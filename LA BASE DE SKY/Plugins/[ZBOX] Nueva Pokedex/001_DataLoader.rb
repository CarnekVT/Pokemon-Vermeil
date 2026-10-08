#===============================================================================
# [ZBOX] Nueva Pokédex - Capa de Carga de Datos y JSON Unificada
#===============================================================================
module NewPokedex
  @dex_data = {}
  @dex_species_cache = {}
  @dex_names = {}
  @dex_forms_cache = {}
  @loaded = false

  # Carga definiciones de JSON y PBS
  def self.load_data(force = false)
    return if @loaded && !force
    @dex_data.clear
    @dex_species_cache.clear
    @dex_forms_cache.clear
    @dex_names.clear

    # 1. Cargar desde JSON si existe
    json_loaded = false
    if File.exist?(NewPokedexConfig::DEX_JSON_PATH)
      begin
        raw = File.read(NewPokedexConfig::DEX_JSON_PATH)
        parsed = nil
        if defined?(Compiler::JsonReader)
          parsed = Compiler::JsonReader.new(raw).parse rescue nil
        elsif defined?(CarnekChangeData::JsonReader)
          parsed = CarnekChangeData::JsonReader.new(raw).parse rescue nil
        end
        if parsed.is_a?(Hash) && parsed["dexes"].is_a?(Hash)
          parsed["dexes"].each do |dex_key, dex_info|
            id = dex_key.to_i
            name = dex_info["name"] || NewPokedexConfig.dex_name(id)
            species = (dex_info["species"] || []).map { |s| s.to_s.upcase.to_sym }
            forms_data = dex_info["forms"] || {}
            @dex_data[id] = { :id => id, :name => name, :species => species, :forms => forms_data }
            @dex_names[id] = name
            @dex_species_cache[id] = species
            @dex_forms_cache[id] = forms_data
          end
          json_loaded = true
        end
      rescue StandardError => e
        echoln "[NewPokedex] Error al leer #{NewPokedexConfig::DEX_JSON_PATH}: #{e.message}"
      end
    end

    # 2. Fallback estándar a PBS GameData::Species regional dexes
    if !json_loaded
      build_from_game_data
    end

    @loaded = true
  end

  def self.build_from_game_data
    num_regional = defined?(Settings::DEXES_COUNT) ? Settings::DEXES_COUNT : 1
    (0...num_regional).each do |dex_id|
      species_list = pbAllRegionalSpecies(dex_id)
      next if !species_list || species_list.empty?
      forms_data = build_forms_data_for_dex(dex_id, species_list)
      name = NewPokedexConfig.dex_name(dex_id)
      @dex_data[dex_id] = { :id => dex_id, :name => name, :species => species_list, :forms => forms_data }
      @dex_names[dex_id] = name
      @dex_species_cache[dex_id] = species_list
      @dex_forms_cache[dex_id] = forms_data
    end
  end

  def self.build_forms_data_for_dex(dex_id, species_list)
    forms_data = {}
    species_list.each do |sp|
      s_data = GameData::Species.try_get(sp)
      next if !s_data
      forms = []
      GameData::Species.each_form_for_species(s_data.species) do |form_sp|
        next if form_sp.form == 0
        next if form_sp.has_flag?("HideFromPokedex")
        forms << {
          :form => form_sp.form,
          :name => form_sp.form_name,
          :types => form_sp.types,
          :sprite_suffix => form_sp.form,
          :show_in_dex => true,
          :unlocks_own_slot => false
        }
      end
      forms_data[sp] = forms if !forms.empty?
    end
    forms_data
  end

  def self.reload_data!
    load_data(true)
  end

  # Lista de dexes habilitadas en la partida actual
  def self.enabled_dex_list
    load_data if !@loaded
    if $player && $player.pokedex
      unlocked = ($player.pokedex.unlocked_dex_list rescue [0])
      return unlocked if unlocked.is_a?(Array) && !unlocked.empty?
    end
    return @dex_data.keys.empty? ? [0] : @dex_data.keys.sort
  end

  def self.dex_name(dex_id)
    load_data if !@loaded
    return @dex_names[dex_id] || NewPokedexConfig.dex_name(dex_id)
  end

  # Especies pertenecientes a la dex indicada o a TODAS las dexes habilitadas
  def self.enabled_species_list(dex_id = nil)
    load_data if !@loaded
    if dex_id && dex_id >= 0
      return (@dex_species_cache[dex_id] || []).clone
    end
    # Unir todas las especies de las dexes habilitadas sin duplicados
    result = []
    enabled_dex_list.each do |d_id|
      species_list = @dex_species_cache[d_id] || []
      result.concat(species_list)
    end
    result.uniq!
    return result
  end

  def self.species_in_dex(dex_id)
    load_data if !@loaded
    return (@dex_species_cache[dex_id] || []).clone
  end

  # Formas de una especie en una dex específica
  def self.forms_for_species(dex_id, species)
    load_data if !@loaded
    forms_data = @dex_forms_cache[dex_id] || {}
    return (forms_data[species] || []).clone
  end

  # Verifica si una forma tiene su propio slot en la Pokédex
  def self.form_has_own_slot?(dex_id, species, form)
    load_data if !@loaded
    forms_data = @dex_forms_cache[dex_id] || {}
    form_info = forms_data[species]&.find { |f| f[:form] == form }
    return form_info ? form_info[:unlocks_own_slot] : false
  end

  # Verifica si una forma debe mostrarse en la Pokédex
  def self.form_show_in_dex?(dex_id, species, form)
    load_data if !@loaded
    forms_data = @dex_forms_cache[dex_id] || {}
    form_info = forms_data[species]&.find { |f| f[:form] == form }
    return form_info ? form_info[:show_in_dex] : true
  end

  # Obtiene los tipos de una forma específica
  def self.form_types(dex_id, species, form)
    load_data if !@loaded
    forms_data = @dex_forms_cache[dex_id] || {}
    form_info = forms_data[species]&.find { |f| f[:form] == form }
    return form_info ? form_info[:types] : nil
  end
end
