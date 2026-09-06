#===============================================================================
# Battle Scene Studio v0.8.19
# Fidelity architecture pass.
# - Runtime uses editor-rasterized PNGs for warp/local blur when available.
# - EBDX camera is ambient-only (or static); commands/moves never request shots.
# - Room animation advances at most once per rendered Graphics frame.
# - Custom wind/rotate use absolute frame time, never number of update calls.
# - Day/night and forest lights use restrained readable values.
#===============================================================================
module BSS098
  VERSION = "0.8.19"
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

  def deep_copy(v)
    Marshal.load(Marshal.dump(v))
  rescue
    if v.is_a?(Hash)
      out={}; v.each{|k,x| out[k]=deep_copy(x)}; out
    elsif v.is_a?(Array)
      v.map{|x| deep_copy(x)}
    else
      v
    end
  end

  def hash_get(h, key)
    return nil unless h.is_a?(Hash)
    h[key] || h[key.to_s] || h[key.to_sym]
  rescue
    nil
  end

  # Runtime scene data is a private room copy. When Maker Studio generated an
  # exact raster for a custom deformation/local blur, swap only that runtime
  # copy to the PNG and remove the expensive mesh/blur instructions.
  def prepare_scene(data)
    out=deep_copy(data)
    return out unless out.is_a?(Hash)
    out.each do |raw_key,row|
      next unless raw_key.to_s =~ /^img\d+/i && row.is_a?(Hash)
      rr=hash_get(row,:runtimeRaster)
      if rr.is_a?(Hash)
        path=hash_get(rr,:bitmap).to_s.strip
        ok=!path.empty? && (pbResolveBitmap(path) rescue false)
        if ok
          row[:bitmap]=path
          row[:ox]=num(hash_get(rr,:ox), row[:ox] || 0)
          row[:oy]=num(hash_get(rr,:oy), row[:oy] || 0)
          row.delete(:warp); row.delete("warp")
          row.delete(:blurAreas); row.delete("blurAreas")
          row.delete(:blur); row.delete("blur")
          row[:bss_rasterized]=true
        end
      end
      # Source EBDX's wind rebuilds/skews bitmaps and rotate increments on every
      # method call. Rename them so the final absolute-time authority below owns
      # those two effects exactly once per rendered frame.
      effect=hash_get(row,:effect).to_s
      if effect=="wind"
        row[:effect]="bss_wind"
      elsif effect=="rotate"
        row[:effect]="bss_rotate"
      end
    end
    out
  rescue => e
    BSS064.log("BSS098 prepare scene warning: #{e.class}: #{e.message}") if defined?(BSS064)
    data
  end
end

# Flatten runtimeRaster at the final room constructor/refresh boundary. This is
# deliberately after BSS090's JSON normalization.
module BSS098RuntimeRasterAuthority
  def initialize(viewport, scene, data)
    super(viewport, scene, BSS098.prepare_scene(data))
  end

  def refresh(*args)
    if args[0].is_a?(Hash)
      copy=args.clone
      copy[0]=BSS098.prepare_scene(args[0])
      return super(*copy)
    end
    super
  end
end

# One environmental simulation step per rendered frame. Previous guards still
# called position() on duplicate updates, and position() itself advanced wind,
# rotation and lights. That is why move animations changed background speed.
module BSS098SingleFrameEnvironment
  def update
    frame=(Graphics.frame_count rescue nil)
    if !frame.nil?
      return if @bss098_last_environment_frame == frame
      @bss098_last_environment_frame = frame
    end
    super
  end

  def position
    ret=super
    frame=(Graphics.frame_count rescue 0).to_f
    begin
      (@data || {}).each do |raw_key,row|
        next unless raw_key.to_s =~ /^img\d+/i && row.is_a?(Hash)
        sp=@sprites[raw_key.to_s] || @sprites[raw_key]
        next if !sp || (sp.disposed? rescue true)
        effect=BSS098.hash_get(row,:effect).to_s
        base=BSS098.num(BSS098.hash_get(row,:angle),0.0)
        speed=[BSS098.num(BSS098.hash_get(row,:speed),1.0).abs,0.01].max
        direction=BSS098.num(BSS098.hash_get(row,:direction),1.0) < 0 ? -1.0 : 1.0
        if effect=="bss_wind"
          # Bottom-pivot sway, not bitmap skew. Gentle by default and stable
          # regardless of how often a move/plugin asks the room to update.
          amp=(@strongwind ? 2.2 : 0.9) * [speed,2.5].min
          seed=(raw_key.to_s.gsub(/\D/,"").to_i * 0.41)
          sp.angle=base + Math.sin(frame*0.022 + seed)*amp if sp.respond_to?(:angle=)
        elsif effect=="bss_rotate"
          sp.angle=(base + direction*speed*frame*0.35) % 360.0 if sp.respond_to?(:angle=)
        end
      end

      # Native EBDX vegetation: readable, low-amplitude ambient sway.
      (@sprites || {}).each do |key,sp|
        next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:angle=)
        s=key.to_s
        if s =~ /^tree(\d+)/i
          idx=$1.to_i; sp.angle=Math.sin(frame*0.018 + idx*0.53)*(@strongwind ? 1.55 : 0.55)
        elsif s =~ /^grass(\d+)/i
          idx=$1.to_i; sp.angle=Math.sin(frame*0.023 + idx*0.37)*(@strongwind ? 1.85 : 0.72)
        elsif s =~ /^[ac]Light(\d+)/i
          # Replace sharp opacity toggling with a slow, shallow pulse.
          idx=$1.to_i
          max_op=((sp.respond_to?(:end_x) ? sp.end_x.to_f : 1.0)*255.0)
          max_op=220.0 if max_op<=0 || max_op>255
          min_op=[max_op*0.82,105.0].max
          wave=(Math.sin(frame*0.020 + idx*0.91)+1.0)*0.5
          sp.opacity=(min_op+(max_op-min_op)*wave).round if sp.respond_to?(:opacity=)
        end
      end
    rescue => e
      BSS064.log("BSS098 ambient element warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    ret
  end

  # Source values were dark enough to crush most pixel detail. Keep time-of-day
  # readable while still visibly different.
  def daylightTint
    return if !@data.try_key?("sky", "outdoor") rescue nil
    (@sprites || {}).each do |key,sp|
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:tone=)
      s=key.to_s
      next if s.include?("trainer") || s.include?("battler") || s.include?("sky") || s.include?("sun") || s.include?("star") || s.include?("cloud") || s.include?("Light")
      row=@data[key] rescue nil
      next if row.is_a?(Hash) && BSS098.hash_get(row,:shading) == false
      if (PBDayNight.isNight? rescue false) && !@sunny
        sp.tone=Tone.new(-34,-30,-18,0)
      elsif ((PBDayNight.isEvening? rescue false) || (PBDayNight.isMorning? rescue false)) && !@sunny
        sp.tone=Tone.new(-8,-20,-20,0)
      else
        sp.tone=Tone.new(0,0,0,0)
      end
    end
  rescue
    super
  end
end

# BSS camera now has two meanings only:
#   EBDX   -> source-like ambient drift while the battle is idle/ongoing.
#   static -> no automatic BSS camera movement.
# Commands, Fight, native moves, sendout, SOS, capture and turn end no longer
# request context shots or MAIN resets. BAS can still author its own camera.
module BSS098AmbientOnlyCamera
  def bss098_static_camera?
    cfg=bss070_ebdx_camera_config rescue {}
    raw=(cfg["profile"] || cfg[:profile] || cfg["preset"] || cfg[:preset]).to_s.downcase
    raw=="static"
  rescue
    false
  end

  def bss084_context_config(key)
    k=key.to_s
    if k=="bas"
      return {"enabled"=>true,"mode"=>"authored","frames"=>0,"strength"=>100}
    end
    if k=="idle"
      return {"enabled"=>!bss098_static_camera?,"mode"=>(bss098_static_camera? ? "hold" : "drift"),"frames"=>0,"strength"=>100}
    end
    {"enabled"=>false,"mode"=>"hold","frames"=>0,"strength"=>0}
  end

  def bss087_request_camera_context(*args)
    false
  end

  def bss084_transition_context(*args)
    false
  end

  def bss070_ebdx_camera_enter(*args)
    @bss087_camera_tween=nil unless @bss070_ebdx_bas_frame
    nil
  end

  def bss070_ebdx_camera_leave(*args)
    nil
  end

  def bss096_camera_to_main(*args)
    nil
  end

  # Keep native/BAS animation ownership flags, but do not touch the world camera
  # and do not force MAIN at the end of each hit/move.
  def bss083_with_move_projection(user=nil, targets=nil, camera_cut=true)
    outer=!@bss098_native_move_active
    if outer
      @bss098_native_move_active=true
      @bss087_native_move_active=true
      @bss084_native_move_active=true
    end
    yield
  ensure
    if outer
      @bss098_native_move_active=false
      @bss087_native_move_active=false
      @bss084_native_move_active=false
      @bss083_animation_projection=false
      @bss083_animation_raw=nil
      begin
        @bss070_ebdx_room.position if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      rescue
      end
    end
  end

  def bss070_ebdx_tick(advance_camera=true, align=true)
    @bss087_camera_tween=nil unless @bss070_ebdx_bas_frame
    super(advance_camera && !bss098_static_camera?, align)
  end
end

# Native Essentials destination remains the sendout/reveal point. Keep the new
# tumbling animation from v0.8.18, but do not substitute a second battler anchor.
begin
  if defined?(BSS096BallHelpers)
    module BSS096BallHelpers
      module_function
      def endpoint(_animation, fallback_x, fallback_y)
        [BSS096.clamp(fallback_x,18,Graphics.width-18),BSS096.clamp(fallback_y,22,Graphics.height-22)]
      rescue
        [fallback_x.to_f,fallback_y.to_f]
      end
    end
  end
rescue
end

begin
  if defined?(BSS070EBDXRoom)
    BSS070EBDXRoom.prepend(BSS098RuntimeRasterAuthority) unless BSS070EBDXRoom.ancestors.include?(BSS098RuntimeRasterAuthority)
    BSS070EBDXRoom.prepend(BSS098SingleFrameEnvironment) unless BSS070EBDXRoom.ancestors.include?(BSS098SingleFrameEnvironment)
  end
rescue => e
  BSS064.log("BSS098 room install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSS098AmbientOnlyCamera) unless Battle::Scene.ancestors.include?(BSS098AmbientOnlyCamera)
  end
rescue => e
  BSS064.log("BSS098 camera install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

module BSS098CustomSky
  def drawSky
    ret=super
    begin
      mode=(@data["skyMode"] || @data[:skyMode] || "dynamic").to_s
      return ret if mode.empty? || mode=="dynamic"
      path=case mode
           when "day" then "Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyDay"
           when "dawn" then "Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyDawn"
           when "night" then "Graphics/BattleSceneStudio/EBDX/Battlebacks/elements/skyNight"
           else mode
           end
      if @sprites && @sprites["sky"] && (pbResolveBitmap(path) rescue false)
        bmp=pbBitmap(path)
        @sprites["sky"].bitmap=bmp
        @sprites["sky"].oy=bmp.height
        @sprites["sky"].ex=0
        @sprites["sky"].ey=bmp.height
        @sprites["sky"].param=1
      end
    rescue => e
      BSS064.log("BSS098 custom sky warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    ret
  end
end

begin
  if defined?(BSS070EBDXRoom)
    BSS070EBDXRoom.prepend(BSS098CustomSky) unless BSS070EBDXRoom.ancestors.include?(BSS098CustomSky)
  end
rescue => e
  BSS064.log("BSS098 custom sky install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
