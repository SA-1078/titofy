/**
 * Titofy — Copyright (C) 2026 Titofy
 * Licensed under GNU General Public License v3.0 or later.
 *
 * player-clock.js — Gestión del Reloj Virtual y Estado de Reproducción
 */

function createPlayerClock(totalDuration) {
  const state = {
    playing: false,
    elapsed: 0,
    resumeTime: 0,
    totalDuration,
    lyrics: [],
    songTitle: "",
    currentLineIdx: -1,
    finished: false,
    exiting: false,
    volume: 100,

    bands: [],
    peaks: [],
    numBands: 0,
    beat: {},
  };

  function getElapsed() {
    if (!state.playing) return state.elapsed;
    return state.elapsed + (Date.now() - state.resumeTime) / 1000;
  }

  function clampPosition(position) {
    return Math.max(0, Math.min(position, totalDuration));
  }

  return {
    state,
    getElapsed,
    clampPosition,
  };
}

module.exports = { createPlayerClock };
