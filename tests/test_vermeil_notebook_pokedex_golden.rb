# encoding: UTF-8
# Pruebas de los PBS Golden sin iniciar mkxp/Pokemon Essentials.
require "json"
require_relative "../LA BASE DE SKY/Plugins/[Balance] Golden Power/00_PBS_Source"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Research Notebook/015_catalog_and_golden_pbs"

def assert(value, label)
  raise "FAIL: #{label}" unless value
  puts "OK: #{label}"
end

ROOT = File.expand_path("../LA BASE DE SKY", __dir__)
Dir.chdir(ROOT) do
  forms = GoldenSystem::PBS.form_entries
  moves = GoldenSystem::PBS.move_entries
  original_forms = JSON.parse(File.read("Data/GoldenSystem/species.json"))["species"].select { |_, v| v.key?("goldenForm") }
  original_moves = JSON.parse(File.read("Data/GoldenSystem/golden_moves.json"))["moves"]
  assert(forms.size >= original_forms.size, "Todos los perfiles dorados migrados al PBS")
  original_forms.each do |key, v|
    base, source = key.split(",", 2)
    source = source.to_i
    payload = GoldenSystem::PBS.form_payload(base, source)
    assert(payload.is_a?(Hash), "PBS Forma #{key}")
    legacy = v["goldenForm"]
    assert(payload["number"] == legacy["number"], "Número de forma #{key}")
    if legacy["baseStats"]
      legacy["baseStats"].each do |stat, number|
        assert(payload["baseStats"][stat] == number, "Estadística #{key}/#{stat}")
      end
    end
  end
  assert(moves.size == original_moves.length, "Variantes áureas del PBS conservadas")
  original_moves.each do |key, old|
    pieces = key.split("|")
    src = pieces.length > 2 ? pieces[2].to_i : nil
    new_row = moves[[pieces[0].to_sym,pieces[1].to_sym,src]]
    assert(new_row && new_row[:name] == old["name"], "Movimiento #{key}")
    assert(new_row[:function_code] == old["functionCode"], "Efecto #{key}") if old["functionCode"]
  end
  assert(GoldenSystem::PBS.form_payload(:CHARIZARD,1)["number"].nil?,
         "Las formas origen sin destino no inventan número")
  dex = JSON.parse(File.read("Data/SpeciesDex/config.json"))
  enabled = dex.fetch("enabledDexes")
  assert(enabled.include?(9), "Pokédex regional de Payu activa")
  assert(dex.fetch("dexes")[9].include?("RATTATA,1"), "Los slots alternos regionales se preservan")

  module ResearchNotebook::Repository
    module_function
    def normalize_species_id(v); v.to_s.upcase.to_sym; end
    def golden_data
      @standalone_golden ||= JSON.parse(File.read("Data/GoldenSystem/species.json"))["species"]
    end
    def entry_for(hash, species); hash[species.to_s]; end
    def get_key(hash, *keys)
      return nil unless hash.is_a?(Hash)
      keys.each { |k| return hash[k] if hash.key?(k) }
      nil
    end
  end
  rep = ResearchNotebook::Repository
  assert(rep.species_base_and_form(:RATTATA_1) == [:RATTATA,1], "Símbolos de slot reconocidos")
  assert(rep.species_base_and_form("CHARIZARD,2") == [:CHARIZARD,2], "Entradas JSON de forma reconocidas")
  assert(rep.golden_form_index(:HERACROSS) == 2, "Forma Dorada Heracross desde PBS")
  assert(rep.golden_form_index("CHARIZARD,1").nil?, "Forma Dorada incompleta queda pendiente")
  script = File.read("Plugins/[VERMEIL] Research Notebook/030_research_notebook_ui.rb")
  assert(script.include?("catalog_admission_set.keys"), "Libreta cubre toda la Pokédex habilitada")
end
puts "Pruebas PBS/Libreta: completadas"
