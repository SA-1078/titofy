/**
 * renderer.js — Renderizado del reproductor en terminal
 * Dibuja la interfaz del reproductor sobreescribiendo líneas (sin parpadeo).
 */

const chalk = require("chalk");
const { formatTime } = require("./lrc-parser");
const os = require('os');

// ─── SAFE MODE GEOMETRÍA ─────────────────────────────────────
const isWindows = os.platform() === 'win32';
const isCmd = !process.env.WT_SESSION && !process.env.TERM_PROGRAM;

const isVSCode = 
  process.env.TERM_PROGRAM === 'vscode' ||
  process.env.VSCODE_PID !== undefined ||
  process.env.VSCODE_INJECTION === '1';

const FORCE_SAFE_MODE = process.env.SAFE_MODE === 'true' || isWindows;
const SAFE_MODE = FORCE_SAFE_MODE || isVSCode || isCmd;

let fixedWidth = null;
let fixedHeight = null;

function getTerminalSize() {
  let w = process.stdout.columns || 110;
  let h = process.stdout.rows || 30;

  if (SAFE_MODE) {
    // En SAFE_MODE (especialmente Windows CMD) usamos tamaño "fijo" pero lo actualizamos siempre
    if (!fixedWidth || w < fixedWidth - 5 || w > fixedWidth + 5) {  // tolerancia de 5 columnas
      fixedWidth = w;
    }
    if (!fixedHeight || h < fixedHeight - 3 || h > fixedHeight + 3) {
      fixedHeight = h;
    }
    return { width: fixedWidth, height: fixedHeight };
  }

  return { width: w, height: h };
}

let previousLineCount = 0;
let initialized = false;
let lastLayoutWidth = -1;
let lastLayoutHeight = -1;

// Estado de transición para letras
let prevLineIdx = -1;
let fromLineIdx = -1;
let lineChangeTimeMs = 0;

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

function renderProgressLine(prefix, text, maxTextWidth, progress, activeColor, restColor, bold = true) {
  const clipped = truncate(text, maxTextWidth);
  const split = Math.max(0, Math.min(clipped.length, Math.round(clipped.length * clamp(progress))));
  const active = clipped.slice(0, split);
  const rest = clipped.slice(split);
  const colorActive = bold ? chalk.bold.rgb(activeColor.r, activeColor.g, activeColor.b) : chalk.rgb(activeColor.r, activeColor.g, activeColor.b);
  const colorRest = chalk.rgb(restColor.r, restColor.g, restColor.b);
  return prefix + colorActive(active) + colorRest(rest);
}

/**
 * Trunca un string a un máximo de caracteres.
 */
function truncate(str, max) {
  return str.length > max ? str.substring(0, max - 1) + "…" : str;
}

/**
 * Encuentra el índice de la línea de letras activa según el tiempo transcurrido.
 */
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
 * Renderiza el reproductor completo en la terminal.
 * Usa \x1b[H para mover el cursor al inicio y sobreescribir (sin console.clear).
 *
 * @param {object} state - Estado actual del reproductor
 * @param {number} state.elapsed       - Tiempo transcurrido en segundos
 * @param {Array}  state.lyrics        - Array de {time, text}
 * @param {string} state.songTitle     - Título de la canción
 * @param {number} state.totalDuration - Duración total en segundos
 * @param {boolean} state.playing      - Si está reproduciendo
 * @param {boolean} state.finished     - Si la canción terminó
 * @returns {number} Índice de la línea actual de letras
 */
function render(state) {
  const { elapsed, lyrics, songTitle, totalDuration, playing, finished, volume } = state;

  const lineIdx = getCurrentLineIdx(lyrics, elapsed);

  // Detección dinámica o fija según el SAFE_MODE
  const { width: termWidth, height: termHeight } = getTerminalSize();

  // Detección inline de reflow + resize (Cura fuerte para Windows CMD)
  if (lastLayoutWidth !== -1 && (termWidth !== lastLayoutWidth || termHeight !== lastLayoutHeight)) {
    initialized = false;
    previousLineCount = 0; // ← importante

    // Siempre limpiamos fuerte cuando hay resize/reflow real
    process.stdout.write("\x1b[2J\x1b[3J\x1b[H"); 
  }
  lastLayoutWidth = termWidth;
  lastLayoutHeight = termHeight;

  const innerWidth = Math.max(60, Math.min(termWidth - 6, 140));

  // Barra de progreso adaptativa
  const timeInfoLength = 22; // Espacio que ocupan los relojes y los íconos laterales
  const barWidth = innerWidth - timeInfoLength;
  const progress = Math.min(elapsed / (totalDuration || 1), 1);
  const filled   = Math.round(progress * barWidth);
  const empty    = barWidth - filled;
  const bar      = chalk.cyan("█".repeat(filled)) + chalk.gray("░".repeat(empty));
  const statusIcon  = finished ? "⏹" : playing ? "▶" : "⏸";
  const statusColor = finished ? chalk.gray : playing ? chalk.green : chalk.yellow;

  const TOTAL_LINES = termHeight >= 32 ? 30 : 20; // Si hay altura, dar 30 líneas para logo. Si no, 20.
  const lines = [];

  // ─── Centrar e Inyectar Logo Principal (Si hay Pantalla Suficiente) ───
  if (termHeight >= 32) {
    const logoBoxWidth = 80;
    const paddingLeft = Math.max(0, Math.floor((termWidth - logoBoxWidth) / 2));
    const p = " ".repeat(paddingLeft);

    lines.push(p + chalk.magenta("  ████████╗██╗████████╗ ██████╗ ███████╗██╗   ██╗     ██████╗███╗   ███╗██████╗ "));
    lines.push(p + chalk.magenta("  ╚══██╔══╝██║╚══██╔══╝██╔═══██╗██╔════╝╚██╗ ██╔╝    ██╔════╝████╗ ████║██╔══██╗"));
    lines.push(p + chalk.cyan("     ██║   ██║   ██║   ██║   ██║█████╗   ╚████╔╝     ██║     ██╔████╔██║██║  ██║"));
    lines.push(p + chalk.cyan("     ██║   ██║   ██║   ██║   ██║██╔══╝    ╚██╔╝      ██║     ██║╚██╔╝██║██║  ██║"));
    lines.push(p + chalk.blue("     ██║   ██║   ██║   ╚██████╔╝██║        ██║       ╚██████╗██║ ╚═╝ ██║██████╔╝"));
    lines.push(p + chalk.blue("     ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚═╝        ╚═╝        ╚═════╝╚═╝     ╚═╝╚═════╝ "));
    lines.push("");
    lines.push(p + chalk.gray("         ✦  Inteligencia Artificial Offline — Modo Terminal v1.0  ✦"));
    lines.push("");
  }

  // ─── Header Adaptativo ─────────────────────────────────────
  lines.push(chalk.cyan("  ╔" + "═".repeat(innerWidth) + "╗"));
  lines.push(chalk.cyan("  ║") + chalk.bold.white(`  🎵 ${truncate(songTitle, innerWidth - 6).padEnd(innerWidth - 5)}`) + chalk.cyan("║"));
  lines.push(chalk.cyan("  ╚" + "═".repeat(innerWidth) + "╝"));
  lines.push("");

  // ─── Barra de progreso ─────────────────────────────────────
  lines.push(`  ${statusColor(statusIcon)}  ${bar}  ${chalk.yellow(formatTime(elapsed))} / ${chalk.gray(formatTime(totalDuration))}`);
  lines.push("");

  // ─── Letras ────────────────────────────────────────────────
  const volStr = `[Vol: ${String(volume).padStart(3)}%]`;
  const dashesCount = innerWidth + 2 - 12 - volStr.length - 1; 
  lines.push(chalk.cyan("  ── Letras " + "─".repeat(Math.max(0, dashesCount)) + " ") + chalk.cyan.dim(volStr));
  lines.push("");

  // 5 slots fijos para letras (mantiene altura constante)
  const lyricSlots = ["", "", "", "", ""];
  const nowMs = Date.now();
  if (lineIdx !== prevLineIdx) {
    fromLineIdx = Math.abs(lineIdx - prevLineIdx) === 1 ? prevLineIdx : -1;
    lineChangeTimeMs = nowMs;
    prevLineIdx = lineIdx;
  }

  if (lineIdx >= 0) {
    const easeOut = easeOutCubic;
    const transition = lineChangeTimeMs
      ? easeOut((nowMs - lineChangeTimeMs) / 600)
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
    lines.push(chalk.cyan("  " + "─".repeat(innerWidth + 2)));
  } else {
    const footerStr = playing 
      ? `[Espacio] Pausar   [← →] ±10 seg   [↑ ↓] Volumen   [Q/Esc] Salir`
      : `[Espacio] Reanudar   [← →] ±10 seg   [↑ ↓] Volumen   [Q/Esc] Salir`;
    lines.push(chalk.gray("  " + footerStr));
    lines.push(""); // placeholder para mantener altura constante
  }

  // Rellenar hasta TOTAL_LINES
  while (lines.length < TOTAL_LINES) lines.push("");

  // NUNCA exceder la altura física de la terminal. Previene "Infinite Scroll Loop"
  const maxSafeHeight = Math.max(5, termHeight - 1);
  if (lines.length > maxSafeHeight) {
    lines.length = maxSafeHeight;
  }

  let output = "";

  if (!initialized) {
    // Primera vez: Emite retornos de carro puros para "empujar" el historial hacia arriba.
    output += "\n".repeat(lines.length);
    output += `\x1b[${lines.length}A\x1b[1G`; // Sube la cantidad exacta a dibujar
    initialized = true;
  } else if (previousLineCount > 0) {
    // Siguiente cuadro: Solo sube las líneas que bajó físicamente
    output += `\x1b[${previousLineCount}A\x1b[1G`;
  }
  
  for (const line of lines) {
    output += line + "\x1b[K\n"; // escribir + borrar resto de esa línea
  }
  
  // Borrar ghosting y asegurar anclaje horizontal puro
  output += "\x1b[J\r\x1b[1G"; 
  
  process.stdout.write(output);
  
  previousLineCount = lines.length;
  return lineIdx;
}

// Reset de estado visual por si se re-abre el player múltiples veces
function resetRenderer() {
  initialized = false;
  previousLineCount = 0;
  lastLayoutWidth = -1;
  lastLayoutHeight = -1;
  // Reiniciar geometry caches cuando se cierre completamente el script si fuera necesario.
  fixedWidth = null;
  fixedHeight = null;
  prevLineIdx = -1;
  fromLineIdx = -1;
  lineChangeTimeMs = 0;
}

module.exports = { render, getCurrentLineIdx, resetRenderer, SAFE_MODE };
