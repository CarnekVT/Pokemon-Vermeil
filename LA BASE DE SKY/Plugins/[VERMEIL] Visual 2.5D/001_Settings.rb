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

    # =======================================================================
    # HEIGHTMAP / CAMARA 3D (relieve real del terreno)
    # Referencia: H-Mode7.update_camera (V.1.4.2) y Neo Mode 7.
    # =======================================================================

    # CAMARA 3D POR HEIGHTMAP: DESACTIVADA.
    # Elevar la camara (cam_y) o la base de muros (wy) por un heightmap rompe
    # el suelo: draw_ground estira franjas de @ground, que es un plano en
    # Z=0. Personajes/camara/muros "flotan" sobre una textura chata.
    # La topografia real se hace por EXTRUSION de bloques (WALL_TERRAIN_TAG_HEIGHT),
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
    PIVOT_RATIO   = 0.50

    # Inclinacion de la camara en grados.
    # Debe ser BAJA para no distorsionar al mover el jugador en vertical
    # (efecto acordeon). 10-14 grados da sutil 3D sin romper el ambiente.
    DEFAULT_ALPHA = 12
    # =======================================================================
    # PROYECCION: AFINE (pendiente fija + scroll) = la que usa Sky.
    # La cuadricula base jamas se deforma: es un plano liso matematico en Z=0.
    # La elevacion se construye APILANDO GEOMETRIA (bloques extruidos por
    # terrain tag), no inflando la proyeccion ni moviendo la camara.
    # =======================================================================

    # :affine -> pendiente constante. El jugador solo desliza offset (scroll).
    #            Cero estiramiento/encogido, cero mareo. (Recomendado.)
    # :conic  -> perspectiva real, se re-proyecta al moverte. Mas "3D" pero
    #            con la deformacion que produce el efecto acordeon.
    PROJECTION = :affine

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

    # FOV horizontal en grados. Controla el aplanado de la cuadricula,
    # desacoplado del pitch:
    #   55+   -> perspectiva plena (distorsion amplia, esquinas estiradas)
    #   15-30 -> FOV retro: tiles arriba y abajo casi del mismo tamano
    #   0     -> ortografico puro (cero distorsion horizontal)
    FOV           = 15

    # =======================================================================
    # RUBBER-HOSE (LEGACY - DESCARTADO)
    # Deformacion local elastica del suelo alrededor del jugador. Se descarto:
    # la sensacion 3D debe venir de la CONICA DE CAMARA FIJA global (sutil,
    # no mareante), no de una lente local que deformaba el muestreo.
    # =======================================================================
    RUBBER_ENABLED = false
    RUBBER_RADIUS  = 160
    RUBBER_FORCE   = 0.0

    # Zoom base (1.0 = escala natural del pixel art).
    DEFAULT_ZOOM  = 1

    # Altura del ojo (normalmente la altura de pantalla).
    DISTANCE_H    = Settings::SCREEN_HEIGHT

    # Color del cielo (visible si la camara baja demasiado).
    SKY_COLOR     = Color.new(104, 168, 224)

    # Color renderizado fuera de los limites del mapa.
    OUTSIDE_COLOR = Color.new(0, 0, 0)

    # =======================================================================
    # ALTURA POR TERRAIN TAG (extrusion de muros, en espacio de mundo)
    # Todo tile con priority > 0, o cuyo TERRAIN TAG este aqui, se extruye
    # hacia arriba ANTES de proyectar. La altura es en tiles de mundo (32px).
    #   1 -> muro de un terraplen (32px)
    #   2 -> arbol/poste (64px) que sobresale del suelo
    #   ... 
    # Como la extrucion sucede en coordenadas de mundo y luego se proyecta
    # con la MISMA conica que el suelo, los muros NO se separan del terreno
    # al mover la camara vertical. (El viejo "WALL_TERRAIN_TAG_PERSPECTIVE"
    # mezclaba dos proyecciones y producia el error; se sustituyo por esto.)
    WALL_TERRAIN_TAG_HEIGHT = {
      :HoneyTree => 2,
      :Mode7Tag  => 2,
      :None      => 1
    }
  end
end

# Registro del Terrain Tag propio del plugin (muros / billboards 2.5D).
GameData::TerrainTag.register({
  :id        => :Mode7Tag,
  :id_number => 19
})