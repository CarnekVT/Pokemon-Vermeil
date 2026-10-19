# Vermeil Movement Studio 0.5.0 — Pokémon Essentials 21.1 / Base de Sky

Un plugin real de movimiento para el personaje, editable desde Maker Studio.
Archivo de configuración: `Plugins/[VERMEIL] Smooth Movement/config.ini`.
Admite configuración global y por mapa. No necesita JSON, FileUtils ni URI.

## Tres avances funcionales

**1. Controles modernos (siempre inmediatos).** El sistema toma la pulsación ACTUAL para mover en 4 u 8 direcciones; no guarda entradas anteriores ni introduce pausas artificiales. La alternativa **Clásica** conserva íntegra la respuesta y el giro original de Pokémon Essentials para quien la prefiera. Ninguna otra opción degrada intencionadamente la respuesta de los botones.

**2. Continuous Flow (nuevo, opcional).** Cuando el jugador termina un paso y mantiene pulsada una dirección, se prepara el siguiente después de que Essentials procese `on_step_taken`, eventos de contacto, seguidores y encuentros. Se arrastra únicamente la fracción de tiempo sobrante del paso anterior para evitar el fotograma vacío. Los tiles lógicos siguen intactos y NO se fuerza un segundo `update_move` en el mismo fotograma. Solo está activo en el modo Moderno y caminando/corriendo por suelo normal; no se usa en hielo, Surf, bicicleta, escaleras, rutas forzadas o cutscenes.

**3. Look-ahead de cámara (nuevo, opcional).** La cámara puede anticipar visualmente 8, 16, 24 o 32 píxeles en la dirección ACTUAL de movimiento, con interpolación basada en el tiempo real e independiente de Turbo. No modifica movimiento, colisiones ni orientación. Respeta el sistema preexistente Fancy Camera/Carnek Project Settings, movimientos forzados de mapa y objetivos de cámara de los eventos. El valor 0 desactiva el efecto.

## Ajustes disponibles en Maker Studio

| Parámetro | Valores | Inicial |
|---|---|---|
| Direcciones | 4 / 8 | 4 |
| Control | Moderno inmediato / Clásico Essentials | Moderno |
| Continuous Flow | Activado / Desactivado | Desactivado |
| Deslizamiento diagonal ante paredes | Sí / No | No |
| Anticipación de cámara | 0 / 8 / 16 / 24 / 32 píxeles | 0 |
| Suavidad de cámara final | 0–100 (35=base de Vermeil) | 35 |
| Perfil por mapa | Sobrescritura local o Global | Global |

**No hay búfer de pulsaciones.** El antiguo `input_buffer_ms` se ignora al leer configuraciones antiguas y se descarta al guardarlas de nuevo. El campo heredado `smooth_movement` tampoco ejecuta efectos y se ha retirado del panel.

Perfiles rápidos, ambos editables y requieren pulsar **Guardar**:
- **Clásico**: 4 direcciones, control original, Flow apagado, cámara centrada.
- **Moderno**: 8 direcciones, respuesta inmediata, Flow encendido, deslizamiento diagonal y look-ahead de 16 px.

La configuración que existe actualmente en el proyecto **no se cambia automáticamente** al actualizar el plugin ni al abrir el panel.

## Compatibilidad y seguridad

- La lógica de Turbo y su continuidad entre combate/overworld **no se modifica** en esta actualización. Continuous Flow usa el `@delta_t` que ya calcula Turbo; look-ahead utiliza `System.unscaled_uptime`.
- Cada casilla termina y dispara sus eventos/encuentros mediante el motor original ANTES de encadenar el siguiente paso.
- Se cancela Flow si aparecen eventos pendientes, encuentro, menú, diálogo, intérprete, transición de mapa, movimiento especial o movimiento forzado.
- Los seguidores reciben las actualizaciones nativas del jugador, sin moverlos dos veces por fotograma.
- La cámara extra no se aplica a las cutscenes con seguimiento de eventos, sacudidas y scroll manual.
- No se implementa todavía movimiento sub-tile real; requiere una nueva lógica de colisiones y eventos, separada de esta versión.

## Plan mínimo de pruebas dentro del juego

1. Comprobar Clásico: girar parado debe comportarse exactamente como en Essentials. Probar también 4 direcciones con Flow desactivado.
2. Probar Moderno, 8 direcciones, Flow activado y una pulsación mantenida por muchas casillas: continuidad sin aceleraciones anómalas ni pasos saltados.
3. Soltar la dirección en medio de una casilla: **no debe generarse otro paso por recordar teclas antiguas**.
4. Caminar contra paredes, NPC y eventos de contacto; pisar hierba alta y entrar/salir de combate con Turbo activado.
5. Comprobar seguidor, puerta de transferencia, escalera lateral/espiral, hielo, bicicleta, Surf, corte de movimiento y cambio de mapa.
6. Con Fancy Camera (switch 59) tanto ON como OFF, probar look-ahead 0/16/32 con suavidad 35; después cambiar a cámara final 0 y 100.

**Estado:** sintaxis/configuración verificables en código; el comportamiento real en mkxp debe validarse dentro del juego antes de declarar la versión estable.


## 0.5.0 — Diagonales, zona muerta, diagnostico

Se han incorporado cinco opciones nuevas al plugin y a Maker Studio. Todas estan apagadas o configuradas con valores equivalentes al comportamiento anterior hasta que el creador las cambie.

- `diagonal_facing=keep|horizontal|vertical`: prioridad de orientacion del sprite en diagonales. `keep` preserva la orientacion existente siempre que sea compatible.
- `wall_slide_priority=horizontal|vertical|facing`: prueba primero el eje indicado si la diagonal esta bloqueada y el deslizamiento estaba activado; se mantiene el `move_generic` cardinal nativo. Por defecto horizontal, igual que 0.4.
- `camera_deadzone=0|8|16|24|32`: zona muerta de camara, cuadrada, medida en pixeles. Valor 0 conserva la camara original; los valores positivos dejan avanzar un poco al jugador en el encuadre sin mover cada pixel del mapa.
- `camera_lead_response=60|120|200`: respuesta de look-ahead en milisegundos. 120 reproduce la velocidad visual anterior; 60 = mas rapida, 200 = mas suave. Look-ahead se activa solo durante movimiento real, no al presionar contra paredes.
- `debug_hud=0|1`: HUD de datos en modo Debug (nunca en version final), con mapa, tile del jugador, direccion, movimiento, Turbo, Flow, camara y FPS; limitado a cinco refrescos por segundo y oculto al entrar en batalla o menus.

Se protege tambien la camara de eventos que usan solo un eje (X o Y). **Ninguna opcion agrega esperas, input buffer o retencion de botones.** Clasico sigue disponible y no cambia.

### Lista de pruebas recomendadas

1. Comparar Clásico (4 direcciones originales) y Moderno (4/8 direcciones) caminando varias casillas y girando frente a paredes.
2. Con Moderno y 8 direcciones, probar las tres preferencias de facing y slide en esquinas, NPCs y eventos de contacto.
3. Con Fancy Camera (switch 59) ON/OFF, comparar Dead Zone 0 vs 8/32, Lookahead 0/16 y Response 60/120/200.
4. Probar seguimiento de camara de eventos, scroll, bordes y transferencias de mapa.
5. Activar HUD solo en Debug y comprobar salida de combate con Turbo. En juego publicado no debe aparecer.
6. Cambiar valores Global/map:ID en Maker Studio y comprobar que guardan y cargan correctamente.

### Siguiente fase mayor

Movimiento sub-tile autentico requiere reescribir colisiones, disparadores, followers y escaleras por separado; no debe activarse como una preferencia falsa en el panel. Despues, spritesheets opcionales de ocho orientaciones y perfiles especificos por terreno. Estas funcionalidades **no forman parte de 0.5.0**.

