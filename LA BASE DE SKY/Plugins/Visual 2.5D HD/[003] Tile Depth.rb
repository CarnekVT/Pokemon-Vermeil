#===============================================================================
# Visual 2.5D HD - Proyeccion del escenario
#-------------------------------------------------------------------------------
# Cada tile pasa por dos transformaciones:
#
#   1. Se proyecta sobre el plano en perspectiva segun la fila que ocupa. Todos
#      los tiles de una misma fila usan la misma escala y el mismo centro, y las
#      filas contiguas comparten borde por construccion, asi que no hay cortes.
#
#   2. Si tiene prioridad > 0 es un elemento vertical: se levanta sobre su
#      casilla de apoyo (la fila "fila + prioridad"), que es comun a toda la
#      columna, de modo que la columna entera sale recta y encajada con su base.
#
# Ademas, para poder alejar la camara hace falta mas mapa del que cabe en la
# pantalla. El motor solo reserva las casillas justas, asi que aqui se amplia su
# rejilla y se corre el encuadre unas casillas hacia arriba y a la izquierda
# mientras dibuja, para que cargue tambien lo que queda fuera de pantalla.
#
# No se modifica ninguna pasabilidad, y la Z sigue calculandose con la fila real.
#===============================================================================
#===============================================================================
# Los enganches siguen el patron del resto del proyecto: el ALIAS va guardado,
# pero la REDEFINICION va fuera de la guarda.
#
# Al pulsar F12 el juego vuelve a ejecutar todos los scripts sin reiniciar las
# clases, y los del motor redefinen sus propios metodos llevandose por delante lo
# que hubiera encima. La guarda evita que el alias se capture dos veces (que
# seria recursion infinita), y redefinir siempre hace que el enganche se vuelva a
# poner en cada reejecucion.
#
# Meter la redefinicion dentro de la guarda es justo lo que rompia: unos
# enganches sobrevivian y otros no, y si sobrevive el que corre el encuadre del
# mapa pero no el que lo compensa en los offsets, todo sale desplazado.
#===============================================================================
class TilemapRenderer
  class TileSprite
    attr_accessor :hd25_zoom_x
    attr_accessor :hd25_zoom_y
    # Ultimo Sprite#taper aplicado. Se cachea igual que el zoom: escribirlo
    # marca la matriz como sucia, asi que no conviene repetirlo por frame.
    attr_accessor :hd25_taper
    # Zoom que quiere otro plugin para este tile (MakerStudio escala algunos con
    # sus efectos por tile). La proyeccion lo multiplica en vez de pisarlo.
    attr_accessor :hd25_base_zoom_x
    attr_accessor :hd25_base_zoom_y
    # Casilla del mapa que muestra el tile, y las paredes de ese mapa. Se
    # resuelve al enlazarlo, que es lo unico que puede cambiarla.
    attr_accessor :hd25_walls
    attr_accessor :hd25_cell_x
    attr_accessor :hd25_cell_y
    attr_accessor :hd25_lifted
    attr_accessor :hd25_map_id
    attr_accessor :hd25_grid_row
    # Prioridad pintada propia (geometria). Independiente de cell_band (solo Z).
    attr_accessor :hd25_geom_priority
    # Copia estable de la prioridad pintada (pool extended recicla sprites).
    attr_accessor :hd25_painted_priority
    # true si este frame aplicamos angle/ox/oy de rampa (WallField tilt).
    attr_accessor :hd25_tilting
    # Agua / surf: no aplicar WALL_*_SEAL (alpha apilada = rayas en limites).
    attr_accessor :hd25_skip_wall_seal
    # El grafico de este tile es can_surf (aunque la casilla sea acantilado).
    # Si aparece en una fila, esa fila entera va en un solo trapecio.
    attr_accessor :hd25_surf_graphic
    # Casilla :InteriorWall: en 2.5D no levantar pri (el borde top no es pared
    # frontal). La cara la pinta InteriorWallLayer.
    attr_accessor :hd25_interior_flat
    # Tile con tag 21 (esta capa, no la casilla entera): tapa tumbada.
    # hd25_shelf_own_pri = prioridad pintada = cota (base de esa altura).
    attr_accessor :hd25_shelf_flat
    attr_accessor :hd25_shelf_height
    attr_accessor :hd25_shelf_own_pri
    # project_tile_z ya escribio Z con Z_LIFT: el setter no debe volver a sumar.
    attr_accessor :hd25_z_pre_raised
    # Cache de proyeccion del pool extended (MS aplasta x/y cada frame).
    attr_accessor :hd25_ext_px
    attr_accessor :hd25_ext_py
    attr_accessor :hd25_ext_pzx
    attr_accessor :hd25_ext_pzy
    attr_accessor :hd25_ext_pz
    # Cache geom vertical para scroll X (Y/scale/seal no cambian si stamp igual).
    attr_accessor :hd25_proj_stamp
    attr_accessor :hd25_proj_row
    attr_accessor :hd25_proj_scale
    attr_accessor :hd25_proj_y
    attr_accessor :hd25_proj_zy
    attr_accessor :hd25_proj_side
    attr_accessor :hd25_proj_wpx
    # Franjas de suelo (GROUND_SLICES). El hijo se crea la primera vez que
    # ese tile se parte, no en cada casilla.
    attr_accessor :hd25_slices
    attr_accessor :hd25_slice_n
    attr_accessor :hd25_src_h
    # true = el grafico aplana la fila (agua / alpha). nil = aun no mirado.
    attr_accessor :hd25_forces_flat
    # Fila de rejilla y X plana de las franjas ya creadas.
    attr_accessor :hd25_slice_row
    attr_accessor :hd25_grid_left
    attr_accessor :hd25_slice_cx
    attr_accessor :hd25_slice_cy
    # Fuera de la pantalla proyectada: no se mueve hasta que vuelva a verse.
    attr_accessor :hd25_culled
    # Capa del tilemap (0..2). La fila compuesta la necesita y el scroll
    # no vuelve a pasar el índice.
    attr_accessor :hd25_layer
    attr_accessor :hd25_row_batched
    attr_accessor :hd25_batch_key
    attr_accessor :hd25_batch_flat
    attr_accessor :hd25_batch_row

    alias hd25_set_bitmap set_bitmap unless method_defined?(:hd25_set_bitmap)
    # set_bitmap devuelve el zoom a su valor original, asi que hay que invalidar
    # la cache para volver a aplicarlo.
    def set_bitmap(*args)
      Visual25D.release_ground_row_member(self) if @hd25_row_batched
      hd25_set_bitmap(*args)
      @hd25_zoom_x = nil
      @hd25_zoom_y = nil
      @hd25_base_zoom_x = nil
      @hd25_base_zoom_y = nil
      @hd25_proj_stamp = nil
      @hd25_taper = nil
      if @hd25_slices
        @hd25_slices.each do |spr|
          next if !spr || spr.disposed?
          spr.visible = false if spr.visible
          spr.bitmap = nil if spr.bitmap
        end
      end
      @hd25_slice_n = nil
      @hd25_src_h = nil
      @hd25_forces_flat = nil
      @hd25_culled = false
      @hd25_slice_row = nil
      @hd25_grid_left = nil
      @hd25_slice_cx = nil
      @hd25_slice_cy = nil
      @hd25_row_batched = false
      @hd25_batch_key = nil
      @hd25_batch_flat = nil
      @hd25_batch_row = nil
      Visual25D.forget_sliced_tile(self)
    end

    # Se recoge en la propia asignacion y no en refresh_tile_z porque otros
    # plugins de mapas (MakerStudio) reescriben esa Z por encima de la del plugin.
    def z=(value)
      if @hd25_z_pre_raised
        @hd25_z_pre_raised = false
      elsif Visual25D.enabled? && Visual25D.raised_tile?(self)
        value = Visual25D.raised_tile_z(value)
      end
      super(value)
    end
  end

  alias hd25_initialize initialize unless method_defined?(:hd25_initialize)
  def initialize(viewport)
    hd25_initialize(viewport)
    @hd25_base_columns = @tiles_horizontal_count
    @hd25_base_rows = @tiles_vertical_count
    hd25_sync_grid
  end

  # La rejilla crece o mengua con la camara, para no arrastrar tiles de mas
  # cuando esta cerca ni quedarse corto cuando se aleja o se inclina.
  def hd25_sync_grid
    if Visual25D.enabled?
      columns = @hd25_base_columns + (Visual25D.margin_columns * 2)
      rows = @hd25_base_rows + (Visual25D.margin_rows * 2)
    else
      columns = @hd25_base_columns
      rows = @hd25_base_rows
    end
    return if columns == @tiles_horizontal_count && rows == @tiles_vertical_count
    old_c = @tiles_horizontal_count
    old_r = @tiles_vertical_count
    growing = columns >= old_c && rows >= old_r && (columns > old_c || rows > old_r)
    @tiles.pop.each { |cell| cell.each { |tile| tile.dispose } } while @tiles.length > columns
    @tiles.each do |column|
      column.pop.each { |tile| tile.dispose } while column.length > rows
      column.push(Array.new(3) { TileSprite.new(@viewport) }) while column.length < rows
    end
    while @tiles.length < columns
      @tiles.push(Array.new(rows) { Array.new(3) { TileSprite.new(@viewport) } })
    end
    @tiles_horizontal_count = columns
    @tiles_vertical_count = rows
    # Al crecer (fundido 2D→2.5D): solo casillas nuevas need_refresh.
    # Full refresh en todo el mapa = un frame sin gráficos MS / paredes.
    if growing
      (old_c...columns).each do |i|
        @tiles[i].each { |coord| coord.each { |tile| tile.need_refresh = true } }
      end
      @tiles.each do |column|
        next if column.length <= old_r
        (old_r...column.length).each do |j|
          column[j].each { |tile| tile.need_refresh = true }
        end
      end
    else
      @need_refresh = true
    end
    # El pool de capas extendidas de MakerStudio se dimensiona con estos mismos
    # contadores pero solo se construye una vez: sin esto, al agrandar la rejilla
    # recorre columnas que aun no existen y revienta.
    @ext_pool_ready = false if defined?(MakerStudio)
  end

  # Se envuelve la actualizacion del motor y no la de otros plugins, para que el
  # corrimiento del encuadre solo afecte a la rejilla de tiles nativa.
  hd25_engine_update = method_defined?(:__mkst__update) ? :__mkst__update : :update
  alias_method :hd25_update, hd25_engine_update unless method_defined?(:hd25_update)
  define_method(hd25_engine_update) do
    if @hd25_in_update
      return
    end
    @hd25_in_update = true
    hd25_sync_grid
    begin
      Visual25D.shift_maps_for_render
      # Offsets con display ya corrido (nativos). Dirty-cache en Core.
      Visual25D.prime_map_offsets! if Visual25D.enabled?
      hd25_update
      Visual25D.flush_ground_rows!(self)
    ensure
      # Dentro del ensure: si se corta entre correr el encuadre y restaurarlo, los
      # mapas se quedan desplazados para siempre y todo se dibuja movido.
      Visual25D.restore_maps_after_render
      Visual25D.perf_frame_end(self)
      @hd25_in_update = false
    end
  end

  # Tanto la posicion como la Z de un tile se miden como "fila de la rejilla por
  # 32, menos @pixel_offset". Sumandole el margen a esos dos offsets en cuanto el
  # motor los recalcula, la ampliacion de la rejilla queda absorbida ahi y deja
  # de existir para todo lo demas: ni el motor ni otro plugin que reescriba la
  # posicion o la Z de un tile (MakerStudio lo hace) necesitan saber de ella.
  alias hd25_check_if_screen_moved check_if_screen_moved unless method_defined?(:hd25_check_if_screen_moved)
  def check_if_screen_moved
    # El motor compara los offsets con los del frame anterior para saber si la
    # pantalla se ha movido, asi que se le devuelven limpios de margen.
    @pixel_offset_x -= @hd25_margin_offset_x if @hd25_margin_offset_x
    @pixel_offset_y -= @hd25_margin_offset_y if @hd25_margin_offset_y
    ret = hd25_check_if_screen_moved
    @hd25_margin_offset_x = Visual25D.margin_offset_x
    @hd25_margin_offset_y = Visual25D.margin_offset_y
    @pixel_offset_x += @hd25_margin_offset_x
    @pixel_offset_y += @hd25_margin_offset_y
    # Fundido 2.5D: sin scroll igual hay que reproyectar cada frame.
    if Visual25D.take_force_reproject!
      @screen_moved = true
      @screen_moved_vertically = true
      ret = true
    end
    # Carrera N: si el resto % 32 no cambia (salto de casilla exacto) vanilla
    # no marca vertical y los pri>0 reusan Y del frame anterior.
    dy = $game_map ? $game_map.display_y : nil
    if !@hd25_last_map_dy.nil? && dy && dy != @hd25_last_map_dy
      @screen_moved = true
      @screen_moved_vertically = true
    end
    @hd25_last_map_dy = dy
    # Una tabla de filas por update (tras pixel_offset final), no por tile.
    if Visual25D.enabled?
      Visual25D.update_projection(@pixel_offset_y)
      # Personajes rellenan col_stack con el stamp de sync; al early-out
      # nativo se reutiliza y el unit N/S sale de otra fila → smear al correr.
      if @screen_moved_vertically
        Visual25D.clear_column_stack_cache!
      end
    end
    return ret
  end

  alias hd25_refresh_tile_coordinates refresh_tile_coordinates unless method_defined?(:hd25_refresh_tile_coordinates)
  def refresh_tile_coordinates(tile, x, y)
    # Siempre coords planas del motor → proyectar. El atajo
    # tile.x -= dox*scale acumulaba redondeo por fila → franja negra dentada.
    hd25_refresh_tile_coordinates(tile, x, y)
    # Capa vacia: motor ya puso x/y planos; nada que proyectar.
    if Visual25D.tile_blank?(tile)
      Visual25D.perf_tick(:blank)
      return
    end
    # MS suma ox/oy con el zoom proyectado del frame anterior. Al correr N/S
    # zoom_y salta mucho: deshacer con ese zoom deja el origen sucio y los
    # pri>0 se arrastran. Siempre origen de rejilla, proyectar, reaplicar ox.
    has_o = Visual25D::MS_ORIGIN_FIX && (tile.ox != 0 || tile.oy != 0)
    tile.x = (x * DISPLAY_TILE_WIDTH) - @pixel_offset_x
    tile.y = (y * DISPLAY_TILE_HEIGHT) - @pixel_offset_y
    if !Visual25D.enabled?
      Visual25D.clear_tile_depth(tile)
      Visual25D.restore_tile_z_2d(tile, y, @pixel_offset_y)
      if has_o
        tile.x += (tile.ox * tile.zoom_x.abs).round
        tile.y += (tile.oy * tile.zoom_y.abs).round
      end
      return
    end
    Visual25D.sync_tile_wall_cell(tile, x, y)
    if Visual25D.defer_tile_project?
      # Origen plano. No reaplicar ox con zoom del sprite reciclado (al
      # correr N el del primer plano se va al horizonte y smearea).
      Visual25D.invalidate_tile_zoom!(tile)
      return
    end
    # Fuera de pantalla: ocultar una vez. Al volver, project_tile entero.
    cull = Visual25D.screen_cull_tile(tile, y, tile.x)
    if cull == :off
      Visual25D.release_ground_row_member(tile)
      return
    end
    # Suelo llano de esta fila: un trapecio compartido. No se proyecta el tile.
    if Visual25D.offer_ground_row!(tile, y, tile.x)
      return
    end
    # Scroll X: cache Y/scale. N/S pri0: y_flat con X de rejilla. Raised: full.
    # No se invalida el zoom aqui: y_flat compara el zoom vivo del sprite.
    # Invalidarlo obligaba a reescribir zoom en cada tile, cada frame N/S.
    # :full tira el atajo: la Y cacheada es de cuando estaba fuera.
    if cull == :full || Visual25D.skip_coords_z?
      Visual25D.project_tile(tile, y)
    elsif @screen_moved_vertically
      if Visual25D.tile_can_yflat?(tile)
        Visual25D.project_tile_scroll_y_flat(tile, y)
      else
        Visual25D.project_tile(tile, y)
      end
    else
      Visual25D.project_tile_scroll_x(tile, y)
    end
    unless Visual25D.skip_coords_z? || @screen_moved_vertically
      if Visual25D.tile_maybe_raised?(tile) ||
         (tile.z && tile.z >= Visual25D::Z_LIFT)
        Visual25D.project_tile_z_selective(tile, y, 0, @pixel_offset_y)
      end
    end
    if has_o
      tile.x += (tile.ox * tile.zoom_x.abs).round
      tile.y += (tile.oy * tile.zoom_y.abs).round
    end
  end

  # La casilla del mapa que muestra un tile solo cambia cuando el motor lo vuelve
  # a enlazar, asi que se resuelve aqui y no en cada frame. Se hace antes de la
  # llamada original porque dentro de ella ya se colocan la posicion y la Z, que
  # son las que la necesitan.
  alias hd25_refresh_tile_frame refresh_tile_frame unless method_defined?(:hd25_refresh_tile_frame)
  def refresh_tile_frame(tile, tile_id)
    hd25_refresh_tile_frame(tile, tile_id)
    # El autotile quieto no pasa por project_tile. Sin esto la franja de
    # abajo se queda en el frame anterior.
    # Quieto, el autotile no pasa por project. Si este frame es transparente
    # hay que quitar las franjas aqui, si no se quedan superpuestas.
    Visual25D.touch_ground_row_frame(tile) if tile.hd25_row_batched
    Visual25D.sync_ground_slice_frame(tile) if tile.hd25_slice_n.to_i > 1
  end

  alias hd25_refresh_tile refresh_tile unless method_defined?(:hd25_refresh_tile)
  def refresh_tile(tile, x, y, map, layer, tile_id)
    tile.hd25_layer = layer
    # Casilla nueva: tirar geom vieja del sprite reciclado.
    tile.hd25_geom_priority = nil if tile.respond_to?(:hd25_geom_priority=)
    tile.hd25_painted_priority = nil if tile.respond_to?(:hd25_painted_priority=)
    Visual25D.bind_tile_walls(tile, map, x, y, tile_id)
    # Engine: coords luego Z. Evita project_tile_z duplicado en coords.
    Visual25D.skip_coords_z = true
    begin
      hd25_refresh_tile(tile, x, y, map, layer, tile_id)
    ensure
      Visual25D.skip_coords_z = false
    end
  end

  alias hd25_refresh_tile_z refresh_tile_z unless method_defined?(:hd25_refresh_tile_z)
  def refresh_tile_z(tile, map, y, layer, tile_id)
    # Oculto fuera de pantalla: la Z no se ve. Al entrar, coordinates ya
    # limpio hd25_culled y este metodo corre despues en el mismo frame.
    if Visual25D.enabled? && (tile.hd25_culled || tile.hd25_row_batched)
      return
    end
    # Siempre MS/motor primero: atajar solo project_tile_z en raised dejaba
    # tiles un frame con Z/banda vieja → “desaparecen” hasta el siguiente rebind.
    hd25_refresh_tile_z(tile, map, y, layer, tile_id)
    if !Visual25D.enabled?
      # Motor/MS ya puso Z; si quedara residuo 2.5D, reafirmar espacio 2D.
      Visual25D.restore_tile_z_2d(tile, y, @pixel_offset_y)
      return
    end
    # defer: Bridge proyecta Z tras assign_geom_priority.
    return if Visual25D.defer_tile_project?
    return if Visual25D.tile_blank?(tile)
    # Shelf / InteriorWall: el motor/MS acaba de escribir Z 2D. Reponer
    # la Z de tapa (si no, tile_maybe_raised? es false y demote tumba el techo
    # y el personaje pasa por encima).
    if Visual25D.flat_cap?(tile) && Visual25D.enabled?
      Visual25D.apply_flat_cap_z(tile, y, @pixel_offset_y)
      return
    end
    # Motor ya escribio Z 2D de suelo. Solo raised necesitan formula 2.5D.
    if !Visual25D.tile_maybe_raised?(tile)
      Visual25D.demote_stale_ground_z(tile)
      return
    end
    Visual25D.perf_tick(:z_raised)
    Visual25D.project_tile_z(tile, y, layer, @pixel_offset_y)
  end
end

module Visual25D
  # Constante de carga: MakerStudio ya esta cargado (meta Last).
  MS_ORIGIN_FIX = defined?(MakerStudio) && MakerStudio::ENABLED
  # Lift unprojected: tiles * esta constante (evita mul por frame en aristas).
  WALL_LIFT_PX = TilemapRenderer::DISPLAY_TILE_HEIGHT * Config::WALL_STEP_RATIO
  # Suelo plano: solape de franja (1) + sello (2).
  CULL_PAD = 4
  # Columna / Cliff: el sobrevuelo medido cabe aqui; no recorta un pri alto
  # que asoma por el borde.
  CULL_PAD_TALL = 96

  # Franja de suelo. Accesores en vez de instance_variable_get en el scroll.
  class GroundStrip < ::Sprite
    attr_accessor :hd25_taper
    attr_accessor :hd25_near
    attr_accessor :hd25_zy
    attr_accessor :hd25_wpx
    attr_accessor :hd25_zx
    attr_accessor :hd25_zy_applied
  end

  class << self
    # Z en espacio PLANO (misma cuenta que Game_Character#screen_z y
    # ms_overhead_tile_z). Nunca wall_column_anchor_y: eso es Y ya proyectada;
    # con WallField activo la perspectiva comprime esa Y y el jugador gana
    # siempre a los tiles con prioridad (nunca pasa detras de arboles/muros).
    # Z con prioridad PINTADA (geom), no cell_band. Bajo el ground-cap MS
    # band=0 pero el arbol sigue en pri 1..5 y debe tapar al jugador.
    # Scroll X / refresh_tile_z: fix v3.0.11 acotado.
    # Raised siempre; suelo solo si arrastra Z_LIFT (sprite reciclado).
    def project_tile_z_selective(tile, row, layer, pixel_offset_y)
      if tile_blank?(tile)
        perf_tick(:blank)
        return
      end
      perf_tick(:z)
      if tile.shows_reflection || tile.bridge
        demote_stale_ground_z(tile)
        return
      end
      # Tapa plana: misma Z que un tile pri N (el personaje queda detras).
      if flat_cap?(tile) && Visual25D.enabled?
        apply_flat_cap_z(tile, row, pixel_offset_y)
        return
      end
      # Gate barato: sin geom_priority completa en el caso comun (suelo sano).
      pri = tile.hd25_geom_priority
      painted = tile.hd25_painted_priority
      if (pri.nil? || pri.to_i <= 0) &&
         (painted.nil? || painted.to_i <= 0) &&
         tile.priority.to_i <= 0
        demote_stale_ground_z(tile)
        return
      end
      perf_tick(:z_raised)
      project_tile_z(tile, row, layer, pixel_offset_y)
    end

    def tile_blank?(tile)
      return true if !tile
      # TileSprite siempre tiene disposed?; evitar respond_to? en hot path.
      return true if tile.disposed?
      return true if !tile.bitmap
      return false
    end

    # Gate barato (sin geom_priority completa).
    def tile_maybe_raised?(tile)
      return false if !tile || tile.shows_reflection || tile.bridge
      return false if flat_cap?(tile) && Visual25D.enabled?
      pri = tile.hd25_geom_priority
      return true if pri && pri.to_i > 0
      painted = tile.hd25_painted_priority
      return true if painted && painted.to_i > 0
      return tile.priority.to_i > 0
    end

    # pri0 sin lift real en ESTA casilla → yFlat aunque el mapa tenga Cliff.
    # No usa wall_geom: el suavizado marca demasiadas celdas y mataba yFlat.
    def tile_can_yflat?(tile)
      return false if tile_maybe_raised?(tile)
      # Shelf / InteriorWall: no son pri>0, pero no son suelo de su fila.
      return false if flat_cap?(tile) && Visual25D.enabled?
      field = tile.hd25_walls
      return true if !field
      cx = tile.hd25_cell_x
      cy = tile.hd25_cell_y
      return false if cx.nil? || cy.nil?
      return false if field.lifted?(cx, cy)
      return false if field.lateral_step?(cx, cy)
      return true
    end

    # :off = no proyectar (sigue fuera). :full = acaba de entrar, project_tile.
    # nil = en pantalla, camino normal.
    def screen_cull_tile(tile, row, left)
      return nil if row.nil? || left.nil? || !@row_top
      off = tile_offscreen?(tile, row, left)
      if tile.hd25_culled
        if off
          # Un rebuild de MakerStudio puede haber vuelto a mostrar el sprite.
          hide_culled_tile!(tile) if tile.visible
          perf_tick(:cull)
          return :off
        end
        show_culled_tile!(tile)
        return :full
      end
      return nil if !off
      note_flat_row_before_cull!(tile, row)
      hide_culled_tile!(tile)
      perf_tick(:cull)
      return :off
    end

    def cull_is_tall?(tile)
      return true if tile_maybe_raised?(tile)
      return true if flat_cap?(tile)
      return false
    end

    # Prioridad para saber si una fila de arriba aun asoma por los pies.
    # InteriorWall usa el tope: son pocas y own_priority escanea el mapa.
    def cull_priority(tile)
      if tile.hd25_shelf_flat
        h = tile.hd25_shelf_own_pri.to_i
        extra = tile.hd25_shelf_height.to_i
        h = extra if extra > h
        return 1 if h < 1
        return h
      end
      return Config::MAX_PRIORITY if tile.hd25_interior_flat
      pri = tile.hd25_geom_priority
      pri = tile.hd25_painted_priority if pri.nil?
      pri = tile.priority if pri.nil?
      pri = pri.to_i
      cap = Config::MAX_PRIORITY
      pri = cap if cap && pri > cap
      return pri
    end

    def tile_offscreen?(tile, row, left)
      return false if !row_covered?(row)
      top = row_top(row)
      bot = row_top(row + 1)
      return false if !top || !bot
      gh = Graphics.height
      # Debajo: la cima asoma un poco por encima de la fila del tile (los pies
      # estan al sur). Con el pad alto no se recorta un pri que aun se ve.
      return true if top > gh + CULL_PAD_TALL
      tall = cull_is_tall?(tile)
      if bot < -CULL_PAD_TALL
        if !tall
          return true
        end
        pri = cull_priority(tile)
        pri = 1 if pri < 1
        feet_row = row + pri
        feet = row_covered?(feet_row) ? row_top(feet_row) : row_top_any(feet_row)
        return true if feet < -CULL_PAD_TALL
      elsif bot < -CULL_PAD && !tall && !tile.hd25_walls
        return true
      end
      pad = (!tall && !tile.hd25_walls) ? CULL_PAD : CULL_PAD_TALL
      return horizontal_offscreen?(row, left, pad)
    end

    def horizontal_offscreen?(row, left, pad)
      scale = row_width_scale(row + 1)
      scale = row_width_scale(row) if !scale || scale <= 0
      return false if !scale || scale <= 0
      dw = TilemapRenderer::DISPLAY_TILE_WIDTH
      start = project_x(left, scale)
      finish = project_x(left + dw, scale)
      return finish < -pad || start > Graphics.width + pad
    end

    # Un agua fuera de pantalla tiene que aplanar su fila igual: si no, el
    # vecino que si se ve se parte y la junta abre una raya negra al entrar.
    def note_flat_row_before_cull!(tile, row)
      return if cull_is_tall?(tile)
      return if map_row_flat?(tile)
      if tile.hd25_forces_flat.nil?
        return if !tile_forces_flat_row?(tile)
      elsif !tile.hd25_forces_flat
        return
      end
      mark_map_row_flat!(tile)
      flatten_ground_row!(row, tile)
    end

    def hide_culled_tile!(tile)
      tile.hd25_culled = true
      tile.hd25_proj_stamp = nil
      tile.visible = false if tile.visible
      slices = tile.hd25_slices
      return if !slices
      i = 0
      while i < slices.length
        spr = slices[i]
        spr.visible = false if spr && !spr.disposed? && spr.visible
        i += 1
      end
    end

    def show_culled_tile!(tile)
      tile.hd25_culled = false
      tile.hd25_proj_stamp = nil
      invalidate_tile_zoom!(tile)
      if tile.bitmap && !tile.disposed?
        tile.visible = true if !tile.visible
      end
      return if tile.hd25_slice_n.to_i <= 1
      slices = tile.hd25_slices
      return if !slices
      n = tile.hd25_slice_n.to_i
      i = 0
      while i < n - 1
        spr = slices[i]
        if spr && !spr.disposed? && spr.bitmap
          spr.visible = true if !spr.visible
        end
        i += 1
      end
    end

    # Evita escribir zoom al sprite si el cambio es sub-pixel (MKXP caro).
    ZOOM_EPS = 0.002
    ZOOM_QUANT = 256.0

    # Sprite#taper existe solo en el mkxp-z propio. Con un binario estandar la
    # constante queda en false y todo se comporta como antes: suelo aproximado
    # con zoom uniforme, que es lo que habia hasta ahora.
    TAPER_SUPPORTED = Sprite.method_defined?(:taper=)

    def quant_zoom(value)
      return (value * ZOOM_QUANT).round / ZOOM_QUANT
    end

    # Scroll vertical pri0 sin WallField: solo tabla + project_x inline.
    # Probe: full/f~1600 en N/S era el cuello; esto evita geom/walls/ensure.
    def project_tile_scroll_y_flat(tile, row)
      tops = @row_top
      widths = @row_width
      tapers = @row_taper
      if !tops || !widths
        project_tile(tile, row)
        return
      end
      perf_tick(:yflat)
      rmax = @row_max || 0
      row = 0 if row < 0
      row = rmax if row > rmax
      if ground_slice_count > 1 && place_ground_strips(tile, row, tile.x)
        return
      end
      scale = widths[row]
      top = tops[row]
      bottom = (row < rmax) ? tops[row + 1] : (top + 1)
      height = bottom - top
      height = 1 if height < 1
      # Mismo trapecio que project_tile: ancho de la fila de delante abajo,
      # estrechando hasta el de esta. Sin esto el camino corto de scroll
      # vertical volveria a dejar el escalon que el largo ya no deja.
      taper = 1.0
      if TAPER_SUPPORTED && tapers && row < rmax
        near = widths[row + 1]
        if near && near > 0
          taper = tapers[row] || 1.0
          scale = near
        end
      end
      apply_tile_taper(tile, taper)
      cx = @proj_center_x || (Graphics.width / 2)
      left = tile.x
      dw = TilemapRenderer::DISPLAY_TILE_WIDTH
      sw = TilemapRenderer::SOURCE_TILE_WIDTH.to_f
      sh = TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
      start = cx + ((left - cx) * scale).round
      finish = cx + ((left + dw - cx) * scale).round
      wpx = finish - start
      zoom_y = quant_zoom(height / sh)
      zoom_x = quant_zoom(wpx / sw)
      if tile.hd25_base_zoom_x
        zoom_x = quant_zoom(zoom_x * tile.hd25_base_zoom_x / TilemapRenderer::ZOOM_X.to_f)
        zoom_y = quant_zoom(zoom_y * tile.hd25_base_zoom_y / TilemapRenderer::ZOOM_Y.to_f)
      end
      tile.x = start
      tile.y = top
      if !tile.hd25_zoom_x || (tile.hd25_zoom_x - zoom_x).abs > ZOOM_EPS ||
         (tile.zoom_x - zoom_x).abs > ZOOM_EPS
        tile.zoom_x = zoom_x
        tile.hd25_zoom_x = zoom_x
      end
      if !tile.hd25_zoom_y || (tile.hd25_zoom_y - zoom_y).abs > ZOOM_EPS ||
         (tile.zoom_y - zoom_y).abs > ZOOM_EPS
        tile.zoom_y = zoom_y
        tile.hd25_zoom_y = zoom_y
      end
      tile.hd25_proj_stamp = @projection_stamp || 0
      tile.hd25_proj_row = row
      tile.hd25_proj_scale = scale
      tile.hd25_proj_y = top
      tile.hd25_proj_zy = height / sh
      tile.hd25_proj_side = 0
      tile.hd25_proj_wpx = wpx
    end

    # Scroll horizontal: reusa Y/scale/seal del ultimo project_tile (mismo stamp).
    def project_tile_scroll_x(tile, row)
      return if tile_blank?(tile)
      stamp = @projection_stamp || 0
      if tile.hd25_proj_stamp == stamp && tile.hd25_proj_row == row && tile.hd25_proj_scale
        perf_tick(:xhit)
        scale = tile.hd25_proj_scale
        side = tile.hd25_proj_side || 0
        left = tile.x
        start = project_x(left, scale)
        finish = project_x(left + TilemapRenderer::DISPLAY_TILE_WIDTH, scale)
        if side > 0
          start -= side
          finish += side
        end
        wpx = finish - start
        tile.x = start
        tile.y = tile.hd25_proj_y
        # En E/O el zoom casi no cambia: solo reescribir si el ancho en px cambia.
        if tile.hd25_proj_wpx != wpx
          tile.hd25_proj_wpx = wpx
          apply_tile_zoom(tile, wpx / TilemapRenderer::SOURCE_TILE_WIDTH.to_f, tile.hd25_proj_zy)
        end
        if tile.hd25_slice_n.to_i > 1
          # Sprite viejo (antes de GroundStrip, p.ej. tras F12): rehacer
          # desde la X plana, no desde la ya proyectada.
          unless reposition_ground_slices_x(tile, left)
            tile.x = left
            project_tile(tile, row)
          end
          # La X de rejilla cambia al andar E/O. Sin esto, aplanar la fila
          # despues recoloca el tile con la X del ultimo project completo.
          tile.hd25_grid_left = left
        end
        return
      end
      perf_tick(:xmiss)
      project_tile(tile, row)
    end

    def project_tile_z(tile, row, layer, pixel_offset_y)
      # Una sola geom_priority: raised_tile? la repetia justo debajo.
      priority = geom_priority(tile)
      if tile.shows_reflection || tile.bridge || priority <= 0
        # Sprite reciclado raised→suelo: sin refresh_tile_z (scroll X) se queda
        # Z_LIFT y puede tapar a los pri>=1 que aun tienen Z de suelo.
        demote_stale_ground_z(tile)
        return
      end
      priority = 1 if priority < 1
      priority = Config::MAX_PRIORITY if priority > Config::MAX_PRIORITY
      ground = ((row + priority + 1) * TilemapRenderer::DISPLAY_TILE_HEIGHT) - pixel_offset_y
      # Misma columna (fila+pri) empata: X+1 tiene que ganar la junta a X,
      # si no el sprite de abajo se pinta despues y recorta el de encima.
      z = ground + 1 + priority
      z += tile.ext_z_offset if tile.respond_to?(:ext_z_offset) && tile.ext_z_offset
      # Z ya con lift: evita raised_tile?/geom_priority otra vez en z=.
      tile.hd25_z_pre_raised = true
      tile.z = raised_tile_z(z)
    end

    def demote_stale_ground_z(tile)
      return if tile.shows_reflection
      return if tile.bridge && $PokemonGlobal && $PokemonGlobal.bridge > 0
      return if flat_cap?(tile) && Visual25D.enabled?
      return if !tile.z || tile.z < Z_LIFT
      z = 0
      if tile.respond_to?(:cell_band) && !tile.cell_band.nil? && tile.cell_band.to_i == 0
        z = tile.ms_ground_z || 0 if tile.respond_to?(:ms_ground_z)
      end
      z += tile.ext_z_offset if tile.respond_to?(:ext_z_offset) && tile.ext_z_offset
      tile.hd25_z_pre_raised = false
      tile.z = z
    end

    # Prioridad pintada para geometria / Z de columna. Nunca cell_band.
    # ponytail: hd25_* son attr en TileSprite; sin respond_to? en hot path.
    def geom_priority(tile)
      # Tapa plana (InteriorWall/Shelf): el pri del borde NO debe hacerse
      # columna frontal.
      return 0 if flat_cap?(tile) && Visual25D.enabled?
      priority = tile.hd25_geom_priority
      painted = tile.hd25_painted_priority
      priority = painted if priority.nil?
      priority = tile.priority if priority.nil?
      priority = priority.to_i
      # Painted / priority del sprite pueden ser mas altos que un geom cacheado a 0
      # (resolve MS bajo el cap). Sin esto raised_tile? falla y Z queda de suelo.
      if !painted.nil? && painted.to_i > priority
        priority = painted.to_i
      end
      tp = tile.priority.to_i
      priority = tp if tp > priority
      priority = Config::MAX_PRIORITY if priority > Config::MAX_PRIORITY
      return priority
    end

    def geom_raised?(tile)
      return false if tile.shows_reflection || tile.bridge
      return geom_priority(tile) > 0
    end

    # Altura de banda para Z: prioridad pintada (geom). cell_band solo si es mayor.
    def raise_priority(tile)
      priority = geom_priority(tile)
      if tile.respond_to?(:cell_band)
        band = tile.cell_band
        if !band.nil?
          band = band.to_i
          priority = band if band > priority
        end
      end
      priority = Config::MAX_PRIORITY if priority > Config::MAX_PRIORITY
      priority = 1 if priority < 1
      return priority
    end

    # Anota prioridad geometrica. own_pri nil → tile.priority.
    def assign_geom_priority(tile, own_pri = nil)
      pri = own_pri.nil? ? tile.priority.to_i : own_pri.to_i
      pri = 0 if pri < 0
      pri = Config::MAX_PRIORITY if pri > Config::MAX_PRIORITY
      tile.hd25_geom_priority = pri
    end

    # Deja anotada en el sprite la casilla del mapa que muestra, para que la
    # proyeccion pueda saber si es una pared. Solo en refresh_tile (rebind).
    def bind_tile_walls(tile, map, x, y, tile_id = nil)
      tile.hd25_proj_stamp = nil
      # Reciclo N: el sprite del primer plano (zoom_y grande) pasa al
      # horizonte. Cortar el zoom antes de proyectar o se arrastra un frame.
      bx = tile.hd25_base_zoom_x || TilemapRenderer::ZOOM_X
      by = tile.hd25_base_zoom_y || TilemapRenderer::ZOOM_Y
      tile.zoom_x = bx if tile.zoom_x != bx
      tile.zoom_y = by if tile.zoom_y != by
      invalidate_tile_zoom!(tile)
      tile.hd25_map_id = map.map_id
      # No asignar geom aqui: tile.priority aun es del sprite reciclado.
      # refresh_tile_bitmap / MS lo escriben despues; geom_priority cae a eso.
      # Siempre anotar casilla: al activar 2.5D en un mapa entrado en 2D hace
      # falta cx/cy aunque el WallField sea flat (pri>0 usa cy+priority).
      offset = map_tile_offset(map)
      tile.hd25_cell_x = x + offset[0]
      tile.hd25_cell_y = y + offset[1]
      annotate_interior_flat!(tile, map)
      annotate_shelf_flat!(tile, map, tile_id)
      field = wall_field(map)
      if !field || field.flat
        tile.hd25_walls = nil
        tile.hd25_lifted = false
        annotate_wall_seal_skip!(tile, map)
        annotate_surf_graphic!(tile, map, tile_id)
        return
      end
      tile.hd25_walls = field
      tile.hd25_lifted = field.lifted?(tile.hd25_cell_x, tile.hd25_cell_y)
      annotate_wall_seal_skip!(tile, map)
      annotate_surf_graphic!(tile, map, tile_id)
    end

    # :InteriorWall = tapa/borde. En 2.5D: geom flat (no columna pri5) pero
    # VISIBLE como tapa arriba del muro. Cara lateral = InteriorWallLayer.
    def annotate_interior_flat!(tile, map)
      tile.hd25_interior_flat = false
      return if !Config::INTERIOR_WALLS || !map
      cx = tile.hd25_cell_x
      cy = tile.hd25_cell_y
      return if cx.nil? || cy.nil?
      return if cx < 0 || cy < 0 || cx >= map.width || cy >= map.height
      tag = map.terrain_tag(cx, cy, true)
      return if !tag || tag.id != Config::INTERIOR_WALL_TAG
      tile.hd25_interior_flat = true
      tile.hd25_painted_priority = 0
      assign_geom_priority(tile, 0)
    end

    # Tag :Shelf = tapa tumbada. El 21 solo marca "plano" y solo ESA capa.
    # Prioridad P = base de esa altura (donde iria el canto bajo del tile
    # vertical). P=1 → ras de suelo. P=5 → cierra con el vertical pri 4.
    SHELF_JOIN_OVERLAP = 1

    def terrain_tag_of_tile(map, tile_id, tile_data = nil)
      if tile_data
        tt = tile_data["terrain_tag"]
        if tt && tt.to_i != 0
          return GameData::TerrainTag.try_get(tt.to_i)
        end
        if tile_data["tileset_id"]
          ts = $data_tilesets[tile_data["tileset_id"].to_i]
          tid = (tile_data["tile_id"] || tile_id).to_i
          if ts && tid > 0
            return GameData::TerrainTag.try_get(ts.terrain_tags[tid] || 0)
          end
        end
      end
      tid = tile_id.to_i
      return nil if tid <= 0 || !map || !map.terrain_tags
      return GameData::TerrainTag.try_get(map.terrain_tags[tid] || 0)
    end

    def tile_is_shelf?(map, tile_id, tile_data = nil)
      return false if !Config::SHELF_ENABLED || !map
      tag = terrain_tag_of_tile(map, tile_id, tile_data)
      return tag && tag.id == Config::SHELF_TAG
    end

    def cell_is_shelf?(map, cx, cy)
      return false if !map || cx.nil? || cy.nil?
      return false if cx < 0 || cy < 0 || cx >= map.width || cy >= map.height
      tag = map.terrain_tag(cx, cy, true)
      return tag && tag.id == Config::SHELF_TAG
    end

    def shelf_priority_cap
      cap = Config::MAX_PRIORITY.to_i
      return cap > 0 ? cap : 12
    end

    # Prioridad de ESTA capa Shelf. Solo el dato de este tile_id / tile_data.
    # No se lee tile.priority ni la cota cacheada: al entrar en pantalla el
    # sprite es el de otro tile y esa prioridad (mas alta) aplastaba la tapa.
    def shelf_priority_for(map, tile_id, tile_data = nil)
      own = 0
      if tile_data && tile_data["priority"]
        own = tile_data["priority"].to_i
      end
      tid = tile_id.to_i
      if map&.priorities && tid > 0
        listed = (map.priorities[tid] || 0).to_i
        own = listed if listed > own
      end
      cap = shelf_priority_cap
      own = 1 if own < 1
      own = cap if own > cap
      return own
    end

    def shelf_own_height(_tile, _map, _cx, _cy, extra = 0)
      h = extra.to_i
      cap = shelf_priority_cap
      h = 1 if h < 1
      h = cap if h > cap
      return h
    end

    def shelf_height_for(tile, map, cx, cy, extra = 0)
      return shelf_own_height(tile, map, cx, cy, extra)
    end

    # Prioridad de la capa tag 21 en (cx,cy). 0 si no hay.
    def shelf_layer_priority(map, cx, cy)
      return 0 if !map || cx.nil? || cy.nil?
      return 0 if cx < 0 || cy < 0 || cx >= map.width || cy >= map.height
      best = 0
      data = map.data
      if data
        [0, 1, 2].each do |layer|
          tid = data[cx, cy, layer].to_i
          next if tid <= 0
          next if !tile_is_shelf?(map, tid)
          pri = (map.priorities[tid] || 0).to_i
          best = pri if pri > best
        end
      end
      if defined?(MakerStudio) && MakerStudio::ENABLED && map == $game_map
        MakerStudio.each_extended_tile_at(cx, cy) do |tid, td|
          next if !tile_is_shelf?(map, tid, td)
          pri = MakerStudio.resolve_band_priority(map, tid, td).to_i
          if td && td["priority"]
            baked = td["priority"].to_i
            pri = baked if baked > pri
          end
          best = pri if pri > best
        end
      end
      return best
    end

    def shelf_wall_field(map)
      return nil if !map || !respond_to?(:wall_field)
      field = wall_field(map)
      return nil if field && field.flat
      return field
    end

    # Canto sur de la tapa: base de altura P (canto bajo del vertical P).
    # P=1 → pies = arista sur de la casilla (ras de suelo).
    # Si la fila de apoyo cae fuera de la tabla (el tile entra por el borde),
    # row_top recorta a la ultima fila y la tapa queda en una linea.
    def shelf_plane_y(map, cx, cy, cell_row, p, field = nil)
      p = p.to_i
      p = 1 if p < 1
      field = shelf_wall_field(map) if field.nil?
      x_row = raised_width_row(cell_row, p)
      edge_row = cell_row.to_i + p
      if row_covered?(x_row) && row_covered?(edge_row)
        unit = row_unit(x_row)
        unit = vertical_unit_at(row_top(x_row + 1)) if !unit || unit <= 0
        feet = wall_column_feet_y(field, cx, cy, cell_row, p)
      else
        th = TilemapRenderer::DISPLAY_TILE_HEIGHT
        top_y = (x_row * th) - (@row_offset || 0)
        unit = vertical_unit_at(top_y + (th / 2))
        feet = shelf_feet_outside(field, cx, cy, cell_row, p)
      end
      return (feet - ((p - 1) * unit)).round
    end

    def shelf_feet_outside(field, cx, cy, cell_row, priority)
      edge_row = cell_row.to_i + priority.to_i
      return row_top_any(edge_row) if !field || field.flat || cx.nil? || cy.nil?
      edge_cy = cy.to_i + priority.to_i
      amount = field.lift(cx, edge_cy)
      return row_top_any(edge_row) if !amount || amount <= 0.0
      th = TilemapRenderer::DISPLAY_TILE_HEIGHT
      y = (edge_row * th) - (@row_offset || 0) - (amount * WALL_LIFT_PX)
      return project_y(y)
    end

    def shelf_column_info(map, cx, cy, cell_row = nil)
      none = { :lift => 0, :plane => 0, :h => 1 }
      return none if !map || cx.nil? || cy.nil?
      ensure_projection
      stamp = @projection_stamp || 0
      if @shelf_lift_stamp != stamp
        @shelf_lift_cache = {}
        @shelf_lift_stamp = stamp
      end
      @shelf_lift_cache ||= {}
      key = (map.map_id.to_i * 1_048_576) + (cx.to_i * 512) + cy.to_i
      return @shelf_lift_cache[key] if @shelf_lift_cache.key?(key)
      p = shelf_layer_priority(map, cx, cy)
      p = 1 if p < 1
      p = shelf_priority_cap if p > shelf_priority_cap
      cell_row = grid_row_for_map_cell(map, cy) if cell_row.nil?
      field = shelf_wall_field(map)
      plane = shelf_plane_y(map, cx, cy, cell_row, p, field)
      ground = wall_column_feet_y(field, cx, cy, cell_row, 1)
      lift = (p <= 1) ? 0 : (ground - plane)
      lift = 0 if lift < 0
      info = { :lift => lift, :plane => plane, :h => p }
      @shelf_lift_cache[key] = info
      return info
    end

    def shelf_plane_lift(map, cx, cy, cell_row = nil)
      return shelf_column_info(map, cx, cy, cell_row)[:lift]
    end

    # El 21 solo dibuja la tapa. No mueve al personaje: al cruzar en
    # horizontal se veia un sube-y-baja (L interpolado por casilla).
    def shelf_character_lift(character, ground = nil)
      return 0
    end

    def annotate_shelf_flat!(tile, map, tile_id = nil, tile_data = nil)
      tile.hd25_shelf_flat = false
      tile.hd25_shelf_own_pri = 0 if tile.respond_to?(:hd25_shelf_own_pri=)
      return if !Config::SHELF_ENABLED || !map
      cx = tile.hd25_cell_x
      cy = tile.hd25_cell_y
      return if cx.nil? || cy.nil?
      return if cx < 0 || cy < 0 || cx >= map.width || cy >= map.height
      tid = tile_id
      tid = tile.tile_id if (tid.nil? || tid.to_i <= 0) && tile.respond_to?(:tile_id)
      return if !tile_is_shelf?(map, tid, tile_data)
      tile.hd25_shelf_flat = true
      own = shelf_priority_for(map, tid, tile_data)
      tile.hd25_shelf_own_pri = own if tile.respond_to?(:hd25_shelf_own_pri=)
      tile.hd25_shelf_height = own
      tile.hd25_painted_priority = 0
      assign_geom_priority(tile, 0)
    end

    # true si el tile es una tapa plana (InteriorWall o Shelf), cualquiera que
    # sea el origen de su altura. Unifica las guardas que antes solo miraban
    # hd25_interior_flat.
    def flat_cap?(tile)
      return (tile.hd25_interior_flat || tile.hd25_shelf_flat) ? true : false
    end

    # Altura (tiles) de la tapa plana, segun su origen.
    def cap_height_tiles(tile)
      if tile.hd25_shelf_flat
        h = tile.hd25_shelf_own_pri.to_i
        h = tile.hd25_shelf_height.to_i if tile.hd25_shelf_height.to_i > h
        return 1 if h < 1
        return h
      end
      return interior_cap_height_tiles(tile)
    end

    # Prioridad propia de la celda tag 20 (capa nativa + capa extendida via
    # MakerStudio). Si el tile tiene prioridad propia, ESA es su altura: sin
    # esto una celda de prueba aislada (p.ej. pintada en capa extra sobre
    # suelo llano) heredaba la prioridad de cualquier vecino -- borde, adorno,
    # lo que fuera -- y la pared salia gigante o con la textura de otra cosa.
    def own_priority(map, cx, cy)
      best = 0
      data = map.data
      if data
        [0, 1, 2].each do |layer|
          tid = data[cx, cy, layer].to_i
          next if tid <= 0
          pri = (map.priorities[tid] || 0).to_i
          best = pri if pri > best
        end
      end
      if defined?(MakerStudio) && MakerStudio::ENABLED && map == $game_map
        MakerStudio.each_extended_tile_at(cx, cy) do |tid, td|
          pri = MakerStudio.resolve_band_priority(map, tid, td).to_i
          best = pri if pri > best
        end
      end
      return best
    end

    # Altura de la pared interior de (cx,cy). Primero la prioridad PROPIA de
    # la celda (el tile que se pinto con tag 20); solo si no tiene ninguna se
    # recurre al cuerpo vecino, para que la tapa y las bandas de
    # InteriorWallLayer acaben a la cota de la masa de al lado (pasillo
    # tallado en un muro real). Tope MAX_PRIORITY (INTERIOR_SRC_PRI_MAX solo
    # filtra textura).
    def interior_wall_height(map, cx, cy)
      h = Config::INTERIOR_WALL_HEIGHT.to_i
      h = 2 if h <= 0
      return h if !map || cx.nil? || cy.nil?
      cap = Config::MAX_PRIORITY.to_i
      cap = 5 if cap <= 0
      own = own_priority(map, cx, cy)
      return [own, cap].min if own >= 1
      data = map.data
      return h if !data
      best = h
      [[0, 1], [0, -1], [1, 0], [-1, 0]].each do |dx, dy|
        nx = cx + dx
        ny = cy + dy
        next if nx < 0 || ny < 0 || nx >= map.width || ny >= map.height
        [0, 1, 2].each do |layer|
          tid = data[nx, ny, layer].to_i
          next if tid <= 0
          pri = (map.priorities[tid] || 0).to_i
          next if pri < 1
          pri = cap if pri > cap
          best = pri if pri > best
        end
      end
      return best
    end

    # Alto de tapa InteriorWall: misma cuenta que las bandas de la cara.
    def interior_cap_height_tiles(tile)
      map = project_tile_map(tile.hd25_map_id)
      return interior_wall_height(map, tile.hd25_cell_x, tile.hd25_cell_y)
    end

    def shelf_tile_z_priority(tile)
      own = 0
      own = tile.hd25_shelf_own_pri.to_i if tile.respond_to?(:hd25_shelf_own_pri)
      h = tile.hd25_shelf_height.to_i
      own = h if h > own
      if tile.respond_to?(:priority)
        p = tile.priority.to_i
        own = p if p > own
      end
      if tile.respond_to?(:hd25_painted_priority) && !tile.hd25_painted_priority.nil?
        p = tile.hd25_painted_priority.to_i
        own = p if p > own
      end
      if tile.respond_to?(:cell_band) && !tile.cell_band.nil?
        band = tile.cell_band.to_i
        own = band if band > own
      end
      cap = Config::MAX_PRIORITY.to_i
      cap = 12 if cap <= 0
      own = cap if own > cap
      # Techo Shelf: nunca Z de suelo. Sin pri conocida, 1 ya pierde ante
      # TILE_CLEARANCE del personaje.
      own = 1 if own < 1 && tile.hd25_shelf_flat
      return own
    end

    # Z de tapa = misma formula que un tile pri N en project_tile_z.
    # Sin esto el personaje (screen_y + TILE_CLEARANCE + Z_LIFT) gana al techo.
    def apply_flat_cap_z(tile, row, pixel_offset_y = nil)
      return if !tile
      if tile.hd25_shelf_flat
        z_pri = shelf_tile_z_priority(tile)
      elsif tile.hd25_interior_flat
        z_pri = cap_height_tiles(tile)
      else
        return
      end
      z_pri = 1 if z_pri.to_i < 1
      th = TilemapRenderer::DISPLAY_TILE_HEIGHT
      poy = pixel_offset_y
      if poy.nil?
        poy = 0
        if $scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer)
          r = $scene.map_renderer
          poy = r.instance_variable_get(:@pixel_offset_y).to_i if r && !r.disposed?
        end
      end
      z = ((row + z_pri + 1) * th) - poy + 1
      tile.hd25_z_pre_raised = true
      tile.z = raised_tile_z(z)
    end

    # Tapa Shelf: tile tumbado en la BASE de su prioridad P.
    # Sur = canto bajo del vertical P (cierra con P-1). Norte = el mismo
    # canto en la casilla de arriba, para que dos tapas compartan arista.
    # Ancho sur = escala del vertical P (la del pri 4 si P=5 un tile al norte).
    def project_shelf_cap(tile, row)
      tile.opacity = 255
      cell_row = row
      tile.hd25_grid_row = row
      map = project_tile_map(tile.hd25_map_id)
      cx = tile.hd25_cell_x
      cy = tile.hd25_cell_y
      field = tile.hd25_walls
      field = nil if field && field.flat
      p = cap_height_tiles(tile)
      p = 1 if p < 1
      if p <= 1
        skip_seal = tile.hd25_skip_wall_seal
        scale = row_width_scale(cell_row)
        taper = 1.0
        if TAPER_SUPPORTED
          near = row_width_scale(cell_row + 1)
          if near && near > 0
            taper = row_taper(cell_row)
            scale = near
          end
        end
        if field
          top, bottom = wall_cell_bounds(field, cx, cy, cell_row, skip_seal)
        else
          top = row_top(cell_row)
          bottom = row_top(cell_row + 1)
        end
      else
        bottom = shelf_plane_y(map, cx, cy, cell_row, p, field)
        if cy && cy > 0
          top = shelf_plane_y(map, cx, cy - 1, cell_row - 1, p, field)
        else
          ground_s = row_top(cell_row + 1)
          top = row_top(cell_row) - (ground_s - bottom)
        end
        if map && cy && !cell_is_shelf?(map, cx, cy + 1)
          bottom += SHELF_JOIN_OVERLAP
        end
        bottom = top + 1 if bottom <= top
        scale = row_width_scale_any(raised_width_row(cell_row, p))
        taper = 1.0
        if TAPER_SUPPORTED
          far = row_width_scale_any(raised_width_row(cell_row - 1, p))
          if scale && scale > 0 && far && far > 0
            taper = far / scale
          end
        end
        b = blend
        if b < 1.0
          if field
            gtop, gbot = wall_cell_bounds(field, cx, cy, cell_row, true)
          else
            gtop = row_top(cell_row)
            gbot = row_top(cell_row + 1)
          end
          top = (gtop + ((top - gtop) * b)).round
          bottom = (gbot + ((bottom - gbot) * b)).round
          gscale = row_width_scale(cell_row + 1)
          if gscale && gscale > 0 && scale
            scale = gscale + ((scale - gscale) * b)
          end
          if TAPER_SUPPORTED
            gtaper = row_taper(cell_row)
            taper = gtaper + ((taper - gtaper) * b)
          end
        end
      end
      height = bottom - top
      height = 1 if height < 1
      left = tile.x
      start = project_x(left, scale)
      finish = project_x(left + TilemapRenderer::DISPLAY_TILE_WIDTH, scale)
      clear_wall_tile_tilt(tile)
      apply_tile_taper(tile, taper)
      zoom_y = height / TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
      tile.x = start
      tile.y = top
      wpx = finish - start
      apply_tile_zoom(tile, wpx / TilemapRenderer::SOURCE_TILE_WIDTH.to_f, zoom_y)
      tile.hd25_proj_stamp = @projection_stamp || 0
      tile.hd25_proj_row = cell_row
      tile.hd25_proj_scale = scale
      tile.hd25_proj_y = top
      tile.hd25_proj_zy = zoom_y
      tile.hd25_proj_side = 0
      tile.hd25_proj_wpx = wpx
      apply_flat_cap_z(tile, row)
    end

    # Tapa InteriorWall: el tile se dibuja como si tuviera prioridad h, con la
    # misma cuenta que un tile pri (escala de la fila de apoyo + pies compartidos).
    def project_interior_cap(tile, row)
      tile.opacity = 255
      cell_row = row
      tile.hd25_grid_row = row
      h = cap_height_tiles(tile)
      _feet, _unit, scale, _x_row, edges = column_stack_geom(
        tile.hd25_walls, tile.hd25_cell_x, tile.hd25_cell_y,
        cell_row, h, tile.hd25_map_id)
      bottom = edges[h - 1] || 0
      top = edges[h] || (bottom - 1)
      bottom += COLUMN_BAND_OVERLAP if h >= 2
      height = bottom - top
      height = 1 if height < 1
      left = tile.x
      start = project_x(left, scale)
      finish = project_x(left + TilemapRenderer::DISPLAY_TILE_WIDTH, scale)
      clear_wall_tile_tilt(tile)
      zoom_y = height / TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
      tile.x = start
      tile.y = top
      wpx = finish - start
      apply_tile_zoom(tile, wpx / TilemapRenderer::SOURCE_TILE_WIDTH.to_f, zoom_y)
      tile.hd25_proj_stamp = @projection_stamp || 0
      tile.hd25_proj_row = cell_row
      tile.hd25_proj_scale = scale
      tile.hd25_proj_y = top
      tile.hd25_proj_zy = zoom_y
      tile.hd25_proj_side = 0
      tile.hd25_proj_wpx = wpx
      # Z encima de la columna de altura h.
      th = TilemapRenderer::DISPLAY_TILE_HEIGHT
      poy = 0
      if $scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer)
        r = $scene.map_renderer
        poy = r.instance_variable_get(:@pixel_offset_y).to_i if r && !r.disposed?
      end
      ground = ((row + h + 1) * th) - poy
      tile.hd25_z_pre_raised = true
      tile.z = raised_tile_z(ground + 1)
    end

    # ponytail: flag en bind (terrain_tag una vez), no por frame.
    def annotate_wall_seal_skip!(tile, map)
      tile.hd25_skip_wall_seal = false
      return if !Config::WALL_SEAL_SKIP_SURF || !map
      cx = tile.hd25_cell_x
      cy = tile.hd25_cell_y
      return if cx.nil? || cy.nil?
      return if cx < 0 || cy < 0 || cx >= map.width || cy >= map.height
      tag = map.terrain_tag(cx, cy, true)
      tile.hd25_skip_wall_seal = tag && tag.can_surf
    end

    # El dibujo del tile (no la casilla). Un agua sobre tag 19 sigue siendo
    # agua: no se parte, pero el sellado del muro no se toca.
    def annotate_surf_graphic!(tile, map, tile_id)
      surf = false
      if Config::WALL_SEAL_SKIP_SURF && map && map.terrain_tags && tile_id.to_i > 0
        tag = GameData::TerrainTag.try_get(map.terrain_tags[tile_id.to_i])
        surf = !!(tag && tag.can_surf)
      end
      if tile.respond_to?(:hd25_surf_graphic=)
        tile.hd25_surf_graphic = surf
      else
        tile.instance_variable_set(:@hd25_surf_graphic, surf)
      end
    end

    # Scroll: actualizar cx/cy desde cache de offsets (sin getMap).
    # Tambien sin WallField: Shelf e InteriorWall re-anotan al reciclar sprite.
    def sync_tile_wall_cell(tile, x, y)
      offset = map_tile_offset_for_id(tile.hd25_map_id)
      return if !offset
      cx = x + offset[0]
      cy = y + offset[1]
      return if tile.hd25_cell_x == cx && tile.hd25_cell_y == cy
      was_shelf = tile.hd25_shelf_flat ? true : false
      was_interior = tile.hd25_interior_flat ? true : false
      tile.hd25_cell_x = cx
      tile.hd25_cell_y = cy
      field = tile.hd25_walls
      tile.hd25_lifted = field ? field.lifted?(cx, cy) : false
      map = project_tile_map(tile.hd25_map_id)
      tid = tile.respond_to?(:tile_id) ? tile.tile_id : nil
      annotate_shelf_flat!(tile, map, tid)
      annotate_interior_flat!(tile, map)
      now_shelf = tile.hd25_shelf_flat ? true : false
      now_interior = tile.hd25_interior_flat ? true : false
      # El sprite cambia de casilla sin rebind. Si la tapa cambia, el cache de
      # scroll X seguiria con la Y y el zoom de la casilla anterior.
      if was_shelf != now_shelf || was_interior != now_interior
        apply_tile_taper(tile, 1.0)
        tile.hd25_proj_stamp = nil
        if tile.hd25_zoom_x || tile.hd25_zoom_y
          tile.zoom_x = tile.hd25_base_zoom_x || TilemapRenderer::ZOOM_X
          tile.zoom_y = tile.hd25_base_zoom_y || TilemapRenderer::ZOOM_Y
          tile.hd25_zoom_x = nil
          tile.hd25_zoom_y = nil
        end
      end
    end

    # Offset display→casilla. Durante shift_maps_for_render el display YA va
    # restado el margen: NO hay que volver a sumar @shift_*. Si se suma,
    # hd25_cell queda en C+margin y WallField (coords reales) desincroniza
    # nativos vs capas MakerStudio, que guardan C directo.
    def compute_map_tile_offset(map)
      zoom_x = TilemapRenderer::ZOOM_X
      zoom_y = TilemapRenderer::ZOOM_Y
      display_x = (map.display_x.to_f / Game_Map::X_SUBPIXELS).round
      display_x = ((display_x + (Graphics.width / 2)) * zoom_x) - (Graphics.width / 2) if zoom_x != 1
      display_y = (map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
      display_y = ((display_y + (Graphics.height / 2)) * zoom_y) - (Graphics.height / 2) if zoom_y != 1
      return [display_x / TilemapRenderer::DISPLAY_TILE_WIDTH,
              display_y / TilemapRenderer::DISPLAY_TILE_HEIGHT]
    end

    def map_tile_offset(map)
      return [0, 0] if !map
      cache = @map_offset_cache
      if cache
        hit = cache[map.map_id]
        return hit if hit
      end
      result = compute_map_tile_offset(map)
      (@map_offset_cache ||= {})[map.map_id] = result
      return result
    end

    def map_tile_offset_for_id(map_id)
      return nil if map_id.nil?
      cache = @map_offset_cache
      return cache[map_id] if cache && cache.key?(map_id)
      return nil if !$map_factory&.hasMap?(map_id)
      map = $map_factory.getMap(map_id, false)
      return map_tile_offset(map) if map
      return nil
    end

    # Fila de rejilla nativa para una casilla de mapa real.
    # Nativos proyectan CON shift (display ya restado el margen): el offset
    # ya lleva el corrimiento, no volver a sumar margin_rows.
    # Extended / personajes proyectan SIN shift: hay que sumar el margen
    # para alinear con el j del tilemap.
    def grid_row_for_map_cell(map, cell_y)
      return cell_y if !map || cell_y.nil?
      extra = shifted_for_render? ? 0 : margin_rows
      return cell_y - map_tile_offset(map)[1] + extra
    end

    def grid_row_for_map_cell_id(map_id, cell_y)
      return nil if map_id.nil? || cell_y.nil?
      offset = map_tile_offset_for_id(map_id)
      return nil if !offset
      extra = shifted_for_render? ? 0 : margin_rows
      return cell_y - offset[1] + extra
    end

    def clear_tile_offsets
    end

    # Fila de rejilla que muestra esta casilla del mapa (solo para depuracion).
    def grid_row_for_cell(map, cy)
      return cy - map_tile_offset(map)[1]
    end

    #---------------------------------------------------------------------------
    # WallField v3.0.1 — lift unprojected + project_y.
    #
    # pri0 = caja de casilla (aristas compartidas).
    # pri>=1 = UN plano vertical por columna (column_stack_geom). Pri X y
    # pri X+1 (fila de encima) comparten feet/unit/scale/edges: la junta es
    # edges[X]. Mezclar caja de suelo en pri1 y billboard en pri2 dejaba
    # una banda entre 1 y 2.
    #---------------------------------------------------------------------------

    def wall_edge_unprojected(field, cx, edge_cy, grid_row)
      tile_h = TilemapRenderer::DISPLAY_TILE_HEIGHT
      y = (grid_row * tile_h) - (@row_offset || 0)
      return y if !field || field.flat || cx.nil? || edge_cy.nil?
      amount = field.lift(cx, edge_cy)
      return y if amount <= 0.0
      return y - (amount * WALL_LIFT_PX)
    end

    # Pixeles de lift en pantalla desde una Y unprojected (personajes / anclas).
    def lift_amount_dy(amount, edge_y)
      return 0 if amount.nil? || amount <= 0.0
      dy = amount * WALL_LIFT_PX
      hi = edge_y
      lo = edge_y - dy
      return (raw_project_y(hi) + horizon_curve(hi) - raw_project_y(lo) - horizon_curve(lo)).round
    end

    # Arista compartida: bottom(x,y) y top(x,y+1) llaman con el mismo
    # (edge_cy, grid_row) → mismo unprojected → mismo project_y.
    # ponytail: sin lift → row_top (tabla); evita project_y en bosques/planos.
    def wall_edge_y(field, cx, edge_cy, grid_row)
      return row_top(grid_row) if !field || field.flat || cx.nil? || edge_cy.nil?
      amount = field.lift(cx, edge_cy)
      return row_top(grid_row) if amount <= 0.0
      tile_h = TilemapRenderer::DISPLAY_TILE_HEIGHT
      y = (grid_row * tile_h) - (@row_offset || 0) - (amount * WALL_LIFT_PX)
      return project_y(y)
    end

    def wall_cell_top_y(field, cx, cy, grid_row)
      return wall_edge_y(field, cx, cy, grid_row)
    end

    def wall_cell_bottom_y(field, cx, cy, grid_row)
      return wall_edge_y(field, cx, cy + 1, grid_row + 1)
    end

    # Escalón horizontal (flags precomputados en WallField).
    def lateral_lift_step?(field, cx, cy)
      return false if !field || field.flat || cx.nil? || cy.nil?
      return field.lateral_step?(cx, cy)
    end

    # Solape horizontal: casilla lifted o pegada a un escalón lateral.
    def wall_side_seal_px(field, cx, cy, skip_seal = false)
      return 0 if skip_seal
      seal = Config::WALL_SIDE_SEAL
      return 0 if seal <= 0 || !field || field.flat || cx.nil? || cy.nil?
      return 0 if !field.wall_geom?(cx, cy)
      # Esquina Cliff: un px mas (triangulo negro entre columnas).
      extra = Config::WALL_CORNER_EXTRA.to_i
      if extra > 0 && field.lifted?(cx, cy) && field.lateral_step?(cx, cy)
        seal += extra
      end
      return seal
    end

    # Aristas por COLUMNA (lift de esta cx), no media con el vecino.
    # Promediar TL/TR rompia la costura vertical entre columnas → huecos.
    # skip_seal: agua/surf — sin solape (alpha apilada); aristas siguen compartidas.
    def wall_cell_bounds(field, cx, cy, grid_row, skip_seal = false)
      if field && !field.flat && !cx.nil? && !cy.nil? && field.lifted?(cx, cy)
        top = wall_cell_top_y(field, cx, cy, grid_row)
        bottom = wall_cell_bottom_y(field, cx, cy, grid_row)
        seal = skip_seal ? 0 : Config::WALL_EDGE_SEAL
        if seal > 0
          top -= seal
          bottom += seal
        end
        top = bottom - 1 if bottom <= top
      elsif field && !field.flat && !cx.nil? && !cy.nil? && field.lateral_step?(cx, cy)
        # Vecino con desnivel: solape vertical tapa el triangulo negro de esquina.
        top = row_top(grid_row)
        bottom = row_top(grid_row + 1)
        seal = skip_seal ? 0 : Config::WALL_EDGE_SEAL
        if seal > 0
          top -= seal
          bottom += seal
        end
      else
        top = row_top(grid_row)
        bottom = row_top(grid_row + 1)
      end
      return top, bottom
    end

    def flat_cell_bounds(grid_row)
      return row_top(grid_row), row_top(grid_row + 1)
    end

    def anchored_cell_bounds(field, cx, cy, grid_row, skip_seal = false)
      return wall_cell_bounds(field, cx, cy, grid_row, skip_seal)
    end

    # Un plano vertical por columna: pri X en cy y pri X+1 en cy-1 leen el
    # mismo (feet, unit, scale, edges). La junta X↔X+1 es edges[X] al pixel.
    # Clave = (mapa, cx, fila de apoyo), no cy: el primero que proyecta fija
    # el plano y el siguiente se pega, aunque su cy/lift discrepe un poco.
    COLUMN_BAND_OVERLAP = 1

    def clear_column_stack_cache!
      if @col_stack
        @col_stack.clear
      else
        @col_stack = {}
      end
      @col_stack_stamp = nil
      if @feet_cache
        @feet_cache.clear
      else
        @feet_cache = {}
      end
      @feet_cache_stamp = nil
    end

    def column_stack_geom(field, cx, cy, cell_row, priority, map_id = 0)
      priority = 1 if priority < 1
      # Base del plano = casilla pri 1 (cy+P-1). Nativo y MakerStudio pueden
      # traer un cell_row distinto (margen); si la clave usa la fila de
      # rejilla, pri 1 y pri 2 no se encuentran y se abre el hueco del 199.
      base_cy = cy.nil? ? nil : (cy + priority - 1)
      stamp = @projection_stamp || 0
      if @col_stack_stamp != stamp
        @col_stack ||= {}
        @col_stack.clear
        @col_stack_stamp = stamp
      end
      key = (cx || 0) + ((base_cy || 0) * 4096) + (map_id.to_i * 16_777_216)
      cached = @col_stack[key]
      return cached if cached
      # Siempre las cuentas del tramo 1: pies = arista sur de la base.
      base_row = cell_row + priority - 1
      x_row = raised_width_row(base_row, 1)
      scale = row_width_scale(x_row)
      unit = row_unit(x_row)
      if !unit || unit <= 0
        unit = vertical_unit_at(row_top(x_row + 1))
      end
      feet = wall_column_feet_y(field, cx, base_cy, base_row, 1)
      maxp = Config::MAX_PRIORITY
      maxp = 12 if !maxp || maxp <= 0
      edges = Array.new(maxp + 1)
      k = 0
      while k <= maxp
        edges[k] = (feet - (k * unit)).round
        k += 1
      end
      result = [feet, unit, scale, x_row, edges, nil]
      @col_stack[key] = result
      return result
    end

    # Pies de prioridad p en (cx,cy): arista con (cy+p). pri1 → y+1.
    # Cache por stamp: pri1+pri2 de la misma columna comparten pies.
    def wall_column_feet_y(field, cx, cy, cell_row, priority)
      edge_row = cell_row + priority
      return row_top(edge_row) if !field || field.flat || cx.nil? || cy.nil?
      edge_cy = cy + priority
      stamp = @projection_stamp || 0
      if @feet_cache_stamp != stamp
        @feet_cache ||= {}
        @feet_cache.clear
        @feet_cache_stamp = stamp
      end
      # key entero: sin Array alloc por tile raised.
      key = cx + (edge_cy * 4096) + (edge_row * 16_777_216)
      cached = @feet_cache[key]
      return cached if cached
      result = wall_edge_y(field, cx, edge_cy, edge_row)
      @feet_cache[key] = result
      return result
    end

    def wall_column_anchor_y(field, cx, cy, cell_row, priority)
      return wall_column_feet_y(field, cx, cy, cell_row, priority)
    end

    # Fila de la que sale row_unit/scale de la columna: la del apoyo (pies).
    # Asi pri1 en cy y pri2 en cy-1 comparten el mismo unit (misma x_row).
    def raised_width_row(cell_row, priority)
      return cell_row + priority - 1
    end

    def project_tile_map(map)
      return nil if !map
      return map if map.is_a?(Game_Map)
      return $map_factory.getMap(map, false) if $map_factory&.hasMap?(map)
      return nil
    end

    # Si el sprite se enlazo con 2.5D OFF, puede no tener hd25_cell_*.
    def ensure_tile_cells(tile)
      return if !tile.hd25_cell_x.nil? && !tile.hd25_cell_y.nil?
      if tile.respond_to?(:map_x) && !tile.map_x.nil? && !tile.map_y.nil?
        tile.hd25_cell_x = tile.map_x.to_i
        tile.hd25_cell_y = tile.map_y.to_i
        tile.hd25_map_id = tile.map_id if tile.hd25_map_id.nil? && tile.respond_to?(:map_id)
      end
      if tile.hd25_walls.nil? && tile.hd25_map_id && respond_to?(:wall_field)
        map = project_tile_map(tile.hd25_map_id)
        if map
          field = wall_field(map)
          tile.hd25_walls = (field && !field.flat) ? field : nil
        end
      end
    end

    def project_tile(tile, row)
      return if tile_blank?(tile)
      perf_tick(:full)
      ensure_tile_cells(tile)
      # Tapa plana nativa: Shelf = tile tumbado a la base de su pri; InteriorWall = cap.
      if flat_cap?(tile)
        release_ground_slices(tile) if tile.hd25_slice_n.to_i > 1
        if Visual25D.enabled?
          if tile.hd25_shelf_flat
            project_shelf_cap(tile, row)
          else
            project_interior_cap(tile, row)
          end
          return
        end
        tile.opacity = 255 if tile.opacity == 0
      end
      field = tile.hd25_walls
      cell_row = row
      derived = grid_row_for_map_cell_id(tile.hd25_map_id, tile.hd25_cell_y)
      cell_row = derived if !derived.nil?
      tile.hd25_grid_row = cell_row
      # Bosque/plano pri0: sin geom_priority ni wall_cell_bounds (mismo look).
      if !field && !tile.shows_reflection && !tile.bridge
        pri = tile.hd25_geom_priority
        painted = tile.hd25_painted_priority
        if (pri.nil? || pri.to_i <= 0) &&
           (painted.nil? || painted.to_i <= 0) &&
           tile.priority.to_i <= 0
          if ground_slice_count > 1 && place_ground_strips(tile, cell_row, tile.x)
            return
          end
          # El tile se dibuja al ancho de su borde INFERIOR (fila cell_row + 1,
          # la mas cercana a camara) y se estrecha hasta el de su borde
          # superior. Antes usaba una sola escala para todo el alto, que es lo
          # que dejaba el escalon contra la fila de detras.
          scale = row_width_scale(cell_row)
          near_scale = TAPER_SUPPORTED ? row_width_scale(cell_row + 1) : scale
          near_scale = scale if !near_scale || near_scale <= 0
          top = row_top(cell_row)
          bottom = row_top(cell_row + 1)
          height = bottom - top
          height = 1 if height < 1
          left = tile.x
          start = project_x(left, near_scale)
          finish = project_x(left + TilemapRenderer::DISPLAY_TILE_WIDTH, near_scale)
          clear_wall_tile_tilt(tile)
          apply_tile_taper(tile, row_taper(cell_row))
          zoom_y = height / TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
          tile.x = start
          tile.y = top
          wpx = finish - start
          apply_tile_zoom(tile, wpx / TilemapRenderer::SOURCE_TILE_WIDTH.to_f, zoom_y)
          tile.hd25_proj_stamp = @projection_stamp || 0
          tile.hd25_proj_row = cell_row
          # La que usa project_x, no la del borde de arriba: en scroll E/O el
          # camino corto reposiciona con esta y el taper no cambia.
          tile.hd25_proj_scale = near_scale
          tile.hd25_proj_y = top
          tile.hd25_proj_zy = zoom_y
          tile.hd25_proj_side = 0
          tile.hd25_proj_wpx = wpx
          return
        end
      end
      priority = geom_priority(tile)
      priority = 0 if priority <= 0 || tile.shows_reflection || tile.bridge
      cx = tile.hd25_cell_x
      cy = tile.hd25_cell_y
      skip_seal = tile.hd25_skip_wall_seal
      side = 0
      taper = 1.0
      geom = nil
      if priority == 0
        if ground_slice_count > 1 && place_ground_strips(tile, cell_row, tile.x)
          return
        end
        # Suelo: mismo trapecio que en el camino rapido de arriba.
        scale = row_width_scale(cell_row)
        if TAPER_SUPPORTED
          near = row_width_scale(cell_row + 1)
          if near && near > 0
            taper = row_taper(cell_row)
            scale = near
          end
        end
        top, bottom = wall_cell_bounds(field, cx, cy, cell_row, skip_seal)
        height = bottom - top
        height = 1 if height < 1
      else
        release_ground_slices(tile) if tile.hd25_slice_n.to_i > 1
        # Billboard de pie: un solo plano por columna (pies + unit + scale).
        # Pri X y pri X+1 de la fila de encima leen el mismo cache: la junta
        # es edges[X], no dos redondeos independientes.
        geom = column_stack_geom(
          field, cx, cy, cell_row, priority, tile.hd25_map_id)
        _feet, _unit, scale, _x_row, edges = geom
        bottom = edges[priority - 1] || 0
        top    = edges[priority] || (bottom - 1)
        # El tramo de encima solapa 1 px hacia el de abajo. Con Z X+1 > X
        # tapa el pelo de la junta sin abrir hueco.
        bottom += COLUMN_BAND_OVERLAP if priority >= 2
        height = bottom - top
        height = 1 if height < 1
        if Config::COLUMN_LEAN > 0
          tip = row_width_scale(cell_row)
          scale += (tip - scale) * Config::COLUMN_LEAN
        end
      end
      left = tile.x
      start = project_x(left, scale)
      finish = project_x(left + TilemapRenderer::DISPLAY_TILE_WIDTH, scale)
      # Seal de la BASE de la columna (pri 1), no de cada casilla pintada:
      # si no, pri1 lifted y pri2 plano salen con distinto ancho y se corta el plano.
      if field
        if geom && !geom[5].nil?
          side = geom[5]
        else
          seal_cy = cy.nil? ? nil : (cy + [priority, 1].max - 1)
          side = wall_side_seal_px(field, cx, seal_cy, skip_seal)
          geom[5] = side if geom
        end
        if side > 0
          start -= side
          finish += side
        end
      end
      clear_wall_tile_tilt(tile)
      apply_tile_taper(tile, taper)
      zoom_y = height / TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
      tile.x = start
      tile.y = top
      wpx = finish - start
      apply_tile_zoom(tile, wpx / TilemapRenderer::SOURCE_TILE_WIDTH.to_f, zoom_y)
      # Para project_tile_scroll_x (andar E/O sin rebuild vertical).
      tile.hd25_proj_stamp = @projection_stamp || 0
      tile.hd25_proj_row = cell_row
      tile.hd25_proj_scale = scale
      tile.hd25_proj_y = top
      tile.hd25_proj_zy = zoom_y
      tile.hd25_proj_side = side
      tile.hd25_proj_wpx = wpx
    end

    def clear_wall_tile_tilt(tile)
      return if !tile.hd25_tilting
      tile.hd25_tilting = false
      tile.angle = 0
      tile.ox = 0
      tile.oy = 0
    end

    # Al correr N/S el Sprite#zoom puede haberse reseteado (MS bind / ox) y
    # hd25_zoom_* seguir con el valor viejo: el skip por EPS no escribiria.
    def invalidate_tile_zoom!(tile)
      tile.hd25_zoom_x = nil
      tile.hd25_zoom_y = nil
      tile.hd25_proj_stamp = nil
    end

    def apply_tile_zoom(tile, zoom_x, zoom_y)
      if tile.hd25_base_zoom_x
        zoom_x *= tile.hd25_base_zoom_x / TilemapRenderer::ZOOM_X.to_f
        zoom_y *= tile.hd25_base_zoom_y / TilemapRenderer::ZOOM_Y.to_f
      end
      zoom_x = quant_zoom(zoom_x)
      zoom_y = quant_zoom(zoom_y)
      live_x = tile.zoom_x
      live_y = tile.zoom_y
      if !tile.hd25_zoom_x || (tile.hd25_zoom_x - zoom_x).abs > ZOOM_EPS ||
         (live_x - zoom_x).abs > ZOOM_EPS
        tile.zoom_x = zoom_x
        tile.hd25_zoom_x = zoom_x
      end
      if !tile.hd25_zoom_y || (tile.hd25_zoom_y - zoom_y).abs > ZOOM_EPS ||
         (live_y - zoom_y).abs > ZOOM_EPS
        tile.zoom_y = zoom_y
        tile.hd25_zoom_y = zoom_y
      end
    end

    # 1 = un trapecio. 2 o 4 = franjas. Otro valor que no divida el alto
    # fuente cae a 2. Sin Sprite#taper no se parte.
    def ground_slice_count
      raw = Config::GROUND_SLICES.to_i
      return @ground_slice_count if @ground_slice_raw == raw && @ground_slice_count
      @ground_slice_raw = raw
      n = 1
      if raw > 1 && Sprite.method_defined?(:taper=)
        raw = 4 if raw > 4
        src = TilemapRenderer::SOURCE_TILE_HEIGHT
        raw = 2 if (src % raw) != 0
        n = raw
      end
      @ground_slice_count = n
      return n
    end

    # Una vez por fila, al reconstruir la proyeccion. El borde de arriba de
    # la primera franja y el de abajo de la ultima son row_top: la junta
    # entre tiles no se mueve. El +1 solo tapa el pelo entre franjas del
    # MISMO tile, no el del tile de debajo.
    def build_row_slices(row_max, tile_height)
      # La fila de pantalla se reclasifica al reconstruir. La lista de tiles
      # partidos no: si se borra, el agua que entra después no puede
      # devolver al trapecio a los que ya se dibujaron este frame.
      @flat_ground_rows = nil
      n = ground_slice_count
      @row_slice_n = n
      return if n <= 1 || !@row_top || !@row_width
      count = row_max + 1
      if !@row_slice_y || @row_slice_y.length != count
        @row_slice_y = Array.new(count)
        @row_slice_s = Array.new(count)
        @row_slice_zy = Array.new(count)
        @row_slice_tp = Array.new(count)
      end
      full_h = TilemapRenderer::SOURCE_TILE_HEIGHT
      band_f = (full_h / n).to_f
      offset = @row_offset || 0
      row = 0
      while row < row_max
        top_y = @row_top[row]
        bot_y = @row_top[row + 1]
        if !top_y || !bot_y || (bot_y - top_y) < n
          @row_slice_y[row] = nil
          row += 1
          next
        end
        ys = @row_slice_y[row]
        ss = @row_slice_s[row]
        zy = @row_slice_zy[row]
        tp = @row_slice_tp[row]
        if !ys || ys.length != n + 1
          ys = Array.new(n + 1)
          ss = Array.new(n + 1)
          zy = Array.new(n)
          tp = Array.new(n)
          @row_slice_y[row] = ys
          @row_slice_s[row] = ss
          @row_slice_zy[row] = zy
          @row_slice_tp[row] = tp
        end
        top_u = (row * tile_height) - offset
        ys[0] = top_y
        ys[n] = bot_y
        ss[0] = @row_width[row]
        ss[n] = @row_width[row + 1]
        k = 1
        while k < n
          f = k.to_f / n
          ys[k] = project_y(top_u + (f * tile_height))
          ss[k] = width_scale_at(top_u + (tile_height / 2.0) + (f * tile_height))
          k += 1
        end
        k = 1
        while k < n
          min_y = ys[k - 1] + 1
          max_y = ys[n] - (n - k)
          y = ys[k]
          y = min_y if y < min_y
          y = max_y if y > max_y
          ys[k] = y
          k += 1
        end
        k = 0
        while k < n
          y0 = ys[k]
          y1 = ys[k + 1]
          y1 = y0 + 1 if y1 <= y0
          draw_b = (k < n - 1) ? (y1 + 1) : y1
          s0 = ss[k]
          s1 = ss[k + 1]
          s0 = s1 if !s0 || s0 <= 0
          s1 = s0 if !s1 || s1 <= 0
          tp[k] = (s1 > 0) ? (s0 / s1) : 1.0
          zy[k] = (draw_b - y0) / band_f
          k += 1
        end
        row += 1
      end
      @row_slice_y[row_max] = nil
    end

    def ensure_ground_slice(tile, index)
      list = tile.hd25_slices
      if !list
        list = []
        tile.hd25_slices = list
      end
      spr = list[index]
      if !spr || spr.disposed? || !spr.is_a?(GroundStrip)
        spr.dispose if spr && !spr.disposed?
        spr = GroundStrip.new(tile.viewport)
        spr.bitmap = nil
        spr.visible = false
        spr.z = tile.z
        list[index] = spr
      end
      return spr
    end

    def release_ground_slices(tile)
      return if !tile
      forget_sliced_tile(tile)
      return if tile.hd25_slice_n.to_i <= 1
      full = TilemapRenderer::SOURCE_TILE_HEIGHT
      sr = tile.src_rect
      if sr && tile.hd25_src_h && sr.height < full
        sr.height = tile.hd25_src_h
      end
      tile.hd25_slice_n = 1
      slices = tile.hd25_slices
      return if !slices
      slices.each do |spr|
        next if !spr || spr.disposed?
        spr.visible = false if spr.visible
        spr.bitmap = nil if spr.bitmap
      end
    end

    def sync_ground_slice_src(tile)
      n = tile.hd25_slice_n.to_i
      return if n <= 1
      sr = tile.src_rect
      return if !sr
      full_h = TilemapRenderer::SOURCE_TILE_HEIGHT
      full_w = TilemapRenderer::SOURCE_TILE_WIDTH
      band = full_h / n
      # El padre es solo la franja de arriba. Si el alto vuelve a 32, dibuja
      # el tile entero encima de las franjas de abajo y el alpha se suma.
      assign_strip_src(tile, sr.x, sr.y, full_w, band)
      slices = tile.hd25_slices
      return if !slices
      i = 0
      while i < n - 1
        spr = slices[i]
        i += 1
        next if !spr || spr.disposed? || !spr.bitmap
        assign_strip_src(spr, sr.x, sr.y + (i * band), full_w, band)
      end
    end

    # Frame de autotile sin scroll. Si el grafico es transparente, la fila
    # deja de partirse aunque el jugador esté quieto.
    def sync_ground_slice_frame(tile)
      return if !tile || tile.hd25_slice_n.to_i <= 1
      if tile_forces_flat_row?(tile)
        mark_map_row_flat!(tile)
        row = tile.hd25_slice_row
        row = tile.hd25_proj_row if row.nil?
        flatten_ground_row!(row) if !row.nil?
        if tile.hd25_slice_n.to_i > 1
          left = tile.hd25_grid_left
          release_ground_slices(tile)
          place_full_ground_trapezoid(tile, row, left) if !row.nil? && !left.nil?
        end
        return
      end
      sync_ground_slice_src(tile)
    end

    def place_ground_strips(tile, cell_row, left)
      n = @row_slice_n || ground_slice_count
      if n <= 1 || !tile.bitmap
        release_ground_slices(tile)
        return false
      end
      rows = @row_slice_y
      if !rows || cell_row < 0 || cell_row >= rows.length
        release_ground_slices(tile)
        return false
      end
      ys = rows[cell_row]
      if !ys
        release_ground_slices(tile)
        return false
      end
      # Fila ya marcada (agua / transparente): un trapecio, sin rehacer franjas.
      if map_row_flat?(tile) || flat_ground_row?(cell_row)
        release_ground_slices(tile)
        return false
      end
      # N/S: el tile ya está partido. Solo se mueven x/y/zoom. Sin get_pixel,
      # sin rebind y sin volver a recortar el src. Misma casilla: el muro no
      # cambia, no hace falta lifted?/lateral cada pixel.
      if tile.hd25_slice_n.to_i == n && tile.hd25_forces_flat == false
        same_cell = tile.hd25_slice_cx == tile.hd25_cell_x &&
                    tile.hd25_slice_cy == tile.hd25_cell_y
        return true if reposition_sliced_strips(tile, cell_row, left, same_cell)
      end
      if tile_forces_flat_row?(tile)
        mark_map_row_flat!(tile)
        flatten_ground_row!(cell_row, tile)
        release_ground_slices(tile)
        return false
      end
      unless ground_tile_sliceable?(tile)
        release_ground_slices(tile)
        return false
      end
      full_h = TilemapRenderer::SOURCE_TILE_HEIGHT
      full_w = TilemapRenderer::SOURCE_TILE_WIDTH
      sr = tile.src_rect
      if !sr || sr.width != full_w
        release_ground_slices(tile)
        return false
      end
      if sr.height == full_h
        tile.hd25_src_h = full_h
      elsif sr.height > full_h || tile.hd25_src_h != full_h
        release_ground_slices(tile)
        return false
      end
      clear_wall_tile_tilt(tile) if tile.hd25_tilting
      ss = @row_slice_s[cell_row]
      zy = @row_slice_zy[cell_row]
      tp = @row_slice_tp[cell_row]
      band = full_h / n
      ox = sr.x
      oy = sr.y
      dw = TilemapRenderer::DISPLAY_TILE_WIDTH
      sw = full_w.to_f
      tile.hd25_slice_n = n
      top_near = nil
      top_wpx = nil
      k = 0
      while k < n
        spr = (k == 0) ? tile : ensure_ground_slice(tile, k - 1)
        y0 = ys[k]
        near = ss[k + 1]
        near = ss[k] if !near || near <= 0
        bind_ground_strip(spr, tile) if k > 0
        start = project_x(left, near)
        finish = project_x(left + dw, near)
        wpx = finish - start
        wpx = 1 if wpx < 1
        apply_strip_taper(spr, tp[k])
        apply_strip_zoom(spr, tile, wpx / sw, zy[k])
        spr.x = start if spr.x != start
        spr.y = y0 if spr.y != y0
        assign_strip_src(spr, ox, oy + (k * band), full_w, band)
        if k == 0
          top_near = near
          top_wpx = wpx
        else
          spr.hd25_near = near
          spr.hd25_zy = zy[k]
          spr.hd25_wpx = wpx
        end
        k += 1
      end
      slices = tile.hd25_slices
      if slices
        i = n - 1
        while i < slices.length
          spr = slices[i]
          spr.visible = false if spr && !spr.disposed? && spr.visible
          i += 1
        end
      end
      tile.hd25_proj_stamp = @projection_stamp || 0
      tile.hd25_proj_row = cell_row
      tile.hd25_proj_scale = top_near
      tile.hd25_proj_y = ys[0]
      tile.hd25_proj_zy = zy[0]
      tile.hd25_proj_side = 0
      tile.hd25_proj_wpx = top_wpx
      remember_sliced_tile(cell_row, tile, left)
      return true
    end

    def flat_map_row_key(id, cy)
      return (id.to_i << 16) + cy.to_i + 32_768
    end

    # Misma fila de mapa ya vista con agua o con un tile transparente.
    def map_row_flat?(tile)
      rows = @flat_map_rows
      return false if !rows || !tile
      id = tile.hd25_map_id
      cy = tile.hd25_cell_y
      return false if id.nil? || cy.nil?
      return !!(rows[flat_map_row_key(id, cy)])
    end

    def mark_map_row_flat!(tile)
      return if !tile
      id = tile.hd25_map_id
      cy = tile.hd25_cell_y
      return if id.nil? || cy.nil?
      @flat_map_rows ||= {}
      @flat_map_rows[flat_map_row_key(id, cy)] = true
    end

    # Scroll N/S con las franjas ya creadas. No toca bitmap, src ni tono.
    # known_sliceable: misma casilla que cuando se partió; el muro no cambió.
    def reposition_sliced_strips(tile, cell_row, left, known_sliceable = false)
      n = tile.hd25_slice_n.to_i
      return false if n <= 1
      band = TilemapRenderer::SOURCE_TILE_HEIGHT / n
      sr = tile.src_rect
      return false if !sr || sr.height != band
      return false if !known_sliceable && !ground_tile_sliceable?(tile)
      ys = @row_slice_y && @row_slice_y[cell_row]
      ss = @row_slice_s && @row_slice_s[cell_row]
      zy = @row_slice_zy && @row_slice_zy[cell_row]
      tp = @row_slice_tp && @row_slice_tp[cell_row]
      return false if !ys || !ss || !zy || !tp || ys.length != n + 1
      slices = tile.hd25_slices
      dw = TilemapRenderer::DISPLAY_TILE_WIDTH
      sw = TilemapRenderer::SOURCE_TILE_WIDTH.to_f
      k = 0
      while k < n
        spr = (k == 0) ? tile : (slices && slices[k - 1])
        return false if !spr || spr.disposed?
        return false if k > 0 && (!spr.bitmap || !spr.is_a?(GroundStrip))
        y0 = ys[k]
        near = ss[k + 1]
        near = ss[k] if !near || near <= 0
        start = project_x(left, near)
        finish = project_x(left + dw, near)
        wpx = finish - start
        wpx = 1 if wpx < 1
        apply_strip_taper(spr, tp[k])
        apply_strip_zoom(spr, tile, wpx / sw, zy[k])
        spr.x = start if spr.x != start
        spr.y = y0 if spr.y != y0
        if k == 0
          tile.hd25_proj_stamp = @projection_stamp || 0
          tile.hd25_proj_row = cell_row
          tile.hd25_proj_scale = near
          tile.hd25_proj_y = y0
          tile.hd25_proj_zy = zy[0]
          tile.hd25_proj_side = 0
          tile.hd25_proj_wpx = wpx
        else
          z = tile.z
          spr.z = z if spr.z != z
          spr.hd25_near = near
          spr.hd25_zy = zy[k]
          spr.hd25_wpx = wpx
        end
        k += 1
      end
      if tile.hd25_slice_row != cell_row
        remember_sliced_tile(cell_row, tile, left)
      else
        tile.hd25_grid_left = left
      end
      return true
    end

    def flat_ground_row?(row)
      rows = @flat_ground_rows
      return !!(rows && rows[row])
    end

    # Los que ya se partieron en esta fila pasan al trapecio completo, el
    # mismo que usa el caller cuando place_ground_strips devuelve false.
    def flatten_ground_row!(row, skip_tile = nil)
      @flat_ground_rows ||= {}
      return if @flat_ground_rows[row]
      @flat_ground_rows[row] = true
      lists = @sliced_row_tiles
      list = lists && lists[row]
      return if !list || list.empty?
      tiles = list.dup
      list.clear
      tiles.each do |tile|
        next if !tile || tile.disposed? || tile.equal?(skip_tile)
        next if tile.hd25_slice_row != row
        grid_left = tile.hd25_grid_left
        tile.hd25_slice_row = nil
        release_ground_slices(tile)
        next if grid_left.nil?
        place_full_ground_trapezoid(tile, row, grid_left)
      end
    end

    def remember_sliced_tile(row, tile, left)
      forget_sliced_tile(tile)
      tile.hd25_grid_left = left
      tile.hd25_slice_row = row
      tile.hd25_slice_cx = tile.hd25_cell_x
      tile.hd25_slice_cy = tile.hd25_cell_y
      @sliced_row_tiles ||= {}
      list = (@sliced_row_tiles[row] ||= [])
      list << tile
    end

    def forget_sliced_tile(tile)
      return if !tile
      row = tile.hd25_slice_row
      return if row.nil?
      list = @sliced_row_tiles && @sliced_row_tiles[row]
      list.delete(tile) if list
      tile.hd25_slice_row = nil
    end

    # Mismo trapecio que el camino pri0 sin franjas: ancho del borde de
    # abajo, estrecho arriba con el taper de la fila.
    def place_full_ground_trapezoid(tile, cell_row, left)
      scale = row_width_scale(cell_row)
      near_scale = TAPER_SUPPORTED ? row_width_scale(cell_row + 1) : scale
      near_scale = scale if !near_scale || near_scale <= 0
      top = row_top(cell_row)
      bottom = row_top(cell_row + 1)
      height = bottom - top
      height = 1 if height < 1
      start = project_x(left, near_scale)
      finish = project_x(left + TilemapRenderer::DISPLAY_TILE_WIDTH, near_scale)
      clear_wall_tile_tilt(tile)
      taper = TAPER_SUPPORTED ? row_taper(cell_row) : 1.0
      apply_tile_taper(tile, taper)
      zoom_y = height / TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
      tile.x = start
      tile.y = top
      wpx = finish - start
      wpx = 1 if wpx < 1
      apply_tile_zoom(tile, wpx / TilemapRenderer::SOURCE_TILE_WIDTH.to_f, zoom_y)
      tile.hd25_proj_stamp = @projection_stamp || 0
      tile.hd25_proj_row = cell_row
      tile.hd25_proj_scale = near_scale
      tile.hd25_proj_y = top
      tile.hd25_proj_zy = zoom_y
      tile.hd25_proj_side = 0
      tile.hd25_proj_wpx = wpx
    end

    def ground_tile_sliceable?(tile)
      field = tile.hd25_walls
      if field && !field.flat
        cx = tile.hd25_cell_x
        cy = tile.hd25_cell_y
        if !cx.nil? && !cy.nil?
          return false if field.lifted?(cx, cy) || field.lateral_step?(cx, cy)
          return false if wall_side_seal_px(field, cx, cy, tile.hd25_skip_wall_seal) > 0
        end
      end
      return false if (tile.ox != 0 || tile.oy != 0) && !tile.hd25_tilting
      return true
    end

    def tile_forces_flat_row?(tile)
      cached = tile.hd25_forces_flat
      return cached unless cached.nil?
      result = compute_tile_forces_flat_row?(tile)
      tile.hd25_forces_flat = result
      return result
    end

    def compute_tile_forces_flat_row?(tile)
      return true if tile.hd25_skip_wall_seal
      return true if tile.opacity && tile.opacity > 0 && tile.opacity < 255
      surf = tile.respond_to?(:hd25_surf_graphic) ? tile.hd25_surf_graphic : tile.instance_variable_get(:@hd25_surf_graphic)
      return true if surf
      return true if water_graphic_name?(tile)
      return tile_body_transparent?(tile)
    end

    def water_graphic_name?(tile)
      name = tile.filename.to_s
      return false if name.empty?
      return !!(name =~ /agua|water|sea|ocean|cascada|waterfall|lago|rio|waves|alga/i)
    end

    # Un pixel semitransparente en el interior basta: el solape de las
    # franjas se ve ahí. Alpha 0 (esquina vacía) no cuenta. No se cachea
    # un "no" si la muestra cayó fuera del bitmap.
    def tile_body_transparent?(tile)
      bmp = tile.bitmap
      return false if !bmp || bmp.disposed?
      sr = tile.src_rect
      return false if !sr
      cache = @flat_graphic_cache ||= {}
      autotile = tile.respond_to?(:is_autotile) && tile.is_autotile
      if autotile
        key = [bmp.object_id, sr.y, :frames]
        return cache[key] if cache.key?(key)
        found = false
        seen = false
        x = 0
        step = TilemapRenderer::SOURCE_TILE_WIDTH
        while x + step <= bmp.width
          kind = cell_transparency(bmp, x, sr.y)
          if kind == :transparent
            found = true
            seen = true
            break
          elsif kind == :opaque
            seen = true
          end
          x += step
        end
        cache[key] = found if seen
        return found
      end
      key = [bmp.object_id, sr.x, sr.y]
      return cache[key] if cache.key?(key)
      kind = cell_transparency(bmp, sr.x, sr.y)
      if kind == :empty
        return false
      end
      cache[key] = (kind == :transparent)
      return cache[key]
    end

    def cell_transparency(bmp, x0, y0)
      w = TilemapRenderer::SOURCE_TILE_WIDTH
      h = TilemapRenderer::SOURCE_TILE_HEIGHT
      return :empty if x0 < 0 || y0 < 0 || (x0 + w) > bmp.width || (y0 + h) > bmp.height
      semi = false
      visible = false
      yy = 8
      while yy <= 20
        xx = 8
        while xx <= 20
          a = bmp.get_pixel(x0 + xx, y0 + yy).alpha
          visible = true if a > 0
          semi = true if a > 0 && a < 250
          xx += 4
        end
        yy += 4
      end
      return :empty if !visible
      return :transparent if semi
      return :opaque
    end

    def reposition_ground_slices_x(tile, left)
      slices = tile.hd25_slices
      return if !slices
      dw = TilemapRenderer::DISPLAY_TILE_WIDTH
      sw = TilemapRenderer::SOURCE_TILE_WIDTH.to_f
      slices.each do |spr|
        next if !spr || spr.disposed? || !spr.bitmap
        return false if !spr.is_a?(GroundStrip)
        scale = spr.hd25_near
        next if !scale || scale <= 0
        start = project_x(left, scale)
        finish = project_x(left + dw, scale)
        spr.x = start
        wpx = finish - start
        wpx = 1 if wpx < 1
        next if spr.hd25_wpx == wpx
        spr.hd25_wpx = wpx
        zy = spr.hd25_zy || 1.0
        apply_strip_zoom(spr, tile, wpx / sw, zy)
      end
      return true
    end

    def bind_ground_strip(spr, tile)
      bmp = tile.bitmap
      if spr.bitmap != bmp
        spr.bitmap = bmp
        spr.tone = tile.tone
        spr.color = tile.color
        spr.viewport = tile.viewport if spr.viewport != tile.viewport
        spr.ox = 0 if spr.ox != 0
        spr.oy = 0 if spr.oy != 0
        spr.angle = 0 if spr.angle != 0
        if tile.respond_to?(:mirror) && spr.respond_to?(:mirror=) && spr.mirror != tile.mirror
          spr.mirror = tile.mirror
        end
        spr.blend_type = tile.blend_type if spr.blend_type != tile.blend_type
      end
      op = tile.opacity
      spr.opacity = op if spr.opacity != op
      vis = !!(tile.visible && bmp)
      spr.visible = vis if spr.visible != vis
      z = tile.z
      spr.z = z if spr.z != z
    end

    def assign_strip_src(spr, x, y, w, h)
      rect = spr.src_rect
      return if rect.x == x && rect.y == y && rect.width == w && rect.height == h
      rect.x = x
      rect.y = y
      rect.width = w
      rect.height = h
    end

    def apply_strip_taper(spr, value)
      value = 1.0 if !value || value <= 0
      apply_tile_taper(spr, value)
    end

    def apply_strip_zoom(spr, tile, zoom_x, zoom_y)
      if spr.equal?(tile)
        apply_tile_zoom(tile, zoom_x, zoom_y)
        return
      end
      if tile.hd25_base_zoom_x
        zoom_x *= tile.hd25_base_zoom_x / TilemapRenderer::ZOOM_X.to_f
        zoom_y *= tile.hd25_base_zoom_y / TilemapRenderer::ZOOM_Y.to_f
      end
      zoom_x = quant_zoom(zoom_x)
      zoom_y = quant_zoom(zoom_y)
      prev_x = spr.hd25_zx
      if !prev_x || (prev_x - zoom_x).abs > ZOOM_EPS || (spr.zoom_x - zoom_x).abs > ZOOM_EPS
        spr.zoom_x = zoom_x
        spr.hd25_zx = zoom_x
      end
      prev_y = spr.hd25_zy_applied
      if !prev_y || (prev_y - zoom_y).abs > ZOOM_EPS || (spr.zoom_y - zoom_y).abs > ZOOM_EPS
        spr.zoom_y = zoom_y
        spr.hd25_zy_applied = zoom_y
      end
    end

    # El borde inferior de un tile de suelo mide lo que su fila, y el superior
    # lo que la fila de detras. Pasarle esa razon al motor lo dibuja como
    # trapecio, y entonces el borde inferior de una fila cae EXACTAMENTE sobre
    # el superior de la de detras: se acaban los escalones que obligaban a
    # mantener VANISHING_STRENGTH bajo.
    def apply_tile_taper(tile, value)
      return if !TAPER_SUPPORTED
      value = 1.0 if !value || value <= 0
      return if tile.hd25_taper && (tile.hd25_taper - value).abs <= ZOOM_EPS
      tile.taper = value
      tile.hd25_taper = value
    end

    def clear_tile_depth(tile)
      if tile.hd25_row_batched
        release_ground_row_member(tile)
        if tile.bitmap && !tile.disposed?
          tile.visible = true if !tile.visible
        end
      end
      if tile.hd25_culled
        tile.hd25_culled = false
        if tile.bitmap && !tile.disposed?
          tile.visible = true if !tile.visible
        end
      end
      release_ground_slices(tile)
      clear_wall_tile_tilt(tile)
      apply_tile_taper(tile, 1.0)
      tile.hd25_proj_stamp = nil
      if tile.hd25_zoom_x || tile.hd25_zoom_y
        tile.zoom_x = tile.hd25_base_zoom_x || TilemapRenderer::ZOOM_X
        tile.zoom_y = tile.hd25_base_zoom_y || TilemapRenderer::ZOOM_Y
        tile.hd25_zoom_x = nil
        tile.hd25_zoom_y = nil
      end
    end

    # Z del modo 2D (Essentials / MakerStudio cap-model). Sin Z_LIFT ni columna
    # 2.5D: si no, al apagar el modo las capas se pintan en orden incorrecto.
    def restore_tile_z_2d(tile, row = nil, pixel_offset_y = nil)
      return if !tile || (tile.respond_to?(:disposed?) && tile.disposed?)
      return if tile.shows_reflection
      return if tile.bridge && $PokemonGlobal && $PokemonGlobal.bridge > 0
      th = TilemapRenderer::SOURCE_TILE_HEIGHT
      off = pixel_offset_y
      if off.nil?
        renderer = ($scene.is_a?(Scene_Map) && $scene.respond_to?(:map_renderer)) ? $scene.map_renderer : nil
        off = renderer.instance_variable_get(:@pixel_offset_y) if renderer && !renderer.disposed?
      end
      off = 0 if off.nil?
      if tile.respond_to?(:cell_band) && !tile.cell_band.nil?
        band = tile.cell_band.to_i
        if band <= 0
          z = tile.respond_to?(:ms_ground_z) ? (tile.ms_ground_z || 0) : 0
          z += tile.ext_z_offset if tile.respond_to?(:ext_z_offset) && tile.ext_z_offset
          tile.z = z
        elsif !row.nil?
          # Misma cuenta que MakerStudio#ms_overhead_tile_z.
          z = (row * th) + (band * th) + th + 1 - off
          z += tile.ext_z_offset if tile.respond_to?(:ext_z_offset) && tile.ext_z_offset
          tile.z = z
        elsif tile.z && tile.z >= Z_LIFT
          tile.z = tile.z - Z_LIFT
        end
        return
      end
      priority = tile.priority.to_i
      if priority <= 0
        tile.z = 0
      elsif !row.nil?
        tile.z = (row * th) + (priority * th) + th + 1 - off
      elsif tile.z && tile.z >= Z_LIFT
        tile.z = tile.z - Z_LIFT
      end
    end
  end
end
