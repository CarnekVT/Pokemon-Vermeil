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
    @entry_cache.each do |(tx, ty), entries|
      cap = -1
      if defined?(MakerStudio) && MakerStudio.respond_to?(:cell_ground_cap)
        cap = MakerStudio.cell_ground_cap(@map, tx, ty)
      end
      entries.each do |entry|
        own = entry[:priority].to_i
        entry[:visual_priority] = own >= 1 && entry[:unify].to_i > cap ? own : 0
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

  # Borde de sala: superficie del piso. Un billboard comparte una sola base y
  # se despega de pasillos/zonas curvas; el tag evita que wall/prioridad lo tome.
  def interior_border_entry?(entry)
    tag = terrain_tag_for_entry(entry)
    return false if !tag || tag.id == :None
    Mode7::Config::INTERIOR_BORDER_TERRAIN_TAGS.key?(tag.id)
  end

  def interior_prop_entry?(entry)
    return false if !Mode7.indoor_map?
    tag = terrain_tag_for_entry(entry)
    return false if !tag || tag.id == :None
    Mode7::Config::INDOOR_PROP_TERRAIN_TAGS.key?(tag.id)
  end

  # Delimitacion interior/exterior. Su layer/prioridad decide el orden visual.
  def interior_black_entry?(entry)
    return false if !Mode7.indoor_map?
    tag = terrain_tag_for_entry(entry)
    return false if !tag || tag.id == :None
    Mode7::Config::INDOOR_BLACK_TERRAIN_TAGS.key?(tag.id)
  end

  # Mountains/Ladders son tiles normales para el renderer 2.5D.
  def entry_is_elevated_wall?(_entry); false; end
  def mountain_shadow_opacity_for(_entries); 0; end

  def resolve_projection_from_indoor_tags
    return if !defined?(Mode7::Config::INDOOR_DETECT_FROM_TERRAIN_TAGS)
    return if !Mode7::Config::INDOOR_DETECT_FROM_TERRAIN_TAGS
    return if Mode7.respond_to?(:projection_override) && Mode7.projection_override

    indoor_tags = {}
    Mode7::Config::INDOOR_WALL_TERRAIN_TAG_HEIGHT.each_key { |id| indoor_tags[id] = true }
    Mode7::Config::INTERIOR_BORDER_TERRAIN_TAGS.each_key { |id| indoor_tags[id] = true }
    Mode7::Config::INDOOR_PROP_TERRAIN_TAGS.each_key { |id| indoor_tags[id] = true }
    Mode7::Config::INDOOR_BLACK_TERRAIN_TAGS.each_key { |id| indoor_tags[id] = true }

    found = @entry_cache.any? do |_position, entries|
      entries.any? do |entry|
        tag = terrain_tag_for_entry(entry)
        tag && indoor_tags[tag.id]
      end
    end

    # El flag hace que indoor_map? responda TRUE aunque la metadata externa no
    # exponga Outside/Outdoor. Debe ir ANTES del return-by-projection para que
    # el angulo y raster_affine se resuelvan por tags tambien.
    Mode7.tag_indoor_map_id = found ? @map_id : nil
    return if !found

    # El setup pudo aplicar OUTDOOR_DEFAULT_ALPHA antes de esta deteccion
    # (aun no se sabia que el mapa era indoor). Reaplicar el angulo del
    # contexto rencien resuelto para que el mapa indoor-por-tags no arranque
    # con la inclinacion equivocada.
    if Mode7.active_now? && Mode7.indoor_map?
      Mode7.set_camera(Mode7.context_default_alpha, Mode7.camera_zoom,
                       0, Mode7.distance_h, Mode7.cylindrical_radius)
    end
    return if Mode7.map_projection == :affine
    Mode7.map_projection = :affine
    Mode7.reset_caches
  rescue Exception
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
      next false if interior_black_entry?(entry)
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
      # Un terrain-tag de wall ya tiene su renderer propio; no elevar la celda.
      height = 0 if entries.any? { |entry| entry_is_wall?(entry) }
      entries.each { |entry| entry[:terrain_tag_height] = height }
    end
  end

  def entry_terrain_tag_height(e)
    return e[:terrain_tag_height].to_i if e.key?(:terrain_tag_height)
    configured_terrain_tag_height(e)
  end



  def priority_surface_entry?(e)
    return false if !Mode7::Config::PRIORITY_SURFACES
    p = entry_visual_priority(e)
    min = Mode7::Config::PRIORITY_SURFACE_MIN.to_i
    return true if interior_black_entry?(e)

    if Mode7.raster_affine_mode?
      return true if interior_border_entry?(e)
      # IndoorProp usa un bloque rigido de escala constante.
      return false if indoor_prop_owned?(e)
    end

    return false if interior_border_entry?(e)
    return true if entry_terrain_tag_height(e) > 0
    return false if p < min
    return false if p == 1 && Mode7Renderer.debug_mode_force_priority_1_as_ground?
    true
  end



  def wall_component_signature(entries)
    direct = entries.any? do |entry|
      entry_is_wall?(entry) && !entry_is_elevated_wall?(entry)
    end
    direct ? [:normal_wall] : []
  end

  def wall_component_key(tx, ty, entries)
    if defined?(Mode7::VolumeIds)
      begin
        id = Mode7::VolumeIds.id_for(@map_id, tx, ty)
        return [:volume, id] if id
      rescue Exception
      end
    end

    direct = entries.select do |entry|
      entry_is_wall?(entry) && !entry_is_elevated_wall?(entry)
    end
    return [:cell, tx, ty] if direct.empty?
    seed = direct.min_by { |entry| entry[:unify].to_i }
    [:auto, rigid_priority_object_key(tx, ty, seed)]
  end

  # Componente wall visual.
  #
  # Las celdas con Terrain Tag wall son las semillas. Una pieza P1-P4 vecina
  # puede incorporarse aunque NO repita el tag, pero solo si su rect fuente es
  # realmente contiguo en el mismo tileset/autotile. Esto mantiene unido el
  # techo/P4 de un edificio sin absorber props adyacentes por simple cercania.
  def wall_source_key(entry)
    return [:tileset, entry[:tileset_id].to_i] if entry[:tileset_id]
    filename = entry[:filename]
    return [:autotile, filename.to_s] if filename && !filename.to_s.empty?
    bmp = entry[:bitmap]
    [:bitmap, bmp ? bmp.object_id : 0]
  end

  def wall_source_contiguous?(a, b, dx, dy)
    return false if wall_source_key(a) != wall_source_key(b)
    ra = a[:src_rect]
    rb = b[:src_rect]
    return false if !ra || !rb
    (rb.x - ra.x) == dx * Game_Map::TILE_WIDTH &&
      (rb.y - ra.y) == dy * Game_Map::TILE_HEIGHT
  rescue Exception
    false
  end

  def wall_extension_candidate?(entries, entry)
    return false if interior_border_entry?(entry)
    return false if interior_black_entry?(entry)
    return false if entry_is_elevated_wall?(entry)
    return false if entry_is_wall?(entry)
    return false if interior_prop_entry?(entry)
    entry_visual_priority(entry) > 0
  end

  def cache_wall_visual_components
    Mode7::VolumeIds.refresh if defined?(Mode7::VolumeIds) rescue nil

    seed_cells = {}
    keys = {}
    @entry_cache.each do |position, entries|
      owned = wall_visual_entries(entries)
      next if owned.empty?
      tx, ty = position
      seed_cells[position] = owned
      keys[position] = wall_component_key(tx, ty, entries)
    end

    pending = {}
    seed_cells.each_key { |position| pending[position] = true }
    components = []
    claimed_extensions = {}

    until pending.empty?
      start_pos = pending.keys.first
      pending.delete(start_pos)
      wanted_key = keys[start_pos]
      stack = [start_pos]
      component = {}

      # Primero une exclusivamente las celdas wall reales.
      until stack.empty?
        tx, ty = stack.pop
        pos = [tx, ty]
        component[pos] ||= []
        component[pos].concat(seed_cells[pos])

        [[tx - 1, ty], [tx + 1, ty], [tx, ty - 1], [tx, ty + 1]].each do |neighbor|
          next if !pending[neighbor]
          next if keys[neighbor] != wanted_key
          pending.delete(neighbor)
          stack.push(neighbor)
        end
      end

      # Luego extiende P1-P4 que pertenezca visualmente al mismo dibujo.
      queue = []
      component.each do |position, entries|
        entries.each { |entry| queue.push([position, entry]) }
      end

      until queue.empty?
        (tx, ty), source_entry = queue.shift
        [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |dx, dy|
          npos = [tx + dx, ty + dy]
          nentries = @entry_cache[npos]
          next if !nentries

          nentries.each do |candidate|
            oid = candidate.object_id
            next if claimed_extensions[oid]
            next if !wall_extension_candidate?(nentries, candidate)
            next if !wall_source_contiguous?(source_entry, candidate, dx, dy)

            component[npos] ||= []
            component[npos].push(candidate)
            claimed_extensions[oid] = true
            queue.push([npos, candidate])
          end
        end
      end

      components.push(component)
    end

    @wall_visual_components = components
    @wall_visual_owned = {}
    components.each do |component|
      component.each_value do |entries|
        entries.each { |entry| @wall_visual_owned[entry.object_id] = true }
      end
    end
    components
  end

  def wall_visual_components
    @wall_visual_components || cache_wall_visual_components
  end

  def wall_visual_owned?(entry)
    @wall_visual_owned && @wall_visual_owned[entry.object_id]
  end

  def build_wall_columns
    # Colision se calcula por celda y nunca depende de como se agrupa el dibujo.
    @entry_cache.each do |(tx, ty), entries|
      direct_walls = entries.select { |entry| entry_is_wall?(entry) }
      next if direct_walls.empty?
      blocking = direct_walls.select { |entry| entry_blocks_movement?(entry) }
      next if blocking.empty?
      @wall_cells[[tx, ty]] = true
    end

    # Todas las prioridades de un wall comparten EXACTAMENTE:
    #   bounds, world-Y de base, elevacion y escala.
    #
    # Priority/unify solo decide Z. P4 ya no puede proyectarse como otro bloque
    # aunque su Terrain Tag no se repita en la fila superior.
    wall_visual_components.each do |component|
      bounds = component.keys
      all_entries = component.values.flatten
      next if all_entries.empty?

      component_elevation = all_entries.map { |entry| entry_world_elevation(entry) }.min || 0.0
      depth_ty = bounds.map { |_tx, ty| ty }.max
      depth_wyb = (depth_ty + 1) * Game_Map::TILE_HEIGHT

      groups = Hash.new { |hash, priority| hash[priority] = {} }
      component.each do |position, entries|
        entries.each do |entry|
          priority = entry_visual_priority(entry)
          groups[priority][position] ||= []
          groups[priority][position].push(entry)
        end
      end

      groups.each do |priority, group_cells|
        unifies = group_cells.values.flatten.map { |entry| entry[:unify].to_i }
        unify = unifies.empty? ? 0 : unifies.min
        make_rigid_component(
          group_cells,
          component_elevation,
          bounds,
          priority,
          unify,
          depth_wyb,
          :wall_component
        )
      end
    end
  rescue Exception => e
    Console.echo_error("2.5D: build_wall_columns: #{e.message}") if defined?(Console)
  end
  # ---------------------------------------------------------------------------
  # Priority P1/P2+ como objetos rigidos, aislados por contexto de superficie
  # ---------------------------------------------------------------------------
  # El bug de v1.7.0 era doble:
  #   * P2+ se agrupaba ignorando si la celda estaba sobre Mountains;
  #   * P1 del mismo objeto quedaba en un strip curvo separado.
  #
  # Resultado: al lado/sobre Mountains un arbol/prop podia usar bounds de otro
  # contexto y, ademas, abrir una junta exacta entre su fila P1 y sus P2+.
  #
  # Ahora Mountains/Ladders forman una FRONTERA de componente. P1 solo se
  # absorbe una fila alrededor de un componente que tenga P2+ real; nunca sirve
  # como puente para unir objetos lejanos o un campo entero de P1.
  def rigid_priority_member_candidate?(entries, entry)
    return false if interior_border_entry?(entry)
    return false if interior_black_entry?(entry)
    return false if entry_is_elevated_wall?(entry)
    return false if wall_visual_owned?(entry)
    entry_visual_priority(entry) >= Mode7::Config::PRIORITY_SURFACE_MIN.to_i
  end

  def rigid_priority_seed?(entries, entry)
    return false if !rigid_priority_member_candidate?(entries, entry)
    entry_visual_priority(entry) >= Mode7::Config::PRIORITY_RIGID_MIN.to_i
  end

  def rigid_priority_source_key(entry)
    if entry[:tileset_id]
      return [:tileset, entry[:tileset_id].to_i]
    end
    filename = entry[:filename]
    return [:autotile, filename.to_s] if filename && !filename.to_s.empty?
    bmp = entry[:bitmap]
    [:bitmap, bmp ? bmp.object_id : 0]
  end

  def rigid_priority_volume_id(tx, ty)
    return nil if !defined?(Mode7::VolumeIds)
    Mode7::VolumeIds.id_for(@map_id, tx, ty)
  rescue Exception
    nil
  end

  # Identidad geometrica del objeto.
  #
  # Para un multitile dibujado sin reordenar piezas:
  #   map_pixel - source_pixel
  # es CONSTANTE para P1/P2/P3/P4 del mismo arbol/prop.
  #
  # Esto es mucho mas estable que flood-fill por celda y no depende de que
  # haya Mountains, P0 o P1 debajo. Dos objetos vecinos del mismo tileset
  # obtienen origenes distintos y no se fusionan.
  def rigid_priority_object_key(tx, ty, entry, volume_id = nil)
    # Solo elevacion EXPLICITA separa objetos. Mountains es soporte del terreno,
    # no identidad del dibujo: si la mitad de un arbol/P4 cae sobre Mountains,
    # todas sus piezas deben seguir dentro del mismo bloque.
    explicit_elevation = (
      entry.key?(:elevation) && !entry[:elevation].nil? ? entry[:elevation].to_f : 0.0
    ).round(4)

    return [:volume, volume_id, explicit_elevation] if volume_id

    rect = entry[:src_rect]
    return [:single, entry.object_id, explicit_elevation] if !rect

    source = rigid_priority_source_key(entry)
    origin_x = tx * Game_Map::TILE_WIDTH  - rect.x.to_i
    origin_y = ty * Game_Map::TILE_HEIGHT - rect.y.to_i
    [:source_object, source, origin_x, origin_y, explicit_elevation]
  end

  def rigid_priority_source_contiguous?(a, b, dx, dy)
    wall_source_contiguous?(a, b, dx, dy)
  end

  def rigid_priority_components
    Mode7::VolumeIds.refresh if defined?(Mode7::VolumeIds) rescue nil

    groups = Hash.new do |hash, key|
      hash[key] = {
        cells: Hash.new { |h, position| h[position] = [] },
        has_seed: false,
        elevation: nil
      }
    end

    @entry_cache.each do |(tx, ty), entries|
      volume_id = rigid_priority_volume_id(tx, ty)
      entries.each do |entry|
        next if !rigid_priority_member_candidate?(entries, entry)
        key = rigid_priority_object_key(tx, ty, entry, volume_id)
        group = groups[key]
        group[:cells][[tx, ty]].push(entry)
        group[:has_seed] = true if rigid_priority_seed?(entries, entry)
        value = entry_world_elevation(entry).to_f
        group[:elevation] = value if group[:elevation].nil? || value < group[:elevation]
      end
    end

    seed_groups = groups.values.select { |group| group[:has_seed] }
    claimed = {}
    seed_groups.each do |group|
      group[:cells].each_value do |entries|
        entries.each { |entry| claimed[entry.object_id] = true }
      end
    end

    # P1 no crea un componente por si solo, pero puede unirse a un P2+ si es
    # literalmente la pieza vecina del mismo dibujo fuente.
    seed_groups.each do |group|
      anchors = []
      group[:cells].each do |position, entries|
        entries.each { |entry| anchors.push([position, entry]) }
      end

      anchors.each do |(tx, ty), source_entry|
        [[-1,0],[1,0],[0,-1],[0,1]].each do |dx, dy|
          pos = [tx + dx, ty + dy]
          entries = @entry_cache[pos]
          next if !entries
          entries.each do |candidate|
            next if claimed[candidate.object_id]
            next if entry_visual_priority(candidate) != 1
            next if !rigid_priority_member_candidate?(entries, candidate)
            next if !rigid_priority_source_contiguous?(source_entry, candidate, dx, dy)
            group[:cells][pos].push(candidate)
            claimed[candidate.object_id] = true
          end
        end
      end
    end

    seed_groups.filter_map do |group|
      cells = group[:cells]
      next if cells.empty?
      [cells, group[:elevation] || 0.0]
    end
  end

  # ---------------------------------------------------------------------------
  # IndoorProp: bloque rigido sin encogimiento por profundidad
  # ---------------------------------------------------------------------------
  def cache_indoor_prop_components
    @indoor_prop_components = []
    @indoor_prop_owned = {}
    return @indoor_prop_components if !Mode7.raster_affine_mode?

    groups = Hash.new { |hash, key| hash[key] = {} }

    @entry_cache.each do |(tx, ty), entries|
      entries.each do |entry|
        next if !interior_prop_entry?(entry)
        key = rigid_priority_object_key(tx, ty, entry, rigid_priority_volume_id(tx, ty))
        groups[key][[tx, ty]] ||= []
        groups[key][[tx, ty]].push(entry)
      end
    end

    # Solo tiles IndoorProp pertenecen al bloque. Un vecino nunca cambia sus
    # bounds ni su ancla; piezas multitile deben compartir tag y Volume ID.
    groups.each_value do |component|
      next if component.empty?
      @indoor_prop_components.push(component)
      component.each_value do |entries|
        entries.each { |entry| @indoor_prop_owned[entry.object_id] = true }
      end
    end

    @indoor_prop_components
  end

  def indoor_prop_owned?(entry)
    @indoor_prop_owned && @indoor_prop_owned[entry.object_id]
  end

  def build_indoor_prop_blocks
    return if !Mode7.raster_affine_mode?
    (@indoor_prop_components || []).each do |component|
      bounds = component.keys
      entries = component.values.flatten
      next if entries.empty?

      elevation = entries.map { |entry| entry_world_elevation(entry) }.min || 0.0
      depth_ty = bounds.map { |_tx, ty| ty }.max
      depth_wyb = (depth_ty + 1) * Game_Map::TILE_HEIGHT

      # TODO el prop en UN solo bloque: P1, P2+ y cualquier prioridad
      # intermedia comparten bounds, base Y y elevacion. Antes cada prioridad
      # generaba su propio componente y los P2+ se separaban visualmente del
      # resto del prop (cada uno con su propio depth_wyb/Z). draw_rigid_...
      # ya ordena el bitmap interno por [unify, priority].
      priority = entries.map { |entry| entry_visual_priority(entry) }.max || 0
      unify = entries.map { |entry| entry[:unify].to_i }.min || 0
      make_rigid_component(
        component, elevation, bounds, priority, unify, depth_wyb, :indoor_prop
      )
    end
  end

  def build_rigid_priority_blocks
    @rigid_priority_owned = {}

    # En interiores raster-affine TODAS las prioridades siguen la cuadricula
    # affine por strips. No extraer P2+ a bloques rigidos.
    return if Mode7.respond_to?(:raster_affine_mode?) && Mode7.raster_affine_mode?

    rigid_priority_components.each do |component, elevation|
      bounds = component.keys

      # Marcar ownership ANTES de construir strips. Una entry que entra aqui
      # no puede volver a aparecer como priority strip.
      component.each_value do |entries|
        entries.each { |entry| @rigid_priority_owned[entry.object_id] = true }
      end

      groups = Hash.new { |hash, priority| hash[priority] = {} }
      component.each do |position, entries|
        entries.each do |entry|
          priority = entry_visual_priority(entry)
          groups[priority][position] ||= []
          groups[priority][position].push(entry)
        end
      end

      groups.each do |priority, group_cells|
        # El Z conserva la prioridad real, pero el layer ya no divide la
        # geometria del objeto. Solo aporta un bias minimo de orden.
        unifies = group_cells.values.flatten.map { |entry| entry[:unify].to_i }
        unify = unifies.empty? ? 0 : unifies.min

        # IMPORTANTE: todas las prioridades del componente usan la misma base
        # Y de los bounds completos. Antes cada priority usaba su propia fila
        # maxima; si el objeto solo tenia P2/P3/P4, esas bases diferian y se
        # percibia una separacion aunque el bitmap-space fuese comun.
        depth_ty = bounds.map { |_tx, ty| ty }.max
        depth_wyb = (depth_ty + 1) * Game_Map::TILE_HEIGHT

        make_rigid_component(
          group_cells,
          elevation,
          bounds,
          priority,
          unify,
          depth_wyb
        )
      end
    end
  end

  def rigid_priority_owned?(entry)
    @rigid_priority_owned && @rigid_priority_owned[entry.object_id]
  end

  def build_priority_surfaces
    build_rigid_priority_blocks

    # P1 y superficies especiales siguen el arco del suelo. P2+ ya fue
    # retirado a bloques rigidos para evitar cortes entre filas.
    strips = Hash.new { |hash, key| hash[key] = {} }

    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]
        entries.each do |entry|
          next if wall_visual_owned?(entry)
          next if rigid_priority_owned?(entry)
          next if !priority_surface_entry?(entry)

          elevation = entry_world_elevation(entry)
          key = [entry[:unify].to_i, entry_visual_priority(entry), ty, elevation]
          strips[key][tx] ||= []
          strips[key][tx].push(entry)
        end
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
  end
  def build_interior_border_surfaces
    return if Mode7.raster_affine_mode?
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

  def make_rigid_component(cells, elevation = 0, bounds = nil,
                          priority = nil, unify = nil, depth_wyb = nil,
                          rigid_kind = :component)
    positions = bounds || cells.keys
    return if positions.empty?

    min_tx = positions.map { |tx, _ty| tx }.min
    max_tx = positions.map { |tx, _ty| tx }.max
    min_ty = positions.map { |_tx, ty| ty }.min
    max_ty = positions.map { |_tx, ty| ty }.max

    width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
    height = (max_ty - min_ty + 1) * Game_Map::TILE_HEIGHT
    bitmap = Bitmap.new(width, height)
    draw_rigid_component_source(bitmap, min_tx, min_ty, cells)

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
      sprite, wx, wyb, height, cells, rigid_kind, unify, depth,
      0, min_tx, min_ty, max_tx, max_ty, elevation
    ])
  end
  def draw_rigid_component_source(dst, min_tx, min_ty, cells)
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
  # Raster approach: las entradas P1 se hornéan directamente en @ground.
  # draw_ground las proyecta scanline por scanline con la misma deformación
  # que el terreno (montañas). Cero sprites, cero cortes entre strips.
  def make_priority_strip(cells, ty, priority, unify, elevation)
    return if !cells || cells.empty?

    # Interior: raster affine REAL. Cada fila priority conserva un Sprite con
    # su Z, pero su geometria se calcula desde project_y/hscale exactamente
    # igual que la cuadricula del ground. No se hornea encima de P0.
    if Mode7.respond_to?(:raster_affine_mode?) && Mode7.raster_affine_mode?
      min_tx = cells.keys.min
      max_tx = cells.keys.max
      width = (max_tx - min_tx + 1) * Game_Map::TILE_WIDTH
      source = Bitmap.new(width, Game_Map::TILE_HEIGHT)
      source.clear

      cells.each do |tx, entries|
        x = (tx - min_tx) * Game_Map::TILE_WIDTH
        entries.sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }.each do |entry|
          blt_entry_into(source, x, 0, entry, entry[:opacity] || 255)
        end
      end

      sprite = Sprite.new(@viewport)
      sprite.bitmap = source
      sprite.ox = 0
      sprite.oy = source.height
      sprite.visible = false

      @priority_strips.push([
        sprite, source, min_tx, ty, priority, unify, elevation,
        cells, :entries_only, nil
      ])
      return
    end

    # Exterior legacy: P1 sigue integrado al raster de ground para compartir
    # exactamente la curva del suelo.
    return if !@ground || @ground.disposed?
    cells.each do |tx, entries|
      x = tx * Game_Map::TILE_WIDTH
      y = ty * Game_Map::TILE_HEIGHT
      sorted = entries.sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }
      sorted.each do |entry|
        blt_entry_into(@ground, x, y, entry, entry[:opacity] || 255)
      end
    end
    @priority_raster_cells ||= {}
    @priority_raster_cells[ty] ||= []
    @priority_raster_cells[ty].push(cells)
  end

  def draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow = false)
    source.clear
    if @ground && !@ground.disposed?
      cells.each_key do |tx|
        gx = tx * Game_Map::TILE_WIDTH
        gy = ty * Game_Map::TILE_HEIGHT
        sx = (tx - min_tx) * Game_Map::TILE_WIDTH
        @src_rect.set(gx, gy, Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
        source.blt(sx, 0, @ground, @src_rect)
      end
    end
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

  # InteriorBorder usa sprite individual porque no pertenece a strips ni a
  # bloques rigidos de prioridad.

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
    cam_x_now = Mode7.cam_x
    cam_y_now = Mode7.projection_cam_y
    proj_rev = Mode7.projection_revision

    @priority_strips.each do |data|
      sprite, source, min_tx, ty, priority, unify, elevation,
      _cells, _mountain_shadow, projection_key = data

      if (ty - cam_ty).abs > radius_y
        sprite.visible = false
        next
      end

      reproj_step = Mode7::Config::PRIORITY_REPROJECT_WORLD_STEP.to_f
      reproj_step = 1.0 if reproj_step <= 0.0
      needs_recalc = !projection_key ||
                     (cam_x_now - projection_key[0]).abs >= reproj_step ||
                     (cam_y_now - projection_key[1]).abs >= reproj_step ||
                     proj_rev != projection_key[2]
      if needs_recalc
        if !redraw_projected_priority_strip(sprite, source, min_tx, ty, elevation)
          sprite.visible = false
          next
        end
        data[9] = [cam_x_now, cam_y_now, proj_rev]
      end

      top = sprite.y - sprite.oy * sprite.zoom_y
      bottom = sprite.y
      if top > Mode7.screen_h || bottom < 0 ||
         sprite.x + sprite.bitmap.width * sprite.zoom_x < 0 ||
         sprite.x > Mode7.screen_w
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

      apply_depth_fog_to_sprite(sprite, sprite.y)
      sprite.visible = true
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

      reproj_step = Mode7::Config::PRIORITY_REPROJECT_WORLD_STEP.to_f
      reproj_step = 1.0 if reproj_step <= 0.0
      needs_projection = !projection_key ||
                         (Mode7.cam_x - projection_key[0]).abs >= reproj_step ||
                         (Mode7.projection_cam_y - projection_key[1]).abs >= reproj_step ||
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
      draw_rigid_component_source(sprite.bitmap, min_tx, min_ty, entries)
    end

    @priority_strips.each do |data|
      _sprite, source, min_tx, ty, _priority, _unify, _elevation,
      cells, mountain_shadow = data
      next if !source || source.disposed?
      next if cells.values.flatten.none? { |entry| entry[:animated] }
      if mountain_shadow == :entries_only
        source.clear
        cells.each do |tx, entries|
          x = (tx - min_tx) * Game_Map::TILE_WIDTH
          entries.sort_by { |entry| [entry[:unify].to_i, entry[:priority].to_i] }.each do |entry|
            blt_entry_into(source, x, 0, entry, entry[:opacity] || 255)
          end
        end
      else
        draw_priority_strip_source(source, min_tx, ty, cells, mountain_shadow)
      end
    end

    if @priority_raster_cells && @ground && !@ground.disposed?
      affected_tys = []
      @autotile_cells.each do |filename, cells|
        next if !@autotiles.animated?(filename)
        cells.each do |_tx, ty|
          affected_tys << ty if @priority_raster_cells[ty]
        end
      end
      affected_tys.uniq.each do |ty|
        @priority_raster_cells[ty].each do |strip_cells|
          strip_cells.each do |tx, entries|
            x = tx * Game_Map::TILE_WIDTH
            y = ty * Game_Map::TILE_HEIGHT
            sorted = entries.sort_by { |e| [e[:unify].to_i, e[:priority].to_i] }
            sorted.each do |entry|
              blt_entry_into(@ground, x, y, entry, entry[:opacity] || 255)
            end
          end
        end
      end
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
  # Bloques rigidos (walls + objetos P2+)
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

      if Mode7.raster_affine_mode?
        if _z_behavior == :indoor_prop
          # Props indoor son objetos: TAMANO constante (zoom fijo) aunque la
          # distancia cambie, pero POSICION en la grid real (sx de project()
          # con hscale actual). Overridear sx con zoom fijo hacia que el prop
          # se descuadrase de su celda al moverse la camara.
          scale_x = Mode7.zoom.to_f
          scale_y = Mode7.zoom.to_f
        else
          # IndoorWall conecta horizontalmente con IndoorBorder en la fila de
          # apoyo, pero conserva altura fija. Asi el borde puede converger en
          # diagonal sin aplastar el wall completo. El border y el bloque negro
          # SON capas planas del suelo: siguen la perspectiva (scale_y = hscale).
          scale_x = Mode7.hscale(syb).to_f
          if _z_behavior == :wall_component && Mode7::Config::INDOOR_WALL_FIXED_HEIGHT
            scale_y = Mode7.zoom.to_f
          else
            scale_y = scale_x
          end
        end
      elsif Mode7.cylindrical_mode?
        # El angulo de camara afecta al BLOQUE COMPLETO de forma uniforme.
        # No deforma sus filas internas ni separa P0-P4.
        scale_x = Mode7.tile_billboard_scale_for_world_y(wyb).to_f
        scale_y = scale_x
      else
        scale_x = Mode7.zoom.to_f
        scale_y = Mode7.zoom.to_f
      end
      scale_x = 0.001 if scale_x <= 0.001
      scale_y = 0.001 if scale_y <= 0.001

      half_width = sprite.bitmap.width * scale_x / 2.0
      screen_height = sprite.bitmap.height * scale_y
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
      sprite.zoom_x = scale_x
      sprite.zoom_y = scale_y

      depth_wyb, depth_priority, depth_unify = depth || [wyb, 0, 0]
      bias = depth_unify.to_i
      bias += Mode7::Config::WALL_TOP_Z_BIAS if depth_priority.to_i > 0
      sprite.z = Mode7.depth_z(depth_wyb, depth_priority, bias)

      apply_depth_fog_to_sprite(sprite, syb)
      sprite.visible = true
    end
  end
end
