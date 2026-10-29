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

  # No resolver un disparo mediante coordenadas antiguas: conservar el
  # objeto Game_Event que estuvo bajo la retícula durante el lanzamiento.
  def self.resolve_throw(event, mode, payload, config, behind_at_release = nil)
    if !event || !valid_target?(event)
      notice(_INTL("El Pokémon ya no está en la trayectoria."))
      return false
    end
    spec = event_spec(event)
    cfg = options($game_map.map_id, spec[0], event.id)
    px, py = $game_player.x, $game_player.y
    geometry = shot_geometry(px, py, event.x, event.y, cfg)
    blocked = cfg["line_of_sight"] == "1" &&
              !line_clear?(px, py, event.x, event.y)
    chance = geometry[:in_range] && !blocked ?
             hit_chance(geometry[:forward], cfg) : 0.0
    hit = geometry[:in_range] && !blocked && rand < chance
    if mode == :ball && (hit || cfg["consume_on_miss"] == "1")
      if !$bag.remove(payload, 1)
        notice(_INTL("Ya no quedan Poké Balls de ese tipo."))
        return false
      end
    end
    if !hit
      message = if !geometry[:in_range]
                  _INTL("¡El Pokémon está fuera de alcance!")
                elsif blocked
                  _INTL("¡Hay un obstáculo en la trayectoria!")
                else
                  _INTL("¡La Poké Ball se ha desviado!")
                end
      notice(message)
      react(event, cfg, :miss) if cfg["alert_on_miss"] != "0"
      return false
    end

    contact_fx(event)
    if mode == :battle
      # Mantener el Pokémon que se eligió, sin alterar permanentemente el orden
      # del equipo ni generar otra copia de la criatura salvaje.
      wild = pbGenerateWildPokemon(spec[0], spec[1])
      wild.form = spec[2] if spec[2] > 0
      party = $player.party
      original = party.dup
      i = party.index(payload)
      if i && i > 0
        party.delete_at(i)
        party.unshift(payload)
      end
      begin
        result = WildBattle.start(wild)
        remove_event(event) if result
      ensure
        party.replace(original.select { |p| party.include?(p) } +
                      party.reject { |p| original.include?(p) })
      end
      return true
    end

    from_behind = behind_at_release.nil? ?
                  behind?(px, py, event) : behind_at_release
    critical_rate = from_behind ? cfg["critical_back"] : cfg["critical_front"]
    critical = rand < critical_rate.to_f / 100.0
    impact(cfg["impact_frames"].to_i) if from_behind
    probability = catch_chance(spec[0], payload, geometry[:forward],
                               from_behind, critical, cfg)
    if rand < probability
      pkmn = pbGenerateWildPokemon(spec[0], spec[1])
      pkmn.form = spec[2] if spec[2] > 0
      pkmn.poke_ball = payload if pkmn.respond_to?(:poke_ball=)
      stored = pbAddPokemon(pkmn)
      if stored
        notice(critical ? _INTL("¡Captura crítica!") : _INTL("¡Capturado!"))
        remove_event(event)
        return true
      end
      notice(_INTL("La captura no se pudo guardar."))
      return false
    end
    notice(_INTL("¡El Pokémon se ha liberado!"))
    react(event, cfg, :breakout)
    false
  end

  # Compatibilidad con los eventos de scripts existentes y los tests antiguos.
  def self.throw_at(tx, ty, _forward, _side, mode, payload, cfg)
    event = $game_map.events.values.find do |e|
      e.x == tx && e.y == ty && valid_target?(e)
    end
    resolve_throw(event, mode, payload, cfg)
  end

  # La detección real y el movimiento continuo se gestionan en 006_Behavior.
  # Este hook solo enlaza los pasos con el mismo sistema de estados.
  def self.on_step
    update_behavior(true) if respond_to?(:update_behavior)
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
