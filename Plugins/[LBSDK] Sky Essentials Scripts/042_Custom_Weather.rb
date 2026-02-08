#===============================================================================
# Custom Weather System - Fluid Motion v13 (Global Sepia + None Weather Support)
# Adapted for Pokémon Essentials v21.1
#===============================================================================
module CustomWeather
  # --- CONFIGURACIÓN DE INTERRUPTOR ---
  # Si este switch está ON, TODOS los climas (incluso :None) se verán Sepia.
  SEPIA_FILTER_SWITCH = 61 

  # Intensidad del filtro cuando no hay clima (0-255). 
  # 160 es un filtro visible pero no totalmente opaco.
  SEPIA_BASE_INTENSITY = 160 

  # --- Constantes de Clima ---
  TYPE_RAIN = :Rain
  TYPE_STORM = :Storm
  TYPE_SNOW = :Snow
  TYPE_HAIL = :Hail
  TYPE_THUNDERSTORM = :Thunderstorm
  TYPE_AUTUMN_LEAVES_FALLING = :AutumnLeavesFalling
  TYPE_AUTUMN_LEAVES_BLOWING = :AutumnLeavesBlowing
  TYPE_AUTUMN_LEAVES_WHIRLING = :AutumnLeavesWhirling
  TYPE_GREEN_LEAVES = :GreenLeaves
  TYPE_SAKURA_PETALS = :SakuraPetals
  TYPE_ROSE_PETALS = :RosePetals
  TYPE_FEATHERS = :Feathers
  TYPE_BLOOD_RAIN = :BloodRain
  TYPE_SPARKS = :Sparks
  TYPE_USER_DEFINED = :UserDefined

  # --- Variantes "PresentColor" ---
  TYPE_THUNDERSTORM_PRESENT_COLOR = :ThunderstormPresentColor
  TYPE_SAKURA_PRESENT_COLOR = :SakuraPetalsPresentColor
  TYPE_AUTUMN_FALLING_PRESENT_COLOR = :AutumnLeavesFallingPresentColor
  TYPE_AUTUMN_BLOWING_PRESENT_COLOR = :AutumnLeavesBlowingPresentColor
  TYPE_AUTUMN_WHIRLING_PRESENT_COLOR = :AutumnLeavesWhirlingPresentColor
  TYPE_GREEN_LEAVES_PRESENT_COLOR = :GreenLeavesPresentColor
  TYPE_ROSE_PETALS_PRESENT_COLOR = :RosePetalsPresentColor
  TYPE_FEATHERS_PRESENT_COLOR = :FeathersPresentColor
  TYPE_SPARKS_PRESENT_COLOR = :SparksPresentColor

  # Global settings
  $CUSTOM_WEATHER_UPDATE = false
  $CUSTOM_WEATHER_IMAGES = []
  $CUSTOM_WEATHER_X = 0
  $CUSTOM_WEATHER_Y = 0
  $CUSTOM_WEATHER_FADE = 0
  $CUSTOM_WEATHER_ANIMATED = false

  #-----------------------------------------------------------------------------
  # FÍSICAS (BEHAVIOR)
  #-----------------------------------------------------------------------------
  PROPERTIES = {
    # --- Estándar ---
    TYPE_THUNDERSTORM => { behavior: :storm, battle_weather: :HeavyRain, delta_x: -24, delta_y: 24, opacity: -10 },
    TYPE_BLOOD_RAIN => { behavior: :storm, battle_weather: :Rain, delta_x: -20, delta_y: 20, opacity: -8 },
    TYPE_SAKURA_PETALS => { behavior: :flutter, battle_weather: :None, delta_x: -1.5, delta_y: 1.0, opacity: -1 },
    TYPE_ROSE_PETALS => { behavior: :flutter, battle_weather: :None, delta_x: -1.5, delta_y: 1.2, opacity: -1 },
    TYPE_FEATHERS => { behavior: :flutter, battle_weather: :None, delta_x: -0.5, delta_y: 0.8, opacity: -1 },
    TYPE_AUTUMN_LEAVES_FALLING => { behavior: :flutter, battle_weather: :None, delta_x: -2.0, delta_y: 1.5, opacity: -2 },
    TYPE_GREEN_LEAVES => { behavior: :flutter, battle_weather: :None, delta_x: -1.5, delta_y: 1.0, opacity: -1 },
    TYPE_AUTUMN_LEAVES_BLOWING => { behavior: :spin, battle_weather: :None, delta_x: -12.0, delta_y: 2.0, opacity: -5 },
    TYPE_AUTUMN_LEAVES_WHIRLING => { behavior: :whirl, battle_weather: :None, delta_x: 0, delta_y: 0, opacity: -4 },
    TYPE_SPARKS => { behavior: :rise, battle_weather: :None, delta_x: 0, delta_y: -2.0, opacity: -6 },
    TYPE_USER_DEFINED => { behavior: :custom, battle_weather: :None, delta_x: 1, delta_y: 2, opacity: -5 },

    # --- Variantes PresentColor ---
    TYPE_THUNDERSTORM_PRESENT_COLOR => { behavior: :storm, battle_weather: :HeavyRain, delta_x: -24, delta_y: 24, opacity: -10 },
    TYPE_SAKURA_PRESENT_COLOR => { behavior: :flutter, battle_weather: :None, delta_x: -1.5, delta_y: 1.0, opacity: -1 },
    TYPE_ROSE_PETALS_PRESENT_COLOR => { behavior: :flutter, battle_weather: :None, delta_x: -1.5, delta_y: 1.2, opacity: -1 },
    TYPE_FEATHERS_PRESENT_COLOR => { behavior: :flutter, battle_weather: :None, delta_x: -0.5, delta_y: 0.8, opacity: -1 },
    TYPE_AUTUMN_FALLING_PRESENT_COLOR => { behavior: :flutter, battle_weather: :None, delta_x: -2.0, delta_y: 1.5, opacity: -2 },
    TYPE_GREEN_LEAVES_PRESENT_COLOR => { behavior: :flutter, battle_weather: :None, delta_x: -1.5, delta_y: 1.0, opacity: -1 },
    TYPE_AUTUMN_BLOWING_PRESENT_COLOR => { behavior: :spin, battle_weather: :None, delta_x: -12.0, delta_y: 2.0, opacity: -5 },
    TYPE_AUTUMN_WHIRLING_PRESENT_COLOR => { behavior: :whirl, battle_weather: :None, delta_x: 0, delta_y: 0, opacity: -4 },
    TYPE_SPARKS_PRESENT_COLOR => { behavior: :rise, battle_weather: :None, delta_x: 0, delta_y: -2.0, opacity: -6 }
  }

  class << self
    def get_behavior(type)
      return PROPERTIES[type][:behavior] if PROPERTIES.key?(type)
      return :rain
    end

    # --- WRAPPER GLOBAL DE TONOS ---
    # Evita crashes y maneja el switch para los climas registrados
    def wrap_tone_logic(default_tone_proc)
      sepia_tone = ->(strength) { Tone.new(-10, -20, -30, strength * 4) }
      neutral_tone = Tone.new(0, 0, 0, 0)
      
      return ->(strength) {
        if $game_switches && $game_switches[SEPIA_FILTER_SWITCH]
          sepia_tone.call(strength)
        else
          val = default_tone_proc ? default_tone_proc.call(strength) : nil
          val || neutral_tone
        end
      }
    end

    def setup_custom_weathers
      tone_storm_sepia = ->(strength) { Tone.new(-10, -20, -30, strength * 4) }
      tone_storm_dark  = ->(strength) { Tone.new(-60, -60, -60, 10) }
      tone_autumn      = ->(strength) { Tone.new(strength / 2, strength / 4, 0, strength / 2) }
      tone_green       = ->(strength) { Tone.new(0, strength / 2, 0, strength / 2) }
      tone_sakura      = ->(strength) { Tone.new(strength / 4, 0, strength / 2, strength / 2) }
      tone_rose        = ->(strength) { Tone.new(strength * 3 / 4, 0, 0, strength / 2) }
      tone_feather     = ->(strength) { Tone.new(strength / 4, strength / 4, strength / 4, strength / 2) }
      tone_blood       = ->(strength) { Tone.new(strength, 0, 0, strength * 3 / 4) }
      tone_sparks      = ->(strength) { Tone.new(strength * 3 / 4, strength / 2, 0, strength / 4) }
      tone_none        = nil 

      weathers_to_register = [
        # --- CLIMAS ORIGINALES ---
        { id: TYPE_THUNDERSTORM, id_number: 9, category: :Rain,
          battle_weather: :HeavyRain,
          tone_proc: wrap_tone_logic(tone_storm_sepia),
          graphics: [["storm_1", "storm_2", "storm_3", "storm_4"], []],
          particle_delta_x: -24, particle_delta_y: 24, particle_delta_opacity: -10 },
          
        { id: TYPE_AUTUMN_LEAVES_FALLING, id_number: 10, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_autumn),
          graphics: [["autumn_leaf"], []],
          particle_delta_x: -2, particle_delta_y: 1.5, particle_delta_opacity: -2 },
          
        { id: TYPE_AUTUMN_LEAVES_BLOWING, id_number: 11, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_autumn),
          graphics: [["autumn_leaf"], []],
          particle_delta_x: -12, particle_delta_y: 1, particle_delta_opacity: -5 },
          
        { id: TYPE_AUTUMN_LEAVES_WHIRLING, id_number: 12, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_autumn),
          graphics: [["autumn_leaf"], []],
          particle_delta_x: 0, particle_delta_y: 0, particle_delta_opacity: -4 },
          
        { id: TYPE_GREEN_LEAVES, id_number: 13, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_green),
          graphics: [["green_leaf"], []],
          particle_delta_x: -1.5, particle_delta_y: 1.2, particle_delta_opacity: -2 },
          
        { id: TYPE_SAKURA_PETALS, id_number: 14, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_sakura),
          graphics: [["sakura_petal"], []],
          particle_delta_x: -1.5, particle_delta_y: 1.2, particle_delta_opacity: -2 },
          
        { id: TYPE_ROSE_PETALS, id_number: 15, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_rose),
          graphics: [["rose_petal"], []],
          particle_delta_x: -1.5, particle_delta_y: 1.2, particle_delta_opacity: -2 },
          
        { id: TYPE_FEATHERS, id_number: 16, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_feather),
          graphics: [["feather"], []],
          particle_delta_x: 1, particle_delta_y: 0.8, particle_delta_opacity: -2 },
          
        { id: TYPE_BLOOD_RAIN, id_number: 17, category: :Rain,
          battle_weather: :Rain,
          tone_proc: wrap_tone_logic(tone_blood),
          graphics: [["storm_1", "storm_2", "storm_3", "storm_4"], []],
          particle_delta_x: -24, particle_delta_y: 24, particle_delta_opacity: -8 },
          
        { id: TYPE_SPARKS, id_number: 18, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_sparks),
          graphics: [["spark"], []],
          particle_delta_x: 0, particle_delta_y: -2, particle_delta_opacity: -6 },
          
        { id: TYPE_USER_DEFINED, id_number: 19, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["green_leaf"], []],
          particle_delta_x: 1, particle_delta_y: 2, particle_delta_opacity: -5 },

        # --- VARIANTES PRESENT COLOR ---
        { id: TYPE_SAKURA_PRESENT_COLOR, id_number: 20, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["sakura_petal"], []],
          particle_delta_x: -1.5, particle_delta_y: 1.2, particle_delta_opacity: -2 },

        { id: TYPE_AUTUMN_FALLING_PRESENT_COLOR, id_number: 21, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["autumn_leaf"], []],
          particle_delta_x: -2, particle_delta_y: 1.5, particle_delta_opacity: -2 },

        { id: TYPE_AUTUMN_BLOWING_PRESENT_COLOR, id_number: 22, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["autumn_leaf"], []],
          particle_delta_x: -12, particle_delta_y: 1, particle_delta_opacity: -5 },

        { id: TYPE_AUTUMN_WHIRLING_PRESENT_COLOR, id_number: 23, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["autumn_leaf"], []],
          particle_delta_x: 0, particle_delta_y: 0, particle_delta_opacity: -4 },

        { id: TYPE_GREEN_LEAVES_PRESENT_COLOR, id_number: 24, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["green_leaf"], []],
          particle_delta_x: -1.5, particle_delta_y: 1.2, particle_delta_opacity: -2 },

        { id: TYPE_ROSE_PETALS_PRESENT_COLOR, id_number: 25, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["rose_petal"], []],
          particle_delta_x: -1.5, particle_delta_y: 1.2, particle_delta_opacity: -2 },

        { id: TYPE_FEATHERS_PRESENT_COLOR, id_number: 26, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["feather"], []],
          particle_delta_x: 1, particle_delta_y: 0.8, particle_delta_opacity: -2 },

        { id: TYPE_SPARKS_PRESENT_COLOR, id_number: 27, category: :Rain,
          battle_weather: :None,
          tone_proc: wrap_tone_logic(tone_none),
          graphics: [["spark"], []],
          particle_delta_x: 0, particle_delta_y: -2, particle_delta_opacity: -6 },

        # --- THUNDERSTORM PRESENT COLOR ---
        { id: TYPE_THUNDERSTORM_PRESENT_COLOR, id_number: 28, category: :Rain,
          battle_weather: :HeavyRain,
          tone_proc: wrap_tone_logic(tone_storm_dark),
          graphics: [["storm_1", "storm_2", "storm_3", "storm_4"], []],
          particle_delta_x: -24, particle_delta_y: 24, particle_delta_opacity: -10 }
      ]

      weathers_to_register.each do |weather_data|
        next if GameData::Weather.exists?(weather_data[:id])
        GameData::Weather.register(weather_data)
      end
    end
  end
end

#===============================================================================
# Override weather update methods
#===============================================================================
class RPG::Weather
  alias_method :custom_weather_original_update_sprite_position, :update_sprite_position unless method_defined?(:custom_weather_original_update_sprite_position)
  alias_method :custom_weather_original_set_sprite_bitmap, :set_sprite_bitmap unless method_defined?(:custom_weather_original_set_sprite_bitmap)
  alias_method :custom_weather_original_prepare_bitmaps, :prepare_bitmaps unless method_defined?(:custom_weather_original_prepare_bitmaps)
  alias_method :custom_weather_original_update, :update unless method_defined?(:custom_weather_original_update)

  #-----------------------------------------------------------------------------
  # GLOBAL UPDATE OVERRIDE (Forcing Filter on :None)
  #-----------------------------------------------------------------------------
  def update
    # Ejecuta la lógica normal (movimiento de partículas, etc.)
    custom_weather_original_update
    
    # Si el switch global está ENCENDIDO, forzamos el tono de pantalla
    if $game_switches && $game_switches[CustomWeather::SEPIA_FILTER_SWITCH]
      # Si hay clima activo (@max > 0), usamos su fuerza.
      # Si el clima es :None (@max es 0), usamos un valor base (40) para que el filtro se vea.
      current_strength = (@max && @max > 0) ? @max : 40 
      
      # Tono Sepia (-10, -20, -30, intensidad)
      gray_val = current_strength * 4
      gray_val = 255 if gray_val > 255
      
      # Forzamos el tono en el viewport (esto sobrescribe cualquier otro color)
      @viewport.tone.set(-10, -20, -30, gray_val)
    end
  end

  #-----------------------------------------------------------------------------
  # FIX: Prevent NaN errors
  #-----------------------------------------------------------------------------
  def ensure_safe_offsets
    if @ox_offset.nil? || (@ox_offset.is_a?(Float) && @ox_offset.nan?)
      @ox_offset = 0
    end
    if @oy_offset.nil? || (@oy_offset.is_a?(Float) && @oy_offset.nan?)
      @oy_offset = 0
    end
  end

  def prepare_bitmaps(type)
    custom_weather_original_prepare_bitmaps(type)
    ensure_safe_offsets
  end

  def set_sprite_bitmap(sprite, index, weather_type)
    if @weatherTypes[weather_type] && @weatherTypes[weather_type][0].category == :Rain && @weatherTypes[weather_type][1].length == 1
      weatherBitmaps = @weatherTypes[weather_type][1]
      sprite.bitmap = weatherBitmaps[0]
      if CustomWeather::PROPERTIES.key?(weather_type)
        sprite.angle = rand(360) 
      end
    else
      custom_weather_original_set_sprite_bitmap(sprite, index, weather_type)
    end
  end

  def update_sprite_position(sprite, index, is_new_sprite = false)
    weather_type = (is_new_sprite) ? @target_type : @type

    if !@weatherTypes[weather_type] && GameData::Weather.exists?(weather_type)
      prepare_bitmaps(weather_type)
    end

    if CustomWeather::PROPERTIES.key?(weather_type)
        behavior = CustomWeather::get_behavior(weather_type)
        
        # --- INITIALIZATION & SAFETY CHECK ---
        if is_new_sprite || sprite.x.nil? || sprite.y.nil?
          ensure_safe_offsets 
          reset_sprite_position(sprite, index, is_new_sprite)
          return 
        end
        # -------------------------------------

        case behavior
        when :storm
          update_storm_particle(sprite, index, is_new_sprite, weather_type)
        when :flutter
          update_flutter_particle(sprite, index, is_new_sprite, weather_type)
        when :spin
          update_spinning_particle(sprite, index, is_new_sprite, weather_type)
        when :whirl
          update_spinning_particle(sprite, index, is_new_sprite, weather_type)
        when :rise
          update_rising_particle(sprite, index, is_new_sprite, weather_type)
        when :custom
           update_custom_generic(sprite, index, is_new_sprite, weather_type)
        else
          custom_weather_original_update_sprite_position(sprite, index, is_new_sprite)
        end
    else
      custom_weather_original_update_sprite_position(sprite, index, is_new_sprite)
    end
  end

  private

  def get_weather_data(weather_type)
     return @weatherTypes[weather_type][0] if @weatherTypes[weather_type]
     return nil
  end

  def update_flutter_particle(sprite, index, is_new_sprite, weather_type)
    return if sprite.x.nil? 
    data = get_weather_data(weather_type)
    return unless data
    t = (Graphics.frame_count + index * 10) / 45.0 
    sprite.x += data.particle_delta_x
    sprite.y += data.particle_delta_y
    sprite.opacity += data.particle_delta_opacity * 0.1 
    sprite.x += Math.sin(t) * 1.5 
    sprite.angle = Math.sin(t / 2.0) * 20 
    check_custom_offscreen(sprite, index, is_new_sprite)
  end

  def update_spinning_particle(sprite, index, is_new_sprite, weather_type)
    return if sprite.x.nil?
    data = get_weather_data(weather_type)
    return unless data
    t = Graphics.frame_count
    sprite.x += data.particle_delta_x
    sprite.y += data.particle_delta_y + Math.sin(t / 5.0) * 2 
    sprite.angle += 5
    check_custom_offscreen(sprite, index, is_new_sprite)
  end

  def update_storm_particle(sprite, index, is_new_sprite, weather_type)
    return if sprite.x.nil?
    data = get_weather_data(weather_type)
    return unless data
    sprite.x += data.particle_delta_x
    sprite.y += data.particle_delta_y
    sprite.opacity = 200 
    is_thunder = weather_type.to_s.include?("Thunderstorm")
    if is_thunder && rand(500) == 0
       @viewport.flash(Color.new(255, 255, 255, 200), 5)
       pbSEPlay("061-Thunderclap01") if File.exist?("Audio/SE/061-Thunderclap01")
    end
    check_custom_offscreen(sprite, index, is_new_sprite)
  end

  def update_rising_particle(sprite, index, is_new_sprite, weather_type)
    return if sprite.x.nil?
    data = get_weather_data(weather_type)
    return unless data
    t = Graphics.frame_count / 20.0
    sprite.x += Math.sin(t + index) 
    sprite.y += data.particle_delta_y 
    sprite.opacity -= 2
    sprite.tone = Tone.new(rand(50), rand(50), 0) if rand(10) == 0
    if sprite.y < -50 || sprite.opacity <= 0
       reset_sprite_position(sprite, index, is_new_sprite)
       sprite.y = 500
    end
  end

  def update_custom_generic(sprite, index, is_new_sprite, weather_type)
     if $CUSTOM_WEATHER_UPDATE
       update_user_defined_bitmaps
       $CUSTOM_WEATHER_UPDATE = false
     end
     return if sprite.x.nil?
     sprite.x += $CUSTOM_WEATHER_X
     sprite.y += $CUSTOM_WEATHER_Y
     sprite.opacity -= $CUSTOM_WEATHER_FADE
     check_custom_offscreen(sprite, index, is_new_sprite)
  end

  def update_user_defined_bitmaps
    return if $CUSTOM_WEATHER_IMAGES.empty?
    @weatherTypes[:UserDefined][1].each { |bitmap| bitmap.dispose }
    @weatherTypes[:UserDefined][1].clear
    $CUSTOM_WEATHER_IMAGES.each do |image_name|
      path = "Graphics/Weather/#{image_name}"
      if File.exist?(path + ".png") || File.exist?(path + ".gif")
         @weatherTypes[:UserDefined][1] << RPG::Cache.load_bitmap("Graphics/Weather/", "#{image_name}")
      end
    end
  end

  def check_custom_offscreen(sprite, index, is_new_sprite)
    ensure_safe_offsets 
    x = sprite.x - @ox - @ox_offset
    y = sprite.y - @oy - @oy_offset
    if sprite.opacity < 10 || x < -100 || x > Graphics.width + 100 || y < -100 || y > Graphics.height + 100
      reset_sprite_position(sprite, index, is_new_sprite)
    end
  end
end

CustomWeather.setup_custom_weathers

#===============================================================================
# BATTLE WEATHER FIREWALL
# Bloquea activamente la lluvia en combate si el clima base del entorno no es rain.
# Funciona incluso con Deluxe Battle Kit.
#===============================================================================
class Battle
  alias_method :custom_weather_pbStartWeather, :pbStartWeather unless method_defined?(:custom_weather_pbStartWeather)
  
  def pbStartWeather(user, newWeather, fixedDuration = false, showAnim = true)
    # Allow all weather changes - don't block moves/abilities from setting weather
    # The overworld custom weathers are purely visual and shouldn't prevent battle weather
    custom_weather_pbStartWeather(user, newWeather, fixedDuration, showAnim)
  end

  # Set initial battle weather based on overworld custom weather
  alias_method :custom_weather_original_pbStartBattleCore, :pbStartBattleCore unless method_defined?(:custom_weather_original_pbStartBattleCore)
  def pbStartBattleCore
    # Check if overworld has a decorative custom weather BEFORE running original code
    overworld_weather = $game_screen ? $game_screen.weather_type : :None
    has_decorative_weather = false
    
    if CustomWeather::PROPERTIES.key?(overworld_weather)
      target = nil
      if GameData::Weather.exists?(overworld_weather)
        target = GameData::Weather.get(overworld_weather).battle_weather if GameData::Weather.get(overworld_weather).respond_to?(:battle_weather)
      end
      target = CustomWeather::PROPERTIES[overworld_weather][:battle_weather] if CustomWeather::PROPERTIES[overworld_weather].key?(:battle_weather)
      target ||= :None
      
      # Mark that we have a decorative weather (no battle weather)
      has_decorative_weather = (target == :None)
    end
    
    # Run original initialization
    custom_weather_original_pbStartBattleCore
    
    # Force weather to None if decorative custom weather is active (override defaultWeather copy)
    if has_decorative_weather
      @field.defaultWeather = :None
      @field.weather = :None
      @field.weatherDuration = 0
    end
  end
end

# Intercept the Battle class's defaultWeather setter to prevent decorative weather
class Battle
  alias_method :custom_weather_original_defaultWeather=, :defaultWeather= unless method_defined?(:custom_weather_original_defaultWeather=)
  
  def defaultWeather=(value)
    # Check if we're trying to set a weather during initialization
    overworld_weather = $game_screen ? $game_screen.weather_type : :None
    
    # If overworld has decorative custom weather, force None instead
    if CustomWeather::PROPERTIES.key?(overworld_weather)
      target = CustomWeather::PROPERTIES[overworld_weather][:battle_weather] if CustomWeather::PROPERTIES[overworld_weather].key?(:battle_weather)
      target ||= :None
      
      if target == :None
        # Force to None instead
        self.custom_weather_original_defaultWeather= :None
        return
      end
    end
    
    # Otherwise use normal assignment
    self.custom_weather_original_defaultWeather= value
  end
end

def pbSetCustomWeather(type, max = 40, duration = 20)
  return unless $game_map && $game_map.weather
  if type == CustomWeather::TYPE_GREEN_LEAVES
    max = [(max * 0.9).round, 6].max
  end
  weather_type = GameData::Weather.get(type).id
  $game_map.weather.fade_in(weather_type, max, duration)
end

def pbResetWeather(duration = 20)
  return unless $game_map && $game_map.weather
  $game_map.weather.fade_in(:None, 0, duration)
end
