#===============================================================================
# BSS layered lighting: legacy battleback separation + Lighting Studio parity.
# No external PNG files are modified. Bitmap slices retain the original image.
#===============================================================================
module BSSLayeredLighting
  module_function

  def clamp(n, low, high)
    [[n.to_f, low].max, high].min
  end

  def config_value(data, key, fallback=nil)
    return fallback unless data.is_a?(Hash)
    val=data[key] || data[key.to_sym]
    val.nil? ? fallback : val
  end

  def outdoor?(data)
    return false unless data.is_a?(Hash)
    flag=config_value(data,"outdoor")
    return false if flag==false
    return true if flag==true
    !!(config_value(data,"sky") || config_value(data,"skyMode") ||
      config_value(data,"trees") || config_value(data,"tallGrass"))
  end

  def hour
    defined?(BSSLightingClockBridge) ? BSSLightingClockBridge.hour : Time.now.hour + Time.now.min/60.0
  rescue StandardError
    12.0
  end

  def slot(data=nil)
    defined?(BSSLightingClockBridge) ? BSSLightingClockBridge.slot(data) : :day
  end

  def ambient_tone
    if defined?(LightingStudioDayNight) && defined?(BSSLightingClockBridge) &&
       BSSLightingClockBridge.active?
      clock=LightingStudioDayNight
      if clock.native_tone?
        return clock.tone_values.map(&:to_f)
      end
      raw=clock.interpolate(hour)
      darkness=raw.is_a?(Array) ? clamp(raw[1],0.0,1.0) : 0.0
      return [-90*darkness,-90*darkness,-82*darkness,0]
    end
    case slot
    when :night then [-78.0,-79.0,-63.0,0]
    when :dawn  then [-28.0,-33.0,-27.0,0]
    else [0.0,0.0,0.0,0]
    end
  rescue StandardError
    [0.0,0.0,0.0,0]
  end

  # A sunlit horizon survives into early evening even when Lighting Studio
  # considers the overworld nighttime. This is color balance, not a new clock.
  def twilight_strength
    h=hour % 24.0
    evening=clamp(1.0-(h-19.0).abs/2.4,0.0,1.0)
    morning=clamp(1.0-(h-6.0).abs/1.2,0.0,1.0)
    [evening,morning].max
  end

  def tone(values,weight=1.0)
    a=(0..2).map { |i| clamp(values[i].to_f*weight,-255.0,255.0).round }
    Tone.new(a[0],a[1],a[2],clamp(values[3].to_f*weight,0,255).round)
  end
end

module BSSLayeredRoomSupport
  # Ground/horizon belong to this room only. The original bitmap remains owned
  # by bg; the slice sprites must never dispose the shared bitmap.
  def bss_layered_release!
    if @bss_layered_source && @sprites.is_a?(Hash)
      bg=@sprites["bg"]
      begin
        bg.bitmap=@bss_layered_source if bg && !(bg.disposed? rescue true)
      rescue StandardError
      end
    end
    Array(@bss_layered_extra).each do |sp|
      sp.dispose if sp && !(sp.disposed? rescue true)
    rescue StandardError
    end
    Array(@bss_layered_generated).each do |bmp|
      bmp.dispose if bmp && !(bmp.disposed? rescue true)
    rescue StandardError
    end
    @bss_layered_extra=nil
    @bss_layered_generated=nil
    @bss_layered_source=nil
    @bss_layered_ranges=nil
    @bss_layered_last_key=nil
  end

  def bss_layered_boundary(bitmap,source,w,h)
    sky=BSSLayeredLighting.config_value(@data,"skySplitY",nil)
    floor=BSSLayeredLighting.config_value(@data,"horizonSplitY",nil)
    if sky && floor
      low=BSSLayeredLighting.clamp(sky,8,h-16).round
      high=BSSLayeredLighting.clamp(floor,low+4,h-4).round
      return Array.new(w,low),Array.new(w,high)
    end
    # Detect the actual sky/terrain colour transition. Battleback PNGs are
    # already pixel art; scan raw RGBA once rather than generating a mask per
    # redraw. No arbitrary 30% / 43% horizontal bands.
    y0=(h*0.23).to_i
    y1=(h*0.62).to_i
    step=[(w/56.0).ceil,1].max
    best_y=(h*0.40).to_i;best=-1
    (y0..y1).step(2) do |y|
      score=0
      x=0
      while x<w
        i=((y-3)*w+x)*4
        j=((y+3)*w+x)*4
        3.times do |ch|
          score+=(source.getbyte(i+ch)-source.getbyte(j+ch)).abs
        end
        x+=step
      end
      # Prefer the skyline over noisy ground texture if gradients are close.
      score=(score*(1.0-0.16*((y-h*0.40).abs/h.to_f))).round
      if score>best
        best=score;best_y=y
      end
    end
    center=best_y+5
    upper=Array.new(w)
    lower=Array.new(w)
    # Resolve gentle per-column variation near the global skyline. Preserve
    # irregular distant tree/roof silhouettes rather than painting a straight
    # rectangle over them. Bound jitter for seamless pixel edges.
    xs=[]
    (0...w).step(4) do |x|
      local=center;peak=-1
      ([center-10,y0].max..[center+10,y1].min).each do |y|
        i=((y-2)*w+x)*4;j=((y+2)*w+x)*4
        score=(source.getbyte(i)-source.getbyte(j)).abs+
              (source.getbyte(i+1)-source.getbyte(j+1)).abs+
              (source.getbyte(i+2)-source.getbyte(j+2)).abs
        score-=((y-center).abs*1.6).to_i
        if score>peak
          peak=score;local=y
        end
      end
      xs << local
    end
    w.times do |x|
      j=x/4
      a=xs[j] || center
      b=xs[j+1] || a
      edge=(a*(1-(x%4)/4.0)+b*((x%4)/4.0)).round
      upper[x]=[edge-28,8].max
      lower[x]=[edge+5,h-4].min
    end
    [upper,lower]
  end

  def bss_layered_split!
    return unless BSSLayeredLighting.outdoor?(@data)
    bg=@sprites.is_a?(Hash) ? @sprites["bg"] : nil
    return unless bg && bg.bitmap && !(bg.bitmap.disposed? rescue true)
    source_bitmap=bg.bitmap
    w=source_bitmap.width.to_i;h=source_bitmap.height.to_i
    return unless w>=16 && h>=48
    source=source_bitmap.respond_to?(:raw_data) ? source_bitmap.raw_data : nil
    if source && source.respond_to?(:getbyte) && source.bytesize>=w*h*4
      upper,lower=bss_layered_boundary(source_bitmap,source,w,h)
      sky="\x00".b*(w*h*4)
      haze="\x00".b*(w*h*4)
      terrain="\x00".b*(w*h*4)
      h.times do |y|
        w.times do |x|
          pos=(y*w+x)*4
          next if source.getbyte(pos+3)==0
          dest=y<upper[x] ? sky : (y<lower[x] ? haze : terrain)
          dest[pos,4]=source.byteslice(pos,4)
        end
      end
      images=[sky,haze,terrain].map do |raw|
        bmp=Bitmap.new(w,h)
        bmp.raw_data=raw
        bmp
      end
      @bss_layered_source=source_bitmap
      @bss_layered_generated=images
      bg.bitmap=images[0]
      bg.src_rect.set(0,0,w,h)
      @bss_layered_ranges=nil
      @bss_layered_extra=[]
      [1,2].each do |index|
        sprite=Sprite.new(@viewport)
        sprite.bitmap=images[index]
        sprite.src_rect.set(0,0,w,h)
        @bss_layered_extra << sprite
      end
      bss_layered_sync!
      bss_layered_apply_tone!(true)
      return
    end
    # Older RGSS builds without Bitmap#raw_data retain the safe scanline
    # fallback rather than failing or blanking the battleback.
    low=BSSLayeredLighting.clamp(BSSLayeredLighting.config_value(@data,"skySplitY",h*0.30),8,h-16).round
    high=BSSLayeredLighting.clamp(BSSLayeredLighting.config_value(@data,"horizonSplitY",h*0.43),low+4,h-4).round
    @bss_layered_source=source_bitmap
    @bss_layered_ranges=[[0,low],[low,high],[high,h]]
    @bss_layered_extra=[]
    bg.src_rect.set(0,0,w,low)
    [1,2].each do |i|
      y0,y1=@bss_layered_ranges[i]
      sp=Sprite.new(@viewport);sp.bitmap=source_bitmap
      sp.src_rect.set(0,y0,w,y1-y0)
      @bss_layered_extra<<sp
    end
    bss_layered_sync!
    bss_layered_apply_tone!(true)
  rescue StandardError => e
    BSS064.log("BSS skyline separation warning: #{e.class}: #{e.message}") if defined?(BSS064)
    bss_layered_release!
  end

  def bss_layered_sync!
    return unless @bss_layered_extra
    bg=@sprites["bg"] rescue nil
    return unless bg && !(bg.disposed? rescue true)
    source_x=bg.x;source_y=bg.y
    # Source EBDX camera travels with the terrain and battlers. The sky is
    # farther away: keep subtle independent parallax, with only 1-4 pixels of
    # displacement to avoid exposing a seam at the automatic alpha skyline.
    sx=source_x;sy=source_y
    begin
      if @scene && @scene.respond_to?(:vector) && @scene.vector && @defaultvector
        sx,sy=@scene.vector.spoof(@defaultvector)
      end
    rescue StandardError
    end
    dx=BSSLayeredLighting.clamp((source_x-sx)*0.15,-4,4)
    dy=BSSLayeredLighting.clamp((source_y-sy)*0.09,-2,2)
    @bss_layered_extra.each_with_index do |part,index|
      next unless part && !(part.disposed? rescue true)
      origin=@bss_layered_ranges ? @bss_layered_ranges[index+1][0] : 0
      # Horizon half depth, ground anchored to the EBDX battle floor.
      factor=index==0 ? 0.5 : 0.0
      part.x=source_x-dx*factor
      part.y=source_y-dy*factor
      part.ox=bg.ox;part.oy=bg.oy-origin
      part.z=bg.z;part.zoom_x=bg.zoom_x;part.zoom_y=bg.zoom_y
      part.angle=bg.angle;part.opacity=bg.opacity;part.visible=bg.visible
    end
    bg.x=source_x-dx
    bg.y=source_y-dy
  end

  def bss_layered_apply_tone!(force=false)
    return unless BSSLayeredLighting.outdoor?(@data)
    bg=@sprites["bg"] rescue nil
    return unless bg && !(bg.disposed? rescue true)
    light=BSSLayeredLighting.ambient_tone
    warmth=BSSLayeredLighting.twilight_strength
    slot=BSSLayeredLighting.slot(@data)
    key=[light.map{|x|x.round(1)},(warmth*24).round,slot].join(":")
    return if !force && @bss_layered_last_key==key
    @bss_layered_last_key=key

    # Dim sky far less than the terrain; do not black out the sunset.
    # The bright sky stays readable; the horizon remains warm while the
    # terrain receives clearly stronger clock lighting.
    sky_tone=BSSLayeredLighting.tone(light,0.36)
    horizon_tone=BSSLayeredLighting.tone(light,0.28)
    ground_tone=BSSLayeredLighting.tone(light,1.35)
    bg.tone=sky_tone
    if @bss_layered_extra && @bss_layered_extra.length==2
      horizon,ground=@bss_layered_extra
      horizon.tone=horizon_tone
      horizon.color=Color.new(255,179,100,(188*warmth).round)
      ground.tone=ground_tone
      ground.color=Color.new(40,70,97,slot==:night ? 78 : (warmth*28).round)
    else
      bg.tone=ground_tone
    end

    @sprites.each do |name,sp|
      next if !sp || (sp.disposed? rescue true)
      # EBDX's source trees can be almost black at dusk/night; lift them into
      # blue-green instead of forcing the original solid black silhouette.
      if name =~ /\A(?:tree|grass)\d+\z/i
        sp.tone=BSSLayeredLighting.tone(light,0.46) if sp.respond_to?(:tone=)
        if sp.respond_to?(:color=)
          alpha=slot==:day ? 0 : (slot==:dawn ? 195 : 225)
          sp.color=Color.new(65,110,118,alpha)
        end
      elsif name=="base" || name=="water"
        sp.tone=ground_tone if sp.respond_to?(:tone=)
      end
    end
  rescue StandardError => e
    BSS064.log("BSS layered lighting warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def visible=(flag)
    result=super
    Array(@bss_layered_extra).each{|part|part.visible=flag if part && !(part.disposed? rescue true)}
    result
  end

  def position(*args,&block)
    result=super
    bss_layered_sync!
    result
  end

  def daylightTint(*args,&block)
    result=super
    bss_layered_apply_tone!(true)
    result
  end

  def update(*args,&block)
    result=super
    # position() already synchronized the three planes once this frame.
    now=defined?(System) && System.respond_to?(:uptime) ? System.uptime : Time.now.to_f
    if !@bss_layered_next_tint || now>=@bss_layered_next_tint
      @bss_layered_next_tint=now+0.25
      bss_layered_apply_tone!
    end
    result
  end

  def dispose(*args,&block)
    bss_layered_release!
    super
  end
end

module BSSLayeredBaseRefresh
  def refresh(*args,&block)
    bss_layered_release!
    result=super
    bss_layered_split! if args[0].is_a?(Hash)
    result
  end
end

module BSSLayeredCustomRefresh
  def refresh(*args,&block)
    bss_layered_release!
    result=super
    bss_layered_split! if args[0].is_a?(Hash)
    result
  end
end

if defined?(BSS070EBDXRoom)
  BSS070EBDXRoom.prepend(BSSLayeredRoomSupport) unless BSS070EBDXRoom.ancestors.include?(BSSLayeredRoomSupport)
  BSS070EBDXRoom.prepend(BSSLayeredBaseRefresh) unless BSS070EBDXRoom.ancestors.include?(BSSLayeredBaseRefresh)
end
if defined?(BSS070CustomRoom)
  BSS070CustomRoom.prepend(BSSLayeredCustomRefresh) unless BSS070CustomRoom.ancestors.include?(BSSLayeredCustomRefresh)
end

# Re-enable EBDX's actual vector interpolation. The previously-installed
# authority updates the room but deliberately did not advance the camera.
# Only active EBDX battles move battlers/world; Vanilla preserves its HUD and
# sprites and uses the adapter's decorative background camera.
module BSSLayeredEBDXCamera
  def bss_layered_camera_config
    cfg=BSS070EBDXCore.camera_config rescue {}
    cfg.is_a?(Hash) ? cfg : {}
  end

  def bss_layered_camera_active?
    return false unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    return false unless @vector && @battle
    cfg=bss_layered_camera_config
    profile=(cfg["profile"] || cfg["preset"] || "ebdx").to_s.downcase
    return false if profile=="static" || profile=="off"
    return false if (@battle.respond_to?(:triplebattle?) && @battle.triplebattle?)
    true
  rescue StandardError
    false
  end

  def bss_layered_next_ebdx_shot
    cfg=bss_layered_camera_config
    strength=BSSLayeredLighting.clamp(cfg["idleStrength"] || 65,0,100)/100.0
    speed=BSSLayeredLighting.clamp(cfg["idleSpeed"] || 50,1,100)/100.0
    base=BSS070EBDXCore.get_vector(:MAIN,@battle).map(&:to_f)
    target=base.clone
    patterns=(BSS070EBDXCore.const_get(:CAMERA_MOTION) rescue nil)
    options=patterns.is_a?(Array) ? patterns.select{|v|v.is_a?(Array) && v.length>=5} : []
    if options.empty?
      phase=@bss_layered_camera_index.to_i
      target[0]+=Math.sin(phase*1.8)*14*strength
      target[1]+=Math.cos(phase*1.4)*8*strength
      target[4]=base[4]*(1.0+Math.sin(phase*1.3)*0.055*strength)
      target[5]=base[5]*(1.0+Math.sin(phase*1.3)*0.055*strength)
    else
      index=@bss_layered_camera_index.to_i%options.length
      row=options[index]
      # Source-authored EBDX vectors, blended towards the stable MAIN framing.
      [0,1,2,3,4,5].each do |i|
        value=(row[i] || (i==5 ? row[4] : base[i])).to_f
        target[i]=base[i]+(value-base[i])*strength
      end
    end
    @bss_layered_camera_index=@bss_layered_camera_index.to_i+1
    @vector.inc=0.004+speed*0.018
    @vector.set(target)
    frames=(260-speed*160).round
    @bss_layered_camera_due=@bss_layered_camera_tick.to_i+frames
  end

  def bss070_ebdx_tick(advance_camera=true,align=true)
    if bss_layered_camera_active? && advance_camera && !@bss084_native_move_active &&
       !@bss083_animation_projection && @bss070_ebdx_suspend_depth.to_i<=0
      @bss_layered_camera_tick=@bss_layered_camera_tick.to_i+1
      if @bss_layered_camera_tick>=@bss_layered_camera_due.to_i &&
         !@bss_in_command_menu && !@bss_entering_fight &&
         !@bss102_command_overview
        bss_layered_next_ebdx_shot
      end
      # EBDX uses the SAME interpolated vector for the room, trainer anchors
      # and battler world projection. Never create a second render camera.
      @vector.update
    end
    super
  end
end
if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSLayeredEBDXCamera)
  Battle::Scene.prepend(BSSLayeredEBDXCamera)
end
