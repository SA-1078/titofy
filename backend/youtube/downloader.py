# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/youtube/downloader.py — Descarga de audio de YouTube / YouTube Music en segundo plano.
Guarda los archivos directamente en la carpeta de música activa de Titofy.
"""

from __future__ import annotations

import os
import re
import shutil
from typing import Any
import yt_dlp  # type: ignore

try:
    from logger import get_logger
    log = get_logger("youtube.downloader")
except ImportError:
    import logging
    log = logging.getLogger("youtube.downloader")


def download_youtube_audio_track(
    video_id: str,
    title: str | None = None,
    artist: str | None = None,
    target_folder: str | None = None,
) -> dict[str, Any]:
    """
    Descarga el audio de un vídeo de YouTube y lo guarda en la carpeta de música local.
    Respeta la carpeta configurada en Ajustes / config.yaml.
    """
    clean_id = video_id.replace("youtube:", "").strip()
    if not clean_id:
        raise ValueError("ID de vídeo de YouTube no válido.")

    url = f"https://www.youtube.com/watch?v={clean_id}"

    # 1. Determinar carpeta destino respetando ajustes
    dest_dir = target_folder
    if not dest_dir or not os.path.exists(dest_dir):
        try:
            from lyric_config import get_config
            cfg = get_config()
            music_folder = cfg.get("paths", {}).get("music_folder")
            if music_folder and os.path.exists(music_folder):
                dest_dir = music_folder
        except Exception:
            pass

    if not dest_dir or not os.path.exists(dest_dir):
        for cand in [os.path.expanduser("~/Música"), os.path.expanduser("~/Music")]:
            if os.path.exists(cand):
                dest_dir = cand
                break

    if not dest_dir or not os.path.exists(dest_dir):
        dest_dir = os.path.expanduser("~/Música")
        os.makedirs(dest_dir, exist_ok=True)

    log.info(f"[YouTube Downloader] Preparando descarga para ID '{clean_id}' en carpeta destino: '{dest_dir}'")

    # 2. Sanitizar nombre de archivo
    safe_name = ""
    if artist and title:
        safe_name = f"{artist} - {title}"
    elif title:
        safe_name = title
    else:
        safe_name = f"youtube_{clean_id}"

    safe_name = re.sub(r'[\\/*?:"<>|]', "", safe_name).strip()
    if not safe_name:
        safe_name = f"youtube_{clean_id}"

    out_template = os.path.join(dest_dir, f"{safe_name}.%(ext)s")

    # 3. Detectar ffmpeg si está disponible
    ffmpeg_bin = shutil.which("ffmpeg")
    if not ffmpeg_bin:
        for cand in ("/usr/bin/ffmpeg", "/usr/local/bin/ffmpeg", "bin/ffmpeg"):
            if os.path.exists(cand):
                ffmpeg_bin = cand
                break

    ydl_opts: dict[str, Any] = {
        "format": "bestaudio[ext=m4a]/bestaudio[ext=mp3]/bestaudio/best",
        "outtmpl": out_template,
        "quiet": False,
        "no_warnings": False,
        "socket_timeout": 30,
        "nocheckcertificate": True,
    }

    if ffmpeg_bin:
        ydl_opts["ffmpeg_location"] = os.path.dirname(ffmpeg_bin)
        ydl_opts["postprocessors"] = [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "m4a",
        }]

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:  # type: ignore
            info = ydl.extract_info(url, download=True)
    except Exception as e:
        log.error(f"[YouTube Downloader] Error al descargar con yt-dlp: {e}")
        raise RuntimeError(f"Error descargando audio de YouTube: {str(e)}")

    # 4. Encontrar la ruta exacta del archivo descargado en dest_dir
    actual_file = None
    if info:
        req_dl = info.get("requested_downloads")
        if req_dl and isinstance(req_dl, list) and len(req_dl) > 0:
            candidate = req_dl[0].get("filepath")
            if candidate and os.path.exists(candidate):
                actual_file = candidate

    if not actual_file:
        for ext in (".m4a", ".mp3", ".opus", ".webm", ".aac"):
            candidate = os.path.join(dest_dir, f"{safe_name}{ext}")
            if os.path.exists(candidate):
                actual_file = candidate
                break

    if not actual_file:
        try:
            entries = [os.path.join(dest_dir, f) for f in os.listdir(dest_dir)]
            matched = [
                f for f in entries
                if os.path.isfile(f) and (safe_name in os.path.basename(f) or clean_id in os.path.basename(f))
            ]
            if matched:
                matched.sort(key=os.path.getmtime, reverse=True)
                actual_file = matched[0]
        except Exception:
            pass

    final_path = actual_file or os.path.join(dest_dir, f"{safe_name}.m4a")
    file_size = os.path.getsize(final_path) if os.path.exists(final_path) else 0

    log.info(f"[YouTube Downloader] Descarga completada con éxito: '{final_path}' ({file_size} bytes)")

    duration_sec = info.get("duration", 0) if info else 0
    duration_ms = int(float(duration_sec) * 1000) if duration_sec else 0

    return {
        "success": True,
        "video_id": clean_id,
        "file_path": final_path,
        "filename": os.path.basename(final_path),
        "target_folder": dest_dir,
        "file_size": file_size,
        "duration_ms": duration_ms,
        "title": title or (info.get("title", "") if info else ""),
        "artist": artist or (info.get("uploader", "") if info else ""),
    }
