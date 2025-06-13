#!/bin/bash
# ==============================================================================
# Script para el Experimento 3: Throughput y Latencia vs. Número de Clientes
# ==============================================================================

# 1. Encontrar la raíz del proyecto y moverse a ella.
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT" || { echo "Error: No se pudo cambiar al directorio raíz del proyecto."; exit 1; }

# 2. Definir las rutas a los binarios.
SERVER_BIN="./lbserver"
CLIENT_BIN="./lbclient"

# --- Configuración del Experimento ---
WORKLOADS=("read-only" "50-50") 
CLIENT_COUNTS=(1 2 4 8 16 32) 
VALUE_SIZE=4096

SUMMARY_FILE="results_exp3_summary.csv"

# --- Comienzo del Script ---
echo "--- Iniciando Experimento 3: Escalabilidad con Múltiples Clientes ---"
echo "Directorio de trabajo actual: $(pwd)"

# --- Preparación ---
echo "[FASE 1] Compilando los binarios..."
make clean client server

echo "Workload,NumClients,AvgLatency_ms,Throughput_ops_s" > "$SUMMARY_FILE"

echo "Iniciando servidor en segundo plano..."
"$SERVER_BIN" > server.log 2>&1 &
SERVER_PID=$!
echo "Servidor iniciado con PID: ${SERVER_PID}"
sleep 3 

# --- Bucle de Ejecución ---
for workload in "${WORKLOADS[@]}"; do
  echo ""
  echo "==========================================================="
  echo "Probando carga de trabajo: ${workload}"
  echo "==========================================================="
  
  for clients in "${CLIENT_COUNTS[@]}"; do
    echo "--- Benchmark: workload=${workload}, clients=${clients} ---"
    
    RAW_CSV_FILE="results_exp3_${workload}_${clients}clients.csv"
    
    BENCH_OUTPUT=$("$CLIENT_BIN" benchmark -workload="${workload}" -valuesize=${VALUE_SIZE} -clients=${clients} -ops=1000 -out="$RAW_CSV_FILE")
    

    THROUGHPUT=$(echo "$BENCH_OUTPUT" | grep 'Rendimiento' | awk '{print $NF}')
    
    AVG_LATENCY=$(awk -F, 'NR > 1 {sum+=$6; count++} END {if (count>0) print sum/count; else print 0}' "$RAW_CSV_FILE")
    
    echo "  -> Throughput: ${THROUGHPUT} ops/s"
    echo "  -> Latencia Promedio: ${AVG_LATENCY} ms"
    

    echo "${workload},${clients},${AVG_LATENCY},${THROUGHPUT}" >> "$SUMMARY_FILE"

  done
done

# --- Limpieza Final ---
echo ""
echo "Experimento completado. Los resultados consolidados están en ${SUMMARY_FILE}"
echo "Deteniendo el servidor..."
kill ${SERVER_PID}
wait ${SERVER_PID} 2>/dev/null
echo "--- Experimento 3 Finalizado ---"