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
    evening=clamp(1.0-(h-18.4).abs/2.1,0.0,1.0)
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
    if @bss_layered_extra.is_a?(Array)
      @bss_layered_extra.each do |sprite|
        sprite.dispose if sprite && !(sprite.disposed? rescue true)
      rescue StandardError
      end
    end
    @bss_layered_extra=nil
    @bss_layered_ranges=nil
    @bss_layered_source=nil
    @bss_layered_last_key=nil
  end

  def bss_layered_split!
    return if !BSSLayeredLighting.outdoor?(@data)
    bg=@sprites.is_a?(Hash) ? @sprites["bg"] : nil
    return if !bg || !bg.bitmap || bg.bitmap.disposed?
    bmp=bg.bitmap
    width=bmp.width.to_i;height=bmp.height.to_i
    return if width<16 || height<48
    # Optional artist-authored split coordinates (native bitmap pixels).
    sky_end=BSSLayeredLighting.clamp(BSSLayeredLighting.config_value(@data,"skySplitY",height*0.30),8,height-16).round
    horizon_end=BSSLayeredLighting.clamp(BSSLayeredLighting.config_value(@data,"horizonSplitY",height*0.43),sky_end+4,height-4).round
    return unless horizon_end>sky_end
    @bss_layered_source=bmp
    @bss_layered_ranges=[[0,sky_end],[sky_end,horizon_end],[horizon_end,height]]
    @bss_layered_extra=[]
    # src_rect is a GPU-level crop; unlike a new bitmap it costs no pixel loops.
    bg.src_rect.set(0,0,width,sky_end)
    [1,2].each do |i|
      y0,y1=@bss_layered_ranges[i]
      part=Sprite.new(@viewport)
      part.bitmap=bmp
      part.src_rect.set(0,y0,width,y1-y0)
      @bss_layered_extra << part
    end
    bss_layered_sync!
    bss_layered_apply_tone!(true)
  rescue StandardError => e
    BSS064.log("BSS layered split warning: #{e.class}: #{e.message}") if defined?(BSS064)
    bss_layered_release!
    if bg && bg.bitmap && !bg.bitmap.disposed?
      bg.src_rect.set(0,0,bg.bitmap.width,bg.bitmap.height)
    end
  end

  def bss_layered_sync!
    return unless @bss_layered_extra && @bss_layered_ranges
    bg=@sprites["bg"] rescue nil
    return if !bg || (bg.disposed? rescue true)
    @bss_layered_extra.each_with_index do |part,index|
      next if !part || (part.disposed? rescue true)
      y0=@bss_layered_ranges[index+1][0]
      # src_rect origin is local to the slice, not global bitmap coordinates.
      part.x=bg.x;part.y=bg.y
      part.ox=bg.ox;part.oy=bg.oy-y0
      part.z=bg.z
      part.zoom_x=bg.zoom_x;part.zoom_y=bg.zoom_y
      part.angle=bg.angle
      part.opacity=bg.opacity
      part.visible=bg.visible
    end
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
    sky_tone=BSSLayeredLighting.tone(light,0.24)
    horizon_tone=BSSLayeredLighting.tone(light,0.28)
    ground_tone=BSSLayeredLighting.tone(light,0.68)
    bg.tone=sky_tone
    if @bss_layered_extra && @bss_layered_extra.length==2
      horizon,ground=@bss_layered_extra
      horizon.tone=horizon_tone
      horizon.color=Color.new(238,142,83,(90*warmth).round)
      ground.tone=ground_tone
      ground.color=Color.new(36,62,70,slot==:night ? 26 : 0)
    else
      bg.tone=ground_tone
    end

    @sprites.each do |name,sp|
      next if !sp || (sp.disposed? rescue true)
      # EBDX's source trees can be almost black at dusk/night; lift them into
      # blue-green instead of forcing the original solid black silhouette.
      if name =~ /\A(?:tree|grass)\d+\z/i
        sp.tone=BSSLayeredLighting.tone(light,0.30) if sp.respond_to?(:tone=)
        if sp.respond_to?(:color=)
          alpha=slot==:day ? 0 : (slot==:dawn ? 106 : 140)
          sp.color=Color.new(45,85,80,alpha)
        end
      elsif name=="base" || name=="water"
        sp.tone=ground_tone if sp.respond_to?(:tone=)
      end
    end
  rescue StandardError => e
    BSS064.log("BSS layered lighting warning: #{e.class}: #{e.message}") if defined?(BSS064)
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
    bss_layered_sync!
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
  def bss070_ebdx_tick(advance_camera=true,align=true)
    active=respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    if active && @vector && advance_camera && !@bss084_native_move_active &&
       @bss070_ebdx_suspend_depth.to_i<=0 &&
       !(defined?(BSS102) && BSS102.respond_to?(:static_camera?) && BSS102.static_camera?(self))
      @vector.update
      @bss_layered_camera_tick=@bss_layered_camera_tick.to_i+1
      if @bss_layered_camera_tick>=@bss_layered_camera_due.to_i &&
         !@bss_in_command_menu && !@bss_entering_fight &&
         respond_to?(:bss102_next_ambient_target)
        bss102_next_ambient_target
        @bss_layered_camera_due=@bss_layered_camera_tick+150
      end
    end
    super
  end
end
if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSLayeredEBDXCamera)
  Battle::Scene.prepend(BSSLayeredEBDXCamera)
end
