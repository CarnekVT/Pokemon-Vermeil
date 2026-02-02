#===============================================================================
# Continuous Terrain Animations Plugin
# Makes terrain animations play continuously during battle using sprite-based approach
#===============================================================================

module ContinuousTerrainSettings
  ENABLED = true
  
  # Terrain settings - customize these to match your terrain types
  TERRAIN_SETTINGS = {
    :Electric => {
      :sprites => 50,
      :speed => 2,
      :fade_speed => 2,
      :direction => :down_right,
      :animation_frames => 4,
      :delay => 10,
      :color => Color.new(255, 255, 0, 180),
      :image => "terrain_electric"
    },
    :Grassy => {
      :sprites => 60,
      :speed => 1.5,
      :fade_speed => 1,
      :direction => :down_left,
      :animation_frames => 3,
      :delay => 15,
      :color => Color.new(0, 255, 0, 120),
      :image => "terrain_grass"
    },
    :Misty => {
      :sprites => 80,
      :speed => 0.8,
      :fade_speed => 0.5,
      :direction => :up_right,
      :animation_frames => 2,
      :delay => 20,
      :color => Color.new(180, 180, 255, 100),
      :image => "terrain_mist"
    },
    :Psychic => {
      :sprites => 40,
      :speed => 2.5,
      :fade_speed => 3,
      :direction => :diagonal,
      :animation_frames => 5,
      :delay => 8,
      :color => Color.new(255, 0, 255, 150),
      :image => "terrain_psychic"
    }
  }
end

class Battle::Scene
  # Add our terrain system to the battle scene initialization
  alias ctas_pbInitSprites pbInitSprites
  def pbInitSprites
    ctas_pbInitSprites
    pbCreateTerrainSprites if ContinuousTerrainSettings::ENABLED
  end

  # Add terrain disposal to sprite cleanup
  alias ctas_pbDisposeSprites pbDisposeSprites
  def pbDisposeSprites
    pbDisposeTerrainSprites if ContinuousTerrainSettings::ENABLED
    ctas_pbDisposeSprites
  end

  # Hook into end battle to stop terrain animation
  alias ctas_pbEndBattle pbEndBattle
  def pbEndBattle(result)
    pbStopTerrainAnimation if ContinuousTerrainSettings::ENABLED
    ctas_pbEndBattle(result)
  end

  # Add terrain updates to frame updates
  alias ctas_pbFrameUpdate pbFrameUpdate
  def pbFrameUpdate(cw = nil)
    ctas_pbFrameUpdate(cw)
    pbUpdateTerrainSprites if ContinuousTerrainSettings::ENABLED
  end

  def pbCreateTerrainSprites
    # Initialize terrain sprite system
    @terrainSprites = []
    @terrainSpriteInfo = []
    @terrainSpriteTimers = []
    @currentTerrainType = :None
    @terrainActive = false
    @terrainBitmaps = {}
    
    # Create sprite pool (reusable sprites)
    200.times do
      sprite = Sprite.new(@viewport)
      sprite.visible = false
      sprite.opacity = 0
      sprite.z = 50  # Behind battle sprites
      @terrainSprites.push(sprite)
      @terrainSpriteInfo.push({
        :x => 0,
        :y => 0,
        :vx => 0,
        :vy => 0,
        :opacity => 0,
        :max_opacity => 0,
        :fade_speed => 0,
        :delay => 0
      })
      @terrainSpriteTimers.push(0)
    end
  end

  def pbStartTerrainAnimation(battleTerrain)
    return if !ContinuousTerrainSettings::ENABLED
    return if battleTerrain == :None || battleTerrain.nil?
    return if battleTerrain == @currentTerrainType
    
    # Stop any existing terrain first
    pbStopTerrainAnimation if @terrainActive
    
    # Check if terrain settings exist
    terrain_settings = ContinuousTerrainSettings::TERRAIN_SETTINGS[battleTerrain]
    return if !terrain_settings
    
    @currentTerrainType = battleTerrain
    @terrainActive = true
    @terrainSettings = terrain_settings
    
    # Load terrain bitmap for particles
    if terrain_settings[:image]
      begin
        @terrainBitmaps[battleTerrain] = RPG::Cache.picture(terrain_settings[:image])
      rescue
        @terrainBitmaps[battleTerrain] = nil
      end
    end
    
    # Load terrain background bitmap
    terrain_background = case battleTerrain
                       when :Electric then "terrain_electric_bg"
                       when :Grassy then "terrain_grass_bg"
                       when :Misty then "terrain_mist_bg"
                       when :Psychic then "terrain_psychic_bg"
                       else nil
                       end
    if terrain_background
      begin
        @terrainBitmaps["#{battleTerrain}_bg"] = RPG::Cache.picture(terrain_background)
      rescue => e
        @terrainBitmaps["#{battleTerrain}_bg"] = nil
      end
    end
    
    # Initialize active sprites including background
    activate_terrain_sprites
  end

  def pbStopTerrainAnimation
    return if !ContinuousTerrainSettings::ENABLED
    return if !@terrainActive

    @terrainActive = false
    @currentTerrainType = :None
    
    # Fade out and dispose terrain background sprite
    if @sprites["terrain_bg"]
      while @sprites["terrain_bg"].opacity > 0
        @sprites["terrain_bg"].opacity -= 8
        pbUpdate
      end
      @sprites["terrain_bg"].visible = false
      @sprites["terrain_bg"].dispose
      @sprites.delete("terrain_bg")
    end
    
    # Hide all terrain sprites and reset their properties
    @terrainSprites.each do |sprite|
      sprite.visible = false
      sprite.opacity = 0
      sprite.bitmap = nil
      sprite.color = Color.new(255, 255, 255, 255)  # Reset color tint
    end
    
    # Clear all terrain bitmaps to force reload when terrain changes
    @terrainBitmaps.each_value do |bitmap|
      bitmap.dispose if bitmap && !bitmap.disposed?
    end
    @terrainBitmaps.clear
  end

  def activate_terrain_sprites
    return if !@terrainActive || !@terrainSettings
    return if !@terrainSprites
    
    # Calculate number of active sprites
    active_sprites = @terrainSettings[:sprites]
    active_sprites = [active_sprites, @terrainSprites.size].min
    
    # Load particle bitmap
    particle_bitmap = @terrainBitmaps[@currentTerrainType]
    
    # Load background using pbAddSprite (existing method)
    terrain_background = case @currentTerrainType
                       when :Electric then "Graphics/Pictures/terrain_electric_bg"
                       when :Grassy then "Graphics/Pictures/terrain_grass_bg"
                       when :Misty then "Graphics/Pictures/terrain_mist_bg"
                       when :Psychic then "Graphics/Pictures/terrain_psychic_bg"
                       else nil
                       end
    if terrain_background
      # Check if we already have a terrain background sprite
      if !@sprites["terrain_bg"]
        bg = pbAddSprite("terrain_bg", 0, 0, terrain_background, @viewport)
        bg.z = 2  # Behind battle sprites
        bg.opacity = 0
        bg.visible = true
        bg.ox = bg.bitmap.width / 2
        bg.oy = bg.bitmap.height / 2
        bg.x = Graphics.width / 2
        bg.y = Graphics.height / 2
        puts "Created new terrain background sprite"
      else
        @sprites["terrain_bg"].visible = true
        @sprites["terrain_bg"].opacity = 0
        puts "Reusing existing terrain background sprite"
      end
    end
    
    # Initialize particle sprites (starting from index 0)
    (0...active_sprites).each do |i|
      sprite = @terrainSprites[i]
      next unless sprite
      
      sprite.visible = true
      sprite.opacity = 0
      sprite.bitmap = particle_bitmap if particle_bitmap
      
      # Set random position within battle area
      x = rand(Graphics.width)
      y = rand(Graphics.height)
      
      # Determine direction and speed
      direction = @terrainSettings[:direction]
      speed = @terrainSettings[:speed]
      case direction
      when :down_right
        vx = speed
        vy = speed
      when :down_left
        vx = -speed
        vy = speed
      when :up_right
        vx = speed
        vy = -speed
      when :up_left
        vx = -speed
        vy = -speed
      when :diagonal
        vx = (rand > 0.5 ? 1 : -1) * speed
        vy = (rand > 0.5 ? 1 : -1) * speed
      else
        vx = 0
        vy = speed
      end
      
      @terrainSpriteInfo[i] = {
        :x => x,
        :y => y,
        :vx => vx,
        :vy => vy,
        :opacity => 0,
        :max_opacity => @terrainSettings[:color].alpha,
        :fade_speed => @terrainSettings[:fade_speed],
        :delay => rand(30)  # Random delay before sprite starts moving
      }
      
      @terrainSpriteTimers[i] = 0
    end
  end

  def pbUpdateTerrainSprites
    return if !@terrainActive || !@terrainSettings
    
    # Update terrain background sprite
    if @sprites["terrain_bg"]
      bg_sprite = @sprites["terrain_bg"]
      if bg_sprite.opacity < 128
        bg_sprite.opacity += 8
        bg_sprite.opacity = [bg_sprite.opacity, 128].min
      end
    end
    
    # Get current terrain bitmaps
    particle_bitmap = @terrainBitmaps[@currentTerrainType]
    
    # Update particle sprites
    @terrainSprites.each_with_index do |sprite, i|
      # Check if sprite should be active based on terrain settings
      is_active = (i < @terrainSettings[:sprites])
      
      if is_active && !sprite.visible
        sprite.visible = true
      elsif !is_active && sprite.visible
        sprite.visible = false
        sprite.opacity = 0
        sprite.bitmap = nil
        next
      end
      
      info = @terrainSpriteInfo[i]
      timer = @terrainSpriteTimers[i]
      
      # Handle delay before sprite starts
      if timer < info[:delay]
        @terrainSpriteTimers[i] += 1
        next
      end
      
      # Update opacity (fading in)
      if info[:opacity] < info[:max_opacity]
        info[:opacity] += info[:fade_speed]
        info[:opacity] = [info[:opacity], info[:max_opacity]].min
      end
      
      # Move sprite
      info[:x] += info[:vx]
      info[:y] += info[:vy]
      
      # Check if sprite is out of bounds
      if info[:x] < -50 || info[:x] > Graphics.width + 50 ||
         info[:y] < -50 || info[:y] > Graphics.height + 50
        # Reset sprite position
        info[:x] = rand(Graphics.width)
        info[:y] = rand(Graphics.height)
        info[:opacity] = 0
      end
      
      # Update sprite properties
      sprite.x = info[:x]
      sprite.y = info[:y]
      sprite.opacity = info[:opacity]
      
      if particle_bitmap
        # If we have a bitmap, use it with color tint
        sprite.bitmap = particle_bitmap
        sprite.color = @terrainSettings[:color]
      else
        # If no bitmap, create a simple colored square
        if !sprite.bitmap || sprite.bitmap.width != 8
          sprite.bitmap = Bitmap.new(8, 8)
          sprite.bitmap.fill_rect(0, 0, 8, 8, @terrainSettings[:color])
        end
      end
      
      # Simple animation by changing scale slightly
      scale = 0.8 + (Math.sin(timer * 0.1) * 0.2)
      sprite.zoom_x = scale
      sprite.zoom_y = scale
      
      @terrainSpriteTimers[i] += 1
    end
  end

  def pbDisposeTerrainSprites
    return if !ContinuousTerrainSettings::ENABLED
    
    # Immediately stop terrain and dispose all sprites
    @terrainActive = false
    @currentTerrainType = :None
    
    # Hide all terrain sprites
    @terrainSprites.each do |sprite|
      sprite.visible = false
      sprite.opacity = 0
      sprite.bitmap = nil
      sprite.color = Color.new(255, 255, 255, 255)
    end
    
    # Force dispose terrain background
    if @sprites["terrain_bg"]
      @sprites["terrain_bg"].visible = false
      @sprites["terrain_bg"].opacity = 0
      @sprites["terrain_bg"].dispose
      @sprites.delete("terrain_bg")
    end
    
    # Dispose all terrain sprites
    @terrainSprites.each do |sprite|
      sprite.dispose
    end
    @terrainSprites.clear
    @terrainSpriteInfo.clear
    @terrainSpriteTimers.clear
    
    # Dispose terrain bitmaps
    @terrainBitmaps.each_value do |bitmap|
      bitmap.dispose if bitmap && !bitmap.disposed?
    end
    @terrainBitmaps.clear
  end
end

#===============================================================================
# Battle class modifications
#===============================================================================
class Battle
  # Hook into terrain starting to begin continuous animations and remove common animation
  alias ctas_pbStartTerrain pbStartTerrain
  def pbStartTerrain(user, newTerrain, fixedDuration = true)
    # Start continuous terrain animation immediately
    @scene.pbStartTerrainAnimation(newTerrain) if newTerrain != :None && ContinuousTerrainSettings::ENABLED
    # Call original method but remove common animation call
    return if @field.terrain == newTerrain
    @field.terrain = newTerrain
    duration = (fixedDuration) ? 5 : -1
    if duration > 0 && user && user.itemActive?
      duration = Battle::ItemEffects.triggerTerrainExtender(user.item, newTerrain, duration, user, self)
    end
    @field.terrainDuration = duration
    pbHideAbilitySplash(user) if user
    case @field.terrain
    when :Electric
      pbDisplay(_INTL("An electric current runs across the battlefield!"))
    when :Grassy
      pbDisplay(_INTL("Grass grew to cover the battlefield!"))
    when :Misty
      pbDisplay(_INTL("Mist swirled about the battlefield!"))
    when :Psychic
      pbDisplay(_INTL("The battlefield got weird!"))
    end
    # Check for abilities/items that trigger upon the terrain changing
    allBattlers.each { |b| b.pbAbilityOnTerrainChange }
    allBattlers.each { |b| b.pbItemTerrainStatBoostCheck }
  end

  alias ctas_pbStartBattleCore pbStartBattleCore
  def pbStartBattleCore(battle_loop = true)
    ctas_pbStartBattleCore(battle_loop)
    @scene.pbStartTerrainAnimation(@field.terrain) if @field.terrain != :None && ContinuousTerrainSettings::ENABLED
  end

  # Hook into end of battle to stop continuous terrain animations
  alias ctas_pbEndOfBattle pbEndOfBattle
  def pbEndOfBattle(*args)
    @scene.pbStopTerrainAnimation if @scene.respond_to?(:pbStopTerrainAnimation)
    result = ctas_pbEndOfBattle(*args)
    return result
  end

  # Hook into end of round terrain to stop continuous animation when terrain ends and remove common animation
  alias ctas_pbEOREndTerrain pbEOREndTerrain
  def pbEOREndTerrain
    old_terrain = @field.terrain
    # Remove the common animation call from the original method
    # Count down terrain duration
    @field.terrainDuration -= 1 if @field.terrainDuration > 0
    # Terrain wears off
    if @field.terrain != :None && @field.terrainDuration == 0
      case @field.terrain
      when :Electric
        pbDisplay(_INTL("The electric current disappeared from the battlefield!"))
      when :Grassy
        pbDisplay(_INTL("The grass disappeared from the battlefield!"))
      when :Misty
        pbDisplay(_INTL("The mist disappeared from the battlefield!"))
      when :Psychic
        pbDisplay(_INTL("The weirdness disappeared from the battlefield!"))
      end
      # Stop terrain animation before changing the terrain
      @scene.pbStopTerrainAnimation
      @field.terrain = :None
      allBattlers.each { |battler| battler.pbAbilityOnTerrainChange }
      # Start up the default terrain
      if @field.defaultTerrain != :None
        pbStartTerrain(nil, @field.defaultTerrain, false)
        allBattlers.each { |battler| battler.pbAbilityOnTerrainChange }
        allBattlers.each { |battler| battler.pbItemTerrainStatBoostCheck }
      end
      return if @field.terrain == :None
    end
    # Terrain continues (without common animation)
    case @field.terrain
    when :Electric then pbDisplay(_INTL("An electric current is running across the battlefield."))
    when :Grassy   then pbDisplay(_INTL("Grass is covering the battlefield."))
    when :Misty    then pbDisplay(_INTL("Mist is swirling about the battlefield."))
    when :Psychic  then pbDisplay(_INTL("The battlefield is weird."))
    end
  end
end
