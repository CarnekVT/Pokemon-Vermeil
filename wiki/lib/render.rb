# frozen_string_literal: true

require "erb"
require "cgi"
require "json"
require "fileutils"
require "tmpdir"
require_relative "assets"
require_relative "diff"
require_relative "trainer_variants"

module Render
  TEMPLATE_DIR = File.join(__dir__, "..", "templates")
  ASSET_DIR    = File.join(__dir__, "..", "assets")
  SITE_MARKER  = ".wiki-generated"
  FEATURE_DEFAULTS = TrainerVariants::FEATURE_DEFAULTS
  NATIVE_FILE_RENAME = File.method(:rename)

  DETAIL_PAGES = {
    species:   ["pokemon",      "species"],
    moves:     ["movimientos",  "move"],
    abilities: ["habilidades",  "ability"],
    items:     ["objetos",      "item"],
    trainers:  ["entrenadores", "trainer"]
  }.freeze

  module_function

  def site(data:, changes:, out:, sprites:, accent_light:, accent_dark:, trainer_config: {}, features: {})
    attach_changes!(data, changes)
    target = File.expand_path(out)
    validate_output!(target)
    FileUtils.mkdir_p(File.dirname(target))
    stage = Dir.mktmpdir(".wiki-stage-", File.dirname(target))
    backup = nil

    begin
      FileUtils.cp_r(Dir[File.join(ASSET_DIR, "*")], stage)
      manifest = Assets.copy(stage, data, sprites: sprites)
      ctx = View.new(data: data, changes: changes, manifest: manifest, trainer_config: trainer_config, features: features)

      write(stage, "accent.css", accent_stylesheet(accent_light, accent_dark))
      write(stage, "index.html", ctx.render("index", root: ""))
      write(stage, "cambios.html", ctx.render("changes", root: "")) if ctx.feature?("changes")
      write(stage, "tipos.html", ctx.render("types", root: "")) if ctx.feature?("types")
      if ctx.feature?("locations")
        write(stage, "ubicaciones/index.html", ctx.render("locations_list", root: "../"))
        data[:locations].each do |loc|
          write(stage, "ubicaciones/#{loc[:map]}.html", ctx.render("location", root: "../", loc: loc))
        end
      end

      DETAIL_PAGES.each do |key, (folder, tmpl)|
        feature_key = key == :species ? "pokemon" : key.to_s
        next unless ctx.feature?(feature_key)

        write(stage, "#{folder}/index.html", ctx.render("list", root: "../", list_key: key, folder: folder))
        entries = key == :trainers ? data[:trainer_groups] : data[key].values
        entries.each do |entry|
          write(stage, "#{folder}/#{entry_id(entry)}.html", ctx.render(tmpl, root: "../", entry: entry))
        end
      end

      write(stage, "buscar.js", "window.WIKI_SEARCH=#{JSON.generate(search_index(data, ctx.features))};")
      File.write(File.join(stage, SITE_MARKER), "Generado por wiki/generate.rb\n")

      if File.exist?(target)
        backup = "#{target}.backup-#{Process.pid}"
        raise "Ya existe el respaldo temporal #{backup}" if File.exist?(backup)

        NATIVE_FILE_RENAME.call(target, backup)
      end
      NATIVE_FILE_RENAME.call(stage, target)
    rescue StandardError
      NATIVE_FILE_RENAME.call(backup, target) if backup && File.exist?(backup) && !File.exist?(target)
      raise
    ensure
      FileUtils.remove_entry_secure(stage) if File.exist?(stage)
    end

    FileUtils.remove_entry_secure(backup) if backup && File.exist?(backup)
  end

  def accent_stylesheet(light, dark)
    <<~CSS
      :root {
        --accent-light: #{light};
        --accent-dark: #{dark};
        --accent-on-light: #{accent_foreground(light)};
        --accent-on-dark: #{accent_foreground(dark)};
      }
    CSS
  end

  def accent_foreground(color)
    channels = color.delete_prefix("#").scan(/../).map { |channel| channel.to_i(16) }
    luminance = channels.map do |value|
      normalized = value / 255.0
      normalized <= 0.04045 ? normalized / 12.92 : ((normalized + 0.055) / 1.055)**2.4
    end
    brightness = luminance.zip([0.2126, 0.7152, 0.0722]).sum { |value, weight| value * weight }
    brightness > 0.179 ? "#1b1d21" : "#ffffff"
  end

  # ponytail: solo se reemplazan wiki/site o salidas marcadas; ampliar el destino permitido si Pages usa otra carpeta existente.
  def validate_output!(target)
    root = File.expand_path(File::SEPARATOR)
    repo = File.expand_path("../..", __dir__)
    if target == root || target == repo || repo.start_with?("#{target}#{File::SEPARATOR}")
      raise ArgumentError, "La salida no puede ser la raíz ni contener el repositorio: #{target}"
    end

    current = File::SEPARATOR
    target.split(File::SEPARATOR).reject(&:empty?).each do |part|
      current = File.join(current, part)
      raise ArgumentError, "La ruta de salida atraviesa un enlace simbólico: #{current}" if File.symlink?(current)
    end

    return unless File.exist?(target)
    raise ArgumentError, "La salida existe y no es una carpeta: #{target}" unless File.directory?(target)

    default_output = File.expand_path(File.join(repo, "wiki", "site"))
    marker = File.join(target, SITE_MARKER)
    marked = File.file?(marker) && !File.symlink?(marker)
    has_content = !Dir.children(target).empty?
    if has_content && !marked && target != default_output
      raise ArgumentError, "La carpeta de salida no parece una wiki generada: #{target}"
    end
  end

  # ---------------------------------------------------------------------------

  def attach_changes!(data, changes)
    return if changes[:empty]

    %i[species moves abilities items types].each do |cat|
      (changes[cat] || {}).each do |id, info|
        e = data[cat][id]
        e[:change] = info if e
      end
    end
  end

  def entry_id(entry) = entry[:page_id] || entry[:key] || entry[:id]

  def write(out, rel, html)
    path = File.join(out, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, html)
  end

  def search_index(data, features = FEATURE_DEFAULTS)
    idx = []
    { species: ["pokemon", "Pokémon"], moves: ["movimientos", "Movimiento"],
      abilities: ["habilidades", "Habilidad"], items: ["objetos", "Objeto"],
      trainers: ["entrenadores", "Entrenador"] }.each do |key, (folder, label)|
      feature_key = key == :species ? "pokemon" : key.to_s
      next unless features.fetch(feature_key, true)

      entries = if key == :species
                  groups = data[:species].values.group_by { |entry| entry[:species] }
                  order = data[:dex_order].uniq
                  order.concat(groups.keys - order)
                  order.filter_map do |species|
                    forms = groups[species]
                    next if forms.nil? || forms.empty?

                    base = forms.find { |form| form[:form].to_i.zero? } || forms.min_by { |form| form[:form].to_i }
                    [base, forms]
                  end
                elsif key == :trainers
                  data[:trainer_groups].map { |group| [group, group[:variants]] }
                else
                  data[key].values.map { |entry| [entry, [entry]] }
                end
      entries.each do |e, forms|
        name = e[:name] || e[:id]
        name = "#{e[:type_name]} #{name}" if key == :trainers
        aliases = key == :species ? forms.filter_map { |form| form[:form_name] }.uniq : []
        changed = forms.find { |form| features.fetch("changes", true) && form[:change] }
        idx << { n: name, s: aliases.join(" "), c: label, u: "#{folder}/#{entry_id(e)}.html",
                 x: (changed ? changed[:change][:status] : nil) }
      end
    end
    if features.fetch("locations", true)
      data[:locations].each { |l| idx << { n: l[:name], c: "Ubicación", u: "ubicaciones/#{l[:map]}.html" } }
    end
    data[:types].each_value do |t|
      next unless features.fetch("types", true)
      next if t[:pseudo]

      idx << { n: t[:name], c: "Tipo", u: "tipos.html##{t[:id]}", x: (features.fetch("changes", true) && t[:change] ? t[:change][:status] : nil) }
    end
    idx
  end

  # ===========================================================================

  class View
    # Etiqueta de la referencia contra la que se comparan los datos.
    BASELINE_LABEL = "los juegos oficiales"

    STAT_LABELS = {
      "HP" => "PS", "ATTACK" => "Ataque", "DEFENSE" => "Defensa", "SPEED" => "Velocidad",
      "SPECIAL_ATTACK" => "At. Esp.", "SPECIAL_DEFENSE" => "Def. Esp."
    }.freeze

    attr_reader :features

    def initialize(data:, changes:, manifest:, trainer_config: {}, features: {})
      @data = data
      @species_forms = data[:species].values.group_by { |form| form[:species] }
      @evolution_outgoing = Hash.new { |hash, key| hash[key] = [] }
      @evolution_incoming = Hash.new { |hash, key| hash[key] = [] }
      @species_forms.each do |from, forms|
        forms.flat_map { |form| form[:evolves_to] }.uniq { |edge| [edge[:to], edge[:text]] }.each do |edge|
          next unless @species_forms.key?(edge[:to])

          relation = { from: from, to: edge[:to], text: edge[:text] }
          @evolution_outgoing[from] << relation
          @evolution_incoming[edge[:to]] << relation
        end
      end
      @changes = changes
      @manifest = manifest
      @trainer_config = trainer_config
      @features = FEATURE_DEFAULTS.merge(features.is_a?(Hash) ? features.transform_keys(&:to_s).slice(*FEATURE_DEFAULTS.keys) : {})
      @erb = {}
      @type_color_cache = {}
      @root = ""
    end

    def render(template, root:, **locals)
      @root = root
      @locals = locals
      @title = nil
      content = erb(template).result(binding)
      return content if template == "layout"

      @title ||= meta[:game_title]
      erb("layout").result(binding)
    end

    def title(str)
      @title = str
      nil
    end

    # -- datos --------------------------------------------------------------
    attr_reader :data, :changes, :locals

    def meta = @data[:meta]
    def species(id) = @data[:species][id.to_s]
    def species_forms(entry) = @species_forms[entry[:species]] || [entry]

    def evolution_paths(entry)
      current = entry[:species]
      ancestors = evolution_ancestors(current)
      descendants = evolution_descendants(current)
      (ancestors.product(descendants).map { |before, after| before + after }).uniq.filter_map do |edges|
        next if edges.empty?

        ids = [edges.first[:from]] + edges.map { |edge| edge[:to] }
        ids.each_with_index.map do |species_id, index|
          base = @species_forms[species_id]&.find { |form| form[:form].to_i.zero? }
          base ||= @species_forms[species_id]&.first
          next unless base

          { id: base[:id], species: species_id, method: edges[index]&.dig(:text) }
        end.compact
      end
    end

    def form_label(entry)
      return entry[:form_name] if entry[:form_name] && !entry[:form_name].to_s.empty?

      entry[:form].to_i.zero? ? "Normal" : "Forma #{entry[:form]}"
    end

    def evolution_ancestors(species_id, visited = [])
      return [[]] if visited.include?(species_id)

      edges = @evolution_incoming[species_id]
      return [[]] if edges.empty?

      edges.flat_map do |edge|
        evolution_ancestors(edge[:from], visited + [species_id]).map { |path| path + [edge] }
      end
    end

    def evolution_descendants(species_id, visited = [])
      return [[]] if visited.include?(species_id)

      edges = @evolution_outgoing[species_id]
      return [[]] if edges.empty?

      edges.flat_map do |edge|
        evolution_descendants(edge[:to], visited + [species_id]).map { |path| [edge] + path }
      end
    end

    def move(id) = @data[:moves][id.to_s]
    def ability(id) = @data[:abilities][id.to_s]
    def item(id) = @data[:items][id.to_s]
    def type(id) = @data[:types][id.to_s]
    def has_changes? = feature?("changes") && !@changes[:empty]
    def trainer_default_mode = @trainer_config["default_mode"]
    def feature?(key) = @features.fetch(key.to_s, true)

    def type_multiplier(definition, attack_id, fields: nil)
      values = {
        "weaknesses" => definition[:weaknesses],
        "resistances" => definition[:resistances],
        "immunities" => definition[:immunities]
      }
      fields&.each do |field|
        values[field[:field]] = field[:from] if field[:field] && field[:from]
      end
      return 0 if Array(values["immunities"]).include?(attack_id)
      return 2 if Array(values["weaknesses"]).include?(attack_id)
      return 0.5 if Array(values["resistances"]).include?(attack_id)

      1
    end

    def type_cell_change(definition, attack_id)
      return nil unless feature?("changes")

      change = definition[:change]
      return nil unless change && change[:status] == "modificado"

      before = type_multiplier(definition, attack_id, fields: change[:fields])
      after = type_multiplier(definition, attack_id)
      return nil if before == after

      { from: before, to: after }
    end

    def multiplier_label(value)
      { 0 => "×0", 0.5 => "×½", 1 => "×1", 2 => "×2" }[value] || "×#{value}"
    end

    # -- texto ------------------------------------------------------------
    def h(str) = CGI.escapeHTML(str.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�"))
    def page_search_text(*values)
      values.flatten.compact.map do |value|
        value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�")
      end.join(" ")
    end
    def asset(path) = "#{@root}#{path}"

    def page(kind, id)
      folder = { species: "pokemon", moves: "movimientos", abilities: "habilidades",
                 items: "objetos", trainers: "entrenadores", locations: "ubicaciones" }[kind]
      "#{@root}#{folder}/#{id}.html"
    end

    def pct(n) = n.nil? ? "" : (n == n.to_i ? "#{n.to_i} %" : format("%.1f %%", n))
    def level_range(min, max) = (min == max) ? "Nv. #{min}" : "Nv. #{min}–#{max}"

    def display_name(s)
      s[:form_name] && !s[:form_name].to_s.empty? ? "#{s[:name]} · #{s[:form_name]}" : s[:name]
    end

    # -- sprites animados -------------------------------------------------
    def sprite_span(cls, url, side, n, extra_style = "")
      return %(<span class="#{cls} is-missing"></span>) unless side&.positive?

      %(<span class="#{cls}" style="--s:#{side}px;--n:#{n};background-image:url(#{url});#{extra_style}"></span>)
    end

    def picon(id, shiny: false)
      shiny_sprite = @manifest.fetch(:icons_shiny, {})[id.to_s] if shiny
      if shiny_sprite
        side, n = shiny_sprite
        return sprite_span("picon", asset("img/icons-shiny/#{id}.png"), side, n)
      end

      side, n = @manifest[:icons][id.to_s]
      sprite_span("picon", asset("img/icons/#{id}.png"), side, n)
    end

    def stat_values(values, omit_zero: false)
      Array(values).filter_map do |stat, value|
        next if value.nil? || (omit_zero && value.to_i.zero?)

        "#{STAT_LABELS[stat] || stat}: #{value}"
      end.join(" · ")
    end

    def psprite(id, hero: false)
      side, n = @manifest[:front][id.to_s]
      return "" if hero && !side

      scale = (hero && side&.positive?) ? (190.0 / side).round(3) : nil
      style = scale ? "--scale:#{scale}" : ""
      sprite_span(hero ? "psprite psprite--hero" : "psprite", asset("img/front/#{id}.png"), side, n, style)
    end

    def tsprite(type_id, hero: false)
      side, n = @manifest[:trainers][type_id.to_s]
      return "" unless side # sin sprite: no dibujamos hueco

      scale = (hero && side&.positive?) ? (170.0 / side).round(3) : nil
      style = scale ? "--scale:#{scale}" : ""
      sprite_span(hero ? "tsprite tsprite--hero" : "tsprite", asset("img/trainers/#{type_id}.png"), side, n, style)
    end

    # Lista de chips; si es larga, se pliega tras un resumen.
    def chiplist(html, count, noun: "Pokémon", threshold: 45)
      return %(<p class="chiplist">#{html}</p>) if count <= threshold

      %(<details class="chiplist-more"><summary>Ver los #{count} #{noun}</summary><p class="chiplist">#{html}</p></details>)
    end

    def item_icon(id, size: 26)
      return "" unless @manifest[:items].include?(id.to_s)

      %(<img class="iicon" src="#{asset("img/items/#{id}.png")}" alt="" width="#{size}" height="#{size}" style="width:#{size}px;height:#{size}px" loading="lazy">)
    end

    # -- tipos: icono recortado de la hoja del propio juego -------------
    # scale < 1 encoge el icono (para la matriz de tipos, donde a tamaño real no
    # caben las 19 columnas).
    def type_tag(type_id, small: false, link: true, scale: nil, fit: false)
      link = false unless feature?("types")
      scale ||= small ? 0.82 : 1.0
      t = type(type_id)
      label = t ? t[:name] : type_id.to_s
      sheet = @manifest[:type_sheet]
      if sheet && t
        pos = t[:icon_position].to_i
        rows = sheet[:rows].to_i
        if fit
          # se adapta al ancho de la celda (para la matriz de tipos): sin scroll.
          style = "--i:#{pos};--rows:#{rows};aspect-ratio:#{sheet[:w]}/#{sheet[:row_h]}"
          inner = %(<span class="tico tico--fit" style="#{style}" role="img" aria-label="#{h(label)}"></span>)
        else
          w = (sheet[:w] * scale).round
          rh = (sheet[:row_h] * scale).round
          full = rh * rows
          style = "width:#{w}px;height:#{rh}px;background-size:#{w}px #{full}px;background-position:0 #{-pos * rh}px"
          inner = %(<span class="tico" style="#{style}" role="img" aria-label="#{h(label)}"></span>)
        end
      else
        inner = %(<span class="tp">#{h(label)}</span>)
      end
      cls = "type#{small ? ' type--sm' : ''}#{fit ? ' type--fit' : ''}"
      link ? %(<a class="#{cls}" href="#{@root}tipos.html##{type_id}">#{inner}</a>) : %(<span class="#{cls}">#{inner}</span>)
    end

    def types_row(ids, small: false, link: true) = ids.map { |t| type_tag(t, small: small, link: link) }.join

    # -- enlaces con icono ---------------------------------------------
    def mon_link(id, current: false)
      s = species(id)
      cls = current ? "chip mon evolution-current" : "chip mon"
      current_attr = current ? ' aria-current="page"' : ""
      %(<a class="#{cls}" href="#{page(:species, id)}"#{current_attr}>#{picon(id)}<span>#{h(s ? display_name(s) : id.to_s)}</span></a>)
    end

    def move_link(id)
      m = move(id)
      text = h(m ? m[:name] : id.to_s)
      feature?("moves") ? %(<a class="chip" href="#{page(:moves, id)}">#{text}</a>) : %(<span class="chip">#{text}</span>)
    end

    def ability_link(id)
      a = ability(id)
      text = h(a ? a[:name] : id.to_s)
      feature?("abilities") ? %(<a class="chip" href="#{page(:abilities, id)}">#{text}</a>) : %(<span class="chip">#{text}</span>)
    end

    def item_link(id)
      i = item(id)
      content = %(#{item_icon(id)}#{h(i ? i[:name] : id.to_s)})
      feature?("items") ? %(<a class="chip" href="#{page(:items, id)}">#{content}</a>) : %(<span class="chip">#{content}</span>)
    end

    # -- cambios --------------------------------------------------------
    def badge(entry)
      return "" unless feature?("changes") && entry[:change]

      if entry[:change][:status] == "nuevo"
        %( <span class="badge badge--new">Nuevo</span>)
      else
        fields = entry[:change][:fields].map { |f| f[:label] }.join(", ")
        %( <span class="badge badge--mod" title="Cambió: #{h(fields)}">Modificado</span>)
      end
    end

    # @return [Hash, nil] { from:, to:, dir: "up"|"down" } si esa stat cambió
    def stat_change(entry, stat_id)
      return nil unless feature?("changes") && entry[:change] && entry[:change][:status] == "modificado"

      f = entry[:change][:fields].find { |x| x[:field] == "base_stats" }
      return nil unless f && f[:from].is_a?(Hash)

      a = f[:from][stat_id].to_i
      b = f[:to][stat_id].to_i
      return nil if a == b

      { from: a, to: b, dir: (b > a ? "up" : "down") }
    end

    def change_box(entry)
      return "" unless feature?("changes")

      c = entry[:change]
      return "" unless c && c[:status] == "modificado" && c[:fields].any?

      fields = c[:fields]
      # el total es redundante si ya se listan las estadísticas
      fields = fields.reject { |f| f[:field] == "bst" } if fields.any? { |f| f[:field] == "base_stats" }
      rows = fields.map do |f|
        "<tr><th>#{h(f[:label])}</th><td>#{render_change(f[:field], f[:from], f[:to])}</td></tr>"
      end.join
      <<~HTML
        <section class="changebox" id="cambios">
          <h2>Cambios respecto a #{BASELINE_LABEL}</h2>
          <table>#{rows}</table>
        </section>
      HTML
    end

    STAT_ABBR = {
      "HP" => "PS", "ATTACK" => "At.", "DEFENSE" => "Def.", "SPEED" => "Vel.",
      "SPECIAL_ATTACK" => "At.Esp.", "SPECIAL_DEFENSE" => "Def.Esp."
    }.freeze

    def render_change(field, from, to)
      case field
      when "base_stats" then stat_delta_table(from, to)
      when "evs"        then hash_delta(from, to) { |k| STAT_ABBR[k] || k }
      when "moves"      then pair_delta(from, to) { |lvl, mv| "Nv.#{lvl} #{move_name(mv)}" }
      when "evolves_to" then evo_delta(from, to)
      when "types", "weaknesses", "resistances", "immunities", "abilities", "hidden_abilities", "egg_groups", "flags", "tutor_moves", "egg_moves"
        list_delta(from, to)
      when "wild_items"
        list_delta((from || []).map { |x| x["item"] }, (to || []).map { |x| x["item"] })
      when "description", "pokedex", "lose_text"
        %(<div class="old">#{h(truncate(from))}</div><div class="new">#{h(truncate(to))}</div>)
      else
        %(<span class="old">#{fmt_scalar(from)}</span> <span class="arrow">→</span> <span class="new">#{fmt_scalar(to)}</span>)
      end
    end

    def stat_delta_table(from, to)
      from ||= {}
      to ||= {}
      rows = STAT_LABELS.filter_map do |sid, label|
        a = from[sid].to_i
        b = to[sid].to_i
        next if a == b

        d = b - a
        "<tr><th>#{label}</th><td class=\"old\">#{a}</td><td class=\"arrow\">→</td>" \
          "<td class=\"new\">#{b}</td><td class=\"delta #{d.positive? ? 'up' : 'down'}\">#{d.positive? ? '+' : ''}#{d}</td></tr>"
      end.join
      %(<table class="statdelta">#{rows}</table>)
    end

    def hash_delta(from, to)
      from ||= {}
      to ||= {}
      keys = (from.keys | to.keys).select { |k| from[k] != to[k] }
      label = block_given? ? ->(k) { yield(k) } : ->(k) { k }
      parts = keys.map do |k|
        "#{label.call(k)} <span class=\"old\">#{from[k] || 0}</span>→<span class=\"new\">#{to[k] || 0}</span>"
      end
      h_parts = parts.join(", ")
      # ya escapado lo justo; los valores son numéricos
      h_parts
    end

    def list_delta(from, to)
      from = Array(from).map(&:to_s)
      to = Array(to).map(&:to_s)
      added = (to - from).map { |x| resolve_name(x) }
      removed = (from - to).map { |x| resolve_name(x) }
      parts = []
      parts << %(<span class="new">+ #{h(added.join(', '))}</span>) unless added.empty?
      parts << %(<span class="old">− #{h(removed.join(', '))}</span>) unless removed.empty?
      parts.join(" ")
    end

    def pair_delta(from, to)
      from = Array(from)
      to = Array(to)
      added = (to - from).map { |p| yield(*p) }
      removed = (from - to).map { |p| yield(*p) }
      [added.empty? ? nil : %(<span class="new">+ #{h(added.join(', '))}</span>),
       removed.empty? ? nil : %(<span class="old">− #{h(removed.join(', '))}</span>)].compact.join(" ")
    end

    def evo_delta(from, to)
      fmt = ->(list) { Array(list).map { |e| "→ #{resolve_name(e['to'])} (#{e['text']})" }.join("; ") }
      %(<div class="old">#{h(fmt.call(from))}</div><div class="new">#{h(fmt.call(to))}</div>)
    end

    def notes(entry)
      return "" unless feature?("notes") && entry[:notes_html]

      %(<section class="notes"><h2>Notas</h2>#{entry[:notes_html]}</section>)
    end

    # -- utilidades -----------------------------------------------------
    def resolve_name(id)
      species(id)&.dig(:name) || move(id)&.dig(:name) || ability(id)&.dig(:name) ||
        item(id)&.dig(:name) || type(id)&.dig(:name) || id.to_s
    end

    def move_name(id) = move(id)&.dig(:name) || id.to_s
    def truncate(str, n = 160) = str.to_s.length > n ? "#{str[0, n]}…" : str.to_s

    def fmt_scalar(v)
      case v
      when nil then "<em>—</em>"
      when true then "sí"
      when false then "no"
      when Hash then h(v["text"] || v.values.join(" "))
      else h(v.to_s)
      end
    end

    private

    def erb(name)
      @erb[name] ||= ERB.new(File.read(File.join(TEMPLATE_DIR, "#{name}.erb")), trim_mode: "-")
    end
  end
end
