#!/bin/bash
# ==============================================================================
# Script para el Experimento 3: Throughput y Latencia vs. Número de Clientes
# ==============================================================================

# 1. Encontrar la raíz del proyecto y moverse a ella.
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT" || { echo "Error: No se pudo cambiar al directorio raíz del proyecto."; exit 1; }

# 2. Definir las rutas a los binarios.
SERVER_BIN="./lbserver.exe"
CLIENT_BIN="./lbclient.exe"

# --- Configuración del Experimento ---
# Cargas de trabajo a probar.
WORKLOADS=("read-only" "50-50") 
# Número de clientes concurrentes a probar.
CLIENT_COUNTS=(1 2 4 8 16 32) 
VALUE_SIZE=4096

# --- Comienzo del Script ---
echo "--- Iniciando Experimento 3: Escalabilidad con Múltiples Clientes ---"
echo "Directorio de trabajo actual: $(pwd)"

# --- Preparación ---
echo "[FASE 1] Compilando los binarios..."
make client server

# Iniciar el servidor en segundo plano
"$SERVER_BIN" &
SERVER_PID=$!
echo "Servidor iniciado con PID: ${SERVER_PID}"
sleep 3 # Dar tiempo al servidor para que arranque

# --- Bucle de Ejecución ---
# Iterar sobre cada carga de trabajo
for workload in "${WORKLOADS[@]}"; do
  echo ""
  echo "==========================================================="
  echo "Probando carga de trabajo: ${workload}"
  echo "==========================================================="
  
  # Iterar sobre cada número de clientes
  for clients in "${CLIENT_COUNTS[@]}"; do
    echo "--- Benchmark: workload=${workload}, clients=${clients} ---"
    
    # Ejecutar el benchmark usando las variables de ruta
    "$CLIENT_BIN" benchmark -workload="${workload}" -valuesize=${VALUE_SIZE} -clients=${clients} -ops=1000 -out="results_exp3_${workload}_${clients}clients.csv"
  done
done

# --- Limpieza Final ---
echo ""
echo "Experimento completado. Deteniendo el servidor..."
kill ${SERVER_PID}
wait ${SERVER_PID} 2>/dev/null
echo "--- Experimento 3 Finalizado ---"