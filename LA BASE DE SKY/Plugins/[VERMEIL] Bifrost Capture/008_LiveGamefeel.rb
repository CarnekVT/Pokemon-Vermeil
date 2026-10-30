# frozen_string_literal: true
# Bifröst live capture: no manual Graphics.update/Input.update loops.
# Map movement and its shared 2.5D camera continue to run normally.
module BifrostCapture
  UI_FLAGS = [:in_battle, :in_menu, :message_window_showing,
              :player_transferring, :transition_processing,
              :menu_calling, :ready_menu_calling, :debug_calling].freeze
  def self.ui_busy?
    return false unless $game_temp
    UI_FLAGS.any? { |flag| $game_temp.respond_to?(flag) &&
                            $game_temp.public_send(flag) }
  end

  module LiveAim
    class << self
      attr_reader :session

      def active?
        !!@session
      end

      def cooldown_remaining
        @throw_cooldown.to_i
      end

      def claim_map_input(key)
        @claimed_map_input = key
      end

      def consume_claimed_map_input?
        claimed = @claimed_map_input
        @claimed_map_input = nil
        return false unless claimed
        input = BifrostCapture.input_action(claimed) if
          BifrostCapture.respond_to?(:input_action)
        !!(input && Input.trigger?(input))
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
        cfg = BifrostCapture.options
        return false if debug_reserved?(cfg)
        balls = BifrostCapture.ball_choices
        baits = BifrostCapture.respond_to?(:bait_choices) ?
          BifrostCapture.bait_choices : []
        party = $player.party.select { |pkmn| pkmn && pkmn.able? }
        can_ball = cfg["capture_enabled"] == "1" && !balls.empty?
        can_battle = cfg["battle_enabled"] == "1" && !party.empty?
        if !can_ball && !can_battle && baits.empty?
          BifrostCapture.notice(_INTL("No hay Pokémon ni Poké Balls disponibles."))
          return false
        end
        target = BifrostCapture.closest_target
        point = target ? BifrostCapture.screen_position(target) :
          [$game_player.screen_x, $game_player.screen_y-56]
        key = BifrostCapture.hotkey
        remembered = cfg["remember_selection"] == "1" &&
                     defined?($PokemonGlobal) && $PokemonGlobal
        last_ball = remembered ? $PokemonGlobal.bifrost_last_ball : nil
        ball_index = balls.index { |entry| entry[0].to_s == last_ball.to_s } || 0
        party_index = remembered ? $PokemonGlobal.bifrost_last_party_index.to_i : 0
        party_index = party_index.clamp(0,[party.length-1,0].max)
        old_mode = remembered ? $PokemonGlobal.bifrost_last_mode.to_s : ""
        mode = if old_mode == "battle" && can_battle
                 :battle
               elsif old_mode == "ball" && can_ball
                 :ball
               else
                 can_ball ? :ball : :battle
               end
        @session = {
          :map=>$game_map.map_id, :config=>cfg, :balls=>balls,
          :baits=>baits, :bait_index=>0, :return_mode=>:ball,
          :party=>party, :ball_index=>ball_index, :party_index=>party_index,
          :mode=>mode,
          :x=>point[0].to_f, :y=>point[1].to_f,
          :target=>target, :mouse_last=>nil, :mouse_active=>false,
          :held=>!!(key && Input.press?(key)), :frames=>0,
          :shot_during_hold=>false
        }
        @hud = BifrostCapture::ThrowHUD.new
        BifrostCapture::Audio.play(:aim,cfg) if defined?(BifrostCapture::Audio)
        BifrostCapture.instance_variable_set(:@aim_open,true)
        true
      end

      def remember_selection(s)
        return unless s && s[:config]["remember_selection"] == "1"
        return unless defined?($PokemonGlobal) && $PokemonGlobal
        index = s[:ball_index].to_i
        ball = s[:balls][index] if s[:balls]
        $PokemonGlobal.bifrost_last_ball = ball[0] if ball
        $PokemonGlobal.bifrost_last_party_index = s[:party_index].to_i
        $PokemonGlobal.bifrost_last_mode =
          (s[:mode] == :bait ? (s[:return_mode] || :ball) : s[:mode]).to_s
      end

      def close
        remember_selection(@session)
        @hud.dispose if @hud
        @hud = nil
        @session = nil
        BifrostCapture.instance_variable_set(:@aim_open,false)
      end

      def can_stay?
        return false if !$game_map || !defined?($scene) ||
                        !$scene.is_a?(Scene_Map)
        return false if $game_map.map_id != @session[:map]
        return false if BifrostCapture.ui_busy?
        return false if $game_temp.respond_to?(:interact_calling) &&
                        $game_temp.interact_calling
        true
      end

      def toggle_mode(s,cfg)
        candidate = s[:mode] == :bait ? (s[:return_mode] || :ball) :
          (s[:mode] == :ball ? :battle : :ball)
        enabled = candidate == :battle ?
          (cfg["battle_enabled"] == "1" && !s[:party].empty?) :
          (cfg["capture_enabled"] == "1" && !s[:balls].empty?)
        return false unless enabled
        s[:mode] = candidate
        remember_selection(s)
        BifrostCapture::Audio.play(:mode,cfg) if defined?(BifrostCapture::Audio)
        true
      end

      def toggle_bait(s,cfg)
        if s[:mode] == :bait
          s[:mode] = s[:return_mode] || :ball
        else
          s[:baits] = BifrostCapture.respond_to?(:bait_choices) ?
            BifrostCapture.bait_choices : []
          if s[:baits].empty?
            BifrostCapture.notice(_INTL("No tienes bayas ni cebos en la mochila"))
            return false
          end
          s[:return_mode] = s[:mode]
          s[:mode] = :bait
        end
        BifrostCapture::Audio.play(:mode,cfg) if defined?(BifrostCapture::Audio)
        true
      end

      def cycle_equipped(s,cfg,step=1)
        if s[:mode] == :bait
          return false if s[:baits].empty?
          s[:bait_index] = (s[:bait_index]+step) % s[:baits].length
          BifrostCapture::Audio.play(:switch,cfg) if defined?(BifrostCapture::Audio)
        elsif s[:mode] == :ball
          return false if s[:balls].empty?
          s[:ball_index] = (s[:ball_index]+step) % s[:balls].length
          equipped = s[:balls][s[:ball_index]][0]
          $PokemonGlobal.bifrost_last_ball = equipped if
            cfg["remember_selection"] == "1" &&
            defined?($PokemonGlobal) && $PokemonGlobal
          BifrostCapture::Audio.play(:switch,cfg) if defined?(BifrostCapture::Audio)
        else
          return false if s[:party].empty?
          s[:party_index] = (s[:party_index]+step) % s[:party].length
          remember_selection(s)
          BifrostCapture::Audio.play(:party,cfg) if defined?(BifrostCapture::Audio)
        end
        true
      end

      def mouse_wheel_delta
        return 0 unless Input.respond_to?(:scroll_v)
        amount = Input.scroll_v
        return 0 unless amount.is_a?(Numeric)
        amount <=> 0
      rescue StandardError
        0
      end

      # Physical keyboard shortcuts are supplementary to F1-remappable
      # logical actions. They never intercept ordinary map movement.
      # mkxp-z supports triggerex? with SDL scancode symbols.
      def physical_key_trigger?(cfg,field)
        key = cfg[field].to_s.downcase
        return false unless %w[tab e r f t g].include?(key)
        return false unless Input.respond_to?(:triggerex?)
        Input.triggerex?(key.upcase.to_sym)
      rescue StandardError
        false
      end

      def reverse_modifier?
        return Input.press?(Input::SHIFT) if Input.const_defined?(:SHIFT)
        return false unless Input.respond_to?(:pressex?)
        Input.pressex?(:LSHIFT) || Input.pressex?(:RSHIFT)
      rescue StandardError
        false
      end

      # Prevent a keyboard shortcut from also opening menus or
      # running the player's registered/debug actions if F1 remapped it.
      def keyboard_shortcut_reserved?(aim_key,ball_key)
        keys = [:SPECIAL,:AUX1,:AUX2,:USE,:BACK]
        keys.map! { |key| Input.const_get(key) if Input.const_defined?(key) }
        keys += [aim_key,ball_key]
        keys.compact.any? { |key| Input.trigger?(key) }
      end

      def cycle_target(step=1)
        s = @session
        return false unless s
        # Include visible-but-blocked targets: show a blocked reticle rather
        # than silently skipping a Pokémon that the player can see.
        candidates = BifrostCapture.visible_targets
        candidates.sort_by! { |e|
          [($game_player.x-e.x).abs+($game_player.y-e.y).abs,e.id]
        }
        return false if candidates.empty?
        index = candidates.index(s[:target])
        index = step < 0 ? 0 : -1 if index.nil?
        next_target = candidates[(index+step)%candidates.length]
        changed = !s[:target].equal?(next_target)
        s[:target] = next_target
        s[:mouse_active] = false
        s[:x],s[:y] = BifrostCapture.screen_position(next_target)
        changed
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
        @throw_cooldown = [@throw_cooldown.to_i-1,0].max
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
          claim_map_input("back")
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
        mouse_mode = cfg["aim_mouse"] == "1" &&
                     cfg["mouse_right_mode"] == "1" &&
                     Input.const_defined?(:MOUSERIGHT) &&
                     Input.trigger?(Input::MOUSERIGHT)
        keyboard_safe = !keyboard_shortcut_reserved?(key,ball_key)
        keyboard_mode = keyboard_safe &&
                        physical_key_trigger?(cfg,"keyboard_mode_key")
        # The selection action must NEVER double as a mode switch.
        # In particular, a legacy INI may map mode_key to jumpdown/S.
        logical_mode = mode_key && mode_key != ball_key &&
                       Input.trigger?(mode_key)
        toggle_mode(s,cfg) if logical_mode || mouse_mode || keyboard_mode
        bait_shortcut = keyboard_safe &&
                        cfg["keyboard_bait_key"] != cfg["keyboard_mode_key"] &&
                        cfg["keyboard_bait_key"] != cfg["keyboard_target_key"] &&
                        physical_key_trigger?(cfg,"keyboard_bait_key")
        toggle_bait(s,cfg) if bait_shortcut
        # One item per new press, regardless of how long the key is held.
        # Shift reverses the cycling direction. E or right click toggles mode.
        if ball_key && Input.trigger?(ball_key)
          cycle_equipped(s,cfg,reverse_modifier? ? -1 : 1)
        end
        if cfg["mouse_wheel_select"] == "1"
          delta = mouse_wheel_delta
          cycle_equipped(s,cfg,delta > 0 ? -1 : 1) if delta != 0
        end
        keyboard_target = keyboard_safe &&
                          cfg["keyboard_target_key"] != cfg["keyboard_mode_key"] &&
                          physical_key_trigger?(cfg,"keyboard_target_key")
        logical_target = target_key && target_key != ball_key &&
                         target_key != mode_key && Input.trigger?(target_key)
        if keyboard_target || logical_target
          changed = cycle_target(reverse_modifier? ? -1 : 1)
          if changed && defined?(BifrostCapture::Audio)
            BifrostCapture::Audio.play(:lock,cfg)
          end
        end

        # Movement arrows remain owned by Game_Player. They are NEVER
        # consumed by the aim interface. Tab changes targets; E changes
        # Ball/Team, both only while aiming. Mouse free-aim stays optional.
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
        hint ||= _INTL("Preparando otra Poké Ball") if
          @throw_cooldown.to_i > 0 && s[:mode] == :ball
        if focus
          spec = BifrostCapture.event_spec(focus)
          local = BifrostCapture.options($game_map.map_id,spec[0],focus.id)
          geom = BifrostCapture.geometry($game_player.x,$game_player.y,
                                         focus.x,focus.y,local)
          clear = local["line_of_sight"] != "1" ||
                  BifrostCapture.line_clear?($game_player.x,$game_player.y,
                                             focus.x,focus.y)
          status = geom[:in_range] && clear ? :ready : :blocked
          if status == :ready && s[:mode] == :ball && defined?(Pressure) &&
             Pressure.locked?(focus,local)
            status = :max_alert
          elsif status == :ready && s[:mode] == :ball &&
                BifrostCapture.behind?($game_player.x,$game_player.y,focus)
            status = :backstrike
          end
          hint ||= status == :max_alert ? _INTL("¡ALERTA MÁXIMA! Combate o usa R: cebo") :
                    status == :backstrike ? _INTL("¡Captura por sorpresa!") :
                    status == :ready ? _INTL("Listo para lanzar") :
                    _INTL("Acércate o cambia el ángulo")
        end
        mood = focus && BifrostCapture.respond_to?(:temperament_for) ?
          BifrostCapture.temperament_for(focus) : :neutral
        @hud.reticle(point[0],point[1],status,mood)
        if s[:mode] == :ball
          s[:balls] = BifrostCapture.ball_choices
          if s[:ball_index] >= s[:balls].length
            s[:ball_index] = 0
            remember_selection(s)
          end
        end
        if s[:mode] == :bait
          s[:baits] = BifrostCapture.respond_to?(:bait_choices) ?
            BifrostCapture.bait_choices : []
          s[:bait_index] = 0 if s[:bait_index] >= s[:baits].length
        end
        item = case s[:mode]
        when :ball then s[:balls][s[:ball_index]] && s[:balls][s[:ball_index]][0]
        when :bait then s[:baits][s[:bait_index]] && s[:baits][s[:bait_index]][0]
        else s[:party][s[:party_index]]
        end
        amount = [:ball,:bait].include?(s[:mode]) && item ? $bag.quantity(item) : 0
        @hud.equip(s[:mode] == :bait ? s[:baits] : s[:balls],
          s[:mode] == :bait ? s[:bait_index] : s[:ball_index])
        @hud.draw(s[:mode],item,amount,focus,hint,
                  s[:party],s[:party_index])

        s[:held] = true if key && Input.press?(key)
        click = cfg["aim_mouse"] == "1" && defined?(Input::MOUSELEFT) &&
                Input.trigger?(Input::MOUSELEFT)
        release = cfg["control_mode"] == "hold" && key &&
                  s[:held] && s[:frames] > 1 && !Input.press?(key)
        use = Input.trigger?(Input::USE)
        if release
          fire unless s[:shot_during_hold]
          close
        elsif use || click
          claim_map_input("use") if use
          success = fire
          close if success && cfg["aim_chain"] == "0"
        elsif cfg["control_mode"] != "hold" && key &&
              s[:frames] > 5 && Input.trigger?(key)
          close
        end
      end

      def fire
        s = @session
        return false unless s
        if [:ball,:bait].include?(s[:mode]) && @throw_cooldown.to_i > 0
          BifrostCapture.notice(_INTL("La Poké Ball se está preparando")) if
            @throw_cooldown.to_i == 1
          return false
        end
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
        if s[:mode] == :ball && defined?(Pressure) && Pressure.locked?(target,local)
          BifrostCapture.capture_result(:blocked,spec[0],
            _INTL("¡Alerta máxima! Usa el combate tradicional"),local)
          return false
        end
        item = case s[:mode]
        when :ball then s[:balls][s[:ball_index]] && s[:balls][s[:ball_index]][0]
        when :bait then s[:baits][s[:bait_index]] && s[:baits][s[:bait_index]][0]
        else s[:party][s[:party_index]]
        end
        return false unless item
        remember_selection(s)
        if [:ball,:bait].include?(s[:mode]) && $bag.quantity(item).to_i <= 0
          BifrostCapture.capture_result(:blocked,spec[0],
                                        _INTL("No quedan Poké Balls"),local)
          return false
        end
        unless BifrostCapture::Motion.can_launch?(target,item,s[:mode],local)
          BifrostCapture.notice(_INTL("Espera un instante o cambia de objetivo"))
          return false
        end
        # Direction follows the locked target without interrupting walking.
        $game_player.direction = geom[:direction]
        launched = BifrostCapture::Motion.launch(target,item,s[:mode],local)
        if launched
          s[:shot_during_hold] = true
          @throw_cooldown = local["throw_cooldown_frames"].to_i.clamp(0,90) if
            [:ball,:bait].include?(s[:mode])
          s[:target] = BifrostCapture.closest_target
          s[:mouse_active] = false
          remember_selection(s)
        end
        launched
      end
    end
  end

  module Motion
    class << self
      def flights
        @flights ||= []
      end

      def catches
        @catches ||= []
      end

      def busy?
        !flights.empty? || !catches.empty? || !!@flight || !!@catch
      end

      def can_launch?(event,item,mode,cfg)
        return false unless event && BifrostCapture.eligible_event?(event)
        return false if event.instance_variable_get(:@bifrost_projectile_lock) ||
                        event.instance_variable_get(:@bifrost_capture_lock)
        return false if mode == :ball && defined?(BifrostCapture::Pressure) &&
          BifrostCapture::Pressure.locked?(event,cfg)
        return false if mode == :battle && busy?
        return false if flights.any? { |a| a[:mode] == :battle }
        return false if flights.length >= cfg["max_flights"].to_i.clamp(1,6)
        if [:ball,:bait].include?(mode)
          reserved = flights.count { |a|
            a[:mode] == mode && a[:item] == item
          }
          return false if !$bag || $bag.quantity(item).to_i <= reserved
        end
        true
      end

      # Share the world viewport with tilemap, character sprites and
      # Visual 2.5D. Independent always-on-top viewports ignore tile priority.
      def map_viewport
        if defined?(Spriteset_Map) && Spriteset_Map.respond_to?(:viewport)
          vp = Spriteset_Map.viewport
          return [vp,false] if vp && !vp.disposed?
        end
        [Viewport.new(0,0,Graphics.width,Graphics.height),true]
      end

      def depth_for(character)
        return 0 unless character && character.respond_to?(:screen_z)
        character.screen_z
      rescue StandardError
        0
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
        viewport.dispose if obj[:owns_vp] && viewport && !viewport.disposed?
      end

      # Cancel every visual effect when a scene changes. Captured entities
      # were committed to storage at impact: never restore duplicates.
      def cancel
        (flights + [@flight].compact).each do |a|
          event = a[:event]
          event.instance_variable_set(:@bifrost_projectile_lock,false) if event
          release_resources(a)
        end
        (catches + [@catch].compact).each do |a|
          event = a[:event]
          if event && !event.instance_variable_get(:@erased)
            event.opacity = a[:opacity]
            event.transparent = a[:transparent]
            event.instance_variable_set(:@move_type,a[:move_type])
            event.instance_variable_set(:@bifrost_capture_lock,false)
            if a[:caught]
              if BifrostCapture.generated?(event)
                BifrostCapture.erase_wild(event)
              else
                BifrostCapture.remove_event(event)
              end
            end
          end
          release_resources(a)
        end
        @flights = []
        @catches = []
        @flight = @catch = nil
        BifrostCapture.instance_variable_set(:@capture_busy,false)
        BifrostCapture::LiveAim.close if BifrostCapture::LiveAim.active?
      end

      def launch(event,item,mode,cfg)
        return false unless can_launch?(event,item,mode,cfg)
        vp,owns_vp = map_viewport
        ball = Sprite.new(vp)
        if mode == :bait
          filename = pbResolveBitmap("Graphics/Items/#{item}")
          ball.bitmap = filename ? Bitmap.new(filename) :
            BifrostCapture.ball_bitmap(:POKEBALL)
        else
          ball.bitmap = BifrostCapture.ball_bitmap(mode == :ball ? item : :POKEBALL)
        end
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
        back = BifrostCapture.behind?($game_player.x,$game_player.y,event)
        critical = false
        if mode == :ball
          rate = back ? cfg["critical_back"] : cfg["critical_front"]
          critical = !miss && rand < rate.to_f/100.0
        end
        trail_bmp = Bitmap.new(8,8)
        trail_color = critical ? Color.new(154,250,255,230) :
                                 Color.new(220,244,255,190)
        trail_bmp.fill_rect(3,0,2,8,trail_color)
        trail_bmp.fill_rect(0,3,8,2,trail_color)
        trails = Array.new(3) { |i|
          sp = Sprite.new(vp)
          sp.bitmap = trail_bmp
          sp.ox = sp.oy = 4
          sp.visible = false
          sp
        }
        if defined?(BifrostCapture::Audio)
          BifrostCapture::Audio.play(:throw,cfg)
          BifrostCapture::Audio.play(:critical,cfg) if critical
        end
        ball.color = Color.new(126,246,255,75) if critical
        event.instance_variable_set(:@bifrost_projectile_lock,true)
        a = {
          :vp=>vp,:owns_vp=>owns_vp, :sprites=>[ball,shadow,*trails],
          :shared_bitmaps=>[trail_bmp],
          :event=>event,:item=>item,:mode=>mode,:config=>cfg,
          :back=>back, :critical=>critical,
          :origin=>[$game_player.x,$game_player.y],
          :roll=>roll,:miss=>miss,
          :frame=>0,:frames=>cfg["throw_frames"].to_i.clamp(8,48),
          :start=>[x+w*0.72,y+h*0.50],:ground=>y+h,
          :start_depth=>depth_for($game_player),
          :last=>BifrostCapture.screen_position(event),
          :positions=>[]
        }
        flights << a
        true
      end

      def start_capture(event,item,caught,critical,cfg,species,destination)
        return false if catches.any? { |a| a[:event].equal?(event) }
        vp,owns_vp = map_viewport
        ball = Sprite.new(vp)
        ball.bitmap = BifrostCapture.ball_bitmap(item)
        # Pivot is the BOTTOM of the ball for rocking on the ground.
        ball.ox = ball.bitmap.width/2; ball.oy = ball.bitmap.height
        z = [27.0/[ball.bitmap.width,ball.bitmap.height].max,1.0].min
        ball.zoom_x = ball.zoom_y = z
        ring = Sprite.new(vp)
        ring.bitmap = Bitmap.new(64,64)
        ring.ox = ring.oy = 32
        color = critical ? Color.new(138,247,255) :
                caught ? Color.new(151,252,205) : Color.new(255,161,151)
        64.times do |i|
          angle = i*2*Math::PI/64
          ring.bitmap.fill_rect((32+Math.cos(angle)*23).round,
            (32+Math.sin(angle)*23).round,2,2,color)
        end
        ring.visible = false
        event.instance_variable_set(:@bifrost_capture_lock,true)
        a = {
          :vp=>vp,:owns_vp=>owns_vp,:sprites=>[ball,ring],
          :event=>event,:item=>item,
          :species=>species,:destination=>destination,
          :caught=>caught,:critical=>critical,:config=>cfg,
          :opacity=>event.opacity,:transparent=>event.transparent,
          :move_type=>event.instance_variable_get(:@move_type),
          :frame=>0,:zoom=>z,
          :shakes=>(critical ? 1 : cfg["capture_shakes"].to_i.clamp(1,5)),
          :phase_frames=>cfg["capture_shake_frames"].to_i.clamp(6,24)
        }
        event.instance_variable_set(:@move_type,0)
        catches << a
        BifrostCapture.instance_variable_set(:@capture_busy,true)
        if critical && defined?(BifrostCapture::Audio)
          BifrostCapture::Audio.play(:lock,cfg)
        end
        true
      end

      def update
        menu_block = BifrostCapture.ui_busy?
        if !defined?($scene) || !$scene.is_a?(Scene_Map) ||
           !$game_map || menu_block
          cancel if busy?
          return
        end
        flights.dup.each { |a| update_flight(a) }
        catches.dup.each { |a| update_catch(a) }
      end

      def update_flight(a)
        return unless flights.include?(a)
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
        origin_z = a[:start_depth]
        target_z = depth_for(event)
        ball.z = (origin_z+(target_z-origin_z)*k).to_i + 1
        rect = BifrostCapture.target_rect(event)
        shadow.x = bx
        shadow.y = a[:ground] + ((rect[1]+rect[3])-a[:ground])*k
        shadow.opacity = (120-55*Math.sin(Math::PI*t)).to_i
        shadow.z = ball.z - 2
        a[:positions].unshift([bx,by])
        a[:positions] = a[:positions].first(4)
        trails.each_with_index do |sp,i|
          pt = a[:positions][i+1]
          sp.visible = !!pt
          next unless pt
          sp.x,sp.y = pt
          sp.z = ball.z - 1
          sp.opacity = 185-i*52
        end
        return if a[:frame] < a[:frames]
        flights.delete(a)
        event.instance_variable_set(:@bifrost_projectile_lock,false) if event
        release_resources(a)
        if !a[:miss] && a[:mode] == :ball && a[:back] &&
           BifrostCapture.eligible_event?(event)
          if defined?(BifrostCapture::Feedback)
            spec = BifrostCapture.event_spec(event)
            BifrostCapture::Feedback.publish(:backstrike,spec && spec[0],
              _INTL("Impacto por sorpresa"),a[:config])
          end
          event.jump(0,0) if event.respond_to?(:jump) &&
            (!event.respond_to?(:jumping?) || !event.jumping?)
        end
        BifrostCapture::Audio.play(:hit,a[:config]) if
          !a[:miss] && defined?(BifrostCapture::Audio)
        if a[:mode] == :bait
          BifrostCapture.resolve_bait(event,a[:item],a[:config]) if
            BifrostCapture.respond_to?(:resolve_bait)
        else
          BifrostCapture.resolve_throw(event,a[:mode],a[:item],
                                        a[:config],a[:back],a[:roll],a[:origin],
                                        a[:critical])
        end
        # A Pokémon battle is launched only after UI and animation are gone.
        if a[:mode] == :battle
          BifrostCapture::LiveAim.close if BifrostCapture::LiveAim.active?
          BifrostCapture.dispatch_battle
        end
      end

      def update_catch(a)
        return unless catches.include?(a)
        a[:frame] += 1
        frame = a[:frame]
        event = a[:event]
        ball,ring = a[:sprites]
        x,y = BifrostCapture.screen_position(event)
        rect = BifrostCapture.target_rect(event)
        ground = rect[1]+rect[3]
        ball.x = x;ball.y = ground
        # Depth is anchored at the Pokémon's feet, not an overlay z.
        ball.z = depth_for(event) + 1
        ring.z = ball.z + 1
        absorb = a[:config]["capture_fx"] == "0" ? 1 : (a[:critical] ? 16 : 10)
        shake_end = absorb+6+a[:shakes]*(a[:phase_frames]+4)
        if frame <= absorb
          if a[:critical]
            ring.visible = true
            ring.x = x;ring.y = ground-8
            ring.zoom_x = ring.zoom_y = 0.65+1.2*frame.to_f/absorb
            ring.opacity = (220*(1.0-frame.to_f/absorb)).to_i
          end
          event.opacity = [a[:opacity] * (1-frame.to_f/absorb),0].max.to_i
          ball.zoom_x = ball.zoom_y = a[:zoom]*(0.7+0.3*frame.to_f/absorb)
          # The ball remains planted at the bottom, even during absorption.
          ball.y = ground
        elsif frame <= shake_end
          ring.visible = false
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
        catches.delete(a)
        release_resources(a)
        event.opacity = a[:opacity]
        event.transparent = a[:transparent]
        event.instance_variable_set(:@move_type,a[:move_type])
        event.instance_variable_set(:@bifrost_capture_lock,false)
        BifrostCapture.instance_variable_set(:@capture_busy,!catches.empty?)
        BifrostCapture.finish_capture_result(event,a[:caught],a[:critical],
          a[:species],a[:destination],a[:config])
      end
    end
  end
end

EventHandlers.add(:on_enter_map,:bifrost_live_reset,
  proc { |_old_map_id| BifrostCapture::Motion.cancel }
)
