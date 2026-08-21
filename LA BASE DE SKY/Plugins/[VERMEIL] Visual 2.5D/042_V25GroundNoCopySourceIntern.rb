#===============================================================================
# [VERMEIL] Visual 2.5D - 042_V25GroundNoCopySourceIntern.rb
# Phase 2.4.14 - ground no-copy + source-key interning
#
# Build-only allocation reduction. Visual/priority/collision semantics are
# unchanged.
#===============================================================================
class Mode7Renderer
  private

  # Reset tiny per-build identity caches together with the other V25 indexes.
  if private_method_defined?(:prepare_v25_maker_studio_indexes) &&
     !private_method_defined?(:_VERMEIL_V25_2414_orig_prepare_indexes)
    alias_method :_VERMEIL_V25_2414_orig_prepare_indexes, :prepare_v25_maker_studio_indexes
  end

  def prepare_v25_maker_studio_indexes
    _VERMEIL_V25_2414_orig_prepare_indexes if respond_to?(:_VERMEIL_V25_2414_orig_prepare_indexes, true)
    @v25_rigid_source_key_cache = {}
    @v25_wall_source_key_cache = {}
  end

  # The old methods allocated [:tileset,id] / [:autotile,name] Arrays every
  # time. The value is immutable identity, so one shared frozen key per source
  # is enough for the whole build.
  if private_method_defined?(:rigid_priority_source_key) &&
     !private_method_defined?(:_VERMEIL_V25_2414_orig_rigid_source_key)
    alias_method :_VERMEIL_V25_2414_orig_rigid_source_key, :rigid_priority_source_key
  end

  def rigid_priority_source_key(entry)
    cache = (@v25_rigid_source_key_cache ||= {})
    if entry[:tileset_id]
      id = entry[:tileset_id].to_i
      key = (id << 2) | 1
      return cache[key] ||= [:tileset, id].freeze
    end
    filename = entry[:filename]
    if filename && !filename.to_s.empty?
      name = filename.to_s
      key = [:autotile, name]
      return cache[key] ||= key.freeze
    end
    bmp = entry[:bitmap]
    id = bmp ? bmp.object_id : 0
    key = (id << 2) | 2
    cache[key] ||= [:bitmap, id].freeze
  rescue Exception
    _VERMEIL_V25_2414_orig_rigid_source_key(entry)
  end

  if private_method_defined?(:wall_source_key) &&
     !private_method_defined?(:_VERMEIL_V25_2414_orig_wall_source_key)
    alias_method :_VERMEIL_V25_2414_orig_wall_source_key, :wall_source_key
  end

  def wall_source_key(entry)
    cache = (@v25_wall_source_key_cache ||= {})
    if entry[:tileset_id]
      id = entry[:tileset_id].to_i
      key = (id << 2) | 1
      return cache[key] ||= [:tileset, id].freeze
    end
    filename = entry[:filename]
    if filename && !filename.to_s.empty?
      name = filename.to_s
      key = [:autotile, name]
      return cache[key] ||= key.freeze
    end
    bmp = entry[:bitmap]
    id = bmp ? bmp.object_id : 0
    key = (id << 2) | 2
    cache[key] ||= [:bitmap, id].freeze
  rescue Exception
    _VERMEIL_V25_2414_orig_wall_source_key(entry)
  end

  # Phase 2.4.6 cached the filtered ground Array per cell, but Array#reject
  # still allocated a new Array for every ordinary P0-only cell. Most cells do
  # not exclude anything, so safely reuse the immutable entry-list Array in
  # that case. A new Array is created only from the first real exclusion.
  if private_method_defined?(:ground_entries_for_cell) &&
     !private_method_defined?(:_VERMEIL_V25_2414_orig_ground_entries_for_cell)
    alias_method :_VERMEIL_V25_2414_orig_ground_entries_for_cell, :ground_entries_for_cell
  end

  def ground_entries_for_cell(tx, ty, entries)
    return _VERMEIL_V25_2414_orig_ground_entries_for_cell(tx, ty, entries) if Mode7.raster_affine_mode?

    cache = @v25_ground_entries_cache
    idx = ty * @map.width + tx
    return cache[idx] if cache && cache.key?(idx)
    return (cache[idx] = entries) if entries.empty? && cache
    return entries if entries.empty?

    filtered = nil
    len = entries.length
    i = 0
    while i < len
      entry = entries[i]
      wall_owned = @wall_visual_owned && @wall_visual_owned[entry.object_id]
      prop_owned = @indoor_prop_owned && @indoor_prop_owned[entry.object_id]
      excluded = wall_owned || prop_owned || !!entry[:v25_ground_static_excluded]

      if excluded
        if filtered.nil?
          filtered = []
          j = 0
          while j < i
            filtered << entries[j]
            j += 1
          end
        end
      elsif filtered
        filtered << entry
      end
      i += 1
    end

    result = filtered || entries
    cache[idx] = result if cache
    result
  rescue Exception
    _VERMEIL_V25_2414_orig_ground_entries_for_cell(tx, ty, entries)
  end
end
