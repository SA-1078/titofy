/**
 * config.js — Configuración compartida de LyricSync
 * Constantes, rutas, variables de entorno y utilidades comunes.
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// ─── Constantes ─────────────────────────────────────────────────────────────
const AUDIO_EXTENSIONS = [".mp3", ".wav", ".m4a", ".flac", ".ogg", ".aac", ".wma", ".mp4", ".mkv", ".webm"];
const LRC_DIR = path.join(__dirname, "..", "lrc");

// Ruta al config.yaml del backend
const CONFIG_YAML_PATH = path.join(__dirname, "..", "..", "backend", "config.yaml");

// Carpeta de música por defecto según el sistema operativo
function getDefaultMusicFolder() {
  if (process.platform === "win32") {
    return path.join(process.env.USERPROFILE || "C:\\Users\\Public", "Music");
  }
  // Linux / macOS: usar XDG_MUSIC_DIR si existe, si no ~/Música o ~/Music
  const xdgMusic = process.env.XDG_MUSIC_DIR;
  if (xdgMusic && fs.existsSync(xdgMusic)) return xdgMusic;

  const home = process.env.HOME || "/home";
  const musicaDir = path.join(home, "Música");
  if (fs.existsSync(musicaDir)) return musicaDir;

  const musicDir = path.join(home, "Music");
  if (fs.existsSync(musicDir)) return musicDir;

  return home;
}

const DEFAULT_MUSIC_FOLDER = getDefaultMusicFolder();

// ─── Persistencia de carpeta en config.yaml ─────────────────────────────────

/**
 * Lee paths.music_folder del config.yaml.
 * Retorna la ruta guardada o null si no existe / está vacía.
 */
function loadSavedMusicFolder() {
  try {
    if (!fs.existsSync(CONFIG_YAML_PATH)) return null;
    const content = fs.readFileSync(CONFIG_YAML_PATH, "utf-8");
    // Buscar la línea "  music_folder: '...'" o "  music_folder: ..."
    const match = content.match(/^\s*music_folder:\s*['"]?(.+?)['"]?\s*$/m);
    if (match && match[1] && match[1].trim() !== "") {
      const folder = match[1].trim();
      if (fs.existsSync(folder)) return folder;
    }
  } catch { /* ignorar errores de lectura */ }
  return null;
}

/**
 * Guarda la carpeta de música elegida en config.yaml (paths.music_folder).
 */
function saveMusicFolder(folderPath) {
  try {
    if (!fs.existsSync(CONFIG_YAML_PATH)) return;
    let content = fs.readFileSync(CONFIG_YAML_PATH, "utf-8");
    // Reemplazar la línea music_folder existente
    content = content.replace(
      /^(\s*music_folder:\s*).*$/m,
      `$1'${folderPath.replace(/'/g, "''")}'`
    );
    fs.writeFileSync(CONFIG_YAML_PATH, content, "utf-8");
  } catch { /* ignorar errores de escritura */ }
}

// Asegurar que la carpeta lrc/ exista
if (!fs.existsSync(LRC_DIR)) fs.mkdirSync(LRC_DIR, { recursive: true });

// ─── PATH del sistema (para ffplay / ffmpeg) ────────────────────────────────
function getSystemPath() {
  if (process.platform !== "win32") {
    return process.env.PATH;
  }
  try {
    const m = execSync(
      'powershell -Command "[System.Environment]::GetEnvironmentVariable(\'PATH\',\'Machine\')"',
      { encoding: "utf-8" }
    ).trim();
    const u = execSync(
      'powershell -Command "[System.Environment]::GetEnvironmentVariable(\'PATH\',\'User\')"',
      { encoding: "utf-8" }
    ).trim();
    return `${m};${u}`;
  } catch {
    return process.env.PATH;
  }
}

const SYSTEM_ENV = { 
  ...process.env, 
  PATH: getSystemPath(),
  PYTHONDONTWRITEBYTECODE: "1", // Evita que Python genere la carpeta __pycache__ y archivos .pyc
  PYTHONIOENCODING: "utf-8"     // Fuerza UTF-8 para evitar errores con caracteres especiales (especialmente en batch)
};

// ─── Utilidades ─────────────────────────────────────────────────────────────

function isAudioFile(file) {
  return AUDIO_EXTENSIONS.includes(path.extname(file).toLowerCase());
}

function getLrcPath(audioPath) {
  const baseName = path.basename(audioPath, path.extname(audioPath));
  return path.join(LRC_DIR, baseName + ".lrc");
}

function hasLrc(audioPath) {
  return fs.existsSync(getLrcPath(audioPath));
}

function formatFileName(filePath) {
  return path.basename(filePath, path.extname(filePath));
}

function truncate(str, max = 55) {
  return str.length > max ? str.slice(0, max - 1) + "…" : str;
}

function scanFolder(folderPath) {
  try {
    const entries = fs.readdirSync(folderPath, { withFileTypes: true });
    return entries
      .filter((e) => e.isFile() && isAudioFile(e.name))
      .map((e) => path.join(folderPath, e.name))
      .sort((a, b) => path.basename(a).localeCompare(path.basename(b)));
  } catch {
    return [];
  }
}

module.exports = {
  AUDIO_EXTENSIONS,
  LRC_DIR,
  DEFAULT_MUSIC_FOLDER,
  SYSTEM_ENV,
  isAudioFile,
  getLrcPath,
  hasLrc,
  formatFileName,
  truncate,
  scanFolder,
  loadSavedMusicFolder,
  saveMusicFolder,
};

