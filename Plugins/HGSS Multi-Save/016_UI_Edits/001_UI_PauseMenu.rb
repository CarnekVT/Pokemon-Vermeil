#===============================================================================
# Pause menu commands.
#===============================================================================

MenuHandlers.add(:pause_menu, :save, {
  "name"      => _INTL("Save"),
  "order"     => 60,
  "condition" => proc {
    next $game_system && !$game_system.save_disabled && !pbInSafari? && !pbInBugContest?
  },
  "effect"    => proc { |menu|
    pbPlayDecisionSE
    ret = false
    pbFadeOutIn do
      ret = UI::Save.new.main
      if ret
        menu.pbEndScene
      else
        menu.pbRefresh
		menu.pbShowMenu
      end
    end
    next ret
  }
})

MenuHandlers.add(:pause_menu, :quit_game, {
  "name"      => _INTL("Quit Game"),
  "order"     => 90,
  "effect"    => proc { |menu|
    menu.pbHideMenu
    if pbConfirmMessage(_INTL("Are you sure you want to quit the game?"))
	  # Suggested by http404error: https://eeveeexpo.com/resources/1059/
	  pbPlayCloseMenuSE
	  pbBGMFade(1.0)
	  pbBGSFade(1.0)
	  menu.visuals.fade_out
	  menu.silent_end_screen
      $scene = pbCallTitle
	  SaveData.mark_values_as_unloaded
      next true
    end
    menu.pbRefresh
    menu.pbShowMenu
    next false
  }
})
