module Settings
  # Si se recalcula el orden de turno después de que un Pokémon Mega Evolucione.
  RECALCULATE_TURN_ORDER_AFTER_MEGA_EVOLUTION = (MECHANICS_GENERATION >= 7)
  # Si se recalcular el orden de turno después de que cambie la estadística de
  # Velocidad de un Pokémon.
  RECALCULATE_TURN_ORDER_AFTER_SPEED_CHANGES  = (MECHANICS_GENERATION >= 8)
  # Si es true, cualquier Pokémon (propio o extranjero) puede desobedecer los
  # comandos del jugador si el Pokémon tiene un nivel demasiado alto en
  # comparación con las Medallas de Gimnasio obtenidas.
  ANY_HIGH_LEVEL_POKEMON_CAN_DISOBEY          = false
  # Si es true, los Pokémon extranjeros pueden desobedecer los comandos del
  # jugador si el Pokémon tiene un nivel demasiado alto en comparación con
  # las Medallas de Gimnasio obtenidas.
  FOREIGN_HIGH_LEVEL_POKEMON_CAN_DISOBEY      = true
  # Determina si la categoría física/especial de un movimiento depende del
  # movimiento mismo (true) o de su tipo (false).
  MOVE_CATEGORY_PER_MOVE                      = (MECHANICS_GENERATION >= 4)
  # Determina si los golpes críticos hacen 1.5x de daño y tienen 4 etapas
  # (true) o hacen 2x de daño y tienen 5 etapas como en la Gen 5 (false).
  # También determina si la tasa de golpe crítico puede ser copiada por
  # Transform/Psych Up.
  NEW_CRITICAL_HIT_RATE_MECHANICS             = (MECHANICS_GENERATION >= 6)

  # El fondo se mueve a los lados al inicio de la batalla, junto con las bases laterales y el/los entrenador(es)/Pokémon.
  # Si esto es true, el fondo no se moverá (las bases/entrenadores/Pokémon sí lo harán).
  DISABLE_SLIDING_BACKGROUND = false

  # Los sprites de entrenadores, Pokémon y sus sombras se mueven a los lados al inicio de la batalla.
  # Si esto es true, estos sprites no se moverán al iniciar el combate.
  DISABLE_SLIDING_SPRITES = false

  # Las bases de combate se mueven a los lados al inicio de la batalla.
  # Si esto es true, las bases no se deslizarán al entrar al combate.
  DISABLE_SLIDING_BASES = false

  # Mostrar las bases de batalla (true) o no (false). Ten en cuenta que esto no afecta a los fondos de batalla, solo a las bases.
  SHOW_BATTLE_BASES = true

  #=============================================================================

  # Determina si un clima o terreno por defecto puede (false) o no puede (true)
  # ser reemplazado por una habilidad o movimiento que induzca otro tipo de clima.
  # Esto no se aplica a los climas primigenios (sol intenso, lluvia fuerte, vientos
  # fuertes), que siempre pueden reemplazar el clima por defecto.
  DEFAULT_WEATHER_AND_TERRAIN_CANNOT_BE_REPLACED = (MECHANICS_GENERATION >= 9)

  # Determina si varios efectos se aplican en relación con el tipo de un Pokémon:
  #   * Inmunidad de los Pokémon tipo Eléctrico a la parálisis
  #   * Inmunidad de los Pokémon tipo Fantasma a quedar atrapados
  #   * Inmunidad de los Pokémon tipo Planta a movimientos en polvo y Espora
  #   * Los Pokémon de tipo Veneno no pueden fallar al usar Tóxico
  MORE_TYPE_EFFECTS                   = (MECHANICS_GENERATION >= 6)
  # Determina si el clima causado por una habilidad dura 5 rondas (true) o para
  # siempre (false).
  FIXED_DURATION_WEATHER_FROM_ABILITY = (MECHANICS_GENERATION >= 6)

  # Determina si los objetos robados a un Pokémon salvaje por un Pokémon del jugador usando
  # Covet/Thief van directamente a la Mochila del jugador (true) o terminan siendo llevados por
  # el Pokémon que usó Covet/Thief (false).
  STOLEN_HELD_ITEMS_GO_INTO_BAG       = (MECHANICS_GENERATION >= 9)
  # Determina si los objetos X (Ataque X, etc.) aumentan su estadística en 2 etapas
  # (true) o en 1 (false).
  X_STAT_ITEMS_RAISE_BY_TWO_STAGES    = (MECHANICS_GENERATION >= 7)
  # Determina si algunas Poké Balls tienen multiplicadores de tasa de captura
  # desde la Gen 7 (true) o desde generaciones anteriores (false).
  NEW_POKE_BALL_CATCH_RATES           = (MECHANICS_GENERATION >= 7)
  # Determina si Rocío Bondad potencia los movimientos de tipo Psíquico y
  # Dragón en un 20% (true) o aumenta el Ataque Especial y la Defensa Especial
  # del portador en un 50% (false).
  SOUL_DEW_POWERS_UP_TYPES            = (MECHANICS_GENERATION >= 7)

  # Determina si la habilidad Fuerte Afecto de Greninja hace que cambie a Ash-Greninja
  # (false) o aumenta su Atk/SpAtk/Spd (true) cuando derrota a un objetivo.
  # De cualquier manera, solo sucede una vez por batalla.
  GRENINJA_BATTLE_BOND_RAISES_STATS     = (MECHANICS_GENERATION >= 9)

  #=============================================================================

  # Si es true, los Pokémon con alta felicidad ganarán más Exp en las batallas,
  # tendrán la posibilidad de evitar/curar efectos negativos por sí mismos,
  # resistirán el desmayo, etc.
  AFFECTION_EFFECTS        = false
  # Si AFFECTION_EFFECTS es true, determina si la felicidad de un Pokémon
  # está limitada a 179 y solo puede aumentarse más con bayas que aumenten
  # la amistad. Relacionado con AFFECTION_EFFECTS por defecto porque los efectos
  # de afecto solo comienzan a aplicarse por encima de una felicidad de 179.
  # También reduce el umbral de evolución por felicidad a 160.
  APPLY_HAPPINESS_SOFT_CAP = AFFECTION_EFFECTS

  # Cambia que el umbral de evolución por felicidad a 160.
  APPLY_HAPPINESS_SOFT_CAP_EVOS = true

  #=============================================================================

  # El número mínimo de medallas requeridas para aumentar cada estadística de
  # los Pokémon del jugador en 1.1x, solo en batalla.
  NUM_BADGES_BOOST_ATTACK  = MECHANICS_GENERATION >= 4 ? 999 : 1
  NUM_BADGES_BOOST_DEFENSE = MECHANICS_GENERATION >= 4 ? 999 : 5
  NUM_BADGES_BOOST_SPATK   = MECHANICS_GENERATION >= 4 ? 999 : 7
  NUM_BADGES_BOOST_SPDEF   = MECHANICS_GENERATION >= 4 ? 999 : 7
  NUM_BADGES_BOOST_SPEED   = MECHANICS_GENERATION >= 4 ? 999 : 3

  #=============================================================================

  # El switch del juego que, cuando está activado, evita que todos los Pokémon
  # en batalla realicen una Mega Evolución incluso si de otra manera pudieran.
  NO_MEGA_EVOLUTION = 34

  #=============================================================================

  # Determina si la exp obtenida al vencer a un Pokémon debe escalarse según el
  # nivel del receptor.
  SCALED_EXP_FORMULA                   = MECHANICS_GENERATION == 5 || MECHANICS_GENERATION >= 7
  # Si es true, la exp. obtenida al vencer a un Pokémon se divide equitativamente
  # entre cada participante (true), o cada participante gana esa cantidad de exp.
  # (false). Esto también se aplica a la exp. obtenida a través del Rep. Exp.
  # (versión de objeto equipable) que se distribuye a todos los que lo llevan equipado.
  SPLIT_EXP_BETWEEN_GAINERS            = (MECHANICS_GENERATION <= 5)
  # Si es true, la Exp obtenida al vencer a un Pokémon se multiplica por 1.5 si
  # ese Pokémon es propiedad de otro entrenador.
  MORE_EXP_FROM_TRAINER_POKEMON        = (MECHANICS_GENERATION <= 6)
  # Determina si un Pokémon que lleva un objeto Power gana 8 (true) o 4 (false)
  # EV en la estadística relevante.
  MORE_EVS_FROM_POWER_ITEMS            = (MECHANICS_GENERATION >= 7)
  # Si es true, se aplica el mecanismo de captura crítica. Ten en cuenta que su
  # cálculo se basa en un total de 600+ especies (es decir, tantas especies deben
  # ser capturadas para proporcionar la mayor probabilidad de captura crítica de
  # 2.5x), y puede haber menos especies en tu juego.
  ENABLE_CRITICAL_CAPTURES             = (MECHANICS_GENERATION >= 5)
  # Si es true, se aplica un bono a la tasa de captura para Pokémon debajo de nivel 13.
  CATCH_RATE_BONUS_FOR_LOW_LEVEL       = (MECHANICS_GENERATION >= 8)
  # Si el jugador no tiene al menos este número de Medallas de Gimnasio, la
  # probabilidad de capturar cualquier Pokémon salvaje cuyo nivel sea mayor que
  # el del Pokémon del jugador se dividirá por 10. 0 significa que esta penalización
  # nunca se aplica. Ten en cuenta que esto no debe usarse con la configuración
  # que aparece a continuación.
  NUM_BADGES_TO_NOT_MAKE_HIGHER_LEVEL_CAPTURES_HARDER = MECHANICS_GENERATION == 8 ? 8 : 0
  # Si es true, los Pokémon salvajes que desobedecerían al jugador por su nivel
  # (excepto si están dentro de 5 niveles del nivel máximo de obediencia) serán
  # más difíciles de capturar. Ten en cuenta que esto no debe usarse con la
  # configuración directamente anterior.
  CATCH_RATE_PENALTY_IF_POKEMON_WILL_NOT_OBEY         = (MECHANICS_GENERATION >= 9)
  # Si es true, los Pokémon ganan Exp por capturar a un Pokémon.
  GAIN_EXP_FOR_CAPTURE                 = (MECHANICS_GENERATION >= 6)
  # Si es true, se le pregunta al jugador qué hacer con un Pokémon recién capturado
  # si su equipo está lleno. Si es true, el jugador puede cambiar si se le pregunta
  # esto en la pantalla de Opciones.
  NEW_CAPTURE_CAN_REPLACE_PARTY_MEMBER = (MECHANICS_GENERATION >= 7)

  #=============================================================================
  # Si es true el comando de huir de un combate contra entrenadores permite al jugador terminar la
  # batalla como su derrota (true) o no hace nada (false).
  CAN_FORFEIT_TRAINER_BATTLES         = (MECHANICS_GENERATION >= 9)

  # El switch de juego que, cuando está activado, evita que el jugador pierda
  # dinero si pierde un combate (todavía puede ganar dinero de entrenadores por ganar).
  NO_MONEY_LOSS                       = 33
  # Si es true, los Pokémon del equipo comprueban si pueden evolucionar después
  # de todas las batallas, independientemente del resultado (true), o solo después
  # de las batallas que el jugador ganó (false).
  CHECK_EVOLUTION_AFTER_ALL_BATTLES   = (MECHANICS_GENERATION >= 6)
  # Si es true, los Pokémon debilitados pueden intentar evolucionar después
  # de un combate.
  CHECK_EVOLUTION_FOR_FAINTED_POKEMON = true

  #=============================================================================

  # Si es true, los Pokémon salvajes marcados como "Legendario", "Mítico" o
  # "Ultraente" (según se define en pokemon.txt) tienen una IA más inteligente.
  # Su nivel de habilidad se establece en 32, que es un nivel de habilidad medio.
  SMARTER_WILD_LEGENDARY_POKEMON = true

  # El mensaje del repartir experiencia será "¡Tus otros Pokémon también ganaron puntos de experiencia!"
  # En lugar de mostrar cuanta experiencia ha ganado cada Pokémon que tenga el Repartir Experiencia activo.
  GROUP_EXP_SHARE_MESSAGE = true


  # Independientemente de si el poder, tipo, categoría, etc. de un movimiento se muestra en combate, la pantalla de resumen
  # y la pantalla de Recordatorio de Movimientos aparecerán con sus valores calculados
  # (verdadero) o con los valores del archivo PBS moves.txt (falso). Por ejemplo, si
  # esto es verdadero, el tipo mostrado de Sentencia dependerá de la Tabla que sostenga
  # el Pokémon que lo tenga.
  SHOW_MODIFIED_MOVE_PROPERTIES = true

  # Agrega el porcentaje de vida restante del Pokémon enemigo debajo de la barra de vida.
  SHOW_ENEMY_HP_PERCENTAGE = true

  # Modo de color de la barra de HP.
  #   :gradient     - Degradado suave entre colores adyacentes (usa los umbrales de abajo)
  #   :classic      - 3 colores fijos (verde >50%, amarillo 50-25%, rojo <25%)
  #   :four_colors  - 4 colores fijos (usa los umbrales de abajo)
  HP_BAR_COLOR_MODE = :gradient

  # Umbrales para los modos :four_colors y :gradient (valores de 0.0 a 1.0).
  # Cada umbral indica el porcentaje de HP en el que cambia al siguiente color.
  #   YELLOW_THRESHOLD: verde -> amarillo
  #   ORANGE_THRESHOLD: amarillo -> naranja
  #   RED_THRESHOLD:    naranja -> rojo
  HP_BAR_GREEN_THRESHOLD  = 0.55
  HP_BAR_YELLOW_THRESHOLD = 0.40
  HP_BAR_ORANGE_THRESHOLD = 0.25
  HP_BAR_RED_THRESHOLD    = 0.10

  # Muestra los peligros de entrada (púas, trampa rocas, tela de araña) en la pantalla de batalla.
  SHOW_HAZARDS_IN_BATTLE = false

  # Si es true, al finalizar una batalla se actualizará el orden del equipo del jugador
  # para que el primer Pokémon del equipo sea el que terminó la batalla (si no está debilitado).
  UPDATE_PARTY_LEAD_BATTLE_END = false

  # Activa o desactiva el cambio de tono (Hue) para los Pokémon Super Shiny.
  SUPER_SHINY_HUE_SHIFT = false
  
  # Valores de tono (Hue) disponibles para la asignación aleatoria.
  # NOTA: Puedes usar SuperShinyHue = VALOR en los PBS de pokemon para asignar un valor
  # especifico. Pede ser un valor individual (SuperShinyHue = 20) o multiples
  # (SuperShinyHue = 20, 120, 85). Esto le dice al sitema que ignore esto y use
  # los que asignes.
  SUPER_SHINY_HUES = [75, 90, 105, 120, 135, 150, 165, 180]
  
  # Si es true, todos los Pokémon de la misma especie tendrán el mismo tono.
  # Si es false, el tono será único por cada Pokémon.
  SUPER_SHINY_HUE_BY_SPECIES = true



  #=============================================================================
  # ** CONFIGURACIÓN BARRAS DE ENTRENADORES **
  #=============================================================================
  
  # FORMA DE LAS BARRAS
  #    :SLANTED    - Triángulos inclinados en las esquinas
  #    :SQUARE     - Marco que abarca toda la pantalla
  #    :HORIZONTAL - Barras rectangulares horizontales clásicas
  BAR_SHAPE = :HORIZONTAL

  # TAMAÑO/GROSOR DEL MARCO EN MODO :SQUARE
  #    Píxeles de grosor máximo que abarcará el marco alrededor de la pantalla
  #    (ej: 36 o 40 para un marco fino y elegante, 64 o 80 para uno más ancho).
  SQUARE_FRAME_THICKNESS = 80

  # DIRECCIÓN DINÁMICA (EXPERIMENTAL)
  #    true  : Las barras aparecen y se orientan hacia donde mira el entrenador
  #            y según la orientación/posición relativa con respecto al jugador.
  #    false : Orientación fija clásica (siempre Superior e Inferior).
  DYNAMIC_DIRECTION = false

  # COLOR RGB Y TRANSPARENCIA PERSONALIZABLE
  #    true  : Activa el uso del color CUSTOM_RGB y la transparencia CUSTOM_ALPHA.
  #    false : Utiliza el degradado oscuro cinemático por defecto.
  CUSTOM_RGB_ENABLED = false
  
  # Color RGB [Rojo, Verde, Azul] (Valores entre 0 y 255)
  # Ejemplos: [10, 12, 16] (Negro mate), [210, 35, 35] (Rojo), [20, 50, 150] (Azul)
  CUSTOM_RGB   = [10, 12, 16]
  
  # Transparencia / Opacidad máxima (0 a 255, donde 255 es sólido y 0 invisible)
  CUSTOM_ALPHA = 240

  # ALTURA MÁXIMA DE LAS BARRAS POR MODO (píxeles)
  #    Define qué tan altas/gruesas se extienden las barras en cada modo cuando
  #    la cercanía está al máximo (jugador pegado al entrenador).
  #      :HORIZONTAL -> HORIZONTAL_BAR_HEIGHT
  #      :SLANTED    -> SLANTED_BAR_HEIGHT
  #    BAR_HEIGHT se mantiene como "alias" de HORIZONTAL_BAR_HEIGHT por
  #    retrocompatibilidad con scripts antiguos.
  HORIZONTAL_BAR_HEIGHT = Graphics.height / 5
  SLANTED_BAR_HEIGHT    = Graphics.height / 3
  BAR_HEIGHT            = HORIZONTAL_BAR_HEIGHT   # alias retrocompat

  # RAZÓN DE EXPANSIÓN INICIAL
  #    Fracción (0..1) de la altura/grosor máximo que muestran las barras justo
  #    al "brotar" (closeness ~ BAR_SOFT_RANGE). Valores más bajos producen un
  #    crecimiento más dramático desde casi 0 hasta el máximo; valores cercanos
  #    a 1 hacen que las barras aparezcan casi a su tamaño final de una vez.
  BAR_MIN_EXPAND_RATIO    = 0.40   # barras :HORIZONTAL / :SLANTED
  SQUARE_MIN_EXPAND_RATIO = 0.30   # grosor del marco :SQUARE

  # TRANSICIONES
  #    Rate de interpolación (lerp) calibrado a 60 FPS de referencia.
  #    El sistema convierte internamente a delta time, así que la velocidad
  #    de la animación es idéntica a 30, 60, 120+ FPS.
  #      0.14 ≈ ~0.8 s para recorrer 0.0 -> 1.0
  #      0.20 ≈ ~0.5 s
  BAR_FADE_RATE  = 0.14   # cambio de opacidad/grosor (closeness)
  BAR_SLIDE_RATE = 0.16   # deslizamiento al entrar las barras
  #    Fracción (0..1) del closeness reservada como "zona suave" de fade-in/out.
  #    Por debajo de este umbral la opacidad crece linealmente desde 0; por
  #    encima se intensifica hasta el máximo. Valores más altos hacen el
  #    fade-in/out más prolongado.
  BAR_SOFT_RANGE = 0.20

  # PARÁMETROS DEL DEGRADADO VERTICAL
  #    BAR_FADE_CURVE controla cómo cae la opacidad de borde externo a interno
  #    en cada barra. Valores >1 hacen la caída más abrupta cerca del borde
  #    interno (degradado más "duro"); valores <1 la hacen más uniforme.
  BAR_FADE_CURVE = 1.3
  #    Fracción (0..1) de la opacidad máxima que la barra muestra en su
  #    intensidad base (closeness = 1.0). El resto se "llena" conforme la
  #    cercanía aumenta. Valores más altos = barras siempre visibles y densas.
  BAR_ALPHA_MIN_RATIO = 0.45

  BAR_OPACITY  = 255 / 8
  SELF_SWITCH  = "A"
  BAR_GRAPHIC  = ""
end

