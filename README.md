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

---

## 🧠 Arquitectura Detallada del Motor Híbrido (Multi-Fuente & Calibración IA)

### 💡 ¿Por qué un Motor Híbrido?
Los sistemas tradicionales de letras enfrentan dos grandes problemas:
1. **Bases de datos online comunitarias (LRCLIB, etc.)**: Son ultrarrápidas (< 0.5s) y tienen ortografía oficial perfecta, pero los tiempos sincronizados muchas veces fueron cronometrados sobre el **Video Oficial de YouTube** (que tiene diálogos o intros de 20-40s) o sobre una versión de álbum distinta a tu archivo local. Esto produce el molesto **desfase de estrofas**.
2. **Transcripción por IA desde cero (Whisper puro)**: Sincroniza al 100% con tu archivo de audio local, pero toma más tiempo (15-30s) y puede alucinar en canciones con instrumentos densos o coros rápidos.

**El Motor Híbrido de Titofy v2.2 une lo mejor de ambos mundos:**
> Descarga la letra oficial de internet (100% libre de faltas ortográficas) y ejecuta **Forced Alignment** con Whisper en tu GPU local durante **~1.5 segundos**. Así adapta cada verso al milisegundo exacto donde suena en **tu archivo local específico**.

---

### 🔍 Los 3 Niveles de Resolución en Detalle

| Nivel | Fuente / Método | Tiempo estimado | Ventaja Principal | Cuándo se activa |
| :---: | :--- | :---: | :--- | :--- |
| **Nivel 1** | **LRCLIB (Sincronizado)** | `< 0.5s` | Letras oficiales con timestamps de alta calidad. | Siempre en primer lugar (si existe match). |
| **Nivel 2** | **Lyrics.ovh + Forced Alignment** | `~ 1.5s` (GPU) | Texto oficial en texto plano calibrado con tu audio local. | Si no hay timestamps en LRCLIB pero sí texto. |
| **Nivel 3** | **Whisper IA Local (Offline)** | `~ 2-5s` (GPU) | 100% offline e independiente de internet; funciona con pistas inéditas. | Fallback si la canción no existe online. |

#### 1. Nivel 1 — LRCLIB (Búsqueda Sincronizada Directa)
* Consulta los endpoints `/api/get` (coincidencia estricta con tolerancia de duración) y `/api/search` (búsqueda difusa).
* Si encuentra la canción con marcas de tiempo sincronizadas, las valida acústicamente y genera el `.lrc` al instante.

#### 2. Nivel 2 — Lyrics.ovh + Forced Alignment Local
* Si una canción no tiene letra sincronizada pero sí texto plano oficial, Titofy consulta `Lyrics.ovh` (`/suggest/{query}` y `/v1/{artist}/{title}`).
* Envía el texto lírico limpio a `stable-whisper` en tu máquina local.
* Whisper "escucha" tu archivo de audio y mapea cada verso a su marca temporal exacta, corrigiendo introducciones, solos y ritmos propios de tu archivo.

#### 3. Nivel 3 — Whisper IA Local (Transcripción Completa)
* Si no hay conexión o la canción no existe en ninguna base de datos online, se activa el motor local `faster-whisper` (CTranslate2).
* Muestra una **barra de progreso interactiva en tiempo real** en la terminal.
* Aplica filtros de post-procesamiento (`hallucination.py`) para eliminar repeticiones de coros o frases de relleno.

---

### 🎭 Formateador y Permutaciones Multi-Artista ([normalizer.py](backend/lyrics/normalizer.py))

Los archivos de música descargados de YouTube suelen tener nombres desordenados, colaboraciones con formatos no estándar o etiquetas de bitrate. Titofy integra un pipeline de normalización en 3 pasos:

#### 1. Limpieza de Ruido Publicitario y Formatos
Elimina automáticamente cualquier variante de:
* `(Official Video)`, `(Video Oficial)`, `(Music Video)`, `(Lyric Video)`
* `(1080P_HD)`, `(720p_HD)`, `[4K]`, `[HD]`, `(MP3_160K)`, `[320kbps]`
* `[Remastered]`, `(En Vivo)`, `[Live]`, etc.

#### 2. Separador de Colaboradores (`split_artists`)
Detecta y desglosa cualquier separador de colaboraciones:
* Guiones bajos: `Silvestre Dangond_ NATTI NATASHA` ➔ `["Silvestre Dangond", "NATTI NATASHA"]`
* Comas o Ampersands: `Chencho Corleone, Peso Pluma` / `Bizarrap & Shakira`
* Feats: `Stalyn y sus Amigos ft. Karu Ñan` ➔ `["Stalyn y sus Amigos", "Karu Ñan"]`

#### 3. Generación de 5 Variantes Jerárquicas (`generate_search_variations`)
Para evitar fallos por discrepancias de nombre en las APIs, genera automáticamente 5 consultas ordenadas por prioridad:

```text
Ejemplo: "Silvestre Dangond_ NATTI NATASHA - Justicia (Official Video)(1080P_HD).mp3"
  1. Artista Principal      : "Silvestre Dangond" + "Justicia"
  2. Colaboradores con coma : "Silvestre Dangond, NATTI NATASHA" + "Justicia"
  3. Colaboradores con &    : "Silvestre Dangond & NATTI NATASHA" + "Justicia"
  4. Artista Secundario     : "NATTI NATASHA" + "Justicia"
  5. Búsqueda Invertida     : "Justicia Silvestre Dangond"
```

---

### 🎼 Preservación de Estrofas y Saltos de Línea ([align.py](backend/whisper_engine/align.py))

Anteriormente, los motores de alineación agrupaban los versos según las pausas de respiración acústicas del cantante, amontonando 2 o 3 líneas en un solo renglón largo.

Titofy v2.2 implementa el algoritmo **`map_words_to_original_lines()`**:
1. **Extracción de Timestamps por Palabra**: Whisper extrae la marca de tiempo de cada palabra cantada.
2. **Mapeo a la Estructura Lírica Oficial**: Cada verso del texto original recibe el segundo exacto donde comienza su primera palabra cantada.
3. **Detección Inteligente de Intros de Video**: Si el videoclip incluye un opening cinematográfico o diálogo de más de 8 segundos antes de cantar, Titofy inserta un marcador `[00:00.00] (intro)` y suprime marcas de tiempo fantasma en los diálogos.

#### Comparativa Real:
```lrc
❌ ANTES (Bloques amontonados):
[02:17.40] pa' otro es nuevo  Déjame quitarte el maquillaje Déjame sentirte
[02:23.50] y abrazarte Píntate la boca y ponte bella Quiero verte así como
[02:28.70] eras antes Deja el sufrimiento en el espejo Coge tu cartera,

✅ AHORA (Estrofas limpias y versos exactos):
[02:13.42] Si te llamo, le haces relevo
[02:15.94] Lo que es viejo pa' uno, pa' otro es nuevo
[02:18.26] Déjame quitarte el maquillaje
[02:21.92] Déjame sentirte y abrazarte
[02:24.58] Píntate la boca y ponte bella
[02:27.10] Quiero verte así como eras antes
[02:29.58] Deja el sufrimiento en el espejo
[02:32.36] Coge tu cartera, yo manejo
[02:34.66] Cómplice la noche de nosotros dos
```

---

### 🧹 Arquitectura Limpia sin Caché SQLite (Zero Dual-State)

En versiones anteriores, la base de datos `lyrics_cache.db` guardaba resultados intermedios. Si una canción fallaba una vez o tenía un error de Whisper, la base de datos quedaba desactualizada y bloqueaba futuras consultas online.

**En Titofy v2.2:**
* Se eliminó por completo `lyrics_cache.db`.
* **El archivo `.lrc` en tu disco es la única fuente de verdad**. Si existe el archivo `.lrc`, la canción está lista para reproducirse al instante (`[SYNC]`).
* Cuando eliges **"Regenerar letras"**, el sistema siempre realiza una consulta fresca en tiempo real o recalibra con IA, sobreescribiendo el `.lrc` sin estados duplicados.

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