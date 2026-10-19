# encoding: UTF-8
# Lighting Studio Runtime 0.4.5 for Pokemon Essentials 21.1 / mkxp.
# Shared additive lightmap: merge sources normally, add a single sprite to the map.
# No shaders required; uses Bitmap#stretch_blt for camera/animation updates.
module LightingStudio
  DATA_PATH = 'Data/LightingStudio/maps.json'
  MASK_LIMIT = 64
  MAX_SOURCES = 160
  # World-space cached chunks. Source masks are rasterized ONCE; chunks are built
  # only as they become visible, at a strict budget per frame.
  CHUNK_WORLD = 256
  CHUNK_PX = 64
  MAX_CHUNKS = 48
  BUILDS_PER_FRAME = 1
  MASKS_PER_FRAME = 2
  # Static lights use channel-wise MAX in chunks. Pulsing union lights are
  # drawn as dynamic additive sprites to avoid rebuilding chunks at runtime.
  module_function

  def number(value, fallback, min, max)
    n = Float(value)
    return fallback unless n.finite?
    [[n, min].max, max].min
  rescue StandardError
    fallback
  end

  def load_map(map_id)
    return nil unless File.file?(DATA_PATH)
    unless defined?(JSON) && JSON.respond_to?(:parse)
      warn '[Lighting Studio] JSON parser unavailable'
      return nil
    end
    json = JSON.parse(File.binread(DATA_PATH))
    return nil unless json.is_a?(Hash) && json['schema'] == 1
    return nil unless json['maps'].is_a?(Hash)
    json['maps'][map_id.to_i.to_s]
  rescue StandardError => e
    warn "[Lighting Studio] Could not read #{DATA_PATH}: #{e.message}"
    nil
  end

  def hex_color(value)
    hex = value.to_s
    return [255, 207, 134] unless /\A#[0-9A-Fa-f]{6}\z/.match?(hex)
    [hex[1,2], hex[3,2], hex[5,2]].map { |p| p.to_i(16) }
  end

  def shape_distance(type, x, y, aperture)
    case type
    when 'rectangle' then [x.abs, y.abs].max
    when 'cone' then [Math.sqrt(x*x + y*y), Math.atan2(y,x).abs/aperture].max
    else Math.sqrt(x*x + y*y)
    end
  end

  # Same falloff shape used in Maker Studio Canvas.
  # Direction describes the edge TOWARDS which the brightness fades.
  # 'bottom': bright plateau at the top, then darker toward the bottom.
  def falloff(spec, nx, ny)
    type = spec['type'] || 'radial'
    softness = number(spec['softness'], 0.75, 0.05, 1)
    aperture = number(spec['angle'], 70, 5, 170) * Math::PI / 360
    d = shape_distance(type, nx, ny, aperture)
    return 0.0 if d >= 1.0
    mode = spec['fadeMode'] || 'center'
    center = number(spec['centerStrength'], 0.65, 0, 1)
    if mode == 'center'
      radial = (1.0 - d)**(1.0 / softness)
      return radial * (center + (1.0 - center) * [d * 2.0, 1.0].min)
    end
    direction = case mode
      when 'bottom' then (ny + 1.0) / 2.0
      when 'top' then (1.0 - ny) / 2.0
      when 'left' then (1.0 - nx) / 2.0
      when 'right' then (nx + 1.0) / 2.0
      else
        ox = number(spec['fadeX'], 0, -1, 1)
        oy = number(spec['fadeY'], 0, -1, 1)
        Math.sqrt((nx - ox)**2 + (ny - oy)**2) / (1 + Math.sqrt(ox*ox + oy*oy))
      end
    start = number(spec['fadeStart'], 0.58, 0, 0.95)
    q = [[(direction - start) / (1.0 - start), 0].max, 1].min
    smooth = 1.0 - q*q*(3.0 - 2.0*q)
    # Edge is only a very narrow shape clip; don't apply a second radial fade.
    edge = [[(1.0 - d)/0.045, 0].max, 1].min
    smooth * edge * center
  end

  # World-space bounds can be calculated without rasterizing a light mask.
  def shape_dimensions(spec)
    type = %w[radial cone ellipse rectangle].include?(spec['type']) ? spec['type'] : 'radial'
    r = number(spec['radiusPx'], 96, 8, 512)
    w = %w[ellipse rectangle].include?(type) ? number(spec['widthPx'],160,8,1024) : 2*r
    h = %w[ellipse rectangle].include?(type) ? number(spec['heightPx'],96,8,1024) : 2*r
    rad = number(spec['rotation'],0,-360,360)*Math::PI/180
    cos = Math.cos(rad).abs
    sin = Math.sin(rad).abs
    [cos*w+sin*h, sin*w+cos*h]
  end

  def shape_bitmap(spec)
    type = %w[radial cone ellipse rectangle].include?(spec['type']) ? spec['type'] : 'radial'
    r = number(spec['radiusPx'],96,8,512)
    orig_w = %w[ellipse rectangle].include?(type) ? number(spec['widthPx'],160,8,1024) : 2*r
    orig_h = %w[ellipse rectangle].include?(type) ? number(spec['heightPx'],96,8,1024) : 2*r
    degrees = number(spec['rotation'],0,-360,360)
    rad = degrees*Math::PI/180
    cos = Math.cos(rad); sin = Math.sin(rad)
    # Enlarged mask contains the rotated shape (stretch_blt itself has no rotation).
    world_w = cos.abs*orig_w + sin.abs*orig_h
    world_h = sin.abs*orig_w + cos.abs*orig_h
    pixel = spec['pixel'].is_a?(Hash) && spec['pixel']['enabled'] == true ? spec['pixel'] : {}
    if pixel.empty?
      scale = [1.0, MASK_LIMIT.to_f / [world_w,world_h].max].min
      w = [[(world_w*scale).round,2].max,MASK_LIMIT].min
      h = [[(world_h*scale).round,2].max,MASK_LIMIT].min
    else
      # One source texel per pixel-art block, matching the Maker Studio preview.
      # Applying MASK_LIMIT first and then stepping pixels destroys ellipse and
      # cone silhouettes; cap the logical grid instead to bound CPU work.
      block_size = number(pixel['size'],6,2,32)
      w = [[(world_w/block_size).ceil,2].max,128].min
      h = [[(world_h/block_size).ceil,2].max,128].min
    end
    step = 1
    steps = pixel.empty? ? 255 : number(pixel['steps'],6,2,24).round
    color = hex_color(spec['color'])
    bmp = Bitmap.new(w,h)
    (0...h).step(step) do |y|
      py = ((y+step/2.0)/h - 0.5)*world_h
      (0...w).step(step) do |x|
        px = ((x+step/2.0)/w - 0.5)*world_w
        local_x = cos*px + sin*py
        local_y = -sin*px + cos*py
        nx = local_x/(orig_w/2.0)
        ny = local_y/(orig_h/2.0)
        a = falloff(spec,nx,ny)
        next if a <= 0
        a = (a*steps).round.to_f/steps
        alpha = (a*255).round
        next if alpha <= 0
        bmp.fill_rect(x,y,[step,w-x].min,[step,h-y].min,Color.new(color[0],color[1],color[2],alpha))
      end
    end
    [bmp,world_w,world_h]
  end

  def pulse_values(pulse,now)
    return [1.0,1.0] unless pulse.is_a?(Hash) && pulse['enabled']==true
    phase = number(pulse['phase'],0,0,360)*Math::PI/180
    wave = Math.sin(now*2*Math::PI*number(pulse['speedHz'],1,0.05,12)+phase)
    size = [0.1,1+wave*number(pulse['radius'],0,0,0.9)].max
    energy = [0.0,1+wave*number(pulse['intensity'],0,0,1)].max
    [size,energy]
  end
end

module LightingStudioSpriteset
  def initialize(*args)
    super
    @ls_sprites = []
    @ls_bitmaps = []
    @ls_mask_cache = {}
    @ls_masks_built_this_frame = 0
    @ls_union_sources = []
    @ls_chunks = {}
    @ls_chunk_tick = 0
    @ls_ambient_sprite = nil
    ls_setup
  end

  def ls_setup
    return unless @map && @map.respond_to?(:map_id)
    data = LightingStudio.load_map(@map.map_id)
    return unless data.is_a?(Hash) && data['enabled'] != false

    ambient = data['ambient'].is_a?(Hash) ? data['ambient'] : {}
    darkness = LightingStudio.number(ambient['darkness'], 0, 0, 1)
    if darkness > 0
      @ls_ambient_sprite = Sprite.new(Spriteset_Map.viewport)
      @ls_ambient_sprite.bitmap = Bitmap.new(1, 1)
      @ls_ambient_sprite.bitmap.set_pixel(0, 0, Color.new(0, 0, 0, 255))
      @ls_ambient_sprite.zoom_x = Graphics.width
      @ls_ambient_sprite.zoom_y = Graphics.height
      @ls_ambient_sprite.opacity = (darkness * 230).round
      @ls_ambient_sprite.z = 8500
      @ls_ambient_sprite.x = 0
      @ls_ambient_sprite.y = 0
      @ls_ambient_sprite.ox = 0
      @ls_ambient_sprite.oy = 0
    end

    lights = data['lights'].is_a?(Array) ? data['lights'].first(LightingStudio::MAX_SOURCES) : []
    lights.each do |source|
      next unless source.is_a?(Hash) && source['enabled'] != false
      key = [
        source['type'], source['radiusPx'], source['widthPx'],
        source['heightPx'], source['angle'], source['rotation'],
        source['color'], source['softness'], source['centerStrength'],
        source['fadeMode'], source['fadeStart'], source['fadeX'], source['fadeY'],
        source['pixel']
      ].inspect
      width, height = LightingStudio.shape_dimensions(source)
      entry = {
        :bitmap => nil, :spec => source, :key => key, :w => width, :h => height,
        :cx => LightingStudio.number(source['x'],0,-2048,2048)*Game_Map::TILE_WIDTH,
        :cy => LightingStudio.number(source['y'],0,-2048,2048)*Game_Map::TILE_HEIGHT,
        :intensity => LightingStudio.number(source['intensity'],0.8,0,1),
        :pulse => source['pulse'].is_a?(Hash) ? source['pulse'] : {}
      }
      mode = source['blendMode'].to_s
      if data['overlapMode'] == 'sum' && ['', 'union', 'add'].include?(mode)
        mode = 'sum'
      end
      mode = 'union' if mode.empty? || mode == 'add'

      if mode == 'union' && entry[:pulse]['enabled'] != true
        # Defer mask generation until this source enters a visible world chunk.
        @ls_union_sources << entry
      else
        # Animated/normal/sum modes remain individual Sprites.
        image = @ls_mask_cache[key]
        unless image
          image = LightingStudio.shape_bitmap(source)
          @ls_mask_cache[key] = image
          @ls_bitmaps << image[0]
        end
        entry[:bitmap] = image[0]
        sprite = Sprite.new(Spriteset_Map.viewport)
        sprite.bitmap = image[0]
        sprite.ox = image[0].width / 2
        sprite.oy = image[0].height / 2
        sprite.z = 8501
        sprite.blend_type = mode == 'subtract' ? 2 : (mode == 'normal' ? 0 : 1)
        @ls_sprites << [sprite, entry]
      end
    end
    ls_update
  end

  # Exact map transformation used by LBDS Animated Props in-game.
  # Feed WORLD PIXELS, not tile coordinates, and do not round until the end.
  def ls_world_screen(wx, wy, mx, my, zx, zy)
    sx = wx - mx
    sy = wy - my
    if zx != 1
      sx = (sx - Graphics.width / 2) * zx + Graphics.width / 2
    end
    if zy != 1
      sy = (sy - Graphics.height / 2) * zy + Graphics.height / 2
    end
    [sx.round, sy.round]
  end

  def ls_visible_keys(mx, my, zx, zy)
    zx = 1.0 if zx <= 0
    zy = 1.0 if zy <= 0
    # Inverse of the same centered-zoom transformation.
    x0 = mx + Graphics.width / 2.0 - Graphics.width / (2.0 * zx)
    x1 = mx + Graphics.width / 2.0 + Graphics.width / (2.0 * zx)
    y0 = my + Graphics.height / 2.0 - Graphics.height / (2.0 * zy)
    y1 = my + Graphics.height / 2.0 + Graphics.height / (2.0 * zy)
    unit = LightingStudio::CHUNK_WORLD
    left = [[(x0 / unit).floor, 0].max, (@map.width * Game_Map::TILE_WIDTH / unit.to_f).ceil].min
    right = [[(x1 / unit).floor, 0].max, (@map.width * Game_Map::TILE_WIDTH / unit.to_f).ceil].min
    top = [[(y0 / unit).floor, 0].max, (@map.height * Game_Map::TILE_HEIGHT / unit.to_f).ceil].min
    bottom = [[(y1 / unit).floor, 0].max, (@map.height * Game_Map::TILE_HEIGHT / unit.to_f).ceil].min
    result = []
    (top..bottom).each do |cy|
      (left..right).each do |cx|
        next if cx * unit >= @map.width * Game_Map::TILE_WIDTH
        next if cy * unit >= @map.height * Game_Map::TILE_HEIGHT
        result << [cx, cy]
      end
    end
    # Build the closest missing chunks first to avoid visible loading at the center.
    middle_x = (x0+x1) / (2*unit)
    middle_y = (y0+y1) / (2*unit)
    result.sort_by! { |key| (key[0]+0.5-middle_x)**2 + (key[1]+0.5-middle_y)**2 }
    # Bound sprite count even with extreme zoom-out: prefer nearby chunks.
    result.first(LightingStudio::MAX_CHUNKS)
  end

  def ls_chunk_bitmap(cx, cy)
    unit = LightingStudio::CHUNK_WORLD
    resolution = LightingStudio::CHUNK_PX
    origin_x = cx * unit
    origin_y = cy * unit
    pixel_unit = unit.to_f / resolution
    red = Array.new(resolution*resolution, 0)
    green = Array.new(resolution*resolution, 0)
    blue = Array.new(resolution*resolution, 0)
    has_light = false

    @ls_union_sources.each do |entry|
      next if entry[:intensity] <= 0
      half_w = entry[:w] / 2.0
      half_h = entry[:h] / 2.0
      min_x = entry[:cx] - half_w
      max_x = entry[:cx] + half_w
      min_y = entry[:cy] - half_h
      max_y = entry[:cy] + half_h
      next if max_x <= origin_x || min_x >= origin_x + unit
      next if max_y <= origin_y || min_y >= origin_y + unit

      x1 = [[((min_x - origin_x) / pixel_unit).floor, 0].max, resolution-1].min
      y1 = [[((min_y - origin_y) / pixel_unit).floor, 0].max, resolution-1].min
      x2 = [[((max_x - origin_x) / pixel_unit).ceil, 0].max, resolution].min
      y2 = [[((max_y - origin_y) / pixel_unit).ceil, 0].max, resolution].min
      bmp = entry[:bitmap]
      unless bmp
        # Hard per-frame budget prevents the first camera view creating dozens
        # of bitmaps at once. Retry this chunk on the next update.
        return :pending if @ls_masks_built_this_frame >= LightingStudio::MASKS_PER_FRAME
        image = @ls_mask_cache[entry[:key]]
        unless image
          image = LightingStudio.shape_bitmap(entry[:spec])
          @ls_mask_cache[entry[:key]] = image
          @ls_bitmaps << image[0]
          @ls_masks_built_this_frame += 1
        end
        entry[:bitmap] = image[0]
        bmp = image[0]
      end

      y = y1
      while y < y2
        world_y = origin_y + (y + 0.5) * pixel_unit
        sy = (((world_y - min_y) / entry[:h]) * bmp.height).floor
        if sy >= 0 && sy < bmp.height
          x = x1
          while x < x2
            world_x = origin_x + (x + 0.5) * pixel_unit
            sx = (((world_x - min_x) / entry[:w]) * bmp.width).floor
            if sx >= 0 && sx < bmp.width
              pixel = bmp.get_pixel(sx, sy)
              if pixel.alpha > 0
                alpha = pixel.alpha / 255.0 * entry[:intensity]
                idx = y * resolution + x
                nr = (pixel.red * alpha).round
                ng = (pixel.green * alpha).round
                nb = (pixel.blue * alpha).round
                red[idx] = nr if nr > red[idx]
                green[idx] = ng if ng > green[idx]
                blue[idx] = nb if nb > blue[idx]
                has_light = true
              end
            end
            x += 1
          end
        end
        y += 1
      end
    end

    return nil unless has_light
    result = Bitmap.new(resolution, resolution)
    idx = 0
    resolution.times do |y|
      resolution.times do |x|
        if red[idx] > 0 || green[idx] > 0 || blue[idx] > 0
          result.set_pixel(x, y, Color.new(red[idx], green[idx], blue[idx], 255))
        end
        idx += 1
      end
    end
    result
  end

  def ls_chunk_build(cx, cy)
    bmp = ls_chunk_bitmap(cx, cy)
    return if bmp == :pending
    sprite = nil
    if bmp
      sprite = Sprite.new(Spriteset_Map.viewport)
      sprite.bitmap = bmp
      sprite.ox = 0
      sprite.oy = 0
      sprite.z = 8501
      sprite.blend_type = 1
    end
    @ls_chunks[[cx, cy]] = {:bitmap => bmp, :sprite => sprite, :tick => @ls_chunk_tick}
  end

  def ls_chunk_dispose(entry)
    sprite = entry[:sprite]
    bitmap = entry[:bitmap]
    sprite.dispose if sprite && !sprite.disposed?
    bitmap.dispose if bitmap && !bitmap.disposed?
  end

  def ls_update_chunks(mx, my, zx, zy)
    return if @ls_union_sources.empty?
    @ls_masks_built_this_frame = 0
    @ls_chunk_tick += 1
    needed = ls_visible_keys(mx, my, zx, zy)
    visible = {}
    needed.each { |key| visible[key] = true }
    @ls_chunks.each do |key, entry|
      next unless entry[:sprite]
      if visible[key]
        world_x = key[0] * LightingStudio::CHUNK_WORLD
        world_y = key[1] * LightingStudio::CHUNK_WORLD
        sx, sy = ls_world_screen(world_x, world_y, mx, my, zx, zy)
        entry[:sprite].x = sx
        entry[:sprite].y = sy
        entry[:sprite].zoom_x = zx * LightingStudio::CHUNK_WORLD / entry[:bitmap].width.to_f
        entry[:sprite].zoom_y = zy * LightingStudio::CHUNK_WORLD / entry[:bitmap].height.to_f
        entry[:sprite].visible = true
        entry[:tick] = @ls_chunk_tick
      else
        entry[:sprite].visible = false
      end
    end

    pending = needed.reject { |key| @ls_chunks.key?(key) }
    LightingStudio::BUILDS_PER_FRAME.times do
      key = pending.shift
      break unless key
      ls_chunk_build(key[0], key[1])
      entry = @ls_chunks[key]
      next unless entry && entry[:sprite]
      world_x = key[0] * LightingStudio::CHUNK_WORLD
      world_y = key[1] * LightingStudio::CHUNK_WORLD
      sx, sy = ls_world_screen(world_x, world_y, mx, my, zx, zy)
      entry[:sprite].x = sx
      entry[:sprite].y = sy
      entry[:sprite].zoom_x = zx * LightingStudio::CHUNK_WORLD / entry[:bitmap].width.to_f
      entry[:sprite].zoom_y = zy * LightingStudio::CHUNK_WORLD / entry[:bitmap].height.to_f
      entry[:sprite].visible = true
    end

    if @ls_chunks.length > LightingStudio::MAX_CHUNKS
      candidates = @ls_chunks.keys.reject { |key| visible.key?(key) }
      candidates.sort_by! { |key| @ls_chunks[key][:tick] }
      while @ls_chunks.length > LightingStudio::MAX_CHUNKS && !candidates.empty?
        key = candidates.shift
        ls_chunk_dispose(@ls_chunks.delete(key))
      end
    end
  end

  def ls_update
    return unless @ls_sprites && @map
    mx = (@map.display_x.to_f / Game_Map::X_SUBPIXELS).round
    my = (@map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
    zx = defined?(TilemapRenderer::ZOOM_X) ? TilemapRenderer::ZOOM_X : 1
    zy = defined?(TilemapRenderer::ZOOM_Y) ? TilemapRenderer::ZOOM_Y : 1
    now = System.uptime

    ls_update_chunks(mx, my, zx, zy)
    @ls_sprites.each do |sprite, entry|
      size, energy = LightingStudio.pulse_values(entry[:pulse], now)
      sx, sy = ls_world_screen(entry[:cx], entry[:cy], mx, my, zx, zy)
      sprite.zoom_x = zx * size * entry[:w] / sprite.bitmap.width.to_f
      sprite.zoom_y = zy * size * entry[:h] / sprite.bitmap.height.to_f
      sprite.opacity = [[(255 * entry[:intensity] * energy).round, 0].max, 255].min
      sprite.x = sx
      sprite.y = sy
      bound = [entry[:w], entry[:h]].max * [zx, zy].max * size / 2
      sprite.visible = sx+bound > 0 && sy+bound > 0 &&
                       sx-bound < Graphics.width && sy-bound < Graphics.height
    end
  end

  def update
    super
    ls_update
  end

  def dispose
    @ls_chunks&.each_value { |entry| ls_chunk_dispose(entry) }
    @ls_chunks = nil
    @ls_sprites&.each { |row| row[0].dispose unless row[0].disposed? }
    @ls_sprites = nil
    if @ls_ambient_sprite
      bitmap = @ls_ambient_sprite.bitmap
      @ls_ambient_sprite.dispose unless @ls_ambient_sprite.disposed?
      bitmap.dispose if bitmap && !bitmap.disposed?
      @ls_ambient_sprite = nil
    end
    @ls_bitmaps&.each { |bitmap| bitmap.dispose unless bitmap.disposed? }
    @ls_bitmaps = nil
    @ls_mask_cache = nil
    super
  end
end

Spriteset_Map.prepend(LightingStudioSpriteset) unless Spriteset_Map.ancestors.include?(LightingStudioSpriteset)
