# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
loader.py — Fachada principal de carga de modelos Whisper, gestión de fallbacks de motor y validación de audio.
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

# Re-exportaciones de soporte CUDA y dispositivos
from whisper_engine.cuda_setup import (  # noqa: F401
    setup_cuda_dlls,
    detect_device,
    print_yellow,
    yellow,
    _get_nvidia_gpu_name,
)

# Re-exportaciones de caché y verificación de modelos
from whisper_engine.cache import (  # noqa: F401
    is_model_downloaded,
    is_any_model_downloaded,
    get_best_available_model,
    fix_loader,
    _huggingface_cache_dirs,
    _faster_whisper_cache_folders,
    _snapshot_has_weights,
    _clear_incomplete_faster_cache,
    _find_complete_faster_snapshot,
    _model_repo_ids,
)

__all__ = [
    "setup_cuda_dlls",
    "detect_device",
    "print_yellow",
    "yellow",
    "is_model_downloaded",
    "is_any_model_downloaded",
    "get_best_available_model",
    "fix_loader",
    "load_whisper_model",
    "resolve_local_binary",
    "validate_audio_file",
]


def _patch_whisper_model(wm_class):
    """Garantiza que WhisperModel.transcribe tolere 'vad' mapeándolo a 'vad_filter' sin lanzar TypeError."""
    if os.name == "nt":
        try:
            from windows import patch_whisper_vad
            if patch_whisper_vad(wm_class):
                return
        except Exception:
            pass
    if not getattr(wm_class, "_titofy_vad_patched", False):
        orig_transcribe = wm_class.transcribe
        def _safe_transcribe(self, *args, **kwargs):
            if "vad" in kwargs:
                v = kwargs.pop("vad")
                if "vad_filter" not in kwargs:
                    kwargs["vad_filter"] = bool(v)
            return orig_transcribe(self, *args, **kwargs)
        wm_class.transcribe = _safe_transcribe
        wm_class._titofy_vad_patched = True


def load_whisper_model(model_name: str, device: str, compute_type: str = "auto"):
    """
    Carga el modelo Whisper con tolerancia a fallos de GPU/drivers y fallback automático entre modelos.
    Prioriza 'faster-whisper' nativo sin dependencias de PyTorch.
    """
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
            _patch_whisper_model(WhisperModel)
            log.info(f"Cargando faster-whisper ({model_source}) en {device} ({selected_compute}, {num_threads} hilos)...")
            model = WhisperModel(model_source, device=device, compute_type=selected_compute, cpu_threads=num_threads)
            return model, True
        except Exception as e:
            last_error = e
            log.warning(f"Fallo faster-whisper ({cur_model}) en {device}: {e}")
            if device == "cuda" and (is_model_downloaded(cur_model) or _snapshot_has_weights(model_source)):
                try:
                    from faster_whisper import WhisperModel
                    _patch_whisper_model(WhisperModel)
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
