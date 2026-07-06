# encoding: utf-8
#===============================================================================
# [ZBOX] Vibrant Adapted — API & Commands
#===============================================================================

module VibrantAdapted
  def self.enable(anim = true)
    Manager.save_data.system_enabled = true
    show(anim)
  end

  def self.disable(anim = true)
    Manager.save_data.system_enabled = false
    hide(anim)
  end

  def self.show(anim = true)
    return if Manager.toggled?
    Manager.toggle(true, anim)
  end

  def self.hide(anim = true)
    return unless Manager.toggled?
    Manager.toggle(false, anim)
  end

  def self.move(commands, wait_for_completion = false)
    follower = $game_temp.followers.get_follower_by_name(FOLLOWER_NAME)
    return unless follower
    pbMoveRoute(follower, commands, wait_for_completion)
  end

  def self.emote(type)
    follower = $game_temp.followers.get_follower_by_name(FOLLOWER_NAME)
    return unless follower
    Emotes.show(follower, type)
  end

  def self.physical_emote(type)
    follower = $game_temp.followers.get_follower_by_name(FOLLOWER_NAME)
    return unless follower
    PhysicalEmotes.play(follower, type)
  end

  def self.active?
    return Manager.toggled?
  end

  def self.event
    return $game_temp.followers.get_follower_by_name(FOLLOWER_NAME)
  end
end

#===============================================================================
# FollowingPkmn compatibility — redirige comandos de FPEX a Vibrant Adapted
#===============================================================================
if !defined?(FollowingPkmn)
  module FollowingPkmn
    ANIMATION_COME_OUT      = VibrantAdapted::Settings::ANIM_APPEAR
    ANIMATION_COME_IN       = VibrantAdapted::Settings::ANIM_RECALL
    ANIMATION_EMOTE_HEART   = 9
    ANIMATION_EMOTE_MUSIC   = 12
    ANIMATION_EMOTE_HAPPY   = 10
    ANIMATION_EMOTE_ELIPSES = 13
    ANIMATION_EMOTE_ANGRY   = 16
    ANIMATION_EMOTE_POISON  = 17

    def self.start_following(event_id = nil, anim = true)
      VibrantAdapted.enable(anim)
    end

    def self.stop_following
      VibrantAdapted.disable(false)
    end

    def self.toggle(forced = nil, anim = true)
      if forced == false
        VibrantAdapted.hide(anim)
      elsif forced == true
        VibrantAdapted.show(anim)
      else
        VibrantAdapted::Manager.toggle(nil, anim)
      end
    end

    def self.toggle_off(anim = true)
      VibrantAdapted.disable(anim)
    end

    def self.toggle_on(anim = true)
      VibrantAdapted.enable(anim)
    end

    def self.lock_toggle
      VibrantAdapted::Manager.save_data.system_enabled = false
    end

    def self.unlock_toggle
      VibrantAdapted::Manager.save_data.system_enabled = true
    end

    def self.talk
      pkmn = $player.first_able_pokemon
      return unless pkmn
      follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
      return unless follower
      $game_player.lock
      random_val = rand(6)
      EventHandlers.trigger(:following_pkmn_talk, pkmn, random_val)
      $game_player.unlock
    end

    def self.move_route(commands = nil, wait_complete = false)
      return unless commands
      VibrantAdapted.move(commands, wait_complete)
    end

    def self.animation(id = nil)
      return unless id
      event = VibrantAdapted.event
      if event && $scene.is_a?(Scene_Map)
        spriteset = $scene.spriteset($game_map.map_id)
        spriteset.addUserAnimation(id, event.x, event.y, true, 1) if spriteset
      end
    end

    def self.active?
      return VibrantAdapted.active?
    end

    def self.get
      event = VibrantAdapted.event
      return nil unless event
      follower_data = $PokemonGlobal.followers.find { |f| f.name == VibrantAdapted::FOLLOWER_NAME }
      return [event, follower_data]
    end

    def self.get_event
      return VibrantAdapted.event
    end

    def self.get_data
      return $PokemonGlobal.followers.find { |f| f.name == VibrantAdapted::FOLLOWER_NAME }
    end

    def self.get_pokemon
      return $player.first_able_pokemon
    end

    def self.refresh(anim = false)
      VibrantAdapted::Manager.refresh
      if anim && active?
        if $scene.is_a?(Scene_Map)
          spriteset = $scene.spriteset($game_map.map_id)
          if spriteset
            event = VibrantAdapted.event
            if event
              spriteset.addUserAnimation(ANIMATION_COME_OUT, event.x, event.y, true, 1)
            end
          end
        end
      end
    end
  end
end
