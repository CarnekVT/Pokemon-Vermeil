# frozen_string_literal: true
# Three reusable temperaments: neutral curiosity, timid flight, aggressive chase.
# OW actions are rate-limited, and battles never begin underneath a live throw.
module BifrostCapture
  @fleeing = {}
  @chasing = {}
  @pending_attack = nil
  @ai_frame = 0

  def self.distance(event)
    (event.x-$game_player.x).abs+(event.y-$game_player.y).abs
  end

  def self.fleeing?(event)
    !!event.instance_variable_get(:@bifrost_flee_state)
  end

  def self.chasing?(event)
    !!event.instance_variable_get(:@bifrost_chase_state)
  end

  def self.start_flee(event,cfg)
    return false unless eligible_event?(event) && !fleeing?(event)
    stop_chase(event) if chasing?(event)
    state = {
      :steps=>0, :blocked=>0,
      :original_speed=>event.move_speed,
      :original_type=>event.instance_variable_get(:@move_type)
    }
    event.instance_variable_set(:@bifrost_flee_state,state)
    event.instance_variable_set(:@bifrost_mood_state,:flee)
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
    event.instance_variable_set(:@bifrost_mood_state,nil)
    (@fleeing || {}).delete(event.object_id)
  end

  def self.finish_escape(event)
    restore_wander(event)
    if generated?(event)
      erase_wild(event)
    else
      event.erase
    end
    notice(_INTL("¡El Pokémon escapó!"))
    BifrostCapture::Audio.play(:flee) if defined?(BifrostCapture::Audio)
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

  def self.start_chase(event,cfg)
    return false unless eligible_event?(event)
    return false if fleeing?(event) || chasing?(event)
    # First notice the player, face them, then pursue in short bursts.
    # A nearby wild Pokémon should not accelerate like a projectile.
    state = {
      :original_speed=>event.move_speed,
      :original_type=>event.instance_variable_get(:@move_type),
      :stuck=>0, :phase=>:notice,
      :notice=>cfg["aggressive_notice_frames"].to_i.clamp(0,90),
      :rest=>0, :attack=>0
    }
    event.instance_variable_set(:@bifrost_chase_state,state)
    event.instance_variable_set(:@bifrost_mood_state,:alert)
    event.instance_variable_set(:@move_type,0)
    event.move_speed = cfg["aggressive_chase_speed"].to_i.clamp(1,6)
    event.turn_toward_player if event.respond_to?(:turn_toward_player)
    @chasing ||= {}
    @chasing[event.object_id] = event
    BifrostCapture::Audio.play(:alert,cfg) if defined?(BifrostCapture::Audio)
    true
  end

  def self.stop_chase(event)
    state = event.instance_variable_get(:@bifrost_chase_state)
    return unless state
    event.move_speed = state[:original_speed]
    event.instance_variable_set(:@move_type,state[:original_type])
    event.remove_instance_variable(:@bifrost_chase_state)
    event.instance_variable_set(:@bifrost_mood_state,nil)
    (@chasing || {}).delete(event.object_id)
  end

  def self.schedule_attack(event)
    return false if @pending_attack
    @pending_attack = event
    @aim_interrupted = true if @aim_open
    true
  end

  def self.chase_tick(event,cfg)
    return unless chasing?(event)
    return if event.instance_variable_get(:@bifrost_capture_lock) ||
              event.instance_variable_get(:@bifrost_projectile_lock)
    state = event.instance_variable_get(:@bifrost_chase_state)
    return unless state
    dist = distance(event)
    alert_dist = cfg["aggressive_alert_distance"].to_i.clamp(1,20)
    if dist > alert_dist+3
      stop_chase(event)
      event.instance_variable_set(:@bifrost_alert_cooldown,90)
      return
    end
    if state[:phase] == :notice
      state[:notice] -= 1
      return if state[:notice] > 0
      state[:phase] = :chase
      event.instance_variable_set(:@bifrost_mood_state,:chase)
    end
    if dist <= cfg["aggressive_attack_distance"].to_i.clamp(1,6)
      event.instance_variable_set(:@bifrost_mood_state,:threat)
      event.turn_toward_player if event.respond_to?(:turn_toward_player) &&
                                  !event.moving?
      state[:attack] += 1
      if state[:attack] >=
         cfg["aggressive_attack_windup"].to_i.clamp(0,90) &&
         !event.moving?
        stop_chase(event)
        schedule_attack(event)
      end
      return
    end
    state[:attack] = 0
    event.instance_variable_set(:@bifrost_mood_state,:chase)
    return if event.moving? || event.move_route_forcing
    state[:rest] -= 1 if state[:rest] > 0
    return if state[:rest] > 0
    before = [event.x,event.y]
    event.move_toward_player if event.respond_to?(:move_toward_player)
    # Keep a small breathing interval after each discrete tile movement.
    state[:rest] = cfg["aggressive_step_pause"].to_i.clamp(0,60)
    if before == [event.x,event.y]
      state[:stuck] += 1
      if state[:stuck] >= 45
        stop_chase(event)
        event.instance_variable_set(:@bifrost_alert_cooldown,120)
      end
    else
      state[:stuck] = 0
    end
  end

  def self.react(event,cfg,reason=:proximity)
    return false unless eligible_event?(event)
    return false if event.instance_variable_get(:@bifrost_capture_lock)
    return false if fleeing?(event)
    temperament = temperament_for(event,cfg)
    case temperament
    when :timid
      start_flee(event,cfg)
    when :aggressive
      start_chase(event,cfg)
    else
      # A neutral creature notices the player but stays in the area.
      # A close miss can make it retreat one tile without fleeing the map.
      event.turn_toward_player if event.respond_to?(:turn_toward_player)
      if [:miss,:breakout].include?(reason) && !event.moving? &&
         event.respond_to?(:move_away_from_player)
        event.move_away_from_player
      end
      event.instance_variable_set(:@bifrost_mood_state,:curious)
      event.instance_variable_set(:@bifrost_alert_cooldown,120)
      true
    end
  end

  def self.battle_wild_for(event)
    spec = event_spec(event)
    return nil unless spec
    wild = pbGenerateWildPokemon(spec[0],spec[1])
    wild.form = spec[2] if spec[2] > 0
    cfg = options($game_map.map_id,spec[0],event.id)
    if temperament_for(event,cfg) == :aggressive && wild.respond_to?(:level=)
      extra = cfg["aggressive_level_bonus"].to_i.clamp(0,20)
      wild.level = [wild.level.to_i + extra,100].min if extra > 0
      wild.calc_stats if extra > 0 && wild.respond_to?(:calc_stats)
    end
    wild
  end

  def self.dispatch_attack
    event = @pending_attack
    @pending_attack = nil
    @aim_interrupted = false
    return false unless event && eligible_event?(event)
    wild = battle_wild_for(event)
    return false unless wild
    BifrostCapture::Feedback.reset if defined?(BifrostCapture::Feedback)
    result = WildBattle.start(wild)
    remove_event(event) if result
    true
  end

  def self.update_behavior
    # Other wild Pokémon keep moving while a Ball is in the air. Per-event
    # capture/projectile locks prevent simultaneous interactions on one target.
    return if !$game_map || !$game_player || !$player
    return if !defined?($scene) || !$scene.is_a?(Scene_Map)
    return if $game_temp.in_menu || $game_temp.in_battle ||
              $game_temp.message_window_showing
    @ai_frame = (@ai_frame || 0) + 1
    (@fleeing || {}).values.dup.each do |event|
      if !eligible_event?(event) || !$game_map.events[event.id].equal?(event)
        (@fleeing || {}).delete(event.object_id)
        next
      end
      spec = event_spec(event)
      flee_tick(event,options($game_map.map_id,spec[0],event.id))
    end
    (@chasing || {}).values.dup.each do |event|
      if !eligible_event?(event) || !$game_map.events[event.id].equal?(event)
        (@chasing || {}).delete(event.object_id)
        next
      end
      spec = event_spec(event)
      chase_tick(event,options($game_map.map_id,spec[0],event.id))
    end
    # The aggro encounter is delayed until the aiming interface closes.
    if @pending_attack && !@aim_open &&
       !(defined?(Motion) && Motion.busy?)
      dispatch_attack
      return
    end
    return unless @ai_frame % 12 == 0
    $game_map.events.values.each do |event|
      next unless eligible_event?(event)
      next if respond_to?(:emerging?) && emerging?(event)
      next if fleeing?(event) || chasing?(event) ||
              event.instance_variable_get(:@bifrost_capture_lock)
      cd = event.instance_variable_get(:@bifrost_alert_cooldown).to_i
      if cd > 0
        event.instance_variable_set(:@bifrost_alert_cooldown,[cd-12,0].max)
        if cd <= 12
          event.instance_variable_set(:@bifrost_mood_state,nil)
        end
        next
      end
      spec = event_spec(event)
      cfg = options($game_map.map_id,spec[0],event.id)
      temperament = temperament_for(event,cfg)
      distance_limit = case temperament
      when :timid then cfg["timid_alert_distance"].to_i
      when :aggressive then cfg["aggressive_alert_distance"].to_i
      else cfg["alert_distance"].to_i
      end
      next if distance_limit <= 0 || distance(event) > distance_limit
      react(event,cfg,:proximity)
    end
  end

  def self.reset_behavior
    (@fleeing || {}).values.dup.each { |event| restore_wander(event) }
    (@chasing || {}).values.dup.each { |event| stop_chase(event) }
    @fleeing = {}
    @chasing = {}
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
