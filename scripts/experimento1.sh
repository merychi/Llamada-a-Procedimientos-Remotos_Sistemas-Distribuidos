#!/bin/bash
# ==============================================================================
# Script para el Experimento 1: Latencia vs. Tamaño de Valor
# ==============================================================================

# Encontrar la raíz del proyecto y moverse a ella.
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT" || { echo "Error: No se pudo cambiar al directorio raíz del proyecto."; exit 1; }

# Definir las rutas a los binarios.
SERVER_BIN="./lbserver"
CLIENT_BIN="./lbclient"

# Comprobar si los binarios existen.
if [ -f "./lbserver.exe" ]; then SERVER_BIN="./lbserver.exe"; fi
if [ -f "./lbclient.exe" ]; then CLIENT_BIN="./lbclient.exe"; fi

if [ ! -f "$SERVER_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    echo "Error: Los binarios no se encontraron. Asegúrate de haber compilado con 'make'."
    exit 1
fi

# Función para encabezados decorativos
print_header() {
    echo ""
    echo "============================================================"
    echo "=> $1"
    echo "============================================================"
}

print_header "Iniciando Experimento 1: Latencia vs. Tamaño de Valor"

SIZES=(512 4096 524288 1048576 4194304)
WORKLOADS=("read-only" "50-50")
NUM_OPS=50

SUMMARY_FILE="results_exp1_summary.csv"
echo "Workload,ValueSize_bytes,AvgLatency_ms" > "$SUMMARY_FILE"
echo "→ Archivo de resumen creado en: ${SUMMARY_FILE}"

# Iniciar el servidor
print_header "Paso 1: Iniciando el servidor"
"$SERVER_BIN" > server.log 2>&1 &
SERVER_PID=$!
echo "Servidor iniciado con éxito (PID: $SERVER_PID). Esperando 5 segundos..."
sleep 5

if ! ps -p $SERVER_PID > /dev/null; then
    echo "Error: El servidor no pudo iniciarse. Revisa server.log para ver los errores."
    exit 1
fi

# Ejecutar benchmarks
print_header "Paso 2: Ejecutando pruebas de latencia"

for workload in "${WORKLOADS[@]}"; do
  for size in "${SIZES[@]}"; do
    echo "------------------------------------------------------------"
    echo "Benchmark: workload=${workload}, valuesize=${size} bytes"

    RAW_CSV_FILE="results_exp1_${workload}_${size}.csv"

    "$CLIENT_BIN" benchmark \
        -workload=${workload} \
        -valuesize=${size} \
        -clients=1 \
        -ops=${NUM_OPS} \
        -out="$RAW_CSV_FILE"

    echo "→ Benchmark completado. Resultados guardados en: ${RAW_CSV_FILE}"

    AVG_LATENCY=$(awk -F, 'NR > 1 {sum+=$6; count++} END {if (count>0) print sum/count; else print 0}' "$RAW_CSV_FILE")
    
    echo "  ↳ Latencia promedio: ${AVG_LATENCY} ms"
    echo "${workload},${size},${AVG_LATENCY}" >> "$SUMMARY_FILE"
    echo "  ↳ Resumen actualizado: ${SUMMARY_FILE}"

    sleep 2
  done
done

# Detener el servidor
print_header "Paso 3: Deteniendo el servidor"
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "Servidor detenido correctamente."

# Resumen final
print_header "Resumen Final del Experimento 1"
echo "Todos los archivos de resultados detallados se han conservado."
echo "El archivo de resumen para la gráfica está listo en: ${SUMMARY_FILE}"
echo "¡Experimento 1 completado con éxito!"

exit 0
