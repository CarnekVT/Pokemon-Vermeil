# encoding: utf-8
module CustomWeather
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

  FALLING_DIAG_TYPES = [
    TYPE_GREEN_LEAVES, TYPE_AUTUMN_LEAVES_FALLING, TYPE_SAKURA_PETALS, TYPE_ROSE_PETALS, TYPE_FEATHERS,
    TYPE_GREEN_LEAVES_PRESENT_COLOR, TYPE_AUTUMN_FALLING_PRESENT_COLOR, TYPE_SAKURA_PRESENT_COLOR,
    TYPE_ROSE_PETALS_PRESENT_COLOR, TYPE_FEATHERS_PRESENT_COLOR
  ]

  FALLING_DIAG_MAX = 1

  # Global settings
  $CUSTOM_WEATHER_UPDATE = false
  $CUSTOM_WEATHER_IMAGES = []
  $CUSTOM_WEATHER_X = 0
  $CUSTOM_WEATHER_Y = 0
  $CUSTOM_WEATHER_FADE = 0
  $CUSTOM_WEATHER_ANIMATED = false

  PROPERTIES = {
    TYPE_THUNDERSTORM => { behavior: :storm, battle_weather: :HeavyRain, delta_x: -24, delta_y: 24, opacity: -10 },
    TYPE_BLOOD_RAIN => { behavior: :storm, battle_weather: :Rain, delta_x: -20, delta_y: 20, opacity: -8 },
    TYPE_SAKURA_PETALS => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -1 },
    TYPE_ROSE_PETALS => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -1 },
    TYPE_FEATHERS => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -1 },
    TYPE_AUTUMN_LEAVES_FALLING => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -2 },
    TYPE_GREEN_LEAVES => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -1 },
    TYPE_AUTUMN_LEAVES_BLOWING => { behavior: :spin, battle_weather: :None, delta_x: -12.0, delta_y: 2.0, opacity: -5 },
    TYPE_AUTUMN_LEAVES_WHIRLING => { behavior: :whirl, battle_weather: :None, delta_x: 0, delta_y: 0, opacity: -4 },
    TYPE_SPARKS => { behavior: :rise, battle_weather: :None, delta_x: 0, delta_y: -2.0, opacity: -6 },
    TYPE_USER_DEFINED => { behavior: :custom, battle_weather: :None, delta_x: 1, delta_y: 2, opacity: -5 },
    TYPE_THUNDERSTORM_PRESENT_COLOR => { behavior: :storm, battle_weather: :HeavyRain, delta_x: -24, delta_y: 24, opacity: -10 },
    TYPE_SAKURA_PRESENT_COLOR => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -1 },
    TYPE_ROSE_PETALS_PRESENT_COLOR => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -1 },
    TYPE_FEATHERS_PRESENT_COLOR => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -1 },
    TYPE_AUTUMN_FALLING_PRESENT_COLOR => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -2 },
    TYPE_GREEN_LEAVES_PRESENT_COLOR => { behavior: :storm, battle_weather: :None, delta_x: -1.8, delta_y: 2.4, opacity: -1 },
    TYPE_AUTUMN_BLOWING_PRESENT_COLOR => { behavior: :spin, battle_weather: :None, delta_x: -12.0, delta_y: 2.0, opacity: -5 },
    TYPE_AUTUMN_WHIRLING_PRESENT_COLOR => { behavior: :whirl, battle_weather: :None, delta_x: 0, delta_y: 0, opacity: -4 },
    TYPE_SPARKS_PRESENT_COLOR => { behavior: :rise, battle_weather: :None, delta_x: 0, delta_y: -2.0, opacity: -6 }
  }

  class << self
    def get_behavior(type)
      return PROPERTIES[type][:behavior] if PROPERTIES.key?(type)
      return :rain
    end

    def wrap_tone_logic(default_tone_proc)
      sepia_tone = ->(strength) { Tone.new(-10, -20, -30, strength * 4) }
      neutral_tone = Tone.new(0, 0, 0, 0)
      
      return ->(strength) {
        if $game_switches && $game_switches[CustomWeather::SEPIA_FILTER_SWITCH]
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
        { id: TYPE_THUNDERSTORM, id_number: 9, category: :Rain, battle_weather: :HeavyRain, tone_proc: wrap_tone_logic(tone_storm_sepia), graphics: [["storm_1", "storm_2", "storm_3", "storm_4"], []], particle_delta_x: -24, particle_delta_y: 24, particle_delta_opacity: -10 },
        { id: TYPE_AUTUMN_LEAVES_FALLING, id_number: 10, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_autumn), graphics: [["autumn_leaf"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_AUTUMN_LEAVES_BLOWING, id_number: 11, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_autumn), graphics: [["autumn_leaf"], []], particle_delta_x: -12, particle_delta_y: 1, particle_delta_opacity: -5 },
        { id: TYPE_AUTUMN_LEAVES_WHIRLING, id_number: 12, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_autumn), graphics: [["autumn_leaf"], []], particle_delta_x: 0, particle_delta_y: 0, particle_delta_opacity: -4 },
        { id: TYPE_GREEN_LEAVES, id_number: 13, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_green), graphics: [["green_leaf"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_SAKURA_PETALS, id_number: 14, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_sakura), graphics: [["sakura_petal"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_ROSE_PETALS, id_number: 15, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_rose), graphics: [["rose_petal"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_FEATHERS, id_number: 16, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_feather), graphics: [["feather"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_BLOOD_RAIN, id_number: 17, category: :Rain, battle_weather: :Rain, tone_proc: wrap_tone_logic(tone_blood), graphics: [["storm_1", "storm_2", "storm_3", "storm_4"], []], particle_delta_x: -24, particle_delta_y: 24, particle_delta_opacity: -8 },
        { id: TYPE_SPARKS, id_number: 18, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_sparks), graphics: [["spark"], []], particle_delta_x: 0, particle_delta_y: -2, particle_delta_opacity: -6 },
        { id: TYPE_USER_DEFINED, id_number: 19, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["green_leaf"], []], particle_delta_x: 1, particle_delta_y: 2, particle_delta_opacity: -5 },
        { id: TYPE_SAKURA_PRESENT_COLOR, id_number: 20, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["sakura_petal"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_AUTUMN_FALLING_PRESENT_COLOR, id_number: 21, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["autumn_leaf"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_AUTUMN_BLOWING_PRESENT_COLOR, id_number: 22, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["autumn_leaf"], []], particle_delta_x: -12, particle_delta_y: 1, particle_delta_opacity: -5 },
        { id: TYPE_AUTUMN_WHIRLING_PRESENT_COLOR, id_number: 23, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["autumn_leaf"], []], particle_delta_x: 0, particle_delta_y: 0, particle_delta_opacity: -4 },
        { id: TYPE_GREEN_LEAVES_PRESENT_COLOR, id_number: 24, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["green_leaf"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_ROSE_PETALS_PRESENT_COLOR, id_number: 25, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["rose_petal"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_FEATHERS_PRESENT_COLOR, id_number: 26, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["feather"], []], particle_delta_x: -1.8, particle_delta_y: 2.4, particle_delta_opacity: -2 },
        { id: TYPE_SPARKS_PRESENT_COLOR, id_number: 27, category: :Rain, battle_weather: :None, tone_proc: wrap_tone_logic(tone_none), graphics: [["spark"], []], particle_delta_x: 0, particle_delta_y: -2, particle_delta_opacity: -6 },
        { id: TYPE_THUNDERSTORM_PRESENT_COLOR, id_number: 28, category: :Rain, battle_weather: :HeavyRain, tone_proc: wrap_tone_logic(tone_storm_dark), graphics: [["storm_1", "storm_2", "storm_3", "storm_4"], []], particle_delta_x: -24, particle_delta_y: 24, particle_delta_opacity: -10 }
      ]

      weathers_to_register.each do |weather_data|
        next if GameData::Weather.exists?(weather_data[:id])
        GameData::Weather.register(weather_data)
      end
    end
  end
end

CustomWeather.setup_custom_weathers
