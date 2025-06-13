import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def plot_latency_vs_size(csv_file):
    try:
        data = pd.read_csv(csv_file)
    except FileNotFoundError:
        print(f"Error: El archivo '{csv_file}' no fue encontrado. Ejecuta el script de benchmark primero.")
        return

    sns.set_theme(style="whitegrid")
    plt.figure(figsize=(10, 7))

    # Usamos lineplot, que es ideal para mostrar una tendencia sobre una variable continua
    plot = sns.lineplot(
        data=data,
        x="ValueSize_bytes",
        y="AvgLatency_ms",
        hue="Workload",  # Crea una línea por cada valor en la columna "Workload"
        style="Workload",
        markers=True,    # Pone un marcador en cada punto de datos
        dashes=False
    )

    # ¡LA CLAVE! Usar escala logarítmica para el eje X
    plot.set_xscale('log')

    # Mejorar las etiquetas del eje X para que sean legibles (ej: "4 KB", "1 MB")
    from matplotlib.ticker import FuncFormatter
    def format_bytes(x, pos):
        if x < 1024: return f'{int(x)} B'
        if x < 1024**2: return f'{int(x/1024)} KB'
        if x < 1024**3: return f'{int(x/1024**2)} MB'
        return f'{int(x/1024**3)} GB'
    plot.xaxis.set_major_formatter(FuncFormatter(format_bytes))

    plt.title('Latencia de Operación vs. Tamaño del Valor', fontsize=16)
    plt.xlabel('Tamaño del Valor (Escala Logarítmica)', fontsize=12)
    plt.ylabel('Latencia Promedio (milisegundos)', fontsize=12)
    plt.legend(title='Carga de Trabajo')
    plt.grid(which="both", ls="--") # Rejilla para escalas logarítmicas

    output_filename = 'grafica_exp1_latencia_vs_tamano.png'
    plt.savefig(output_filename, dpi=300)
    print(f"Gráfica guardada como '{output_filename}'")
    plt.show()

if __name__ == '__main__':
    plot_latency_vs_size('results_exp1_summary.csv')