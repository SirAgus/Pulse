# 🚀 Guía de Lanzamiento y Distribución (Homebrew)

Esta guía detalla los pasos necesarios para compilar, generar un release en GitHub y actualizar el instalador de Homebrew para **PULSE**.

---

## 1. Construcción del Proyecto y DMG
El script `build.sh` automatiza la compilación técnica y la creación del instalador macOS.

```bash
./build.sh
```
*   **¿Qué hace?**: Compila en modo Release, crea el bundle `PULSE.app`, copia iconos/recursos y empaqueta todo en un archivo `PULSE.dmg`.

---

## 2. Generación del Checksum (SHA256)
Homebrew requiere un "huella digital" del archivo para asegurar que la descarga sea segura y no haya sido alterada.

```bash
shasum -a 256 PULSE.dmg
```
*   **Resultado**: Un código largo (ej: `c615f8...`). Este código debe copiarse en el archivo `.rb`.

---

## 3. Creación del Release en GitHub
Publica tu software para que sea descargable públicamente.

```bash
# Crea el release y sube el DMG de una sola vez
gh release create v0.01.0 PULSE.dmg --generate-notes
```
*   **`v0.01.0`**: La versión del tag (debe coincidir con tu archivo .rb).
*   **`PULSE.dmg`**: El binario que vas a distribuir.
*   **`--generate-notes`**: Crea automáticamente la lista de cambios basados en tus commits.

---

## 4. Estructura del Cask para Homebrew (`pulse.rb`)
El archivo Ruby (`.rb`) es la "receta" que Brew lee para saber cómo instalar tu app.

```ruby
cask "pulse" do
  version "0.01.0" # Cambiar según el release
  sha256 "CODIGO_OBTENIDO_EN_PASO_2"

  url "https://github.com/SirAgus/Pulse/releases/download/v#{version}/PULSE.dmg"
  name "PULSE"
  desc "Dynamic Island for macOS"
  homepage "https://github.com/SirAgus/Pulse"

  app "PULSE.app" # Indica que debe instalar el archivo .app
end
```

---

## 5. Subida al Tap de Homebrew
Un **Tap** es tu repositorio personal de fórmulas de Brew (normalmente llamado `homebrew-tap`).

### Estructura del repositorio `homebrew-tap`:
```text
homebrew-tap/
└── Casks/
    └── pulse.rb
```

### Comandos para subir cambios:
```bash
cd ~/Documents/cask  # Tu carpeta del tap
git add .
git commit -m "Update PULSE to v0.01.0"
git push origin main
```

---

## 6. Comandos de Instalación para Usuarios
Una vez que el Tap está actualizado, cualquier usuario puede instalar PULSE con:

```bash
# 1. Agrega tu repositorio de fórmulas
brew tap SirAgus/tap

# 2. Instala la aplicación
brew install --cask pulse
```

---

## 💡 Notas Importantes
*   **Inmutabilidad**: Si cambias el archivo `PULSE.dmg` en GitHub pero no actualizas el `sha256` en el Ruby, Brew dará error de seguridad. Cada cambio de archivo requiere un nuevo hash.
*   **Prueba Local**: Puedes probar tu receta antes de subirla con `brew install --cask ./Casks/pulse.rb`.

## ⚠️ Solución al Error "App dañada" (macOS Gatekeeper)
Al ser una app nueva y no estar firmada con un certificado de Apple Developer (que cuesta $99/año), macOS la marcará como "dañada" al descargarla de internet.

**Para arreglarlo, el usuario debe ejecutar este comando una sola vez:**
```bash
xattr -cr /Applications/PULSE.app
```
Esto elimina el atributo de "cuarentena" y permite que la app abra normalmente. Puedes incluir esta instrucción en el README de tu proyecto.
