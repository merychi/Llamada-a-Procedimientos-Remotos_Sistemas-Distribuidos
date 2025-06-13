package main

import (
	"bufio"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"hash/fnv"
	"log"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	pb "asignacionservidor/proto/keyval"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const (
	MaxKeySize       = 128
	// numShards: Divide los datos en múltiples mapas más pequeños (fragmentos o 'shards').
	// Esto reduce la contención de bloqueos y mejora el rendimiento en sistemas con múltiples CPUs.
	numShards        = 32
	dataDir          = "./data"
	snapshotFile     = "snapshot.json"
	// walFile: Write-Ahead Log. Un diario donde se registra cada operación de escritura ANTES de ejecutarla.
	// Es crucial para recuperar datos si el servidor se cae.
	walFile          = "kvstore.wal"
	snapshotInterval = 5 * time.Minute
	walSizeThreshold = 256 * 1024 * 1024
)

// ---- Estructuras de Datos ---- //
type Statistics struct {
	mu               sync.Mutex
	totalKeys        uint64
	totalSizeBytes   uint64
	setOperations    uint64
	getOperations    uint64
	prefixOperations uint64
}

// KeyValueStoreShard: Un único fragmento de datos.
// Tiene su propio candado (mutex) para permitir escrituras y lecturas concurrentes en diferentes fragmentos.
type KeyValueStoreShard struct {
	mu    sync.RWMutex
	store map[string][]byte
}

// ShardedStore: Estructura central que organiza los fragmentos (shards)
// y gestiona la persistencia (WAL y snapshots).
type ShardedStore struct {
	shards       []*KeyValueStoreShard
	stats        *Statistics
	walMutex     sync.Mutex // Protege solo el acceso al archivo WAL.
	walFile      *os.File
	walSize      int64
	walPath      string
	snapshotPath string

	// Canal para desacoplar la solicitud de creación de snapshots del hilo principal de operaciones.
	snapshotTrigger chan struct{}
	snapshotMutex   sync.Mutex
}

type SnapshotData struct {
	Timestamp int64             `json:"timestamp"`
	Data      map[string][]byte `json:"data"`
}

// ---- Inicialización y Recuperación ---- //

func NewShardedStore() (*ShardedStore, error) {
	log.Println("Inicializando el almacén clave-valor...")
	if err := os.MkdirAll(dataDir, 0755); err != nil { return nil, err }

	store := &ShardedStore{
		shards:          make([]*KeyValueStoreShard, numShards),
		stats:           &Statistics{},
		walPath:         filepath.Join(dataDir, walFile),
		snapshotPath:    filepath.Join(dataDir, snapshotFile),
		// Se inicializa un canal para recibir peticiones de snapshot.
		snapshotTrigger: make(chan struct{}, 1),
	}

	for i := range store.shards {
		store.shards[i] = &KeyValueStoreShard{store: make(map[string][]byte)}
	}

	// Al arrancar, intenta recuperar el estado desde el disco.
	if err := store.recoverStore(); err != nil { return nil, err }

	file, err := os.OpenFile(store.walPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil { return nil, err }
	store.walFile = file

	info, err := file.Stat()
	if err != nil { return nil, err }
	store.walSize = info.Size()

	log.Printf("Almacén inicializado. Tamaño inicial del WAL: %d bytes.", store.walSize)
	return store, nil
}

// getShard: Calcula un hash de la clave para determinar a qué fragmento (shard) pertenece.
// Esta es la estrategia de distribución de datos.
func (s *ShardedStore) getShard(key string) *KeyValueStoreShard {
	h := fnv.New32a()
	h.Write([]byte(key))
	return s.shards[h.Sum32()%uint32(numShards)]
}

// recoverStore: Proceso de recuperación de fallos.
// 1. Carga el último 'snapshot' (la foto completa más reciente de los datos).
// 2. Reaplica las operaciones del WAL (diario) que ocurrieron después de ese snapshot.
func (s *ShardedStore) recoverStore() error {
	log.Println("Iniciando proceso de recuperación...")
	var snapshotTimestamp int64 = 0
	snapshotData, err := os.ReadFile(s.snapshotPath)
	if err == nil {
		var snap SnapshotData
		if err := json.Unmarshal(snapshotData, &snap); err != nil {
			log.Printf("ADVERTENCIA: No se pudo parsear el snapshot, se ignora. Error: %v", err)
		} else {
			log.Printf("Cargando estado desde snapshot con fecha %v...", time.Unix(0, snap.Timestamp).Format(time.RFC3339))
			for k, v := range snap.Data {
				shard := s.getShard(k)
				shard.store[k] = v
			}
			snapshotTimestamp = snap.Timestamp
			log.Printf("Snapshot cargado. %d claves restauradas.", len(snap.Data))
		}
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("error al leer el archivo de snapshot: %w", err)
	}

	log.Println("Reaplicando operaciones desde el WAL...")
	walReader, err := os.Open(s.walPath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Println("No se encontró archivo WAL, se asume estado limpio.")
			return nil
		}
		return fmt.Errorf("no se pudo abrir el WAL para lectura: %w", err)
	}
	defer walReader.Close()
	scanner := bufio.NewScanner(walReader)
	const maxLineSize = 10 * 1024 * 1024
	buf := make([]byte, maxLineSize)
	scanner.Buffer(buf, maxLineSize)

	linesReplayed := 0
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" { continue }
		parts := strings.SplitN(line, ",", 3)
		if len(parts) != 3 {
			log.Printf("ADVERTENCIA: Línea de WAL malformada, se ignora: %s", line)
			continue
		}
		walTimestamp, err := strconv.ParseInt(parts[0], 10, 64)
		if err != nil {
			log.Printf("ADVERTENCIA: Timestamp de WAL inválido, se ignora: %s", line)
			continue
		}
		// Solo se aplican las operaciones del WAL posteriores al snapshot.
		if walTimestamp > snapshotTimestamp {
			key := parts[1]
			valueBytes, err := base64.StdEncoding.DecodeString(parts[2])
			if err != nil {
				log.Printf("ADVERTENCIA: Valor en WAL no es Base64 válido, se ignora: %s", line)
				continue
			}
			shard := s.getShard(key)
			shard.store[key] = valueBytes
			linesReplayed++
		}
	}
	log.Printf("Recuperación del WAL completada. %d operaciones reaplicadas.", linesReplayed)
	return scanner.Err()
}

// ---- Lógica de Persistencia (WAL y Snapshots) ---- //

// logOperation: Implementa el Write-Ahead Log (WAL). Cada escritura se registra en disco
// ANTES de ser aplicada en memoria, garantizando la durabilidad ante caídas.
func (s *ShardedStore) logOperation(key string, value []byte) error {
	encodedValue := base64.StdEncoding.EncodeToString(value)
	timestamp := time.Now().UnixNano()
	entry := fmt.Sprintf("%d,%s,%s\n", timestamp, key, encodedValue)

	s.walMutex.Lock()
	n, err := s.walFile.WriteString(entry)
	if err != nil {
		s.walMutex.Unlock()
		return err
	}
	// `Sync` fuerza la escritura al disco físico. Es lento pero seguro.
	if err := s.walFile.Sync(); err != nil {
		s.walMutex.Unlock()
		return err
	}
	s.walSize += int64(n)
	currentSize := s.walSize
	s.walMutex.Unlock()

	// Si el WAL crece mucho, notifica a otra rutina para que cree un snapshot.
	if currentSize > walSizeThreshold {
		select {
		case s.snapshotTrigger <- struct{}{}:
		default: // No bloquear si ya hay una petición pendiente.
		}
	}

	return nil
}

// takeSnapshot: Crea un 'snapshot': una copia completa de todos los datos en un momento dado.
// Esto permite truncar el archivo WAL para que no crezca indefinidamente.
func (s *ShardedStore) takeSnapshot() {
	s.snapshotMutex.Lock()
	defer s.snapshotMutex.Unlock()

	log.Println("Iniciando creación de snapshot...")

	snapshotMap := make(map[string][]byte)
	for _, shard := range s.shards {
		// Se usa un Read Lock (RLock) para permitir lecturas mientras se crea el snapshot.
		shard.mu.RLock()
		for k, v := range shard.store { snapshotMap[k] = v }
		shard.mu.RUnlock()
	}

	snapshot := SnapshotData{Timestamp: time.Now().UnixNano(), Data: snapshotMap}
	data, err := json.Marshal(snapshot)
	if err != nil {
		log.Printf("ERROR al crear snapshot: no se pudo serializar a JSON: %v", err)
		return
	}

	// Patrón seguro: Escribir en un archivo temporal y luego renombrarlo.
	// Esto evita tener un snapshot corrupto si el servidor falla a mitad de la escritura.
	tempPath := s.snapshotPath + ".tmp"
	if err := os.WriteFile(tempPath, data, 0644); err != nil {
		log.Printf("ERROR al crear snapshot: no se pudo escribir el archivo temporal: %v", err)
		return
	}
	if err := os.Rename(tempPath, s.snapshotPath); err != nil {
		log.Printf("ERROR al crear snapshot: no se pudo renombrar el archivo: %v", err)
		return
	}

	log.Printf("Snapshot creado exitosamente con %d claves.", len(snapshotMap))

	// Rotación del WAL: Una vez el snapshot es seguro, el viejo WAL ya no es necesario.
	// Se cierra, se renombra como backup y se crea uno nuevo y vacío.
	s.walMutex.Lock()
	defer s.walMutex.Unlock()
	
	s.walFile.Close()
	backupWalPath := fmt.Sprintf("%s.%d", s.walPath, time.Now().Unix())
	os.Rename(s.walPath, backupWalPath)
	
	newWalFile, err := os.OpenFile(s.walPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("CRÍTICO: no se pudo crear un nuevo WAL después del snapshot: %v", err)
	}
	s.walFile = newWalFile
	s.walSize = 0 // El tamaño del nuevo WAL es cero.
	log.Println("Rotación del WAL completada.")
}

// ---- Servidor gRPC ---- //

type Server struct {
	pb.UnimplementedKeyValueServiceServer
	kvStore *ShardedStore
}

// Set: Manejador de la petición Set. El orden es crucial para la consistencia:
// 1. Escribe en el WAL (disco).
// 2. Actualiza la memoria (el shard).
func (s *Server) Set(ctx context.Context, req *pb.SetRequest) (*pb.SetResponse, error) {
	key, value := req.Pair.Key, req.Pair.Value
	if len(key) > MaxKeySize {
		return nil, status.Errorf(codes.InvalidArgument, "el tamaño de la clave excede %d bytes", MaxKeySize)
	}
	if err := s.kvStore.logOperation(key, value); err != nil {
		return nil, status.Errorf(codes.Internal, "fallo al persistir la operación: %v", err)
	}
	shard := s.kvStore.getShard(key)
	shard.mu.Lock()
	defer shard.mu.Unlock()
	oldValue, exists := shard.store[key]
	shard.store[key] = value
	s.kvStore.stats.mu.Lock()
	defer s.kvStore.stats.mu.Unlock()
	if exists {
		s.kvStore.stats.totalSizeBytes -= uint64(len(oldValue))
	} else {
		s.kvStore.stats.totalKeys++
	}
	s.kvStore.stats.totalSizeBytes += uint64(len(value))
	s.kvStore.stats.setOperations++
	return &pb.SetResponse{Success: true}, nil
}

func (s *Server) Get(ctx context.Context, req *pb.GetRequest) (*pb.GetResponse, error) {
	shard := s.kvStore.getShard(req.Key)
	shard.mu.RLock()
	defer shard.mu.RUnlock()
	value, exists := shard.store[req.Key]
	s.kvStore.stats.mu.Lock()
	s.kvStore.stats.getOperations++
	s.kvStore.stats.mu.Unlock()
	return &pb.GetResponse{Value: value, Found: exists}, nil
}

// GetPrefixStream: Ejemplo de procesamiento paralelo. Lanza una goroutine por cada shard
// para buscar coincidencias, y usa un canal para agregar los resultados.
// Esto acelera la búsqueda en un sistema con múltiples CPUs.
func (s *Server) GetPrefixStream(req *pb.GetPrefixRequest, stream pb.KeyValueService_GetPrefixStreamServer) error {
	log.Printf("ADVERTENCIA DE RENDIMIENTO: Ejecutando GetPrefix con escaneo completo.")
	startTime := time.Now()
	resultsChan := make(chan *pb.KeyValuePair, 100)
	var wg sync.WaitGroup
	for i := 0; i < numShards; i++ {
		wg.Add(1)
		go func(shardIndex int) {
			defer wg.Done()
			shard := s.kvStore.shards[shardIndex]
			shard.mu.RLock()
			defer shard.mu.RUnlock()
			for k, v := range shard.store {
				if strings.HasPrefix(k, req.Prefix) {
					resultsChan <- &pb.KeyValuePair{Key: k, Value: v}
				}
			}
		}(i)
	}
	// Esta goroutine espera a que todas las búsquedas en los shards terminen y luego cierra el canal.
	go func() {
		wg.Wait()
		close(resultsChan)
	}()
	var count uint64
	for pair := range resultsChan {
		if err := stream.Send(&pb.GetPrefixStreamResponse{Response: &pb.GetPrefixStreamResponse_Pair{Pair: pair}}); err != nil {
			return err
		}
		count++
	}
	log.Printf("GetPrefix completado en %v, se encontraron %d coincidencias.", time.Since(startTime), count)
	s.kvStore.stats.mu.Lock()
	s.kvStore.stats.prefixOperations++
	s.kvStore.stats.mu.Unlock()
	return nil
}

func (s *Server) Stat(ctx context.Context, req *pb.StatRequest) (*pb.StatResponse, error) {
	s.kvStore.stats.mu.Lock()
	defer s.kvStore.stats.mu.Unlock()
	return &pb.StatResponse{
		TotalKeys:        s.kvStore.stats.totalKeys,
		TotalSizeBytes:   s.kvStore.stats.totalSizeBytes,
		SetOperations:    s.kvStore.stats.setOperations,
		GetOperations:    s.kvStore.stats.getOperations,
		PrefixOperations: s.kvStore.stats.prefixOperations,
	}, nil
}

// ---- Función Principal ---- //

func main() {
	kvStore, err := NewShardedStore()
	if err != nil {
		log.Fatalf("No se pudo inicializar el almacén: %v", err)
	}

	// Goroutine dedicada a gestionar la creación de snapshots.
	// Actúa de forma asíncrona para no bloquear las peticiones de los clientes.
	go func() {
		ticker := time.NewTicker(snapshotInterval)
		defer ticker.Stop()

		for {
			// El `select` espera a que ocurra uno de dos eventos.
			select {
			// 1. Pasó el intervalo de tiempo definido.
			case <-ticker.C:
				log.Println("Disparador de snapshot por tiempo activado.")
				kvStore.takeSnapshot()
			// 2. El tamaño del WAL superó el umbral.
			case <-kvStore.snapshotTrigger:
				log.Println("Disparador de snapshot por tamaño activado.")
				time.Sleep(2 * time.Second) // Pequeña espera para agrupar posibles disparos rápidos.
				kvStore.takeSnapshot()
			}
		}
	}()

	lis, err := net.Listen("tcp", ":50051")
	if err != nil { log.Fatalf("falló al escuchar: %v", err) }
	
	s := grpc.NewServer(
    grpc.MaxRecvMsgSize(10 * 1024 * 1024), // Aumenta a 10 MB
    grpc.MaxSendMsgSize(10 * 1024 * 1024), // Aumenta a 10 MB
	)
	pb.RegisterKeyValueServiceServer(s, &Server{kvStore: kvStore})
	log.Printf("SERVIDOR ESCUCHANDO EN %v", lis.Addr())
	if err := s.Serve(lis); err != nil { log.Fatalf("falló al servir: %v", err) }
}