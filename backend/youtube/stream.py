# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/youtube/stream.py — Obtención rápida de enlace CDN directo de streaming de audio.
"""

from __future__ import annotations
from typing import Any
import yt_dlp  # type: ignore


def get_youtube_audio_stream_url(video_id: str) -> dict[str, Any]:
    """
    Obtiene el enlace CDN directo de streaming de audio para un vídeo de YouTube.
    Formato prioritario: audio m4a/aac o opus de alta velocidad sin descargar el archivo.
    """
    clean_id = video_id.replace("youtube:", "").strip()
    if not clean_id:
        raise ValueError("ID de vídeo de YouTube no válido.")

    url = f"https://www.youtube.com/watch?v={clean_id}"

    ydl_opts: Any = {
        "format": "bestaudio[ext=m4a]/bestaudio/best",
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "socket_timeout": 15,
        "nocheckcertificate": True,
        "http_headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
            "Accept-Language": "es-ES,es;q=0.9,en;q=0.8",
        },
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:  # type: ignore
            info = ydl.extract_info(url, download=False)
    except Exception as e:
        raise RuntimeError(f"Error al resolver flujo de audio en YouTube: {str(e)}")

    if not info or not info.get("url"):
        raise ValueError("No se pudo obtener la URL de streaming para este vídeo.")

    return {
        "success": True,
        "video_id": clean_id,
        "stream_url": info["url"],
        "title": info.get("title", ""),
        "duration": info.get("duration", 0),
        "format": info.get("format", "audio"),
    }
