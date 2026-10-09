#!/usr/bin/env bash
# ==============================================================================
# Titofy — Desinstalador Oficial para Linux
# ==============================================================================
set -e

echo "=========================================================="
echo "          🗑️ DESINSTALADOR OFICIAL DE TITOFY             "
echo "=========================================================="

echo "Eliminando archivos de instalación de Titofy..."
rm -rf "$HOME/.local/share/titofy"
rm -f "$HOME/.local/bin/titofy"
rm -f "$HOME/.local/share/applications/com.titofy.desktop.desktop"
rm -f "$HOME/.local/share/icons/hicolor/512x512/apps/titofy.png"
rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/titofy.png"
rm -f "$HOME/.local/share/pixmaps/titofy.png"
rm -f "$HOME/.local/bin/uninstall-titofy"

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "✅ Titofy ha sido desinstalado completamente de tu PC."
