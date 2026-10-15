# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
cache.py — Gestión de caché de Hugging Face y modelos Whisper, verificación de pesos y auto-reparación.
"""

import os
import sys
import shutil
import time

# Asegurar que la raíz de backend esté en sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from logger import get_logger
log = get_logger("whisper.cache")

_repair_failures: dict[str, float] = {}
_REPAIR_RETRY_SECONDS = 60.0


def _huggingface_cache_dirs() -> list[str]:
    """Obtiene todas las ubicaciones de caché que puede usar HuggingFace en Windows."""
    dirs: list[str] = []
    for env_name in ("HUGGINGFACE_HUB_CACHE", "HF_HUB_CACHE", "HF_HOME", "TRANSFORMERS_CACHE"):
        value = os.environ.get(env_name)
        if value:
            dirs.append(os.path.join(value, "hub") if env_name == "HF_HOME" else value)
    try:
        from huggingface_hub.constants import HUGGINGFACE_HUB_CACHE
        dirs.append(HUGGINGFACE_HUB_CACHE)
    except Exception:
        pass
    dirs.append(os.path.join(os.path.expanduser("~"), ".cache", "huggingface", "hub"))
    if os.name == "nt":
        local_appdata = os.environ.get("LOCALAPPDATA")
        if local_appdata:
            dirs.append(os.path.join(local_appdata, "huggingface", "hub"))
    return list(dict.fromkeys(os.path.abspath(d) for d in dirs))


def _faster_whisper_cache_folders(model_name: str) -> list[str]:
    """Devuelve repositorios conocidos para un alias de faster-whisper."""
    if model_name in ("turbo", "large-v3-turbo"):
        return [
            "models--mobiuslabsgmbh--faster-whisper-large-v3-turbo",
            "models--deepdml--faster-whisper-large-v3-turbo-ct2",
        ]
    if model_name == "large-v3":
        return ["models--Systran--faster-whisper-large-v3"]
    return [f"models--Systran--faster-whisper-{model_name}"]


def _snapshot_has_weights(snapshot_path: str) -> bool:
    """Verifica si un snapshot de faster-whisper contiene model.bin con pesos válidos (> 10MB)."""
    try:
        bin_path = os.path.join(snapshot_path, "model.bin")
        if not (os.path.exists(bin_path) or os.path.lexists(bin_path)):
            return False

        candidate_paths = [bin_path]

        # 1. Resolver enlace simbólico relativo si existe (típico de HuggingFace en Windows)
        try:
            if os.path.islink(bin_path):
                link_target = os.readlink(bin_path)
                if not os.path.isabs(link_target):
                    candidate_paths.append(os.path.normpath(os.path.join(snapshot_path, link_target)))
                else:
                    candidate_paths.append(link_target)
        except Exception:
            pass

        try:
            real_path = os.path.realpath(bin_path)
            candidate_paths.append(real_path)
        except Exception:
            pass

        # 2. Verificar tamaño > 10MB en cualquiera de las rutas candidatas
        for path_to_check in dict.fromkeys(candidate_paths):
            try:
                if os.path.isfile(path_to_check):
                    size = os.path.getsize(path_to_check)
                    if size > 10 * 1024 * 1024:
                        return True
            except OSError:
                pass

        # 3. Apertura binaria directa para sortear particularidades de reparse points en NTFS
        try:
            with open(bin_path, "rb") as f:
                f.seek(0, os.SEEK_END)
                if f.tell() > 10 * 1024 * 1024:
                    return True
        except (OSError, PermissionError):
            pass

        # 4. En Windows NTFS: si model.bin existe en el snapshot y la carpeta blobs/ tiene el archivo > 10MB
        model_repo_dir = os.path.dirname(os.path.dirname(snapshot_path))
        blobs_dir = os.path.join(model_repo_dir, "blobs")
        if os.path.isdir(blobs_dir):
            try:
                for blob_name in os.listdir(blobs_dir):
                    blob_file = os.path.join(blobs_dir, blob_name)
                    if os.path.isfile(blob_file) and not blob_name.endswith((".incomplete", ".tmp")):
                        if os.path.getsize(blob_file) > 10 * 1024 * 1024:
                            return True
            except OSError:
                pass

        return False
    except Exception:
        return False


def _clear_incomplete_faster_cache(model_name: str) -> None:
    """Quita únicamente snapshots vacíos o corruptos sin destruir la carpeta de blobs."""
    for cache_dir in _huggingface_cache_dirs():
        for folder in _faster_whisper_cache_folders(model_name):
            model_folder_path = os.path.join(cache_dir, folder)
            snapshots_dir = os.path.join(model_folder_path, "snapshots")
            if not os.path.isdir(snapshots_dir):
                continue
            try:
                snapshots = [
                    os.path.join(snapshots_dir, entry)
                    for entry in os.listdir(snapshots_dir)
                    if os.path.isdir(os.path.join(snapshots_dir, entry))
                ]
                for snapshot in snapshots:
                    if not _snapshot_has_weights(snapshot):
                        # Si tiene archivos temporales de descarga activa, no interrumpir
                        has_temp = False
                        try:
                            has_temp = any(
                                f.endswith(".incomplete") or f.endswith(".tmp") or f.startswith("tmp")
                                for f in os.listdir(snapshot)
                            )
                        except OSError:
                            pass
                        if not has_temp:
                            log.warning(f"Snapshot Whisper incompleto detectado; limpiando snapshot: {snapshot}")
                            shutil.rmtree(snapshot, ignore_errors=True)
            except OSError as exc:
                log.warning(f"No se pudo reparar la caché Whisper '{snapshots_dir}': {exc}")


def _materialize_snapshot_symlinks(snapshot_path: str) -> None:
    """En Windows, CTranslate2 (C++) no puede abrir enlaces simbólicos relativos de HuggingFace
    sin Developer Mode o privilegios de Administrador.
    Reemplaza cualquier enlace simbólico en el snapshot con un HardLink nativo de NTFS
    hacia el blob real (mismo inode, 0 bytes de espacio adicional).
    """
    if os.name != "nt" or not os.path.isdir(snapshot_path):
        return

    try:
        for entry in os.listdir(snapshot_path):
            file_path = os.path.join(snapshot_path, entry)
            if os.path.islink(file_path):
                try:
                    real_target = os.path.realpath(file_path)
                    if os.path.isfile(real_target) and os.path.getsize(real_target) > 0:
                        os.remove(file_path)
                        try:
                            os.link(real_target, file_path)
                            log.info(f"Enlace '{entry}' materializado a HardLink NTFS hacia '{real_target}'")
                        except OSError:
                            shutil.copy2(real_target, file_path)
                            log.info(f"Enlace '{entry}' copiado como archivo real hacia '{file_path}'")
                except Exception as exc:
                    log.warning(f"No se pudo materializar enlace '{file_path}': {exc}")
    except Exception as exc:
        log.warning(f"Error inspeccionando enlaces en snapshot '{snapshot_path}': {exc}")


def _find_complete_faster_snapshot(model_name: str) -> str | None:
    """Retorna la ruta exacta de un snapshot usable por CTranslate2."""
    for cache_dir in _huggingface_cache_dirs():
        for folder in _faster_whisper_cache_folders(model_name):
            snapshots_dir = os.path.join(cache_dir, folder, "snapshots")
            if not os.path.isdir(snapshots_dir):
                continue
            try:
                for entry in os.listdir(snapshots_dir):
                    snapshot = os.path.join(snapshots_dir, entry)
                    if os.path.isdir(snapshot) and _snapshot_has_weights(snapshot):
                        _materialize_snapshot_symlinks(snapshot)
                        return snapshot
            except OSError:
                continue
    return None


def _model_repo_ids(model_name: str) -> list[str]:
    """Repositorios HuggingFace oficiales/compatibles para el alias solicitado."""
    if model_name == "large-v3":
        return ["Systran/faster-whisper-large-v3"]
    if model_name in ("turbo", "large-v3-turbo"):
        return [
            "mobiuslabsgmbh/faster-whisper-large-v3-turbo",
            "deepdml/faster-whisper-large-v3-turbo-ct2",
        ]
    return [f"Systran/faster-whisper-{model_name}"]


def is_model_downloaded(model_name: str, use_faster: bool = True) -> bool:
    """Verifica si el modelo Whisper ya está en la caché local con pesos completos."""
    try:
        from lyric_config import get_config
        cfg = get_config()
        if model_name in ["turbo", "large-v3-turbo"] and cfg.get("whisper", {}).get("use_large_v3_for_pro", False):
            model_name = "large-v3"
    except Exception:
        pass

    std_name = "turbo" if model_name in ["turbo", "large-v3-turbo"] else model_name

    if use_faster:
        if _find_complete_faster_snapshot(model_name):
            return True

        # No declarar listo un .pt de OpenAI Whisper cuando el runtime
        # productivo va a intentar cargar faster-whisper/CTranslate2. Esas
        # cachés son formatos distintos y provocan el falso positivo que deja
        # pasar un modelo sin model.bin hasta la fase de alineación.
        try:
            import faster_whisper  # noqa: F401
            return False
        except ImportError:
            pass

    import importlib
    download_root = os.getenv(
        "XDG_CACHE_HOME",
        os.path.join(os.path.expanduser("~"), ".cache", "whisper")
    )

    try:
        openai_whisper = importlib.import_module("whisper")
        url = openai_whisper._MODELS.get(std_name)
    except Exception:
        return False

    if not url:
        return False

    expected_filename = url.split("/")[-1]
    model_path = os.path.join(download_root, expected_filename)
    return os.path.exists(model_path) and os.path.getsize(model_path) > 10 * 1024 * 1024


def fix_loader(model_name: str) -> str | None:
    """Repara o descarga un modelo faster-whisper antes de cargarlo.

    Retorna la ruta del snapshot únicamente cuando contiene model.bin (> 10MB).
    La reparación es deliberadamente limitada a snapshots incompletos; no
    borra modelos válidos ni otros archivos de la caché del usuario.
    """
    existing_snapshot = _find_complete_faster_snapshot(model_name)
    if existing_snapshot:
        return existing_snapshot

    _clear_incomplete_faster_cache(model_name)

    try:
        from huggingface_hub import snapshot_download
    except ImportError as exc:
        log.warning(f"huggingface_hub no está disponible para descargar '{model_name}': {exc}")
        return None

    cache_dirs = _huggingface_cache_dirs()
    # Preferir la caché configurada por HF; si no existe, usar la primera
    # ubicación estándar. snapshot_download crea el árbol necesario.
    cache_dir = cache_dirs[0] if cache_dirs else None
    last_failure = _repair_failures.get(model_name)
    if last_failure and time.monotonic() - last_failure < _REPAIR_RETRY_SECONDS:
        log.warning(f"Se omite nueva descarga de '{model_name}': fallo de reparación reciente")
        return None

    last_error: Exception | None = None
    for repo_id in _model_repo_ids(model_name):
        try:
            log.info(f"Modelo '{model_name}' no está completo. Descargando pesos desde {repo_id}...")
            downloaded_snapshot = snapshot_download(
                repo_id=repo_id,
                cache_dir=cache_dir,
                local_files_only=False,
                max_workers=2,
                force_download=False,
                resume_download=True,
            )
            if _snapshot_has_weights(downloaded_snapshot):
                _materialize_snapshot_symlinks(downloaded_snapshot)
                log.info(f"Modelo '{model_name}' reparado y verificado: {downloaded_snapshot}")
                return downloaded_snapshot
            last_error = RuntimeError(f"HuggingFace terminó sin model.bin usable en {downloaded_snapshot}")
            log.warning(str(last_error))
        except Exception as exc:
            last_error = exc
            log.warning(f"No se pudo descargar '{repo_id}': {exc}")

    if last_error:
        log.error(f"No se pudo reparar/descargar el modelo '{model_name}': {last_error}")
    _repair_failures[model_name] = time.monotonic()
    return None


def is_any_model_downloaded() -> bool:
    """Verifica si existe al menos un modelo Whisper con pesos completos listos en disco."""
    return any(is_model_downloaded(m) for m in ["turbo", "large-v3-turbo", "small", "base", "tiny"])


def get_best_available_model(preferred: str = "turbo") -> str:
    """Retorna el modelo preferido si está descargado; de lo contrario, el mejor modelo disponible con pesos completos."""
    if is_model_downloaded(preferred):
        return preferred
    candidates = ["turbo", "large-v3-turbo", "small", "base", "tiny"]
    for c in candidates:
        if c != preferred and is_model_downloaded(c):
            log.info(f"Modelo preferido '{preferred}' no descargado/incompleto. Usando modelo disponible en disco: '{c}'")
            return c
    return preferred
