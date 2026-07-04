#===============================================================================
# VIBRANT COMPANIONS - COMPATIBILITY
# Capa de compatibilidad para comandos del "Following Pokemon EX"
#===============================================================================

module FollowingPkmn
  #-----------------------------------------------------------------------------
  # Constantes heredadas de Following Pokemon EX
  #-----------------------------------------------------------------------------
  ANIMATION_COME_OUT        = VibrantCompanions::Settings::ANIM_APPEAR
  ANIMATION_COME_IN         = VibrantCompanions::Settings::ANIM_RECALL
  ANIMATION_EMOTE_HEART     = 9
  ANIMATION_EMOTE_MUSIC     = 12
  ANIMATION_EMOTE_HAPPY     = 10
  ANIMATION_EMOTE_ELIPSES   = 13
  ANIMATION_EMOTE_ANGRY     = 16
  ANIMATION_EMOTE_POISON    = 17

  #-----------------------------------------------------------------------------
  # Redirección de Comandos de Control y Visibilidad
  #-----------------------------------------------------------------------------
  
  def self.start_following(event_id = nil, anim = true)
    VibrantCompanions.enable(anim)
  end

  def self.stop_following
    VibrantCompanions.disable(false)
  end

  def self.toggle(forced = nil, anim = true)
    if forced == false
      VibrantCompanions.hide(anim)
    elsif forced == true
      VibrantCompanions.show(anim)
    else
      VibrantCompanions::Manager.toggle(nil, anim)
    end
  end

  def self.toggle_off(anim = true)
    VibrantCompanions.disable(anim)
  end

  def self.toggle_on(anim = true)
    VibrantCompanions.enable(anim)
  end

  def self.lock_toggle
    VibrantCompanions::Manager.save_data.system_enabled = false
  end

  def self.unlock_toggle
    VibrantCompanions::Manager.save_data.system_enabled = true
  end

  #-----------------------------------------------------------------------------
  # Redirección de Interacción y Movimiento
  #-----------------------------------------------------------------------------

  def self.talk
    VibrantCompanions::Interaction.start(0)
  end

  def self.move_route(commands = nil, wait_complete = false)
    return unless commands
    VibrantCompanions.move(commands, wait_complete, 0)
  end

  def self.animation(id = nil)
    return unless id
    event = VibrantCompanions.event(0)
    if event && $scene.is_a?(Scene_Map)
      spriteset = $scene.spriteset($game_map.map_id)
      spriteset.addUserAnimation(id, event.x, event.y, true, 1) if spriteset
    end
  end

  #-----------------------------------------------------------------------------
  # Redirección de Utilidades
  #-----------------------------------------------------------------------------

  def self.active?
    return VibrantCompanions.active?
  end

  def self.get
    event = VibrantCompanions.event(0)
    return nil unless event
    follower_data = $PokemonGlobal.followers.find { |f| f.name == "VibrantFollower_0" }
    return [event, follower_data]
  end

  def self.get_event
    return VibrantCompanions.event(0)
  end

  def self.get_data
    return $PokemonGlobal.followers.find { |f| f.name == "VibrantFollower_0" }
  end

  def self.get_pokemon
    return $player.first_able_pokemon
  end

  def self.refresh(anim = false)
    VibrantCompanions::Manager.refresh
    if anim && active?
      if $scene.is_a?(Scene_Map)
        spriteset = $scene.spriteset($game_map.map_id)
        if spriteset
          # Reproducir animación en todo el tren
          $game_temp.followers.each_follower do |event, follower|
            if follower.name && follower.name.start_with?("VibrantFollower_")
              spriteset.addUserAnimation(ANIMATION_COME_OUT, event.x, event.y, true, 1)
            end
          end
        end
      end
    end
  end
end