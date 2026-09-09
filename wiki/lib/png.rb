# frozen_string_literal: true

# Lee el tamaño de un PNG sin dependencias: la cabecera IHDR va justo tras la
# firma de 8 bytes (4 de longitud + "IHDR" + ancho + alto, todo big-endian).
module PNG
  SIGNATURE = "\x89PNG\r\n\x1a\n".b

  module_function

  # @return [Array(Integer, Integer), nil] [ancho, alto] o nil si no es un PNG
  def dimensions(path)
    File.open(path, "rb") do |f|
      return nil unless f.read(8) == SIGNATURE

      f.read(8) # longitud del chunk + "IHDR"
      w, h = f.read(8).unpack("N2")
      (w && h && w.positive? && h.positive?) ? [w, h] : nil
    end
  rescue SystemCallError
    nil
  end

  # Los sprites de Essentials son tiras horizontales de fotogramas cuadrados:
  # el lado del fotograma es la altura, y el nº de fotogramas ancho/alto.
  # @return [Array(Integer, Integer)] [lado_del_fotograma, nº_de_fotogramas]
  def frames(path)
    w, h = dimensions(path)
    return [0, 1] unless w

    n = (w.to_f / h).round
    [h, [n, 1].max]
  end
end
