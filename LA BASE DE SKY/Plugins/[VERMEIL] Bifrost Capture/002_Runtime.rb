# frozen_string_literal: true
# Lanzamiento: cursor frontal, 7 columnas x 7 filas + 8a fila de fallo.
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

  def self.aim
    return false if !$game_player || !$game_map || !$player
    cfg = options
    return false if cfg["enabled"] != "1"
    commands = []
    commands << _INTL("Lanzar Poké Ball") if cfg["capture_enabled"] == "1"
    commands << _INTL("Enviar Pokémon") if cfg["battle_enabled"] == "1"
    commands << _INTL("Salir")
    selection = pbMessage(_INTL("¿Qué deseas lanzar?"), commands, commands.length-1)
    return false if selection < 0 || selection == commands.length-1
    mode = commands[selection] == _INTL("Lanzar Poké Ball") ? :ball : :battle
    payload = mode == :ball ? choose_ball : choose_pokemon
    return false if !payload
    return show_aim_cursor(mode,payload,cfg)
  end

  def self.show_aim_cursor(mode,payload,cfg)
    px,py = $game_player.x,$game_player.y
    facing = $game_player.direction
    side,forward = 0, [cfg["optimal_range"].to_i,1].max
    maxrange = [cfg["range"].to_i,1].max
    width = [cfg["width"].to_i,1].max
    width += 1 if width.even?
    forward = [forward,maxrange].min
    half = width/2
    # Se usa una superposicion ligera sobre el mapa, sin cambiar la camara 2.5D.
    viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
    viewport.z = 999999
    sprite = Sprite.new(viewport)
    sprite.bitmap = Bitmap.new(Graphics.width,Graphics.height)
    begin
      loop do
        bitmap = sprite.bitmap
        bitmap.clear
        header = _INTL("APUNTAR  |  ↑↓ distancia  ←→ lateral  C lanzar  B cancelar")
        bitmap.draw_text(0,8,Graphics.width,32,header,1)
        bitmap.draw_text(0,42,Graphics.width,26,
          _INTL("Fila {1}/{2} | Columna {3}/{4}",forward,maxrange,side+half+1,width),1)
        # Grilla compacta 7x7 (+8a casilla si el autor configura 8+).
        cell = [27, 180/[maxrange,7].max].min
        origin_x = Graphics.width/2 - width*cell/2
        origin_y = 85
        (1..[maxrange+1,8].max).each do |f|
          next if f > 12
          (-half..half).each do |s|
            x=origin_x+(s+half)*cell
            y=origin_y+(f-1)*cell
            color = f>maxrange ? Color.new(130,50,50,150) :
              Color.new(38,62,96,140)
            bitmap.fill_rect(x+1,y+1,cell-2,cell-2,color)
            if f==forward && s==side
              bitmap.fill_rect(x+4,y+4,cell-8,cell-8,Color.new(255,218,95,220))
            end
          end
        end
        tx,ty=offset(px,py,facing,forward,side)
        target = $game_map.events.values.find { |e| e.x==tx && e.y==ty && valid_target?(e) }
        bitmap.draw_text(0,Graphics.height-50,Graphics.width,35,
          target ? _INTL("Objetivo: {1}",event_spec(target)[0]) :
          _INTL("Casilla sin objetivo"),1)
        Graphics.update
        Input.update
        return false if Input.trigger?(Input::BACK)
        if Input.trigger?(Input::UP)
          forward = [forward-1,1].max
        elsif Input.trigger?(Input::DOWN)
          forward = [forward+1,maxrange+1].min
        elsif Input.trigger?(Input::LEFT)
          side = [side-1,-half].max
        elsif Input.trigger?(Input::RIGHT)
          side = [side+1,half].min
        elsif Input.trigger?(Input::USE)
          return throw_at(tx,ty,forward,side,mode,payload,cfg)
        end
      end
    ensure
      sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
      sprite.dispose if !sprite.disposed?
      viewport.dispose if !viewport.disposed?
    end
  end

  def self.impact(frames)
    return if frames <= 0
    view = Viewport.new(0,0,Graphics.width,Graphics.height)
    view.z = 999999
    view.color = Color.new(255,255,255,95)
    begin
      frames.times { Graphics.update }
    ensure
      view.dispose
    end
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
      pbMessage(_INTL("¡El Pokémon ha huido!"))
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
    valid_tile = forward.between?(1,range) && side.abs <= width/2
    visible = cfg["line_of_sight"] != "1" || line_clear?(px,py,tx,ty)
    hit = !!event && valid_tile && visible &&
          rand < hit_chance(forward,cfg)
    # Al impactar se consume siempre una Ball. Si falla por apuntado,
    # consume_on_miss decide si el lanzamiento gasta el item.
    if mode == :ball && (hit || cfg["consume_on_miss"] == "1")
      return false unless $bag.remove(payload,1)
    end
    if !hit
      pbMessage(_INTL("¡El lanzamiento ha fallado!"))
      react(event,cfg) if event
      return false
    end
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
      pbMessage(critical ? _INTL("¡Captura crítica!") : _INTL("¡Capturado!"))
      # El motor decide equipo/cajas y registra Pokédex normalmente.
      pbAddPokemon(pkmn)
      remove_event(event)
      return true
    end
    pbMessage(_INTL("¡Se ha liberado!"))
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
