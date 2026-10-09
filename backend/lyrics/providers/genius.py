# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
genius.py — Proveedor de Letras para Genius (Scraping no comercial / API pública de búsqueda)
Permite buscar letras en la base de datos de Genius sin necesidad de clave de pago.
Sirve como alternativa online para texto plano, activando Forced Alignment (Nivel 2).
"""

import html
import json
import re
import urllib.parse
import urllib.request
import urllib.error

from .base import LyricsProvider
from ..models import LyricData, LyricLine, LyricSource
from ..normalizer import clean_query, generate_search_variations, is_artist_compatible, is_lyrics_script_compatible

try:
    from logger import get_logger
    log = get_logger("lyrics.genius")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.genius")


class GeniusProvider(LyricsProvider):
    name: str = "Fuente 3"
    SEARCH_URL: str = "https://genius.com/api/search/multi"
    TIMEOUT_SECONDS: int = 6
    USER_AGENT: str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

    def search(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        """
        Busca letras en Genius con validación estricta de artista y compatibilidad de idioma.
        """
        clean_title = clean_query(title)
        if not clean_title:
            return None

        variations = generate_search_variations(artist, title)

        for var in variations:
            v_artist = var["artist"]
            v_title = var["title"]
            query = f"{v_artist} {v_title}".strip()

            song_hit = self._search_song(query, expected_artist=v_artist, expected_title=v_title)

            if song_hit:
                song_url = song_hit.get("url")
                hit_title = song_hit.get("title") or v_title
                hit_artist = song_hit.get("artist") or v_artist

                if song_url:
                    lyrics_text = self._scrape_lyrics(song_url)
                    if lyrics_text and is_lyrics_script_compatible(f"{v_artist} {v_title}", lyrics_text):
                        lines_raw = lyrics_text.splitlines()
                        lyric_lines: list[LyricLine] = []
                        for line in lines_raw:
                            cleaned = line.strip()
                            if not cleaned:
                                continue
                            # Filtrar artefactos típicos de Genius
                            if re.match(r"^\d+\s*Contributors?", cleaned, re.IGNORECASE):
                                continue
                            if re.match(r"^.*Lyrics$", cleaned, re.IGNORECASE):
                                continue
                            if re.match(r"^(?:Embed|\d+Embed|You might also like|Share|Translations.*)$", cleaned, re.IGNORECASE):
                                continue
                            if cleaned.startswith("[") and cleaned.endswith("]"):
                                continue

                            lyric_lines.append(LyricLine(text=cleaned, start=None))

                        if lyric_lines:
                            log.info(f"[Fuente 3 / Genius] Letra válida obtenida para '{hit_artist}' - '{hit_title}' ({len(lyric_lines)} líneas)")
                            return LyricData(
                                title=hit_title,
                                artist=hit_artist,
                                source=LyricSource.ONLINE_ALIGNED,
                                lines=lyric_lines,
                                plain_lyrics="\n".join(l.text for l in lyric_lines),
                                provider="Fuente 3",
                            )

        return None

    def _search_song(self, query: str, expected_artist: str | None = None, expected_title: str | None = None) -> dict | None:
        """Consulta el buscador público de Genius y verifica coincidencia de artista."""
        url = f"{self.SEARCH_URL}?q={urllib.parse.quote(query)}"
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
                    sections = data.get("response", {}).get("sections", [])
                    for section in sections:
                        if section.get("type") == "song":
                            hits = section.get("hits", [])
                            for hit in hits:
                                result = hit.get("result", {})
                                candidate_artist = result.get("primary_artist", {}).get("name", "")
                                candidate_title = result.get("title", "")

                                # Validación estricta: Si se especificó artista, debe ser compatible
                                if expected_artist and not is_artist_compatible(expected_artist, candidate_artist):
                                    continue

                                return {
                                    "url": result.get("url"),
                                    "title": candidate_title,
                                    "artist": candidate_artist,
                                }
        except Exception as e:
            log.debug(f"[Fuente 3 / Genius] Error buscando ({query}): {e}")
        return None

    def _scrape_lyrics(self, page_url: str) -> str | None:
        """Descarga la página de Genius y extrae el contenido de los contenedores de letras."""
        try:
            req = urllib.request.Request(
                page_url,
                headers={
                    "User-Agent": self.USER_AGENT,
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                },
            )
            with urllib.request.urlopen(req, timeout=self.TIMEOUT_SECONDS) as resp:
                if resp.status == 200:
                    html_content = resp.read().decode("utf-8", errors="replace")
                    return self._extract_lyrics_from_html(html_content)
        except Exception as e:
            log.debug(f"[Fuente 3 / Genius] Scraping error ({page_url}): {e}")
        return None

    def _extract_lyrics_from_html(self, raw_html: str) -> str | None:
        """Extrae el texto de las etiquetas div con data-lyrics-container="true" o class="lyrics"."""
        containers = re.findall(r'<div[^>]*data-lyrics-container="true"[^>]*>(.*?)</div>', raw_html, re.DOTALL)
        if not containers:
            containers = re.findall(r'<div[^>]*class="lyrics"[^>]*>(.*?)</div>', raw_html, re.DOTALL)

        if not containers:
            return None

        combined_html = "\n".join(containers)
        text = re.sub(r'<br\s*/?>', '\n', combined_html, flags=re.IGNORECASE)
        text = re.sub(r'<[^>]+>', '', text)
        text = html.unescape(text)

        cleaned_lines = [l.strip() for l in text.splitlines() if l.strip()]
        if cleaned_lines:
            return "\n".join(cleaned_lines)
        return None
