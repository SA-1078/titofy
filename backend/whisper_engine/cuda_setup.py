# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
cuda_setup.py — Detección de dispositivos (CUDA/CPU) y configuración de DLLs en Windows.
Re-exporta directamente desde el paquete backend/cuda.
"""

import os
import sys

# Asegurar que la raíz de backend esté en sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from cuda import (
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
