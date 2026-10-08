#===============================================================================
# Elementos: una clase por cada tipo de cosa que se puede poner en una pantalla.
#
# TODOS SIGUEN EL MISMO CONTRATO
#   crear      construye el sprite de RGSS
#   actualizar aplica las animaciones de este instante
#   soltar     lo suelta todo, sin dejar bitmaps colgando
#
# COMO CONVIVEN LAS DOS ANIMACIONES
#   Un elemento puede tener un efecto de ENTRADA (de catalogo) y ademas PISTAS de
#   claves hechas en la linea de tiempo. Manda la entrada mientras dura, y cuando
#   acaba toman el relevo las pistas. Se eligio asi porque es lo unico que se
#   puede explicar en una frase: "primero entra, luego se mueve".
#
#   Lo que no toca ninguna animacion se queda en su valor de reposo, el del
#   diseño. Asi animar la x de algo no le estropea la y.
#===============================================================================

module Interfaces
  # Convierte "#RRGGBB" o "#RRGGBBAA" en un Color. Devuelve nil si no se entiende,
  # para que quien llama pueda avisar en vez de pintar un color equivocado en
  # silencio.
  def self.color(texto)
    t = texto.to_s.strip
    t = t[1..-1] if t.start_with?("#")
    return nil if t !~ /\A[0-9a-fA-F]{6}([0-9a-fA-F]{2})?\z/
    a = (t.length == 8) ? t[6, 2].to_i(16) : 255
    return Color.new(t[0, 2].to_i(16), t[2, 2].to_i(16), t[4, 2].to_i(16), a)
  end

  #-----------------------------------------------------------------------------
  # Prepara un bitmap para escribir. TODO el texto del plugin pasa por aqui, para
  # que no puedan discrepar tres sitios distintos.
  #
  # LA LINEA IMPORTANTE ES text_offset_y = 0.
  #
  # pbSetSystemFont deja el offset en 8, y al dibujar el motor hace y -= offset,
  # o sea que pinta el texto OCHO PIXELES MAS ARRIBA de donde se le dice. Eso
  # tiene sentido en la ventana de dialogo, para la que se calibro, pero aqui
  # hacia dos destrozos:
  #
  #   - Un texto en un bitmap de su tamaño se salia por arriba y se veia cortado.
  #   - La marca de depuracion se pintaba fuera de la franja que se limpia, asi
  #     que se iba acumulando encima de si misma cada fotograma.
  #
  # Y ademas descuadraba con el editor, que dibuja centrado en la caja sin
  # inventarse desplazamientos. Con el offset a cero, el juego pinta donde el
  # editor enseña, que es la promesa de toda esta herramienta.
  #-----------------------------------------------------------------------------
  def self.fuente(bitmap, tamano = nil)
    pbSetSystemFont(bitmap)
    bitmap.font.size = tamano if tamano && tamano > 0
    bitmap.text_offset_y = 0
    return bitmap
  end

  #-----------------------------------------------------------------------------
  # Pone una imagen en un sprite SIN QUE PUEDA TIRAR EL JUEGO.
  #
  # Paso de verdad: una imagen bajada de una web de recursos se llamaba .png pero
  # por dentro era un WebP, y SDL corta el juego con "Unsupported image format".
  # Que el juego de un jugador se caiga porque una decoracion venia en el formato
  # equivocado es inaceptable: se avisa y se sigue, igual que con una que falta.
  #
  # Devuelve nil si fue bien, o el motivo si no.
  #-----------------------------------------------------------------------------
  def self.poner_imagen(sprite, ruta)
    return "sin imagen" if ruta.to_s.empty?
    begin
      sprite.setBitmap(ruta)
      return nil
    rescue Exception => e
      # Se recoge Exception y no solo StandardError porque SDLError no aparece por
      # ningun sitio en los scripts del juego y no se puede saber de que hereda;
      # un rescue normal podria no pillarlo.
      #
      # Pero NO se traga lo que nunca hay que tragarse: si el jugador cierra el
      # juego o algo se queda sin memoria, eso tiene que seguir su camino.
      raise if e.is_a?(SystemExit) || e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
      begin
        sprite.setBitmap("")
      rescue Exception
        nil
      end
      return e.message.to_s
    end
  end

  # RGSS alinea con 0, 1 y 2. En el diseño se escribe con palabras.
  def self.alineacion(nombre)
    case nombre.to_s
    when "centro"  then 1
    when "derecha" then 2
    else                0
    end
  end

  #-----------------------------------------------------------------------------
  # DONDE EMPIEZA Y ACABA LA TINTA DE LA LETRA, MEDIDO DE VERDAD.
  #
  # POR QUE HAY QUE MEDIRLO Y NO SE PUEDE CALCULAR
  #   draw_text de este motor hace esto (esta en los scripts del juego):
  #
  #       def draw_text(x, y, width, height = nil, text = "", align = 0)
  #         y -= (@text_offset_y || 0)
  #         height = text_size(text).height      # <- TIRA el alto que le pasas
  #         mkxp_draw_text(x, y, width, height, text, align)
  #       end
  #
  #   O sea que NO centra en la caja que le das: pega el texto arriba, en la y.
  #   Y text_size devuelve la "caja de linea" de la fuente, que incluye el hueco
  #   que Power Green reserva para tildes y colas, repartido de forma desigual.
  #   Centrar esa caja NO centra la letra que se ve.
  #
  #   Asi que se pinta una muestra en un bitmap aparte y se mira, fila a fila,
  #   donde empieza y acaba la tinta. Es la unica manera de saberlo sin adivinar,
  #   y ya se adivino dos veces (una quedo alto y otra bajo).
  #
  #   Se hace UNA VEZ por tamaño de letra y se guarda. La muestra es fija a
  #   proposito (no el texto de cada elemento): asi todos los textos comparten la
  #   misma linea base y no bailan segun lleven o no una "g".
  #-----------------------------------------------------------------------------
  MUESTRA_METRICA = "AXgy"          # mayuscula alta y cola baja, para coger todo

  def self.metricas(tamano)
    @metricas ||= {}
    guardada = @metricas[tamano]
    return guardada if guardada

    alto_probeta = (tamano * 3) + 8
    b = Bitmap.new((tamano * 6) + 8, alto_probeta)
    fuente(b, tamano)
    b.font.color = Color.new(255, 255, 255)
    b.draw_text(0, 0, b.width, tamano, MUESTRA_METRICA, 0)

    arriba = nil
    abajo = nil
    fila = 0
    while fila < alto_probeta
      col = 0
      hay = false
      while col < b.width
        if b.get_pixel(col, fila).alpha > 0
          hay = true
          break
        end
        col += 2                     # de dos en dos: basta para detectar tinta
      end
      if hay
        arriba = fila if arriba.nil?
        abajo = fila
      end
      fila += 1
    end
    b.dispose

    if arriba.nil?
      # La fuente no pinto nada (¿tamaño 0?). Se cae a algo razonable en vez de
      # dividir por cero.
      arriba = 0
      abajo = tamano
    end
    @metricas[tamano] = { :arriba => arriba, :abajo => abajo, :alto => abajo - arriba + 1 }
    return @metricas[tamano]
  end

  #-----------------------------------------------------------------------------
  # Escribe un texto dentro de una caja, colocandolo por la TINTA.
  #
  # "Centrado" quiere decir que lo que se VE queda centrado, no que lo quede una
  # caja invisible de la fuente. El editor hace la misma cuenta con la tinta que
  # mide el canvas, asi que los dos colocan igual.
  #-----------------------------------------------------------------------------
  def self.escribir(b, txt, x, y, ancho, alto, opciones = {})
    return 0 if txt.to_s.empty?
    al     = alineacion(opciones[:alineacion])
    av     = opciones[:vertical].to_s
    nudge  = opciones[:desplazar].to_i
    color  = opciones[:color]
    sombra = opciones[:sombra]

    m = metricas(b.font.size)
    # ty es la y que hay que pasarle a draw_text para que la TINTA caiga donde se
    # quiere. Como draw_text pega el texto en la y, la tinta acaba en
    # ty+arriba .. ty+abajo.
    ty = case av
         when "arriba" then -m[:arriba]
         when "abajo"  then alto - m[:abajo] - 1
         else               ((alto - m[:alto]) / 2.0).round - m[:arriba]
         end
    ty += nudge

    if sombra
      if opciones[:contorno]
        # Contorno completo: el texto rodeado por los ocho lados. Cuesta ocho
        # pasadas mas, pero se hace una sola vez al crear el elemento y es lo que
        # hace que un texto claro se lea sobre CUALQUIER fondo, que es justo
        # donde una sombra sola se queda corta.
        b.font.color = sombra
        [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]].each do |dx, dy|
          b.draw_text(x + dx, y + ty + dy, ancho, alto, txt, al)
        end
      else
        b.font.color = sombra
        b.draw_text(x + 1, y + ty + 1, ancho, alto, txt, al)
      end
    end
    b.font.color = color if color
    b.draw_text(x, y + ty, ancho, alto, txt, al)
    return m[:alto]
  end

  #-----------------------------------------------------------------------------
  # Un rectangulo con borde. Los menus de Pokemon casi nunca son un color plano:
  # llevan marco, y eso solo ya cambia mucho como se ve una pantalla.
  #-----------------------------------------------------------------------------
  def self.recuadro(b, x, y, ancho, alto, relleno, borde = nil, grosor = 1)
    b.fill_rect(x, y, ancho, alto, relleno) if relleno
    return if borde.nil? || grosor <= 0
    g = [grosor, [ancho, alto].min / 2].min
    g = 1 if g < 1
    b.fill_rect(x, y, ancho, g, borde)                    # arriba
    b.fill_rect(x, y + alto - g, ancho, g, borde)         # abajo
    b.fill_rect(x, y, g, alto, borde)                     # izquierda
    b.fill_rect(x + ancho - g, y, g, alto, borde)         # derecha
  end

  #=============================================================================
  # Base comun.
  #=============================================================================
  class Elemento
    attr_reader :id, :datos, :capa

    # Fabrica: del tipo del diseño a la clase que toca. El tipo ya viene
    # comprobado por el Lector, asi que aqui no hace falta defenderse.
    def self.construir(datos, viewport, avisos)
      clase = case datos["tipo"].to_s
              when "imagen"  then Imagen
              when "texto"   then Texto
              when "boton"   then Boton
              when "panel"   then Panel
              when "animado" then Animado
              when "barra"   then Barra
              when "pokemon" then PokemonSprite
              end
      return clase.new(datos, viewport, avisos)
    end

    def initialize(datos, viewport, avisos)
      @datos    = datos
      @viewport = viewport
      @avisos   = avisos
      @id       = datos["id"].to_s
      @capa     = datos["capa"].to_i
      @sprite   = nil

      # Valores de reposo: donde esta el elemento cuando no lo anima nada.
      @reposo = {
        "x"        => datos["x"].to_f,
        "y"        => datos["y"].to_f,
        "opacidad" => datos["opacidad"].nil? ? 255.0 : datos["opacidad"].to_f,
        "zoom"     => datos["zoom"].nil? ? 1.0 : datos["zoom"].to_f,
        "angulo"   => datos["angulo"].to_f
      }

      @entrada = {}      # propiedad => Tween
      @pistas  = {}      # propiedad => Pista
    end

    def sprite
      @sprite
    end

    def ancho
      return @datos["ancho"].to_i if @datos["ancho"]
      return 0 if !@sprite || @sprite.disposed? || !@sprite.bitmap
      return @sprite.bitmap.width
    end

    def alto
      return @datos["alto"].to_i if @datos["alto"]
      return 0 if !@sprite || @sprite.disposed? || !@sprite.bitmap
      return @sprite.bitmap.height
    end

    #---------------------------------------------------------------------------
    # Ciclo de vida. crear_sprite lo pone cada subclase.
    #---------------------------------------------------------------------------
    def crear(ahora)
      crear_sprite
      preparar_animaciones(ahora)
      actualizar(ahora)
    end

    def crear_sprite
      raise "crear_sprite sin implementar en #{self.class}"
    end

    def soltar
      @sprite.dispose if @sprite && !@sprite.disposed?
      @sprite = nil
    end

    #---------------------------------------------------------------------------
    # Animacion.
    #---------------------------------------------------------------------------
    def preparar_animaciones(ahora)
      preparar_entrada(ahora)
      preparar_pistas(ahora)
    end

    # Traduce un efecto del catalogo a tweens sobre propiedades. El catalogo
    # existe para no obligar a nadie a montar claves a mano para algo tan comun
    # como "que aparezca desde arriba".
    def preparar_entrada(ahora)
      ent = @datos["entrada"]
      return if !ent.is_a?(Hash)
      efecto  = (ent["efecto"] || "aparece").to_s
      dur     = (ent["duracion"] || Interfaces::ENTRADA_DURACION).to_f
      curva   = (ent["suavizado"] || Interfaces::SUAVIZADO_DEFECTO).to_s
      retraso = (ent["retraso"] || 0.0).to_f
      dist    = (ent["distancia"] || Interfaces::DESLIZA_DISTANCIA).to_f

      case efecto
      when "desde_arriba"
        @entrada["y"] = Tween.new(@reposo["y"] - dist, @reposo["y"], dur, curva, retraso)
      when "desde_abajo"
        @entrada["y"] = Tween.new(@reposo["y"] + dist, @reposo["y"], dur, curva, retraso)
      when "desde_izquierda"
        @entrada["x"] = Tween.new(@reposo["x"] - dist, @reposo["x"], dur, curva, retraso)
      when "desde_derecha"
        @entrada["x"] = Tween.new(@reposo["x"] + dist, @reposo["x"], dur, curva, retraso)
      when "crece"
        @entrada["zoom"] = Tween.new(0.0, @reposo["zoom"], dur, curva, retraso)
      when "gira"
        @entrada["angulo"] = Tween.new(@reposo["angulo"] - 180.0, @reposo["angulo"], dur, curva, retraso)
      end

      # Todos los efectos entran ADEMAS apareciendo, incluidos los de deslizar:
      # sin eso, un elemento que viene de fuera se ve surgir de golpe en el borde
      # de la pantalla, que queda peor que no animar nada.
      @entrada["opacidad"] = Tween.new(0.0, @reposo["opacidad"], dur, curva, retraso)

      @entrada.each_value { |t| t.empezar(ahora) }
    end

    def preparar_pistas(ahora)
      lista = @datos["animaciones"]
      return if !lista.is_a?(Array)
      lista.each do |p|
        pista = Pista.new(p["propiedad"], p["claves"], p["bucle"])
        next if pista.vacia?
        pista.empezar(ahora)
        @pistas[pista.propiedad] = pista
      end
    end

    # El valor de una propiedad AHORA, decidiendo quien manda.
    def valor_de(propiedad, ahora)
      tw = @entrada[propiedad]
      return tw.valor(ahora) if tw && !tw.terminado?(ahora)
      pista = @pistas[propiedad]
      return pista.valor(ahora) if pista
      return tw.valor(ahora) if tw            # entrada acabada y sin pista: se queda
      return @reposo[propiedad]
    end

    # Correccion entre donde dice el diseño que esta el elemento y donde hay que
    # poner el sprite. Casi siempre 0; el texto la usa porque su bitmap lleva un
    # colchon alrededor para que no se recorten las letras.
    def ajuste_x; return 0; end
    def ajuste_y; return 0; end

    def actualizar(ahora)
      return if !@sprite || @sprite.disposed?
      @sprite.x       = valor_de("x", ahora).round + ajuste_x
      @sprite.y       = valor_de("y", ahora).round + ajuste_y
      @sprite.opacity = valor_de("opacidad", ahora).round
      @sprite.angle   = valor_de("angulo", ahora)
      z = valor_de("zoom", ahora)
      @sprite.zoom_x  = z
      @sprite.zoom_y  = z
      @sprite.z       = @capa
      @sprite.visible = @datos["visible"].nil? ? true : !!@datos["visible"]
      @sprite.update if @sprite.respond_to?(:update)
    end

    # Cuanto tarda en terminar todo lo que este elemento tiene animado. Lo usa la
    # escena para saber cuando ha acabado de entrar la pantalla entera.
    def duracion_entrada
      return 0.0 if @entrada.empty?
      return @entrada.values.map { |t| t.duracion_total }.max
    end

    #---------------------------------------------------------------------------

    def avisar(texto)
      @avisos << "\"#{@id}\": #{texto}"
    end

    # Lee un color del diseño avisando si esta mal escrito.
    def color_de(clave, defecto)
      bruto = @datos[clave]
      return Interfaces.color(defecto) if bruto.nil?
      c = Interfaces.color(bruto)
      if c.nil?
        avisar("el color #{bruto.inspect} de #{clave} no se entiende, tiene que ser tipo \"#RRGGBB\"")
        return Interfaces.color(defecto)
      end
      return c
    end
  end

  #=============================================================================
  # Imagen: un PNG puesto en un sitio.
  #=============================================================================
  class Imagen < Elemento
    def crear_sprite
      @sprite = IconSprite.new(0, 0, @viewport)
      ruta = @datos["imagen"].to_s
      return if ruta.empty?
      fallo = Interfaces.poner_imagen(@sprite, ruta)
      avisar("no he podido cargar #{ruta}: #{fallo}") if fallo
    end
  end

  #=============================================================================
  # Panel: un rectangulo de color. Para fondos y separadores sin gastar un PNG.
  #=============================================================================
  class Panel < Elemento
    def crear_sprite
      w = [@datos["ancho"].to_i, 1].max
      h = [@datos["alto"].to_i, 1].max
      @sprite = BitmapSprite.new(w, h, @viewport)
      borde = @datos["borde"] ? color_de("borde", "#FFFFFF") : nil
      Interfaces.recuadro(@sprite.bitmap, 0, 0, w, h,
                          color_de("color", "#000000"), borde,
                          @datos["borde_grosor"].nil? ? 1 : @datos["borde_grosor"].to_i)
    end

    def ancho
      return [@datos["ancho"].to_i, 1].max
    end

    def alto
      return [@datos["alto"].to_i, 1].max
    end
  end

  #=============================================================================
  # Texto.
  #
  # Se dibuja a mano en un bitmap propio (fuente, sombra, alineado) en vez de
  # usar una ventana de Essentials, porque una ventana trae su marco y sus
  # margenes y aqui hace falta poder poner el texto exactamente donde diga el
  # diseño.
  #=============================================================================
  class Texto < Elemento
    # Colchon invisible alrededor del texto. Tiene que ser MAYOR que el
    # FONT_Y_OFFSET del motor (8) para que, aunque algo desplace el dibujo, la
    # letra caiga dentro del bitmap y no se recorte. Sobra sitio transparente y
    # eso no se ve; que se corte una letra si se ve.
    MARGEN = 12

    def crear_sprite
      txt    = Interfaces::Datos.rellenar(@datos["texto"])
      @vivo  = Interfaces::Datos.tiene_datos?(@datos["texto"])
      @ultimo_txt = txt
      tamano = @datos["tamano"].to_i
      tamano = Interfaces::TEXTO_TAMANO if tamano <= 0

      @caja_w = @datos["ancho"].to_i
      @caja_h = @datos["alto"].to_i
      @caja_w, @caja_h = medir(txt, tamano, @caja_w, @caja_h)

      @sprite = BitmapSprite.new(@caja_w + (MARGEN * 2), @caja_h + (MARGEN * 2), @viewport)
      b = Interfaces.fuente(@sprite.bitmap, tamano)

      Interfaces.escribir(b, txt, MARGEN, MARGEN, @caja_w, @caja_h,
                          :alineacion => @datos["alineacion"],
                          :vertical   => @datos["alineacion_vertical"] || "centro",
                          :desplazar  => @datos["desplazar_y"],
                          :contorno   => @datos["contorno"],
                          :color      => color_de("color", Interfaces::TEXTO_COLOR),
                          :sombra     => color_de("sombra", Interfaces::TEXTO_SOMBRA))
    end

    # El bitmap lleva colchon por los cuatro lados, asi que hay que correr el
    # sprite para que la CAJA quede donde dice el diseño y no el colchon.
    def ajuste_x; return -MARGEN; end
    def ajuste_y; return -MARGEN; end

    # Un texto con datos del juego se vuelve a pintar cuando el dato cambia. Se
    # mira SOLO si el texto lleva llaves, y solo unas pocas veces por segundo: un
    # texto fijo no se repinta nunca, y uno con datos no necesita ir a 60 por
    # segundo para que la vida se vea bajar.
    REVISAR_CADA = 0.15

    def actualizar(ahora)
      super
      return if !@vivo || !@sprite || @sprite.disposed?
      @proxima ||= 0.0
      return if ahora < @proxima
      @proxima = ahora + REVISAR_CADA
      nuevo = Interfaces::Datos.rellenar(@datos["texto"])
      return if nuevo == @ultimo_txt
      @ultimo_txt = nuevo
      repintar(nuevo)
    end

    def repintar(txt)
      tamano = @datos["tamano"].to_i
      tamano = Interfaces::TEXTO_TAMANO if tamano <= 0
      b = @sprite.bitmap
      b.clear
      Interfaces.fuente(b, tamano)
      Interfaces.escribir(b, txt, MARGEN, MARGEN, @caja_w, @caja_h,
                          :alineacion => @datos["alineacion"],
                          :vertical   => @datos["alineacion_vertical"] || "centro",
                          :desplazar  => @datos["desplazar_y"],
                          :contorno   => @datos["contorno"],
                          :color      => color_de("color", Interfaces::TEXTO_COLOR),
                          :sombra     => color_de("sombra", Interfaces::TEXTO_SOMBRA))
    end

    # Si el diseño no dice el tamaño de la caja, se mide el texto. Asi un texto
    # recien puesto en el editor ya se ve entero sin tener que ajustar nada.
    def medir(txt, tamano, w, h)
      if w <= 0 || h <= 0
        regla = Bitmap.new(1, 1)
        Interfaces.fuente(regla, tamano)
        medida = regla.text_size(txt)
        if w <= 0
          w = medida.width + 4
          # Un texto con datos del juego cambia de largo mientras se juega: hoy
          # pone "1500" y mañana "999999". Se le da la mitad mas de sitio para que
          # el valor nuevo no salga apretado. Lo suyo es ponerle un ancho a mano,
          # y por eso el editor lo avisa.
          w = (w * 1.5).round if @vivo
        end
        # text_size se queda corto con las colas de la g, la j y la p, asi que se
        # toma lo que mas de las dos medidas.
        h = [medida.height, tamano + 4].max if h <= 0
        regla.dispose
      end
      return [w, 1].max, [h, 1].max
    end

    def ancho
      return @caja_w.to_i
    end

    def alto
      return @caja_h.to_i
    end
  end

  #=============================================================================
  # Animado: una hoja de sprites que se reproduce sola.
  #=============================================================================
  class Animado < Elemento
    def crear_sprite
      ruta = @datos["imagen"].to_s
      if ruta.empty?
        @sprite = BitmapSprite.new(1, 1, @viewport)
        return
      end
      n   = [@datos["fotogramas"].to_i, 1].max
      vel = [@datos["velocidad"].to_i, 1].max
      fw  = @datos["ancho_fotograma"].to_i
      fh  = @datos["alto_fotograma"].to_i

      # SE COMPRUEBA ANTES DE CONSTRUIR, Y NO ES POR GUSTO.
      #
      # AnimatedSprite crea su Sprite con super(viewport) y DESPUES valida que el
      # ancho de la imagen sea multiplo del ancho de fotograma. Si esa validacion
      # falla, la excepcion sale cuando el sprite y su bitmap ya existen dentro del
      # viewport, y como la asignacion a @sprite nunca llego a hacerse, no queda
      # ninguna referencia con la que soltarlos: se filtran hasta que el recolector
      # los alcance, si es que llega. En un HUD que se abre muchas veces eso se
      # acumula.
      #
      # Midiendo la imagen aqui, la excepcion no llega a producirse.
      fallo = validar(ruta, fw, fh)
      if fallo
        avisar("no puedo animar #{ruta}: #{fallo}")
        @sprite = BitmapSprite.new(1, 1, @viewport)
        return
      end

      begin
        @sprite = if fw > 0 && fh > 0
                    AnimatedSprite.new(ruta, n, fw, fh, vel, @viewport)
                  else
                    # Sin medidas, la forma corta las deduce de la imagen.
                    AnimatedSprite.create(ruta, n, vel, @viewport)
                  end
        @sprite.play
      rescue Exception => e
        raise if e.is_a?(SystemExit) || e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
        # Red de seguridad por si queda algun caso que la comprobacion no cubra.
        avisar("no puedo animar #{ruta}: #{e.message}")
        @sprite = BitmapSprite.new(1, 1, @viewport)
      end
    end

    # Devuelve el motivo por el que esta imagen NO se puede animar, o nil si vale.
    # Mide la imagen en un bitmap aparte que se suelta siempre.
    def validar(ruta, fw, fh)
      return "no encuentro la imagen" if !pbResolveBitmap(ruta)
      return nil if fw <= 0 || fh <= 0        # sin medidas, las deduce el motor
      medida = nil
      begin
        medida = AnimatedBitmap.new(ruta)
        w = medida.width
        h = medida.height
        return "la imagen mide #{w}x#{h} y el ancho no es multiplo de #{fw}" if (w % fw) != 0
        return "la imagen mide #{w}x#{h} y el alto no es multiplo de #{fh}" if (h % fh) != 0
        return nil
      rescue Exception => e
        raise if e.is_a?(SystemExit) || e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
        return e.message.to_s
      ensure
        medida.dispose if medida && !medida.disposed?
      end
    end
  end

  #=============================================================================
  # Barra: una barra que se llena segun un dato del juego.
  #
  # Es LA pieza que faltaba para poder replicar una caja de datos de combate o una
  # ficha de equipo. El valor y el maximo pueden venir de datos:
  #
  #   "valor": "{equipo.1.hp}", "maximo": "{equipo.1.hp_max}"
  #
  # Por defecto cambia de color como las barras de vida de Pokemon (verde, amarillo
  # y rojo segun lo que quede), porque es lo que espera cualquiera que vea una
  # barra en este juego. Se puede apagar con "por_tramos": false.
  #=============================================================================
  class Barra < Elemento
    # Los cortes de las barras de vida de Pokemon: por debajo de la mitad se pone
    # amarilla y por debajo de un cuarto, roja.
    TRAMO_MEDIO = 0.5
    TRAMO_BAJO  = 0.25

    COLOR_ALTO  = "#68D076FF"
    COLOR_MEDIO = "#E8A830FF"
    COLOR_BAJO  = "#E24234FF"

    def crear_sprite
      @w = [@datos["ancho"].to_i, 1].max
      @h = [@datos["alto"].to_i, 1].max
      @sprite = BitmapSprite.new(@w, @h, @viewport)
      @ultimo = nil
      pintar
    end

    def ancho; return @w.to_i; end
    def alto;  return @h.to_i; end

    # Cuanto esta llena, de 0 a 1.
    def fraccion
      v = Interfaces::Datos.numero(sin_llaves(@datos["valor"]))
      m = Interfaces::Datos.numero(sin_llaves(@datos["maximo"]))
      m = 100.0 if m <= 0                      # sin maximo, se trata como porcentaje
      f = v / m
      return 0.0 if f < 0.0
      return 1.0 if f > 1.0
      return f
    end

    # "{equipo.1.hp}" -> "equipo.1.hp". Se permite escribirlo con o sin llaves,
    # porque en un campo que SOLO admite un dato las llaves son ruido.
    def sin_llaves(v)
      s = v.to_s.strip
      return s[1..-2].to_s if s.start_with?("{") && s.end_with?("}")
      return s
    end

    def color_actual(f)
      return color_de("color", COLOR_ALTO) if @datos["por_tramos"] == false
      return color_de("color_bajo", COLOR_BAJO)   if f <= TRAMO_BAJO
      return color_de("color_medio", COLOR_MEDIO) if f <= TRAMO_MEDIO
      return color_de("color", COLOR_ALTO)
    end

    def pintar
      f = fraccion
      b = @sprite.bitmap
      b.clear
      grosor = @datos["borde_grosor"].nil? ? 1 : @datos["borde_grosor"].to_i
      borde = @datos["borde"] ? color_de("borde", "#FFFFFF") : nil
      Interfaces.recuadro(b, 0, 0, @w, @h, color_de("color_fondo", "#20242BFF"), borde, grosor)

      dentro = borde ? grosor : 0
      util_w = @w - (dentro * 2)
      util_h = @h - (dentro * 2)
      return if util_w <= 0 || util_h <= 0

      largo = (util_w * f).round
      largo = 1 if largo < 1 && f > 0            # que se vea que queda algo
      return if largo <= 0

      if @datos["hacia"].to_s == "izquierda"
        # Las barras del rival crecen al reves en muchos juegos.
        b.fill_rect(dentro + util_w - largo, dentro, largo, util_h, color_actual(f))
      else
        b.fill_rect(dentro, dentro, largo, util_h, color_actual(f))
      end
      @ultimo = f
    end

    # Se repinta SOLO si el valor cambio. Rehacer el bitmap en cada fotograma seria
    # tirar trabajo: una barra de vida no cambia sesenta veces por segundo.
    def actualizar(ahora)
      super
      return if !@sprite || @sprite.disposed?
      f = fraccion
      pintar if @ultimo.nil? || (f - @ultimo).abs > 0.001
    end
  end

  #=============================================================================
  # Pokemon: enseña un Pokemon del equipo.
  #
  #   "cual": 1        el primero del equipo (1 es el primero, como cuenta la gente)
  #   "modo": "icono"  el iconito de la lista, o "frente" / "espalda"
  #
  # Sin esto no se puede replicar ninguna pantalla que enseñe Pokemon, que son
  # justo las que mas se quieren rehacer.
  #=============================================================================
  class PokemonSprite < Elemento
    def crear_sprite
      @sprite = IconSprite.new(0, 0, @viewport)
      @cual = @datos["cual"].to_i
      @cual = 1 if @cual <= 0
      @modo = (@datos["modo"] || "icono").to_s
      poner
    end

    def pokemon
      return Interfaces::Datos.del_equipo(@cual)
    end

    def ruta_de(pkmn)
      return nil if pkmn.nil?
      case @modo
      when "frente"
        return GameData::Species.front_sprite_filename(pkmn.species, pkmn.form, pkmn.gender, pkmn.shiny?)
      when "espalda"
        return GameData::Species.back_sprite_filename(pkmn.species, pkmn.form, pkmn.gender, pkmn.shiny?)
      else
        return GameData::Species.icon_filename_from_pokemon(pkmn)
      end
    end

    def poner
      pkmn = pokemon
      @especie_puesta = pkmn ? [pkmn.species, pkmn.form, pkmn.shiny?] : nil
      if pkmn.nil?
        # Ese puesto del equipo esta vacio. No es un error: una pantalla puede
        # tener seis huecos y el jugador llevar tres.
        @sprite.setBitmap("") rescue nil
        @sprite.visible = false
        return
      end
      @sprite.visible = true
      ruta = ruta_de(pkmn)
      if ruta.nil? || !pbResolveBitmap(ruta)
        avisar("no encuentro el grafico del Pokemon #{@cual} (#{@modo})")
        @sprite.visible = false
        return
      end
      fallo = Interfaces.poner_imagen(@sprite, ruta)
      if fallo
        avisar("no he podido cargar #{ruta}: #{fallo}")
        @sprite.visible = false
        return
      end
      # Los iconos son una tira de fotogramas: se enseña solo el primero, que si
      # no saldria el Pokemon estirado con todas sus poses seguidas.
      if @modo == "icono" && @sprite.bitmap
        alto = @sprite.bitmap.height
        @sprite.src_rect.set(0, 0, alto, alto) if @sprite.bitmap.width > alto
      end
    end

    # Si cambia el Pokemon de ese puesto (se cambia el orden, evoluciona, entra
    # otro), se vuelve a poner. Se compara lo minimo para no rehacerlo sin motivo.
    def actualizar(ahora)
      super
      return if !@sprite || @sprite.disposed?
      pkmn = pokemon
      ahora_es = pkmn ? [pkmn.species, pkmn.form, pkmn.shiny?] : nil
      poner if ahora_es != @especie_puesta
    end
  end

  #=============================================================================
  # Boton: una imagen que reacciona al raton y hace algo al pulsarla.
  #
  # Tres estados, cada uno con su imagen opcional: normal, encima y pulsado. Si
  # no hay imagen para un estado se usa la normal, asi que un boton de una sola
  # imagen tambien vale.
  #=============================================================================
  class Boton < Elemento
    attr_reader :estado

    # Dos modos:
    #   con imagen  una imagen por estado (las que falten usan la normal)
    #   sin imagen  un rectangulo de color, tambien uno por estado
    #
    # El modo de color existe para poder montar una pantalla ENTERA antes de haber
    # dibujado nada. Prototipar sin depender del arte es la diferencia entre
    # probar una idea hoy o dentro de una semana.
    def crear_sprite
      @estado = :normal
      @rutas = {
        :normal  => @datos["imagen"].to_s,
        :encima  => @datos["imagen_encima"].to_s,
        :pulsado => @datos["imagen_pulsado"].to_s
      }
      @por_color = @rutas[:normal].empty?

      if @por_color
        w = [@datos["ancho"].to_i, 1].max
        h = [@datos["alto"].to_i, 1].max
        @sprite = BitmapSprite.new(w, h, @viewport)
        @colores = {
          :normal  => color_de("color", "#3C6E9BFF"),
          :encima  => color_de("color_encima", "#5A96C8FF"),
          :pulsado => color_de("color_pulsado", "#28506FFF")
        }
      else
        @sprite = IconSprite.new(0, 0, @viewport)
      end
      pintar_estado(:normal)
    end

    # Solo se llama al CAMBIAR de estado, nunca cada fotograma: setBitmap crea un
    # AnimatedBitmap nuevo, y hacerlo 60 veces por segundo seria absurdo.
    def pintar_estado(estado)
      if @por_color
        b = @sprite.bitmap
        b.clear
        # El borde se aclara al pasar por encima y se apaga al pulsar: da la
        # sensacion de que el boton responde, sin necesidad de tener arte.
        borde = if @datos["borde"]
                  case estado
                  when :encima  then color_de("borde_encima", @datos["borde"])
                  when :pulsado then color_de("borde_pulsado", @datos["borde"])
                  else               color_de("borde", "#FFFFFF")
                  end
                end
        Interfaces.recuadro(b, 0, 0, b.width, b.height, @colores[estado], borde,
                            @datos["borde_grosor"].nil? ? 1 : @datos["borde_grosor"].to_i)
        etiqueta(b) if !@datos["texto"].to_s.empty?
      else
        ruta = @rutas[estado]
        ruta = @rutas[:normal] if ruta.nil? || ruta.empty?
        if !ruta.nil? && !ruta.empty?
          fallo = Interfaces.poner_imagen(@sprite, ruta)
          # Solo se avisa una vez por boton: si no, un boton con la imagen mala
          # llenaria la lista de avisos cada vez que pasas el raton por encima.
          if fallo && !@aviso_imagen
            @aviso_imagen = true
            avisar("no he podido cargar #{ruta}: #{fallo}")
          end
        end
      end
    end

    # Un boton de color puede llevar su texto dentro, que es lo natural: si no,
    # habria que poner un texto encima a mano y cuadrarlo cada vez que se mueve.
    #
    # Se dibuja centrado en TODA la caja del boton y sin cuentas a mano. Antes se
    # calculaba una y a ojo para compensar el desplazamiento de la fuente; con el
    # offset ya a cero (ver Interfaces.fuente) eso sobra, y ademas cuadra con lo
    # que enseña el editor, que tambien centra en la caja.
    def etiqueta(b)
      tamano = @datos["tamano"].to_i
      tamano = Interfaces::TEXTO_TAMANO if tamano <= 0
      Interfaces.fuente(b, tamano)
      Interfaces.escribir(b, @datos["texto"].to_s, 0, 0, b.width, b.height,
                          :alineacion => @datos["alineacion"] || "centro",
                          :vertical   => @datos["alineacion_vertical"] || "centro",
                          :desplazar  => @datos["desplazar_y"],
                          :contorno   => @datos["contorno"],
                          :color      => color_de("color_texto", Interfaces::TEXTO_COLOR),
                          :sombra     => color_de("sombra", Interfaces::TEXTO_SOMBRA))
    end

    # La zona sensible va donde el boton se VE ahora mismo, no donde dice el
    # diseño: asi un boton que esta entrando deslizandose se pulsa donde esta.
    #
    # Pero SIN contar lo que haya crecido al pasar el raton por encima. Si el area
    # creciera con el boton, al estar el raton justo en el borde entraria (crece),
    # el borde se alejaria, saldria (encoge), el borde volveria... y parpadearia
    # sin parar.
    def zona
      w, h = medida_base
      x = @x_base || (@sprite ? @sprite.x : 0)
      y = @y_base || (@sprite ? @sprite.y : 0)
      return [x, y, w, h]
    end

    # ¿Cae este punto dentro del boton? Recibe las coordenadas ya calculadas por
    # la escena.
    #
    # NO SE USA Mouse.over_area?, Y NO ES CAPRICHO: esa funcion esta ROTA en este
    # proyecto. Hace Rect.new(...) desde dentro del modulo Mouse, y aqui existe un
    # Mouse::Rect (un mixin para la clase Rect de verdad), asi que el nombre
    # resuelve al mixin y revienta con "undefined method `new' for
    # Mouse::Rect:Module". Se comprobo con el juego delante.
    def contiene?(mx, my)
      return false if mx.nil? || my.nil?
      return false if !@sprite || @sprite.disposed?
      return false if !@sprite.visible || @sprite.opacity < 8
      x, y, w, h = zona
      return false if w <= 0 || h <= 0
      return mx >= x && mx < x + w && my >= y && my < y + h
    end

    # Cambia el aspecto segun lo que este pasando y devuelve :entra, :sale o nil,
    # para que la escena ponga los sonidos sin saber como funciona el boton.
    #
    # LOS DOS ARGUMENTOS LOS DECIDE LA ESCENA, no el boton:
    #   dentro    si este es el boton de capa mas alta bajo el raton (si dos se
    #             solapan solo responde el de arriba)
    #   capturado si el jugador apreto el raton estando sobre ESTE boton
    #---------------------------------------------------------------------------
    # CRECER AL PASAR POR ENCIMA.
    #
    # Dos trampas, y las dos se ven feo si no se tienen en cuenta:
    #
    #   1. RGSS escala desde la ESQUINA superior izquierda, asi que un boton que
    #      crece se va hacia la derecha y hacia abajo en vez de hincharse en su
    #      sitio. Se compensa corriendo el sprite la mitad de lo que crece.
    #
    #   2. Saltar del tamaño normal al grande de un fotograma al otro da un tiron.
    #      Se va acercando poco a poco (un 25 % de lo que falta en cada fotograma),
    #      que es suave, no necesita reloj y llega solo.
    #
    # La ZONA SENSIBLE no crece: se queda la de siempre. Si creciera, el borde del
    # boton se movería justo cuando el raton esta en el borde y parpadearia entre
    # grande y pequeño.
    #---------------------------------------------------------------------------
    ACERCAMIENTO = 0.25

    def escala_objetivo
      case @estado
      when :encima  then (@datos["escala_encima"] || 1.0).to_f
      when :pulsado then (@datos["escala_pulsado"] || @datos["escala_encima"] || 1.0).to_f
      else               1.0
      end
    end

    def actualizar(ahora)
      super
      return if !@sprite || @sprite.disposed?

      # Donde esta el boton SIN contar lo que haya crecido. Es lo que usa la zona
      # sensible, para que el area de pulsado no se mueva mientras crece.
      @x_base = @sprite.x
      @y_base = @sprite.y

      @escala ||= 1.0
      destino = escala_objetivo
      @escala += (destino - @escala) * ACERCAMIENTO
      @escala = destino if (destino - @escala).abs < 0.002    # para de temblar
      return if (@escala - 1.0).abs < 0.001

      base = valor_de("zoom", ahora)
      w, h = medida_base
      @sprite.zoom_x = base * @escala
      @sprite.zoom_y = base * @escala
      @sprite.x = @x_base - ((w * base * (@escala - 1.0)) / 2).round
      @sprite.y = @y_base - ((h * base * (@escala - 1.0)) / 2).round
    end

    # Cuanto mide el boton sin escalar.
    def medida_base
      w = @datos["ancho"].to_i
      h = @datos["alto"].to_i
      w = (@sprite && @sprite.bitmap) ? @sprite.bitmap.width : 0 if w <= 0
      h = (@sprite && @sprite.bitmap) ? @sprite.bitmap.height : 0 if h <= 0
      return [w, h]
    end

    def aplicar_raton(dentro, capturado)
      nuevo = if dentro && capturado then :pulsado
              elsif dentro then :encima
              else :normal
              end

      suceso = nil
      if nuevo != @estado
        suceso = :entra if @estado == :normal
        suceso = :sale  if nuevo == :normal
        @estado = nuevo
        pintar_estado(nuevo)
      end
      return suceso
    end

    def accion
      return @datos["accion"]
    end
  end
end
