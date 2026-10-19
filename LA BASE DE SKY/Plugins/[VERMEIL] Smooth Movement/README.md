# Vermeil Smooth Movement 0.1.2 (Essentials v21.1)

Panel: Maker Studio > **Movement Studio**. Guarda `config.ini` junto al plugin.

## Disponible

- 4 direcciones por defecto, 8 direcciones opcionales mediante Input.dir8.
- Giros inmediatos opcionales; desactivados se mantiene la pausa tradicional.
- Diagonales conservadoras: comprueban ambas rutas ortogonales y excluyen bicicleta, Surf, buceo, hielo, escaleras, rampas, espirales y movimientos forzados.
- Deslizamiento cardinal opcional si una diagonal queda bloqueada.
- Interpolación nativa de movimiento de La Base de Sky y animaciones OWs More Frames sin modificarlas.
- Ajuste de cámara sobre Fancy Camera existente. El switch 59 activa Fancy Camera; 35 mantiene suavizado original.
- Valores globales y overrides por mapa en `[map:17]`; se recarga mientras se ejecuta el juego (comprobación del archivo cada 0.5 s).

## Limitaciones importantes

- `mode=free` y `subtile_divisions` **están reservados**. Elegirlos no activa aún desplazamiento libre real: se conserva el desplazamiento lógico por tiles para proteger eventos, escaleras, encuentros y followers.
- `smooth_movement=1` activa easing visual; `0` vuelve a la interpolación lineal de Essentials.
- El desplazamiento diagonal utiliza las cuatro orientaciones gráficas tradicionales (sin filas diagonales nuevas).
- Las diagonales se prueban solamente en terreno normal. No sustituyen la lógica de salto, agua ni movimiento forzado.
- No hay pruebas de ejecución dentro del cliente RPG Maker/mkxp; verifica mapas y eventos antes de integrarlo a una build estable.

## Verificación manual recomendada

1. Prueba 4 direcciones en pueblo, cueva, hierba, eventos y transiciones.
2. Activa 8 direcciones y comprueba esquinas estrechas, paredes y NPCs.
3. Comprueba escalera lateral/espiral, hielo, bici, agua, seguidores y encuentros.
4. Prueba Fancy Camera con switch 59 activado y desactivado.
5. Guarda un perfil [map:ID] y vuelve al global; prueba reinicio y carga partida.

## Importante al actualizar

Ejecuta el juego en modo debug para forzar la recompilación del plugin si se encuentra el archivo `Data/PluginScripts.rxdata` anterior. La versión 0.1.1 modifica meta.txt para detectar actualización. El editor escribe en el proyecto abierto, no en otro directorio del juego.

### Hotfix 0.1.2

Se soluciono el NoMethodError `undefined method [] for Time` al leer `config.ini`: la lectura de secciones devuelve explicitamente un Hash, no la fecha de modificacion del archivo. El metodo `option` consulta una sola instantanea de configuracion. Reinicia la ejecucion de Game.exe para recompilar y recargar el plugin.
