# frozen_string_literal: true
# Pokemon Vermeil - Battle Scene Studio cinematic camera v2
# A single scene-world camera, with BAS retaining exclusive move-camera control.
# Unlike old BSS patches, this director drives the EBDX vector AND the real
# battler/shadow screen anchors from the same absolute camera state.
# It does not import EBS scripts and leaves BAS animation timelines untouched.

module VermeilBSSCinema
  VERSION = "2.6.1"
  DEFAULTS = {
    "cinematicCamera" => true,
    "cinematicIdleZoom" => 1.0,
    "cinematicCommandZoom" => 1.0,
    "cinematicFightZoom" => 1.0,
    "cinematicSmooth" => 0.115,
    "cinematicIdlePan" => 5.0,
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

  def vermeil_cinema_script_locked?
    return true if @bss_nds_intro_active
    return true if @vermeil_cinema_script_depth.to_i > 0
    return true if @vermeil_cinema_trainer_intro_depth.to_i > 0
    return false
  end

  def vermeil_cinema_locked?
    return true if vermeil_cinema_script_locked?
    return true if respond_to?(:bss_shared_camera_leased?) && bss_shared_camera_leased?
    # Attack owns the entire turn, not just the frames when BAS is playing.
    # Commands, text, damage effects and common animations may not retarget.
    return true if @bss_camera_attack_phase_depth.to_i > 0
    return true if @bss070_ebdx_bas_frame || @bas_runtime_playback_depth.to_i > 0
    return true if @vermeil_cinema_native_move_depth.to_i > 0
    # EBS-like priority arbiter: a command/fight menu has no native move
    # playing. Legacy 'camera freeze' counters can survive earlier sendouts,
    # leaving the presentation permanently static. Explicit BAS/attack/script
    # leases above still win; do not let stale ambient locks veto a menu shot.
    menu_phase = [:command, :fight].include?(vermeil_cinema_phase)
    unless menu_phase
      return true if @bss083_camera_freeze.to_i > 0 || @bss070_ebdx_suspend_depth.to_i > 0
      return true if @bss098_native_move_active || @bss096_move_projection_active
      return true if @bss087_native_move_active || @bss084_native_move_active
      return true if @bss096_native_formation_depth.to_i > 0 || @bss096_battler_anim_depth.to_i > 0
      return true if (respond_to?(:inPartyAnimation?) && inPartyAnimation?)
    end
    return true if @bss087_end_battle_lock
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

  # Preserve the scene's authored horizon, angle, perspective and scale. The
  # presentation director only pans the existing world; changing [2..5] every
  # menu frame inflated Pokemon sprites and warped the EBDX background.
  # EBDX remains the only world-vector writer. Animate the composition with
  # bounded pans; moving zoom1/zoom2 here would resize the backdrop without
  # resizing Essentials/DBK battlers and produce the old warped-camera bug.
  def vermeil_cinema_vector
    main = BSS070EBDXCore.get_vector(:MAIN, @battle)
    return nil unless main.is_a?(Array) && main.length >= 6
    main = main[0, 6].map { |v| v.to_f }
    cfg = vermeil_cinema_config
    strength = VermeilBSSCinema.clamp(cfg["idleStrength"] || 40, 0, 100) / 100.0
    pan_x = VermeilBSSCinema.clamp(cfg["panX"] || 100, 0, 200) / 100.0
    pan_y = VermeilBSSCinema.clamp(cfg["panY"] || 100, 0, 200) / 100.0
    phase = vermeil_cinema_phase
    # EBS-style priority discipline: deterministic target for EACH menu phase.
    # Do not animate sine waves every frame: this created visible meandering,
    # and fight->attack->text flickered between unrelated camera positions.
    cfg_strength = VermeilBSSCinema.clamp(cfg["cinematicIdlePan"], 0, 20)
    strength = 0.85 + cfg_strength / 40.0
    # Noticeably different eyelines without overshooting the EBDX overscan.
    phase_pan_x = (phase == :command ? 18.0 : (phase == :fight ? -18.0 : 0.0))
    phase_pan_y = (phase == :command ? -3.0 : (phase == :fight ? 4.0 : 0.0))
    target = main.clone
    target[0] += VermeilBSSCinema.clamp(phase_pan_x * pan_x * strength, -20.0, 20.0)
    target[1] += VermeilBSSCinema.clamp(phase_pan_y * pan_y * strength, -6.0, 6.0)
    # Perspective, physical scale and native battler sizes remain unchanged.
    target
  rescue StandardError => e
    BSS064.log("Cinema target: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end

  # An absolute pan, not a scale animation. Base battler coordinates and
  # zooms come from the native Essentials/DBK formation every frame.
  def vermeil_cinema_project_point(x, y, vector, main, _scale, weight = 1.0)
    dx = (vector[0].to_f - main[0].to_f) * 0.65 * weight.to_f
    dy = (vector[1].to_f - main[1].to_f) * 0.45 * weight.to_f
    [x.to_f + dx, y.to_f + dy]
  end

  def vermeil_cinema_align_sprite(sprite, native, vector, main, scale, weight)
    return unless sprite && native && native.length >= 5
    return if sprite.respond_to?(:disposed?) && sprite.disposed?
    x, y = vermeil_cinema_project_point(native[0], native[1], vector, main, scale, weight)
    sprite.x = x if sprite.respond_to?(:x=)
    sprite.y = y if sprite.respond_to?(:y=)
    # Never multiply these by the world zoom. Zoom belongs to BAS only during
    # attacks; normal BSS camera movement may not change Pokemon/shadow sizes.
    sprite.zoom_x = native[3].to_f if sprite.respond_to?(:zoom_x=)
    sprite.zoom_y = native[4].to_f if sprite.respond_to?(:zoom_y=)
  end

  def bss070_ebdx_apply_world_alignment(*args, &block)
    # ONE alignment authority. BSS103 already projects battlers/shadows from
    # the EBDX room matrix. The old v2.x code ran super and then immediately
    # wrote native screen coordinates to the SAME sprites, causing wandering
    # battlers, disappearing actors and inconsistent floor/shadow placement.
    # BAS/native animated moves retain the current visuals without writes.
    return nil if vermeil_cinema_active? && vermeil_cinema_locked?
    super
  end

  # This supersedes the 0.8.36 ambient scheduler. It is the ONLY writer of the
  # EBDX scene vector during normal battle presentation; old 039 and 037 still
  # update the room, but receive advance_camera=false (no competing retarget).
  def bss070_ebdx_tick(advance_camera = true, align = true)
    return super unless vermeil_cinema_active?
    # Do not modify the vector or recalibrate battlers/trainers during scripted
    # dialogue, DBK speech, trainer animation, or the NDS overlay handoff.
    return super(false, false) if vermeil_cinema_script_locked?
    # Ownership: intro > speech/forced > BAS/native attack phase > menu > idle.
    # Always render the room, but only command/fight menus can write a new
    # presentation camera target. This prevents vector drift between moves.
    return super(false, align) unless @vermeil_cinema_first_command_reached
    owned = vermeil_cinema_locked?
    return super(false, false) if owned
    phase = vermeil_cinema_phase
    # Drop stale, pre-director tweens only when the presentation owns the shot.
    @bss087_camera_tween = nil unless @bss087_end_battle_lock
    if advance_camera && (phase == :command || phase == :fight)
      @vermeil_cinema_ticks = @vermeil_cinema_ticks.to_i + 1
      # Acquire a new shot only when the menu context changes. Keep updating
      # the current interpolation, not recreating its target every frame.
      if @vermeil_cinema_last_shot != phase
        target = vermeil_cinema_vector
        if target
          cfg = vermeil_cinema_config
          @vector.inc = VermeilBSSCinema.clamp(cfg["cinematicSmooth"], 0.025, 0.18)
          @vector.set(target)
          @vermeil_cinema_last_shot = phase
          BSS064.log("[Camera v2.5] #{phase} shot, BAS owns moves") if defined?(BSS064)
        end
      end
      @vector.update
    end
    super(false, align && !owned)
  end

  def pbInitSprites(*args, &block)
    @vermeil_cinema_ticks = 0
    @vermeil_cinema_first_command_reached = false
    @vermeil_cinema_command_depth = 0
    @vermeil_cinema_fight_depth = 0
    @vermeil_cinema_logged = false
    @vermeil_cinema_last_shot = nil
    super
  end

  def pbCommandMenu(*args, &block)
    return super unless vermeil_cinema_active?
    @vermeil_cinema_first_command_reached = true
    @vermeil_cinema_last_shot = nil  # new turn / reacquire Command
    @vermeil_cinema_command_depth = @vermeil_cinema_command_depth.to_i + 1
    super
  ensure
    @vermeil_cinema_command_depth = [@vermeil_cinema_command_depth.to_i - 1, 0].max if @vermeil_cinema_command_depth
  end

  def pbFightMenu(*args, &block)
    return super unless vermeil_cinema_active?
    @vermeil_cinema_last_shot = nil  # reacquire Fight from Command
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

  # Native Essentials/PBS moves may animate sprites but NEVER direct the
  # persistent BSS camera. BAS clips already own their camera in the separate
  # playback path; these wrappers isolate all other move/common animations.
  def vermeil_cinema_hold_native_move_camera
    return yield unless vermeil_cinema_active? && @vector
    @vermeil_cinema_native_move_depth = @vermeil_cinema_native_move_depth.to_i + 1
    yield
  ensure
    if @vermeil_cinema_native_move_depth.to_i > 0
      @vermeil_cinema_native_move_depth -= 1
      # No forced snap to a saved camera at attack end. BAS releases its
      # render-only camera; the BSS world vector never needs rolling back.
    end
  end

  def pbAnimation(*args, &block)
    vermeil_cinema_hold_native_move_camera { super }
  end

  def pbCommonAnimation(*args, &block)
    vermeil_cinema_hold_native_move_camera { super }
  end

  # Simple runtime proof that the new camera is active and BAS is not being
  # overwritten. Available through scene.vermeil_cinema_status when debugging.
  def vermeil_cinema_status
    {
      :version => VermeilBSSCinema::VERSION,
      :active => vermeil_cinema_active?,
      :phase => vermeil_cinema_phase,
      :stable_sprite_size => true,
      :native_move_camera_frozen => @vermeil_cinema_native_move_depth.to_i > 0,
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