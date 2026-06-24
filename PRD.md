# vimotion — PRD (Product Requirements Document)

## 1. Resumen

**vimotion** es una utilidad ligera para macOS, escrita en Swift, que permite
mover el foco entre las ventanas abiertas usando atajos de teclado al estilo Vim
(`Option + h/j/k/l`), sin necesidad de usar el ratón.

Es una alternativa minimalista a herramientas como `aerospace` o `yabai`: en
lugar de gestionar tiling, resize o escritorios virtuales, vimotion hace **una
sola cosa y la hace bien** — navegar direccionalmente entre ventanas activas.

## 2. Problema

Al trabajar con varias ventanas en pantalla, cambiar de foco obliga a usar el
ratón o a recorrer ventanas en orden arbitrario con `Cmd + ~` / `Cmd + Tab`.
Esto rompe el flujo de quien está acostumbrado a navegar con el teclado (usuarios
de Vim, tmux, etc.).

Herramientas como aerospace resuelven esto, pero arrastran un montón de
funcionalidad (tiling managers, workspaces, resize) que no se necesita y que
añade complejidad, configuración y consumo de recursos.

## 3. Objetivo

Poder mover el foco entre ventanas en pantalla **direccionalmente** con:

- `Option + h` → ventana a la **izquierda**
- `Option + j` → ventana **abajo**
- `Option + k` → ventana **arriba**
- `Option + l` → ventana a la **derecha**

Nada más.

## 4. Alcance (Scope)

### Dentro de alcance (v1)

- Navegación direccional del foco entre ventanas visibles.
- Atajo global configurable por código (`Option + h/j/k/l` por defecto).
- Funcionamiento como agente en segundo plano (sin icono en el Dock; con icono
  en la barra de menús).
- Icono en la barra de menús con tres acciones: **Enable**, **Disable** y
  **Quit**, y la opción de cambiar la **leader key** (modificador).
- Navegación limitada al **monitor activo** (el monitor donde está la aplicación
  enfocada). En setups de varios monitores no se salta entre pantallas.
- Gestión del permiso de Accesibilidad de macOS (necesario para mover foco).

### Fuera de alcance (v1, explícito)

- ❌ Redimensionar (resize) ventanas.
- ❌ Mover/recolocar ventanas.
- ❌ Escritorios o espacios virtuales (Spaces).
- ❌ Tiling automático.
- ❌ Personalización de las teclas de dirección (siempre `h/j/k/l`; si se
  pudieran cambiar, dejaría de ser "vim" 😄). **Excepción**: la leader key /
  modificador sí es cambiable (Option por defecto) para quien no quiera usar
  Option.
- ❌ Interfaz gráfica de configuración compleja (solo el menú de barra).
- ❌ Soporte para otros sistemas operativos (solo macOS por ahora).

## 5. Usuarios

Usuario único (personal): un desarrollador que usa el teclado intensivamente y
quiere navegar entre ventanas sin levantar las manos del teclado.

## 6. Experiencia de usuario

1. El usuario instala/ejecuta vimotion.
2. La app pide el permiso de Accesibilidad la primera vez (con instrucciones
   claras).
3. A partir de ahí, en cualquier momento, `Option + h/j/k/l` mueve el foco a la
   ventana más cercana en esa dirección.
4. La app vive en segundo plano con un icono en la barra de menús que permite
   **Enable** / **Disable** la navegación, cambiar la **leader key** y **Quit**.

### Comportamiento multi-monitor

La navegación se restringe al **monitor activo**, entendido como el monitor que
contiene la **aplicación/ventana enfocada**. Así, `Option + l` mueve el foco a
la ventana más cercana a la derecha **dentro de ese mismo monitor**, sin saltar a
otra pantalla.

## 7. Criterios de éxito

- Pulsar `Option + l` con dos ventanas lado a lado mueve el foco a la de la
  derecha de forma fiable (>95% de aciertos en disposiciones normales).
- Latencia percibida < 100 ms entre la pulsación y el cambio de foco.
- Consumo en reposo prácticamente nulo (sin polling activo; basado en eventos).
- Cero configuración para el caso por defecto.

## 8. Principios de diseño

- **Minimalismo**: una responsabilidad, sin opciones innecesarias.
- **Arquitectura extensible**: el núcleo (detección de ventanas, hotkeys,
  navegación) está desacoplado para poder añadir en el futuro cosas como
  navegación por ciclo, soporte de Spaces, o configuración por archivo — sin
  reescribir.
- **Nativo y ligero**: solo AppKit / APIs del sistema, sin dependencias externas.

## 9. Posibles ampliaciones futuras (no v1)

- Archivo de configuración (atajos personalizables, modos).
- Navegación cíclica / por número de ventana.
- Resaltado visual de la ventana destino.
- Filtrado por app o por pantalla.
- Soporte de Spaces / pantalla completa.
