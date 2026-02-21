#===============================================================================
# Continuous Weather Animations Plugin
# Makes weather animations play continuously during battle
#===============================================================================

module ContinuousWeatherSettings
  ENABLED = true
  # How often to restart weather animations (in frames, 60 = 1 second)
end

class Battle::Scene
  # Add our weather system to the battle scene initialization
  alias cwas_pbInitSprites pbInitSprites
  def pbInitSprites
    cwas_pbInitSprites
    pbCreateWeatherSystem if ContinuousWeatherSettings::ENABLED
  end

  # Add weather disposal to sprite cleanup
  alias cwas_pbDisposeSprites pbDisposeSprites
  def pbDisposeSprites
    pbDisposeWeatherSystem if ContinuousWeatherSettings::ENABLED
    cwas_pbDisposeSprites
  end

  # Hook into end battle to stop weather animation
  alias cwas_pbEndBattle pbEndBattle
  def pbEndBattle(result)
    pbStopWeatherAnimationInstantly if ContinuousWeatherSettings::ENABLED
    cwas_pbEndBattle(result)
  end

  # Add weather updates to frame updates
  alias cwas_pbFrameUpdate pbFrameUpdate
  def pbFrameUpdate(cw = nil)
    cwas_pbFrameUpdate(cw)
    pbUpdateWeatherSystem if ContinuousWeatherSettings::ENABLED
  end

  def pbCreateWeatherSystem
    # Initialize weather system using the default Essentials weather class
    @weatherSystem = RPG::Weather.new(@viewport)
    @weatherSystem.ox_offset = 0
    @weatherSystem.oy_offset = 0
    @currentWeatherType = :None
    @weatherActive = false
    @weatherNeedsInitialization = true  # Flag to force weather animation on first update
    # Sun animation variables
    @sunSprite = nil
    @sunOpacity = 150
    @sunFadeDirection = 1
    @sunFadeSpeed = 2
    # Desolate Land particles
    @desolateLandParticles = []
    @desolateLandParticleTimers = []
  end

  def pbStartWeatherAnimation(battleWeather)
    return if !ContinuousWeatherSettings::ENABLED
    return if battleWeather == :None || battleWeather.nil?
    
    # Initialize weather system if not already done
    if !@weatherSystem
      pbCreateWeatherSystem
    end
    
    # Only skip if already animating this exact weather type
    # Don't skip if this is being called to ensure animation starts
    if battleWeather == @currentWeatherType && @weatherActive
      return
    end
    
    # Stop any existing weather immediately for fast transitions
    pbStopWeatherAnimationInstantly if @weatherActive
    
    # Convert battle weather to GameData::Weather ID
    weatherID = case battleWeather
               when :Rain        then :Rain
               when :Hail        then (Settings::HAIL_WEATHER_TYPE == 1 ? :Snow : :Blizzard)
               when :Sandstorm   then :Sandstorm
               when :Sun         then :Sun
               when :HarshSun    then :Sun
               when :HeavyRain   then :HeavyRain
               when :StrongWinds then :Storm
               when :ShadowSky   then :Fog
               else :None
               end
    
    # Set weather type instantly for fast transitions
    @weatherSystem.type = weatherID
    @weatherSystem.max = 60
    @currentWeatherType = battleWeather
    @weatherActive = true
    
    # Initialize sun animation for sun weather
    if battleWeather == :Sun || battleWeather == :HarshSun
      pbCreateSunAnimation
    end
    
    # Initialize Desolate Land particles
    if battleWeather == :HarshSun
      pbCreateDesolateLandParticles
    end
    
    # Modify the z-index of the weather sprites
    pbUpdateWeatherZIndex
  end

  def pbCreateSunAnimation
    return unless ContinuousWeatherSettings::ENABLED
    
    # Create sun sprite
    begin
      @sunSprite = pbAddSprite("sun", Graphics.width / 2, Graphics.height / 3, "Graphics/Weather/Sun", @viewport)
      @sunSprite.z = 80  # Behind all other sprites except background
      @sunSprite.ox = @sunSprite.bitmap.width / 2
      @sunSprite.oy = @sunSprite.bitmap.height / 2
      @sunSprite.opacity = @sunOpacity
      @sunSprite.visible = true
    rescue => e
      PBDebug.log("Sun animation sprite could not be created: #{e}")
    end
  end

  def pbCreateDesolateLandParticles
    return unless ContinuousWeatherSettings::ENABLED
    
    # Create desolate land particles
    @desolateLandParticles.clear
    @desolateLandParticleTimers.clear
    50.times do
      sprite = Sprite.new(@viewport)
      sprite.z = 85  # Above sun, behind other sprites
      sprite.visible = false
      sprite.opacity = 0
      @desolateLandParticles.push(sprite)
      @desolateLandParticleTimers.push(0)
    end
  end

  def pbStopWeatherAnimation
    return if !ContinuousWeatherSettings::ENABLED
    return if !@weatherActive

    @weatherActive = false
    @currentWeatherType = :None
    
    # Stop weather instantly for fast transitions
    pbStopWeatherAnimationInstantly
  end

  def pbStopWeatherAnimationInstantly
    return if !ContinuousWeatherSettings::ENABLED
    
    # Guard against cases where the weather system was already disposed or not created
    return if !@weatherSystem
    @weatherSystem.type = :None
    @weatherSystem.max = 0
    
    # Remove sun sprite instantly
    if @sunSprite
      @sunSprite.opacity = 0
      @sunSprite.visible = false
      @sunSprite.dispose
      @sprites.delete("sun") if @sprites && @sprites["sun"]
      @sunSprite = nil
    end
    
    # Remove desolate land particles
    @desolateLandParticles.each do |sprite|
      sprite.opacity = 0
      sprite.visible = false
      sprite.bitmap.dispose if sprite.bitmap
      sprite.dispose
    end
    @desolateLandParticles.clear
    @desolateLandParticleTimers.clear
  end

  def pbUpdateWeatherSystem
    return if !ContinuousWeatherSettings::ENABLED
    
    # On first update, ensure weather animation is initialized if there's active battle weather
    if @weatherNeedsInitialization && @battle && @battle.field && @battle.field.weather != :None
      @weatherNeedsInitialization = false
      pbStartWeatherAnimation(@battle.field.weather)
      return  # Skip normal update this frame to avoid double processing
    end
    
    return if !@weatherActive
    
    # Save the current viewport tone before updating the weather system
    old_tone = Tone.new(@viewport.tone.red, @viewport.tone.green,
                       @viewport.tone.blue, @viewport.tone.gray)
    
    # Update the weather system without calling update_screen_tone
    # This prevents the weather from changing the screen tone
    @weatherSystem.instance_variable_set(:@fading, false)
    @weatherSystem.instance_variable_set(:@time_until_flash, 0)
    
    # Update only the weather sprites without screen tone
    if @weatherSystem.instance_variable_get(:@weatherTypes)[@weatherSystem.type] &&
       @weatherSystem.instance_variable_get(:@weatherTypes)[@weatherSystem.type][1].length > 0
      @weatherSystem.send(:ensureSprites)
      RPG::Weather::MAX_SPRITES.times do |i|
        @weatherSystem.send(:update_sprite_position, @weatherSystem.instance_variable_get(:@sprites)[i], i, false)
      end
    end
    
    # Update new weather sprites (if any)
    if @weatherSystem.instance_variable_get(:@fading) &&
       @weatherSystem.instance_variable_get(:@weatherTypes)[@weatherSystem.instance_variable_get(:@target_type)] &&
       @weatherSystem.instance_variable_get(:@weatherTypes)[@weatherSystem.instance_variable_get(:@target_type)][1].length > 0
      @weatherSystem.send(:ensureSprites)
      RPG::Weather::MAX_SPRITES.times do |i|
        @weatherSystem.send(:update_sprite_position, @weatherSystem.instance_variable_get(:@new_sprites)[i], i, true)
      end
    end
    
    # Update weather tiles (if any)
    if @weatherSystem.instance_variable_get(:@tiles_wide) > 0 && @weatherSystem.instance_variable_get(:@tiles_tall) > 0
      @weatherSystem.send(:ensureTiles)
      @weatherSystem.send(:recalculate_tile_positions)
      @weatherSystem.instance_variable_get(:@tiles).each_with_index do |sprite, i|
        @weatherSystem.send(:update_tile_position, sprite, i)
      end
    end
    
    # Update sun animation
    pbUpdateSunAnimation
    
    # Update desolate land particles
    pbUpdateDesolateLandParticles
    
    # Ensure the z-index is correct on each update
    pbUpdateWeatherZIndex
    
    # Restore the old viewport tone to prevent the weather from affecting the UI
    @viewport.tone.set(old_tone.red, old_tone.green, old_tone.blue, old_tone.gray)
  end

  def pbUpdateSunAnimation
    return unless @currentWeatherType == :Sun || @currentWeatherType == :HarshSun
    return unless @sunSprite
    
    # Make sure sprite is visible
    @sunSprite.visible = true
    
    # Faster blinking effect for sun
    if @currentWeatherType == :Sun
      @sunOpacity += @sunFadeSpeed * @sunFadeDirection
      if @sunOpacity > 255
        @sunOpacity = 255
        @sunFadeDirection = -1
      elsif @sunOpacity < 50
        @sunOpacity = 50
        @sunFadeDirection = 1
      end
      @sunSprite.opacity = @sunOpacity
    end
    
    # Harsh sun (Desolate Land) with brighter sun
    if @currentWeatherType == :HarshSun
      # Brighter sun for desolate land
      @sunOpacity += @sunFadeSpeed * @sunFadeDirection
      if @sunOpacity > 255
        @sunOpacity = 255
        @sunFadeDirection = -1
      elsif @sunOpacity < 200
        @sunOpacity = 200
        @sunFadeDirection = 1
      end
      @sunSprite.opacity = @sunOpacity
    end
  end

  def pbUpdateDesolateLandParticles
    return unless @currentWeatherType == :HarshSun
    
    @desolateLandParticles.each_with_index do |sprite, i|
      # Load sandstorm_4 as particle bitmap
      if !sprite.bitmap
        begin
          sprite.bitmap = RPG::Cache.load_bitmap("Graphics/Weather/", "sandstorm_4")
          sprite.ox = sprite.bitmap.width / 2
          sprite.oy = sprite.bitmap.height / 2
        rescue => e
          PBDebug.log("Sandstorm_4 particle could not be loaded: #{e}")
          next
        end
      end
      
      # Get particle timer
      timer = @desolateLandParticleTimers[i]
      
      if timer == 0
        # Initialize particle
        sprite.x = rand(Graphics.width)
        sprite.y = Graphics.height + sprite.bitmap.height / 2
        sprite.opacity = rand(50..150)
        sprite.visible = true
        @desolateLandParticleTimers[i] = 1
      else
        # Move particle up
        sprite.y -= 2
        sprite.opacity -= 1
        
        # Check if particle is off-screen or faded out
        if sprite.y < -sprite.bitmap.height / 2 || sprite.opacity <= 0
          sprite.visible = false
          @desolateLandParticleTimers[i] = 0
        else
          @desolateLandParticleTimers[i] = timer + 1
        end
      end
    end
  end

  def pbUpdateWeatherZIndex
    # Get all weather sprites and set their z-index to be behind UI
    [@weatherSystem.instance_variable_get(:@sprites), @weatherSystem.instance_variable_get(:@new_sprites)].each do |sprite_array|
      next unless sprite_array
      sprite_array.each do |sprite|
        next unless sprite.is_a?(Sprite)
        sprite.z = 90  # Behind data boxes (100) and UI elements (200)
      end
    end
    # Also update the weather tiles z-index
    tiles = @weatherSystem.instance_variable_get(:@tiles)
    if tiles
      tiles.each do |sprite|
        next unless sprite.is_a?(Sprite)
        sprite.z = 90  # Behind UI elements
      end
    end
  end

  def pbDisposeWeatherSystem
    return if !ContinuousWeatherSettings::ENABLED
    
    # Dispose the weather system
    pbStopWeatherAnimationInstantly
    if @sunSprite
      @sunSprite.dispose
      @sunSprite = nil
    end
    @desolateLandParticles.each do |sprite|
      sprite.bitmap.dispose if sprite.bitmap
      sprite.dispose
    end
    @desolateLandParticles.clear
    @desolateLandParticleTimers.clear
    @weatherSystem.dispose if @weatherSystem
    @weatherSystem = nil
  end
end

#===============================================================================
# Battle class modifications
#===============================================================================
class Battle
  # Hook into weather starting to begin continuous animations and remove common animation
  alias cwas_pbStartWeather pbStartWeather
  def pbStartWeather(user, newWeather, fixedDuration = false, showAnim = true)
    return if @field.weather == newWeather
    @field.weather = newWeather
    duration = (fixedDuration) ? 5 : -1
    if duration > 0 && user && user.itemActive?
      duration = Battle::ItemEffects.triggerWeatherExtender(user.item, @field.weather, duration, user, self)
    end
    @field.weatherDuration = duration
    pbHideAbilitySplash(user) if user
    case @field.weather
    when :Sun         then pbDisplay(_INTL("The sunlight is strong."))
    when :Rain        then pbDisplay(_INTL("It is raining."))
    when :Sandstorm   then pbDisplay(_INTL("A sandstorm is raging."))
    when :HarshSun    then pbDisplay(_INTL("The sunlight is extremely harsh."))
    when :HeavyRain   then pbDisplay(_INTL("It is raining heavily."))
    when :StrongWinds then pbDisplay(_INTL("The wind is strong."))
    when :ShadowSky   then pbDisplay(_INTL("The sky is shadowy."))
    when :Hail
      if Settings::HAIL_WEATHER_TYPE == 1
        pbDisplay(_INTL("Snow is falling."))
      elsif Settings::HAIL_WEATHER_TYPE == 2
        pbDisplay(_INTL("A harsh hailstorm bellows!"))
      else
        pbDisplay(_INTL("Hail is falling."))
      end
    end
    allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
    pbEndPrimordialWeather
    # Start continuous weather animation
    @scene.pbStartWeatherAnimation(@field.weather) if @field.weather != :None && ContinuousWeatherSettings::ENABLED
  end

  alias cwas_pbStartBattleCore pbStartBattleCore
  def pbStartBattleCore(battle_loop = true)
    cwas_pbStartBattleCore(battle_loop)
    # Weather animation will be initialized on first frame update via pbUpdateWeatherSystem
  end

  # Override the pbCommonAnimation call for weather to use continuous animation instead
  alias cwas_pbCommonAnimation pbCommonAnimation
  def pbCommonAnimation(animID, *args)
    # Check if this is being called for weather animation at battle start
    # If continuous weather is enabled and we're in battle with active weather,
    # skip the common animation and let continuous weather handle it
    if defined?(@field) && @field && @field.weather != :None && ContinuousWeatherSettings::ENABLED
      # Check if this is a weather animation by seeing if it matches weather data
      weather_data = GameData::BattleWeather.try_get(@field.weather)
      if weather_data && weather_data.animation == animID
        # Skip common animation, continuous weather already handles it
        return
      end
    end
    # For non-weather animations, call normally
    cwas_pbCommonAnimation(animID, *args)
  end

  # Hook into end of battle to stop continuous weather animations
  alias cwas_pbEndOfBattle pbEndOfBattle
  def pbEndOfBattle(*args)
    @scene.pbStopWeatherAnimationInstantly if @scene.respond_to?(:pbStopWeatherAnimationInstantly)
    result = cwas_pbEndOfBattle(*args)
    return result
  end

  # Hook into end of round weather to stop continuous animation when weather ends and remove common animation
  alias cwas_pbEOREndWeather pbEOREndWeather
  def pbEOREndWeather(priority)
    old_weather = @field.weather
    # Remove the common animation call from the original method
    # Count down weather duration
    @field.weatherDuration -= 1 if @field.weatherDuration > 0
    # Weather wears off
    if @field.weatherDuration == 0
      case @field.weather
      when :Sun       then pbDisplay(_INTL("The sunlight faded."))
      when :Rain      then pbDisplay(_INTL("The rain stopped."))
      when :Sandstorm then pbDisplay(_INTL("The sandstorm subsided."))
      when :Hail
        if Settings::HAIL_WEATHER_TYPE == 1
          pbDisplay(_INTL("The snow stopped."))
        else
          pbDisplay(_INTL("The hail stopped."))
        end
      when :ShadowSky then pbDisplay(_INTL("The shadow sky faded."))
      end
      # Stop weather animation before changing the weather
      @scene.pbStopWeatherAnimationInstantly
      @field.weather = :None
      # Check for form changes caused by the weather changing
      allBattlers.each { |battler| battler.pbCheckFormOnWeatherChange }
      # Start up the default weather
      pbStartWeather(nil, @field.defaultWeather) if @field.defaultWeather != :None
      return if @field.weather == :None
    end
    # Weather continues (without common animation)
    case @field.weather
    when :Sun         then pbDisplay(_INTL("The sunlight is strong."))
    when :Rain        then pbDisplay(_INTL("Rain continues to fall."))
    when :Sandstorm   then pbDisplay(_INTL("The sandstorm is raging."))
    when :Hail
      if Settings::HAIL_WEATHER_TYPE == 1
        pbDisplay(_INTL("Snow continues to fall."))
      else
        pbDisplay(_INTL("Hail continues to fall."))
      end
    when :HarshSun    then pbDisplay(_INTL("The sunlight is extremely harsh."))
    when :HeavyRain   then pbDisplay(_INTL("It is raining heavily."))
    when :StrongWinds then pbDisplay(_INTL("The wind is strong."))
    when :ShadowSky   then pbDisplay(_INTL("The shadow sky continues."))
    end
    # Effects due to weather
    priority.each do |battler|
      # Weather-related abilities
      if battler.abilityActive?
        Battle::AbilityEffects.triggerEndOfRoundWeather(battler.ability, battler.effectiveWeather, battler, self)
        battler.pbFaint if battler.fainted?
      end
      # Weather damage
      pbEORWeatherDamage(battler)
    end
  end

  alias cwas_pbEndPrimordialWeather pbEndPrimordialWeather
  def pbEndPrimordialWeather
    old_weather = @field.weather
    cwas_pbEndPrimordialWeather
    if old_weather != :None && @field.weather == :None
      @scene.pbStopWeatherAnimationInstantly
    end
  end
end