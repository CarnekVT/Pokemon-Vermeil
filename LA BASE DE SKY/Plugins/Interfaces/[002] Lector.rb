#===============================================================================
# Lector: carga UI/<nombre>.json, lo analiza y lo comprueba.
#
# POR QUE HAY UN PARSER JSON ESCRITO A MANO AQUI
#   Porque `require "json"` NO se puede usar en este juego, y no es por gusto:
#   la libreria que acompaña al proyecto ("Ruby Library 3.3.0") trae json como
#   extension en C, en x64-mingw-ucrt/json/ext/parser.so, compilada para Ruby 3.3
#   con el runtime mingw-ucrt. El interprete de este juego es
#   x64-msvcrt-ruby310.dll, o sea Ruby 3.1 con msvcrt: dos incompatibilidades a
#   la vez, version de ABI y runtime de C. Y el json moderno ya no incluye la
#   version escrita en Ruby puro (json/pure desaparecio), asi que no hay plan B
#   dentro de la libreria.
#
#   JSON es una gramatica de cuatro reglas. Sale mas barato tenerlo bajo control
#   en cien lineas que depender de que el motor cargue una libreria que no puede.
#   De paso, los mensajes de error son mios, y eso importa: quien usa el editor
#   no programa, y "unexpected token at line 1" no le sirve de nada.
#
# QUE DEVUELVE
#   cargar(nombre) -> [datos, avisos]
#     datos   el Hash de la pantalla, ya comprobado y con los huecos rellenos
#     avisos  lista de textos con problemas que NO impiden abrir la pantalla
#             (una imagen que falta, por ejemplo: puedes estar diseñando antes
#             de dibujar el arte)
#   Si el fichero esta roto de verdad, lanza ErrorPantalla con fichero y linea.
#===============================================================================

module Interfaces
  #=============================================================================
  # El error que se pinta en pantalla. Lleva fichero y linea porque un error sin
  # sitio no se puede arreglar.
  #=============================================================================
  class ErrorPantalla < StandardError
    attr_reader :fichero, :linea

    def initialize(mensaje, fichero = nil, linea = nil)
      @fichero = fichero
      @linea   = linea
      super(mensaje)
    end

    # Una linea corta para el cartel de error.
    def sitio
      return "" if !@fichero
      return @linea ? "#{@fichero}, linea #{@linea}" : @fichero.to_s
    end
  end

  #=============================================================================
  # Analizador de JSON por descenso recursivo.
  #
  # Cubre el JSON entero: objetos, listas, textos con escapes (incluido \uXXXX),
  # numeros con exponente, true, false y null. No acepta cosas que JSON no tiene
  # (comentarios, comas de sobra al final) porque si el editor las escribiera
  # seria un fallo del editor, y prefiero enterarme.
  #=============================================================================
  class AnalizadorJSON
    def self.analizar(texto, fichero = "?")
      new(texto, fichero).analizar
    end

    def initialize(texto, fichero = "?")
      @t = texto.to_s
      # Quitar la marca de orden de bytes: muchos editores de Windows la ponen y
      # sin esto el primer caracter no seria la llave de apertura.
      @t = @t[1..-1] if !@t.empty? && @t[0] == "﻿"
      @fichero = fichero
      @i = 0
    end

    def analizar
      espacios
      fallo("el fichero esta vacio") if fin?
      v = valor
      espacios
      fallo("sobra texto despues del final del diseño") if !fin?
      return v
    end

    private

    def fin?
      @i >= @t.length
    end

    def act
      @t[@i]
    end

    # Se calcula solo cuando hay un error, asi que no importa que recorra.
    def linea
      return @t[0, @i].count("\n") + 1
    end

    def fallo(mensaje)
      raise ErrorPantalla.new(mensaje, @fichero, linea)
    end

    def espacios
      @i += 1 while !fin? && (act == " " || act == "\t" || act == "\n" || act == "\r")
    end

    def valor
      espacios
      fallo("falta un valor") if fin?
      case act
      when "{" then objeto
      when "[" then lista
      when '"' then texto
      when "t" then literal("true", true)
      when "f" then literal("false", false)
      when "n" then literal("null", nil)
      else
        return numero if act == "-" || (act >= "0" && act <= "9")
        fallo("no entiendo que es #{act.inspect} aqui")
      end
    end

    def literal(palabra, devuelve)
      fallo("esperaba #{palabra}") if @t[@i, palabra.length] != palabra
      @i += palabra.length
      return devuelve
    end

    def objeto
      @i += 1                      # la {
      h = {}
      espacios
      if act == "}"
        @i += 1
        return h
      end
      loop do
        espacios
        fallo("las claves de un objeto van entre comillas") if act != '"'
        clave = texto
        espacios
        fallo("falta el : despues de \"#{clave}\"") if act != ":"
        @i += 1
        h[clave] = valor
        espacios
        fallo("falta una , o una } en el objeto") if fin?
        if act == ","
          @i += 1
          next
        elsif act == "}"
          @i += 1
          return h
        else
          fallo("esperaba , o } y hay #{act.inspect}")
        end
      end
    end

    def lista
      @i += 1                      # la [
      a = []
      espacios
      if act == "]"
        @i += 1
        return a
      end
      loop do
        a << valor
        espacios
        fallo("falta una , o una ] en la lista") if fin?
        if act == ","
          @i += 1
          next
        elsif act == "]"
          @i += 1
          return a
        else
          fallo("esperaba , o ] y hay #{act.inspect}")
        end
      end
    end

    def texto
      @i += 1                      # la comilla de apertura
      salida = ""
      loop do
        fallo("un texto se queda sin cerrar la comilla") if fin?
        c = act
        if c == '"'
          @i += 1
          return salida
        elsif c == "\\"
          @i += 1
          fallo("una barra invertida se queda sin nada detras") if fin?
          e = act
          @i += 1
          case e
          when '"'  then salida << '"'
          when "\\" then salida << "\\"
          when "/"  then salida << "/"
          when "b"  then salida << "\b"
          when "f"  then salida << "\f"
          when "n"  then salida << "\n"
          when "r"  then salida << "\r"
          when "t"  then salida << "\t"
          when "u"
            hex = @t[@i, 4]
            fallo("un \\u tiene que llevar cuatro digitos") if hex.nil? || hex !~ /\A[0-9a-fA-F]{4}\z/
            @i += 4
            salida << [hex.to_i(16)].pack("U")
          else
            fallo("no conozco el escape \\#{e}")
          end
        else
          salida << c
          @i += 1
        end
      end
    end

    def numero
      inicio = @i
      @i += 1 if act == "-"
      fallo("un numero necesita al menos un digito") if fin? || act < "0" || act > "9"
      @i += 1 while !fin? && act >= "0" && act <= "9"
      decimal = false
      if !fin? && act == "."
        decimal = true
        @i += 1
        fallo("falta el decimal despues del punto") if fin? || act < "0" || act > "9"
        @i += 1 while !fin? && act >= "0" && act <= "9"
      end
      if !fin? && (act == "e" || act == "E")
        decimal = true
        @i += 1
        @i += 1 if !fin? && (act == "+" || act == "-")
        fallo("falta el exponente despues de la e") if fin? || act < "0" || act > "9"
        @i += 1 while !fin? && act >= "0" && act <= "9"
      end
      trozo = @t[inicio...@i]
      return decimal ? trozo.to_f : trozo.to_i
    end
  end

  #=============================================================================
  # Lector: del fichero al Hash comprobado.
  #=============================================================================
  module Lector
    TIPOS = ["imagen", "texto", "boton", "panel", "animado", "barra", "pokemon"]
    ALINEACIONES = ["izquierda", "centro", "derecha"]
    VERTICALES = ["arriba", "centro", "abajo"]

    # Las propiedades que se pueden animar con claves. Si alguien escribe otra en
    # el .json es que se equivoco, y mas vale decirselo que ignorarlo en silencio.
    PROPIEDADES = ["x", "y", "opacidad", "zoom", "angulo"]

    # Los de deslizar se llaman "desde_" a proposito: dicen de DONDE viene el
    # elemento, no hacia donde va. "desliza_arriba" se puede leer de las dos
    # maneras y quien use el editor no tiene por que adivinar cual.
    EFECTOS = ["aparece", "desde_arriba", "desde_abajo", "desde_izquierda",
               "desde_derecha", "crece", "gira"]

    module_function

    def ruta(nombre)
      return Interfaces::RUTA_PANTALLAS + nombre.to_s + ".json"
    end

    def existe?(nombre)
      return File.file?(ruta(nombre))
    end

    # Todos los diseños que hay, ordenados. Lo usa el menu de debug para poder
    # abrir cualquiera sin tener que montar un evento.
    def listar
      carpeta = Interfaces::RUTA_PANTALLAS
      return [] if !File.directory?(carpeta)
      # Los que empiezan por _ no son pantallas: queda reservado para ficheros de
      # configuracion que puedan hacer falta mas adelante.
      nombres = Dir.entries(carpeta).select { |f| f =~ /\.json\z/i && f[0, 1] != "_" }
      return nombres.map { |f| f.sub(/\.json\z/i, "") }.sort
    end

    #---------------------------------------------------------------------------
    # CATALOGO DE APERTURAS
    #
    # Lee de cada diseño solo como se abre (titulo, menu de pausa, tecla,
    # interruptor). Se hace UNA VEZ al arrancar, porque el menu de pausa y las
    # teclas se registran al cargar el plugin.
    #
    # REGLA QUE NO SE PUEDE ROMPER: un diseño roto NO puede impedir que el juego
    # arranque. Si un fichero esta mal, se salta y se apunta en @catalogo_malos
    # para poder decirlo en el menu de debug. Dejar al jugador con un juego que
    # no abre por una coma de mas en un fichero de decoracion seria inaceptable.
    #---------------------------------------------------------------------------
    def catalogo
      return @catalogo if @catalogo
      @catalogo = []
      @catalogo_malos = []
      listar.each do |nombre|
        begin
          bruto = File.open(ruta(nombre), "rb") { |f| f.read }.force_encoding("UTF-8")
          datos = AnalizadorJSON.analizar(bruto, ruta(nombre))
          @catalogo.push(aperturas_de(nombre, datos))
        rescue StandardError => e
          @catalogo_malos.push([nombre, e.message])
        end
      end
      return @catalogo
    end

    def catalogo_malos
      catalogo                        # asegura que ya se ha escaneado
      return @catalogo_malos || []
    end

    # Para cuando se guarda un diseño nuevo mientras el juego corre: el menu de
    # debug puede pedir que se relea. El menu de pausa y las teclas NO cambian
    # hasta reiniciar, porque se registran al cargar el plugin.
    def olvidar_catalogo
      @catalogo = nil
      @catalogo_malos = nil
    end

    def aperturas_de(nombre, datos)
      ap = datos["aperturas"]
      ap = {} if !ap.is_a?(Hash)
      titulo = datos["titulo"].to_s
      titulo = nombre if titulo.empty?
      return {
        :nombre      => nombre,
        :titulo      => titulo,
        :menu_pausa  => !!ap["menu_pausa"],
        :orden       => (ap["orden"] || Interfaces::ORDEN_DEFECTO).to_i,
        :tecla       => ap["tecla"].to_s.upcase,
        :interruptor => ap["interruptor"].to_s
      }
    end

    # Que interfaz NUESTRA responde a un interruptor. nil si ninguna.
    def interfaz_de_interruptor(interruptor)
      clave = interruptor.to_s
      return nil if clave.empty?
      encontrada = catalogo.find { |e| e[:interruptor] == clave }
      return encontrada ? encontrada[:nombre] : nil
    end

    #---------------------------------------------------------------------------
    # A donde lleva un interruptor. LA REGLA, en un solo sitio:
    #
    #   MANDA LA PANTALLA TUYA SI EXISTE, Y SI NO, LA DEL JUEGO.
    #
    # Devuelve:
    #   [:interfaz, "mi_mochila"]   una pantalla hecha con el editor
    #   [:integrada, "mochila"]     una de las que ya trae el juego
    #   [:nada, nil]                nadie lo recoge, y eso hay que decirlo
    #---------------------------------------------------------------------------
    def destino_de_interruptor(interruptor)
      clave = interruptor.to_s
      return [:nada, nil] if clave.empty?
      propia = interfaz_de_interruptor(clave)
      return [:interfaz, propia] if propia
      return [:integrada, clave] if Interfaces::INTEGRADAS.key?(clave)
      return [:nada, nil]
    end

    # Los interruptores del juego que el usuario ha reemplazado por una pantalla
    # suya. Lo usa [006] Comandos.rb para secuestrar el menu de pausa, y el menu
    # de debug para poder enseñarlo.
    def integradas_reemplazadas
      salida = {}
      Interfaces::INTEGRADAS.each_key do |clave|
        propia = interfaz_de_interruptor(clave)
        salida[clave] = propia if propia
      end
      return salida
    end

    #---------------------------------------------------------------------------
    # Carga y comprueba. Devuelve [datos, avisos].
    #---------------------------------------------------------------------------
    def cargar(nombre)
      fichero = ruta(nombre)
      if !File.file?(fichero)
        raise ErrorPantalla.new("no encuentro el diseño \"#{nombre}\"", fichero)
      end
      # En binario y forzando UTF-8: asi da igual la configuracion regional de
      # Windows, que si no se cuela en las tildes y en la ñ.
      bruto = File.open(fichero, "rb") { |f| f.read }
      bruto = bruto.force_encoding("UTF-8")
      datos = AnalizadorJSON.analizar(bruto, fichero)

      avisos = []
      comprobar(datos, fichero, avisos)
      return datos, avisos
    end

    #---------------------------------------------------------------------------
    # Comprobaciones. Lo que impide pintar lanza; lo que solo se vera raro avisa.
    #---------------------------------------------------------------------------
    def comprobar(datos, fichero, avisos)
      if !datos.is_a?(Hash)
        raise ErrorPantalla.new("el diseño tiene que ser un objeto { }", fichero)
      end
      elementos = datos["elementos"]
      if elementos.nil?
        raise ErrorPantalla.new("al diseño le falta la lista \"elementos\"", fichero)
      end
      if !elementos.is_a?(Array)
        raise ErrorPantalla.new("\"elementos\" tiene que ser una lista [ ]", fichero)
      end

      datos["nombre"]         ||= "(sin nombre)"
      datos["oscurecer_mapa"] ||= Interfaces::OSCURECER_DEFECTO
      comprobar_aperturas(datos, fichero, avisos)

      vistos = {}
      elementos.each_with_index do |el, i|
        donde = "el elemento #{i + 1}"
        if !el.is_a?(Hash)
          raise ErrorPantalla.new("#{donde} tendria que ser un objeto { }", fichero)
        end

        # Un id que falte no es fatal: se inventa uno. Uno repetido si lo es,
        # porque las animaciones y las acciones se refieren a los elementos por
        # su id y con dos iguales se aplicarian al equivocado.
        el["id"] = "elemento_#{i + 1}" if el["id"].nil? || el["id"].to_s.empty?
        id = el["id"].to_s
        if vistos[id]
          raise ErrorPantalla.new(
            "hay dos elementos con el id \"#{id}\" (#{donde} y el #{vistos[id]}). " \
            "Los ids tienen que ser distintos", fichero)
        end
        vistos[id] = i + 1

        tipo = el["tipo"].to_s
        if !TIPOS.include?(tipo)
          raise ErrorPantalla.new(
            "\"#{id}\" es de tipo #{el["tipo"].inspect}, que no existe. " \
            "Los tipos son: #{TIPOS.join(", ")}", fichero)
        end

        # Numeros: se dejan siempre como numero para que la escena no tenga que
        # ir preguntando. Un texto donde iba un numero se avisa, no revienta.
        ["x", "y", "ancho", "alto", "capa", "opacidad", "zoom", "angulo"].each do |clave|
          next if el[clave].nil?
          if !el[clave].is_a?(Numeric)
            avisos << "\"#{id}\": #{clave} deberia ser un numero, no #{el[clave].inspect}"
            el[clave] = el[clave].to_f
          end
        end
        el["x"]    ||= 0
        el["y"]    ||= 0
        el["capa"] ||= 0

        comprobar_por_tipo(el, id, tipo, fichero, avisos)
        comprobar_animaciones(el, id, fichero, avisos)
      end
      return true
    end

    # El bloque "aperturas". Todo son avisos y no errores: una pantalla con la
    # apertura mal puesta se puede abrir igual desde el menu de debug, y poder
    # verla es justo lo que hace falta para arreglarla.
    def comprobar_aperturas(datos, fichero, avisos)
      ap = datos["aperturas"]
      return if ap.nil?
      if !ap.is_a?(Hash)
        raise ErrorPantalla.new("\"aperturas\" tiene que ser un objeto { }", fichero)
      end

      tecla = ap["tecla"].to_s.upcase
      if !tecla.empty? && Interfaces::TECLAS_PROHIBIDAS.include?(tecla)
        avisos << "la tecla #{tecla} ya la usa el juego, elige otra o no se sabra que va a pasar"
      end

      if ap["menu_pausa"] && ap["orden"] && (ap["orden"].to_i % 10).zero?
        avisos << "el orden #{ap["orden"]} en el menu de pausa choca con una entrada del juego; " \
                  "usa un numero de en medio (35, 45, 55...)"
      end

      # Un interruptor declarado que nadie activa no es un error, pero uno que se
      # activa y no lleva a ningun sitio si: eso se avisa al ejecutarlo.
      inter = ap["interruptor"].to_s
      if !inter.empty? && inter !~ /\A[a-z0-9_]+\z/
        avisos << "el interruptor de interfaz #{inter.inspect} deberia ir en minusculas y sin espacios"
      end
    end

    def comprobar_por_tipo(el, id, tipo, fichero, avisos)
      case tipo
      when "imagen"
        if el["imagen"].to_s.empty?
          avisos << "\"#{id}\" es una imagen pero no tiene ninguna puesta"
        else
          avisar_si_falta_imagen(el["imagen"], id, avisos)
        end

      when "texto"
        el["texto"]      = el["texto"].to_s
        el["tamano"]   ||= Interfaces::TEXTO_TAMANO
        el["color"]    ||= Interfaces::TEXTO_COLOR
        el["sombra"]   ||= Interfaces::TEXTO_SOMBRA
        el["alineacion"] ||= Interfaces::TEXTO_ALINEACION
        if el["texto"].to_s.include?("{") && el["ancho"].to_i <= 0
          avisos << "\"#{id}\" enseña un dato del juego y no tiene ancho puesto. "                     "El hueco se mide con el valor de ahora y puede quedarse corto"
        end
        if !ALINEACIONES.include?(el["alineacion"].to_s)
          avisos << "\"#{id}\": alineacion #{el["alineacion"].inspect} no existe " \
                    "(#{ALINEACIONES.join(", ")}). Uso izquierda"
          el["alineacion"] = "izquierda"
        end
        if el["alineacion_vertical"] && !VERTICALES.include?(el["alineacion_vertical"].to_s)
          avisos << "\"#{id}\": alineacion vertical #{el["alineacion_vertical"].inspect} " \
                    "no existe (#{VERTICALES.join(", ")}). Uso centro"
          el["alineacion_vertical"] = "centro"
        end

      when "boton"
        ["imagen", "imagen_encima", "imagen_pulsado"].each do |clave|
          avisar_si_falta_imagen(el[clave], id, avisos) if !el[clave].to_s.empty?
        end
        # Un boton sin tamaño no se puede pulsar: la zona sensible es el rectangulo.
        if el["ancho"].nil? || el["alto"].nil?
          if el["imagen"].to_s.empty?
            avisos << "\"#{id}\" es un boton sin ancho ni alto y sin imagen: " \
                      "no habra nada que pulsar"
          end
          # Si tiene imagen, la escena le pone el tamaño de la imagen al crearla.
        end
        ["escala_encima", "escala_pulsado"].each do |clave|
          next if el[clave].nil?
          v = el[clave].to_f
          if v < 0.2 || v > 4.0
            avisos << "\"#{id}\": #{clave} = #{v} es exagerado; con 1.08 ya se nota"
          end
        end
        if el["accion"].nil?
          avisos << "\"#{id}\" es un boton pero no hace nada (le falta la accion)"
        elsif !el["accion"].is_a?(Hash)
          raise ErrorPantalla.new("la accion de \"#{id}\" tiene que ser un objeto { }", fichero)
        end

      when "panel"
        el["color"] ||= "#000000"

      when "barra"
        if el["ancho"].nil? || el["alto"].nil?
          avisos << "\"#{id}\" es una barra sin ancho o sin alto: no se vera"
        end
        if el["valor"].to_s.empty?
          avisos << "\"#{id}\" es una barra pero no dice que valor enseña "                     "(por ejemplo {equipo.1.hp})"
        end

      when "pokemon"
        n = el["cual"].to_i
        if n < 1 || n > 6
          avisos << "\"#{id}\": el equipo va del 1 al 6, y pone #{el["cual"].inspect}. Uso el 1"
          el["cual"] = 1
        end
        modo = (el["modo"] || "icono").to_s
        if !["icono", "frente", "espalda"].include?(modo)
          avisos << "\"#{id}\": modo #{modo.inspect} no existe (icono, frente, espalda). Uso icono"
          el["modo"] = "icono"
        end

      when "animado"
        if el["imagen"].to_s.empty?
          avisos << "\"#{id}\" es animado pero no tiene imagen"
        else
          avisar_si_falta_imagen(el["imagen"], id, avisos)
        end
        el["fotogramas"]     ||= 1
        el["velocidad"]      ||= 2
        el["bucle"] = true if el["bucle"].nil?
        if el["fotogramas"].to_i < 1
          avisos << "\"#{id}\": fotogramas tiene que ser 1 o mas. Uso 1"
          el["fotogramas"] = 1
        end
      end
    end

    def comprobar_animaciones(el, id, fichero, avisos)
      entrada = el["entrada"]
      if entrada
        if !entrada.is_a?(Hash)
          raise ErrorPantalla.new("la entrada de \"#{id}\" tiene que ser un objeto { }", fichero)
        end
        efecto = entrada["efecto"].to_s
        if !efecto.empty? && !EFECTOS.include?(efecto)
          avisos << "\"#{id}\": el efecto de entrada #{efecto.inspect} no existe " \
                    "(#{EFECTOS.join(", ")})"
          entrada["efecto"] = "aparece"
        end
        avisar_si_falta_suavizado(entrada["suavizado"], id, "la entrada", avisos)
        entrada["duracion"]  ||= Interfaces::ENTRADA_DURACION
        entrada["suavizado"] ||= Interfaces::SUAVIZADO_DEFECTO
        entrada["retraso"]   ||= 0.0
      end

      pistas = el["animaciones"]
      return if pistas.nil?
      if !pistas.is_a?(Array)
        raise ErrorPantalla.new("\"animaciones\" de \"#{id}\" tiene que ser una lista [ ]", fichero)
      end
      pistas.each do |pista|
        if !pista.is_a?(Hash)
          raise ErrorPantalla.new("una animacion de \"#{id}\" no es un objeto { }", fichero)
        end
        prop = pista["propiedad"].to_s
        if !PROPIEDADES.include?(prop)
          raise ErrorPantalla.new(
            "\"#{id}\" quiere animar #{pista["propiedad"].inspect}, que no se puede. " \
            "Se pueden animar: #{PROPIEDADES.join(", ")}", fichero)
        end
        claves = pista["claves"]
        if !claves.is_a?(Array) || claves.empty?
          raise ErrorPantalla.new(
            "la animacion de #{prop} en \"#{id}\" no tiene claves", fichero)
        end
        claves.each do |clave|
          if !clave.is_a?(Hash) || clave["t"].nil? || clave["valor"].nil?
            raise ErrorPantalla.new(
              "una clave de #{prop} en \"#{id}\" necesita \"t\" y \"valor\"", fichero)
          end
          avisar_si_falta_suavizado(clave["suavizado"], id, "una clave de #{prop}", avisos)
        end
      end
    end

    #---------------------------------------------------------------------------

    def avisar_si_falta_suavizado(nombre, id, donde, avisos)
      return if nombre.nil?
      return if Interfaces::Suavizado.existe?(nombre)
      avisos << "\"#{id}\": el suavizado #{nombre.inspect} de #{donde} no existe " \
                "(#{Interfaces::Suavizado::NOMBRES.join(", ")}). Uso lineal"
    end

    # Solo avisa: puedes estar cuadrando una pantalla antes de dibujar el arte, y
    # no tendria sentido que eso impidiera abrirla. Pero se dice, porque un hueco
    # vacio sin explicacion es de lo que mas tiempo hace perder.
    def avisar_si_falta_imagen(ruta, id, avisos)
      return if ruta.to_s.empty?
      return if pbResolveBitmap(ruta)
      avisos << "\"#{id}\": no encuentro la imagen #{ruta}"
    end
  end
end
