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
    Solución de Carga de DLLs para Windows CUDA, cuBLAS, cuDNN y PyAV.
    Agrega directorios binarios de PyInstaller (_MEIPASS), entornos virtuales,
    paquetes locales nvidia y CUDA_PATH al PATH de DLLs de Windows.
    """
    os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

    if os.name == "nt":
        candidates: list[str] = []
        if getattr(sys, "frozen", False):
            base_dir = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
            candidates.append(base_dir)
            candidates.append(os.path.dirname(sys.executable))
        else:
            backend_dir = os.path.dirname(os.path.abspath(__file__))
            candidates.append(backend_dir)

        venv_root = os.path.dirname(os.path.dirname(sys.executable))
        site_packages = os.path.join(venv_root, "Lib", "site-packages")
        if os.path.exists(site_packages):
            candidates.append(site_packages)

        for base in list(candidates):
            for pkg in ["cublas", "cudnn", "cuda_nvrtc", "cuda_runtime"]:
                candidates.append(os.path.join(base, "nvidia", pkg, "bin"))
                candidates.append(os.path.join(base, pkg, "bin"))
                candidates.append(os.path.join(base, "nvidia", pkg))
            candidates.append(os.path.join(base, "av.libs"))

        cuda_path = os.environ.get("CUDA_PATH")
        if cuda_path:
            candidates.append(os.path.join(cuda_path, "bin"))

        for d in dict.fromkeys(os.path.abspath(p) for p in candidates if os.path.isdir(p)):
            try:
                os.add_dll_directory(d)
            except Exception:
                pass
            cur_path = os.environ.get("PATH", "")
            if d not in cur_path:
                os.environ["PATH"] = d + os.pathsep + cur_path


def _get_nvidia_gpu_name() -> str:
    """Intenta obtener el nombre comercial de la GPU mediante nvidia-smi."""
    try:
        import subprocess
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
            text=True,
            timeout=2,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        first_line = out.strip().splitlines()[0]
        if first_line:
            return first_line.strip()
    except Exception:
        pass
    return "NVIDIA CUDA GPU"


def detect_device() -> tuple[str, str]:
    """
    Detecta automáticamente si hay GPU CUDA disponible y FUNCIONAL.
    Prioriza CTranslate2 (faster-whisper) y luego PyTorch si está instalado.
    """
    setup_cuda_dlls()

    try:
        import ctranslate2
        if ctranslate2.get_cuda_device_count() > 0:
            name = _get_nvidia_gpu_name()
            return "cuda", name
    except Exception:
        pass

    try:
        import torch
        if torch.cuda.is_available():
            torch.cuda.init()
            if torch.cuda.device_count() > 0:
                _ = torch.zeros(1, device="cuda")
                name = torch.cuda.get_device_name(0)
                return "cuda", name
    except Exception as exc:
        print(f"\033[33m  ⚠️  CUDA/GPU no disponible o fallo en driver ({exc}).\033[0m")
        print("\033[33m     Activando fallback automático a CPU para continuar sin errores.\033[0m")
    return "cpu", "CPU"

