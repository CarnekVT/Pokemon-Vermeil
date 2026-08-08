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
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]
        next if !effective_cell_has_wall?(tx, ty, entries)
        direct_walls = entries.select { |entry| entry_is_wall?(entry) }
        @wall_cells[[tx, ty]] = true if direct_walls.any? { |entry| entry_blocks_movement?(entry) }
        wall_layer = effective_wall_layer_unify(tx, ty, entries)
        wall_entries = entries.select do |entry|
          entry[:unify].to_i >= wall_layer && !priority_surface_entry?(entry)
        end
        next if wall_entries.empty?

        # Base P0 y cada P1+ son sprites separados. Un P4 dentro de Mountain no
        # puede elevar visualmente Mountain, Layer 1 ni celdas adyacentes.
        base_entries = wall_entries.select { |entry| entry_visual_priority(entry) <= 0 }
        if !base_entries.empty?
          unify = base_entries.map { |entry| entry[:unify].to_i }.max || 0
          depth = [(ty + 1) * Game_Map::TILE_HEIGHT, 0, unify]
          shadow_opacity = mountain_shadow_opacity_for(base_entries)
          make_wall_column(tx, ty, base_entries, unify, :dynamic, depth, shadow_opacity)
        end
        wall_entries.each do |entry|
          priority = entry_visual_priority(entry)
          next if priority <= 0
          unify = entry[:unify].to_i
          depth = [(ty + 1) * Game_Map::TILE_HEIGHT, priority, unify]
          make_wall_column(tx, ty, [entry], unify, :dynamic, depth)
        end
      rescue Exception
        Console.echo_error("2.5D: columna fallida en (#{tx},#{ty})") if defined?(Console)
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
  def blt_mountain_surface_shadow(dst, tx, ty, entries, opacity)
    return if tx.nil? || ty.nil? || !@shadow_ground || @shadow_ground.disposed?
    return if entries.any? { |entry| shadow_source_entry?(tx, ty, entry) }
    @src_rect.set(tx * Game_Map::TILE_WIDTH, ty * Game_Map::TILE_HEIGHT,
                  Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
    dst.blt(0, dst.height - Game_Map::TILE_HEIGHT, @shadow_ground, @src_rect,
            opacity.to_i.clamp(0, 255))
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

      x_step = Mode7::Config::PRIORITY_REPROJECT_PIXELS.to_i.clamp(1, 32)
      y_step = Mode7::Config::PRIORITY_VERTICAL_REPROJECT_PIXELS.to_i.clamp(1, 32)
      vertical_changed = true
      if state
        vertical_delta = (Mode7.cam_y - state[1]).abs
        vertical_changed = y_step <= 1 ? vertical_delta > 0.001 : vertical_delta >= y_step
      end
      needs_projection = !state ||
                         (Mode7.cam_x - state[0]).abs >= x_step ||
                         vertical_changed
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

        redraw_ground_cell(tx, ty)
      end
    end

    @wall_data.each do |data|
      sprite, wx, wyb, _h, entries, _z_behavior, _base_unify, _depth, shadow_opacity = data
      next if !sprite.bitmap || sprite.bitmap.disposed?
      next if entries.none? { |entry| entry[:animated] }

      sprite.bitmap.clear
      tx = ((wx - Game_Map::TILE_WIDTH / 2.0) / Game_Map::TILE_WIDTH).round
      ty = (wyb / Game_Map::TILE_HEIGHT - 1).round
      draw_wall_column_source(sprite.bitmap, entries, tx, ty, shadow_opacity)
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
      sprite, wx, wyb, h, _entries, _z_behavior, _base_unify, depth = data

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

      half_width = half_w * k
      top_y = syb - h * k
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
      sprite.zoom_y = k
      depth_wyb, depth_priority, depth_unify = depth || [wyb, 0, 0]
      bias = depth_unify.to_i
      bias += Mode7::Config::WALL_TOP_Z_BIAS if depth_priority > 0
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, bias)

      apply_depth_fog_to_sprite(sprite, syb)
      sprite.visible = true
    end
  end
end
