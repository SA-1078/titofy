/**
 * model-checker.js — Verificador de modelos Whisper nuevos
 * 
 * Consulta la API de Hugging Face para detectar si hay modelos
 * faster-whisper más recientes que los soportados por Titofy CMD.
 * 
 * - Solo consulta una vez cada 7 días (configurable)
 * - Falla silenciosamente si no hay internet
 * - Guarda resultados en config.yaml
 */

const https = require("https");
const fs = require("fs");
const path = require("path");

// ─── Modelos que Titofy CMD soporta actualmente ────────────────────────────
const SUPPORTED_MODELS = new Set([
  "faster-whisper-tiny",
  "faster-whisper-tiny.en",
  "faster-whisper-base",
  "faster-whisper-base.en",
  "faster-whisper-small",
  "faster-whisper-small.en",
  "faster-whisper-medium",
  "faster-whisper-medium.en",
  "faster-whisper-large",
  "faster-whisper-large-v1",
  "faster-whisper-large-v2",
  "faster-whisper-large-v3",
  "faster-whisper-large-v3-turbo",
]);

const CONFIG_YAML_PATH = path.join(__dirname, "..", "..", "backend", "config.yaml");
const CHECK_INTERVAL_DAYS = 7;

// ─── Lectura/escritura en config.yaml ────────────────────────────────────────

function readModelCheckData() {
  try {
    if (!fs.existsSync(CONFIG_YAML_PATH)) return null;
    const content = fs.readFileSync(CONFIG_YAML_PATH, "utf-8");

    const lastCheckMatch = content.match(/^\s*last_model_check:\s*['"]?(.+?)['"]?\s*$/m);
    const newModelsMatch = content.match(/^\s*new_models_found:\s*['"]?(.+?)['"]?\s*$/m);

    return {
      lastCheck: lastCheckMatch ? lastCheckMatch[1].trim() : null,
      newModels: newModelsMatch ? newModelsMatch[1].trim() : null,
    };
  } catch {
    return null;
  }
}

function saveModelCheckData(newModels) {
  try {
    if (!fs.existsSync(CONFIG_YAML_PATH)) return;
    let content = fs.readFileSync(CONFIG_YAML_PATH, "utf-8");
    const now = new Date().toISOString().split("T")[0]; // YYYY-MM-DD

    // Si ya existe la sección model_check, actualizar
    if (content.includes("model_check:")) {
      content = content.replace(
        /^(\s*last_model_check:\s*).*$/m,
        `$1'${now}'`
      );
      content = content.replace(
        /^(\s*new_models_found:\s*).*$/m,
        `$1'${newModels.join(", ") || "ninguno"}'`
      );
    } else {
      // Agregar la sección al final
      content += `model_check:\n  last_model_check: '${now}'\n  new_models_found: '${newModels.join(", ") || "ninguno"}'\n`;
    }

    fs.writeFileSync(CONFIG_YAML_PATH, content, "utf-8");
  } catch { /* silencioso */ }
}

// ─── Consulta a Hugging Face ─────────────────────────────────────────────────

function fetchHuggingFaceModels() {
  return new Promise((resolve, reject) => {
    const url = "https://huggingface.co/api/models?author=Systran&search=faster-whisper&limit=50";

    const req = https.get(url, { timeout: 8000 }, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          const models = JSON.parse(data);
          resolve(models);
        } catch (e) {
          reject(new Error("JSON inválido de Hugging Face"));
        }
      });
    });

    req.on("error", reject);
    req.on("timeout", () => {
      req.destroy();
      reject(new Error("Timeout al consultar Hugging Face"));
    });
  });
}

// ─── Lógica principal ────────────────────────────────────────────────────────

function shouldCheck() {
  const data = readModelCheckData();
  if (!data || !data.lastCheck) return true;

  try {
    const lastDate = new Date(data.lastCheck);
    const now = new Date();
    const diffDays = (now - lastDate) / (1000 * 60 * 60 * 24);
    return diffDays >= CHECK_INTERVAL_DAYS;
  } catch {
    return true;
  }
}

function getCachedNewModels() {
  const data = readModelCheckData();
  if (!data || !data.newModels || data.newModels === "ninguno") return [];
  return data.newModels.split(",").map((m) => m.trim()).filter(Boolean);
}

async function checkForNewModels() {
  // Si no toca verificar, devolver modelos cacheados
  if (!shouldCheck()) {
    return getCachedNewModels();
  }

  try {
    const models = await fetchHuggingFaceModels();
    
    const newModels = models
      .map((m) => {
        // modelId es "Systran/faster-whisper-large-v3" → extraer nombre
        const parts = m.modelId || m.id || "";
        return parts.split("/").pop();
      })
      .filter((name) => {
        // Solo modelos faster-whisper que NO están en nuestra lista
        return name.startsWith("faster-whisper-") && !SUPPORTED_MODELS.has(name);
      });

    saveModelCheckData(newModels);
    return newModels;
  } catch {
    // Sin internet o error → no molestar, devolver cache si hay
    return getCachedNewModels();
  }
}

module.exports = { checkForNewModels, getCachedNewModels, SUPPORTED_MODELS };
