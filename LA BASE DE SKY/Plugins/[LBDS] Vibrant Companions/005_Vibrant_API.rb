#===============================================================================
# VIBRANT COMPANIONS - API & COMMANDS
# Comandos para usar en Eventos de RPG Maker
#===============================================================================

module VibrantCompanions
  #-----------------------------------------------------------------------------
  # CONTROL MAESTRO
  #-----------------------------------------------------------------------------
  
  # Desbloquea el sistema y saca a los Pokémon automáticamente.
  def self.enable(anim = true)
    Manager.save_data.system_enabled = true
    show(anim)
  end

  # Bloquea el sistema y guarda a los Pokémon automáticamente.
  def self.disable(anim = true)
    Manager.save_data.system_enabled = false
    hide(anim)
  end

  #-----------------------------------------------------------------------------
  # CONTROL DE VISIBILIDAD
  #-----------------------------------------------------------------------------
  
  # Saca a los Pokémon. anim = false los hace aparecer instantáneamente.
  def self.show(anim = true)
    return if Manager.toggled?
    Manager.toggle(true, anim)
  end

  # Guarda a los Pokémon. anim = false los desaparece instantáneamente.
  def self.hide(anim = true)
    return unless Manager.toggled?
    Manager.toggle(false, anim)
  end

  #-----------------------------------------------------------------------------
  # CONTROL DE MOVIMIENTO Y EMOCIONES
  #-----------------------------------------------------------------------------
  
  # Mueve a un Pokémon manualmente. 
  # index: 0 es el líder, 1 es el segundo, etc.
  # Ejemplo: VibrantCompanions.move([PBMoveRoute::JUMP, 0, 0], false, 2) # Hace saltar al 3er Pokémon
  def self.move(commands, wait_for_completion = false, index = 0)
    follower = $game_temp.followers.get_follower_by_name("VibrantFollower_#{index}")
    return unless follower
    pbMoveRoute(follower, commands, wait_for_completion)
  end

  # Muestra una burbuja de emoción en un Pokémon.
  # Tipos: :Exclamation, :Question, :Heart, :Happy, :Smile, :Music, :Ellipsis, :Sad, :Mad, :Angry, :Poison
  # Ejemplo: VibrantCompanions.emote(:Heart, 1) # Muestra un corazón en el 2do Pokémon
  def self.emote(type, index = 0)
    follower = $game_temp.followers.get_follower_by_name("VibrantFollower_#{index}")
    return unless follower
    Emotes.show(follower, type)
  end

  # Ejecuta una animación en un Pokémon.
  # Tipos: :shiver, :jump_happy, :spin, :look_around, :step_back, :love_rub
  # Ejemplo: VibrantCompanions.physical_emote(:spin, 0) # Hace girar al líder
  def self.physical_emote(type, index = 0)
    follower = $game_temp.followers.get_follower_by_name("VibrantFollower_#{index}")
    return unless follower
    PhysicalEmotes.play(follower, type)
  end

  #-----------------------------------------------------------------------------
  # 4. UTILIDADES
  #-----------------------------------------------------------------------------
  
  # Devuelve true si el o los Follower está actualmente fuera de sus Poké Ball.
  def self.active?
    return Manager.toggled?
  end

  # Devuelve el objeto del evento de un Pokémon específico.
  # Ejemplo: event = VibrantCompanions.event(2)
  def self.event(index = 0)
    return $game_temp.followers.get_follower_by_name("VibrantFollower_#{index}")
  end
end