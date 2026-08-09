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
  # Vanilla conserva la estrella propia de cada entry. Un P0 de Mountains en
  # otra layer no puede convertir un P1/P4 vecino en P0: eso hacia que Mountain
  # cubra props y que la prioridad pareciera heredada por adyacencia.
  def cache_visual_priorities
    @entry_cache.each_value do |entries|
      entries.each { |entry| entry[:visual_priority] = entry[:priority].to_i }
    end
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

  # Una casilla Mountain/Wall puede tener su P0 con tag y P1/P4 sin tag
  # propio (escalera, borde, remate). Todos deben compartir raster. Limitarlo
  # a la misma celda evita arrastrar prioridad de tiles adyacentes.
  def entry_uses_wall_raster?(entry)
    return true if entry[:terrain_height_wall_cell]
    entry_is_wall?(entry)
  end

  # Objetos wall compactos necesitan una base comun. Si cada fila usa su
  # borde curvo individual, arriba se solapan y abajo se separan. Componentes
  # grandes siguen raster normal para conservar curvatura de pasillos/mapa.
  def cache_wall_raster_components
    cells = {}
    @entry_cache.each do |position, entries|
      # Una celda ElevatedWall presta su raster a las capas de ESA celda, pero
      # corta el componente normal. Si entra aqui, su Mode7Tag/P1 conecta el
      # ancla con walls vecinos y les contagia posicion/prioridad visual.
      next if entries.any? { |entry| entry_is_elevated_wall?(entry) }
      next if entries.none? { |entry|
        entry_is_wall?(entry) && !entry_is_elevated_wall?(entry)
      }
      cells[position] = entries
    end
    return if cells.empty?

    max_size = [wall_terrain_tag_heights.values.map(&:to_i).max.to_i * 2, 1].max
    priority_volume_components(cells).each do |component|
      xs = component.keys.map { |tx, _ty| tx }
      ys = component.keys.map { |_tx, ty| ty }
      next if xs.max - xs.min + 1 > max_size || ys.max - ys.min + 1 > max_size
      anchor_ty = ys.max
      component.each_value do |entries|
        entries.each do |entry|
          next if !entry_is_wall?(entry) && entry_visual_priority(entry) <= 0
          entry[:wall_raster_anchor_ty] = anchor_ty
        end
      end
    end
    # ponytail: componentes <= reserva*2; ID de objeto si Maker Studio lo hace
    # obligatorio para edificios contiguos mayores.
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

  # Una escalera en capa superior es un suelo caminable que cruza una pared
  # inferior. El mapa ya decide su pasabilidad nativa; la cache 2.5D no debe
  # volver a bloquearla solo por encontrar Mountains/Mode7Tag debajo.
  def entry_is_walkable_ladder?(e)
    tag = terrain_tag_for_entry(e)
    return false if !tag || tag.id == :None
    tag.id == :Ladders || tag.id == :LaddersSide
  end

  def ladder_overrides_wall_collision?(entries, blocking_entries)
    ladders = entries.select { |entry| entry_is_walkable_ladder?(entry) }
    return false if ladders.empty? || blocking_entries.empty?
    ladder_unify = ladders.map { |entry| entry[:unify].to_i }.max
    wall_unify = blocking_entries.map { |entry| entry[:unify].to_i }.max
    ladder_unify >= wall_unify
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
    return true if entry_hybrid_priority(e)
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
    # Wall ya no se dibuja como Sprite independiente. P0 entra a @ground y
    # P1-P4 a strips por fila, exactamente como Mountains. Asi comparte slot
    # con tiles vecinos y no puede perseguir camara ni abrir juntas internas.
    # ponytail: malla 3D real solo si RGSS expone vertices/texturas por tile.
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]
        direct_walls = entries.select { |entry| entry_is_wall?(entry) }
        next if direct_walls.empty?
        blocking = direct_walls.select { |entry| entry_blocks_movement?(entry) }
        next if blocking.empty? || ladder_overrides_wall_collision?(entries, blocking)
        @wall_cells[[tx, ty]] = true
      rescue Exception
        Console.echo_error("2.5D: columna fallida en (#{tx},#{ty})") if defined?(Console)
      end
    end
  end

  def build_priority_surfaces
    strips = Hash.new { |hash, key| hash[key] = {} }
    volumes = Hash.new { |hash, key| hash[key] = {} }
    @map.width.times do |tx|
      @map.height.times do |ty|
        @entry_cache[[tx, ty]].each do |entry|
          wall_raster_entry = !entry[:wall_raster_anchor_ty].nil?
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
          # P1/P4 dentro de misma celda wall usa raster del plano, incluso si
          # fragmento superior no repite terrain tag. Asi P0/P1 comparten
          # scanlines sin extender logica a grass/props vecinos.
          ground_raster = wall_raster_entry || entry_uses_wall_raster?(entry)
          key = [entry[:unify].to_i, entry_visual_priority(entry),
                 entry_world_elevation(entry), ground_raster]
          volumes[key][[tx, ty]] ||= []
          volumes[key][[tx, ty]].push(entry)
        end
      end
    end
    strips.each do |(kind, unify, priority, ty, elevation), cells|
      hybrid_mode = kind == :normal ? nil : kind
      make_priority_strip(cells, ty, priority, unify, elevation, hybrid_mode)
    end
    volumes.each do |(_unify, _priority, elevation, ground_raster), cells|
      # P1+ conserva prioridad Z, pero su rectangulo visible vive en la misma
      # celda curva que el suelo. Un billboard grande era quien lo arrastraba.
      make_cell_locked_priority_strips(cells, elevation, ground_raster)
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
          # InteriorBorder conserva su estrella nativa. Forzarlo a P0 hacia
          # que un borde P4/P6 quedara debajo del actor aunque Maker lo guarde.
          depth = [(ty + 1) * Game_Map::TILE_HEIGHT,
                   entry_visual_priority(entry), entry[:unify].to_i]
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

  # P1+ delimita objeto wall dentro de SU capa real. P0 y P1-P4 de esa capa
  # comparten bounds; un P1 vecino de otra capa no puede absorber su prioridad.
  def priority_wall_components(cells)
    cap_groups = Hash.new { |hash, key| hash[key] = {} }
    cells.each do |position, entries|
      caps = entries.select { |entry| entry_visual_priority(entry) > 0 }
      caps.each do |entry|
        unify = entry[:unify].to_i
        cap_groups[unify][position] ||= []
        cap_groups[unify][position].push(entry)
      end
    end
    return [[], priority_wall_entries(cells)] if cap_groups.empty?

    claimed_priority = {}
    components = []
    cap_groups.each do |unify, cap_cells|
      priority_volume_components(cap_cells).each do |cap_component|
        component = {}
        cap_component.each do |position, entries|
          component[position] = entries.dup
          entries.each { |entry| claimed_priority[entry.object_id] = true }
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
            support_entries = entries.select do |entry|
              entry[:unify].to_i == unify && entry_visual_priority(entry) <= 0
            end
            next if support_entries.empty?
            component[[nx, ny]] ||= []
            support_entries.each do |entry|
              next if component[[nx, ny]].include?(entry)
              component[[nx, ny]].push(entry)
            end
            pending.push([nx, ny])
          end
        end
        components.push(component)
      end
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
  def make_cell_locked_priority_strips(cells, elevation, ground_raster = false)
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
          anchor_ty = segment.values.flatten.filter_map do |entry|
            entry[:wall_raster_anchor_ty]
          end.max
          make_priority_strip(segment, ty, priority, unify, elevation, nil,
                              1.0, ground_raster, anchor_ty)
          segment = {}
        end
        segment[tx] = row[tx]
        previous = tx
      end
      if !segment.empty?
        anchor_ty = segment.values.flatten.filter_map do |entry|
          entry[:wall_raster_anchor_ty]
        end.max
        make_priority_strip(segment, ty, priority, unify, elevation, nil,
                            1.0, ground_raster, anchor_ty)
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
                          curve_response = 1.0, ground_raster = false,
                          wall_anchor_ty = nil)
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
                           curve_response, mountain_shadow, ground_raster,
                           wall_anchor_ty])
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
                           0.0, true)
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
    return redraw_projected_wall_surface(sprite, source, wx, wyb, elevation) if wall_component

    projected = Mode7.project_billboard(wx, wyb, elevation)
    return false if !projected
    scale_x = Mode7.tile_billboard_scale_for_world_y(wyb)
    return false if !scale_x || scale_x <= 0
    response = curve_response.to_f.clamp(0.0, 1.0)
    scale_y = scale_x
    if response > 0.0
      top = Mode7.project_y(wyb - source.height, elevation)
      curve_scale = top ? (projected[1] - top) / source.height.to_f : scale_x
      curve_scale = scale_x if curve_scale <= 0.001
      scale_y += (curve_scale - scale_y) * response
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

  # Wall y sus bandas P1-P4 deben usar transformacion del MAPA, no la de un
  # overworld billboard. Comparten base, escala y bounds; priority solo cambia
  # Z. Mezclar project_billboard con project movia P1 lateralmente al variar la
  # perspectiva conica y separaba barriles, techos y arboles.
  def redraw_projected_wall_surface(sprite, source, wx, wyb, elevation = 0)
    projected = Mode7.project(wx, wyb, elevation)
    return false if !projected
    scale = Mode7.hscale(projected[1])
    return false if !scale || scale <= 0.001

    sprite.bitmap = source if sprite.bitmap != source
    sprite.ox = source.width / 2.0
    sprite.oy = source.height
    sprite.x = projected[0]
    sprite.y = projected[1]
    sprite.zoom_x = scale
    sprite.zoom_y = scale
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
    # Wall P1 se ata al borde inferior, mismo borde que raster del suelo.
    # Asi no toma X de mitad de celda y abre una junta al reducir curvatura.
    anchor_y = curve_response.to_f < 1.0 ? wy_bottom : wy_middle
    left = Mode7.project(wx_left, anchor_y, elevation)
    right = Mode7.project(wx_right, anchor_y, elevation)
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

  # Busca limite contra la misma inversa que llena @ground. No usar project_y:
  # su redondeo directo dejaba P1 un pixel/fila distinto del raster al bajar.
  def first_ground_row_for_world_y(world_y, low, high)
    result = nil
    while low <= high
      middle = (low + high) / 2
      row_world_y = Mode7.world_y_for_row(middle)
      if row_world_y && row_world_y.floor >= world_y
        result = middle
        high = middle - 1
      else
        low = middle + 1
      end
    end
    result
  end

  def priority_strip_ground_row_range(ty)
    @priority_strip_row_ranges ||= {}
    # El plano base ya se mueve en enteros de pixel. Repetir la busqueda de
    # filas por cada fraccion de scroll hacia que todos los P1/P4 de una casa
    # repintaran su bitmap en cada frame.
    # ponytail: cuantizar a pixel; subpixel solo si se requiere camara suave HD.
    cache_key = [Mode7.projection_cam_y.floor, Mode7.projection_revision]
    if @priority_strip_row_ranges[:camera] != cache_key
      @priority_strip_row_ranges.clear
      @priority_strip_row_ranges[:camera] = cache_key
    end
    return @priority_strip_row_ranges[ty] if @priority_strip_row_ranges.key?(ty)

    world_top = ty * Game_Map::TILE_HEIGHT
    world_bottom = world_top + Game_Map::TILE_HEIGHT
    first_visible = [Mode7.horizon_row.ceil, 0].max
    # Base de edificio puede quedar bajo viewport mientras techo aun se ve.
    # Buscar unas filas extra evita que componente entero haga popping.
    reserve = wall_terrain_tag_heights.values.map(&:to_i).max.to_i * 2
    extra = [reserve * Game_Map::TILE_HEIGHT * Mode7.zoom, 0].max.ceil
    last_visible = Mode7.screen_h - 1 + extra
    return @priority_strip_row_ranges[ty] = nil if first_visible > last_visible
    first = first_ground_row_for_world_y(world_top, first_visible, last_visible)
    return @priority_strip_row_ranges[ty] = nil if !first
    after_last = first_ground_row_for_world_y(world_bottom, first, last_visible)
    last = after_last ? after_last - 1 : last_visible
    return @priority_strip_row_ranges[ty] = nil if last < first
    @priority_strip_row_ranges[ty] = [first, last]
  end

  def priority_strip_raster_metrics(source, ty, wall_anchor_ty = nil)
    rows = priority_strip_ground_row_range(ty)
    return nil if !rows
    source_first, source_last = rows
    source_height = [source_last - source_first + 1, 1].max
    if wall_anchor_ty
      anchor_rows = priority_strip_ground_row_range(wall_anchor_ty)
      return nil if !anchor_rows
      anchor_height = [anchor_rows[1] - anchor_rows[0] + 1, 1].max
      rigid_height = source.height * Mode7.zoom
      rigidity = Mode7::Config::SKY_WALL_RASTER_RIGIDITY.to_f.clamp(0.0, 1.0)
      target_height = (anchor_height + (rigid_height - anchor_height) * rigidity).round
      target_height = [target_height, 1].max
      target_last = anchor_rows[1] - (wall_anchor_ty - ty) * target_height
      target_first = target_last - target_height + 1
      return [source_first, source_last, target_first, target_last,
              source_height, target_height]
    end
    # ponytail: alto nativo en pantalla. El billboard direccional tambien se
    # encogia al alejarse, asi que no servia como limite de rigidez.
    rigid_height = source.height * Mode7.zoom
    rigid_height = [rigid_height, source_height].max
    rigidity = Mode7::Config::SKY_WALL_RASTER_RIGIDITY.to_f.clamp(0.0, 1.0)
    target_height = (source_height + (rigid_height - source_height) * rigidity).round
    target_height = [target_height, 1].max
    target_last = source_last
    target_first = target_last - target_height + 1
    [source_first, source_last, target_first, target_last, source_height, target_height]
  end

  # Estado minimo que cambia los pixeles de un strip rasterizado. La banda
  # visible y la muestra de mundo cambian cada pixel de camara, no cada frame.
  def priority_strip_ground_raster_state(source, ty, wall_anchor_ty = nil)
    metrics = priority_strip_raster_metrics(source, ty, wall_anchor_ty)
    return nil if !metrics
    source_first, source_last, target_first, target_last, _source_height, _target_height = metrics
    [source_first, source_last, target_first, target_last,
     Mode7.cam_x.floor, Mode7.projection_cam_y.floor,
     Mode7.projection_revision]
  end

  def priority_strip_raster_bounds(source, ty, wall_anchor_ty = nil)
    metrics = priority_strip_raster_metrics(source, ty, wall_anchor_ty)
    return nil if !metrics
    _source_first, _source_last, first, last, _source_height, _target_height = metrics
    return nil if last < 0 || first >= Mode7.screen_h
    [[first, 0].max, [last, Mode7.screen_h - 1].min]
  end

  # P1 de wall se repinta por scanline, igual que @ground. No es un Sprite
  # con zoom: cada pixel toma misma X/Y de mundo que Mountain P0. El Sprite
  # solo aporta Z por fila para que actor quede arriba/abajo segun prioridad.
  def redraw_ground_raster_priority_strip(sprite, source, min_tx, ty,
                                          wall_anchor_ty = nil)
    metrics = priority_strip_raster_metrics(source, ty, wall_anchor_ty)
    return false if !metrics
    source_first, source_last, first_row, last_row, source_height, required_height = metrics
    return false if last_row < 0 || first_row >= Mode7.screen_h
    @priority_strip_rasters ||= {}
    raster = @priority_strip_rasters[sprite.object_id]
    if !raster || raster.disposed? || raster.width != Mode7.screen_w ||
       raster.height < required_height
      raster.dispose if raster && !raster.disposed?
      raster = Bitmap.new(Mode7.screen_w, required_height)
      @priority_strip_rasters[sprite.object_id] = raster
    else
      raster.clear
    end

    world_left = min_tx * Game_Map::TILE_WIDTH
    world_right = world_left + source.width
    world_top = ty * Game_Map::TILE_HEIGHT
    world_bottom = world_top + source.height
    (0...required_height).each do |target_row|
      if wall_anchor_ty
        screen_row = first_row + target_row
        source_y = ((target_row + 0.5) * source.height / required_height).floor
        source_y = [[source_y, 0].max, source.height - 1].min
      else
        screen_row = source_first + ((target_row + 0.5) * source_height / required_height).floor
        screen_row = [[screen_row, source_first].max, source_last].min
        wy = Mode7.world_y_for_row(screen_row)
        next if !wy || wy < world_top || wy >= world_bottom
        source_y = wy.floor - world_top
      end
      scale = Mode7.hscale(screen_row)
      next if !scale || scale <= 0.001
      span = Mode7.screen_w / scale
      wx_left = Mode7.cam_x - Mode7.center_x / scale
      source_left = [wx_left.floor, world_left].max
      source_right = [(wx_left + span).ceil, world_right].min
      next if source_right <= source_left

      screen_left = (((source_left - wx_left) / span) * Mode7.screen_w).round
      screen_right = (((source_right - wx_left) / span) * Mode7.screen_w).round
      screen_left = [screen_left, 0].max
      screen_right = [screen_right, Mode7.screen_w].min
      next if screen_right <= screen_left
      @src_rect.set(source_left - world_left, source_y,
                    source_right - source_left, 1)
      @dest_rect.set(screen_left, target_row,
                     screen_right - screen_left, 1)
      raster.stretch_blt(@dest_rect, source, @src_rect)
    end
    sprite.bitmap = raster
    sprite.src_rect.set(0, 0, Mode7.screen_w, required_height)
    sprite.ox = 0
    sprite.oy = 0
    sprite.x = 0
    sprite.y = first_row
    sprite.zoom_x = 1.0
    sprite.zoom_y = 1.0
    true
  end

  def redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation = 0,
                                      curve_response = 1.0, ground_raster = false,
                                      wall_anchor_ty = nil)
    if ground_raster
      return redraw_ground_raster_priority_strip(sprite, source, min_tx, ty,
                                                 wall_anchor_ty)
    end
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

  def priority_strip_on_screen?(source, min_tx, ty, elevation, curve_response = 1.0,
                                ground_raster = false, wall_anchor_ty = nil)
    if ground_raster
      rows = priority_strip_raster_bounds(source, ty, wall_anchor_ty)
      return false if !rows
      screen_y = (rows[0] + rows[1]) / 2.0
      scale = Mode7.hscale(screen_y)
      return false if !scale || scale <= 0.001
      world_left = min_tx * Game_Map::TILE_WIDTH
      screen_left = Mode7.center_x + (world_left - Mode7.cam_x) * scale
      screen_right = screen_left + source.width * scale
      # ponytail: bounds AABB por strip; clip por scanline solo si X deja de
      # ser lineal. Evita rasterizar walls totalmente fuera del viewport.
      return screen_right >= 0 && screen_left <= Mode7.screen_w
    end
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
      hybrid_mode, state, curve_response, _mountain_shadow, ground_raster,
      wall_anchor_ty = data
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
      if !priority_strip_on_screen?(source, min_tx, ty, elevation, curve_response,
                                    ground_raster, wall_anchor_ty)
        sprite.visible = false
        next
      end

      # P1/P4 raster comparte las scanlines de Mountain, pero no debe crear un
      # bitmap nuevo por cada 0.25 px del paso del jugador. Los strips normales
      # conservan la ruta de proyeccion exacta.
      raster_state = if ground_raster
                       priority_strip_ground_raster_state(source, ty,
                                                         wall_anchor_ty)
                     end
      needs_projection = if ground_raster
                           !raster_state || state != raster_state
                         else
                           !state ||
                             (Mode7.cam_x - state[0]).abs >= 1.0 ||
                             (Mode7.cam_y - state[1]).abs > 0.001 ||
                             state[2].nil? ||
                             (Mode7.projection_cam_y - state[2]).abs > 0.001 ||
                             state[3] != Mode7.projection_revision
                         end
      if needs_projection
        if !redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation,
                                            curve_response, ground_raster,
                                            wall_anchor_ty)
          sprite.visible = false
          next
        end
        data[10] = ground_raster ? raster_state :
                    [Mode7.cam_x, Mode7.cam_y, Mode7.projection_cam_y,
                     Mode7.projection_revision]
        state = data[10]
      end
      if !sprite.bitmap || sprite.bitmap.disposed?
        sprite.visible = false
        next
      end
      if ground_raster
        top = sprite.y
        bottom = top + sprite.src_rect.height * sprite.zoom_y
        left = sprite.x
        right = left + sprite.src_rect.width * sprite.zoom_x
      else
        top = sprite.y - sprite.oy * sprite.zoom_y
        bottom = sprite.y
        left = sprite.x - sprite.ox * sprite.zoom_x
        right = left + sprite.bitmap.width * sprite.zoom_x
      end
      if top > Mode7.screen_h || bottom < 0 || left > Mode7.screen_w || right < 0
        sprite.visible = false
        next
      end

      bias = unify + (priority > 0 ? Mode7::Config::WALL_TOP_Z_BIAS : 0)
      sprite.z = Mode7.depth_z((ty + 1) * Game_Map::TILE_HEIGHT, priority, bias)
      fog_y = ground_raster ? bottom : sprite.y + sprite.bitmap.height
      apply_depth_fog_to_sprite(sprite, fog_y)
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

      # Misma proyeccion que @ground. Nunca usar la escala/posicion de OW para
      # tiles del mapa: esa diferencia era arrastre vertical/lateral al caminar.
      pr = Mode7.project(wx, wyb, elevation)
      if !pr
        sprite.visible = false
        next
      end
      sx, syb = pr

      k = Mode7.hscale(syb)
      if !k || k <= 0
        sprite.visible = false
        next
      end

      # P0 y P1-P4 de componente comparten este factor. No comprimir alto por
      # separado: prioridad cambia oclusion, no geometria.
      scale_y = k
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
