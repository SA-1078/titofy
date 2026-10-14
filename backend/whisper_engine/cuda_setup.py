# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
cuda_setup.py — Detección de dispositivos (CUDA/CPU) y configuración de DLLs en Windows.
"""

import os
import sys
import subprocess
from logger import get_logger

log = get_logger("whisper.cuda")

# Asegurar que la raíz de backend esté en sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

ANSI_YELLOW = "\033[33m"
ANSI_RESET = "\033[0m"


def yellow(text: str) -> str:
    """Devuelve el texto formateado en amarillo ANSI."""
    return f"{ANSI_YELLOW}{text}{ANSI_RESET}"


def print_yellow(text: str) -> None:
    """Imprime texto en amarillo tolerando pipes cerrados."""
    try:
        print(yellow(text))
    except (BrokenPipeError, OSError):
        pass


def setup_cuda_dlls() -> None:
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
    """Detecta automáticamente si hay GPU CUDA disponible y funcional para faster-whisper o PyTorch."""
    setup_cuda_dlls()

    # 1. Priorizar CTranslate2 (motor primario faster-whisper nativo en C++)
    try:
        import ctranslate2
        if ctranslate2.get_cuda_device_count() > 0:
            gpu_name = _get_nvidia_gpu_name()
            return "cuda", gpu_name
    except Exception as exc:
        log.debug(f"CTranslate2 CUDA no disponible: {exc}")

    # 2. Probar PyTorch (si está instalado en entorno dev)
    try:
        import torch
        if torch.cuda.is_available():
            torch.cuda.init()
            if torch.cuda.device_count() > 0:
                _ = torch.zeros(1, device="cuda")
                name = torch.cuda.get_device_name(0)
                return "cuda", name
    except Exception as exc:
        print_yellow(f"  ⚠️  CUDA no disponible o fallo de driver ({exc}). Fallback a CPU.")

    return "cpu", "CPU"
