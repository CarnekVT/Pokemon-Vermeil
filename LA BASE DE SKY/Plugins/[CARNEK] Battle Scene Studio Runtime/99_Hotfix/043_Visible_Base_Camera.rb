# frozen_string_literal: true
# BSS keeps the persistent camera and EBDX projection. This patch improves the
# nearly imperceptible ambient movement without altering the attack timeline
# (which belongs exclusively to BAS). All values may be overridden in camera
# config, and the static profile is respected.

module BSSVisibleCameraOptions
  DEFAULT_AMBIENT_BOOST = true
  DEFAULT_PAN_X = 22.0
  DEFAULT_PAN_Y = 10.0
  DEFAULT_ZOOM_STRENGTH = 0.07
  MIN_HOLD_FRAMES = 100
end

module BSSVisibleBaseCamera
  def bss_layered_next_ebdx_shot
    return super unless respond_to?(:bss_layered_camera_active?) && bss_layered_camera_active?
    return if respond_to?(:bss_shared_camera_leased?) && bss_shared_camera_leased?
    return if @bss098_native_move_active || @bss096_move_projection_active || @bss087_native_move_active
    cfg = respond_to?(:bss_layered_camera_config) ? bss_layered_camera_config : {}
    cfg = {} unless cfg.is_a?(Hash)
    return super if cfg.fetch("sharedCameraAmbientBoost", BSSVisibleCameraOptions::DEFAULT_AMBIENT_BOOST) == false
    return super unless @vector && defined?(BSS070EBDXCore)
    main = BSS070EBDXCore.get_vector(:MAIN, @battle)
    return super unless main.is_a?(Array) && main.length >= 6

    strength = [[(cfg["idleStrength"] || 40).to_f / 100.0, 0.0].max, 1.0].min
    return super if strength <= 0.0
    speed = [[(cfg["idleSpeed"] || 50).to_f / 100.0, 0.1].max, 1.5].min
    xfactor = [[(cfg["panX"] || 100).to_f / 100.0, 0.0].max, 2.0].min
    yfactor = [[(cfg["panY"] || 100).to_f / 100.0, 0.0].max, 2.0].min
    zfactor = [[(cfg["zoom"] || 100).to_f / 100.0, 0.0].max, 2.0].min
    phase = @bss_layered_camera_index.to_i
    weight = 0.25 + strength * 0.75
    pan_x = BSSVisibleCameraOptions::DEFAULT_PAN_X * weight * xfactor
    pan_y = BSSVisibleCameraOptions::DEFAULT_PAN_Y * weight * yfactor
    zoom = BSSVisibleCameraOptions::DEFAULT_ZOOM_STRENGTH * weight * zfactor
    target = main.map { |value| value.to_f }
    # Deterministic alternating composition; bounded so the room's sky and
    # battle platforms retain their designed horizon and no accumulating drift.
    target[0] += Math.sin(phase * 1.7 + 0.7) * pan_x
    target[1] += Math.cos(phase * 1.3) * pan_y
    target[4] = main[4].to_f * (1.0 + zoom * (0.55 + 0.45 * Math.sin(phase * 1.31 + 0.4)))
    target[5] = main[5].to_f * (1.0 + zoom * (0.55 + 0.45 * Math.sin(phase * 1.31 + 0.4)))
    @vector.inc = 0.016 + speed * 0.015 if @vector.respond_to?(:inc=)
    @vector.set(target)
    @bss_layered_camera_index = phase + 1
    @bss_layered_camera_due = @bss_layered_camera_tick.to_i +
      [[(185 - speed * 65).round, BSSVisibleCameraOptions::MIN_HOLD_FRAMES].max, 240].min
  rescue StandardError => e
    BSS064.log("BSS visible camera: #{e.class}: #{e.message}") if defined?(BSS064)
    super
  end
end

if defined?(Battle::Scene) &&
   !Battle::Scene.ancestors.include?(BSSVisibleBaseCamera)
  Battle::Scene.prepend(BSSVisibleBaseCamera)
end