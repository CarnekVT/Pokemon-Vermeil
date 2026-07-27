# encoding: utf-8
EventHandlers.add(:on_game_load, :lbds_cust_scene_engine_cleanup,
  proc { SceneEngine.instance_variable_set(:@players, {}) }
)

# Debug F9 menu entry for quick scene testing
MenuHandlers.add(:debug_menu, :test_scene, {
  "name"        => _INTL("Probar Scene"),
  "parent"      => :main,
  "description" => _INTL("Ejecuta una scene guardada en Graphics/Scenes/"),
  "effect"      => proc {
    scenes = Dir.get("Graphics/Scenes").select { |d| Dir.safe?(d) && File.directory?("Graphics/Scenes/#{d}") }
    next false if scenes.empty?
    cmd = pbMessage(_INTL("¿Qué scene probar?"), scenes, -1)
    SceneEngine.play(scenes[cmd]) if cmd >= 0
    next false
  }
})
