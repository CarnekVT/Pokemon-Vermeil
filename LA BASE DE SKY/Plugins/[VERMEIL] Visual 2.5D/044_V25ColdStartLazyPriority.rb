#===============================================================================
# [VERMEIL] Visual 2.5D - 044_V25ColdStartLazyPriority.rb
# Phase 2.5.3 - cold-start / first-save-load latency
#
# Priority ownership/classification stays synchronous and authoritative, but
# off-screen strip/surface bitmaps are materialized only when they can enter the
# camera window. This removes a large number of Bitmap.new/blt operations from
# the first Scene_Map build without changing P0/P1/P2 semantics.
#===============================================================================
module Mode7
  module Config
    V25_LAZY_PRIORITY_BITMAPS = true unless const_defined?(:V25_LAZY_PRIORITY_BITMAPS)
    V25_PRIORITY_LAZY_RADIUS_X = 28 unless const_defined?(:V25_PRIORITY_LAZY_RADIUS_X)
  end
end

class Mode7Renderer
  private

  # Same descriptor as the stable make_priority_strip, but source allocation is
  # delayed. All ownership, row grouping, elevation and logical priority have
  # already been resolved before this method is called.
  if private_method_defined?(:make_priority_strip) &&
     !private_method_defined?(:_VERMEIL_V253_full_make_priority_strip)
    alias_method :_VERMEIL_V253_full_make_priority_strip, :make_priority_strip
  end

  def make_priority_strip(cells, ty, priority, unify, elevation)
    return _VERMEIL_V253_full_make_priority_strip(cells, ty, priority, unify, elevation) if !Mode7::Config::V25_LAZY_PRIORITY_BITMAPS
    return if !cells || cells.empty?

    min_tx = cells.keys.min
    max_tx = cells.keys.max
    return if min_tx.nil? || max_tx.nil?
    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH

    sprite = Sprite.new(@viewport)
    sprite.bitmap = nil
    sprite.ox = 0
    sprite.oy = Game_Map::TILE_HEIGHT
    sprite.visible = false

    lazy = {
      width: width,
      min_tx: min_tx,
      max_tx: max_tx,
      ty: ty,
      cells: cells,
      mode: :entries_only
    }

    @priority_strips.push([
      sprite, nil, min_tx, ty, priority, unify, elevation,
      cells, :entries_only, nil, lazy
    ])
  rescue Exception => e
    Console.echo_error("2.5D lazy priority descriptor: #{e.message}") if defined?(Console)
  end

  def v25_materialize_priority_strip(data)
    return nil if !data
    source = data[1]
    return source if source && !source.disposed?
    lazy = data[10]
    return nil if !lazy

    width = lazy[:width].to_i
    return nil if width <= 0
    source = Bitmap.new(width, Game_Map::TILE_HEIGHT)
    source.clear
    min_tx = lazy[:min_tx].to_i
    cells = lazy[:cells] || data[7] || {}

    cells.each do |tx, entries|
      x = (tx - min_tx) * Game_Map::TILE_WIDTH
      entries.sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }.each do |entry|
        blt_entry_into(source, x, 0, entry, entry[:opacity] || 255)
      end
    end

    sprite = data[0]
    sprite.bitmap = source
    sprite.ox = 0
    sprite.oy = source.height
    sprite.tone = @tone if @tone
    sprite.color = @color if @color
    data[1] = source
    data[10] = nil
    source
  rescue Exception => e
    Console.echo_error("2.5D lazy priority materialize: #{e.message}") if defined?(Console)
    nil
  end

  # Individual priority surfaces are rare (e.g. InteriorBorder), but keep them
  # lazy as well so first-map cost scales with what is actually visible.
  if private_method_defined?(:make_priority_surface) &&
     !private_method_defined?(:_VERMEIL_V253_full_make_priority_surface)
    alias_method :_VERMEIL_V253_full_make_priority_surface, :make_priority_surface
  end

  def make_priority_surface(tx, ty, entry, depth = nil, force = false)
    return _VERMEIL_V253_full_make_priority_surface(tx, ty, entry, depth, force) if !Mode7::Config::V25_LAZY_PRIORITY_BITMAPS
    return if !force && !priority_surface_entry?(entry)

    sprite = Sprite.new(@viewport)
    sprite.bitmap = nil
    sprite.ox = Game_Map::TILE_WIDTH / 2.0
    sprite.oy = Game_Map::TILE_HEIGHT
    sprite.visible = false

    wx = tx * Game_Map::TILE_WIDTH + Game_Map::TILE_WIDTH / 2.0
    wyb = (ty + 1) * Game_Map::TILE_HEIGHT
    lazy = { entry: entry }
    @priority_data.push([
      sprite, wx, wyb, entry, entry_visual_priority(entry),
      entry_world_elevation(entry), depth, tx, ty, nil, nil, lazy
    ])
  rescue Exception => e
    Console.echo_error("2.5D lazy priority surface descriptor: #{e.message}") if defined?(Console)
  end

  def v25_materialize_priority_surface(data)
    return nil if !data
    source = data[9]
    return source if source && !source.disposed?
    lazy = data[11]
    entry = lazy && lazy[:entry] ? lazy[:entry] : data[3]
    return nil if !entry

    source = Bitmap.new(Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
    source.clear
    blt_entry_into(source, 0, 0, entry, entry[:opacity] || 255)
    sprite = data[0]
    sprite.bitmap = source
    sprite.ox = source.width / 2.0
    sprite.oy = source.height
    sprite.tone = @tone if @tone
    sprite.color = @color if @color
    data[9] = source
    data[11] = nil
    source
  rescue Exception => e
    Console.echo_error("2.5D lazy priority surface materialize: #{e.message}") if defined?(Console)
    nil
  end

  # Reimplementation of the stable updater with one important difference:
  # coarse tile-space culling happens BEFORE Bitmap allocation.
  def update_priority_strips
    return if !@priority_strips
    cam_tx = Mode7.cam_x / Game_Map::TILE_WIDTH
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ? Mode7::Config::WALL_SPAWN_RADIUS_Y : 34
    radius_x = Mode7::Config::V25_PRIORITY_LAZY_RADIUS_X.to_i
    radius_x = 28 if radius_x <= 0
    cam_x_now = Mode7.cam_x
    cam_y_now = Mode7.projection_cam_y
    cam_elev_now = Mode7.projection_cam_elevation.to_f
    proj_rev = Mode7.projection_revision

    @priority_strips.each do |data|
      sprite, source, min_tx, ty, priority, _unify, elevation,
      cells, _mountain_shadow, projection_key = data

      if (ty - cam_ty).abs > radius_y
        sprite.visible = false
        next
      end

      lazy = data[10]
      max_tx = if lazy && lazy[:max_tx]
                 lazy[:max_tx].to_i
               elsif cells && !cells.empty?
                 cells.keys.max.to_i
               else
                 min_tx.to_i
               end
      if max_tx < cam_tx - radius_x || min_tx.to_i > cam_tx + radius_x
        sprite.visible = false
        next
      end

      source = v25_materialize_priority_strip(data) if !source || source.disposed?
      if !source || source.disposed?
        sprite.visible = false
        next
      end

      reproj_step = Mode7::Config::PRIORITY_REPROJECT_WORLD_STEP.to_f
      reproj_step = 1.0 if reproj_step <= 0.0
      needs_recalc = !projection_key ||
                     (cam_x_now - projection_key[0]).abs >= reproj_step ||
                     (cam_y_now - projection_key[1]).abs >= reproj_step ||
                     projection_key.length < 4 ||
                     (cam_elev_now - projection_key[2]).abs >= 0.01 ||
                     proj_rev != projection_key[3]
      if needs_recalc
        if !redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation)
          sprite.visible = false
          next
        end
        data[9] = [cam_x_now, cam_y_now, cam_elev_now, proj_rev]
      end

      top = sprite.y - sprite.oy * sprite.zoom_y
      bottom = sprite.y
      if top > Mode7.screen_h || bottom < 0 ||
         sprite.x + source.width * sprite.zoom_x < 0 ||
         sprite.x > Mode7.screen_w
        sprite.visible = false
        next
      end

      effective_priority = [priority.to_i, 0].max
      logical_wyb = (ty + 1 + effective_priority) * Game_Map::TILE_HEIGHT
      sprite.z = Mode7.depth_z_at_elevation(logical_wyb, elevation, 0, -1)
      apply_depth_fog_to_sprite(sprite, sprite.y)
      sprite.visible = true
    end
  end

  def update_priority_objects
    return if !@priority_data
    cam_tx = Mode7.cam_x / Game_Map::TILE_WIDTH
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT
    radius_x = defined?(Mode7::Config::WALL_SPAWN_RADIUS_X) ? Mode7::Config::WALL_SPAWN_RADIUS_X : 26
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ? Mode7::Config::WALL_SPAWN_RADIUS_Y : 34

    @priority_data.each do |data|
      sprite, wx, wyb, _entry, priority, elevation, depth,
      tx, ty, source, projection_key = data

      if tx < cam_tx - radius_x || tx > cam_tx + radius_x ||
         ty < cam_ty - radius_y || ty > cam_ty + radius_y
        sprite.visible = false
        next
      end

      source = v25_materialize_priority_surface(data) if !source || source.disposed?
      if !source || source.disposed?
        sprite.visible = false
        next
      end

      reproj_step = Mode7::Config::PRIORITY_REPROJECT_WORLD_STEP.to_f
      reproj_step = 1.0 if reproj_step <= 0.0
      needs_projection = !projection_key ||
                         (Mode7.cam_x - projection_key[0]).abs >= reproj_step ||
                         (Mode7.projection_cam_y - projection_key[1]).abs >= reproj_step ||
                         projection_key.length < 4 ||
                         (Mode7.projection_cam_elevation.to_f - projection_key[2]).abs >= 0.01 ||
                         projection_key[3] != Mode7.projection_revision
      if needs_projection
        if !redraw_projected_priority_surface(sprite, source, wx, wyb, elevation)
          sprite.visible = false
          next
        end
        data[10] = [Mode7.cam_x, Mode7.projection_cam_y,
                    Mode7.projection_cam_elevation.to_f, Mode7.projection_revision]
      end

      top = sprite.y - sprite.oy * sprite.zoom_y
      left = sprite.x - sprite.ox * sprite.zoom_x
      right = left + source.width * sprite.zoom_x
      if top > Mode7.screen_h || sprite.y < 0 ||
         left > Mode7.screen_w || right < 0
        sprite.visible = false
        next
      end

      depth_wyb, depth_priority, _depth_unify = depth || [wyb, priority, 0]
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, -1)
      apply_depth_fog_to_sprite(sprite, sprite.y)
      sprite.visible = true
    end
  end

  # Animated autotiles that have not yet materialized need no update. Once a
  # lazy strip/surface exists, preserve the stable recomposition behavior.
  if private_method_defined?(:recomposite_autotiles) &&
     !private_method_defined?(:_VERMEIL_V253_recomposite_autotiles)
    alias_method :_VERMEIL_V253_recomposite_autotiles, :recomposite_autotiles
  end
end

# Warm the only authoring JSON still consulted by Visual 2.5D while the user is
# outside Scene_Map. This shifts its disk read/parse away from first save load.
module Mode7
  module ColdStartWarmup
    @done = false
    class << self
      def update
        return if @done
        return if defined?(Scene_Map) && defined?($scene) && $scene.is_a?(Scene_Map)
        @done = true
        if defined?(Mode7::ProgressiveZoom)
          Mode7::ProgressiveZoom.send(:runtime_document) rescue nil
        end
      rescue Exception
        @done = true
      end
    end
  end
end

EventHandlers.add(:on_frame_update, :vermeil_v25_cold_start_warmup,
  proc { Mode7::ColdStartWarmup.update }
)
