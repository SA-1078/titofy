# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
lrclib.py — Proveedor de Letras para LRCLIB (https://lrclib.net)
Servicio libre y gratuito con letras sincronizadas y en texto plano.
"""

import json
import urllib.parse
import urllib.request
import urllib.error
from typing import Any

from .base import LyricsProvider
from ..models import LyricData, LyricSource
from ..normalizer import clean_query, normalize_for_match, round_duration, generate_search_variations

try:
    from rapidfuzz import fuzz
    HAS_RAPIDFUZZ = True
except ImportError:
    HAS_RAPIDFUZZ = False

try:
    from logger import get_logger
    log = get_logger("lyrics.lrclib")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.lrclib")


class LrclibProvider(LyricsProvider):
    name: str = "lrclib"
    BASE_URL: str = "https://lrclib.net/api"
    TIMEOUT_SECONDS: int = 5
    USER_AGENT: str = "Titofy/2.0 (https://github.com/titofy/titofy)"

    def search(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        """
        Busca letras en LRCLIB probando combinaciones inteligentes de artistas y título:
        1. /get exacto por cada permutación de artista/colaborador.
        2. Fallback a /search con matching difuso y tolerancia de duración.
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

            # Paso 1: Intentar /api/get exacto
            if v_artist:
                exact_result = self._fetch_get(v_artist, v_title, rounded_dur)
                if exact_result is not None:
                    log.info(f"LRCLIB /get hit directo para '{v_artist}' - '{v_title}'")
                    return self._parse_record(exact_result, clean_title, clean_artist or v_artist, rounded_dur)

            # Paso 2: Fallback a /api/search
            search_result = self._fetch_search(v_artist, v_title, rounded_dur, query_text=v_query)
            if search_result is not None:
                log.info(f"LRCLIB /search hit para query '{v_query}'")
                return self._parse_record(search_result, clean_title, clean_artist or v_artist, rounded_dur)

        return None

    def _make_request(self, endpoint: str, params: dict[str, Any]) -> Any | None:
        """Realiza una petición HTTP GET segura a la API de LRCLIB."""
        filtered_params = {k: v for k, v in params.items() if v is not None and v != ""}
        query_string = urllib.parse.urlencode(filtered_params)
        url = f"{self.BASE_URL}/{endpoint}?{query_string}"

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
                    raw_data = response.read().decode("utf-8")
                    return json.loads(raw_data)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                # 404 es esperado cuando una canción no está en la base de datos
                return None
            log.warning(f"Error HTTP {e.code} en LRCLIB ({endpoint}): {e.reason}")
        except urllib.error.URLError as e:
            log.warning(f"Fallo de conexión con LRCLIB ({endpoint}): {e.reason}")
        except TimeoutError:
            log.warning(f"Timeout ({self.TIMEOUT_SECONDS}s) al consultar LRCLIB")
        except Exception as e:
            log.warning(f"Error inesperado al consultar LRCLIB: {e}")

        return None

    def _fetch_get(self, artist: str, title: str, duration: int | None) -> dict[str, Any] | None:
        params: dict[str, Any] = {
            "track_name": title,
        }
        if artist:
            params["artist_name"] = artist
        if duration:
            params["duration"] = duration

        res = self._make_request("get", params)
        if isinstance(res, dict) and (res.get("syncedLyrics") or res.get("plainLyrics")):
            return res
        return None

    def _fetch_search(self, artist: str, title: str, duration: int | None, query_text: str | None = None) -> dict[str, Any] | None:
        params: dict[str, Any] = {
            "track_name": title,
        }
        if artist:
            params["artist_name"] = artist

        results = self._make_request("search", params)
        if not results or not isinstance(results, list):
            # Probar búsqueda difusa general con q
            q = query_text or f"{artist} {title}".strip()
            results = self._make_request("search", {"q": q})

        if not results or not isinstance(results, list):
            return None

        # Filtrar y ordenar candidatos por relevancia y tolerancia de duración
        best_candidate = None
        best_score = -1.0

        target_title_norm = normalize_for_match(title)
        target_artist_norm = normalize_for_match(artist) if artist else ""

        for candidate in results:
            if not isinstance(candidate, dict):
                continue

            # Descartar si no tiene ninguna letra
            has_synced = bool(candidate.get("syncedLyrics"))
            has_plain = bool(candidate.get("plainLyrics"))
            if not has_synced and not has_plain:
                continue

            c_title = candidate.get("trackName") or candidate.get("name") or ""
            c_artist = candidate.get("artistName") or ""
            c_duration = candidate.get("duration")

            c_title_norm = normalize_for_match(c_title)
            c_artist_norm = normalize_for_match(c_artist)

            # 1. Similitud de texto inteligente (soporta títulos largos con nombres de colaboradores)
            if HAS_RAPIDFUZZ:
                title_sim = max(
                    fuzz.ratio(target_title_norm, c_title_norm),
                    fuzz.token_set_ratio(target_title_norm, c_title_norm),
                    fuzz.partial_ratio(target_title_norm, c_title_norm),
                )
                artist_sim = max(
                    fuzz.ratio(target_artist_norm, c_artist_norm),
                    fuzz.token_set_ratio(target_artist_norm, c_artist_norm),
                ) if target_artist_norm else 100.0
                text_score = (title_sim * 0.6) + (artist_sim * 0.4)
            else:
                title_match = target_title_norm in c_title_norm or c_title_norm in target_title_norm
                artist_match = (target_artist_norm in c_artist_norm or c_artist_norm in target_artist_norm) if target_artist_norm else True
                text_score = 90.0 if (title_match and artist_match) else (60.0 if title_match else 0.0)

            if text_score < 55.0:
                continue

            # 2. Tolerancia y penalización por duración
            dur_score = 100.0
            if duration and c_duration:
                diff = abs(float(c_duration) - float(duration))
                if diff <= 3:
                    dur_score = 100.0
                elif diff <= 8:
                    dur_score = 80.0
                elif diff <= 18:
                    dur_score = 50.0
                else:
                    dur_score = 20.0

            # 3. Bonus si tiene letras sincronizadas
            bonus = 20.0 if has_synced else 0.0

            total_score = (text_score * 0.6) + (dur_score * 0.3) + bonus

            if total_score > best_score:
                best_score = total_score
                best_candidate = candidate

        if best_candidate and best_score >= 65.0:
            log.info(
                f"Mejor candidato LRCLIB seleccionado: '{best_candidate.get('artistName')}' - "
                f"'{best_candidate.get('trackName')}' (score={best_score:.1f})"
            )
            return best_candidate

        return None

    def _parse_record(
        self,
        record: dict[str, Any],
        fallback_title: str,
        fallback_artist: str,
        fallback_duration: int | None,
    ) -> LyricData:
        synced_lyrics = record.get("syncedLyrics")
        plain_lyrics = record.get("plainLyrics")

        title = record.get("trackName") or record.get("name") or fallback_title
        artist = record.get("artistName") or fallback_artist
        album = record.get("albumName")
        duration = round_duration(record.get("duration")) or fallback_duration

        if synced_lyrics and synced_lyrics.strip():
            # Nivel 1: Sincronizada online
            lyric_data = LyricData.from_lrc_string(
                lrc_text=synced_lyrics,
                title=title,
                artist=artist,
                duration=duration,
                source=LyricSource.ONLINE_SYNCED,
                album=album,
                provider=self.name,
            )
            lyric_data.plain_lyrics = plain_lyrics or lyric_data.get_plain_text()
            return lyric_data

        # Nivel 2: Solo texto plano disponible (para Forced Alignment)
        lines = []
        if plain_lyrics:
            for l in plain_lyrics.splitlines():
                l_strip = l.strip()
                if l_strip:
                    lines.append(LyricData(text=l_strip, start=None))  # type: ignore

        from ..models import LyricLine
        real_lines = [LyricLine(text=l.strip(), start=None) for l in (plain_lyrics or "").splitlines() if l.strip()]

        return LyricData(
            title=title,
            artist=artist,
            duration=duration,
            source=LyricSource.ONLINE_ALIGNED,
            lines=real_lines,
            plain_lyrics=plain_lyrics,
            album=album,
            provider=self.name,
        )
