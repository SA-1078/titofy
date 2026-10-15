# 🎵 Titofy — Suite de Letras Sincronizadas, Reproductor Nativo e IA Local

**Titofy** es una herramienta integral para obtener, calibrar, transcribir y reproducir letras de canciones (`.lrc`) sincronizadas con archivos locales de audio, además de incluir visualizadores espectrales reactivos en tiempo real.

Incluye:
- **App Desktop (Flutter)**: Interfaz gráfica nativa oficial **v1.0** para **Linux** y **Windows** con modo karaoke, Studio IA offline, gestión de listas de reproducción y paleta de colores personalizable.
- **CLI (Terminal TUI)**: Reproductor de letras con scroll continuo y visualizador FFT de 112 bandas Truecolor (v2.4).
- **Motor Híbrido & API FastAPI**: Búsqueda remota (LRCLIB / NetEase / Genius), calibración mediante **Forced Alignment** acústico y transcripción offline con **faster-whisper** (CTranslate2) en GPU/CPU.
- **Instaladores Oficiales**: Paquetes de instalación listos para usar en la carpeta `INSTALADORES/` (`Titofy-Setup-v1.0.X.exe` dinámico para Windows y script de integración nativa para Linux).

---

## ✨ Novedades en CLI v2.4 & Desktop v1.0

- 🎬 **Alineación Inteligente para Videoclips con Intro Extenso (Offset $\ge 3.0$s)**:
  - Solución definitiva para audios extraídos de YouTube o videoclips oficiales que incluyen diálogos, actuaciones o intros musicales largos (como en *Silvestre Dangond - Cásate Conmigo* o *Daddy Yankee - Lovumba*).
  - Al detectar un desfase $\ge 3.0$ segundos entre el audio y la letra de Internet, el motor activa automáticamente la **Alineación Forzada Completa** (`word_timestamps=True`), inserta el marcador `[00:00.00](intro)` y empareja acústicamente cada verso con el momento exacto en que empieza la voz del cantante.
- ⚡ **Modelo Turbo Nativo en GPU sin Falsos Fallbacks**:
  - Corrección en el loader y la caché para respetar el alias `large-v3-turbo` (mobiuslabsgmbh), eliminando la sustitución heredada hacia `large-v3` (3 GB).
  - Carga inmediata en ~2.1 segundos en GPUs NVIDIA (CUDA) o en CPU con cuantización `int8`, sin retroceder indebidamente a `small`.
- 🛡️ **Subsistema Nativo y Resiliencia en Windows (`backend/windows/`)**:
  - **Watchdog & Autodestrucción**: Monitoreo de `--parent-pid` para evitar procesos huérfanos de `api_server.exe` al cerrar la interfaz gráfica.
  - **Liberación de Puertos y Hot-Patching**: `windows_backend_service.dart` libera automáticamente el puerto `8642` (`netstat`/`taskkill`) y sincroniza en caliente archivos de backend (`cache.py`, scripts de motor) hacia las carpetas temporales `_MEI` de PyInstaller.
  - **Compatibilidad PyAV y VAD**: Fijación de `av==12.3.0` en CI/CD y parche dinámico en runtime para mapear transparentemente parámetros `vad` a `vad_filter` en `faster-whisper`.
  - **Auditoría Estricta de Pesos**: Exigencia física de `model.bin > 10MB` y purga completa de carpetas dañadas para evitar bloqueos por descargas incompletas.
- 🎛️ **IA Studio Refactorizado y Modular en Desktop**:
  - Widgets desacoplados (`studio_audio_card`, `studio_control_card`, `studio_strategy_card`) bajo el límite de mantenimiento (<600 líneas).
  - Polling optimizado, captura de excepciones y mensajes de estado humanizados durante la descarga y transcripción.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 PIPELINE DE RESOLUCIÓN (v2.4)                          │
│                                                                                        │
│   [Audio Local] ──► Normalizador Multi-Artista ──► Generación de Consultas             │
│                              │                                                         │
│       ┌──────────────────────┴──────────────────────┐                                  │
│       ▼                                             ▼                                  │
│  [NIVEL 1: LRCLIB / NetEase]                   [NIVEL 2: Genius / Lyrics.ovh]          │
│  Sincronización remota (<0.5s)                 Texto plano sin tiempos                 │
│       │                                             │                                  │
│       ├─────────────────────────────────────────────┘                                  │
│       ▼                                                                                │
│  ¿Desfase ≥ 3.0s o Intro Largo?                                                        │
│       ├─► SÍ ──► [FORCED ALIGNMENT ACÚSTICO COMPLETO]                                  │
│       │          Whisper word_timestamps=True + Marcador [00:00.00](intro)            │
│       └─► NO ──► Calibración lineal / Entrega directa                                  │
│                              │ (Si no hay coincidencias online)                        │
│                              ▼                                                         │
│               [NIVEL 3: Whisper Local (Offline)]                                       │
│               Transcripción completa con faster-whisper                                │
│                              │                                                         │
│                              ▼                                                         │
│               [Archivo .lrc local verificado]                                          │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Arquitectura del Motor Híbrido

### Niveles de Resolución

| Nivel | Método | Tiempo estimado (GPU) | Comportamiento |
| :---: | :--- | :---: | :--- |
| **1** | **LRCLIB / NetEase** | `< 0.5s` | Descarga timestamps listos. Se activa en primera instancia. |
| **2** | **Genius / Lyrics.ovh + Forced Alignment** | `~ 1.5s` | Si solo existe letra en texto plano, Whisper alinea cada línea con el audio local. |
| **3** | **Whisper Local (Offline)** | `~ 2-5s` | Transcripción directa si la pista no existe en las fuentes online. |

- **Nivel 1 (Sincronización Remota)**: Búsqueda estricta y difusa en LRCLIB y NetEase Music. Genera el archivo `.lrc` directamente si hay coincidencia temporal.
- **Calibración Acústica de Intros**: Si el audio contiene un intro hablado o musical largo respecto a la versión de estudio de Internet (desfase $\ge 3.0$ s), el motor descarta el offset plano y ejecuta `align_lyrics()` para anclar acústicamente los versos a la voz real del cantante.
- **Nivel 2 (Texto Plano + Forced Alignment)**: Obtiene la letra en texto plano y ejecuta Whisper localmente para calcular los timestamps reales del archivo del usuario.
- **Nivel 3 (Transcripción pura)**: `faster-whisper` (CTranslate2) transcribe el audio completo y aplica filtros anti-alucinación (`hallucination.py`).

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
- Inserta una etiqueta `[00:00.00] (intro)` y posiciona la primera estrofa exactamente cuando empieza el canto.

---

### Manejo de Estado en Disco

- El archivo `.lrc` local junto a la pista es la única referencia del sistema.
- Se ignoran cachés antiguas si no están marcadas como `online_aligned` o calibradas.
- La opción de regeneración sobreescribe directamente el archivo `.lrc` existente mediante una nueva consulta o recalibración.

---

## 🚦 Estado de los Módulos

| Módulo | Estado | Descripción |
| :--- | :---: | :--- |
| **Titofy Desktop (Flutter)** | 🟢 Estable (v1.0.X) | Reproductor gráfico nativo para Linux y Windows con soporte de karaoke, IA Studio y temas. |
| **Titofy CLI (Node.js)** | 🟢 Estable (v2.4) | Menú interactivo, reproductor con scroll y visualizador FFT de 112 bandas. |
| **Backend (Python)** | 🟢 Estable (v2.4) | Motor híbrido con auto-detección de intro, faster-whisper, paquete Windows nativo y API FastAPI. |
| **Instaladores Oficiales** | 🟢 Disponible | Instalador Inno Setup automatizado para Windows (`Titofy-Setup-v1.0.X.exe`) y script nativo para Linux. |

---

## 📁 Estructura del Proyecto

```text
titofy/
├── INSTALADORES/                → Instaladores listos para producción (Linux y Windows)
│   ├── linux/                   → Instalador y desinstalador nativo (.sh)
│   ├── windows/                 → Asistente Inno Setup (.iss) y compilador de Windows
│   └── README.md                → Guía pública de instalación
│
├── backend/                     → API local y motor IA (Python 3.11+)
│   ├── api_server.py            → Servidor FastAPI (http://127.0.0.1:8642/docs)
│   ├── whisper_transcribe.py    → Transcripción CLI offline
│   ├── whisper_align.py         → Forced Alignment CLI
│   ├── windows/                 → Subsistema nativo de resiliencia para Windows
│   │   ├── dll_setup.py         → Carga segura de DLLs CUDA y PyAV
│   │   ├── process.py           → Watchdog de ciclo de vida con PID padre
│   │   └── whisper_patch.py     → Parche dinámico vad -> vad_filter
│   ├── lyrics/                  → Resolución de letras y normalización
│   │   ├── resolver.py          → Orquestador de niveles y alineación de videoclips
│   │   ├── normalizer.py        → Limpieza de tags y generación de variantes
│   │   ├── models.py            → Modelos Pydantic
│   │   └── providers/           → Clientes LRCLIB, NetEase y Genius
│   ├── whisper_engine/          → Carga de modelos, gestión de caché e inferencia
│   │   ├── loader.py            → Carga de faster-whisper y fallback GPU/CPU
│   │   ├── cache.py             → Auditoría de model.bin (>10MB) y purga limpia
│   │   └── align.py             → Alineación acústica palabra por palabra
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
│   ├── lib/core/services/       → Servicios de API, letras y windows_backend_service
│   ├── lib/features/studio/     → IA Studio desacoplado en widgets (<600 líneas)
│   └── pubspec.yaml
└── README.md
```

---

## ⚙️ Requisitos

- **Node.js**: v18+
- **Python**: v3.10+ (recomendado 3.11+)
- **FFmpeg / ffprobe**: v4.4+
- **Flutter**: v3.19+ (opcional, solo para compilar desktop)

---

## 🚀 Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/titofy.git
cd titofy
git checkout 2.4
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
| **`base`** | 74M | ~1 GB | ~1-2 segundos | ~10-15 segundos |
| **`small`** | 244M | ~2 GB | ~2-4 segundos | ~20-25 segundos |
| **`turbo`** | 809M | ~4 GB | ~2-3 segundos | ~25-35 segundos |

> *Nota:* Pruebas de GPU realizadas con aceleración CUDA en NVIDIA RTX Laptop GPU y cuantización `float16` / `int8`.

---

## 🔧 Endpoints FastAPI

La API corre por defecto en `http://127.0.0.1:8642` (documentación en `/docs`):
- `POST /lyrics/resolve` — Ejecuta el pipeline de resolución híbrida en 3 niveles con auto-alineación acústica.
- `POST /transcribe` — Transcripción directa de audio con Whisper.
- `POST /align` — Forced alignment acústico entre audio y texto provisto.
- `POST /models/preload` — Descarga y preparación anticipada de modelos en memoria/disco.
- `GET /models/status` — Monitoreo del estado de descarga de modelos.
- `POST /postprocess` — Filtro y limpieza de timestamps en archivos `.lrc`.
- `GET /health` — Estado del servicio y disponibilidad de GPU/CUDA.

---

## 🤝 Licencia

Este proyecto está licenciado bajo la **Licencia Pública General GNU v3.0 (GPL-3.0)**.
Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

*Titofy v2.4 & Titofy Desktop v1.0 — Letras sincronizadas con la velocidad de la nube y la potencia de tu GPU local.*

Titofy - Santiago Colimba. Todos los derechos reservados ©2026.