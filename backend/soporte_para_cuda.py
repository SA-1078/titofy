#!/usr/bin/env python3
"""
soporte_para_cuda.py — Titofy CMD
Módulo dedicado para la gestión y detección de GPU NVIDIA CUDA y carga de DLLs en Windows.
"""

import os
import sys

def setup_cuda_dlls():
    """
    Solución de Carga de DLLs para Windows CUDA y PyAV (Python 3.8+)
    Agrega los directorios binarios de las dependencias nvidia y PyAV locales de la venv
    o del sistema al PATH de DLLs de Windows.
    """
    if os.name == "nt":
        # 1. Obtener la raíz del entorno virtual (.venv)
        venv_root = os.path.dirname(os.path.dirname(sys.executable))
        site_packages = os.path.join(venv_root, "Lib", "site-packages")

        if os.path.exists(site_packages):
            # 2. Agregar paths de bibliotecas nvidia locales de la venv
            for pkg in ["cublas", "cudnn", "cuda_nvrtc", "cuda_runtime"]:
                bin_dir = os.path.join(site_packages, "nvidia", pkg, "bin")
                if os.path.exists(bin_dir):
                    try:
                        os.add_dll_directory(bin_dir)
                    except Exception:
                        pass

            # 3. Agregar path de PyAV (av.libs)
            av_libs = os.path.join(site_packages, "av.libs")
            if os.path.exists(av_libs):
                try:
                    os.add_dll_directory(av_libs)
                except Exception:
                    pass

        # 4. Agregar paths de CUDA en el sistema si existen
        cuda_path = os.environ.get("CUDA_PATH")
        if cuda_path:
            bin_dir = os.path.join(cuda_path, "bin")
            if os.path.exists(bin_dir):
                try:
                    os.add_dll_directory(bin_dir)
                except Exception:
                    pass


def detect_device() -> tuple[str, str]:
    """
    Detecta automáticamente si hay GPU CUDA disponible.
    Returns: (device, device_name)
      - ("cuda", "NVIDIA GeForce RTX ...") si hay GPU
      - ("cpu", "CPU") si no hay GPU
    """
    try:
        import torch
        if torch.cuda.is_available():
            name = torch.cuda.get_device_name(0)
            return "cuda", name
    except Exception as exc:
        print(f"\033[33m  ⚠️  CUDA no se pudo inicializar correctamente: {exc}\033[0m")
        print("\033[33m     Se usara CPU para continuar sin detener el programa.\033[0m")
    return "cpu", "CPU"
