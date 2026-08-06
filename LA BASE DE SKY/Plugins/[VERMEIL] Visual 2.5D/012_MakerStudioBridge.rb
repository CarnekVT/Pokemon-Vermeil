#===============================================================================
# [VERMEIL] Visual 2.5D - 012_MakerStudioBridge.rb
# Compatibilidad con el plugin MakerStudio: capas extendidas, tilesets extra
# y HORNEADO de capas de sombra dentro del suelo proyectado (@ground).
# Solo actua si MakerStudio esta cargado (defined?). Sin el, estos metodos
# son no-ops y el renderer usa las capas nativas del mapa.
#===============================================================================
class Mode7Renderer
  private

# Carga las capas extendidas de MakerStudio para el mapa actual si faltan.
  def ensure_extended_data
    return if !defined?(MakerStudio)
    if !MakerStudio.get_extended_data_for(@map_id) && MakerStudio.respond_to?(:load_extended_layers_for_map)
      MakerStudio.load_extended_layers_for_map(@map_id, @map)
    end
    # Con Mode7Renderer activo el refresh del TilemapRenderer (donde MS crea
    # los Planes de fog/panorama) nunca corre: los instancia aqui cada mapa.
    # create_fog_sprites_for_map es idempotente (no duplica si ya existen).
    if MakerStudio.respond_to?(:create_fog_sprites_for_map)
      begin
        MakerStudio.create_fog_sprites_for_map(@map_id, @map)
        Console.echoln("VERMEIL: MS fog/panorama planes ok para mapa #{@map_id}") if defined?(Console)
      rescue Exception
        Console.echo_error("VERMEIL: create_fog_sprites_for_map: #{$!.message}") if defined?(Console)
      end
    end
  end

  # Avanza los Planes de fog/panorama de MakerStudio solo si la cámara se movió.
   # Evita llamar a MakerStudio.update_fog_sprites cada frame (costoso).
   def update_ms_fog_if_moved
     cam_x = Mode7.cam_x
     cam_y = Mode7.cam_y
     return if @last_ms_fog_cam_x == cam_x && @last_ms_fog_cam_y == cam_y
     @last_ms_fog_cam_x = cam_x
     @last_ms_fog_cam_y = cam_y
     update_ms_fog
   end

  # Avanza los Planes de fog/panorama de MakerStudio cada frame (scroll/zoom).
  def update_ms_fog
    if defined?(MakerStudio) && MakerStudio.respond_to?(:update_fog_sprites)
      MakerStudio.update_fog_sprites
    end
  end

  # True si el mapa tiene layers de panorama de MakerStudio. Si las hay, el
  # "cielo" del 2.5D debe quedar transparente para que el Plane de panorama
  # (z=-1000, detras del suelo) se vea en lugar del color SKY_COLOR solido.
  def ms_has_panorama?
    return false if !defined?(MakerStudio) || !MakerStudio.respond_to?(:get_extended_data_for)
    ext = MakerStudio.get_extended_data_for(@map_id)
    panos = ext && ext["panoramaLayers"]
    return panos && !panos.empty?
  rescue
    false
  end

  # Hornea las sombras de MakerStudio dentro del suelo (@ground). Como el 2.5D
  # reemplaza al TilemapRenderer (cuyos @shadow_sprites viven alli), sus sombras
  # no se dibujan. Reusa el pipeline de MS con un TilemapRenderer auxiliar
  # temporal: genera los sprites de sombra, lee su bitmap+posicion y los blt
  # sobre el suelo ANTES de la deformacion -> siguen la perspectiva del tilemap.
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
    # Viewport oculto: el TilemapRenderer auxiliar se crea solo para reusar el
    # pipeline de sombras de MS; nada de lo que genere debe verse en pantalla.
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

  # Prob de una capa nativa de MakerStudio (arreglos extendidos del editor).
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
      return { bitmap: bmp, src_rect: @scratch.src_rect.clone, priority: priority,
               animated: @autotiles.animated?(name), filename: name, tid: vid, unify: layer }
    end
    if props["tileset_id"]
      ts = $data_tilesets[props["tileset_id"].to_i]
      tid = @map.data[tx, ty, layer]
      tid = props["tile_id"].to_i if tid.nil? || tid == 0
      return nil if !ts || tid <= 0
      priority = MakerStudio.resolve_band_priority(@map, tid, props)
      return entry_from_tileset(ts, tid, priority, layer)
    end
    nil
  end

  # Recopila las entradas de las capas extendidas de MakerStudio.
  def collect_extended_entries(tx, ty, entries, seen)
    return if !defined?(MakerStudio) || !MakerStudio.respond_to?(:ext_layers_index_for)
    layers = MakerStudio.ext_layers_index_for(@map_id, @map.width)
    return if layers.empty?
    idx = ty * @map.width + tx
    layers.each do |layer|
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
      append_entry(entries, seen, entry)
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