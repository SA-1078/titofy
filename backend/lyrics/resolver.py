# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
resolver.py — Orquestador Híbrido Asíncrono de Resolución de Letras
Decide la fuente más económica y confiable para obtener letras sincronizadas:
0. Paso 0: Identificación de metadatos embebidos y huella acústica (ffprobe / AcoustID)
1. Nivel 1: Proveedores online sincronizados en paralelo (LRCLIB + NetEase Cloud Music)
2. Nivel 2: Proveedores online de texto plano en paralelo (Genius + Lyrist) + Forced Alignment local
3. Nivel 3: Transcripción Whisper local offline (faster-whisper)
"""

from __future__ import annotations

import os
import asyncio
from typing import Any

from .models import LyricData, LyricLine, LyricSource
from .normalizer import clean_query, extract_artist_title_from_filename, round_duration, clean_song_metadata
from .fingerprint import identify_audio
from .providers.base import LyricsProvider
from .providers.lrclib import LrclibProvider
from .providers.netease import NeteaseProvider
from .providers.lyrist import LyristProvider
from .providers.genius import GeniusProvider
from .providers.lyrics_ovh import LyricsOvhProvider
from .alignment import calibrate_synced_lyrics, align_plain_lyrics, generate_with_whisper
from .storage import save_lrc_if_requested

try:
    from logger import get_logger
    log = get_logger("lyrics.resolver")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.resolver")


class LyricsResolver:
    def __init__(
        self,
        providers: list[LyricsProvider] | None = None,
    ):
        if providers is not None:
            self.providers = providers
            self.synced_providers = [p for p in providers if getattr(p, "is_synced_provider", False)]
            self.plain_providers = [p for p in providers if not getattr(p, "is_synced_provider", False)]
        else:
            self.synced_providers = [
                LrclibProvider(),
                NeteaseProvider(),
            ]
            self.plain_providers = [
                GeniusProvider(),
                LyristProvider(),
                LyricsOvhProvider(),
            ]
            self.providers = self.synced_providers + self.plain_providers

    async def resolve_async(
        self,
        artist: str | None = None,
        title: str | None = None,
        duration: int | float | None = None,
        audio_path: str | None = None,
        mode: str = "auto",                  # "auto", "offline", "ai_only", "online_only", "hybrid", "online_align"
        model_name: str = "small",
        language: str = "auto",
        output_lrc: str | None = None,
        force: bool = False,
    ) -> LyricData | None:
        """
        Orquestación asíncrona concurrente de resolución de letras.
        """
        dur_int = round_duration(duration)

        # ── PASO 0: Huella Acústica / Metadatos si faltan datos y hay audio local ──
        if audio_path and os.path.exists(audio_path):
            needs_identification = (not artist or not clean_query(artist)) or (not title or not clean_query(title))
            if needs_identification:
                log.info(f"[Paso 0] Analizando archivo de audio '{os.path.basename(audio_path)}'...")
                fp_artist, fp_title, fp_dur = identify_audio(audio_path)
                if fp_artist and not clean_query(artist):
                    artist = fp_artist
                if fp_title and not clean_query(title):
                    title = fp_title
                if fp_dur and not dur_int:
                    dur_int = fp_dur

            if (not artist or not clean_query(artist)) or (not title or not clean_query(title)):
                extracted_artist, extracted_title = extract_artist_title_from_filename(audio_path)
                if not artist or not clean_query(artist):
                    artist = extracted_artist
                if not title or not clean_query(title):
                    title = extracted_title

        clean_artist, clean_title = clean_song_metadata(artist, title)
        if not clean_title:
            clean_title = "Unknown Title"

        log.info(f"[Titofy Resolver] Resolviendo letra para: '{clean_artist}' - '{clean_title}' (mode={mode}, dur={dur_int}, force={force})")

        # Auto-descarga si audio_path es de YouTube y se requiere archivo físico para Whisper
        if audio_path and audio_path.startswith("youtube:") and mode in ("hybrid", "online_align", "ai_only"):
            try:
                from youtube.downloader import download_youtube_audio_track
                dl_info = download_youtube_audio_track(
                    video_id=audio_path,
                    title=clean_title if clean_title != "Unknown Title" else None,
                    artist=clean_artist or None,
                )
                if dl_info and dl_info.get("file_path") and os.path.exists(dl_info["file_path"]):
                    audio_path = dl_info["file_path"]
                    log.info(f"[Titofy Resolver] Audio descargado transparentemente para Whisper: {audio_path}")
            except Exception as dl_err:
                log.warning(f"[Titofy Resolver] No se pudo auto-descargar audio youtube: {dl_err}")

        # Parche universal en RAM para faster-whisper y WhisperModel
        try:
            from faster_whisper import WhisperModel
            if not getattr(WhisperModel, "_vad_patched", False):
                _orig_transcribe = WhisperModel.transcribe
                def _safe_transcribe(self, *a, **kw):
                    kw.pop("vad", None)
                    return _orig_transcribe(self, *a, **kw)
                WhisperModel.transcribe = _safe_transcribe
                WhisperModel._vad_patched = True
                log.info("[Titofy Windows Patch] WhisperModel.transcribe parcheado en RAM exitosamente")
        except Exception as e:
            log.error(f"[Titofy Windows Patch ERROR] {e}")

        # ── FASE 1 (Nivel 1): Proveedores Online Sincronizados (Fuente 1, Fuente 2) ────
        if mode in ("auto", "online_only", "online_align", "hybrid") and not (mode in ("offline", "ai_only")):
            log.info(f"[Titofy Nivel 1] Consultando fuentes sincronizadas (Fuente 1, Fuente 2)...")
            tasks = [p.search_async(clean_artist, clean_title, dur_int) for p in self.synced_providers]
            synced_results = await asyncio.gather(*tasks, return_exceptions=True)

            for res in synced_results:
                if not isinstance(res, LyricData):
                    if isinstance(res, BaseException):
                        log.debug(f"[Titofy Nivel 1] Excepción en proveedor sincronizado: {res}")
                    continue

                if res.is_synced or (res.plain_lyrics or res.get_plain_text()):
                    log.info(
                        f"[Titofy Nivel 1] Letra encontrada en '{res.provider}' "
                        f"(sincronizada={res.is_synced}, {len(res.lines)} líneas)"
                    )

                    if res.is_synced:
                        from whisper_engine.loader import is_any_model_downloaded, get_best_available_model
                        should_align = (
                            mode in ("online_align", "hybrid") or
                            (mode == "auto" and is_any_model_downloaded())
                        )
                        if should_align and audio_path and os.path.exists(audio_path):
                            effective_model = get_best_available_model(model_name)
                            log.info(f"[Titofy] Modo '{mode}' con modelo '{effective_model}': calibración acústica con audio local...")
                            try:
                                calibrated = await asyncio.to_thread(
                                    calibrate_synced_lyrics, res, audio_path, model_name=effective_model, language=language
                                )
                                if calibrated and calibrated.is_synced and len(calibrated.lines) > 0:
                                    calibrated.title = res.title or clean_title
                                    calibrated.artist = res.artist or clean_artist
                                    save_lrc_if_requested(calibrated, output_lrc, audio_path, force=force)
                                    return calibrated
                            except Exception as e:
                                log.warning(f"[Titofy] Calibración falló ({e}). Entregando letra original.")
                                save_lrc_if_requested(res, output_lrc, audio_path, force=force)
                                return res
                        save_lrc_if_requested(res, output_lrc, audio_path, force=force)
                        return res

            # ── FASE 2 (Nivel 2): Proveedores Texto Plano (Fuente 3) ──────────────────
            log.info(f"[Titofy Nivel 2] Nivel 1 no disponible. Consultando Fuente 3...")
            plain_tasks = [p.search_async(clean_artist, clean_title, dur_int) for p in self.plain_providers]
            plain_results = await asyncio.gather(*plain_tasks, return_exceptions=True)

            for pres in plain_results:
                if not isinstance(pres, LyricData):
                    continue

                plain_text = pres.plain_lyrics or pres.get_plain_text()
                if plain_text:
                    from whisper_engine.loader import is_any_model_downloaded, get_best_available_model
                    should_align = (
                        mode in ("online_align", "hybrid") or
                        (mode == "auto" and is_any_model_downloaded())
                    )
                    if should_align and audio_path and os.path.exists(audio_path):
                        effective_model = get_best_available_model(model_name)
                        log.info(f"[Titofy Nivel 2] Alineando letra plana con audio local vía Whisper ({effective_model})...")
                        try:
                            aligned = await asyncio.to_thread(
                                align_plain_lyrics, pres, audio_path, model_name=effective_model, language=language
                            )
                            if aligned and aligned.is_synced and len(aligned.lines) > 0:
                                aligned.title = pres.title or clean_title
                                aligned.artist = pres.artist or clean_artist
                                aligned.provider = f"{pres.provider} · Alineada con Audio"
                                save_lrc_if_requested(aligned, output_lrc, audio_path, force=force)
                                return aligned
                        except Exception as e:
                            log.warning(f"Forced Alignment Nivel 2 falló ({e}).")
                            if mode == "online_align":
                                continue
                            if mode == "hybrid":
                                log.info(f"[Titofy Híbrido] Alineación falló; entregando texto de {pres.provider}.")
                                save_lrc_if_requested(pres, output_lrc, audio_path, force=force)
                                return pres

                    if should_align and mode == "online_align":
                        continue

                    save_lrc_if_requested(pres, output_lrc, audio_path, force=force)
                    return pres

        if mode in ("online_only", "auto"):
            log.info(f"[Titofy] No se encontró letra online para '{clean_artist} - {clean_title}'. Finalizando.")
            return None

        # ── FASE 3 (Nivel 3): Whisper Local Offline ──
        if mode in ("ai_only", "hybrid"):
            if not audio_path or not os.path.exists(audio_path):
                if mode == "hybrid":
                    log.info(f"[Titofy Híbrido] Sin audio local para transcribir. Finalizando.")
                    return None
                raise FileNotFoundError(
                    f"No se proporcionó archivo de audio local válido para transcripción: '{clean_artist} - {clean_title}'"
                )

            log.info(f"[Titofy Nivel 3] Iniciando transcripción con Whisper local ({model_name})...")
            generated = await asyncio.to_thread(
                generate_with_whisper,
                audio_path=audio_path,
                title=clean_title,
                artist=clean_artist,
                duration=dur_int,
                model_name=model_name,
                language=language,
            )

            save_lrc_if_requested(generated, output_lrc, audio_path, force=force)
            return generated

        return None

    def resolve(
        self,
        artist: str | None = None,
        title: str | None = None,
        duration: int | float | None = None,
        audio_path: str | None = None,
        mode: str = "auto",
        model_name: str = "small",
        language: str = "auto",
        output_lrc: str | None = None,
        force: bool = False,
    ) -> LyricData | None:
        """
        Versión síncrona retrocompatible de resolve().
        """
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop and loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                fut: concurrent.futures.Future[LyricData | None] = pool.submit(
                    asyncio.run,
                    self.resolve_async(
                        artist=artist,
                        title=title,
                        duration=duration,
                        audio_path=audio_path,
                        mode=mode,
                        model_name=model_name,
                        language=language,
                        output_lrc=output_lrc,
                        force=force,
                    ),
                )
                return fut.result()
        else:
            return asyncio.run(
                self.resolve_async(
                    artist=artist,
                    title=title,
                    duration=duration,
                    audio_path=audio_path,
                    mode=mode,
                    model_name=model_name,
                    language=language,
                    output_lrc=output_lrc,
                    force=force,
                )
            )

    # Métodos delegados para retrocompatibilidad
    def _calibrate_synced(self, data: LyricData, audio_path: str, model_name: str = "small", language: str = "auto") -> LyricData:
        return calibrate_synced_lyrics(data, audio_path, model_name, language)

    def _align(self, data: LyricData, audio_path: str, model_name: str = "base", language: str = "auto") -> LyricData:
        return align_plain_lyrics(data, audio_path, model_name, language)

    def _generate_with_whisper(self, audio_path: str, title: str, artist: str, duration: int | None, model_name: str = "small", language: str = "auto") -> LyricData:
        return generate_with_whisper(audio_path, title, artist, duration, model_name, language)

    @staticmethod
    def _save_lrc_if_requested(data: LyricData, output_lrc: str | None, audio_path: str | None, force: bool = False):
        save_lrc_if_requested(data, output_lrc, audio_path, force=force)
