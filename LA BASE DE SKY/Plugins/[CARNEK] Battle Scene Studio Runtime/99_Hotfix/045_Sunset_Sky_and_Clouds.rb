# frozen_string_literal: true
# Vermeil BSS - Warm twilight atmosphere, without changing world geometry.
# The EBDX dawn bitmap contains cool cyan pixels. Its sky/horizon separation
# preserves those colors, producing the blue band visible at sunset.
# Regrade only sky-colored pixels in the two generated atmospheric layers.
# Cloud colors are adjusted independently, without editing the PNG assets.
module BSSSunsetAtmosphere
  VERSION = "1.0.0"
  module_function

  def dawn?(data)
    defined?(BSSLayeredLighting) && BSSLayeredLighting.slot(data).to_s == "dawn"
  rescue StandardError
    false
  end

  def regrade(raw, w, h, layer)
    return nil unless raw && raw.respond_to?(:getbyte) && raw.respond_to?(:setbyte)
    return nil if raw.bytesize < w * h * 4
    # The haze layer also contains trees: never recolor its lower terrain.
    limit = layer == 0 ? h : (h * 0.50).to_i
    y = 0
    while y < limit
      x = 0
      while x < w
        i = (y * w + x) * 4
        if raw.getbyte(i + 3).to_i > 0
          r = raw.getbyte(i).to_i
          g = raw.getbyte(i + 1).to_i
          b = raw.getbyte(i + 2).to_i
          # Identifies cold sky/cyan stripe. Tree/grass greens, orange
          # horizon and the sun keep their original authored palette.
          if b >= r + 13 && b >= g + 7
            bright = (r + g + b) / 3.0
            if bright >= 180
              rr = [[230 + (bright - 180) * 0.27, 255].min, 0].max.to_i
              gg = [[191 + (bright - 180) * 0.40, 255].min, 0].max.to_i
              bb = [[173 + (bright - 180) * 0.34, 255].min, 0].max.to_i
            else
              rr = [[199 + bright * 0.15, 255].min, 0].max.to_i
              gg = [[133 + bright * 0.18, 255].min, 0].max.to_i
              bb = [[119 + bright * 0.13, 255].min, 0].max.to_i
            end
            raw.setbyte(i, rr)
            raw.setbyte(i + 1, gg)
            raw.setbyte(i + 2, bb)
          end
        end
        x += 1
      end
      y += 1
    end
    raw
  end
end

module BSSSunsetAtmosphereRoom
  def bss_sunset_capture_layers!
    @bss_sunset_sources = []
    Array(@bss_layered_generated)[0, 2].each_with_index do |bmp, index|
      next unless bmp && !(bmp.disposed? rescue true)
      next unless bmp.respond_to?(:raw_data) && bmp.respond_to?(:raw_data=)
      raw = bmp.raw_data rescue nil
      next unless raw.is_a?(String) && raw.bytesize >= bmp.width * bmp.height * 4
      @bss_sunset_sources[index] = [bmp, raw.dup]
    end
    @bss_sunset_phase = nil
    @bss_sunset_cloud_originals = {}
  end

  def bss_sunset_clouds!(warm)
    @bss_sunset_cloud_originals ||= {}
    ["cloud0", "cloud1"].each do |key|
      sp = @sprites.is_a?(Hash) ? @sprites[key] : nil
      next unless sp && !(sp.disposed? rescue true)
      old = @bss_sunset_cloud_originals[key]
      if !old || old[:sprite] != sp
        old = { :sprite => sp, :tone => (sp.tone.clone rescue nil),
                :color => (sp.color.clone rescue nil) }
        @bss_sunset_cloud_originals[key] = old
      end
      if warm
        sp.tone = Tone.new(34, 4, -56, 0) if sp.respond_to?(:tone=)
        sp.color = Color.new(246, 173, 133, 205) if sp.respond_to?(:color=)
      else
        sp.tone = old[:tone] if old[:tone] && sp.respond_to?(:tone=)
        sp.color = old[:color] if old[:color] && sp.respond_to?(:color=)
      end
    end
  end

  def bss_sunset_correct_atmosphere!
    return unless @sprites.is_a?(Hash)
    warm = BSSSunsetAtmosphere.dawn?(@data)
    return if @bss_sunset_phase == warm
    @bss_sunset_phase = warm
    Array(@bss_sunset_sources).each_with_index do |entry, index|
      next unless entry
      bmp, source = entry
      next unless bmp && !(bmp.disposed? rescue true)
      raw = source.dup
      BSSSunsetAtmosphere.regrade(raw, bmp.width, bmp.height, index) if warm
      bmp.raw_data = raw
    end
    bss_sunset_clouds!(warm)
  rescue StandardError => e
    BSS064.log("BSS sunset atmosphere: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss_layered_split!(*args, &block)
    result = super
    bss_sunset_capture_layers!
    bss_sunset_correct_atmosphere!
    result
  end

  def update(*args, &block)
    result = super
    bss_sunset_correct_atmosphere!
    result
  end

  def bss_layered_release!(*args, &block)
    result = super
    @bss_sunset_sources = nil
    @bss_sunset_phase = nil
    @bss_sunset_cloud_originals = nil
    result
  end
end

if defined?(BSS070EBDXRoom) &&
   !BSS070EBDXRoom.ancestors.include?(BSSSunsetAtmosphereRoom)
  BSS070EBDXRoom.prepend(BSSSunsetAtmosphereRoom)
end
