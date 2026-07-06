# encoding: utf-8
#===============================================================================
# [ZBOX] Vibrant Adapted — Interaction & Dialogues (FPEX EventHandlers pattern)
#===============================================================================

module VibrantAdapted
  #=============================================================================
  # Helpers
  #=============================================================================
  module Interaction
    def self.can_talk?
      return false if $game_temp.in_menu || $game_temp.in_battle
      return false if $game_player.move_route_forcing
      return false if $game_temp.message_window_showing
      follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
      return false if follower && follower.move_route_forcing
      return true
    end
  end

  #=============================================================================
  # Easter Eggs (placeholder para integrar)
  #=============================================================================
  module EasterEggs
    def self.try_trigger(pkmn, event)
      return false
    end

    def self.cancel_conga
      state = VibrantAdapted::Manager.save_data
      state.conga_timer = 0.0 if state
    end
  end
end

#===============================================================================
# :following_pkmn_talk — handlers con prioridad (FPEX pattern)
#===============================================================================

# Status handlers (prioridad alta, devuelven true si matchean)
[:POISON, :BURN, :PARALYSIS, :FROZEN, :SLEEP].each do |status_sym|
  EventHandlers.add(:following_pkmn_talk, :"va_status_#{status_sym.downcase}", proc { |pkmn, random_val|
    next false if pkmn.status != status_sym
    next false unless VibrantAdapted::Interaction.can_talk?
    follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
    case status_sym
    when :POISON
      if follower
        VibrantAdapted::Emotes.show(follower, :Poison)
        VibrantAdapted::PhysicalEmotes.play(follower, :shiver)
      end
      pbMessage(_INTL("{1} está tiritando a causa del veneno.", pkmn.name))
    when :BURN
      if follower
        VibrantAdapted::Emotes.show(follower, :Angry)
        VibrantAdapted::PhysicalEmotes.play(follower, :step_back)
      end
      pbMessage(_INTL("Parece que a {1} le duele mucho su quemadura.", pkmn.name))
    when :PARALYSIS
      if follower
        VibrantAdapted::Emotes.show(follower, :Ellipsis)
        VibrantAdapted::PhysicalEmotes.play(follower, :shiver)
      end
      pbMessage(_INTL("{1} está temblando y tiene sacudidas.", pkmn.name))
    when :FROZEN
      if follower
        VibrantAdapted::Emotes.show(follower, :Ellipsis)
        VibrantAdapted::PhysicalEmotes.play(follower, :shiver)
      end
      pbMessage(_INTL("Da la impresión de que {1} está pasando mucho frío.", pkmn.name))
    when :SLEEP
      if follower
        VibrantAdapted::Emotes.show(follower, :Ellipsis)
      end
      pbMessage(_INTL("{1} parece agotado y medio dormido.", pkmn.name))
    end
    next true
  })
end

# Low HP handler
EventHandlers.add(:following_pkmn_talk, :va_low_hp, proc { |pkmn, random_val|
  next false if pkmn.hp > pkmn.totalhp / 4
  next false unless VibrantAdapted::Interaction.can_talk?
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Sad)
    VibrantAdapted::PhysicalEmotes.play(follower, :shiver)
  end
  pbMessage(_INTL("{1} parece estar a punto de desmayarse...", pkmn.name))
  next true
})

# Weather handlers
EventHandlers.add(:following_pkmn_talk, :va_weather_rain, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false unless [:Rain, :HeavyRain, :Thunder].include?($game_screen.weather_type)
  next false unless pkmn.hasType?(:WATER) || pkmn.hasType?(:ELECTRIC) ||
                   pkmn.hasType?(:FIRE) || pkmn.hasType?(:ROCK) || pkmn.hasType?(:GROUND)
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if pkmn.hasType?(:WATER) || pkmn.hasType?(:ELECTRIC)
    if follower
      VibrantAdapted::Emotes.show(follower, :Happy)
      VibrantAdapted::PhysicalEmotes.play(follower, :jump_happy)
    end
    pbMessage(_INTL("¡{1} parece estar disfrutando de la lluvia!", pkmn.name))
  else
    if follower
      VibrantAdapted::Emotes.show(follower, :Sad)
      VibrantAdapted::PhysicalEmotes.play(follower, :shiver)
    end
    pbMessage(_INTL("{1} odia mojarse y está tiritando...", pkmn.name))
  end
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_weather_snow, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false unless [:Snow, :Blizzard].include?($game_screen.weather_type)
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if pkmn.hasType?(:ICE)
    if follower
      VibrantAdapted::Emotes.show(follower, :Happy)
      VibrantAdapted::PhysicalEmotes.play(follower, :spin)
    end
    pbMessage(_INTL("¡{1} adora la nieve y el frío!", pkmn.name))
  else
    if follower
      VibrantAdapted::Emotes.show(follower, :Ellipsis)
      VibrantAdapted::PhysicalEmotes.play(follower, :shiver)
    end
    pbMessage(_INTL("{1} se encogió debido al frío...", pkmn.name))
  end
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_weather_sandstorm, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false unless $game_screen.weather_type == :Sandstorm
  next false unless pkmn.hasType?(:ROCK) || pkmn.hasType?(:GROUND) || pkmn.hasType?(:STEEL)
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Happy)
    VibrantAdapted::PhysicalEmotes.play(follower, :jump_happy)
  end
  pbMessage(_INTL("¡{1} parece inmune a la tormenta de arena!", pkmn.name))
  next true
})

# Map-specific handlers
EventHandlers.add(:following_pkmn_talk, :va_map_pokecenter, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  map_meta = $game_map.metadata
  next false unless map_meta && map_meta.has_flag?("PokeCenter")
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Happy)
    VibrantAdapted::PhysicalEmotes.play(follower, :spin)
  end
  pbMessage(_INTL("{1} se ve relajado por el ambiente curativo.", pkmn.name))
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_map_gym, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  map_meta = $game_map.metadata
  next false unless map_meta && (map_meta.has_flag?("GymMap") || map_meta.has_flag?("Gym"))
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Angry)
    VibrantAdapted::PhysicalEmotes.play(follower, :jump_happy)
  end
  pbMessage(_INTL("¡{1} está concentrado y listo para pelear!", pkmn.name))
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_map_lab, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  map_meta = $game_map.metadata
  next false unless map_meta && map_meta.has_flag?("Pokemon Lab")
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Question)
    VibrantAdapted::PhysicalEmotes.play(follower, :look_around)
  end
  pbMessage(_INTL("{1} mira todo con mucha curiosidad.", pkmn.name))
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_map_player_house, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  map_meta = $game_map.metadata
  next false unless map_meta && map_meta.has_flag?("Player's House")
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Heart)
    VibrantAdapted::PhysicalEmotes.play(follower, :love_rub)
  end
  pbMessage(_INTL("¡{1} se ve muy contento de estar en casa!", pkmn.name))
  next true
})

# Happiness handlers
EventHandlers.add(:following_pkmn_talk, :va_happiness_high, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false if pkmn.happiness >= 220
  next false if pkmn.happiness < 50
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if pkmn.happiness >= 220
    if follower
      VibrantAdapted::Emotes.show(follower, :Heart)
      VibrantAdapted::PhysicalEmotes.play(follower, :love_rub)
    end
    pbMessage(_INTL("¡{1} se frota cariñosamente contra las piernas de {2}!", pkmn.name, $player.name))
  else
    if follower
      VibrantAdapted::Emotes.show(follower, :Mad)
      VibrantAdapted::PhysicalEmotes.play(follower, :step_back)
    end
    pbMessage(_INTL("{1} mira hacia otro lado, ignorando a {2}...", pkmn.name, $player.name))
  end
  next true
})

# Generic handlers (random_val dispatch, 5 categorías como FPEX)
EventHandlers.add(:following_pkmn_talk, :va_generic_music, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false if random_val != 0
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Music)
    VibrantAdapted::PhysicalEmotes.play(follower, :spin)
  end
  pbMessage(_INTL("{1} está tarareando una melodía feliz.", pkmn.name))
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_generic_angry, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false if random_val != 1
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Angry)
    VibrantAdapted::PhysicalEmotes.play(follower, :step_back)
  end
  pbMessage(_INTL("{1} está gruñendo por nada en particular.", pkmn.name))
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_generic_ellipses, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false if random_val != 2
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Ellipsis)
    VibrantAdapted::PhysicalEmotes.play(follower, :look_around)
  end
  pbMessage(_INTL("{1} mira fijamente al horizonte.", pkmn.name))
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_generic_happy, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false if random_val != 3
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Happy)
    VibrantAdapted::PhysicalEmotes.play(follower, :jump_happy)
  end
  pbMessage(_INTL("¡{1} da saltitos de alegría!", pkmn.name))
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_generic_question, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false if random_val != 4
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Question)
    VibrantAdapted::PhysicalEmotes.play(follower, :look_around)
  end
  pbMessage(_INTL("{1} olfatea el aire con curiosidad.", pkmn.name))
  next true
})

EventHandlers.add(:following_pkmn_talk, :va_generic_smile, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  next false if random_val != 5
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::Emotes.show(follower, :Smile)
    VibrantAdapted::PhysicalEmotes.play(follower, :jump_happy)
  end
  pbMessage(_INTL("{1} te sigue alegremente.", pkmn.name))
  next true
})

#===============================================================================
# :following_pkmn_item — item finding system (FPEX pattern)
#===============================================================================
EventHandlers.add(:following_pkmn_item, :va_find_item, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Settings.allow_interact?
  next false unless pkmn
  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  next false unless follower

  state = VibrantAdapted::Manager.save_data
  state.steps += 1

  # Check if already holding item
  if state.holding_item.nil?
    time_needed = VibrantAdapted::Settings::ITEM_TIME_TAKEN
    if state.steps >= time_needed
      state.steps = 0
      if rand(100) < 5
        state.holding_item = :POTION
        if follower
          VibrantAdapted::Emotes.show(follower, :Music)
        end
      end
    end
  end

  next false
})

# Item give handler (triggered from Interaction when holding_item is set)
EventHandlers.add(:following_pkmn_talk, :va_give_item, proc { |pkmn, random_val|
  next false unless VibrantAdapted::Interaction.can_talk?
  state = VibrantAdapted::Manager.save_data
  item_id = state.holding_item
  next false if item_id.nil?

  item = GameData::Item.try_get(item_id)
  next false unless item

  follower = $game_temp.followers.get_follower_by_name(VibrantAdapted::FOLLOWER_NAME)
  if follower
    VibrantAdapted::PhysicalEmotes.play(follower, :jump_happy)
  end
  pbMessage(_INTL("¡{1} parece estar sujetando algo en su boca!", pkmn.name))

  if $bag.add(item_id, 1)
    itemname = item.portion_name
    pocket   = item.pocket
    meName   = item.is_key_item? ? "Key item get" : "Item get"

    if item.is_machine?
      meName = "Machine get"
      move_name = GameData::Move.get(item.move).name
      pbMessage(_INTL("\\me[{1}]¡Recibiste \\c[1]{2} {3}\\c[0] de {4}!\\wtnp[70]",
                      meName, itemname, move_name, pkmn.name))
    else
      pbMessage(_INTL("\\me[{1}]¡Recibiste \\c[1]{2}\\c[0] de {3}!\\wtnp[40]",
                      meName, itemname, pkmn.name))
    end

    pocket_name = PokemonBag.pocket_names[pocket - 1]
    pbMessage(_INTL("Has guardado {1} en\\nel bolsillo <icon=bagPocket{2}>\\c[1]{3}\\c[0].",
                    itemname, pocket, pocket_name))

    if defined?($item_log) && $item_log.respond_to?(:register)
      $item_log.register(item_id)
    end

    state.holding_item = nil
  else
    pbMessage(_INTL("Pero tu mochila está llena..."))
  end

  next true
})
