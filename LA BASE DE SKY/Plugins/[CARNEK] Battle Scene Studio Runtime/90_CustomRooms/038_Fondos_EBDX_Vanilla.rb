#===============================================================================
# Battle Scene Studio - EBDX backgrounds in the Vanilla battle scene
# Keeps the native Essentials battlers, boxes and controls.
#===============================================================================
module BSSZBoxFondosEBDXVanilla
  class StaticScene
    attr_reader :battle, :vector
    def initialize(battle, vector)
      @battle = battle
      @vector = vector
    end
  end

  class << self
    # Cache one wrapper per original renderer. EBDX built-ins must retain the
    # FULL EBDX room (effects, water, sky); only authored custom scenes use the
    # custom-room renderer. Both share their own low-z viewport.
    def room_class_for(base)
      @room_classes ||= {}
      return @room_classes[base] if @room_classes[base]
      @room_classes[base] = Class.new(base) do
        def initialize(viewport, scene, data)
          @bss_vanilla_room = true
          @zbox_vp = Viewport.new(viewport.rect.x, viewport.rect.y,
                                   viewport.rect.width, viewport.rect.height)
          @zbox_vp.z = (viewport.z || 0) - 1
          super(@zbox_vp, scene, data)
          @zbox_time_slot = bss_zbox_time_slot
        rescue Exception
          @zbox_vp.dispose if @zbox_vp && !@zbox_vp.disposed?
          @zbox_vp = nil
          raise
        end

        def bss_zbox_time_slot
          return nil if !defined?(BSSLightingClockBridge) || !BSSLightingClockBridge.active?
          return :night if BSSLightingClockBridge.night?
          return :dawn if BSSLightingClockBridge.dawn?
          :day
        rescue StandardError
          nil
        end

        def update
          return if disposed?
          # A time jump may happen during battle. Rebuild only on a sky phase
          # boundary, not every frame. Ordinary animation is handled by EBDX.
          if (@data["sky"] || @data[:sky]) && @data["outdoor"] != false
            slot = bss_zbox_time_slot
            if !slot.nil? && !@zbox_time_slot.nil? && slot != @zbox_time_slot
              refresh(@data)
            end
            @zbox_time_slot = slot
          end
          super
        end

        def color
          @zbox_vp ? @zbox_vp.color : nil
        end

        def color=(value)
          @zbox_vp.color = value if @zbox_vp && !@zbox_vp.disposed?
        end

        def dispose
          return if disposed?
          super
        ensure
          if @zbox_vp && !@zbox_vp.disposed?
            @zbox_vp.dispose
          end
          @zbox_vp = nil
        end
      end
    end

    def authored_backdrop(battle)
      env = battle.respond_to?(:bss_environment_config) ? battle.bss_environment_config : nil
      env = {} if !env.is_a?(Hash)
      requested = (env["ebdxBackdrop"] || env[:ebdxBackdrop] ||
                   env["scene"] || env[:scene]).to_s.strip
      return requested if !requested.empty? && !["auto","inherit"].include?(requested.downcase)
      BSS070EBDXCore.map_backdrop
    end

    def applicable?(scene)
      return false unless defined?(BSS070EBDXCore) && defined?(BSS070EBDXRoom)
      battle = scene.instance_variable_get(:@battle) rescue nil
      return false if !battle || BSS070EBDXCore.active_for_battle?(battle)
      name = authored_backdrop(battle)
      name && !name.to_s.strip.empty?
    rescue StandardError
      false
    end

    def install(scene)
      return false unless defined?(BSS070EBDXVector) && defined?(BSS070EBDXCore)
      return false unless applicable?(scene)
      battle = scene.instance_variable_get(:@battle) rescue nil
      viewport = scene.instance_variable_get(:@viewport) rescue nil
      sprites = scene.instance_variable_get(:@sprites) rescue nil
      return false unless battle && viewport && sprites.is_a?(Hash)
      old = sprites["battlebg"]
      return true if old && old.instance_variable_get(:@bss_vanilla_room) && !(old.disposed? rescue true)

      main = BSS070EBDXCore.get_vector(:MAIN, battle)
      vector = BSS070EBDXVector.new(*main)
      vector.snap(main)
      stub = StaticScene.new(battle, vector)
      data = BSS070EBDXCore.environment_for(stub)
      return false unless data.is_a?(Hash)

      klass = if scene.respond_to?(:bss070_ebdx_room_class)
                scene.bss070_ebdx_room_class(battle)
              else
                BSS070EBDXRoom
              end
      klass = BSS070EBDXRoom unless klass.is_a?(Class) && klass <= BSS070EBDXRoom
      # Older loaders sometimes fail to identify a custom scene by libraryId,
      # but its independent img### layers are sufficient to select its renderer.
      if defined?(BSS070CustomRoom) && data.keys.any? { |k| k.to_s =~ /\Aimg\d+/i }
        klass = BSS070CustomRoom
      end
      room = room_class_for(klass).new(viewport, stub, data)
      room.update
      sprites["battlebg"] = room

      # Hide only the native background surfaces. The room is drawn beneath
      # battlers in its own viewport and must not hide their HUD or shadows.
      ["battle_bg", "battle_bg2", "base_0", "base_1"].each do |key|
        sprite = sprites[key] rescue nil
        next if !sprite
        sprite.visible = false if sprite.respond_to?(:visible=)
        sprite.opacity = 0 if sprite.respond_to?(:opacity=)
      end
      true
    rescue StandardError => e
      BSS064.log("EBDX Vanilla backdrop: #{e.class}: #{e.message}") if defined?(BSS064)
      if room && !(room.disposed? rescue true)
        room.dispose
      end
      sprites.delete("battlebg") if sprites.is_a?(Hash) && sprites["battlebg"].equal?(room)
      false
    end
  end
end

# Vanilla only calls update on battle_bg, not on the extra battlebg entry.
# Update the EBDX room exactly once in the normal battle graphics tick.
module BSSZBoxVanillaGraphicsTick
  def pbGraphicsUpdate(*args, &block)
    result = super
    if @sprites.is_a?(Hash)
      room = @sprites["battlebg"]
      if room && room.instance_variable_get(:@bss_vanilla_room) &&
         !(room.disposed? rescue true)
        room.update
      end
    end
    result
  end
end
if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSZBoxVanillaGraphicsTick)
  Battle::Scene.prepend(BSSZBoxVanillaGraphicsTick)
end
