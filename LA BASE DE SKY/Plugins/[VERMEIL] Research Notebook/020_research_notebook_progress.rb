# encoding: UTF-8
#===============================================================================
# Libreta de Investigación - Progreso persistente v1.2.2
#===============================================================================
module ResearchNotebook
  class Progress
    attr_accessor :notebook_unlocked
    attr_accessor :arcane_section_unlocked
    attr_accessor :golden_section_unlocked

    # Solo estos estados cuentan como desbloqueo real. Leer la habilidad configurada
    # en species_data NO basta: muchas implementaciones exponen ese dato incluso
    # cuando el Pokémon todavía no la ha despertado.
    ARCANE_UNLOCK_READERS = [
      :arcane_unlocked?, :arcane_unlocked, :arcaneUnlocked,
      :arcane_ability_unlocked?, :arcaneAbilityUnlocked?, :arcaneAbilityUnlocked,
      :has_arcane_ability?, :hasArcaneAbility?, :arcane_active?, :arcane_active, :arcaneActive
    ]
    ARCANE_UNLOCKED_ABILITY_READERS = [
      :unlocked_arcane_ability, :unlockedArcaneAbility,
      :unlocked_arcane_ability_id, :unlockedArcaneAbilityId
    ]
    ARCANE_USED_READERS = [
      :arcane_used?, :arcane_ability_used?, :arcaneAbilityUsed?,
      :used_arcane_ability?, :usedArcaneAbility?
    ]
    ARCANE_UNLOCK_IVARS = [
      :@arcane_unlocked, :@arcaneUnlocked, :@arcane_ability_unlocked,
      :@arcaneAbilityUnlocked
    ]
    ARCANE_UNLOCKED_ABILITY_IVARS = [
      :@unlocked_arcane_ability, :@unlockedArcaneAbility,
      :@unlocked_arcane_ability_id, :@unlockedArcaneAbilityId
    ]
    ARCANE_USED_IVARS = [
      :@arcane_used, :@arcane_ability_used, :@arcaneAbilityUsed
    ]

    def initialize
      @notebook_unlocked       = ResearchNotebook::Settings::NOTEBOOK_AVAILABLE_FROM_START
      @arcane_section_unlocked = false
      @golden_section_unlocked = false
      @arcane = {}
      @golden = {}
      @arcane_visibility_schema = 2
    end

    def arcane
      @arcane ||= {}
      return @arcane
    end

    def golden
      @golden ||= {}
      return @golden
    end

    # v1.2.0 podía guardar como "vista" una habilidad obtenida solo desde la
    # configuración de especie. Esos datos no prueban que el jugador la hubiera
    # descubierto. Al cargar una partida antigua se limpian una sola vez.
    # Las habilidades realmente usadas se conservan porque sí fueron observadas.
    def ensure_visibility_schema!
      return self if @arcane_visibility_schema.to_i >= 2
      arcane.each_value do |rec|
        next if !rec.is_a?(Hash)
        if rec[:ability_used]
          rec[:ability_seen] = true
        else
          rec[:ability_seen] = false
          rec[:ability_id] = nil
        end
      end
      @arcane_visibility_schema = 2
      return self
    end

    def normalize_species(species)
      return ResearchNotebook::Repository.normalize_species_id(species)
    rescue
      return species.to_sym rescue species
    end

    def arcane_record(species)
      id = normalize_species(species)
      return nil if !id
      arcane[id] ||= {}
      rec = arcane[id]
      rec[:potential_known] = false if rec[:potential_known].nil?
      rec[:ability_seen]    = false if rec[:ability_seen].nil?
      rec[:ability_used]    = false if rec[:ability_used].nil?
      rec[:ability_id]      = nil if !rec.key?(:ability_id)
      return rec
    end

    def golden_record(species)
      id = normalize_species(species)
      return nil if !id
      golden[id] ||= {}
      rec = golden[id]
      rec[:potential_known]   = false if rec[:potential_known].nil?
      rec[:golden_type_known] = false if rec[:golden_type_known].nil?
      rec[:form_seen]         = false if rec[:form_seen].nil?
      rec[:form_used]         = false if rec[:form_used].nil?
      rec[:power_used]        = false if rec[:power_used].nil?
      return rec
    end

    def unlock_notebook!
      @notebook_unlocked = true
    end

    def unlock_arcane!
      @notebook_unlocked = true
      @arcane_section_unlocked = true
      sync_party_unlocks!
    end

    def unlock_golden!
      @notebook_unlocked = true
      @golden_section_unlocked = true
      sync_party_unlocks!
    end

    def arcane_potential_known?(species)
      rec = arcane_record(species)
      return rec && rec[:potential_known]
    end

    def arcane_seen?(species)
      rec = arcane_record(species)
      return rec && rec[:ability_seen]
    end

    def arcane_used?(species)
      rec = arcane_record(species)
      return rec && rec[:ability_used]
    end

    def arcane_ability_id(species)
      rec = arcane_record(species)
      return nil if !rec || !rec[:ability_seen]
      return rec[:ability_id] || ResearchNotebook::Repository.arcane_ability(species)
    end

    def tracked_arcane_species
      return arcane.keys.compact
    end

    def tracked_golden_species
      return golden.keys.compact
    end

    def golden_potential_known?(species)
      rec = golden_record(species)
      return rec && rec[:potential_known]
    end

    def golden_type_known?(species)
      rec = golden_record(species)
      return rec && rec[:golden_type_known]
    end

    def golden_form_seen?(species)
      rec = golden_record(species)
      return rec && rec[:form_seen]
    end

    def golden_form_used?(species)
      rec = golden_record(species)
      return rec && rec[:form_used]
    end

    def golden_power_used?(species)
      rec = golden_record(species)
      return rec && rec[:power_used]
    end

    # Conocer que una especie puede despertar una Habilidad Arcana NO revela
    # su identidad. El ID solo se guarda cuando la habilidad ha sido desbloqueada.
    def mark_arcane_potential(species, ability = nil)
      rec = arcane_record(species)
      return if !rec
      rec[:potential_known] = true
    end

    def mark_arcane_seen(species, ability = nil, propagate = true)
      id = normalize_species(species)
      rec = arcane_record(id)
      return if !rec
      resolved = ResearchNotebook::Repository.resolve_ability(ability) if ability
      resolved ||= ResearchNotebook::Repository.arcane_ability(id)
      rec[:potential_known] = true
      rec[:ability_seen] = true
      rec[:ability_id] = resolved if resolved

      # Si una evolución/pre-evolución tiene exactamente la misma Habilidad Arcana,
      # conocerla en una especie basta para reconocerla en las demás. Una habilidad
      # distinta sigue cerrada hasta que esa especie la despierte por sí misma.
      if propagate && resolved
        ResearchNotebook::Repository.same_arcane_family_species(id, resolved).each do |relative|
          next if normalize_species(relative) == id
          mark_arcane_seen(relative, resolved, false)
        end
      end
    end

    def mark_arcane_used(species, ability = nil, propagate = true)
      id = normalize_species(species)
      rec = arcane_record(id)
      return if !rec
      resolved = ResearchNotebook::Repository.resolve_ability(ability) if ability
      resolved ||= ResearchNotebook::Repository.arcane_ability(id)
      rec[:potential_known] = true
      rec[:ability_seen] = true
      rec[:ability_used] = true
      rec[:ability_id] = resolved if resolved
      if propagate && resolved
        ResearchNotebook::Repository.same_arcane_family_species(id, resolved).each do |relative|
          next if normalize_species(relative) == id
          # Compartir identidad no significa que esa otra especie ya la haya usado.
          mark_arcane_seen(relative, resolved, false)
        end
      end
    end

    def mark_golden_potential(species)
      rec = golden_record(species)
      return if !rec
      rec[:potential_known] = true
      rec[:golden_type_known] = true if ResearchNotebook::Settings::REVEAL_GOLDEN_TYPE_BEFORE_USE
    end

    def mark_golden_form_seen(species)
      rec = golden_record(species)
      return if !rec
      rec[:potential_known] = true
      rec[:golden_type_known] = true
      rec[:form_seen] = true
    end

    def mark_golden_form_used(species)
      rec = golden_record(species)
      return if !rec
      rec[:potential_known] = true
      rec[:golden_type_known] = true
      rec[:form_seen] = true
      rec[:form_used] = true
    end

    def mark_golden_power_used(species)
      rec = golden_record(species)
      return if !rec
      rec[:potential_known] = true
      rec[:golden_type_known] = true
      rec[:power_used] = true
    end

    # Pokedex#owned? es O(1) y evita recorrer todas las cajas por cada celda de UI.
    def owned?(species, owned_species = nil)
      id = normalize_species(species)
      return false if !id
      return true if owned_species && owned_species[id]
      if defined?($player) && $player && $player.respond_to?(:pokedex) && $player.pokedex
        begin
          return !!$player.pokedex.owned?(id)
        rescue
        end
      end
      # Fallback solo para proyectos sin Pokédex funcional.
      each_owned_pokemon do |pkmn|
        begin
          return true if normalize_species(pkmn.species) == id
        rescue
        end
      end
      return false
    end

    # Equipo + cajas. Se llama una sola vez por sincronización, no por entrada.
    def each_owned_pokemon
      return enum_for(:each_owned_pokemon) if !block_given?
      seen = {}
      if defined?($player) && $player && $player.respond_to?(:party)
        $player.party.each do |pkmn|
          next if !pkmn
          oid = pkmn.object_id rescue nil
          next if oid && seen[oid]
          seen[oid] = true if oid
          yield pkmn
        end
      end
      storage = defined?($PokemonStorage) ? $PokemonStorage : nil
      return if !storage
      begin
        if storage.respond_to?(:boxes)
          storage.boxes.each do |box|
            next if !box
            collection = box.respond_to?(:pokemon) ? box.pokemon : box
            next if !collection.respond_to?(:each)
            collection.each do |pkmn|
              next if !pkmn || !pkmn.respond_to?(:species)
              oid = pkmn.object_id rescue nil
              next if oid && seen[oid]
              seen[oid] = true if oid
              yield pkmn
            end
          end
          return
        end
      rescue => e
        ResearchNotebook::Repository.log("Lectura de cajas (boxes): #{e.message}")
      end
      begin
        if storage.respond_to?(:maxBoxes) && storage.respond_to?(:maxPokemon)
          storage.maxBoxes.times do |box_index|
            storage.maxPokemon(box_index).times do |slot|
              pkmn = storage[box_index, slot] rescue nil
              next if !pkmn || !pkmn.respond_to?(:species)
              oid = pkmn.object_id rescue nil
              next if oid && seen[oid]
              seen[oid] = true if oid
              yield pkmn
            end
          end
        end
      rescue => e
        ResearchNotebook::Repository.log("Lectura de cajas (índices): #{e.message}")
      end
    end

    def owned_snapshot
      pokemon = []
      species = {}
      each_owned_pokemon do |pkmn|
        pokemon << pkmn
        id = normalize_species(pkmn.species) rescue nil
        species[id] = true if id
      end
      return pokemon, species
    end

    def truthy_arcane_value?(value)
      return false if value.nil? || value == false
      return value if value == true
      return value.to_i > 0 if value.is_a?(Numeric)
      text = value.to_s.strip.downcase
      return false if text.empty? || ["false", "none", "nil", "0", "locked"].include?(text)
      return true
    end

    def safe_reader(obj, names)
      names.each do |name|
        next if !obj.respond_to?(name)
        begin
          return obj.send(name)
        rescue ArgumentError
          next
        rescue
          next
        end
      end
      return nil
    end

    def safe_ivar(obj, names)
      names.each do |name|
        begin
          return obj.instance_variable_get(name) if obj.instance_variable_defined?(name)
        rescue
        end
      end
      return nil
    end

    def concrete_arcane_ability(value)
      return nil if value.nil? || value == true || value == false
      if value.is_a?(Hash)
        value = ResearchNotebook::Repository.get_key(value,
          "ability", "Ability", "abilityId", "AbilityID", "id", "ID", "arcaneAbility", "ArcaneAbility")
      elsif value.is_a?(Array)
        value = value.find { |v| !v.nil? && v != false }
      end
      return nil if value.nil? || value == true || value == false
      resolved = ResearchNotebook::Repository.resolve_ability(value)
      return nil if !resolved
      if defined?(GameData::Ability)
        begin
          return nil if !GameData::Ability.try_get(resolved)
        rescue
        end
      end
      return resolved
    end

    def pokemon_arcane_unlocked?(pkmn)
      unlock_value = safe_reader(pkmn, ARCANE_UNLOCK_READERS)
      unlock_value = safe_ivar(pkmn, ARCANE_UNLOCK_IVARS) if unlock_value.nil?
      return true if truthy_arcane_value?(unlock_value)

      # Solo un campo cuyo nombre diga explícitamente "unlocked" puede implicar
      # desbloqueo por sí mismo. `arcane_ability` normal nunca lo hace.
      unlocked_ability = safe_reader(pkmn, ARCANE_UNLOCKED_ABILITY_READERS)
      unlocked_ability = safe_ivar(pkmn, ARCANE_UNLOCKED_ABILITY_IVARS) if unlocked_ability.nil?
      return !concrete_arcane_ability(unlocked_ability).nil?
    end

    def pokemon_arcane_used?(pkmn)
      used_value = safe_reader(pkmn, ARCANE_USED_READERS)
      used_value = safe_ivar(pkmn, ARCANE_USED_IVARS) if used_value.nil?
      return truthy_arcane_value?(used_value)
    end

    def sync_arcane_unlocks_from_owned_pokemon!(pokemon = nil)
      return self if !@arcane_section_unlocked
      list = pokemon || each_owned_pokemon.to_a
      list.each do |pkmn|
        species = normalize_species(pkmn.species) rescue nil
        next if !species || !ResearchNotebook::Repository.arcane_capable?(species)
        mark_arcane_potential(species) if ResearchNotebook::Settings::REVEAL_ARCANE_POTENTIAL_ON_CAPTURE
        ability_id = ResearchNotebook::Repository.arcane_ability(species)
        if pokemon_arcane_unlocked?(pkmn)
          mark_arcane_seen(species, ability_id)
        end
        if pokemon_arcane_used?(pkmn)
          mark_arcane_used(species, ability_id)
        end
      end
      return self
    end

    def propagate_known_arcane_families!
      known = arcane.keys.select { |sp| arcane_record(sp)[:ability_seen] }
      known.each do |species|
        rec = arcane_record(species)
        ability = rec[:ability_id] || ResearchNotebook::Repository.arcane_ability(species)
        mark_arcane_seen(species, ability, true) if ability
      end
      return self
    end

    def golden_stone_owned?
      item = ResearchNotebook::Settings::GOLDEN_STONE_ITEM
      return false if !item || !defined?($bag) || !$bag
      begin
        return $bag.has?(item) if $bag.respond_to?(:has?)
        return $bag.hasItem?(item) if $bag.respond_to?(:hasItem?)
        return $bag.quantity(item) > 0 if $bag.respond_to?(:quantity)
      rescue
      end
      return false
    end

    # Sincronización rápida para la UI. Solo mira el equipo (máximo 6 Pokémon)
    # y el objeto clave; nunca recorre las cajas al abrir/cambiar de sección.
    def sync_party_unlocks!
      ensure_visibility_schema!
      @notebook_unlocked = true if ResearchNotebook::Settings::NOTEBOOK_AVAILABLE_FROM_START
      if golden_stone_owned? && !@golden_section_unlocked
        @notebook_unlocked = true
        @golden_section_unlocked = true
      end
      party = []
      if defined?($player) && $player && $player.respond_to?(:party)
        party = $player.party.compact
      end
      party.each do |pkmn|
        species = normalize_species(pkmn.species) rescue nil
        next if !species
        if @arcane_section_unlocked && ResearchNotebook::Repository.arcane_capable?(species) &&
           ResearchNotebook::Settings::REVEAL_ARCANE_POTENTIAL_ON_CAPTURE
          mark_arcane_potential(species)
        end
        if @golden_section_unlocked && ResearchNotebook::Repository.golden_capable?(species)
          mark_golden_potential(species)
        end
      end
      sync_arcane_unlocks_from_owned_pokemon!(party)
      propagate_known_arcane_families!
      return self
    end

    # Sincronización completa, reservada para migraciones/debug. Hace una sola
    # pasada por equipo + cajas.
    def sync_unlocks!
      ensure_visibility_schema!
      @notebook_unlocked = true if ResearchNotebook::Settings::NOTEBOOK_AVAILABLE_FROM_START
      if golden_stone_owned? && !@golden_section_unlocked
        @notebook_unlocked = true
        @golden_section_unlocked = true
      end
      pokemon, owned_species = owned_snapshot
      sync_known_potentials!(owned_species)
      sync_arcane_unlocks_from_owned_pokemon!(pokemon)
      propagate_known_arcane_families!
      return self
    end

    def sync_known_potentials!(owned_species = nil, snapshot_only = false)
      ResearchNotebook::Repository.relevant_species.each do |species|
        is_owned = if snapshot_only
                     id = normalize_species(species)
                     owned_species && owned_species[id]
                   else
                     owned?(species, owned_species)
                   end
        next if !is_owned
        if @arcane_section_unlocked && ResearchNotebook::Repository.arcane_capable?(species) &&
           ResearchNotebook::Settings::REVEAL_ARCANE_POTENTIAL_ON_CAPTURE
          mark_arcane_potential(species)
        end
        if @golden_section_unlocked && ResearchNotebook::Repository.golden_capable?(species)
          mark_golden_potential(species)
        end
      end
      return self
    end
  end

  module_function

  def progress
    $research_notebook_progress ||= ResearchNotebook::Progress.new
    $research_notebook_progress.ensure_visibility_schema! if $research_notebook_progress.respond_to?(:ensure_visibility_schema!)
    return $research_notebook_progress
  end

  def notebook_unlocked?
    # Evita una sincronización de cajas cada vez que el menú evalúa su condición.
    return true if ResearchNotebook::Settings::NOTEBOOK_AVAILABLE_FROM_START
    p = progress
    return p.notebook_unlocked || p.arcane_section_unlocked || p.golden_section_unlocked
  end
end

ResearchNotebookProgress = ResearchNotebook::Progress if !defined?(ResearchNotebookProgress)

if defined?(SaveData)
  SaveData.register(:research_notebook_progress) do
    ensure_class :ResearchNotebookProgress
    save_value { $research_notebook_progress }
    load_value { |value| $research_notebook_progress = value }
    new_game_value { ResearchNotebook::Progress.new }
  end
end

#===============================================================================
# API pública
#===============================================================================
def pbUnlockResearchNotebook
  ResearchNotebook.progress.unlock_notebook!
end

def pbUnlockArcaneNotebook
  ResearchNotebook.progress.unlock_arcane!
end

def pbUnlockGoldenNotebook
  ResearchNotebook.progress.unlock_golden!
end

def pbResearchArcaneSeen(species, ability = nil)
  return if !ResearchNotebook::Repository.arcane_capable?(species) && ability.nil?
  ResearchNotebook.progress.mark_arcane_seen(species, ability)
end

def pbResearchArcaneUsed(species, ability = nil)
  return if !ResearchNotebook::Repository.arcane_capable?(species) && ability.nil?
  ResearchNotebook.progress.mark_arcane_used(species, ability)
end

def pbResearchGoldenFormSeen(species)
  ResearchNotebook.progress.mark_golden_form_seen(species)
end

def pbResearchGoldenFormUsed(species)
  ResearchNotebook.progress.mark_golden_form_used(species)
end

def pbResearchGoldenPowerUsed(species)
  ResearchNotebook.progress.mark_golden_power_used(species)
end
