#===============================================================================
# CREDITOS
# Golisopod User, Wolf PP, Marin, Zik
# Website    = https://www.youtube.com/watch?v=dQw4w9WgXcQ
#===============================================================================

#-------------------------------------------------------------------------------
# Global variable to track all shadows without losing references
#-------------------------------------------------------------------------------
$all_ow_shadows = [] if !$all_ow_shadows

#-------------------------------------------------------------------------------
# New Class for Shadow object
#-------------------------------------------------------------------------------
class Sprite_OWShadow
  attr_reader :visible
  attr_reader :sprite
  attr_reader :shadow_data

  #-----------------------------------------------------------------------------
  # Initialize a shadow sprite based on the name of the event
  #-----------------------------------------------------------------------------
  def initialize(sprite, event, viewport = nil)
    @rsprite  = sprite
    @event    = event
    @viewport = viewport
    @sprite   = Sprite.new(viewport)
    @disposed = false
    @remove   = false
    @fix_radius = 0
    @fix_x      = 0
    @fix_y      = 0
    
    @shadow_data = nil
    @render_bitmap = nil
    @custom_shadow_bitmap = nil
    
    # Track character/bitmap changes to regenerate shadow when needed
    @last_character_name = nil
    @last_bitmap = nil
    @shadow_fade = 1.0
    $all_ow_shadows << self
    
    update
  end
  #-----------------------------------------------------------------------------
  # Helper to calculate coordinates for the first frame
  #-----------------------------------------------------------------------------
  def get_frame_coordinates
    rect = @rsprite.src_rect
    bitmap = @rsprite.bitmap
    
    # Si el src_rect tiene las dimensiones completas del bitmap, calculamos el tamaño del frame
    # dividiendo por 4 (formato estándar de spritesheets 4x4)
    if rect.width == bitmap.width && rect.height == bitmap.height
      cw = bitmap.width / 4
      ch = bitmap.height / 4
    else
      cw = rect.width
      ch = rect.height
    end
    
    sx = 0
    sy = 0   

    if @event.respond_to?(:character_name) && @event.character_name && !@event.character_name.empty?
      char_name = @event.character_name
      is_single_sheet = char_name[/^[\$\!]./] ? true : false
      is_single_sheet = true if char_name.downcase.include?("follower")
      
      if is_single_sheet
        sx = 0
        sy = 0
      else
        idx = (@event.respond_to?(:character_index) ? @event.character_index : 0)
        char_col = idx % 4
        char_row = idx / 4        
        frames_per_char = (bitmap.width / cw) / 4
        frames_per_char = 4 if frames_per_char < 1        
        sx = char_col * (frames_per_char * cw)
        sy = (char_row * (4 * ch))
      end
    end    

    if sx + cw > bitmap.width || sy + ch > bitmap.height
      return rect.x, rect.y
    end   

    return sx, sy
  end
  #-----------------------------------------------------------------------------
  # Analyzes pixel density
  #-----------------------------------------------------------------------------
  def analyze_footprint(bitmap, sx, sy, cw, ch)
    mass_pixels = []
    sum_x = 0

    (0...cw).each do |x|
      (0...ch).each do |y|
        next if (sx + x) >= bitmap.width || (sy + y) >= bitmap.height
        if bitmap.get_pixel(sx + x, sy + y).alpha > 20
          mass_pixels << x
          sum_x += x
        end
      end
    end

    total_mass = mass_pixels.size
    return cw, 0 if total_mass == 0

    com_x = sum_x.to_f / total_mass
    
    variance_sum = 0.0
    mass_pixels.each do |x|
      variance_sum += (x - com_x)**2
    end
    
    variance = variance_sum / total_mass
    std_dev = Math.sqrt(variance)

    core_width = (std_dev * 3.5).round
    frame_center = cw / 2.0
    offset_x = com_x - frame_center

    return core_width, offset_x
  end
  #-----------------------------------------------------------------------------
  # Generate a procedural shadow bitmap
  #-----------------------------------------------------------------------------
  def generate_shadow_data
    return nil if !@rsprite.bitmap || @rsprite.disposed?
    
    bitmap = @rsprite.bitmap
    rect = @rsprite.src_rect
    
    # Si el src_rect tiene las dimensiones completas del bitmap, calculamos el tamaño del frame
    # dividiendo por 4 (formato estándar de spritesheets 4x4)
    if rect.width == bitmap.width && rect.height == bitmap.height
      cw = bitmap.width / 4
      ch = bitmap.height / 4
    else
      cw = rect.width
      ch = rect.height
    end
    
    sx, sy = get_frame_coordinates

    if OWShadowSettings::AUTOMATIC_SHADOW_GENERATION
      core_width, offset_x = analyze_footprint(bitmap, sx, sy, cw, ch)
      logical_width = (core_width / 2.0).ceil
      logical_width = [logical_width, OWShadowSettings::FIXED_SHADOW_SIZE].max
    else
      offset_x = 0
      logical_width = OWShadowSettings::FIXED_SHADOW_SIZE
    end
    
    logical_width += @fix_radius    
    logical_width = [logical_width, 6].max
    logical_width += 1 if logical_width.odd?
    
    extra_width = [logical_width - 8, 0].max
    logical_height = 4 + (extra_width / 4)
    logical_height = [logical_height, 10].min
    logical_height += 1 if logical_height.odd?
    
    bmp = Bitmap.new(logical_width * 2, logical_height * 2)
    color = Color.new(0, 0, 0, 80)
    
    cx = logical_width / 2.0 - 0.5
    cy = logical_height / 2.0 - 0.5
    rx = logical_width / 2.0
    ry = logical_height / 2.0

    (0...logical_height).each do |y|
      (0...logical_width).each do |x|
        dx = (x - cx) / rx
        dy = (y - cy) / ry
        if (dx**2 + dy**2) <= 1.0
           bmp.fill_rect(x * 2, y * 2, 2, 2, color)
        end
      end
    end
    
    return { :bitmap => bmp, :offset => offset_x }
  end
  #-----------------------------------------------------------------------------
  # Shadow Fusion Logic (Clipping)
  #-----------------------------------------------------------------------------
  def apply_shadow_fusion(base_bmp, src_rect = nil)
    my_rect = src_rect || base_bmp.rect
    
    if !@render_bitmap || @render_bitmap.width != my_rect.width || @render_bitmap.height != my_rect.height
      @render_bitmap.dispose if @render_bitmap
      @render_bitmap = Bitmap.new(my_rect.width, my_rect.height)
    end

    @render_bitmap.clear
    @render_bitmap.blt(0, 0, base_bmp, my_rect)

    my_x = @sprite.x
    my_y = @sprite.y
    my_ox = @sprite.ox
    my_oy = @sprite.oy
    my_zx = @sprite.zoom_x
    my_zy = @sprite.zoom_y

    exact_p_x1 = my_x - (my_ox * my_zx)
    exact_p_x2 = exact_p_x1 + (my_rect.width * my_zx)
    exact_p_y1 = my_y - (my_oy * my_zy)
    exact_p_y2 = exact_p_y1 + (my_rect.height * my_zy)

    $all_ow_shadows.each do |other|
      next if other == self
      next if other.disposed?
      
      o_sprite = other.sprite
      next if !o_sprite || o_sprite.disposed? || !o_sprite.visible || o_sprite.opacity == 0
      next if other.__id__ > self.__id__ 
      
      o_x = o_sprite.x
      o_y = o_sprite.y
      
      # Distance Culling
      next if (my_x - o_x).abs > 64 || (my_y - o_y).abs > 64
      
      o_bmp = o_sprite.bitmap
      next if !o_bmp || o_bmp.disposed?
      
      o_rect = o_sprite.src_rect
      o_ox = o_sprite.ox
      o_oy = o_sprite.oy
      o_zx = o_sprite.zoom_x
      o_zy = o_sprite.zoom_y
      
      exact_o_x1 = o_x - (o_ox * o_zx)
      exact_o_x2 = exact_o_x1 + (o_rect.width * o_zx)
      exact_o_y1 = o_y - (o_oy * o_zy)
      exact_o_y2 = exact_o_y1 + (o_rect.height * o_zy)
      
      ix = [exact_p_x1, exact_o_x1].max
      iy = [exact_p_y1, exact_o_y1].max
      iw = [exact_p_x2, exact_o_x2].min - ix
      ih = [exact_p_y2, exact_o_y2].min - iy
      
      next if iw <= 0 || ih <= 0
      
      start_px = ((ix - exact_p_x1) / my_zx).floor
      end_px   = ((ix + iw - exact_p_x1) / my_zx).ceil
      start_py = ((iy - exact_p_y1) / my_zy).floor
      end_py   = ((iy + ih - exact_p_y1) / my_zy).ceil
      
      loop_start_x = [start_px - 1, 0].max
      loop_end_x   = [end_px + 1, my_rect.width].min
      loop_start_y = [start_py - 1, 0].max
      loop_end_y   = [end_py + 1, my_rect.height].min
      
      (loop_start_x...loop_end_x).each do |px|
        (loop_start_y...loop_end_y).each do |py|
          next if @render_bitmap.get_pixel(px, py).alpha == 0
          
          screen_px = exact_p_x1 + (px * my_zx)
          screen_py = exact_p_y1 + (py * my_zy)
          
          local_o_x = ((screen_px - o_x) / o_zx) + o_ox
          local_o_y = ((screen_py - o_y) / o_zy) + o_oy
          
          local_o_x = o_rect.width - 1.0 - local_o_x if o_sprite.mirror
          
          if local_o_x >= -0.5 && local_o_x <= o_rect.width - 0.5 && local_o_y >= -0.5 && local_o_y <= o_rect.height - 0.5
            ox_clamp = local_o_x.round.clamp(0, o_rect.width - 1)
            oy_clamp = local_o_y.round.clamp(0, o_rect.height - 1)
            
            sample_x = o_rect.x + ox_clamp
            sample_y = o_rect.y + oy_clamp
            
            if o_bmp.get_pixel(sample_x, sample_y).alpha > 20 
              @render_bitmap.clear_rect(px, py, 1, 1)
            end
          end
        end
      end
    end

    return @render_bitmap
  end
  #-----------------------------------------------------------------------------
  # Invalidate shadow data to force regeneration
  #-----------------------------------------------------------------------------
  def invalidate_shadow_data
    @shadow_data[:bitmap].dispose if @shadow_data && @shadow_data[:bitmap]
    @shadow_data = nil
  end
  #-----------------------------------------------------------------------------
  # Override the bitmap of the shadow sprite
  #-----------------------------------------------------------------------------
  def set_bitmap(name)
    invalidate_shadow_data
    @custom_shadow_bitmap&.dispose
    @custom_shadow_bitmap = nil
    @sprite.dispose if @sprite && !@sprite.disposed?
    @sprite = nil
    @sprite = Sprite.new(@viewport)
    update
  end
  #-----------------------------------------------------------------------------
  # Dispose the shadow bitmap
  #-----------------------------------------------------------------------------
  def dispose
    return if @disposed
    $all_ow_shadows.delete(self)
    @sprite.dispose if @sprite
    @shadow_data[:bitmap].dispose if @shadow_data && @shadow_data[:bitmap]
    @render_bitmap.dispose if @render_bitmap
    @custom_shadow_bitmap.dispose if @custom_shadow_bitmap
    @sprite = nil
    @disposed = true
  end
  #-----------------------------------------------------------------------------
  # Check whether the shadow has been disposed
  #-----------------------------------------------------------------------------
  def disposed?; return @disposed; end
  #-----------------------------------------------------------------------------
  # Calculation of shadow size and position
  #-----------------------------------------------------------------------------
  def update
    return if disposed? || !$scene.is_a?(Scene_Map)
    @sprite = Sprite.new(@viewport) if !@sprite
    
    current_char_name = @event.respond_to?(:character_name) ? @event.character_name : nil
    current_bitmap = @rsprite.bitmap
    
    if current_char_name != @last_character_name
      @last_character_name = current_char_name
      @fix_radius = 0
      @fix_x      = 0
      @fix_y      = 0
      
      if current_char_name
        OWShadowSettings::CHARACTER_SHADOW_FIX.each do |key, value|
          if current_char_name.include?(key)
            @fix_radius = value[0]
            @fix_x      = value[1]
            @fix_y      = value[2]
            break
          end
        end
      end
      
      invalidate_shadow_data
      @custom_shadow_bitmap&.dispose
      @custom_shadow_bitmap = nil
      
      if current_char_name && !current_char_name.empty?
        base_name = File.basename(current_char_name, ".*")
        
        paths_to_try = [
          "Graphics/shadows/#{base_name}",
          "Graphics/Shadows/#{base_name}",
          "Graphics/Characters/shadows/#{base_name}",
          "Graphics/Characters/Shadows/#{base_name}"
        ]
        
        paths_to_try.each do |path|
          resolved = pbResolveBitmap(path)
          if resolved
            @custom_shadow_bitmap = Bitmap.new(resolved)
            break
          end
        end
      end
    end
    
    if current_bitmap != @last_bitmap
      @last_bitmap = current_bitmap
      invalidate_shadow_data
    end
    
    is_floating = @event.respond_to?(:is_floating) && @event.is_floating
    float_offset = (is_floating && @event.respond_to?(:float_offset)) ? @event.float_offset : 0
    if @event.jumping?
      ground_y = (@event.real_y - $game_map.display_y + 3) / 4 + 32
      jump_offset = (ground_y - @rsprite.y).abs
    elsif is_floating
      ground_y = @rsprite.y + float_offset
      jump_offset = 0
    else
      ground_y = @rsprite.y
      jump_offset = 0
    end

    s_off_x = (@event.respond_to?(:shadow_offset_x) ? @event.shadow_offset_x.to_i : 0)
    s_off_y = (@event.respond_to?(:shadow_offset_y) ? @event.shadow_offset_y.to_i : 0)
    
    @sprite.x = @rsprite.x + s_off_x + @fix_x
    @sprite.y = ground_y + s_off_y + @fix_y
    
    scale_factor = 1.0
    if @event.jumping?
      scale_factor = 1.0 - (jump_offset * 0.01)
    elsif is_floating
      scale_factor = 1.0 - (float_offset * 0.03)
    end

    scale_factor = 0.4 if scale_factor < 0.4
    scale_factor = 1.2 if scale_factor > 1.2

    @sprite.zoom_x  = @rsprite.zoom_x * scale_factor
    @sprite.zoom_y  = @rsprite.zoom_y * scale_factor
    if @event.shows_shadow?
      @shadow_fade += 0.15 if @shadow_fade < 1.0
      @shadow_fade = 1.0 if @shadow_fade > 1.0
    else
      @shadow_fade -= 0.15 if @shadow_fade > 0.0
      @shadow_fade = 0.0 if @shadow_fade < 0.0
    end

    @sprite.visible = @rsprite.visible && @shadow_fade > 0.0

    is_on_screen = (@sprite.x > -64 && @sprite.x < Graphics.width + 64 && 
                    @sprite.y > -64 && @sprite.y < Graphics.height + 64)
                    
    clipping_enabled = defined?(OWShadowSettings::ENABLE_SHADOW_CLIPPING) ? OWShadowSettings::ENABLE_SHADOW_CLIPPING : true

    # Rendering: Custom vs Procedural
    if @custom_shadow_bitmap
      @sprite.ox = @rsprite.ox
      @sprite.oy = @rsprite.oy
      @sprite.z  = @event.screen_z(@rsprite.src_rect.height) - 1
      base_opacity = @rsprite.opacity
      @sprite.opacity = (base_opacity * (80.0 / 255.0) * @shadow_fade).to_i
      
      if clipping_enabled && @sprite.visible && @sprite.opacity > 0 && is_on_screen
        @sprite.bitmap = apply_shadow_fusion(@custom_shadow_bitmap, @rsprite.src_rect)
        @sprite.src_rect.set(0, 0, @rsprite.src_rect.width, @rsprite.src_rect.height)
      else
        @sprite.bitmap = @custom_shadow_bitmap
        @sprite.src_rect.set(@rsprite.src_rect.x, @rsprite.src_rect.y, @rsprite.src_rect.width, @rsprite.src_rect.height)
      end
    else
      if !@shadow_data && @rsprite.bitmap && !@rsprite.disposed?
        @shadow_data = generate_shadow_data
      end
      return unless @shadow_data
      
      @sprite.ox = (@shadow_data[:bitmap].width / 2) - @shadow_data[:offset]
      @sprite.oy = @shadow_data[:bitmap].height
      @sprite.z  = @event.screen_z(@shadow_data[:bitmap].height) - 1      
      @sprite.opacity = (@rsprite.opacity * @shadow_fade).to_i
      
      if clipping_enabled && @sprite.visible && @sprite.opacity > 0 && is_on_screen
        @sprite.bitmap = apply_shadow_fusion(@shadow_data[:bitmap], nil)
        @sprite.src_rect.set(0, 0, @sprite.bitmap.width, @sprite.bitmap.height)
      else
        @sprite.bitmap = @shadow_data[:bitmap]
        @sprite.src_rect.set(0, 0, @sprite.bitmap.width, @sprite.bitmap.height)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# New Method for setting shadow of any event given the map id and event id
#-------------------------------------------------------------------------------
def pbSetOverworldShadow(name, event_id = nil, map_id = nil)
  return if !$scene.is_a?(Scene_Map)
  return if nil_or_empty?(name)
  if !event_id
    $scene.spritesetGlobal.playersprite.ow_shadow.set_bitmap(name)
  else
    map_id = $game_map.map_id if !map_id
    $scene.spritesets[map_id].character_sprites[(event_id - 1)].ow_shadow.set_bitmap(name)
  end
end

#-------------------------------------------------------------------------------
# Referencing and initializing Shadow Sprite in Sprite_Character
#-------------------------------------------------------------------------------
class Sprite_Character
  attr_accessor :ow_shadow
  #-----------------------------------------------------------------------------
  # Initializing Shadow with Character
  #-----------------------------------------------------------------------------
  alias __ow_shadow__initialize initialize unless private_method_defined?(:__ow_shadow__initialize)
  def initialize(*args)
    __ow_shadow__initialize(*args)
    @ow_shadow = Sprite_OWShadow.new(self, args[1], args[0])
    update
  end
  #-----------------------------------------------------------------------------
  # Disposing Shadow with Character
  #-----------------------------------------------------------------------------
  alias __ow_shadow__dispose dispose unless method_defined?(:__ow_shadow__dispose)
  def dispose(*args)
    __ow_shadow__dispose(*args)
    @ow_shadow.dispose if @ow_shadow
    @ow_shadow = nil
  end
  #-----------------------------------------------------------------------------
  # Updating Shadow with Character
  #-----------------------------------------------------------------------------
  alias __ow_shadow__update update unless method_defined?(:__ow_shadow__update)
  def update(*args)
    __ow_shadow__update(*args)
    return if !@ow_shadow
    @ow_shadow.update
  end
end

#-------------------------------------------------------------------------------
# Adding shadow checking method to Game_Event
#-------------------------------------------------------------------------------
class Game_Character
  attr_reader :jump_count
  attr_reader :jump_distance
  attr_reader :jump_distance_left
  attr_reader :jump_peak
  #-----------------------------------------------------------------------------
  # Initializing Shadow with event
  #-----------------------------------------------------------------------------
  alias __ow_shadow__initialize initialize unless private_method_defined?(:__ow_shadow__initialize)
  def initialize(*args)
    __ow_shadow__initialize(*args)
    @shows_shadow = false
  end
  #-----------------------------------------------------------------------------
  # Updating Shadow with Character
  #-----------------------------------------------------------------------------
  alias __ow_shadow__calculate_bush_depth calculate_bush_depth unless method_defined?(:__ow_shadow__calculate_bush_depth)
  def calculate_bush_depth(*args)
    __ow_shadow__calculate_bush_depth(*args)
    @shows_shadow = shows_shadow?(true)
  end
  #-----------------------------------------------------------------------------
  # Check whether the character should have a shadow
  #-----------------------------------------------------------------------------
  def shows_shadow?(recalc = false)
    return @shows_shadow if !recalc
    return false if nil_or_empty?(self.character_name) || self.transparent
    if OWShadowSettings::CASE_SENSITIVE_BLACKLISTS
      return false if OWShadowSettings::SHADOWLESS_CHARACTER_NAME.any?{ |e| self.character_name[/#{e}/] }
      return false if self.respond_to?(:name) && OWShadowSettings::SHADOWLESS_EVENT_NAME.any? { |e| self.name[/#{e}/]}
    else
      return false if OWShadowSettings::SHADOWLESS_CHARACTER_NAME.any?{ |e| self.character_name[/#{e}/i] }
      return false if self.respond_to?(:name) && OWShadowSettings::SHADOWLESS_EVENT_NAME.any? { |e| self.name[/#{e}/]}
    end
    terrain = $game_map.terrain_tag(self.x, self.y)
    return false if OWShadowSettings::SHADOWLESS_TERRAIN_NAME.any? { |e| terrain == e } if terrain
    return true
  end
  #-----------------------------------------------------------------------------
  # Updating Shadows when transparency is changed
  #-----------------------------------------------------------------------------
  alias __ow_shadow__transparent_set transparent= unless method_defined?(:__ow_shadow__transparent_set)
  def transparent=(*args)
    __ow_shadow__transparent_set(*args)
    @shows_shadow = shows_shadow?(true)
  end
  #-----------------------------------------------------------------------------
end

#-------------------------------------------------------------------------------
# Updating Shadow with Character
#-------------------------------------------------------------------------------
class Game_Event
  alias __ow_shadow__refresh refresh unless method_defined?(:__ow_shadow__refresh)
  def refresh(*args)
    ret = __ow_shadow__refresh(*args)
    @shows_shadow = shows_shadow?(true)
    return ret
  end
end

class Game_Player
  #-----------------------------------------------------------------------------
  # Updating Shadow with Player's Movement
  #-----------------------------------------------------------------------------
  alias __ow_shadow__set_movement_type set_movement_type unless method_defined?(:__ow_shadow__set_movement_type)
  def set_movement_type(*args)
    ret = __ow_shadow__set_movement_type(*args)
    @shows_shadow = shows_shadow?(true)
    return ret
  end
  #-----------------------------------------------------------------------------
end

#-------------------------------------------------------------------------------
# Adding accessors to the Scene_Map class
#-------------------------------------------------------------------------------
class Scene_Map
  attr_accessor :spritesets
end

#-------------------------------------------------------------------------------
# Adding accessors to the Game_Character class
#-------------------------------------------------------------------------------
class Spriteset_Map
  attr_accessor :character_sprites
end

