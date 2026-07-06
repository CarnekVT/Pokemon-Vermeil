# encoding: utf-8
#===============================================================================
# [ZBOX] Vibrant Adapted — Core
# Manager, SaveData, toggle, spawn de followers.
# Single follower approach (FPEX).
#===============================================================================

if defined?(Spriteset_Global)
  class Spriteset_Global
    attr_reader :follower_sprites
  end
end

module VibrantAdapted
  FOLLOWER_NAME = "VibrantFollower"

  #=============================================================================
  # PluginState — datos persistentes
  #=============================================================================
  class PluginState
    attr_accessor :toggled
    attr_accessor :steps
    attr_accessor :holding_item
    attr_accessor :system_enabled

    def conga_timer
      @conga_timer = 0.0 if @conga_timer.nil?
      return @conga_timer
    end
    attr_writer :conga_timer

    def initialize
      @toggled        = false
      @steps          = 0
      @holding_item   = nil
      @system_enabled = false
      @conga_timer    = 0.0
    end
  end

  #=============================================================================
  # Manager
  #=============================================================================
  module Manager
    @@state = PluginState.new
    @@just_loaded = false

    def self.save_data; return @@state; end

    def self.load_data(data)
      @@state = data || PluginState.new
      @@just_loaded = true
    end

    def self.toggled?; return @@state.toggled; end
    def self.just_loaded?; return @@just_loaded; end
    def self.clear_just_loaded; @@just_loaded = false; end

    #--- Toggle ---
    def self.toggle(force_state = nil, with_anim = true)
      old_state = @@state.toggled
      @@state.toggled = force_state.nil? ? !old_state : force_state

      if old_state && !@@state.toggled && with_anim
        play_toggle_animation(false)
      end

      refresh

      if !old_state && @@state.toggled && with_anim
        play_toggle_animation(true)
      end
    end

    #--- Refresh ---
    def self.refresh
      is_indoor = $game_map && $game_map.metadata && !$game_map.metadata.outdoor_map
      indoor_blocked = is_indoor && !VibrantAdapted::Settings.allow_indoors?

      waiting_surf = defined?(VehicleMonitor) && VehicleMonitor.waiting_for_land_step?

      if !@@state.toggled || $player.party.empty? ||
         $PokemonGlobal.bicycle || $PokemonGlobal.surfing || $PokemonGlobal.diving ||
         indoor_blocked || waiting_surf
        remove_follower
        return
      end

      pkmn = $player.first_able_pokemon
      unless pkmn
        remove_follower
        return
      end

      existing = $game_temp.followers.get_follower_by_name(FOLLOWER_NAME)
      if existing
        character_name = get_pokemon_graphic(pkmn)
        existing.character_name = character_name
        existing.character_hue  = pkmn.respond_to?(:superShiny?) && pkmn.superShiny? ? pkmn.superHue : 0
      else
        spawn_follower(pkmn)
      end

      if $scene.is_a?(Scene_Map) && $scene.spritesetGlobal && $scene.spritesetGlobal.respond_to?(:follower_sprites)
        fs = $scene.spritesetGlobal.follower_sprites
        fs.refresh if fs
      end
    end

    #--- Animaciones ---
    def self.play_dynamic_animation(spriteset, anim_id, x, y, pkmn)
      anim = $data_animations[anim_id]
      if anim && pkmn
        original_name = anim.animation_name
        ball_name = "Ball_#{pkmn.poke_ball}"
        begin
          if pbResolveBitmap("Graphics/Animations/#{ball_name}.png") || pbResolveBitmap("Graphics/Animations/#{ball_name}")
            anim.animation_name = ball_name
          elsif pbResolveBitmap("Graphics/Animations/Ball_POKEBALL.png") || pbResolveBitmap("Graphics/Animations/Ball_POKEBALL")
            anim.animation_name = "Ball_POKEBALL"
          end
          spriteset.addUserAnimation(anim_id, x, y, true, 1)
        ensure
          anim.animation_name = original_name
        end
      else
        spriteset.addUserAnimation(anim_id, x, y, true, 1) if anim
      end
    end

    private

    def self.remove_follower
      if defined?(VibrantAdapted::EasterEggs)
        VibrantAdapted::EasterEggs.cancel_conga
      else
        @@state.conga_timer = 0.0 if @@state
      end

      existing = $game_temp.followers.get_follower_by_name(FOLLOWER_NAME)
      if existing
        $game_temp.followers.remove_follower_by_name(FOLLOWER_NAME)
        if $scene.is_a?(Scene_Map) && $scene.spritesetGlobal && $scene.spritesetGlobal.respond_to?(:follower_sprites)
          fs = $scene.spritesetGlobal.follower_sprites
          fs.refresh if fs
        end
      end
    end

    #--- Spawn: crear FollowerData + Game_PokemonFollower (FPEX approach) ---
    def self.spawn_follower(pkmn)
      character_name = get_pokemon_graphic(pkmn)
      character_hue  = pkmn.respond_to?(:superShiny?) && pkmn.superShiny? ? pkmn.superHue : 0

      pos = find_free_tile

      event_data = FollowerData.new(
        $game_map.map_id,
        999,
        FOLLOWER_NAME,
        $game_map.map_id,
        pos[:x],
        pos[:y],
        $game_player.direction,
        character_name,
        character_hue
      )
      event_data.name            = FOLLOWER_NAME
      event_data.common_event_id = nil

      $game_temp.followers.add_follower_data(event_data)

      follower = $game_temp.followers.get_follower_by_name(FOLLOWER_NAME)
      if follower && follower.is_a?(Game_PokemonFollower)
        follower.va_species = pkmn.species
      end
    end

    def self.find_free_tile
      px = $game_player.x
      py = $game_player.y
      pd = $game_player.direction

      back_dir = 10 - pd
      behind = case back_dir
               when 2 then { x: px,     y: py + 1 }
               when 4 then { x: px - 1, y: py }
               when 6 then { x: px + 1, y: py }
               when 8 then { x: px,     y: py - 1 }
               end

      others = [
        { x: px,     y: py - 1 },
        { x: px - 1, y: py },
        { x: px + 1, y: py },
        { x: px,     y: py + 1 },
        { x: px - 1, y: py - 1 },
        { x: px + 1, y: py - 1 },
        { x: px - 1, y: py + 1 },
        { x: px + 1, y: py + 1 }
      ].reject { |c| c[:x] == behind[:x] && c[:y] == behind[:y] }

      candidates = [behind] + others

      occupied = $game_map.events.values.map { |e| [e.x, e.y] }

      candidates.each do |c|
        next unless c[:x] >= 0 && c[:x] < $game_map.width
        next unless c[:y] >= 0 && c[:y] < $game_map.height
        next if occupied.include?([c[:x], c[:y]])
        next if px == c[:x] && py == c[:y]
        next if VibrantAdapted::Settings.water_tile?(c[:x], c[:y])
        return c
      end

      return { x: px, y: py }
    end

    #--- Gráfico del Pokémon (check_graphic_file de Essentials) ---
    def self.get_pokemon_graphic(pkmn)
      return "" if !pkmn || pkmn.egg?
      filename = GameData::Species.check_graphic_file(
        "Graphics/Characters/", pkmn.species, pkmn.form,
        pkmn.gender, pkmn.shiny?, pkmn.shadow, "Followers"
      )
      if filename.nil? || filename.empty?
        folder = pkmn.shiny? ? "Followers shiny/" : "Followers/"
        fallback = "#{folder}#{pkmn.species}"
        if pbResolveBitmap("Graphics/Characters/#{fallback}.png") || pbResolveBitmap("Graphics/Characters/#{fallback}")
          return fallback
        else
          return pkmn.species.to_s
        end
      end
      filename = filename.gsub("Graphics/Characters/", "").gsub(".png", "").gsub(".gif", "")
      return filename
    end

    #--- Animación toggle ---
    def self.play_toggle_animation(appearing)
      return unless $scene.is_a?(Scene_Map)
      spriteset = $scene.spriteset($game_map.map_id)
      return unless spriteset

      anim_id = appearing ? VibrantAdapted::Settings::ANIM_APPEAR : VibrantAdapted::Settings::ANIM_RECALL
      pkmn = $player.first_able_pokemon
      event = $game_temp.followers.get_follower_by_name(FOLLOWER_NAME)
      play_dynamic_animation(spriteset, anim_id, event.x, event.y, pkmn) if event && pkmn
    end
  end
end

#===============================================================================
# Game_FollowerFactory — aceptar FollowerData directamente (FPEX approach)
#===============================================================================
class Game_FollowerFactory
  def add_follower_data(event_data)
    followers = $PokemonGlobal.followers
    return if followers.any? { |data| data.name == event_data.name }
    followers.push(event_data)
    newEvent = create_follower_object(event_data)
    @events.push(newEvent)
    @last_update += 1
  end
end

#===============================================================================
# SaveData
#===============================================================================
SaveData.register(:vibrant_adapted) do
  save_value { VibrantAdapted::Manager.save_data }
  load_value { |data| VibrantAdapted::Manager.load_data(data) }
  new_game_value { VibrantAdapted::PluginState.new }
end

#===============================================================================
# Hooks
#===============================================================================

EventHandlers.add(:on_map_or_spriteset_change, :va_follower_refresh, proc {
  VibrantAdapted::Manager.refresh
})

EventHandlers.add(:on_frame_update, :va_follower_input, proc {
  next if $game_temp.in_menu || $game_temp.message_window_showing
  next if $game_player.moving? || $game_player.lock?
  next if $game_temp.in_battle || $game_temp.encounter_triggered
  next unless VibrantAdapted::Manager.save_data.system_enabled
  if Input.trigger?(VibrantAdapted::Settings::TOGGLE_KEY)
    pbPlayDecisionSE
    VibrantAdapted::Manager.toggle
  end
})

EventHandlers.add(:on_frame_update, :va_cycle_party, proc {
  next if $game_temp.in_menu || $game_temp.message_window_showing
  next if $game_player.moving? || $game_player.lock?
  next if $game_temp.in_battle || $game_temp.encounter_triggered
  next unless VibrantAdapted::Manager.save_data.system_enabled
  next unless VibrantAdapted::Manager.toggled?
  next if $player.party.length < 2
  if Input.trigger?(VibrantAdapted::Settings::CYCLE_PARTY_FORWARD_KEY)
    pbPlayDecisionSE
    $player.party.rotate!
    VibrantAdapted::Manager.refresh
  elsif Input.trigger?(VibrantAdapted::Settings::CYCLE_PARTY_BACKWARD_KEY)
    pbPlayDecisionSE
    $player.party.rotate!(-1)
    VibrantAdapted::Manager.refresh
  end
})

EventHandlers.add(:on_frame_update, :va_clear_load_flag, proc {
  next unless VibrantAdapted::Manager.just_loaded?
  if $scene.is_a?(Scene_Map)
    VibrantAdapted::Manager.clear_just_loaded
  end
})

#===============================================================================
# Hooks de pantallas
#===============================================================================
class PokemonParty_Scene
  alias va_pbEndScene pbEndScene unless method_defined?(:va_pbEndScene)
  def pbEndScene
    VibrantAdapted::Manager.refresh if VibrantAdapted::Manager.toggled?
    va_pbEndScene
  end
end

class PokemonStorageScene
  alias va_pbCloseBox pbCloseBox unless method_defined?(:va_pbCloseBox)
  def pbCloseBox
    VibrantAdapted::Manager.refresh if VibrantAdapted::Manager.toggled?
    va_pbCloseBox
  end
end

class PokemonEvolutionScene
  alias va_pbEndScreen pbEndScreen unless method_defined?(:va_pbEndScreen)
  def pbEndScreen(*args)
    VibrantAdapted::Manager.refresh if VibrantAdapted::Manager.toggled?
    va_pbEndScreen(*args)
  end
end

alias va_pbHatch pbHatch unless defined?(va_pbHatch)
def pbHatch(*args)
  ret = va_pbHatch(*args)
  VibrantAdapted::Manager.refresh if VibrantAdapted::Manager.toggled?
  return ret
end

alias va_pbChooseItem pbChooseItem unless defined?(va_pbChooseItem)
def pbChooseItem(*args)
  ret = va_pbChooseItem(*args)
  VibrantAdapted::Manager.refresh if VibrantAdapted::Manager.toggled?
  return ret
end
