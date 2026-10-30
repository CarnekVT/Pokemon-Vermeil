# frozen_string_literal: true
# Bifrost Capture - independent, throttled OW AI. No instant deletion on flee.
module BifrostCapture
  @fleeing = {}
  @pending_attack = nil
  @ai_frame = 0

  def self.distance(event)
    (event.x-$game_player.x).abs+(event.y-$game_player.y).abs
  end

  def self.fleeing?(event)
    !!event.instance_variable_get(:@bifrost_flee_state)
  end

  def self.start_flee(event,cfg)
    return false unless eligible_event?(event)
    return false if fleeing?(event)
    state = {
      :steps=>0, :blocked=>0,
      :original_speed=>event.move_speed,
      :original_type=>event.instance_variable_get(:@move_type)
    }
    event.instance_variable_set(:@bifrost_flee_state,state)
    event.instance_variable_set(:@move_type,0)
    event.move_speed = cfg["flee_speed"].to_i.clamp(1,6)
    @fleeing ||= {}
    @fleeing[event.object_id] = event
    notice(_INTL("¡El Pokémon está huyendo!"))
    true
  end

  def self.restore_wander(event)
    state = event.instance_variable_get(:@bifrost_flee_state)
    return unless state
    event.move_speed = state[:original_speed]
    event.instance_variable_set(:@move_type,state[:original_type])
    event.remove_instance_variable(:@bifrost_flee_state)
    (@fleeing || {}).delete(event.object_id)
  end

  def self.finish_escape(event)
    restore_wander(event)
    # Escaping is NOT catching. Never persist a captured flag for a roamer.
    if generated?(event)
      erase_wild(event)
    else
      event.erase
    end
    notice(_INTL("¡El Pokémon escapó!"))
    if defined?(BifrostCapture::Feedback)
      species = event_spec(event)
      BifrostCapture::Feedback.publish(:escape,
        species && species[0],_INTL("Se alejó de la zona"))
    end
  end

  def self.flee_tick(event,cfg)
    return unless fleeing?(event)
    return if event.instance_variable_get(:@bifrost_capture_lock)
    state = event.instance_variable_get(:@bifrost_flee_state)
    return if event.moving? || event.move_route_forcing
    steps = cfg["flee_steps"].to_i.clamp(1,30)
    dist = cfg["flee_disappear_distance"].to_i.clamp(4,30)
    if state[:steps] >= steps || distance(event) >= dist
      finish_escape(event)
      return
    end
    oldx,oldy = event.x,event.y
    event.move_away_from_player
    if event.x != oldx || event.y != oldy
      state[:steps] += 1
      state[:blocked] = 0
    else
      state[:blocked] += 1
      if state[:blocked] >= cfg["flee_stuck_frames"].to_i.clamp(15,600)
        restore_wander(event)
        event.instance_variable_set(:@bifrost_alert_cooldown,120)
      end
    end
  end

  def self.react(event,cfg,reason=:proximity)
    return false unless eligible_event?(event)
    return false if event.instance_variable_get(:@bifrost_capture_lock)
    return false if fleeing?(event)
    case cfg["reaction"]
    when "flee"
      start_flee(event,cfg)
    when "attack"
      event.instance_variable_set(:@bifrost_alert_cooldown,180)
      @pending_attack ||= event
      @aim_interrupted = true if @aim_open
      # Do not launch battles inside the projectile or UI update.
      true
    else
      false
    end
  end

  def self.dispatch_attack
    event = @pending_attack
    @pending_attack = nil
    @aim_interrupted = false
    return false unless event && eligible_event?(event)
    spec = event_spec(event)
    wild = pbGenerateWildPokemon(spec[0],spec[1])
    wild.form = spec[2] if spec[2] > 0
    result = WildBattle.start(wild)
    remove_event(event) if result
    true
  end

  def self.update_behavior
    return if @capture_busy
    return if !$game_map || !$game_player || !$player
    return if !defined?($scene) || !$scene.is_a?(Scene_Map)
    return if $game_temp.in_menu || $game_temp.in_battle ||
              $game_temp.message_window_showing
    @ai_frame = (@ai_frame || 0)+1
    (@fleeing || {}).values.dup.each do |event|
      if !eligible_event?(event) || !$game_map.events[event.id].equal?(event)
        (@fleeing || {}).delete(event.object_id)
        next
      end
      spec = event_spec(event)
      flee_tick(event,options($game_map.map_id,spec[0],event.id))
    end
    # Calm Pokémon only checked ~5x per second, avoiding 2.5D frame drops.
    return unless @ai_frame % 12 == 0
    $game_map.events.values.each do |event|
      next unless eligible_event?(event)
      next if fleeing?(event) || event.instance_variable_get(:@bifrost_capture_lock)
      cooldown = event.instance_variable_get(:@bifrost_alert_cooldown).to_i
      if cooldown > 0
        event.instance_variable_set(:@bifrost_alert_cooldown,
                                    [cooldown-12,0].max)
        next
      end
      spec = event_spec(event)
      cfg = options($game_map.map_id,spec[0],event.id)
      radius = cfg["alert_distance"].to_i
      next unless radius > 0 && distance(event) <= radius
      react(event,cfg,:proximity)
    end
    if @pending_attack && !@aim_open && !$game_temp.in_battle
      dispatch_attack
    end
  end

  def self.reset_behavior
    (@fleeing || {}).values.each { |event| restore_wander(event) }
    @fleeing = {}
    @pending_attack = nil
    @aim_interrupted = false
    @ai_frame = 0
  end
end

EventHandlers.add(:on_frame_update,:bifrost_ow_ai,
  proc { BifrostCapture.update_behavior }
)
EventHandlers.add(:on_enter_map,:bifrost_ow_ai_reset,
  proc { |_old| BifrostCapture.reset_behavior }
)
