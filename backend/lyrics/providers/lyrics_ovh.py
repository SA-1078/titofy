# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
lyrics_ovh.py — Proveedor de Letras para Lyrics.ovh (https://lyrics.ovh)
Servicio público y gratuito de letras en texto plano.
Sirve como respaldo cuando LRCLIB no tiene la canción, activando Forced Alignment (Nivel 2).
"""

import json
import urllib.parse
import urllib.request
import urllib.error
from typing import Any

from .base import LyricsProvider
from ..models import LyricData, LyricLine, LyricSource
from ..normalizer import clean_query, normalize_for_match, round_duration, generate_search_variations, is_artist_compatible, is_lyrics_script_compatible

try:
    from rapidfuzz import fuzz
    HAS_RAPIDFUZZ = True
except ImportError:
    HAS_RAPIDFUZZ = False

try:
    from logger import get_logger
    log = get_logger("lyrics.lyrics_ovh")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.lyrics_ovh")


class LyricsOvhProvider(LyricsProvider):
    name: str = "Fuente 3"
    BASE_URL: str = "https://api.lyrics.ovh"
    TIMEOUT_SECONDS: int = 5
    USER_AGENT: str = "Titofy/2.0 (https://github.com/titofy/titofy)"

    def search(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        """
        Busca letras en texto plano en Lyrics.ovh probando combinaciones inteligentes:
        1. /v1/{artist}/{title} directo por cada combinación de artista.
        2. /suggest/{query} para búsqueda difusa con título y artista.
        """
        clean_artist = clean_query(artist) if artist else ""
        clean_title = clean_query(title)
        rounded_dur = round_duration(duration)

        if not clean_title:
            return None

        variations = generate_search_variations(artist, title)

        for var in variations:
            v_artist = var["artist"]
            v_title = var["title"]
            v_query = var["query"]

            # 1. Búsqueda directa por artista y título
            if v_artist:
                lyrics_text = self._fetch_v1(v_artist, v_title)
                if lyrics_text:
                    log.info(f"Lyrics.ovh hit directo para '{v_artist}' - '{v_title}'")
                    return self._build_lyric_data(clean_title, clean_artist or v_artist, lyrics_text, rounded_dur)

            # 2. Búsqueda por sugerencias /suggest/{query}
            suggested = self._fetch_suggest(v_query, clean_title, clean_artist or v_artist)
            if suggested:
                s_artist = suggested.get("artist", {}).get("name", v_artist)
                s_title = suggested.get("title", clean_title)
                lyrics_text = self._fetch_v1(s_artist, s_title)
                if lyrics_text:
                    log.info(f"Lyrics.ovh hit vía /suggest para '{s_artist}' - '{s_title}'")
                    return self._build_lyric_data(s_title, s_artist, lyrics_text, rounded_dur)

        return None

    def _fetch_v1(self, artist: str, title: str) -> str | None:
        """Consulta /v1/{artist}/{title}."""
        enc_artist = urllib.parse.quote(artist)
        enc_title = urllib.parse.quote(title)
        url = f"{self.BASE_URL}/v1/{enc_artist}/{enc_title}"

        data = self._make_request(url)
        if isinstance(data, dict) and data.get("lyrics"):
            return str(data["lyrics"]).strip()
        return None

    def _fetch_suggest(self, query: str, target_title: str, target_artist: str) -> dict[str, Any] | None:
        """Consulta /suggest/{query} y escoge el mejor resultado."""
        enc_query = urllib.parse.quote(query)
        url = f"{self.BASE_URL}/suggest/{enc_query}"

        data = self._make_request(url)
        if not isinstance(data, dict) or not data.get("data") or not isinstance(data["data"], list):
            return None

        items = data["data"]
        if not items:
            return None

        target_title_norm = normalize_for_match(target_title)
        target_artist_norm = normalize_for_match(target_artist)

        best_item = None
        best_score = -1.0

        for item in items[:6]:
            if not isinstance(item, dict):
                continue
            item_title = item.get("title", "")
            item_artist = item.get("artist", {}).get("name", "")

            it_norm = normalize_for_match(item_title)
            ia_norm = normalize_for_match(item_artist)

            if HAS_RAPIDFUZZ:
                title_sim = max(
                    fuzz.ratio(target_title_norm, it_norm),
                    fuzz.token_set_ratio(target_title_norm, it_norm),
                )
                artist_sim = max(
                    fuzz.ratio(target_artist_norm, ia_norm),
                    fuzz.token_set_ratio(target_artist_norm, ia_norm),
                ) if target_artist_norm else 100.0
                score = (title_sim * 0.6) + (artist_sim * 0.4)
            else:
                score = 80.0 if (target_title_norm in it_norm or it_norm in target_title_norm) else 0.0

            if score > best_score and score >= 60.0:
                best_score = score
                best_item = item

        return best_item

    def _make_request(self, url: str) -> Any | None:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": self.USER_AGENT,
                "Accept": "application/json",
            },
        )

        try:
            with urllib.request.urlopen(req, timeout=self.TIMEOUT_SECONDS) as response:
                if response.status == 200:
                    raw = response.read().decode("utf-8")
                    return json.loads(raw)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            log.debug(f"HTTP {e.code} en Lyrics.ovh: {e.reason}")
        except Exception as e:
            log.debug(f"Error al consultar Lyrics.ovh: {e}")

        return None

    def _build_lyric_data(
        self,
        title: str,
        artist: str,
        plain_lyrics: str,
        duration: int | None,
    ) -> LyricData | None:
        if not is_lyrics_script_compatible(f"{artist} {title}", plain_lyrics):
            return None

        lines = [LyricLine(text=l.strip(), start=None) for l in plain_lyrics.splitlines() if l.strip()]

        return LyricData(
            title=title,
            artist=artist,
            duration=duration,
            source=LyricSource.ONLINE_ALIGNED,
            lines=lines,
            plain_lyrics=plain_lyrics,
            provider="Fuente 3",
        )
