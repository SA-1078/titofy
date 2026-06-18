# 🎵 Titofy CMD v1.4 — Motor de Generación de Letras Sincronizadas Offline

Software **100% local y offline** que genera letras de canciones sincronizadas automáticamente usando IA (ecosistema Whisper acelerado por hardware) y las reproduce en la terminal al ritmo de la música. Incluye API local, forced alignment y procesamiento batch paralelo. Todo se procesa en tu propio ordenador: *Nada se sube a internet.*

### ✨ Novedades de la v1.4
- **Aceleración con `faster-whisper`**: Migración al backend optimizado CTranslate2 de `faster-whisper`, logrando velocidades de procesamiento de 4x a 8x más rápidas tanto en CPU como en GPU.
- **Cuantización Inteligente `int8`**: Transcripción acelerada por hardware de bajo consumo en CPU sin pérdida perceptible de precisión, reduciendo drásticamente el consumo de memoria RAM.
- **Modelo Turbo (SOTA)**: Añadido soporte nativo para el modelo de última generación `large-v3-turbo` (Turbo), que ofrece la increíble precisión de `large-v3` a la velocidad de procesamiento del modelo `small`.
- **Menú Simplificado y Optimizado**: Se redujeron las opciones del menú de selección a la terna útil ideal: **Turbo** (Calidad Pro/Máxima), **Small** (El Bueno/Balanceado) y **Base** (El Rápido/Borrador).
- **Entorno Virtual Aislado (`.venv`)**: Aislamiento local de dependencias de Python para evitar contaminar la instalación de tu sistema global.

### ✨ Novedades de la v1.3
- **Renombramiento General**: Consolidación total del ecosistema bajo el nombre **Titofy CMD** (ex LyricSync).
- **Scroll Continuo Suave (Cross-fade Scroll)**: Efecto dinámico de desplazamiento vertical que previene saltos de texto abruptos.
- **Resaltado Spotify-Style**: Iluminación progresiva de letras letra a letra (`renderProgressLine`) a 20 FPS (50ms).

---

## 📁 Estructura del Proyecto

```
titofy_cmd/
├── index.js                  → Punto de entrada unificado
├── generate-lrc.js           → Orquestador CLI (Node.js → Python)
├── whisper_transcribe.py     → Motor IA de transcripción (offline)
├── whisper_align.py          → Forced Alignment (letra existente → .lrc)
├── lyrics_postprocess.py     → Post-procesador inteligente
├── music_detector.py         → Clasificador de secciones musicales
├── api_server.py             → API local FastAPI (microservicio)
├── lyric_config.py           → Cargador de configuración
├── logger.py                 → Sistema de logging profesional
├── config.yaml               → Configuración central (todos los parámetros)
├── package.json / requirements.txt
├── lrc/                      → Letras generadas (.lrc)
├── logs/                     → Logs del sistema
├── bin/                      → FFmpeg bundled (opcional)
├── scripts/
│   └── download-ffmpeg.js    → Instalador de FFmpeg bundled
└── src/
    ├── config.js             → Configuración global y utilidades
    ├── player.js             → Coordinador del reproductor TUI
    ├── renderer.js           → Renderizado terminal (ANSI)
    ├── audio.js              → Gestor de procesos ffplay
    ├── lrc-parser.js         → Parser de archivos .lrc
    ├── keyboard.js           → Captura de teclado
    ├── logger.js             → Logging Node.js
    ├── ffmpeg-resolver.js    → Resolver FFmpeg (bundle + PATH fallback)
    ├── api-client.js         → Cliente HTTP para la API local
    ├── batch-worker.js       → Worker pool para batch paralelo
    └── ui/
        ├── menu-core.js      → Motor del menú interactivo
        └── menu-actions.js   → Acciones del menú
```

---

## ⚙️ Requisitos del Sistema

| Requisito | Versión mínima | Para qué |
|-----------|---------------|----------|
| **Node.js** | v18+ | Menú interactivo y reproductor |
| **Python** | v3.9+ | Motor de transcripción Whisper |
| **FFmpeg** | cualquiera | Extracción de audio y reproducción |

---

## 🚀 Instalación Completa

### 1. Clonar o descargar el proyecto

```bash
cd "C:\Users\TuUsuario\Documents"
git clone <tu-repo> titofy-cmd
cd titofy-cmd
```

### 2. Instalar dependencias de Node.js

```bash
npm install
```

Esto instala automáticamente:
- `chalk@4` — colores en terminal
- `inquirer@8` — menú interactivo con flechas
- `js-yaml` — lectura de configuración YAML

### 3. Instalar dependencias de Python

Recomendamos utilizar el entorno virtual local `.venv` (el cual es resuelto automáticamente por la app):

```bash
# Crear entorno virtual (.venv)
python -m venv .venv

# Instalar dependencias
.venv\Scripts\pip install -r requirements.txt
```

| Paquete | Tamaño | Para qué |
|---------|--------|----------|
| `stable-ts` | ~2 MB | Wrapper para Whisper con alineamiento DTW y VAD |
| `faster-whisper` | ~3 MB | Motor de inferencia ultrarrápido (CTranslate2) |
| `openai-whisper` | ~3 MB | Motor IA estándar (usado como fallback) |
| `rapidfuzz` | ~1.5 MB | Fuzzy matching para limpieza de duplicados |
| `pyyaml` | ~0.5 MB | Lectura de config.yaml |
| `fastapi` | ~1 MB | API local (microservicio HTTP) |
| `uvicorn` | ~0.5 MB | Servidor ASGI para FastAPI |

> ⚠️ **Nota:** La primera vez que generes letras, se descargarán una única vez los modelos de IA localmente (~800 MB para `turbo` y un detector VAD hiper-ligero). A partir de allí, puedes usar la app **incluso sin conexión a internet o WiFi.**

### 4. Instalar FFmpeg (si no lo tienes)

```bash
# Windows (con winget)
winget install Gyan.FFmpeg

# O descárgalo manualmente de: https://ffmpeg.org/download.html
```

Verifica que esté instalado:
```bash
ffplay -version
```

**Alternativa: FFmpeg bundled** (incluido en el proyecto)
```bash
npm run ffmpeg:install
```
> Descarga FFmpeg (~85MB) directamente en `bin/`. LyricSync lo detecta automáticamente.

---

## 🎮 Cómo Usar

### Opción 1: Menú interactivo (recomendado)

```bash
npm start
# o también:
node index.js
# o directamente:
node menu.js
```

El menú te permite:
- 📁 **Explorar** tu carpeta de música (detecta `.mp3`, `.wav`, `.m4a`, `.flac`, `.mkv`, `.mp4`, etc.)
- 🤖 **Generar letras** con Whisper (elige el modelo de IA)
- ▶️ **Reproducir** canciones con letras sincronizadas
- 📋 **Ver** los archivos `.lrc` generados
- 🚀 **Procesar en lote** varias canciones a la vez

### Opción 2: Generar letras por CLI (directo)

```bash
node generate-lrc.js "C:\ruta\a\cancion.mp3" --language es
```

Opciones disponibles:
```
--output  -o  <archivo.lrc>   Nombre del archivo de salida
--model   -m  <modelo>        Modelo Whisper (default: small)
--language -l <codigo>        Forzar idioma: es, en, pt, fr... (default: auto)
--words                       Timestamps por PALABRA
```

### Opción 3: Forced Alignment (sincronizar con letra existente)

```bash
python whisper_align.py audio.mp3 --lyrics letra.txt --language es
```

> 💥 **Nivel Spotify lyrics sync**: si ya tienes la letra, esto produce sincronización perfecta.

### Opción 4: API local (para integraciones)

```bash
npm run api
# API disponible en http://127.0.0.1:8642/docs
```

Endpoints:
- `POST /transcribe` — Transcribir audio
- `POST /align` — Forced alignment
- `POST /postprocess` — Limpiar .lrc existente
- `GET /status/{id}` — Estado de tarea
- `GET /health` — Salud del servidor

### Opción 5: Limpiar un .lrc existente (post-procesador standalone)

```bash
python lyrics_postprocess.py "lrc/mi_cancion.lrc"
python lyrics_postprocess.py "lrc/mi_cancion.lrc" --output limpia.lrc
```

---

## 🤖 Modelos de Whisper

| Modelo   | Precisión | Velocidad (CPU)*       | RAM   | Tamaño descarga | Descripción |
|----------|-----------|----------------------|-------|-----------------|-------------|
| `base`   | ⭐⭐      | ⚡⚡⚡ ~10 seg/canción  | ~1 GB | ~139 MB         | El rápido: baja precisión, menos recursos |
| `small`  | ⭐⭐⭐     | ⚡⚡ ~20-30 seg/canción | ~2 GB | ~461 MB         | El bueno: balance recomendado para uso estándar |
| `turbo`  | ⭐⭐⭐⭐⭐ ← recomendado | ⚡ ~30-40 seg/canción | ~4 GB | ~809 MB | Lo mejor: calidad profesional (large-v3) y velocidad extrema |

> 💡 *Los tiempos son estimaciones para una canción de ~3 minutos en CPU usando la aceleración `faster-whisper` (`int8`). Con GPU NVIDIA los tiempos se reducen drásticamente (menos de 5 segundos).*

---

## 🧹 Post-procesador de Letras

El post-procesador `lyrics_postprocess.py` se ejecuta automáticamente después de cada transcripción y corrige:

| Corrección | Ejemplo |
|-----------|---------|
| Repeticiones internas | `lo que se fue ×20` → `lo que se fue` |
| Duplicados consecutivos | 3 líneas iguales seguidas → 1 sola |
| Duplicados fuzzy (85%+ similares) | Variaciones mínimas → 1 sola |
| Alucinaciones de Whisper | `"Gracias por ver"`, `"Suscríbete"` → eliminados |
| Timestamps imposibles | Segmentos de >30s con poco texto → eliminados |

---

## 📄 Formato .lrc

Puedes crear archivos `.lrc` manualmente con este formato:

```
[ti:Nombre de la canción]
[00:01.00]Primera línea de la letra
[00:05.50]Segunda línea
[00:10.00]♪
```

---

## 🔧 Solución de Problemas

| Error | Solución |
|-------|----------|
| `Python no está instalado` | Instala Python 3.9+ desde https://www.python.org/downloads/ |
| `ffplay no encontrado` | Instala FFmpeg: `winget install Gyan.FFmpeg` y reinicia la terminal |
| `ModuleNotFoundError: whisper` | Ejecuta: `pip install openai-whisper` |
| `ModuleNotFoundError: rapidfuzz` | Ejecuta: `pip install rapidfuzz` |
| Letras con muchos errores | Usa `--language es` para forzar el idioma |
| Audio sigue sonando después de Ctrl+C | Ya corregido — ffplay se mata automáticamente |

---

## 🌐 Roadmap

- [x] **Fase 1** — Letras sincronizadas en terminal
  - [x] Transcripción offline con Whisper local
  - [x] Menú interactivo con selección de canciones
  - [x] Procesamiento en lote
  - [x] Post-procesador anti-alucinaciones
  - [x] Soporte multi-formato (mp3, wav, m4a, flac, mkv, mp4...)
- [x] **Fase 1.5** — Mejoras Pro++ (actual)
  - [x] API local FastAPI (microservicio)
  - [x] Config avanzada YAML centralizada
  - [x] Logging profesional (niveles + archivo)
  - [x] Forced Alignment (sincronizar con letra existente)
  - [x] Detección musical: (intro), (coro), (instrumental), (outro)
  - [x] Evaluación de calidad (score de confianza por transcripción)
  - [x] Procesamiento batch paralelo (worker pool)
  - [x] FFmpeg bundled con fallback
  - [x] Limpieza de dependencias
- [ ] **Fase 2** — Web app (subir audio → genera video con letras)
- [ ] **Fase 3** — App móvil (reproductor de música con letras)
