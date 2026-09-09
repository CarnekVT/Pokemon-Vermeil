# frozen_string_literal: true

require "erb"
require "cgi"
require "json"
require "fileutils"
require_relative "assets"
require_relative "diff"

module Render
  TEMPLATE_DIR = File.join(__dir__, "..", "templates")
  ASSET_DIR    = File.join(__dir__, "..", "assets")

  DETAIL_PAGES = {
    species:   ["pokemon",      "species"],
    moves:     ["movimientos",  "move"],
    abilities: ["habilidades",  "ability"],
    items:     ["objetos",      "item"],
    trainers:  ["entrenadores", "trainer"]
  }.freeze

  module_function

  def site(data:, changes:, out:, sprites:)
    attach_changes!(data, changes)

    FileUtils.rm_rf(out)
    FileUtils.mkdir_p(out)
    FileUtils.cp_r(Dir[File.join(ASSET_DIR, "*")], out)
    manifest = Assets.copy(out, data, sprites: sprites)

    ctx = View.new(data: data, changes: changes, manifest: manifest)

    write(out, "index.html", ctx.render("index", root: ""))
    write(out, "tipos.html", ctx.render("types", root: ""))
    write(out, "ubicaciones/index.html", ctx.render("locations_list", root: "../"))
    data[:locations].each do |loc|
      write(out, "ubicaciones/#{loc[:map]}.html", ctx.render("location", root: "../", loc: loc))
    end

    DETAIL_PAGES.each do |key, (folder, tmpl)|
      write(out, "#{folder}/index.html", ctx.render("list", root: "../", list_key: key, folder: folder))
      data[key].each_value do |entry|
        write(out, "#{folder}/#{entry_id(entry)}.html", ctx.render(tmpl, root: "../", entry: entry))
      end
    end

    write(out, "buscar.js", "window.WIKI_SEARCH=#{JSON.generate(search_index(data))};")
  end

  # ---------------------------------------------------------------------------

  def attach_changes!(data, changes)
    return if changes[:empty]

    %i[species moves abilities items].each do |cat|
      (changes[cat] || {}).each do |id, info|
        e = data[cat][id]
        e[:change] = info if e
      end
    end
  end

  def entry_id(entry) = entry[:key] || entry[:id]

  def write(out, rel, html)
    path = File.join(out, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, html)
  end

  def search_index(data)
    idx = []
    { species: ["pokemon", "Pokémon"], moves: ["movimientos", "Movimiento"],
      abilities: ["habilidades", "Habilidad"], items: ["objetos", "Objeto"],
      trainers: ["entrenadores", "Entrenador"] }.each do |key, (folder, label)|
      data[key].each_value do |e|
        name = e[:name] || e[:id]
        name = "#{name} · #{e[:form_name]}" if key == :species && e[:form_name] && !e[:form_name].to_s.empty?
        name = "#{e[:type_name]} #{name}" if key == :trainers
        idx << { n: name, c: label, u: "#{folder}/#{entry_id(e)}.html",
                 x: (e[:change] ? e[:change][:status] : nil) }
      end
    end
    data[:locations].each { |l| idx << { n: l[:name], c: "Ubicación", u: "ubicaciones/#{l[:map]}.html" } }
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

    def initialize(data:, changes:, manifest:)
      @data = data
      @changes = changes
      @manifest = manifest
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
    def move(id) = @data[:moves][id.to_s]
    def ability(id) = @data[:abilities][id.to_s]
    def item(id) = @data[:items][id.to_s]
    def type(id) = @data[:types][id.to_s]
    def has_changes? = !@changes[:empty]

    # -- texto ------------------------------------------------------------
    def h(str) = CGI.escapeHTML(str.to_s)
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

    def picon(id)
      side, n = @manifest[:icons][id.to_s]
      sprite_span("picon", asset("img/icons/#{id}.png"), side, n)
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
    def mon_link(id)
      s = species(id)
      %(<a class="chip mon" href="#{page(:species, id)}">#{picon(id)}<span>#{h(s ? display_name(s) : id.to_s)}</span></a>)
    end

    def move_link(id)
      m = move(id)
      %(<a class="chip" href="#{page(:moves, id)}">#{h(m ? m[:name] : id.to_s)}</a>)
    end

    def ability_link(id)
      a = ability(id)
      %(<a class="chip" href="#{page(:abilities, id)}">#{h(a ? a[:name] : id.to_s)}</a>)
    end

    def item_link(id)
      i = item(id)
      %(<a class="chip" href="#{page(:items, id)}">#{item_icon(id)}#{h(i ? i[:name] : id.to_s)}</a>)
    end

    # -- cambios --------------------------------------------------------
    def badge(entry)
      return "" unless entry[:change]

      if entry[:change][:status] == "nuevo"
        %( <span class="badge badge--new">Nuevo</span>)
      else
        fields = entry[:change][:fields].map { |f| f[:label] }.join(", ")
        %( <span class="badge badge--mod" title="Cambió: #{h(fields)}">Modificado</span>)
      end
    end

    # @return [Hash, nil] { from:, to:, dir: "up"|"down" } si esa stat cambió
    def stat_change(entry, stat_id)
      return nil unless entry[:change] && entry[:change][:status] == "modificado"

      f = entry[:change][:fields].find { |x| x[:field] == "base_stats" }
      return nil unless f && f[:from].is_a?(Hash)

      a = f[:from][stat_id].to_i
      b = f[:to][stat_id].to_i
      return nil if a == b

      { from: a, to: b, dir: (b > a ? "up" : "down") }
    end

    def change_box(entry)
      c = entry[:change]
      return "" unless c && c[:status] == "modificado" && c[:fields].any?

      fields = c[:fields]
      # el total es redundante si ya se listan las estadísticas
      fields = fields.reject { |f| f[:field] == "bst" } if fields.any? { |f| f[:field] == "base_stats" }
      rows = fields.map do |f|
        "<tr><th>#{h(f[:label])}</th><td>#{render_change(f[:field], f[:from], f[:to])}</td></tr>"
      end.join
      <<~HTML
        <section class="changebox">
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
      when "types", "abilities", "hidden_abilities", "egg_groups", "flags", "tutor_moves", "egg_moves"
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
      entry[:notes_html] ? %(<section class="notes"><h2>Notas</h2>#{entry[:notes_html]}</section>) : ""
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
