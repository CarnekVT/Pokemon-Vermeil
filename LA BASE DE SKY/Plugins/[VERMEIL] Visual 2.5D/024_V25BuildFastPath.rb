#===============================================================================
# [VERMEIL] Visual 2.5D - 024_V25BuildFastPath.rb
# V25 Phase 2.4.3 - authoritative sparse indexes + ground build fast path
#===============================================================================
class Mode7Renderer
  private

  # ---------------------------------------------------------------------------
  # Maker Studio sparse indexes
  # ---------------------------------------------------------------------------
  # The current LBDS integration already builds cell-indexed structures.  Once
  # one of those structures exists, a missing cell is authoritative "no data";
  # it must NOT fall back to the public accessor and repeat the same lookup.
  if private_method_defined?(:prepare_v25_maker_studio_indexes) &&
     !private_method_defined?(:_VERMEIL_V25_243_orig_prepare_indexes)
    alias_method :_VERMEIL_V25_243_orig_prepare_indexes, :prepare_v25_maker_studio_indexes
  end

  def prepare_v25_maker_studio_indexes
    _VERMEIL_V25_243_orig_prepare_indexes if respond_to?(:_VERMEIL_V25_243_orig_prepare_indexes, true)

    @v25_native_props_authoritative = !@v25_native_props_index.nil?
    @v25_cell_caps_authoritative    = !@v25_cell_caps_index.nil?

    # Invert visible extended layers once: idx => [[layer, tile_data, unify], ...]
    # The Maker Studio source index is sparse by layer.  The old Visual loop did
    # one hash probe PER visible extended layer PER map cell; this turns that into
    # one probe per cell and only visits actual extended tiles.
    @v25_ext_cells_index = nil
    layers = @v25_ext_layers_index
    if layers.is_a?(Array)
      by_cell = {}
      layers.each do |layer|
        next if !layer
        tiles = layer[:tiles]
        next if !tiles || !tiles.respond_to?(:each_pair)
        ul = if defined?(MakerStudio) && MakerStudio.respond_to?(:unified_layer)
               MakerStudio.unified_layer(layer["id"])
             else
               native_layer_count + layer["id"].to_i
             end
        tiles.each_pair do |idx, td|
          next if !td
          key = idx.to_i
          (by_cell[key] ||= []) << [layer, td, ul]
        end
      end
      @v25_ext_cells_index = by_cell
    end

    # Per-build derived caches.  Entries/ownership are immutable until the next
    # renderer build, so filtering a cell twice is pure duplicated work.
    @v25_ground_entries_cache = {}
    @v25_autotile_cell_seen = Hash.new { |h, k| h[k] = {} }
  rescue Exception
    @v25_native_props_authoritative = false
    @v25_cell_caps_authoritative = false
    @v25_ext_cells_index = nil
    @v25_ground_entries_cache = {}
    @v25_autotile_cell_seen = Hash.new { |h, k| h[k] = {} }
  end

  if private_method_defined?(:v25_native_props_at) &&
     !private_method_defined?(:_VERMEIL_V25_243_orig_native_props_at)
    alias_method :_VERMEIL_V25_243_orig_native_props_at, :v25_native_props_at
  end

  def v25_native_props_at(tx, ty, layer)
    if @v25_native_props_authoritative
      idx = ty * @map.width + tx
      data = @v25_native_props_index
      pair = nil
      if data.is_a?(Array)
        cells = data[layer]
        pair = cells[idx] if cells && cells.respond_to?(:[])
      elsif data.is_a?(Hash)
        cells = data[layer]
        cells = data[layer.to_s] if cells.nil?
        pair = cells[idx] if cells && cells.respond_to?(:[])
        pair = cells[idx.to_s] if pair.nil? && cells && cells.respond_to?(:[])
      end
      return nil if pair.nil?
      pair = pair[0] if pair.is_a?(Array) && pair.length == 2 && pair[0].is_a?(Hash)
      return pair if pair.is_a?(Hash)
      return nil
    end
    return _VERMEIL_V25_243_orig_native_props_at(tx, ty, layer) if respond_to?(:_VERMEIL_V25_243_orig_native_props_at, true)
    nil
  rescue Exception
    nil
  end

  if private_method_defined?(:v25_cached_ground_cap) &&
     !private_method_defined?(:_VERMEIL_V25_243_orig_ground_cap)
    alias_method :_VERMEIL_V25_243_orig_ground_cap, :v25_cached_ground_cap
  end

  def v25_cached_ground_cap(tx, ty)
    if @v25_cell_caps_authoritative
      idx = ty * @map.width + tx
      data = @v25_cell_caps_index
      value = nil
      if data.is_a?(Array)
        value = data[idx]
      elsif data.is_a?(Hash)
        value = data[idx]
        value = data[idx.to_s] if value.nil?
      end
      return value.nil? ? -1 : value.to_i
    end
    return _VERMEIL_V25_243_orig_ground_cap(tx, ty) if respond_to?(:_VERMEIL_V25_243_orig_ground_cap, true)
    -1
  rescue Exception
    -1
  end

  # ---------------------------------------------------------------------------
  # Sparse extended layers: one cell lookup instead of N layers per cell
  # ---------------------------------------------------------------------------
  if private_method_defined?(:collect_extended_entries) &&
     !private_method_defined?(:_VERMEIL_V25_243_orig_collect_extended_entries)
    alias_method :_VERMEIL_V25_243_orig_collect_extended_entries, :collect_extended_entries
  end

  def collect_extended_entries(tx, ty, entries, seen)
    by_cell = @v25_ext_cells_index
    if by_cell
      idx = ty * @map.width + tx
      items = by_cell[idx]
      return if !items || items.empty?

      items.each do |item|
        layer, td, ul = item
        next if !layer || !td
        next if layer.key?("visible") && !layer["visible"]

        tid = td["tile_id"].to_i
        priority = if defined?(MakerStudio) && MakerStudio.respond_to?(:resolve_band_priority)
                     MakerStudio.resolve_band_priority(@map, tid, td)
                   else
                     td["priority"].to_i
                   end
        entry = nil

        if td["autotile_name"]
          entry = make_ext_autotile_entry(td, priority, ul)
        elsif td["tileset_id"]
          ts = $data_tilesets[td["tileset_id"].to_i]
          entry = entry_from_tileset(ts, tid, priority, ul) if ts
        elsif tid > 0
          ts = $data_tilesets[@map.tileset_id]
          entry = entry_from_tileset(ts, tid, priority, ul) if ts
        end
        next if !entry

        stylize_entry(entry, td, ul)
        entry[:zoom_x] = layer["zoom_x"] || td["zoom_x"] || 1.0
        entry[:zoom_y] = layer["zoom_y"] || td["zoom_y"] || 1.0
        entry[:angle] = layer["angle"] || td["angle"] || 0.0
        entry[:mirror] = layer.key?("mirror") ? layer["mirror"] : (td.key?("mirror") ? td["mirror"] : false)
        entry[:ox] = layer["ox"] || td["ox"] || 0
        entry[:oy] = layer["oy"] || td["oy"] || 0
        entry[:blend_type] = layer["blend_type"] || td["blend_type"] || 0

        if layer["opacity"]
          entry[:opacity] = layer["opacity"].to_i
        elsif !entry[:opacity]
          entry[:opacity] = 255
        end
        entry[:elevation] = layer["elevation"].to_i if layer["elevation"]
        append_entry(entries, seen, entry)
      end
      return
    end

    _VERMEIL_V25_243_orig_collect_extended_entries(tx, ty, entries, seen) if respond_to?(:_VERMEIL_V25_243_orig_collect_extended_entries, true)
  end

  # ---------------------------------------------------------------------------
  # Ground filtering cache
  # ---------------------------------------------------------------------------
  if private_method_defined?(:ground_entries_for_cell) &&
     !private_method_defined?(:_VERMEIL_V25_243_orig_ground_entries_for_cell)
    alias_method :_VERMEIL_V25_243_orig_ground_entries_for_cell, :ground_entries_for_cell
  end

  def ground_entries_for_cell(tx, ty, entries)
    cache = @v25_ground_entries_cache
    if cache
      idx = ty * @map.width + tx
      return cache[idx] if cache.key?(idx)
      result = _VERMEIL_V25_243_orig_ground_entries_for_cell(tx, ty, entries)
      cache[idx] = result
      return result
    end
    _VERMEIL_V25_243_orig_ground_entries_for_cell(tx, ty, entries)
  rescue Exception
    []
  end

  # ---------------------------------------------------------------------------
  # Ground compositor fast path
  # ---------------------------------------------------------------------------
  # collect_cell_entries is already ordered native 0,1,2 followed by Maker
  # Studio's ext_layers_index_for(), which is sorted by layer id.  reject/select
  # preserve that ordering.  Sorting the same 1-4 entries again for every cell
  # therefore only allocated arrays and repeated comparisons.
  def blt_ground_cell(tx, ty, entries, target = @ground)
    return if !entries || entries.empty?
    dx = tx * Game_Map::TILE_WIDTH
    dy = ty * Game_Map::TILE_HEIGHT
    cell_idx = ty * @map.width + tx

    entries.each do |e|
      next if !e[:bitmap]
      blt_entry_into(target, dx, dy, e, e[:opacity] || 255)
      next if !e[:animated]

      filename = e[:filename]
      @autotile_cells[filename] ||= []
      seen_by_name = @v25_autotile_cell_seen
      if seen_by_name
        seen = seen_by_name[filename]
        next if seen[cell_idx]
        seen[cell_idx] = true
      else
        # Compatibility fallback if this method is called before build setup.
        pair = [tx, ty]
        next if @autotile_cells[filename].include?(pair)
      end
      @autotile_cells[filename] << [tx, ty]
    end
  end
end

# --- Blit directo al suelo (antes 038_V25GroundPlainBlit.rb) ---
# Entries without Maker Studio color effects are copied directly. This preserves
# exact pixels while avoiding baked_source() and its temporary [bitmap, rect]
# Array on the common path. Effect-bearing entries keep the original pipeline.
class Mode7Renderer
  private

  if private_method_defined?(:blt_entry_into) &&
     !private_method_defined?(:_VERMEIL_V25_2411_orig_blt_entry_into)
    alias_method :_VERMEIL_V25_2411_orig_blt_entry_into, :blt_entry_into
  end

  def blt_entry_into(dst, dx_px, y, entry, opacity = 255)
    state = entry[:v25_plain_blt]
    if state.nil?
      plain = !entry[:hue] && !entry[:saturation] && !entry[:lighting] &&
              !entry[:tone] && !entry[:color]
      state = plain ? 1 : 0
      entry[:v25_plain_blt] = state
    end

    if state == 1
      bitmap = entry[:bitmap]
      rect = entry[:src_rect]
      return dst.blt(dx_px, y, bitmap, rect, opacity) if bitmap && rect
    end

    return _VERMEIL_V25_2411_orig_blt_entry_into(dst, dx_px, y, entry, opacity)
  end
end

# --- Cache de fuentes estaticas (antes 041_V25StaticTileSourceCache.rb) ---
# Build-only optimization. Static tileset entries repeatedly resolve the same
# bitmap + source rectangle for the same tile ID. Cache that immutable source
# once per renderer build. Animated autotiles keep unique Rect instances because
# their frame rectangle is mutated at runtime.
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
    priority = resolve_tileset_priority_override(ts.id, tid, priority) if respond_to?(:resolve_tileset_priority_override, true)
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

  # Preserve exact autotile-entry shape while removing per-tile Bitmap.new and
  # string allocations from the build path.
  def make_native_entry(tid, layer)
    if tid < TilemapRenderer::TILESET_START_ID
      filename = autotile_name_for(tid)
      return nil if !filename || filename.empty?

      bmp = @autotiles[filename]
      return nil if !bmp

      animated = @autotiles.animated?(filename)
      if animated
        @scratch.filename = filename
        @autotiles.set_src_rect(@scratch, tid)
        src = @scratch.src_rect.clone
      else
        @v25_static_autotile_source_cache ||= {}
        key = [filename, tid]
        src = @v25_static_autotile_source_cache[key]
        if !src
          @scratch.filename = filename
          @autotiles.set_src_rect(@scratch, tid)
          r = @scratch.src_rect
          src = Rect.new(r.x, r.y, r.width, r.height)
          @v25_static_autotile_source_cache[key] = src
        end
      end

      p = @map.priorities[tid] || 0
      p = resolve_tileset_priority_override(@map.tileset_id, tid, p) if respond_to?(:resolve_tileset_priority_override, true)
      return {
        bitmap: bmp,
        src_rect: src,
        priority: p,
        animated: animated,
        filename: filename,
        tid: tid,
        unify: layer
      }
    end

    ts = $data_tilesets[@map.tileset_id]
    return nil if !ts
    p = @map.priorities[tid] || 0
    p = resolve_tileset_priority_override(ts.id, tid, p) if respond_to?(:resolve_tileset_priority_override, true)
    entry_from_tileset(ts, tid, p, layer)
  rescue Exception
    nil
  end
end
# >>> [VERMEIL] Visual 2.5D - 036_V25EntryBuildCache.rb
#===============================================================================
# [VERMEIL] Visual 2.5D - 036_V25EntryBuildCache.rb
# Phase 2.4.6 - build classification cache + numeric rigid-priority hot path
#
# Goal: keep Phase 2.4.3 visuals/ownership exactly, but stop re-running the
# same NDS category/priority predicates in every build pass.
#===============================================================================
class Mode7Renderer
  private

  V25F_FLOOR          = 0x0001 unless const_defined?(:V25F_FLOOR)
  V25F_WALL_PLANE     = 0x0002 unless const_defined?(:V25F_WALL_PLANE)
  V25F_ROOF_PLANE     = 0x0004 unless const_defined?(:V25F_ROOF_PLANE)
  V25F_PROTECTED_ROOF = 0x0008 unless const_defined?(:V25F_PROTECTED_ROOF)
  V25F_BILLBOARD      = 0x0010 unless const_defined?(:V25F_BILLBOARD)
  V25F_VOLUME         = 0x0020 unless const_defined?(:V25F_VOLUME)
  V25F_STAIR          = 0x0040 unless const_defined?(:V25F_STAIR)
  V25F_GROUND_BUSH    = 0x0080 unless const_defined?(:V25F_GROUND_BUSH)
  V25F_BORDER         = 0x0100 unless const_defined?(:V25F_BORDER)
  V25F_BLACK          = 0x0200 unless const_defined?(:V25F_BLACK)

  # Keep the final implementations available for pre-cache/fallback calls.
  {
    floor:          :nds_floor_entry?,
    wall_plane:     :nds_wall_plane_entry?,
    roof_plane:     :nds_roof_plane_entry?,
    protected_roof: :nds_protected_roof_entry?,
    billboard:      :nds_billboard_entry?,
    volume:         :nds_volume_entry?,
    stair:          :nds_stair_entry?,
    ground_bush:    :nds_ground_bush_entry?,
    visual_priority: :entry_visual_priority,
    priority_surface: :priority_surface_entry?
  }.each do |suffix, method_name|
    alias_name = "_VERMEIL_V25_246_orig_#{suffix}".to_sym
    if private_method_defined?(method_name) && !private_method_defined?(alias_name)
      alias_method alias_name, method_name
    end
  end

  # cache_visual_priorities is intentionally replaced, not wrapped: the base
  # method already walks every entry. We perform that same calculation and
  # prime the immutable classification data in the same pass.
  def cache_visual_priorities
    @v25_entry_index = {}
    indoor = Mode7.indoor_map?
    surface_enabled = Mode7::Config::PRIORITY_SURFACES
    surface_min = Mode7::Config::PRIORITY_SURFACE_MIN.to_i
    force_p1_ground = Mode7Renderer.debug_mode_force_priority_1_as_ground?

    floor_id      = Mode7::Config::NDS_FLOOR_TERRAIN_TAG
    wall_plane_id = Mode7::Config::NDS_WALL_PLANE_TERRAIN_TAG
    mountain_wall_plane_id = Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
    roof_plane_id = Mode7::Config::NDS_ROOF_PLANE_TERRAIN_TAG
    roof_id       = Mode7::Config::NDS_ROOF_TERRAIN_TAG
    roof_high_id  = Mode7::Config::NDS_ROOF_HIGH_TERRAIN_TAG
    billboard_id  = Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG
    structure_id  = Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG
    overlay_id    = Mode7::Config::NDS_OVERLAY_TERRAIN_TAG
    volume_id     = Mode7::Config::NDS_VOLUME_TERRAIN_TAG
    volume_hi_id  = Mode7::Config::NDS_VOLUME_HIGH_TERRAIN_TAG
    mountain_top_id = Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
    stair_id      = Mode7::Config::NDS_STAIR_TERRAIN_TAG

    @entry_cache.each do |position, entries|
      tx, ty = position
      idx = ty * @map.width + tx
      @v25_entry_index[idx] = entries
      cap = v25_cached_ground_cap(tx, ty)

      entries.each do |entry|
        own = entry[:priority].to_i
        visual = if defined?(Mode7::Config::PRIORITY_VISUAL_HEIGHT_ENABLED) && Mode7::Config::PRIORITY_VISUAL_HEIGHT_ENABLED
                   own
                 else
                   own >= 1 && entry[:unify].to_i > cap ? own : 0
                 end
        entry[:visual_priority] = visual

        id = nds_category_id(entry)
        flags = 0
        flags |= V25F_FLOOR if id == floor_id
        
        is_mountain_billboard = Mode7.nds_mountain_billboard?(@map_id) &&
                                (id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG ||
                                 id == mountain_wall_plane_id)

        flags |= V25F_WALL_PLANE if id == wall_plane_id || (id == mountain_wall_plane_id && !is_mountain_billboard)
        flags |= V25F_ROOF_PLANE if id == roof_plane_id
        protected_roof = (id == roof_id || id == roof_high_id)
        billboard = (id == billboard_id || id == structure_id || id == overlay_id || is_mountain_billboard)
        volume = (id == volume_id || id == volume_hi_id || (id == mountain_top_id && !Mode7.nds_mountain_billboard?(@map_id)))
        flags |= V25F_PROTECTED_ROOF if protected_roof
        flags |= V25F_BILLBOARD if billboard
        flags |= V25F_VOLUME if volume
        flags |= V25F_STAIR if id == stair_id

        tag = terrain_tag_for_entry(entry)
        tag_id = tag && tag.id != :None ? tag.id : nil
        border = !!(tag_id && Mode7::Config::INTERIOR_BORDER_TERRAIN_TAGS.key?(tag_id))
        black = !!(indoor && tag_id && Mode7::Config::INDOOR_BLACK_TERRAIN_TAGS.key?(tag_id))
        flags |= V25F_BORDER if border
        flags |= V25F_BLACK if black

        # Ground-bush is the only flag that also depends on passage metadata.
        ground_bush = false
        if tag
          grass = tag.id == :Grass || tag.id == :TallGrass ||
                  (tag.respond_to?(:shows_grass_rustle) && tag.shows_grass_rustle) ||
                  (tag.respond_to?(:deep_bush) && tag.deep_bush)
          if grass
            passage = entry_shadow_passage(entry)
            ground_bush = !!(passage && (passage.to_i & 0x40) == 0x40)
          end
        end
        flags |= V25F_GROUND_BUSH if ground_bush
        entry[:v25_build_flags] = flags

        # Final entry_visual_priority semantics from 020_NDSTileCategories.
        vpriority = (billboard || protected_roof || (defined?(Mode7::Config::PRIORITY_VISUAL_HEIGHT_ENABLED) && Mode7::Config::PRIORITY_VISUAL_HEIGHT_ENABLED)) ? own : visual
        entry[:v25_visual_priority] = vpriority

        # Final priority_surface_entry? semantics for perspective/cylindrical.
        # Raster-affine retains the original dynamic method because indoor prop
        # ownership is resolved after this pass.
        if !Mode7.raster_affine_mode?
          priority_surface = false
          if (flags & (V25F_FLOOR | V25F_STAIR | V25F_GROUND_BUSH)) != 0
            priority_surface = false
          elsif (flags & (V25F_ROOF_PLANE | V25F_BILLBOARD | V25F_PROTECTED_ROOF)) != 0
            priority_surface = true
          elsif !surface_enabled || border || black
            priority_surface = false
          elsif entry_terrain_tag_height(entry).to_f > 0.0
            priority_surface = true
          elsif vpriority < surface_min
            priority_surface = false
          elsif vpriority == 1 && force_p1_ground
            priority_surface = false
          else
            priority_surface = true
          end
          entry[:v25_priority_surface] = priority_surface

          rigid_tag = v25_rigid_ground_tag?(id)
          entry[:v25_ground_static_excluded] =
            rigid_tag || volume || priority_surface
        end

        # Reused by rigid object-key/contiguity calculations.
        entry[:v25_explicit_elevation] =
          (entry.key?(:elevation) && !entry[:elevation].nil? ? entry[:elevation].to_f : 0.0).round(4)
        entry[:v25_rigid_source_key] = rigid_priority_source_key(entry)
      end
    end
  end

  def v25_build_flag?(entry, mask)
    flags = entry[:v25_build_flags]
    !flags.nil? && (flags & mask) != 0
  end

  def nds_floor_entry?(entry)
    return v25_build_flag?(entry, V25F_FLOOR) if entry.key?(:v25_build_flags)
    _VERMEIL_V25_246_orig_floor(entry)
  end

  def nds_wall_plane_entry?(entry)
    return v25_build_flag?(entry, V25F_WALL_PLANE) if entry.key?(:v25_build_flags)
    _VERMEIL_V25_246_orig_wall_plane(entry)
  end

  def nds_roof_plane_entry?(entry)
    return v25_build_flag?(entry, V25F_ROOF_PLANE) if entry.key?(:v25_build_flags)
    _VERMEIL_V25_246_orig_roof_plane(entry)
  end

  def nds_protected_roof_entry?(entry)
    return v25_build_flag?(entry, V25F_PROTECTED_ROOF) if entry.key?(:v25_build_flags)
    _VERMEIL_V25_246_orig_protected_roof(entry)
  end

  def nds_billboard_entry?(entry)
    return v25_build_flag?(entry, V25F_BILLBOARD) if entry.key?(:v25_build_flags)
    _VERMEIL_V25_246_orig_billboard(entry)
  end

  def nds_volume_entry?(entry)
    return v25_build_flag?(entry, V25F_VOLUME) if entry.key?(:v25_build_flags)
    _VERMEIL_V25_246_orig_volume(entry)
  end

  def nds_stair_entry?(entry)
    return v25_build_flag?(entry, V25F_STAIR) if entry.key?(:v25_build_flags)
    _VERMEIL_V25_246_orig_stair(entry)
  end

  def nds_ground_bush_entry?(entry)
    return v25_build_flag?(entry, V25F_GROUND_BUSH) if entry.key?(:v25_build_flags)
    _VERMEIL_V25_246_orig_ground_bush(entry)
  end

  def entry_visual_priority(entry)
    return entry[:v25_visual_priority].to_i if entry.key?(:v25_visual_priority)
    _VERMEIL_V25_246_orig_visual_priority(entry)
  end

  def priority_surface_entry?(entry)
    if !Mode7.raster_affine_mode? && entry.key?(:v25_priority_surface)
      return !!entry[:v25_priority_surface]
    end
    _VERMEIL_V25_246_orig_priority_surface(entry)
  end

  # Ground is built after wall/indoor-prop ownership has been resolved. In
  # perspective/cylindrical mode all other exclusion decisions are immutable
  # and were already cached above.
  def ground_entries_for_cell(tx, ty, entries)
    if !Mode7.raster_affine_mode?
      cache = @v25_ground_entries_cache
      idx = ty * @map.width + tx
      return cache[idx] if cache && cache.key?(idx)
      result = entries.reject do |entry|
        wall_owned = @wall_visual_owned && @wall_visual_owned[entry.object_id]
        prop_owned = @indoor_prop_owned && @indoor_prop_owned[entry.object_id]
        wall_owned || prop_owned || !!entry[:v25_ground_static_excluded]
      end
      cache[idx] = result if cache
      return result
    end
    _VERMEIL_V25_243_orig_ground_entries_for_cell(tx, ty, entries)
  rescue Exception
    []
  end

  def v25_rigid_object_key_fast(tx, ty, entry)
    explicit = entry[:v25_explicit_elevation] || 0.0
    rect = entry[:src_rect]
    return [:single, entry.object_id, explicit] if !rect
    source = entry[:v25_rigid_source_key] || rigid_priority_source_key(entry)
    origin_x = tx * Game_Map::TILE_WIDTH  - rect.x.to_i
    origin_y = ty * Game_Map::TILE_HEIGHT - rect.y.to_i
    [:source_object, source, origin_x, origin_y, explicit]
  end

  def v25_rigid_contiguous_fast?(a, b, dx, dy)
    sa = a[:v25_rigid_source_key] || rigid_priority_source_key(a)
    sb = b[:v25_rigid_source_key] || rigid_priority_source_key(b)
    return false if sa != sb
    ra = a[:src_rect]
    rb = b[:src_rect]
    return false if !ra || !rb
    (rb.x - ra.x) == dx * Game_Map::TILE_WIDTH &&
      (rb.y - ra.y) == dy * Game_Map::TILE_HEIGHT
  rescue Exception
    false
  end

  if private_method_defined?(:rigid_priority_components) &&
     !private_method_defined?(:_VERMEIL_V25_246_orig_rigid_priority_components)
    alias_method :_VERMEIL_V25_246_orig_rigid_priority_components, :rigid_priority_components
  end

  # Same grouping/seed/P1-neighbor rules as Phase 2.4.3, but temporary cell
  # keys are numeric and classification lives on each entry instead of several
  # object_id Hashes. Array [x,y] keys are created only for final components.
  def rigid_priority_components
    return _VERMEIL_V25_246_orig_rigid_priority_components if Mode7.raster_affine_mode? && respond_to?(:_VERMEIL_V25_246_orig_rigid_priority_components, true)

    width = @map.width
    cells_index = @v25_entry_index
    if !cells_index
      cells_index = {}
      @entry_cache.each do |(tx, ty), entries|
        cells_index[ty * width + tx] = entries
      end
    end

    groups = Hash.new do |hash, key|
      hash[key] = { cells: Hash.new { |h, idx| h[idx] = [] }, has_seed: false, elevation: nil }
    end

    surface_min = Mode7::Config::PRIORITY_SURFACE_MIN.to_i
    rigid_min = Mode7::Config::PRIORITY_RIGID_MIN.to_i

    cells_index.each do |idx, entries|
      ty = idx / width
      tx = idx - ty * width
      # Object identity is source-origin + explicit elevation.

      has_volume = false
      has_wall_plane = false
      entries.each do |entry|
        flags = entry[:v25_build_flags].to_i
        has_volume ||= (flags & V25F_VOLUME) != 0
        has_wall_plane ||= (flags & V25F_WALL_PLANE) != 0
      end

      entries.each do |entry|
        flags = entry[:v25_build_flags].to_i
        candidate = true
        candidate = false if @nds_bush_cap_owned && @nds_bush_cap_owned[entry.object_id]
        candidate = false if (flags & (V25F_FLOOR | V25F_ROOF_PLANE | V25F_VOLUME | V25F_GROUND_BUSH)) != 0

        protected = (flags & (V25F_BILLBOARD | V25F_PROTECTED_ROOF)) != 0
        if candidate && !protected
          candidate = false if has_volume || has_wall_plane
          candidate = false if (flags & (V25F_BORDER | V25F_BLACK)) != 0
          candidate = false if @wall_visual_owned && @wall_visual_owned[entry.object_id]
          candidate = false if entry[:v25_visual_priority].to_i < surface_min
        end

        entry[:v25_rigid_candidate] = candidate
        next if !candidate

        priority = entry[:v25_visual_priority].to_i
        elevation = entry_world_elevation(entry).to_f
        key = v25_rigid_object_key_fast(tx, ty, entry)
        group = groups[key]
        group[:cells][idx].push(entry)
        group[:has_seed] = true if protected || priority >= rigid_min
        group[:elevation] = elevation if group[:elevation].nil? || elevation < group[:elevation]
      end
    end

    seed_groups = []
    groups.each_value { |group| seed_groups << group if group[:has_seed] }

    seed_groups.each do |group|
      group[:cells].each_value do |entries|
        entries.each { |entry| entry[:v25_rigid_claimed] = true }
      end
    end

    # Extend only one orthogonal row of P1, exactly as the existing algorithm.
    seed_groups.each do |group|
      initial_indices = group[:cells].keys
      initial_indices.each do |idx|
        source_entries = group[:cells][idx]
        ty = idx / width
        tx = idx - ty * width
        source_entries.each do |source_entry|
          # left
          if tx > 0
            v25_absorb_rigid_p1_neighbor(group, cells_index, idx - 1, source_entry, -1, 0)
          end
          # right
          if tx + 1 < width
            v25_absorb_rigid_p1_neighbor(group, cells_index, idx + 1, source_entry, 1, 0)
          end
          # up/down
          v25_absorb_rigid_p1_neighbor(group, cells_index, idx - width, source_entry, 0, -1) if ty > 0
          v25_absorb_rigid_p1_neighbor(group, cells_index, idx + width, source_entry, 0, 1) if ty + 1 < @map.height
        end
      end
    end

    output = []
    seed_groups.each do |group|
      numeric_cells = group[:cells]
      next if numeric_cells.empty?
      cells = {}
      numeric_cells.each do |idx, entries|
        ty = idx / width
        tx = idx - ty * width
        cells[[tx, ty]] = entries
      end
      elevation = group[:elevation] || 0.0
      if respond_to?(:nds_component_support_height, true)
        support = nds_component_support_height(cells).to_f
        elevation = support if support > elevation.to_f
      end
      output << [cells, elevation]
    end
    output
  end

  def v25_absorb_rigid_p1_neighbor(group, cells_index, neighbor_idx, source_entry, dx, dy)
    entries = cells_index[neighbor_idx]
    return if !entries || entries.empty?
    entries.each do |candidate|
      next if candidate[:v25_rigid_claimed]
      next if candidate[:v25_visual_priority].to_i != 1
      next if !candidate[:v25_rigid_candidate]
      next if !v25_rigid_contiguous_fast?(source_entry, candidate, dx, dy)
      group[:cells][neighbor_idx].push(candidate)
      candidate[:v25_rigid_claimed] = true
    end
  end
end
# >>> [VERMEIL] Visual 2.5D - 037_V25FusedEntryPrepass.rb
#===============================================================================
# [VERMEIL] Visual 2.5D - 037_V25FusedEntryPrepass.rb
# Phase 2.4.8 - single-scan entry preclassification
#
# Conserva el orden visual de 2.4.7.1:
#   entry cache -> surface geometry -> indoor projection -> terrain/priority.
# Durante el primer scan SOLO precalcula datos inmutables y la altura de celda
# en una estructura temporal. terrain_tag_height / v25_build_flags oficiales se
# publican despues de surface geometry e indoor detection, igual que 2.4.7.1.
#===============================================================================
class Mode7Renderer
  private

  # Mientras dura el build, reutilizar el TerrainTag exacto resuelto durante el
  # scan. Se elimina al terminar cache_visual_priorities para no retener refs.
  if private_method_defined?(:terrain_tag_for_entry) &&
     !private_method_defined?(:_VERMEIL_V25_248_orig_terrain_tag_for_entry)
    alias_method :_VERMEIL_V25_248_orig_terrain_tag_for_entry, :terrain_tag_for_entry
  end

  def terrain_tag_for_entry(entry)
    if entry.key?(:v25_pre_tag_ref)
      tag = entry[:v25_pre_tag_ref]
      return nil if tag == false
      return tag
    end
    _VERMEIL_V25_248_orig_terrain_tag_for_entry(entry)
  end

  # Fast native entry: authoritative Maker Studio index means a missing cell is
  # definitively "no props", avoiding another public accessor call.
  def v25_make_native_entry_prepass(tx, ty, layer, idx)
    props = if @v25_native_props_authoritative
              v25_indexed_native_props(layer, idx)
            else
              v25_native_props_at(tx, ty, layer)
            end

    if props && (props["autotile_name"] || props["tileset_id"])
      return make_native_prop_entry(tx, ty, layer, props)
    end

    tid = @map.data[tx, ty, layer]
    return nil if !tid || tid <= 0
    entry = make_native_entry(tid, layer)
    return nil if !entry

    if props
      if defined?(MakerStudio) && MakerStudio.respond_to?(:resolve_band_priority)
        entry[:priority] = MakerStudio.resolve_band_priority(@map, tid, props)
      end
      stylize_entry(entry, props, layer)
      entry[:shadow_props] = props
    end
    entry[:tileset_id] ||= @map.tileset_id
    entry[:native_layer] = layer
    entry[:native_tile_id] = tid
    entry
  rescue Exception
    make_native_entry_with_props(tx, ty, layer)
  end

  # @v25_ext_cells_index ya contiene como maximo una tile por extended layer y
  # celda, y cada item tiene unify distinto. append_entry/seen no puede eliminar
  # nada en esta ruta, asi que evitamos Hash+Arrays temporales por celda.
  def v25_append_extended_entries_prepass(idx, entries)
    items = @v25_ext_cells_index[idx]
    return if !items || items.empty?

    items.each do |item|
      layer, td, ul = item
      next if !layer || !td
      next if layer.key?("visible") && !layer["visible"]

      tid = td["tile_id"].to_i
      priority = if defined?(MakerStudio) && MakerStudio.respond_to?(:resolve_band_priority)
                   MakerStudio.resolve_band_priority(@map, tid, td)
                 else
                   td["priority"].to_i
                 end
      entry = nil
      if td["autotile_name"]
        entry = make_ext_autotile_entry(td, priority, ul)
      elsif td["tileset_id"]
        ts = $data_tilesets[td["tileset_id"].to_i]
        entry = entry_from_tileset(ts, tid, priority, ul) if ts
      elsif tid > 0
        ts = $data_tilesets[@map.tileset_id]
        entry = entry_from_tileset(ts, tid, priority, ul) if ts
      end
      next if !entry

      stylize_entry(entry, td, ul)
      entry[:zoom_x] = layer["zoom_x"] || td["zoom_x"] || 1.0
      entry[:zoom_y] = layer["zoom_y"] || td["zoom_y"] || 1.0
      entry[:angle] = layer["angle"] || td["angle"] || 0.0
      entry[:mirror] = layer.key?("mirror") ? layer["mirror"] : (td.key?("mirror") ? td["mirror"] : false)
      entry[:ox] = layer["ox"] || td["ox"] || 0
      entry[:oy] = layer["oy"] || td["oy"] || 0
      entry[:blend_type] = layer["blend_type"] || td["blend_type"] || 0
      if layer["opacity"]
        entry[:opacity] = layer["opacity"].to_i
      elsif !entry[:opacity]
        entry[:opacity] = 255
      end
      entry[:elevation] = layer["elevation"].to_i if layer["elevation"]
      entries << entry
    end
  end

  def v25_collect_cell_entries_prepass(tx, ty, idx)
    # Current LBDS path: all extended data has already been inverted by cell.
    # Keep legacy collect_cell_entries untouched when the integration does not
    # expose that index.
    return collect_cell_entries(tx, ty) if @v25_ext_cells_index.nil?

    entries = []
    3.times do |layer|
      entry = v25_make_native_entry_prepass(tx, ty, layer, idx)
      entries << entry if entry
    end
    v25_append_extended_entries_prepass(idx, entries)
    entries
  end

  # Called by 003_TileDepth#build_v25_entry_cache. It creates the two cell
  # indexes AND computes immutable tag/category data in the same map scan.
  def v25_build_entry_cache_prepass
    @v25_entry_index = {}
    @v25_prepass_cells = []

    width = @map.width
    height = @map.height
    force_wall = Mode7Renderer.debug_mode_force_all_priority_wall?
    volume_enabled = Mode7::Config::NDS_VOLUME_ENABLED

    floor_id      = Mode7::Config::NDS_FLOOR_TERRAIN_TAG
    wall_plane_id = Mode7::Config::NDS_WALL_PLANE_TERRAIN_TAG
    mountain_wall_plane_id = Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
    roof_plane_id = Mode7::Config::NDS_ROOF_PLANE_TERRAIN_TAG
    roof_id       = Mode7::Config::NDS_ROOF_TERRAIN_TAG
    roof_high_id  = Mode7::Config::NDS_ROOF_HIGH_TERRAIN_TAG
    billboard_id  = Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG
    structure_id  = Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG
    overlay_id    = Mode7::Config::NDS_OVERLAY_TERRAIN_TAG
    volume_id     = Mode7::Config::NDS_VOLUME_TERRAIN_TAG
    volume_hi_id  = Mode7::Config::NDS_VOLUME_HIGH_TERRAIN_TAG
    mountain_top_id = Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
    stair_id      = Mode7::Config::NDS_STAIR_TERRAIN_TAG

    border_tags = Mode7::Config::INTERIOR_BORDER_TERRAIN_TAGS
    terrain_heights = Mode7::Config::TERRAIN_TAG_TILE_HEIGHT
    wall_heights = wall_terrain_tag_heights
    height_lut = {}

    height.times do |ty|
      row = ty * width
      width.times do |tx|
        idx = row + tx
        entries = v25_collect_cell_entries_prepass(tx, ty, idx)
        next if entries.empty?

        @entry_cache[[tx, ty]] = entries
        @v25_entry_index[idx] = entries

        cap = v25_cached_ground_cap(tx, ty)
        cell_height = 0
        has_wall = false

        entries.each do |entry|
          tag = _VERMEIL_V25_248_orig_terrain_tag_for_entry(entry)
          entry[:v25_pre_tag_ref] = tag || false
          tag_id = tag && tag.id != :None ? tag.id : nil
          entry[:nds_tag_id] = tag_id || false

          if tag_id
            h = height_lut[tag_id]
            if h.nil?
              h = 0
              if volume_enabled
                volume_h = Mode7.nds_volume_height_for_tag(tag_id).to_f
                h = volume_h.to_i if volume_h > 0.0
              end
              h = (terrain_heights[tag_id] || 0).to_i if h <= 0
              height_lut[tag_id] = h
            end
            cell_height = h if h > cell_height
          end

          border = !!(tag_id && border_tags.key?(tag_id))
          wall = false
          if !border
            configured = tag_id ? wall_heights[tag_id] : nil
            if !configured.nil?
              wall = configured.to_i > 0
            elsif force_wall && entry[:priority].to_i > 0
              wall = true
            end
          end
          has_wall ||= wall

          flags = 0
          flags |= V25F_FLOOR if tag_id == floor_id
          flags |= V25F_WALL_PLANE if tag_id == wall_plane_id || (tag_id == mountain_wall_plane_id && !Mode7.nds_mountain_billboard?(@map_id))
          flags |= V25F_ROOF_PLANE if tag_id == roof_plane_id
          protected_roof = (tag_id == roof_id || tag_id == roof_high_id)
          billboard = (tag_id == billboard_id || tag_id == structure_id || tag_id == overlay_id ||
                       (Mode7.nds_mountain_billboard?(@map_id) && (tag_id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG || tag_id == mountain_wall_plane_id)))
          volume = (tag_id == volume_id || tag_id == volume_hi_id || (tag_id == mountain_top_id && !Mode7.nds_mountain_billboard?(@map_id)))
          flags |= V25F_PROTECTED_ROOF if protected_roof
          flags |= V25F_BILLBOARD if billboard
          flags |= V25F_VOLUME if volume
          flags |= V25F_STAIR if tag_id == stair_id
          flags |= V25F_BORDER if border

          ground_bush = false
          if tag
            grass = tag.id == :Grass || tag.id == :TallGrass ||
                    (tag.respond_to?(:shows_grass_rustle) && tag.shows_grass_rustle) ||
                    (tag.respond_to?(:deep_bush) && tag.deep_bush)
            if grass
              passage = entry_shadow_passage(entry)
              ground_bush = !!(passage && (passage.to_i & 0x40) == 0x40)
            end
          end
          flags |= V25F_GROUND_BUSH if ground_bush
          entry[:v25_pre_flags] = flags

          own = entry[:priority].to_i
          visual = if defined?(Mode7::Config::PRIORITY_VISUAL_HEIGHT_ENABLED) && Mode7::Config::PRIORITY_VISUAL_HEIGHT_ENABLED
                     own
                   else
                     own >= 1 && entry[:unify].to_i > cap ? own : 0
                   end
          entry[:visual_priority] = visual
          entry[:v25_pre_visual_priority] = (billboard || protected_roof || (defined?(Mode7::Config::PRIORITY_VISUAL_HEIGHT_ENABLED) && Mode7::Config::PRIORITY_VISUAL_HEIGHT_ENABLED)) ? own : visual
          entry[:v25_pre_explicit_elevation] =
            (entry.key?(:elevation) && !entry[:elevation].nil? ? entry[:elevation].to_f : 0.0).round(4)
          entry[:v25_pre_rigid_source_key] = rigid_priority_source_key(entry)
        end

        cell_height = 0 if has_wall
        # Do NOT publish terrain_tag_height yet. build_nds_surface_geometry must
        # see the same state/order as 2.4.7.1.
        @v25_prepass_cells << [tx, ty, entries, cell_height]
      end
    end
    nil
  end

  # Height is published together with Priority after surface geometry and indoor
  # projection resolution, preserving the proven 2.4.7.1 order.
  def cache_terrain_tag_heights
    # intentionally fused into cache_visual_priorities
  end

  def cache_visual_priorities
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue nil

    indoor = Mode7.indoor_map?
    surface_enabled = Mode7::Config::PRIORITY_SURFACES
    surface_min = Mode7::Config::PRIORITY_SURFACE_MIN.to_i
    force_p1_ground = Mode7Renderer.debug_mode_force_priority_1_as_ground?
    black_tags = Mode7::Config::INDOOR_BLACK_TERRAIN_TAGS
    affine = Mode7.raster_affine_mode?

    cells = @v25_prepass_cells
    if !cells
      # Safety fallback should an external script call this method outside the
      # normal build lifecycle.
      cells = @entry_cache.map { |(tx, ty), entries| [tx, ty, entries, nil] }
    end

    cells.each do |cell|
      _tx, _ty, entries, pre_height = cell
      cell_height = pre_height
      if cell_height.nil?
        # Fallback only; normal 2.4.8 builds always carry pre_height.
        cell_height = 0
        entries.each do |entry|
          id = nds_category_id(entry)
          h = 0
          if id && Mode7::Config::NDS_VOLUME_ENABLED
            vh = Mode7.nds_volume_height_for_tag(id).to_f
            h = vh.to_i if vh > 0.0
          end
          h = (Mode7::Config::TERRAIN_TAG_TILE_HEIGHT[id] || 0).to_i if id && h <= 0
          cell_height = h if h > cell_height
        end
      end

      entries.each do |entry|
        entry[:terrain_tag_height] = cell_height

        id_cache = entry[:nds_tag_id]
        id = id_cache == false ? nil : id_cache
        flags = entry[:v25_pre_flags].to_i
        black = !!(indoor && id && black_tags.key?(id))
        flags |= V25F_BLACK if black
        entry[:v25_build_flags] = flags

        vpriority = entry[:v25_pre_visual_priority].to_i
        entry[:v25_visual_priority] = vpriority

        if !affine
          border = (flags & V25F_BORDER) != 0
          priority_surface = false
          if (flags & (V25F_FLOOR | V25F_STAIR | V25F_GROUND_BUSH)) != 0
            priority_surface = false
          elsif (flags & (V25F_ROOF_PLANE | V25F_BILLBOARD | V25F_PROTECTED_ROOF)) != 0
            priority_surface = true
          elsif !surface_enabled || border || black
            priority_surface = false
          elsif cell_height > 0
            priority_surface = true
          elsif vpriority < surface_min
            priority_surface = false
          elsif vpriority == 1 && force_p1_ground
            priority_surface = false
          else
            priority_surface = true
          end
          entry[:v25_priority_surface] = priority_surface

          volume = (flags & V25F_VOLUME) != 0
          rigid_tag = v25_rigid_ground_tag?(id)
          entry[:v25_ground_static_excluded] = rigid_tag || volume || priority_surface
        end

        entry[:v25_explicit_elevation] = entry.delete(:v25_pre_explicit_elevation) || 0.0
        entry[:v25_rigid_source_key] = entry.delete(:v25_pre_rigid_source_key) || rigid_priority_source_key(entry)
        entry.delete(:v25_pre_flags)
        entry.delete(:v25_pre_visual_priority)
        entry.delete(:v25_pre_tag_ref)
      end
    end

    @v25_prepass_cells = nil

    if t0
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0 rescue 0.0
      @nds_v513_profile ||= Hash.new(0.0)
      @nds_v513_profile[:cache_visual_priorities] += elapsed
    end
    nil
  end
end
