# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
cleaner.py — Pipeline Principal de Post-procesamiento de Letras.
"""

import re
import argparse
from rapidfuzz import fuzz
from .hallucination import is_hallucination, is_too_short
from .normalizer import normalize_text, clean_intra_repetition, normalize_music_tags, merge_short_lines


def postprocess_segments(segments: list, similarity_threshold: int = 85) -> list:
    """
    Aplica la tubería completa de limpieza sobre la lista de segmentos de Whisper.
    """
    if not segments:
        return []

    # ── Umbral de tiempo para repeticiones legítimas ───────────────────────
    # Si dos segmentos similares están separados por MÁS de este número de segundos,
    # se tratan como repetición real de la canción (estribillo, segunda estrofa, etc.)
    # y NO se eliminan. Solo se borra un duplicado si aparece casi inmediatamente.
    MIN_GAP_FOR_REPEAT = 8.0  # segundos

    # PASO 1: Filtrar alucinaciones y líneas vacías/cortas
    step1 = []
    for seg in segments:
        text = seg.get("text", "").strip()
        if is_hallucination(text) or is_too_short(text):
            continue
        text = clean_intra_repetition(text)
        text = normalize_music_tags(text)
        seg_copy = dict(seg)
        seg_copy["text"] = text
        step1.append(seg_copy)

    # PASO 2: Eliminar duplicados consecutivos exactos (solo si son inmediatos)
    step2 = []
    last_normalized = ""
    last_end = -999.0
    for seg in step1:
        norm = normalize_text(seg["text"])
        gap = seg.get("start", 0) - last_end
        # Solo eliminar duplicados exactos si están muy seguidos en el tiempo
        if norm and norm == last_normalized and gap < MIN_GAP_FOR_REPEAT:
            last_end = seg.get("end", seg.get("start", 0))
            continue
        last_normalized = norm
        last_end = seg.get("end", seg.get("start", 0))
        step2.append(seg)

    # PASO 3: Eliminar duplicados casi idénticos (Fuzzy) con ventana de tiempo
    step3 = []
    for seg in step2:
        if not step3:
            step3.append(seg)
            continue

        prev_seg = step3[-1]
        prev_text = prev_seg["text"]
        curr_text = seg["text"]

        prev_norm = normalize_text(prev_text)
        curr_norm = normalize_text(curr_text)

        if not prev_norm or not curr_norm:
            step3.append(seg)
            continue

        # Calcular separación temporal entre los dos segmentos
        time_gap = seg.get("start", 0) - prev_seg.get("end", prev_seg.get("start", 0))

        ratio = fuzz.ratio(prev_norm, curr_norm)

        # Si están muy separados en el tiempo → repetición legítima de la canción → conservar
        if time_gap >= MIN_GAP_FOR_REPEAT:
            step3.append(seg)
        elif ratio >= similarity_threshold:
            # Duplicado cercano: conservar el más largo
            if len(curr_text) > len(prev_text):
                step3[-1] = seg
        else:
            step3.append(seg)

    # PASO 4: Fusionar líneas incompletas cortas
    step4 = merge_short_lines(step3)

    return step4


def parse_lrc_file(lrc_path: str) -> list:
    """Parsea un archivo .lrc en una lista de diccionarios de segmentos."""
    segments = []
    time_pattern = re.compile(r"^\[(\d+):(\d+(?:\.\d+)?)\](.*)$")

    with open(lrc_path, "r", encoding="utf-8") as f:
        for line in f:
            match = time_pattern.match(line.strip())
            if match:
                mins = float(match.group(1))
                secs = float(match.group(2))
                text = match.group(3).strip()
                start_sec = mins * 60 + secs
                segments.append({"start": start_sec, "end": start_sec + 3.0, "text": text})

    return segments


def segments_to_lrc(segments: list, title: str = "Desconocido", by: str = "Titofy") -> str:
    """Convierte una lista de segmentos en el contenido completo de un archivo .lrc."""
    lines = [
        f"[ti:{title}]",
        f"[by:{by}]",
        "",
    ]
    for seg in segments:
        start = seg["start"]
        mins = int(start // 60)
        secs = start % 60
        ts = f"{mins:02d}:{secs:05.2f}"
        lines.append(f"[{ts}]{seg['text']}")

    return "\n".join(lines)
