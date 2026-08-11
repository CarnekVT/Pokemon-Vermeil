#===============================================================================
# [VERMEIL] Visual 2.5D - 007_DebugMenu.rb
# Comandos de debug (F3 / F9) para alternar la camara 2.5D y editar perspectiva.
#===============================================================================
module Input
  F3 = 114 unless const_defined?(:F3)
end

module Mode7
  def self.projection_debug_label
    forced = projection_override
    source = forced ? _INTL("Manual") : _INTL("Auto")
    indoor = indoor_map? ? _INTL("Indoor") : _INTL("Outdoor")
    _INTL("{1} [{2}/{3}]", map_mode.to_s.capitalize, source, indoor)
  end

  def self.open_projection_debug_selector
    values = [:auto, :affine, :cylindrical]
    labels = [
      _INTL("Auto (metadata/tags)"),
      _INTL("Affine"),
      _INTL("Cylindrical")
    ]
    current = projection_override || :auto
    index = values.index(current) || 0
    chosen = pbShowCommands(nil, labels, -1, index)
    return if chosen < 0
    set_projection_mode(values[chosen])
  end

  def self.open_camera_debug_menu
    return if !$scene.is_a?(Scene_Map) || !Mode7.rendering_now?

    cmd = 0
    loop do
      commands = [
        _INTL("Modo: {1}", Mode7.projection_debug_label),
        _INTL("Angulo Indoor: {1}°", Mode7.indoor_alpha.round),
        _INTL("Angulo Outdoor: {1}°", Mode7.outdoor_alpha.round),
        _INTL("Zoom: {1}", Mode7.zoom),
        _INTL("Radio Cylindrical: {1}", Mode7.cylindrical_radius),
        _INTL("Distancia (Altura): {1}", Mode7.distance_h),
        _INTL("Volver")
      ]
      cmd = pbShowCommands(nil, commands, -1, cmd)
      break if cmd < 0 || cmd == commands.length - 1

      case cmd
      when 0
        Mode7.open_projection_debug_selector
      when 1, 2
        context = (cmd == 1) ? :indoor : :outdoor
        current = context == :indoor ? Mode7.indoor_alpha : Mode7.outdoor_alpha
        params = ChooseNumberParams.new
        params.setRange(0, 89)
        params.setDefaultValue(current.round)
        value = pbMessageChooseNumber(
          _INTL("Elige el angulo {1}:", context == :indoor ? "Indoor" : "Outdoor"),
          params
        )
        Mode7.set_context_angle(context, value) if value
      when 3
        params = ChooseNumberParams.new
        min_zoom = (Mode7::Config::CAMERA_ZOOM_MIN * 100).round
        max_zoom = (Mode7::Config::CAMERA_ZOOM_MAX * 100).round
        params.setRange(min_zoom, max_zoom)
        params.setDefaultValue((Mode7.zoom * 100).round.clamp(min_zoom, max_zoom))
        value = pbMessageChooseNumber(_INTL("Zoom x100 (100 = 1.00):"), params)
        Mode7.set_zoom(value.to_f / 100.0) if value
      when 4
        params = ChooseNumberParams.new
        params.setRange(100, 5000)
        params.setDefaultValue(Mode7.cylindrical_radius.round)
        value = pbMessageChooseNumber(_INTL("Radio Cylindrical:"), params)
        Mode7.set_camera(
          Mode7.current_alpha, Mode7.zoom, 0,
          Mode7.distance_h, value.to_f
        ) if value
      when 5
        params = ChooseNumberParams.new
        params.setRange(100, 2000)
        params.setDefaultValue(Mode7.distance_h.round)
        value = pbMessageChooseNumber(_INTL("Distancia (H):"), params)
        Mode7.set_camera(
          Mode7.current_alpha, Mode7.zoom, 0,
          value.to_f, Mode7.cylindrical_radius
        ) if value
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
    "description" => _INTL("Activa o desactiva la proyeccion 2.5D del mapa actual."),
    "effect"      => proc {
      Mode7.toggle_debug
      pbMessage(_INTL("2.5D ({1})", Mode7.override_state))
    }
  })

  MenuHandlers.add(:debug_menu, :mode7_camera, {
    "name"        => _INTL("Configurar Camara 2.5D"),
    "parent"      => :main,
    "description" => _INTL("Cambia la inclinacion, zoom y radio Cylindrical."),
    "effect"      => proc {
      Mode7.open_camera_debug_menu
    }
  })
end
