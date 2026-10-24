# encoding: UTF-8
# PBS propios de Vermeil. Se cargan de forma perezosa: no alteran GameData::Move
# ni la compilación estándar de Pokémon Essentials.
module GoldenSystem
  module PBS
    FORMS_PATH = "PBS/golden_forms.txt"
    MOVES_PATH = "PBS/golden_moves.txt"
    STATS_ORDER = %w[HP ATTACK DEFENSE SPECIAL_ATTACK SPECIAL_DEFENSE SPEED]
    module_function

    def signature(path)
      return nil unless File.file?(path)
      [File.size(path), File.mtime(path).to_f]
    rescue StandardError
      nil
    end

    def parse_sections(path)
      return {} unless File.file?(path)
      result = {}
      name = nil
      File.open(path, "rb") do |file|
        file.each_line.with_index(1) do |raw, line_number|
          line = raw.strip
          line = line.sub(/\A\xEF\xBB\xBF/, "")
          next if line.empty? || line.start_with?("#", ";")
          if line =~ /\A\[([^\]]+)\]\z/
            name = $1.strip.upcase
            result[name] ||= {}
          elsif name && line.include?("=")
            key, value = line.split("=", 2)
            result[name][key.strip.downcase] = value.to_s.strip
          else
            echoln("[Golden PBS] Línea ignorada #{path}:#{line_number}") if defined?(echoln)
          end
        end
      end
      result
    rescue StandardError => e
      echoln("[Golden PBS] Error leyendo #{path}: #{e.message}") if defined?(echoln)
      {}
    end

    def sections(path)
      @cache ||= {}
      sig = signature(path)
      cached = @cache[path]
      return cached[:data] if cached && cached[:stamp] == sig
      data = sig ? parse_sections(path) : {}
      @cache[path] = {:stamp => sig, :data => data}
      data
    end

    def reload!
      @cache = {}
    end

    def form_payload(species, source_form = 0)
      key = species.to_s.upcase
      exact = "#{key},#{source_form.to_i}"
      # Una entrada propia de forma origen tiene prioridad, incluso si aún es
      # un borrador incompleto. No se inventa un índice de transformación.
      fields = sections(FORMS_PATH)[exact]
      fields ||= sections(FORMS_PATH)[key] if source_form.to_i == 0
      return nil unless fields
      ret = {}
      number = fields["number"] || fields["targetform"]
      ret["number"] = number.to_i if number && number =~ /\A[0-9]+\z/
      ret["name"] = fields["name"] if fields["name"]
      ret["ability"] = fields["ability"] if fields["ability"]
      ret["types"] = fields["types"].split(",").map(&:strip) if fields["types"]
      if fields["basestats"]
        numbers = fields["basestats"].split(",").map(&:strip)
        stats = {}
        STATS_ORDER.each_with_index do |stat, i|
          stats[stat] = numbers[i].to_i if numbers[i] && numbers[i] =~ /\A\d+\z/
        end
        ret["baseStats"] = stats unless stats.empty?
      end
      ret
    end

    def form_entries
      sections(FORMS_PATH)
    end

    def move_entries
      result = {}
      sections(MOVES_PATH).each do |raw_key, fields|
        parts = raw_key.split("|").map(&:strip)
        next unless parts.length.between?(2, 3)
        species = parts[0].to_sym
        move = parts[1].to_sym
        src = (parts.length == 3 && parts[2] != "*") ? parts[2].to_i : nil
        row = { :species => species, :move => move, :source_form => src }
        row[:form] = fields["form"].to_i if fields["form"]
        row[:name] = fields["name"] if fields["name"]
        type = fields["type"]
        row[:type] = type.upcase.to_sym if type && (!defined?(GameData::Type) || GameData::Type.exists?(type.upcase.to_sym))
        row[:power] = [fields["power"].to_i, 0].max if fields["power"]
        row[:accuracy] = [[fields["accuracy"].to_i, 0].max, 100].min if fields["accuracy"]
        row[:function_code] = fields["functioncode"] if fields["functioncode"]
        row[:description] = fields["description"] if fields["description"]
        row[:effect] = fields["effect"] if fields["effect"]
        result[[species, move, src]] = row
      end
      result
    end
  end
end
