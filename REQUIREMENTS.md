# vimotion — REQUIREMENTS (Requisitos técnicos)

## 1. Plataforma y herramientas

- **SO**: macOS 13 (Ventura) o superior.
- **Lenguaje**: Swift 5.9+.
- **Frameworks**: AppKit, ApplicationServices (Accessibility API), Carbon
  (`RegisterEventHotKey`) o `CGEventTap` para el atajo global.
- **Build**: Swift Package Manager (target ejecutable que se empaqueta como
  `.app`). Sin dependencias de terceros.
- **Arquitectura**: Apple Silicon + Intel (universal, no crítico para uso
  personal).

## 2. Requisitos funcionales

| ID    | Requisito |
|-------|-----------|
| RF-1  | Registrar un atajo global `Option + h/j/k/l`. |
| RF-2  | Al pulsar el atajo, identificar la ventana actualmente enfocada. |
| RF-3  | Enumerar las ventanas visibles candidatas, **restringidas al monitor de la ventana enfocada**. |
| RF-4  | Seleccionar la ventana destino más adecuada en la dirección indicada. |
| RF-5  | Dar foco a la ventana destino (activar app + elevar ventana). |
| RF-6  | Gestionar el permiso de Accesibilidad (detectar, solicitar, guiar). |
| RF-7  | Ejecutarse como agente en segundo plano (`LSUIElement`). |
| RF-8  | Icono en barra de menús con **Enable**, **Disable** y **Quit**. |
| RF-9  | Permitir cambiar la **leader key** (modificador) desde el menú; teclas de dirección fijas (`h/j/k/l`). |
| RF-10 | El estado Enable/Disable y la leader key elegida persisten entre reinicios (`UserDefaults`). |

## 3. Requisitos no funcionales

| ID     | Requisito |
|--------|-----------|
| RNF-1  | Latencia < 100 ms por pulsación. |
| RNF-2  | Sin polling continuo: trabajo solo en respuesta a eventos. |
| RNF-3  | Sin dependencias externas. |
| RNF-4  | Código modular y testeable (lógica de selección pura, sin efectos). |
| RNF-5  | Manejo correcto de errores cuando faltan permisos. |

## 4. Detalles técnicos clave

### 4.1 Detección y control de ventanas

- **Permiso de Accesibilidad** (`AXIsProcessTrusted`) es obligatorio para leer la
  posición de ventanas de otras apps y para enfocarlas.
- **Enumeración de ventanas**: combinación de
  - `CGWindowListCopyWindowInfo` (lista de ventanas en pantalla, con bounds,
    capa/layer y owner PID) para filtrar ventanas reales y visibles, y
  - **Accessibility API** (`AXUIElement` por aplicación → `kAXWindowsAttribute`)
    para poder **enfocar/elevar** la ventana destino (`AXRaise` +
    `NSRunningApplication.activate`).
- Filtrar: solo ventanas con `kCGWindowLayer == 0` (capa normal), con tamaño
  mínimo razonable, no offscreen, excluyendo elementos del sistema (barra de
  menús, Dock, wallpaper).

### 4.2 Geometría y coordenadas

- `CGWindowList` usa coordenadas con origen arriba-izquierda (top-left) del
  espacio global de pantallas; la Accessibility API también. Hay que unificar el
  sistema de coordenadas usado en el cálculo direccional.
- Cada ventana se representa por su rectángulo (`CGRect`) y un punto de
  referencia (su centro).

### 4.2.1 Restricción al monitor activo

- El **monitor activo** se determina por la **ventana enfocada**: el `NSScreen`
  cuyo `frame` contiene el centro (o la mayor área) de la ventana origen.
- Antes de aplicar el algoritmo direccional, la lista de candidatas se **filtra**
  para conservar solo las ventanas cuyo centro cae en ese mismo `NSScreen`.
- Si no hay ventana enfocada clara, se usa el `NSScreen` que contiene el cursor
  (`NSEvent.mouseLocation`) como respaldo.

### 4.3 Algoritmo de navegación direccional

Entrada: ventana actual (origen) + dirección (left/down/up/right) + lista de
ventanas candidatas.

Lógica (función pura, sin efectos secundarios):

1. Descartar la ventana origen.
2. Filtrar candidatas que están en la dirección pedida respecto al origen
   (p. ej., para `right`, las que tienen su centro a la derecha del centro del
   origen, dentro de un cono/sector angular para evitar saltos raros).
3. Entre las candidatas, elegir la de **menor coste**, combinando:
   - distancia en el eje principal (la dirección de movimiento), y
   - penalización por desalineación en el eje perpendicular (solapamiento).
4. Si no hay candidata en esa dirección, no hacer nada (o, futuro: ciclar).

El algoritmo se aísla en un componente testeable con casos sintéticos.

### 4.4 Atajo global

- Opción A: **Carbon `RegisterEventHotKey`** — simple, fiable, no requiere
  permisos extra, ideal para combinaciones fijas con modificador.
- Opción B: **`CGEventTap`** — más flexible (útil a futuro para modos/secuencias)
  pero requiere permiso de Accesibilidad (que ya tenemos) y más cuidado.
- **Decisión v1**: empezar con Carbon `RegisterEventHotKey` por simplicidad,
  detrás de una abstracción `HotkeyManaging` para poder cambiar a event tap más
  adelante sin tocar el resto.
- **Leader key cambiable**: el modificador (Option por defecto) se puede cambiar
  desde el menú (p. ej. Option / Command / Control / Ctrl+Option). Las teclas de
  dirección (`h/j/k/l`) son fijas. Al cambiarla, se vuelven a registrar los 4
  atajos con el nuevo modificador.

### 4.4.1 Estado Enable / Disable

- El menú permite **Disable**: se des-registran los atajos (o se ignoran), de
  modo que las teclas vuelven a su comportamiento normal.
- **Enable** los vuelve a registrar.
- El estado actual y la leader key se guardan en `UserDefaults` y se restauran al
  arrancar.

### 4.5 Permisos

- Comprobar `AXIsProcessTrustedWithOptions` al arrancar.
- Si falta, mostrar aviso y abrir
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- No bloquear: reintentar/observar hasta que se conceda.

## 5. Arquitectura propuesta

Separación en capas con responsabilidades claras y dependencias hacia
abstracciones (protocolos), de modo que cada pieza sea sustituible y testeable.

```
vimotion/
├── Package.swift
├── Sources/
│   └── vimotion/
│       ├── main.swift                  # punto de entrada (NSApplication)
│       ├── App/
│       │   ├── AppDelegate.swift        # ciclo de vida
│       │   ├── AppCoordinator.swift     # une hotkeys + navegación
│       │   ├── MenuBarController.swift   # icono + Enable/Disable/Leader/Quit
│       │   └── Preferences.swift         # estado enable + leader key (UserDefaults)
│       ├── Hotkeys/
│       │   ├── HotkeyManaging.swift     # protocolo
│       │   ├── CarbonHotkeyManager.swift# implementación Carbon
│       │   ├── LeaderKey.swift          # modificador configurable
│       │   └── Shortcut.swift           # modelo (modificador + tecla + dirección)
│       ├── Windows/
│       │   ├── WindowInfo.swift         # modelo de ventana (id, pid, frame, ...)
│       │   ├── WindowEnumerating.swift  # protocolo
│       │   ├── AccessibilityWindowService.swift # CGWindowList + AX
│       │   ├── ScreenFiltering.swift     # restringir candidatas al monitor activo
│       │   └── WindowFocuser.swift      # dar foco/elevar
│       ├── Navigation/
│       │   ├── Direction.swift          # enum left/down/up/right
│       │   └── DirectionalNavigator.swift # algoritmo puro de selección
│       ├── Permissions/
│       │   └── AccessibilityPermission.swift
│       └── Support/
│           └── Logger.swift
├── Tests/
│   └── vimotionTests/
│       └── DirectionalNavigatorTests.swift  # tests de la lógica pura
├── PRD.md
├── REQUIREMENTS.md
└── TASK.md
```

### Principios de la arquitectura

- **Núcleo puro testeable**: `DirectionalNavigator` recibe datos
  (`[WindowInfo]`, origen, `Direction`) y devuelve la ventana destino. Cero
  dependencias de AppKit → 100% testeable.
- **Servicios detrás de protocolos**: `WindowEnumerating`, `HotkeyManaging`
  permiten sustituir implementaciones (mocks en tests, event tap en el futuro).
- **Coordinador delgado**: `AppCoordinator` orquesta: recibe dirección del
  hotkey, pide ventanas al servicio, llama al navegador, enfoca el resultado.
- **Extensibilidad**: añadir configuración, modos o Spaces en el futuro = añadir
  módulos/implementaciones, sin reescribir el núcleo.

## 6. Empaquetado y ejecución

- `swift build` genera el ejecutable.
- Un pequeño script/instrucciones para empaquetarlo como `.app` con `Info.plist`
  que incluya `LSUIElement = true` (sin Dock) — necesario para que el permiso de
  Accesibilidad sea estable y para correr en background.
- Para uso personal: opción de añadirlo a *Login Items* para arranque
  automático.

## 7. Pruebas

- **Unitarias**: `DirectionalNavigatorTests` con disposiciones sintéticas
  (lado a lado, apiladas, diagonales, multi-monitor, sin candidata).
- **Manuales**: checklist de navegación real con 2–4 ventanas y 2 monitores.
