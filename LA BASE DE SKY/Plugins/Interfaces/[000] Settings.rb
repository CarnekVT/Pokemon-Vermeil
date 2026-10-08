#===============================================================================
# Interfaces: pantallas hechas con datos, no con codigo.
#
# LA IDEA
#   Una pantalla del juego deja de ser una clase de Ruby con las coordenadas
#   escritas a mano y pasa a ser un fichero de datos en UI/<nombre>.json. Este
#   plugin es el motor que lo lee, lo pinta y responde al raton.
#
#   CONSECUENCIA IMPORTANTE: cambiar un diseño NO obliga a recompilar. Los
#   .json se leen cada vez que se abre la pantalla, asi que se guarda en el
#   editor y se vuelve a abrir. Solo hay que borrar PluginScripts.rxdata si se
#   toca el codigo de este plugin.
#
# COMO SE ABRE UNA PANTALLA
#   Desde un evento:                pbInterfaz("menu_misiones")
#   Desde el menu de pausa:         se registra en [006] Comandos.rb
#   Para probar sin montar nada:    menu de debug -> "Abrir una interfaz..."
#                                   (lista sola todos los UI/*.json)
#
# EL EDITOR
#   Es un mod de MakerStudio, en tools/makerstudio-uibuilder/. Se instala con
#   node tools/install-mod.js makerstudio-uibuilder
#===============================================================================

module Interfaces
  # Donde viven las pantallas. Una pantalla = un fichero .json.
  RUTA_PANTALLAS = "UI/"

  # Sube esto al tocar el MOTOR (este plugin). No hace falta subirlo al cambiar
  # un diseño, porque los diseños son datos y no se compilan.
  VERSION = "v10"

  # LA MARCA DE LA ESQUINA. APAGADA.
  #
  # Pintaba "INTERFACES v10  raton 0,9  lienzo 512x384" abajo a la derecha, y solo
  # con $DEBUG puesto. Hizo su trabajo: sin ella no habia forma de saber si el
  # juego habia recompilado (y se depuro dos veces a ciegas por no tenerla), y las
  # coordenadas del raton descartaron en dos segundos que los clics se
  # descuadraran al ampliar la pantalla.
  #
  # Ya no hace falta y estorba encima del diseño. Ponla a true el dia que algo
  # "siga igual" despues de tocar el motor: es la forma mas rapida de saber si
  # estas viendo el codigo nuevo o el viejo.
  MARCA_VERSION = false

  #-----------------------------------------------------------------------------
  # Lienzo.
  #-----------------------------------------------------------------------------
  # OJO: este juego corre a 512x384, no a los 640x480 de Essentials de serie
  # (Settings::SCREEN_WIDTH/HEIGHT y defScreenW/H de mkxp.json). El editor usa
  # este mismo tamaño de lienzo; si algun dia cambia la resolucion, los diseños
  # viejos quedan descolocados y hay que reabrirlos en el editor.
  #
  # No se leen de aqui en tiempo de ejecucion: la escena usa Graphics.width y
  # Graphics.height directamente. Esto es solo la referencia documentada.
  LIENZO_ANCHO = 512
  LIENZO_ALTO  = 384

  #-----------------------------------------------------------------------------
  # Valores por defecto de los elementos.
  #
  # Todo esto se puede sobreescribir en el .json elemento a elemento. Estan aqui
  # para que un elemento recien creado en el editor ya se vea sin tocar nada.
  #-----------------------------------------------------------------------------
  TEXTO_TAMANO      = 14
  TEXTO_COLOR       = "#FFFFFF"
  TEXTO_SOMBRA      = "#404040"
  TEXTO_ALINEACION  = "izquierda"

  # Cuanto se oscurece el mapa de detras (0 = nada, 255 = negro). Se puede poner
  # por pantalla con "oscurecer_mapa" en el .json.
  OSCURECER_DEFECTO = 0

  # Duracion por defecto de los efectos de entrada y salida, en segundos.
  ENTRADA_DURACION  = 0.25
  SALIDA_DURACION   = 0.18
  SUAVIZADO_DEFECTO = "suave"

  # Cuanto recorre un elemento que entra desde un lado, en pixeles. Se puede
  # poner por elemento con "distancia" dentro de "entrada".
  DESLIZA_DISTANCIA = 32

  #-----------------------------------------------------------------------------
  # Sonidos.
  #-----------------------------------------------------------------------------
  SE_ENCIMA = "GUI sel cursor"      # al pasar el raton por encima de un boton
  SE_PULSAR = "GUI sel decision"    # al pulsarlo
  SE_CERRAR = "GUI menu close"

  #-----------------------------------------------------------------------------
  # Rejilla del editor. Vive aqui para que el editor y el motor no discrepen.
  #-----------------------------------------------------------------------------
  REJILLA = 8

  #-----------------------------------------------------------------------------
  # COMO SE ABREN LAS INTERFACES
  #
  # Aqui NO hay ninguna lista que mantener. Cada diseño lleva dentro un bloque
  # "aperturas" que dice como se abre, y el plugin los escanea al arrancar. O
  # sea: se configura en el editor, con casillas, y no hay que tocar codigo.
  #
  # Antes esto era una lista MENU_PAUSA en este fichero, y estaba mal: obligaba a
  # editar Ruby para meter una pantalla en el menu del jugador, que es justo lo
  # que esta herramienta tiene que evitar.
  #
  # Las cuatro maneras de abrir una interfaz:
  #
  #   1. MENU DE PAUSA     "aperturas": { "menu_pausa": true, "orden": 35 }
  #   2. UNA TECLA         "aperturas": { "tecla": "Q" }
  #   3. UN INTERRUPTOR    "aperturas": { "interruptor": "misiones" }
  #      DE INTERFAZ       y un boton con la accion interruptor_interfaz
  #   4. DESDE UN EVENTO   Comando de Script:  pbInterfaz("menu_misiones")
  #
  # Ojo con el 1 y el 2: se leen al ARRANCAR el juego. Cambiar el diseño no pide
  # recompilar, pero si cambias COMO SE ABRE hay que reiniciar el juego una vez.
  #-----------------------------------------------------------------------------

  # Ordenes del menu de pausa de Essentials, para no pisarlos sin querer:
  # Pokedex 10, Pokemon 20, Mochila 30, Mapa/Pokegear 40, Ficha 50, Guardar 60,
  # Opciones 70, Debug 80, Salir 90. Los numeros de en medio (35, 45...) quedan
  # libres para las tuyas.
  ORDEN_DEFECTO = 35

  # Teclas que NO se pueden usar para abrir una interfaz, porque ya las usa el
  # juego o el motor y el resultado seria un lio.
  TECLAS_PROHIBIDAS = ["Z", "X", "C", "A", "S", "D", "RETURN", "ESCAPE", "SPACE",
                       "UP", "DOWN", "LEFT", "RIGHT", "LSHIFT", "RSHIFT",
                       "LCTRL", "RCTRL", "F1", "F5", "F8", "F12"]

  # Tope de saltos seguidos entre pantallas. No es para el jugador (cada salto lo
  # da el pulsando un boton) sino para cazar dos pantallas que se llaman la una a
  # la otra por un interruptor mal puesto, que si no dejaria el juego colgado.
  MAX_SALTOS = 50

  #-----------------------------------------------------------------------------
  # LAS PANTALLAS QUE YA TRAE EL JUEGO, CON SU INTERRUPTOR
  #
  # Estas no las hicimos nosotros: son las de Essentials (la Mochila, el equipo,
  # la Pokedex...). Aqui se les da un interruptor de interfaz a cada una, para
  # que se puedan usar igual que las tuyas:
  #
  #   - Un boton tuyo con el interruptor "equipo" abre el equipo del juego.
  #
  #   - Y AL REVES, que es lo bueno: si haces una pantalla tuya y le pones el
  #     interruptor "equipo" en sus aperturas, LA TUYA GANA. A partir de ahi ese
  #     interruptor abre la tuya, y ademas la entrada del menu de pausa tambien
  #     abre la tuya. Asi se reemplaza una pantalla del juego sin ir buscando
  #     todos los sitios desde los que se abria.
  #
  # La regla es una sola: MANDA LA TUYA SI EXISTE, y si no, la del juego.
  #
  # :menu es la clave con la que Essentials registro esa entrada en el menu de
  # pausa; hace falta para poder reemplazarla. :accion es el metodo de
  # [004] Acciones.rb que abre la pantalla original.
  #-----------------------------------------------------------------------------
  INTEGRADAS = {
    "mochila"  => { :titulo => "Mochila",           :menu => :bag,          :accion => "abrir_mochila"  },
    "equipo"   => { :titulo => "Equipo Pokemon",    :menu => :party,        :accion => "abrir_equipo"   },
    "pokedex"  => { :titulo => "Pokedex",           :menu => :pokedex,      :accion => "abrir_pokedex"  },
    "guardar"  => { :titulo => "Guardar partida",   :menu => :save,         :accion => "abrir_guardar"  },
    "ficha"    => { :titulo => "Ficha de entrenador", :menu => :trainer_card, :accion => "abrir_ficha"  },
    "mapa"     => { :titulo => "Mapa de la region", :menu => :town_map,     :accion => "abrir_mapa"     },
    "pokegear" => { :titulo => "Pokegear",          :menu => :pokegear,     :accion => "abrir_pokegear" }
  }

  #-----------------------------------------------------------------------------
  # Colores del aviso de error.
  #
  # Un .json roto NO revienta el juego: se pinta este cartel con el fichero, la
  # linea y el fallo. Un error silencioso en una pantalla de datos es imposible
  # de encontrar para quien no programa, asi que se ve y se lee.
  #-----------------------------------------------------------------------------
  C_ERROR_FONDO = Color.new(28, 12, 12, 235)
  C_ERROR_BORDE = Color.new(226, 66, 52)
  C_ERROR_TEXTO = Color.new(250, 226, 226)
  C_ERROR_TENUE = Color.new(198, 150, 150)

  # Color de la marca de version en desarrollo.
  C_VERSION = Color.new(255, 255, 255, 90)
end
