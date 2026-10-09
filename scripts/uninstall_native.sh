#!/usr/bin/env bash
# Titofy — Script de Desinstalación Limpia en Linux
set -e

INSTALL_DIR="$HOME/.local/share/titofy"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR_512="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_DIR_256="$HOME/.local/share/icons/hicolor/256x256/apps"
PIXMAPS_DIR="$HOME/.local/share/pixmaps"
DATA_DIR="$HOME/.local/share/com.titofy.desktop"

echo "====================================================="
echo "   🗑️  Desinstalando Titofy de tu PC Linux          "
echo "====================================================="

echo "1. Cerrando instancias activas de Titofy si las hay..."
pkill -f "titofy/bundle/desktop" 2>/dev/null || true

echo "2. Eliminando lanzadores del sistema..."
rm -f "$BIN_DIR/titofy"
rm -f "$BIN_DIR/uninstall-titofy"

echo "3. Eliminando entrada del menú de aplicaciones..."
rm -f "$DESKTOP_DIR/com.titofy.desktop.desktop"

echo "4. Eliminando íconos de la aplicación..."
rm -f "$ICON_DIR_512/titofy.png"
rm -f "$ICON_DIR_256/titofy.png"
rm -f "$PIXMAPS_DIR/titofy.png"

echo "5. Eliminando archivos de la aplicación instalada ($INSTALL_DIR/bundle)..."
rm -rf "$INSTALL_DIR/bundle"
rm -f "$INSTALL_DIR/backend"

# Limpiar directorio titofy si quedó vacío
if [ -d "$INSTALL_DIR" ] && [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
    rmdir "$INSTALL_DIR" 2>/dev/null || true
fi

echo "6. Actualizando base de datos de escritorio de GNOME..."
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
echo "====================================================="
echo "  ✅ Titofy ha sido desinstalado completamente de tu sistema."
echo ""
echo "  ℹ️  Tus canciones y listas de reproducción locales"
echo "      están guardadas en: $DATA_DIR"
echo "      (Si también deseas borrar tu base de datos SQLite y favoritos,"
echo "       ejecuta: rm -rf \"$DATA_DIR\")"
echo "====================================================="
