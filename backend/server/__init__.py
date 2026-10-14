# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
server — Módulos internos del servidor FastAPI Titofy.
"""

from .schemas import (
    TaskState,
    TranscribeRequest,
    AlignRequest,
    PostprocessRequest,
    ResolveLyricsRequest,
    PreloadModelRequest,
)
from .process import start_parent_watchdog, free_port_if_in_use
from .tasks import (
    tasks,
    model_cache,
    model_download_status,
    task_lock,
    get_model,
    run_transcription,
    run_alignment,
    download_worker,
)

__all__ = [
    "TaskState",
    "TranscribeRequest",
    "AlignRequest",
    "PostprocessRequest",
    "ResolveLyricsRequest",
    "PreloadModelRequest",
    "start_parent_watchdog",
    "free_port_if_in_use",
    "tasks",
    "model_cache",
    "model_download_status",
    "task_lock",
    "get_model",
    "run_transcription",
    "run_alignment",
    "download_worker",
]
