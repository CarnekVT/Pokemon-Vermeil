#===============================================================================
# [VERMEIL] Visual 2.5D - 001_Settings.rb
# Configuracion global y registros del plugin.
#===============================================================================
module Mode7
  module Config
    # Switch global que activa la perspectiva dinamica en el mapa. 0 = desactivado.
    SWITCH_ID     = 0

    # Switch que activa/desactiva el jugador desde el menu de Opciones (pagina
    # Plugins). 0 = oculta la opcion. Configuralo con un switch libre del juego.
    # active_now? lo consulta despues de SWITCH_ID.
    PLAYER_SWITCH = 0

    # MODO INICIAL sin switches. true inicia mapas con 2.5D; false, vanilla.
    # SWITCH_ID/PLAYER_SWITCH y el toggle debug manual tienen prioridad sobre
    # este valor. Cambiarlo no altera partidas ni metadata de mapas.
    DEFAULT_ENABLED = true

    # =======================================================================
    # HEIGHTMAP / CAMARA 3D (relieve real del terreno)
    # Referencia: H-Mode7.update_camera (V.1.4.2) y Neo Mode 7.
    # =======================================================================

    # CAMARA 3D POR HEIGHTMAP: DESACTIVADA.
    # Elevar la camara (cam_y) o la base de muros (wy) por un heightmap rompe
    # el suelo: draw_ground estira franjas de @ground, que es un plano en
    # Z=0. Personajes/camara/muros "flotan" sobre una textura chata.
    # La topografia real se hace por extrusión de bloques filtrados por terrain tag,
    # nunca moviendo la camara. Dejar en false. (El modulo Heightmap queda
    # disponible pero NO como elevacion de camara.)
    HEIGHTMAP_ENABLED  = false

    # Carpeta (relativa a Graphics/) donde buscar los PNG de relieve.
    # Nombre del archivo: Heightmap_XXX.png, donde XXX = id del mapa (3 cifras).
    HEIGHTMAP_FOLDER   = "Heightmaps"

# Elevacion (px de mundo) que representa el valor 255 del PNG (blanco).
    # 255 -> sube 240 px; cada unidad de brillo, 240/255 px.
    HEIGHT_RANGE_PX    = 240

    # Cuanto escala la elevacion dentro de la proyeccion.
    # Mayor = terreno mas accidentado; menor = mas plano.
    HEIGHT_SCALE       = 0.5

    # Velocidad con la que la camara sigue la altura del terreno (0..1).
    # 1.0 = instantanea, 0.05 = suave (como seguimiento reloj).
    ALTITUDE_SMOOTH   = 0.12


    # =======================================================================
    # CAMARA / PROYECCION
    # =======================================================================

    # El Affine antiguo usaba pivote central; Cylindrical conserva el jugador
    # ligeramente por debajo del centro.
    AFFINE_PIVOT_RATIO      = 0.50
    CYLINDRICAL_PIVOT_RATIO = 0.60
    # Angulos independientes por contexto.
    OUTDOOR_DEFAULT_ALPHA = 15
    INDOOR_DEFAULT_ALPHA  = 15
    # Alias legacy para scripts externos.
    DEFAULT_ALPHA = OUTDOOR_DEFAULT_ALPHA

    # Solo existen DOS modos:
    #   :affine       -> matematica del ZIP pre-curve.
    #   :cylindrical  -> exterior curvo.
    PROJECTION = :cylindrical

    # Flags de mapa.
    MAP_FLAG_AFFINE          = "mode7affine"
    MAP_FLAG_AFFINE_LEGACY   = "mode7afine"
    MAP_FLAG_RASTER_AFFINE   = "mode7rasteraffine"
    MAP_FLAG_CYLINDRICAL     = "mode7cylindrical"
    MAP_FLAG_INDOOR          = "mode7indoor"

    # Outside/Outdoor=false siempre fuerza Affine.
    INDOOR_PROJECTION = :affine
    INDOOR_RASTER_TILES = true

    # IndoorWall conecta horizontalmente con el raster Affine en su base,
    # pero conserva altura fija para no verse aplastado/encogido.
    INDOOR_WALL_FIXED_HEIGHT = true

    # Fallback opcional si algun plugin de metadata no expone Outdoor/Outside
    # al runtime. Agrega IDs solamente si los necesitas.
    INDOOR_MAP_IDS = [].freeze

    # Si el mapa contiene alguno de los Terrain Tags exclusivos de interior,
    # la proyeccion se resuelve como Affine aunque la metadata externa no pueda
    # leerse. Se evalua una sola vez al construir el mapa.
    INDOOR_DETECT_FROM_TERRAIN_TAGS = true

    INTERIOR_BORDER_TERRAIN_TAGS = {
      :IndoorBorder => true
    }.freeze
    INDOOR_PROP_TERRAIN_TAGS = {
      :IndoorProp => true
    }.freeze
    INTERIOR_OPAQUE_GROUND = true

    WALL_TOP_Z_BIAS = 1

    # -----------------------------------------------------------------------
    # AFFINE
    # -----------------------------------------------------------------------
    # Valores del ZIP "[VERMEIL] Visual 2.5D(AFFINE PRE-CURVE ONLY AFFINE)".
    AFFINE_SLOPE       = 1.0
    AFFINE_ZOOM        = 0.5
    AFFINE_CONVERGENCE = 0.0
    AFFINE_DEPTH       = 0.4

    # -----------------------------------------------------------------------
    # CYLINDRICAL
    # -----------------------------------------------------------------------
    CYLINDRICAL_RADIUS = 1100.0
    CYLINDRICAL_PHASE  = 1.00
    CYLINDRICAL_MIN    = 0.16
    CYLINDRICAL_MAX    = 1.42

    CYLINDRICAL_GROUND_Y_SCALE         = 1.00
    CYLINDRICAL_WIDTH_PERSPECTIVE      = 0.020
    CYLINDRICAL_BILLBOARD_PERSPECTIVE = 0.0
    CYLINDRICAL_VERTICAL_SCALE         = 1.00
    CYLINDRICAL_SPRITE_SCALE           = 0.0

    # Estos multiplicadores solo afectan Cylindrical. Affine no pasa por ellos.
    # El angulo cambia la curvatura, no el zoom global. A zoom 1.0 los tiles,
    # personajes y bloques conservan escala 1:1 alrededor del jugador.
    CYLINDRICAL_PITCH_STRENGTH           = 0.0
    CYLINDRICAL_BILLBOARD_PITCH_STRENGTH = 0.0

    PRIORITY_RIGID_MIN = 2
    PRIORITY_Z_MIN_STEP = 32.0
    PRIORITY_EDGE_OVERLAP = 1.25
    PRIORITY_EDGE_OVERLAP_MAX = 3.0
    PRIORITY_SURFACES = true
    PRIORITY_SURFACE_MIN = 1

    DEFAULT_ZOOM = 1.0
    CAMERA_ZOOM_MIN            = 0.25
    CAMERA_ZOOM_MAX            = 3.00
    CAMERA_ZOOM_SMOOTH_FRAMES  = 12
    CAMERA_ANGLE_SMOOTH_FRAMES = 18
    MODE_TRANSITION_FRAMES = 1

    # Rendimiento. draw_ground hace un remuestreo horizontal por fila de
    # pantalla; no repetirlo por cada subpixel de scroll.
    GROUND_REDRAW_WORLD_STEP = 2.0
    PRIORITY_REPROJECT_WORLD_STEP = 2.0

    # Cylindrical es el modo caro: rasterizar varias filas de pantalla en un
    # solo stretch_blt reduce mucho el coste al caminar. Affine sigue en 1px
    # para conservar su cuadricula exacta.
    CYLINDRICAL_RASTER_SCAN_STEP = 4

    # Altura del ojo de la formula Affine pre-curve.
    DISTANCE_H = Settings::SCREEN_HEIGHT

    CYLINDRICAL_BACKGROUND_COLOR = Color.new(104, 168, 224)
    OUTSIDE_COLOR = Color.new(0, 0, 0)

    # =======================================================================
    # FILTRO DE VOLUMEN POR TERRAIN TAG. No sustituye el tag del tile: decide
    # que celdas se dibujan como volumen 2.5D. Tag, pasabilidad y mecanicas
    # quedan intactos (por ejemplo HoneyTree conserva Headbutt/miel).
    #
    # Valor > 0 activa el filtro. Es compatibilidad con la configuracion vieja;
    # NO es prioridad, elevacion ni cantidad de tiles. Cada celda conserva su
    # bitmap y proyeccion; tag y capa no mezclan objetos vecinos.
    # Tags de wall EXCLUSIVOS por entorno.
    #
    # IndoorWall no actua en exteriores.
    # Mode7Tag/HoneyTree no actuan como wall de interior.
    # Esto evita que una regla de Mountains/outdoor cambie accidentalmente la
    # composicion de una habitacion.
    INDOOR_WALL_TERRAIN_TAG_HEIGHT = {
      :IndoorWall => 4
    }.freeze
    OUTDOOR_WALL_TERRAIN_TAG_HEIGHT = {
      :Mode7Tag  => 4,
      :HoneyTree => 4
    }.freeze

    # Mountains/Ladders NO tienen propiedades visuales 2.5D.
    # Conservan su Terrain Tag original, pero el renderer no los interpreta
    # como volumen, elevacion ni soporte especial.
    ELEVATED_WALL_TERRAIN_TAG_HEIGHT = {}.freeze

    MOUNTAIN_SHADOW_TERRAIN_TAG_OPACITY = {}.freeze


    # ELEVACION LOCAL POR TERRAIN TAG. No mueve camara: cada tile del filtro
    # se proyecta elevado sobre su propia base, sin alterar tiles adyacentes.
    # Valor = alto visual en px. No cambia tag, colision ni eventos.
    # Usa un tag pasable que NO este en *_WALL_TERRAIN_TAG_HEIGHT. Si un tag
    # pertenece a volumen (por ejemplo :Mountains), gana volumen y se ignora
    # aqui: elevar bitmap de muro rompe sus capas adyacentes.
    # ponytail: hash por tag; altura por tile solo si el mapa realmente la pide.
    TERRAIN_TAG_TILE_HEIGHT = {
    }.freeze

    # Sin camera-lift por Mountains/Ladders. Esta era una de las fuentes
    # principales de desacople entre suelo, walls y prioridades.
    TERRAIN_TAG_CAMERA_LIFT = {}.freeze
    # La transicion empieza durante el paso, no despues de entrar a la celda.
    # Limite por frame: evita un salto visible incluso con lifts altos.
    TERRAIN_TAG_CAMERA_LIFT_SMOOTH = 0.34
    TERRAIN_TAG_CAMERA_LIFT_MAX_STEP = 0.75
    # El lift interpola cada frame, pero el raster solo cambia al cruzar este
    # intervalo. ponytail: 2.0 reduce reconstrucciones; bajar si luego se usa
    # una resolucion donde el escalonado sea visible.
    TERRAIN_TAG_CAMERA_LIFT_RENDER_STEP = 2.0
    # Cambio de profundidad por punto de lift. 50 en Mountains equivale a
    # +15% con 0.003. Subirlo aumenta sensacion de altura; 0.0 lo desactiva.
    TERRAIN_TAG_CAMERA_LIFT_DEPTH_FACTOR = 0.0

    # ESCALERAS LATERALES POR TERRAIN TAG. Unico tag: :LaddersSide.
    # Maker Studio guarda por celda si el tramo sube-derecha (-1) o
    # baja-derecha (1). Este valor es default para celdas aun sin metadata.
    # Paso diagonal real: coordenadas y colision cambian juntas en vanilla y
    # 2.5D.
    SIDE_LADDER_TERRAIN_TAG_SLOPE_Y = {
      :LaddersSide => -1
    }.freeze


    # Radio (en tiles) en pantalla donde se sigue spawncndeando/sposeando
    # objetos/muros del filtro de terrain tags. Antes era 14/18.
    WALL_SPAWN_RADIUS_X = 20
    WALL_SPAWN_RADIUS_Y = 24

    # =======================================================================
    # PASABILIDAD MECANICA vs ELEVACION VISUAL
    # Si true, las celdas con un muro extruido (tile con unify de muro o terrain
    # tag alto) quedan INTRANSITABLES para jugador y eventos: no se pueden
    # atravesar columnas/elevaciones, igual que H-Mode7 lo hace con sus muros
    # verticales. False = el motor sigue ignorando la extrusion (solo visual).
    # =======================================================================
    WALL_BLOCKS_MOVEMENT = true

    # En interiores raster-affine, la pasabilidad del editor/Maker Studio es
    # la autoridad. El renderer no añade una segunda collision wall porque el
    # bloque visual puede abarcar varias layers aunque la collision nativa no.
    INDOOR_WALL_BLOCKS_MOVEMENT = false

    # =======================================================================
    # NIEBLA DE PROFUNDIDAD (distance fog hacia el horizonte)
    # Rampa de alpha por fila de pantalla: 0 en el pivot del jugador, maximo en
    # el horizonte. Los modulos 2.5D (suelo, muros, personajes) la consultan via
    # Mode7.fog_alpha(screen_y) para difuminar lo lejano.
    # =======================================================================
    FOG_ENABLED   = false
    FOG_MAX_ALPHA = 120
    FOG_COLOR     = Color.new(160, 200, 230)
  end
end

# Registro del Terrain Tag propio del plugin (muros / billboards 2.5D).
GameData::TerrainTag.register({
  :id        => :Mode7Tag,
  :id_number => 19
})

GameData::TerrainTag.register({
  :id        => :Ladders,
  :id_number => 21
})

# Terrain tag unico para escaleras laterales. ID 22 queda separado de Ladders
# (21), que conserva solo volumen/camera lift.
unless GameData::TerrainTag.exists?(:LaddersSide)
  GameData::TerrainTag.register({
    :id        => :LaddersSide,
    :id_number => 22
  })
end

# Marco interior de plano. ID 23 queda libre tras retirar LaddersSideReverse.
unless GameData::TerrainTag.exists?(:IndoorBorder)
  GameData::TerrainTag.register({
    :id        => :IndoorBorder,
    :id_number => 23
  })
end

# Tags exclusivos para interiores. No se consultan como walls outdoor.
unless GameData::TerrainTag.exists?(:IndoorWall)
  GameData::TerrainTag.register({
    :id        => :IndoorWall,
    :id_number => 24
  })
end

unless GameData::TerrainTag.exists?(:IndoorProp)
  GameData::TerrainTag.register({
    :id        => :IndoorProp,
    :id_number => 25
  })
end
# Maker Studio guarda la etiqueta Mountains con el ID 20. Essentials no la
# conoce por defecto, por eso el runtime la convertia en :None y los filtros
# 2.5D (muro elevado y camera lift) nunca la recibian.
unless GameData::TerrainTag.exists?(:Mountains)
  GameData::TerrainTag.register({
    :id        => :Mountains,
    :id_number => 20
  })
end
