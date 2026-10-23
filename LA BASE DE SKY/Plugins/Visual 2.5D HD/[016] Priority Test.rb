#===============================================================================
# Visual 2.5D HD - Prioridades temporales de testeo
# No edita Tilesets.rxdata, mapa, PBS ni colisiones de Game_Map.
# Solo reemplaza la prioridad visual que utiliza el renderer 2.5D.
#===============================================================================
module Visual25D
  class << self
    def test_priority_for(map_id, tile_id)
      return nil if !enabled? || !@test_priority_maps
      map_entries = @test_priority_maps[map_id]
      return nil if !map_entries
      return nil if tile_id.nil?
      return map_entries[tile_id.to_i]
    end

    def test_priority_for_sprite(sprite)
      return nil if !sprite || sprite.hd25_interior_flat || sprite.hd25_shelf_flat
      return test_priority_for(sprite.hd25_map_id, sprite.hd25_test_tile_id)
    end

    def set_test_priority(map_id, tile_id, priority)
      return if map_id.nil? || tile_id.to_i <= 0
      @test_priority_maps ||= {}
      entries = (@test_priority_maps[map_id.to_i] ||= {})
      value = priority.to_i
      value = 0 if value < 0
      value = Config::MAX_PRIORITY if value > Config::MAX_PRIORITY
      entries[tile_id.to_i] = value
      redraw_map
    end

    def clear_test_priorities
      @test_priority_maps = nil
      redraw_map
    end

    def test_priority_count
      return 0 if !@test_priority_maps
      return @test_priority_maps.values.inject(0) { |sum, entries| sum + entries.length }
    end

    alias hd25_real_geom_priority geom_priority unless method_defined?(:hd25_real_geom_priority)
    def geom_priority(tile)
      changed = test_priority_for_sprite(tile)
      return changed unless changed.nil?
      return hd25_real_geom_priority(tile)
    end

    alias hd25_real_tile_maybe_raised? tile_maybe_raised? unless method_defined?(:hd25_real_tile_maybe_raised?)
    def tile_maybe_raised?(tile)
      changed = test_priority_for_sprite(tile)
      return changed > 0 unless changed.nil?
      return hd25_real_tile_maybe_raised?(tile)
    end

    alias hd25_real_project_tile_z_selective project_tile_z_selective unless method_defined?(:hd25_real_project_tile_z_selective)
    def project_tile_z_selective(tile, row, layer, pixel_offset_y)
      changed = test_priority_for_sprite(tile)
      if !changed.nil?
        if changed > 0
          project_tile_z(tile, row, layer, pixel_offset_y)
        else
          demote_stale_ground_z(tile)
        end
        return
      end
      hd25_real_project_tile_z_selective(tile, row, layer, pixel_offset_y)
    end

    alias hd25_real_cull_priority cull_priority unless method_defined?(:hd25_real_cull_priority)
    def cull_priority(tile)
      changed = test_priority_for_sprite(tile)
      return changed unless changed.nil?
      return hd25_real_cull_priority(tile)
    end

    # Las paredes interiores consultan las prioridades en la rejilla del mapa.
    # Calcularlas de nuevo solo cuando existe un override en este mapa.
    alias hd25_real_own_priority own_priority unless method_defined?(:hd25_real_own_priority)
    def own_priority(map, cx, cy)
      overrides = @test_priority_maps && map && @test_priority_maps[map.map_id]
      return hd25_real_own_priority(map, cx, cy) if !enabled? || !overrides || overrides.empty?
      return hd25_real_own_priority(map, cx, cy) if cx.nil? || cy.nil?
      return 0 if cx < 0 || cy < 0 || cx >= map.width || cy >= map.height
      result = 0
      if map.data
        3.times do |layer|
          tid = map.data[cx, cy, layer].to_i
          next if tid <= 0
          v = overrides.key?(tid) ? overrides[tid] : (map.priorities[tid] || 0).to_i
          result = v if v > result
        end
      end
      if defined?(MakerStudio) && MakerStudio::ENABLED && map == $game_map
        MakerStudio.each_extended_tile_at(cx, cy) do |tid, td|
          v = overrides.key?(tid.to_i) ? overrides[tid.to_i] : MakerStudio.resolve_band_priority(map, tid, td).to_i
          result = v if v > result
        end
      end
      return result
    end
  end
end

# Herramienta de depuracion: el ID puede consultarse en el tileset o en la
# rejilla del jugador. Los cambios solo duran esta sesion del juego.
def pbVisual25DTestTilePriority
  return if !$game_map || !$game_player
  loop do
    sample = []
    if $game_map.data
      3.times do |layer|
        tid = $game_map.data[$game_player.x, $game_player.y, layer].to_i
        sample << _INTL("Capa {1}: ID {2}", layer + 1, tid) if tid > 0
      end
    end
    info = sample.empty? ? _INTL("Sin tiles nativos bajo el jugador.") : sample.join(" / ")
    choice = pbMessage(
      _INTL("Prioridad VISUAL de prueba (2.5D solamente).\nMapa: {1}.\n{2}\nCambios activos: {3}.",
            $game_map.map_id, info, Visual25D.test_priority_count),
      [_INTL("Cambiar prioridad por ID"), _INTL("Borrar todas las pruebas"), _INTL("Salir")], 3
    )
    case choice
    when 0
      proposed = $game_map.data ? $game_map.data[$game_player.x, $game_player.y, 2].to_i : 1
      proposed = 1 if proposed <= 0
      tid = pbVisual25DChooseNumber(_INTL("ID del tile a modificar (1-9999)."), proposed, 1, 9999)
      current = Visual25D.test_priority_for($game_map.map_id, tid)
      current = ($game_map.priorities[tid] || 0).to_i if current.nil?
      current = [[current, 0].max, Visual25D::Config::MAX_PRIORITY].min
      pri = pbVisual25DChooseNumber(
        _INTL("Prioridad VISUAL para tile ID {1} (0-{2}).", tid, Visual25D::Config::MAX_PRIORITY),
        current, 0, Visual25D::Config::MAX_PRIORITY
      )
      Visual25D.set_test_priority($game_map.map_id, tid, pri)
    when 1
      Visual25D.clear_test_priorities
      pbMessage(_INTL("Prioridades temporales restauradas."))
    else
      break
    end
  end
end

MenuHandlers.add(:debug_menu, :visual25d_priority_test, {
  "name" => _INTL("2.5D: prioridad de tiles (PRUEBA)"),
  "parent" => :field_menu,
  "description" => _INTL("Ajusta prioridad VISUAL por ID en este mapa, sin editar tilesets ni colisiones."),
  "effect" => proc { pbVisual25DTestTilePriority }
})
