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
      sx = x.to_i
      sy = y.to_i
      # Compatibilidad para llamadas discretas. La altura continua de una rampa
      # se resuelve en nds_surface_height_at_real(), usando el pie real del actor.
      stair_h = renderer.instance_variable_get(:@nds_stair_elevations)
      if stair_h && (value = stair_h[[sx, sy]])
        return value.to_f
      end
      cache = renderer.instance_variable_get(:@entry_cache)
      entries = cache && cache[[sx, sy]]
      return 0.0 if !entries || entries.empty?
      mountain = entries.any? do |entry|
        tag = renderer.send(:terrain_tag_for_entry, entry)
        tag && tag.id == Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
      end
      if mountain && renderer.respond_to?(:nds_mountain_height_at, true)
        return renderer.send(:nds_mountain_height_at, sx, sy).to_f
      end
      entries.map do |entry|
        tag = renderer.send(:terrain_tag_for_entry, entry)
        tag ? nds_volume_height_for_tag(tag.id) : 0.0
      end.max || 0.0
    rescue Exception
      0.0
    end

    # Altura de superficie en coordenadas de mundo (px). A diferencia de la API
    # discreta, una NDSStair interpola continuamente entre su borde sur y norte.
    # Esto evita el salto de prioridad/altura a mitad de una escalera de 1 tile.
    def nds_surface_height_at_real(world_x, world_y)
      return 0.0 if !$scene.is_a?(Scene_Map) || !$game_map
      renderer = $scene.instance_variable_get(:@map_renderer)
      return 0.0 if !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      wx = world_x.to_f
      wy = world_y.to_f
      ramps = renderer.instance_variable_get(:@nds_stair_ramps)
      if ramps
        ramps.each do |ramp|
          next if wx < ramp[:west_wx] - 0.001 || wx > ramp[:east_wx] + 0.001
          next if wy < ramp[:north_wy] - 0.001 || wy > ramp[:south_wy] + 0.001
          span = ramp[:south_wy] - ramp[:north_wy]
          next if span.abs <= 0.001
          t = ((ramp[:south_wy] - wy) / span).clamp(0.0, 1.0)
          return ramp[:south_z] + (ramp[:north_z] - ramp[:south_z]) * t
        end
      end
      tw = Game_Map::TILE_WIDTH.to_f
      th = Game_Map::TILE_HEIGHT.to_f
      tx = (wx / tw).floor
      # El pie de un personaje cae exactamente en el borde sur de su celda.
      ty = ((wy - 0.001) / th).floor
      nds_surface_height_at(tx, ty)
    rescue Exception
      0.0
    end

    # Orden fisico de sprites para perspective. La distancia real de camara es
    # la componente principal; Priority solo es un pequeno desempate local.
    # De esta forma P4 en Z=0 nunca puede saltar por encima de un actor/top que
    # se encuentra realmente a Z=32/64/96.
    def physical_depth_z(wy, elevation = 0.0, priority = 0, bias = 0)
      if perspective_mode? && respond_to?(:perspective_depth_for)
        depth = perspective_depth_for(wy.to_f, elevation.to_f)
        base = Config::PHYSICAL_DEPTH_Z_BASE.to_i
        scale = Config::PHYSICAL_DEPTH_Z_SCALE.to_f
        scale = 64.0 if scale <= 0.0
        pstep = Config::PRIORITY_DEPTH_BIAS_STEP.to_i
        return base - (depth * scale).round + priority.to_i * pstep + bias.to_i
      end

      sy = project_y(wy.to_f, elevation.to_f)
      return bias.to_i if sy.nil?
      # Incluso en Affine, Priority es solo un desempate local. Usar un paso de
      # fila completo volvia a permitir que P2/P4 ganara contra altura fisica.
      sy.round + priority.to_i * Config::PRIORITY_DEPTH_BIAS_STEP.to_i + bias.to_i
    end

    def depth_z_at_elevation(wy, elevation = 0.0, priority = 0, bias = 0)
      physical_depth_z(wy, elevation, priority, bias)
    end

    # Mantiene coherente el codigo legacy/volume faces que aun llama depth_z.
    def depth_z(wy, priority = 0, bias = 0)
      physical_depth_z(wy, 0.0, priority, bias)
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

# Maker Studio puede sustituir el tileset de una celda sin modificar las tablas
# nativas de Game_Map. Resolvemos bush/deep bush desde las mismas entries que ve
# el renderer para que la lógica y la imagen nunca consulten propiedades distintas.
module Mode7
  class << self
    def nds_effective_bush_state(map, x, y)
      return nil if !defined?(MakerStudio) || !$scene.is_a?(Scene_Map)
      renderer = $scene.instance_variable_get(:@map_renderer)
      return nil if !renderer.is_a?(Mode7Renderer) || renderer.disposed?
      return nil if renderer.instance_variable_get(:@map) != map
      cache = renderer.instance_variable_get(:@entry_cache)
      entries = cache && cache[[x.to_i, y.to_i]]
      return nil if !entries

      bush = false
      deep = false
      entries.reverse_each do |entry|
        passage = renderer.send(:entry_shadow_passage, entry)
        next if !passage || (passage.to_i & 0x40) != 0x40
        bush = true
        tag = renderer.send(:terrain_tag_for_entry, entry)
        deep = true if tag && tag.respond_to?(:deep_bush) && tag.deep_bush
      end
      [bush, deep]
    rescue Exception
      nil
    end
  end
end

class Game_Map
  alias_method :_VERMEIL_NDS_orig_bush?, :bush? unless method_defined?(:_VERMEIL_NDS_orig_bush?)
  alias_method :_VERMEIL_NDS_orig_deepBush?, :deepBush? unless method_defined?(:_VERMEIL_NDS_orig_deepBush?)

  def bush?(x, y)
    state = Mode7.nds_effective_bush_state(self, x, y)
    return state[0] if state
    _VERMEIL_NDS_orig_bush?(x, y)
  end

  def deepBush?(x, y)
    state = Mode7.nds_effective_bush_state(self, x, y)
    return state[1] if state
    _VERMEIL_NDS_orig_deepBush?(x, y)
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

  # Altura real de una meseta.
  #
  # V5.6 calculaba la altura POR CELDA mirando los MountainWall justo al sur.
  # En una meseta de varias filas, las celdas del borde sur veian 2/3 walls
  # mientras las filas interiores no veian ninguno. El mismo plateau terminaba
  # partido en escalones horizontales (32/64/96) aunque visualmente fuese una
  # unica cima.
  #
  # V5.7 resuelve primero connected-components de NDSMountainTop en map-space.
  # Todas las celdas de la misma meseta comparten una sola altura, tomada de la
  # mayor pila de MountainWall que existe bajo SU BORDE SUR.
  def nds_mountain_wall_cell?(tx, ty)
    return false if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    entries = @entry_cache[[tx, ty]] || []
    entries.any? do |entry|
      id = nds_category_id(entry)
      id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG ||
        id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
    end
  rescue Exception
    false
  end

  def nds_mountain_wall_entry_at(tx, ty)
    return nil if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    entries = @entry_cache[[tx, ty]] || []
    entries.reverse.find { |entry| nds_mountain_wall_entry?(entry) }
  rescue Exception
    nil
  end

  def nds_stair_cell?(tx, ty)
    return false if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    entries = @entry_cache[[tx, ty]] || []
    entries.any? { |entry| nds_stair_entry?(entry) }
  rescue Exception
    false
  end

  def nds_mountain_top_cell?(tx, ty)
    return false if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    entries = @entry_cache[[tx, ty]] || []
    entries.any? do |entry|
      nds_category_id(entry) == Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
    end
  rescue Exception
    false
  end

  def nds_build_mountain_height_cache
    @nds_mountain_height_cache = {}
    @nds_mountain_component_cache = {}
    @nds_mountain_wall_source_cache = {}
    @nds_mountain_height_cache_complete = false
    base = Mode7::Config::NDS_MOUNTAIN_HEIGHT.to_f
    base = 32.0 if base <= 0.0

    top_cells = {}
    @entry_cache.each do |(tx, ty), entries|
      if entries.any? { |entry| nds_category_id(entry) == Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG }
        top_cells[[tx, ty]] = true
      end
    end

    visited = {}
    component_id = 0
    top_cells.each_key do |start|
      next if visited[start]
      component = {}
      queue = [start]
      visited[start] = true

      until queue.empty?
        cx, cy = queue.shift
        component[[cx, cy]] = true
        [[cx - 1, cy], [cx + 1, cy], [cx, cy - 1], [cx, cy + 1]].each do |nx, ny|
          pos = [nx, ny]
          next if !top_cells[pos] || visited[pos]
          visited[pos] = true
          queue << pos
        end
      end

      # El borde sur aporta la ALTURA y el ARTE, pero no la geometria. Cada
      # componente MountainTop se convierte en un volumen unico; una forma en L
      # conserva su silueta porque las caras se generaran desde sus bordes.
      wall_levels = []
      wall_sources = []
      component.each_key do |cx, cy|
        next if component[[cx, cy + 1]]
        count = 0
        wy = cy + 1
        while wy < @map.height && nds_mountain_wall_cell?(cx, wy)
          wall_sources << nds_mountain_wall_entry_at(cx, wy) if count == 0
          count += 1
          wy += 1
        end
        wall_levels << count if count > 0
      end

      levels = wall_levels.empty? ? 1 : wall_levels.max
      levels = 1 if levels <= 0
      height = base * levels
      source = wall_sources.compact.first
      component_id += 1
      component.each_key do |pos|
        @nds_mountain_height_cache[pos] = height
        @nds_mountain_component_cache[pos] = component_id
        @nds_mountain_wall_source_cache[pos] = source if source
      end
    end

    @nds_mountain_height_cache_complete = true
  rescue Exception => e
    @nds_mountain_height_cache ||= {}
    @nds_mountain_height_cache_complete = true
    Console.echo_error("2.5D V5.7 mountain height cache: #{e.message}") if defined?(Console)
  end

  def nds_mountain_height_at(tx, ty)
    if !@nds_mountain_height_cache_complete
      nds_build_mountain_height_cache
    end
    key = [tx.to_i, ty.to_i]
    @nds_mountain_height_cache[key] || Mode7::Config::NDS_MOUNTAIN_HEIGHT.to_f
  rescue Exception
    Mode7::Config::NDS_MOUNTAIN_HEIGHT.to_f
  end

  def nds_mountain_component_id_at(tx, ty)
    nds_build_mountain_height_cache if !@nds_mountain_height_cache_complete
    (@nds_mountain_component_cache || {})[[tx.to_i, ty.to_i]]
  rescue Exception
    nil
  end

  # Fuente de pared para una cara generada. Primero busca la pila local justo
  # al sur de esta columna del top; si la entrada es una zona lateral/interior,
  # reutiliza la fachada representativa de la misma meseta.
  def nds_mountain_wall_source_for(tx, ty)
    cy = ty.to_i
    while cy < @map.height && nds_mountain_top_cell?(tx, cy)
      cy += 1
    end
    entry = nds_mountain_wall_entry_at(tx, cy)
    return entry if entry
    nds_build_mountain_height_cache if !@nds_mountain_height_cache_complete
    (@nds_mountain_wall_source_cache || {})[[tx.to_i, ty.to_i]]
  rescue Exception
    nil
  end

  def nds_component_support_height(component)
    return 0.0 if !component || component.empty?
    foot_ty = component.keys.map { |_tx, ty| ty }.max
    values = component.keys.filter_map do |tx, ty|
      next if ty != foot_ty
      nds_base_surface_height_at(tx, ty).to_f
    end
    values.empty? ? 0.0 : values.max
  rescue Exception
    0.0
  end

  # Altura de una celda sin considerar NDSStair. Se usa para conectar la rampa
  # con el terreno que tiene inmediatamente al norte/sur.
  def nds_base_surface_height_at(tx, ty)
    return 0.0 if tx < 0 || ty < 0 || tx >= @map.width || ty >= @map.height
    entries = @entry_cache[[tx, ty]] || []
    max_h = 0.0
    entries.each do |entry|
      id = nds_category_id(entry)
      next if id == Mode7::Config::NDS_STAIR_TERRAIN_TAG
      h = if id == Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
            nds_mountain_height_at(tx, ty)
          else
            Mode7.nds_volume_height_for_tag(id).to_f
          end
      max_h = h if h > max_h
    end
    max_h
  rescue Exception
    0.0
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

  def nds_mountain_face_plane_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG ||
      id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG
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

  # Grass/TallGrass permanece en el receptor. El bit bush controla solamente
  # la oclusion de la mitad inferior del personaje, no crea geometria vertical.
  def nds_ground_bush_entry?(entry)
    tag = terrain_tag_for_entry(entry)
    return false if !tag
    grass = tag.id == :Grass || tag.id == :TallGrass ||
            (tag.respond_to?(:shows_grass_rustle) && tag.shows_grass_rustle) ||
            (tag.respond_to?(:deep_bush) && tag.deep_bush)
    return false if !grass
    passage = entry_shadow_passage(entry)
    passage && (passage.to_i & 0x40) == 0x40
  rescue Exception
    false
  end

  def nds_bush_overlay_entry?(_entry)
    false
  end

  # Parte superior de hierba de 2 tiles: muchos tilesets ponen el pie con
  # Grass/TallGrass y la mitad superior como un tile P1 sin Terrain Tag justo
  # encima. Proyectar ese P1 como suelo lo separa hacia el horizonte. V5.8 lo
  # detecta por continuidad vertical del rect fuente y lo convierte en overlay
  # billboard anclado al pie de la hierba.
  def nds_bush_cap_pair?(cap, bush)
    return false if !cap || !bush
    return false if nds_category_id(cap)
    return false if cap[:priority].to_i <= 0
    return false if !nds_ground_bush_entry?(bush)
    return false if wall_source_key(cap) != wall_source_key(bush)
    a = cap[:src_rect]
    b = bush[:src_rect]
    return false if !a || !b
    a.x.to_i == b.x.to_i &&
      (b.y.to_i - a.y.to_i) == Game_Map::TILE_HEIGHT
  rescue Exception
    false
  end

  def cache_nds_bush_caps
    @nds_bush_cap_owned = {}
    @nds_bush_cap_specs = []

    @entry_cache.each do |(tx, ty), entries|
      entries.each do |cap|
        next if nds_category_id(cap)
        next if cap[:priority].to_i <= 0

        # Layout A: ambas mitades estan en la misma celda/capas.
        bush = entries.find { |candidate| nds_bush_cap_pair?(cap, candidate) }
        top_ty = ty - 1
        base_ty = ty

        # Layout B: la mitad superior esta realmente una celda al norte.
        if !bush
          below = @entry_cache[[tx, ty + 1]] || []
          bush = below.find { |candidate| nds_bush_cap_pair?(cap, candidate) }
          top_ty = ty
          base_ty = ty + 1
        end
        next if !bush

        @nds_bush_cap_owned[cap.object_id] = true
        elevation = nds_base_surface_height_at(tx, base_ty).to_f
        @nds_bush_cap_specs << {
          tx: tx, top_ty: top_ty, base_ty: base_ty, entry: cap,
          elevation: elevation, priority: cap[:priority].to_i,
          unify: cap[:unify].to_i
        }
      end
    end
    @nds_bush_cap_specs
  rescue Exception => e
    @nds_bush_cap_owned ||= {}
    @nds_bush_cap_specs ||= []
    Console.echo_error("2.5D V5.8 bush caps: #{e.message}") if defined?(Console)
    @nds_bush_cap_specs
  end

  def nds_bush_cap_owned?(entry)
    @nds_bush_cap_owned && @nds_bush_cap_owned[entry.object_id]
  end

  def build_nds_bush_cap_overlays
    specs = @nds_bush_cap_specs || []
    return if specs.empty?

    groups = Hash.new { |h, k| h[k] = [] }
    specs.each do |spec|
      key = [spec[:top_ty], spec[:base_ty], spec[:elevation].round(4),
             spec[:priority], spec[:unify]]
      groups[key] << spec
    end

    groups.each_value do |items|
      items.sort_by! { |spec| spec[:tx] }
      segment = []
      flush = proc do
        next if segment.empty?
        cells = {}
        bounds = []
        segment.each do |spec|
          cells[[spec[:tx], spec[:top_ty]]] = [spec[:entry]]
          bounds << [spec[:tx], spec[:top_ty]]
          bounds << [spec[:tx], spec[:base_ty]]
        end
        first = segment.first
        depth_wyb = (first[:base_ty] + 1) * Game_Map::TILE_HEIGHT
        sprite = make_rigid_component(cells, first[:elevation], bounds,
                                     first[:priority], first[:unify], depth_wyb,
                                     :nds_bush_overlay)
        if sprite
          sprite.instance_variable_set(:@nds_bush_base_ty, first[:base_ty])
        end
        segment.clear
      end

      previous_x = nil
      items.each do |spec|
        flush.call if previous_x && spec[:tx] != previous_x + 1
        segment << spec
        previous_x = spec[:tx]
      end
      flush.call
    end
  end

  def nds_volume_entry?(entry)
    id = nds_category_id(entry)
    id == Mode7::Config::NDS_VOLUME_TERRAIN_TAG ||
      id == Mode7::Config::NDS_VOLUME_HIGH_TERRAIN_TAG ||
      id == Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
  end

  def nds_stair_entry?(entry)
    nds_category_id(entry) == Mode7::Config::NDS_STAIR_TERRAIN_TAG
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
      Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG,
      Mode7::Config::NDS_STAIR_TERRAIN_TAG
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
    return false if nds_stair_entry?(entry)
    return false if nds_ground_bush_entry?(entry)
    return true if nds_roof_plane_entry?(entry)
    return true if nds_billboard_entry?(entry) || nds_protected_roof_entry?(entry)
    _VERMEIL_V4_orig_priority_surface_entry(entry)
  end

  if private_method_defined?(:rigid_priority_member_candidate?) &&
     !private_method_defined?(:_VERMEIL_V4_orig_rigid_member)
    alias_method :_VERMEIL_V4_orig_rigid_member, :rigid_priority_member_candidate?
  end

  def rigid_priority_member_candidate?(entries, entry)
    return false if nds_bush_cap_owned?(entry)
    return false if nds_floor_entry?(entry) || nds_roof_plane_entry?(entry) || nds_volume_entry?(entry)
    return false if nds_ground_bush_entry?(entry)
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
    return false if nds_bush_cap_owned?(entry)
    return false if nds_ground_bush_entry?(entry)
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
    # NDSStair abre fisicamente la fachada. Si debajo de la escalera existe un
    # MountainWall en otra layer, no puede seguir formando parte del bloque:
    # antes unia izquierda/derecha por detras de la rampa y aparecia como una
    # banda completa atravesando la entrada.
    has_stair = entries.any? { |entry| nds_stair_entry?(entry) }

    # Un WallPlane ya es una cara completa. Con escalera, se conserva cualquier
    # WallPlane generico pero se elimina MountainWallPlane de esa celda.
    plane_entries = entries.select { |entry| nds_wall_plane_entry?(entry) }
    if has_stair
      plane_entries.reject! do |entry|
        nds_category_id(entry) == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
      end
    end
    return plane_entries if !plane_entries.empty?

    # MountainWall normal ya es arte de fachada. Una celda ocupada por Stair es
    # el hueco real del acceso y por tanto no renderiza wall detras.
    if !has_stair
      mountain_entries = entries.select { |entry| nds_mountain_wall_entry?(entry) }
      return mountain_entries if !mountain_entries.empty?
    end

    # Si lo unico descartado era MountainWall bajo la escalera, no caer al
    # renderer legacy porque lo volveria a absorber mediante Priority/textura.
    if has_stair && entries.any? { |entry| nds_mountain_wall_entry?(entry) }
      return []
    end
    _VERMEIL_V5_orig_wall_visual_entries(entries)
  end

  if private_method_defined?(:wall_component_key) &&
     !private_method_defined?(:_VERMEIL_V5_orig_wall_component_key)
    alias_method :_VERMEIL_V5_orig_wall_component_key, :wall_component_key
  end

  def wall_component_key(tx, ty, entries)
    # MountainWall normal y MountainWallPlane describen la MISMA cara fisica.
    # Una pila vertical no se separa por fila, variante de tile ni tipo Plane:
    # todas las celdas ortogonalmente contiguas se colapsan sobre un solo plano
    # vertical. Esto elimina definitivamente el efecto de terrazas apiladas.
    mountain = entries.find { |entry| nds_mountain_wall_entry?(entry) }
    if mountain
      return [:nds_mountain_face, :auto]
    end

    plane = entries.find { |entry| nds_wall_plane_entry?(entry) }
    if plane
      plane_id = nds_category_id(plane)
      return [:nds_wall_plane_row, plane_id, ty, wall_source_key(plane)]
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
      # V5.10: MountainWall/MountainWallPlane son MATERIAL vertical, no una
      # casilla fisica delante de la meseta. Si los dejamos en @wall_cells la
      # colision queda 1..N tiles mas cerca que la cara 3D y el error crece con
      # la altura. La barrera real es ahora el cambio de altura del height grid.
      if Mode7::Config::NDS_MOUNTAIN_AUTO_FACES
        direct_walls = direct_walls.reject do |entry|
          id = nds_category_id(entry)
          id == Mode7::Config::NDS_MOUNTAIN_WALL_TERRAIN_TAG ||
            id == Mode7::Config::NDS_MOUNTAIN_WALL_PLANE_TERRAIN_TAG
        end
      end
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
        # V5.9: MountainWall es textura/metadata. La cara fisica se genera desde
        # MountainTop en 019, para que visual, colision y forma irregular usen
        # exactamente el mismo borde. Evita colapsar una L en un rectangulo.
        if Mode7::Config::NDS_MOUNTAIN_AUTO_FACES &&
           [:nds_mountain_wall, :nds_mountain_wall_plane].include?(kind)
          next
        end
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
  # Billboards/estructuras: una geometria por objeto; overlays especiales aun
  # pueden conservar mascaras por Priority cuando su funcion sea de foreground.
  # ---------------------------------------------------------------------------
  def nds_structure_components_compatible?(a, elev_a, b, elev_b)
    elev_a = [elev_a.to_f, nds_component_support_height(a)].max
    elev_b = [elev_b.to_f, nds_component_support_height(b)].max
    (elev_a - elev_b).abs <= 0.001
  end

  # NDSStructure se agrupa por continuidad EN EL MAPA, no por la posicion del
  # rect fuente en el tileset. Asi una casa partida en varias zonas del PNG pero
  # contigua en el mapa conserva un solo bitmap/ancla/escala.
  def nds_merge_structure_components(components)
    structures = []
    other = []
    components.each do |component, elevation|
      if nds_component_kind(component) == :nds_structure
        structures << [component, elevation]
      else
        other << [component, elevation]
      end
    end
    return components if structures.length <= 1

    pending = (0...structures.length).to_a
    merged = []
    until pending.empty?
      seed_i = pending.shift
      seed, seed_e = structures[seed_i]
      combined = {}
      seed.each { |pos, entries| combined[pos] = entries.dup }
      changed = true
      while changed
        changed = false
        pending.dup.each do |idx|
          candidate, candidate_e = structures[idx]
          next if !nds_structure_components_compatible?(combined, seed_e, candidate, candidate_e)
          touches = candidate.keys.any? do |x, y|
            combined.key?([x, y]) || combined.key?([x - 1, y]) ||
              combined.key?([x + 1, y]) || combined.key?([x, y - 1]) ||
              combined.key?([x, y + 1])
          end
          next if !touches
          candidate.each do |pos, entries|
            combined[pos] ||= []
            combined[pos].concat(entries)
          end
          pending.delete(idx)
          changed = true
        end
      end
      merged << [combined, seed_e]
    end
    other + merged
  end

  def nds_merge_billboard_rows(components)
    components = nds_merge_structure_components(components)
    rows = Hash.new { |hash, key| hash[key] = [] }
    output = []
    components.each do |component, elevation|
      bounds = component.keys
      kind = nds_component_kind(component)
      # Structures ya llegan unidas por connected-components en map-space. No
      # volver a inferir su identidad desde source rect/foot row.
      if kind == :nds_structure
        output << [component, elevation]
        next
      end
      if bounds.empty? || kind != :nds_billboard
        output << [component, elevation]
        next
      end
      min_tx = bounds.map { |tx, _ty| tx }.min
      max_tx = bounds.map { |tx, _ty| tx }.max
      foot_ty = bounds.map { |_tx, ty| ty }.max
      key = [kind, foot_ty, elevation.to_f.round(4)]
      rows[key] << [component, elevation, min_tx, max_tx]
    end

    rows.each_value do |items|
      current = nil
      items.sort_by { |item| item[2] }.each do |component, elevation, min_tx, max_tx|
        span = current ? [current[3], max_tx].max - current[2] + 1 : 0
        if current && min_tx <= current[3] + 1 && span <= 16
          component.each do |position, entries|
            current[0][position] ||= []
            current[0][position].concat(entries)
          end
          current[3] = [current[3], max_tx].max
        else
          output << [current[0], current[1]] if current
          copy = {}
          component.each { |position, entries| copy[position] = entries.dup }
          current = [copy, elevation, min_tx, max_tx]
        end
      end
      output << [current[0], current[1]] if current
    end
    output
  end

  def build_rigid_priority_blocks
    @rigid_priority_owned = {}
    return if Mode7.respond_to?(:raster_affine_mode?) && Mode7.raster_affine_mode?

    components = nds_merge_billboard_rows(rigid_priority_components)
    components.each do |component, elevation|
      bounds = component.keys
      all_entries = component.values.flatten
      next if all_entries.empty?

      component.each_value do |entries|
        entries.each { |entry| @rigid_priority_owned[entry.object_id] = true }
      end

      depth_ty = bounds.map { |_tx, ty| ty }.max
      depth_wyb = (depth_ty + 1) * Game_Map::TILE_HEIGHT
      kind = nds_component_kind(component)
      # Un objeto apoyado sobre MountainTop/Volume hereda la superficie bajo su
      # fila de apoyo. Antes el prop seguia en Z=0 aunque el suelo estuviera a
      # 32/64/96, porque solo se miraba la elevacion del propio tile grafico.
      support = nds_component_support_height(component)
      elevation = support if support > elevation.to_f

      # Un arbol o edificio es una sola malla vertical ordenada por su pie.
      # Separarlo por Priority duplicaba sprites y abria columnas entre piezas.
      if [:nds_billboard, :nds_structure].include?(kind)
        unify = all_entries.map { |entry| entry[:unify].to_i }.min || 0
        make_rigid_component(component, elevation, bounds,
                             0, unify, depth_wyb, kind)
        next
      end

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

  def nds_volume_surface_elevation(entries, tx = nil, ty = nil)
    # En mapas del Maker una cara puede solaparse una o dos filas con el top
    # que usa de respaldo. La cara gana la celda: si no, el top atraviesa el
    # muro y el plano vertical queda anclado dentro de la propia meseta.
    # Phase 2.4.10 keeps the exact rule but avoids any?/select/map temporaries.
    maximum = nil
    mountain_top_id = Mode7::Config::NDS_MOUNTAIN_TOP_TERRAIN_TAG
    entries.each do |entry|
      return nil if nds_mountain_face_plane_entry?(entry)
      next if !nds_volume_entry?(entry)
      id_cache = entry[:nds_tag_id]
      id = id_cache == false || id_cache.nil? ? nds_category_id(entry) : id_cache
      value = if id == mountain_top_id && !tx.nil? && !ty.nil?
                explicit = entry.key?(:elevation) && !entry[:elevation].nil? ? entry[:elevation].to_f : 0.0
                explicit + nds_mountain_height_at(tx, ty)
              else
                entry_world_elevation(entry).to_f
              end
      maximum = value if maximum.nil? || value > maximum
    end
    maximum
  end

  def nds_elevated_surface_entries(entries, base_unify)
    entries.reject do |entry|
      entry[:unify].to_i < base_unify ||
        wall_visual_owned?(entry) || rigid_priority_owned?(entry) ||
        nds_bush_cap_owned?(entry) ||
        nds_wall_entry?(entry) || nds_billboard_entry?(entry) ||
        nds_stair_entry?(entry) ||
        nds_protected_roof_entry?(entry) || nds_roof_plane_entry?(entry) ||
        interior_black_entry?(entry) || indoor_prop_owned?(entry)
    end
  end

  def nds_elevated_surface_owned?(entry)
    @nds_elevated_surface_owned && @nds_elevated_surface_owned[entry.object_id]
  end

  def build_priority_surfaces
    # Debe resolverse antes del extractor P2+ para que la mitad superior de la
    # hierba no sea reclamada como objeto generico.
    cache_nds_bush_caps
    build_rigid_priority_blocks
    build_nds_bush_cap_overlays
    @nds_elevated_surface_owned = {}

    # El top y sus decals planos forman una textura proyectada. Las escaleras
    # quedan fuera: pertenecen a una unica rampa inclinada y no se duplican.
    elevated_rows = Hash.new { |hash, key| hash[key] = {} }
    @entry_cache.each do |(tx, ty), entries|
      elevation = nds_volume_surface_elevation(entries, tx, ty)
      next if elevation.nil? || elevation <= 0.0
      base_unify = nil
      entries.each do |entry|
        next if !nds_volume_entry?(entry)
        unify = entry[:unify].to_i
        base_unify = unify if base_unify.nil? || unify < base_unify
      end
      base_unify ||= 0
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
        next if nds_bush_cap_owned?(entry)
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

    build_nds_stair_ramps
  rescue Exception => e
    Console.echo_error("2.5D V5 build surfaces: #{e.message}") if defined?(Console)
    _VERMEIL_V5_orig_build_priority_surfaces
  end

  # ---------------------------------------------------------------------------
  # Escaleras: cada region contigua de NDSStair es una sola rampa continua.
  # ---------------------------------------------------------------------------
  def build_nds_stair_ramps
    @nds_stair_elevations = {}
    @nds_stair_ramps = []
    stair_cells = {}
    @entry_cache.each do |(tx, ty), entries|
      if entries.any? { |entry| nds_stair_entry?(entry) }
        stair_cells[[tx, ty]] = true
      end
    end
    return if stair_cells.empty?

    visited = {}
    stair_cells.each do |(tx, ty), _flag|
      next if visited[[tx, ty]]
      region = {}
      queue = [[tx, ty]]
      visited[[tx, ty]] = true
      head = 0
      while head < queue.length
        cx, cy = queue[head]
        head += 1
        region[[cx, cy]] = true
        [[cx - 1, cy], [cx + 1, cy], [cx, cy - 1], [cx, cy + 1]].each do |nx, ny|
          if stair_cells[[nx, ny]] && !visited[[nx, ny]]
            visited[[nx, ny]] = true
            queue.push([nx, ny])
          end
        end
      end
      make_nds_stair_ramp(region)
    end
  rescue Exception => e
    Console.echo_error("2.5D V5 stairs build: #{e.message}") if defined?(Console)
  end

  def make_nds_stair_ramp(region)
    positions = region.keys
    return if positions.empty?

    xs = positions.map { |p| p[0] }
    ys = positions.map { |p| p[1] }
    min_tx = xs.min
    max_tx = xs.max
    min_ty = ys.min
    max_ty = ys.max
    tw = Game_Map::TILE_WIDTH.to_f
    th = Game_Map::TILE_HEIGHT.to_f

    # La rampa conecta las superficies reales que tiene al sur/norte. Si el
    # norte no esta elevado, conserva la subida NDS_STAIR_HEIGHT tradicional.
    south_samples = (min_tx..max_tx).map { |x| nds_base_surface_height_at(x, max_ty + 1) }
    north_samples = (min_tx..max_tx).map { |x| nds_base_surface_height_at(x, min_ty - 1) }
    south_z = south_samples.max || 0.0
    north_z = north_samples.max || 0.0
    if (north_z - south_z).abs <= 0.01
      north_z = south_z + Mode7::Config::NDS_STAIR_HEIGHT.to_f
    end

    north_wy = min_ty * th
    south_wy = (max_ty + 1) * th
    @nds_stair_ramps ||= []
    @nds_stair_ramps << {
      west_wx: min_tx * tw, east_wx: (max_tx + 1) * tw,
      north_wy: north_wy, south_wy: south_wy,
      north_z: north_z.to_f, south_z: south_z.to_f
    }

    @nds_stair_elevations ||= {}
    span = [south_wy - north_wy, 0.001].max
    region.each_key do |(x, ty)|
      # Valor discreto compatible con scripts externos: altura en el borde sur
      # de la celda. El personaje usa la API continua con su real_x/real_y.
      cell_south = (ty + 1) * th
      t = ((south_wy - cell_south) / span).clamp(0.0, 1.0)
      @nds_stair_elevations[[x, ty]] = south_z + (north_z - south_z) * t
    end

    cells = {}
    positions.each do |pos|
      entries = @entry_cache[pos] || []
      cells[pos] = entries.select { |entry| nds_stair_entry?(entry) }
    end
    depth_wy = south_wy
    sprite = make_rigid_component(cells, south_z, positions, 0, -1, depth_wy, :nds_stair)
    if sprite
      sprite.instance_variable_set(:@nds_stair_south_z, south_z.to_f)
      sprite.instance_variable_set(:@nds_stair_north_z, north_z.to_f)
    end
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
