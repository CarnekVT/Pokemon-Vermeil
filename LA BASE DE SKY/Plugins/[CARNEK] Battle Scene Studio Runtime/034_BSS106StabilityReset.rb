#===============================================================================
# Battle Scene Studio v0.8.34
# Stability reset authority.
#
# This file deliberately replaces the last incremental camera/party-animation
# behaviour with a small terminal contract:
#   * EBDX scenery is ALWAYS background scenery during BAS/native animations.
#   * Send Out/Recall run the project's native implementation at the CURRENT
#     camera frame; no extra MAIN/SENDOUT snap and no projected pbBattlerPosition.
#   * SOS join freezes camera retargeting while its reflow animation runs.
#   * hidden editor layers are removed from the runtime room copy.
#   * an authored warp without a generated raster falls back to the source image
#     instead of drawing the old micro-tile mesh seams.
#===============================================================================
module BSS106
  VERSION = "0.8.34"
  module_function

  def room(scene)
    r=scene.instance_variable_get(:@bss070_ebdx_room) rescue nil
    if (!r || (r.disposed? rescue false)) && (scene.instance_variable_get(:@sprites) rescue nil).is_a?(Hash)
      r=scene.instance_variable_get(:@sprites)["battlebg"] rescue nil
    end
    r
  rescue
    nil
  end

  def native_scene_method(scene,name)
    m=scene.method(name) rescue nil
    m=m.super_method if m
    while m
      owner=m.owner.to_s
      return m if owner=="Battle::Scene" || (owner !~ /BSS|EBDX|BattleSceneStudio/i && owner !~ /SceneBridge|Authority|CameraSync/i)
      m=m.super_method
    end
    nil
  rescue
    nil
  end

  def camera_state(scene)
    v=scene.instance_variable_get(:@vector) rescue nil
    return nil unless v
    {
      :target => (v.instance_variable_get(:@set).dup rescue nil),
      :inc    => (v.inc rescue nil),
      :due102 => (scene.instance_variable_get(:@bss102_ambient_due) rescue nil),
      :idx102 => (scene.instance_variable_get(:@bss102_ambient_index) rescue nil)
    }
  rescue
    nil
  end

  def restore_camera_target(scene,state)
    return unless scene && state
    v=scene.instance_variable_get(:@vector) rescue nil
    return unless v
    v.inc=state[:inc] if !state[:inc].nil? && v.respond_to?(:inc=)
    v.set(state[:target]) if state[:target] && v.respond_to?(:set)
    scene.instance_variable_set(:@bss102_ambient_due,state[:due102]) unless state[:due102].nil?
    scene.instance_variable_set(:@bss102_ambient_index,state[:idx102]) unless state[:idx102].nil?
  rescue => e
    BSS064.log("BSS106 restore target warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end


  def hex_color(str, alpha=255)
    s=str.to_s.strip
    return nil unless s =~ /\A#?([0-9a-fA-F]{6})\z/
    h=$1
    Color.new(h[0,2].to_i(16),h[2,2].to_i(16),h[4,2].to_i(16),[[alpha.to_i,0].max,255].min)
  rescue
    nil
  end

  def time_slot
    return :night if defined?(PBDayNight) && PBDayNight.respond_to?(:isNight?) && PBDayNight.isNight?
    if defined?(PBDayNight) && ((PBDayNight.respond_to?(:isEvening?) && PBDayNight.isEvening?) || (PBDayNight.respond_to?(:isMorning?) && PBDayNight.isMorning?))
      return :dawn
    end
    :day
  rescue
    :day
  end

  def apply_authored_tint!(row)
    return row unless row.is_a?(Hash)
    slot=time_slot
    prefix=(slot==:night ? 'Night' : (slot==:dawn ? 'Dawn' : 'Day'))
    color=row[("tint#{prefix}Color").to_sym] || row["tint#{prefix}Color"] || row[:tintColor] || row["tintColor"]
    alpha=row[("tint#{prefix}Alpha").to_sym] || row["tint#{prefix}Alpha"] || row[:tintAlpha] || row["tintAlpha"]
    a=alpha.nil? ? 0 : alpha.to_i
    if a>0
      c=hex_color(color,a)
      row[:colorize]=c if c
    end
    row
  rescue
    row
  end
  def prune_hidden!(data)
    return data unless data.is_a?(Hash)
    data.keys.clone.each do |k|
      row=data[k]
      if k.to_s =~ /^img\d+/i && row.is_a?(Hash)
        if (row[:hidden] == true || row["hidden"] == true)
          data.delete(k)
          next
        end
        apply_authored_tint!(row)
        # Visible deformations require the editor-rasterized PNG. If it wasn't
        # written, prefer the intact source art over the seam-heavy micro mesh.
        warp=row[:warp] || row["warp"]
        rr=row[:runtimeRaster] || row["runtimeRaster"]
        if warp.is_a?(Hash)
          path=(rr.is_a?(Hash) ? (rr[:bitmap] || rr["bitmap"]).to_s : "")
          valid=!path.empty? && (pbResolveBitmap(path) rescue false)
          unless valid
            row.delete(:warp); row.delete("warp")
            row[:bss_warp_fallback]=true
          end
        end
      elsif (k.to_s=="trees" || k.to_s=="tallGrass") && row.is_a?(Hash)
        hidden=row[:hidden] || row["hidden"]
        if hidden.is_a?(Array) && hidden.any?
          keys=[:x,:y,:z,:zoom,:mirror]
          count=(row[:elements] || row["elements"] || 0).to_i
          keep=(0...count).reject{|i| hidden[i] == true}
          keys.each do |kk|
            arr=row[kk] || row[kk.to_s]
            next unless arr.is_a?(Array)
            row[kk]=keep.map{|i|arr[i]}
            row.delete(kk.to_s)
          end
          row[:elements]=keep.length
          row.delete(:hidden); row.delete("hidden")
        end
      end
    end
    data
  rescue => e
    BSS064.log("BSS106 hidden/warp prune warning: #{e.class}: #{e.message}") if defined?(BSS064)
    data
  end
end

# Runtime scene preparation: honour visibility and never show mesh seams as a
# fallback when Generated/... is missing.
if defined?(BSS098)
  class << BSS098
    unless method_defined?(:bss106_prepare_scene_before)
      alias_method :bss106_prepare_scene_before, :prepare_scene
    end
    def prepare_scene(data)
      out=bss106_prepare_scene_before(data)
      BSS106.prune_hidden!(out)
    end
  end
end

# The projected pbBattlerPosition introduced for v0.8.27 is the main cause of
# Ball/party endpoints being calculated in a different coordinate space than
# the native animation. Keep pbBattlerPosition native; live battler sprites are
# still aligned to the EBDX room by BSS103 outside the party animation itself.
if defined?(BSS082BattlerPositionAuthority)
  module BSS082BattlerPositionAuthority
    def pbBattlerPosition(index, sideSize=1)
      super(index,sideSize)
    end
  end
end

# Strong scenery priority. EBDX's original -100 defocus is not enough for every
# BAS Z layout. While an animation owns the scene, put EVERY room sprite into a
# dedicated deep-background band and restore the exact Zs afterwards.
module BSS106RoomPriority
  def bss106_push_behind!
    @bss106_priority_depth=@bss106_priority_depth.to_i+1
    return true if @bss106_priority_depth>1
    @bss106_saved_z={}
    (@sprites || {}).each do |k,sp|
      next unless sp && !(sp.disposed? rescue true) && sp.respond_to?(:z) && sp.respond_to?(:z=)
      @bss106_saved_z[k]=sp.z.to_i
      sp.z=[sp.z.to_i-10_000,-5_000].min
    end
    @bss106_force_behind=true
    true
  rescue
    false
  end

  def bss106_pop_behind!
    @bss106_priority_depth=[@bss106_priority_depth.to_i-1,0].max
    return true if @bss106_priority_depth>0
    saved=@bss106_saved_z || {}
    (@sprites || {}).each do |k,sp|
      next unless sp && !(sp.disposed? rescue true) && sp.respond_to?(:z=)
      sp.z=saved[k] if saved.key?(k)
    end
    @bss106_saved_z=nil
    @bss106_force_behind=false
    true
  rescue
    false
  end

  def drawWater
    ret=super
    begin
      z0=(BSS098.hash_get(@data,:waterBaseZ) rescue nil)
      z1=(BSS098.hash_get(@data,:waterFxZ) rescue nil)
      @sprites["water0"].z=z0.to_i if !z0.nil? && @sprites["water0"] && @sprites["water0"].respond_to?(:z=)
      @sprites["water1"].z=z1.to_i if !z1.nil? && @sprites["water1"] && @sprites["water1"].respond_to?(:z=)
    rescue
    end
    ret
  end

  def drawSky
    ret=super
    begin
      cfg=BSS098.hash_get(@data,:cloudsConfig) rescue nil
      if cfg.is_a?(Hash)
        enabled=BSS098.hash_get(cfg,:enabled)
        slot=(BSS098.hash_get(@data,:skyMode).to_s rescue '')
        slot=(BSS106.time_slot.to_s if slot.empty? || slot=='dynamic')
        key=(slot=='night' ? :nightColor : (slot=='dawn' ? :dawnColor : :dayColor))
        color=BSS106.hex_color(BSS098.hash_get(cfg,key) || '#dfefff',255)
        for i in 0..1
          sp=@sprites["cloud#{i}"] rescue nil
          next unless sp && !(sp.disposed? rescue true)
          sp.visible=(enabled != false) if sp.respond_to?(:visible=)
          sp.colorize(color,255) if color && sp.respond_to?(:colorize)
          x=BSS098.hash_get(cfg,("cloud#{i+1}X").to_sym)
          y=BSS098.hash_get(cfg,("cloud#{i+1}Y").to_sym)
          speed=BSS098.hash_get(cfg,("cloud#{i+1}Speed").to_sym)
          dir=BSS098.hash_get(cfg,("cloud#{i+1}Direction").to_sym)
          op=BSS098.hash_get(cfg,("cloud#{i+1}Opacity").to_sym)
          sp.ex=x.to_f if !x.nil? && sp.respond_to?(:ex=)
          sp.ey=y.to_f if !y.nil? && sp.respond_to?(:ey=)
          sp.speed=speed.to_f if !speed.nil? && sp.respond_to?(:speed=)
          sp.direction=dir.to_i if !dir.nil? && sp.respond_to?(:direction=)
          sp.opacity=op.to_i if !op.nil? && sp.respond_to?(:opacity=)
        end
      end
    rescue => e
      BSS064.log("BSS106 cloud config warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    ret
  end

  def position
    ret=super
    if @bss106_force_behind
      (@sprites || {}).each_value do |sp|
        next unless sp && !(sp.disposed? rescue true) && sp.respond_to?(:z) && sp.respond_to?(:z=)
        sp.z=[sp.z.to_i,-5_000].min
      end
      # Warp tiles are not part of @sprites, so force those too if a legacy
      # scene still reached the mesh authority.
      if @bss093_warp_layers.is_a?(Hash)
        @bss093_warp_layers.each_value do |row|
          (row[:tiles] || []).each do |entry|
            sp=entry[:sprite] rescue nil
            sp.z=-5_000 if sp && !(sp.disposed? rescue true) && sp.respond_to?(:z=)
          end
        end
      end
    end
    ret
  end
end

begin
  if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS106RoomPriority)
    BSS070EBDXRoom.prepend(BSS106RoomPriority)
  end
rescue => e
  BSS064.log("BSS106 room-priority install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# Replace the v0.8.27 party sync with a minimal freeze. No current-vector snap,
# no pbBattlerPosition projection, and no post-animation re-centering.
if defined?(BSS104PartyCameraSync)
  module BSS104PartyCameraSync
    def bss104_with_party_camera_sync
      return yield unless defined?(BSS104) && BSS104.active?(self)
      state=BSS106.camera_state(self)
      old=@bss106_party_camera_freeze
      @bss106_party_camera_freeze=true
      yield
    ensure
      @bss106_party_camera_freeze=old
      BSS106.restore_camera_target(self,state) if state
      begin
        bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
        room=BSS106.room(self); room.update if room && !(room.disposed? rescue true)
        bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
      rescue
      end
    end

    def bss100_graphics_frame
      if @bss106_party_camera_freeze && respond_to?(:bss070_ebdx_tick)
        return bss070_ebdx_tick(false,false)
      end
      super
    end
  end
end

# Terminal scene authority: animation priority + native party transitions + SOS
# camera freeze. This deliberately bypasses the old SendOut/Recall wrapper pile.
module BSS106SceneStability
  def bss070_ebdx_tick(advance_camera=true,align=true)
    advance_camera=false if @bss106_party_camera_freeze || @bss106_sos_camera_freeze || @bss106_transition_freeze
    super(advance_camera,align)
  end

  def bss070_ebdx_suspend_world(*args,&block)
    room=BSS106.room(self)
    room.bss106_push_behind! if room && room.respond_to?(:bss106_push_behind!)
    super
  ensure
    room.bss106_pop_behind! if room && room.respond_to?(:bss106_pop_behind!)
  end

  def pbSendOutBattlers(*args,&block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    state=BSS106.camera_state(self); old=@bss106_party_camera_freeze; @bss106_party_camera_freeze=true
    m=BSS106.native_scene_method(self,:pbSendOutBattlers)
    return m.call(*args,&block) if m
    super
  ensure
    @bss106_party_camera_freeze=old
    BSS106.restore_camera_target(self,state) if state
    begin
      bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
      room=BSS106.room(self); room.update if room && !(room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
    rescue
    end
  end

  def pbRecall(*args,&block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    state=BSS106.camera_state(self); old=@bss106_party_camera_freeze; @bss106_party_camera_freeze=true
    m=BSS106.native_scene_method(self,:pbRecall)
    return m.call(*args,&block) if m
    super
  ensure
    @bss106_party_camera_freeze=old
    BSS106.restore_camera_target(self,state) if state
    begin
      bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
      room=BSS106.room(self); room.update if room && !(room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
    rescue
    end
  end

  def bss_pbSOSJoin(*args,&block)
    old=@bss106_sos_camera_freeze; @bss106_sos_camera_freeze=true
    super
  ensure
    @bss106_sos_camera_freeze=old
    begin
      bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
      room=BSS106.room(self); room.update if room && !(room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
    rescue
    end
  end
end

begin
  if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS106SceneStability)
    Battle::Scene.prepend(BSS106SceneStability)
  end
rescue => e
  BSS064.log("BSS106 scene-stability install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
