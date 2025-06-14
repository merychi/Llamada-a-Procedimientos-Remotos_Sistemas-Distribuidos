

# Variables
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOPATH_BIN=$(shell $(GOCMD) env GOPATH)/bin

# Nombre de los binarios de salida
SERVER_BIN=lbserver
CLIENT_BIN=lbclient

# Rutas a los paquetes Go
SERVER_PKG=./server
CLIENT_PKG=./client
PROTO_PKG=./proto/keyval

# Archivo Proto
PROTO_FILE=./proto/kvstore.proto

.PHONY: all server client proto clean test run-server run-client-sample

# Target por defecto: compila todo
all: server client

# Target para compilar el servidor
server:
	@echo "Compilando el servidor (lbserver)..."
	$(GOBUILD) -o $(SERVER_BIN) $(SERVER_PKG)
	@echo "Servidor compilado en ./${SERVER_BIN}"

# Target para compilar el cliente
client:
	@echo "Compilando el cliente (lbclient)..."
	$(GOBUILD) -o $(CLIENT_BIN) $(CLIENT_PKG)
	@echo "Cliente compilado en ./${CLIENT_BIN}"

# Target para generar el código Go a partir del .proto
proto:
	@echo "Generando código gRPC desde $(PROTO_FILE)..."
	@# Comprobar si protoc-gen-go y protoc-gen-go-grpc están instalados
	@if ! command -v protoc-gen-go &> /dev/null; then \
		echo "ERROR: protoc-gen-go no encontrado. Por favor, instálalo con 'go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28'"; \
		exit 1; \
	fi
	@if ! command -v protoc-gen-go-grpc &> /dev/null; then \
		echo "ERROR: protoc-gen-go-grpc no encontrado. Por favor, instálalo con 'go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2'"; \
		exit 1; \
	fi
	protoc --go_out=. --go_opt=paths=source_relative \
       --go-grpc_out=. --go-grpc_opt=paths=source_relative \
       $(PROTO_FILE)
	@echo "Código gRPC generado en $(PROTO_PKG)"

# Target para limpiar los binarios y archivos generados
clean:
	@echo "Limpiando binarios y archivos temporales..."
	rm -f $(SERVER_BIN) $(CLIENT_BIN)
	$(GOCLEAN)
	@echo "Limpieza completada."

# Target para ejecutar el script de prueba simple requerido
test: all
	@echo "Ejecutando el script de prueba simple (test.sh)..."
	@chmod +x ./scripts/test.sh
	./scripts/test.sh

# Targets para ejecutar cada experimento individual
experimento1: all
	@echo "Ejecutando Experimento 1: Latencia vs Tamaño de Valor..."
	@chmod +x ./scripts/experimento1.sh
	./scripts/experimento1.sh

experimento2: all
	@echo "Ejecutando Experimento 2: Recuperación ante Fallos..."
	@chmod +x ./scripts/experimento2.sh
	./scripts/experimento2.sh

experimento3: all
	@echo "Ejecutando Experimento 3: Escalabilidad con Clientes Concurrentes..."
	@chmod +x ./scripts/experimento3.sh
	./scripts/experimento3.sh

# Target para ejecutar todos los experimentos en orden
test-all: test experimento1 experimento2 experimento3
	@echo "Todos los experimentos han sido ejecutados con éxito."


# Target de conveniencia para correr el servidor
run-server: all
	@echo "Iniciando el servidor..."
	./$(SERVER_BIN)

# Target de conveniencia para correr un cliente de ejemplo
run-client-sample: all
	@echo "Ejecutando un cliente de ejemplo (get stats)..."
	./$(CLIENT_BIN) stats