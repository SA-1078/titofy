# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
align.py — Forced Alignment: sincroniza una letra existente con el audio.
"""

import sys
import os
import shutil
import argparse
import typing

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from logger import get_logger
from lyric_config import get_config
from whisper_engine.loader import setup_cuda_dlls, detect_device, load_whisper_model, is_model_downloaded, validate_audio_file, print_yellow
from whisper_engine.formatter import to_lrc_timestamp

import re

log = get_logger("whisper.align")


def _clean_token(token: str) -> str:
    """Normaliza una palabra para matching ignorando signos de puntuación y mayúsculas."""
    return re.sub(r"[^\w]", "", token.lower())


def map_words_to_original_lines(original_lines: list[str], words: list[dict[str, typing.Any]]) -> list[str]:
    """
    Asigna a cada línea original de la letra su marca de tiempo exacta basándose
    en los timestamps de las palabras reconocidas por Whisper.
    Preserva intacta la estructura de estrofas y versos del texto original,
    manejando limpiamente intros instrumentales y diálogos de videos musicales.
    """
    mapped_lrc: list[str] = []
    total_words = len(words)

    # 1. Detectar el inicio de la primera actividad vocal genuina
    first_real_vocal_ts = 0.0
    for i in range(total_words):
        w = words[i]
        dur = float(w.get("end", 0.0)) - float(w.get("start", 0.0))
        prob = float(w.get("probability", 0.0))
        if dur > 0.08 and prob > 0.20:
            first_real_vocal_ts = float(w.get("start", 0.0))
            break

    # Si hay una introducción instrumental o diálogo > 8s, insertar marcador limpio de (intro)
    if first_real_vocal_ts >= 8.0:
        mapped_lrc.append("[00:00.00] (intro)")

    w_idx = 0

    for line in original_lines:
        line_strip = line.strip()
        if not line_strip:
            continue

        line_tokens = [_clean_token(t) for t in line_strip.split() if _clean_token(t)]
        if not line_tokens:
            continue

        start_ts: float | None = None
        matched_tokens = 0

        while w_idx < total_words and matched_tokens < len(line_tokens):
            w_obj = words[w_idx]
            w_token = _clean_token(w_obj.get("word", ""))

            if w_token == line_tokens[matched_tokens]:
                if start_ts is None:
                    raw_ts = float(w_obj.get("start", 0.0))
                    w_prob = float(w_obj.get("probability", 0.0))
                    w_dur = float(w_obj.get("end", 0.0)) - raw_ts
                    if raw_ts >= first_real_vocal_ts or (w_prob > 0.35 and w_dur > 0.10):
                        start_ts = raw_ts
                    else:
                        start_ts = first_real_vocal_ts
                matched_tokens += 1
            w_idx += 1

        if start_ts is None:
            if w_idx < total_words:
                start_ts = max(float(words[w_idx].get("start", 0.0)), first_real_vocal_ts)
            elif total_words > 0:
                start_ts = max(float(words[-1].get("start", 0.0)), first_real_vocal_ts)
            else:
                start_ts = first_real_vocal_ts

        ts_str = to_lrc_timestamp(start_ts)
        mapped_lrc.append(f"[{ts_str}]{line_strip}")

    return mapped_lrc



def align_lyrics(

    audio_path: str,
    lyrics_text: str,
    output_path: str,
    model_name: str = "base",
    language: str = "es",
):
    """
    Toma un audio + letra existente y genera un .lrc perfectamente sincronizado.
    """
    setup_cuda_dlls()
    cfg = get_config()

    basename = os.path.basename(audio_path)
    lrc_name = os.path.basename(output_path)

    term_width = shutil.get_terminal_size((100, 20)).columns
    inner_width = min(max(term_width - 6, 60), 140)

    print()
    print("  ╭" + "─" * (inner_width - 2) + "╮")
    print("  │  🎯 FORCED ALIGNMENT — SINCRONIZACIÓN CON LETRA EXISTENTE".ljust(inner_width, ' ') + "│")
    print("  ╰" + "─" * (inner_width - 2) + "╯")
    print()
    print(f"  💿 Archivo  : {basename}")

    duration = validate_audio_file(audio_path)
    size_mb = os.path.getsize(audio_path) / (1024 * 1024)
    line_count = len([l for l in lyrics_text.strip().split("\n") if l.strip()])

    print(f"  📦 Tamaño   : {size_mb:.2f} MB")
    if duration:
        print(f"  ⏱️ Duración : {duration:.2f} s")
    print(f"  🤖 Modelo   : {model_name} (alineación)")
    print(f"  🌐 Idioma   : {language}")
    print(f"  📝 Líneas   : {line_count} líneas de letra")
    print(f"  📂 Salida   : {lrc_name}")
    print("  " + "─" * inner_width)
    print()

    device, device_name = detect_device()
    if device == "cuda":
        print(f"  🚀 GPU       : {device_name}")
    else:
        print_yellow("  ⚠️  GPU CUDA no detectada; usando CPU como fallback seguro.")

    wcfg = cfg.get("whisper", {})
    compute_type = wcfg.get("compute_type", "auto")

    log.info(f"Cargando modelo '{model_name}' en {device} para alineación...")
    import stable_whisper
    model: typing.Any = stable_whisper.load_model(model_name, device=device)

    log.info("Ejecutando forced alignment (stable-ts model.align)...")
    print("  🔄 Alineando letra con audio...")
    print("     ℹ️  Esto es más rápido que transcribir desde cero.\n")

    try:
        result = model.align(audio_path, lyrics_text, language=language)
    except Exception as e:
        log.error(f"Fallo en forced alignment: {e}")
        print(f"\n  ❌ Error durante la alineación: {e}", file=sys.stderr)
        sys.exit(1)

    if cfg.get("whisper", {}).get("adjust_by_silence", True):
        try:
            result.adjust_by_silence(audio_path, q_levels=20, k_size=5)
            log.info("Realineamiento por silencios aplicado")
            print("  ✅ Realineamiento por silencios aplicado")
        except Exception as e:
            log.warning(f"Realineamiento por silencios omitido: {e}")

    result_dict = result.to_dict()
    segments = result_dict.get("segments", [])

    # Extraer todas las palabras con timestamps
    all_words: list[dict[str, typing.Any]] = []
    for seg in segments:
        for w in seg.get("words", []):
            all_words.append(w)

    title = os.path.splitext(os.path.basename(audio_path))[0]
    lrc_lines = [
        f"[ti:{title}]",
        f"[by:Titofy — Forced Alignment ({model_name}) | lang:{language}]",
        "",
    ]

    orig_lines = [l.strip() for l in lyrics_text.splitlines() if l.strip()]

    if all_words and orig_lines:
        # Mapear respetando 100% las estrofas y versos de la letra original
        mapped_verses = map_words_to_original_lines(orig_lines, all_words)
        lrc_lines.extend(mapped_verses)
    else:
        # Fallback a segmentos directos si no hay palabras
        for seg in segments:
            text = seg.get("text", "").strip()
            if not text:
                continue
            ts = to_lrc_timestamp(seg["start"])
            lrc_lines.append(f"[{ts}]{text}")

    lrc_content = "\n".join(lrc_lines)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(lrc_content)

    lyric_count = len([l for l in lrc_lines if l.startswith("[") and not l.startswith("[ti") and not l.startswith("[by")])
    log.info(f"Alineación completada: {lyric_count} líneas sincronizadas → {lrc_name}")

    print()
    print("  ╭" + "─" * (inner_width - 2) + "╮")
    print("  │  🎉 ALINEACIÓN COMPLETADA SATISFACTORIAMENTE".ljust(inner_width, ' ') + "│")
    print("  ╰" + "─" * (inner_width - 2) + "╯")
    print(f"   📂 Archivo : {lrc_name}")
    print(f"   🎼 Líneas  : {lyric_count} líneas sincronizadas (estructura original respetada)")
    print(f"   ⚡ Método  : Forced Alignment con mapeo de estrofas\n")



if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Titofy — Forced Alignment: sincronizar letra existente con audio",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("audio", help="Ruta al archivo de audio (.mp3, .wav, .m4a, etc.)")
    parser.add_argument("--lyrics", "-t", required=True, help="Ruta al archivo de texto con la letra (.txt)")
    parser.add_argument("--output", "-o", default=None, help="Nombre del archivo .lrc de salida")
    parser.add_argument("--model", "-m", default="base", help="Modelo Whisper a usar (default: base)")
    parser.add_argument("--language", "-l", default="es", help="Código de idioma (default: es)")

    args = parser.parse_args()
    output = args.output or (os.path.splitext(args.audio)[0] + ".lrc")

    with open(args.lyrics, "r", encoding="utf-8") as f:
        lyrics_text = f.read()

    align_lyrics(args.audio, lyrics_text, output, model_name=args.model, language=args.language)
