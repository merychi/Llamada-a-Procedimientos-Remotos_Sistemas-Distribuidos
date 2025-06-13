import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

def graficar_experimento_2(cold_file="cold_read_results.csv", hot_file="hot_read_results.csv"):
    """
    Genera un gráfico de barras comparando la latencia promedio de lecturas
    en frío y en caliente a partir de dos archivos CSV.
    """
    print("--- Graficando Experimento 2: Comparación de Lecturas en Frío y Caliente ---")

    # --- Verificación de archivos ---
    # Comprobar si los archivos de datos necesarios existen antes de continuar.
    if not os.path.exists(cold_file) or not os.path.exists(hot_file):
        print(f"Error: No se encontraron los archivos de datos '{cold_file}' y/o '{hot_file}'.")
        print("Por favor, asegúrate de haber ejecutado el script 'run_exp2.sh' primero.")
        return

    try:
        # --- Carga y Procesamiento de Datos ---
        # Cargar los datos de latencia desde los archivos CSV.
        df_frio = pd.read_csv(cold_file)
        df_caliente = pd.read_csv(hot_file)

        # Calcular la latencia promedio (media) para cada condición.
        frio_avg = df_frio["latency_ms"].mean()
        caliente_avg = df_caliente["latency_ms"].mean()
        
        print(f"Latencia promedio (Fría):  {frio_avg:.4f} ms")
        print(f"Latencia promedio (Caliente): {caliente_avg:.4f} ms")

    except Exception as e:
        print(f"Ocurrió un error al procesar los archivos CSV: {e}")
        return

    # --- Creación de la Gráfica ---
    # Configurar un estilo visual agradable para la gráfica.
    sns.set_theme(style="whitegrid")
    plt.figure(figsize=(8, 6))

    # Definir las etiquetas y los valores para las barras.
    labels = ["Lectura en Frío\n(Tras Reinicio)", "Lectura en Caliente\n(Caché Poblada)"]
    values = [frio_avg, caliente_avg]
    colors = ['#4c72b0', '#55a868'] # Tonos de azul y verde más profesionales.

    # Crear el gráfico de barras.
    bars = plt.bar(labels, values, color=colors)

    # Añadir etiquetas de valor encima de cada barra para mayor claridad.
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2.0, yval, f'{yval:.3f} ms', va='bottom', ha='center')

    # --- Configuración de Títulos y Etiquetas ---
    plt.ylabel("Latencia Promedio (milisegundos)", fontsize=12)
    plt.title("Comparación de Latencia: Lecturas en Frío vs. en Caliente", fontsize=16, pad=20)
    plt.ylim(0, max(values) * 1.2) # Ajustar el límite del eje Y para que haya espacio para el texto.

    # --- Guardado y Finalización ---
    output_filename = "grafica_exp2_frio_vs_caliente.png"
    plt.savefig(output_filename, dpi=300, bbox_inches='tight')
    plt.close() # Cierra la figura para liberar memoria.

    print(f"\n¡Éxito! Gráfica guardada como '{output_filename}'")
    print("--------------------------------------------------------------------")


if __name__ == '__main__':
    # Esta función se ejecutará cuando corras el script directamente desde la terminal.
    graficar_experimento_2()