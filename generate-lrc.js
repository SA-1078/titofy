#!/usr/bin/env node
/**
 * generate-lrc.js — Titofy CMD
 * Genera un archivo .lrc sincronizado a partir de un archivo de audio
 * usando Whisper local (100% offline, sin API key).
 *
 * Uso:
 *   node generate-lrc.js <audio>
 *   node generate-lrc.js song.mp3 --language es
 *   node generate-lrc.js song.mp3 --model small --language es
 *   node generate-lrc.js song.mp3 --words          (timestamp por palabra)
 *
 * Modelos:
 *   turbo  → súper rápido, precisión extrema (large-v3)  ← lo mejor
 *   small  → buen balance calidad/velocidad  ← el bueno
 *   base   → rápido, baja precisión  ← el rápido
 */

const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const { resolvePython } = require("./src/python-resolver");
// ─── Parsear argumentos ────────────────────────────────────────────────────────
const args = process.argv.slice(2);

if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
  console.log(`
🎵 Titofy CMD — Generador de letras offline con Whisper

Uso:
  node generate-lrc.js <audio> [opciones]

Opciones:
  --output  -o  <archivo.lrc>   Nombre del archivo de salida
  --model   -m  <modelo>        Modelo Whisper a usar (default: small)
  --language -l <codigo>        Forzar idioma: es, en, pt, fr... (default: auto)
  --words                       Timestamps por PALABRA (más preciso)
  --force                       Regenerar aunque ya exista el .lrc

Modelos:
  turbo  → Súper rápido, precisión extrema (large-v3)  ← lo mejor de lo mejor
  small  → Buen balance calidad/velocidad  ← el bueno
  base   → Rápido, menor precisión  ← el rápido

Ejemplos:
  node generate-lrc.js song.mp3
  node generate-lrc.js song.mp3 --language es
  node generate-lrc.js song.mp3 --model turbo --language es
  node generate-lrc.js song.mp3 --words --language es
  node generate-lrc.js "C:\\Music\\cancion.mp3" --output letras.lrc
`);
  process.exit(0);
}

const audioFile = args[0];

function optionIndex(...names) {
  const indexes = names.map((name) => args.indexOf(name)).filter((idx) => idx !== -1);
  return indexes.length ? Math.min(...indexes) : -1;
}

const outputIndex = optionIndex("--output", "-o");
const outputWasExplicit = outputIndex !== -1 && args[outputIndex + 1];
const lrcDir = path.join(__dirname, "lrc");
const defaultOutputFile = path.join(lrcDir, path.basename(audioFile, path.extname(audioFile)) + ".lrc");
const outputFile = outputWasExplicit
  ? path.resolve(args[outputIndex + 1])
  : defaultOutputFile;

const modelIndex = args.indexOf("--model") !== -1 ? args.indexOf("--model") : args.indexOf("-m");
const model = modelIndex !== -1 && args[modelIndex + 1] ? args[modelIndex + 1] : "small";

const langIndex = args.indexOf("--language") !== -1 ? args.indexOf("--language") : args.indexOf("-l");
const language = langIndex !== -1 && args[langIndex + 1] ? args[langIndex + 1] : null;

const wordMode = args.includes("--words");
const force = args.includes("--force");

// ─── Validar archivo de entrada ───────────────────────────────────────────────
if (!fs.existsSync(audioFile)) {
  console.error(`❌ No se encontró el archivo: ${audioFile}`);
  process.exit(1);
}

// ─── Ruta al script Python ────────────────────────────────────────────────────
const scriptPath = path.join(__dirname, "whisper_transcribe.py");

if (!fs.existsSync(scriptPath)) {
  console.error("❌ No se encontró whisper_transcribe.py en la carpeta del proyecto.");
  process.exit(1);
}

if (!fs.existsSync(lrcDir)) {
  fs.mkdirSync(lrcDir, { recursive: true });
}

// ─── Cargar PATH del sistema (necesario para que ffmpeg sea encontrado) ───────
const { execSync } = require("child_process");

function getSystemPath() {
  try {
    // Leer el PATH del sistema y del usuario desde el registro de Windows
    const machinePath = execSync(
      'powershell -Command "[System.Environment]::GetEnvironmentVariable(\'PATH\', \'Machine\')"',
      { encoding: "utf-8" }
    ).trim();
    const userPath = execSync(
      'powershell -Command "[System.Environment]::GetEnvironmentVariable(\'PATH\', \'User\')"',
      { encoding: "utf-8" }
    ).trim();
    return `${machinePath};${userPath}`;
  } catch {
    return process.env.PATH; // fallback al PATH actual
  }
}

// ─── Ejecutar script Python ───────────────────────────────────────────────────
const pythonArgs = [scriptPath, audioFile, "--output", outputFile, "--model", model];

if (language) pythonArgs.push("--language", language);
if (wordMode) pythonArgs.push("--words");

const env = { ...process.env, PATH: getSystemPath() };
const pythonBin = resolvePython(env);

if (!pythonBin) {
  console.error("❌ No se encontró Python disponible.");
  console.error("   Instala Python 3.11+ o define la variable PYTHON con la ruta al ejecutable.");
  process.exit(1);
}

const existingLrc = fs.existsSync(outputFile)
  ? outputFile
  : (!outputWasExplicit && fs.existsSync(defaultOutputFile) ? defaultOutputFile : null);

if (existingLrc && !force) {
  console.log("");
  console.log(`✅ Ya existe el archivo LRC: ${path.relative(__dirname, existingLrc)}`);
  console.log("   Saltando Whisper y abriendo el reproductor directamente.");
  console.log("   Usa --force si quieres regenerar la letra.");
  console.log("");

  const playerArgs = [
    path.join(__dirname, "index.js"),
    "--audio", path.resolve(audioFile),
    "--lrc", existingLrc,
  ];

  const player = spawn(process.execPath, playerArgs, { stdio: "inherit", env });
  player.on("error", (err) => {
    console.error(`❌ Error al abrir el reproductor: ${err.message}`);
    process.exit(1);
  });
  player.on("close", (code) => process.exit(code || 0));
  return;
}

const proc = spawn(pythonBin, pythonArgs, { stdio: "inherit", env });

proc.on("error", (err) => {
  if (err.code === "ENOENT") {
    console.error("❌ Python no está instalado o no está en el PATH.");
    console.error("   Descárgalo en: https://www.python.org/downloads/");
  } else {
    console.error(`❌ Error al ejecutar Python: ${err.message}`);
  }
  process.exit(1);
});

proc.on("close", (code) => {
  if (code !== 0) {
    console.error(`\n❌ El script de Python terminó con código de error: ${code}`);
    process.exit(code);
  }
});
