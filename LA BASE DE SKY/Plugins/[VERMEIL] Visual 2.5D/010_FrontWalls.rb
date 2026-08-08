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
  # La prioridad del editor es la fuente de verdad. El renderer 2.5D no puede
  # rebajar un priority 4 por su layer/unify: Maker Studio admite bandas > 4.
  def cache_visual_priorities
    @entry_cache.each_value do |entries|
      entries.each do |entry|
        entry[:visual_priority] = entry[:priority].to_i
      end
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

  def entry_wall_height(e)
    tag = terrain_tag_for_entry(e)
    return 1 if !tag || tag.id == :None
    wall_terrain_tag_heights[tag.id] || 1
  end

  # Un muro fisico se decide por Terrain Tag. Priority NO significa altura.
  def entry_is_wall?(e)
    tag = terrain_tag_for_entry(e)
    if tag && tag.id != :None && wall_terrain_tag_heights.key?(tag.id)
      return true
    end
    return true if Mode7Renderer.debug_mode_force_all_priority_wall? && e[:priority].to_i > 0
    false
  end

  def entry_hybrid_priority(e)
    tag = terrain_tag_for_entry(e)
    return nil if !tag || tag.id == :None
    Mode7::Config::HYBRID_PRIORITY_TERRAIN_TAGS[tag.id]
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
    return false if entry_is_wall?(e)
    return true if entry_hybrid_priority(e)
    p = entry_visual_priority(e)
    min = Mode7::Config::PRIORITY_SURFACE_MIN.to_i
    return false if p < min
    return false if p == 1 && Mode7Renderer.debug_mode_force_priority_1_as_ground?
    true
  end

  def cell_has_wall?(entries)
    entries.any? { |e| entry_is_wall?(e) }
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

  def wall_layer_height(entries)
    entries.select { |e| entry_is_wall?(e) }.map { |e| entry_wall_height(e) }.max || 1
  end

  def wall_layer_unify(entries)
    vals = entries.select { |e| entry_is_wall?(e) }.map { |e| e[:unify].to_i }
    vals.empty? ? 0 : vals.min
  end

  def connected_cell_groups(cells)
    groups = []
    seen = {}
    cells.each_key do |origin|
      next if seen[origin]
      seen[origin] = true
      queue = [origin]
      index = 0
      group = []
      while index < queue.length
        x, y = queue[index]
        index += 1
        group.push([x, y, cells[[x, y]]])
        [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |dx, dy|
          neighbor = [x + dx, y + dy]
          next if seen[neighbor] || !cells.key?(neighbor)
          seen[neighbor] = true
          queue.push(neighbor)
        end
      end
      groups.push(group)
    end
    groups
  end

  # Priority 0 conserva siempre su base individual. Piezas contiguas de la
  # MISMA prioridad positiva comparten profundidad: un tejado priority 4 se
  # comporta como una sola banda, sin arrastrar suelo/props priority 0.
  def tile_depths(cells, share_priority_depth = false)
    depths = {}
    unless share_priority_depth
      cells.each_key do |tx, ty|
        depths[[tx, ty]] = (ty + 1) * Game_Map::TILE_HEIGHT
      end
      return depths
    end

    connected_cell_groups(cells).each do |group|
      depth = (group.map { |_x, y, _entries| y }.max + 1) * Game_Map::TILE_HEIGHT
      group.each { |x, y, _entries| depths[[x, y]] = depth }
    end
    depths
  end

  def build_wall_columns
    wall_cells = {}
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]
        next if !effective_cell_has_wall?(tx, ty, entries)
        @wall_cells[[tx, ty]] = true if cell_has_wall?(entries)
        wall_layer = effective_wall_layer_unify(tx, ty, entries)
        wall_entries = entries.select do |entry|
          entry[:unify].to_i >= wall_layer && !priority_surface_entry?(entry)
        end
        wall_cells[[tx, ty]] = wall_entries unless wall_entries.empty?
      end
    end

    grouped_cells = {}
    max_cells = Mode7::Config::TERRAIN_TAG_VOLUME_GROUP_MAX_CELLS
    connected_cell_groups(wall_cells).each do |group|
      next if group.length > max_cells
      make_terrain_volume_group(group)
      group.each { |tx, ty, _entries| grouped_cells[[tx, ty]] = true }
    rescue Exception
      Console.echo_error("2.5D: volumen de terrain tag fallido") if defined?(Console)
    end

    # El filtro terrain tag declara un volumen unico. Su prioridad maxima queda
    # en Z del volumen entero: tapa al actor como RM, pero no separa/deforma
    # barril, copa o tronco entre celdas.
    ungrouped_cells = {}
    wall_cells.each do |key, entries|
      next if grouped_cells[key]
      ungrouped_cells[key] = entries
    end
    depths = tile_depths(ungrouped_cells)
    ungrouped_cells.each do |(tx, ty), entries|
      priority = entries.map { |entry| entry_visual_priority(entry) }.max || 0
      depth = [depths[[tx, ty]], priority]
      make_column(tx, ty, entries, wall_layer_height(entries), 0, :dynamic, depth)
    rescue Exception
      Console.echo_error("2.5D: columna fallida en (#{tx},#{ty})") if defined?(Console)
    end
  end

  # Componente etiquetado como volumen: su prioridad interna es arte del objeto,
  # no capas independientes. Se pinta como un billboard vertical rigido anclado
  # en su borde sur; por eso un arbol 3x3 no se curva ni se parte en copa/tronco.
  def make_terrain_volume_group(group)
    min_x = group.map { |x, _y, _entries| x }.min
    max_x = group.map { |x, _y, _entries| x }.max
    min_y = group.map { |_x, y, _entries| y }.min
    max_y = group.map { |_x, y, _entries| y }.max
    entries = group.flat_map { |_x, _y, cell_entries| cell_entries }
    padding = entries.map { |entry| entry_world_elevation(entry).ceil }.max || 0
    width = (max_x - min_x + 1) * Game_Map::TILE_WIDTH
    height = (max_y - min_y + 1) * Game_Map::TILE_HEIGHT + padding
    layout = {
      :cells => group, :min_x => min_x, :max_y => max_y,
      :padding => padding, :width => width, :height => height
    }
    bitmap = Bitmap.new(width, height)
    draw_terrain_volume_group(bitmap, layout)
    sprite = Sprite.new(@viewport)
    sprite.bitmap = bitmap
    sprite.ox = width / 2.0
    sprite.oy = height
    sprite.visible = false
    wx = min_x * Game_Map::TILE_WIDTH + width / 2.0
    wyb = (max_y + 1) * Game_Map::TILE_HEIGHT
    priority = entries.map { |entry| entry_visual_priority(entry) }.max || 0
    @wall_data.push([sprite, wx, wyb, height, entries, :volume, 0,
                     [wyb, priority], layout])
  end

  def draw_terrain_volume_group(bitmap, layout)
    bitmap.clear
    layout[:cells].sort_by { |x, y, _entries| [y, x] }.each do |tx, ty, entries|
      dx = (tx - layout[:min_x]) * Game_Map::TILE_WIDTH
      y = layout[:padding] + (layout[:max_y] - ty) * Game_Map::TILE_HEIGHT
      entries.sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }.each do |entry|
        blt_entry_into(bitmap, dx, y - entry_world_elevation(entry).round,
                       entry, entry[:opacity] || 255)
      end
    end
  end

  def build_priority_surfaces
    strips = Hash.new { |hash, key| hash[key] = {} }
    @map.width.times do |tx|
      @map.height.times do |ty|
        @entry_cache[[tx, ty]].each do |entry|
          next if !priority_surface_entry?(entry)
          hybrid = entry_hybrid_priority(entry)
          if hybrid
            # Base p0 siempre. Copia pN se muestra por fila solo cuando el
            # jugador queda al norte; evita un sprite/reproyeccion por grass.
            base_key = [:hybrid_base, entry[:unify].to_i, 0, ty,
                        entry_world_elevation(entry)]
            top_key = [:hybrid_top, entry[:unify].to_i, hybrid.to_i, ty,
                       entry_world_elevation(entry)]
            strips[base_key][tx] ||= []
            strips[base_key][tx].push(entry)
            strips[top_key][tx] ||= []
            strips[top_key][tx].push(entry)
            next
          end
          key = [:normal, entry[:unify].to_i, entry_visual_priority(entry), ty,
                 entry_world_elevation(entry)]
          strips[key][tx] ||= []
          strips[key][tx].push(entry)
        end
      end
    end
    strips.each do |(kind, unify, priority, ty, elevation), cells|
      hybrid_mode = kind == :normal ? nil : kind
      make_priority_strip(cells, ty, priority, unify, elevation, hybrid_mode)
    end
  end

  # ---------------------------------------------------------------------------
  # Altura fisica
  # ---------------------------------------------------------------------------
  # Desde Phase 4 el layer/unify NO genera altura. Solo una elevacion explicita
  # de Maker Studio mueve el tile sobre el eje Z.
  def entry_world_elevation(e)
    return 0.0 if !e.key?(:elevation) || e[:elevation].nil?
    e[:elevation].to_f
  end

  # Columna fisica de muro. Cada sprite contiene una sola prioridad; los layers
  # se componen dentro de esa banda sin convertirse en altura fisica.
  def make_column(tx, ty, entries, max_h, base_unify = 0, z_behavior = :dynamic, depth = nil)
    return if entries.nil? || entries.empty?
    max_h = max_h.to_i.clamp(1, 16)
    max_elev = entries.map { |e| entry_world_elevation(e) }.max || 0.0
    h = [max_h * Game_Map::TILE_HEIGHT, Game_Map::TILE_HEIGHT + max_elev.ceil].max

    bmp = Bitmap.new(Game_Map::TILE_WIDTH, h)
    bmp.clear

    entries.sort_by { |e| [entry_world_elevation(e), e[:unify].to_i, e[:priority].to_i] }.each do |e|
      elev = entry_world_elevation(e)
      y = (h - Game_Map::TILE_HEIGHT - elev).round
      y = 0 if y < 0
      blt_entry_into(bmp, 0, y, e, e[:opacity] || 255)
    end

    sprite = Sprite.new(@viewport)
    sprite.bitmap = bmp
    sprite.ox = Game_Map::TILE_WIDTH / 2.0
    sprite.oy = h
    sprite.visible = false

    wx = tx * Game_Map::TILE_WIDTH + Game_Map::TILE_WIDTH / 2.0
    wyb = ty * Game_Map::TILE_HEIGHT + Game_Map::TILE_HEIGHT
    @wall_data.push([sprite, wx, wyb, h, entries, z_behavior, base_unify, depth])
  end

  # ---------------------------------------------------------------------------
  # Priority surfaces (equivalente 2.5D de los tiles con estrella de RMXP)
  # ---------------------------------------------------------------------------
  # Un strip contiene todos los tiles de una fila que comparten priority/layer.
  # RPG Maker calcula Z por fila de tile, no por tile individual: esta unidad
  # mantiene la prioridad real y evita crear/reproyectar cientos de sprites al
  # mover la camara verticalmente.
  def make_priority_strip(cells, ty, priority, unify, elevation, hybrid_mode = nil)
    min_tx = cells.keys.min
    max_tx = cells.keys.max
    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
    source = Bitmap.new(width, Game_Map::TILE_HEIGHT)
    draw_priority_strip_source(source, min_tx, cells)

    sprite = Sprite.new(@viewport)
    sprite.bitmap = Bitmap.new(1, 1)
    sprite.ox = 0
    sprite.oy = 0
    sprite.visible = false
    @priority_strips.push([sprite, source, min_tx, ty, priority, unify,
                           elevation, nil, cells, hybrid_mode, nil])
  end

  def draw_priority_strip_source(source, min_tx, cells)
    source.clear
    cells.each do |tx, entries|
      x = (tx - min_tx) * Game_Map::TILE_WIDTH
      entries.sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }.each do |entry|
        blt_entry_into(source, x, 0, entry, entry[:opacity] || 255)
      end
    end
  end

  def make_priority_surface(tx, ty, entry, depth = nil, hybrid_priority = nil)
    return if !priority_surface_entry?(entry)

    # Solo prioridad hibrida llega aqui. El resto se dibuja por strips de fila.
    source = Bitmap.new(Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
    source.clear
    blt_entry_into(source, 0, 0, entry, entry[:opacity] || 255)
    sprite = Sprite.new(@viewport)
    sprite.bitmap = Bitmap.new(1, 1)
    sprite.ox = 0
    sprite.oy = 0
    sprite.visible = false
    wx = tx * Game_Map::TILE_WIDTH + Game_Map::TILE_WIDTH / 2.0
    wyb = (ty + 1) * Game_Map::TILE_HEIGHT
    @priority_data.push([sprite, wx, wyb, entry, entry_visual_priority(entry),
                         entry_world_elevation(entry), depth, hybrid_priority, tx, ty,
                         source, nil])
  end

  def redraw_projected_priority_surface(sprite, source, tx, ty, elevation = 0)
    return false if !source || source.disposed?
    redraw_projected_priority_source(sprite, source,
                                     tx * Game_Map::TILE_WIDTH,
                                     ty * Game_Map::TILE_HEIGHT, elevation)
  end

  def redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation = 0)
    return false if !source || source.disposed?
    redraw_projected_priority_source(sprite, source,
                                     min_tx * Game_Map::TILE_WIDTH,
                                     ty * Game_Map::TILE_HEIGHT, elevation)
  end

  def redraw_projected_priority_source(sprite, source, world_x, world_y, elevation = 0)
    rows = []
    Mode7.screen_h.times do |sy|
      wy = Mode7.world_y_for_row(sy)
      next if !wy || wy < world_y || wy >= world_y + Game_Map::TILE_HEIGHT
      scale = Mode7.hscale(sy)
      next if !scale || scale <= 0
      wx_left = Mode7.cam_x - Mode7.center_x / scale
      left = ((world_x - wx_left) * scale).round
      right = ((world_x + source.width - wx_left) * scale).round
      next if right <= left
      visible_left = [left, 0].max
      visible_right = [right, Mode7.screen_w].min
      next if visible_right <= visible_left
      src_left = (((visible_left - left) * source.width) / (right - left).to_f).floor
      src_right = (((visible_right - left) * source.width) / (right - left).to_f).ceil
      src_left = src_left.clamp(0, source.width - 1)
      src_right = src_right.clamp(src_left + 1, source.width)
      rows.push([sy, visible_left, visible_right,
                 (wy - world_y).floor.clamp(0, Game_Map::TILE_HEIGHT - 1),
                 src_left, src_right])
    end
    return false if rows.empty?

    min_x = rows.map { |_sy, left, _right, _src_y, _src_left, _src_right| left }.min
    max_x = rows.map { |_sy, _left, right, _src_y, _src_left, _src_right| right }.max
    min_y = rows.map { |sy, _left, _right, _src_y, _src_left, _src_right| sy }.min
    max_y = rows.map { |sy, _left, _right, _src_y, _src_left, _src_right| sy }.max
    width = max_x - min_x
    height = max_y - min_y + 1
    if !sprite.bitmap || sprite.bitmap.disposed? ||
       sprite.bitmap.width != width || sprite.bitmap.height != height
      sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
      sprite.bitmap = Bitmap.new(width, height)
    end
    sprite.bitmap.clear
    @priority_dst_rect ||= Rect.new(0, 0, 1, 1)
    @priority_src_rect ||= Rect.new(0, 0, 1, 1)
    rows.each do |sy, left, right, src_y, src_left, src_right|
      @priority_dst_rect.set(left - min_x, sy - min_y, right - left, 1)
      @priority_src_rect.set(src_left, src_y, src_right - src_left, 1)
      sprite.bitmap.stretch_blt(@priority_dst_rect, source, @priority_src_rect)
    end
    bottom_y = world_y + Game_Map::TILE_HEIGHT
    elevated_y = Mode7.project_y(bottom_y, elevation)
    ground_y = Mode7.project_y(bottom_y, 0)
    offset = elevated_y && ground_y ? elevated_y - ground_y : 0
    sprite.x = min_x
    sprite.y = min_y + (offset || 0).round
    sprite.ox = 0
    sprite.oy = 0
    sprite.zoom_x = 1.0
    sprite.zoom_y = 1.0
    true
  end

  def update_priority_surfaces
    update_priority_strips
    update_hybrid_priority_surfaces
  end

  def priority_strip_on_screen?(source, min_tx, ty, elevation)
    return false if !source || source.disposed?
    world_y = ty * Game_Map::TILE_HEIGHT
    projected = [Mode7.project_y(world_y, elevation),
                 Mode7.project_y(world_y + Game_Map::TILE_HEIGHT, elevation)].compact
    return false if projected.empty?
    return false if projected.max < 0 || projected.min > Mode7.screen_h

    sy = projected.sum / projected.length.to_f
    sy = sy.clamp(0, Mode7.screen_h - 1).round
    scale = Mode7.hscale(sy)
    return false if !scale || scale <= 0
    wx_left = Mode7.cam_x - Mode7.center_x / scale
    world_x = min_tx * Game_Map::TILE_WIDTH
    left = (world_x - wx_left) * scale
    right = (world_x + source.width - wx_left) * scale
    right >= 0 && left <= Mode7.screen_w
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
      sprite, source, min_tx, ty, priority, unify, elevation, _projection_key, _cells, hybrid_mode, state = data
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
      if !priority_strip_on_screen?(source, min_tx, ty, elevation)
        sprite.visible = false
        next
      end

      step = Mode7::Config::PRIORITY_REPROJECT_PIXELS.to_i.clamp(1, 32)
      needs_projection = !state ||
                         (Mode7.cam_x - state[0]).abs >= step ||
                         (Mode7.cam_y - state[1]).abs >= step
      if needs_projection
        if !redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation)
          sprite.visible = false
          next
        end
        anchor = priority_strip_anchor(min_tx, ty, elevation)
        data[10] = [Mode7.cam_x, Mode7.cam_y, anchor ? anchor[0] : nil,
                    anchor ? anchor[1] : nil]
        state = data[10]
      elsif state[2] && state[3]
        anchor = priority_strip_anchor(min_tx, ty, elevation)
        if anchor
          sprite.x += (anchor[0] - state[2]).round
          sprite.y += (anchor[1] - state[3]).round
          state[2] = anchor[0]
          state[3] = anchor[1]
        end
      end
      if !sprite.bitmap || sprite.bitmap.disposed? ||
         sprite.y > Mode7.screen_h || sprite.y + sprite.bitmap.height < 0 ||
         sprite.x > Mode7.screen_w || sprite.x + sprite.bitmap.width < 0
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
      sprite, _wx, wyb, _entry, priority, elevation, depth, hybrid_priority, tx, ty, source, projection_key = data

      if (tx - cam_tx).abs > radius_x || (ty - cam_ty).abs > radius_y
        sprite.visible = false
        next
      end

      camera_key = [Mode7.cam_x.round, Mode7.cam_y.round, elevation]
      if projection_key != camera_key
        if !redraw_projected_priority_surface(sprite, source, tx, ty, elevation)
          sprite.visible = false
          next
        end
        data[11] = camera_key
      end
      if !sprite.bitmap || sprite.bitmap.disposed?
        sprite.visible = false
        next
      end
      if sprite.y > Mode7.screen_h || sprite.y + sprite.bitmap.height < 0 ||
         sprite.x > Mode7.screen_w || sprite.x + sprite.bitmap.width < 0
        sprite.visible = false
        next
      end

      hybrid_active = hybrid_priority_active?(hybrid_priority, tx, ty)
      priority = hybrid_active ? hybrid_priority : 0 if hybrid_priority
      depth_wyb, depth_priority = depth || [wyb, priority]
      depth_priority = priority if hybrid_priority
      bias = depth_priority > 0 ? Mode7::Config::WALL_TOP_Z_BIAS : 0
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, bias)

      apply_depth_fog_to_sprite(sprite, sprite.y + sprite.bitmap.height)
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

        entries = collect_cell_entries(tx, ty)
        if effective_cell_has_wall?(tx, ty, entries)
          wall_layer = effective_wall_layer_unify(tx, ty, entries)
          ground_entries = entries.select do |e|
            e[:unify].to_i < wall_layer && !priority_surface_entry?(e)
          end
          blt_ground_cell(tx, ty, ground_entries) unless ground_entries.empty?
        else
          ground_entries = entries.reject { |e| priority_surface_entry?(e) }
          blt_ground_cell(tx, ty, ground_entries) unless ground_entries.empty?
        end
      end
    end

    @wall_data.each do |data|
      sprite, _wx, _wyb, h, entries, _z_behavior, _base_unify, _depth, layout = data
      next if !sprite.bitmap || sprite.bitmap.disposed?
      next if entries.none? { |e| e[:animated] }

      if layout
        draw_terrain_volume_group(sprite.bitmap, layout)
        next
      end

      sprite.bitmap.clear
      entries.sort_by { |e| [entry_world_elevation(e), e[:unify].to_i, e[:priority].to_i] }.each do |e|
        elev = entry_world_elevation(e)
        y = (h - Game_Map::TILE_HEIGHT - elev).round
        y = 0 if y < 0
        blt_entry_into(sprite.bitmap, 0, y, e, e[:opacity] || 255)
      end
    end

    @priority_strips.each do |data|
      _sprite, source, min_tx, _ty, _priority, _unify, _elevation, _projection_key, cells = data
      next if !source || source.disposed?
      next if cells.values.flatten.none? { |entry| entry[:animated] }
      draw_priority_strip_source(source, min_tx, cells)
      data[7] = nil
      data[10] = nil
    end

    @priority_data.each do |data|
      sprite, _wx, _wyb, entry, _priority, _elevation, _depth, _hybrid, _tx, _ty, source, _projection_key = data
      next if !entry[:animated]
      next if !source || source.disposed?
      source.clear
      blt_entry_into(source, 0, 0, entry, entry[:opacity] || 255)
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
      sprite, wx, wyb, h, entries, _z_behavior, _base_unify, depth, _layout = data

      wt = wx / Game_Map::TILE_WIDTH
      wty = (wyb - Game_Map::TILE_HEIGHT / 2.0) / Game_Map::TILE_HEIGHT
      if (wt - cam_tx).abs > radius_x || (wty - cam_ty).abs > radius_y
        sprite.visible = false
        next
      end

      pr = Mode7.project(wx, wyb, 0)
      if !pr
        sprite.visible = false
        next
      end
      sx, syb = pr

      # Un muro es una cara vertical, no una franja del suelo. Su pixel art
      # conserva proporcion: zoom_x == zoom_y. La escala uniforme coincide con
      # la separacion horizontal de la fila para evitar grietas entre columnas.
      k = Mode7.tile_billboard_scale_for_world_y(wyb)
      if !k || k <= 0
        sprite.visible = false
        next
      end

      half_width = sprite.bitmap.width * k / 2.0
      if syb < -h * k - Game_Map::TILE_HEIGHT ||
         syb > Mode7.screen_h + Game_Map::TILE_HEIGHT ||
         sx < -half_width - Game_Map::TILE_WIDTH ||
         sx > Mode7.screen_w + half_width + Game_Map::TILE_WIDTH
        sprite.visible = false
        next
      end

      sprite.x = sx
      sprite.y = syb
      sprite.zoom_x = k
      sprite.zoom_y = k
      priority = entries.map { |entry| entry_visual_priority(entry) }.max || 0
      depth_wyb, depth_priority = depth || [wyb, priority]
      bias = depth_priority > 0 ? Mode7::Config::WALL_TOP_Z_BIAS : 0
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, bias)

      apply_depth_fog_to_sprite(sprite, syb)
      sprite.visible = true
    end
  end
end
