# 🎵 Guía de Instalación de Titofy v1.0.0

Bienvenido a **Titofy**, tu reproductor multimedia inteligente con soporte para letras sincronizadas en tiempo real, modo karaoke, visualizadores de espectro de audio e inteligencia artificial Whisper para transcribir y alinear canciones sin conexión a internet.

---

## 🪟 Instalación en Windows (Windows 10 / 11)

### 🚀 Instalación en 3 Pasos:
1. **Descarga el instalador:**  
   Descarga el archivo **`Titofy-Setup-v1.0.0.exe`** desde la sección oficial de [Releases de GitHub](../../releases).

2. **Ejecuta el instalador:**  
   Haz doble clic sobre **`Titofy-Setup-v1.0.0.exe`**.  
   *(Nota: Si Windows SmartScreen muestra el aviso habitual de "Windows protegió su PC", haz clic en **Más información** y luego en **Ejecutar de todas formas**).*

3. **Sigue el Asistente:**  
   Presiona **Siguiente**, elige si deseas crear un acceso directo en el Escritorio y haz clic en **Instalar**.

¡Listo! Titofy se iniciará automáticamente y estará disponible en tu **Menú Inicio** y **Escritorio**.

---

## 🐧 Instalación en Linux (Ubuntu, Debian, Fedora, Arch, etc.)

Titofy se integra de forma nativa en tu entorno de escritorio (GNOME, KDE Plasma, XFCE, etc.), asociando formatos de audio y creando el acceso en tu menú de aplicaciones.

### 🚀 Instalación Rápida:
Abre una terminal en esta carpeta y ejecuta:

```bash
chmod +x linux/instalar_linux.sh
./linux/instalar_linux.sh
```

### ¿Qué hace el instalador?
- Instala Titofy en `~/.local/share/titofy/`.
- Crea el acceso directo en el menú de aplicaciones de tu sistema con el ícono oficial en alta resolución.
- Crea el comando ejecutable global `titofy` para que puedas abrir el reproductor o reproducir canciones directamente desde la terminal.

### 🗑️ Desinstalación en Linux:
Si en algún momento deseas desinstalar la aplicación limpiamente:
```bash
./linux/desinstalar_linux.sh
```
O simplemente ejecutando en cualquier terminal:
```bash
uninstall-titofy
```

---

## ⚡ Requisitos del Sistema

| Requisito | Mínimo | Recomendado |
| :--- | :--- | :--- |
| **Sistema Operativo** | Windows 10 (64-bit) o Linux (64-bit) | Windows 11 o Ubuntu 22.04+ |
| **Memoria RAM** | 4 GB | 8 GB o superior |
| **Almacenamiento** | 500 MB libres | 2 GB libres (para modelos de IA Whisper) |
| **Tarjeta Gráfica (GPU)** | Gráficos integrados (CPU) | NVIDIA (RTX / GTX) con soporte CUDA para IA acelerada |

---

## 💡 Consejos de Uso
- **Búsqueda automática de letras:** Al reproducir cualquier canción, Titofy buscará automáticamente la letra sincronizada en la nube.
- **Studio IA:** Si tienes una canción que no existe en internet, entra a la pestaña **Studio IA** para que el modelo Whisper transcriba y sincronice los versos usando tu propia computadora.
- **Personalización:** En la sección **Ajustes**, puedes personalizar el tema, tamaño de letra del karaoke y color de acento de la aplicación.
