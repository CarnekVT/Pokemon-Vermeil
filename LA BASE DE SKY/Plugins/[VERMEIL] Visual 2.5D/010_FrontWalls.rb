#===============================================================================
# [VERMEIL] Visual 2.5D - 010_FrontWalls.rb
# Muros frontales por extruccion vertical: columnas por celda y proyeccion
# UNIFICADA conica (la misma que el suelo y los personajes).
#===============================================================================
class Mode7Renderer
  private

  # ---------------------------------------------------------------------------
  # 1. Filtro Condicional para Columnas
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

  # Altura de extrucion en tiles de mundo para una entrada (por terrain tag).
  def entry_wall_height(e)
    tag = terrain_tag_for_entry(e)
    return 1 if !tag || tag.id == :None
    Mode7::Config::WALL_TERRAIN_TAG_HEIGHT[tag.id] || 1
  end

  def entry_is_wall?(e)
    # SOLO los tiles CON prioridad > 0 son paredes: esos si heredan la altura
    # de WALL_TERRAIN_TAG_HEIGHT (extrusion). Un tile de prioridad 0 NO se
    # desvincula del suelo, aunque tenga un terrain tag de pared: se queda en
    # el plano del terreno (no separado, no por encima del player).
    e[:priority] > 0
  end

  def cell_has_wall?(entries)
    entries.any? { |e| entry_is_wall?(e) }
  end

  # Extrusion maxima (en tiles) de las entradas que forman pared.
  def wall_layer_height(entries)
    entries.select { |e| entry_is_wall?(e) }.map { |e| entry_wall_height(e) }.max || 1
  end

  # Unify minimo de las entradas que forman pared: separa suelo (menor) y muro.
  def wall_layer_unify(entries)
    entries.select { |e| entry_is_wall?(e) }.map { |e| e[:unify] }.min
  end

  # ---------------------------------------------------------------------------
  # 2. Ensamblaje Preciso (Columna por Columna) sin arrastre
  # ---------------------------------------------------------------------------
  def make_column(tx, ty, entries, h_tiles = nil)
    h_tiles ||= wall_layer_height(entries)
    # ponytail: acota la altura para no crear un Bitmap fuera de limites.
    h_tiles = 1 if h_tiles < 1 || h_tiles > 16
    h = h_tiles * Game_Map::TILE_HEIGHT
    bmp = Bitmap.new(Game_Map::TILE_WIDTH, h)
    bmp.clear

    entries.sort_by { |e| [e[:priority], e[:unify]] }.each do |e|
      op = e[:opacity] || 255
      bmp.blt(0, h - Game_Map::TILE_HEIGHT, e[:bitmap], current_src_rect(e), op)
    end

    sprite = Sprite.new(@viewport)
    sprite.bitmap = bmp
    sprite.ox = 0
    sprite.oy = h
    sprite.visible = false

    wx = tx * Game_Map::TILE_WIDTH + (Game_Map::TILE_WIDTH / 2.0)
    wy = ty * Game_Map::TILE_HEIGHT + Game_Map::TILE_HEIGHT

    pmax = entries.map { |e| e[:priority] }.max || 0
    # Elevacion = SOLO extrusión de bloques por terrain tag (entry_wall_height).
    # Queda anclada a la cota Z=0 del suelo: la base del bloque toca el plano,
    # la topografia se apila hacia arriba. (Sin elevacion de camara: el suelo
    # es un plano liso y un bloque bajo no produce despegue que flote.)
    @wall_data.push([sprite, wx, wy, h, pmax, entries])
  end

  # ---------------------------------------------------------------------------
  # Recompone celdas con autotiles animados (suelo y columnas).
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
      sprite, _wx, _wy, _h, _pmax, entries = data
      next if !sprite.bitmap || sprite.bitmap.disposed?
      next if entries.none? { |e| e[:animated] }

      sprite.bitmap.clear
      entries.sort_by { |w| [w[:priority], w[:unify]] }.each do |w|
        sprite.bitmap.blt(0, 0, w[:bitmap], current_src_rect(w), w[:opacity] || 255)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Proyeccion de Muros: PERSPECTIVE-CORRECT.
  #    La BASE se alinea al suelo (hscale de su fila -> pega con los tiles de
  #    alrededor y con las columnas apiladas de abajo) y el TOPE se proyecta a
  #    su fila real (project_y de wyb-h). El zoom vertical conecta ambos, asi
  #    el muro converge hacia el horizonte como el suelo y NO se corta con los
  #    tiles de prioridad 1+ apilados encima.
  # ---------------------------------------------------------------------------
  def update_walls
    @wall_data.each do |data|
      sprite, wx, wyb, h, pmax, _entries = data

      # Fila de pantalla de la base (donde toca el suelo) y del tope.
      syb = Mode7.project_y(wyb)
      syt = Mode7.project_y(wyb - h)
      next (sprite.visible = false) if syb.nil? || syt.nil?

      # Escala horizontal = la del SUELO en la fila de la base: la columna
      # queda pegada a los tiles de alrededor (misma formula que draw_ground).
      k = Mode7.hscale(syb)
      next (sprite.visible = false) if k.nil? || k <= 0

      # Centro X con la MISMA formula que draw_ground para que la base de la
      # columna coincida exactamente con la celda de suelo que la rodea.
      sx_center = Mode7.center_x + k * (wx - Mode7.cam_x)
      drawn_width  = Game_Map::TILE_WIDTH * k
      sx_left   = (sx_center - drawn_width / 2.0).round
      sx_right  = (sx_center + drawn_width / 2.0).round
      sy_bottom = syb.round
      sy_top    = syt.round

      if syb < -600 || syb > Mode7.screen_h + 600 || sx_left < -600 || sx_right > Mode7.screen_w + 600
        sprite.visible = false
        next
      end

      sprite.ox = 0
      sprite.x = sx_left
      sprite.y = sy_bottom + 1
      sprite.z = sy_bottom + (pmax * 32)

      # zoom_x = escala del suelo (base pegada al terreno).
      # zoom_y = estira la columna hasta la fila real del tope (converge).
      sprite.zoom_x = k
      sprite.zoom_y = (sy_bottom + 1 - sy_top) / h.to_f
      sprite.zoom_y = k if sprite.zoom_y <= 0
      sprite.visible = true
    end
  end
end