#===============================================================================
# Interfaces — las cuatro maneras de abrir una pantalla
#
# NINGUNA DE LAS CUATRO PIDE TOCAR ESTE FICHERO. Todo se configura en el editor,
# en el panel "Aperturas", y se guarda dentro del propio diseño. Este fichero
# solo lee lo que hayas puesto ahi.
#
#   1. MENU DE PAUSA
#      Marca la casilla en el editor. Sale en el menu que abre el jugador con X.
#
#   2. UNA TECLA
#      Pon la tecla en el editor. Estando en el mapa, esa tecla abre la pantalla.
#
#   3. UN INTERRUPTOR DE INTERFAZ
#      Para ir de una pantalla a otra: un boton activa el interruptor "misiones"
#      y la pantalla que lo tenga puesto se abre, cerrandose la de antes.
#      OJO: no son los interruptores de Essentials, son nuestros y con nombre.
#
#   4. DESDE UN EVENTO
#      Comando de Script (Script...) en el evento:
#
#          pbInterfaz("menu_misiones")
#
#      Y si la pantalla deja un resultado, se puede recoger en una variable del
#      juego para montar condiciones con el editor de eventos, sin codigo:
#
#          pbInterfazEnVariable(20, "confirmar_venta")
#
# CUANDO HAY QUE REINICIAR EL JUEGO
#   El menu de pausa y las teclas se leen AL ARRANCAR. Si cambias el DISEÑO
#   (mover cosas, colores, animaciones) basta con volver a abrir la pantalla. Si
#   cambias COMO SE ABRE, hay que reiniciar el juego una vez.
#===============================================================================

def pbInterfaz(nombre)
  return Interfaces.abrir(nombre.to_s, 0)
end

def pbInterfazEnVariable(id_variable, nombre)
  $game_variables[id_variable] = pbInterfaz(nombre)
  $game_map.need_refresh = true if $game_map
  return $game_variables[id_variable]
end

#===============================================================================
# 1. MENU DE PAUSA — las interfaces se registran solas.
#
# Se escanea UI/*.json al cargar el plugin y se registra la que lo pida. Antes
# esto era una lista en Settings.rb y obligaba a editar Ruby para meter una
# pantalla en el menu del jugador, que es exactamente lo que esta herramienta
# tiene que evitar.
#
# Todo va envuelto en un rescue: si un diseño esta roto NO puede impedir que el
# juego arranque. Se salta, y el menu de debug lo cuenta.
#===============================================================================
begin
  Interfaces::Lector.catalogo.each do |entrada|
    next if !entrada[:menu_pausa]
    nombre_interfaz = entrada[:nombre]
    MenuHandlers.add(:pause_menu, ("interfaz_" + nombre_interfaz).to_sym, {
      "name"   => entrada[:titulo],
      "order"  => entrada[:orden],
      "effect" => proc { |menu|
        pbPlayDecisionSE
        # Con pbFadeOutIn, como el resto de entradas del menu: si no, la interfaz
        # aparece encima del menu de pausa todavia dibujado.
        pbFadeOutIn do
          pbInterfaz(nombre_interfaz)
          menu.pbRefresh
        end
        next false
      }
    })
  end
rescue StandardError => e
  # Sin esto, un fichero de decoracion mal escrito dejaria el juego sin arrancar.
  echoln("[Interfaces] No he podido registrar el menu de pausa: #{e.message}") if defined?(echoln)
end

#===============================================================================
# REEMPLAZAR UNA PANTALLA DEL JUEGO POR UNA TUYA
#
# Si haces una pantalla y le pones en sus aperturas el interruptor "mochila",
# esa pasa a SER la mochila: la entrada del menu de pausa abre la tuya, y
# cualquier boton que use el interruptor "mochila" tambien.
#
# Se hace cambiando la entrada que registro Essentials en el menu de pausa. Se
# puede porque MenuHandlers guarda los controladores en un Hash por clave, asi
# que volver a añadir con la misma clave lo reemplaza. Y el menu de Voltseon los
# lee con MenuHandlers.each_available, asi que tambien coge el cambio.
#
# DOS CUIDADOS IMPORTANTES:
#
#   1. Solo se toca lo que hayas reemplazado de verdad. Si ninguna pantalla tuya
#      reclama "mochila", la entrada de la Mochila se queda EXACTAMENTE como
#      estaba. Cero huella.
#
#   2. Se copia la entrada original y solo se cambia lo que hace. Asi se
#      conservan su nombre, su puesto y su condicion (por ejemplo, la Mochila no
#      sale durante el Concurso de Bichos), que si las reescribiera a mano se
#      perderian.
#===============================================================================
begin
  Interfaces::Lector.integradas_reemplazadas.each_pair do |interruptor, mia|
    datos = Interfaces::INTEGRADAS[interruptor]
    next if datos.nil?
    original = MenuHandlers.get(:pause_menu, datos[:menu])
    next if original.nil?                    # ese menu no existe en este juego

    nueva = original.clone
    nueva["effect"] = proc { |menu|
      pbPlayDecisionSE
      pbFadeOutIn do
        pbInterfaz(mia)
        menu.pbRefresh
      end
      next false
    }
    MenuHandlers.add(:pause_menu, datos[:menu], nueva)
  end
rescue StandardError => e
  echoln("[Interfaces] No he podido reemplazar una pantalla del juego: #{e.message}") if defined?(echoln)
end

#===============================================================================
# 2. TECLAS — vigilante que corre solo en el mapa.
#
# on_frame_update se dispara desde Scene_Map#updateMaps, asi que ya solo corre
# estando en el mapa: no hace falta comprobar la escena.
#
# Las guardas son las que usa el propio motor antes de interrumpir al jugador
# (mirar low_battery_warning en los scripts del juego). Sin ellas la pantalla se
# abriria en medio de un dialogo o de una cinematica.
#===============================================================================
EventHandlers.add(:on_frame_update, :interfaces_por_tecla,
  proc {
    next if $game_temp.nil? || $game_player.nil?
    next if $game_temp.in_menu || $game_temp.in_battle ||
            $game_player.move_route_forcing ||
            $game_temp.message_window_showing || pbMapInterpreterRunning?

    Interfaces.teclas.each_pair do |tecla, nombre_interfaz|
      pulsada = false
      begin
        pulsada = Input.triggerex?(tecla)
      rescue StandardError => e
        # Un nombre de tecla que este build no conoce reventaria SESENTA VECES POR
        # SEGUNDO y dejaria el juego inservible. Se apaga esa tecla y se sigue.
        Interfaces.desactivar_tecla(tecla, e.message)
        next
      end
      next if !pulsada
      pbInterfaz(nombre_interfaz)
      break                                  # una por pulsacion, no dos a la vez
    end
  }
)

module Interfaces
  # tecla (simbolo) => nombre del diseño. Se calcula una vez, porque recorrer el
  # catalogo en cada fotograma seria absurdo.
  def self.teclas
    return @teclas if @teclas
    @teclas = {}
    begin
      Lector.catalogo.each do |entrada|
        next if entrada[:tecla].empty?
        simbolo = entrada[:tecla].to_sym
        # Dos pantallas con la misma tecla: gana la primera y se avisa, porque en
        # silencio parecería que la segunda esta rota.
        if @teclas[simbolo]
          echoln("[Interfaces] La tecla #{entrada[:tecla]} la piden \"#{@teclas[simbolo]}\" y " \
                 "\"#{entrada[:nombre]}\". Se queda la primera.") if defined?(echoln)
          next
        end
        @teclas[simbolo] = entrada[:nombre]
      end
    rescue StandardError
      @teclas = {}
    end
    return @teclas
  end

  def self.olvidar_teclas
    @teclas = nil
    @teclas_rotas = nil
  end

  # Apaga una tecla que este build de MKXP-Z no reconoce, y lo apunta para poder
  # decirlo en el mapa de aperturas. Mejor perder esa apertura que perder el juego.
  def self.desactivar_tecla(tecla, motivo)
    @teclas_rotas ||= {}
    return if @teclas_rotas[tecla]
    @teclas_rotas[tecla] = motivo
    nombre = teclas[tecla]
    teclas.delete(tecla)
    if defined?(echoln)
      echoln("[Interfaces] La tecla #{tecla} no vale en este motor (#{motivo}). " \
             "\"#{nombre}\" ya no se abrira con ella; prueba con una letra.")
    end
  end

  def self.teclas_rotas
    return @teclas_rotas || {}
  end
end

#===============================================================================
# MENU DE DEBUG
#===============================================================================

#-------------------------------------------------------------------------------
# Abrir cualquier diseño sin montar nada. La herramienta de trabajo mientras
# diseñas: guardas en el editor y abres aqui, sin recompilar.
#-------------------------------------------------------------------------------
MenuHandlers.add(:debug_menu, :abrir_interfaz, {
  "name"        => _INTL("Abrir una interfaz..."),
  "parent"      => :main,
  "description" => _INTL("Abre una pantalla hecha con el editor de interfaces (UI/*.json)."),
  "effect"      => proc {
    nombres = Interfaces::Lector.listar
    if nombres.empty?
      pbMessage(_INTL("No hay ningun diseño todavia.\nLos diseños van en la carpeta {1} del proyecto, uno por pantalla.",
                      Interfaces::RUTA_PANTALLAS))
      next
    end
    opciones = nombres.clone
    opciones.push(_INTL("Salir"))
    eleccion = pbShowCommands(nil, opciones, -1, 0)
    next if eleccion < 0 || eleccion >= nombres.length
    pbInterfaz(nombres[eleccion])
  }
})

#-------------------------------------------------------------------------------
# MAPA DE APERTURAS: como se abre cada pantalla, de un golpe.
#
# Existe para que la lista la lleve el programa y no tu. Sin esto habria que
# acordarse de que interruptor lleva a que pantalla, que es justo la queja que
# hizo que se escribiera todo esto.
#-------------------------------------------------------------------------------
MenuHandlers.add(:debug_menu, :mapa_aperturas_interfaces, {
  "name"        => _INTL("Ver como se abre cada interfaz"),
  "parent"      => :main,
  "description" => _INTL("Lista todas las pantallas con su tecla, su interruptor y si salen en el menu."),
  "effect"      => proc {
    Interfaces::Lector.olvidar_catalogo          # por si se guardo algo hace un momento
    Interfaces.olvidar_teclas
    catalogo = Interfaces::Lector.catalogo
    malos = Interfaces::Lector.catalogo_malos

    if catalogo.empty? && malos.empty?
      pbMessage(_INTL("No hay ningun diseño en {1}.", Interfaces::RUTA_PANTALLAS))
      next
    end

    lineas = []
    catalogo.each do |e|
      formas = []
      formas.push(_INTL("menu de pausa ({1})", e[:orden])) if e[:menu_pausa]
      formas.push(_INTL("tecla {1}", e[:tecla]))           if !e[:tecla].empty?
      formas.push(_INTL("interruptor \"{1}\"", e[:interruptor])) if !e[:interruptor].empty?
      formas.push(_INTL("solo por script")) if formas.empty?
      lineas.push("#{e[:nombre]}: " + formas.join(", "))
    end
    malos.each { |nombre, fallo| lineas.push(_INTL("{1}: ROTO - {2}", nombre, fallo)) }

    # Las del juego: cual sigue siendo la original y cual has reemplazado.
    reemplazadas = Interfaces::Lector.integradas_reemplazadas
    lineas.push("")
    lineas.push(_INTL("PANTALLAS DEL JUEGO"))
    Interfaces::INTEGRADAS.each_pair do |interruptor, datos|
      mia = reemplazadas[interruptor]
      if mia
        lineas.push(_INTL("{1} (\"{2}\") -> LA TUYA: {3}", datos[:titulo], interruptor, mia))
      else
        lineas.push(_INTL("{1} (\"{2}\") -> la del juego", datos[:titulo], interruptor))
      end
    end

    # De cuatro en cuatro, que en 512 de ancho no cabe mucho mas.
    lineas.each_slice(4) { |trozo| pbMessage(trozo.join("\n")) }

    if !malos.empty?
      pbMessage(_INTL("Recuerda: el menu de pausa y las teclas se leen al arrancar el juego.\nSi acabas de cambiar como se abre una pantalla, reinicia una vez."))
    end
  }
})

#-------------------------------------------------------------------------------
# Comprobar todos los diseños sin abrirlos.
#-------------------------------------------------------------------------------
MenuHandlers.add(:debug_menu, :comprobar_interfaces, {
  "name"        => _INTL("Comprobar las interfaces"),
  "parent"      => :main,
  "description" => _INTL("Lee todos los UI/*.json y dice cuales tienen fallos o avisos."),
  "effect"      => proc {
    nombres = Interfaces::Lector.listar
    if nombres.empty?
      pbMessage(_INTL("No hay ningun diseño en {1}.", Interfaces::RUTA_PANTALLAS))
      next
    end
    lineas = []
    nombres.each do |nombre|
      begin
        _datos, avisos = Interfaces::Lector.cargar(nombre)
        if avisos.empty?
          lineas.push(_INTL("{1}: bien", nombre))
        else
          lineas.push(_INTL("{1}: {2} aviso(s)", nombre, avisos.length))
        end
      rescue Interfaces::ErrorPantalla => e
        lineas.push(_INTL("{1}: ROTO - {2}", nombre, e.message))
      end
    end
    lineas.each_slice(4) { |trozo| pbMessage(trozo.join("\n")) }
  }
})
