#==============================================================================#
# AJUSTES DE LOS PLUGINS                                                      #
#                                                                              #
# Aquí encontrarás toda la configuración de los distintos Plugins que          #
# incorpora esta base.                                                         #
#==============================================================================#

#===============================================================================
# MinimalGrinding - Toggle para ignorar IVs/EVs en tiempo de ejecución
# Usa MinimalGrinding.on / MinimalGrinding.off / MinimalGrinding.toggle
#===============================================================================
module MinimalGrinding
  module_function

  def on?
    $PokemonGlobal&.minimal_grinding ? true : false
  end

  def on
    $PokemonGlobal.minimal_grinding = true
  end

  def off
    $PokemonGlobal.minimal_grinding = false
  end

  def toggle
    $PokemonGlobal.minimal_grinding = !$PokemonGlobal.minimal_grinding
  end
end

module Settings

  # Activa es to si quieres que los objetos consumibles
  # como gemas, bayas, banda focus, etc. sean restaurados luego del combate
  RESTORE_HELD_ITEMS_AFTER_BATTLE = true

  # Lista de objetos consumibles que NO serán recuperados luego del combate
  # el formato es [:IDOBJETO] por ejemplo [:SITRUSBERRY]
  RESTORE_HELD_ITEMS_BLACKLIST = []

  # Esta es la lista de bayas por si las quieres añadir en los corchetes.
  #
  #   :CHERIBERRY, :CHESTOBERRY, :PECHABERRY, :RAWSTBERRY,
  #   :ASPEARBERRY, :LEPPABERRY, :ORANBERRY, :PERSIMBERRY, :LUMBERRY, :SITRUSBERRY,
  #   :FIGYBERRY, :WIKIBERRY, :MAGOBERRY, :AGUAVBERRY, :IAPAPABERRY, :RAZZBERRY,
  #   :BLUKBERRY, :NANABBERRY, :WEPEARBERRY, :PINAPBERRY, :POMEGBERRY, :KELPSYBERRY,
  #   :QUALOTBERRY, :HONDEWBERRY, :GREPABERRY, :TAMATOBERRY, :CORNNBERRY, :MAGOSTBERRY,
  #   :RABUTABERRY, :NOMELBERRY, :SPELONBERRY, :PAMTREBERRY, :WATMELBERRY, :DURINBERRY,
  #   :BELUEBERRY, :OCCABERRY, :PASSHOBERRY, :WACANBERRY, :RINDOBERRY, :YACHEBERRY,
  #   :CHOPLEBERRY, :KEBIABERRY, :SHUCABERRY, :COBABERRY, :PAYAPABERRY, :TANGABERRY,
  #   :CHARTIBERRY, :KASIBBERRY, :HABANBERRY, :COLBURBERRY, :BABIRIBERRY, :ROSELIBERRY,
  #   :CHILANBERRY, :LIECHIBERRY, :GANLONBERRY, :SALACBERRY, :PETAYABERRY, :APICOTBERRY,
  #   :LANSATBERRY, :STARFBERRY, :ENIGMABERRY, :MICLEBERRY, :CUSTAPBERRY, :JABOCABERRY,
  #   :ROWAPBERRY, :KEEBERRY, :MARANGABERRY

  ################################################################################
  #  CONFIGURACIÓN DEL DELUXE BATTLE SCRIPT
  ################################################################################
  # Almacena la ruta para los gráficos utilizados por este plugin.
  DELUXE_GRAPHICS_PATH = File.join('Graphics', 'Plugins', 'Deluxe Battle Kit/')

  # Acorta los nombres largos de los movimientos en el menú de combate para que se
  # ajusten a la interfaz de batalla predeterminada.
  SHORTEN_MOVES = true

  # Activa o desactiva la animación de Mega Evolución utilizada por este plugin.
  SHOW_MEGA_ANIM = true

  # Activa o desactiva la animación de Reversión Primigenia utilizada por este plugin.
  SHOW_PRIMAL_ANIM = true

  # Activa el nuevo repartir experiencia que se puede activar para cada pokémon del equipo.
  USE_NEW_EXP_SHARE = true

  ## HABILITAR EL REAPATIR EXPERIENCIA desde el inicio de la partida, sin necesidad de dar ningun objeto
  ## o de activar el $player.has_exp_all, si desean activar el expshare para todos los pokémon, con alguno
  ## de los 2 metodos mencionados anteriormente, deben dejar esta variable en false.
  EXPSHARE_ENABLED = true


  ################################################################################
  #  CONFIGURACIÓN DE POKÉMON
  ################################################################################
  # Elige si quieres que las formas de la línea evolutiva de Spewpa dependan de el ID del jugador.
  LINEA_DE_SPEWPA_POR_ID = true

  # Elige si quieres que las formas regionales dependan de la región en la que esté el jugador.
  REGIONAL_FORMS_DEPEND_ON_MAP_REGION = true


  ################################################################################
  #  CONFIGURACIÓN DEL ENHANCED BATTLE UI
  ################################################################################
  # Almacena la ruta para los gráficos utilizados por este plugin.
  BATTLE_UI_GRAPHICS_PATH = File.join('Graphics', 'Plugins', 'Enhanced Battle UI/')

  #-----------------------------------------------------------------------------
  # The display style for button prompts used to open UI menus that appear when selecting commands.
  # 0 => No prompts shown
  # 1 => Always show prompt
  # 2 => Show prompt, but hide after 2 seconds.
  #-----------------------------------------------------------------------------
  UI_PROMPT_DISPLAY = 2

  # Cuando en el grafico Graphics/Plugins/Enhanced Battle UI/command_prompts.png
  # ya están incluidos los textos de los prompts (A: , S: ), poner esta constante en true.
  PROMPT_TEXT_INCLUDED_IN_GRAPHICS = true


  #-----------------------------------------------------------------------------
  # When true, Move UI background will reflect the color of the move type.
  #-----------------------------------------------------------------------------
  USE_MOVE_TYPE_BACKGROUNDS = true


  # Cuando es falso, la pantalla no mostrará la efectividad del tipo de movimientos
  # contra especies nuevas que encuentres por primera vez.
  # Cuando es verdadero, siempre se mostrará la efectividad del tipo, incluso para
  # especies nuevas.
  SHOW_TYPE_EFFECTIVENESS_FOR_NEW_SPECIES = false

  # Cuando un Pokémon es debilitado todos sus sprites se veran grisados
  # Al curarlo vuelven a su color original
  GREY_OUT_FAINTED = true

  ################################################################################
  #  POKÉDEX AVANZADA
  ################################################################################

  # Si está en true hace que en las dexes verifique tambien si has visto formas alternativas
  # esto es util si quieres hacer una dex solo de formas regionales o megas
  REGIONAL_DEXES_INCLUDE_ALTERNATE_FORMS = true

  #-----------------------------------------------------------------------------
  # Ruta de gráficos para la página de datos de la Pokédex.
  #-----------------------------------------------------------------------------
  # Almacena la ruta para los gráficos utilizados por este plugin.
  POKEDEX_DATA_PAGE_GRAPHICS_PATH = File.join('Graphics', ' UI', 'Pokedex Data Page/')

  # # Interruptor que activa la página de datos de la Pokédex.
  # Esto se ha eliminado, ya que no creo que alguien quiera desactivar la Pokédex
  # avanzada.
  # POKEDEX_DATA_PAGE_SWITCH = 60

  # Activa o desactiva la visualización de los nombres alternativos de los grupos
  # huevo.
  ALT_EGG_GROUP_NAMES = false

  # Número de pagina de la Dex Avanzada
  # Si agregan paginas nuevas a la pokédex en medio, cambiar esto
  ADVANCED_DEX_PAGE = 4

  # # Mostrar Siluetas para los Pokémon no vistos en la dex
  SHOW_SILHOUETTES_IN_DEX = false

  # Mostrar cambios de stats respecto a los juegos oficiales
  # Para esto se utiliza la PokeAPI, si no hay internet no hará nada
  SHOW_STAT_CHANGES_WITH_POKEAPI = false

  # Origen de los datos de PokeAPI (stats/abilities/types de referencia):
  # :network -> descarga y cachea en Data/data_pokeapi.json (se auto-actualiza con nuevos Pokémon)
  # :local   -> solo lee Data/data_pokeapi.json, nunca toca internet (hay que mantenerlo a mano)
  POKEAPI_DATA_SOURCE = :network



  ################################################################################
  #  TURBO
  ################################################################################
  # Habilitar o deshabilitar opciones del menú, habilitado por defecto.
  SPEED_OPTIONS = true



  ################################################################################
  #  ENHANCED POKÉMON UI
  ################################################################################
  # Ruta de gráficos
  # Almacena la ruta para los gráficos utilizados por este plugin.
  POKEMON_UI_GRAPHICS_PATH = 'Graphics/UI/Enhanced Pokemon UI/'

  # Party Ball
  # Habilita la visualización de iconos de Poké Ball que coinciden con la Poké Ball
  # de cada Pokémon en el menú del equipo.
  SHOW_PARTY_BALL = true

  # Medidor de felicidad
  # Habilita la visualización de un medidor de felicidad en la pantalla de resumen
  # del Pokémon.
  SUMMARY_HAPPINESS_METER = true

  # Hoja brillante
  # Habilita la visualización de las Hojas Brillantes recopiladas por un Pokémon
  # en las pantallas de resumen/almacenamiento.
  SUMMARY_SHINY_LEAF = false
  STORAGE_SHINY_LEAF = false

  # Datos heredados
  # Habilita la opción de abrir el menú de Datos Heredados en el resumen.
  SUMMARY_LEGACY_DATA = true

  # Valoraciones de IV
  # Habilita la visualización de valoraciones para los IV de un Pokémon en las
  # pantallas de resumen/almacenamiento.
  SUMMARY_IV_RATINGS = true
  STORAGE_IV_RATINGS = false
  IV_DISPLAY_STYLE   = 1 # 0 = Estrellas, 1 = Letras

  # Visualización mejorada de estadísticas
  # El número de interruptor utilizado para permitir al jugador acceder a la
  # visualización mejorada de estadísticas.
  DISPLAY_ENHANCED_STATS = false

  # Visualizacion de IVs y EVs
  SHOW_ADVANCED_STATS = true

  # Mostrar cuadro de descripción al obtener un objeto nuevo
  SHOW_ITEM_DESCRIPTIONS_ON_RECEIVE = true

  # Mostrar MTs y MOs en el recordador
  SHOW_MTS_MOS_IN_MOVE_RELEARNER = true

  # Mostrar indicador para movimientos no vistos en el recordador
  # Esto es para cuando un Pokémon puede aprender un movimiento que el jugador no ha visto antes
  # Ya sea porque es un movimiento que el Pokémon solo aprende por recordador
  # o porque el jugador tiene la opción de saltarse el aprendizaje por nivel.
  SHOW_INDICATOR_FOR_UNSEEN_MOVES_IN_MOVE_RELEARNER = false

  # Cerrar el recordador luego de cada ataque
  CLOSE_MOVE_RELEARNER_AFTER_TEACHING_MOVE = false

  # Usar nombres default para el jugador en lugar del nombre de usuario del sistema
  # Si esta constante está en true, se usarán los nombres de las constantes
  # MALE_PLAYER_NAME y FEMALE_PLAYER_NAME definidas más abajo.
  # En caso contrario, se usará el nombre de usuario del sistema como nombre del jugador.
  USE_DEFAULT_PLAYER_NAMES = false
  MALE_PLAYER_NAME = 'Rojo'
  FEMALE_PLAYER_NAME = 'Hoja'

  # Es el número de switch que usa la Fancy Camera. Debes encender este switch
  # para activar la cámara fancy.
  CAMERA_FANCY = 59

  # Elige si quieres que al aprender un ataque nuevo y olvidar otro salga el texto de "1, 2 y puf".
  MENSAJE_CUENTA_MOVIMIENTOS = true

  # Elige si quieres que después de hablar con un NPC, este vuelva a su dirección de origen.
  RESTORE_EVENT_DIRECTION = false
end

#===============================================================================
# Pantalla de la Mochila con Equipo
#===============================================================================
module BagScreenWiInParty
  # Si deseas que tu pantalla de la Mochila tenga un panorama desplazable (true o
  # false):
  PANORAMA = true

  # Color de fondo de la interfaz:
  # 0 para solo naranja (estilo de generaciones más recientes);
  # 1 para un color diferente según el género del jugador (estilo BW);
  # 2 para un color diferente para cada bolsillo (estilo HGSS).
  BGSTYLE = 0

  # Si deseas que aparezca un icono de Pokérus y/o de shiny, respectivamente
  # (true o false):
  PKRSICON  = true
  SHINYICON = true
end



#===============================================================================
# OPCIONES ESPECIALES DEL ALMACENAMIENTO DE POKÉMON
#===============================================================================
STORAGE_ARROW_PATH = File.join('Graphics', 'UI', 'Storage/')

# Si se pueden intercambiar rápidamente las cajas seleccionando "Intercambiar" desde
# el encabezado de la caja
CAN_SWAP_BOXES   = true

# Sie pueden seleccionar/mover varios Pokémon al mismo tiempo usando la mano verde
CAN_MULTI_SELECT = true

# Si se pueden liberar varios Pokémon presionando la tecla de acción mientras se tienen
# varios Pokémon agarrados
# Necesitas tener seleccionada la opción CAN_MULTI_SELECT
CAN_MASS_RELEASE = true

# Si se pueden "dejar" Pokémon en una caja
# Esto te permite almacenar rápidamente Pokémon en una caja haciendo clic en el
# encabezado de la caja mientras tienes un Pokémon agarrado
CAN_BOX_POUR     = true



################################################################################
#  CONFIGURACIÓN DE LOS SPRITES ANIMADOS
################################################################################
#===============================================================================
# * Constantes para sprites animados de Pokémon
# * Para cambiar la posición del sprites de espalda de Pokémon en la batalla,
#   selecciona y presiona
# * CTRL + Shift + F en la siguiente línea de código:
# * sprite.y += (metrics[MetricBattlerPlayerY][species] || 0)*2
#===============================================================================
FRONTSPRITE_SCALE = 1 # 2
BACKSPRITE_SCALE  = 1 # 3


################################################################################
# Mostrar el número de pasos restantes para la eclosión de un HUEVO en la
# pantalla de Datos.
################################################################################
MOSTRAR_PASOS_HUEVO = false


module Settings
  ################################################################################
  # MAPAS SIN REFLEJOS
  # IDs de los mapas en los que no quieres que el personaje tenga reflejo.
  # Ejemplo: MAPAS_SIN_REFLEJO = [12,157,536]
  ################################################################################
  MAPAS_SIN_REFLEJO = []

  ################################################################################
  # MAPAS SIN REFLEJOS ONDULANTES
  # IDs de los mapas en los que no quieres que el reflejo del personaje no ondule.
  # Ejemplo: MAPAS_SIN_REFLEJO_ONDULANTE = [12,157,536]
  ################################################################################
  MAPAS_SIN_REFLEJO_ONDULANTE = []

end


################################################################################
# MAPAS SIN SONIDO DE HIERBA
# IDs de los mapas en los que no quieres que el personaje ni eventos hagan sonido
# al caminar por la hierba.
# Ejemplo: MAPAS_SIN_SONIDO_HIERBA = [12,157,536]
################################################################################

MAPAS_SIN_SONIDO_HIERBA = []

# Si deseas que cuando un evento camina por la hierba la animación y su sonido no se reproduzcan
# a menos que el jugador esté cerca (dentro del rango de visión), pon esta constante en true.
MUTE_GRASS_RUSTLE_OUT_OF_SIGHT = true

# Nombres de eventos que al moverse no deben reproducir la animación ni el sonido de caminar por la hierba, incluso si el jugador está cerca.
GRASS_RUSTLE_EXCLUDED_EVENT_NAMES = ['airborne']



################################################################################
# LISTADO DE POKÉMON CON FORMAS REGIONALES
# Los Pokémon que estén en el listado de abajo son los que el cambia formas
# podrá cambiar
################################################################################
REGIONAL_SPECIES = [:RATTATA, :RATICATE, :RAICHU, :SANDSHREW, :SANDSLASH, :VULPIX, :NINETALES, :DIGLETT, :DUGTRIO,
                    :MEOWTH, :PERSIAN, :GEODUDE, :GRAVELER, :GOLEM, :PONYTA, :RAPIDASH, :SLOWPOKE, :SLOWBRO, :FARFETCHD, :GRIMER, :MUK,
                    :EXEGGUTOR, :MAROWAK, :WEEZING, :MRMIME, :ARTICUNO, :ZAPDOS, :MOLTRES, :SLOWKING, :CORSOLA,
                    :ZIGZAGOON, :LINOONE, :DARUMAKA, :DARMANITAN, :YAMASK, :STUNFISK, :LYCANROC, :GROWLITHE, :ARCANINE,
                    :VOLTORB, :ELECTRODE, :TAUROS, :TYPHLOSION, :WOOPER, :QWILFISH, :SNEASEL, :SAMUROTT,
                    :LILLIGANT, :ZORUA, :ZOROARK, :BRAVIARY, :SLIGGOO, :GOODRA, :BERGMITE, :AVALUGG, :DECIDUEYE,
                    :PIKACHU, :URSALUNA, :FLABEBE, :FLOETTE, :FLORGES, :SHELLOS, :GASTRODON, :BURMY, :WORMADAM,
                    :ORICORIO, :BASCULIN, :SQUAWKABILLY, :VIVILLON]


#######################################################################################
# LISTADO DE FORMAS DE POKÉMON NO PERMITIDAS
# Este listado es para configurar determinadas formas de Pokémon del listado de arriba
# Para que el cambia formas no las muestre
########################################################################################
FORMS_BLACKLIST = { DARMANITAN: [1, 3] }

# Este listado es para que el cambia formas permita cambiar a esa especie pero no a una forma especifica
# Por ejemplo, si quieres que el cambia formas permita cambiar a Floette pero no cambiarlo a la form Flor Eterna
CURRENT_SPECIES_BLACKLIST = [:FLOETTE_5]

# Habilitar o deshabilitar la visualización de sprites en el cambiador de formas
# Al posarse sobre una opción en el cambia formas, se mostrará el sprite del Pokémon con esa forma
SHOW_SPRITES_IN_FORM_CHANGER = true


################################################################################
# ESCALERAS LATERALES
# RECUERDA que los eventos de la escalera se deben llamar "Stairs".
# Configuraciones para las escaleras laterales
################################################################################
SMOOTH_SCROLLING = true
SPEED_REDUCTION_ON_STAIRS = 0.85
# Nombres de eventos que al iniciar su movimiento deben activar la función de escaleras laterales
STAIR_EVENT_NAMES = ['Stairs', 'Slope']
$disable_scroll_counter = 0


################################################################################
# Huellas en la Arena
################################################################################
module FootprintsSettings
  # Esta es la cantidad de opacidad que se reduce por frame. Necesita ir de 256 a 0,
  # lo que significa que establecer esto en 4 haría que cada par de pasos dure 64 frames (~1.5s)
  FADE_OUT_SPEED = 6

  # Un desplazamiento configurable X/Y para los sprites de los pasos, en caso de que no se alineen
  # bien con el gráfico del jugador.
  WALK_X_OFFSET = 0
  WALK_Y_OFFSET = 0

  # Un desplazamiento configurable X/Y para los sprites de las huellas de la bicicleta, en caso de que no se alineen
  # bien con el gráfico del jugador.
  BIKE_X_OFFSET = -8
  BIKE_Y_OFFSET = 0

  # Si es verdadero, tanto el jugador como el follower crearán huellas.
  # Si es falso, solo el follower creará huellas.
  DUPLICATE_FOOTSTEPS_WITH_FOLLOWER = false

  # Si el nombre del evento incluye alguna de estos textos, no producirá
  # huellas. Puedes añadir alguno a la lista si quieres.
  EVENTNAME_MAY_NOT_INCLUDE = ['SinHuellas', '.sinhuellas']

  # Si el nombre del archivo (gráfico) incluye alguna de estos textos, no producirá
  # huellas. Funciona además de la lista de nombres de eventos.
  FILENAME_MAY_NOT_INCLUDE = [
    # Aquí se pueden añadir más textos si es necesario
  ]
end

module DamageNumberSettings
  ACTIVE     = true
  SHOW_HEAL  = true

  # Debug
  DEBUG_LOGS = false

  # Visual General
  FONT_SIZE  = 32
  FONT_BOLD  = true

  # Si es verdadero, los números de daño mostrarán un signo delante del número.
  DAMAGE_SYMBOLS = true

  #-----------------------------------------------------------------------------
  # Configuración de Colores por Categoría (R, G, B)
  #-----------------------------------------------------------------------------
  COLORS = {
    # Daño normal
    physical: { base: Color.new(255, 168, 168),
                border: Color.new(180, 0, 0) },
    # Golpe Crítico
    critical: { base: Color.new(255, 240, 0),
                border: Color.new(220, 40, 0) },
    # Curación
    heal: { base: Color.new(80, 255, 80),
            border: Color.new(0, 100, 0) },
    # Veneno
    poison: { base: Color.new(200, 100, 255),
              border: Color.new(80, 0, 120) },
    # Quemadura
    burn: { base: Color.new(255, 140, 60),
            border: Color.new(140, 40, 0) },
    # Clima, Trampas, Retroceso
    passive: { base: Color.new(220, 220, 220),
               border: Color.new(60, 60, 60) }
  }

  # Animación
  DURATION    = 110
  FADE_START  = 1.20
  FLOAT_DIST  = 60
end

module OWShadowSettings
  # Si es verdadero, calcula el tamaño de la sombra en función de los píxeles del sprite.
  # Si es falso, utiliza el tamaño definido en FIXED_SHADOW_SIZE para todos.
  AUTOMATIC_SHADOW_GENERATION = true

  # Tamaño fijo de la sombra cuando la generación automática está desactivada.
  # Un valor entre 10 y 14 es ideal para personajes de tamaño normal.
  FIXED_SHADOW_SIZE = 14

  # Activar o desactivar el recorte de sombras cuando interactuan entre si.
  # Puede afectar el rendimiento si hay una cantidad exagerada de eventos con sombra en el mapa.
  ENABLE_SHADOW_CLIPPING = false

  # ============================================================================
  # Si es verdadero, las blackslist de nombres de eventos y nombres de gráficos distinguirán entre mayúsculas y minúsculas.
  CASE_SENSITIVE_BLACKLISTS = false

  # Si el nombre de un evento contiene una de estas palabras, no generará sombra.
  SHADOWLESS_EVENT_NAME     = [
    'door', 'FlechaSalida', 'nurse', 'Enfermera', 'Healing balls', 'Balls curativas', 'Mart', 'Tendero', 'SmashRock', 'RocaRompible', 'StrengthBoulder', 'PiedraFuerza',
    'CutTree', 'ArbolCorte', 'HeadbuttTree', 'ArbolGolpeCabeza', 'BerryPlant', 'Planta Bayas', '.shadowless', '.noshadow', '.sl', 'Entrada Mazmorra Bosque', 'Entrada Cueva', 'Relic Stone',
    'Escalera', 'Puerta', 'ExitArrow', 'NoShadow', 'noShadow'
  ]

  # Si gráfico utiliza una de estas palabras en su nombre de archivo, no generará sombra.
  SHADOWLESS_CHARACTER_NAME = ['nil']

  # Si un evento se encuentra sobre una casilla con uno de estos terrain tags, no tendrá sombra.
  # (Los nombres se pueden ver en la sección del script "Terrain Tag")
  SHADOWLESS_TERRAIN_NAME   = [
    :Grass, :DeepWater, :StillWater, :Water, :Waterfall, :WaterfallCrest,
    :Puddle
  ]

  # Hash para ajustar el radio de sombra para archivos de personajes específicos.
  # KEY: Parte del nombre del archivo (p. ej., "PIKACHU").
  # VALUE: [RADIO, X, Y]
  CHARACTER_SHADOW_FIX = {
    'PIKACHU' => [-2, 0, 0],
    'SNORLAX' => [8, 0, 0]
  }
end
