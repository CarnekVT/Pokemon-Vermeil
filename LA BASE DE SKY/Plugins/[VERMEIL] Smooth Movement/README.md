# Vermeil Smooth Movement 0.1.0 (Essentials v21.1)

Panel: Maker Studio > **Movement Studio**. Guarda `config.ini` junto al plugin.

## Disponible

- 4 direcciones por defecto, 8 direcciones opcionales mediante Input.dir8.
- Giros inmediatos opcionales; desactivados se mantiene la pausa tradicional.
- Diagonales conservadoras: comprueban ambas rutas ortogonales y excluyen bicicleta, Surf, buceo, hielo, escaleras, rampas, espirales y movimientos forzados.
- Deslizamiento cardinal opcional si una diagonal queda bloqueada.
- Interpolación nativa de movimiento de La Base de Sky y animaciones OWs More Frames sin modificarlas.
- Ajuste de cámara sobre Fancy Camera existente. El switch 59 activa Fancy Camera; 35 mantiene suavizado original.
- Valores globales y overrides por mapa en `[map:17]`; reinicia el juego al editar.

## Limitaciones importantes

- `mode=free` y `subtile_divisions` **están reservados**. Elegirlos no activa aún desplazamiento libre real: se conserva el desplazamiento lógico por tiles para proteger eventos, escaleras, encuentros y followers.
- `smooth_movement=0` está reservado: la interpolación existente de Essentials sigue activa.
- El desplazamiento diagonal utiliza las cuatro orientaciones gráficas tradicionales (sin filas diagonales nuevas).
- Las diagonales se prueban solamente en terreno normal. No sustituyen la lógica de salto, agua ni movimiento forzado.
- No hay pruebas de ejecución dentro del cliente RPG Maker/mkxp; verifica mapas y eventos antes de integrarlo a una build estable.

## Verificación manual recomendada

1. Prueba 4 direcciones en pueblo, cueva, hierba, eventos y transiciones.
2. Activa 8 direcciones y comprueba esquinas estrechas, paredes y NPCs.
3. Comprueba escalera lateral/espiral, hielo, bici, agua, seguidores y encuentros.
4. Prueba Fancy Camera con switch 59 activado y desactivado.
5. Guarda un perfil [map:ID] y vuelve al global; prueba reinicio y carga partida.
