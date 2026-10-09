#!/usr/bin/env bash
# Titofy — Script de Instalación Nativa en Linux
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_SRC="$REPO_DIR/desktop/build/linux/x64/release/bundle"

INSTALL_DIR="$HOME/.local/share/titofy"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR_512="$HOME/.local/share/icons/hicolor/512x512/apps"
ICON_DIR_256="$HOME/.local/share/icons/hicolor/256x256/apps"
PIXMAPS_DIR="$HOME/.local/share/pixmaps"

echo "====================================================="
echo "   🚀 Instalando Titofy Nativamente en tu PC Linux   "
echo "====================================================="

# 1. Verificar binario release
if [ ! -f "$BUNDLE_SRC/desktop" ]; then
    echo "⚙️ Compilando release bundle de Titofy..."
    (cd "$REPO_DIR/desktop" && flutter build linux --release)
fi

echo "📦 1. Creando directorios del sistema de usuario..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$ICON_DIR_512"
mkdir -p "$ICON_DIR_256"
mkdir -p "$PIXMAPS_DIR"

echo "📂 2. Copiando bundle optimizado a $INSTALL_DIR/bundle..."
rm -rf "$INSTALL_DIR/bundle"
mkdir -p "$INSTALL_DIR/bundle"
cp -r "$BUNDLE_SRC/"* "$INSTALL_DIR/bundle/"
chmod +x "$INSTALL_DIR/bundle/desktop"

echo "🧠 3. Conectando backend de IA..."
ln -sfn "$REPO_DIR/backend" "$INSTALL_DIR/backend"

echo "🎨 4. Instalando ícono oficial de Titofy..."
ICON_SRC="$REPO_DIR/desktop/assets/images/logo.png"
if [ ! -f "$ICON_SRC" ]; then
    ICON_SRC="$REPO_DIR/Logo_app_desktop.jpg"
fi
cp "$ICON_SRC" "$ICON_DIR_512/titofy.png"
cp "$ICON_SRC" "$ICON_DIR_256/titofy.png"
cp "$ICON_SRC" "$PIXMAPS_DIR/titofy.png"

echo "🚀 5. Creando lanzador ejecutable en $BIN_DIR/titofy..."
cat << 'EOF' > "$BIN_DIR/titofy"
#!/usr/bin/env bash
# Lanzador nativo de Titofy
BUNDLE_DIR="$HOME/.local/share/titofy/bundle"
export LD_LIBRARY_PATH="$BUNDLE_DIR/lib:$LD_LIBRARY_PATH"
exec "$BUNDLE_DIR/desktop" "$@"
EOF
chmod +x "$BIN_DIR/titofy"

echo "🖥️ 6. Creando entrada en el menú de aplicaciones de GNOME / Ubuntu..."
cat << EOF > "$DESKTOP_DIR/com.titofy.desktop.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Titofy
GenericName=Reproductor de Música y Letras
Comment=Reproductor inteligente con letras sincronizadas y visualizadores FFT
Exec=$BIN_DIR/titofy %U
Icon=titofy
Terminal=false
Categories=AudioVideo;Audio;Player;Music;
MimeType=audio/mpeg;audio/flac;audio/x-wav;audio/ogg;audio/mp4;audio/aac;
Keywords=titofy;musica;music;player;lyrics;karaoke;lrc;audio;
StartupNotify=true
StartupWMClass=titofy
EOF
chmod +x "$DESKTOP_DIR/com.titofy.desktop.desktop"

echo "🗑️ 7. Instalando desinstalador en $BIN_DIR/uninstall-titofy..."
cp "$REPO_DIR/scripts/uninstall_native.sh" "$BIN_DIR/uninstall-titofy"
chmod +x "$BIN_DIR/uninstall-titofy"

echo "🔄 8. Actualizando base de datos de escritorio e íconos..."
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
echo "====================================================="
echo "  ✅ ¡Instalación completada con éxito!"
echo "  • Puedes abrir Titofy desde tu menú de aplicaciones"
echo "    o ejecutando 'titofy' en la terminal."
echo "  • Para desinstalar en cualquier momento, ejecuta:"
echo "    'uninstall-titofy' o './scripts/uninstall_native.sh'"
echo "====================================================="
