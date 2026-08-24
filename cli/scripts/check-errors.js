#!/usr/bin/env node
// Titofy — Copyright (C) 2026 Titofy
// Licensed under GNU General Public License v3.0 or later.
//
// check-errors.js — Buscador Universal de Errores para todo el proyecto Titofy
// Analiza Python (backend/), JavaScript (cli/) y Dart (desktop/) en una sola pasada.
//
// Uso:
//   node scripts/check-errors.js           # analizar todo
//   node scripts/check-errors.js --python  # solo backend Python
//   node scripts/check-errors.js --js      # solo cli JavaScript
//   node scripts/check-errors.js --dart    # solo desktop Dart
//   node scripts/check-errors.js --fix     # modo verbose con hints de corrección

const { execSync, spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// ─── Configuración ────────────────────────────────────────────────────────────
const ROOT = path.resolve(__dirname, "..", "..");
const BACKEND = path.join(ROOT, "backend");
const CLI = path.join(ROOT, "cli");
const DESKTOP = path.join(ROOT, "desktop");

const args = process.argv.slice(2);
const RUN_PYTHON = args.length === 0 || args.includes("--python");
const RUN_JS = args.length === 0 || args.includes("--js");
const RUN_DART = args.length === 0 || args.includes("--dart");
const VERBOSE = args.includes("--fix") || args.includes("--verbose") || args.includes("-v");

// ─── Estilos ANSI ─────────────────────────────────────────────────────────────
const C = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  magenta: "\x1b[35m",
  white: "\x1b[37m",
  bgRed: "\x1b[41m",
  bgGreen: "\x1b[42m",
};

const W = Math.min(process.stdout.columns || 100, 120);

function hr(char = "─") { return char.repeat(W); }
function header(title, icon = "🔍") {
  console.log();
  console.log(C.bold + C.cyan + `  ╭${"─".repeat(W - 4)}╮` + C.reset);
  console.log(C.bold + C.cyan + `  │  ${icon}  ${title}`.padEnd(W - 2) + "│" + C.reset);
  console.log(C.bold + C.cyan + `  ╰${"─".repeat(W - 4)}╯` + C.reset);
  console.log();
}

function ok(msg) { console.log(`  ${C.green}✅${C.reset} ${msg}`); }
function warn(msg) { console.log(`  ${C.yellow}⚠️ ${C.reset} ${msg}`); }
function err(msg) { console.log(`  ${C.red}❌${C.reset} ${msg}`); }
function info(msg) { console.log(`  ${C.cyan}ℹ️ ${C.reset} ${msg}`); }
function section(msg) { console.log(`\n${C.bold}${C.white}  ${msg}${C.reset}`); console.log(C.dim + "  " + hr() + C.reset); }

// ─── Utilidades ───────────────────────────────────────────────────────────────
function cmd(command, options = {}) {
  try {
    const output = execSync(command, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
      cwd: options.cwd || ROOT,
      ...options,
    });
    return { ok: true, output: output.trim(), code: 0 };
  } catch (e) {
    return {
      ok: false,
      output: ((e.stdout || "") + "\n" + (e.stderr || "")).trim(),
      code: e.status || 1,
    };
  }
}

function which(bin) {
  const r = cmd(`which ${bin}`);
  return r.ok ? r.output.trim() : null;
}

function countLines(output) {
  return output.split("\n").filter(Boolean).length;
}

// ─── Totales globales ─────────────────────────────────────────────────────────
let totalErrors = 0;
let totalWarnings = 0;
const summary = [];

// ─────────────────────────────────────────────────────────────────────────────
// PYTHON — pyflakes (errores de imports, variables no usadas, etc.)
// ─────────────────────────────────────────────────────────────────────────────
function runPython() {
  header("Backend Python — pyflakes + py_compile", "🐍");

  // Detectar intérprete
  const pythonBin = which("python3") || which("python");
  if (!pythonBin) {
    err("Python no encontrado en PATH. Instala Python 3.11+.");
    summary.push({ lang: "Python", status: "skipped", errors: 0, warns: 0 });
    return;
  }
  info(`Intérprete: ${pythonBin}`);

  // Verificar si pyflakes está disponible
  const hasFlakes = cmd(`${pythonBin} -m pyflakes --version`).ok;
  if (!hasFlakes) {
    warn("pyflakes no está instalado. Instálalo con: pip install pyflakes");
  }

  // Recopilar archivos Python del proyecto (excluir .venv y __pycache__)
  const findResult = cmd(
    `find "${BACKEND}" -name "*.py" -not -path "*/.venv/*" -not -path "*/__pycache__/*" -not -path "*/build/*"`,
  );
  const pyFiles = findResult.output.split("\n").filter(Boolean);

  section(`📄 Archivos Python encontrados: ${pyFiles.length}`);

  let pyErrors = 0;
  let pyWarns = 0;

  // py_compile — detecta errores de sintaxis básicos
  section("🔎 Verificación de Sintaxis (py_compile)");
  for (const file of pyFiles) {
    const r = cmd(`${pythonBin} -m py_compile "${file}"`);
    const rel = path.relative(ROOT, file);
    if (!r.ok) {
      err(`${rel}\n       ${r.output.replace(/\n/g, "\n       ")}`);
      pyErrors++;
    }
  }
  if (pyErrors === 0) ok("Cero errores de sintaxis en archivos Python.");

  // pyflakes — detecta imports faltantes, variables sin usar, etc.
  if (hasFlakes) {
    section("🔎 Análisis de Imports y Variables (pyflakes)");
    const flakeExcludes = [".venv", "__pycache__", "build"];
    const filesToCheck = pyFiles.join('" "');
    const r = cmd(`${pythonBin} -m pyflakes "${filesToCheck}"`);

    if (r.output) {
      const lines = r.output.split("\n").filter(Boolean);
      for (const line of lines) {
        const rel = line.replace(ROOT + "/", "");
        if (rel.includes("undefined name") || rel.includes("unable to detect") || rel.includes("syntax error")) {
          err(rel);
          pyErrors++;
        } else {
          warn(rel);
          pyWarns++;
        }
      }
    }

    if (pyErrors === 0 && pyWarns === 0) ok("Cero problemas de imports/variables en Python.");
  }

  totalErrors += pyErrors;
  totalWarnings += pyWarns;
  summary.push({ lang: "Python (backend)", status: pyErrors > 0 ? "fail" : "ok", errors: pyErrors, warns: pyWarns });
}

// ─────────────────────────────────────────────────────────────────────────────
// JAVASCRIPT — Node.js require() check + eslint (si está disponible)
// ─────────────────────────────────────────────────────────────────────────────
function runJS() {
  header("CLI JavaScript — Syntax + ESLint", "🟨");

  const nodeBin = which("node");
  if (!nodeBin) {
    err("Node.js no encontrado en PATH.");
    summary.push({ lang: "JavaScript", status: "skipped", errors: 0, warns: 0 });
    return;
  }
  info(`Node.js: ${nodeBin}`);

  // Verificar si ESLint está disponible como script del proyecto
  const eslintBin = path.join(CLI, "node_modules", ".bin", "eslint");
  const hasEslint = fs.existsSync(eslintBin);
  if (!hasEslint) {
    warn("ESLint no encontrado en cli/node_modules. Ejecuta: npm install --save-dev eslint");
  }

  // Recopilar archivos JS del CLI
  const findResult = cmd(
    `find "${CLI}/src" "${CLI}/index.js" "${CLI}/generate-lrc.js" -name "*.js" -not -path "*/node_modules/*" 2>/dev/null`,
  );
  const jsFiles = findResult.output.split("\n").filter(Boolean);

  section(`📄 Archivos JavaScript encontrados: ${jsFiles.length}`);

  let jsErrors = 0;
  let jsWarns = 0;

  // Verificación de sintaxis con node --check
  section("🔎 Verificación de Sintaxis (node --check)");
  for (const file of jsFiles) {
    const r = cmd(`node --check "${file}"`);
    const rel = path.relative(ROOT, file);
    if (!r.ok) {
      err(`${rel}\n       ${r.output.replace(/\n/g, "\n       ")}`);
      jsErrors++;
    }
  }
  if (jsErrors === 0) ok("Cero errores de sintaxis en archivos JavaScript.");

  // ESLint si disponible
  if (hasEslint) {
    section("🔎 Análisis de Estilo y Errores (ESLint)");
    const r = cmd(`"${eslintBin}" src/ index.js generate-lrc.js --format compact 2>&1`, { cwd: CLI });
    if (r.output) {
      const lines = r.output.split("\n").filter(Boolean);
      for (const line of lines) {
        if (line.includes(": error:") || line.includes(" Error ")) {
          err(line.replace(CLI + "/", ""));
          jsErrors++;
        } else if (line.includes(": warning:") || line.includes(" Warning ")) {
          warn(line.replace(CLI + "/", ""));
          jsWarns++;
        } else if (VERBOSE && line.trim()) {
          console.log("  " + C.dim + line.replace(CLI + "/", "") + C.reset);
        }
      }
    }
    if (jsErrors === 0 && jsWarns === 0) ok("Cero problemas ESLint en JavaScript.");
  }

  // Verificar requires inexistentes + exports nombrados
  section("🔎 Verificación de requires() Locales y Exports Nombrados");
  let missingRequires = 0;

  for (const file of jsFiles) {
    const content = fs.readFileSync(file, "utf-8");
    const rel = path.relative(ROOT, file);

    // Detectar todos los require locales (que empiezan con . o ..)
    const allRequires = [...content.matchAll(/(?:const\s*(\{[^}]+\})|const\s+\w+)\s*=\s*require\(['"](\.[^'"]+)['"]\)/g)];

    for (const match of allRequires) {
      const destructuring = match[1]; // e.g. "{ foo, bar }"
      const reqPath = match[2];
      const resolved = path.resolve(path.dirname(file), reqPath);
      const extensions = [".js", "/index.js", ".json"];

      // 1. Verificar que el archivo existe
      const filePath = extensions.map((ext) => resolved + ext).concat([resolved]).find((p) => fs.existsSync(p));
      if (!filePath) {
        err(`${rel}\n       require('${reqPath}') → archivo no encontrado`);
        jsErrors++;
        missingRequires++;
        continue;
      }

      // 2. Si hay destructuring, verificar que los nombres existen como exports
      if (destructuring && filePath.endsWith(".js")) {
        const names = destructuring
          .replace(/[{}]/g, "")
          .split(",")
          .map((n) => n.trim().split(/\s+as\s+/)[0].trim())
          .filter(Boolean);

        if (names.length > 0) {
          try {
            const targetContent = fs.readFileSync(filePath, "utf-8");
            // Buscar module.exports = { ... } o exports.xxx
            const exportsMatch = targetContent.match(/module\.exports\s*=\s*\{([^}]+)\}/s);
            if (exportsMatch) {
              const exportedNames = exportsMatch[1]
                .split(",")
                .map((n) => n.trim().split(":")[0].trim().split("\n").pop().trim())
                .filter((n) => /^[a-zA-Z_$]/.test(n));

              for (const name of names) {
                if (!exportedNames.includes(name)) {
                  err(`${rel}\n       { ${name} } de require('${reqPath}') → '${name}' no está en module.exports`);
                  jsErrors++;
                  missingRequires++;
                }
              }
            }
          } catch (_) { /* si no se puede leer, ignorar */ }
        }
      }
    }
  }
  if (missingRequires === 0) ok("Todos los require() locales y sus exports resuelven correctamente.");

  totalErrors += jsErrors;
  totalWarnings += jsWarns;
  summary.push({ lang: "JavaScript (cli)", status: jsErrors > 0 ? "fail" : "ok", errors: jsErrors, warns: jsWarns });
}

// ─────────────────────────────────────────────────────────────────────────────
// DART — flutter analyze (si está disponible)
// ─────────────────────────────────────────────────────────────────────────────
function runDart() {
  header("Desktop Flutter/Dart — flutter analyze", "💙");

  const flutterBin = which("flutter");
  if (!flutterBin) {
    warn("Flutter no encontrado en PATH. Saltando análisis Dart.");
    summary.push({ lang: "Dart (desktop)", status: "skipped", errors: 0, warns: 0 });
    return;
  }
  info(`Flutter: ${flutterBin}`);

  section("🔎 Análisis de Dart (flutter analyze)");
  const r = cmd(`flutter analyze --no-pub 2>&1`, { cwd: DESKTOP });

  let dartErrors = 0;
  let dartWarns = 0;

  if (r.output) {
    const lines = r.output.split("\n").filter(Boolean);
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith("error ·") || trimmed.startsWith("  error")) {
        err(trimmed.replace(DESKTOP + "/", ""));
        dartErrors++;
      } else if (trimmed.startsWith("warning ·") || trimmed.startsWith("  warning")) {
        warn(trimmed.replace(DESKTOP + "/", ""));
        dartWarns++;
      } else if (trimmed.startsWith("info ·") && VERBOSE) {
        info(trimmed.replace(DESKTOP + "/", ""));
      }
    }
  }

  if (dartErrors === 0 && dartWarns === 0) ok("Cero errores/warnings en Dart.");

  totalErrors += dartErrors;
  totalWarnings += dartWarns;
  summary.push({ lang: "Dart (desktop)", status: dartErrors > 0 ? "fail" : "ok", errors: dartErrors, warns: dartWarns });
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────────────
const startTime = Date.now();

console.clear();
console.log();
console.log(C.bold + C.magenta + "  ╔" + "═".repeat(W - 4) + "╗" + C.reset);
console.log(C.bold + C.magenta + "  ║" + " TITOFY — BUSCADOR UNIVERSAL DE ERRORES".padEnd(W - 4) + "║" + C.reset);
console.log(C.bold + C.magenta + "  ╚" + "═".repeat(W - 4) + "╝" + C.reset);
console.log();

if (RUN_PYTHON) runPython();
if (RUN_JS) runJS();
if (RUN_DART) runDart();

// ─── Resumen Final ────────────────────────────────────────────────────────────
const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

console.log();
console.log(C.bold + "  ╔" + "═".repeat(W - 4) + "╗" + C.reset);
console.log(C.bold + "  ║  📊  RESUMEN FINAL".padEnd(W - 2) + "║" + C.reset);
console.log(C.bold + "  ╠" + "═".repeat(W - 4) + "╣" + C.reset);

for (const s of summary) {
  const icon = s.status === "ok" ? "✅" : s.status === "skipped" ? "⏭️ " : "❌";
  const errStr = s.errors > 0 ? C.red + `${s.errors} error(es)` + C.reset : C.dim + "0 errores" + C.reset;
  const warnStr = s.warns > 0 ? C.yellow + `${s.warns} warning(s)` + C.reset : C.dim + "0 warnings" + C.reset;
  const line = `  ║  ${icon}  ${s.lang.padEnd(22)} ${errStr}   ${warnStr}`;
  console.log(line);
}

console.log(C.bold + "  ╠" + "═".repeat(W - 4) + "╣" + C.reset);

if (totalErrors === 0) {
  console.log(C.bold + C.green + `  ║  🎉  Sin errores encontrados · ${elapsed}s`.padEnd(W - 2) + "║" + C.reset);
} else {
  console.log(C.bold + C.red + `  ║  ❌  ${totalErrors} error(es) total · ${totalWarnings} warning(s) · ${elapsed}s`.padEnd(W - 2) + "║" + C.reset);
}

console.log(C.bold + "  ╚" + "═".repeat(W - 4) + "╝" + C.reset);
console.log();

process.exit(totalErrors > 0 ? 1 : 0);
