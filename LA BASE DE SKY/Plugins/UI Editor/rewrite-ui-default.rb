#----------------------------------------------------------------------
# Refactoring Sky Base interface update methods (pbUpdate)
# for UI Editor compatibility
#----------------------------------------------------------------------


#----------------------------------------------------------------------
# Refactorización  de los update // pbUpdate de las interfaces de la Base de Sky 
# para hacerlo compatible con el editor de UI
#----------------------------------------------------------------------

module UI_Editor
  module SceneTracker
    def track_scene
      
      ControlEditor.last_scene = self
      if self.respond_to?(:apply_UI_deltas) && !@ui_editor_applied
        apply_UI_deltas()
      end
      if $DEBUG && Input.triggerex?(:F5) && !ControlEditor.active?
        UI_Editor_Helper.call(self)
      end
    end
  end
end



Settings_UI_Editor::UI_EDITABLE_CLASS.each do |klass_name|
  next unless Object.const_defined?(klass_name)
  klass = Object.const_get(klass_name)
  
  klass.class_eval do
    include UI_Editor::SceneTracker

    # --- HOOK PARA pbUpdate ---
    if method_defined?(:pbUpdate)
      # Remove old alias to prevent calling a previous version 
      # that lacks track_scene.


      # si hay un alias antiguo, lo borramos para evitar apuntar a una
      # versión anterior del método que no incluye track_scene
      remove_method(:ui_editor_alias_pbUpdate) if method_defined?(:ui_editor_alias_pbUpdate)

      alias_method :ui_editor_alias_pbUpdate, :pbUpdate

      def pbUpdate(*args)
        track_scene
        ui_editor_alias_pbUpdate(*args)
      end
    end

    # --- HOOK PARA update ---

      # Follows pbUpdate logic: re-alias after variable reinforcement 
      # to ensure track_scene is always called.


    # misma lógica que en pbUpdate: asegúrate de rehacer el alias tras un
    # refuerzo de variables para que track_scene se invoque siempre.
    if method_defined?(:update)
      remove_method(:ui_editor_alias_update) if method_defined?(:ui_editor_alias_update)

      alias_method :ui_editor_alias_update, :update

      def update(*args)
        track_scene
        ui_editor_alias_update(*args)
      end
    end


    # Using prepend would have been more efficient, but it could cause issues with alias_method, so I’m doing it the old-school way.
    # Plus, it would force the script to always load last in case another script aliased it later—and I didn't like that restriction.


    # Esto con prepend era mas eficiente pero podia dar problemas con el alias_method, asi que lo hago a la antigua usanza
    # Ademas que obliga al script a cargar siempre de ultimo en caso de que otro script hiciese un alias después de él
    # Y no me gustaba esa restricción.
    
    

  end
end


module Input
  unless defined?(ui_editor_update)
    class << self
      alias ui_editor_update update
    end
  end

  def self.update
    ui_editor_update
  end
end

#--------- HOOKS INDIVIDUALES F6 -------------------
# Using F6 to open the editor in specific scenes that might have issues or need manual adjustment

# Para aquellas uis que pueden dar problemas y necesitan un ajuste manual

=begin
if Input.triggerex?(:F6) && $DEBUG && !UI_Editor::ControlEditor.active?
  UI_Editor_Helper.call(self)
end
=end

class UI::MoveReminderVisuals
  alias_method :ui_editor_alias_update_input, :update_input

  def update_input
    if Input.triggerex?(:F6) && $DEBUG && !UI_Editor::ControlEditor.active?
      UI_Editor_Helper.call(self)
    end
    ui_editor_alias_update_input()
  end

end