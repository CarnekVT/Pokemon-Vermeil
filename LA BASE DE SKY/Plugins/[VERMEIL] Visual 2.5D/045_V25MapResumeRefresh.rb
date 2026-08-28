#===============================================================================
# [VERMEIL] Visual 2.5D - 045_V25MapResumeRefresh.rb
# Phase 2.5.3.1 - Scene/battle return refresh
#
# Visible-first ground and lazy priority deliberately retain per-map state while
# gameplay is active. Battles/menus can suspend Scene_Map for many frames while
# leaving the same renderer instance alive. On resume, the camera may have the
# same world X/Y, so the normal "camera moved" test does not redraw the cached
# Sky bands until the player takes a step. This file invalidates only the
# visible/projection state on resume; it never rebuilds the whole map.
#===============================================================================
module Mode7
  module MapResumeRefresh
    @pending = false

    class << self
      def request!
        @pending = true
      end

      def consume!
        value = @pending
        @pending = false
        value
      end
    end
  end
end

# Essentials v21 exposes an end-battle event in normal battle flows. Keep the
# renderer-side frame-gap fallback below as authority for bases/plugins that do
# not trigger this event or run battles without changing $scene.
if defined?(EventHandlers)
  begin
    EventHandlers.add(:on_end_battle, :vermeil_v25_map_resume_refresh,
      proc { |*args| Mode7::MapResumeRefresh.request! }
    )
  rescue Exception
  end
end

class Mode7Renderer
  # The Phase 2.5.3 lazy strips have no Bitmap during build. Phase 2.4.1's
  # spatial bucket builder used the Bitmap width and therefore skipped those
  # descriptors entirely. Register their descriptor bounds without forcing
  # materialization so Priority remains visible-first AND participates in the
  # normal fast-path after battle/map resume.
  if private_method_defined?(:build_nds_runtime_buckets) &&
     !private_method_defined?(:_VERMEIL_V2531_build_nds_runtime_buckets)
    alias_method :_VERMEIL_V2531_build_nds_runtime_buckets, :build_nds_runtime_buckets
  end

  private

  def build_nds_runtime_buckets
    _VERMEIL_V2531_build_nds_runtime_buckets
    return if !@nds_fast_strip_buckets || !@priority_strips

    @priority_strips.each_with_index do |data, i|
      next if !data
      source = data[1]
      next if source && !source.disposed?   # already indexed by the stable path
      min_tx = data[2]
      ty = data[3]
      lazy = data[10]
      next if min_tx.nil? || ty.nil? || !lazy
      max_tx = lazy[:max_tx]
      if max_tx.nil?
        width = lazy[:width].to_i
        max_tx = min_tx.to_i + [(width.to_f / Game_Map::TILE_WIDTH).ceil - 1, 0].max
      end
      nds_fast_bucket_add(@nds_fast_strip_buckets, i,
                          min_tx.to_i, ty.to_i, max_tx.to_i, ty.to_i)
    end
  rescue Exception => e
    Console.echo_error("2.5D lazy priority bucket restore: #{e.message}") if defined?(Console)
  end

  def v25_resume_frame_number
    return Graphics.frame_count.to_i if defined?(Graphics) && Graphics.respond_to?(:frame_count)
    nil
  rescue Exception
    nil
  end

  def v25_resume_projection_revision
    return Mode7.projection_revision.to_i if Mode7.respond_to?(:projection_revision)
    0
  rescue Exception
    0
  end

  def v25_force_visible_resume_refresh
    # Force the next renderer update through the normal ground draw path.
    @need_ground_redraw = true
    @last_cam_x = nil
    @last_cam_y = nil
    @last_cam_elevation = nil

    # Cached background/band plans are screen/projection state, not map data.
    # A battle transition can invalidate the target without changing world X/Y.
    @nds_fast_background_key = nil
    @v25_sky_ground_background_key = nil
    @v25_sky_ground_projective_plan_key = nil
    @v25_sky_ground_band_states = nil

    # Force spatial subsets and projected sprite transforms to be reconsidered
    # immediately. The underlying descriptors/bitmaps remain cached.
    @nds_fast_wall_key = nil
    @nds_fast_wall_visibility_key = nil
    @nds_fast_priority_key = nil
    @nds_fast_priority_visibility_key = nil

    if @priority_strips
      @priority_strips.each do |data|
        data[9] = nil if data && data.length > 9
      end
    end
    if @priority_data
      @priority_data.each do |data|
        data[10] = nil if data && data.length > 10
      end
    end

    # Visible-first ground may have composed a different camera window just
    # before battle. Mark only the current visible cells dirty so draw_ground
    # repaints them synchronously on this very frame instead of waiting for a
    # movement threshold. This is intentionally bounded to the camera window.
    if respond_to?(:v25_visible_ground_tile_bounds, true) &&
       respond_to?(:v25_ground_composed_mask, true) && @map && @ground
      bounds = v25_visible_ground_tile_bounds
      if bounds
        min_tx, min_ty, max_tx, max_ty = bounds
        margin = if defined?(Mode7::Config::V25_VISIBLE_GROUND_MARGIN_TILES)
                   Mode7::Config::V25_VISIBLE_GROUND_MARGIN_TILES.to_i
                 else
                   2
                 end
        min_tx = [min_tx.to_i - margin, 0].max
        min_ty = [min_ty.to_i - margin, 0].max
        max_tx = [max_tx.to_i + margin, @map.width - 1].min
        max_ty = [max_ty.to_i + margin, @map.height - 1].min
        mask = v25_ground_composed_mask
        ty = min_ty
        while ty <= max_ty
          row = ty * @map.width
          tx = min_tx
          while tx <= max_tx
            idx = row + tx
            mask[idx] = false if idx >= 0 && idx < mask.length
            tx += 1
          end
          ty += 1
        end
      end
    end
  rescue Exception => e
    Console.echo_error("2.5D map-resume refresh: #{e.message}") if defined?(Console)
    @need_ground_redraw = true
  end

  public

  # Wrap the final renderer update loaded by 021. We detect three equivalent
  # resume signals:
  #   1) explicit Essentials battle-end event;
  #   2) a gap in map-renderer frames (works with custom battle/menu scenes);
  #   3) a projection revision change while X/Y remains unchanged.
  if method_defined?(:update) && !method_defined?(:_VERMEIL_V2531_map_resume_update)
    alias_method :_VERMEIL_V2531_map_resume_update, :update
  end

  def update
    frame = v25_resume_frame_number
    revision = v25_resume_projection_revision
    explicit = Mode7::MapResumeRefresh.consume! rescue false
    gap = frame && @v25_resume_last_frame && (frame - @v25_resume_last_frame) > 3
    projection_changed = !@v25_resume_last_revision.nil? &&
                         revision != @v25_resume_last_revision

    v25_force_visible_resume_refresh if explicit || gap || projection_changed

    _VERMEIL_V2531_map_resume_update
  ensure
    @v25_resume_last_frame = frame if defined?(frame) && frame
    @v25_resume_last_revision = v25_resume_projection_revision
  end
end
