#!/usr/bin/env python3
# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
soporte_para_cuda.py — Titofy
Módulo dedicado para la gestión y detección de GPU NVIDIA CUDA y carga de DLLs en Windows.
Delega a whisper_engine.cuda_setup para mantener un único punto de verdad.
"""

import os
import sys

# Asegurar que la raíz de backend esté en sys.path
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from whisper_engine.cuda_setup import (
    setup_cuda_dlls,
    _get_nvidia_gpu_name,
    detect_device,
    print_yellow,
    yellow,
)

__all__ = [
    "setup_cuda_dlls",
    "_get_nvidia_gpu_name",
    "detect_device",
    "print_yellow",
    "yellow",
]

if __name__ == "__main__":
    device, device_name = detect_device()
    print(f"Dispositivo detectado: {device} ({device_name})")
