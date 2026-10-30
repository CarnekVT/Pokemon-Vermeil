# frozen_string_literal: true
# Shiny Pokémon OW: short entrance burst, audible cue, quiet periodic twinkles.
# Uses Spriteset_Map's shared viewport (2.5D-safe), never a topmost HUD layer.
# Sprites and shared bitmaps are created lazily and reused across frames.
module BifrostCapture
  module ShinySignals
    class << self
      def shiny?(event)
        return false unless event
        pkmn = event.instance_variable_get(:@bifrost_wild_pokemon)
        !!(pkmn && pkmn.respond_to?(:shiny?) && pkmn.shiny?)
      end

      def state_for(event)
        @states ||= {}
        @states[event.object_id] ||= {
          :event=>event, :age=>0, :announced=>false, :burst=>0,
          :sprites=>[], :halo=>nil, :last_repeat=>0
        }
      end

      # Called at a natural spawn and when the test switch forces a shiny.
      # Presentation waits until the Pokémon finishes emerging on the map.
      def on_spawn(event,cfg=nil)
        return false unless shiny?(event)
        state = state_for(event)
        state[:announced] = false
        state[:burst] = 0
        state[:age] = 0
        true
      end

      def forget(event)
        return unless event && @states
        state = @states.delete(event.object_id)
        release_state(state)
      end

      def release_state(state)
        return unless state
        (state[:sprites] || []).each do |sprite|
          sprite.dispose if sprite && !sprite.disposed?
        end
        halo = state[:halo]
        halo.dispose if halo && !halo.disposed?
        state[:sprites] = []
        state[:halo] = nil
      end

      def reset
        (@states || {}).each_value { |state| release_state(state) }
        @states = {}
        (@bitmaps || {}).each_value do |bitmap|
          bitmap.dispose if bitmap && !bitmap.disposed?
        end
        @bitmaps = {}
        @viewport = nil
        @frame = 0
        @last_sound_frame = nil
      end

      # Small original pixel-art assets, not extracted from Legends games.
      def star_bitmap(index)
        @bitmaps ||= {}
        key = index.even? ? :gold_star : :ice_star
        existing = @bitmaps[key]
        return existing if existing && !existing.disposed?
        bmp = Bitmap.new(23,23)
        outer = key == :gold_star ? Color.new(255,210,102,95) :
                                   Color.new(123,230,255,95)
        middle = key == :gold_star ? Color.new(255,229,156,210) :
                                    Color.new(190,246,255,210)
        white = Color.new(255,255,243,255)
        bmp.fill_rect(9,2,5,19,outer)
        bmp.fill_rect(2,9,19,5,outer)
        bmp.fill_rect(10,4,3,15,middle)
        bmp.fill_rect(4,10,15,3,middle)
        [5,17].each do |n|
          bmp.fill_rect(n,n,2,2,middle)
          bmp.fill_rect(n,22-n,2,2,middle)
        end
        bmp.fill_rect(10,10,3,3,white)
        @bitmaps[key] = bmp
      end

      def halo_bitmap
        @bitmaps ||= {}
        bmp = @bitmaps[:halo]
        return bmp if bmp && !bmp.disposed?
        bmp = Bitmap.new(66,66)
        64.times do |i|
          angle = 2.0*Math::PI*i/64
          for radius,color in [
            [23,Color.new(255,217,142,175)],
            [24,Color.new(254,240,195,80)],
            [25,Color.new(143,220,251,70)]
          ]
            xx = (33+radius*Math.cos(angle)).round
            yy = (33+radius*Math.sin(angle)).round
            bmp.fill_rect(xx,yy,2,2,color)
          end
        end
        @bitmaps[:halo] = bmp
      end

      def map_viewport
        return nil unless defined?(Spriteset_Map) &&
                          Spriteset_Map.respond_to?(:viewport)
        vp = Spriteset_Map.viewport
        return nil unless vp && !vp.disposed?
        if @viewport && !@viewport.equal?(vp)
          (@states || {}).each_value { |state| release_state(state) }
        end
        @viewport = vp
        vp
      end

      def ensure_sprites(state,vp,count)
        sprites = state[:sprites]
        while sprites.length < count
          index = sprites.length
          sprite = Sprite.new(vp)
          sprite.bitmap = star_bitmap(index)
          sprite.ox = 11
          sprite.oy = 11
          sprite.opacity = 0
          sprite.blend_type = 1 if sprite.respond_to?(:blend_type=)
          sprites << sprite
        end
        if !state[:halo] || state[:halo].disposed?
          state[:halo] = Sprite.new(vp)
          state[:halo].bitmap = halo_bitmap
          state[:halo].ox = 33
          state[:halo].oy = 33
          state[:halo].visible = false
          state[:halo].blend_type = 1 if state[:halo].respond_to?(:blend_type=)
        end
      end

      def notify_if_needed(state,cfg)
        return if state[:announced]
        state[:announced] = true
        state[:burst] = 46
        # Throttle overlapping spawns in debug (not a sound every frame).
        if @last_sound_frame.nil? || @frame-@last_sound_frame >= 45
          if defined?(BifrostCapture::Audio) && cfg["shiny_sound_enabled"] != "0"
            BifrostCapture::Audio.play(:shiny,cfg)
          end
          @last_sound_frame = @frame
        end
      end

      def render_state(state,cfg,vp)
        event = state[:event]
        count = cfg["shiny_fx_intensity"].to_i.clamp(1,3)+1
        ensure_sprites(state,vp,count)
        age = state[:age]
        state[:burst] = [state[:burst]-1,0].max
        x,y,w,h = BifrostCapture.target_rect(event)
        alpha = event.respond_to?(:opacity) ? event.opacity.to_i.clamp(0,255) : 255
        z = event.respond_to?(:screen_z) ? event.screen_z+2 : 2
        period = cfg["shiny_pulse_frames"].to_i.clamp(80,360)
        anchors = [[-0.31,0.30],[0.34,0.14],[-0.06,-0.05],[0.21,0.58]]
        state[:sprites].each_with_index do |sprite,index|
          t = (age+index*(period/count)) % period
          burst = state[:burst] > 0
          # Short fading twinkles instead of a permanent obstructing halo.
          visible = burst || t < 30
          sprite.visible = visible
          next unless visible
          ax,ay = anchors[index]
          drift = burst ? (46-state[:burst])*0.16 : t*0.10
          sprite.x = (x+w*(0.5+ax)).round
          sprite.y = (y+h*ay-drift).round
          sprite.z = z
          wave = burst ? (state[:burst].to_f/46.0) :
                         Math.sin(Math::PI*t/30.0)
          sprite.opacity = (alpha*wave*(burst ? 0.96 : 0.72)).round.clamp(0,255)
          size = (burst ? 0.68+0.36*wave : 0.46+0.24*wave)
          sprite.zoom_x = sprite.zoom_y = size
        end
        halo = state[:halo]
        burst = state[:burst]
        halo.visible = burst > 0
        if burst > 0
          t = (46-burst).to_f/46.0
          halo.x = (x+w/2).round
          halo.y = (y+h*0.48).round
          halo.z = z-1
          halo.zoom_x = halo.zoom_y = (0.32+0.88*t)*[w/32.0,0.70].max
          halo.opacity = (alpha*0.76*Math.sin(Math::PI*t)).round.clamp(0,255)
        end
      end

      def update
        return reset unless defined?($scene) && $scene.is_a?(Scene_Map) &&
                            $game_map && (!defined?($game_temp) ||
                            !$game_temp || !$game_temp.in_battle)
        @frame = @frame.to_i+1
        states = @states ||= {}
        states.keys.each do |key|
          event = states[key][:event]
          forget(event) unless $game_map.events[event.id].equal?(event) &&
                                !event.instance_variable_get(:@erased) &&
                                shiny?(event)
        end
        # One-pass visibility selection; avoid walking all map sprites twice.
        targets = BifrostCapture.visible_targets
        return if targets.empty? && states.empty?
        vp = map_viewport
        return unless vp
        onscreen = {}
        targets.each do |event|
          next unless shiny?(event)
          next if event.respond_to?(:transparent) && event.transparent
          next if event.respond_to?(:opacity) && event.opacity.to_i < 35
          cfg = BifrostCapture.options($game_map.map_id,
            BifrostCapture.event_spec(event)[0],event.id)
          state = state_for(event)
          onscreen[event.object_id] = true
          notify_if_needed(state,cfg)
          state[:age] += 1
          if cfg["shiny_fx_enabled"] == "1"
            render_state(state,cfg,vp)
          else
            release_state(state)
          end
          if cfg["shiny_repeat_sound"] == "1" &&
             state[:age] - state[:last_repeat] >= 720
            state[:last_repeat] = state[:age]
            if @last_sound_frame.nil? || @frame-@last_sound_frame >= 90
              BifrostCapture::Audio.play(:shiny,cfg) if defined?(BifrostCapture::Audio) &&
                cfg["shiny_sound_enabled"] != "0"
              @last_sound_frame = @frame
            end
          end
        end
        states.each do |key,state|
          next if onscreen[key]
          (state[:sprites] || []).each { |sp| sp.visible = false if !sp.disposed? }
          state[:halo].visible = false if state[:halo] && !state[:halo].disposed?
        end
      rescue StandardError
        # Cosmetic effects should never interrupt the game's map update.
        reset
      end
    end
  end
end

EventHandlers.add(:on_frame_update,:bifrost_shiny_signals,
  proc { BifrostCapture::ShinySignals.update }
)
EventHandlers.add(:on_enter_map,:bifrost_shiny_signals_reset,
  proc { |_old| BifrostCapture::ShinySignals.reset }
)
