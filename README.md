# 🎵 Titofy v2.2 — Suite Multimedia de Letras Sincronizadas y Motor Híbrido IA

**Titofy** es una suite moderna y modular para obtener, transcribir, sincronizar y reproducir letras de canciones con inteligencia artificial, reproducirlas al ritmo de la música y visualizar el espectro de audio en tiempo real.

Incluye:
- **Interfaz CLI (Terminal TUI)**: Menú interactivo, reproductor de letras sincronizadas estilo Spotify y Visualizador Espectral ASCII de 112 bandas Truecolor.
- **Motor Híbrido Multi-Fuente & API FastAPI**: Búsqueda online ultrarrápida (LRCLIB / Lyrics.ovh), calibración acústica con **Forced Alignment** y transcripción local 100% offline con **faster-whisper** (CTranslate2) acelerada por GPU NVIDIA CUDA o CPU.
- **Aplicación Desktop (Flutter)**: Interfaz gráfica nativa para Linux y Windows (en desarrollo activo con reproductor `media_kit`).

**Tus archivos locales son tu música. El motor híbrido te da la mayor velocidad online y la máxima precisión offline sin bases de datos intermedias.**

---

## ✨ ¿Qué hay de nuevo en la v2.2?

La versión **2.2** revoluciona la forma en que Titofy obtiene y sincroniza las letras, introduciendo un motor híbrido inteligente de 3 niveles, formateo multi-artista y alineación acústica perfecta:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 MOTOR HÍBRIDO TITOFY v2.2                              │
│                                                                                        │
│   [Audio Local] ──► Formateador Multi-Artista ──► Generación de 5 Permutaciones        │
│                              │                                                         │
│       ┌──────────────────────┴──────────────────────┐                                  │
│       ▼                                             ▼                                  │
│  [NIVEL 1: LRCLIB]                             [NIVEL 2: Lyrics.ovh]                   │
│  Letra sincronizada directa (<0.5s)            Texto plano oficial                     │
│       │                                             │                                  │
│       └──────────────────────┬──────────────────────┘                                  │
│                              ▼                                                         │
│               [CALIBRACIÓN LOCAL: Forced Alignment]                                    │
│               Whisper calibra el texto con tu audio específico en ~1.5s                │
│                              │ (Si no hay letras online)                               │
│                              ▼                                                         │
│               [NIVEL 3: Whisper IA Local (Offline)]                                    │
│               Transcripción completa desde cero con barra interactiva                  │
│                              │                                                         │
│                              ▼                                                         │
│               [.lrc Única Fuente de Verdad en Disco]                                   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 🌐 1. Motor Híbrido Multi-Fuente (3 Niveles Inteligentes)
- **Nivel 1 (LRCLIB)**: Búsqueda instantánea de letras oficiales y sincronizadas en menos de 0.5 segundos.
- **Nivel 2 (Lyrics.ovh + Forced Alignment)**: Si solo existe letra en texto plano, Titofy la descarga y ejecuta **Forced Alignment** con tu audio local para generar las marcas de tiempo automáticamente.
- **Nivel 3 (Whisper IA Local)**: Si la canción es inédita o no existe en internet, el motor local de Whisper transcribe la pista desde cero con barra de progreso en vivo.

### 🎭 2. Formateador y Permutaciones de Búsqueda Multi-Artista
- **Limpieza de Ruido de Ripeos**: Remueve automáticamente etiquetas de calidad y video como `(Official Video)`, `(1080P_HD)`, `(MP3_160K)`, `[4K]`, `[Remastered]`, etc.
- **Detección de Colaboradores**: Separa artistas unidos por `_`, `,`, `/`, `|`, `&`, `y`, `x`, `feat.`, `ft.`, `with`.
- **Generación de 5 Variantes Jerárquicas**: Consulta las APIs probando combinaciones prioritarias (Artista principal, colaboradores combinados con coma o `&`, colaboradores secundarios y búsquedas invertidas Título-Artista).

### 🎼 3. Mapeo Perfecto de Estrofas y Saltos de Línea (`map_words_to_original_lines`)
- **Preservación 100% de la Estructura Lírica**: Mapeo de timestamps a nivel de palabra que respeta los saltos de línea y estrofas musicales del texto oficial.
- **Cero Versos Amontonados**: Elimina los bloques pegados y cortes arbitrarios a mitad de frase.
- **Detección Inteligente de Intros de Video**: Inserta marcadores limpios `[00:00.00] (intro)` y suprime palabras fantasma en openings o escenas de diálogo de videoclips.

### 🧹 4. Arquitectura Limpia sin Caché SQLite (Zero Dual-State)
- **Eliminación Total de `lyrics_cache.db`**: El archivo `.lrc` físico en disco actúa como la única fuente de verdad natural.
- **Regeneración 100% Determinista**: Al pulsar "Regenerar", el sistema siempre consulta proveedores frescos o recalibra con IA sin estados viejos congelados.

### 🖥️ 5. Salida Atómica y Limpieza de Terminal
- **Salida limpia con `Ctrl + C` o `Esc`**: Secuencias ANSI `\x1b[2J\x1b[3J\x1b[H` que limpian tanto la pantalla como el buffer de scrollback de la terminal.
- **Cierre Seguro de Procesos**: Terminación inmediata de `ffplay` y servidores secundarios para no dejar memoria ni VRAM ocupada.
- **Encabezados Dinámicos de Preview**: Avisos claros según el modo utilizado (`IA`, `Online`, `Alineadas`).
- **Métricas 100% en Español**: `Nivel de confianza`, `Segmentos de baja confianza`, etc.

---

## 🚦 Estado de los Módulos v2.2

| Módulo | Estado | Recomendado para uso diario | Descripción |
| :--- | :--- | :---: | :--- |
| **Titofy CLI (Node.js)** | 🟢 Estable y maduro | **Sí** | Menú interactivo, reproductor con scroll continuo y visualizador FFT de 112 bandas. |
| **Backend & Motor Híbrido (Python)** | 🟢 Estable y maduro | **Sí** | Motor híbrido (LRCLIB + Lyrics.ovh), Forced Alignment, `faster-whisper` y API FastAPI. |
| **Titofy Desktop App (Flutter)** | 🟡 En desarrollo | Experimental | Aplicación gráfica nativa para Linux y Windows (en progreso). |

---

## 📁 Estructura del Monorepo

```text
titofy/
├── backend/                     → Motor de IA, Híbrido y API local (Python 3.11+)
│   ├── api_server.py            → Microservicio FastAPI (http://127.0.0.1:8642/docs)
│   ├── whisper_transcribe.py    → Wrapper CLI de transcripción offline
│   ├── whisper_align.py         → Wrapper CLI de Forced Alignment
│   ├── lyrics/                  → Módulo del Motor Híbrido
│   │   ├── resolver.py          → Orquestador híbrido multi-fuente (3 niveles)
│   │   ├── normalizer.py        → Limpieza de ruido y permutaciones multi-artista
│   │   ├── models.py            → Modelos de datos de letras y líneas sincronizadas
│   │   └── providers/           → Proveedores online (LRCLIB, Lyrics.ovh)
│   ├── whisper_engine/          → Motor Whisper y Forced Alignment
│   │   ├── loader.py            → Carga de modelos y detección de GPU CUDA
│   │   ├── transcribe.py        → Transcripción por segmentos/palabras
│   │   ├── align.py             → Forced Alignment con preservación de estrofas
│   │   └── formatter.py         → Formato de timestamps .lrc
│   ├── postprocess/             → Filtros anti-alucinaciones y repeticiones
│   ├── logger.py                → Logging estructurado
│   ├── config.yaml              → Configuración centralizada
│   └── requirements.txt
│
├── cli/                         → Interfaz de terminal Titofy CLI (Node.js)
│   ├── index.js                 → Entrada unificada CLI
│   ├── generate-lrc.js          → Generador directo por línea de comandos
│   ├── scripts/visualizer.py    → Motor visualizador Python
│   ├── src/
│   │   ├── ascii-player/        → Visualizador FFT de 112 bandas (Truecolor RGB)
│   │   ├── player.js            → Reproductor TUI con scroll estilo Spotify
│   │   ├── api-client.js        → Cliente HTTP para el backend FastAPI
│   │   ├── audio.js             → Controlador de audio con ffplay
│   │   └── ui/                  → Menús interactivos (menu-core.js, menu-actions.js)
│   ├── lrc/                     → Almacenamiento de archivos .lrc generados
│   └── package.json
│
├── desktop/                     → Aplicación gráfica nativa Titofy Desktop App (Flutter)
│   ├── lib/                     → Vistas, reproductor media_kit y shell NavRail
│   └── pubspec.yaml
│
├── logs/                        → Logs del sistema (titofy-YYYY-MM-DD.log)
└── README.md
```

---

## ⚙️ Requisitos del Sistema

| Requisito | Versión mínima | Para qué |
| :--- | :--- | :--- |
| **Node.js** | v18+ | Interfaz de terminal CLI, menú interactivo y reproductor |
| **Python** | v3.10+ (recomendado 3.11+) | Motor de transcripción Whisper, alineación y búsqueda híbrida |
| **FFmpeg & ffplay** | v4.4+ | Reproducción de audio y extracción de audio para IA |
| **Flutter** | v3.19+ | Titofy Desktop App (solo si vas a compilar la app gráfica) |

---

## 🚀 Instalación Rápida

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/titofy.git
cd titofy
```

### 2. Configurar el Backend (Python)

```bash
cd backend
python3 -m venv .venv

# En Linux / macOS:
source .venv/bin/activate

# En Windows:
.venv\Scripts\activate

pip install -r requirements.txt
```

### 3. Configurar la CLI (Node.js)

```bash
cd ../cli
npm install
```

### 4. Instalar FFmpeg (si no lo tienes)

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y ffmpeg

# Windows (winget)
winget install Gyan.FFmpeg
```

---

## 🎮 Cómo Usar

### Modo Menú Interactivo (Recomendado)

```bash
cd cli
npm start
```

Desde el menú podrás:
- 📁 **Explorar tu biblioteca musical**: Escanea automáticamente tu carpeta de música configurada.
- ⚡ **Obtener letras en Modo Automático (Híbrido)**: Busca online en LRCLIB / Lyrics.ovh y calibra con tu audio local en ~1.5s.
- 🤖 **Generar letras con IA local (Whisper)**: Transcripción 100% offline eligiendo el modelo (`turbo`, `small`, `base`).
- 🎯 **Forced Alignment (.txt local)**: Sincroniza un archivo de texto con el audio.
- ▶️ **Reproductor Clásico**: Reproduce canciones con letras sincronizadas y scroll continuo.
- 🌈 **Visualizador ASCII (Espectro PRO)**: Visualizador de frecuencias animado de 112 bandas Truecolor.
- 🚀 **Procesamiento por Lotes**: Genera letras para múltiples canciones de forma desatendida.

---

## 🤖 Modelos Whisper Disponibles

| Modelo | Precisión | Velocidad (GPU CUDA)* | Velocidad (CPU int8)* | VRAM / RAM | Uso Recomendado |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **`base`** | ⭐⭐ | **~1-2s** | ~10s | ~1 GB | Ultrarrápido: ideal para Forced Alignment y pruebas. |
| **`small`** | ⭐⭐⭐⭐ | **~2-4s** | ~20s | ~2 GB | Excelente balance para transcripción diaria. |
| **`turbo`** | ⭐⭐⭐⭐⭐ | **~3-5s** | ~30s | ~4 GB | **Máxima precisión (SOTA)**: Calidad de `large-v3` a alta velocidad. |

*\* Tiempos estimados para canciones promedio de ~3.5 minutos.*

---

## 🔧 API Local de Backend (FastAPI)

El servidor FastAPI se inicia automáticamente en segundo plano cuando la CLI lo necesita, o puedes iniciarlo manualmente:

```bash
cd backend
python api_server.py
```

Documentación interactiva Swagger en: `http://127.0.0.1:8642/docs`

### Endpoints Principales:
- `POST /lyrics/resolve` → Motor Híbrido (Online LRCLIB / Lyrics.ovh + Forced Alignment + Whisper fallback).
- `POST /transcribe` → Transcripción directa de audio con Whisper.
- `POST /align` → Forced Alignment entre un audio y texto lírico.
- `POST /postprocess` → Limpieza y filtrado anti-alucinaciones en archivos `.lrc`.
- `GET /health` → Estado del servidor, modelos cargados y tareas activas.

---

## 🤝 Licencia

Este proyecto está licenciado bajo la **GNU General Public License v3.0 (GPL-3.0)**.

Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

*Titofy v2.2 — Letras sincronizadas con la velocidad de la nube y la potencia de tu GPU local.*

Titofy - Santiago Colimba.
Todos los derechos reservados ©2026.