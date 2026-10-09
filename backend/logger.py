# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
logger.py — Titofy
Sistema de logging profesional con niveles y salida a archivo.

Uso:
    from logger import get_logger
    log = get_logger("whisper")
    log.info("Transcripción iniciada")
    log.warn("Segmento sospechoso")
    log.error("Fallo al cargar modelo")
"""

import logging
import os
import sys
from datetime import datetime


# Cache de loggers ya configurados
_configured_loggers = set()


class SafeStream:
    """Envuelve sys.stdout / sys.stderr para absorber BrokenPipeError y OSError en procesos huérfanos o cerrados."""
    def __init__(self, target):
        self._target = target

    def write(self, s):
        try:
            return self._target.write(s)
        except (BrokenPipeError, OSError):
            return len(s) if hasattr(s, "__len__") else 0

    def flush(self):
        try:
            return self._target.flush()
        except (BrokenPipeError, OSError):
            pass

    def isatty(self):
        try:
            return self._target.isatty()
        except Exception:
            return False

    def fileno(self):
        try:
            return self._target.fileno()
        except Exception:
            raise OSError("No fileno on safe stream")

    def __getattr__(self, name):
        return getattr(self._target, name)


# Proteger streams estándar globalmente
if not isinstance(sys.stdout, SafeStream):
    sys.stdout = SafeStream(sys.stdout)
if not isinstance(sys.stderr, SafeStream):
    sys.stderr = SafeStream(sys.stderr)


class SafeStreamHandler(logging.StreamHandler):
    """Handler que no crashea con emojis en Windows cp1252 ni con BrokenPipe en Linux."""

    def emit(self, record):
        try:
            msg = self.format(record)
            stream = self.stream
            try:
                stream.write(msg + self.terminator)
            except (BrokenPipeError, OSError):
                return
            except UnicodeEncodeError:
                try:
                    stream.write(msg.encode("ascii", errors="replace").decode("ascii") + self.terminator)
                except (BrokenPipeError, OSError):
                    return
            try:
                self.flush()
            except (BrokenPipeError, OSError):
                pass
        except Exception:
            pass  # Nunca propagar error de logging en consola


def get_logger(
    name: str,
    level: str | None = None,
    to_file: bool | None = None,
    log_dir: str | None = None,
) -> logging.Logger:
    """
    Crea o retorna un logger configurado.

    Args:
        name: Nombre del módulo (ej: "whisper", "postprocess", "api")
        level: Nivel de logging (DEBUG, INFO, WARNING, ERROR). Si None, lee de config.
        to_file: Si guardar en archivo. Si None, lee de config.
        log_dir: Directorio de logs. Si None, lee de config.
    """
    logger = logging.getLogger(f"titofy.{name}")

    # Evitar re-configurar si ya fue configurado
    if name in _configured_loggers:
        return logger

    # Leer config si no se proveen parámetros explícitos
    if level is None or to_file is None or log_dir is None:
        try:
            from lyric_config import get_config
            cfg = get_config().get("logging", {})
        except ImportError:
            cfg = {}

        if level is None:
            level = cfg.get("level") or "INFO"
        if to_file is None:
            to_file = bool(cfg.get("to_file", True))
        if log_dir is None:
            log_dir = cfg.get("log_dir") or "logs"

    # Garantizar strings válidos
    safe_level = (level or "INFO").strip()
    safe_log_dir = (log_dir or "logs").strip()

    # Mapear nivel
    level_map = {
        "DEBUG": logging.DEBUG,
        "INFO": logging.INFO,
        "WARN": logging.WARNING,
        "WARNING": logging.WARNING,
        "ERROR": logging.ERROR,
    }
    log_level = level_map.get(safe_level.upper(), logging.INFO)
    logger.setLevel(log_level)

    # Formato rico
    fmt = logging.Formatter(
        "%(asctime)s │ %(levelname)-5s │ %(name)s │ %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # Console handler (Solo mostrar WARNING/ERROR en consola; INFO va al archivo de log)
    console_level = logging.WARNING
    if os.getenv("VERBOSE", "0") in ("1", "true", "True") or os.getenv("TITOFY_VERBOSE", "0") in ("1", "true", "True"):
        console_level = log_level

    ch = SafeStreamHandler(sys.stdout)
    ch.setLevel(console_level)
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    # File handler (guarda absolutamente TODOS los logs DEBUG/INFO/WARN/ERROR en archivo)
    if to_file:
        try:
            project_dir = os.path.dirname(sys.executable) if getattr(sys, "frozen", False) else os.path.dirname(os.path.abspath(__file__))
            full_log_dir = os.path.join(project_dir, safe_log_dir)
            os.makedirs(full_log_dir, exist_ok=True)

            log_file = os.path.join(full_log_dir, f"titofy-{datetime.now().strftime('%Y-%m-%d')}.log")
            fh = logging.FileHandler(log_file, encoding="utf-8")
            fh.setLevel(logging.DEBUG)
            fh.setFormatter(fmt)
            logger.addHandler(fh)
        except Exception:
            pass  # Si falla el file handler, continuar solo con console

    # Evitar propagación al logger raíz (evita duplicados)
    logger.propagate = False

    _configured_loggers.add(name)
    return logger
