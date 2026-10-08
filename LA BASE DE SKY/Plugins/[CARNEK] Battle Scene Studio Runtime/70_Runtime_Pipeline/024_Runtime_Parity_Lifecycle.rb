#===============================================================================
# Battle Scene Studio v0.8.15
# Final runtime parity / lifecycle / intro authority.
#
# Goals:
# - custom img### layers follow the exact EBDX room camera like native elements;
# - warp tiles are updated after the final layer transform and can use denser
#   subdivision so authored curvature remains visible in game;
# - blur is a real runtime property, not editor-only decoration;
# - EBDX daylight tint stays readable and Forest ambient lights pulse smoothly;
# - sendout balls remain on-screen and finish at the loaded battler endpoint;
# - early Gen-5-style camera motion is restored without stealing BAS camera;
# - end-battle battler/camera lock survives until sprite disposal/fade teardown;
# - Wild Intro styles actually select different engines, including Vanilla.
#===============================================================================
module BSS095
  VERSION = "0.8.15"
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

  CLASSIC_CONTEXTS = {
    "command"  => {"enabled"=>true, "mode"=>"player",  "frames"=>46, "strength"=>16},
    "fight"    => {"enabled"=>true, "mode"=>"player",  "frames"=>38, "strength"=>22},
    "move"     => {"enabled"=>true, "mode"=>"focus",   "frames"=>30, "strength"=>26},
    "spread"   => {"enabled"=>true, "mode"=>"wide",    "frames"=>34, "strength"=>22},
    "common"   => {"enabled"=>true, "mode"=>"neutral", "frames"=>32, "strength"=>10},
    "sendout"  => {"enabled"=>true, "mode"=>"focus",   "frames"=>34, "strength"=>18},
    "recall"   => {"enabled"=>true, "mode"=>"focus",   "frames"=>30, "strength"=>16},
    "sos"      => {"enabled"=>true, "mode"=>"wide",    "frames"=>38, "strength"=>20},
    "capture"  => {"enabled"=>true, "mode"=>"enemy",   "frames"=>34, "strength"=>20},
    "faint"    => {"enabled"=>true, "mode"=>"focus",   "frames"=>30, "strength"=>18},
    "turn_end" => {"enabled"=>true, "mode"=>"neutral", "frames"=>46, "strength"=>8},
    "idle"     => {"enabled"=>true, "mode"=>"drift",   "frames"=>0,  "strength"=>72},
    "bas"      => {"enabled"=>true, "mode"=>"authored", "frames"=>0, "strength"=>100}
  }

  def legacy_static_contexts?(contexts)
    return true if !contexts.is_a?(Hash) || contexts.empty?
    keys=%w[command fight move spread common sendout recall sos capture faint turn_end]
    keys.all? do |k|
      r=contexts[k] || contexts[k.to_sym]
      !r.is_a?(Hash) || (r["enabled"] != true && r[:enabled] != true &&
        (r["strength"] || r[:strength] || 0).to_f <= 0)
    end
  rescue
    false
  end

  def sendout_endpoint(animation, dest_x=nil, dest_y=nil)
    sprites=animation.instance_variable_get(:@sprites) rescue nil
    return nil if !sprites.is_a?(Hash)
    idx=nil
    [:@idxBattler, :@idx_battler, :@battlerIndex, :@battler_index, :@index].each do |iv|
      next unless animation.instance_variable_defined?(iv)
      v=animation.instance_variable_get(iv) rescue nil
      if v.is_a?(Numeric)
        idx=v.to_i; break
      elsif v && v.respond_to?(:index)
        idx=v.index.to_i rescue nil; break if idx
      end
    end
    if idx.nil? && animation.instance_variable_defined?(:@battler)
      b=animation.instance_variable_get(:@battler) rescue nil
      idx=b.index.to_i if b && b.respond_to?(:index)
    end
    sp=idx.nil? ? nil : (sprites["pokemon_#{idx}"] rescue nil)
    if !sp
      candidates=[]
      sprites.each do |k,v|
        next unless k.to_s =~ /^pokemon_\d+$/ && v && !(v.disposed? rescue true)
        ep=v.instance_variable_get(:@bss087_sendout_endpoint) rescue nil
        next unless ep.is_a?(Array) && ep.length>=2
        score=if dest_x && dest_y
                (ep[0].to_f-dest_x.to_f)**2 + (ep[1].to_f-dest_y.to_f)**2
              else
                0
              end
        candidates << [score,v]
      end
      sp=candidates.min_by{|r| r[0]}[1] rescue nil
    end
    return nil if !sp
    ep=sp.instance_variable_get(:@bss087_sendout_endpoint) rescue nil
    ep=[sp.x,sp.y] unless ep.is_a?(Array) && ep.length>=2
    x=ep[0].to_f; y=ep[1].to_f
    # Never let a stale/temporary endpoint send the ball outside the viewport.
    return nil if x < -24 || x > Graphics.width+24 || y < -24 || y > Graphics.height+24
    [x,y]
  rescue
    nil
  end
end

#-------------------------------------------------------------------------------
# Camera migration: the old "source_faithful" preset accidentally disabled all
# command/fight/action contexts. Real EBDX is alive during normal battle flow.
# Preserve explicitly customized profiles, but migrate that exact legacy shape.
#-------------------------------------------------------------------------------
begin
  if defined?(BSS087) && BSS087.const_defined?(:CAMERA_PROFILES)
    BSS087::CAMERA_PROFILES["classic_gen5"]={
      "label"=>"Gen 5 Classic",
      "contexts"=>BSS087.deep_copy(BSS095::CLASSIC_CONTEXTS)
    }
  end
rescue
end

module BSS095CameraAuthority
  def bss087_camera_profile
    cfg=bss070_ebdx_camera_config rescue {}
    raw=(cfg["profile"] || cfg[:profile] || cfg["preset"] || cfg[:preset]).to_s
    return "classic_gen5" if raw.empty?
    raw
  rescue
    "classic_gen5"
  end

  def bss084_context_config(key)
    cfg=bss070_ebdx_camera_config rescue {}
    profile=bss087_camera_profile.to_s
    contexts=cfg.is_a?(Hash) ? (cfg["contexts"] || cfg[:contexts]) : nil
    schema=(cfg["cameraSchemaVersion"] || cfg[:cameraSchemaVersion] || 0).to_i
    if (profile=="source_faithful" || profile=="classic_gen5") && schema<2 && BSS095.legacy_static_contexts?(contexts)
      row=BSS095::CLASSIC_CONTEXTS[key.to_s]
      return BSS087.deep_copy(row) if row
    end
    if profile=="classic_gen5"
      base=BSS087.deep_copy(BSS095::CLASSIC_CONTEXTS[key.to_s] || {"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0})
      row=contexts.is_a?(Hash) ? (contexts[key.to_s] || contexts[key.to_sym]) : nil
      row.each{|k,v| base[k.to_s]=v} if row.is_a?(Hash)
      base["enabled"]=(base["enabled"]==true)
      base["frames"]=[[base["frames"].to_i,0].max,120].min
      base["strength"]=BSS087.clamp(base["strength"].nil? ? 100 : base["strength"],0,100)
      return base
    end
    super
  rescue
    BSS087.deep_copy(BSS095::CLASSIC_CONTEXTS[key.to_s] || {"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0})
  end
end

#-------------------------------------------------------------------------------
# Final EBDX room transform. Custom image layers use the same immutable EX/EY
# world anchors and bg camera zoom as native EBDX elements. Warp is refreshed
# after this final pass, which is important because micro-tiles otherwise used a
# transform from an earlier authority in the chain.
#-------------------------------------------------------------------------------
module BSS095RoomParityAuthority
  def bss095_regular_custom_layer?(data)
    return false unless data.is_a?(Hash)
    return false if data[:scrolling] == true || data[:rainbow] == true
    true
  end

  def bss095_apply_custom_layer_camera!
    bg=@sprites && @sprites["bg"]
    return if !bg || !@data.is_a?(Hash)
    @data.each do |raw_key,data|
      key=raw_key.to_s
      next unless key =~ /^img\d+/i && bss095_regular_custom_layer?(data)
      sp=@sprites[key] || @sprites[raw_key]
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:ex) || sp.ex.nil? || !sp.respond_to?(:ey) || sp.ey.nil?
      begin
        general=data.has_key?(:zoom) ? BSS095.num(data[:zoom],1.0) : ((sp.respond_to?(:param) && sp.param) ? sp.param.to_f : 1.0)
        zx=data.has_key?(:zoom_x) ? BSS095.num(data[:zoom_x],general) : general
        zy=data.has_key?(:zoom_y) ? BSS095.num(data[:zoom_y],general) : general
        sp.x=bg.x.to_f-(bg.ox.to_f-sp.ex.to_f)*bg.zoom_x.to_f
        sp.y=bg.y.to_f-(bg.oy.to_f-sp.ey.to_f)*bg.zoom_y.to_f
        if data[:flat] == true || data[:canvasLayer] == true
          sp.zoom_x=bg.zoom_x.to_f*zx
          sp.zoom_y=bg.zoom_y.to_f*zy
        else
          perspective=bg.zoom_x.to_f
          sp.zoom_x=perspective*zx
          sp.zoom_y=perspective*zy
        end
      rescue
      end
    end
  end

  def bss095_smooth_ambient_lights!
    return if !@sprites.is_a?(Hash)
    frame=(Graphics.frame_count rescue 0).to_f
    @sprites.each do |key,sp|
      next unless key.to_s =~ /^(?:aLight|cLight)\d+$/
      next if !sp || (sp.disposed? rescue true)
      begin
        base=(sp.end_x.to_f*255.0 rescue sp.opacity.to_f)
        phase=sp.instance_variable_get(:@bss095_light_phase)
        if phase.nil?
          phase=(key.to_s.gsub(/\D/,"").to_i*0.77)+(rand*0.35)
          sp.instance_variable_set(:@bss095_light_phase,phase)
        end
        # Long, shallow pulse instead of the old rapid 95<->max sawtooth.
        wave=Math.sin(frame/72.0 + phase)
        sp.opacity=BSS095.clamp(base*(0.93+0.055*wave),0,255).round
      rescue
      end
    end
  end

  def position
    ret=super
    bss095_apply_custom_layer_camera!
    bss093_update_warp_tiles! if respond_to?(:bss093_update_warp_tiles!)
    bss095_smooth_ambient_lights!
    ret
  end

  # Readable dynamic lighting using authentic EBDX tone palette (-120, -100, -60).
  def daylightTint
    has_outdoor = @data.is_a?(Hash) && (@data[:outdoor] || @data["outdoor"] || @data[:sky] || @data["sky"] || @data[:skyMode] || @data["skyMode"] || @data[:cloudsConfig] || @data["cloudsConfig"])
    return unless has_outdoor
    custom=@data["lighting"] rescue nil
    nt=[-120,-100,-60]; tw=[-16,-52,-56]
    if custom.is_a?(Hash)
      n=custom[:night] || custom["night"]; t=custom[:twilight] || custom["twilight"]
      nt=n.map{|x| BSS095.num(x,0).to_i}[0,3] if n.is_a?(Array) && n.length>=3
      tw=t.map{|x| BSS095.num(x,0).to_i}[0,3] if t.is_a?(Array) && t.length>=3
    end
    (@sprites || {}).each do |key,sp|
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:tone=)
      k=key.to_s
      next if k.include?("trainer") || k.include?("battler")
      next if k.include?("sky") || k.include?("sun") || k.include?("star") || k.include?("cloud") || k.include?("Light")
      d=@data[k] || @data[k.to_s] || @data[k.to_sym] rescue nil
      if d.is_a?(Hash)
        shading = d.has_key?(:shading) ? d[:shading] : d["shading"]
        next if shading == false
      end
      begin
        slot = (defined?(BSS106) && BSS106.respond_to?(:time_slot)) ? BSS106.time_slot(@data) : (PBDayNight.isNight? ? :night : ((PBDayNight.isEvening? || PBDayNight.isMorning?) ? :dawn : :day))
        tone_for_slot = case slot
        when :night
          Tone.new(nt[0], nt[1], nt[2], 0)
        when :dawn
          Tone.new(tw[0], tw[1], tw[2], 0)
        else
          Tone.new(0, 0, 0, 0)
        end
        sp.tone = tone_for_slot
        sp.color = Color.new(0, 0, 0, 0) if sp.respond_to?(:color=) && slot != :day
      rescue
      end
    end
  end

  # Portable custom-layer blur. Clone first so cached source bitmaps are never
  # modified. Warp rebuild runs afterwards from this blurred source.
  def bss095_apply_layer_blur!(key)
    data=@data[key] || @data[key.to_s]
    return unless data.is_a?(Hash)
    blur_val = data[:blur] || data["blur"]
    areas = data[:blurAreas] || data["blurAreas"]
    has_areas = areas.is_a?(Array) && areas.any? { |a| a.is_a?(Hash) && (BSS095.num(a[:radius] || a["radius"], 0) > 0 || (a[:mode] || a["mode"]).to_s.start_with?("band") || (a[:mode] || a["mode"]).to_s == "total") }
    amount=[[BSS095.num(blur_val,0).round,0].max,6].min
    return if amount<=0 && !has_areas
    sp=@sprites[key.to_s] || @sprites[key]
    return if !sp || (sp.disposed? rescue true) || !sp.bitmap || (sp.bitmap.disposed? rescue true)

    # 1. Source-linked crop: if layer is cropped (e.g. from a huge tileset),
    # extract the cropped slice FIRST so we process ~1000 px instead of 2.8 million.
    crop = data[:crop] || data["crop"]
    if crop.is_a?(Hash) && !data[:bss_cropped] && !data["bss_cropped"]
      src_raw = sp.bitmap
      sw = src_raw.width
      sh = src_raw.height
      cx = BSS095.num(crop[:x] || crop["x"], 0).round
      cy = BSS095.num(crop[:y] || crop["y"], 0).round
      cw = BSS095.num(crop[:w] || crop["w"], sw).round
      ch = BSS095.num(crop[:h] || crop["h"], sh).round
      cx = [[cx, 0].max, sw - 1].min
      cy = [[cy, 0].max, sh - 1].min
      cw = [[cw, 1].max, sw - cx].min
      ch = [[ch, 1].max, sh - cy].min
      cut = Bitmap.new(cw, ch)
      cut.blt(0, 0, src_raw, Rect.new(cx, cy, cw, ch))
      sp.bitmap = cut
      data[:bss_cropped] = true
      data["bss_cropped"] = true
      ox = data[:ox] || data["ox"]
      oy = data[:oy] || data["oy"]
      sp.ox = ox.nil? ? cw / 2 : ox.to_f - cx if sp.respond_to?(:ox=)
      sp.oy = oy.nil? ? ch : oy.to_f - cy if sp.respond_to?(:oy=)
    end

    src=sp.bitmap
    bmp=Bitmap.new(src.width,src.height)
    bmp.blt(0,0,src,src.rect)
    if amount > 0
      amount.times do
        if bmp.respond_to?(:blur)
          bmp.blur
        else
          w=[bmp.width/2,1].max; h=[bmp.height/2,1].max
          tmp=Bitmap.new(w,h); tmp.stretch_blt(tmp.rect,bmp,bmp.rect)
          bmp.clear; bmp.stretch_blt(bmp.rect,tmp,tmp.rect); tmp.dispose
        end
      end
    end
    if has_areas
      w = bmp.width; h = bmp.height
      areas.each do |a|
        next unless a.is_a?(Hash)
        mode = (a[:mode] || a["mode"] || "radial").to_s
        style = (a[:style] || a["style"] || "high").to_s
        strength = [[BSS095.num(a[:strength] || a["strength"], 4).round, 1].max, 24].min
        feather = [BSS095.num(a[:feather] || a["feather"], 18).round, 1].max
        ay = (data[:oy] || data["oy"] || h).to_f
        cy = (ay + BSS095.num(a[:y] || a["y"], 0)).round

        blurred = Bitmap.new(w, h)
        blurred.blt(0, 0, bmp, bmp.rect)
        if style == "jumble"
          rad = [[strength, 1].max, 24].min
          passes = (w * h <= 4096) ? [[(rad * 0.5).round, 1].max, 4].min : 1
          step = (w * h > 10000) ? 2 : 1
          rng = 0x5a5a5a
          swaps = 0
          max_swaps = 15000

          # Area-constrained bounds to prevent running on unneeded pixels
          min_x = 0; max_x = w - 1
          min_y = 0; max_y = h - 1
          if mode == "radial"
            rad_b = BSS095.num(a[:radius] || a["radius"], 48).round
            ax = (data[:ox] || data["ox"] || w / 2).to_f
            c_x = (ax + BSS095.num(a[:x] || a["x"], 0)).round
            min_x = [[c_x - rad_b, 0].max, w - 1].min
            max_x = [[c_x + rad_b, 0].max, w - 1].min
            min_y = [[cy - rad_b, 0].max, h - 1].min
            max_y = [[cy + rad_b, 0].max, h - 1].min
          elsif mode == "band_top"
            max_y = [[cy + feather, 0].max, h - 1].min
          elsif mode == "band_bottom"
            min_y = [[cy - feather, 0].max, h - 1].min
          end

          passes.times do
            (min_y..max_y).step(step) do |y|
              (min_x..max_x).step(step) do |x|
                break if swaps >= max_swaps
                c1 = blurred.get_pixel(x, y)
                next if !c1 || c1.alpha == 0
                wave = Math.sin(x * 0.05 + y * 0.035) * Math.cos(x * 0.03 - y * 0.06) +
                       0.35 * Math.sin((x + y) * 0.09) + 0.2 * Math.cos((x - y) * 0.14)
                norm = (wave + 1.55) / 3.1
                rng = (rng * 1664525 + 1013904223) & 0xffffffff
                chance = rng.to_f / 0xffffffff
                next if chance > norm * 0.85 + 0.1
                local_rad = [[(rad * (0.35 + 0.85 * norm)).round, 1].max, 24].min
                rng = (rng * 1664525 + 1013904223) & 0xffffffff
                ang = (rng.to_f / 0xffffffff) * Math::PI * 2
                rng = (rng * 1664525 + 1013904223) & 0xffffffff
                dist_ratio = rng.to_f / 0xffffffff
                dist = (dist_ratio**1.4) * local_rad
                nx = [[(x + Math.cos(ang) * dist).round, min_x].max, max_x].min
                ny = [[(y + Math.sin(ang) * dist).round, min_y].max, max_y].min
                c2 = blurred.get_pixel(nx, ny)
                next if !c2 || c2.alpha == 0
                blurred.set_pixel(x, y, c2)
                blurred.set_pixel(nx, ny, c1)
                swaps += 1
                if norm > 0.6 && x + 1 <= max_x && nx + 1 <= max_x
                  c1n = blurred.get_pixel(x + 1, y)
                  c2n = blurred.get_pixel(nx + 1, ny)
                  if c1n && c1n.alpha > 0 && c2n && c2n.alpha > 0
                    blurred.set_pixel(x + 1, y, c2n)
                    blurred.set_pixel(nx + 1, ny, c1n)
                  end
                end
              end
            end
          end
        else
          strength.times do
            if blurred.respond_to?(:blur)
              blurred.blur
            else
              tw = [blurred.width / 2, 1].max; th = [blurred.height / 2, 1].max
              tmp = Bitmap.new(tw, th); tmp.stretch_blt(tmp.rect, blurred, blurred.rect)
              blurred.clear; blurred.stretch_blt(blurred.rect, tmp, tmp.rect); tmp.dispose
            end
          end

          if style == "few_tones"
            qw = [w / 3, 1].max; qh = [h / 3, 1].max
            qtmp = Bitmap.new(qw, qh)
            qtmp.stretch_blt(qtmp.rect, blurred, blurred.rect)
            blurred.clear
            blurred.stretch_blt(blurred.rect, qtmp, qtmp.rect)
            qtmp.dispose rescue nil
          end
        end

        if mode == "total"
          bmp.clear
          bmp.blt(0, 0, blurred, Rect.new(0, 0, w, h))
        elsif mode == "band_bottom"
          y_start = [[cy - feather, 0].max, h].min
          rect_h = [h - y_start, 0].max
          bmp.blt(0, y_start, blurred, Rect.new(0, y_start, w, rect_h)) if rect_h > 0
        elsif mode == "band_top"
          y_end = [[cy + feather, 0].max, h].min
          bmp.blt(0, 0, blurred, Rect.new(0, 0, w, y_end)) if y_end > 0
        elsif mode == "radial"
          ax = (data[:ox] || data["ox"] || w / 2).to_f
          cx = (ax + BSS095.num(a[:x] || a["x"], 0)).round
          rad = BSS095.num(a[:radius] || a["radius"], 48).round
          rx = [[cx - rad, 0].max, w].min
          ry = [[cy - rad, 0].max, h].min
          rw = [cx + rad - rx, 0].max
          rh = [cy + rad - ry, 0].max
          bmp.blt(rx, ry, blurred, Rect.new(rx, ry, rw, rh)) if rw > 0 && rh > 0
        end
        blurred.dispose rescue nil
      end
    end
    @bss095_blur_bitmaps||=[]
    @bss095_blur_bitmaps << bmp
    sp.bitmap=bmp
    sp.memorize_bitmap if sp.respond_to?(:memorize_bitmap)
  rescue => e
    BSS064.log("BSS095 blur warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def drawImg(key)
    ret=super
    begin
      bss095_apply_layer_blur!(key)
      data=@data[key] || @data[key.to_s]
      warp = data.is_a?(Hash) ? (data[:warp] || data["warp"]) : nil
      if warp.is_a?(Hash) && (warp[:enabled] == true || warp["enabled"] == true) && respond_to?(:bss093_build_warp_layer!)
        bss093_build_warp_layer!(key)
      end
    rescue
    end
    ret
  end

  def bss076_dispose_owned_sprites!
    begin
      (@bss095_blur_bitmaps || []).each{|b| b.dispose if b && !(b.disposed? rescue true)}
    rescue
    end
    @bss095_blur_bitmaps=[]
    super
  end
end

# Make warp projection use the final root transform, not an earlier bg estimate.
module BSS095WarpProjectionAuthority
  def bss093_project_point(root,data,cfg,u,v)
    rel=bss093_sample_warp(cfg,u,v)
    general=data.has_key?(:zoom) ? BSS095.num(data[:zoom],1.0) : 1.0
    zx=data.has_key?(:zoom_x) ? BSS095.num(data[:zoom_x],general) : general
    zy=data.has_key?(:zoom_y) ? BSS095.num(data[:zoom_y],general) : general
    rx=(zx.abs<0.00001 ? 1.0 : root.zoom_x.to_f/zx)
    ry=(zy.abs<0.00001 ? 1.0 : root.zoom_y.to_f/zy)
    rad=BSS095.num(data[:angle],0.0)*Math::PI/180.0
    cs=Math.cos(rad); sn=Math.sin(rad)
    lx=rel[0]*zx*rx; ly=rel[1]*zy*ry
    [root.x.to_f + lx*cs-ly*sn, root.y.to_f + lx*sn+ly*cs]
  rescue
    super
  end
end

#-------------------------------------------------------------------------------
# Ball trajectory: safe arc + final endpoint from the already loaded EBDX
# battler. Older Gen5 arc code could start at Graphics.width+54 and lift 176px,
# which made the ball visibly leave the screen before the Pokémon appeared.
#-------------------------------------------------------------------------------
module BSS095PlayerBallEndpoint
  def createBallTrajectory(ball,delay,duration,startX,startY,midX,midY,endX,endY)
    owner=self.class.to_s
    capture_like=(owner =~ /(throw|capture|catch)/i)
    if !capture_like && defined?(BSS078) && BSS078.ebdx_room?(@sprites)
      ep=BSS095.sendout_endpoint(self,endX,endY)
      if ep
        endX,endY=ep
      end
      startX=BSS095.clamp(startX,18,Graphics.width-18)
      startY=BSS095.clamp(startY,22,Graphics.height-22)
      midX=(startX.to_f+endX.to_f)*0.5
      lift=[92.0,(endY.to_f-24.0).abs].min
      midY=BSS095.clamp([midY.to_f,endY.to_f-lift].min,24,Graphics.height-24)
    end
    super(ball,delay,duration,startX,startY,midX,midY,endX,endY)
  end
end

module BSS095TrainerBallEndpoint
  def createBallTrajectory(ball,destX,destY)
    if defined?(BSS078) && BSS078.ebdx_room?(@sprites)
      ep=BSS095.sendout_endpoint(self,destX,destY)
      destX,destY=ep if ep
    end
    super(ball,destX,destY)
  end
end

#-------------------------------------------------------------------------------
# End-battle visual lock stays active through the fade and only releases when
# the scene actually disposes its sprites. This hides internal EBDX->native
# restoration from the player.
#-------------------------------------------------------------------------------
module BSS095EndBattleLifecycle
  def pbEndBattle(*args,&block)
    @bss095_hold_end_lock=true
    bss087_begin_end_battle_lock if respond_to?(:bss087_begin_end_battle_lock)
    super
  ensure
    bss087_apply_end_battle_lock_frame if respond_to?(:bss087_apply_end_battle_lock_frame)
  end

  def bss087_finish_end_battle_lock
    return true if @bss095_hold_end_lock
    super
  end

  def pbDisposeSprites(*args,&block)
    begin
      bss087_apply_end_battle_lock_frame if respond_to?(:bss087_apply_end_battle_lock_frame)
      @bss095_hold_end_lock=false
      bss087_finish_end_battle_lock if respond_to?(:bss087_finish_end_battle_lock)
    rescue
    end
    super
  end
end

#-------------------------------------------------------------------------------
# Wild intro engine selection.
# - vanilla: bypass every BSS/NDS replacement and use Essentials' intro.
# - nds_biome: use standalone snapshot intro over the live EBDX/Vanilla world.
# - other styles: use BSS079 style-specific live-scene intro.
#-------------------------------------------------------------------------------
if defined?(BSS083StandaloneWildNDS)
  module BSS083StandaloneWildNDS
    module_function
    def enabled?(scene)
      battle=scene.instance_variable_get(:@battle) rescue nil
      return false if !battle || !(battle.wildBattle? rescue false)
      cfg=scene.respond_to?(:bss079_intro_config) ? (scene.bss079_intro_config rescue {}) : {}
      style=(cfg.is_a?(Hash) ? (cfg["style"] || cfg[:style]) : nil).to_s
      style="nds_biome" if style.empty?
      return false if style=="vanilla"
      return false if style!="nds_biome"
      if defined?(VermeilWildIntroNDS)
        return false unless (VermeilWildIntroNDS.enabled? rescue true)
      end
      ebdx=scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?
      return true if ebdx
      cfg.is_a?(Hash) && (cfg["useInVanilla"] == true || cfg[:useInVanilla] == true)
    rescue
      false
    end
  end
end

module BSS095WildIntroSnapshot
  def bss083_nds_world_snapshot(foes)
    return nil if !defined?(Graphics) || !Graphics.respond_to?(:snap_to_bitmap)
    hidden=[]; old_color=nil
    ebdx=respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    begin
      bss070_ebdx_ensure_core if ebdx && respond_to?(:bss070_ebdx_ensure_core)
      room=@bss070_ebdx_room rescue nil
      room ||= (@sprites["battlebg"] rescue nil)
      room.update if ebdx && room && room.respond_to?(:update) && !(room.disposed? rescue true)
      if @viewport && @viewport.respond_to?(:color) && @viewport.respond_to?(:color=)
        c=@viewport.color
        old_color=Color.new(c.red,c.green,c.blue,c.alpha) rescue nil
        @viewport.color=Color.new(0,0,0,0)
      end
      (@sprites || {}).each do |key,sp|
        next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible)
        k=key.to_s
        keep = if ebdx
                 k=="battlebg"
               else
                 ["battle_bg","battle_bg2","base_0","base_1"].include?(k)
               end
        next if keep
        hide = if ebdx
                 true
               else
                 k =~ /^(pokemon_|shadow_|dataBox_|trainer_|player_|party|cmdBar|command|fight|target|message|enhanced|info_icon|ball_icon|leftarrow|rightarrow|boss|ability|itemWindow|captureBall)/i || k =~ /_outline\d+$/i
               end
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
  rescue => e
    BSS064.log("BSS095 WildIntro snapshot warning: #{e.class}: #{e.message}") if defined?(BSS064)
    nil
  end
end

# BSS079 itself must respect the explicit Vanilla style once standalone NDS has
# declined the intro. Reopening the prepended module changes the active method.
if defined?(BSS079IntroAuthority)
  module BSS079IntroAuthority
    alias bss095_bss079_pbBattleIntroAnimation pbBattleIntroAnimation unless method_defined?(:bss095_bss079_pbBattleIntroAnimation)
    def pbBattleIntroAnimation
      cfg=bss079_intro_config rescue {}
      style=(cfg["style"] || cfg[:style]).to_s rescue ""
      return super if style=="vanilla"
      bss095_bss079_pbBattleIntroAnimation
    end
  end
end

#-------------------------------------------------------------------------------
# Install the final authorities after 023.
#-------------------------------------------------------------------------------
begin
  BSS070EBDXRoom.prepend(BSS095RoomParityAuthority) if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS095RoomParityAuthority)
  BSS070EBDXRoom.prepend(BSS095WarpProjectionAuthority) if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS095WarpProjectionAuthority)
rescue => e
  BSS064.log("BSS095 room install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  Battle::Scene.prepend(BSS095CameraAuthority) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS095CameraAuthority)
  Battle::Scene.prepend(BSS095EndBattleLifecycle) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS095EndBattleLifecycle)
  Battle::Scene.prepend(BSS095WildIntroSnapshot) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS095WildIntroSnapshot)
rescue => e
  BSS064.log("BSS095 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  mix=Battle::Scene::Animation::BallAnimationMixin
  mix.prepend(BSS095PlayerBallEndpoint) if defined?(mix) && !mix.ancestors.include?(BSS095PlayerBallEndpoint)
rescue => e
  BSS064.log("BSS095 player ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  k=Battle::Scene::Animation::PokeballTrainerSendOut
  k.prepend(BSS095TrainerBallEndpoint) if defined?(k) && !k.ancestors.include?(BSS095TrainerBallEndpoint)
rescue => e
  BSS064.log("BSS095 trainer ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
