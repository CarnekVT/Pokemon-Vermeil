# frozen_string_literal: true
# Per-target overworld capture pressure. All runtime state stays transient.
module BifrostCapture
  module Pressure
    class << self
      def value(event)
        return 0 unless event
        event.instance_variable_get(:@bifrost_pressure).to_i.clamp(0,100)
      end

      def locked?(event,cfg)
        return false unless event && cfg["pressure_enabled"] == "1"
        return true if event.instance_variable_get(:@bifrost_max_alert)
        value(event) >= cfg["pressure_block_threshold"].to_i.clamp(1,100)
      end

      def add(event,reason,cfg)
        return 0 unless event && cfg["pressure_enabled"] == "1"
        field = { :miss=>"pressure_miss", :breakout=>"pressure_breakout",
                  :front=>"pressure_front", :back=>"pressure_back" }[reason]
        gain = field ? cfg[field].to_i : 0
        previous = event.instance_variable_get(:@bifrost_pressure_attempt_frame)
        gain += cfg["pressure_repeat"].to_i if previous && @frame.to_i-previous < 150
        event.instance_variable_set(:@bifrost_pressure_attempt_frame,@frame.to_i)
        old = value(event)
        updated = (old+gain.clamp(0,100)).clamp(0,100)
        was_locked = locked?(event,cfg)
        event.instance_variable_set(:@bifrost_pressure,updated)
        if updated >= cfg["pressure_block_threshold"].to_i.clamp(1,100)
          event.instance_variable_set(:@bifrost_max_alert,true)
          unless was_locked
            spec = BifrostCapture.event_spec(event)
            if defined?(BifrostCapture::Feedback)
              BifrostCapture::Feedback.publish(:max_alert,spec && spec[0],
                _INTL("Solo combate o usar un cebo/baya"),cfg)
            end
          end
        end
        alert = cfg["pressure_alert_threshold"].to_i.clamp(1,100)
        if old < alert && updated >= alert
          spec = BifrostCapture.event_spec(event)
          if defined?(BifrostCapture::Feedback)
            BifrostCapture::Feedback.publish(:pressure,spec && spec[0],
              _INTL("Ahora es más difícil capturarlo"),cfg)
          end
          BifrostCapture.notice(_INTL("¡El Pokémon está en alerta!"))
          if BifrostCapture.temperament_for(event,cfg) == :aggressive &&
             !BifrostCapture.chasing?(event)
            BifrostCapture.start_chase(event,cfg)
          end
        end
        updated
      end

      def capture_modifier(event,cfg)
        return 1.0 if cfg["pressure_enabled"] != "1"
        factor = (1.0-value(event)*0.007).clamp(0.30,1.0)
        factor *= 0.55 if BifrostCapture.respond_to?(:chasing?) &&
                          BifrostCapture.chasing?(event)
        factor *= 0.72 if @map_alarm.to_i > 0
        factor
      end

      def on_escape(event,cfg)
        return unless cfg["pressure_enabled"] == "1"
        frames = cfg["pressure_escape_frames"].to_i.clamp(0,1800)
        return if frames <= 0
        @map_alarm = [@map_alarm.to_i,frames].max
        BifrostCapture.notice(_INTL("¡Escapaste, pero la zona está alerta!"))
        if defined?(BifrostCapture::Feedback)
          spec = BifrostCapture.event_spec(event)
          BifrostCapture::Feedback.publish(:retreat,spec && spec[0],
            _INTL("Capturas directas menos eficaces temporalmente"),cfg)
        end
      end

      def calm_with_bait(event,item,cfg)
        return false unless event && item && $bag &&
          $bag.quantity(item).to_i > 0 && BifrostCapture.eligible_event?(event)
        return false unless BifrostCapture.bait_item?(item)
        return false unless $bag.remove(item,1)
        event.instance_variable_set(:@bifrost_pressure,0)
        event.instance_variable_set(:@bifrost_max_alert,false)
        event.instance_variable_set(:@bifrost_pressure_attempt_frame,nil)
        BifrostCapture.stop_chase(event) if BifrostCapture.respond_to?(:chasing?) &&
          BifrostCapture.chasing?(event)
        BifrostCapture.restore_wander(event) if BifrostCapture.respond_to?(:fleeing?) &&
          BifrostCapture.fleeing?(event)
        BifrostCapture.cancel_escape_reaction(event) if
          BifrostCapture.respond_to?(:cancel_escape_reaction)
        BifrostCapture.cancel_pending_attack(event) if
          BifrostCapture.respond_to?(:cancel_pending_attack)
        event.instance_variable_set(:@bifrost_alert_cooldown,180)
        event.instance_variable_set(:@bifrost_mood_state,:curious)
        spec = BifrostCapture.event_spec(event)
        if defined?(BifrostCapture::Feedback)
          BifrostCapture::Feedback.publish(:calmed,spec && spec[0],
            _INTL("Aceptó el alimento y bajó la guardia"),cfg)
        end
        true
      end

      def clear_success(event)
        if event
          event.instance_variable_set(:@bifrost_max_alert,false)
          event.instance_variable_set(:@bifrost_pressure,0)
          event.instance_variable_set(:@bifrost_pressure_attempt_frame,nil)
        end
        @map_alarm = 0
      end

      def update
        return unless defined?($scene) && $scene.is_a?(Scene_Map) &&
                      $game_map && $game_player
        @frame = @frame.to_i+1
        @map_alarm = [@map_alarm.to_i-1,0].max
        cfg = BifrostCapture.options
        return unless cfg["pressure_enabled"] == "1"
        interval = cfg["pressure_decay_frames"].to_i.clamp(6,120)
        return unless @frame % interval == 0
        $game_map.events.values.each do |event|
          next unless BifrostCapture.eligible_event?(event)
          next if locked?(event,cfg)
          n = value(event)
          event.instance_variable_set(:@bifrost_pressure,n-1) if n > 0
        end
      end

      def reset
        @map_alarm = 0
        @frame = 0
      end
    end
  end
end

EventHandlers.add(:on_frame_update,:bifrost_gamefeel_pressure,
  proc { BifrostCapture::Pressure.update }
)
EventHandlers.add(:on_enter_map,:bifrost_pressure_map_change,
  proc { |_old| BifrostCapture::Pressure.reset }
)
