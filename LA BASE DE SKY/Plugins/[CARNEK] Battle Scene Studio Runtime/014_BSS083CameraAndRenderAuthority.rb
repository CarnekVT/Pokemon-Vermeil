#===============================================================================
# Battle Scene Studio v0.8.3
# Camera state machine + render transform authority + Enhanced UI/filter guards.
#===============================================================================
module BSS083
  VERSION = "0.8.3"
  module_function

  def clamp(v, lo, hi)
    [[v.to_f, lo.to_f].max, hi.to_f].min
  end

  def lerp_vector(a, b, w)
    w = clamp(w, 0.0, 1.0)
    6.times.map do |i|
      av = (a[i] || (i >= 4 ? 1.0 : 0.0)).to_f
      bv = (b[i] || av).to_f
      av + (bv - av) * w
    end
  end

  # Deterministic shots from the supplied EBDX camera vocabulary. These are not
  # selected randomly on every menu transition. They are chosen by battle context.
  def camera_shot(kind, battle=nil)
    main = BSS070EBDXCore.get_vector(:MAIN, battle)
    rows = BSS070EBDXCore::CAMERA_MOTION
    case kind.to_s.downcase.to_sym
    when :player
      lerp_vector(main, rows[3], 0.38)
    when :enemy
      lerp_vector(main, rows[2], 0.38)
    when :wide
      lerp_vector(main, rows[7], 0.28)
    when :impact
      lerp_vector(main, rows[0], 0.28)
    when :idle_left
      lerp_vector(main, rows[3], 0.12)
    when :idle_right
      lerp_vector(main, rows[2], 0.12)
    else
      main.clone
    end
  rescue
    BSS070EBDXCore::MAIN_FALLBACK.clone
  end
end

module BSS083SceneCameraAuthority
  # ---------------------------------------------------------------------------
  # Camera state machine
  # ---------------------------------------------------------------------------
  def bss083_camera_active?
    respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active? && @vector
  rescue
    false
  end

  def bss083_set_camera_state(state, shot=nil, speed=nil)
    return if !bss083_camera_active?
    @bss083_camera_state = state.to_s.downcase.to_sym
    @bss070_ebdx_camera_mode = @bss083_camera_state
    if shot
      @vector.inc = speed.to_f if speed
      @vector.set(BSS083.camera_shot(shot, @battle))
    end
    @bss083_camera_state
  rescue => e
    BSS064.log("BSS083 camera state warning: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end

  def bss083_settle_camera
    return if !bss083_camera_active?
    @vector.inc = 0.028
    @vector.set(BSS083.camera_shot(:main, @battle))
    @bss083_camera_state = :settle
    @bss070_ebdx_camera_mode = :idle
    # Source EBDX waits a long time before a decorative random drift. Do the same.
    @bss083_idle_due = BSS070EBDXCore::BATTLE_MOTION_TIMER.to_i * BSS070EBDXCore.frame_rate.to_i
  rescue
  end

  def bss083_battler_index(obj)
    return nil if !obj
    return obj.index.to_i if obj.respond_to?(:index)
    return obj.to_i if obj.is_a?(Numeric)
    nil
  rescue
    nil
  end

  def bss083_camera_move_context(user, targets)
    arr = targets.is_a?(Array) ? targets.compact : (targets ? [targets] : [])
    ui = bss083_battler_index(user)
    ti = arr.map { |x| bss083_battler_index(x) }.compact
    # Spread/multi-target attacks get a readable full-field composition.
    return [:wide, 0.045] if ti.length > 1
    focus = ti[0]
    focus = ui if focus.nil?
    return [:impact, 0.04] if focus.nil?
    [(focus.even? ? :player : :enemy), 0.046]
  rescue
    [:impact, 0.04]
  end

  # Command/Fight menus are UI states, not camera cuts. The old implementation
  # chose a new random vector every time these methods were entered/left, which
  # is why the camera appeared to restart at the slightest interaction.
  def bss070_ebdx_camera_enter(mode)
    return super unless bss083_camera_active?
    @bss083_camera_state = mode.to_s.downcase.to_sym
    @bss070_ebdx_camera_mode = @bss083_camera_state
    @bss083_idle_due ||= BSS070EBDXCore::BATTLE_MOTION_TIMER.to_i * BSS070EBDXCore.frame_rate.to_i
    nil
  end

  def bss070_ebdx_camera_leave
    return super unless bss083_camera_active?
    @bss083_camera_state = :idle
    @bss070_ebdx_camera_mode = :idle
    @bss083_idle_due ||= BSS070EBDXCore::BATTLE_MOTION_TIMER.to_i * BSS070EBDXCore.frame_rate.to_i
    nil
  end

  # Replace the fast 2-5 second random-camera cycle with the original EBDX/Gen-5
  # style: contextual movement during actions, and only an occasional subtle idle
  # drift when nothing else owns the scene.
  def bss070_ebdx_tick(advance_camera=true, align=true)
    return super unless respond_to?(:bss070_ebdx_ensure_core) && bss070_ebdx_ensure_core
    bss070_ebdx_hide_native_backdrops if respond_to?(:bss070_ebdx_hide_native_backdrops)

    frozen = @bss083_camera_freeze.to_i > 0 || @bss070_ebdx_bas_frame
    can_advance = advance_camera && !frozen && bss070_ebdx_camera_enabled?
    @vector.update if can_advance
    @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
    bss070_ebdx_apply_world_alignment if align

    return unless can_advance
    @bss083_idle_due ||= BSS070EBDXCore::BATTLE_MOTION_TIMER.to_i * BSS070EBDXCore.frame_rate.to_i
    state = (@bss083_camera_state || :idle).to_sym
    if state == :settle && @vector.finished?
      @bss083_camera_state = :idle
      state = :idle
    end
    return unless state == :idle

    @bss083_idle_due -= 1
    if @bss083_idle_due <= 0 && @vector.finished?
      @bss083_idle_side = (@bss083_idle_side == :idle_left ? :idle_right : :idle_left)
      @vector.inc = 0.008
      @vector.set(BSS083.camera_shot(@bss083_idle_side, @battle))
      @bss083_idle_due = (BSS070EBDXCore::BATTLE_MOTION_TIMER.to_i * BSS070EBDXCore.frame_rate.to_i * 0.5).to_i
    end
  rescue => e
    BSS064.log("BSS083 camera tick warning: #{e.class}: #{e.message}") if defined?(BSS064)
    super
  end

  # ---------------------------------------------------------------------------
  # Native/PBS animation transform sandwich
  # ---------------------------------------------------------------------------
  def bss083_restore_animation_raw_transforms
    rows = @bss083_animation_raw
    return if !rows.is_a?(Hash)
    rows.each do |idx, raw|
      sp = bss070_ebdx_native_sprite(idx) rescue nil
      next if !sp || (sp.disposed? rescue true)
      begin
        sp.x, sp.y, sp.z = raw[:x], raw[:y], raw[:z]
        sp.zoom_x, sp.zoom_y = raw[:zx], raw[:zy]
        sp.angle = raw[:angle] if raw.has_key?(:angle) && sp.respond_to?(:angle=)
      rescue
      end
    end
  end

  def bss083_capture_and_project_animation_transforms
    return if !@bss083_animation_projection
    return if !@bss070_ebdx_room || !@vector || !@battle
    @bss083_animation_raw ||= {}
    main = BSS070EBDXCore.get_vector(:MAIN, @battle)
    mz = main[4].to_f
    mz = 1.0 if mz == 0.0
    camera_zoom = (@vector.zoom1.to_f / mz) ** 0.75
    cfg = bss070_ebdx_camera_config rescue {}
    inf = BSS083.clamp((cfg["battlerInfluence"] || 100).to_f / 100.0, 0.0, 1.5)

    @battle.battlers.each_index do |idx|
      sp = bss070_ebdx_native_sprite(idx) rescue nil
      next if !sp || (sp.disposed? rescue true) || !bss070_ebdx_sprite_loaded?(sp)
      anchor = @bss070_ebdx_room.battler(idx) rescue nil
      next if !anchor
      begin
        raw = {
          :x => sp.x.to_f, :y => sp.y.to_f, :z => sp.z.to_i,
          :zx => sp.zoom_x.to_f, :zy => sp.zoom_y.to_f,
          :angle => (sp.angle rescue 0).to_f
        }
        @bss083_animation_raw[idx] = raw
        native = BSS082.without_position_context { bss070_ebdx_native_position_for(idx) }
        nx, ny = native[0].to_f, native[1].to_f
        bx = nx + (anchor.x.to_f - nx) * inf
        by = ny + (anchor.y.to_f - ny) * inf
        # Preserve the move's own delta/zoom, then apply the camera exactly once.
        sp.x = bx + (raw[:x] - nx) * camera_zoom
        sp.y = by + (raw[:y] - ny) * camera_zoom
        sp.zoom_x = raw[:zx] * camera_zoom
        sp.zoom_y = raw[:zy] * camera_zoom
        sp.z = [raw[:z], 50 + idx].max
      rescue
      end
    end
  rescue => e
    BSS064.log("BSS083 animation projection warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss070_ebdx_apply_world_alignment
    if @bss083_animation_projection
      bss083_capture_and_project_animation_transforms
      return
    end
    super
  end

  def pbUpdate(*args, &block)
    bss083_restore_animation_raw_transforms if @bss083_animation_projection
    ret = super
    bss083_enhanced_ui_guard
    ret
  end

  # The lower BSS wrapper calls this for native/PBS move animations. While our
  # projection mode is active, do not save/snap/restore the camera around every
  # animation; keep the contextual shot alive and let the transform sandwich keep
  # the animation's own coordinates intact.
  def bss070_ebdx_suspend_world(*args, &block)
    return yield if @bss083_animation_projection
    super
  end

  def bss083_prepare_native_animation_baseline
    return if !@battle
    @bss083_animation_raw ||= {}
    @battle.battlers.each_index do |idx|
      sp = bss070_ebdx_native_sprite(idx) rescue nil
      next if !sp || (sp.disposed? rescue true) || !bss070_ebdx_sprite_loaded?(sp)
      begin
        native = BSS082.without_position_context { bss070_ebdx_native_position_for(idx) }
        scale = bss070_ebdx_anchor_scale(idx)
        raw = {
          :x => native[0].to_f, :y => native[1].to_f, :z => native[2].to_i,
          :zx => scale[0].to_f, :zy => scale[1].to_f,
          :angle => (sp.angle rescue 0).to_f
        }
        @bss083_animation_raw[idx] = raw
        sp.x = raw[:x]; sp.y = raw[:y]; sp.z = raw[:z]
        sp.zoom_x = raw[:zx]; sp.zoom_y = raw[:zy]
      rescue
      end
    end
  end

  def bss083_with_move_projection(user=nil, targets=nil, camera_cut=true)
    return yield unless bss083_camera_active?
    outer = !@bss083_animation_projection
    if outer
      @bss083_animation_projection = true
      @bss083_animation_raw = {}
      # Native/PBS animation classes must read native battler coordinates, never
      # the already camera-projected coordinates left on-screen by EBDX.
      bss083_prepare_native_animation_baseline
      if camera_cut
        shot, speed = bss083_camera_move_context(user, targets)
        bss083_set_camera_state(:move, shot, speed)
      end
    end
    yield
  ensure
    if outer
      begin
        bss083_restore_animation_raw_transforms
      rescue
      end
      @bss083_animation_projection = false
      @bss083_animation_raw = nil
      begin
        @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
        bss070_ebdx_apply_world_alignment
      rescue
      end
      bss083_settle_camera if camera_cut
    end
  end

  def pbAnimation(move_id, user, targets, *args, &block)
    return super unless bss083_camera_active?
    bss083_with_move_projection(user, targets) { super }
  end

  def pbCommonAnimation(anim_name, user=nil, target=nil, *args, &block)
    return super unless bss083_camera_active?
    # Common animations fire for status, shiny, item, capture and many UI-adjacent
    # effects. They must preserve the current camera state; otherwise every tiny
    # effect becomes a new cut/reset. We still use the transform sandwich so PBS/
    # native battler coordinates remain stable under the current EBDX projection.
    if user || target
      bss083_with_move_projection(user, target ? [target] : [], false) { super }
    else
      super
    end
  end

  # BAS already has its own authored camera/anchors. Freeze the BSS vector at the
  # current shot and stop post-animation state restoration from causing a tick.
  def bss083_with_bas_camera_lock
    return yield unless bss083_camera_active?
    # BAS owns its authored camera for the animation. The EBDX vector underneath
    # is frozen and then continues from exactly the same state, rather than being
    # told to return to MAIN just because a BAS clip ended.
    @bss083_camera_freeze = @bss083_camera_freeze.to_i + 1
    yield
  ensure
    @bss083_camera_freeze = [@bss083_camera_freeze.to_i - 1, 0].max
  end

  def pbPlayBattleAnimationStudio(*args, &block)
    return super unless bss083_camera_active?
    bss083_with_bas_camera_lock { super }
  end

  def pbPlayBattleAnimationStudioCustom(*args, &block)
    return super unless bss083_camera_active?
    bss083_with_bas_camera_lock { super }
  end

  # Sendout/recall/SOS/capture are screen-space Poké Ball sequences. Freeze the
  # current camera for the sequence; only sendout settles toward MAIN afterwards,
  # mirroring original EBDX without a hard snap.
  def bss083_with_camera_freeze(settle=false)
    @bss083_camera_freeze = @bss083_camera_freeze.to_i + 1
    yield
  ensure
    @bss083_camera_freeze = [@bss083_camera_freeze.to_i - 1, 0].max
    bss083_settle_camera if settle && @bss083_camera_freeze == 0
  end

  def pbSendOutBattlers(*args, &block)
    return super unless bss083_camera_active?
    bss083_with_camera_freeze(true) { super }
  end

  def pbRecall(*args, &block)
    return super unless bss083_camera_active?
    bss083_with_camera_freeze(false) { super }
  end

  def bss_pbSOSJoin(*args, &block)
    return super unless bss083_camera_active?
    result = bss083_with_camera_freeze(false) { super }
    begin
      bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
      bss070_ebdx_recalibrate_if_needed if respond_to?(:bss070_ebdx_recalibrate_if_needed)
      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment
    rescue
    end
    result
  end

  [:pbThrow, :pbThrowAndDeflect, :pbThrowPokeBall].each do |meth|
    define_method(meth) do |*args, &block|
      return super(*args, &block) unless bss083_camera_active?
      bss083_with_camera_freeze(false) { super(*args, &block) }
    end
  end

  # ---------------------------------------------------------------------------
  # Enhanced Battle UI: preserve its own visibility authority and correct Z.
  # ---------------------------------------------------------------------------
  def bss080_enforce_enhanced_ui_z
    return if !@sprites.is_a?(Hash)
    @sprites.each do |key, sp|
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:z=)
      k = key.to_s
      begin
        if k == "enhancedUI"
          sp.z = 96000
        elsif k == "enhancedUIPrompts"
          sp.z = 96040
        elsif k =~ /^(info_icon|ball_icon).*_outline\d+$/i
          sp.z = 96020
        elsif k =~ /^(info_icon|ball_icon)/i
          sp.z = 96021
        elsif k =~ /^(leftarrow|rightarrow)$/i
          sp.z = 96030
        end
      rescue
      end
    end
  end

  # Remember Enhanced UI's requested outline state. The guard may temporarily
  # mask an outline while its parent icon is hidden, but must restore that intent
  # when the icon becomes visible again instead of permanently losing selection.
  def pbShowOutline(sprite, visibility=true)
    if !visibility.is_a?(Numeric)
      @bss083_outline_intent ||= {}
      @bss083_outline_intent[sprite.to_s] = !!visibility
    end
    super
  end

  def bss083_hide_enhanced_aux
    return if !@sprites.is_a?(Hash)
    @sprites.each do |key, sp|
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible=)
      k = key.to_s
      next unless k == "enhancedUI" || k == "enhancedUIPrompts" || k =~ /^(info_icon|ball_icon|leftarrow|rightarrow)/i
      sp.visible = false
    end
  rescue
  end

  def bss083_enhanced_ui_guard
    bss080_enforce_enhanced_ui_z
    return if !@sprites.is_a?(Hash) || !instance_variable_defined?(:@enhancedUIToggle)
    toggle = @enhancedUIToggle
    command_visible = (@sprites["commandWindow"].visible rescue false)
    fight_visible = (@sprites["fightWindow"].visible rescue false)
    message_visible = (@sprites["messageBox"].visible rescue false) && !command_visible && !fight_visible
    target_visible = (@sprites["targetWindow"].visible rescue false)
    party_anim = (respond_to?(:inPartyAnimation?) && inPartyAnimation?) rescue false
    cinematic = @bss083_standalone_intro || @bss083_camera_freeze.to_i > 0

    # Info panes are valid only while the menu that owns them is actually active.
    allowed_toggle = case toggle
                     when :move then fight_visible
                     when :battler then command_visible
                     when :ball then command_visible
                     else false
                     end
    allowed_toggle = false if message_visible || target_visible || party_anim || cinematic
    if toggle && !allowed_toggle
      begin; pbHideInfoUI if respond_to?(:pbHideInfoUI); rescue; end
      toggle = nil
    end

    # Outlines may never outlive their parent icon. Do not force outlines visible;
    # Enhanced UI's pbShowOutline remains the selection authority.
    @sprites.each do |key, sp|
      k = key.to_s
      next unless k =~ /\A(.+)_outline\d+\z/
      parent_key = $1
      parent = @sprites[parent_key] rescue nil
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible=)
      parent_visible = parent && (parent.visible rescue false)
      intent = (@bss083_outline_intent && @bss083_outline_intent.has_key?(parent_key)) ? @bss083_outline_intent[parent_key] : (sp.visible rescue false)
      sp.visible = !!(parent_visible && intent)
    end

    prompt = @sprites["enhancedUIPrompts"] rescue nil
    if prompt && prompt.respond_to?(:visible=)
      prompt_allowed = (command_visible || fight_visible) && !message_visible && !target_visible && !party_anim && !cinematic
      prompt.visible = false unless prompt_allowed
    end
  rescue => e
    BSS064.log("BSS083 Enhanced UI guard warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  # Never resurrect Enhanced UI elements from a stale cinematic visibility
  # snapshot. Their plugin re-opens them only in valid command/fight contexts.
  def bss078_cinematic_ui_restore(state)
    filtered = {}
    if state.is_a?(Hash)
      state.each do |key, vis|
        k = key.to_s
        next if k =~ /(info_icon|ball_icon|enhancedUI|enhancedUIPrompts|leftarrow|rightarrow|_outline)/i
        filtered[key] = vis
      end
    end
    super(filtered)
    bss083_hide_enhanced_aux
  end

  # ---------------------------------------------------------------------------
  # DBK darken/revert filter authority for the complete EBDX room.
  # ---------------------------------------------------------------------------
  def bss081_sync_background_filter
    return unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    native = (@sprites["battle_bg"] rescue nil) || (@sprites["battle_bg2"] rescue nil)
    room = @bss070_ebdx_room rescue nil
    return if !native || !room || (room.disposed? rescue true)
    rs = room.instance_variable_get(:@sprites) rescue nil
    return if !rs.is_a?(Hash)
    c = native.color rescue nil
    t = native.tone rescue nil
    color_active = c && c.alpha.to_f > 0.0
    tone_active = t && (t.red.to_f != 0.0 || t.green.to_f != 0.0 || t.blue.to_f != 0.0 || t.gray.to_f != 0.0)

    rs.each do |key, sp|
      next if !sp || (sp.disposed? rescue false)
      k = key.to_s
      # Metric anchors are not rendered scenery. Every actual visual layer,
      # including lights/weather/custom images, participates in the DBK filter.
      next if k.start_with?("battler") || k.start_with?("shadow") || k.start_with?("trainer_")
      begin
        if sp.respond_to?(:color=)
          if color_active
            unless sp.instance_variable_defined?(:@bss083_filter_base_color)
              bc = sp.color rescue nil
              sp.instance_variable_set(:@bss083_filter_base_color, Color.new(bc.red, bc.green, bc.blue, bc.alpha)) if bc
            end
            sp.color = Color.new(c.red, c.green, c.blue, c.alpha)
          elsif sp.instance_variable_defined?(:@bss083_filter_base_color)
            bc = sp.instance_variable_get(:@bss083_filter_base_color)
            sp.color = bc if bc
            sp.remove_instance_variable(:@bss083_filter_base_color) rescue nil
          end
        end
      rescue
      end
      begin
        if sp.respond_to?(:tone=)
          if tone_active
            unless sp.instance_variable_defined?(:@bss083_filter_base_tone)
              bt = sp.tone rescue nil
              sp.instance_variable_set(:@bss083_filter_base_tone, Tone.new(bt.red, bt.green, bt.blue, bt.gray)) if bt
            end
            sp.tone = Tone.new(t.red, t.green, t.blue, t.gray)
          elsif sp.instance_variable_defined?(:@bss083_filter_base_tone)
            bt = sp.instance_variable_get(:@bss083_filter_base_tone)
            sp.tone = bt if bt
            sp.remove_instance_variable(:@bss083_filter_base_tone) rescue nil
          end
        end
      rescue
      end
    end
  rescue => e
    BSS064.log("BSS083 room filter warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end
end

begin
  Battle::Scene.prepend(BSS083SceneCameraAuthority) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS083SceneCameraAuthority)
rescue => e
  BSS064.log("BSS083 scene authority install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
