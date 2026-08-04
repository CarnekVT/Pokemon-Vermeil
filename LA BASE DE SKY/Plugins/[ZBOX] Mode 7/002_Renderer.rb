#===============================================================================
# Mode 7 (2.5D) - Renderer de suelo y muros verticales multicapa
#===============================================================================
# Los muros dejan de ser un único sprite estirado (efecto "cartón"). Cada celda
# con prioridad > 0 genera una columna de altura = prioridad * 32 px, compuesta
# por las bandas de textura reales de todas sus capas (nativas 0-2 + extendidas
# del Maker Studio). La banda superior de cada nivel de prioridad muestra la
# textura de la capa que la pinta; las bandas vacías heredan la de la cima.
# El zoom_y ya no deforma: es la escala proyectiva natural del volumen (el
# bitmap mide ya H px de mapa y cada texel de 32 px conserva su tamaño real).
class Mode7Renderer
  # Réplica mínima de un TileSprite para reutilizar set_src_rect de las cachés
  # de TilemapRenderer.
  class ScratchTile
    attr_accessor :filename
    attr_reader   :src_rect

    def initialize
      @src_rect = Rect.new(0, 0, 32, 32)
    end
  end

  attr_reader :tilesets, :autotiles, :viewport
  attr_accessor :tone, :color, :ox, :oy, :visible

  def initialize(viewport)
    @viewport = (viewport) ? viewport : Viewport.new(0, 0, Mode7.screen_w, Mode7.screen_h)
    @tilesets  = TilemapRenderer::TilesetBitmaps.new
    @autotiles = TilemapRenderer::AutotileBitmaps.new
    @tone    = Tone.new(0, 0, 0, 0)
    @color   = Color.new(0, 0, 0, 0)
    @old_tone = @tone.clone
    @old_color = @color.clone
    @scratch  = ScratchTile.new
    @src_rect  = Rect.new(0, 0, 1, 1)
    @dest_rect = Rect.new(0, 0, 1, 1)
    @ground_sprite = Sprite.new(@viewport)
    @ground_sprite.z = -1000
    @ground_sprite.bitmap = Bitmap.new(Mode7.screen_w, Mode7.screen_h)
    @ground = nil
    @wall_data = []
    @autotile_cells = {}
    @need_build = true
    @need_ground_redraw = true
    @last_cam_x = nil
    @last_cam_y = nil
    @map_id = -1
    @map = nil
    @disposed = false
    Mode7.configure
  end

  def disposed?
    return @disposed
  end

  def dispose
    return if disposed?
    @ground_sprite&.dispose
    @ground_sprite = nil
    @ground&.dispose
    @ground = nil
    @wall_data.each do |data|
      spr = data[0]
      spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
      spr.dispose
    end
    @wall_data.clear
    @tilesets.bitmaps.each_value { |b| b.dispose }
    @tilesets.bitmaps.clear
    @autotiles.bitmaps.each_value { |b| b.dispose }
    @autotiles.bitmaps.clear
    @disposed = true
  end

  def add_tileset(filename)
    @tilesets.add(filename)
    @need_build = true
  end

  def remove_tileset(filename)
    @tilesets.remove(filename)
  end

  def add_autotile(filename)
    @autotiles.add(filename)
    @need_build = true
  end

  def remove_autotile(filename)
    @autotiles.remove(filename)
  end

  def add_extra_autotiles(tileset_id)
    arr = TilemapRenderer::EXTRA_AUTOTILES[tileset_id]
    return if !arr
    arr.each { |a| a.each { |filename| add_autotile(filename) } }
  end

  def remove_extra_autotiles(tileset_id)
    arr = TilemapRenderer::EXTRA_AUTOTILES[tileset_id]
    return if !arr
    arr.each { |a| a.each { |filename| remove_autotile(filename) } }
  end

  def refresh
    @need_build = true
    @need_ground_redraw = true
  end

  def update
    @tilesets.update
    @autotiles.update
    if @need_build || @map_id != $game_map.map_id
      build
    elsif @autotiles.changed && !@autotile_cells.empty?
      recomposite_autotiles
      @need_ground_redraw = true
    end
    cx = Mode7.cam_x
    cy = Mode7.cam_y
    if @need_ground_redraw || @last_cam_x != cx || @last_cam_y != cy
      draw_ground
      @last_cam_x = cx
      @last_cam_y = cy
      @need_ground_redraw = false
    end
    update_walls
    apply_tone_color
    @autotiles.changed = false
  end

  private

  def build
    @map_id = $game_map.map_id
    @map = $game_map
    ensure_extended_data
    @ground&.dispose
    @ground = Bitmap.new(@map.width * Game_Map::TILE_WIDTH, @map.height * Game_Map::TILE_HEIGHT)
    @wall_data.each do |data|
      spr = data[0]
      spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
      spr.dispose
    end
    @wall_data.clear
    @autotile_cells = Hash.new { |h, k| h[k] = [] }
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = collect_cell_entries(tx, ty)

        # [FIX OPENCODE]: Dibuja SIEMPRE el suelo base primero. Una celda con
        # muro (prioridad > 0) dejaba el suelo sin pintar; la transparencia de
        # los arbustos mostraba el SKY_COLOR azul detrás.
        blt_ground_cell(tx, ty, entries)

        if entries.any? { |e| e[:priority] > 0 }
          make_column(tx, ty, entries)
        end
      end
    end
    @need_build = false
    @need_ground_redraw = true

    # [FIX OPENCODE]: Resetear el caché de color para que los nuevos sprites de
    # muros absorban el tono del mapa al cambiar.
    @old_tone = nil
    @old_color = nil
  end

  # ---------------------------------------------------------------------------
  # Recolección de capas por celda (nativas 0-2 + extendidas Maker Studio)
  # ---------------------------------------------------------------------------

  # Todos los tiles pintados en la celda, cada uno con su textura resuelta y su
  # prioridad (el tileset define la altura). Orden: capa alta primero.
  def collect_cell_entries(tx, ty)
    entries = []
    seen = {}
    2.downto(0) do |layer|
      props = native_props_at(tx, ty, layer)
      if props && (props["autotile_name"] || props["tileset_id"])
        entry = make_native_prop_entry(tx, ty, layer, props)
        append_entry(entries, seen, entry)
      end
      tid = @map.data[tx, ty, layer]
      if tid && tid > 0
        entry = make_native_entry(tid, layer)
        append_entry(entries, seen, entry)
      end
    end
    collect_extended_entries(tx, ty, entries, seen)
    entries
  end

  # Properties de Maker Studio sobre una capa nativa (autotile extra o tileset
  # ajeno). nil si no hay.
  def native_props_at(tx, ty, layer)
    return nil if !defined?(MakerStudio) || !MakerStudio.respond_to?(:native_props_at)
    return MakerStudio.native_props_at(@map_id, @map.width, layer, ty * @map.width + tx)
  end

  def make_native_entry(tid, layer)
    if tid < TilemapRenderer::TILESET_START_ID
      filename = autotile_name_for(tid)
      return nil if !filename
      bmp = @autotiles[filename]
      return nil if !bmp
      @scratch.filename = filename
      @autotiles.set_src_rect(@scratch, tid)
      return { bitmap: bmp, src_rect: @scratch.src_rect.clone, priority: @map.priorities[tid] || 0,
               animated: @autotiles.animated?(filename), filename: filename, tid: tid, unify: layer }
    end
    ts = $data_tilesets[@map.tileset_id]
    return nil if !ts
    entry_from_tileset(ts, tid, @map.priorities[tid] || 0, layer)
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

  def append_entry(entries, seen, entry)
    return if !entry
    rect = entry[:src_rect]
    key = [
      entry[:priority],
      entry[:unify],
      entry[:filename],
      entry[:tid],
      rect ? [rect.x, rect.y, rect.width, rect.height] : nil
    ]
    return if seen[key]
    seen[key] = true
    entries << entry
  end

  # Textura de un tile de tileset: el propio del mapa sale de la caché del
  # renderer; los tilesets ajenos (cross-tileset) de MakerStudio.
  # OJO: se resuelve por ts.tileset_name (nombre del ARCHIVO), nunca ts.name
  # (nombre lógico del editor) — el archivo en disco no lleva ese nombre.
  def entry_from_tileset(ts, tid, priority, unify)
    return nil if !ts
    ts_name = ts.tileset_name
    if ts_name == @map.tileset_name
      bmp = @tilesets[@map.tileset_name]
      return nil if !bmp
      @scratch.filename = @map.tileset_name
      @tilesets.set_src_rect(@scratch, tid)
      src = @scratch.src_rect.clone
    elsif defined?(MakerStudio)
      bmp = MakerStudio.get_extra_tileset_for_sprite(ts_name)
      return nil if !bmp
      src = MakerStudio.extra_tileset_src_rect(ts_name, tid)
    else
      return nil
    end
    { bitmap: bmp, src_rect: src, priority: priority, animated: false, filename: nil, tid: 0, unify: unify }
  end

  # Registra un autotile extra (por nombre, no en la Table) en @autotiles con el
  # formato expandido que espera set_src_rect.
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

  # Asegura que MakerStudio tenga la data extendida del mapa cacheada.
  def ensure_extended_data
    return if !defined?(MakerStudio)
    return if MakerStudio.get_extended_data_for(@map_id)
    MakerStudio.load_extended_layers_for_map(@map_id, @map) if MakerStudio.respond_to?(:load_extended_layers_for_map)
  end

  # ---------------------------------------------------------------------------
  # Suelo: capas de prioridad 0, planas
  # ---------------------------------------------------------------------------

  def blt_ground_cell(tx, ty, entries)
    ground_entries = entries.select { |e| e && e[:priority] == 0 }
    ground_entries.sort_by { |e| e[:unify] }.each do |e|
      next if !e[:bitmap]
      @ground.blt(tx * Game_Map::TILE_WIDTH, ty * Game_Map::TILE_HEIGHT, e[:bitmap], e[:src_rect])
      if e[:animated]
        @autotile_cells[e[:filename]] ||= []
        cells = @autotile_cells[e[:filename]]
        cells.push([tx, ty]) if !cells.include?([tx, ty])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Muros: billboards planos de 32px por celda (una textura por columna)
  # ---------------------------------------------------------------------------

  def make_column(tx, ty, entries)
    walls = entries.select { |e| e[:priority] > 0 }
    return if walls.empty?
    # Altura total basada en la prioridad más alta de esta celda.
    pmax = walls.map { |e| e[:priority] }.max
    h = pmax * Game_Map::TILE_HEIGHT
    bmp = Bitmap.new(Game_Map::TILE_WIDTH, h)

    # [FIX OPENCODE]: Dibuja EXACTAMENTE lo mapeado en Maker Studio. Se ordena por
    # prioridad y capa para respetar el z-index interno. Banda vacía = aire (transparente).
    paint_column_bmp(bmp, walls)

    sprite = Sprite.new(@viewport)
    sprite.bitmap = bmp
    sprite.ox = Game_Map::TILE_WIDTH / 2
    sprite.oy = h
    sprite.visible = false

    wx = tx * Game_Map::TILE_WIDTH + Game_Map::TILE_WIDTH / 2
    wy = ty * Game_Map::TILE_HEIGHT + Game_Map::TILE_HEIGHT

    # [FIX OPENCODE]: Z clásico de RMXP a partir de coordenadas de mundo, no de
    # pantalla (las prioridades colapsan porque 3D deforma el Y proyectado).
    base_z = wy + (pmax * Game_Map::TILE_HEIGHT) + Game_Map::TILE_HEIGHT

    # [sprite, wx, wy(px base), altura(px), z-mundo, entries]
    @wall_data.push([sprite, wx, wy, h, base_z, entries])
  end

  # Pinta las bandas de la columna sobre el bitmap. Usado por make_column y por
  # recomposite_autotiles (texturas animadas).
  def paint_column_bmp(bmp, walls)
    walls.sort_by { |w| [w[:priority], w[:unify]] }.each do |w|
      draw_y = bmp.height - (w[:priority] * Game_Map::TILE_HEIGHT)
      bmp.blt(0, draw_y, w[:bitmap], current_src_rect(w))
    end
  end

  # Compone el bitmap de la columna: cada nivel de prioridad p muestra la
  # textura de la capa más alta que lo pinte. Un nivel vacío (aire entre el
  # suelo y el techo) NO hereda de la cima — se estira la textura del nivel
  # inmediatamente inferior (pared sólida). Solo si no hay inferior se usa la
  # cima. Así el voladizo transparente del techo se ve una vez, en la cima,
  # y no se repite como estrías en todo el muro.
  # Redibuja el contenido de la columna (lo usa recomposite_autotiles para
  # actualizar texturas animadas). Mismo resultado que make_column: top_entry.
  def current_src_rect(entry)
    return entry[:src_rect] if !entry[:animated]
    @scratch.filename = entry[:filename]
    @autotiles.set_src_rect(@scratch, entry[:tid])
    return @scratch.src_rect.clone
  end

  def recomposite_autotiles
    seen = {}
    @autotile_cells.each do |filename, cells|
      next if !@autotiles.animated?(filename)
      cells.each do |tx, ty|
        key = "#{tx},#{ty}"
        next if seen[key]
        seen[key] = true
        blt_ground_cell(tx, ty, collect_cell_entries(tx, ty))
      end
    end
    @wall_data.each do |data|
      sprite, entries = data[0], data[5]
      next if !entries || entries.none? { |e| e[:animated] }
      next if !sprite.bitmap || sprite.bitmap.disposed?
      walls = entries.select { |e| e[:priority] > 0 }
      paint_column_bmp(sprite.bitmap, walls)
    end
  end

  def autotile_name_for(tid)
    return nil if tid < TilemapRenderer::TILES_PER_AUTOTILE
    if tid < TilemapRenderer::TILESET_START_ID
      return @map.autotile_names[(tid / TilemapRenderer::TILES_PER_AUTOTILE) - 1]
    end
    extra = TilemapRenderer::EXTRA_AUTOTILES[@map.tileset_id]
    return nil if !extra
    large_start = TilemapRenderer::TILESET_START_ID
    single_start = large_start + (extra[0] ? extra[0].length : 0) * TilemapRenderer::TILES_PER_AUTOTILE
    if tid < single_start
      return extra[0][(tid - TilemapRenderer::TILESET_START_ID) / TilemapRenderer::TILES_PER_AUTOTILE]
    end
    return extra[1][tid - single_start]
  end

  def draw_ground
    bmp = @ground_sprite.bitmap
    bmp.fill_rect(0, 0, Mode7.screen_w, Mode7.screen_h, Mode7::Config::SKY_COLOR)
    return if !@ground || @ground.disposed?
    horizon = [Mode7.horizon_row.ceil, 0].max
    return if horizon >= Mode7.screen_h
    cx = Mode7.cam_x
    map_h_px = @map.height * Game_Map::TILE_HEIGHT
    ground_w = @ground.width
    (horizon...Mode7.screen_h).each do |sy|
      wy = Mode7.world_y_for_row(sy)
      next if !wy

      # [FIX OPENCODE]: Clamping del eje Y para evitar el renderizado del OUTSIDE_COLOR.
      # Con PIVOT_RATIO 0.80 el FOV inferior proyecta wy por debajo de los límites
      # del mapa; en vez de pintar negro, se estira el último píxel del borde.
      if wy < 0
        wy = 0
      elsif wy >= map_h_px
        wy = map_h_px - 1
      end
      k = Mode7.hscale(sy)
      span = Mode7.screen_w / k
      wx_left = cx - Mode7.center_x / k
      lo = [wx_left.floor, 0].max
      hi = [(wx_left + span).ceil, ground_w].min
      if hi <= lo
        @dest_rect.set(0, sy, Mode7.screen_w, 1)
        bmp.fill_rect(@dest_rect, Mode7::Config::OUTSIDE_COLOR)
        next
      end
      d_x0 = ((lo - wx_left) / span) * Mode7.screen_w
      d_w = ((hi - wx_left) / span) * Mode7.screen_w - d_x0
      if d_x0 > 0 && d_x0.round > 0
        @dest_rect.set(0, sy, d_x0.round, 1)
        bmp.fill_rect(@dest_rect, Mode7::Config::OUTSIDE_COLOR)
      end
      d_x1 = d_x0 + d_w
      if d_x1.round < Mode7.screen_w
        @dest_rect.set(d_x1.round, sy, Mode7.screen_w - d_x1.round, 1)
        bmp.fill_rect(@dest_rect, Mode7::Config::OUTSIDE_COLOR)
      end
      if d_w.round > 0
        @src_rect.set(lo, wy.floor, hi - lo, 1)
        @dest_rect.set(d_x0.round, sy, d_w.round, 1)
        bmp.stretch_blt(@dest_rect, @ground, @src_rect)
      end
    end
  end

  # Proyecta cada columna como un sólido: la altura proyectada (syb - syt) sale
  # de la perspectiva real, y el zoom_y es solo la escala que la aplica al
  # bitmap (que ya mide H px de mapa) — nunca deformación artificial.
  def update_walls
    @wall_data.each do |data|
      sprite, wx, wyb, h, base_z = data
      pr = Mode7.project(wx, wyb)
      if !pr
        sprite.visible = false
        next
      end
      sx, syb = pr
      syt = Mode7.project_y(wyb - h)
      if !syt || syb - syt <= 0
        sprite.visible = false
        next
      end
      if syb < -100 || syb > Mode7.screen_h + 100 ||
         sx < -160 || sx > Mode7.screen_w + 160
        sprite.visible = false
        next
      end
      sprite.x = sx
      sprite.y = syb
      # [FIX OPENCODE]: Z matemático de mundo (RMXP vanilla). El Y de pantalla lo
      # deforma el 3D; usar syb colapsa las prioridades (Charizard pisando árboles).
      sprite.z = base_z
      sprite.zoom_x = Mode7.hscale(syb)
      # [FIX OPENCODE]: +0.6px sella las costuras que deja el redondeo flotante
      # del zoom vertical (líneas transparentes en los árboles).
      sprite.zoom_y = (syb - syt + 0.6) / h
      sprite.visible = true
    end
  end

  def apply_tone_color
    if @old_tone != @tone
      @ground_sprite.tone = @tone
      @wall_data.each { |data| data[0].tone = @tone }
      @old_tone = @tone.clone
    end
    if @old_color != @color
      @ground_sprite.color = @color
      @wall_data.each { |data| data[0].color = @color }
      @old_color = @color.clone
    end
  end
end
