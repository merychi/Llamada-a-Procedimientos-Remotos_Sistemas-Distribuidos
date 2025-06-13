#!/bin/bash

# ==============================================================================
# SCRIPT DE PRUEBA PARA EL SERVIDOR KEY-VALUE (v4)
# - Compila los binarios en la raíz del proyecto.
# - Nombres de binarios: Ibserver e Ibclient.
# ==============================================================================

# --- Configuración ---
SERVER_SRC_DIR="./server"
CLIENT_SRC_DIR="./client"

# Nombres de los binarios de salida (en la raíz del proyecto)
SERVER_BIN="./lbserver"
CLIENT_BIN="./lbclient"

# Archivos de salida
SERVER_LOG="server.log"
DATA_DIR="./data"

# Parámetros de la prueba
NUM_CLIENTS=10
OPS_PER_CLIENT=1000 # 10 clientes * 1000 ops = 10K operaciones totales

# --- Funciones de Utilidad ---
print_header() {
    echo ""
    echo "============================================================"
    echo "=> $1"
    echo "============================================================"
}

# --- 1. Limpieza y Preparación ---
print_header "Paso 1: Limpiando y Preparando el Entorno"
echo "Limpiando artefactos de ejecuciones anteriores..."
# Se eliminan los binarios de la raíz, el directorio de datos y los logs.
rm -f "$SERVER_BIN" "$CLIENT_BIN" "$SERVER_LOG" benchmark_results.csv
rm -rf "$DATA_DIR"

# --- 2. Compilación ---
print_header "Paso 2: Compilando el Servidor y el Cliente"
echo "Compilando el servidor desde '$SERVER_SRC_DIR' -> $SERVER_BIN"
go build -o "$SERVER_BIN" "$SERVER_SRC_DIR"

echo "Compilando el cliente desde '$CLIENT_SRC_DIR' -> $CLIENT_BIN"
go build -o "$CLIENT_BIN" "$CLIENT_SRC_DIR"

if [ ! -f "$SERVER_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    echo "Error: La compilación falló."
    exit 1
fi
echo "Compilación completada."

# --- 3. Iniciar el Servidor ---
print_header "Paso 3: Iniciando el Servidor"
SERVER_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
# Ejecutar el binario desde la raíz
./"$SERVER_BIN" > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!
sleep 2
if ! ps -p $SERVER_PID > /dev/null; then
   echo "Error: ¡El servidor no pudo iniciarse! Revisa el log: $SERVER_LOG"
   exit 1
fi
echo "Servidor iniciado con éxito (PID: $SERVER_PID)."

# --- 4. Ejecutar Clientes de Prueba de Carga (SET/GET) ---
print_header "Paso 4: Ejecutando Prueba de Carga (SET/GET)"
echo "Iniciando $NUM_CLIENTS clientes, cada uno con $OPS_PER_CLIENT operaciones..."
# Ejecutar el binario desde la raíz
./"$CLIENT_BIN" benchmark -clients $NUM_CLIENTS -ops $OPS_PER_CLIENT -workload "50-50"
echo "Prueba de carga completada."

# --- 4.5. Ejecutar Prueba de GetPrefix ---
print_header "Paso 4.5: Ejecutando Prueba de GetPrefix"
PREFIX_TO_SEARCH="bench-w0-"
echo "Buscando claves con el prefijo: '$PREFIX_TO_SEARCH'..."
# Ejecutar el binario desde la raíz
./"$CLIENT_BIN" getprefix "$PREFIX_TO_SEARCH" > /dev/null
echo "Prueba de GetPrefix completada."

# --- 5. Obtener Estadísticas Finales ---
print_header "Paso 5: Obteniendo Estadísticas Finales"
# Ejecutar el binario desde la raíz
STATS_OUTPUT=$(./"$CLIENT_BIN" stats)

TOTAL_SETS=$(echo "$STATS_OUTPUT"     | awk '/Operaciones Set/ {print $NF}')
TOTAL_GETS=$(echo "$STATS_OUTPUT"     | awk '/Operaciones Get/ {print $NF}')
TOTAL_PREFIXES=$(echo "$STATS_OUTPUT" | awk '/Operaciones GetPrefix/ {print $NF}')

TOTAL_SETS=${TOTAL_SETS:-0}
TOTAL_GETS=${TOTAL_GETS:-0}
TOTAL_PREFIXES=${TOTAL_PREFIXES:-0}

# --- 6. Detener el Servidor ---
print_header "Paso 6: Deteniendo el Servidor"
echo "Enviando señal de terminación al servidor (PID: $SERVER_PID)..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "Servidor detenido."

# --- 7. Reporte Final ---
print_header "Resumen Final de la Prueba"
echo "Hora de inicio del servidor:    $SERVER_START_TIME"
echo "#total_sets completados:        $TOTAL_SETS"
echo "#total_gets completados:        $TOTAL_GETS"
echo "#total_getprefixes completados: $TOTAL_PREFIXES"
echo ""
echo "¡Prueba finalizada!"

exit 0