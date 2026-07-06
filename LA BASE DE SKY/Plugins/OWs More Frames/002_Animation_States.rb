#===============================================================================
# OWs More Frames — Animation States
# Complemento que a?ade estados de animaci?n diferenciados:
#   - Idle: sprite quieto cuando el personaje no se mueve
#   - Run:  sprite de carrera cuando el jugador corre
#   - Surf: sprite de nado para Pokémon de agua (cuando aplique)
# Los sufijos para cada estado se buscan autom?ticamente:
#   {base}_idle, {base}_run, {base}_surf
#===============================================================================
module OWsMoreFrames
  module AnimationStates
    # Retardo en segundos antes de entrar en estado idle
    IDLE_DELAY = 2.0

    IDLE_SUFFIX = "_idle"
    RUN_SUFFIX  = "_run"
    SURF_SUFFIX = "_surf"

    def self.charset_exists?(name)
      return false if name.nil? || name.empty?
      pbResolveBitmap("Graphics/Characters/#{name}") != nil
    end

    def self.strip_state(name)
      name.sub(/_(idle|run|surf)\z/, "")
    end

    def self.water_type?(pkmn)
      return false unless pkmn
      pkmn.types.any? { |t| t == :WATER }
    end
  end
end

#===============================================================================
# Player — Idle cuando está quieto
#===============================================================================
class Game_Player
  alias _ows_as_orig_update_stop update_stop unless method_defined?(:_ows_as_orig_update_stop)
  def update_stop
    _ows_as_orig_update_stop
    check_idle
  end

  alias _ows_as_orig_update_move update_move unless method_defined?(:_ows_as_orig_update_move)
  def update_move
    revert_idle
    _ows_as_orig_update_move
  end

  private

  def check_idle
    return if @move_route_forcing
    return if $PokemonGlobal&.surfing || $PokemonGlobal&.diving || $PokemonGlobal&.bicycle
    if moving? || jumping?
      @_ows_idle_timer = 0
      return
    end
    @_ows_idle_timer ||= 0
    @_ows_idle_timer += @delta_t || Graphics.delta
    return if @_ows_idle_timer < OWsMoreFrames::AnimationStates::IDLE_DELAY
    return if @_ows_using_idle
    # Buscar sufijo _idle directamente sobre el charset actual
    idle_charset = @character_name + OWsMoreFrames::AnimationStates::IDLE_SUFFIX
    if OWsMoreFrames::AnimationStates.charset_exists?(idle_charset)
      @character_name = idle_charset
      @_ows_using_idle = true
    end
  end

  def revert_idle
    return unless @_ows_using_idle
    @character_name = OWsMoreFrames::AnimationStates.strip_state(@character_name)
    @_ows_using_idle = false
    @_ows_idle_timer = 0
  end
end

#===============================================================================
# Followers — Estados walk/run/idle/surf
#===============================================================================
if defined?(Game_PokemonFollower)
  # --- Vibrant Companions ---
  class Game_PokemonFollower
    alias _ows_as_orig_update update unless method_defined?(:_ows_as_orig_update)
    def update
      _ows_as_orig_update
      update_state_sprite
    end

    private

    IDLE_DEBOUNCE = 0.3

    def update_state_sprite
      return unless @vibrant_name
      idx = @vibrant_name.split("_")[1].to_i
      pkmn = $player.party[idx]
      return unless pkmn

      target = target_charset(pkmn)
      return if target == @character_name

      @character_name = target if target
    end

    def target_charset(pkmn)
      base = OWsMoreFrames::AnimationStates.strip_state(@character_name)
      player_input   = Input.dir4 != 0
      player_moving  = $game_player&.moving? || $game_player&.jumping? || player_input
      follower_moving = moving? || jumping?

      # Movimiento forzado: nunca idle durante comandos de interacción.
      if @move_route_forcing
        @_ows_stopped = 0.0
        return base
      end

      # Surf — player surfeando + Pokémon de agua
      if $PokemonGlobal&.surfing && OWsMoreFrames::AnimationStates.water_type?(pkmn)
        surf = base + OWsMoreFrames::AnimationStates::SURF_SUFFIX
        return surf if OWsMoreFrames::AnimationStates.charset_exists?(surf)
      end

      # Run — jugador corre (prioridad sobre idle)
      if player_input && $game_player&.move_speed && $game_player.move_speed >= 4
        @_ows_stopped = 0.0
        run = base + OWsMoreFrames::AnimationStates::RUN_SUFFIX
        return run if OWsMoreFrames::AnimationStates.charset_exists?(run)
      end

      # Idle — solo si ambos quietos durante IDLE_DEBOUNCE segundos
      if !player_input && !follower_moving
        @_ows_stopped ||= 0.0
        @_ows_stopped += Graphics.delta
        if @_ows_stopped >= IDLE_DEBOUNCE
          idle = base + OWsMoreFrames::AnimationStates::IDLE_SUFFIX
          return idle if OWsMoreFrames::AnimationStates.charset_exists?(idle)
        end
      else
        @_ows_stopped = 0.0
      end

      base
    end
  end
else
  # --- Fallback para sistemas que usen Game_Follower directamente ---
  class Game_Follower
    IDLE_DEBOUNCE = 0.2

    alias _ows_as_orig_update update unless method_defined?(:_ows_as_orig_update)
    def update
      _ows_as_orig_update
      update_state_sprite
    end

    private

    def update_state_sprite
      base = OWsMoreFrames::AnimationStates.strip_state(@character_name)
      player_input   = Input.dir4 != 0
      player_moving  = $game_player&.moving? || $game_player&.jumping? || player_input
      follower_moving = moving? || jumping?

      # Surf — no aplica a followers genéricos

      # Movimiento forzado
      if @move_route_forcing
        @_ows_stopped = 0.0
        @character_name = base if @character_name != base
        return
      end

      # Run — jugador corre
      if player_input && $game_player&.move_speed && $game_player.move_speed >= 4
        @_ows_stopped = 0.0
        run = base + OWsMoreFrames::AnimationStates::RUN_SUFFIX
        return if run == @character_name
        if OWsMoreFrames::AnimationStates.charset_exists?(run)
          @character_name = run
          return
        end
      end

      # Idle — solo si ambos quietos durante IDLE_DEBOUNCE segundos
      if !player_input && !follower_moving
        @_ows_stopped ||= 0.0
        @_ows_stopped += Graphics.delta
        if @_ows_stopped >= IDLE_DEBOUNCE
          idle = base + OWsMoreFrames::AnimationStates::IDLE_SUFFIX
          return if idle == @character_name
          if OWsMoreFrames::AnimationStates.charset_exists?(idle)
            @character_name = idle
            return
          end
        end
      else
        @_ows_stopped = 0.0
      end

      @character_name = base if @character_name != base
    end
  end
end
