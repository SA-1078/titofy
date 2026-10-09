# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
lyrist.py — Proveedor de Letras para Lyrist REST API (https://github.com/asrvd/lyrist)
API REST abierta y gratuita para buscar letras por título y artista.
Sirve como alternativa online para texto plano, activando Forced Alignment (Nivel 2).
"""

import json
import urllib.parse
import urllib.request
import urllib.error

from .base import LyricsProvider
from ..models import LyricData, LyricLine, LyricSource
from ..normalizer import clean_query, generate_search_variations, is_artist_compatible, is_lyrics_script_compatible

try:
    from logger import get_logger
    log = get_logger("lyrics.lyrist")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.lyrist")


class LyristProvider(LyricsProvider):
    name: str = "Fuente 3"
    BASE_URL: str = "https://lyrist.vercel.app/api"
    TIMEOUT_SECONDS: int = 5
    USER_AGENT: str = "Titofy/2.0 (https://github.com/titofy/titofy)"

    def search(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        """
        Consulta la API de Lyrist con combinaciones de título y artista.
        Endpoints soportados:
          1. /api/:title/:artist
          2. /api/:title (solo si coincide el artista de la respuesta)
        """
        clean_title = clean_query(title)
        if not clean_title:
            return None

        variations = generate_search_variations(artist, title)

        for var in variations:
            v_artist = var["artist"]
            v_title = var["title"]

            # 1. Probar ruta /api/:title/:artist si hay artista
            if v_artist:
                url = f"{self.BASE_URL}/{urllib.parse.quote(v_title)}/{urllib.parse.quote(v_artist)}"
                res = self._fetch_url(url)
                if res:
                    lyric_data = self._parse_response(res, v_title, v_artist)
                    if lyric_data:
                        log.info(f"[Fuente 3 / Lyrist] Hit confirmado: '{v_artist}' - '{v_title}'")
                        return lyric_data

            # 2. Probar ruta /api/:title solo (con verificación estricta de artista)
            if not v_artist:
                url_title_only = f"{self.BASE_URL}/{urllib.parse.quote(v_title)}"
                res_title = self._fetch_url(url_title_only)
                if res_title:
                    lyric_data = self._parse_response(res_title, v_title, "")
                    if lyric_data:
                        log.info(f"[Fuente 3 / Lyrist] Hit para título: '{v_title}'")
                        return lyric_data

        return None

    def _fetch_url(self, url: str) -> dict | None:
        try:
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": self.USER_AGENT,
                    "Accept": "application/json",
                },
            )
            with urllib.request.urlopen(req, timeout=self.TIMEOUT_SECONDS) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode("utf-8", errors="replace"))
                    if isinstance(data, dict) and not data.get("error"):
                        return data
        except urllib.error.HTTPError as e:
            if e.code not in (404, 503):
                log.debug(f"[Fuente 3 / Lyrist] HTTP {e.code} para {url}")
        except Exception as e:
            log.debug(f"[Fuente 3 / Lyrist] Error de conexión ({url}): {e}")
        return None

    def _parse_response(self, data: dict, fallback_title: str, fallback_artist: str) -> LyricData | None:
        lyrics_text = (data.get("lyrics") or "").strip()
        if not lyrics_text:
            return None

        # Verificar compatibilidad de alfabeto e idioma
        if not is_lyrics_script_compatible(f"{fallback_artist} {fallback_title}", lyrics_text):
            return None

        resp_artist = data.get("artist") or ""
        if fallback_artist and not is_artist_compatible(fallback_artist, resp_artist):
            return None

        lines_raw = lyrics_text.splitlines()
        lyric_lines: list[LyricLine] = []
        for line in lines_raw:
            cleaned = line.strip()
            if cleaned:
                lyric_lines.append(LyricLine(text=cleaned, start=None))

        if not lyric_lines:
            return None

        title = data.get("title") or fallback_title
        artist = resp_artist or fallback_artist

        return LyricData(
            title=title,
            artist=artist,
            source=LyricSource.ONLINE_ALIGNED,
            lines=lyric_lines,
            plain_lyrics=lyrics_text,
            provider="Fuente 3",
        )
