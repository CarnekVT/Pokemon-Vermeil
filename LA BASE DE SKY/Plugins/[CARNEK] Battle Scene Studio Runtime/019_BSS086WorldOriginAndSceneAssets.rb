#===============================================================================
# Battle Scene Studio v0.8.6
# Logical EBDX origin authority + stable asset-layer scenes.
#
# Wide bitmaps are storage/coverage only. EBDX gameplay coordinates remain in
# the original 384x308 logical room. Every room-space sprite receives the same
# physical-content origin as the background exactly once. This prevents wide
# EBDX/custom backgrounds from throwing battlers and scenery into a corner.
#===============================================================================
module BSS086
  VERSION = "0.8.6"
  module_function

  def clamp(v,a,b)
    [[v,a].max,b].min
  end
end

module BSS086LogicalWorldOrigin
  # Apply a desired physical origin as a delta, so refresh/recalibration is
  # idempotent and newly-created SOS/battler metric sprites can be corrected
  # without moving already-correct scenery a second time.
  def bss086_apply_origin_to_sprite(sp, ox, oy)
    return if !sp || (sp.disposed? rescue true)
    old_x = sp.instance_variable_get(:@bss086_origin_x).to_f
    old_y = sp.instance_variable_get(:@bss086_origin_y).to_f
    dx = ox.to_f - old_x
    dy = oy.to_f - old_y
    begin
      if dx != 0.0 && sp.respond_to?(:ex) && sp.respond_to?(:ex=) && !sp.ex.nil?
        sp.ex = sp.ex.to_f + dx
      end
      if dy != 0.0 && sp.respond_to?(:ey) && sp.respond_to?(:ey=) && !sp.ey.nil?
        sp.ey = sp.ey.to_f + dy
      end
      sp.instance_variable_set(:@bss086_origin_x, ox.to_f)
      sp.instance_variable_set(:@bss086_origin_y, oy.to_f)
    rescue
    end
  end

  def bss086_logical_world_origin
    row = @bss_wide_world_origin
    return [0.0,0.0] if !row || !row.respond_to?(:[])
    [row[0].to_f,row[1].to_f]
  rescue
    [0.0,0.0]
  end

  def bss086_sync_world_origin!(metrics_only=false)
    ox,oy = bss086_logical_world_origin
    return if ox == 0.0 && oy == 0.0
    (@sprites || {}).each do |key,sp|
      k=key.to_s
      next if k=="bg" || k=="void"
      if metrics_only
        next unless k.start_with?("battler") || k.start_with?("shadow") || k.start_with?("trainer_")
      end
      # Screen-space weather particles do not use room authored EX/EY.
      next if k.start_with?("w_rain") || k.start_with?("w_snow") || k.start_with?("w_sand") || k.start_with?("w_fog") || k.start_with?("w_sunny")
      bss086_apply_origin_to_sprite(sp,ox,oy)
    end
  end

  def adjustMetrics
    ret=super
    bss086_sync_world_origin!(true)
    ret
  end

  def refresh(*args)
    ret=super
    if args[0].is_a?(Hash)
      bss086_sync_world_origin!(false)
      # Apply corrected metrics immediately. Waiting for the next room update is
      # what caused the visible one-frame corner jump after refresh/SOS.
      position rescue nil
    end
    ret
  end

  # Physical wide worlds also need the same translation for stage lights whose
  # EX/EY is recalculated every frame and would otherwise overwrite the fix.
  def stageLightPos(j)
    pos=super
    return pos if !pos || !pos.respond_to?(:[]) || pos.length<2
    ox,oy=bss086_logical_world_origin
    [pos[0].to_f+ox,pos[1].to_f+oy]
  rescue
    super
  end

  # v0.8.5 added a second parallax transform after EBDX#position. Because it was
  # applied to the already-transformed X/Y/zoom each frame it accumulated drift.
  # Reassert the single EBDX transform from immutable EX/EY for legacy
  # canvasLayer scenes. New 0.8.6 scenes are ordinary EBDX img### layers and do
  # not need this compatibility path at all.
  def position
    ret=super
    bg=@sprites && @sprites["bg"]
    return ret if !bg || !bg.respond_to?(:zoom_x)
    (@data || {}).each do |key,data|
      next unless key.to_s.include?("img") && data.is_a?(Hash) && data[:canvasLayer] == true
      sp=@sprites[key.to_s] || @sprites[key]
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:ex) || sp.ex.nil? || !sp.respond_to?(:ey) || sp.ey.nil?
      begin
        sp.x = bg.x - (bg.ox - sp.ex.to_f) * bg.zoom_x if sp.respond_to?(:x=)
        sp.y = bg.y - (bg.oy - sp.ey.to_f) * bg.zoom_y if sp.respond_to?(:y=)
        zx=(sp.respond_to?(:zx) && sp.zx) ? sp.zx.to_f : 1.0
        zy=(sp.respond_to?(:zy) && sp.zy) ? sp.zy.to_f : 1.0
        sp.zoom_x=bg.zoom_x*zx if sp.respond_to?(:zoom_x=)
        sp.zoom_y=bg.zoom_y*zy if sp.respond_to?(:zoom_y=)
        sp.z=[[sp.z.to_i,-500].max,14].min if sp.respond_to?(:z=)
      rescue
      end
    end
    ret
  end

  # drawImg/tree colorization occurs before refresh finishes calculating
  # @bss_wide_world_origin. Infer the physical center offset from the target
  # bitmap so colorize samples the same pixel the sprite will actually occupy.
  def setColor(target, sprite, color=true)
    return if !target || !target.bitmap || !sprite || !sprite.respond_to?(:ex) || !sprite.respond_to?(:ey) || sprite.ex.nil? || sprite.ey.nil?
    begin
      ox=[(target.bitmap.width.to_f-384.0)/2.0,0.0].max
      oy=[(target.bitmap.height.to_f-308.0)/2.0,0.0].max
      sx=BSS086.clamp((sprite.ex.to_f+ox).round,0,target.bitmap.width-1)
      sy=BSS086.clamp((sprite.ey.to_f+oy).round,0,target.bitmap.height-1)
      c=target.bitmap.get_pixel(sx,sy)
      a=(color=="slight") ? 128 : 255
      sprite.colorize(c,a)
      return
    rescue
    end
    super
  end
end

begin
  if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS086LogicalWorldOrigin)
    BSS070EBDXRoom.prepend(BSS086LogicalWorldOrigin)
  end
rescue => e
  BSS064.log("BSS086 logical world origin install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# Scene-side guard: a room refresh should settle geometry in the same frame. It
# deliberately does not add any camera movement or extra projection.
module BSS086SceneSameFrameSync
  def bss070_ebdx_recalibrate_if_needed(*args)
    ret=super
    begin
      room=@bss070_ebdx_room
      if room && !(room.disposed? rescue true)
        room.bss086_sync_world_origin!(true) if room.respond_to?(:bss086_sync_world_origin!)
        room.position rescue nil
      end
    rescue
    end
    ret
  end
end

begin
  if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS086SceneSameFrameSync)
    Battle::Scene.prepend(BSS086SceneSameFrameSync)
  end
rescue => e
  BSS064.log("BSS086 same-frame sync install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
