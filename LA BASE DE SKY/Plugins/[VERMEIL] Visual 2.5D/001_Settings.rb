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
    AFFINE_PIVOT_RATIO      = 0.60
    CYLINDRICAL_PIVOT_RATIO = 0.60
    # Camara NDS: el jugador/pivote queda al 50% de la pantalla.
    PERSPECTIVE_PIVOT_RATIO = 0.52
    # Angulos independientes por contexto.
    # V5.7: exterior mas sutil tipo Pokemon 2.5D; evita que fachadas y
    # billboards se vean excesivamente inclinados.
    OUTDOOR_DEFAULT_ALPHA = 25
    INDOOR_DEFAULT_ALPHA  = 24
    # Alias legacy para scripts externos.
    DEFAULT_ALPHA = OUTDOOR_DEFAULT_ALPHA

    # Proyeccion unica de gameplay: camara pinhole NDS.
    # Affine/Cylindrical se conservan solo como implementacion interna antigua
    # para compatibilidad de codigo, pero ya no pueden ser seleccionados por mapa.
    NDS_ONLY_PROJECTION = true
    PROJECTION = :perspective

    # Flags de mapa.
    MAP_FLAG_AFFINE          = "mode7affine"
    MAP_FLAG_AFFINE_LEGACY   = "mode7afine"
    MAP_FLAG_RASTER_AFFINE   = "mode7rasteraffine"
    MAP_FLAG_CYLINDRICAL     = "mode7cylindrical"
    MAP_FLAG_PERSPECTIVE     = "mode7perspective"
    MAP_FLAG_INDOOR          = "mode7indoor"

    # Indoor/Outdoor comparten el mismo backend NDS. El contexto solo cambia
    # angulo, tags y reglas visuales; nunca cambia la proyeccion. Los flags
    # mode7affine/mode7cylindrical antiguos se ignoran en runtime.
    INDOOR_PROJECTION = :perspective
    INDOOR_RASTER_TILES = false

    # NDSIndoorWall conecta horizontalmente con el raster Affine en su base,
    # pero conserva altura fija para no verse aplastado/encogido.
    INDOOR_WALL_FIXED_HEIGHT = true

    # Fallback opcional si algun plugin de metadata no expone Outdoor/Outside
    # al runtime. Agrega IDs solamente si los necesitas.
    INDOOR_MAP_IDS = [].freeze

    # Si el mapa contiene alguno de los Terrain Tags exclusivos de interior,
    # la proyeccion se resuelve con INDOOR_PROJECTION aunque la metadata externa
    # no pueda leerse. Se evalua una sola vez al construir el mapa.
    INDOOR_DETECT_FROM_TERRAIN_TAGS = true

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
    # Affine conserva la inclinacion principal; esta fraccion mezcla el arco.
    CYLINDRICAL_CURVE_MIX = 0.20

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

    # V5.8: profundidad fisica primero, Priority solo desempata objetos que
    # comparten practicamente la misma superficie. Ya no puede saltar por
    # encima de una montana/plataforma solo por ser P2/P4.
    PHYSICAL_DEPTH_Z_BASE    = 100000
    PHYSICAL_DEPTH_Z_SCALE   = 64.0
    PRIORITY_DEPTH_BIAS_STEP = 4

    # La camara acompana la elevacion real bajo los pies del jugador. En una
    # escalera el valor es continuo, por lo que al llegar a una meseta la
    # pantalla mantiene al jugador en el mismo nivel visual en vez de dejarlo
    # subir hacia el borde superior.
    CAMERA_FOLLOW_SURFACE_ELEVATION = true

    # V6 / Geometry v4: explicit Geometry data uses the clean V25 files under
    # Data/VERMEIL_GEOMETRY_V4. The old legacy Geometry JSON folder is not a
    # runtime source anymore. Maps without a v4 runtime can still use Visual
    # 2.5D Terrain Tags normally; authored v4 maps are authoritative.
    SURFACE_GEOMETRY_ENABLED     = true
    SURFACE_GEOMETRY_DIRECTORY   = "Data/VERMEIL_GEOMETRY_V4"
    SURFACE_GEOMETRY_HEIGHT_STEP = 32.0

    # Compatibility constant retained for older code paths. Geometry v4 runtime
    # never falls back to editor JSON; it reads MapXXX.v25r only.
    SURFACE_GEOMETRY_ALLOW_EDITOR_JSON_RUNTIME = false

    # La altura grafica de un charset NO debe sumar casi un tile entero al Z.
    # Este bias solo desempata billboards que comparten la misma superficie.
    CHARACTER_DEPTH_BIAS = 2
    # ponytail: sin sangrado entre superficies; reactivar solo ante juntas
    # transparentes reproducibles en el raster legacy.
    PRIORITY_EDGE_OVERLAP = 0.0
    PRIORITY_EDGE_OVERLAP_MAX = 0.0
    PRIORITY_SURFACES = true
    PRIORITY_SURFACE_MIN = 1

    DEFAULT_ZOOM = 1.0
    CAMERA_ZOOM_MIN            = 0.50
    CAMERA_ZOOM_MAX            = 1.50
    CAMERA_ZOOM_SMOOTH_FRAMES  = 12
    CAMERA_ANGLE_SMOOTH_FRAMES = 18
    MODE_TRANSITION_FRAMES = 1

    # Mantener suelo y sprites en el mismo subpixel evita juntas al detenerse.
    # ponytail: raster exacto; subir a 1.0 solo si Cylindrical pierde FPS.
    GROUND_REDRAW_WORLD_STEP = 2.0
    PRIORITY_REPROJECT_WORLD_STEP = 2.0

    # Una muestra por fila evita cortes horizontales en tiles altos.
    CYLINDRICAL_RASTER_SCAN_STEP = 2

    # Altura del ojo de la formula Affine pre-curve.
    # Distancia de la camara NDS al pivote. 380 replica el perfil del video.
    DISTANCE_H = 640.0

    CYLINDRICAL_BACKGROUND_COLOR = Color.new(104, 168, 224)
    OUTSIDE_COLOR = Color.new(0, 0, 0)

    # =======================================================================
    # SISTEMA NDS V5 - TERRAIN TAGS VISUALES LIMPIOS
    # =======================================================================
    # V5 deja de reutilizar tags legacy/mecanicas legacy/Mode7Tag/HoneyTree como reglas
    # visuales. Los Terrain Tags del renderer describen SOLO la funcion visual
    # del tile. Priority conserva exclusivamente su funcion de orden de dibujo.
    #
    # Tags que cuentan como pared fisica. No existe camera-lift por Terrain Tag.
    INDOOR_WALL_TERRAIN_TAG_HEIGHT = {
      :NDSIndoorWall => 4
    }.freeze
    OUTDOOR_WALL_TERRAIN_TAG_HEIGHT = {
      :NDSWall              => 4,
      :NDSMountainWall      => 4,
      :NDSWallPlane         => 4,
      :NDSMountainWallPlane => 4
    }.freeze

    INTERIOR_BORDER_TERRAIN_TAGS = {
      :NDSIndoorBorder => true
    }.freeze
    INDOOR_PROP_TERRAIN_TAGS = {
      :NDSIndoorProp => true
    }.freeze
    INDOOR_BLACK_TERRAIN_TAGS = {
      :NDSIndoorBlack => true
    }.freeze

    # Compatibilidad interna del renderer. V4 no define ElevatedWall, sombras
    # de tags legacy, altura generica por tag ni desplazamiento de camara por tag.
    ELEVATED_WALL_TERRAIN_TAG_HEIGHT = {}.freeze
    MOUNTAIN_SHADOW_TERRAIN_TAG_OPACITY = {}.freeze
    TERRAIN_TAG_TILE_HEIGHT = {}.freeze

    # Radio (en tiles) en pantalla donde se sigue spawncndeando/sposeando
    # objetos/muros del filtro de terrain tags. Antes era 14/18.
    WALL_SPAWN_RADIUS_X = 14
    WALL_SPAWN_RADIUS_Y = 16

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

    # =======================================================================
    # MKXP-Z EXT (rama feature.interactable-console-shader + integraciones)
    # =======================================================================
    # Conserva coordenadas Float hasta Sprite.x/y. Reduce el temblor al hacer
    # scroll lento y durante transiciones suaves de camara.
    EXT_SUBPIXEL_SPRITES = true

    # Quads arbitrarios nativos. Walls y superficies de prioridad pueden usar
    # los 4 vertices proyectados en vez de depender solo de zoom_x/zoom_y.
    EXT_CORNERS_ENABLED    = true
    EXT_CORNERS_WALLS      = true
    EXT_CORNERS_PRIORITIES = true
    # ponytail: solape subpixel minimo; subirlo solo si otro backend rasteriza
    # juntas mayores entre quads que comparten exactamente el mismo borde.
    EXT_CORNERS_OVERLAP    = 0.0

    # -----------------------------------------------------------------------
    # RENDERER V4.0 - NDS TILE SPACE / ALTO RENDIMIENTO
    # -----------------------------------------------------------------------
    # Objetivo: perspectiva NDS coherente con el menor coste Ruby posible.
    # Todo usa la misma Mode7.project(): suelo, volumen, walls y personajes.
    # No se usan modelos 3D.
    NDS_PERFORMANCE_PROFILE = :performance  # :performance, :balanced, :quality
    # Global runtime cache layer. Keeps expensive projection/mode queries out
    # of hot per-face/per-character loops and idles 3D-only work when disabled.
    GLOBAL_RUNTIME_OPTIMIZATIONS = true
    IDLE_3D_WHEN_DISABLED        = true

    # La malla cacheada evita los ~480 stretch_blt que hacía el raster legacy
    # cada vez que avanza la cámara. Es el único camino viable para mantener
    # FPS estables en exterior; las bandas runtime se adaptan al perfil NDS.
    GEOMETRY_GROUND_ENABLED      = true
    GEOMETRY_GROUND_BAND_HEIGHT  = 32
    GEOMETRY_GROUND_OVERLAP      = 0.0
    GEOMETRY_GROUND_CULL_MARGIN  = 48
    GEOMETRY_GROUND_X_MARGIN     = 48
    GEOMETRY_GROUND_POOL_MAX     = 96
    # mkxp-z-ext proyecta el bitmap completo con un vertex shader. Esto elimina
    # las bandas/corners del suelo y todo su coste Ruby durante el movimiento.
    # Si Shader no existe o no compila, el renderer vuelve al camino por bandas.
    NDS_NATIVE_GROUND_SHADER     = true
    # Cuantización subpíxel: evita que suelo, paredes y tops se actualicen en
    # frames distintos sin introducir los saltos visibles del umbral de 2 px.
    NDS_GROUND_REPROJECT_STEP    = 2.0

    GEOMETRY_PRIORITY_SURFACES = true
    GEOMETRY_WALLS             = true

    # Camara NDS segura. BALANCE 0.5 reparte el foreshortening entre X/Y:
    # evita que al subir el angulo los tiles se ensanchen de golpe.
    PERSPECTIVE_NEAR_CLIP        = 24.0
    PERSPECTIVE_COS_MIN          = 0.18
    PERSPECTIVE_FOCAL_SCALE_MAX  = 3.5
    PERSPECTIVE_FOCAL_BALANCE    = 0.30
    PERSPECTIVE_SAFE_DISTANCE     = true
    PERSPECTIVE_SAFE_DISTANCE_BASE = 300.0
    PERSPECTIVE_SAFE_DISTANCE_PER_DEGREE = 4.0
    PERSPECTIVE_BILLBOARD_HEIGHT = 32.0

    # V5: una sola camara. Suelo, personajes y billboards comparten F/depth.
    PERSPECTIVE_OUTDOOR_BILLBOARD_STRENGTH = 1.0
    PERSPECTIVE_INDOOR_BILLBOARD_STRENGTH  = 1.0

    PERSPECTIVE_GROUND_MIN_SCALE = 0.55
    PERSPECTIVE_GROUND_MAX_SCALE = 1.65
    PERSPECTIVE_OBJECT_MIN_SCALE = 0.55
    PERSPECTIVE_OBJECT_MAX_SCALE = 1.65

    # -----------------------------------------------------------------------
    # CATEGORIAS VISUALES NDS V4
    # -----------------------------------------------------------------------
    # IDs 19-26 son el nucleo nuevo. IDs 27+ cubren casos especializados.
    NDS_FLOOR_TERRAIN_TAG       = :NDSFloor
    NDS_WALL_TERRAIN_TAG        = :NDSWall
    NDS_ROOF_TERRAIN_TAG        = :NDSRoof
    NDS_BILLBOARD_TERRAIN_TAG   = :NDSBillboard
    NDS_VOLUME_TERRAIN_TAG      = :NDSVolume
    NDS_STRUCTURE_TERRAIN_TAG   = :NDSStructure
    NDS_INDOOR_WALL_TERRAIN_TAG = :NDSIndoorWall
    NDS_INDOOR_PROP_TERRAIN_TAG = :NDSIndoorProp

    NDS_INDOOR_BORDER_TERRAIN_TAG = :NDSIndoorBorder
    NDS_INDOOR_BLACK_TERRAIN_TAG  = :NDSIndoorBlack
    NDS_MOUNTAIN_TOP_TERRAIN_TAG  = :NDSMountainTop
    NDS_MOUNTAIN_WALL_TERRAIN_TAG = :NDSMountainWall
    NDS_ROOF_HIGH_TERRAIN_TAG     = :NDSRoofHigh
    NDS_VOLUME_HIGH_TERRAIN_TAG   = :NDSVolumeHigh
    NDS_OVERLAY_TERRAIN_TAG       = :NDSOverlay

    # La camara mueve TODOS los grupos en el mismo espacio. El bitmap conserva
    # proporcion; la perspectiva solo aplica una escala uniforme por su pie.
    NDS_WALL_HEIGHT_SCALE          = 0.88
    NDS_MOUNTAIN_WALL_HEIGHT_SCALE = 1.00
    # El tag MountainWall normal conserva el arte 2D apilado como una sola
    # fachada rigida. Solo MountainWallPlane fuerza un quad vertical real.
    # Convertir cada fila normal en plano producia tiras y huecos entre niveles.
    NDS_MOUNTAIN_WALLS_AS_PLANES   = true

    # V5.9: MountainTop es la autoridad geometrica. MountainWall queda como
    # proveedor de arte/numero de niveles; las caras fisicas se generan desde
    # el borde REAL de la meseta. Esto permite frentes irregulares y laterales
    # automaticos sin obligar al mapper a dibujar un mapa pensando en 3D.
    NDS_MOUNTAIN_AUTO_FACES         = true
    NDS_MOUNTAIN_AUTO_SIDE_FACES    = true
    NDS_MOUNTAIN_HEIGHT_COLLISION   = true
    NDS_MOUNTAIN_COLLISION_EPSILON  = 1.0

    # La mitad superior de una hierba de dos tiles es billboard mientras el
    # pie sigue siendo bush/suelo. Se alinea matematicamente con el borde norte
    # del tile base y se deja este pequeno solape para ocultar raster seams.
    NDS_BUSH_CAP_OVERLAP_PX         = 2.0

    NDS_BILLBOARD_DEPTH_STRENGTH   = 1.00
    NDS_STRUCTURE_DEPTH_STRENGTH   = 1.00
    NDS_OVERLAY_DEPTH_STRENGTH     = 1.00
    NDS_BILLBOARD_SCALE_MIN        = 0.55
    NDS_BILLBOARD_SCALE_MAX        = 1.65
    NDS_STRUCTURE_SCALE_MIN        = 0.55
    NDS_STRUCTURE_SCALE_MAX        = 1.65

    # Alturas independientes de Priority. Priority vuelve a ser SOLO orden Z.
    NDS_ROOF_HEIGHT       = 48.0
    NDS_ROOF_HIGH_HEIGHT  = 72.0
    NDS_MOUNTAIN_HEIGHT   = 32.0
    NDS_VOLUME_HIGH_HEIGHT = 24.0

    # -----------------------------------------------------------------------
    # VOLUMEN NDS POR TILE
    # -----------------------------------------------------------------------
    # NDSVolume genera grosor ligero; NDSVolumeHigh y NDSMountainTop tienen
    # alturas propias. El TOP conserva la textura original.
    NDS_VOLUME_ENABLED          = true
    NDS_VOLUME_DEFAULT_HEIGHT   = 8.0
    NDS_VOLUME_MAX_HEIGHT       = 64.0
    NDS_VOLUME_FRONT_FACES      = true
    NDS_VOLUME_SIDE_FACES       = true
    NDS_VOLUME_EDGE_SAMPLE      = 1
    NDS_VOLUME_FRONT_SHADE      = 30
    NDS_VOLUME_SIDE_SHADE       = 48
    NDS_VOLUME_CULL_TILES_X     = 14
    NDS_VOLUME_CULL_TILES_Y     = 12
    NDS_VOLUME_BUCKET_SIZE      = 8
    NDS_VOLUME_REPROJECT_STEP   = 2.0

    # V4.1 Fast Path
    # Las caras de volumen se preparan como metadata al cargar el mapa y sus
    # Bitmaps/Sprites se crean solo cuando entran en la zona visible.
    NDS_LAZY_VOLUME_FACES       = true
    NDS_VOLUME_FACE_BUILD_BUDGET = 3
    NDS_VOLUME_FACE_CACHE_MAX    = 128

    # Buckets espaciales para no iterar todas las fachadas/props del mapa en
    # cada frame. 8 tiles es un buen compromiso para mapas grandes.
    NDS_RUNTIME_BUCKET_SIZE      = 8
    NDS_WALL_REPROJECT_STEP      = 2.0

    # Los tags normales protegen arte Pokemon ya perspectivado. Usa los tags
    # Plane solo cuando quieras una superficie geometricamente 3D.
    NDS_WALL_PLANE_TERRAIN_TAG          = :NDSWallPlane
    NDS_ROOF_PLANE_TERRAIN_TAG          = :NDSRoofPlane
    NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG = :NDSMountainWallPlane

    # La escalera se dibuja como una rampa 3D: un quad inclinado cuyo borde sur
    # queda a ras del suelo y el borde norte sube hasta la elevacion vecina.
    # NDS_STAIR_HEIGHT es la subida por defecto si no hay meseta/volumen al norte.
    NDS_STAIR_TERRAIN_TAG = :NDSStair
    NDS_STAIR_HEIGHT      = 32.0

    # -----------------------------------------------------------------------
    # OBJETOS GEOMETRY (cubos/planos del editor 2.5D Geometry)
    # -----------------------------------------------------------------------
    # Objetos colocados con la herramienta "Objetos" del mod Maker Studio y
    # guardados en legacy Geometry authoring data (array "objects"). Se dibujan
    # como quads 3D texturizados y, segun su colision, bloquean el paso.
    NDS_GEOMETRY_OBJECTS_ENABLED = true
    NDS_OBJECT_CULL_TILES_X      = 16
    NDS_OBJECT_CULL_TILES_Y      = 14
    NDS_OBJECT_FRONT_SHADE       = 24
    NDS_OBJECT_SIDE_SHADE        = 46
    NDS_OBJECT_TOP_SHADE         = 0
    NDS_OBJECT_LAZY_BITMAPS      = true
    NDS_OBJECT_REPROJECT_STEP    = 2.0
    # Limita creación de sprites/materiales Geometry por frame para evitar picos al cargar.
    NDS_OBJECT_FACE_BUILD_BUDGET = 4
    NDS_OBJECT_FACE_CACHE_MAX    = 192
    # Reuse identical generated face bitmaps (same material/UV/size) across
    # sprites. This cuts allocations heavily on repeated cliffs/buildings.
    NDS_OBJECT_BITMAP_CACHE_MAX  = 256
    # Phase 2 Sky-safe Performance Core. With the stock Sky runtime (no
    # Sprite#corners), project/cull all candidate Geometry faces in ONE DLL call.
    NDS_OBJECT_SKY_NATIVE_BATCH  = true
    NDS_OBJECT_SKY_BATCH_MIN_FACES = 4

    # Lightweight diagnostics. Timing is sampled only once every N frames, so it
    # does not turn profiling itself into the performance problem.
    V25_PERF_DIAGNOSTICS         = true
    V25_PERF_SAMPLE_INTERVAL     = 300
    # Model Studio 3.1 writes optional special-model meshes as JSONL. Only a tiny
    # number of faces are parsed/registered per frame, eliminating the
    # synchronous full-model JSON.parse hitch when entering a map.
    # Hybrid terrain keeps first-frame geometry tiny. Special Model Studio /
    # Blockbench meshes wait until the map is already playable and are streamed
    # only while the player is idle, avoiding micro-hitches during movement.
    NDS_MODEL_STREAM_START_DELAY_FRAMES = 12
    NDS_MODEL_STREAM_INTERVAL_FRAMES    = 2
    NDS_MODEL_STREAM_IDLE_ONLY          = true
    NDS_MODEL_STREAM_FACE_BUDGET        = 16
    NDS_MODEL_STREAM_TIME_MS            = 0.75
    # Altura (en tiles) que el jugador puede subir por una cara "climb"/"one-way"
    # sin escalera. Por encima se trata como pared solida.
    NDS_OBJECT_CLIMB_MAX_TILES   = 1
    # Sombras: las capas de Maker Studio son sombras planas por layer. Los props
    # verticales (billboards/estructuras) las aplanan en una linea antiestetica y
    # heredan la direccion de config de CADA sombra. Con NDS_SHADOW_PROP_BLOBS
    # el bake las sustituye por un blob radial uniforme en la base del prop.
    NDS_SHADOW_PROP_BLOBS = false
    NDS_SHADOW_BLOB_CORE_ALPHA = 180
    NDS_SHADOW_BLOB_MIN_OPACITY = 192

    # La sombra del personaje se apoya en el plano: se comprime en Y con la
    # misma cámara que el suelo y se oculta bajo la hierba alta.
    OW_SHADOW_GROUND_ALIGNMENT = true
    OW_SHADOW_HIDE_IN_BUSH     = true

    # -----------------------------------------------------------------------
    # FPS / MKXP-Z
    # -----------------------------------------------------------------------
    # El ZIP incluye un perfil mkxp.json para 120 FPS: vsync OFF,
    # syncToRefreshrate OFF y fixedFramerate 120. Se configura fuera del plugin
    # para que sea facil volver atras si otro plugin depende de una tasa concreta.
    # Graphics.average_frame_rate se usa aqui solo para diagnostico.
    # V5: zoom de camara global. Ningun Terrain Tag posee un zoom propio.
    PROGRESSIVE_ZOOM_ENABLED = true
    FORCE_RIGID_OBJECT_SCALE = false
    GROUND_SAFE_X_COVERAGE = true

    NDS_SHOW_PERFORMANCE_DEBUG = false
  end
end

#===============================================================================
# Terrain Tags visuales NDS V4
# IDs 19-26 forman el nucleo. El usuario puede reasignar sus tilesets sin
# conservar ninguna semantica del sistema anterior.
#===============================================================================
[
  [:NDSFloor,        19],
  [:NDSWall,         20],
  [:NDSRoof,         21],
  [:NDSBillboard,    22],
  [:NDSVolume,       23],
  [:NDSStructure,    24],
  [:NDSIndoorWall,   25],
  [:NDSIndoorProp,   26],
  [:NDSIndoorBorder, 27],
  [:NDSIndoorBlack,  28],
  [:NDSMountainTop,  29],
  [:NDSMountainWall, 30],
  [:NDSRoofHigh,     31],
  [:NDSVolumeHigh,   32],
  [:NDSOverlay,      33],
  [:NDSRoofPlane,     34],
  [:NDSWallPlane,     35],
  [:NDSMountainWallPlane, 36],
  [:NDSStair,         37]
].each do |id, number|
  next if GameData::TerrainTag.exists?(id)
  GameData::TerrainTag.register({ :id => id, :id_number => number })
end
