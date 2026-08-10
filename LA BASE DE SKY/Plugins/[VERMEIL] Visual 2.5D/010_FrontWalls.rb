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

  # ---------------------------------------------------------------------------
  # Ownership visual de walls normales
  # ---------------------------------------------------------------------------
  # Una celda con Terrain Tag wall tiene una unica ruta visual:
  #   wall sprite fijo
  #
  # Nunca puede dibujarse tambien en @ground o @priority_strips. Esto elimina
  # los duplicados que aparecian cuando P0 quedaba horneado en el suelo y P1
  # salia como otra superficie.
  def wall_visual_base_unify(entries)
    direct = entries.select do |entry|
      entry_is_wall?(entry) && !entry_is_elevated_wall?(entry)
    end
    return nil if direct.empty?
    direct.map { |entry| entry[:unify].to_i }.min
  end

  def wall_visual_entries(entries)
    return [] if !entries || entries.empty?
    base = wall_visual_base_unify(entries)
    return [] if base.nil?

    entries.select do |entry|
      next false if entry_is_elevated_wall?(entry)
      next false if interior_border_entry?(entry)
      next false if entry_hybrid_priority(entry)
      entry[:unify].to_i >= base
    end
  rescue Exception
    []
  end




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
      elevated_wall_cell = entries.any? { |entry| entry_is_elevated_wall?(entry) }
      height = 0 if wall_cell
      entries.each do |entry|
        entry[:terrain_tag_height] = height
        entry[:terrain_height_wall_cell] = true if wall_cell
        entry[:terrain_height_elevated_wall_cell] = true if elevated_wall_cell
      end
    end
  end

  def entry_terrain_tag_height(e)
    return e[:terrain_tag_height].to_i if e.key?(:terrain_tag_height)
    configured_terrain_tag_height(e)
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



  def wall_component_signature(entries)
    direct = entries.select do |entry|
      entry_is_wall?(entry) && !entry_is_elevated_wall?(entry)
    end
    tags = direct.map do |entry|
      tag = terrain_tag_for_entry(entry)
      tag ? tag.id : :None
    end.compact.uniq.sort_by(&:to_s)
    [tags, wall_visual_base_unify(entries)]
  end

  def wall_component_key(tx, ty, entries)
    if defined?(Mode7::VolumeIds)
      begin
        id = Mode7::VolumeIds.id_for(@map_id, tx, ty)
        return [:volume, id] if id
      rescue Exception
      end
    end
    [:auto, wall_component_signature(entries)]
  end

  # Agrupa SOLO celdas que ya pertenecen al renderer wall. Nunca incorpora
  # soporte/suelo/vecinos por heuristica. Eso permite tratar un edificio/arbol
  # como bloque rigido sin contagiar tiles adyacentes.
  def wall_visual_components
    Mode7::VolumeIds.refresh if defined?(Mode7::VolumeIds) rescue nil

    cells = {}
    keys = {}
    @entry_cache.each do |position, entries|
      owned = wall_visual_entries(entries)
      next if owned.empty?
      tx, ty = position
      cells[position] = owned
      keys[position] = wall_component_key(tx, ty, entries)
    end

    pending = {}
    cells.each_key { |position| pending[position] = true }
    result = []

    until pending.empty?
      start = pending.keys.first
      pending.delete(start)
      wanted_key = keys[start]
      stack = [start]
      component = {}

      until stack.empty?
        tx, ty = stack.pop
        pos = [tx, ty]
        component[pos] = cells[pos]

        [[tx - 1, ty], [tx + 1, ty], [tx, ty - 1], [tx, ty + 1]].each do |neighbor|
          next if !pending[neighbor]
          next if keys[neighbor] != wanted_key
          pending.delete(neighbor)
          stack.push(neighbor)
        end
      end

      result.push(component)
    end
    result
  end

  def build_wall_columns
    # Colision se calcula por celda y nunca depende de como se agrupa el dibujo.
    @entry_cache.each do |(tx, ty), entries|
      direct_walls = entries.select { |entry| entry_is_wall?(entry) }
      next if direct_walls.empty?
      blocking = direct_walls.select { |entry| entry_blocks_movement?(entry) }
      next if blocking.empty?
      next if ladder_overrides_wall_collision?(entries, blocking)
      @wall_cells[[tx, ty]] = true
    end

    # Dibujo: cada componente visual usa UNOS bounds rigidos. Se separa por
    # fila/priority/layer solo para Z, pero todos esos sprites comparten el
    # mismo bitmap-space, ancla y escala. Por tanto el bloque no se deforma.
    wall_visual_components.each do |component|
      bounds = component.keys
      groups = Hash.new { |hash, key| hash[key] = {} }

      component.each do |(tx, ty), entries|
        entries.each do |entry|
          key = [
            ty,
            entry_visual_priority(entry),
            entry[:unify].to_i,
            entry_world_elevation(entry).to_f
          ]
          groups[key][[tx, ty]] ||= []
          groups[key][[tx, ty]].push(entry)
        end
      end

      groups.each do |(depth_ty, priority, unify, elevation), group_cells|
        depth_wyb = (depth_ty + 1) * Game_Map::TILE_HEIGHT
        make_wall_component(
          group_cells,
          elevation,
          bounds,
          priority,
          unify,
          depth_wyb
        )
      end
    end
  rescue Exception => e
    Console.echo_error("2.5D: build_wall_columns: #{e.message}") if defined?(Console)
  end
  def build_priority_surfaces
    strips = Hash.new { |hash, key| hash[key] = {} }

    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]
        wall_owned = wall_visual_entries(entries)

        entries.each do |entry|
          next if wall_owned.include?(entry)
          next if !priority_surface_entry?(entry)

          hybrid = entry_hybrid_priority(entry)
          elevation = entry_world_elevation(entry)

          if hybrid
            elevation += entry_hybrid_height(entry)
            base_key = [:hybrid_base, entry[:unify].to_i, 0, ty, elevation]
            top_key  = [:hybrid_top, entry[:unify].to_i, hybrid.to_i, ty, elevation]
            strips[base_key][tx] ||= []
            strips[base_key][tx].push(entry)
            strips[top_key][tx] ||= []
            strips[top_key][tx].push(entry)
            next
          end

          key = [:normal, entry[:unify].to_i, entry_visual_priority(entry), ty,
                 elevation]
          strips[key][tx] ||= []
          strips[key][tx].push(entry)
        end
      end
    end

    strips.each do |(kind, unify, priority, ty, elevation), row|
      segment = {}
      previous = nil
      row.keys.sort.each do |tx|
        if previous && tx != previous + 1
          make_priority_strip(segment, ty, priority, unify, elevation, kind)
          segment = {}
        end
        segment[tx] = row[tx]
        previous = tx
      end
      make_priority_strip(segment, ty, priority, unify, elevation, kind) if !segment.empty?
    end
  end
  def build_interior_border_surfaces
    @map.width.times do |tx|
      @map.height.times do |ty|
        @entry_cache[[tx, ty]].each do |entry|
          next if !interior_border_entry?(entry)
          # InteriorBorder conserva su estrella nativa. Forzarlo a P0 hacia
          # que un borde P4/P6 quedara debajo del actor aunque Maker lo guarde.
          depth = [(ty + 1) * Game_Map::TILE_HEIGHT,
                   entry_visual_priority(entry), entry[:unify].to_i]
          make_priority_surface(tx, ty, entry, depth, true)
        end
      end
    end
  end

  # Agrupa solo vecinos ortogonales con mismo layer, prioridad y elevacion.
  # ponytail: sin ID manual; separar arte contiguo distinto requeriria metadata.





  def entry_world_elevation(e)
    elevation = e.key?(:elevation) && !e[:elevation].nil? ? e[:elevation].to_f : 0.0
    elevation + entry_terrain_tag_height(e)
  end

  # Columna fisica de UNA celda. Forma original del volumen 2.5D: nunca usa
  # filas vecinas como alto, por eso no arrastra ni corta bloques al mover Y.

  def make_wall_component(cells, elevation = 0, bounds = nil,
                          priority = nil, unify = nil, depth_wyb = nil)
    positions = bounds || cells.keys
    return if positions.empty?

    min_tx = positions.map { |tx, _ty| tx }.min
    max_tx = positions.map { |tx, _ty| tx }.max
    min_ty = positions.map { |_tx, ty| ty }.min
    max_ty = positions.map { |_tx, ty| ty }.max

    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
    height = (max_ty - min_ty + 1) * Game_Map::TILE_HEIGHT
    bitmap = Bitmap.new(width, height)
    draw_wall_component_base_source(bitmap, min_tx, min_ty, cells)

    all_entries = cells.values.flatten
    priority = all_entries.map { |entry| entry_visual_priority(entry) }.max || 0 if priority.nil?
    unify = all_entries.map { |entry| entry[:unify].to_i }.min || 0 if unify.nil?
    depth_wyb ||= (max_ty + 1) * Game_Map::TILE_HEIGHT

    sprite = Sprite.new(@viewport)
    sprite.bitmap = bitmap
    sprite.ox = width / 2.0
    sprite.oy = height
    sprite.visible = false

    wx = min_tx * Game_Map::TILE_WIDTH + width / 2.0
    wyb = (max_ty + 1) * Game_Map::TILE_HEIGHT
    depth = [depth_wyb, priority, unify]

    @wall_data.push([
      sprite, wx, wyb, height, cells, :component, unify, depth,
      0, min_tx, min_ty, max_tx, max_ty, elevation
    ])
  end
  def draw_wall_component_base_source(dst, min_tx, min_ty, cells)
    dst.clear
    cells.keys.sort_by { |tx, ty| [ty, tx] }.each do |tx, ty|
      x = (tx - min_tx) * Game_Map::TILE_WIDTH
      y = (ty - min_ty) * Game_Map::TILE_HEIGHT
      cells[[tx, ty]].sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }.each do |entry|
        blt_entry_into(dst, x, y, entry, entry[:opacity] || 255)
      end
    end
  end



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
  def make_priority_strip(cells, ty, priority, unify, elevation, kind = :normal)
    return if !cells || cells.empty?
    min_tx = cells.keys.min
    max_tx = cells.keys.max
    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
    source = Bitmap.new(width, Game_Map::TILE_HEIGHT)

    mountain_shadow = priority <= 0 && cells.values.flatten.any? do |entry|
      entry_is_elevated_wall?(entry) && mountain_shadow_opacity_for([entry]) > 0
    end
    draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow)

    sprite = Sprite.new(@viewport)
    sprite.bitmap = source
    sprite.ox = 0
    sprite.oy = source.height
    sprite.visible = false

    hybrid_mode = kind == :normal ? nil : kind
    @priority_strips.push([
      sprite, source, min_tx, ty, priority, unify, elevation,
      cells, hybrid_mode, nil, mountain_shadow
    ])
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



  def make_priority_surface(tx, ty, entry, depth = nil, force = false)
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
    @priority_data.push([
      sprite, wx, wyb, entry, entry_visual_priority(entry),
      entry_world_elevation(entry), depth, tx, ty, source, nil
    ])
  end
  def redraw_projected_priority_surface(sprite, source, wx, wyb, elevation = 0)
    return false if !source || source.disposed?

    world_top = wyb - source.height
    top = Mode7.project_y(world_top, elevation)
    bottom = Mode7.project_y(wyb, elevation)
    return false if top.nil? || bottom.nil?
    height = bottom - top
    return false if height <= 0.001

    middle = (top + bottom) / 2.0
    scale_x = Mode7.hscale(middle)
    return false if !scale_x || scale_x <= 0.001

    overlap = Mode7.priority_edge_overlap
    width = source.width * scale_x
    sx = Mode7.center_x + (wx.to_f - Mode7.cam_x) * scale_x

    sprite.bitmap = source if sprite.bitmap != source
    sprite.ox = source.width / 2.0
    sprite.oy = source.height
    sprite.x = sx
    sprite.y = bottom + overlap * 0.50
    sprite.zoom_x = (width + overlap) / source.width.to_f
    sprite.zoom_y = (height + overlap) / source.height.to_f
    true
  end








  def priority_strip_geometry(source, min_tx, ty, elevation = 0)
    return nil if !source || source.disposed?

    world_top = ty * Game_Map::TILE_HEIGHT
    world_bottom = world_top + Game_Map::TILE_HEIGHT
    top = Mode7.project_y(world_top, elevation)
    bottom = Mode7.project_y(world_bottom, elevation)
    return nil if top.nil? || bottom.nil?

    height = bottom - top
    return nil if height <= 0.001

    middle = (top + bottom) / 2.0
    scale_x = Mode7.hscale(middle)
    return nil if !scale_x || scale_x <= 0.001

    world_left = min_tx * Game_Map::TILE_WIDTH
    left = Mode7.center_x + (world_left - Mode7.cam_x) * scale_x
    width = source.width * scale_x

    overlap = Mode7.priority_edge_overlap
    h_overlap = overlap * 0.50
    v_overlap = overlap

    [
      left - h_overlap,
      top - v_overlap * 0.50,
      width + h_overlap * 2.0,
      height + v_overlap,
      bottom + v_overlap * 0.50
    ]
  end

  def redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation = 0)
    geometry = priority_strip_geometry(source, min_tx, ty, elevation)
    return false if !geometry

    left, _top, width, height, bottom = geometry
    sprite.bitmap = source if sprite.bitmap != source
    sprite.ox = 0
    sprite.oy = source.height
    sprite.x = left
    sprite.y = bottom
    sprite.zoom_x = width / source.width.to_f
    sprite.zoom_y = height / source.height.to_f
    true
  end
  def update_priority_surfaces
    update_priority_strips
    update_priority_objects
  end
  def priority_strip_on_screen?(source, min_tx, ty, elevation = 0)
    geometry = priority_strip_geometry(source, min_tx, ty, elevation)
    return false if !geometry
    left, top, width, height, _bottom = geometry
    right = left + width
    bottom = top + height
    right >= 0 && left <= Mode7.screen_w &&
      bottom >= 0 && top <= Mode7.screen_h
  end

  def update_priority_strips
    return if !@priority_strips
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ?
               Mode7::Config::WALL_SPAWN_RADIUS_Y : 34

    @priority_strips.each do |data|
      sprite, source, min_tx, ty, priority, unify, elevation,
      _cells, hybrid_mode, _projection_state, _mountain_shadow = data

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
      if !redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation)
        sprite.visible = false
        next
      end

      effective_priority = priority
      bias = unify + (effective_priority > 0 ? Mode7::Config::WALL_TOP_Z_BIAS : 0)
      sprite.z = Mode7.depth_z(
        (ty + 1) * Game_Map::TILE_HEIGHT,
        effective_priority,
        bias
      )

      top = sprite.y - sprite.oy * sprite.zoom_y
      apply_depth_fog_to_sprite(sprite, sprite.y)
      sprite.visible = !(top > Mode7.screen_h || sprite.y < 0)
    end
  end
  # Priority sprites que no pertenecen a strips (actualmente InteriorBorder).
  # La geometria y el Z se recalculan con el angulo/zoom actual.
  def update_priority_objects
    return if !@priority_data
    cam_tx = Mode7.cam_x / Game_Map::TILE_WIDTH
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT
    radius_x = defined?(Mode7::Config::WALL_SPAWN_RADIUS_X) ?
               Mode7::Config::WALL_SPAWN_RADIUS_X : 26
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ?
               Mode7::Config::WALL_SPAWN_RADIUS_Y : 34

    @priority_data.each do |data|
      sprite, wx, wyb, _entry, priority, elevation, depth,
      tx, ty, source, projection_key = data

      if tx < cam_tx - radius_x || tx > cam_tx + radius_x ||
         ty < cam_ty - radius_y || ty > cam_ty + radius_y
        sprite.visible = false
        next
      end

      needs_projection = !projection_key ||
                         (Mode7.cam_x - projection_key[0]).abs >= 0.5 ||
                         (Mode7.projection_cam_y - projection_key[1]).abs >= 0.5 ||
                         projection_key[2] != Mode7.projection_revision
      if needs_projection
        if !redraw_projected_priority_surface(sprite, source, wx, wyb, elevation)
          sprite.visible = false
          next
        end
        data[10] = [Mode7.cam_x, Mode7.projection_cam_y, Mode7.projection_revision]
      end

      top = sprite.y - sprite.oy * sprite.zoom_y
      left = sprite.x - sprite.ox * sprite.zoom_x
      right = left + sprite.bitmap.width * sprite.zoom_x
      if top > Mode7.screen_h || sprite.y < 0 ||
         left > Mode7.screen_w || right < 0
        sprite.visible = false
        next
      end

      depth_wyb, depth_priority, depth_unify = depth || [wyb, priority, 0]
      bias = depth_unify.to_i
      bias += Mode7::Config::WALL_TOP_Z_BIAS if depth_priority.to_i > 0
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, bias)

      apply_depth_fog_to_sprite(sprite, sprite.y)
      sprite.visible = true
    end
  end
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
      sprite, _wx, _wyb, _h, entries, _z_behavior, _base_unify, _depth,
      _shadow_opacity, min_tx, min_ty = data
      next if !sprite.bitmap || sprite.bitmap.disposed?
      next if !entries.is_a?(Hash)
      next if entries.values.flatten.none? { |entry| entry[:animated] }
      draw_wall_component_base_source(sprite.bitmap, min_tx, min_ty, entries)
    end

    @priority_strips.each do |data|
      _sprite, source, min_tx, ty, _priority, _unify, _elevation,
      cells, _hybrid_mode, _projection_state, mountain_shadow = data
      next if !source || source.disposed?
      next if cells.values.flatten.none? { |entry| entry[:animated] }
      draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow)
      data[9] = nil
    end

    @priority_data.each do |data|
      _sprite, _wx, _wyb, entry, _priority, _elevation, _depth,
      _tx, _ty, source = data
      next if !source || source.disposed?
      next if !entry || !entry[:animated]
      source.clear
      blt_entry_into(source, 0, 0, entry, entry[:opacity] || 255)
      data[10] = nil
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

    radius_x = defined?(Mode7::Config::WALL_SPAWN_RADIUS_X) ?
               Mode7::Config::WALL_SPAWN_RADIUS_X : 26
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ?
               Mode7::Config::WALL_SPAWN_RADIUS_Y : 34

    @wall_data.each do |data|
      sprite, wx, wyb, h, _entries, _z_behavior, _base_unify, depth,
      _shadow_opacity, min_tx, min_ty, max_tx, max_ty, elevation = data

      min_tx ||= ((wx - sprite.bitmap.width / 2.0) / Game_Map::TILE_WIDTH).floor
      max_tx ||= ((wx + sprite.bitmap.width / 2.0) / Game_Map::TILE_WIDTH).ceil
      min_ty ||= ((wyb - h) / Game_Map::TILE_HEIGHT).floor
      max_ty ||= (wyb / Game_Map::TILE_HEIGHT).ceil

      if max_tx < cam_tx - radius_x || min_tx > cam_tx + radius_x ||
         max_ty < cam_ty - radius_y || min_ty > cam_ty + radius_y
        sprite.visible = false
        next
      end

      elevation = elevation.to_f
      projected = Mode7.project(wx, wyb, elevation)
      if !projected
        sprite.visible = false
        next
      end

      sx, syb = projected

      # El wall es un BLOQUE rigido: la perspectiva solo mueve el ancla.
      # El zoom de camara escala X/Y por igual; la profundidad NO cambia su
      # relacion de aspecto ni hace que filas internas se separen.
      fixed_scale = Mode7.zoom.to_f
      fixed_scale = 0.001 if fixed_scale <= 0.001

      half_width = sprite.bitmap.width * fixed_scale / 2.0
      screen_height = sprite.bitmap.height * fixed_scale
      top_y = syb - screen_height

      if syb < -Game_Map::TILE_HEIGHT ||
         top_y > Mode7.screen_h + Game_Map::TILE_HEIGHT ||
         sx < -half_width - Game_Map::TILE_WIDTH ||
         sx > Mode7.screen_w + half_width + Game_Map::TILE_WIDTH
        sprite.visible = false
        next
      end

      sprite.x = sx
      sprite.y = syb
      sprite.zoom_x = fixed_scale
      sprite.zoom_y = fixed_scale

      depth_wyb, depth_priority, depth_unify = depth || [wyb, 0, 0]
      bias = depth_unify.to_i
      bias += Mode7::Config::WALL_TOP_Z_BIAS if depth_priority.to_i > 0
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, bias)

      apply_depth_fog_to_sprite(sprite, syb)
      sprite.visible = true
    end
  end
end
