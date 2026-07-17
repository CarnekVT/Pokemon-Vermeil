

module UI_Editor
  
  class Main
    attr_reader :hud, :seleccion, :handler_movement, :handler_visual, :change_manager, :menus, :undo
    attr_accessor :refresh_hud, :dashboard

    include MiolUtils

    def initialize(categorized_data, original_scene)
      return if !categorized_data || categorized_data.values.all?(&:empty?)
      
      @parent_scene =  original_scene
      ControlEditor.active(@parent_scene)

      @original_stats = {}
      @original_vis = {}  
      @show_hud = true
      @terminated = false
      @refresh_hud = true
      


      #setup_hud
    
      
      # * Clases
      @hud = HUD.new
      @seleccion = Seleccion.new(categorized_data)
      @dashboard = Ui_Editor_Dashboard.new(categorized_data)
      @undo   = Undo.new
      @handler_movement = HandlerMovement.new(@seleccion, @original_stats, @undo)
      @handler_visual = VisualFocus.new(categorized_data, @original_stats, @original_vis)
      @change_manager = ChangeManager.new(@original_stats, categorized_data, @parent_scene, self)
      @menus = Menus.new(self)

      @mouse_handler = MouseInputHandler.new(self)
      @input_handler = InputHandler.new(self)
      # * métodos 
      @handler_visual.record_all_initial_values
      main_control_dashboard()
      dispose()
    end
    
    # * Método de control entre el dashboard y main
    def main_control_dashboard
      loop do
        @handler_visual.reset
        @dashboard.visible = true
        @hud.show_help = false
        
        
        @dashboard.update_selection(self) 
        
        break if @terminated
      end
    end

    def start_editing_mode(mode)
    
      @dashboard.visible = false
      @hud.visible = true
      
      
      @seleccion.set_mode(mode)
      

      if @seleccion.current_entry.nil?
        pbMessage("La categoría #{mode.capitalize} está vacía.")
        @dashboard.visible = true
        @hud.visible = false
        return
      end

      
      colores = {
        :sprite => Color.new(50, 255, 50),   # Verde
        :const  => Color.new(50, 255, 255),  # Cyan
        :var    => Color.new(255, 255, 50)   # Amarillo
      }
      @current_mode_color = colores[mode.to_sym] || Color.new(255, 255, 255)
      
      
      @handler_visual.update(@seleccion.current_sprite) 
      @refresh_hud = true
      
      
      pbPlayDecisionSE
      
      
      pbMainLoop 
      
      
      Input.update
    end

    # * Método de Principal del loop
    def pbMainLoop
      loop do
        Graphics.update
        Input.update

        @refresh_hud = true if @input_handler.update
        @refresh_hud = true if @mouse_handler.update
        if Input.triggerex?(:F6)
          @mouse_handler.toggle
        end
        if @refresh_hud
          @hud.refresh(@seleccion, @current_mode_color)
          @refresh_hud = false
        end
        break if @input_handler.exit_mode_edition || @terminated
      end
    end

    # * Método que establece el final del ciclo
    def terminate_editor
      if pbConfirmMessage("¿Cerrar UI Editor?")
        
        dispose()
        @terminated = true
      end
    end

  
    def dispose
      @terminated = true
      @dashboard.dispose
      ControlEditor.close
      @handler_visual.reset
      @change_manager.dispose
      @hud.dispose
      @undo.clear_history_undo
    end

  end
    

  




  

  
end


