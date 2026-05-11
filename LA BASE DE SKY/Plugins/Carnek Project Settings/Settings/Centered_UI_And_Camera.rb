#===============================================================================
# Plugin: Carnek Project Settings - Centered UI and Camera Scaling
#===============================================================================

module CarnekProjectSettings
  def self.screen_center_x
    return ((Graphics.width / 2) - (Game_Map::TILE_WIDTH / 2)) * Game_Map::X_SUBPIXELS
  end

  def self.screen_center_y
    return ((Graphics.height / 2) - (Game_Map::TILE_HEIGHT / 2)) * Game_Map::Y_SUBPIXELS
  end
end

class Game_Player
  alias carnek_settings_center center unless method_defined?(:carnek_settings_center)
  alias carnek_settings_update_screen_position update_screen_position unless method_defined?(:carnek_settings_update_screen_position)

  def carnek_screen_center_x
    return CarnekProjectSettings.screen_center_x
  end

  def carnek_screen_center_y
    return CarnekProjectSettings.screen_center_y
  end

  def center(x, y)
    self.map.display_x = (x * Game_Map::REAL_RES_X) - carnek_screen_center_x
    self.map.display_y = (y * Game_Map::REAL_RES_Y) - carnek_screen_center_y
  end

  def update_screen_position(last_real_x, last_real_y)
    if $game_switches && defined?(Settings::CAMERA_FANCY) && $game_switches[Settings::CAMERA_FANCY]
      carnek_settings_update_screen_position(last_real_x, last_real_y)
      return
    end
    return if self.map.scrolling? || !(@moved_last_frame || @moved_this_frame)
    center_x = carnek_screen_center_x
    center_y = carnek_screen_center_y
    if (@real_x < last_real_x && @real_x < $game_map.display_x + center_x) ||
       (@real_x > last_real_x && @real_x > $game_map.display_x + center_x)
      self.map.display_x += @real_x - last_real_x
    end
    if (@real_y < last_real_y && @real_y < $game_map.display_y + center_y) ||
       (@real_y > last_real_y && @real_y > $game_map.display_y + center_y)
      self.map.display_y += @real_y - last_real_y
    end
  end
end

class Game_Temp
  alias carnek_settings_camera_x_set camera_x= unless method_defined?(:carnek_settings_camera_x_set)
  alias carnek_settings_camera_y_set camera_y= unless method_defined?(:carnek_settings_camera_y_set)

  def camera_x=(value)
    @camera_x = value
    @camera_pos = [0, 0] if !@camera_pos
    @camera_pos[0] = ((value == 0) ? 0 : (@camera_x * Game_Map::REAL_RES_X) - CarnekProjectSettings.screen_center_x)
  end

  def camera_y=(value)
    @camera_y = value
    @camera_pos = [0, 0] if !@camera_pos
    @camera_pos[1] = ((value == 0) ? 0 : (@camera_y * Game_Map::REAL_RES_Y) - CarnekProjectSettings.screen_center_y)
  end
end

if defined?(FancyCamera)
  class Game_Player
    alias carnek_settings_fancy_update_screen_position update_screen_position unless method_defined?(:carnek_settings_fancy_update_screen_position)

    def update_screen_position(last_real_x, last_real_y)
      if !($game_switches && defined?(Settings::CAMERA_FANCY) && $game_switches[Settings::CAMERA_FANCY])
        carnek_settings_fancy_update_screen_position(last_real_x, last_real_y)
        return
      end
      return if self.map.scrolling?
      target = [@real_x - carnek_screen_center_x, @real_y - carnek_screen_center_y]
      target = $game_temp.camera_pos if $game_temp.camera_pos && $game_temp.camera_pos[0] != 0 && $game_temp.camera_pos[1] != 0
      if $game_temp.camera_target_event && $game_temp.camera_target_event != 0
        event = $game_map.events[$game_temp.camera_target_event]
        target = [event.real_x - carnek_screen_center_x, event.real_y - carnek_screen_center_y] if event
      end
      if $game_temp.camera_shake > 0
        power = $game_temp.camera_shake * 25
        target = [target[0] + rand(-power..power), target[1] + rand(-power..power)]
      end
      if $game_temp.camera_offset && $game_temp.camera_offset != [0, 0]
        target = [target[0] + ($game_temp.camera_offset[0] * Game_Map::REAL_RES_X), target[1] + ($game_temp.camera_offset[1] * Game_Map::REAL_RES_Y)]
      end
      distance = Math.sqrt((target[0] - self.map.display_x)**2 + (target[1] - self.map.display_y)**2)
      speed = $game_temp.camera_speed * 0.2
      if distance < 0.75
        self.map.display_x = target[0]
        self.map.display_y = target[1]
      else
        self.map.display_x = ease_in_out(self.map.display_x, target[0], speed)
        self.map.display_y = ease_in_out(self.map.display_y, target[1], speed)
      end
    end
  end
end

#===============================================================================
# Centrado de la Interfaz de Usuario (UI)
#===============================================================================
# La mayoría de las ventanas de la UI heredan de Window_Base. Al modificar su
# inicialización, podemos desplazarlas para que aparezcan centradas.
class Window_Base < Window
  alias :carnek_centered_ui_initialize :initialize
  def initialize(x, y, width, height)
    # No aplicar el centrado a la UI del Editor de Animaciones
    if defined?(AnimationEditor) && $scene.is_a?(AnimationEditor)
      carnek_centered_ui_initialize(x, y, width, height)
      return
    end
    # Heurística para ajustar ventanas alineadas en la parte inferior (como los cuadros de mensaje).
    # Se asume que una ventana cuya coordenada Y se calcula en base a la altura total
    # de la pantalla debe ser ajustada para el área de UI lógica.
    if y > Settings::UI_BASE_HEIGHT && y + height > Graphics.height - 4
      y = y - Graphics.height + Settings::UI_BASE_HEIGHT
    end
    # Aplica el desplazamiento para centrar la ventana.
    carnek_centered_ui_initialize(x + Settings.ui_origin_x, y + Settings.ui_origin_y, width, height)
  end
end

# Las imágenes mostradas con "Mostrar Imagen" son elementos de la UI y necesitan
# ser desplazadas. Modificamos sus getters para añadir el desplazamiento.
class Sprite_Picture < Sprite
  def x
    # No aplicar el centrado a la UI del Editor de Animaciones
    return super if defined?(AnimationEditor) && $scene.is_a?(AnimationEditor)
    return super + Settings.ui_origin_x
  end

  def y
    # No aplicar el centrado a la UI del Editor de Animaciones
    return super if defined?(AnimationEditor) && $scene.is_a?(AnimationEditor)
    return super + Settings.ui_origin_y
  end
end
