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
