# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
server/process.py — Watchdog de proceso padre y gestión de puertos de red para Titofy API.
"""

import os
import sys
import time
import threading

# Asegurar que backend esté en sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from logger import get_logger

log = get_logger("api.process")


def start_parent_watchdog(parent_pid: int) -> None:
    """Monitorea el proceso padre de Titofy. Si se cierra o desinstala, termina api_server inmediatamente."""
    if parent_pid <= 0:
        return

    if os.name == "nt":
        from windows import start_parent_watchdog as win_watchdog
        win_watchdog(parent_pid)
        return

    def _watch():
        while True:
            time.sleep(1.5)
            try:
                os.kill(parent_pid, 0)
            except Exception:
                log.info(f"Proceso padre {parent_pid} terminó en Linux. Cerrando...")
                os._exit(0)

    t = threading.Thread(target=_watch, daemon=True)
    t.start()


def free_port_if_in_use(port: int) -> None:
    """Mata cualquier proceso huérfano anterior que esté ocupando el puerto para permitir inicio limpio."""
    import socket
    import subprocess

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        in_use = (s.connect_ex(("127.0.0.1", port)) == 0)

    if not in_use:
        return

    log.warning(f"Puerto {port} ocupado por un proceso previo. Liberando...")

    if os.name == "nt":
        from windows import free_port as win_free_port
        win_free_port(port)
        time.sleep(0.4)
        return

    # Linux / Ubuntu nativo
    try:
        subprocess.run(["fuser", "-k", f"{port}/tcp"], capture_output=True)
    except Exception:
        try:
            out = subprocess.check_output(["lsof", "-t", f"-i:{port}"], text=True)
            current_pid = os.getpid()
            for pid_str in out.splitlines():
                pid = int(pid_str.strip())
                if pid != current_pid and pid > 0:
                    os.kill(pid, 9)
        except Exception:
            pass

    time.sleep(0.4)
