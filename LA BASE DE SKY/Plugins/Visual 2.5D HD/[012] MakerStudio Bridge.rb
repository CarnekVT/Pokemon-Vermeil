#===============================================================================
# Visual 2.5D HD - Puente con MakerStudio
#-------------------------------------------------------------------------------
# MakerStudio dibuja sus capas extendidas (3, 4, 5...) con un pool de sprites
# propio, al margen de la rejilla del motor: les escribe la posicion a mano y no
# pasa nunca por refresh_tile_coordinates, que es donde el plugin proyecta los
# tiles nativos. Sin esto, un mapa con capas de MakerStudio dibuja esas capas
# planas sobre un suelo en perspectiva.
#
# Prioridades (v3.0.4):
#   2.5D ON: geom/Z = prioridad PINTADA (hd25_painted_priority), no cell_band.
#   2.5D OFF: skip/scroll 2D del pool (idle + pixel); restore una vez al apagar.
#             No tocar priority/Z en el bind; cap-model MS.
#   Margen de rejilla = 0 en 2D (si no, ms_overhead_tile_z ≠ screen_z jugador).
#
# Orden: el pool extended corre DESPUES de restore_maps_after_render. Las
# casillas tile_x/y son coords reales de mapa (igual que WallField). Los nativos
# enlazan dentro del shift; map_tile_offset no debe re-sumar el margen.
#===============================================================================
if defined?(MakerStudio) && TilemapRenderer.method_defined?(:update_extended_pool)
  class TilemapRenderer
    # Los efectos por tile de MakerStudio pueden escalar un sprite. Se anota el
    # zoom que deja, para que la proyeccion lo multiplique en vez de borrarlo.
    def hd25_record_base_zoom(sprite)
      return if sprite.disposed?
      if sprite.zoom_x == TilemapRenderer::ZOOM_X && sprite.zoom_y == TilemapRenderer::ZOOM_Y
        sprite.hd25_base_zoom_x = nil
        sprite.hd25_base_zoom_y = nil
      else
        sprite.hd25_base_zoom_x = sprite.zoom_x
        sprite.hd25_base_zoom_y = sprite.zoom_y
      end
      sprite.hd25_zoom_x = nil
      sprite.hd25_zoom_y = nil
      @hd25_ext_proj_dirty = true
    end

    alias hd25_bind_ext_pool_sprite bind_ext_pool_sprite unless method_defined?(:hd25_bind_ext_pool_sprite)
    def bind_ext_pool_sprite(sprite, map, layer, slot, tile_data, tile_x, tile_y)
      # Antes del bind MS: geom vieja haria que z= del suelo aplicara Z_LIFT.
      sprite.hd25_geom_priority = nil
      sprite.hd25_painted_priority = nil
      sprite.hd25_ext_px = nil
      @hd25_ext_proj_dirty = true
      hd25_bind_ext_pool_sprite(sprite, map, layer, slot, tile_data, tile_x, tile_y)
      # Casilla siempre (hace falta al activar 2.5D sin re-bind).
      sprite.hd25_map_id = map.map_id
      sprite.hd25_cell_x = tile_x
      sprite.hd25_cell_y = tile_y
      field = Visual25D.wall_field(map)
      field = nil if field&.flat
      sprite.hd25_walls = field
      sprite.hd25_lifted = field ? field.lifted?(tile_x, tile_y) : false
      sprite.hd25_grid_row = nil
      Visual25D.annotate_wall_seal_skip!(sprite, map)
      ext_tid = tile_data ? tile_data["tile_id"] : (sprite.respond_to?(:tile_id) ? sprite.tile_id : nil)
      Visual25D.annotate_surf_graphic!(sprite, map, ext_tid)
      Visual25D.annotate_interior_flat!(sprite, map)
      Visual25D.annotate_shelf_flat!(sprite, map, ext_tid, tile_data)
      # En 2D puro no tocar priority/Z: deja el cap-model de MakerStudio.
      if !Visual25D.enabled?
        Visual25D.clear_tile_depth(sprite)
        return
      end
      if sprite.hd25_interior_flat
        sprite.priority = 0
        sprite.hd25_painted_priority = 0
        Visual25D.assign_geom_priority(sprite, 0)
        hd25_record_base_zoom(sprite)
        return
      end
      if tile_data && sprite.bitmap
        tid = tile_data["tile_id"].to_i
        own_pri = MakerStudio.resolve_band_priority(map, tid, tile_data)
        # Por si el tileset live dice 0 pero el dato pintado trae prioridad.
        if tile_data["priority"]
          baked = tile_data["priority"].to_i
          own_pri = baked if baked > own_pri
        end
        sprite.priority = own_pri
        sprite.hd25_painted_priority = own_pri
        Visual25D.assign_geom_priority(sprite, own_pri)
      else
        sprite.hd25_painted_priority = 0
        Visual25D.assign_geom_priority(sprite, 0)
      end
      # Shelf: solo ESTA capa (tag 21). geom 0 (no columna); pri se conserva para Z.
      if sprite.hd25_shelf_flat
        # Cota de ESTA capa, no la que el sprite tenia antes de reciclarse.
        own = sprite.priority.to_i
        g = sprite.hd25_geom_priority.to_i
        own = g if g > own
        if own < 1
          own = Visual25D.shelf_priority_for(map, ext_tid, tile_data)
        end
        sprite.hd25_shelf_own_pri = own
        sprite.hd25_shelf_height = Visual25D.shelf_height_for(
          sprite, map, tile_x, tile_y, own)
        sprite.priority = own if own > sprite.priority.to_i
        sprite.hd25_painted_priority = 0
        Visual25D.assign_geom_priority(sprite, 0)
      end
      hd25_record_base_zoom(sprite)
    end

    alias hd25_bind_native_prop_tile bind_native_prop_tile unless method_defined?(:hd25_bind_native_prop_tile)
    def bind_native_prop_tile(tile, props, has_effects, map, table_tile_id)
      hd25_bind_native_prop_tile(tile, props, has_effects, map, table_tile_id)
      hd25_record_base_zoom(tile)
    end

    # Tras el bind MS (cell_band ya resuelto): geom = prioridad pintada, no band.
    # defer_tile_project: coords no proyecta; aqui una sola vez con geom lista.
    alias hd25_ms_refresh_tile refresh_tile unless method_defined?(:hd25_ms_refresh_tile)
    def refresh_tile(tile, x, y, map, layer, tile_id)
      # Solo diferir si este metodo va a proyectar al final (MS ON + 2.5D ON).
      defer = MakerStudio::ENABLED && Visual25D.enabled?
      Visual25D.defer_tile_project = true if defer
      begin
        hd25_ms_refresh_tile(tile, x, y, map, layer, tile_id)
      ensure
        Visual25D.defer_tile_project = false
      end
      return if !MakerStudio::ENABLED || !tile || !map
      # Nunca bajar de tile.priority: resolve bajo el ground-cap puede devolver 0
      # aunque el sprite ya tenga pri>=1 → geom=0 → Z de suelo hasta scroll Y.
      own_pri = tile.priority.to_i
      props = nil
      if tile.respond_to?(:map_x) && !tile.map_x.nil? && !tile.map_y.nil?
        idx = (tile.map_y.to_i * map.width) + tile.map_x.to_i
        entry = MakerStudio.native_props_at(map.map_id, map.width, layer, idx)
        props = entry ? entry[0] : nil
        resolved = MakerStudio.resolve_band_priority(map, tile.tile_id.to_i, props)
        own_pri = resolved if resolved > own_pri
        if props && props["priority"]
          baked = props["priority"].to_i
          own_pri = baked if baked > own_pri
        end
      end
      tile.hd25_painted_priority = own_pri
      Visual25D.assign_geom_priority(tile, own_pri)
      # MS acaba de pintar pri: reafirmar InteriorWall flat (si no, columna frontal).
      if tile.hd25_interior_flat
        tile.hd25_painted_priority = 0
        Visual25D.assign_geom_priority(tile, 0)
      end
      # Shelf: re-anotar con el tile_id / props de ESTA capa (no la casilla).
      if Visual25D.tile_is_shelf?(map, tile.tile_id, props)
        tile.hd25_shelf_flat = true
        # own_pri ya es la prioridad de este tile (bitmap ya actualizado).
        # No subirla con hd25_shelf_own_pri: era la cota del sprite reciclado.
        if own_pri < 1
          own_pri = Visual25D.shelf_priority_for(map, tile.tile_id, props)
        end
        tile.hd25_shelf_own_pri = own_pri
        tile.hd25_shelf_height = Visual25D.shelf_height_for(
          tile, map, tile.hd25_cell_x, tile.hd25_cell_y, own_pri)
        tile.priority = own_pri if own_pri > tile.priority.to_i
        tile.hd25_painted_priority = 0
        Visual25D.assign_geom_priority(tile, 0)
      else
        tile.hd25_shelf_flat = false
        tile.hd25_shelf_own_pri = 0
      end
      return if !Visual25D.enabled?
      # Origen plano de rejilla (coords diferidas: x/y aun planos o con ox MS).
      tile.x = (x * DISPLAY_TILE_WIDTH) - @pixel_offset_x
      tile.y = (y * DISPLAY_TILE_HEIGHT) - @pixel_offset_y
      case Visual25D.screen_cull_tile(tile, y, tile.x)
      when :off
        Visual25D.release_ground_row_member(tile)
        return
      end
      if Visual25D.offer_ground_row!(tile, y, tile.x)
        return
      end
      Visual25D.project_tile(tile, y)
      # Shelf / InteriorWall: project_*_cap ya escribio Z (geom 0 no debe tumbarlo).
      Visual25D.project_tile_z_selective(tile, y, layer, @pixel_offset_y)
      if tile.ox != 0 || tile.oy != 0
        tile.x += (tile.ox * tile.zoom_x.abs).round
        tile.y += (tile.oy * tile.zoom_y.abs).round
      end
    end

    alias hd25_update_extended_pool update_extended_pool unless method_defined?(:hd25_update_extended_pool)
    def update_extended_pool
      if !Visual25D.enabled?
        hd25_update_extended_pool_2d
        return
      end
      # Salir de 2D: forzar proyectar; no reusar coords planas.
      if @hd25_ext_2d_ready
        @hd25_ext_2d_ready = false
        @hd25_ext_proj_dirty = true
      end
      map = $game_map
      dx = map ? map.display_x : nil
      dy = map ? map.display_y : nil
      stamp = Visual25D.projection_stamp
      off_y = @pixel_offset_y
      # Idle: sin rebuild MS.
      if Visual25D::Config::MS_EXT_IDLE_SKIP &&
         hd25_ext_idle_can_skip?(dx, dy, off_y, stamp)
        hd25_ext_idle_keep!
        return
      end
      # Scroll sub-tile: sin rebuild MS (mismo dx_tile/dy_tile). N/S proyecta
      # entero (no y_flat): rebuild cada pixel al correr hitchaba y arrastraba
      # los pri>0.
      if Visual25D::Config::MS_EXT_PIXEL_SCROLL &&
         hd25_ext_try_pixel_scroll!(dx, dy)
        return
      end
      hd25_update_extended_pool
      Visual25D.perf_tick(:ext_reapply)
      @hd25_ext_anim_none = nil
      Visual25D.prime_map_offsets!
      Visual25D.update_projection(@pixel_offset_y)
      off_y = @pixel_offset_y
      stamp = Visual25D.projection_stamp
      n = @ext_visible.length
      x_only = !@screen_moved_vertically &&
               @hd25_ext_dy == dy && @hd25_ext_stamp == stamp &&
               @hd25_ext_off_y == off_y && !@hd25_ext_proj_dirty
      @hd25_ext_proj_dirty = false
      @hd25_ext_dx = dx
      @hd25_ext_dy = dy
      @hd25_ext_off_y = off_y
      @hd25_ext_stamp = stamp
      @hd25_ext_n = n
      @ext_visible.each do |sprite|
        Visual25D.perf_tick(:ext_proj)
        if x_only
          Visual25D.project_ext_sprite_scroll_x(sprite, off_y)
        else
          Visual25D.project_ext_sprite(sprite, off_y)
        end
        Visual25D.cache_ext_proj!(sprite)
      end
      hd25_ext_store_tile_sig!
    end

    # Idle: pool ya proyectado, sin scroll ni refresh.
    def hd25_ext_idle_can_skip?(dx, dy, off_y, stamp)
      return false if @hd25_ext_proj_dirty
      return false if @need_refresh
      return false if @screen_moved || @screen_moved_vertically
      return false if Visual25D.force_reproject_pending?
      return false if !@ext_visible || @ext_visible.empty?
      return false if !@hd25_ext_n || @hd25_ext_n <= 0
      return false if @hd25_ext_dx != dx || @hd25_ext_dy != dy
      return false if @hd25_ext_off_y != off_y || @hd25_ext_stamp != stamp
      return false if @hd25_ext_n != @ext_visible.length
      spr = @ext_visible[0]
      return false if !spr || spr.disposed? || !spr.hd25_ext_px
      return true
    end

    def hd25_ext_idle_keep!
      Visual25D.perf_tick(:ext_idle)
      hd25_ext_sync_tone_color!
      hd25_ext_animate_autotiles!
      hd25_ext_store_tile_sig! if !@hd25_ms_tile_sig || @hd25_ms_tile_sig.empty?
    end

    # 2.5D OFF: skip/scroll del pool MS. restore_ext_sprite_2d solo al
    # bajar de 2.5D, no cada frame (mapa 205: miles de sprites).
    def hd25_update_extended_pool_2d
      map = $game_map
      dx = map ? map.display_x : nil
      dy = map ? map.display_y : nil
      off_x = @pixel_offset_x
      off_y = @pixel_offset_y
      unless @hd25_ext_2d_ready
        hd25_update_extended_pool
        @ext_visible.each { |sprite| Visual25D.restore_ext_sprite_2d(sprite) }
        hd25_ext_2d_commit!(dx, dy, off_x, off_y)
        @hd25_ext_2d_ready = true
        return
      end
      if Visual25D::Config::MS_EXT_IDLE_SKIP && hd25_ext_2d_idle_can_skip?(dx, dy, off_x, off_y)
        hd25_ext_idle_keep!
        return
      end
      if Visual25D::Config::MS_EXT_PIXEL_SCROLL && hd25_ext_try_pixel_scroll_2d!(dx, dy)
        return
      end
      hd25_update_extended_pool
      hd25_ext_2d_commit!(dx, dy, off_x, off_y)
    end

    def hd25_ext_2d_commit!(dx, dy, off_x, off_y)
      @hd25_ext_dx = dx
      @hd25_ext_dy = dy
      @hd25_ext_off_x = off_x
      @hd25_ext_off_y = off_y
      @hd25_ext_n = @ext_visible ? @ext_visible.length : 0
      @hd25_ext_proj_dirty = false
      hd25_ext_store_tile_sig!
    end

    def hd25_ext_2d_idle_can_skip?(dx, dy, off_x, off_y)
      return false if @need_refresh
      return false if @screen_moved || @screen_moved_vertically
      return false if @hd25_ext_dx != dx || @hd25_ext_dy != dy
      return false if @hd25_ext_off_x != off_x || @hd25_ext_off_y != off_y
      return false if @hd25_ms_grid_sig != hd25_ext_grid_sig
      n = @ext_visible ? @ext_visible.length : 0
      return false if @hd25_ext_n != n
      true
    end

    # Igual que hd25_ext_try_pixel_scroll! sin project_tile.
    def hd25_ext_try_pixel_scroll_2d!(dx, dy)
      return false if @need_refresh
      return false if !@ext_pool_ready
      return false if !@screen_moved && !@screen_moved_vertically
      return false if !@ext_visible || @ext_visible.empty?
      return false if !@hd25_ext_n || @hd25_ext_n <= 0
      return false if !@hd25_ms_tile_sig || @hd25_ms_tile_sig.empty?
      return false if !$map_factory
      return false if @hd25_ms_grid_sig != hd25_ext_grid_sig
      if @hd25_ext_dx && @hd25_ext_dy && dx && dy
        lim = Game_Map::REAL_RES_X
        return false if (dx - @hd25_ext_dx).abs > lim || (dy - @hd25_ext_dy).abs > lim
      end
      tw = TilemapRenderer::DISPLAY_TILE_WIDTH
      th = TilemapRenderer::DISPLAY_TILE_HEIGHT
      tile_info = hd25_ext_pixel_tile_info(tw, th)
      return false if !tile_info
      y_scroll = @screen_moved_vertically
      updated = 0
      @ext_visible.each do |sprite|
        next if !sprite || sprite.disposed? || !sprite.bitmap
        info = tile_info[sprite.map_id]
        return false if !info
        dx_tile = info[0]
        dy_tile = info[1]
        pox = info[2]
        poy = info[3]
        flat_x = ((sprite.map_x - dx_tile) * tw) - pox
        flat_y = ((sprite.map_y - dy_tile) * th) - poy
        if sprite.ox != 0 || sprite.oy != 0
          bx = sprite.hd25_base_zoom_x || TilemapRenderer::ZOOM_X
          by = sprite.hd25_base_zoom_y || TilemapRenderer::ZOOM_Y
          sprite.zoom_x = bx
          sprite.zoom_y = by
          sprite.x = flat_x + (sprite.ox * bx.abs).round
          sprite.y = flat_y + (sprite.oy * by.abs).round
        else
          sprite.x = flat_x
          sprite.y = flat_y
        end
        band = sprite.cell_band
        if y_scroll && band && band > 0 && respond_to?(:ms_overhead_tile_z)
          z = ms_overhead_tile_z(sprite.map_y - dy_tile, band) + (sprite.ext_z_offset || 0)
          sprite.z = z if sprite.z != z
        end
        Visual25D.perf_tick(:ext_fast)
        updated += 1
      end
      return false if updated != @ext_visible.length
      hd25_ext_sync_tone_color!
      hd25_ext_animate_autotiles!
      hd25_ext_2d_commit!(dx, dy, @pixel_offset_x, @pixel_offset_y)
      true
    end

    def hd25_ext_sync_tone_color!
      if @tone && @ext_old_tone != @tone
        @ext_old_tone = @tone.clone
        @ext_visible.each do |spr|
          next if !spr || spr.disposed?
          spr.tone = ms_tone_with_light(spr.ms_light) if respond_to?(:ms_tone_with_light)
        end
      end
      if @color && @ext_old_color != @color
        @ext_old_color = @color.clone
        @ext_visible.each do |spr|
          next if !spr || spr.disposed?
          spr.color = @color
        end
      end
    end

    def hd25_ext_animate_autotiles!
      return if !@autotiles
      return if @hd25_ext_anim_none
      any = false
      @ext_visible.each do |sprite|
        next if !sprite || sprite.disposed? || !sprite.visible
        next if !sprite.animated
        any = true
        @autotiles.set_src_rect(sprite, sprite.ms_src_id || sprite.tile_id)
        if sprite.hd25_slice_n.to_i > 1
          Visual25D.sync_ground_slice_frame(sprite)
        end
      end
      # ponytail: sin animated en el pool → no reescanear hasta rebuild.
      @hd25_ext_anim_none = !any
    end

    # Guarda dx_tile/dy_tile + firma de rejilla V25D (pool stale si cambia).
    def hd25_ext_store_tile_sig!
      @hd25_ms_tile_sig = {}
      @hd25_ms_grid_sig = hd25_ext_grid_sig
      return if !$map_factory
      $map_factory.maps.each do |map|
        next unless map&.instance_variable_get(:@map)
        offs = ms_tile_offsets(map)
        @hd25_ms_tile_sig[map.map_id] = [offs[0], offs[1]]
      end
    end

    # Contadores nativos + márgenes: si cambian, ext_pool/@ext_visible quedan cortos.
    def hd25_ext_grid_sig
      return [@tiles_horizontal_count, @tiles_vertical_count,
              Visual25D.margin_columns, Visual25D.margin_rows]
    end

    # Scroll dentro de la misma casilla de display: sin rebuild MS.
    # true = path aplicado; false = caer a rebuild completo.
    def hd25_ext_try_pixel_scroll!(dx, dy)
      return false if @hd25_ext_proj_dirty || @need_refresh
      return false if !@ext_pool_ready
      return false if Visual25D.force_reproject_pending?
      return false if !@screen_moved && !@screen_moved_vertically
      return false if !@ext_visible || @ext_visible.empty?
      return false if !@hd25_ext_n || @hd25_ext_n <= 0
      return false if !@hd25_ms_tile_sig || @hd25_ms_tile_sig.empty?
      return false if !$map_factory
      # ponytail: margen V25D / tamaño pool distinto → rebuild (evita cortes E/O).
      return false if @hd25_ms_grid_sig != hd25_ext_grid_sig
      # Carrera / turbo / bajón de FPS: más de un tile por frame. El path
      # pixel asume el mismo dx_tile y deja capas MS fuera de sitio.
      if @hd25_ext_dx && @hd25_ext_dy && dx && dy
        lim = Game_Map::REAL_RES_X
        return false if (dx - @hd25_ext_dx).abs > lim || (dy - @hd25_ext_dy).abs > lim
      end
      tw = TilemapRenderer::DISPLAY_TILE_WIDTH
      th = TilemapRenderer::DISPLAY_TILE_HEIGHT
      # Reusar tile_info si display no cruzó casilla (misma sig).
      tile_info = hd25_ext_pixel_tile_info(tw, th)
      return false if !tile_info
      Visual25D.prime_map_offsets!
      Visual25D.update_projection(@pixel_offset_y)
      off_y = @pixel_offset_y
      stamp = Visual25D.projection_stamp
      y_scroll = @screen_moved_vertically
      updated = 0
      @ext_visible.each do |sprite|
        next if !sprite || sprite.disposed? || !sprite.bitmap
        info = tile_info[sprite.map_id]
        # Mapa ya no en factory / sin offs → pool stale.
        return false if !info
        dx_tile = info[0]
        dy_tile = info[1]
        pox = info[2]
        poy = info[3]
        # Coords planas MS (= nativo tras cancelar margen V25D en pixel_offset).
        flat_x = ((sprite.map_x - dx_tile) * tw) - pox
        flat_y = ((sprite.map_y - dy_tile) * th) - poy
        # Suelo en N/S: misma vía corta que el tile nativo. project_tile
        # entero en cada pixel es lo que traba al andar en vertical.
        if y_scroll
          Visual25D.ensure_ext_geom!(sprite)
          if Visual25D.tile_can_yflat?(sprite)
            sprite.x = flat_x
            sprite.y = flat_y
            row = Visual25D.ext_grid_row(sprite, flat_y)
            if row
              sprite.hd25_grid_row = row
              case Visual25D.screen_cull_tile(sprite, row, flat_x)
              when :off
                updated += 1
                next
              when :full
                # Acaba de entrar: project_ext_sprite, no el atajo y_flat.
              else
                Visual25D.project_tile_scroll_y_flat(sprite, row)
                if sprite.ox != 0 || sprite.oy != 0
                  sprite.x += (sprite.ox * sprite.zoom_x.abs).round
                  sprite.y += (sprite.oy * sprite.zoom_y.abs).round
                end
                Visual25D.apply_ext_sprite_z(sprite, row, off_y)
                Visual25D.perf_tick(:ext_fast)
                Visual25D.cache_ext_proj!(sprite)
                updated += 1
                next
              end
            end
          end
        end
        # Zoom BASE siempre: si se deja el proyectado, unprojected_origin /
        # ox en pri>0 arrastra al correr N/S.
        bx = sprite.hd25_base_zoom_x || TilemapRenderer::ZOOM_X
        by = sprite.hd25_base_zoom_y || TilemapRenderer::ZOOM_Y
        sprite.zoom_x = bx
        sprite.zoom_y = by
        Visual25D.invalidate_tile_zoom!(sprite)
        if sprite.ox != 0 || sprite.oy != 0
          sprite.x = flat_x + (sprite.ox * bx.abs).round
          sprite.y = flat_y + (sprite.oy * by.abs).round
        else
          sprite.x = flat_x
          sprite.y = flat_y
        end
        Visual25D.perf_tick(:ext_fast)
        if y_scroll
          Visual25D.project_ext_sprite(sprite, off_y)
        else
          Visual25D.project_ext_sprite_scroll_x(sprite, off_y)
        end
        Visual25D.cache_ext_proj!(sprite)
        updated += 1
      end
      return false if updated != @ext_visible.length
      hd25_ext_sync_tone_color!
      hd25_ext_animate_autotiles!
      @hd25_ext_proj_dirty = false
      @hd25_ext_dx = dx
      @hd25_ext_dy = dy
      @hd25_ext_off_y = off_y
      @hd25_ext_stamp = stamp
      @hd25_ext_n = @ext_visible.length
      hd25_ext_store_tile_sig!
      return true
    end

    # [dx_tile, dy_tile, pox, poy] por map_id. nil → hay que rebuild.
    def hd25_ext_pixel_tile_info(tw, th)
      info = {}
      $map_factory.maps.each do |map|
        next unless map&.instance_variable_get(:@map)
        offs = ms_tile_offsets(map)
        dx_tile = offs[0]
        dy_tile = offs[1]
        prev = @hd25_ms_tile_sig[map.map_id]
        return nil if !prev
        # Cruce de casilla → hace falta rebind MS.
        return nil if prev[0] != dx_tile || prev[1] != dy_tile
        pox = offs[4] % tw
        poy = offs[5] % th
        info[map.map_id] = [dx_tile, dy_tile, pox, poy]
      end
      return info
    end

    alias hd25_update_shadow_sprites update_shadow_sprites unless method_defined?(:hd25_update_shadow_sprites)
    def update_shadow_sprites
      hd25_update_shadow_sprites
      return if !Visual25D.enabled? || !Visual25D::Config::PROJECT_SHADOWS
      return if @last_visible_shadows.empty?
      Visual25D.update_projection(@pixel_offset_y)
      @last_visible_shadows.each { |sprite| Visual25D.project_ground_sprite(sprite) }
    end
  end

  module Visual25D
    class << self
      # Deshace ox/oy MS. Out-params en ivars (sin Array por sprite).
      def unprojected_origin(sprite)
        x = sprite.x
        y = sprite.y
        if sprite.ox != 0 || sprite.oy != 0
          x -= (sprite.ox * sprite.zoom_x.abs).round
          y -= (sprite.oy * sprite.zoom_y.abs).round
        end
        @hd25_ux = x
        @hd25_uy = y
        return nil
      end

      def cache_ext_proj!(sprite)
        sprite.hd25_ext_px = sprite.x
        sprite.hd25_ext_py = sprite.y
        sprite.hd25_ext_pzx = sprite.zoom_x
        sprite.hd25_ext_pzy = sprite.zoom_y
        sprite.hd25_ext_pz = sprite.z
      end

      # Reafirmar geom pintada solo si hace falta (cell_band no tumba columna).
      def ensure_ext_geom!(sprite)
        if flat_cap?(sprite) && Visual25D.enabled?
          sprite.hd25_painted_priority = 0
          assign_geom_priority(sprite, 0)
          return
        end
        painted = sprite.hd25_painted_priority
        if !painted.nil?
          return if sprite.hd25_geom_priority == painted
          assign_geom_priority(sprite, painted)
        elsif sprite.hd25_geom_priority.nil?
          assign_geom_priority(sprite, sprite.priority.to_i)
        end
      end

      # Capa extended: misma geometria que nativo + Z segun prioridad PINTADA.
      def project_ext_sprite(sprite, pixel_offset_y = nil)
        return if !sprite.bitmap || sprite.disposed?
        ensure_ext_geom!(sprite)
        unprojected_origin(sprite)
        sprite.x = @hd25_ux
        row = ext_grid_row(sprite, @hd25_uy)
        sprite.hd25_grid_row = row
        if screen_cull_tile(sprite, row, @hd25_ux) == :off
          return
        end
        project_tile(sprite, row)
        apply_ext_sprite_z(sprite, row, pixel_offset_y) if pixel_offset_y
        if sprite.ox != 0 || sprite.oy != 0
          sprite.x += (sprite.ox * sprite.zoom_x.abs).round
          sprite.y += (sprite.oy * sprite.zoom_y.abs).round
        end
      end

      # Scroll E/O: reusa Y/scale del stamp (nativo project_tile_scroll_x).
      # Skip Z si stamp/fila estables (Z = f(row,pri), no cambia en E/O).
      def project_ext_sprite_scroll_x(sprite, pixel_offset_y = nil)
        return if !sprite.bitmap || sprite.disposed?
        ensure_ext_geom!(sprite)
        has_o = (sprite.ox != 0 || sprite.oy != 0)
        if has_o
          unprojected_origin(sprite)
          left = @hd25_ux
          uy = @hd25_uy
        else
          left = sprite.x
          uy = sprite.y
        end
        row = sprite.hd25_grid_row
        row = ext_grid_row(sprite, uy) if row.nil?
        sprite.hd25_grid_row = row
        cull = screen_cull_tile(sprite, row, left)
        if cull == :off
          return
        end
        if cull == :full
          sprite.x = left
          project_tile(sprite, row)
          apply_ext_sprite_z(sprite, row, pixel_offset_y) if pixel_offset_y
          if has_o
            sprite.x += (sprite.ox * sprite.zoom_x.abs).round
            sprite.y += (sprite.oy * sprite.zoom_y.abs).round
          end
          return
        end
        stamp = @projection_stamp || 0
        if sprite.hd25_proj_stamp == stamp && sprite.hd25_proj_row == row &&
           sprite.hd25_proj_scale
          perf_tick(:xhit)
          scale = sprite.hd25_proj_scale
          side = sprite.hd25_proj_side || 0
          dw = TilemapRenderer::DISPLAY_TILE_WIDTH
          start = project_x(left, scale)
          finish = project_x(left + dw, scale)
          if side > 0
            start -= side
            finish += side
          end
          wpx = finish - start
          sprite.x = start
          sprite.y = sprite.hd25_proj_y
          # Pixel-scroll con ox deja zoom base; recuperar proyectado cacheado.
          if sprite.hd25_zoom_x
            sprite.zoom_x = sprite.hd25_zoom_x
            sprite.zoom_y = sprite.hd25_zoom_y if sprite.hd25_zoom_y
          end
          if sprite.hd25_proj_wpx != wpx
            sprite.hd25_proj_wpx = wpx
            apply_tile_zoom(sprite, wpx / TilemapRenderer::SOURCE_TILE_WIDTH.to_f,
                            sprite.hd25_proj_zy)
          end
          if has_o
            sprite.x += (sprite.ox * sprite.zoom_x.abs).round
            sprite.y += (sprite.oy * sprite.zoom_y.abs).round
          end
          # Z estable en E/O: reaplicar cache. hd25_z_pre_raised evita que
          # TileSprite#z= sume Z_LIFT otra vez (pri1 tapaba al jugador).
          if pixel_offset_y
            if Config::MS_EXT_SKIP_Z_ON_X_SCROLL && sprite.hd25_ext_pz
              sprite.hd25_z_pre_raised = true
              sprite.z = sprite.hd25_ext_pz
            else
              apply_ext_sprite_z(sprite, row, pixel_offset_y)
            end
          end
          return
        end
        sprite.x = left
        project_tile(sprite, row)
        apply_ext_sprite_z(sprite, row, pixel_offset_y) if pixel_offset_y
        if has_o
          sprite.x += (sprite.ox * sprite.zoom_x.abs).round
          sprite.y += (sprite.oy * sprite.zoom_y.abs).round
        end
      end

      # Scroll N/S: project_tile completo. y_flat recicla X/zoom y estira al correr.
      def project_ext_sprite_scroll_y(sprite, pixel_offset_y = nil)
        return if !sprite.bitmap || sprite.disposed?
        ensure_ext_geom!(sprite)
        has_o = (sprite.ox != 0 || sprite.oy != 0)
        if has_o
          unprojected_origin(sprite)
          sprite.x = @hd25_ux
          uy = @hd25_uy
        else
          uy = sprite.y
        end
        row = ext_grid_row(sprite, uy)
        sprite.hd25_grid_row = row
        if screen_cull_tile(sprite, row, sprite.x) == :off
          return
        end
        project_tile(sprite, row)
        apply_ext_sprite_z(sprite, row, pixel_offset_y) if pixel_offset_y
        if has_o
          sprite.x += (sprite.ox * sprite.zoom_x.abs).round
          sprite.y += (sprite.oy * sprite.zoom_y.abs).round
        end
      end

      # 2D: quitar zoom 2.5D y reafirmar Z del cap-model MS.
      # band=0: MS no refresca Z cada frame → forzar 2+slot (orden entre capas).
      # band>0: MS ya escribio ms_overhead este frame; solo retirar Z_LIFT residual.
      def restore_ext_sprite_2d(sprite)
        return if !sprite || sprite.disposed?
        clear_tile_depth(sprite)
        band = sprite.respond_to?(:cell_band) ? sprite.cell_band : nil
        if band && band.to_i > 0
          if sprite.z && sprite.z >= Z_LIFT
            sprite.z = sprite.z - Z_LIFT
          end
          return
        end
        z = 2
        z += sprite.ext_z_offset if sprite.respond_to?(:ext_z_offset) && sprite.ext_z_offset
        sprite.z = z
      end

      # Raised (geom>0): Z de columna Essentials + ext_z_offset.
      # Suelo (geom=0): banda ground MS (2 + slot), sin quedar con Z_LIFT viejo.
      def apply_ext_sprite_z(sprite, row, pixel_offset_y)
        # Shelf / InteriorWall: project_*_cap ya escribio Z raised.
        if flat_cap?(sprite) && Visual25D.enabled?
          apply_flat_cap_z(sprite, row, pixel_offset_y)
          return
        end
        if raised_tile?(sprite)
          project_tile_z(sprite, row, 0, pixel_offset_y)
        else
          z = 2
          z += sprite.ext_z_offset if sprite.respond_to?(:ext_z_offset) && sprite.ext_z_offset
          sprite.z = z
        end
      end

      # Fila de rejilla alineada con el tilemap nativo (incluye margen V25D).
      # Cache de offsets (prime_map_offsets!) — sin getMap por sprite.
      def ext_grid_row(sprite, unprojected_y)
        cy = sprite.hd25_cell_y
        return row_at(unprojected_y) if cy.nil?
        map_id = sprite.hd25_map_id
        map_id = sprite.map_id if map_id.nil? && sprite.respond_to?(:map_id)
        row = grid_row_for_map_cell_id(map_id, cy)
        return row if !row.nil?
        return row_at(unprojected_y)
      end

      # Sombras de MakerStudio: son bitmaps de varias casillas tumbados sobre el
      # suelo, no carteleras. Se recolocan con la escala de su propia fila y sin
      # deformarse: medir el estirado sobre el alto entero del bitmap se dispara
      # en las sombras grandes y las convierte en manchas.
      def project_ground_sprite(sprite)
        return if !sprite.bitmap || sprite.disposed?
        unprojected_origin(sprite)
        x = @hd25_ux
        y = @hd25_uy
        scale = width_scale_at(y)
        sprite.x = project_x(x, scale)
        sprite.y = project_y(y)
        sprite.zoom_x = scale
        sprite.zoom_y = scale
        if sprite.ox != 0 || sprite.oy != 0
          sprite.x += (sprite.ox * scale).round
          sprite.y += (sprite.oy * scale).round
        end
      end
    end
  end
end