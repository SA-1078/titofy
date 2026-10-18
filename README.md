# 🎵 Titofy — Suite de Letras Sincronizadas, Reproductor Nativo e IA Local

**Titofy** es una herramienta integral para obtener, calibrar, transcribir y reproducir letras de canciones (`.lrc`) sincronizadas con archivos locales de audio, además de incluir visualizadores espectrales reactivos en tiempo real.

Incluye:
- **App Desktop (Flutter)**: Interfaz gráfica nativa oficial **v1.1** para **Linux** y **Windows** con renderizado GPU optimizado, análisis de ritmo acústico real, visualizadores desacoplados, Studio IA offline, gestión de listas de reproducción y temas dinámicos.
- **CLI (Terminal TUI)**: Reproductor de letras con scroll continuo y visualizador FFT de 112 bandas Truecolor (v2.4.1).
- **Motor Híbrido & API FastAPI**: Búsqueda remota (LRCLIB / NetEase / Genius), calibración mediante **Forced Alignment** acústico y transcripción offline con **faster-whisper** (CTranslate2) en GPU/CPU.
- **Instaladores Oficiales**: Paquetes de instalación listos para usar en la carpeta `INSTALADORES/` (`Titofy-Setup-v1.0.X.exe` dinámico para Windows y script de integración nativa para Linux).

---

## ✨ Novedades en v2.4.1 (Rendimiento Extremo, Modo Ritmo Real & Fusión Espectro)

- 🚀 **Renderizado Directo GPU en Visualizadores (Zero Widget Rebuilds)**:
  - **Repintado Directo por Controlador**: Eliminación de las reconstrucciones completas a 60 FPS causadas por `AnimatedBuilder`. `SpectrumPainter`, `CliRainbowSpectrumPainter`, `RhythmSymmetricPainter` y `RhythmRadialPainter` ahora heredan de `CustomPainter(repaint: controller)` repintando directamente en el canvas GPU sin instanciar nuevos objetos pintores en cada frame.
  - **Aislamiento de Capas (`RepaintBoundary`)**: Encapsulación gráfica de los visualizadores (`ExpandedSpectrumView`, `ExpandedRhythmView`, `ExpandedKaraokeView`, `ExpandedCliSpectrum`, `PlayerFtt`) para evitar invalidar el resto de la interfaz durante la animación activa.
  - **Optimización Crítica del Modo Radial**: Eliminación de hasta 52 shaders lineales dinámicos calculados por fotograma, sustituidos por interpolación matemática de color de bajo coste computacional y animación aislada de portada.
  - **Reutilización de Buffers**: `SpectrumController` y `InteractiveAudioWaveform` reutilizan buffers de difusión fijos evitando asignaciones continuas en el garbage collector.

- 🥁 **Modo Ritmo con Detección Acústica Real (`AudioBeatAnalysisService`)**:
  - Frente a v2.4 (donde el visualizador de ritmo pulsaba por patrones sintéticos sin escuchar la señal), v2.4.1 implementa **extracción acústica real** de energía y transitorios.
  - **Procesamiento Aislado en Segundo Plano**: Decodificación de audio local con FFmpeg a PCM mono de 8 kHz en un `Isolate` de Flutter, calculando perfiles RMS y golpes de percusión/bajos.
  - **Caché Inteligente Persistente**: Los perfiles calculados se almacenan en `.titofy_beats.json` indexados por hash de archivo, tamaño y fecha de modificación. Durante la reproducción, el secuenciador sincroniza barras simétricas y pulsos radiales con la posición exacta del reproductor con coste de CPU prácticamente nulo (~0% overhead).

- 🎛️ **Fusión de Modos: Espectro Neón e Híbrido Unificados**:
  - Se unificaron los modos independientes "Espectro Neón" e "Híbrido" en una única vista coherente con selector interactivo (`Sin Letras` / `Con Letras`) en la barra superior (`SpectrumStyleSelector`).
  - La preferencia seleccionada se almacena persistentemente en la base de datos SQLite local (`DatabaseService`) para futuras sesiones.

- ⚡ **Desacoplamiento Reactivo del MiniPlayer y NavRail**:
  - Eliminación de suscripciones globales `context.watch<PlayerService>()` en `AppShell`, `NavRail` y `AppTopBar`.
  - Reemplazadas por selectores granulares `context.select(...)`, garantizando que las actualizaciones de milisegundos de la posición de audio no reconstruyan la barra lateral, la barra de título ni los menús.
  - La forma de onda interactiva del reproductor (`InteractiveAudioWaveform`) ahora repinta de forma autónoma en GPU.

- 🎤 **Karaoke Anti-Tirones (Scroll Scheduling Guard)**:
  - Prevención de llamadas concurrentes o acumuladas a `ScrollController.animateTo()` al cambiar rápidamente de verso, evitando bloqueos y micro-tirones.
  - Transición suavizada a 320ms con curva `Curves.easeOutCubic` para una lectura fluida en monitores de alta frecuencia de refresco (120Hz/144Hz+).

- 🪟 **Distribución y Empaquetado Windows Completo**:
  - Inclusión automática del binario nativo `ffmpeg.exe` en la ruta `{app}\backend\bin\` dentro del instalador Inno Setup (`titofy_setup.iss`) y el flujo CI/CD (`build_windows.yml`).
  - Habilita el análisis acústico de beats y herramientas multimedia en Windows sin requerir instalación manual previa de FFmpeg vía terminal ni dependencias externas.

- 🧱 **Arquitectura Modular Limpia (<550 Líneas)**:
  - Refactorización integral de los módulos de mayor escala (`expanded_player_view.dart`, `music_page.dart`, `mini_player.dart`, `database_service.dart`, `lyrics_service.dart`) dividiéndolos en subcomponentes especializados y testeables.
  - Nuevo módulo de notificaciones del sistema (`NotificationService` y `ActivityNotificationsModal`) y diálogo de importación de YouTube (`import_youtube_dialog.dart`).

---

## 📌 Historial: Novedades en CLI v2.4 & Desktop v1.0

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

### 🎯 Capacidades Principales del Motor

- 🧹 **Normalización Automática de Metadatos**: Limpieza inteligente de etiquetas de calidad (`[Official Video]`, `1080p`, `320kbps`, `En Vivo`) y detección de colaboraciones multi-artista (`_`, `,`, `&`, `ft.`) para garantizar la máxima tasa de acierto en las fuentes de letras.
- 🎙️ **Alineación Acústica por Palabra**: Sincronización precisa que conserva los saltos de verso originales del tema sin truncamientos, asignando marcas de tiempo exactas por palabra y detectando intros instrumentales o silencios prolongados.
- 💾 **Almacenamiento Estándar `.lrc`**: Genera y actualiza directamente archivos `.lrc` universales junto a tus pistas de audio, sin bases de datos propietarias intermedias, 100% compatibles con reproductores de escritorio, móviles y automóviles.

---

## 🚦 Estado de los Módulos

| Módulo | Estado | Descripción |
| :--- | :---: | :--- |
| **Titofy Desktop (Flutter)** | 🟢 Estable (v1.1 / v2.4.1) | Reproductor gráfico nativo optimizado para GPU, análisis de ritmo real, visualizadores desacoplados, IA Studio y temas. |
| **Titofy CLI (Node.js)** | 🟢 Estable (v2.4.1) | Menú interactivo, reproductor con scroll y visualizador FFT de 112 bandas. |
| **Backend (Python)** | 🟢 Estable (v2.4.1) | Motor híbrido con auto-detección de intro, faster-whisper, paquete Windows nativo y API FastAPI. |
| **Instaladores Oficiales** | 🟢 Disponible | Instalador Inno Setup automatizado para Windows (`Titofy-Setup-v1.0.X.exe` con FFmpeg integrado) y script nativo para Linux. |

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

## 📦 Instalación

### 🖥️ Opción 1: App Desktop (Recomendada para Usuarios)

Titofy Desktop incluye la interfaz gráfica nativa oficial, el motor de inteligencia artificial empaquetado de forma autónoma y todas las dependencias necesarias sin requerir configuraciones de terminal ni entornos virtuales.

#### 🪟 Windows (10 / 11)
1. Descarga el instalador oficial **`Titofy-Setup-v1.0.X.exe`** desde la carpeta [INSTALADORES/windows](INSTALADORES/windows/) o desde los [Releases de GitHub](https://github.com/SA-1078/titofy/releases).
2. Ejecuta el asistente de instalación paso a paso en español.
3. El instalador configurará automáticamente el motor autónomo (`api_server.exe`), los accesos directos en el menú inicio y el desinstalador limpio.

#### 🐧 Linux (Ubuntu, Debian, Fedora, Arch)
1. Clona o descarga el repositorio y ejecuta el script de instalación en un solo comando:
   ```bash
   bash INSTALADORES/linux/instalar_linux.sh
   ```
2. El script integrará Titofy en el menú de aplicaciones de tu entorno de escritorio (GNOME, KDE, etc.), instalará los íconos oficiales del sistema y registrará el comando global `titofy`.

---

### 💻 Opción 2: CLI y Entorno de Desarrollo (Terminal)

Para desarrolladores o usuarios que deseen utilizar la interfaz interactiva de terminal (TUI) con visualizador FFT o deseen contribuir al código fuente:

#### 1. Requisitos Previos
- **Node.js**: v18+
- **Python**: v3.10+ (recomendado 3.11+)
- **FFmpeg / ffprobe**: v4.4+
- **Flutter**: v3.19+ (opcional, solo para compilar la versión desktop desde el código fuente)

#### 2. Dependencias del Sistema (FFmpeg)
```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y ffmpeg

# Windows (vía winget)
winget install Gyan.FFmpeg
```

#### 3. Clonar el Repositorio
```bash
git clone https://github.com/SA-1078/titofy.git
cd titofy
git checkout 2.4.1
```

#### 4. Configurar el Backend (Python)
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

#### 5. Configurar la CLI (Node.js)
```bash
cd ../cli
npm install
```

---

## 🎮 Modos de Uso

### 🖥️ App Desktop

1. Abre **Titofy** desde tu menú de inicio o lanzador del sistema (o ejecutando el comando `titofy` en Linux).
2. **Reproducción & Karaoke**: Añade canciones o carpetas completas a tu biblioteca para reproducir con visualización de letras en tiempo real.
3. **Sincronización Híbrida**: Si una pista tiene un intro largo de videoclip desfasado, pulsa en el botón de calibración acústica para sincronizar los versos con la voz del cantante al instante.
4. **IA Studio**: Transcribe pistas offline desde cero seleccionando el modelo Whisper deseado (`base`, `small` o `turbo`) con aceleración automática por GPU.

---

### 💻 CLI Interactiva (Terminal)

Inicia el menú interactivo en tu terminal:

```bash
cd cli
npm start
```

Opciones principales disponibles en la terminal:
- **Escaneo y sincronización**: Búsqueda y descarga automática de letras `.lrc` para tu biblioteca musical.
- **Transcripción offline**: Selección y descarga de modelos Whisper (`base`, `small`, `turbo`).
- **Forced Alignment**: Alineación temporal de un archivo de texto `.txt` contra un audio local.
- **Reproductor TUI**: Modo karaoke de terminal con scroll continuo o visualizador espectral FFT de 112 bandas reactivo.
- **Procesamiento por lotes**: Sincronización desatendida para carpetas enteras de música.

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

*Titofy v2.4.1 & Titofy Desktop v1.1 — Letras con la velocidad de la nube y la potencia de tu GPU local.*

Titofy - Santiago Colimba. Todos los derechos reservados ©2026.