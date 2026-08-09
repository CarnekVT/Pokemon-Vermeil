#===============================================================================
# Records which file, section and line are currently being read
#===============================================================================
module FileLineData
  @file     = ""
  @linedata = ""
  @lineno   = 0
  @section  = nil
  @key      = nil
  @value    = nil

  def self.file; return @file; end
  def self.file=(value); @file = value; end

  def self.clear
    @file     = ""
    @linedata = ""
    @lineno   = ""
    @section  = nil
    @key      = nil
    @value    = nil
  end

  def self.setSection(section, key, value)
    @section = section
    @key     = key
    if value && value.length > 200
      @value = value[0, 200].to_s + "..."
    else
      @value = (value) ? value.clone : ""
    end
  end

  def self.setLine(line, lineno)
    @section  = nil
    @linedata = (line && line.length > 200) ? sprintf("%s...", line[0, 200]) : line.clone
    @lineno   = lineno
  end

  def self.linereport
    if @section
      if @key.nil?
        return _INTL("Archivo {1}, sección {2}\n{3}", @file, @section, @value) + "\n\n"
      else
        return _INTL("Archivo {1}, sección {2}, clave {3}\n{4}", @file, @section, @key, @value) + "\n\n"
      end
    else
      return _INTL("Archivo {1}, línea {2}\n{3}", @file, @lineno, @linedata) + "\n\n"
    end
  end
end

#===============================================================================
# Compiler
#===============================================================================
module Compiler
  module_function

  def findIndex(a)
    index = -1
    count = 0
    a.each do |i|
      if yield i
        index = count
        break
      end
      count += 1
    end
    return index
  end

  def prepline(line)
    line.sub!(/\s*\#.*$/, "")
    line.sub!(/^\s+/, "")
    line.sub!(/\s+$/, "")
    return line
  end

  def csvQuote(str, always = false)
    return "" if nil_or_empty?(str)
    if always || str[/[,\"]/]   # || str[/^\s/] || str[/\s$/] || str[/^#/]
      str = str.gsub(/\"/, "\\\"")
      str = "\"#{str}\""
    end
    return str
  end

  def csvQuoteAlways(str)
    return csvQuote(str, true)
  end

  #=============================================================================
  # PBS file readers
  #=============================================================================
  def pbEachFileSectionEx(f, schema = nil)
    if File.extname(f.path).downcase == ".json"
      pbEachJSONFileSection(f, schema) { |section, name| yield section, name }
      return
    end
    lineno      = 1
    havesection = false
    sectionname = nil
    lastsection = {}
    f.each_line do |line|
      if lineno == 1 && line[0].ord == 0xEF && line[1].ord == 0xBB && line[2].ord == 0xBF
        line = line[3, line.length - 3]
      end
      line.force_encoding(Encoding::UTF_8)
      if !line[/^\#/] && !line[/^\s*$/]
        line = prepline(line)
        if line[/^\s*\[\s*(.*)\s*\]\s*$/]   # Of the format: [something]
          yield lastsection, sectionname if havesection
          sectionname = $~[1]
          havesection = true
          lastsection = {}
        else
          if sectionname.nil?
            FileLineData.setLine(line, lineno)
            raise _INTL("Se esperaba una sección al principio del archivo. Este error también puede ocurrir si el archivo no se guardó en UTF-8.\n{1}", FileLineData.linereport)
          end
          if !line[/^\s*(\w+)\s*=\s*(.*)$/]
            FileLineData.setSection(sectionname, nil, line)
            raise _INTL("Sintaxis de línea incorrecta (se esperaba una sintaxis como XXX=YYY)\n{1}", FileLineData.linereport)
          end
          r1 = $~[1]
          r2 = $~[2]
          if schema && schema[r1] && schema[r1][1][0] == "^"
            lastsection[r1] ||= []
            lastsection[r1].push(r2.gsub(/\s+$/, ""))
          else
            lastsection[r1] = r2.gsub(/\s+$/, "")
          end
        end
      end
      lineno += 1
      Graphics.update if lineno % 1000 == 0
    end
    yield lastsection, sectionname if havesection
  end

  #=============================================================================
  # JSON PBS support
  #
  # A .json PBS file is parsed once into native Ruby values, then every field
  # value is stringified into the same CSV-style token that get_csv_record
  # already parses from a .txt line. This means every schema-driven .txt
  # reader (pbEachFileSection/pbEachFileSectionNumbered, and therefore every
  # compile_XXX that uses them) gains .json support for free, and both
  # formats run through the exact same field coercion/validation code.
  #=============================================================================
  def pbLoadJSONFile(filename)
    json_text = File.open(filename, "rb") { |f| f.read }
    if json_text.bytesize >= 3 && json_text.getbyte(0) == 0xEF &&
       json_text.getbyte(1) == 0xBB && json_text.getbyte(2) == 0xBF
      json_text = json_text.byteslice(3, json_text.bytesize - 3)
    end
    json_text.force_encoding(Encoding::UTF_8)
    begin
      return HTTPLite::JSON.parse(json_text)
    rescue MKXPError, StandardError => e
      raise _INTL("Error de sintaxis JSON en {1}:\n{2}", filename, e.message)
    end
  end

  def pbEachJSONFileSection(f, schema)
    data = pbLoadJSONFile(f.path)
    if !data.is_a?(Hash)
      raise _INTL("El archivo JSON {1} debe contener un objeto en la raíz (keyed por ID de sección), no un {2}.", f.path, data.class)
    end
    data.each do |section_name, fields|
      if !fields.is_a?(Hash)
        raise _INTL("La sección '{1}' en {2} debe ser un objeto JSON.\n", section_name, f.path)
      end
      contents = {}
      fields.each do |key, value|
        next if value.nil?
        fmt = (schema && schema[key]) ? schema[key][1] : nil
        raw = ["q", "Q", "^q", "^Q"].include?(fmt)
        if fmt && fmt[0] == "^"
          if !value.is_a?(Array)
            raise _INTL("El campo '{1}' de la sección '{2}' en {3} es repetible y debe ser un array JSON.", key, section_name, f.path)
          end
          contents[key] = value.map { |row| json_value_to_csv_token(row, raw: raw) }
        else
          if STAT_SEXTET_FORMATS.include?(fmt) && value.is_a?(Hash)
            contents[key] = stat_hash_to_csv_token(value, f.path, key)
          elsif ARRAY_OF_OBJECTS_FORMATS.key?(fmt) && value.is_a?(Array) && value.all? { |row| row.is_a?(Hash) } && !value.empty?
            contents[key] = array_of_objects_to_csv_token(value, ARRAY_OF_OBJECTS_FORMATS[fmt], f.path, key)
          else
            contents[key] = json_value_to_csv_token(value, raw: raw)
          end
        end
      end
      yield contents, section_name
    end
  end

  def json_value_to_csv_token(value, raw: false)
    return value.map { |v| json_scalar_to_csv_token(v, raw: raw) }.join(",") if value.is_a?(Array)
    return json_scalar_to_csv_token(value, raw: raw)
  end

  def json_scalar_to_csv_token(value, raw: false)
    return "" if value.nil?
    # JSON has no int/float distinction on the wire, so a whole number like
    # BaseStats' 90 round-trips through the parser as a Float 90.0. Render
    # whole floats without the decimal so integer-format schema fields
    # ("u"/"v"/"i"...) get "90", not "90.0" (which fails their regex).
    value = value.to_i if value.is_a?(Float) && value == value.to_i
    return value.to_s if raw
    return csvQuote(value.to_s)
  end

  # A "stat sextet" field (BaseStats, IV, EV) may be given as a JSON object
  # keyed by the real GameData::Stat id ("HP", "ATTACK", "DEFENSE",
  # "SPECIAL_ATTACK", "SPECIAL_DEFENSE", "SPEED") instead of a positional
  # array, since the PBS on-disk order (Speed is 4th, not last) is easy to
  # get wrong by hand. All 6 keys are required — no silent defaulting.
  STAT_SEXTET_FORMATS = ["vvvvvv", "uUUUUU"].freeze

  # A "*"-repeated multi-field value (Species/pokemon_forms level-up Moves,
  # Evolutions) may be given as an array of named objects instead of one
  # fully-flattened array, since remembering "which position is which field"
  # across N repetitions is error-prone. All keys per object are required.
  ARRAY_OF_OBJECTS_FORMATS = {
    "*ie"  => ["level", "move"],
    "*ees" => ["species", "method", "parameter"],
    "*ses" => ["species", "method", "parameter"]
  }.freeze

  def array_of_objects_to_csv_token(value, keys, filename, field_label)
    tokens = value.flat_map do |row|
      if !row.is_a?(Hash)
        raise _INTL("Cada elemento de '{1}' en {2} debe ser un objeto JSON con las claves {3}.", field_label, filename, keys.join(", "))
      end
      missing = keys.reject { |k| row.key?(k) }
      if !missing.empty?
        raise _INTL("A un elemento de '{1}' en {2} le falta la clave '{3}'.", field_label, filename, missing.first)
      end
      keys.map { |k| json_scalar_to_csv_token(row[k]) }
    end
    return tokens.join(",")
  end

  def stat_hash_to_csv_token(value, filename, field_label)
    ordered = []
    GameData::Stat.each_main do |s|
      next if s.pbs_order < 0
      key = s.id.to_s
      if !value.key?(key)
        raise _INTL("Al campo de stats '{1}' en {2} le falta la clave '{3}'.", field_label, filename, key)
      end
      ordered[s.pbs_order] = value[key]
    end
    return ordered.map { |v| json_scalar_to_csv_token(v) }.join(",")
  end

  # Used for types.txt, abilities.txt, moves.txt, items.txt, berry_plants.txt,
  # pokemon.txt, pokemon_forms.txt, pokemon_metrics.txt, shadow_pokemon.txt,
  # ribbons.txt, trainer_types.txt, battle_facility_lists.txt, Battle Tower
  # trainers PBS files and dungeon_parameters.txt
  def pbEachFileSection(f, schema = nil)
    pbEachFileSectionEx(f, schema) do |section, name|
      yield section, name if block_given? && name[/^.+$/]
    end
  end

  # Used for metadata.txt and map_metadata.txt
  def pbEachFileSectionNumbered(f, schema = nil)
    pbEachFileSectionEx(f, schema) do |section, name|
      yield section, name.to_i if block_given? && name[/^\d+$/]
    end
  end

  # Used by translated text compiler
  def pbEachSection(f)
    lineno      = 1
    havesection = false
    sectionname = nil
    lastsection = []
    f.each_line do |line|
      if lineno == 1 && line[0].ord == 0xEF && line[1].ord == 0xBB && line[2].ord == 0xBF
        line = line[3, line.length - 3]
      end
      line.force_encoding(Encoding::UTF_8)
      if !line[/^\#/] && !line[/^\s*$/]
        if line[/^\s*\[\s*(.+?)\s*\]\s*$/]
          yield lastsection, sectionname if havesection
          lastsection.clear
          sectionname = $~[1]
          havesection = true
        else
          if sectionname.nil?
            raise _INTL("Se esperaba una sección al principio del archivo (línea {1}). Las secciones comienzan con '[nombre de la sección]'.", lineno)
          end
          lastsection.push(line.strip)
        end
      end
      lineno += 1
      Graphics.update if lineno % 500 == 0
    end
    yield lastsection, sectionname if havesection
  end

  # Unused
  def pbEachCommentedLine(f)
    lineno = 1
    f.each_line do |line|
      if lineno == 1 && line[0].ord == 0xEF && line[1].ord == 0xBB && line[2].ord == 0xBF
        line = line[3, line.length - 3]
      end
      line.force_encoding(Encoding::UTF_8)
      yield line, lineno if !line[/^\#/] && !line[/^\s*$/]
      lineno += 1
    end
  end

  # Used for town_map.txt and Battle Tower Pokémon PBS files
  def pbCompilerEachCommentedLine(filename)
    if File.extname(filename).downcase == ".json"
      FileLineData.file = filename
      lines = json_lines_for_battle_tower_pokemon(filename)
      lines.each_with_index do |line, i|
        FileLineData.setLine(line, i + 1)
        yield line, i + 1
      end
      return
    end
    File.open(filename, "rb") do |f|
      FileLineData.file = filename
      lineno = 1
      f.each_line do |line|
        if lineno == 1 && line[0].ord == 0xEF && line[1].ord == 0xBB && line[2].ord == 0xBF
          line = line[3, line.length - 3]
        end
        line.force_encoding(Encoding::UTF_8)
        if !line[/^\#/] && !line[/^\s*$/]
          FileLineData.setLine(line, lineno)
          yield line, lineno
        end
        lineno += 1
      end
    end
  end

  # Converts battle_tower_pokemon.json into the same
  # "Species;Item;Nature;EV1,EV2;Move1,Move2,Move3,Move4" lines that
  # PBPokemon.fromInspected already parses (see 054_Battle Frontier/003).
  def json_lines_for_battle_tower_pokemon(filename)
    data = pbLoadJSONFile(filename)
    if !data.is_a?(Array)
      raise _INTL("El archivo {1} debe contener un array JSON de Pokémon.", filename)
    end
    return data.map do |pkmn|
      if !pkmn.is_a?(Hash) || !pkmn["species"]
        raise _INTL("Cada Pokémon en {1} necesita al menos 'species'.", filename)
      end
      ev_list = Array(pkmn["ev"]).join(",")
      moves_list = Array(pkmn["moves"]).join(",")
      [pkmn["species"], pkmn["item"], pkmn["nature"], ev_list, moves_list].map { |v| v.to_s }.join(";")
    end
  end

  # Unused
  def pbEachPreppedLine(f)
    lineno = 1
    f.each_line do |line|
      if lineno == 1 && line[0].ord == 0xEF && line[1].ord == 0xBB && line[2].ord == 0xBF
        line = line[3, line.length - 3]
      end
      line.force_encoding(Encoding::UTF_8)
      line = prepline(line)
      yield line, lineno if !line[/^\#/] && !line[/^\s*$/]
      lineno += 1
    end
  end

  # Maps a PBS base filename (without extension/suffix) to the method that
  # converts its .json contents into the same already-"prepped" line strings
  # the .txt parser below already knows how to consume line by line. Each
  # compile_XXX that reads via pbCompilerEachPreppedLine keeps its exact
  # existing per-line parsing/validation untouched.
  JSON_PREPPED_LINE_CONVERTERS = {
    "map_connections" => :json_lines_for_map_connections,
    "regional_dexes"  => :json_lines_for_regional_dexes,
    "encounters"      => :json_lines_for_encounters,
    "trainers"        => :json_lines_for_trainers
  }

  # Used for map_connections.txt, phone.txt, regional_dexes.txt, encounters.txt,
  # trainers.txt and dungeon_tilesets.txt
  def pbCompilerEachPreppedLine(filename)
    if File.extname(filename).downcase == ".json"
      base_name = File.basename(filename, ".json")
      converter_key = JSON_PREPPED_LINE_CONVERTERS.keys.find { |k| base_name == k || base_name.start_with?(k + "_") }
      if !converter_key
        raise _INTL("No hay soporte JSON implementado todavía para el archivo {1}.", filename)
      end
      FileLineData.file = filename
      lines = send(JSON_PREPPED_LINE_CONVERTERS[converter_key], filename)
      lines.each_with_index do |line, i|
        FileLineData.setLine(line, i + 1)
        yield line, i + 1
      end
      return
    end
    File.open(filename, "rb") do |f|
      FileLineData.file = filename
      lineno = 1
      f.each_line do |line|
        if lineno == 1 && line[0].ord == 0xEF && line[1].ord == 0xBB && line[2].ord == 0xBF
          line = line[3, line.length - 3]
        end
        line.force_encoding(Encoding::UTF_8)
        line = prepline(line)
        if !line[/^\#/] && !line[/^\s*$/]
          FileLineData.setLine(line, lineno)
          yield line, lineno
        end
        lineno += 1
      end
    end
  end

  # Cada fila es [MapID1, Lado1, Offset1, MapID2, Lado2, Offset2] — mismo orden
  # que las columnas de map_connections.txt (schema "iyiiyi" de compile_connections).
  # Ejemplo real: [41, "N", 0, 40, "S", 0].
  # También soporta objeto: {"map1":41,"side1":"N","offset1":0,"map2":40,"side2":"S","offset2":0}
  def json_lines_for_map_connections(filename)
    data = pbLoadJSONFile(filename)
    if !data.is_a?(Array)
      raise _INTL("El archivo {1} debe contener un array JSON de filas de conexión.", filename)
    end
    keys = ["map1", "side1", "offset1", "map2", "side2", "offset2"]
    return data.map do |row|
      if row.is_a?(Hash)
        missing = keys.reject { |k| row.key?(k) }
        if !missing.empty?
          raise _INTL("A una conexión en {1} le falta la clave '{2}'.", filename, missing.first)
        end
        keys.map { |k| json_scalar_to_csv_token(row[k]) }.join(",")
      elsif row.is_a?(Array)
        row.map { |v| json_scalar_to_csv_token(v) }.join(",")
      else
        raise _INTL("Cada conexión en {1} debe ser un array o un objeto JSON.", filename)
      end
    end
  end


  def json_lines_for_regional_dexes(filename)
    data = pbLoadJSONFile(filename)
    if !data.is_a?(Hash)
      raise _INTL("El archivo {1} debe contener un objeto JSON keyed por número de Pokédex.", filename)
    end
    lines = []
    data.each do |dex_number, species_list|
      if !species_list.is_a?(Array)
        raise _INTL("La lista de la Pokédex {1} en {2} debe ser un array JSON de especies.", dex_number, filename)
      end
      lines.push("[#{dex_number}]")
      lines.push(species_list.map { |s| json_scalar_to_csv_token(s) }.join(","))
    end
    return lines
  end

  def json_lines_for_encounters(filename)
    data = pbLoadJSONFile(filename)
    if !data.is_a?(Hash)
      raise _INTL("El archivo {1} debe contener un objeto JSON keyed por \"MapID_Version\".", filename)
    end
    lines = []
    data.each do |map_key, types|
      if !types.is_a?(Hash)
        raise _INTL("Los datos del mapa '{1}' en {2} deben ser un objeto JSON.", map_key, filename)
      end
      map_id, version = map_key.to_s.split("_", 2)
      version ||= "0"
      lines.push("[#{map_id},#{version}]")
      types.each do |type_name, slots|
        next if type_name.to_s.end_with?("_chance")   # Ya se consume junto a su tipo base, abajo
        if !slots.is_a?(Array)
          raise _INTL("Los slots del tipo de encuentro '{1}' del mapa '{2}' en {3} deben ser un array JSON.", type_name, map_key, filename)
        end
        chance = types["#{type_name}_chance"]
        lines.push(chance ? "#{type_name},#{chance}" : type_name.to_s)
        slots.each do |slot|
          if slot.is_a?(Hash)
            if !slot.key?("chance") || !slot.key?("species") || !slot.key?("min_level")
              raise _INTL("A un slot de '{1}' del mapa '{2}' en {3} le falta 'chance', 'species' o 'min_level'.", type_name, map_key, filename)
            end
            max_level = slot.key?("max_level") ? slot["max_level"] : slot["min_level"]
            row = [slot["chance"], slot["species"], slot["min_level"], max_level]
          elsif slot.is_a?(Array) && slot.length >= 3
            row = slot
          else
            raise _INTL("Cada slot de '{1}' del mapa '{2}' en {3} debe ser [chance, especie, nivel_min, nivel_max?] o un objeto JSON con esas claves.", type_name, map_key, filename)
          end
          lines.push(row.map { |v| json_scalar_to_csv_token(v) }.join(","))
        end
      end
    end
    return lines
  end

  def json_lines_for_trainers(filename)
    data = pbLoadJSONFile(filename)
    if !data.is_a?(Hash)
      raise _INTL("El archivo {1} debe contener un objeto JSON keyed por \"Tipo,Nombre,Version\".", filename)
    end
    lines = []
    data.each do |trainer_key, fields|
      if !fields.is_a?(Hash)
        raise _INTL("Los datos del entrenador '{1}' en {2} deben ser un objeto JSON.", trainer_key, filename)
      end
      parts = trainer_key.to_s.split(",")
      if parts.length < 2 || parts.length > 3
        raise _INTL("La clave del entrenador '{1}' en {2} debe tener el formato \"Tipo,Nombre\" o \"Tipo,Nombre,Version\".", trainer_key, filename)
      end
      parts.push("0") if parts.length < 3
      lines.push("[#{parts.join(",")}]")
      pokemon_list = fields["Pokemon"]
      fields.each do |key, value|
        next if key == "Pokemon"
        raw = (key == "LoseText" || key == "LoseText_F")
        lines.push("#{key} = #{json_value_to_csv_token(value, raw: raw)}")
      end
      next if !pokemon_list
      if !pokemon_list.is_a?(Array)
        raise _INTL("'Pokemon' del entrenador '{1}' en {2} debe ser un array JSON.", trainer_key, filename)
      end
      pokemon_list.each do |pkmn|
        if !pkmn.is_a?(Hash) || !pkmn["Species"] || !pkmn["Level"]
          raise _INTL("Cada Pokémon del entrenador '{1}' en {2} necesita al menos 'Species' y 'Level'.", trainer_key, filename)
        end
        lines.push("Pokemon = #{json_scalar_to_csv_token(pkmn["Species"])},#{json_scalar_to_csv_token(pkmn["Level"])}")
        pkmn.each do |key, value|
          next if key == "Species" || key == "Level"
          if (key == "IV" || key == "EV") && value.is_a?(Hash)
            lines.push("#{key} = #{stat_hash_to_csv_token(value, filename, key)}")
          else
            lines.push("#{key} = #{json_value_to_csv_token(value)}")
          end
        end
      end
    end
    return lines
  end

  #=============================================================================
  # Splits a string containing comma-separated values into an array of those
  # values.
  #=============================================================================
  def split_csv_line(string)
    # Split the string into an array of values, using a comma as the separator
    values = string.split(",")
    # Check for quote marks in each value, as we may need to recombine some values
    # to make proper results
    (0...values.length).each do |i|
      value = values[i]
      next if !value || value.empty?
      quote_count = value.count('"')
      if quote_count != 0
        # Quote marks found in value
        (i...(values.length - 1)).each do |j|
          quote_count = values[i].count('"')
          if quote_count == 2 && value.start_with?('\\"') && values[i].end_with?('\\"')
            # Two quote marks around the whole value; remove them
            values[i] = values[i][2..-3]
            break
          elsif quote_count.even?
            break
          end
          # Odd number of quote marks in value; concatenate the next value to it and
          # see if that's any better
          values[i] += "," + values[j + 1]
          values[j + 1] = nil
        end
        # Recheck for enclosing quote marks to remove
        if quote_count != 2
          if value.count('"') == 2 && value.start_with?('\\"') && value.end_with?('\\"')
            values[i] = values[i][2..-3]
          end
        end
      end
      # Remove leading and trailing whitespace from value
      values[i].strip!
    end
    # Remove nil values caused by concatenating values above
    values.compact!
    return values
  end

  #=============================================================================
  # Convert a string to certain kinds of values
  #=============================================================================
  # Unused
  # NOTE: This method is about 10 times slower than split_csv_line.
  def csvfield!(str)
    ret = ""
    str.sub!(/^\s*/, "")
    if str[0, 1] == "\""
      str[0, 1] = ""
      escaped = false
      fieldbytes = 0
      str.scan(/./) do |s|
        fieldbytes += s.length
        break if s == "\"" && !escaped
        if s == "\\" && !escaped
          escaped = true
        else
          ret += s
          escaped = false
        end
      end
      str[0, fieldbytes] = ""
      if !str[/^\s*,/] && !str[/^\s*$/]
        raise _INTL("Campo entre comillas no válido (en: {1})\n{2}", str, FileLineData.linereport)
      end
      str[0, str.length] = $~.post_match
    else
      if str[/,/]
        str[0, str.length] = $~.post_match
        ret = $~.pre_match
      else
        ret = str.clone
        str[0, str.length] = ""
      end
      ret.gsub!(/\s+$/, "")
    end
    return ret
  end

  # Unused
  def csvBoolean!(str, _line = -1)
    field = csvfield!(str)
    return true if field[/^(?:1|TRUE|YES|Y)$/i]
    return false if field[/^(?:0|FALSE|NO|N)$/i]
    raise _INTL("El campo {1} no es un valor booleano (true, false, 1, 0)\n{2}", field, FileLineData.linereport)
  end

  # Unused
  def csvInt!(str, _line = -1)
    ret = csvfield!(str)
    if !ret[/^\-?\d+$/]
      raise _INTL("El campo {1} no es un entero (int) \n{2}", ret, FileLineData.linereport)
    end
    return ret.to_i
  end

  # Unused
  def csvPosInt!(str, _line = -1)
    ret = csvfield!(str)
    if !ret[/^\d+$/]
      raise _INTL("El campo {1} no es un número entero (int) positivo\n{2}", ret, FileLineData.linereport)
    end
    return ret.to_i
  end

  # Unused
  def csvFloat!(str, _line = -1)
    ret = csvfield!(str)
    return Float(ret) rescue raise _INTL("El campo {1} no es un número\n{2}", ret, FileLineData.linereport)
  end

  # Unused
  def csvEnumField!(value, enumer, _key, _section)
    ret = csvfield!(value)
    return checkEnumField(ret, enumer)
  end

  # Unused
  def csvEnumFieldOrInt!(value, enumer, _key, _section)
    ret = csvfield!(value)
    return ret.to_i if ret[/\-?\d+/]
    return checkEnumField(ret, enumer)
  end

  # Turns a value (a string) into another data type as determined by the given
  # schema.
  # @param value [String]
  # @param schema [String]
  def cast_csv_value(value, schema, enumer = nil)
    case schema.downcase
    when "i"   # Integer
      if !value || !value[/^\-?\d+$/]
        raise _INTL("El campo {1} no es un número entero (int)\n{2}", value, FileLineData.linereport)
      end
      return value.to_i
    when "u"   # Positive integer or zero
      if !value || !value[/^\d+$/]
        raise _INTL("El campo {1} no es un número entero (int) positivo o 0\n{2}", value, FileLineData.linereport)
      end
      return value.to_i
    when "v"   # Positive integer
      if !value || !value[/^\d+$/]
        raise _INTL("El campo {1} no es un número entero (int) positivo\n{2}", value, FileLineData.linereport)
      end
      if value.to_i == 0
        raise _INTL("El campo '{1}' debe ser mayor que 0\n{2}", value, FileLineData.linereport)
      end
      return value.to_i
    when "x"   # Hexadecimal number
      if !value || !value[/^[A-F0-9]+$/i]
        raise _INTL("El campo '{1}' no es un número hexadecimal\n{2}", value, FileLineData.linereport)
      end
      return value.hex
    when "f"   # Floating point number
      if !value || !value[/^\-?^\d*\.?\d*$/]
        raise _INTL("El campo {1} no es un número\n{2}", value, FileLineData.linereport)
      end
      return value.to_f
    when "b"   # Boolean
      return true if value && value[/^(?:1|TRUE|YES|Y)$/i]
      return false if value && value[/^(?:0|FALSE|NO|N)$/i]
      raise _INTL("El campo {1} no es un valor booleano (true, false, 1, 0)\n{2}", value, FileLineData.linereport)
    when "n"   # Name
      if !value || !value[/^(?![0-9])\w+$/]
        raise _INTL("El campo '{1}' solo puede contener letras, dígitos y guiones bajos, y no debe comenzar con un número.\n{2}", value, FileLineData.linereport)
      end
    when "s"   # String
    when "q"   # Unformatted text
    when "m"   # Symbol
      if !value || !value[/^(?![0-9])\w+$/]
        raise _INTL("El campo '{1}' debe contener solo letras, dígitos y guiones bajos, y no puede comenzar con un número.\n{2}", value, FileLineData.linereport)
      end
      return value.to_sym
    when "e"   # Enumerable
      return checkEnumField(value, enumer)
    when "y"   # Enumerable or integer
      return value.to_i if value && value[/^\-?\d+$/]
      return checkEnumField(value, enumer)
    end
    return value
  end

  def checkEnumField(ret, enumer)
    case enumer
    when Module
      begin
        if nil_or_empty?(ret) || !enumer.const_defined?(ret)
          raise _INTL("Valor {1} no definido en {2}\n{3}", ret, enumer.name, FileLineData.linereport)
        end
      rescue NameError
        raise _INTL("Valor {1} incorrecto en {2}\n{3}", ret, enumer.name, FileLineData.linereport)
      end
      return enumer.const_get(ret.to_sym)
    when Symbol, String
      if !Kernel.const_defined?(enumer.to_sym) && GameData.const_defined?(enumer.to_sym)
        enumer = GameData.const_get(enumer.to_sym)
        begin
          if nil_or_empty?(ret) || !enumer.exists?(ret.to_sym)
            raise _INTL("Valor {1} no definido en {2}\n{3}", ret, enumer.name, FileLineData.linereport)
          end
        rescue NameError
          raise _INTL("Valor {1} incorrecto en {2}\n{3}", ret, enumer.name, FileLineData.linereport)
        end
        return ret.to_sym
      end
      enumer = Object.const_get(enumer.to_sym)
      begin
        if nil_or_empty?(ret) || !enumer.const_defined?(ret)
          raise _INTL("Valor {1} no definido en {2}\n{3}", ret, enumer.name, FileLineData.linereport)
        end
      rescue NameError
        raise _INTL("Valor {1} incorrecto en {2}\n{3}", ret, enumer.name, FileLineData.linereport)
      end
      return enumer.const_get(ret.to_sym)
    when Array
      idx = findIndex(enumer) { |item| ret == item }
      if idx < 0
        raise _INTL("Valor {1} no definido (se esperaba uno de: {2})\n{3}", ret, enumer.inspect, FileLineData.linereport)
      end
      return idx
    when Hash
      value = enumer[ret]
      if value.nil?
        raise _INTL("Valor no definido {1} (se esperaba uno de: {2})\n{3}", ret, enumer.keys.inspect, FileLineData.linereport)
      end
      return value
    end
    raise _INTL("Enumeración no definida\n{1}", FileLineData.linereport)
  end

  # Unused
  def checkEnumFieldOrNil(ret, enumer)
    case enumer
    when Module
      return nil if nil_or_empty?(ret) || !(enumer.const_defined?(ret) rescue false)
      return enumer.const_get(ret.to_sym)
    when Symbol, String
      if GameData.const_defined?(enumer.to_sym)
        enumer = GameData.const_get(enumer.to_sym)
        return nil if nil_or_empty?(ret) || !enumer.exists?(ret.to_sym)
        return ret.to_sym
      end
      enumer = Object.const_get(enumer.to_sym)
      return nil if nil_or_empty?(ret) || !(enumer.const_defined?(ret) rescue false)
      return enumer.const_get(ret.to_sym)
    when Array
      idx = findIndex(enumer) { |item| ret == item }
      return nil if idx < 0
      return idx
    when Hash
      return enumer[ret]
    end
    return nil
  end

  #=============================================================================
  # Convert a string to values using a schema
  #=============================================================================
  # Unused
  # @deprecated This method is slated to be removed in v22.
  def pbGetCsvRecord(rec, lineno, schema)
    Deprecation.warn_method("pbGetCsvRecord", "v22", "get_csv_record")
    record = []
    repeat = false
    schema_length = schema[1].length
    start = 0
    case schema[1][0, 1]
    when "*"
      repeat = true
      start = 1
    when "^"
      start = 1
      schema_length -= 1
    end
    subarrays = repeat && schema[1].length > 2
    loop do
      subrecord = []
      (start...schema[1].length).each do |i|
        chr = schema[1][i, 1]
        case chr
        when "i"   # Integer
          subrecord.push(csvInt!(rec, lineno))
        when "I"   # Optional integer
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif !field[/^\-?\d+$/]
            raise _INTL("El campo {1} no es un entero (int)\n{2}", field, FileLineData.linereport)
          else
            subrecord.push(field.to_i)
          end
        when "u"   # Positive integer or zero
          subrecord.push(csvPosInt!(rec, lineno))
        when "U"   # Optional positive integer or zero
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif !field[/^\d+$/]
            raise _INTL("El campo '{1}' debe ser 0 o mayor\n{2}", field, FileLineData.linereport)
          else
            subrecord.push(field.to_i)
          end
        when "v"   # Positive integer
          field = csvPosInt!(rec, lineno)
          raise _INTL("El campo '{1}' debe ser mayor que 0\n{2}", field, FileLineData.linereport) if field == 0
          subrecord.push(field)
        when "V"   # Optional positive integer
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif !field[/^\d+$/]
            raise _INTL("El campo '{1}' debe ser mayor que 0\n{2}", field, FileLineData.linereport)
          elsif field.to_i == 0
            raise _INTL("El campo '{1}' debe ser mayor que 0\n{2}", field, FileLineData.linereport)
          else
            subrecord.push(field.to_i)
          end
        when "x"   # Hexadecimal number
          field = csvfield!(rec)
          if !field[/^[A-Fa-f0-9]+$/]
            raise _INTL("El campo '{1}' no es un número hexadecimal\n{2}", field, FileLineData.linereport)
          end
          subrecord.push(field.hex)
        when "X"   # Optional hexadecimal number
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif !field[/^[A-Fa-f0-9]+$/]
            raise _INTL("El campo '{1}' no es un número hexadecimal\n{2}", field, FileLineData.linereport)
          else
            subrecord.push(field.hex)
          end
        when "f"   # Floating point number
          subrecord.push(csvFloat!(rec, lineno))
        when "F"   # Optional floating point number
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif !field[/^\-?^\d*\.?\d*$/]
            raise _INTL("El campo {1} no es un número decimal\n{2}", field, FileLineData.linereport)
          else
            subrecord.push(field.to_f)
          end
        when "b"   # Boolean
          subrecord.push(csvBoolean!(rec, lineno))
        when "B"   # Optional Boolean
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif field[/^1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Tt]|[Yy]$/]
            subrecord.push(true)
          else
            subrecord.push(false)
          end
        when "n"   # Name
          field = csvfield!(rec)
          if !field[/^(?![0-9])\w+$/]
            raise _INTL("El campo '{1}' debe contener solo letras, dígitos y guiones bajos, y no puede empezar con un número.\n{2}", field, FileLineData.linereport)
          end
          subrecord.push(field)
        when "N"   # Optional name
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif !field[/^(?![0-9])\w+$/]
            raise _INTL("El campo '{1}' debe contener solo letras, dígitos y guiones bajos, y no puede empezar con un número.\n{2}", field, FileLineData.linereport)
          else
            subrecord.push(field)
          end
        when "s"   # String
          subrecord.push(csvfield!(rec))
        when "S"   # Optional string
          field = csvfield!(rec)
          subrecord.push((nil_or_empty?(field)) ? nil : field)
        when "q"   # Unformatted text
          subrecord.push(rec)
          rec = ""
        when "Q"   # Optional unformatted text
          if nil_or_empty?(rec)
            subrecord.push(nil)
          else
            subrecord.push(rec)
            rec = ""
          end
        when "m"   # Symbol
          field = csvfield!(rec)
          if !field[/^(?![0-9])\w+$/]
            raise _INTL("El campo '{1}' debe contener solo letras, números y guiones bajos, y no puede comenzar con un número.\n{2}", field, FileLineData.linereport)
          end
          subrecord.push(field.to_sym)
        when "M"   # Optional symbol
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif !field[/^(?![0-9])\w+$/]
            raise _INTL("El campo '{1}' debe contener solo letras, dígitos y guiones bajos, y no puede empezar con un número.\n{2}", field, FileLineData.linereport)
          else
            subrecord.push(field.to_sym)
          end
        when "e"   # Enumerable
          subrecord.push(csvEnumField!(rec, schema[2 + i - start], "", FileLineData.linereport))
        when "E"   # Optional enumerable
          field = csvfield!(rec)
          subrecord.push(checkEnumFieldOrNil(field, schema[2 + i - start]))
        when "y"   # Enumerable or integer
          field = csvfield!(rec)
          subrecord.push(csvEnumFieldOrInt!(field, schema[2 + i - start], "", FileLineData.linereport))
        when "Y"   # Optional enumerable or integer
          field = csvfield!(rec)
          if nil_or_empty?(field)
            subrecord.push(nil)
          elsif field[/^\-?\d+$/]
            subrecord.push(field.to_i)
          else
            subrecord.push(checkEnumFieldOrNil(field, schema[2 + i - start]))
          end
        end
      end
      if !subrecord.empty?
        if subarrays
          record.push(subrecord)
        else
          record.concat(subrecord)
        end
      end
      break if repeat && nil_or_empty?(rec)
      break unless repeat
    end
    return (!repeat && schema_length == 1) ? record[0] : record
  end

  #=============================================================================
  # Convert a string to values using a schema
  #=============================================================================
  def get_csv_record(rec, schema)
    ret = []
    repeat = false
    start = 0
    schema_length = schema[1].length
    case schema[1][0, 1]   # First character in schema
    when "*"
      repeat = true
      start = 1
    when "^"
      start = 1
      schema_length -= 1
    end
    subarrays = repeat && schema[1].length - start > 1   # Whether ret is an array of arrays
    # Split the string on commas into an array of values to apply the schema to
    values = split_csv_line(rec)
    # Apply the schema to each value in the line
    idx = -1   # Index of value to look at in values
    loop do
      record = []
      (start...schema[1].length).each do |i|
        idx += 1
        sche = schema[1][i, 1]
        if sche[/[A-Z]/]   # Upper case = optional
          if nil_or_empty?(values[idx])
            record.push(nil)
            next
          end
        end
        if sche.downcase == "q"   # Unformatted text
          record.push(rec)
          idx = values.length
          break
        else
          record.push(cast_csv_value(values[idx], sche, schema[2 + i - start]))
        end
      end
      if !record.empty?
        if subarrays
          ret.push(record)
        else
          ret.concat(record)
        end
      end
      break if !repeat || idx >= values.length - 1
    end
    return (!repeat && schema_length == 1) ? ret[0] : ret
  end

  #=============================================================================
  # Write values to a file using a schema
  #=============================================================================
  def pbWriteCsvRecord(record, file, schema)
    rec = (record.is_a?(Array)) ? record.flatten : [record]
    start = (["*", "^"].include?(schema[1][0, 1])) ? 1 : 0
    index = -1
    loop do
      (start...schema[1].length).each do |i|
        index += 1
        value = rec[index]
        if schema[1][i, 1][/[A-Z]/]   # Optional
          # Check the rest of the values for non-nil things
          later_value_found = false
          (index...rec.length).each do |j|
            later_value_found = true if !rec[j].nil?
            break if later_value_found
          end
          if !later_value_found
            start = -1
            break
          end
        end
        file.write(",") if index > 0
        next if value.nil?
        case schema[1][i, 1]
        when "e", "E"   # Enumerable
          enumer = schema[2 + i - start]
          case enumer
          when Array
            file.write((value.is_a?(Integer) && !enumer[value].nil?) ? enumer[value] : value)
          when Symbol, String
            if GameData.const_defined?(enumer.to_sym)
              mod = GameData.const_get(enumer.to_sym)
              file.write(mod.get(value).id.to_s)
            else
              mod = Object.const_get(enumer.to_sym)
              file.write(getConstantName(mod, value))
            end
          when Module
            file.write(getConstantName(enumer, value))
          when Hash
            if value.is_a?(String)
              file.write(value)
            else
              enumer.each_key do |key|
                next if enumer[key] != value
                file.write(key)
                break
              end
            end
          end
        when "y", "Y"   # Enumerable or integer
          enumer = schema[2 + i - start]
          case enumer
          when Array
            file.write((value.is_a?(Integer) && !enumer[value].nil?) ? enumer[value] : value)
          when Symbol, String
            if !Kernel.const_defined?(enumer.to_sym) && GameData.const_defined?(enumer.to_sym)
              mod = GameData.const_get(enumer.to_sym)
              if mod.exists?(value)
                file.write(mod.get(value).id.to_s)
              else
                file.write(value.to_s)
              end
            else
              mod = Object.const_get(enumer.to_sym)
              file.write(getConstantNameOrValue(mod, value))
            end
          when Module
            file.write(getConstantNameOrValue(enumer, value))
          when Hash
            if value.is_a?(String)
              file.write(value)
            else
              has_enum = false
              enumer.each_key do |key|
                next if enumer[key] != value
                file.write(key)
                has_enum = true
                break
              end
              file.write(value) if !has_enum
            end
          end
        else
          if value.is_a?(String)
            file.write((schema[1][i, 1].downcase == "q") ? value : csvQuote(value))
          elsif value.is_a?(Symbol)
            file.write(csvQuote(value.to_s))
          elsif value == true
            file.write("true")
          elsif value == false
            file.write("false")
          else
            file.write(value.inspect)
          end
        end
      end
      break if start > 0 && index >= rec.length - 1
      break if start <= 0
    end
    return record
  end

  #=============================================================================
  # Parse string into a likely constant name and return its ID number (if any).
  # Last ditch attempt to figure out whether a constant is defined.
  #=============================================================================
  # Unused
  def pbGetConst(mod, item, err)
    isDef = false
    begin
      mod = Object.const_get(mod) if mod.is_a?(Symbol)
      isDef = mod.const_defined?(item.to_sym)
    rescue
      raise sprintf(err, item)
    end
    raise sprintf(err, item) if !isDef
    return mod.const_get(item.to_sym)
  end

  def parseItem(item)
    clonitem = item.upcase
    clonitem.sub!(/^\s*/, "")
    clonitem.sub!(/\s*$/, "")
    itm = GameData::Item.try_get(clonitem)
    if !itm
      raise _INTL("Objeto no definido: {1}\nAsegúrate de que el objeto esté definido en PBS/items.txt.\n{2}", item, FileLineData.linereport)
    end
    return itm.id
  end

  def parseSpecies(species)
    clonspecies = species.upcase
    clonspecies.gsub!(/^\s*/, "")
    clonspecies.gsub!(/\s*$/, "")
    clonspecies = "NIDORANmA" if clonspecies == "NIDORANMA"
    clonspecies = "NIDORANfE" if clonspecies == "NIDORANFE"
    spec = GameData::Species.try_get(clonspecies)
    if !spec
      raise _INTL("Nombre de la especie no definido: {1}\nAsegúrate de que la especie esté definida en PBS/pokemon.txt.\n{2}", species, FileLineData.linereport)
    end
    return spec.id
  end

  def parseMove(move, skip_unknown = false)
    clonmove = move.upcase
    clonmove.sub!(/^\s*/, "")
    clonmove.sub!(/\s*$/, "")
    mov = GameData::Move.try_get(clonmove)
    if !mov
      return nil if skip_unknown
      raise _INTL("Movimiento no definido: {1}\nAsegúrate de que el movimiento esté definido en PBS/moves.txt.\n{2}", move, FileLineData.linereport)
    end
    return mov.id
  end

  # Unused
  def parseNature(nature)
    clonnature = nature.upcase
    clonnature.sub!(/^\s*/, "")
    clonnature.sub!(/\s*$/, "")
    nat = GameData::Nature.try_get(clonnature)
    if !nat
      raise _INTL("naturaleza no definida: {1}\nAsegúrate de que la naturaleza esté definida en los scripts.\n{2}", nature, FileLineData.linereport)
    end
    return nat.id
  end

  # Unused
  def parseTrainer(type)
    clontype = type.clone
    clontype.sub!(/^\s*/, "")
    clontype.sub!(/\s*$/, "")
    typ = GameData::TrainerType.try_get(clontype)
    if !typ
      raise _INTL("Tipo de Entrenador no definido: {1}\nAsegúrate de que el tipo de entrenador esté definido en PBS/trainer_types.txt.\n{2}", type, FileLineData.linereport)
    end
    return typ.id
  end

  #=============================================================================
  # Replace text in PBS files before compiling them
  #=============================================================================
  def edit_and_rewrite_pbs_file_text(filename)
    return if !block_given? || !FileTest.exist?(filename)
    lines = []
    File.open(filename, "rb") do |f|
      f.each_line { |line| lines.push(line) }
    end
    changed = false
    lines.each { |line| changed = true if yield line }
    if changed
      Console.markup_style("Changes made to file #{filename}.", text: :yellow)
      File.open(filename, "wb") do |f|
        lines.each { |line| f.write(line) }
      end
    end
  end

  def modify_pbs_file_contents_before_compiling
    edit_and_rewrite_pbs_file_text("PBS/trainer_types.txt") do |line|
      next line.gsub!(/^\s*VictoryME\s*=/, "VictoryBGM =")
    end
    edit_and_rewrite_pbs_file_text("PBS/moves.txt") do |line|
      next line.gsub!(/^\s*BaseDamage\s*=/, "Power =")
    end
  end

  #=============================================================================
  # Compile all data
  #=============================================================================
  def compile_pbs_file_message_start(filename)
    # The `` around the file's name turns it cyan
    Console.echo_li(_INTL("Compilando el archivo PBS `{1}`...", filename.split("/").last))
  end

  def write_pbs_file_message_start(filename)
    # The `` around the file's name turns it cyan
    Console.echo_li(_INTL("Escribiendo el archivo PBS `{1}`...", filename.split("/").last))
  end

  def process_pbs_file_message_end
    Console.echo_done(true)
    Graphics.update
  end

  def get_all_pbs_files_to_compile
    # Get the GameData classes and their respective base PBS filenames
    ret = GameData.get_all_pbs_base_filenames
    ret.merge!({
      :BattleFacility => "battle_facility_lists",
      :Connection     => "map_connections",
      :RegionalDex    => "regional_dexes"
    })
    ret.each { |key, val| ret[key] = [val] }   # [base_filename, ["PBS/file.txt", etc.]]
    # Look through all PBS files and match them to a GameData class based on
    # their base filenames
    text_files_keys = ret.keys.sort! { |a, b| ret[b][0].length <=> ret[a][0].length }
    Dir.chdir("PBS/") do
      # Dir.glob's order isn't guaranteed alphabetical (filesystem-dependent),
      # but additional/suffixed files (pokemon_custom.txt, pokemon_AAA.txt,
      # pokemon_custom_001.txt...) must load in a predictable order so later
      # files can override earlier ones. Sort case-insensitively; since "."
      # (0x2E) sorts before "_" (0x5F) and any letter/digit, the base file
      # (pokemon.txt) always loads before any pokemon_XXX suffix variant.
      all_files = Dir.glob(["*.txt", "*.json"]).sort_by { |f| f.downcase }
      # A .txt always wins over a .json with the same base name
      txt_basenames = all_files.select { |f| File.extname(f).downcase == ".txt" }
                               .map { |f| File.basename(f, ".txt") }
      all_files.each do |f|
        next if File.extname(f).downcase == ".json" && txt_basenames.include?(File.basename(f, ".json"))
        base_name = File.basename(f, File.extname(f))
        text_files_keys.each do |key|
          next if base_name != ret[key][0] && !f.start_with?(ret[key][0] + "_")
          ret[key][1] ||= []
          ret[key][1].push("PBS/" + f)
          break
        end
      end
    end
    return ret
  end

  def compile_pbs_files
    text_files = get_all_pbs_files_to_compile
    modify_pbs_file_contents_before_compiling
    compile_town_map(*text_files[:TownMap][1])
    compile_connections(*text_files[:Connection][1])
    compile_types(*text_files[:Type][1])
    compile_abilities(*text_files[:Ability][1])
    compile_moves(*text_files[:Move][1])                       # Depends on Type
    compile_items(*text_files[:Item][1])                       # Depends on Move
    compile_berry_plants(*text_files[:BerryPlant][1])          # Depends on Item
    compile_pokemon(*text_files[:Species][1])                  # Depends on Move, Item, Type, Ability
    compile_pokemon_forms(*text_files[:Species1][1])           # Depends on Species, Move, Item, Type, Ability
    compile_pokemon_metrics(*text_files[:SpeciesMetrics][1])   # Depends on Species
    compile_shadow_pokemon(*text_files[:ShadowPokemon][1])     # Depends on Species
    compile_regional_dexes(*text_files[:RegionalDex][1])       # Depends on Species
    compile_ribbons(*text_files[:Ribbon][1])
    compile_encounters(*text_files[:Encounter][1])             # Depends on Species
    compile_trainer_types(*text_files[:TrainerType][1])
    compile_trainers(*text_files[:Trainer][1])                 # Depends on Species, Item, Move
    compile_trainer_lists                                      # Depends on TrainerType
    compile_metadata(*text_files[:Metadata][1])                # Depends on TrainerType
    compile_map_metadata(*text_files[:MapMetadata][1])
    compile_dungeon_tilesets(*text_files[:DungeonTileset][1])
    compile_dungeon_parameters(*text_files[:DungeonParameters][1])
    compile_phone(*text_files[:PhoneMessage][1])               # Depends on TrainerType
  end

  def compile_all(mustCompile)
    Console.echo_h1(_INTL("Comprobando los datos del juego"))
    if !mustCompile
      Console.echoln_li(_INTL("Los datos del juego no se han tenido que compilar de nuevo"))
      echoln ""
      return
    end
    FileLineData.clear
    compile_pbs_files
    compile_animations
    compile_trainer_events(mustCompile)
    Console.echo_li(_INTL("Guardando mensajes..."))
    Translator.gather_script_and_event_texts
    MessageTypes.save_default_messages
    MessageTypes.load_default_messages if FileTest.exist?("Data/messages_core.dat")
    Console.echo_done(true)
    Console.echoln_li_done(_INTL("Se han compilado los datos del juego correctamente"))
  end

  def main
    return if !$DEBUG
    begin
      mustCompile = false
      # If no PBS file, create one and fill it, then recompile
      if !FileTest.directory?("PBS")
        Dir.mkdir("PBS") rescue nil
        GameData.load_all
        write_all
        mustCompile = true
      end
      # Get all data files and PBS files to be checked for their last modified times
      data_files = GameData.get_all_data_filenames
      data_files += [   # Extra .dat files for data that isn't a GameData class
        ["map_connections.dat", true],
        ["regional_dexes.dat", true],
        ["trainer_lists.dat", true]
      ]
      text_files = get_all_pbs_files_to_compile
      latestDataTime = 0
      latestTextTime = 0
      # Should recompile if new maps were imported
      mustCompile |= import_new_maps
      # Check data files for their latest modify time
      data_files.each do |filename|   # filename = [string, boolean (whether mandatory)]
        if FileTest.exist?("Data/" + filename[0])
          begin
            File.open("Data/#{filename[0]}") do |file|
              latestDataTime = [latestDataTime, file.mtime.to_i].max
            end
          rescue SystemCallError
            mustCompile = true
          end
        elsif filename[1]
          mustCompile = true
          break
        end
      end
      # Check PBS files for their latest modify time
      text_files.each do |key, value|
        next if !value || !value[1].is_a?(Array)
        value[1].each do |filepath|
          begin
            File.open(filepath) { |file| latestTextTime = [latestTextTime, file.mtime.to_i].max }
          rescue SystemCallError
          end
        end
      end
      # Decide to compile if a PBS file was edited more recently than any .dat files
      mustCompile |= (latestTextTime >= latestDataTime)
      # Should recompile if holding Ctrl
      Input.update
      mustCompile = true if Input.press?(Input::CTRL)
      # Delete old data files in preparation for recompiling
      if mustCompile
        data_files.each do |filename|
          begin
            File.delete("Data/#{filename[0]}") if FileTest.exist?("Data/#{filename[0]}")
          rescue SystemCallError
          end
        end
      end
      # Recompile all data
      compile_all(mustCompile)
    rescue Exception
      e = $!
      raise e if e.class.to_s == "Reset" || e.is_a?(Reset) || e.is_a?(SystemExit)
      pbPrintException(e)
      data_files.each do |filename|
        begin
          File.delete("Data/#{filename[0]}") if FileTest.exist?("Data/#{filename[0]}")
        rescue SystemCallError
        end
      end
      raise Reset.new if e.is_a?(Hangup)
      raise "Excepción desconocida al compilar."
    end
  end
end

