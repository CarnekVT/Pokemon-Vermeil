#===============================================================================
# [VERMEIL] Visual 2.5D - 022_NDSNativeGround.rb
# V5.5 - Plano de suelo persistente proyectado en GPU para mkxp-z-ext.
#
# Reemplaza las bandas Sprite#corners por un unico quad con perspectiva exacta.
# Ruby solo actualiza cinco uniforms cuando cambia la camara; el bitmap del mapa
# permanece en GPU y no se vuelve a rasterizar durante el movimiento.
#===============================================================================

class Mode7Renderer
  NDS_NATIVE_GROUND_SHADER_PATH =
    "Plugins/[VERMEIL] Visual 2.5D/Shaders/nds_ground.frag"

  if private_method_defined?(:update_nds_ground) &&
     !private_method_defined?(:_VERMEIL_V55_band_update_nds_ground)
    alias_method :_VERMEIL_V55_band_update_nds_ground, :update_nds_ground
  end
  if private_method_defined?(:dispose_nds_ground) &&
     !private_method_defined?(:_VERMEIL_V55_band_dispose_nds_ground)
    alias_method :_VERMEIL_V55_band_dispose_nds_ground, :dispose_nds_ground
  end
  if private_method_defined?(:apply_tone_color) &&
     !private_method_defined?(:_VERMEIL_V55_orig_apply_tone_color)
    alias_method :_VERMEIL_V55_orig_apply_tone_color, :apply_tone_color
  end

  private

  def nds_native_ground_enabled?
    return false if @nds_native_ground_failed
    return false if !Mode7::Config::NDS_NATIVE_GROUND_SHADER
    Mode7::MKXPZExt.shader? && Mode7.perspective_mode?
  rescue Exception
    false
  end

  def ensure_nds_native_ground
    return false if !nds_native_ground_enabled?
    if @nds_native_ground_sprite && !@nds_native_ground_sprite.disposed? &&
       @nds_native_ground_shader && !@nds_native_ground_shader.disposed?
      if @nds_native_ground_sprite.bitmap != @ground
        @nds_native_ground_sprite.bitmap = @ground
      end
      return true
    end

    dispose_nds_native_ground
    @nds_native_ground_shader = Shader.new(NDS_NATIVE_GROUND_SHADER_PATH)
    @nds_native_ground_sprite = Sprite.new(@viewport)
    @nds_native_ground_sprite.bitmap = @ground
    @nds_native_ground_sprite.shader = @nds_native_ground_shader
    @nds_native_ground_sprite.x = 0
    @nds_native_ground_sprite.y = 0
    @nds_native_ground_sprite.ox = 0
    @nds_native_ground_sprite.oy = 0
    @nds_native_ground_sprite.z = -1000
    @nds_native_ground_sprite.visible = false
    true
  rescue Exception => e
    nds_disable_native_ground(e)
    false
  end

  def dispose_nds_native_ground
    spr = @nds_native_ground_sprite
    shader = @nds_native_ground_shader
    if spr && !spr.disposed?
      begin
        spr.shader = nil
      rescue Exception
      end
      spr.dispose
    end
    shader.dispose if shader && !shader.disposed?
    @nds_native_ground_sprite = nil
    @nds_native_ground_shader = nil
    @nds_native_ground_key = nil
  rescue Exception
    @nds_native_ground_sprite = nil
    @nds_native_ground_shader = nil
    @nds_native_ground_key = nil
  end

  def dispose_nds_ground
    dispose_nds_native_ground
    _VERMEIL_V55_band_dispose_nds_ground
  end

  def nds_disable_native_ground(error)
    @nds_native_ground_failed = true
    dispose_nds_native_ground
    return if @nds_native_ground_error_logged
    @nds_native_ground_error_logged = true
    if defined?(Console)
      Console.echo_error("2.5D GPU ground fallback: #{error.message}")
    end
  rescue Exception
  end

  def nds_native_ground_key
    [
      Mode7.cam_x.to_f.round(4),
      Mode7.projection_cam_y.to_f.round(4),
      Mode7.perspective_pivot_world_y.to_f.round(4),
      Mode7.projection_cam_elevation.to_f.round(4),
      Mode7.projection_revision
    ]
  end

  def update_nds_native_ground_uniforms
    math = Mode7.nds_camera_math
    shader = @nds_native_ground_shader
    shader.set_vec2("u_camera", Mode7.cam_x.to_f,
                    Mode7.perspective_pivot_world_y.to_f)
    shader.set_vec2("u_optics", math[:distance].to_f, math[:focal].to_f)
    shader.set_vec2("u_angle", math[:sin].to_f, math[:cos_raw].to_f)
    shader.set_vec2("u_screen", Mode7.center_x.to_f, Mode7.pivot_y.to_f)
    shader.set_float("u_camera_elevation", Mode7.projection_cam_elevation.to_f)
    near = Mode7::Config::PERSPECTIVE_NEAR_CLIP.to_f
    near = 8.0 if near <= 0.0
    shader.set_float("u_near", near)
  end

  def update_nds_ground(force = false)
    return _VERMEIL_V55_band_update_nds_ground(force) if !nds_native_ground_enabled?
    return if !nds_ground_active?
    build_nds_ground if !@nds_ground_pool ||
                        @nds_ground_bitmap_id != @ground.object_id
    return _VERMEIL_V55_band_update_nds_ground(force) if !ensure_nds_native_ground

    key = nds_native_ground_key
    return if !force && @nds_native_ground_key == key
    @nds_native_ground_key = key

    min_y, max_y = nds_visible_world_y_range
    x0, x1 = nds_visible_world_x_range(min_y, max_y)
    sx0 = x0.floor.clamp(0, @ground.width)
    sx1 = x1.ceil.clamp(0, @ground.width)
    sy0 = min_y.floor.clamp(0, @ground.height)
    sy1 = max_y.ceil.clamp(0, @ground.height)

    spr = @nds_native_ground_sprite
    if sx1 <= sx0 || sy1 <= sy0
      spr.visible = false
      hide_unused_nds_ground(0)
      return
    end

    spr.bitmap = @ground if spr.bitmap != @ground
    spr.src_rect.set(sx0, sy0, sx1 - sx0, sy1 - sy0)
    spr.z = -1000
    spr.tone = @tone
    spr.color = @color
    update_nds_native_ground_uniforms
    spr.visible = true
    hide_unused_nds_ground(0)
  rescue Exception => e
    nds_disable_native_ground(e)
    _VERMEIL_V55_band_update_nds_ground(force)
  end

  def apply_tone_color
    _VERMEIL_V55_orig_apply_tone_color
    spr = @nds_native_ground_sprite
    return if !spr || spr.disposed?
    spr.tone = @tone
    spr.color = @color
  end
end
