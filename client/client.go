package main

import (
	"context"
	"crypto/rand"
	"encoding/csv"
	"flag"
	"fmt"
	"io"
	"log"
	"math/big"
	"os"
	"sync"
	"time"

	pb "asignacionservidor/proto/keyval" 

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Variable global para el cliente gRPC, inicializada en main para ser usada por todos los comandos.
var grpcClient pb.KeyValueServiceClient

// ---- Parte 1 ----

func doSet(ctx context.Context, key, value string) {
	// Realiza una llamada RPC (Remote Procedure Call) unaria al método 'Set' del servidor.
	_, err := grpcClient.Set(ctx, &pb.SetRequest{
		Pair: &pb.KeyValuePair{Key: key, Value: []byte(value)},
	})
	if err != nil {
		log.Fatalf("Error en la operación Set: %v", err)
	}
	fmt.Printf("Éxito: Clave '%s' establecida.\n", key)
}

func doGet(ctx context.Context, key string) {
	resp, err := grpcClient.Get(ctx, &pb.GetRequest{Key: key})
	if err != nil {
		log.Fatalf("Error en la operación Get: %v", err)
	}
	if resp.Found {
		fmt.Printf("Valor para '%s': %s\n", key, string(resp.Value))
	} else {
		fmt.Printf("Clave '%s' no encontrada.\n", key)
	}
}

func doGetPrefix(ctx context.Context, prefix string) {
	// Inicia una llamada de streaming; el cliente se prepara para recibir múltiples respuestas del servidor.
	stream, err := grpcClient.GetPrefixStream(ctx, &pb.GetPrefixRequest{Prefix: prefix})
	if err != nil {
		log.Fatalf("Error al iniciar el stream de GetPrefix: %v", err)
	}
	fmt.Printf("Valores para claves con prefijo '%s':\n", prefix)
	count := 0
	// Bucle para recibir cada una de las respuestas del stream.
	for {
		resp, err := stream.Recv()
		// io.EOF es la señal del servidor de que la transmisión de datos ha terminado.
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatalf("Error al recibir del stream: %v", err)
		}
		if pair := resp.GetPair(); pair != nil {
			fmt.Printf(" - %s: %s\n", pair.Key, string(pair.Value))
			count++
		}
	}
	if count == 0 {
		fmt.Println(" (Ninguna coincidencia encontrada)")
	}
}

func doStats(ctx context.Context) {
	resp, err := grpcClient.Stat(ctx, &pb.StatRequest{})
	if err != nil {
		log.Fatalf("Error en la operación Stat: %v", err)
	}
	fmt.Println("--- Estadísticas del Servidor ---")
	fmt.Printf("Claves totales:        %d\n", resp.TotalKeys)
	fmt.Printf("Tamaño total (bytes):  %d\n", resp.TotalSizeBytes)
	fmt.Printf("Operaciones Set:       %d\n", resp.SetOperations)
	fmt.Printf("Operaciones Get:       %d\n", resp.GetOperations)
	fmt.Printf("Operaciones GetPrefix: %d\n", resp.PrefixOperations)
	fmt.Println("-------------------------------")
}

// doPopulate: Función para cargar datos masivamente en el servidor.
func doPopulate() {
    popCmd := flag.NewFlagSet("populate", flag.ExitOnError)
    numKeys := popCmd.Int("n", 100000, "Número de claves a insertar")
    valueSize := popCmd.Int("valuesize", 4096, "Tamaño del valor en bytes")
    
    popCmd.Parse(os.Args[2:])

    fmt.Fprintf(os.Stderr, "Poblando el servidor con %d claves (valor de %dB cada una)...\n", *numKeys, *valueSize)

    value := make([]byte, *valueSize)
    rand.Read(value)

    // Para acelerar la carga, se lanzan múltiples "workers" (goroutines) concurrentes.
    numWorkers := 16
    var wg sync.WaitGroup
    keysPerWorker := *numKeys / numWorkers

    startTime := time.Now()

    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()
            startKey := workerID * keysPerWorker
            endKey := startKey + keysPerWorker
            for k := startKey; k < endKey; k++ {
                key := fmt.Sprintf("key-%d", k)
                // Cada goroutine realiza llamadas Set de forma independiente para maximizar el paralelismo.
                _, err := grpcClient.Set(context.Background(), &pb.SetRequest{
                    Pair: &pb.KeyValuePair{Key: key, Value: value},
                })
                if err != nil {
                    log.Printf("Error al poblar la clave %s: %v", key, err)
                }
            }
        }(i)
    }

    // `wg.Wait()` se asegura de que la función no termine hasta que todos los workers hayan finalizado.
    wg.Wait()
    duration := time.Since(startTime)
    fmt.Fprintf(os.Stderr, "Población completada en %v.\n", duration)
}

// ---- Parte 2: Lógica del Benchmark ----

// worker simula un cliente virtual que ejecuta operaciones para medir el rendimiento del servidor.
// Recibe un canal de resultados para escribir sus mediciones.
func worker(ctx context.Context, id int, wg *sync.WaitGroup, workload string, valueSize int, numOps int, resultsChan chan<- []string) {
	defer wg.Done()

	value := make([]byte, valueSize)
	rand.Read(value)

	for i := 0; i < numOps; i++ {
		opKey := fmt.Sprintf("bench-w%d-op%d", id, i)
		var opType string

		// Determina si la operación será de lectura (GET) o escritura (SET) según la carga de trabajo.
		if workload == "read-only" {
			opType = "GET"
		} else if workload == "write-only" {
			opType = "SET"
		} else { // "50-50" por defecto
			n, _ := rand.Int(rand.Reader, big.NewInt(2))
			if n.Int64() == 0 {
				opType = "GET"
			} else {
				opType = "SET"
			}
		}
		
		// Mide la latencia de cada operación individual.
		startTime := time.Now()
		var err error

		if opType == "GET" {
			_, err = grpcClient.Get(ctx, &pb.GetRequest{Key: opKey})
		} else {
			_, err = grpcClient.Set(ctx, &pb.SetRequest{
				Pair: &pb.KeyValuePair{Key: opKey, Value: value},
			})
		}

		latency := time.Since(startTime)
		
		if err != nil {
			log.Printf("Error en worker %d: %v", id, err)
			continue
		}
		
		// Envía la medición de latencia a un canal para su procesamiento centralizado y asíncrono.
		resultsChan <- []string{
			workload,
			fmt.Sprintf("%d", valueSize),
			fmt.Sprintf("%d", id),
			fmt.Sprintf("%d", i),
			opType,
			fmt.Sprintf("%f", latency.Seconds() * 1000), // Latencia en ms
		}
	}
}

func doBenchmark() {
	benchCmd := flag.NewFlagSet("benchmark", flag.ExitOnError)
	workload := benchCmd.String("workload", "50-50", "Carga de trabajo: 'read-only', 'write-only' o '50-50'")
	valueSize := benchCmd.Int("valuesize", 4096, "Tamaño del valor en bytes")
	numClients := benchCmd.Int("clients", 1, "Número de clientes concurrentes")
	numOps := benchCmd.Int("ops", 1000, "Número de operaciones por cliente")
	csvFile := benchCmd.String("out", "benchmark_results.csv", "Archivo CSV para guardar los resultados")

	benchCmd.Parse(os.Args[2:])

	// Prepara un archivo CSV para guardar las mediciones de forma persistente y analizable.
	file, err := os.Create(*csvFile)
	if err != nil { log.Fatalf("No se pudo crear el archivo CSV: %v", err) }
	defer file.Close()
	writer := csv.NewWriter(file)
	defer writer.Flush()
	writer.Write([]string{"workload", "value_size_bytes", "client_id", "op_id", "op_type", "latency_ms"})

	// Se pre-cargan datos para que las pruebas de lectura (GET) tengan claves que encontrar.
	fmt.Println("Pre-poblando datos para lecturas de benchmark...")
	prepopulateValue := make([]byte, *valueSize)
	rand.Read(prepopulateValue)
	for c := 0; c < *numClients; c++ {
		for o := 0; o < *numOps; o++ {
			opKey := fmt.Sprintf("bench-w%d-op%d", c, o)
			grpcClient.Set(context.Background(), &pb.SetRequest{Pair: &pb.KeyValuePair{Key: opKey, Value: prepopulateValue}})
		}
	}

	fmt.Printf("Iniciando benchmark: [Workload: %s] [ValueSize: %dB] [Clients: %d] [Ops/Client: %d]\n",
		*workload, *valueSize, *numClients, *numOps)
	
	resultsChan := make(chan []string, *numClients*(*numOps))
	var wg sync.WaitGroup
	ctx := context.Background()
	startTime := time.Now()
	
	// Lanza el número de clientes concurrentes (workers) especificado para simular carga real.
	for i := 0; i < *numClients; i++ {
		wg.Add(1)
		go worker(ctx, i, &wg, *workload, *valueSize, *numOps, resultsChan)
	}

	// Una goroutine separada escribe los resultados para no ralentizar a los workers de la prueba.
	go func() {
		for result := range resultsChan {
			if err := writer.Write(result); err != nil {
				log.Printf("Error al escribir en CSV: %v", err)
			}
		}
	}()
	
	// Espera a que todos los workers terminen antes de calcular los resultados finales.
	wg.Wait()
	close(resultsChan)

	totalDuration := time.Since(startTime)
	totalOps := *numClients * *numOps
	// Al finalizar, calcula métricas clave como el rendimiento total (throughput).
	throughput := float64(totalOps) / totalDuration.Seconds()
	
	fmt.Println("\n--- Resultados del Benchmark ---")
	fmt.Printf("Tiempo total:          %v\n", totalDuration)
	fmt.Printf("Operaciones totales:   %d\n", totalOps)
	fmt.Printf("Rendimiento (ops/seg): %.2f\n", throughput)
	fmt.Printf("Resultados guardados en: %s\n", *csvFile)
	fmt.Println("------------------------------")
}

// ---- Parte 3: El Despachador Principal (nueva función main) ----

func main() {
	serverAddr := flag.String("addr", "localhost:50051", "Dirección del servidor gRPC (host:puerto)")
	flag.Parse()

	// Se conecta al servidor gRPC. 'insecure' se usa para pruebas locales sin cifrado TLS.
	conn, err := grpc.Dial(*serverAddr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		// Aumenta el tamaño máximo de los mensajes para los benchmarks con valores grandes.
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(10*1024*1024),
			grpc.MaxCallSendMsgSize(10*1024*1024),
		),
	)
	if err != nil { log.Fatalf("La conexión falló: %v", err) }
	defer conn.Close()
	grpcClient = pb.NewKeyValueServiceClient(conn)

	// Determina el subcomando a ejecutar.
	if flag.NArg() < 1 {
		fmt.Println("Uso: lbclient [-addr host:port] <comando> [argumentos]")
		fmt.Println("Comandos: set, get, getprefix, stats, benchmark")
		os.Exit(1)
	}
	
	command := flag.Arg(0)
	//  Crea un contexto con tiempo de espera para evitar que el cliente se cuelgue indefinidamente.
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	// Este 'switch' actúa como un despachador que ejecuta la función correspondiente al comando.
	switch command {
	case "set":
		if flag.NArg() != 3 { log.Fatalf("Uso: lbclient set <key> <value>") }
		doSet(ctx, flag.Arg(1), flag.Arg(2))
	case "get":
		if flag.NArg() != 2 { log.Fatalf("Uso: lbclient get <key>") }
		doGet(ctx, flag.Arg(1))
	case "getprefix":
		if flag.NArg() != 2 { log.Fatalf("Uso: lbclient getprefix <prefix>") }
		doGetPrefix(ctx, flag.Arg(1))
	case "stats":
		doStats(ctx)
	case "populate":
    	doPopulate()
	case "benchmark":
		doBenchmark()
	default:
		log.Fatalf("Comando desconocido: '%s'. Válidos: set, get, getprefix, stats, benchmark", command)
	}
}