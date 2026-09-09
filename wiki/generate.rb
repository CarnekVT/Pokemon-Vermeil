#!/usr/bin/env ruby
# frozen_string_literal: true

# Genera una wiki web estática del juego a partir de sus datos.
#
#   ruby wiki/generate.rb                      # sitio en wiki/site/
#   ruby wiki/generate.rb --out publico        # otra carpeta de salida
#   ruby wiki/generate.rb --snapshot wiki/baseline.json   # vuelca el snapshot de referencia
#   ruby wiki/generate.rb --baseline none      # wiki completa sin marcar cambios
#   ruby wiki/generate.rb --no-sprites         # sin copiar imágenes
#   ruby wiki/generate.rb --no-recompile       # usa los Data/*.dat existentes tal cual
#
# No hay nada que instalar: arranca el motor con tests/harness.rb (igual que la
# suite de tests) y lee GameData directamente, así que los PBS divididos
# (pokemon_custom.txt, moves_x.txt, ...) y las secciones parciales ya vienen
# fusionados por el compilador del propio juego.

REPO_ROOT = File.expand_path("..", __dir__)

require_relative "lib/boot"
require_relative "lib/evolution"
require_relative "lib/extract"
require_relative "lib/overrides"
require_relative "lib/diff"
require_relative "lib/render"

module Wiki
  DEFAULTS = {
    out: File.join(REPO_ROOT, "wiki", "site"),
    baseline: File.join(REPO_ROOT, "wiki", "baseline.json"),
    snapshot: nil,
    sprites: true,
    recompile: true
  }.freeze

  def self.parse_args(argv)
    opts = DEFAULTS.dup
    until argv.empty?
      case (arg = argv.shift)
      when "--out"        then opts[:out] = File.expand_path(argv.shift, Dir.pwd)
      when "--baseline"   then opts[:baseline] = argv.shift
      when "--snapshot"   then opts[:snapshot] = File.expand_path(argv.shift, Dir.pwd)
      when "--no-sprites" then opts[:sprites] = false
      when "--no-recompile" then opts[:recompile] = false
      when "-h", "--help" then puts(File.read(__FILE__)[/\A(?:#.*\n)+/].gsub(/^# ?/, "")); exit
      else abort("Opción desconocida: #{arg}")
      end
    end
    opts
  end

  def self.run(argv)
    opts = parse_args(argv)
    started = Time.now

    Boot.load_engine(recompile: opts[:recompile])
    data = Extract.all

    if opts[:snapshot]
      Boot.unguarded { File.write(opts[:snapshot], JSON.pretty_generate(Snapshot.reduce(data))) }
      puts "Snapshot escrito en #{opts[:snapshot]} (#{Snapshot.reduce(data).values.sum(&:size)} entradas)"
      return
    end

    baseline = (opts[:baseline] == "none") ? nil : Diff.load(opts[:baseline])
    changes  = baseline ? Diff.compare(Snapshot.reduce(data), baseline) : Diff.empty
    Overrides.apply!(data, File.join(REPO_ROOT, "wiki", "overrides"))

    Boot.unguarded do
      Render.site(data: data, changes: changes, out: opts[:out], sprites: opts[:sprites])
    end

    puts format("Wiki generada en %s  (%.1fs)", opts[:out], Time.now - started)
    puts "  #{data[:species].size} especies · #{data[:moves].size} movimientos · " \
         "#{data[:abilities].size} habilidades · #{data[:items].size} objetos · " \
         "#{data[:trainers].size} entrenadores · #{data[:locations].size} mapas"
    unless changes[:empty]
      puts "  cambios respecto a la baseline: #{changes[:counts].map { |k, v| "#{v} #{k}" }.join(', ')}"
    end
  end
end

Wiki.run(ARGV) if $PROGRAM_NAME == __FILE__
