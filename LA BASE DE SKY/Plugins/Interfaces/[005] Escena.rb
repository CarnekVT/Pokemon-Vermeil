#===============================================================================
# Escena: coge un diseño ya leido y lo convierte en una pantalla jugable.
#
# ES UNA SOLA CLASE PARA TODAS LAS PANTALLAS. Ahi esta la gracia: el diseño
# cambia, esto no. Sigue el reparto Escena/Pantalla de Essentials (mirar
# PokemonBag_Scene y PokemonBagScreen) pero fundido en una clase, porque no hay
# logica de juego que separar: lo que hace cada boton lo dice el diseño.
#
# POR QUE NO USA pbUpdateSpriteHash
#   Porque cada elemento ya se actualiza a si mismo en su actualizar(), y los
#   AnimatedSprite avanzan de fotograma dentro de update. Llamar a los dos seria
#   actualizarlos dos veces por fotograma y las hojas de sprites irian al doble
#   de velocidad.
#
# ERRORES A LA VISTA
#   Un diseño roto pinta un cartel rojo con el fichero, la linea y el fallo. Los
#   problemas menores (una imagen que falta) se listan en una esquina, pero SOLO
#   con $DEBUG. Un hueco vacio sin explicacion es lo que mas tiempo hace perder,
#   y quien usa el editor no puede leer una consola.
#===============================================================================

module Interfaces
  # Z del viewport: EL MISMO 99999 que usan las pantallas de Essentials.
  #
  # No es un numero al azar y cambiarlo rompe cosas. pbFadeOutIn (con el que se
  # abren las entradas del menu de pausa) crea un viewport a z 99999 y lo pone
  # NEGRO OPACO, y lo deja puesto mientras corre lo que venga despues. Estando por
  # debajo, una interfaz abierta desde el menu de pausa se veria completamente
  # negra. Con el mismo z, y creandose despues, queda encima del negro y el mapa
  # desaparece: que es exactamente el efecto de "pantalla completa" que usan la
  # Mochila y la Pokedex.
  #
  # Que la Mochila abierta DESDE una interfaz salga por encima no se arregla con
  # el z sino escondiendo la interfaz mientras tanto (ver Escena#con_la_interfaz_oculta),
  # que ademas queda mejor: no se ve asomar por detras.
  Z_BASE = 99999

  #-----------------------------------------------------------------------------
  # EL RATON, A PELO.
  #
  # Se usan solo Input.mouse_x / Input.mouse_y / Input.press?(Input::MOUSELEFT),
  # que son las primitivas que usan las propias pantallas de debug de Essentials
  # (UIControls) y por tanto las unicas de las que uno se puede fiar aqui.
  #
  # Del modulo Mouse que trae el proyecto NO se usa nada para acertar botones:
  # su over_area? esta roto (hace Rect.new dentro del modulo Mouse, donde Rect es
  # un mixin y no la clase), y su click? lleva un contador global compartido que
  # se corrompe si lo llaman varios sitios. Comprobado con el juego delante.
  #-----------------------------------------------------------------------------
  def self.raton
    x = Input.mouse_x
    y = Input.mouse_y
    return nil if x.nil? || y.nil?
    return nil if x < 0 || y < 0                    # fuera de la ventana
    return [x, y]
  end

  def self.raton_pulsado?
    return Input.press?(Input::MOUSELEFT)
  rescue StandardError
    # Si este build no tuviera boton de raton, mejor sin clics que sin juego.
    return false
  end

  #-----------------------------------------------------------------------------
  # La puerta de entrada. Es lo que llaman pbInterfaz y el menu de debug.
  #
  # ES UN BUCLE, NO UNA LLAMADA ANIDADA. Cuando una pantalla dice "vete a esta
  # otra", esta se cierra y la siguiente se abre AL MISMO NIVEL. Asi el jugador
  # puede navegar por un menu de veinte pantallas sin apilar veinte escenas
  # abiertas, que era lo que pasaria llamando a abrir() desde dentro de abrir().
  #
  # Lo que si anida es la accion abrir_interfaz, que existe para avisos y
  # confirmaciones ("¿seguro?" encima de lo que ya hay). Esa lleva su tope de
  # profundidad aparte, en Acciones.
  #-----------------------------------------------------------------------------
  def self.abrir(nombre, profundidad = 0)
    destino = nombre.to_s
    resultado = nil
    saltos = 0

    while destino
      saltos += 1
      if saltos > MAX_SALTOS
        # Dos pantallas que se llaman la una a la otra. No puede pasar pulsando
        # botones (cada salto es un clic), pero si con un interruptor mal puesto,
        # y colgar el juego en silencio no es una opcion.
        mostrar_error(ErrorPantalla.new(
          "he saltado #{MAX_SALTOS} veces seguidas entre pantallas y no paro. " \
          "Mira si dos se estan llamando la una a la otra", "UI/" + destino + ".json"))
        return nil
      end

      datos = nil
      avisos = []
      begin
        datos, avisos = Lector.cargar(destino)
      rescue ErrorPantalla => e
        mostrar_error(e)
        return nil
      end

      escena = Escena.new(datos, avisos, profundidad)
      resultado = escena.ejecutar
      destino = escena.ir_a          # nil = no hay que ir a ningun sitio, se sale
    end
    return resultado
  end

  #-----------------------------------------------------------------------------
  # El cartel de error. Tiene que funcionar SIN depender de nada del diseño,
  # porque justo lo que ha fallado es el diseño.
  #-----------------------------------------------------------------------------
  def self.mostrar_error(e)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = Z_BASE + 100
    lienzo = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
    b = lienzo.bitmap
    Interfaces.fuente(b)

    m = 16
    b.fill_rect(m, m, Graphics.width - (m * 2), Graphics.height - (m * 2), C_ERROR_FONDO)
    b.fill_rect(m, m, Graphics.width - (m * 2), 2, C_ERROR_BORDE)

    b.font.size = 16
    b.font.color = C_ERROR_BORDE
    b.draw_text(m + 10, m + 8, Graphics.width - (m * 2) - 20, 22, _INTL("No puedo abrir esta interfaz"))

    b.font.size = 13
    b.font.color = C_ERROR_TEXTO
    y = m + 38
    # El mensaje puede ser largo: se parte a mano porque draw_text no salta linea.
    partir(e.message.to_s, 58).each do |linea|
      b.draw_text(m + 10, y, Graphics.width - (m * 2) - 20, 18, linea)
      y += 17
    end

    if !e.sitio.empty?
      b.font.color = C_ERROR_TENUE
      b.draw_text(m + 10, y + 6, Graphics.width - (m * 2) - 20, 18, e.sitio)
    end

    b.font.color = C_ERROR_TENUE
    b.draw_text(m + 10, Graphics.height - m - 26, Graphics.width - (m * 2) - 20, 18,
                _INTL("Pulsa una tecla para volver"))

    pbSEPlay("GUI sel buzzer")
    loop do
      Graphics.update
      Input.update
      break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
    end
    lienzo.dispose
    viewport.dispose
  end

  # Parte un texto en lineas de como maximo n caracteres, sin cortar palabras.
  def self.partir(texto, n)
    lineas = []
    actual = ""
    texto.split(" ").each do |palabra|
      if actual.empty?
        actual = palabra
      elsif (actual.length + 1 + palabra.length) <= n
        actual += " " + palabra
      else
        lineas << actual
        actual = palabra
      end
    end
    lineas << actual if !actual.empty?
    return lineas
  end

  #=============================================================================
  # La escena.
  #=============================================================================
  class Escena
    attr_reader :profundidad
    attr_accessor :resultado
    # Si al cerrarse hay que abrir otra pantalla, aqui va su nombre. Lo pone la
    # accion ir_a_interfaz o interruptor_interfaz, y lo lee el bucle de arriba.
    attr_accessor :ir_a

    def initialize(datos, avisos, profundidad = 0)
      @datos       = datos
      @avisos      = avisos
      @profundidad = profundidad
      @elementos   = []
      @botones     = []
      @cursores    = []
      @elegido     = nil
      @resultado   = nil
      @ir_a        = nil
      @depurando   = $DEBUG
      # El teclado va puesto salvo que el diseño lo apague. Es lo natural en un
      # Pokemon, y ademas el raton no siempre esta a mano.
      @teclado     = datos["teclado"] != false
      @completa    = !!datos["pantalla_completa"]
    end

    # Esconde la interfaz mientras corre otra cosa (la Mochila, el equipo...) y la
    # devuelve al terminar. Sin esto, la interfaz se veria asomando por detras de
    # la pantalla del juego, que ademas es de las que llenan la pantalla entera.
    def con_la_interfaz_oculta
      antes = @viewport ? @viewport.visible : nil
      @viewport.visible = false if @viewport && !@viewport.disposed?
      yield
    ensure
      @viewport.visible = antes if @viewport && !@viewport.disposed? && !antes.nil?
    end

    #---------------------------------------------------------------------------
    # EL ensure NO ES OPCIONAL.
    #
    # crear pone $game_temp.in_menu = true y va construyendo elementos. Si algo
    # revienta a mitad (un Pokemon con datos raros de una partida vieja, un color
    # imposible), sin este ensure pasaban dos cosas a la vez: el viewport y los
    # sprites ya creados se quedaban sin soltar, y sobre todo in_menu se quedaba
    # en true PARA SIEMPRE. Esa es la señal que mira el motor para saber que el
    # jugador esta en un menu, asi que el juego se quedaba como congelado sin
    # ningun menu delante. Un fallo de una pantalla de adorno no puede dejar la
    # partida inservible.
    def ejecutar
      begin
        crear
        bucle
      rescue Exception => e
        raise if e.is_a?(SystemExit) || e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
        # Se cierra primero (el ensure de abajo) y se enseña el fallo despues, para
        # que el cartel no salga por detras de la pantalla a medio construir.
        @fallo = e
      ensure
        cerrar
      end
      if @fallo
        Interfaces.mostrar_error(ErrorPantalla.new(
          "algo fallo dentro de esta pantalla: #{@fallo.message}",
          Lector.ruta(@datos["nombre"])))
        return nil
      end
      return @resultado
    end

    def crear
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      # Cada interfaz anidada va por encima de la que la abrio.
      @viewport.z = Interfaces::Z_BASE + (@profundidad * 2)

      # EL FONDO.
      #
      #   Ventana (por defecto): se oscurece el mapa lo que diga el diseño y se
      #   sigue viendo detras.
      #
      #   Pantalla completa: un fondo OPACO que tapa el mapa del todo. Es lo que
      #   hace que una pantalla se sienta "propia" y no una ventanita encima del
      #   juego, y ademas evita el efecto feo de que se vea el mapa moverse por
      #   los bordes de un diseño que no llega a cubrirlo entero.
      if @completa
        # El fondo es EXACTAMENTE el color que se haya puesto, transparencia
        # incluida. Antes se forzaba a opaco "porque completa quiere decir opaca",
        # y eso era decidir por quien diseña: con alfa 0 se puede hacer una capa
        # que ocupa toda la pantalla y deja ver el mapa por debajo, que es una
        # forma perfectamente valida de hacer un HUD.
        fondo = Interfaces.color(@datos["color_fondo"]) || Color.new(0, 0, 0, 255)
        if fondo.alpha > 0
          @atenuar = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
          @atenuar.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, fondo)
          @atenuar.z = -1
        end
      else
        oscurecer = @datos["oscurecer_mapa"].to_i
        if oscurecer > 0
          @atenuar = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
          @atenuar.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height,
                                    Color.new(0, 0, 0, [oscurecer, 255].min))
          @atenuar.z = -1                    # detras de todos los elementos
        end
      end

      ahora = System.uptime
      # Por capa, y a igualdad de capa por el orden del diseño: asi la lista de
      # capas del editor y lo que se ve en el juego coinciden siempre.
      ordenados = @datos["elementos"].each_with_index.sort_by { |el, i| [el["capa"].to_i, i] }
      ordenados.each do |el, _i|
        elemento = Elemento.construir(el, @viewport, @avisos)
        elemento.crear(ahora)
        @elementos << elemento
        @botones << elemento if elemento.is_a?(Boton)
        @cursores << elemento if el["sigue_seleccion"]
      end

      # Orden para el teclado: primero lo que diga el diseño y, a falta de eso,
      # de arriba abajo y de izquierda a derecha, que es como se lee.
      @botones = @botones.sort_by do |b|
        orden = b.datos["orden_teclado"]
        x, y, _w, _h = b.zona
        [orden.nil? ? 1 : 0, orden.to_i, y, x]
      end

      # El primero queda elegido de salida, para que las flechas hagan algo desde
      # el principio en vez de pedir un primer clic.
      @elegido = @botones.first if @teclado && !@botones.empty?
      colocar_cursores

      # Marcar que el jugador esta en un menu. Es la señal que mira el resto del
      # motor para no interrumpir (el aviso de bateria baja, por ejemplo) y la que
      # impide que la tecla de apertura vuelva a disparar estando ya dentro.
      @menu_antes = $game_temp ? $game_temp.in_menu : nil
      $game_temp.in_menu = true if $game_temp

      # EL CLIC QUE ABRIO ESTA PANTALLA NO CUENTA COMO CLIC DENTRO DE ELLA.
      #
      # Si se llega aqui pulsando un boton de la pantalla anterior, el raton
      # todavia esta apretado. Empezando con @pulsando_antes a false, el primer
      # fotograma veria "acaban de apretar", capturaria lo que hubiera bajo el
      # cursor y al soltar dispararia ese boton solo. O sea que navegar de una
      # pantalla a otra activaria botones sin tocarlos.
      #
      # Arrancando con el estado REAL del raton, hay que soltar y volver a
      # apretar para que cuente.
      @pulsando_antes = Interfaces.raton_pulsado?
      @capturado = nil

      mostrar_cursor
      crear_capa_depuracion if @depurando
    end

    #---------------------------------------------------------------------------
    def bucle
      loop do
        Graphics.update
        Input.update
        ahora = System.uptime

        @elementos.each { |el| el.actualizar(ahora) }

        break if navegar_con_teclado == :cerrar
        break if revisar_botones == :cerrar

        # Despues de mover la seleccion, para que la flecha no vaya un fotograma
        # por detras del boton que señala.
        colocar_cursores
        # Solo se repinta cada fotograma si la marca esta puesta: lo unico que
        # cambia ahi son las coordenadas del raton.
        actualizar_marca if @depurando && Interfaces::MARCA_VERSION

        if Input.trigger?(Input::BACK)
          pbSEPlay(Interfaces::SE_CERRAR)
          break
        end
      end
    end

    #---------------------------------------------------------------------------
    # TECLADO. Flechas para moverse, Z para pulsar.
    #
    # Se elige el boton MAS CERCANO en la direccion que se pulsa, no el siguiente
    # de una lista. Asi funciona igual en un menu en columna, en fila o repartido
    # por la pantalla, sin pedirle a nadie que numere nada. Quien quiera mandar
    # sobre el orden, puede poner "orden_teclado" en el editor.
    #---------------------------------------------------------------------------
    def navegar_con_teclado
      return nil if !@teclado || @botones.empty?

      dir = if Input.trigger?(Input::UP)      then :arriba
            elsif Input.trigger?(Input::DOWN)  then :abajo
            elsif Input.trigger?(Input::LEFT)  then :izquierda
            elsif Input.trigger?(Input::RIGHT) then :derecha
            end

      if dir
        siguiente = boton_hacia(dir)
        if siguiente
          @elegido = siguiente
          pbSEPlay(Interfaces::SE_ENCIMA)
        end
        return nil
      end

      if Input.trigger?(Input::USE) && @elegido
        sonido = @elegido.datos["sonido"].to_s
        pbSEPlay(sonido.empty? ? Interfaces::SE_PULSAR : sonido)
        return :cerrar if Acciones.ejecutar(@elegido.accion, self) == :cerrar
      end
      return nil
    end

    # El boton mas cercano en esa direccion, midiendo desde el centro del actual.
    # Se penaliza el desvio lateral para que bajar en una columna no salte a otra
    # columna que estuviera un poco mas cerca en linea recta.
    def boton_hacia(dir)
      utiles = @botones.select { |b| b.sprite && !b.sprite.disposed? && b.sprite.visible }
      return nil if utiles.empty?
      return utiles.first if @elegido.nil?

      ox, oy = centro_de(@elegido)
      mejor = nil
      mejor_coste = nil
      utiles.each do |b|
        next if b.equal?(@elegido)
        bx, by = centro_de(b)
        dx = bx - ox
        dy = by - oy
        avance, desvio = case dir
                         when :arriba     then [-dy, dx.abs]
                         when :abajo      then [dy, dx.abs]
                         when :izquierda  then [-dx, dy.abs]
                         when :derecha    then [dx, dy.abs]
                         end
        next if avance <= 0                       # esta al otro lado
        coste = avance + (desvio * 2)             # el desvio lateral pesa doble
        if mejor_coste.nil? || coste < mejor_coste
          mejor = b
          mejor_coste = coste
        end
      end
      return mejor
    end

    def centro_de(b)
      x, y, w, h = b.zona
      return [x + (w / 2.0), y + (h / 2.0)]
    end

    # El cursor (la flecha que señala) se coloca junto al boton elegido. Es lo que
    # hace que la flecha del diseño signifique algo en vez de ser un adorno.
    def colocar_cursores
      return if @cursores.empty?
      if @elegido.nil?
        @cursores.each { |c| c.sprite.visible = false if c.sprite && !c.sprite.disposed? }
        return
      end
      x, y, w, h = @elegido.zona
      @cursores.each do |c|
        next if !c.sprite || c.sprite.disposed?
        c.sprite.visible = true
        dx = c.datos["cursor_x"].to_i
        dy = c.datos["cursor_y"].to_i
        # Pegado al borde izquierdo del boton y centrado a su altura, que es lo
        # que se espera de una flecha que señala.
        alto_cursor = c.sprite.bitmap ? c.sprite.bitmap.height : 0
        c.sprite.x = x + dx
        c.sprite.y = y + ((h - alto_cursor) / 2) + dy
      end
    end

    # Devuelve :cerrar si alguna accion pide cerrar la pantalla.
    #
    # EL CLIC ES APRETAR Y SOLTAR SOBRE EL MISMO BOTON, como en cualquier
    # programa: si aprietas y te vas antes de soltar, no cuenta. Asi se puede
    # arrepentir uno, y ademas evita disparar acciones sin querer al arrastrar.
    def revisar_botones
      return nil if @botones.empty?

      raton = Interfaces.raton
      pulsando = Interfaces.raton_pulsado?
      mx, my = raton

      # SOLO responde el boton de capa mas alta que este bajo el raton. Sin esto,
      # dos botones que se solapan se encienden los dos y se pulsan los dos, que
      # es justo lo que no espera nadie.
      arriba = nil
      if raton
        @botones.sort_by { |b| -b.capa }.each do |b|
          if b.contiene?(mx, my)
            arriba = b
            break
          end
        end
      end

      # Flancos: quien se apreto y donde se solto.
      recien_apretado = pulsando && !@pulsando_antes
      recien_soltado  = !pulsando && @pulsando_antes
      @pulsando_antes = pulsando

      @capturado = arriba if recien_apretado          # nil si se apreto en el vacio
      @capturado = nil if !pulsando && !recien_soltado

      # El raton manda sobre la seleccion, PERO SOLO SI SE HA MOVIDO.
      #
      # Antes se ponia @elegido = arriba siempre que el raton estuviera encima de
      # otro boton, y eso rompia el teclado del todo: con el raton parado sobre un
      # boton, pulsabas una flecha, navegar_con_teclado movia la seleccion... y
      # dos lineas mas abajo, en el MISMO fotograma, esto la devolvia al boton de
      # debajo del raton. O sea que con el raton apoyado en cualquier sitio las
      # flechas no hacian nada, sin ni siquiera un parpadeo que diera una pista.
      #
      # Mirando si el raton se ha movido, cada manejo manda cuando se usa: mueves
      # el raton y elige el de debajo, tocas una flecha y elige el de al lado.
      movido = (raton && @raton_antes && raton != @raton_antes)
      @raton_antes = raton
      @elegido = arriba if movido && arriba && !arriba.equal?(@elegido)

      cerrar_al_salir = false
      pulsado_ahora = nil

      @botones.each do |b|
        dentro = b.equal?(arriba) || b.equal?(@elegido)
        suceso = b.aplicar_raton(dentro, pulsando && b.equal?(@capturado))
        # El sonido solo cuando entra el RATON: si no, sonaria tambien al moverse
        # con las flechas, y eso ya lo suena la navegacion por su cuenta.
        pbSEPlay(Interfaces::SE_ENCIMA) if suceso == :entra && b.equal?(arriba)
        # Clic completo: se apreto aqui y se ha soltado aqui.
        pulsado_ahora = b if recien_soltado && b.equal?(arriba) && b.equal?(@capturado)
      end
      @capturado = nil if recien_soltado

      if pulsado_ahora
        sonido = pulsado_ahora.datos["sonido"].to_s
        pbSEPlay(sonido.empty? ? Interfaces::SE_PULSAR : sonido)
        cerrar_al_salir = true if Acciones.ejecutar(pulsado_ahora.accion, self) == :cerrar
      end
      return cerrar_al_salir ? :cerrar : nil
    end

    #---------------------------------------------------------------------------
    def cerrar
      @elementos.each { |el| el.soltar }
      @elementos.clear
      @botones.clear
      @cursores.clear
      @elegido = nil
      @atenuar.dispose if @atenuar && !@atenuar.disposed?
      @depuracion.dispose if @depuracion && !@depuracion.disposed?
      @viewport.dispose if @viewport && !@viewport.disposed?
      restaurar_cursor
      # Se devuelve como estaba, no a false: si esta interfaz se abrio DESDE el
      # menu de pausa, el menu sigue abierto detras y ponerlo a false lo dejaria
      # creyendo que el jugador ya salio.
      $game_temp.in_menu = @menu_antes if $game_temp && !@menu_antes.nil?
    end

    #---------------------------------------------------------------------------
    # El raton. Esta interfaz se maneja con el raton, asi que el cursor tiene que
    # verse; y al salir se deja como estaba, que puede ser visible si el jugador
    # lo tiene asi.
    #---------------------------------------------------------------------------
    # Todo entre rescue: se toca Graphics.show_cursor, que no todos los builds de
    # MKXP-Z exponen para leer. Quedarse sin puntero es un incordio; no poder
    # abrir la pantalla, un fallo.
    def mostrar_cursor
      @cursor_antes = begin
        Graphics.show_cursor
      rescue StandardError, NoMethodError
        false
      end
      begin
        Graphics.show_cursor = true
      rescue StandardError, NoMethodError
        # sin puntero visible, pero el raton sigue funcionando
      end
    end

    def restaurar_cursor
      Graphics.show_cursor = @cursor_antes ? true : false
    rescue StandardError, NoMethodError
      nil
    end

    #---------------------------------------------------------------------------
    # Capa de depuracion: la version del motor y los avisos del diseño. Solo con
    # $DEBUG, o sea nunca en una release para jugadores.
    #---------------------------------------------------------------------------
    def crear_capa_depuracion
      @depuracion = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @depuracion.z = 999999
      pintar_depuracion
    end

    def pintar_depuracion
      return if !@depuracion
      b = @depuracion.bitmap
      b.clear
      Interfaces.fuente(b)

      actualizar_marca

      return if @avisos.empty?

      # Los avisos, arriba a la izquierda y recortados: son una ayuda, no deben
      # tapar el diseño que se esta cuadrando.
      alto = [(@avisos.length * 14) + 20, 120].min
      b.fill_rect(0, 0, Graphics.width, alto, Color.new(60, 40, 0, 200))
      b.font.size = 11
      b.font.color = Color.new(255, 220, 120)
      b.draw_text(6, 3, Graphics.width - 12, 14,
                  _INTL("{1} aviso(s) en este diseño:", @avisos.length))
      b.font.color = Color.new(255, 245, 220)
      y = 17
      @avisos.each do |aviso|
        break if y > alto - 14
        b.draw_text(6, y, Graphics.width - 12, 14, aviso)
        y += 13
      end
    end

    # La franja de abajo: version y coordenadas del raton. Se repinta sola cada
    # fotograma, borrando solo su tira para no rehacer los avisos cada vez.
    #
    # LAS COORDENADAS NO SON ADORNO. Si algun dia los botones no responden donde
    # se ven, esto lo dice en dos segundos: basta con cambiar el tamaño de
    # pantalla en las opciones y mirar si los numeros siguen llegando al tamaño
    # del lienzo o se pasan de largo (eso significaria que Input.mouse_x da
    # coordenadas de la VENTANA y hay que dividir por la escala).
    def actualizar_marca
      return if !@depuracion
      # Apagada por ajuste: estorba encima del diseño. Los AVISOS de arriba siguen
      # saliendo, que esos si hacen falta mientras se diseña.
      return if !Interfaces::MARCA_VERSION
      b = @depuracion.bitmap
      alto = 22
      # Se limpia una franja MAS ALTA de lo que ocupa el texto. Con el offset de
      # fuente del motor, el texto se pintaba fuera de la franja que se borraba y
      # se iba acumulando encima de si mismo cada fotograma, dejando un churro
      # ilegible en la esquina. Interfaces.fuente ya pone ese offset a cero, y
      # este colchon es el cinturon de seguridad.
      b.fill_rect(0, Graphics.height - alto, Graphics.width, alto, Color.new(0, 0, 0, 0))
      Interfaces.fuente(b, 12)
      b.font.color = Interfaces::C_VERSION
      raton = Interfaces.raton
      marca = "INTERFACES " + Interfaces::VERSION
      marca += raton ? "  raton #{raton[0]},#{raton[1]}" : "  raton fuera"
      marca += "  lienzo #{Graphics.width}x#{Graphics.height}"
      b.draw_text(0, Graphics.height - alto, Graphics.width - 4, 16, marca, 2)
    end

    # Para que las acciones puedan quejarse en tiempo de ejecucion.
    def avisar_en_pantalla(texto)
      @avisos << texto
      pintar_depuracion
    end
  end
end
