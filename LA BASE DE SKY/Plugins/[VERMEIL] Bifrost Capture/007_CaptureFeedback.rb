# frozen_string_literal: true
# Non-modal Legends-style results: enter from LEFT, hold, exit to LEFT.
# No Graphics.update loop and no blocking dialogue windows.
module BifrostCapture
  module Feedback
    COLORS = {
      :caught   => [Color.new(26,73,59), Color.new(143,243,180)],
      :critical => [Color.new(28,72,91), Color.new(142,231,255)],
      :breakout => [Color.new(86,42,48), Color.new(255,156,153)],
      :miss     => [Color.new(89,68,40), Color.new(255,216,151)],
      :blocked  => [Color.new(60,64,75), Color.new(202,210,222)],
      :escape   => [Color.new(73,54,90), Color.new(218,178,255)],
      :counter  => [Color.new(100,49,32), Color.new(255,184,133)],
      :backstrike=>[Color.new(85,66,30),Color.new(255,216,105)],
      :pressure=>[Color.new(92,51,36),Color.new(255,188,105)],
      :retreat=>[Color.new(79,50,50),Color.new(255,169,154)],
      :party_hit=>[Color.new(103,51,53),Color.new(255,176,181)]
    }.freeze
    TITLES = {
      :caught=>"¡ATRAPADO!", :critical=>"¡CAPTURA CRÍTICA!",
      :breakout=>"¡SE LIBERÓ!", :miss=>"¡LANZAMIENTO FALLIDO!",
      :blocked=>"NO SE PUEDE LANZAR", :escape=>"¡ESCAPÓ!",
      :counter=>"¡CONTRAATAQUE!", :backstrike=>"¡POR LA ESPALDA!",
      :pressure=>"¡POKÉMON ALERTADO!", :retreat=>"¡HUIDA ARRIESGADA!",
      :party_hit=>"¡POKÉMON DAÑADO!"
    }.freeze

    class << self
      attr_reader :last_result

      def publish(kind,species=nil,detail=nil,cfg=nil)
        cfg ||= BifrostCapture.options
        return nil if cfg["feedback_enabled"] == "0"
        incoming = {
          :kind=>kind, :species=>species, :detail=>detail.to_s,
          :enter=>cfg["feedback_enter_frames"].to_i.clamp(6,30),
          :hold=>kind == :backstrike ? 28 : cfg["feedback_hold_frames"].to_i.clamp(25,180),
          :exit=>cfg["feedback_exit_frames"].to_i.clamp(6,30),
          :frames=>0
        }
        @last_result = incoming # Stable public result for tests/debug consumers.
        @queue ||= []
        @queue << incoming
        limit = cfg["feedback_queue_limit"].to_i.clamp(1,8)
        @queue.shift while @queue.length > limit
        advance_queue unless @active
        @last_result
      end

      def advance_queue
        @active = @queue && @queue.shift
        if @active
          redraw
        else
          dispose
        end
      end

      def update
        return unless @active
        return unless defined?($scene) && $scene.is_a?(Scene_Map)
        ensure_sprite
        state = @active
        state[:frames] += 1
        frame = state[:frames]
        enter_frames = state[:enter]
        exit_start = enter_frames + state[:hold]
        if frame <= enter_frames
          t = frame.to_f/enter_frames
          ease = t*t*(3-2*t)
          @toast.x = -@toast.bitmap.width-8 +
            ((@toast.bitmap.width+20)*ease)
          @toast.opacity = (255*ease).to_i
        elsif frame <= exit_start
          @toast.x = 12
          @toast.opacity = 255
        elsif frame < exit_start+state[:exit]
          t = (frame-exit_start).to_f/state[:exit]
          ease = t*t*(3-2*t)
          @toast.x = 12 - ((@toast.bitmap.width+24)*ease)
          @toast.opacity = (255*(1.0-ease)).to_i
        else
          advance_queue
          return
        end
        @toast.y = [(Graphics.height*0.19).round,20].max
      end

      def ensure_sprite
        return if @toast && !@toast.disposed?
        @viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
        @viewport.z = 999999
        @toast = Sprite.new(@viewport)
        @toast.bitmap = Bitmap.new([[Graphics.width-20,318].min,180].max,70)
        @toast.x = -@toast.bitmap.width-8
        @toast.y = [(Graphics.height*0.19).round,20].max
        @toast.opacity = 0
      end

      def redraw
        return unless @active
        ensure_sprite
        bmp = @toast.bitmap
        bmp.clear
        state = @active
        fill,accent = COLORS[state[:kind]] || COLORS[:blocked]
        w = bmp.width
        # Layered compact surface; clearer than an opaque central toast.
        bmp.fill_rect(0,0,w,67,Color.new(11,20,31,223))
        bmp.fill_rect(0,0,4,67,accent)
        bmp.fill_rect(4,0,w-4,2,fill)
        bmp.fill_rect(4,62,w-4,2,Color.new(73,95,112,130))
        bmp.fill_rect(12,10,46,46,fill)
        icon = state[:kind] == :blocked ? nil : species_icon(state[:species])
        if icon && icon.width > 0 && icon.height > 0
          source_width = icon.width > icon.height ? icon.width/2 : icon.width
          bmp.stretch_blt(Rect.new(14,12,42,42),icon,
            Rect.new(0,0,source_width,icon.height))
        else
          bmp.fill_rect(21,19,27,27,accent)
          if state[:kind] == :blocked
            bmp.fill_rect(22,31,26,4,Color.new(24,35,46))
            bmp.fill_rect(32,28,8,10,Color.new(24,35,46))
            22.times { |i| bmp.fill_rect(23+i,43-i,2,2,Color.new(255,120,120)) }
          end
          if [:caught,:critical].include?(state[:kind])
            bmp.fill_rect(26,32,7,3,Color.new(25,56,48))
            bmp.fill_rect(31,36,5,3,Color.new(25,56,48))
            bmp.fill_rect(36,26,4,14,Color.new(25,56,48))
          end
        end
        bmp.font.size = 18
        bmp.font.bold = true
        bmp.font.color = accent
        bmp.draw_text(67,6,w-75,27,TITLES[state[:kind]] || "BIFRÖST")
        bmp.font.bold = false
        bmp.font.size = 13
        bmp.font.color = Color.new(233,240,249)
        name = nil
        if state[:species]
          name = begin GameData::Species.get(state[:species]).name
                 rescue StandardError
                   state[:species].to_s
                 end
        end
        description = [name,state[:detail]].reject { |t| t.nil? || t.empty? }.join(" · ")
        bmp.draw_text(67,35,w-75,21,description)
      end

      def species_icon(species)
        return nil unless species
        return @icon_bitmap if @icon_species == species && @icon_bitmap &&
                               !@icon_bitmap.disposed?
        @icon_bitmap.dispose if @icon_bitmap && !@icon_bitmap.disposed?
        @icon_bitmap = nil
        @icon_species = species
        path = pbResolveBitmap("Graphics/Pokemon/Icons/#{species}")
        @icon_bitmap = Bitmap.new(path) if path
        @icon_bitmap
      rescue StandardError
        nil
      end

      def dispose
        @icon_bitmap.dispose if @icon_bitmap && !@icon_bitmap.disposed?
        @icon_bitmap = nil
        @icon_species = nil
        if @toast && !@toast.disposed?
          bmp = @toast.bitmap
          @toast.dispose
          bmp.dispose if bmp && !bmp.disposed?
        end
        @toast = nil
        @viewport.dispose if @viewport && !@viewport.disposed?
        @viewport = nil
      end

      def reset
        @last_result = nil
        @queue = []
        @active = nil
        dispose
      end
    end
  end
end

EventHandlers.add(:on_frame_update,:bifrost_capture_results,
  proc { BifrostCapture::Feedback.update }
)
EventHandlers.add(:on_enter_map,:bifrost_result_map_change,
  proc { |_old| BifrostCapture::Feedback.reset }
)
EventHandlers.add(:on_start_battle,:bifrost_result_enter_battle,
  proc { |_battle| BifrostCapture::Feedback.reset }
)
