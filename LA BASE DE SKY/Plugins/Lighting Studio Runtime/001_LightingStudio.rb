# encoding: UTF-8
# Lighting Studio Runtime 0.4.0 for Pokemon Essentials 21.1 / mkxp.
# Shared additive lightmap: merge sources normally, add a single sprite to the map.
# No shaders required; uses Bitmap#stretch_blt for camera/animation updates.
module LightingStudio
  DATA_PATH = 'Data/LightingStudio/maps.json'
  MASK_LIMIT = 128
  LIGHTMAP_SCALE = 0.25
  MAX_SOURCES = 160
  MERGE_FPS = 6
  # Shared union is intentionally low-res; every source broadens the same area
  # without summing its brightness on overlaps.
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
  def falloff(spec, nx, ny)
    type = spec['type'] || 'radial'
    softness = number(spec['softness'],0.75,0.05,1)
    aperture = number(spec['angle'],70,5,170)*Math::PI/360
    d = shape_distance(type,nx,ny,aperture)
    return 0.0 if d >= 1
    mode = spec['fadeMode'] || 'center'
    dist = case mode
           when 'top' then (ny+1)/2.0
           when 'bottom' then (1-ny)/2.0
           when 'left' then (nx+1)/2.0
           when 'right' then (1-nx)/2.0
           when 'custom'
             ox = number(spec['fadeX'],0,-1,1)
             oy = number(spec['fadeY'],0,-1,1)
             Math.sqrt((nx-ox)**2+(ny-oy)**2)/(1+Math.sqrt(ox*ox+oy*oy))
           else d
           end
    dist = [[dist, 0].max,1].min
    core = (1-dist)**(1.0/softness)
    edge = mode == 'center' ? 1.0 : [[(1-d)/[0.035,0.18*softness].max,0].max,1].min
    center = number(spec['centerStrength'],0.65,0,1)
    core*edge*(center+(1-center)*[1.0,d*2].min)
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
    scale = [1.0, MASK_LIMIT/[world_w,world_h].max].min
    w = [[(world_w*scale).round,2].max,MASK_LIMIT].min
    h = [[(world_h*scale).round,2].max,MASK_LIMIT].min
    pixel = spec['pixel'].is_a?(Hash) && spec['pixel']['enabled'] == true ? spec['pixel'] : {}
    step = pixel.empty? ? 1 : [[(number(pixel['size'],6,2,32)*scale).round,1].max,32].min
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
    @ls_add_sources = []
    @ls_ambient_sprite = nil
    @ls_lightmap = nil
    @ls_workmap = nil
    @ls_lightmap_sprite = nil
    @ls_last_frame_key = nil
    ls_setup
  end

  def ls_setup
    return unless @map && @map.respond_to?(:map_id)
    data = LightingStudio.load_map(@map.map_id)
    return unless data.is_a?(Hash) && data['enabled'] != false
    ambient = data['ambient'].is_a?(Hash) ? data['ambient'] : {}
    darkness = LightingStudio.number(ambient['darkness'],0,0,1)
    if darkness > 0
      @ls_ambient_sprite = Sprite.new(Spriteset_Map.viewport)
      @ls_ambient_sprite.bitmap = Bitmap.new(1,1)
      @ls_ambient_sprite.bitmap.set_pixel(0,0,Color.new(0,0,0,255))
      @ls_ambient_sprite.zoom_x = Graphics.width
      @ls_ambient_sprite.zoom_y = Graphics.height
      @ls_ambient_sprite.opacity = (darkness*230).round
      @ls_ambient_sprite.z = 8500
    end
    lights = data['lights'].is_a?(Array) ? data['lights'].first(LightingStudio::MAX_SOURCES) : []
    cache = {}
    lights.each do |s|
      next unless s.is_a?(Hash) && s['enabled'] != false
      key = [s['type'],s['radiusPx'],s['widthPx'],s['heightPx'],s['angle'],s['rotation'],
        s['color'],s['softness'],s['centerStrength'],s['fadeMode'],s['fadeX'],s['fadeY'],s['pixel']].inspect
      entry = cache[key]
      unless entry
        entry = LightingStudio.shape_bitmap(s)
        cache[key] = entry
        @ls_bitmaps << entry[0]
      end
      bmp,w,h = entry
      x = LightingStudio.number(s['x'],0,-2048,2048)
      y = LightingStudio.number(s['y'],0,-2048,2048)
      intensity = LightingStudio.number(s['intensity'],0.8,0,1)
      pulse = s['pulse'].is_a?(Hash) ? s['pulse'] : {}
      mode = s['blendMode'].to_s
      if data['overlapMode']=='sum' && ['','add','union'].include?(mode)
        mode = 'sum'
      end
      if ['','add','union'].include?(mode)
        @ls_add_sources << [bmp,w,h,x,y,intensity,pulse]
      else
        sprite = Sprite.new(Spriteset_Map.viewport)
        sprite.bitmap = bmp
        sprite.ox = bmp.width/2
        sprite.oy = bmp.height/2
        sprite.blend_type = mode=='subtract' ? 2 : mode=='sum' ? 1 : 0
        sprite.z = 8501
        @ls_sprites << [sprite,w,h,x,y,intensity,pulse]
      end
    end
    unless @ls_add_sources.empty?
      width = [(Graphics.width*LightingStudio::LIGHTMAP_SCALE).ceil,1].max
      height = [(Graphics.height*LightingStudio::LIGHTMAP_SCALE).ceil,1].max
      @ls_lightmap = Bitmap.new(width,height)
      @ls_workmap = Bitmap.new(width,height)
      @ls_lightmap_sprite = Sprite.new(Spriteset_Map.viewport)
      @ls_lightmap_sprite.bitmap = @ls_lightmap
      @ls_lightmap_sprite.zoom_x = Graphics.width.to_f/width
      @ls_lightmap_sprite.zoom_y = Graphics.height.to_f/height
      @ls_lightmap_sprite.x = 0
      @ls_lightmap_sprite.y = 0
      @ls_lightmap_sprite.ox = 0
      @ls_lightmap_sprite.oy = 0
      @ls_lightmap_sprite.blend_type = 1
      @ls_lightmap_sprite.z = 8501
    end
    ls_update
  end

  def ls_position(tx,ty,mx,my,zx,zy)
    sx = tx*Game_Map::TILE_WIDTH-mx
    sy = ty*Game_Map::TILE_HEIGHT-my
    # Mirror LBDS Animated Props map-to-screen transform for game zoom.
    if zx != 1
      sx = (sx - Graphics.width / 2) * zx + Graphics.width / 2
    end
    if zy != 1
      sy = (sy - Graphics.height / 2) * zy + Graphics.height / 2
    end
    [sx,sy]
  end

  def ls_compose(now,mx,my,zx,zy)
    return unless @ls_lightmap && @ls_add_sources && !@ls_add_sources.empty?
    animated = @ls_add_sources.any? { |s| s[6]['enabled']==true }
    frame = animated ? (now*LightingStudio::MERGE_FPS).floor : 0
    key = [mx.round(2),my.round(2),zx,zy,frame]
    return if key == @ls_last_frame_key
    @ls_last_frame_key = key
    @ls_lightmap.clear
    rx = @ls_lightmap.width.to_f/Graphics.width
    ry = @ls_lightmap.height.to_f/Graphics.height
    @ls_add_sources.each do |bmp,w,h,tx,ty,intensity,pulse|
      size,energy = LightingStudio.pulse_values(pulse,now)
      alpha = [[(255*intensity*energy).round,0].max,255].min
      next if alpha<=0
      x,y = ls_position(tx,ty,mx,my,zx,zy)
      # Match LBDS Animated Props sprite.x/y integer rounding at non-100% zoom.
      x = x.round
      y = y.round
      sw=w*zx*size;sh=h*zy*size
      next if x+sw/2<0 || y+sh/2<0 || x-sw/2>Graphics.width || y-sh/2>Graphics.height
      dx=((x-sw/2)*rx).round;dy=((y-sh/2)*ry).round
      dw=[(sw*rx).round,1].max;dh=[(sh*ry).round,1].max
      # Render each lantern into a temporary mask, then apply per-channel MAX.
      # This makes overlap widen the lit area without doubling its intensity.
      left = [[dx,0].max,@ls_lightmap.width].min
      top = [[dy,0].max,@ls_lightmap.height].min
      right = [[dx+dw,0].max,@ls_lightmap.width].min
      bottom = [[dy+dh,0].max,@ls_lightmap.height].min
      next if right<=left || bottom<=top
      @ls_workmap.clear
      @ls_workmap.stretch_blt(Rect.new(dx,dy,dw,dh),bmp,Rect.new(0,0,bmp.width,bmp.height),alpha)
      yy=top
      while yy<bottom
        xx=left
        while xx<right
          source=@ls_workmap.get_pixel(xx,yy)
          if source.alpha>0
            dest=@ls_lightmap.get_pixel(xx,yy)
            factor=source.alpha/255.0
            r=[dest.red,(source.red*factor).round].max
            g=[dest.green,(source.green*factor).round].max
            b=[dest.blue,(source.blue*factor).round].max
            @ls_lightmap.set_pixel(xx,yy,Color.new(r,g,b,255))
          end
          xx+=1
        end
        yy+=1
      end
    end
  end

  def ls_update
    return unless @ls_sprites && @map
    mx=(@map.display_x.to_f/Game_Map::X_SUBPIXELS).round
    my=(@map.display_y.to_f/Game_Map::Y_SUBPIXELS).round
    zx=defined?(TilemapRenderer::ZOOM_X) ? TilemapRenderer::ZOOM_X : 1
    zy=defined?(TilemapRenderer::ZOOM_Y) ? TilemapRenderer::ZOOM_Y : 1
    now=System.uptime
    ls_compose(now,mx,my,zx,zy)
    @ls_sprites.each do |sprite,w,h,tx,ty,intensity,pulse|
      size,energy=LightingStudio.pulse_values(pulse,now)
      sx,sy=ls_position(tx,ty,mx,my,zx,zy)
      sprite.zoom_x=zx*size*w/sprite.bitmap.width.to_f
      sprite.zoom_y=zy*size*h/sprite.bitmap.height.to_f
      sprite.opacity=[[((255*intensity*energy).round),0].max,255].min
      sprite.x=sx.round;sprite.y=sy.round
      bound=[w,h].max*[zx,zy].max*size/2
      sprite.visible = sx+bound>0 && sy+bound>0 &&
                       sx-bound<Graphics.width && sy-bound<Graphics.height
    end
  end

  def update
    super
    ls_update
  end

  def dispose
    @ls_sprites&.each { |row| row[0].dispose unless row[0].disposed? }
    @ls_sprites=nil
    if @ls_lightmap_sprite
      @ls_lightmap_sprite.dispose unless @ls_lightmap_sprite.disposed?
      @ls_lightmap_sprite=nil
    end
    if @ls_lightmap
      @ls_lightmap.dispose unless @ls_lightmap.disposed?
      @ls_lightmap=nil
    end
    if @ls_workmap
      @ls_workmap.dispose unless @ls_workmap.disposed?
      @ls_workmap=nil
    end
    if @ls_ambient_sprite
      bmp=@ls_ambient_sprite.bitmap
      @ls_ambient_sprite.dispose unless @ls_ambient_sprite.disposed?
      bmp.dispose if bmp && !bmp.disposed?
      @ls_ambient_sprite=nil
    end
    @ls_bitmaps&.each { |bmp| bmp.dispose unless bmp.disposed? }
    @ls_bitmaps=nil
    super
  end
end

Spriteset_Map.prepend(LightingStudioSpriteset) unless Spriteset_Map.ancestors.include?(LightingStudioSpriteset)
