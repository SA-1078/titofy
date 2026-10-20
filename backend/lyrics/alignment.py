# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/lyrics/alignment.py — Calibración acústica, Forced Alignment y Whisper local para letras.
"""

from __future__ import annotations

import os
import tempfile
from typing import TYPE_CHECKING

from .models import LyricData, LyricLine, LyricSource

if TYPE_CHECKING:
    pass

try:
    from logger import get_logger
    log = get_logger("lyrics.alignment")
except ImportError:
    import logging
    log = logging.getLogger("lyrics.alignment")


def calibrate_synced_lyrics(
    data: LyricData,
    audio_path: str,
    model_name: str = "small",
    language: str = "auto",
) -> LyricData:
    """
    Calibra letras que YA vienen sincronizadas online contra el audio local.
    Detecta el desfase de inicio (intro/videoclip) sin alterar la métrica de LRCLIB.
    """
    if not data.lines:
        return data

    first_line = next(
        (
            l
            for l in data.lines
            if l.text and l.text.strip() and not l.text.strip().lower().startswith("(intro") and l.start is not None
        ),
        None,
    )
    if not first_line or first_line.start is None:
        return data

    original_start: float = float(first_line.start)

    try:
        from whisper_engine.loader import get_whisper_model, cleanup_gpu_memory
        model, _ = get_whisper_model(model_name)

        effective_lang = None if (not language or language == "auto") else language
        result = model.transcribe(audio_path, language=effective_lang, word_timestamps=True)

        first_vocal_time: float | None = None
        if isinstance(result, tuple) and len(result) == 2:
            segments_gen, _ = result
            for s in segments_gen:
                text = str(getattr(s, "text", "") or "").strip()
                if text and len(text) >= 3:
                    s_words = getattr(s, "words", None)
                    s_start = getattr(s, "start", 0.0)
                    if s_words:
                        for w in s_words:
                            if getattr(w, "word", "").strip():
                                w_start = getattr(w, "start", None)
                                val = w_start if w_start is not None else s_start
                                if val is not None:
                                    first_vocal_time = float(val)
                                    break
                    if first_vocal_time is None and s_start is not None:
                        first_vocal_time = float(s_start)
                    break

        if first_vocal_time is not None:
            offset = round(first_vocal_time - original_start, 2)
            if abs(offset) >= 3.0:
                try:
                    log.info(
                        f"[Titofy Calibración] Desfase grande de {offset:+.2f}s. "
                        "Alineando la letra completa contra el audio local..."
                    )
                    aligned = align_plain_lyrics(data, audio_path, model_name, language)
                    if aligned.is_synced and aligned.lines:
                        aligned.provider = f"{data.provider} · Alineada con audio"
                        return aligned
                except Exception as exc:
                    log.warning(f"[Titofy Calibración] Alineación completa falló ({exc}). Usando ajuste global.")
            if 0.6 <= abs(offset) <= 60.0:
                log.info(
                    f"[Titofy Calibración] Desfase detectado de {offset:+.2f}s "
                    f"(audio: {first_vocal_time:.2f}s vs letra: {original_start:.2f}s). "
                    f"Aplicando a {len(data.lines)} líneas..."
                )
                calibrated_lines: list[LyricLine] = []
                if first_vocal_time >= 6.0:
                    calibrated_lines.append(LyricLine(start=0.0, text="(intro)"))

                for l in data.lines:
                    if l.start is not None:
                        new_start: float | None = max(0.0, round(float(l.start) + offset, 2))
                    else:
                        new_start = None
                    calibrated_lines.append(LyricLine(start=new_start, text=l.text))

                data.lines = calibrated_lines
                data.source = LyricSource.ONLINE_ALIGNED
                data.provider = f"{data.provider} · Calibrada ({offset:+.1f}s)"
                return data
            else:
                log.info(
                    f"[Titofy Calibración] Audio local coincide con letra online "
                    f"({offset:+.2f}s). Marcas de tiempo de LRCLIB verificadas."
                )
                data.provider = f"{data.provider} · Verificada"
                return data
    except Exception as e:
        log.warning(f"[Titofy Calibración] Error en calibración acústica ({e}). Conservando sincronización original.")

    return data


def align_plain_lyrics(
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
            from whisper_engine.loader import get_best_available_model
            effective_model = get_best_available_model(model_name)
        except Exception:
            effective_model = model_name

        try:
            from whisper_engine.align import align_lyrics
        except ImportError:
            from whisper_align import align_lyrics

        align_lyrics(
            audio_path=audio_path,
            lyrics_text=lyrics_text,
            output_path=tmp_lrc_path,
            model_name=effective_model,
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


def generate_with_whisper(
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
