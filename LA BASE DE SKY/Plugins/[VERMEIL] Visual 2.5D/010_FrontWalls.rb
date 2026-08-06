#===============================================================================
# [VERMEIL] Visual 2.5D - 010_FrontWalls.rb
# Muros por extrusión vertical HORNEADA en el suelo (@ground), ANTES de
# proyectar. Como el muro queda dentro de la misma textura del terreno,
# draw_ground lo proyecta con la MISMA cónica que el suelo -> no se separa,
# no se deforma al cambiar de angulo y nunca se ve "cortado". Y como vive en
# el z del suelo (Sprite@z=-1000), queda encima de sombras/panorama de
# MakerStudio; el fog (viewport z=3000) va por delante.
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

  # Altura de extrusión en tiles de mundo para una entrada (por terrain tag).
  def entry_wall_height(e)
    tag = terrain_tag_for_entry(e)
    return 1 if !tag || tag.id == :None
    Mode7::Config::WALL_TERRAIN_TAG_HEIGHT[tag.id] || 1
  end

  def entry_is_wall?(e)
    # SOLO los tiles CON prioridad > 0 son paredes: esos herean la altura de
    # WALL_TERRAIN_TAG_HEIGHT (extrusión). Un tile de prioridad 0 NO se
    # desvincula del suelo (ni siquiera con terrain tag de pared): queda en el
    # plano del terreno.
    e[:priority] > 0
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
  # 2. Horneado de Muro en la Textura del Suelo
  #    Pinta la cara del muro en @ground ocupando EXACTAMENTE h_tiles filas: la
  #    base (ty) y las h_tiles-1 que quedan por debajo delante (ty+1.. en el
  #    mundo negro no: en el mundo la cota hacia abajo es ty+). El bloque queda
  #    como una columna contigua, SIN duplicar el tile en filas adyacentes.
  #    draw_ground proyecta esa textura fila a fila con su cónica -> el muro
  #    "es" el suelo elevado, vive en el z del suelo (encima de sombras/panorama,
  #    el fog va por delante con su viewport z=3000).
  # ---------------------------------------------------------------------------
  def make_column(tx, ty, entries, h_tiles = nil)
    h_tiles ||= wall_layer_height(entries)
    # ponytail: acota la altura para no crear un bloque fuera de limites.
    h_tiles = 1 if h_tiles < 1 || h_tiles > 16
    face = entries.max_by { |e| [e[:priority], e[:unify]] }
    return if !face || !face[:bitmap]
    src = current_src_rect(face)
    op = face[:opacity] || 255
    (0...h_tiles).each do |r|
      gy = ty - r
      next if gy < 0
      @ground.blt(tx * Game_Map::TILE_WIDTH, gy * Game_Map::TILE_HEIGHT, face[:bitmap], src, op)
    end
  end

  # ---------------------------------------------------------------------------
  # Recompone celdas con autotiles animados (suelo y columnas).
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
          wall_entries   = entries.select { |e| e[:unify] >= wall_layer }
          blt_ground_cell(tx, ty, ground_entries) unless ground_entries.empty?
          make_column(tx, ty, wall_entries) unless wall_entries.empty?
        else
          blt_ground_cell(tx, ty, entries)
        end
      end
    end
  end
end