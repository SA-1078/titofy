/**
 * api-client.js — LyricSync
 * Cliente HTTP para consumir la API local FastAPI.
 *
 * Modo híbrido: intenta la API primero, si no está corriendo hace fallback
 * al spawn directo de Python.
 *
 * Uso:
 *   const { LyricSyncAPI } = require("./api-client");
 *   const api = new LyricSyncAPI();
 *   if (await api.isRunning()) { ... }
 */

const http = require("http");
const path = require("path");
const fs = require("fs");
const { createLogger } = require("./logger");

const log = createLogger("api-client");

let _spawnedBackendProcess = null;

function _killSpawnedBackend() {
  if (_spawnedBackendProcess && !_spawnedBackendProcess.killed) {
    try {
      if (process.platform === "win32") {
        const { execSync } = require("child_process");
        execSync(`taskkill /pid ${_spawnedBackendProcess.pid} /T /F`, { stdio: "ignore" });
      } else {
        process.kill(-_spawnedBackendProcess.pid, "SIGTERM");
      }
    } catch {
      try { _spawnedBackendProcess.kill("SIGKILL"); } catch {}
    }
    _spawnedBackendProcess = null;
  }
}

process.on("exit", _killSpawnedBackend);
process.on("SIGINT", _killSpawnedBackend);
process.on("SIGTERM", _killSpawnedBackend);


class LyricSyncAPI {
  constructor(host = "127.0.0.1", port = 8642) {
    this.host = host;
    this.port = port;

    // Leer config si existe
    try {
      const configPath = path.join(__dirname, "..", "config.yaml");
      if (fs.existsSync(configPath)) {
        const content = fs.readFileSync(configPath, "utf-8");
        const hostMatch = content.match(/^\s*host:\s*"?([^"\n]+)"?/m);
        const portMatch = content.match(/^\s*port:\s*(\d+)/m);
        if (hostMatch) this.host = hostMatch[1].trim();
        if (portMatch) this.port = parseInt(portMatch[1]);
      }
    } catch {}
  }

  /**
   * Hace una petición HTTP a la API local.
   * @returns {Promise<object>} - Respuesta JSON parseada
   */
  _request(method, path, body = null, timeoutMs = 8000) {
    return new Promise((resolve, reject) => {
      const options = {
        hostname: this.host,
        port: this.port,
        path,
        method,
        headers: { "Content-Type": "application/json" },
        timeout: timeoutMs,
      };

      const req = http.request(options, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            reject(new Error(`Invalid JSON: ${data}`));
          }
        });
      });

      req.on("error", reject);
      req.on("timeout", () => {
        req.destroy();
        reject(new Error(`Timeout de petición (${timeoutMs}ms)`));
      });

      if (body) req.write(JSON.stringify(body));
      req.end();
    });
  }

  /**
   * Verifica si la API está corriendo.
   */
  async isRunning() {
    try {
      const res = await this._request("GET", "/health", null, 2500);
      return res && res.status === "ok";
    } catch {
      return false;
    }
  }

  /**
   * Asegura que el servidor API esté en ejecución, arrancándolo en segundo plano si es necesario.
   */
  async ensureServerRunning() {

    if (await this.isRunning()) return true;

    try {
      const { resolvePython } = require("./python-resolver");
      const { SYSTEM_ENV, getLyricsConfig } = require("./config");
      const cfg = getLyricsConfig();
      if (!cfg.auto_start_api) return false;

      const pythonBin = resolvePython(SYSTEM_ENV);
      if (!pythonBin) return false;

      const backendDir = path.join(__dirname, "..", "..", "backend");
      const serverScript = path.join(backendDir, "api_server.py");

      const { spawn } = require("child_process");
      const proc = spawn(pythonBin, [serverScript], {
        detached: process.platform !== "win32",
        stdio: "ignore",
        cwd: backendDir,
        env: SYSTEM_ENV,
      });

      _spawnedBackendProcess = proc;

      // Esperar hasta 4.5 segundos a que la API responda
      for (let i = 0; i < 18; i++) {
        await new Promise((r) => setTimeout(r, 250));
        if (await this.isRunning()) return true;
      }
    } catch (err) {
      log.warning("No se pudo auto-iniciar el servidor de backend:", err);
    }
    return false;
  }


  /**
   * Resuelve letras usando el motor híbrido (Caché → LRCLIB → Forced Alignment → Whisper).
   */
  async resolveLyrics(artist, title, options = {}) {
    const {
      duration = null,
      audioPath = null,
      mode = "auto",
      model = "small",
      language = "auto",
      outputPath = null,
      force = false,
      timeout = 600000, // 10 minutos por si entra a Whisper (Nivel 3)
    } = options;

    return this._request(
      "POST",
      "/lyrics/resolve",
      {
        artist,
        title,
        duration,
        audio_path: audioPath,
        mode,
        model,
        language,
        output_path: outputPath,
        force,
      },
      timeout
    );
  }



  /**
   * Post-procesa un .lrc (sincrónico).
   */

  async postprocess(lrcPath, threshold = 85) {
    return this._request("POST", "/postprocess", {
      lrc_path: lrcPath,
      threshold,
    });
  }

  /**
   * Consulta el estado de una tarea.
   */
  async getStatus(taskId) {
    return this._request("GET", `/status/${taskId}`);
  }

  /**
   * Polling de estado con timeout.
   * @param {string} taskId
   * @param {function} onProgress - callback(status, progress)
   * @param {number} intervalMs - intervalo de polling
   * @param {number} timeoutMs - timeout total
   */
  async waitForCompletion(taskId, onProgress = null, intervalMs = 2000, timeoutMs = 1800000) {
    const start = Date.now();

    while (Date.now() - start < timeoutMs) {
      try {
        const status = await this.getStatus(taskId);

        if (onProgress) onProgress(status.status, status.progress);

        if (status.status === "done") return status;
        if (status.status === "error") throw new Error(status.error || "Task failed");
      } catch (err) {
        if (err.message !== "Timeout") throw err;
      }

      await new Promise((r) => setTimeout(r, intervalMs));
    }

    throw new Error("Timeout waiting for task completion");
  }
}

module.exports = { LyricSyncAPI };
