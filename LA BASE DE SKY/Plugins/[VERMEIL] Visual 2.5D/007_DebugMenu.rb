#===============================================================================
# [VERMEIL] Visual 2.5D - 007_DebugMenu.rb
# Comandos de debug (F9) para alternar la camara 2.5D y editar la perspectiva
# en vivo. Incluye el control de angulo dinamico (efecto vuelo/respiracion).
#===============================================================================

module Mode7
  module CameraControl
    # SWITCH para activar el angulo cambiante (efecto respiracion/vuelo)
    DYNAMIC_ANGLE_SWITCH = 62

    # Rango en grados para el angulo dinamico
    MIN_ALPHA = 10.0
    MAX_ALPHA = 25.0

    # Velocidad de la oscilacion
    OSCILLATION_SPEED = 0.02

    @current_oscillation = 0.0

    class << self
      def update_dynamic_angle
        if $game_switches && $game_switches[DYNAMIC_ANGLE_SWITCH]
          @current_oscillation += OSCILLATION_SPEED

          # Calcula el nuevo angulo usando una onda senoidal
          mid_point = (MAX_ALPHA + MIN_ALPHA) / 2.0
          amplitude = (MAX_ALPHA - MIN_ALPHA) / 2.0
          new_alpha = mid_point + Math.sin(@current_oscillation) * amplitude

          # Aplicamos el nuevo angulo en tiempo real
          Mode7.configure(new_alpha.round, Mode7.zoom)

          # Forzamos redibujado de suelo para el efecto acordeon en tiempo real
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

# Inyectamos la actualizacion de la camara en el Scene_Map
class Scene_Map
  alias_method :_VERMEIL_25D_camera_update, :update unless method_defined?(:_VERMEIL_25D_camera_update)

  def update
    _VERMEIL_25D_camera_update
    if Mode7.active_now?
      Mode7::CameraControl.update_dynamic_angle
      Mode7::Heightmap.update_camera if Mode7::Config::HEIGHTMAP_ENABLED
    end
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :mode7_toggle, {
    "name"        => _INTL("Alternar 2.5D (Mode 7)"),
    "parent"      => :main,
    "description" => _INTL("Activa o desactiva la proyeccion 2.5D (Modo 7) del mapa actual."),
    "effect"      => proc {
      Mode7.toggle_debug
      pbMessage(_INTL("2.5D ({1})", Mode7.override_state))
      next if !$scene.is_a?(Scene_Map)
      # createSpritesets del motor NO dispone los spritesets viejos (003_Scene_Map.rb);
      # si no se dispone antes, quedan sprites de eventos huerfanos duplicados.
      $scene.disposeSpritesets
      $scene.createSpritesets
    }
  })

  MenuHandlers.add(:debug_menu, :mode7_camera, {
    "name"        => _INTL("Configurar Camara 2.5D"),
    "parent"      => :main,
    "description" => _INTL("Cambia la inclinacion, distancia y activa la camara dinamica."),
    "effect"      => proc {
      next if !$scene.is_a?(Scene_Map) || !Mode7.active_now?

      cmd = 0
      loop do
        commands = [
          _INTL("Angulo Estatico: {1}°", Mode7.current_alpha),
          _INTL("Distancia (Altura): {1}", Mode7::Config::DISTANCE_H),
          _INTL("Angulo Dinamico: {1}", $game_switches[Mode7::CameraControl::DYNAMIC_ANGLE_SWITCH] ? "ON" : "OFF"),
          _INTL("Volver")
        ]
        cmd = pbShowCommands(nil, commands, -1, cmd)
        break if cmd < 0 || cmd == commands.length - 1

        case cmd
        when 0 # Editar Angulo
          params = ChooseNumberParams.new
          params.setRange(0, 89)
          params.setDefaultValue(Mode7.current_alpha)
          new_alpha = pbMessageChooseNumber(_INTL("Elige el angulo de inclinacion:"), params)
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
        when 2 # Toggle Dinamico
          $game_switches[Mode7::CameraControl::DYNAMIC_ANGLE_SWITCH] = !$game_switches[Mode7::CameraControl::DYNAMIC_ANGLE_SWITCH]
        end
      end
    }
  })
end