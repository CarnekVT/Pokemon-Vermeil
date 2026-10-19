# Lighting Studio v0.4.0 — Maker Studio / Pokémon Essentials 21.1

Estado: prototipo experimental, **sin pruebas de interfaz ni de runtime dentro del juego**. No distribuir como release estable.

## Archivos
- Mod del editor: `Plugins/MakerStudio/003_Editor/Mods/Lighting Studio/`
- Plugin Ruby: `Plugins/Lighting Studio Runtime/`
- Datos por mapa: `Data/LightingStudio/maps.json` (se conserva el esquema 1).
- Se requiere JSON Compatibility si el Ruby embebido no dispone de `JSON.parse`.

## Flujo de edición (referencia BAS/BSS)
1. Abre un mapa y elige **Mods > Lighting Studio**.
2. Usa la herramienta **Seleccionar / Añadir luz / Borrar** sobre el propio mapa.
3. En la biblioteca, elige una fuente existente o crea una nueva (radial, cono, elipse o rectángulo).
4. En el inspector, usa las pestañas:
   - **Forma**: tipo, tamaño, rotación, color, intensidad y modo de mezcla.
   - **Difuminado**: origen **Centro, Arriba, Abajo, Izquierda, Derecha o Personalizado** (origen X/Y entre -1 y 1), suavidad y brillo central.
   - **Pulsación**: velocidad, variación de intensidad y tamaño.
   - **Pixel art**: tamaño de bloque y niveles de degradado.
5. La iluminación se previsualiza **sobre el mapa**, no en un canvas separado. Los cambios se guardan en `maps.json`.

Las coordenadas X/Y del inspector admiten decimales hasta tres cifras (`25.30`, `30,75`, etc.). La herramienta de puntero todavía trabaja por casillas.

## Composición de luces
- **Aditiva (predeterminada)**: las fuentes se componen sobre **una sola superficie** y se aplican al mapa una única vez.
- En el editor, la mezcla del mapa compartido prioriza el brillo máximo por canal (`lighten`) en lugar de acumular todas las pasadas (`lighter`).
- En el runtime, el bitmap compartido utiliza mezcla normal de alpha de máscaras y una sola pasada aditiva. Es una unión más suave, pero **no equivale exactamente a la mezcla por máximo del editor**.
- **Normal** y **Sustractiva** mantienen el modo de composición individual. No hay sombras físicas ni oclusión todavía.

## Mejoras de rendimiento
- Las máscaras 2D se generan una sola vez por configuración y se reutilizan (máximo 16 máscaras en el editor).
- La composición del editor usa una superficie de media resolución y caché de hasta tres vistas por mapa/cámara/revisión.
- Las peticiones de repintado se agrupan; hay control para no acumular redibujados cuando Maker Studio está ocupado.
- El mouse no solicita un nuevo repintado si permanece en la misma casilla.
- El runtime crea un bitmap compartido a media resolución y lo recompone cuando se mueve la cámara o cambia el estado de pulsación. La velocidad nominal de pulsación es 8 actualizaciones de bitmap por segundo.
- El inspector muestra tiempo de dibujo del overlay y demora hasta que Maker Studio ejecuta el repintado.

## Validación indispensable
1. Verifica que las geometrías radial, cono, elipse y rectángulo se ven en editor y juego.
2. Superpón dos luces **Aditivas** del mismo color; confirma que se ven como una iluminación continua.
3. Alterna el origen de difuminado Arriba/Abajo e Izquierda/Derecha. Verifica orientación en ambas vistas.
4. Edita rápidamente radio, intensidad, color, suavidad y brillo central. Revisa que no se reinicie el scroll del panel.
5. Comprueba los indicadores de latencia del overlay y el FPS del editor, tanto con mapa vacío como con 5/20 fuentes, con y sin pulsación.
6. Comprueba F12, cambios de mapa, scrolling, condiciones meteorológicas y Animated Props.
7. Revisa rendimiento de carga del mapa y de movimiento de cámara en el juego.

## Limitaciones declaradas
- No se han medido FPS ni tiempos de carga en una instancia real de Maker Studio; **la eliminación del lag no está confirmada**.
- La unión de luces en el juego usa alpha-composition, no un shader MAX ni un lightmap físicamente correcto.
- El color del ambiente en juego sigue utilizando una capa oscura y puede diferir del editor.
- Las luces no tienen sombras de geometría ni seguimiento de eventos/jugador.
- El plugin no edita el núcleo de Maker Studio y puede verse afectado por su API o por otros overlays.
- Los cambios del editor se guardan, pero el juego recarga datos al entrar en el mapa.

## v0.4.1 — Zoom, Ruby SyntaxError y repintado

- **Corrección del error Ruby**: reemplazadas las expresiones inválidas `/h-.5` y `/w-.5` por `/h - 0.5` y `/w - 0.5`. Los siguientes mensajes sobre `end` eran errores en cascada de ese parseo.
- **Zoom de Maker Studio**: la coordenada de cada luz utiliza la transformación de Animated Props: `(tile * tileSize - viewportOffset) * zoom`. Una única luz se dibuja directamente en el canvas del mapa; las luces fusionadas usan una superficie compartida con escalado exacto, sin ajustar su tamaño al ancho del viewport (que provocaba redondeos de posición).
- **Zoom del juego**: el runtime redondea el desplazamiento del mapa antes de proyectar y aplica zoom respecto al centro de pantalla, como LBDS Animated Props. El lightmap compartido se fija a la esquina superior izquierda de la viewport, y sus fuentes redondean coordenadas como los sprites normales.
- **Reducción del lag**: se reutiliza **una sola** superficie de composición del editor, sin reasignar una imagen completa por cada rueda de zoom. Se usa overlay avanzado como Animated Props (con fallback). No se fuerza un redibujado completo con cada actualización periódica; las solicitudes se coalescen hasta que Maker Studio acepta el dibujo, con recuperación si no hay respuesta. El mouse no redibuja al permanecer en la misma casilla.
- **Comprobación**: pruebas simuladas de 50%, 75%, 100%, 125%, 150% y 200% verificaron coincidencia matemática entre luz directa, luz combinada y la fórmula de Animated Props. La prueba de un fragmento Ruby con el literal corregido pasó `ruby -c`; **todavía no se ha ejecutado la validación de sintaxis del archivo Ruby completo ni Maker Studio/Essentials**.

### Verificación manual

1. En el equipo del proyecto, ejecutar `ruby -c "LA BASE DE SKY/Plugins/Lighting Studio Runtime/001_LightingStudio.rb"` usando una instalación de Ruby, o iniciar el juego y confirmar que el plugin carga.
2. En Maker Studio, fijar una luz encima de un tile de referencia y cambiar zoom entre 50%, 75%, 100%, 125%, 150% y 200%. Probar con **una** luz y con **dos** luces fusionadas, moviendo la cámara.
3. Probar edición de propiedades y apuntar **ms de dibujo** y **ms de espera** en el indicador de Lighting Studio. No se han medido FPS reales en Maker Studio: optimizaciones implementadas, resultados pendientes de validar.
4. En juego, probar zoom, scrolling, transferencia de mapa, F12 y efectos meteorológicos para descartar interacciones con otros plugins.
