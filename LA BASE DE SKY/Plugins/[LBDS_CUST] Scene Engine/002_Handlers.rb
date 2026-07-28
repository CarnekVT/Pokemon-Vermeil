# encoding: utf-8
EventHandlers.add(:on_game_load, :lbds_cust_scene_engine_cleanup,
  proc { SceneEngine.instance_variable_set(:@players, {}) }
)

MenuHandlers.add(:debug_menu, :test_intro, {
  "name"        => _INTL("Intro Vermeil"),
  "parent"      => :main,
  "description" => _INTL("Ejecuta la cinemática de introducción"),
  "effect"      => proc {
    pbIntroVermeil
    next false
  }
})
