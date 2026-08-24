#!/usr/bin/env python3
# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
whisper_transcribe.py — Wrapper Shim de Compatibilidad
Re-exporta la funcionalidad desde el paquete backend/whisper_engine.
"""

import sys
import os
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from whisper_engine.transcribe import transcribe_audio
from whisper_engine.loader import load_whisper_model, is_model_downloaded, detect_device, setup_cuda_dlls, validate_audio_file, print_yellow

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
    parser.add_argument("--force", action="store_true", help="Forzar regeneracion (LRC previo borrado + cache limpia)")

    args = parser.parse_args()
    transcribe_audio(args.audio, args.output, args.model, args.language, args.words)
