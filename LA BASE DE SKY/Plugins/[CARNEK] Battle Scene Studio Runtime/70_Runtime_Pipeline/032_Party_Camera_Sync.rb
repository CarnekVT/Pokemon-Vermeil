#===============================================================================
# Battle Scene Studio v0.8.27
# Camera-synchronized Send Out / Recall authority.
#
# Problem fixed:
# - a battler sent out while the ambient EBDX camera was mid-pan could be built
#   from a different camera frame than the world currently on screen;
# - Recall Poké Ball coordinates could use native screen-space positions while
#   the visible battler was already projected into EBDX world-space.
#
# Rule:
# - Send Out/Recall inherit the exact CURRENT EBDX frame;
# - the ambient camera pauses at that exact frame for the brief party animation;
# - animation builders receive EBDX-projected BASE coordinates, while species
#   metrics remain owned by the battler sprite/room final anchor;
# - when the animation ends, the previous ambient target resumes without a snap.
#===============================================================================
module BSS104
  VERSION = "0.8.27"
  module_function

  def active?(scene)
    scene && scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?
  rescue
    false
  end

  def camera_state(scene)
    v=scene.instance_variable_get(:@vector) rescue nil
    return nil if !v
    {
      :current => (v.get.dup rescue nil),
      :target  => ((v.instance_variable_get(:@set).dup) rescue nil),
      :inc     => (v.inc rescue nil),
      :due102  => (scene.instance_variable_get(:@bss102_ambient_due) rescue nil),
      :idx102  => (scene.instance_variable_get(:@bss102_ambient_index) rescue nil),
      :out100  => (scene.instance_variable_get(:@bss100_ambient_out) rescue nil),
      :due100  => (scene.instance_variable_get(:@bss100_ambient_due) rescue nil)
    }
  rescue
    nil
  end

  def restore_camera(scene,state)
    return if !scene || !state
    v=scene.instance_variable_get(:@vector) rescue nil
    return if !v
    v.snap(state[:current]) if state[:current] && v.respond_to?(:snap)
    v.inc=state[:inc] if !state[:inc].nil? && v.respond_to?(:inc=)
    v.set(state[:target]) if state[:target] && v.respond_to?(:set)
    scene.instance_variable_set(:@bss102_ambient_due,state[:due102]) unless state[:due102].nil?
    scene.instance_variable_set(:@bss102_ambient_index,state[:idx102]) unless state[:idx102].nil?
    scene.instance_variable_set(:@bss100_ambient_out,state[:out100]) unless state[:out100].nil?
    scene.instance_variable_set(:@bss100_ambient_due,state[:due100]) unless state[:due100].nil?
  rescue => e
    BSS064.log("BSS104 camera restore warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end
end

# BSS100 temporarily forced every animation coordinate back to native screen
# space. That was correct while battlers were screen-space, but BSS103 restored
# world-space battlers. Honor the EBDX position context again so party animations
# are built from the SAME current room transform as the visible battler.
if defined?(BSS082BattlerPositionAuthority)
  module BSS082BattlerPositionAuthority
    def pbBattlerPosition(index, sideSize=1)
      ctx=(defined?(BSS070EBDXCore) ? (BSS070EBDXCore.position_scene rescue nil) : nil)
      return super(index,sideSize) if !ctx || !(defined?(BSS104) && BSS104.active?(ctx))

      base=if defined?(BSS082) && BSS082.respond_to?(:without_position_context)
             BSS082.without_position_context { super(index,sideSize) }
           else
             super(index,sideSize)
           end
      room=ctx.instance_variable_get(:@bss070_ebdx_room) rescue nil
      return base if !room || (room.disposed? rescue true)
      if room.respond_to?(:bss082_project_screen_point)
        return room.bss082_project_screen_point(base[0],base[1])
      end
      base
    rescue => e
      BSS064.log("BSS104 projected party position warning: #{e.class}: #{e.message}") if defined?(BSS064)
      if defined?(BSS082) && BSS082.respond_to?(:without_position_context)
        BSS082.without_position_context { super(index,sideSize) }
      else
        super(index,sideSize)
      end
    end
  end
end

module BSS104PartyCameraSync
  def bss104_prepare_party_frame
    return nil unless BSS104.active?(self)
    bss070_ebdx_ensure_core if respond_to?(:bss070_ebdx_ensure_core)
    room=@bss070_ebdx_room rescue nil
    begin
      room.update if room && !(room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
    rescue
    end
    BSS104.camera_state(self)
  end

  def bss104_with_party_camera_sync
    return yield unless BSS104.active?(self)
    state=bss104_prepare_party_frame
    old_lock=@bss104_party_camera_lock
    old_preserve=@bss082_preserve_native_camera
    @bss104_party_camera_lock=true
    @bss082_preserve_native_camera=true
    if respond_to?(:bss070_ebdx_with_position_context)
      bss070_ebdx_with_position_context { yield }
    else
      yield
    end
  ensure
    @bss104_party_camera_lock=old_lock
    @bss082_preserve_native_camera=old_preserve
    BSS104.restore_camera(self,state) if state
    begin
      bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
      bss070_ebdx_recalibrate_if_needed if respond_to?(:bss070_ebdx_recalibrate_if_needed)
      room=@bss070_ebdx_room rescue nil
      room.update if room && !(room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
    rescue
    end
  end

  def pbSendOutBattlers(*args,&block)
    return super unless BSS104.active?(self)
    bss104_with_party_camera_sync { super }
  end

  def pbRecall(*args,&block)
    return super unless BSS104.active?(self)
    bss104_with_party_camera_sync { super }
  end

  # The global Graphics pump must not advance the ambient vector while the
  # native party animation is using coordinates authored from the current frame.
  # The room itself keeps updating, so water/clouds/other ambient layers remain
  # alive during the brief pause.
  def bss100_graphics_frame
    return super unless BSS104.active?(self)
    if @bss104_party_camera_lock
      BSS100.active_scene=self if defined?(BSS100) && BSS100.respond_to?(:active_scene=)
      return bss070_ebdx_tick(false,false)
    end
    super
  end
end

begin
  if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS104PartyCameraSync)
    Battle::Scene.prepend(BSS104PartyCameraSync)
  end
rescue => e
  BSS064.log("BSS104 party-camera install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
