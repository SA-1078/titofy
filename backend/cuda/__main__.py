# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
Punto de entrada ejecutable para el paquete cuda:
    python -m cuda
"""

from .soporte_para_cuda import detect_device

if __name__ == "__main__":
    dev, name = detect_device()
    print(f"Dispositivo detectado: {dev} ({name})")
