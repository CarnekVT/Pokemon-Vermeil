# encoding: UTF-8
# Pruebas aisladas de Libreta sin arrancar el motor gráfico.
class Color
  attr_reader :red, :green, :blue
  def initialize(red=0, green=0, blue=0, alpha=255)
    @red, @green, @blue = red, green, blue
  end
end

require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Research Notebook/001_research_notebook_config"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Research Notebook/010_research_notebook_data"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Research Notebook/015_catalog_and_golden_pbs"
require_relative "../LA BASE DE SKY/Plugins/[VERMEIL] Research Notebook/030_research_notebook_ui"

def check(value, message)
  raise "FAIL: #{message}" unless value
  puts "OK: #{message}"
end

class TestCanvas
  def clear; end
end
class TestSprite
  attr_reader :bitmap
  def initialize; @bitmap = TestCanvas.new; end
end

Dir.chdir(File.expand_path("../LA BASE DE SKY", __dir__)) do
  def pbResolveBitmap(candidate)
    File.file?(candidate + ".png") ? candidate + ".png" : nil
  end
  notebook = ResearchNotebook::Scene.allocate
  check(notebook.split_species_form(:FARFETCHD_1) == [:FARFETCHD, 1],
        "El parser distingue los slots con guion bajo")
  check(notebook.split_species_form("RATTATA,1") == [:RATTATA, 1],
        "El parser reconoce también las formas con coma")
  check(notebook.grid_icon_filename(nil, :FARFETCHD, 1).to_s.end_with?("FARFETCHD_1.png"),
        "El icono de Farfetch'd de Galar proviene de su forma 1")
  check(notebook.grid_icon_filename(nil, :RATTATA, 1).to_s.end_with?("RATTATA_1.png"),
        "El icono de Rattata regional no proviene de la forma 0")
  check(notebook.grid_icon_filename(nil, :HERACROSS, 2).nil?,
        "Nunca se suplanta un icono de forma ausente con uno base")

  notebook.instance_variable_set(:@detail_open, false)
  notebook.instance_variable_set(:@sections, [[:arcane, "Arcano"]])
  notebook.instance_variable_set(:@section_index, 0)
  notebook.instance_variable_set(:@index, 0)
  notebook.instance_variable_set(:@sort_mode, :DEX)
  notebook.instance_variable_set(:@species_generation, 1)
  notebook.instance_variable_set(:@grid_signature, nil)
  notebook.instance_variable_set(:@species, Array.new(8) { |i| "SPECIES#{i}".to_sym })
  notebook.instance_variable_set(:@sprites, {"grid_icons" => TestSprite.new})
  notebook.instance_variable_set(:@rendered, [])
  def notebook.draw_species_icon_to_grid(canvas, species, slot)
    @rendered << [species, slot]
  end
  notebook.refresh_grid_icons
  check(notebook.instance_variable_get(:@pending_grid_icons).length == 8,
        "La cuadrícula aplaza la carga de las 8 imágenes")
  notebook.render_next_grid_icons(2)
  check(notebook.instance_variable_get(:@rendered).length == 2 &&
        notebook.instance_variable_get(:@pending_grid_icons).length == 6,
        "Se procesa solo el presupuesto de iconos por fotograma")
  def notebook.refresh
    @test_refreshed = true
  end
  notebook.instance_variable_set(:@detail_open, true)
  notebook.instance_variable_set(:@detail_page, 3)
  notebook.move_detail_species(1)
  check(notebook.instance_variable_get(:@index) == 1 &&
        notebook.instance_variable_get(:@detail_page) == 0 &&
        notebook.instance_variable_get(:@test_refreshed),
        "Se cambia de Pokémon dentro de la ficha sin regresar al catálogo")
end
puts "QA Libreta: OK"
