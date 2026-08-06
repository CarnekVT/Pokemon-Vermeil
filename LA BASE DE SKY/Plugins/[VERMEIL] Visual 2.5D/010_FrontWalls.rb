#===============================================================================
# [VERMEIL] Visual 2.5D - 010_FrontWalls.rb
# Muros por extrusion vertical como SPRITES INDEPENDIENTES del suelo.
# Cada columna es un sprite con un bitmap de h tiles apilados por capa (unify).
# Se proyecta con:
#   - BASE PEGADA al suelo: x = center_x + k*(wx - cam_x); y = project_y(wyb)
#     con k = hscale(base_row). La cara del muro comparte la conica del suelo.
#   - zoom_x = k + 0.04 (la escala horizontal del suelo en su fila, MAS un pequeno
#     overlap de seguridad para que no queden huecos entre columnas adyacentes).
#   - zoom_y = (project_y(wyb) - project_y(wyb-h)) / h: ESCALA VERTICAL
#     perspective-correct. La altura del sprite coincide pixel-a-pixel con la
#     distancia en pantalla entre la base y el tope proyectados, de modo que el
#     muro se comprime verticalmente con la perspectiva del suelo y NO se rompe
#     a pedazos en angulos fuertes: encaja con el terreno y con muros adyacentes.
# oy = h => el sprite se ancla a su base proyectada. Como no escribe en @ground,
# no borra/borra tiles adyacentes; su z (fila, +prioridad) ocluye correctamente.
#===============================================================================
class Mode7Renderer
  # ---------------------------------------------------------------------------
  # 1. Debug mode toggle (configurable desde overworld)
  # ---------------------------------------------------------------------------
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
    return if !Mode7.active_now?
    renderer = $scene.instance_variable_get(:@map_renderer)
    return if !renderer || !renderer.is_a?(Mode7Renderer) || renderer.disposed?
    renderer.invalidate_ground
  end

  private

  # ---------------------------------------------------------------------------
  # 1.2. Filtro Condicional para Columnas
  # ---------------------------------------------------------------------------
  def terrain_tag_for_entry(entry)
    tid = entry[:tid]
    return nil if !tid || tid <= 0
    ts_id = entry[:tileset_id] || @map.tileset_id
    ts = $data_tilesets[ts_id]
    return nil if !ts || !ts.terrain_tags
    raw = ts.terrain_tags[tid]
    return nil if !raw || raw == 0
    GameData::TerrainTag.try_get(raw)
  rescue
    nil
  end

  # Altura de extrusión en tiles de mundo para una entrada (por terrain tag).
  def entry_wall_height(e)
    tag = terrain_tag_for_entry(e)
    return 1 if !tag || tag.id == :None
    Mode7::Config::WALL_TERRAIN_TAG_HEIGHT[tag.id] || 1
  end

  def entry_is_wall?(e)
    # Modo debug: forzar prioridad 1+ como muros
    return true if Mode7Renderer.debug_mode_force_all_priority_wall? && e[:priority] > 0
    # Modo debug: forzar prioridad 1+ como suelo (no muros)
    return false if Mode7Renderer.debug_mode_force_priority_1_as_ground? && e[:priority] > 0
    # Comportamiento normal: candidato a muro 3D si tiene el terrain tag
    # WALL_TERRAIN_TAG_HEIGHT (muro 3D de prioridad 0 o 1+).
    # La ALTURA de extrusion sigue definida SOLO por el terrain tag
    # (entry_wall_height); la prioridad no sube la altura, solo el z-index.
    tag = terrain_tag_for_entry(e)
    return false if !tag || tag.id == :None
    Mode7::Config::WALL_TERRAIN_TAG_HEIGHT.key?(tag.id)
  end

  def cell_has_wall?(entries)
    entries.any? { |e| entry_is_wall?(e) }
  end

  # Extrusión máxima (en tiles) de las entradas que forman pared.
  def wall_layer_height(entries)
    entries.select { |e| entry_is_wall?(e) }.map { |e| entry_wall_height(e) }.max || 1
  end

  # Unify mínimo de las entradas que forman pared: separa suelo (menor) y muro.
  def wall_layer_unify(entries)
    entries.select { |e| entry_is_wall?(e) }.map { |e| e[:unify] }.min
  end

  # ---------------------------------------------------------------------------
  # 2. Ensamblaje de la Columna (Sprite independiente, bitmap apilado por capa)
  # ---------------------------------------------------------------------------
  def make_column(tx, ty, entries, h_tiles = nil)
    h_tiles ||= wall_layer_height(entries)
    # ponytail: acota la altura para no crear un Bitmap fuera de limites.
    h_tiles = 1 if h_tiles < 1 || h_tiles > 16
    h = h_tiles * Game_Map::TILE_HEIGHT
    bmp = Bitmap.new(Game_Map::TILE_WIDTH, h)
    bmp.clear

    # Apila entradas por capa (unify): capa 0 abajo, capa superior arriba.
    layers = entries.map { |e| e[:unify] }.uniq.sort
    entries.each do |e|
      op = e[:opacity] || 255
      rank = layers.index(e[:unify]) || 0
      y = h - (rank + 1) * Game_Map::TILE_HEIGHT
      y = 0 if y < 0
      bmp.blt(0, y, e[:bitmap], current_src_rect(e), op)
    end

    sprite = Sprite.new(@viewport)
    sprite.bitmap = bmp
    sprite.ox = Game_Map::TILE_WIDTH / 2.0   # origen: centro horizontal
    sprite.oy = h                            # origen: base del muro
    sprite.visible = false

    # Posicion de mundo del muro (base = fila del tile).
    wx = tx * Game_Map::TILE_WIDTH + (Game_Map::TILE_WIDTH / 2.0)
    wyb = ty * Game_Map::TILE_HEIGHT + Game_Map::TILE_HEIGHT

    # pmax: prioridad del tile WALL (solo entries que son wall). Los tiles
    # priority 1+ que NO son wall no elevan el z de la columna (problema 3):
    # se pueden subir por encima como si fueran p0.
    pmax = entries.select { |e| entry_is_wall?(e) }.map { |e| e[:priority] }.max || 0

    @wall_data.push([sprite, wx, wyb, h, entries, pmax])
  end

  # ---------------------------------------------------------------------------
  # 3. Recompone celdas con autotiles animados (suelo y columnas).
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
        if cell_has_wall?(entries)
          wall_layer = wall_layer_unify(entries)
          ground_entries = entries.select { |e| e[:unify] < wall_layer }
          blt_ground_cell(tx, ty, ground_entries) unless ground_entries.empty?
        else
          blt_ground_cell(tx, ty, entries)
        end
      end
    end

    @wall_data.each do |data|
      sprite, _wx, _wyb, h, entries = data
      next if !sprite.bitmap || sprite.bitmap.disposed?
      next if entries.none? { |e| e[:animated] }

      sprite.bitmap.clear
      layers = entries.map { |e| e[:unify] }.uniq.sort
      entries.sort_by { |w| [w[:priority], w[:unify]] }.each do |w|
        rank = layers.index(w[:unify]) || 0
        y = h - (rank + 1) * Game_Map::TILE_HEIGHT
        y = 0 if y < 0
        sprite.bitmap.blt(0, y, w[:bitmap], current_src_rect(w), w[:opacity] || 255)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Proyeccion de muros: PERSPECTIVE-CORRECT + base pegada al suelo.
  #    x = centro_camara + k*(wx - cam_x), igual que el suelo en esa fila.
  #    y_base = project_y(wyb) (fila de pantalla donde la base del muro toca
  #    el suelo). k = hscale(y_base).
  #    zoom_x = k (con overlap seguro para evitar huecos entre columnas).
  #    zoom_y = (y_base - y_top) / h => la altura del sprite coincide EXACTAMENTE
  #    zoom_y = (syb - syt) / h => la altura del sprite coincide EXACTAMENTE
  #    con la distancia en pantalla entre la base proyectada y el tope
  #    proyectado (project_y(wyb-h)). Asi el muro se comprime verticalmente con
  #    la perspectiva del suelo y NO se ROMPE a pedazos en angulos fuertes:
  #    encaja pixel-a-pixel con el terreno y con muros adyacentes.
  #    oy=h => el sprite se ancla a la base proyectada.
  # ---------------------------------------------------------------------------
  def update_walls
    @wall_data.each do |data|
      sprite, wx, wyb, h, _entries, pmax = data

      syb = Mode7.project_y(wyb)
      syt = Mode7.project_y(wyb - h)
      next (sprite.visible = false) if syb.nil? || syt.nil?

      k = Mode7.hscale(syb)
      next (sprite.visible = false) if k.nil? || k <= 0

      sx = Mode7.center_x + k * (wx - Mode7.cam_x)

      # Culling: fuera de pantalla (con margen de seguridad).
      if syb < -1000 || syb > Mode7.screen_h + 1000 || sx < -1000 || sx > Mode7.screen_w + 1000
        sprite.visible = false
        next
      end

      sprite.ox = Game_Map::TILE_WIDTH / 2.0
      sprite.oy = h            # base del muro anclada al suelo (proyectado)
      sprite.x = sx
      sprite.y = syb
      # z-index: prioridad 1+ de muros -> por encima del player normal (z ~ syb)
      # pero POR DEBAJO de always_on_top (999). Techo fijo 990 garantiza esto.
      # Prioridad 0 -> z = syb (por debajo del player normal, como suelo plano).
      sprite.z = (pmax > 0) ? [syb.round + 500, 990].min : syb.round
      # ESCALA UNIFORME horizontal con overlap de seguridad (evita huecos entre
      # columnas adyacentes; ~1.2px de overlap a escala 1.0).
      sprite.zoom_x = k + 0.04
      # ESCALA VERTICAL perspective-correct: ajusta a la altura proyectada.
      # Clamp minimo evita zoom_y ~ 0 o negativo (cerca del horizonte) que
      # corta/recorta la sprite. k*0.1 es el umbral; cae a k+0.04 (overlap).
      zoom_y = (syb - syt) / h.to_f
      zoom_y = k + 0.04 if zoom_y <= k * 0.1
      sprite.zoom_y = zoom_y
      sprite.visible = true
    end
  end
end