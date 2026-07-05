const inquirer = require("inquirer");
const chalk = require("chalk");

/**
 * Limpia SOLO los listeners del reproductor heredados en stdin.
 * NO toca rawMode ni pausa/resume — inquirer v8 gestiona eso por su cuenta.
 *
 * Llamar solo después de salir del reproductor (player/ascii-player),
 * nunca antes ni durante un prompt activo.
 */
function cleanupPlayerStdin() {
  if (!process.stdin.isTTY) return;
  // Quitar listeners del reproductor (keypress handler del keyboard.js)
  // setRawMode lo maneja inquirer internamente — no lo tocamos aquí
  process.stdin.removeAllListeners("keypress");
  process.stdin.removeAllListeners("data");
}

function normalizeQuestions(questions) {
  return questions.map((question) => ({
    prefix: chalk.cyan("›"),
    suffix: "",
    ...question,
  }));
}

/**
 * Wrapper de inquirer.prompt.
 * No manipula stdin — inquirer v8 gestiona rawMode, pause y resume por su cuenta.
 */
async function prompt(questions, answers) {
  return await inquirer.prompt(normalizeQuestions(questions), answers);
}

// Alias mantenido por compatibilidad con imports existentes
const preparePromptInput = cleanupPlayerStdin;

module.exports = {
  inquirer,
  normalizeQuestions,
  prompt,
  preparePromptInput,
  cleanupPlayerStdin,
};
