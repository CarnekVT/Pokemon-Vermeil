#===============================================================================
# Battle Scene Studio v0.8.5
# Stable EBDX world authority, source-like camera, Wild NDS, SOS and Enhanced UI.
#===============================================================================
module BSS085
  VERSION = "0.8.5"
  module_function

  def copy_visual_transform(sp)
    return nil if !sp || (sp.disposed? rescue true)
    { :x=>(sp.x rescue 0), :y=>(sp.y rescue 0), :z=>(sp.z rescue 0),
      :zx=>(sp.zoom_x rescue 1.0), :zy=>(sp.zoom_y rescue 1.0),
      :angle=>(sp.angle rescue 0) }
  end

  def restore_visual_transform(sp,row)
    return if !sp || !row || (sp.disposed? rescue true)
    sp.x=row[:x] if sp.respond_to?(:x=); sp.y=row[:y] if sp.respond_to?(:y=)
    sp.z=row[:z] if sp.respond_to?(:z=); sp.zoom_x=row[:zx] if sp.respond_to?(:zoom_x=)
    sp.zoom_y=row[:zy] if sp.respond_to?(:zoom_y=); sp.angle=row[:angle] if sp.respond_to?(:angle=)
  rescue
  end
end

# Physical 1280px EBDX backgrounds do not need the old synthetic runtime
# overscan. Keep that fallback only for genuinely small/custom legacy images.
module BSS085WideRoomAuthority
  def bss078_extend_room_bitmap!
    bg=@sprites && @sprites["bg"]
    if bg && bg.bitmap && !(bg.bitmap.disposed? rescue true) && bg.bitmap.width >= 1200 && bg.bitmap.height >= 440
      bg.instance_variable_set(:@bss084_overscanned,true)
      return true
    end
    super
  end

  # canvasLayer is scenery by definition. Never let a custom full-screen layer
  # cross into battler/UI Z space, even if a JSON edit supplied a huge Z value.
  def drawImg(key)
    ret=super
    begin
      data=@data[key]
      sp=@sprites[key]
      if data.is_a?(Hash) && data[:canvasLayer] == true && sp && sp.respond_to?(:z=)
        sp.z=[[sp.z.to_i,-500].max,14].min
      end
    rescue
    end
    ret
  end

  # User-supplied parallax scenes are reconstructed from independent layers.
  # EBDX remains the only world transform; near layers simply inherit a little
  # more of the already-computed pan/zoom around screen centre. No second camera.
  def position
    ret=super
    begin
      cx=@viewport ? @viewport.width.to_f/2.0 : Graphics.width.to_f/2.0
      cy=@viewport ? @viewport.height.to_f/2.0 : Graphics.height.to_f/2.0
      (@data||{}).each do |key,data|
        next unless key.to_s.include?("img") && data.is_a?(Hash) && data[:canvasLayer] == true
        factor=(data[:parallaxFactor] || 1.0).to_f
        next if (factor-1.0).abs < 0.0001
        factor=[[factor,0.75].max,1.35].min
        sp=@sprites[key.to_s] || @sprites[key]
        next if !sp || (sp.disposed? rescue true)
        sp.x=cx+(sp.x.to_f-cx)*factor if sp.respond_to?(:x=)
        sp.y=cy+(sp.y.to_f-cy)*(1.0+(factor-1.0)*0.35) if sp.respond_to?(:y=)
        if sp.respond_to?(:zoom_x=) && sp.respond_to?(:zoom_x)
          sp.zoom_x=1.0+(sp.zoom_x.to_f-1.0)*factor
        end
        if sp.respond_to?(:zoom_y=) && sp.respond_to?(:zoom_y)
          sp.zoom_y=1.0+(sp.zoom_y.to_f-1.0)*factor
        end
        sp.z=[[sp.z.to_i,-500].max,14].min if sp.respond_to?(:z=)
      end
    rescue
    end
    ret
  end
end

module BSS085SceneAuthority
  # ---------------------------------------------------------------------------
  # Source-like camera: ordinary Vanilla/PBS actions no longer request a shot.
  # The camera keeps its current vector; original EBDX-style idle drift still
  # happens only after BATTLE_MOTION_TIMER (~90 s). BAS remains authored.
  # ---------------------------------------------------------------------------
  def bss084_context_config(key)
    row=super
    if ["move","spread","sos","capture","faint"].include?(key.to_s)
      # Old 0.8.4 defaults are migrated to HOLD. Explicit non-default user
      # settings remain available from EBDX Studio.
      old={"move"=>["focus",8],"spread"=>["wide",10],"sos"=>["wide",12],"capture"=>["enemy",8],"faint"=>["focus",6]}[key.to_s]
      if old && row["enabled"]==true && row["mode"].to_s==old[0] && row["frames"].to_i==old[1]
        row=row.merge("enabled"=>false,"mode"=>"hold","frames"=>0)
      end
    end
    row
  rescue
    super
  end

  # Native/PBS actions may animate battlers, but they do not own the persistent
  # EBDX formation. Preserve the exact entry transform and restore only geometry
  # after the animation; opacity/visibility/tone remain authored by the move.
  def bss083_with_move_projection(user=nil,targets=nil,camera_cut=true)
    return yield unless bss083_camera_active? rescue false
    outer=!@bss085_native_move
    if outer
      @bss085_native_move=true
      @bss084_native_move_active=true
      @bss083_animation_projection=false
      @bss083_camera_freeze=@bss083_camera_freeze.to_i+1
      @bss085_move_geometry={}
      (@battle.battlers rescue []).each_index do |idx|
        @bss085_move_geometry[["pokemon",idx]]=BSS085.copy_visual_transform((@sprites["pokemon_#{idx}"] rescue nil))
        @bss085_move_geometry[["shadow",idx]]=BSS085.copy_visual_transform((@sprites["shadow_#{idx}"] rescue nil))
      end
    end
    yield
  ensure
    if outer
      (@bss085_move_geometry||{}).each do |key,row|
        kind,idx=key
        sp=@sprites["#{kind}_#{idx}"] rescue nil
        BSS085.restore_visual_transform(sp,row)
      end
      @bss083_camera_freeze=[@bss083_camera_freeze.to_i-1,0].max
      @bss085_native_move=false; @bss084_native_move_active=false
      @bss083_animation_projection=false; @bss083_animation_raw=nil
      begin
        @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
        bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
      rescue
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Wild NDS snapshot: capture ONLY the live EBDX world, with the viewport filter
  # temporarily cleared. This prevents the black/Vanilla frame before the foe is
  # announced. The reveal itself starts on the real scene, not a black plate.
  # ---------------------------------------------------------------------------
  def bss083_nds_world_snapshot(foes)
    return nil if !defined?(Graphics) || !Graphics.respond_to?(:snap_to_bitmap)
    hidden=[]; old_color=nil
    ebdx = respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    begin
      if @viewport && @viewport.respond_to?(:color) && @viewport.respond_to?(:color=)
        c=@viewport.color
        old_color=Color.new(c.red,c.green,c.blue,c.alpha) rescue nil
        @viewport.color=Color.new(0,0,0,0)
      end
      if ebdx
        @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
        # EBDX mode: the authored room is the only background authority.
        bss070_ebdx_hide_native_backdrops if respond_to?(:bss070_ebdx_hide_native_backdrops)
      end
      (@sprites||{}).each do |key,sp|
        next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible)
        k=key.to_s
        keep_background = if ebdx
                            (k=="battlebg")
                          else
                            # Vanilla mode: snapshot the actual Essentials backdrop
                            # and bases instead of hiding them behind the NDS intro.
                            (k=="battle_bg" || k=="battle_bg2" || k=="base_0" || k=="base_1")
                          end
        next if keep_background
        # Hide battlers, trainers and every UI family. In Vanilla, unknown scenery
        # extensions are left alone so the snapshot matches the real battle world.
        hide = ebdx ||
               k =~ /^(pokemon_|shadow_|dataBox_|trainer_|player_|party|cmdBar|command|fight|target|message|enhanced|info_icon|ball_icon|leftarrow|rightarrow|boss|ability|itemWindow|captureBall)/i ||
               k =~ /_outline\d+$/i
        next unless hide
        hidden << [sp,sp.visible]
        sp.visible=false if sp.respond_to?(:visible=)
      rescue
      end
      Graphics.snap_to_bitmap
    ensure
      hidden.each{|sp,vis| begin; sp.visible=vis if sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible=); rescue; end}
      @viewport.color=old_color if old_color && @viewport && @viewport.respond_to?(:color=)
    end
  end

  def bss083_run_standalone_wild_nds
    foes=bss083_nds_foe_rows
    return false if foes.empty?
    snap=bss083_nds_world_snapshot(foes)
    return false if !snap
    cfg=respond_to?(:bss079_intro_config) ? (bss079_intro_config rescue {}) : {}; cfg={} unless cfg.is_a?(Hash)
    hold=[[ (cfg["holdFrames"]||12).to_i,0].max,120].min
    move=[[ (cfg["moveFrames"]||24).to_i,10].max,180].min
    reveal=[[ (cfg["revealFrames"]||12).to_i,6].max,move].min
    zoom=[[(cfg["zoomStart"]||170).to_f/100.0,1.0].max,2.2].min
    visibility={}; (@sprites||{}).each{|k,sp| visibility[k]=(sp.visible rescue nil) if sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible)}
    @bss083_standalone_intro=true
    vp=Viewport.new(0,0,Graphics.width,Graphics.height); vp.z=999_000 if vp.respond_to?(:z=); temp=[]
    begin
      (@sprites||{}).each{|k,sp| begin; sp.visible=false if k.to_s!="battlebg" && sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible=); rescue; end}
      cx=Graphics.width/2.0; cy=Graphics.height/2.0; first=foes[0][1]
      fx=(first.x rescue Graphics.width*0.72).to_f; fy=(first.y rescue Graphics.height*0.40).to_f
      bg=Sprite.new(vp); bg.bitmap=snap; bg.ox=snap.width/2; bg.oy=snap.height/2; bg.x=cx+(cx-fx)*zoom; bg.y=cy+(cy-fy)*zoom; bg.zoom_x=zoom; bg.zoom_y=zoom; bg.z=0; temp<<bg
      rows=[]
      foes.each_with_index do |row,i|
        idx,src,_sh=row; cp=bss083_nds_copy_sprite(src,vp,100+i); next if !cp
        ex=src.x.to_f; ey=src.y.to_f; ezx=src.zoom_x.to_f; ezy=src.zoom_y.to_f
        cp.x=cx+(ex-fx)*zoom; cp.y=cy+(ey-fy)*zoom; cp.zoom_x=ezx*zoom; cp.zoom_y=ezy*zoom; cp.opacity=0
        cp.tone=Tone.new(0,0,0,0) if cp.respond_to?(:tone=); rows<<[idx,src,cp,ex,ey,ezx,ezy]; temp<<cp
      end
      icfg=bss083_nds_intro_config rescue {}; intro=nil; visual=icfg[:visual]||icfg["visual"]
      if visual && (pbResolveBitmap(visual) rescue false)
        intro=Sprite.new(vp); intro.bitmap=pbBitmap(visual); sc=[Graphics.width.to_f/[intro.bitmap.width,1].max,Graphics.height.to_f/[intro.bitmap.height,1].max].max
        intro.zoom_x=sc; intro.zoom_y=sc; intro.z=800; intro.opacity=255; temp<<intro
      end
      bss083_nds_play_se(icfg[:se]||icfg["se"]); drift=icfg[:drift]||icfg["drift"]||[(cfg["driftX"]||-7),(cfg["driftY"]||3)]; dx=drift[0].to_f; dy=drift[1].to_f
      white=Sprite.new(vp); white.bitmap=Bitmap.new(1,1); white.bitmap.fill_rect(0,0,1,1,Color.new(255,255,255)); white.zoom_x=Graphics.width; white.zoom_y=Graphics.height; white.opacity=0; white.z=950; temp<<white
      cried=false; (hold+move).times do |f|
        if intro
          intro.x += dx/[hold+move,1].max; intro.y += dy/[hold+move,1].max
          intro.opacity=(255*(1.0-[((f-hold+1).to_f/move)/0.75,1.0].min)).round if f>=hold
        end
        if f>=hold
          local=f-hold+1; t=[local.to_f/move,1.0].min; ease=t*t*(3.0-2.0*t); sx=cx+(cx-fx)*zoom; sy=cy+(cy-fy)*zoom
          bg.x=sx+(cx-sx)*ease; bg.y=sy+(cy-sy)*ease; z=zoom+(1.0-zoom)*ease; bg.zoom_x=z; bg.zoom_y=z
          rows.each do |idx,src,cp,ex,ey,ezx,ezy|
            px=cx+(ex-fx)*zoom; py=cy+(ey-fy)*zoom; cp.x=px+(ex-px)*ease; cp.y=py+(ey-py)*ease; cp.zoom_x=ezx*z; cp.zoom_y=ezy*z
            rp=[local.to_f/reveal,1.0].min; cp.opacity=(255*(rp*rp*(3.0-2.0*rp))).round
          end
          if !cried && local>=[reveal/2,1].max; bss083_nds_play_cry(rows[0][0]) if rows[0]; cried=true; end
          flash=(cfg["flash"]||120).to_i; white.opacity = local<=3 ? (flash*local/3.0).round : (local<=10 ? (flash*(1.0-(local-3).to_f/7.0)).round : 0)
        end
        Graphics.update; Input.update if defined?(Input) && Input.respond_to?(:update)
      end
      foes.each{|_i,src,_s| begin; src.opacity=255 if src.respond_to?(:opacity=); src.tone=Tone.new(0,0,0,0) if src.respond_to?(:tone=); rescue; end}; true
    ensure
      temp.reverse_each{|sp| begin; if sp && sp.bitmap && sp.bitmap.width==1 && sp.bitmap.height==1; sp.bitmap.dispose unless sp.bitmap.disposed? rescue nil; end; sp.dispose if sp && !(sp.disposed? rescue true); rescue; end}
      begin; snap.dispose if snap && !(snap.disposed? rescue true); rescue; end; begin; vp.dispose if vp && !(vp.disposed? rescue true); rescue; end
      visibility.each{|k,v| sp=@sprites[k] rescue nil; begin; sp.visible=v if !v.nil? && sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible=); rescue; end}
      foes.each{|_i,src,_s| begin; src.visible=true if src && src.respond_to?(:visible=); rescue; end}
      # The standalone EBDX intro is the transition owner. Do not resurrect a
      # stale black Vanilla viewport color after disposing its private viewport.
      begin; @viewport.color=Color.new(0,0,0,0) if @viewport && @viewport.respond_to?(:color=); rescue; end
      @bss083_standalone_intro=false
    end
  rescue => e
    @bss083_standalone_intro=false; BSS064.log("BSS085 Wild NDS warning: #{e.class}: #{e.message}") if defined?(BSS064); false
  end

  # ---------------------------------------------------------------------------
  # Complete room filter. During Boss capture/revert, DBK sometimes filters only
  # scene-owned sprites. Mirror the strongest native/viewport filter to every
  # EBDX room visual, including custom img###/parallax layers.
  # ---------------------------------------------------------------------------
  def bss085_capture_filter_active?
    return true if @bss085_capture_filter_active
    return true if @battle && @battle.instance_variable_get(:@bss653_boss_capture_visuals_locked)==true
    false
  rescue
    false
  end

  def bss081_sync_background_filter
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    room=@bss070_ebdx_room rescue nil; rs=room.instance_variable_get(:@sprites) rescue nil; return super unless rs.is_a?(Hash)
    native=(@sprites["battle_bg"] rescue nil)||(@sprites["battle_bg2"] rescue nil)
    c=native.color rescue nil; t=native.tone rescue nil
    if (!c || c.alpha.to_i<=0) && bss085_capture_filter_active?; c=Color.new(0,0,0,112); end
    rs.each do |key,sp|
      next if !sp || (sp.disposed? rescue false); k=key.to_s
      next if k.start_with?("battler") || k.start_with?("shadow") || k.start_with?("trainer_")
      begin
        if sp.respond_to?(:color=)
          if c && c.alpha.to_i>0
            unless sp.instance_variable_defined?(:@bss085_base_color); bc=sp.color rescue nil; sp.instance_variable_set(:@bss085_base_color,Color.new(bc.red,bc.green,bc.blue,bc.alpha)) if bc; end
            sp.color=Color.new(c.red,c.green,c.blue,c.alpha)
          elsif sp.instance_variable_defined?(:@bss085_base_color)
            sp.color=sp.instance_variable_get(:@bss085_base_color); sp.remove_instance_variable(:@bss085_base_color) rescue nil
          end
        end
        if sp.respond_to?(:tone=)
          active=t && (t.red.to_i!=0 || t.green.to_i!=0 || t.blue.to_i!=0 || t.gray.to_i!=0)
          if active
            unless sp.instance_variable_defined?(:@bss085_base_tone); bt=sp.tone rescue nil; sp.instance_variable_set(:@bss085_base_tone,Tone.new(bt.red,bt.green,bt.blue,bt.gray)) if bt; end
            sp.tone=Tone.new(t.red,t.green,t.blue,t.gray)
          elsif sp.instance_variable_defined?(:@bss085_base_tone)
            sp.tone=sp.instance_variable_get(:@bss085_base_tone); sp.remove_instance_variable(:@bss085_base_tone) rescue nil
          end
        end
      rescue
      end
    end
  rescue => e
    BSS064.log("BSS085 room filter warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def pbRevertBattlerStart(*args,&block)
    # Capture/decline transition itself calls pbUpdate, so the Room must already
    # be participating in the filter before DBK animates the battler.
    @bss085_capture_filter_active=true
    bss081_sync_background_filter
    ret=super
    bss081_sync_background_filter
    ret
  end

  def pbRevertBattlerEnd(*args,&block)
    ret=super; @bss085_capture_filter_active=false; bss081_sync_background_filter; ret
  end

  # ---------------------------------------------------------------------------
  # Enhanced UI: BSS only fixes final layer order and stale visibility leaks.
  # The plugin still owns icon/outline visibility and all interactions.
  # ---------------------------------------------------------------------------
  def bss085_enhanced_ui_layers
    return if !@sprites.is_a?(Hash)
    # TargetMenu/BattleBox use 10000 in Essentials/BSS. Enhanced must be above
    # them, otherwise its panel is visibly clipped by the native battle UI.
    main=@sprites["enhancedUI"] rescue nil; main.z=11000 if main && !(main.disposed? rescue true) && main.respond_to?(:z=)
    prompt=@sprites["enhancedUIPrompts"] rescue nil; prompt.z=11060 if prompt && !(prompt.disposed? rescue true) && prompt.respond_to?(:z=)
    ["leftarrow","rightarrow"].each{|k| sp=@sprites[k] rescue nil; sp.z=11100 if sp && !(sp.disposed? rescue true) && sp.respond_to?(:z=)}
    @sprites.each do |k,sp|
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:z=); s=k.to_s
      if s =~ /^(info_icon|ball_icon).*_outline\d+$/; sp.z=11140
      elsif s =~ /^(info_icon|ball_icon)\d+$/; sp.z=11141
      end
    end
  rescue
  end

  def bss085_enhanced_prompt_guard
    p=@sprites["enhancedUIPrompts"] rescue nil; return if !p || (p.disposed? rescue true)
    cmd=(@sprites["commandWindow"].visible rescue false); fight=(@sprites["fightWindow"].visible rescue false)
    unless cmd || fight
      pbHideUIPrompt if respond_to?(:pbHideUIPrompt) && (p.visible rescue false)
      return
    end
    want = fight && defined?(Battle::Scene::FIGHT_BOX) ? Battle::Scene::FIGHT_BOX : (defined?(Battle::Scene::COMMAND_BOX) ? Battle::Scene::COMMAND_BOX : nil)
    p.window=want if want && p.respond_to?(:window) && p.window!=want && p.respond_to?(:window=)
  rescue
  end

  # Apply the final Enhanced ordering on the same frame a menu window changes,
  # not one pbUpdate later. This also gives EnhancedUIPrompt the correct
  # COMMAND_BOX/FIGHT_BOX so its :A / :S command slashes are redrawn.
  def pbShowWindow(windowType,*args,&block)
    ret=super
    bss085_enhanced_prompt_guard
    bss085_enhanced_ui_layers
    ret
  end

  def pbUpdateInfoSprites(*args,&block)
    ret=super
    bss085_enhanced_ui_layers
    ret
  end

  # Enhanced's outline helpers assign their authored local Z (300/400, etc.)
  # immediately. Without a same-call correction there is one rendered frame in
  # which icons/outlines can sit underneath the Enhanced panel. Keep Enhanced's
  # own coordinates/visibility, then restore only the final BSS layer order.
  def pbSetWithOutline(sprite, coords=[], color=Color.white, border=2)
    ret=super
    bss085_enhanced_ui_layers
    ret
  end

  def pbShowOutline(sprite, visibility=true)
    ret=super
    bss085_enhanced_ui_layers
    ret
  end

  def pbAddSpriteOutline(param=[], color=Color.white, border=2, opacity=255)
    ret=super
    bss085_enhanced_ui_layers
    ret
  end

  # Refresh prompts only for the command/fight context that owns them. Enhanced
  # calls this once before COMMAND_BOX becomes visible, so an explicit window is
  # accepted; later refreshes infer the real visible window. Supplying the real
  # battler index is important because EnhancedUIPrompt#refresh redraws the A/S
  # command slash differently for COMMAND_BOX and FIGHT_BOX.
  def pbRefreshUIPrompt(idxBattler=nil, window=nil)
    command_box = defined?(Battle::Scene::COMMAND_BOX) ? Battle::Scene::COMMAND_BOX : nil
    fight_box   = defined?(Battle::Scene::FIGHT_BOX) ? Battle::Scene::FIGHT_BOX : nil
    cmd_vis=(@sprites["commandWindow"].visible rescue false)
    fight_vis=(@sprites["fightWindow"].visible rescue false)
    explicit_valid=(window==command_box || window==fight_box)
    unless explicit_valid || cmd_vis || fight_vis
      pbHideUIPrompt if respond_to?(:pbHideUIPrompt)
      return false
    end
    actual = window
    actual = fight_box if actual.nil? && fight_vis
    actual = command_box if actual.nil? && cmd_vis
    # CommandMenu/FightMenu are UI menus, not battler owners in Essentials v21.1.
    # Never call #battler on them. EnhancedUIPrompt owns the last battler context;
    # preserve an explicit index when supplied and use that safe context otherwise.
    if !idxBattler.nil?
      raw_idx = idxBattler.respond_to?(:index) ? idxBattler.index : idxBattler
      @bss085_last_prompt_battler = raw_idx.to_i if raw_idx.is_a?(Numeric)
    else
      owner = nil
      prompt = @sprites["enhancedUIPrompts"] rescue nil
      owner = prompt.battler if prompt && prompt.respond_to?(:battler)
      owner = owner.index if owner && owner.respond_to?(:index)
      owner = nil unless owner.is_a?(Numeric)
      idxBattler = owner || @bss085_last_prompt_battler
    end
    ret=super(idxBattler,actual)
    bss085_enhanced_prompt_guard
    bss085_enhanced_ui_layers
    ret
  end

  def bss078_cinematic_ui_restore(state)
    filtered={}; (state||{}).each{|k,v| filtered[k]=v unless k.to_s =~ /(enhancedUI|enhancedUIPrompts|info_icon|ball_icon|leftarrow|rightarrow|_outline)/i} if state.is_a?(Hash)
    super(filtered); bss085_enhanced_prompt_guard; bss085_enhanced_ui_layers
  end

  def pbUpdate(*args,&block)
    ret=super; bss085_enhanced_prompt_guard; bss085_enhanced_ui_layers; bss081_sync_background_filter; ret
  end

  # SOS: freeze camera while formation changes. This prevents a camera update and
  # a slot reflow from competing during the same 12/20-frame join.
  def bss_pbSOSJoin(idx_battler,*args,&block)
    @bss083_camera_freeze=@bss083_camera_freeze.to_i+1
    begin; bss_sync_sos_side_size_state(idx_battler) if respond_to?(:bss_sync_sos_side_size_state); rescue; end
    super
  ensure
    @bss083_camera_freeze=[@bss083_camera_freeze.to_i-1,0].max
    begin; bss_sync_sos_side_size_state(idx_battler) if respond_to?(:bss_sync_sos_side_size_state); rescue; end
  end

  # One deliberate terminal camera settle, and only here. This gives all victory,
  # capture/decline and fade paths the same final world position.
  def bss085_finish_camera!
    return unless bss083_camera_active? rescue false
    # Preserve the last valid EBDX shot through victory/capture/fade. Scene
    # disposal does not need a MAIN vector, and changing it here was visible as
    # an inconsistent final snap on the last battle frame.
    @bss070_ebdx_room.update rescue nil
    bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
    true
  rescue
    true
  end
end

# Slower, non-pop SOS formation animation. Incoming battler is already hidden by
# prep; set its final coordinates at frame 0, then reveal while the rest reflows.
if defined?(Battle::Scene::Animation::BSSSOSJoin)
  class Battle::Scene::Animation::BSSSOSJoin < Battle::Scene::Animation
    def createProcesses
      duration=20
      @battle.battlers.each do |b|
        next if !b || b.opposes?(@idx_sos)
        bat=@sprites["pokemon_#{b.index}"]; sha=@sprites["shadow_#{b.index}"]; boxsp=@sprites["dataBox_#{b.index}"]; next if !bat
        side_size=bat.respond_to?(:sideSize) && bat.sideSize ? bat.sideSize : @battle.pbSideSize(b.index)
        nx,ny,nz=bss_sos_battler_position(b,side_size,bat)
        if b.index==@idx_sos
          obj=addSprite(bat,PictureOrigin::BOTTOM); obj.setXY(0,nx,ny) if obj.respond_to?(:setXY); obj.setZ(0,nz) if obj.respond_to?(:setZ); obj.setTone(0,Tone.new(-196,-196,-196,-196)); obj.setOpacity(0,0); obj.setVisible(0,true); obj.moveOpacity(2,14,255); obj.moveTone(5,15,Tone.new(0,0,0,0),[bat,:pbPlayIntroAnimation])
          if sha; sx,sy,sz=bss_sos_shadow_position(b,side_size,sha); sh=addSprite(sha,PictureOrigin::CENTER); sh.setXY(0,sx,sy); sh.setZ(0,sz) if sh.respond_to?(:setZ); sh.setOpacity(0,0); sh.setVisible(0,true); sh.moveOpacity(4,12,255); end
          if boxsp; bx=addSprite(boxsp); mode=(BSS064.databox_animation_mode rescue "slide"); if mode=="fade"; bx.setOpacity(0,0); bx.setVisible(2,true); bx.moveOpacity(4,16,255); elsif mode=="pop"; bx.setOpacity(6,255); bx.setVisible(6,true); else; dir=b.index.even? ? 1 : -1; bx.setOpacity(0,255) if bx.respond_to?(:setOpacity); bx.setDelta(0,dir*Graphics.width/2,0); bx.setVisible(2,true); bx.moveDelta(2,18,-dir*Graphics.width/2,0); end; end
        else
          obj=addSprite(bat,PictureOrigin::BOTTOM); obj.setZ(0,nz) if obj.respond_to?(:setZ); obj.moveXY(0,duration,nx,ny)
          if sha; sx,sy,sz=bss_sos_shadow_position(b,side_size,sha); sh=addSprite(sha,PictureOrigin::CENTER); sh.setZ(0,sz) if sh.respond_to?(:setZ); sh.moveXY(0,duration,sx,sy); end
          if boxsp; bx=addSprite(boxsp); from=boxsp.instance_variable_get(:@bss656_reflow_from_xy) rescue nil; to=boxsp.instance_variable_get(:@bss656_reflow_to_xy) rescue nil; if from.is_a?(Array)&&to.is_a?(Array); bx.setXY(0,from[0],from[1]); bx.moveXY(0,duration,to[0],to[1]); boxsp.instance_variable_set(:@bss656_reflow_from_xy,nil) rescue nil; boxsp.instance_variable_set(:@bss656_reflow_to_xy,nil) rescue nil; end; end
        end
      end
    end
  end
end

module BSS085BattleEndAuthority
  def pbEndOfBattle(*args,&block)
    begin; @scene.bss085_finish_camera! if @scene && @scene.respond_to?(:bss085_finish_camera!); rescue; end
    super
  end
end

begin
  BSS070EBDXRoom.prepend(BSS085WideRoomAuthority) if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS085WideRoomAuthority)
rescue => e
  BSS064.log("BSS085 room install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle::Scene.prepend(BSS085SceneAuthority) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS085SceneAuthority)
rescue => e
  BSS064.log("BSS085 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle.prepend(BSS085BattleEndAuthority) if defined?(Battle) && !Battle.ancestors.include?(BSS085BattleEndAuthority)
rescue => e
  BSS064.log("BSS085 battle install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
