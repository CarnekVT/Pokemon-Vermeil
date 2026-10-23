#===============================================================================
# Visual 2.5D HD - Sprites auxiliares
#-------------------------------------------------------------------------------
# Todo lo que se dibuja sobre un personaje sin ser su sprite (sombras, plantas,
# animaciones de hierba...) calcula su sitio con coordenadas sin proyectar, asi
# que se descuadraba respecto a los sprites: al moverse recorria mas distancia
# que ellos. Aqui se proyectan por el mismo sitio que todo lo demas.
#
# Y como con la camara alejada se ven mas casillas de las que el motor da por
# visibles, tambien se amplia el margen con el que decide que un evento esta
# fuera de pantalla y deja de actualizarse.
#===============================================================================
# El ALIAS va guardado y la REDEFINICION fuera: asi el enganche se vuelve a poner
# cada vez que se reejecutan los scripts (F12) sin capturarse a si mismo.
#===============================================================================
module ScreenPosHelper
  class << self
    alias hd25_pbScreenX pbScreenX unless method_defined?(:hd25_pbScreenX)
    def pbScreenX(ch)
      value = hd25_pbScreenX(ch)
      return value if !Visual25D.enabled?
      ground = ch.screen_y_ground
      scale = Visual25D.width_scale_at(ground)
      if ch.is_a?(Game_Event) && ch.hd25_tag_height > 0
        scale, _cunit = Visual25D.event_column_scales(ch, ch.hd25_tag_height, ground)
      end
      return Visual25D.project_x(value, scale)
    end

    alias hd25_pbScreenY pbScreenY unless method_defined?(:hd25_pbScreenY)
    def pbScreenY(ch)
      value = hd25_pbScreenY(ch)
      return value if !Visual25D.enabled?
      ground = ch.screen_y_ground
      # El salto se mide sobre el suelo sin proyectar y se escala con el.
      hop = ground - value
      scale = Visual25D.width_scale_at(ground)
      if ch.is_a?(Game_Event) && ch.hd25_tag_height > 0
        scale, _cunit = Visual25D.event_column_scales(ch, ch.hd25_tag_height, ground)
      end
      return Visual25D.project_y(ground) -
             (hop * scale).round -
             Visual25D.character_lift(ch, ground) -
             Visual25D.shelf_character_lift(ch, ground) -
             Visual25D.event_tag_lift(ch, ground)
    end

    alias hd25_pbScreenZoomX pbScreenZoomX unless method_defined?(:hd25_pbScreenZoomX)
    def pbScreenZoomX(ch)
      value = hd25_pbScreenZoomX(ch)
      return value if !Visual25D.enabled?
      ground = ch.screen_y_ground
      scale = Visual25D.width_scale_at(ground)
      if ch.is_a?(Game_Event) && ch.hd25_tag_height > 0
        scale, _cunit = Visual25D.event_column_scales(ch, ch.hd25_tag_height, ground)
      end
      return value * scale
    end

    alias hd25_pbScreenZoomY pbScreenZoomY unless method_defined?(:hd25_pbScreenZoomY)
    def pbScreenZoomY(ch)
      value = hd25_pbScreenZoomY(ch)
      return value if !Visual25D.enabled?
      # Misma unidad vertical que Sprite_Character (no width_scale: achataba).
      ground = ch.screen_y_ground
      cunit = Visual25D.character_unit_at(ground)
      if ch.is_a?(Game_Event) && ch.hd25_tag_height > 0
        _scale, cunit = Visual25D.event_column_scales(ch, ch.hd25_tag_height, ground)
      end
      return value * (cunit / TilemapRenderer::SOURCE_TILE_HEIGHT.to_f)
    end
  end
end

#===============================================================================
# Animaciones ancladas a una casilla, como el revuelo de la hierba alta.
#===============================================================================
if defined?(AnimationContainerSprite)
  class AnimationContainerSprite
    alias hd25_setCoords setCoords unless method_defined?(:hd25_setCoords)
    def setCoords
      hd25_setCoords
      return if !Visual25D.enabled?
      # Y plana, antes de proyectar: las celdas escalan con esta fila.
      @hd25_ground = self.y
      ground = @hd25_ground
      self.x = Visual25D.project_x(self.x, Visual25D.width_scale_at(ground))
      self.y = Visual25D.project_y(ground) -
               Visual25D.cell_lift(@map, @tileX, @tileY, ground)
    end

    # Las celdas son sprites sueltos. El zoom del contenedor no las encoge:
    # su tamaño sale de cell_data y el desplazamiento es en pixeles planos.
    alias hd25_animation_set_sprites animation_set_sprites unless method_defined?(:hd25_animation_set_sprites)
    def animation_set_sprites(sprites, cell_data, position, quick_update = false)
      hd25_animation_set_sprites(sprites, cell_data, position, quick_update)
      return if !Visual25D.enabled? || @hd25_ground.nil?
      scale = Visual25D.width_scale_at(@hd25_ground)
      return if (scale - 1.0).abs < 0.01
      ax, ay = hd25_anim_anchor(position)
      16.times do |i|
        sprite = sprites[i]
        next if !sprite || sprite.disposed? || !sprite.visible
        sprite.x = ax + ((sprite.x - ax) * scale)
        sprite.y = ay + ((sprite.y - ay) * scale)
        pattern = cell_data[i, 0]
        next if pattern.nil? || pattern == -1
        zoom = cell_data[i, 3].to_f / 100.0 * scale
        sprite.zoom_x = zoom
        sprite.zoom_y = zoom
      end
    end

    def hd25_anim_anchor(position)
      if position == 3
        if viewport
          return [viewport.rect.width / 2, viewport.rect.height - 160]
        end
        return [320, 240]
      end
      sprite_x = x - ox + (src_rect.width / 2)
      sprite_y = y - oy
      if src_rect.height > 1
        sprite_y += src_rect.height / 2 if position == 1
        sprite_y += src_rect.height if position == 2
      end
      return [sprite_x, sprite_y]
    end
  end
end

#===============================================================================
# Huellas en la arena. Se colocan con el display_x/y del mapa en crudo y sin
# zoom, igual que la hierba de arriba, asi que sin proyectar quedan flotando
# fuera de su casilla y con el tamano de una pantalla sin perspectiva.
#===============================================================================
if Sprite_Character.method_defined?(:update_footsteps)
  class Sprite_Character
    alias hd25_update_footsteps update_footsteps unless method_defined?(:hd25_update_footsteps)
    def update_footsteps
      return hd25_update_footsteps if !@steps || !Visual25D.enabled?
      for i in 0...@steps.size
        next unless @steps[i]
        sprite, map, x, y = @steps[i]
        # Misma cuenta que el motor (fila+1, luego se sube un tile), pero
        # guardando la fila sin proyectar para escalar por ella.
        ground = (-map.display_y / Game_Map::Y_SUBPIXELS) + ((y + 1) * Game_Map::TILE_HEIGHT)
        raw_x  = (-map.display_x / Game_Map::X_SUBPIXELS) + (x * Game_Map::TILE_WIDTH)
        scale = Visual25D.width_scale_at(ground)
        sprite.x = Visual25D.project_x(raw_x, scale)
        sprite.y = Visual25D.project_y(ground) - (Game_Map::TILE_HEIGHT * scale).round -
                   Visual25D.cell_lift(map, x, y, ground)
        sprite.zoom_x = scale
        sprite.zoom_y = scale
        sprite.opacity -= FootprintsSettings::FADE_OUT_SPEED
        if sprite.opacity <= 0
          sprite.dispose
          @steps[i] = nil
        end
      end
      @steps.compact!
    end
  end
end

#===============================================================================
# Mapas conectados. El motor los descarga en cuanto se alejan 6 casillas de la
# pantalla, y con la camara alejada se siguen viendo: al descargarse se llevan
# por delante sus tiles y sus eventos, que es lo que se ve desaparecer y volver
# al acercarse.
#===============================================================================
module MapFactoryHelper
  class << self
    alias hd25_mapInRange? mapInRange? unless method_defined?(:hd25_mapInRange?)
    def mapInRange?(map)
      return hd25_mapInRange?(map) if !Visual25D.enabled?
      return Visual25D.map_in_range?(map.display_x, map.display_y, map.width, map.height)
    end

    alias hd25_mapInRangeById? mapInRangeById? unless method_defined?(:hd25_mapInRangeById?)
    def mapInRangeById?(id, dispx, dispy)
      return hd25_mapInRangeById?(id, dispx, dispy) if !Visual25D.enabled?
      dims = getMapDims(id)
      return Visual25D.map_in_range?(dispx, dispy, dims[0], dims[1])
    end
  end
end

#===============================================================================
# Tabla de filas de este frame antes de Sprite_Character (el tilemap va despues).
#===============================================================================
class Spriteset_Map
  alias hd25_spriteset_update update unless method_defined?(:hd25_spriteset_update)
  def update
    Visual25D.sync_projection_from_map!($game_map) if Visual25D.enabled?
    hd25_spriteset_update
  end
end

#===============================================================================
# Culling de eventos.
#===============================================================================
class Game_Event
  # El motor descarta lo que se salga dos casillas de la pantalla, midiendolo
  # sin proyectar. Aqui se mira donde acaba dibujado de verdad el sprite, que
  # con la camara alejada o inclinada cae bastante mas arriba.
  #
  # El margen es generoso a proposito: un evento que deja de actualizarse se
  # queda congelado en pantalla mientras el mapa sigue desplazandose, y se le ve
  # arrastrarse fuera de su casilla junto con su sombra.
  def hd25_within_extended_view?
    ground = self.screen_y_ground
    scale = Visual25D.width_scale_at(ground)
    x = Visual25D.project_x(self.screen_x, scale)
    y = Visual25D.project_y(ground)
    width = (@sprite_size ? @sprite_size[0] : Game_Map::TILE_WIDTH) * scale
    # Se da el doble de alto por lo que crecen los elementos verticales.
    height = (@sprite_size ? @sprite_size[1] : Game_Map::TILE_HEIGHT) * scale * 2
    range = 12 * Game_Map::TILE_HEIGHT
    return false if x - (width / 2) > Graphics.width + range
    return false if x + (width / 2) < -range
    return false if y - height > Graphics.height + range
    return false if y < -range
    return true
  end

  # Misma idea que el culling 2D del motor, pero con las casillas extra de la
  # rejilla 2.5D. No usa la tabla de proyección: al correr esa tabla va un
  # frame atras y hd25_within_extended_view? daba falsos "fuera", congelando
  # sprites encima del mapa hasta que el scroll lento los reenganchaba.
  def hd25_within_grid_margin?
    map = self.map
    return false if !map
    extra_x = Visual25D.margin_columns.to_i + 4
    extra_y = Visual25D.margin_rows.to_i + 4
    range_x = 2 + extra_x
    range_y = 2 + extra_y
    event_x = @real_x / Game_Map::REAL_RES_X
    event_y = @real_y / Game_Map::REAL_RES_Y
    sprite_w_tiles = (@sprite_size ? @sprite_size[0] : Game_Map::TILE_WIDTH) / Game_Map::TILE_WIDTH
    sprite_h_tiles = (@sprite_size ? @sprite_size[1] : Game_Map::TILE_HEIGHT) / Game_Map::TILE_HEIGHT
    return false if event_x - (sprite_w_tiles / 2) > map.display_x_tiles + map.screen_width_tiles + range_x
    return false if event_x + (sprite_w_tiles / 2) < map.display_x_tiles - range_x
    return false if event_y - sprite_h_tiles + 1 > map.display_y_tiles + map.screen_height_tiles + range_y
    return false if event_y + 1 < map.display_y_tiles - range_y
    return true
  end

  alias hd25_should_update? should_update? unless method_defined?(:hd25_should_update?)
  def should_update?(recalc = false)
    return @to_update if !recalc
    return true if hd25_should_update?(true)
    return false if !Visual25D.enabled?
    return hd25_within_grid_margin?
  end
end

#===============================================================================
# Encuentros salvajes visibles: que no se borren ni dejen de animarse mientras
# sigan a la vista. El despawn por distancia viene desactivado de serie en el
# plugin, asi que esa parte solo entra si se llega a activar.
#===============================================================================
if defined?(Game_PokeEvent)
  class Game_PokeEvent
    if method_defined?(:onscreen?) || method_defined?(:hd25_onscreen?)
      alias hd25_onscreen? onscreen? unless method_defined?(:hd25_onscreen?)
      def onscreen?
        return hd25_onscreen? if !Visual25D.enabled?
        return true if hd25_within_grid_margin?
        return hd25_within_extended_view?
      end
    end

    # El despawn por distancia viene desactivado de serie en el plugin, asi que
    # esta parte solo entra si se llega a activar.
    if private_method_defined?(:check_distance_despawn) ||
       private_method_defined?(:hd25_check_distance_despawn)
      unless private_method_defined?(:hd25_check_distance_despawn)
        alias hd25_check_distance_despawn check_distance_despawn
      end
      def check_distance_despawn
        return if Visual25D.enabled? && hd25_within_extended_view?
        hd25_check_distance_despawn
      end
      private :check_distance_despawn
    end
  end
end