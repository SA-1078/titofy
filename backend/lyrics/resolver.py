# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
resolver.py — Orquestador Híbrido de Resolución de Letras (Sin DB / Directo a .LRC)
Decide la fuente más económica y confiable para obtener letras sincronizadas:
1. Proveedores Online sincronizados (Nivel 1 - ej. LRCLIB)
2. Proveedores Online plano + Forced Alignment local (Nivel 2 - ej. Lyrics.ovh)
3. Transcripción Whisper local offline (Nivel 3)
"""

import os
import sys
import tempfile
from typing import Any

from .models import LyricData, LyricLine, LyricSource
from .normalizer import clean_query, extract_artist_title_from_filename, round_duration
from .providers.base import LyricsProvider
from .providers.lrclib import LrclibProvider
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
        self.providers = providers if providers is not None else [LrclibProvider(), LyricsOvhProvider()]

    def resolve(
        self,
        artist: str | None = None,
        title: str | None = None,
        duration: int | float | None = None,
        audio_path: str | None = None,
        mode: str = "auto",                  # "auto", "offline", "ai_only", "online_only"
        model_name: str = "small",
        language: str = "es",
        output_lrc: str | None = None,
        force: bool = False,
    ) -> LyricData | None:
        """
        Resuelve y retorna la letra para una canción según la prioridad jerárquica.
        """
        # Extraer artista y título del nombre de archivo si vienen vacíos o sucios
        if audio_path:
            extracted_artist, extracted_title = extract_artist_title_from_filename(audio_path)
            if not artist or not clean_query(artist):
                artist = extracted_artist
            if not title or not clean_query(title):
                title = extracted_title

        clean_artist = clean_query(artist) if artist else ""
        clean_title = clean_query(title) if title else "Unknown Title"
        dur_int = round_duration(duration)

        log.info(f"Resolviendo letra para: '{clean_artist}' - '{clean_title}' (mode={mode}, dur={dur_int})")

        # ── 1. Proveedores Online + Forced Alignment Local ────────────────────
        if mode in ("auto", "online_only", "online_align"):
            for provider in self.providers:
                try:
                    log.info(f"Consultando proveedor online '{provider.name}'...")
                    result = provider.search(clean_artist, clean_title, dur_int)
                except Exception as e:
                    log.warning(f"Error al consultar proveedor '{provider.name}': {e}")
                    continue

                if result is None:
                    continue

                plain_text = result.plain_lyrics or result.get_plain_text()

                # Si tenemos el archivo de audio local, alinear el texto oficial con el audio real
                # para garantizar que coincida al milisegundo con la versión exacta que tiene el usuario
                if plain_text and audio_path and os.path.exists(audio_path):
                    log.info(f"🎯 Letra oficial obtenida de '{provider.name}'. Alineando con tu audio local para sincronización exacta...")
                    try:
                        aligned = self._align(result, audio_path, model_name=model_name, language=language)
                        if aligned and aligned.is_synced:
                            log.info(f"✅ Sincronización milimétrica completada ({len(aligned.lines)} líneas)")
                            aligned.title = result.title or clean_title
                            aligned.artist = result.artist or clean_artist
                            aligned.provider = f"{provider.name} (calibrado con audio)"
                            self._save_lrc_if_requested(aligned, output_lrc, audio_path)
                            return aligned
                    except Exception as e:
                        log.warning(f"Forced Alignment falló ({e}). Usando timestamps online si existen...")

                # Si no se pudo alinear o no hay audio, usar los timestamps online directos si existen
                if result.is_synced:
                    log.info(f"✅ Usando letra sincronizada directa de '{provider.name}' ({len(result.lines)} líneas)")
                    self._save_lrc_if_requested(result, output_lrc, audio_path)
                    return result

        if mode == "online_only":
            raise ValueError(f"No se encontró letra online para '{clean_artist} - {clean_title}'")



        # ── 2. Nivel 3: Whisper local de audio completo ───────────────────────
        if not audio_path or not os.path.exists(audio_path):
            raise FileNotFoundError(
                f"No hay letra online y no se proporcionó archivo de audio local válido para '{clean_artist} - {clean_title}'"
            )

        log.info(f"🤖 Nivel 3: Sin letra online disponible. Ejecutando transcripción Whisper ({model_name})...")
        generated = self._generate_with_whisper(
            audio_path=audio_path,
            title=clean_title,
            artist=clean_artist,
            duration=dur_int,
            model_name=model_name,
            language=language,
        )

        self._save_lrc_if_requested(generated, output_lrc, audio_path)
        return generated


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

        # Usar idioma detectado de data si existe, o el provisto
        effective_lang = data.language if (data.language and data.language != "auto") else language
        if effective_lang == "auto":
            effective_lang = "es"  # Fallback seguro para el aligner

        # Generar salida en archivo temporal
        with tempfile.NamedTemporaryFile(suffix=".lrc", delete=False) as tmp:
            tmp_lrc_path = tmp.name

        try:
            from whisper_engine.align import align_lyrics
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
            from whisper_engine.transcribe import transcribe_audio
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
    def _save_lrc_if_requested(data: LyricData, output_lrc: str | None, audio_path: str | None):
        target_path = output_lrc
        if not target_path and audio_path:
            # Si no se pasó output_lrc pero hay audio_path, calcular mismo nombre con .lrc
            target_path = os.path.splitext(audio_path)[0] + ".lrc"

        if target_path:
            out_dir = os.path.dirname(target_path)
            if out_dir:
                os.makedirs(out_dir, exist_ok=True)
            with open(target_path, "w", encoding="utf-8") as f:
                f.write(data.to_lrc())
            log.info(f"Archivo .lrc guardado en: {target_path}")
