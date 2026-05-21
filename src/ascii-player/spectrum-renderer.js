/**
 * spectrum-renderer.js — Renderizado ASCII del espectro arcoíris (v3 PRO)
 *
 * Mejoras PRO implementadas:
 *  - Mejora 3: Peaks más visibles (estilo Winamp/CAVA con decay gradual)
 *  - Mejora 5: Beat notorio con pulse suave (iluminar gradiente, no blanco puro)
 *  - Mejora 6: Fade de letras, warmup de siguiente línea, transiciones suaves
 *
 * Técnica de render: ANSI cursor control (sin console.clear).
 * Escribe todo el frame como un único string y hace flush atómico.
 */

const chalk = require("chalk");
const { formatTime } = require("../lrc-parser");
const cfg = require("./config");
const os = require("os");

// ─── Geometry Cache ────────────────────────────────────────────────────
const isWindows = os.platform() === "win32";
let fixedWidth = null;
let fixedHeight = null;

function getTerminalSize() {
  let w = process.stdout.columns || 110;
  let h = process.stdout.rows || 30;

  if (isWindows) {
    if (!fixedWidth || w < fixedWidth - 5 || w > fixedWidth + 5) fixedWidth = w;
    if (!fixedHeight || h < fixedHeight - 3 || h > fixedHeight + 3) fixedHeight = h;
    return { width: fixedWidth, height: fixedHeight };
  }
  return { width: w, height: h };
}

// ─── Gradient System ───────────────────────────────────────────────────

function buildGradientTable(numRows, colorShift = 0) {
  const stops = cfg.GRADIENT_STOPS;
  const numStops = stops.length;
  const table = [];

  for (let row = 0; row < numRows; row++) {
    const t = numRows > 1 ? row / (numRows - 1) : 0;
    const shiftedT = (t + colorShift / numStops) % 1;
    const scaledIdx = shiftedT * (numStops - 1);
    const idx = Math.floor(scaledIdx);
    const frac = scaledIdx - idx;

    const c1 = stops[Math.min(idx, numStops - 1)];
    const c2 = stops[Math.min(idx + 1, numStops - 1)];

    table.push({
      r: Math.round(c1.r + (c2.r - c1.r) * frac),
      g: Math.round(c1.g + (c2.g - c1.g) * frac),
      b: Math.round(c1.b + (c2.b - c1.b) * frac),
    });
  }

  return table;
}

// ─── Renderer State ────────────────────────────────────────────────────
let previousLineCount = 0;
let initialized = false;
let lastLayoutWidth = -1;
let lastLayoutHeight = -1;

// Estado de fade para letras (interpolación entre líneas)
let prevLineIdx = -1;
let fromLineIdx = -1;
let lineChangeTimeMs = 0;

function resetSpectrumRenderer() {
  initialized = false;
  previousLineCount = 0;
  lastLayoutWidth = -1;
  lastLayoutHeight = -1;
  fixedWidth = null;
  fixedHeight = null;
  prevLineIdx = -1;
  fromLineIdx = -1;
  lineChangeTimeMs = 0;
}

function truncate(str, max) {
  return str.length > max ? str.substring(0, max - 1) + "…" : str;
}

function clamp(value, min = 0, max = 1) {
  return Math.max(min, Math.min(max, value));
}

function easeOutCubic(t) {
  const x = clamp(t);
  return 1 - Math.pow(1 - x, 3);
}

function mix(a, b, t) {
  return Math.round(a + (b - a) * clamp(t));
}

function resampleHeights(values, targetLength) {
  if (!values.length || targetLength <= 0) return [];
  if (values.length === targetLength) return values;
  if (targetLength === 1) return [values[0]];

  const result = [];
  const scale = (values.length - 1) / (targetLength - 1);

  for (let i = 0; i < targetLength; i++) {
    const pos = i * scale;
    const left = Math.floor(pos);
    const right = Math.min(values.length - 1, left + 1);
    const t = pos - left;
    result.push(mix(values[left], values[right], t));
  }

  return result;
}

function renderProgressLine(prefix, text, maxTextWidth, progress, activeColor, restColor, bold = true) {
  const clipped = truncate(text, maxTextWidth);
  const split = Math.max(0, Math.min(clipped.length, Math.round(clipped.length * clamp(progress))));
  const active = clipped.slice(0, split);
  const rest = clipped.slice(split);
  const colorActive = bold ? chalk.bold.rgb(activeColor.r, activeColor.g, activeColor.b) : chalk.rgb(activeColor.r, activeColor.g, activeColor.b);
  const colorRest = chalk.rgb(restColor.r, restColor.g, restColor.b);
  return prefix + colorActive(active) + colorRest(rest);
}

function getCurrentLineIdx(lyrics, elapsed) {
  let low = 0;
  let high = lyrics.length - 1;
  let idx = -1;

  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    if (elapsed >= lyrics[mid].time) {
      idx = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return idx;
}

/**
 * Brighten a color by a factor (for beat pulses).
 * More subtle than pure white — preserves the gradient feel.
 */
function brighten(color, amount) {
  return {
    r: Math.min(255, color.r + amount),
    g: Math.min(255, color.g + amount),
    b: Math.min(255, color.b + amount),
  };
}

/**
 * Renderiza un frame completo del visualizador.
 */
function renderSpectrum(state) {
  const {
    bands = [],
    peaks = [],
    numBands = 0,
    beat = {},
    elapsed = 0,
    lyrics = [],
    songTitle = "LyricSync Visualizer",
    totalDuration = 0,
    playing = false,
    finished = false,
    volume = 100,
  } = state;

  const lineIdx = getCurrentLineIdx(lyrics, elapsed);
  const { width: termWidth, height: termHeight } = getTerminalSize();

  // Detección de resize
  if (lastLayoutWidth !== -1 && (termWidth !== lastLayoutWidth || termHeight !== lastLayoutHeight)) {
    initialized = false;
    previousLineCount = 0;
    process.stdout.write("\x1b[2J\x1b[3J\x1b[H");
  }
  lastLayoutWidth = termWidth;
  lastLayoutHeight = termHeight;

  const innerWidth = Math.max(60, Math.min(termWidth - 6, 140));
  // Reservar espacio para: header(4) + baseline(2) + progreso(2) + letras(9) + controles(3) = 20
  const maxHeight = Math.min(cfg.MAX_HEIGHT, Math.max(6, termHeight - 20));
  const effectiveHeight = maxHeight;

  // ─── Construir gradiente para este frame ───────────────────
  const gradient = buildGradientTable(effectiveHeight, beat.colorShift || 0);

  // ─── Beat intensity para pulse visual ──────────────────────
  // intensity decae suavemente (viene del beat-detector)
  const beatIntensity = clamp(beat.intensity || 0);

  // ─── Construir barras del espectro ─────────────────────────
  const bassLimit = Math.ceil(bands.length * 0.3);
  const bassPulse = beat.bassBeat ? cfg.BEAT_HEIGHT_BOOST : 1;
  const barHeights = bands.map((v, i) => {
    const boosted = i < bassLimit ? v * bassPulse : v;
    return Math.round(clamp(boosted) * effectiveHeight);
  });
  const peakHeights = peaks.map((v) => Math.round(clamp(v) * effectiveHeight));

  // ─── Simetría perfecta (sin hueco central) ────────────────
  let displayBars = barHeights;
  let displayPeaks = peakHeights;
  if (cfg.SYMMETRIC && barHeights.length > 0) {
    const right = barHeights;
    const left = [...right].reverse();
    displayBars = [...left, ...right];
    const rightPeaks = peakHeights;
    const leftPeaks = [...rightPeaks].reverse();
    displayPeaks = [...leftPeaks, ...rightPeaks];
  }

  // Estirar el espectro para ocupar mas ancho sin crecer en vertical.
  const maxSpectrumWidth = Math.max(20, termWidth - 8);
  const targetSpectrumWidth = Math.max(
    20,
    Math.min(maxSpectrumWidth, Math.round(innerWidth * 1.2))
  );
  displayBars = resampleHeights(displayBars, targetSpectrumWidth);
  displayPeaks = resampleHeights(displayPeaks, targetSpectrumWidth);

  // Centrar el espectro en la terminal
  const spectrumWidth = displayBars.length;
  const padLeft = Math.max(0, Math.floor((termWidth - spectrumWidth) / 2));
  const padding = " ".repeat(padLeft);

  // Helper: ¿es columna de bajos? (para pulse visual)
  const isBassColumn = (col) => cfg.SYMMETRIC
    ? col < bassLimit || col >= spectrumWidth - bassLimit
    : col < bassLimit;

  const lines = [];

  // ─── Header ────────────────────────────────────────────────
  const headerPad = Math.max(0, Math.floor((termWidth - innerWidth - 4) / 2));
  const hp = " ".repeat(headerPad);
  lines.push(hp + chalk.cyan("╔" + "═".repeat(innerWidth) + "╗"));
  lines.push(hp + chalk.cyan("║") + chalk.bold.white(`  🎵 ${truncate(songTitle, innerWidth - 6).padEnd(innerWidth - 3)}`) + chalk.cyan("║"));
  lines.push(hp + chalk.cyan("╚" + "═".repeat(innerWidth) + "╝"));
  lines.push("");

  // ─── Espectro (dibujado de arriba hacia abajo) ─────────────
  for (let row = effectiveHeight - 1; row >= 0; row--) {
    let rowStr = padding;
    const color = gradient[row];

    for (let col = 0; col < spectrumWidth; col++) {
      const height = displayBars[col];
      const peak = displayPeaks[col];

      if (row < height) {
        // ── Barra sólida ──────────────────────────────────
        if (beat.bassBeat && isBassColumn(col)) {
          // Mejora 5: Beat pulse — iluminar gradiente (no blanco puro)
          // Mezclar color del gradiente hacia blanco según intensidad
          const pulseAmount = Math.round(90 + 60 * beatIntensity);
          const bc = brighten(color, pulseAmount);
          rowStr += chalk.bold.rgb(bc.r, bc.g, bc.b)(cfg.BAR_CHARS.FULL);
        } else {
          rowStr += chalk.rgb(color.r, color.g, color.b)(cfg.BAR_CHARS.FULL);
        }
      } else if (peak > 0 && row === Math.max(0, peak - 1)) {
        // ── Mejora 3: Peak indicator más visible ──────────
        // Más brillante que la barra, con bold para resaltar
        const pr = Math.min(255, color.r + 90);
        const pg = Math.min(255, color.g + 90);
        const pb = Math.min(255, color.b + 90);
        rowStr += chalk.bold.rgb(pr, pg, pb)(cfg.BAR_CHARS.PEAK);
      } else {
        rowStr += " ";
      }
    }

    lines.push(rowStr);
  }

  // ─── Línea base del espectro ───────────────────────────────
  const baseLine = padding + chalk.gray("▁".repeat(spectrumWidth));
  lines.push(baseLine);
  lines.push("");

  // ─── Barra de progreso ─────────────────────────────────────
  const timeInfoLength = 22;
  const barWidth = Math.max(10, innerWidth - timeInfoLength);
  const progress = Math.min(elapsed / (totalDuration || 1), 1);
  const filled = Math.round(progress * barWidth);
  const empty = barWidth - filled;
  const bar = chalk.cyan("█".repeat(filled)) + chalk.gray("░".repeat(empty));
  const statusIcon = finished ? "⏹" : playing ? "▶" : "⏸";
  const statusColor = finished ? chalk.gray : playing ? chalk.green : chalk.yellow;

  lines.push(`  ${statusColor(statusIcon)}  ${bar}  ${chalk.yellow(formatTime(elapsed))} / ${chalk.gray(formatTime(totalDuration))}`);
  lines.push("");

  // ─── Letras con fade/warmup (Mejora 6) ─────────────────────
  const volStr = `[Vol: ${String(volume).padStart(3)}%]`;
  const dashesCount = innerWidth + 2 - 12 - volStr.length - 1;
  lines.push(chalk.cyan("  ── Letras " + "─".repeat(Math.max(0, dashesCount)) + " ") + chalk.cyan.dim(volStr));
  lines.push("");

  // Detectar cambio de línea para fade timing
  const nowMs = Date.now();
  if (lineIdx !== prevLineIdx) {
    fromLineIdx = Math.abs(lineIdx - prevLineIdx) === 1 ? prevLineIdx : -1;
    lineChangeTimeMs = nowMs;
    prevLineIdx = lineIdx;
  }

  // 5 slots fijos para letras — transiciones tipo Spotify
  const lyricSlots = ["", "", "", "", ""];
  if (lineIdx >= 0) {
    // Curva easeOut para transiciones suaves (rápido al inicio, suave al final)
    const easeOut = easeOutCubic;

    // Tiempo desde que cambió la línea actual
    const transition = lineChangeTimeMs
      ? easeOut((nowMs - lineChangeTimeMs) / (cfg.LYRIC_TRANSITION_MS || 650))
      : 1;
    const inLineTransition = fromLineIdx >= 0 && fromLineIdx !== lineIdx && transition < 1;
    const maxLyricWidth = innerWidth - 8;
    const timeSinceChange = transition;

    // ── Slot 0: línea -2 (muy tenue, casi invisible) ──────
    if (lineIdx > 1) {
      lyricSlots[0] = chalk.rgb(75, 75, 75)(`      ${truncate(lyrics[lineIdx - 2].text, innerWidth - 8)}`);
    }

    // ── Slot 1: línea anterior (fade-out suave 1.2s) ──────
    if (lineIdx > 0) {
      const fadeOutT = easeOut(timeSinceChange / 1.2);
      // De blanco cálido → gris oscuro
      const shade = Math.round(185 - 95 * fadeOutT); // 185 → 90
      lyricSlots[1] = chalk.rgb(shade, shade, Math.round(shade * 0.9))(`      ${truncate(lyrics[lineIdx - 1].text, innerWidth - 8)}`);
    }

    // ── Slot 2: línea ACTUAL (fade-in 0.8s con acento Spotify) ──
    const fadeIn = easeOut(timeSinceChange / 0.8);

    // Color Spotify: aparece en gris y se ilumina a verde-cyan brillante
    // Al avanzar la línea, el color evoluciona de verde → cyan → blanco
    const lineProgress = lyrics[lineIdx + 1]
      ? clamp((elapsed - lyrics[lineIdx].time) / (lyrics[lineIdx + 1].time - lyrics[lineIdx].time))
      : clamp((elapsed - lyrics[lineIdx].time) / 3);

    // Base: verde Spotify (#1DB954) → blanco cálido
    const accentR = Math.round((80 + 175 * lineProgress) * fadeIn + 90 * (1 - fadeIn));
    const accentG = Math.round((220 + 35 * lineProgress) * fadeIn + 90 * (1 - fadeIn));
    const accentB = Math.round((100 + 100 * lineProgress) * fadeIn + 90 * (1 - fadeIn));
    const activeColor = { r: accentR, g: accentG, b: accentB };
    const restColor = { r: 105, g: 118, b: 112 };
    const progressFill = inLineTransition
      ? Math.max(0.08, lineProgress * transition)
      : lineProgress;
    lyricSlots[2] = renderProgressLine("  ♪   ", lyrics[lineIdx].text, maxLyricWidth, progressFill, activeColor, restColor);

    // ── Slot 3: siguiente línea (warmup 2.5s antes) ───────
    if (lineIdx < lyrics.length - 1) {
      const nextIn = lyrics[lineIdx + 1].time - elapsed;
      const warmth = easeOut(clamp(1 - nextIn / 2.5));
      // De casi invisible → gris claro preparándose
      const nextR = Math.round(70 + 100 * warmth);
      const nextG = Math.round(70 + 105 * warmth);
      const nextB = Math.round(70 + 95 * warmth);
      lyricSlots[3] = chalk.rgb(nextR, nextG, nextB)(`      ${truncate(lyrics[lineIdx + 1].text, innerWidth - 8)}`);
    }

    // ── Slot 4: línea +2 (apenas visible) ─────────────────
    if (lineIdx < lyrics.length - 2) {
      lyricSlots[4] = chalk.rgb(60, 60, 60)(`      ${truncate(lyrics[lineIdx + 2].text, innerWidth - 8)}`);
    }
  } else {
    lyricSlots[2] = chalk.gray.italic(`  ♪   Esperando que comience la letra...`);
  }
  for (const slot of lyricSlots) lines.push(slot);

  lines.push("");
  lines.push(chalk.cyan("  " + "─".repeat(innerWidth + 2)));

  // ─── Controles ─────────────────────────────────────────────
  if (finished) {
    lines.push(chalk.bold.green("  ✅ ¡Canción terminada!"));
    lines.push(chalk.gray("     👉 Pulsa [Enter] o [Espacio] para volver al menú principal..."));
  } else {
    const footerStr = playing
      ? `[Espacio] Pausar   [← →] ±10 seg   [↑ ↓] Volumen   [Q/Esc] Salir`
      : `[Espacio] Reanudar   [← →] ±10 seg   [↑ ↓] Volumen   [Q/Esc] Salir`;
    lines.push(chalk.gray("  " + footerStr));
    lines.push("");
  }

  // ─── Rellenar hasta altura segura ──────────────────────────
  const maxSafeHeight = Math.max(5, termHeight - 1);
  if (lines.length > maxSafeHeight) {
    lines.length = maxSafeHeight;
  }

  // ─── Flush atómico (1 solo write) ──────────────────────────
  let output = "";

  if (!initialized) {
    output += "\n".repeat(lines.length);
    output += `\x1b[${lines.length}A\x1b[1G`;
    initialized = true;
  } else if (previousLineCount > 0) {
    output += `\x1b[${previousLineCount}A\x1b[1G`;
  }

  for (const line of lines) {
    output += line + "\x1b[K\n";
  }

  output += "\x1b[J\r\x1b[1G";
  process.stdout.write(output);

  previousLineCount = lines.length;
  return lineIdx;
}

module.exports = { renderSpectrum, resetSpectrumRenderer, getCurrentLineIdx };
