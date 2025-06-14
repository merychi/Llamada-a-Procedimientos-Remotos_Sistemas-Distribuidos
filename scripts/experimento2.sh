#!/bin/bash

# ==============================================================================
# Script para el Experimento 2: Recuperación y Lectura Fría/Caliente
# ==============================================================================

#  Encontrar la raíz del proyecto y subir un nivel.
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_ROOT" || { echo "Error: No se pudo cambiar al directorio raíz del proyecto."; exit 1; }

#  las rutas a los binarios RELATIVAS A LA RAÍZ DEL PROYECTO.
SERVER_BIN="./lbserver"
CLIENT_BIN="./lbclient"

# --- Configuración del Experimento ---
NUM_KEYS=10000 # número de prueba, debe ser: 10.000.000
VALUE_SIZE=4096
DATA_DIR="./data"
COLD_READ_RESULTS="cold_read_results.csv"
HOT_READ_RESULTS="hot_read_results.csv"

# --- Función para imprimir encabezados bonitos ---
print_header() {
    echo ""
    echo "============================================================"
    echo "=> $1"
    echo "============================================================"
}

# --- Comienzo del Script ---
print_header "Experimento 2: Recuperación y Latencia Fría/Caliente"
echo "Directorio de trabajo actual: $(pwd)"

# --- FASE 1: Limpieza y Preparación ---
print_header "FASE 1: Limpieza y Preparación"
echo "Eliminando datos antiguos"
rm -rf "${DATA_DIR}"
rm -f "${COLD_READ_RESULTS}" "${HOT_READ_RESULTS}"


# --- FASE 2: Población de Datos ---
print_header "FASE 2: Población de Datos"
echo "Poblando la base de datos con ${NUM_KEYS} claves..."
"$SERVER_BIN" > server.log 2>&1 &
SERVER_PID=$!
echo "Servidor iniciado con PID: ${SERVER_PID}"
sleep 3

"$CLIENT_BIN" populate -n=${NUM_KEYS} -valuesize=${VALUE_SIZE}
echo "Población completada."

# Simular el crash
print_header "Simulación de Crash"
echo "Deteniendo el servidor abruptamente..."
kill -9 ${SERVER_PID}
wait ${SERVER_PID} 2>/dev/null
echo "Servidor detenido bruscamente."
sleep 2

# --- FASE 3: Medición del Tiempo de Reinicio ---
print_header "FASE 3: Reinicio y Medición de Recuperación"
START=$(date +%s%3N)
"$SERVER_BIN" > server_recovery.log 2>&1 &
SERVER_PID=$!
END=$(date +%s%3N)
RECOVERY_MS=$((END - START))

echo "Servidor reiniciado con PID: ${SERVER_PID}"
echo "Tiempo de recuperación: ${RECOVERY_MS} ms"
sleep 5

# --- FASE 4: Medición de Lecturas "en Frío" ---
print_header "FASE 4: Benchmark de Lectura 'en Frío'"
"$CLIENT_BIN" benchmark -workload=read-only -ops=1000 -clients=4 -valuesize=${VALUE_SIZE} -out=${COLD_READ_RESULTS}
echo "Lectura en frío completada."

# --- FASE 5: Medición de Lecturas "en Caliente" ---
print_header "FASE 5: Benchmark de Lectura 'en Caliente'"
echo "Esperando 10 segundos antes de la prueba..."
sleep 10
"$CLIENT_BIN" benchmark -workload=read-only -ops=1000 -clients=4 -valuesize=${VALUE_SIZE} -out=${HOT_READ_RESULTS}
echo "Lectura en caliente completada."

# --- FASE 6: Limpieza Final ---
print_header "FASE 6: Limpieza Final"
echo "Deteniendo el servidor..."
kill ${SERVER_PID}
wait ${SERVER_PID} 2>/dev/null
echo "Servidor detenido."

print_header "Experimento 2 Finalizado"
