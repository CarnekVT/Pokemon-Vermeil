#===============================================================================
# Visual 2.5D HD - Diorama
#-------------------------------------------------------------------------------
# Tres cosas que caben en este motor, sin otro Game.exe:
#
#   - Suelo por filas. Las casillas llanas de una fila de pantalla comparten
#     un trapecio (o GROUND_SLICES franjas). El gráfico se rehace cuando
#     cambia el tile, no en cada píxel de scroll. Cliff, sellos y ox de
#     MakerStudio siguen tile a tile.
#   - Óvalo de contacto bajo el personaje, en el plano del suelo.
#   - Los interruptores de curva, desenfoque y esta fila viven aquí; la curva
#     en sí está en project_y (Core) para que paredes y personajes la sigan.
#===============================================================================

module Visual25D
  class GroundRow
    attr_accessor :key, :layer, :index, :viewport
    attr_accessor :tiles, :sprites, :sig, :dirty
    attr_accessor :blocked, :saw_blocker
    attr_accessor :min_x, :max_x, :flat, :tone_key

    def initialize
      @tiles = {}
      @sprites = []
      @dirty = true
      @blocked = false
      @saw_blocker = false
      @flat = false
      @sig = nil
      @min_x = nil
      @max_x = nil
    end
  end

  class << self
    def row_batch?
      return @row_batch unless @row_batch.nil?
      return Config::ROW_BATCH
    end

    def row_batch=(value)
      @row_batch = value ? true : false
      dispose_ground_rows
      redraw_map
    end

    def band_blur?
      return @band_blur unless @band_blur.nil?
      return Config::BAND_BLUR
    end

    def band_blur=(value)
      @band_blur = value ? true : false
    end

    def row_batch_active?
      return false if !row_batch? || !enabled?
      return true
    end

    def dispose_ground_rows
      rows = @ground_rows
      @ground_rows = nil
      @row_flush_needed = false
      return if !rows
      rows.each_value do |row|
        row.tiles.each_value do |tile|
          next if !tile || tile.disposed?
          tile.hd25_row_batched = false
          tile.hd25_batch_key = nil
          if tile.bitmap && !tile.hd25_culled
            tile.visible = true if !tile.visible
          end
        end
        row.sprites.each do |spr|
          next if !spr || spr.disposed?
          spr.bitmap&.dispose
          spr.dispose
        end
      end
    end

    def release_ground_row_member(tile)
      return if !tile || !tile.hd25_row_batched
      key = tile.hd25_batch_key
      tile.hd25_row_batched = false
      tile.hd25_batch_key = nil
      return if key.nil? || !@ground_rows
      row = @ground_rows[key]
      return if !row
      row.tiles.delete(tile.object_id)
      row.dirty = true
      @row_flush_needed = true
    end

    def touch_ground_row_frame(tile)
      return if !tile || !tile.hd25_row_batched || !@ground_rows
      row = @ground_rows[tile.hd25_batch_key]
      return if !row
      row.dirty = true
      @row_flush_needed = true
    end

    # true = el tile queda oculto y lo dibuja la fila. false = camino normal.
    def offer_ground_row!(tile, row_i, flat_x)
      return false if !row_batch_active?
      return false if tile_blank?(tile) || tile.hd25_culled
      return false if flat_x.nil? || row_i.nil?
      layer = tile.hd25_layer
      return false if layer.nil?
      if !ground_row_candidate?(tile)
        if ground_row_blocker?(tile)
          row = ground_row_for(layer, row_i, tile.viewport)
          row.saw_blocker = true
          row.blocked = true
          @row_flush_needed = true
        end
        release_ground_row_member(tile)
        return false
      end
      row = ground_row_for(layer, row_i, tile.viewport)
      if row.blocked
        release_ground_row_member(tile)
        return false
      end
      key = row.key
      if tile.hd25_row_batched && tile.hd25_batch_key == key
        tile.hd25_batch_flat = flat_x
        tile.hd25_batch_row = row_i
        tile.visible = false if tile.visible
        return true
      end
      release_ground_row_member(tile) if tile.hd25_row_batched
      row.tiles[tile.object_id] = tile
      row.dirty = true
      tile.hd25_row_batched = true
      tile.hd25_batch_key = key
      tile.hd25_batch_flat = flat_x
      tile.hd25_batch_row = row_i
      tile.visible = false if tile.visible
      release_ground_slices(tile) if tile.hd25_slice_n.to_i > 1
      @row_flush_needed = true
      return true
    end

    def ground_row_candidate?(tile)
      return false if tile.shows_reflection || tile.bridge
      return false if flat_cap?(tile)
      return false if tile_maybe_raised?(tile)
      op = tile.opacity
      return false if op && op > 0 && op < 255
      return false if !tile_can_yflat?(tile)
      return false if !ground_tile_sliceable?(tile)
      sr = tile.src_rect
      return false if !sr
      sw = TilemapRenderer::SOURCE_TILE_WIDTH
      sh = TilemapRenderer::SOURCE_TILE_HEIGHT
      return false if sr.width != sw || sr.height < sh
      return true
    end

    # pri0 que no entra en la fila (Cliff, puente, ox). Si hay uno, no se junta.
    def ground_row_blocker?(tile)
      return false if tile_blank?(tile)
      return false if tile.shows_reflection
      return false if flat_cap?(tile)
      return false if tile_maybe_raised?(tile)
      return true
    end

    def ground_row_for(layer, row_i, viewport)
      @ground_rows ||= {}
      key = (layer.to_i << 12) + row_i.to_i
      row = @ground_rows[key]
      if !row
        row = GroundRow.new
        row.key = key
        row.layer = layer.to_i
        row.index = row_i.to_i
        @ground_rows[key] = row
      end
      row.viewport = viewport if viewport
      return row
    end

    def flush_ground_rows!(renderer)
      if !row_batch_active?
        dispose_ground_rows if @ground_rows
        return
      end
      return if !@ground_rows
      moved = renderer && renderer.instance_variable_get(:@screen_moved)
      if !moved && !@row_flush_needed
        sync_ground_row_tones
        return
      end
      @row_flush_needed = false
      if moved
        @ground_rows.each_value do |row|
          row.blocked = row.saw_blocker ? true : false
          row.saw_blocker = false
        end
      end
      @ground_rows.each_value do |row|
        if row.blocked
          unbatch_ground_row!(row)
          next
        end
        if row.tiles.empty?
          hide_ground_row_sprites(row)
          next
        end
        paint_ground_row!(row)
      end
    end

    def unbatch_ground_row!(row)
      row.tiles.each_value do |tile|
        next if !tile || tile.disposed?
        row_i = tile.hd25_batch_row
        flat = tile.hd25_batch_flat
        tile.hd25_row_batched = false
        tile.hd25_batch_key = nil
        next if row_i.nil? || flat.nil? || !tile.bitmap
        tile.visible = true
        tile.x = flat
        tile.hd25_proj_stamp = nil
        project_tile(tile, row_i)
        demote_stale_ground_z(tile) if !tile_maybe_raised?(tile)
      end
      row.tiles.clear
      row.dirty = true
      row.sig = nil
      hide_ground_row_sprites(row)
    end

    def sync_ground_row_tones
      return if !@ground_rows
      @ground_rows.each_value do |row|
        next if row.blocked || row.tiles.empty?
        apply_ground_row_tone(row)
      end
    end

    def apply_ground_row_tone(row)
      tone = nil
      row.tiles.each_value do |tile|
        next if !tile || tile.disposed?
        tone = tile.tone
        break
      end
      return if !tone
      key = tone.red.to_i ^ (tone.green.to_i << 8) ^ (tone.blue.to_i << 16) ^ (tone.gray.to_i << 24)
      return if row.tone_key == key
      row.tone_key = key
      row.sprites.each do |spr|
        next if !spr || spr.disposed? || !spr.bitmap
        spr.tone = tone
      end
    end

    def hide_ground_row_sprites(row)
      row.sprites.each do |spr|
        next if !spr || spr.disposed?
        spr.visible = false if spr.visible
      end
    end

    def paint_ground_row!(row)
      measure_ground_row!(row)
      return if row.min_x.nil?
      if row.dirty || row.sig.nil?
        sig = ground_row_sig(row)
        if sig != row.sig
          rebuild_ground_row!(row)
          return if row.blocked || row.tiles.empty?
          row.sig = sig
        end
        row.dirty = false
      end
      row.tiles.each_value do |tile|
        next if !tile || tile.disposed?
        tile.visible = false if tile.visible
      end
      n = row.flat ? 1 : ground_slice_count
      idx = row.index
      if n > 1 && (!@row_slice_y || !@row_slice_y[idx])
        n = 1
      end
      place_ground_row!(row, n)
      hide_extra_row_sprites(row, n)
    end

    def measure_ground_row!(row)
      min_x = nil
      max_x = nil
      dw = TilemapRenderer::DISPLAY_TILE_WIDTH
      row.tiles.each_value do |tile|
        next if !tile || tile.disposed?
        fx = tile.hd25_batch_flat
        next if fx.nil?
        min_x = fx if min_x.nil? || fx < min_x
        right = fx + dw
        max_x = right if max_x.nil? || right > max_x
      end
      row.min_x = min_x
      row.max_x = max_x
    end

    def ground_row_sig(row)
      sig = 17
      flat = false
      row.tiles.each_value do |tile|
        next if !tile || tile.disposed?
        sig = (sig * 33 + tile.object_id) & 0x7fffffff
        bmp = tile.bitmap
        sig = (sig * 33 + (bmp ? bmp.object_id : 0)) & 0x7fffffff
        sr = tile.src_rect
        if sr
          sig = (sig * 33 + sr.x + (sr.y * 8192)) & 0x7fffffff
        end
        flat = true if tile_forces_flat_row?(tile)
      end
      row.flat = flat
      sig += 1 if flat
      return sig
    end

    def rebuild_ground_row!(row)
      return if row.min_x.nil? || row.max_x.nil?
      row.tone_key = nil
      dw = TilemapRenderer::DISPLAY_TILE_WIDTH
      sw = TilemapRenderer::SOURCE_TILE_WIDTH
      sh = TilemapRenderer::SOURCE_TILE_HEIGHT
      span = row.max_x - row.min_x
      return if span < 1
      bmp_w = (span * sw) / dw
      bmp_w = 1 if bmp_w < 1
      # Una fila más ancha que esto es un fallo de medida: mejor tiles sueltos.
      if bmp_w > 4096
        row.blocked = true
        unbatch_ground_row!(row)
        return
      end
      n = row.flat ? 1 : ground_slice_count
      idx = row.index
      n = 1 if n > 1 && (!@row_slice_y || !@row_slice_y[idx])
      band = sh / n
      band = sh if band < 1
      k = 0
      while k < n
        spr = ensure_row_sprite(row, k)
        bh = (n == 1) ? sh : band
        sy0 = (n == 1) ? 0 : (k * band)
        bmp = spr.bitmap
        if !bmp || bmp.disposed? || bmp.width != bmp_w || bmp.height != bh
          bmp.dispose if bmp && !bmp.disposed?
          bmp = Bitmap.new(bmp_w, bh)
          spr.bitmap = bmp
        else
          bmp.clear
        end
        row.tiles.each_value do |tile|
          next if !tile || tile.disposed? || !tile.bitmap || tile.bitmap.disposed?
          sr = tile.src_rect
          fx = tile.hd25_batch_flat
          next if !sr || fx.nil?
          next if sr.y + sy0 + bh > tile.bitmap.height
          next if sr.x + sw > tile.bitmap.width
          dx = ((fx - row.min_x) * sw) / dw
          bmp.stretch_blt(Rect.new(dx, 0, sw, bh), tile.bitmap,
                          Rect.new(sr.x, sr.y + sy0, sw, bh))
        end
        k += 1
      end
    end

    def ensure_row_sprite(row, index)
      spr = row.sprites[index]
      vp = row.viewport
      if spr && !spr.disposed? && spr.viewport != vp
        spr.bitmap&.dispose
        spr.dispose
        spr = nil
      end
      if !spr || spr.disposed?
        spr = GroundStrip.new(vp)
        spr.z = 0
        spr.ox = 0
        spr.oy = 0
        row.sprites[index] = spr
      end
      return spr
    end

    def place_ground_row!(row, n)
      idx = row.index
      min_x = row.min_x
      max_x = row.max_x
      return if min_x.nil? || max_x.nil?
      if n <= 1
        place_ground_row_full!(row, idx, min_x, max_x)
        apply_ground_row_tone(row)
        return
      end
      ys = @row_slice_y[idx]
      ss = @row_slice_s[idx]
      zy = @row_slice_zy[idx]
      tp = @row_slice_tp[idx]
      if !ys || !ss || !zy || !tp
        place_ground_row_full!(row, idx, min_x, max_x)
        apply_ground_row_tone(row)
        return
      end
      k = 0
      while k < n
        spr = row.sprites[k]
        k += 1
        next if !spr || spr.disposed? || !spr.bitmap
        near = ss[k]
        near = ss[k - 1] if !near || near <= 0
        y0 = ys[k - 1]
        next if !near || y0.nil?
        start = project_x(min_x, near)
        finish = project_x(max_x, near)
        wpx = finish - start
        wpx = 1 if wpx < 1
        bw = spr.bitmap.width.to_f
        bw = 1.0 if bw < 1.0
        pose_row_sprite(spr, start, y0, wpx / bw, zy[k - 1], tp[k - 1])
      end
      apply_ground_row_tone(row)
    end

    def place_ground_row_full!(row, idx, min_x, max_x)
      spr = row.sprites[0]
      return if !spr || spr.disposed? || !spr.bitmap
      near = row_width_scale(idx + 1)
      near = row_width_scale(idx) if !near || near <= 0
      top = row_top(idx)
      bot = row_top(idx + 1)
      height = bot - top
      height = 1 if height < 1
      start = project_x(min_x, near)
      finish = project_x(max_x, near)
      wpx = finish - start
      wpx = 1 if wpx < 1
      bw = spr.bitmap.width.to_f
      bw = 1.0 if bw < 1.0
      zy = height / TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
      pose_row_sprite(spr, start, top, wpx / bw, zy, row_taper(idx))
    end

    def pose_row_sprite(spr, x, y, zx, zy, taper)
      apply_tile_taper(spr, taper)
      zx = quant_zoom(zx)
      zy = quant_zoom(zy)
      spr.zoom_x = zx if (spr.zoom_x - zx).abs > ZOOM_EPS
      spr.zoom_y = zy if (spr.zoom_y - zy).abs > ZOOM_EPS
      spr.x = x if spr.x != x
      spr.y = y if spr.y != y
      spr.z = 0 if spr.z != 0
      spr.opacity = 255 if spr.opacity != 255
      spr.visible = true if !spr.visible
    end

    def hide_extra_row_sprites(row, n)
      i = n
      while i < row.sprites.length
        spr = row.sprites[i]
        spr.visible = false if spr && !spr.disposed? && spr.visible
        i += 1
      end
    end

  end
end

# F12 no pisa una constante ya creada. Estos dos se apagan aquí también.
Visual25D.row_batch = false
Visual25D.band_blur = false