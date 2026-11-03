# frozen_string_literal: true
# Pokemon Vermeil - Battle Scene Studio cinematic camera v2
# A single scene-world camera, with BAS retaining exclusive move-camera control.
# Unlike old BSS patches, this director drives the EBDX vector AND the real
# battler/shadow screen anchors from the same absolute camera state.
# It does not import EBS scripts and leaves BAS animation timelines untouched.

module VermeilBSSCinema
  VERSION = "3.1.0"
  # Deliberate real-time eyeline sweeps rather than one-frame retargets.
  SWEEP_SECONDS = 3.0
  SWEEP_HOLD_SECONDS = 0.52
  IDLE_PAN_X = 19.0
  IDLE_PAN_Y = 3.6
  DEFAULTS = {
    "cinematicCamera" => true,
    "cinematicIdleZoom" => 1.0,
    "cinematicCommandZoom" => 1.0,
    "cinematicFightZoom" => 1.0,
    "cinematicSmooth" => 0.045,
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
    return true if @bss_dialogue_cinema_active || @bss_video_blackbars
    return true if respond_to?(:pbInCinematicSpeech?) && (pbInCinematicSpeech? rescue false)
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
    menu_phase = [:command, :fight, :target].include?(vermeil_cinema_phase)
    unless menu_phase
      # Legacy freeze counters can outlive a native sendout.
      return true if @bss070_ebdx_suspend_depth.to_i > 0
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
    return :target if @bss_target_select_depth.to_i > 0
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
    phase_pan_x = (phase == :command ? 9.0 : (phase == :fight ? 0.0 : 0.0))
    phase_pan_y = (phase == :command ? -2.0 : (phase == :fight ? 0.0 : 0.0))
    target = main.clone
    target[0] += VermeilBSSCinema.clamp(phase_pan_x * pan_x * strength, -20.0, 20.0)
    target[1] += VermeilBSSCinema.clamp(phase_pan_y * pan_y * strength, -6.0, 6.0)
    if phase == :idle || phase == :command
      # Both idle AND command menus must visibly drift; the user spends most
      # of a turn in the command menu, not the idle phase.
      direction=@vermeil_cinema_idle_side.to_i.even? ? 1.0 : -1.0
      target[0]+=direction*VermeilBSSCinema::IDLE_PAN_X*pan_x
      target[1]+=direction*VermeilBSSCinema::IDLE_PAN_Y*pan_y
    end
    # During move selection focus the actual active USER of that move,
    # not the first opponent nor a fixed right-side pan.
    if phase == :fight && @bss_fight_actor_index.is_a?(Integer)
      shot = vermeil_cinema_focus_vector(@bss_fight_actor_index)
      return shot if shot
    end
    # During multi-target choice focus the currently highlighted battler.
    if @bss_selected_target_index.is_a?(Integer)
      shot = vermeil_cinema_focus_vector(@bss_selected_target_index)
      return shot if shot
    end
    # Camera target depends only on the menu phase and active battler.
    # Never oscillate on a timer while the player navigates a choice.
    # Perspective, physical scale and native battler sizes remain unchanged.
    target
  rescue StandardError => e
    BSS064.log("Cinema target: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end

  # Focus is derived from the actual projected battler location, not
  # world-vector presets. These bounded deltas travel the SAME EBDX matrix
  # that BSS103 uses for scenery, Pokemon and their shadows.
  def vermeil_cinema_focus_vector(index)
    sprite=@sprites.is_a?(Hash) ? @sprites["pokemon_#{index}"] : nil
    return nil unless sprite && !(sprite.disposed? rescue true)
    return nil unless (sprite.visible rescue false)
    main=BSS070EBDXCore.get_vector(:MAIN,@battle).clone.map{|v|v.to_f}
    # Read the canonical screen-space/native formation, NEVER the already
    # projected sprite. Using sprite.x made successive shots chase their own
    # previous offset and drift across the screen.
    native=(bss070_ebdx_neutral_battler_position(index) rescue nil)
    pos=native.is_a?(Array) ? native[0] : nil
    return nil unless pos
    dx=VermeilBSSCinema.clamp((Graphics.width.to_f*0.48-pos.to_f)*0.13,-17.0,17.0)
    main[0]+=dx
    main
  rescue StandardError
    nil
  end

  def vermeil_cinema_acquire_shot(shot)
    return unless vermeil_cinema_active? && @vector && !vermeil_cinema_locked?
    @vector.inc=VermeilBSSCinema.clamp(vermeil_cinema_config["cinematicSmooth"],0.08,0.22)
    @vector.set(shot) if shot
    @vermeil_cinema_ambient_due=120
  end

  def vermeil_cinema_return_main(frames=9)
    return unless vermeil_cinema_active? && @vector
    # Never animate to MAIN while DBK/BSS owns scripted speech.
    return if vermeil_cinema_script_locked?
    main=BSS070EBDXCore.get_vector(:MAIN,@battle)
    # Ease the SINGLE shared world vector instead of using a too-fast fixed
    # @vector.inc and snapping 8%-20% of the remaining distance at the end.
    # A true ease-out reaches MAIN exactly without an abrupt last frame.
    initial=(@vector.get.clone rescue main.clone)
    duration=[[frames.to_i,12].max,26].min
    duration.times do |i|
      t=(i+1).to_f/duration
      eased=t*t*(3.0-2.0*t)
      vector=6.times.map{|k| initial[k].to_f+(main[k].to_f-initial[k].to_f)*eased}
      @vector.snap(vector) if @vector.respond_to?(:snap)
      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      if defined?(BSS103WorldSpaceBattlers)
        BSS103WorldSpaceBattlers.instance_method(:bss070_ebdx_apply_world_alignment).bind(self).call
      end
      # Do not call Input.update here. Those extra polling frames consumed
      # arrows/confirm presses while Essentials was changing menus.
      Graphics.update
    end
    @vermeil_cinema_last_shot=nil
  rescue StandardError => e
    BSS064.log("BSS camera main: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  # Bag/party/cancel are not focus shots. Interpolate back to the
  # NORMAL EBDX MAIN composition and hold it until another command is shown.
  def vermeil_cinema_queue_home
    return unless vermeil_cinema_active? && @vector
    @vermeil_cinema_home_from=@vector.get.clone
    @vermeil_cinema_home_started=Time.now.to_f
    @vermeil_cinema_home_hold=true
    @vermeil_cinema_sweep_phase=nil
    @vermeil_cinema_last_shot=nil
  end

  def vermeil_cinema_home_tick
    main=BSS070EBDXCore.get_vector(:MAIN,@battle)
    return unless main.is_a?(Array) && @vector
    began=@vermeil_cinema_home_started
    if began
      t=[[((Time.now.to_f-began)/0.42),0.0].max,1.0].min
      smooth=t*t*(3.0-2.0*t)
      from=@vermeil_cinema_home_from || @vector.get
      @vector.snap(6.times.map{|i| from[i].to_f+(main[i].to_f-from[i].to_f)*smooth})
      @vermeil_cinema_home_started=nil if t>=1.0
    else
      # Keep the Bag/Party view at the normalized full-field baseline.
      @vector.snap(main)
    end
  end

  # A single absolute EBDX world-vector tween: smoothstep begins/ends at
  # zero speed and the deliberate 3-second travel remains visible at 60 or
  # 110 FPS. No extra camera and no per-frame retarget of BSSVector#set.
  def vermeil_cinema_sweep_tick(phase)
    now=Time.now.to_f
    started=@vermeil_cinema_sweep_started
    if @vermeil_cinema_sweep_phase!=phase || !started
      @vermeil_cinema_sweep_phase=phase
      @vermeil_cinema_sweep_started=now
      @vermeil_cinema_sweep_from=@vector.get.clone
      @vermeil_cinema_sweep_to=vermeil_cinema_vector
    elsif now-started >= VermeilBSSCinema::SWEEP_SECONDS+VermeilBSSCinema::SWEEP_HOLD_SECONDS
      @vermeil_cinema_idle_side=@vermeil_cinema_idle_side.to_i+1
      @vermeil_cinema_sweep_started=now
      @vermeil_cinema_sweep_from=@vector.get.clone
      @vermeil_cinema_sweep_to=vermeil_cinema_vector
    end
    from=@vermeil_cinema_sweep_from
    dest=@vermeil_cinema_sweep_to
    return unless from.is_a?(Array) && dest.is_a?(Array) && from.length>=6 && dest.length>=6
    p=[[((now-@vermeil_cinema_sweep_started)/VermeilBSSCinema::SWEEP_SECONDS),0.0].max,1.0].min
    p=p*p*(3.0-2.0*p)
    @vector.snap(6.times.map{|i| from[i].to_f+(dest[i].to_f-from[i].to_f)*p})
    @vermeil_cinema_last_shot=phase
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
    # Scripted dialogue/DBK speech is an exclusive presentation lease.
    # Some older BSS helpers can still call vector.set directly; restore the
    # snapshot before rendering this frame without affecting BAS ownership.
    if vermeil_cinema_script_locked?
      held=@vermeil_cinema_script_camera_hold
      if held.is_a?(Array) && @vector && @bas_runtime_playback_depth.to_i<=0 &&
         !(respond_to?(:bss_shared_camera_leased?) && bss_shared_camera_leased?)
        @vector.snap(held)
      end
      return super(false,false)
    end
    # Ownership: intro > speech/forced > BAS/native attack phase > menu > idle.
    # Always render the room, but only command/fight menus can write a new
    # presentation camera target. This prevents vector drift between moves.
    return super(false, align) unless @vermeil_cinema_first_command_reached
    owned = vermeil_cinema_locked?
    return super(false, false) if owned
    phase = vermeil_cinema_phase
    # Drop stale, pre-director tweens only when the presentation owns the shot.
    @bss087_camera_tween = nil unless @bss087_end_battle_lock
    if advance_camera
      if @vermeil_cinema_home_hold && phase==:idle
        vermeil_cinema_home_tick
      elsif phase==:idle || phase==:command
        vermeil_cinema_sweep_tick(phase)
      elsif phase==:fight || phase==:target
        # Target selection receives a discrete, user-initiated composition.
        # No ambient sweep may compete with the selected battler or BAS.
        @vermeil_cinema_sweep_phase=nil
        if @vermeil_cinema_last_shot!=phase
          shot=vermeil_cinema_vector
          if shot
            @vector.inc=0.065
            @vector.set(shot)
            @vermeil_cinema_last_shot=phase
          end
        end
        @vector.update
      end
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
    @vermeil_cinema_ambient_due = 0
    @vermeil_cinema_idle_side = 0
    @vermeil_cinema_sweep_phase = nil
    @vermeil_cinema_sweep_started = nil
    @vermeil_cinema_home_started = nil
    @vermeil_cinema_home_hold = false
    @bss_fight_actor_index=nil
    @bss_selected_target_index=nil
    @bss_target_select_depth=0
    super
  end

  def pbCommandMenu(*args, &block)
    return super unless vermeil_cinema_active?
    @vermeil_cinema_first_command_reached = true
    @vermeil_cinema_home_hold=false
    @vermeil_cinema_home_started=nil
    @vermeil_cinema_last_shot = nil  # new turn / reacquire Command
    @vermeil_cinema_command_depth = @vermeil_cinema_command_depth.to_i + 1
    choice=super
    choice
  ensure
    @vermeil_cinema_command_depth = [@vermeil_cinema_command_depth.to_i - 1, 0].max if @vermeil_cinema_command_depth
    # Essentials: 0=Fight; 1=Bag; 2=Party; -1=Cancel.
    vermeil_cinema_queue_home if defined?(choice) && choice!=0
  end

  def pbFightMenu(*args, &block)
    return super unless vermeil_cinema_active?
    @vermeil_cinema_last_shot = nil  # reacquire Fight from Command
    @bss_fight_actor_index=args[0] if args[0].is_a?(Integer)
    @vermeil_cinema_fight_depth = @vermeil_cinema_fight_depth.to_i + 1
    super
  ensure
    @vermeil_cinema_fight_depth = [@vermeil_cinema_fight_depth.to_i - 1, 0].max if @vermeil_cinema_fight_depth
    @bss_fight_actor_index=nil if @vermeil_cinema_fight_depth.to_i<=0
    vermeil_cinema_queue_home if @vermeil_cinema_fight_depth.to_i==0
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