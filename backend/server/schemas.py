# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
server/schemas.py — Modelos de datos Pydantic y estado de tareas para Titofy API.
"""

import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class TaskState:
    """Representa el ciclo de vida y estado de una tarea asíncrona de IA."""
    def __init__(self, task_type: str, audio_path: str):
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


class ExtractYouTubeRequest(BaseModel):
    url: str


class YouTubeStreamRequest(BaseModel):
    video_id: str


class YouTubeDownloadRequest(BaseModel):
    video_id: str
    title: Optional[str] = None
    artist: Optional[str] = None
    target_folder: Optional[str] = None

