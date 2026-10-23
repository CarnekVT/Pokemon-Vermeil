#===============================================================================
# Visual 2.5D HD - Puente Oscuridad Dinamica (Caruban)
#-------------------------------------------------------------------------------
# DarknessSprite usa Game_Character#screen_x/y (plano). Los sprites del mapa van
# proyectados via Sprite_Character. Sin este puente, luces/linternas quedan en
# coords 2D y no siguen el 2.5D.
#
# Solo carga si existe DarknessSprite (Optional en meta).
#===============================================================================
# El nombre de la clase puede existir en otras implementaciones de oscuridad.
# Solo envolver la API concreta de Dynamic Darkness; si no coincide, omitir
# el bridge sin impedir que Visual 2.5D ni las luces del juego arranquen.
if defined?(DarknessSprite) && DarknessSprite.is_a?(Class) &&
   [:get_nearby_events, :draw_all_lights, :refresh].all? { |method_name|
     DarknessSprite.method_defined?(method_name) ||
       DarknessSprite.private_method_defined?(method_name)
   }
  class DarknessSprite
    alias hd25_dd_get_nearby_events get_nearby_events unless method_defined?(:hd25_dd_get_nearby_events)
    def get_nearby_events
      return hd25_dd_get_nearby_events if !Visual25D.enabled?
      events_pos = []
      flashlights = []
      moving = false
      range = 13
      $game_map.events.each_value do |event|
        dx = event.x - $game_player.x
        dy = event.y - $game_player.y
        next if dx.abs > range || dy.abs > range
        props = get_event_properties(event)
        next unless props[:has_light] || props[:has_flashlight]
        moving = true if props[:has_flashlight] || event.moving? ||
                         (defined?(Game_PokeEvent) && event.is_a?(Game_PokeEvent))
        half = event.sprite_size[1] / 2
        ex, ey, wscale = Visual25D.project_darkness_point(event, half)
        if props[:has_light]
          switch_on = if props[:switch_id]
                        check_switch(event, props[:switch_id], props[:reverse_switch])
                      else
                        true
                      end
          radius = (props[:glow_size] * wscale).round
          radius = 1 if radius < 1
          events_pos.push([ex, ey, radius, switch_on, props[:is_static]])
        end
        if props[:has_flashlight]
          dist = getFlashlightDistance(event, props[:flashlight_dist])
          dist = (dist * wscale).round
          dist = 1 if dist < 1
          beam = (24 * wscale).round
          beam = 8 if beam < 8
          flashlights.push([ex, ey, event.direction, dist, beam])
        end
      end
      return { light_sources: events_pos, flashlights: flashlights, moving: moving }
    end

    alias hd25_dd_draw_all_lights draw_all_lights unless method_defined?(:hd25_dd_draw_all_lights)
    def draw_all_lights
      return hd25_dd_draw_all_lights if !Visual25D.enabled?
      return unless @cached_events
      # Misma logica que el plugin, pero circulo del jugador en coords 2.5D.
      events_pos = @cached_events[:light_sources].map do |ev|
        r = ev[2]
        r += @light_modifier unless ev[4]
        [ev[0], ev[1], r, ev[3]]
      end
      flashlights = @cached_events[:flashlights].map(&:dup)
      show_player_circle = Settings::SHOW_PLAYER_DARKNESS_CIRCLE && @radius > 0
      if show_player_circle
        cx, cy, pw = Visual25D.project_darkness_point($game_player, 0)
        cradius = ((@radius + @light_modifier) * pw).round
      else
        cx = Graphics.width / 2
        cy = Graphics.height / 2
        cradius = @radius + @light_modifier
      end
      (1..FADE_STEPS).each do |i|
        if show_player_circle
          drawCircle(cx, cy, FADE_STEPS, i, cradius)
          cradius = (cradius * FADE_FACTOR).floor
        end
        events_pos.each do |ev|
          next unless ev[3]
          drawCircle(ev[0], ev[1], FADE_STEPS, i, ev[2])
          ev[2] = (ev[2] * FADE_FACTOR).floor
        end
        next if i > 2
        flashlights.each do |ev|
          drawFlashlight(ev[0], ev[1], ev[2], ev[3], ev[4], i, 2)
          ev[4] = (ev[4] * FADE_FACTOR).floor
        end
      end
    end

    alias hd25_dd_refresh refresh unless method_defined?(:hd25_dd_refresh)
    def refresh(force = false)
      if Visual25D.enabled?
        stamp = Visual25D.projection_stamp
        if @hd25_dd_stamp != stamp || Visual25D.blending?
          force = true
          @hd25_dd_stamp = stamp
        end
        # La oscuridad sale antes si jugador y camara no cambian de tile.
        # Una luz que anda con la camara fija se quedaba en el sitio viejo.
        force = true if !force && hd25_nearby_light_moving?
      end
      hd25_dd_refresh(force)
    end

    def hd25_nearby_light_moving?
      return false if !$game_map || !$game_player
      range = 13
      px = $game_player.x
      py = $game_player.y
      $game_map.events.each_value do |event|
        next if (event.x - px).abs > range || (event.y - py).abs > range
        props = get_event_properties(event)
        next unless props[:has_light] || props[:has_flashlight]
        return true if event.moving? || (event.respond_to?(:jumping?) && event.jumping?)
        return true if defined?(Game_PokeEvent) && event.is_a?(Game_PokeEvent)
      end
      return false
    end
  end
end