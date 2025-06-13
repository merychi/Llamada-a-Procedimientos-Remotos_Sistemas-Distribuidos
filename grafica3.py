import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def plot_latency_vs_throughput(csv_file):
    """
    Lee los datos del benchmark desde un archivo CSV y genera una gráfica
    de latencia vs. throughput.
    """
    try:
        # Cargar los datos usando pandas
        data = pd.read_csv(csv_file)
    except FileNotFoundError:
        print(f"Error: El archivo '{csv_file}' no fue encontrado.")
        print("Asegúrate de ejecutar primero el script de benchmark (run_exp3.sh).")
        return

    # Configurar el estilo de la gráfica para que se vea profesional
    sns.set_theme(style="whitegrid")
    plt.figure(figsize=(12, 8))

    # Crear la gráfica de dispersión (scatter plot)
    # - x: Eje X será el Throughput
    # - y: Eje Y será la Latencia Promedio
    # - hue: Colorea los puntos según la carga de trabajo (Workload)
    # - style: Usa diferentes marcadores para cada carga de trabajo
    # - s: Aumenta el tamaño de los puntos para mejor visibilidad
    plot = sns.scatterplot(
        data=data,
        x="Throughput_ops_s",
        y="AvgLatency_ms",
        hue="Workload",
        style="Workload",
        s=150  # Tamaño de los puntos
    )

    # Añadir etiquetas de texto a cada punto para saber a qué número de clientes corresponde
    for i in range(data.shape[0]):
        plt.text(
            x=data.Throughput_ops_s[i] + data.Throughput_ops_s.max() * 0.01, # Posición X del texto
            y=data.AvgLatency_ms[i], # Posición Y del texto
            s=f'{data.NumClients[i]}c', # El texto a mostrar (ej: "8c" para 8 clientes)
            fontdict=dict(color='black', size=10)
        )

    # Configurar títulos y etiquetas de los ejes
    plt.title('Rendimiento del Sistema: Latencia vs. Throughput', fontsize=16)
    plt.xlabel('Rendimiento (Operaciones por Segundo)', fontsize=12)
    plt.ylabel('Latencia Promedio (milisegundos)', fontsize=12)
    plt.legend(title='Carga de Trabajo')

    # Ajustar límites para que la gráfica no empiece pegada a los ejes
    plt.xlim(left=0)
    plt.ylim(bottom=0)
    
    # Guardar la gráfica en un archivo y mostrarla
    output_filename = 'grafica_latencia_vs_throughput.png'
    plt.savefig(output_filename, dpi=300)
    print(f"Gráfica guardada como '{output_filename}'")
    
    plt.show()

if __name__ == '__main__':
    # Nombre del archivo CSV generado por el script de bash
    summary_file = 'results_exp3_summary.csv'
    plot_latency_vs_throughput(summary_file)