#===============================================================================
# Mode 7 (2.5D) - Control Dinámico y Menú de Cámara
#===============================================================================

module Mode7
  module CameraControl
    # SWITCH para activar el ángulo cambiante (efecto respiración/vuelo)
    DYNAMIC_ANGLE_SWITCH = 62

    # Rango en grados para el ángulo dinámico
    MIN_ALPHA = 10.0
    MAX_ALPHA = 25.0

    # Velocidad de la oscilación
    OSCILLATION_SPEED = 0.02

    @current_oscillation = 0.0

    class << self
      def update_dynamic_angle
        if $game_switches && $game_switches[DYNAMIC_ANGLE_SWITCH]
          @current_oscillation += OSCILLATION_SPEED

          # Calcula el nuevo ángulo usando una onda senoidal
          mid_point = (MAX_ALPHA + MIN_ALPHA) / 2.0
          amplitude = (MAX_ALPHA - MIN_ALPHA) / 2.0
          new_alpha = mid_point + Math.sin(@current_oscillation) * amplitude

          # Aplicamos el nuevo ángulo en tiempo real
          Mode7.configure(new_alpha.round, Mode7.zoom)

          # Forzamos redibujado de suelo para el efecto acordeón en tiempo real
          invalidate_renderer_ground
        end
      end


      private


      def invalidate_renderer_ground
        return if !$scene.is_a?(Scene_Map)
        renderer = $scene.instance_variable_get(:@map_renderer)
        return if !renderer || !renderer.is_a?(Mode7Renderer) || renderer.disposed?
        renderer.invalidate_ground if renderer.respond_to?(:invalidate_ground)
      end
    end
  end
end

# Inyectamos la actualización de la cámara en el Scene_Map
class Scene_Map
  alias_method :_ZBOX_M7_camera_update, :update unless method_defined?(:_ZBOX_M7_camera_update)

  def update
    _ZBOX_M7_camera_update
    Mode7::CameraControl.update_dynamic_angle if Mode7.active_now?
  end
end

#===============================================================================
# Añadimos un menú al Debug Menu (F9) para editar la cámara en vivo
#===============================================================================
if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :mode7_camera, {
    "name"        => _INTL("Configurar Cámara 2.5D"),
    "parent"      => :main,
    "description" => _INTL("Cambia la inclinación, distancia y activa la cámara dinámica."),
    "effect"      => proc {
      next if !$scene.is_a?(Scene_Map) || !Mode7.active_now?

      cmd = 0
      loop do
        commands = [
          _INTL("Ángulo Estático: {1}°", Mode7.current_alpha),
          _INTL("Distancia (Altura): {1}", Mode7::Config::DISTANCE_H),
          _INTL("Ángulo Dinámico: {1}", $game_switches[Mode7::CameraControl::DYNAMIC_ANGLE_SWITCH] ? "ON" : "OFF"),
          _INTL("Volver")
        ]
        cmd = pbShowCommands(nil, commands, -1, cmd)
        break if cmd < 0 || cmd == commands.length - 1

        case cmd
        when 0 # Editar Ángulo
          params = ChooseNumberParams.new
          params.setRange(0, 89)
          params.setDefaultValue(Mode7.current_alpha)
          new_alpha = pbMessageChooseNumber(_INTL("Elige el ángulo de inclinación:"), params)
          Mode7.configure(new_alpha, Mode7.zoom)
          $scene.instance_variable_get(:@map_renderer).invalidate_ground rescue nil
        when 1 # Editar Distancia
          params = ChooseNumberParams.new
          params.setRange(100, 2000)
          params.setDefaultValue(Mode7::Config::DISTANCE_H)
          new_dist = pbMessageChooseNumber(_INTL("Elige la distancia (H):"), params)

          # Actualizamos la constante y reconfiguramos
          Mode7::Config.send(:remove_const, :DISTANCE_H)
          Mode7::Config.const_set(:DISTANCE_H, new_dist)
          Mode7.configure(Mode7.current_alpha, Mode7.zoom)
          $scene.instance_variable_get(:@map_renderer).invalidate_ground rescue nil
        when 2 # Toggle Dinámico
          $game_switches[Mode7::CameraControl::DYNAMIC_ANGLE_SWITCH] = !$game_switches[Mode7::CameraControl::DYNAMIC_ANGLE_SWITCH]
        end
      end
    }
  })
end
