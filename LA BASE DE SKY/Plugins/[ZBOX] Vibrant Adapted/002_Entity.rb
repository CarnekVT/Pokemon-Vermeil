# encoding: utf-8
#===============================================================================
# [ZBOX] Vibrant Adapted — Entity
# Game_PokemonFollower: CERO overrides de following/rendering.
# El motor maneja: follow_leader, screen_x/y/z, update_pattern, sprites.
# Solo guardamos datos para el sistema vibrante (conga, interacción).
#===============================================================================

class Game_PokemonFollower < Game_Follower
  attr_accessor :vibrant_state
  attr_accessor :current_leader
  attr_accessor :vibrant_name
  attr_accessor :va_species

  def initialize(event_data)
    super(event_data)
    @vibrant_name   = event_data.name
    @vibrant_state  = :following
    @current_leader = $game_player
    @va_species     = nil
    @step_anime     = true
  end

  def pattern_update_speed
    return super unless @step_anime
    if moving?
      # Usar velocidad de carrera si el jugador corre, si no, velocidad de caminata/surf
      if $game_player&.move_speed && $game_player.move_speed >= 4
        VibrantAdapted::Settings::RUN_ANIM_SPEED
      else
        VibrantAdapted::Settings::WALK_ANIM_SPEED
      end
    else
      VibrantAdapted::Settings::IDLE_ANIM_SPEED
    end
  end

  #===========================================================================
  # UPDATE — solo conga. Todo lo demás es del motor.
  #===========================================================================
  alias va_orig_update update unless method_defined?(:va_orig_update)
  def update
    va_orig_update
    update_conga
  end

  private

  def update_conga
    state = VibrantAdapted::Manager.save_data
    if state.conga_timer > 0
      if @vibrant_name == VibrantAdapted::FOLLOWER_NAME && state.conga_timer > 0
        state.conga_timer -= Graphics.delta
        if state.conga_timer <= 0
          state.conga_timer = 0.0
          $game_system.bgm_unpause
        end
      end
      if state.conga_timer > 0
        time = System.uptime * 5.0
        beat = Math.sin(time)
        self.y_offset = (beat > 0.7) ? -12 : 0
        if beat > 0.4
          @direction = 4
        elsif beat < -0.4
          @direction = 6
        else
          @direction = @current_leader ? @current_leader.direction : 2
        end
      else
        self.y_offset = 0
      end
    else
      self.y_offset = 0
    end
  end
end

#===============================================================================
# FollowerFactory
#===============================================================================
class Game_FollowerFactory
  alias va_create_follower_object create_follower_object unless method_defined?(:va_create_follower_object)
  def create_follower_object(event_data)
    if event_data.name && event_data.name == VibrantAdapted::FOLLOWER_NAME
      return Game_PokemonFollower.new(event_data)
    end
    return va_create_follower_object(event_data)
  end
end

#===============================================================================
# FollowerSprites — status tone pulse
#===============================================================================
class FollowerSprites
  alias va_update update unless method_defined?(:va_update)
  def update
    va_update
    apply_status_tone_pulse if VibrantAdapted::Settings::APPLY_STATUS_TONES
  end

  private

  def apply_status_tone_pulse
    pkmn = $player.first_able_pokemon
    return unless pkmn
    return if pkmn.egg?

    target_tone = case pkmn.status
                  when :BURN      then VibrantAdapted::Settings::TONE_BURN
                  when :POISON    then VibrantAdapted::Settings::TONE_POISON
                  when :PARALYSIS then VibrantAdapted::Settings::TONE_PARALYSIS
                  when :FROZEN    then VibrantAdapted::Settings::TONE_FROZEN
                  when :SLEEP     then VibrantAdapted::Settings::TONE_SLEEP
                  else return
                  end

    @status_pulse_timer ||= 0.0
    @status_pulse_timer += Graphics.delta / 40.0
    pulse = Math.sin(@status_pulse_timer * 2.0) * 0.5 + 0.5

    @sprites.each do |sprite|
      next unless sprite.is_a?(Sprite_Character)
      next unless sprite.character.is_a?(Game_PokemonFollower)
      sprite.tone = Tone.new(
        (target_tone.red * pulse).to_i,
        (target_tone.green * pulse).to_i,
        (target_tone.blue * pulse).to_i,
        (target_tone.gray * pulse).to_i
      )
    end
  end
end

#===============================================================================
# FollowerData — interact via EventHandlers
#===============================================================================
class FollowerData
  alias va_interact interact unless method_defined?(:va_interact)
  def interact(event)
    if self.name && self.name == VibrantAdapted::FOLLOWER_NAME
      return unless VibrantAdapted::Settings.allow_interact?
      pkmn = $player.first_able_pokemon
      if pkmn
        random_val = rand(6)
        EventHandlers.trigger(:following_pkmn_talk, pkmn, random_val)
      end
      return
    end
    va_interact(event)
  end
end
