#===============================================================================
# Battle Scene Studio v0.8.2
# Coordinate/camera authority regression repair.
#
# The v0.8.0/0.8.1 sendout regression was caused by metric calibration probing
# BattlerSprite#pbSetPosition while the EBDX position context was active. The
# probe therefore consumed an already projected EBDX point and projected it a
# second time. Sendout/SOS/capture builders also need an EBDX-projected BASE
# point, not the species-adjusted final battler anchor.
#===============================================================================
module BSS082
  VERSION = "0.8.2"
  module_function

  def ebdx_scene?(scene)
    scene && scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?
  rescue
    false
  end

  def without_position_context
    return yield if !defined?(BSS070EBDXCore)
    old = BSS070EBDXCore.position_scene
    BSS070EBDXCore.position_scene = nil
    yield
  ensure
    BSS070EBDXCore.position_scene = old if defined?(BSS070EBDXCore)
  end
end

#-------------------------------------------------------------------------------
# Project a normal Essentials screen point through the live EBDX room.
# This is deliberately a BASE-point projection. Species metrics continue to be
# owned by BattlerSprite#pbSetPosition / the final room battler anchor.
#-------------------------------------------------------------------------------
if defined?(BSS070EBDXRoom)
  class BSS070EBDXRoom
    def bss082_project_screen_point(x, y)
      ex, ey = screen_to_room(x, y)
      bg = @sprites && @sprites["bg"]
      return [x.to_f, y.to_f] if !bg || (bg.disposed? rescue true)
      if bg.instance_variable_get(:@bss078_overscanned)
        ex += @bss078_pad_x.to_f
        ey += @bss078_pad_y.to_f
      end
      sx = bg.x.to_f - (bg.ox.to_f - ex.to_f) * bg.zoom_x.to_f
      sy = bg.y.to_f - (bg.oy.to_f - ey.to_f) * bg.zoom_y.to_f
      [sx, sy]
    rescue
      [x.to_f, y.to_f]
    end
  end
end

#-------------------------------------------------------------------------------
# EBDX animation coordinate authority.
# 0.8.1 returned room.battler here, which is a FINAL species-adjusted anchor.
# Poké Ball sendout/recall/capture classes expect Battle::Scene.pbBattlerPosition
# to be the BASE location and calculate their own final/ground offsets around it.
#-------------------------------------------------------------------------------
module BSS082BattlerPositionAuthority
  def pbBattlerPosition(index, sideSize = 1)
    ctx = defined?(BSS070EBDXCore) ? (BSS070EBDXCore.position_scene rescue nil) : nil
    return super if !BSS082.ebdx_scene?(ctx)

    base = BSS082.without_position_context { super(index, sideSize) }
    room = ctx.instance_variable_get(:@bss070_ebdx_room) rescue nil
    return base if !room || (room.disposed? rescue true) || !room.respond_to?(:bss082_project_screen_point)
    room.bss082_project_screen_point(base[0], base[1])
  rescue => e
    BSS064.log("BSS082 battler base projection warning: #{e.class}: #{e.message}") if defined?(BSS064)
    BSS082.without_position_context { super(index, sideSize) }
  end
end
begin
  Battle::Scene.singleton_class.prepend(BSS082BattlerPositionAuthority) if defined?(Battle::Scene) && !Battle::Scene.singleton_class.ancestors.include?(BSS082BattlerPositionAuthority)
rescue => e
  BSS064.log("BSS082 battler position install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

module BSS082SceneAuthority
  # Never let the metric sampler see the animation projection context. It must
  # sample the project's native/DBK position exactly once, then the room projects
  # that result once.
  def bss070_ebdx_neutral_battler_position(*args, &block)
    BSS082.without_position_context { super }
  end

  def bss070_ebdx_native_position_for(*args, &block)
    BSS082.without_position_context { super }
  end

  def bss070_ebdx_native_shadow_position_for(*args, &block)
    BSS082.without_position_context { super }
  end

  # Preserve both the visible vector and its in-progress target. 0.8.1 restored
  # only the current vector after native/BAS animation ownership, which discarded
  # the previous target and produced a visible camera correction on the next tick.
  def bss082_camera_state
    return nil if !@vector
    {
      :current => (@vector.get.dup rescue nil),
      :target  => ((@vector.instance_variable_get(:@set).dup) rescue nil),
      :inc     => (@vector.inc rescue nil),
      :mode    => @bss070_ebdx_camera_mode,
      :due     => @bss070_ebdx_motion_due,
      :last    => @bss070_ebdx_last_motion,
      :idle    => @bss070_ebdx_idle_timer
    }
  rescue
    nil
  end

  def bss082_restore_camera_state(state)
    return if !state || !@vector
    @vector.snap(state[:current]) if state[:current] && @vector.respond_to?(:snap)
    @vector.inc = state[:inc] if !state[:inc].nil? && @vector.respond_to?(:inc=)
    @vector.set(state[:target]) if state[:target] && @vector.respond_to?(:set)
    @bss070_ebdx_camera_mode = state[:mode]
    @bss070_ebdx_motion_due  = state[:due]
    @bss070_ebdx_last_motion = state[:last]
    @bss070_ebdx_idle_timer  = state[:idle]
    @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
    bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
  rescue => e
    BSS064.log("BSS082 camera restore warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  # The v0.7.8 baseline snap is useful only when a sequence owns a complete EBDX
  # camera shot. Native Poké Ball/SOS sequences are screen-space animations and
  # must inherit the exact current camera instead.
  def bss070_ebdx_snap_animation_baseline(*args)
    return if @bss082_preserve_native_camera
    super
  end

  def bss070_ebdx_camera_enter(*args)
    return if @bss082_preserve_native_camera
    super
  end

  def bss070_ebdx_camera_leave(*args)
    return if @bss082_preserve_native_camera
    super
  end

  def bss070_ebdx_suspend_world(*args, &block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    state = bss082_camera_state
    super
  ensure
    bss082_restore_camera_state(state) if state
  end

  # Sendout: DBK loads/repositions the bitmap first, then the animation reads a
  # projected BASE point for the Ball and the projected FINAL point from the
  # battler sprite. No MAIN/SENDOUT teleport is allowed during that construction.
  def pbSendOutBattlers(*args, &block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    state = bss082_camera_state
    old = @bss082_preserve_native_camera
    @bss082_preserve_native_camera = true
    super
  ensure
    @bss082_preserve_native_camera = old
    bss082_restore_camera_state(state) if state
  end

  def pbRecall(*args, &block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    state = bss082_camera_state
    old = @bss082_preserve_native_camera
    @bss082_preserve_native_camera = true
    super
  ensure
    @bss082_preserve_native_camera = old
    bss082_restore_camera_state(state) if state
  end

  def bss_pbSOSJoin(*args, &block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    state = bss082_camera_state
    old = @bss082_preserve_native_camera
    @bss082_preserve_native_camera = true
    super
  ensure
    @bss082_preserve_native_camera = old
    begin
      bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
      bss070_ebdx_recalibrate_if_needed if respond_to?(:bss070_ebdx_recalibrate_if_needed)
      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
    rescue
    end
    bss082_restore_camera_state(state) if state
  end

  # v21 scene interfaces vary slightly with installed DBK/Enhanced UI versions.
  # Wrap all common capture entry points. Methods which are not used by the
  # project are harmless; those that are used get EBDX BASE coordinates and a
  # stable screen-space camera for the whole throw.
  [:pbThrow, :pbThrowAndDeflect, :pbThrowPokeBall].each do |meth|
    define_method(meth) do |*args, &block|
      return super(*args, &block) unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
      state = bss082_camera_state
      old = @bss082_preserve_native_camera
      @bss082_preserve_native_camera = true
      result = nil
      begin
        result = bss070_ebdx_with_position_context { super(*args, &block) }
      ensure
        @bss082_preserve_native_camera = old
        bss082_restore_camera_state(state) if state
      end
      result
    end
  end

  # Enhanced UI creates outline sprites with names such as info_icon0_outline0.
  # 0.8.1 tested "info_icon" before "outline", so those outlines were promoted
  # above the icon. Outlines are now always one layer below the icon family.
  def bss080_enforce_enhanced_ui_z
    return if !@sprites.is_a?(Hash)
    @sprites.each do |key, sp|
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:z=)
      k = key.to_s
      begin
        icon_ui = (k =~ /(info_icon|ball_icon|item_icon|pokemon_icon|enhancedUI|prompt)/i)
        if icon_ui && k =~ /outline/i
          sp.z = 96019
        elsif icon_ui
          sp.z = [(sp.z rescue 0).to_i, 96020].max
        end
      rescue
      end
    end
  end

  # Capture/fade filters belong to the EBDX environment as a whole, not only the
  # main backdrop bitmap. Copy native scene color+tone to trees, sky, overlays,
  # custom imgs and the room background while leaving metric anchors untouched.
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
      next if k.start_with?("battler") || k.start_with?("shadow") || k.start_with?("trainer_")
      next if k =~ /(sLight|aLight|bLight|cLight|weather|w_sunny|w_sand|w_fog)/i
      begin
        if color_active && sp.respond_to?(:color=)
          if !sp.instance_variable_defined?(:@bss082_filter_base_color)
            bc = sp.color rescue nil
            sp.instance_variable_set(:@bss082_filter_base_color, Color.new(bc.red, bc.green, bc.blue, bc.alpha)) if bc
          end
          sp.color = Color.new(c.red, c.green, c.blue, c.alpha)
        elsif sp.instance_variable_defined?(:@bss082_filter_base_color) && sp.respond_to?(:color=)
          bc = sp.instance_variable_get(:@bss082_filter_base_color)
          sp.color = bc if bc
          sp.remove_instance_variable(:@bss082_filter_base_color) rescue nil
        end
      rescue
      end
      begin
        if tone_active && sp.respond_to?(:tone=)
          if !sp.instance_variable_defined?(:@bss082_filter_base_tone)
            bt = sp.tone rescue nil
            sp.instance_variable_set(:@bss082_filter_base_tone, Tone.new(bt.red, bt.green, bt.blue, bt.gray)) if bt
          end
          sp.tone = Tone.new(t.red, t.green, t.blue, t.gray)
        elsif sp.instance_variable_defined?(:@bss082_filter_base_tone) && sp.respond_to?(:tone=)
          bt = sp.instance_variable_get(:@bss082_filter_base_tone)
          sp.tone = bt if bt
          sp.remove_instance_variable(:@bss082_filter_base_tone) rescue nil
        end
      rescue
      end
    end
  rescue
  end

  # Build the original WildIntroNDS reveal from a snapshot of the actual EBDX
  # room. This keeps the original 200% -> 100%, HOLD/MOVE timings, flash and foe
  # reveal logic instead of feeding it the hidden Vanilla battle_bg bitmap.
  def bss082_wild_nds_snapshot
    return nil if !defined?(Graphics) || !Graphics.respond_to?(:snap_to_bitmap)
    room = @bss070_ebdx_room rescue nil
    return nil if !room || (room.disposed? rescue true)
    hidden = []
    old_color = nil
    begin
      if @viewport && @viewport.respond_to?(:color) && @viewport.respond_to?(:color=)
        c = @viewport.color
        old_color = Color.new(c.red, c.green, c.blue, c.alpha) rescue nil
        @viewport.color = Color.new(0, 0, 0, 0)
      end
      (@sprites || {}).each do |key, sp|
        next if key.to_s == "battlebg" || !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible)
        begin
          hidden << [sp, sp.visible]
          sp.visible = false if sp.respond_to?(:visible=)
        rescue
        end
      end
      room.update rescue nil
      Graphics.snap_to_bitmap
    ensure
      hidden.each { |sp, vis| begin; sp.visible = vis if sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible=); rescue; end }
      @viewport.color = old_color if old_color && @viewport && @viewport.respond_to?(:color=)
    end
  rescue => e
    BSS064.log("BSS082 NDS snapshot warning: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end

  def bss082_projected_base(side)
    idx = side.to_i
    size = (@battle.pbSideSize(idx) rescue 1).to_i
    base = BSS082.without_position_context { Battle::Scene.pbBattlerPosition(idx, size) }
    room = @bss070_ebdx_room rescue nil
    return base if !room || !room.respond_to?(:bss082_project_screen_point)
    room.bss082_project_screen_point(base[0], base[1])
  rescue
    side.to_i == 0 ? [128, Graphics.height - 80] : [Graphics.width - 128, (Graphics.height * 3 / 4) - 112]
  end

  def pbBattleIntroAnimation
    wild = @battle && @battle.respond_to?(:wildBattle?) && @battle.wildBattle?
    return super if !wild || !respond_to?(:bss070_ebdx_active?) || !bss070_ebdx_active?
    bss070_ebdx_ensure_core if respond_to?(:bss070_ebdx_ensure_core)

    nds_enabled = defined?(VermeilWildIntroNDS) && defined?(Battle::Scene::Animation::WildIntroReveal)
    nds_enabled &&= (VermeilWildIntroNDS.enabled? rescue true)
    if nds_enabled
      snap = bss082_wild_nds_snapshot
      if snap
        original = {}
        temps = []
        begin
          ["battle_bg", "battle_bg2", "base_0", "base_1"].each { |k| original[k] = (@sprites[k] rescue nil) }

          bg = Sprite.new(@viewport)
          bg.bitmap = snap
          bg.x = 0; bg.y = 0; bg.z = 0
          @sprites["battle_bg"] = bg
          temps << bg
          @sprites.delete("battle_bg2")

          2.times do |side|
            base = Sprite.new(@viewport)
            base.bitmap = Bitmap.new(2, 2)
            p = bss082_projected_base(side)
            base.x = p[0]; base.y = p[1]
            base.ox = 1; base.oy = 1; base.z = 1
            @sprites["base_#{side}"] = base
            temps << base
          end

          size = (@battle.sideSizes[1] rescue 1).to_i
          size = 1 if size < 1
          reveal = Battle::Scene::Animation::WildIntroReveal.new(@sprites, @viewport, size, @battle.battlers, @battle)
          @animations.push(reveal)
          wait = (VermeilWildIntroNDS.reveal_wait_frames rescue 20).to_i
          wait = 20 if wait < 20
          wait.times { pbUpdate }
        ensure
          ["battle_bg", "battle_bg2", "base_0", "base_1"].each do |k|
            if original.has_key?(k) && original[k]
              @sprites[k] = original[k]
            else
              @sprites.delete(k)
            end
          end
          temps.each do |sp|
            begin
              # Snapshot bitmap is owned by the temporary bg; dispose it once.
              sp.bitmap.dispose if sp.respond_to?(:bitmap) && sp.bitmap && !(sp.bitmap.disposed? rescue true)
            rescue
            end
            begin; sp.dispose if sp && !(sp.disposed? rescue true); rescue; end
          end
        end
        bss079_finish_wild_intro if respond_to?(:bss079_finish_wild_intro)
        return
      end
    end

    # Safe EBDX fallback. Never hand WildIntroReveal the hidden Vanilla backdrop.
    if respond_to?(:bss079_play_custom_wild_intro) && respond_to?(:bss079_finish_wild_intro)
      bss079_play_custom_wild_intro(true)
      bss079_finish_wild_intro
      return
    end
    super
  rescue => e
    BSS064.log("BSS082 wild intro warning: #{e.class}: #{e.message}") if defined?(BSS064)
    begin
      bss079_play_custom_wild_intro(true) if respond_to?(:bss079_play_custom_wild_intro)
      bss079_finish_wild_intro if respond_to?(:bss079_finish_wild_intro)
    rescue
      super
    end
  end
end
begin
  Battle::Scene.prepend(BSS082SceneAuthority) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS082SceneAuthority)
rescue => e
  BSS064.log("BSS082 scene authority install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# Enhanced Legacy Data reads Battle#@party2 from pbEndOfBattle, not only from the
# Scene cleanup. SOS legitimately leaves sparse slots, so expose a compact view
# only for that final reader and restore the real array immediately afterwards.
#-------------------------------------------------------------------------------
module BSS082LegacyPartyReadView
  def pbEndOfBattle(*args, &block)
    original = nil
    if instance_variable_defined?(:@party2)
      p2 = instance_variable_get(:@party2) rescue nil
      if p2.is_a?(Array) && p2.any?(&:nil?)
        original = p2
        instance_variable_set(:@party2, p2.compact)
      end
    end
    super
  ensure
    instance_variable_set(:@party2, original) if original
  end
end
begin
  Battle.prepend(BSS082LegacyPartyReadView) if defined?(Battle) && !Battle.ancestors.include?(BSS082LegacyPartyReadView)
rescue => e
  BSS064.log("BSS082 Legacy Data install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
