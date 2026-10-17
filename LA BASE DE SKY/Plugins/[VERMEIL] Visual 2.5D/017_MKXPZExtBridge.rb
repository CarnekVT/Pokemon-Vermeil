#===============================================================================
# [VERMEIL] Visual 2.5D - 017_MKXPZExtBridge.rb
# Integracion con las extensiones nativas de mkxp-z-ext:
#   * coordenadas subpixel reales en Sprite
#   * Sprite#corners para quads arbitrarios
#   * deteccion centralizada de Shader / Viewport zoom
#
# Carga despues de 016_ProgressiveZoom.rb y solo activa APIs que existan.
# En mkxp-z normal conserva el renderer legacy sin romper el juego.
#===============================================================================

module Mode7
  module Config
    EXT_SUBPIXEL_SPRITES = true unless const_defined?(:EXT_SUBPIXEL_SPRITES)
    EXT_CORNERS_ENABLED  = true unless const_defined?(:EXT_CORNERS_ENABLED)

    # Los walls y bloques P2+ pueden usar un quad vertical cuya base y techo
    # se proyectan por separado. NDSIndoorProp queda rigido deliberadamente.
    EXT_CORNERS_WALLS      = true unless const_defined?(:EXT_CORNERS_WALLS)
    EXT_CORNERS_PRIORITIES = true unless const_defined?(:EXT_CORNERS_PRIORITIES)

    # Solape en px para evitar microjuntas entre quads de prioridad.
    EXT_CORNERS_OVERLAP = 1.0 unless const_defined?(:EXT_CORNERS_OVERLAP)
  end

  module MKXPZExt
    class << self
      def sprite_float?
        # En la rama ext X/Y/OX/OY son Float, pero Ruby no expone el tipo de
        # binding. La presencia de corners identifica la implementacion nueva.
        corners?
      end

      def corners?
        defined?(Sprite) && Sprite.method_defined?(:corners=)
      rescue Exception
        false
      end

      def shader?
        defined?(Shader) && defined?(Sprite) && Sprite.method_defined?(:shader=)
      rescue Exception
        false
      end

      def viewport_zoom?
        defined?(Viewport) && Viewport.method_defined?(:zoom_x=) &&
          Viewport.method_defined?(:zoom_y=)
      rescue Exception
        false
      end

      def capabilities
        {
          subpixel: sprite_float?,
          corners: corners?,
          shader: shader?,
          viewport_zoom: viewport_zoom?
        }
      end

      def log_capabilities
        return if @capabilities_logged
        @capabilities_logged = true
        caps = capabilities.map { |k, v| "#{k}=#{v ? 'yes' : 'no'}" }.join(", ")
        if defined?(Console) && Console.respond_to?(:echo_li)
          Console.echo_li("[VERMEIL 2.5D] mkxp-z-ext: #{caps}")
        elsif defined?(Console) && Console.respond_to?(:echo)
          Console.echo("[VERMEIL 2.5D] mkxp-z-ext: #{caps}")
        end
      rescue Exception
      end

      # Cierra microjuntas sin sqrt ni normalizacion por vertice. El solape es
      # deliberadamente pequeno (subpixel/1px), asi que esta expansion por ejes
      # preserva mejor el pixel-art y cuesta bastante menos en Ruby.
      def expand_quad(points, amount)
        return points if !points || points.length != 8 || amount.to_f <= 0.0
        a = amount.to_f
        [
          points[0] - a, points[1] - a,
          points[2] + a, points[3] - a,
          points[4] + a, points[5] + a,
          points[6] - a, points[7] + a
        ]
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Subpixel real para personajes/eventos.
#
# 004_CharacterDepth redondeaba el resultado final porque RGSS clasico solo
# trabajaba comodamente con enteros. mkxp-z-ext acepta float en Sprite.x/y, por
# lo que conservar la fraccion elimina el temblor de scroll lento.
#-------------------------------------------------------------------------------
class Game_Character
  def screen_x
    return _VERMEIL_25D_orig_screen_x if !mode7_active_for_self?
    wx = @real_x.to_f / Game_Map::X_SUBPIXELS +
         (@width * Game_Map::TILE_WIDTH / 2.0)
    wy = mode7_world_y_ground
    elevation = mode7_world_elevation
    pr = Mode7.project(wx, wy, elevation)
    return -1000 if !pr

    x = pr[0].to_f + self.x_offset
    if Mode7::Config::EXT_SUBPIXEL_SPRITES && Mode7::MKXPZExt.sprite_float?
      return x
    end
    x.round
  end

  def screen_y_ground
    return _VERMEIL_25D_orig_screen_y_ground if !mode7_active_for_self?
    wy = mode7_world_y_ground
    elevation = mode7_world_elevation
    y = Mode7.overworld_project_y(wy, elevation).to_f
    if Mode7::Config::EXT_SUBPIXEL_SPRITES && Mode7::MKXPZExt.sprite_float?
      return y
    end
    y.round
  end
end

#-------------------------------------------------------------------------------
# Corners para superficies P1/strips raster-affine.
#-------------------------------------------------------------------------------
class Mode7Renderer
  if private_method_defined?(:redraw_projected_priority_surface) &&
     !private_method_defined?(:_VERMEIL_EXT_orig_redraw_projected_priority_surface)
    alias_method :_VERMEIL_EXT_orig_redraw_projected_priority_surface,
                 :redraw_projected_priority_surface
  end

  private

  def redraw_projected_priority_surface(sprite, source, wx, wyb, elevation = 0)
    use_corners = Mode7::Config::EXT_CORNERS_ENABLED &&
                  Mode7::Config::EXT_CORNERS_PRIORITIES &&
                  Mode7::MKXPZExt.corners?
    return _VERMEIL_EXT_orig_redraw_projected_priority_surface(
      sprite, source, wx, wyb, elevation
    ) if !use_corners
    return false if !source || source.disposed?

    half_w = source.width / 2.0
    left_wx  = wx.to_f - half_w
    right_wx = wx.to_f + half_w
    top_wy   = wyb.to_f - source.height
    bottom_wy = wyb.to_f
    elev = elevation.to_f

    tl = Mode7.project(left_wx,  top_wy,    elev)
    tr = Mode7.project(right_wx, top_wy,    elev)
    br = Mode7.project(right_wx, bottom_wy, elev)
    bl = Mode7.project(left_wx,  bottom_wy, elev)
    return false if !tl || !tr || !br || !bl

    points = [tl[0], tl[1], tr[0], tr[1], br[0], br[1], bl[0], bl[1]]
    overlap = Mode7::Config::EXT_CORNERS_OVERLAP.to_f
    points = Mode7::MKXPZExt.expand_quad(points, overlap) if overlap > 0.0

    sprite.bitmap = source if sprite.bitmap != source

    # Aunque corners ignora transform para dibujar, update_priority_surfaces
    # reutiliza x/y/ox/oy/zoom para culling y fog. Conservamos un bounding
    # aproximado coherente con el quad.
    xs = [points[0], points[2], points[4], points[6]]
    ys = [points[1], points[3], points[5], points[7]]
    projected_w = [xs.max - xs.min, 0.001].max
    projected_h = [ys.max - ys.min, 0.001].max
    bottom_y = (points[5] + points[7]) * 0.5
    center_x = (xs.max + xs.min) * 0.5

    sprite.x = center_x
    sprite.y = bottom_y
    sprite.ox = source.width / 2.0
    sprite.oy = source.height.to_f
    sprite.zoom_x = projected_w / source.width.to_f
    sprite.zoom_y = projected_h / source.height.to_f
    sprite.corners = points
    true
  rescue Exception => e
    begin
      sprite.corners = nil if sprite && Mode7::MKXPZExt.corners?
    rescue Exception
    end
    Console.echo_error("2.5D corners priority: #{e.message}") if defined?(Console)
    _VERMEIL_EXT_orig_redraw_projected_priority_surface(
      sprite, source, wx, wyb, elevation
    )
  end
end

#-------------------------------------------------------------------------------
# Corners para bloques rigidos (walls y P2+).
# Se ejecuta DESPUES de update_walls legacy. Asi todo el culling, Z, fog y
# compatibilidad Maker Studio siguen centralizados en 010_FrontWalls.rb.
#-------------------------------------------------------------------------------
class Mode7Renderer
  if private_method_defined?(:update_walls) &&
     !private_method_defined?(:_VERMEIL_EXT_orig_update_walls)
    alias_method :_VERMEIL_EXT_orig_update_walls, :update_walls
  end

  private

  def update_walls
    _VERMEIL_EXT_orig_update_walls
    return if !Mode7::Config::EXT_CORNERS_ENABLED ||
              !Mode7::Config::EXT_CORNERS_WALLS ||
              !Mode7::MKXPZExt.corners?

    @wall_data.each do |data|
      sprite, _wx, wyb, h, _entries, rigid_kind, _unify, _depth,
      _shadow_opacity, min_tx, _min_ty, max_tx, _max_ty, elevation = data
      next if !sprite || sprite.disposed?

      # NDSIndoorProp debe conservar tamano/silueta constantes; es una decision
      # visual explicita del plugin y corners no debe contradecirla.
      if rigid_kind == :indoor_prop
        sprite.corners = nil if sprite.corners
        next
      end

      # NDSIndoorWall fijo conserva su altura exacta. Su base sigue conectada al
      # raster affine; no se fuerza un techo con perspectiva adicional.
      if Mode7.raster_affine_mode? && rigid_kind == :wall_component &&
         Mode7::Config::INDOOR_WALL_FIXED_HEIGHT
        sprite.corners = nil if sprite.corners
        next
      end

      if !sprite.visible || !sprite.bitmap || sprite.bitmap.disposed?
        next
      end

      min_tx ||= ((_wx - sprite.bitmap.width / 2.0) / Game_Map::TILE_WIDTH).floor
      max_tx ||= ((_wx + sprite.bitmap.width / 2.0) / Game_Map::TILE_WIDTH).ceil - 1
      left_wx  = min_tx.to_f * Game_Map::TILE_WIDTH
      right_wx = (max_tx.to_f + 1.0) * Game_Map::TILE_WIDTH
      base_wy  = wyb.to_f
      elev     = elevation.to_f
      height   = h.to_f

      bl = Mode7.project(left_wx,  base_wy, elev)
      br = Mode7.project(right_wx, base_wy, elev)
      tl = Mode7.project(left_wx,  base_wy, elev + height)
      tr = Mode7.project(right_wx, base_wy, elev + height)
      next if !tl || !tr || !br || !bl

      sprite.corners = [
        tl[0], tl[1],
        tr[0], tr[1],
        br[0], br[1],
        bl[0], bl[1]
      ]
    end
  rescue Exception => e
    Console.echo_error("2.5D corners walls: #{e.message}") if defined?(Console)
  end
end

# Log una sola vez cuando ya existe el runtime.
EventHandlers.add(:on_frame_update, :vermeil_2p5d_mkxpz_caps,
  proc { Mode7::MKXPZExt.log_capabilities }
)

#-------------------------------------------------------------------------------
# Diagnostico rapido desde el Debug Menu.
#-------------------------------------------------------------------------------
module Mode7
  def self.mkxpz_ext_status_text
    caps = Mode7::MKXPZExt.capabilities
    [
      "MKXP-Z EXT",
      "Subpixel: #{caps[:subpixel] ? 'OK' : 'NO'}",
      "Corners: #{caps[:corners] ? 'OK' : 'NO'}",
      "Shader: #{caps[:shader] ? 'OK' : 'NO'}",
      "Viewport zoom: #{caps[:viewport_zoom] ? 'OK' : 'NO'}",
      "Projection: #{Mode7.map_mode}",
      "Geometry ground: #{Mode7::Config::GEOMETRY_GROUND_ENABLED ? 'ON' : 'OFF'}",
      "Band height runtime: #{Mode7.respond_to?(:nds_ground_band_height) ? Mode7.nds_ground_band_height : Mode7::Config::GEOMETRY_GROUND_BAND_HEIGHT}px",
      "Perfil: #{Mode7.respond_to?(:nds_performance_profile) ? Mode7.nds_performance_profile : :legacy}",
      "Volumen tiles: #{Mode7::Config::NDS_VOLUME_ENABLED ? 'ON' : 'OFF'}"
    ].join("\n")
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :vermeil_mkxpz_ext_status, {
    "name"        => _INTL("Estado MKXP-Z EXT / 2.5D"),
    "parent"      => :main,
    "description" => _INTL("Comprueba subpixel, corners y renderer NDS."),
    "effect"      => proc { pbMessage(Mode7.mkxpz_ext_status_text) }
  })
end
