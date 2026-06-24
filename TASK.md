# vimotion — TASK (Plan de implementación)

Desglose de tareas para construir la v1. Orden pensado para tener algo
funcionando pronto y luego pulir.

## Fase 0 — Scaffolding del proyecto

- [ ] T0.1 Crear `Package.swift` (target ejecutable `vimotion` + target de tests).
- [ ] T0.2 Estructura de carpetas (`App/`, `Hotkeys/`, `Windows/`, `Navigation/`,
      `Permissions/`, `Support/`).
- [ ] T0.3 `main.swift` arrancando una `NSApplication` como agente
      (`setActivationPolicy(.accessory)`).
- [ ] T0.4 `Logger` mínimo.

## Fase 1 — Núcleo de navegación (lógica pura, testeable)

- [ ] T1.1 `Direction` (enum: left/down/up/right + mapeo desde h/j/k/l).
- [ ] T1.2 `WindowInfo` (id, pid, frame, título, app).
- [ ] T1.3 `DirectionalNavigator`: algoritmo de selección direccional (función
      pura).
- [ ] T1.4 Tests unitarios `DirectionalNavigatorTests` (disposiciones varias).

## Fase 2 — Servicios del sistema

- [ ] T2.1 `AccessibilityPermission`: comprobar/solicitar permiso, abrir Ajustes.
- [ ] T2.2 `WindowEnumerating` + `AccessibilityWindowService`: enumerar ventanas
      visibles vía `CGWindowListCopyWindowInfo`, filtrar capa normal/tamaño.
- [ ] T2.3 `WindowFocuser`: localizar el `AXUIElement` de la ventana destino,
      `AXRaise` + activar la app propietaria.
- [ ] T2.4 Identificar la ventana enfocada actual (origen de la navegación).
- [ ] T2.5 `ScreenFiltering`: determinar el monitor activo (de la ventana
      enfocada, con fallback al cursor) y filtrar candidatas a ese monitor.

## Fase 3 — Atajos globales

- [ ] T3.1 `Shortcut` (modificador + tecla → dirección) y `LeaderKey`
      (modificador configurable).
- [ ] T3.2 `HotkeyManaging` (protocolo) con register/unregister.
- [ ] T3.3 `CarbonHotkeyManager`: registrar `<leader> + h/j/k/l` y emitir la
      dirección al coordinador; re-registrar al cambiar leader key.

## Fase 4 — Integración

- [ ] T4.1 `AppCoordinator`: hotkey → enumerar → filtrar por monitor → navegar →
      enfocar.
- [ ] T4.2 `Preferences`: persistir estado Enable/Disable y leader key
      (`UserDefaults`).
- [ ] T4.3 `MenuBarController`: icono con **Enable**, **Disable**, submenú de
      **leader key**, y **Quit**.
- [ ] T4.4 `AppDelegate`: ciclo de vida, comprobación de permiso al arrancar.
- [ ] T4.5 Conectar todo en `main.swift`.

## Fase 5 — Empaquetado y prueba real

- [ ] T5.1 `Info.plist` con `LSUIElement` y script/instrucciones para generar
      el `.app`.
- [ ] T5.2 Prueba manual: 2 ventanas lado a lado, apiladas, multi-monitor.
- [ ] T5.3 Instrucciones de instalación / Login Item en el `README.md`.

## Fase 6 — Pulido (opcional dentro de v1)

- [ ] T6.1 Afinar el coste del algoritmo según pruebas reales.
- [ ] T6.2 Mensajes claros cuando falta permiso.

## Backlog (post-v1, no implementar ahora)

- Configuración por archivo (atajos personalizables).
- Navegación cíclica / por número.
- Resaltado visual de la ventana destino.
- Soporte de Spaces / filtros por app o pantalla.

---

### Definición de "hecho" para v1

`Option + h/j/k/l` mueve el foco de forma fiable entre ventanas visibles en
disposiciones normales, la app corre en segundo plano sin icono en el Dock, y
gestiona el permiso de Accesibilidad correctamente.
