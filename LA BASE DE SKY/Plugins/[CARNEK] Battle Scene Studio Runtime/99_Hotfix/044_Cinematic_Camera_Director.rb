# frozen_string_literal: true
# Pokemon Vermeil - Battle Scene Studio cinematic camera v2
# A single scene-world camera, with BAS retaining exclusive move-camera control.
# Unlike old BSS patches, this director drives the EBDX vector AND the real
# battler/shadow screen anchors from the same absolute camera state.
# It does not import EBS scripts and leaves BAS animation timelines untouched.

module VermeilBSSCinema
  VERSION = "2.0.0"
  DEFAULTS = {
    "cinematicCamera" => true,
    "cinematicIdleZoom" => 1.045,
    "cinematicCommandZoom" => 1.105,
    "cinematicFightZoom" => 1.145,
    "cinematicSmooth" => 0.090,
    "cinematicIdlePan" => 8.0,
    "cinematicBattlerFollow" => 100.0
  }

  module_function

  def clamp(value, low, high)
    n = value.to_f
    [[n, low].max, high].min
  end

  def enabled?(scene)
    return false unless scene && scene.instance_variable_get(:@vector)
    return false unless defined?(BSS070EBDXCore)
    return false unless scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?
    return false if scene.respond_to?(:bss070_ebdx_camera_enabled?) && !scene.bss070_ebdx_camera_enabled?
    cfg = scene.respond_to?(:bss070_ebdx_camera_config) ? scene.bss070_ebdx_camera_config : BSS070EBDXCore.camera_config
    return false if cfg.is_a?(Hash) && cfg["cinematicCamera"] == false
    profile = (cfg.is_a?(Hash) ? (cfg["profile"] || cfg["preset"]) : nil).to_s.downcase
    !["static", "static_gen4", "off", "vanilla"].include?(profile)
  rescue StandardError
    false
  end

  def config(scene)
    cfg = scene.bss070_ebdx_camera_config rescue {}
    cfg = {} unless cfg.is_a?(Hash)
    DEFAULTS.merge(cfg)
  end
end

module VermeilBSSCinemaScene
  # Only presentation states are driven here. BAS's camera timeline retains
  # full authority over move shots, zoom/shake/focus and its own easing.
  def vermeil_cinema_active?
    VermeilBSSCinema.enabled?(self)
  end

  def vermeil_cinema_locked?
    return true if respond_to?(:bss_shared_camera_leased?) && bss_shared_camera_leased?
    return true if @bss070_ebdx_bas_frame || @bas_runtime_playback_depth.to_i > 0
    return true if @bss083_camera_freeze.to_i > 0 || @bss070_ebdx_suspend_depth.to_i > 0
    return true if @bss098_native_move_active || @bss096_move_projection_active
    return true if @bss087_native_move_active || @bss084_native_move_active
    return true if @bss096_native_formation_depth.to_i > 0 || @bss096_battler_anim_depth.to_i > 0
    return true if @bss087_end_battle_lock
    return true if (respond_to?(:inPartyAnimation?) && inPartyAnimation?)
    false
  rescue StandardError
    true
  end

  def vermeil_cinema_phase
    return :fight if @vermeil_cinema_fight_depth.to_i > 0
    return :command if @vermeil_cinema_command_depth.to_i > 0
    :idle
  end

  def vermeil_cinema_config
    VermeilBSSCinema.config(self)
  end

  def vermeil_cinema_vector
    main = BSS070EBDXCore.get_vector(:MAIN, @battle)
    return nil unless main && main.length >= 6
    main = main[0, 6].map { |v| v.to_f }
    cfg = vermeil_cinema_config
    phase = vermeil_cinema_phase
    strength = VermeilBSSCinema.clamp(cfg["idleStrength"] || 28, 0.0, 100.0) / 100.0
    pan_x = VermeilBSSCinema.clamp(cfg["panX"] || 100, 0.0, 200.0) / 100.0
    pan_y = VermeilBSSCinema.clamp(cfg["panY"] || 100, 0.0, 200.0) / 100.0
    pan_scale = phase == :idle ? (0.35 + 0.65 * strength) : 1.0
    # The existing BSS Studio camera sliders must keep affecting this new
    # director; otherwise the camera would look detached from the editor.
    command_weight = VermeilBSSCinema.clamp(cfg["commandStrength"] || 45, 0, 100) / 45.0
    fight_weight = VermeilBSSCinema.clamp(cfg["fightStrength"] || 65, 0, 100) / 65.0
    # No random cuts: coherent composition based on the camera's phase.
    tick = @vermeil_cinema_ticks.to_i
    breath = Math.sin(tick * 0.011)
    sway = Math.sin(tick * 0.007 + 1.0)
    zoom = case phase
           when :command then VermeilBSSCinema.clamp(cfg["cinematicCommandZoom"], 1.0, 1.20)
           when :fight then VermeilBSSCinema.clamp(cfg["cinematicFightZoom"], 1.0, 1.22)
           else VermeilBSSCinema.clamp(cfg["cinematicIdleZoom"], 1.0, 1.14)
           end
    # Respect original scene scale, using the EBDX vector as world authority.
    target = main.clone
    if phase == :command
      target[0] -= 17.0 * pan_x
      target[1] -= 5.0 * pan_y
      target[2] += 0.65
      target[3] -= 2.0
    elsif phase == :fight
      target[0] -= 27.0 * pan_x
      target[1] -= 8.0 * pan_y
      target[2] += 1.05
      target[3] -= 4.0
    else
      amplitude = VermeilBSSCinema.clamp(cfg["cinematicIdlePan"], 0, 20)
      target[0] += amplitude * breath * pan_x * pan_scale
      target[1] += 3.0 * sway * pan_y * pan_scale
      zoom += 0.010 * breath * strength
    end
    if phase == :command
      target[0] = main[0] + (target[0] - main[0]) * command_weight
      target[1] = main[1] + (target[1] - main[1]) * command_weight
      target[2] = main[2] + (target[2] - main[2]) * command_weight
      target[3] = main[3] + (target[3] - main[3]) * command_weight
      zoom = 1.0 + (zoom - 1.0) * command_weight
    elsif phase == :fight
      target[0] = main[0] + (target[0] - main[0]) * fight_weight
      target[1] = main[1] + (target[1] - main[1]) * fight_weight
      target[2] = main[2] + (target[2] - main[2]) * fight_weight
      target[3] = main[3] + (target[3] - main[3]) * fight_weight
      zoom = 1.0 + (zoom - 1.0) * fight_weight
    end
    zoom = VermeilBSSCinema.clamp(zoom, 1.0, 1.23)
    # Keep two zoom components equal; the prior stack sometimes stretched
    # the field vertically by modifying only one of them.
    target[4] = main[4] * zoom
    target[5] = main[5] * zoom
    target
  rescue StandardError => e
    BSS064.log("Cinema target: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end

  # All camera states are absolute, based on the native battle scene frame:
  # calling alignment twice in one render frame cannot compound the transform.
  def vermeil_cinema_project_point(x, y, vector, main, scale, weight = 1.0)
    cx = (Graphics.width.to_f rescue 640.0) / 2.0
    cy = (Graphics.height.to_f rescue 480.0) / 2.0
    dx = (vector[0] - main[0]) * 0.65 * weight
    dy = (vector[1] - main[1]) * 0.45 * weight
    [cx + ((x.to_f - cx) * scale) + dx, cy + ((y.to_f - cy) * scale) + dy]
  end

  def vermeil_cinema_align_sprite(sprite, native, vector, main, scale, weight)
    return unless sprite && native && native.length >= 5
    return if sprite.respond_to?(:disposed?) && sprite.disposed?
    x, y = vermeil_cinema_project_point(native[0], native[1], vector, main, scale, weight)
    sprite.x = x if sprite.respond_to?(:x=)
    sprite.y = y if sprite.respond_to?(:y=)
    sprite.zoom_x = native[3].to_f * scale if sprite.respond_to?(:zoom_x=)
    sprite.zoom_y = native[4].to_f * scale if sprite.respond_to?(:zoom_y=)
  end

  def bss070_ebdx_apply_world_alignment(*args, &block)
    ret = super
    return ret unless vermeil_cinema_active? && !vermeil_cinema_locked?
    return ret unless @battle && @sprites && @battle.respond_to?(:battlers)
    return ret unless respond_to?(:bss096_native_position)
    main = BSS070EBDXCore.get_vector(:MAIN, @battle)
    vector = @vector.get
    return ret unless vector && main && main.length >= 6
    raw_scale = vector[4].to_f / (main[4].to_f.abs < 0.001 ? 1.0 : main[4].to_f)
    cfg = vermeil_cinema_config
    weight = VermeilBSSCinema.clamp(cfg["cinematicBattlerFollow"], 0, 100) / 100.0
    scale = 1.0 + (VermeilBSSCinema.clamp(raw_scale, 0.85, 1.25) - 1.0) * weight
    # Keep normal double/triple formations legible at any zoom.
    count = @battle.battlers.compact.length
    scale = 1.0 + (scale - 1.0) * 0.60 if count > 2
    @battle.battlers.each_index do |i|
      next unless @battle.battlers[i]
      sp = bss070_ebdx_native_sprite(i) rescue nil
      if sp && (!respond_to?(:bss070_ebdx_sprite_loaded?) || bss070_ebdx_sprite_loaded?(sp))
        vermeil_cinema_align_sprite(sp, bss096_native_position(i), vector, main, scale, weight)
      end
      sh = bss070_ebdx_native_shadow_sprite(i) rescue nil
      if sh && (!respond_to?(:bss070_ebdx_sprite_loaded?) || bss070_ebdx_sprite_loaded?(sh))
        if !@bss070_ebdx_room || !@bss070_ebdx_room.respond_to?(:shadows_enabled?) || @bss070_ebdx_room.shadows_enabled?
          vermeil_cinema_align_sprite(sh, bss096_native_shadow_position(i), vector, main, scale, weight)
        end
      end
    end
    ret
  rescue StandardError => e
    BSS064.log("Cinema battler alignment: #{e.class}: #{e.message}") if defined?(BSS064)
    ret
  end

  # This supersedes the 0.8.36 ambient scheduler. It is the ONLY writer of the
  # EBDX scene vector during normal battle presentation; old 039 and 037 still
  # update the room, but receive advance_camera=false (no competing retarget).
  def bss070_ebdx_tick(advance_camera = true, align = true)
    return super unless vermeil_cinema_active?
    owned = vermeil_cinema_locked?
    # Old BSS087 tweens can snap the vector even when advance_camera=false.
    # They are not allowed to outlive the new presentation director.
    @bss087_camera_tween = nil unless @bss087_end_battle_lock
    if advance_camera && !owned
      @vermeil_cinema_ticks = @vermeil_cinema_ticks.to_i + 1
      target = vermeil_cinema_vector
      if target
        cfg = vermeil_cinema_config
        @vector.inc = VermeilBSSCinema.clamp(cfg["cinematicSmooth"], 0.025, 0.18)
        @vector.set(target)
        @vector.update
        unless @vermeil_cinema_logged
          @vermeil_cinema_logged = true
          BSS064.log("[Camera v2] active: BSS scene owns world; BAS owns attacks") if defined?(BSS064)
        end
      end
    end
    super(false, align && !owned)
  end

  def pbInitSprites(*args, &block)
    @vermeil_cinema_ticks = 0
    @vermeil_cinema_command_depth = 0
    @vermeil_cinema_fight_depth = 0
    @vermeil_cinema_logged = false
    super
  end

  def pbCommandMenu(*args, &block)
    return super unless vermeil_cinema_active?
    @vermeil_cinema_command_depth = @vermeil_cinema_command_depth.to_i + 1
    super
  ensure
    @vermeil_cinema_command_depth = [@vermeil_cinema_command_depth.to_i - 1, 0].max if @vermeil_cinema_command_depth
  end

  def pbFightMenu(*args, &block)
    return super unless vermeil_cinema_active?
    @vermeil_cinema_fight_depth = @vermeil_cinema_fight_depth.to_i + 1
    super
  ensure
    @vermeil_cinema_fight_depth = [@vermeil_cinema_fight_depth.to_i - 1, 0].max if @vermeil_cinema_fight_depth
  end

  # Legacy callbacks attempted to return to MAIN or choose random EBDX shots.
  # New camera phase tracking is at the real menu boundaries above.
  def bss_unified_camera_to(*args)
    return nil if vermeil_cinema_active?
    super
  end

  def bss087_request_camera_context(*args)
    return false if vermeil_cinema_active?
    super
  end

  def bss084_transition_context(*args)
    return false if vermeil_cinema_active?
    super
  end

  def bss083_set_camera_state(*args)
    return nil if vermeil_cinema_active?
    super
  end

  def bss070_ebdx_camera_enter(*args)
    return nil if vermeil_cinema_active?
    super
  end

  def bss070_ebdx_camera_leave(*args)
    return nil if vermeil_cinema_active?
    super
  end

  def bss096_camera_to_main(*args)
    return false if vermeil_cinema_active?
    super
  end

  def bss083_settle_camera(*args)
    return nil if vermeil_cinema_active?
    super
  end

  # Simple runtime proof that the new camera is active and BAS is not being
  # overwritten. Available through scene.vermeil_cinema_status when debugging.
  def vermeil_cinema_status
    {
      :version => VermeilBSSCinema::VERSION,
      :active => vermeil_cinema_active?,
      :phase => vermeil_cinema_phase,
      :bas_owner => (respond_to?(:bss_shared_camera_leased?) && bss_shared_camera_leased?),
      :vector => (@vector.get rescue nil)
    }
  end

  def bss_layered_next_ebdx_shot(*args)
    return nil if vermeil_cinema_active?
    super
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(VermeilBSSCinemaScene)
  Battle::Scene.prepend(VermeilBSSCinemaScene)
end