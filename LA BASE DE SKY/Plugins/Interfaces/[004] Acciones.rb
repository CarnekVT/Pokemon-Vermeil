#===============================================================================
# Acciones: lo que pasa al pulsar un boton.
#
# Cada accion del diseño es un objeto con un "tipo" y lo que ese tipo necesite:
#
#   { "tipo": "cerrar" }
#   { "tipo": "ir_a_interfaz", "interfaz": "menu_misiones" }
#   { "tipo": "interruptor_interfaz", "nombre": "misiones" }
#   { "tipo": "abrir_interfaz", "interfaz": "aviso_encima" }
#   { "tipo": "abrir_mochila" }
#   { "tipo": "interruptor", "numero": 42, "valor": true }
#   { "tipo": "variable", "numero": 7, "valor": 1, "operacion": "sumar" }
#   { "tipo": "sonido", "nombre": "GUI sel decision" }
#   { "tipo": "script", "codigo": "pbMessage(_INTL(\"hola\"))" }
#
# OJO CON LA DIFERENCIA, QUE ES LA QUE MAS SE CONFUNDE:
#
#   ir_a_interfaz          cierra esta y abre la otra. Es lo normal en un menu.
#   interruptor_interfaz   lo mismo, pero por nombre: el boton no lleva escrito
#                          el fichero, asi que puedes cambiar que pantalla
#                          responde sin tocar el boton. Y ademas un evento del
#                          mapa puede activar el mismo interruptor.
#   abrir_interfaz         abre la otra ENCIMA y al cerrarla vuelves a esta. Para
#                          un aviso o una confirmacion, no para navegar.
#
# Los interruptores de interfaz NO son los interruptores de Essentials. Tienen
# nombre ("misiones") en vez de numero, y viven en su propio sitio para no
# ensuciar los del juego ni chocar con los que usan los eventos. Para tocar un
# interruptor DEL JUEGO esta la accion "interruptor", que es otra cosa.
#
# LAS INVOCACIONES DE LAS PANTALLAS DEL JUEGO NO SON INVENTADAS: estan copiadas
# de las entradas del menu de pausa de Essentials (MenuHandlers.add(:pause_menu,
# ...)), que es el sitio donde el propio motor abre la Mochila, el equipo y las
# demas. Si algun dia Essentials las cambia, es ahi donde hay que mirar.
#
# "script" es la valvula de escape: para todo lo que no previ, se escribe Ruby y
# ya. Un fallo dentro del script se avisa, no tira la pantalla.
#===============================================================================

module Interfaces
  module Acciones
    # Cuantas interfaces pueden estar abiertas una encima de otra. Es un tope de
    # seguridad: si una pantalla A abre la B y la B abre la A, sin esto el juego
    # se queda sin memoria de pila y se cierra sin decir nada.
    PROFUNDIDAD_MAXIMA = 4

    TIPOS = ["cerrar", "ir_a_interfaz", "interruptor_interfaz", "abrir_interfaz",
             "abrir_mochila", "abrir_equipo", "abrir_pokedex", "abrir_guardar",
             "abrir_ficha", "abrir_mapa", "abrir_pokegear",
             "interruptor", "variable", "sonido", "script", "nada"]

    module_function

    #---------------------------------------------------------------------------
    # Ejecuta una accion. Devuelve :cerrar si la pantalla tiene que cerrarse,
    # o nil para seguir abierta.
    #---------------------------------------------------------------------------
    def ejecutar(accion, escena)
      return nil if !accion.is_a?(Hash)
      tipo = accion["tipo"].to_s

      case tipo
      when "nada", ""
        return nil

      when "cerrar"
        return :cerrar

      #-------------------------------------------------------------------------
      # IR A OTRA PANTALLA. La manera normal de moverse por un menu: se cierra
      # esta y se abre la otra AL MISMO NIVEL, no una encima de otra. Ir y volver
      # cien veces no apila cien pantallas.
      #-------------------------------------------------------------------------
      when "ir_a_interfaz"
        destino = accion["interfaz"].to_s
        if destino.empty?
          escena.avisar_en_pantalla("un boton dice \"ir a otra pantalla\" pero no dice a cual")
          return nil
        end
        if !Lector.existe?(destino)
          escena.avisar_en_pantalla("no existe la pantalla \"#{destino}\"")
          return nil
        end
        escena.ir_a = destino
        return :cerrar

      #-------------------------------------------------------------------------
      # INTERRUPTOR DE INTERFAZ. Son NUESTROS: tienen nombre y no son los
      # interruptores de Essentials. Se eligio asi a proposito para no ensuciar
      # los del juego ni chocar con los que usan los eventos.
      #
      # Al activarlo, la pantalla que declare ese interruptor en su bloque
      # "aperturas" se abre, y esta se cierra. Sirve tambien desde un evento del
      # mapa, porque el vigilante de [006] Comandos.rb mira los mismos.
      #
      # La ventaja de que sea con nombre y no directo: el boton no lleva escrito
      # el nombre del fichero, asi que puedes cambiar que pantalla responde al
      # interruptor sin tocar el boton.
      #-------------------------------------------------------------------------
      when "interruptor_interfaz"
        nombre = accion["nombre"].to_s
        if nombre.empty?
          escena.avisar_en_pantalla("un boton activa un interruptor de interfaz sin nombre")
          return nil
        end
        tipo_destino, destino = Lector.destino_de_interruptor(nombre)
        case tipo_destino
        when :interfaz
          # Una pantalla nuestra: se cierra esta y se abre aquella.
          escena.ir_a = destino
          return :cerrar
        when :integrada
          # Una del juego (Mochila, equipo...). Se abre y al cerrarla se vuelve
          # aqui, porque esas pantallas no saben "navegar", tienen su propio
          # bucle y su propia salida.
          escena.con_la_interfaz_oculta { send(Interfaces::INTEGRADAS[destino][:accion]) }
          return nil
        else
          escena.avisar_en_pantalla(
            "el interruptor \"#{nombre}\" no lleva a ninguna parte. " \
            "Abre la pantalla que quieres que salga y ponle ese interruptor en \"Como se abre en el juego\"")
          return nil
        end

      #-------------------------------------------------------------------------
      # ABRIR ENCIMA. Esta se queda debajo y se vuelve a ella al cerrar la otra.
      # Es para un aviso o un "¿seguro?", no para navegar: para eso esta
      # ir_a_interfaz, que no apila.
      #-------------------------------------------------------------------------
      when "abrir_interfaz"
        nombre = accion["interfaz"].to_s
        if nombre.empty?
          escena.avisar_en_pantalla("una accion de tipo abrir_interfaz no dice cual")
          return nil
        end
        if !Lector.existe?(nombre)
          escena.avisar_en_pantalla("no existe la pantalla \"#{nombre}\"")
          return nil
        end
        if escena.profundidad >= PROFUNDIDAD_MAXIMA
          escena.avisar_en_pantalla(
            "no abro \"#{nombre}\": ya hay #{PROFUNDIDAD_MAXIMA} pantallas una encima " \
            "de otra. Si lo que querias era ir a otra pantalla, usa \"Ir a otra pantalla\", " \
            "que cierra esta en vez de apilarla")
          return nil
        end
        Interfaces.abrir(nombre, escena.profundidad + 1)
        return nil

      # Todas escondiendo antes la interfaz: son pantallas que ocupan todo y
      # verla asomar por detras queda fatal.
      when "abrir_mochila"   then escena.con_la_interfaz_oculta { abrir_mochila }  ; return nil
      when "abrir_equipo"    then escena.con_la_interfaz_oculta { abrir_equipo }   ; return nil
      when "abrir_pokedex"   then escena.con_la_interfaz_oculta { abrir_pokedex }  ; return nil
      when "abrir_guardar"   then escena.con_la_interfaz_oculta { abrir_guardar }  ; return nil
      when "abrir_ficha"     then escena.con_la_interfaz_oculta { abrir_ficha }    ; return nil
      when "abrir_mapa"      then escena.con_la_interfaz_oculta { abrir_mapa }     ; return nil
      when "abrir_pokegear"  then escena.con_la_interfaz_oculta { abrir_pokegear } ; return nil

      when "interruptor"
        n = accion["numero"].to_i
        if n <= 0
          escena.avisar_en_pantalla("la accion interruptor necesita un \"numero\" mayor que 0")
          return nil
        end
        valor = accion["valor"]
        $game_switches[n] = if valor.to_s == "cambiar"
                              !$game_switches[n]     # el contrario del que hubiera
                            else
                              !!valor
                            end
        $game_map.need_refresh = true if $game_map
        return nil

      when "variable"
        n = accion["numero"].to_i
        if n <= 0
          escena.avisar_en_pantalla("la accion variable necesita un \"numero\" mayor que 0")
          return nil
        end
        valor = accion["valor"]
        if accion["operacion"].to_s == "sumar"
          $game_variables[n] = $game_variables[n].to_i + valor.to_i
        else
          $game_variables[n] = valor
        end
        $game_map.need_refresh = true if $game_map
        return nil

      when "sonido"
        nombre = accion["nombre"].to_s
        pbSEPlay(nombre) if !nombre.empty?
        return nil

      when "script"
        codigo = accion["codigo"].to_s
        return nil if codigo.empty?
        begin
          # Se evalua con este binding para que el codigo pueda usar `escena`.
          eval(codigo, binding)
        rescue StandardError, SyntaxError => e
          escena.avisar_en_pantalla("el script fallo: #{e.message}")
        end
        return nil

      else
        escena.avisar_en_pantalla(
          "no conozco la accion #{accion["tipo"].inspect}. Las que hay: #{TIPOS.join(", ")}")
        return nil
      end
    end

    #---------------------------------------------------------------------------
    # Las pantallas del juego. Todas van envueltas en pbFadeOutIn, que es como
    # las abre el menu de pausa.
    #---------------------------------------------------------------------------
    def abrir_mochila
      pbFadeOutIn do
        escena = PokemonBag_Scene.new
        pantalla = PokemonBagScreen.new(escena, $bag)
        pantalla.pbStartScreen
      end
    end

    def abrir_equipo
      pbFadeOutIn do
        escena = PokemonParty_Scene.new
        pantalla = PokemonPartyScreen.new(escena, $player.party)
        pantalla.pbPokemonScreen
      end
    end

    def abrir_pokedex
      # Con varias regiones hay que pasar antes por el menu de dexes, igual que
      # hace el menu de pausa.
      if Settings::USE_CURRENT_REGION_DEX || $player.pokedex.accessible_dexes.length == 1
        if !Settings::USE_CURRENT_REGION_DEX
          $PokemonGlobal.pokedexDex = $player.pokedex.accessible_dexes[0]
        end
        pbFadeOutIn do
          escena = PokemonPokedex_Scene.new
          pantalla = PokemonPokedexScreen.new(escena)
          pantalla.pbStartScreen
        end
      else
        pbFadeOutIn do
          escena = PokemonPokedexMenu_Scene.new
          pantalla = PokemonPokedexMenuScreen.new(escena)
          pantalla.pbStartScreen
        end
      end
    end

    def abrir_guardar
      # Guardar NO va con pbFadeOutIn: la pantalla de guardado hace su propio
      # fundido y anidarlos deja la pantalla en negro.
      escena = PokemonSave_Scene.new
      pantalla = PokemonSaveScreen.new(escena)
      pantalla.pbSaveScreen
    end

    def abrir_ficha
      pbFadeOutIn do
        escena = PokemonTrainerCard_Scene.new
        pantalla = PokemonTrainerCardScreen.new(escena)
        pantalla.pbStartScreen
      end
    end

    def abrir_mapa
      pbFadeOutIn do
        escena = PokemonRegionMap_Scene.new(-1, false)
        pantalla = PokemonRegionMapScreen.new(escena)
        ret = pantalla.pbStartScreen
        $game_temp.fly_destination = ret if ret
      end
      pbFlyToNewLocation
    end

    def abrir_pokegear
      pbFadeOutIn do
        escena = PokemonPokegear_Scene.new
        pantalla = PokemonPokegearScreen.new(escena)
        pantalla.pbStartScreen
      end
      pbFlyToNewLocation
    end
  end
end
