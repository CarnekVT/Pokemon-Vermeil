#===============================================================================
# [VERMEIL] Visual 2.5D - 042_V25VisibleFirstGroundLoad.rb
# Phase 2.5.2 - visible-first map loading
#
# The old build composed the complete map-sized @ground bitmap before Scene_Map
# could draw a frame. Large maps therefore paid for thousands of off-screen
# cells on every transfer/startup. This keeps the same authoritative entry cache
# and renderer, but rasterizes only the cells that the current perspective can
# actually sample. New cells are composed synchronously just before they enter
# a ground band, so there is no visual pop-in.
#===============================================================================
module Mode7
  module Config
    V25_VISIBLE_FIRST_GROUND = true unless const_defined?(:V25_VISIBLE_FIRST_GROUND)
    V25_VISIBLE_GROUND_MARGIN_TILES = 2 unless const_defined?(:V25_VISIBLE_GROUND_MARGIN_TILES)
  end
end

class Mode7Renderer
  private

  def v25_visible_first_ground_enabled?
    Mode7::Config::V25_VISIBLE_FIRST_GROUND && @map && @ground && !@ground.disposed?
  rescue Exception
    false
  end

  def v25_ground_composed_mask
    expected = @map.width.to_i * @map.height.to_i
    if !@v25_ground_composed_mask || @v25_ground_composed_mask.length != expected
      @v25_ground_composed_mask = Array.new(expected, false)
    end
    @v25_ground_composed_mask
  end

  def v25_ground_entries_at_index(idx, tx, ty)
    packed = @v25_entry_index
    return packed[idx] if packed && packed.respond_to?(:[]) && packed[idx]
    cache = @entry_cache
    return nil if !cache
    cache[[tx, ty]]
  rescue Exception
    nil
  end

  # Exact per-cell equivalent of compose_ground_fast. It deliberately reuses
  # the established ground/underlay/shadow helpers so visual semantics do not
  # diverge from the stable Phase 2.4.13 renderer.
  def v25_compose_ground_cell(tx, ty)
    return if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    idx = ty * @map.width + tx
    mask = v25_ground_composed_mask
    return if mask[idx]

    entries = v25_ground_entries_at_index(idx, tx, ty)
    if entries && !entries.empty?
      ground_entries = ground_entries_for_cell(tx, ty, entries)
      paint_nds_underlay(tx, ty, entries, ground_entries, @ground)

      if @ms_shadow_env
        lower = []
        upper = []
        ground_entries.each do |entry|
          if ground_shadow_band_for(tx, ty, entry) == :above_shadow
            upper << entry
          else
            lower << entry
          end
        end
        blt_ground_cell(tx, ty, lower, @ground) unless lower.empty?
        if @shadow_ground && !@shadow_ground.disposed?
          tw = Game_Map::TILE_WIDTH
          th = Game_Map::TILE_HEIGHT
          px = tx * tw
          py = ty * th
          @src_rect.set(px, py, tw, th)
          @ground.blt(px, py, @shadow_ground, @src_rect)
        end
        blt_ground_cell(tx, ty, upper, @ground) unless upper.empty?
      else
        blt_ground_cell(tx, ty, ground_entries, @ground) unless ground_entries.empty?
      end
    end
    mask[idx] = true
  rescue Exception => e
    mask[idx] = true if defined?(mask) && mask && defined?(idx) && idx
    Console.echo_error("VERMEIL visible-ground cell #{tx},#{ty}: #{e.message}") if defined?(Console)
  end

  def v25_ensure_ground_tile_rect(min_tx, min_ty, max_tx, max_ty)
    return if !v25_visible_first_ground_enabled?
    margin = Mode7::Config::V25_VISIBLE_GROUND_MARGIN_TILES.to_i
    margin = 0 if margin < 0
    min_tx = [min_tx.to_i - margin, 0].max
    min_ty = [min_ty.to_i - margin, 0].max
    max_tx = [max_tx.to_i + margin, @map.width - 1].min
    max_ty = [max_ty.to_i + margin, @map.height - 1].min
    return if max_tx < min_tx || max_ty < min_ty

    ty = min_ty
    while ty <= max_ty
      tx = min_tx
      while tx <= max_tx
        v25_compose_ground_cell(tx, ty)
        tx += 1
      end
      ty += 1
    end
  end

  # Resolve the union of world source rectangles sampled by the adaptive Sky
  # ground bands. This is tighter than a fixed player-centered rectangle and
  # stays correct at different angles/zooms/resolutions.
  def v25_visible_ground_tile_bounds
    return nil if !@map || !@ground
    horizon = [Mode7.horizon_row.ceil, 0].max
    return nil if horizon >= Mode7.screen_h

    plan = if respond_to?(:v25_sky_ground_band_plan, true)
             v25_sky_ground_band_plan(horizon)
           else
             [[horizon, [Mode7.screen_h - horizon, 1].max]]
           end
    cx = Mode7.cam_x.to_f
    screen_w = Mode7.screen_w.to_f
    center_x = Mode7.center_x.to_f
    ground_w = @ground.width.to_i
    map_h_px = @map.height * Game_Map::TILE_HEIGHT

    min_x = ground_w
    max_x = 0
    min_y = map_h_px
    max_y = 0
    found = false

    plan.each do |band|
      sy = band[0].to_i
      bh = [band[1].to_i, 1].max
      sample_sy = sy + (bh - 1) * 0.5
      wy0 = Mode7.world_y_for_row(sy)
      wy1 = Mode7.world_y_for_row([sy + bh, Mode7.screen_h - 1].min)
      next if !wy0 || !wy1 || wy1 < 0 || wy0 >= map_h_px
      k = Mode7.hscale(sample_sy)
      next if !k || k <= 0.001
      span = screen_w / k
      wx_left = cx - center_x / k
      lo = [wx_left.floor, 0].max
      hi = [(wx_left + span).ceil, ground_w].min
      next if hi <= lo
      top = [[wy0, wy1].min.floor, 0].max
      bottom = [[wy0, wy1].max.ceil, map_h_px].min
      next if bottom <= top
      min_x = lo if lo < min_x
      max_x = hi if hi > max_x
      min_y = top if top < min_y
      max_y = bottom if bottom > max_y
      found = true
    end
    # V25 PATCH3: when the new Game.exe exposes Shader/corners, the active
    # ground backend may sample the NDS source rectangle instead of exactly the
    # Sky-band plan above. Union both visible source ranges before rasterizing
    # cells. Without this, priority/stair sprites can remain visible while the
    # underlying @ground pixels are still transparent, producing blue "unloaded"
    # zones even though the map itself is present.
    if respond_to?(:nds_visible_world_y_range, true) &&
       respond_to?(:nds_visible_world_x_range, true)
      begin
        ny0, ny1 = nds_visible_world_y_range
        nx0, nx1 = nds_visible_world_x_range(ny0, ny1)
        if nx1.to_f > nx0.to_f && ny1.to_f > ny0.to_f
          min_x = [min_x, nx0.floor].min
          max_x = [max_x, nx1.ceil].max
          min_y = [min_y, ny0.floor].min
          max_y = [max_y, ny1.ceil].max
          found = true
        end
      rescue Exception
      end
    end

    return nil if !found

    min_x = min_x.clamp(0, ground_w)
    max_x = max_x.clamp(0, ground_w)
    min_y = min_y.clamp(0, map_h_px)
    max_y = max_y.clamp(0, map_h_px)

    tw = Game_Map::TILE_WIDTH
    th = Game_Map::TILE_HEIGHT
    [min_x / tw, min_y / th,
     [(max_x - 1) / tw, 0].max,
     [(max_y - 1) / th, 0].max]
  rescue Exception
    nil
  end

  def v25_ensure_visible_ground
    bounds = v25_visible_ground_tile_bounds
    if bounds
      v25_ensure_ground_tile_rect(*bounds)
      return
    end

    # Conservative fallback before camera projection is fully initialized.
    tx = ($game_player && $game_player.respond_to?(:x)) ? $game_player.x.to_i : 0
    ty = ($game_player && $game_player.respond_to?(:y)) ? $game_player.y.to_i : 0
    half_x = (Mode7.screen_w / Game_Map::TILE_WIDTH / 2) + 4
    half_y = (Mode7.screen_h / Game_Map::TILE_HEIGHT / 2) + 6
    v25_ensure_ground_tile_rect(tx - half_x, ty - half_y, tx + half_x, ty + half_y)
  end

  # Replace only the map-wide raster pass. All classification/ownership remains
  # untouched and therefore billboard/P0/P1/wall semantics stay identical.
  if private_method_defined?(:compose_ground_fast) &&
     !private_method_defined?(:_VERMEIL_V25LOAD_compose_full_ground)
    alias_method :_VERMEIL_V25LOAD_compose_full_ground, :compose_ground_fast
  end

  def compose_ground_fast
    return _VERMEIL_V25LOAD_compose_full_ground if respond_to?(:_VERMEIL_V25LOAD_compose_full_ground, true) && !Mode7::Config::V25_VISIBLE_FIRST_GROUND
    @v25_ground_composed_mask = Array.new(@map.width * @map.height, false)
    bake_ms_shadows if @ms_shadow_env
    v25_ensure_visible_ground
  end

  # Priority strips occasionally copy their P0 base from @ground while the map
  # is still being built. Ensure those exact cells exist before the copy; this
  # prevents off-screen strips from inheriting transparent/uninitialized pixels.
  if private_method_defined?(:draw_priority_strip_source) &&
     !private_method_defined?(:_VERMEIL_V25LOAD_orig_draw_priority_strip_source)
    alias_method :_VERMEIL_V25LOAD_orig_draw_priority_strip_source, :draw_priority_strip_source
    def draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow = false)
      if Mode7::Config::V25_VISIBLE_FIRST_GROUND && cells
        cells.each_key { |tx| v25_compose_ground_cell(tx, ty) }
      end
      _VERMEIL_V25LOAD_orig_draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow)
    end
  end

  if private_method_defined?(:draw_ground) &&
     !private_method_defined?(:_VERMEIL_V25LOAD_orig_draw_ground)
    alias_method :_VERMEIL_V25LOAD_orig_draw_ground, :draw_ground
    def draw_ground
      v25_ensure_visible_ground if Mode7::Config::V25_VISIBLE_FIRST_GROUND
      _VERMEIL_V25LOAD_orig_draw_ground
    end
  end

  if private_method_defined?(:redraw_ground_cell) &&
     !private_method_defined?(:_VERMEIL_V25LOAD_orig_redraw_ground_cell)
    alias_method :_VERMEIL_V25LOAD_orig_redraw_ground_cell, :redraw_ground_cell
    def redraw_ground_cell(tx, ty)
      _VERMEIL_V25LOAD_orig_redraw_ground_cell(tx, ty)
      if @v25_ground_composed_mask && @map
        idx = ty.to_i * @map.width + tx.to_i
        @v25_ground_composed_mask[idx] = true if idx >= 0 && idx < @v25_ground_composed_mask.length
      end
    end
  end
end
