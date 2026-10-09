#!/usr/bin/env python3
# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
soporte_para_cuda.py — Titofy
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
    os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

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
    Detecta automáticamente si hay GPU CUDA disponible y FUNCIONAL.
    Verifica que el driver responda adecuadamente. Si el usuario cambió o tiene
    problemas con drivers NVIDIA, hace fallback transparente y seguro a CPU
    sin detener la aplicación ni requerir cambios manuales.
    Returns: (device, device_name)
      - ("cuda", "NVIDIA GeForce RTX ...") si GPU y driver están operativos
      - ("cpu", "CPU") si no hay GPU o si el driver falló
    """
    try:
        import torch
        if torch.cuda.is_available():
            torch.cuda.init()
            if torch.cuda.device_count() > 0:
                # Verificación activa con tensor pequeño para garantizar que el driver responde
                _ = torch.zeros(1, device="cuda")
                name = torch.cuda.get_device_name(0)
                return "cuda", name
    except Exception as exc:
        print(f"\033[33m  ⚠️  CUDA/GPU no disponible o fallo en driver ({exc}).\033[0m")
        print("\033[33m     Activando fallback automático a CPU para continuar sin errores.\033[0m")
    return "cpu", "CPU"

