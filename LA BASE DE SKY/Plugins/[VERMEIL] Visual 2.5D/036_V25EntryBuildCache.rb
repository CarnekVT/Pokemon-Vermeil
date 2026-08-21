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
        visual = own >= 1 && entry[:unify].to_i > cap ? own : 0
        entry[:visual_priority] = visual

        id = nds_category_id(entry)
        flags = 0
        flags |= V25F_FLOOR if id == floor_id
        flags |= V25F_WALL_PLANE if id == wall_plane_id || id == mountain_wall_plane_id
        flags |= V25F_ROOF_PLANE if id == roof_plane_id
        protected_roof = (id == roof_id || id == roof_high_id)
        billboard = (id == billboard_id || id == structure_id || id == overlay_id)
        volume = (id == volume_id || id == volume_hi_id || id == mountain_top_id)
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
        vpriority = (billboard || protected_roof) ? own : visual
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

  def v25_rigid_source_key_cached(entry)
    return entry[:v25_rigid_source_key] if entry.key?(:v25_rigid_source_key)
    key = rigid_priority_source_key(entry)
    entry[:v25_rigid_source_key] = key
    key
  end

  def v25_rigid_object_key_fast(tx, ty, entry)
    explicit = entry[:v25_explicit_elevation] || 0.0
    rect = entry[:src_rect]
    return [:single, entry.object_id, explicit] if !rect
    source = v25_rigid_source_key_cached(entry)
    origin_x = tx * Game_Map::TILE_WIDTH  - rect.x.to_i
    origin_y = ty * Game_Map::TILE_HEIGHT - rect.y.to_i
    [:source_object, source, origin_x, origin_y, explicit]
  end

  def v25_rigid_contiguous_fast?(a, b, dx, dy)
    sa = v25_rigid_source_key_cached(a)
    sb = v25_rigid_source_key_cached(b)
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
