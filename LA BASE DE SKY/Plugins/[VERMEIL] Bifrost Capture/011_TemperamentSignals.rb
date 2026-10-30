# frozen_string_literal: true
# Subtle, non-blocking map-space temperament indicators.
# They follow the character sprite and share the Visual 2.5D viewport.
module BifrostCapture
  module TemperamentSignals
    class << self
      def reset
        (@sprites || {}).each_value do |sprite|
          sprite.dispose if sprite && !sprite.disposed?
        end
        (@bitmaps || {}).each_value do |bitmap|
          bitmap.dispose if bitmap && !bitmap.disposed?
        end
        @sprites = {}
        @bitmaps = {}
        @viewport = nil
      end

      def clear_missing(keep)
        (@sprites || {}).keys.each do |id|
          next if keep.include?(id)
          sprite = @sprites.delete(id)
          sprite.dispose if sprite && !sprite.disposed?
        end
      end

      def kind_for(event)
        cfg = BifrostCapture.options($game_map.map_id,
          BifrostCapture.event_spec(event)[0],event.id)
        return :max_alert if defined?(BifrostCapture::Pressure) &&
          BifrostCapture::Pressure.locked?(event,cfg)
        state = event.instance_variable_get(:@bifrost_mood_state)
        return :danger if [:threat,:charge,:chase].include?(state)
        return :alert if state == :alert
        return :timid if state == :flee
        case BifrostCapture.temperament_for(event)
        when :aggressive then :aggressive
        when :timid then :timid
        else :neutral
        end
      end

      def bitmap_for(kind)
        @bitmaps ||= {}
        return @bitmaps[kind] if @bitmaps[kind] &&
                                 !@bitmaps[kind].disposed?
        palette = {
          :neutral=>[Color.new(36,91,74,174),Color.new(151,231,189),"·"],
          :timid=>[Color.new(41,78,127,188),Color.new(161,214,255),"?"],
          :aggressive=>[Color.new(115,63,48,187),Color.new(255,190,142),"!"],
          :alert=>[Color.new(130,97,37,195),Color.new(255,220,125),"!"],
          :danger=>[Color.new(142,47,47,219),Color.new(255,231,221),"!!"],
          :max_alert=>[Color.new(145,37,37,230),Color.new(255,209,103),"!!"]
        }
        back,front,mark = palette[kind] || palette[:neutral]
        bmp = Bitmap.new(30,26)
        bmp.fill_rect(5,3,20,20,Color.new(12,18,25,115))
        bmp.fill_rect(3,1,20,20,back)
        bmp.fill_rect(3,1,20,2,front)
        bmp.font.size = mark.length > 1 ? 14 : 17
        bmp.font.bold = true
        bmp.font.color = front
        bmp.draw_text(3,2,20,20,mark,1)
        @bitmaps[kind] = bmp
      end

      def update
        unless defined?($scene) && $scene.is_a?(Scene_Map) &&
               $game_map && (!defined?($game_temp) || !$game_temp ||
                 !$game_temp.in_battle)
          reset unless (@sprites || {}).empty?
          return
        end
        cfg = BifrostCapture.options
        if cfg["temperament_indicators"] == "0"
          reset unless (@sprites || {}).empty?
          return
        end
        return unless defined?(Spriteset_Map) &&
                      Spriteset_Map.respond_to?(:viewport)
        vp = Spriteset_Map.viewport
        return unless vp && !vp.disposed?
        reset if @viewport && !@viewport.equal?(vp)
        @viewport = vp
        @sprites ||= {}
        keep = []
        BifrostCapture.visible_targets.each do |event|
          next if event.instance_variable_get(:@bifrost_capture_lock)
          next if event.respond_to?(:transparent) && event.transparent
          next if event.respond_to?(:opacity) && event.opacity.to_i < 35
          key = event.object_id
          keep << key
          sprite = @sprites[key]
          if !sprite || sprite.disposed?
            sprite = Sprite.new(vp)
            @sprites[key] = sprite
          end
          sprite.bitmap = bitmap_for(kind_for(event))
          x,y,w,h = BifrostCapture.target_rect(event)
          sprite.x = (x + w/2 - 12).round
          sprite.y = [y-27,0].max.round
          sprite.z = event.respond_to?(:screen_z) ? event.screen_z+1 : 1
          sprite.opacity = event.respond_to?(:opacity) ?
                             [event.opacity,222].min : 222
        end
        clear_missing(keep)
      rescue StandardError
        reset
      end
    end
  end
end

EventHandlers.add(:on_frame_update,:bifrost_temperament_signals,
  proc { BifrostCapture::TemperamentSignals.update }
)
EventHandlers.add(:on_enter_map,:bifrost_signals_map_change,
  proc { |_old_map| BifrostCapture::TemperamentSignals.reset }
)
