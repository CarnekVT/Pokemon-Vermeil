# frozen_string_literal: true
# Bifröst live capture: no manual Graphics.update/Input.update loops.
# Map movement and its shared 2.5D camera continue to run normally.
module BifrostCapture
  module LiveAim
    class << self
      attr_reader :session

      def active?
        !!@session
      end

      def binding(cfg,field,_fallback=nil)
        return nil unless BifrostCapture.respond_to?(:capture_action)
        BifrostCapture.capture_action(cfg,field)
      end

      def debug_reserved?(cfg)
        BifrostCapture.respond_to?(:debug_input_blocked?) &&
          BifrostCapture.debug_input_blocked?(cfg)
      end

      def start
        return false if active? || !BifrostCapture.aim_allowed?
        return false if BifrostCapture::Motion.busy?
        cfg = BifrostCapture.options
        return false if debug_reserved?(cfg)
        balls = BifrostCapture.ball_choices
        party = $player.party.select { |pkmn| pkmn && pkmn.able? }
        can_ball = cfg["capture_enabled"] == "1" && !balls.empty?
        can_battle = cfg["battle_enabled"] == "1" && !party.empty?
        if !can_ball && !can_battle
          BifrostCapture.notice(_INTL("No hay Pokémon ni Poké Balls disponibles."))
          return false
        end
        target = BifrostCapture.closest_target
        point = target ? BifrostCapture.screen_position(target) :
          [$game_player.screen_x, $game_player.screen_y-56]
        key = BifrostCapture.hotkey
        @session = {
          :map=>$game_map.map_id, :config=>cfg, :balls=>balls,
          :party=>party, :ball_index=>0, :party_index=>0,
          :mode=>(can_ball ? :ball : :battle),
          :x=>point[0].to_f, :y=>point[1].to_f,
          :target=>target, :mouse_last=>nil, :mouse_active=>false,
          :held=>!!(key && Input.press?(key)), :frames=>0,
          :ball_held=>false, :ball_frames=>0, :ball_long_done=>false
        }
        @hud = BifrostCapture::ThrowHUD.new
        BifrostCapture::Audio.play(:aim,cfg) if defined?(BifrostCapture::Audio)
        BifrostCapture.instance_variable_set(:@aim_open,true)
        true
      end

      def close
        @hud.dispose if @hud
        @hud = nil
        @session = nil
        BifrostCapture.instance_variable_set(:@aim_open,false)
      end

      def can_stay?
        return false if !$game_map || !defined?($scene) ||
                        !$scene.is_a?(Scene_Map)
        return false if $game_map.map_id != @session[:map]
        return false if $game_temp.in_battle || $game_temp.in_menu ||
                        $game_temp.message_window_showing ||
                        $game_temp.player_transferring ||
                        $game_temp.transition_processing
        true
      end

      def toggle_mode(s,cfg)
        candidate = s[:mode] == :ball ? :battle : :ball
        enabled = candidate == :battle ?
          (cfg["battle_enabled"] == "1" && !s[:party].empty?) :
          (cfg["capture_enabled"] == "1" && !s[:balls].empty?)
        if enabled
          s[:mode] = candidate
          BifrostCapture::Audio.play(:switch,cfg) if defined?(BifrostCapture::Audio)
          return true
        end
        false
      end

      def cycle_equipped(s,cfg)
        if s[:mode] == :ball && s[:balls].length > 1
          s[:ball_index] = (s[:ball_index]+1) % s[:balls].length
        elsif s[:mode] == :battle && s[:party].length > 1
          s[:party_index] = (s[:party_index]+1) % s[:party].length
        else
          return false
        end
        BifrostCapture::Audio.play(:switch,cfg) if defined?(BifrostCapture::Audio)
        true
      end

      # A short S press cycles the equipped item; holding S switches between
      # Balls and Pokémon. This uses no third key and preserves D's Ready Menu.
      def update_equipped_input(s,cfg,key)
        return unless key
        if Input.press?(key)
          unless s[:ball_held]
            s[:ball_held] = true
            s[:ball_frames] = 0
            s[:ball_long_done] = false
          end
          s[:ball_frames] += 1
          threshold = cfg["ball_hold_mode_frames"].to_i
          if threshold > 0 && s[:ball_frames] >= threshold &&
             !s[:ball_long_done]
            s[:ball_long_done] = toggle_mode(s,cfg)
          end
        elsif s[:ball_held]
          cycle_equipped(s,cfg) unless s[:ball_long_done]
          s[:ball_held] = false
          s[:ball_frames] = 0
          s[:ball_long_done] = false
        end
      end

      def cycle_target
        s = @session
        return unless s
        candidates = BifrostCapture.visible_targets.select do |e|
          spec = BifrostCapture.event_spec(e)
          cfg = BifrostCapture.options($game_map.map_id,spec[0],e.id)
          geo = BifrostCapture.geometry($game_player.x,$game_player.y,e.x,e.y,cfg)
          geo[:in_range] &&
            (cfg["line_of_sight"] != "1" ||
            BifrostCapture.line_clear?($game_player.x,$game_player.y,e.x,e.y))
        end
        candidates.sort_by! { |e|
          [($game_player.x-e.x).abs+($game_player.y-e.y).abs,e.id]
        }
        return if candidates.empty?
        index = candidates.index(s[:target]) || -1
        s[:target] = candidates[(index+1)%candidates.length]
        s[:mouse_active] = false
        s[:x],s[:y] = BifrostCapture.screen_position(s[:target])
      end

      def pointer
        s = @session
        return nil unless s
        if s[:target] && BifrostCapture.eligible_event?(s[:target]) &&
           !s[:mouse_active]
          s[:x],s[:y] = BifrostCapture.screen_position(s[:target])
        end
        [s[:x],s[:y]]
      end

      def update
        BifrostCapture::Motion.update
        if !active?
          cfg = BifrostCapture.options
          return if debug_reserved?(cfg)
          key = BifrostCapture.hotkey
          return if !key || !Input.trigger?(key)
          return unless ["always","nearby"].include?(cfg["access_mode"])
          return unless BifrostCapture.aim_allowed?
          return if cfg["access_mode"] == "nearby" &&
                    !BifrostCapture.closest_target
          start
          return
        end
        unless can_stay?
          close
          return
        end
        s = @session
        cfg = s[:config]
        return if debug_reserved?(cfg)
        s[:frames] += 1
        key = BifrostCapture.hotkey
        if Input.trigger?(Input::BACK)
          close
          return
        end
        if BifrostCapture.instance_variable_get(:@aim_interrupted)
          close
          return
        end
        mode_key = binding(cfg,"mode_key")
        ball_key = binding(cfg,"ball_key")
        target_key = binding(cfg,"target_key")
        toggle_mode(s,cfg) if mode_key && Input.trigger?(mode_key)
        update_equipped_input(s,cfg,ball_key)
        if target_key && target_key != ball_key &&
           target_key != mode_key && Input.trigger?(target_key)
          cycle_target
          BifrostCapture::Audio.play(:lock,cfg) if defined?(BifrostCapture::Audio)
        end

        # Movement arrows remain owned by Game_Player. They are NEVER
        # consumed by the aim interface. Keyboard switches locked targets
        # via an optional unique input, while mouse free-aim remains available.
        if cfg["aim_mouse"] == "1" && defined?(Mouse)
          mouse = Mouse.getMousePos
          if mouse
            old = s[:mouse_last]
            if old && (mouse[0]-old[0]).abs+(mouse[1]-old[1]).abs >= 3
              s[:mouse_active] = true
            end
            s[:mouse_last] = mouse
            if s[:mouse_active]
              s[:x],s[:y] = mouse
              s[:target] = BifrostCapture.focus_at(mouse,cfg)
            end
          end
        end

        if s[:target] && !BifrostCapture.eligible_event?(s[:target])
          s[:target] = nil
        end
        if !s[:mouse_active] && !s[:target]
          s[:target] = BifrostCapture.closest_target
        end
        point = pointer
        focus = s[:target]
        status = :free
        hint = BifrostCapture.take_notice
        if focus
          spec = BifrostCapture.event_spec(focus)
          local = BifrostCapture.options($game_map.map_id,spec[0],focus.id)
          geom = BifrostCapture.geometry($game_player.x,$game_player.y,
                                         focus.x,focus.y,local)
          clear = local["line_of_sight"] != "1" ||
                  BifrostCapture.line_clear?($game_player.x,$game_player.y,
                                             focus.x,focus.y)
          status = geom[:in_range] && clear ? :ready : :blocked
          hint ||= status == :ready ? _INTL("Listo para lanzar") :
                    _INTL("Acércate o cambia el ángulo")
        end
        mood = focus && BifrostCapture.respond_to?(:temperament_for) ?
          BifrostCapture.temperament_for(focus) : :neutral
        @hud.reticle(point[0],point[1],status,mood)
        if s[:mode] == :ball
          s[:balls] = BifrostCapture.ball_choices
          s[:ball_index] = 0 if s[:ball_index] >= s[:balls].length
        end
        item = s[:mode] == :ball ?
          (s[:balls][s[:ball_index]] && s[:balls][s[:ball_index]][0]) :
          s[:party][s[:party_index]]
        amount = s[:mode] == :ball && item ? $bag.quantity(item) : 0
        @hud.equip(s[:balls],s[:ball_index])
        @hud.draw(s[:mode],item,amount,focus,hint)

        s[:held] = true if key && Input.press?(key)
        click = cfg["aim_mouse"] == "1" && defined?(Input::MOUSELEFT) &&
                Input.trigger?(Input::MOUSELEFT)
        release = cfg["control_mode"] == "hold" && key &&
                  s[:held] && s[:frames] > 1 && !Input.press?(key)
        use = Input.trigger?(Input::USE)
        if use || click || release
          fire
          close if release || cfg["aim_chain"] == "0"
        elsif cfg["control_mode"] != "hold" && key &&
              s[:frames] > 5 && Input.trigger?(key)
          close
        end
      end

      def fire
        s = @session
        return false unless s && !BifrostCapture::Motion.busy?
        target = s[:target]
        if s[:mouse_active]
          target = BifrostCapture.focus_at([s[:x],s[:y]],s[:config])
        end
        if !target || !BifrostCapture.eligible_event?(target)
          BifrostCapture.capture_result(:blocked,nil,
            _INTL("No hay un Pokémon capturable"),s[:config])
          return false
        end
        spec = BifrostCapture.event_spec(target)
        local = BifrostCapture.options($game_map.map_id,spec[0],target.id)
        geom = BifrostCapture.geometry($game_player.x,$game_player.y,
                                        target.x,target.y,local)
        unless geom[:in_range] &&
               (local["line_of_sight"] != "1" ||
                 BifrostCapture.line_clear?($game_player.x,$game_player.y,
                                            target.x,target.y))
          BifrostCapture.capture_result(:blocked,spec[0],
            _INTL("Objetivo fuera de alcance"),local)
          return false
        end
        item = s[:mode] == :ball ?
          (s[:balls][s[:ball_index]] && s[:balls][s[:ball_index]][0]) :
          s[:party][s[:party_index]]
        return false unless item
        if s[:mode] == :ball && $bag.quantity(item).to_i <= 0
          BifrostCapture.capture_result(:blocked,spec[0],
                                        _INTL("No quedan Poké Balls"),local)
          return false
        end
        # Direction follows the locked target without interrupting walking.
        $game_player.direction = geom[:direction]
        BifrostCapture::Motion.launch(target,item,s[:mode],local)
      end
    end
  end

  module Motion
    class << self
      def busy?
        !!@flight || !!@catch
      end

      def release_resources(obj)
        return unless obj
        (obj[:sprites] || []).each do |sprite|
          next if !sprite || sprite.disposed?
          bitmap = sprite.bitmap
          sprite.dispose
          bitmap.dispose if bitmap && !bitmap.disposed? &&
            !(obj[:shared_bitmaps] || []).include?(bitmap)
        end
        (obj[:shared_bitmaps] || []).each do |bmp|
          bmp.dispose unless bmp.disposed?
        end
        viewport = obj[:vp]
        viewport.dispose if viewport && !viewport.disposed?
      end

      def cancel
        if @catch
          event = @catch[:event]
          if event && !event.instance_variable_get(:@erased)
            event.opacity = @catch[:opacity]
            event.transparent = @catch[:transparent]
            event.instance_variable_set(:@move_type,@catch[:move_type])
            event.instance_variable_set(:@bifrost_capture_lock,false)
            # Captured Pokemon was already stored when animation began.
            # If a map transfer interrupts it, remove its OW to avoid a
            # duplicate encounter on the next visit.
            if @catch[:caught]
              if BifrostCapture.generated?(event)
                BifrostCapture.erase_wild(event)
              else
                event.erase
              end
            end
          end
        end
        release_resources(@flight)
        release_resources(@catch)
        @flight = @catch = nil
        BifrostCapture.instance_variable_set(:@capture_busy,false)
        BifrostCapture::LiveAim.close if BifrostCapture::LiveAim.active?
      end

      def launch(event,item,mode,cfg)
        return false if busy? || !BifrostCapture.eligible_event?(event)
        vp = Viewport.new(0,0,Graphics.width,Graphics.height)
        vp.z = 999996
        ball = Sprite.new(vp)
        ball.bitmap = BifrostCapture.ball_bitmap(mode == :ball ? item : :POKEBALL)
        ball.ox = ball.bitmap.width/2
        ball.oy = ball.bitmap.height/2
        scale = [26.0/[ball.bitmap.width,ball.bitmap.height].max,1.0].min
        ball.zoom_x = ball.zoom_y = scale
        shadow = Sprite.new(vp)
        shadow.bitmap = Bitmap.new(32,10)
        shadow.bitmap.fill_rect(2,3,28,4,Color.new(12,18,28,94))
        shadow.ox = 16; shadow.oy = 5
        x,y,w,h = BifrostCapture.target_rect($game_player)
        geom = BifrostCapture.geometry($game_player.x,$game_player.y,
                                       event.x,event.y,cfg)
        roll = mode == :ball ? rand : nil
        miss = roll && roll >= BifrostCapture.hit_chance(geom[:front],cfg)
        trail_bmp = Bitmap.new(8,8)
        trail_bmp.fill_rect(3,0,2,8,Color.new(220,244,255,190))
        trail_bmp.fill_rect(0,3,8,2,Color.new(220,244,255,190))
        trails = Array.new(3) { |i|
          sp = Sprite.new(vp)
          sp.bitmap = trail_bmp
          sp.ox = sp.oy = 4
          sp.visible = false
          sp
        }
        BifrostCapture::Audio.play(:throw,cfg) if defined?(BifrostCapture::Audio)
        @flight = {
          :vp=>vp, :sprites=>[ball,shadow,*trails],
          :shared_bitmaps=>[trail_bmp],
          :event=>event,:item=>item,:mode=>mode,:config=>cfg,
          :back=>BifrostCapture.behind?($game_player.x,$game_player.y,event),
          :origin=>[$game_player.x,$game_player.y],
          :roll=>roll,:miss=>miss,
          :frame=>0,:frames=>cfg["throw_frames"].to_i.clamp(8,48),
          :start=>[x+w*0.72,y+h*0.50],:ground=>y+h,
          :last=>BifrostCapture.screen_position(event),
          :positions=>[]
        }
        true
      end

      def start_capture(event,item,caught,critical,cfg,species,destination)
        return false if @catch
        vp = Viewport.new(0,0,Graphics.width,Graphics.height)
        vp.z = 999997
        ball = Sprite.new(vp)
        ball.bitmap = BifrostCapture.ball_bitmap(item)
        ball.ox = ball.bitmap.width/2; ball.oy = ball.bitmap.height/2
        z = [27.0/[ball.bitmap.width,ball.bitmap.height].max,1.0].min
        ball.zoom_x = ball.zoom_y = z
        ring = Sprite.new(vp)
        ring.bitmap = Bitmap.new(64,64)
        ring.ox = ring.oy = 32
        color = caught ? Color.new(151,252,205) : Color.new(255,161,151)
        64.times do |i|
          angle = i*2*Math::PI/64
          ring.bitmap.fill_rect((32+Math.cos(angle)*23).round,
            (32+Math.sin(angle)*23).round,2,2,color)
        end
        ring.visible = false
        event.instance_variable_set(:@bifrost_capture_lock,true)
        @catch = {
          :vp=>vp,:sprites=>[ball,ring],:event=>event,:item=>item,
          :species=>species,:destination=>destination,
          :caught=>caught,:critical=>critical,:config=>cfg,
          :opacity=>event.opacity,:transparent=>event.transparent,
          :move_type=>event.instance_variable_get(:@move_type),
          :frame=>0,:zoom=>z,
          :shakes=>(critical ? 1 : cfg["capture_shakes"].to_i.clamp(1,5)),
          :phase_frames=>cfg["capture_shake_frames"].to_i.clamp(6,24)
        }
        event.instance_variable_set(:@move_type,0)
        BifrostCapture.instance_variable_set(:@capture_busy,true)
        true
      end

      def update
        if !defined?($scene) || !$scene.is_a?(Scene_Map) ||
           !$game_map || ($game_temp && $game_temp.in_battle)
          cancel if @flight || @catch
          return
        end
        update_flight if @flight
        update_catch if @catch
      end

      def update_flight
        a = @flight
        return unless a
        event = a[:event]
        a[:frame] += 1
        t = [a[:frame].to_f/a[:frames],1.0].min
        k = t*t*(3-2*t)
        if BifrostCapture.eligible_event?(event)
          a[:last] = BifrostCapture.screen_position(event)
        end
        x,y = a[:last]
        start_x,start_y = a[:start]
        bx = start_x+(x-start_x)*k
        by = start_y+(y-start_y)*k -
             Math.sin(Math::PI*t)*a[:config]["throw_arc"].to_i
        if a[:miss]
          drift = [((k-0.55)/0.45),0.0].max
          bx += drift*38
          by -= drift*9
        end
        ball,shadow,*trails = a[:sprites]
        ball.x = bx;ball.y = by;ball.angle = (t*470).to_i
        rect = BifrostCapture.target_rect(event)
        shadow.x = bx
        shadow.y = a[:ground] + ((rect[1]+rect[3])-a[:ground])*k
        shadow.opacity = (120-55*Math.sin(Math::PI*t)).to_i
        a[:positions].unshift([bx,by])
        a[:positions] = a[:positions].first(4)
        trails.each_with_index do |sp,i|
          pt = a[:positions][i+1]
          sp.visible = !!pt
          next unless pt
          sp.x,sp.y = pt
          sp.opacity = 185-i*52
        end
        return if a[:frame] < a[:frames]
        @flight = nil
        release_resources(a)
        BifrostCapture::Audio.play(:hit,a[:config]) if
          !a[:miss] && defined?(BifrostCapture::Audio)
        BifrostCapture.resolve_throw(event,a[:mode],a[:item],
                                      a[:config],a[:back],a[:roll],a[:origin])
        # A Pokémon battle is launched only after UI and animation are gone.
        if a[:mode] == :battle
          BifrostCapture::LiveAim.close if BifrostCapture::LiveAim.active?
          BifrostCapture.dispatch_battle
        end
      end

      def update_catch
        a = @catch
        return unless a
        a[:frame] += 1
        frame = a[:frame]
        event = a[:event]
        ball,ring = a[:sprites]
        x,y = BifrostCapture.screen_position(event)
        rect = BifrostCapture.target_rect(event)
        ground = rect[1]+rect[3] - 9
        ball.x = x;ball.y = ground
        absorb = a[:config]["capture_fx"] == "0" ? 1 : 10
        shake_end = absorb+6+a[:shakes]*(a[:phase_frames]+4)
        if frame <= absorb
          event.opacity = [a[:opacity] * (1-frame.to_f/absorb),0].max.to_i
          ball.zoom_x = ball.zoom_y = a[:zoom]*(0.7+0.3*frame.to_f/absorb)
          ball.y = ground-12*(1-frame.to_f/absorb)
        elsif frame <= shake_end
          event.transparent = true
          phase = (frame-absorb-7) % (a[:phase_frames]+4)
          if phase == 0 && defined?(BifrostCapture::Audio)
            BifrostCapture::Audio.play(:shake,a[:config])
          end
          if phase < a[:phase_frames]
            ball.angle = Math.sin(phase*2*Math::PI/a[:phase_frames])*15
            ball.x = x + Math.sin(phase*2*Math::PI/a[:phase_frames])*3
          else
            ball.angle = 0
          end
        else
          event.transparent = true
          ring.visible = true
          ring.x = x;ring.y = ground
          f = frame-shake_end
          ring.zoom_x = ring.zoom_y = 0.6+f*0.08
          ring.opacity = [255-18*f,0].max
          ball.opacity = [255-18*f,0].max
        end
        return unless frame >= shake_end+14
        @catch = nil
        release_resources(a)
        event.opacity = a[:opacity]
        event.transparent = a[:transparent]
        event.instance_variable_set(:@move_type,a[:move_type])
        event.instance_variable_set(:@bifrost_capture_lock,false)
        BifrostCapture.instance_variable_set(:@capture_busy,false)
        BifrostCapture.finish_capture_result(event,a[:caught],a[:critical],
          a[:species],a[:destination],a[:config])
      end
    end
  end
end

EventHandlers.add(:on_enter_map,:bifrost_live_reset,
  proc { |_old_map_id| BifrostCapture::Motion.cancel }
)
