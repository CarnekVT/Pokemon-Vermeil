#===============================================================================
# Add to Debug menu.
#===============================================================================
MenuHandlers.add(:debug_menu, :new_animation_editor, {
  "name"        => _INTL("New battle animation editor"),
  "parent"      => :editors_menu,
  "description" => _INTL("Edit the battle animations."),
  "effect"      => proc {
    pbBGMStop
    Graphics.resize_screen(AnimationEditor::WINDOW_WIDTH, AnimationEditor::WINDOW_HEIGHT)
    pbSetResizeFactor(1, false)  # Changed: pass false to prevent automatic resize
    screen = AnimationEditor::AnimationSelector.new
    screen.run
    Graphics.resize_screen(Settings::SCREEN_WIDTH, Settings::SCREEN_HEIGHT)
    pbSetResizeFactor($PokemonSystem.screensize, false)  # Changed: pass false to prevent automatic resize
    $game_map&.autoplay
  }
})
