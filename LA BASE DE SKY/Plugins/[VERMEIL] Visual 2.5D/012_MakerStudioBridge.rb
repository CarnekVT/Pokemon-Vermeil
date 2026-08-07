#===============================================================================
# [VERMEIL] Visual 2.5D - 012_MakerStudioBridge.rb
#===============================================================================
class Mode7Renderer
  private

  def ensure_extended_data
    return if !defined?(MakerStudio)
    if !MakerStudio.get_extended_data_for(@map_id) && MakerStudio.respond_to?(:load_extended_layers_for_map)
      MakerStudio.load_extended_layers_for_map(@map_id, @map)
    end
    if MakerStudio.respond_to?(:create_fog_sprites_for_map)
      begin
        MakerStudio.create_fog_sprites_for_map(@map_id, @map)
        Console.echoln("VERMEIL: MS fog/panorama planes ok para mapa #{@map_id}") if defined?(Console)
      rescue Exception
        Console.echo_error("VERMEIL: create_fog_sprites_for_map: #{$!.message}") if defined?(Console)
      end
    end
  end

   def update_ms_fog_if_moved
     cam_x = Mode7.cam_x
     cam_y = Mode7.cam_y
     return if @last_ms_fog_cam_x == cam_x && @last_ms_fog_cam_y == cam_y
     @last_ms_fog_cam_x = cam_x
     @last_ms_fog_cam_y = cam_y
     update_ms_fog
   end

  def update_ms_fog
    if defined?(MakerStudio) && MakerStudio.respond_to?(:update_fog_sprites)
      MakerStudio.update_fog_sprites
    end
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
    aux_vp = Viewport.new(0, 0, 1, 1)
    aux_vp.visible = false
    aux = TilemapRenderer.new(aux_vp)
    aux.create_shadow_sprites_for_map(@map, ext)
    aux.instance_variable_get(:@shadow_sprites).each do |spr|
      next if !spr || spr.disposed? || !spr.bitmap || spr.bitmap.disposed?
      fw = (spr.respond_to?(:shadow_frame_w) ? spr.shadow_frame_w : 0).to_i
      fw = spr.bitmap.width if fw <= 0 || fw > spr.bitmap.width
      dx = spr.map_x * Game_Map::TILE_WIDTH - spr.ox.to_i
      dy = spr.map_y * Game_Map::TILE_HEIGHT - spr.oy.to_i
      @ground.blt(dx, dy, spr.bitmap, Rect.new(0, 0, fw, spr.bitmap.height), spr.opacity)
    end
    aux.dispose if aux && !aux.disposed?
    aux_vp.dispose if aux_vp && !aux_vp.disposed?
  rescue Exception
    Console.echo_error("VERMEIL: bake_ms_shadows: #{$!.message}") if defined?(Console)
    aux.dispose if defined?(aux) && aux && aux.respond_to?(:dispose) && !aux.disposed?
    aux_vp.dispose if defined?(aux_vp) && aux_vp && aux_vp.respond_to?(:dispose) && !aux_vp.disposed?
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
    if unify && unify > 0
      entry[:elevation] = unify * Mode7::Config::ELEVATION_PER_UNIFY + Mode7::Config::ELEVATION_FLOOR_PAD
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
    layers = MakerStudio.ext_layers_index_for(@map_id, @map.width)
    return if layers.empty?
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
      expanded = AutotileExpander.expand(raw)
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
