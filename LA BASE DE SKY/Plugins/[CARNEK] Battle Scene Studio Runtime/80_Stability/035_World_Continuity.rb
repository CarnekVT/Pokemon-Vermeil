#===============================================================================
# Battle Scene Studio v0.8.36
# World continuity authority.
#
# One terminal contract for the remaining unstable cases:
# - ambient camera never changes angle/zoom/depth, only a tiny MAIN-relative pan;
# - moves/BAS/Common animations never request or settle a contextual camera shot;
# - sendout/recall/capture/SOS build their native animation coordinates from the
#   CURRENT EBDX room transform while the camera is frozen;
# - scenery is pushed behind animation sprites for the exact animation lifetime;
# - after a transition, battlers are aligned once to the current room anchors;
# - water layers have deterministic background bands if the scene did not author
#   explicit values.
#===============================================================================
module BSS108
  VERSION = "0.8.36"
  module_function

  def active?(scene)
    scene && scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?
  rescue
    false
  end

  def room(scene)
    return nil unless scene
    r=scene.instance_variable_get(:@bss070_ebdx_room) rescue nil
    if (!r || (r.disposed? rescue false)) && (scene.instance_variable_get(:@sprites) rescue nil).is_a?(Hash)
      r=scene.instance_variable_get(:@sprites)["battlebg"] rescue nil
    end
    r
  rescue
    nil
  end

  def main(scene)
    b=scene.instance_variable_get(:@battle) rescue nil
    (BSS070EBDXCore.get_vector(:MAIN,b) rescue [102,408,32,342,1,1]).map{|v|v.to_f}
  rescue
    [102.0,408.0,32.0,342.0,1.0,1.0]
  end

  def with_position_context(scene)
    if scene.respond_to?(:bss070_ebdx_with_position_context)
      scene.bss070_ebdx_with_position_context { yield }
    else
      yield
    end
  end

  def align(scene)
    return unless scene
    begin
      scene.bss070_ebdx_invalidate_anchors if scene.respond_to?(:bss070_ebdx_invalidate_anchors)
      scene.bss096_clear_native_position_cache if scene.respond_to?(:bss096_clear_native_position_cache)
    rescue
    end
    begin
      r=room(scene); r.update if r && !(r.disposed? rescue true)
      scene.bss070_ebdx_apply_world_alignment if scene.respond_to?(:bss070_ebdx_apply_world_alignment)
    rescue => e
      BSS064.log("BSS108 realign warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
  end
end

# Deterministic water/background bands. Existing authored values always win.
if defined?(BSS098)
  class << BSS098
    unless method_defined?(:bss108_prepare_scene_before)
      alias_method :bss108_prepare_scene_before, :prepare_scene
    end
    def prepare_scene(data)
      out=bss108_prepare_scene_before(data)
      if out.is_a?(Hash) && (BSS098.hash_get(out,:water) rescue false)
        has0=out.key?(:waterBaseZ) || out.key?("waterBaseZ")
        has1=out.key?(:waterFxZ) || out.key?("waterFxZ")
        out[:waterBaseZ]=-2 unless has0
        out[:waterFxZ]=1 unless has1
      end
      out
    end
  end
end

module BSS108RoomBands
  def drawWater
    ret=super
    begin
      z0=(BSS098.hash_get(@data,:waterBaseZ) rescue -2)
      z1=(BSS098.hash_get(@data,:waterFxZ) rescue 1)
      @sprites["water0"].z=z0.to_i if @sprites["water0"] && @sprites["water0"].respond_to?(:z=)
      @sprites["water1"].z=z1.to_i if @sprites["water1"] && @sprites["water1"].respond_to?(:z=)
    rescue
    end
    ret
  end
end

begin
  if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS108RoomBands)
    BSS070EBDXRoom.prepend(BSS108RoomBands)
  end
rescue => e
  BSS064.log("BSS108 room-band install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

module BSS108WorldContinuity
  # Never let an old wrapper ask for a post-action MAIN recenter. Ambient camera
  # owns the background continuously; action contexts only freeze it.
  def bss083_settle_camera(*args); nil; end
  def bss083_camera_move_context(*args); [:main,0.0]; end
  def bss083_set_camera_state(state,*args)
    @bss083_camera_state=state.to_s.downcase.to_sym rescue :idle
    @bss070_ebdx_camera_mode=@bss083_camera_state
    @bss083_camera_state
  rescue
    nil
  end

  # MAIN-relative ambient motion only. No angle/scale/zoom changes means the sea,
  # horizon and authored floor cannot suddenly consume the whole frame.
  def bss102_next_ambient_target
    return unless @vector
    main=BSS108.main(self)
    n=@bss108_ambient_step.to_i
    @bss108_ambient_step=n+1
    phase=n*Math::PI/3.0
    target=main.clone
    target[0]=main[0]+Math.sin(phase)*4.0
    target[1]=main[1]+Math.cos(phase*0.73)*1.5
    target[2]=main[2]
    target[3]=main[3]
    target[4]=main[4]
    target[5]=main[5]
    @vector.inc=0.0045 if @vector.respond_to?(:inc=)
    @vector.set(target) if @vector.respond_to?(:set)
    @bss102_ambient_due=120
  rescue => e
    BSS064.log("BSS108 ambient target warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def pbInitSprites(*args,&block)
    ret=super
    if BSS108.active?(self) && @vector
      begin
        @vector.snap(BSS108.main(self)) if @vector.respond_to?(:snap)
        @bss108_ambient_step=0
        @bss102_ambient_due=80
        BSS108.align(self)
      rescue
      end
    end
    ret
  end

  def bss070_ebdx_tick(advance_camera=true,align=true)
    advance_camera=false if @bss108_camera_lock.to_i>0
    super(advance_camera,align)
  end

  # Replace the old save/set/snap/restore stack. This method intentionally does
  # not call super: those older wrappers are exactly what created the visible
  # post-animation re-centering. Room animation continues through pbUpdate/BAS
  # pump; only vector advancement and alignment are frozen here.
  def bss070_ebdx_suspend_world(*args,&block)
    active=BSS108.active?(self)
    return yield unless active
    outer=@bss108_suspend_depth.to_i<=0
    @bss108_suspend_depth=@bss108_suspend_depth.to_i+1
    @bss070_ebdx_suspend_depth=@bss070_ebdx_suspend_depth.to_i+1
    @bss108_camera_lock=@bss108_camera_lock.to_i+1
    room=BSS108.room(self)
    room.bss106_push_behind! if outer && room && room.respond_to?(:bss106_push_behind!)
    yield
  ensure
    if active
      @bss108_camera_lock=[@bss108_camera_lock.to_i-1,0].max
      @bss070_ebdx_suspend_depth=[@bss070_ebdx_suspend_depth.to_i-1,0].max
      @bss108_suspend_depth=[@bss108_suspend_depth.to_i-1,0].max
      if outer
        begin; room.bss106_pop_behind! if room && room.respond_to?(:bss106_pop_behind!); rescue; end
        BSS108.align(self)
      end
    end
  end

  # Native/PBS move animations keep the CURRENT displayed battler positions and
  # CURRENT camera. No temporary enemy/player/impact vector and no MAIN settle.
  def bss083_with_move_projection(user=nil,targets=nil,camera_cut=true)
    active=BSS108.active?(self)
    return yield unless active
    outer=!@bss108_move_projection
    if outer
      @bss108_move_projection=true
      @bss083_animation_projection=true
      @bss108_camera_lock=@bss108_camera_lock.to_i+1
    end
    yield
  ensure
    if active && outer
      @bss108_camera_lock=[@bss108_camera_lock.to_i-1,0].max
      @bss083_animation_projection=false
      @bss108_move_projection=false
      BSS108.align(self)
    end
  end

  def bss108_party_context
    active=BSS108.active?(self)
    return yield unless active
    @bss108_camera_lock=@bss108_camera_lock.to_i+1
    @bss082_preserve_native_camera=true
    BSS108.with_position_context(self) { yield }
  ensure
    if active
      @bss082_preserve_native_camera=false
      @bss108_camera_lock=[@bss108_camera_lock.to_i-1,0].max
      BSS108.align(self)
    end
  end

  def pbSendOutBattlers(*args,&block)
    return super unless BSS108.active?(self)
    bss108_party_context { super }
  end

  def pbRecall(*args,&block)
    return super unless BSS108.active?(self)
    bss108_party_context { super }
  end

  def bss_pbSOSJoin(*args,&block)
    return super unless BSS108.active?(self)
    bss108_party_context { super }
  end

  [:pbThrow,:pbThrowAndDeflect,:pbThrowPokeBall].each do |meth|
    define_method(meth) do |*args,&block|
      return super(*args,&block) unless BSS108.active?(self)
      bss108_party_context { super(*args,&block) }
    end
  end
end

begin
  if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS108WorldContinuity)
    Battle::Scene.prepend(BSS108WorldContinuity)
  end
rescue => e
  BSS064.log("BSS108 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
