# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/windows/whisper_patch.py — Titofy
Módulo exclusivo de Windows para blindar faster-whisper contra incompatibilidades de kwargs.
"""

from typing import Any
from logger import get_logger

log = get_logger("windows.whisper_patch")


def patch_whisper_vad(wm_class: Any = None) -> bool:
    """
    Parchea faster_whisper.WhisperModel.transcribe para aceptar 'vad'
    y mapearlo a 'vad_filter: bool' de manera segura sin lanzar TypeError.
    """
    try:
        if wm_class is None:
            import faster_whisper
            wm_class = getattr(faster_whisper, "WhisperModel", None)

        if wm_class is None:
            return False

        if getattr(wm_class, "_titofy_vad_patched", False):
            return True

        orig_transcribe = wm_class.transcribe

        def _safe_transcribe(self: Any, *args: Any, **kwargs: Any) -> Any:
            if "vad" in kwargs:
                v = kwargs.pop("vad")
                if "vad_filter" not in kwargs:
                    kwargs["vad_filter"] = bool(v)
            return orig_transcribe(self, *args, **kwargs)

        wm_class.transcribe = _safe_transcribe
        wm_class._titofy_vad_patched = True
        log.info("Parche vad aplicado exitosamente a faster_whisper.WhisperModel en Windows")
        return True
    except Exception as e:
        log.warning(f"No se pudo aplicar el parche vad en faster_whisper: {e}")
        return False
