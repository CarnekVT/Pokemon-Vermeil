#===============================================================================
# VIBRANT COMPANIONS - INTERACTION & DIALOGUES
#===============================================================================

module VibrantCompanions
  module PhysicalEmotes
    def self.play(event, type)
      return unless Settings::ENABLE_PHYSICAL_EMOTES
      return unless event

      case type
      when :shiver
        pbMoveRoute(event, [
          PBMoveRoute::TURN_RIGHT, PBMoveRoute::WAIT, 2,
          PBMoveRoute::TURN_LEFT, PBMoveRoute::WAIT, 2,
          PBMoveRoute::TURN_RIGHT, PBMoveRoute::WAIT, 2,
          PBMoveRoute::TURN_LEFT, PBMoveRoute::WAIT, 2,
          PBMoveRoute::TURN_TOWARD_PLAYER
        ])
      when :jump_happy
        pbMoveRoute(event, [
          PBMoveRoute::JUMP, 0, 0, PBMoveRoute::WAIT, 10,
          PBMoveRoute::JUMP, 0, 0
        ])
      when :spin
        pbMoveRoute(event, [
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 4,
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 4,
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 4,
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 4,
          PBMoveRoute::TURN_TOWARD_PLAYER
        ])
      when :look_around
        pbMoveRoute(event, [
          PBMoveRoute::TURN_RIGHT90, PBMoveRoute::WAIT, 15,
          PBMoveRoute::TURN180, PBMoveRoute::WAIT, 15,
          PBMoveRoute::TURN_TOWARD_PLAYER
        ])
      when :step_back
        pbMoveRoute(event, [
          PBMoveRoute::BACKWARD, PBMoveRoute::WAIT, 10,
          PBMoveRoute::FORWARD
        ])
      when :love_rub
        pbMoveRoute(event, [
          PBMoveRoute::FORWARD, PBMoveRoute::WAIT, 15,
          PBMoveRoute::BACKWARD
        ])
      end
    end
  end

  module Interaction

    @@is_interacting = false 
    def self.start
      return if @@is_interacting
      pkmn = $player.first_able_pokemon
      return unless pkmn
      follower = $game_temp.followers.get_follower_by_name("VibrantFollower_0")
      return unless follower
      
      @@is_interacting = true
      follower.turn_toward_player
      GameData::Species.play_cry_from_pokemon(pkmn)
      
      if defined?(EasterEggs) && EasterEggs.try_trigger(pkmn, follower)
        @@is_interacting = false
        return
      end

      if check_and_give_item(pkmn, follower)
        @@is_interacting = false
        return
      end
      
      reaction = decide_reaction(pkmn)
      
      Emotes.show(follower, reaction[:anim]) if reaction[:anim]
      PhysicalEmotes.play(follower, reaction[:phys]) if reaction[:phys]
      
      pbMessage(_INTL(reaction[:text], pkmn.name, $player.name))
      @@is_interacting = false
    end

    def self.check_and_give_item(pkmn, follower)
      state = Manager.save_data
      item_id = state.holding_item
      return false if item_id.nil?
      
      item = GameData::Item.get(item_id)
      PhysicalEmotes.play(follower, :jump_happy)
      pbMessage(_INTL("¡{1} parece estar sujetando algo en su boca!", pkmn.name))
      
      # Intentamos añadir 1 unidad a la mochila
      if $bag.add(item_id, 1)
        itemname = item.portion_name
        pocket   = item.pocket
        meName   = item.is_key_item? ? "Key item get" : "Item get"
        
        # 1. Mensaje de obtención con ME integrado
        if item.is_machine?
          meName = "Machine get"
          move_name = GameData::Move.get(item.move).name
          pbMessage(_INTL("\\me[{1}]¡Recibiste \\c[1]{2} {3}\\c[0] de {4}!\\wtnp[70]", 
                          meName, itemname, move_name, pkmn.name))
        else
          pbMessage(_INTL("\\me[{1}]¡Recibiste \\c[1]{2}\\c[0] de {3}!\\wtnp[40]", 
                          meName, itemname, pkmn.name))
        end
        
        # 2. Mensaje de guardado en el bolsillo con icono
        pocket_name = PokemonBag.pocket_names[pocket - 1]
        pbMessage(_INTL("Has guardado {1} en\\nel bolsillo <icon=bagPocket{2}>\\c[1]{3}\\c[0].", 
                        itemname, pocket, pocket_name))
        
        # 3. INTEGRACIÓN CON PLUGIN "ITEM FIND" (Boonzeet)
        # Verificamos que el plugin exista para evitar crasheos si lo desinstalas
        if defined?($item_log) && $item_log.respond_to?(:register)
          $item_log.register(item_id)
        end
        
        # Limpiamos el objeto
        state.holding_item = nil
      else
        # Si la mochila está llena
        pbMessage(_INTL("Pero tu mochila está llena..."))
      end
      
      return true
    end

    def self.decide_reaction(pkmn)
      if pkmn.hp <= (pkmn.totalhp / 4)
        return { anim: :Sad, phys: :shiver, text: "{1} parece estar a punto de desmayarse..." }
      end
      
      case pkmn.status
      when :POISON
        return { anim: :Poison, phys: :shiver, text: "{1} está tiritando a causa del veneno." }
      when :BURN
        return { anim: :Angry, phys: :step_back, text: "Parece que a {1} le duele mucho su quemadura." }
      when :PARALYSIS
        return { anim: :Ellipsis, phys: :shiver, text: "{1} está temblando y tiene sacudidas." }
      when :FROZEN
        return { anim: :Ellipsis, phys: :shiver, text: "Da la impresión de que {1} está pasando mucho frío." }
      when :SLEEP
        return { anim: :Ellipsis, phys: nil, text: "{1} parece agotado y medio dormido." }
      end

      map_meta = $game_map.metadata
      if map_meta
        if map_meta.has_flag?("GymMap") || map_meta.has_flag?("Gym")
          return { anim: :Angry, phys: :jump_happy, text: "¡{1} está concentrado y listo para pelear!" }
        elsif map_meta.has_flag?("PokeCenter")
          return { anim: :Happy, phys: :spin, text: "{1} se ve relajado por el ambiente curativo." }
        end
      end

      case $game_screen.weather_type
      when :Rain, :HeavyRain, :Thunder
        if pkmn.hasType?(:WATER) || pkmn.hasType?(:ELECTRIC)
          return { anim: :Happy, phys: :jump_happy, text: "¡{1} parece estar disfrutando de la lluvia!" }
        elsif pkmn.hasType?(:FIRE) || pkmn.hasType?(:ROCK) || pkmn.hasType?(:GROUND)
          return { anim: :Sad, phys: :shiver, text: "{1} odia mojarse y está tiritando..." }
        end
      when :Snow, :Blizzard
        if pkmn.hasType?(:ICE)
          return { anim: :Happy, phys: :spin, text: "¡{1} adora la nieve y el frío!" }
        else
          return { anim: :Ellipsis, phys: :shiver, text: "{1} se encogió debido al frío..." }
        end
      end

      if pkmn.happiness >= 220
        return { anim: :Heart, phys: :love_rub, text: "¡{1} se frota cariñosamente contra las piernas de {2}!" }
      elsif pkmn.happiness < 50
        return { anim: :Mad, phys: :step_back, text: "{1} mira hacia otro lado, ignorando a {2}..." }
      end

      generics = [
        { anim: :Music, phys: :spin, text: "{1} está tarareando una melodía feliz." },
        { anim: :Smile, phys: :jump_happy, text: "{1} te sigue alegremente." },
        { anim: :Question, phys: :look_around, text: "{1} olfatea el aire con curiosidad." },
        { anim: :Ellipsis, phys: nil, text: "{1} mira fijamente al horizonte." },
        { anim: :Happy, phys: :jump_happy, text: "¡{1} da saltitos de alegría!" }
      ]
      return generics.sample
    end
  end
end



class FollowerData
  alias vibrant_interact interact unless method_defined?(:vibrant_interact)
  def interact(event)
    if self.name && self.name.start_with?("VibrantFollower_")
      if self.name == "VibrantFollower_0"
        return unless VibrantCompanions::Settings.allow_interact?
        $game_player.lock
        VibrantCompanions::Interaction.start
        $game_player.unlock
      end
      return
    end
    vibrant_interact(event)
  end
end