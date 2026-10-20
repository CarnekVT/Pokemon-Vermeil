# Movement Studio — Editor UI v0.6.0

Interfaz reconstruida con la organización visual de **Battle Animation Studio (BAS)** y **Battle Scene Studio (BSS)**. Esta actualización es exclusivamente del **editor de Maker Studio**. El plugin Ruby de movimiento se conserva en su versión **0.5.0**.

## Ventana de trabajo

- Barra superior: contexto Global/Mapa, estado de modificaciones, Recargar y Guardar.
- Navegación izquierda: **Vista general**, **Control**, **Diagonales**, **Cámara** y **Diagnóstico**.
- Área central: escenario esquemático con cuadrícula, jugador, flechas de movimiento, zonas de cámara y controles de dirección **solo para previsualizar**.
- Inspector derecho: campos agrupados, valores actuales, ayudas breves, etiquetas **GLOBAL/MAPA**, y botón para restablecer o heredar cada campo.
- Pie de estado: confirmación de lectura/guardado y ruta real de `config.ini`.
- Perfiles rápidos **Clásico** y **Moderno**, aplicados a los controles del ámbito actual sin escribir en disco hasta pulsar **Guardar**.
- CSS separado en `styles.js` para facilitar futuras iteraciones visuales.

El diseño utiliza los principios de BAS/BSS: fondo oscuro, barra de herramientas, inspector por secciones, tarjetas discretas, estados claros y áreas de trabajo independientes. No replica timeline ni sistemas de combate que no tengan aplicación en Movement Studio.

## Presentación responsive

- Ventana recomendada: 1400×860. Maker Studio administra el tamaño real de la ventana.
- Ancho intermedio: la navegación se compacta a iconos.
- Ancho estrecho: la navegación pasa a una tira superior y el inspector se apila bajo la vista.
- No impone tamaños fijos ni altera ventanas del sistema operativo.

## Configuración y seguridad

- Archivo: `Plugins/[VERMEIL] Smooth Movement/config.ini`.
- Mantiene los campos antiguos compatibles y conserva los valores de partida existentes.
- Global y mapas tienen perfiles separados. Al editar un mapa, el indicador **GLOBAL** significa que el campo hereda el ajuste global; al cambiarlo pasa a ser un valor propio de ese mapa.
- La acción **↶** en un mapa elimina solo la sobrescritura del campo. En Global devuelve el campo a su valor original.
- Los cambios se aplican solo al pulsar **Guardar**. Después, el editor lee el archivo para verificarlo.
- **Recargar** exige una segunda pulsación para descartar cambios no guardados.
- La vista central es un **esquema interactivo de configuración**, no un simulador ni un game preview. Las flechas cambian solo el dibujo.
- No se cambian temporizadores, colisiones, Turbo, Continuous Flow ni Fancy Camera en esta versión de UI.

## Validación inicial

Probado con un entorno simulado de las APIs de Maker Studio:

1. El archivo JavaScript se analiza sin errores de sintaxis.
2. Los cinco apartados renderizan su inspector.
3. Se cargan opciones antiguas desde un INI existente.
4. Cambiar un valor para `[map:12]` no sobrescribe `[global]`.
5. Guardar y volver a leer conservan las opciones elegidas.

Pendiente de comprobación manual en Maker Studio real: apertura desde menú Mods, tamaños acoplados y compactos, enfoque del teclado y renderizado CSS en el webview del editor.
