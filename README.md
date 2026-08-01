# 🎵 Titofy v2.0 — Suite Multimedia Offline de Letras Sincronizadas

**Titofy** es una suite 100% local y offline que genera letras de canciones sincronizadas automáticamente usando inteligencia artificial (ecosistema Whisper acelerado por hardware) y las reproduce al ritmo de la música.

Incluye:
- Interfaz de terminal (CLI) con reproductor y visualizador espectral
- Motor de IA local + API FastAPI
- Inicio de la aplicación de escritorio nativa (Flutter)

**Todo se procesa en tu propio ordenador. Nada se sube a internet.**

---

## ✨ ¿Qué es nuevo en la v2.0?

La versión **2.0** representa el gran salto arquitectónico del proyecto:

- **Arquitectura Monorepo**: El código se reorganizó en tres módulos independientes:
  - `backend/` → Motor de IA y API local (Python)
  - `cli/` → Interfaz de terminal, reproductor y visualizador (Node.js)
  - `desktop/` → Aplicación gráfica de escritorio (Flutter)
- **Inicio de la App Desktop**: Primera versión de la interfaz nativa para Linux y Windows (UI básica inicial).
- **Mejor separación de responsabilidades**: Cada módulo tiene su propio entorno de dependencias aislado.
- Se conservan todas las mejoras de la v1.4 (faster-whisper, modelo turbo, Forced Alignment, post-procesador, etc.).

### Estado actual de la v2.0

| Módulo | Estado | Recomendado para uso diario |
| :--- | :--- | :--- |
| **CLI** | Estable y funcional | Sí |
| **Backend** | Estable y funcional | Sí |
| **App Desktop** | En desarrollo temprano (UI básica) | Aún no (experimental) |

---

## ✨ Novedades heredadas de la v1.4 y v1.3

### De la v1.4
- Aceleración con **faster-whisper** (CTranslate2): 4x a 8x más rápido en CPU y GPU.
- Cuantización inteligente **int8** para CPU (bajo consumo de RAM).
- Modelo **turbo** (`large-v3-turbo`): calidad de large-v3 a velocidad de small.
- Menú simplificado con tres modelos útiles: Turbo, Small y Base.
- Entorno virtual aislado (`.venv`).

### De la v1.3
- Renombramiento completo a **Titofy CMD**.
- Scroll continuo suave (Cross-fade Scroll).
- Resaltado de letras estilo Spotify (palabra por palabra a 20 FPS).

---

## 📁 Estructura del Proyecto (Monorepo)

```text
titofy-cmd/
├── backend/                     → Motor de IA y API local (Python)
│   ├── api_server.py            → Microservicio FastAPI
│   ├── whisper_transcribe.py    → Transcripción con faster-whisper
│   ├── whisper_align.py         → Forced Alignment
│   ├── lyrics_postprocess.py    → Post-procesador anti-alucinaciones
│   ├── music_detector.py        → Detección de secciones musicales
│   ├── logger.py                → Sistema de logging
│   ├── config.yaml              → Configuración central
│   └── requirements.txt
│
├── cli/                         → Interfaz de terminal (Node.js)
│   ├── index.js                 → Punto de entrada
│   ├── generate-lrc.js          → Generador de letras por CLI
│   ├── src/                     → Reproductor, visualizador y TUI
│   ├── package.json
│   └── ...
│
├── desktop/                     → Aplicación de escritorio (Flutter)
│   ├── lib/
│   ├── pubspec.yaml
│   └── ...                      → (UI básica inicial - en desarrollo)
│
├── lrc/                         → Letras generadas (.lrc)
├── logs/                        → Logs del sistema
└── README.md
```

---

## ⚙️ Requisitos del Sistema

| Requisito | Versión mínima | Para qué |
| :--- | :--- | :--- |
| **Node.js** | v18+ | CLI, menú interactivo y reproductor |
| **Python** | v3.9+ (recomendado 3.11+) | Motor de transcripción e IA |
| **Flutter** | 3.x+ | App Desktop (solo si la vas a usar) |
| **FFmpeg** | cualquiera | Extracción de audio y reproducción |

---

## 🚀 Instalación Completa

### 1. Clonar el repositorio

```bash
git clone <tu-repo> titofy-cmd
cd titofy-cmd
```

### 2. Configurar el Backend (Python)

```bash
cd backend
python -m venv .venv

# Windows
.venv\Scripts\activate

# Linux / macOS
source .venv/bin/activate

pip install -r requirements.txt
```

### 3. Configurar la CLI (Node.js)

```bash
cd ../cli
npm install
```

### 4. (Opcional) Configurar la App Desktop

```bash
cd ../desktop
flutter pub get
```

*Nota: La App Desktop todavía está en etapa temprana. Se recomienda usar la CLI para uso diario.*

### 5. FFmpeg

Si no lo tienes instalado:

```bash
# Windows
winget install Gyan.FFmpeg

# Linux (ejemplo Ubuntu/Debian)
sudo apt install ffmpeg
```

Verifica la instalación:

```bash
ffplay -version
```

---

## 🎮 Cómo Usar

### Opción 1: Menú interactivo (recomendado)

```bash
cd cli
npm start
```

El menú te permite:
- Explorar tu carpeta de música (`.mp3`, `.wav`, `.m4a`, `.flac`, `.mp4`, etc.)
- Generar letras con IA local (elige el modelo)
- Reproducir canciones con letras sincronizadas
- Ver los archivos `.lrc` generados
- Procesar varias canciones en lote
- Usar Forced Alignment

### Opción 2: Generar letras por CLI (directo)

```bash
cd cli
node generate-lrc.js "ruta/a/cancion.mp3" --language es --model turbo
```

Opciones principales:
- `--model` / `-m` → `turbo`, `small` o `base`
- `--language` / `-l` → `es`, `en`, `pt`, etc.
- `--output` / `-o` → nombre del archivo de salida

### Opción 3: Forced Alignment

```bash
cd backend
python whisper_align.py audio.mp3 --lyrics letra.txt --language es
```

Ideal cuando ya tienes la letra en texto plano y quieres sincronizarla perfectamente.

### Opción 4: API Local (FastAPI)

```bash
cd backend
python api_server.py
```

Documentación interactiva disponible en: `http://127.0.0.1:8642/docs`

Endpoints principales:
- `POST /transcribe` → Transcribir audio desde cero
- `POST /align` → Forced Alignment
- `POST /postprocess` → Limpiar un `.lrc`
- `GET /health` → Estado del servidor y detección de hardware

---

## 🤖 Modelos de Whisper disponibles

| Modelo | Precisión | Velocidad (CPU)* | RAM aprox. | Descripción |
| :--- | :---: | :---: | :---: | :--- |
| **`base`** | ⭐⭐ | Muy rápida (~10s) | ~1 GB | El rápido (borrador / pruebas) |
| **`small`** | ⭐⭐⭐ | Rápida (~20-30s) | ~2 GB | Balance recomendado para uso diario |
| **`turbo`** | ⭐⭐⭐⭐⭐ | Buena (~30-40s) | ~4 GB | **Recomendado** – Mejor calidad (SOTA) |

*\* Tiempos estimados para una canción de ~3 minutos usando faster-whisper en CPU (int8). Con GPU NVIDIA los tiempos bajan drásticamente.*

---

## 🧹 Post-procesador de Letras

Se ejecuta automáticamente después de cada transcripción y corrige:

| Problema | Acción |
| :--- | :--- |
| Repeticiones internas | Se reducen a una sola aparición |
| Duplicados consecutivos | Se eliminan |
| Duplicados similares (fuzzy) | Se unifican |
| Alucinaciones típicas | Se eliminan (“Gracias por ver”, etc.) |
| Timestamps imposibles | Se filtran |

---

## 📄 Formato .lrc

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
| `Python no encontrado` | Instala Python 3.9+ |
| `ffplay no encontrado` | Instala FFmpeg y reinicia la terminal |
| `ModuleNotFoundError` | Activa el `.venv` e instala `requirements.txt` |
| `Letras con muchos errores` | Usa `--language es` (o el idioma correcto) |
| `La App Desktop no compila` | Asegúrate de tener Flutter instalado y ejecuta `flutter doctor` |

---

## 🌐 Ruta de Desarrollo (Roadmap)

### ✅ Completado
- Motor de transcripción offline con `faster-whisper` y modelo `turbo`
- CLI completa con menú interactivo, reproductor y visualizador
- Forced Alignment
- API local FastAPI
- Post-procesador anti-alucinaciones
- Reestructuración a Monorepo (v2.0)
- Inicio de la App Desktop en Flutter

### 🚧 En desarrollo
- Mejora y estabilización de la App Desktop
- Mejoras adicionales de la experiencia CLI
- Posible modo híbrido (búsqueda de letras online + fallback local)

### 🔮 Planeado
- Empaquetado e instaladores sencillos
- Más opciones de personalización
- Posibles versiones web o móvil en el futuro

---

## 📌 Notas importantes de la v2.0

1. Esta versión introduce la **arquitectura monorepo**.
2. La CLI y el Backend son la parte madura y recomendada para uso diario.
3. La App Desktop se encuentra en una etapa temprana (UI básica). Se irá mejorando en próximas versiones.
