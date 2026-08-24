# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
formatter.py — Formateador de Timestamps LRC y Calculador de Calidad.
"""

import re


def to_lrc_timestamp(seconds: float) -> str:
    """Convierte segundos a formato LRC [MM:SS.xx]"""
    minutes = int(seconds // 60)
    secs = seconds % 60
    return f"{minutes:02d}:{secs:05.2f}"


def clean_text(text: str, lang: str = "auto") -> str:
    """
    Limpia el texto transcrito:
    - Normaliza marcadores a "(música)"
    - Elimina caracteres asiáticos/rusos si el idioma es español/inglés.
    """
    music_tags = r"(?i)(\[\s*music\s*\]|\(\s*música\s*\)|\[\s*música\s*\]|\bMúsica\b|\bMusica\b|♪)"
    text = re.sub(music_tags, "(música)", text)

    text = re.sub(
        r'\(música\)\s*'
        r'(de\s+cierre|instrumental|de\s+fondo|de\s+salida|de\s+entrada'
        r'|de\s+intro|de\s+outro|de\s+apertura|de\s+transición'
        r'|suave|lenta|rápida|alegre|triste)'
        r'[.!,;]*',
        '(música)',
        text,
        flags=re.IGNORECASE
    )

    music_residual = re.match(r'^\s*\(música\)\s+(.{1,20})\s*$', text, re.IGNORECASE)
    if music_residual:
        residual = music_residual.group(1).strip().rstrip('.')
        residual_words = residual.split()
        if len(residual_words) <= 3:
            text = '(música)'

    text = re.sub(r"\[(?!\s*música\s*).*?\]", "", text, flags=re.IGNORECASE)

    if lang in ["es", "en", "pt", "fr", "it", "de", "auto"]:
        text = re.sub(r"[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff]", "", text)

    text = re.sub(r"\s+", " ", text).strip()
    return text


def split_long_segment(text: str, start: float, end: float, max_chars: int = 42) -> list[tuple[float, str]]:
    """Divide segmentos largos en sub-líneas sincronizadas por interpolación."""
    if len(text) <= max_chars or "," not in text and "." not in text and " y " not in text:
        return [(start, text)]

    parts = re.split(r"(?<=[,.])\s+", text)
    if len(parts) <= 1:
        return [(start, text)]

    total_len = sum(len(p) for p in parts)
    duration = end - start
    result = []
    curr_time = start

    for part in parts:
        part = part.strip()
        if not part:
            continue
        fraction = len(part) / total_len if total_len > 0 else 1 / len(parts)
        result.append((curr_time, part))
        curr_time += duration * fraction

    return result


def estimate_transcription_quality(segments: list, audio_duration: float | None = None) -> dict:
    """Calcula métricas objetivas de confianza y calidad de la transcripción."""
    if not segments:
        return {
            "overall_score": 0,
            "avg_probability": 0.0,
            "low_confidence_segments": 0,
            "low_confidence_pct": 0,
            "coverage_pct": 0,
        }

    probs = []
    low_conf_count = 0

    for seg in segments:
        words = seg.get("words", [])
        if words:
            word_probs = [w.get("probability", 1.0) for w in words if "probability" in w]
            seg_prob = sum(word_probs) / len(word_probs) if word_probs else 0.8
        else:
            seg_prob = seg.get("probability", 0.8)

        probs.append(seg_prob)
        if seg_prob < 0.6:
            low_conf_count += 1

    avg_prob = sum(probs) / len(probs) if probs else 0.0
    low_conf_pct = round((low_conf_count / len(segments)) * 100)

    score = int(avg_prob * 100)
    score -= min(30, low_conf_pct // 2)

    if audio_duration and audio_duration > 0 and segments:
        last_end = segments[-1].get("end", 0)
        coverage = min(100, int((last_end / audio_duration) * 100))
    else:
        coverage = 100

    return {
        "overall_score": max(0, min(100, score)),
        "avg_probability": round(avg_prob, 2),
        "low_confidence_segments": low_conf_count,
        "low_confidence_pct": low_conf_pct,
        "coverage_pct": coverage,
    }
