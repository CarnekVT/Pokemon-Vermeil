#===============================================================================
# Carnek Project Settings - Golden move names in Enhanced Battle UI
# Pokémon Essentials v21.1 / Golden Power / DBK Enhanced Battle UI
#
# This lives outside third-party plugins so Enhanced Battle UI updates cannot
# remove the Golden name refresh or its layer authority.
#===============================================================================

# The actual rendering hook is deliberately applied as a prepend. It calls the
# original menu refresh first, then redraws only the visible move labels with
# Golden Power's display name when that API is available.
module CarnekProjectSettings::GoldenMoveNameRefresh
  def refreshButtonNames
    # Keep the normal DBK/Essentials renderer alive. The old hook replaced it
    # entirely, so move names vanished whenever its private overlay was absent.
    ret = super
    moves = (@battler) ? @battler.moves : []
    if !defined?(USE_GRAPHICS) || !USE_GRAPHICS
      commands = []
      [4, moves.length].max.times do |i|
        move = moves[i]
        name = if move && move.respond_to?(:golden_display_name)
                 move.golden_display_name(@battler)
               else
                 move ? move.name : "-"
               end
        commands << name
      end
      @cmdWindow.commands = commands if defined?(@cmdWindow) && @cmdWindow
      return ret
    end
    return ret unless defined?(@overlay) && @overlay && defined?(@buttons) && @buttons
    @overlay.bitmap.clear
    text_pos = []
    @buttons.each_with_index do |button, i|
      next if @visibility && !@visibility["button_#{i}"]
      move = moves[i]
      next if !move
      x = button.x - self.x + (button.src_rect.width / 2)
      y = button.y - self.y + 14
      move_name = move.respond_to?(:golden_display_name) ? move.golden_display_name(@battler) : move.name
      move_name = move_name.to_s[0, 14] if move_name.to_s.length > 14
      base = @customUI ? @base_color : TEXT_BASE_COLOR
      shadow = @customUI ? @shadow_color : TEXT_SHADOW_COLOR
      text_pos << [move_name, x, y, :center, base, shadow]
    end
    pbDrawTextPositions(@overlay.bitmap, text_pos)
    ret
  rescue
    ret
  end
end

if defined?(Battle::Scene::FightMenu) &&
   !Battle::Scene::FightMenu.ancestors.include?(CarnekProjectSettings::GoldenMoveNameRefresh)
  Battle::Scene::FightMenu.prepend(CarnekProjectSettings::GoldenMoveNameRefresh)
end
