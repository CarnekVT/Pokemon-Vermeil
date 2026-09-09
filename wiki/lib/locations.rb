# frozen_string_literal: true

# Ubicaciones: encuentros salvajes (GameData::Encounter) + objetos colocados en
# los mapas. Para los objetos reutiliza ItemBallPrinter (menú debug del juego),
# que escanea los eventos de cada Data/Map###.rxdata en busca de pbItemBall /
# pbReceiveItem.
#
# ponytail: mismo alcance que la herramienta del juego: solo eventos de mapa, no
# Common Events, y solo llamadas con un símbolo literal (`pbItemBall(:POTION)`).
# Los que usan una variable quedan fuera; ampliar si hace falta.
module Locations
  ENCOUNTER_METHOD_NAMES = {
    "Land" => "Hierba", "LandDay" => "Hierba (día)", "LandNight" => "Hierba (noche)",
    "LandMorning" => "Hierba (mañana)", "LandAfternoon" => "Hierba (tarde)", "LandEvening" => "Hierba (anochecer)",
    "PokeRadar" => "Pokéradar",
    "Cave" => "Cueva", "CaveDay" => "Cueva (día)", "CaveNight" => "Cueva (noche)",
    "CaveMorning" => "Cueva (mañana)", "CaveAfternoon" => "Cueva (tarde)", "CaveEvening" => "Cueva (anochecer)",
    "Water" => "Surf", "WaterDay" => "Surf (día)", "WaterNight" => "Surf (noche)",
    "WaterMorning" => "Surf (mañana)", "WaterAfternoon" => "Surf (tarde)", "WaterEvening" => "Surf (anochecer)",
    "OldRod" => "Caña vieja", "GoodRod" => "Caña buena", "SuperRod" => "Supercaña",
    "RockSmash" => "Golpe Roca", "HeadbuttLow" => "Golpe Cabeza", "HeadbuttHigh" => "Golpe Cabeza (árbol alto)",
    "BugContest" => "Concurso de captura"
  }.freeze

  module_function

  # @return [Array<Hash>] un elemento por mapa con datos:
  #   { map:, name:, encounters: [ { method:, method_name:, version:, slots: [...] } ],
  #     items: [ { item:, x:, y:, hidden:, kind:, event: } ] }
  def all
    by_map = Hash.new { |h, k| h[k] = { map: k, name: map_name(k), encounters: [], items: [] } }

    GameData::Encounter.each do |enc|
      enc.types.each do |type, slots|
        next if slots.nil? || slots.empty?

        total = slots.sum { |sl| sl[0] }.to_f
        by_map[enc.map][:encounters] << {
          method: type.to_s,
          method_name: ENCOUNTER_METHOD_NAMES[type.to_s] || type.to_s,
          version: enc.version,
          slots: slots.map { |weight, species, min, max|
            { species: species.to_s, min: min, max: (max || min),
              chance: (total.positive? ? (weight / total * 100).round(1) : nil) }
          }
        }
      end
    end

    scan_map_items(by_map) if defined?(ItemBallPrinter)

    by_map.values
          .select { |m| m[:encounters].any? || m[:items].any? }
          .sort_by { |m| m[:map] }
  end

  # ---------------------------------------------------------------------------

  def scan_map_items(by_map)
    Dir[File.join(Dir.pwd, "Data", "Map[0-9][0-9][0-9].rxdata")].sort.each do |path|
      map_id = File.basename(path)[/\d+/].to_i
      map = load_data(path)
      next unless map.respond_to?(:events) && map.events

      [[:item_balls, /pbItemBall\s*\(?\s*:(\w+)/], [:receive_items, /pbReceiveItem\s*\(?\s*:(\w+)/]].each do |kind, re|
        pairs = begin
          ItemBallPrinter.get_events_and_ball_scripts(map.events.values, kind)
        rescue StandardError
          []
        end
        pairs.each do |event, script|
          m = script.match(re)
          next unless m

          by_map[map_id][:items] << {
            item: m[1], x: event.x, y: event.y,
            hidden: !ItemBallPrinter.is_hidden_item?(event).nil?,
            kind: (kind == :item_balls ? "Poké Ball" : "Regalo de NPC"),
            event: event.name.to_s
          }
        end
      end
    end
  end

  def map_name(id)
    name = (pbGetMapNameFromId(id) if defined?(pbGetMapNameFromId))
    (name.nil? || name.empty?) ? "Mapa #{id}" : name
  rescue StandardError
    "Mapa #{id}"
  end
end
