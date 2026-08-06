#===============================================================================
# [VERMEIL] Visual 2.5D - 003_TileDepth.rb
# Renderer de suelo en perspectiva (extrusion vertical del piso 2.5D).
# Swap del renderer en Scene_Map (TilemapRenderer <-> Mode7Renderer).
#===============================================================================

# Replica minima de un TileSprite para reutilizar set_src_rect de las caches
# de TilemapRenderer.
class Mode7Renderer
  class ScratchTile
    attr_accessor :filename
    attr_reader   :src_rect
    def initialize; @src_rect = Rect.new(0, 0, 32, 32); end
  end

  attr_reader :tilesets, :autotiles, :viewport
  attr_accessor :tone, :color, :ox, :oy, :visible

  def initialize(viewport)
    @viewport = viewport || Viewport.new(0, 0, Mode7.screen_w, Mode7.screen_h)
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
    @last_ms_fog_cam_x = nil
    @last_ms_fog_cam_y = nil
    @map_id = -1
    @map = nil
    @disposed = false
    Mode7.configure
  end

  def disposed?; return @disposed; end

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

  def add_tileset(filename); @tilesets.add(filename); @need_build = true; end
  def remove_tileset(filename); @tilesets.remove(filename); end
  def add_autotile(filename); @autotiles.add(filename); @need_build = true; end
  def remove_autotile(filename); @autotiles.remove(filename); end

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

  # Fuerza el redibujado del suelo en el proximo update.
  def invalidate_ground
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
    # ponytail: only redraw if cam_y changed OR forced. Movement vertical
    # requires redraw (perspective changes). Movement lateral: el suelo
    # proyectado cambia solo en offset X → redraw también needed (affine
    # has scroll-x dependent on hscale per-fila). Redraw threshold 1 world-px
    # skipa ~7/8 frames. Resultado: 75fps idle, ~60fps movement (vs 40-50).
    if @need_ground_redraw || (@last_cam_x.nil? || @last_cam_y.nil?) ||
       (@last_cam_x - cx).abs >= 1 || (@last_cam_y - cy).abs >= 1
      draw_ground
      @last_cam_x = cx
      @last_cam_y = cy
      @need_ground_redraw = false
    end
    update_ms_fog
    update_walls
    apply_tone_color
    @autotiles.changed = false
  end

  private

  # ---------------------------------------------------------------------------
  # Ensamblaje del suelo: extruye cada celda del mapa a un bitmap plano.
  # ---------------------------------------------------------------------------
  def build
    @map_id = $game_map.map_id
    @map = $game_map
    ensure_extended_data
    @ground&.dispose
    @ground = Bitmap.new(@map.width * Game_Map::TILE_WIDTH, @map.height * Game_Map::TILE_HEIGHT)
    @wall_data.each { |data| data[0].bitmap.dispose if data[0].bitmap && !data[0].bitmap.disposed?; data[0].dispose }
    @wall_data.clear
    @autotile_cells = Hash.new { |h, k| h[k] = [] }
    @entry_cache = {}  # Cache de entries por (tx,ty) para evitar recomputar
    @terrain_tag_cache = {}  # Cache de terrain_tag por tid:tileset_id

    # Pase 1: suelo. En celdas con muro se pinta SOLO lo que esta bajo el muro
    # (unify < wall_layer); la cara del muro (y todo lo apilado encima, incluidos
    # tiles de prioridad 1+ sin tag) se extruye como sprite en el pase 2.
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = collect_cell_entries(tx, ty)
        @entry_cache[[tx, ty]] = entries  # cache para el pase 2
        if cell_has_wall?(entries)
          wall_layer = wall_layer_unify(entries)
          ground_entries = entries.select { |e| e[:unify] < wall_layer }
          blt_ground_cell(tx, ty, ground_entries) unless ground_entries.empty?
        else
          # Sin muro: prioridad 0 -> suelo plano (z bajo, dibuja bajo el player);
          # la prioridad +1 se hornea tambien en el suelo porque cualquier sprite
          # de prioridad sera un muro extruido mas tarde (pase 2) si aplica.
          blt_ground_cell(tx, ty, entries)
        end
      end
    end

    # Sombras de MakerStudio horneadas en el suelo (van DEBAJO de los muros).
    bake_ms_shadows

    # Pase 2: extrusion de muros (tag WALL_TERRAIN_TAG_HEIGHT, o prioridad 1+),
    # como sprites por encima del suelo y las sombras. Se extruyen JUNTOS todas
    # las capas >= wall_layer de una celda (cara del muro + adornos encima),
    # asi no se cortan ni se separan al cambiar de angulo.
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]  # usa cached del pase 1
        next if !cell_has_wall?(entries)
        wall_layer = wall_layer_unify(entries)
        wall_entries = entries.select { |e| e[:unify] >= wall_layer }
        # ponytail: una columna que falle (VRAM/limite) se degrada a suelo
        # plano en vez de tumbar el build entero del mapa.
        begin
          make_column(tx, ty, wall_entries) unless wall_entries.empty?
        rescue Exception
          blt_ground_cell(tx, ty, wall_entries)
          Console.echo_error("2.5D: columna fallida en (#{tx},#{ty}) - se pinta plana")
        end
      end
    end

    @need_build = false
    @need_ground_redraw = true
    @old_tone = nil
    @old_color = nil
  end

# (El pre-render en un solo bitmap y scroll no suma: la forma de Dibujo
  # del mundo ya es fija en la proyeccion afine/slope elegida; ver draw_ground.)

  # Completa la recopilacion de entradas de una celda (nativas + MakerStudio).
  def collect_cell_entries(tx, ty)
    entries = []
    seen = {}
    3.times do |layer|
      tid = @map.data[tx, ty, layer]
      next if !tid || tid <= 0
      entry = make_native_entry(tid, layer)
      append_entry(entries, seen, entry)
    end
    collect_extended_entries(tx, ty, entries, seen)
    entries
  end

  def blt_ground_cell(tx, ty, entries)
    entries.sort_by { |e| e[:unify] }.each do |e|
      next if !e[:bitmap]
      op = e[:opacity] || 255
      @ground.blt(tx * Game_Map::TILE_WIDTH, ty * Game_Map::TILE_HEIGHT, e[:bitmap], e[:src_rect], op)
      if e[:animated]
        @autotile_cells[e[:filename]] ||= []
        cells = @autotile_cells[e[:filename]]
        cells.push([tx, ty]) if !cells.include?([tx, ty])
      end
    end
  end

  def current_src_rect(entry)
    return entry[:src_rect] if !entry[:animated]
    @scratch.filename = entry[:filename]
    @autotiles.set_src_rect(@scratch, entry[:tid])
    return @scratch.src_rect.clone
  end

  # Entrada desde las capas nativas del mapa (autotiles y tileset base).
  def make_native_entry(tid, layer)
    if tid < TilemapRenderer::TILESET_START_ID
      filename = autotile_name_for(tid)
      return nil if !filename || filename.empty?
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

  def append_entry(entries, seen, entry)
    return if !entry
    rect = entry[:src_rect]
    key = [entry[:priority], entry[:unify], entry[:filename], entry[:tid], rect ? [rect.x, rect.y, rect.width, rect.height] : nil]
    return if seen[key]
    seen[key] = true
    entries << entry
  end

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
    { bitmap: bmp, src_rect: src, priority: priority, animated: false, filename: nil, tid: tid, unify: unify,
      tileset_id: ts.id }
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

# ---------------------------------------------------------------------------
  # Dibuja el cielo + el suelo proyectado fila a fila, con relleno de bordes.
  # La proyeccion usa la CONICA DE CAMARA FIJA de Mode7 (project/world_y_for_row):
  # arriba lejano se encoge, abajo cercano se estira, con deformacion SUTIL
  # (AFFINE_DEPTH) para no marear. Sin rubber-hose local: la forma es global y
  # estable, no depende de la posicion del jugador.
  # ---------------------------------------------------------------------------
   def draw_ground
     return if !@ground || @ground.disposed?
     bmp = @ground_sprite.bitmap
     horizon = [Mode7.horizon_row.ceil, 0].max
     return if horizon >= Mode7.screen_h
     # ponytail: limpiar cielo solo arriba del horizonte (no full screen).
     if horizon > 0
       @clear_rect.set(0, 0, Mode7.screen_w, horizon)
       bmp.fill_rect(@clear_rect, sky_fill_color)
     end
     cx = Mode7.cam_x
     map_h_px = @map.height * Game_Map::TILE_HEIGHT
     ground_w = @ground.width
     # ponytail: culling de world_rows VISIBLES. Invertir proyeccion: encontrar
     # wy que mapea a sy=0 (top) y sy=screen_h (bottom). world y visible ≈
     # [world_y_for_row(0), world_y_for_row(screen_h)].
     wy_top = Mode7.world_y_for_row(0)
     wy_bot = Mode7.world_y_for_row(Mode7.screen_h - 1)
     wy_start = wy_top ? [wy_top.floor, 0].max : 0
     wy_end = wy_bot ? [(wy_bot + Game_Map::TILE_HEIGHT).ceil, map_h_px].min : map_h_px
      # ponytail: .step(TILE_HEIGHT) avanza por tile en vez de por píxel.
      # Cada iteración proyecta un world_row completo (32px). Evita overdraw:
      # el .each iteraba 1px dibujando 32px height → 32x overdraw. Con step,
      # una iteración por tile. Reduction 97% de stretch_blt.
      (wy_start...wy_end).step(Game_Map::TILE_HEIGHT) do |wy_int|
       sy_top = Mode7.project_y(wy_int)
       sy_bot = Mode7.project_y(wy_int + Game_Map::TILE_HEIGHT)
       next if sy_top.nil? || sy_bot.nil?

       # Determinar screen_rows que cubre esta world_row.
       sy_lo = [sy_top.floor, horizon].max
       sy_hi = sy_bot.floor
       next if sy_hi < horizon || sy_lo >= Mode7.screen_h

       sy_lo = horizon if sy_lo < horizon
       sy_hi = Mode7.screen_h - 1 if sy_hi > Mode7.screen_h - 1
       rows = sy_hi - sy_lo + 1
       next if rows <= 0

       # Calcular proyección horizontal (usa k del screen_row medio).
       sy_mid = (sy_lo + sy_hi) / 2
       wy_mid = wy_int + Game_Map::TILE_HEIGHT / 2
       k = Mode7.hscale(sy_mid)
       span = Mode7.screen_w / k
       wx_left = cx - Mode7.center_x / k
       lo = [wx_left.floor, 0].max
       hi = [(wx_left + span).ceil, ground_w].min
       if hi <= lo
         @dest_rect.set(0, sy_lo, Mode7.screen_w, rows)
         bmp.fill_rect(@dest_rect, Mode7::Config::OUTSIDE_COLOR)
         next
       end
       d_x0 = ((lo - wx_left) / span) * Mode7.screen_w
       d_w = ((hi - wx_left) / span) * Mode7.screen_w - d_x0
       if d_x0 > 0 && d_x0.round > 0
         @dest_rect.set(0, sy_lo, d_x0.round, rows)
         bmp.fill_rect(@dest_rect, Mode7::Config::OUTSIDE_COLOR)
       end
       d_x1 = d_x0 + d_w
       if d_x1.round < Mode7.screen_w
         @dest_rect.set(d_x1.round, sy_lo, Mode7.screen_w - d_x1.round, rows)
         bmp.fill_rect(@dest_rect, Mode7::Config::OUTSIDE_COLOR)
       end
       if d_w.round > 0
         @src_rect.set(lo, wy_int, hi - lo, Game_Map::TILE_HEIGHT)
         @dest_rect.set(d_x0.round, sy_lo, d_w.round, rows)
         bmp.stretch_blt(@dest_rect, @ground, @src_rect)
       end
     end
   end

    # Color de relleno del cielo. Con panorama de MakerStudio queda TRANSPARENTE
  # (alpha 0) para que el Plane del panorama (z=-1000) se vea por detras; sin
  # panorama usa SKY_COLOR. Un Color con alpha 0 rellena "borrando" el bitmap.
  def sky_fill_color
    return Mode7::Config::SKY_COLOR if !ms_has_panorama?
    return Color.new(0, 0, 0, 0)
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

# Swap del renderer en Scene_Map: usa Mode7Renderer o TilemapRenderer segun
# el estado activo de la camara 2.5D.
class Scene_Map
  alias_method :_VERMEIL_25D_orig_createSpritesets, :createSpritesets

  def createSpritesets
    wanted = (Mode7.active_now?) ? Mode7Renderer : TilemapRenderer
    if !@map_renderer || @map_renderer.disposed? || !@map_renderer.is_a?(wanted)
      @map_renderer.dispose if @map_renderer && !@map_renderer.disposed?
      @map_renderer = wanted.new(Spriteset_Map.viewport)
    end
    _VERMEIL_25D_orig_createSpritesets
  end
end