module Settings
  # El ANCHO por defecto de la pantalla en píxeles (en escala 1.0).
  SCREEN_WIDTH = 640
  # El ALTO de la pantalla en píxelex (en escala 1.0).
  SCREEN_HEIGHT = 480

  # El fondo se mueve a los lados al inicio de la batalla, junto con las bases laterales y el/los entrenador(es)/Pokémon.
  # Si esto es true, el fondo no se moverá (las bases/entrenadores/Pokémon sí lo harán).
  DISABLE_SLIDING_BACKGROUND = true

  # Los sprites de entrenadores, Pokémon y sus sombras se mueven a los lados al inicio de la batalla.
  # Si esto es true, estos sprites no se moverán al iniciar el combate.
  DISABLE_SLIDING_SPRITES = true

  # Las bases de combate se mueven a los lados al inicio de la batalla.
  # Si esto es true, las bases no se deslizarán al entrar al combate.
  DISABLE_SLIDING_BASES = true

  # Mostrar las bases de batalla (true) o no (false). Ten en cuenta que esto no afecta a los fondos de batalla, solo a las bases.
  SHOW_BATTLE_BASES = false
  
  DYNAMIC_CAMERA_ON = false
  ENABLE_CAMERA_APPROACH = true
  CAMERA_ZOOM_LEVELS = {
    default: 1.25,
    strong: 1.35,
    sos: 1.15
  }

  # Helper methods for convenient access
  def self.dynamic_camera_enabled?
    DYNAMIC_CAMERA_ON
  end

  def self.show_battle_bases?
    SHOW_BATTLE_BASES
  end

  def self.camera_approach_enabled?
    ENABLE_CAMERA_APPROACH
  end

  def self.disable_sliding_background?
    DISABLE_SLIDING_BACKGROUND
  end

  def self.disable_sliding_sprites?
    DISABLE_SLIDING_SPRITES
  end

  def self.disable_sliding_bases?
    DISABLE_SLIDING_BASES
  end

  def self.zoom_level(key = :default)
    CAMERA_ZOOM_LEVELS[key] || 1.25
  end
end
