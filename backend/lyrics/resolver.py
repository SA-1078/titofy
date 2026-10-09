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

import os
import sys
import asyncio
import tempfile
from typing import Any

from .models import LyricData, LyricLine, LyricSource
from .normalizer import clean_query, extract_artist_title_from_filename, round_duration
from .fingerprint import identify_audio
from .providers.base import LyricsProvider
from .providers.lrclib import LrclibProvider
from .providers.netease import NeteaseProvider
from .providers.lyrist import LyristProvider
from .providers.genius import GeniusProvider
from .providers.lyrics_ovh import LyricsOvhProvider

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

            # Si aún faltan, extraer del nombre de archivo
            if (not artist or not clean_query(artist)) or (not title or not clean_query(title)):
                extracted_artist, extracted_title = extract_artist_title_from_filename(audio_path)
                if not artist or not clean_query(artist):
                    artist = extracted_artist
                if not title or not clean_query(title):
                    title = extracted_title

        clean_artist = clean_query(artist) if artist else ""
        clean_title = clean_query(title) if title else "Unknown Title"

        log.info(f"[Titofy Resolver] Resolviendo letra para: '{clean_artist}' - '{clean_title}' (mode={mode}, dur={dur_int}, force={force})")

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

                    # Si hay un archivo de audio local:
                    # SIEMPRE alinear con el audio local (Forced Alignment) escuchando la canción
                    # para que los timestamps encajen exactamente con el archivo local
                    # (corrige desfases de intros de video oficial, diálogos, silencios, etc.)
                    if audio_path and os.path.exists(audio_path):
                        log.info(f"[Titofy] Sincronizando letra de '{res.provider}' escuchando audio local ({audio_path})...")
                        try:
                            aligned = await asyncio.to_thread(
                                self._align, res, audio_path, model_name=model_name, language=language
                            )
                            if aligned and aligned.is_synced and len(aligned.lines) > 0:
                                aligned.title = res.title or clean_title
                                aligned.artist = res.artist or clean_artist
                                aligned.provider = f"{res.provider} · Alineada con Audio"
                                self._save_lrc_if_requested(aligned, output_lrc, audio_path, force=force)
                                return aligned
                        except Exception as e:
                            log.warning(f"[Titofy] Alineación con audio local falló ({e}). Retornando letra de '{res.provider}'.")

                    if res.is_synced:
                        self._save_lrc_if_requested(res, output_lrc, audio_path, force=force)
                        return res

            # ── FASE 2 (Nivel 2): Proveedores Texto Plano (Fuente 3) + Forced Alignment ──
            log.info(f"[Titofy Nivel 2] Nivel 1 no disponible o sin sincronizar. Consultando Fuente 3...")
            plain_tasks = [p.search_async(clean_artist, clean_title, dur_int) for p in self.plain_providers]
            plain_results = await asyncio.gather(*plain_tasks, return_exceptions=True)

            for pres in plain_results:
                if not isinstance(pres, LyricData):
                    continue

                plain_text = pres.plain_lyrics or pres.get_plain_text()
                if plain_text and audio_path and os.path.exists(audio_path):
                    log.info(f"[Titofy Nivel 2] Letra plana obtenida de '{pres.provider}'. Alineando con audio local vía Whisper...")
                    try:
                        aligned = await asyncio.to_thread(
                            self._align, pres, audio_path, model_name=model_name, language=language
                        )
                        if aligned and aligned.is_synced and len(aligned.lines) > 0:
                            log.info(f"[Titofy Nivel 2] Alineación completada con éxito ({len(aligned.lines)} líneas)")
                            aligned.title = pres.title or clean_title
                            aligned.artist = pres.artist or clean_artist
                            aligned.provider = f"{pres.provider} · Alineada con Audio"
                            self._save_lrc_if_requested(aligned, output_lrc, audio_path, force=force)
                            return aligned
                    except Exception as e:
                        log.warning(f"Forced Alignment Nivel 2 falló ({e}).")

                if plain_text:
                    self._save_lrc_if_requested(pres, output_lrc, audio_path, force=force)
                    return pres

        if mode == "online_only":
            raise ValueError(
                f"No se encontró letra online en ninguna fuente (Fuente 1, Fuente 2, Fuente 3) para '{clean_artist} - {clean_title}'."
            )

        # ── FASE 3 (Nivel 3): Whisper Local Offline ───────────────────────────
        if not audio_path or not os.path.exists(audio_path):
            raise FileNotFoundError(
                f"No hay letra online y no se proporcionó archivo de audio local válido para '{clean_artist} - {clean_title}'"
            )

        log.info(f"[Titofy Nivel 3] Iniciando transcripción completa con Whisper local ({model_name})...")
        generated = await asyncio.to_thread(
            self._generate_with_whisper,
            audio_path=audio_path,
            title=clean_title,
            artist=clean_artist,
            duration=dur_int,
            model_name=model_name,
            language=language,
        )

        self._save_lrc_if_requested(generated, output_lrc, audio_path, force=force)
        return generated

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
        Ejecuta resolve_async() en el bucle de eventos apropiado.
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
                res: LyricData | None = fut.result()
                return res
        else:
            res_sync: LyricData | None = asyncio.run(
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
            return res_sync

    def _align(
        self,
        data: LyricData,
        audio_path: str,
        model_name: str = "base",
        language: str = "auto",
    ) -> LyricData:
        """
        Ejecuta Forced Alignment (alineación forzada) del texto plano contra el audio.
        """
        lyrics_text = data.get_plain_text()
        if not lyrics_text.strip():
            raise ValueError("Texto de letra vacío para alineación")

        effective_lang = data.language if (data.language and data.language != "auto") else language
        if effective_lang == "auto":
            effective_lang = "es"

        with tempfile.NamedTemporaryFile(suffix=".lrc", delete=False) as tmp:
            tmp_lrc_path = tmp.name

        try:
            try:
                from whisper_engine.align import align_lyrics
            except ImportError:
                from whisper_align import align_lyrics

            align_lyrics(
                audio_path=audio_path,
                lyrics_text=lyrics_text,
                output_path=tmp_lrc_path,
                model_name=model_name,
                language=effective_lang,
            )

            if os.path.exists(tmp_lrc_path):
                with open(tmp_lrc_path, "r", encoding="utf-8") as f:
                    lrc_content = f.read()

                aligned_data = LyricData.from_lrc_string(
                    lrc_text=lrc_content,
                    title=data.title,
                    artist=data.artist,
                    duration=data.duration,
                    source=LyricSource.ONLINE_ALIGNED,
                    language=effective_lang,
                    album=data.album,
                    provider=data.provider,
                )
                aligned_data.plain_lyrics = lyrics_text
                return aligned_data
        finally:
            if os.path.exists(tmp_lrc_path):
                try:
                    os.remove(tmp_lrc_path)
                except OSError:
                    pass

        raise RuntimeError("Fallo al generar archivo de alineación forzada")

    def _generate_with_whisper(
        self,
        audio_path: str,
        title: str,
        artist: str,
        duration: int | None,
        model_name: str = "small",
        language: str = "auto",
    ) -> LyricData:
        """
        Ejecuta la transcripción completa de Whisper local.
        """
        with tempfile.NamedTemporaryFile(suffix=".lrc", delete=False) as tmp:
            tmp_lrc_path = tmp.name

        try:
            try:
                from whisper_engine.transcribe import transcribe_audio
            except ImportError:
                from whisper_transcribe import transcribe_audio

            transcribe_audio(
                audio_path=audio_path,
                output_path=tmp_lrc_path,
                model_name=model_name,
                language=language,
                verbose=False,
            )

            if os.path.exists(tmp_lrc_path):
                with open(tmp_lrc_path, "r", encoding="utf-8") as f:
                    lrc_content = f.read()

                return LyricData.from_lrc_string(
                    lrc_text=lrc_content,
                    title=title,
                    artist=artist,
                    duration=duration,
                    source=LyricSource.AI_GENERATED,
                    language=language if language != "auto" else None,
                    provider="whisper_local",
                )
        finally:
            if os.path.exists(tmp_lrc_path):
                try:
                    os.remove(tmp_lrc_path)
                except OSError:
                    pass

        raise RuntimeError(f"Fallo al transcribir con Whisper local: {audio_path}")

    @staticmethod
    def _save_lrc_if_requested(data: LyricData, output_lrc: str | None, audio_path: str | None, force: bool = False):
        cli_lrc_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "cli", "lrc"))
        backend_lrc_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "lrc"))

        for d in [cli_lrc_dir, backend_lrc_dir]:
            try:
                os.makedirs(d, exist_ok=True)
            except Exception:
                pass

        if audio_path:
            # Eliminar cualquier archivo .lrc extraviado en la carpeta de música del usuario
            stray_music_lrc = os.path.splitext(audio_path)[0] + ".lrc"
            if os.path.exists(stray_music_lrc):
                try:
                    os.remove(stray_music_lrc)
                    log.info(f"Eliminado archivo .lrc residual de la carpeta de música: {stray_music_lrc}")
                except Exception as e:
                    log.warning(f"No se pudo eliminar .lrc en carpeta de música: {e}")

            audio_base = os.path.splitext(os.path.basename(audio_path))[0]
            for lrc_dir in [cli_lrc_dir, backend_lrc_dir]:
                target = os.path.join(lrc_dir, f"{audio_base}.lrc")
                if force and os.path.exists(target):
                    try:
                        os.remove(target)
                    except OSError:
                        pass
                try:
                    with open(target, "w", encoding="utf-8") as f:
                        f.write(data.to_lrc())
                    log.info(f"Archivo .lrc guardado en: {target}")
                except Exception as e:
                    log.warning(f"No se pudo guardar en {target}: {e}")

        # Si se solicitó explícitamente un output_lrc, verificar que NO sea la carpeta de música del usuario
        if output_lrc:
            audio_dir = os.path.abspath(os.path.dirname(audio_path)) if audio_path else ""
            out_dir = os.path.abspath(os.path.dirname(output_lrc))
            if out_dir and out_dir != audio_dir:
                try:
                    os.makedirs(out_dir, exist_ok=True)
                    if force and os.path.exists(output_lrc):
                        try:
                            os.remove(output_lrc)
                        except OSError:
                            pass
                    with open(output_lrc, "w", encoding="utf-8") as f:
                        f.write(data.to_lrc())
                    log.info(f"Archivo .lrc guardado en ruta explícita: {output_lrc}")
                except Exception as e:
                    log.warning(f"No se pudo guardar en {output_lrc}: {e}")
