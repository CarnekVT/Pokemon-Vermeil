#===============================================================================
# Battle Scene Studio v0.8.20
# Final runtime authority for the reported v0.8.19 regressions.
#
# - EBDX camera = ambient world drift only, or static. Commands/moves never cut.
# - The EBDX room is pumped once per rendered Graphics frame, including blocking
#   nickname/level-up/move-learning/capture UI loops.
# - Scrolling/sheet/rainbow animation speed is based on Graphics frames rather
#   than number of update calls.
# - Enhanced Battle UI keeps complete visibility/input authority. BSS changes Z
#   only; outlines are always exactly one layer below their owning icon.
# - All Poké Ball trajectories and pbBattlerPosition calculations use native
#   Essentials/DBK screen coordinates. BSS does not move the battler to the ball; native tumbling/rotation is preserved.
# - Non-destructive project tile crops are supported through editor runtimeRaster.
#===============================================================================
module BSS100
  VERSION = "0.8.20"
  class << self
    attr_accessor :active_scene
  end
  module_function

  def frame
    Graphics.frame_count.to_i
  rescue
    0
  end

  def static_camera?(scene)
    cfg=(scene.respond_to?(:bss070_ebdx_camera_config) ? scene.bss070_ebdx_camera_config : {}) rescue {}
    raw=(cfg["profile"] || cfg[:profile] || cfg["preset"] || cfg[:preset]).to_s.downcase
    raw=="static"
  rescue
    false
  end

  def ebdx_scene?(scene)
    scene && scene.respond_to?(:bss070_ebdx_active?) && scene.bss070_ebdx_active?
  rescue
    false
  end
end

#-------------------------------------------------------------------------------
# Since battlers are screen-space in current BSS, no animation builder should
# ever receive an EBDX-projected pbBattlerPosition. This removes the remaining
# ball-outside-screen -> battler teleport chain for sendout/recall/capture/SOS.
#-------------------------------------------------------------------------------
if defined?(BSS082BattlerPositionAuthority)
  module BSS082BattlerPositionAuthority
    def pbBattlerPosition(index, sideSize=1)
      if defined?(BSS082) && BSS082.respond_to?(:without_position_context)
        return BSS082.without_position_context { super(index, sideSize) }
      end
      super(index, sideSize)
    rescue
      super(index, sideSize)
    end
  end
end

#-------------------------------------------------------------------------------
# Exact frame-clock sprite animations. Repeated room.update calls in one visual
# frame do nothing; UI loops which skip Battle::Scene#pbUpdate catch up on the
# next Graphics frame through the pump below.
#-------------------------------------------------------------------------------
if defined?(BSS070EBDXScrollingSprite)
  class BSS070EBDXScrollingSprite
    def update
      return if !bitmap
      now=BSS100.frame
      if @bss100_scroll_frame.nil?
        @bss100_scroll_frame=now
        return
      end
      elapsed=now-@bss100_scroll_frame
      return if elapsed<=0
      elapsed=6 if elapsed>6
      @bss100_scroll_frame=now
      @scroll_accum ||= 0.0
      @scroll_accum += @speed.to_f.abs*elapsed.to_f
      pixels=@scroll_accum.floor
      @scroll_accum-=pixels
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
      now=BSS100.frame
      if @bss100_anim_frame.nil?
        @bss100_anim_frame=now
        return
      end
      elapsed=now-@bss100_anim_frame
      return if elapsed<=0
      elapsed=12 if elapsed>12
      @bss100_anim_frame=now
      @anim_tick=@anim_tick.to_i+elapsed
      wait=[@anim_wait.to_i,1].max
      steps=@anim_tick/wait
      @anim_tick%=wait
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
      now=BSS100.frame
      if @bss100_sheet_frame.nil?
        @bss100_sheet_frame=now
        return
      end
      elapsed=now-@bss100_sheet_frame
      return if elapsed<=0
      elapsed=12 if elapsed>12
      @bss100_sheet_frame=now
      @tick=@tick.to_i+elapsed
      wait=[@speed.to_i,1].max
      steps=@tick/wait
      @tick%=wait
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
      now=BSS100.frame
      if @bss100_rainbow_frame.nil?
        @bss100_rainbow_frame=now
        return
      end
      elapsed=now-@bss100_rainbow_frame
      return if elapsed<=0
      elapsed=6 if elapsed>6
      @bss100_rainbow_frame=now
      @hue=(@hue+[1.0,@speed.to_f.abs].max*elapsed)%360.0
      self.bitmap.dispose if bitmap && !bitmap.disposed?
      self.bitmap=@source.clone
      bitmap.hue_change(@hue.to_i)
    end
  end
end

#-------------------------------------------------------------------------------
# Ambient camera + room frame pump.
# This implementation intentionally bypasses the legacy context-shot scheduler.
# It alternates MAIN <-> a restrained EBDX source vector every few seconds.
# Battlers remain fixed by BSS096's native screen-space authority.
#-------------------------------------------------------------------------------
module BSS100AmbientWorld
  def bss100_ambient_pick_target
    return if !@vector || !defined?(BSS070EBDXCore)
    main=(BSS070EBDXCore.get_vector(:MAIN,@battle) rescue nil)
    return if !main || main.length<6
    target=main.map{|x| x.to_f}
    if @bss100_ambient_out
      @bss100_ambient_out=false
    else
      rows=[]
      begin
        raw_rows=BSS070EBDXCore.const_get(:CAMERA_MOTION)
        ids=[0,8,3,2,1,5]
        rows=ids.map{|i| raw_rows[i]}.compact if raw_rows.is_a?(Array)
      rescue
        rows=[]
      end
      rows=(BSS070EBDXCore.safe_camera_vectors(@battle,:idle) rescue []) if rows.empty?
      rows=rows.select{|r| r.is_a?(Array) && r.length>=6}
      candidates=rows.reject{|r| r.each_with_index.all?{|x,i| (x.to_f-main[i].to_f).abs<0.01 }}
      if !candidates.empty?
        raw=candidates[rand(candidates.length)]
        # Gen-5 ambient motion, not a cinematic shot. Use the source EBDX
        # direction with a restrained but clearly visible world displacement.
        weights=[0.18,0.15,0.12,0.12,0.08,0.08]
        6.times{|i| target[i]=main[i].to_f+(raw[i].to_f-main[i].to_f)*weights[i]}
      end
      @bss100_ambient_out=true
    end
    @vector.inc=0.0065 if @vector.respond_to?(:inc=)
    @vector.set(target) if @vector.respond_to?(:set)
    @bss100_ambient_due=150+rand(121)
  rescue => e
    BSS064.log("BSS100 ambient target warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def bss070_ebdx_tick(_advance_camera=true, align=true)
    # Guard before ensure_core: room/core construction can itself enter an
    # older tick authority through a callback. Waiting until after ensure_core
    # still allows that circular chain to grow the Ruby stack.
    return false if @bss100_tick_active
    @bss100_tick_active=true
    begin
      return false if !bss070_ebdx_ensure_core
      now=BSS100.frame
      return true if @bss100_last_world_tick==now
      @bss100_last_world_tick=now
      bss070_ebdx_hide_native_backdrops if respond_to?(:bss070_ebdx_hide_native_backdrops)

      static=BSS100.static_camera?(self)
      bas=!!@bss070_ebdx_bas_frame
      suspended=@bss070_ebdx_suspend_depth.to_i>0
      if !static && !bas && !suspended && @vector
        @vector.update
        unless @bss100_ambient_ready
          @bss100_ambient_ready=true
          @bss100_ambient_due=48
          @bss100_ambient_out=false
        end
        @bss100_ambient_due=@bss100_ambient_due.to_i-1
        if @bss100_ambient_due<=0 && (@vector.finished? rescue true)
          bss100_ambient_pick_target
        end
      end

      @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
      bss070_ebdx_apply_world_alignment if align && respond_to?(:bss070_ebdx_apply_world_alignment)
      true
    ensure
      @bss100_tick_active=false
    end
  rescue => e
    @bss100_tick_active=false
    BSS064.log("BSS100 world tick warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  # No command/fight/move/SOS/sendout context is allowed to redirect this camera.
  def bss070_ebdx_camera_enter(*args); nil; end
  def bss070_ebdx_camera_leave(*args); nil; end
  def bss087_request_camera_context(*args); false; end
  def bss084_transition_context(*args); false; end
  def bss096_camera_to_main(*args); false; end

  def bss100_graphics_frame
    return if !BSS100.ebdx_scene?(self)
    BSS100.active_scene=self
    bss070_ebdx_tick(true,true)
  rescue
  end

  def pbInitSprites(*args,&block)
    ret=super
    BSS100.active_scene=self
    bss100_enhanced_z_only
    ret
  end

  def pbUpdate(*args,&block)
    BSS100.active_scene=self
    ret=super
    bss100_graphics_frame
    ret
  end

  def pbDisposeSprites(*args,&block)
    BSS100.active_scene=nil if BSS100.active_scene.equal?(self)
    super
  end
end

# F12 safety: do NOT hook Graphics.update globally.
#
# Carnek Project Settings/SleepAnimations wraps Graphics.update with an alias.
# Prepending BSS here makes F12 reload alias the prepended BSS method; the next
# call then cycles BSS100GraphicsPump#update -> SleepAnimations#update -> the
# aliased BSS100GraphicsPump#update until SystemStackError.
#
# Battle::Scene#pbUpdate already calls bss100_graphics_frame below, so the EBDX
# room still advances during the battle without owning the global Graphics API.
module BSS100GraphicsPump
end

#-------------------------------------------------------------------------------
# Enhanced Battle UI: no BSS visibility or prompt-state changes.
# Z-order only, with outline = owning icon - 1.
#-------------------------------------------------------------------------------
module BSS100EnhancedZ
  def bss100_enhanced_z_only
    return if !@sprites.is_a?(Hash)
    main=@sprites["enhancedUI"] rescue nil
    prompt=@sprites["enhancedUIPrompts"] rescue nil
    main.z=11500 if main && !(main.disposed? rescue true) && main.respond_to?(:z=)
    prompt.z=11560 if prompt && !(prompt.disposed? rescue true) && prompt.respond_to?(:z=)
    ["leftarrow","rightarrow"].each do |k|
      sp=@sprites[k] rescue nil
      sp.z=11610 if sp && !(sp.disposed? rescue true) && sp.respond_to?(:z=)
    end
    @sprites.each do |k,sp|
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:z=)
      s=k.to_s
      next unless s =~ /\A(info_icon|ball_icon)\d+\z/i
      sp.z=11642
    end
    @sprites.each do |k,sp|
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:z=)
      s=k.to_s
      next unless s =~ /\A(.+)_outline\d+\z/i
      parent=@sprites[$1] rescue nil
      sp.z=(parent && parent.respond_to?(:z) ? parent.z.to_i-1 : 11641)
    end
  rescue
  end

  def pbUpdate(*args,&block)
    ret=super
    bss100_enhanced_z_only
    ret
  end

  def pbShowWindow(*args,&block)
    ret=super
    begin
      window_type=args[0]
      command_box=(defined?(Battle::Scene::COMMAND_BOX) ? Battle::Scene::COMMAND_BOX : nil)
      fight_box=(defined?(Battle::Scene::FIGHT_BOX) ? Battle::Scene::FIGHT_BOX : nil)
      if window_type==command_box || window_type==fight_box
        prompt=@sprites["enhancedUIPrompts"] rescue nil
        if prompt && !(prompt.visible rescue false) && respond_to?(:pbRefreshUIPrompt)
          pbRefreshUIPrompt(nil,window_type)
        end
      end
    rescue
    end
    bss100_enhanced_z_only
    ret
  end

  def pbUpdateInfoSprites(*args,&block)
    ret=super
    bss100_enhanced_z_only
    ret
  end

  def pbSetWithOutline(*args,&block)
    ret=super
    bss100_enhanced_z_only
    ret
  end

  def pbShowOutline(*args,&block)
    ret=super
    bss100_enhanced_z_only
    ret
  end

  def pbStartBattle(*args,&block)
    ret=super
    bss100_enhanced_z_only
    ret
  end
end

# Neutralise visibility-mutating guards already present in older BSS modules.
if defined?(BSS083CameraAndRenderAuthority)
  module BSS083CameraAndRenderAuthority
    def bss083_enhanced_ui_guard
      bss100_enhanced_z_only if respond_to?(:bss100_enhanced_z_only)
      true
    end
  end
end
if defined?(BSS085StableWorldAuthority)
  module BSS085StableWorldAuthority
    def bss085_enhanced_prompt_guard
      bss100_enhanced_z_only if respond_to?(:bss100_enhanced_z_only)
      true
    end
    def bss085_enhanced_ui_layers
      bss100_enhanced_z_only if respond_to?(:bss100_enhanced_z_only)
      true
    end
  end
end
if defined?(BSS097SceneUIParity)
  module BSS097SceneUIParity
    def pbUpdate(*args,&block)
      ret=super
      bss100_enhanced_z_only if respond_to?(:bss100_enhanced_z_only)
      ret
    end
  end
end
if defined?(BSS087EnhancedUIAuthority)
  module BSS087EnhancedUIAuthority
    def bss087_refresh_enhanced_now
      bss100_enhanced_z_only if respond_to?(:bss100_enhanced_z_only)
      true
    end
    def bss087_enforce_enhanced_ui_z
      bss100_enhanced_z_only if respond_to?(:bss100_enhanced_z_only)
      true
    end
  end
end

#-------------------------------------------------------------------------------
# Ball authority: skip every BSS trajectory wrapper and execute the original
# Essentials/DBK implementation directly, including its native tumbling/rotation.
#-------------------------------------------------------------------------------
module BSS100NativeBallTrajectory
  def createBallTrajectory(*args)
    m=method(:createBallTrajectory).super_method
    while m && m.owner.to_s.start_with?("BSS")
      m=m.super_method
    end
    m ? m.call(*args) : super
  end
end

module BSS100NativeTrainerBallTrajectory
  def createBallTrajectory(*args)
    m=method(:createBallTrajectory).super_method
    while m && m.owner.to_s.start_with?("BSS")
      m=m.super_method
    end
    m ? m.call(*args) : super
  end
end

#-------------------------------------------------------------------------------
# Metadata context resolver: use Essentials' real encounter type tokens first.
#-------------------------------------------------------------------------------
if defined?(BSS097EncounterBackdropRuntime)
  module BSS097EncounterBackdropRuntime
    module_function
    def current_context_tokens
      vals=[]
      begin
        vals.concat(BSS080.encounter_type_tokens) if defined?(BSS080) && BSS080.respond_to?(:encounter_type_tokens)
      rescue
      end
      begin
        if defined?($PokemonEncounters) && $PokemonEncounters && $PokemonEncounters.respond_to?(:encounter_type)
          raw=$PokemonEncounters.encounter_type
          vals << raw
          if raw && defined?(GameData::EncounterType)
            row=GameData::EncounterType.get(raw) rescue nil
            vals << row.id if row && row.respond_to?(:id)
            vals << row.type if row && row.respond_to?(:type)
            vals << row.name if row && row.respond_to?(:name)
          end
        end
      rescue
      end
      vals.compact.map{|x| x.to_s}.reject{|x| x.empty?}.uniq
    end
    def current_context
      current_context_tokens[0]
    end
    def context_backdrop
      rows=(BSS070EBDXCore.global_config["ebdxEncounterMetadata"] rescue nil)
      return nil if !rows.is_a?(Array) || rows.empty?
      tokens=current_context_tokens.map{|x| x.downcase}
      row=rows.find do |r|
        next false unless r.is_a?(Hash)
        wanted=(r["context"] || r[:context]).to_s.downcase
        tokens.include?(wanted)
      end
      return nil if !row
      name=(row["backdrop"] || row[:backdrop]).to_s.strip
      return nil if name.empty? || ["auto","inherit"].include?(name.downcase)
      found=(BSS070EBDXCore::BUILTIN.keys.find{|k| k.to_s.downcase==name.downcase } rescue nil)
      found || name
    rescue
      nil
    end
  end
end

# runtimeRaster already contains editor crop/warp/blur. Do not reapply crop.
if defined?(BSS098)
  module BSS098
    class << self
      alias bss100_prepare_scene_without_crop_cleanup prepare_scene unless method_defined?(:bss100_prepare_scene_without_crop_cleanup)
      def prepare_scene(data)
        out=bss100_prepare_scene_without_crop_cleanup(data)
        if out.is_a?(Hash)
          out.each do |k,row|
            next unless k.to_s =~ /^img\d+/i && row.is_a?(Hash)
            if row[:bss_rasterized] || row["bss_rasterized"]
              row.delete(:crop);row.delete("crop")
            end
          end
        end
        out
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Recursion guard for Battle::Scene#pbUpdate to prevent SystemStackError
# from circular prepend chains in BSS modules.
#-------------------------------------------------------------------------------
module BSS100RecursionGuard
  @@pbupdate_frame = 0
  @@pbupdate_count = 0
  MAX_PBUPDATE_PER_FRAME = 50

  def pbUpdate(*args,&block)
    # A nested Scene#pbUpdate is never a valid frame update. It is the
    # signature of the circular prepend chain seen with StableWorld/Golden.
    # Stop it before calling super, rather than allowing dozens of nested
    # wrappers to accumulate until SystemStackError.
    if @bss100_pbupdate_active
      BSS064.log("BSS100RecursionGuard: nested pbUpdate skipped") if defined?(BSS064)
      return false
    end
    @bss100_pbupdate_active=true
    current_frame = Graphics.frame_count rescue 0
    if @@pbupdate_frame != current_frame
      @@pbupdate_frame = current_frame
      @@pbupdate_count = 0
    end
    @@pbupdate_count += 1
    if @@pbupdate_count > MAX_PBUPDATE_PER_FRAME
      BSS064.log("BSS100RecursionGuard: pbUpdate recursion detected (#{@@pbupdate_count} calls/frame), skipping") if defined?(BSS064)
      @bss100_pbupdate_active=false
      return
    end
    begin
      super(*args,&block)
    ensure
      @@pbupdate_count -= 1
      @bss100_pbupdate_active=false
    end
  end
end

# Apply the guard to Battle::Scene (last in prepend chain)
if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS100RecursionGuard)
  Battle::Scene.prepend(BSS100RecursionGuard)
end

# Install final authorities.
begin
  if defined?(Battle::Scene)
    Battle::Scene.prepend(BSS100AmbientWorld) unless Battle::Scene.ancestors.include?(BSS100AmbientWorld)
    Battle::Scene.prepend(BSS100EnhancedZ) unless Battle::Scene.ancestors.include?(BSS100EnhancedZ)
  end
rescue => e
  BSS064.log("BSS100 scene install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
# Intentionally no Graphics.singleton_class.prepend here.
# See BSS100GraphicsPump above: global Graphics hooks are F12-unsafe alongside
# SleepAnimations' alias-based update wrapper.
begin
  mix=Battle::Scene::Animation::BallAnimationMixin
  mix.prepend(BSS100NativeBallTrajectory) if defined?(mix) && !mix.ancestors.include?(BSS100NativeBallTrajectory)
rescue => e
  BSS064.log("BSS100 native ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
begin
  k=Battle::Scene::Animation::PokeballTrainerSendOut
  k.prepend(BSS100NativeTrainerBallTrajectory) if defined?(k) && !k.ancestors.include?(BSS100NativeTrainerBallTrajectory)
rescue => e
  BSS064.log("BSS100 trainer ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# Source-linked crop for project graphics/tilesets. A crop-only layer keeps the
# original Graphics path and stores only x/y/w/h in scenes.json. No duplicate PNG
# is needed. Warp/local blur still use runtimeRaster for exact visual parity.
#-------------------------------------------------------------------------------
module BSS100SourceCrop
  def drawImg(key)
    ret=super
    begin
      row=@data[key] || @data[key.to_s] || @data[key.to_sym]
      next_ret=ret
      return ret unless row.is_a?(Hash)
      return ret if row[:bss_rasterized] || row["bss_rasterized"]
      crop=(row[:crop] || row["crop"])
      return ret unless crop.is_a?(Hash)
      sp=@sprites[key.to_s] || @sprites[key]
      return ret if !sp || (sp.disposed? rescue true) || !sp.bitmap
      src=sp.bitmap
      vertical=(sp.respond_to?(:vertical) && sp.vertical) rescue false
      scrolling=defined?(BSS070EBDXScrollingSprite) && sp.is_a?(BSS070EBDXScrollingSprite)
      source_w=scrolling && !vertical ? src.width/2 : src.width
      source_h=scrolling && vertical ? src.height/2 : src.height
      x=BSS098.num(BSS098.hash_get(crop,:x),0).round
      y=BSS098.num(BSS098.hash_get(crop,:y),0).round
      w=BSS098.num(BSS098.hash_get(crop,:w),source_w).round
      h=BSS098.num(BSS098.hash_get(crop,:h),source_h).round
      x=[[x,0].max,[source_w-1,0].max].min
      y=[[y,0].max,[source_h-1,0].max].min
      w=[[w,1].max,source_w-x].min
      h=[[h,1].max,source_h-y].min
      cut=Bitmap.new(w,h)
      cut.blt(0,0,src,Rect.new(x,y,w,h))
      if scrolling
        old=sp.bitmap
        sp.setBitmap(cut,vertical,(sp.respond_to?(:pulse) ? sp.pulse : false))
        begin; old.dispose if old && !old.disposed?; rescue; end
        begin; cut.dispose if cut && !cut.disposed?; rescue; end
      else
        sp.bitmap=cut
      end
      ox=BSS098.hash_get(row,:ox)
      oy=BSS098.hash_get(row,:oy)
      sp.ox=ox.nil? ? w/2 : ox.to_f-x if sp.respond_to?(:ox=)
      sp.oy=oy.nil? ? h : oy.to_f-y if sp.respond_to?(:oy=)
      sp.memorize_bitmap if sp.respond_to?(:memorize_bitmap)
    rescue => e
      BSS064.log("BSS100 source crop warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    ret
  end
end

begin
  if defined?(BSS070EBDXRoom)
    BSS070EBDXRoom.prepend(BSS100SourceCrop) unless BSS070EBDXRoom.ancestors.include?(BSS100SourceCrop)
  end
rescue => e
  BSS064.log("BSS100 crop install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
