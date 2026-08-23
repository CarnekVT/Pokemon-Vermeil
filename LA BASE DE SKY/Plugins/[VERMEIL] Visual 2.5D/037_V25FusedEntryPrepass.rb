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
          flags |= V25F_WALL_PLANE if tag_id == wall_plane_id || tag_id == mountain_wall_plane_id
          flags |= V25F_ROOF_PLANE if tag_id == roof_plane_id
          protected_roof = (tag_id == roof_id || tag_id == roof_high_id)
          billboard = (tag_id == billboard_id || tag_id == structure_id || tag_id == overlay_id)
          volume = (tag_id == volume_id || tag_id == volume_hi_id || tag_id == mountain_top_id)
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
          visual = own >= 1 && entry[:unify].to_i > cap ? own : 0
          entry[:visual_priority] = visual
          entry[:v25_pre_visual_priority] = (billboard || protected_roof) ? own : visual
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
