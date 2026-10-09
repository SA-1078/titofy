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


def _safe_print(*args: typing.Any, **kwargs: typing.Any) -> None:
    try:
        print(*args, **kwargs)
    except (BrokenPipeError, OSError):
        pass


def _clean_token(token: str) -> str:
    """Normaliza una palabra para matching ignorando signos de puntuación y mayúsculas."""
    return re.sub(r"[^\w]", "", token.lower())


def _get_w_val(w: typing.Any, key: str, default: typing.Any = None) -> typing.Any:
    """Extrae valores de forma segura ya sea un dict o un objeto WordTiming de stable_whisper."""
    if isinstance(w, dict):
        return w.get(key, default)
    return getattr(w, key, default)


def map_words_to_original_lines(original_lines: list[str], words: list[typing.Any]) -> list[str]:
    """
    Asigna a cada línea original de la letra su marca de tiempo exacta basándose
    en los timestamps de las palabras reconocidas acústicamente por Whisper.
    Preserva intacta la estructura de estrofas y versos del texto original,
    manejando limpiamente intros instrumentales y diálogos de videos musicales.
    """
    mapped_lrc: list[str] = []
    total_words = len(words)
    if not words or not original_lines:
        return mapped_lrc

    # 1. Recolectar versos y tokens
    valid_lines: list[str] = []
    line_token_list: list[list[str]] = []
    for line in original_lines:
        line_strip = line.strip()
        if not line_strip:
            continue
        tokens = [_clean_token(t) for t in line_strip.split() if _clean_token(t)]
        if not tokens:
            continue
        valid_lines.append(line_strip)
        line_token_list.append(tokens)

    if not valid_lines:
        return mapped_lrc

    # Extraer tokens limpios de las palabras reconocidas y sus timestamps
    clean_words: list[str] = [_clean_token(str(_get_w_val(w, "word", ""))) for w in words]
    word_starts: list[float] = [float(_get_w_val(w, "start", 0.0)) for w in words]

    line_timestamps: list[float | None] = [None] * len(valid_lines)
    w_cursor = 0

    # 2. Emparejar cada verso secuencialmente contra las palabras reconocidas por Whisper
    for line_idx, tokens in enumerate(line_token_list):
        if not tokens:
            continue

        best_match_start: float | None = None
        best_match_end_idx: int = -1
        best_match_score = 0.0

        # Ventana de búsqueda hacia adelante generosa (hasta 250 palabras)
        search_window_end = min(total_words, w_cursor + 250)
        t_len = len(tokens)

        for s_idx in range(w_cursor, max(w_cursor + 1, search_window_end - t_len + 1)):
            matches = 0
            for t_offset, token in enumerate(tokens):
                check_idx = s_idx + t_offset
                if check_idx < total_words and clean_words[check_idx] == token:
                    matches += 1

            score = matches / t_len
            min_score = 0.4 if t_len >= 3 else 0.8
            if score >= min_score and score > best_match_score:
                best_match_score = score
                best_match_start = word_starts[s_idx]
                best_match_end_idx = min(total_words - 1, s_idx + t_len)
                if score >= 0.95:
                    break

        if best_match_start is not None and best_match_score >= 0.4:
            line_timestamps[line_idx] = best_match_start
            w_cursor = max(w_cursor, best_match_end_idx)

    # 3. Interpolar marcas de tiempo
    anchors = [(idx, ts) for idx, ts in enumerate(line_timestamps) if ts is not None]
    resolved_ts: list[float] = [0.0] * len(valid_lines)

    if not anchors:
        for i in range(len(valid_lines)):
            resolved_ts[i] = i * 2.5
    else:
        first_anchor_idx, first_anchor_ts = anchors[0]

        # Rellenar antes de la primera ancla (sin retroceder a 0 si hay intro)
        resolved_ts[first_anchor_idx] = first_anchor_ts
        if first_anchor_idx > 0:
            step = 2.0
            for i in range(first_anchor_idx - 1, -1, -1):
                resolved_ts[i] = max(first_anchor_ts - ((first_anchor_idx - i) * step), 0.0)

        # Rellenar entre anclas consecutivas
        for a_curr, a_next in zip(anchors[:-1], anchors[1:]):
            idx_a, ts_a = a_curr
            idx_b, ts_b = a_next
            resolved_ts[idx_a] = ts_a
            resolved_ts[idx_b] = ts_b
            count = idx_b - idx_a - 1
            if count > 0:
                step = (ts_b - ts_a) / (count + 1)
                for step_i, i in enumerate(range(idx_a + 1, idx_b), 1):
                    resolved_ts[i] = ts_a + (step * step_i)

        # Rellenar después de la última ancla
        last_idx, last_ts = anchors[-1]
        resolved_ts[last_idx] = last_ts
        for i in range(last_idx + 1, len(valid_lines)):
            resolved_ts[i] = resolved_ts[i - 1] + 2.5

    # 4. Si la primera voz empieza tarde (intro instrumental/videoclip > 6s), insertar marcador (intro)
    earliest_vocal = resolved_ts[0] if resolved_ts else 0.0
    if earliest_vocal >= 6.0:
        mapped_lrc.append("[00:00.00](intro)")

    # 5. Asegurar monotonicidad estricta
    for i in range(1, len(resolved_ts)):
        if resolved_ts[i] <= resolved_ts[i - 1]:
            resolved_ts[i] = resolved_ts[i - 1] + 0.8

    for line_text, ts in zip(valid_lines, resolved_ts):
        ts_str = to_lrc_timestamp(ts)
        mapped_lrc.append(f"[{ts_str}]{line_text}")

    return mapped_lrc



def _align_with_model(model_instance: typing.Any, audio: str, text: str, lang: str) -> typing.Any:
    """Invoca el método align de stable_whisper de forma segura y tipada para linters estáticos."""
    align_func: typing.Callable[..., typing.Any] = getattr(model_instance, "align")
    return align_func(audio, text, language=lang)


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
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio no encontrado: {audio_path}")
    if not lyrics_text or not lyrics_text.strip():
        raise ValueError("Texto de letra vacío para alineación")

    output_path = os.path.abspath(output_path)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    setup_cuda_dlls()
    cfg = get_config()

    basename = os.path.basename(audio_path)
    lrc_name = os.path.basename(output_path)

    term_width = shutil.get_terminal_size((100, 20)).columns
    inner_width = min(max(term_width - 6, 60), 140)

    _safe_print()
    _safe_print("  ╭" + "─" * (inner_width - 2) + "╮")
    _safe_print("  │  🎯 FORCED ALIGNMENT — SINCRONIZACIÓN CON LETRA EXISTENTE".ljust(inner_width, ' ') + "│")
    _safe_print("  ╰" + "─" * (inner_width - 2) + "╯")
    _safe_print()
    _safe_print(f"  💿 Archivo  : {basename}")

    duration = validate_audio_file(audio_path)
    size_mb = os.path.getsize(audio_path) / (1024 * 1024)
    line_count = len([l for l in lyrics_text.strip().split("\n") if l.strip()])

    _safe_print(f"  📦 Tamaño   : {size_mb:.2f} MB")
    if duration:
        _safe_print(f"  ⏱️ Duración : {duration:.2f} s")
    _safe_print(f"  🤖 Modelo   : {model_name} (alineación)")
    _safe_print(f"  🌐 Idioma   : {language}")
    _safe_print(f"  📝 Líneas   : {line_count} líneas de letra")
    _safe_print(f"  📂 Salida   : {lrc_name}")
    _safe_print("  " + "─" * inner_width)
    _safe_print()

    device, device_name = detect_device()
    if device == "cuda":
        _safe_print(f"  🚀 GPU       : {device_name}")
    else:
        try:
            print_yellow("  ⚠️  GPU CUDA no detectada; usando CPU como fallback seguro.")
        except Exception:
            pass

    wcfg = cfg.get("whisper", {})
    compute_type = wcfg.get("compute_type", "auto")

    log.info(f"Cargando modelo '{model_name}' en {device} para alineación...")
    try:
        model, _ = load_whisper_model(model_name, device=device, compute_type=compute_type)
    except Exception as exc:
        log.warning(f"Fallo al cargar faster-whisper ({exc}). Intentando con stable_whisper directo...")
        try:
            import stable_whisper
            model = stable_whisper.load_model(model_name, device=device)
        except Exception as exc_sw:
            raise RuntimeError(f"Error al cargar modelo de alineación: {exc_sw}")

    log.info("Analizando acústica del audio con Whisper para capturar inicio real del canto...")
    _safe_print("  🎙️ Escuchando audio y detectando inicio real de la voz...")

    result: typing.Any = None
    try:
        # 1. Transcripción acústica real: identifica exactamente en qué segundo comienza el canto
        result = model.transcribe(audio_path, language=language)
    except Exception as e_trans:
        log.warning(f"Transcripción directa con {device} falló ({e_trans}). Intentando alineación forzada clásica...")
        try:
            result = _align_with_model(model, audio_path, lyrics_text, language)
        except Exception as e:
            if device == "cuda":
                log.warning(f"Fallo en alineación GPU ({e}). Reintentando con CPU...")
                try:
                    model_cpu, _ = load_whisper_model(model_name, device="cpu", compute_type="int8")
                    result = _align_with_model(model_cpu, audio_path, lyrics_text, language)
                except Exception as e_cpu:
                    log.error(f"Fallo definitivo en CPU: {e_cpu}")
                    raise RuntimeError(f"Fallo en alineación con audio: {e_cpu}")
            else:
                log.error(f"Fallo en alineación: {e}")
                raise RuntimeError(f"Fallo en alineación con audio: {e}")

    segments = []
    if hasattr(result, "to_dict"):
        segments = result.to_dict().get("segments", [])
    elif isinstance(result, tuple) and len(result) == 2:
        segments_gen, _ = result
        for s in segments_gen:
            words = []
            if hasattr(s, "words") and s.words:
                for w in s.words:
                    words.append({
                        "word": getattr(w, "word", ""),
                        "start": getattr(w, "start", 0.0),
                        "end": getattr(w, "end", 0.0),
                    })
            segments.append({
                "start": getattr(s, "start", 0.0),
                "end": getattr(s, "end", 0.0),
                "text": getattr(s, "text", ""),
                "words": words,
            })
    elif isinstance(result, dict):
        segments = result.get("segments", [])

    # Extraer todas las palabras reconocidas con timestamps reales
    all_words: list[dict[str, typing.Any]] = []
    for seg in segments:
        seg_words = seg.get("words", [])
        if seg_words:
            for w in seg_words:
                all_words.append(w)
        else:
            seg_text = seg.get("text", "").strip()
            s_start = float(seg.get("start", 0.0))
            s_end = float(seg.get("end", s_start + 2.0))
            tokens = seg_text.split()
            if tokens:
                step = (s_end - s_start) / max(len(tokens), 1)
                for idx, t in enumerate(tokens):
                    all_words.append({
                        "word": t,
                        "start": s_start + (step * idx),
                        "end": s_start + (step * (idx + 1)),
                        "probability": 0.9,
                    })

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

    _safe_print()
    _safe_print("  ╭" + "─" * (inner_width - 2) + "╮")
    _safe_print("  │  🎉 ALINEACIÓN COMPLETADA SATISFACTORIAMENTE".ljust(inner_width, ' ') + "│")
    _safe_print("  ╰" + "─" * (inner_width - 2) + "╯")
    _safe_print(f"   📂 Archivo : {lrc_name}")
    _safe_print(f"   🎼 Líneas  : {lyric_count} líneas sincronizadas (estructura original respetada)")
    _safe_print(f"   ⚡ Método  : Forced Alignment con mapeo de estrofas\n")



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
