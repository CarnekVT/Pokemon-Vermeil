# encoding: UTF-8
# Lighting Studio Runtime 0.1.0 - Essentials v21.1 prototype.
# Draws atmospheric darkening and radial halos. Does not provide true 2D lightmaps or shadows.
# Depends on the project's JSON Compatibility bootstrap if Ruby's JSON gem is unavailable.
module LightingStudio
  DATA_PATH = 'Data/LightingStudio/maps.json'
  DEFAULT_TILE = 32
  module_function

  def load_map(map_id)
    return nil unless File.file?(DATA_PATH)
    unless defined?(JSON) && JSON.respond_to?(:parse)
      warn '[LightingStudio] JSON parser missing; install JSON Compatibility.'
      return nil
    end
    data = JSON.parse(File.binread(DATA_PATH))
    return nil unless data.is_a?(Hash) && data['schema'] == 1
    maps = data['maps']
    return nil unless maps.is_a?(Hash)
    result = maps[map_id.to_i.to_s]
    return nil unless result.is_a?(Hash)
    result
  rescue StandardError => e
    warn "[LightingStudio] Data error: #{e.class}: #{e.message}"
    nil
  end

  def number(value, fallback, min, max)
    n = Float(value)
    return fallback unless n.finite?
    [[n, min].max, max].min
  rescue StandardError
    fallback
  end

  def hex_color(hex)
    s = hex.to_s
    return [255, 207, 134] unless /\A#[0-9A-Fa-f]{6}\z/.match?(s)
    [s[1,2],s[3,2],s[5,2]].map { |v| v.to_i(16) }
  end

  # Precalculated per-source halo bitmaps; avoid allocating them every frame.
  def gradient(radius, rgb, softness)
    diameter = radius * 2
    bitmap = Bitmap.new(diameter, diameter)
    radius_sq = radius * radius
    # Sparse concentric rings reduce Bitmap#set_pixel calls on larger lights.
    # The prototype prioritizes correctness over GPU-optimized lightmaps.
    (0...diameter).each do |y|
      dy = y - radius + 0.5
      (0...diameter).each do |x|
        dx = x - radius + 0.5
        fraction = (dx*dx + dy*dy) / radius_sq.to_f
        next if fraction >= 1.0
        falloff = (1.0 - Math.sqrt(fraction)) ** (1.0 / softness)
        alpha = (235 * falloff).round
        bitmap.set_pixel(x, y, Color.new(rgb[0],rgb[1],rgb[2],alpha)) if alpha > 0
      end
    end
    bitmap
  end
end

module LightingStudioSpriteset
  def initialize(*args)
    super
    @ls_sprites = []
    @ls_bitmaps = []
    @ls_ambient_sprite = nil
    ls_setup
  end

  def ls_setup
    return unless @map && @map.respond_to?(:map_id)
    data = LightingStudio.load_map(@map.map_id)
    return unless data
    ambient = data['ambient'].is_a?(Hash) ? data['ambient'] : {}
    darkness = LightingStudio.number(ambient['darkness'],0,0,1)
    if darkness > 0
      @ls_ambient_sprite = Sprite.new(Spriteset_Map.viewport)
      @ls_ambient_sprite.bitmap = Bitmap.new(1,1)
      @ls_ambient_sprite.bitmap.set_pixel(0,0,Color.new(0,0,0,255))
      @ls_ambient_sprite.zoom_x = Graphics.width
      @ls_ambient_sprite.zoom_y = Graphics.height
      @ls_ambient_sprite.opacity = (darkness * 230).round
      @ls_ambient_sprite.z = 8500
    end
    lights = data['lights'].is_a?(Array) ? data['lights'].first(200) : []
    cache = {}
    lights.each do |l|
      next unless l.is_a?(Hash) && l['enabled'] != false
      radius = LightingStudio.number(l['radiusPx'],96,8,512).round
      softness = LightingStudio.number(l['softness'],0.75,0.05,1)
      rgb = LightingStudio.hex_color(l['color'])
      key = [radius,rgb,softness]
      bitmap = cache[key]
      unless bitmap
        bitmap = LightingStudio.gradient(radius,rgb,softness)
        cache[key] = bitmap
        @ls_bitmaps << bitmap
      end
      sprite = Sprite.new(Spriteset_Map.viewport)
      sprite.bitmap = bitmap
      sprite.ox = radius
      sprite.oy = radius
      sprite.blend_type = 1
      sprite.z = 8501
      sprite.opacity = (LightingStudio.number(l['intensity'],0.8,0,1) * 255).round
      @ls_sprites << [sprite, LightingStudio.number(l['x'],0,-2048,2048), LightingStudio.number(l['y'],0,-2048,2048), radius]
    end
    ls_update
  end

  def ls_update
    return unless @ls_sprites && @map
    # The same map-to-viewport transform used by LBDS Animated Props.
    mx = @map.display_x.to_f / Game_Map::X_SUBPIXELS
    my = @map.display_y.to_f / Game_Map::Y_SUBPIXELS
    zx = defined?(TilemapRenderer::ZOOM_X) ? TilemapRenderer::ZOOM_X : 1
    zy = defined?(TilemapRenderer::ZOOM_Y) ? TilemapRenderer::ZOOM_Y : 1
    @ls_sprites.each do |sprite,tx,ty,radius|
      sx = tx * Game_Map::TILE_WIDTH - mx
      sy = ty * Game_Map::TILE_HEIGHT - my
      sx = (sx - Graphics.width / 2) * zx + Graphics.width / 2 if zx != 1
      sy = (sy - Graphics.height / 2) * zy + Graphics.height / 2 if zy != 1
      sprite.zoom_x = zx
      sprite.zoom_y = zy
      sprite.x = sx.round
      sprite.y = sy.round
      sprite.visible = sx + radius*zx > 0 && sy + radius*zy > 0 &&
                       sx - radius*zx < Graphics.width && sy - radius*zy < Graphics.height
    end
  end

  def update
    super
    ls_update
  end

  def dispose
    @ls_sprites&.each { |s,| s.dispose unless s.disposed? }
    @ls_sprites = nil
    if @ls_ambient_sprite
      bmp = @ls_ambient_sprite.bitmap
      @ls_ambient_sprite.dispose unless @ls_ambient_sprite.disposed?
      bmp.dispose if bmp && !bmp.disposed?
      @ls_ambient_sprite = nil
    end
    @ls_bitmaps&.each { |b| b.dispose unless b.disposed? }
    @ls_bitmaps = nil
    super
  end
end
Spriteset_Map.prepend(LightingStudioSpriteset) unless Spriteset_Map.ancestors.include?(LightingStudioSpriteset)
