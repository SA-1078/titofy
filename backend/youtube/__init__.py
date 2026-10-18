# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/youtube — Módulo de extracción e integración con YouTube y YouTube Music.
"""

from .extractor import extract_youtube_metadata, normalize_yt_url
from .stream import get_youtube_audio_stream_url
from .downloader import download_youtube_audio_track

__all__ = [
    "extract_youtube_metadata",
    "normalize_yt_url",
    "get_youtube_audio_stream_url",
    "download_youtube_audio_track",
]
