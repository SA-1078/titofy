const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

let cachedPython = null;

function works(command, env = process.env) {
  if (!command) return false;
  if (path.isAbsolute(command) && !fs.existsSync(command)) return false;

  const result = spawnSync(command, ["--version"], {
    encoding: "utf-8",
    env,
    stdio: "ignore",
    windowsHide: true,
  });

  return !result.error && result.status === 0;
}

function resolvePython(extraEnv = {}) {
  if (cachedPython) return cachedPython;

  const env = { ...process.env, ...extraEnv };
  const root = path.join(__dirname, "..");
  const candidates = [
    process.env.PYTHON,
    path.join(root, ".venv", "Scripts", "python.exe"),
    path.join(root, "venv", "Scripts", "python.exe"),
    path.join(root, ".venv", "bin", "python"),
    path.join(root, "venv", "bin", "python"),
    "python",
    "py",
    "python3",
  ].filter(Boolean);

  cachedPython = candidates.find((candidate) => works(candidate, env)) || null;
  return cachedPython;
}

module.exports = { resolvePython };
