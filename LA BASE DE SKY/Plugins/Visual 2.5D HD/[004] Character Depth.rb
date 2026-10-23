#===============================================================================
# Visual 2.5D HD - Personajes sobre el plano
#-------------------------------------------------------------------------------
# Los sprites siguen siendo 2D: se colocan con la misma proyeccion que el suelo
# que pisan, de modo que un NPC al fondo del mapa se ve mas pequeno y uno en
# primer plano mas grande, sin desencajarse nunca de su casilla.
#
# El ALIAS va guardado y la REDEFINICION fuera: asi el enganche se vuelve a poner
# cada vez que se reejecutan los scripts (F12) sin capturarse a si mismo.
#===============================================================================

#===============================================================================
# La Z se sube en el personaje y no en su sprite porque no solo la usa el: las
# sombras del proyecto se la piden al propio personaje. Sin esto, un evento
# lejano da Z negativa, su sombra queda por debajo del suelo y desaparece
# mientras el evento se sigue viendo.
#===============================================================================
# Tag de altura en el nombre del evento, ej. "Farol [h5]".
# Se ancla como un tile de esa prioridad: pies en la casilla N filas al sur,
# sprite en la banda N (encima de la columna 1..N-1). Si el evento esta EN la
# cima actual (esa casilla ya es pri N-1), se trata como el siguiente tramo.
# Se lee 1 vez y se cachea (el nombre del editor no cambia en runtime).
HD25_EVENT_HEIGHT_TAG = /\[h(\d+)\]/i

class Game_Event
  def hd25_tag_height
    return @hd25_tag_height if !@hd25_tag_height.nil?
    match = self.name.match(HD25_EVENT_HEIGHT_TAG)
    @hd25_tag_height = match ? match[1].to_i : 0
    return @hd25_tag_height
  end

  def hd25_column_cell_cached(x, y, height)
    return @hd25_col_cell if @hd25_col_x == x && @hd25_col_y == y && @hd25_col_h == height
    return nil
  end

  def hd25_column_cell_set(x, y, height, cell)
    @hd25_col_x = x
    @hd25_col_y = y
    @hd25_col_h = height
    @hd25_col_cell = cell
  end
end

class Game_Character
  alias hd25_screen_z screen_z unless method_defined?(:hd25_screen_z)
  def screen_z(height = 0)
    return Visual25D.always_on_top_z if Visual25D.enabled? && @always_on_top
    value = hd25_screen_z(height)
    return value if !Visual25D.enabled?
    return Visual25D.character_z(value, self.screen_y_ground)
  end
end

# MakerStudio (y similares) hacen alias de Game_Event#screen_z ANTES de este
# plugin (Last=true). Ese alias queda pegado al Game_Character#screen_z viejo,
# sin Z_LIFT. Resultado: jugador (via Game_Character vivo) tapa cabezas de
# eventos altos en Y+1, y followers/NPCs se meten bajo arboles y otros sprites.
# Re-envolver aqui; character_z es idempotente si la cadena ya loftó.
class Game_Event
  alias hd25_event_screen_z screen_z unless method_defined?(:hd25_event_screen_z)
  def screen_z(height = 0)
    return Visual25D.always_on_top_z if Visual25D.enabled? && @always_on_top
    value = hd25_event_screen_z(height)
    return value if !Visual25D.enabled?
    tag_h = hd25_tag_height
    return Visual25D.event_column_z(self, tag_h, value) if tag_h > 0
    return Visual25D.character_z(value, self.screen_y_ground)
  end
end

class Sprite_Character
  alias hd25_update update unless method_defined?(:hd25_update)
  def update
    if Visual25D.enabled? && @character.is_a?(Game_Event) && !@character.should_update?
      hd25_follow_camera_while_culled
      return
    end
    hd25_update
    return if @character.is_a?(Game_Event) && !@character.should_update?
    hd25_apply_depth
  end

  # Evento fuera del culling 2D: el motor no toca x/y y el sprite se queda
  # clavado mientras el mapa corre. Recolocar con la camara; si ya esta fuera
  # de la pantalla proyectada, ocultar.
  def hd25_follow_camera_while_culled
    return if !@character || !@charbitmap
    return if !self.visible
    hd25_clear_proj_cache
    self.x = screen_x
    self.y = screen_y
    self.z = screen_z
    hd25_apply_depth
    range = 12 * Game_Map::TILE_HEIGHT
    if self.x < -range || self.x > Graphics.width + range ||
       self.y < -range || self.y > Graphics.height + range
      self.visible = false
    end
  end

  alias hd25_screen_z screen_z unless method_defined?(:hd25_screen_z)
  def screen_z
    return hd25_screen_z if !@character
    # El motor ya evita que lo de la fila de arriba recorte a un sprite mas
    # alto que una casilla, pero mide esa altura sin proyectar. Al proyectar,
    # un sprite normal pasa a ser mas alto que su casilla, asi que se le da la
    # altura medida en el mundo proyectado.
    ground = @character.screen_y_ground
    height = Visual25D.enabled? ? Visual25D.projected_height(@ch, ground) : @ch
    # El desplazamiento de Z ya lo aplica Game_Character#screen_z.
    return @character.screen_z(height)
  end

  # La posicion se entrega ya proyectada desde aqui, y no recolocando el sprite
  # despues: el motor coloca en su update todo lo que cuelga del personaje
  # (sombras del suelo, reflejos), y esos leen la posicion del sprite tal y como
  # este en ese momento. Si se corrigiera despues, se quedarian con la posicion
  # sin proyectar y se irian separando del personaje al desplazarse el mapa.
  alias hd25_screen_x screen_x unless method_defined?(:hd25_screen_x)
  def screen_x
    value = hd25_screen_x
    return value if !@character || !Visual25D.enabled?
    hd25_ensure_proj_cache
    return Visual25D.project_x(value, @hd25_wscale)
  end

  alias hd25_screen_y screen_y unless method_defined?(:hd25_screen_y)
  def screen_y
    value = hd25_screen_y
    return value if !@character || !Visual25D.enabled?
    hd25_ensure_proj_cache
    ground = @hd25_ground
    # Los saltos se miden sobre el suelo sin proyectar y se escalan con el.
    hop = ground - value
    return Visual25D.project_y(ground) -
           (hop * @hd25_wscale).round -
           Visual25D.character_lift(@character, ground) -
           Visual25D.shelf_character_lift(@character, ground) -
           Visual25D.event_tag_lift(@character, ground)
  end

  # ponytail: escala/suelo 1x por (pose, encuadre, stamp); screen_x/y/zoom reusan.
  def hd25_ensure_proj_cache
    map = @character.map
    rx = @character.real_x
    ry = @character.real_y
    dx = map ? map.display_x : nil
    dy = map ? map.display_y : nil
    stamp = Visual25D.projection_stamp
    return if @hd25_cache_rx == rx && @hd25_cache_ry == ry &&
              @hd25_cache_dx == dx && @hd25_cache_dy == dy &&
              @hd25_cache_stamp == stamp && @hd25_wscale
    @hd25_cache_rx = rx
    @hd25_cache_ry = ry
    @hd25_cache_dx = dx
    @hd25_cache_dy = dy
    @hd25_cache_stamp = stamp
    @hd25_ground = ground_y
    tag_h = @character.is_a?(Game_Event) ? @character.hd25_tag_height : 0
    if tag_h > 0
      @hd25_wscale, @hd25_cunit = Visual25D.event_column_scales(@character, tag_h, @hd25_ground)
    else
      @hd25_wscale = Visual25D.width_scale_at(@hd25_ground)
      @hd25_cunit = Visual25D.character_unit_at(@hd25_ground)
    end
  end

  def hd25_clear_proj_cache
    @hd25_cache_rx = nil
    @hd25_wscale = nil
    @hd25_cunit = nil
    @hd25_ground = nil
  end

  def hd25_apply_depth
    return if !@charbitmap || !@character
    if !Visual25D.enabled?
      return if !@hd25_depth
      self.zoom_x = TilemapRenderer::ZOOM_X
      self.zoom_y = TilemapRenderer::ZOOM_Y
      @hd25_depth = false
      @hd25_zoom_x = nil
      @hd25_zoom_y = nil
      @hd25_sig_rx = nil
      hd25_clear_proj_cache
      return
    end
    @hd25_depth = true
    hd25_ensure_proj_cache
    # ponytail: reusar ivars de ensure (sin releer map/rx/stamp).
    rx = @hd25_cache_rx
    ry = @hd25_cache_ry
    dx = @hd25_cache_dx
    dy = @hd25_cache_dy
    stamp = @hd25_cache_stamp
    if @hd25_sig_rx == rx && @hd25_sig_ry == ry &&
       @hd25_sig_dx == dx && @hd25_sig_dy == dy &&
       @hd25_sig_stamp == stamp && @hd25_sig_cw == @cw && @hd25_sig_ch == @ch
      return
    end
    @hd25_sig_rx = rx
    @hd25_sig_ry = ry
    @hd25_sig_dx = dx
    @hd25_sig_dy = dy
    @hd25_sig_stamp = stamp
    @hd25_sig_cw = @cw
    @hd25_sig_ch = @ch
    scale = @hd25_wscale
    # Un personaje es un elemento vertical, asi que se levanta con la camara en
    # vez de acortarse con el suelo. Si la altura usara la escala de profundidad,
    # el sprite se achataria y se estiraria al moverse por la pantalla.
    zoom_y = @hd25_cunit / TilemapRenderer::SOURCE_TILE_HEIGHT.to_f
    # Se redondea a pixeles enteros para que el sprite no "vibre" al reescalarse.
    zoom_x = (@cw && @cw > 0) ? (@cw * scale).round / @cw.to_f : scale
    zoom_y = (@ch && @ch > 0) ? (@ch * zoom_y).round / @ch.to_f : zoom_y
    if @hd25_zoom_x != zoom_x
      self.zoom_x = zoom_x
      @hd25_zoom_x = zoom_x
    end
    if @hd25_zoom_y != zoom_y
      self.zoom_y = zoom_y
      @hd25_zoom_y = zoom_y
    end
  end
end