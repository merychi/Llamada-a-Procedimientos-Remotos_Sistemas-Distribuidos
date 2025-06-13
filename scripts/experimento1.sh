#!/bin/bash
# ==============================================================================
# Script para el Experimento 1: Latencia vs. Tamaño de Valor
# ==============================================================================

# 1. Encontrar la raíz del proyecto y moverse a ella.
# Esto asegura que el script se puede ejecutar desde cualquier lugar.
PROJECT_ROOT=$(dirname "$0")/..
cd "$PROJECT_ROOT" || { echo "Error: No se pudo cambiar al directorio raíz del proyecto."; exit 1; }

# 2. Definir las rutas a los binarios.
# Asumimos que los binarios están en la raíz del proyecto.
SERVER_BIN="./lbserver.exe" # Quitar .exe para compatibilidad con Linux/WSL
CLIENT_BIN="./lbclient.exe" # Quitar .exe para compatibilidad con Linux/WSL

# Comprobar si los binarios existen.
if [ ! -f "$SERVER_BIN" ] && [ -f "$SERVER_BIN.exe" ]; then SERVER_BIN="./lbserver.exe"; fi
if [ ! -f "$CLIENT_BIN" ] && [ -f "$CLIENT_BIN.exe" ]; then CLIENT_BIN="./lbclient.exe"; fi

if [ ! -f "$SERVER_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    echo "Error: Los binarios no se encontraron. Asegúrate de haber compilado con 'make'."
    exit 1
fi


echo "Ejecutando Experimento 1: Latencia vs. Tamaño de Valor"
# Tamaños en bytes: 512B, 4KB, 512KB, 1MB, (4MB comentado por si tarda mucho)
SIZES=(512 4096 524288 1048576) # 4194304
WORKLOADS=("read-only" "50-50")
NUM_OPS=100 # <--- ¡AQUÍ ESTÁ LA VARIABLE CLAVE!

# Iniciar el servidor en segundo plano
echo "Iniciando el servidor..."
$SERVER_BIN > server.log 2>&1 &
SERVER_PID=$!
echo "Servidor iniciado con PID $SERVER_PID. Esperando 5 segundos para que arranque..."
sleep 5

# Comprobar si el servidor sigue vivo
if ! ps -p $SERVER_PID > /dev/null; then
   echo "Error: El servidor no pudo iniciarse. Revisa server.log para ver los errores."
   exit 1
fi

for workload in "${WORKLOADS[@]}"; do
  for size in "${SIZES[@]}"; do
    echo "--- Benchmark: workload=${workload}, valuesize=${size}, ops=${NUM_OPS} ---"
    
    # Llamada al cliente con el número de operaciones especificado
    $CLIENT_BIN benchmark \
        -workload=${workload} \
        -valuesize=${size} \
        -clients=1 \
        -ops=${NUM_OPS} \
        -out="results_exp1_${workload}_${size}.csv"
        
    echo "Benchmark completado. Durmiendo 2 segundos antes del siguiente..."
    sleep 2
  done
done

# Detener el servidor
echo "Deteniendo el servidor (PID: $SERVER_PID)..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null

echo "Experimento 1 completado."