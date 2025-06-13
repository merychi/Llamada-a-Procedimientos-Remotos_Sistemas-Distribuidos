#!/bin/bash

# ==============================================================================
# Script para el Experimento 2: Recuperación y Lectura Fría/Caliente
# ==============================================================================

# 1. Encontrar la raíz del proyecto  y subir un nivel.
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# 2. Definir las rutas a los binarios RELATIVAS A LA RAÍZ DEL PROYECTO.
SERVER_BIN="./lbserver"
CLIENT_BIN="./lbclient"

# 3. Moverse a la raíz del proyecto para que todos los comandos y archivos funcionen correctamente.
cd "$PROJECT_ROOT" || { echo "Error: No se pudo cambiar al directorio raíz del proyecto."; exit 1; }

# --- Configuración del Experimento ---
NUM_KEYS=10000 #numero de prueba, debe ser: 10.000.000
VALUE_SIZE=4096
DATA_DIR="./data"
COLD_READ_RESULTS="cold_read_results.csv"
HOT_READ_RESULTS="hot_read_results.csv"

# --- Comienzo del Script ---
echo "--- Iniciando Experimento 2: Recuperación y Latencia Fría/Caliente ---"
echo "Directorio de trabajo actual: $(pwd)"

# --- FASE 1: Limpieza y Preparación ---
echo "[FASE 1] Limpiando datos antiguos y compilando..."
rm -rf ${DATA_DIR}
rm -f ${COLD_READ_RESULTS} ${HOT_READ_RESULTS}
make client server

# --- FASE 2: Población de Datos ---
echo "[FASE 2] Poblando la base de datos con ${NUM_KEYS} claves..."
# Ahora usamos la variable con la ruta correcta al servidor
"$SERVER_BIN" &
SERVER_PID=$!
echo "Servidor iniciado con PID: ${SERVER_PID}"
sleep 3

"$CLIENT_BIN" populate -n=${NUM_KEYS} -valuesize=${VALUE_SIZE}
echo "Población completada."

# Simular el crash
echo "Simulando un 'crash' del servidor..."
kill -9 ${SERVER_PID}
wait ${SERVER_PID} 2>/dev/null
echo "Servidor detenido bruscamente."
sleep 2

# --- FASE 3: Medición del Tiempo de Reinicio ---
echo "[FASE 3] Reiniciando el servidor y midiendo el tiempo de recuperación..."
START=$(date +%s%3N)
"$SERVER_BIN" > server_recovery.log 2>&1 &
SERVER_PID=$!
END=$(date +%s%3N)
RECOVERY_MS=$((END - START))

echo "Servidor reiniciado con PID: ${SERVER_PID}"
echo "Tiempo de recuperación: ${RECOVERY_MS} ms"

sleep 5

# --- FASE 4: Medición de Lecturas "en Frío" ---
echo "[FASE 4] Ejecutando benchmark de lectura 'en frío'..."
"$CLIENT_BIN" benchmark -workload=read-only -ops=1000 -clients=4 -valuesize=${VALUE_SIZE} -out=${COLD_READ_RESULTS}
echo "Se quedo congelado1?"

# --- FASE 5: Medición de Lecturas "en Caliente" ---
echo "[FASE 5] Esperando 10 segundos y ejecutando benchmark de lectura 'en caliente'..."
sleep 10
"$CLIENT_BIN" benchmark -workload=read-only -ops=1000 -clients=4 -valuesize=${VALUE_SIZE} -out=${HOT_READ_RESULTS}
echo "Se quedo congelado2?"

# --- FASE 6: Limpieza Final ---
echo "[FASE 6] Experimento completado. Deteniendo el servidor..."
kill ${SERVER_PID}
wait ${SERVER_PID} 2>/dev/null
echo "Se quedo congelado3?"
echo "--- Experimento 2 Finalizado ---"