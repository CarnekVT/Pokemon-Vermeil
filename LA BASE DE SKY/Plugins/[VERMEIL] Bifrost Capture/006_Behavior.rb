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
      :original_type=>event.instance_variable_get(:@move_type),
      :windup=>cfg["timid_reaction_frames"].to_i.clamp(0,120)
    }
    event.instance_variable_set(:@bifrost_flee_state,state)
    event.instance_variable_set(:@bifrost_mood_state,:flee)
    event.instance_variable_set(:@move_type,0)
    event.move_speed = cfg["flee_speed"].to_i.clamp(1,6)
    @fleeing ||= {}
    @fleeing[event.object_id] = event
    event.turn_toward_player if event.respond_to?(:turn_toward_player)
    event.jump(0,0) if event.respond_to?(:jump) &&
      (!event.respond_to?(:jumping?) || !event.jumping?)
    notice(_INTL("¡El Pokémon se asustó!"))
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
    if state[:windup].to_i > 0
      state[:windup] -= 1
      return
    end
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
      :rest=>0, :attack=>0, :charge_steps=>0
    }
    event.instance_variable_set(:@bifrost_chase_state,state)
    event.instance_variable_set(:@bifrost_mood_state,:alert)
    event.instance_variable_set(:@move_type,0)
    event.move_speed = cfg["aggressive_chase_speed"].to_i.clamp(5,6)
    event.turn_toward_player if event.respond_to?(:turn_toward_player)
    event.jump(0,0) if event.respond_to?(:jump) &&
      (!event.respond_to?(:jumping?) || !event.jumping?)
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
      Pressure.on_escape(event,cfg) if defined?(Pressure)
      stop_chase(event)
      event.instance_variable_set(:@bifrost_alert_cooldown,90)
      return
    end
    if state[:phase] == :notice
      state[:notice] -= 1
      return if state[:notice] > 0
      state[:phase] = :watch
      event.instance_variable_set(:@bifrost_mood_state,:alert)
    end
    # The outer sensing radius only warns. Actual pursuit starts within
    # a separate inner radius, after the preparation completes.
    if state[:phase] == :watch
      event.turn_toward_player if event.respond_to?(:turn_toward_player) &&
                                  !event.moving?
      return if dist > cfg["aggressive_lunge_distance"].to_i.clamp(1,20)
      state[:phase] = :charge
      state[:charge_steps] = cfg["aggressive_charge_steps"].to_i.clamp(1,5)
      state[:rest] = 0
      event.move_speed = cfg["aggressive_lunge_speed"].to_i.clamp(5,6)
      event.instance_variable_set(:@bifrost_mood_state,:charge)
      event.jump(0,0) if event.respond_to?(:jump) &&
        (!event.respond_to?(:jumping?) || !event.jumping?)
      BifrostCapture::Audio.play(:alert,cfg) if defined?(BifrostCapture::Audio)
    end
    if dist <= cfg["aggressive_attack_distance"].to_i.clamp(1,6)
      event.instance_variable_set(:@bifrost_mood_state,:threat)
      event.turn_toward_player if event.respond_to?(:turn_toward_player) &&
                                  !event.moving?
      unless state[:threat_jump]
        event.jump(0,0) if event.respond_to?(:jump) &&
          (!event.respond_to?(:jumping?) || !event.jumping?)
        state[:threat_jump] = true
      end
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
    state[:threat_jump] = false
    event.instance_variable_set(:@bifrost_mood_state,
      state[:phase] == :charge ? :charge : :chase)
    return if event.moving? || event.move_route_forcing
    state[:rest] -= 1 if state[:rest] > 0
    return if state[:rest] > 0
    before = [event.x,event.y]
    event.move_toward_player if event.respond_to?(:move_toward_player)
    # Keep a small breathing interval after each discrete tile movement.
    state[:rest] = state[:phase] == :charge ? 0 :
      cfg["aggressive_step_pause"].to_i.clamp(0,60)
    if before == [event.x,event.y]
      state[:stuck] += 1
      if state[:stuck] >= 45
        stop_chase(event)
        event.instance_variable_set(:@bifrost_alert_cooldown,120)
      end
    else
      state[:stuck] = 0
      if state[:phase] == :charge
        state[:charge_steps] -= 1
        if state[:charge_steps] <= 0
          state[:phase] = :chase
          event.move_speed = cfg["aggressive_chase_speed"].to_i.clamp(5,6)
          event.instance_variable_set(:@bifrost_mood_state,:chase)
        end
      end
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

  # Optional escape backlash: the player can retreat before the tell ends.
  # Apply modest, non-fainting HP pressure to the first available party member.
  def self.trigger_escape_reaction(event,cfg)
    return false unless cfg["escape_reaction_enabled"] == "1"
    return false unless eligible_event?(event)
    return false if @escape_reaction_recovery.to_i > 0
    return false if rand(100) >= cfg["escape_reaction_chance"].to_i.clamp(0,100)
    return false if event.instance_variable_get(:@bifrost_escape_reaction)
    state = {
      :frames=>cfg["escape_reaction_windup"].to_i.clamp(8,120),
      :range=>cfg["escape_reaction_range"].to_i.clamp(1,12),
      :hp=>cfg["escape_reaction_hp_percent"].to_i.clamp(0,30),
      :recovery=>cfg["escape_reaction_recovery"].to_i.clamp(0,600),
      :previous=>event.instance_variable_get(:@bifrost_mood_state),
      :lunged=>false
    }
    stop_chase(event) if chasing?(event)
    event.turn_toward_player if event.respond_to?(:turn_toward_player)
    event.instance_variable_set(:@bifrost_escape_reaction,state)
    event.instance_variable_set(:@bifrost_mood_state,:threat)
    event.jump(0,0) if event.respond_to?(:jump) &&
      (!event.respond_to?(:jumping?) || !event.jumping?)
    @escape_reactions ||= {}
    @escape_reactions[event.object_id] = event
    notice(_INTL("¡El Pokémon se enfadó! Aléjate de su alcance."))
    BifrostCapture::Audio.play(:alert,cfg) if defined?(BifrostCapture::Audio)
    true
  end

  def self.cancel_escape_reaction(event)
    return unless event
    state = event.instance_variable_get(:@bifrost_escape_reaction)
    return unless state
    event.remove_instance_variable(:@bifrost_escape_reaction)
    event.instance_variable_set(:@bifrost_mood_state,nil)
    event.instance_variable_set(:@bifrost_alert_cooldown,90)
    (@escape_reactions || {}).delete(event.object_id)
  end

  def self.update_escape_reactions
    @escape_reaction_recovery = [@escape_reaction_recovery.to_i-1,0].max
    (@escape_reactions || {}).values.dup.each do |event|
      state = event.instance_variable_get(:@bifrost_escape_reaction)
      unless state && eligible_event?(event) &&
             $game_map.events[event.id].equal?(event)
        cancel_escape_reaction(event)
        next
      end
      # A new capture attempt interrupts the telegraphed counteraction.
      next if event.instance_variable_get(:@bifrost_projectile_lock) ||
              event.instance_variable_get(:@bifrost_capture_lock)
      state[:frames] -= 1
      next if state[:frames] > 0
      unless state[:lunged]
        state[:lunged] = true
        event.move_toward_player if !event.moving? &&
          event.respond_to?(:move_toward_player)
        spec = event_spec(event)
        local = spec ? options($game_map.map_id,spec[0],event.id) : options
        state[:frames] = local["escape_lunge_delay"].to_i.clamp(6,45)
        next
      end
      next if event.moving?
      inside = distance(event) <= state[:range]
      if inside && state[:hp] > 0 && $player.respond_to?(:party)
        pokemon = $player.party.find do |pkmn|
          pkmn && pkmn.respond_to?(:able?) && pkmn.able? &&
            pkmn.respond_to?(:hp=) && pkmn.respond_to?(:totalhp)
        end
        if pokemon
          max = pokemon.totalhp.to_i
          amount = [(max*state[:hp]/100.0).round,1].max
          pokemon.hp = [pokemon.hp.to_i-amount,1].max if max > 1
          notice(_INTL("¡{1} perdió {2} PS!".dup,pokemon.name.to_s,amount))
          if defined?(Feedback)
            spec = event_spec(event)
            Feedback.publish(:party_hit,pokemon.species,
              _INTL("{1}: -{2} PS".dup,pokemon.name.to_s,amount))
          end
        end
      else
        notice(_INTL("¡Esquivaste la reacción del Pokémon!"))
      end
      cancel_escape_reaction(event)
      @escape_reaction_recovery = state[:recovery]
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

  # Talking to a generated OW Pokémon starts the ordinary wild battle.
  # Do not run it while an animated throw is still resolving.
  def self.interact_battle(event)
    return false unless event && eligible_event?(event)
    return false if event.instance_variable_get(:@bifrost_capture_lock) ||
                    event.instance_variable_get(:@bifrost_projectile_lock)
    return false if defined?(Motion) && Motion.busy?
    return false if $game_temp && ($game_temp.in_battle || $game_temp.in_menu)
    wild = battle_wild_for(event)
    return false unless wild
    BifrostCapture::LiveAim.close if defined?(BifrostCapture::LiveAim) &&
      BifrostCapture::LiveAim.active?
    BifrostCapture::Feedback.reset if defined?(BifrostCapture::Feedback)
    outcome = WildBattle.start(wild)
    if outcome
      Pressure.clear_success(event) if defined?(Pressure)
      remove_event(event)
    end
    true
  end

  def self.cancel_pending_attack(event)
    if @pending_attack && @pending_attack.equal?(event)
      @pending_attack = nil
      @aim_interrupted = false
    end
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
    if result
      Pressure.clear_success(event) if defined?(Pressure)
      remove_event(event)
    end
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
    update_escape_reactions
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
              event.instance_variable_get(:@bifrost_escape_reaction) ||
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
    (@escape_reactions || {}).values.dup.each { |event| cancel_escape_reaction(event) }
    @escape_reactions = {}
    @escape_reaction_recovery = 0
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
