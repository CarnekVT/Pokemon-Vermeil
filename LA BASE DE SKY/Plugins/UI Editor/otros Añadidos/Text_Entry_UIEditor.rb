module UI_Editor
  class UIEditorTextEntry < PokemonEntryScene
    def pbStartScene(helptext, minlength, maxlength, initialText, previews = nil)
      @sprites = {}
      # Viewport con Z superior a todo el editor
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999
      
      # 1. Ventana de entrada (Keyboard focus)
      @sprites["entry"] = Window_TextEntry_Keyboard.new(
        initialText, 0, 0, Graphics.width - 64, 96, helptext, true
      )
      Input.text_input = true
      @sprites["entry"].x = (Graphics.width - @sprites["entry"].width) / 2
      @sprites["entry"].y = (Graphics.height - @sprites["entry"].height) / 2 + 150
      @sprites["entry"].viewport = @viewport
      @sprites["entry"].maxlength = maxlength
      @sprites["entry"].visible = true
      pbFadeInAndShow(@sprites)
      @sprites["entry"].active = true
      

      @sprites["background"] = ScrollingSprite.new(@viewport)
      @sprites["background"].setBitmap("Graphics/Plugins/UI_Editor/otros Añadidos/scroll_bg", true, false, 2)
      @sprites["background"].z = -1
      
      @sprites["helpwindow"]  = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @sprites["helpwindow"].z = 99
      
      pbSetSystemFont(@sprites["helpwindow"].bitmap)
      
      previews(previews)
      @minlength = minlength
      @maxlength = maxlength
      

      
      pbFadeInAndShow(@sprites)
    end

    def previews(previews) 
      return unless previews

      @sprites["preview_before"] = Sprite.new(@viewport)
      @sprites["preview_before"].bitmap = previews[:before]
      @sprites["preview_before"].x = 10
      @sprites["preview_before"].y = 50 
      @sprites["preview_before"].z = 10

      
      @sprites["preview_after"] = Sprite.new(@viewport)
      @sprites["preview_after"].bitmap = previews[:after]
      @sprites["preview_after"].x = Graphics.width - previews[:after].width - 18
      @sprites["preview_after"].y = 50
      @sprites["preview_after"].z = 10


      @sprites["preview_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @sprites["preview_overlay"].z = 11
      pbSetSmallFont(@sprites["preview_overlay"].bitmap)
      
      overlay = @sprites["preview_overlay"].bitmap
      

      textpos = [
        ["ESTADO ORIGINAL", @sprites["preview_before"].x + (previews[:before].width / 2), (@sprites["preview_before"].y - 20), 2, Color.new(200, 200, 200), Color.new(0, 0, 0, 150)],
        ["NUEVO DISEÑO", @sprites["preview_after"].x + (previews[:after].width / 2), (@sprites["preview_after"].y - 20), 2, Color.new(50, 255, 50), Color.new(0, 0, 0, 150)]
      ]
      pbDrawTextPositions(overlay, textpos)


      border_color = Color.new(255, 255, 255, 50)
      [@sprites["preview_before"], @sprites["preview_after"]].each do |s|

        overlay.fill_rect(s.x - 2, s.y - 2, s.bitmap.width + 4, s.bitmap.height + 4, border_color)
      end
    end

    def pbEntry
      ret = ""
      loop do
        Graphics.update
        Input.update
        if Input.triggerex?(:ESCAPE) && @minlength == 0
          ret = ""
          break
        elsif Input.triggerex?(:RETURN) && @sprites["entry"].text.length >= @minlength
          ret = @sprites["entry"].text
          break
        end
        @sprites["background"].update
        @sprites["helpwindow"].update
        @sprites["entry"].update
        @sprites["subject"]&.update
      end
      Input.update
      return ret
    end

    # Limpieza al cerrar
    def pbEndScene
      pbFadeOutAndHide(@sprites)
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
      @sprites.clear
      Input.text_input = false
    end
  
  end

  class MiolTextEntry
    def initialize(scene)
      @scene = scene
    end

    def pbStartScreen(helptext, minlength, maxlength, initialText, previews = nil)
      @scene.pbStartScene(helptext, minlength, maxlength, initialText, previews)
      ret = @scene.pbEntry
      @scene.pbEndScene
      return ret
    end
  end
end