# encoding: utf-8


module GameData
  module PBSGlossaryNames
    def self.load_names(path)
      data = HTTPLite::JSON.parse(File.read(path, encoding: "UTF-8"))
      names = {}
      data["entries"].each do |entry|
        translations = entry["names"]
        source = translations["es_ES"]
        target = translations["es_latam"]
        names[source] = target if source && target && source != target
      end
      return names
    rescue StandardError => e
      Console.echo_warn("No se pudo cargar el glosario #{path}: #{e.message}")
      return {}
    end

    def self.translate(source_name, translated_name, glossary)
      return translated_name unless $PokemonSystem
      language = $PokemonSystem.language
      return translated_name unless language.is_a?(Integer) && Settings::LANGUAGES[language]&.[](1) == "es_latam"
      return glossary.fetch(source_name, translated_name)
    end

    MOVE_NAMES = load_names("Translations/moves.json")
    ABILITY_NAMES = load_names("Translations/abilities.json")
  end

  class Move
    alias_method :_LBDS_glossary_orig_name, :name

    def name
      translated_name = _LBDS_glossary_orig_name
      return PBSGlossaryNames.translate(@real_name, translated_name, PBSGlossaryNames::MOVE_NAMES)
    end
  end

  class Ability
    alias_method :_LBDS_glossary_orig_name, :name

    def name
      translated_name = _LBDS_glossary_orig_name
      return PBSGlossaryNames.translate(@real_name, translated_name, PBSGlossaryNames::ABILITY_NAMES)
    end
  end
end
