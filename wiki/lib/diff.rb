# frozen_string_literal: true

require "json"

# Compara el estado actual del juego contra wiki/baseline.json (el snapshot que
# publica La Base de Sky). Marca cada entidad como nueva / modificada y lista los
# campos que cambiaron. Si no hay baseline, no marca nada.
module Diff
  FIELD_LABELS = {
    "name" => "Nombre", "form_name" => "Nombre de forma", "types" => "Tipos",
    "base_stats" => "Estadísticas base", "bst" => "Total de estadísticas", "evs" => "EVs que da",
    "abilities" => "Habilidades", "hidden_abilities" => "Habilidades ocultas",
    "moves" => "Movimientos por nivel", "tutor_moves" => "Movimientos de MT/tutor",
    "egg_moves" => "Movimientos huevo", "egg_groups" => "Grupos huevo", "hatch_steps" => "Pasos de incubación",
    "gender_ratio" => "Ratio de género", "growth_rate" => "Crecimiento", "catch_rate" => "Ratio de captura",
    "base_exp" => "Experiencia base", "happiness" => "Felicidad base", "height" => "Altura", "weight" => "Peso",
    "generation" => "Generación", "category" => "Categoría", "pokedex" => "Entrada Pokédex",
    "wild_items" => "Objetos salvajes", "evolves_to" => "Evoluciones", "prevo" => "Preevolución",
    "mega_stone" => "Piedra Mega", "mega_move" => "Movimiento Mega",
    "type" => "Tipo", "power" => "Potencia", "accuracy" => "Precisión",
    "total_pp" => "PP", "priority" => "Prioridad", "target" => "Objetivo", "function_code" => "Código de efecto",
    "flags" => "Propiedades", "effect_chance" => "Probabilidad de efecto", "description" => "Descripción",
    "name_plural" => "Nombre plural", "pocket" => "Bolsillo", "price" => "Precio", "sell_price" => "Precio de venta",
    "bp_price" => "Precio en PC", "field_use" => "Uso en el mapa", "battle_use" => "Uso en combate",
    "consumable" => "Consumible", "machine" => "MT/MO", "type_name" => "Tipo de entrenador",
    "version" => "Versión", "lose_text" => "Frase de derrota", "items" => "Objetos", "party" => "Equipo",
    "weaknesses" => "Debilidades", "resistances" => "Resistencias", "immunities" => "Inmunidades"
  }.freeze

  CATEGORY_LABELS = {
    "species" => "Pokémon", "moves" => "Movimientos", "abilities" => "Habilidades",
    "items" => "Objetos", "trainers" => "Entrenadores", "types" => "Tipos"
  }.freeze

  module_function

  def empty
    { empty: true, counts: {}, removed: {} }
  end

  # @param path [String]
  # @return [Hash, nil] baseline (categoría => id => campos) o nil si no existe
  def load(path)
    return nil unless path && File.exist?(path)

    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    warn "No se pudo leer la baseline #{path}: #{e.message}"
    nil
  end

  # @param current [Hash] Snapshot.reduce(data) (claves símbolo)
  # @param baseline [Hash] baseline cargada (claves string)
  # @return [Hash]
  def compare(current, baseline)
    current = JSON.parse(JSON.generate(current))
    result = { empty: false, counts: Hash.new(0), removed: {} }

    current.each do |cat, entries|
      next unless baseline.key?(cat)

      base_cat = baseline[cat]
      per_entity = {}
      renamed = cat == "abilities" ? renamed_abilities(base_cat, entries) : {}

      entries.each do |id, fields|
        if !base_cat.key?(id)
          if (old_id = renamed[id])
            changed = diff_fields(base_cat[old_id], fields)
            unless changed.empty?
              per_entity[id] = { status: "modificado", fields: changed }
              result[:counts]["modificadas"] += 1
            end
            next
          end
          per_entity[id] = { status: "nuevo", fields: [] }
          result[:counts]["nuevas"] += 1
        else
          changed = diff_fields(base_cat[id], fields)
          next if changed.empty?

          per_entity[id] = { status: "modificado", fields: changed }
          result[:counts]["modificadas"] += 1
        end
      end

      removed = base_cat.keys - entries.keys - renamed.values
      if cat == "species"
        removed.reject! do |id|
          entry = base_cat[id]
          same_form_present = entries.values.any? do |current_entry|
            comparison_value(current_entry["name"]) == comparison_value(entry["name"]) &&
              comparison_value(current_entry["form_name"]) == comparison_value(entry["form_name"])
          end
          base_id = id.sub(/_\d+\z/, "")
          same_form_present || (entry["form_name"].to_s.empty? && base_id != id && entries.key?(base_id))
        end
      end
      unless removed.empty?
        result[:removed][cat] = removed.map do |id|
          fields = base_cat[id] || {}
          name = fields["name"].to_s
          form = fields["form_name"]
          name = id if name.empty?
          name = "#{name} — #{form}" if cat == "species" && form && !form.empty?
          { id: id, name: name }
        end
        result[:counts]["eliminadas"] += removed.size
      end

      result[cat.to_sym] = per_entity
    end

    result[:empty] = true if result[:counts].values.sum.zero?
    result
  end

  def comparison_value(value)
    case value
    when Hash
      value.transform_values { |nested| comparison_value(nested) }
    when Array
      value.map { |nested| comparison_value(nested) }
    when String
      value.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�")
           .unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
    else
      value
    end
  end

  def diff_fields(before, after)
    (before.keys | after.keys).filter_map do |k|
      b = before[k]
      a = after[k]
      next if k == "hidden_from_dex" # Campo interno de Pokédex; no es un cambio de juego.
      next if comparison_value(b) == comparison_value(a)

      { field: k, label: FIELD_LABELS[k] || k, from: b, to: a }
    end
  end

  # PBS distintos pueden usar IDs diferentes para la misma habilidad. Solo
  # empareja nombres y descripciones únicos; así conserva las diferencias reales.
  def renamed_abilities(baseline, current)
    old_groups = (baseline.keys - current.keys).group_by do |id|
      entry = baseline[id]
      [comparison_value(entry["name"]), comparison_value(entry["description"])]
    end
    new_groups = (current.keys - baseline.keys).group_by do |id|
      entry = current[id]
      [comparison_value(entry["name"]), comparison_value(entry["description"])]
    end
    old_groups.each_with_object({}) do |(signature, old_ids), matches|
      new_ids = new_groups[signature]
      matches[new_ids.first] = old_ids.first if old_ids&.one? && new_ids&.one?
    end
  end
end
