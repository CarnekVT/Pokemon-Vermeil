#===============================================================================
# [VERMEIL] Visual 2.5D - 004_CharacterDepth.rb
# Proyeccion 2.5D de personajes/eventos y desactivacion de reflejos 2D.
#===============================================================================

# Proyecta la posicion en pantalla de los personajes segun la camara 2.5D.
class Game_Character
  alias_method :_VERMEIL_25D_orig_screen_x, :screen_x
  alias_method :_VERMEIL_25D_orig_screen_y_ground, :screen_y_ground
  alias_method :_VERMEIL_25D_orig_screen_z, :screen_z

  def screen_x
    return _VERMEIL_25D_orig_screen_x if !mode7_active_for_self?
    wx = @real_x.to_f / Game_Map::X_SUBPIXELS + (@width * Game_Map::TILE_WIDTH / 2)
    wy = @real_y.to_f / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT
    pr = Mode7.project(wx, wy, 0)
    return -1000 if !pr
    return pr[0].round + self.x_offset
  end

  def screen_y_ground
    return _VERMEIL_25D_orig_screen_y_ground if !mode7_active_for_self?
    wx = @real_x.to_f / Game_Map::X_SUBPIXELS
    wy = @real_y.to_f / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT
    pr = Mode7.project(wx, wy, 0)
    return 100_000 if !pr
    return pr[1].round
  end

  def screen_z(height = 0)
    # El jugador y los eventos usan su posición proyectada en pantalla como Z.
    # Esto alinea su eje de profundidad exactamente con el de los muros.
    return screen_y_ground + height if mode7_active_for_self?
    
    ret = _VERMEIL_25D_orig_screen_z(height)
    return ret
  end

  private

  def mode7_active_for_self?
    return false if !$scene.is_a?(Scene_Map)
    return Mode7.rendering_now?
  end
end

# --- NUEVO: Escala Dinamica de Sprites ---
# Adapta el tamanio del personaje a la distancia de la camara usando la misma
# funcion SKY que usa el renderer. Con SKY_SPRITE_SCALE=0 el interior conserva
# el tamano del personaje y evita el efecto de "embudo" hacia el fondo.
class Sprite_Character < RPG::Sprite
  alias_method :_VERMEIL_25D_orig_update_scale, :update unless method_defined?(:_VERMEIL_25D_orig_update_scale)

  def update
    _VERMEIL_25D_orig_update_scale
    return if disposed? || !@character

    if $scene.is_a?(Scene_Map) && Mode7.rendering_now?
      syb = @character.screen_y_ground
      k = Mode7.base_hscale(syb)
      self.zoom_x = k if k && k > 0
      self.zoom_y = k if k && k > 0

      # Niebla (inerte hasta que Mode7.fog_alpha este definido)
      if Mode7.respond_to?(:fog_alpha)
        alpha = Mode7.fog_alpha(syb)
        if alpha > 0
          self.color.set(Mode7::Config::FOG_COLOR.red, Mode7::Config::FOG_COLOR.green, Mode7::Config::FOG_COLOR.blue, alpha)
        else
          self.color.set(0, 0, 0, 0)
        end
      end
    else
      # Restaura el tamanho original si se apaga la camara 2.5D
      self.zoom_x = 1.0
      self.zoom_y = 1.0
      self.color.set(0, 0, 0, 0)
    end
  end
end

# Desactiva los reflejos 2D en la camara 2.5D (coordenadas proyectadas
# dibujarian el reflejo fuera de sitio).
class Sprite_Reflection < RPG::Sprite
  alias_method :_VERMEIL_25D_orig_update, :update unless method_defined?(:_VERMEIL_25D_orig_update)

  def update
    _VERMEIL_25D_orig_update

    if $scene.is_a?(Scene_Map) && Mode7.rendering_now?
      self.visible = false
    end
  end
end