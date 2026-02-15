module Settings
  # The save slot options available to the player. Is one of:
  #   * :one       = Classic saving. There is only one save file and it is
  #                  replaced upon saving..
  #   * :adventure = Each adventure (i.e. starting a New Game) has its own
  #                  single save slot. Allows the player to have multiple
  #                  adventures saved, but each adventure behaves clasically
  #                  when it comes to saving.
  #   * :multiple  = An infinite number of save slots are always available. The
  #                  player can choose to save in an empty save slot at any
  #                  time, or overwrite an existing save slot.
  SAVE_SLOTS = :multiple
  # Whether the game will skip the intro splash screens and title screen, and go
  # straight to the Continue/New Game screen. Only applies to playing in Debug
  # mode.
  SKIP_TITLE_SCREEN    = true
  # Whether the game will skip the Continue/New Game screen and go straight into
  # a saved game (if there is one) or start a new game (if there isn't). Only
  # applies to playing in Debug mode.
  SKIP_CONTINUE_SCREEN = false
end