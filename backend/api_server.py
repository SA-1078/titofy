#!/usr/bin/env python3
# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
api_server.py — Titofy
Microservicio local FastAPI que expone el motor Whisper y resolución de letras como endpoints HTTP.

Uso:
    python api_server.py
    npm run api

Endpoints:
    POST /transcribe         → Transcribir audio a LRC (async con task_id)
    POST /align              → Forced alignment con letra existente
    POST /postprocess        → Limpiar un .lrc existente
    POST /lyrics/resolve     → Resuelve letras con motor híbrido
    GET  /status/{task_id}   → Estado de una tarea en curso
    GET  /tasks              → Lista todas las tareas
    GET  /health             → Estado del servidor
    GET  /models             → Modelos Whisper disponibles y su estado
    POST /models/preload     → Precarga/descarga de modelo
    GET  /models/status/{m}  → Estado de un modelo específico
    GET  /config             → Configuración actual
    POST /shutdown           → Apagado controlado para recarga
"""

import os
import sys

# Give synced source modules precedence over PyInstaller's _MEI archive before
# importing any project module. This is harmless in regular Python launches.
_pypath_env = os.environ.get("PYTHONPATH", "")
for _p in reversed(_pypath_env.split(os.pathsep)):
    _p = _p.strip()
    if _p:
        while _p in sys.path:
            sys.path.remove(_p)
        sys.path.insert(0, _p)

# Inicializar entorno Windows si aplica (UTF-8, DLLs y parches)
if os.name == "nt":
    try:
        from windows import setup_windows_runtime
        setup_windows_runtime()
    except Exception:
        pass

# Asegurar que el directorio de trabajo (backend) esté en sys.path con máxima prioridad
cwd_dir = os.path.abspath(os.getcwd())
if cwd_dir not in sys.path:
    sys.path.insert(0, cwd_dir)
if getattr(sys, "frozen", False):
    exe_dir = os.path.dirname(sys.executable)
    if exe_dir not in sys.path:
        sys.path.insert(0, exe_dir)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# Cuando corre como exe congelado, anteponer PYTHONPATH al final (mayor prioridad)
# para que los .py reales del workspace ganen sobre _MEI
if getattr(sys, "frozen", False):
    _pypath_env = os.environ.get("PYTHONPATH", "")
    for _p in reversed(_pypath_env.split(os.pathsep)):
        _p = _p.strip()
        if _p:
            while _p in sys.path:
                sys.path.remove(_p)
            sys.path.insert(0, _p)

from logger import SafeStream, get_logger
if not isinstance(sys.stdout, SafeStream):
    sys.stdout = SafeStream(sys.stdout)
if not isinstance(sys.stderr, SafeStream):
    sys.stderr = SafeStream(sys.stderr)

import threading
from typing import Optional

# Limitar hilos de CPU para que Whisper / CTranslate2 no saturen la CPU
max_threads = str(min(4, max(1, (os.cpu_count() or 4) // 2)))
os.environ.setdefault("OMP_NUM_THREADS", max_threads)
os.environ.setdefault("MKL_NUM_THREADS", max_threads)
os.environ.setdefault("OPENBLAS_NUM_THREADS", max_threads)
os.environ.setdefault("VECLIB_MAXIMUM_THREADS", max_threads)
os.environ.setdefault("NUMEXPR_NUM_THREADS", max_threads)
os.environ.setdefault("CT2_NUM_THREADS", max_threads)

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from lyric_config import get_config
from server.schemas import (
    TaskState,
    TranscribeRequest,
    AlignRequest,
    PostprocessRequest,
    ResolveLyricsRequest,
    PreloadModelRequest,
    ExtractYouTubeRequest,
    YouTubeStreamRequest,
    YouTubeDownloadRequest,
)
from server.process import start_parent_watchdog, free_port_if_in_use
from server.tasks import (
    tasks,
    model_cache,
    model_download_status,
    task_lock,
    get_model,
    run_transcription,
    run_alignment,
    download_worker,
)

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ──────────────────────────────────────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────────────────────────────────────

@app.post("/transcribe")
async def transcribe(req: TranscribeRequest):
    """Inicia una transcripción en background. Retorna task_id para polling."""
    if req.audio_path.startswith("youtube:"):
        try:
            from youtube.downloader import download_youtube_audio_track
            dl_info = download_youtube_audio_track(video_id=req.audio_path)
            if dl_info and dl_info.get("file_path") and os.path.exists(dl_info["file_path"]):
                req.audio_path = dl_info["file_path"]
        except Exception as e:
            log.warning(f"Error auto-descargando audio de YouTube en transcribe: {e}")

    if not os.path.exists(req.audio_path):
        raise HTTPException(status_code=404, detail=f"Audio no encontrado: {req.audio_path}")

    task = TaskState("transcribe", req.audio_path)
    with task_lock:
        tasks[task.task_id] = task

    thread = threading.Thread(target=run_transcription, args=(task, req), daemon=True)
    thread.start()

    log.info(f"Tarea creada [{task.task_id}]: transcribe {req.audio_path}")
    return {"task_id": task.task_id, "status": "queued"}


@app.post("/align")
async def align(req: AlignRequest):
    """Inicia forced alignment en background."""
    if req.audio_path.startswith("youtube:"):
        try:
            from youtube.downloader import download_youtube_audio_track
            dl_info = download_youtube_audio_track(video_id=req.audio_path)
            if dl_info and dl_info.get("file_path") and os.path.exists(dl_info["file_path"]):
                req.audio_path = dl_info["file_path"]
        except Exception as e:
            log.warning(f"Error auto-descargando audio de YouTube en align: {e}")

    if not os.path.exists(req.audio_path):
        raise HTTPException(status_code=404, detail=f"Audio no encontrado: {req.audio_path}")

    task = TaskState("align", req.audio_path)
    with task_lock:
        tasks[task.task_id] = task

    thread = threading.Thread(target=run_alignment, args=(task, req), daemon=True)
    thread.start()

    log.info(f"Tarea creada [{task.task_id}]: align {req.audio_path}")
    return {"task_id": task.task_id, "status": "queued"}


@app.post("/postprocess")
async def postprocess(req: PostprocessRequest):
    """Post-procesa un .lrc existente (sincrónico, es rápido)."""
    if not os.path.exists(req.lrc_path):
        raise HTTPException(status_code=404, detail=f"LRC no encontrado: {req.lrc_path}")

    try:
        from postprocess import parse_lrc_file, postprocess_segments, segments_to_lrc
    except ImportError:
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
    """Resuelve la letra de una canción usando el motor híbrido (Caché → Online → Forced Alignment → Whisper)."""
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


@app.post("/youtube/playlist")
async def extract_youtube_playlist(req: ExtractYouTubeRequest):
    """
    Extrae los metadatos de una playlist o vídeo de YouTube / YouTube Music
    sin descargar ningún archivo de audio (modo metadatos primero).
    """
    from youtube.extractor import extract_youtube_metadata
    try:
        data = extract_youtube_metadata(req.url)
        return data
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        log.error(f"Error al extraer playlist de YouTube: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/youtube/stream")
async def get_youtube_stream(req: YouTubeStreamRequest):
    """
    Obtiene la URL directa de streaming de audio para reproducir vía media_kit.
    """
    from youtube.extractor import get_youtube_audio_stream_url
    try:
        data = get_youtube_audio_stream_url(req.video_id)
        return data
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        log.error(f"Error al obtener stream de YouTube: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/youtube/download")
async def download_youtube_track(req: YouTubeDownloadRequest):
    """
    Descarga el audio de una pista de YouTube en segundo plano a la carpeta local.
    """
    from youtube.extractor import download_youtube_audio_track
    try:
        data = download_youtube_audio_track(
            video_id=req.video_id,
            title=req.title,
            artist=req.artist,
            target_folder=req.target_folder,
        )
        return data
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        log.error(f"Error al descargar pista de YouTube: {e}")
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
    """Descarga/precarga en caché un modelo Whisper por adelantado sin bloquear."""
    model_name = (req.model if req and req.model else "small")
    from whisper_engine.loader import is_model_downloaded
    if is_model_downloaded(model_name) and model_name in model_cache:
        model_download_status[model_name] = {"status": "ready", "error": None}
        return {"status": "ready", "model": model_name, "downloaded": True}

    current = model_download_status.get(model_name, {})
    if current.get("status") == "downloading":
        return {"status": "downloading", "model": model_name, "downloaded": False}

    model_download_status[model_name] = {"status": "downloading", "error": None}
    thread = threading.Thread(target=download_worker, args=(model_name,), daemon=True)
    thread.start()
    return {"status": "downloading", "model": model_name, "downloaded": False}


@app.get("/models/status/{model_name}")
async def get_model_status(model_name: str):
    """Consulta el estado de descarga de un modelo."""
    from whisper_engine.loader import is_model_downloaded
    if is_model_downloaded(model_name):
        return {"model": model_name, "status": "ready", "error": None}
    status = model_download_status.get(model_name, {"status": "not_downloaded", "error": None})
    return {"model": model_name, **status}


@app.get("/config")
async def get_config_endpoint():
    """Configuración actual."""
    return get_config()


@app.post("/shutdown")
async def shutdown():
    """Permite reiniciar el proceso del servidor para recargar código actualizado."""
    def _kill():
        import time
        time.sleep(0.2)
        os._exit(0)
    threading.Thread(target=_kill, daemon=True).start()
    return {"status": "shutting_down"}


if __name__ == "__main__":
    import multiprocessing
    multiprocessing.freeze_support()

    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--parent-pid", type=int, default=0, help="PID del proceso padre")
    parsed_args, _ = parser.parse_known_args()
    if parsed_args.parent_pid > 0:
        log.info(f"Iniciando watchdog para proceso padre PID {parsed_args.parent_pid}")
        start_parent_watchdog(parsed_args.parent_pid)

    import uvicorn
    host = cfg["api"]["host"]
    port = cfg["api"]["port"]
    free_port_if_in_use(port)
    log.info(f"Titofy API iniciando en http://{host}:{port}")
    uvicorn.run(app, host=host, port=port, reload=False, workers=1, log_level="warning")
