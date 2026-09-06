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
  def bss070_ebdx_apply_world_alignment
    return if @bss070_ebdx_suspend_depth.to_i>0 || @bss070_ebdx_bas_frame
    return if @bss096_battler_anim_depth.to_i>0 || @bss087_native_move_active || @bss084_native_move_active
    return if @bss087_end_battle_lock
    return if !@bss070_ebdx_room || !@battle || !@sprites

    bss070_ebdx_recalibrate_if_needed if respond_to?(:bss070_ebdx_recalibrate_if_needed)
    scale0=BSS103.room_scale

    @battle.battlers.each_index do |i|
      sp=(bss070_ebdx_native_sprite(i) rescue nil)
      next if !sp || (sp.disposed? rescue true) || !(bss070_ebdx_sprite_loaded?(sp) rescue true)
      anchor=(@bss070_ebdx_room.battler(i) rescue nil)
      next if !anchor || (anchor.disposed? rescue false)

      # The invisible EBDX metric anchor is authored from Essentials' real
      # pbBattlerPosition and projected by the same room matrix as scenery.
      sp.x=anchor.x if sp.respond_to?(:x=)
      sp.y=anchor.y if sp.respond_to?(:y=)
      base=(bss070_ebdx_anchor_scale(i) rescue [1.0,1.0])
      factor=((anchor.zoom_x rescue scale0).to_f/scale0)
      factor=1.0 if !factor.finite? || factor<=0
      sp.zoom_x=base[0].to_f*factor if sp.respond_to?(:zoom_x=)
      sp.zoom_y=base[1].to_f*factor if sp.respond_to?(:zoom_y=)
      sp.z=[(anchor.z rescue 50).to_i,50+i].max if sp.respond_to?(:z=)

      sh=(bss070_ebdx_native_shadow_sprite(i) rescue nil)
      if sh && !(sh.disposed? rescue true) && (bss070_ebdx_sprite_loaded?(sh) rescue true)
        if @bss070_ebdx_room.respond_to?(:shadows_enabled?) && !@bss070_ebdx_room.shadows_enabled?
          sh.visible=false if sh.respond_to?(:visible=)
        else
          sa=(@bss070_ebdx_room.shadow(i) rescue nil)
          if sa && !(sa.disposed? rescue false)
            sh.x=sa.x if sh.respond_to?(:x=)
            sh.y=sa.y if sh.respond_to?(:y=)
            sb=(bss070_ebdx_shadow_anchor_scale(i) rescue [1.0,0.25])
            sf=((sa.zoom_x rescue scale0).to_f/scale0)
            sf=1.0 if !sf.finite? || sf<=0
            sh.zoom_x=sb[0].to_f*sf if sh.respond_to?(:zoom_x=)
            sh.zoom_y=sb[1].to_f*sf if sh.respond_to?(:zoom_y=)
            sh.z=[(sa.z rescue 3).to_i,30+i].max if sh.respond_to?(:z=)
          end
        end
      end
    end

    # Trainers use the same world projection while they are present.
    if @battle.opponent
      @battle.opponent.each_index do |t|
        sp=(@sprites["trainer_#{t}"] rescue nil)
        next if !sp || (sp.disposed? rescue true)
        a=(@bss070_ebdx_room.trainer(t*2+1) rescue nil)
        next if !a || (a.disposed? rescue false)
        sp.x=a.x if sp.respond_to?(:x=)
        sp.y=a.y if sp.respond_to?(:y=)
      end
    end
    true
  rescue => e
    BSS064.log("BSS103 world battler alignment warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end
end

module BSS103NativeWildIntro
  def pbBattleIntroAnimation(*args,&block)
    wild=(@battle && @battle.respond_to?(:wildBattle?) && @battle.wildBattle?) rescue false
    if wild
      # BSS096 already knows how to walk past every BSS intro prepend and reach
      # the real project/Essentials implementation. Use it while custom Wild
      # Intro authoring is intentionally suspended.
      if respond_to?(:bss096_native_wild_intro)
        begin
          return bss096_native_wild_intro
        rescue => e
          BSS064.log("BSS103 native wild intro fallback warning: #{e.class}: #{e.message}") if defined?(BSS064)
        end
      end
    end
    super
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
