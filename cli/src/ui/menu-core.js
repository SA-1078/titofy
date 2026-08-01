const fs = require("fs");
const chalk = require("chalk");
const { prompt } = require("./prompt");
const ui = require("./theme");
const { enterAltScreen, exitAltScreen, customList } = require("./alt-screen");

const {
  scanFolder,
  hasLrc,
  DEFAULT_MUSIC_FOLDER,
  loadSavedMusicFolder,
  saveMusicFolder,
} = require("../config");

const { songActionMenu, batchGenerateMenu, pause } = require("./menu-actions");
const { checkForNewModels } = require("../model-checker");

// ──────────────────────────────────────────────────────────────────────────

function renderLibraryHeader(folderPath, total, synced, newModelsBanner) {
  ui.header();
  const rows = [
    ui.kv("Carpeta", ui.clip(folderPath, ui.width() - 18)),
    `${ui.kv("Pistas", String(total).padEnd(4))}  ${chalk.green(`Con letras ${String(synced).padEnd(4)}`)}  ${chalk.yellow(`Pendientes ${total - synced}`)}`,
  ];
  if (newModelsBanner && newModelsBanner.length > 0) {
    const modelNames = newModelsBanner.map((m) => m.replace("faster-whisper-", "")).join(", ");
    rows.push(chalk.cyan(`⚡ Nuevo modelo disponible: ${modelNames}`));
  }
  ui.box("Biblioteca", rows);
  ui.footer();
}

async function chooseFolderMenu(currentFolder) {
  ui.header("Cambiar carpeta musical");
  ui.box("Actual", [ui.kv("Carpeta", currentFolder)]);

  const { folder } = await prompt([{
    type: "input",
    name: "folder",
    message: "Ruta de la carpeta",
    default: currentFolder,
  }]);

  const folderPath = folder.trim().replace(/^"|"$/g, "");
  if (!fs.existsSync(folderPath)) {
    ui.notice("Carpeta no encontrada", folderPath, "danger");
    await pause("Presiona Enter para continuar");
    return currentFolder;
  }

  // Guardar la carpeta elegida para futuras sesiones
  saveMusicFolder(folderPath);
  return folderPath;
}

async function songListMenu(folderPath, newModelsBanner) {
  const audioFiles = scanFolder(folderPath);

  enterAltScreen();

  if (audioFiles.length === 0) {
    ui.header();
    ui.box("Biblioteca", [
      ui.kv("Carpeta", folderPath),
      ui.kv("Estado", "No se encontraron archivos de audio compatibles"),
      ui.kv("Formatos", "mp3, wav, m4a, flac, ogg, aac, wma, mp4, mkv, webm"),
    ]);
    await pause("Presiona Enter para elegir otra carpeta");
    return "__folder__";
  }

  const synced = audioFiles.filter(hasLrc).length;
  const pending = audioFiles.length - synced;
  const nameWidth = Math.max(28, Math.min(ui.width() - 22, 84));

  const choices = [
    ui.separator("Canciones"),
    ...audioFiles.map((file) => ui.songChoice(file, hasLrc(file) ? "sync" : "pending", nameWidth)),
    ui.separator("Herramientas"),
    ui.actionChoice("Procesar pendientes", `${pending} pendiente(s)`, "__batch__", pending ? "info" : "muted"),
    ui.actionChoice("Cambiar carpeta musical", "Seleccionar otro directorio", "__folder__", "info"),
    ui.separator(),
    ui.actionChoice("Salir de Titofy CMD", "Cerrar esta sesion de terminal", "__exit__", "danger"),
  ];

  const selected = await customList(
    () => renderLibraryHeader(folderPath, audioFiles.length, synced, newModelsBanner),
    choices,
    "Selecciona una pista"
  );

  if (selected === "__exit__") return null;
  if (selected === "__folder__") return "__folder__";
  if (selected === "__batch__") {
    exitAltScreen();
    await batchGenerateMenu(audioFiles);
    return folderPath;
  }

  // songActionMenu usa customList internamente — corre dentro del alt screen
  await songActionMenu(selected, folderPath);
  return folderPath;
}

async function startMenuLoop() {
  const folderArgIndex = process.argv.indexOf("--folder");
  let currentFolder = folderArgIndex !== -1 && process.argv[folderArgIndex + 1]
    ? process.argv[folderArgIndex + 1]
    : (loadSavedMusicFolder() || DEFAULT_MUSIC_FOLDER);

  // Verificar modelos nuevos en segundo plano (no bloquea el inicio)
  let newModelsBanner = null;
  checkForNewModels()
    .then((newModels) => {
      if (newModels.length > 0) {
        newModelsBanner = newModels;
      }
    })
    .catch(() => {}); // silencioso si falla

  enterAltScreen();
  process.on("exit", exitAltScreen);
  process.on("SIGINT", () => { exitAltScreen(); process.exit(0); });

  while (true) {
    const result = await songListMenu(currentFolder, newModelsBanner);

    if (result === null) {
      exitAltScreen();
      console.log("\n  👋 Titofy CMD cerrado.\n");
      process.exit(0);
    }

    if (result === "__folder__") {
      enterAltScreen();
      currentFolder = await chooseFolderMenu(currentFolder);
    } else {
      currentFolder = result || currentFolder;
    }
  }
}

module.exports = { startMenuLoop, enterAltScreen, exitAltScreen };
