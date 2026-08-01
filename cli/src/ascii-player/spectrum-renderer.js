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

function mixFloat(a, b, t) {
  return a + (b - a) * clamp(t);
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
    result.push(mixFloat(values[left], values[right], t));
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
  const beatIntensity = clamp(beat.intensity || 0);

  // ─── Construir alturas flotantes del espectro ─────────────
  const bassLimit = Math.ceil(bands.length * 0.3);
  const bassPulse = beat.bassBeat ? (cfg.BEAT_HEIGHT_BOOST || 1.15) : 1;
  const barHeights = bands.map((v, i) => {
    const boosted = i < bassLimit ? v * bassPulse : v;
    return clamp(boosted) * effectiveHeight;
  });
  const peakHeights = peaks.map((v) => clamp(v) * effectiveHeight);

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

  // Estirar el espectro para ocupar más ancho sin crecer en vertical.
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

  const subBlocks = cfg.BAR_CHARS.SUB_BLOCKS || [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"];
  const peakChar = cfg.BAR_CHARS.PEAK || "▀";

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

  // ─── Espectro (dibujado de arriba hacia abajo con Sub-Blocks Unicode) ─────────────
  for (let row = effectiveHeight - 1; row >= 0; row--) {
    let rowStr = padding;
    const color = gradient[row];

    for (let col = 0; col < spectrumWidth; col++) {
      const floatHeight = displayBars[col];
      const peakFloat = displayPeaks[col];

      const fullRowThreshold = row + 1;
      const rowFloor = row;

      if (floatHeight >= fullRowThreshold) {
        // ── Barra sólida de bloque entero ────────────────
        rowStr += chalk.rgb(color.r, color.g, color.b)(subBlocks[7]);
      } else if (floatHeight > rowFloor) {
        // ── Sub-block de alta resolución vertical (8 niveles) ──
        const frac = floatHeight - rowFloor;
        const subIndex = Math.min(7, Math.max(1, Math.floor(frac * 8)));
        rowStr += chalk.rgb(color.r, color.g, color.b)(subBlocks[subIndex]);
      } else if (peakFloat > floatHeight + 0.1 && Math.floor(peakFloat) === row) {
        // ── Peak Hold (marcador flotante blanco solo por encima de la barra) ─────────
        rowStr += chalk.bold.rgb(255, 255, 255)(peakChar);
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
    const easeOut = easeOutCubic;
    // Transición dura lo configurado o 600ms
    const transitionDuration = cfg.LYRIC_TRANSITION_MS || 600;
    const transition = lineChangeTimeMs
      ? easeOut((nowMs - lineChangeTimeMs) / transitionDuration)
      : 1;

    const inLineTransition = fromLineIdx >= 0 && fromLineIdx !== lineIdx && transition < 1;
    const maxLyricWidth = innerWidth - 8;

    const isFirstHalf = inLineTransition && transition < 0.5;
    const baseIdx = isFirstHalf ? lineIdx - 1 : lineIdx;

    const texts = [
      (baseIdx > 1) ? lyrics[baseIdx - 2].text : "",
      (baseIdx > 0) ? lyrics[baseIdx - 1].text : "",
      lyrics[baseIdx].text,
      (baseIdx < lyrics.length - 1) ? lyrics[baseIdx + 1].text : "",
      (baseIdx < lyrics.length - 2) ? lyrics[baseIdx + 2].text : "",
    ];

    const activeColorBase = { r: 57, g: 255, b: 20 }; // Verde neón
    const restColorBase = { r: 95, g: 95, b: 95 };     // Gris opaco

    const getProgressOf = (idx) => {
      if (idx < 0 || idx >= lyrics.length) return 0;
      const nextTime = lyrics[idx + 1] ? lyrics[idx + 1].time : lyrics[idx].time + 3;
      const duration = nextTime - lyrics[idx].time;
      return clamp((elapsed - lyrics[idx].time) / (duration || 1));
    };

    if (inLineTransition) {
      const factorActive = transition;
      const factorOldActive = 1 - transition;

      const colorNewActive = {
        r: mix(restColorBase.r, activeColorBase.r, factorActive),
        g: mix(restColorBase.g, activeColorBase.g, factorActive),
        b: mix(restColorBase.b, activeColorBase.b, factorActive),
      };

      const colorOldActive = {
        r: mix(restColorBase.r, activeColorBase.r, factorOldActive),
        g: mix(restColorBase.g, activeColorBase.g, factorOldActive),
        b: mix(restColorBase.b, activeColorBase.b, factorOldActive),
      };

      if (isFirstHalf) {
        lyricSlots[0] = texts[0] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[0], maxLyricWidth)}`) : "";
        lyricSlots[1] = texts[1] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[1], maxLyricWidth)}`) : "";

        const prog2 = getProgressOf(lineIdx - 1);
        lyricSlots[2] = renderProgressLine("  ♪   ", texts[2], maxLyricWidth, prog2, colorOldActive, restColorBase);

        const prog3 = getProgressOf(lineIdx);
        lyricSlots[3] = texts[3] ? renderProgressLine("      ", texts[3], maxLyricWidth, prog3, colorNewActive, restColorBase, false) : "";

        lyricSlots[4] = texts[4] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[4], maxLyricWidth)}`) : "";
      } else {
        lyricSlots[0] = texts[0] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[0], maxLyricWidth)}`) : "";

        const prog1 = getProgressOf(lineIdx - 1);
        lyricSlots[1] = texts[1] ? renderProgressLine("      ", texts[1], maxLyricWidth, prog1, colorOldActive, restColorBase, false) : "";

        const prog2 = getProgressOf(lineIdx);
        lyricSlots[2] = renderProgressLine("  ♪   ", texts[2], maxLyricWidth, prog2, colorNewActive, restColorBase);

        lyricSlots[3] = texts[3] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[3], maxLyricWidth)}`) : "";
        lyricSlots[4] = texts[4] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[4], maxLyricWidth)}`) : "";
      }
    } else {
      lyricSlots[0] = texts[0] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[0], maxLyricWidth)}`) : "";
      lyricSlots[1] = texts[1] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[1], maxLyricWidth)}`) : "";

      const prog2 = getProgressOf(lineIdx);
      lyricSlots[2] = renderProgressLine("  ♪   ", texts[2], maxLyricWidth, prog2, activeColorBase, restColorBase);

      lyricSlots[3] = texts[3] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[3], maxLyricWidth)}`) : "";
      lyricSlots[4] = texts[4] ? chalk.rgb(restColorBase.r, restColorBase.g, restColorBase.b)(`      ${truncate(texts[4], maxLyricWidth)}`) : "";
    }
  } else {
    lyricSlots[2] = chalk.rgb(95, 95, 95).italic(`  ♪   Esperando que comience la letra...`);
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
