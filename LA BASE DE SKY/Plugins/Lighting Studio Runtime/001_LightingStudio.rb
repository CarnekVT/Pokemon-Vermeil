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

  # Generates a low-resolution cached bitmap; sprites scale to world dimensions.
  def gradient(spec, pixel_size = 1, steps = 255)
    type = %w[radial cone ellipse rectangle].include?(spec['type']) ? spec['type'] : 'radial'
    radius = number(spec['radiusPx'],96,8,512)
    width = %w[ellipse rectangle].include?(type) ? number(spec['widthPx'],160,8,1024) : radius*2
    height = %w[ellipse rectangle].include?(type) ? number(spec['heightPx'],96,8,1024) : radius*2
    ratio = [1.0, 128.0/[width,height].max].min
    w = [[(width*ratio).round,2].max,128].min
    h = [[(height*ratio).round,2].max,128].min
    bitmap = Bitmap.new(w,h)
    color = hex_color(spec['color'])
    softness = number(spec['softness'],0.75,0.05,1)
    center = number(spec['centerStrength'],0.65,0,1)
    aperture = number(spec['angle'],70,5,170)*Math::PI/360.0
    pixel_size = [[(pixel_size*ratio).round,1].max,32].min
    (0...h).step(pixel_size) do |y|
      ny = ((y + pixel_size/2.0)/h - 0.5)*2
      (0...w).step(pixel_size) do |x|
        nx = ((x + pixel_size/2.0)/w - 0.5)*2
        dist = case type
               when 'rectangle' then [nx.abs,ny.abs].max
               when 'ellipse' then Math.sqrt(nx*nx+ny*ny)
               when 'cone' then [Math.sqrt(nx*nx+ny*ny), Math.atan2(ny,nx).abs/aperture].max
               else Math.sqrt(nx*nx+ny*ny)
               end
        next if dist>=1
        falloff = (1-dist)**(1.0/softness)
        alpha = ((falloff*(center+(1-center)*[dist*2,1].min))*steps).round.to_f/steps
        alpha = (alpha*255).round
        next if alpha<=0
        bitmap.fill_rect(x,y,[pixel_size,w-x].min,[pixel_size,h-y].min,Color.new(*color,alpha))
      end
    end
    [bitmap,width,height]
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
    return if data['enabled'] == false
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
      radius = LightingStudio.number(l['radiusPx'],96,8,512)
      pixel = l['pixel'].is_a?(Hash) && l['pixel']['enabled']==true ? l['pixel'] : {}
      ps = LightingStudio.number(pixel['size'],1,1,32).round
      steps = LightingStudio.number(pixel['steps'],255,2,255).round
      key = [l['type'],radius,l['widthPx'],l['heightPx'],l['angle'],l['color'],l['softness'],l['centerStrength'],ps,steps]
      entry = cache[key]
      unless entry
        entry = LightingStudio.gradient(l,ps,steps)
        cache[key] = entry
        @ls_bitmaps << entry[0]
      end
      bitmap,width,height = entry
      sprite = Sprite.new(Spriteset_Map.viewport)
      sprite.bitmap = bitmap
      sprite.ox = bitmap.width/2
      sprite.oy = bitmap.height/2
      mode = l['blendMode'].to_s
      sprite.blend_type = mode=='normal' ? 0 : mode=='subtract' ? 2 : 1
      sprite.z = 8501
      pulse = l['pulse'].is_a?(Hash) ? l['pulse'] : {}
      @ls_sprites << [sprite,LightingStudio.number(l['x'],0,-2048,2048),
          LightingStudio.number(l['y'],0,-2048,2048),width,height,
          LightingStudio.number(l['intensity'],0.8,0,1),pulse,
          LightingStudio.number(l['rotation'],0,-360,360)]
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
    now = System.uptime
    @ls_sprites.each do |sprite,tx,ty,width,height,base_intensity,pulse,rotation|
      sx = tx * Game_Map::TILE_WIDTH - mx
      sy = ty * Game_Map::TILE_HEIGHT - my
      sx = (sx - Graphics.width / 2) * zx + Graphics.width / 2 if zx != 1
      sy = (sy - Graphics.height / 2) * zy + Graphics.height / 2 if zy != 1
      wave = pulse['enabled'] == true ? Math.sin(now * Math::PI * 2 * LightingStudio.number(pulse['speedHz'],1,0.05,12) + LightingStudio.number(pulse['phase'],0,0,360) * Math::PI / 180) : 0
      size_mult = 1 + wave * LightingStudio.number(pulse['radius'],0,0,0.9)
      intensity_mult = 1 + wave * LightingStudio.number(pulse['intensity'],0,0,1)
      sprite.zoom_x = zx * size_mult * width/sprite.bitmap.width.to_f
      sprite.zoom_y = zy * size_mult * height/sprite.bitmap.height.to_f
      sprite.angle = rotation
      sprite.opacity = [[(255 * base_intensity * intensity_mult).round,0].max,255].min
      sprite.x = sx.round
      sprite.y = sy.round
      bound = [width,height].max * [zx,zy].max * size_mult
      sprite.visible = sx + bound > 0 && sy + bound > 0 && sx - bound < Graphics.width && sy - bound < Graphics.height
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
