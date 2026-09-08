#===============================================================================
# BSS v0.8.18 - requested parity/fidelity/runtime fixes
#===============================================================================

module BSS097BallHelperParity
  def self.endpoint(animation, fallback_x, fallback_y)
    begin
      if defined?(BSS095)
        ep=BSS095.sendout_endpoint(animation, fallback_x, fallback_y) rescue nil
        return ep if ep.is_a?(Array) && ep.length>=2
      end
    rescue
    end
    begin
      if defined?(BSS096BallHelpers)
        x=fallback_x.to_f; y=fallback_y.to_f
        return [BSS096.clamp(x,18,Graphics.width-18), BSS096.clamp(y,22,Graphics.height-22)]
      end
    rescue
    end
    [fallback_x.to_f, fallback_y.to_f]
  end
end

begin
  module BSS096BallHelpers
    module_function
    def endpoint(animation, fallback_x, fallback_y)
      BSS097BallHelperParity.endpoint(animation, fallback_x, fallback_y)
    end
  end
rescue
end

module BSS097BallSpin
  def createBallTrajectory(*args)
    ret=super
    begin
      ball=args[0]
      delay=(args.length>=2 ? args[1].to_i : 0)
      duration=(args.length>=3 ? args[2].to_i : 18)
      createBallTumbling(ball,delay,duration) if respond_to?(:createBallTumbling)
    rescue
    end
    ret
  end
end

module BSS097TrainerBallSpin
  def createBallTrajectory(*args)
    ret=super
    begin
      ball=args[0]
      createBallTumbling(ball,0,20) if respond_to?(:createBallTumbling)
    rescue
    end
    ret
  end
end

module BSS097RoomFrameGuard
  def update
    frame=(Graphics.frame_count rescue nil)
    if !frame.nil? && @bss097_last_update_frame==frame
      return if self.disposed? rescue false
      begin
        @sprites["bg"].x=@scene.vector.x2 if @sprites["bg"] && @scene && @scene.respond_to?(:vector) && @scene.vector
        @sprites["bg"].y=@scene.vector.y2 if @sprites["bg"] && @scene && @scene.respond_to?(:vector) && @scene.vector
        if @sprites["bg"] && @scene && @scene.respond_to?(:vector) && @scene.vector
          sx, sy = @scene.vector.spoof(@defaultvector)
          denx=(sx - @defaultvector[0]).to_f; denx=0.001 if denx.abs < 0.001
          deny=(sy - @defaultvector[1]).to_f; deny=0.001 if deny.abs < 0.001
          @sprites["bg"].zoom_x = @scale*((@scene.vector.x2 - @scene.vector.x).to_f/denx)**0.6
          @sprites["bg"].zoom_y = @scale*((@scene.vector.y2 - @scene.vector.y).to_f/deny)**0.6
        end
        clamp_camera_to_viewport! if respond_to?(:clamp_camera_to_viewport!)
        position if respond_to?(:position)
        updateSky if respond_to?(:updateSky)
        @scene.bss070_ebdx_apply_shadow_policy(@data.has_key?("noshadow") && @data["noshadow"] == true) if @scene && @scene.respond_to?(:bss070_ebdx_apply_shadow_policy)
      rescue
      end
      return
    end
    @bss097_last_update_frame=frame unless frame.nil?
    super
  end
end

module BSS097SceneUIParity
  def bss085_enhanced_ui_layers
    super if defined?(super)
    return if !@sprites.is_a?(Hash)
    main=@sprites["enhancedUI"] rescue nil; main.z=11000 if main && !(main.disposed? rescue true) && main.respond_to?(:z=)
    prompt=@sprites["enhancedUIPrompts"] rescue nil; prompt.z=11060 if prompt && !(prompt.disposed? rescue true) && prompt.respond_to?(:z=)
    ["leftarrow","rightarrow"].each do |k|
      sp=@sprites[k] rescue nil
      sp.z=11100 if sp && !(sp.disposed? rescue true) && sp.respond_to?(:z=)
    end
    @sprites.each do |k,sp|
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:z=)
      s=k.to_s
      if s =~ /^(info_icon|ball_icon).*_outline\d+$/i
        sp.z=11134
      elsif s =~ /^(info_icon|ball_icon)\d+$/i
        sp.z=11142
      end
    end
  rescue
  end

  def pbUpdate(*args,&block)
    ret=super
    begin
      cmd=(@sprites["commandWindow"].visible rescue false)
      fight=(@sprites["fightWindow"].visible rescue false)
      if cmd || fight
        ui=@sprites["enhancedUI"] rescue nil
        ui.visible=true if ui && ui.respond_to?(:visible=)
        pbUpdateInfoSprites if respond_to?(:pbUpdateInfoSprites)
        bss085_enhanced_ui_layers if respond_to?(:bss085_enhanced_ui_layers)
        bss085_enhanced_prompt_guard if respond_to?(:bss085_enhanced_prompt_guard)
      end
    rescue
    end
    ret
  end
end

module BSS097EncounterBackdropRuntime
  CONTEXT_IVARS = [:@encounter_type,:@encounterType,:@encountertype,:@last_encounter_type,:@lastEncounterType]
  module_function
  def current_context
    if defined?($PokemonTemp) && $PokemonTemp
      CONTEXT_IVARS.each do |iv|
        next unless $PokemonTemp.instance_variable_defined?(iv)
        v=$PokemonTemp.instance_variable_get(iv) rescue nil
        s=v.to_s.strip
        return s if !s.empty?
      end
    end
    nil
  rescue
    nil
  end
  def context_backdrop
    rows=(BSS070EBDXCore.global_config["ebdxEncounterMetadata"] rescue nil)
    return nil if !rows.is_a?(Array) || rows.empty?
    ctx=current_context.to_s.downcase
    row=rows.find{|r| r.is_a?(Hash) && (r["context"] || r[:context]).to_s.downcase==ctx }
    return nil if !row
    name=(row["backdrop"] || row[:backdrop]).to_s.strip
    return nil if name.empty? || ["auto","inherit"].include?(name.downcase)
    found=(BSS070EBDXCore::BUILTIN.keys.find{|k| k.to_s.downcase==name.downcase } rescue nil)
    found || name
  rescue
    nil
  end
end

begin
  module BSS070EBDXCore
    class << self
      alias bss097_map_backdrop_without_context map_backdrop unless method_defined?(:bss097_map_backdrop_without_context)
      def map_backdrop
        bss_map_backdrop || BSS097EncounterBackdropRuntime.context_backdrop || original_ebdx_map_backdrop
      rescue
        bss097_map_backdrop_without_context rescue nil
      end
      alias bss097_camera_config_without_profile camera_config unless method_defined?(:bss097_camera_config_without_profile)
      def camera_config
        cfg=bss097_camera_config_without_profile
        g=global_config
        cam=(g["ebdxCamera"] || g[:ebdxCamera] || {}) rescue {}
        profile=(cam["profile"] || cam[:profile] || cam["preset"] || cam[:preset]).to_s.downcase
        if profile=="static"
          cfg=cfg.merge({"idleStrength"=>0.0,"commandStrength"=>0.0,"fightStrength"=>0.0,"panX"=>0.0,"panY"=>0.0,"angle"=>0.0,"perspective"=>0.0,"zoom"=>100.0,"battlerInfluence"=>0.0,"shadowInfluence"=>0.0})
        end
        cfg
      rescue
        bss097_camera_config_without_profile rescue {}
      end
    end
  end
rescue
end

class Battle::Scene::Animation::BSSSOSJoin < Battle::Scene::Animation
  def createProcesses
    delay = 0
    battlers = (@battle.battlers rescue []) || []
    battlers.each do |b|
      next if !b || b.opposes?(@idx_sos)
      bat = @sprites["pokemon_#{b.index}"] rescue nil
      sha = @sprites["shadow_#{b.index}"] rescue nil
      boxsp = @sprites["dataBox_#{b.index}"] rescue nil
      next if !bat
      if b.index == @idx_sos
        side_size = bat.respond_to?(:sideSize) && bat.sideSize ? bat.sideSize : @battle.pbSideSize(b.index)
        _nx, _ny, native_z = bss_sos_battler_position(b, side_size, bat)
        obj = addSprite(bat, PictureOrigin::BOTTOM)
        obj.setZ(delay, native_z) if obj.respond_to?(:setZ)
        obj.setTone(delay, Tone.new(-196, -196, -196, -196))
        obj.setOpacity(delay, 0)
        obj.setVisible(delay, true)
        obj.moveOpacity(delay, 2, 255)
        obj.moveTone(delay + 2, 6, Tone.new(0, 0, 0, 0), [bat, :pbPlayIntroAnimation])
        if sha
          sha.visible = false
          _sx, _sy, native_shadow_z = bss_sos_shadow_position(b, side_size, sha)
          sh = addSprite(sha, PictureOrigin::CENTER)
          sh.setZ(delay, native_shadow_z) if sh.respond_to?(:setZ)
          sh.setOpacity(delay, 0)
          sh.setVisible(delay, true)
          sh.moveOpacity(delay, 2, 255)
        end
        if boxsp
          bx = addSprite(boxsp)
          mode=(BSS064.databox_animation_mode rescue "slide")
          case mode
          when "pop"
            bx.setOpacity(delay,255) if bx.respond_to?(:setOpacity)
            bx.setVisible(delay,true)
          when "fade"
            bx.setOpacity(delay,0)
            bx.setVisible(delay,true)
            bx.moveOpacity(delay,4,255)
          else
            dir = b.index.even? ? 1 : -1
            bx.setOpacity(delay,255) if bx.respond_to?(:setOpacity)
            bx.setDelta(delay, dir * Graphics.width / 4, 0)
            bx.setVisible(delay, true)
            bx.moveDelta(delay, 4, -dir * Graphics.width / 4, 0)
          end
        end
      else
        side_size = bat.respond_to?(:sideSize) && bat.sideSize ? bat.sideSize : @battle.pbSideSize(b.index)
        new_x, new_y, new_z = bss_sos_battler_position(b, side_size, bat)
        obj = addSprite(bat, PictureOrigin::BOTTOM)
        obj.setZ(delay, new_z) if obj.respond_to?(:setZ)
        obj.moveXY(delay, 2, new_x, new_y)
        if sha
          shadow_size = sha.respond_to?(:sideSize) && sha.sideSize ? sha.sideSize : side_size
          sx, sy, sz = bss_sos_shadow_position(b, shadow_size, sha)
          sh = addSprite(sha, PictureOrigin::CENTER)
          sh.setZ(delay, sz) if sh.respond_to?(:setZ)
          sh.moveXY(delay, 2, sx, sy)
        end
        if boxsp
          bx=addSprite(boxsp)
          from=boxsp.instance_variable_get(:@bss656_reflow_from_xy) rescue nil
          to=boxsp.instance_variable_get(:@bss656_reflow_to_xy) rescue nil
          if from.is_a?(Array) && to.is_a?(Array)
            bx.setXY(delay,from[0],from[1])
            bx.moveXY(delay,2,to[0],to[1])
            boxsp.instance_variable_set(:@bss656_reflow_from_xy,nil) rescue nil
            boxsp.instance_variable_set(:@bss656_reflow_to_xy,nil) rescue nil
          end
          hide_for_boss=false
          begin
            boss=(@battle.bss_find_boss_battler_any rescue nil) if @battle.respond_to?(:bss_find_boss_battler_any)
            boss ||= (@battle.bss_find_boss_battler rescue nil) if @battle.respond_to?(:bss_find_boss_battler)
            cfg=(@battle.bss_boss_hud_config rescue {}) if @battle.respond_to?(:bss_boss_hud_config)
            hide_for_boss=(@battle.respond_to?(:bss_boss_enabled?) && @battle.bss_boss_enabled? && boss && boss.equal?(b) && cfg.is_a?(Hash) && cfg["enabled"]!=false)
          rescue
            hide_for_boss=false
          end
          bx.setVisible(delay,true) if !hide_for_boss
        end
      end
    end
  end
end

begin
  if defined?(BSS070EBDXRoom)
    BSS070EBDXRoom.prepend(BSS097RoomFrameGuard) unless BSS070EBDXRoom.ancestors.include?(BSS097RoomFrameGuard)
  end
rescue => e
  BSS064.log("BSS097 room guard install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSS097SceneUIParity) unless Battle::Scene.ancestors.include?(BSS097SceneUIParity)
  end
rescue => e
  BSS064.log("BSS097 scene UI install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  mix=Battle::Scene::Animation::BallAnimationMixin
  mix.prepend(BSS097BallSpin) if defined?(mix) && !mix.ancestors.include?(BSS097BallSpin)
rescue => e
  BSS064.log("BSS097 player ball spin install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  k=Battle::Scene::Animation::PokeballTrainerSendOut
  k.prepend(BSS097TrainerBallSpin) if defined?(k) && !k.ancestors.include?(BSS097TrainerBallSpin)
rescue => e
  BSS064.log("BSS097 trainer ball spin install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
