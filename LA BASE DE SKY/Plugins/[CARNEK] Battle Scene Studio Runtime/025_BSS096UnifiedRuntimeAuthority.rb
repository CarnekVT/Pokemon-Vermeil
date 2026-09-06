#===============================================================================
# Battle Scene Studio v0.8.17
# Unified runtime authority / parity & performance pass.
#
# This file intentionally sits last. It removes the remaining places where old
# compatibility patches could fight one another: battler-vs-camera ownership,
# sendout endpoints, SOS formation, Wild Intro, capture tinting and warp cost.
#===============================================================================
module BSS096
  VERSION = "0.8.17"
  module_function

  def num(v, fallback=0.0)
    return fallback.to_f if v.nil?
    return v.to_f if v.is_a?(Numeric)
    s=v.to_s.strip
    return fallback.to_f if s.empty?
    return s.to_f if s =~ /\A[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?\z/
    fallback.to_f
  rescue
    fallback.to_f
  end

  def clamp(v,a,b)
    [[num(v,a),a.to_f].max,b.to_f].min
  end

  def ebdx?(scene)
    scene && scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?
  rescue
    false
  end

  # Always ask Essentials/DBK for its native screen position with BSS' projected
  # pbBattlerPosition context disabled. This is the stable screen-space anchor.
  def native_battler_base(scene, index, side=nil)
    idx=index.to_i
    size=(side || (scene.instance_variable_get(:@battle).pbSideSize(idx) rescue 1)).to_i
    size=1 if size<1
    pos=nil
    if defined?(BSS082) && BSS082.respond_to?(:without_position_context)
      pos=BSS082.without_position_context { Battle::Scene.pbBattlerPosition(idx,size) }
    else
      old=(BSS070EBDXCore.position_scene rescue nil) if defined?(BSS070EBDXCore)
      begin
        BSS070EBDXCore.position_scene=nil if defined?(BSS070EBDXCore)
        pos=Battle::Scene.pbBattlerPosition(idx,size)
      ensure
        BSS070EBDXCore.position_scene=old if defined?(BSS070EBDXCore)
      end
    end
    return [pos[0].to_f,pos[1].to_f] if pos && pos.length>=2
    p=BSS070EBDXCore.fallback_screen_position(idx,scene.instance_variable_get(:@battle)) rescue [160,360,50]
    [p[0].to_f,p[1].to_f]
  rescue
    side=index.to_i.odd? ? 1 : 0
    side==0 ? [160.0,360.0] : [480.0,190.0]
  end

  def battle_boss?(battle)
    return true if battle && battle.respond_to?(:bss_boss_enabled?) && battle.bss_boss_enabled? == true
    bp=(battle.bss_blueprint rescue nil)
    return false unless bp.is_a?(Hash)
    setup=bp["setup"] || bp[:setup]
    kind=setup.is_a?(Hash) ? (setup["kind"] || setup[:kind]).to_s.downcase : ""
    ["boss","totem","raid"].include?(kind)
  rescue
    false
  end
end

#-------------------------------------------------------------------------------
# Environment priority.
# Boss/Totem battles inherit the map's EBDX metadata unless that Blueprint chose
# an actual scene. The editor's temporary global preview flag no longer masks
# map metadata inside Boss battles.
#-------------------------------------------------------------------------------
if defined?(BSS070EBDXCore)
  module BSS070EBDXCore
    class << self
      unless method_defined?(:bss096_environment_for_base)
        alias bss096_environment_for_base environment_for
      end
      def environment_for(scene)
        battle=scene.instance_variable_get(:@battle) rescue nil
        env=(battle && battle.respond_to?(:bss_environment_config)) ? (battle.bss_environment_config rescue {}) : {}
        env={} unless env.is_a?(Hash)
        selected=explicit_name(env).to_s.strip
        selected="Auto" if selected.empty? || selected.downcase=="inherit"
        mapped=map_backdrop
        # A Boss' default/inherit value must not silently turn into the global
        # Composer test scene. Per-map metadata is the expected source.
        if BSS096.battle_boss?(battle) && mapped && ["auto","inherit"].include?(selected.downcase)
          canonical=BUILTIN.keys.find{|x| x.to_s.downcase==mapped.to_s.downcase} || mapped
          data=custom_environment(canonical) || deep_copy(BUILTIN[canonical] || BUILTIN["Field"])
          custom=env["backgroundGraphic"].to_s.strip.tr("\\","/")
          data["backdrop"]=custom if !custom.empty? && custom =~ /\AGraphics\/.+\.(?:png|gif|jpg|jpeg|webp|bmp)\z/i
          return data
        end
        bss096_environment_for_base(scene)
      rescue => e
        BSS064.log("BSS096 environment warning: #{e.class}: #{e.message}") if defined?(BSS064)
        bss096_environment_for_base(scene)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Optimised warp runtime.
# v0.8.15 could create hundreds of tiny Sprite+Bitmap objects per warped layer
# and recompute them more than once per frame. The visual control grid remains
# unchanged; runtime tessellation is capped to 64 tiles at normal/high quality
# and 144 only at maximum quality, with same-frame/unchanged-transform caching.
#-------------------------------------------------------------------------------
module BSS096WarpPerformance
  def bss093_build_warp_layer!(raw_key)
    key=raw_key.to_s
    data=@data[raw_key] || @data[key]
    cfg=bss093_warp_config(data)
    return if !cfg
    root=@sprites[key] || @sprites[raw_key]
    return if !root || (root.disposed? rescue true) || !root.bitmap || (root.bitmap.disposed? rescue true)
    @bss093_warp_layers||={}
    bss093_dispose_warp_layer!(key)

    q=cfg[:quality].to_i
    subdiv = q>=6 ? 3 : (q>=3 ? 2 : 1)
    seg_x=[(cfg[:cols]-1)*subdiv,1].max
    seg_y=[(cfg[:rows]-1)*subdiv,1].max
    max_tiles=64
    while seg_x*seg_y>max_tiles && subdiv>1
      subdiv-=1
      seg_x=[(cfg[:cols]-1)*subdiv,1].max
      seg_y=[(cfg[:rows]-1)*subdiv,1].max
    end
    src=root.bitmap
    tiles=[]
    seg_y.times do |iy|
      sy0=(iy*src.height.to_f/seg_y).floor
      sy1=((iy+1)*src.height.to_f/seg_y).ceil
      sh=[sy1-sy0,1].max
      seg_x.times do |ix|
        sx0=(ix*src.width.to_f/seg_x).floor
        sx1=((ix+1)*src.width.to_f/seg_x).ceil
        sw=[sx1-sx0,1].max
        bmp=Bitmap.new(sw,sh)
        bmp.blt(0,0,src,Rect.new(sx0,sy0,sw,sh))
        sp=BSS070EBDXSprite.new(@viewport)
        sp.bitmap=bmp; sp.ox=sw/2.0; sp.oy=sh/2.0
        sp.z=root.z; sp.opacity=root.opacity; sp.visible=false
        tiles << {:sprite=>sp,:sw=>sw.to_f,:sh=>sh.to_f,
                  :u0=>ix.to_f/seg_x,:u1=>(ix+1).to_f/seg_x,
                  :v0=>iy.to_f/seg_y,:v1=>(iy+1).to_f/seg_y}
      end
    end
    root.visible=false
    @bss093_warp_layers[key]={:root=>root,:data=>data,:config=>cfg,:tiles=>tiles,:fingerprint=>nil,:last_frame=>-1}
  end

  def bss096_warp_fingerprint(root)
    bg=@sprites && @sprites["bg"]
    tone=root.tone rescue nil
    color=root.color rescue nil
    [root.x.to_f.round(3),root.y.to_f.round(3),root.z.to_i,
     root.zoom_x.to_f.round(4),root.zoom_y.to_f.round(4),root.angle.to_f.round(3),
     root.opacity.to_i,(root.visible rescue false),
     (bg ? bg.x.to_f.round(3) : 0),(bg ? bg.y.to_f.round(3) : 0),
     (bg ? bg.zoom_x.to_f.round(4) : 1),(bg ? bg.zoom_y.to_f.round(4) : 1),
     (tone ? [tone.red.to_i,tone.green.to_i,tone.blue.to_i,tone.gray.to_i] : nil),
     (color ? [color.red.to_i,color.green.to_i,color.blue.to_i,color.alpha.to_i] : nil)]
  rescue
    nil
  end

  def bss093_update_warp_tiles!
    return if !@bss093_warp_layers.is_a?(Hash) || @bss093_warp_layers.empty?
    frame=(Graphics.frame_count rescue 0).to_i
    visible_state=@bss093_visible_state.nil? ? true : @bss093_visible_state
    @bss093_warp_layers.each do |_key,row|
      root=row[:root]; data=row[:data]; cfg=row[:config]
      next if !root || (root.disposed? rescue true) || !data || !cfg
      root.visible=false if root.respond_to?(:visible=)
      fp=bss096_warp_fingerprint(root)
      # position() is reached through several historical authorities. Never do
      # the expensive projection twice on the same frame/transform.
      if row[:last_frame].to_i==frame && row[:fingerprint]==fp
        next
      end
      if row[:fingerprint]==fp
        row[:last_frame]=frame
        next
      end
      row[:fingerprint]=fp; row[:last_frame]=frame
      row[:tiles].each do |entry|
        sp=entry[:sprite]; next if !sp || (sp.disposed? rescue true)
        u0=entry[:u0];u1=entry[:u1];v0=entry[:v0];v1=entry[:v1]
        uc=(u0+u1)*0.5; vc=(v0+v1)*0.5
        pc=bss093_project_point(root,data,cfg,uc,vc)
        pl=bss093_project_point(root,data,cfg,u0,vc); pr=bss093_project_point(root,data,cfg,u1,vc)
        pt=bss093_project_point(root,data,cfg,uc,v0); pb=bss093_project_point(root,data,cfg,uc,v1)
        hx=pr[0]-pl[0]; hy=pr[1]-pl[1]
        vx=pb[0]-pt[0]; vy=pb[1]-pt[1]
        hlen=Math.sqrt(hx*hx+hy*hy)
        angle=Math.atan2(hy,hx)
        nx=-Math.sin(angle); ny=Math.cos(angle)
        vproj=(vx*nx+vy*ny).abs
        vlen=Math.sqrt(vx*vx+vy*vy); vproj=vlen if vproj<0.01
        sp.x=pc[0]; sp.y=pc[1]; sp.angle=angle*180.0/Math::PI
        sp.zoom_x=[hlen/[entry[:sw],0.001].max*1.025,0.001].max
        sp.zoom_y=[vproj/[entry[:sh],0.001].max*1.025,0.001].max
        bss093_copy_sprite_visuals(root,sp)
        sp.visible=visible_state
      end
    end
  rescue => e
    BSS064.log("BSS096 warp update warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end
end

#-------------------------------------------------------------------------------
# Camera is a WORLD camera. Battlers remain on their contextual Essentials/DBK
# screen anchors unless an animation (BAS/native move/SOS/sendout) owns them.
#-------------------------------------------------------------------------------
module BSS096SceneCameraAndBattlers
  def bss096_native_position(index, side=nil)
    idx=index.to_i
    sp=bss070_ebdx_native_sprite(idx) rescue nil
    size=(side || (@battle.pbSideSize(idx) rescue 1)).to_i
    size=1 if size<1
    @bss096_native_position_cache ||= {}
    key=[idx,size,(sp ? sp.object_id : 0),(sp && sp.respond_to?(:bitmap) && sp.bitmap ? sp.bitmap.object_id : 0)]
    cached=@bss096_native_position_cache[key]
    return cached.clone if cached
    vals=nil
    if sp && !(sp.disposed? rescue true) && (bss070_ebdx_sprite_loaded?(sp) rescue true) && sp.respond_to?(:pbSetPosition)
      old=[sp.x,sp.y,sp.z,(sp.zoom_x rescue nil),(sp.zoom_y rescue nil),(sp.respond_to?(:sideSize) ? sp.sideSize : nil)]
      begin
        sp.sideSize=size if sp.respond_to?(:sideSize=)
        if defined?(BSS082) && BSS082.respond_to?(:without_position_context)
          BSS082.without_position_context { sp.pbSetPosition }
        else
          sp.pbSetPosition
        end
        vals=[sp.x.to_f,sp.y.to_f,sp.z.to_i,(sp.zoom_x rescue 1.0).to_f,(sp.zoom_y rescue 1.0).to_f]
      ensure
        sp.x=old[0] if sp.respond_to?(:x=); sp.y=old[1] if sp.respond_to?(:y=); sp.z=old[2] if sp.respond_to?(:z=)
        sp.zoom_x=old[3] if !old[3].nil? && sp.respond_to?(:zoom_x=); sp.zoom_y=old[4] if !old[4].nil? && sp.respond_to?(:zoom_y=)
        sp.sideSize=old[5] if !old[5].nil? && sp.respond_to?(:sideSize=)
      end
    end
    unless vals
      q=BSS096.native_battler_base(self,idx,size)
      vals=[q[0],q[1],50,(sp ? (sp.zoom_x rescue 1.0) : 1.0).to_f,(sp ? (sp.zoom_y rescue 1.0) : 1.0).to_f]
    end
    @bss096_native_position_cache.clear if @bss096_native_position_cache.length>20
    @bss096_native_position_cache[key]=vals.clone
    vals
  rescue
    q=BSS096.native_battler_base(self,index,side)
    [q[0],q[1],50,1.0,1.0]
  end

  def bss096_native_shadow_position(index, side=nil)
    idx=index.to_i
    sh=bss070_ebdx_native_shadow_sprite(idx) rescue nil
    size=(side || (@battle.pbSideSize(idx) rescue 1)).to_i
    size=1 if size<1
    @bss096_native_shadow_cache ||= {}
    key=[idx,size,(sh ? sh.object_id : 0),(sh && sh.respond_to?(:bitmap) && sh.bitmap ? sh.bitmap.object_id : 0)]
    cached=@bss096_native_shadow_cache[key]
    return cached.clone if cached
    vals=nil
    if sh && !(sh.disposed? rescue true) && sh.respond_to?(:pbSetPosition)
      old=[sh.x,sh.y,sh.z,(sh.zoom_x rescue nil),(sh.zoom_y rescue nil),(sh.respond_to?(:sideSize) ? sh.sideSize : nil)]
      begin
        sh.sideSize=size if sh.respond_to?(:sideSize=)
        if defined?(BSS082) && BSS082.respond_to?(:without_position_context)
          BSS082.without_position_context { sh.pbSetPosition }
        else
          sh.pbSetPosition
        end
        vals=[sh.x.to_f,sh.y.to_f,sh.z.to_i,(sh.zoom_x rescue 1.0).to_f,(sh.zoom_y rescue 0.25).to_f]
      ensure
        sh.x=old[0] if sh.respond_to?(:x=); sh.y=old[1] if sh.respond_to?(:y=); sh.z=old[2] if sh.respond_to?(:z=)
        sh.zoom_x=old[3] if !old[3].nil? && sh.respond_to?(:zoom_x=); sh.zoom_y=old[4] if !old[4].nil? && sh.respond_to?(:zoom_y=)
        sh.sideSize=old[5] if !old[5].nil? && sh.respond_to?(:sideSize=)
      end
    end
    unless vals
      q=BSS096.native_battler_base(self,idx,size); vals=[q[0],q[1],3,1.0,0.25]
    end
    @bss096_native_shadow_cache.clear if @bss096_native_shadow_cache.length>20
    @bss096_native_shadow_cache[key]=vals.clone
    vals
  rescue
    q=BSS096.native_battler_base(self,index,side)
    [q[0],q[1],3,1.0,0.25]
  end

  def bss096_clear_native_position_cache(index=nil)
    if index.nil?
      @bss096_native_position_cache={}; @bss096_native_shadow_cache={}
    else
      i=index.to_i
      (@bss096_native_position_cache||={}).delete_if{|k,_| k[0].to_i==i}
      (@bss096_native_shadow_cache||={}).delete_if{|k,_| k[0].to_i==i}
    end
    true
  rescue
    true
  end

  # Older EBDX bridges projected pbBattlerPosition during sendout/SOS. Since
  # battlers are screen-space in v0.8.17, those lifecycles must use the native
  # Essentials/DBK coordinate system from beginning to end.
  def bss070_ebdx_with_position_context(*args,&block)
    if @bss096_native_formation_depth.to_i>0
      return yield
    end
    super
  end

  def pbSendOutBattlers(*args,&block)
    @bss096_native_formation_depth=@bss096_native_formation_depth.to_i+1
    bss096_camera_to_main(8) if BSS096.ebdx?(self)
    super
  ensure
    @bss096_native_formation_depth=[@bss096_native_formation_depth.to_i-1,0].max rescue 0
    bss096_clear_native_position_cache
    begin
      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment if @bss096_native_formation_depth.to_i<=0
    rescue
    end
  end

  def bss070_ebdx_apply_world_alignment
    return if @bss070_ebdx_suspend_depth.to_i>0 || @bss070_ebdx_bas_frame
    return if @bss096_battler_anim_depth.to_i>0 || @bss087_native_move_active || @bss084_native_move_active
    return if @bss087_end_battle_lock
    return if !@bss070_ebdx_room || !@battle || !@sprites
    bss070_ebdx_recalibrate_if_needed if respond_to?(:bss070_ebdx_recalibrate_if_needed)
    @battle.battlers.each_index do |i|
      sp=bss070_ebdx_native_sprite(i) rescue nil
      next if !sp || (sp.disposed? rescue true) || !(bss070_ebdx_sprite_loaded?(sp) rescue true)
      p=bss096_native_position(i)
      sp.x=p[0] if sp.respond_to?(:x=); sp.y=p[1] if sp.respond_to?(:y=)
      sp.zoom_x=p[3] if sp.respond_to?(:zoom_x=); sp.zoom_y=p[4] if sp.respond_to?(:zoom_y=)
      sp.z=[p[2].to_i,50+i].max if sp.respond_to?(:z=)
      sh=bss070_ebdx_native_shadow_sprite(i) rescue nil
      if sh && !(sh.disposed? rescue true) && (bss070_ebdx_sprite_loaded?(sh) rescue true)
        if @bss070_ebdx_room.respond_to?(:shadows_enabled?) && !@bss070_ebdx_room.shadows_enabled?
          sh.visible=false if sh.respond_to?(:visible=)
        else
          q=bss096_native_shadow_position(i)
          sh.x=q[0] if sh.respond_to?(:x=); sh.y=q[1] if sh.respond_to?(:y=)
          sh.zoom_x=q[3] if sh.respond_to?(:zoom_x=); sh.zoom_y=q[4] if sh.respond_to?(:zoom_y=)
          sh.z=[q[2].to_i,30+i].max if sh.respond_to?(:z=)
        end
      end
    end
  rescue => e
    BSS064.log("BSS096 battler screen authority warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss096_camera_to_main(frames=12)
    return false unless @vector && defined?(BSS070EBDXCore)
    target=BSS070EBDXCore.get_vector(:MAIN,@battle).map{|x| x.to_f}
    from=(@vector.get rescue target.clone).map{|x| x.to_f}
    @bss087_camera_tween={:key=>"neutral",:from=>from,:to=>target,:frame=>0,:frames=>[[frames.to_i,1].max,60].min}
    @bss083_camera_state=:neutral; @bss070_ebdx_camera_mode=:neutral
    true
  rescue
    false
  end

  # One focus per actual action. Repeated multihit animation calls do not kick
  # the camera from target->neutral->target on every hit.
  # Native/BAS attack animations own battler motion. During the attack the
  # world camera stays on MAIN; idle/command camera movement resumes only after
  # the action. This prevents multihit from refocusing once per hit.
  def bss083_with_move_projection(user=nil, targets=nil, camera_cut=true)
    return yield unless (bss083_camera_active? rescue false)
    outer=!@bss096_move_projection_active
    if outer
      @bss096_move_projection_active=true
      @bss087_native_move_active=true; @bss084_native_move_active=true
      @bss083_camera_freeze=@bss083_camera_freeze.to_i+1
      @bss087_camera_tween=nil
      if @vector && defined?(BSS070EBDXCore)
        main=BSS070EBDXCore.get_vector(:MAIN,@battle) rescue nil
        @vector.snap(main) if main && @vector.respond_to?(:snap)
      end
      @bss083_camera_state=:neutral; @bss070_ebdx_camera_mode=:neutral
      begin
        @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      rescue
      end
    end
    yield
  ensure
    if outer
      @bss083_camera_freeze=[@bss083_camera_freeze.to_i-1,0].max rescue 0
      @bss096_move_projection_active=false
      @bss087_native_move_active=false; @bss084_native_move_active=false
      @bss083_animation_projection=false; @bss083_animation_raw=nil
      bss096_camera_to_main(8) unless @bss070_ebdx_bas_frame
      begin
        @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
        bss070_ebdx_apply_world_alignment
      rescue
      end
    end
  end

  def pbChangePokemon(idxBattler, pkmn, *args, &block)
    ret=super
    bss096_clear_native_position_cache(idxBattler)
    if BSS096.ebdx?(self)
      sp=@sprites["pokemon_#{idxBattler}"] rescue nil
      if sp && !(sp.disposed? rescue true)
        p=bss096_native_position(idxBattler)
        # Keep the freshly-loaded sprite on the same native anchor the sendout
        # animation uses. No post-reveal EBDX snap/teleport.
        sp.x=p[0] if sp.respond_to?(:x=); sp.y=p[1] if sp.respond_to?(:y=)
      end
    end
    ret
  end

end

#-------------------------------------------------------------------------------
# Sendout ball endpoint. This is the only sendout trajectory authority now.
# Capture throws deliberately fall through untouched.
#-------------------------------------------------------------------------------
module BSS096BallHelpers
  module_function
  def endpoint(_animation, fallback_x, fallback_y)
    # The original Essentials sendout animation already calculated the opening
    # point that battlerAppear expects. Do not substitute the species sprite
    # anchor here; doing so is exactly what caused ball/reveal disagreement.
    [BSS096.clamp(fallback_x,18,Graphics.width-18),BSS096.clamp(fallback_y,22,Graphics.height-22)]
  rescue
    [fallback_x.to_f,fallback_y.to_f]
  end
end

module BSS096PlayerBallAuthority
  def createBallTrajectory(ball, delay, duration, startX, startY, midX, midY, endX, endY)
    owner=self.class.to_s
    capture_like=(owner =~ /(throw|capture|catch)/i)
    return super if capture_like || !(defined?(BSS078) && BSS078.ebdx_room?(@sprites))
    ex,ey=BSS096BallHelpers.endpoint(self,endX,endY)
    sx=BSS096.clamp(startX,18,Graphics.width-18)
    sy=BSS096.clamp(startY,22,Graphics.height-22)
    dur=[[duration.to_i,18].max,34].min
    mx=(sx+ex)*0.5
    my=BSS096.clamp([sy,ey].min-72,24,Graphics.height-24)
    ball.setVisible(delay,true) if ball.respond_to?(:setVisible)
    a=(2*sy)-(4*my)+(2*ey); b=(4*my)-(3*sy)-ey; c=sy
    (1..dur).each do |i|
      t=i.to_f/dur
      x=sx+(ex-sx)*t
      y=a*(t**2)+b*t+c
      ball.moveXY(delay+i-1,1,x,y)
    end
  end
end

module BSS096TrainerBallAuthority
  def createBallTrajectory(ball, destX, destY)
    return super unless defined?(BSS078) && BSS078.ebdx_room?(@sprites)
    ex,ey=BSS096BallHelpers.endpoint(self,destX,destY)
    dur=20
    sx=BSS096.clamp(ex+126,18,Graphics.width-18)
    sy=BSS096.clamp(ey-38,22,Graphics.height-22)
    my=BSS096.clamp([sy,ey].min-66,24,Graphics.height-24)
    ball.setVisible(0,true) if ball.respond_to?(:setVisible)
    a=(2*sy)-(4*my)+(2*ey); b=(4*my)-(3*sy)-ey; c=sy
    (1..dur).each do |i|
      t=i.to_f/dur
      x=sx+(ex-sx)*t
      y=a*(t**2)+b*t+c
      ball.moveXY(i-1,1,x,y)
    end
  end
end

#-------------------------------------------------------------------------------
# SOS: freeze the current world camera and animate existing battlers only between
# their old screen point and the new native side-size point. No projected room
# waypoint is ever used, so the caller cannot fly off and snap back.
#-------------------------------------------------------------------------------
module BSS096SOSSceneAuthority
  def bss_pbSOSJoin(*args,&block)
    vec=(@vector.get.clone rescue nil)
    @bss096_battler_anim_depth=@bss096_battler_anim_depth.to_i+1
    @bss096_native_formation_depth=@bss096_native_formation_depth.to_i+1
    @bss083_camera_freeze=@bss083_camera_freeze.to_i+1
    bss096_clear_native_position_cache if respond_to?(:bss096_clear_native_position_cache)
    ret=super
    ret
  ensure
    @bss083_camera_freeze=[@bss083_camera_freeze.to_i-1,0].max rescue 0
    @bss096_native_formation_depth=[@bss096_native_formation_depth.to_i-1,0].max rescue 0
    @bss096_battler_anim_depth=[@bss096_battler_anim_depth.to_i-1,0].max rescue 0
    begin
      @bss087_camera_tween=nil
      @vector.snap(vec) if vec && @vector && @vector.respond_to?(:snap)
      bss096_clear_native_position_cache if respond_to?(:bss096_clear_native_position_cache)
      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment
    rescue
    end
  end
end

if defined?(Battle::Scene::Animation::BSSSOSJoin)
  class Battle::Scene::Animation::BSSSOSJoin < Battle::Scene::Animation
    def bss096_probe(sprite,b,size,shadow=false)
      return nil if !sprite || (sprite.disposed? rescue true)
      if sprite.respond_to?(:pbSetPosition)
        old=[sprite.x,sprite.y,sprite.z,(sprite.zoom_x rescue nil),(sprite.zoom_y rescue nil),(sprite.respond_to?(:sideSize) ? sprite.sideSize : nil)]
        out=nil
        begin
          sprite.sideSize=size if sprite.respond_to?(:sideSize=)
          if defined?(BSS082) && BSS082.respond_to?(:without_position_context)
            BSS082.without_position_context { sprite.pbSetPosition }
          else
            sprite.pbSetPosition
          end
          out=[sprite.x.to_f,sprite.y.to_f,sprite.z.to_i]
        ensure
          sprite.x=old[0] if sprite.respond_to?(:x=); sprite.y=old[1] if sprite.respond_to?(:y=); sprite.z=old[2] if sprite.respond_to?(:z=)
          sprite.zoom_x=old[3] if !old[3].nil? && sprite.respond_to?(:zoom_x=); sprite.zoom_y=old[4] if !old[4].nil? && sprite.respond_to?(:zoom_y=)
          sprite.sideSize=old[5] if !old[5].nil? && sprite.respond_to?(:sideSize=)
        end
        return out if out
      end
      p=nil
      if defined?(BSS082) && BSS082.respond_to?(:without_position_context)
        p=BSS082.without_position_context { Battle::Scene.pbBattlerPosition(b.index,size) }
      else
        p=Battle::Scene.pbBattlerPosition(b.index,size)
      end
      [p[0].to_f,p[1].to_f,shadow ? 3 : 50]
    rescue
      nil
    end

    def createProcesses
      duration=18
      @battle.battlers.each do |b|
        next if !b || b.opposes?(@idx_sos)
        bat=@sprites["pokemon_#{b.index}"]; sha=@sprites["shadow_#{b.index}"]; box=@sprites["dataBox_#{b.index}"]
        next if !bat
        size=(bat.respond_to?(:sideSize) && bat.sideSize) ? bat.sideSize : (@battle.pbSideSize(b.index) rescue 1)
        to=bss096_probe(bat,b,size,false) || [bat.x.to_f,bat.y.to_f,(bat.z rescue 50).to_i]
        if b.index==@idx_sos
          obj=addSprite(bat,PictureOrigin::BOTTOM)
          obj.setXY(0,to[0],to[1]) if obj.respond_to?(:setXY); obj.setZ(0,to[2]) if obj.respond_to?(:setZ)
          obj.setTone(0,Tone.new(-96,-96,-96,-64)); obj.setOpacity(0,0); obj.setVisible(0,true)
          obj.moveOpacity(2,12,255); obj.moveTone(2,14,Tone.new(0,0,0,0),[bat,:pbPlayIntroAnimation])
          if sha
            st=bss096_probe(sha,b,size,true) || [sha.x.to_f,sha.y.to_f,(sha.z rescue 3).to_i]
            sh=addSprite(sha,PictureOrigin::CENTER); sh.setXY(0,st[0],st[1]) if sh.respond_to?(:setXY); sh.setZ(0,st[2]) if sh.respond_to?(:setZ)
            sh.setOpacity(0,0); sh.setVisible(2,true); sh.moveOpacity(3,11,255)
          end
          if box
            bx=addSprite(box); mode=(BSS064.databox_animation_mode rescue "slide")
            if mode=="fade"
              bx.setOpacity(0,0); bx.setVisible(4,true); bx.moveOpacity(4,12,255)
            elsif mode=="pop"
              bx.setOpacity(7,255) if bx.respond_to?(:setOpacity); bx.setVisible(7,true)
            else
              dir=b.index.even? ? 1 : -1
              bx.setOpacity(0,255) if bx.respond_to?(:setOpacity); bx.setDelta(0,dir*Graphics.width/2,0); bx.setVisible(2,true); bx.moveDelta(2,16,-dir*Graphics.width/2,0)
            end
          end
        else
          from=bat.instance_variable_get(:@bss087_sos_from_xy) rescue nil
          from=[bat.x.to_f,bat.y.to_f] unless from.is_a?(Array)
          obj=addSprite(bat,PictureOrigin::BOTTOM); obj.setXY(0,from[0],from[1]) if obj.respond_to?(:setXY); obj.setZ(0,to[2]) if obj.respond_to?(:setZ)
          obj.moveXY(0,duration,to[0],to[1])
          if sha
            sfrom=sha.instance_variable_get(:@bss087_sos_from_xy) rescue nil
            sfrom=[sha.x.to_f,sha.y.to_f] unless sfrom.is_a?(Array)
            st=bss096_probe(sha,b,size,true) || [sha.x.to_f,sha.y.to_f,(sha.z rescue 3).to_i]
            sh=addSprite(sha,PictureOrigin::CENTER); sh.setXY(0,sfrom[0],sfrom[1]) if sh.respond_to?(:setXY); sh.setZ(0,st[2]) if sh.respond_to?(:setZ)
            sh.moveXY(0,duration,st[0],st[1])
          end
          if box
            bfrom=box.instance_variable_get(:@bss087_sos_from_xy) rescue nil
            bto=box.instance_variable_get(:@bss656_reflow_to_xy) rescue nil
            if bfrom.is_a?(Array) && bto.is_a?(Array)
              bx=addSprite(box); bx.setXY(0,bfrom[0],bfrom[1]); bx.moveXY(0,duration,bto[0],bto[1])
            end
          end
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Capture backdrop treatment: one smooth overlay only. Never copy a black native
# Sprite#color/Tone into every room element. Existing accidental snapshots from
# 0.8.5 are restored immediately.
#-------------------------------------------------------------------------------
module BSS096CaptureFilterAuthority
  def bss096_restore_room_filters!
    room=@bss070_ebdx_room rescue nil
    rs=room.instance_variable_get(:@sprites) rescue nil
    return unless rs.is_a?(Hash)
    rs.each_value do |sp|
      next if !sp || (sp.disposed? rescue true)
      begin
        if sp.instance_variable_defined?(:@bss085_base_color)
          sp.color=sp.instance_variable_get(:@bss085_base_color) if sp.respond_to?(:color=)
          sp.remove_instance_variable(:@bss085_base_color) rescue nil
        end
        if sp.instance_variable_defined?(:@bss085_base_tone)
          sp.tone=sp.instance_variable_get(:@bss085_base_tone) if sp.respond_to?(:tone=)
          sp.remove_instance_variable(:@bss085_base_tone) rescue nil
        end
      rescue
      end
    end
  end

  def bss081_sync_background_filter
    bss096_restore_room_filters!
    true
  rescue
    true
  end

  def bss087_set_capture_filter(active)
    @bss087_capture_filter_active=(active==true)
    @bss085_capture_filter_active=@bss087_capture_filter_active
    @bss096_capture_filter_target=@bss087_capture_filter_active ? 64 : 0
    sp=bss087_capture_filter_overlay rescue nil
    if sp
      sp.z=44 rescue nil
      sp.visible=true if @bss096_capture_filter_target.to_i>0 || sp.opacity.to_i>0
    end
    unless active
      bss096_restore_room_filters!
      begin
        @bss070_ebdx_room.daylightTint if @bss070_ebdx_room && @bss070_ebdx_room.respond_to?(:daylightTint)
      rescue
      end
    end
    true
  rescue
    false
  end

  def bss096_tick_capture_filter
    sp=bss087_capture_filter_overlay rescue nil
    return unless sp
    target=@bss096_capture_filter_target.to_i
    cur=sp.opacity.to_i
    step=8
    cur=[cur+step,target].min if cur<target
    cur=[cur-step,target].max if cur>target
    sp.opacity=cur
    sp.visible=(cur>0)
    bss096_restore_room_filters!
  rescue
  end

  def pbUpdate(*args,&block)
    ret=super
    bss096_tick_capture_filter
    ret
  end
end

#-------------------------------------------------------------------------------
# Background-centric Wild Intro. No copied/black Pokémon is drawn over a plate.
# The actual currently-active EBDX/Vanilla world is snapshotted without battlers,
# animated, then dissolved to the real scene while the real foe fades in.
#-------------------------------------------------------------------------------
module BSS096WildIntroAuthority
  def bss096_native_wild_intro
    m=method(:pbBattleIntroAnimation).super_method
    while m && m.owner.to_s.start_with?("BSS")
      m=m.super_method
    end
    return m.call if m
    nil
  end

  def bss096_intro_foes
    rows=[]
    (@battle.battlers rescue []).each do |b|
      next if !b || !b.respond_to?(:index) || b.index.to_i.even?
      sp=@sprites["pokemon_#{b.index}"] rescue nil
      sh=@sprites["shadow_#{b.index}"] rescue nil
      next if !sp
      tone=sp.tone rescue nil; color=sp.color rescue nil
      rows << {:index=>b.index,:sprite=>sp,:shadow=>sh,
               :visible=>(sp.visible rescue true),:opacity=>(sp.opacity rescue 255),
               :shadow_visible=>(sh.visible rescue false),:shadow_opacity=>(sh.opacity rescue 255),
               :tone=>(tone ? Tone.new(tone.red,tone.green,tone.blue,tone.gray) : nil),
               :color=>(color ? Color.new(color.red,color.green,color.blue,color.alpha) : nil)}
    end
    rows
  rescue
    []
  end

  # Animate the LIVE EBDX room. No screenshot/biome plate sits over the
  # battle; the same background the battle will use is what moves during intro.
  def bss096_live_ebdx_intro(style,cfg)
    return false unless BSS096.ebdx?(self) && @vector && defined?(BSS070EBDXCore)
    bss070_ebdx_ensure_core if respond_to?(:bss070_ebdx_ensure_core)
    room=@bss070_ebdx_room rescue nil
    return false unless room
    foes=bss096_intro_foes
    main=(BSS070EBDXCore.get_vector(:MAIN,@battle) rescue @vector.get).map{|x| x.to_f}
    start=main.clone
    zoom=BSS096.clamp(cfg["zoomStart"],105,170)/100.0
    dx=BSS096.clamp(cfg["driftX"],-32,32); dy=BSS096.clamp(cfg["driftY"],-24,24)
    case style
    when "side_sweep"
      start[0]-=84; start[1]+=8; start[4]*=1.08; start[5]*=1.08
    when "focus_zoom"
      start[0]+=54; start[1]-=24; start[4]*=[zoom,1.28].max; start[5]*=[zoom,1.28].max
    when "flash_focus"
      start[0]+=38; start[1]-=18; start[4]*=[zoom,1.18].max; start[5]*=[zoom,1.18].max
    when "dark_reveal"
      start[0]+=dx*2; start[1]+=dy*2; start[4]*=1.12; start[5]*=1.12
    when "custom"
      start[0]+=dx*4; start[1]+=dy*4; start[4]*=zoom; start[5]*=zoom
    else
      # NDS-like push from the foe side, but on the live authored room.
      start[0]+=48; start[1]-=22; start[4]*=[zoom,1.22].min; start[5]*=[zoom,1.22].min
    end
    hold=[[cfg["holdFrames"].to_i,0].max,50].min
    move=[[cfg["moveFrames"].to_i,8].max,72].min
    reveal=[[cfg["revealFrames"].to_i,4].max,24].min
    saved_freeze=@bss083_camera_freeze.to_i
    @bss083_camera_freeze=saved_freeze+1
    @bss087_camera_tween=nil
    begin
      foes.each do |r|
        sp=r[:sprite]; sh=r[:shadow]
        sp.tone=Tone.new(0,0,0,0) if sp.respond_to?(:tone=)
        sp.color=Color.new(0,0,0,0) if sp.respond_to?(:color=)
        sp.opacity=0 if sp.respond_to?(:opacity=); sp.visible=true if sp.respond_to?(:visible=)
        if sh; sh.opacity=0 if sh.respond_to?(:opacity=); sh.visible=r[:shadow_visible] if sh.respond_to?(:visible=); end
      end
      @vector.snap(start) if @vector.respond_to?(:snap)
      room.update; bss096_restore_room_filters! if respond_to?(:bss096_restore_room_filters!)
      hold.times do
        room.update; Graphics.update; Input.update if defined?(Input) && Input.respond_to?(:update)
      end
      move.times do |i|
        t=(i+1).to_f/move; e=t*t*(3.0-2.0*t)
        v=6.times.map{|j| start[j].to_f+(main[j].to_f-start[j].to_f)*e}
        @vector.snap(v) if @vector.respond_to?(:snap)
        room.update
        Graphics.update; Input.update if defined?(Input) && Input.respond_to?(:update)
      end
      @vector.snap(main) if @vector.respond_to?(:snap); room.update
      foes.each do |r|
        sp=r[:sprite]; sp.tone=Tone.new(0,0,0,0) if sp.respond_to?(:tone=); sp.color=Color.new(0,0,0,0) if sp.respond_to?(:color=)
      end
      reveal.times do |i|
        e=(i+1).to_f/reveal
        foes.each do |r|
          sp=r[:sprite]; sh=r[:shadow]
          sp.opacity=(r[:opacity].to_i*e).round if sp.respond_to?(:opacity=)
          sh.opacity=(r[:shadow_opacity].to_i*e).round if sh && r[:shadow_visible] && sh.respond_to?(:opacity=)
        end
        room.update; Graphics.update; Input.update if defined?(Input) && Input.respond_to?(:update)
      end
      begin
        first=foes[0]; b=@battle.battlers[first[:index]] if first
        b.pokemon.play_cry if b && b.respond_to?(:pokemon) && b.pokemon
      rescue
      end
      true
    ensure
      @vector.snap(main) if @vector && @vector.respond_to?(:snap)
      @bss083_camera_freeze=saved_freeze
      foes.each do |r|
        begin
          sp=r[:sprite]; sh=r[:shadow]
          sp.visible=r[:visible] if sp.respond_to?(:visible=); sp.opacity=r[:opacity] if sp.respond_to?(:opacity=)
          sp.tone=Tone.new(0,0,0,0) if sp.respond_to?(:tone=); sp.color=Color.new(0,0,0,0) if sp.respond_to?(:color=)
          if sh; sh.visible=r[:shadow_visible] if sh.respond_to?(:visible=); sh.opacity=r[:shadow_opacity] if sh.respond_to?(:opacity=); end
        rescue
        end
      end
      begin; room.update; rescue; end
      @viewport.color=Color.new(0,0,0,0) if @viewport && @viewport.respond_to?(:color=)
    end
  rescue => e
    BSS064.log("BSS096 live EBDX intro warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  def bss096_world_intro(style,cfg)
    foes=bss096_intro_foes
    snap=bss083_nds_world_snapshot(foes.map{|r| [r[:index],r[:sprite],r[:shadow]]}) if respond_to?(:bss083_nds_world_snapshot)
    snap=Graphics.snap_to_bitmap if !snap && defined?(Graphics) && Graphics.respond_to?(:snap_to_bitmap)
    return false if !snap
    vp=nil; bg=nil; dark=nil; white=nil
    hold=[[cfg["holdFrames"].to_i,0].max,60].min
    move=[[cfg["moveFrames"].to_i,8].max,90].min
    reveal=[[cfg["revealFrames"].to_i,6].max,30].min
    zoom_cfg=BSS096.clamp(cfg["zoomStart"],100,180)/100.0
    dim=[[cfg["dim"].to_i,0].max,140].min
    flash=[[cfg["flash"].to_i,0].max,180].min
    dx=BSS096.clamp(cfg["driftX"],-32,32); dy=BSS096.clamp(cfg["driftY"],-24,24)
    begin
      foes.each do |r|
        sp=r[:sprite]; sh=r[:shadow]
        sp.visible=false if sp.respond_to?(:visible=); sp.opacity=0 if sp.respond_to?(:opacity=)
        sh.visible=false if sh && sh.respond_to?(:visible=)
      end
      vp=Viewport.new(0,0,Graphics.width,Graphics.height); vp.z=99970
      bg=Sprite.new(vp); bg.bitmap=snap; bg.ox=snap.width/2.0; bg.oy=snap.height/2.0; bg.x=Graphics.width/2.0; bg.y=Graphics.height/2.0; bg.z=0
      dark=Sprite.new(vp); dark.bitmap=Bitmap.new(1,1); dark.bitmap.fill_rect(0,0,1,1,Color.new(0,0,0)); dark.zoom_x=Graphics.width; dark.zoom_y=Graphics.height; dark.z=5; dark.opacity=0
      white=Sprite.new(vp); white.bitmap=Bitmap.new(1,1); white.bitmap.fill_rect(0,0,1,1,Color.new(255,255,255)); white.zoom_x=Graphics.width; white.zoom_y=Graphics.height; white.z=6; white.opacity=0
      case style
      when "focus_zoom" then start_zoom=[zoom_cfg,1.28].max; start_x=Graphics.width*0.43; start_y=Graphics.height*0.46
      when "side_sweep" then start_zoom=1.08; start_x=Graphics.width/2.0-84; start_y=Graphics.height/2.0
      when "flash_focus" then start_zoom=[zoom_cfg,1.15].max; start_x=Graphics.width*0.46; start_y=Graphics.height*0.48
      when "dark_reveal" then start_zoom=1.10; start_x=Graphics.width/2.0+dx; start_y=Graphics.height/2.0+dy
      when "custom" then start_zoom=zoom_cfg; start_x=Graphics.width/2.0+dx*4; start_y=Graphics.height/2.0+dy*4
      else # nds_biome: real world is the transition, not a biome plate.
        start_zoom=[zoom_cfg,1.18].min; start_zoom=[start_zoom,1.12].max
        start_x=Graphics.width*0.46; start_y=Graphics.height*0.48
      end
      bg.zoom_x=start_zoom; bg.zoom_y=start_zoom; bg.x=start_x; bg.y=start_y
      dark.opacity=(style=="dark_reveal" ? dim : (dim*0.35).round)
      hold.times do
        Graphics.update; Input.update if defined?(Input) && Input.respond_to?(:update)
      end
      move.times do |i|
        t=(i+1).to_f/move; e=t*t*(3.0-2.0*t)
        bg.zoom_x=start_zoom+(1.0-start_zoom)*e; bg.zoom_y=bg.zoom_x
        bg.x=start_x+(Graphics.width/2.0-start_x)*e; bg.y=start_y+(Graphics.height/2.0-start_y)*e
        dark.opacity=((style=="dark_reveal" ? dim : dim*0.35)*(1.0-e)).round
        if style=="flash_focus" && i>=move/3 && i<move/3+8
          q=(i-move/3).to_f/8.0; white.opacity=(flash*(1.0-q)).round
        else
          white.opacity=0
        end
        Graphics.update; Input.update if defined?(Input) && Input.respond_to?(:update)
      end
      # Dissolve the temporary world into the real identical world. Real foe is
      # neutral-toned before visibility is restored, eliminating black spawn.
      foes.each do |r|
        sp=r[:sprite]; sh=r[:shadow]
        sp.tone=Tone.new(0,0,0,0) if sp.respond_to?(:tone=)
        sp.color=Color.new(0,0,0,0) if sp.respond_to?(:color=)
        sp.visible=true if sp.respond_to?(:visible=); sp.opacity=0 if sp.respond_to?(:opacity=)
        if sh
          sh.visible=r[:shadow_visible] if sh.respond_to?(:visible=); sh.opacity=0 if sh.respond_to?(:opacity=)
        end
      end
      reveal.times do |i|
        t=(i+1).to_f/reveal; e=t*t*(3.0-2.0*t)
        bg.opacity=(255*(1.0-e)).round
        dark.opacity=(dark.opacity.to_i*(1.0-e)).round
        foes.each do |r|
          r[:sprite].opacity=(r[:opacity].to_i*e).round if r[:sprite].respond_to?(:opacity=)
          if r[:shadow] && r[:shadow_visible]
            r[:shadow].opacity=(r[:shadow_opacity].to_i*e).round if r[:shadow].respond_to?(:opacity=)
          end
        end
        Graphics.update; Input.update if defined?(Input) && Input.respond_to?(:update)
      end
      begin
        first=foes[0]; b=@battle.battlers[first[:index]] if first
        b.pokemon.play_cry if b && b.respond_to?(:pokemon) && b.pokemon
      rescue
      end
      true
    ensure
      [bg,dark,white].each do |sp|
        begin
          bmp=sp.bitmap if sp
          sp.dispose if sp && !(sp.disposed? rescue true)
          bmp.dispose if bmp && bmp.width==1 && bmp.height==1 && !(bmp.disposed? rescue true)
        rescue
        end
      end
      begin; vp.dispose if vp && !(vp.disposed? rescue true); rescue; end
      begin; snap.dispose if snap && !(snap.disposed? rescue true); rescue; end
      foes.each do |r|
        begin
          sp=r[:sprite]; sh=r[:shadow]
          sp.visible=r[:visible] if sp.respond_to?(:visible=); sp.opacity=r[:opacity] if sp.respond_to?(:opacity=)
          # Always leave the real foe neutral after the intro. The previous
          # stored black tone/color was itself often the broken intro state.
          sp.tone=Tone.new(0,0,0,0) if sp.respond_to?(:tone=)
          sp.color=Color.new(0,0,0,0) if sp.respond_to?(:color=)
          if sh
            sh.visible=r[:shadow_visible] if sh.respond_to?(:visible=); sh.opacity=r[:shadow_opacity] if sh.respond_to?(:opacity=)
          end
        rescue
        end
      end
      @viewport.color=Color.new(0,0,0,0) if @viewport && @viewport.respond_to?(:color=)
    end
  rescue => e
    BSS064.log("BSS096 world intro warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  def pbBattleIntroAnimation
    wild=@battle && @battle.respond_to?(:wildBattle?) && @battle.wildBattle?
    return super unless wild
    cfg=respond_to?(:bss079_intro_config) ? (bss079_intro_config rescue {}) : {}
    cfg={} unless cfg.is_a?(Hash)
    style=(cfg["style"] || cfg[:style]).to_s
    style="nds_biome" if style.empty?
    ebdx=BSS096.ebdx?(self)
    if style=="vanilla" || (!ebdx && cfg["useInVanilla"]!=true && cfg[:useInVanilla]!=true)
      return bss096_native_wild_intro
    end
    bss070_ebdx_ensure_core if ebdx && respond_to?(:bss070_ebdx_ensure_core)
    ok=ebdx ? bss096_live_ebdx_intro(style,cfg) : bss096_world_intro(style,cfg)
    if ok
      bss079_finish_wild_intro if respond_to?(:bss079_finish_wild_intro)
      return
    end
    bss096_native_wild_intro
  end
end

#-------------------------------------------------------------------------------
# Install last.
#-------------------------------------------------------------------------------
begin
  BSS070EBDXRoom.prepend(BSS096WarpPerformance) if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS096WarpPerformance)
rescue => e
  BSS064.log("BSS096 room install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSS096SceneCameraAndBattlers) unless Battle::Scene.ancestors.include?(BSS096SceneCameraAndBattlers)
    Battle::Scene.prepend(BSS096SOSSceneAuthority) unless Battle::Scene.ancestors.include?(BSS096SOSSceneAuthority)
    Battle::Scene.prepend(BSS096CaptureFilterAuthority) unless Battle::Scene.ancestors.include?(BSS096CaptureFilterAuthority)
    Battle::Scene.prepend(BSS096WildIntroAuthority) unless Battle::Scene.ancestors.include?(BSS096WildIntroAuthority)
  end
rescue => e
  BSS064.log("BSS096 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  mix=Battle::Scene::Animation::BallAnimationMixin
  mix.prepend(BSS096PlayerBallAuthority) if defined?(mix) && !mix.ancestors.include?(BSS096PlayerBallAuthority)
rescue => e
  BSS064.log("BSS096 player ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  k=Battle::Scene::Animation::PokeballTrainerSendOut
  k.prepend(BSS096TrainerBallAuthority) if defined?(k) && !k.ancestors.include?(BSS096TrainerBallAuthority)
rescue => e
  BSS064.log("BSS096 trainer ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
