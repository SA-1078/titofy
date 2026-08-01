/**
 * config.js - Parametros centralizados del Visualizador ASCII.
 *
 * Render event-driven, carga uniforme y movimiento fluido en terminal.
 */

module.exports = {
  // FFT / Audio
  SAMPLE_RATE: 44100,
  CHANNELS: 1,
  BIT_DEPTH: 16,
  FFT_SIZE: 1024,

  // Espectro (Izquierda = Graves, Derecha = Agudos)
  BANDS: 112,
  MAX_HEIGHT: 12,
  SYMMETRIC: false,

  // === GRAVES (primeras 30% de barras: curvas orgánicas y difusión lateral) ===
  BASS_BARS_RATIO: 0.30,    // 30% de resolución para la zona de graves
  BASS_DIFFUSION: 0.22,     // Difusión lateral (suavizado horizontal entre barras vecinas)
  BASS_MAX_WEIGHT: 0.75,    // 75% MAX + 25% AVG bin weight (punch + forma orgánica)
  BASS_AVG_WEIGHT: 0.25,
  BASS_ATTACK: 0.90,        // Subida rápida y con cuerpo
  BASS_DECAY: 0.68,         // Bajada ágil (equilibrada)
  BASS_POWER: 1.25,         // Compresión suave de picos
  BASS_GAIN: 1.05,          // Ganancia con cuerpo para presencia superior a medios
  BASS_MAX_CEILING: 0.92,   // Techo alto (hasta 92% de altura)
  PEAK_HOLD_BASS_FRAMES: 5, // Peak hold ágil en graves (5 frames)

  // === MEDIOS Y AGUDOS (75% restante: respuesta fluida) ===
  ATTACK_RATE: 0.97,        // Subida casi instantánea ante notas y hi-hats
  DECAY: 0.72,              // Bajada fluida tipo ola
  PEAK_HOLD_FRAMES: 8,      // Peak hold estándar para medios/agudos
  PEAK_DECAY: 0.88,         // Caída ágil del peak
  BEAT_HEIGHT_BOOST: 1.08,  // Multiplicador sutil de beat
  LYRIC_TRANSITION_MS: 650,  // Duración del cambio suave de línea
  LYRIC_WARMUP_SEC: 2.5,    // Tiempo para iluminar la siguiente línea

  // Render (Rango Dinámico equilibrado)
  FPS: 30,                  // 30 FPS para movimiento ultra-fluido
  MIN_DB: -48,              // -48 dB: Silencio limpio sin perder dinámica
  MAX_DB: -8,               // -8 dB: Techo dinámico reactivo
  STREAM_DEAD_MS: 500,

  // Gradiente RGB Truecolor espectral (Azul → Cyan → Verde → Amarillo → Naranja → Rojo)
  GRADIENT_STOPS: [
    { r: 0, g: 150, b: 255 },
    { r: 0, g: 230, b: 255 },
    { r: 0, g: 255, b: 120 },
    { r: 255, g: 220, b: 0 },
    { r: 255, g: 100, b: 0 },
    { r: 255, g: 30, b: 90 },
  ],

  // Beat detection
  BASS_RANGE_HZ: [20, 200],
  MID_RANGE_HZ: [200, 2000],
  TREBLE_RANGE_HZ: [2000, 16000],
  BEAT_THRESHOLD: 1.4,
  BEAT_COOLDOWN_FRAMES: 4,
  ENERGY_HISTORY_SIZE: 43,

  // Caracteres Unicode de bloque para alta resolución vertical
  BAR_CHARS: {
    FULL: "█",
    SUB_BLOCKS: [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
    PEAK: "▀",
    EMPTY: " ",
  },
};
