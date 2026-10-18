# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
config.py — Alias de conveniencia y compatibilidad para lyric_config.
Permite importaciones `from config import get_config` o `import config`.
"""

from lyric_config import DEFAULTS, get_config

__all__ = ["get_config", "DEFAULTS"]
