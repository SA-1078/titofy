# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
normalizer.py — Normalizador de Texto, Limpieza de Puntuación y Fusión de Segmentos.
"""

import re


def normalize_text(text: str) -> str:
    """Normaliza texto para comparación: minúsculas, sin puntuación extra."""
    text = text.lower().strip()
    text = re.sub(r"[¿¡!?,.:;\"'…\-–—]", "", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip()


def clean_intra_repetition(text: str) -> str:
    """
    Detecta y elimina repeticiones dentro de un mismo segmento.
    Ejemplo: 'lo que se fue, lo que se fue, lo que se fue' → 'lo que se fue'
    """
    words = text.split()
    if len(words) < 6:
        return text

    best_phrase = None
    best_count = 1

    for phrase_len in range(2, min(9, len(words) // 2 + 1)):
        phrase = " ".join(words[:phrase_len])
        phrase_lower = phrase.lower().strip(",. ")

        remaining = text.lower()
        count = 0
        pos = 0
        while True:
            idx = remaining.find(phrase_lower, pos)
            if idx == -1:
                break
            count += 1
            pos = idx + len(phrase_lower)

        if count >= 3 and count > best_count:
            coverage = (count * len(phrase_lower)) / len(text.lower())
            if coverage > 0.5:
                best_phrase = phrase.strip(",. ")
                best_count = count

    if best_phrase and best_count >= 3:
        return best_phrase

    return text


def normalize_music_tags(text: str) -> str:
    """Normaliza cualquier etiqueta musical a un formato consistente (música)."""
    stripped = text.strip()
    lower = stripped.lower()

    if any(tag in lower for tag in ["music", "música", "musica"]):
        return "(música)"
    if re.match(r'^[♪♫🎵🎶\s\-–—\.]+$', stripped):
        return "(música)"

    return text


def merge_short_lines(segments: list, min_words: int = 3, max_gap: float = 2.0) -> list:
    """Fusiona líneas incompletas/cortadas con la siguiente si el gap temporal es pequeño."""
    if len(segments) < 2:
        return segments

    merged = []
    skip_next = False

    for i in range(len(segments)):
        if skip_next:
            skip_next = False
            continue

        seg = segments[i]
        text = seg["text"].strip()
        word_count = len(text.split())

        if re.match(r'^\(.*\)$', text):
            merged.append(seg)
            continue

        if word_count < min_words and i + 1 < len(segments):
            next_seg = segments[i + 1]
            next_text = next_seg["text"].strip()

            gap = next_seg["start"] - seg["end"]

            if gap < max_gap and not re.match(r'^\(.*\)$', next_text):
                combined_text = f"{text} {next_text}"
                merged_seg = {
                    "start": seg["start"],
                    "end": next_seg["end"],
                    "text": combined_text,
                }
                if "words" in seg and "words" in next_seg:
                    merged_seg["words"] = seg["words"] + next_seg["words"]

                merged.append(merged_seg)
                skip_next = True
                continue

        merged.append(seg)

    return merged
