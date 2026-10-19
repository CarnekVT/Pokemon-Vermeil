# encoding: UTF-8
# Lighting Studio / Character normals v0.5.0
# Experimental, visible RGSS overlay for player and follower sprites.
# This is a CACHED SOFTWARE NORMAL-LIGHT PASS, not a GPU shader.
# It computes at most one small sprite frame per graphics frame and reuses
# directional masks afterwards; there is no per-pixel processing in update.
module LightingStudioNormals
  MAX_BITMAPS = 96
  MAX_FRAME_SIDE = 192
  LIGHT_HEIGHT = 0.76
  LIGHT_HORIZONTAL = 0.65
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
      cx = LightingStudio.number(src['x'], 0, -2048, 2048)*Game_Map::TILE_WIDTH
      cy = LightingStudio.number(src['y'], 0, -2048, 2048)*Game_Map::TILE_HEIGHT
      color = LightingStudio.hex_color(src['color'])
      @lights << [cx, cy, radius, color, LightingStudio.number(src['intensity'],0.8,0,1)]
    end
    @lights
  rescue StandardError => e
    warn_once(:lights, "Could not load map lights: #{e.message}")
    @lights = []
  end

  def nearby_light(character)
    map = character.respond_to?(:map) ? character.map : $game_map
    return nil unless map && map.respond_to?(:map_id)
    cx = (character.x.to_f+0.5)*Game_Map::TILE_WIDTH
    cy = (character.y.to_f+0.5)*Game_Map::TILE_HEIGHT
    best = nil
    score = 0.0
    light_sources(map.map_id).each do |lx,ly,radius,rgb,intensity|
      dx=lx-cx
      dy=ly-cy
      distance=Math.sqrt(dx*dx+dy*dy)
      next if distance>=radius+24.0
      # A deliberately conservative one-light budget for the initial runtime:
      # nearest/strongest light governs surface normals without additive stacking.
      strength=intensity*(1.0-distance/(radius+24.0))
      next if strength<=score
      score=strength
      theta=Math.atan2(dy,dx)
      direction=((theta*4.0/Math::PI).round) % 8
      best=[direction,rgb,strength]
    end
    best
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
    overlay.visible=false
    return if @mode==:original || !base.visible || !base.bitmap
    return unless base.character && base.character.respond_to?(:character_name)
    path=LightingStudio.normal_for_character(base.character)
    return unless path
    rect=base.src_rect
    return unless rect && rect.width>0 && rect.height>0
    if @mode==:normals
      bmp=normal_bitmap(path)
      return unless bmp && rect.x+rect.width<=bmp.width && rect.y+rect.height<=bmp.height
      overlay.bitmap=bmp if overlay.bitmap!=bmp
      overlay.src_rect.set(rect.x,rect.y,rect.width,rect.height)
      overlay.blend_type=0
      overlay.opacity=255
    else
      info=nearby_light(base.character)
      return unless info
      direction,color,strength=info
      bmp=frame_bitmap(path,[rect.x,rect.y,rect.width,rect.height],direction,color)
      return unless bmp
      overlay.bitmap=bmp if overlay.bitmap!=bmp
      overlay.src_rect.set(0,0,bmp.width,bmp.height)
      overlay.blend_type=1
      overlay.opacity=[[((strength*190).round),0].max,255].min
    end

    # Draw the overlay over the same frame/anchor as the original Sprite_Character.
    # At z=8502 it appears above Lighting Studio's ambient/halo layers so the
    # surface response is visible; strict occlusion still requires engine shaders.
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
