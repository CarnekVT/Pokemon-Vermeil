# encoding: UTF-8
# Gráficos opcionales de la Nueva Pokédex, siempre a resolución nativa 640x480.
# No se crean Bitmap nuevos por frame; se cargan una vez por escena.
class VermeilPokedexSkin
  ROOT = "Graphics/UI/Vermeil/NewPokedex"
  SIZES = {
    :background        => [640, 480],
    :header            => [256, 44],
    :list_panel        => [326, 420],
    :portrait_panel    => [256, 256],
    :counter_panel     => [256, 48],
    :list_row          => [326, 36],
    :list_row_selected => [326, 36],
    :scrollbar_track   => [6, 420],
    :entry_page        => [640, 480],
    :area_page         => [640, 480],
    :forms_page        => [640, 480]
  }.freeze

  def initialize(enabled = true)
    @enabled = enabled
    @cache = {}
  end

  def bitmap(key)
    return nil if !@enabled || !SIZES.key?(key)
    return @cache[key] if @cache.key?(key)
    name = File.join(ROOT, key.to_s)
    file = if defined?(pbResolveBitmap)
             pbResolveBitmap(name)
           else
             File.file?(name + ".png") ? name + ".png" : nil
           end
    if !file
      @cache[key] = nil
      return nil
    end
    bmp = Bitmap.new(file)
    expected = SIZES[key]
    if bmp.width != expected[0] || bmp.height != expected[1]
      echoln("[Nueva Pokédex] #{key}.png: se requieren #{expected[0]}x#{expected[1]} píxeles.") if defined?(echoln)
      bmp.dispose
      @cache[key] = nil
    else
      @cache[key] = bmp
    end
    @cache[key]
  rescue StandardError => e
    echoln("[Nueva Pokédex] Error en skin #{key}: #{e.message}") if defined?(echoln)
    @cache[key] = nil
  end

  def draw(canvas, key, x, y)
    bmp = bitmap(key)
    return false if !bmp || !canvas || canvas.disposed?
    canvas.blt(x.to_i, y.to_i, bmp, Rect.new(0, 0, bmp.width, bmp.height))
    true
  end

  def dispose
    @cache.each_value { |bmp| bmp.dispose if bmp && !bmp.disposed? }
    @cache.clear
  end
end
