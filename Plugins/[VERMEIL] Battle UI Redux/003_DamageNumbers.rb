#===============================================================================
# Damage Numbers for Battle - Pokemon Vermeil v21
#===============================================================================
# Plugin: Battle UI Redux - Damage Numbers
# Fully Compatible with Battle UI Redux & Cinematic Engine
#===============================================================================

#=============================================================================
# Configuration Module - Easy configuration
#=============================================================================
module VermeilDamageNumbersSettings
  # Duration for damage numbers to stay on screen (in seconds)
  DISPLAY_DURATION = 1.0
  
  # How high numbers rise (pixels)
  RISE_DISTANCE = 25
  
  # Font size
  FONT_SIZE = 26
  
  # Minimum zoom (when damage is 0% of max HP)
  MIN_ZOOM = 1.0
  # Maximum zoom (when damage is 100% of max HP)
  MAX_ZOOM = 1.3
  
  # Critical shake settings
  SHAKE_AMOUNT = 4        # Amplitude in pixels
  SHAKE_OSCILLATIONS = 6  # Number of full oscillations
  
  # Flash interval for critical hits (every N frames)
  CRITICAL_FLASH_INTERVAL = 8
  
  # Vertical bounds - never go below this Y position
  MIN_Y_POSITION = 40
  
  # Use PokemonSystem setting for enable/disable
  SYSTEM_SETTING = :damagenumbers
end

#=============================================================================
# Damage Numbers Sprite - Displays floating damage numbers
#=============================================================================
class Battle::Scene::DamageNumbersSprite
  include VermeilDamageNumbersSettings
  
  # Colors for different damage types
  COLORS = {
    :normal    => { base: Color.new(248, 248, 248), stroke: Color.new(0, 0, 0) },    # White - neutral
    :healing   => { base: Color.new(56, 200, 56), stroke: Color.new(0, 80, 0) },     # Green - healing
    :critical  => { base: Color.new(255, 255, 0), stroke: Color.new(180, 100, 0) },   # Yellow - critical
    :effective => { base: Color.new(255, 120, 48), stroke: Color.new(180, 60, 0) },  # Orange-red - super effective
    :weak      => { base: Color.new(120, 168, 255), stroke: Color.new(40, 80, 180) }  # Blue - not very effective
  }
  
  # Critical flash colors (alternating) - brighter versions
  CRITICAL_FLASH_COLORS = {
    :normal    => { base: Color.new(255, 255, 200), stroke: Color.new(180, 150, 0) },
    :effective => { base: Color.new(255, 200, 180), stroke: Color.new(200, 100, 80) },
    :weak      => { base: Color.new(200, 220, 255), stroke: Color.new(80, 120, 200) }
  }

  def initialize(viewport, x, y, damage, is_healing = false, is_critical = false, effectiveness = 0, max_hp = 1, total_damage = nil)
    @viewport = viewport
    @x = x
    @y = y
    @damage = damage.abs
    @is_healing = is_healing
    @is_critical = is_critical && !is_healing
    @effectiveness = effectiveness
    @max_hp = max_hp
    @start_time = System.uptime
    @duration = DISPLAY_DURATION
    @completed = false
    
    # Calculate initial zoom based on damage percentage
    @initial_zoom = calculate_initial_zoom
    
    # Store current zoom for animation
    @current_zoom = @initial_zoom
    
    # Get depth factor from sprite if available
    @depth_factor = 1.0
    
    # Determine colors based on type (priority: critical > healing > effectiveness > normal)
    determine_colors
    
    # Add prefix for healing/damage
    prefix = ""
    prefix = "+" if @is_healing
    prefix = "-" if !@is_healing
    
    # Create bitmap and draw
    create_bitmap
    draw_damage_number(@bitmap.bitmap, "#{prefix}#{@damage}")
  end
  
  def calculate_initial_zoom
    return MIN_ZOOM if @max_hp <= 0
    
    # Calculate damage ratio (0 to 1)
    ratio = @damage.to_f / @max_hp
    ratio = 0.0 if ratio < 0.0
    ratio = 1.0 if ratio > 1.0
    
    # Interpolate between min and max zoom
    return MIN_ZOOM + ratio * (MAX_ZOOM - MIN_ZOOM)
  end
  
  def determine_colors
    @color_base = COLORS[:normal][:base]
    @color_stroke = COLORS[:normal][:stroke]
    
    if @is_critical
      @color_base = COLORS[:critical][:base]
      @color_stroke = COLORS[:critical][:stroke]
    elsif @is_healing
      @color_base = COLORS[:healing][:base]
      @color_stroke = COLORS[:healing][:stroke]
    elsif @effectiveness > 0
      @color_base = COLORS[:effective][:base]
      @color_stroke = COLORS[:effective][:stroke]
    elsif @effectiveness < 0
      @color_base = COLORS[:weak][:base]
      @color_stroke = COLORS[:weak][:stroke]
    end
  end
  
  def create_bitmap
    # Measure text first
    temp_bmp = Bitmap.new(1, 1)
    pbSetSystemFont(temp_bmp)
    temp_bmp.font.size = FONT_SIZE
    temp_bmp.font.bold = true
    
    text = "#{@damage}"
    tw = temp_bmp.text_size(text).width
    th = temp_bmp.text_size(text).height
    temp_bmp.dispose
    
    # Add extra margin to prevent cutting
    margin = 16
    bmpw = tw + margin * 2 + 20
    bmph = th + margin * 2 + 20
    
    # Create our own viewport if none provided
    if @viewport.nil?
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    end
    @viewport.z = 99999
    
    @bitmap = BitmapSprite.new(bmpw, bmph, @viewport)
    # Keep ox/oy at 0 for normal drawing from top-left
    @bitmap.ox = 0
    @bitmap.oy = 0
    @bitmap.x = @x
    @bitmap.y = @y
    @bitmap.z = 100000  # Higher than viewport
    @bitmap.opacity = 255  # Start fully visible
    @bitmap.visible = true
    
    @margin = margin
    @text_width = tw
    @text_height = th
  end

  def draw_damage_number(bitmap, text, base_color = nil, stroke_color = nil)
    base_color ||= @color_base
    stroke_color ||= @color_stroke
    
    # Use the game's default font
    pbSetSystemFont(bitmap)
    bitmap.font.size = FONT_SIZE
    bitmap.font.bold = true
    
    # Get actual text dimensions
    text_w = bitmap.text_size(text).width
    text_h = bitmap.text_size(text).height
    
    # Calculate center position
    cx = (bitmap.width - text_w) / 2
    cy = (bitmap.height - text_h) / 2
    
    # Draw thicker outline (stroke around text)
    bitmap.font.color = stroke_color
    
    # Draw stroke in all 8 directions
    bitmap.draw_text(cx - 2, cy - 2, text_w + 4, text_h + 4, text, 0)
    bitmap.draw_text(cx + 2, cy + 2, text_w + 4, text_h + 4, text, 0)
    bitmap.draw_text(cx - 2, cy + 2, text_w + 4, text_h + 4, text, 0)
    bitmap.draw_text(cx + 2, cy - 2, text_w + 4, text_h + 4, text, 0)
    bitmap.draw_text(cx, cy - 2, text_w + 4, text_h + 4, text, 0)
    bitmap.draw_text(cx, cy + 2, text_w + 4, text_h + 4, text, 0)
    bitmap.draw_text(cx - 2, cy, text_w + 4, text_h + 4, text, 0)
    bitmap.draw_text(cx + 2, cy, text_w + 4, text_h + 4, text, 0)
    
    # Inner stroke
    bitmap.draw_text(cx - 1, cy - 1, text_w + 2, text_h + 2, text, 0)
    bitmap.draw_text(cx + 1, cy + 1, text_w + 2, text_h + 2, text, 0)
    bitmap.draw_text(cx - 1, cy + 1, text_w + 2, text_h + 2, text, 0)
    bitmap.draw_text(cx + 1, cy - 1, text_w + 2, text_h + 2, text, 0)
    
    # Draw main text centered
    bitmap.font.color = base_color
    bitmap.draw_text(cx, cy, text_w, text_h, text, 0)
  end

  def update
    return if @completed
    return if !@bitmap || @bitmap.disposed?
    return if !@bitmap.bitmap || @bitmap.bitmap.disposed?
    
    elapsed = System.uptime - @start_time
    
    # Calculate progress (0 to 1)
    progress = elapsed / @duration
    
    if progress >= 1.0
      @completed = true
      @bitmap.opacity = 0
      return
    end
    
    # Ease-out animation for Y position (straight up, no curve)
    # Linear movement instead of ease-out
    progress_linear = progress
    
    # Move upward linearly
    offset_y = (RISE_DISTANCE * progress_linear).floor
    @bitmap.y = @y - offset_y
    
    # Ensure we don't go below minimum Y
    @bitmap.y = MIN_Y_POSITION if @bitmap.y < MIN_Y_POSITION
    
    # Zoom descent: start at initial_zoom and decrease to 1.0
    zoom_decrease = (@initial_zoom - 1.0) * progress
    @current_zoom = @initial_zoom - zoom_decrease
    @bitmap.zoom_x = @current_zoom * @depth_factor
    @bitmap.zoom_y = @current_zoom * @depth_factor
    
    # Critical shake effect
    if @is_critical && !@is_healing
      # Calculate shake offset using sin wave
      shake_offset = SHAKE_AMOUNT * Math.sin(progress * 2 * Math::PI * SHAKE_OSCILLATIONS)
      @bitmap.x = @x + shake_offset.floor
      
      # Critical flash: alternate colors
      frame_number = (elapsed * 60).to_i  # Assuming 60 FPS
      if (frame_number / CRITICAL_FLASH_INTERVAL).even?
        # Use flash colors for critical hits
        flash_colors = get_flash_colors
        redraw_with_colors(flash_colors[:base], flash_colors[:stroke])
      else
        # Use normal critical colors
        redraw_with_colors(@color_base, @color_stroke)
      end
    else
      @bitmap.x = @x
    end
    
    # Fade out near the end (last 30%)
    if progress > 0.7
      fade_progress = (progress - 0.7) / 0.3
      @bitmap.opacity = (255 * (1 - fade_progress)).floor
    end
  end
  
  def get_flash_colors
    if @effectiveness > 0
      return CRITICAL_FLASH_COLORS[:effective]
    elsif @effectiveness < 0
      return CRITICAL_FLASH_COLORS[:weak]
    else
      return CRITICAL_FLASH_COLORS[:normal]
    end
  end
  
  def redraw_with_colors(base_color, stroke_color)
    @bitmap.bitmap.clear
    prefix = ""
    prefix = "+" if @is_healing
    prefix = "-" if !@is_healing
    
    text = "#{prefix}#{@damage}"
    
    pbSetSystemFont(@bitmap.bitmap)
    @bitmap.bitmap.font.size = FONT_SIZE
    @bitmap.bitmap.font.bold = true
    
    # Get actual text dimensions
    text_w = @bitmap.bitmap.text_size(text).width
    text_h = @bitmap.bitmap.text_size(text).height
    
    # Calculate center position
    cx = (@bitmap.width - text_w) / 2
    cy = (@bitmap.height - text_h) / 2
    
    # Draw stroke
    @bitmap.bitmap.font.color = stroke_color
    @bitmap.bitmap.draw_text(cx - 2, cy - 2, text_w + 4, text_h + 4, text, 0)
    @bitmap.bitmap.draw_text(cx + 2, cy + 2, text_w + 4, text_h + 4, text, 0)
    @bitmap.bitmap.draw_text(cx - 2, cy + 2, text_w + 4, text_h + 4, text, 0)
    @bitmap.bitmap.draw_text(cx + 2, cy - 2, text_w + 4, text_h + 4, text, 0)
    @bitmap.bitmap.draw_text(cx, cy - 2, text_w + 4, text_h + 4, text, 0)
    @bitmap.bitmap.draw_text(cx, cy + 2, text_w + 4, text_h + 4, text, 0)
    @bitmap.bitmap.draw_text(cx - 2, cy, text_w + 4, text_h + 4, text, 0)
    @bitmap.bitmap.draw_text(cx + 2, cy, text_w + 4, text_h + 4, text, 0)
    @bitmap.bitmap.draw_text(cx - 1, cy - 1, text_w + 2, text_h + 2, text, 0)
    @bitmap.bitmap.draw_text(cx + 1, cy + 1, text_w + 2, text_h + 2, text, 0)
    @bitmap.bitmap.draw_text(cx - 1, cy + 1, text_w + 2, text_h + 2, text, 0)
    @bitmap.bitmap.draw_text(cx + 1, cy - 1, text_w + 2, text_h + 2, text, 0)
    
    # Draw main text
    @bitmap.bitmap.font.color = base_color
    @bitmap.bitmap.draw_text(cx, cy, text_w, text_h, text, 0)
  end

  def completed?
    return @completed
  end

  def dispose
    @bitmap.dispose if @bitmap && !@bitmap.disposed?
  end

  def visible?
    return @bitmap && !@bitmap.disposed? && @bitmap.opacity > 0
  end
  
  def set_depth_factor(factor)
    @depth_factor = factor
  end
end

#=============================================================================
# Damage Numbers Animation - Integrated with Cinematic Engine
#=============================================================================
class Battle::Scene::Animation::DamageNumbers < Battle::Scene::Animation
  def initialize(sprites, viewport, targets)
    @targets = targets
    @tempSprites = []
    @disposed = false
    super(sprites, viewport)
    # Ensure we have a valid viewport
    @viewport = viewport if viewport
  end

  def createProcesses
    @targets.each_with_index do |target, index|
      battler = target[0]
      damage = target[1]
      is_healing = target[2]
      is_critical = target[3]
      effectiveness = target[4] || 0
      max_hp = target[5] || battler.totalhp
      total_damage = target[6]  # Raw calculated damage
      
      # Try different sprite name formats
      sprite_name = "pokemon#{battler.index}"
      sprite = @sprites[sprite_name]
      
      # Try alternative format if not found
      if !sprite
        sprite_name = "pokemon_#{battler.index}"
        sprite = @sprites[sprite_name]
      end
      
      # Try with "0" suffix for player, "2" for foe
      if !sprite
        sprite_name = "pokemon0"
        sprite = @sprites[sprite_name]
      end
      
      next if !sprite
      
      # Use sprite position as base
      x = sprite.x
      y = sprite.y
      
      # Offset to appear above the battler's head (use sprite height)
      sprite_h = sprite.src_rect ? sprite.src_rect.height : 96
      sprite_h = sprite_h * sprite.zoom_y if sprite.respond_to?(:zoom_y) && sprite.zoom_y
      y = y - sprite_h / 2 - 20
      
      # Center horizontally on the battler (adjust based on side)
      if battler.index == 0 || battler.index == 2
        x = x - 15   # Player side
      else
        x = x - 55   # Foe side
      end
      
      # Ensure we don't go below minimum Y (hardcoded value)
      y = 40 if y < 40
      
      # Add slight offset for multiple targets
      if @targets.length > 1
        offset = ((index * 20) - ((@targets.length - 1) * 10))
        x += offset
      end
      
      # Create damage numbers sprite with a valid viewport
      dmg_vp = @viewport
      if dmg_vp.nil?
        dmg_vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
        dmg_vp.z = 99999
      end
      
      dmg_numbers = Battle::Scene::DamageNumbersSprite.new(dmg_vp, x, y, damage, is_healing, is_critical, effectiveness, max_hp, total_damage)
      
      # Set depth factor from battler sprite
      if sprite.respond_to?(:zoom_x) && sprite.zoom_x
        dmg_numbers.set_depth_factor(sprite.zoom_x)
      end
      
      @tempSprites.push(dmg_numbers)
    end
  end

  def update
    return if @disposed
    super
    return if !@tempSprites
    @tempSprites.each do |sprite|
      sprite.update if sprite
    end
  end

  def dispose
    return if @disposed
    @disposed = true
    return if !@tempSprites
    @tempSprites.each do |sprite|
      sprite.dispose if sprite
    end
    @tempSprites = nil
  end

  def animDone?
    return true if @disposed
    return true if !@tempSprites || @tempSprites.empty?
    return @tempSprites.all? { |s| !s || s.completed? }
  end
end

#=============================================================================
# Damage Numbers Controller - Fully Compatible with Cinematic Engine
#=============================================================================
module VermeilDamageNumbers
  # Damage display modes
  DAMAGE_MODE_REAL = 0  # Show actual HP lost/gained
  DAMAGE_MODE_RAW = 1   # Show raw calculated damage
  DAMAGE_MODE_OFF = 2   # Disabled
  
  # Check if damage numbers are enabled
  def damage_numbers_enabled?
    # Check PokemonSystem setting
    # 0 = Real (actual HP lost), 1 = Raw, 2 = Off
    if $PokemonSystem
      return false if $PokemonSystem.damagenumbers == 2  # Off
      return true   # Real (0) or Raw (1)
    end
    return true  # Default to enabled
  end
  
  # Get current damage mode
  def damage_numbers_mode
    return DAMAGE_MODE_OFF if !$PokemonSystem
    # 0 = Real, 1 = Raw, 2 = Off
    return $PokemonSystem.damagenumbers
  end
  
  # Calculate effectiveness for display
  def get_effectiveness(target)
    return 0 if !target
    # Try to get effectiveness from damageState (set during damage calculation)
    if target.respond_to?(:damageState) && target.damageState && target.damageState.respond_to?(:typeMod)
      type_mod = target.damageState.typeMod
      return 1 if type_mod > 1  # Super effective
      return -1 if type_mod < 1  # Not very effective
      return 0  # Neutral
    end
    return 0
  end
  
  # Hook into HP changes - shows damage/healing numbers
  def pbHPChanged(battler, oldHP, showAnim = false)
    result = super
    
    mode = damage_numbers_mode
    return result if mode == DAMAGE_MODE_OFF
    return result if oldHP == battler.hp
    
    is_healing = battler.hp > oldHP
    damage = (battler.hp - oldHP).abs
    return if damage == 0
    
    # Get effectiveness if this is not healing
    effectiveness = is_healing ? 0 : get_effectiveness(battler)
    
    # Check if this was a critical hit from damageState
    is_critical = false
    if battler.respond_to?(:damageState) && battler.damageState
      is_critical = battler.damageState.critical rescue false
    end
    
    # Get raw damage from damageState.calcDamage
    raw_damage = nil
    if battler.respond_to?(:damageState) && battler.damageState
      raw_damage = battler.damageState.calcDamage rescue nil
    end
    
    # For raw damage mode, use the raw calculated damage
    display_damage = (mode == DAMAGE_MODE_RAW && raw_damage && raw_damage > 0) ? raw_damage : damage
    
    damage_data = [[battler, display_damage, is_healing, is_critical, effectiveness, battler.totalhp, raw_damage]]
    damage_anim = Battle::Scene::Animation::DamageNumbers.new(@sprites, @viewport, damage_data)
    @animations.push(damage_anim)
    
    return result
  end

  # Hook into hit and HP loss animation - shows damage numbers from attacks
  def pbHitAndHPLossAnimation(targets)
    result = super
    
    mode = damage_numbers_mode
    return result if mode == DAMAGE_MODE_OFF
    return result if !targets
    
    damage_targets = []
    targets.each do |t|
      battler = t[0]
      old_hp = t[1]
      damage = (old_hp - battler.hp).abs
      next if damage == 0
      
      # Determine if this was a critical hit - use damageState
      is_critical = false
      if battler.respond_to?(:damageState) && battler.damageState
        is_critical = battler.damageState.critical rescue false
      end
      
      # Get raw damage from damageState.calcDamage (calculated damage before clamping)
      raw_damage = nil
      if battler.respond_to?(:damageState) && battler.damageState
        raw_damage = battler.damageState.calcDamage rescue nil
      end
      
      # Fallback: try stored calculation
      if raw_damage.nil? || raw_damage == 0
        if @lastDamageCalculated && @lastDamageCalculated[battler.index]
          raw_damage = @lastDamageCalculated[battler.index][:damage]
        end
      end
      
      # Get effectiveness from damageState if available
      effectiveness = 0
      if battler.respond_to?(:damageState) && battler.damageState
        type_mod = battler.damageState.typeMod rescue nil
        if type_mod
          # type_mod: >1 super effective, <1 not very effective, ==1 neutral
          effectiveness = 1 if type_mod > 1
          effectiveness = -1 if type_mod < 1
        end
      end
      
      # Use raw damage if available and in raw mode, otherwise use actual damage
      display_damage = (mode == DAMAGE_MODE_RAW && raw_damage && raw_damage > 0) ? raw_damage : damage
      
      damage_targets.push([battler, display_damage, false, is_critical, effectiveness, battler.totalhp, raw_damage])
    end
    
    unless damage_targets.empty?
      damage_anim = Battle::Scene::Animation::DamageNumbers.new(@sprites, @viewport, damage_targets)
      @animations.push(damage_anim)
    end
    
    return result
  end
  
  # Hook into damage calculation to track critical hits
  def pbDamageAnimation(battler, effectiveness = 0)
    # Store critical info before damage calculation
    @lastDamageCalculated ||= {}
    @lastDamageCalculated[battler.index] = { 
      critical: false
    }
    
    if battler.respond_to?(:critical?) && battler.critical?
      @lastDamageCalculated[battler.index][:critical] = true
    end
    
    super
  end
end

# Prepend to Battle::Scene for Cinematic Engine compatibility
Battle::Scene.prepend(VermeilDamageNumbers)

#=============================================================================
# Force cleanup when battle ends - ensures damage numbers are removed
#=============================================================================
module VermeilDamageNumbersCleanup
  def pbEndBattleriefly(result)
    # Force dispose all damage number animations before battle ends
    if @animations
      @animations.each do |anim|
        anim.dispose if anim.is_a?(Battle::Scene::Animation::DamageNumbers)
      end
    end
    super(result)
  end
  
  def pbEndBattle(*args)
    # Force dispose all damage number animations before battle ends
    if @animations
      @animations.each do |anim|
        anim.dispose if anim.is_a?(Battle::Scene::Animation::DamageNumbers)
      end
    end
    super(*args)
  end
end

Battle::Scene.prepend(VermeilDamageNumbersCleanup)

#=============================================================================
# Settings Module - PokemonSystem Integration
#=============================================================================
module VermeilDamageNumbersSettings
  # System setting index (will be added to PokemonSystem)
  SYSTEM_INDEX = 77  # Adjust if needed
end
