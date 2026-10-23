#===============================================================================
# Visual 2.5D HD - Ajustes
#-------------------------------------------------------------------------------
# El plugin no toca la jugabilidad: proyecta el mapa que ya existe sobre un plano
# en perspectiva y levanta sobre el los elementos verticales.
#
#   - El suelo se proyecta con punto de fuga: las filas de arriba (las lejanas)
#     se ven mas pequenas y el mapa se estrecha hacia el fondo. Toda la escena
#     usa la misma proyeccion, asi que no aparecen cortes entre tiles.
#   - Los tiles con prioridad > 0 estan "de pie" sobre el suelo: la prioridad es
#     su altura en tiles, asi que se levantan sobre su casilla de apoyo en lugar
#     de quedarse pegados al fondo plano.
#
# El angulo de la camara y la distancia de dibujado se ajustan en marcha con el
# script  pbVisual25DMenu  (o desde Depuracion -> Campo -> Visual 2.5D HD), y se
# guardan en la partida.
#===============================================================================
module Visual25D
  module Config
    # Efecto activo al arrancar el juego.
    ENABLED = true
    # Interruptor de juego que apaga el efecto mientras este ON (0 = ninguno).
    # Util para cuevas, interiores concretos o cinematicas.
    DISABLE_SWITCH = 0

    # Duracion por defecto (segundos) del fundido al encender/apagar con
    # pbVisual25DToggleSmooth / cambiar_modo_suave.
    TRANSITION_SECONDS = 1.0
    # Sin tecla por defecto: no se apropia del turbo/movimiento de Vermeil.
    # Alternar desde menu de opciones/debug o asignar manualmente una tecla libre.
    HOTKEY = nil

    #---------------------------------------------------------------------------
    # CAMARA
    #---------------------------------------------------------------------------
    # Inclinacion de la camara, en grados. A 0 se mira desde arriba del todo y no
    # hay perspectiva. Al inclinarla, la fila del jugador conserva su tamano y lo
    # que se reparte es el resto: el fondo se encoge (y por tanto se ve mas lejos)
    # y el primer plano se agranda.
    TILT_DEGREES = 27
    MAX_TILT_DEGREES = 50

    # Modelo de proyeccion del suelo (solo Ruby; sin Model3D del MK).
    #   :classic — perfil conservador y economico, preset compatible 2.5D.
    #   :camera  — escala ~ 1/profundidad + FOV. v3.0.43: pitch soft-saturado
    #              (antes tan(tilt)>1 → depth negativa → shape~6x, look roto).
    #              Probar en menú debug; default sigue classic.
    # raw_unproject dual (log + tramo lineal bajo clamp).
    PROJECTION_MODEL = :classic
    # FOV vertical: suaviza la curva :camera (ancho = menos drama).
    CAMERA_FOV = 55

    # Cuanto converge el mapa a lo ancho, respecto a lo que se acorta en
    # profundidad. Es lo que marca el punto de fuga, pero tambien lo que separa
    # lateralmente un elemento alto de la casilla que ocupa: a 1.0 un edificio de
    # tres pisos junto al borde de la pantalla se despega bastante de su base.
    # Entre 0.2 y 0.4 da profundidad sin que se noten esas separaciones.
    VANISHING_STRENGTH = 0.25

    # El suelo es un trapecio por fila. Los vecinos encajan (misma arista),
    # pero el borde vertical es recto y la escala es curva: se ve un quiebro
    # cada 32 px. Partir el tile en franjas mete un vertice en esa curva.
    #   1 = un trapecio (como antes).  2 = dos mitades.  4 = cuatro franjas.
    # Solo suelo de prioridad 0, y solo si el binario tiene Sprite#taper.
    # Una fila con un tile transparente (agua, cristal, o el cuerpo del
    # grafico con alpha) va entera en un solo trapecio. Partir solo ese
    # tile y dejar el de al lado en mitades abre un hueco negro en la junta.
    # Si el FPS baja, vuelve a 1.
    GROUND_SLICES = 1

    # Suelo opaco de una fila de pantalla = un trapecio, no un sprite por
    # casilla. Apagado: al ocultar el tile antes de que la fila cubra el
    # hueco salen barras negras. El camino tile a tile es el que se ve.
    if const_defined?(:ROW_BATCH)
      remove_const(:ROW_BATCH)
    end
    ROW_BATCH = false

    # Caída del horizonte, en píxeles, en el borde de arriba de la pantalla.
    # 0 = suelo como hasta 3.2. El centro (el jugador) no se mueve.
    HORIZON_CURVE = 0

    # Desenfoque de las franjas de arriba y de abajo. Apagado: sin shader
    # solo emborrona una captura vieja y mancha el suelo.
    if const_defined?(:BAND_BLUR)
      remove_const(:BAND_BLUR)
    end
    BAND_BLUR = false
    BAND_BLUR_OPACITY = 110
    if const_defined?(:CONTACT_SHADOW)
      remove_const(:CONTACT_SHADOW)
    end

    # Zoom de la camara sobre el mapa, en porcentaje. 100 = encuadre original,
    # menos de 100 aleja la camara y se ve mas mapa.
    CAMERA_ZOOM = 100
    MAX_CAMERA_ZOOM = 250

    # Hasta donde se puede alejar la camara. Tanto alejar como inclinar exigen
    # dibujar mas mapa del que cabe en pantalla, y el motor solo reserva las
    # casillas justas (17 columnas para 16 visibles), asi que el plugin le amplia
    # la rejilla. El margen se recalcula con los valores en uso, de modo que solo
    # se paga rendimiento mientras la camara este lejos o muy inclinada.
    #
    # Al alejarse cerca del borde de un mapa sin conexiones se vera el vacio de
    # detras, igual que en cualquier camara que se separe del terreno.
    MIN_CAMERA_ZOOM = 60

    # Tope de casillas de mas que se pueden anadir a cada lado de la rejilla.
    # Es el freno de rendimiento: cerca del horizonte la perspectiva pediria
    # infinitas filas, asi que al llegar a este tope se deja de recentrar la
    # camara en el jugador antes que dejar los bordes sin dibujar.
    MAX_MARGIN_COLUMNS = 10
    MAX_MARGIN_ROWS = 10

    # Cuanto se levanta un bordillo por cada tile de altura, como fraccion del
    # alto de la fila en la que se apoya.
    #
    # Al ser una fraccion de la fila, un bordillo ocupa siempre la misma porcion
    # de suelo este donde este en la pantalla: cerca del jugador sube muchos
    # pixeles y junto al horizonte pocos, pero lo mismo en proporcion. Antes se
    # sacaba de lo que mide un elemento de pie menos lo que mide la fila tumbada,
    # y en el primer plano esa resta se volvia negativa: los bordillos se
    # desinflaban hasta quedarse planos segun el jugador se acercaba a ellos.
    #
    # Tambien es lo que fija el escalonado del vertice: con un desnivel de N
    # tiles, dos columnas vecinas ensenan filas distintas a lo largo de
    # N * este valor filas. Cuanto mas alto, mas se nota ese dentado.
    WALL_STEP_RATIO = 0.35
    # Pixeles de solape vertical en casillas lifted / con escalon lateral.
    # Esquinas del desnivel (tag 19) dejan huecos negros con 1 px; 2 tapa el
    # redondeo de project_x/y entre columnas con distinto lift.
    WALL_EDGE_SEAL = 2
    # Pixeles de solape horizontal (esquinas / dentado entre columnas).
    WALL_SIDE_SEAL = 2
    # Extra horizontal solo en casilla lifted+lateral (esquina de bordillo).
    # 0 = off. 1 tapa el triangulo negro tipico sin engordar todo el muro.
    WALL_CORNER_EXTRA = 1
    # Sin seal en terreno can_surf (agua). El solape apila alpha y marca la
    # rejilla; las aristas compartidas (sin seal) ya coinciden tile a tile.
    WALL_SEAL_SKIP_SURF = true
    # Por debajo de esto el lift del suavizado se ignora: si no, el spread deja
    # micro-deformaciones en agua/suelo lejos del bordillo y salen puntos negros.
    LIFT_EPSILON = 0.12

    #---------------------------------------------------------------------------
    # ELEMENTOS VERTICALES
    #-------------------------------------------------------------------------
    # La prioridad de un tile es su altura sobre el suelo: la casilla de apoyo de
    # un tile de prioridad p es la que esta p filas mas abajo. Todos los tiles de
    # una columna tienen que apuntar a esa misma casilla, asi que hay que
    # numerarlos 1,2,3... de abajo arriba, empezando por 1 en la base.
    #
    # Si a la base de un arbol se le deja prioridad 0 y a la copa se le pone 2,
    # el plugin situa la copa dos filas mas abajo de donde se apoya y queda
    # flotando. Se numera la base con 1 y se arregla.
    #---------------------------------------------------------------------------
    # Cuanto se "ponen de pie" los elementos verticales al inclinar la camara.
    # El suelo se acorta con la inclinacion, pero un elemento vertical esta de
    # cara a la camara y no deberia acortarse: cuanto mas baja la camara, mas
    # alto se ve. A 0 se quedan tumbados sobre el suelo como hasta ahora, a 1 se
    # levantan del todo (1/cos del angulo, un 56% mas altos a 50 grados).
    # 0.4: paredes/arboles dejan de verse planos a TILT_DEGREES 50.
    VERTICAL_GAIN = 0.35

    # Pixeles que se levanta un tile por cada nivel de prioridad. Es la
    # exageracion de altura, aparte de lo que ya sube por el angulo. A 0 los
    # elementos verticales solo crecen lo que les toca por la inclinacion.
    TILE_LIFT = 0
    # Prioridad maxima considerada. RMXP nativo 0-5; MakerStudio puede ir mas
    # alto. Todo lo que pase de esto se clampea (altura/Z como si fuera este tope).
    MAX_PRIORITY = 12
    # Cuanto se levantan los personajes respecto a lo que se levantan las
    # paredes. Conviene dejarlo por debajo de 1: si un personaje creciera igual
    # que un edificio, su cabeza se meteria en la fila de arriba y los tiles con
    # prioridad de esa fila lo taparian. A 0 no se estiran nada.
    CHARACTER_GAIN = 0.4

    # Cuanto se inclina una columna hacia el punto de fuga. A 0 toda la columna
    # usa la escala de su base y sale recta, que es lo que evita que se despegue
    # de la casilla que ocupa. Al subirlo, cada tramo usa la escala de la altura
    # a la que se dibuja: la parte alta se abre hacia fuera y la pared se inclina
    # como en una camara de verdad, dejando ver sus caras laterales.
    #
    # A cambio aparecen escalones de uno o dos pixeles entre tramos apilados. Se
    # sube junto con VANISHING_STRENGTH: con la convergencia alta y esto a 0 las
    # columnas se despegan de su base, y con los dos altos la perspectiva es
    # mucho mas fuerte pero se notan mas los escalones.
    COLUMN_LEAN = 0.0

    #---------------------------------------------------------------------------
    # PAREDES FRONTALES
    #-------------------------------------------------------------------------
    # Un solo terrain tag, en los tiles de pared que miran a la camara: los que
    # tienen terreno alto por arriba y terreno bajo por abajo. Con eso esa pared
    # se dibuja de pie en vez de tumbada sobre el suelo, que es lo que hace que
    # el mapa deje de verse plano al alejar la camara.
    #
    # Lift deforma el suelo por aristas compartidas (sin rajas). pri1 en zona
    # lifted comparte caja con pri0. Laterales ciegos: INTERIOR_WALL_TAG.

    #
    # Una pared pintada con dos tiles se levanta entera y apilada, sin hacer nada
    # especial: solo hay que marcarlos los dos. Si en una columna hay tres o mas
    # seguidos se entiende que son dos bordillos pegados y cada uno se levanta
    # por su cuenta; para separarlos se compara hasta donde llega cada fila en
    # horizontal.
    #---------------------------------------------------------------------------
    WALLS = true
    WALL_TERRAIN_TAG = :Cliff
    # Alto maximo de un bordillo, en tiles.
    MAX_WALL_HEIGHT = 2
    # Cuanto se difumina el levantamiento a lo largo de la fila. Es lo que
    # convierte el borde de arriba de la pared en una diagonal en vez de una
    # escalera, y lo que la funde con el suelo de al lado en sus extremos. Cada
    # pasada lo reparte una casilla mas a cada lado. A 0 no hay suavizado y la
    # pared se levanta de golpe.
    WALL_SMOOTHING = 5
    # Suavizado N-S (ademas del E-O). Rampa hacia el Cliff menos a escalones.
    # No usa angle ni media de vertices (eso rompia esquinas).
    WALL_SMOOTH_VERTICAL = true
    # Cuanto del lift se reparte hacia arriba (meseta). El desnivel lo absorbe
    # el terreno de encima encogiendose en pantalla (aristas compartidas).
    WALL_RISE = 0.78
    # OFF: angle en sprites abre huecos negros en esquinas. No activar.
    WALL_TILE_TILT = false
    WALL_TILE_TILT_MAX = 16
    WALL_TILE_TILT_MIN_PX = 2

    # CUANTO SE LEVANTA una pared lo manda VERTICAL_GAIN, no un ajuste de aqui:
    # la casilla ya ocupa su fila del plano del suelo, asi que lo que gana al
    # ponerse de pie es lo que mide de pie menos lo que mediria tumbada. Con
    # VERTICAL_GAIN a 0.4 son unos 6 px por tile de pared; subiendolo a 0.8-1.0
    # las paredes se ven bastante mas altas.

    #---------------------------------------------------------------------------
    # PAREDES INTERIORES (solo visibles en 2.5D)
    #-------------------------------------------------------------------------
    # Tag 20 = tapa del muro interior (casilla sin cuerpo pri, p.ej. el borde
    # top-down de un pasillo). La tapa se dibuja como un tile de prioridad h.
    # La cara lateral NO sale de la proyeccion: en pitch sin yaw queda de canto.
    # Es una franja de INTERIOR_SIDE_WIDTH px, hacia dentro del muro, con la
    # pila de textura (zocalo abajo, remate arriba). Sin angle.
    INTERIOR_WALLS = true
    INTERIOR_WALL_TAG = :InteriorWall
    # Alto (tiles) si no hay cuerpo vecino que marque la cota.
    INTERIOR_WALL_HEIGHT = 3
    # Color si no hay cuerpo de muro usable como textura.
    INTERIOR_WALL_FALLBACK = Color.new(72, 64, 56)
    # Columnas a los lados donde buscar pila de textura si la propia no tiene.
    INTERIOR_SRC_RANGE = 6
    # No usar como textura capas con pri > esto (pri 4–5 = techo/borde).
    INTERIOR_SRC_PRI_MAX = 3
    # Grosor del muro interior en px (a escala 1; encoge con la fila).
    #
    # Es un grosor DECIDIDO, no derivado: en esta proyeccion (pitch sin yaw) una
    # cara que mira al este/oeste queda de canto. Medido con tilt 50 / zoom 90:
    # un tile pri sube ~4 px por nivel sobre su fila y lo elevado se separa ~1 px
    # por nivel a dos casillas, asi que la cara "real" seria de 3 px. Esta franja
    # la pinta con un ancho fijo para que el pasillo lea como un cubo.
    INTERIOR_SIDE_WIDTH = 10

    #---------------------------------------------------------------------------
    # TILES SHELF (tapa tumbada a la base de su prioridad)
    #-------------------------------------------------------------------------
    # El tag 21 solo marca "esto va tumbado" (esa capa). La cota es la
    # prioridad del tile: se dibuja plano en la BASE de esa altura, donde
    # iria el canto bajo del mismo tile en vertical.
    #   pri 1 + 21 → ras de suelo
    #   pri 5 + 21 → cierra con el vertical pri 4
    # Ejemplo cilindro: cara pri 1-4 sin 21; disco pri 5 + 21.
    SHELF_ENABLED = true
    SHELF_TAG = :Shelf

    #---------------------------------------------------------------------------
    # INTEGRACION CON MAKERSTUDIO
    #---------------------------------------------------------------------------
    # Sus capas extendidas se proyectan siempre; sin eso se dibujarian planas
    # sobre un suelo en perspectiva. Sus sombras son bitmaps de varias casillas y
    # no se pueden proyectar bien con un solo sprite, asi que solo se recolocan.
    # Si aparecen manchas oscuras raras por el mapa, ponlo a false para descartar
    # que vengan de aqui.
    PROJECT_SHADOWS = false
    # Idle: no rebuild MS del pool extended. Solo autotiles/tono.
    # Vale con 2.5D ON y OFF (en OFF el rebuild era cada frame). false si
    # tiles MS “congelados”.
    MS_EXT_IDLE_SKIP = true
    # Scroll sub-tile (mismo dx_tile/dy_tile): sin rebuild MS. 2.5D ON proyecta;
    # 2.5D OFF solo mueve x/y (+ Z overhead). N/S usa project_tile (no y_flat)
    # para pri>0; rebuild solo al cruzar casilla (rebuild cada pixel hitchaba).
    MS_EXT_PIXEL_SCROLL = true
    # E/O: si stamp/fila cacheados, solo recalcula X (no Z). Z = f(row,pri)
    # estable en scroll horizontal. Al reaplicar hd25_ext_pz hay que marcar
    # hd25_z_pre_raised (si no, TileSprite#z= dobla Z_LIFT). false = siempre
    # apply_ext_sprite_z.
    MS_EXT_SKIP_Z_ON_X_SCROLL = true

    #---------------------------------------------------------------------------
    # ATMOSFERA
    #---------------------------------------------------------------------------
    # Neblina de distancia en la parte alta de la pantalla, que es justo donde
    # esta el punto de fuga. Refuerza mucho la sensacion de profundidad.
    HAZE = false
    HAZE_COLOR = Color.new(188, 212, 240)
    HAZE_OPACITY = 48
    # Porcion de la pantalla que cubre, de arriba hacia abajo.
    HAZE_HEIGHT = 0.55
    # Cuanto mayor, mas rapido se desvanece hacia abajo.
    HAZE_FALLOFF = 1.8
    # Solo en mapas marcados como exteriores.
    HAZE_OUTDOOR_ONLY = true

    # Franja de niebla en primer plano. Junto con la de arriba imita el desenfoque
    # de maqueta ("tilt-shift") de los mods 2.5D: al lavar el fondo y el primer
    # plano, la banda central que queda limpia hace que el mapa parezca un
    # diorama en miniatura.
    NEAR_HAZE = false
    NEAR_HAZE_OPACITY = 26
    NEAR_HAZE_HEIGHT = 0.28
    # Falloff propio del primer plano (antes compartia HAZE_FALLOFF).
    # Mas alto = franja mas corta/dura; 1.2-1.6 deja banda central limpia.
    NEAR_HAZE_FALLOFF = 1.4

    # Oscurecido suave de los bordes de la pantalla.
    VIGNETTE = false
    VIGNETTE_COLOR = Color.new(0, 0, 0)
    VIGNETTE_OPACITY = 70
    # Grosor del degradado respecto al lado corto de la pantalla.
    VIGNETTE_SIZE = 0.3
    # Curva del vineteado (antes fijo 2.0). Mas alto = borde mas duro.
    VIGNETTE_FALLOFF = 2.0

    # Luz direccional barata (idea light_*/ambient de Model3D): sesga opacity
    # de neblina lejana vs primer plano, y bordes L/R de la vineta (DIR_X).
    # Sin shaders. 0 strength = off.
    LIGHT_BIAS = true
    LIGHT_DIR_X = 0.0
    LIGHT_DIR_Y = -1.0
    LIGHT_STRENGTH = 0.12
    LIGHT_AMBIENT = 0.92

    # Multiplica opacidad de neblina con el tilt (0 = off). Sin rebuild Bitmap:
    # solo opacity. A tilt max + blend 1 → opacity *= (1 + este valor).
    HAZE_TILT_LINK = 0.25

    # Z del viewport de neblina y vineteado. Por encima del mapa (0) y por
    # debajo de las imagenes (200) y del flash de pantalla (500).
    OVERLAY_Z = 100

    # Etiqueta "Modo 2D" / "Modo 2.5D" abajo a la izquierda (overworld).
    # Entra/sale deslizándose por la izquierda; permanece durante el fundido.
    MODE_LABEL = false
    MODE_LABEL_PAD_X = 8
    MODE_LABEL_PAD_Y = 6
    MODE_LABEL_SLIDE_SECONDS = 0.28

    # Probe FPS (1 echoln/seg). true = ON al cargar cualquier mapa.
    # Menu: Visual 2.5D HD: probe FPS. Solo echoln (nunca puts).
    PERF_PROBE_AUTO = false
    # Mapas donde el probe se enciende solo al entrar (y se apaga al salir).
    # [] = off. Ej. [205] para Bosque Lumirinto.
    PERF_PROBE_MAPS = []
  end
end



def cambiar_modo
  Visual25D.enabled = !Visual25D.enabled
end

# Toggle 2.5D con fundido (~Config::TRANSITION_SECONDS). Para eventos/cinemática.
# duration opcional en segundos (p.ej. cambiar_modo_suave(0.5)).
def cambiar_modo_suave(duration = nil)
  Visual25D.toggle_smooth(duration)
end

def pbVisual25DToggleSmooth(duration = nil)
  Visual25D.toggle_smooth(duration)
end

# Encender/apagar con fundido (sin invertir). to_on: true/false.
def pbVisual25DSetSmooth(to_on, duration = nil)
  Visual25D.set_smooth(to_on, duration)
end