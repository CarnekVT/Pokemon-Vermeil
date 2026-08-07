#===============================================================================
# [VERMEIL] Visual 2.5D - 005_ModeTransition.rb
# Transición suave vanilla <-> 2.5D (blend + swap de renderer).
#===============================================================================
module Mode7
  class << self
    def init_mode_state
      @mode_blend = active_now? ? 1.0 : 0.0
      @last_mode_state = active_now?
      if active_now?
        configure(Config::DEFAULT_ALPHA, Config::DEFAULT_ZOOM)
      else
        configure(0.0, 1.0)
      end
    end

    def smoothstep(t)
      t = [[t, 0.0].max, 1.0].min
      return t * t * (3.0 - 2.0 * t)
    end

    def check_mode_state_change
      state = active_now?
      if @last_mode_state.nil?
        init_mode_state
        return
      end
      return if state == @last_mode_state
      @last_mode_state = state
      begin_mode_transition(state)
    end

    def begin_mode_transition(turning_on)
      frames = Config::MODE_TRANSITION_FRAMES
      @mode_transition_total = frames
      @mode_transition_frames = frames
      @mode_blend_from = effective_mode_blend
      @mode_blend_to = turning_on ? 1.0 : 0.0
      if turning_on
        swap_renderer!(Mode7Renderer)
        set_camera(Config::DEFAULT_ALPHA, Config::DEFAULT_ZOOM, frames)
      else
        set_camera(0.0, 1.0, frames)
      end
    end

    def update_mode_transition
      check_mode_state_change

      return if !@mode_transition_frames || @mode_transition_frames <= 0

      @mode_transition_frames -= 1
      done = @mode_transition_frames <= 0
      t = smoothstep(1.0 - (@mode_transition_frames.to_f / @mode_transition_total))
      @mode_blend = @mode_blend_from + (@mode_blend_to - @mode_blend_from) * t
      invalidate_renderer_ground

      if done
        @mode_blend = @mode_blend_to
        swap_renderer!(TilemapRenderer) if @mode_blend_to <= 0.0
      end
    end

    def swap_renderer!(klass)
      return if !$scene.is_a?(Scene_Map)
      renderer = $scene.instance_variable_get(:@map_renderer)
      return if renderer.is_a?(klass) && !renderer.disposed?
      $scene.disposeSpritesets
      $scene.createSpritesets
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
