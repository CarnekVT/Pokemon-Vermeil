#===============================================================================
# Battle Scene Studio v0.8.7
# Stable camera profiles, exact sendout endpoints, smooth SOS formation,
# atomic capture filter, Enhanced UI authority and end-battle visual lock.
#===============================================================================

module BSS087
  VERSION = "0.8.7"
  BUNDLED_SCENES_FILE = "Data/BattleSceneStudio/EBDX/bundled_scenes.json"

  CAMERA_PROFILES = {
    "minimal" => {
      "label" => "Minimal",
      "contexts" => {
        "command"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "fight"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "move"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "spread"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "common"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "sendout"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "recall"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "sos"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "capture"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "faint"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "turn_end"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "idle"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "bas"=>{"enabled"=>true,"mode"=>"authored","frames"=>0,"strength"=>100}
      }
    },
    "source_faithful" => {
      "label" => "EBDX Source Faithful",
      "contexts" => {
        "command"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "fight"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "move"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "spread"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "common"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "sendout"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "recall"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "sos"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "capture"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "faint"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "turn_end"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "idle"=>{"enabled"=>true,"mode"=>"drift","frames"=>0,"strength"=>100},
        "bas"=>{"enabled"=>true,"mode"=>"authored","frames"=>0,"strength"=>100}
      }
    },
    "smooth_dynamic" => {
      "label" => "Dynamic Smooth",
      "contexts" => {
        "command"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "fight"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "move"=>{"enabled"=>true,"mode"=>"focus","frames"=>32,"strength"=>20},
        "spread"=>{"enabled"=>true,"mode"=>"wide","frames"=>36,"strength"=>18},
        "common"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "sendout"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "recall"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "sos"=>{"enabled"=>true,"mode"=>"wide","frames"=>38,"strength"=>16},
        "capture"=>{"enabled"=>true,"mode"=>"enemy","frames"=>34,"strength"=>18},
        "faint"=>{"enabled"=>true,"mode"=>"focus","frames"=>30,"strength"=>14},
        "turn_end"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "idle"=>{"enabled"=>true,"mode"=>"drift","frames"=>0,"strength"=>75},
        "bas"=>{"enabled"=>true,"mode"=>"authored","frames"=>0,"strength"=>100}
      }
    },
    "cinematic" => {
      "label" => "Cinematic",
      "contexts" => {
        "command"=>{"enabled"=>true,"mode"=>"player","frames"=>34,"strength"=>14},
        "fight"=>{"enabled"=>true,"mode"=>"player","frames"=>30,"strength"=>18},
        "move"=>{"enabled"=>true,"mode"=>"focus","frames"=>26,"strength"=>34},
        "spread"=>{"enabled"=>true,"mode"=>"wide","frames"=>30,"strength"=>28},
        "common"=>{"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0},
        "sendout"=>{"enabled"=>true,"mode"=>"focus","frames"=>30,"strength"=>22},
        "recall"=>{"enabled"=>true,"mode"=>"focus","frames"=>26,"strength"=>18},
        "sos"=>{"enabled"=>true,"mode"=>"wide","frames"=>34,"strength"=>28},
        "capture"=>{"enabled"=>true,"mode"=>"enemy","frames"=>30,"strength"=>32},
        "faint"=>{"enabled"=>true,"mode"=>"focus","frames"=>28,"strength"=>26},
        "turn_end"=>{"enabled"=>true,"mode"=>"neutral","frames"=>40,"strength"=>12},
        "idle"=>{"enabled"=>true,"mode"=>"drift","frames"=>0,"strength"=>100},
        "bas"=>{"enabled"=>true,"mode"=>"authored","frames"=>0,"strength"=>100}
      }
    }
  }

  def self.deep_copy(v)
    Marshal.load(Marshal.dump(v))
  rescue
    v
  end

  def self.context(profile, key)
    p = CAMERA_PROFILES[profile.to_s] || CAMERA_PROFILES["source_faithful"]
    deep_copy((p["contexts"] || {})[key.to_s] || {"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0})
  end

  def self.clamp(v, lo, hi)
    [[v.to_f, lo.to_f].max, hi.to_f].min
  end
end

#-------------------------------------------------------------------------------
# Bundled scenes are read-only defaults. Project-created scenes remain in the
# user's Data/BattleSceneStudio/EBDX/scenes.json and override matching IDs.
# Updates therefore never need to overwrite project scene data.
#-------------------------------------------------------------------------------
module BSS087SceneDataAuthority
  def external_scenes
    bundled = []
    begin
      raw = external_json(BSS087::BUNDLED_SCENES_FILE)
      rows = raw["scenes"] || raw[:scenes]
      bundled = rows if rows.is_a?(Array)
    rescue
      bundled = []
    end
    user = super
    user = [] if !user.is_a?(Array)
    merged = {}
    bundled.each do |r|
      next unless r.is_a?(Hash)
      id = (r["id"] || r[:id]).to_s
      merged[id.downcase] = r if !id.empty?
    end
    user.each do |r|
      next unless r.is_a?(Hash)
      id = (r["id"] || r[:id]).to_s
      merged[id.downcase] = r if !id.empty?
    end
    merged.values
  rescue
    super
  end
end

#-------------------------------------------------------------------------------
# Scene camera profiles. Transitions are asynchronous smoothstep tweens. No
# Graphics.update loops are inserted before actions and no automatic MAIN reset
# occurs when menus/animations finish.
#-------------------------------------------------------------------------------
module BSS087SceneCameraAuthority
  def bss087_camera_profile
    cfg = bss070_ebdx_camera_config rescue {}
    raw = (cfg["profile"] || cfg[:profile] || cfg["preset"] || cfg[:preset]).to_s
    return raw if BSS087::CAMERA_PROFILES.key?(raw)
    "source_faithful"
  rescue
    "source_faithful"
  end

  def bss084_context_config(key)
    base = BSS087.context(bss087_camera_profile, key)
    cfg = bss070_ebdx_camera_config rescue {}
    contexts = cfg.is_a?(Hash) ? (cfg["contexts"] || cfg[:contexts]) : nil
    row = contexts.is_a?(Hash) ? (contexts[key.to_s] || contexts[key.to_sym]) : nil
    if row.is_a?(Hash)
      row.each { |k,v| base[k.to_s] = v }
    end
    base["enabled"] = (base["enabled"] == true)
    base["frames"] = [[base["frames"].to_i, 0].max, 120].min
    base["strength"] = BSS087.clamp(base["strength"].nil? ? 100 : base["strength"], 0, 100)
    base
  rescue
    BSS087.context("source_faithful", key)
  end

  def bss087_camera_current
    return nil unless @vector && @vector.respond_to?(:get)
    @vector.get.map { |v| v.to_f }
  rescue
    nil
  end

  def bss087_camera_target_for_context(key, user=nil, targets=nil)
    row = bss084_context_config(key)
    return nil if !row["enabled"]
    mode = row["mode"].to_s
    return nil if ["", "hold", "authored", "drift"].include?(mode)
    shot = bss084_context_shot(key, user, targets) rescue nil
    return nil if !shot
    full = BSS083.camera_shot(shot, @battle) rescue nil
    cur = bss087_camera_current
    return full if !cur || !full
    strength = BSS087.clamp(row["strength"], 0, 100) / 100.0
    6.times.map do |i|
      c = (cur[i] || (i >= 4 ? 1.0 : 0.0)).to_f
      f = (full[i] || c).to_f
      c + ((f - c) * strength)
    end
  rescue
    nil
  end

  def bss087_request_camera_context(key, user=nil, targets=nil)
    return false unless bss083_camera_active? rescue false
    row = bss084_context_config(key)
    target = bss087_camera_target_for_context(key, user, targets)
    return false if !target
    frames = [row["frames"].to_i, 1].max
    from = bss087_camera_current || target.clone
    @bss087_camera_tween = {
      :key => key.to_s,
      :from => from,
      :to => target.map { |v| v.to_f },
      :frame => 0,
      :frames => frames
    }
    @bss083_camera_state = key.to_s.to_sym
    @bss070_ebdx_camera_mode = @bss083_camera_state
    true
  rescue => e
    BSS064.log("BSS087 camera request warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  def bss084_transition_context(key, user=nil, targets=nil)
    bss087_request_camera_context(key, user, targets)
  end

  def bss070_ebdx_camera_enter(mode)
    return super unless bss083_camera_active? rescue false
    key = mode.to_s == "fight" ? "fight" : "command"
    bss087_request_camera_context(key)
    @bss083_camera_state = key.to_sym
    @bss070_ebdx_camera_mode = key.to_sym
    nil
  rescue
    nil
  end

  def bss070_ebdx_camera_leave
    return super unless bss083_camera_active? rescue false
    # Closing a command/fight window is not a camera instruction.
    nil
  rescue
    nil
  end

  # 0.8.5 restored whole battler snapshots after native/PBS moves, which could
  # visibly tick at the final frame. Let the move author its temporary transform;
  # EBDX realigns once after completion without a native/EBDX sandwich.
  def bss083_with_move_projection(user=nil, targets=nil, camera_cut=true)
    return yield unless bss083_camera_active? rescue false
    outer = !@bss087_native_move_active
    if outer
      arr = targets.is_a?(Array) ? targets.compact : (targets ? [targets] : [])
      context = arr.length > 1 ? "spread" : "move"
      bss087_request_camera_context(context, user, arr) if camera_cut
      @bss087_native_move_active = true
      @bss084_native_move_active = true
      @bss083_animation_projection = false
      @bss083_animation_raw = nil
    end
    yield
  ensure
    if outer
      @bss087_native_move_active = false
      @bss084_native_move_active = false
      @bss083_animation_projection = false
      @bss083_animation_raw = nil
      begin
        @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
        bss070_ebdx_apply_world_alignment
      rescue
      end
    end
  end

  def bss070_ebdx_tick(advance_camera=true, align=true)
    tween = @bss087_camera_tween
    if tween && @vector && @bss083_camera_freeze.to_i <= 0 && !@bss087_end_battle_lock
      f = tween[:frame].to_i + 1
      total = [tween[:frames].to_i, 1].max
      t = [[f.to_f / total.to_f, 0.0].max, 1.0].min
      smooth = t * t * (3.0 - (2.0 * t))
      row = 6.times.map do |i|
        a = tween[:from][i].to_f
        b = tween[:to][i].to_f
        a + ((b - a) * smooth)
      end
      @vector.snap(row)
      tween[:frame] = f
      @bss087_camera_tween = nil if f >= total
      ret = super(false, align)
      bss087_apply_end_battle_lock_frame if @bss087_end_battle_lock
      return ret
    end
    idle = bss084_context_config("idle") rescue {"enabled"=>true,"mode"=>"drift"}
    allow_idle = idle["enabled"] == true && idle["mode"].to_s == "drift"
    ret = super(advance_camera && allow_idle, align)
    bss087_apply_end_battle_lock_frame if @bss087_end_battle_lock
    ret
  end

  # During BAS the authored camera remains the only camera authority.
  def bss087_cancel_context_tween!
    @bss087_camera_tween = nil
  end

  # Sendout/recall/SOS use a stable current vector unless the chosen profile
  # explicitly requests a context shot. They never reset to MAIN.
  def pbSendOutBattlers(*args, &block)
    bss087_request_camera_context("sendout")
    super
  end

  def pbRecall(*args, &block)
    bss087_request_camera_context("recall")
    super
  end
end

#-------------------------------------------------------------------------------
# Poké Ball endpoints: trajectory and final Pokémon reveal use the exact same
# already-projected battler endpoint. The target is captured immediately after
# pbChangePokemon has loaded/repositioned the DBK/Essentials battler bitmap.
#-------------------------------------------------------------------------------
module BSS087SendoutTargetCapture
  def pbChangePokemon(idxBattler, pkmn, *args, &block)
    ret = super
    begin
      if @sprites && @sprites["battlebg"].is_a?(BSS070EBDXRoom)
        sp = @sprites["pokemon_#{idxBattler}"]
        if sp
          sp.instance_variable_set(:@bss087_sendout_endpoint, [sp.x.to_f, sp.y.to_f])
        end
      end
    rescue
    end
    ret
  end
end

module BSS087PlayerBallEndpoint
  def createBallTrajectory(ball, delay, duration, startX, startY, midX, midY, endX, endY)
    # The caller already supplies the projected EBDX BASE point while
    # BSS070EBDXCore.position_scene is active. Do not replace it with batSprite.x/y:
    # that is the species-adjusted FINAL anchor used by battlerAppear, not the
    # Poké Ball opening point. Preserve the source-faithful coordinates and let the
    # Gen5 arc below modify only the path.
    super(ball, delay, duration, startX, startY, midX, midY, endX, endY)
  end
end

module BSS087TrainerBallEndpoint
  def createBallTrajectory(ball, destX, destY)
    # TrainerSendOut receives the projected BASE point. The Gen5 trajectory may
    # reshape the arc, but v0.8.14 keeps its final frame exactly on destX/destY.
    # Never substitute the species-adjusted final battler sprite anchor here.
    super(ball, destX, destY)
  end
end

#-------------------------------------------------------------------------------
# Smooth SOS formation. Existing battlers remember their actual on-screen start
# coordinates before side-size/metrics change. The incoming battler is placed at
# its final EBDX anchor while invisible, then revealed. No one-frame pop.
#-------------------------------------------------------------------------------
module BSS087SOSSceneAuthority
  def bss_pbSOSJoin(*args, &block)
    begin
      (@battle.battlers rescue []).each do |b|
        next if !b
        ["pokemon_", "shadow_", "dataBox_"].each do |prefix|
          sp = @sprites["#{prefix}#{b.index}"] rescue nil
          next if !sp
          sp.instance_variable_set(:@bss087_sos_from_xy, [sp.x.to_f, sp.y.to_f])
        end
      end
      @bss083_camera_freeze = @bss083_camera_freeze.to_i + 1
      bss087_request_camera_context("sos") if respond_to?(:bss087_request_camera_context)
    rescue
    end
    super
  ensure
    @bss083_camera_freeze = [@bss083_camera_freeze.to_i - 1, 0].max rescue 0
    begin
      (@sprites || {}).each_value do |sp|
        next if !sp
        sp.remove_instance_variable(:@bss087_sos_from_xy) if sp.instance_variable_defined?(:@bss087_sos_from_xy)
      end
    rescue
    end
  end
end

if defined?(Battle::Scene::Animation::BSSSOSJoin)
  class Battle::Scene::Animation::BSSSOSJoin < Battle::Scene::Animation
    def createProcesses
      duration = 26
      @battle.battlers.each do |b|
        next if !b || b.opposes?(@idx_sos)
        bat = @sprites["pokemon_#{b.index}"]
        sha = @sprites["shadow_#{b.index}"]
        box = @sprites["dataBox_#{b.index}"]
        next if !bat
        side_size = bat.respond_to?(:sideSize) && bat.sideSize ? bat.sideSize : @battle.pbSideSize(b.index)
        nx,ny,nz = bss_sos_battler_position(b, side_size, bat)
        if b.index == @idx_sos
          obj = addSprite(bat, PictureOrigin::BOTTOM)
          obj.setXY(0,nx,ny) if obj.respond_to?(:setXY)
          obj.setZ(0,nz) if obj.respond_to?(:setZ)
          obj.setTone(0,Tone.new(-196,-196,-196,-196))
          obj.setOpacity(0,0); obj.setVisible(0,true)
          obj.moveOpacity(4,14,255)
          obj.moveTone(6,18,Tone.new(0,0,0,0),[bat,:pbPlayIntroAnimation])
          if sha
            sx,sy,sz = bss_sos_shadow_position(b,side_size,sha)
            sh = addSprite(sha,PictureOrigin::CENTER)
            sh.setXY(0,sx,sy) if sh.respond_to?(:setXY)
            sh.setZ(0,sz) if sh.respond_to?(:setZ)
            sh.setOpacity(0,0); sh.setVisible(2,true); sh.moveOpacity(5,14,255)
          end
          if box
            bx = addSprite(box)
            mode = (BSS064.databox_animation_mode rescue "slide")
            case mode
            when "fade"
              bx.setOpacity(0,0); bx.setVisible(6,true); bx.moveOpacity(6,16,255)
            when "pop"
              bx.setOpacity(10,255) if bx.respond_to?(:setOpacity); bx.setVisible(10,true)
            else
              dir = b.index.even? ? 1 : -1
              bx.setOpacity(0,255) if bx.respond_to?(:setOpacity)
              bx.setDelta(0,dir*Graphics.width/2,0); bx.setVisible(4,true)
              bx.moveDelta(4,22,-dir*Graphics.width/2,0)
            end
          end
        else
          from = bat.instance_variable_get(:@bss087_sos_from_xy) rescue nil
          from = [bat.x.to_f,bat.y.to_f] if !from.is_a?(Array)
          obj = addSprite(bat,PictureOrigin::BOTTOM)
          obj.setXY(0,from[0],from[1]) if obj.respond_to?(:setXY)
          obj.setZ(0,nz) if obj.respond_to?(:setZ)
          obj.moveXY(0,duration,nx,ny)
          if sha
            sfrom = sha.instance_variable_get(:@bss087_sos_from_xy) rescue nil
            sfrom = [sha.x.to_f,sha.y.to_f] if !sfrom.is_a?(Array)
            sx,sy,sz = bss_sos_shadow_position(b,side_size,sha)
            sh = addSprite(sha,PictureOrigin::CENTER)
            sh.setXY(0,sfrom[0],sfrom[1]) if sh.respond_to?(:setXY)
            sh.setZ(0,sz) if sh.respond_to?(:setZ)
            sh.moveXY(0,duration,sx,sy)
          end
          if box
            bfrom = box.instance_variable_get(:@bss087_sos_from_xy) rescue nil
            to = box.instance_variable_get(:@bss656_reflow_to_xy) rescue nil
            if bfrom.is_a?(Array) && to.is_a?(Array)
              bx = addSprite(box); bx.setXY(0,bfrom[0],bfrom[1]); bx.moveXY(0,duration,to[0],to[1])
            end
            box.instance_variable_set(:@bss656_reflow_from_xy,nil) rescue nil
            box.instance_variable_set(:@bss656_reflow_to_xy,nil) rescue nil
          end
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Atomic capture filter: one scene overlay, not independent color writes on each
# background element. This removes staggered pops and guarantees cleanup.
#-------------------------------------------------------------------------------
module BSS087CaptureFilterAuthority
  def bss087_capture_filter_z
    zs = []
    (@sprites || {}).each do |k,sp|
      next if !sp || !sp.respond_to?(:z)
      name = k.to_s.downcase
      zs << sp.z.to_i if name.include?("databox") || name.include?("battlebox") || name.include?("command") || name.include?("fight")
    end
    base = zs.empty? ? 200 : zs.min
    [base - 2, 45].max
  rescue
    198
  end

  def bss087_capture_filter_overlay
    sp = @sprites && @sprites["bss087CaptureFilter"]
    return sp if sp && !(sp.disposed? rescue false)
    return nil if !@viewport
    sp = Sprite.new(@viewport)
    sp.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    sp.bitmap.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(0,0,0))
    sp.x=0; sp.y=0; sp.ox=0; sp.oy=0; sp.opacity=0; sp.visible=false
    @sprites["bss087CaptureFilter"] = sp if @sprites
    sp
  rescue
    nil
  end

  def bss087_set_capture_filter(active)
    @bss087_capture_filter_active = (active == true)
    sp = bss087_capture_filter_overlay
    if sp
      sp.z = bss087_capture_filter_z
      sp.opacity = @bss087_capture_filter_active ? 112 : 0
      sp.visible = @bss087_capture_filter_active
    end
    @bss085_capture_filter_active = @bss087_capture_filter_active
    @bss653_boss_capture_visuals_locked = @bss087_capture_filter_active if instance_variable_defined?(:@bss653_boss_capture_visuals_locked)
    true
  rescue
    false
  end

  def bss081_sync_background_filter
    capture = (@bss087_capture_filter_active == true) || (@bss085_capture_filter_active == true)
    if capture
      bss087_set_capture_filter(true)
      return true
    end
    bss087_set_capture_filter(false)
    super
  rescue
    true
  end

  def pbRevertBattlerStart(*args,&block)
    ret = super
    # Lower Boss/DBK code marks capture visuals active around this lifecycle.
    bss087_set_capture_filter(true) if @bss085_capture_filter_active == true || @bss653_boss_capture_visuals_locked == true
    ret
  end

  def pbRevertBattlerEnd(*args,&block)
    ret = super
    bss087_set_capture_filter(false)
    ret
  ensure
    bss087_set_capture_filter(false)
  end

  def pbHideCaptureBall(*args,&block)
    ret = super
    bss087_set_capture_filter(false)
    ret
  ensure
    bss087_set_capture_filter(false)
  end

  def pbThrowPokeBall(*args,&block)
    ret = super
    bss087_set_capture_filter(false)
    ret
  ensure
    bss087_set_capture_filter(false)
  end

  def pbThrowAndDeflect(*args,&block)
    ret = super
    bss087_set_capture_filter(false)
    ret
  ensure
    bss087_set_capture_filter(false)
  end
end

#-------------------------------------------------------------------------------
# Enhanced Battle UI owns visibility. BSS only guarantees that it is above the
# BattleBox and refreshes prompt/info state immediately when Enhanced changes it.
#-------------------------------------------------------------------------------
module BSS087EnhancedUIAuthority
  def bss087_enhanced_base_z
    z = 300
    (@sprites || {}).each do |k,sp|
      next if !sp || !sp.respond_to?(:z)
      n = k.to_s.downcase
      next if n.include?("enhanced") || n.include?("outline") || n.include?("info_icon") || n.include?("ball_icon") || n == "bss087capturefilter"
      if n.include?("databox") || n.include?("battlebox") || n.include?("command") || n.include?("fight") || n.include?("messagebox") || n.include?("cmdbar")
        z = [z, sp.z.to_i + 20].max
      end
    end
    z
  rescue
    500
  end

  def bss087_enhanced_context_window
    cw = @sprites && @sprites["commandWindow"]
    fw = @sprites && @sprites["fightWindow"]
    return Battle::Scene::FIGHT_BOX if fw && (fw.visible rescue false)
    return Battle::Scene::COMMAND_BOX if cw && (cw.visible rescue false)
    nil
  rescue
    nil
  end

  def bss087_enforce_enhanced_ui_z
    return unless @sprites
    base = bss087_enhanced_base_z
    ui = @sprites["enhancedUI"]; ui.z = base if ui && ui.respond_to?(:z=)
    p = @sprites["enhancedUIPrompts"]; p.z = base + 20 if p && p.respond_to?(:z=)
    ["leftArrow","rightArrow"].each { |k| s=@sprites[k]; s.z=base+30 if s && s.respond_to?(:z=) }
    @sprites.each do |k,s|
      next if !s || !s.respond_to?(:z=)
      n=k.to_s
      if n =~ /Outline_\d+/i
        s.z=base+40
      elsif n =~ /^(info_icon|ball_icon)\d+/i
        s.z=base+41
      end
    end
    true
  rescue
    false
  end

  def bss087_refresh_enhanced_now
    return unless @sprites
    bss087_enforce_enhanced_ui_z
    prompt=@sprites["enhancedUIPrompts"]
    win=bss087_enhanced_context_window
    if prompt
      if win.nil? || (@enhancedUIToggle rescue nil)
        prompt.visible=false if prompt.respond_to?(:visible=)
      else
        begin
          prompt.window=win if prompt.respond_to?(:window=)
          idx=nil
          src=(win==Battle::Scene::FIGHT_BOX ? @sprites["fightWindow"] : @sprites["commandWindow"])
          idx=src.index if src && src.respond_to?(:index)
          prompt.battler=idx if !idx.nil? && prompt.respond_to?(:battler=)
          prompt.refresh if prompt.respond_to?(:refresh)
          prompt.visible=true if prompt.respond_to?(:visible=)
        rescue
        end
      end
    end
    true
  rescue
    false
  end

  def pbShowWindow(windowType,*args,&block)
    ret=super
    bss087_refresh_enhanced_now
    ret
  end

  def pbRefreshUIPrompt(*args,&block)
    ret=super
    bss087_refresh_enhanced_now
    ret
  end

  def pbUpdateInfoSprites(*args,&block)
    ret=super
    bss087_refresh_enhanced_now
    ret
  end

  def pbToggleMoveInfo(*args,&block)
    ret=super
    begin; pbUpdateMoveInfoWindow(*args) if (@enhancedUIToggle rescue nil)==:move && respond_to?(:pbUpdateMoveInfoWindow); rescue; end
    bss087_refresh_enhanced_now
    ret
  end

  def pbToggleBattleInfo(*args,&block)
    ret=super
    begin; pbUpdateBattlerInfo if (@enhancedUIToggle rescue nil)==:battler && respond_to?(:pbUpdateBattlerInfo); rescue; end
    bss087_refresh_enhanced_now
    ret
  end

  def pbToggleBallInfo(*args,&block)
    ret=super
    begin; pbUpdateBallInfo if (@enhancedUIToggle rescue nil)==:ball && respond_to?(:pbUpdateBallInfo); rescue; end
    bss087_refresh_enhanced_now
    ret
  end

  def pbOpenBattlerInfo(*args,&block)
    ret=super
    bss087_refresh_enhanced_now
    ret
  end

  def pbSetWithOutline(*args,&block)
    ret=super
    bss087_enforce_enhanced_ui_z
    ret
  end

  def pbShowOutline(*args,&block)
    ret=super
    bss087_enforce_enhanced_ui_z
    ret
  end

  def pbAddSpriteOutline(*args,&block)
    ret=super
    bss087_enforce_enhanced_ui_z
    ret
  end

  def pbUpdate(*args,&block)
    ret=super
    bss087_refresh_enhanced_now
    bss087_apply_end_battle_lock_frame if @bss087_end_battle_lock
    ret
  end
end

#-------------------------------------------------------------------------------
# End-battle visual lock. Keep the last EBDX battler pose and camera until the
# scene fade/cleanup has finished; internal Vanilla restoration stays invisible.
#-------------------------------------------------------------------------------
module BSS087EndBattleSceneLock
  def bss087_begin_end_battle_lock
    return if @bss087_end_battle_lock
    @bss087_end_battle_lock = true
    @bss087_end_battle_visuals = {}
    (@sprites || {}).each do |k,sp|
      next if !sp
      n=k.to_s
      next unless n.start_with?("pokemon_") || n.start_with?("shadow_")
      begin
        @bss087_end_battle_visuals[k] = [sp.x,sp.y,sp.z,sp.zoom_x,sp.zoom_y,sp.ox,sp.oy,sp.visible,sp.opacity]
      rescue
      end
    end
    @bss087_end_battle_camera = bss087_camera_current if respond_to?(:bss087_camera_current)
    @bss083_camera_freeze = @bss083_camera_freeze.to_i + 1
    @bss087_camera_tween = nil
    true
  end

  def bss087_apply_end_battle_lock_frame
    return unless @bss087_end_battle_lock
    (@bss087_end_battle_visuals || {}).each do |k,row|
      sp=@sprites[k] rescue nil; next if !sp || (sp.disposed? rescue false)
      begin
        sp.x=row[0];sp.y=row[1];sp.z=row[2];sp.zoom_x=row[3];sp.zoom_y=row[4];sp.ox=row[5];sp.oy=row[6];sp.visible=row[7];sp.opacity=row[8]
      rescue
      end
    end
    @vector.snap(@bss087_end_battle_camera) if @vector && @bss087_end_battle_camera
    true
  rescue
    false
  end

  def bss087_finish_end_battle_lock
    @bss087_end_battle_lock=false
    @bss087_end_battle_visuals=nil
    @bss087_end_battle_camera=nil
    @bss083_camera_freeze=[@bss083_camera_freeze.to_i-1,0].max
    bss087_set_capture_filter(false) if respond_to?(:bss087_set_capture_filter)
    true
  rescue
    true
  end

  def pbEndBattle(*args,&block)
    bss087_begin_end_battle_lock
    super
  ensure
    bss087_finish_end_battle_lock
  end
end

module BSS087BattleEndAuthority
  def pbEndOfBattle(*args,&block)
    begin
      @scene.bss087_begin_end_battle_lock if @scene && @scene.respond_to?(:bss087_begin_end_battle_lock)
    rescue
    end
    super
  ensure
    begin
      @scene.bss087_set_capture_filter(false) if @scene && @scene.respond_to?(:bss087_set_capture_filter)
    rescue
    end
  end
end

#-------------------------------------------------------------------------------
# Install final authority after all older compatibility layers.
#-------------------------------------------------------------------------------
begin
  class << BSS070EBDXCore; prepend BSS087SceneDataAuthority unless ancestors.include?(BSS087SceneDataAuthority); end if defined?(BSS070EBDXCore)
rescue => e
  BSS064.log("BSS087 data install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle::Scene.prepend(BSS087SceneCameraAuthority) unless Battle::Scene.ancestors.include?(BSS087SceneCameraAuthority)
  Battle::Scene.prepend(BSS087SendoutTargetCapture) unless Battle::Scene.ancestors.include?(BSS087SendoutTargetCapture)
  Battle::Scene.prepend(BSS087SOSSceneAuthority) unless Battle::Scene.ancestors.include?(BSS087SOSSceneAuthority)
  Battle::Scene.prepend(BSS087CaptureFilterAuthority) unless Battle::Scene.ancestors.include?(BSS087CaptureFilterAuthority)
  Battle::Scene.prepend(BSS087EnhancedUIAuthority) unless Battle::Scene.ancestors.include?(BSS087EnhancedUIAuthority)
  Battle::Scene.prepend(BSS087EndBattleSceneLock) unless Battle::Scene.ancestors.include?(BSS087EndBattleSceneLock)
rescue => e
  BSS064.log("BSS087 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  mix=Battle::Scene::Animation::BallAnimationMixin
  mix.prepend(BSS087PlayerBallEndpoint) unless mix.ancestors.include?(BSS087PlayerBallEndpoint)
rescue => e
  BSS064.log("BSS087 player ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  k=Battle::Scene::Animation::PokeballTrainerSendOut
  k.prepend(BSS087TrainerBallEndpoint) unless k.ancestors.include?(BSS087TrainerBallEndpoint)
rescue => e
  BSS064.log("BSS087 trainer ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle.prepend(BSS087BattleEndAuthority) unless Battle.ancestors.include?(BSS087BattleEndAuthority)
rescue => e
  BSS064.log("BSS087 battle install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# Final prompt-context guard: visibility alone is insufficient because DBK can
# leave the previous command/fight window visible behind another scene window.
module BSS087EnhancedWindowContextGuard
  def pbShowWindow(windowType,*args,&block)
    @bss087_active_window_type = windowType
    ret = super
    bss087_refresh_enhanced_now if respond_to?(:bss087_refresh_enhanced_now)
    ret
  end

  def bss087_enhanced_context_window
    type = @bss087_active_window_type
    return nil unless [Battle::Scene::COMMAND_BOX, Battle::Scene::FIGHT_BOX].include?(type) rescue false
    type
  rescue
    nil
  end
end
begin
  Battle::Scene.prepend(BSS087EnhancedWindowContextGuard) unless Battle::Scene.ancestors.include?(BSS087EnhancedWindowContextGuard)
rescue => e
  BSS064.log("BSS087 enhanced window guard warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
