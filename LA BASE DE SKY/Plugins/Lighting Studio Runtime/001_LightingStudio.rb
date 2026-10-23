# encoding: UTF-8
# Lighting Studio Runtime 0.9.0 for Pokemon Essentials 21.1 / mkxp.
# Shared additive lightmap: merge sources normally, add a single sprite to the map.
# No shaders required; uses Bitmap#stretch_blt for camera/animation updates.
module LightingStudio
  DATA_PATH = 'Data/LightingStudio/maps.json'
  MASK_LIMIT = 64
  SMOOTH_MASK_LIMIT = 128
  SMOOTH_CHUNK_PX = 128
  MAX_SOURCES = 160
  # World-space cached chunks. Source masks are rasterized ONCE; chunks are built
  # only as they become visible, at a strict budget per frame.
  CHUNK_WORLD = 256
  CHUNK_PX = 64
  MAX_CHUNKS = 48
  BUILDS_PER_FRAME = 2
  INITIAL_CHUNKS = 12
  MASKS_PER_FRAME = 12
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
  # Keep the cone emitter anchored at normalized origin (0, 0), projecting
  # to +X. Both the editor and runtime use the same two independent fades:
  # forward distance and angular side feather.
  def smoothstep(lo, hi, value)
    q = [[(value - lo) / (hi - lo), 0.0].max, 1.0].min
    q*q*(3.0 - 2.0*q)
  end

  def directional_fade(spec, nx, ny)
    mode = spec['fadeMode'] || 'center'
    direction = case mode
                when 'bottom' then (ny + 1.0) / 2.0
                when 'top' then (1.0 - ny) / 2.0
                when 'left' then (1.0 - nx) / 2.0
                when 'right' then (nx + 1.0) / 2.0
                else
                  ox = number(spec['fadeX'], 0, -1, 1)
                  oy = number(spec['fadeY'], 0, -1, 1)
                  Math.sqrt((nx - ox)**2 + (ny - oy)**2) /
                    (1.0 + Math.sqrt(ox*ox + oy*oy))
                end
    start = number(spec['fadeStart'], 0.58, 0, 0.95)
    1.0 - smoothstep(start, 1.0, direction)
  end

  def falloff(spec, nx, ny)
    type = spec['type'] || 'radial'
    softness = number(spec['softness'], 0.75, 0.05, 1)
    mode = spec['fadeMode'] || 'center'
    center = number(spec['centerStrength'], 0.65, 0, 1)

    if type == 'cone'
      distance = Math.sqrt(nx*nx + ny*ny)
      return 0.0 if nx < 0.0 || distance >= 1.0
      half_angle = number(spec['angle'], 70, 5, 170) * Math::PI / 360.0
      relative_angle = Math.atan2(ny, nx).abs / half_angle
      return 0.0 if relative_angle >= 1.0
      feather = number(spec['coneFeather'], 0.28, 0.03, 0.9)
      side = 1.0 - smoothstep(1.0 - feather, 1.0, relative_angle)
      if mode == 'center'
        reach_start = number(spec['fadeStart'], 0.58, 0, 0.95)
        return side * (1.0 - smoothstep(reach_start, 1.0, distance)) * center
      end
      tip = 1.0 - smoothstep(0.88, 1.0, distance)
      return side * tip * directional_fade(spec, nx, ny) * center
    end

    aperture = number(spec['angle'], 70, 5, 170) * Math::PI / 360.0
    distance = shape_distance(type, nx, ny, aperture)
    return 0.0 if distance >= 1.0
    if mode == 'center'
      radial = (1.0 - distance)**(1.0 / softness)
      return radial *
        (center + (1.0 - center) * [distance * 2.0, 1.0].min)
    end
    edge = [[(1.0 - distance) / 0.045, 0.0].max, 1.0].min
    directional_fade(spec, nx, ny) * edge * center
  end

  # World-space bounds can be calculated without rasterizing a light mask.
  def shape_dimensions(spec)
    type = %w[radial cone ellipse rectangle mask].include?(spec['type']) ? spec['type'] : 'radial'
    r = number(spec['radiusPx'], 96, 8, 512)
    w = %w[ellipse rectangle mask].include?(type) ? number(spec['widthPx'],160,8,1024) : 2*r
    h = %w[ellipse rectangle mask].include?(type) ? number(spec['heightPx'],96,8,1024) : 2*r
    rad = number(spec['rotation'],0,-360,360)*Math::PI/180
    cos = Math.cos(rad).abs
    sin = Math.sin(rad).abs
    [cos*w+sin*h, sin*w+cos*h]
  end

  # Grayscale/alpha PNG forms the exact custom light silhouette. Tint once,
  # reuse the bitmap across frames; restrict paths to Graphics/LightingStudio/Masks.
  def mask_bitmap(spec)
    name=spec['maskFile'].to_s
    unless /\A[a-zA-Z0-9_-]{1,70}\.png\z/i.match?(name)
      warn "[Lighting Studio] Invalid mask filename: #{name.inspect}"
      return [Bitmap.new(1,1),1.0,1.0]
    end
    path="Graphics/LightingStudio/Masks/#{name}"
    unless File.file?(path)
      warn "[Lighting Studio] Missing PNG mask #{path}"
      return [Bitmap.new(1,1),1.0,1.0]
    end
    source=Bitmap.new(path)
    begin
      w=source.width; h=source.height
      raise 'Mask exceeds 512x512 pixels' if w<=0 || h<=0 || w>512 || h>512
      raw=source.raw_data
      raise 'Bitmap.raw_data unavailable' unless raw && raw.respond_to?(:getbyte)
      color=hex_color(spec['color'])
      result=Array.new(w*h*4,0)
      i=0
      while i<w*h*4
        alpha=raw.getbyte(i+3)
        if alpha && alpha>0
          value=(raw.getbyte(i)*54+raw.getbyte(i+1)*183+raw.getbyte(i+2)*19)/256.0
          result[i]=color[0]; result[i+1]=color[1];result[i+2]=color[2]
          result[i+3]=[[((alpha*value)/255.0).round,0].max,255].min
        end
        i+=4
      end
      bitmap=Bitmap.new(w,h)
      bitmap.raw_data=result.pack('C*')
      world_w=number(spec['widthPx'],160,8,1024)
      world_h=number(spec['heightPx'],96,8,1024)
      [bitmap,world_w,world_h]
    ensure
      source.dispose unless source.disposed?
    end
  rescue StandardError => e
    warn "[Lighting Studio] Mask #{name}: #{e.message}"
    [Bitmap.new(1,1),1.0,1.0]
  end

  # Apply a PNG as a non-destructive stencil to an existing light shape.
  # White pixels define visible light (reveal) or obstacles (block).
  # The stencil is projected in the lamp's local coordinates BEFORE rotation.
  def apply_shape_stencil!(bytes,w,h,spec,orig_w,orig_h,world_w,world_h,cos,sin)
    return bytes unless spec['maskEnabled']==true
    name=spec['maskFile'].to_s
    return bytes unless /\A[a-zA-Z0-9_-]{1,70}\.png\z/i.match?(name)
    path="Graphics/LightingStudio/Masks/#{name}"
    return bytes unless File.file?(path)
    source=Bitmap.new(path)
    begin
      return bytes if source.width>512 || source.height>512
      raw=source.raw_data
      return bytes unless raw && raw.respond_to?(:getbyte)
      inverse=spec['maskMode']=='block'
      y=0
      while y<h
        py=((y+0.5)/h-0.5)*world_h
        x=0
        while x<w
          i=(y*w+x)*4
          if bytes[i+3]>0
            px=((x+0.5)/w-0.5)*world_w
            local_x=cos*px+sin*py
            local_y=-sin*px+cos*py
            u=local_x/orig_w+0.5
            v=local_y/orig_h+0.5
            power=0.0
            if u>=0 && u<1 && v>=0 && v<1
              ix=[(u*source.width).floor,source.width-1].min
              iy=[(v*source.height).floor,source.height-1].min
              k=(iy*source.width+ix)*4
              gray=(raw.getbyte(k)*54+raw.getbyte(k+1)*183+raw.getbyte(k+2)*19)/256.0
              power=raw.getbyte(k+3)*gray/(255.0*255.0)
            end
            bytes[i+3]=(bytes[i+3]*(inverse ? 1.0-power : power)).round
          end
          x+=1
        end
        y+=1
      end
    ensure
      source.dispose unless source.disposed?
    end
    bytes
  rescue StandardError => e
    warn "[Lighting Studio] Light mask clip #{name}: #{e.message}"
    bytes
  end

  def shape_bitmap(spec)
    type = %w[radial cone ellipse rectangle mask].include?(spec['type']) ? spec['type'] : 'radial'
    return mask_bitmap(spec) if type == 'mask'
    r = number(spec['radiusPx'],96,8,512)
    orig_w = %w[ellipse rectangle mask].include?(type) ? number(spec['widthPx'],160,8,1024) : 2*r
    orig_h = %w[ellipse rectangle mask].include?(type) ? number(spec['heightPx'],96,8,1024) : 2*r
    degrees = number(spec['rotation'],0,-360,360)
    rad = degrees*Math::PI/180
    cos = Math.cos(rad); sin = Math.sin(rad)
    # Enlarged mask contains the rotated shape (stretch_blt itself has no rotation).
    world_w = cos.abs*orig_w + sin.abs*orig_h
    world_h = sin.abs*orig_w + cos.abs*orig_h
    pixel = spec['pixel'].is_a?(Hash) && spec['pixel']['enabled'] == true ? spec['pixel'] : {}
    if pixel.empty?
      # Smooth cone/ellipse masks must not use the 64px pixel-art budget.
      limit = %w[cone ellipse].include?(type) ? SMOOTH_MASK_LIMIT : MASK_LIMIT
      scale = [1.0, limit.to_f / [world_w,world_h].max].min
      w = [[(world_w*scale).round,2].max,limit].min
      h = [[(world_h*scale).round,2].max,limit].min
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
    # Building a mask with fill_rect for each pixel invokes tens of
    # thousands of native RGSS calls. Bake RGBA in Ruby, then transfer once.
    bytes = Array.new(w*h*4,0)
    y=0
    while y<h
      py=((y+0.5)/h-0.5)*world_h
      x=0
      while x<w
        px=((x+0.5)/w-0.5)*world_w
        local_x=cos*px+sin*py
        local_y=-sin*px+cos*py
        a=falloff(spec,local_x/(orig_w/2.0),local_y/(orig_h/2.0))
        if a>0
          alpha=((a*steps).round.to_f/steps*255).round
          if alpha>0
            i=(y*w+x)*4
            bytes[i]=color[0]
            bytes[i+1]=color[1]
            bytes[i+2]=color[2]
            bytes[i+3]=alpha
          end
        end
        x+=1
      end
      y+=1
    end
    apply_shape_stencil!(bytes,w,h,spec,orig_w,orig_h,world_w,world_h,cos,sin)
    bmp=Bitmap.new(w,h)
    if bmp.respond_to?(:raw_data=)
      bmp.raw_data=bytes.pack('C*')
    else
      h.times do |row|
        w.times do |col|
          i=(row*w+col)*4
          next if bytes[i+3]==0
          bmp.set_pixel(col,row,Color.new(bytes[i],bytes[i+1],bytes[i+2],bytes[i+3]))
        end
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
    @ls_chunk_resolution = LightingStudio::CHUNK_PX
    @ls_chunks = {}
    @ls_chunk_tick = 0
    @ls_ambient_sprite = nil
    @ls_initial_pass = true
    ls_setup
    @ls_initial_pass = false
  end

  def ls_setup
    return unless @map && @map.respond_to?(:map_id)
    LightingStudio.normal_reset_cache if LightingStudio.respond_to?(:normal_reset_cache)
    LightingStudioDayNight.reset_cache if defined?(LightingStudioDayNight)
    LightingStudioNormals.release if defined?(LightingStudioNormals)
    data = LightingStudio.load_map(@map.map_id)
    return unless data.is_a?(Hash) && data['enabled'] != false

    @ls_map_data = data
    ambient = data['ambient'].is_a?(Hash) ? data['ambient'] : {}
    darkness = LightingStudio.number(ambient['darkness'], 0, 0, 1)
    dynamic_day = defined?(LightingStudioDayNight) && LightingStudioDayNight.active_on_map?(data)
    native_tone = dynamic_day && LightingStudioDayNight.native_tone?
    if !native_tone && (darkness > 0 || dynamic_day)
      @ls_ambient_sprite = Sprite.new(Spriteset_Map.viewport)
      @ls_ambient_sprite.bitmap = Bitmap.new(1, 1)
      rgb=LightingStudio.hex_color(ambient['color'])
      @ls_ambient_sprite.bitmap.set_pixel(0, 0, Color.new(rgb[0],rgb[1],rgb[2],255))
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
        source['heightPx'], source['angle'], source['coneFeather'], source['rotation'],
        source['color'], source['softness'], source['centerStrength'],
        source['fadeMode'], source['fadeStart'], source['fadeX'], source['fadeY'],
        source['pixel'],source['maskFile'],source['maskEnabled'],source['maskMode']
      ].inspect
      width, height = LightingStudio.shape_dimensions(source)
      if source['type'] == 'mask'
        width=LightingStudio.number(source['widthPx'],160,8,1024)
        height=LightingStudio.number(source['heightPx'],96,8,1024)
      end
      entry = {
        :bitmap => nil, :spec => source, :key => key, :w => width, :h => height,
        :cx => LightingStudio.number(source['x'],0,-2048,2048)*Game_Map::TILE_WIDTH,
        :cy => LightingStudio.number(source['y'],0,-2048,2048)*Game_Map::TILE_HEIGHT,
        :intensity => LightingStudio.number(source['intensity'],0.8,0,1),
        :pulse => source['pulse'].is_a?(Hash) ? source['pulse'] : {},
        :schedule => source['schedule'].is_a?(Hash) ? source['schedule'] : {}
      }
      mode = source['blendMode'].to_s
      if data['overlapMode'] == 'sum' && ['', 'union', 'add'].include?(mode)
        mode = 'sum'
      end
      mode = 'union' if mode.empty? || mode == 'add'

      if mode == 'union' && entry[:pulse]['enabled'] != true &&
         source['type'] != 'mask' && source['maskEnabled'] != true && entry[:schedule]['enabled'] != true
        # Only smooth cone/ellipse sources increase chunk resolution; retain
        # the cheaper 64px chunks for pixel-art and ordinary map lighting.
        if ['cone','ellipse'].include?(source['type']) && !(source['pixel'].is_a?(Hash) && source['pixel']['enabled'] == true)
          @ls_chunk_resolution = LightingStudio::SMOOTH_CHUNK_PX
        end
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
        sprite.angle = LightingStudio.number(source['rotation'],0,-360,360) if source['type'] == 'mask'
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
    resolution = @ls_chunk_resolution || LightingStudio::CHUNK_PX
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
      # Cache byte-buffer access instead of allocating Color on every sampled texel.
      unless entry.key?(:raw_pixels)
        entry[:raw_pixels]=bmp.respond_to?(:raw_data) ? bmp.raw_data : nil
      end
      rgba=entry[:raw_pixels]

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
              if rgba && rgba.respond_to?(:getbyte)
                pix=(sy*bmp.width+sx)*4
                opa=rgba.getbyte(pix+3)
                if opa && opa>0
                  alpha=opa / 255.0 * entry[:intensity]
                  idx=y*resolution+x
                  nr=(rgba.getbyte(pix)*alpha).round
                  ng=(rgba.getbyte(pix+1)*alpha).round
                  nb=(rgba.getbyte(pix+2)*alpha).round
                  red[idx]=nr if nr>red[idx]
                  green[idx]=ng if ng>green[idx]
                  blue[idx]=nb if nb>blue[idx]
                  has_light=true
                end
              else
                pixel=bmp.get_pixel(sx,sy)
                if pixel.alpha>0
                  alpha=pixel.alpha/255.0*entry[:intensity]
                  idx=y*resolution+x
                  nr=(pixel.red*alpha).round
                  ng=(pixel.green*alpha).round
                  nb=(pixel.blue*alpha).round
                  red[idx]=nr if nr>red[idx]
                  green[idx]=ng if ng>green[idx]
                  blue[idx]=nb if nb>blue[idx]
                  has_light=true
                end
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
    if result.respond_to?(:raw_data=)
      bytes=Array.new(resolution*resolution*4,0)
      idx=0
      while idx<red.length
        if red[idx]>0 || green[idx]>0 || blue[idx]>0
          j=idx*4
          bytes[j]=red[idx]
          bytes[j+1]=green[idx]
          bytes[j+2]=blue[idx]
          bytes[j+3]=255
        end
        idx+=1
      end
      result.raw_data=bytes.pack('C*')
    else
      idx=0
      resolution.times do |y|
        resolution.times do |x|
          if red[idx]>0 || green[idx]>0 || blue[idx]>0
            result.set_pixel(x,y,Color.new(red[idx],green[idx],blue[idx],255))
          end
          idx+=1
        end
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
    budget = @ls_initial_pass ? LightingStudio::INITIAL_CHUNKS : LightingStudio::BUILDS_PER_FRAME
    budget.times do
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

  # Public to the Sleeping Bag test item; forces the same ambient layer used
  # by the ordinary runtime even if the update budget hasn't elapsed.
  def ls_update_day_night(force=false, now=nil)
    return unless defined?(LightingStudioDayNight) && @ls_map_data
    return unless LightingStudioDayNight.active_on_map?(@ls_map_data)
    now ||= System.uptime
    revision=LightingStudioDayNight.revision
    return if !force && @ls_last_clock_revision==revision &&
              @ls_next_daynight_update && now<@ls_next_daynight_update
    @ls_last_clock_revision=revision
    @ls_next_daynight_update=now+0.2
    data=LightingStudioDayNight.ambient(@ls_map_data)
    return unless data
    if LightingStudioDayNight.native_tone?
      # Preserve existing event tones ($game_screen.tone) and apply a
      # channel-based RGB/gray tint instead of an alpha colored rectangle.
      # The base Spriteset_Map#update resets viewport.tone every frame;
      # this plugin restores the combined result afterward.
      @ls_native_values=data
      @ls_ambient_sprite.visible=false if @ls_ambient_sprite
      ls_apply_native_day_night
      return
    end
    color,darkness=data
    if !@ls_ambient_sprite
      @ls_ambient_sprite=Sprite.new(Spriteset_Map.viewport)
      @ls_ambient_sprite.bitmap=Bitmap.new(1,1)
      @ls_ambient_sprite.zoom_x=Graphics.width
      @ls_ambient_sprite.zoom_y=Graphics.height
      @ls_ambient_sprite.z=8500
    end
    color = color.map { |v| [[v.round,0].max,255].min }
    opacity=LightingStudioDayNight.ambient_opacity(darkness)
    if @ls_ambient_last_rgb!=color
      @ls_ambient_sprite.bitmap.set_pixel(0,0,Color.new(*color,255))
      @ls_ambient_last_rgb=color
    end
    @ls_ambient_sprite.opacity=opacity
    @ls_ambient_sprite.visible=opacity>0
  rescue StandardError => e
    warn "[Lighting Studio Time] Ambient refresh failed: #{e.message}"
  end

  def ls_apply_native_day_night
    return unless defined?(LightingStudioDayNight) && @ls_map_data &&
                  LightingStudioDayNight.active_on_map?(@ls_map_data) &&
                  LightingStudioDayNight.native_tone?
    # Connected map spritesets share the same viewport. Only the active map
    # should set it, otherwise an indoor neighbor might replace outdoor tone.
    return if defined?($game_map) && $game_map && @map.map_id!=$game_map.map_id
    viewport=Spriteset_Map.viewport
    return if !viewport || viewport.disposed?
    tone_values=@ls_native_values || LightingStudioDayNight.tone_values
    screen_tone=defined?($game_screen) && $game_screen ? $game_screen.tone : nil
    viewport.tone=LightingStudioDayNight.compose_tone(screen_tone,tone_values)
  rescue StandardError => e
    warn "[Lighting Studio Time] RGSS tone composition failed: #{e.message}"
  end

  def ls_update
    return unless @ls_sprites && @map
    mx = (@map.display_x.to_f / Game_Map::X_SUBPIXELS).round
    my = (@map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
    zx = defined?(TilemapRenderer::ZOOM_X) ? TilemapRenderer::ZOOM_X : 1
    zy = defined?(TilemapRenderer::ZOOM_Y) ? TilemapRenderer::ZOOM_Y : 1
    now = System.uptime

    ls_update_day_night(false, now)
    ls_apply_native_day_night
    ls_update_chunks(mx, my, zx, zy)
    elapsed=@ls_last_light_update ? [[now-@ls_last_light_update,0.0].max,0.10].min : 0.0
    @ls_sprites.each do |sprite, entry|
      size, energy = LightingStudio.pulse_values(entry[:pulse], now)
      sx, sy = ls_world_screen(entry[:cx], entry[:cy], mx, my, zx, zy)
      sprite.zoom_x = zx * size * entry[:w] / sprite.bitmap.width.to_f
      sprite.zoom_y = zy * size * entry[:h] / sprite.bitmap.height.to_f
      scheduled = defined?(LightingStudioDayNight) ?
        LightingStudioDayNight.schedule_factor(entry[:schedule]) : 1.0
      if entry[:schedule]['enabled']==true
        previous=entry[:ls_schedule_alpha]
        previous=scheduled if previous.nil?
        # Smooth the visual switch in real seconds so jumping to 19:00
        # never forces players to wait game-hours to see a streetlamp.
        coefficient=1.0-Math.exp(-elapsed/0.28)
        displayed=previous+(scheduled-previous)*coefficient
        displayed=scheduled if (displayed-scheduled).abs<0.002
        entry[:ls_schedule_alpha]=displayed
        scheduled=displayed
      end
      sprite.opacity = [[(255 * entry[:intensity] * energy * scheduled).round, 0].max, 255].min
      sprite.x = sx
      sprite.y = sy
      bound = [entry[:w], entry[:h]].max * [zx, zy].max * size / 2
      sprite.visible = sprite.opacity > 0 && sx+bound > 0 && sy+bound > 0 &&
                       sx-bound < Graphics.width && sy-bound < Graphics.height
    end
    @ls_last_light_update=now
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
