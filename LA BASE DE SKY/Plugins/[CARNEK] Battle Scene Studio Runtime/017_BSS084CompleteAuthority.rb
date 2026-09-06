#===============================================================================
# Battle Scene Studio v0.8.4
# Final authority pass: contextual EBDX camera, stable native/PBS moves,
# smooth SOS insertion, standalone Wild NDS reveal, Enhanced UI ownership,
# room-wide filters, extended world coverage and accumulated Boss EXP.
#===============================================================================
module BSS084
  VERSION = "0.8.4"
  module_function

  CONTEXT_DEFAULTS = {
    "command"  => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "fight"    => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "move"     => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "spread"   => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "common"   => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "sendout"  => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "recall"   => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "sos"      => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "capture"  => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "faint"    => { "enabled" => false, "mode" => "hold",    "frames" => 0  },
    "turn_end" => { "enabled" => false, "mode" => "neutral", "frames" => 10 },
    "idle"     => { "enabled" => true,  "mode" => "drift",   "frames" => 0  },
    "bas"      => { "enabled" => true,  "mode" => "authored","frames" => 0  }
  }

  def merge_context(raw, key)
    base = CONTEXT_DEFAULTS[key.to_s] || { "enabled" => false, "mode" => "hold", "frames" => 0 }
    row = raw.is_a?(Hash) ? (raw[key.to_s] || raw[key.to_sym]) : nil
    row = {} unless row.is_a?(Hash)
    out = base.merge(row)
    out["enabled"] = out["enabled"] == true
    out["mode"] = out["mode"].to_s
    out["frames"] = [[out["frames"].to_i, 0].max, 60].min
    out
  end
end

#-------------------------------------------------------------------------------
# Larger safety/world surface. Authored pixels are never horizontally stretched;
# the original world is repeated/continued outside the logical center so camera
# pans and zoom-outs cannot expose a hard bitmap edge at 640x480/640x408.
#-------------------------------------------------------------------------------
module BSS084WideRoom
  def bss078_extend_room_bitmap!
    bg = @sprites && @sprites["bg"]
    return if !bg || !bg.bitmap || (bg.bitmap.disposed? rescue false)
    return if bg.instance_variable_get(:@bss084_overscanned)
    src = bg.bitmap
    px = [(@viewport.width * 2.05).to_i, 1280].max
    pt = [(@viewport.height * 1.05).to_i, 480].max
    pb = [(@viewport.height * 1.40).to_i, 680].max
    dst = Bitmap.new(src.width + px * 2, src.height + pt + pb)

    top = src.get_pixel([[src.width / 2, 0].max, src.width - 1].min, 0)
    bottom = src.get_pixel([[src.width / 2, 0].max, src.width - 1].min, src.height - 1)
    dst.fill_rect(0, 0, dst.width, pt, top)
    dst.fill_rect(0, pt + src.height, dst.width, pb, bottom)
    dst.blt(px, pt, src, src.rect)

    # Continue authored scenery with broad, alternating strips. This preserves the
    # original pixel scale and is less visibly repetitive than one cloned edge.
    band = [[src.width / 3, 96].max, src.width].min
    x = px
    n = 0
    while x > 0
      w = [band, x].min
      sx = ((n * band) % [src.width, 1].max)
      sx = [sx, src.width - w].min
      x -= w
      dst.blt(x, pt, src, Rect.new([sx, 0].max, 0, w, src.height))
      n += 1
    end
    x = px + src.width
    n = 0
    while x < dst.width
      w = [band, dst.width - x].min
      sx = src.width - (((n + 1) * band) % [src.width, 1].max)
      sx = 0 if sx < 0
      sx = [sx, src.width - w].min
      dst.blt(x, pt, src, Rect.new([sx, 0].max, 0, w, src.height))
      x += w
      n += 1
    end

    old_ox = bg.ox.to_f
    old_oy = bg.oy.to_f
    bg.bitmap = dst
    bg.ox = old_ox + px
    bg.oy = old_oy + pt
    bg.instance_variable_set(:@bss078_overscanned, true)
    bg.instance_variable_set(:@bss083_wide_world, true)
    bg.instance_variable_set(:@bss084_overscanned, true)
    @bss078_pad_x = px
    @bss078_pad_y = pt

    @sprites.each do |key, sp|
      next if !sp || key == "bg" || key == "void"
      begin
        sp.ex = sp.ex.to_f + px if sp.respond_to?(:ex) && sp.respond_to?(:ex=) && !sp.ex.nil?
        sp.ey = sp.ey.to_f + pt if sp.respond_to?(:ey) && sp.respond_to?(:ey=) && !sp.ey.nil?
        # Environment/custom art can never jump above battlers. Its own authored
        # ordering is preserved inside the scenery band.
        sp.z = [[sp.z.to_i, -500].max, 40].min if sp.respond_to?(:z) && sp.respond_to?(:z=)
      rescue
      end
    end
    begin; src.dispose if src && !(src.disposed? rescue true); rescue; end
  rescue => e
    BSS064.log("BSS084 wide room warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end
end

#-------------------------------------------------------------------------------
# Scene authority.
#-------------------------------------------------------------------------------
module BSS084SceneAuthority
  def bss084_context_config(key)
    cfg = respond_to?(:bss070_ebdx_camera_config) ? (bss070_ebdx_camera_config rescue {}) : {}
    raw = cfg.is_a?(Hash) ? (cfg["contexts"] || cfg[:contexts]) : nil
    BSS084.merge_context(raw, key)
  rescue
    BSS084.merge_context(nil, key)
  end

  def bss084_context_shot(key, user=nil, targets=nil)
    row = bss084_context_config(key)
    mode = row["mode"].to_s
    return nil if !row["enabled"] || mode == "hold" || mode == "authored" || mode == "drift"
    case mode
    when "neutral", "main" then :main
    when "wide"            then :wide
    when "player"          then :player
    when "enemy"           then :enemy
    when "impact"          then :impact
    when "focus"
      arr = targets.is_a?(Array) ? targets.compact : (targets ? [targets] : [])
      return :wide if arr.length > 1
      focus = arr[0] || user
      idx = focus.respond_to?(:index) ? focus.index.to_i : (focus.is_a?(Numeric) ? focus.to_i : nil)
      return :impact if idx.nil?
      idx.even? ? :player : :enemy
    else
      nil
    end
  rescue
    nil
  end

  def bss084_transition_context(key, user=nil, targets=nil)
    return unless bss083_camera_active? rescue false
    row = bss084_context_config(key)
    shot = bss084_context_shot(key, user, targets)
    return if !shot
    frames = row["frames"].to_i
    @bss083_camera_state = key.to_s.to_sym
    @bss070_ebdx_camera_mode = @bss083_camera_state
    @vector.inc = frames > 0 ? [1.0 / frames.to_f, 0.012].max : 1.0
    @vector.set(BSS083.camera_shot(shot, @battle))
    # Explicit pre-action transition. The move itself never reprojects battlers,
    # avoiding the one-frame position/scale ticks of the old transform sandwich.
    frames.times do
      break if @vector.finished?
      @vector.update
      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment
      bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
      Graphics.update
      Input.update if defined?(Input) && Input.respond_to?(:update)
    end
  rescue => e
    BSS064.log("BSS084 camera transition warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  # No automatic MAIN reset. Contexts replace each other; idle only drifts after
  # the normal EBDX delay. This removes the "camera restarts at the slightest thing"
  # behavior from 0.8.3.
  def bss083_settle_camera
    return unless bss083_camera_active? rescue false
    @bss083_camera_state = :idle
    @bss070_ebdx_camera_mode = :idle
    @bss083_idle_due ||= BSS070EBDXCore::BATTLE_MOTION_TIMER.to_i * BSS070EBDXCore.frame_rate.to_i
  rescue
  end

  def bss070_ebdx_camera_enter(mode)
    return super unless bss083_camera_active? rescue false
    key = mode.to_s == "fight" ? "fight" : "command"
    row = bss084_context_config(key)
    shot = bss084_context_shot(key)
    if row["enabled"] && shot
      @vector.inc = [1.0 / [row["frames"].to_i, 1].max, 0.012].max
      @vector.set(BSS083.camera_shot(shot, @battle))
    end
    @bss083_camera_state = key.to_sym
    @bss070_ebdx_camera_mode = key.to_sym
    nil
  rescue
    nil
  end

  def bss070_ebdx_camera_leave
    return super unless bss083_camera_active? rescue false
    # Leaving a menu is not a camera event.
    @bss083_camera_state = :idle if [:command, :fight].include?((@bss083_camera_state rescue nil))
    @bss070_ebdx_camera_mode = :idle if [:command, :fight].include?((@bss070_ebdx_camera_mode rescue nil))
    nil
  rescue
    nil
  end

  # Native/PBS moves now operate directly on the currently projected EBDX
  # battlers. The room/camera is frozen for those authored transforms, then one
  # clean alignment is applied at the end. No native -> EBDX -> native sandwich.
  def bss083_with_move_projection(user=nil, targets=nil, camera_cut=true)
    return yield unless bss083_camera_active? rescue false
    outer = !@bss084_native_move_active
    if outer
      arr = targets.is_a?(Array) ? targets.compact : (targets ? [targets] : [])
      context = arr.length > 1 ? "spread" : "move"
      bss084_transition_context(context, user, arr) if camera_cut
      @bss084_native_move_active = true
      @bss083_animation_projection = false
      @bss083_animation_raw = nil
      @bss083_camera_freeze = @bss083_camera_freeze.to_i + 1
    end
    yield
  ensure
    if outer
      @bss083_camera_freeze = [@bss083_camera_freeze.to_i - 1, 0].max
      @bss084_native_move_active = false
      @bss083_animation_projection = false
      @bss083_animation_raw = nil
      begin
        @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
        bss070_ebdx_apply_world_alignment
        bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
      rescue
      end
      @bss083_camera_state = :action_hold if camera_cut
    end
  end

  # Lower 0.7/0.8 wrappers normally suspend and restore the camera around every
  # native animation. While v0.8.4 owns a move, bypass that lower restore path.
  def bss070_ebdx_suspend_world(*args, &block)
    return yield if @bss084_native_move_active
    super
  end

  def bss070_ebdx_tick(advance_camera=true, align=true)
    if @bss084_native_move_active
      bss070_ebdx_hide_native_backdrops if respond_to?(:bss070_ebdx_hide_native_backdrops)
      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
      return
    end
    idle_cfg = bss084_context_config("idle") rescue { "enabled" => true, "mode" => "drift" }
    if (@bss083_camera_state || :idle).to_sym == :idle && (!idle_cfg["enabled"] || idle_cfg["mode"].to_s != "drift")
      @bss083_camera_state = :hold
      @bss070_ebdx_camera_mode = :hold
    end
    ret = super
    # Filters are final-room state, not a one-off copy. EBDX elements, custom
    # img### layers, weather/lights and canvas layers therefore remain under the
    # same capture/darken filter even if their own update changed color/tone.
    bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
    ret
  end

  # Optional camera contexts around scene lifecycles. Defaults preserve the
  # current plane for sendout/recall/common; users can opt into authored cuts.
  def pbSendOutBattlers(*args, &block)
    bss084_transition_context("sendout") if (bss083_camera_active? rescue false)
    super
  end

  def pbRecall(*args, &block)
    bss084_transition_context("recall") if (bss083_camera_active? rescue false)
    super
  end

  def pbCommonAnimation(anim_name, user=nil, target=nil, *args, &block)
    if (bss083_camera_active? rescue false) && bss084_context_config("common")["enabled"]
      bss084_transition_context("common", user, target ? [target] : [])
    end
    super
  end

  # Contextual SOS shot, then the existing camera freeze owns the ball/entry.
  def bss_pbSOSJoin(*args, &block)
    bss084_transition_context("sos") if (bss083_camera_active? rescue false)
    super
  end

  # Capture can use an enemy-focus shot without resetting afterward.
  [:pbThrow, :pbThrowAndDeflect, :pbThrowPokeBall].each do |meth|
    define_method(meth) do |*args, &block|
      bss084_transition_context("capture") if (bss083_camera_active? rescue false)
      super(*args, &block)
    end
  end

  # Enhanced Battle UI owns its own Z and visibility. Previous BSS guard code
  # overrode valid plugin state and caused slots/outlines to flicker/disappear.
  def bss080_enforce_enhanced_ui_z; end
  def bss083_enhanced_ui_guard; end

  def bss078_cinematic_ui_restore(state)
    return if !state.is_a?(Hash) || !@sprites.is_a?(Hash)
    state.each do |key, vis|
      sp = @sprites[key] rescue nil
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible=)
      begin; sp.visible = vis; rescue; end
    end
  end

  def pbUpdate(*args, &block)
    ret = super
    bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
    ret
  end

  if instance_methods.include?(:pbFrameUpdate)
    def pbFrameUpdate(*args, &block)
      ret = super
      bss081_sync_background_filter if respond_to?(:bss081_sync_background_filter)
      ret
    end
  end

  # Snapshot only the live authored world. Explicitly hide every native backdrop
  # and base alias (battle_bg/battle_bg2/base_0/base_1), fixing the Vanilla flash.
  def bss083_nds_world_snapshot(foes)
    return nil if !defined?(Graphics) || !Graphics.respond_to?(:snap_to_bitmap)
    hidden = []
    (@sprites || {}).each do |key, sp|
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible)
      k = key.to_s
      next if k == "battlebg" # EBDX room object
      should_hide = (k =~ /^(battle_bg|battle_bg2|base_\d+|pokemon_|shadow_|dataBox_|trainer_|party|cmdBar|command|fight|target|message|enhanced|info_icon|ball_icon|leftarrow|rightarrow|boss|ability|itemWindow)/i) || (k =~ /_outline\d+$/i)
      next unless should_hide
      begin
        hidden << [sp, sp.visible]
        sp.visible = false if sp.respond_to?(:visible=)
      rescue
      end
    end
    Graphics.snap_to_bitmap
  ensure
    hidden.each do |sp, vis|
      begin; sp.visible = vis if sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible=); rescue; end
    end if hidden
  end

  # Full standalone NDS reveal. It never modifies the EBDX vector/Room and it
  # restores every live UI sprite to its exact previous visibility afterward.
  def bss083_run_standalone_wild_nds
    foes = bss083_nds_foe_rows
    return false if foes.empty?
    snap = bss083_nds_world_snapshot(foes)
    return false if !snap

    cfg0 = respond_to?(:bss079_intro_config) ? (bss079_intro_config rescue {}) : {}
    cfg0 = {} unless cfg0.is_a?(Hash)
    hold_frames = [[(cfg0["holdFrames"] || 16).to_i, 0].max, 120].min
    move_frames = [[(cfg0["moveFrames"] || 28).to_i, 8].max, 180].min
    reveal_frames = [[(cfg0["revealFrames"] || 10).to_i, 4].max, move_frames].min
    fade_frames = [[(cfg0["fadeFrames"] || 14).to_i, 4].max, 60].min
    zoom_start = [[(cfg0["zoomStart"] || 185).to_f / 100.0, 1.0].max, 2.4].min

    visibility = {}
    (@sprites || {}).each do |key, sp|
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible)
      visibility[key] = sp.visible rescue nil
    end
    @bss083_standalone_intro = true

    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 999_000 if vp.respond_to?(:z=)
    temp = []
    begin
      # Hide live combat objects; the isolated viewport owns the reveal.
      (@sprites || {}).each do |key, sp|
        next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible=)
        next if key.to_s == "battlebg"
        begin; sp.visible = false; rescue; end
      end

      cx = Graphics.width / 2.0
      cy = Graphics.height / 2.0
      first = foes[0][1]
      focus_x = (first.x rescue Graphics.width * 0.72).to_f
      focus_y = (first.y rescue Graphics.height * 0.40).to_f

      bg = Sprite.new(vp); bg.bitmap = snap
      bg.ox = snap.width / 2; bg.oy = snap.height / 2
      bg.x = cx + (cx - focus_x) * zoom_start
      bg.y = cy + (cy - focus_y) * zoom_start
      bg.zoom_x = zoom_start; bg.zoom_y = zoom_start; bg.z = 0
      temp << bg

      foe_temp = []
      foes.each_with_index do |row, i|
        idx, src, _sh = row
        cp = bss083_nds_copy_sprite(src, vp, 100 + i)
        next if !cp
        ex = src.x.to_f; ey = src.y.to_f
        cp.x = cx + (ex - focus_x) * zoom_start
        cp.y = cy + (ey - focus_y) * zoom_start
        cp.zoom_x = src.zoom_x.to_f * zoom_start
        cp.zoom_y = src.zoom_y.to_f * zoom_start
        cp.opacity = 0
        cp.tone = Tone.new(0,0,0,0) if cp.respond_to?(:tone=)
        foe_temp << [idx, src, cp, ex, ey, src.zoom_x.to_f, src.zoom_y.to_f]
        temp << cp
      end

      intro_cfg = bss083_nds_intro_config
      intro = nil
      visual = intro_cfg[:visual] || intro_cfg["visual"]
      if visual && (pbResolveBitmap(visual) rescue false)
        intro = Sprite.new(vp); intro.bitmap = pbBitmap(visual)
        scale = [Graphics.width.to_f/[intro.bitmap.width,1].max, Graphics.height.to_f/[intro.bitmap.height,1].max].max
        intro.zoom_x=scale; intro.zoom_y=scale; intro.x=0; intro.y=0; intro.z=800; intro.opacity=255
        temp << intro
      end
      bss083_nds_play_se(intro_cfg[:se] || intro_cfg["se"])
      drift = intro_cfg[:drift] || intro_cfg["drift"] || [(cfg0["driftX"] || -7), (cfg0["driftY"] || 3)]
      dx = drift[0].to_f; dy = drift[1].to_f

      black = Sprite.new(vp); black.bitmap = Bitmap.new(1,1); black.bitmap.fill_rect(0,0,1,1,Color.new(0,0,0)); black.zoom_x=Graphics.width; black.zoom_y=Graphics.height; black.opacity=255; black.z=1000; temp << black
      white = Sprite.new(vp); white.bitmap = Bitmap.new(1,1); white.bitmap.fill_rect(0,0,1,1,Color.new(255,255,255)); white.zoom_x=Graphics.width; white.zoom_y=Graphics.height; white.opacity=0; white.z=950; temp << white

      total = hold_frames + move_frames
      cried = false
      total.times do |f|
        black.opacity = f < fade_frames ? (255 * (1.0 - (f+1).to_f/fade_frames)).round : 0
        if intro
          intro.x += dx / [hold_frames + move_frames,1].max
          intro.y += dy / [hold_frames + move_frames,1].max
          if f >= hold_frames
            p = (f-hold_frames+1).to_f/move_frames
            intro.opacity = (255 * (1.0-[p/0.72,1.0].min)).round
          end
        end
        if f >= hold_frames
          local = f-hold_frames+1
          t = [local.to_f/move_frames,1.0].min
          ease = t*t*(3.0-2.0*t)
          start_x = cx + (cx-focus_x)*zoom_start
          start_y = cy + (cy-focus_y)*zoom_start
          bg.x = start_x + (cx-start_x)*ease
          bg.y = start_y + (cy-start_y)*ease
          z = zoom_start + (1.0-zoom_start)*ease
          bg.zoom_x=z; bg.zoom_y=z
          foe_temp.each do |idx,src,cp,ex,ey,ezx,ezy|
            sx = cx + (ex-focus_x)*zoom_start; sy = cy + (ey-focus_y)*zoom_start
            cp.x=sx+(ex-sx)*ease; cp.y=sy+(ey-sy)*ease
            cp.zoom_x=ezx*z; cp.zoom_y=ezy*z
            rp=[local.to_f/reveal_frames,1.0].min
            cp.opacity=(255*(rp*rp*(3.0-2.0*rp))).round
          end
          if !cried && local >= [reveal_frames/3,1].max
            bss083_nds_play_cry(foe_temp[0][0]) if foe_temp[0]
            cried=true
          end
          flash = (cfg0["flash"] || 150).to_i
          if local <= 3
            white.opacity=(flash*local/3.0).round
          elsif local <= 11
            white.opacity=(flash*(1.0-(local-3).to_f/8.0)).round
          else
            white.opacity=0
          end
        end
        Graphics.update
        Input.update if defined?(Input) && Input.respond_to?(:update)
      end

      foes.each do |_idx, src, _sh|
        begin
          src.opacity=255 if src.respond_to?(:opacity=)
          src.tone=Tone.new(0,0,0,0) if src.respond_to?(:tone=)
        rescue
        end
      end
      true
    ensure
      temp.reverse_each do |sp|
        begin
          if sp && sp.bitmap && sp.bitmap.width==1 && sp.bitmap.height==1
            sp.bitmap.dispose unless sp.bitmap.disposed? rescue nil
          end
          sp.dispose if sp && !(sp.disposed? rescue true)
        rescue
        end
      end
      begin; snap.dispose if snap && !(snap.disposed? rescue true); rescue; end
      begin; vp.dispose if vp && !(vp.disposed? rescue true); rescue; end
      visibility.each do |key, vis|
        sp=@sprites[key] rescue nil
        next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible=) || vis.nil?
        begin; sp.visible=vis; rescue; end
      end
      foes.each do |_idx,src,_sh|
        begin; src.visible=true if src && src.respond_to?(:visible=); rescue; end
      end
      @bss083_standalone_intro=false
    end
  rescue => e
    @bss083_standalone_intro=false
    BSS064.log("BSS084 standalone Wild NDS warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end
end

#-------------------------------------------------------------------------------
# Smooth SOS formation expansion. Incoming sprites are positioned before their
# first visible frame; existing battlers reflow together over 12 frames.
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::BSSSOSJoin < Battle::Scene::Animation
  def createProcesses
    duration = 12
    @battle.battlers.each do |b|
      next if !b || b.opposes?(@idx_sos)
      bat = @sprites["pokemon_#{b.index}"]
      sha = @sprites["shadow_#{b.index}"]
      boxsp = @sprites["dataBox_#{b.index}"]
      next if !bat
      side_size = bat.respond_to?(:sideSize) && bat.sideSize ? bat.sideSize : @battle.pbSideSize(b.index)
      nx, ny, nz = bss_sos_battler_position(b, side_size, bat)
      if b.index == @idx_sos
        obj = addSprite(bat, PictureOrigin::BOTTOM)
        obj.setXY(0, nx, ny) if obj.respond_to?(:setXY)
        obj.setZ(0, nz) if obj.respond_to?(:setZ)
        obj.setTone(0, Tone.new(-196,-196,-196,-196))
        obj.setOpacity(0,0); obj.setVisible(0,true)
        obj.moveOpacity(0,8,255)
        obj.moveTone(4,12,Tone.new(0,0,0,0),[bat,:pbPlayIntroAnimation])
        if sha
          sx,sy,sz=bss_sos_shadow_position(b,side_size,sha)
          sh=addSprite(sha,PictureOrigin::CENTER)
          sh.setXY(0,sx,sy) if sh.respond_to?(:setXY)
          sh.setZ(0,sz) if sh.respond_to?(:setZ)
          sh.setOpacity(0,0); sh.setVisible(0,true); sh.moveOpacity(2,8,255)
        end
        if boxsp
          bx=addSprite(boxsp); mode=(BSS064.databox_animation_mode rescue "slide")
          case mode
          when "pop"
            bx.setOpacity(2,255) if bx.respond_to?(:setOpacity); bx.setVisible(2,true)
          when "fade"
            bx.setOpacity(0,0); bx.setVisible(0,true); bx.moveOpacity(2,10,255)
          else
            dir=b.index.even? ? 1 : -1
            bx.setOpacity(0,255) if bx.respond_to?(:setOpacity)
            bx.setDelta(0,dir*Graphics.width/2,0); bx.setVisible(0,true); bx.moveDelta(0,12,-dir*Graphics.width/2,0)
          end
        end
      else
        obj=addSprite(bat,PictureOrigin::BOTTOM); obj.setZ(0,nz) if obj.respond_to?(:setZ); obj.moveXY(0,duration,nx,ny)
        if sha
          shadow_size=sha.respond_to?(:sideSize) && sha.sideSize ? sha.sideSize : side_size
          sx,sy,sz=bss_sos_shadow_position(b,shadow_size,sha)
          sh=addSprite(sha,PictureOrigin::CENTER); sh.setZ(0,sz) if sh.respond_to?(:setZ); sh.moveXY(0,duration,sx,sy)
        end
        if boxsp
          bx=addSprite(boxsp)
          from=boxsp.instance_variable_get(:@bss656_reflow_from_xy) rescue nil
          to=boxsp.instance_variable_get(:@bss656_reflow_to_xy) rescue nil
          if from.is_a?(Array) && to.is_a?(Array)
            bx.setXY(0,from[0],from[1]); bx.moveXY(0,duration,to[0],to[1])
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
          bx.setVisible(0,true) if !hide_for_boss
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Boss accumulated EXP. Core EXP/EV/level-up calculations stay untouched; only
# the repeated "gained X Exp" lines are suppressed and one actual accumulated
# total is shown when the Boss battle resolves.
#-------------------------------------------------------------------------------
module BSS084BossEXP
  def bss084_global_exp_mode?
    cfg = @bss_boss_config
    cfg.is_a?(Hash) && cfg["enabled"] == true && cfg["expMode"].to_s == "global"
  rescue
    false
  end

  def pbGainExpOne(idxParty, defeatedBattler, numPartic, expShare, expAll, showMessages=true)
    return super unless bss084_global_exp_mode?
    pkmn = pbParty(0)[idxParty] rescue nil
    before = pkmn ? pkmn.exp.to_i : nil
    ret = super(idxParty, defeatedBattler, numPartic, expShare, expAll, false)
    if pkmn && before
      gained = [pkmn.exp.to_i - before, 0].max
      @bss084_exp_totals ||= {}
      row = (@bss084_exp_totals[idxParty] ||= { :pokemon => pkmn, :exp => 0 })
      row[:pokemon] = pkmn
      row[:exp] += gained
    end
    ret
  end

  def bss084_show_exp_summary
    return if @bss084_exp_summary_shown || !bss084_global_exp_mode?
    @bss084_exp_summary_shown = true
    rows = @bss084_exp_totals
    return if !rows.is_a?(Hash) || rows.empty?
    rows.keys.sort.each do |idx|
      row=rows[idx]; next if !row || row[:exp].to_i<=0
      pkmn=row[:pokemon]; name=(pkmn.name rescue _INTL("Pokémon"))
      msg=((@bss_boss_config.is_a?(Hash) && @bss_boss_config["expSummaryMessage"]) rescue nil).to_s; msg="¡{1} ganó un total de {2} Puntos de Experiencia!" if msg.empty?; pbDisplay(_INTL(msg,name,row[:exp].to_i))
    end
  rescue => e
    BSS064.log("BSS084 EXP summary warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def pbEndOfBattle(*args, &block)
    bss084_show_exp_summary
    super
  ensure
    @bss084_exp_totals=nil
  end
end

# Camera contexts that live outside Battle::Scene.
module BSS084BattleCameraContexts
  def pbEndOfRoundPhase(*args, &block)
    ret = super
    begin
      @scene.bss084_transition_context("turn_end") if @scene && @scene.respond_to?(:bss084_transition_context)
    rescue
    end
    ret
  end
end

module BSS084BattlerCameraContexts
  def pbFaint(*args, &block)
    begin
      sc = @battle.scene rescue nil
      sc.bss084_transition_context("faint", self, [self]) if sc && sc.respond_to?(:bss084_transition_context)
    rescue
    end
    super
  end
end

begin
  BSS070EBDXRoom.prepend(BSS084WideRoom) if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS084WideRoom)
rescue => e
  BSS064.log("BSS084 wide-room install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle::Scene.prepend(BSS084SceneAuthority) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS084SceneAuthority)
rescue => e
  BSS064.log("BSS084 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle.prepend(BSS084BattleCameraContexts) if defined?(Battle) && !Battle.ancestors.include?(BSS084BattleCameraContexts)
rescue => e
  BSS064.log("BSS084 battle-camera install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle::Battler.prepend(BSS084BattlerCameraContexts) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS084BattlerCameraContexts)
rescue => e
  BSS064.log("BSS084 battler-camera install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle.prepend(BSS084BossEXP) if defined?(Battle) && !Battle.ancestors.include?(BSS084BossEXP)
rescue => e
  BSS064.log("BSS084 EXP install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
