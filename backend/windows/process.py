# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
backend/windows/process.py — Titofy
Módulo exclusivo de Windows para gestión de procesos, watchdog Win32 y puertos.
"""

import os
import time
import threading
import subprocess
from logger import get_logger

log = get_logger("windows.process")


def start_parent_watchdog(parent_pid: int) -> None:
    """
    Monitorea el proceso padre de Titofy en Windows usando kernel32.OpenProcess y WaitForSingleObject.
    Si el padre finaliza, termina api_server inmediatamente para no dejar procesos huérfanos.
    """
    if parent_pid <= 0 or os.name != "nt":
        return

    def _watch() -> None:
        import ctypes
        while True:
            time.sleep(1.5)
            try:
                SYNCHRONIZE = 0x00100000
                h = ctypes.windll.kernel32.OpenProcess(SYNCHRONIZE, False, parent_pid)
                if not h:
                    log.info(f"Proceso padre {parent_pid} ya no existe en Windows. Cerrando...")
                    os._exit(0)
                res = ctypes.windll.kernel32.WaitForSingleObject(h, 0)
                ctypes.windll.kernel32.CloseHandle(h)
                if res != 0x00000102:  # 258 = WAIT_TIMEOUT
                    log.info(f"Proceso padre {parent_pid} terminó en Windows. Cerrando...")
                    os._exit(0)
            except Exception:
                log.info(f"Proceso padre {parent_pid} no accesible. Cerrando...")
                os._exit(0)

    t = threading.Thread(target=_watch, daemon=True)
    t.start()


def free_port(port: int) -> None:
    """
    Libera el puerto especificado en Windows buscando con netstat y terminando con taskkill /F.
    """
    if os.name != "nt":
        return

    current_pid = os.getpid()
    try:
        out = subprocess.check_output(f"netstat -ano | findstr :{port}", shell=True, text=True)
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 5 and "LISTENING" in parts:
                pid = int(parts[-1])
                if pid != current_pid and pid > 0:
                    subprocess.run(f"taskkill /F /PID {pid}", shell=True, capture_output=True)
                    log.info(f"Proceso huérfano {pid} en puerto {port} terminado en Windows")
    except Exception:
        pass
