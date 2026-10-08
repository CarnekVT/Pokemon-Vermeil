#!/usr/bin/env ruby
# frozen_string_literal: true

# Genera una wiki web estática del juego a partir de sus datos.
#
#   ruby wiki/generate.rb                      # asistente en terminal; sitio en wiki/site/
#   ruby wiki/generate.rb --out publico        # otra carpeta de salida
#   ruby wiki/generate.rb --snapshot /tmp/baseline.json  # guarda una vista previa del snapshot
#   ruby wiki/generate.rb --baseline none      # wiki completa sin marcar cambios
#   ruby wiki/generate.rb --no-sprites         # sin copiar imágenes
#   ruby wiki/generate.rb --accent "#336699"   # mismo accent en ambos temas
#   ruby wiki/generate.rb --accent-light "#1a3d5c" --accent-dark "#5ba0d6"
#   ruby wiki/generate.rb --no-recompile       # usa los Data/*.dat existentes tal cual
#   ruby wiki/generate.rb --configure          # abre el editor visual local
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
require_relative "lib/trainer_variants"
require_relative "lib/configurator"

module Wiki
  DEFAULTS = {
    out: File.join(REPO_ROOT, "wiki", "site"),
    baseline: File.join(REPO_ROOT, "wiki", "baseline.json"),
    snapshot: nil,
    sprites: true,
    recompile: true,
    accent_light: "#1a3d5c",
    accent_dark: "#5ba0d6",
    configure: false
  }.freeze

  def self.configured_options(config = TrainerVariants.load)
    settings = config["settings"] || {}
    out = File.expand_path(settings.fetch("out", "wiki/site"), REPO_ROOT)
    baseline_value = settings.fetch("baseline", "wiki/baseline.json")
    baseline = baseline_value == "none" ? "none" : File.expand_path(baseline_value, REPO_ROOT)
    DEFAULTS.merge(
      out: out, baseline: baseline,
      sprites: settings.fetch("sprites", true),
      recompile: settings.fetch("recompile", true),
      accent_light: settings.fetch("accent_light", "#1a3d5c"),
      accent_dark: settings.fetch("accent_dark", "#5ba0d6")
    )
  end

  def self.parse_args(argv)
    opts = configured_options
    until argv.empty?
      case (arg = argv.shift)
      when "--out"        then opts[:out] = File.expand_path(option_value!(argv, arg), Dir.pwd)
      when "--baseline"   then opts[:baseline] = option_value!(argv, arg)
      when "--snapshot"   then opts[:snapshot] = File.expand_path(option_value!(argv, arg), Dir.pwd)
      when "--accent"
        color = accent_option_value!(argv, arg)
        opts[:accent_light] = color
        opts[:accent_dark] = color
      when "--accent-light"
        opts[:accent_light] = accent_option_value!(argv, arg)
      when "--accent-dark"
        opts[:accent_dark] = accent_option_value!(argv, arg)
      when "--no-sprites" then opts[:sprites] = false
      when "--configure" then opts[:configure] = true
      when "--no-recompile" then opts[:recompile] = false
      when "-h", "--help" then puts(File.read(__FILE__)[/\A(?:#.*\n)+/].gsub(/^# ?/, "")); exit
      else abort("Opción desconocida: #{arg}")
      end
    end
    opts
  end

  def self.normalize_accent(value)
    color = value.strip
    color = "##{color}" unless color.start_with?("#")
    color.downcase if color.match?(%r{\A#[0-9a-fA-F]{6}\z})
  end

  def self.accent_option_value!(argv, option)
    color = normalize_accent(option_value!(argv, option))
    abort("Color no válido. Usa #RRGGBB, por ejemplo #1a3d5c.") unless color

    color
  end

  def self.option_value!(argv, option)
    value = argv.shift
    abort("Falta el valor de #{option}.") if value.nil? || value.start_with?("--")

    value
  end

  # ponytail: el asistente expone opciones frecuentes; la CLI conserva el resto.
  def self.interactive_options
    puts "Generador de wiki para jugadores"
    puts "1. Generar wiki con la configuración guardada"
    puts "2. Ajustar opciones en terminal"
    puts "3. Configurar la wiki en el navegador"
    puts "4. Salir"
    choice = prompt_choice("Elige una opción", %w[1 2 3 4], "1")
    return nil if choice.nil? || choice == "4"

    opts = configured_options
    return opts.merge(configure: true, persist_settings: true) if choice == "3"

    if choice == "2"
      out = prompt_text("Carpeta de salida", opts[:out])
      return nil if out.nil?
      opts[:out] = File.expand_path(out, Dir.pwd)

      sprites = prompt_yes_no("Copiar imágenes de Pokémon y objetos", opts[:sprites])
      return nil if sprites.nil?
      opts[:sprites] = sprites

      recompile = prompt_yes_no("Recompilar los PBS antes de generar", opts[:recompile])
      return nil if recompile.nil?
      opts[:recompile] = recompile

      baseline = prompt_yes_no("Marcar cambios respecto a los juegos oficiales", opts[:baseline] != "none")
      return nil if baseline.nil?
      opts[:baseline] = baseline ? File.join(REPO_ROOT, "wiki", "baseline.json") : "none"
    end

    accent_light = prompt_accent("modo claro", opts[:accent_light])
    return nil if accent_light.nil?
    opts[:accent_light] = accent_light

    accent_dark = prompt_accent("modo oscuro", opts[:accent_dark])
    return nil if accent_dark.nil?
    opts[:accent_dark] = accent_dark

    puts ""
    puts "Salida: #{opts[:out]}"
    puts "Accent claro: #{opts[:accent_light]}"
    puts "Accent oscuro: #{opts[:accent_dark]}"
    puts "PBS: #{opts[:recompile] ? 'se recompilan' : 'usar datos compilados'}"
    puts "Imágenes: #{opts[:sprites] ? 'incluidas' : 'omitidas'}"
    prompt_yes_no("Generar la wiki con estas opciones", true) ? opts.merge(persist_settings: true) : nil
  end

  def self.prompt_accent(theme, default)
    loop do
      value = prompt_text("Color accent para #{theme} (#RRGGBB)", default)
      return nil if value.nil?

      color = normalize_accent(value)
      return color if color

      puts "Color no válido. Usa #RRGGBB, por ejemplo #1a3d5c."
    end
  end

  def self.prompt_choice(label, choices, default)
    loop do
      print "#{label} [#{default}]: "
      value = $stdin.gets
      return nil if value.nil?

      value = value.strip
      value = default if value.empty?
      return value if choices.include?(value)

      puts "Elige #{choices.join(', ')}."
    end
  end

  def self.prompt_text(label, default)
    print "#{label} [#{default}]: "
    value = $stdin.gets
    return nil if value.nil?

    value.strip.empty? ? default : value.strip
  end

  def self.prompt_yes_no(label, default)
    suffix = default ? "S/n" : "s/N"
    loop do
      print "#{label}? [#{suffix}]: "
      value = $stdin.gets
      return nil if value.nil?
      return default if value.strip.empty?

      answer = value.strip.downcase
      return true if %w[s si sí y yes].include?(answer)
      return false if %w[n no].include?(answer)

      puts "Responde sí o no."
    end
  end

  def self.config_settings(opts)
    relative = lambda do |path|
      expanded = File.expand_path(path, REPO_ROOT)
      expanded.start_with?("#{REPO_ROOT}/") ? expanded.delete_prefix("#{REPO_ROOT}/") : expanded
    end
    {
      "out" => relative.call(opts[:out]),
      "baseline" => opts[:baseline] == "none" ? "none" : relative.call(opts[:baseline]),
      "sprites" => opts[:sprites], "recompile" => opts[:recompile],
      "accent_light" => opts[:accent_light], "accent_dark" => opts[:accent_dark]
    }
  end

  def self.run(argv)
    opts = argv.empty? && $stdin.tty? ? interactive_options : parse_args(argv)
    return unless opts

    started = Time.now
    config = TrainerVariants.load

    initially_recompiled = opts[:recompile]
    Boot.load_engine(recompile: initially_recompiled)
    data = Extract.all

    if opts[:configure]
      groups = TrainerVariants.build_groups(data[:trainers], config, data[:species])
      config = WikiConfigurator.open(config: config, groups: groups, species: data[:species])
      opts = configured_options(config).merge(persist_settings: true)
      if opts[:recompile] && !initially_recompiled
        Boot.load_engine(recompile: true)
        data = Extract.all
      end
    end

    if opts[:persist_settings]
      Boot.unguarded { TrainerVariants.save(config.merge("settings" => config_settings(opts))) }
    end
    if opts[:snapshot]
      snapshot = Snapshot.reduce(data)
      Boot.unguarded { File.write(opts[:snapshot], JSON.pretty_generate(Snapshot.document(data))) }
      puts "Snapshot escrito en #{opts[:snapshot]} (#{snapshot.values.sum(&:size)} entradas)"
      return
    end

    baseline = (opts[:baseline] == "none") ? nil : Diff.load(opts[:baseline])
    changes  = baseline ? Diff.compare(Snapshot.reduce(data), baseline) : Diff.empty
    Overrides.apply!(data, File.join(REPO_ROOT, "wiki", "overrides"))
    data[:trainer_groups] = TrainerVariants.build_groups(data[:trainers], config, data[:species])

    Boot.unguarded do
      Render.site(data: data, changes: changes, out: opts[:out], sprites: opts[:sprites],
                  accent_light: opts[:accent_light], accent_dark: opts[:accent_dark],
                  trainer_config: config, features: config["features"])
    end

    puts format("Wiki generada en %s  (%.1fs)", opts[:out], Time.now - started)
    puts "  #{data[:species].size} especies · #{data[:moves].size} movimientos · " \
         "#{data[:abilities].size} habilidades · #{data[:items].size} objetos · " \
         "#{data[:trainer_groups].size} combates · #{data[:locations].size} mapas"
    unless changes[:empty]
      puts "  cambios respecto a la baseline: #{changes[:counts].map { |k, v| "#{v} #{k}" }.join(', ')}"
    end
  end
end

Wiki.run(ARGV) if $PROGRAM_NAME == __FILE__
