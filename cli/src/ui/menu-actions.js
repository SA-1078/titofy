const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const { prompt } = require("./prompt");
const ui = require("./theme");
const { exitAltScreen, enterAltScreen, customList } = require("./alt-screen");

const {
  SYSTEM_ENV,
  getLrcPath,
  hasLrc,
  formatFileName,
} = require("../config");

const { startPlayer } = require("../player");
const { startAsciiPlayer } = require("../ascii-player");
const { LyricSyncAPI } = require("../api-client");
const { BatchProcessor } = require("../batch-worker");
const { resolvePython } = require("../python-resolver");

function pause(message = "Presiona Enter para volver") {
  return prompt([{
    type: "input",
    name: "_",
    message: chalk.gray(message),
  }]);
}

function lrcLineCount(lrcPath) {
  if (!fs.existsSync(lrcPath)) return 0;
  return fs.readFileSync(lrcPath, "utf-8")
    .split(/\r?\n/)
    .filter((line) => /^\[\d/.test(line))
    .length;
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

function modelChoices(backValue = "__back__") {
  return [
    ui.actionChoice("turbo", "turbo   · Lo mejor (calidad profesional + velocidad)", "turbo", "ok"),
    ui.actionChoice("small", "small   · Balance ideal para la mayoria de canciones", "small", "info"),
    ui.actionChoice("base", "base    · Rapido (equipos lentos)", "base", "muted"),
    ui.separator(),
    ui.actionChoice("Volver", "Regresar sin cambios", backValue, "muted"),
  ];
}

async function chooseModel(title = "Modelo de transcripcion") {
  ui.header(title);
  ui.box("Guia de modelos", [
    ui.kv("turbo", "Lo mejor (calidad profesional + velocidad)"),
    ui.kv("small", "Balance ideal para la mayoria de canciones"),
    ui.kv("base", "Rapido (equipos lentos)"),
  ]);
  ui.footer();

  const { model } = await prompt([{
    type: "list",
    name: "model",
    message: "Selecciona modelo",
    choices: modelChoices(),
    default: "small",
    pageSize: 8,
  }]);

  return model;
}

async function confirmSlowModel(model, count = 1) {
  return true;
}

async function generateLrc(audioPath, model = "small", language = "es") {
  const lrcPath = getLrcPath(audioPath);
  const api = new LyricSyncAPI();

  if (await api.isRunning()) {
    try {
      const { task_id } = await api.transcribe(audioPath, model, language);
      await api.waitForCompletion(task_id, (status, progress) => {
        const pct = String(progress).padStart(3);
        process.stdout.write(`\r  → Transcribiendo... [${pct}%]`);
      });
      process.stdout.write("\n");
    } catch (err) {
      ui.notice("Fallback de API", err.message, "warn");
    }
  }

  const scriptPath = path.join(__dirname, "..", "..", "..", "backend", "whisper_transcribe.py");
  const pythonBin = resolvePython(SYSTEM_ENV);

  if (!pythonBin) {
    ui.notice("Python no disponible", "Instala Python 3.11+ o define la variable PYTHON con la ruta al ejecutable.", "danger");
    return false;
  }

  const success = await new Promise((resolve) => {
    const proc = spawn(
      pythonBin,
      [scriptPath, audioPath, "--output", lrcPath, "--model", model, "--language", language],
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
    const { showLyrics } = await prompt([{
      type: "confirm",
      name: "showLyrics",
      message: "¿Deseas ver el resumen de letras?",
      default: false,
    }]);

    if (showLyrics) {
      const lines = fs.readFileSync(lrcPath, "utf-8")
        .split(/\r?\n/)
        .filter((l) => l.startsWith("[") && !l.startsWith("[ti") && !l.startsWith("[by"));

      console.log("\n  📋 Resumen de letras:");
      console.log(chalk.gray("  " + "─".repeat(56)));
      lines.slice(0, 8).forEach((line) => {
        console.log(`     ${chalk.cyan(line.slice(0, 10))} ${line.slice(10)}`);
      });
      if (lines.length > 8) {
        console.log(chalk.gray(`     ... y ${lines.length - 8} líneas más`));
      }
      console.log(chalk.gray("  " + "─".repeat(56)) + "\n");
    }
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

  ui.notice("Iniciando visualizador de espectro", path.basename(audioPath), "info");
  await startAsciiPlayer(audioPath, lrcPath, SYSTEM_ENV);
}

async function batchGenerateMenu(audioFiles) {
  const withoutLrc = audioFiles.filter((file) => !hasLrc(file));

  ui.header("Procesamiento por lotes");

  if (withoutLrc.length === 0) {
    ui.box("Lote", [
      ui.kv("Estado", `${ui.pill("LISTO", "ok")} Todas las pistas ya tienen letras`),
    ]);
    await pause();
    return;
  }

  ui.box("Lote", [
    ui.kv("Pendientes", String(withoutLrc.length)),
    ui.kv("Modo", "Selecciona pistas y luego un modelo Whisper"),
  ]);

  const nameWidth = Math.max(28, Math.min(ui.width() - 22, 78));
  const choices = withoutLrc.map((file) => ({
    name: `  ${ui.clip(formatFileName(file), nameWidth)}`,
    value: file,
    checked: true,
  }));

  const { selected } = await prompt([{
    type: "checkbox",
    name: "selected",
    message: "Pistas a procesar",
    choices,
    pageSize: Math.min(16, Math.max(8, (process.stdout.rows || 28) - 10)),
  }]);

  if (selected.length === 0) {
    ui.notice("Sin seleccion", "Usa Espacio para marcar pistas antes de continuar.", "warn");
    await pause();
    return;
  }

  const model = await chooseModel("Modelo para lote");
  if (model === "__back__") return;

  const ok = await confirmSlowModel(model, selected.length);
  if (!ok) {
    ui.notice("Cancelado", "No se inicio el procesamiento por lotes.", "warn");
    await pause();
    return;
  }

  let maxWorkers = 2;
  if (model === "turbo" || model === "large") {
    // Modelos pesados (turbo/large) consumen ~3.5 GB VRAM por proceso.
    // 1 worker a la vez garantiza velocidad extrema en GPU sin saturación ni CUDA OOM.
    maxWorkers = 1;
  } else {
    try {
      const yaml = require("js-yaml");
      const configPath = path.join(__dirname, "..", "..", "backend", "config.yaml");
      if (fs.existsSync(configPath)) {
        const cfg = yaml.load(fs.readFileSync(configPath, "utf-8"));
        maxWorkers = (cfg && cfg.batch && cfg.batch.max_workers) || 2;
      }
    } catch { }
  }

  ui.header("Procesamiento por lotes");
  ui.box("Ejecucion", [
    ui.kv("Modelo", model),
    ui.kv("Pistas", String(selected.length)),
    ui.kv("Procesos", String(maxWorkers)),
  ]);

  const batch = new BatchProcessor(maxWorkers, SYSTEM_ENV);
  for (const file of selected) {
    batch.addTask({
      audioPath: file,
      outputPath: getLrcPath(file),
      model,
      language: "es",
    });
  }

  const results = await batch.processAll((idx, total, fileName, status, detail) => {
    const statusLabel = String(status).padEnd(8);
    const tone = status === "done" ? chalk.green(statusLabel) : status === "error" ? chalk.red(statusLabel) : chalk.cyan(statusLabel);
    console.log(`  ${chalk.dim(`[${idx}/${total}]`)} ${tone} ${ui.clip(fileName, 58)} ${chalk.dim(detail || "")}`);
  });

  const successes = results.filter((result) => result.success).length;
  const failures = results.filter((result) => !result.success).length;

  ui.notice("Lote completado", `${successes} correcta(s), ${failures} fallida(s).`, failures ? "warn" : "ok");
  await pause();
}

async function inspectLrc(audioPath) {
  const lrcPath = getLrcPath(audioPath);
  const content = fs.readFileSync(lrcPath, "utf-8");
  const lines = content.split(/\r?\n/);
  const previewLimit = Math.max(10, Math.min((process.stdout.rows || 28) - 10, 24));

  ui.header("Archivo de letras");
  ui.box(path.basename(lrcPath), [
    ...lines.slice(0, previewLimit).map((line) => ui.clip(line, ui.width() - 6)),
    ...(lines.length > previewLimit ? [chalk.dim(`... ${lines.length - previewLimit} linea(s) mas`)] : []),
  ]);
  await pause();
}

async function songActionMenu(audioPath) {
  const lrcExists = hasLrc(audioPath);
  const choices = [];

  if (lrcExists) {
    choices.push(ui.actionChoice("Reproducir", "Reproductor interactivo", "play", "ok"));
    choices.push(ui.actionChoice("Visualizador espectro", "Espectro ASCII animado", "play_viz", "info"));
    choices.push(ui.actionChoice("Regenerar letras", "Sobreescribir .lrc actual", "regen", "warn"));
    choices.push(ui.actionChoice("Alinear letra existente", "Sincronizacion forzada", "align", "info"));
    choices.push(ui.actionChoice("Inspeccionar .lrc", "Vista previa sincronizada", "view", "muted"));
  } else {
    choices.push(ui.actionChoice("Generar letras", "Transcribir con Whisper", "gen_small", "ok"));
    choices.push(ui.actionChoice("Alinear letra existente", "Sincronizacion forzada", "align", "info"));
  }

  choices.push(ui.separator());
  choices.push(ui.actionChoice("Volver", "Regresar a biblioteca", "back", "muted"));

  // Usar customList para evitar el scroll infinito de inquirer nativo.
  // ui.footer() va dentro del render del header para que customList lo capture.
  const action = await customList(
    () => { renderTrackHeader(audioPath); ui.footer(); },
    choices,
    "Selecciona accion"
  );

  switch (action) {
    case "play":
      exitAltScreen();
      await playSong(audioPath);
      enterAltScreen();
      break;

    case "play_viz":
      exitAltScreen();
      await playSongVisualizer(audioPath);
      enterAltScreen();
      break;

    case "gen_small":
    case "regen": {
      const model = await chooseModel(action === "regen" ? "Regenerar letras" : "Generar letras");
      if (model === "__back__") break;

      const ok = await confirmSlowModel(model);
      if (!ok) {
        ui.notice("Cancelado", "No se inicio la generacion de letras.", "warn");
        await pause();
        break;
      }

      await generateLrc(audioPath, model, "es");
      await pause();
      break;
    }

    case "view":
      await inspectLrc(audioPath);
      break;

    case "align":
      await alignLyrics(audioPath);
      await pause();
      break;

    case "back":
    default:
      break;
  }
}

module.exports = {
  pause,
  generateLrc,
  alignLyrics,
  playSong,
  playSongVisualizer,
  batchGenerateMenu,
  songActionMenu,
};
