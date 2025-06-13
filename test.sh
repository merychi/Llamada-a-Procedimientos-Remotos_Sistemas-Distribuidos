#!/bin/bash

# ==============================================================================
# Script de Prueba Simple para el Servidor Key-Value
# - Inicia el servidor en segundo plano.
# - Lanza 10 clientes concurrentes que realizan operaciones.
# - Espera a que los clientes terminen.
# - Pide y muestra las estadísticas finales del servidor.
# - Detiene el servidor de forma limpia.
# ==============================================================================

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# --- Configuración ---
SERVER_BIN="./lbserver"
CLIENT_BIN="./lbclient"
NUM_CLIENTS=10
OPS_PER_CLIENT=1000 # 10K en total (10 clientes * 1000 ops)

# Función para limpiar procesos anteriores si el script falló
cleanup() {
    echo -e "${YELLOW}Limpiando procesos de servidor anteriores...${NC}"
    pkill -f $SERVER_BIN
    # Esperar un poco para asegurarse de que el puerto se libere
    sleep 1
}

# --- Ejecución Principal ---

# 1. Compilar todo usando el Makefile
echo -e "${YELLOW}Paso 1: Compilando el proyecto...${NC}"
make
if [ $? -ne 0 ]; then
    echo "Error en la compilación. Abortando."
    exit 1
fi
echo -e "${GREEN}Compilación exitosa.${NC}"
echo ""

# Limpiar cualquier instancia del servidor que pudiera haber quedado colgada
cleanup

# 2. Iniciar el servidor
echo -e "${YELLOW}Paso 2: Iniciando el servidor en segundo plano...${NC}"
$SERVER_BIN &
SERVER_PID=$!
SERVER_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")

# Dar un momento al servidor para que arranque completamente
sleep 2

# Verificar si el servidor sigue corriendo
if ! ps -p $SERVER_PID > /dev/null; then
   echo "Error: El servidor no pudo iniciarse. Abortando."
   exit 1
fi
echo -e "${GREEN}Servidor iniciado exitosamente.${NC}"
echo "   - PID: $SERVER_PID"
echo "   - Hora de inicio: $SERVER_START_TIME"
echo ""

# 3. Lanzar clientes concurrentes
echo -e "${YELLOW}Paso 3: Lanzando $NUM_CLIENTS clientes, cada uno con $OPS_PER_CLIENT operaciones...${NC}"
for i in $(seq 1 $NUM_CLIENTS); do
    # Cada cliente realiza una mezcla de operaciones en segundo plano
    (
      for j in $(seq 1 $OPS_PER_CLIENT); do
        key="cliente${i}_clave${j}"
        value="valor_de_prueba_${i}_${j}"
        
        # Mezcla de operaciones: 50% set, 49% get, 1% getprefix
        op_rand=$((1 + RANDOM % 100))
        if [ $op_rand -le 50 ]; then
            $CLIENT_BIN set "$key" "$value" > /dev/null
        elif [ $op_rand -le 99 ]; then
            $CLIENT_BIN get "$key" > /dev/null
        else
            $CLIENT_BIN getprefix "cliente${i}" > /dev/null
        fi
      done
      echo "   - Cliente $i terminó."
    ) &
done

# Esperar a que todos los procesos de los clientes en segundo plano terminen
wait
echo -e "${GREEN}Todos los clientes han completado sus operaciones.${NC}"
echo ""

# 4. Obtener y mostrar estadísticas finales
echo -e "${YELLOW}Paso 4: Obteniendo estadísticas finales del servidor...${NC}"
STATS_OUTPUT=$($CLIENT_BIN stats)

# El enunciado pide mostrar estos valores específicos
TOTAL_SETS=$(echo "$STATS_OUTPUT" | grep "Operaciones Set" | awk '{print $3}')
TOTAL_GETS=$(echo "$STATS_OUTPUT" | grep "Operaciones Get" | awk '{print $3}')
TOTAL_GETPREFIXES=$(echo "$STATS_OUTPUT" | grep "Operaciones GetPrefix" | awk '{print $3}')

echo -e "${GREEN}--- Estadísticas Requeridas ---${NC}"
echo "Hora de inicio del servidor:   $SERVER_START_TIME"
echo "#total_sets completados:       $TOTAL_SETS"
echo "#total_gets completados:       $TOTAL_GETS"
echo "#total_getprefixes completados: $TOTAL_GETPREFIXES"
echo -e "${GREEN}-------------------------------${NC}"
echo ""


# 5. Detener el servidor
echo -e "${YELLOW}Paso 5: Deteniendo el servidor...${NC}"
kill $SERVER_PID
# Esperar a que el proceso del servidor termine realmente
wait $SERVER_PID 2>/dev/null
echo -e "${GREEN}Servidor detenido. Prueba completada.${NC}"