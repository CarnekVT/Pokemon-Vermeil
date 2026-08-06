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
    tag = terrain_tag_for_entry(e)
    has_valid_tag = tag && Mode7::Config::WALL_TERRAIN_TAG_HEIGHT.key?(tag.id) && tag.id != :None
    e[:priority] > 0 || has_valid_tag
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
  def make_column(tx, ty, entries)
    h_tiles = wall_layer_height(entries)
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
  # 3. Proyeccion de Muros: UNICA y CONICA (igual que suelo y personajes)
  # ---------------------------------------------------------------------------
  def update_walls
    @wall_data.each do |data|
      sprite, wx, wyb, h, pmax, _entries = data
      half_w = Game_Map::TILE_WIDTH / 2.0

      # Proyeccion conica de la base y del tope del muro: la MISMA funcion que
      # dibuja el suelo (draw_ground) y posiciona a los personajes (Game_Character).
      pr_left  = Mode7.project(wx - half_w, wyb)
      pr_right = Mode7.project(wx + half_w, wyb)
      if !pr_left || !pr_right
        sprite.visible = false
        next
      end

      sx_left  = pr_left[0].round
      sx_right = pr_right[0].round
      syb      = pr_left[1]

      pr_top = Mode7.project(wx, wyb - h)
      if !pr_top || syb - pr_top[1] <= 0
        sprite.visible = false
        next
      end
      syt = pr_top[1]

      if syb < -600 || syb > Mode7.screen_h + 600 || sx_left < -600 || sx_right > Mode7.screen_w + 600
        sprite.visible = false
        next
      end

      sy_bottom = syb.round
      sy_top    = syt.round

      sprite.ox = 0
      sprite.x = sx_left
      sprite.y = sy_bottom + 1
      sprite.z = sy_bottom + (pmax * 32)

      drawn_width  = sx_right - sx_left
      drawn_height = (sy_bottom + 1) - sy_top

      sprite.zoom_x = (drawn_width + 0.8) / Game_Map::TILE_WIDTH.to_f
      sprite.zoom_y = (drawn_height + 0.8) / h.to_f
      sprite.visible = true
    end
  end
end