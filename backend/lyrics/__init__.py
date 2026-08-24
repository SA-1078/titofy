# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
lyrics — Motor Híbrido de Letras y Resolución Multi-Fuente
"""

from .models import LyricSource, LyricWord, LyricLine, LyricData
from .normalizer import clean_query, normalize_for_match, extract_artist_title_from_filename
from .resolver import LyricsResolver

__all__ = [
    "LyricSource",
    "LyricWord",
    "LyricLine",
    "LyricData",
    "clean_query",
    "normalize_for_match",
    "extract_artist_title_from_filename",
    "LyricsResolver",
]

