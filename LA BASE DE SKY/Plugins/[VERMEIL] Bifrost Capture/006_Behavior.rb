# frozen_string_literal: true
# Bifrost OW behavior: reactions live on Game_Event instances, not UI overlays.
# Fleeing is MOVEMENT before disappearance. No instant erase in react(:flee).
module BifrostCapture
  @behavior_frame = 0
  @pending_attack = nil

  def self.alert_distance(event)
    spec = event_spec(event)
    return 0 unless spec
    options($game_map.map_id, spec[0], event.id)["alert_distance"].to_i
  end

  def self.distance_to_player(event)
    (event.x-$game_player.x).abs + (event.y-$game_player.y).abs
  end

  def self.fleeing?(event)
    event && event.instance_variable_get(:@bifrost_flee_state).is_a?(Hash)
  end

  def self.begin_flee(event, cfg)
    return false if !event || fleeing?(event) || !valid_target?(event)
    state = {
      steps: 0, elapsed: 0, stuck: 0,
      move_type: event.instance_variable_get(:@move_type),
      speed: event.move_speed
    }
    event.instance_variable_set(:@bifrost_flee_state, state)
    @fleeing_events ||= {}
    @fleeing_events[event.object_id] = event
    event.instance_variable_set(:@move_type, 0) # Stop random routes while fleeing.
    event.move_speed = cfg["flee_speed"].to_i.clamp(1, 6)
    notice(_INTL("¡El Pokémon intenta escapar!"))
    true
  end

  def self.restore_wander(event, state)
    event.instance_variable_set(:@move_type, state[:move_type]) if state
    event.move_speed = state[:speed] if state && state[:speed]
    event.remove_instance_variable(:@bifrost_flee_state) if
      event.instance_variable_defined?(:@bifrost_flee_state)
  end

  def self.finish_flee(event, cfg)
    state = event.instance_variable_get(:@bifrost_flee_state)
    return unless state
    restore_wander(event, state)
    @fleeing_events.delete(event.object_id) if @fleeing_events
    notice(_INTL("¡El Pokémon escapó!"))
    # Huir NO es ser capturado: no guardar la bandera persistente de captura.
    # Un errante puede reaparecer en otra visita o al reactivarse su evento.
    if generated?(event)
      discard_generated(event)
    else
      event.erase
    end
  end

  def self.tick_flee(event, cfg)
    state = event.instance_variable_get(:@bifrost_flee_state)
    return unless state
    state[:elapsed] += 1
    steps = cfg["flee_steps"].to_i.clamp(1, 30)
    distance = cfg["flee_disappear_distance"].to_i.clamp(4, 30)
    if state[:steps] >= steps || distance_to_player(event) >= distance
      finish_flee(event, cfg) unless event.moving?
      return
    end
    if !event.moving? && !event.move_route_forcing
      ox, oy = event.x, event.y
      event.move_away_from_player
      if event.x != ox || event.y != oy
        state[:steps] += 1
        state[:stuck] = 0
      else
        state[:stuck] += 1
      end
    end
    if state[:stuck] >= cfg["flee_stuck_frames"].to_i.clamp(15, 600)
      # Never teleport or erase an OW that is physically trapped.
      restore_wander(event, state)
      @fleeing_events.delete(event.object_id) if @fleeing_events
      event.instance_variable_set(:@bifrost_alert_cooldown, 90)
    end
  end

  def self.perform_attack(event)
    return false unless event && valid_target?(event)
    spec = event_spec(event)
    wild = pbGenerateWildPokemon(spec[0], spec[1])
    wild.form = spec[2] if spec[2] > 0
    notice(_INTL("¡El Pokémon te desafía!"))
    result = WildBattle.start(wild)
    remove_event(event) if result
    true
  end

  def self.react(event, cfg, reason = :proximity)
    return false if !event || !valid_target?(event)
    return false if fleeing?(event)
    case cfg["reaction"]
    when "flee"
      begin_flee(event, cfg)
    when "attack"
      event.instance_variable_set(:@bifrost_alert_cooldown, 180)
      if @aim_running || @aim_opening
        @pending_attack ||= event
        @aim_interrupted = true
      else
        perform_attack(event)
      end
      true
    when "ignore"
      false
    else
      false
    end
  end

  def self.aim_interrupted?
    @aim_interrupted == true
  end

  def self.perform_pending_attack
    @aim_interrupted = false
    target = @pending_attack
    @pending_attack = nil
    perform_attack(target) if target
  end

  def self.perform_pending_send
    pending = @pending_send
    @pending_send = nil
    return false unless pending
    event, payload = pending
    return false unless valid_target?(event)
    spec = event_spec(event)
    wild = pbGenerateWildPokemon(spec[0],spec[1])
    wild.form = spec[2] if spec[2] > 0
    party = $player.party
    original = party.dup
    index = party.index(payload)
    if index && index > 0
      party.delete_at(index)
      party.unshift(payload)
    end
    begin
      result = WildBattle.start(wild)
      remove_event(event) if result
    ensure
      party.replace(original.select { |p| party.include?(p) } +
                    party.reject { |p| original.include?(p) })
    end
    true
  end

  def self.update_behavior(force = false)
    return if !defined?($scene) || !$scene.is_a?(Scene_Map)
    return if !$game_map || !$game_player || !$player
    return if $game_temp && ($game_temp.in_battle || $game_temp.in_menu ||
                              $game_temp.message_window_showing)
    @behavior_frame = (@behavior_frame || 0) + 1
    # Per-frame solo se actualizan las criaturas que REALMENTE están huyendo.
    # Los OW en reposo se revisan cada 12 fotogramas o al caminar el jugador.
    (@fleeing_events || {}).values.dup.each do |event|
      if !valid_target?(event) || !$game_map.events[event.id].equal?(event)
        @fleeing_events.delete(event.object_id)
        next
      end
      spec = event_spec(event)
      tick_flee(event, options($game_map.map_id, spec[0], event.id))
    end
    return unless force || @behavior_frame % 12 == 0
    $game_map.events.values.each do |event|
      next if event.instance_variable_get(:@bifrost_capture_locked)
      next unless valid_target?(event) && !fleeing?(event)
      cooldown = event.instance_variable_get(:@bifrost_alert_cooldown).to_i
      if cooldown > 0
        event.instance_variable_set(:@bifrost_alert_cooldown, [0,cooldown-12].max)
        next
      end
      spec = event_spec(event)
      cfg = options($game_map.map_id, spec[0], event.id)
      radius = cfg["alert_distance"].to_i
      next if radius <= 0 || distance_to_player(event) > radius
      next if @pending_attack.equal?(event)
      react(event, cfg, :proximity)
    end
  end

  def self.clear_behavior
    (@fleeing_events || {}).values.each do |event|
      state = event.instance_variable_get(:@bifrost_flee_state)
      restore_wander(event, state) if state
    end
    @fleeing_events = {}
    @behavior_frame = 0
    @pending_attack = nil
    @pending_send = nil
    @aim_interrupted = false
  end
end

EventHandlers.add(:on_frame_update, :bifrost_ow_behavior,
  proc { BifrostCapture.update_behavior }
)
EventHandlers.add(:on_enter_map, :bifrost_behavior_map_reset,
  proc { |_old_map_id| BifrostCapture.clear_behavior }
)
