#!/usr/bin/env python3
# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
lyrics_postprocess.py — Wrapper Shim de Compatibilidad
Re-exporta la funcionalidad desde el paquete backend/postprocess.
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from postprocess.cleaner import postprocess_segments, parse_lrc_file, segments_to_lrc

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Titofy — Limpiador de transcripciones")
    parser.add_argument("input", help="Archivo .lrc a limpiar")
    parser.add_argument("--output", "-o", default=None, help="Archivo de salida (default: sobreescribe)")
    parser.add_argument("--threshold", "-t", type=int, default=85, help="Umbral de similitud 0-100 para detectar duplicados")
    args = parser.parse_args()

    print(f"\n🧹 Titofy — Limpiador de letras")
    print(f"{'─' * 45}")
    print(f"📄 Entrada: {args.input}")

    segments = parse_lrc_file(args.input)
    if not segments:
        print("❌ No se encontraron segmentos.")
        sys.exit(1)

    clean = postprocess_segments(segments, args.threshold)
    output = args.output or args.input
    title = os.path.splitext(os.path.basename(args.input))[0]
    lrc_content = segments_to_lrc(clean, title, "Titofy — post-procesado")

    with open(output, "w", encoding="utf-8") as f:
        f.write(lrc_content)

    print(f"\n✅ Guardado en: {output}\n")
