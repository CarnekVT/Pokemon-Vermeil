# frozen_string_literal: true
# Vermeil UI editor bridge. These profiles are authored with the existing
# MakerStudio Interfaces editor; they NEVER replace the real scene/data logic.
module VermeilInterfaceLayout
  FILES = {
    :notebook => ["vermeil_libreta", "vermeil_libreta_detalle"],
    :pokedex  => ["vermeil_pokedex_lista", "vermeil_pokedex_ficha",
                  "vermeil_pokedex_area", "vermeil_pokedex_formas"]
  }.freeze

  module_function

  def load(kind)
    result = {}
    (FILES[kind] || []).each do |name|
      file = "UI/#{name}.json"
      next unless File.file?(file)
      source = File.open(file, "rb") { |f| f.read }
      data = if defined?(JSON) && JSON.respond_to?(:parse)
               JSON.parse(source)
             elsif defined?(Interfaces::AnalizadorJSON)
               Interfaces::AnalizadorJSON.analizar(source, file)
             end
      next unless data.is_a?(Hash) && data["elementos"].is_a?(Array)
      data["elementos"].each do |element|
        next unless element.is_a?(Hash)
        id = element["id"].to_s
        next if id.empty?
        result[id] = element
      end
    end
    result
  rescue StandardError => error
    # Corrupted design must not prevent the Pokédex/Notebook from opening.
    p "[Vermeil UI] #{error.class}: #{error.message}" if $DEBUG
    result || {}
  end

  def number(layout, id, property, fallback)
    data = layout.is_a?(Hash) ? layout[id.to_s] : nil
    value = data.is_a?(Hash) ? data[property.to_s] : nil
    return fallback unless value.is_a?(Numeric) && value.finite?
    value
  end

  def position(layout, id, axis, fallback)
    number(layout, id, axis, fallback).round
  end

  def layer(layout, id, fallback)
    number(layout, id, "capa", fallback).to_i
  end

  def entrance(layout, id)
    data = layout.is_a?(Hash) ? layout[id.to_s] : nil
    entry = data.is_a?(Hash) ? data["entrada"] : nil
    entry.is_a?(Hash) ? entry : {}
  end

  def frames(layout, id, fallback, minimum = 3, maximum = 75)
    duration = entrance(layout, id)["duracion"]
    return fallback unless duration.is_a?(Numeric) && duration.finite? && duration > 0
    [[(duration * 60).round, minimum].max, maximum].min
  end
end
