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
    "mega_stone" => "Piedra Mega", "mega_move" => "Movimiento Mega", "hidden_from_dex" => "Oculto en la Pokédex",
    "type" => "Tipo", "power" => "Potencia", "accuracy" => "Precisión",
    "total_pp" => "PP", "priority" => "Prioridad", "target" => "Objetivo", "function_code" => "Código de efecto",
    "flags" => "Propiedades", "effect_chance" => "Probabilidad de efecto", "description" => "Descripción",
    "name_plural" => "Nombre plural", "pocket" => "Bolsillo", "price" => "Precio", "sell_price" => "Precio de venta",
    "bp_price" => "Precio en PC", "field_use" => "Uso en el mapa", "battle_use" => "Uso en combate",
    "consumable" => "Consumible", "machine" => "MT/MO", "type_name" => "Tipo de entrenador",
    "version" => "Versión", "lose_text" => "Frase de derrota", "items" => "Objetos", "party" => "Equipo"
  }.freeze

  CATEGORY_LABELS = {
    "species" => "Pokémon", "moves" => "Movimientos", "abilities" => "Habilidades",
    "items" => "Objetos", "trainers" => "Entrenadores"
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
      base_cat = baseline[cat] || {}
      per_entity = {}

      entries.each do |id, fields|
        if !base_cat.key?(id)
          per_entity[id] = { status: "nuevo", fields: [] }
          result[:counts]["nuevas"] += 1
        else
          changed = diff_fields(base_cat[id], fields)
          next if changed.empty?

          per_entity[id] = { status: "modificado", fields: changed }
          result[:counts]["modificadas"] += 1
        end
      end

      removed = base_cat.keys - entries.keys
      unless removed.empty?
        result[:removed][cat] = removed
        result[:counts]["eliminadas"] += removed.size
      end

      result[cat.to_sym] = per_entity
    end

    result[:empty] = true if result[:counts].values.sum.zero?
    result
  end

  def diff_fields(before, after)
    (before.keys | after.keys).filter_map do |k|
      b = before[k]
      a = after[k]
      next if b == a

      { field: k, label: FIELD_LABELS[k] || k, from: b, to: a }
    end
  end
end
