# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
cuda — Paquete de soporte, detección y configuración de NVIDIA CUDA para Titofy.
"""

from .soporte_para_cuda import (
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
