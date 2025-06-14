#!/bin/bash

# ==============================================================================
# Script de Prueba General para el Servidor Key-Value
# ==============================================================================

#  Encontrar la raíz del proyecto y moverse a ella.
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT" || { echo "Error: No se pudo cambiar al directorio raíz del proyecto."; exit 1; }

# Definir las rutas a los binarios.
SERVER_BIN="./lbserver"
CLIENT_BIN="./lbclient"

# Comprobar si los binarios existen.
if [ ! -f "$SERVER_BIN" ] && [ -f "$SERVER_BIN.exe" ]; then SERVER_BIN="./lbserver.exe"; fi
if [ ! -f "$CLIENT_BIN" ] && [ -f "$CLIENT_BIN.exe" ]; then CLIENT_BIN="./lbclient.exe"; fi

if [ ! -f "$SERVER_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    echo "Error: Los binarios no se encontraron. Asegúrate de haber compilado con 'make'."
    exit 1
fi

# Configuración de ejecución
SERVER_LOG="$PROJECT_ROOT/server.log"
DATA_DIR="$PROJECT_ROOT/data"
NUM_CLIENTS=10
OPS_PER_CLIENT=1000 # 10 clientes * 1000 ops = 10K operaciones

# --- Función para imprimir encabezados bonitos ---
print_header() {
    echo ""
    echo "============================================================"
    echo "=> $1"
    echo "============================================================"
}

# --- Paso 1: Limpieza ---
print_header "Paso 1: Limpieza del Entorno"
rm -f "$SERVER_LOG" benchmark_results.csv
rm -rf "$DATA_DIR"

# --- Paso 2: Iniciar el Servidor ---
print_header "Paso 2: Iniciando el Servidor"
SERVER_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
"$SERVER_BIN" > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!
sleep 2

if ! ps -p $SERVER_PID > /dev/null; then
   echo "Error: El servidor no pudo iniciarse. Revisa el log: $SERVER_LOG"
   exit 1
fi
echo "Servidor iniciado con éxito (PID: $SERVER_PID)"

# --- Paso 3: Prueba de Carga (SET/GET) ---
print_header "Paso 3: Ejecutando Prueba de Carga (SET/GET)"
"$CLIENT_BIN" benchmark -clients $NUM_CLIENTS -ops $OPS_PER_CLIENT -workload "50-50"
echo "Carga completada."

# --- Paso 4: Prueba de GetPrefix ---
print_header "Paso 4: Ejecutando Prueba de GetPrefix"
PREFIX_TO_SEARCH="bench-w0-"
"$CLIENT_BIN" getprefix "$PREFIX_TO_SEARCH" > /dev/null
echo "GetPrefix completado."

# --- Paso 5: Estadísticas Finales ---
print_header "Paso 5: Obteniendo Estadísticas"
STATS_OUTPUT=$("$CLIENT_BIN" stats)

TOTAL_SETS=$(echo "$STATS_OUTPUT"     | awk '/Operaciones Set/ {print $NF}')
TOTAL_GETS=$(echo "$STATS_OUTPUT"     | awk '/Operaciones Get/ {print $NF}')
TOTAL_PREFIXES=$(echo "$STATS_OUTPUT" | awk '/Operaciones GetPrefix/ {print $NF}')

TOTAL_SETS=${TOTAL_SETS:-0}
TOTAL_GETS=${TOTAL_GETS:-0}
TOTAL_PREFIXES=${TOTAL_PREFIXES:-0}

# --- Paso 6: Detener el Servidor ---
print_header "Paso 6: Deteniendo el Servidor"
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "Servidor detenido."

# --- Paso 7: Resumen Final ---
print_header "Resumen Final de la Prueba"
echo "Hora de inicio del servidor:    $SERVER_START_TIME"
echo "#total_sets completados:        $TOTAL_SETS"
echo "#total_gets completados:        $TOTAL_GETS"
echo "#total_getprefixes completados: $TOTAL_PREFIXES"
echo ""
echo "¡Prueba finalizada!"

exit 0
