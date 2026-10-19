# Vermeil Movement Studio 0.4.0 — Pokémon Essentials 21.1 / Base de Sky

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
