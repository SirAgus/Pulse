# 🏝️ PULSE - Dynamic Island for macOS

**PULSE** trae la experiencia de la Isla Dinámica de iOS a tu Mac, integrando widgets interactivos, controles de medios, temporizadores pomodoro y más, directamente sobre tu notch o barra de menús.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2014.0+-black.svg)

---

## 🚀 Instalación

### Opción 1: Homebrew (Recomendado)
La forma más fácil y rápida de mantener PULSE actualizado.

```bash
# Agrega el repositorio de fórmulas
brew tap SirAgus/tap

# Instala la aplicación
brew install --cask pulse
```

### Opción 2: Descarga Manual
1. Ve a la sección de [Releases](https://github.com/SirAgus/Pulse/releases).
2. Descarga el archivo `PULSE.dmg`.
3. Arrastra **PULSE.app** a tu carpeta de **Aplicaciones**.

---

## 🛡️ Permisos Requeridos
Para funcionar correctamente, PULSE te pedirá los siguientes permisos en el primer inicio:

*   **Accesibilidad**: Necesario para detectar el tamaño de las ventanas y posicionar la isla correctamente bajo el notch.
*   **Calendario**: Para mostrar tu próximo evento en el widget de calendario.
*   **Bluetooth**: Para listar tus dispositivos conectados (auriculares, ratón, etc.).
*   **Ubicación**: Requerido por macOS para poder leer el nombre (SSID) de tu red WiFi actual.
*   **Eventos de Apple (AppleScript)**: Para controlar apps como Music o Spotify (Play/Pause, Volumen).

---

## ⚠️ Solución al Error "App Dañada"
Si descargas la app **manualmente** (sin Brew), macOS mostrará un aviso de seguridad diciéndote que la app está dañada. **No está dañada**, simplemente no está firmada por Apple.

**Para solucionarlo, ejecuta esto en tu Terminal:**
```bash
xattr -cr /Applications/PULSE.app
```

*Si instalaste mediante **Homebrew**, este paso ya se realizó automáticamente.*

---

## ✨ Características
*   🎵 **Controles de Música**: Compatible con Music y Spotify.
*   ⏱️ **Temporizador Pomodoro**: Gestiona tus sesiones de enfoque.
*   ⏰ **Gestión de Alarmas**: Crea y edita alarmas rápidamente.
*   📊 **Widgets de Sistema**: Monitoriza CPU, Memoria, Batería y WiFi.
*   📋 **Portapapeles**: Historial reciente de tus items copiados.

---

## 📸 Capturas de Pantalla

### Vista General
![Full Demo](Resources/screenshots/full_demo.png)

### Modos Expandidos
| Música | Productividad (Pomodoro) | Notas |
| :---: | :---: | :---: |
| ![Música](Resources/screenshots/music_sound.png) | ![Focus](Resources/screenshots/focus.png) | ![Notas](Resources/screenshots/notes.png) |

### Utilidades y Widgets
| Sistema | Portapapeles | Cámara y Alarmas |
| :---: | :---: | :---: |
| ![Sistema](Resources/screenshots/apps_widgets.png) | ![Portapapeles](Resources/screenshots/clypaste.png) | ![Cámara](Resources/screenshots/camera_and_alarms.png) |

### Personalización
| Configuración | Estilo Liquid Glass | Widgets Personalizados |
| :---: | :---: | :---: |
| ![Configuración](Resources/screenshots/settings.png) | ![Liquid Glass](Resources/screenshots/change_bg.png) | ![Widgets](Resources/screenshots/add_widgets.png) |

### Modos Compactos y Alertas
| Música Compacta | Alerta de Enfoque | Alerta de Enfoque (Expandida) |
| :---: | :---: | :---: |
| ![Música](Resources/screenshots/music_collapsed.png) | ![Focus Collapsed](Resources/screenshots/focus_collapsed.png) | ![Focus Complete](Resources/screenshots/focus_complete.png) |

---

## 🛠️ Para Desarrolladores
Si quieres contribuir o compilar el proyecto tú mismo, consulta la [Guía de Lanzamiento](RELEASE_GUIDE.md).

---

**Hecho con ❤️ por [SirAgus](https://github.com/SirAgus)**
