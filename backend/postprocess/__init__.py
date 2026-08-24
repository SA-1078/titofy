# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
Paquete backend/postprocess — Limpiador Inteligente de Letras y Alucinaciones
"""

from .cleaner import postprocess_segments, parse_lrc_file, segments_to_lrc
from .hallucination import is_hallucination, is_too_short
from .normalizer import normalize_text, clean_intra_repetition, normalize_music_tags, merge_short_lines

__all__ = [
    "postprocess_segments",
    "parse_lrc_file",
    "segments_to_lrc",
    "is_hallucination",
    "is_too_short",
    "normalize_text",
    "clean_intra_repetition",
    "normalize_music_tags",
    "merge_short_lines",
]
