/**
 * Titofy — Copyright (C) 2026 Titofy
 * Licensed under GNU General Public License v3.0 or later.
 *
 * batch-ui.js — Interfaz Interactiva de Procesamiento por Lotes en la CLI
 */

const fs = require("fs");
const path = require("path");
const chalk = require("chalk");
const ui = require("./theme");
const { prompt } = require("./prompt");
const { chooseModel, confirmSlowModel } = require("./model-selector");
const { BatchProcessor } = require("../batch-worker");
const { SYSTEM_ENV, getLrcPath, hasLrc, formatFileName } = require("../config");

function pause(message = "Presiona Enter para volver") {
  return prompt([{
    type: "input",
    name: "_",
    message: chalk.gray(message),
  }]);
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

  const nameWidth = Math.max(30, ui.width() - 16);
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

  const trackStatus = selected.map((file) => ({
    file,
    fileName: formatFileName(file),
    status: "pending",
    pct: 0,
    bar: "░".repeat(30),
    eta: "",
    detail: "",
    errorMsg: "",
  }));

  const renderBatchScreen = () => {
    ui.clear();
    ui.header("Procesamiento por lotes");

    const w = ui.width();
    const lineLen = Math.max(40, w - 6);
    const nameWidthFull = Math.max(30, lineLen - 26);
    const barWidth = Math.max(20, Math.min(60, lineLen - 32));

    const completed = trackStatus.filter((t) => t.status === "done").length;
    const failed = trackStatus.filter((t) => t.status === "error").length;

    const executionMode = (model === "turbo" || model === "large")
      ? `${ui.pill("SI, GPU CUDA DEDICADA", "ok")}  1 trabajo a la vez (3.5 GB VRAM por trabajo / Máxima velocidad)`
      : `${ui.pill("MULTI-HILO PARALELO", "info")}  ${maxWorkers} trabajos a la vez (CPU + GPU / Máxima velocidad)`;

    ui.box("Estado del Lote", [
      ui.kv("Modelo IA:", chalk.bold.yellow(model.toUpperCase())),
      ui.kv("Carga GPU (CUDA):", executionMode),
      ui.kv("Progreso:", `${completed}/${selected.length} canciones completadas ${failed ? chalk.red(`(${failed} fallidas)`) : ""}`),
    ]);

    console.log(chalk.bold("  📋 Lista de Pistas a procesar:"));
    console.log(chalk.gray("  " + "─".repeat(lineLen)));

    trackStatus.forEach((t, i) => {
      const idxStr = `[${i + 1}/${selected.length}]`;
      const clippedName = ui.clip(t.fileName, nameWidthFull);

      if (t.status === "pending") {
        console.log(`  ${chalk.gray(idxStr)} ${chalk.dim("⏸  Pendiente  ")} ${chalk.gray(clippedName)}`);
      } else if (t.status === "downloading") {
        console.log(`  ${chalk.cyan(idxStr)} ${chalk.cyan("⏳ Descargando ")} ${chalk.white(clippedName)}`);
        console.log(`      ${chalk.dim(t.detail || "Descargando modelo de IA...")}`);
      } else if (t.status === "running") {
        let displayBar = t.bar || "░".repeat(barWidth);
        if (t.pct !== undefined) {
          const filled = Math.round((t.pct / 100) * barWidth);
          displayBar = "█".repeat(filled) + "░".repeat(Math.max(0, barWidth - filled));
        }
        const barStr = chalk.rgb(38, 198, 218)(displayBar);
        const pctStr = chalk.bold.cyan(`${String(t.pct).padStart(3)}%`);
        const etaStr = t.eta ? chalk.dim(` · ${t.eta}`) : "";
        console.log(`  ${chalk.bold.yellow(idxStr)} ${chalk.bold.yellow("→ Transcribiendo")} ${chalk.bold.white(clippedName)}`);
        console.log(`      ${barStr} ${pctStr}${etaStr}`);
      } else if (t.status === "done") {
        console.log(`  ${chalk.green(idxStr)} ${chalk.bold.green("✅ Completado  ")} ${chalk.white(clippedName)}`);
      } else if (t.status === "error") {
        console.log(`  ${chalk.red(idxStr)} ${chalk.bold.red("❌ Error       ")} ${chalk.white(clippedName)}`);
        if (t.errorMsg) {
          console.log(`      ${chalk.red.dim(ui.clip(t.errorMsg, lineLen - 6))}`);
        }
      }
    });

    console.log(chalk.gray("  " + "─".repeat(lineLen)) + "\n");
  };

  renderBatchScreen();

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
    const item = trackStatus[idx - 1];
    if (item) {
      if (status === "starting") {
        item.status = "running";
        item.pct = 0;
      } else if (status === "downloading") {
        item.status = "downloading";
        item.detail = typeof detail === "object" ? detail.detail : String(detail);
      } else if (status === "running") {
        item.status = "running";
        if (typeof detail === "object") {
          item.pct = detail.pct || 0;
          item.bar = detail.bar || "░".repeat(20);
          item.eta = detail.eta || "";
        }
      } else if (status === "done") {
        item.status = "done";
        item.pct = 100;
      } else if (status === "error") {
        item.status = "error";
        item.errorMsg = typeof detail === "object" ? detail.error : String(detail || "Error en transcripción");
      }
    }
    renderBatchScreen();
  });

  renderBatchScreen();

  const successes = results.filter((result) => result.success).length;
  const failures = results.filter((result) => !result.success).length;

  ui.notice("Procesado del lote completado", `${successes} correcta(s), ${failures} fallida(s).`, failures ? "warn" : "ok");
  await pause();
}

module.exports = { batchGenerateMenu };
