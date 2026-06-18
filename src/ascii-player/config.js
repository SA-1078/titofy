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

  // Espectro
  BANDS: 112,
  MAX_HEIGHT: 12,
  SYMMETRIC: true,

  // Suavizado / fisica visual
  SMOOTHING: 0.75,          // EMA decay: movimiento mas organico
  DECAY_RATE: 1.2,          // Caida lineal en celdas/frame
  ATTACK_RATE: 0.5,         // Subida directa con lerp suave
  MAX_DELTA: 0.35,          // Anti-spike: salto máximo por frame
  PEAK_HOLD_FRAMES: 6,      // Frames que el peak flota antes de caer
  PEAK_DECAY_RATE: 0.3,     // Caida del peak en celdas/frame
  BASS_BOOST: 1.5,          // Boost solo para bandas graves
  BASS_POWER: 1.3,          // Curva musical con bajos mas dominantes
  HIGH_BAND_BOOST: 0.45,    // Extiende presencia visual hacia los laterales
  BEAT_HEIGHT_BOOST: 1.2,   // Multiplicador de altura en bass beat
  LYRIC_TRANSITION_MS: 650,  // Duracion del cambio suave de linea
  LYRIC_WARMUP_SEC: 2.5,    // Tiempo para iluminar la siguiente linea

  // Render
  FPS: 20,                  // Mas fluido sin castigar demasiado la terminal
  MIN_DB: -60,
  MAX_DB: -10,
  STREAM_DEAD_MS: 500,

  // Gradiente RGB arcoiris, de abajo hacia arriba.
  GRADIENT_STOPS: [
    { r: 255, g: 0, b: 0 },
    { r: 255, g: 100, b: 0 },
    { r: 255, g: 220, b: 0 },
    { r: 0, g: 255, b: 50 },
    { r: 0, g: 255, b: 200 },
    { r: 0, g: 130, b: 255 },
    { r: 180, g: 0, b: 255 },
  ],

  // Beat detection
  BASS_RANGE_HZ: [20, 200],
  MID_RANGE_HZ: [200, 2000],
  TREBLE_RANGE_HZ: [2000, 16000],
  BEAT_THRESHOLD: 1.4,
  BEAT_COOLDOWN_FRAMES: 4,
  ENERGY_HISTORY_SIZE: 43,

  // Caracteres de barra
  BAR_CHARS: {
    FULL: "█",
    THREE_Q: "▓",
    HALF: "▒",
    QUARTER: "░",
    PEAK: "▔",
    EMPTY: " ",
  },
};
