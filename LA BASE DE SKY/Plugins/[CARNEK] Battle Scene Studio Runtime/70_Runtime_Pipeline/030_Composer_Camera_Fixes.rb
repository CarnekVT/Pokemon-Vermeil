#===============================================================================
# Battle Scene Studio v0.8.23
# Composer/runtime parity, stable ambient camera, cloud/rigid/tint authoring,
# safe raster fallback and Boss-SOS flee lifecycle.
#===============================================================================
module BSS102
  VERSION = "0.8.23"
  module_function

  def num(v, fallback=0.0)
    return fallback.to_f if v.nil?
    return v.to_f if v.is_a?(Numeric)
    s=v.to_s.strip
    return fallback.to_f if s.empty?
    s.to_f
  rescue
    fallback.to_f
  end

  def hget(h,key)
    return nil unless h.is_a?(Hash)
    h[key] || h[key.to_s] || h[key.to_sym]
  rescue
    nil
  end

  def file_bitmap_exists?(path)
    p=path.to_s.strip
    return false if p.empty?
    candidates=[p]
    if File.extname(p).to_s.empty?
      candidates += [p+".png",p+".jpg",p+".jpeg",p+".bmp"]
    end
    candidates.any?{|x| File.file?(x) rescue false}
  rescue
    false
  end

  def color_from_hex(value,alpha=0)
    s=value.to_s.strip
    return nil unless s =~ /\A#?([0-9a-fA-F]{6})\z/
    hex=$1
    Color.new(hex[0,2].to_i(16),hex[2,2].to_i(16),hex[4,2].to_i(16),[[alpha.to_i,0].max,255].min)
  rescue
    nil
  end

  def camera_config(scene=nil)
    cfg=(scene && scene.respond_to?(:bss070_ebdx_camera_config) ? scene.bss070_ebdx_camera_config : BSS070EBDXCore.camera_config) rescue {}
    cfg.is_a?(Hash) ? cfg : {}
  rescue
    {}
  end

  def static_camera?(scene)
    cfg=camera_config(scene)
    mode=(cfg["profile"] || cfg[:profile] || cfg["preset"] || cfg[:preset]).to_s.downcase
    mode=="static"
  rescue
    false
  end

  def command_overview?(scene)
    cfg=camera_config(scene)
    cfg["commandOverviewEnabled"]==true || cfg[:commandOverviewEnabled]==true
  rescue
    false
  end
end

#-------------------------------------------------------------------------------
# Runtime raster: do not call pbResolveBitmap on a missing generated path. mkxp
# logs ENOENT even when that exception is rescued. Missing generated images now
# silently fall back to the original source + crop/warp data.
#-------------------------------------------------------------------------------
module BSS102RuntimeRasterSafety
  def prepare_scene(data)
    out=BSS098.deep_copy(data)
    return out unless out.is_a?(Hash)
    if out[:sky] || out["sky"] || out[:skyMode] || out["skyMode"] || out[:cloudsConfig] || out["cloudsConfig"]
      out[:outdoor] = true
      out["outdoor"] = true
    end
    BSS106.prune_hidden!(out) if defined?(BSS106) && BSS106.respond_to?(:prune_hidden!)
    out.each do |raw_key,row|
      next unless raw_key.to_s =~ /^img\d+/i && row.is_a?(Hash)
      BSS106.apply_authored_tint!(row, out) if defined?(BSS106) && BSS106.respond_to?(:apply_authored_tint!)
      warp=BSS098.hash_get(row,:warp)
      has_warp=warp.is_a?(Hash) && warp[:enabled] != false && warp["enabled"] != false
      areas=BSS098.hash_get(row,:blurAreas)
      has_blur=(areas.is_a?(Array) && areas.any?{|a| a.is_a?(Hash) && (BSS102.num(a[:radius]||a["radius"],0)>0 || (a[:mode]||a["mode"]).to_s.start_with?("band") || (a[:mode]||a["mode"]).to_s=="total")}) || BSS102.num(BSS098.hash_get(row,:blur),0) > 0
      rr=BSS098.hash_get(row,:runtimeRaster)
      if rr.is_a?(Hash)
        path=BSS098.hash_get(rr,:bitmap).to_s.strip
        if !has_warp && !has_blur
          row.delete(:runtimeRaster); row.delete("runtimeRaster")
        elsif BSS102.file_bitmap_exists?(path)
          row[:bitmap]=path
          row["bitmap"]=path
          crop=BSS098.hash_get(row,:crop)
          def_ox=crop.is_a?(Hash) ? BSS102.num(crop[:w]||crop["w"],32)/2 : (BSS098.hash_get(row,:ox) || 0)
          def_oy=crop.is_a?(Hash) ? BSS102.num(crop[:h]||crop["h"],32) : (BSS098.hash_get(row,:oy) || 0)
          ox=BSS102.num(BSS098.hash_get(rr,:ox), def_ox)
          oy=BSS102.num(BSS098.hash_get(rr,:oy), def_oy)
          row[:ox]=ox; row["ox"]=ox
          row[:oy]=oy; row["oy"]=oy
          [:warp,"warp",:blurAreas,"blurAreas",:blur,"blur",:crop,"crop",:runtimeRaster,"runtimeRaster"].each{|k|row.delete(k)}
          row[:bss_rasterized]=true
          row["bss_rasterized"]=true
        else
          row.delete(:runtimeRaster); row.delete("runtimeRaster")
        end
      end
      # Protect against 100% entered as 100 instead of 1.0
      zx=BSS102.num(row[:zoom_x] || row["zoom_x"], 0)
      zy=BSS102.num(row[:zoom_y] || row["zoom_y"], 0)
      if zx >= 50.0
        zx = [[zx / 100.0, 0.05].max, 8.0].min
        row[:zoom_x]=zx; row["zoom_x"]=zx
      end
      if zy >= 50.0
        zy = [[zy / 100.0, 0.05].max, 8.0].min
        row[:zoom_y]=zy; row["zoom_y"]=zy
      end
      effect=BSS098.hash_get(row,:effect).to_s
      row[:effect]="bss_wind" if effect=="wind"
      row[:effect]="bss_rotate" if effect=="rotate"
    end
    out
  rescue => e
    BSS064.log("BSS102 prepare scene warning: #{e.class}: #{e.message}") if defined?(BSS064)
    data
  end
end

#-------------------------------------------------------------------------------
# Custom-layer integration. Rigid projection follows camera/world placement but
# uses one uniform camera scale, so a project tile/prop is never anisotropically
# stretched by EBDX perspective. Manual tint is independent of daylight tone.
# Cloud coordinates/speeds are source EBDX coordinates.
#-------------------------------------------------------------------------------
module BSS102RoomAuthoringParity
  def drawImg(key)
    ret=super
    begin
      row=@data[key] || @data[key.to_s] || @data[key.to_sym]
      sp=@sprites[key.to_s] || @sprites[key]
      if row.is_a?(Hash) && sp && !(sp.disposed? rescue true)
        slot=defined?(BSS106) && BSS106.respond_to?(:time_slot) ? BSS106.time_slot(@data) : :day
        prefix=(slot==:night ? 'Night' : (slot==:dawn ? 'Dawn' : 'Day'))
        color_val=row["tint#{prefix}Color"] || row["tint#{prefix}Color".to_sym] || BSS102.hget(row,:tintColor)
        alpha_val=row["tint#{prefix}Alpha"] || row["tint#{prefix}Alpha".to_sym] || BSS102.hget(row,:tintAlpha)
        color=BSS102.color_from_hex(color_val,BSS102.num(alpha_val,0).round)
        sp.color=color if color && sp.respond_to?(:color=)
      end
    rescue => e
      BSS064.log("BSS102 layer tint warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    ret
  end

  def drawSky
    ret=super
    begin
      cfg=BSS102.hget(@data,:cloudsConfig)
      if cfg.is_a?(Hash)
        pairs=[["cloud0",1,98,1.0,1],["cloud1",2,91,0.5,-1]]
        pairs.each do |sprite_key,n,dy,ds,dd|
          sp=@sprites[sprite_key]
          next if !sp || (sp.disposed? rescue true)
          enabled=BSS102.hget(cfg,:enabled)
          if enabled==false
            sp.visible=false if sp.respond_to?(:visible=)
            next
          end
          sp.ex=BSS102.num(BSS102.hget(cfg,"cloud#{n}X"),0) if sp.respond_to?(:ex=)
          sp.ey=BSS102.num(BSS102.hget(cfg,"cloud#{n}Y"),dy) if sp.respond_to?(:ey=)
          sp.speed=[BSS102.num(BSS102.hget(cfg,"cloud#{n}Speed"),ds).abs,0.01].max if sp.respond_to?(:speed=)
          sp.direction=BSS102.num(BSS102.hget(cfg,"cloud#{n}Direction"),dd)<0 ? -1 : 1 if sp.respond_to?(:direction=)
          sp.opacity=[[BSS102.num(BSS102.hget(cfg,"cloud#{n}Opacity"),255).round,0].max,255].min if sp.respond_to?(:opacity=)
        end
      end
    rescue => e
      BSS064.log("BSS102 cloud setup warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    ret
  end

  def position
    ret=super
    begin
      bg=@sprites && @sprites["bg"]
      if bg && @data.is_a?(Hash)
        uniform=Math.sqrt((bg.zoom_x.to_f*bg.zoom_y.to_f).abs)
        uniform=(bg.zoom_x.to_f.abs+bg.zoom_y.to_f.abs)/2.0 if uniform<=0.001
        slot=defined?(BSS106) && BSS106.respond_to?(:time_slot) ? BSS106.time_slot(@data) : :day
        prefix=(slot==:night ? 'Night' : (slot==:dawn ? 'Dawn' : 'Day'))
        @data.each do |raw_key,row|
          next unless raw_key.to_s =~ /^img\d+/i && row.is_a?(Hash)
          bitmap=BSS102.hget(row,:bitmap).to_s.tr("\\","/")
          inferred=(bitmap =~ %r{^Graphics/Tilesets/}i || bitmap =~ %r{/SceneAssets/(?:Cutouts|Props)/}i)
          projection=BSS102.hget(row,:projection).to_s
          rigid=(projection=="rigid" || (projection.empty? && (BSS102.hget(row,:bssRigid)==true || inferred)))
          next unless rigid
          sp=@sprites[raw_key.to_s] || @sprites[raw_key]
          next if !sp || (sp.disposed? rescue true)
          general=BSS102.num(BSS102.hget(row,:zoom),1.0)
          sx=BSS102.hget(row,:zoom_x).nil? ? general : BSS102.num(BSS102.hget(row,:zoom_x),general)
          sy=BSS102.hget(row,:zoom_y).nil? ? general : BSS102.num(BSS102.hget(row,:zoom_y),general)
          sp.zoom_x=uniform*sx if sp.respond_to?(:zoom_x=)
          sp.zoom_y=uniform*sy if sp.respond_to?(:zoom_y=)
          color_val=row["tint#{prefix}Color"] || row["tint#{prefix}Color".to_sym] || BSS102.hget(row,:tintColor)
          alpha_val=row["tint#{prefix}Alpha"] || row["tint#{prefix}Alpha".to_sym] || BSS102.hget(row,:tintAlpha)
          color=BSS102.color_from_hex(color_val,BSS102.num(alpha_val,0).round)
          sp.color=color if color && sp.respond_to?(:color=)
        end
      end
    rescue => e
      BSS064.log("BSS102 rigid projection warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    ret
  end
end

#-------------------------------------------------------------------------------
# Final scene camera. Ambient movement is visible from battle start, does not
# wait for capture/flee, and does not use command/move/SOS-specific shots. An
# optional command overview is the only deliberate temporary zoom-out.
# Native/BAS animations suspend camera retargeting but the room keeps updating.
#-------------------------------------------------------------------------------
module BSS102AmbientCamera
  def bss102_main_vector
    (BSS070EBDXCore.get_vector(:MAIN,@battle) rescue @vector.get).map{|x|x.to_f}
  rescue
    [102.0,408.0,32.0,342.0,1.0,1.0]
  end

  def bss102_next_ambient_target
    return if !@vector
    main=bss102_main_vector
    rows=[]
    begin
      src=BSS070EBDXCore.const_get(:CAMERA_MOTION)
      rows=src.select{|r|r.is_a?(Array)&&r.length>=5} if src.is_a?(Array)
    rescue
      rows=[]
    end
    if rows.empty?
      if respond_to?(:bss100_ambient_pick_target)
        bss100_ambient_pick_target
        @bss102_ambient_due=@bss100_ambient_due
      else
        @vector.inc=0.006 if @vector.respond_to?(:inc=)
        @vector.set(main) if @vector.respond_to?(:set)
        @bss102_ambient_due=120
      end
      return
    end
    raw=rows[@bss102_ambient_index.to_i % rows.length]
    @bss102_ambient_index=@bss102_ambient_index.to_i+1
    target=main.clone
    # Source-like, but restrained enough to preserve authored sea/floor framing.
    target[0]=main[0]+(raw[0].to_f-main[0])*0.24
    target[1]=main[1]+(raw[1].to_f-main[1])*0.095
    target[2]=main[2]+(raw[2].to_f-main[2])*0.045
    target[3]=main[3]+(raw[3].to_f-main[3])*0.025
    target[4]=main[4]+((raw[4] || 1).to_f-main[4])*0.02
    target[5]=main[5]+((raw[5] || raw[4] || 1).to_f-main[5])*0.02
    @vector.inc=0.0062 if @vector.respond_to?(:inc=)
    @vector.set(target) if @vector.respond_to?(:set)
    @bss102_ambient_due=96+rand(65)
  rescue => e
    BSS064.log("BSS102 ambient target warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss102_command_overview_enter
    false
  end

  def bss102_command_overview_leave
    return unless @bss102_command_overview
    saved=@bss102_command_saved
    @bss102_command_overview=false
    @bss102_command_saved=nil
    if saved && @vector
      @vector.inc=0.018 if @vector.respond_to?(:inc=)
      @vector.set(saved) if @vector.respond_to?(:set)
      @bss102_ambient_due=72
    end
  rescue
  end

  def pbInitSprites(*args,&block)
    ret=super
    @bss102_ambient_due=8
    @bss102_ambient_index=0
    @bss102_last_world_tick=nil
    ret
  end

  def bss070_ebdx_tick(advance_camera=true,align=true)
    super(advance_camera, align)
  rescue => e
    BSS064.log("BSS102 world tick warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  # Only optional command overview. Fight/moves/SOS remain environmental.
  def pbCommandMenu(*args,&block)
    active=(respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?) rescue false
    bss102_command_overview_enter if active && !BSS102.static_camera?(self)
    super
  ensure
    bss102_command_overview_leave if active
  end

  # Removed camera_enter overrides to allow zooms

  # No snap after Aura/BAS/native move. The room keeps animating while camera
  # ownership is suspended, then returns once and smoothly to the saved vector.
  def bss070_ebdx_suspend_world(*args,&block)
    return yield if @bss083_animation_projection || @bss084_native_move_active
    outer=@bss070_ebdx_suspend_depth.to_i<=0
    saved=(@vector.get.clone rescue nil) if outer && @vector
    room=nil
    if outer
      room=@bss070_ebdx_room rescue nil
      room=@sprites["battlebg"] if (!room || (room.disposed? rescue false)) && @sprites.is_a?(Hash)
      begin; room.defocus if room && room.respond_to?(:defocus); rescue; end
    end
    @bss070_ebdx_suspend_depth=@bss070_ebdx_suspend_depth.to_i+1
    yield
  ensure
    @bss070_ebdx_suspend_depth=[@bss070_ebdx_suspend_depth.to_i-1,0].max
    if outer && @bss070_ebdx_suspend_depth==0
      begin; room.focus if room && room.respond_to?(:focus); rescue; end
      if saved && @vector
        @vector.inc=0.016 if @vector.respond_to?(:inc=)
        @vector.set(saved) if @vector.respond_to?(:set)
        @bss102_ambient_due=72
      end
    end
  end
end

#-------------------------------------------------------------------------------
# bss096_clear_native_position_cache sometimes receives a Battler object from a
# late sendout/SOS refresh. Accept either Battler or Integer.
#-------------------------------------------------------------------------------
module BSS102PositionCacheFix
  def bss096_clear_native_position_cache(index=nil)
    if index.nil?
      @bss096_native_position_cache={}; @bss096_native_shadow_cache={}
    else
      i=index.respond_to?(:index) ? index.index.to_i : index.to_i
      (@bss096_native_position_cache||={}).delete_if{|k,_|k[0].to_i==i}
      (@bss096_native_shadow_cache||={}).delete_if{|k,_|k[0].to_i==i}
    end
    true
  rescue => e
    BSS064.log("BSS102 native position cache warning: #{e.class}: #{e.message}") if defined?(BSS064)
    true
  end
end

#-------------------------------------------------------------------------------
# If Boss cleanup is configured as "flee", a helper reduced to 0 in the same
# move as the Boss must flee instead of first playing a faint animation.
#-------------------------------------------------------------------------------
module BSS102SOSFleeInsteadOfFaint
  def pbFaint(showMessage=true)
    return if @fainted || @bss_fainting
    battle=@battle rescue nil
    if battle && !battle.instance_variable_get(:@bss102_helper_flee_in_progress) && battle.respond_to?(:bss_find_boss_battler_any) && battle.respond_to?(:bss656_sos_on_boss_defeat)
      boss=(battle.bss_find_boss_battler_any rescue nil)
      if boss && !boss.equal?(self) && !(opposes?(boss.index) rescue true) && (boss.hp rescue 1).to_i<=0 && (battle.bss656_sos_on_boss_defeat rescue "faint").to_s=="flee" && battle.respond_to?(:bss656_flee_boss_helper)
        begin
          battle.instance_variable_set(:@bss102_helper_flee_in_progress,true)
          ok=battle.bss656_flee_boss_helper(self,false)
          @fainted=true if ok
          return true if ok
        ensure
          battle.instance_variable_set(:@bss102_helper_flee_in_progress,false)
        end
      end
    end
    @bss_fainting=true
    begin
      ret=super(showMessage)
      @fainted=true
      ret
    ensure
      @bss_fainting=false
    end
  end
end

#-------------------------------------------------------------------------------
# Install final authorities.
#-------------------------------------------------------------------------------
begin
  if defined?(BSS098)
    sc=BSS098.singleton_class
    sc.prepend(BSS102RuntimeRasterSafety) unless sc.ancestors.include?(BSS102RuntimeRasterSafety)
  end
rescue => e
  BSS064.log("BSS102 raster safety install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  if defined?(BSS070EBDXRoom)
    BSS070EBDXRoom.prepend(BSS102RoomAuthoringParity) unless BSS070EBDXRoom.ancestors.include?(BSS102RoomAuthoringParity)
  end
rescue => e
  BSS064.log("BSS102 room parity install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSS102AmbientCamera) unless Battle::Scene.ancestors.include?(BSS102AmbientCamera)
    Battle::Scene.prepend(BSS102PositionCacheFix) unless Battle::Scene.ancestors.include?(BSS102PositionCacheFix)
  end
rescue => e
  BSS064.log("BSS102 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  if defined?(Battle::Battler)
    Battle::Battler.prepend(BSS102SOSFleeInsteadOfFaint) unless Battle::Battler.ancestors.include?(BSS102SOSFleeInsteadOfFaint)
  end
rescue => e
  BSS064.log("BSS102 SOS flee install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# BSS Clean Flee Message Suppression
# Moves flee suppression out of DBK and into BSS Runtime.
# When a flee is triggered narratively (wildFlee: true, midbattle scripts, or
# silent helper retirement), msg == false or "" suppresses the generic text.
#-------------------------------------------------------------------------------
module BSSFleeMessageControl
  def pbBattlerFlee(battler, msg = nil)
    # Allow BSS064SmoothBossHelperFleeScene658 to handle smooth boss helper flee animations
    marked = @battle && @battle.instance_variable_get(:@bss658_smooth_helper_flee_target)
    return super(battler, msg) if marked && battler && marked.equal?(battler)
    if msg == false || msg == ""
      @briefMessage = false if instance_variable_defined?(:@briefMessage)
      anim_cls = (defined?(Battle::Scene::Animation::BattlerFlee) rescue nil)
      box_cls  = (defined?(Battle::Scene::Animation::DataBoxDisappear) rescue nil)
      fleeAnim = anim_cls ? anim_cls.new(@sprites, @viewport, battler.index, @battle) : nil rescue nil
      dataBoxAnim = box_cls ? box_cls.new(@sprites, @viewport, battler.index) : nil rescue nil
      pbAnimateSubstitute(battler, :break) if respond_to?(:pbAnimateSubstitute)
      if fleeAnim && dataBoxAnim
        loop do
          begin; fleeAnim.update; rescue; end
          begin; dataBoxAnim.update; rescue; end
          pbUpdate rescue nil
          break if (fleeAnim.animDone? rescue true) && (dataBoxAnim.animDone? rescue true)
        end
        begin; fleeAnim.dispose; rescue; end
        begin; dataBoxAnim.dispose; rescue; end
      end
      return
    end
    super(battler, msg)
  end
end

module BSSBattlerWildFleeControl
  def wild_flee(fleeMsg = nil)
    # If called with boolean true (e.g. from wildFlee: true in DBK midbattle triggers),
    # convert to false to suppress the duplicate "¡{1} huyó!" after scripted text.
    fleeMsg = false if fleeMsg == true
    super(fleeMsg)
  end
end

begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSSFleeMessageControl) unless Battle::Scene.ancestors.include?(BSSFleeMessageControl)
  end
rescue => e
  BSS064.log("BSS flee message scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

begin
  if defined?(Battle::Battler)
    Battle::Battler.prepend(BSSBattlerWildFleeControl) unless Battle::Battler.ancestors.include?(BSSBattlerWildFleeControl)
  end
rescue => e
  BSS064.log("BSS battler wild flee install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# Re-register DBK's wildFlee trigger handler cleanly so it passes false if params == true
begin
  if defined?(MidbattleHandlers)
    MidbattleHandlers.add(:midbattle_triggers, "wildFlee",
      proc { |battle, idxBattler, idxTarget, params|
        battler = battle.battlers[idxBattler]
        next if battle.decided? || !battler || !battler.wild?
        PBDebug.log("     'wildFlee': forcing the wild #{battler.name} (#{battler.index}) to flee")
        battle.scene.pbForceEndSpeech if battle.scene && battle.scene.respond_to?(:pbForceEndSpeech)
        flee_msg = (params == true ? false : (params.is_a?(String) ? params : nil))
        battler.wild_flee(flee_msg)
      }
    )
  end
rescue => e
  BSS064.log("BSS midbattle wildFlee override warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# BSS DBK Bridge: AI Skill & Boss Difficulty Extension
# Migrated from Deluxe Battle Kit into BSS Runtime.
#-------------------------------------------------------------------------------
class Battle
  attr_accessor :opponent_ai_skill unless method_defined?(:opponent_ai_skill)
  attr_writer :canLose unless method_defined?(:canLose=)

  def canLose
    return @canLose if defined?(@canLose) && !@canLose.nil?
    return @rules[:continue_if_lose] if @rules.is_a?(Hash) && @rules.key?(:continue_if_lose)
    false
  end unless method_defined?(:canLose)

  alias canLose? canLose unless method_defined?(:canLose?)
end

module BSSAITrainerSkillExtension
  def set_up_skill
    super
    if @side == 1
      # 1. Battle rule or explicit battle property
      if @ai.battle.respond_to?(:opponent_ai_skill) && !@ai.battle.opponent_ai_skill.nil?
        @skill = @ai.battle.opponent_ai_skill.to_i
      # 2. BSS Boss configuration (Trainer or Wild boss)
      elsif @ai.battle.respond_to?(:bss_boss_config) && @ai.battle.bss_boss_config.is_a?(Hash) &&
            (@ai.battle.bss_boss_config.key?("aiSkill") || @ai.battle.bss_boss_config.key?("skill"))
        @skill = (@ai.battle.bss_boss_config["aiSkill"] || @ai.battle.bss_boss_config["skill"]).to_i
      # 3. Wild Boss battle
      elsif !@trainer
        wild_battler = @ai.battle.battlers[@side] rescue nil
        is_boss = (wild_battler.respond_to?(:hasBossImmunity?) && wild_battler.hasBossImmunity?) ||
                  (wild_battler && wild_battler.pokemon && wild_battler.pokemon.respond_to?(:hp_level) && wild_battler.pokemon.hp_level > 0) ||
                  (@ai.battle.respond_to?(:bss_boss_config) && @ai.battle.bss_boss_config.is_a?(Hash) && @ai.battle.bss_boss_config["enabled"] == true)
        if is_boss
          @skill = 100
        elsif @skill == 0 && !@ai.battle.wildBattleMode.nil?
          @skill = 32
        end
      end
    end
  end
end

begin
  if defined?(Battle::AI::AITrainer)
    Battle::AI::AITrainer.prepend(BSSAITrainerSkillExtension) unless Battle::AI::AITrainer.ancestors.include?(BSSAITrainerSkillExtension)
  end
rescue => e
  BSS064.log("BSS AI skill install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# BSS DBK Bridge: Battle Rules Extension (aiskill, opponentskill)
#-------------------------------------------------------------------------------
module BSSBattleRulesAI
  def add_battle_rule(rule, var = nil)
    case rule.to_s.downcase
    when "aiskill", "opponentskill"
      rules = self.battle_rules
      rules["aiSkill"] = var.to_i
      return
    end
    super(rule, var)
  end
end

module BSSPrepareBattleAI
  def prepare_battle(battle)
    ret = super(battle)
    if defined?($game_temp) && $game_temp.respond_to?(:battle_rules)
      battleRules = $game_temp.battle_rules
      battle.opponent_ai_skill = battleRules["aiSkill"] if battle.respond_to?(:opponent_ai_skill=) && !battleRules["aiSkill"].nil?
    end
    ret
  end
end

begin
  if defined?(Game_Temp)
    Game_Temp.prepend(BSSBattleRulesAI) unless Game_Temp.ancestors.include?(BSSBattleRulesAI)
  end
rescue => e
  BSS064.log("BSS battle rules AI install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

begin
  if defined?(BattleCreationHelperMethods)
    BattleCreationHelperMethods.prepend(BSSPrepareBattleAI) unless BattleCreationHelperMethods.ancestors.include?(BSSPrepareBattleAI)
  end
rescue => e
  BSS064.log("BSS prepare battle AI install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# BSS DBK Bridge: Midbattle Script & Symbol Resolution Fix
# Ensures Midbattle symbol scripts correctly load their Hash from MidbattleScripts,
# and fixes the HP thresholds (75%, 50%, 25%) in pbFinalizeMoveTriggers.
#-------------------------------------------------------------------------------
module BSSMidbattleSymbolResolver
  def pbDeluxeTriggers(idxBattler, idxTarget, *triggers)
    if @midbattleScript.is_a?(Symbol) && defined?(MidbattleScripts) && hasConst?(MidbattleScripts, @midbattleScript)
      @midbattleScript = getConst(MidbattleScripts, @midbattleScript).clone
    end
    super(idxBattler, idxTarget, *triggers)
  end
end

begin
  if defined?(Battle)
    Battle.prepend(BSSMidbattleSymbolResolver) unless Battle.ancestors.include?(BSSMidbattleSymbolResolver)
  end
rescue => e
  BSS064.log("BSS midbattle symbol resolver install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

module BSSMoveMidbattleTriggersFix
  def pbFinalizeMoveTriggers(user, target)
    if !user.fainted?
      if user.hp <= (user.totalhp * 3 / 4)
        lowHP = user.hp <= user.totalhp / 4
        halfHP = user.hp <= user.totalhp / 2
        is_last = (@battle.pbParty(user.index).length > @battle.pbSideSize(user.index)) ?
                  (@battle.pbAbleNonActiveCount(user.index) == 0) : true
        prefix = is_last ? "LastUser" : "User"
        @battler_triggers[:user].push("#{prefix}HP75", user.species, *user.pokemon.types)
        @battler_triggers[:user].push("#{prefix}HPHalf", user.species, *user.pokemon.types) if halfHP
        @battler_triggers[:user].push("#{prefix}HPLow", user.species, *user.pokemon.types) if lowHP
        if !is_last && @battle.pbParty(user.index).length <= @battle.pbSideSize(user.index)
          @battler_triggers[:user].push("UserHP75", user.species, *user.pokemon.types)
          @battler_triggers[:user].push("UserHPHalf", user.species, *user.pokemon.types) if halfHP
          @battler_triggers[:user].push("UserHPLow", user.species, *user.pokemon.types) if lowHP
        end
      end
    end
    if !target.fainted? && user.opposes?(target.index)
      if target.hp <= (target.totalhp * 3 / 4)
        lowHP = target.hp <= target.totalhp / 4
        halfHP = target.hp <= target.totalhp / 2
        is_last = (@battle.pbParty(target.index).length > @battle.pbSideSize(target.index)) ?
                  (@battle.pbAbleNonActiveCount(target.index) == 0) : true
        prefix = is_last ? "LastTarget" : "Target"
        @battler_triggers[:targ].push("#{prefix}HP75", target.species, *target.pokemon.types)
        @battler_triggers[:targ].push("#{prefix}HPHalf", target.species, *target.pokemon.types) if halfHP
        @battler_triggers[:targ].push("#{prefix}HPLow", target.species, *target.pokemon.types) if lowHP
        if !is_last && @battle.pbParty(target.index).length <= @battle.pbSideSize(target.index)
          @battler_triggers[:targ].push("TargetHP75", target.species, *target.pokemon.types)
          @battler_triggers[:targ].push("TargetHPHalf", target.species, *target.pokemon.types) if halfHP
          @battler_triggers[:targ].push("TargetHPLow", target.species, *target.pokemon.types) if lowHP
        end
      end
    end
    @battler_triggers.each do |battler, triggers|
      next if triggers.empty?
      case battler
      when :user then @battle.pbDeluxeTriggers(user, target.index, *triggers)
      when :targ then @battle.pbDeluxeTriggers(target, user.index, *triggers)
      end
    end
    @battler_triggers[:user].clear
    @battler_triggers[:targ].clear
  end
end

begin
  if defined?(Battle::Move)
    Battle::Move.prepend(BSSMoveMidbattleTriggersFix) unless Battle::Move.ancestors.include?(BSSMoveMidbattleTriggersFix)
  end
rescue => e
  BSS064.log("BSS move midbattle triggers fix install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# BSS DBK Bridge: Substitute Doll Scene Safety Fix
# Fixes undefined method `index' for nil:NilClass in pbAnimateSubstitute
# without modifying Deluxe Battle Kit / Animated Pokémon System scripts.
#-------------------------------------------------------------------------------
module BSSSubstituteDollSceneExtension
  def pbUpdateSubstituteSprite(idxBattler, mode)
    return if !@battle
    battler = (idxBattler.respond_to?("index")) ? idxBattler : (@battle.battlers ? @battle.battlers[idxBattler] : nil)
    return if !battler
    pkmnSprite = battler.respond_to?(:battlerSprite) ? battler.battlerSprite : nil
    return if !pkmnSprite
    if [:create, :show].include?(mode)
      return if !battler.respond_to?(:effects) || battler.effects[PBEffects::Substitute] <= 0
      pkmnSprite.substitute = true if pkmnSprite.respond_to?(:substitute=)
    else
      pkmnSprite.substitute = false if pkmnSprite.respond_to?(:substitute=)
    end
  end

  def pbAnimateSubstitute(idxBattler, mode, delay = false)
    return if respond_to?(:pbInSafari?) && pbInSafari?
    return if idxBattler.nil? || !@battle || (@battle.decision && @battle.decision > 0)
    battler = (idxBattler.respond_to?("index")) ? idxBattler : (@battle.battlers ? @battle.battlers[idxBattler] : nil)
    return if !battler
    # If Substitute is not active and not breaking, do not animate
    return if !battler.respond_to?(:effects) || (battler.effects[PBEffects::Substitute] == 0 && mode != :broken)
    return if battler.respond_to?(:semiInvulnerable?) && battler.semiInvulnerable?
    opposing = battler.pbDirectOpposing rescue nil
    return if opposing && @battle.respond_to?(:pbAllFainted?) && @battle.pbAllFainted?(opposing.index)
    pbPauseScene if delay && respond_to?(:pbPauseScene)
    substituteAnim = nil
    if defined?(Animation::SubstituteAppear)
      case mode
      when :create then substituteAnim = Animation::SubstituteAppear.new(@sprites, @viewport, battler)
      when :show   then substituteAnim = Animation::SubstituteSwapIn.new(@sprites, @viewport, battler)
      when :hide   then substituteAnim = Animation::SubstituteSwapOut.new(@sprites, @viewport, battler)
      when :broken then substituteAnim = Animation::SubstituteSwapOut.new(@sprites, @viewport, battler, true)
      end
    end
    if substituteAnim
      loop do
        substituteAnim.update
        pbUpdate if respond_to?(:pbUpdate)
        break if substituteAnim.animDone?
      end
      substituteAnim.dispose
    end
    pbUpdateSubstituteSprite(battler, mode)
    if @sprites && battler.respond_to?(:index) && @sprites["pokemon_#{battler.index}"]
      @sprites["pokemon_#{battler.index}"].visible = true
    end
    pbChangePokemon(battler.index, battler.visiblePokemon) if respond_to?(:pbChangePokemon) && battler.respond_to?(:visiblePokemon)
  end
end

begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSSSubstituteDollSceneExtension) unless Battle::Scene.ancestors.include?(BSSSubstituteDollSceneExtension)
  end
rescue => e
  BSS064.log("BSS substitute doll scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#===============================================================================
# BSS Core Battle & Environment Safety Extensions
# Migrated from Data/Scripts to keep core Essentials 100% untouched.
#===============================================================================

# Ensure Ruby 3.3 x64-mingw-ucrt library path is available
begin
  ucrt_lib = File.join(Dir.pwd, "Data", "Ruby Library 3.3.0", "x64-mingw-ucrt")
  $:.push(ucrt_lib) if File.directory?(ucrt_lib) && !$:.include?(ucrt_lib)
rescue => e
  # ignore
end

module BSSCoreBattleSafetyExtensions
  # For the given side of the field (0=player's, 1=opponent's), returns an array
  # containing the number of able Pokémon in each team, safe against nil parties.
  def pbAbleTeamCounts(side)
    party = (side == 0 ? @party1 : @party2) || []
    partyStarts = (side == 0 ? @party1starts : @party2starts) || [0]
    ret = []
    idxTeam = -1
    nextStart = 0
    party.each_with_index do |pkmn, i|
      if i >= nextStart
        idxTeam += 1
        nextStart = (idxTeam < partyStarts.length - 1) ? partyStarts[idxTeam + 1] : party.length
      end
      next if !pkmn || !pkmn.able?
      ret[idxTeam] = 0 if !ret[idxTeam]
      ret[idxTeam] += 1
    end
    return ret
  end

  def pbEnsureParticipants
    if trainerBattle?
      @player ||= []
      @opponent ||= []
    end
    super
  end
end

begin
  if defined?(Battle)
    Battle.prepend(BSSCoreBattleSafetyExtensions) unless Battle.ancestors.include?(BSSCoreBattleSafetyExtensions)
  end
rescue => e
  BSS064.log("BSS core battle safety install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end



