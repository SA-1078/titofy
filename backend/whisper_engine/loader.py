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
    print(yellow(text))


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
    """Detecta automáticamente si hay GPU CUDA disponible."""
    try:
        import torch
        if torch.cuda.is_available():
            name = torch.cuda.get_device_name(0)
            return "cuda", name
    except Exception as exc:
        print_yellow(f"  ⚠️  CUDA no se pudo inicializar correctamente: {exc}")
    return "cpu", "CPU"


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
        hf_cache = os.path.join(os.path.expanduser("~"), ".cache", "huggingface", "hub")
        fw_folder = f"models--Systran--faster-whisper-{fw_name}"
        if os.path.exists(os.path.join(hf_cache, fw_folder)):
            return True

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


def load_whisper_model(model_name: str, device: str, compute_type: str = "auto"):
    """
    Carga el modelo Whisper. Prioriza 'faster-whisper' mediante CTranslate2 para máxima
    velocidad, menor consumo de RAM y soporte de cuantización, con fallback a PyTorch Whisper.
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

    try:
        import stable_whisper

        if compute_type == "auto":
            selected_compute = "float16" if device == "cuda" else "int8"
        else:
            selected_compute = compute_type

        log.info(f"Cargando faster-whisper ({model_name_fw}) en {device} ({selected_compute})...")
        print(f"  ⚡ Usando motor optimizado faster-whisper ({selected_compute})")

        model = stable_whisper.load_faster_whisper(model_name_fw, device=device, compute_type=selected_compute)
        return model, True

    except Exception as e:
        log.warning(f"Fallback desde faster-whisper: {e}")
        print_yellow(f"  ⚠️  No se pudo usar faster-whisper ({e}).")
        print_yellow("     Usando motor estándar de PyTorch como fallback seguro.")

    try:
        import stable_whisper as whisper
        model = whisper.load_model(model_name_std, device=device)
        return model, False
    except Exception as e:
        log.error(f"Error crítico al cargar {model_name}: {e}")
        print(f"\n  ❌ Error crítico al cargar el modelo Whisper: {e}", file=sys.stderr)
        sys.exit(1)


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
        print(f"\n  ❌ No se encontro el archivo: {audio_path}", file=sys.stderr)
        sys.exit(1)

    if os.path.getsize(audio_path) <= 0:
        log.error(f"Archivo de audio vacio: {audio_path}")
        print(f"\n  ❌ El archivo de audio esta vacio: {audio_path}", file=sys.stderr)
        sys.exit(1)

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
        log.error(f"ffprobe no pudo leer el audio: {detail}")
        print(f"\n  ❌ ffprobe no pudo leer el archivo de audio: {detail}", file=sys.stderr)
        sys.exit(1)

    try:
        duration = float(result.stdout.strip())
    except ValueError:
        duration = 0.0

    if duration <= 0:
        log.error("Duracion de audio invalida")
        print("\n  ❌ El archivo de audio no tiene duracion valida.\n", file=sys.stderr)
        sys.exit(1)

    return duration
