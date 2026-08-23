#===============================================================================
# [VERMEIL] Visual 2.5D - 007_DebugMenu.rb
# Debug V5: camara NDS, Terrain Tags visuales, volumen y rendimiento.
#===============================================================================
module Input
  F3 = 114 unless const_defined?(:F3)
end

module Mode7
  def self.projection_debug_label
    indoor = indoor_map? ? _INTL("Indoor") : _INTL("Outdoor")
    _INTL("Camara NDS [Fija/{1}]", indoor)
  end

  def self.performance_profile_label
    case nds_performance_profile
    when :quality then _INTL("Calidad")
    when :balanced then _INTL("Balanceado")
    else _INTL("Rendimiento")
    end
  rescue Exception
    _INTL("Rendimiento")
  end

  def self.open_projection_debug_selector
    pbMessage(_INTL("Visual 2.5D usa Camara NDS en todos los mapas. Affine y Cylindrical ya no son modos seleccionables."))
    set_projection_mode(:perspective)
  end

  def self.open_performance_profile_selector
    values = [:performance, :balanced, :quality]
    labels = [
      _INTL("Rendimiento - 16px, menos caras laterales"),
      _INTL("Balanceado - 12px, volumen completo"),
      _INTL("Calidad - 8px, mas subdivision")
    ]
    current = nds_performance_profile
    index = values.index(current) || 0
    chosen = pbShowCommands(nil, labels, -1, index)
    return if chosen < 0
    self.nds_performance_profile = values[chosen]
  end

  def self.open_performance_debug_menu
    return if !$scene.is_a?(Scene_Map)
    cmd = 0
    loop do
      fps = respond_to?(:nds_average_fps) ? nds_average_fps : 0.0
      graphics_target = Graphics.respond_to?(:frame_rate) ? Graphics.frame_rate : 0
      band = respond_to?(:nds_ground_band_height) ? nds_ground_band_height : Config::GEOMETRY_GROUND_BAND_HEIGHT
      side = respond_to?(:nds_side_faces?) && nds_side_faces? ? _INTL("ON") : _INTL("OFF")
      commands = [
        _INTL("Perfil: {1}", performance_profile_label),
        _INTL("FPS medio: {1}", format('%.1f', fps)),
        _INTL("Graphics.frame_rate: {1}", graphics_target),
        _INTL("Tramo suelo efectivo: {1}px", band),
        _INTL("Caras laterales de volumen: {1}", side),
        _INTL("Volumen 23: {1}px | Alto 32: {2}px | Montana 29: {3}px", nds_volume_height.round, Config::NDS_VOLUME_HIGH_HEIGHT.round, Config::NDS_MOUNTAIN_HEIGHT.round),
        _INTL("Volver")
      ]
      cmd = pbShowCommands(nil, commands, -1, cmd)
      break if cmd < 0 || cmd == commands.length - 1
      case cmd
      when 0
        open_performance_profile_selector
      when 1, 2, 3, 4
        pbMessage(_INTL("Estos valores son de diagnostico. Para buscar FPS de tres cifras usa el perfil Rendimiento y los ajustes High FPS de mkxp.json incluidos en el plugin."))
      when 5
        params = ChooseNumberParams.new
        params.setRange(0, Config::NDS_VOLUME_MAX_HEIGHT.to_i)
        params.setDefaultValue(nds_volume_height.round)
        value = pbMessageChooseNumber(_INTL("Altura del Terrain Tag 23 NDSVolume:"), params)
        self.nds_volume_height = value if value
      end
    end
  end

  def self.open_camera_debug_menu
    return if !$scene.is_a?(Scene_Map) || !Mode7.rendering_now?

    cmd = 0
    loop do
      active_angle = Mode7.indoor_map? ? Mode7.indoor_alpha : Mode7.outdoor_alpha
      band = Mode7.respond_to?(:nds_ground_band_height) ? Mode7.nds_ground_band_height : Mode7::Config::GEOMETRY_GROUND_BAND_HEIGHT
      balance = Mode7.respond_to?(:nds_focal_balance) ? (Mode7.nds_focal_balance * 100).round : (Mode7::Config::PERSPECTIVE_FOCAL_BALANCE * 100).round
      commands = [
        _INTL("Camara: {1}", Mode7.projection_debug_label),
        _INTL("Angulo actual: {1} grados", active_angle.round),
        _INTL("Distancia: {1}", Mode7.distance_h.round),
        _INTL("Pivote vertical: {1}%", Mode7.respond_to?(:perspective_pivot_percent) ? Mode7.perspective_pivot_percent : 50),
        _INTL("Balance perspectiva: {1}%", balance),
        _INTL("Tramo suelo efectivo: {1}px", band),
        _INTL("Altura billboard ref.: {1}", Mode7::Config::PERSPECTIVE_BILLBOARD_HEIGHT.round),
        _INTL("Angulo Indoor: {1} grados", Mode7.indoor_alpha.round),
        _INTL("Angulo Outdoor: {1} grados", Mode7.outdoor_alpha.round),
        _INTL("Volver")
      ]
      cmd = pbShowCommands(nil, commands, -1, cmd)
      break if cmd < 0 || cmd == commands.length - 1

      case cmd
      when 0
        Mode7.open_projection_debug_selector
      when 1
        params = ChooseNumberParams.new
        params.setRange(0, 65)
        params.setDefaultValue(active_angle.round)
        value = pbMessageChooseNumber(_INTL("Angulo de camara NDS:"), params)
        if value
          context = Mode7.indoor_map? ? :indoor : :outdoor
          Mode7.set_context_angle(context, value)
        end
      when 2
        params = ChooseNumberParams.new
        params.setRange(250, 900)
        params.setDefaultValue(Mode7.distance_h.round)
        value = pbMessageChooseNumber(_INTL("Distancia de camara:"), params)
        Mode7.set_camera(
          Mode7.current_alpha, Mode7.camera_zoom, 0,
          value.to_f, Mode7.cylindrical_radius
        ) if value
      when 3
        if Mode7.respond_to?(:set_perspective_pivot_percent)
          params = ChooseNumberParams.new
          params.setRange(35, 65)
          params.setDefaultValue(Mode7.perspective_pivot_percent)
          value = pbMessageChooseNumber(_INTL("Pivote vertical (%):"), params)
          Mode7.set_perspective_pivot_percent(value) if value
        end
      when 4
        if Mode7.respond_to?(:nds_focal_balance=)
          params = ChooseNumberParams.new
          params.setRange(0, 100)
          params.setDefaultValue(balance)
          value = pbMessageChooseNumber(_INTL("Balance perspectiva (%): 38 = recomendado para pixel art"), params)
          Mode7.nds_focal_balance = value.to_f / 100.0 if value
        end
      when 5
        pbMessage(_INTL("El tramo se adapta al perfil y al angulo. Rendimiento prioriza estabilidad."))
      when 6
        pbMessage(_INTL("Billboards y estructuras mantienen escala 1:1."))
      when 7, 8
        context = (cmd == 7) ? :indoor : :outdoor
        current = context == :indoor ? Mode7.indoor_alpha : Mode7.outdoor_alpha
        params = ChooseNumberParams.new
        params.setRange(0, 65)
        params.setDefaultValue(current.round)
        value = pbMessageChooseNumber(
          _INTL("Elige el angulo {1}:", context == :indoor ? "Indoor" : "Outdoor"),
          params
        )
        Mode7.set_context_angle(context, value) if value
      end
    end
  end
end

class Scene_Map
  alias_method :_VERMEIL_25D_camera_update, :update unless method_defined?(:_VERMEIL_25D_camera_update)

  def update
    _VERMEIL_25D_camera_update
    Mode7::Heightmap.update_camera if Mode7.rendering_now? && Mode7::Config::HEIGHTMAP_ENABLED

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
    "description" => _INTL("Activa o desactiva la camara 2.5D del mapa actual."),
    "effect"      => proc {
      Mode7.toggle_debug
      pbMessage(_INTL("2.5D ({1})", Mode7.override_state))
    }
  })

  MenuHandlers.add(:debug_menu, :mode7_camera, {
    "name"        => _INTL("Configurar Camara NDS / 2.5D"),
    "parent"      => :main,
    "description" => _INTL("Ajusta una sola camara compartida por suelo, volumen, walls y personajes."),
    "effect"      => proc { Mode7.open_camera_debug_menu }
  })

  MenuHandlers.add(:debug_menu, :mode7_performance, {
    "name"        => _INTL("Rendimiento NDS / FPS"),
    "parent"      => :main,
    "description" => _INTL("Cambia perfil, revisa FPS y ajusta el volumen global de tiles."),
    "effect"      => proc { Mode7.open_performance_debug_menu }
  })
end
