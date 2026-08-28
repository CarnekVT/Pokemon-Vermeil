#===============================================================================
# [VERMEIL] Visual 2.5D - 025_V25SkyGroundBands.rb
# V25 Phase 2A FIX1 - Sky-safe exact persistent ground scanlines
#
# Sky's stock mkxp-z has no Sprite#corners and no custom Shader API. The old
# compatibility path therefore rebuilt the projected floor into a screen-sized
# Bitmap with many Bitmap#stretch_blt calls whenever the camera moved.
#
# This backend keeps the already-composed map bitmap (@ground) untouched and
# displays persistent Sprite scanlines that reference it directly. FIX1 uses an
# exact one-row plan in Perspective/Affine: the previous adaptive 8/16/32-row
# approximation was fast, but its independently quantized source rectangles
# produced a visible wave/shimmer while the camera moved.
#===============================================================================

module Mode7
  module Config
    V25_SKY_GROUND_BANDS = true unless const_defined?(:V25_SKY_GROUND_BANDS)
    # V25 PATCH3: visual parity first. The new executable may expose corners
    # and Shader, but ground keeps the tested Sky adaptive-band renderer until
    # the GPU ground path has exact near-plane/source-coverage parity.
    V25_NEXT_SAFE_GROUND_BANDS = true unless const_defined?(:V25_NEXT_SAFE_GROUND_BANDS)

    # Phase 2.3.1: the adaptive plan applies to BOTH :perspective and :affine.
    # Phase 2.3 accidentally enabled it only for Affine, so Perspective maps
    # still used one Sprite per screen row (480 bands at 640x480).
    # 0.10 px keeps the approximation well below one visible pixel.
    V25_SKY_AFFINE_ADAPTIVE_BANDS = false unless const_defined?(:V25_SKY_AFFINE_ADAPTIVE_BANDS)
    V25_SKY_AFFINE_MAX_BAND_HEIGHT = 1 unless const_defined?(:V25_SKY_AFFINE_MAX_BAND_HEIGHT)
    V25_SKY_AFFINE_MAX_SCREEN_ERROR = 0.0 unless const_defined?(:V25_SKY_AFFINE_MAX_SCREEN_ERROR)

    # Exact compatibility switch. Setting this to 1 and disabling adaptive bands
    # reproduces the Phase 2.2 one-row-per-Sprite path.
    V25_SKY_AFFINE_BAND_HEIGHT = 1 unless const_defined?(:V25_SKY_AFFINE_BAND_HEIGHT)
  end
end

class Mode7Renderer
  if private_method_defined?(:draw_ground) &&
     !private_method_defined?(:_VERMEIL_V25P22_legacy_draw_ground)
    alias_method :_VERMEIL_V25P22_legacy_draw_ground, :draw_ground
  end
  if method_defined?(:dispose) &&
     !method_defined?(:_VERMEIL_V25P22_ground_dispose)
    alias_method :_VERMEIL_V25P22_ground_dispose, :dispose
  end

  def dispose
    dispose_v25_sky_ground_bands
    _VERMEIL_V25P22_ground_dispose
  end

  private

  def v25_sky_ground_bands_enabled?
    return false if !Mode7::Config::V25_SKY_GROUND_BANDS
    return false if !Mode7.respond_to?(:perspective_mode?) || !Mode7.perspective_mode?
    safe = Mode7::Config.const_defined?(:V25_NEXT_SAFE_GROUND_BANDS) &&
           Mode7::Config::V25_NEXT_SAFE_GROUND_BANDS
    return true if safe
    return false if Mode7::MKXPZExt.corners?
    return false if Mode7::MKXPZExt.shader?
    true
  rescue Exception
    false
  end

  def v25_sky_ground_band_height
    if Mode7.cylindrical_mode? &&
       Mode7::Config.const_defined?(:CYLINDRICAL_RASTER_SCAN_STEP)
      n = Mode7::Config::CYLINDRICAL_RASTER_SCAN_STEP.to_i
      return n > 0 ? n : 1
    end
    n = Mode7::Config::V25_SKY_AFFINE_BAND_HEIGHT.to_i
    n > 0 ? n : 1
  rescue Exception
    1
  end

  def v25_sky_ground_projective_band_error(sy, block_h)
    return 0.0 if block_h.to_i <= 1
    sy0 = sy.to_f
    sy1 = [sy0 + block_h.to_f, Mode7.screen_h - 1.0].min
    span = sy1 - sy0
    return 0.0 if span <= 1.0e-6

    wy0 = Mode7.world_y_for_row(sy0)
    wy1 = Mode7.world_y_for_row(sy1)
    return Float::INFINITY if !wy0 || !wy1

    max_error = 0.0
    [0.25, 0.50, 0.75].each do |f|
      sample_sy = sy0 + span * f
      linear_wy = wy0.to_f + (wy1.to_f - wy0.to_f) * f
      projected = Mode7.project_y(linear_wy, 0)
      return Float::INFINITY if !projected
      e = (projected.to_f - sample_sy).abs
      max_error = e if e > max_error
    end
    max_error
  rescue Exception
    Float::INFINITY
  end

  def v25_sky_ground_projective_plan(horizon)
    @v25_sky_ground_projective_plan ||= []
    max_h = Mode7::Config::V25_SKY_AFFINE_MAX_BAND_HEIGHT.to_i
    max_h = 1 if max_h < 1
    max_h = 64 if max_h > 64
    max_error = Mode7::Config::V25_SKY_AFFINE_MAX_SCREEN_ERROR.to_f
    max_error = 0.0 if max_error < 0.0
    adaptive = Mode7::Config::V25_SKY_AFFINE_ADAPTIVE_BANDS

    mode = Mode7.respond_to?(:map_mode) ? Mode7.map_mode : :unknown
    cam_elev = Mode7.respond_to?(:projection_cam_elevation) ? Mode7.projection_cam_elevation.to_f.round(3) : 0.0
    key = [Mode7.projection_revision.to_i, Mode7.screen_h.to_i,
           horizon.to_i, max_h, max_error, adaptive, mode, cam_elev]
    return @v25_sky_ground_projective_plan if @v25_sky_ground_projective_plan_key == key

    plan = []
    sy = horizon.to_i
    if !adaptive
      step = Mode7::Config::V25_SKY_AFFINE_BAND_HEIGHT.to_i
      step = 1 if step < 1
      while sy < Mode7.screen_h
        h = [step, Mode7.screen_h - sy].min
        plan << [sy, h]
        sy += h
      end
    else
      # Power-of-two candidates make the plan stable while camera position
      # changes. Projection revision invalidates it when optics actually change.
      candidates = [32, 16, 8, 4, 2, 1].select { |h| h <= max_h }
      candidates << max_h if !candidates.include?(max_h)
      candidates = candidates.uniq.sort.reverse

      while sy < Mode7.screen_h
        remaining = Mode7.screen_h - sy
        selected = 1
        candidates.each do |h|
          next if h > remaining
          if h <= 1 || v25_sky_ground_projective_band_error(sy, h) <= max_error
            selected = h
            break
          end
        end
        plan << [sy, selected]
        sy += selected
      end
    end

    @v25_sky_ground_projective_plan_key = key
    @v25_sky_ground_projective_plan = plan
    plan
  rescue Exception
    # Safe exact fallback.
    plan = []
    sy = horizon.to_i
    while sy < Mode7.screen_h
      plan << [sy, 1]
      sy += 1
    end
    @v25_sky_ground_projective_plan = plan
    plan
  end

  def v25_sky_ground_band_plan(horizon)
    # Perspective is the default outdoor/NDS mode. It has the same analytical
    # project_y/world_y_for_row pair as Affine, so the visual-error test is
    # valid for both and lets Sky render a few dozen bands instead of 480.
    if (Mode7.respond_to?(:perspective_mode?) && Mode7.perspective_mode?) || Mode7.affine_mode?
      return v25_sky_ground_projective_plan(horizon)
    end

    # Cylindrical keeps its existing raster step because its curved mapping is
    # intentionally controlled by CYLINDRICAL_RASTER_SCAN_STEP.
    step = v25_sky_ground_band_height
    plan = []
    sy = horizon.to_i
    while sy < Mode7.screen_h
      h = [step, Mode7.screen_h - sy].min
      plan << [sy, h]
      sy += h
    end
    plan
  end

  def v25_sky_tone_key(tone)
    return nil if !tone
    [tone.red, tone.green, tone.blue, tone.gray]
  rescue Exception
    tone.object_id
  end

  def v25_sky_color_key(color)
    return nil if !color
    [color.red, color.green, color.blue, color.alpha]
  rescue Exception
    color.object_id
  end

  def ensure_v25_sky_ground_band(index)
    @v25_sky_ground_bands ||= []
    spr = @v25_sky_ground_bands[index]
    if !spr || spr.disposed?
      spr = Sprite.new(@viewport)
      spr.ox = 0
      spr.oy = 0
      spr.angle = 0
      spr.z = -999
      spr.visible = false
      @v25_sky_ground_bands[index] = spr
    end
    spr.bitmap = @ground if spr.bitmap != @ground
    @v25_sky_ground_band_states ||= []
    @v25_sky_ground_band_states[index] ||= {}
    spr
  end

  def hide_v25_sky_ground_bands(from_index = 0)
    return if !@v25_sky_ground_bands
    i = from_index.to_i
    while i < @v25_sky_ground_bands.length
      spr = @v25_sky_ground_bands[i]
      if spr && !spr.disposed?
        spr.visible = false
        if @v25_sky_ground_band_states && @v25_sky_ground_band_states[i]
          @v25_sky_ground_band_states[i][:visible] = false
        end
      end
      i += 1
    end
    @v25_sky_ground_bands_used = from_index.to_i
  end

  def dispose_v25_sky_ground_bands
    if @v25_sky_ground_bands
      @v25_sky_ground_bands.each do |spr|
        spr.dispose if spr && !spr.disposed?
      rescue Exception
      end
    end
    @v25_sky_ground_bands = nil
    @v25_sky_ground_band_states = nil
    @v25_sky_ground_bands_used = 0
    @v25_sky_ground_background_key = nil
    @v25_sky_ground_band_fog = nil
    @v25_sky_ground_projective_plan = nil
    @v25_sky_ground_projective_plan_key = nil
  rescue Exception
    @v25_sky_ground_bands = nil
    @v25_sky_ground_bands_used = 0
  end

  def v25_sky_ground_color_for(fog_alpha)
    fog_alpha = fog_alpha.to_i.clamp(0, 255)
    base = @color
    return base if fog_alpha <= 0
    fog = Mode7::Config::FOG_COLOR
    ba = base ? base.alpha.to_i.clamp(0, 255) : 0
    if ba <= 0
      @v25_sky_ground_fog ||= {}
      return (@v25_sky_ground_fog[fog_alpha] ||= Color.new(fog.red, fog.green, fog.blue, fog_alpha))
    end

    # Compose the normal Sprite color overlay first, then the depth fog overlay.
    # This is only used when both effects are active at once (rare); ordinary
    # gameplay with fog disabled returns @color directly and allocates nothing.
    oa = fog_alpha + ((ba * (255 - fog_alpha)) / 255.0)
    oa = oa.round.clamp(1, 255)
    fr = fog_alpha.to_f / oa
    br = (ba * (255 - fog_alpha) / 255.0) / oa
    r = (fog.red * fr + base.red * br).round.clamp(0, 255)
    g = (fog.green * fr + base.green * br).round.clamp(0, 255)
    b = (fog.blue * fr + base.blue * br).round.clamp(0, 255)
    Color.new(r, g, b, oa)
  rescue Exception
    @color
  end

  def refresh_v25_sky_ground_background
    return if !@ground_sprite || @ground_sprite.disposed? ||
              !@ground_sprite.bitmap || @ground_sprite.bitmap.disposed?
    c = projection_fill_color
    key = [c.red, c.green, c.blue, c.alpha, Mode7.indoor_map?, Mode7.map_mode]
    if @v25_sky_ground_background_key != key
      @ground_sprite.bitmap.clear
      if c.alpha.to_i > 0
        @ground_sprite.bitmap.fill_rect(0, 0, Mode7.screen_w, Mode7.screen_h, c)
      end
      @v25_sky_ground_background_key = key
    end
    @ground_sprite.z = -1000
    @ground_sprite.visible = true
  end

  def draw_ground
    if !v25_sky_ground_bands_enabled?
      hide_v25_sky_ground_bands(0)
      return _VERMEIL_V25P22_legacy_draw_ground
    end
    return if !@ground || @ground.disposed?

    refresh_v25_sky_ground_background

    horizon = [Mode7.horizon_row.ceil, 0].max
    if horizon >= Mode7.screen_h
      hide_v25_sky_ground_bands(0)
      return
    end

    cx = Mode7.cam_x
    map_h_px = @map.height * Game_Map::TILE_HEIGHT
    ground_w = @ground.width
    screen_w = Mode7.screen_w
    center_x = Mode7.center_x
    has_fog = Mode7.respond_to?(:fog_alpha)
    band_plan = v25_sky_ground_band_plan(horizon)

    used = 0
    band_plan.each do |band_entry|
      sy = band_entry[0]
      block_h = band_entry[1]
      sample_sy = sy + (block_h - 1) * 0.5

      wy0 = Mode7.world_y_for_row(sy)
      wy1 = Mode7.world_y_for_row([sy + block_h, Mode7.screen_h - 1].min)
      wy = Mode7.world_y_for_row(sample_sy)
      if !wy || !wy0 || !wy1 || wy1 < 0 || wy0 >= map_h_px
        next
      end

      k = Mode7.hscale(sample_sy)
      if !k || k <= 0.001
        next
      end

      span = screen_w / k
      wx_left = cx - center_x / k
      lo = [wx_left.floor, 0].max
      hi = [(wx_left + span).ceil, ground_w].min
      if hi <= lo
        next
      end

      d_x0 = ((lo - wx_left) / span) * screen_w
      d_w = ((hi - wx_left) / span) * screen_w - d_x0
      d_x0_int = d_x0.round
      d_w_int = d_w.round
      if d_w_int <= 0
        next
      end

      src_top = [[wy0, wy1].min.floor, 0].max
      src_bottom = [[wy0, wy1].max.ceil, map_h_px].min
      src_h = [src_bottom - src_top, 1].max
      src_w = hi - lo
      if src_w <= 0
        next
      end

      spr = ensure_v25_sky_ground_band(used)
      state = @v25_sky_ground_band_states[used]

      src_key = [lo, src_top, src_w, src_h]
      if state[:src] != src_key
        spr.src_rect.set(lo, src_top, src_w, src_h)
        state[:src] = src_key
      end
      if state[:x] != d_x0_int
        spr.x = d_x0_int
        state[:x] = d_x0_int
      end
      if state[:y] != sy
        spr.y = sy
        state[:y] = sy
      end

      zx = d_w_int.to_f / src_w.to_f
      zy = block_h.to_f / src_h.to_f
      if state[:zx] != zx
        spr.zoom_x = zx
        state[:zx] = zx
      end
      if state[:zy] != zy
        spr.zoom_y = zy
        state[:zy] = zy
      end

      tone_key = v25_sky_tone_key(@tone)
      if state[:tone] != tone_key
        spr.tone = @tone
        state[:tone] = tone_key
      end
      fog_alpha = has_fog ? Mode7.fog_alpha(sample_sy).to_i : 0
      band_color = v25_sky_ground_color_for(fog_alpha)
      color_key = v25_sky_color_key(band_color)
      if state[:color] != color_key
        spr.color = band_color
        state[:color] = color_key
      end
      if state[:visible] != true
        spr.visible = true
        state[:visible] = true
      end
      used += 1
    end

    hide_v25_sky_ground_bands(used)
    @v25_sky_ground_bands_used = used
  rescue Exception => e
    # Never leave the map without a floor if a Sky-specific optimization hits
    # an unsupported edge case. Disable it for this renderer and use legacy.
    @v25_sky_ground_bands_failed = true
    hide_v25_sky_ground_bands(0)
    Console.echo_error("V25 Sky ground bands fallback: #{e.message}") if defined?(Console)
    _VERMEIL_V25P22_legacy_draw_ground
  end

  # Once an edge case fails, legacy stays authoritative for the map instance.
  alias_method :_VERMEIL_V25P22_enabled_raw, :v25_sky_ground_bands_enabled?
  def v25_sky_ground_bands_enabled?
    return false if @v25_sky_ground_bands_failed
    _VERMEIL_V25P22_enabled_raw
  end
end
