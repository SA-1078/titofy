# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
lyrics.providers — Proveedores de Letras Online
"""

from .base import LyricsProvider
from .lrclib import LrclibProvider
from .lyrics_ovh import LyricsOvhProvider

__all__ = ["LyricsProvider", "LrclibProvider", "LyricsOvhProvider"]
