# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
netease.py — Proveedor de Letras Sincronizadas para NetEase Cloud Music (网易云音乐)
Catálogo masivo global con letras sincronizadas (.lrc) milimétricas.
"""

import json
import urllib.parse
import urllib.request
import urllib.error
from typing import Any

from .base import LyricsProvider
from ..models import LyricData, LyricSource
from ..normalizer import clean_query, normalize_for_match, round_duration, generate_search_variations, is_artist_compatible, is_lyrics_script_compatible

try:
    from rapidfuzz import fuzz
    HAS_RAPIDFUZZ = True
except ImportError:
    HAS_RAPIDFUZZ = False

try:
    from logger import get_logger
    log = get_logger("lyrics.netease")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.netease")


class NeteaseProvider(LyricsProvider):
    name: str = "Fuente 2"
    is_synced_provider: bool = True

    CLOUD_SEARCH_URL: str = "https://music.163.com/api/cloudsearch/pc"
    LYRIC_URL: str = "https://music.163.com/api/song/lyric"
    TIMEOUT_SECONDS: int = 5
    HEADERS: dict[str, str] = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": "https://music.163.com/",
        "Cookie": "os=pc",
    }

    def search(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        """
        Busca letras sincronizadas en NetEase Cloud Music.
        1. Prueba con artista y título normalizados.
        2. Selecciona la canción candidata por proximidad de duración y similitud de título.
        3. Descarga la letra sincronizada parseada a LyricData.
        """
        clean_artist = clean_query(artist) if artist else ""
        clean_title = clean_query(title)
        rounded_dur = round_duration(duration)

        if not clean_title:
            return None

        variations = generate_search_variations(artist, title)

        for var in variations:
            q = var["query"]
            if not q:
                continue

            try:
                songs = self._cloud_search(q, limit=5)
            except Exception as e:
                log.debug(f"NetEase error en búsqueda para query '{q}': {e}")
                continue

            if not songs:
                continue

            # Buscar la mejor coincidencia entre los resultados
            best_song = self._pick_best_song(songs, clean_artist, clean_title, rounded_dur)
            if best_song and best_song.get("id") is not None:
                song_id = int(best_song["id"])
                song_name = str(best_song.get("name") or clean_title)
                ar_list = best_song.get("ar", [])
                artist_name = ", ".join([a.get("name", "") for a in ar_list if isinstance(a, dict) and a.get("name")]) or clean_artist

                lyric_data = self._fetch_lyrics(song_id, song_name, artist_name, rounded_dur)
                if lyric_data and lyric_data.is_synced:
                    log.info(f"[NetEase] Letra sincronizada encontrada para '{artist_name}' - '{song_name}' (ID: {song_id})")
                    return lyric_data

        return None

    async def search_async(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        """
        Implementación asíncrona optimizada para consultas concurrentes con httpx si está disponible,
        o delegación a hilo con asyncio.to_thread.
        """
        try:
            import httpx
            return await self._search_async_httpx(artist, title, duration)
        except ImportError:
            import asyncio
            return await asyncio.to_thread(self.search, artist, title, duration)

    async def _search_async_httpx(
        self,
        artist: str | None,
        title: str,
        duration: int | None = None,
    ) -> LyricData | None:
        import httpx

        clean_artist = clean_query(artist) if artist else ""
        clean_title = clean_query(title)
        rounded_dur = round_duration(duration)

        if not clean_title:
            return None

        variations = generate_search_variations(artist, title)

        async with httpx.AsyncClient(timeout=self.TIMEOUT_SECONDS, headers=self.HEADERS) as client:
            for var in variations:
                q = var["query"]
                if not q:
                    continue

                try:
                    params = {"s": q, "type": "1", "offset": "0", "limit": "5"}
                    resp = await client.get(self.CLOUD_SEARCH_URL, params=params)
                    if resp.status_code != 200:
                        continue
                    data = resp.json()
                    songs = data.get("result", {}).get("songs", [])
                except Exception as e:
                    log.debug(f"[NetEase Async] Error buscando '{q}': {e}")
                    continue

                if not songs:
                    continue

                best_song = self._pick_best_song(songs, clean_artist, clean_title, rounded_dur)
                if best_song and best_song.get("id") is not None:
                    song_id = int(best_song["id"])
                    song_name = str(best_song.get("name") or clean_title)
                    ar_list = best_song.get("ar", [])
                    artist_name = ", ".join([a.get("name", "") for a in ar_list if isinstance(a, dict) and a.get("name")]) or clean_artist

                    try:
                        lyric_params = {"os": "pc", "id": str(song_id), "lv": "-1", "kv": "-1", "tv": "-1"}
                        lresp = await client.get(self.LYRIC_URL, params=lyric_params)
                        if lresp.status_code == 200:
                            ldata = lresp.json()
                            lrc_str = ldata.get("lrc", {}).get("lyric", "")
                            if lrc_str and "[" in lrc_str and is_lyrics_script_compatible(f"{artist_name} {song_name}", lrc_str):
                                lyric_data = LyricData.from_lrc_string(
                                    lrc_text=lrc_str,
                                    title=song_name,
                                    artist=artist_name,
                                    duration=rounded_dur,
                                    source=LyricSource.ONLINE_SYNCED,
                                    provider=self.name,
                                )
                                if lyric_data.is_synced:
                                    log.info(f"[Fuente 2 / NetEase] Letra sincronizada encontrada para '{artist_name}' - '{song_name}' (ID: {song_id})")
                                    return lyric_data
                    except Exception as e:
                        log.debug(f"[Fuente 2 / NetEase] Error al obtener letras ID {song_id}: {e}")

        return None

    def _cloud_search(self, query: str, limit: int = 5) -> list[dict[str, Any]]:
        params = urllib.parse.urlencode({
            "s": query,
            "type": 1,
            "offset": 0,
            "limit": limit,
        })
        url = f"{self.CLOUD_SEARCH_URL}?{params}"
        req = urllib.request.Request(url, headers=self.HEADERS)
        with urllib.request.urlopen(req, timeout=self.TIMEOUT_SECONDS) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode("utf-8"))
                return data.get("result", {}).get("songs", [])
        return []

    def _fetch_lyrics(self, song_id: int, title: str, artist: str, duration: int | None) -> LyricData | None:
        params = urllib.parse.urlencode({
            "os": "pc",
            "id": song_id,
            "lv": -1,
            "kv": -1,
            "tv": -1,
        })
        url = f"{self.LYRIC_URL}?{params}"
        req = urllib.request.Request(url, headers=self.HEADERS)
        try:
            with urllib.request.urlopen(req, timeout=self.TIMEOUT_SECONDS) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode("utf-8"))
                    lrc_text = data.get("lrc", {}).get("lyric", "")
                    if lrc_text and "[" in lrc_text and is_lyrics_script_compatible(f"{artist} {title}", lrc_text):
                        return LyricData.from_lrc_string(
                            lrc_text=lrc_text,
                            title=title,
                            artist=artist,
                            duration=duration,
                            source=LyricSource.ONLINE_SYNCED,
                            provider=self.name,
                        )
        except Exception as e:
            log.debug(f"[Fuente 2 / NetEase] Error al obtener letras para ID {song_id}: {e}")
        return None

    def _pick_best_song(
        self,
        songs: list[dict[str, Any]],
        artist: str,
        title: str,
        duration: int | None,
    ) -> dict[str, Any] | None:
        if not songs:
            return None

        norm_title = normalize_for_match(title)
        norm_artist = normalize_for_match(artist)

        best_score = -1.0
        best_song = None

        for song in songs:
            s_name = song.get("name", "")
            s_duration = round(song.get("dt", 0) / 1000.0)
            s_artists = [a.get("name", "") for a in song.get("ar", [])]
            s_artist_combined = " ".join(s_artists)

            s_norm_title = normalize_for_match(s_name)
            s_norm_artist = normalize_for_match(s_artist_combined)

            # Validación estricta de artista si se especificó
            if artist and not is_artist_compatible(artist, s_artist_combined):
                continue

            # Puntuación de título
            if HAS_RAPIDFUZZ:
                title_sim = fuzz.token_sort_ratio(norm_title, s_norm_title)
                artist_sim = fuzz.token_sort_ratio(norm_artist, s_norm_artist) if norm_artist else 80.0
            else:
                title_sim = 100.0 if (norm_title in s_norm_title or s_norm_title in norm_title) else 50.0
                artist_sim = 100.0 if (norm_artist and (norm_artist in s_norm_artist or s_norm_artist in norm_artist)) else 70.0

            if title_sim < 60.0:
                continue

            score = title_sim * 0.6 + artist_sim * 0.4

            # Penalización o bonus por duración
            if duration and s_duration > 0:
                diff = abs(duration - s_duration)
                if diff <= 3:
                    score += 20.0
                elif diff <= 6:
                    score += 10.0
                elif diff > 15:
                    score -= 25.0

            if score > best_score:
                best_score = score
                best_song = song

        # Umbral mínimo de confianza
        if best_score >= 50.0:
            return best_song

        return None
