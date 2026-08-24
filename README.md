# 🎵 Titofy v2.2 — Suite de Letras Sincronizadas y Motor Híbrido

**Titofy** es una herramienta para obtener, calibrar, transcribir y reproducir letras de canciones (`.lrc`) sincronizadas con archivos locales de audio, además de incluir un visualizador espectral en tiempo real.

Incluye:
- **CLI (Terminal TUI)**: Reproductor de letras con scroll continuo y visualizador FFT de 112 bandas Truecolor.
- **Motor Híbrido & API FastAPI**: Búsqueda remota (LRCLIB / Lyrics.ovh), calibración mediante **Forced Alignment** y transcripción offline con **faster-whisper** (CTranslate2) en GPU/CPU.
- **App Desktop (Flutter)**: Interfaz gráfica nativa para Linux y Windows (en desarrollo).

---

## ✨ Novedades en v2.2

La versión 2.2 implementa una arquitectura híbrida de resolución en 3 niveles, normalización de metadatos multi-artista y alineación por palabra para evitar desfases temporales.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 PIPELINE DE RESOLUCIÓN                                 │
│                                                                                        │
│   [Audio Local] ──► Normalizador Multi-Artista ──► Generación de 5 Consultas           │
│                              │                                                         │
│       ┌──────────────────────┴──────────────────────┐                                  │
│       ▼                                             ▼                                  │
│  [NIVEL 1: LRCLIB]                             [NIVEL 2: Lyrics.ovh]                   │
│  Sincronización remota (<0.5s)                 Texto plano                             │
│       │                                             │                                  │
│       └──────────────────────┬──────────────────────┘                                  │
│                              ▼                                                         │
│               [CALIBRACIÓN: Forced Alignment]                                          │
│               Alineación de texto plano con el audio local (~1.5s)                     │
│                              │ (Si no hay coincidencias online)                        │
│                              ▼                                                         │
│               [NIVEL 3: Whisper Local (Offline)]                                       │
│               Transcripción completa con faster-whisper                                │
│                              │                                                         │
│                              ▼                                                         │
│               [Archivo .lrc local]                                                     │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Arquitectura del Motor Híbrido

### Niveles de Resolución

| Nivel | Método | Tiempo estimado (GPU) | Comportamiento |
| :---: | :--- | :---: | :--- |
| **1** | **LRCLIB** | `< 0.5s` | Descarga timestamps listos. Se activa en primera instancia. |
| **2** | **Lyrics.ovh + Forced Alignment** | `~ 1.5s` | Si solo existe letra en texto plano, Whisper alinea cada línea con el audio local. |
| **3** | **Whisper Local** | `~ 2-5s` | Fallback offline si la pista no existe en las APIs remotas. |

- **Nivel 1 (LRCLIB)**: Búsqueda estricta y difusa en endpoints `/api/get` y `/api/search`. Genera el archivo `.lrc` directamente si hay coincidencia temporal.
- **Nivel 2 (Lyrics.ovh + Forced Alignment)**: Obtiene la letra en texto plano y ejecuta `stable-whisper` localmente para calcular los timestamps reales del archivo del usuario, omitiendo intros o diferencias de versiones.
- **Nivel 3 (Transcripción pura)**: `faster-whisper` (CTranslate2) transcribe el audio completo y aplica filtros (`hallucination.py`) para descartar repeticiones erróneas.

---

### Normalización de Nombres ([normalizer.py](backend/lyrics/normalizer.py))

Limpia metadatos y genera variantes de búsqueda para evitar fallos por nombres de archivos provenientes de rips o YouTube:

1. **Limpieza de etiquetas**: Remueve tags de resolución y tipo (`[Official Video]`, `(1080p)`, `[320kbps]`, `(En Vivo)`, etc.).
2. **Separación de artistas**: Parsea patrones como `_`, `,`, `&` y `ft.` (`"Silvestre Dangond_ NATTI NATASHA"` ➔ `["Silvestre Dangond", "NATTI NATASHA"]`).
3. **Generación de consultas ordenadas**:
   ```text
   Archivo: "Silvestre Dangond_ NATTI NATASHA - Justicia (Official Video).mp3"
     1. "Silvestre Dangond" + "Justicia"
     2. "Silvestre Dangond, NATTI NATASHA" + "Justicia"
     3. "Silvestre Dangond & NATTI NATASHA" + "Justicia"
     4. "NATTI NATASHA" + "Justicia"
     5. "Justicia Silvestre Dangond"
   ```

---

### Alineación de Estrofas ([align.py](backend/whisper_engine/align.py))

Para evitar que Whisper colapse varias líneas cortas en un solo renglón largo por pausas acústicas, el método `map_words_to_original_lines()`:
- Extrae marcas de tiempo a nivel de palabra.
- Mapea el inicio del verso al timestamp de la primera palabra detectada, conservando los saltos de línea del texto original.
- Inserta una etiqueta `[00:00.00] (intro)` si detecta silencios o secciones instrumentales superiores a 8 segundos al inicio.

---

### Manejo de Estado en Disco

- Se eliminó el almacenamiento en base de datos SQLite intermedia (`lyrics_cache.db`).
- El archivo `.lrc` local junto a la pista es la única referencia del sistema.
- La opción de regeneración sobreescribe directamente el archivo `.lrc` existente mediante una nueva consulta o recalibración.

---

## 🚦 Estado de los Módulos

| Módulo | Estado | Descripción |
| :--- | :---: | :--- |
| **Titofy CLI (Node.js)** | 🟢 Estable | Menú interactivo, reproductor con scroll y visualizador FFT. |
| **Backend (Python)** | 🟢 Estable | Motor híbrido, Forced Alignment, faster-whisper y API FastAPI. |
| **Titofy Desktop (Flutter)** | 🟡 Desarrollo | Interfaz gráfica nativa (en progreso). |

---

## 📁 Estructura del Proyecto

```text
titofy/
├── backend/                     → API local y motor IA (Python 3.11+)
│   ├── api_server.py            → Servidor FastAPI (http://127.0.0.1:8642/docs)
│   ├── whisper_transcribe.py    → Transcripción CLI offline
│   ├── whisper_align.py         → Forced Alignment CLI
│   ├── lyrics/                  → Resolución de letras y normalización
│   │   ├── resolver.py          → Orquestador de los 3 niveles
│   │   ├── normalizer.py        → Limpieza de tags y generación de variantes
│   │   ├── models.py            → Modelos Pydantic
│   │   └── providers/           → Clientes LRCLIB y Lyrics.ovh
│   ├── whisper_engine/          → Carga de modelos y alineación temporal
│   ├── postprocess/             → Filtros anti-alucinación
│   ├── config.yaml              → Configuración general
│   └── requirements.txt
│
├── cli/                         → Interfaz de terminal (Node.js)
│   ├── index.js                 → Punto de entrada CLI
│   ├── generate-lrc.js          → Generador manual vía terminal
│   ├── src/
│   │   ├── ascii-player/        → Visualizador FFT de 112 bandas
│   │   ├── player.js            → Reproductor con scroll sincronizado
│   │   ├── api-client.js        → Cliente HTTP para FastAPI
│   │   └── ui/                  → Menús y lógica de terminal
│   └── package.json
│
├── desktop/                     → Aplicación Flutter (Linux / Windows)
└── README.md
```

---

## ⚙️ Requisitos

- **Node.js**: v18+
- **Python**: v3.10+ (recomendado 3.11+)
- **FFmpeg / ffplay**: v4.4+
- **Flutter**: v3.19+ (opcional, solo para compilar desktop)

---

## 🚀 Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/titofy.git
cd titofy
```

### 2. Backend (Python)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 3. CLI (Node.js)

```bash
cd ../cli
npm install
```

### 4. Dependencias del sistema (FFmpeg)

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y ffmpeg

# Windows
winget install Gyan.FFmpeg
```

---

## 🎮 Uso

Iniciar el menú interactivo:

```bash
cd cli
npm start
```

Opciones principales:
- **Escaneo y sincronización**: Búsqueda y descarga automática de `.lrc`.
- **Transcripción offline**: Selección de modelos Whisper (`base`, `small`, `turbo`).
- **Forced Alignment**: Alineación de un `.txt` arbitrario contra un audio local.
- **Reproductor TUI**: Modo clásico de terminal o visualizador FFT de 112 bandas.
- **Procesamiento por lotes**: Generación desatendida para directorios completos.

---

## 🤖 Rendimiento de Modelos Whisper

| Modelo | Parámetros | VRAM / RAM | Tiempo en GPU (pista 3.5 min) | Tiempo en CPU (int8) |
| :--- | :---: | :---: | :---: | :---: |
| **`base`** | 74M | ~1 GB | ~1-2s | ~10s |
| **`small`** | 244M | ~2 GB | ~2-4s | ~20s |
| **`turbo`** | 809M | ~4 GB | ~3-5s | ~30s |

---

## 🔧 Endpoints FastAPI

La API corre por defecto en `http://127.0.0.1:8642` (documentación en `/docs`):
- `POST /lyrics/resolve` — Ejecuta el pipeline de resolución en 3 niveles.
- `POST /transcribe` — Transcripción directa de audio con Whisper.
- `POST /align` — Forced alignment entre audio y texto provisto.
- `POST /postprocess` — Filtro y limpieza de timestamps en archivos `.lrc`.
- `GET /health` — Estado del servicio y disponibilidad de GPU/CUDA.

---

## 🤝 Licencia

Este proyecto está licenciado bajo la **Licencia Pública General GNU v3.0 (GPL-3.0)**.
Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

*Titofy v2.2 — Letras sincronizadas con la velocidad de la nube y la potencia de tu GPU local.*

Titofy - Santiago Colimba. Todos los derechos reservados ©2026.