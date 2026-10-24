# encoding: UTF-8
# Sistema opcional de capas PNG para la Libreta de Investigación.
# Independiente del progreso y de los JSON de Golden/Arcane/SpeciesDex.
module ResearchNotebook
  class Skin
    ROOT = "Graphics/UI/Vermeil/ResearchNotebook"
    SIZES = {
      :background         => [640, 480],
      :focus_panel        => [294, 368],
      :grid_panel         => [306, 348],
      :detail_panel       => [306, 365],
      :grid_cell          => [58, 63],
      :grid_cell_selected => [58, 63],
      :cover              => [628, 387],
      :pages              => [628, 387],
      :tab_arcane         => [149, 37],
      :tab_golden         => [149, 37]
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
      w, h = SIZES[key]
      if bmp.width != w || bmp.height != h
        echoln("[Libreta] #{key}.png: medidas requeridas #{w}x#{h}") if defined?(echoln)
        bmp.dispose
        @cache[key] = nil
      else
        @cache[key] = bmp
      end
      @cache[key]
    rescue StandardError => e
      echoln("[Libreta] Error en skin #{key}: #{e.message}") if defined?(echoln)
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
end
