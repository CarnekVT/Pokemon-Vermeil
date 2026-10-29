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
                    $game_player.moving? ||
                    $game_player.move_route_forcing
    return false if pbMapInterpreterRunning?
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

  def self.resolve_throw(event,mode,payload,cfg,back_at_release=nil)
    if !event || !eligible_event?(event)
      notice(_INTL("No hay un Pokémon salvaje capturable en la trayectoria."))
      return false
    end
    spec = event_spec(event)
    local = options($game_map.map_id,spec[0],event.id)
    geo = geometry($game_player.x,$game_player.y,event.x,event.y,local)
    blocked = local["line_of_sight"] == "1" &&
              !line_clear?($game_player.x,$game_player.y,event.x,event.y)
    if !geo[:in_range] || blocked
      notice(blocked ? _INTL("Hay un obstáculo entre ambos.") :
             _INTL("El Pokémon está fuera del alcance."))
      return false
    end
    if mode == :battle
      @pending_battle = [event,payload]
      return true
    end
    limit = local["attempt_limit"].to_i
    if limit > 0 && attempts(event) >= limit
      notice(_INTL("Este Pokémon ya no acepta más lanzamientos directos."))
      return false
    end
    unless $bag.quantity(payload).to_i > 0
      notice(_INTL("No quedan Poké Balls."))
      return false
    end
    hit = rand < hit_chance(geo[:front],local)
    if !hit
      $bag.remove(payload,1) if local["consume_on_miss"] == "1"
      notice(_INTL("¡El lanzamiento se desvió!"))
      react(event,local,:miss) if local["alert_on_miss"] == "1"
      return false
    end
    return false unless $bag.remove(payload,1)
    event.instance_variable_set(:@bifrost_attempts,attempts(event)+1)
    contact_fx(event) if respond_to?(:contact_fx)
    behind = back_at_release.nil? ?
      behind?($game_player.x,$game_player.y,event) : back_at_release
    crit_rate = behind ? local["critical_back"] : local["critical_front"]
    critical = rand < crit_rate.to_f/100.0
    probability = catch_chance(spec[0],payload,geo[:front],behind,critical,local)
    caught = rand < probability
    pkmn = nil
    if caught
      pkmn = pbGenerateWildPokemon(spec[0],spec[1])
      pkmn.form = spec[2] if spec[2] > 0
      pkmn.poke_ball = payload if pkmn.respond_to?(:poke_ball=)
      caught = !!pbAddPokemon(pkmn)
    end
    animate_catch(event,payload,caught,critical,local) if respond_to?(:animate_catch)
    if caught
      notice(critical ? _INTL("¡Captura crítica!") : _INTL("¡Pokémon capturado!"))
      remove_event(event)
      return true
    end
    notice(_INTL("¡El Pokémon se liberó!"))
    react(event,local,:breakout)
    false
  end

  def self.dispatch_battle
    request = @pending_battle
    @pending_battle = nil
    return false unless request
    event,chosen = request
    return false unless eligible_event?(event)
    spec = event_spec(event)
    wild = pbGenerateWildPokemon(spec[0],spec[1])
    wild.form = spec[2] if spec[2] > 0
    party = $player.party
    original = party.dup
    index = party.index(chosen)
    if index && index > 0
      party.delete_at(index)
      party.unshift(chosen)
    end
    begin
      outcome = WildBattle.start(wild)
      remove_event(event) if outcome
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
