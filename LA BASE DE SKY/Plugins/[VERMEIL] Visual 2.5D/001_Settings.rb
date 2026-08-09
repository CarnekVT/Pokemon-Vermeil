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

    # Color base fuera del limite (fondo del relieve bajo el suelo).
    RELIEF_BASE_COLOR = Color.new(80, 100, 140)

    # =======================================================================
    # CAMARA POR DEFECTO (ESTILO GEN 5)
    # Perspectiva conica central con horizonte elevado y camara en picado.
    # =======================================================================

    # Fila de pantalla (fraccion) donde queda anclado el jugador.
    # 0.50 = centro exacto de pantalla. Combinado con cam_y anclada a pivot_y,
    # mantiene el centro de camara == centro matematico de proyeccion.
    # Jugador anclado ~62% abajo (look Animal Crossing / Sky Flyer).
    PIVOT_RATIO   = 0.62

    # Inclinacion de la camara en grados (roll del cilindro Sky).
    DEFAULT_ALPHA = 25
    # =======================================================================
    # PROYECCION: AFINE, CONIC, o SKY (Cilíndrica)
    # =======================================================================
    # :sky    -> Proyección cilíndrica (Mario Galaxy). Líneas paralelas, 
    #            el mundo "rueda" hacia el horizonte. (Efecto Sky real).
    # :affine -> Pendiente constante plana.
    # :conic  -> Perspectiva real con punto de fuga.
    PROJECTION = :sky

    # =======================================================================
    # PROYECCION POR MAPA (flags opcionales; por defecto todo sigue SKY)
    # La proyeccion global (PROJECTION) se puede FORZAR por mapa via flags de
    # metadata (PBS: map_metadata.txt, columna Flags). Interior/exterior usan
    # Sky por defecto; Mode7Affine queda disponible como excepcion por mapa.
    #   "Mode7Affine" -> espacia el mapa en proyeccion plana.
    #   "Mode7Sky"    -> fuerza la curva cilindrica.
    MAP_FLAG_AFFINE = "mode7afine"
    MAP_FLAG_SKY    = "mode7sky"

    # Sky tambien en interiores. Mode7Affine en Flags fuerza el modo interior
    # plano solo para mapas que realmente lo necesiten.
    AUTO_INDOOR_AFFINE = false

    # BORDE INTERIOR. Superficie del plano para zocalos, bordes y suelo
    # interior. No entra al volumen ni a prioridad: conserva posicion exacta
    # junto al piso curvo. Pasabilidad sigue siendo la del tile en Maker Studio.
    INTERIOR_BORDER_TERRAIN_TAGS = {
      :InteriorBorder => true
    }.freeze

    # Interiores: mantener el bitmap de suelo opaco para que celdas vacias no
    # dejen ver panoramas/fogs del mapa anterior por transparencia.
    INTERIOR_OPAQUE_GROUND = true

    # Si una puerta/ventana no lleva Mode7Tag, puede heredar visualmente la
    # condicion de muro cuando esta encajada ENTRE dos columnas etiquetadas.
    # Es solo visual: NO convierte esa celda en bloqueante para pasabilidad.
    INTERIOR_INFER_WALL_CONNECTORS = false

    # Legacy de Phase 3. Phase 4 ya no duplica el grafico del muro sobre el
    # suelo; el plano y las superficies verticales se separan de forma explicita.
    INTERIOR_WALL_GROUND_SEAL = false

    # Bias de profundidad para piezas de techo/prioridad alta. Nunca usar 9999:
    # deben seguir ordenandose por la Y de su base como el jugador.
    WALL_TOP_Z_BIAS = 1

    # Radio del "planeta" para el modo :sky (en píxeles).
    # Menor radio = mayor curvatura/perspectiva hacia el horizonte.
    PLANET_RADIUS = 230.0

    # Slope de inclinacion (px de pantalla por px de mundo) en afín.
    # Positivo abajo delante (mundo hacia abajo). Menor = mas plano.
    AFFINE_SLOPE = 1

    # Zoom horizontal (px pantalla por px mundo). Bajo el pitch visible.
    AFFINE_ZOOM  = 0.5

    # Convergencia al horizonte (0..1). Forma de "lente" FIJA en espacio de
    # pantalla. NOTA: cualquier valor >0 es curvatura = estiramiento al
    # moverse (por eso Sky usa 0). En 0 el mundo es un plano afín puro:
    # scroll 100% estable, cero mareo; la profundidad se da con AFFINE_SLOPE.
    #   0.0 -> plano afín (Sky, RECOMENDADO)
    #   0.2+ -> curvatura suave (acepta leve estiramiento)
    AFFINE_CONVERGENCE = 0.0

    # Profundidad vertical del plano afín. Intensidad de la CONICA DE CAMARA
    # FIJA (terreno 3D de Sky): las filas lejanas convergen al horizonte y las
    # cercanas se estiran, y ESA deformacion pertenece al plano del mapa, NO al
    # jugador (scroll estable, sin mareo). Usa la MISMA logica que la conica
    # original (affine_depth_scale, formula heff*yi*cos/(heff-yi*sin)) pero con
    # curvatura SUTIL: AFFINE_DEPTH es el divisor de la altura del ojo (heff =
    # DISTANCE_H/t), asi que un valor BAJO aplanNa poco y un valor ALTO curva mas.
    #   ~0.15-0.3 -> deformacion suave (recomendado: no marea, da 3D sutil)
    #   ~1.0      -> conica plena (perspectiva marcada tipo Gen5)
    AFFINE_DEPTH      = 0.4

    # Fuerza de la perspectiva afine (0..1). Multiplica el seno efectivo de la
    # camara en la proyeccion. Con 1.0 = perspectiva original (crecimiento
    # cuadratico 1/d^2 -> "embudo" en las filas cercanas, horizonte cercano).
    # Con valores bajos el terreno se aplana, las filas apenas cambian de tamano
    # y el horizonte se aleja (look Sky / Animal Crossing). 0.0 = afin puro plano
    # (zoom constante por fila, sin perspectiva). Se aplica CONSISTENTEMENTE en
    # scale/unscale/hscale/horizon para no rasgar el terreno.
    AFFINE_PERSPECTIVE = 0.0

    # =======================================================================
    # SKY V2 - PROYECCION CILINDRICA HIBRIDA (look Sky / Animal Crossing)
    # Terreno = mezcla de curva seno + tramo lineal; compresion horizontal de
    # las filas lejanas; sprites con escala propia. Todos los knobs son 0..1.
    # =======================================================================

    # Curva residual del suelo. El 3D ya NO depende de una "banana" fuerte:
    # primero comprimimos el plano en Y y luego anadimos una curvatura suave.
    SKY_CURVE = 0.45

    # Parte lineal de la proyeccion del suelo. Debe complementar SKY_CURVE.
    SKY_LINEAR = 0.55

    # Escala vertical LOCAL del plano. 1.0 conserva altura de cada celda;
    # Sky curva posicion global, no aplasta tiles hacia el horizonte.
    SKY_GROUND_Y_SCALE = 1.00

    # Conicidad muy leve del plano de suelo. Mantiene profundidad sin convertir
    # el mapa en una rejilla plana.
    SKY_WIDTH_PERSPECTIVE = 0.050

    # Walls bloqueantes se dibujan como objetos completos anclados a su base.
    # ElevatedWall y prioridad fuera de walls siguen bordes de cada celda.
    # 0.0 deja wall con forma original.
    SKY_BILLBOARD_PERSPECTIVE = 0.0

    # Legacy de configuracion. Wall P1 ahora se rasteriza con el mismo plano
    # scanline de Mountains; no admite curva local porque separaba P0/P1.
    # Se conserva para compatibilidad con configuraciones anteriores.
    SKY_WALL_CURVE_RESPONSE = 0.08

    # RIGIDEZ VERTICAL DEL RASTER WALL (0.0..1.0). Solo P1+ de tags wall.
    # 0.0 = alto exacto del plano Mountains. 1.0 = nunca encoge por debajo
    # de su alto base en el borde inferior. X y prioridad siguen scanline.
    # 0.35 conserva volumen sin volver a separar P0/P1.
    SKY_WALL_RASTER_RIGIDITY = 1

    # Solape vertical en px de pantalla entre filas wall. Tapa lineas de
    # redondeo al proyectar dos tiles que comparten borde.
    SKY_WALL_ROW_OVERLAP = 1.0

    # Personajes/OW conservan escala fija: NPCs, followers y eventos no crecen
    # ni encogen al recorrer la curvatura.
    SKY_SPRITE_SCALE = 0.0

    # Cuanto de un pixel de altura real se ve verticalmente en pantalla. Los
    # muros y elevaciones usan este eje Z separado de la Y del suelo.
    SKY_VERTICAL_SCALE = 1.00

    # Tiles con prioridad > 0 salen del suelo y conservan prioridad RPG Maker.
    # Fuera de wall se proyectan entre bordes de fila; dentro de wall usan una
    # pieza completa con respuesta vertical leve, para no dejar cortes.
    PRIORITY_SURFACES = true
    PRIORITY_SURFACE_MIN = 1

    # Una prioridad N se ordena como si su base de profundidad estuviera N tiles
    # mas adelante. Reproduce el comportamiento visual clasico sin usar z=9999.
    PRIORITY_DEPTH_STEP = 32

    # Reproyeccion de tiras priority en scroll horizontal. Con Y no se puede
    # interpolar: cambia la curvatura de cada fila y aparecen cortes.
    PRIORITY_REPROJECT_PIXELS = 4
    PRIORITY_VERTICAL_REPROJECT_PIXELS = 1

    # FOV horizontal en grados. Controla el aplanado de la cuadricula,
    # desacoplado del pitch:
    #   55+   -> perspectiva plena (distorsion amplia, esquinas estiradas)
    #   15-30 -> FOV retro: tiles arriba y abajo casi del mismo tamano
    #   0     -> ortografico puro (cero distorsion horizontal)
    FOV           = 15

    # =======================================================================
    # RUBBER (LEGACY - DESCARTADO)
    # Deformacion local elastica del suelo alrededor del jugador. Se descarto:
    # la sensacion 3D debe venir de la CONICA DE CAMARA FIJA global (sutil,
    # no mareante), no de una lente local que deformaba el muestreo.
    # =======================================================================
    RUBBER_ENABLED = false
    RUBBER_RADIUS  = 160
    RUBBER_FORCE   = 0.0

    # Zoom base (1.0 = escala natural del pixel art).
    DEFAULT_ZOOM  = 1

    # Limites y suavizado del zoom de depuracion. El zoom no modifica
    # colisiones: solo la proyeccion y el area visible.
    CAMERA_ZOOM_MIN           = 0.25
    CAMERA_ZOOM_MAX           = 3.00
    CAMERA_ZOOM_SMOOTH_FRAMES = 12

    # Frames al activar/desactivar 2.5D desde Opciones o debug.
    MODE_TRANSITION_FRAMES = 1

    # Altura del ojo (normalmente la altura de pantalla).
    DISTANCE_H    = Settings::SCREEN_HEIGHT

    # Color del cielo (visible si la camara baja demasiado).
    SKY_COLOR     = Color.new(104, 168, 224)

    # Color renderizado fuera de los limites del mapa.
    OUTSIDE_COLOR = Color.new(0, 0, 0)

    # =======================================================================
    # FILTRO DE VOLUMEN POR TERRAIN TAG. No sustituye el tag del tile: decide
    # que celdas se dibujan como volumen 2.5D. Tag, pasabilidad y mecanicas
    # quedan intactos (por ejemplo HoneyTree conserva Headbutt/miel).
    #
    # Valor > 0 activa el filtro. Es compatibilidad con la configuracion vieja;
    # NO es prioridad, elevacion ni cantidad de tiles. Cada celda conserva su
    # bitmap y proyeccion; tag y capa no mezclan objetos vecinos.
    INDOOR_WALL_TERRAIN_TAG_HEIGHT = {
      :Mode7Tag => 4,
    }.freeze
    OUTDOOR_WALL_TERRAIN_TAG_HEIGHT = {
      :Mode7Tag => 4,
      :HoneyTree => 4
    }.freeze

    # MURO ELEVADO 2.5D. Clase aparte del muro normal: conserva volumen visual,
    # pero deja la pasabilidad al tile nativo. Mountains bloquea en paredes por
    # su pasabilidad original y permite escaleras/plataformas que sean pasables.
    # No duplicar un tag aqui y en *_WALL_* normal.
    ELEVATED_WALL_TERRAIN_TAG_HEIGHT = {
      :Mountains => 4,
      :Ladders => 4,
      :LaddersSide => 4
    }.freeze

    # SOMBRA DE SUPERFICIE PARA MOUNTAINS. Replica sombra Maker Studio sobre
    # Mountain solo cuando la sombra cae DESDE otra pieza; el propio source tile
    # queda encima, como vanilla. Valor 0..255 multiplica opacity original MS.
    # Agregar un tag aqui es opt-in, no altera sombra de otros walls.
    MOUNTAIN_SHADOW_TERRAIN_TAG_OPACITY = {
      :Mountains => 255
    }.freeze

    # PRIORIDAD HIBRIDA 2.5D. Terrain tags aqui NO son volumenes. Al pisar la
    # celda, el tile queda en priority 0; si el jugador esta detras (al norte),
    # usa temporalmente el valor configurado y lo cubre. No cambia PBS,
    # pasabilidad ni comportamiento fuera de Mode7.
    HYBRID_PRIORITY_TERRAIN_TAGS = {
      :Grass     => 3
    }.freeze

    # Altura visual en px para capas hibridas. Grass queda sobre el suelo como
    # una alfombra de hojas baja; no cambia colision, terreno ni prioridad PBS.
    HYBRID_PRIORITY_TERRAIN_TAG_HEIGHT = {
      :Grass     => 2
    }.freeze

    # ELEVACION LOCAL POR TERRAIN TAG. No mueve camara: cada tile del filtro
    # se proyecta elevado sobre su propia base, sin alterar tiles adyacentes.
    # Valor = alto visual en px. No cambia tag, colision ni eventos.
    # Usa un tag pasable que NO este en *_WALL_TERRAIN_TAG_HEIGHT. Si un tag
    # pertenece a volumen (por ejemplo :Mountains), gana volumen y se ignora
    # aqui: elevar bitmap de muro rompe sus capas adyacentes.
    # ponytail: hash por tag; altura por tile solo si el mapa realmente la pide.
    TERRAIN_TAG_TILE_HEIGHT = {
    }.freeze

    # ELEVACION DE CAMARA POR TERRAIN TAG. Mountains es ElevatedWall: en
    # escalera/plataforma pasable activa lift; en pared usa su pasabilidad
    # nativa. El lift cambia profundidad alrededor del pivot del jugador, NO
    # traslada el origen del mapa: player, NPCs y colisiones quedan en su celda.
    # Valor = intensidad base del efecto de elevacion.
    TERRAIN_TAG_CAMERA_LIFT = {
      :Mountains => 24,
      :Ladders => 12,
      :LaddersSide => 8

    }.freeze
    # La transicion empieza durante el paso, no despues de entrar a la celda.
    # Limite por frame: evita un salto visible incluso con lifts altos.
    TERRAIN_TAG_CAMERA_LIFT_SMOOTH = 0.34
    TERRAIN_TAG_CAMERA_LIFT_MAX_STEP = 0.75
    # Cambio de profundidad por punto de lift. 50 en Mountains equivale a
    # +15% con 0.003. Subirlo aumenta sensacion de altura; 0.0 lo desactiva.
    TERRAIN_TAG_CAMERA_LIFT_DEPTH_FACTOR = 0.003

    # ESCALERAS LATERALES POR TERRAIN TAG. Unico tag: :LaddersSide.
    # Maker Studio guarda por celda si el tramo sube-derecha (-1) o
    # baja-derecha (1). Este valor es default para celdas aun sin metadata.
    # Paso diagonal real: coordenadas y colision cambian juntas en vanilla y
    # 2.5D.
    SIDE_LADDER_TERRAIN_TAG_SLOPE_Y = {
      :LaddersSide => -1
    }.freeze

    # =======================================================================
    # ELEVACION FALSO 3D (apilado de capas sobre el cilindro)
    # =======================================================================

    # Compatibilidad legacy. Desde Phase 4, el indice de layer/unify NO implica
    # altura fisica. Solo se usa elevacion cuando Maker Studio la define de forma
    # explicita. Estas constantes quedan para proyectos que las consulten fuera.
    ELEVATION_PER_UNIFY = 12
    ELEVATION_FLOOR_PAD = 4

    # Radio (en tiles) en pantalla donde se sigue spawncndeando/sposeando
    # objetos/muros del filtro de terrain tags. Antes era 14/18.
    WALL_SPAWN_RADIUS_X = 26
    WALL_SPAWN_RADIUS_Y = 34

    # =======================================================================
    # PASABILIDAD MECANICA vs ELEVACION VISUAL
    # Si true, las celdas con un muro extruido (tile con unify de muro o terrain
    # tag alto) quedan INTRANSITABLES para jugador y eventos: no se pueden
    # atravesar columnas/elevaciones, igual que H-Mode7 lo hace con sus muros
    # verticales. False = el motor sigue ignorando la extrusion (solo visual).
    # =======================================================================
    WALL_BLOCKS_MOVEMENT = true

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
unless GameData::TerrainTag.exists?(:InteriorBorder)
  GameData::TerrainTag.register({
    :id        => :InteriorBorder,
    :id_number => 23
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
