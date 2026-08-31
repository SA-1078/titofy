# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
transcribe.py — Modulo Principal de Transcripcion de Audio con Whisper Local.
"""

import sys
import os
import argparse
import shutil
import typing

os.environ["TQDM_DISABLE"] = "1"
os.environ["PYTHONWARNINGS"] = "ignore"
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import warnings
warnings.filterwarnings("ignore")

import logging
logging.getLogger("stable_whisper").setLevel(logging.ERROR)
logging.getLogger("whisper").setLevel(logging.ERROR)
logging.getLogger("numba").setLevel(logging.ERROR)
logging.getLogger("ctranslate2").setLevel(logging.ERROR)
logging.getLogger("torch").setLevel(logging.ERROR)

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from logger import get_logger
from lyric_config import get_config
from whisper_engine.loader import setup_cuda_dlls, detect_device, load_whisper_model, is_model_downloaded, validate_audio_file, print_yellow
from whisper_engine.formatter import to_lrc_timestamp, clean_text, split_long_segment, estimate_transcription_quality

log = get_logger("whisper.transcribe")

try:
    from music_detector import classify_sections
    HAS_MUSIC_DETECTOR = True
except ImportError:
    HAS_MUSIC_DETECTOR = False

try:
    from postprocess.cleaner import postprocess_segments
    HAS_POSTPROCESS = True
except ImportError:
    HAS_POSTPROCESS = False

INITIAL_PROMPTS = {
    "es": "Letra de canción en español. Transcripción precisa de la voz cantada.",
    "en": "Song lyrics in English. Precise transcription of singing voice.",
    "pt": "Letra de música em português. Transcrição precisa da voz cantada.",
    "fr": "Paroles de chanson en français. Transcription précise de la voix chantée.",
    "it": "Testo della canzone in italiano. Trascrizione precisa della voce cantata.",
    "de": "Songtext auf Deutsch. Präzise Transkription der Gesangsstimme.",
}


def transcribe_audio(
    audio_path: str,
    output_path: str | None = None,
    model_name: str = "small",
    language: str = "auto",
    word_mode: bool = False,
    verbose: bool = True,
):
    """Transcribe un archivo de audio a .lrc usando Whisper local."""
    setup_cuda_dlls()
    cfg = get_config()

    if output_path is None:
        output_path = os.path.splitext(audio_path)[0] + ".lrc"

    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    # ── Borrar LRC anterior para garantizar transcripción fresca ──────────
    # Evita que el sistema reutilice un resultado previo (cache implícito)
    if os.path.exists(output_path):
        try:
            os.remove(output_path)
            log.info(f"LRC anterior eliminado para regeneración fresca: {os.path.basename(output_path)}")
        except OSError as e:
            log.warning(f"No se pudo eliminar LRC anterior: {e}")

    basename = os.path.basename(audio_path)
    lrc_name = os.path.basename(output_path)

    term_width = shutil.get_terminal_size((100, 20)).columns
    inner_width = min(max(term_width - 6, 60), 140)

    if verbose:
        print()
        print("  ╭" + "─" * (inner_width - 2) + "╮")
        print("  │  🎵 TITOFY — TRANSCRIBIR AUDIO A LRC DE LETRAS".ljust(inner_width, ' ') + "│")
        print("  ╰" + "─" * (inner_width - 2) + "╯")
        print()

    duration = validate_audio_file(audio_path)
    lang_display = "auto (detectar)" if language == "auto" else language
    model_display = f"{model_name} (turbo SOTA)" if model_name in ["turbo", "large-v3-turbo"] else model_name

    device, device_name = detect_device()

    if verbose:
        sep = "  │  " + "─" * (inner_width - 7) + "  │"
        print("  ╭" + "─" * (inner_width - 2) + "╮")
        def _row(key, val):
            line = f"  │  {key:<12}: {val}"
            print(line.ljust(inner_width + 2) + "│")
        _row("Modelo", model_display)
        _row("Archivo", basename)
        if duration:
            dur_m = int(duration // 60)
            dur_s = int(duration % 60)
            _row("Duración", f"{dur_m}:{dur_s:02d}")
        _row("Idioma", lang_display)
        _row("Salida", f"lrc/{lrc_name}")
        if device == "cuda":
            _row("GPU", device_name)
            _row("Precisión", "FP16 · aceleración GPU")
        else:
            _row("Hardware", "CPU (int8) — sin GPU CUDA")
        print("  ╰" + "─" * (inner_width - 2) + "╯")
        print()

    log.info(f"Iniciando transcripción: {basename} [modelo={model_name}, lang={lang_display}, device={device}]")

    wcfg = cfg.get("whisper", {})
    compute_type = wcfg.get("compute_type", "auto")

    # ── Limpiar caché CUDA antes de cargar el modelo ───────────────────────
    try:
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.reset_peak_memory_stats()
            log.info("Caché CUDA limpiada antes de cargar modelo")
    except Exception:
        pass

    if verbose:
        print(f"  ⏳ Cargando modelo '{model_name}' en {device.upper()}...")

    try:
        model, is_faster = load_whisper_model(model_name, device=device, compute_type=compute_type)
    except Exception as exc:
        exc_str = str(exc)
        if "CUDA out of memory" in exc_str or "out of memory" in exc_str.lower():
            log.warning(f"CUDA Out of Memory en GPU. Conmutando a CPU como fallback: {exc}")
            print_yellow("  ⚠️  VRAM agotada. Conmutando a CPU (int8)...")
            device = "cpu"
            model, is_faster = load_whisper_model(model_name, device="cpu", compute_type="int8")
        else:
            raise exc

    log.info(f"Modelo '{model_name}' cargado en {device} [{device_name}]")

    import time
    real_stdout = sys.stdout
    start_time = time.time()

    def progress_callback(seek, total):
        if total <= 0:
            return
        pct = min(100, int((seek / total) * 100))
        bar_len = 20
        filled = int((pct / 100.0) * bar_len)
        bar = "█" * filled + "░" * (bar_len - filled)

        elapsed = time.time() - start_time
        if pct > 0:
            total_est = elapsed / (pct / 100.0)
            rem_sec = max(0, int(total_est - elapsed))
        else:
            rem_sec = max(0, int(duration - seek)) if duration else 0

        rem_m = rem_sec // 60
        rem_s = rem_sec % 60
        time_str = f"{rem_m}:{rem_s:02d} restantes"

        real_stdout.write(f"\r→ Transcribiendo  {bar}  {pct}%  ·  {time_str}   ")
        real_stdout.flush()

    default_lang = wcfg.get("default_language", "es")
    selected_lang = default_lang if language == "auto" else language
    lang_param = None if selected_lang == "auto" else selected_lang

    initial_prompt = wcfg.get("initial_prompt", None)

    transcribe_kwargs = {
        "language": lang_param,
        "initial_prompt": initial_prompt,
        "vad": wcfg.get("vad", True),
    }


    if is_faster:
        transcribe_kwargs.update({
            "beam_size": wcfg.get("beam_size", 5),
            "patience": wcfg.get("patience", 1.0),
            "no_speech_threshold": wcfg.get("no_speech_threshold", 0.6),
            # True: el modelo recuerda lo que transcribió antes → respeta repeticiones legítimas
            "condition_on_previous_text": wcfg.get("condition_on_previous_text", True),
            # Umbral de compresión más alto: canciones con estribillos repetidos tienen
            # ratio alto de compresión, no deben ser descartadas como alucinaciones
            "compression_ratio_threshold": wcfg.get("compression_ratio_threshold", 3.0),
            # Penalización de repetición baja → permite repetir frases reales de la canción
            "repetition_penalty": wcfg.get("repetition_penalty", 1.0),
            # Silenciar la barra de progreso interna de faster-whisper
            "verbose": False,
        })
    else:
        transcribe_kwargs["verbose"] = False

    orig_tqdm: typing.Any = None
    try:
        import tqdm as _tqdm_mod
        orig_tqdm = getattr(_tqdm_mod, "tqdm", None)
        if orig_tqdm is not None:
            setattr(_tqdm_mod, "tqdm", lambda *a, **k: orig_tqdm(*a, **{**k, "disable": True}))
    except Exception:
        pass

    import io
    devnull_stream = io.StringIO()

    try:
        sys.stdout = devnull_stream  # suprimir «Detected Language: ...» de stable-whisper
        model_obj: typing.Any = model
        if is_faster:
            result = model_obj.transcribe(audio_path, progress_callback=progress_callback, **transcribe_kwargs)
        else:
            result = model_obj.transcribe(audio_path, **transcribe_kwargs)
    except Exception as e:
        sys.stdout = real_stdout
        real_stdout.write("\n")
        log.error(f"Fallo en la transcripción: {e}")
        print(f"\n  ❌ Error durante la transcripción: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        sys.stdout = real_stdout
        real_stdout.write("\r" + " " * 80 + "\r")
        real_stdout.flush()
        # Restaurar tqdm original
        try:
            import tqdm as _tqdm_mod
            if orig_tqdm is not None:
                setattr(_tqdm_mod, "tqdm", orig_tqdm)
        except Exception:
            pass



    result_obj: typing.Any = result
    result_dict = result_obj.to_dict() if hasattr(result_obj, "to_dict") else dict(result_obj)
    detected_lang = result_dict.get("language", language)
    segments = result_dict.get("segments", [])

    if not segments:
        print_yellow("\n  ⚠️  Whisper no detectó voz en este audio.")
        sys.exit(1)

    quality = estimate_transcription_quality(segments, duration)

    if wcfg.get("postprocess", True) and HAS_POSTPROCESS:
        threshold = wcfg.get("postprocess_threshold", 85)
        segments = postprocess_segments(segments, similarity_threshold=threshold)

    if wcfg.get("classify_music_sections", True) and HAS_MUSIC_DETECTOR:
        total_dur = duration or (segments[-1]["end"] if segments else 180.0)
        segments = classify_sections(segments, total_dur)

    title = os.path.splitext(os.path.basename(audio_path))[0]
    lrc_lines = [
        f"[ti:{title}]",
        f"[by:Titofy — Whisper {model_name} | lang:{detected_lang}]",
        "",
    ]

    if word_mode:
        for seg in segments:
            words = seg.get("words", [])
            for w in words:
                text = clean_text(w.get("word", ""), detected_lang)
                if text:
                    ts = to_lrc_timestamp(w["start"])
                    lrc_lines.append(f"[{ts}]{text}")
    else:
        for seg in segments:
            text = seg["text"].strip()
            if not text:
                continue
            parts = split_long_segment(text, seg["start"], seg["end"])
            for (t, part_text) in parts:
                ts = to_lrc_timestamp(t)
                lrc_lines.append(f"[{ts}]{part_text}")

    lrc_content = "\n".join(lrc_lines)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(lrc_content)

    lyric_count = len([l for l in lrc_lines if l.startswith("[") and not l.startswith("[ti") and not l.startswith("[by")])
    log.info(f"LRC generado: {lrc_name} [{lyric_count} líneas]")

    score_val = quality['overall_score']
    if score_val >= 80:
        score_str = f"\033[32m{score_val}%\033[0m"
    elif score_val >= 60:
        score_str = f"\033[33m{score_val}%\033[0m"
    else:
        score_str = f"\033[31m{score_val}%\033[0m"

    if verbose:
        print()
        def _res(key, val):
            line = f"  │  {key:<24}: {val}"
            print(line.ljust(inner_width + 2) + "│")
        print("  ╭" + "─" * (inner_width - 2) + "╮")
        print("  │  Resultado".ljust(inner_width + 2) + "│")
        print("  │  " + "─" * (inner_width - 7) + "  │")
        _res("Líneas sincronizadas", str(lyric_count))
        _res("Nivel de confianza", score_str)
        if quality['low_confidence_segments'] > 0:
            _res("Segmentos baja confianza", f"{quality['low_confidence_segments']} ({quality['low_confidence_pct']}%)")
        print("  │".ljust(inner_width + 2) + "│")
        _res("Guardado en", f"lrc/{lrc_name}")
        print("  ╰" + "─" * (inner_width - 2) + "╯")
        print()



if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Titofy — Generador LRC con Whisper local (offline)",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("audio", help="Ruta al archivo de audio (.mp3, .wav, .m4a, .mp4, etc.)")
    parser.add_argument("--output", "-o", default=None, help="Nombre del archivo .lrc de salida")
    parser.add_argument("--model", "-m", default="small", choices=["base", "small", "turbo", "large-v3-turbo"], help="Modelo Whisper a usar")
    parser.add_argument("--language", "-l", default="auto", help="Código de idioma (es, en, pt, fr... o auto)")
    parser.add_argument("--words", action="store_true", help="Generar timestamps por PALABRA")
    parser.add_argument("--force", action="store_true", help="Forzar regeneración aunque el LRC ya exista (borra caché)")

    args = parser.parse_args()
    transcribe_audio(args.audio, args.output, args.model, args.language, args.words)
