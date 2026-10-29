# frozen_string_literal: true
# Inventario, resolucion de impacto, captura y encuentros; la presentacion se maneja en 005.
module BifrostCapture
  def self.ball_choices
    items = []
    $bag.pockets.each do |pocket|
      pocket.each do |entry|
        next if !entry
        item, qty = entry[0], entry[1]
        data = GameData::Item.try_get(item)
        items << [item, qty] if qty > 0 && data && data.is_poke_ball?
      end
    end
    items
  end

  def self.choose_ball
    balls = ball_choices
    if balls.empty?
      pbMessage(_INTL("No tienes Poké Balls."))
      return nil
    end
    commands = balls.map { |item,qty| _INTL("{1} x{2}", GameData::Item.get(item).name, qty) }
    commands << _INTL("Cancelar")
    idx = pbMessage(_INTL("Selecciona una Poké Ball."),commands,commands.length-1)
    return nil if idx < 0 || idx >= balls.length
    balls[idx][0]
  end

  def self.choose_pokemon
    usable = $player.party.each_with_index.select { |p,i| p && p.able? }
    return nil if usable.empty?
    commands = usable.map { |p,i| _INTL("{1} (Nv. {2})",p.name,p.level) }
    commands << _INTL("Cancelar")
    idx = pbMessage(_INTL("¿A quién enviarás?"),commands,commands.length-1)
    return nil if idx < 0 || idx >= usable.length
    usable[idx][0]
  end

  def self.react(event, cfg)
    case cfg["reaction"]
    when "attack"
      spec = event_spec(event)
      return false unless spec
      pbMessage(_INTL("¡El Pokémon se ha abalanzado sobre ti!"))
      wild = pbGenerateWildPokemon(spec[0],spec[1])
      wild.form = spec[2] if spec[2] > 0
      result = WildBattle.start(wild)
      remove_event(event) if result
    when "flee"
      notice(_INTL("¡El Pokémon ha huido!"))
      remove_event(event)
    end
    true
  end

  def self.throw_at(tx,ty,forward,side,mode,payload,base)
    px,py = $game_player.x,$game_player.y
    event = $game_map.events.values.find { |e| e.x==tx && e.y==ty && valid_target?(e) }
    cfg = event ? options($game_map.map_id,event_spec(event)[0],event.id) : base
    range = [cfg["range"].to_i,1].max
    width = [cfg["width"].to_i,1].max
    if event
      geom = shot_geometry(px, py, event.x, event.y, cfg)
      forward, side = geom[:forward], geom[:side]
      valid_tile = geom[:in_range]
    else
      valid_tile = false
    end
    visible = !event || cfg["line_of_sight"] != "1" ||
              line_clear?(px,py,tx,ty)
    accuracy = valid_tile ? hit_chance(forward,cfg) : 0.0
    hit = !!event && valid_tile && visible && rand < accuracy
    # Al impactar se consume siempre una Ball. Si falla por apuntado,
    # consume_on_miss decide si el lanzamiento gasta el item.
    if mode == :ball && (hit || cfg["consume_on_miss"] == "1")
      return false unless $bag.remove(payload,1)
    end
    if !hit
      reason = if !event
                 _INTL("No hay un Pokémon en la trayectoria.")
               elsif !valid_tile
                 _INTL("El objetivo está fuera de alcance.")
               elsif !visible
                 _INTL("Un obstáculo bloquea el lanzamiento.")
               else
                 _INTL("La Poké Ball se ha desviado.")
               end
      notice(reason)
      react(event,cfg) if event && valid_tile && visible
      return false
    end
    contact_fx(event)
    spec=event_spec(event)
    if mode == :battle
      pbMessage(_INTL("¡Adelante, {1}!",payload.name))
      wild = pbGenerateWildPokemon(spec[0],spec[1])
      wild.form = spec[2] if spec[2] > 0
      # El Pokémon elegido encabeza temporalmente el equipo al iniciar combate.
      party = $player.party
      original_order = party.dup
      index = party.index(payload)
      if index && index > 0
        party.delete_at(index)
        party.unshift(payload)
      end
      begin
        result = WildBattle.start(wild)
        remove_event(event) if result
      ensure
        # Preservar capturas u otros cambios reales en el equipo.
        party.replace(original_order.select { |p| party.include?(p) } +
                      party.reject { |p| original_order.include?(p) })
      end
      return true
    end
    behind=behind?(px,py,event)
    critical=rand < (behind ? cfg["critical_back"].to_f :
                                cfg["critical_front"].to_f)/100.0
    impact(cfg["impact_frames"].to_i) if behind
    pkmn=pbGenerateWildPokemon(spec[0],spec[1])
    pkmn.form=spec[2] if spec[2] > 0
    chance=catch_chance(spec[0],payload,forward,behind,critical,cfg)
    if rand < chance
      pkmn.poke_ball=payload if pkmn.respond_to?(:poke_ball=)
      notice(critical ? _INTL("¡Captura crítica!") : _INTL("¡Capturado!"))
      # El motor decide equipo/cajas y registra Pokédex normalmente.
      pbAddPokemon(pkmn)
      remove_event(event)
      return true
    end
    notice(_INTL("¡El Pokémon se ha liberado!"))
    react(event,cfg)
    false
  end

  def self.on_step
    return if !$game_map || !$game_player
    $game_map.events.values.each do |event|
      next unless valid_target?(event)
      spec=event_spec(event)
      cfg=options($game_map.map_id,spec[0],event.id)
      next unless cfg["alert_distance"].to_i > 0
      dist = ($game_player.x-event.x).abs + ($game_player.y-event.y).abs
      next unless dist <= cfg["alert_distance"].to_i
      # Una sola reaccion por evento. Al alejarse se permite otra.
      @alerted ||= {}
      id=[$game_map.map_id,event.id]
      next if @alerted[id]
      @alerted[id]=true
      react(event,cfg)
    end
    @alerted ||= {}
    @alerted.delete_if do |id,_|
      next true if id[0] != $game_map.map_id
      event = $game_map.events[id[1]]
      !event || ($game_player.x-event.x).abs +
        ($game_player.y-event.y).abs > 4
    end
  end
end

# Llamar pbBifrostAim desde un evento, un objeto o un control personalizado.
def pbBifrostAim
  BifrostCapture.aim
end

EventHandlers.add(:on_player_step_taken,:bifrost_capture_alert,
  proc { BifrostCapture.on_step }
)

# No modifica Scene_Map#update_input ni el menu Ready: usa el handler
# oficial de fotogramas de Essentials y solo actua con access_mode adecuado.
EventHandlers.add(:on_frame_update, :bifrost_capture_access,
  proc { BifrostCapture.update_access }
)
