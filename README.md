# 🎵 Titofy v2.1 — Suite Multimedia Offline de Letras Sincronizadas (Monorepo)

**Titofy** es una suite 100% local y offline para transcribir, sincronizar y reproducir letras de canciones usando inteligencia artificial (ecosistema Whisper acelerado por hardware), reproducirlas al ritmo de la música y visualizar el espectro de audio en tiempo real.

Incluye:
- **Interfaz CLI (Terminal TUI)**: Reproductor de letras sincronizadas estilo Spotify + Visualizador Espectral ASCII de 112 bandas Truecolor.
- **Motor de IA Local & API FastAPI**: Transcripción acelerada por hardware con `faster-whisper` (CTranslate2), modelo `turbo`, Forced Alignment y microservicio HTTP local (`http://127.0.0.1:8642/docs`).
- **Aplicación Desktop (Flutter)**: Interfaz gráfica nativa inicial para Linux y Windows (en etapa temprana de desarrollo con UI básica, `media_kit` y `NavRail`).

**Todo se procesa en tu propio ordenador. Nada se sube a internet.**

---

## ✨ ¿Qué hay de nuevo en la v2.1?

La versión **2.1** introduce mejoras significativas de físicas de sonido, usabilidad en terminal y experiencia limpia de interfaz respecto a la v2.0:

### 🌊 Visualizador Espectral FFT de 112 Bandas (Truecolor)
- Físicas de audio diferenciadas entre graves (`0-30%`) y medios/agudos (`70%`).
- **Difusión Lateral en Graves (`BASS_DIFFUSION: 0.22`)**: Suavizado horizontal entre barras vecinas para romper la forma rectangular rígida.
- **Extracción Mixta `75% MAX + 25% AVG`**: Respuesta con *punch* instantáneo en los bombos sin saturar ni pegarse al techo.
- **Respuesta de Ola en Medios y Agudos**: Movimiento fluido estilo olas a 30 FPS (`ATTACK: 0.97`, `DECAY: 0.72`).

### ⚡ Interfaz CLI Limpia sin Desplazamiento
- Fix de secuencias ANSI en `alt-screen.js` y `theme.js`. El encabezado `>> TITOFY CMD` permanece fijo en la fila 1 sin requerir scroll hacia arriba al iniciar o navegar.

### 🔇 Silenciamiento Estricto de Logs & Barra de Progreso Única
- Ocultamiento de logs informativos técnicos de consola (redirigidos a `logs/titofy-YYYY-MM-DD.log`).
- Eliminación de barras nativas molestas de `tqdm` y Whisper.
- **Barra de progreso interactiva de 1 sola línea**: `→ Transcribiendo  ████████████░░░░░░░░  58%  ·  1:47 restantes`.

### 🎨 Score de Confianza Dinámico
- Tarjeta final de resultados con puntuación de precisión por código de color: Verde (≥ 80%), Amarillo (60-79%), Rojo (< 60%).

### ⚙️ Carga de CUDA y Estructura Monorepo
- Módulo `soporte_para_cuda.py` para detección y carga dinámica de DLLs de NVIDIA CUDA (cuBLAS, cuDNN) en el entorno virtual `.venv`.

---

## 🚦 Estado Actual de los Módulos v2.1

| Módulo | Estado | Recomendado para uso diario | Descripción |
| :--- | :--- | :---: | :--- |
| **CLI (Node.js)** | 🟢 Estable y funcional | **Sí** | Experiencia TUI completa, reproductor y visualizador espectral. |
| **Backend (Python)** | 🟢 Estable y funcional | **Sí** | Motor `faster-whisper`, API FastAPI y Forced Alignment. |
| **App Desktop (Flutter)** | 🟡 En desarrollo (UI básica) | Experimental | Primera versión gráfica nativa para Linux y Windows (en progreso). |

---

## 📁 Estructura del Monorepo

```text
titofy-cmd/
├── backend/                     → Motor de IA y API local (Python 3.11+)
│   ├── api_server.py            → Microservicio FastAPI (http://127.0.0.1:8642/docs)
│   ├── whisper_transcribe.py    → Transcripción offline con faster-whisper
│   ├── whisper_align.py         → Forced Alignment (Alineamiento maestro)
│   ├── lyrics_postprocess.py    → Limpieza anti-alucinaciones y duplicados
│   ├── music_detector.py        → Detección de secciones musicales
│   ├── soporte_para_cuda.py     → Carga de DLLs CUDA/cuBLAS en .venv
│   ├── logger.py                → Logging filtrado (consola limpia / archivo exhaustivo)
│   ├── config.yaml              → Configuración centralizada
│   └── requirements.txt
│
├── cli/                         → Interfaz de terminal (Node.js)
│   ├── index.js                 → Punto de entrada unificado CLI
│   ├── generate-lrc.js          → Generador de letras por CLI
│   ├── scripts/visualizer.py    → Motor visualizador Python
│   ├── src/
│   │   ├── ascii-player/        → Visualizador FFT de 112 bandas (Truecolor RGB)
│   │   ├── player.js            → Reproductor TUI con scroll continuo Spotify
│   │   └── ui/                  → Menú interactivo TUI (menu-core.js, alt-screen.js)
│   └── package.json
│
├── desktop/                     → Aplicación de escritorio nativa (Flutter)
│   ├── lib/                     → Vistas, reproductor media_kit y shell NavRail
│   ├── pubspec.yaml
│   └── ...                      → (UI gráfica inicial - en desarrollo)
│
├── lrc/                         → Almacenamiento de letras generadas (.lrc)
├── logs/                        → Logs del sistema (titofy-YYYY-MM-DD.log)
└── README.md
```

---

## ⚙️ Requisitos del Sistema

| Requisito | Versión mínima | Para qué |
| :--- | :--- | :--- |
| **Node.js** | v18+ | CLI, menú interactivo y reproductor de terminal |
| **Python** | v3.9+ (recomendado 3.11+) | Motor de transcripción Whisper e IA local |
| **Flutter** | v3.19+ | App Desktop (solo si vas a compilar la app gráfica) |
| **FFmpeg** | v4.4+ | Extracción de audio y reproducción con ffplay |

---

## 🚀 Instalación Completa

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/titofy-cmd.git
cd titofy-cmd
```

### 2. Configurar el Backend (Python)

```bash
cd backend
python3 -m venv .venv

# Linux / macOS
source .venv/bin/activate

# Windows
.venv\Scripts\activate

pip install -r requirements.txt
```

### 3. Configurar la CLI (Node.js)

```bash
cd ../cli
npm install
```

### 4. (Opcional) Configurar la App Desktop (Flutter)

```bash
cd ../desktop
flutter pub get
flutter run -d linux   # o -d windows
```

> *Nota: La App Desktop se encuentra en etapa temprana. Se recomienda usar la CLI para uso diario.*

### 5. Instalar FFmpeg (si no lo tienes)

```bash
# Windows (con winget)
winget install Gyan.FFmpeg

# Linux (Ubuntu/Debian)
sudo apt install ffmpeg
```

Verifica la instalación:
```bash
ffplay -version
```

---

## 🎮 Cómo Usar

### Opción 1: Menú CLI Interactivo (Recomendado)

```bash
cd cli
npm start
```

El menú te permite:
- 📁 Explorar tu carpeta de música (`.mp3`, `.wav`, `.m4a`, `.flac`, `.mp4`, `.mkv`).
- 🤖 Generar letras con IA local (elige el modelo).
- ▶️ Reproducir canciones con letras sincronizadas y scroll estilo Spotify.
- 🌈 Visualizar el espectro animado de audio de 112 bandas Truecolor.
- 🚀 Procesar varias canciones en lote.
- 🎯 Usar Forced Alignment (sincronización con letras `.txt`).

### Opción 2: Generar letras por CLI (Directo)

```bash
cd cli
node generate-lrc.js "ruta/a/cancion.mp3" --language es --model turbo
```

Opciones principales:
- `--model` / `-m` → `turbo`, `small` o `base`
- `--language` / `-l` → `es`, `en`, `pt`, etc.
- `--output` / `-o` → nombre del archivo `.lrc` de salida

### Opción 3: Forced Alignment (Sincronizar letra existente)

```bash
cd backend
python whisper_align.py audio.mp3 --lyrics letra.txt --language es
```

### Opción 4: API Local (FastAPI)

```bash
cd backend
python api_server.py
```

Documentación interactiva disponible en: `http://127.0.0.1:8642/docs`

Endpoints principales:
- `POST /transcribe` → Transcribir y sincronizar audio desde cero.
- `POST /align` → Realizar Forced Alignment.
- `POST /postprocess` → Limpiar un `.lrc` generado.
- `GET /health` → Estado del servidor y detección de hardware (CPU/GPU).

---

## 🤖 Modelos de Whisper Disponibles

| Modelo | Precisión | Velocidad (CPU int8)* | RAM aprox. | Tamaño Descarga | Descripción |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **`base`** | ⭐⭐ | ~10s / canción | ~1 GB | ~139 MB | El rápido: ideal para pruebas o borradores. |
| **`small`** | ⭐⭐⭐ | ~20-30s / canción | ~2 GB | ~461 MB | El bueno: balance diario recomendado. |
| **`turbo`** | ⭐⭐⭐⭐⭐ | ~30-40s / canción | ~4 GB | ~809 MB | **Recomendado (SOTA)**: Calidad de `large-v3` a la velocidad de `small`. |

*\* Tiempos estimados para una canción de ~3 minutos usando `faster-whisper` en CPU (`int8`). En GPU NVIDIA CUDA los tiempos bajan a menos de 5 segundos.*

---

## 🧹 Post-Procesador de Letras

El post-procesador `lyrics_postprocess.py` se ejecuta automáticamente tras cada transcripción y corrige:

| Problema | Acción Realizada | Ejemplo |
| :--- | :--- | :--- |
| **Repeticiones internas** | Se reducen a una sola aparición | `lo que se fue ×20` → `lo que se fue` |
| **Duplicados consecutivos** | Se eliminan líneas idénticas | 3 líneas iguales → 1 sola |
| **Duplicados fuzzy (85%+)** | Se unifican variaciones mínimas | Ajuste de frases similares |
| **Alucinaciones de Whisper** | Se eliminan textos de relleno | `"Gracias por ver"`, `"Suscríbete"` |
| **Timestamps imposibles** | Se filtran intervalos incoherentes | Segmentos >30s con poco texto |

---

## 📄 Formato .lrc

Los archivos `.lrc` generados o creados manualmente siguen el estándar:

```lrc
[ti:Nombre de la canción]
[ar:Artista]
[00:01.00]Primera línea de la letra
[00:05.50]Segunda línea
[00:10.00]♪
```

---

## 🔧 Solución de Problemas

| Error | Solución |
| :--- | :--- |
| `Python no encontrado` | Instala Python 3.9+ desde python.org |
| `ffplay no encontrado` | Instala FFmpeg (`winget install Gyan.FFmpeg` o `sudo apt install ffmpeg`) |
| `ModuleNotFoundError` | Activa el entorno `.venv` e instala `pip install -r requirements.txt` |
| `Letras con muchos errores` | Usa `--language es` para forzar el idioma deseado |
| `La App Desktop no compila` | Ejecuta `flutter doctor` en la carpeta `desktop/` para verificar dependencias de Flutter |

---

## 🌐 Ruta de Desarrollo (Roadmap)

### ✅ Completado hasta v2.0
- Motor de transcripción offline con `faster-whisper` (CTranslate2).
- CLI completa con menú interactivo TUI y reproductor estilo Spotify.
- Forced Alignment y microservicio API local en FastAPI.
- Reestructuración a Monorepo (`backend/`, `cli/`, `desktop/`).

### ✨ Nuevo en v2.1
- [x] Visualizador espectral FFT de 112 bandas en Truecolor ANSI con difusión lateral en graves.
- [x] Corrección de viewport en terminal TUI (encabezado fijo sin scroll hacia arriba).
- [x] Barra de progreso única interactiva y silenciamiento de logs técnicos en consola.
- [x] Tarjeta de resultados con scores de confianza por colores.
- [x] Módulo `soporte_para_cuda.py` para carga limpia de DLLs de NVIDIA CUDA.

### 🚧 En desarrollo / Próximamente
- [ ] Mejora y estabilización progresiva de la App Desktop (Flutter).
- [ ] Empaquetado e instaladores sencillos.
- [ ] Modo híbrido opcional (búsqueda de letras online + fallback local).

---

## 📌 Notas Importantes de la v2.1

1. Esta versión mantiene y perfecciona la **arquitectura Monorepo** (`backend/`, `cli/`, `desktop/`).
2. La CLI y el Backend son el núcleo maduro y recomendado para el uso diario.
3. La App Desktop nativa en Flutter está en desarrollo temprano (UI básica) y se irá mejorando en futuras entregas.

---

## 🤝 Licencia

Licencia MIT — Desarrollado por el equipo de **Titofy**.

---
*Titofy v2.1 — De la terminal al escritorio, siempre offline y bajo tu control.*
