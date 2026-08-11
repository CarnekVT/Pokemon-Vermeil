#===============================================================================
# [VERMEIL] Visual 2.5D - 003_TileDepth.rb
# Renderer de suelo en perspectiva (extrusion vertical del piso 2.5D).
# Swap del renderer en Scene_Map (TilemapRenderer <-> Mode7Renderer).
# Todo tile conserva su propia base de profundidad. Compartir la Y de un bloque
# grande hace que un priority 0 lejano tape al jugador.
#===============================================================================

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
    @clear_rect = Rect.new(0, 0, 1, 1)
    @ground_sprite = Sprite.new(@viewport)
    @ground_sprite.z = -1000
    @ground_sprite.bitmap = Bitmap.new(Mode7.screen_w, Mode7.screen_h)
    @ground = nil
    @shadow_ground = nil
    @wall_data = []
    @priority_strips = []
    @priority_data = []
    @autotile_cells = {}
    @wall_cells = {}
    @walls_known = true
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

  def wall_cell_at?(x, y)
    return false if @disposed || !@walls_known
    return !@wall_cells[[x.to_i, y.to_i]].nil?
  end

  def dispose
    return if disposed?
    @ground_sprite&.dispose
    @ground_sprite = nil
    @ground&.dispose
    @ground = nil
    @shadow_ground&.dispose
    @shadow_ground = nil
    @wall_data.each do |data|
      spr = data[0]
      spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
      spr.dispose
    end
    @wall_data.clear
    @priority_strips.each do |data|
      spr, src = data[0], data[1]
      src.dispose if src && !src.disposed?
      spr.dispose
    end
    @priority_strips.clear
    @priority_data.each do |data|
      spr = data[0]
      src = data[9]
      src.dispose if src && !src.disposed?
      spr.dispose
    end
    @priority_data.clear
    @tilesets.bitmaps.each_value { |b| b.dispose }
    @tilesets.bitmaps.clear
    @autotiles.bitmaps.each_value { |b| b.dispose }
    @autotiles.bitmaps.clear
    if @tile_bake_cache
      @tile_bake_cache.each_value { |arr| arr[0].dispose if arr && arr[0] && !arr[0].disposed? }
      @tile_bake_cache = nil
    end
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
    redraw_step = Mode7::Config::GROUND_REDRAW_WORLD_STEP.to_f
    redraw_step = 1.0 if redraw_step <= 0.0
    camera_moved = @need_ground_redraw || (@last_cam_x.nil? || @last_cam_y.nil?) ||
                   (@last_cam_x - cx).abs >= redraw_step ||
                   (@last_cam_y - cy).abs >= redraw_step
    if camera_moved
      draw_ground
      @last_cam_x = cx
      @last_cam_y = cy
      @need_ground_redraw = false
    end
    update_ms_fog
    update_walls
    update_priority_surfaces
    apply_tone_color
    @autotiles.changed = false
  end

  private

  def build
    @map_id = $game_map.map_id
    @map = $game_map
    ensure_extended_data
    @ground&.dispose
    @shadow_ground&.dispose
    @ground = Bitmap.new(@map.width * Game_Map::TILE_WIDTH, @map.height * Game_Map::TILE_HEIGHT)
    @shadow_ground = Bitmap.new(@ground.width, @ground.height)
    @shadow_ground.clear
    if Mode7.indoor_map? && Mode7::Config::INTERIOR_OPAQUE_GROUND
      @ground.fill_rect(0, 0, @ground.width, @ground.height, Mode7::Config::OUTSIDE_COLOR)
    end
    @wall_data.each do |data|
      spr = data[0]
      spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
      spr.dispose
    end
    @wall_data.clear
    @priority_strips.each do |data|
      data[1].dispose if data[1] && !data[1].disposed?
      data[0].dispose
    end
    @priority_strips.clear
    @priority_raster_cells = {}
    @priority_data.each do |data|
      data[9].dispose if data[9] && !data[9].disposed?
      data[0].dispose
    end
    @priority_data.clear
    @autotile_cells = Hash.new { |h, k| h[k] = [] }
    @entry_cache = {}
    @terrain_tag_cache = {}
    @wall_visual_components = nil
    @wall_visual_owned = {}
    @indoor_prop_components = []
    @indoor_prop_owned = {}
    @wall_cells = {}
    @walls_known = true

    # Cache completo primero. La continuidad de puertas/ventanas interiores
    # necesita poder consultar las celdas vecinas sin depender del orden X/Y.
    @map.width.times do |tx|
      @map.height.times do |ty|
        @entry_cache[[tx, ty]] = collect_cell_entries(tx, ty)
      end
    end

    # Los tags exclusivos Indoor pueden resolver el modo aunque un plugin de
    # metadata no exponga Outside/Outdoor al objeto GameData.
    resolve_projection_from_indoor_tags if respond_to?(:resolve_projection_from_indoor_tags, true)

    cache_terrain_tag_heights
    cache_visual_priorities
    # Debe resolverse ANTES de hornear @ground: P4/techo sin Terrain Tag puede
    # pertenecer al mismo wall y no debe quedar duplicado en el bitmap base.
    cache_wall_visual_components
    cache_indoor_prop_components if respond_to?(:cache_indoor_prop_components, true)
    Mode7.snap_terrain_camera_lift_to_target

    # ponytail: conservar pila vanilla en bitmap fuente. Proyectar tres planos
    # por fila costaba FPS al caminar; walls se mantienen z=2 y tapan sombra,
    # igual que TilemapRenderer, sin hornear sombra sobre su cara.
    @ms_shadow_env = ms_shadow_environment
    if @ms_shadow_env
      [:base, :native_overlay, :extended].each do |pass|
        draw_ground_pass(pass, :below_shadow, @ground)
      end
      bake_ms_shadows
      composite_ground_shadows
      [:base, :native_overlay, :extended].each do |pass|
        draw_ground_pass(pass, :above_shadow, @ground)
      end
    else
      draw_ground_pass(:base, nil, @ground)
      draw_ground_pass(:native_overlay, nil, @ground)
      draw_ground_pass(:extended, nil, @ground)
    end

    # Pase 2/3: cada tile conserva bitmap Y profundidad propios. La prioridad
    # solo modifica su oclusion, nunca hereda la posicion de un vecino.
    build_wall_columns
    build_indoor_prop_blocks if respond_to?(:build_indoor_prop_blocks, true)
    build_interior_border_surfaces
    build_priority_surfaces

    @need_build = false
    @need_ground_redraw = true
    @old_tone = nil
    @old_color = nil
  end

  def collect_cell_entries(tx, ty)
    entries = []
    seen = {}
    3.times do |layer|
      entry = make_native_entry_with_props(tx, ty, layer)
      next if !entry
      append_entry(entries, seen, entry)
    end
    collect_extended_entries(tx, ty, entries, seen)
    entries
  end

  def native_layer_count
    return MakerStudio::NATIVE_LAYERS if defined?(MakerStudio::NATIVE_LAYERS)
    3
  end

  def ground_pass_for(entry)
    unify = entry[:unify].to_i
    return :extended if unify >= native_layer_count
    return :base if unify <= 0
    :native_overlay
  end

  def draw_ground_pass(pass, shadow_band = nil, target = @ground)
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]
        ground_entries = ground_entries_for_cell(tx, ty, entries)
        ground_entries.select! { |entry| ground_pass_for(entry) == pass }
        if shadow_band
          ground_entries.select! do |entry|
            ground_shadow_band_for(tx, ty, entry) == shadow_band
          end
        end
        blt_ground_cell(tx, ty, ground_entries, target) unless ground_entries.empty?
      end
    end
  end

  # Sombra Maker Studio entre bandas z=0/z=2. Incluso una celda wall recibe el
  # bitmap base: su columna se dibuja despues, z=2, y solo deja ver sombra en
  # transparencia real, igual que renderer vanilla.
  def composite_ground_shadows
    return if !@shadow_ground || @shadow_ground.disposed?
    tw = Game_Map::TILE_WIDTH
    th = Game_Map::TILE_HEIGHT
    @map.width.times do |tx|
      @map.height.times do |ty|
        @src_rect.set(tx * tw, ty * th, tw, th)
        @ground.blt(tx * tw, ty * th, @shadow_ground, @src_rect)
      end
    end
  end

  def ground_shadow_band_for(tx, ty, entry)
    env = @ms_shadow_env
    return :below_shadow if !env
    return :above_shadow if shadow_source_entry?(tx, ty, entry)
    passage = entry_shadow_passage(entry)
    return :above_shadow if passage && (passage & 0x0F) == 0x0F
    :below_shadow
  rescue Exception
    :below_shadow
  end

  def shadow_source_entry?(tx, ty, entry)
    env = @ms_shadow_env
    return false if !env
    index = ty * @map.width + tx
    sources = env[:source_entries] && env[:source_entries][index]
    return true if sources && sources.any? { |source| shadow_source_matches_entry?(source, entry) }
    source_tid = env[:source_keys][index]
    !source_tid.nil? && source_tid == entry_shadow_tile_id(entry)
  end

  # sourceLayerIndex viene del editor. Nativas antiguas pueden llegar 0-based
  # o 1-based; extendidas llegan como layer unificada. El tileId sigue siendo
  # obligatorio, asi el fallback no mueve una sombra a otra pieza vecina.
  def shadow_source_matches_entry?(source, entry)
    return false if source[:tile_id].to_i != entry_shadow_tile_id(entry)
    layer = source[:layer]
    return true if layer.nil?
    native = entry[:native_layer]
    return true if !native.nil? && (layer == native.to_i || layer == native.to_i + 1)
    entry[:unify].to_i == layer
  end

  def ms_shadow_environment
    return nil if !defined?(MakerStudio) || !MakerStudio.respond_to?(:shadow_env_for)
    env = MakerStudio.shadow_env_for(@map)
    return nil if !env || !env[:has_shadows]
    ext = MakerStudio.get_extended_data_for(@map_id) if MakerStudio.respond_to?(:get_extended_data_for)
    shadows = ext ? (ext["shadowLayers"] || []) : []
    shadows = [ext["shadowLayer"]].compact if ext && shadows.empty?
    by_cell = Hash.new { |hash, key| hash[key] = [] }
    shadows.each do |shadow|
      next if !shadow || !shadow["visible"]
      layer = shadow.key?("sourceLayerIndex") ? shadow["sourceLayerIndex"].to_i : nil
      (shadow["sourceTiles"] || []).each do |tile|
        index = tile["y"].to_i * @map.width + tile["x"].to_i
        by_cell[index] << { tile_id: tile["tileId"].to_i, layer: layer }
      end
    end
    env[:source_entries] = by_cell
    env
  rescue Exception
    nil
  end

  def entry_shadow_tile_id(entry)
    return entry[:native_tile_id].to_i if entry.key?(:native_tile_id)
    entry[:tid].to_i
  end

  def entry_shadow_passage(entry)
    tid = entry_shadow_tile_id(entry)
    return nil if tid < 0
    props = entry[:shadow_props]
    if defined?(MakerStudio) && MakerStudio.respond_to?(:resolve_shadow_tile_passage)
      return MakerStudio.resolve_shadow_tile_passage(tid, props, @map.passages)
    end
    tileset_id = entry[:tileset_id]
    passages = tileset_id ? $data_tilesets[tileset_id]&.passages : @map.passages
    passages ? passages[tid] : nil
  end

  # Una entry de wall normal pertenece SOLO al renderer de walls.
  # No puede quedar tambien horneada en @ground, que era la causa principal de
  # tiles duplicados al combinar P0/P1 o wall sobre otras superficies.
  def ground_entries_for_cell(tx, ty, entries)
    raster_affine = Mode7.respond_to?(:raster_affine_mode?) && Mode7.raster_affine_mode?

    entries.reject do |entry|
      wall_owned = respond_to?(:wall_visual_owned?, true) && wall_visual_owned?(entry)
      prop_owned = respond_to?(:indoor_prop_owned?, true) && indoor_prop_owned?(entry)

      # IndoorBorder pertenece al MISMO raster affine que el suelo aunque tenga
      # prioridad. Asi los laterales se convierten en una sola forma diagonal
      # continua en vez de sprites rectos escalonados.
      border_in_ground = raster_affine && interior_border_entry?(entry)
      next false if border_in_ground

      wall_owned || prop_owned ||
        priority_surface_entry?(entry) ||
        interior_border_entry?(entry)
    end
  end

  def make_native_entry_with_props(tx, ty, layer)
    if defined?(MakerStudio) && MakerStudio.respond_to?(:native_props_at)
      result = MakerStudio.native_props_at(@map_id, @map.width, layer, ty * @map.width + tx)
      props = result.is_a?(Array) ? result[0] : result
      if props
        if props["autotile_name"] || props["tileset_id"]
          return make_native_prop_entry(tx, ty, layer, props)
        end
        # Capa natitiva con solo efectos visuales (hue/sat/lighting/opacity/
        # rotation...): se construye la entry nativa y se estiliza para que los
        # efectos de MS tambien se apliquen en capas 1-3.
        tid = @map.data[tx, ty, layer]
        return nil if !tid || tid <= 0
        entry = make_native_entry(tid, layer)
        return nil if !entry
        if MakerStudio.respond_to?(:resolve_band_priority)
          entry[:priority] = MakerStudio.resolve_band_priority(@map, tid, props)
        end
        stylize_entry(entry, props, layer)
        entry[:tileset_id] ||= @map.tileset_id
        entry[:native_layer] = layer
        entry[:native_tile_id] = tid
        entry[:shadow_props] = props
        return entry
      end
    end
    tid = @map.data[tx, ty, layer]
    return nil if !tid || tid <= 0
    entry = make_native_entry(tid, layer)
    return nil if !entry
    entry[:native_layer] = layer
    entry[:native_tile_id] = tid
    entry
  end

  def blt_ground_cell(tx, ty, entries, target = @ground)
    entries.sort_by { |e| e[:unify] }.each do |e|
      next if !e[:bitmap]
      blt_entry_into(target, tx * Game_Map::TILE_WIDTH, ty * Game_Map::TILE_HEIGHT, e, e[:opacity] || 255)
      if e[:animated]
        @autotile_cells[e[:filename]] ||= []
        cells = @autotile_cells[e[:filename]]
        cells.push([tx, ty]) if !cells.include?([tx, ty])
      end
    end
  end

  def redraw_ground_cell(tx, ty)
    return if !@ground || @ground.disposed?
    tw = Game_Map::TILE_WIDTH
    th = Game_Map::TILE_HEIGHT
    x = tx * tw
    y = ty * th
    @clear_rect.set(x, y, tw, th)
    @ground.clear_rect(@clear_rect)
    if Mode7.indoor_map? && Mode7::Config::INTERIOR_OPAQUE_GROUND
      @ground.fill_rect(@clear_rect, Mode7::Config::OUTSIDE_COLOR)
    end

    entries = collect_cell_entries(tx, ty)
    ground_entries = ground_entries_for_cell(tx, ty, entries)
    if @ms_shadow_env
      lower = ground_entries.select do |entry|
        ground_shadow_band_for(tx, ty, entry) == :below_shadow
      end
      upper = ground_entries.select do |entry|
        ground_shadow_band_for(tx, ty, entry) == :above_shadow
      end
      blt_ground_cell(tx, ty, lower, @ground) unless lower.empty?
      if @shadow_ground && !@shadow_ground.disposed?
        @src_rect.set(x, y, tw, th)
        @ground.blt(x, y, @shadow_ground, @src_rect)
      end
      blt_ground_cell(tx, ty, upper, @ground) unless upper.empty?
    else
      blt_ground_cell(tx, ty, ground_entries, @ground) unless ground_entries.empty?
    end
  end


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

  def draw_ground
    return if !@ground || @ground.disposed?

    bmp = @ground_sprite.bitmap
    background_color = projection_fill_color
    bmp.fill_rect(0, 0, Mode7.screen_w, Mode7.screen_h, background_color)

    horizon = [Mode7.horizon_row.ceil, 0].max
    return if horizon >= Mode7.screen_h

    cx = Mode7.cam_x
    map_h_px = @map.height * Game_Map::TILE_HEIGHT
    ground_w = @ground.width
    screen_w = Mode7.screen_w
    center_x = Mode7.center_x
    outside_color = Mode7::Config::OUTSIDE_COLOR
    has_fog = Mode7.respond_to?(:fog_alpha)
    @fog_color_obj ||= Mode7::Config::FOG_COLOR.clone
    fog_color = @fog_color_obj

    # Affine conserva scanline 1:1. Cylindrical agrupa 3 filas por defecto:
    # 480 stretch_blt -> ~160 por redraw, que es la parte mas cara al caminar.
    scan_step = 1
    if Mode7.cylindrical_mode? &&
       defined?(Mode7::Config::CYLINDRICAL_RASTER_SCAN_STEP)
      scan_step = Mode7::Config::CYLINDRICAL_RASTER_SCAN_STEP.to_i
      scan_step = 1 if scan_step < 1
    end

    sy = horizon
    while sy < Mode7.screen_h
      block_h = [scan_step, Mode7.screen_h - sy].min
      sample_sy = sy + (block_h - 1) * 0.5

      wy0 = Mode7.world_y_for_row(sy)
      wy1 = Mode7.world_y_for_row([sy + block_h, Mode7.screen_h - 1].min)
      wy = Mode7.world_y_for_row(sample_sy)

      if !wy || !wy0 || !wy1 || wy1 < 0 || wy0 >= map_h_px
        @dest_rect.set(0, sy, screen_w, block_h)
        bmp.fill_rect(@dest_rect, outside_color)
        sy += block_h
        next
      end

      k = Mode7.hscale(sample_sy)
      if !k || k <= 0.001
        @dest_rect.set(0, sy, screen_w, block_h)
        bmp.fill_rect(@dest_rect, outside_color)
        sy += block_h
        next
      end

      span = screen_w / k
      wx_left = cx - center_x / k
      lo = [wx_left.floor, 0].max
      hi = [(wx_left + span).ceil, ground_w].min

      if hi <= lo
        @dest_rect.set(0, sy, screen_w, block_h)
        bmp.fill_rect(@dest_rect, outside_color)
        sy += block_h
        next
      end

      d_x0 = ((lo - wx_left) / span) * screen_w
      d_w = ((hi - wx_left) / span) * screen_w - d_x0
      d_x0_int = d_x0.round
      d_w_int = d_w.round
      d_x1_int = d_x0_int + d_w_int

      if d_x0_int > 0
        @dest_rect.set(0, sy, d_x0_int, block_h)
        bmp.fill_rect(@dest_rect, outside_color)
      end
      if d_x1_int < screen_w
        @dest_rect.set(d_x1_int, sy, screen_w - d_x1_int, block_h)
        bmp.fill_rect(@dest_rect, outside_color)
      end

      if d_w_int > 0
        src_top = [[wy0, wy1].min.floor, 0].max
        src_bottom = [[wy0, wy1].max.ceil, map_h_px].min
        src_h = [src_bottom - src_top, 1].max

        @dest_rect.set(d_x0_int, sy, d_w_int, block_h)
        @src_rect.set(lo, src_top, hi - lo, src_h)
        bmp.stretch_blt(@dest_rect, @ground, @src_rect)

        if has_fog
          alpha = Mode7.fog_alpha(sample_sy)
          if alpha > 0
            fog_color.alpha = alpha
            bmp.fill_rect(@dest_rect, fog_color)
          end
        end
      end

      sy += block_h
    end
  end

  def projection_fill_color
    return Mode7::Config::OUTSIDE_COLOR if Mode7.indoor_map? && Mode7::Config::INTERIOR_OPAQUE_GROUND
    return Mode7::Config::CYLINDRICAL_BACKGROUND_COLOR if !ms_has_panorama?
    return Color.new(0, 0, 0, 0)
  end

  def apply_tone_color
    if @old_tone != @tone
      @ground_sprite.tone = @tone
      @wall_data.each { |data| data[0].tone = @tone }
      @priority_data.each { |data| data[0].tone = @tone }
      @old_tone = @tone.clone
    end
    if @old_color != @color
      @ground_sprite.color = @color
      @wall_data.each { |data| data[0].color = @color }
      @priority_data.each { |data| data[0].color = @color }
      @old_color = @color.clone
    end
  end
end

# Swap del renderer en Scene_Map: usa Mode7Renderer o TilemapRenderer segun
# el estado activo de la camara 2.5D.
class Scene_Map
  alias_method :_VERMEIL_25D_orig_createSpritesets, :createSpritesets unless method_defined?(:_VERMEIL_25D_orig_createSpritesets)

  def createSpritesets
    # El plugin conserva siempre su renderer. Estado OFF = angulo 0/zoom 1,
    # no cambio de clase a TilemapRenderer.
    wanted = Mode7Renderer
    if !@map_renderer || @map_renderer.disposed? || !@map_renderer.is_a?(wanted)
      @map_renderer.dispose if @map_renderer && !@map_renderer.disposed?
      @map_renderer = wanted.new(Spriteset_Map.viewport)
    end
    _VERMEIL_25D_orig_createSpritesets
  end
end
