#!/usr/bin/env python3
# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
whisper_align.py — Wrapper Shim de Compatibilidad
Re-exporta la funcionalidad desde el paquete backend/whisper_engine.
"""

import sys
import os
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from whisper_engine.align import align_lyrics

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
