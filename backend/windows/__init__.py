# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/windows — Titofy
Módulo exclusivo para Windows: ciclo de vida, watchdog Win32, gestión de DLLs
y blindaje de faster-whisper contra incompatibilidades de kwargs.
"""

import os
import sys

from .whisper_patch import patch_whisper_vad
from .process import start_parent_watchdog, free_port
from .dll_setup import setup_windows_dlls


def setup_windows_runtime(backend_dir: str | None = None) -> None:
    """Configura el entorno de ejecución en Windows (UTF-8, DLLs y parches)."""
    if os.name != "nt":
        return

    # Forzar UTF-8 en streams estándar para evitar UnicodeEncodeError en Windows
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if hasattr(sys.stderr, "reconfigure"):
        try:
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    # Configurar directorios de DLLs
    setup_windows_dlls(backend_dir)

    # Aplicar parche a faster-whisper en memoria
    patch_whisper_vad()


__all__ = [
    "setup_windows_runtime",
    "patch_whisper_vad",
    "start_parent_watchdog",
    "free_port",
    "setup_windows_dlls",
]
