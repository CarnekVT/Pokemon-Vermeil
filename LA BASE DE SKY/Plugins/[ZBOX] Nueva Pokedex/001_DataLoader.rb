# encoding: UTF-8
# Compatibilidad de la API NewPokedex con el catálogo canónico de Vermeil.
# Fuente única: Data/SpeciesDex/config.json (NuevaPokedex).
module NewPokedex
  module_function

  def load_data(force = false)
    if defined?(NuevaPokedex)
      NuevaPokedex.instance_variable_set(:@config_stamp, nil) if force
      NuevaPokedex.config
    end
    true
  end

  def reload_data!
    load_data(true)
  end

  def enabled_dex_list
    return [] unless defined?(NuevaPokedex)
    NuevaPokedex.accessible_regions
  end

  def dex_name(dex_id)
    return NuevaPokedex.dex_name_for(dex_id) if defined?(NuevaPokedex)
    NewPokedexConfig.dex_name(dex_id)
  end

  def enabled_species_list(dex_id = nil)
    return [] unless defined?(NuevaPokedex)
    return species_in_dex(dex_id) unless dex_id.nil?
    enabled_dex_list.flat_map { |id| species_in_dex(id) }.uniq
  end

  def species_in_dex(dex_id)
    return [] unless defined?(NuevaPokedex)
    id = dex_id.to_i
    NuevaPokedex.regional_species(id).dup
  end

  def build_from_game_data
    # Compatibilidad: ya no mezcla el PBS completo con la Pokédex activa.
    enabled_dex_list
  end

  def build_forms_data_for_dex(dex_id, species_list)
    result = {}
    species_list.each do |slot|
      base, = NuevaPokedex.entry_base_and_form(slot)
      result[base] = forms_for_species(dex_id, base)
    end
    result
  end

  def forms_for_species(dex_id, species)
    return [] unless defined?(NuevaPokedex) && defined?(GameData::Species)
    base, = NuevaPokedex.entry_base_and_form(species)
    forms = []
    GameData::Species.each_form_for_species(base) do |form_sp|
      next if form_sp.form.to_i <= 0
      next if form_sp.has_flag?("HideFromPokedex")
      forms << {
        :form => form_sp.form,
        :name => form_sp.form_name,
        :types => form_sp.types,
        :sprite_suffix => form_sp.form,
        :show_in_dex => NuevaPokedex.form_shown?(base, form_sp.form),
        :unlocks_own_slot => form_has_own_slot?(dex_id, base, form_sp.form)
      }
    end
    forms
  end

  def form_has_own_slot?(dex_id, species, form)
    return false unless defined?(NuevaPokedex)
    base, = NuevaPokedex.entry_base_and_form(species)
    slot = "#{base}_#{form.to_i}".to_sym
    NuevaPokedex.form_has_own_slot?(dex_id, slot)
  end

  def form_show_in_dex?(dex_id, species, form)
    return true unless defined?(NuevaPokedex)
    base, = NuevaPokedex.entry_base_and_form(species)
    NuevaPokedex.form_shown?(base, form.to_i)
  end

  def form_types(dex_id, species, form)
    return nil unless defined?(GameData::Species)
    base, = NuevaPokedex.entry_base_and_form(species)
    GameData::Species.get_species_form(base, form.to_i)&.types
  rescue StandardError
    nil
  end
end
