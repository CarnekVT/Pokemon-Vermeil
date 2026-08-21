#===============================================================================
# [VERMEIL] Visual 2.5D - 040_V25DebugThroughBypass.rb
# Phase 2.4.11.7 - Debug Ctrl is authoritative over all V25 collision.
#
# Essentials' debug walk-through must win over model/Geometry collision too.
# The V25 passability hooks run before parts of the vanilla debug path, so they
# explicitly mirror the Ctrl bypass instead of returning false first.
#===============================================================================
module Mode7
  class << self
    def v25_debug_through_active?
      return false if !$DEBUG
      return false if !defined?(Input) || !Input.respond_to?(:press?)

      keys = []
      keys << Input::CTRL    if defined?(Input::CTRL)
      keys << Input::CONTROL if defined?(Input::CONTROL)
      keys << Input::LCTRL   if defined?(Input::LCTRL)
      keys << Input::RCTRL   if defined?(Input::RCTRL)
      keys.each do |key|
        begin
          return true if Input.press?(key)
        rescue Exception
        end
      end
      false
    rescue Exception
      false
    end
  end
end

# Make the shared 2.5D collision cache honor Ctrl before consulting walls,
# surfaces or model physics. The engine's original passability method then runs
# and retains its own normal debug behavior.
module Mode7
  class << self
    if method_defined?(:movement_blocked_cached?) &&
       !method_defined?(:_VERMEIL_V25_4117_movement_blocked_cached)
      alias_method :_VERMEIL_V25_4117_movement_blocked_cached, :movement_blocked_cached?
    end

    def movement_blocked_cached?(x, y, dir)
      return false if v25_debug_through_active?
      _VERMEIL_V25_4117_movement_blocked_cached(x, y, dir)
    end
  end
end

# 029_ModelPhysics also has a direct player movement gate. It must use the same
# bypass or it can still veto movement after Game_Map#passable? allowed Ctrl.
if defined?(VermeilModelPhysicsPlayerGate)
  module VermeilModelPhysicsPlayerGate
    def can_move_in_direction?(dir, strict = false)
      bypass = (respond_to?(:through) && through) ||
               (Mode7.respond_to?(:v25_debug_through_active?) && Mode7.v25_debug_through_active?)
      if !bypass && defined?(Mode7::ModelPhysicsWorld) &&
         Mode7::ModelPhysicsWorld.blocked_move?(self, dir)
        return false
      end
      super
    end
  end
end
