#===============================================================================
# [VERMEIL] Visual 2.5D - 041_V25StaticTileSourceCache.rb
# Phase 2.4.15 - static tile source cache + allocation-light keys
#
# Build-only optimization. Static tileset entries repeatedly resolve the same
# bitmap + source rectangle for the same tile ID. Cache that immutable source
# once per renderer build. Animated autotiles keep unique Rect instances because
# their frame rectangle is mutated at runtime.
#===============================================================================
class Mode7Renderer
  private

  if private_method_defined?(:prepare_v25_maker_studio_indexes) &&
     !private_method_defined?(:_VERMEIL_V25_2413_orig_prepare_indexes)
    alias_method :_VERMEIL_V25_2413_orig_prepare_indexes, :prepare_v25_maker_studio_indexes
  end

  def prepare_v25_maker_studio_indexes
    _VERMEIL_V25_2413_orig_prepare_indexes if respond_to?(:_VERMEIL_V25_2413_orig_prepare_indexes, true)
    @v25_static_tileset_source_cache = {}
    @v25_static_autotile_source_cache = {}
    @v25_autotile_name_by_tid = {}
  end

  # Map/extra tileset source. Rect is immutable for static tiles, so sharing it
  # is safe and removes thousands of Rect#clone allocations during map build.
  def v25_static_tileset_source(ts, tid)
    @v25_static_tileset_source_cache ||= {}
    ts_id = ts.respond_to?(:id) ? ts.id.to_i : ts.object_id
    key = (ts_id << 32) | (tid.to_i & 0xFFFFFFFF)
    cached = @v25_static_tileset_source_cache[key]
    return cached if cached

    ts_name = ts.tileset_name
    bmp = nil
    src = nil
    if ts_name == @map.tileset_name
      bmp = @tilesets[@map.tileset_name]
      return nil if !bmp
      @scratch.filename = @map.tileset_name
      @tilesets.set_src_rect(@scratch, tid)
      r = @scratch.src_rect
      src = Rect.new(r.x, r.y, r.width, r.height)
    elsif defined?(MakerStudio)
      bmp = MakerStudio.get_extra_tileset_for_sprite(ts_name)
      return nil if !bmp
      r = MakerStudio.extra_tileset_src_rect(ts_name, tid)
      return nil if !r
      src = Rect.new(r.x, r.y, r.width, r.height)
    else
      return nil
    end

    pair = [bmp, src]
    @v25_static_tileset_source_cache[key] = pair
    pair
  rescue Exception
    nil
  end

  # Override only source lookup/allocation. Entry semantics stay identical.
  def entry_from_tileset(ts, tid, priority, unify)
    return nil if !ts
    pair = v25_static_tileset_source(ts, tid)
    return nil if !pair
    bmp, src = pair
    {
      bitmap: bmp,
      src_rect: src,
      priority: priority,
      animated: false,
      filename: nil,
      tid: tid,
      unify: unify,
      tileset_id: ts.id
    }
  rescue Exception
    nil
  end

  if private_method_defined?(:autotile_name_for) &&
     !private_method_defined?(:_VERMEIL_V25_2413_orig_autotile_name_for)
    alias_method :_VERMEIL_V25_2413_orig_autotile_name_for, :autotile_name_for
  end

  def autotile_name_for(tid)
    @v25_autotile_name_by_tid ||= {}
    return @v25_autotile_name_by_tid[tid] if @v25_autotile_name_by_tid.key?(tid)
    value = _VERMEIL_V25_2413_orig_autotile_name_for(tid)
    @v25_autotile_name_by_tid[tid] = value
    value
  rescue Exception
    _VERMEIL_V25_2413_orig_autotile_name_for(tid)
  end

  # Static autotiles can share their source Rect too. Animated autotiles keep
  # the old per-entry clone because refresh_animated_entry_frames mutates it.
  def make_native_entry(tid, layer)
    if tid < TilemapRenderer::TILESET_START_ID
      filename = autotile_name_for(tid)
      return nil if !filename || filename.empty?
      bmp = @autotiles[filename]
      return nil if !bmp
      animated = @autotiles.animated?(filename)

      src = nil
      if animated
        @scratch.filename = filename
        @autotiles.set_src_rect(@scratch, tid)
        src = @scratch.src_rect.clone
      else
        @v25_static_autotile_source_cache ||= {}
        # Phase 2.4.15: avoid allocating [filename, tid] for every lookup.
        # Nested hashes preserve exact key semantics without hash-collision tricks.
        by_tid = @v25_static_autotile_source_cache[filename]
        if !by_tid
          by_tid = {}
          @v25_static_autotile_source_cache[filename] = by_tid
        end
        src = by_tid[tid]
        if !src
          @scratch.filename = filename
          @autotiles.set_src_rect(@scratch, tid)
          r = @scratch.src_rect
          src = Rect.new(r.x, r.y, r.width, r.height)
          by_tid[tid] = src
        end
      end

      return {
        bitmap: bmp,
        src_rect: src,
        priority: @map.priorities[tid] || 0,
        animated: animated,
        filename: filename,
        tid: tid,
        unify: layer
      }
    end

    ts = $data_tilesets[@map.tileset_id]
    return nil if !ts
    entry_from_tileset(ts, tid, @map.priorities[tid] || 0, layer)
  rescue Exception
    nil
  end
end
