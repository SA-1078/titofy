# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/windows/dll_setup.py — Titofy
Módulo exclusivo de Windows para resolución y registro de DLLs de CUDA, cuDNN y PyAV.
"""

import os
import sys
from logger import get_logger

log = get_logger("windows.dll_setup")


def setup_windows_dlls(backend_dir: str | None = None) -> None:
    """
    Agrega directorios binarios de PyInstaller (_MEIPASS), entornos virtuales,
    paquetes locales nvidia y CUDA_PATH al PATH de DLLs de Windows con os.add_dll_directory.
    """
    if os.name != "nt":
        return

    os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

    if backend_dir is None:
        backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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
