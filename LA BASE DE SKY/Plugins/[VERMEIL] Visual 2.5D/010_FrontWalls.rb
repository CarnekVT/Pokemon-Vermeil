#===============================================================================
# [VERMEIL] Visual 2.5D - 010_FrontWalls.rb
# Phase 4.1 - SkyFlyer style surfaces / aspect-ratio fix
#
# Regla principal:
#   * Terrain Tag de muro  -> columna vertical real (billboard anclado al suelo)
#   * Priority > 0         -> superficie vertical de prioridad, NO altura fisica
#   * layer/unify          -> orden de dibujo, NO coordenada Z
#
# Esto evita el fallo anterior donde priority >= 2 se convertia en otra columna
# completa y donde la elevacion se obtenia del indice de layer.
#===============================================================================
class Mode7Renderer
  def self.debug_mode_force_all_priority_wall?
    @debug_mode_force_all_priority_wall ||= false
  end

  def self.debug_mode_force_all_priority_wall=(value)
    @debug_mode_force_all_priority_wall = value
    Mode7Renderer.invalidate_renderer_ground
  end

  def self.debug_mode_force_priority_1_as_ground?
    @debug_mode_force_priority_1_as_ground ||= false
  end

  def self.debug_mode_force_priority_1_as_ground=(value)
    @debug_mode_force_priority_1_as_ground = value
    Mode7Renderer.invalidate_renderer_ground
  end

  def self.invalidate_renderer_ground
    return if !Mode7.rendering_now?
    renderer = $scene.instance_variable_get(:@map_renderer)
    return if !renderer || !renderer.is_a?(Mode7Renderer) || renderer.disposed?
    renderer.invalidate_ground
  end

  private

  # ---------------------------------------------------------------------------
  # Clasificacion de tiles
  # ---------------------------------------------------------------------------
  # Maker Studio calcula una prioridad EFECTIVA por celda: un P0 en una capa
  # superior tapa las capas inferiores y anula su overhead. El 2.5D debe usar
  # exactamente esa banda; usar prioridad cruda hace que un P0/Mountain parezca
  # heredar el P1+ de un wall vecino.
  def cache_visual_priorities
    @entry_cache.each do |(tx, ty), entries|
      ground_cap = visual_ground_cap(tx, ty, entries)
      entries.each do |entry|
        priority = entry[:priority].to_i
        entry[:visual_priority] = priority > 0 && entry[:unify].to_i > ground_cap ? priority : 0
      end
    end
  end

  def visual_ground_cap(tx, ty, entries)
    if defined?(MakerStudio) && MakerStudio.respond_to?(:cell_ground_cap)
      return MakerStudio.cell_ground_cap(@map, tx, ty).to_i
    end
    # ponytail: fallback sin Maker Studio; cache local por celda, no indice global.
    caps = entries.select { |entry| entry[:priority].to_i == 0 }
                  .map { |entry| entry[:unify].to_i }
    caps.empty? ? -1 : caps.max
  rescue Exception
    -1
  end

  def entry_visual_priority(entry)
    return entry[:visual_priority].to_i if entry.key?(:visual_priority)
    entry[:priority].to_i
  end

  def wall_terrain_tag_heights
    return Mode7::Config::INDOOR_WALL_TERRAIN_TAG_HEIGHT if Mode7.indoor_map?
    Mode7::Config::OUTDOOR_WALL_TERRAIN_TAG_HEIGHT
  end

  # Borde de sala: superficie del piso. Un billboard comparte una sola base y
  # se despega de pasillos/zonas curvas; el tag evita que wall/prioridad lo tome.
  def interior_border_entry?(entry)
    tag = terrain_tag_for_entry(entry)
    return false if !tag || tag.id == :None
    Mode7::Config::INTERIOR_BORDER_TERRAIN_TAGS.key?(tag.id)
  end

  def elevated_wall_terrain_tag_heights
    Mode7::Config::ELEVATED_WALL_TERRAIN_TAG_HEIGHT
  end

  # ElevatedWall no es una cara vertical rigida. Mountains/escaleras ya traen
  # su relieve dibujado por tiles: conservar cada fila en su propia celda evita
  # que lift o curvatura separen una pieza del borde superior/inferior.
  def entry_is_elevated_wall?(entry)
    tag = terrain_tag_for_entry(entry)
    return false if !tag || tag.id == :None
    elevated_wall_terrain_tag_heights[tag.id].to_i > 0
  end

  def mountain_shadow_opacity_for(entries)
    return 0 if !@ms_shadow_env || !defined?(Mode7::Config::MOUNTAIN_SHADOW_TERRAIN_TAG_OPACITY)
    entries.map do |entry|
      tag = terrain_tag_for_entry(entry)
      next 0 if !tag || tag.id == :None
      (Mode7::Config::MOUNTAIN_SHADOW_TERRAIN_TAG_OPACITY[tag.id] || 0).to_i
    end.max || 0
  end

  def terrain_tag_for_entry(entry)
    if entry.key?(:terrain_tag)
      return GameData::TerrainTag.try_get(entry[:terrain_tag])
    end
    tid = entry[:tid]
    return nil if !tid || tid <= 0
    ts_id = entry[:tileset_id] || @map.tileset_id
    key = "#{tid}:#{ts_id}"
    return @terrain_tag_cache[key] if @terrain_tag_cache.key?(key)

    ts = $data_tilesets[ts_id]
    if !ts || !ts.terrain_tags
      @terrain_tag_cache[key] = nil
      return nil
    end

    tag_index = tid
    if defined?(TilemapRenderer::TILESET_START_ID) && tid < TilemapRenderer::TILESET_START_ID
      tag_index = tid / 48
    elsif tid < 384
      tag_index = tid / 48
    end

    raw = ts.terrain_tags[tag_index]
    tag = nil
    if raw.is_a?(GameData::TerrainTag)
      tag = raw
    elsif raw
      tag = GameData::TerrainTag.try_get(raw)
    end

    @terrain_tag_cache[key] = tag
    tag
  rescue
    @terrain_tag_cache[key] = nil
    nil
  end

  # Un muro fisico se decide por Terrain Tag. Priority NO significa altura.
  def entry_is_wall?(e)
    return false if interior_border_entry?(e)
    tag = terrain_tag_for_entry(e)
    if tag && tag.id != :None
      configured = wall_terrain_tag_heights[tag.id]
      return configured.to_i > 0 if !configured.nil?
      configured = elevated_wall_terrain_tag_heights[tag.id]
      return configured.to_i > 0 if !configured.nil?
    end
    return true if Mode7Renderer.debug_mode_force_all_priority_wall? && e[:priority].to_i > 0
    false
  end

  # Solo los muros normales fuerzan bloqueo. ElevatedWall usa la pasabilidad
  # nativa de la escalera/suelo y puede disparar camera lift al pisarlo.
  def entry_blocks_movement?(e)
    return false if interior_border_entry?(e)
    tag = terrain_tag_for_entry(e)
    if tag && tag.id != :None
      configured = wall_terrain_tag_heights[tag.id]
      return configured.to_i > 0 if !configured.nil?
    end
    return true if Mode7Renderer.debug_mode_force_all_priority_wall? && e[:priority].to_i > 0
    false
  end

  def entry_hybrid_priority(e)
    tag = terrain_tag_for_entry(e)
    return nil if !tag || tag.id == :None
    Mode7::Config::HYBRID_PRIORITY_TERRAIN_TAGS[tag.id]
  end

  def entry_hybrid_height(e)
    tag = terrain_tag_for_entry(e)
    return 0 if !tag || tag.id == :None
    (Mode7::Config::HYBRID_PRIORITY_TERRAIN_TAG_HEIGHT[tag.id] || 0).to_i
  end

  def configured_terrain_tag_height(e)
    tag = terrain_tag_for_entry(e)
    return 0 if !tag || tag.id == :None
    (Mode7::Config::TERRAIN_TAG_TILE_HEIGHT[tag.id] || 0).to_i
  end

  # Un terrain tag de altura eleva la celda completa. Asi props, overlay y
  # prioridad sobre una montana conservan la misma base visual.
  def cache_terrain_tag_heights
    @entry_cache.each_value do |entries|
      height = entries.map { |entry| configured_terrain_tag_height(entry) }.max || 0
      wall_cell = entries.any? { |entry| entry_is_wall?(entry) }
      height = 0 if wall_cell
      entries.each do |entry|
        entry[:terrain_tag_height] = height
        entry[:terrain_height_wall_cell] = true if wall_cell
      end
    end
  end

  def entry_terrain_tag_height(e)
    return e[:terrain_tag_height].to_i if e.key?(:terrain_tag_height)
    configured_terrain_tag_height(e)
  end

  def hybrid_priority_active?(priority, tx, ty)
    return false if !priority || priority.to_i <= 0 || !$game_player
    return false if $game_player.x == tx && $game_player.y == ty
    $game_player.y < ty
  end

  def hybrid_row_priority_active?(priority, ty)
    return false if !priority || priority.to_i <= 0 || !$game_player
    $game_player.y < ty
  end

  def priority_surface_entry?(e)
    return false if !Mode7::Config::PRIORITY_SURFACES
    return false if interior_border_entry?(e)
    return false if entry_is_wall?(e)
    return true if entry_hybrid_priority(e)
    # Muros ya se dibujan como volumen. Promoverlos a priority surface los
    # saca de ese volumen y rompe capas vecinas/props superiores.
    return true if entry_terrain_tag_height(e) > 0 && !e[:terrain_height_wall_cell]
    p = entry_visual_priority(e)
    min = Mode7::Config::PRIORITY_SURFACE_MIN.to_i
    return false if p < min
    return false if p == 1 && Mode7Renderer.debug_mode_force_priority_1_as_ground?
    true
  end

  def cell_has_wall?(entries)
    entries.any? { |e| entry_is_wall?(e) }
  end

  def cell_has_blocking_wall?(entries)
    entries.any? { |e| entry_blocks_movement?(e) }
  end

  # Heuristica legacy. Phase 4 la deja disponible, pero Settings la desactiva:
  # una puerta con priority se representa mejor como priority surface que como
  # una columna inventada entre dos muros.
  def interior_connector_wall?(tx, ty, entries)
    return false if !Mode7::Config::INTERIOR_INFER_WALL_CONNECTORS
    return false if !Mode7.indoor_map?
    return false if entries.nil? || entries.none? { |e| e[:priority].to_i > 0 }

    left  = tx > 0 ? @entry_cache[[tx - 1, ty]] : nil
    right = tx + 1 < @map.width ? @entry_cache[[tx + 1, ty]] : nil
    up    = ty > 0 ? @entry_cache[[tx, ty - 1]] : nil
    down  = ty + 1 < @map.height ? @entry_cache[[tx, ty + 1]] : nil

    horizontal = left && right && cell_has_wall?(left) && cell_has_wall?(right)
    vertical   = up && down && cell_has_wall?(up) && cell_has_wall?(down)
    horizontal || vertical
  end

  def effective_cell_has_wall?(tx, ty, entries)
    return true if cell_has_wall?(entries)
    interior_connector_wall?(tx, ty, entries)
  end

  def effective_wall_layer_unify(tx, ty, entries)
    direct = entries.select { |e| entry_is_wall?(e) }
    return direct.map { |e| e[:unify].to_i }.min if !direct.empty?
    if interior_connector_wall?(tx, ty, entries)
      candidates = entries.select { |e| e[:priority].to_i > 0 }
      return candidates.map { |e| e[:unify].to_i }.min if !candidates.empty?
    end
    0
  end

  def wall_layer_unify(entries)
    vals = entries.select { |e| entry_is_wall?(e) }.map { |e| e[:unify].to_i }
    vals.empty? ? 0 : vals.min
  end

  def build_wall_columns
    # Solo un wall bloqueante puede ser pieza rigida P0/P1. Mountains y las
    # escaleras son ElevatedWall: conservan celda propia y no absorben vecinos.
    rigid_walls = Hash.new { |hash, key| hash[key] = {} }
    elevated_rows = Hash.new { |hash, key| hash[key] = {} }
    loose_bases = Hash.new { |hash, key| hash[key] = [] }
    loose_tops = Hash.new { |hash, key| hash[key] = [] }
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]
        direct_walls = entries.select { |entry| entry_is_wall?(entry) }
        next if direct_walls.empty?
        @wall_cells[[tx, ty]] = true if direct_walls.any? { |entry| entry_blocks_movement?(entry) }

        direct_walls.each do |entry|
          priority = entry_visual_priority(entry)
          if entry_is_elevated_wall?(entry)
            # ponytail: fila/celda, no malla. Una malla solo hace falta si Maker
            # Studio expone vertices de relieve para cada tile.
            key = [priority, entry[:unify].to_i, entry_world_elevation(entry)]
            elevated_rows[key][[tx, ty]] ||= []
            elevated_rows[key][[tx, ty]].push(entry)
          elsif entry_blocks_movement?(entry)
            tag = terrain_tag_for_entry(entry)
            key = [tag ? tag.id : :None, entry_world_elevation(entry)]
            rigid_walls[key][[tx, ty]] ||= []
            rigid_walls[key][[tx, ty]].push(entry)
          elsif priority <= 0
            loose_bases[[tx, ty]].push(entry)
          else
            loose_tops[[tx, ty]].push(entry)
          end
        end
      rescue Exception
        Console.echo_error("2.5D: columna fallida en (#{tx},#{ty})") if defined?(Console)
      end
    end
    elevated_rows.each do |(_priority, _unify, elevation), cells|
      make_cell_locked_priority_strips(cells, elevation,
                                       Mode7::Config::SKY_WALL_CURVE_RESPONSE)
    end
    rigid_walls.each do |(_tag_id, elevation), cells|
      used_base_entries = {}
      components, residual_priority = priority_wall_components(cells)
      components.each do |component|
        base_entries = component.values.flatten.select do |entry|
          entry_visual_priority(entry) <= 0
        end
        base_entries.each { |entry| used_base_entries[entry.object_id] = true }
        make_wall_component(component, elevation) if !base_entries.empty?
        make_wall_priority_component(component, elevation)
      end
      make_cell_locked_priority_strips(residual_priority, elevation,
                                       Mode7::Config::SKY_WALL_CURVE_RESPONSE)

      cells.each do |(tx, ty), cell_entries|
        base_entries = cell_entries.select do |entry|
          entry_visual_priority(entry) <= 0 && !used_base_entries[entry.object_id]
        end
        next if base_entries.empty?
        unify = base_entries.map { |entry| entry[:unify].to_i }.max || 0
        depth = [(ty + 1) * Game_Map::TILE_HEIGHT, 0, unify]
        make_wall_column(tx, ty, base_entries, unify, :dynamic, depth,
                         mountain_shadow_opacity_for(base_entries))
      end
    end
    loose_bases.each do |(tx, ty), entries|
      unify = entries.map { |entry| entry[:unify].to_i }.max || 0
      depth = [(ty + 1) * Game_Map::TILE_HEIGHT, 0, unify]
      make_wall_column(tx, ty, entries, unify, :dynamic, depth,
                       mountain_shadow_opacity_for(entries))
    end
    loose_tops.each do |(tx, ty), entries|
      entries.each do |entry|
        priority = entry_visual_priority(entry)
        depth = [(ty + 1) * Game_Map::TILE_HEIGHT, priority, entry[:unify].to_i]
        make_priority_surface(tx, ty, entry, depth, nil, true)
      end
    end
  end

  def build_priority_surfaces
    strips = Hash.new { |hash, key| hash[key] = {} }
    volumes = Hash.new { |hash, key| hash[key] = {} }
    @map.width.times do |tx|
      @map.height.times do |ty|
        @entry_cache[[tx, ty]].each do |entry|
          next if !priority_surface_entry?(entry)
          hybrid = entry_hybrid_priority(entry)
          if hybrid
            # Base p0 siempre. Copia pN se muestra por fila solo cuando el
            # jugador queda al norte; evita un sprite/reproyeccion por grass.
            elevation = entry_world_elevation(entry) + entry_hybrid_height(entry)
            base_key = [:hybrid_base, entry[:unify].to_i, 0, ty,
                        elevation]
            top_key = [:hybrid_top, entry[:unify].to_i, hybrid.to_i, ty,
                       elevation]
            strips[base_key][tx] ||= []
            strips[base_key][tx].push(entry)
            strips[top_key][tx] ||= []
            strips[top_key][tx].push(entry)
            next
          end
          # P1+ normal forma un objeto rigido. Juntar celdas vecinas evita que
          # cada parte se encoga/desplace por separado frente a su P0.
          key = [entry[:unify].to_i, entry_visual_priority(entry),
                 entry_world_elevation(entry)]
          volumes[key][[tx, ty]] ||= []
          volumes[key][[tx, ty]].push(entry)
        end
      end
    end
    strips.each do |(kind, unify, priority, ty, elevation), cells|
      hybrid_mode = kind == :normal ? nil : kind
      make_priority_strip(cells, ty, priority, unify, elevation, hybrid_mode)
    end
    volumes.each do |(_unify, _priority, elevation), cells|
      # P1+ conserva prioridad Z, pero su rectangulo visible vive en la misma
      # celda curva que el suelo. Un billboard grande era quien lo arrastraba.
      make_cell_locked_priority_strips(cells, elevation)
    end
  end

  # InteriorBorder es suelo visual, no wall. Nunca se agrupa: un borde puede
  # tocar suelo o decoracion con mismo terrain tag y un componente grande los
  # convertia en una sola pieza visual.
  def build_interior_border_surfaces
    @map.width.times do |tx|
      @map.height.times do |ty|
        @entry_cache[[tx, ty]].each do |entry|
          next if !interior_border_entry?(entry)
          depth = [(ty + 1) * Game_Map::TILE_HEIGHT, 0, entry[:unify].to_i]
          make_priority_surface(tx, ty, entry, depth, nil, true)
        end
      end
    end
  end

  # Agrupa solo vecinos ortogonales con mismo layer, prioridad y elevacion.
  # ponytail: sin ID manual; separar arte contiguo distinto requeriria metadata.
  def priority_volume_components(cells)
    pending = {}
    cells.each_key { |position| pending[position] = true }
    components = []
    until pending.empty?
      start = pending.keys.first
      pending.delete(start)
      stack = [start]
      component = {}
      until stack.empty?
        tx, ty = stack.pop
        position = [tx, ty]
        component[position] = cells[position]
        [[tx - 1, ty], [tx + 1, ty], [tx, ty - 1], [tx, ty + 1]].each do |neighbor|
          next if !pending.delete(neighbor)
          stack.push(neighbor)
        end
      end
      components.push(component)
    end
    components
  end

  # P1+ delimita objeto wall. P0 y cada banda P1-P4 comparten sus bounds: un
  # barril/techo multi-tile no puede separar su parte superior del soporte.
  def priority_wall_components(cells)
    cap_cells = {}
    cells.each do |position, entries|
      caps = entries.select { |entry| entry_visual_priority(entry) > 0 }
      cap_cells[position] = caps if !caps.empty?
    end
    return [[], priority_wall_entries(cells)] if cap_cells.empty?

    claimed_priority = {}
    components = priority_volume_components(cap_cells).map do |cap_component|
      component = {}
      cap_component.each do |position, entries|
        component[position] = entries.dup
        entries.each { |entry| claimed_priority[entry.object_id] = true }
        cells[position].each do |entry|
          next if entry_visual_priority(entry) > 1 || component[position].include?(entry)
          component[position].push(entry)
          claimed_priority[entry.object_id] = true if entry_visual_priority(entry) > 0
        end
      end

      xs = cap_component.keys.map { |tx, _ty| tx }
      ys = cap_component.keys.map { |_tx, ty| ty }
      min_tx = xs.min
      max_tx = xs.max
      min_ty = ys.min
      max_ty = ys.max
      support_rows = wall_component_height(cap_component)
      pending = cap_component.keys.dup
      visited = {}

      until pending.empty?
        tx, ty = pending.shift
        next if visited[[tx, ty]]
        visited[[tx, ty]] = true
        [[tx - 1, ty], [tx + 1, ty], [tx, ty - 1], [tx, ty + 1]].each do |nx, ny|
          next if nx < min_tx || nx > max_tx || ny < min_ty || ny > max_ty + support_rows
          entries = cells[[nx, ny]]
          next if !entries
          support_entries = entries.select { |entry| entry_visual_priority(entry) <= 1 }
          next if support_entries.empty?
          component[[nx, ny]] ||= []
          support_entries.each do |entry|
            next if component[[nx, ny]].include?(entry)
            component[[nx, ny]].push(entry)
            claimed_priority[entry.object_id] = true if entry_visual_priority(entry) > 0
          end
          pending.push([nx, ny])
        end
      end
      component
    end

    [components, priority_wall_entries(cells, claimed_priority)]
  end

  def priority_wall_entries(cells, claimed = nil)
    cells.each_with_object({}) do |(position, entries), result|
      remaining = entries.select do |entry|
        entry_visual_priority(entry) > 0 && (!claimed || !claimed[entry.object_id])
      end
      result[position] = remaining if !remaining.empty?
    end
  end

  # Cada fila de prioridad se escala entre sus dos bordes de mapa. P1/P4 nunca
  # comparte ancla vertical con fila vecina: perspectiva comprime dentro de la
  # casilla, no desplaza el tile entero sobre la camara.
  def make_cell_locked_priority_strips(cells, elevation, curve_response = 1.0)
    rows = Hash.new { |hash, key| hash[key] = {} }
    cells.each do |(tx, ty), entries|
      entries.each do |entry|
        key = [ty, entry_visual_priority(entry), entry[:unify].to_i]
        rows[key][tx] ||= []
        rows[key][tx].push(entry)
      end
    end
    rows.each do |(ty, priority, unify), row|
      segment = {}
      previous = nil
      row.keys.sort.each do |tx|
        if previous && tx != previous + 1
          make_priority_strip(segment, ty, priority, unify, elevation, nil,
                              curve_response)
          segment = {}
        end
        segment[tx] = row[tx]
        previous = tx
      end
      if !segment.empty?
        make_priority_strip(segment, ty, priority, unify, elevation, nil,
                            curve_response)
      end
    end
  end

  def wall_component_height(cells)
    height = cells.values.flatten.map do |entry|
      tag = terrain_tag_for_entry(entry)
      tag ? wall_terrain_tag_heights[tag.id].to_i : 0
    end.max || 0
    [height, 1].max
  end

  # ---------------------------------------------------------------------------
  # Altura fisica
  # ---------------------------------------------------------------------------
  # Desde Phase 4 el layer/unify NO genera altura. Solo una elevacion explicita
  # de Maker Studio mueve el tile sobre el eje Z.
  def entry_world_elevation(e)
    elevation = e.key?(:elevation) && !e[:elevation].nil? ? e[:elevation].to_f : 0.0
    elevation + entry_terrain_tag_height(e)
  end

  # Columna fisica de UNA celda. Forma original del volumen 2.5D: nunca usa
  # filas vecinas como alto, por eso no arrastra ni corta bloques al mover Y.
  def make_wall_column(tx, ty, entries, base_unify = 0, z_behavior = :dynamic,
                       depth = nil, surface_shadow_opacity = 0)
    return if entries.nil? || entries.empty?
    max_elev = entries.map { |entry| entry_world_elevation(entry) }.max || 0.0
    height = Game_Map::TILE_HEIGHT + [max_elev.ceil, 0].max
    bitmap = Bitmap.new(Game_Map::TILE_WIDTH, height)
    bitmap.clear
    draw_wall_column_source(bitmap, entries, tx, ty, surface_shadow_opacity)

    sprite = Sprite.new(@viewport)
    sprite.bitmap = bitmap
    sprite.ox = Game_Map::TILE_WIDTH / 2.0
    sprite.oy = height
    sprite.visible = false
    wx = tx * Game_Map::TILE_WIDTH + Game_Map::TILE_WIDTH / 2.0
    wyb = (ty + 1) * Game_Map::TILE_HEIGHT
    @wall_data.push([sprite, wx, wyb, height, entries, z_behavior, base_unify, depth,
                      surface_shadow_opacity])
  end

  # P0 y P1+ de un wall bloqueante comparten bounds y ancla. P1 se separa en
  # priority_data solo para su Z, no para volver a proyectar otra pieza.
  def make_wall_component(cells, elevation = 0)
    positions = cells.keys
    min_tx = positions.map { |tx, _ty| tx }.min
    max_tx = positions.map { |tx, _ty| tx }.max
    min_ty = positions.map { |_tx, ty| ty }.min
    max_ty = positions.map { |_tx, ty| ty }.max
    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
    height = (max_ty - min_ty + 1) * Game_Map::TILE_HEIGHT
    bitmap = Bitmap.new(width, height)
    draw_wall_component_base_source(bitmap, min_tx, min_ty, cells)

    sprite = Sprite.new(@viewport)
    sprite.bitmap = bitmap
    sprite.ox = width / 2.0
    sprite.oy = height
    sprite.visible = false
    wx = min_tx * Game_Map::TILE_WIDTH + width / 2.0
    wyb = (max_ty + 1) * Game_Map::TILE_HEIGHT
    unify = cells.values.flatten.map { |entry| entry[:unify].to_i }.min || 0
    depth = [wyb, 0, unify]
    @wall_data.push([sprite, wx, wyb, height, cells, :component, unify, depth,
                     0, min_tx, min_ty, max_tx, max_ty, elevation])
  end

  def draw_wall_component_base_source(dst, min_tx, min_ty, cells)
    dst.clear
    cells.keys.sort_by { |tx, ty| [ty, tx] }.each do |tx, ty|
      x = (tx - min_tx) * Game_Map::TILE_WIDTH
      y = (ty - min_ty) * Game_Map::TILE_HEIGHT
      cells[[tx, ty]].sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }.each do |entry|
        next if entry_visual_priority(entry) > 0
        blt_entry_into(dst, x, y, entry, entry[:opacity] || 255)
      end
    end
  end

  def draw_wall_column_source(dst, entries, tx = nil, ty = nil, surface_shadow_opacity = 0)
    sorted = entries.sort_by do |entry|
      [entry_world_elevation(entry), entry[:unify].to_i, entry[:priority].to_i]
    end
    return draw_wall_column_entries(dst, sorted) if surface_shadow_opacity.to_i <= 0
    base = sorted.select { |entry| entry_visual_priority(entry) <= 0 }
    top = sorted.reject { |entry| entry_visual_priority(entry) <= 0 }
    draw_wall_column_entries(dst, base)
    blt_mountain_surface_shadow(dst, tx, ty, base, surface_shadow_opacity)
    draw_wall_column_entries(dst, top)
  end

  def draw_wall_column_entries(dst, entries)
    entries.each do |entry|
      y = (dst.height - Game_Map::TILE_HEIGHT - entry_world_elevation(entry)).round
      y = 0 if y < 0
      blt_entry_into(dst, 0, y, entry, entry[:opacity] || 255)
    end
  end

  # Mountain tiene plano de sombra propio: misma silueta/offset/opacity de MS,
  # pero nunca encima de su source tile ni de piezas priority. Asi no invade
  # walls normales ni convierte sombra en una textura flotante.
  def blt_mountain_surface_shadow(dst, tx, ty, entries, opacity, dst_x = 0)
    return if tx.nil? || ty.nil? || !@shadow_ground || @shadow_ground.disposed?
    return if entries.any? { |entry| shadow_source_entry?(tx, ty, entry) }
    @src_rect.set(tx * Game_Map::TILE_WIDTH, ty * Game_Map::TILE_HEIGHT,
                  Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
    dst.blt(dst_x, dst.height - Game_Map::TILE_HEIGHT, @shadow_ground, @src_rect,
            opacity.to_i.clamp(0, 255))
  end

  # ---------------------------------------------------------------------------
  # Priority surfaces (equivalente 2.5D de los tiles con estrella de RMXP)
  # ---------------------------------------------------------------------------
  # Un strip contiene todos los tiles de una fila que comparten priority/layer.
  # RPG Maker calcula Z por fila de tile, no por tile individual: esta unidad
  # mantiene la prioridad real y evita crear/reproyectar cientos de sprites al
  # mover la camara verticalmente.
  def make_priority_strip(cells, ty, priority, unify, elevation, hybrid_mode = nil,
                          curve_response = 1.0)
    min_tx = cells.keys.min
    max_tx = cells.keys.max
    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
    source = Bitmap.new(width, Game_Map::TILE_HEIGHT)
    mountain_shadow = priority <= 0 && cells.values.flatten.any? do |entry|
      entry_is_elevated_wall?(entry) && mountain_shadow_opacity_for([entry]) > 0
    end
    draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow)

    sprite = Sprite.new(@viewport)
    sprite.bitmap = Bitmap.new(1, 1)
    sprite.ox = 0
    sprite.oy = 0
    sprite.visible = false
    @priority_strips.push([sprite, source, min_tx, ty, priority, unify,
                           elevation, nil, cells, hybrid_mode, nil,
                           curve_response, mountain_shadow])
  end

  def draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow = false)
    source.clear
    cells.each do |tx, entries|
      x = (tx - min_tx) * Game_Map::TILE_WIDTH
      sorted = entries.sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }
      if mountain_shadow
        base = sorted.select { |entry| entry_visual_priority(entry) <= 0 }
        top = sorted.reject { |entry| entry_visual_priority(entry) <= 0 }
        base.each do |entry|
          blt_entry_into(source, x, 0, entry, entry[:opacity] || 255)
        end
        opacity = mountain_shadow_opacity_for(base)
        blt_mountain_surface_shadow(source, tx, ty, base, opacity, x) if opacity > 0
        top.each do |entry|
          blt_entry_into(source, x, 0, entry, entry[:opacity] || 255)
        end
        next
      end
      sorted.each do |entry|
        blt_entry_into(source, x, 0, entry, entry[:opacity] || 255)
      end
    end
  end

  # P1-P4 usa source transparente del mismo rectangulo P0. Cada prioridad
  # conserva Z nativa, pero todas las piezas de un objeto usan mismo anclaje.
  def make_wall_priority_component(cells, elevation)
    bounds = cells.keys
    by_priority = Hash.new { |hash, key| hash[key] = {} }
    cells.each do |position, entries|
      entries.each do |entry|
        priority = entry_visual_priority(entry)
        next if priority <= 0
        key = [priority, entry[:unify].to_i]
        by_priority[key][position] ||= []
        by_priority[key][position].push(entry)
      end
    end
    by_priority.each do |(priority, unify), priority_cells|
      make_priority_volume(priority_cells, unify, priority, elevation, bounds,
                           Mode7::Config::SKY_WALL_COMPONENT_CURVE_RESPONSE,
                           true)
    end
  end

  def make_priority_volume(cells, unify, priority, elevation, bounds = nil,
                           curve_response = 0.0, wall_component = false)
    positions = bounds || cells.keys
    min_tx = positions.map { |tx, _ty| tx }.min
    max_tx = positions.map { |tx, _ty| tx }.max
    min_ty = positions.map { |_tx, ty| ty }.min
    max_ty = positions.map { |_tx, ty| ty }.max
    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
    height = (max_ty - min_ty + 1) * Game_Map::TILE_HEIGHT
    source = Bitmap.new(width, height)
    draw_priority_volume_source(source, min_tx, min_ty, cells)

    sprite = Sprite.new(@viewport)
    sprite.bitmap = source
    sprite.ox = source.width / 2.0
    sprite.oy = source.height
    sprite.visible = false
    wx = min_tx * Game_Map::TILE_WIDTH + source.width / 2.0
    wyb = (max_ty + 1) * Game_Map::TILE_HEIGHT
    depth = [wyb, priority, unify]
    @priority_data.push([sprite, wx, wyb, cells, priority, elevation, depth, nil,
                         min_tx, min_ty, source, nil, max_tx, max_ty,
                         curve_response, wall_component])
  end

  def draw_priority_volume_source(source, min_tx, min_ty, cells)
    source.clear
    cells.keys.sort_by { |tx, ty| [ty, tx] }.each do |tx, ty|
      x = (tx - min_tx) * Game_Map::TILE_WIDTH
      y = (ty - min_ty) * Game_Map::TILE_HEIGHT
      cells[[tx, ty]].sort_by do |entry|
        [entry[:unify].to_i, entry[:priority].to_i]
      end.each do |entry|
        blt_entry_into(source, x, y, entry, entry[:opacity] || 255)
      end
    end
  end

  def make_priority_surface(tx, ty, entry, depth = nil, hybrid_priority = nil, force = false)
    return if !force && !priority_surface_entry?(entry)

    source = Bitmap.new(Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
    source.clear
    blt_entry_into(source, 0, 0, entry, entry[:opacity] || 255)
    sprite = Sprite.new(@viewport)
    sprite.bitmap = source
    sprite.ox = source.width / 2.0
    sprite.oy = source.height
    sprite.visible = false
    wx = tx * Game_Map::TILE_WIDTH + Game_Map::TILE_WIDTH / 2.0
    wyb = (ty + 1) * Game_Map::TILE_HEIGHT
    @priority_data.push([sprite, wx, wyb, entry, entry_visual_priority(entry),
                         entry_world_elevation(entry), depth, hybrid_priority, tx, ty,
                         source, nil])
  end

  def redraw_projected_priority_surface(sprite, source, wx, wyb, elevation = 0,
                                        curve_response = 0.0, wall_component = false)
    return false if !source || source.disposed?
    projected = Mode7.project_billboard(wx, wyb, elevation)
    return false if !projected
    scale_x = Mode7.tile_billboard_scale_for_world_y(wyb)
    return false if !scale_x || scale_x <= 0
    if wall_component
      scale_y = wall_component_scale_y(wyb, source.height, elevation, scale_x)
    else
      response = curve_response.to_f.clamp(0.0, 1.0)
      scale_y = scale_x
      if response > 0.0
        top = Mode7.project_y(wyb - source.height, elevation)
        curve_scale = top ? (projected[1] - top) / source.height.to_f : scale_x
        curve_scale = scale_x if curve_scale <= 0.001
        scale_y += (curve_scale - scale_y) * response
      end
    end
    sprite.bitmap = source if sprite.bitmap != source
    sprite.ox = source.width / 2.0
    sprite.oy = source.height
    sprite.x = projected[0]
    sprite.y = projected[1]
    sprite.zoom_x = scale_x
    sprite.zoom_y = scale_y
    true
  end

  def priority_strip_projection(source, min_tx, ty, elevation = 0,
                                curve_response = 1.0)
    return false if !source || source.disposed?
    wy_top = ty * Game_Map::TILE_HEIGHT
    wy_bottom = wy_top + Game_Map::TILE_HEIGHT
    wy_middle = (wy_top + wy_bottom) / 2.0
    wx_left = min_tx * Game_Map::TILE_WIDTH
    wx_right = wx_left + source.width
    left = Mode7.project(wx_left, wy_middle, elevation)
    right = Mode7.project(wx_right, wy_middle, elevation)
    top = Mode7.project_y(wy_top, elevation)
    bottom = Mode7.project_y(wy_bottom, elevation)
    return false if !left || !right || !top || !bottom
    if curve_response.to_f < 1.0
      default_height = source.height * Mode7.tile_billboard_scale_for_world_y(wy_bottom)
      curved_extra = [bottom - top - default_height, 0.0].max
      height = default_height + curved_extra * curve_response.to_f.clamp(0.0, 1.0)
      # ponytail: solape de 1 px; malla vertical solo si renderer expone vertices.
      height += Mode7::Config::SKY_WALL_ROW_OVERLAP.to_f
      top = bottom - height
    end
    height = bottom - top
    width = right[0] - left[0]
    return false if height <= 0.001 || width <= 0.001
    [left[0], right[0], top, bottom]
  end

  def redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation = 0,
                                      curve_response = 1.0)
    projection = priority_strip_projection(source, min_tx, ty, elevation,
                                           curve_response)
    return false if !projection
    left, right, top, bottom = projection
    height = bottom - top
    return false if height <= 0.001
    sprite.bitmap = source if sprite.bitmap != source
    sprite.ox = source.width / 2.0
    sprite.oy = source.height
    sprite.x = (left + right) / 2.0
    sprite.y = bottom
    sprite.zoom_x = (right - left) / source.width.to_f
    sprite.zoom_y = height / source.height.to_f
    true
  end

  def update_priority_surfaces
    update_priority_strips
    update_hybrid_priority_surfaces
  end

  def priority_strip_on_screen?(source, min_tx, ty, elevation, curve_response = 1.0)
    projection = priority_strip_projection(source, min_tx, ty, elevation,
                                           curve_response)
    return false if !projection
    left, right, top, bottom = projection
    right >= 0 && left <= Mode7.screen_w && bottom >= 0 && top <= Mode7.screen_h
  end

  def priority_strip_anchor(min_tx, ty, elevation)
    Mode7.project(min_tx * Game_Map::TILE_WIDTH,
                  ty * Game_Map::TILE_HEIGHT + Game_Map::TILE_HEIGHT / 2.0,
                  elevation)
  end

  def update_priority_strips
    return if !@priority_strips
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ? Mode7::Config::WALL_SPAWN_RADIUS_Y : 34

    @priority_strips.each do |data|
      sprite, source, min_tx, ty, priority, unify, elevation, _projection_key, _cells,
      hybrid_mode, state, curve_response, _mountain_shadow = data
      hybrid_active = hybrid_mode && hybrid_row_priority_active?(1, ty)
      if hybrid_mode == :hybrid_top && !hybrid_active
        sprite.visible = false
        next
      end
      if hybrid_mode == :hybrid_base && hybrid_active
        sprite.visible = false
        next
      end
      if (ty - cam_ty).abs > radius_y
        sprite.visible = false
        next
      end
      if !priority_strip_on_screen?(source, min_tx, ty, elevation, curve_response)
        sprite.visible = false
        next
      end

      # Debe usar umbral IDENTICO a @ground: este se redibuja cada 1 px X y
      # cada cambio Y. Reproyectar/mover antes desalineaba tall grass del suelo.
      needs_projection = !state ||
                         (Mode7.cam_x - state[0]).abs >= 1.0 ||
                         (Mode7.cam_y - state[1]).abs > 0.001 ||
                         state[2].nil? ||
                         (Mode7.projection_cam_y - state[2]).abs > 0.001 ||
                         state[3] != Mode7.projection_revision
      if needs_projection
        if !redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation,
                                            curve_response)
          sprite.visible = false
          next
        end
        data[10] = [Mode7.cam_x, Mode7.cam_y, Mode7.projection_cam_y,
                    Mode7.projection_revision]
        state = data[10]
      end
      if !sprite.bitmap || sprite.bitmap.disposed?
        sprite.visible = false
        next
      end
      top = sprite.y - sprite.oy * sprite.zoom_y
      left = sprite.x - sprite.ox * sprite.zoom_x
      right = left + sprite.bitmap.width * sprite.zoom_x
      if top > Mode7.screen_h || sprite.y < 0 ||
         left > Mode7.screen_w || right < 0
        sprite.visible = false
        next
      end

      bias = unify + (priority > 0 ? Mode7::Config::WALL_TOP_Z_BIAS : 0)
      sprite.z = Mode7.depth_z((ty + 1) * Game_Map::TILE_HEIGHT, priority, bias)
      apply_depth_fog_to_sprite(sprite, sprite.y + sprite.bitmap.height)
      sprite.visible = true
    end
  end

  def update_hybrid_priority_surfaces
    return if !@priority_data
    cam_tx = Mode7.cam_x / Game_Map::TILE_WIDTH
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT
    radius_x = defined?(Mode7::Config::WALL_SPAWN_RADIUS_X) ? Mode7::Config::WALL_SPAWN_RADIUS_X : 26
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ? Mode7::Config::WALL_SPAWN_RADIUS_Y : 34

    @priority_data.each do |data|
      sprite, wx, wyb, entry_or_cells, priority, elevation, depth, hybrid_priority,
      tx, ty, source, projection_key, max_tx, max_ty, curve_response, wall_component = data
      max_tx ||= tx
      max_ty ||= ty

      if max_tx < cam_tx - radius_x || tx > cam_tx + radius_x ||
         max_ty < cam_ty - radius_y || ty > cam_ty + radius_y
        sprite.visible = false
        next
      end

      needs_projection = !projection_key ||
                         (Mode7.cam_x - projection_key[0]).abs >= 1.0 ||
                         (Mode7.cam_y - projection_key[1]).abs > 0.001 ||
                         elevation != projection_key[2] ||
                         projection_key[3].nil? ||
                         (Mode7.projection_cam_y - projection_key[3]).abs > 0.001 ||
                         projection_key[4] != Mode7.projection_revision
      if needs_projection
        if !redraw_projected_priority_surface(sprite, source, wx, wyb, elevation,
                                              curve_response, wall_component)
          sprite.visible = false
          next
        end
        data[11] = [Mode7.cam_x, Mode7.cam_y, elevation, Mode7.projection_cam_y,
                    Mode7.projection_revision]
      end
      if !sprite.bitmap || sprite.bitmap.disposed?
        sprite.visible = false
        next
      end
      top = sprite.y - sprite.oy * sprite.zoom_y
      left = sprite.x - sprite.ox * sprite.zoom_x
      right = left + sprite.bitmap.width * sprite.zoom_x
      if top > Mode7.screen_h || sprite.y < 0 ||
         left > Mode7.screen_w || right < 0
        sprite.visible = false
        next
      end

      hybrid_active = hybrid_priority_active?(hybrid_priority, tx, ty)
      priority = hybrid_active ? hybrid_priority : 0 if hybrid_priority
      depth_wyb, depth_priority, depth_unify = depth || [wyb, priority, 0]
      depth_priority = priority if hybrid_priority
      bias = depth_unify.to_i
      bias += Mode7::Config::WALL_TOP_Z_BIAS if depth_priority > 0
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, bias)

      apply_depth_fog_to_sprite(sprite, sprite.y)
      sprite.visible = true
    end
  end

  # ---------------------------------------------------------------------------
  # Autotiles / actualizacion
  # ---------------------------------------------------------------------------
  def recomposite_autotiles
    seen = {}
    @autotile_cells.each do |filename, cells|
      next if !@autotiles.animated?(filename)
      cells.each do |tx, ty|
        key = "#{tx},#{ty}"
        next if seen[key]
        seen[key] = true

        redraw_ground_cell(tx, ty)
      end
    end

    @wall_data.each do |data|
      sprite, wx, wyb, _h, entries, _z_behavior, _base_unify, _depth, shadow_opacity,
      min_tx, min_ty = data
      next if !sprite.bitmap || sprite.bitmap.disposed?
      if entries.is_a?(Hash)
        next if entries.values.flatten.none? { |entry| entry[:animated] }
        draw_wall_component_base_source(sprite.bitmap, min_tx, min_ty, entries)
        next
      end
      next if entries.none? { |entry| entry[:animated] }

      sprite.bitmap.clear
      tx = ((wx - Game_Map::TILE_WIDTH / 2.0) / Game_Map::TILE_WIDTH).round
      ty = (wyb / Game_Map::TILE_HEIGHT - 1).round
      draw_wall_column_source(sprite.bitmap, entries, tx, ty, shadow_opacity)
    end

    @priority_strips.each do |data|
      _sprite, source, min_tx, ty, _priority, _unify, _elevation, _projection_key,
      cells, _hybrid_mode, _state, _curve_response, mountain_shadow = data
      next if !source || source.disposed?
      next if cells.values.flatten.none? { |entry| entry[:animated] }
      draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow)
      data[7] = nil
      data[10] = nil
    end

    @priority_data.each do |data|
      sprite, _wx, _wyb, entry_or_cells, _priority, _elevation, _depth, _hybrid,
      tx, ty, source, _projection_key = data
      next if !source || source.disposed?
      if entry_or_cells.is_a?(Hash)
        next if entry_or_cells.values.flatten.none? { |entry| entry[:animated] }
        draw_priority_volume_source(source, tx, ty, entry_or_cells)
      else
        next if !entry_or_cells[:animated]
        source.clear
        blt_entry_into(source, 0, 0, entry_or_cells, entry_or_cells[:opacity] || 255)
      end
      data[11] = nil
    end
  end

  def apply_depth_fog_to_sprite(sprite, sy)
    return if !Mode7.respond_to?(:fog_alpha)
    alpha = Mode7.fog_alpha(sy)
    if alpha > 0
      sprite.color.set(Mode7::Config::FOG_COLOR.red,
                       Mode7::Config::FOG_COLOR.green,
                       Mode7::Config::FOG_COLOR.blue, alpha)
    else
      sprite.color.set(0, 0, 0, 0)
    end
  end

  # Ancla hibrida P0: el borde inferior queda en su celda Sky real, mientras
  # alto toma una parte de la distancia top-bottom del mapa. Asi el bloque no
  # se pega al player como billboard ni se vuelve una tira de tiles sueltos.
  def wall_component_scale_y(wyb, height, elevation, billboard_scale)
    return billboard_scale if !Mode7.sky_mode? || height <= 0
    top = Mode7.project_y(wyb - height, elevation)
    bottom = Mode7.project_y(wyb, elevation)
    return billboard_scale if !top || !bottom
    ground_scale = (bottom - top) / height.to_f
    return billboard_scale if ground_scale <= 0.001
    ground_scale = billboard_scale if ground_scale < billboard_scale
    response = Mode7::Config::SKY_WALL_COMPONENT_CURVE_RESPONSE.to_f.clamp(0.0, 1.0)
    billboard_scale + ((ground_scale - billboard_scale) * response)
  end

  # ---------------------------------------------------------------------------
  # Muros fisicos
  # ---------------------------------------------------------------------------
  def update_walls
    cam_tx = Mode7.cam_x / Game_Map::TILE_WIDTH
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT

    radius_x = defined?(Mode7::Config::WALL_SPAWN_RADIUS_X) ? Mode7::Config::WALL_SPAWN_RADIUS_X : 26
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ? Mode7::Config::WALL_SPAWN_RADIUS_Y : 34

    @wall_data.each do |data|
      sprite, wx, wyb, h, entries, _z_behavior, _base_unify, depth,
      _shadow_opacity, _min_tx, _min_ty, _max_tx, _max_ty, elevation = data

      half_w = sprite.bitmap.width / 2.0
      left_tx = (wx - half_w) / Game_Map::TILE_WIDTH
      right_tx = (wx + half_w) / Game_Map::TILE_WIDTH
      top_ty = (wyb - h) / Game_Map::TILE_HEIGHT
      bottom_ty = wyb / Game_Map::TILE_HEIGHT
      if right_tx < cam_tx - radius_x || left_tx > cam_tx + radius_x ||
         bottom_ty < cam_ty - radius_y || top_ty > cam_ty + radius_y
        sprite.visible = false
        next
      end

      pr = Mode7.project_billboard(wx, wyb, 0)
      if !pr
        sprite.visible = false
        next
      end
      sx, syb = pr

      # Columna simple conserva proporcion. Componente P0 conserva X de wall,
      # pero usa alto hibrido para coincidir mejor con tramo vertical Sky.
      k = Mode7.tile_billboard_scale_for_world_y(wyb)
      if !k || k <= 0
        sprite.visible = false
        next
      end

      scale_y = entries.is_a?(Hash) ? wall_component_scale_y(wyb, h, elevation, k) : k
      half_width = half_w * k
      top_y = syb - h * scale_y
      if syb < -Game_Map::TILE_HEIGHT ||
         top_y > Mode7.screen_h + Game_Map::TILE_HEIGHT ||
         sx < -half_width - Game_Map::TILE_WIDTH ||
         sx > Mode7.screen_w + half_width + Game_Map::TILE_WIDTH
        sprite.visible = false
        next
      end

      sprite.x = sx
      sprite.y = syb
      sprite.zoom_x = k
      sprite.zoom_y = scale_y
      depth_wyb, depth_priority, depth_unify = depth || [wyb, 0, 0]
      bias = depth_unify.to_i
      bias += Mode7::Config::WALL_TOP_Z_BIAS if depth_priority > 0
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, bias)

      apply_depth_fog_to_sprite(sprite, syb)
      sprite.visible = true
    end
  end
end
