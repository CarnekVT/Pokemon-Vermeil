#===============================================================================
# [VERMEIL] Visual 2.5D - 039_V25BillboardModelCollisionFix.rb
# Phase 2.4.11.5 - Runtime collision preload authority.
#
# MapXXX.v25c was already supported by the codec/physics world, but no final
# Game_Map#setup hook actually preloaded it. Consequently a compiled model could
# render from .v25r/.v25m while its collision Hash remained empty.
#===============================================================================
class Game_Map
  alias_method :_VERMEIL_V25_4115_setup, :setup unless method_defined?(:_VERMEIL_V25_4115_setup)

  def setup(map_id)
    _VERMEIL_V25_4115_setup(map_id)

    if Mode7.respond_to?(:clear_geometry_collision_authority_cache!)
      Mode7.clear_geometry_collision_authority_cache!
    end

    cells = nil
    if Mode7.respond_to?(:preload_geometry_collision_for_map)
      cells = Mode7.preload_geometry_collision_for_map(map_id, width, height)
    elsif defined?(Mode7::ModelPhysicsWorld)
      cells = Mode7::ModelPhysicsWorld.preload(map_id)
    end

    # movement_blocked_cached? is frame-scoped, but setup may happen inside the
    # same Graphics frame as the previous map. Clear it explicitly so no stale
    # result survives a transfer/reload.
    Mode7.instance_variable_set(:@movement_block_cache_frame, nil)
    Mode7.instance_variable_set(:@movement_block_cache_map, nil)
    Mode7.instance_variable_set(:@movement_block_cache, {})

    if defined?(Console) && defined?(Mode7::ModelPhysicsWorld)
      begin
        path = Mode7::ModelPhysicsWorld.collision_path(map_id)
        state = File.file?(path) ? "sidecar" : "runtime-fallback pending"
        count = cells.respond_to?(:length) ? cells.length : 0
        Console.echo_li("[VERMEIL] Model collision: #{state} #{path} cells=#{count}")
      rescue Exception
      end
    end
  end
end
