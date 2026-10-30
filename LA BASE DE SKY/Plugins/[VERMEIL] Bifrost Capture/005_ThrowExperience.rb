# frozen_string_literal: true
# Bifrost Capture - map-space aim, real Sprite_Character bounds, projectile/HUD.
module BifrostCapture
  # Compact 3-slot ball wheel; aiming feedback is separate from capture result.
  class ThrowHUD
    def initialize
      @vp = Viewport.new(0,0,Graphics.width,Graphics.height)
      @vp.z = 999992
      @aim = Sprite.new(@vp)
      @aim.bitmap = Bitmap.new(64,64)
      @aim.ox = @aim.oy = 32
      @panel = Sprite.new(@vp)
      @panel.bitmap = Bitmap.new(316,104)
      @panel.x = [Graphics.width-323,4].max
      @panel.y = [Graphics.height-111,4].max
      @last_status = nil
      @icons = {}
      @ball_list = []
      @selected = 0
    end

    def equip(list,selected)
      @ball_list = list || []
      @selected = selected.to_i
    end

    def icon(item)
      return nil if !item
      return @icons[item] if @icons.key?(item)
      filename = pbResolveBitmap("Graphics/Items/#{item}")
      @icons[item] = filename ? Bitmap.new(filename) : nil
    end

    def reticle(x,y,status)
      @aim.x = x.to_i
      @aim.y = y.to_i
      @aim.visible = true
      return if status == @last_status
      @last_status = status
      bmp = @aim.bitmap
      bmp.clear
      color = case status
              when :ready then Color.new(136,249,188)
              when :blocked then Color.new(249,146,142)
              else Color.new(224,231,241)
              end
      72.times do |i|
        theta = i*2*Math::PI/72
        px=(32+Math.cos(theta)*19).round
        py=(32+Math.sin(theta)*19).round
        bmp.fill_rect(px,py,2,2,color)
      end
      # Four small breaks make the cursor readable over grass and foliage.
      bmp.fill_rect(31,2,2,10,color)
      bmp.fill_rect(31,52,2,10,color)
      bmp.fill_rect(2,31,10,2,color)
      bmp.fill_rect(52,31,10,2,color)
      bmp.fill_rect(30,30,4,4,color)
    end

    def draw(mode,item,count,focus,notice)
      bmp = @panel.bitmap
      bmp.clear
      bmp.fill_rect(0,0,316,104,Color.new(13,19,31,223))
      bmp.fill_rect(0,0,3,104,Color.new(174,195,227))
      bmp.font.size = 12
      bmp.font.color = Color.new(169,187,212)
      bmp.draw_text(12,4,280,16,mode == :ball ? "POKÉ BALL EQUIPADA" : "POKÉMON PREPARADO")
      if mode == :ball
        # Three-slot strip; middle slot is the item being thrown.
        [-1,0,1].each_with_index do |offset,i|
          next if @ball_list.empty?
          idx = (@selected+offset) % @ball_list.length
          selected_ball = @ball_list[idx][0]
          left = 14+i*54
          bmp.fill_rect(left,24,49,43,
            Color.new(44,64,85, i==1 ? 228 : 138))
          bmp.fill_rect(left,64,49,2,i==1 ?
            Color.new(146,231,194) : Color.new(83,107,130))
          source = icon(selected_ball)
          if source && source.width > 0 && source.height > 0
            bmp.stretch_blt(Rect.new(left+10,28,29,29), source,
                            Rect.new(0,0,source.width,source.height))
          else
            bmp.fill_rect(left+18,37,13,13,Color.new(211,223,244))
          end
          bmp.font.color = i==1 ? Color.new(243,247,255) :
                          Color.new(178,195,214)
          bmp.draw_text(left,52,49,13,"x#{$bag.quantity(selected_ball)}",1)
        end
      else
        bmp.fill_rect(15,28,153,42,Color.new(43,61,79,204))
        bmp.font.size = 17
        bmp.font.color = Color.new(235,243,253)
        bmp.draw_text(23,36,143,25,item ? item.name : "-")
      end
      bmp.fill_rect(182,24,123,43,Color.new(28,37,53,216))
      spec = focus && BifrostCapture.event_spec(focus)
      bmp.font.size = 12
      bmp.font.color = spec ? Color.new(175,243,200) :
                        Color.new(235,174,161)
      bmp.draw_text(189,25,109,19,spec ? spec[0].to_s : "SIN OBJETIVO")
      bmp.font.color = Color.new(227,234,244)
      bmp.draw_text(189,46,109,18,spec ? "Nv. #{spec[1]}" : "Busca un OW")
      bmp.font.size = 12
      bmp.font.color = Color.new(248,214,157)
      bmp.draw_text(13,71,293,17,notice.to_s)
      bmp.font.size = 10
      bmp.font.color = Color.new(176,193,216)
      bmp.draw_text(13,90,294,13,"W apuntar/soltar · Q cambiar · C lanzar · D modo")
    end

    def dispose
      @icons.each_value do |bitmap|
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
      [@aim,@panel].each do |sprite|
        bitmap = sprite.bitmap
        sprite.dispose unless sprite.disposed?
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
      @vp.dispose unless @vp.disposed?
    end
  end

  # Actual onscreen area from Sprite_Character (including camera zoom).
  def self.target_rect(event)
    if $scene.is_a?(Scene_Map) && $scene.respond_to?(:spriteset)
      spriteset = $scene.spriteset($game_map.map_id)
      sprites = spriteset && spriteset.instance_variable_get(:@character_sprites)
      sprite = sprites && sprites.find { |sp| sp && sp.character.equal?(event) }
      if sprite && !sprite.disposed? && sprite.visible
        w = [sprite.src_rect.width*sprite.zoom_x.abs,8].max
        h = [sprite.src_rect.height*sprite.zoom_y.abs,8].max
        return [sprite.x-sprite.ox*sprite.zoom_x,
                sprite.y-sprite.oy*sprite.zoom_y,w,h]
      end
    end
    size = event.respond_to?(:sprite_size) ? event.sprite_size : [32,32]
    w = [size[0].to_f,20].max
    h = [size[1].to_f,20].max
    [event.screen_x-w/2,event.screen_y-h,w,h]
  end

  def self.screen_position(event)
    x,y,w,h = target_rect(event)
    [x+w/2,y+h*0.55]
  end

  def self.rect_distance(px,py,rect)
    x,y,w,h = rect
    dx = [x-px,0,px-x-w].max
    dy = [y-py,0,py-y-h].max
    dx*dx+dy*dy
  end

  def self.visible_targets
    return [] unless $game_map
    $game_map.events.values.select do |event|
      next false unless eligible_event?(event)
      x,y,w,h = target_rect(event)
      x < Graphics.width && y < Graphics.height && x+w > 0 && y+h > 0
    end
  end

  def self.focus_at(point,cfg)
    return nil unless point
    radius = cfg["aim_target_radius"].to_i.clamp(4,120)
    nearest = visible_targets.map { |event|
      [event,rect_distance(point[0],point[1],target_rect(event))]
    }.min_by { |row| row[1] }
    nearest && nearest[1] <= radius*radius ? nearest[0] : nil
  end

  def self.closest_target
    all = visible_targets
    ready = all.select do |event|
      spec = event_spec(event)
      local = options($game_map.map_id,spec[0],event.id)
      geo = geometry($game_player.x,$game_player.y,event.x,event.y,local)
      geo[:in_range] && (local["line_of_sight"] != "1" ||
        line_clear?($game_player.x,$game_player.y,event.x,event.y))
    end
    (ready.empty? ? all : ready).min_by do |event|
      [($game_player.x-event.x).abs+($game_player.y-event.y).abs,event.id]
    end
  end

  def self.update_frame
    $scene.updateMaps
    $scene.updateSpritesets
  end

  def self.ball_bitmap(item)
    filename = pbResolveBitmap("Graphics/Items/#{item}")
    filename ||= pbResolveBitmap("Graphics/Items/POKEBALL")
    return Bitmap.new(filename) if filename
    bmp = Bitmap.new(18,18)
    bmp.fill_rect(2,2,14,7,Color.new(220,80,84))
    bmp.fill_rect(2,9,14,7,Color.new(244,241,225))
    bmp.fill_rect(2,8,14,2,Color.new(33,35,42))
    bmp.fill_rect(7,7,4,4,Color.new(247,247,247))
    bmp
  end

  def self.projectile(item,event,point,cfg,hit_roll=nil)
    vp = Viewport.new(0,0,Graphics.width,Graphics.height)
    vp.z = 999996
    sprite = Sprite.new(vp)
    sprite.bitmap = ball_bitmap(item)
    sprite.ox = sprite.bitmap.width/2
    sprite.oy = sprite.bitmap.height/2
    scale = [26.0/[sprite.bitmap.width,sprite.bitmap.height].max,1.0].min
    sprite.zoom_x = sprite.zoom_y = scale
    shadow = Sprite.new(vp)
    shadow.bitmap = Bitmap.new(34,10)
    shadow.bitmap.fill_rect(2,2,30,6,Color.new(10,15,20,74))
    shadow.ox = 17
    shadow.oy = 5
    trail_bmp = Bitmap.new(12,12)
    trail_bmp.fill_rect(5,1,2,10,Color.new(225,240,255))
    trail_bmp.fill_rect(1,5,10,2,Color.new(225,240,255))
    trails = Array.new(4) do
      t = Sprite.new(vp)
      t.bitmap = trail_bmp
      t.ox = t.oy = 6
      t.visible = false
      t
    end
    positions = []
    x,y,w,h = target_rect($game_player)
    begin
      pbSEPlay("Battle throw") if cfg["feedback_sfx"] != "0" &&
        defined?(pbSEPlay)
    rescue StandardError
    end
    sx,sy = x+w*0.75,y+h*0.50
    ground_start = y+h
    ex,ey = point
    ground_end = ey+20
    frames = cfg["throw_frames"].to_i.clamp(8,48)
    arc = cfg["throw_arc"].to_i.clamp(0,110)
    will_miss = false
    if event && hit_roll
      spec = event_spec(event)
      if spec
        local = options($game_map.map_id,spec[0],event.id)
        geo = geometry($game_player.x,$game_player.y,event.x,event.y,local)
        will_miss = geo[:in_range] &&
          hit_roll >= hit_chance(geo[:front],local)
      end
    end
    begin
      frames.times do |i|
        t = (i+1).to_f/frames
        k = t*t*(3-2*t)
        if event && eligible_event?(event)
          ex,ey = screen_position(event)
          r = target_rect(event)
          ground_end = r[1]+r[3]
        end
        sprite.x = sx+(ex-sx)*k
        sprite.y = sy+(ey-sy)*k-Math.sin(Math::PI*t)*arc
        # Deviation is the SAME pre-rolled hit check used by resolve_throw.
        # It starts late in the arc so the throw remains readable.
        if will_miss
          drift = [((k-0.55)/0.45),0.0].max
          sprite.x += drift*35
          sprite.y -= drift*12
        end
        sprite.angle = (480*t).to_i
        positions.unshift([sprite.x,sprite.y])
        positions = positions.first(5)
        trails.each_with_index do |tr,j|
          point = positions[j+1]
          tr.visible = !!point
          next unless point
          tr.x,tr.y = point
          tr.opacity = 190-j*43
          tr.zoom_x = tr.zoom_y = 0.75-j*0.12
        end
        shadow.x = sprite.x
        shadow.y = ground_start+(ground_end-ground_start)*k
        shadow.opacity = (110-70*Math.sin(Math::PI*t)).to_i
        Graphics.update
        Input.update
        update_frame
      end
    ensure
      trails.each { |t| t.dispose unless t.disposed? }
      trail_bmp.dispose unless trail_bmp.disposed?
      [sprite,shadow].each do |s|
        bmp = s.bitmap
        s.dispose unless s.disposed?
        bmp.dispose if bmp && !bmp.disposed?
      end
      vp.dispose unless vp.disposed?
    end
  end

  def self.contact_fx(event)
    return unless event
    vp = Viewport.new(0,0,Graphics.width,Graphics.height)
    vp.z = 999997
    flash = Sprite.new(vp)
    flash.bitmap = Bitmap.new(40,40)
    48.times do |i|
      theta = i*Math::PI/24
      px = (20+Math.cos(theta)*16).round
      py = (20+Math.sin(theta)*16).round
      flash.bitmap.fill_rect(px,py,2,2,Color.new(246,252,250))
    end
    flash.ox = flash.oy = 20
    begin
      7.times do |i|
        flash.x,flash.y = screen_position(event)
        flash.opacity = 255-i*33
        flash.zoom_x = flash.zoom_y = 0.7+i*0.1
        Graphics.update
        Input.update
        update_frame
      end
    ensure
      bmp = flash.bitmap
      flash.dispose unless flash.disposed?
      bmp.dispose if bmp && !bmp.disposed?
      vp.dispose unless vp.disposed?
    end
  end

  def self.animate_catch(event,item,caught,critical,cfg)
    return unless event
    vp = Viewport.new(0,0,Graphics.width,Graphics.height)
    vp.z = 999997
    ball = Sprite.new(vp)
    ball.bitmap = ball_bitmap(item)
    ball.ox = ball.bitmap.width/2
    ball.oy = ball.bitmap.height/2
    old_transparency = event.transparent
    old_move_type = event.instance_variable_get(:@move_type)
    event.instance_variable_set(:@bifrost_capture_lock,true)
    event.instance_variable_set(:@move_type,0)
    event.transparent = true
    begin
      count = critical ? 1 : cfg["capture_shakes"].to_i.clamp(1,5)
      frames = cfg["capture_shake_frames"].to_i.clamp(4,20)
      count.times do
        frames.times do |frame|
          ball.x,ball.y = screen_position(event)
          ball.y += 14
          ball.angle = Math.sin(frame*2*Math::PI/frames)*14
          Graphics.update
          Input.update
          update_frame
        end
      end
    ensure
      event.transparent = old_transparency
      event.instance_variable_set(:@move_type,old_move_type)
      event.instance_variable_set(:@bifrost_capture_lock,false)
      bmp = ball.bitmap
      ball.dispose unless ball.disposed?
      bmp.dispose if bmp && !bmp.disposed?
      vp.dispose unless vp.disposed?
    end
  end

  def self.update_input
    return if @aim_open
    cfg = options
    return unless ["always","nearby"].include?(cfg["access_mode"])
    return unless aim_allowed?
    key = hotkey
    return unless key && Input.trigger?(key)
    if cfg["access_mode"] == "nearby"
      return unless closest_target
    end
    aim
  end

  def self.aim
    return false if @aim_open || !aim_allowed?
    @aim_open = true
    cancelled = false
    hud = nil
    begin
      cfg = options
      hud = ThrowHUD.new
      balls = ball_choices
      selected = 0
      party = $player.party.select { |p| p && p.able? }
      party_i = 0
      mode = cfg["capture_enabled"] == "1" && !balls.empty? ? :ball : :battle
      unless (mode == :ball && !balls.empty?) ||
             (mode == :battle && cfg["battle_enabled"] == "1" && !party.empty?)
        notice(_INTL("No hay Poké Balls ni Pokémon disponibles."))
        return false
      end
      focus = closest_target
      px,py = focus ? screen_position(focus) :
        [$game_player.screen_x,$game_player.screen_y-65]
      mouse_mode = false
      dx = 0
      dy = 0
      old_mouse = nil
      frames = 0
      key = hotkey
      # A manual event opening must not auto-fire when the configured mode is
      # hold-to-release unless the player actually held the aiming button.
      held_seen = !!(key && Input.press?(key))
      loop do
        Graphics.update
        Input.update
        update_frame
        frames += 1
        held_seen = true if key && Input.press?(key)
        if Input.trigger?(Input::BACK) ||
           (cfg["control_mode"] != "hold" && key && frames > 8 &&
             Input.trigger?(key))
          cancelled = true
          break
        end
        break if @aim_interrupted
        if Input.trigger?(Input::SPECIAL)
          mode = mode == :ball ? :battle : :ball
          mode = :ball if mode == :battle &&
            (cfg["battle_enabled"] != "1" || party.empty?)
          mode = :battle if mode == :ball &&
            (cfg["capture_enabled"] != "1" || balls.empty?)
        end
        cycle = key == Input::AUX1 ? Input::ACTION : Input::AUX1
        if Input.trigger?(cycle)
          if mode == :ball && balls.length > 1
            selected = (selected+1)%balls.length
          elsif mode == :battle && party.length > 1
            party_i = (party_i+1)%party.length
          end
        end
        if cfg["aim_keyboard"] == "1"
          speed = cfg["aim_speed"].to_i.clamp(1,16)
          dx = (Input.press?(Input::RIGHT) ? 1 : 0) -
               (Input.press?(Input::LEFT) ? 1 : 0)
          dy = (Input.press?(Input::DOWN) ? 1 : 0) -
               (Input.press?(Input::UP) ? 1 : 0)
          if dx != 0 || dy != 0
            px = (px+dx*speed).clamp(8,Graphics.width-8)
            py = (py+dy*speed).clamp(8,Graphics.height-8)
            mouse_mode = false
          end
          if Input.trigger?(Input::ACTION) && key != Input::AUX1
            target = closest_target
            px,py = screen_position(target) if target
          end
        end
        if cfg["aim_mouse"] == "1" && defined?(Mouse)
          mouse = Mouse.getMousePos
          if mouse && old_mouse &&
             (mouse[0]-old_mouse[0]).abs+(mouse[1]-old_mouse[1]).abs >= 3
            mouse_mode = true
          end
          old_mouse = mouse if mouse
          px,py = mouse if mouse_mode && mouse
        end
        target = focus_at([px,py],cfg)
        status = :free
        hint = take_notice
        if target
          spec = event_spec(target)
          local = options($game_map.map_id,spec[0],target.id)
          geom = geometry($game_player.x,$game_player.y,
                          target.x,target.y,local)
          visible = local["line_of_sight"] != "1" ||
            line_clear?($game_player.x,$game_player.y,target.x,target.y)
          status = geom[:in_range] && visible ? :ready : :blocked
          hint ||= status == :ready ? "Objetivo fijado" : "No hay trayectoria libre"
        end
        if target && !mouse_mode && dx.to_i == 0 && dy.to_i == 0
          # Magnetic target follow for keyboard and gamepad: moving Pokémon
          # don't leave a stationary reticle behind after snapping.
          px,py = screen_position(target)
        end
        center = target ? screen_position(target) : [px,py]
        hud.reticle(center[0],center[1],status)
        item = mode == :ball ? (balls[selected] && balls[selected][0]) : party[party_i]
        count = mode == :ball && item ? $bag.quantity(item) : 0
        hud.equip(balls,selected) if mode == :ball
        hud.draw(mode,item,count,target,hint)
        click = cfg["aim_mouse"] == "1" && defined?(Input::MOUSELEFT) &&
                Input.trigger?(Input::MOUSELEFT)
        release = cfg["control_mode"] == "hold" && key &&
                  held_seen && frames > 2 && !Input.press?(key)
        next unless frames > 5 && (Input.trigger?(Input::USE) || click || release)
        if click && old_mouse
          px,py = old_mouse
          target = focus_at([px,py],cfg)
        end
        item = mode == :ball ? (balls[selected] && balls[selected][0]) : party[party_i]
        next unless item
        if !target
          notice(_INTL("No hay un Pokémon OW capturable bajo la retícula."))
          capture_result(:blocked,nil,_INTL("Sin objetivo válido"),cfg)
          if cfg["allow_empty_throw"] == "1"
            projectile(mode == :ball ? item : :POKEBALL,nil,[px,py],cfg)
            $bag.remove(item,1) if mode == :ball &&
              cfg["consume_on_miss"] == "1"
          end
          break if release
          next
        end
        spec = event_spec(target)
        local = options($game_map.map_id,spec[0],target.id)
        behind = behind?($game_player.x,$game_player.y,target)
        hit_roll = mode == :ball ? rand : nil
        facing = geometry($game_player.x,$game_player.y,
                          target.x,target.y,local)[:direction]
        $game_player.instance_variable_set(:@direction,facing)
        projectile(mode == :ball ? item : :POKEBALL,target,
                   screen_position(target),local,hit_roll)
        resolve_throw(target,mode,item,local,behind,hit_roll)
        balls = ball_choices
        selected = 0 if selected >= balls.length
        break if mode == :battle || release || cfg["aim_chain"] == "0"
      end
    ensure
      hud.dispose if hud
      @aim_open = false
    end
    dispatch_battle
    dispatch_attack if respond_to?(:dispatch_attack)
    !cancelled
  end
end
