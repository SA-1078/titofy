/**
 * Titofy — Copyright (C) 2026 Titofy
 * Licensed under GNU General Public License v3.0 or later.
 *
 * model-selector.js — Selector Interactivo de Modelos Whisper en la CLI
 */

const ui = require("./theme");
const { prompt } = require("./prompt");

function modelChoices(backValue = "__back__") {
  return [
    ui.actionChoice("turbo", "turbo   · Lo mejor (calidad profesional + velocidad)", "turbo", "ok"),
    ui.actionChoice("small", "small   · Balance ideal para la mayoria de canciones", "small", "info"),
    ui.actionChoice("base", "base    · Rapido (equipos lentos)", "base", "muted"),
    ui.separator(),
    ui.actionChoice("Volver", "Regresar sin cambios", backValue, "muted"),
  ];
}

async function chooseModel(title = "Modelo de transcripción") {
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

module.exports = {
  modelChoices,
  chooseModel,
  confirmSlowModel,
};
