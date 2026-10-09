/**
 * Titofy — Copyright (C) 2026 Titofy
 * Licensed under GNU General Public License v3.0 or later.
 *
 * check-models.js — Verificador de modelos faster-whisper en Hugging Face
 *
 * Muestra:
 *  - Modelos soportados actualmente y cuáles están descargados localmente
 *  - Modelos nuevos en HF que aún no soporta Titofy
 *  - Tamaño aproximado, cantidad de descargas y fecha de actualización
 */

const { SUPPORTED_MODELS } = require("../src/model-checker");
const chalk = require("chalk");
const https = require("https");
const os = require("os");
const fs = require("fs");
const path = require("path");

// ─── Detectar modelos descargados localmente (caché HF) ──────────────────────

function getLocalDownloaded() {
  const hfCache = path.join(os.homedir(), ".cache", "huggingface", "hub");
  const downloaded = new Set();
  if (!fs.existsSync(hfCache)) return downloaded;
  try {
    for (const entry of fs.readdirSync(hfCache)) {
      // Formato: models--Systran--faster-whisper-base
      const match = entry.match(/^models--Systran--(faster-whisper-.+)$/);
      if (match) downloaded.add(match[1]);
    }
  } catch { /* sin acceso */ }
  return downloaded;
}

// ─── Petición a la API de Hugging Face ───────────────────────────────────────

function fetchHF(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      timeout: 10000,
      headers: { "User-Agent": "Titofy/2.2 (check-models)" },
    }, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => {
        try { resolve(JSON.parse(data)); }
        catch { reject(new Error("JSON inválido de Hugging Face")); }
      });
    });
    req.on("error", reject);
    req.on("timeout", () => { req.destroy(); reject(new Error("Timeout")); });
  });
}

// ─── Formateo de números ──────────────────────────────────────────────────────

function fmtDownloads(n) {
  if (!n && n !== 0) return "—";
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}k`;
  return String(n);
}

function fmtDate(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  return d.toISOString().split("T")[0];
}

// ─── Render de tablas ─────────────────────────────────────────────────────────

const COL = { name: 38, dl: 10, updated: 12, local: 8 };
const W = COL.name + COL.dl + COL.updated + COL.local + 6;

function hline() {
  return "─".repeat(W);
}

function row(name, dl, updated, local, nameColor = chalk.white) {
  const localBadge = local ? chalk.green("✓ local") : chalk.gray("  —    ");
  return (
    nameColor(name.padEnd(COL.name)) +
    chalk.gray(fmtDownloads(dl).padStart(COL.dl)) +
    chalk.gray(("  " + fmtDate(updated)).padEnd(COL.updated + 2)) +
    "  " + localBadge
  );
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function run() {
  const downloaded = getLocalDownloaded();

  console.log();
  console.log(chalk.bold("  Titofy — Modelos faster-whisper (Hugging Face · Systran)"));
  console.log(chalk.gray("  " + hline()));
  console.log();

  // ── Cabecera de tabla ──
  console.log(
    chalk.bold.gray("  " +
      "Modelo".padEnd(COL.name) +
      "Descargas".padStart(COL.dl) +
      "  Actualizado".padEnd(COL.updated + 2) +
      "  Local"
    )
  );
  console.log(chalk.gray("  " + hline()));

  let allModels = [];

  try {
    allModels = await fetchHF(
      "https://huggingface.co/api/models?author=Systran&search=faster-whisper&limit=100&sort=downloads&direction=-1"
    );
  } catch (err) {
    console.log(chalk.red(`\n  ❌ Sin conexión o error al consultar Hugging Face: ${err.message}`));
    console.log(chalk.gray("  Verifica tu conexión e inténtalo de nuevo.\n"));
    return;
  }

  const newModels = [];
  const knownModels = [];

  for (const m of allModels) {
    const modelId = (m.modelId || m.id || "");
    const name = modelId.split("/").pop();
    const isFasterWhisper = name.startsWith("faster-whisper-") || name.startsWith("faster-distil-whisper-");
    if (!isFasterWhisper) continue;

    const entry = {
      name,
      downloads: m.downloads ?? m.downloadsAllTime ?? null,
      updated: m.lastModified || m.updatedAt || null,
      local: downloaded.has(name),
      isNew: !SUPPORTED_MODELS.has(name),
    };

    if (entry.isNew) newModels.push(entry);
    else knownModels.push(entry);
  }

  // ── Modelos ya soportados ──
  if (knownModels.length > 0) {
    console.log(chalk.dim("  ── Soportados en Titofy ──────────────────────────────────────────────────────────"));
    for (const m of knownModels) {
      const color = m.local ? chalk.white : chalk.gray;
      console.log("  " + row(m.name, m.downloads, m.updated, m.local, color));
    }
  }

  // ── Modelos nuevos ──
  if (newModels.length > 0) {
    console.log();
    console.log(chalk.yellow("  ── Nuevos en HF (no soportados aún) ────────────────────────────────────────────────"));
    for (const m of newModels) {
      console.log("  " + row(m.name, m.downloads, m.updated, m.local, chalk.yellow));
    }
    console.log();
    console.log(chalk.gray("  Para agregar soporte a un modelo nuevo:"));
    console.log(chalk.gray("    1. Agrega el nombre a SUPPORTED_MODELS en cli/src/model-checker.js"));
    console.log(chalk.gray("    2. Agrégalo en modelChoices() en cli/src/ui/model-selector.js"));
    console.log(chalk.gray("    3. Si requiere configuración especial, actualiza backend/whisper_engine/loader.py"));
  } else {
    console.log();
    console.log(chalk.green("  ✓ No hay modelos nuevos en Hugging Face. Titofy está al día."));
  }

  console.log();
  console.log(chalk.gray(`  Total revisados: ${allModels.length} · Soportados: ${knownModels.length} · Nuevos: ${newModels.length} · Descargados localmente: ${downloaded.size}`));
  console.log(chalk.gray("  " + hline()));
  console.log();
}

run();
