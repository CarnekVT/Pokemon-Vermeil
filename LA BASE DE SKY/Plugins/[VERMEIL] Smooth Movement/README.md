# Vermeil Smooth Movement 0.3.0 (Pokémon Essentials 21.1)

Plugin Ruby + panel **Movement Studio** para Maker Studio, con opciones globales y por mapa. Editor y juego usan `Plugins/[VERMEIL] Smooth Movement/config.ini` sin depender de JSON ni FileUtils. Los cambios de configuracion se detectan durante la partida (hasta dos comprobaciones por segundo).

## Opciones funcionales

- **4 u 8 direcciones.** Cuatro por defecto; diagonales opcionales para terreno normal. Las diagonales comprueban ambas rutas ortogonales y mantienen sprites tradicionales de cuatro filas.
- **Giro inmediato / giro clasico.** En inmediato, si el jugador esta quieto y presiona otra direccion, gira e inicia el movimiento en ese mismo update. En clasico se utiliza literalmente `Game_Player#update_command_new` original de Essentials, incluido su retardo inicial de 75 ms. **Mientras ya camina, ambos modos funcionan casi igual por la naturaleza del grid original**; esto no es movimiento libre.
- **Deslizamiento en diagonales.** Si la diagonal esta bloqueada, opcion para intentar uno de los ejes cardinales.
- **Camara 0-100.** El valor 35 respeta el movimiento de camara previo del proyecto. Valores menores siguen antes y valores mayores siguen con mas rezago. Se aplica al resultado de la camara existente, tambien cuando Fancy Camera (switch 59) esta desactivada. La implementacion preserva scroll de mapa y camaras de eventos/cutscenes.

## Correccion de suavidad

Se quito la interpolacion `smoothstep` por tile: frenaba el sprite al final de *cada* casilla y hacia caminar seguido mas entrecortado. El jugador vuelve a la interpolacion lineal nativa de Essentials. El control `smooth_movement` en INI queda como dato heredado **sin efecto**, y se ha retirado del panel. Se ha eliminado tambien el intento de arrancar un segundo paso fuera del ciclo de actualizacion original, por riesgo de desincronizar eventos, encuentros o followers.

El movimiento verdaderamente fluido entre casillas y el modo sub-tile (1/4, 1/8) requieren una implementacion especifica con colisiones y eventos; **todavia no estan disponibles**. No se muestran como funciones activas en Movement Studio.

## Pruebas manuales

1. Actualiza esta rama, cierra el juego y abrelo en modo Debug para que compile el plugin 0.2.2.
2. En Maker Studio selecciona **Global**, cambia a giro clasico, guarda y verifica su confirmacion de lectura de `config.ini`. Compara la pausa al girar **desde parado** con el giro inmediato.
3. Camina varias casillas de corrido: comprueba que desaparecieron los frenazos del viejo easing.
4. En un mapa amplio, prueba camara **0, 35 y 100** con switch 59 apagado y encendido. Evita cutscenes para esta prueba.
5. Prueba eventos de contacto, encuentros, followers, escaleras, hielo, bicicleta, Surf y transiciones de mapa. No activar diagonales en maniobras especiales.

**Nota:** Los archivos se han revisado en GitHub, pero la ejecucion dentro de mkxp/RPG Maker requiere pruebas locales.

## Hotfix 0.2.3 - Turbo y transiciones de combate

- En `Data/Scripts/058_Utilities/010_Turbo.rb` se reajusta el offset de `System.uptime` al pasar de `SPEED_STAGES` (overworld) a `SPEED_BATTLE_STAGES` (batalla), y viceversa. Evita saltos masivos hacia adelante/atras del reloj virtual cuando el multiplicador cambia sin llamar a `Turbo.set_speed`.
- `Turbo.set_speed` actualiza tambien el multiplicador de referencia para evitar una doble correccion de tiempo.
- Movement Studio consulta cambios de `config.ini` usando `System.unscaled_uptime`, independientemente de la velocidad del Turbo.
- El parche no reinicia el Turbo al acabar una batalla si se eligio el modo `Siempre`: conserva la velocidad escogida por el jugador. En modo `Solo combates`, los handlers originales siguen restaurando la velocidad normal.

Prueba: inicia Turbo a x2 en el mapa, entra en combate (etapa equivalente x3), termina el combate y verifica que el movimiento de jugador/NPC, el scroll y el cambio de velocidad no saltan ni se congelan. Repite en modo `Solo combates` y con Turbo desactivado. Los cambios se han validado mediante una simulacion aislada del reloj; falta ejecutarlos en mkxp.

## Versión 0.3.0 - Primera mejora de respuesta sin alterar el grid

Se incorpora el **buffer de giro opcional**: `input_buffer_ms=0|60|100|150`. Con `instant_turn=1`, si se pulsa una dirección durante los ultimos milisegundos de un paso y se suelta antes de terminar, se recordará durante el intervalo elegido para ejecutarla en la siguiente oportunidad permitida. La entrada todavía pulsada siempre tiene prioridad frente al buffer. Cada intención se consume una sola vez, y caduca segun el reloj **real** (`System.unscaled_uptime`), no el tiempo acelerado por Turbo.

La captura se omite en condiciones delicadas: combates, intérprete activo, mensajes, movimiento forzado, saltos, escaleras, hielo, cascadas, movimiento `through` y colisiones especiales. Antes de consumirla se comprueba si hay eventos pendientes o encuentros. No se adelantan los eventos ni se realiza un update extra del jugador.

El valor predeterminado es **0** (sin buffer), para que las partidas existentes conserven el comportamiento validado. Aunque la opción no exista en un `config.ini` anterior, se interpreta como 0. Movement Studio agrega cuatro opciones y dos presets editables:

- **Clásico:** 4 direcciones, giro original, buffer 0, deslizamiento diagonal apagado y cámara 35.
- **Ágil:** 8 direcciones, giro inmediato, buffer 100 ms, deslizamiento diagonal activado y cámara 35.

Los perfiles solo alteran los controles del panel. **Debes pulsar Guardar** para aplicar sus valores; no se cambia automáticamente la configuración existente del proyecto.

### Prueba de regresión 0.3.0

1. Con buffer en 0, verifica que nada cambia respecto a 0.2.3.
2. Con giro inmediato y buffer 100, pulsa brevemente otra dirección justo antes del final de una casilla, y suéltala. El siguiente paso debería recoger esa intención.
3. Repite con el personaje mirando hacia una pared: no debe atravesarla ni perder la colisión.
4. Repite en hierba alta junto a un NPC o evento de contacto, y prueba un combate y retorno con Turbo activado.
5. Prueba hielo, bici, Surf, escalera, movimiento forzado y transiciones. En estos casos el buffer no debe reemplazar el movimiento original.
6. Selecciona un perfil por mapa, guarda y verifica que el perfil global no cambia.

Pendiente de implementación: movimiento sub-tile con colisiones continuas, actualización segura de eventos/followers y animaciones de 8 direcciones opcionales. No ofrecer estas funciones como activas antes de desarrollarlas y validarlas.
