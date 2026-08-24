# Titofy (v2.2)

Titofy es un reproductor y generador de letras sincronizadas (.lrc) para la terminal. Funciona de forma híbrida: busca letras oficiales en internet y las sincroniza con tu archivo de audio local usando Whisper (IA), o transcribe canciones desde cero de forma 100% offline.

Incluye:
- **CLI / TUI**: Menú interactivo, reproductor con sincronización de letras y visualizador de espectro de audio (FFT de 112 bandas).
- **Motor Híbrido & Backend**: Búsqueda en proveedores online (LRCLIB, Lyrics.ovh), alineación forzada (Forced Alignment) y transcripción local con `faster-whisper`.
- **API FastAPI**: Microservicio local para procesar o consultar letras por HTTP (`http://127.0.0.1:8642`).
- **Desktop (Flutter)**: Interfaz gráfica en desarrollo.

---

## Novedades de la v2.2

### 1. Motor Híbrido de Letras (3 niveles)
Cuando pides las letras de una canción en modo automático, el sistema sigue este orden:

```text
1. LRCLIB (Online) ──────────► ¿Tiene letra sincronizada? ──► Descarga y calibra con tu audio.
                                      │ (No)
2. Lyrics.ovh (Online) ──────► ¿Tiene texto plano? ────────► Descarga texto y alinea con tu audio.
                                      │ (No)
3. Whisper (Local Offline) ──► Transcribe el audio desde cero con IA local.
```

- **Por qué se hace así**: Muchas letras de internet están sincronizadas con el video oficial de YouTube (que suele tener intros largas o diálogos). Al descargar el texto y calibrarlo con tu archivo local mediante *Forced Alignment* (~1.5s en GPU), las marcas de tiempo coinciden exactamente con tu archivo específico.
- **Sin base de datos de caché**: Se eliminó SQLite (`lyrics_cache.db`). El archivo `.lrc` guardado en disco es la única referencia. Al elegir "Regenerar", el sistema siempre busca o procesa de forma limpia.

### 2. Formateador de nombres y múltiples artistas
Los archivos descargados suelen tener nombres con ruido o formatos variados (`Artista1_ Artista2 - Cancion (Official Video)(1080P_HD).mp3`).
- Limpia etiquetas de video, resolución y bitrate (`(1080P_HD)`, `[4K]`, `(MP3_160K)`, etc.).
- Separa colaboradores por `_`, `,`, `&`, `x`, `feat`, `ft`.
- Genera consultas alternativas automáticas (artista principal, colaboradores juntos, solo el segundo artista, título primero) para asegurar resultados en las APIs.

### 3. Mapeo de estrofas y saltos de línea
- En lugar de juntar versos según los silencios del audio, el alineador mapea las marcas de tiempo de Whisper directamente sobre las líneas del texto original.
- Mantiene los saltos de línea y la estructura de estrofas intacta.
- Detecta intros habladas o instrumentales largas (> 8s) y evita colocar letras sobre diálogos que no corresponden a la canción.

### 4. Limpieza de terminal
- Al salir con `Ctrl + C` o `Esc`, se limpian los buffers de la terminal y se cierran los procesos en segundo plano (`ffplay`, backend) sin dejar residuos en la pantalla.

---

## Estructura del proyecto

```text
titofy/
├── backend/                     → Motor Python (Whisper, alineación, API)
│   ├── api_server.py            → Servidor FastAPI local
│   ├── lyrics/                  → Motor híbrido y proveedores online
│   │   ├── resolver.py          → Resolución jerárquica (3 niveles)
│   │   ├── normalizer.py        → Limpieza de nombres y permutaciones
│   │   └── providers/           → LRCLIB y Lyrics.ovh
│   ├── whisper_engine/          → Transcripción y Forced Alignment
│   │   ├── align.py             → Alineación de texto con audio
│   │   └── transcribe.py        → Transcripción por segmentos
│   ├── postprocess/             → Filtros de texto y repeticiones
│   └── requirements.txt
│
├── cli/                         → Interfaz de terminal en Node.js
│   ├── index.js                 → Punto de entrada CLI
│   ├── src/
│   │   ├── ascii-player/        → Visualizador espectral de 112 bandas
│   │   ├── player.js            → Reproductor de terminal
│   │   └── ui/                  → Menús y acciones
│   └── package.json
│
├── desktop/                     → App gráfica en Flutter (en desarrollo)
└── README.md
```

---

## Requisitos

- **Node.js**: v18 o superior.
- **Python**: 3.10 o superior (recomendado 3.11/3.12).
- **FFmpeg**: Instalado y disponible en el PATH del sistema (`ffmpeg` y `ffplay`).

---

## Instalación

### 1. Clonar el repositorio
```bash
git clone https://github.com/tu-usuario/titofy.git
cd titofy
```

### 2. Configurar backend
```bash
cd backend
python3 -m venv .venv

# Linux / macOS:
source .venv/bin/activate

# Windows:
.venv\Scripts\activate

pip install -r requirements.txt
```

### 3. Configurar CLI
```bash
cd ../cli
npm install
```

---

## Uso

### Iniciar la CLI
```bash
cd cli
npm start
```

Opciones disponibles en el menú:
1. **Explorar música**: Escanea tu carpeta de música configurada.
2. **Obtener letras (Modo Híbrido)**: Busca online, calibra con tu archivo y guarda el `.lrc`.
3. **Generar solo con Whisper**: Transcripción offline eligiendo modelo (`base`, `small`, `turbo`).
4. **Forced Alignment**: Sincroniza un `.txt` con tu audio.
5. **Reproducir**: Modo normal o Visualizador ASCII espectral.

### Modelos de Whisper

| Modelo | Velocidad (GPU)* | Velocidad (CPU)* | RAM/VRAM | Uso |
| :--- | :---: | :---: | :---: | :--- |
| **`base`** | ~1-2s | ~10s | ~1 GB | Ideal para Forced Alignment y pruebas rápidas. |
| **`small`** | ~2-4s | ~20s | ~2 GB | Buen balance de precisión para transcribir. |
| **`turbo`** | ~3-5s | ~30s | ~4 GB | Mayor precisión para canciones complejas. |

*\* Tiempos aproximados para audios de ~3.5 minutos.*

---

## API Local

Para iniciar el servidor manualmente:
```bash
cd backend
python api_server.py
```

Endpoints principales en `http://127.0.0.1:8642`:
- `POST /lyrics/resolve`: Resuelve letras mediante el motor híbrido.
- `POST /transcribe`: Transcribe un audio con Whisper.
- `POST /align`: Alinea texto con un archivo de audio.
- `GET /health`: Estado del servidor.

Documentación interactiva disponible en `http://127.0.0.1:8642/docs`.

---

## Licencia

GNU General Public License v3.0 (GPL-3.0). Consulta el archivo [LICENSE](LICENSE) para más detalles.