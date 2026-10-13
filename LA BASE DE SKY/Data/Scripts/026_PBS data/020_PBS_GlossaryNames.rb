# encoding: utf-8


module GameData
  module PBSGlossaryNames
    def self.load_translations(path, field, key_field = "id", key_overrides = {})
      data = HTTPLite::JSON.parse(File.read(path, encoding: "UTF-8"))
      translations = {}
      data["entries"].each do |entry|
        values = entry[field]
        key = (key_field == "name") ? entry.dig("names", "es_ES") : entry[key_field]
        key = key_overrides.fetch(entry["id"], key)
        next if !key || !values.is_a?(Hash)
        key = key.to_s.downcase.gsub(/[^a-z0-9]/, "") if key_field == "key"
        translations[key.to_s] = values
      end
      return translations
    rescue StandardError => e
      Console.echo_warn("No se pudo cargar el glosario #{path}: #{e.message}")
      return {}
    end

    def self.translate(key, translated_text, glossary)
      return translated_text unless $PokemonSystem
      language = $PokemonSystem.language
      return translated_text unless language.is_a?(Integer) && language >= 0
      language_code = Settings::LANGUAGES[language]&.[](1)
      return translated_text if !language_code || language_code == "es_ES"
      return glossary.dig(key.to_s, language_code) || translated_text
    end

    MOVE_NAMES = load_translations("Translations/moves.json", "names", "name")
    ABILITY_NAMES = load_translations("Translations/abilities.json", "names", "name")
    MOVE_DESCRIPTIONS = load_translations("Translations/move_descriptions.json", "descriptions", "key", { 741 => "EEVEEVOLLEY" })
    # Variantes con el mismo nombre oficial pero efectos distintos.
    ABILITY_DESCRIPTIONS = load_translations("Translations/ability_descriptions.json", "descriptions", "key", {
      266 => "ASONECHILLINGNEIGH",
      267 => "ASONEGRIMNEIGH",
      301 => "EMBODYASPECTSPEED",
      302 => "EMBODYASPECTSPDEF",
      303 => "EMBODYASPECTATTACK",
      304 => "EMBODYASPECTDEFENSE"
    })
    TYPE_NAMES = load_translations("Translations/types.json", "names")
    ITEM_NAMES = load_translations("Translations/items.json", "names")
    ITEM_DESCRIPTIONS = load_translations("Translations/item_descriptions.json", "descriptions")
    POKEDEX_DESCRIPTIONS = load_translations("Translations/pokedex_descriptions.json", "descriptions", "key")

    def self.translate_pokedex(species, translated_text)
      key = species.to_s.downcase.gsub(/[^a-z0-9]/, "")
      # Los IDs PBS de Nidoran no coinciden con los slugs de PokeAPI.
      key = "nidoranf" if key == "nidoranfe"
      key = "nidoranm" if key == "nidoranma"
      return translate(key, translated_text, POKEDEX_DESCRIPTIONS)
    end
  end

  class Type
    alias_method :_LBDS_glossary_orig_name, :name

    def name
      PBSGlossaryNames.translate(@id, _LBDS_glossary_orig_name, PBSGlossaryNames::TYPE_NAMES)
    end
  end

  class Move
    alias_method :_LBDS_glossary_orig_name, :name
    alias_method :_LBDS_glossary_orig_description, :description

    def name
      PBSGlossaryNames.translate(@real_name, _LBDS_glossary_orig_name, PBSGlossaryNames::MOVE_NAMES)
    end

    def description
      PBSGlossaryNames.translate(@id.to_s.downcase, _LBDS_glossary_orig_description, PBSGlossaryNames::MOVE_DESCRIPTIONS)
    end
  end

  class Ability
    alias_method :_LBDS_glossary_orig_name, :name
    alias_method :_LBDS_glossary_orig_description, :description

    def name
      PBSGlossaryNames.translate(@real_name, _LBDS_glossary_orig_name, PBSGlossaryNames::ABILITY_NAMES)
    end

    def description
      PBSGlossaryNames.translate(@id.to_s.downcase, _LBDS_glossary_orig_description, PBSGlossaryNames::ABILITY_DESCRIPTIONS)
    end
  end

  class Item
    alias_method :_LBDS_glossary_orig_name, :name
    alias_method :_LBDS_glossary_orig_description, :description

    def name
      PBSGlossaryNames.translate(@id, _LBDS_glossary_orig_name, PBSGlossaryNames::ITEM_NAMES)
    end

    def description
      PBSGlossaryNames.translate(@id, _LBDS_glossary_orig_description, PBSGlossaryNames::ITEM_DESCRIPTIONS)
    end
  end

  class Species
    alias_method :_LBDS_glossary_orig_pokedex_entry, :pokedex_entry

    def pokedex_entry
      translated_text = _LBDS_glossary_orig_pokedex_entry
      if @form != 0
        base_species = GameData::Species.try_get(@species)
        return translated_text if !base_species || base_species.real_pokedex_entry != @real_pokedex_entry
      end
      PBSGlossaryNames.translate_pokedex(@species, translated_text)
    end
  end
end
