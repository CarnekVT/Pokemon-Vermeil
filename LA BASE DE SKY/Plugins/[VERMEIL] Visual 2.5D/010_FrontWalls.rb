#===============================================================================
# [VERMEIL] Visual 2.5D - 010_FrontWalls.rb
# Extrusion de muros/techos en columnas (una por tile). El sprite se clava en
# su base (x=sx, y=syb) y se escala con perspectiva affin pura (zoom_y=k), sin
# parallax falso ni estiramiento vertical distorsionado. El Z divide bandas
# para respetar la oclusion (techo :always_top sobre todo).
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

  def terrain_tag_for_entry(entry)
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
    Mode7::Config::WALL_TERRAIN_TAG_HEIGHT[tag.id] || 1
  end

  # Solo se elevan tiles con el Terrain Tag de muro (o debug forzado por prio).
  def entry_is_wall?(e)
    tag = terrain_tag_for_entry(e)
    if tag && tag.id != :None && Mode7::Config::WALL_TERRAIN_TAG_HEIGHT.key?(tag.id)
      return true
    end
    return true if Mode7Renderer.debug_mode_force_all_priority_wall? && e[:priority] > 0
    return false
  end

  def cell_has_wall?(entries)
    entries.any? { |e| entry_is_wall?(e) }
  end

  def wall_layer_height(entries)
    entries.select { |e| entry_is_wall?(e) }.map { |e| entry_wall_height(e) }.max || 1
  end

  def wall_layer_unify(entries)
    entries.select { |e| entry_is_wall?(e) }.map { |e| e[:unify] }.min
  end

  # Columna de h = max_h tiles. base_unify es el unify del suelo de la celda:
  # rank = entry.unify - base_unify coloca cada capa a su altura original, asi
  # base y techo comparten el mismo bloque y el techo no se hunde.
  def make_column(tx, ty, entries, max_h, base_unify, z_behavior = :dynamic)
    max_h = max_h.to_i.clamp(1, 16)
    base_unify = base_unify.to_i
    h = max_h * Game_Map::TILE_HEIGHT
    bmp = Bitmap.new(Game_Map::TILE_WIDTH, h)
    bmp.clear

    entries.each do |e|
      rank = e[:unify].to_i - base_unify
      y = h - (rank + 1) * Game_Map::TILE_HEIGHT
      y = 0 if y < 0
      blt_entry_into(bmp, 0, y, e, e[:opacity] || 255)
    end

    sprite = Sprite.new(@viewport)
    sprite.bitmap = bmp
    sprite.ox = Game_Map::TILE_WIDTH / 2.0
    sprite.oy = h
    sprite.visible = false

    wx = tx * Game_Map::TILE_WIDTH + (Game_Map::TILE_WIDTH / 2.0)
    wyb = ty * Game_Map::TILE_HEIGHT + Game_Map::TILE_HEIGHT

    @wall_data.push([sprite, wx, wyb, h, entries, z_behavior, base_unify])
  end

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
      sprite, _wx, _wyb, h, entries, _z_behavior, base_unify = data
      next if !sprite.bitmap || sprite.bitmap.disposed?
      next if entries.none? { |e| e[:animated] }

      sprite.bitmap.clear
      entries.sort_by { |w| [w[:priority], w[:unify]] }.each do |w|
        rank = w[:unify].to_i - base_unify.to_i
        y = h - (rank + 1) * Game_Map::TILE_HEIGHT
        y = 0 if y < 0
        blt_entry_into(sprite.bitmap, 0, y, w, w[:opacity] || 255)
      end
    end
  end

  def update_walls
    cam_tx = Mode7.cam_x / Game_Map::TILE_WIDTH
    cam_ty = Mode7.cam_y / Game_Map::TILE_HEIGHT

    radius_x = defined?(Mode7::Config::WALL_SPAWN_RADIUS_X) ? Mode7::Config::WALL_SPAWN_RADIUS_X : 26
    radius_y = defined?(Mode7::Config::WALL_SPAWN_RADIUS_Y) ? Mode7::Config::WALL_SPAWN_RADIUS_Y : 34

    @wall_data.each do |data|
      sprite, wx, wyb, h, _entries, z_behavior, _base_unify = data

      wt = wx / Game_Map::TILE_WIDTH
      wty = (wyb - Game_Map::TILE_HEIGHT / 2.0) / Game_Map::TILE_HEIGHT
      if (wt - cam_tx).abs > radius_x || (wty - cam_ty).abs > radius_y
        sprite.visible = false
        next
      end

      # LA SOLUCION DEFINITIVA: Elevacion estricta de 0 para que la base del muro no flote
      syb = Mode7.project_y(wyb, 0)
      next if syb.nil?

      pr = Mode7.project(wx, wyb, 0)
      next if !pr
      sx = pr[0]

      k = Mode7.base_hscale(syb)
      next if k.nil? || k <= 0

      if syb < -Game_Map::TILE_HEIGHT ||
         syb > Mode7.screen_h + Game_Map::TILE_HEIGHT ||
         sx < -Game_Map::TILE_WIDTH ||
         sx > Mode7.screen_w + Game_Map::TILE_WIDTH
        sprite.visible = false
        next
      end

      sprite.ox = Game_Map::TILE_WIDTH / 2.0
      sprite.oy = h

      # Sin parallax falso: posicionamiento inamovible en la base.
      sprite.x = sx
      sprite.y = syb

      if z_behavior == :always_top
        sprite.z = 9999
      else
        sprite.z = syb.round
      end

      # Escala estable (sin distorsion vertical)
      sprite.zoom_x = k + 0.04
      sprite.zoom_y = k + 0.04

      # Niebla (inerte hasta que 006_Atmosphere defina fog_alpha)
      if Mode7.respond_to?(:fog_alpha)
        alpha = Mode7.fog_alpha(syb)
        if alpha > 0
          sprite.color.set(Mode7::Config::FOG_COLOR.red, Mode7::Config::FOG_COLOR.green, Mode7::Config::FOG_COLOR.blue, alpha)
        else
          sprite.color.set(0, 0, 0, 0)
        end
      end

      sprite.visible = true
    end
  end
end