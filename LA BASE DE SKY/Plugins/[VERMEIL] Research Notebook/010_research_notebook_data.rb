# encoding: UTF-8
#===============================================================================
# Libreta de Investigación - Lectura y adaptación de datos
# Lee los JSON existentes de Habilidades Arcanas y del sistema Áureo.
# No crea una segunda fuente de verdad.
#===============================================================================
module ResearchNotebook
  #---------------------------------------------------------------------------
  # Parser JSON pequeño y autocontenido.
  # Se evita depender de `require "json"`, que no siempre está disponible en
  # entornos de Pokémon Essentials/mkxp-z distribuidos.
  #---------------------------------------------------------------------------
  module MiniJSON
    class ParseError < StandardError; end

    class Parser
      def initialize(text)
        source = text.to_s.dup
        if source.bytesize >= 3 && source.getbyte(0) == 0xEF && source.getbyte(1) == 0xBB && source.getbyte(2) == 0xBF
          source = source.byteslice(3, source.bytesize - 3)
        end
        @text = source.b
        @index = 0
        @length = @text.bytesize
      end

      def parse
        skip_ws
        value = parse_value
        skip_ws
        raise ParseError, "Contenido extra después del JSON (posición #{@index})." if @index < @length
        return value
      end

      private

      def current
        return nil if @index >= @length
        return @text.getbyte(@index)
      end

      def skip_ws
        while @index < @length
          c = @text.getbyte(@index)
          break if c != 32 && c != 9 && c != 10 && c != 13
          @index += 1
        end
      end

      def parse_value
        skip_ws
        c = current
        raise ParseError, "JSON incompleto." if c.nil?
        case c
        when 123 then return parse_object       # {
        when 91  then return parse_array        # [
        when 34  then return parse_string       # "
        when 45, 48..57 then return parse_number
        when 116 then consume_literal("true");  return true
        when 102 then consume_literal("false"); return false
        when 110 then consume_literal("null");  return nil
        end
        raise ParseError, "Valor JSON inválido en posición #{@index}."
      end

      def parse_object
        result = {}
        @index += 1
        skip_ws
        if current == 125
          @index += 1
          return result
        end
        loop do
          skip_ws
          raise ParseError, "Se esperaba una clave de texto." if current != 34
          key = parse_string
          skip_ws
          raise ParseError, "Se esperaba ':' después de '#{key}'." if current != 58
          @index += 1
          result[key] = parse_value
          skip_ws
          case current
          when 44
            @index += 1
          when 125
            @index += 1
            break
          else
            raise ParseError, "Se esperaba ',' o '}' en posición #{@index}."
          end
        end
        return result
      end

      def parse_array
        result = []
        @index += 1
        skip_ws
        if current == 93
          @index += 1
          return result
        end
        loop do
          result << parse_value
          skip_ws
          case current
          when 44
            @index += 1
          when 93
            @index += 1
            break
          else
            raise ParseError, "Se esperaba ',' o ']' en posición #{@index}."
          end
        end
        return result
      end

      def parse_string
        raise ParseError, "Se esperaba una cadena." if current != 34
        @index += 1
        out = +"".b
        while @index < @length
          c = @text.getbyte(@index)
          @index += 1
          return out.force_encoding(Encoding::UTF_8) if c == 34
          if c == 92
            raise ParseError, "Escape incompleto." if @index >= @length
            esc = @text.getbyte(@index)
            @index += 1
            case esc
            when 34  then out << '"'
            when 92  then out << '\\'
            when 47  then out << '/'
            when 98  then out << "\b"
            when 102 then out << "\f"
            when 110 then out << "\n"
            when 114 then out << "\r"
            when 116 then out << "\t"
            when 117
              hex = @text[@index, 4]
              raise ParseError, "Escape Unicode inválido." if !hex || hex !~ /\A[0-9a-fA-F]{4}\z/
              @index += 4
              code = hex.to_i(16)
              # Pareja surrogate UTF-16.
              if code >= 0xD800 && code <= 0xDBFF && @text[@index, 2] == "\\u"
                hex2 = @text[@index + 2, 4]
                if hex2 && hex2 =~ /\A[0-9a-fA-F]{4}\z/
                  low = hex2.to_i(16)
                  if low >= 0xDC00 && low <= 0xDFFF
                    @index += 6
                    code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                  end
                end
              end
              begin
                out << [code].pack("U").b
              rescue
                out << "?".b
              end
            else
              raise ParseError, "Escape JSON desconocido."
            end
          else
            # Copia byte a byte; el texto del proyecto ya es UTF-8.
            out << c
          end
        end
        raise ParseError, "Cadena JSON sin cerrar."
      end

      def parse_number
        start = @index
        @index += 1 if current == 45
        if current == 48
          @index += 1
        else
          raise ParseError, "Número inválido." if !current || current < 49 || current > 57
          @index += 1 while current && current >= 48 && current <= 57
        end
        if current == 46
          @index += 1
          raise ParseError, "Decimal inválido." if !current || current < 48 || current > 57
          @index += 1 while current && current >= 48 && current <= 57
        end
        if current == 101 || current == 69
          @index += 1
          @index += 1 if current == 43 || current == 45
          raise ParseError, "Exponente inválido." if !current || current < 48 || current > 57
          @index += 1 while current && current >= 48 && current <= 57
        end
        raw = @text[start...@index]
        return (raw.include?(".") || raw.include?("e") || raw.include?("E")) ? raw.to_f : raw.to_i
      end

      def consume_literal(literal)
        if @text[@index, literal.length] != literal
          raise ParseError, "Literal JSON inválido en posición #{@index}."
        end
        @index += literal.length
      end
    end

    module_function
    def parse(text)
      return Parser.new(text).parse
    end
  end

  #---------------------------------------------------------------------------
  # Repositorio/adaptador. Tolera camelCase/PascalCase y la forma antigua donde
  # arcaneAbility estaba temporalmente dentro de species.json del sistema Áureo.
  #---------------------------------------------------------------------------
  module Repository
    @golden_data = nil
    @arcane_data = nil
    @golden_stamp = nil
    @arcane_stamp = nil
    @family_graph = nil
    @family_cache = {}
    @changedex_hidden_keys = nil
    @changedex_hidden_stamp = nil
    @changedex_species_keys = nil
    @changedex_species_stamp = nil

    module_function

    def log(message)
      text = "[Libreta] #{message}"
      if defined?(PBDebug) && PBDebug.respond_to?(:log)
        PBDebug.log(text)
      elsif defined?(echoln)
        echoln(text)
      end
    rescue
    end

    def file_stamp(path)
      return nil if !File.exist?(path)
      return [File.mtime(path).to_i, File.size(path)]
    rescue
      return nil
    end

    def load_json_file(path)
      return {} if !File.exist?(path)
      raw = File.open(path, "rb") { |f| f.read }
      parsed = ResearchNotebook::MiniJSON.parse(raw)
      return parsed
    rescue => e
      log("No se pudo leer #{path}: #{e.class}: #{e.message}")
      return {}
    end

    def golden_data
      path = ResearchNotebook::Settings::GOLDEN_SPECIES_JSON
      stamp = file_stamp(path)
      if @golden_data.nil? || @golden_stamp != stamp
        @golden_data = normalize_species_dataset(load_json_file(path))
        @golden_stamp = stamp
      end
      return @golden_data || {}
    end

    def arcane_data
      path = ResearchNotebook::Settings::ARCANE_SPECIES_JSON
      stamp = file_stamp(path)
      if @arcane_data.nil? || @arcane_stamp != stamp
        @arcane_data = normalize_species_dataset(load_json_file(path))
        @arcane_stamp = stamp
      end
      return @arcane_data || {}
    end

    def reload!
      @golden_data = nil
      @arcane_data = nil
      @golden_stamp = nil
      @arcane_stamp = nil
      @family_graph = nil
      @family_cache = {}
      @arcane_gamedata_species = nil
      @relevant_species_cache = nil
      @changedex_hidden_keys = nil
      @changedex_hidden_stamp = nil
      @changedex_species_keys = nil
      @changedex_species_stamp = nil
      golden_data
      arcane_data
    end

    def get_key(hash, *keys)
      return nil if !hash.is_a?(Hash)
      keys.each do |key|
        return hash[key] if hash.key?(key)
        skey = key.to_s
        return hash[skey] if hash.key?(skey)
        sym = skey.to_sym
        return hash[sym] if hash.key?(sym)
      end
      return nil
    end

    def normalize_species_dataset(raw)
      if raw.is_a?(Hash)
        nested = get_key(raw, "species", "Species", "pokemon", "Pokemon", "entries", "Entries")
        return nested if nested.is_a?(Hash)
        if nested.is_a?(Array)
          raw = nested
        else
          return raw
        end
      end
      if raw.is_a?(Array)
        result = {}
        raw.each do |entry|
          next if !entry.is_a?(Hash)
          species = get_key(entry, "species", "Species", "speciesId", "SpeciesID", "id", "ID")
          next if species.nil?
          result[species.to_s] = entry
        end
        return result
      end
      return {}
    end

    def species_key_candidates(species)
      id = species.respond_to?(:id) ? species.id : species
      id = id.to_sym rescue id
      raw = id.to_s
      return [id, raw, raw.upcase, raw.downcase]
    end

    def entry_for(hash, species)
      species_key_candidates(species).each do |key|
        return hash[key] if hash.is_a?(Hash) && hash.key?(key)
      end
      return nil
    end

    def golden_entry(species)
      value = entry_for(golden_data, species)
      return value.is_a?(Hash) ? value : nil
    end

    def arcane_entry(species)
      value = entry_for(arcane_data, species)
      return value if value.is_a?(Hash) || value.is_a?(String) || value.is_a?(Symbol)
      # Compatibilidad con el JSON combinado usado durante prototipos.
      legacy = golden_entry(species)
      legacy_value = get_key(legacy, "arcaneAbility", "ArcaneAbility", "arcane_ability")
      return legacy_value if legacy_value
      return nil
    end

    def normalize_species_key(value)
      return nil if value.nil?
      raw = value.respond_to?(:id) ? value.id : value
      raw = raw.to_s.strip
      return nil if raw.empty?
      parts = raw.split(",", 2)
      species = parts[0].strip
      form = parts.length > 1 ? parts[1].strip : nil
      aliases = {
        "NIDORANFE" => "NIDORANfE",
        "NIDORANF"  => "NIDORANfE",
        "NIDORANMA" => "NIDORANmA",
        "NIDORANM"  => "NIDORANmA"
      }
      species = aliases[species.upcase] || species
      return form ? "#{species},#{form}" : species
    end

    def changedex_hidden_keys
      return {} if !ResearchNotebook::Settings::USE_CHANGEDEX_HIDDEN_FORMS
      path = ResearchNotebook::Settings::CHANGEDEX_CONFIG_JSON
      stamp = file_stamp(path)
      if @changedex_hidden_keys.nil? || @changedex_hidden_stamp != stamp
        hidden = {}
        if ResearchNotebook::Settings::USE_CHANGEDEX_HIDDEN_FORMS && File.exist?(path)
          doc = load_json_file(path)
          Array(get_key(doc, "hiddenForms", "HiddenForms")).each do |entry|
            key = normalize_species_key(entry)
            hidden[key.upcase] = true if key
          end
        end
        @changedex_hidden_keys = hidden
        @changedex_hidden_stamp = stamp
      end
      return @changedex_hidden_keys || {}
    end

    # Devuelve true si la forma dada es de tipo "especial" (Mega, Gigamax, etc.)
    def special_form_type(species, form)
      return nil if form.to_i == 0
      return nil if !defined?(GameData::Species)
      begin
        data = GameData::Species.get_species_form(species, form)
        if data && data.respond_to?(:form_name) && !data.form_name.to_s.empty?
          fname = data.form_name.to_s.downcase
          # Detectar tipos de forma especial por palabras clave en el nombre
          return :MEGA if fname.include?("mega")
          return :GIGANTAMAX if fname.include?("gigantamax") || fname.include?("gmax")
          return :PRIMAL if fname.include?("primal")
          return :ULTRA_BURST if fname.include?("ultra burst") || fname.include?("ultraburst")
          return :ETERNAMAX if fname.include?("eternamax")
          return :ORIGIN if fname.include?("origin")
          return :ZEN if fname.include?("zen")
          return :COMPLETE if fname.include?("complete")
          return :CROWNED if fname.include?("crowned")
          return :HERO if fname.include?("hero")
          return :ETERNAL if fname.include?("eternal")
          return :DAWN if fname.include?("dawn") || fname.include?("dusk")
          return :SCHOOL if fname.include?("school")
          return :SHIELDED if fname.include?("shielded") || fname.include?("blade")
          # Fallback: usar el nombre completo como símbolo
          return fname.gsub(/[^a-z0-9_]/, "_").to_sym
        end
      rescue
      end
      return nil
    end

    def is_golden_special_form?(species, form)
      return false if form.to_i == 0
      type = special_form_type(species, form)
      return false if !type
      Array(ResearchNotebook::Settings::GOLDEN_SPECIAL_FORM_TYPES).include?(type)
    end

    def is_form_one_readonly?(species, form)
      return false if !ResearchNotebook::Settings::FORM_ONE_READONLY
      return form.to_i == 1
    end

    def changedex_species_keys
      path = ResearchNotebook::Settings::CHANGEDEX_CHANGES_JSON
      stamp = file_stamp(path)
      if @changedex_species_keys.nil? || @changedex_species_stamp != stamp
        keys = {}
        if File.exist?(path)
          doc = load_json_file(path)
          species = get_key(doc, "species", "Species")
          if species.is_a?(Hash)
            species.keys.each do |key|
              normalized = normalize_species_key(key)
              keys[normalized.upcase] = true if normalized
            end
          end
        end
        @changedex_species_keys = keys
        @changedex_species_stamp = stamp
      end
      return @changedex_species_keys || {}
    end

    def changedex_hidden?(raw_key)
      return false if !ResearchNotebook::Settings::USE_CHANGEDEX_HIDDEN_FORMS
      key = normalize_species_key(raw_key)
      return false if !key
      visible = Array(ResearchNotebook::Settings::CHANGEDEX_VISIBLE_FORMS).map do |entry|
        normalized = normalize_species_key(entry)
        normalized.upcase if normalized
      end.compact
      return false if visible.include?(key.upcase)

      # La Libreta agrupa sus entradas por especie base. Por tanto, si ChangeDex
      # oculta cualquier forma de esa especie (Mega, Gigamax, etc.), no debe
      # aparecer la entrada especial agrupada de la Libreta. Una excepción de
      # Settings para cualquier forma de esa especie la deja visible.
      species_key = key.split(",", 2)[0].upcase
      return false if visible.any? { |entry| entry == species_key || entry.start_with?(species_key + ",") }
      return changedex_hidden_keys.key?(key.upcase) ||
             changedex_hidden_keys.key?(species_key) ||
             changedex_hidden_keys.keys.any? { |entry| entry.start_with?(species_key + ",") }
    end

    def changedex_has_entry?(raw_key)
      key = normalize_species_key(raw_key)
      return false if !key
      return changedex_species_keys.key?(key.upcase)
    end

    def notebook_entry_visible?(raw_key)
      return false if changedex_hidden?(raw_key)
      return true
    end

    # Normaliza IDs provenientes de JSON/PBS sin llamar a try_get con valores
    # que Essentials no conoce. Algunos proyectos escriben NIDORANFE/NIDORANMA
    # y otros escriben NINETALES,1 para especie + forma.
    # Devuelve el nombre de forma legible (ej: "Hisuian Form", "Alolan Form", "Mega Form")
    def form_display_name(species, form)
      return "" if form.to_i == 0
      return nil if !defined?(GameData::Species)
      begin
        data = GameData::Species.get_species_form(species, form)
        return data.form_name.to_s if data && data.respond_to?(:form_name) && !data.form_name.to_s.empty?
      rescue
      end
      return nil
    end

    # Devuelve el nombre completo con forma (ej: "Zorua (Hisuian Form)")
    def species_form_display_name(species, form)
      base_name = species_name(species)
      fname = form_display_name(species, form)
      return base_name if !fname || fname.empty?
      return "#{base_name} (#{fname})"
    end

    def normalize_species_id(value)
      return nil if value.nil?
      raw = value.respond_to?(:id) ? value.id : value
      raw = raw.to_s.strip
      return nil if raw.empty?
      raw = raw.split(",", 2)[0].strip
      aliases = {
        "NIDORANFE" => "NIDORANfE",
        "NIDORANF"  => "NIDORANfE",
        "NIDORANMA" => "NIDORANmA",
        "NIDORANM"  => "NIDORANmA"
      }
      candidates = [aliases[raw.upcase] || raw, raw.upcase, raw.downcase]
      candidates = candidates.compact.map { |candidate| candidate.to_sym rescue nil }.compact.uniq
      return candidates.first if !defined?(GameData::Species)

      # DATA es la tabla canónica y permite comprobar existencia sin generar
      # el log de Unknown ID que produce try_get en ciertas versiones.
      known = nil
      begin
        table = GameData::Species.const_get(:DATA) if GameData::Species.const_defined?(:DATA)
        if table.is_a?(Hash)
          known = candidates.find { |candidate| table.key?(candidate) }
        end
      rescue
        known = nil
      end
      if known
        begin
          data = GameData::Species.get(known)
          return data.species if data && data.respond_to?(:species)
          return data.id if data && data.respond_to?(:id)
        rescue
        end
        return known
      end

      # Fallback para implementaciones que no exponen DATA: solo intenta los
      # candidatos después de filtrar los alias/formats problemáticos.
      candidates.each do |candidate|
        begin
          data = GameData::Species.try_get(candidate)
          return data.species if data && data.respond_to?(:species)
          return data.id if data && data.respond_to?(:id)
        rescue
        end
      end
      return nil
    end

    def species_ids_from(hash)
      return [] if !hash.is_a?(Hash)
      ret = []
      hash.keys.each do |key|
        next if !notebook_entry_visible?(key)
        id = normalize_species_id(key)
        ret << id if id
      end
      return ret
    end

    def arcane_species_from_gamedata
      return @arcane_gamedata_species if @arcane_gamedata_species
      ret = []
      if defined?(GameData::Species)
        begin
          GameData::Species.each do |data|
            next if data.respond_to?(:form) && data.form.to_i != 0
            next if !data.respond_to?(:arcane_ability)
            ability = data.arcane_ability rescue nil
            next if ability.nil? || ability == ""
            id = normalize_species_id(data.respond_to?(:species) ? data.species : data.id)
            ret << id if id
          end
        rescue => e
          log("Lectura de ArcaneAbility desde GameData::Species: #{e.message}")
        end
      end
      @arcane_gamedata_species = ret.compact.uniq
      return @arcane_gamedata_species
    end

    def relevant_species
      return @relevant_species_cache if @relevant_species_cache
      golden_ids = species_ids_from(golden_data)
      ids = golden_ids + species_ids_from(arcane_data) + arcane_species_from_gamedata
      # Incluye entradas Arcana heredadas del JSON Áureo.
      golden_ids.each do |species|
        ids << species if arcane_entry(species)
      end
      @relevant_species_cache = ids.compact.uniq
      return @relevant_species_cache
    end

    # Recopila todas las entradas (base + formas) para la sección Áureo.
    # Devuelve array de strings: "ESPECIE" para base, "ESPECIE,FORMA" para formas.
    def golden_entries_with_forms
      return @golden_entries_cache if @golden_entries_cache
      entries = []
      
      # Especies base desde JSON
      base_species = species_ids_from(golden_data)
      entries.concat(base_species)
      
      # Progreso trackeado - filtrar por ChangeDex
      ResearchNotebook.progress.tracked_golden_species.each do |sp|
        entries << sp unless changedex_hidden?(sp)
      end
      
      # Formas especiales (Megas, Gigamax, etc.) si está habilitado
      if ResearchNotebook::Settings::INCLUDE_SPECIAL_FORMS_IN_GOLDEN
        if defined?(GameData::Species)
          begin
            special_forms = golden_special_forms_from_gamedata
            special_forms.each do |entry|
              next if changedex_hidden?(entry)
              entries << entry unless entries.include?(entry)
            end
          rescue => e
            log("Formas especiales Áureo: #{e.message}")
          end
        end
      end
      
      # Forma 1 (Pikachu, Cubone, etc.) - ahora editable vía ChangeDex
      if ResearchNotebook::Settings::INCLUDE_FORM_ONE_IN_GOLDEN
        form_one = form_one_forms_from_gamedata
        form_one.each do |entry|
          next if changedex_hidden?(entry)
          entries << entry unless entries.include?(entry)
        end
      end
      
      @golden_entries_cache = entries.compact.uniq
      return @golden_entries_cache
    end

    # Recopila todas las entradas (base + formas) para la sección Habilidades Arcanas.
    def arcane_entries_with_forms
      return @arcane_entries_cache if @arcane_entries_cache
      entries = []
      
      # Especies base desde JSON
      base_species = species_ids_from(arcane_data)
      entries.concat(base_species)
      
      # Especies desde GameData
      entries.concat(arcane_species_from_gamedata)
      
      # Progreso trackeado - filtrar por ChangeDex
      ResearchNotebook.progress.tracked_arcane_species.each do |sp|
        entries << sp unless changedex_hidden?(sp)
      end
      
      # Formas alternas si está habilitado
      if ResearchNotebook::Settings::INCLUDE_ALTERNATE_FORMS_IN_ARCANE
        if defined?(GameData::Species)
          begin
            alt_forms = arcane_alternate_forms_from_gamedata
            alt_forms.each do |entry|
              next if changedex_hidden?(entry)
              entries << entry unless entries.include?(entry)
            end
          rescue => e
            log("Formas alternas Arcanas: #{e.message}")
          end
        end
      end
      
      # Forma 1 - ahora editable vía ChangeDex
      if ResearchNotebook::Settings::INCLUDE_FORM_ONE_IN_ARCANE
        form_one = form_one_forms_from_gamedata
        form_one.each do |entry|
          next if changedex_hidden?(entry)
          next unless arcane_capable?(entry.split(",")[0])
          entries << entry unless entries.include?(entry)
        end
      end
      
      @arcane_entries_cache = entries.compact.uniq
      return @arcane_entries_cache
    end

    # Cache para evitar iterar GameData::Species múltiples veces
    @gamedata_species_cache = nil
    @gamedata_species_stamp = nil

    def all_gamedata_species
      if defined?(GameData::Species)
        # Usar timestamp de compilación como caché simple
        return @gamedata_species_cache if @gamedata_species_cache
        ret = []
        begin
          GameData::Species.each do |data|
            ret << data
          end
        rescue => e
          log("Error iterando GameData::Species: #{e.message}")
        end
        @gamedata_species_cache = ret
        return ret
      end
      return []
    end

    def golden_special_forms_from_gamedata
      ret = []
      all_gamedata_species.each do |data|
        next if !data.respond_to?(:form) || data.form.to_i == 0
        species = data.respond_to?(:species) ? data.species : data.id
        next if !species
        base_id = normalize_species_id(species)
        next if !base_id
        next unless is_golden_special_form?(base_id, data.form)
        ret << "#{base_id},#{data.form}"
      end
      ret.uniq
    end

    def arcane_alternate_forms_from_gamedata
      ret = []
      all_gamedata_species.each do |data|
        next if !data.respond_to?(:form) || data.form.to_i == 0
        species = data.respond_to?(:species) ? data.species : data.id
        next if !species
        base_id = normalize_species_id(species)
        next if !base_id
        next unless arcane_capable?(base_id)
        ret << "#{base_id},#{data.form}"
      end
      ret.uniq
    end

    def form_one_forms_from_gamedata
      ret = []
      all_gamedata_species.each do |data|
        next if !data.respond_to?(:form) || data.form.to_i != 1
        species = data.respond_to?(:species) ? data.species : data.id
        next if !species
        base_id = normalize_species_id(species)
        next if !base_id
        ret << "#{base_id},1"
      end
      ret.uniq
    end

    def reload!
      @golden_data = nil
      @arcane_data = nil
      @golden_stamp = nil
      @arcane_stamp = nil
      @family_graph = nil
      @family_cache = {}
      @arcane_gamedata_species = nil
      @relevant_species_cache = nil
      @changedex_hidden_keys = nil
      @changedex_hidden_stamp = nil
      @changedex_species_keys = nil
      @changedex_species_stamp = nil
      @golden_entries_cache = nil
      @arcane_entries_cache = nil
      @gamedata_species_cache = nil
      golden_data
      arcane_data
    end

    def golden_capable?(species)
      e = golden_entry(species)
      return false if !e
      keys = [
        "goldenForm", "GoldenForm", "goldenType", "GoldenType", "goldenPower", "GoldenPower",
        "goldenAbility", "GoldenFormAbility", "goldenStats", "GoldenStats", "goldenFormTypes", "GoldenFormTypes"
      ]
      return keys.any? { |k| !get_key(e, k).nil? }
    end

    def arcane_capable?(species)
      return !arcane_ability_raw(species).nil?
    end

    # `goldenForm` admite dos esquemas del proyecto:
    #   1) número/ID de forma (esquema antiguo)
    #   2) Hash con los datos de la forma, p. ej. { "types" => [...],
    #      "baseStats" => {...} }. Nunca se hace to_i sobre un Hash.
    def golden_form_value(species)
      e = golden_entry(species)
      return get_key(e, "goldenForm", "GoldenForm", "golden_form")
    end

    def golden_form_payload(species)
      value = golden_form_value(species)
      return value if value.is_a?(Hash)
      e = golden_entry(species)
      nested = get_key(e, "goldenFormData", "GoldenFormData", "golden_form_data", "formData", "FormData")
      return nested if nested.is_a?(Hash)
      return nil
    end

    def golden_form_index(species)
      value = golden_form_value(species)
      if value.is_a?(Numeric)
        return value.to_i
      elsif value.is_a?(String) || value.is_a?(Symbol)
        raw = value.to_s.strip
        return raw.to_i if raw =~ /\A-?\d+\z/
        return nil
      elsif value.is_a?(Hash)
        idx = get_key(value, "form", "Form", "formIndex", "FormIndex", "form_index", "index", "Index", "spriteForm", "SpriteForm")
        return idx.to_i if idx.is_a?(Numeric)
        return idx.to_i if idx && idx.to_s.strip =~ /\A-?\d+\z/
      end
      return nil
    end

    # Compatibilidad con llamadas de versiones anteriores de la Libreta.
    def golden_form(species)
      return golden_form_index(species)
    end

    # Ruta opcional de un gráfico específico para la forma áurea.
    # Se acepta una ruta completa o un nombre relativo a Settings::GOLDEN_FORM_SPRITE_ROOT.
    def golden_form_sprite_raw(species)
      e = golden_entry(species)
      value = get_key(e, "goldenFormSprite", "GoldenFormSprite",
        "goldenFormGraphic", "GoldenFormGraphic", "golden_form_sprite",
        "golden_form_graphic")
      payload = golden_form_payload(species)
      value = get_key(payload, "sprite", "Sprite", "graphic", "Graphic",
        "spritePath", "SpritePath") if value.nil? && payload.is_a?(Hash)
      return value.to_s if value && value.to_s.strip != ""
      return nil
    end

    def golden_form_sprite_path(species)
      raw = golden_form_sprite_raw(species)
      return nil if !raw
      path = raw.to_s.gsub('\\', '/')
      return path if path.start_with?("Graphics/")
      root = ResearchNotebook::Settings::GOLDEN_FORM_SPRITE_ROOT.to_s
      path = "#{root}/#{path}" if !path.start_with?(root)
      return path
    end

    def golden_form_configured?(species)
      value = golden_form_value(species)
      return false if value.nil? || value == ""
      return true
    end

    def golden_type_raw(species)
      e = golden_entry(species)
      return get_key(e, "goldenType", "GoldenType", "golden_type")
    end

    def golden_type(species)
      return resolve_type(golden_type_raw(species))
    end

    def golden_type_replace(species)
      e = golden_entry(species)
      return get_key(e, "goldenTypeReplace", "GoldenTypeReplace", "golden_type_replace")
    end

    def golden_form_types_raw(species)
      e = golden_entry(species)
      explicit = get_key(e, "goldenFormTypes", "GoldenFormTypes", "golden_form_types", "goldenTypes", "GoldenTypes")
      return explicit if !explicit.nil?
      payload = golden_form_payload(species)
      return get_key(payload, "types", "Types", "goldenTypes", "GoldenTypes", "formTypes", "FormTypes")
    end

    def golden_form_types(species)
      explicit = golden_form_types_raw(species)
      if explicit
        values = explicit.is_a?(Array) ? explicit : explicit.to_s.split(/[\s,;\/]+/)
        types = values.map { |v| resolve_type(v) }.compact
        return types if !types.empty?
      end
      form = golden_form(species)
      if !form.nil? && defined?(GameData::Species)
        begin
          data = GameData::Species.get_species_form(species, form)
          return data.types if data && data.respond_to?(:types)
        rescue
        end
      end
      return []
    end

    def golden_ability_raw(species)
      e = golden_entry(species)
      explicit = get_key(e, "goldenAbility", "GoldenAbility", "GoldenFormAbility", "goldenFormAbility", "golden_form_ability")
      return explicit if !explicit.nil?
      payload = golden_form_payload(species)
      return get_key(payload, "ability", "Ability", "abilityId", "AbilityID", "goldenAbility", "GoldenAbility")
    end

    def golden_ability(species)
      return resolve_ability(golden_ability_raw(species))
    end

    def golden_stats(species)
      e = golden_entry(species)
      raw = get_key(e, "goldenStats", "GoldenStats", "golden_stats")
      if raw.nil?
        payload = golden_form_payload(species)
        raw = get_key(payload, "baseStats", "BaseStats", "stats", "Stats", "goldenStats", "GoldenStats")
      end
      # Compatibilidad: algunos esquemas antiguos guardaban BaseStats arriba.
      raw = get_key(e, "baseStats", "BaseStats") if raw.nil?
      return nil if raw.nil?
      if raw.is_a?(Array)
        keys = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
        ret = {}
        keys.each_with_index { |k, i| ret[k] = raw[i].to_i if !raw[i].nil? }
        return ret
      end
      return nil if !raw.is_a?(Hash)
      aliases = {
        :HP => ["HP", "hp"],
        :ATTACK => ["ATTACK", "Attack", "attack", "ATK", "Atk"],
        :DEFENSE => ["DEFENSE", "Defense", "defense", "DEF", "Def"],
        :SPECIAL_ATTACK => ["SPECIAL_ATTACK", "SpecialAttack", "specialAttack", "SPATK", "SpAtk", "SPECIALATTACK"],
        :SPECIAL_DEFENSE => ["SPECIAL_DEFENSE", "SpecialDefense", "specialDefense", "SPDEF", "SpDef", "SPECIALDEFENSE"],
        :SPEED => ["SPEED", "Speed", "speed", "SPE", "Spe"]
      }
      ret = {}
      aliases.each do |stat, names|
        value = get_key(raw, *names)
        ret[stat] = value.to_i if !value.nil?
      end
      return ret.empty? ? nil : ret
    end

    def golden_hp_drain(species)
      e = golden_entry(species)
      value = get_key(e, "goldenFormHPDrain", "GoldenFormHPDrain", "goldenHPDrain", "hpDrain")
      return value if !value.nil?
      payload = golden_form_payload(species)
      return get_key(payload, "hpDrain", "HPDrain", "goldenHPDrain", "GoldenHPDrain")
    end

    # Devuelve el texto del drenaje de HP de la Forma Dorada formateado (ej: 0.25 -> "1/4")
    def golden_form_drain_text
      return "Pierde 1/4 de sus PS máximos al final de cada turno." if !defined?(GoldenSystem) || !GoldenSystem.respond_to?(:settings)
      drain = GoldenSystem.settings[:form_hp_drain] rescue 0.25
      # Convertir decimal a fracción legible
      fraction = case drain
      when 0.25 then "1/4"
      when 0.33, 0.333 then "1/3"
      when 0.5 then "1/2"
      when 0.66, 0.666 then "2/3"
      when 0.75 then "3/4"
      else drain.to_s
      end
      return _INTL("Pierde {1} de sus PS máximos al final de cada turno.", fraction)
    end

    def golden_power_raw(species)
      e = golden_entry(species)
      return get_key(e, "goldenPower", "GoldenPower", "golden_power")
    end

    def golden_power_name(species)
      raw = golden_power_raw(species)
      return nil if raw.nil?
      if raw.is_a?(Hash)
        return get_key(raw, "name", "Name", "displayName", "DisplayName", "id", "ID")
      end
      return raw.to_s
    end

    def golden_power_description(species)
      raw = golden_power_raw(species)
      return nil if raw.nil?
      if raw.is_a?(Hash)
        return get_key(raw, "description", "Description", "desc", "Desc", "text", "Text")
      end
      return nil
    end

    def arcane_ability_raw(species)
      # Fuente principal del sistema actual: PBS/GameData::Species
      #   ArcaneAbility = XXXXX  -> species_data.arcane_ability
      if defined?(GameData::Species)
        begin
          data = GameData::Species.try_get(species)
          if data && data.respond_to?(:arcane_ability)
            value = data.arcane_ability
            return value if !value.nil? && value != ""
          end
        rescue
        end
      end
      # Compatibilidad con el JSON de Arcane Ability Studio/prototipos.
      raw = arcane_entry(species)
      return raw if raw.is_a?(String) || raw.is_a?(Symbol)
      return nil if !raw.is_a?(Hash)
      value = get_key(raw,
        "arcaneAbility", "ArcaneAbility", "arcane_ability",
        "ability", "Ability", "abilityId", "AbilityID", "ability_id")
      if value.is_a?(Hash)
        value = get_key(value, "ability", "Ability", "abilityId", "AbilityID", "id", "ID", "name", "Name")
      end
      return value if !value.nil?
      nested = get_key(raw, "arcane", "Arcane", "arcaneData", "ArcaneData", "data", "Data")
      if nested.is_a?(Hash)
        return get_key(nested, "ability", "Ability", "abilityId", "AbilityID", "id", "ID", "arcaneAbility", "ArcaneAbility")
      end
      # Solo usa un `id` genérico como último recurso si resuelve a una Ability real.
      generic = get_key(raw, "id", "ID")
      if generic && defined?(GameData::Ability)
        begin
          return generic if GameData::Ability.try_get(generic.to_s.upcase.to_sym)
        rescue
        end
      end
      return nil
    end

    def arcane_ability(species)
      return resolve_ability(arcane_ability_raw(species))
    end

    # Devuelve la familia evolutiva de una especie. Se usa únicamente para
    # compartir una Habilidad Arcana cuando el ID es exactamente el mismo.
    # El grafo fallback se construye una vez y luego queda cacheado.
    def build_family_graph
      return @family_graph if @family_graph
      graph = Hash.new { |h, k| h[k] = [] }
      if defined?(GameData::Species)
        begin
          GameData::Species.each do |data|
            next if data.respond_to?(:form) && data.form.to_i != 0
            from = normalize_species_id(data.respond_to?(:species) ? data.species : data.id)
            next if !from
            evolutions = []
            begin
              evolutions = data.get_evolutions(true) if data.respond_to?(:get_evolutions)
            rescue
              begin
                evolutions = data.get_evolutions if data.respond_to?(:get_evolutions)
              rescue
                evolutions = []
              end
            end
            Array(evolutions).each do |evo|
              target = evo.is_a?(Array) ? evo[0] : evo
              target = normalize_species_id(target)
              next if !target || target == from
              graph[from] << target if !graph[from].include?(target)
              graph[target] << from if !graph[target].include?(from)
            end
          end
        rescue => e
          log("Familias evolutivas: #{e.message}")
        end
      end
      @family_graph = graph
      return @family_graph
    end

    def evolution_family(species)
      id = normalize_species_id(species)
      return [] if !id
      @family_cache ||= {}
      return @family_cache[id] if @family_cache[id]

      # Essentials expone get_family_species en varias versiones. Se prefiere
      # cuando existe porque respeta ramificaciones sin reconstruirlas.
      if defined?(GameData::Species)
        begin
          data = GameData::Species.try_get(id)
          if data && data.respond_to?(:get_family_species)
            family = Array(data.get_family_species).map { |sp| normalize_species_id(sp) }.compact.uniq
            if !family.empty?
              family.each { |sp| @family_cache[sp] = family }
              return family
            end
          end
        rescue
        end
      end

      graph = build_family_graph
      family = []
      queue = [id]
      visited = {}
      until queue.empty?
        current = queue.shift
        next if visited[current]
        visited[current] = true
        family << current
        Array(graph[current]).each { |other| queue << other if !visited[other] }
      end
      family = [id] if family.empty?
      family.each { |sp| @family_cache[sp] = family }
      return family
    end

    def same_arcane_family_species(species, ability = nil)
      resolved = resolve_ability(ability || arcane_ability(species))
      return [] if !resolved
      return evolution_family(species).select do |relative|
        arcane_ability(relative) == resolved
      end
    end

    def resolve_ability(value)
      return nil if value.nil? || value == ""
      return value.id if value.respond_to?(:id)
      raw = value.to_s
      candidates = [raw, raw.upcase, raw.upcase.gsub(/[^A-Z0-9_]/, "")]
      if defined?(GameData::Ability)
        candidates.each do |candidate|
          begin
            data = GameData::Ability.try_get(candidate.to_sym)
            return data.id if data
          rescue
          end
        end
        begin
          GameData::Ability.each do |ability|
            next if !ability.respond_to?(:name)
            return ability.id if ability.name.to_s.downcase == raw.downcase
          end
        rescue
        end
      end
      return candidates.last.to_sym rescue nil
    end

    def resolve_type(value)
      return nil if value.nil? || value == ""
      return value.id if value.respond_to?(:id)
      raw = value.to_s
      candidates = [raw, raw.upcase, raw.upcase.gsub(/[^A-Z0-9_]/, "")]
      if defined?(GameData::Type)
        candidates.each do |candidate|
          begin
            data = GameData::Type.try_get(candidate.to_sym)
            return data.id if data
          rescue
          end
        end
        begin
          GameData::Type.each do |type|
            next if !type.respond_to?(:name)
            return type.id if type.name.to_s.downcase == raw.downcase
          end
        rescue
        end
      end
      return candidates.last.to_sym rescue nil
    end

    def ability_name(id)
      return "???" if !id
      begin
        data = GameData::Ability.try_get(id)
        return data.name if data
      rescue
      end
      return id.to_s
    end

    def ability_description(id)
      return "" if !id
      begin
        data = GameData::Ability.try_get(id)
        return data.description.to_s if data && data.respond_to?(:description)
      rescue
      end
      return ""
    end

    def type_name(id)
      return "???" if !id
      begin
        data = GameData::Type.try_get(id)
        return data.name if data
      rescue
      end
      return id.to_s
    end

    def species_name(species)
      # Acepta "ESPECIE" o "ESPECIE,FORMA"
      if species.is_a?(String) && species.include?(",")
        base, form_str = species.split(",", 2)
        form = form_str.to_i
        begin
          data = GameData::Species.get_species_form(base.to_sym, form)
          return data.name if data
        rescue
        end
        # Fallback: nombre base + nombre de forma
        base_data = GameData::Species.try_get(base.to_sym)
        form_name = ""
        begin
          form_data = GameData::Species.get_species_form(base.to_sym, form)
          form_name = form_data.form_name.to_s if form_data && form_data.respond_to?(:form_name)
        rescue
        end
        return base_data ? "#{base_data.name} (#{form_name})" : species.to_s
      end
      begin
        data = GameData::Species.try_get(species)
        return data.name if data
      rescue
      end
      return species.to_s
    end

    def species_base_and_form(species)
      # Devuelve [base_species, form] desde "ESPECIE" o "ESPECIE,FORMA"
      if species.is_a?(String) && species.include?(",")
        base, form_str = species.split(",", 2)
        return [base.to_sym, form_str.to_i]
      end
      return [species, 0]
    end

    def form_name(species, form)
      return "" if form.to_i == 0
      begin
        data = GameData::Species.get_species_form(species, form)
        return data.form_name.to_s if data && data.respond_to?(:form_name)
      rescue
      end
      return ""
    end

    def normal_types(species, form = 0)
      begin
        data = species_data(species, form)
        return data.types if data && data.respond_to?(:types)
      rescue
      end
      return []
    end

    #-------------------------------------------------------------------------
    # Datos generales usados para que el Registro sea una libreta de campo real
    # y no solo un visor de las dos mecánicas especiales.
    #-------------------------------------------------------------------------
    def species_data(species, form = 0)
      return nil if !defined?(GameData::Species)
      begin
        return GameData::Species.get_species_form(species, form) if form.to_i != 0
      rescue
      end
      begin
        return GameData::Species.try_get(species)
      rescue
      end
      return nil
    end

    def all_base_species
      ret = []
      return ret if !defined?(GameData::Species)
      begin
        GameData::Species.each do |data|
          next if data.respond_to?(:form) && data.form.to_i != 0
          id = normalize_species_id(data.respond_to?(:species) ? data.species : data.id)
          ret << id if id
        end
      rescue => e
        log("No se pudo construir el registro general: #{e.message}")
      end
      return ret.compact.uniq
    end

    def species_category(species)
      data = species_data(species)
      return "" if !data
      begin
        return data.category.to_s if data.respond_to?(:category)
      rescue
      end
      return ""
    end

    def species_pokedex_entry(species)
      data = species_data(species)
      return "" if !data
      begin
        return data.pokedex_entry.to_s if data.respond_to?(:pokedex_entry)
      rescue
      end
      begin
        return data.pokedex.to_s if data.respond_to?(:pokedex)
      rescue
      end
      return ""
    end

    def species_height(species)
      data = species_data(species)
      return nil if !data
      begin
        return data.height.to_f / 10.0 if data.respond_to?(:height)
      rescue
      end
      return nil
    end

    def species_weight(species)
      data = species_data(species)
      return nil if !data
      begin
        return data.weight.to_f / 10.0 if data.respond_to?(:weight)
      rescue
      end
      return nil
    end

    def base_stats(species, form = 0)
      data = species_data(species, form)
      return nil if !data || !data.respond_to?(:base_stats)
      raw = data.base_stats rescue nil
      return nil if !raw
      keys = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
      if raw.is_a?(Array)
        ret = {}
        keys.each_with_index { |k, i| ret[k] = raw[i].to_i if !raw[i].nil? }
        return ret
      end
      if raw.respond_to?(:[])
        ret = {}
        keys.each do |key|
          value = nil
          begin; value = raw[key]; rescue; end
          if value.nil?
            begin; value = raw[key.to_s]; rescue; end
          end
          ret[key] = value.to_i if !value.nil?
        end
        return ret.empty? ? nil : ret
      end
      return nil
    end

    def item_name(id)
      return id.to_s if !id
      begin
        data = GameData::Item.try_get(id)
        return data.name.to_s if data
      rescue
      end
      return id.to_s
    end

    def item_description(id)
      return "" if !id
      begin
        data = GameData::Item.try_get(id)
        return data.description.to_s if data && data.respond_to?(:description)
      rescue
      end
      return ""
    end
  end
end
