# encoding: UTF-8
# Lighting Studio / Character normals v0.5.2
# Experimental, visible RGSS overlay for player and follower sprites.
# This is a CACHED SOFTWARE NORMAL-LIGHT PASS, not a GPU shader.
# It computes at most one small sprite frame per graphics frame and reuses
# directional masks afterwards; there is no per-pixel processing in update.
module LightingStudioNormals
  MAX_BITMAPS = 96
  MAX_FRAME_SIDE = 192
  LIGHT_HEIGHT = 0.76
  LIGHT_HORIZONTAL = 0.65
  ATTACK_SECONDS = 0.10
  RELEASE_SECONDS = 0.24
  EDGE_FADE_START = 0.60
  NORMAL_LIGHT_Z = 8502
  @mode = :lit
  @normal_raw = {}
  @normal_bitmaps = {}
  @frames = {}
  @attached = {}
  @last_build_frame = nil
  @last_light_map = nil
  @lights = []
  @warned = {}

  class << self
    attr_reader :mode
  end
  module_function

  def mode=(value)
    @mode = [:lit, :normals, :original].include?(value) ? value : :lit
  end

  def warn_once(key, message)
    return if @warned[key]
    @warned[key] = true
    warn "[Lighting Studio Normals] #{message}"
  end

  def clear_lights
    @last_light_map = nil
    @lights = []
  end

  def valid_sprite?(sprite)
    return false if !sprite || (sprite.respond_to?(:disposed?) && sprite.disposed?)
    true
  end

  def register(sprite)
    @attached[sprite.object_id] = sprite
  end

  def unregister(sprite)
    @attached.delete(sprite.object_id) if sprite
  end

  def release
    @attached.each_value do |sprite|
      next unless valid_sprite?(sprite)
      begin
        sprite.bitmap = nil
        sprite.visible = false
      rescue StandardError
      end
    end
    @frames.each_value { |bmp| bmp.dispose if bmp && !bmp.disposed? }
    @normal_bitmaps.each_value { |bmp| bmp.dispose if bmp && !bmp.disposed? }
    @frames.clear
    @normal_bitmaps.clear
    @normal_raw.clear
    @last_build_frame = nil
    clear_lights
  end

  def clock_seconds
    return System.uptime if defined?(System) && System.respond_to?(:uptime)
    Time.now.to_f
  end

  # Cache only static light settings. Evaluate pulse on each update using
  # LightingStudio.pulse_values, the SAME clock/radius/intensity as map lights.
  def light_sources(map_id)
    return @lights if @last_light_map == map_id
    data = LightingStudio.load_map(map_id)
    @last_light_map = map_id
    @lights = []
    return @lights unless data.is_a?(Hash) && data['enabled'] != false
    list = data['lights'].is_a?(Array) ? data['lights'] : []
    list.first(80).each do |src|
      next unless src.is_a?(Hash) && src['enabled'] != false
      radius = LightingStudio.number(src['radiusPx'], 96, 8, 512)
      cx = LightingStudio.number(src['x'], 0, -2048, 2048) * Game_Map::TILE_WIDTH
      cy = LightingStudio.number(src['y'], 0, -2048, 2048) * Game_Map::TILE_HEIGHT
      color = LightingStudio.hex_color(src['color'])
      pulse = src['pulse'].is_a?(Hash) ? src['pulse'] : {}
      type = src['type'].to_s
      rotation = LightingStudio.number(src['rotation'], 0, -360, 360) * Math::PI / 180.0
      width = LightingStudio.number(src['widthPx'], 160, 8, 1024)
      height = LightingStudio.number(src['heightPx'], 96, 8, 1024)
      angle = LightingStudio.number(src['angle'], 70, 5, 170) * Math::PI / 360.0
      @lights << [cx, cy, radius, color,
                  LightingStudio.number(src['intensity'], 0.8, 0, 1),
                  pulse, type, rotation, width, height, angle]
    end
    @lights
  rescue StandardError => e
    warn_once(:lights, "Could not load map lights: #{e.message}")
    @lights = []
  end

  def smooth_edge(progress)
    return 1.0 if progress <= EDGE_FADE_START
    return 0.0 if progress >= 1.0
    t = (progress - EDGE_FADE_START) / (1.0 - EDGE_FADE_START)
    1.0 - t*t*(3.0 - 2.0*t)
  end

  def character_world_position(character)
    if character.respond_to?(:real_x) && character.respond_to?(:real_y) &&
       !character.real_x.nil? && !character.real_y.nil?
      width = character.respond_to?(:width) ? character.width : 1
      cx = character.real_x.to_f / Game_Map::X_SUBPIXELS +
           width.to_f * Game_Map::TILE_WIDTH / 2.0
      cy = character.real_y.to_f / Game_Map::Y_SUBPIXELS +
           Game_Map::TILE_HEIGHT / 2.0
    else
      cx = (character.x.to_f + 0.5) * Game_Map::TILE_WIDTH
      cy = (character.y.to_f + 0.5) * Game_Map::TILE_HEIGHT
    end
    [cx, cy]
  end

  def nearby_light(character, now = nil)
    map = character.respond_to?(:map) ? character.map : $game_map
    return nil unless map && map.respond_to?(:map_id)
    now ||= clock_seconds
    cx,cy = character_world_position(character)
    best = nil
    score = 0.0
    light_sources(map.map_id).each do |lx,ly,radius,rgb,intensity,pulse,type,rotation,width,height,angle|
      size, energy = LightingStudio.pulse_values(pulse, now)
      next if energy <= 0.0 || intensity <= 0.0
      dx=lx-cx
      dy=ly-cy
      # Rotate into the light's local space, matching the static masks.
      cos=Math.cos(rotation)
      sin=Math.sin(rotation)
      local_x=cos*dx+sin*dy
      local_y=-sin*dx+cos*dy
      progress = case type
                 when 'ellipse'
                   Math.sqrt((local_x/(width*size/2.0))**2 +
                             (local_y/(height*size/2.0))**2)
                 when 'rectangle'
                   [(local_x/(width*size/2.0)).abs,
                    (local_y/(height*size/2.0)).abs].max
                 when 'cone'
                   # The cone emits along +X; dx/dy point from character to light,
                   # so the character's position relative to the light is negated.
                   fx=-local_x
                   fy=-local_y
                   next if fx < 0
                   reach=Math.sqrt(fx*fx+fy*fy)/(radius*size)
                   azimuth=Math.atan2(fy,fx).abs
                   next if azimuth >= angle
                   reach
                 else
                   Math.sqrt(dx*dx+dy*dy)/(radius*size)
                 end
      next if progress >= 1.0
      # No hard cutoff at the light's radius: both shape and strength taper
      # continuously to zero. Radius AND intensity obey the pulse waveform.
      strength = [[intensity*energy*smooth_edge(progress),0.0].max,1.0].min
      next if strength <= score
      score = strength
      theta = Math.atan2(dy,dx)
      direction = ((theta*4.0/Math::PI).round) % 8
      best = [direction,rgb,strength]
    end
    best
  end

  def eased_opacity(overlay, target, now)
    current = overlay.instance_variable_get(:@ls_normal_smooth_opacity)
    current = 0.0 if current.nil?
    previous = overlay.instance_variable_get(:@ls_normal_last_time)
    delta = previous ? [[now-previous, 0.0].max,0.1].min : 1.0/60.0
    duration = target > current ? ATTACK_SECONDS : RELEASE_SECONDS
    coefficient = 1.0 - Math.exp(-delta/duration)
    current += (target-current)*coefficient
    current = target if (target-current).abs < 0.5
    overlay.instance_variable_set(:@ls_normal_last_time,now)
    overlay.instance_variable_set(:@ls_normal_smooth_opacity,current)
    [[current.round,0].max,255].min
  end

  def normal_bitmap(path)
    return @normal_bitmaps[path] if @normal_bitmaps.key?(path)
    bitmap = Bitmap.new(path)
    raw = bitmap.respond_to?(:raw_data) ? bitmap.raw_data : nil
    if !raw || !raw.respond_to?(:getbyte)
      warn_once(:raw_data,"Bitmap.raw_data is missing; normal shading disabled on this engine.")
      bitmap.dispose unless bitmap.disposed?
      return nil
    end
    @normal_bitmaps[path] = bitmap
    @normal_raw[path] = raw
    bitmap
  rescue StandardError => e
    warn_once(path, "Could not read #{path}: #{e.message}")
    nil
  end

  def frame_bitmap(path, rect, direction, color)
    normal = normal_bitmap(path)
    return nil unless normal
    rx,ry,w,h = rect.map { |x| x.to_i }
    return nil if w<=0 || h<=0 || w>MAX_FRAME_SIDE || h>MAX_FRAME_SIDE
    return nil if rx<0 || ry<0 || rx+w>normal.width || ry+h>normal.height
    key=[path,rx,ry,w,h,direction,color].join('|')
    if (found=@frames.delete(key))
      @frames[key]=found
      return found
    end
    frame_id=Graphics.respond_to?(:frame_count) ? Graphics.frame_count : nil
    return nil if !frame_id.nil? && @last_build_frame == frame_id
    @last_build_frame=frame_id

    # Quantize to eight light directions and keep their baked frames.
    # Result never changes with each camera update; only the sprite's opacity.
    angle=direction*Math::PI/4.0
    lx=Math.cos(angle)*LIGHT_HORIZONTAL
    ly=Math.sin(angle)*LIGHT_HORIZONTAL
    lz=LIGHT_HEIGHT
    raw=@normal_raw[path]
    result=Array.new(w*h*4,0)
    cr,cg,cb=color
    yy=0
    while yy<h
      xx=0
      while xx<w
        src=(((ry+yy)*normal.width)+rx+xx)*4
        alpha=raw.getbyte(src+3)
        if alpha && alpha>0
          nx=(raw.getbyte(src)/127.5)-1.0
          ny=(raw.getbyte(src+1)/127.5)-1.0
          nz=(raw.getbyte(src+2)/127.5)-1.0
          dot=nx*lx+ny*ly+nz*lz
          response=[[((dot-0.25)/0.75),0.0].max,1.0].min
          if response>0
            dst=(yy*w+xx)*4
            result[dst]=(cr*response).round
            result[dst+1]=(cg*response).round
            result[dst+2]=(cb*response).round
            result[dst+3]=alpha
          end
        end
        xx+=1
      end
      yy+=1
    end
    bmp=Bitmap.new(w,h)
    bmp.raw_data=result.pack('C*')
    @frames[key]=bmp
    if @frames.length>MAX_BITMAPS
      victim=@frames.keys.find do |other_key|
        old=@frames[other_key]
        !@attached.values.any? { |sprite| valid_sprite?(sprite) && sprite.bitmap.equal?(old) }
      end
      if victim
        old=@frames.delete(victim)
        old.dispose if old && !old.disposed?
      end
    end
    bmp
  rescue StandardError => e
    warn_once(:bake,"Could not bake normal frame: #{e.message}")
    nil
  end

  def update_character(base, overlay)
    return unless valid_sprite?(overlay)
    if @mode == :original || !base.visible || !base.bitmap
      overlay.visible = false
      overlay.instance_variable_set(:@ls_normal_smooth_opacity,0.0)
      overlay.instance_variable_set(:@ls_normal_last_time,nil)
      return
    end
    unless base.character && base.character.respond_to?(:character_name)
      overlay.visible=false
      return
    end
    path = LightingStudio.normal_for_character(base.character)
    unless path
      overlay.visible=false
      return
    end
    rect = base.src_rect
    return unless rect && rect.width>0 && rect.height>0

    if @mode == :normals
      bitmap = normal_bitmap(path)
      return unless bitmap && rect.x+rect.width<=bitmap.width && rect.y+rect.height<=bitmap.height
      overlay.bitmap=bitmap if overlay.bitmap!=bitmap
      overlay.src_rect.set(rect.x,rect.y,rect.width,rect.height)
      overlay.blend_type=0
      overlay.opacity=255
      overlay.instance_variable_set(:@ls_normal_baked,false)
    else
      now=clock_seconds
      info=nearby_light(base.character,now)
      target=info ? [[(info[2]*190).round,0].max,255].min : 0
      if info && target > 0
        direction,color,strength=info
        bitmap=frame_bitmap(path,[rect.x,rect.y,rect.width,rect.height],direction,color)
        if bitmap
          overlay.bitmap=bitmap if overlay.bitmap!=bitmap
          overlay.src_rect.set(0,0,bitmap.width,bitmap.height)
          overlay.instance_variable_set(:@ls_normal_baked,true)
        end
        # One bitmap may be generated per frame; retain the previous cached
        # frame instead of blinking when the new direction is still baking.
      end
      baked=overlay.instance_variable_get(:@ls_normal_baked)
      if !baked || !overlay.bitmap
        overlay.visible=false
        return
      end
      overlay.blend_type=1
      opacity=eased_opacity(overlay,target,now)
      overlay.opacity=opacity
      # Keep the old illumination frame while fading out beyond light radius.
      # Do NOT clear its bitmap or hide at the beginning of update.
      if opacity <= 0
        overlay.visible=false
        return
      end
    end

    overlay.x=base.x
    overlay.y=base.y
    overlay.ox=base.ox
    overlay.oy=base.oy
    overlay.zoom_x=base.zoom_x
    overlay.zoom_y=base.zoom_y
    overlay.angle=base.angle if base.respond_to?(:angle)
    overlay.mirror=base.mirror if base.respond_to?(:mirror)
    overlay.z=NORMAL_LIGHT_Z
    overlay.visible=true
  rescue StandardError => e
    warn_once(:update,"Normal overlay disabled after error: #{e.message}")
    overlay.visible=false
  end

end

module LightingStudioCharacterNormalSprites
  def update
    super
    return unless @character
    eligible=(@character==$game_player || @follower==true)
    if !eligible
      @ls_normal_overlay.visible=false if @ls_normal_overlay && !@ls_normal_overlay.disposed?
      return
    end
    if !@ls_normal_overlay || @ls_normal_overlay.disposed?
      @ls_normal_overlay=Sprite.new(self.viewport)
      @ls_normal_overlay.visible=false
      LightingStudioNormals.register(@ls_normal_overlay)
    end
    LightingStudioNormals.update_character(self,@ls_normal_overlay)
  end

  def dispose
    if @ls_normal_overlay && !@ls_normal_overlay.disposed?
      LightingStudioNormals.unregister(@ls_normal_overlay)
      @ls_normal_overlay.dispose
    end
    @ls_normal_overlay=nil
    super
  end
end

if defined?(Sprite_Character) &&
   !Sprite_Character.ancestors.include?(LightingStudioCharacterNormalSprites)
  Sprite_Character.prepend(LightingStudioCharacterNormalSprites)
end
