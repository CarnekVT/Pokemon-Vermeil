module UI_Editor
  
  class HUD
    attr_accessor  :show_help, :show_guides, :visible
    HEIGHT_BITMAP_HUD_MAIN = 80
    def initialize
      @visible = true
      @show_help = false
      @show_guides = false
      
      # * Viewport del Panel principal (HUDMain) y Panel de ayuda (HelpPanel)
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 999999

      # * Viewport de las lineas guia (PrecisionGuides)
      @viewport_guides =  Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport_guides.z = 999998

      @hud_main = HUDMain.new(@viewport)
      @help_panel = HelpPanel.new(@viewport)
      @guides = PrecisionGuides.new(@viewport_guides)

      @botton_pos_init = false
    end

    def visible?; return @visible; end

    def toggle_position
      @botton_pos_init = !@botton_pos_init
      if @botton_pos_init
        pos_y = Graphics.height - HEIGHT_BITMAP_HUD_MAIN
        @hud_main.set_y = pos_y
      else
        @hud_main.set_y = 0
      end
    end

    def visible=(val)
      @visible = val
      @viewport.visible = val
      @viewport_guides.visible = val if @viewport_guides
    end

    def refresh(seleccion, color_mode) 
      return if !@visible
      
      # ! revisar en nuevos tests
      
      @hud_main.clear
      @help_panel.clear
      @guides.clear

      
      @hud_main.draw(seleccion, color_mode, @show_help) if @visible
      @help_panel.draw if @show_help
      @guides.draw(seleccion) if @show_guides
    end

    def dispose
      @hud_main.dispose
      @help_panel.dispose
      @guides.dispose
      @viewport.dispose
      @viewport_guides.dispose
    end
  end

  
  

end
