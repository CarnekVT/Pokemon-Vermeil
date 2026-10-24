# encoding: UTF-8
# Compatibilidad entre slots de Pokédex, formas de Golden/Arcane y PBS dedicado.
# No cambia los registros del jugador ni elimina JSONs históricos.
module ResearchNotebook
  module Repository
    module_function

    def species_base_and_form(species)
      raw = species.respond_to?(:id) ? species.id.to_s : species.to_s
      if raw =~ /\A(.+),(\d+)\z/ || raw =~ /\A(.+)_(\d+)\z/
        base = normalize_species_id($1)
        return [base || $1.to_sym, $2.to_i]
      end
      base = normalize_species_id(raw)
      [base || raw.to_sym, 0]
    end

    def species_name(species)
      base, form = species_base_and_form(species)
      data = GameData::Species.try_get(base) if defined?(GameData::Species)
      return species.to_s unless data
      return data.name if form.to_i <= 0
      form_data = (GameData::Species.get_species_form(base, form) rescue nil)
      form_name = form_data.form_name.to_s if form_data && form_data.respond_to?(:form_name)
      form_name = "Forma #{form}" if !form_name || form_name.empty?
      "#{data.name} (#{form_name})"
    end

    def golden_entry(species)
      base, form = species_base_and_form(species)
      first = entry_for(golden_data, base)
      first = {} unless first.is_a?(Hash)
      return first if form <= 0
      overlay = entry_for(golden_data, "#{base},#{form}")
      overlay.is_a?(Hash) ? first.merge(overlay) : first
    end

    def golden_form_value(species)
      base, form = species_base_and_form(species)
      if defined?(GoldenSystem::PBS)
        pbs = GoldenSystem::PBS.form_payload(base, form)
        return pbs if pbs
      end
      value = get_key(golden_entry(species), "goldenForm", "GoldenForm", "golden_form")
      value
    end

    def golden_form_payload(species)
      value = golden_form_value(species)
      return value if value.is_a?(Hash)
      entry = golden_entry(species)
      get_key(entry, "goldenFormData", "GoldenFormData", "golden_form_data", "formData", "FormData")
    end

    def golden_form_index(species)
      value = golden_form_value(species)
      value = get_key(value, "number", "Number", "targetForm", "TargetForm",
                            "form", "Form", "formIndex", "FormIndex") if value.is_a?(Hash)
      return nil if value.nil?
      raw = value.to_s.strip
      return nil unless raw =~ /\A\d+\z/
      n = raw.to_i
      n > 0 ? n : nil
    end

    # Nombres y progreso son por especie base; el sprite y la definición de forma
    # dependen además del slot de origen.
    def golden_form_configured?(species)
      !golden_form_value(species).nil?
    end
  end
end
