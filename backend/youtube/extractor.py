# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/youtube/extractor.py — Extractor de metadatos de YouTube y YouTube Music para Titofy.
Utiliza yt-dlp con extract_flat=True para una extracción rápida de playlists y vídeos
sin descargar audio ni saturar el ancho de banda.
"""

from __future__ import annotations

import urllib.parse
from typing import Any, Tuple
import yt_dlp  # type: ignore

try:
    from lyrics.normalizer import clean_query, extract_artist_title_from_filename
except ImportError:
    import sys
    import os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from lyrics.normalizer import clean_query, extract_artist_title_from_filename

try:
    from logger import get_logger
    log = get_logger("youtube.extractor")
except ImportError:
    import logging
    log = logging.getLogger("youtube.extractor")


def normalize_yt_url(raw_url: str) -> Tuple[str, str, str]:
    """
    Normaliza cualquier variante de URL de YouTube o YouTube Music.
    Retorna una tupla: (kind, canonical_id, canonical_url)
    donde kind puede ser 'playlist', 'video' o 'unknown'.
    """
    if not raw_url or not isinstance(raw_url, str):
        return "unknown", "", ""

    url_str = raw_url.strip()
    if not (url_str.startswith("http://") or url_str.startswith("https://")):
        url_str = "https://" + url_str

    try:
        parsed = urllib.parse.urlparse(url_str)
    except Exception:
        return "unknown", "", raw_url

    netloc = parsed.netloc.lower()
    # Permitir youtube.com, music.youtube.com, m.youtube.com, youtu.be
    valid_domains = (
        "youtube.com",
        "www.youtube.com",
        "music.youtube.com",
        "m.youtube.com",
        "youtu.be",
        "www.youtu.be",
    )
    if not any(netloc == d or netloc.endswith("." + d) for d in ("youtube.com", "youtu.be")):
        return "unknown", "", raw_url

    query = urllib.parse.parse_qs(parsed.query)

    # 1. Prioridad: Lista de reproducción (parámetro list=...)
    if "list" in query and query["list"]:
        list_id = query["list"][0].strip()
        if list_id:
            return "playlist", list_id, f"https://www.youtube.com/playlist?list={list_id}"

    # 2. Vídeo de YouTube estándar (watch?v=...)
    if "v" in query and query["v"]:
        video_id = query["v"][0].strip()
        if video_id:
            return "video", video_id, f"https://www.youtube.com/watch?v={video_id}"

    # 3. Enlace corto youtu.be/VIDEO_ID
    if "youtu.be" in netloc:
        path_parts = [p for p in parsed.path.split("/") if p]
        if path_parts:
            video_id = path_parts[0].strip()
            if video_id:
                return "video", video_id, f"https://www.youtube.com/watch?v={video_id}"

    # 4. Ruta /playlist o /watch directa
    path_parts = [p for p in parsed.path.split("/") if p]
    if len(path_parts) >= 2 and path_parts[0] in ("shorts", "embed", "v"):
        video_id = path_parts[1].strip()
        if video_id:
            return "video", video_id, f"https://www.youtube.com/watch?v={video_id}"

    return "unknown", "", raw_url


def _clean_track_entry(entry: Any, default_album: str = "") -> dict[str, Any] | None:
    """Procesa una entrada de vídeo y extrae metadatos normalizados."""
    if not entry or not isinstance(entry, dict):
        return None

    video_id = entry.get("id")
    if not video_id:
        return None

    raw_title = entry.get("title") or ""
    # Omitir vídeos privados o eliminados
    if not raw_title or raw_title.startswith("[Private video]") or raw_title.startswith("[Deleted video]"):
        return None

    # Normalizar artista y título
    raw_artist = entry.get("artist") or entry.get("uploader") or entry.get("channel") or ""
    artist, title = extract_artist_title_from_filename(raw_title)

    if not artist or artist.strip().lower() in ("desconocido", "unknown"):
        artist = raw_artist.strip() or "Artista desconocido"

    if not title:
        title = clean_query(raw_title) or raw_title

    # Duración
    duration_sec = entry.get("duration")
    try:
        duration_ms = int(float(duration_sec) * 1000) if duration_sec is not None else 0
    except (ValueError, TypeError):
        duration_ms = 0

    # Portada / Thumbnail
    thumbnails = entry.get("thumbnails")
    thumb_url = None
    if isinstance(thumbnails, list) and thumbnails:
        # Seleccionar la mejor calidad disponible
        thumb_url = thumbnails[-1].get("url")
    elif entry.get("thumbnail"):
        thumb_url = entry.get("thumbnail")

    canonical_path = f"youtube:{video_id}"
    web_url = f"https://www.youtube.com/watch?v={video_id}"

    return {
        "id": video_id,
        "path": canonical_path,
        "title": title,
        "artist": artist,
        "album": default_album or "YouTube",
        "duration_ms": duration_ms,
        "thumbnail": thumb_url,
        "url": web_url,
    }


def _fetch_oembed(video_id: str) -> dict[str, Any] | None:
    """Fallback instantáneo y confiable usando el endpoint oficial oEmbed de YouTube."""
    try:
        import urllib.request
        import json
        oembed_url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={video_id}&format=json"
        req = urllib.request.Request(
            oembed_url,
            headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
            },
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                raw_title = data.get("title") or f"YouTube {video_id}"
                author_name = data.get("author_name") or "YouTube"
                artist, title = extract_artist_title_from_filename(raw_title)
                if not artist or artist.strip().lower() in ("desconocido", "unknown"):
                    artist = author_name
                if not title:
                    title = clean_query(raw_title) or raw_title
                thumb = data.get("thumbnail_url") or f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"
                return {
                    "id": video_id,
                    "path": f"youtube:{video_id}",
                    "title": title,
                    "artist": artist,
                    "album": "YouTube",
                    "duration_ms": 0,
                    "thumbnail": thumb,
                    "url": f"https://www.youtube.com/watch?v={video_id}",
                }
    except Exception as e:
        log.warning(f"[YouTube oEmbed Fallback] Error en oEmbed para {video_id}: {e}")
    return None


def extract_youtube_metadata(raw_url: str) -> dict[str, Any]:
    """
    Extrae los metadatos de una playlist o vídeo de YouTube / YouTube Music.
    No descarga audio ni satura el ancho de banda.
    """
    kind, canonical_id, canonical_url = normalize_yt_url(raw_url)
    if kind == "unknown" or not canonical_id:
        raise ValueError(
            "La URL proporcionada no es un enlace válido de YouTube o YouTube Music."
        )

    # Para listas usamos 'in_playlist' para agilizar. Para vídeos individuales debe ser False
    is_playlist = (kind == "playlist")
    ydl_opts: Any = {
        "extract_flat": "in_playlist" if is_playlist else False,
        "skip_download": True,
        "quiet": True,
        "no_warnings": True,
        "socket_timeout": 15,
        "nocheckcertificate": True,
        "http_headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
            "Accept-Language": "es-ES,es;q=0.9,en;q=0.8",
        },
    }

    info = None
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:  # type: ignore
            info = ydl.extract_info(canonical_url, download=False)
    except Exception as e:
        log.warning(f"[YouTube Extractor] yt-dlp error al conectar con YouTube para '{canonical_url}': {e}")

    # Fallback inmediato con oEmbed para vídeos individuales si yt-dlp falló o fue bloqueado
    if not info and not is_playlist:
        log.info(f"[YouTube Extractor] Ejecutando fallback oEmbed para {canonical_id}...")
        oembed_track = _fetch_oembed(canonical_id)
        if oembed_track is not None:
            return {
                "success": True,
                "kind": "video",
                "canonical_id": canonical_id,
                "canonical_url": canonical_url,
                "title": oembed_track["title"],
                "author": oembed_track["artist"],
                "thumbnail": oembed_track["thumbnail"],
                "total_tracks": 1,
                "tracks": [oembed_track],
            }

    if not info:
        raise ValueError("No se pudieron obtener datos del enlace especificado.")

    tracks = []
    # Caso 1: Playlist
    if "entries" in info:
        playlist_title = info.get("title") or "Playlist de YouTube"
        author = info.get("uploader") or info.get("channel") or "YouTube"
        thumbnail = None
        if info.get("thumbnails") and isinstance(info["thumbnails"], list):
            thumbnail = info["thumbnails"][-1].get("url")

        entries = info.get("entries") or []
        for entry in entries:
            cleaned = _clean_track_entry(entry, default_album=playlist_title)
            if cleaned is not None:
                tracks.append(cleaned)

        return {
            "success": True,
            "kind": "playlist",
            "canonical_id": canonical_id,
            "canonical_url": canonical_url,
            "title": playlist_title,
            "author": author,
            "thumbnail": thumbnail,
            "total_tracks": len(tracks),
            "tracks": tracks,
        }

    # Caso 2: Vídeo individual
    cleaned_single = _clean_track_entry(info)
    if cleaned_single is None:
        oembed_track = _fetch_oembed(canonical_id)
        if oembed_track is not None:
            return {
                "success": True,
                "kind": "video",
                "canonical_id": canonical_id,
                "canonical_url": canonical_url,
                "title": oembed_track["title"],
                "author": oembed_track["artist"],
                "thumbnail": oembed_track["thumbnail"],
                "total_tracks": 1,
                "tracks": [oembed_track],
            }
        raise ValueError("El vídeo no contiene metadatos accesibles o es privado.")

    return {
        "success": True,
        "kind": "video",
        "canonical_id": canonical_id,
        "canonical_url": canonical_url,
        "title": cleaned_single["title"],
        "author": cleaned_single["artist"],
        "thumbnail": cleaned_single["thumbnail"],
        "total_tracks": 1,
        "tracks": [cleaned_single],
    }


# Re-exportar funcionalidades especializadas de streaming y descarga
try:
    from .stream import get_youtube_audio_stream_url
    from .downloader import download_youtube_audio_track
except ImportError:
    from youtube.stream import get_youtube_audio_stream_url
    from youtube.downloader import download_youtube_audio_track


