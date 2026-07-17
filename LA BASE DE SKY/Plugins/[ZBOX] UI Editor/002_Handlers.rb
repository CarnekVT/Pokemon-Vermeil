# encoding: utf-8
if $DEBUG
  MenuHandlers.add(:debug_menu, :zbox_uieditor, {
    "name"        => _INTL("UI Editor..."),
    "parent"      => :main,
    "description" => _INTL("Editor visual de coordenadas de la UI"),
    "effect"      => proc {
      pbFadeOutIn {
        scene = ZBOX_UIEditor::Scene.new
        screen = ZBOX_UIEditor::Screen.new(scene)
        screen.pbStartScreen
      }
      next false
    }
  })
end
