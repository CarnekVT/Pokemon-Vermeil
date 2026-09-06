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
    out.each do |raw_key,row|
      next unless raw_key.to_s =~ /^img\d+/i && row.is_a?(Hash)
      rr=BSS098.hash_get(row,:runtimeRaster)
      if rr.is_a?(Hash)
        path=BSS098.hash_get(rr,:bitmap).to_s.strip
        if BSS102.file_bitmap_exists?(path)
          row[:bitmap]=path
          row[:ox]=BSS102.num(BSS098.hash_get(rr,:ox), BSS098.hash_get(row,:ox) || 0)
          row[:oy]=BSS102.num(BSS098.hash_get(rr,:oy), BSS098.hash_get(row,:oy) || 0)
          [:warp,"warp",:blurAreas,"blurAreas",:blur,"blur",:crop,"crop",:runtimeRaster,"runtimeRaster"].each{|k|row.delete(k)}
          row[:bss_rasterized]=true
        else
          row.delete(:runtimeRaster); row.delete("runtimeRaster")
        end
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
        color=BSS102.color_from_hex(BSS102.hget(row,:tintColor),BSS102.num(BSS102.hget(row,:tintAlpha),0).round)
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
          color=BSS102.color_from_hex(BSS102.hget(row,:tintColor),BSS102.num(BSS102.hget(row,:tintAlpha),0).round)
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
      @vector.inc=0.006 if @vector.respond_to?(:inc=)
      @vector.set(main) if @vector.respond_to?(:set)
      @bss102_ambient_due=120
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
    return false unless @vector && BSS102.command_overview?(self)
    cfg=BSS102.camera_config(self); main=bss102_main_vector
    @bss102_command_saved=@vector.get.clone rescue main.clone
    out=[[BSS102.num(cfg["commandOverviewZoomOut"] || cfg[:commandOverviewZoomOut],12),0].max,30].min/100.0
    lift=[[BSS102.num(cfg["commandOverviewLift"] || cfg[:commandOverviewLift],22),0].max,80].min
    frames=[[BSS102.num(cfg["commandOverviewFrames"] || cfg[:commandOverviewFrames],24).round,8].max,80].min
    target=main.clone
    target[1]-=lift
    target[3]=main[3]*(1.0-out)
    @vector.inc=[[1.0/frames.to_f,0.006].max,0.08].min if @vector.respond_to?(:inc=)
    @vector.set(target) if @vector.respond_to?(:set)
    @bss102_command_overview=true
    true
  rescue
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
    return false if !bss070_ebdx_ensure_core
    now=(Graphics.frame_count rescue 0).to_i
    return true if @bss102_last_world_tick==now
    @bss102_last_world_tick=now
    bss070_ebdx_hide_native_backdrops if respond_to?(:bss070_ebdx_hide_native_backdrops)
    static=BSS102.static_camera?(self)
    external=@bss070_ebdx_bas_frame || @bss070_ebdx_suspend_depth.to_i>0 || @bss083_animation_projection || @bss084_native_move_active || @bss087_native_move_active
    if advance_camera && @vector && !static
      @vector.update
      unless external || @bss102_command_overview
        @bss102_ambient_due=@bss102_ambient_due.to_i-1
        bss102_next_ambient_target if @bss102_ambient_due<=0
      end
    end
    @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
    bss070_ebdx_apply_world_alignment if align && respond_to?(:bss070_ebdx_apply_world_alignment)
    bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
    true
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

  def bss070_ebdx_camera_enter(*args); nil; end
  def bss070_ebdx_camera_leave(*args); nil; end
  def bss087_request_camera_context(*args); false; end
  def bss084_transition_context(*args); false; end
  def bss096_camera_to_main(*args); false; end

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
    battle=@battle rescue nil
    if battle && !battle.instance_variable_get(:@bss102_helper_flee_in_progress) && battle.respond_to?(:bss_find_boss_battler_any) && battle.respond_to?(:bss656_sos_on_boss_defeat)
      boss=(battle.bss_find_boss_battler_any rescue nil)
      if boss && !boss.equal?(self) && !(opposes?(boss.index) rescue true) && (boss.hp rescue 1).to_i<=0 && (battle.bss656_sos_on_boss_defeat rescue "faint").to_s=="flee" && battle.respond_to?(:bss656_flee_boss_helper)
        begin
          battle.instance_variable_set(:@bss102_helper_flee_in_progress,true)
          ok=battle.bss656_flee_boss_helper(self)
          @fainted=true if ok
          return true if ok
        ensure
          battle.instance_variable_set(:@bss102_helper_flee_in_progress,false)
        end
      end
    end
    super
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
