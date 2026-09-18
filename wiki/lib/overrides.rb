# frozen_string_literal: true

require "yaml"

# Capa de correcciones editable a mano por quien no programa.
#
# Un fichero por entidad a retocar:  wiki/overrides/<categoria>/<ID>.md
# (categorías: species, moves, abilities, items, trainers, locations)
#
#   ---
#   # opcional: corrige campos que salieron mal. Borra lo que no uses.
#   pokedex: "Texto corregido."
#   ---
#   Texto libre en Markdown sencillo que aparece como sección "Notas" en la ficha.
#
# ponytail: Markdown mínimo (párrafos, listas, negrita/cursiva, enlaces). Si
# alguien necesita tablas o imágenes, que escriba HTML directamente en el cuerpo:
# se pasa tal cual.
module Overrides
  CATEGORIES = %w[species moves abilities items trainers locations].freeze

  module_function

  def apply!(data, dir)
    CATEGORIES.each do |cat|
      Dir[File.join(dir, cat, "*.md")].sort.each do |path|
        id = File.basename(path, ".md")
        entry = lookup(data, cat, id)
        unless entry
          warn "overrides: no existe #{cat}/#{id}, se ignora #{path}"
          next
        end

        front, body = split(File.read(path))
        front.each { |k, v| entry[k.to_sym] = v }
        entry[:notes_html] = to_html(body) unless body.strip.empty?
      end
    end
  end

  def lookup(data, cat, id)
    if cat == "locations"
      data[:locations].find { |m| m[:map].to_s == id }
    else
      data[cat.to_sym][id]
    end
  end

  # @return [Array(Hash, String)] frontmatter (o {}) y cuerpo
  def split(text)
    if text.start_with?("---\n") && (close = text.index("\n---\n", 4))
      front = YAML.safe_load(text[4...close]) || {}
      [front, text[(close + 5)..].to_s]
    else
      [{}, text]
    end
  rescue Psych::SyntaxError => e
    warn "overrides: frontmatter YAML inválido (#{e.message})"
    [{}, text]
  end

  def to_html(md)
    blocks = md.strip.split(/\n\s*\n/)
    blocks.map { |block|
      lines = block.split("\n")
      if lines.all? { |l| l.strip.start_with?("- ") }
        "<ul>" + lines.map { |l| "<li>#{inline(l.strip.sub(/\A- /, ''))}</li>" }.join + "</ul>"
      elsif (m = block.match(/\A(\#{1,6})\s+(.*)/m))
        level = [m[1].length, 6].min
        "<h#{level}>#{inline(m[2])}</h#{level}>"
      elsif block.lstrip.start_with?("<")
        block
      else
        "<p>#{inline(block.gsub("\n", ' '))}</p>"
      end
    }.join("\n")
  end

  def inline(text)
    text.gsub(/\[([^\]]+)\]\(([^)]+)\)/) { "<a href=\"#{$2}\">#{$1}</a>" }
        .gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
        .gsub(/(?<!\*)\*([^*]+)\*(?!\*)/, '<em>\1</em>')
  end
end
