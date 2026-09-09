# Comprueba que el generador de la wiki (wiki/) produce un sitio completo a
# partir de los datos ya cargados del juego, y que el diff contra una baseline
# detecta cambios de campo.
#
# No arranca el motor por su cuenta ni recompila PBS (eso lo hace wiki/generate.rb
# en uso normal); reutiliza el motor que ya levantó el harness.

require "tmpdir"
require "json"

WIKI_LIB = File.expand_path("../../wiki/lib", __dir__)
require File.join(WIKI_LIB, "extract")
require File.join(WIKI_LIB, "diff")
require File.join(WIKI_LIB, "overrides")
require File.join(WIKI_LIB, "render")

class TestWikiGenerator < EngineTest
  def setup
    super
    @data = Extract.all
  end

  # El WriteGuard del shim bloquea toda escritura; la generación real de la wiki
  # va siempre envuelta en WriteGuard.unguarded, así que aquí igual (incluida la
  # creación del directorio temporal).
  def with_site(data, changes)
    WriteGuard.unguarded do
      Dir.mktmpdir do |out|
        Render.site(data: data, changes: changes, out: out, sprites: false)
        yield out
      end
    end
  end

  def test_site_has_a_page_for_every_kind
    with_site(@data, Diff.empty) do |out|
      assert File.exist?(File.join(out, "index.html")), "falta index.html"
      assert File.exist?(File.join(out, "tipos.html")), "falta tipos.html"
      assert File.exist?(File.join(out, "buscar.js")), "falta el índice de búsqueda"

      %w[pokemon movimientos habilidades objetos entrenadores ubicaciones].each do |folder|
        assert File.exist?(File.join(out, folder, "index.html")), "falta #{folder}/index.html"
      end

      html = File.read(File.join(out, "pokemon", "PIKACHU.html"))
      assert_includes html, "Pikachu"
      assert_includes html, "Estadísticas base"
      assert_includes html, "Movimientos por nivel"

      count = Dir[File.join(out, "pokemon", "*.html")].size
      assert_operator count, :>, 100, "se generaron muy pocas fichas de Pokémon (#{count})"
    end
  end

  def test_search_index_covers_every_species
    with_site(@data, Diff.empty) do |out|
      js = File.read(File.join(out, "buscar.js"))
      index = JSON.parse(js.sub(/\Awindow\.WIKI_SEARCH=/, "").chomp(";"))
      species_rows = index.count { |row| row["c"] == "Pokémon" }
      assert_equal @data[:species].size, species_rows
    end
  end

  def test_diff_flags_a_changed_field
    snapshot = Snapshot.reduce(@data)
    baseline = JSON.parse(JSON.generate(snapshot))

    baseline["species"]["BULBASAUR"]["base_stats"]["SPEED"] = 999
    victim_move = @data[:moves].keys.first
    baseline["moves"].delete(victim_move)

    changes = Diff.compare(snapshot, baseline)

    refute changes[:empty]
    bulba = changes[:species]["BULBASAUR"]
    refute_nil bulba, "no se detectó el cambio en Bulbasaur"
    assert_equal "modificado", bulba[:status]
    assert(bulba[:fields].any? { |f| f[:field] == "base_stats" })
    assert_equal "nuevo", changes[:moves][victim_move][:status]
  end

  def test_change_box_renders_in_the_species_page
    snapshot = Snapshot.reduce(@data)
    baseline = JSON.parse(JSON.generate(snapshot))
    baseline["species"]["BULBASAUR"]["catch_rate"] = 1
    changes = Diff.compare(snapshot, baseline)

    with_site(@data, changes) do |out|
      html = File.read(File.join(out, "pokemon", "BULBASAUR.html"))
      assert_includes html, "Cambios respecto a"
      assert_includes html, "Ratio de captura"
    end
  end

  def test_overrides_add_a_notes_section
    data = Extract.all
    WriteGuard.unguarded do
      Dir.mktmpdir do |odir|
        FileUtils.mkdir_p(File.join(odir, "species"))
        File.write(File.join(odir, "species", "BULBASAUR.md"), "---\n---\nUna nota **de prueba**.\n")
        Overrides.apply!(data, odir)
      end
    end
    assert_includes data[:species]["BULBASAUR"][:notes_html].to_s, "de prueba"

    with_site(data, Diff.empty) do |out|
      assert_includes File.read(File.join(out, "pokemon", "BULBASAUR.html")), "Notas"
    end
  end
end
