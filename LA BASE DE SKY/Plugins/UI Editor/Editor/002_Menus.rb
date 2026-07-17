module UI_Editor

  class Menus
    include MiolUtils
    
    def initialize(editor)
      @editor = editor
      @sel = editor.seleccion
      @changes = editor.change_manager
      @vis     = editor.handler_visual
      @movs    = editor.handler_movement
      @dashboard = editor.dashboard
      @hud = editor.hud
    end

    def open_options_menus
      cmds = ["Ver Delta Actual",
              "Log Total (Consola Debug.)"
              ]
      

      options = [:deltas, :log]

      if Settings_UI_Editor::EXPERIMENTAL_FUNCTIONS
        cmds.push("Genera Codigo con deltas cargados")
        options.push(:patch)
      end
      
      cmds.push("Cancelar")
      options.push(:cancel)
      cmd = pbShowCommandsCustom(cmds, 0, (Graphics.width-260)/2, (Graphics.height-160)/2)

      case options[cmd]
      when :deltas then @changes.display_delta_data(@sel.current_sprite)
      when :log    then @changes.log_all_changes
      when :patch  then process_patch_logic()
      end
    end  


    def resets_menus
      cmds = ["Reset Global",
              "Reset. Individual",
              "Cancelar"
            ]
      
      cmd = pbShowCommandsCustom(cmds, 0, (Graphics.width-260)/2, (Graphics.height-160)/2)

      case cmd
      when 0 then @movs.reset_all
      when 1 then @movs.open_menu_resets
      end
      
    end


    def open_navigator
      labels = @sel.main_keys_labels
      return if labels.empty?

      # Añadimos iconos decorativos a las etiquetas
      

      idx = pbShowCommandsCustom(labels, @sel.main_index, (Graphics.width-240)/2, (Graphics.height-300)/2, true)
      
      if idx >= 0
        @sel.jump_to(idx)
        @vis.update(@sel.current_sprite)
        @editor.refresh_hud = true
        pbPlayDecisionSE
      end
    end

    def open_config_menu
      
      @dashboard.visible = false

      @hud.visible = false
      scene = ConfigPanel.new
      scene.main

    
      @dashboard.visible = true

      @hud.visible = true
      
      @vis.update(@sel.current_sprite)
      
    end

    private

    def process_patch_logic
      result = @changes.compile_patch_json
      
      if result
        pbMessage("¡Cirugía completada con éxito!")
        pbMessage("Los archivos Addon han sido actualizados. Reinicia el juego para ver los cambios permanentes.")
      end
    end

  end

end