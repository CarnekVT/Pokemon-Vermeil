#===============================================================================
# Battle Scene Studio v0.8.24
# World-space battlers + native Wild Intro fallback.
#
# Camera rule:
# - the EBDX room is the world;
# - battlers/shadows/trainers use the room's projected metric anchors;
# - native/BAS battler animations temporarily keep their own authority;
# - once the animation finishes, the battler returns to its CURRENT world anchor,
#   not to a fixed screen coordinate.
#
# Wild Intro rule:
# - BSS custom wild intros are temporarily disabled;
# - Essentials/project-native pbBattleIntroAnimation is used instead.
#===============================================================================
module BSS103
  VERSION = "0.8.24"
  module_function

  def room_scale
    v=(BSS070EBDXCore::ROOM_SCALE rescue 1.0).to_f
    v=1.0 if v.abs < 0.0001
    v
  end
end

module BSS103WorldSpaceBattlers
  def bss103_formation_spacing_x(index)
    return 0.0 unless @battle && @battle.respond_to?(:pbSideSize)
    side_size=(@battle.pbSideSize(index) rescue 1).to_i
    return 0.0 if side_size<=1
    slot=index.to_i/2
    # Additional horizontal room beyond Essentials' native slot positions,
    # using more breadth on the player's near plane. All offsets are in
    # screen pixels after EBDX projection and mirrored for the shadow.
    if index.to_i.even?
      # Player-side allies are larger/closer to camera: give them slightly
      # more breathing room than the far-side opponents.
      return [-21.0,27.0][slot] if side_size==2 && slot<2
      return [-28.0,3.0,36.0][slot] if side_size==3 && slot<3
      return [[(slot-(side_size-1)/2.0)*29.0,-56.0].max,56.0].min
    else
      return [-15.0,22.0][slot] if side_size==2 && slot<2
      return [-21.0,3.0,26.0][slot] if side_size==3 && slot<3
      return [[(slot-(side_size-1)/2.0)*23.0,-46.0].max,46.0].min
    end
  rescue StandardError
    0.0
  end

  def bss070_ebdx_apply_world_alignment
    return if @bss070_ebdx_suspend_depth.to_i>0 || @bss070_ebdx_bas_frame
    return if @bss096_battler_anim_depth.to_i>0 || @bss087_native_move_active || @bss084_native_move_active
    return if @bss087_end_battle_lock
    return if !@bss070_ebdx_room || !@battle || !@sprites

    # DBK's Sprite Positioner writes species/form-specific metrics via
    # BattlerSprite#pbSetPosition. The EBDX metric floor is *not* that final
    # position: writing anchor.y directly discarded the positioner offsets
    # and launched sprites far above their authored floor.
    #
    # Use the real DBK positions (read through BSS096's native probe) as the
    # authoritative baseline. Only the shared EBDX camera's bounded pan is
    # composed on top. BAS, sendout and other animations stay excluded above.
    camera_dx=0.0
    camera_dy=0.0
    if @vector && defined?(BSS070EBDXCore) &&
       respond_to?(:vermeil_cinema_active?) && vermeil_cinema_active?
      current=@vector.get
      main=BSS070EBDXCore.get_vector(:MAIN,@battle)
      if current.is_a?(Array) && main.is_a?(Array)
        camera_dx=(current[0].to_f-main[0].to_f)*0.65
        camera_dy=(current[1].to_f-main[1].to_f)*0.45
      end
    end

    @battle.battlers.each_index do |i|
      sp=(bss070_ebdx_native_sprite(i) rescue nil)
      next unless sp && !(sp.disposed? rescue true)
      next unless (bss070_ebdx_sprite_loaded?(sp) rescue false)
      # pbSetPosition invokes the project's configured DBK SpeciesMetrics.
      native=(bss096_native_position(i) rescue nil)
      native=(bss070_ebdx_native_position_for(i) rescue nil) unless native.is_a?(Array) && native.length>=5
      next unless native.is_a?(Array) && native.length>=2
      offset_x=bss103_formation_spacing_x(i)
      sp.x=native[0].to_f+camera_dx+offset_x if sp.respond_to?(:x=)
      locked_y=(sp.instance_variable_get(:@bss_caller_locked_baseline_y) rescue nil)
      sp.y=locked_y || (native[1].to_f+camera_dy) if sp.respond_to?(:y=)
      if native.length>=5
        sp.zoom_x=native[3].to_f if sp.respond_to?(:zoom_x=) && native[3].to_f>0.02
        sp.zoom_y=native[4].to_f if sp.respond_to?(:zoom_y=) && native[4].to_f>0.02
      end
      sp.z=[(sp.z rescue 50).to_i,50+i].max if sp.respond_to?(:z=)

      sh=(bss070_ebdx_native_shadow_sprite(i) rescue nil)
      next unless sh && !(sh.disposed? rescue true)
      next unless (bss070_ebdx_sprite_loaded?(sh) rescue false)
      if @bss070_ebdx_room.respond_to?(:shadows_enabled?) &&
         !@bss070_ebdx_room.shadows_enabled?
        sh.visible=false if sh.respond_to?(:visible=)
        next
      end
      shadow=(bss096_native_shadow_position(i) rescue nil)
      shadow=(bss070_ebdx_native_shadow_position_for(i) rescue nil) unless shadow.is_a?(Array) && shadow.length>=5
      next unless shadow.is_a?(Array) && shadow.length>=2
      sh.x=shadow[0].to_f+camera_dx+offset_x if sh.respond_to?(:x=)
      locked_shadow_y=(sh.instance_variable_get(:@bss_caller_locked_baseline_y) rescue nil)
      sh.y=locked_shadow_y || (shadow[1].to_f+camera_dy) if sh.respond_to?(:y=)
      if shadow.length>=5
        sh.zoom_x=shadow[3].to_f if sh.respond_to?(:zoom_x=) && shadow[3].to_f>0.02
        sh.zoom_y=shadow[4].to_f if sh.respond_to?(:zoom_y=) && shadow[4].to_f>0.02
      end
      sh.z=[(sh.z rescue 3).to_i,30+i].max if sh.respond_to?(:z=)
    end

    # Animated Trainer Intros/DBK own real trainer sprite XY for the entire
    # sendout, speech and midbattle dialogue lifecycle. BSS only positions
    # its invisible trainer metric anchors, NEVER trainer_1/etc themselves.
    # This fixes trainers drifting upwards after the NDS handoff and
    # stops world recalibration undoing authored presentation keyframes.
    true
  rescue => e
    BSS064.log("BSS103 world battler alignment warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end
end

module BSS103NativeWildIntro
  def pbBattleIntroAnimation(*args,&block)
    wild=(@battle && @battle.respond_to?(:wildBattle?) && @battle.wildBattle?) rescue false
    if wild && respond_to?(:bss096_native_wild_intro)
      begin
        # Essentials intro methods typically return nil. That means SUCCESS,
        # not failure: the old code called super again and doubled the reveal.
        return bss096_native_wild_intro
      rescue StandardError => e
        BSS064.log("BSS103 native wild intro fallback warning: #{e.class}: #{e.message}") if defined?(BSS064)
        # Only failures may fall back, not a normal nil return.
      end
    end
    super(*args,&block)
  end
end

# Disable the standalone NDS gate as well. The assets/data remain in the project
# so the feature can be redesigned later without losing user configuration.
begin
  if defined?(BSS083StandaloneWildNDS)
    module BSS083StandaloneWildNDS
      class << self
        def enabled?(_scene); false; end
      end
    end
  end
rescue
end

begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSS103WorldSpaceBattlers) unless Battle::Scene.ancestors.include?(BSS103WorldSpaceBattlers)
    Battle::Scene.prepend(BSS103NativeWildIntro) unless Battle::Scene.ancestors.include?(BSS103NativeWildIntro)
  end
rescue => e
  BSS064.log("BSS103 install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
