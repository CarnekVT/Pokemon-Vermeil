module UI_Editor
  
  class InputHandler
    def initialize(editor)
      @editor  = editor
      @menus   = editor.menus # futura Clse de menus
      @sel     = editor.seleccion
      @hud     = editor.hud
      @mov     = editor.handler_movement
      @vis     = editor.handler_visual
    end

    def update
      any_change = false

      
      res_nav   = update_navigation()
      res_mov   = @mov.update
      res_hud   = update_hud_controls() 
      res_menus = update_menus()
      res_undo  = update_undo()

      any_change = true if res_nav || res_mov || res_hud || res_menus || res_undo
      
      # AvPág / RePág deberían cambiar la página de la escena y refrescar la selección.
      # usando las teclas definidas en los ajustes en lugar de literales hex.
      # 1. Capturamos los triggers en variables para no perder el pulso de la tecla
      plus_pressed = Input.triggerex?(Settings_UI_Editor::KEYS[:AV_PAG]) # AvPág
      min_pressed  = Input.triggerex?(Settings_UI_Editor::KEYS[:REV_PAG]) # RePágs

      if plus_pressed || min_pressed
        scene = @editor.instance_variable_get(:@parent_scene)
        page = SceneContext.get_page(scene)
        
        if page
          # 2. Calculamos la nueva página
          new_page = page
          new_page += 1 if plus_pressed
          new_page -= 1 if min_pressed
          

          max_p = scene.is_a?(PokemonSummary_Scene) ? 6 : 4
          new_page = 1 if new_page > max_p
          new_page = max_p if new_page < 1
          if scene.is_a?(PokemonSummary_Scene)
            if scene.instance_variable_get(:@ribbonOffset).nil? 
              scene.instance_variable_set(:@ribbonOffset, 0)
            end

          end
          # Forzar el redibujado de la escena original
          if scene.respond_to?(:drawPage)
            
            scene.instance_variable_set(:@page, new_page)
            
            scene.drawPage(new_page) 
            pbPlayCursorSE
          end

          # 5. Sincronizamos el Editor con la nueva realidad visual
          @sel.refresh_keys
          @vis.update(@sel.current_sprite)
          return true 
        end
      end
      return any_change
    end
  
    def exit_mode_edition
      if Input.trigger?(Settings_UI_Editor::KEYS[:EXIT])
        return pbConfirmMessage("¿Volver al menú principal?")
      end
      return false
    end

    private

    def update_navigation
      changed = false
      step = Input.press?(Input::SHIFT) ? 5 : 1

      if Input.triggerex?(Settings_UI_Editor::KEYS[:NEXT_OBJ])
        @sel.nexts(step)
        changed = true
      elsif Input.triggerex?(Settings_UI_Editor::KEYS[:PREV_OBJ])
        @sel.prev(step)
        changed = true
      elsif Input.triggerex?(Settings_UI_Editor::KEYS[:TOGGLE_SUB])
        @sel.toggle_sub
        changed = true
      end

      if changed
        @vis.update(@sel.current_sprite)
        pbPlayCursorSE
      end

      return changed
    end

    def update_hud_controls
      changed = false
      
      if Input.triggerex?(Settings_UI_Editor::KEYS[:TOGGLE_HUD])
        @hud.visible = !@hud.visible
        changed = true
      elsif Input.triggerex?(Settings_UI_Editor::KEYS[:TOGGLE_HELP])
        @hud.show_help = !@hud.show_help
        changed = true
      elsif Input.triggerex?(Settings_UI_Editor::KEYS[:TOGGLE_GUIDES])
        @hud.show_guides = !@hud.show_guides
        changed = true
      elsif Input.triggerex?(Settings_UI_Editor::KEYS[:ADJUST_HUD])
        @hud.toggle_position
        changed = true
      end

      pbPlayDecisionSE if changed
      return changed
    end

    def update_menus
      changed = false

      if Input.triggerex?(Settings_UI_Editor::KEYS[:ACTION_MENU])
        @menus.open_options_menus
      elsif Input.triggerex?(Settings_UI_Editor::KEYS[:RESET])
        @menus.resets_menus
      elsif Input.triggerex?(Settings_UI_Editor::KEYS[:LIST_HUD])
        @menus.open_navigator
      end

    end

    def update_undo
      if Input.press?(Input::CTRL) && Input.triggerex?(:Z)
        if @editor.undo.undo #unga unga....xd
          @vis.update(@sel.current_sprite)
          pbPlayCancelSE
          return true 
        end
      end
    end
  end
end
