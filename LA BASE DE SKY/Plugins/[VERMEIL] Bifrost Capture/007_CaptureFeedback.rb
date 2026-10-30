# frozen_string_literal: true
# Bifröst: independent, non-modal capture confirmation + Legends-inspired feedback.
# Display remains alive after aim mode has been closed.
module BifrostCapture
  module Feedback
    COLORS = {
      :caught   => [Color.new(28, 77, 65), Color.new(136, 244, 186)],
      :critical => [Color.new(38, 81, 87), Color.new(150, 242, 255)],
      :breakout => [Color.new(97, 49, 49), Color.new(255, 171, 156)],
      :miss     => [Color.new(91, 65, 35), Color.new(255, 219, 142)],
      :blocked  => [Color.new(65, 67, 78), Color.new(197, 203, 215)],
      :escape   => [Color.new(72, 53, 91), Color.new(221, 179, 255)]
    }.freeze
    TITLES = {
      :caught   => "¡CAPTURADO!",
      :critical => "¡CAPTURA CRÍTICA!",
      :breakout => "¡SE HA LIBERADO!",
      :miss     => "¡LANZAMIENTO FALLIDO!",
      :blocked  => "SIN OBJETIVO",
      :escape   => "¡POKÉMON ESCAPÓ!"
    }.freeze

    class << self
      attr_reader :last_result

      def publish(kind, species = nil, detail = nil, cfg = nil)
        cfg ||= BifrostCapture.options
        return unless cfg["feedback_enabled"] != "0"
        @last_result = {
          :kind=>kind, :species=>species, :detail=>detail.to_s,
          :frames=>cfg["feedback_frames"].to_i.clamp(45,300),
          :max_frames=>cfg["feedback_frames"].to_i.clamp(45,300)
        }
        redraw
        play_sfx(kind, cfg)
        @last_result
      end

      def reset
        @last_result = nil
        dispose
      end

      def update
        return unless @last_result
        return unless defined?($scene) && $scene.is_a?(Scene_Map)
        ensure_sprite
        @last_result[:frames] -= 1
        remaining = @last_result[:frames]
        if remaining <= 0
          reset
          return
        end
        @toast.opacity = [255, remaining*14].min
        @toast.y = 10 - [(@last_result[:max_frames] - remaining) / 5, 5].min
      end

      def ensure_sprite
        return if @toast && !@toast.disposed?
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 999999
        @toast = Sprite.new(@viewport)
        @toast.bitmap = Bitmap.new([Graphics.width - 24, 360].min, 76)
        @toast.x = (Graphics.width - @toast.bitmap.width) / 2
        @toast.y = 10
      end

      def redraw
        ensure_sprite
        bmp = @toast.bitmap
        bmp.clear
        result = @last_result
        bg, accent = COLORS[result[:kind]] || COLORS[:blocked]
        # Dark neutral surface with a single status-colored edge and small icon.
        bmp.fill_rect(0, 0, bmp.width, 68, Color.new(12, 18, 29, 226))
        bmp.fill_rect(0, 0, 5, 68, accent)
        bmp.fill_rect(6, 0, bmp.width-6, 2, bg)
        bmp.fill_rect(14, 11, 42, 42, bg)
        # Use existing Pokémon icon sheets from Vermeil, not synthetic art.
        icon = species_icon(result[:species])
        if icon
          source_width = icon.width > icon.height ? icon.width / 2 : icon.width
          bmp.stretch_blt(Rect.new(15,11,40,40),icon,
            Rect.new(0,0,source_width,icon.height))
        else
          bmp.fill_rect(21, 19, 24, 24, accent)
          if [:caught,:critical].include?(result[:kind])
            bmp.fill_rect(25,30,6,3,Color.new(20,40,39))
            bmp.fill_rect(30,35,4,3,Color.new(20,40,39))
            bmp.fill_rect(34,28,4,10,Color.new(20,40,39))
          elsif result[:kind] == :breakout || result[:kind] == :miss
            bmp.fill_rect(27,23,5,12,Color.new(50,29,29))
            bmp.fill_rect(27,38,5,4,Color.new(50,29,29))
          end
        end
        bmp.font.size = 20
        bmp.font.bold = true
        bmp.font.color = accent
        bmp.draw_text(60, 7, bmp.width-70, 29, TITLES[result[:kind]] || "BIFRÖST")
        bmp.font.bold = false
        bmp.font.size = 14
        bmp.font.color = Color.new(235, 242, 248)
        species = result[:species]
        name = if species
          begin GameData::Species.get(species).name rescue species.to_s end
        end
        summary = [name, result[:detail]].reject { |s| s.nil? || s.empty? }.join("  ·  ")
        bmp.draw_text(60, 37, bmp.width-68, 22, summary)
      end

      def species_icon(species)
        return nil unless species
        return @icon_bitmap if @icon_species == species && @icon_bitmap &&
                               !@icon_bitmap.disposed?
        if @icon_bitmap && !@icon_bitmap.disposed?
          @icon_bitmap.dispose
        end
        @icon_bitmap = nil
        @icon_species = species
        file = pbResolveBitmap("Graphics/Pokemon/Icons/#{species}")
        @icon_bitmap = Bitmap.new(file) if file
        @icon_bitmap
      rescue StandardError
        nil
      end

      def play_sfx(kind, cfg)
        return if cfg["feedback_sfx"] == "0"
        return unless defined?(pbSEPlay)
        name = case kind
          when :caught,:critical then "Battle capture success"
          when :breakout then "Battle ball shake"
          when :miss then "Battle ball drop"
          else nil
        end
        pbSEPlay(name) if name
      rescue StandardError
        # Sound packs are optional; a missing SE must never invalidate capture.
      end

      def dispose
        @icon_bitmap.dispose if @icon_bitmap && !@icon_bitmap.disposed?
        @icon_bitmap = nil
        @icon_species = nil
        if @toast && !@toast.disposed?
          bitmap = @toast.bitmap
          @toast.dispose
          bitmap.dispose if bitmap && !bitmap.disposed?
        end
        @toast = nil
        if @viewport && !@viewport.disposed?
          @viewport.dispose
        end
        @viewport = nil
      end
    end
  end

  # Capture state machine: absorb -> land -> anticipation -> distinct shakes
  # -> success burst or breakout. No blocking pbMessage or battle scene.
  def self.animate_catch(event, item, caught, critical, cfg)
    return unless event
    @capture_busy = true
    viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
    viewport.z = 999997
    ball = Sprite.new(viewport)
    ball.bitmap = ball_bitmap(item)
    ball.ox = ball.bitmap.width / 2
    ball.oy = ball.bitmap.height / 2
    zoom = [28.0 / [ball.bitmap.width, ball.bitmap.height].max, 1.0].min
    ball.zoom_x = ball.zoom_y = zoom
    ring = Sprite.new(viewport)
    ring.bitmap = Bitmap.new(72,72)
    ring.ox = ring.oy = 36
    # Pulse ring traced with bright dots, not a full-screen flash.
    80.times do |i|
      angle = i * 2 * Math::PI / 80
      x = 36 + Math.cos(angle) * 28
      y = 36 + Math.sin(angle) * 28
      ring.bitmap.fill_rect(x.round, y.round, 2, 2, Color.new(156, 230, 255))
    end
    orig_alpha = event.opacity
    orig_hidden = event.transparent
    orig_move = event.instance_variable_get(:@move_type)
    event.instance_variable_set(:@bifrost_capture_lock,true)
    event.instance_variable_set(:@move_type,0)
    begin
      x,y = screen_position(event)
      ground = target_rect(event)
      ground_y = ground[1] + ground[3] - 8
      ball.x = x
      ball.y = ground_y
      ring.x = x
      ring.y = y
      # Absorb: target shrinks/fades while energy ring converges.
      if cfg["capture_fx"] != "0"
        12.times do |f|
          event.opacity = [255 - f*23, 0].max
          ring.zoom_x = ring.zoom_y = 1.1 - f*0.07
          ring.opacity = [255 - f*16, 0].max
          ball.y = ground_y - 10 + f*10.0/11
          ball.zoom_x = ball.zoom_y = zoom*(0.7 + f*0.3/11)
          Graphics.update; Input.update; update_frame
        end
      end
      event.transparent = true
      ring.visible = false
      # A small pause before shaking makes each result readable.
      7.times { Graphics.update; Input.update; update_frame }
      shakes = critical ? 1 : cfg["capture_shakes"].to_i.clamp(1,5)
      phase_frames = cfg["capture_shake_frames"].to_i.clamp(6,25)
      shakes.times do
        begin
          pbSEPlay("Battle ball shake") if cfg["feedback_sfx"] != "0" &&
            defined?(pbSEPlay)
        rescue StandardError
        end
        phase_frames.times do |f|
          u = f.to_f / phase_frames
          ball.angle = Math.sin(u*2*Math::PI)*16
          ball.x = x + Math.sin(u*2*Math::PI)*3
          ball.y = ground_y - (Math.sin(u*Math::PI).abs*3)
          Graphics.update; Input.update; update_frame
        end
        ball.angle = 0
        5.times { Graphics.update; Input.update; update_frame }
      end
      ring.visible = true
      ring.bitmap.clear
      tint = caught ? Color.new(144,255,195) : Color.new(255,156,141)
      80.times do |i|
        angle = i*2*Math::PI/80
        cx = (36+Math.cos(angle)*25).round
        cy = (36+Math.sin(angle)*25).round
        ring.bitmap.fill_rect(cx,cy,2,2,tint)
      end
      13.times do |f|
        ring.x = x
        ring.y = ground_y
        ring.zoom_x = ring.zoom_y = 0.45 + 0.095*f
        ring.opacity = 255-19*f
        ball.opacity = caught ? [255-26*f,0].max : [255-31*f,0].max
        Graphics.update; Input.update; update_frame
      end
    ensure
      event.opacity = orig_alpha
      event.transparent = caught || orig_hidden
      event.instance_variable_set(:@move_type,orig_move)
      event.instance_variable_set(:@bifrost_capture_lock,false)
      [ball,ring].each do |sprite|
        bmp = sprite.bitmap
        sprite.dispose unless sprite.disposed?
        bmp.dispose if bmp && !bmp.disposed?
      end
      viewport.dispose unless viewport.disposed?
      @capture_busy = false
    end
  end
end

EventHandlers.add(:on_frame_update,:bifrost_capture_results,
  proc { BifrostCapture::Feedback.update }
)
EventHandlers.add(:on_enter_map,:bifrost_result_map_change,
  proc { |_old| BifrostCapture::Feedback.reset }
)
