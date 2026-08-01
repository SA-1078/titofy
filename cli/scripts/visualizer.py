#!/usr/bin/env python3
"""
visualizer.py — Visualizador Espectral Animado PRO (Python + sounddevice / rich)

Características:
  - Escala logarítmica de frecuencias (30 Hz - 16,000 Hz)
  - Attack rápido (subida instantánea) + Decay lento (caída suave con EMA)
  - Peak Hold con temporizador de retención y caída exponencial
  - Resolución vertical mejorada con caracteres sub-block Unicode ( ▂▃▄▅▆▇█)
  - Renderizado Truecolor RGB espectral fluido
  - Reposicionamiento ANSI del cursor (\x1b[H) sin parpadeo (flicker-free)
"""

import sys
import time
import math
import os

try:
    import numpy as np
except ImportError:
    print("Error: numpy no está instalado. Ejecuta: pip install numpy")
    sys.exit(1)

try:
    import sounddevice as sd
except ImportError:
    sd = None

try:
    from rich.console import Console
    from rich.text import Text
    console = Console()
except ImportError:
    console = None


# ─── Configuración ─────────────────────────────────────────────────────────────
SAMPLE_RATE = 44100
BLOCK_SIZE = 2048
BARS = 60
HEIGHT = 16
ATTACK_RATE = 0.97
DECAY = 0.82
PEAK_DECAY = 0.90
PEAK_HOLD_FRAMES = 6
MIN_FREQ = 30
MAX_FREQ = 16000

SUB_BLOCKS = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
PEAK_CHAR = "▀"

# Gradiente espectral (Azul → Cyan → Verde → Amarillo → Naranja → Rojo)
GRADIENT_STOPS = [
    (0, 150, 255),
    (0, 230, 255),
    (0, 255, 120),
    (255, 220, 0),
    (255, 100, 0),
    (255, 30, 90),
]


def interpolate_color(c1, c2, t):
    r = int(c1[0] + (c2[0] - c1[0]) * t)
    g = int(c1[1] + (c2[1] - c1[1]) * t)
    b = int(c1[2] + (c2[2] - c1[2]) * t)
    return max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))


def get_gradient_color(level_ratio):
    t = max(0.0, min(1.0, level_ratio))
    scaled = t * (len(GRADIENT_STOPS) - 1)
    idx = int(scaled)
    frac = scaled - idx
    if idx >= len(GRADIENT_STOPS) - 1:
        return GRADIENT_STOPS[-1]
    return interpolate_color(GRADIENT_STOPS[idx], GRADIENT_STOPS[idx + 1], frac)


def log_bins(fft_size, num_bars, sample_rate):
    freqs = np.fft.rfftfreq(fft_size, 1.0 / sample_rate)
    indices = np.linspace(0, 1, num_bars + 1) ** 0.85
    log_freqs = MIN_FREQ * ((MAX_FREQ / MIN_FREQ) ** indices)
    bins = np.searchsorted(freqs, log_freqs)
    for i in range(len(bins) - 1):
        if bins[i + 1] <= bins[i]:
            bins[i + 1] = bins[i] + 1
    return bins


bins = log_bins(BLOCK_SIZE, BARS, SAMPLE_RATE)
prev_bars = np.zeros(BARS, dtype=np.float64)
peaks = np.zeros(BARS, dtype=np.float64)
peak_hold = np.zeros(BARS, dtype=np.int32)
initialized = False


def process_audio_chunk(audio_data):
    global prev_bars, peaks, peak_hold

    # Mono + Ventana Hann
    if audio_data.ndim > 1:
        mono = np.mean(audio_data, axis=1)
    else:
        mono = audio_data

    if len(mono) < BLOCK_SIZE:
        mono = np.pad(mono, (0, BLOCK_SIZE - len(mono)))

    windowed = mono * np.hanning(len(mono))
    fft = np.abs(np.fft.rfft(windowed))

    # Agrupar por bins logarítmicos: 75% MAX + 25% AVG en graves (30%), MEAN en medios/agudos
    spectrum = np.zeros(BARS)
    bass_bars = int(BARS * 0.30)
    for i in range(BARS):
        start, end = bins[i], bins[i + 1]
        if start < len(fft):
            chunk = fft[start:min(end, len(fft))]
            if len(chunk) > 0:
                if i < bass_bars:
                    spectrum[i] = 0.75 * np.max(chunk) + 0.25 * np.mean(chunk)
                else:
                    spectrum[i] = np.mean(chunk)

    # Normalización por rango dinámico fijo en dB [-48 dB, -8 dB]
    eps = 1e-6
    min_db, max_db = -48.0, -8.0

    for i in range(BARS):
        val = spectrum[i]
        db = 20.0 * np.log10(val + eps)
        norm = np.clip((db - min_db) / (max_db - min_db), 0.0, 1.0)

        if i < bass_bars:
            norm *= 1.05
            norm = math.pow(norm, 1.25)
            norm = min(norm, 0.92)

        spectrum[i] = max(0.0, min(1.0, norm))

    # 1. Física diferenciada
    for i in range(BARS):
        curr = spectrum[i]
        prev = prev_bars[i]
        is_bass = (i < bass_bars)

        attack = 0.90 if is_bass else 0.97
        decay = 0.68 if is_bass else 0.72

        if curr > prev:
            prev_bars[i] = curr * attack + prev * (1.0 - attack)
        else:
            prev_bars[i] = prev * decay + curr * (1.0 - decay)

        prev_bars[i] = max(0.0, min(1.0, prev_bars[i]))

    # 2. Difusión lateral (suavizado horizontal) solo en la zona de graves
    diffusion = 0.22
    for i in range(1, bass_bars - 1):
        left = prev_bars[i - 1]
        right = prev_bars[i + 1]
        center = prev_bars[i]
        prev_bars[i] = max(0.0, min(1.0, center * (1.0 - diffusion) + (left + right) * 0.5 * diffusion))

    # 3. Peak Hold diferenciado
    for i in range(BARS):
        is_bass = (i < bass_bars)
        hold_frames = 5 if is_bass else 8
        if prev_bars[i] >= peaks[i]:
            peaks[i] = prev_bars[i]
            peak_hold[i] = hold_frames
        elif peak_hold[i] > 0:
            peak_hold[i] -= 1
        else:
            peaks[i] = max(prev_bars[i], peaks[i] * 0.88)

    render(prev_bars, peaks)


def render(bars, peaks_arr):
    global initialized
    output = []

    # Reposición de cursor sin parpadeo (flicker-free)
    if not initialized:
        output.append("\033[2J\033[H")
        initialized = True
    else:
        output.append("\033[H")

    output.append("  🎵 Titofy Spectrum Visualizer (Python PRO Engine)\n")
    output.append("  " + "─" * (BARS + 4) + "\n")

    for h in range(HEIGHT - 1, -1, -1):
        row_str = "    "
        for i in range(BARS):
            float_h = bars[i] * HEIGHT
            peak_h = peaks_arr[i] * HEIGHT

            color = get_gradient_color(h / (HEIGHT - 1))
            color_ansi = f"\033[38;2;{color[0]};{color[1]};{color[2]}m"

            if float_h >= h + 1:
                row_str += f"{color_ansi}{SUB_BLOCKS[7]}\033[0m"
            elif float_h > h:
                frac = float_h - h
                sub_idx = min(7, max(1, int(frac * 8)))
                row_str += f"{color_ansi}{SUB_BLOCKS[sub_idx]}\033[0m"
            elif peak_h > float_h + 0.1 and int(peak_h) == h:
                row_str += f"\033[1;37m{PEAK_CHAR}\033[0m"
            else:
                row_str += " "

        row_str += "\033[K\n"
        output.append(row_str)

    output.append("  " + "─" * (BARS + 4) + "\033[K\n")
    output.append("  Presiona Ctrl+C para salir.\033[K\n")

    sys.stdout.write("".join(output))
    sys.stdout.flush()


def audio_callback(indata, frames, time_info, status):
    if status:
        pass
    process_audio_chunk(indata)


def main():
    if sd is None:
        print("Error: sounddevice no está instalado.")
        print("Instálalo con: pip install sounddevice numpy rich")
        sys.exit(1)

    print("Iniciando visualizador de audio en vivo...")
    try:
        with sd.InputStream(callback=audio_callback, channels=1, samplerate=SAMPLE_RATE, blocksize=BLOCK_SIZE):
            while True:
                time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n\nVisualizador finalizado.")
        sys.exit(0)


if __name__ == "__main__":
    main()
