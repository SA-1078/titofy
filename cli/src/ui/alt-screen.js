/**
 * alt-screen.js — Alternate screen buffer + Custom list selector
 *
 * Módulo independiente para romper la dependencia circular entre
 * menu-core.js y menu-actions.js.
 */

const chalk = require("chalk");
const readline = require("readline");
const inquirer = require("inquirer");

// ─── Alternate Screen Buffer ──────────────────────────────────────────────
function enterAltScreen() {
  process.stdout.write("\x1b[?1049h\x1b[H\x1b[J");
}

function exitAltScreen() {
  process.stdout.write("\x1b[?1049l");
}

// ─── Custom List Selector ─────────────────────────────────────────────────
// Sustituye inquirer's list para evitar el bug de scroll infinito.
// Técnica: redibuja el frame completo desde \x1b[H en cada keypress.
// El diseño nunca desborda porque siempre empezamos desde (0,0).
//
// @param {Function} renderHeader — Función que imprime el header (void)
// @param {Array}    choices      — Array de { name, value } + Separators
// @param {string}   message      — Texto del prompt
// @returns {Promise<any>}        — Valor seleccionado
function customList(renderHeader, choices, message) {
  return new Promise((resolve) => {
    // Clasificar items
    const items = choices.map((c) => ({
      name: c.name || (c.line ? c.line : " "),
      value: c.value,
      isSep: c instanceof inquirer.Separator || c.type === "separator",
    }));

    const navigable = items.filter((c) => !c.isSep && c.value !== undefined);
    let cursorPos = 0;
    let scrollOffset = 0;

    function pageSize() {
      const rows = process.stdout.rows || 24;
      // header 11 líneas + prompt 1 + hint 1 + buffer 1 = 14 fijos
      return Math.max(3, rows - 14);
    }

    function adjustScroll() {
      const ps = pageSize();
      if (cursorPos < scrollOffset) scrollOffset = cursorPos;
      if (cursorPos >= scrollOffset + ps) scrollOffset = cursorPos - ps + 1;
    }

    function render() {
      adjustScroll();
      const ps = pageSize();

      // ── Capturar salida del header ──────────────────────────────────────
      let headerOut = "";
      const origWrite = process.stdout.write.bind(process.stdout);
      process.stdout.write = (s) => { headerOut += s; return true; };
      renderHeader();
      process.stdout.write = origWrite;
      // ───────────────────────────────────────────────────────────────────

      // ── Construir frame completo ────────────────────────────────────────
      let frame = "\x1b[H"; // cursor al origen (0,0)
      frame += headerOut;
      frame += `  ${chalk.cyan("›")} ${message}\x1b[K\n`;

      // Construir lista aplanada (items + separadores en orden)
      let navI = 0;
      let rendered = 0;
      let inWindow = false;
      let windowStart = 0;

      // Encontrar el índice del primer item navegable visible (scrollOffset)
      let navCount = 0;
      let startItemIdx = 0;
      for (let i = 0; i < items.length; i++) {
        if (!items[i].isSep && items[i].value !== undefined) {
          if (navCount === scrollOffset) { startItemIdx = i; break; }
          navCount++;
        }
      }

      // Renderizar desde startItemIdx hasta llenar pageSize
      let navRendered = 0;
      let i = startItemIdx;

      // Si el separador inmediatamente anterior al startItemIdx no está incluido,
      // buscarlo y mostrarlo para contexto visual
      if (startItemIdx > 0 && items[startItemIdx - 1].isSep) {
        const sep = items[startItemIdx - 1];
        frame += `  ${chalk.dim(sep.name)}\x1b[K\n`;
      }

      while (i < items.length && navRendered < ps) {
        const item = items[i];
        if (item.isSep) {
          frame += `  ${chalk.dim(item.name)}\x1b[K\n`;
        } else {
          const realNavIdx = navigable.indexOf(item);
          if (realNavIdx === -1) { i++; continue; }
          const isSelected = realNavIdx === cursorPos;
          const prefix = isSelected ? chalk.cyan(">") : " ";
          const text = isSelected ? chalk.bold(item.name) : item.name;
          frame += `  ${prefix} ${text}\x1b[K\n`;
          navRendered++;
        }
        i++;
      }

      // Hint si hay más
      if (navigable.length > ps) {
        frame += chalk.dim(`  (↑↓ para ver más)\x1b[K\n`);
      } else {
        frame += "\x1b[K\n";
      }

      frame += "\x1b[J"; // limpiar resto de pantalla
      process.stdout.write(frame);
    }

    // ── Teclado ────────────────────────────────────────────────────────────
    readline.emitKeypressEvents(process.stdin);
    if (process.stdin.isTTY) {
      try { process.stdin.setRawMode(true); } catch { }
    }
    process.stdin.resume();

    function cleanup() {
      process.stdin.removeListener("keypress", listener);
      if (process.stdin.isTTY) {
        try { process.stdin.setRawMode(false); } catch { }
      }
      // Pausar stdin para que inquirer pueda tomarlo limpiamente en Windows
      process.stdin.pause();
    }

    const listener = (str, key) => {
      if (!key) return;

      if ((key.ctrl && key.name === "c") || key.name === "q") {
        cleanup();
        exitAltScreen();
        process.exit(0);
      }

      if (key.name === "up") {
        cursorPos = Math.max(0, cursorPos - 1);
        render();
        return;
      }
      if (key.name === "down") {
        cursorPos = Math.min(navigable.length - 1, cursorPos + 1);
        render();
        return;
      }
      if (key.name === "return" || key.name === "enter") {
        const selectedValue = navigable[cursorPos].value;
        cleanup();
        // Pequeño defer para que el event loop procese el pause antes de que
        // inquirer intente reanudar stdin en el siguiente prompt
        setImmediate(() => resolve(selectedValue));
        return;
      }
    };

    process.stdin.on("keypress", listener);
    render();
  });
}

module.exports = { enterAltScreen, exitAltScreen, customList };
