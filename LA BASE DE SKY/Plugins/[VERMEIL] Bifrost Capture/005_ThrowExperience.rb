# frozen_string_literal: true
# Lanzamiento directo sobre el mapa: sin cuadrícula ni diálogo de apuntado.
# Sprite_Character/Game_Character entregan la posición de pantalla ya ajustada
# por la cámara de Visual 2.5D HD. No se altera el render de la cámara.
module BifrostCapture
  class AimOverlay
    attr_reader :viewport

    def initialize
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 999990
      @ring = Sprite.new(@viewport)
      @ring.bitmap = Bitmap.new(64, 64)
      @ring.ox = 32
      @ring.oy = 32
      @hud = Sprite.new(@viewport)
      @hud.bitmap = Bitmap.new(305, 84)
      @hud.x = [Graphics.width - 315, 4].max
      @hud.y = [Graphics.height - 94, 4].max
      @last_color = nil
    end

    def circle(bitmap, radius, color, thickness = 1)
      96.times do |i|
        angle = (i * Math::PI * 2) / 96
        x = 32 + Math.cos(angle) * radius
        y = 32 + Math.sin(angle) * radius
        bitmap.fill_rect(x.to_i, y.to_i, thickness, thickness, color)
      end
    end

    def update_reticle(x, y, status)
      @ring.visible = !!x && !!y
      return unless @ring.visible
      @ring.x = x.to_i
      @ring.y = y.to_i
      return if @last_color == status
      @last_color = status
      b = @ring.bitmap
      b.clear
      color = case status
              when :locked then Color.new(128, 236, 190, 236)
              when :far then Color.new(243, 123, 120, 226)
              else Color.new(233, 232, 216, 204)
              end
      circle(b, 24, color, 2)
      circle(b, 9, color)
      b.fill_rect(31, 0, 2, 10, color)
      b.fill_rect(31, 54, 2, 10, color)
      b.fill_rect(0, 31, 10, 2, color)
      b.fill_rect(54, 31, 10, 2, color)
      b.fill_rect(30, 30, 4, 4, color)
    end

    def update_hud(mode, item, quantity, focus, cfg, notice = nil)
      b = @hud.bitmap
      b.clear
      b.fill_rect(0, 0, 305, 84, Color.new(14, 19, 29, 194))
      b.fill_rect(0, 0, 3, 84, Color.new(148, 182, 239, 220))
      b.font.color = Color.new(239, 244, 250)
      b.font.size = 17
      label = mode == :ball ? (item ? GameData::Item.get(item).name : "Sin Poké Balls") : (item ? item.name : "Sin Pokémon")
      b.draw_text(12, 6, 270, 22, label + (mode == :ball ? "  x#{quantity}" : ""))
      b.font.size = 13
      if focus
        spec = BifrostCapture.event_spec(focus)
        b.draw_text(12, 30, 280, 17, "Objetivo: #{spec[0]}" + 
          (BifrostCapture.behind?($game_player.x, $game_player.y, focus) ? "  / espalda" : ""))
      else
        b.draw_text(12, 30, 280, 17, "Apunta a un Pokémon visible")
      end
      b.font.size = 11
      b.font.color = Color.new(179, 197, 220)
      b.draw_text(12, 61, 292, 18, "C / clic: lanzar    ↑↓: Balls    Z: modo    Esc: salir")
      if notice && !notice.empty?
        b.font.color = Color.new(246, 219, 152)
        b.draw_text(12, 44, 285, 18, notice)
      end
    end

    def dispose
      [@ring, @hud].each do |sprite|
        next if !sprite
        bitmap = sprite.bitmap
        sprite.dispose unless sprite.disposed?
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
      @viewport.dispose if @viewport && !@viewport.disposed?
    end
  end

  def self.notice(message)
    if @aim_running
      @aim_notice = message
      @aim_notice_frames = 65
    else
      pbMessage(message)
    end
  end

  def self.screen_position(event)
    [event.screen_x, event.screen_y - 16]
  end

  def self.aim_direction(event)
    dx = event.x - $game_player.x
    dy = event.y - $game_player.y
    return dx < 0 ? 4 : 6 if dx.abs > dy.abs
    dy < 0 ? 8 : 2
  end

  def self.current_focus(mouse_pos, selection, cfg)
    range = [cfg["range"].to_i, 1].max
    events = $game_map.events.values.select { |e| valid_target?(e) }
    return [nil, nil, nil] if events.empty?
    if mouse_pos && cfg["aim_mouse"] == "1"
      mx, my = mouse_pos
      radius = [cfg["aim_target_radius"].to_i, 10].max
      choices = events.map do |e|
        sx, sy = screen_position(e)
        [e, (sx-mx)**2 + (sy-my)**2]
      end
      best = choices.min_by { |entry| entry[1] }
      if best && best[1] <= radius**2
        return [best[0], mx, my]
      end
      return [nil, mx, my]
    end
    # Teclado: el objetivo más cercano; flechas izquierda/derecha rotan la lista.
    sorted = events.sort_by do |e|
      [($game_player.x-e.x).abs + ($game_player.y-e.y).abs, e.id]
    end
    focus = sorted[selection % sorted.length]
    return [focus, *screen_position(focus)]
  end

  def self.map_preview_update
    return unless $scene.is_a?(Scene_Map)
    # No actualizar al jugador: las flechas controlan el lanzamiento, no el paso.
    $scene.updateMaps
    $scene.updateSpritesets
  end

  def self.ball_sprite_bitmap(item)
    path = pbResolveBitmap("Graphics/Items/#{item}")
    path ||= pbResolveBitmap("Graphics/Items/POKEBALL")
    return Bitmap.new(path) if path
    # Reserva visual, sin depender de un fichero ajeno.
    bitmap = Bitmap.new(18, 18)
    bitmap.fill_rect(3, 2, 12, 7, Color.new(239, 97, 103))
    bitmap.fill_rect(3, 9, 12, 7, Color.new(230, 238, 249))
    bitmap.fill_rect(1, 8, 16, 2, Color.new(32, 42, 58))
    bitmap.fill_rect(7, 7, 4, 4, Color.new(250, 250, 255))
    bitmap
  end

  def self.fly_ball(item, end_x, end_y, distance, cfg)
    view = Viewport.new(0, 0, Graphics.width, Graphics.height)
    view.z = 999999
    ball = Sprite.new(view)
    ball.bitmap = ball_sprite_bitmap(item)
    ball.ox = ball.bitmap.width / 2
    ball.oy = ball.bitmap.height / 2
    # Usar los sprites de las Balls que ya incluye Vermeil.
    z = [24.0 / [ball.bitmap.width,ball.bitmap.height].max, 1.0].min
    ball.zoom_x = z
    ball.zoom_y = z
    start_x = $game_player.screen_x + 4
    start_y = $game_player.screen_y - 22
    frames = cfg["throw_frames"].to_i.clamp(8,48)
    arc = cfg["throw_arc"].to_i.clamp(0,110)
    begin
      frames.times do |i|
        t = (i+1).to_f / frames
        smooth = t*t*(3-2*t)
        ball.x = start_x + (end_x-start_x)*smooth
        ball.y = start_y + (end_y-start_y)*smooth -
                 Math.sin(Math::PI*t)*arc
        ball.angle = (t*520).to_i % 360
        Graphics.update
        Input.update
        $scene.updateSpritesets if $scene.is_a?(Scene_Map)
      end
    ensure
      bitmap = ball.bitmap
      ball.dispose unless ball.disposed?
      bitmap.dispose if bitmap && !bitmap.disposed?
      view.dispose unless view.disposed?
    end
  end

  def self.contact_fx(event)
    return unless event
    view = Viewport.new(0, 0, Graphics.width, Graphics.height)
    view.z = 999999
    sprite = Sprite.new(view)
    sprite.bitmap = Bitmap.new(52, 52)
    sprite.ox = 26
    sprite.oy = 26
    bitmap = sprite.bitmap
    72.times do |i|
      theta = i * Math::PI * 2 / 72
      x = 26 + Math.cos(theta) * 17
      y = 26 + Math.sin(theta) * 17
      bitmap.fill_rect(x.to_i, y.to_i, 2, 2, Color.new(240, 250, 255))
    end
    begin
      8.times do |i|
        sprite.x, sprite.y = screen_position(event)
        sprite.zoom_x = sprite.zoom_y = 0.55 + 0.065 * i
        sprite.opacity = 255 - 31 * i
        Graphics.update
        Input.update
        $scene.updateSpritesets if $scene.is_a?(Scene_Map)
      end
    ensure
      sprite.dispose unless sprite.disposed?
      bitmap.dispose unless bitmap.disposed?
      view.dispose unless view.disposed?
    end
  end

  # Impact frame localizado, sin el destello blanco de pantalla completa.
  def self.impact(frames)
    [[frames.to_i,0].max,5].min.times do
      Graphics.update
      Input.update
    end
  end

  # Sobrescribir únicamente la presentación: conserva las probabilidades,
  # inventario, formas de Galar y flujo de combate del runtime anterior.
  class << self
    alias bifrost_original_throw_at throw_at
  end

  def self.throw_at(tx, ty, forward, side, mode, payload, cfg)
    event = $game_map.events.values.find do |e|
      e.x == tx && e.y == ty && valid_target?(e)
    end
    destination = if event
      screen_position(event)
    else
      @aim_pointer || [$game_player.screen_x, $game_player.screen_y-64]
    end
    item = mode == :ball ? payload : :POKEBALL
    fly_ball(item, destination[0], destination[1], forward, cfg)
    bifrost_original_throw_at(tx, ty, forward, side, mode, payload, cfg)
  end

  def self.aim
    return false if !$game_player || !$game_map || !$player
    cfg = options
    return false if cfg["enabled"] != "1"
    return false if cfg["capture_enabled"] != "1" && cfg["battle_enabled"] != "1"
    return false if @aim_running
    previous_guard = @aim_opening
    @aim_opening = true
    @aim_running = true
    @aim_notice = nil
    @aim_notice_frames = 0
    balls = ball_choices
    ball_index = 0
    party_pokemon = $player.party.find { |p| p && p.able? }
    mode = cfg["capture_enabled"] == "1" && !balls.empty? ? :ball : :battle
    if mode == :battle && (!party_pokemon || cfg["battle_enabled"] != "1")
      @aim_running = false
      @aim_opening = previous_guard
      pbMessage(_INTL("No tienes nada que lanzar."))
      return false
    end
    overlay = AimOverlay.new
    selection = 0
    last_mouse = nil
    mouse_enabled = false
    frame_count = 0
    begin
      loop do
        Graphics.update
        Input.update
        map_preview_update
        frame_count += 1

        return false if Input.trigger?(Input::BACK)
        key = hotkey_code(cfg["hotkey"])
        return false if key && Input.trigger?(key) && frame_count > 8

        # Cambiar tipo de objeto sin reabrir un menú antes de cada lanzamiento.
        if Input.trigger?(Input::SPECIAL)
          if mode == :ball && cfg["battle_enabled"] == "1" && party_pokemon
            chosen = choose_pokemon
            if chosen
              party_pokemon = chosen
              mode = :battle
            end
          elsif mode == :battle && cfg["capture_enabled"] == "1" && !balls.empty?
            mode = :ball
          end
        end
        if mode == :ball && !balls.empty?
          if Input.trigger?(Input::UP)
            ball_index = (ball_index-1) % balls.length
          elsif Input.trigger?(Input::DOWN)
            ball_index = (ball_index+1) % balls.length
          end
        end
        if Input.trigger?(Input::LEFT)
          selection -= 1
          mouse_enabled = false
        elsif Input.trigger?(Input::RIGHT)
          selection += 1
          mouse_enabled = false
        end
        if cfg["aim_mouse"] == "1" && defined?(Mouse)
          pos = Mouse.getMousePos
          if pos && last_mouse &&
             ((pos[0]-last_mouse[0]).abs+(pos[1]-last_mouse[1]).abs) >= 2
            mouse_enabled = true
          end
          last_mouse = pos if pos
        end
        focus, x, y = current_focus(mouse_enabled ? last_mouse : nil, selection, cfg)
        if !focus && !mouse_enabled
          fx, fy = DIR[$game_player.direction] || [0,-1]
          x = $game_player.screen_x + fx * 70
          y = $game_player.screen_y - 25 + fy * 70
        end
        forward = [cfg["range"].to_i+1, 8].max
        lateral = 0
        status = :free
        if focus
          facing = aim_direction(focus)
          forward, lateral = relative($game_player.x,$game_player.y,
                                      facing,focus.x,focus.y)
          valid = forward.between?(1,cfg["range"].to_i) &&
                  lateral.abs <= cfg["width"].to_i/2
          status = valid ? :locked : :far
        end
        overlay.update_reticle(x,y,status)
        if @aim_notice_frames > 0
          @aim_notice_frames -= 1
        else
          @aim_notice = nil
        end
        current_ball = balls[ball_index] && balls[ball_index][0]
        current_qty = current_ball ? $bag.quantity(current_ball) : 0
        if mode == :ball && current_qty <= 0
          balls = ball_choices
          ball_index = 0
          current_ball = balls[0] && balls[0][0]
          current_qty = current_ball ? $bag.quantity(current_ball) : 0
          if !current_ball && cfg["battle_enabled"] == "1" && party_pokemon
            mode = :battle
          end
        end
        overlay.update_hud(mode,mode == :ball ? current_ball : party_pokemon,
                           current_qty,focus,cfg,@aim_notice)
        left_click = cfg["aim_mouse"] == "1" && defined?(Input::MOUSELEFT) &&
                     Input.trigger?(Input::MOUSELEFT)
        next unless frame_count > 6 &&
                    (Input.trigger?(Input::USE) || left_click)
        payload = mode == :ball ? current_ball : party_pokemon
        next if !payload
        @aim_pointer = [x,y]
        if focus
          facing = aim_direction(focus)
          # Solo cambia el facing visual. Evita el evento de encuentro
          # aleatorio que se ejecutaría mediante turn_up/left/right.
          $game_player.instance_variable_set(:@direction,facing)
          throw_at(focus.x,focus.y,forward,lateral,mode,payload,cfg)
        else
          # El lanzamiento vacío no inventa un objetivo: siempre falla.
          fx, fy = DIR[$game_player.direction] || [0,-1]
          tx = $game_player.x + fx * forward
          ty = $game_player.y + fy * forward
          throw_at(tx,ty,forward,0,mode,payload,cfg)
        end
        break if mode == :battle || cfg["aim_chain"] == "0"
        balls = ball_choices if mode == :ball
        ball_index = 0 if ball_index >= balls.length
      end
    ensure
      @aim_pointer = nil
      overlay.dispose if overlay
      @aim_running = false
      @aim_opening = previous_guard
    end
    true
  end
end
