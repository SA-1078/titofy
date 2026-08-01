/**
 * spectrum-analyzer.js — Motor de análisis espectral en tiempo real (v2 — estable)
 *
 * Pipeline:  ffmpeg (decode) → PCM buffer → Hanning window → FFT → log-scale bands → dB → smooth
 *
 * Cambios arquitectónicos clave:
 *  - Anti-spike limiter (MAX_DELTA) para evitar saltos violentos
 *  - Clamp seguro [0,1] en toda la cadena
 *  - Bass boost controlado
 *  - Kill confirmado (taskkill /T antes de relanzar el stream)
 *  - Detección de stream muerto via timestamp de último dato
 */

const { spawn, execFileSync } = require("child_process");
const { EventEmitter } = require("events");
const ft = require("fourier-transform").default;
const { resolveFFmpeg } = require("../ffmpeg-resolver");
const { createLogger } = require("../logger");
const cfg = require("./config");

const log = createLogger("spectrum");

function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}

class SpectrumAnalyzer extends EventEmitter {
  /**
   * @param {string} audioFile  — Ruta al archivo de audio
   * @param {object} systemEnv  — Variables de entorno con PATH extendido
   */
  constructor(audioFile, systemEnv) {
    super();
    this.audioFile = audioFile;
    this.systemEnv = systemEnv;
    this.process = null;
    this.buffer = Buffer.alloc(0);
    this.prevBands = null;        // Para suavizado frame-to-frame
    this.peakBands = null;        // Indicadores de pico
    this.peakHold = null;         // Contadores de hold por banda
    this._destroyed = false;
    this.lastDataTime = 0;        // Timestamp del último dato recibido

    // Pre-calcular ventana Hanning
    this._hanningWindow = this._createHanningWindow(cfg.FFT_SIZE);
    // Pre-calcular mapeo logarítmico de bins → bandas
    this._bandMap = null;         // Se genera al conocer el número real de bandas
  }

  /**
   * Calcula cuántas bandas usar según el ancho de la terminal.
   */
  getAdaptiveBands() {
    const termWidth = process.stdout.columns || 110;
    // En modo simetría, necesitamos el doble de espacio
    const availableWidth = termWidth - 6; // margen lateral
    let maxBands = cfg.SYMMETRIC
      ? Math.floor(availableWidth / 2)
      : availableWidth;

    // Cada barra ocupa 1 carácter + 0 de gap (compacto)
    return Math.max(16, Math.min(cfg.BANDS, maxBands));
  }

  /**
   * ¿El stream está vivo? (recibió datos recientemente)
   */
  isStreamAlive() {
    if (this.lastDataTime === 0) return false;
    return (Date.now() - this.lastDataTime) < cfg.STREAM_DEAD_MS;
  }

  /**
   * Inicia el stream de análisis FFT.
   * Spawna ffmpeg para decodificar el audio a PCM crudo.
   */
  start() {
    const ffmpegBin = resolveFFmpeg();
    if (!ffmpegBin) {
      log.error("ffmpeg no encontrado — no se puede analizar audio");
      return;
    }

    const args = [
      "-re",                      // ← CRÍTICO: forzar output en tiempo real
      "-i", this.audioFile,
      "-f", "s16le",              // Raw PCM 16-bit signed little-endian
      "-acodec", "pcm_s16le",
      "-ar", String(cfg.SAMPLE_RATE),
      "-ac", String(cfg.CHANNELS),
      "-loglevel", "quiet",
      "pipe:1",                   // Output a stdout
    ];

    this.process = spawn(ffmpegBin, args, {
      stdio: ["pipe", "pipe", "ignore"],
      env: this.systemEnv,
    });

    // Bytes necesarios por chunk FFT: FFT_SIZE samples × 2 bytes/sample (16-bit)
    const chunkBytes = cfg.FFT_SIZE * 2;

    this.process.stdout.on("data", (data) => {
      if (this._destroyed) return;

      this.lastDataTime = Date.now();

      // Acumular buffer
      this.buffer = Buffer.concat([this.buffer, data]);

      // Procesar todos los chunks completos disponibles
      while (this.buffer.length >= chunkBytes) {
        const chunk = this.buffer.subarray(0, chunkBytes);
        this.buffer = this.buffer.subarray(chunkBytes);
        this._processChunk(chunk);
      }
    });

    this.process.on("error", (err) => {
      log.error(`ffmpeg error: ${err.message}`);
    });

    this.process.on("close", () => {
      if (!this._destroyed) {
        this.emit("end");
      }
    });
  }

  /**
   * Procesa un chunk de PCM crudo: int16 → float → Hanning → FFT → bandas.
   */
  _processChunk(chunk) {
    const numBands = this.getAdaptiveBands();

    // 1. Convertir Int16 → Float64 normalizado [-1, 1]
    const samples = new Float64Array(cfg.FFT_SIZE);
    for (let i = 0; i < cfg.FFT_SIZE; i++) {
      samples[i] = chunk.readInt16LE(i * 2) / 32768;
    }

    // 2. Aplicar ventana Hanning (reduce spectral leakage)
    for (let i = 0; i < cfg.FFT_SIZE; i++) {
      samples[i] *= this._hanningWindow[i];
    }

    // 3. FFT → magnitudes (solo mitad positiva: FFT_SIZE / 2 bins)
    const magnitudes = ft(samples);

    // 4. Agrupar en bandas logarítmicas
    if (!this._bandMap || this._bandMap.numBands !== numBands) {
      this._bandMap = this._createLogBandMap(magnitudes.length, numBands);
    }
    const rawBands = this._groupIntoBands(magnitudes, this._bandMap);

    // 5. Convertir a dB con epsilon, normalizar a rango dinámico [-48dB, -8dB] y procesar de forma diferenciada
    const bassLimit = Math.floor(numBands * (cfg.BASS_BARS_RATIO || 0.25));
    const eps = 1e-6;

    const normalizedBands = rawBands.map((val, i) => {
      const isBass = i < bassLimit;

      // Convertir magnitud a dB
      const db = 20 * Math.log10(val + eps);

      // Normalizar por rango dinámico [-48 dB, -8 dB]
      let norm = (db - cfg.MIN_DB) / (cfg.MAX_DB - cfg.MIN_DB);
      norm = clamp01(norm);

      if (isBass) {
        // === GRAVES ===
        norm *= cfg.BASS_GAIN || 1.05;
        norm = Math.pow(norm, cfg.BASS_POWER || 1.25);
        norm = Math.min(norm, cfg.BASS_MAX_CEILING || 0.92);
      } else {
        // === MEDIOS Y AGUDOS ===
        const bandRatio = (i - bassLimit) / Math.max(1, numBands - bassLimit);
        norm *= 1 + bandRatio * (cfg.HIGH_BAND_BOOST || 0.35);
      }

      return clamp01(norm);
    });

    // 6. Suavizado diferenciado + Attack/Decay
    const smoothed = this._applySmoothing(normalizedBands, numBands, bassLimit);

    // 7. Actualizar picos diferenciados
    this._updatePeaks(smoothed, numBands, bassLimit);

    // 8. Emitir datos del espectro
    this.emit("spectrum", {
      bands: smoothed,
      peaks: this.peakBands ? Array.from(this.peakBands) : smoothed,
      numBands,
      rawMagnitudes: magnitudes,
    });
  }

  /**
   * Crea ventana Hanning para reducir spectral leakage.
   */
  _createHanningWindow(size) {
    const window = new Float64Array(size);
    for (let i = 0; i < size; i++) {
      window[i] = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (size - 1)));
    }
    return window;
  }

  /**
   * Crea un mapeo logarítmico de bins FFT → bandas visuales.
   */
  _createLogBandMap(numBins, numBands) {
    const map = [];
    const minFreq = 30;     // 30 Hz graves (siempre a la izquierda)
    const maxFreq = 16000;  // 16 kHz agudos (siempre a la derecha)
    const nyquist = cfg.SAMPLE_RATE / 2;

    for (let i = 0; i < numBands; i++) {
      const tLow = Math.pow(i / numBands, 0.85);
      const tHigh = Math.pow((i + 1) / numBands, 0.85);

      const freqLow = minFreq * Math.pow(maxFreq / minFreq, tLow);
      const freqHigh = minFreq * Math.pow(maxFreq / minFreq, tHigh);

      let binLow = Math.floor((freqLow / nyquist) * numBins);
      let binHigh = Math.floor((freqHigh / nyquist) * numBins);

      binLow = Math.max(0, Math.min(numBins - 1, binLow));
      binHigh = Math.max(binLow, Math.min(numBins - 1, binHigh));

      map.push({ binLow, binHigh, freqLow, freqHigh });
    }

    map.numBands = numBands;
    return map;
  }

  /**
   * Agrupa bins FFT en bandas: 75% MAX + 25% AVG en graves (punch + forma orgánica) y MEAN en medios/agudos.
   */
  _groupIntoBands(magnitudes, bandMap) {
    const bands = new Float64Array(bandMap.numBands);
    const bassLimit = Math.floor(bandMap.numBands * (cfg.BASS_BARS_RATIO || 0.30));

    for (let i = 0; i < bandMap.numBands; i++) {
      const { binLow, binHigh } = bandMap[i];
      const isBass = i < bassLimit;

      if (isBass) {
        // Graves: Combina 75% MAX (punch) + 25% AVG (forma orgánica)
        let maxVal = 0;
        let sum = 0;
        let count = 0;
        for (let b = binLow; b <= binHigh; b++) {
          if (b < magnitudes.length) {
            const val = magnitudes[b];
            if (val > maxVal) maxVal = val;
            sum += val;
            count++;
          }
        }
        const avgVal = count > 0 ? sum / count : 0;
        const maxW = cfg.BASS_MAX_WEIGHT || 0.75;
        const avgW = cfg.BASS_AVG_WEIGHT || 0.25;
        bands[i] = maxVal * maxW + avgVal * avgW;
      } else {
        // Medios y agudos: promedio (mean)
        let sum = 0;
        let count = 0;
        for (let b = binLow; b <= binHigh; b++) {
          if (b < magnitudes.length) {
            sum += magnitudes[b];
            count++;
          }
        }
        bands[i] = count > 0 ? sum / count : 0;
      }
    }

    return bands;
  }

  /**
   * Aplica física de audio diferenciada + Difusión Lateral en graves:
   *  - Graves: caída rápida (BASS_DECAY = 0.68) + difusión horizontal (BASS_DIFFUSION = 0.22).
   *  - Medios y agudos: movimiento fluido de ola (ATTACK = 0.97, DECAY = 0.72).
   */
  _applySmoothing(current, numBands, bassLimit) {
    if (!this.prevBands || this.prevBands.length !== numBands) {
      this.prevBands = new Float64Array(numBands);
    }

    const result = new Float64Array(numBands);

    const bassAttack = cfg.BASS_ATTACK || 0.90;
    const bassDecay = cfg.BASS_DECAY || 0.68;
    const restAttack = cfg.ATTACK_RATE || 0.97;
    const restDecay = cfg.DECAY || 0.72;

    // 1. Attack / Decay vertical por banda
    for (let i = 0; i < numBands; i++) {
      const prev = this.prevBands[i];
      const curr = current[i];
      const isBass = i < bassLimit;

      const attack = isBass ? bassAttack : restAttack;
      const decay = isBass ? bassDecay : restDecay;

      if (curr > prev) {
        result[i] = curr * attack + prev * (1 - attack);
      } else {
        result[i] = prev * decay + curr * (1 - decay);
      }

      result[i] = clamp01(result[i]);
      this.prevBands[i] = result[i];
    }

    // 2. Difusión lateral (suavizado horizontal) SOLO en la zona de graves
    const diffusion = cfg.BASS_DIFFUSION || 0.22;
    for (let i = 1; i < bassLimit - 1; i++) {
      const left = this.prevBands[i - 1];
      const right = this.prevBands[i + 1];
      const center = this.prevBands[i];

      const diffVal = center * (1 - diffusion) + (left + right) * 0.5 * diffusion;
      result[i] = clamp01(diffVal);
      this.prevBands[i] = result[i];
    }

    return Array.from(result);
  }

  /**
   * Actualiza indicadores de pico con Peak Hold diferenciado (4 frames en graves vs 8 en medios/agudos).
   */
  _updatePeaks(bands, numBands, bassLimit) {
    if (!this.peakBands || this.peakBands.length !== numBands) {
      this.peakBands = new Float64Array(numBands);
      this.peakHold = new Int32Array(numBands);
    }

    const peakHoldBass = cfg.PEAK_HOLD_BASS_FRAMES || 4;
    const peakHoldRest = cfg.PEAK_HOLD_FRAMES || 8;
    const peakDecay = cfg.PEAK_DECAY || 0.88;

    for (let i = 0; i < numBands; i++) {
      const current = bands[i];
      const isBass = i < bassLimit;
      const holdFrames = isBass ? peakHoldBass : peakHoldRest;

      if (current >= this.peakBands[i]) {
        this.peakBands[i] = current;
        this.peakHold[i] = holdFrames;
      } else if (this.peakHold[i] > 0) {
        this.peakHold[i]--;
      } else {
        this.peakBands[i] = Math.max(current, this.peakBands[i] * peakDecay);
      }
    }
  }

  /**
   * Obtiene los rangos de bins para bass/mid/treble (para beat detection).
   */
  getFrequencyRanges(numBins) {
    const binForHz = (hz) => Math.floor(hz * numBins * 2 / cfg.SAMPLE_RATE);
    return {
      bass: { low: binForHz(cfg.BASS_RANGE_HZ[0]), high: binForHz(cfg.BASS_RANGE_HZ[1]) },
      mid: { low: binForHz(cfg.MID_RANGE_HZ[0]), high: binForHz(cfg.MID_RANGE_HZ[1]) },
      treble: { low: binForHz(cfg.TREBLE_RANGE_HZ[0]), high: binForHz(cfg.TREBLE_RANGE_HZ[1]) },
    };
  }

  /**
   * Mata el proceso ffmpeg y limpia recursos.
   * Kill confirmado: evita acumular procesos ffmpeg al hacer seek o pausar.
   */
  destroy() {
    this._destroyed = true;
    if (this.process) {
      this.process.removeAllListeners();
      if (this.process.stdout) this.process.stdout.removeAllListeners();
      const pid = this.process.pid;

      // En Windows, taskkill /T espera a que muera todo el arbol de ffmpeg.
      if (pid) {
        try {
          execFileSync("taskkill", ["/F", "/T", "/PID", pid.toString()], {
            stdio: "ignore",
            timeout: 1500,
            windowsHide: true,
          });
        } catch { }
      }

      try { this.process.kill("SIGKILL"); } catch { }

      this.process = null;
    }
    this.buffer = Buffer.alloc(0);
    this.prevBands = null;
    this.peakBands = null;
    this.peakHold = null;
    this.lastDataTime = 0;
    this.removeAllListeners();
  }
}

module.exports = SpectrumAnalyzer;
