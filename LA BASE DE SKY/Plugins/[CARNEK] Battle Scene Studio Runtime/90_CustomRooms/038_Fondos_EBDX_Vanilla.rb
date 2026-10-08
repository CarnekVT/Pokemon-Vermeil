#===============================================================================
# Battle Scene Studio - Fondos EBDX en Motor Vanilla (Unificado)
#===============================================================================
# Pinta el fondo/escenario authorado de Battle Scene Studio (EBDX) como imagen
# ESTÁTICA detrás de las batallas de motor VANILLA, en los mapas que tengan
# escena asignada (map_metadata.json, p.ej. mapa 79 -> scene_custom/Island).
#===============================================================================
module BSSZBoxFondosEBDXVanilla
  # Escena mínima con la que el room construye/posiciona sin tocar la batalla
  # real: solo battle y vector.
  class StaticScene
    attr_reader :battle, :vector

    def initialize(battle, vector)
      @battle = battle
      @vector = vector
    end
  end

  class << self
    # Subclase del room real con un viewport PROPIO (z bajo) y un único update.
    def frozen_room_class
      @frozen_room_class ||= Class.new(BSS070CustomRoom) do
        def initialize(viewport, scene, data)
          @zbox_positioned = false
          @zbox_vp = Viewport.new(viewport.rect.x, viewport.rect.y,
                                  viewport.rect.width, viewport.rect.height)
          @zbox_vp.z = (viewport.z || 0) - 1000
          super(@zbox_vp, scene, data)
        end

        def update
          return if disposed?
          if !@zbox_positioned
            @zbox_positioned = true
            super
          end
        end

        def color
          @zbox_vp ? @zbox_vp.color : nil
        end

        def color=(val)
          @zbox_vp.color = val if @zbox_vp
        end

        def dispose
          return if disposed?
          super
          if @zbox_vp && !@zbox_vp.disposed?
            @zbox_vp.color = Color.new(0, 0, 0, 0)
            @zbox_vp.dispose
          end
          @zbox_vp = nil
        end
      end
    end
    private :frozen_room_class

    # ¿Debe el plugin sustituir el battleback vanilla? Solo si motor vanilla + escena authorada.
    def applicable?(scene)
      return false if !defined?(BSS070EBDXCore) || !defined?(BSS070CustomRoom)
      battle = scene.instance_variable_get(:@battle) rescue nil
      return false if !battle
      return false if BSS070EBDXCore.active_for_battle?(battle)
      backdrop = BSS070EBDXCore.bss_map_backdrop
      return false if !backdrop || backdrop.to_s.strip.empty?
      true
    rescue
      false
    end

    def install(scene)
      return false if !defined?(BSS070EBDXCore) || !defined?(BSS070CustomRoom) ||
                      !defined?(BSS070EBDXVector) || !frozen_room_class
      return false if !applicable?(scene)
      battle = scene.instance_variable_get(:@battle) rescue nil
      viewport = scene.instance_variable_get(:@viewport) rescue nil
      sprites = scene.instance_variable_get(:@sprites) rescue nil
      return false if !battle || !viewport || !sprites.is_a?(Hash)

      main = BSS070EBDXCore.get_vector(:MAIN, battle)
      vector = BSS070EBDXVector.new(*main)
      vector.snap(main)
      stub = StaticScene.new(battle, vector)
      data = BSS070EBDXCore.environment_for(stub)
      return false if !data.is_a?(Hash)

      room_class = scene.respond_to?(:bss070_ebdx_room_class) ?
                   scene.bss070_ebdx_room_class(battle) : BSS070CustomRoom
      room_class = BSS070CustomRoom if !(room_class.is_a?(Class) && room_class < BSS070CustomRoom)
      room = frozen_room_class.new(viewport, stub, data)
      room.update
      sprites["battlebg"] = room

      # Esconde el battleback y los círculos base vanilla
      ["battle_bg", "battle_bg2", "base_0", "base_1"].each do |key|
        sprite = sprites[key] rescue nil
        next if !sprite
        sprite.visible = false if sprite.respond_to?(:visible=)
        sprite.opacity = 0 if sprite.respond_to?(:opacity=)
      end
      true
    rescue => e
      BSS064.log("ZBOX Fondos EBDX Vanilla::install #{e.class}: #{e.message}") if defined?(BSS064)
      if room && !(room.disposed? rescue true)
        room.dispose
      elsif sprites.is_a?(Hash) && sprites["battlebg"] && !(sprites["battlebg"].disposed? rescue true)
        sprites["battlebg"].dispose
      end
      false
    end
  end
end
