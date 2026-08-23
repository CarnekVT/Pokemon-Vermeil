#===============================================================================
# [VERMEIL] Visual 2.5D - 012_MakerStudioBridge.rb
#===============================================================================
class Mode7Renderer
  private

  # El video de prueba mostraba hojas y fondo verde del exterior aun despues
  # de entrar a la casa. Maker Studio mantiene algunos sprites de fog/panorama
  # fuera del renderer; limpiamos SOLO objetos Sprite guardados en ivars cuyo
  # nombre indica fog/panorama y luego dejamos que el mapa actual los recree.
  def dispose_ms_plane_sprites(obj, seen = {})
    return false if obj.nil?
    oid = obj.object_id rescue nil
    return false if oid && seen[oid]
    seen[oid] = true if oid
    if defined?(Sprite) && obj.is_a?(Sprite)
      obj.dispose if !obj.disposed?
      return true
    end
    if obj.is_a?(Array)
      obj.delete_if do |v|
        is_sprite = defined?(Sprite) && v.is_a?(Sprite)
        dispose_ms_plane_sprites(v, seen)
        is_sprite
      end
    elsif obj.is_a?(Hash)
      obj.delete_if do |_k, v|
        is_sprite = defined?(Sprite) && v.is_a?(Sprite)
        dispose_ms_plane_sprites(v, seen)
        is_sprite
      end
    end
    false
  rescue Exception
    false
  end

  def clear_stale_ms_planes
    return if !defined?(MakerStudio)
    MakerStudio.instance_variables.each do |ivar|
      next if ivar.to_s !~ /(fog|panorama)/i
      value = MakerStudio.instance_variable_get(ivar) rescue nil
      dispose_ms_plane_sprites(value)
    end
  rescue Exception
  end

  def ensure_extended_data
    return if !defined?(MakerStudio)
    # V5.13: never recursively walk MakerStudio's fog/panorama ivars during a
    # map renderer build. Those caches can contain large arrays/hashes and the
    # walk used to happen exactly on the loading-frame hot path. Maker Studio's
    # own renderer lifecycle already disposes stale planes and creates current
    # map fog lazily.
    if !MakerStudio.get_extended_data_for(@map_id) && MakerStudio.respond_to?(:load_extended_layers_for_map)
      MakerStudio.load_extended_layers_for_map(@map_id, @map)
    end
    # Fog creation itself is cache-guarded per map. Keep it, but avoid the old
    # recursive global cache walk above.
    if MakerStudio.respond_to?(:create_fog_sprites_for_map)
      MakerStudio.create_fog_sprites_for_map(@map_id, @map)
    end
  rescue Exception => e
    Console.echo_error("VERMEIL MakerStudio bridge: #{e.message}") if defined?(Console)
  end


  def update_ms_fog
    if defined?(MakerStudio) && MakerStudio.respond_to?(:update_fog_sprites)
      MakerStudio.update_fog_sprites
    end
  rescue Exception
    # Un fog/panorama viejo nunca debe tumbar el mapa durante un transfer.
  end

  def ms_has_panorama?
    return false if !defined?(MakerStudio) || !MakerStudio.respond_to?(:get_extended_data_for)
    ext = MakerStudio.get_extended_data_for(@map_id)
    panos = ext && ext["panoramaLayers"]
    return panos && !panos.empty?
  rescue
    false
  end

  def bake_ms_shadows
    return if !defined?(MakerStudio)
    if !TilemapRenderer.method_defined?(:create_shadow_sprites_for_map)
      Console.echoln("VERMEIL: MS shadow pipeline no esta en TilemapRenderer; skip bake") if defined?(Console)
      return
    end
    ext = MakerStudio.get_extended_data_for(@map_id)
    if !ext || !(ext["shadowLayers"] || ext["shadowLayer"])
      return
    end
    shadows = ext["shadowLayers"]
    shadows = [ext["shadowLayer"]].compact if !shadows || shadows.empty?
    # create_shadow_sprites_for_map aplica estos mismos filtros. Mantener una
    # lista paralela permite recuperar las celdas fuente reales de cada sombra.
    shadow_defs = shadows.select do |shadow|
      next false if !shadow || !shadow["visible"]
      config = shadow["config"]
      sources = shadow["sourceTiles"]
      config && sources && !sources.empty? &&
        !config["height"].nil? && !config["direction"].nil?
    end
    aux_vp = Viewport.new(0, 0, 1, 1)
    aux_vp.visible = false
    aux = TilemapRenderer.new(aux_vp)
    aux.create_shadow_sprites_for_map(@map, ext)
    @nds_baked_prop_shadow_keys = {}
    shadow_sprites = aux.instance_variable_get(:@shadow_sprites) || []
    shadow_sprites.each_with_index do |spr, shadow_index|
      next if !spr || spr.disposed? || !spr.bitmap || spr.bitmap.disposed?
      fw = (spr.respond_to?(:shadow_frame_w) ? spr.shadow_frame_w : 0).to_i
      fw = spr.bitmap.width if fw <= 0 || fw > spr.bitmap.width
      # TileSprite compensa ox/oy dentro de Sprite al mostrarse. El bitmap ya
      # trae su padding; aplicarlo otra vez aqui desplaza la sombra de su origen.
      dx = spr.map_x * Game_Map::TILE_WIDTH
      dy = spr.map_y * Game_Map::TILE_HEIGHT
      # Los props verticales (billboard/estructura/overlay) aplastan su silueta
      # en una linea antiestetica con la direccion de CADA capa de MS. Para
      # ellos el bake sustituye el slab plano por un blob radial uniforme en
      # la base del objeto: direccion consistente y sin cola pixelada.
      prop_cells = if Mode7::Config::NDS_SHADOW_PROP_BLOBS
                     source_cells = nds_shadow_source_prop_cells(
                       shadow_defs[shadow_index]
                     )
                     source_cells.empty? ? nds_prop_shadow_cells(spr, fw) : source_cells
                   else
                     []
                   end
      if !prop_cells.empty?
        nds_bake_prop_shadow_blobs(prop_cells, spr)
        next
      end
      # Maker Studio ya entrega esta silueta proyectada. Se hornea una sola vez
      # en el receptor; convertirla despues en otro quad de perspectiva era una
      # segunda proyeccion y producia curvas/zigzags ademas de otro Sprite.
      @shadow_ground.blt(dx, dy, spr.bitmap,
                         Rect.new(0, 0, fw, spr.bitmap.height), spr.opacity)
    end
    aux.dispose if aux && !aux.disposed?
    aux_vp.dispose if aux_vp && !aux_vp.disposed?
  rescue Exception
    Console.echo_error("VERMEIL: bake_ms_shadows: #{$!.message}") if defined?(Console)
    aux.dispose if defined?(aux) && aux && aux.respond_to?(:dispose) && !aux.disposed?
    aux_vp.dispose if defined?(aux_vp) && aux_vp && aux_vp.respond_to?(:dispose) && !aux_vp.disposed?
  end

  # Fuente vertical de Maker Studio: las posiciones sourceTiles son mas fiables
  # que buscar el objeto dentro del bitmap proyectado (que puede extenderse diez
  # celdas en otra direccion). Tambien cubre props legacy P1+ aun sin tag NDS.
  def nds_shadow_source_prop_cells(shadow)
    return [] if !shadow || !@entry_cache
    cells = []
    (shadow["sourceTiles"] || []).each do |source|
      tx = source["x"].to_i
      ty = source["y"].to_i
      entries = @entry_cache[[tx, ty]]
      next if !entries || entries.empty?
      prop = entries.any? do |entry|
        id = respond_to?(:nds_category_id, true) ? nds_category_id(entry) : nil
        explicit = [
          Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG,
          Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG,
          Mode7::Config::NDS_OVERLAY_TERRAIN_TAG,
          Mode7::Config::NDS_INDOOR_PROP_TERRAIN_TAG
        ].include?(id)
        next true if explicit
        next false if respond_to?(:nds_floor_entry?, true) && nds_floor_entry?(entry)
        next false if respond_to?(:nds_volume_entry?, true) && nds_volume_entry?(entry)
        next false if respond_to?(:nds_stair_entry?, true) && nds_stair_entry?(entry)
        next false if respond_to?(:nds_wall_entry?, true) && nds_wall_entry?(entry)
        entry_visual_priority(entry).to_i > 0
      end
      cells << [tx, ty] if prop
    end
    cells.uniq
  rescue Exception
    []
  end

  # Celdas de props verticales cubiertas por una capa de sombra de Maker Studio.
  # La lista recupera el pie real del objeto aunque la sombra tenga offset.
  def nds_prop_shadow_cells(spr, fw)
    return [] if !@entry_cache
    tw = Game_Map::TILE_WIDTH
    th = Game_Map::TILE_HEIGHT
    bw = [1, (fw.to_f / tw).ceil].max
    bh = [1, (spr.bitmap.height.to_f / th).ceil].max
    cells = []
    (0...bw).each do |ox|
      (0...bh).each do |oy|
        tx = spr.map_x + ox
        ty = spr.map_y + oy
        next if tx < 0 || ty < 0
        entries = @entry_cache[[tx, ty]]
        next if !entries || entries.empty?
        if entries.any? do |entry|
             id = respond_to?(:nds_category_id, true) ? nds_category_id(entry) : nil
             id == Mode7::Config::NDS_BILLBOARD_TERRAIN_TAG ||
               id == Mode7::Config::NDS_STRUCTURE_TERRAIN_TAG ||
               id == Mode7::Config::NDS_OVERLAY_TERRAIN_TAG
           end
          cells << [tx, ty]
        end
      end
    end
    cells.uniq
  rescue Exception
    []
  end

  def nds_prop_shadow_groups(cells)
    pending = {}
    cells.each { |cell| pending[cell] = true }
    groups = []
    until pending.empty?
      seed = pending.keys.first
      pending.delete(seed)
      queue = [seed]
      group = []
      until queue.empty?
        cell = queue.shift
        group << cell
        x, y = cell
        [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]].each do |near|
          next if !pending.delete(near)
          queue << near
        end
      end
      groups << group
    end
    groups
  end

  # Blob radial cacheado por (w,h): economico y sin per-pixel por sombra.
  def nds_shadow_blob_bitmap(w, h)
    @shadow_blob_cache ||= {}
    key = "#{w}x#{h}"
    cached = @shadow_blob_cache[key]
    return cached if cached && !cached.disposed?
    bmp = Bitmap.new(w, h)
    cx = w / 2.0
    cy = h / 2.0
    rx = [cx, 1.0].max
    ry = [cy, 1.0].max
    # La sombra se dibuja con el alpha de Maker Studio. Un nucleo demasiado
    # tenue desaparecia al combinar ambos alphas sobre césped claro.
    core_alpha = if defined?(Mode7::Config::NDS_SHADOW_BLOB_CORE_ALPHA)
                   Mode7::Config::NDS_SHADOW_BLOB_CORE_ALPHA.to_i
                 else
                   180
                 end
    core_alpha = core_alpha.clamp(0, 255)
    h.times do |y|
      w.times do |x|
        d = Math.sqrt(((x - cx) / rx)**2 + ((y - cy) / ry)**2)
        next if d > 1.0
        a = (core_alpha * (1.0 - d)).round.clamp(0, 255)
        bmp.set_pixel(x, y, Color.new(0, 0, 0, a)) if a > 0
      end
    end
    @shadow_blob_cache[key] = bmp
    bmp
  rescue Exception
    nil
  end

  # Una elipse corta bajo cada objeto conserva el lenguaje visual Pokemon y no
  # depende del shear de Maker Studio ni crea sprites durante el movimiento.
  def nds_bake_prop_shadow_blobs(cells, spr)
    tw = Game_Map::TILE_WIDTH
    th = Game_Map::TILE_HEIGHT
    op = (spr.respond_to?(:opacity) ? spr.opacity.to_i : 255).clamp(0, 255)
    min_op = if defined?(Mode7::Config::NDS_SHADOW_BLOB_MIN_OPACITY)
               Mode7::Config::NDS_SHADOW_BLOB_MIN_OPACITY.to_i.clamp(0, 255)
             else
               192
             end
    op = min_op if op < min_op
    nds_prop_shadow_groups(cells).each do |group|
      xs = group.map { |x, _y| x }
      ys = group.map { |_x, y| y }
      key = [xs.min, ys.min, xs.max, ys.max]
      next if @nds_baked_prop_shadow_keys[key]
      @nds_baked_prop_shadow_keys[key] = true

      cell_width = xs.max - xs.min + 1
      rw = (cell_width * tw * 0.72).round.clamp((tw * 0.65).round, tw * 3)
      rh = (rw * 0.32).round.clamp((th * 0.25).round, (th * 0.8).round)
      bmp = nds_shadow_blob_bitmap(rw, rh)
      next if !bmp
      cx = (xs.min + xs.max + 1) * tw / 2.0
      base_y = (ys.max + 1) * th.to_f
      dx = (cx - rw / 2.0).round
      dy = (base_y - rh / 2.0).round
      @shadow_ground.blt(dx, dy, bmp, Rect.new(0, 0, rw, rh), op)
    end
  rescue Exception => e
    Console.echo_error("2.5D blob shadow: #{e.message}") if defined?(Console)
  end

  def native_props_at(tx, ty, layer)
    return nil if !defined?(MakerStudio) || !MakerStudio.respond_to?(:native_props_at)
    return MakerStudio.native_props_at(@map_id, @map.width, layer, ty * @map.width + tx)
  end

  def make_native_prop_entry(tx, ty, layer, props)
    if props["autotile_name"]
      name = props["autotile_name"]
      bmp = ensure_autotile(name)
      return nil if !bmp
      pattern = (props["autotile_pattern"] || 0).to_i
      vid = 8 * TilemapRenderer::TILES_PER_AUTOTILE + pattern
      priority = MakerStudio.resolve_band_priority(@map, 0, props)
      @scratch.filename = name
      @autotiles.set_src_rect(@scratch, vid)
      entry = { bitmap: bmp, src_rect: @scratch.src_rect.clone, priority: priority,
               animated: @autotiles.animated?(name), filename: name, tid: vid, unify: layer,
               tileset_id: @map.tileset_id }
      stylize_entry(entry, props, layer)
      entry[:native_layer] = layer
      entry[:native_tile_id] = @map.data[tx, ty, layer].to_i
      entry[:shadow_props] = props
      return entry
    end
    if props["tileset_id"]
      ts = $data_tilesets[props["tileset_id"].to_i]
      tid = @map.data[tx, ty, layer]
      tid = props["tile_id"].to_i if tid.nil? || tid == 0
      return nil if !ts || tid <= 0
      priority = MakerStudio.resolve_band_priority(@map, tid, props)
      entry = entry_from_tileset(ts, tid, priority, layer)
      return nil if !entry
      stylize_entry(entry, props, layer)
      entry[:tileset_id] = ts.id
      entry[:native_layer] = layer
      entry[:native_tile_id] = @map.data[tx, ty, layer].to_i
      entry[:shadow_props] = props
      return entry
    end
    nil
  end

  # Aplica sobre una entry ya construida los atributos visuales reales de
  # Maker Studio (claves de tile_data: opacity, hue, saturation, lighting,
  # rotation, flipH/flipV) mas la elevacion por capa unificada. hue/saturation/
  # lighting son enteros que se hornean via MakerStudio::TileEffects, NO
  # Tone/Color.
  def stylize_entry(entry, src, unify = nil)
    # Conserva override de terrain tag de Maker Studio para el filtro 2.5D.
    entry[:terrain_tag] = src["terrain_tag"].to_i if src.key?("terrain_tag")
    v = src["opacity"];   entry[:opacity] = v.to_i if v
    v = src["rotation"];  entry[:rotation] = v.to_i if v && v.to_i != 0
    entry[:flip] = true if src["flipH"] || src["flipV"]
    h = src["hue"].to_i
    s = (src["saturation"] || 100).to_i
    l = (src["lighting"] || 0).to_i
    entry[:hue] = h if h % 360 != 0
    entry[:saturation] = s if s != 100
    entry[:lighting] = l if l != 0
    toned = src["tone"]
    if toned.is_a?(Array)
      entry[:tone] = Tone.new(*toned)
    elsif toned.is_a?(Tone)
      entry[:tone] = toned
    end
    # IMPORTANTE: `unify`/layer es orden de dibujo, NO altura fisica.
    # Solo elevamos una entry si Maker Studio trae una elevacion explicita.
    if src.key?("elevation") && !src["elevation"].nil?
      entry[:elevation] = src["elevation"].to_i
    end
  end

  # Devuelve [bitmap, rect] para dibujar la entry, con hue/saturation/lighting
  # de MS horneados en un tile 32x32 cacheado. Si no hay efecto (o no se puede
  # hornear) devuelve el bitmap original.
  def baked_source(e)
    h = e[:hue] || 0
    s = e[:saturation] || 100
    l = e[:lighting] || 0
    return [e[:bitmap], e[:src_rect]] if h == 0 && s == 100 && l == 0
    @tile_bake_cache ||= {}
    key = "#{e[:filename] || e[:tid]}:#{e[:tileset_id] || @map.tileset_id}:#{h}:#{s}:#{l}"
    hit = @tile_bake_cache[key]
    return hit if hit
    tmp = Bitmap.new(Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
    tmp.blt(0, 0, e[:bitmap], e[:src_rect], 255)
    if defined?(MakerStudio::TileEffects) && MakerStudio::TileEffects.respond_to?(:apply_css_color_filters)
      begin
        MakerStudio::TileEffects.apply_css_color_filters(tmp, h, s, l)
      rescue Exception
      end
    end
    @tile_bake_cache[key] = [tmp, Rect.new(0, 0, Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)]
  rescue Exception
    [e[:bitmap], e[:src_rect]]
  end

  # Dibuja una entry dentro de un bitmap destino (columna o suelo) en la
  # posicion dx_px,y aplicando el horno de MS y, si existe, Tone/Color legacy.
  def blt_entry_into(dst, dx_px, y, e, op = 255)
    src_b, src_r = baked_source(e)
    if e[:tone] || e[:color]
      tmp = Bitmap.new(Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT)
      tmp.blt(0, 0, src_b, src_r, op)
      tmp.tone = e[:tone] if e[:tone]
      tmp.color = e[:color] if e[:color]
      dst.blt(dx_px, y, tmp, Rect.new(0, 0, Game_Map::TILE_WIDTH, Game_Map::TILE_HEIGHT))
      tmp.dispose
    else
      dst.blt(dx_px, y, src_b, src_r, op)
    end
  end

  def collect_extended_entries(tx, ty, entries, seen)
    return if !defined?(MakerStudio) || !MakerStudio.respond_to?(:ext_layers_index_for)
    layers = @v25_ext_layers_index
    if layers.nil?
      begin
        layers = MakerStudio.ext_layers_index_for(@map_id, @map.width)
        @v25_ext_layers_index = layers
      rescue Exception
        layers = []
      end
    end
    return if !layers || layers.empty?
    idx = ty * @map.width + tx
    
    layers.each do |layer|
      next if layer.key?("visible") && !layer["visible"]
      
      td = layer[:tiles][idx]
      next if !td
      
      tid = td["tile_id"].to_i
      priority = MakerStudio.resolve_band_priority(@map, tid, td)
      ul = MakerStudio.unified_layer(layer["id"])
      entry = nil
      
      if td["autotile_name"]
        entry = make_ext_autotile_entry(td, priority, ul)
      elsif td["tileset_id"]
        ts = $data_tilesets[td["tileset_id"].to_i]
        entry = entry_from_tileset(ts, tid, priority, ul) if ts
      elsif tid > 0
        ts = $data_tilesets[@map.tileset_id]
        entry = entry_from_tileset(ts, tid, priority, ul) if ts
      end
      
      if entry
        stylize_entry(entry, td, ul)

        # Transform (zoom, angle, mirror, offset)
        entry[:zoom_x] = layer["zoom_x"] || td["zoom_x"] || 1.0
        entry[:zoom_y] = layer["zoom_y"] || td["zoom_y"] || 1.0
        entry[:angle] = layer["angle"] || td["angle"] || 0.0
        entry[:mirror] = layer.key?("mirror") ? layer["mirror"] : (td.key?("mirror") ? td["mirror"] : false)
        entry[:ox] = layer["ox"] || td["ox"] || 0
        entry[:oy] = layer["oy"] || td["oy"] || 0
        entry[:blend_type] = layer["blend_type"] || td["blend_type"] || 0

        if layer["opacity"]
          entry[:opacity] = layer["opacity"].to_i
        elsif !entry[:opacity]
          entry[:opacity] = 255
        end
        entry[:elevation] = layer["elevation"].to_i if layer["elevation"]

        append_entry(entries, seen, entry)
      end
    end
  end

  def make_ext_autotile_entry(td, priority, ul)
    name = td["autotile_name"]
    bmp = ensure_autotile(name)
    return nil if !bmp
    pattern = (td["autotile_pattern"] || 0).to_i
    vid = 8 * TilemapRenderer::TILES_PER_AUTOTILE + pattern
    @scratch.filename = name
    @autotiles.set_src_rect(@scratch, vid)
    return { bitmap: bmp, src_rect: @scratch.src_rect.clone, priority: priority,
             animated: @autotiles.animated?(name), filename: name, tid: vid, unify: ul }
  end

  def ensure_autotile(name)
    existing = @autotiles[name]
    return existing if existing && !existing.disposed?
    return nil if !defined?(MakerStudio) || !MakerStudio.respond_to?(:get_extra_autotile)
    raw = MakerStudio.get_extra_autotile(name)
    return nil if !raw || raw.disposed?
    begin
      durations = @autotiles.instance_variable_get(:@frame_durations)
      durations[name] = TilemapRenderer::AUTOTILE_FRAME_DURATION.to_f / 20 if durations && !durations.key?(name)
      # Essentials v21/LBDS defines the expander under TilemapRenderer.
      # An unqualified constant here resolves inside Mode7Renderer first.
      expander = nil
      if defined?(TilemapRenderer::AutotileExpander)
        expander = TilemapRenderer::AutotileExpander
      elsif defined?(::AutotileExpander)
        expander = ::AutotileExpander
      end
      return nil if !expander
      expanded = expander.expand(raw)
      return nil if !expanded || expanded.disposed?
      @autotiles[name] = expanded
      load_counts = @autotiles.instance_variable_get(:@load_counts)
      load_counts[name] ||= 1 if load_counts
      if expanded.height > MakerStudio::TILE_HEIGHT && expanded.height < MakerStudio::TILES_PER_AUTOTILE * MakerStudio::TILE_HEIGHT
        wraps_hash = @autotiles.instance_variable_get(:@bitmap_wraps)
        wraps_hash[name] = true if wraps_hash
        @autotiles.frame_count(name, true)
      end
    rescue
      return nil
    end
    return @autotiles[name]
  end
end
