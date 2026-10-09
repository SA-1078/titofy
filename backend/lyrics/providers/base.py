# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
base.py — Interfaz Base Abstracta para Proveedores de Letras
"""

import asyncio
from abc import ABC, abstractmethod
from ..models import LyricData


class LyricsProvider(ABC):
    name: str = "base"
    is_synced_provider: bool = False  # True si entrega .lrc sincronizado (Nivel 1)

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

    async def search_async(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        """
        Búsqueda asíncrona no bloqueante para concurrencia en FastAPI (asyncio.gather).
        Por defecto ejecuta search() en un hilo de trabajo en el pool de asyncio.
        """
        return await asyncio.to_thread(self.search, artist, title, duration)

