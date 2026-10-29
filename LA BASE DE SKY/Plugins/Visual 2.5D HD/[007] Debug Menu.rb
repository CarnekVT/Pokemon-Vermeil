#===============================================================================
# Visual 2.5D HD - Menu de camara
#-------------------------------------------------------------------------------
# Se abre con  pbVisual25DMenu  desde el script de un evento, o desde
# Depuracion -> Campo -> Visual 2.5D HD.
#
# Cada valor se elige con un selector de numeros que indica su rango, y al
# confirmarlo el mapa se recoloca al instante. Todo queda guardado en la partida.
#===============================================================================
def pbVisual25DMenu
  return if !$DEBUG
  loop do
    state = Visual25D.enabled ? _INTL("activado") : _INTL("desactivado")
    model = (Visual25D.projection_model == :camera) ? _INTL("cámara") : _INTL("clásico")
    round = (Visual25D.horizon_curve_px > 0.5) ? _INTL("redondo") : _INTL("plano")
    command = pbMessage(
      _INTL("Cámara 2.5D ({1}).\nÁngulo {2}°, distancia {3}%, altura {4} px.\nModelo {5}, FOV {6}°, terreno {7}.",
            state, Visual25D.tilt, Visual25D.camera_zoom, Visual25D.tile_lift,
            model, Visual25D.camera_fov.to_i, round),
      [_INTL("Ángulo de la cámara"),
       _INTL("Distancia de dibujado"),
       _INTL("Altura de los verticales"),
       _INTL("Modelo de proyección"),
       _INTL("FOV de cámara"),
       _INTL("Desenfoque de bordes ({1})", Visual25D.band_blur? ? _INTL("sí") : _INTL("no")),
       _INTL("Suelo por filas ({1})", Visual25D.row_batch? ? _INTL("sí") : _INTL("no")),
       _INTL("Activar/desactivar"),
       _INTL("Ajustes avanzados de geometría"),
       _INTL("Restaurar valores"),
       _INTL("Salir")], 11
    )
    case command
    when 0
      max = Visual25D::Config::MAX_TILT_DEGREES
      Visual25D.tilt = pbVisual25DChooseNumber(
        _INTL("Ángulo de la cámara, en grados (de 0 a {1}).\nCuanto mayor, más lejos se ve.", max),
        Visual25D.tilt, 0, max
      )
    when 1
      min = Visual25D::Config::MIN_CAMERA_ZOOM
      max = Visual25D::Config::MAX_CAMERA_ZOOM
      Visual25D.camera_zoom = pbVisual25DChooseNumber(
        _INTL("Distancia de dibujado, en porcentaje (de {1} a {2}).\nPor debajo de 100 la cámara se aleja y se ve más mapa.", min, max),
        Visual25D.camera_zoom, min, max
      )
    when 2
      Visual25D.tile_lift = pbVisual25DChooseNumber(
        _INTL("Píxeles que se levanta un tile por cada nivel de prioridad (de 0 a 24)."),
        Visual25D.tile_lift, 0, 24
      )
    when 3
      # Sesión only: no PokemonSystem.
      choice = pbMessage(
        _INTL("Modelo de proyección del suelo.\nClásico = estable (default).\nCámara = 1/profundidad (pulido v3.0.43)."),
        [_INTL("Clásico"), _INTL("Cámara"), _INTL("Cancelar")], 3
      )
      case choice
      when 0 then Visual25D.projection_model = :classic
      when 1 then Visual25D.projection_model = :camera
      end
    when 4
      Visual25D.camera_fov = pbVisual25DChooseNumber(
        _INTL("FOV vertical en grados (de 20 a 90).\nSolo modelo Cámara. Más alto = perspectiva más suave."),
        Visual25D.camera_fov.to_i, 20, 90
      )
    when 5
      Visual25D.band_blur = !Visual25D.band_blur?
    when 6
      Visual25D.row_batch = !Visual25D.row_batch?
    when 7
      Visual25D.toggle_smooth
      break
    when 8
      pbVisual25DGeometryMenu
    when 9
      pbVisual25DResetTuning
      Visual25D.reset_to_defaults
    else
      break
    end
  end
end

# Controles de geometria de esta sesion. Solo en Depuracion: no afectan
# al jugador ni crean archivos o preferencias persistentes.
VISUAL25D_GEOMETRY_DEFAULTS = {
  :VANISHING_STRENGTH => 0.3, :VERTICAL_GAIN => 0.4,
  :COLUMN_LEAN => 0.0, :WALL_SMOOTHING => 0,
  :WALL_SMOOTH_VERTICAL => false, :WALL_EDGE_SEAL => 2,
  :GROUND_SLICES => 1, :AUTO_COLUMN_PRIORITY => true,
  :TIGHT_GRID => true
}
def pbVisual25DGeometrySet(name, value)
  return unless $DEBUG
  cfg = Visual25D::Config
  return if cfg.const_get(name) == value
  cfg.send(:remove_const, name)
  cfg.const_set(name, value)
  Visual25D.rebuild_render_params!
  Visual25D.clear_column_stack_cache! if Visual25D.respond_to?(:clear_column_stack_cache!)
  Visual25D.redraw_map
end
def pbVisual25DResetTuning
  return unless $DEBUG
  VISUAL25D_GEOMETRY_DEFAULTS.each do |name, val|
    cfg = Visual25D::Config
    cfg.send(:remove_const, name)
    cfg.const_set(name, val)
  end
  eigen = Visual25D.singleton_class
  eigen.send(:remove_const, :COLUMN_BAND_OVERLAP) if eigen.const_defined?(:COLUMN_BAND_OVERLAP, false)
  eigen.const_set(:COLUMN_BAND_OVERLAP, 2)
end
def pbVisual25DGeometryMenu
  return unless $DEBUG
  cfg = Visual25D::Config
  loop do
    cmd = pbMessage(_INTL("Geometría 2.5D (solo debug). Los cambios no se guardan."),
      [
        _INTL("Convergencia horizontal: {1}%", (cfg::VANISHING_STRENGTH * 100).round),
        _INTL("Altura vertical: {1}%", (cfg::VERTICAL_GAIN * 100).round),
        _INTL("Inclinación de columnas: {1}%", (cfg::COLUMN_LEAN * 100).round),
        _INTL("Suavizado de montaña: {1}", cfg::WALL_SMOOTHING),
        _INTL("Suavizado vertical: {1}", cfg::WALL_SMOOTH_VERTICAL ? _INTL("Sí") : _INTL("No")),
        _INTL("Solape de bordes: {1} px", cfg::WALL_EDGE_SEAL),
        _INTL("Solape de tiles: {1} px", Visual25D.column_band_overlap),
        _INTL("Franjas de suelo: {1}", cfg::GROUND_SLICES),
        _INTL("Unir columnas del tileset: {1}", cfg::AUTO_COLUMN_PRIORITY ? _INTL("Sí") : _INTL("No")),
        _INTL("Rejilla optimizada: {1}", cfg::TIGHT_GRID ? _INTL("Sí") : _INTL("No")),
        _INTL("Restaurar geometría"), _INTL("Volver")
      ], 12)
    case cmd
    when 0
      n = pbVisual25DChooseNumber(_INTL("Convergencia horizontal, 0–60%."), (cfg::VANISHING_STRENGTH * 100).round, 0, 60)
      pbVisual25DGeometrySet(:VANISHING_STRENGTH, n / 100.0)
    when 1
      n = pbVisual25DChooseNumber(_INTL("Altura de árboles, edificios y columnas, 0–100%."), (cfg::VERTICAL_GAIN * 100).round, 0, 100)
      pbVisual25DGeometrySet(:VERTICAL_GAIN, n / 100.0)
    when 2
      n = pbVisual25DChooseNumber(_INTL("Inclinación lateral de las columnas, 0–50%."), (cfg::COLUMN_LEAN * 100).round, 0, 50)
      pbVisual25DGeometrySet(:COLUMN_LEAN, n / 100.0)
    when 3
      n = pbVisual25DChooseNumber(_INTL("Suavizado de montaña, 0–5 pasadas."), cfg::WALL_SMOOTHING, 0, 5)
      pbVisual25DGeometrySet(:WALL_SMOOTHING, n)
    when 4
      pbVisual25DGeometrySet(:WALL_SMOOTH_VERTICAL, !cfg::WALL_SMOOTH_VERTICAL)
    when 5
      n = pbVisual25DChooseNumber(_INTL("Solape de bordes, 0–4 píxeles."), cfg::WALL_EDGE_SEAL, 0, 4)
      pbVisual25DGeometrySet(:WALL_EDGE_SEAL, n)
    when 6
      eigen = Visual25D.singleton_class
      n = pbVisual25DChooseNumber(_INTL("Solape entre tiles verticales, 0–4 píxeles."), Visual25D.column_band_overlap, 0, 4)
      if n != Visual25D.column_band_overlap
        eigen.send(:remove_const, :COLUMN_BAND_OVERLAP)
        eigen.const_set(:COLUMN_BAND_OVERLAP, n)
        Visual25D.clear_column_stack_cache!
        Visual25D.redraw_map
      end
    when 7
      n = pbVisual25DChooseNumber(_INTL("Franjas de suelo. 1 es la opción más rápida."), cfg::GROUND_SLICES, 1, 4)
      pbVisual25DGeometrySet(:GROUND_SLICES, n == 3 ? 2 : n)
    when 8
      pbVisual25DGeometrySet(:AUTO_COLUMN_PRIORITY, !cfg::AUTO_COLUMN_PRIORITY)
    when 9
      pbVisual25DGeometrySet(:TIGHT_GRID, !cfg::TIGHT_GRID)
    when 10
      pbVisual25DResetTuning
      Visual25D.rebuild_render_params!
      Visual25D.redraw_map
    else
      break
    end
  end
end

def pbVisual25DChooseNumber(message, current, min, max)
  params = ChooseNumberParams.new
  params.setRange(min, max)
  params.setInitialValue(current)
  params.setCancelValue(current)
  return pbMessageChooseNumber(message, params)
end

# Compatibilidad con eventos antiguos; el horizonte permanece recto.
def pbVisual25DMundoRedondo
  Visual25D.horizon_curve = 0
  $PokemonSystem.visual25d_round = false if $PokemonSystem&.respond_to?(:visual25d_round=)
end

#===============================================================================
# Diagnostico temporal: vuelca la Z real del jugador y la de los tiles con
# prioridad que tiene encima, para ver quien gana el dibujado y por que.
#===============================================================================
def pbVisual25DZReport
  renderer = $scene.map_renderer
  tiles = renderer.instance_variable_get(:@tiles)
  pixel_offset_y = renderer.instance_variable_get(:@pixel_offset_y)
  sprite = nil
  ($scene.instance_variable_get(:@spritesets) || {}).each_value do |sset|
    list = sset.instance_variable_get(:@character_sprites)
    next if !list
    found = list.find { |s| s.character == $game_player }
    sprite = found if found
  end
  ground = $game_player.screen_y_ground
  ch = sprite ? sprite.instance_variable_get(:@ch) : 0
  lines = []
  lines << "--- Visual 2.5D: diagnostico de Z ---"
  lines << "activo=#{Visual25D.enabled?} margen_filas=#{Visual25D.margin_rows} pixel_offset_y=#{pixel_offset_y}"
  lines << "jugador: suelo=#{ground} ch=#{ch} alto_proyectado=#{Visual25D.projected_height(ch, ground)}"
  lines << "jugador: screen_z_motor=#{$game_player.screen_z(Visual25D.projected_height(ch, ground))} z_sprite=#{sprite&.z}"
  lines << "jugador: sprite x=#{sprite&.x} y=#{sprite&.y} viewport=#{sprite&.viewport.object_id}"
  lines << "tilemap viewport=#{renderer.viewport.object_id}"
  found = []
  tiles.each_with_index do |col, i|
    col.each_with_index do |cell, j|
      cell.each_with_index do |tile, layer|
        next if !sprite
        next if tile.tile_id.to_i <= 0
        next if (tile.x - sprite.x).abs > 40
        next if tile.y > sprite.y + 8 || tile.y < sprite.y - 120
        band = tile.respond_to?(:cell_band) ? tile.cell_band.inspect : "-"
        found << "  [#{i},#{j},L#{layer}] pri=#{tile.priority} banda=#{band} z=#{tile.z} y=#{tile.y}"
      end
    end
  end
  lines << "tiles alrededor de la cabeza del jugador (#{found.length}):"
  lines.concat(found[0, 20])
  lines.each { |l| echoln(l) }
  pbMessage(lines[0, 6].join("\n"))
  pbMessage((["tiles sobre la cabeza:"] + found[0, 6]).join("\n")) if !found.empty?
end

#===============================================================================
# Mapa de alturas. Vuelca a la consola la rejilla de ESQUINAS que hay alrededor
# del jugador, que es donde vive de verdad la altura del terreno. Cada casilla
# del mapa queda entre cuatro de esos numeros.
#
#   .     suelo normal        X  el jugador
#   1..9  cuanto se levanta el borde de arriba de esa casilla, redondeado. Un
#         bordillo de dos tiles sale como 2 arriba y 1 abajo.
#   -     levantamiento parcial, del suavizado hacia los extremos
#   !     rotura de run vertical (Cliff con vecino abajo de tramo distinto)
#   >     desnivel lateral fuerte vs casilla de la izquierda (dentado)
#===============================================================================
def pbVisual25DWallMap(radius = 14)
  map = $game_map
  field = Visual25D.wall_field(map)
  if !field || field.flat
    pbMessage(_INTL("Este mapa no tiene ningún tile marcado como pared frontal."))
    return
  end
  left   = [$game_player.x - radius, 0].max
  right  = [$game_player.x + radius, map.width - 1].min
  top    = [$game_player.y - radius, 0].max
  bottom = [$game_player.y + radius, map.height - 1].min
  breaks = 0
  ledges = 0
  echoln("--- Visual 2.5D: paredes frontales (mapa #{map.map_id}) ---")
  echoln("jugador en #{$game_player.x},#{$game_player.y}")
  echoln("leyenda: .=suelo -=suave 1-9=lift !=run_break >=dentado lateral X=jugador")
  (top..bottom).each do |y|
    line = ""
    (left..right).each do |x|
      if x == $game_player.x && y == $game_player.y
        line += "X"
        next
      end
      if field.run_break?(x, y)
        line += "!"
        breaks += 1
        next
      end
      lift = field.lift(x, y)
      if x > left
        delta = (lift - field.lift(x - 1, y)).abs
        if delta >= 0.75
          line += ">"
          ledges += 1
          next
        end
      end
      line += if lift <= 0.0 then "."
              elsif lift < 0.5 then "-"
              else lift.round.to_s
              end
    end
    echoln(line)
  end
  echoln("roturas de run: #{breaks}  dentados laterales: #{ledges}")
  # Continuidad de aristas: bottom(x,y) debe = top(x,y+1) (sin seal).
  renderer = ($scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer)) ? $scene.map_renderer : nil
  mismatches = 0
  if renderer && !renderer.disposed? && Visual25D.enabled?
    Visual25D.update_projection(renderer.instance_variable_get(:@pixel_offset_y))
    echoln("aristas: bottom(y) vs top(y+1) sin seal (gaps si !=):")
    (([$game_player.y - radius, 0].max)..([$game_player.y + radius - 1, map.height - 2].min)).each do |y|
      (([$game_player.x - radius, 0].max)..([$game_player.x + radius, map.width - 1].min)).each do |x|
        next if !field.lifted?(x, y) && !field.lifted?(x, y + 1)
        row = Visual25D.grid_row_for_map_cell(map, y)
        bot = Visual25D.wall_cell_bottom_y(field, x, y, row)
        top = Visual25D.wall_cell_top_y(field, x, y + 1, row + 1)
        delta = bot - top
        next if delta == 0
        mismatches += 1
        echoln("  #{x},#{y}/#{y + 1} bot=#{bot} top=#{top} d=#{delta}")
      end
    end
    echoln("roturas de arista: #{mismatches}")
    # geom = prioridad pintada (geometria); band = cell_band (solo Z).
    # geom>0 con path=flat = bug. geom>0 band=0 path=raised = OK (bajo el cap).
    echoln("tiles cerca: celda geom band pri path:")
    geom_bugs = 0
    under_cap = 0
    seen = {}
    dump_geom_tile = lambda do |tile|
      next if !tile || !tile.bitmap || (tile.respond_to?(:visible) && !tile.visible)
      cx = tile.respond_to?(:hd25_cell_x) ? tile.hd25_cell_x : nil
      cy = tile.respond_to?(:hd25_cell_y) ? tile.hd25_cell_y : nil
      next if cx.nil? || cy.nil?
      next if (cx - $game_player.x).abs > 6 || (cy - $game_player.y).abs > 6
      geom = Visual25D.geom_priority(tile)
      band = tile.respond_to?(:cell_band) && !tile.cell_band.nil? ? tile.cell_band.to_i : -1
      pri  = tile.priority.to_i
      path = Visual25D.geom_raised?(tile) ? "raised" : "flat"
      key = "#{cx},#{cy},#{geom},#{band},#{pri},#{path}"
      next if seen[key]
      seen[key] = true
      flag = ""
      if geom > 0 && path == "flat"
        flag = " [BUG geom flat]"
        geom_bugs += 1
      elsif geom > 0 && band == 0
        flag = " [under-cap raised]"
        under_cap += 1
      end
      echoln("  #{cx},#{cy} geom=#{geom} band=#{band} pri=#{pri} #{path}#{flag}")
    end
    tiles = renderer.instance_variable_get(:@tiles)
    tiles.each { |col| col.each { |cell| cell.each { |t| dump_geom_tile.call(t) } } } if tiles
    ext = renderer.instance_variable_get(:@ext_visible)
    ext.each { |t| dump_geom_tile.call(t) } if ext
    echoln("bugs geom-flat: #{geom_bugs}  under-cap raised: #{under_cap}")
  else
    geom_bugs = 0
  end
  pbMessage(_INTL("Mapa de paredes volcado en la consola.\nRoturas de run: {1}. Dentados: {2}.\nRoturas arista: {3}.\nBugs geom: {4}.",
                  breaks, ledges, mismatches, geom_bugs))
end

#===============================================================================
# Buscador de huecos. Recorre la rejilla que hay dibujada ahora mismo y compara,
# casilla a casilla, donde acaba un tile y donde empieza el de debajo. Si entre
# los dos queda aire, ahi es donde se ve el fondo, y lo canta con su posicion en
# el mapa para poder ir a mirarlo.
#
# Tambien avisa de las casillas que no tienen nada dibujado en ninguna capa: esas
# se ven negras aunque la proyeccion sea correcta, y el arreglo es pintarlas.
#===============================================================================
def pbVisual25DFindGaps
  renderer = $scene.map_renderer
  tiles = renderer.instance_variable_get(:@tiles)
  columns = renderer.instance_variable_get(:@tiles_horizontal_count)
  rows = renderer.instance_variable_get(:@tiles_vertical_count)
  gaps = []
  empty = []
  columns.times do |i|
    rows.times do |j|
      next if j + 1 >= rows
      here = tiles[i][j]
      below = tiles[i][j + 1]
      drawn = here.select { |tile| tile.bitmap && tile.visible && tile.tile_id.to_i > 0 }
      if drawn.empty?
        empty.push([i, j]) if empty.length < 20
        next
      end
      lowest = drawn.map { |tile| tile.y + (tile.src_rect.height * tile.zoom_y).round }.max
      top = below.select { |tile| tile.bitmap && tile.visible && tile.tile_id.to_i > 0 }
                 .map { |tile| tile.y }.min
      next if !top
      gaps.push([i, j, top - lowest]) if top - lowest > 0 && gaps.length < 20
    end
  end
  # Desniveles laterales en el WallField alrededor del jugador (causa tipica
  # de esquinas negras junto a bordillos Cliff).
  field = Visual25D.wall_field($game_map)
  side_gaps = []
  if field && !field.flat
    px = $game_player.x
    py = $game_player.y
    ((py - 8)..(py + 8)).each do |y|
      ((px - 8)..(px + 8)).each do |x|
        next if x <= 0
        delta = (field.lift(x, y) - field.lift(x - 1, y)).abs
        next if delta < 0.75
        side_gaps.push([x, y, delta.round(2)]) if side_gaps.length < 20
      end
    end
  end
  echoln("--- Visual 2.5D: buscador de huecos ---")
  echoln("rejilla #{columns}x#{rows}")
  if gaps.empty?
    echoln("no hay ningun hueco entre tiles: la sabana esta cerrada.")
  else
    echoln("HUECOS (columna, fila de la rejilla, pixeles de aire):")
    gaps.each { |i, j, size| echoln("  #{i},#{j}  #{size} px") }
  end
  if empty.empty?
    echoln("no hay casillas sin dibujar.")
  else
    echoln("CASILLAS SIN NADA PINTADO (se ven negras, hay que pintarlas):")
    empty.each { |i, j| echoln("  rejilla #{i},#{j}") }
  end
  if side_gaps.empty?
    echoln("no hay dentados laterales fuertes cerca del jugador.")
  else
    echoln("DENTADOS LATERALES (mapa x,y, delta lift):")
    side_gaps.each { |x, y, d| echoln("  #{x},#{y}  Δ=#{d}") }
  end
  iw = Visual25D.interior_wall_field($game_map)
  iw_n = (iw && !iw.flat) ? iw.cells.length : 0
  iw_faces = (iw && !iw.flat) ? iw.cells.sum { |cell| cell.dirs.length } : 0
  echoln("InteriorWall casillas en mapa: #{iw_n} (franjas de grosor: #{iw_faces})")
  pbMessage(_INTL("Huecos entre tiles: {1}.\nCasillas sin pintar: {2}.\nDentados laterales: {3}.\nInteriorWall: {4}.\nDetalle en la consola.",
                  gaps.length, empty.length, side_gaps.length, iw_n))
end

MenuHandlers.add(:debug_menu, :visual_25d_hd_gaps, {
  "name"        => _INTL("Visual 2.5D HD: buscar huecos"),
  "parent"      => :field_menu,
  "description" => _INTL("Busca huecos entre tiles y casillas sin pintar en lo que hay en pantalla."),
  "effect"      => proc { pbVisual25DFindGaps }
})

MenuHandlers.add(:debug_menu, :visual_25d_hd, {
  "name"        => _INTL("Visual 2.5D HD"),
  "parent"      => :field_menu,
  "description" => _INTL("Cambia el ángulo de la cámara y la distancia de dibujado del mapa."),
  "effect"      => proc { pbVisual25DMenu }
})

MenuHandlers.add(:debug_menu, :visual_25d_hd_walls, {
  "name"        => _INTL("Visual 2.5D HD: mapa de paredes"),
  "parent"      => :field_menu,
  "description" => _INTL("Vuelca a la consola qué tiles se levantan como pared alrededor del jugador."),
  "effect"      => proc { pbVisual25DWallMap }
})

MenuHandlers.add(:debug_menu, :visual_25d_hd_z, {
  "name"        => _INTL("Visual 2.5D HD: diagnóstico de Z"),
  "parent"      => :field_menu,
  "description" => _INTL("Vuelca la Z del jugador y la de los tiles que tiene encima."),
  "effect"      => proc { pbVisual25DZReport }
})

#===============================================================================
# Probe FPS: 1 linea/seg. Solo echoln (nunca puts).
# Scripts: pbVisual25DPerfProbe / pbVisual25DPerfDump
# Auto en mapas Config::PERF_PROBE_MAPS (p.ej. 205).
#===============================================================================
def pbVisual25DPerfProbe
  Visual25D.perf_enabled = !Visual25D.perf_enabled?
  state = Visual25D.perf_enabled? ? _INTL("activado") : _INTL("desactivado")
  pbMessage(_INTL("Probe de rendimiento 2.5D: {1}.\nMira la consola / mkxp.log (1 línea por segundo, echoln).", state))
end

def pbVisual25DPerfDump
  Visual25D.perf_dump_map_profile!
  pbMessage(_INTL("Perfil del mapa volcado a consola / mkxp.log (echoln)."))
end

MenuHandlers.add(:debug_menu, :visual_25d_hd_perf, {
  "name"        => _INTL("Visual 2.5D HD: probe FPS"),
  "parent"      => :field_menu,
  "description" => _INTL("Activa o desactiva el muestreo de rendimiento (1 línea/seg en consola)."),
  "effect"      => proc { pbVisual25DPerfProbe }
})

MenuHandlers.add(:debug_menu, :visual_25d_hd_perf_dump, {
  "name"        => _INTL("Visual 2.5D HD: dump perfil mapa"),
  "parent"      => :field_menu,
  "description" => _INTL("Vuelca a consola el perfil MS/capas del mapa actual (echoln)."),
  "effect"      => proc { pbVisual25DPerfDump }
})
