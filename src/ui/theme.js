const path = require("path");
const chalk = require("chalk");
const stripAnsi = require("strip-ansi");

const INDENT = "  ";
const MAX_WIDTH = 120;
const MIN_WIDTH = 72;

function width() {
  const columns = process.stdout.columns || 100;
  return Math.max(MIN_WIDTH, Math.min(columns - 4, MAX_WIDTH));
}

function clip(text, max) {
  const value = String(text ?? "");
  if (value.length <= max) return value;
  if (max <= 3) return value.slice(0, max);
  return `${value.slice(0, max - 3)}...`;
}

function visibleLength(text) {
  return stripAnsi(String(text ?? "")).length;
}

function fitLine(text, max) {
  const value = String(text ?? "");
  if (visibleLength(value) > max) return clip(stripAnsi(value), max);
  return value + " ".repeat(Math.max(0, max - visibleLength(value)));
}

function clear() {
  // \x1b[2J = limpiar pantalla
  // \x1b[3J = limpiar scrollback buffer (critico para que inquirer no entre al historial)
  // \x1b[H  = cursor al origen (0,0)
  process.stdout.write("\x1b[2J\x1b[3J\x1b[H");
}

function header(subtitle = "IA offline para letras sincronizadas") {
  clear();
  const w = width();
  const title = chalk.bold.rgb(86, 200, 255)("LYRICSYNC");
  const tag = chalk.gray(subtitle);
  console.log(`${INDENT}${title} ${chalk.gray("·")} ${tag}`);
  console.log(`${INDENT}${chalk.dim("─".repeat(w))}`);
  console.log("");
}

function box(title, rows, options = {}) {
  const w = options.width || width();
  const titleText = title ? ` ${title} ` : "";
  const topFill = Math.max(0, w - titleText.length - 2);
  const lines = [
    `${INDENT}${chalk.cyan("╭" + titleText + "─".repeat(topFill) + "╮")}`,
  ];

  for (const row of rows) {
    const text = String(row ?? "");
    lines.push(`${INDENT}${chalk.cyan("│")} ${fitLine(text, w - 4)} ${chalk.cyan("│")}`);
  }

  lines.push(`${INDENT}${chalk.cyan("╰" + "─".repeat(w - 2) + "╯")}`);
  console.log(lines.join("\n"));
  console.log("");
}

function kv(label, value) {
  return `${chalk.dim(label.padEnd(10))} ${chalk.white(value)}`;
}

function pill(text, tone = "muted") {
  const colors = {
    ok: chalk.green,
    warn: chalk.yellow,
    danger: chalk.red,
    info: chalk.cyan,
    muted: chalk.gray,
  };
  return (colors[tone] || colors.muted)(`[${text}]`);
}

function section(label) {
  return chalk.magenta(`  ${label}`);
}

function separator(label = "") {
  const inquirer = require("inquirer");
  return new inquirer.Separator(label ? chalk.dim(`  ${label}`) : " ");
}

function songChoice(filePath, status, maxNameWidth) {
  const name = clip(path.basename(filePath, path.extname(filePath)), maxNameWidth);
  const state = status === "sync" ? pill("SYNC", "ok") : pill("PENDIENTE", "warn");
  const displayName = status === "sync"
    ? `${chalk.white(name)} ${state}`
    : `${chalk.gray(name)} ${state}`;
  return { name: `  ${displayName}`, value: filePath };
}

function actionChoice(label, description, value, tone = "info") {
  const color = {
    ok: chalk.green,
    warn: chalk.yellow,
    danger: chalk.red,
    info: chalk.cyan,
    muted: chalk.gray,
  }[tone] || chalk.cyan;
  const desc = description ? chalk.dim(`  ${description}`) : "";
  return { name: `  ${color(label.padEnd(31))}${desc}`, value };
}

function footer(text = "↑↓ Mover   Enter Seleccionar   Esc Volver") {
  console.log(`${INDENT}${chalk.dim("─".repeat(width()))}`);
  console.log(`${INDENT}${chalk.gray(text)}`);
  console.log("");
}

function notice(title, body, tone = "info") {
  const color = {
    ok: chalk.green,
    warn: chalk.yellow,
    danger: chalk.red,
    info: chalk.cyan,
  }[tone] || chalk.cyan;
  console.log("");
  console.log(`${INDENT}${color(title)}`);
  if (body) console.log(`${INDENT}${chalk.gray(body)}`);
  console.log("");
}

module.exports = {
  INDENT,
  actionChoice,
  box,
  clear,
  clip,
  footer,
  fitLine,
  header,
  kv,
  notice,
  pill,
  section,
  separator,
  songChoice,
  visibleLength,
  width,
};
