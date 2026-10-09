#!/usr/bin/env bash
# ==============================================================================
# Titofy — Instalador Oficial para Linux (Ubuntu, Debian, Fedora, Arch, etc.)
# ==============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_SRC="$REPO_DIR/desktop/build/linux/x64/release/bundle"

INSTALL_DIR="$HOME/.local/share/titofy"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR_512="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_DIR_256="$HOME/.local/share/icons/hicolor/256x256/apps"
PIXMAPS_DIR="$HOME/.local/share/pixmaps"

echo "=========================================================="
echo "          🚀 INSTALADOR OFICIAL DE TITOFY (LINUX)         "
echo "=========================================================="

# 1. Compilar release nativo de Flutter
echo "⚙️ Compilando release nativo más reciente de Titofy con Flutter..."
(cd "$REPO_DIR/desktop" && flutter build linux --release)

echo "📦 1. Creando directorios del sistema de usuario..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$ICON_DIR_512"
mkdir -p "$ICON_DIR_256"
mkdir -p "$PIXMAPS_DIR"

echo "📂 2. Instalando bundle nativo de Titofy..."
rm -rf "$INSTALL_DIR/bundle"
mkdir -p "$INSTALL_DIR/bundle"
cp -r "$BUNDLE_SRC/"* "$INSTALL_DIR/bundle/"
chmod +x "$INSTALL_DIR/bundle/desktop"

echo "🧠 3. Enlazando backend de IA (FastAPI / Whisper)..."
ln -sfn "$REPO_DIR/backend" "$INSTALL_DIR/backend"

echo "🎨 4. Instalando ícono oficial de la aplicación..."
ICON_SRC="$REPO_DIR/desktop/assets/images/logo.png"
if [ ! -f "$ICON_SRC" ]; then
    ICON_SRC="$REPO_DIR/Logo_app_desktop.jpg"
fi
cp "$ICON_SRC" "$ICON_DIR_512/titofy.png" 2>/dev/null || true
cp "$ICON_SRC" "$ICON_DIR_256/titofy.png" 2>/dev/null || true
cp "$ICON_SRC" "$PIXMAPS_DIR/titofy.png" 2>/dev/null || true

echo "🚀 5. Creando binario ejecutable en $BIN_DIR/titofy..."
cat << 'EOF' > "$BIN_DIR/titofy"
#!/usr/bin/env bash
BUNDLE_DIR="$HOME/.local/share/titofy/bundle"
export LD_LIBRARY_PATH="$BUNDLE_DIR/lib:$LD_LIBRARY_PATH"
exec "$BUNDLE_DIR/desktop" "$@"
EOF
chmod +x "$BIN_DIR/titofy"

echo "🖥️ 6. Creando lanzador para el menú de aplicaciones..."
cat << EOF > "$DESKTOP_DIR/com.titofy.desktop.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Titofy
GenericName=Reproductor de Música y Letras IA
Comment=Reproductor inteligente con letras sincronizadas, Forced Alignment y visualizadores FFT
Exec=$BIN_DIR/titofy %U
Icon=titofy
Terminal=false
Categories=AudioVideo;Audio;Player;Music;
MimeType=audio/mpeg;audio/flac;audio/x-wav;audio/ogg;audio/mp4;audio/aac;
Keywords=titofy;musica;music;player;lyrics;karaoke;lrc;audio;
StartupNotify=true
StartupWMClass=com.titofy.desktop
EOF
chmod +x "$DESKTOP_DIR/com.titofy.desktop.desktop"

echo "🗑️ 7. Instalando desinstalador en $BIN_DIR/uninstall-titofy..."
cat << 'EOF' > "$BIN_DIR/uninstall-titofy"
#!/usr/bin/env bash
echo "Eliminando Titofy del sistema..."
rm -rf "$HOME/.local/share/titofy"
rm -f "$HOME/.local/bin/titofy"
rm -f "$HOME/.local/share/applications/com.titofy.desktop.desktop"
rm -f "$HOME/.local/share/icons/hicolor/512x512/apps/titofy.png"
rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/titofy.png"
rm -f "$HOME/.local/share/pixmaps/titofy.png"
rm -f "$HOME/.local/bin/uninstall-titofy"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
echo "✅ Titofy ha sido desinstalado de tu sistema."
EOF
chmod +x "$BIN_DIR/uninstall-titofy"

echo "🔄 8. Actualizando base de datos de escritorio..."
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
echo "=========================================================="
echo "  🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!               "
echo "  • Abre Titofy desde el menú de aplicaciones de tu PC.   "
echo "  • O ejecutando el comando 'titofy' en la terminal.      "
echo "  • Para desinstalar ejecuta: 'uninstall-titofy'         "
echo "=========================================================="
