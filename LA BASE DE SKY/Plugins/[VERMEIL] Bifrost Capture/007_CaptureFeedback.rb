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
        return if defined?(BifrostCapture::Audio) # centralized event audio
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

end

# The capture FX state machine lives in 008_LiveGamefeel.rb and is updated
# by the existing map frame hook. No extra frame loop may be introduced here.

EventHandlers.add(:on_frame_update,:bifrost_capture_results,
  proc { BifrostCapture::Feedback.update }
)
EventHandlers.add(:on_enter_map,:bifrost_result_map_change,
  proc { |_old| BifrostCapture::Feedback.reset }
)
