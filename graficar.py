import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
from matplotlib.ticker import FuncFormatter

# --- Script 1: Gráfica de Latencia vs. Tamaño del Valor ---

def plot_latency_vs_size(csv_file):

    print(f"--- Generando Grafica 1: Latencia vs. Tamaño del Valor ---")
    try:
        # Cargar datos desde el archivo CSV especificado
        data = pd.read_csv(csv_file)
    except FileNotFoundError:
        print(f"Error: El archivo '{csv_file}' no fue encontrado. Asegúrate de que existe.")
        return

    # Configurar el estilo visual de la gráfica
    sns.set_theme(style="whitegrid")
    plt.figure(figsize=(10, 7))

    # Crear la gráfica de líneas usando seaborn para comparar diferentes cargas de trabajo
    plot = sns.lineplot(
        data=data,
        x="ValueSize_bytes",
        y="AvgLatency_ms",
        hue="Workload",  # Crea una línea por cada tipo de "Workload"
        style="Workload",
        markers=True,    # Pone un marcador en cada punto de datos
        dashes=False
    )

    plot.set_xscale('log')

    # Función para formatear las etiquetas del eje X a un formato legible (B, KB, MB)
    def format_bytes(x, pos):
        if x < 1024: return f'{int(x)} B'
        if x < 1024**2: return f'{int(x/1024)} KB'
        if x < 1024**3: return f'{int(x/1024**2)} MB'
        return f'{int(x/1024**3)} GB'
    
    # Aplicar el formateador de etiquetas al eje X
    plot.xaxis.set_major_formatter(FuncFormatter(format_bytes))

    # Añadir títulos y etiquetas para claridad
    plt.title('Latencia de Operación vs. Tamaño del Valor', fontsize=16)
    plt.xlabel('Tamaño del Valor (Escala Logaritmica)', fontsize=12)
    plt.ylabel('Latencia Promedio (milisegundos)', fontsize=12)
    plt.legend(title='Carga de Trabajo')
    plt.grid(which="both", ls="--") # Mostrar rejilla para ambas escalas (mayor y menor)

    # Guardar la figura en un archivo en lugar de mostrarla en una ventana
    output_filename = 'grafica_exp1_latencia_vs_tamano.png'
    plt.savefig(output_filename, dpi=300, bbox_inches='tight')
    plt.close() # Cerrar la figura para liberar memoria y evitar que se muestre

    print(f"Gráfica 1 guardada como '{output_filename}'")


# --- Script 2: Gráfica de Lecturas en Frío vs. Caliente ---

def graficar_experimento_2(cold_file, hot_file):

    print(f"\n--- Generando Grafica 2: Comparación de Lecturas en Frío y Caliente ---")

    # Verificar que los archivos de entrada existan antes de continuar
    if not os.path.exists(cold_file) or not os.path.exists(hot_file):
        print(f"Error: No se encontraron los archivos '{cold_file}' y/o '{hot_file}'.")
        return

    try:
        # Cargar los datos de latencia desde los archivos CSV
        df_frio = pd.read_csv(cold_file)
        df_caliente = pd.read_csv(hot_file)

        # Calcular la latencia promedio (media) para cada condición
        frio_avg = df_frio["latency_ms"].mean()
        caliente_avg = df_caliente["latency_ms"].mean()
    except Exception as e:
        print(f"Ocurrio un error al procesar los archivos CSV: {e}")
        return

    # Configurar el estilo de la gráfica
    sns.set_theme(style="whitegrid")
    plt.figure(figsize=(8, 6))

    labels = ["Lectura en Frío\n(Tras Reinicio)", "Lectura en Caliente\n(Caché Poblada)"]
    values = [frio_avg, caliente_avg]
    
    # Crear el gráfico de barras
    bars = plt.bar(labels, values, color=['#4c72b0', '#55a868'])

    # Añadir el valor exacto encima de cada barra para mayor claridad
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2.0, yval, f'{yval:.3f} ms', va='bottom', ha='center')

    # Añadir títulos y etiquetas
    plt.ylabel("Latencia Promedio (milisegundos)", fontsize=12)
    plt.title("Comparacion de Latencia: Lecturas en Frío vs. en Caliente", fontsize=16, pad=20)
    plt.ylim(0, max(values) * 1.2)

    # Guardar la gráfica en un archivo y cerrar la figura
    output_filename = "grafica_exp2_frio_vs_caliente.png"
    plt.savefig(output_filename, dpi=300, bbox_inches='tight')
    plt.close()

    print(f"Grafica 2 guardada como '{output_filename}'")


# --- Script 3: Gráfica de Latencia vs. Throughput ---

def plot_latency_vs_throughput(csv_file):

    print(f"\n--- Generando Grafica 3: Latencia vs. Throughput ---")
    try:
        # Cargar los datos desde el archivo CSV
        data = pd.read_csv(csv_file)
    except FileNotFoundError:
        print(f"Error: El archivo '{csv_file}' no fue encontrado.")
        return

    # Configurar el estilo visual
    sns.set_theme(style="whitegrid")
    plt.figure(figsize=(12, 8))

    # Crear la gráfica de dispersión (scatterplot)
    sns.scatterplot(
        data=data,
        x="Throughput_ops_s",
        y="AvgLatency_ms",
        hue="Workload",  # Colorear puntos según la carga de trabajo
        style="Workload", # Usar diferentes marcadores según la carga
        s=150
    )

    # Añadir etiquetas de texto a cada punto para identificar el número de clientes
    for i in range(data.shape[0]):
        plt.text(
            x=data.Throughput_ops_s[i] + data.Throughput_ops_s.max() * 0.01,
            y=data.AvgLatency_ms[i],
            s=f'{data.NumClients[i]}c', # Texto a mostrar, ej: "8c"
            fontdict=dict(color='black', size=10)
        )

    # Añadir títulos y etiquetas
    plt.title('Rendimiento del Sistema: Latencia vs. Throughput', fontsize=16)
    plt.xlabel('Rendimiento (Operaciones por Segundo)', fontsize=12)
    plt.ylabel('Latencia Promedio (milisegundos)', fontsize=12)
    plt.legend(title='Carga de Trabajo')
    plt.xlim(left=0)
    plt.ylim(bottom=0)
    
    # Guardar la gráfica en un archivo de imagen 
    output_filename = 'grafica_exp3_latencia_vs_throughput.png'
    plt.savefig(output_filename, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"Gráfica 3 guardada como '{output_filename}'")


# --- Bloque principal de ejecución ---

def main():
    print("Iniciando la generación de todas las gráficas...")
    
    # Llamar a la función para la primera gráfica
    plot_latency_vs_size('results_exp1_summary.csv')

    # Llamar a la función para la segunda gráfica
    graficar_experimento_2(cold_file="cold_read_results.csv", hot_file="hot_read_results.csv")
    
    # Llamar a la función para la tercera gráfica
    plot_latency_vs_throughput('results_exp3_summary.csv')
    
    print("\nProceso completado. Todas las graficas han sido guardadas como archivos .png.")

if __name__ == '__main__':
    main()