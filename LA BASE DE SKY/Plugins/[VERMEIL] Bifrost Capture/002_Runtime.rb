# frozen_string_literal: true
# Bifrost Capture - inventory, real resolution, storage. No UI or event spawn.
module BifrostCapture
  @aim_open = false
  @pending_battle = nil

  def self.ball_choices
    out = []
    return out unless $bag
    $bag.pockets.each do |pocket|
      pocket.each do |entry|
        next unless entry && entry[1].to_i > 0
        data = GameData::Item.try_get(entry[0])
        out << [entry[0],entry[1]] if data && data.is_poke_ball?
      end
    end
    out
  end

  # Natural berries, plus Honey as an overworld lure; no invented items.
  def self.bait_item?(item)
    data = GameData::Item.try_get(item)
    return false unless data
    return true if data.respond_to?(:is_berry?) && data.is_berry?
    item.to_s.upcase == "HONEY"
  end

  def self.bait_choices
    return [] unless $bag
    choices = []
    $bag.pockets.each do |pocket|
      pocket.each do |entry|
        next unless entry && entry[1].to_i > 0
        choices << [entry[0],entry[1]] if bait_item?(entry[0])
      end
    end
    choices
  end

  def self.resolve_bait(event,item,cfg)
    return false unless eligible_event?(event)
    spec = event_spec(event)
    local = options($game_map.map_id,spec[0],event.id)
    return false unless defined?(Pressure)
    Pressure.calm_with_bait(event,item,local)
  end

  def self.aim_allowed?
    cfg = options
    return false unless cfg["enabled"] == "1"
    return false if cfg["capture_enabled"] != "1" && cfg["battle_enabled"] != "1"
    return false unless $player && $game_player && $game_map
    return false unless defined?($scene) && $scene.is_a?(Scene_Map)
    return false if $game_temp.in_menu || $game_temp.in_battle ||
                    $game_temp.message_window_showing ||
                    $game_temp.player_transferring ||
                    $game_temp.transition_processing ||
                    $game_player.move_route_forcing
    return false if pbMapInterpreterRunning? && cfg["access_mode"] != "event"
    true
  end

  def self.catch_chance(species,ball,distance,back,critical,cfg)
    rate = GameData::Species.get(species).catch_rate.to_f
    bonus = {
      :MASTERBALL=>1000.0, :ULTRABALL=>2.0, :GREATBALL=>1.5,
      :NETBALL=>1.5, :DUSKBALL=>1.5, :QUICKBALL=>1.5,
      :BEASTBALL=>0.1
    }[ball] || 1.0
    optimal = [cfg["optimal_range"].to_i,1].max
    limit = [cfg["range"].to_i,optimal].max
    dist_bonus = distance <= optimal ? (1.0+(optimal-distance)*0.15) :
      (1.0-(distance-optimal)*0.5/[limit-optimal,1].max)
    base = [rate/765.0, cfg["capture_floor"].to_f/100.0].max
    back_mult = back ? cfg["back_multiplier"].to_f/100.0 : 1.0
    crit_mult = critical ? cfg["critical_multiplier"].to_f/100.0 : 1.0
    instant = cfg["instant_modifier"].to_f/100.0
    (base*bonus*dist_bonus*back_mult*crit_mult*instant).clamp(0.0,1.0)
  end

  def self.attempts(event)
    event.instance_variable_get(:@bifrost_attempts).to_i
  end

  def self.eligible_event?(event)
    valid_target?(event) && !removed?(event)
  end

  # Non-modal storage. Avoid pbAddPokemon's blocking text boxes during capture.
  # Fallback retains compatibility with games using a custom storage pipeline.
  def self.store_captured_pokemon(pokemon)
    if $player && $player.respond_to?(:party_full?) &&
       $player.respond_to?(:party)
      if $player.party_full?
        if defined?($PokemonStorage) && $PokemonStorage &&
           $PokemonStorage.respond_to?(:pbStoreCaught)
          index = $PokemonStorage.pbStoreCaught(pokemon)
          return [false,nil] if !index || index < 0
          box = begin $PokemonStorage[index].name rescue _INTL("una caja") end
          location = _INTL("Enviado a {1}".dup, box)
        else
          return [false,nil]
        end
      else
        $player.party << pokemon
        location = _INTL("Añadido al equipo")
      end
      if $player.respond_to?(:pokedex) && $player.pokedex
        $player.pokedex.register(pokemon) if $player.pokedex.respond_to?(:register)
        $player.pokedex.set_owned(pokemon.species) if
          $player.pokedex.respond_to?(:set_owned)
      end
      return [true,location]
    end
    # Test harness and projects without the standard storage interface.
    return [!!pbAddPokemon(pokemon),_INTL("Captura registrada")]
  end

  def self.capture_result(kind,species=nil,detail=nil,cfg=nil)
    if defined?(BifrostCapture::Feedback)
      BifrostCapture::Feedback.publish(kind,species,detail,cfg)
    end
  end

  def self.resolve_throw(event,mode,payload,cfg,back_at_release=nil,hit_roll=nil,origin=nil,critical_override=nil)
    if !event || !eligible_event?(event)
      notice(_INTL("No hay un Pokémon salvaje capturable en la trayectoria."))
      capture_result(:blocked,nil,_INTL("Acércate a un Pokémon visible."),cfg)
      return false
    end
    spec = event_spec(event)
    local = options($game_map.map_id,spec[0],event.id)
    px,py = origin || [$game_player.x,$game_player.y]
    geo = geometry(px,py,event.x,event.y,local)
    blocked = local["line_of_sight"] == "1" &&
              !line_clear?(px,py,event.x,event.y)
    if !geo[:in_range] || blocked
      reason = blocked ? _INTL("Trayectoria bloqueada") :
              _INTL("Fuera de alcance")
      notice(reason)
      capture_result(:blocked,spec[0],reason,local)
      return false
    end
    if mode == :battle
      @pending_battle = [event,payload]
      return true
    end
    if defined?(Pressure) && Pressure.locked?(event,local)
      capture_result(:blocked,spec[0],_INTL("Demasiado alerta: entra en combate"),local)
      return false
    end
    limit = local["attempt_limit"].to_i
    if limit > 0 && attempts(event) >= limit
      notice(_INTL("Este Pokémon ya no acepta más lanzamientos directos."))
      capture_result(:blocked,spec[0],_INTL("Resiste la captura directa"),local)
      return false
    end
    unless $bag.quantity(payload).to_i > 0
      notice(_INTL("No quedan Poké Balls."))
      return false
    end
    hit = (hit_roll.nil? ? rand : hit_roll) < hit_chance(geo[:front],local)
    if !hit
      $bag.remove(payload,1) if local["consume_on_miss"] == "1"
      notice(_INTL("¡El lanzamiento se desvió!"))
      capture_result(:miss,spec[0],_INTL("La Ball no acertó"),local)
      Pressure.add(event,:miss,local) if defined?(Pressure)
      react(event,local,:miss) if local["alert_on_miss"] == "1"
      return false
    end
    return false unless $bag.remove(payload,1)
    event.instance_variable_set(:@bifrost_attempts,attempts(event)+1)
    contact_fx(event) if respond_to?(:contact_fx)
    behind = back_at_release.nil? ?
      behind?($game_player.x,$game_player.y,event) : back_at_release
    crit_rate = behind ? local["critical_back"] : local["critical_front"]
    critical = critical_override.nil? ? rand < crit_rate.to_f/100.0 : critical_override
    probability = catch_chance(spec[0],payload,geo[:front],behind,critical,local)
    probability *= Pressure.capture_modifier(event,local) if defined?(Pressure)
    caught = rand < probability
    Pressure.add(event,behind ? :back : :front,local) if !caught && defined?(Pressure)
    destination = nil
    if caught
      pkmn = ow_pokemon_for(event,local)
      return false unless pkmn
      pkmn.poke_ball = payload if pkmn.respond_to?(:poke_ball=)
      caught,destination = store_captured_pokemon(pkmn)
    end
    # The result is stored, but the OW remains locked/visible to the capture
    # state machine until its animation finishes. This never blocks Scene_Map.
    if defined?(Motion) && Motion.respond_to?(:start_capture)
      if Motion.start_capture(event,payload,caught,critical,local,
                              spec[0],destination)
        return caught
      end
    end
    # Compatibility path for headless tests / reduced runtimes without sprites.
    finish_capture_result(event,caught,critical,spec[0],destination,local)
    caught
  end

  def self.finish_capture_result(event,caught,critical,species,destination,cfg)
    if caught
      Pressure.clear_success(event) if defined?(Pressure)
      remove_event(event)
      notice(critical ? _INTL("¡Captura crítica!") : _INTL("¡Capturado!"))
      capture_result(critical ? :critical : :caught,species,destination,cfg)
      BifrostCapture::Audio.play(:caught,cfg) if defined?(BifrostCapture::Audio)
    else
      notice(_INTL("¡El Pokémon se liberó!"))
      capture_result(:breakout,species,_INTL("¡Sigue libre!"),cfg)
      Pressure.add(event,:breakout,cfg) if defined?(Pressure)
      BifrostCapture::Audio.play(:breakout,cfg) if defined?(BifrostCapture::Audio)
      angry = respond_to?(:trigger_escape_reaction) &&
              trigger_escape_reaction(event,cfg)
      react(event,cfg,:breakout) unless angry
    end
  end

  def self.dispatch_battle
    request = @pending_battle
    @pending_battle = nil
    return false unless request
    event,chosen = request
    return false unless eligible_event?(event)
    wild = battle_wild_for(event)
    return false unless wild
    party = $player.party
    original = party.dup
    index = party.index(chosen)
    if index && index > 0
      party.delete_at(index)
      party.unshift(chosen)
    end
    begin
      BifrostCapture::Feedback.reset if defined?(BifrostCapture::Feedback)
      outcome = WildBattle.start(wild)
      if outcome
        Pressure.clear_success(event) if defined?(Pressure)
        remove_event(event)
      end
    ensure
      party.replace(original.select { |p| party.include?(p) } +
                    party.reject { |p| original.include?(p) })
    end
    true
  end

  def self.throw_at(tx,ty,_forward,_side,mode,item,cfg)
    event = $game_map.events.values.find { |e|
      e.x==tx && e.y==ty && eligible_event?(e)
    }
    resolve_throw(event,mode,item,cfg)
  end

  def self.set_rule(key,value)
    return false unless DEFAULTS.key?(key) && $PokemonGlobal
    $PokemonGlobal.bifrost_overrides ||= {}
    $PokemonGlobal.bifrost_overrides[key] = value.to_s
    true
  end

  def self.reset_rules
    $PokemonGlobal.bifrost_overrides = {} if $PokemonGlobal
  end
end

def pbBifrostAim
  BifrostCapture.aim
end

EventHandlers.add(:on_frame_update,:bifrost_aim_button,
  proc { BifrostCapture.update_input }
)
