# Vermeil Movement Studio - HUD de diagnostico, solo en modo DEBUG.
# No modifica input, movimiento, camara ni variables guardadas de la partida.
module VermeilMovement
  module Diagnostics
    def self.close
      if @sprite
        begin
          @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
          @sprite.dispose unless @sprite.disposed?
        rescue StandardError
        end
      end
      @sprite = nil
      @last_draw = nil
    end

    def self.update
      if !$DEBUG || !$game_player || !$game_map || !$game_temp ||
         $game_temp.in_battle || $game_temp.in_menu || !VermeilMovement.enabled?("debug_hud")
        close if @sprite
        return
      end
      if !@sprite || @sprite.disposed?
        @sprite = Sprite.new
        @sprite.bitmap = Bitmap.new(424, 116)
        @sprite.z = 999997
        @sprite.x = 8
        @sprite.y = 42   # Debajo del indicador del Turbo.
        @last_draw = nil
      end
      now = System.respond_to?(:unscaled_uptime) ? System.unscaled_uptime : System.uptime
      return if @last_draw && now >= @last_draw && now - @last_draw < 0.2
      @last_draw = now

      player = $game_player
      effective_dirs = VermeilMovement.enabled?("instant_turn") ? VermeilMovement.directions : 4
      input_dir = (effective_dirs == 8 && Input.respond_to?(:dir8)) ? Input.dir8 : Input.dir4(false)
      turbo_multiplier = defined?(Turbo) ? Turbo.multiplier : 1.0
      move_state = player.instance_variable_get(:@move_timer) ? "MOVIENDO" : "QUIETO"
      flow = VermeilMovement.flow? ? "ON" : "OFF"
      cam = VermeilMovement.camera_smoothing
      lead = VermeilMovement.camera_lookahead
      dead = VermeilMovement.camera_deadzone

      bitmap = @sprite.bitmap
      bitmap.clear
      bitmap.fill_rect(0, 0, 424, 116, Color.new(13, 16, 24, 204))
      bitmap.font.size = 17
      bitmap.font.color = Color.new(242, 247, 250)
      bitmap.draw_text(8, 2, 405, 23, "VERMEIL MOVEMENT   [DIAG / DEBUG]")
      bitmap.font.size = 15
      bitmap.draw_text(8, 27, 405, 20,
        "Mapa #{player.map_id}  |  #{move_state}  |  Input #{input_dir}  |  #{effective_dirs} dir")
      bitmap.draw_text(8, 48, 405, 20,
        "Tile #{player.x},#{player.y}  |  Facing #{player.direction}  |  Turbo x#{sprintf('%.1f',turbo_multiplier)}")
      bitmap.draw_text(8, 69, 405, 20,
        "Flow #{flow}  |  Camara #{cam}%  |  Lead #{lead}px  |  Zona #{dead}px")
      bitmap.draw_text(8, 90, 405, 20,
        "Move time #{sprintf('%.3f',player.instance_variable_get(:@move_time).to_f)}s" +
        "  |  FPS #{sprintf('%.0f',Graphics.average_frame_rate.to_f)}")
    rescue StandardError => exception
      # Una herramienta visual no puede provocar un crash del overworld.
      close
      unless @failed_once
        @failed_once = true
        p "[Movement Studio HUD] #{exception.class}: #{exception.message}"
      end
    end
  end
end

EventHandlers.add(:on_frame_update, :vermeil_movement_diagnostics, proc {
  VermeilMovement::Diagnostics.update
})
EventHandlers.add(:on_start_battle, :vermeil_movement_hide_hud_battle, proc {
  VermeilMovement::Diagnostics.close
})
