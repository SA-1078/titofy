# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
loader.py — Carga de modelos Whisper, gestión de CUDA y fallbacks VRAM/CPU.
"""

import os
import sys
import shutil
import subprocess

# Asegurar que la raíz de backend esté en sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from logger import get_logger
log = get_logger("whisper.loader")

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
    Solución de Carga de DLLs para Windows CUDA y PyAV (Python 3.8+)
    Agrega los directorios binarios de las dependencias nvidia y PyAV locales de la venv
    o del sistema al PATH de DLLs de Windows.
    """
    os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

    if os.name == "nt":
        venv_root = os.path.dirname(os.path.dirname(sys.executable))
        site_packages = os.path.join(venv_root, "Lib", "site-packages")

        if os.path.exists(site_packages):
            for pkg in ["cublas", "cudnn", "cuda_nvrtc", "cuda_runtime"]:
                bin_dir = os.path.join(site_packages, "nvidia", pkg, "bin")
                if os.path.exists(bin_dir):
                    try:
                        os.add_dll_directory(bin_dir)
                    except Exception:
                        pass

            av_libs = os.path.join(site_packages, "av.libs")
            if os.path.exists(av_libs):
                try:
                    os.add_dll_directory(av_libs)
                except Exception:
                    pass

        cuda_path = os.environ.get("CUDA_PATH")
        if cuda_path:
            bin_dir = os.path.join(cuda_path, "bin")
            if os.path.exists(bin_dir):
                try:
                    os.add_dll_directory(bin_dir)
                except Exception:
                    pass


def detect_device() -> tuple[str, str]:
    """Detecta automáticamente si hay GPU CUDA disponible y funcional."""
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
    for env_name in ("HUGGINGFACE_HUB_CACHE", "HF_HOME", "TRANSFORMERS_CACHE"):
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
    fw_name = "large-v3-turbo" if model_name in ("turbo", "large-v3-turbo") else model_name
    folders = [f"models--Systran--faster-whisper-{fw_name}"]
    # El alias large-v3-turbo también se publica bajo este repositorio.
    if fw_name == "large-v3-turbo":
        folders.append("models--mobiuslabsgmbh--faster-whisper-large-v3-turbo")
    return folders


def _snapshot_has_weights(snapshot_path: str) -> bool:
    try:
        return any(
            f.startswith("model") and f.endswith((".bin", ".safetensors"))
            for f in os.listdir(snapshot_path)
        )
    except OSError:
        return False


def _clear_incomplete_faster_cache(model_name: str) -> None:
    """Quita solo snapshots incompletos para que HF pueda reanudar la descarga."""
    for cache_dir in _huggingface_cache_dirs():
        for folder in _faster_whisper_cache_folders(model_name):
            snapshots_dir = os.path.join(cache_dir, folder, "snapshots")
            if not os.path.isdir(snapshots_dir):
                continue
            try:
                snapshots = [
                    os.path.join(snapshots_dir, entry)
                    for entry in os.listdir(snapshots_dir)
                    if os.path.isdir(os.path.join(snapshots_dir, entry))
                ]
                if snapshots and not any(_snapshot_has_weights(s) for s in snapshots):
                    for snapshot in snapshots:
                        log.warning(f"Snapshot Whisper incompleto detectado; se eliminara para reanudar descarga: {snapshot}")
                        shutil.rmtree(snapshot, ignore_errors=True)
            except OSError as exc:
                log.warning(f"No se pudo reparar la caché Whisper '{snapshots_dir}': {exc}")


def is_model_downloaded(model_name: str, use_faster: bool = True) -> bool:
    """Verifica si el modelo Whisper ya está en la caché local."""
    try:
        from lyric_config import get_config
        cfg = get_config()
        if model_name in ["turbo", "large-v3-turbo"] and cfg.get("whisper", {}).get("use_large_v3_for_pro", False):
            model_name = "large-v3"
    except Exception:
        pass

    fw_name = "large-v3-turbo" if model_name in ["turbo", "large-v3-turbo"] else model_name
    std_name = "turbo" if model_name in ["turbo", "large-v3-turbo"] else model_name

    if use_faster:
        cache_dirs = _huggingface_cache_dirs()
        fw_folders = _faster_whisper_cache_folders(model_name)
        for cdir in cache_dirs:
            for fw_folder in fw_folders:
                target = os.path.join(cdir, fw_folder)
                if not os.path.exists(target):
                    continue
                snapshots_dir = os.path.join(target, "snapshots")
                if os.path.exists(snapshots_dir):
                    try:
                        for s in os.listdir(snapshots_dir):
                            snap_path = os.path.join(snapshots_dir, s)
                            if os.path.isdir(snap_path):
                                if _snapshot_has_weights(snap_path):
                                    return True
                    except Exception:
                        pass
                try:
                    if any(f.startswith("model") and f.endswith((".bin", ".safetensors")) for f in os.listdir(target)):
                        return True
                except Exception:
                    pass

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
    return os.path.exists(model_path)


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

    last_error: Exception | None = None
    for cur_model in models_to_attempt:
        try:
            # faster-whisper puede reutilizar un snapshot roto sin volver a
            # descargar los pesos. Limpiarlo permite que HF lo reconstruya.
            if not is_model_downloaded(cur_model):
                _clear_incomplete_faster_cache(cur_model)
            from faster_whisper import WhisperModel
            log.info(f"Cargando faster-whisper ({cur_model}) en {device} ({selected_compute}, {num_threads} hilos)...")
            model = WhisperModel(cur_model, device=device, compute_type=selected_compute, cpu_threads=num_threads)
            return model, True
        except Exception as e:
            last_error = e
            log.warning(f"Fallo faster-whisper ({cur_model}) en {device}: {e}")
            if device == "cuda":
                try:
                    from faster_whisper import WhisperModel
                    log.info(f"Reintentando faster-whisper ({cur_model}) en CPU (int8)...")
                    model = WhisperModel(cur_model, device="cpu", compute_type="int8", cpu_threads=num_threads)
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
