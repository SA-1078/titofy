# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
Paquete backend/whisper_engine — Motor de Transcripción y Sincronización de IA
"""

from .loader import load_whisper_model, is_model_downloaded, detect_device, setup_cuda_dlls, validate_audio_file
from .formatter import to_lrc_timestamp, clean_text, estimate_transcription_quality, split_long_segment
from .transcribe import transcribe_audio
from .align import align_lyrics

__all__ = [
    "load_whisper_model",
    "is_model_downloaded",
    "detect_device",
    "setup_cuda_dlls",
    "validate_audio_file",
    "to_lrc_timestamp",
    "clean_text",
    "estimate_transcription_quality",
    "split_long_segment",
    "transcribe_audio",
    "align_lyrics",
]
