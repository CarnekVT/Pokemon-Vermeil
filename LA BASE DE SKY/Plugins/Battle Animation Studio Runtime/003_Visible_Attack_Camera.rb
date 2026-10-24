# frozen_string_literal: true
# BAS visual camera defaults for exported moves (BSS and Vanilla battles).
# BAS is the ONLY author of attack-shot choreography. BSS provides the existing
# camera's world transform; BAS applies a render-only relative shot to that world.
# Custom camera keyframes ALWAYS take priority over these automatic defaults.

module BASVisibleAttackCameraSettings
  ENABLED = true
  AUTO_WITHOUT_BSS = true # BAS remains the attack-camera author in Vanilla too.
  USER_ZOOM   = 1.095
  TARGET_ZOOM = 1.135
  WIDE_ZOOM   = 1.055
  PAN_FRACTION_X = 0.32
  PAN_FRACTION_Y = 0.25
  RETURN_SECONDS = 0.20  # Existing BAS/BSS bridge handles the easing tail.
end

module BASVisibleAttackCamera
  def initialize(*args)
    super
    @bas_visible_auto = bas_visible_auto_camera?
  end

  # Never replace animation data saved in BAS. Even one camera key, follow
  # directive, or custom baseline means the author is in charge.
  def bas_visible_authored_camera?(camera)
    return false unless camera.is_a?(Hash)
    visual = camera["visual"].is_a?(Hash) ? camera["visual"] : {}
    return true if visual["cameraX"].to_f.abs > 0.001
    return true if visual["cameraY"].to_f.abs > 0.001
    return true if visual["cameraRotation"].to_f.abs > 0.001
    return true if visual.key?("cameraZoom") && (visual["cameraZoom"].to_f - 100.0).abs > 0.001
    keys = camera["valueKeys"].is_a?(Hash) ? camera["valueKeys"] : {}
    ["cameraX", "cameraY", "cameraZoom", "cameraRotation"].each do |name|
      return true if keys[name].is_a?(Array) && !keys[name].empty?
    end
    events = camera["logic"].is_a?(Array) ? camera["logic"] : []
    return true if events.any? { |event| event.is_a?(Hash) && ["focus", "follow", "focus_clear"].include?(event["type"].to_s.downcase) }
    false
  end

  def bas_visible_auto_camera?
    return false unless BASVisibleAttackCameraSettings::ENABLED
    return false if !@bas_bss_camera_scene && !BASVisibleAttackCameraSettings::AUTO_WITHOUT_BSS
    return false unless @data.is_a?(Hash)
    source = @data["source"].is_a?(Hash) ? @data["source"] : {}
    # No auto camera on common/status/intro/custom animations.
    catalog = source["catalogType"].to_s.downcase
    return false if ["common", "custom"].include?(catalog)
    camera = @data["camera"].is_a?(Hash) ? @data["camera"] : {}
    return false if camera["enabled"] == false || camera["autoCinematic"] == false
    return false if bas_visible_authored_camera?(camera)
    true
  rescue StandardError
    false
  end

  def bas_visible_shot_role
    source = @data["source"].is_a?(Hash) ? @data["source"] : {}
    scope = source["targetScope"].to_s.downcase
    return :wide if scope =~ /(?:all|spread|multi|field|environment|side|everyone)/
    return :self if scope =~ /(?:single_user|self|user_only)/
    return :wide if @explicit_targets.is_a?(Array) && @explicit_targets.length > 1
    return :self unless @target && @target != @user
    :single
  end

  def bas_visible_anchor(side)
    key = side == :user ? :user : :target
    baseline = @original.is_a?(Hash) ? @original[key] : nil
    if baseline.is_a?(Hash) && baseline.key?(:x) && baseline.key?(:y)
      return [baseline[:x].to_f, baseline[:y].to_f]
    end
    camera_follow_point(key)
  rescue StandardError
    [(Graphics.width rescue 512) / 2.0, (Graphics.height rescue 384) / 2.0]
  end

  def bas_visible_smooth(value)
    t = [[value.to_f, 0.0].max, 1.0].min
    t * t * (3.0 - 2.0 * t)
  end

  def bas_visible_lerp(a, b, t)
    a.to_f + (b.to_f - a.to_f) * bas_visible_smooth(t)
  end

  def bas_visible_frame_shot(frame)
    width = [(Graphics.width.to_f rescue 512.0), 1.0].max
    height = [(Graphics.height.to_f rescue 384.0), 1.0].max
    center = [width / 2.0, height / 2.0]
    role = bas_visible_shot_role
    if role == :wide
      zoom = bas_visible_lerp(1.0, BASVisibleAttackCameraSettings::WIDE_ZOOM, frame / 0.25)
      return [0.0, 0.0, zoom]
    end
    user = bas_visible_anchor(:user)
    target = (role == :self) ? user : bas_visible_anchor(:target)
    ratio_x = BASVisibleAttackCameraSettings::PAN_FRACTION_X
    ratio_y = BASVisibleAttackCameraSettings::PAN_FRACTION_Y
    a = [(user[0] - center[0]) * ratio_x, (user[1] - center[1]) * ratio_y, BASVisibleAttackCameraSettings::USER_ZOOM]
    b = [(target[0] - center[0]) * ratio_x, (target[1] - center[1]) * ratio_y, BASVisibleAttackCameraSettings::TARGET_ZOOM]
    if role == :self
      step = bas_visible_smooth(frame / 0.22)
      return [a[0] * step, a[1] * step, 1.0 + (a[2] - 1.0) * step]
    end
    if frame < 0.26
      t = bas_visible_smooth(frame / 0.26)
      return [a[0] * t, a[1] * t, 1.0 + (a[2] - 1.0) * t]
    end
    if frame < 0.66
      t = bas_visible_smooth((frame - 0.26) / 0.40)
      return [bas_visible_lerp(a[0], b[0], t), bas_visible_lerp(a[1], b[1], t), bas_visible_lerp(a[2], b[2], t)]
    end
    b
  end

  def camera_state
    state = super
    return state unless @bas_visible_auto && !@bas_bss_camera_tail
    len = [duration.to_f, 1.0].max
    progress = [[@frame.to_f / len, 0.0].max, 1.0].min
    x, y, zoom = bas_visible_frame_shot(progress)
    # The camera is composed around the current BSS scene, so protect against
    # revealing undersized battleback edges in both screen directions.
    width = [(Graphics.width.to_f rescue 512.0), 1.0].max
    height = [(Graphics.height.to_f rescue 384.0), 1.0].max
    zoom = [[zoom.to_f, 1.0].max, 1.20].min
    safety_x = [(width * (zoom - 1.0) / (2.0 * zoom)) - 3.0, 0.0].max
    safety_y = [(height * (zoom - 1.0) / (2.0 * zoom)) - 3.0, 0.0].max
    state[:x] = [[x, -safety_x].max, safety_x].min
    state[:y] = [[y, -safety_y].max, safety_y].min
    state[:zoom] = zoom
    # Rotation, shake and other manually authored BAS effects remain untouched.
    state
  rescue StandardError => e
    BattleAnimationStudioRuntime.log("auto camera: #{e.class}: #{e.message}") if defined?(BattleAnimationStudioRuntime)
    state || super
  end
end

if defined?(BattleAnimationStudioRuntime::Player) &&
   !BattleAnimationStudioRuntime::Player.ancestors.include?(BASVisibleAttackCamera)
  BattleAnimationStudioRuntime::Player.prepend(BASVisibleAttackCamera)
end