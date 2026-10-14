# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
loader.py — Carga de modelos Whisper, gestión de CUDA y fallbacks VRAM/CPU.
"""

import os
import sys
import shutil
import subprocess
import time

# Asegurar que la raíz de backend esté en sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from logger import get_logger
log = get_logger("whisper.loader")

_repair_failures: dict[str, float] = {}
_REPAIR_RETRY_SECONDS = 60.0

ANSI_YELLOW = "\033[33m"
ANSI_RESET = "\033[0m"


def yellow(text: str) -> str:
    return f"{ANSI_YELLOW}{text}{ANSI_RESET}"


def print_yellow(text: str):
    try:
        print(yellow(text))
    except (BrokenPipeError, OSError):
        pass


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
            "models--Systran--faster-whisper-large-v3-turbo",
        ]
    if model_name == "large-v3":
        return ["models--Systran--faster-whisper-large-v3"]
    return [f"models--Systran--faster-whisper-{model_name}"]


def _snapshot_has_weights(snapshot_path: str) -> bool:
    """Verifica si un snapshot de faster-whisper contiene model.bin con pesos válidos (> 10MB)."""
    try:
        bin_path = os.path.join(snapshot_path, "model.bin")
        if not os.path.exists(bin_path):
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
                        return snapshot
            except OSError:
                continue
    return None


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


def _model_repo_ids(model_name: str) -> list[str]:
    """Repositorios HuggingFace oficiales/compatibles para el alias solicitado."""
    if model_name == "large-v3":
        return ["Systran/faster-whisper-large-v3"]
    if model_name in ("turbo", "large-v3-turbo"):
        return [
            "mobiuslabsgmbh/faster-whisper-large-v3-turbo",
            "Systran/faster-whisper-large-v3-turbo",
        ]
    return [f"Systran/faster-whisper-{model_name}"]


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


def load_whisper_model(model_name: str, device: str, compute_type: str = "auto"):
    """
    Carga el modelo Whisper con tolerancia a fallos de GPU/drivers y fallback automático entre modelos.
    Prioriza 'faster-whisper' nativo sin dependencias de PyTorch.
    """
    try:
        from lyric_config import get_config
        cfg = get_config()
        if model_name in ["turbo", "large-v3-turbo"] and cfg.get("whisper", {}).get("use_large_v3_for_pro", False):
            model_name = "large-v3"
    except Exception:
        pass

    model_name_fw = "large-v3-turbo" if model_name in ["turbo", "large-v3-turbo"] else model_name
    model_name_std = "turbo" if model_name in ["turbo", "large-v3-turbo"] else model_name

    # Limitar hilos de CPU para no congelar la máquina del usuario
    cpu_limit = str(min(4, max(1, (os.cpu_count() or 4) // 2)))
    os.environ.setdefault("OMP_NUM_THREADS", cpu_limit)
    os.environ.setdefault("MKL_NUM_THREADS", cpu_limit)
    os.environ.setdefault("OPENBLAS_NUM_THREADS", cpu_limit)
    os.environ.setdefault("NUMEXPR_NUM_THREADS", cpu_limit)
    os.environ.setdefault("CT2_NUM_THREADS", cpu_limit)

    # 1. Intentar faster-whisper nativo en el dispositivo seleccionado
    if compute_type == "auto":
        selected_compute = "float16" if device == "cuda" else "int8"
    else:
        selected_compute = compute_type

    num_threads = int(os.environ.get("CT2_NUM_THREADS", "4"))

    # Lista ordenada de modelos a probar: primero el pedido, luego alternativas descargadas
    models_to_attempt = [model_name_fw]
    for alt in ["large-v3-turbo", "turbo", "small", "base", "tiny"]:
        alt_norm = "large-v3-turbo" if alt in ["turbo", "large-v3-turbo"] else alt
        if alt_norm not in models_to_attempt and is_model_downloaded(alt):
            models_to_attempt.append(alt_norm)

    # Si el modelo pedido no está descargado pero hay otro modelo válido en disco,
    # priorizar el que ya está listo para evitar descargas innecesarias y latencia
    if not is_model_downloaded(model_name_fw):
        available_alts = [m for m in models_to_attempt if m != model_name_fw and is_model_downloaded(m)]
        if available_alts:
            log.info(f"Modelo '{model_name_fw}' no descargado; usando modelo disponible en disco: '{available_alts[0]}'")
            models_to_attempt = available_alts + [model_name_fw]

    last_error: Exception | None = None
    for cur_model in models_to_attempt:
        # Debe existir también si falla la preparación del modelo antes de
        # entrar al fallback CPU del bloque except.
        model_source: str = cur_model
        try:
            # faster-whisper puede reutilizar un snapshot roto sin volver a
            # descargar los pesos. Limpiarlo permite que HF lo reconstruya.
            if not is_model_downloaded(cur_model):
                repaired_source = fix_loader(cur_model)
                if repaired_source is None:
                    raise RuntimeError(f"Modelo faster-whisper '{cur_model}' no disponible: falta model.bin")
                model_source = repaired_source
            else:
                model_source = _find_complete_faster_snapshot(cur_model) or cur_model
            from faster_whisper import WhisperModel
            log.info(f"Cargando faster-whisper ({model_source}) en {device} ({selected_compute}, {num_threads} hilos)...")
            model = WhisperModel(model_source, device=device, compute_type=selected_compute, cpu_threads=num_threads)
            return model, True
        except Exception as e:
            last_error = e
            log.warning(f"Fallo faster-whisper ({cur_model}) en {device}: {e}")
            if device == "cuda" and (is_model_downloaded(cur_model) or _snapshot_has_weights(model_source)):
                try:
                    from faster_whisper import WhisperModel
                    log.info(f"Reintentando faster-whisper ({cur_model}) en CPU (int8)...")
                    model = WhisperModel(model_source, device="cpu", compute_type="int8", cpu_threads=num_threads)
                    return model, True
                except Exception as e_cpu:
                    last_error = e_cpu
                    log.warning(f"Fallo faster-whisper ({cur_model}) en CPU: {e_cpu}")

    # 2. Fallback a PyTorch Whisper estándar si está instalado (entorno dev)
    try:
        import stable_whisper as sw_module
        log.info(f"Cargando PyTorch stable_whisper ({model_name_std}) en {device}...")
        return sw_module.load_model(model_name_std, device=device), False
    except (ImportError, Exception):
        pass

    try:
        import whisper as openai_whisper_module
        log.info(f"Cargando PyTorch Whisper ({model_name_std}) en {device}...")
        return openai_whisper_module.load_model(model_name_std, device=device), False
    except (ImportError, Exception):
        pass

    raise RuntimeError(
        f"No se pudo cargar ningún modelo Whisper disponible en disco (último error: {last_error})"
    )


def resolve_local_binary(binary_name: str) -> str | None:
    """Busca ffmpeg/ffprobe en PATH y en bin/ del proyecto."""
    exe_name = binary_name + (".exe" if os.name == "nt" else "")
    bundled = os.path.join(backend_dir, "bin", exe_name)
    if os.path.exists(bundled):
        return bundled
    return shutil.which(binary_name) or shutil.which(exe_name)


def validate_audio_file(audio_path: str) -> float | None:
    """Valida existencia, tamaño y lectura básica del audio antes de cargar Whisper."""
    if not os.path.exists(audio_path):
        log.error(f"No se encontro el archivo: {audio_path}")
        raise FileNotFoundError(f"No se encontró el archivo de audio: {audio_path}")

    if os.path.getsize(audio_path) <= 0:
        log.error(f"Archivo de audio vacio: {audio_path}")
        raise ValueError(f"El archivo de audio está vacío: {audio_path}")

    ffprobe = resolve_local_binary("ffprobe")
    if not ffprobe:
        print_yellow("  ⚠️  ffprobe no está disponible; se omite la validación profunda del audio.")
        return None

    cmd = [
        ffprobe,
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        audio_path,
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    except Exception as exc:
        print_yellow(f"  ⚠️  No se pudo validar el audio con ffprobe: {exc}")
        return None

    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "sin detalle").strip()
        log.warning(f"ffprobe reportó advertencia en el archivo: {detail}")
        return None

    try:
        duration = float(result.stdout.strip())
    except ValueError:
        duration = 0.0

    if duration <= 0:
        log.warning("Duración de audio no determinada con ffprobe; continuando.")
        return None

    return duration
