#===============================================================================
# [VERMEIL] Visual 2.5D - 007_DebugMenu.rb
# Comandos de debug (F3 / F9) para alternar la camara 2.5D y editar perspectiva.
#===============================================================================
module Input
  F3 = 114 unless const_defined?(:F3)
end

module Mode7
  def self.open_camera_debug_menu
    return if !$scene.is_a?(Scene_Map) || !Mode7.rendering_now?

    cmd = 0
    loop do
      commands = [
        _INTL("Angulo: {1}°", Mode7.current_alpha),
        _INTL("Zoom: {1}", Mode7.zoom),
        _INTL("Rango profundidad Sky: {1}", Mode7.planet_radius),
        _INTL("Distancia (Altura): {1}", Mode7.distance_h),
        _INTL("Diagnostico lift"),
        _INTL("Volver")
      ]
      cmd = pbShowCommands(nil, commands, -1, cmd)
      break if cmd < 0 || cmd == commands.length - 1

      case cmd
      when 0 # Editar Angulo
        params = ChooseNumberParams.new
        params.setRange(0, 89)
        params.setDefaultValue(Mode7.current_alpha.round)
        new_alpha = pbMessageChooseNumber(_INTL("Elige el angulo de inclinacion:"), params)
        if new_alpha
          Mode7.set_camera(new_alpha, Mode7.zoom, 0, Mode7.distance_h, Mode7.planet_radius)
          $scene.instance_variable_get(:@map_renderer).invalidate_ground rescue nil
        end
      when 1 # Editar Zoom
        params = ChooseNumberParams.new
        min_zoom = (Mode7::Config::CAMERA_ZOOM_MIN * 100).round
        max_zoom = (Mode7::Config::CAMERA_ZOOM_MAX * 100).round
        params.setRange(min_zoom, max_zoom)
        params.setDefaultValue((Mode7.zoom * 100).round.clamp(min_zoom, max_zoom))
        new_zoom_int = pbMessageChooseNumber(_INTL("Elige el Zoom (x100, ej: 60 = 0.60):"), params)
        if new_zoom_int
          new_zoom = new_zoom_int.to_f / 100.0
          Mode7.set_zoom(new_zoom)
        end
      when 2 # Editar Rango profundidad Sky
        params = ChooseNumberParams.new
        params.setRange(100, 5000)
        params.setDefaultValue(Mode7.planet_radius.round)
        new_rad = pbMessageChooseNumber(_INTL("Elige el rango de profundidad Sky:"), params)
        if new_rad
          Mode7.set_camera(Mode7.current_alpha, Mode7.zoom, 0, Mode7.distance_h, new_rad.to_f)
          $scene.instance_variable_get(:@map_renderer).invalidate_ground rescue nil
        end
      when 3 # Editar Distancia
        params = ChooseNumberParams.new
        params.setRange(100, 2000)
        params.setDefaultValue(Mode7.distance_h.round)
        new_dist = pbMessageChooseNumber(_INTL("Elige la distancia (H):"), params)
        if new_dist
          Mode7.set_camera(Mode7.current_alpha, Mode7.zoom, 0, new_dist.to_f, Mode7.planet_radius)
          $scene.instance_variable_get(:@map_renderer).invalidate_ground rescue nil
        end
      when 4 # Diagnostico lift
        pbMessage(Mode7.terrain_camera_lift_debug_text)
      end
    end
  end
end

# Inyectamos el atajo F3 en el Scene_Map
class Scene_Map
  alias_method :_VERMEIL_25D_camera_update, :update unless method_defined?(:_VERMEIL_25D_camera_update)

  def update
    _VERMEIL_25D_camera_update
    Mode7::Heightmap.update_camera if Mode7.rendering_now? && Mode7::Config::HEIGHTMAP_ENABLED
    
    # El atajo F3 debe funcionar siempre, no solo cuando el modo 2.5D está activo.
    if Input.trigger?(Input::F3)
      Mode7.toggle_debug
      pbMessage(_INTL("2.5D ({1})", Mode7.override_state))
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
    }
  })

  MenuHandlers.add(:debug_menu, :mode7_camera, {
    "name"        => _INTL("Configurar Camara 2.5D"),
    "parent"      => :main,
    "description" => _INTL("Cambia la inclinacion, zoom y radio del planeta."),
    "effect"      => proc {
      Mode7.open_camera_debug_menu
    }
  })
end
