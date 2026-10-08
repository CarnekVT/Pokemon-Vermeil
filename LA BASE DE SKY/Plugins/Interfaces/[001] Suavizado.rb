#===============================================================================
# Suavizado: las curvas de animacion y el motor de interpolacion.
#
# POR QUE ESTO ES CODIGO NUEVO Y NO SE REUSA NADA
#   En todo Essentials no hay ni un tween ni una curva. Lo unico que existe es
#   lerp(), que es interpolacion LINEAL, y cada animacion del motor (los
#   fundidos, las de DBK) es una clase escrita a mano con su propio update y su
#   propio animDone?. No hay nada generico que reutilizar, asi que el motor de
#   animacion se escribe aqui entero.
#
# COMO MIDE EL TIEMPO
#   Con System.uptime (segundos en coma flotante desde que arranco el motor), que
#   es lo que usan los fundidos y AnimatedBitmap. NO se cuentan fotogramas: asi
#   una animacion de 0,3 s dura 0,3 s aunque el juego pegue un tiron.
#
# DOS NIVELES DE ANIMACION
#   Tween  una sola cosa que va de A a B: lo que usan los efectos de entrada.
#   Pista  una propiedad con varias claves en el tiempo: lo que monta la linea
#          de tiempo del editor.
#===============================================================================

module Interfaces
  #=============================================================================
  # Las curvas.
  #
  # Todas reciben t entre 0 y 1 (cuanto ha avanzado la animacion) y devuelven
  # cuanto ha avanzado el VALOR, tambien de 0 a 1. Una curva puede pasarse de 1 o
  # bajar de 0 a mitad de camino: eso es justo lo que hace que "golpe" y "rebote"
  # se sientan vivos.
  #
  # Los nombres estan en castellano a proposito. En el editor no pone "easeOutBack"
  # ni "cubic-bezier", pone "golpe", porque eso si dice lo que va a pasar.
  #=============================================================================
  module Suavizado
    # Constantes de las curvas clasicas. Los numeros no son inventados: son los
    # de las curvas de Penner, que son las que "se sienten bien" y las que usan
    # las herramientas de animacion desde siempre.
    GOLPE_FUERZA   = 1.70158        # cuanto se pasa "golpe" antes de volver
    REBOTE_N       = 7.5625         # los cuatro botes de "rebote"
    REBOTE_D       = 2.75
    ELASTICO_PERIODO = (2 * Math::PI) / 3.0

    NOMBRES = [
      "lineal",       # a velocidad constante, sin gracia pero predecible
      "suave",        # arranca lento, acelera, frena. El que sirve para todo
      "entra_suave",  # arranca lento y termina a toda velocidad
      "sale_suave",   # arranca rapido y frena al final
      "golpe",        # se pasa de largo y vuelve. Bien para que algo aparezca
      "rebote",       # cae y bota como una pelota
      "elastico"      # se pasa y oscila hasta pararse
    ]

    module_function

    def existe?(nombre)
      NOMBRES.include?(nombre.to_s)
    end

    # Devuelve cuanto ha avanzado el valor (normalmente 0..1, puede salirse).
    # Un nombre desconocido cae en lineal en vez de reventar: mas vale una
    # animacion sosa que una pantalla que no abre.
    def aplicar(nombre, t)
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      case nombre.to_s
      when "suave"       then suave(t)
      when "entra_suave" then t * t * t
      when "sale_suave"  then 1.0 - ((1.0 - t)**3)
      when "golpe"       then golpe(t)
      when "rebote"      then rebote(t)
      when "elastico"    then elastico(t)
      else                    t
      end
    end

    #---------------------------------------------------------------------------

    def suave(t)
      return 4.0 * t * t * t if t < 0.5
      return 1.0 - (((-2.0 * t) + 2.0)**3) / 2.0
    end

    def golpe(t)
      c1 = GOLPE_FUERZA
      c3 = c1 + 1.0
      return 1.0 + (c3 * ((t - 1.0)**3)) + (c1 * ((t - 1.0)**2))
    end

    def rebote(t)
      n = REBOTE_N
      d = REBOTE_D
      if t < 1.0 / d
        return n * t * t
      elsif t < 2.0 / d
        t -= 1.5 / d
        return (n * t * t) + 0.75
      elsif t < 2.5 / d
        t -= 2.25 / d
        return (n * t * t) + 0.9375
      else
        t -= 2.625 / d
        return (n * t * t) + 0.984375
      end
    end

    def elastico(t)
      return 0.0 if t <= 0.0
      return 1.0 if t >= 1.0
      return (2**(-10.0 * t)) * Math.sin(((t * 10.0) - 0.75) * ELASTICO_PERIODO) + 1.0
    end
  end

  #=============================================================================
  # Tween: una cosa que va de A a B en un tiempo, con una curva.
  #
  # No toca sprites: solo sabe decir "en este instante el valor es X". Quien lo
  # usa decide si eso es una x, una opacidad o un angulo. Asi el mismo codigo
  # sirve para todo.
  #=============================================================================
  class Tween
    attr_reader :desde, :hasta, :duracion, :curva, :retraso

    def initialize(desde, hasta, duracion, curva = "lineal", retraso = 0.0)
      @desde    = desde.to_f
      @hasta    = hasta.to_f
      @duracion = duracion.to_f
      @curva    = curva.to_s
      @retraso  = retraso.to_f
      @inicio   = nil
    end

    def empezar(ahora = System.uptime)
      @inicio = ahora
    end

    def empezado?
      !@inicio.nil?
    end

    # Cuanto tiempo lleva de animacion util (descontado el retraso).
    def transcurrido(ahora = System.uptime)
      return 0.0 if !empezado?
      return (ahora - @inicio) - @retraso
    end

    def valor(ahora = System.uptime)
      return @desde if !empezado?
      t = transcurrido(ahora)
      return @desde if t <= 0.0                 # todavia esperando el retraso
      return @hasta if @duracion <= 0.0 || t >= @duracion
      avance = Suavizado.aplicar(@curva, t / @duracion)
      return @desde + ((@hasta - @desde) * avance)
    end

    def terminado?(ahora = System.uptime)
      return false if !empezado?
      return transcurrido(ahora) >= @duracion
    end

    # Duracion total incluyendo la espera, para saber cuanto dura el conjunto.
    def duracion_total
      return @retraso + @duracion
    end
  end

  #=============================================================================
  # Pista: una propiedad con varias claves repartidas en el tiempo.
  #
  # Es lo que dibuja la linea de tiempo del editor. Cada clave lleva el suavizado
  # con el que se LLEGA a ella, que es como funcionan las herramientas de
  # animacion de verdad: la curva describe el tramo que acaba en esa clave.
  #
  #   claves = [ {"t" => 0.0, "valor" => -100},
  #              {"t" => 0.4, "valor" => 20, "suavizado" => "golpe"} ]
  #=============================================================================
  class Pista
    attr_reader :propiedad, :claves, :bucle

    def initialize(propiedad, claves, bucle = false)
      @propiedad = propiedad.to_s
      @bucle     = !!bucle
      # Ordenadas por tiempo: el editor deberia darlas ya en orden, pero si
      # alguien edita el .json a mano no tiene por que acordarse.
      @claves = claves.sort_by { |c| c["t"].to_f }
      @inicio = nil
    end

    def vacia?
      @claves.empty?
    end

    def empezar(ahora = System.uptime)
      @inicio = ahora
    end

    def duracion
      return 0.0 if vacia?
      return @claves.last["t"].to_f
    end

    def valor(ahora = System.uptime)
      return nil if vacia?
      return @claves.first["valor"].to_f if @inicio.nil?

      t = ahora - @inicio
      total = duracion

      if @bucle && total > 0.0
        t = t % total
      elsif t >= total
        return @claves.last["valor"].to_f
      end
      return @claves.first["valor"].to_f if t <= 0.0

      # Buscar el tramo que contiene a t.
      anterior = @claves.first
      @claves.each do |clave|
        ct = clave["t"].to_f
        if ct >= t
          hueco = ct - anterior["t"].to_f
          return clave["valor"].to_f if hueco <= 0.0    # dos claves en el mismo instante
          local = (t - anterior["t"].to_f) / hueco
          curva = clave["suavizado"] || Interfaces::SUAVIZADO_DEFECTO
          avance = Suavizado.aplicar(curva, local)
          desde = anterior["valor"].to_f
          hasta = clave["valor"].to_f
          return desde + ((hasta - desde) * avance)
        end
        anterior = clave
      end
      return @claves.last["valor"].to_f
    end

    def terminado?(ahora = System.uptime)
      return true if vacia?
      return false if @bucle          # una pista en bucle no termina nunca
      return false if @inicio.nil?
      return (ahora - @inicio) >= duracion
    end
  end
end
