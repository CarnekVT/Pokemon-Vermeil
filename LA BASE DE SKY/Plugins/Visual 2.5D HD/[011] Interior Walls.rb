#===============================================================================
# Visual 2.5D HD - Paredes interiores (tag 20)
#-------------------------------------------------------------------------------
# Terrain tag :InteriorWall (20) = tapa del muro interior (p.ej. tile 385 en la
# capa MakerStudio del mapa 196, columnas 37/43 del pasillo).
#
# En esta proyeccion (pitch sin yaw) una cara que mira al este/oeste queda de
# canto: un tile pri sube ~4 px por nivel sobre su fila y lo elevado se separa
# ~1 px por nivel, asi que la cara "real" mide 3 px. No hay cara que derivar.
#
# Lo que se pinta es el GROSOR del muro: una franja vertical de ancho fijo
# (INTERIOR_SIDE_WIDTH) pegada al canto que da al hueco, en la misma banda
# vertical que la tapa (tile pri-h) para que acabe a la cota de la masa vecina.
# La franja de cada casilla se estira hasta la de la casilla siguiente, asi que
# el tramo sale continuo en vez de una fila de dominos.
#===============================================================================
GameData::TerrainTag.register({ :id => :InteriorWall, :id_number => 20 })

module Visual25D
  #=============================================================================
  # Casillas tag 20 con altura y celdas fuente de textura por nivel
  #=============================================================================
  class InteriorWallField
    # x, y casilla; dirs = lados con hueco (:E/:W); height en tiles;
    # levels = celda fuente [sx, sy] por nivel de altura;
    # run_start = primera casilla del tramo (cierra la esquina hacia el norte);
    # run_end = ultima casilla del tramo hacia el sur (cierra la esquina)
    Cell = Struct.new(:x, :y, :dirs, :height, :levels, :run_start, :run_end, :south_h, :north_h)

    attr_reader :cells
    attr_reader :flat

    def initialize(map)
      @cells = []
      @flat = true
      return if !Config::INTERIOR_WALLS
      return if !scan(map)
      @flat = false
    end

    private

    def scan(map)
      tag = Config::INTERIOR_WALL_TAG
      return false if !tileset_uses_tag?(map, tag)
      return false if !GameData::TerrainTag.try_get(tag)
      cols = {}
      map.height.times do |y|
        map.width.times do |x|
          next if map.terrain_tag(x, y, true).id != tag
          cols[x] ||= []
          cols[x].push(y)
        end
      end
      # La pila de textura es la del extremo sur de cada tramo contiguo, asi que
      # se resuelve una vez por tramo y no por casilla.
      cols.each do |x, ys|
        ys.sort!
        start = ys[0]
        prev = ys[0]
        (1...ys.length).each do |i|
          y = ys[i]
          if y == prev + 1
            prev = y
            next
          end
          push_run(map, x, start, prev, tag)
          start = y
          prev = y
        end
        push_run(map, x, start, prev, tag)
      end
      return !@cells.empty?
    end

    def push_run(map, x, y0, y1, tag)
      stack = own_run_stack(map, x, y0, y1)
      stack = resolve_stack(map, x, y1) if stack.empty?
      # run_start/run_end son de la PRIMERA/ULTIMA casilla que de verdad se
      # pinta (dirs no vacio), no del y0/y1 del escaneo crudo: las filas de
      # los extremos pueden no tener hueco lateral (vecino con suelo/adorno,
      # no realmente abierto) y saltarse, dejando la esquina real mas adentro.
      rows = []
      (y0..y1).each do |y|
        dirs = side_dirs(map, x, y, tag)
        next if dirs.empty?
        rows.push([y, dirs])
      end
      return if rows.empty?
      first_y = rows.first[0]
      last_y = rows.last[0]
      rows.each do |y, dirs|
        height = Visual25D.interior_wall_height(map, x, y)
        south_h = Visual25D.interior_wall_height(map, x, y + 1)
        north_h = Visual25D.interior_wall_height(map, x, y - 1)
        @cells.push(Cell.new(
          x, y, dirs, height, levels_for(stack, height),
          y == first_y, y == last_y, south_h, north_h
        ))
      end
    end

    # Pila de textura del PROPIO tramo: el tag 20 suele ir pegado (capa
    # extendida) encima del muro real (capas nativas) al que hace de tapa, asi
    # que ese muro YA es la textura correcta. Se prueba antes que salir a
    # buscar al sur (resolve_stack): sin esto, un tramo con muro real debajo
    # pero nada util al sur (p.ej. el borde exterior, prioridad fuera de
    # rango) se quedaba sin pila y caia al color de relleno -- salia negro.
    def own_run_stack(map, x, y0, y1)
      found = []
      (y0..y1).each do |y|
        pri = texture_pri(map, x, y)
        next if pri <= 0
        found.push([pri, x, y])
      end
      return [] if found.empty?
      found.sort_by! { |pri, _sx, _sy| pri }
      return found.map { |_pri, sx, sy| [sx, sy] }
    end

    def tileset_uses_tag?(map, tag)
      return true if defined?(MakerStudio) && MakerStudio::ENABLED &&
                     MakerStudio.get_extended_data_for(map.map_id)
      tags = map.terrain_tags
      return false if !tags
      number = GameData::TerrainTag.try_get(tag).id_number
      tags.xsize.times { |tile_id| return true if tags[tile_id] == number }
      return false
    end

    # La cara lateral solo existe donde hay hueco al este u oeste (el pasillo).
    # Sin hueco lateral la casilla se queda solo con su tapa.
    def side_dirs(map, x, y, tag)
      dirs = []
      dirs.push(:E) if open_cell?(map, x + 1, y, tag)
      dirs.push(:W) if open_cell?(map, x - 1, y, tag)
      return dirs
    end

    def open_cell?(map, x, y, tag)
      return false if x < 0 || y < 0 || x >= map.width || y >= map.height
      return false if map.terrain_tag(x, y, true).id == tag
      return body_pri(map, x, y) <= 0
    end

    # Prioridad de cuerpo de muro de la casilla (0 = suelo/hueco).
    def body_pri(map, x, y)
      data = map.data
      return 0 if !data
      best = 0
      [0, 1, 2].each do |layer|
        tid = data[x, y, layer].to_i
        next if tid <= 0
        pri = (map.priorities[tid] || 0).to_i
        best = pri if pri > best
      end
      return best
    end

    # Prioridad usable como textura (pri 4-5 = techo/borde de frente).
    def texture_pri(map, x, y)
      max_pri = Config::INTERIOR_SRC_PRI_MAX.to_i
      max_pri = 3 if max_pri <= 0
      best = 0
      data = map.data
      return 0 if !data
      [0, 1, 2].each do |layer|
        tid = data[x, y, layer].to_i
        next if tid <= 0
        pri = (map.priorities[tid] || 0).to_i
        next if pri < 1 || pri > max_pri
        best = pri if pri > best
      end
      return best
    end

    # Pila de la esquina: cuerpo pri contiguo en la misma columna hacia el sur
    # (mapa 196: tag 20 en (37,27..42) → pared de frente en (37,43..45) 3/2/1).
    # Devuelve celdas ordenadas por prioridad ascendente.
    def resolve_stack(map, x, y)
      stack = column_stack(map, x, y)
      return stack if !stack.empty?
      range = Config::INTERIOR_SRC_RANGE.to_i
      range = 6 if range <= 0
      (1..range).each do |d|
        [x - d, x + d].each do |nx|
          next if nx < 0 || nx >= map.width
          stack = column_stack(map, nx, y)
          return stack if !stack.empty?
        end
      end
      return []
    end

    def column_stack(map, x, y)
      range = Config::INTERIOR_SRC_RANGE.to_i
      range = 6 if range <= 0
      limit = [range * 4, 24].max
      found = []
      ny = y + 1
      while ny < map.height && (ny - y) <= limit
        pri = texture_pri(map, x, ny)
        if pri <= 0
          break if !found.empty?
          ny += 1
          next
        end
        found.push([pri, x, ny])
        ny += 1
      end
      return [] if found.empty?
      found.sort_by! { |pri, _sx, _sy| pri }
      return found.map { |_pri, sx, sy| [sx, sy] }
    end

    # Banda 1 = zocalo (pri mas bajo), banda H = remate (pri mas alto), medias
    # con el panel intermedio. Sin pila usable: nil → color de relleno.
    def levels_for(stack, height)
      return Array.new(height) if stack.empty?
      last = stack.length - 1
      mid = (last > 1) ? 1 : last
      return Array.new(height) do |i|
        band = i + 1
        if band == 1
          stack[0]
        elsif band >= height
          stack[last]
        else
          stack[mid]
        end
      end
    end
  end

  #=============================================================================
  # Pool de franjas: 1 sprite por casilla y lado expuesto
  #=============================================================================
  class InteriorWallLayer
    VIEW_RADIUS = 20

    def initialize
      @sprites = []
      @bitmaps = {}
      @edge_ok = {}
      @fallback = nil
      @map_id = nil
      @field = nil
      @viewport = nil
      @needed = []
      @set_map_id = nil
      @set_px = nil
      @set_py = nil
      @place_dx = nil
      @place_dy = nil
      @place_stamp = nil
      @hidden = false
    end

    def update
      if !Config::INTERIOR_WALLS || !Visual25D.enabled?
        hide_all
        clear_sigs
        return
      end
      map = $game_map
      return hide_all_and_clear_sig if !map
      ensure_field(map)
      return hide_all_and_clear_sig if !@field || @field.flat
      renderer = ($scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer)) ? $scene.map_renderer : nil
      return hide_all_and_clear_sig if !renderer || renderer.disposed?
      @viewport = renderer.viewport
      Visual25D.ensure_projection
      px = $game_player.x
      py = $game_player.y
      dx = map.display_x
      dy = map.display_y
      stamp = Visual25D.projection_stamp
      if !@hidden && @set_map_id == map.map_id && @set_px == px && @set_py == py &&
         @place_dx == dx && @place_dy == dy && @place_stamp == stamp
        return
      end
      @hidden = false
      if @set_map_id != map.map_id || @set_px != px || @set_py != py
        @set_map_id = map.map_id
        @set_px = px
        @set_py = py
        @needed = @field.cells.select do |cell|
          next false if (cell.x - px).abs > VIEW_RADIUS
          next false if (cell.y - py).abs > VIEW_RADIUS
          true
        end
      end
      @place_dx = dx
      @place_dy = dy
      @place_stamp = stamp
      place_all(map, renderer)
    end

    def dispose
      @sprites.each { |s| s.dispose if s && !s.disposed? }
      @sprites.clear
      dispose_bitmaps_only
      @map_id = nil
      clear_sigs
    end

    private

    def hide_all
      @sprites.each { |s| s.visible = false if s && !s.disposed? }
      @hidden = true
    end

    def clear_sigs
      @set_map_id = nil
      @set_px = nil
      @set_py = nil
      @place_dx = nil
      @place_dy = nil
      @place_stamp = nil
      @needed = []
    end

    def hide_all_and_clear_sig
      hide_all
      clear_sigs
    end

    def ensure_field(map)
      if @map_id != map.map_id
        dispose_bitmaps_only
        @map_id = map.map_id
      end
      @field = Visual25D.interior_wall_field(map)
    end

    def dispose_bitmaps_only
      @bitmaps.each_value { |b| b.dispose if b && !b.disposed? }
      @bitmaps.clear
      @edge_ok.clear
      @fallback&.dispose
      @fallback = nil
      @field = nil
    end

    # true si el borde recortado (edge_x..edge_x+strip) del bitmap no es un
    # margen de sombra/relleno casi negro pegado al canto. Umbral generoso:
    # solo descarta bordes claramente vacios, no textura de piedra oscura.
    # Cacheado por bitmap+borde+ancho: recorta 1-2 veces por tile, no por frame.
    def edge_usable?(bmp, edge_x, strip)
      key = [bmp.object_id, edge_x, strip]
      cached = @edge_ok[key]
      return cached unless cached.nil?
      total = 0
      count = 0
      step = [bmp.height / 8, 1].max
      0.step(bmp.height - 1, step) do |y|
        strip.times do |dx|
          c = bmp.get_pixel(edge_x + dx, y)
          total += c.red + c.green + c.blue
          count += 1
        end
      end
      avg = count > 0 ? total / (count * 3).to_f : 255
      ok = avg >= 24
      @edge_ok[key] = ok
      return ok
    end

    def make_sprite
      sprite = Sprite.new(@viewport)
      sprite.visible = false
      return sprite
    end

    def place_all(map, renderer)
      Visual25D.prime_map_offsets!
      tile_w = TilemapRenderer::DISPLAY_TILE_WIDTH
      tile_h = TilemapRenderer::DISPLAY_TILE_HEIGHT
      offset = Visual25D.map_tile_offset(map)
      pox = renderer.instance_variable_get(:@pixel_offset_x).to_i
      poy = renderer.instance_variable_get(:@pixel_offset_y).to_i
      walls = Visual25D.wall_field(map)
      walls = nil if walls&.flat
      seal = Config::WALL_SIDE_SEAL.to_i
      seal = 0 if seal < 0
      vseal = Config::WALL_EDGE_SEAL.to_i
      vseal = 0 if vseal < 0
      thick = Config::INTERIOR_SIDE_WIDTH.to_i
      thick = 1 if thick < 1
      used = 0
      @needed.each do |cell|
        row = cell.y - offset[1] + Visual25D.margin_rows
        col = cell.x - offset[0] + Visual25D.margin_columns
        cell_left = (col * tile_w) - pox
        height = cell.height.to_i
        height = 1 if height < 1
        # Misma banda vertical que la tapa (tile pri-h): asi la franja acaba a la
        # cota de la cima del muro y de la masa vecina, sin escalones.
        x_row = row + height - 1
        unit = Visual25D.row_unit(x_row)
        unit = Visual25D.vertical_unit_at(((x_row + 1) * tile_h) - poy) if unit <= 0
        next if unit <= 0
        scale = Visual25D.row_width_scale(x_row)
        feet = Visual25D.wall_column_feet_y(walls, cell.x, cell.y, row, height)
        top = (feet - (height * unit)).round
        bottom = (feet - ((height - 1) * unit)).round
        # En primer plano la fila mide mas que unit, asi que la banda de la tapa no
        # llega a la de la casilla siguiente: la franja se estira hasta ella o
        # quedan cortes negros cada fila (los "dominos").
        #
        # La casilla siguiente puede tener SU PROPIA altura distinta (own_priority
        # por celda, ya no un h uniforme de tramo): usar la de esta celda para el
        # estiramiento deja un hueco de 1-2px justo en la fila donde cambia (p.ej.
        # el remate alto de una esquina bajando al cuerpo llano del muro).
        nxt_h = cell.south_h.to_i
        nxt_h = height if nxt_h < 1
        nxt_unit = Visual25D.row_unit(row + nxt_h)
        nxt_unit = unit if nxt_unit <= 0
        nxt_feet = Visual25D.wall_column_feet_y(walls, cell.x, cell.y + 1, row + 1, nxt_h)
        nxt_top = (nxt_feet - (nxt_h * nxt_unit)).round
        bottom = nxt_top if nxt_top > bottom
        # Fin de tramo: la franja baja hasta el suelo para cerrar la esquina.
        if cell.run_end
          floor = Visual25D.wall_edge_y(walls, cell.x, cell.y + 1, row + 1)
          bottom = floor if floor > bottom
        end
        # Inicio de tramo: nada dentro del tramo estira SU tapa hacia esta, asi
        # que si hay un muro real justo al norte (la pared/borde de arriba de
        # la sala) la franja se queda corta y deja un hueco en la esquina. Se
        # estira hacia arriba igual que hacia abajo, con la altura real de esa
        # casilla vecina.
        if cell.run_start
          prev_h = cell.north_h.to_i
          if prev_h >= 1
            prev_x_row = (row - 1) + prev_h - 1
            prev_unit = Visual25D.row_unit(prev_x_row)
            prev_unit = unit if prev_unit <= 0
            prev_feet = Visual25D.wall_column_feet_y(walls, cell.x, cell.y - 1, row - 1, prev_h)
            prev_top = (prev_feet - (prev_h * prev_unit)).round
            top = prev_top if prev_top < top
          end
          top -= vseal
        end
        bottom += vseal
        band_h = bottom - top
        band_h = 1 if band_h < 1
        # Grosor del muro: px fijos de config, encogidos con la fila para que no
        # engorde en el fondo.
        width = (thick * scale).round
        width = 1 if width < 1
        width = tile_w if width > tile_w
        z = Visual25D.raised_tile_z((((row + height + 1) * tile_h) - poy) + 1) + 1
        # Pila completa: zocalo abajo, remate arriba. Una sola franja, mismo ancho.
        bmp = stack_bitmap(map, cell.levels, height)
        cell.dirs.each do |dir|
          # Canto interior del cubo: la franja crece hacia dentro del muro.
          edge_x = (dir == :E) ? (cell_left + tile_w) : cell_left
          anchor = Visual25D.project_x(edge_x, scale)
          if dir == :E
            right = anchor + seal
            left = right - width
          else
            left = anchor - seal
            right = left + width
          end
          span = right - left
          span = 1 if span < 1
          @sprites.push(make_sprite) if @sprites.length <= used
          sprite = @sprites[used]
          if !sprite || sprite.disposed? || sprite.viewport != @viewport
            sprite.dispose if sprite && !sprite.disposed?
            sprite = @sprites[used] = make_sprite
          end
          # Tira del panel pegada al canto, del ancho de la franja: el ladrillo
          # no se aplasta, solo se recorta.
          strip = span
          strip = bmp.width if strip > bmp.width
          strip = 1 if strip < 1
          edge_x = (dir == :E) ? (bmp.width - strip) : 0
          # Algunos tiles pintan un margen de sombra casi negro pegado al borde
          # (p.ej. la viga de madera de Ruinas): recortar justo ESE borde saca
          # negro solido en vez de textura. Si el recorte sale oscuro de mas,
          # usar el color de relleno en su lugar.
          use_bmp = edge_usable?(bmp, edge_x, strip) ? bmp : fallback_bitmap
          sprite.bitmap = use_bmp if sprite.bitmap != use_bmp
          sr = sprite.src_rect
          sx = (use_bmp == bmp) ? edge_x : 0
          sh = use_bmp.height
          if sr.x != sx || sr.y != 0 || sr.width != strip || sr.height != sh
            sr.x = sx
            sr.y = 0
            sr.width = strip
            sr.height = sh
            sprite.src_rect = sr
          end
          sprite.ox = 0 if sprite.ox != 0
          sprite.oy = 0 if sprite.oy != 0
          sprite.x = left if sprite.x != left
          sprite.y = top if sprite.y != top
          zx = span / strip.to_f
          zy = band_h / [use_bmp.height, 1].max.to_f
          sprite.zoom_x = zx if sprite.zoom_x != zx
          sprite.zoom_y = zy if sprite.zoom_y != zy
          sprite.z = z if sprite.z != z
          sprite.opacity = 255 if sprite.opacity != 255
          sprite.visible = true if !sprite.visible
          used += 1
        end
      end
      (@sprites.length - 1).downto(used) do |i|
        spr = @sprites[i]
        spr.visible = false if spr && !spr.disposed?
      end
    end

    def band_bitmap(map, source)
      return fallback_bitmap if !source
      sx = source[0].to_i
      sy = source[1].to_i
      key = (map.map_id.to_i * 1_000_000) + (sx * 1000) + sy
      bmp = @bitmaps[key]
      return bmp if bmp && !bmp.disposed?
      @bitmaps[key] = capture_cell(map, sx, sy)
      return @bitmaps[key]
    end

    # Una bitmap por tramo: cada nivel de la pila ocupa una franja igual.
    # levels[0] = zocalo (abajo). levels[height-1] = remate (arriba).
    def stack_bitmap(map, levels, height)
      height = height.to_i
      height = 1 if height < 1
      parts = []
      height.times do |i|
        src = levels && levels[i]
        parts << (src ? "#{src[0].to_i},#{src[1].to_i}" : "-")
      end
      key = "stack:#{map.map_id}:#{parts.join(';')}"
      bmp = @bitmaps[key]
      return bmp if bmp && !bmp.disposed?
      w = TilemapRenderer::SOURCE_TILE_WIDTH
      h = TilemapRenderer::SOURCE_TILE_HEIGHT
      out = Bitmap.new(w, h * height)
      height.times do |i|
        src = levels && levels[i]
        band = src ? band_bitmap(map, src) : fallback_bitmap
        next if !band || band.disposed?
        dest_y = (height - 1 - i) * h
        out.blt(0, dest_y, band, Rect.new(0, 0, [band.width, w].min, [band.height, h].min))
      end
      @bitmaps[key] = out
      return out
    end

    # Panel = capas usables de la celda fuente, como las pinta el motor.
    def capture_cell(map, sx, sy)
      w = TilemapRenderer::SOURCE_TILE_WIDTH
      h = TilemapRenderer::SOURCE_TILE_HEIGHT
      bmp = Bitmap.new(w, h)
      bmp.fill_rect(0, 0, w, h, Config::INTERIOR_WALL_FALLBACK)
      renderer = $scene&.map_renderer
      return bmp if !renderer || renderer.disposed?
      tiles = layer_tiles(map, sx, sy)
      return bmp if tiles.empty?
      temp = TilemapRenderer::TileSprite.new(renderer.viewport)
      begin
        tiles.each do |tid|
          renderer.refresh_tile_bitmap(temp, map, tid)
          next if !temp.bitmap || temp.bitmap.disposed?
          bmp.blt(0, 0, temp.bitmap, temp.src_rect)
        end
      ensure
        temp.dispose
      end
      return bmp
    end

    def layer_tiles(map, sx, sy)
      data = map.data
      return [] if !data
      max_pri = Config::INTERIOR_SRC_PRI_MAX.to_i
      max_pri = 3 if max_pri <= 0
      tiles = []
      [0, 1, 2].each do |layer|
        tid = data[sx, sy, layer].to_i
        next if tid <= 0
        pri = (map.priorities[tid] || 0).to_i
        next if pri > max_pri
        tiles.push(tid)
      end
      return tiles
    end

    def fallback_bitmap
      return @fallback if @fallback && !@fallback.disposed?
      w = TilemapRenderer::SOURCE_TILE_WIDTH
      h = TilemapRenderer::SOURCE_TILE_HEIGHT
      @fallback = Bitmap.new(w, h)
      @fallback.fill_rect(0, 0, w, h, Config::INTERIOR_WALL_FALLBACK)
      return @fallback
    end
  end

  class << self
    def interior_wall_field(map)
      return nil if !map || !Config::INTERIOR_WALLS
      @interior_wall_fields ||= {}
      field = @interior_wall_fields[map.map_id]
      return field if field
      return @interior_wall_fields[map.map_id] = InteriorWallField.new(map)
    end

    # Nombre historico: lo llama Core al recalcular la tabla de filas.
    def clear_interior_faces(map_id = nil)
      return if !@interior_wall_fields
      if map_id
        @interior_wall_fields.delete(map_id)
      else
        @interior_wall_fields.clear
      end
    end
  end
end

#===============================================================================
# Ciclo de vida
#===============================================================================
class Scene_Map
  alias hd25_iw_createSpritesets createSpritesets unless method_defined?(:hd25_iw_createSpritesets)
  def createSpritesets
    hd25_iw_createSpritesets
    @hd25_interior_walls = Visual25D::InteriorWallLayer.new if !@hd25_interior_walls
  end

  alias hd25_iw_disposeSpritesets disposeSpritesets unless method_defined?(:hd25_iw_disposeSpritesets)
  def disposeSpritesets
    hd25_iw_disposeSpritesets
    @hd25_interior_walls&.dispose
    @hd25_interior_walls = nil
  end

  alias hd25_iw_updateSpritesets updateSpritesets unless method_defined?(:hd25_iw_updateSpritesets)
  def updateSpritesets(refresh = false)
    hd25_iw_updateSpritesets(refresh)
    @hd25_interior_walls&.update
  end
end

class Game_Map
  alias hd25_iw_setup setup unless method_defined?(:hd25_iw_setup)
  def setup(map_id)
    hd25_iw_setup(map_id)
    Visual25D.clear_interior_faces(map_id)
  end
end