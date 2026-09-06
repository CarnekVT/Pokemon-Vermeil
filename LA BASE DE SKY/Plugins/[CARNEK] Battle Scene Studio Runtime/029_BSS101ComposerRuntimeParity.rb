#===============================================================================
# Battle Scene Studio v0.8.22
# Final Composer/Runtime parity authority.
#
# - Ambient EBDX camera begins immediately and never uses command/move shots.
# - Environmental speeds are normalized to EBDX's 40 FPS source clock.
# - Authored custom img Z/visibility is reasserted after every legacy transform.
# - Enhanced Battle UI prompt is refreshed by its own API on the first command
#   frame; outlines remain one layer below their owning icon.
#===============================================================================
module BSS101
  VERSION = "0.8.22"
  SOURCE_FPS = 40.0
  module_function

  def frame
    Graphics.frame_count.to_i
  rescue
    0
  end

  def fps
    f=(Graphics.frame_rate rescue SOURCE_FPS).to_f
    return SOURCE_FPS if f <= 1.0 || f > 240.0
    f
  rescue
    SOURCE_FPS
  end

  def source_step(elapsed)
    elapsed.to_f * SOURCE_FPS / fps
  rescue
    elapsed.to_f
  end

  def static_camera?(scene)
    cfg=(scene.respond_to?(:bss070_ebdx_camera_config) ? scene.bss070_ebdx_camera_config : {}) rescue {}
    raw=(cfg["profile"] || cfg[:profile] || cfg["preset"] || cfg[:preset]).to_s.downcase
    raw=="static"
  rescue
    false
  end
end

#-------------------------------------------------------------------------------
# Source-clock animation. A move or plugin can call Room#update ten times during
# one rendered frame and these sprites still advance exactly one visual step.
#-------------------------------------------------------------------------------
if defined?(BSS070EBDXScrollingSprite)
  class BSS070EBDXScrollingSprite
    def update
      return if !bitmap
      now=BSS101.frame
      if @bss101_scroll_frame.nil?
        @bss101_scroll_frame=now
        return
      end
      elapsed=now-@bss101_scroll_frame
      return if elapsed<=0
      elapsed=8 if elapsed>8
      @bss101_scroll_frame=now
      step=BSS101.source_step(elapsed)
      @bss101_scroll_accum ||= 0.0
      @bss101_scroll_accum += @speed.to_f.abs*step
      pixels=@bss101_scroll_accum.floor
      @bss101_scroll_accum-=pixels
      return if pixels<=0
      shift=pixels*(@direction.to_f<0 ? -1 : 1)
      if @vertical
        self.src_rect.y+=shift; h=[self.src_rect.height,1].max
        self.src_rect.y-=h while self.src_rect.y>=h
        self.src_rect.y+=h while self.src_rect.y<0
      else
        self.src_rect.x+=shift; w=[self.src_rect.width,1].max
        self.src_rect.x-=w while self.src_rect.x>=w
        self.src_rect.x+=w while self.src_rect.x<0
      end
      if @pulse
        self.opacity-=@gopac*pixels
        @gopac*=-1 if opacity<=@min_o || opacity>=@max_o
      end
    end
  end
end

if defined?(BSS070EBDXAnimatedSprite)
  class BSS070EBDXAnimatedSprite
    def update
      return if !@frames || @frames.empty?
      now=BSS101.frame
      if @bss101_anim_frame.nil?
        @bss101_anim_frame=now; @bss101_anim_tick=0.0
        return
      end
      elapsed=now-@bss101_anim_frame
      return if elapsed<=0
      elapsed=12 if elapsed>12
      @bss101_anim_frame=now
      @bss101_anim_tick=@bss101_anim_tick.to_f+BSS101.source_step(elapsed)
      wait=[@anim_wait.to_f,1.0].max
      steps=(@bss101_anim_tick/wait).floor
      @bss101_anim_tick-=steps*wait
      return if steps<=0
      @anim_index=(@anim_index+steps)%@frames.length
      begin; self.bitmap.dispose if bitmap && !bitmap.disposed?; rescue; end
      self.bitmap=@frames[@anim_index].clone
    end
  end
end

if defined?(BSS070EBDXSheetSprite)
  class BSS070EBDXSheetSprite
    def update
      return if !bitmap
      now=BSS101.frame
      if @bss101_sheet_frame.nil?
        @bss101_sheet_frame=now; @bss101_sheet_tick=0.0
        return
      end
      elapsed=now-@bss101_sheet_frame
      return if elapsed<=0
      elapsed=12 if elapsed>12
      @bss101_sheet_frame=now
      @bss101_sheet_tick=@bss101_sheet_tick.to_f+BSS101.source_step(elapsed)
      wait=[@speed.to_f,1.0].max
      steps=(@bss101_sheet_tick/wait).floor
      @bss101_sheet_tick-=steps*wait
      return if steps<=0
      @cur=(@cur+steps)%@frames
      if @vertical; src_rect.y=@cur*src_rect.height
      else; src_rect.x=@cur*src_rect.width
      end
    end
  end
end

if defined?(BSS070EBDXRainbowSprite)
  class BSS070EBDXRainbowSprite
    def update
      return if !@source
      now=BSS101.frame
      if @bss101_rainbow_frame.nil?
        @bss101_rainbow_frame=now
        return
      end
      elapsed=now-@bss101_rainbow_frame
      return if elapsed<=0
      elapsed=8 if elapsed>8
      @bss101_rainbow_frame=now
      @hue=(@hue+[1.0,@speed.to_f.abs].max*BSS101.source_step(elapsed))%360.0
      begin; self.bitmap.dispose if bitmap && !bitmap.disposed?; rescue; end
      self.bitmap=@source.clone
      bitmap.hue_change(@hue.to_i)
    end
  end
end

#-------------------------------------------------------------------------------
# Ambient EBDX camera only. Ignore stale legacy suspend-depth flags: BAS is the
# only thing allowed to temporarily own the camera. Keep depth/zoom at MAIN so
# authored ground/water coverage remains visually close to the editor.
#-------------------------------------------------------------------------------
module BSS101AmbientCamera
  def bss101_ambient_target
    return if !@vector || !defined?(BSS070EBDXCore)
    main=(BSS070EBDXCore.get_vector(:MAIN,@battle) rescue nil)
    return if !main || main.length<6
    target=main.map{|x|x.to_f}
    if @bss101_ambient_out
      @bss101_ambient_out=false
    else
      rows=[]
      begin
        src=BSS070EBDXCore.const_get(:CAMERA_MOTION)
        rows=[0,8,3,2,1,5].map{|i|src[i]}.compact if src.is_a?(Array)
      rescue
        rows=[]
      end
      rows=(BSS070EBDXCore.safe_camera_vectors(@battle,:idle) rescue []) if rows.empty?
      rows=rows.select{|r|r.is_a?(Array)&&r.length>=6}
      raw=rows[rand(rows.length)] unless rows.empty?
      if raw
        # Mostly horizontal Gen-5 drift. Very small vertical shift and no zoom /
        # depth changes, so sea/floor composition does not radically change.
        target[0]=main[0].to_f+(raw[0].to_f-main[0].to_f)*0.08
        target[1]=main[1].to_f+(raw[1].to_f-main[1].to_f)*0.025
      end
      @bss101_ambient_out=true
    end
    @vector.inc=0.0045 if @vector.respond_to?(:inc=)
    @vector.set(target) if @vector.respond_to?(:set)
    @bss101_ambient_due=110+rand(91)
  rescue => e
    BSS064.log("BSS101 ambient target warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss070_ebdx_tick(_advance_camera=true, align=true)
    return false if !bss070_ebdx_ensure_core
    now=BSS101.frame
    return true if @bss101_last_world_tick==now
    @bss101_last_world_tick=now
    bss070_ebdx_hide_native_backdrops if respond_to?(:bss070_ebdx_hide_native_backdrops)
    static=BSS101.static_camera?(self)
    bas=!!@bss070_ebdx_bas_frame
    if !static && !bas && @vector
      @vector.update
      unless @bss101_ambient_ready
        @bss101_ambient_ready=true
        @bss101_ambient_due=18
        @bss101_ambient_out=false
      end
      @bss101_ambient_due=@bss101_ambient_due.to_i-1
      bss101_ambient_target if @bss101_ambient_due<=0 && (@vector.finished? rescue true)
    end
    @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
    bss070_ebdx_apply_world_alignment if align && respond_to?(:bss070_ebdx_apply_world_alignment)
    true
  rescue => e
    BSS064.log("BSS101 world tick warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  # No context-driven automatic cuts.
  def bss070_ebdx_camera_enter(*args); nil; end
  def bss070_ebdx_camera_leave(*args); nil; end
  def bss087_request_camera_context(*args); false; end
  def bss084_transition_context(*args); false; end
  def bss096_camera_to_main(*args); false; end
end

#-------------------------------------------------------------------------------
# Final custom-layer authority. Legacy canvasLayer compatibility used to cap Z
# at 14 and some refresh paths could leave a custom sprite hidden. Reapply the
# exact authored Z after all source/legacy positioning has completed.
#-------------------------------------------------------------------------------
module BSS101CustomLayerParity
  def position
    ret=super
    begin
      (@data || {}).each do |raw_key,row|
        next unless raw_key.to_s =~ /^img\d+/i && row.is_a?(Hash)
        sp=@sprites[raw_key.to_s] || @sprites[raw_key]
        next if !sp || (sp.disposed? rescue true)
        z=BSS098.num(BSS098.hash_get(row,:z),0).round rescue 0
        # EBDX defocus is the source-of-truth for move/BAS priority. Custom
        # layers must inherit its -100 offset instead of restoring authored Z
        # on every position() call. Warp micro-tiles copy this root Z later.
        bg=@sprites["bg"] rescue nil
        defocused=((@focused == false) || (bg && bg.respond_to?(:z) && bg.z.to_i < 0))
        z_offset=defocused ? -100 : 0
        sp.z=[[-500,z].max,40].min + z_offset if sp.respond_to?(:z=)
        hidden=(BSS098.hash_get(row,:visible)==false rescue false)
        sp.visible=true if !hidden && sp.respond_to?(:visible=)
      end
    rescue => e
      BSS064.log("BSS101 custom layer parity warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    ret
  end
end

#-------------------------------------------------------------------------------
# Enhanced UI. Refresh the plugin's own prompt API immediately on the first
# COMMAND/FIGHT frame. BSS does not infer a battler or mutate menu indices.
#-------------------------------------------------------------------------------
module BSS101EnhancedPrompt
  def bss101_enhanced_z
    return unless @sprites.is_a?(Hash)
    main=@sprites["enhancedUI"] rescue nil
    prompt=@sprites["enhancedUIPrompts"] rescue nil
    main.z=9300 if main && !(main.disposed? rescue true) && main.respond_to?(:z=)
    prompt.z=9360 if prompt && !(prompt.disposed? rescue true) && prompt.respond_to?(:z=)
    @sprites.each do |k,sp|
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:z=)
      s=k.to_s
      if s =~ /\A(info_icon|ball_icon)\d+\z/i
        sp.z=9442
      elsif s =~ /\A(.+)_outline\d+\z/i
        parent=@sprites[$1] rescue nil
        sp.z=(parent && parent.respond_to?(:z) ? parent.z.to_i-1 : 9441)
      end
    end
  rescue
  end

  def pbShowWindow(windowType,*args,&block)
    ret=super
    begin
      command_box=(defined?(Battle::Scene::COMMAND_BOX) ? Battle::Scene::COMMAND_BOX : nil)
      fight_box=(defined?(Battle::Scene::FIGHT_BOX) ? Battle::Scene::FIGHT_BOX : nil)
      if (windowType==command_box || windowType==fight_box) && respond_to?(:pbRefreshUIPrompt)
        pbRefreshUIPrompt(nil,windowType)
      end
    rescue => e
      BSS064.log("BSS101 Enhanced prompt warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    bss101_enhanced_z
    ret
  end

  def pbUpdate(*args,&block)
    ret=super
    bss101_enhanced_z
    ret
  end
end

begin
  if defined?(BSS070EBDXRoom)
    BSS070EBDXRoom.prepend(BSS101CustomLayerParity) unless BSS070EBDXRoom.ancestors.include?(BSS101CustomLayerParity)
  end
rescue => e
  BSS064.log("BSS101 room install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSS101AmbientCamera) unless Battle::Scene.ancestors.include?(BSS101AmbientCamera)
    Battle::Scene.prepend(BSS101EnhancedPrompt) unless Battle::Scene.ancestors.include?(BSS101EnhancedPrompt)
  end
rescue => e
  BSS064.log("BSS101 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
