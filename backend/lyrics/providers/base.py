# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
base.py — Interfaz Base Abstracta para Proveedores de Letras
"""

from abc import ABC, abstractmethod
from ..models import LyricData


class LyricsProvider(ABC):
    name: str = "base"

    @abstractmethod
    def search(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        """
        Busca la letra de una canción en el proveedor.
        
        Devuelve:
          - LyricData con is_synced=True si encontró letra sincronizada (Nivel 1).
          - LyricData con is_synced=False si encontró letra en texto plano (Nivel 2).
          - None si no se encontró resultado o hubo fallo de red.
        """
        pass
