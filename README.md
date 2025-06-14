# 🚀 Almacén Clave-Valor Distribuido con gRPC  
**Actividad 2.2 de Sistemas Distribuidos**

---

## 📜 Descripción  
Este proyecto implementa un sistema de almacenamiento clave-valor (key-value store) no replicado.  
Está desarrollado en **Go** y utiliza **gRPC** para la comunicación cliente-servidor.  
Su diseño prioriza la **durabilidad**, **concurrencia** y **rendimiento**.

---

## 🎯 Objetivos y Características

- 🔑 **API Funcional:**  
  - `set(key, value)`: almacena o actualiza un par clave-valor.  
  - `get(key)`: recupera el valor de una clave.  
  - `getPrefix(prefix)`: obtiene todos los pares con clave que empieza con un prefijo.

- 🛡️ **Durabilidad y Persistencia:**  
  - Write-Ahead Logging (WAL) para evitar pérdida de datos ante fallos.  
  - Snapshots periódicos para acelerar recuperación y compactar logs.

- ⚙️ **Alta Concurrencia:**  
  - Sharding para dividir la carga.  
  - Bloqueos finos (`RWMutex`) para permitir operaciones paralelas sin conflictos.

- 📊 **Rendimiento Medible:**  
  - Cliente con modo benchmark para medir latencia y throughput.

---

## 🛠 Tecnologías Utilizadas

- **Lenguaje:** Go  
- **Comunicación:** gRPC  
- **Serialización:** Protocol Buffers (Protobuf)  
- **Automatización:** Makefile  
- **Scripts:** Shell (`.sh`) para pruebas y benchmarks  
- **Visualización:** Python (`pandas`, `matplotlib`) para análisis de datos

---

## ⚙️ Cómo probar el programa

### 🔧 Requisitos previos

- Go 1.18+  
- Make  
- Protoc con plugins Go para gRPC

### 🚀 Pasos para compilar y ejecutar

1. **Compilar los archivos de Prueba**  

- Primera Prueba: make test
- Experimento 1:  make experimento1
- Experimento 2:  make experimento2
- Experimento 3:  make experimento3
- Para Graficar resultados: python graficar.py
- Para limpiar archivos generados: make clean


