#===============================================================================
# [VERMEIL] Visual 2.5D - 005_ModeTransition.rb
# Transición suave vanilla <-> 2.5D (blend + swap de renderer).
#===============================================================================
module Mode7
  class << self
    def init_mode_state
      # Plugin scripts are evaluated before a save has restored $game_switches.
      # Remember whether the gameplay state was actually available; otherwise
      # treating nil as OFF makes a loaded 2.5D save start at vanilla camera and
      # animate into perspective during the first visible frames.
      @mode_state_hydrated = !!$game_switches
      @last_mode_state = active_now?
      @mode_blend = 1.0
      if @last_mode_state
        configure(context_default_alpha, Config::DEFAULT_ZOOM)
      else
        configure(0.0, 1.0)
      end
    end

    def hydrate_mode_state!
      return false if @mode_state_hydrated
      return false if !$game_switches
      @mode_state_hydrated = true
      @last_mode_state = active_now?
      @mode_blend = 1.0
      @transition_frames = 0
      if @last_mode_state
        # Do this synchronously before Mode7Renderer is constructed.  The first
        # rendered map frame therefore already uses the authored perspective.
        configure(context_default_alpha, Config::DEFAULT_ZOOM)
      else
        configure(0.0, 1.0)
      end
      true
    end

    def check_mode_state_change
      hydrate_mode_state!
      state = active_now?
      if @last_mode_state.nil?
        init_mode_state
        return
      end
      return if state == @last_mode_state
      @last_mode_state = state
      begin_mode_transition(state)
    end

    # No existe swap de renderer. Encender/apagar solo interpola la camara.
    def begin_mode_transition(turning_on)
      frames = Config::MODE_TRANSITION_FRAMES
      target_alpha = turning_on ? context_default_alpha : 0.0
      target_zoom  = turning_on ? Config::DEFAULT_ZOOM  : 1.0
      set_camera(target_alpha, target_zoom, frames)
    end

    def update_mode_transition
      check_mode_state_change
    end
  end

  init_mode_state
end

class Scene_Map
  alias_method :_VERMEIL_25D_mode_update, :update unless method_defined?(:_VERMEIL_25D_mode_update)

  def update
    _VERMEIL_25D_mode_update
    Mode7.update_transition
    Mode7.update_mode_transition if $game_map
  end
end


# Load/save hydration must happen before the renderer is allocated, not after
# Scene_Map has already presented one vanilla-looking frame.
class Scene_Map
  if method_defined?(:createSpritesets) &&
     !method_defined?(:_VERMEIL_V25_FIX2_mode_createSpritesets)
    alias_method :_VERMEIL_V25_FIX2_mode_createSpritesets, :createSpritesets
  end

  def createSpritesets
    Mode7.hydrate_mode_state! if Mode7.respond_to?(:hydrate_mode_state!)
    _VERMEIL_V25_FIX2_mode_createSpritesets
  end
end
