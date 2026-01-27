# Dynamic Island for macOS 🏝️

Una aplicación nativa para macOS inspirada en la "Isla Dinámica" de iOS y aplicaciones como Alcove.

## Características
- **Isla Dinámica**: Una ventana flotante en la parte superior central de la pantalla.
- **Modo Música**: Se expande automáticamente cuando detecta música reproduciéndose en Music.app o Spotify.
- **Modo Batería**: Muestra el estado de la batería y se activa al conectar el cargador.
- **Animaciones Suaves**: Utiliza SwiftUI para transiciones fluidas y orgánicas.
- **Nativa y Ligera**: Construida puramente en Swift y SwiftUI.

## Cómo ejecutar
1. Abre la carpeta `DynamicIslandApp` en tu terminal.
2. Ejecuta `./build.sh` para compilar y crear el paquete de aplicación.
3. Ejecuta `open DynamicIsland.app`.

Alternativamente, puedes abrir la carpeta `DynamicIslandApp` en **Xcode** y ejecutar el proyecto directamente.

## Estructura del Proyecto
- `IslandApp.swift`: Punto de entrada y lógica de la ventana (`NSPanel`).
- `IslandView.swift`: La interfaz de usuario construida con SwiftUI.
- `IslandState.swift`: Gestor de estado que controla los modos y expansiones.
- `MusicObserver.swift`: Observa cambios en la reproducción de medios.
- `BatteryObserver.swift`: Monitorea el estado de la batería.

## Personalización
Puedes ajustar los tamaños y colores en `IslandView.swift`. El comportamiento de expansión se define en `IslandState.swift`.
