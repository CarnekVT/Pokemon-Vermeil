# Vermeil Smooth Movement 0.2.2 (Pokémon Essentials 21.1)

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
