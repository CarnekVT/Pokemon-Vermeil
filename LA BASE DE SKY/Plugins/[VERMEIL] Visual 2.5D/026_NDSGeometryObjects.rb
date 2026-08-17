#===============================================================================
# [VERMEIL] Visual 2.5D - 026_NDSGeometryObjects.rb (Region Mesh)
# Objetos Geometry (cubos/planos) colocados con la herramienta "Objetos" del
# mod Maker Studio 2.5D Geometry (legacy Geometry authoring data -> "objects").
#
# Cada objeto se dibuja como quads 3D texturizados con Sprite#corners:
#   * cubo  -> top + caras sur/norte + caras este/oeste
#   * plano -> solo top a su elevacion
# La textura sale del material (tileset + src_rect) del propio objeto; sin
# material se usa un color de relleno segun su categoria. Es la implementacion
# in-game del "Modelo" del editor: la textura del objeto ya no queda reservada.
#
# La colision se evalua aparte en 014_Passability.rb con object_cell_blocked?.
#===============================================================================

class Mode7Renderer
  if private_method_defined?(:build) &&
     !private_method_defined?(:_VERMEIL_V60_obj_orig_build)
    alias_method :_VERMEIL_V60_obj_orig_build, :build
  end
  if method_defined?(:update) && !method_defined?(:_VERMEIL_V60_obj_orig_update)
    alias_method :_VERMEIL_V60_obj_orig_update, :update
  end
  if method_defined?(:dispose) && !method_defined?(:_VERMEIL_V60_obj_orig_dispose)
    alias_method :_VERMEIL_V60_obj_orig_dispose, :dispose
  end

  def update
    _VERMEIL_V60_obj_orig_update
    update_nds_geometry_objects if Mode7::Config::NDS_GEOMETRY_OBJECTS_ENABLED
  end

  def dispose
    dispose_nds_geometry_objects
    _VERMEIL_V60_obj_orig_dispose
  end

  private

  def build
    dispose_nds_geometry_objects
    _VERMEIL_V60_obj_orig_build
    build_nds_geometry_objects if Mode7::Config::NDS_GEOMETRY_OBJECTS_ENABLED &&
                                  Mode7::MKXPZExt.corners?
  end

  def dispose_nds_geometry_objects
    @nds_object_faces ||= []
    @nds_object_faces.each do |face|
      spr = face[:sprite]
      bmp = face[:bitmap]
      begin
        spr.corners = nil if spr && !spr.disposed? && Mode7::MKXPZExt.corners?
      rescue Exception
      end
      spr.dispose if spr && !spr.disposed?
      bmp.dispose if bmp && !bmp.disposed? && !face[:bitmap_shared]
    end
    if @nds_object_face_bitmap_cache
      @nds_object_face_bitmap_cache.each_value do |bmp|
        bmp.dispose if bmp && !bmp.disposed?
      rescue Exception
      end
    end
    @nds_object_face_bitmap_cache = {}
    @nds_object_faces = []
    @nds_object_buckets = nil
    @nds_object_active = []
    @nds_object_projection_key = nil
    @nds_object_visibility_key = nil
    @nds_object_visible_indices = []
    if @nds_object_material_cache
      @nds_object_material_cache.each_value do |pair|
        bmp = pair.is_a?(Array) ? pair[0] : nil
        bmp.dispose if bmp && !bmp.disposed?
      rescue Exception
      end
    end
    @nds_object_material_cache = {}
    @nds_object_connect_index = nil
  end

  def nds_geometry_objects
    geo = @nds_surface_geometry
    geo ? geo.objects : []
  end

  def nds_geometry_mesh_faces
    geo = @nds_surface_geometry
    geo && geo.respond_to?(:mesh_faces) ? geo.mesh_faces : []
  end

  # Resolve the exact source saved by the Scene Compiler. Regular tiles can
  # come from any project tileset; autotiles can be either the normal RMXP
  # autotile table or Maker Studio named/extra autotiles.
  def nds_object_raw_material_source(mat)
    return [nil, nil] if !mat.is_a?(Hash)
    kind = mat["kind"].to_s
    name = mat["graphic"].to_s
    name = mat["tileset_name"].to_s if name.empty?
    return [nil, nil] if name.empty?

    # Model Studio 3.1 / Blockbench link: project-local pixel-art textures live
    # under Graphics/Models and can be edited directly in Aseprite or any PNG
    # editor. Runtime caches them once just like a tileset; no per-face IO.
    if kind == "image"
      @nds_external_model_texture_cache ||= {}
      clean = name.tr("\\", "/").sub(%r{^/+}, "")
      bmp = @nds_external_model_texture_cache[clean]
      if !bmp || bmp.disposed?
        path = File.join("Graphics", "Models", clean)
        path += ".png" if File.extname(path).to_s.empty?
        begin
          bmp = Bitmap.new(path)
          @nds_external_model_texture_cache[clean] = bmp
        rescue Exception
          bmp = nil
        end
      end
      return [nil, nil] if !bmp || bmp.disposed?
      r = mat["src_rect"]
      if r.is_a?(Hash)
        x = (r["x"] || r[:x] || 0).to_i
        y = (r["y"] || r[:y] || 0).to_i
        w = (r["w"] || r[:w] || bmp.width).to_i
        h = (r["h"] || r[:h] || bmp.height).to_i
        return [bmp, Rect.new(x, y, [w, 1].max, [h, 1].max)]
      end
      return [bmp, Rect.new(0, 0, bmp.width, bmp.height)]
    end

    if kind == "autotile"
      bmp = nil
      begin
        bmp = @autotiles[name]
      rescue Exception
        bmp = nil
      end
      if (!bmp || bmp.disposed?) && respond_to?(:ensure_autotile, true)
        begin
          bmp = send(:ensure_autotile, name)
        rescue Exception
          bmp = nil
        end
      end
      return [nil, nil] if !bmp || bmp.disposed?
      begin
        tid = (mat["autotile_tid"] || mat["tile_id"] || 0).to_i
        @scratch.filename = name if @scratch.respond_to?(:filename=)
        @autotiles.set_src_rect(@scratch, tid)
        return [bmp, @scratch.src_rect.clone]
      rescue Exception
        return [nil, nil]
      end
    end

    bmp = nil
    begin
      bmp = @tilesets[name]
    rescue Exception
      bmp = nil
    end
    if (!bmp || bmp.disposed?) && defined?(MakerStudio) && MakerStudio.respond_to?(:get_extra_tileset_for_sprite)
      begin
        bmp = MakerStudio.get_extra_tileset_for_sprite(name)
      rescue Exception
        bmp = nil
      end
    end
    return [nil, nil] if !bmp || bmp.disposed?
    r = mat["src_rect"]
    return [nil, nil] if !r.is_a?(Hash)
    x = (r["x"] || r[:x] || 0).to_i
    y = (r["y"] || r[:y] || 0).to_i
    w = (r["w"] || r[:w] || Game_Map::TILE_WIDTH).to_i
    h = (r["h"] || r[:h] || Game_Map::TILE_HEIGHT).to_i
    [bmp, Rect.new(x, y, [w, 1].max, [h, 1].max)]
  end

  # Bake Maker Studio per-tile appearance once. This mirrors the bridge's
  # colour path and also keeps 90-degree rotation/flip when that exact placed
  # tile becomes geometry. The baked 32x32 sample is cached per material.
  def nds_object_baked_material_source(mat)
    src_b, src_r = nds_object_raw_material_source(mat)
    return [src_b, src_r] if !src_b || !src_r || !mat.is_a?(Hash)
    rot = ((mat["rotation"] || 0).to_i % 360 + 360) % 360
    flip_h = mat["flip_h"] == true
    flip_v = mat["flip_v"] == true
    hue = (mat["hue"] || 0).to_i
    sat = mat.key?("saturation") ? mat["saturation"].to_i : 100
    light = mat.key?("lighting") ? mat["lighting"].to_i : 0
    return [src_b, src_r] if rot == 0 && !flip_h && !flip_v && hue % 360 == 0 && sat == 100 && light == 0

    @nds_object_material_cache ||= {}
    rr = [src_r.x, src_r.y, src_r.width, src_r.height].join(",")
    key = [mat["kind"], mat["tileset_id"], mat["graphic"], mat["tile_id"], mat["autotile_tid"], rr, rot, flip_h, flip_v, hue, sat, light].join("|")
    cached = @nds_object_material_cache[key]
    return cached if cached && cached[0] && !cached[0].disposed?

    # Preserve the full selected material rectangle. A 1x2 texture is 32x64
    # and must stay 32x64; collapsing it to 32x32 causes it to be duplicated
    # vertically when applied to a two-tile-high model face.
    src_w = [src_r.width.to_i, 1].max
    src_h = [src_r.height.to_i, 1].max
    tmp = Bitmap.new(src_w, src_h)
    tmp.stretch_blt(Rect.new(0, 0, src_w, src_h), src_b, src_r)
    if defined?(MakerStudio::TileEffects) && MakerStudio::TileEffects.respond_to?(:apply_css_color_filters)
      begin
        MakerStudio::TileEffects.apply_css_color_filters(tmp, hue, sat, light)
      rescue Exception
      end
    end

    if rot != 0 || flip_h || flip_v
      out_w = (rot == 90 || rot == 270) ? src_h : src_w
      out_h = (rot == 90 || rot == 270) ? src_w : src_h
      transformed = Bitmap.new(out_w, out_h)
      transformed.clear
      y = 0
      while y < src_h
        x = 0
        while x < src_w
          sx = flip_h ? src_w - 1 - x : x
          sy = flip_v ? src_h - 1 - y : y
          dx = x
          dy = y
          case rot
          when 90
            dx = src_h - 1 - y; dy = x
          when 180
            dx = src_w - 1 - x; dy = src_h - 1 - y
          when 270
            dx = y; dy = src_w - 1 - x
          end
          transformed.set_pixel(dx, dy, tmp.get_pixel(sx, sy))
          x += 1
        end
        y += 1
      end
      tmp.dispose
      tmp = transformed
      src_w = out_w
      src_h = out_h
    end
    pair = [tmp, Rect.new(0, 0, src_w, src_h)]
    @nds_object_material_cache[key] = pair
    pair
  rescue Exception
    [src_b, src_r]
  end

  def nds_object_face_bitmap_cache_key(mat, face, w, h)
    return nil if !mat.is_a?(Hash)
    [
      mat, w.to_i, h.to_i,
      face[:uv_rect], face[:pattern_uv],
      face[:obj] && face[:obj][:material_repeat] == true
    ]
  rescue Exception
    nil
  end

  # Bitmap de una cara a partir del material. Stretch y Repeat Pattern usan
  # rutas distintas; bitmaps visualmente identicos se comparten entre sprites
  # para no reconstruir la misma pared/textura cientos de veces.
  def nds_object_face_bitmap(obj, face)
    # Model Workshop supports a different material for each face. Manual/legacy
    # objects still fall back to obj[:material].
    fm = obj[:face_materials].is_a?(Hash) ? obj[:face_materials] : {}
    face_key = face[:kind] == :top ? "top" : face[:edge].to_s
    mat = fm[face_key] || fm[face_key.to_sym] || obj[:material]
    w = face[:px_w].to_i
    h = face[:px_h].to_i
    w = [w, 1].max
    h = [h, 1].max
    cache_key = nds_object_face_bitmap_cache_key(mat, face, w, h)
    @nds_object_face_bitmap_cache ||= {}
    if cache_key
      cached = @nds_object_face_bitmap_cache[cache_key]
      if cached && !cached.disposed?
        face[:bitmap_shared] = true
        return cached
      end
    end
    out = Bitmap.new(w, h)
    out.clear
    src_b, src_r = nds_object_baked_material_source(mat)
    uv = face[:uv_rect]
    # uv_rect splits a stretched texture across subdivided faces. Repeat Pattern
    # must keep the entire selected rectangle as the unit and use pattern_uv
    # only for phase, otherwise a 1x2 source is accidentally cropped to 1x1.
    if obj[:material_repeat] != true && src_b && src_r && uv.is_a?(Array) && uv.length == 4
      begin
        u0 = [[uv[0].to_f, 0.0].max, 1.0].min
        v0 = [[uv[1].to_f, 0.0].max, 1.0].min
        u1 = [[uv[2].to_f, 0.0].max, 1.0].min
        v1 = [[uv[3].to_f, 0.0].max, 1.0].min
        sx = src_r.x + (src_r.width * u0).floor
        sy = src_r.y + (src_r.height * v0).floor
        sw = [(src_r.width * (u1 - u0)).ceil, 1].max
        sh = [(src_r.height * (v1 - v0)).ceil, 1].max
        src_r = Rect.new(sx, sy, sw, sh)
      rescue Exception
      end
    end
    if src_b && src_r
      begin
        if obj[:material_repeat] == true
          # Repeat the COMPLETE selected rectangle as one pattern unit. A 1x2
          # selection therefore repeats every 32x64, never as two independent
          # 32x32 tiles. pattern_uv preserves phase across subdivided/deformed
          # faces so the texture does not restart at each control segment.
          unit_w = [src_r.width.to_i, 1].max
          unit_h = [src_r.height.to_i, 1].max
          tmp = Bitmap.new(unit_w, unit_h)
          tmp.stretch_blt(Rect.new(0, 0, unit_w, unit_h), src_b, src_r)
          pu = face[:pattern_uv]
          start_x = 0
          start_y = 0
          if pu.is_a?(Array) && pu.length == 4
            start_x = (pu[0].to_f * Game_Map::TILE_WIDTH).round
            start_y = (pu[1].to_f * Game_Map::TILE_HEIGHT).round
          end
          phase_x = ((start_x % unit_w) + unit_w) % unit_w
          phase_y = ((start_y % unit_h) + unit_h) % unit_h
          yy = 0
          while yy < h
            sy = (phase_y + yy) % unit_h
            dh = [unit_h - sy, h - yy].min
            xx = 0
            while xx < w
              sx = (phase_x + xx) % unit_w
              dw = [unit_w - sx, w - xx].min
              out.blt(xx, yy, tmp, Rect.new(sx, sy, dw, dh))
              xx += dw
            end
            yy += dh
          end
          tmp.dispose
        else
          out.stretch_blt(Rect.new(0, 0, w, h), src_b, src_r)
        end
      rescue Exception
        out.fill_rect(0, 0, w, h, nds_object_category_color(obj))
      end
    else
      out.fill_rect(0, 0, w, h, nds_object_category_color(obj))
    end
    if cache_key
      max_cache = if Mode7::Config.const_defined?(:NDS_OBJECT_BITMAP_CACHE_MAX)
                    Mode7::Config::NDS_OBJECT_BITMAP_CACHE_MAX.to_i
                  else
                    256
                  end
      if max_cache <= 0 || @nds_object_face_bitmap_cache.length < max_cache
        @nds_object_face_bitmap_cache[cache_key] = out
        face[:bitmap_shared] = true
      end
    end
    out
  end

  def nds_object_category_color(obj)
    case obj[:category].to_s
    when "wall" then Color.new(96, 78, 58)
    when "border" then Color.new(108, 100, 92)
    when "mountain" then Color.new(92, 63, 42)
    when "roof" then Color.new(120, 105, 125)
    when "custom" then Color.new(128, 96, 128)
    when "plane" then Color.new(108, 96, 120)
    else Color.new(148, 128, 186) # floor / prop
    end
  end

  def nds_object_face_shade(kind)
    value = case kind
            when :front then Mode7::Config::NDS_OBJECT_FRONT_SHADE
            when :side then Mode7::Config::NDS_OBJECT_SIDE_SHADE
            else Mode7::Config::NDS_OBJECT_TOP_SHADE
            end
    value.to_i.clamp(0, 255)
  end

  # Convierte [wx,wy,z...] world -> puntos screen para Sprite#corners.
  def nds_object_project_points(world)
    out = []
    4.times do |i|
      p = Mode7.project(world[i * 3], world[i * 3 + 1], world[i * 3 + 2])
      return nil if !p
      out << p[0]
      out << p[1]
    end
    out
  end

  def nds_object_add_face(face)
    index = @nds_object_faces.length
    @nds_object_faces << face
    bs = Mode7::Config::NDS_RUNTIME_BUCKET_SIZE.to_i
    bs = 8 if bs <= 0
    bx0 = face[:min_tx] / bs
    bx1 = face[:max_tx] / bs
    by0 = face[:min_ty] / bs
    by1 = face[:max_ty] / bs
    bx = bx0
    while bx <= bx1
      by = by0
      while by <= by1
        @nds_object_buckets[[bx, by]] << index
        by += 1
      end
      bx += 1
    end
  end

  def nds_object_connected_at?(obj, tx, ty, base_z, top_z, step)
    return false if !@nds_object_connect_index
    (@nds_object_connect_index[[tx, ty]] || []).any? do |other|
      next false if other.equal?(obj)
      next false if other[:category].to_s != obj[:category].to_s
      other_base = other[:anchor_z].to_f * step
      other_top = other_base + other[:height].to_f * step
      (other_base - base_z).abs < 0.01 && (other_top - top_z).abs < 0.01
    end
  end

  def nds_object_build_region_mesh_faces(tw, th, step, faces_override = nil)
    faces = faces_override || nds_geometry_mesh_faces
    return if !faces || faces.empty?
    faces.each do |mf|
      begin
        kind = mf[:kind].to_s
        x0 = mf[:x0].to_f
        y0 = mf[:y0].to_f
        x1 = mf[:x1].to_f
        y1 = mf[:y1].to_f
        z0 = mf[:z0].to_f * step
        z1 = mf[:z1].to_f * step
        pseudo = {
          category: mf[:category].to_s.empty? ? "mountain" : mf[:category].to_s,
          material: mf[:material],
          face_materials: {},
          material_repeat: mf[:material_repeat] != false,
          characters_in_front: false,
          model_id: mf[:model_id],
          model_instance_id: mf[:model_instance_id]
        }
        vertices = mf[:vertices]
        if kind == "quad" && vertices.is_a?(Array) && vertices.length == 4
          xs = vertices.map { |v| v[0].to_f }
          ys = vertices.map { |v| v[1].to_f }
          min_tx = xs.min.floor
          min_ty = ys.min.floor
          max_tx = [xs.max.ceil - 1, min_tx].max
          max_ty = [ys.max.ceil - 1, min_ty].max
          world = []
          vertices.each do |v|
            world << v[0].to_f * tw
            world << v[1].to_f * th
            world << v[2].to_f * step
          end
          dx01 = (vertices[1][0].to_f - vertices[0][0].to_f) * tw
          dy01 = (vertices[1][1].to_f - vertices[0][1].to_f) * th
          dz01 = (vertices[1][2].to_f - vertices[0][2].to_f) * step
          dx03 = (vertices[3][0].to_f - vertices[0][0].to_f) * tw
          dy03 = (vertices[3][1].to_f - vertices[0][1].to_f) * th
          dz03 = (vertices[3][2].to_f - vertices[0][2].to_f) * step
          pw = Math.sqrt(dx01 * dx01 + dy01 * dy01 + dz01 * dz01)
          ph = Math.sqrt(dx03 * dx03 + dy03 * dy03 + dz03 * dz03)
          edge = mf[:edge].to_s
          surface = mf[:surface].to_s
          fkind = surface == "top" ? :top : (["north", "south"].include?(edge) ? :front : :side)
          face = {
            kind: fkind, edge: edge, obj: pseudo, world: world,
            uv_rect: mf[:uv_rect], pattern_uv: mf[:pattern_uv],
            px_w: [pw.round, 1].max, px_h: [ph.round, 1].max,
            min_tx: min_tx, min_ty: min_ty, max_tx: max_tx, max_ty: max_ty,
            shade: nds_object_face_shade(fkind), bitmap: nil, sprite: nil
          }
          nds_object_add_face(face)
        else
          min_tx = [x0, x1].min.floor
          min_ty = [y0, y1].min.floor
          max_tx = [[x0, x1].max.ceil - 1, min_tx].max
          max_ty = [[y0, y1].max.ceil - 1, min_ty].max
          if kind == "top"
            z = z1
            world = [x0 * tw, y0 * th, z,
                     x1 * tw, y0 * th, z,
                     x1 * tw, y1 * th, z,
                     x0 * tw, y1 * th, z]
            face = {
              kind: :top, obj: pseudo, world: world,
              px_w: ((x1 - x0).abs * tw).round,
              px_h: ((y1 - y0).abs * th).round,
              min_tx: min_tx, min_ty: min_ty, max_tx: max_tx, max_ty: max_ty,
              shade: nds_object_face_shade(:top), bitmap: nil, sprite: nil
            }
            nds_object_add_face(face)
          else
            next if z1 <= z0 + 0.01
            edge = mf[:edge].to_s
            next if !["north", "south", "east", "west"].include?(edge)
            world = [x0 * tw, y0 * th, z1,
                     x1 * tw, y1 * th, z1,
                     x1 * tw, y1 * th, z0,
                     x0 * tw, y0 * th, z0]
            fkind = ["north", "south"].include?(edge) ? :front : :side
            length = if (x1 - x0).abs > 0.001
                       (x1 - x0).abs * tw
                     else
                       (y1 - y0).abs * th
                     end
            face = {
              kind: fkind, edge: edge, obj: pseudo, world: world,
              px_w: length.round, px_h: (z1 - z0).abs.round,
              min_tx: min_tx, min_ty: min_ty, max_tx: max_tx, max_ty: max_ty,
              shade: nds_object_face_shade(fkind), bitmap: nil, sprite: nil
            }
            nds_object_add_face(face)
          end
        end
      rescue Exception => e
        Console.echo_error("2.5D region mesh face: #{e.message}") if defined?(Console)
      end
    end
  end

  def build_nds_geometry_objects
    @nds_object_faces = []
    @nds_object_buckets = Hash.new { |h, k| h[k] = [] }
    @nds_object_active = []
    objs = nds_geometry_objects || []
    mesh_faces = nds_geometry_mesh_faces || []
    return if objs.empty? && mesh_faces.empty?

    tw = Game_Map::TILE_WIDTH.to_f
    th = Game_Map::TILE_HEIGHT.to_f
    step = @nds_surface_geometry ? @nds_surface_geometry.height_step.to_f : 32.0
    step = 32.0 if step <= 0.0

    # Unity-like Connect Neighbours component: source-compiled 1x1 cubes that
    # share category/base/top remove their touching internal side faces.
    @nds_object_connect_index = Hash.new { |h, k| h[k] = [] }
    objs.each do |obj|
      comps = obj[:components].is_a?(Hash) ? obj[:components] : {}
      next if comps["connect_neighbors"] != true
      next if obj[:type].to_s != "cube"
      (obj[:y].to_i...(obj[:y].to_i + [obj[:h].to_i, 1].max)).each do |ty|
        (obj[:x].to_i...(obj[:x].to_i + [obj[:w].to_i, 1].max)).each do |tx|
          @nds_object_connect_index[[tx, ty]] << obj
        end
      end
    end

    objs.each do |obj|
      begin
        next if obj[:render] == false
        x0 = obj[:x].to_i * tw
        y0 = obj[:y].to_i * th
        x1 = (obj[:x].to_i + obj[:w].to_i) * tw
        y1 = (obj[:y].to_i + obj[:h].to_i) * th
        base_z = obj[:anchor_z].to_f * step
        is_cube = obj[:type].to_s == "cube"
        top_z = is_cube ? base_z + obj[:height].to_f * step : base_z
        comps = obj[:components].is_a?(Hash) ? obj[:components] : {}
        min_tx = obj[:x].to_i
        min_ty = obj[:y].to_i
        max_tx = min_tx + obj[:w].to_i - 1
        max_ty = min_ty + obj[:h].to_i - 1

        # Cara superior. Planes always need it; cubes can disable Cap.
        if !is_cube || comps["cap"] != false
          top = {
            kind: :top, obj: obj,
            world: [x0, y0, top_z, x1, y0, top_z, x1, y1, top_z, x0, y1, top_z],
            px_w: ((x1 - x0)).round, px_h: ((y1 - y0)).round,
            min_tx: min_tx, min_ty: min_ty, max_tx: max_tx, max_ty: max_ty,
            shade: nds_object_face_shade(:top)
          }
          top[:bitmap] = nil
          top[:sprite] = nil
          nds_object_add_face(top)
        end

        if is_cube && top_z > base_z + 0.01
          faces = [
            { kind: :front, edge: "south",
              world: [x0, y1, top_z, x1, y1, top_z, x1, y1, base_z, x0, y1, base_z],
              px_w: (x1 - x0).round, px_h: (top_z - base_z).round },
            { kind: :front, edge: "north",
              world: [x1, y0, top_z, x0, y0, top_z, x0, y0, base_z, x1, y0, base_z],
              px_w: (x1 - x0).round, px_h: (top_z - base_z).round },
            { kind: :side, edge: "east",
              world: [x1, y0, top_z, x1, y1, top_z, x1, y1, base_z, x1, y0, base_z],
              px_w: (y1 - y0).round, px_h: (top_z - base_z).round },
            { kind: :side, edge: "west",
              world: [x0, y1, top_z, x0, y0, top_z, x0, y0, base_z, x0, y1, base_z],
              px_w: (y1 - y0).round, px_h: (top_z - base_z).round },
          ]
          faces.each do |spec|
            if comps["connect_neighbors"] == true
              ntx, nty = obj[:x].to_i, obj[:y].to_i
              case spec[:edge]
              when "south" then nty = obj[:y].to_i + obj[:h].to_i
              when "north" then nty = obj[:y].to_i - 1
              when "east"  then ntx = obj[:x].to_i + obj[:w].to_i
              when "west"  then ntx = obj[:x].to_i - 1
              end
              next if nds_object_connected_at?(obj, ntx, nty, base_z, top_z, step)
            end
            face = {
              kind: spec[:kind], edge: spec[:edge], obj: obj,
              world: spec[:world], px_w: spec[:px_w], px_h: spec[:px_h],
              min_tx: min_tx, min_ty: min_ty, max_tx: max_tx, max_ty: max_ty,
              shade: nds_object_face_shade(spec[:kind]),
              bitmap: nil, sprite: nil
            }
            nds_object_add_face(face)
          end
        end
      rescue Exception => e
        Console.echo_error("2.5D geometry object build: #{e.message}") if defined?(Console)
      end
    end
    nds_object_build_region_mesh_faces(tw, th, step)
  rescue Exception => e
    Console.echo_error("2.5D geometry objects build: #{e.message}") if defined?(Console)
    dispose_nds_geometry_objects
  end

  def nds_object_key
    step = Mode7::Config::NDS_OBJECT_REPROJECT_STEP.to_f
    step = 1.0 if step <= 0.0
    [(Mode7.cam_x / step).round,
     (Mode7.projection_cam_y / step).round,
     Mode7.projection_cam_elevation.to_f.round(3),
     Mode7.instance_variable_get(:@current_alpha).to_f.round(3),
     Mode7.instance_variable_get(:@zoom).to_f.round(4),
     Mode7.projection_revision]
  end

  def prune_nds_object_face_cache(active_indices)
    return if !Mode7::Config.const_defined?(:NDS_OBJECT_FACE_CACHE_MAX)
    max = Mode7::Config::NDS_OBJECT_FACE_CACHE_MAX.to_i
    return if max <= 0
    live = []
    (@nds_object_faces || []).each_with_index do |face, i|
      spr = face[:sprite]
      live << [face[:last_used].to_i, i] if spr && !spr.disposed?
    end
    return if live.length <= max
    active = {}
    active_indices.each { |i| active[i] = true }
    live.sort_by! { |pair| pair[0] }
    live_count = live.length
    live.each do |_stamp, i|
      next if active[i]
      face = @nds_object_faces[i]
      spr = face[:sprite]
      bmp = face[:bitmap]
      begin
        spr.corners = nil if spr && !spr.disposed? && Mode7::MKXPZExt.corners?
      rescue Exception
      end
      spr.dispose if spr && !spr.disposed?
      bmp.dispose if bmp && !bmp.disposed? && !face[:bitmap_shared]
      face[:sprite] = nil
      face[:bitmap] = nil
      live_count -= 1
      break if live_count <= max
    end
  rescue Exception
  end

  def update_nds_geometry_objects
    return if !@nds_object_faces || @nds_object_faces.empty?
    key = nds_object_key
    return if @nds_object_projection_key == key
    @nds_object_projection_key = key

    bs = Mode7::Config::NDS_RUNTIME_BUCKET_SIZE.to_i
    bs = 8 if bs <= 0
    cam_tx = (Mode7.cam_x / Game_Map::TILE_WIDTH).floor
    cam_ty = (Mode7.cam_y / Game_Map::TILE_HEIGHT).floor
    rx = Mode7::Config::NDS_OBJECT_CULL_TILES_X.to_i
    ry = Mode7::Config::NDS_OBJECT_CULL_TILES_Y.to_i
    bx0 = (cam_tx - rx) / bs
    bx1 = (cam_tx + rx) / bs
    by0 = (cam_ty - ry) / bs
    by1 = (cam_ty + ry) / bs

    visibility_key = [cam_tx, cam_ty, rx, ry, bs]
    if @nds_object_visibility_key != visibility_key || !@nds_object_visible_indices
      seen = {}
      bx = bx0
      while bx <= bx1
        by = by0
        while by <= by1
          (@nds_object_buckets[[bx, by]] || []).each { |i| seen[i] = true }
          by += 1
        end
        bx += 1
      end
      @nds_object_visible_indices = seen.keys
      @nds_object_visibility_key = visibility_key
    end
    indices = @nds_object_visible_indices || []
    index_lookup = {}
    indices.each { |i| index_lookup[i] = true }

    (@nds_object_active || []).each do |i|
      next if index_lookup[i]
      spr = @nds_object_faces[i][:sprite]
      spr.visible = false if spr && !spr.disposed?
    end

    active = []
    build_budget = if Mode7::Config.const_defined?(:NDS_OBJECT_FACE_BUILD_BUDGET)
                     Mode7::Config::NDS_OBJECT_FACE_BUILD_BUDGET.to_i
                   else
                     8
                   end
    build_budget = 1 if build_budget < 1
    deferred = false
    frame_stamp = Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : 0

    indices.each do |i|
      face = @nds_object_faces[i]
      spr = face[:sprite]
      if !spr || spr.disposed?
        if build_budget <= 0
          deferred = true
          next
        end
        bmp = face[:bitmap]
        if !bmp || bmp.disposed?
          bmp = nds_object_face_bitmap(face[:obj], face)
          face[:bitmap] = bmp
        end
        spr = Sprite.new(@viewport)
        spr.bitmap = bmp
        spr.visible = false
        spr.z = -998
        spr.color.set(0, 0, 0, face[:shade].to_i.clamp(0, 255))
        mat = face[:obj][:material]
        spr.opacity = mat.is_a?(Hash) && mat.key?("opacity") ? mat["opacity"].to_i.clamp(0, 255) : 255
        face[:sprite] = spr
        build_budget -= 1
      end

      face[:last_used] = frame_stamp
      points = nds_object_project_points(face[:world])
      if !points
        spr.visible = false
        next
      end
      xs = [points[0], points[2], points[4], points[6]]
      ys = [points[1], points[3], points[5], points[7]]
      margin = 40.0
      visible = xs.max >= -margin && xs.min <= Mode7.screen_w + margin &&
                ys.max >= -margin && ys.min <= Mode7.screen_h + margin
      spr.visible = visible
      next if !visible
      spr.corners = points
      w = face[:world]
      center_world_y = (w[1] + w[4] + w[7] + w[10]) / 4.0
      center_world_z = (w[2] + w[5] + w[8] + w[11]) / 4.0
      depth_bias = face[:obj][:characters_in_front] ? -8 : -2
      spr.z = Mode7.depth_z_at_elevation(center_world_y, center_world_z, 0, depth_bias)
      spr.tone = @tone
      active << i
    end
    @nds_object_active = active
    prune_nds_object_face_cache(active) if frame_stamp > 0 && (frame_stamp % 180) == 0
    # Continue lazily creating faces on following frames without freezing the
    # first map frame. Existing faces stay visible while the queue finishes.
    @nds_object_projection_key = nil if deferred
  rescue Exception => e
    Console.echo_error("2.5D geometry objects update: #{e.message}") if defined?(Console)
  end
end
