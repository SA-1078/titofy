/**
 * Titofy — Copyright (C) 2026 Titofy
 * Licensed under GNU General Public License v3.0 or later.
 *
 * menu-actions.js — Acciones Individuales de Pista y Flujos de la CLI
 */

const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const { prompt } = require("./prompt");
const ui = require("./theme");
const { exitAltScreen, enterAltScreen, customList } = require("./alt-screen");
const { chooseModel, confirmSlowModel, modelChoices } = require("./model-selector");
const { batchGenerateMenu } = require("./batch-ui");

const {
  SYSTEM_ENV,
  getLrcPath,
  hasLrc,
  formatFileName,
  getLyricsConfig,
} = require("../config");

const { startPlayer } = require("../player");
const { startAsciiPlayer } = require("../ascii-player");
const { LyricSyncAPI } = require("../api-client");
const { resolvePython } = require("../python-resolver");

async function pause(message = "Presiona Enter para volver") {
  try {
    return await prompt([{
      type: "input",
      name: "_",
      message: chalk.gray(message),
    }]);
  } catch (err) {
    if (err.name === "ExitPromptError" || err.message?.includes("force closed")) {
      process.stdout.write("\x1b[?25h\x1b[?7h\x1b[?1049l\x1b[0m\x1b[2J\x1b[3J\x1b[H");
      process.exit(0);
    }
  }
}

function lrcLineCount(lrcPath) {
  if (!fs.existsSync(lrcPath)) return 0;
  return fs.readFileSync(lrcPath, "utf-8")
    .split(/\r?\n/)
    .filter((line) => /^\[\d/.test(line))
    .length;
}

function showLyricsPreview(lrcPath, mode = "online", maxLines = 8) {
  if (!fs.existsSync(lrcPath)) return;
  const lines = fs.readFileSync(lrcPath, "utf-8")
    .split(/\r?\n/)
    .filter((l) => l.startsWith("[") && !l.startsWith("[ti") && !l.startsWith("[by") && !l.startsWith("[ar") && !l.startsWith("[al"));

  if (lines.length === 0) return;

  let titleLabel = "📋 Preview de letras obtenidas:";
  if (mode === "ai" || mode === "ai_generated") {
    titleLabel = "📋 Preview de letras generadas con IA:";
  } else if (mode === "aligned" || mode === "online_aligned") {
    titleLabel = "📋 Preview de letras alineadas:";
  } else if (mode === "online" || mode === "online_synced") {
    titleLabel = "📋 Preview de letras obtenidas online:";
  }

  console.log(`\n  ${titleLabel}`);
  console.log(chalk.gray("  " + "─".repeat(56)));
  lines.slice(0, maxLines).forEach((line) => {
    console.log(`     ${chalk.cyan(line.slice(0, 10))} ${line.slice(10)}`);
  });
  if (lines.length > maxLines) {
    console.log(chalk.gray(`     ... y ${lines.length - maxLines} líneas más`));
  }
  console.log(chalk.gray("  " + "─".repeat(56)) + "\n");
}


function renderTrackHeader(audioPath) {
  const lrcPath = getLrcPath(audioPath);
  const synced = fs.existsSync(lrcPath);
  const rows = [
    ui.kv("Pista", ui.clip(formatFileName(audioPath), ui.width() - 18)),
    ui.kv("Archivo", ui.clip(audioPath, ui.width() - 17)),
    synced
      ? `${ui.kv("Estado", `${ui.pill("SYNC", "ok")}  ${lrcLineCount(lrcPath)} lineas sincronizadas`)}`
      : `${ui.kv("Estado", `${ui.pill("PENDIENTE", "warn")}  faltan letras`)}`,
  ];

  ui.header("Acciones de pista");
  ui.box("Pista", rows);
}

async function resolveHybridLyrics(audioPath, options = {}) {
  const lrcPath = getLrcPath(audioPath);
  const fileName = formatFileName(audioPath);
  let artist = null;
  let title = fileName;

  if (fileName.includes(" - ")) {
    const parts = fileName.split(" - ");
    artist = parts[0].trim();
    title = parts.slice(1).join(" - ").trim();
  }

  ui.header(options.force ? "Regenerando Letras (Modo Hibrido)" : "Obteniendo Letras (Modo Hibrido)");
  ui.box("Pista", [
    ui.kv("Pista", ui.clip(fileName, ui.width() - 18)),
    ui.kv("Estrategia", "Online (LRCLIB / Lyrics.ovh) → Whisper IA Local"),
  ]);

  console.log(chalk.cyan("  🔍 Buscando en proveedores online (LRCLIB / Lyrics.ovh)..."));

  const api = new LyricSyncAPI();
  const isApiReady = await api.ensureServerRunning();

  if (isApiReady) {
    try {
      const res = await api.resolveLyrics(artist, title, {
        audioPath,
        mode: "auto",
        language: "auto",
        outputPath: lrcPath,
        force: true,
        timeout: 60000,
      });

      if (res && res.lines && res.lines.length > 0 && fs.existsSync(lrcPath)) {
        const source = res.source || "online_synced";
        const lineCount = res.lines.length;

        if (source === "online_aligned" || (res.provider && res.provider.includes("calibrado"))) {
          ui.notice(
            "🎯 Letra oficial obtenida y calibrada con tu audio en tiempo real",
            `Fuente texto: ${res.provider || "LRCLIB"} · ${lineCount} líneas sincronizadas con Whisper IA`,
            "ok"
          );
        } else {
          ui.notice(
            "⚡ Letras sincronizadas obtenidas al instante",
            `Fuente: ${res.provider || "LRCLIB"} · ${lineCount} líneas sincronizadas`,
            "ok"
          );
        }

        showLyricsPreview(lrcPath, "aligned");
        return true;
      }

    } catch {
      // No encontrado online — continuar a Whisper local
    }
  }


  // ── No se encontró online: Avisar explícitamente y ejecutar Whisper con barra ──
  console.log(chalk.yellow("\n  ⚠️  No se encontraron letras en proveedores online para esta pista."));
  console.log(chalk.cyan("  🤖 Iniciando transcripción local con IA (Whisper)...\n"));

  const success = await generateLrc(audioPath, "small", "es");
  if (success) {
    ui.notice(
      "🤖 Transcripción IA completada",
      `Motor: Whisper local · ${lrcLineCount(lrcPath)} líneas sincronizadas`,
      "ok"
    );
  }
  return success;
}


async function generateLrc(audioPath, model = "small", language = "auto") {
  const lrcPath = getLrcPath(audioPath);
  const scriptPath = path.join(__dirname, "..", "..", "..", "backend", "whisper_transcribe.py");
  const pythonBin = resolvePython(SYSTEM_ENV);

  if (!pythonBin) {
    ui.notice("Python no disponible", "Instala Python 3.11+ o define la variable PYTHON con la ruta al ejecutable.", "danger");
    return false;
  }

  const success = await new Promise((resolve) => {
    const proc = spawn(
      pythonBin,
      [scriptPath, audioPath, "--output", lrcPath, "--model", model, "--language", language, "--force"],
      { stdio: "inherit", env: SYSTEM_ENV }
    );

    proc.on("close", (code) => {
      resolve(code === 0);
    });

    proc.on("error", () => {
      ui.notice("Python no disponible", "Instala Python 3.11+ y verifica que este en PATH.", "danger");
      resolve(false);
    });
  });

  if (success && fs.existsSync(lrcPath)) {
    showLyricsPreview(lrcPath, "ai");
  }

  return success;
}


async function alignLyrics(audioPath) {
  const lrcPath = getLrcPath(audioPath);

  ui.header("Alineacion forzada");
  ui.box("Pista", [
    ui.kv("Pista", ui.clip(formatFileName(audioPath), ui.width() - 18)),
    ui.kv("Salida", `lrc/${path.basename(lrcPath)}`),
  ]);

  const { lyricsSource } = await prompt([{
    type: "list",
    name: "lyricsSource",
    message: "Fuente de letras",
    choices: [
      ui.actionChoice("Archivo de texto", "Usar un .txt existente", "file", "info"),
      ui.actionChoice("Pegar en terminal", "Termina con FIN en una linea", "input", "info"),
      ui.separator(),
      ui.actionChoice("Volver", "Regresar al menu de pista", "back", "muted"),
    ],
    pageSize: 6,
  }]);

  if (lyricsSource === "back") return;

  let lyricsText = "";

  if (lyricsSource === "file") {
    const { txtPath } = await prompt([{
      type: "input",
      name: "txtPath",
      message: "Ruta del .txt con letras",
    }]);

    const cleanPath = txtPath.trim().replace(/^"|"$/g, "");
    if (!fs.existsSync(cleanPath)) {
      ui.notice("Archivo no encontrado", cleanPath, "danger");
      return;
    }
    lyricsText = fs.readFileSync(cleanPath, "utf-8");
  } else {
    ui.notice("Pegar letras", "Escribe una linea por vez. Usa FIN para terminar.", "info");
    const lines = [];
    while (true) {
      const { line } = await prompt([{
        type: "input",
        name: "line",
        message: ">",
      }]);
      if (line.trim().toUpperCase() === "FIN") break;
      lines.push(line);
    }
    lyricsText = lines.join("\n");
  }

  if (!lyricsText.trim()) {
    ui.notice("Cancelado", "El texto de letras esta vacio.", "warn");
    return;
  }

  ui.notice("Alineacion", `Sincronizando ${lyricsText.split(/\r?\n/).length} linea(s)...`, "info");

  const scriptPath = path.join(__dirname, "..", "..", "..", "backend", "whisper_align.py");
  const tempTxt = path.join(__dirname, "..", "..", "_temp_lyrics.txt");
  fs.writeFileSync(tempTxt, lyricsText, "utf-8");
  const pythonBin = resolvePython(SYSTEM_ENV);

  if (!pythonBin) {
    try { fs.unlinkSync(tempTxt); } catch { }
    ui.notice("Python no disponible", "Instala Python 3.11+ o define la variable PYTHON con la ruta al ejecutable.", "danger");
    return false;
  }

  return new Promise((resolve) => {
    const proc = spawn(
      pythonBin,
      [scriptPath, audioPath, "--lyrics", tempTxt, "--output", lrcPath, "--language", "es"],
      { stdio: "inherit", env: SYSTEM_ENV }
    );

    proc.on("close", (code) => {
      try { fs.unlinkSync(tempTxt); } catch { }

      if (code === 0) {
        ui.notice("Alineacion completada", `Guardado en lrc/${path.basename(lrcPath)}`, "ok");
      } else {
        ui.notice("Alineacion fallida", `Python salio con codigo ${code}.`, "danger");
      }
      resolve(code === 0);
    });

    proc.on("error", () => {
      try { fs.unlinkSync(tempTxt); } catch { }
      ui.notice("Python no disponible", "Instala Python 3.11+ y verifica que este en PATH.", "danger");
      resolve(false);
    });
  });
}

async function playSong(audioPath) {
  const lrcPath = getLrcPath(audioPath);

  if (!fs.existsSync(lrcPath)) {
    ui.notice("Faltan letras", "Genera o alinea letras antes de reproducir esta pista.", "warn");
    return;
  }

  ui.notice("Iniciando reproductor", path.basename(audioPath), "info");
  await startPlayer(audioPath, lrcPath, SYSTEM_ENV);
}

async function playSongVisualizer(audioPath) {
  const lrcPath = getLrcPath(audioPath);

  if (!fs.existsSync(lrcPath)) {
    ui.notice("Faltan letras", "Genera o alinea letras antes de usar el visualizador.", "warn");
    return;
  }

  await startAsciiPlayer(audioPath, lrcPath, SYSTEM_ENV);
}

async function inspectLrc(audioPath) {
  const lrcPath = getLrcPath(audioPath);
  if (!fs.existsSync(lrcPath)) {
    ui.notice("Faltan letras", "Aun no existe archivo .lrc para esta pista.", "warn");
    return;
  }

  const content = fs.readFileSync(lrcPath, "utf-8");
  const lines = content.split(/\r?\n/).filter(Boolean);

  ui.header("Inspeccion de letras");
  ui.box("Archivo LRC", [
    ui.kv("Pista", ui.clip(formatFileName(audioPath), ui.width() - 18)),
    ui.kv("Ruta", ui.clip(lrcPath, ui.width() - 16)),
    ui.kv("Lineas", String(lines.length)),
  ]);

  console.log(chalk.bold("  📜 Primeras lineas del archivo:"));
  console.log(chalk.gray("  " + "─".repeat(Math.min(ui.width(), 64))));
  lines.slice(0, 12).forEach((line) => {
    if (line.startsWith("[")) {
      console.log(`     ${chalk.cyan(line.slice(0, 10))} ${line.slice(10)}`);
    } else {
      console.log(`     ${line}`);
    }
  });
  console.log(chalk.gray("  " + "─".repeat(Math.min(ui.width(), 64))) + "\n");

  await pause();
}

async function alignOnlineLyricsWithLocalAudio(audioPath) {
  const lrcPath = getLrcPath(audioPath);
  const fileName = formatFileName(audioPath);
  let artist = null;
  let title = fileName;

  if (fileName.includes(" - ")) {
    const parts = fileName.split(" - ");
    artist = parts[0].trim();
    title = parts.slice(1).join(" - ").trim();
  }

  ui.header("Alineacion con Audio Local");
  ui.box("Pista", [
    ui.kv("Pista", ui.clip(fileName, ui.width() - 18)),
    ui.kv("Estrategia", "Descarga texto oficial y lo sincroniza con tu audio local exacto"),
  ]);

  console.log(chalk.cyan("  🔍 Obteniendo texto oficial y alineando con tu audio..."));

  const api = new LyricSyncAPI();
  const isApiReady = await api.ensureServerRunning();

  if (isApiReady) {
    try {
      const res = await api.resolveLyrics(artist, title, {
        audioPath,
        mode: "online_align",
        language: "es",
        outputPath: lrcPath,
        force: true,
        timeout: 60000,
      });

      if (res && res.lines && res.lines.length > 0 && fs.existsSync(lrcPath)) {
        ui.notice(
          "🎯 Letra oficial alineada milimetricamente con tu audio",
          `Fuente: ${res.provider || "Online"} · ${res.lines.length} lineas sincronizadas`,
          "ok"
        );
        showLyricsPreview(lrcPath, "aligned");
        return true;
      }
    } catch (err) {
      ui.notice("Aviso de alineacion", err.message, "warn");
    }
  }

  ui.notice("No se pudo alinear online", "Prueba con transcripcion directa de Whisper o archivo .txt", "warn");
  return false;
}

async function regenerateLyricsMenu(audioPath) {
  ui.header("Regenerar Letras");
  ui.box("Pista", [
    ui.kv("Pista", ui.clip(formatFileName(audioPath), ui.width() - 18)),
    ui.kv("Accion", "Reemplazar la letra actual con un nuevo procesamiento"),
  ]);

  const { method } = await prompt([{
    type: "list",
    name: "method",
    message: "Selecciona el metodo de regeneracion",
    choices: [
      ui.actionChoice("1. Automatico (Hibrido: Online + Calibracion IA)", "Busca texto oficial y lo calibra con tu audio local (Recomendado)", "resolve", "ok"),
      ui.actionChoice("2. Solo IA local (Whisper)", "Transcribir audio offline forzando Whisper desde cero", "gen", "info"),
      ui.actionChoice("3. Forced Alignment (.txt local)", "Sincronizar una letra desde archivo .txt", "align", "info"),
      ui.separator(),
      ui.actionChoice("Volver", "Cancelar y regresar al menu de pista", "back", "muted"),
    ],
    pageSize: 6,
  }]);

  if (method === "back" || !method) return;

  if (method === "resolve") {
    await resolveHybridLyrics(audioPath, { force: true });
    await pause();
  } else if (method === "gen") {
    const model = await chooseModel();
    if (model !== "__back__") {
      const ok = await confirmSlowModel(model, 1);
      if (ok) {
        ui.header("Generando letras");
        ui.notice("Iniciando Whisper local", `Modelo: ${model}`, "info");
        const okGen = await generateLrc(audioPath, model);
        if (okGen) {
          ui.notice("Transcribir completado", "El archivo .lrc se actualizo correctamente.", "ok");
        }
        await pause();
      }
    }
  } else if (method === "align") {
    await alignLyrics(audioPath);
    await pause();
  }
}



async function trackMenu(audioPath) {
  while (true) {
    const synced = hasLrc(audioPath);

    const choices = [];

    if (synced) {
      // Pista con letras sincronizadas: Opciones principales de reproductor
      choices.push(ui.actionChoice("Visualizador ASCII (Espectro PRO)", "Reproducir con visualizador animado de frecuencias", "play_viz", "ok"));
      choices.push(ui.actionChoice("Reproductor clasico", "Reproducir audio con sincronizacion de letras clasica", "play", "info"));
      choices.push(ui.actionChoice("Ver contenido del .lrc", "Inspeccionar marcas de tiempo y texto", "inspect", "info"));
      choices.push(ui.separator("Mantenimiento"));
      choices.push(ui.actionChoice("Regenerar letras", "Elegir metodo: Automatico (Online+IA), Solo Whisper o .txt", "regenerate", "muted"));
    } else {
      // Pista pendiente de letras
      choices.push(ui.actionChoice("Obtener letras (Modo Hibrido: Online + IA)", "Busca online (LRCLIB), alinea o genera con Whisper", "resolve", "ok"));
      choices.push(ui.actionChoice("Generar solo con IA local (Whisper)", "Transcribir audio offline sin consultar internet", "gen", "info"));
      choices.push(ui.actionChoice("Forced Alignment (Alinear .txt)", "Sincronizar una letra de texto que ya tengas", "align", "info"));
    }

    choices.push(ui.separator());
    choices.push(ui.actionChoice("Volver al menu", "Regresar a la biblioteca", "back", "muted"));

    const action = await customList(
      () => renderTrackHeader(audioPath),
      choices,
      "Selecciona una accion"
    );

    if (action === "back" || action === null || action === undefined) return;

    exitAltScreen();

    if (action === "play_viz") {
      await playSongVisualizer(audioPath);
    } else if (action === "play") {
      await playSong(audioPath);
    } else if (action === "inspect") {
      await inspectLrc(audioPath);
    } else if (action === "resolve") {
      await resolveHybridLyrics(audioPath);
      await pause();
    } else if (action === "regenerate") {
      await regenerateLyricsMenu(audioPath);
    } else if (action === "gen") {
      const model = await chooseModel();
      if (model !== "__back__") {
        const ok = await confirmSlowModel(model, 1);
        if (ok) {
          ui.header("Generando letras");
          ui.notice("Iniciando Whisper local", `Modelo: ${model}`, "info");
          const okGen = await generateLrc(audioPath, model);
          if (okGen) {
            ui.notice("Transcribir completado", "El archivo .lrc se creo correctamente.", "ok");
          }
          await pause();
        }
      }
    } else if (action === "align") {
      await alignLyrics(audioPath);
      await pause();
    }

    enterAltScreen();
  }
}

// Alias de compatibilidad: menu-core.js importa songActionMenu
const songActionMenu = trackMenu;

module.exports = {
  trackMenu,
  songActionMenu,
  regenerateLyricsMenu,
  batchGenerateMenu,
  pause,
  chooseModel,
  confirmSlowModel,
  generateLrc,
  resolveHybridLyrics,
  alignLyrics,
  playSong,
  playSongVisualizer,
};


