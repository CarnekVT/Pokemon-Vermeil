#===============================================================================
# BSS070CustomRoom - Clean Custom Background Renderer
#
# This completely replaces the default EBDX room refresh logic when a scene
# uses "libraryId": "project" (a custom scene). It parses scenes.json and
# renders backdrop, base, and img### layers as independent, fully isolated
# sprites. This eliminates all the bugs and clipping caused by EBDX's
# wideWorld math and blt operations.
#===============================================================================
class BSS070CustomRoom < BSS070EBDXRoom
  def refresh(*args)
    # Discard existing sprites
    bss076_dispose_owned_sprites! rescue nil
    
    sx, sy = @scene.vector.spoof(@defaultvector)
    
    # Void (Padding)
    @sprites["void"] = BSS070EBDXSprite.new(@viewport)
    @sprites["void"].z = -10
    @overscan_pad = [(@viewport.width * 0.5).to_i, 192].max
    @sprites["void"].bitmap = Bitmap.new(@viewport.width + @overscan_pad*2, @viewport.height + @overscan_pad*2)
    @sprites["void"].x = -@overscan_pad
    @sprites["void"].y = -@overscan_pad
    @sprites["void"].bitmap.fill_rect(0, 0, @sprites["void"].bitmap.width, @sprites["void"].bitmap.height, Color.new(0, 0, 0))

    # --- 1. BACKDROP ---
    if @data.has_key?("backdrop")
      path = pbResolveBitmap(@data["backdrop"]) ? @data["backdrop"] : "Graphics/BattleSceneStudio/EBDX/Battlebacks/battlebg/" + @data["backdrop"]
      @sprites["bg"] = BSS070EBDXSprite.new(@viewport)
      @sprites["bg"].bitmap = pbBitmap(path)
      @sprites["bg"].z = 0
      @sprites["bg"].center!
      @sprites["bg"].ox = sx/1.5 - 16
      @sprites["bg"].oy = sy/1.5 + 16
      
      if @data["wideWorld"] == true || @sprites["bg"].bitmap.width > 384 || @sprites["bg"].bitmap.height > 308
        logical_w = 384.0
        logical_h = 308.0
        extra_x = [(@sprites["bg"].bitmap.width.to_f  - logical_w) / 2.0, 0.0].max
        extra_y = [(@sprites["bg"].bitmap.height.to_f - logical_h) / 2.0, 0.0].max
        @sprites["bg"].ox += extra_x
        @sprites["bg"].oy += extra_y
        @bss_wide_world_origin = [extra_x, extra_y]
      else
        @bss_wide_world_origin = [0.0, 0.0]
      end
    else
      # Fallback empty bg so camera has an anchor
      @sprites["bg"] = BSS070EBDXSprite.new(@viewport)
      @sprites["bg"].bitmap = Bitmap.new(384, 308)
      @sprites["bg"].z = 0
      @sprites["bg"].center!
      @bss_wide_world_origin = [0.0, 0.0]
    end

    # --- 2. BASE ---
    if @data.has_key?("base")
      str = pbResolveBitmap(@data["base"]) ? @data["base"] : "Graphics/BattleSceneStudio/EBDX/Battlebacks/base/" + @data["base"]
      if str
        @sprites["base"] = BSS070EBDXSprite.new(@viewport)
        @sprites["base"].bitmap = pbBitmap(str)
        @sprites["base"].z = 1
        
        # Position base independently to avoid blt math issues
        base_h = @sprites["base"].bitmap.height
        
        logical_h = 308.0
        extra_y = [(@sprites["bg"].bitmap.height.to_f - logical_h) / 2.0, 0.0].max
        dist_to_bottom = extra_y + 308 - @sprites["bg"].oy
        
        @sprites["base"].ox = @sprites["bg"].ox
        @sprites["base"].oy = base_h - dist_to_bottom
      end
    end
    
    # --- 3. DYNAMIC ELEMENTS ---
    self.drawSky if @data.has_key?("sky")
    self.drawWater if @data.has_key?("water")
    self.drawTrees if @data.has_key?("trees")
    self.drawGrass if @data.has_key?("tallGrass")
    
    # --- 4. CUSTOM IMAGES (img001, img002, etc) ---
    for key in @data.keys
      if key.include?("img")
        self.drawImg(key)
      end
    end

    self.adjustMetrics
    self.daylightTint
  end

  # We must override position so the standalone "base" sprite tracks the camera exactly like "bg" does.
  def position
    super
    if @sprites["base"] && !@sprites["base"].disposed? && @sprites["bg"] && !@sprites["bg"].disposed?
      @sprites["base"].x = @sprites["bg"].x
      @sprites["base"].y = @sprites["bg"].y
      @sprites["base"].zoom_x = @sprites["bg"].zoom_x
      @sprites["base"].zoom_y = @sprites["bg"].zoom_y
    end
  end
end

# Inject the Custom Room loader into the main room initiator
module BSS070CustomRoomLoader
  def bss070_ebdx_room_class(battle)
    # Check if this scene is a custom one exported by Battle Scene Studio.
    # The legacy `BSS095RuntimeLifecycleCore.scenes_registry` index never
    # existed, which forced every scene through the standard EBDXRoom path and
    # hid the authored ground/base of custom scenes (Island). Resolve the scene
    # name through the same pipeline `environment_for` uses instead.
    name = nil
    begin
      env = (battle.respond_to?(:bss_environment_config) ? battle.bss_environment_config : nil) rescue nil
      if env.is_a?(Hash)
        cand = (env["ebdxBackdrop"] || env[:ebdxBackdrop] || env["scene"] || env[:scene]).to_s
        name = cand if !cand.empty? && cand.downcase != "auto" && cand.downcase != "inherit"
      end
    rescue
      name = nil
    end
    begin
      if name.to_s.empty? && BSS070EBDXCore.respond_to?(:map_backdrop)
        name = BSS070EBDXCore.map_backdrop
      end
    rescue
      name = nil
    end
    name = battle.backdrop if name.to_s.empty?
    name = "indoor1" if name.to_s.empty?
    begin
      rows = BSS070EBDXCore.respond_to?(:external_scenes) ? BSS070EBDXCore.external_scenes : []
      rows = [] if !rows.is_a?(Array)
      row = rows.find { |r| r.is_a?(Hash) && (r["id"] || r[:id]).to_s.downcase == name.to_s.downcase }
      if row.is_a?(Hash)
        lib = (row["libraryId"] || row[:libraryId]).to_s
        data = row["data"] || row[:data] || {}
        if lib == "project" || (data.is_a?(Hash) && data.keys.any? { |k| k.to_s.start_with?("img0") })
          return BSS070CustomRoom
        end
      end
    rescue
    end
    return BSS070EBDXRoom
  end
end

module BSS070CustomRoomInjector
  def pbInitSprites(*args, &block)
    super(*args, &block)
    
    # If the standard EBDX initializer created an EBDXRoom, replace it with CustomRoom if needed
    if @bss070_ebdx_room && @bss070_ebdx_room.class == BSS070EBDXRoom
      klass = bss070_ebdx_room_class(@battle)
      if klass == BSS070CustomRoom
        old_room = @bss070_ebdx_room
        # Same (viewport, scene, data) contract as BSS070EBDXRoom.new in
        # 10_EBDX_Source/005_Faithful_EBDX_Room#bss070_ebdx_ensure_core.
        room_data = (old_room && old_room.respond_to?(:data)) ? old_room.data : BSS070EBDXCore.environment_for(self)
        @bss070_ebdx_room = BSS070CustomRoom.new(@viewport, self, room_data)
        old_room.dispose rescue nil
      end
    end
  end
end

class Battle::Scene
  include BSS070CustomRoomLoader
end

Battle::Scene.prepend(BSS070CustomRoomInjector) unless Battle::Scene.ancestors.include?(BSS070CustomRoomInjector)
