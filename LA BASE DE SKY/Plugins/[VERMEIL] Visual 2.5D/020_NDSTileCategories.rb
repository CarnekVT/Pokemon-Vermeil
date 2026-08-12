#===============================================================================
# [VERMEIL] Visual 2.5D - 020_NDSTileCategories.rb
# V5.0 - Sistema visual NDS limpio por Terrain Tag y una sola camara.
#
# El renderer NO infiere geometria 3D desde Priority. Priority solo ordena Z.
# Cada Terrain Tag describe una funcion visual concreta:
#   19 NDSFloor        plano horizontal
#   20 NDSWall         pared/fachada vertical
#   21 NDSRoof         techo horizontal elevado (48 px)
#   22 NDSBillboard    arbol/prop rigido
#   23 NDSVolume       relieve/plataforma baja (altura runtime, 12 px default)
  #   24 NDSStructure    casa/estructura 2D completa, billboard de camara
#   25 NDSIndoorWall   pared indoor fija
#   26 NDSIndoorProp   prop indoor fijo
#   27 NDSIndoorBorder borde/plano indoor
#   28 NDSIndoorBlack  mascara negra indoor
#   29 NDSMountainTop  cima/meseta elevada (32 px)
#   30 NDSMountainWall cara de montana/acantilado
#   31 NDSRoofHigh     techo elevado alto (72 px)
#   32 NDSVolumeHigh   volumen alto (24 px)
#   33 NDSOverlay      copa/aleros/foreground como billboard de camara
#   34 NDSRoofPlane    techo/plataforma realmente horizontal (geometria)
#   35 NDSWallPlane    pared realmente vertical (quad)
#   36 NDSMountainWallPlane cara de montana realmente vertical
#===============================================================================

module Mode7
  class << self
    def nds_tag_id(entry, renderer = nil)
      return nil if !entry
      if renderer
        tag = renderer.send(:terrain_tag_for_entry, entry)
        return tag.id if tag && tag.respond_to?(:id) && tag.id != :None
      end
      nil
    rescue Exception
      nil
    end

    def nds_roof_height_for_tag(tag_id)
      case tag_id
      when Config::NDS_ROOF_TERRAIN_TAG
        Config::NDS_ROOF_HEIGHT.to_f
      when Config::NDS_ROOF_HIGH_TERRAIN_TAG
        Config::NDS_ROOF_HIGH_HEIGHT.to_f
      when Config::NDS_ROOF_PLANE_TERRAIN_TAG
        Config::NDS_ROOF_HEIGHT.to_f
      else
        0.0
      end
    end

    def nds_volume_height_for_tag(tag_id)
      case tag_id
      when Config::NDS_VOLUME_TERRAIN_TAG
        nds_volume_height.to_f
      when Config::NDS_VOLUME_HIGH_TERRAIN_TAG
        Config::NDS_VOLUME_HIGH_HEIGHT.to_f
      when Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
        Config::NDS_MOUNTAIN_HEIGHT.to_f
      else
        0.0
      end
    end

    def nds_rigid_scale_for_world_y(world_y, _kind = nil, elevation = 0.0)
      # ponytail: una escala para todas las categorias; separar solo si aparece
      # un asset con metadata de camara propia, no por Terrain Tag global.
      object_scale_for_world_y(world_y, elevation).to_f
    rescue Exception
      1.0
    end


    # Altura de la superficie caminable V4. Solo volumen/meseta; tejados no
    # elevan personajes porque son decoracion visual salvo que el mapa use otra
    # mecanica especifica.
    def nds_surface_height_at(x, y)
      return 0.0 if !$scene.is_a?(Scene_Map) || !$game_map
      renderer = $scene.instance_variable_get(:@map_renderer)
      return 0.0 if !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      cache = renderer.instance_variable_get(:@entry_cache)
      entries = cache && cache[[x.to_i, y.to_i]]
      return 0.0 if !entries || entries.empty?
      entries.map do |entry|
        tag = renderer.send(:terrain_tag_for_entry, entry)
        tag ? nds_volume_height_for_tag(tag.id) : 0.0
      end.max || 0.0
    rescue Exception
      0.0
    end

    def depth_z_at_elevation(wy, elevation = 0.0, priority = 0, bias = 0)
      sy = project_y(wy.to_f, elevation.to_f)
      return bias.to_i if sy.nil?
      p = priority.to_i
      sy += priority_screen_step(wy) * p if p > 0
      sy.round + bias.to_i
    end

    def nds_tile_category_help
      [
        _INTL("19 NDSFloor: suelo/decal horizontal. Priority no lo convierte en pared."),
        _INTL("20 NDSWall: fachada o muro vertical. 21 NDSRoof: techo a 48 px."),
        _INTL("22 NDSBillboard: arbol/prop rigido. 23 NDSVolume: grosor de terreno."),
        _INTL("24 NDSStructure: casa completa 2D; billboard anclado por su fila inferior."),
        _INTL("25 NDSIndoorWall / 26 NDSIndoorProp: categorias indoor principales."),
        _INTL("27 IndoorBorder, 28 IndoorBlack, 29 MountainTop, 30 MountainWall."),
        _INTL("31 RoofHigh, 32 VolumeHigh, 33 Overlay (copas/aleros/foreground)."),
        _INTL("34 RoofPlane / 35 WallPlane / 36 MountainWallPlane: geometria 3D real."),
        _INTL("V5: todos comparten camara/zoom. Usa Plane solo para superficies geometricas.")
      ]
    end

    def open_nds_tile_category_help
      nds_tile_category_help.each { |text| pbMessage(text) }
    end

    def nds_map_tag_audit
      return _INTL("Abre un mapa primero.") if !$scene.is_a?(Scene_Map)
      renderer = $scene.instance_variable_get(:@map_renderer)
      return _INTL("Renderer 2.5D no disponible.") if !renderer.is_a?(Mode7Renderer)
      cache = renderer.instance_variable_get(:@entry_cache) || {}
      counts = Hash.new(0)
      cache.each_value do |entries|
        entries.each do |entry|
          tag = renderer.send(:terrain_tag_for_entry, entry)
          counts[tag.id] += 1 if tag && tag.id != :None
        end
      end
      mapping = [
        [:NDSFloor,19], [:NDSWall,20], [:NDSRoof,21], [:NDSBillboard,22],
        [:NDSVolume,23], [:NDSStructure,24], [:NDSIndoorWall,25],
        [:NDSIndoorProp,26], [:NDSIndoorBorder,27], [:NDSIndoorBlack,28],
        [:NDSMountainTop,29], [:NDSMountainWall,30], [:NDSRoofHigh,31],
        [:NDSVolumeHigh,32], [:NDSOverlay,33], [:NDSRoofPlane,34],
        [:NDSWallPlane,35], [:NDSMountainWallPlane,36]
      ]
      mapping.map { |id,n| _INTL("{1} {2}: {3}", n, id.to_s, counts[id]) }.join("\n")
    rescue Exception => e
      _INTL("No se pudo auditar: {1}", e.message)
    end
  end
end

class Mode7Renderer
  private

  # ---------------------------------------------------------------------------
  # Clasificacion explicita
  # ---------------------------------------------------------------------------
  def nds_category_id(entry)
    if entry.key?(:nds_tag_id)
      cached = entry[:nds_tag_id]
      return nil if cached == false
      return cached
    end
    tag = terrain_tag_for_entry(entry)
    id = tag && tag.id != :None ? tag.id : nil
    entry[:nds_tag_id] = id || false
    id
  rescue Exception
    nil
  end

  def nds_floor_entry?(entry)
    nds_category_id(entry) == Mode7::Config::NDS_FLOOR_TERRAIN_TAG
  end

  def nds_wall_plane_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_WALL_PLANE_TERRAIN_TAG ||
      id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
  end

  def nds_wall_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_WALL_TERRAIN_TAG ||
      id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG ||
      id == Mode7::Config::NDS_WALL_PLANE_TERRAIN_TAG ||
      id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
  end

  def nds_mountain_wall_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG ||
      id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
  end

  def nds_roof_plane_entry?(entry)
    nds_category_id(entry) == Mode7::Config::NDS_ROOF_PLANE_TERRAIN_TAG
  end

  def nds_roof_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_ROOF_TERRAIN_TAG ||
      id == Mode7::Config::NDS_ROOF_HIGH_TERRAIN_TAG ||
      id == Mode7::Config::NDS_ROOF_PLANE_TERRAIN_TAG
  end

  def nds_protected_roof_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_ROOF_TERRAIN_TAG ||
      id == Mode7::Config::NDS_ROOF_HIGH_TERRAIN_TAG
  end

  def nds_structure_entry?(entry)
    nds_category_id(entry) == Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG
  end

  def nds_overlay_entry?(entry)
    nds_category_id(entry) == Mode7::Config::NDS_OVERLAY_TERRAIN_TAG
  end

  def nds_billboard_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG ||
      id == Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG ||
      id == Mode7::Config::NDS_OVERLAY_TERRAIN_TAG
  end

  def nds_volume_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_VOLUME_TERRAIN_TAG ||
      id == Mode7::Config::NDS_VOLUME_HIGH_TERRAIN_TAG ||
      id == Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
  end

  def nds_explicit_category_entry?(entry)
    id = nds_category_id(entry)
    [
      Mode7::Config::NDS_FLOOR_TERRAIN_TAG,
      Mode7::Config::NDS_WALL_TERRAIN_TAG,
      Mode7::Config::NDS_ROOF_TERRAIN_TAG,
      Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG,
      Mode7::Config::NDS_VOLUME_TERRAIN_TAG,
      Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG,
      Mode7::Config::NDS_INDOOR_WALL_TERRAIN_TAG,
      Mode7::Config::NDS_INDOOR_PROP_TERRAIN_TAG,
      Mode7::Config::NDS_INDOOR_BORDER_TERRAIN_TAG,
      Mode7::Config::NDS_INDOOR_BLACK_TERRAIN_TAG,
      Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG,
      Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG,
      Mode7::Config::NDS_ROOF_HIGH_TERRAIN_TAG,
      Mode7::Config::NDS_VOLUME_HIGH_TERRAIN_TAG,
      Mode7::Config::NDS_OVERLAY_TERRAIN_TAG,
      Mode7::Config::NDS_ROOF_PLANE_TERRAIN_TAG,
      Mode7::Config::NDS_WALL_PLANE_TERRAIN_TAG,
      Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
    ].include?(id)
  end

  # ---------------------------------------------------------------------------
  # Ownership visual: Priority ya no define forma geometrica.
  # ---------------------------------------------------------------------------
  if private_method_defined?(:entry_visual_priority) &&
     !private_method_defined?(:_VERMEIL_V5_orig_entry_visual_priority)
    alias_method :_VERMEIL_V5_orig_entry_visual_priority, :entry_visual_priority
  end

  def entry_visual_priority(entry)
    # Los tags rigidos son una declaracion explicita del mapper. Maker Studio no
    # puede convertir su P1/P2/P3/P4 en P0 por el ground cap de la celda.
    return entry[:priority].to_i if nds_billboard_entry?(entry) ||
                                    nds_protected_roof_entry?(entry)
    _VERMEIL_V5_orig_entry_visual_priority(entry)
  end

  if private_method_defined?(:priority_surface_entry?) &&
     !private_method_defined?(:_VERMEIL_V4_orig_priority_surface_entry)
    alias_method :_VERMEIL_V4_orig_priority_surface_entry, :priority_surface_entry?
  end

  def priority_surface_entry?(entry)
    return false if nds_floor_entry?(entry)
    return true if nds_roof_plane_entry?(entry)
    return true if nds_billboard_entry?(entry) || nds_protected_roof_entry?(entry)
    _VERMEIL_V4_orig_priority_surface_entry(entry)
  end

  if private_method_defined?(:rigid_priority_member_candidate?) &&
     !private_method_defined?(:_VERMEIL_V4_orig_rigid_member)
    alias_method :_VERMEIL_V4_orig_rigid_member, :rigid_priority_member_candidate?
  end

  def rigid_priority_member_candidate?(entries, entry)
    return false if nds_floor_entry?(entry) || nds_roof_plane_entry?(entry) || nds_volume_entry?(entry)
    return true if nds_billboard_entry?(entry) || nds_protected_roof_entry?(entry)
    # Una escalera/decal colocado sobre una meseta pertenece a la textura de la
    # superficie. Priority no puede extraerlo como objeto ni cambiar sus bounds.
    return false if entries.any? { |candidate| nds_volume_entry?(candidate) }
    # Lo mismo sobre una cara vertical: queda en su propia superficie/capa y no
    # entra en el componente del muro ni se convierte en billboard por P2+.
    return false if entries.any? { |candidate| nds_wall_plane_entry?(candidate) }
    _VERMEIL_V4_orig_rigid_member(entries, entry)
  end

  if private_method_defined?(:rigid_priority_seed?) &&
     !private_method_defined?(:_VERMEIL_V4_orig_rigid_seed)
    alias_method :_VERMEIL_V4_orig_rigid_seed, :rigid_priority_seed?
  end

  def rigid_priority_seed?(entries, entry)
    return true if nds_billboard_entry?(entry) || nds_protected_roof_entry?(entry)
    _VERMEIL_V4_orig_rigid_seed(entries, entry)
  end

  if private_method_defined?(:wall_extension_candidate?) &&
     !private_method_defined?(:_VERMEIL_V4_orig_wall_extension_candidate)
    alias_method :_VERMEIL_V4_orig_wall_extension_candidate, :wall_extension_candidate?
  end

  def wall_extension_candidate?(entries, entry)
    # Toda categoria explicita es una frontera. Evita absorber tejados, props o
    # montanas vecinas dentro de una fachada por simple continuidad de textura.
    return false if nds_explicit_category_entry?(entry)
    _VERMEIL_V4_orig_wall_extension_candidate(entries, entry)
  end

  if private_method_defined?(:wall_visual_entries) &&
     !private_method_defined?(:_VERMEIL_V5_orig_wall_visual_entries)
    alias_method :_VERMEIL_V5_orig_wall_visual_entries, :wall_visual_entries
  end

  def wall_visual_entries(entries)
    # Un WallPlane ya es una cara completa. Nada colocado en otra layer de su
    # celda puede incorporarse al bitmap vertical ni alterar sus bounds.
    plane_entries = entries.select { |entry| nds_wall_plane_entry?(entry) }
    return plane_entries if !plane_entries.empty?
    _VERMEIL_V5_orig_wall_visual_entries(entries)
  end

  if private_method_defined?(:wall_component_key) &&
     !private_method_defined?(:_VERMEIL_V5_orig_wall_component_key)
    alias_method :_VERMEIL_V5_orig_wall_component_key, :wall_component_key
  end

  def wall_component_key(tx, ty, entries)
    plane = entries.find { |entry| nds_wall_plane_entry?(entry) }
    if plane
      # Una fila contigua de cara 3D usa un solo quad, incluso si el tileset
      # repite el mismo tile central. Evita una junta/sprite por cada celda.
      return [:nds_wall_plane_row, nds_category_id(plane), ty, wall_source_key(plane)]
    end
    _VERMEIL_V5_orig_wall_component_key(tx, ty, entries)
  end

  # Altura por categoria, nunca por Priority.
  if private_method_defined?(:entry_terrain_tag_height) &&
     !private_method_defined?(:_VERMEIL_V4_orig_entry_tag_height)
    alias_method :_VERMEIL_V4_orig_entry_tag_height, :entry_terrain_tag_height
  end

  def entry_terrain_tag_height(entry)
    id = nds_category_id(entry)
    roof_h = Mode7.nds_roof_height_for_tag(id)
    return roof_h if roof_h > 0.0
    volume_h = Mode7.nds_volume_height_for_tag(id)
    return volume_h if volume_h > 0.0
    _VERMEIL_V4_orig_entry_tag_height(entry)
  end

  def nds_component_kind(component)
    ids = component.values.flatten.map { |e| nds_category_id(e) }.compact
    return :nds_structure if ids.include?(Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG)
    return :nds_overlay if ids.include?(Mode7::Config::NDS_OVERLAY_TERRAIN_TAG)
    return :nds_billboard if ids.include?(Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG)
    return :nds_roof_high if ids.include?(Mode7::Config::NDS_ROOF_HIGH_TERRAIN_TAG)
    return :nds_roof if ids.include?(Mode7::Config::NDS_ROOF_TERRAIN_TAG)
    return :nds_mountain_wall_plane if ids.include?(Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG)
    return :nds_wall_plane if ids.include?(Mode7::Config::NDS_WALL_PLANE_TERRAIN_TAG)
    return :nds_mountain_wall if ids.include?(Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG)
    return :nds_wall if ids.include?(Mode7::Config::NDS_WALL_TERRAIN_TAG)
    nil
  end

  # ---------------------------------------------------------------------------
  # Walls: una fachada explicita = un bloque. No se parte por P1/P2/P3/P4.
  # ---------------------------------------------------------------------------
  def build_wall_columns
    @entry_cache.each do |(tx, ty), entries|
      direct_walls = entries.select { |entry| entry_is_wall?(entry) }
      next if direct_walls.empty?
      blocking = direct_walls.select { |entry| entry_blocks_movement?(entry) }
      next if blocking.empty?
      @wall_cells[[tx, ty]] = true
    end

    wall_visual_components.each do |component|
      bounds = component.keys
      all_entries = component.values.flatten
      next if all_entries.empty?

      component_elevation = all_entries.map { |entry| entry_world_elevation(entry) }.min || 0.0
      depth_ty = bounds.map { |_tx, ty| ty }.max
      depth_wyb = (depth_ty + 1) * Game_Map::TILE_HEIGHT
      kind = nds_component_kind(component)

      if [:nds_wall, :nds_mountain_wall, :nds_wall_plane, :nds_mountain_wall_plane].include?(kind)
        priority = all_entries.map { |entry| entry_visual_priority(entry) }.max || 0
        unify = all_entries.map { |entry| entry[:unify].to_i }.min || 0
        make_rigid_component(component, component_elevation, bounds,
                             priority, unify, depth_wyb, kind)
        next
      end

      # ponytail: fallback legacy entero; metadata por pieza si hiciera falta.
      priority = all_entries.map { |entry| entry_visual_priority(entry) }.max || 0
      unify = all_entries.map { |entry| entry[:unify].to_i }.min || 0
      make_rigid_component(component, component_elevation, bounds,
                           priority, unify, depth_wyb, :wall_component)
    end
  rescue Exception => e
    Console.echo_error("2.5D V5 build walls: #{e.message}") if defined?(Console)
  end

  # ---------------------------------------------------------------------------
  # Billboards/estructuras/overlays: misma geometria, una mascara por Priority.
  # ---------------------------------------------------------------------------
  def build_rigid_priority_blocks
    @rigid_priority_owned = {}
    return if Mode7.respond_to?(:raster_affine_mode?) && Mode7.raster_affine_mode?

    rigid_priority_components.each do |component, elevation|
      bounds = component.keys
      all_entries = component.values.flatten
      next if all_entries.empty?

      component.each_value do |entries|
        entries.each { |entry| @rigid_priority_owned[entry.object_id] = true }
      end

      depth_ty = bounds.map { |_tx, ty| ty }.max
      depth_wyb = (depth_ty + 1) * Game_Map::TILE_HEIGHT
      kind = nds_component_kind(component)

      groups = Hash.new { |hash, priority| hash[priority] = {} }
      component.each do |position, entries|
        entries.each do |entry|
          priority = entry_visual_priority(entry)
          groups[priority][position] ||= []
          groups[priority][position].push(entry)
        end
      end

      # Todas las mascaras conservan bitmap, origen, pie, escala y bounds del
      # objeto completo. Solo cambia Z; por eso P4 vuelve a funcionar sin que
      # una copa/tejado se agrande, se encoja o se separe del resto.
      groups.each do |priority, group_cells|
        unify = group_cells.values.flatten.map { |entry| entry[:unify].to_i }.min || 0
        make_rigid_component(group_cells, elevation, bounds,
                             priority, unify, depth_wyb, kind || :component)
      end
    end
  rescue Exception => e
    Console.echo_error("2.5D V5 build rigid: #{e.message}") if defined?(Console)
  end

  # ---------------------------------------------------------------------------
  # Mesetas/volumenes: un unico plano superior por fila.
  # ---------------------------------------------------------------------------
  if private_method_defined?(:build_priority_surfaces) &&
     !private_method_defined?(:_VERMEIL_V5_orig_build_priority_surfaces)
    alias_method :_VERMEIL_V5_orig_build_priority_surfaces, :build_priority_surfaces
  end

  def nds_volume_surface_elevation(entries)
    volume = entries.select { |entry| nds_volume_entry?(entry) }
    return nil if volume.empty?
    volume.map { |entry| entry_world_elevation(entry).to_f }.max
  end

  def nds_elevated_surface_entries(entries, base_unify)
    entries.reject do |entry|
      entry[:unify].to_i < base_unify ||
        wall_visual_owned?(entry) || rigid_priority_owned?(entry) ||
        nds_wall_entry?(entry) || nds_billboard_entry?(entry) ||
        nds_protected_roof_entry?(entry) || nds_roof_plane_entry?(entry) ||
        interior_black_entry?(entry) || indoor_prop_owned?(entry)
    end
  end

  def nds_elevated_surface_owned?(entry)
    @nds_elevated_surface_owned && @nds_elevated_surface_owned[entry.object_id]
  end

  def build_priority_surfaces
    build_rigid_priority_blocks
    @nds_elevated_surface_owned = {}

    # El top y cualquier escalera/decal de sus layers forman una sola textura
    # proyectada. Priority solo decide el orden dentro de esa textura.
    elevated_rows = Hash.new { |hash, key| hash[key] = {} }
    @entry_cache.each do |(tx, ty), entries|
      elevation = nds_volume_surface_elevation(entries)
      next if elevation.nil? || elevation <= 0.0
      volume_entries = entries.select { |entry| nds_volume_entry?(entry) }
      base_unify = volume_entries.map { |entry| entry[:unify].to_i }.min || 0
      surface_entries = nds_elevated_surface_entries(entries, base_unify)
      next if surface_entries.empty?
      surface_entries.each do |entry|
        @nds_elevated_surface_owned[entry.object_id] = true
      end
      elevated_rows[[ty, elevation]][tx] = surface_entries
    end

    elevated_rows.each do |(ty, elevation), row|
      segment = {}
      previous = nil
      row.keys.sort.each do |tx|
        if previous && tx != previous + 1
          make_priority_strip(segment, ty, 0, -1, elevation)
          segment = {}
        end
        segment[tx] = row[tx]
        previous = tx
      end
      make_priority_strip(segment, ty, 0, -1, elevation) if !segment.empty?
    end

    strips = Hash.new { |hash, key| hash[key] = {} }
    @entry_cache.each do |(tx, ty), entries|
      entries.each do |entry|
        next if wall_visual_owned?(entry)
        next if rigid_priority_owned?(entry)
        next if nds_elevated_surface_owned?(entry)
        next if !priority_surface_entry?(entry)

        elevation = entry_world_elevation(entry)
        priority = entry_visual_priority(entry)
        priority = 1 if interior_border_entry?(entry) && priority < 1
        key = [entry[:unify].to_i, priority, ty, elevation]
        strips[key][tx] ||= []
        strips[key][tx].push(entry)
      end
    end

    strips.each do |(unify, priority, ty, elevation), row|
      segment = {}
      previous = nil
      row.keys.sort.each do |tx|
        if previous && tx != previous + 1
          make_priority_strip(segment, ty, priority, unify, elevation)
          segment = {}
        end
        segment[tx] = row[tx]
        previous = tx
      end
      make_priority_strip(segment, ty, priority, unify, elevation) if !segment.empty?
    end
  rescue Exception => e
    Console.echo_error("2.5D V5 build surfaces: #{e.message}") if defined?(Console)
    _VERMEIL_V5_orig_build_priority_surfaces
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :mode7_nds_tile_help, {
    "name"        => _INTL("Guia Terrain Tags NDS V5"),
    "parent"      => :main,
    "description" => _INTL("Muestra el esquema de Terrain Tags 19-36."),
    "effect"      => proc { Mode7.open_nds_tile_category_help }
  })
  MenuHandlers.add(:debug_menu, :mode7_nds_tile_audit, {
    "name"        => _INTL("Auditar Terrain Tags NDS V5"),
    "parent"      => :main,
    "description" => _INTL("Cuenta cuantos tiles de cada categoria usa el mapa actual."),
    "effect"      => proc { pbMessage(Mode7.nds_map_tag_audit) }
  })
end
