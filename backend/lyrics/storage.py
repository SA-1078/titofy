# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/lyrics/storage.py — Gestión y persistencia de archivos .lrc para Titofy.
Guarda archivos en carpetas de caché (cli/lrc y backend/lrc) evitando contaminar
la biblioteca de música del usuario.
"""

from __future__ import annotations

import os
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .models import LyricData

try:
    from logger import get_logger
    log = get_logger("lyrics.storage")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.storage")


def save_lrc_if_requested(data: LyricData, output_lrc: str | None, audio_path: str | None, force: bool = False) -> None:
    """
    Persiste la letra sincronizada en formato .lrc en las carpetas de caché internas
    y en la ruta solicitada si aplica.
    """
    cli_lrc_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "cli", "lrc"))
    backend_lrc_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "lrc"))

    for d in [cli_lrc_dir, backend_lrc_dir]:
        try:
            os.makedirs(d, exist_ok=True)
        except Exception:
            pass

    if audio_path:
        # Eliminar cualquier archivo .lrc residual en la carpeta de música del usuario
        stray_music_lrc = os.path.splitext(audio_path)[0] + ".lrc"
        if os.path.exists(stray_music_lrc):
            try:
                os.remove(stray_music_lrc)
                log.info(f"Eliminado archivo .lrc residual de la carpeta de música: {stray_music_lrc}")
            except Exception as e:
                log.warning(f"No se pudo eliminar .lrc en carpeta de música: {e}")

        audio_base = os.path.splitext(os.path.basename(audio_path))[0]
        for lrc_dir in [cli_lrc_dir, backend_lrc_dir]:
            target = os.path.join(lrc_dir, f"{audio_base}.lrc")
            if force and os.path.exists(target):
                try:
                    os.remove(target)
                except OSError:
                    pass
            try:
                with open(target, "w", encoding="utf-8") as f:
                    f.write(data.to_lrc())
                log.info(f"Archivo .lrc guardado en: {target}")
            except Exception as e:
                log.warning(f"No se pudo guardar en {target}: {e}")

    # Si se solicitó explícitamente un output_lrc, verificar que NO sea la carpeta de música del usuario
    if output_lrc:
        audio_dir = os.path.abspath(os.path.dirname(audio_path)) if audio_path else ""
        out_dir = os.path.abspath(os.path.dirname(output_lrc))
        if out_dir and out_dir != audio_dir:
            try:
                os.makedirs(out_dir, exist_ok=True)
                if force and os.path.exists(output_lrc):
                    try:
                        os.remove(output_lrc)
                    except OSError:
                        pass
                with open(output_lrc, "w", encoding="utf-8") as f:
                    f.write(data.to_lrc())
                log.info(f"Archivo .lrc guardado en ruta explícita: {output_lrc}")
            except Exception as e:
                log.warning(f"No se pudo guardar en {output_lrc}: {e}")
