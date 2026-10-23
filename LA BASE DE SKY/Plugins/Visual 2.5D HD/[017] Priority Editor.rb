#===============================================================================
# Visual 2.5D HD - Prioridades nativas para testeo (solo en memoria).
# Base = 1, segunda fila = 2, tercera = 3, para la geometría 2.5D.
# No se modifica Data/Tilesets.rxdata ni se guardan cambios en partidas.
#===============================================================================
module Visual25D
  module PriorityEditor
    @original = {}
    class << self
      def tileset
        return nil unless $game_map && $data_tilesets
        return $data_tilesets[$game_map.tileset_id]
      end

      def set_priority(tile_id, priority)
        ts = tileset
        return false unless ts && ts.priorities
        tid = tile_id.to_i
        return false if tid < 384
        return false if ts.priorities.respond_to?(:xsize) && tid >= ts.priorities.xsize
        p = priority.to_i.clamp(0, 5)
        key = [$game_map.tileset_id, tid]
        @original[key] = ts.priorities[tid] unless @original.key?(key)
        ts.priorities[tid] = p
        return true
      end

      def set_vertical_stack(bottom_tile_id, width, height)
        bottom = bottom_tile_id.to_i
        # Evitar que un objeto de varias columnas invada la fila de al lado.
        w = width.to_i.clamp(1, 8 - (bottom % 8))
        h = height.to_i.clamp(1, 5)
        changed = 0
        h.times do |up|
          w.times do |dx|
            tid = bottom - up * 8 + dx
            changed += 1 if set_priority(tid, up + 1)
          end
        end
        Visual25D.redraw_map if changed > 0
        return changed
      end

      def set_single(tile_id, priority)
        ok = set_priority(tile_id, priority)
        Visual25D.redraw_map if ok
        return ok
      end

      def restore
        count = 0
        @original.each do |(id, tid), value|
          ts = $data_tilesets && $data_tilesets[id]
          next unless ts && ts.priorities
          ts.priorities[tid] = value
          count += 1
        end
        @original.clear
        Visual25D.redraw_map if count > 0
        return count
      end

      def count
        return @original.size
      end
    end
  end
end

def pbVisual25DPriorityEditor
  return if !$game_map
  if !Visual25D::PriorityEditor.tileset
    pbMessage(_INTL("No hay tileset cargado."))
    return
  end
  loop do
    choice = pbMessage(
      _INTL("Prioridades nativas: base=1, encima=2,3...\\nTileset {1}; {2} ID(s) alterados en RAM.",
            $game_map.tileset_id, Visual25D::PriorityEditor.count),
      [_INTL("Prioridades de un objeto vertical"), _INTL("Prioridad de un tile"),
       _INTL("IDs cercanos al jugador"), _INTL("Restaurar originales"), _INTL("Salir")], 5)
    case choice
    when 0
      bottom = pbVisual25DChooseNumber(_INTL("ID del tile INFERIOR (384-9999)."), 384, 384, 9999)
      w = pbVisual25DChooseNumber(_INTL("Ancho del objeto en tiles (1-8)."), 1, 1, 8)
      h = pbVisual25DChooseNumber(_INTL("Altura en tiles (1-5)."), 3, 1, 5)
      total = Visual25D::PriorityEditor.set_vertical_stack(bottom, w, h)
      pbMessage(_INTL("Prioridades nativas asignadas en {1} tiles.", total))
    when 1
      tid = pbVisual25DChooseNumber(_INTL("ID del tile (384-9999)."), 384, 384, 9999)
      pri = pbVisual25DChooseNumber(_INTL("Prioridad visual nativa (0-5)."), 1, 0, 5)
      Visual25D::PriorityEditor.set_single(tid, pri)
    when 2
      x = $game_player.x
      y = $game_player.y
      rows = []
      [[x, y, "Actual"], [x, y-1, "Norte"], [x, y+1, "Sur"],
       [x-1, y, "Oeste"], [x+1, y, "Este"]].each do |xx, yy, name|
        next if xx < 0 || yy < 0 || xx >= $game_map.width || yy >= $game_map.height
        next unless $game_map.data
        ids = (0..2).map { |layer| $game_map.data[xx, yy, layer].to_i }
        rows << "#{name}: #{ids.join('/')}"
      end
      pbMessage(rows.join("\\n"))
    when 3
      total = Visual25D::PriorityEditor.restore
      pbMessage(_INTL("{1} prioridades originales restauradas.", total))
    else
      break
    end
  end
end

MenuHandlers.add(:debug_menu, :visual25d_priority_editor, {
  "name" => _INTL("2.5D: prioridades nativas (test)"),
  "parent" => :field_menu,
  "description" => _INTL("Cambiar prioridades reales en memoria; no editar tilesets en disco."),
  "effect" => proc { pbVisual25DPriorityEditor }
})
