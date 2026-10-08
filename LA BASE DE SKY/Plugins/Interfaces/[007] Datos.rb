#===============================================================================
# Datos del juego dentro de una pantalla.
#
# PARA QUE SIRVE
#   Sin esto, un texto solo puede decir algo fijo. Con esto puede decir el nombre
#   del jugador, su dinero, la vida del primer Pokemon del equipo... o sea que se
#   pueden construir pantallas DE VERDAD (una ficha, un HUD, una caja de datos de
#   combate) y no solo menus de botones.
#
#   En el diseño se escriben entre llaves y se sustituyen al abrir la pantalla:
#
#     "texto": "{jugador} tiene {dinero}$"
#     "texto": "{equipo.1.nombre}  Nv{equipo.1.nivel}"
#     "texto": "{equipo.1.hp}/{equipo.1.hp_max}"
#
# LA REGLA QUE NO SE PUEDE ROMPER
#   PEDIR UN DATO NUNCA PUEDE TIRAR EL JUEGO. Una pantalla se puede abrir sin
#   partida empezada, con el equipo vacio, desde el menu de debug o en mitad de
#   un combate, y en cualquiera de esos casos la mitad de estos datos no existen.
#   Todo va envuelto y lo que no se puede saber devuelve un hueco visible ("---"),
#   que ademas se ve raro en pantalla y por eso se detecta enseguida.
#
# COMO AÑADIR UNO NUEVO
#   Una linea en FUENTES. El bloque recibe los trozos de despues del primer punto
#   ("equipo.1.hp" -> ["1", "hp"]) y devuelve lo que sea; se convierte a texto.
#===============================================================================

module Interfaces
  module Datos
    HUECO = "---"          # lo que se ve cuando un dato no esta disponible

    # Las barras necesitan numeros, no textos. Un dato que no se puede saber vale
    # 0 aqui, para que una barra rota se vea vacia en vez de reventar.
    def self.numero(clave)
      v = valor(clave)
      return 0.0 if v.nil? || v == HUECO
      return v.to_f
    end

    #---------------------------------------------------------------------------
    # El valor de un dato, ya en texto.
    #---------------------------------------------------------------------------
    def self.valor(clave)
      partes = clave.to_s.strip.split(".")
      raiz = partes.shift.to_s.downcase
      fuente = FUENTES[raiz]
      return HUECO if fuente.nil?
      begin
        v = fuente.call(partes)
        return HUECO if v.nil?
        return v.to_s
      rescue Exception => e
        raise if e.is_a?(SystemExit) || e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
        # Que un dato no este (sin partida, equipo vacio, fuera de combate) es
        # normal, no es un fallo del que haya que enterarse a gritos.
        return HUECO
      end
    end

    # Sustituye todas las {llaves} de un texto.
    def self.rellenar(texto)
      t = texto.to_s
      return t if !t.include?("{")
      return t.gsub(/\{([^{}]+)\}/) { valor($1) }
    end

    # ¿Este texto depende de algo que puede cambiar mientras la pantalla esta
    # abierta? Si es que si, hay que volver a pintarlo cada cierto tiempo.
    def self.tiene_datos?(texto)
      return texto.to_s.include?("{")
    end

    #---------------------------------------------------------------------------
    # Un Pokemon del equipo por su numero (1 es el primero, como lo cuenta
    # cualquiera; el codigo cuenta desde 0, y esa resta se hace aqui una vez).
    #---------------------------------------------------------------------------
    def self.del_equipo(numero)
      return nil if !$player
      i = numero.to_i - 1
      return nil if i < 0
      party = $player.party
      return nil if party.nil? || i >= party.length
      return party[i]
    end

    # Los datos de un Pokemon concreto.
    def self.de_pokemon(pkmn, campo)
      return nil if pkmn.nil?
      case campo.to_s.downcase
      when "nombre"    then pkmn.name
      when "especie"   then pkmn.species_data.name
      when "nivel"     then pkmn.level
      when "hp"        then pkmn.hp
      when "hp_max"    then pkmn.totalhp
      when "hp_pct"    then (pkmn.totalhp > 0) ? ((pkmn.hp * 100.0) / pkmn.totalhp).round : 0
      when "exp"       then pkmn.exp
      when "exp_max"   then pkmn.growth_rate.minimum_exp_for_level(pkmn.level + 1)
      when "naturaleza" then pkmn.nature.name
      when "objeto"    then pkmn.item ? pkmn.item.name : ""
      when "estado"
        return "" if pkmn.status == :NONE
        return GameData::Status.get(pkmn.status).name
      when "genero"
        return "" if pkmn.genderless?
        return pkmn.male? ? "M" : "F"
      when "ataque"    then pkmn.attack
      when "defensa"   then pkmn.defense
      when "velocidad" then pkmn.speed
      when "at_esp"    then pkmn.spatk
      when "def_esp"   then pkmn.spdef
      when "felicidad" then pkmn.happiness
      when "vivo"      then pkmn.able? ? 1 : 0
      end
    end

    #---------------------------------------------------------------------------
    # EL REGISTRO. Añadir un dato nuevo es añadir una linea aqui.
    #
    # Cada bloque recibe los trozos que van despues del primer punto.
    #---------------------------------------------------------------------------
    FUENTES = {
      # --- El jugador ---
      "jugador"   => proc { |_p| $player ? $player.name : nil },
      "dinero"    => proc { |_p| $player ? $player.money : nil },
      "insignias" => proc { |_p| $player ? $player.badge_count : nil },
      "id"        => proc { |_p| $player ? sprintf("%05d", $player.public_ID) : nil },
      "horas"     => proc { |_p| $stats ? ($stats.play_time / 3600).to_i : nil },
      "minutos"   => proc { |_p| $stats ? (($stats.play_time / 60) % 60).to_i : nil },
      "pokedex"   => proc { |_p| $player ? $player.pokedex.owned_count : nil },
      "vistos"    => proc { |_p| $player ? $player.pokedex.seen_count : nil },

      # --- Donde esta ---
      "mapa"      => proc { |_p| $game_map ? $game_map.name : nil },

      # --- El equipo ---
      # {equipo.total}          cuantos lleva
      # {equipo.1.nombre}       el primero
      "equipo" => proc { |p|
        if p[0].to_s.downcase == "total"
          next ($player && $player.party) ? $player.party.length : 0
        end
        Interfaces::Datos.de_pokemon(Interfaces::Datos.del_equipo(p[0]), p[1])
      },

      # --- Interruptores y variables del juego, los de los eventos ---
      "variable"    => proc { |p| $game_variables ? $game_variables[p[0].to_i] : nil },
      "interruptor" => proc { |p| $game_switches ? ($game_switches[p[0].to_i] ? 1 : 0) : nil },

      # --- El combate, cuando lo hay ---
      # Solo valen con un combate en marcha; fuera dan hueco, que es lo correcto.
      "combate" => proc { |p|
        b = $game_temp.respond_to?(:in_battle) && $game_temp.in_battle ? $battle : nil
        next nil if b.nil?
        case p[0].to_s.downcase
        when "turno" then b.turnCount
        when "mio"   then Interfaces::Datos.de_pokemon(b.battlers[0]&.pokemon, p[1])
        when "rival" then Interfaces::Datos.de_pokemon(b.battlers[1]&.pokemon, p[1])
        end
      }
    }

    #---------------------------------------------------------------------------
    # La lista para el editor: que datos hay y un ejemplo de cada uno.
    #
    # Vive aqui, junto a las fuentes, para que añadir un dato y que salga en el
    # editor sea el mismo sitio y no se puedan desincronizar.
    #---------------------------------------------------------------------------
    CATALOGO = [
      ["jugador",             "El nombre del jugador",            "ENTRENADOR"],
      ["dinero",              "El dinero que lleva",              "1500"],
      ["insignias",           "Cuantas medallas tiene",           "3"],
      ["id",                  "Su numero de entrenador",          "04213"],
      ["horas",               "Horas jugadas",                    "12"],
      ["minutos",             "Minutos (de la hora en curso)",    "34"],
      ["pokedex",             "Pokemon capturados",               "27"],
      ["vistos",              "Pokemon vistos",                   "58"],
      ["mapa",                "Donde esta ahora",                 "Pueblo Rumh"],
      ["equipo.total",        "Cuantos Pokemon lleva",            "4"],
      ["equipo.1.nombre",     "Nombre del Pokemon 1",             "PIKACHU"],
      ["equipo.1.especie",    "Su especie",                       "Pikachu"],
      ["equipo.1.nivel",      "Su nivel",                         "24"],
      ["equipo.1.hp",         "Su vida ahora",                    "31"],
      ["equipo.1.hp_max",     "Su vida maxima",                   "45"],
      ["equipo.1.hp_pct",     "Su vida en porcentaje",            "69"],
      ["equipo.1.exp",        "Su experiencia",                   "8420"],
      ["equipo.1.exp_max",    "La que necesita para subir",       "9261"],
      ["equipo.1.estado",     "Envenenado, dormido...",           "PSN"],
      ["equipo.1.genero",     "M o F",                            "M"],
      ["equipo.1.objeto",     "Lo que lleva puesto",              "Baya Aranja"],
      ["equipo.1.naturaleza", "Su naturaleza",                    "Alegre"],
      ["equipo.1.ataque",     "Su ataque",                        "52"],
      ["equipo.1.defensa",    "Su defensa",                       "40"],
      ["equipo.1.velocidad",  "Su velocidad",                     "90"],
      ["variable.5",          "El valor de la variable 5",        "7"],
      ["interruptor.20",      "1 si el interruptor 20 esta on",   "1"],
      ["combate.turno",       "En que turno va el combate",       "3"],
      ["combate.mio.nombre",  "Mi Pokemon en combate",            "PIKACHU"],
      ["combate.mio.hp",      "Su vida",                          "31"],
      ["combate.mio.hp_max",  "Su vida maxima",                   "45"],
      ["combate.rival.nombre", "El Pokemon rival",                "RATTATA"],
      ["combate.rival.hp_pct", "Su vida en porcentaje",           "80"]
    ]
  end
end
