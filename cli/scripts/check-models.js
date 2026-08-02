/**
 * Titofy — Copyright (C) 2026 Titofy
 * Licensed under GNU General Public License v3.0 or later.
 *
 * check-models.js — Verificador manual de modelos IA en Hugging Face
 */

const { SUPPORTED_MODELS } = require("../src/model-checker");
const chalk = require("chalk");
const https = require("https");

async function run() {
  console.log("");
  console.log(chalk.bold.cyan("🔍 Titofy — Verificando nuevos modelos en Hugging Face (Systran)..."));
  console.log(chalk.gray("─────────────────────────────────────────────────────────────"));
  console.log(chalk.dim(`Modelos soportados actualmente (${SUPPORTED_MODELS.size}):`));
  console.log(chalk.gray(Array.from(SUPPORTED_MODELS).join(", ")));
  console.log("");

  const url = "https://huggingface.co/api/models?author=Systran&search=faster-whisper&limit=50";

  const req = https.get(url, { timeout: 8000 }, (res) => {
    let data = "";
    res.on("data", (c) => (data += c));
    res.on("end", () => {
      try {
        const models = JSON.parse(data);
        const found = models
          .map((m) => (m.modelId || m.id || "").split("/").pop())
          .filter((name) => name.startsWith("faster-whisper-"));

        const newModels = found.filter((name) => !SUPPORTED_MODELS.has(name));

        if (newModels.length === 0) {
          console.log(chalk.green("✅ Todos los modelos de Hugging Face (Systran) ya están soportados en Titofy."));
          console.log(chalk.gray(`Modelos revisados: ${found.length}`));
        } else {
          console.log(chalk.bold.yellow("⚡ ¡NUEVOS MODELOS DETECTADOS EN HUGGING FACE!"));
          for (const nm of newModels) {
            console.log(chalk.cyan(`   • ${nm}`));
          }
          console.log("");
          console.log(chalk.gray("Pasos para dar soporte a un nuevo modelo en Titofy:"));
          console.log(chalk.gray("1. Agrega el nombre del modelo a SUPPORTED_MODELS en cli/src/model-checker.js"));
          console.log(chalk.gray("2. Agrega la opción en modelChoices() en cli/src/ui/menu-actions.js"));
        }
        console.log("");
      } catch (err) {
        console.error(chalk.red(`❌ Error al procesar respuesta: ${err.message}`));
      }
    });
  });

  req.on("error", (err) => {
    console.error(chalk.red(`❌ Sin conexión a internet o error en la consulta: ${err.message}`));
  });
}

run();
