# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
server/tasks.py — Gestión de tareas en segundo plano, workers de Whisper y caché de modelos en RAM.
"""

import os
import sys
import threading
from datetime import datetime
from typing import Optional, Any

# Asegurar que backend esté en sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from logger import get_logger
from lyric_config import get_config
from server.schemas import TaskState, TranscribeRequest, AlignRequest

log = get_logger("api.tasks")
cfg = get_config()

# Estado global de tareas y modelos
tasks: dict[str, TaskState] = {}
model_cache: dict[str, Any] = {}
model_download_status: dict[str, dict[str, Optional[str]]] = {}
task_lock = threading.Lock()


def get_model(model_name: str):
    """Carga un modelo con cache manteniendo como máximo 1 modelo en memoria RAM."""
    global model_cache
    with task_lock:
        if model_name in model_cache:
            return model_cache[model_name]

        # Liberar modelo previo para evitar acumular 20 GB de memoria RAM
        if model_cache:
            log.info("Liberando modelo previo en memoria RAM...")
            model_cache.clear()
            import gc
            gc.collect()

        from whisper_engine.loader import load_whisper_model, detect_device
        device, device_name = detect_device()
        wcfg = cfg.get("whisper", {})
        compute_type = wcfg.get("compute_type", "auto")

        log.info(f"Cargando modelo '{model_name}' en {device} (1 modelo activo en RAM)...")
        model, is_faster = load_whisper_model(model_name, device=device, compute_type=compute_type)
        model_cache[model_name] = model
        return model


def run_transcription(task: TaskState, req: TranscribeRequest) -> None:
    """Worker de transcripción en background."""
    try:
        task.status = "running"
        task.progress = 10
        log.info(f"[{task.task_id}] Transcripción iniciada: {req.audio_path}")

        import importlib
        # Eliminar de sys.modules para forzar re-importación desde sys.path[0]
        # (que es el workspace real cuando se lanza el exe con PYTHONPATH=backendDir)
        for _mod_key in list(sys.modules.keys()):
            if _mod_key.startswith("whisper_engine"):
                sys.modules.pop(_mod_key, None)
        try:
            import faster_whisper
            from whisper_engine.loader import _patch_whisper_model
            _patch_whisper_model(faster_whisper.WhisperModel)
        except Exception:
            pass
        from whisper_engine.transcribe import transcribe_audio
        output = req.output_path or os.path.splitext(os.path.basename(req.audio_path))[0] + ".lrc"

        # Asegurar que el directorio de salida exista
        lrc_dir = os.path.join(backend_dir, "lrc")
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


def run_alignment(task: TaskState, req: AlignRequest) -> None:
    """Worker de forced alignment en background."""
    try:
        task.status = "running"
        task.progress = 10
        log.info(f"[{task.task_id}] Alineación iniciada: {req.audio_path}")

        try:
            from whisper_engine.align import align_lyrics
        except ImportError:
            from whisper_align import align_lyrics
        output = req.output_path or os.path.splitext(os.path.basename(req.audio_path))[0] + ".lrc"

        lrc_dir = os.path.join(backend_dir, "lrc")
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


def download_worker(model_name: str) -> None:
    """Worker de descarga en segundo plano."""
    try:
        model_download_status[model_name] = {"status": "downloading", "error": None}
        from whisper_engine.loader import fix_loader
        snapshot = fix_loader(model_name)
        if not snapshot:
            raise RuntimeError(f"No se pudo descargar o verificar los pesos del modelo '{model_name}'.")
        get_model(model_name)
        model_download_status[model_name] = {"status": "ready", "error": None}
        log.info(f"Modelo '{model_name}' descargado y verificado en caché ({snapshot}).")
    except Exception as e:
        log.error(f"Error descargando modelo '{model_name}': {e}")
        model_download_status[model_name] = {"status": "error", "error": str(e)}
