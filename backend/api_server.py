#!/usr/bin/env python3
# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
api_server.py — Titofy
Microservicio local FastAPI que expone el motor Whisper como endpoints HTTP.

Uso:
    python api_server.py
    npm run api

Endpoints:
    POST /transcribe     → Transcribir audio a LRC (async con task_id)
    POST /postprocess    → Limpiar un .lrc existente
    POST /align          → Forced alignment con letra existente
    GET  /status/{id}    → Estado de una tarea en curso
    GET  /health         → Estado del servidor
    GET  /config         → Configuración actual
"""

import os
import sys

# Asegurar que el directorio de este script esté en sys.path para resolver los imports de la misma carpeta
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from logger import SafeStream, get_logger
if not isinstance(sys.stdout, SafeStream):
    sys.stdout = SafeStream(sys.stdout)
if not isinstance(sys.stderr, SafeStream):
    sys.stderr = SafeStream(sys.stderr)

import uuid
import time
import threading
import signal
from datetime import datetime

# Evitar que una escritura sobre un pipe/socket cerrado
# termine todo el proceso mediante SIGPIPE.
if hasattr(signal, "SIGPIPE"):
    signal.signal(signal.SIGPIPE, signal.SIG_IGN)

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

from lyric_config import get_config
from logger import get_logger

log = get_logger("api")
cfg = get_config()

# ──────────────────────────────────────────────────────────────────────────────
# App FastAPI
# ──────────────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Titofy API",
    description="Motor de transcripción y sincronización de letras offline",
    version="1.0.0",
)

# CORS para futura web app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ──────────────────────────────────────────────────────────────────────────────
# Estado global
# ──────────────────────────────────────────────────────────────────────────────

tasks = {}          # {task_id: TaskState}
model_cache = {}    # {model_name: loaded_model}
_lock = threading.Lock()


class TaskState:
    def __init__(self, task_type, audio_path):
        self.task_id = str(uuid.uuid4())[:8]
        self.task_type = task_type
        self.audio_path = audio_path
        self.status = "queued"      # queued → running → done → error
        self.progress = 0
        self.result = None
        self.error = None
        self.created_at = datetime.now().isoformat()
        self.completed_at = None

    def to_dict(self):
        return {
            "task_id": self.task_id,
            "task_type": self.task_type,
            "status": self.status,
            "progress": self.progress,
            "result": self.result,
            "error": self.error,
            "created_at": self.created_at,
            "completed_at": self.completed_at,
        }


# ──────────────────────────────────────────────────────────────────────────────
# Modelos Pydantic
# ──────────────────────────────────────────────────────────────────────────────

class TranscribeRequest(BaseModel):
    audio_path: str
    model: str = "small"
    language: str = "es"
    output_path: Optional[str] = None
    word_mode: bool = False

class AlignRequest(BaseModel):
    audio_path: str
    lyrics_text: str
    model: str = "base"
    language: str = "es"
    output_path: Optional[str] = None

class PostprocessRequest(BaseModel):
    lrc_path: str
    threshold: int = 85
    output_path: Optional[str] = None

class ResolveLyricsRequest(BaseModel):
    artist: Optional[str] = None
    title: Optional[str] = None
    duration: Optional[float] = None
    audio_path: Optional[str] = None
    mode: Optional[str] = "auto"          # "auto", "offline", "ai_only", "online_only"
    model: Optional[str] = "small"
    language: Optional[str] = "auto"
    output_path: Optional[str] = None
    force: Optional[bool] = False


class PreloadModelRequest(BaseModel):
    model: Optional[str] = "small"


# ──────────────────────────────────────────────────────────────────────────────
# Workers (background threads)
# ──────────────────────────────────────────────────────────────────────────────

def _get_model(model_name: str):
    """Carga un modelo con cache."""
    if model_name not in model_cache:
        from whisper_transcribe import detect_device, load_whisper_model
        device, device_name = detect_device()
        wcfg = cfg.get("whisper", {})
        compute_type = wcfg.get("compute_type", "auto")
        
        log.info(f"Cargando modelo '{model_name}' en {device} (primera vez, se cacheará)...")
        model, is_faster = load_whisper_model(model_name, device=device, compute_type=compute_type)
        model_cache[model_name] = model
    return model_cache[model_name]


def _run_transcription(task: TaskState, req: TranscribeRequest):
    """Worker de transcripción en background."""
    try:
        task.status = "running"
        task.progress = 10
        log.info(f"[{task.task_id}] Transcripción iniciada: {req.audio_path}")

        from whisper_engine.transcribe import transcribe_audio
        output = req.output_path or os.path.splitext(os.path.basename(req.audio_path))[0] + ".lrc"

        # Asegurar que el directorio de salida exista
        lrc_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lrc")
        os.makedirs(lrc_dir, exist_ok=True)
        output_full = os.path.join(lrc_dir, output) if not os.path.isabs(output) else output

        task.progress = 20
        transcribe_audio(
            audio_path=req.audio_path,
            output_path=output_full,
            model_name=req.model,
            language=req.language,
            word_mode=req.word_mode,
        )

        task.progress = 100
        task.status = "done"
        task.result = {"output_path": output_full}
        task.completed_at = datetime.now().isoformat()
        log.info(f"[{task.task_id}] Transcripción completada: {output_full}")

    except Exception as e:
        task.status = "error"
        task.error = str(e)
        task.completed_at = datetime.now().isoformat()
        log.error(f"[{task.task_id}] Error en transcripción: {e}")


def _run_alignment(task: TaskState, req: AlignRequest):
    """Worker de forced alignment en background."""
    try:
        task.status = "running"
        task.progress = 10
        log.info(f"[{task.task_id}] Alineación iniciada: {req.audio_path}")

        from whisper_align import align_lyrics
        output = req.output_path or os.path.splitext(os.path.basename(req.audio_path))[0] + ".lrc"

        lrc_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lrc")
        os.makedirs(lrc_dir, exist_ok=True)
        output_full = os.path.join(lrc_dir, output) if not os.path.isabs(output) else output

        task.progress = 20
        align_lyrics(
            audio_path=req.audio_path,
            lyrics_text=req.lyrics_text,
            output_path=output_full,
            model_name=req.model,
            language=req.language,
        )

        task.progress = 100
        task.status = "done"
        task.result = {"output_path": output_full}
        task.completed_at = datetime.now().isoformat()
        log.info(f"[{task.task_id}] Alineación completada: {output_full}")

    except Exception as e:
        task.status = "error"
        task.error = str(e)
        task.completed_at = datetime.now().isoformat()
        log.error(f"[{task.task_id}] Error en alineación: {e}")


# ──────────────────────────────────────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────────────────────────────────────

@app.post("/transcribe")
async def transcribe(req: TranscribeRequest):
    """Inicia una transcripción en background. Retorna task_id para polling."""
    if not os.path.exists(req.audio_path):
        raise HTTPException(status_code=404, detail=f"Audio no encontrado: {req.audio_path}")

    task = TaskState("transcribe", req.audio_path)
    with _lock:
        tasks[task.task_id] = task

    thread = threading.Thread(target=_run_transcription, args=(task, req), daemon=True)
    thread.start()

    log.info(f"Tarea creada [{task.task_id}]: transcribe {req.audio_path}")
    return {"task_id": task.task_id, "status": "queued"}


@app.post("/align")
async def align(req: AlignRequest):
    """Inicia forced alignment en background."""
    if not os.path.exists(req.audio_path):
        raise HTTPException(status_code=404, detail=f"Audio no encontrado: {req.audio_path}")

    task = TaskState("align", req.audio_path)
    with _lock:
        tasks[task.task_id] = task

    thread = threading.Thread(target=_run_alignment, args=(task, req), daemon=True)
    thread.start()

    log.info(f"Tarea creada [{task.task_id}]: align {req.audio_path}")
    return {"task_id": task.task_id, "status": "queued"}


@app.post("/postprocess")
async def postprocess(req: PostprocessRequest):
    """Post-procesa un .lrc existente (sincrónico, es rápido)."""
    if not os.path.exists(req.lrc_path):
        raise HTTPException(status_code=404, detail=f"LRC no encontrado: {req.lrc_path}")

    from lyrics_postprocess import parse_lrc_file, postprocess_segments, segments_to_lrc

    segments = parse_lrc_file(req.lrc_path)
    if not segments:
        raise HTTPException(status_code=400, detail="No se encontraron segmentos en el LRC")

    clean = postprocess_segments(segments, req.threshold)
    output = req.output_path or req.lrc_path

    title = os.path.splitext(os.path.basename(req.lrc_path))[0]
    lrc_content = segments_to_lrc(clean, title, "Titofy — post-procesado vía API")

    with open(output, "w", encoding="utf-8") as f:
        f.write(lrc_content)

    log.info(f"Post-procesado: {req.lrc_path} → {output} ({len(clean)} segmentos)")
    return {
        "output_path": output,
        "original_segments": len(segments),
        "clean_segments": len(clean),
    }


@app.post("/lyrics/resolve")
async def resolve_lyrics(req: ResolveLyricsRequest):
    """
    Resuelve la letra de una canción usando el motor híbrido (Caché → Online → Forced Alignment → Whisper).
    """
    import sys
    import importlib
    if "lyrics.resolver" in sys.modules:
        try:
            importlib.reload(sys.modules["lyrics.resolver"])
        except Exception:
            pass
    from lyrics.resolver import LyricsResolver
    resolver = LyricsResolver()

    try:
        data = await resolver.resolve_async(
            artist=req.artist,
            title=req.title,
            duration=req.duration,
            audio_path=req.audio_path,
            mode=req.mode or "auto",
            model_name=req.model or "small",
            language=req.language or "auto",
            output_lrc=req.output_path,
            force=bool(req.force),
        )
        if data is None:
            raise HTTPException(status_code=404, detail="No se encontraron letras para esta canción")
        return data.to_dict()
    except HTTPException:
        raise
    except (ValueError, FileNotFoundError) as e:
        log.warning(f"No se pudo resolver letra: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        import traceback
        log.error(f"Error en /lyrics/resolve: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))



@app.get("/status/{task_id}")

async def get_status(task_id: str):
    """Consulta el estado de una tarea."""
    task = tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")
    return task.to_dict()


@app.get("/tasks")
async def list_tasks():
    """Lista todas las tareas."""
    return [t.to_dict() for t in tasks.values()]


@app.get("/health")
async def health():
    """Estado del servidor."""
    return {
        "status": "ok",
        "models_loaded": list(model_cache.keys()),
        "active_tasks": len([t for t in tasks.values() if t.status in ("queued", "running")]),
        "total_tasks": len(tasks),
    }


@app.get("/models")
async def list_models():
    """Consulta los 3 modelos Whisper oficiales (base, small, turbo) y su estado de descarga."""
    try:
        from whisper_engine.loader import is_model_downloaded
        models = [
            {
                "id": "base",
                "name": "BASE (Rápido)",
                "size": "~145 MB",
                "description": "Rápido y ligero para audios claros",
                "downloaded": is_model_downloaded("base"),
            },
            {
                "id": "small",
                "name": "SMALL (Recomendado)",
                "size": "~465 MB",
                "description": "Equilibrado en precisión y velocidad",
                "downloaded": is_model_downloaded("small"),
            },
            {
                "id": "turbo",
                "name": "TURBO (large-v3)",
                "size": "~1.5 GB",
                "description": "Máxima fidelidad en canciones complejas",
                "downloaded": is_model_downloaded("turbo"),
            },
        ]
        return {"models": models, "loaded": list(model_cache.keys())}
    except Exception as e:
        return {"models": [], "error": str(e)}


@app.post("/models/preload")
async def preload_model(req: Optional[PreloadModelRequest] = None):
    """Descarga/precarga en caché un modelo Whisper por adelantado."""
    model_name = (req.model if req and req.model else "small")
    import asyncio
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _get_model, model_name)
    return {"status": "ok", "model": model_name, "downloaded": True}


@app.get("/config")
async def get_config_endpoint():
    """Configuración actual."""
    return get_config()


@app.post("/shutdown")
async def shutdown():
    """Permite reiniciar el proceso del servidor para recargar código actualizado."""
    import threading
    def _kill():
        import time
        time.sleep(0.2)
        os._exit(0)
    threading.Thread(target=_kill, daemon=True).start()
    return {"status": "shutting_down"}


# ──────────────────────────────────────────────────────────────────────────────
def _free_port_if_in_use(port: int):
    """Mata cualquier proceso huérfano anterior que esté ocupando el puerto para permitir inicio limpio."""
    import socket
    import subprocess
    import time

    # Verificar si el puerto ya está en uso
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        in_use = (s.connect_ex(("127.0.0.1", port)) == 0)

    if not in_use:
        return

    log.warning(f"Puerto {port} ocupado por un proceso previo. Terminando proceso huérfano para inicio limpio...")
    current_pid = os.getpid()

    if os.name == "nt":
        try:
            out = subprocess.check_output(f"netstat -ano | findstr :{port}", shell=True, text=True)
            for line in out.splitlines():
                parts = line.strip().split()
                if len(parts) >= 5 and "LISTENING" in parts:
                    pid = int(parts[-1])
                    if pid != current_pid and pid > 0:
                        subprocess.run(f"taskkill /F /PID {pid}", shell=True, capture_output=True)
        except Exception:
            pass
    else:
        try:
            subprocess.run(["fuser", "-k", f"{port}/tcp"], capture_output=True)
        except Exception:
            try:
                out = subprocess.check_output(["lsof", "-t", f"-i:{port}"], text=True)
                for pid_str in out.splitlines():
                    pid = int(pid_str.strip())
                    if pid != current_pid and pid > 0:
                        os.kill(pid, 9)
            except Exception:
                pass

    time.sleep(0.4)


if __name__ == "__main__":
    import uvicorn

    host = cfg["api"]["host"]
    port = cfg["api"]["port"]

    # Liberar puerto huérfano si estaba ocupado
    _free_port_if_in_use(port)

    print()
    print("  ╭──────────────────────────────────────────────────╮")
    print("  │  🚀 Titofy API — Servidor Local                 │")
    print("  ╰──────────────────────────────────────────────────╯")
    print(f"  🌐 URL: http://{host}:{port}")
    print(f"  📋 Docs: http://{host}:{port}/docs")
    print()

    log.info(f"API server iniciando en {host}:{port}")

    uvicorn.run(app, host=host, port=port, log_level="warning")
