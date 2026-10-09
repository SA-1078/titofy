# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
fingerprint.py — Paso 0: Identificación de Metadatos y Huella Acústica (AcoustID / Chromaprint / ffprobe)

Permite rescatar el título y artista correctos cuando el archivo local tiene
nombres genéricos (ej. 'Track01.mp3', 'Audio_01.mp4') antes de disparar la búsqueda online.
"""

import os
import json
import subprocess
import urllib.request
import urllib.parse
from typing import Any

try:
    from logger import get_logger
    log = get_logger("lyrics.fingerprint")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.fingerprint")


# Clave pública de cliente AcoustID para proyectos open-source (utilizada por Picard / AcoustID)
ACOUSTID_CLIENT_KEY = "8XaBELgH"
ACOUSTID_API_URL = "https://api.acoustid.org/v2/lookup"


def extract_metadata_via_ffprobe(audio_path: str) -> tuple[str | None, str | None, int | None]:
    """
    Paso 0A (Ultra-rápido y 100% offline):
    Inspecciona las etiquetas ID3 / Vorbis / MP4 nativas del archivo de audio con ffprobe.
    Retorna (artist, title, duration_seconds) o None en cada campo si no existen.
    """
    if not audio_path or not os.path.exists(audio_path):
        return (None, None, None)

    try:
        cmd = [
            "ffprobe",
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            audio_path,
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=4, text=True)
        if res.returncode != 0 or not res.stdout:
            return (None, None, None)

        data = json.loads(res.stdout)
        fmt = data.get("format", {})
        tags = fmt.get("tags", {})

        # Tags pueden venir en mayúsculas o minúsculas dependiendo del formato
        lower_tags = {k.lower(): v for k, v in tags.items()}

        raw_artist = lower_tags.get("artist") or lower_tags.get("album_artist") or lower_tags.get("performer")
        raw_title = lower_tags.get("title") or lower_tags.get("track")
        raw_duration = fmt.get("duration")

        duration_sec = None
        if raw_duration:
            try:
                duration_sec = round(float(raw_duration))
            except (ValueError, TypeError):
                duration_sec = None

        artist = raw_artist.strip() if raw_artist and str(raw_artist).strip() else None
        title = raw_title.strip() if raw_title and str(raw_title).strip() else None

        if artist or title:
            log.info(f"[Paso 0: ffprobe] Metadatos encontrados en tags de audio: '{artist}' - '{title}' ({duration_sec}s)")
            return (artist, title, duration_sec)

    except Exception as e:
        log.debug(f"[Paso 0: ffprobe] No se pudieron leer tags con ffprobe: {e}")

    return (None, None, None)


def generate_chromaprint_fingerprint(audio_path: str, max_duration: int = 25) -> tuple[str | None, int | None]:
    """
    Genera la huella acústica Chromaprint usando el binario 'fpcalc'.
    Si 'fpcalc' no está instalado en el sistema, retorna (None, None) pacíficamente.
    """
    if not audio_path or not os.path.exists(audio_path):
        return (None, None)

    try:
        cmd = ["fpcalc", "-json", "-length", str(max_duration), audio_path]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=6, text=True)
        if res.returncode == 0 and res.stdout:
            data = json.loads(res.stdout)
            fingerprint = data.get("fingerprint")
            duration = round(float(data.get("duration", 0)))
            if fingerprint and duration > 0:
                log.info(f"[Paso 0: Chromaprint] Huella acústica generada ({duration}s)")
                return (fingerprint, duration)
    except FileNotFoundError:
        log.debug("[Paso 0: Chromaprint] 'fpcalc' no está instalado en el sistema. Omitiendo huella acústica.")
    except Exception as e:
        log.debug(f"[Paso 0: Chromaprint] Error ejecutando fpcalc: {e}")

    return (None, None)


def lookup_acoustid(fingerprint: str, duration: int) -> tuple[str | None, str | None]:
    """
    Paso 0B (Huella Acústica Online):
    Consulta la base de datos de MusicBrainz / AcoustID para resolver el título y artista exactos.
    """
    if not fingerprint or duration <= 0:
        return (None, None)

    try:
        params = {
            "client": ACOUSTID_CLIENT_KEY,
            "meta": "recordings+releasegroups",
            "duration": str(duration),
            "fingerprint": fingerprint,
        }
        url = f"{ACOUSTID_API_URL}?{urllib.parse.urlencode(params)}"
        req = urllib.request.Request(url, headers={"User-Agent": "Titofy/2.0 (AudioFingerprint)"})

        with urllib.request.urlopen(req, timeout=4) as response:
            if response.status == 200:
                data = json.loads(response.read().decode("utf-8"))
                results = data.get("results", [])
                for item in results:
                    recordings = item.get("recordings", [])
                    if recordings:
                        rec = recordings[0]
                        title = rec.get("title")
                        artists = rec.get("artists", [])
                        artist_name = artists[0].get("name") if artists else None
                        if title and artist_name:
                            log.info(f"[Paso 0: AcoustID] Coincidencia acústica hallada: '{artist_name}' - '{title}'")
                            return (artist_name, title)
    except Exception as e:
        log.debug(f"[Paso 0: AcoustID] No se pudo consultar AcoustID: {e}")

    return (None, None)


def identify_audio(audio_path: str | None) -> tuple[str | None, str | None, int | None]:
    """
    Función orquestadora del Paso 0:
    1. Lee etiquetas de metadatos embebidas vía ffprobe (offline, instantáneo).
    2. Si falló, genera huella acústica con fpcalc y consulta AcoustID.
    Retorna (artist, title, duration).
    """
    if not audio_path or not os.path.exists(audio_path):
        return (None, None, None)

    # 1. Intentar ffprobe tags embebidos
    f_artist, f_title, f_dur = extract_metadata_via_ffprobe(audio_path)
    if f_artist and f_title:
        return (f_artist, f_title, f_dur)

    # 2. Intentar huella acústica con fpcalc + AcoustID si aún no tenemos artista o título
    fp, fp_dur = generate_chromaprint_fingerprint(audio_path)
    if fp and fp_dur:
        a_artist, a_title = lookup_acoustid(fp, fp_dur)
        if a_artist or a_title:
            return (a_artist or f_artist, a_title or f_title, f_dur or fp_dur)

    return (f_artist, f_title, f_dur)
