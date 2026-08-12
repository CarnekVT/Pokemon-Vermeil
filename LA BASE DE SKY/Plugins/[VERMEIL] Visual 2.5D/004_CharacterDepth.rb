#===============================================================================
# [VERMEIL] Visual 2.5D - 004_CharacterDepth.rb
# Proyeccion 2.5D de personajes/eventos y desactivacion de reflejos 2D.
#===============================================================================

# Proyecta la posicion en pantalla de los personajes segun la camara 2.5D.
class Game_Character
  alias_method :_VERMEIL_25D_orig_screen_x, :screen_x unless method_defined?(:_VERMEIL_25D_orig_screen_x)
  alias_method :_VERMEIL_25D_orig_screen_y_ground, :screen_y_ground unless method_defined?(:_VERMEIL_25D_orig_screen_y_ground)
  alias_method :_VERMEIL_25D_orig_screen_z, :screen_z unless method_defined?(:_VERMEIL_25D_orig_screen_z)

  def screen_x
    return _VERMEIL_25D_orig_screen_x if !mode7_active_for_self?
    wx = @real_x.to_f / Game_Map::X_SUBPIXELS + (@width * Game_Map::TILE_WIDTH / 2)
    wy = mode7_world_y_ground
    # El actor comparte la proyeccion X/Y exacta del plano. Usar billboard o
    # screen_x vanilla lo dejaba visualmente fuera de su casilla al curvar Sky.
    # Sprite_Character toma la escala F/depth de este mismo punto de apoyo.
    elevation = mode7_world_elevation
    pr = Mode7.project(wx, wy, elevation)
    return -1000 if !pr
    return pr[0] + self.x_offset
  end

  def screen_y_ground
    return _VERMEIL_25D_orig_screen_y_ground if !mode7_active_for_self?
    wy = mode7_world_y_ground
    elevation = mode7_world_elevation
    return Mode7.overworld_project_y(wy, elevation)
  end

  def screen_z(height = 0)
    if mode7_active_for_self?
      return _VERMEIL_25D_orig_screen_z(height) if @always_on_top
      wy = mode7_world_y_ground
      elevation = mode7_world_elevation
      if @tile_id > 0
        begin
          priority = self.map.priorities[@tile_id]
          raise if priority.nil?
          return Mode7.depth_z_at_elevation(wy, elevation, priority, 0)
        rescue
          raise _INTL("El grafico del evento es un tile fuera de rango (evento {1}, mapa {2})",
                      @id, self.map.map_id)
        end
      end
      height_bias = height > Game_Map::TILE_HEIGHT ? Game_Map::TILE_HEIGHT - 1 : 0
      return Mode7.depth_z_at_elevation(wy, elevation, 0, height_bias)
    end
    _VERMEIL_25D_orig_screen_z(height)
  end

  def mode7_billboard_scale
    return 1.0 if !mode7_active_for_self?
    Mode7.object_scale_for_world_y(mode7_world_y_ground, mode7_world_elevation)
  rescue Exception
    1.0
  end

  private

  def mode7_active_for_self?
    return false if !$scene.is_a?(Scene_Map)
    return Mode7.rendering_now?
  end

  # Altura visual de volumen bajo los pies. Interpola durante el paso para que
  # subir/bajar una plataforma no produzca un salto de un frame.
  def mode7_world_elevation
    return 0.0 if !$game_map || !Mode7.respond_to?(:nds_surface_height_at)
    target = Mode7.nds_surface_height_at(@x, @y)
    return target if !moving?

    start_x = @move_initial_x
    start_y = @move_initial_y
    return target if start_x.nil? || start_y.nil?
    start = Mode7.nds_surface_height_at(start_x, start_y)

    progress = []
    if @x != start_x
      rx = @real_x.to_f / Game_Map::X_SUBPIXELS
      progress << ((rx - start_x).abs / (@x - start_x).abs.to_f)
    end
    if @y != start_y
      ry = @real_y.to_f / Game_Map::Y_SUBPIXELS
      progress << ((ry - start_y).abs / (@y - start_y).abs.to_f)
    end
    return target if progress.empty?
    t = (progress.sum / progress.length.to_f).clamp(0.0, 1.0)
    start + (target - start) * t
  rescue Exception
    0.0
  end

  # Escaleras/stairs nativas desplazan Y en pantalla mientras el personaje
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
      # V5: misma F/depth que suelo, edificios y props. Escala uniforme y pie
      # fijo; una categoria nunca puede cambiar el tamano por su cuenta.
      scale = @character.mode7_billboard_scale.to_f
      scale = 0.001 if scale <= 0.001
      self.zoom_x = scale
      self.zoom_y = scale

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
