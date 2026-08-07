#===============================================================================
# [VERMEIL] Visual 2.5D - 003_TileDepth.rb
# Renderer de suelo en perspectiva (extrusion vertical del piso 2.5D).
# Swap del renderer en Scene_Map (TilemapRenderer <-> Mode7Renderer).
# Pase 2 SIN agrupador horizontal (run): cada tile se eleva en su propia
# columna para seguir la curva exacta del terreno sin despegarse.
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
    @wall_data = []
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

  def build
    @map_id = $game_map.map_id
    @map = $game_map
    ensure_extended_data
    @ground&.dispose
    @ground = Bitmap.new(@map.width * Game_Map::TILE_WIDTH, @map.height * Game_Map::TILE_HEIGHT)
    @wall_data.each { |data| data[0].bitmap.dispose if data[0].bitmap && !data[0].bitmap.disposed?; data[0].dispose }
    @wall_data.clear
    @autotile_cells = Hash.new { |h, k| h[k] = [] }
    @entry_cache = {}
    @terrain_tag_cache = {}
    @wall_cells = {}
    @walls_known = true

    # Pase 1: suelo plano. En celdas con muro se pinta SOLO lo que esta bajo el
    # muro (unify < wall_layer); la cara del muro se extruye en el pase 2.
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = collect_cell_entries(tx, ty)
        @entry_cache[[tx, ty]] = entries
        if cell_has_wall?(entries)
          wall_layer = wall_layer_unify(entries)
          ground_entries = entries.select { |e| e[:unify] < wall_layer }
          blt_ground_cell(tx, ty, ground_entries) unless ground_entries.empty?
        else
          blt_ground_cell(tx, ty, entries)
        end
      end
    end

    bake_ms_shadows

    # Pase 2: muros. Una columna POR TILE para seguir la curva del terreno.
    @map.width.times do |tx|
      @map.height.times do |ty|
        entries = @entry_cache[[tx, ty]]
        if cell_has_wall?(entries)
          @wall_cells[[tx, ty]] = true
          wall_layer = wall_layer_unify(entries)
          wall_entries = entries.select { |e| e[:unify] >= wall_layer }

          lower_entries = wall_entries.select { |e| e[:priority] <= 1 }
          top_entries   = wall_entries.select { |e| e[:priority] >= 2 }

          begin
            # Altura global de la columna para que base y techo embonen
            max_h = wall_entries.map { |e| e[:unify] }.max.to_i - wall_layer + 1
            max_h = [wall_layer_height(wall_entries), max_h].max

            make_column(tx, ty, lower_entries, max_h, wall_layer, :dynamic) unless lower_entries.empty?
            make_column(tx, ty, top_entries, max_h, wall_layer, :always_top) unless top_entries.empty?
          rescue Exception
            blt_ground_cell(tx, ty, wall_entries)
            Console.echo_error("2.5D: columna fallida en (#{tx},#{ty}) - se pinta plana")
          end
        end
      end
    end

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
        return entry
      end
    end
    tid = @map.data[tx, ty, layer]
    return nil if !tid || tid <= 0
    make_native_entry(tid, layer)
  end

  def blt_ground_cell(tx, ty, entries)
    entries.sort_by { |e| e[:unify] }.each do |e|
      next if !e[:bitmap]
      blt_entry_into(@ground, tx * Game_Map::TILE_WIDTH, ty * Game_Map::TILE_HEIGHT, e, e[:opacity] || 255)
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
    bmp.clear

    sky = sky_fill_color
    bmp.fill_rect(0, 0, Mode7.screen_w, Mode7.screen_h, sky) if sky.alpha > 0

    cx = Mode7.cam_x
    map_h_px = @map.height * Game_Map::TILE_HEIGHT
    ground_w = @ground.width

    (0...Mode7.screen_h).each do |sy|
      wy = Mode7.world_y_for_row(sy)
      in_bounds = wy && wy >= 0 && wy < map_h_px

      if in_bounds
        k = Mode7.hscale(sy)
        span = Mode7.screen_w / k
        if !span.nan? && !span.infinite? && span > 1.0
          wx_left = cx - (Mode7.center_x.to_f / k)
          lo = [wx_left.floor, 0].max
          hi = [(wx_left + span).ceil, ground_w].min
          if hi > lo
            d_x0 = ((lo - wx_left) / span) * Mode7.screen_w
            d_w = ((hi - lo) / span) * Mode7.screen_w
            if d_w.round > 0
              @src_rect.set(lo, wy.floor, hi - lo, 1)
              @dest_rect.set(d_x0.round, sy, d_w.round, 1)
              bmp.stretch_blt(@dest_rect, @ground, @src_rect)
            end
          end
        end
      end

      # Niebla en TODAS las filas (suelo + cielo fuera de limites).
      if Mode7.respond_to?(:fog_alpha)
        alpha = Mode7.fog_alpha(sy)
        if alpha > 0
          @fog_color_obj ||= Mode7::Config::FOG_COLOR.clone
          @fog_color_obj.alpha = alpha
          @dest_rect.set(0, sy, Mode7.screen_w, 1)
          bmp.fill_rect(@dest_rect, @fog_color_obj)
        end
      end
    end
  end

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
    wanted = Mode7.rendering_now? ? Mode7Renderer : TilemapRenderer
    if !@map_renderer || @map_renderer.disposed? || !@map_renderer.is_a?(wanted)
      @map_renderer.dispose if @map_renderer && !@map_renderer.disposed?
      @map_renderer = wanted.new(Spriteset_Map.viewport)
    end
    _VERMEIL_25D_orig_createSpritesets
  end
end