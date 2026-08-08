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
    wy = mode7_world_y_ground
    pr = Mode7.project(wx, wy, 0)
    return -1000 if !pr
    return pr[0].round + self.x_offset
  end

  def screen_y_ground
    return _VERMEIL_25D_orig_screen_y_ground if !mode7_active_for_self?
    wx = @real_x.to_f / Game_Map::X_SUBPIXELS
    wy = mode7_world_y_ground
    pr = Mode7.project(wx, wy, 0)
    return 100_000 if !pr
    return pr[1].round
  end

  def screen_z(height = 0)
    if mode7_active_for_self?
      return _VERMEIL_25D_orig_screen_z(height) if @always_on_top
      wy = mode7_world_y_ground
      return Mode7.depth_z(wy, 0, height)
    end
    _VERMEIL_25D_orig_screen_z(height)
  end

  private

  def mode7_active_for_self?
    return false if !$scene.is_a?(Scene_Map)
    return Mode7.rendering_now?
  end

  # Escaleras laterales nativas desplazan Y en pantalla mientras el personaje
  # avanza X. 2.5D recalcula la proyeccion y antes perdia ese desplazamiento.
  def mode7_world_y_ground
    return @real_y.to_f / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT if !on_stair?
    # screen_x se consulta antes de Game_Character#moving? en algunos sprites.
    # El motor inicializa este offset alli, pero screen_y_ground lo suma aqui.
    @view_offset_y ||= 0 if self.is_a?(Game_Player) && defined?(SMOOTH_SCROLLING) && SMOOTH_SCROLLING
    native_y = _VERMEIL_25D_orig_screen_y_ground
    world_y = @real_y.to_f / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT
    flat_y = ((@real_y.to_f - map.display_y) / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT).round
    world_y + native_y - flat_y
  end
end

# --- NUEVO: Escala Dinamica de Sprites ---
# Adapta el tamanio del personaje a la distancia de la camara, igual que los
# muros: usa la misma base_hscale de las columnas, asi se encoje al caminar
# hacia el horizonte y crece al acercarse, manteniendo la escala coherente.
class Sprite_Character < RPG::Sprite
  alias_method :_VERMEIL_25D_orig_update_scale, :update unless method_defined?(:_VERMEIL_25D_orig_update_scale)

  def update
    _VERMEIL_25D_orig_update_scale
    return if disposed? || !@character

    if $scene.is_a?(Scene_Map) && Mode7.rendering_now?
      syb = @character.screen_y_ground
      wy = @character.send(:mode7_world_y_ground)
      k = Mode7.object_scale_for_world_y(wy)
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
