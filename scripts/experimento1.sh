#!/bin/bash
# ==============================================================================
# Script para el Experimento 1: Latencia vs. Tamaño de Valor
# ==============================================================================

# 1. Encontrar la raíz del proyecto y moverse a ella.
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT" || { echo "Error: No se pudo cambiar al directorio raíz del proyecto."; exit 1; }

# 2. Definir las rutas a los binarios.
SERVER_BIN="./lbserver"
CLIENT_BIN="./lbclient"

# Comprobar si los binarios existen.
if [ ! -f "$SERVER_BIN" ] && [ -f "$SERVER_BIN.exe" ]; then SERVER_BIN="./lbserver.exe"; fi
if [ ! -f "$CLIENT_BIN" ] && [ -f "$CLIENT_BIN.exe" ]; then CLIENT_BIN="./lbclient.exe"; fi

if [ ! -f "$SERVER_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    echo "Error: Los binarios no se encontraron. Asegúrate de haber compilado con 'make'."
    exit 1
fi

echo "--- Iniciando Experimento 1: Latencia vs. Tamaño de Valor ---"
# Tamaños en bytes: 512B, 4KB, 512KB, 1MB, 4MB
SIZES=(512 4096 524288 1048576 4194304)
WORKLOADS=("read-only" "50-50")
NUM_OPS=50

# --- Preparación del archivo de resumen ---
SUMMARY_FILE="results_exp1_summary.csv"
echo "Workload,ValueSize_bytes,AvgLatency_ms" > "$SUMMARY_FILE"
echo "Se creará el archivo de resumen en: ${SUMMARY_FILE}"

# --- Inicio del Servidor ---
echo "Iniciando el servidor..."
"$SERVER_BIN" > server.log 2>&1 &
SERVER_PID=$!
echo "Servidor iniciado con PID $SERVER_PID. Esperando 5 segundos para que arranque..."
sleep 5

# Comprobar si el servidor sigue vivo
if ! ps -p $SERVER_PID > /dev/null; then
   echo "Error: El servidor no pudo iniciarse. Revisa server.log para ver los errores."
   exit 1
fi

# --- Bucle de Ejecución del Benchmark ---
for workload in "${WORKLOADS[@]}"; do
  for size in "${SIZES[@]}"; do
    echo "--------------------------------------------------------"
    echo "Benchmark: workload=${workload}, valuesize=${size}"
    
    # Nombre del archivo para los resultados detallados de esta ejecución.
    RAW_CSV_FILE="results_exp1_${workload}_${size}.csv"
    
    # Ejecutar el benchmark. El cliente crea el archivo CSV detallado.
    "$CLIENT_BIN" benchmark \
        -workload=${workload} \
        -valuesize=${size} \
        -clients=1 \
        -ops=${NUM_OPS} \
        -out="$RAW_CSV_FILE"
        
    echo "Benchmark completado. Resultados detallados en: ${RAW_CSV_FILE}"

    # --- Cálculo y Escritura en el Resumen ---
    AVG_LATENCY=$(awk -F, 'NR > 1 {sum+=$6; count++} END {if (count>0) print sum/count; else print 0}' "$RAW_CSV_FILE")
    
    echo "  -> Latencia Promedio: ${AVG_LATENCY} ms"
    
    # Escribir los resultados agregados en el archivo de resumen.
    echo "${workload},${size},${AVG_LATENCY}" >> "$SUMMARY_FILE"
    echo "  -> Resumen actualizado en: ${SUMMARY_FILE}"
    
    sleep 2
  done
done

# --- Limpieza Final ---
echo "--------------------------------------------------------"
echo "Deteniendo el servidor (PID: $SERVER_PID)..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null

echo "Experimento 1 completado."
echo "Todos los archivos de resultados detallados se han conservado."
echo "El archivo de resumen para la gráfica está listo en: ${SUMMARY_FILE}"