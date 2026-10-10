
module EventTextExporter
  DIRECTORY = "Text_Events"
  BACKUP_DIRECTORY = "Text_Events/backups"
  FORMAT_VERSION = 1

  module_function

  def generated_files
    map_files = Dir.glob("#{DIRECTORY}/Map[0-9]*.json").select { |filename| filename[/Map\d+\.json$/i] }
    return map_files + ["#{DIRECTORY}/AllMaps.json", "#{DIRECTORY}/CommonEvents.json"]
  end

  def export_all(format = :per_map)
    raise "Formato de exportación no válido." if ![:per_map, :combined].include?(format)
    Dir.mkdir(DIRECTORY) if !Dir.exist?(DIRECTORY)
    map_payloads = []
    Dir.glob("Data/Map*.rxdata").sort.each do |filename|
      next if !filename[/Map(\d+)\.rxdata$/i]
      map_id = $1.to_i
      map = load_data(filename)
      entries = map_entries(map, map_id)
      next if entries.empty?
      map_payloads << { "map_id" => map_id, "entries" => entries }
    end
    common_entries = common_event_entries(load_data("Data/CommonEvents.rxdata"))
    generated_files.each { |filename| File.delete(filename) if File.file?(filename) }
    case format
    when :per_map
      map_payloads.each do |payload|
        write_json(sprintf("%s/Map%03d.json", DIRECTORY, payload["map_id"]), {
          "version" => FORMAT_VERSION,
          "source" => "map",
          "map_id" => payload["map_id"],
          "entries" => payload["entries"]
        })
      end
    when :combined
      write_json("#{DIRECTORY}/AllMaps.json", combined_payload(map_payloads))
    end
    count = map_payloads.sum { |payload| payload["entries"].length }
    if !common_entries.empty?
      write_json("#{DIRECTORY}/CommonEvents.json", {
        "version" => FORMAT_VERSION,
        "source" => "common_events",
        "entries" => common_entries
      })
      count += common_entries.length
    end
    return count
  end

  def import_all
    map_payloads = []
    combined_filename = "#{DIRECTORY}/AllMaps.json"
    map_filenames = Dir.glob("#{DIRECTORY}/Map[0-9]*.json").select { |filename| filename[/Map\d+\.json$/i] }.sort
    if File.file?(combined_filename) && !map_filenames.empty?
      raise "Usa AllMaps.json o los archivos Map*.json, no ambos formatos a la vez."
    end
    if File.file?(combined_filename)
      payload = read_json(combined_filename)
      validate_payload(payload, "maps")
      raise "El archivo no contiene una lista de mapas." if !payload["maps"].is_a?(Array)
      map_payloads = payload["maps"]
    else
      map_filenames.each do |filename|
        next if !filename[/Map(\d+)\.json$/i]
        map_id = $1.to_i
        payload = read_json(filename)
        validate_payload(payload, "map", map_id)
        map_payloads << { "map_id" => map_id, "entries" => payload["entries"] }
      end
    end
    validate_combined_map_payloads(map_payloads)
    loaded_maps = []
    map_payloads.each do |payload|
      map_id = payload["map_id"]
      map_filename = sprintf("Data/Map%03d.rxdata", map_id)
      raise _INTL("No se encontró el archivo {1}.", map_filename) if !File.file?(map_filename)
      map = load_data(map_filename)
      validate_map_entries(payload["entries"], map_id, map)
      loaded_maps << [map_filename, map, payload["entries"]]
    end

    common_filename = "#{DIRECTORY}/CommonEvents.json"
    common_events = nil
    common_entries = nil
    if File.file?(common_filename)
      payload = read_json(common_filename)
      validate_payload(payload, "common_events")
      common_events = load_data("Data/CommonEvents.rxdata")
      common_entries = payload["entries"]
      validate_common_event_entries(common_entries, common_events)
    end
    raise "No se encontraron archivos JSON en Text_Events." if loaded_maps.empty? && common_entries.nil?

    changed_files = []
    loaded_maps.each do |filename, map, entries|
      changed = entries.select { |entry| entry["original"] != entry["text"] }
      apply_map_entries(changed, map)
      changed_files << [filename, map] if !changed.empty?
    end
    if common_entries
      changed = common_entries.select { |entry| entry["original"] != entry["text"] }
      apply_common_event_entries(changed, common_events)
      changed_files << ["Data/CommonEvents.rxdata", common_events] if !changed.empty?
    end
    return 0 if changed_files.empty?

    Dir.mkdir(BACKUP_DIRECTORY) if !Dir.exist?(BACKUP_DIRECTORY)
    changed_files.each do |filename, _data|
      backup = File.join(BACKUP_DIRECTORY, File.basename(filename))
      if !File.exist?(backup)
        File.open(backup, "wb") { |file| file.write(File.binread(filename)) }
      end
    end
    changed_files.each { |filename, data| save_data(data, filename) }
    return changed_files.length
  end

  def map_entries(map, map_id)
    entries = []
    map.events.keys.sort.each do |event_id|
      event = map.events[event_id]
      event.pages.each_with_index do |page, page_index|
        entries.concat(list_entries(page.list, {
          "map_id" => map_id,
          "event_id" => event_id,
          "page" => page_index
        }))
      end
    end
    return entries
  end

  def combined_payload(map_payloads)
    return {
      "version" => FORMAT_VERSION,
      "source" => "maps",
      "maps" => map_payloads
    }
  end

  def common_event_entries(events)
    entries = []
    events.compact.each do |event|
      entries.concat(list_entries(event.list, { "event_id" => event.id }))
    end
    return entries
  end

  def list_entries(list, location)
    entries = []
    i = 0
    while i < list.length
      command = list[i]
      case command.code
      when 101
        lines = [command.parameters[0].to_s]
        j = i + 1
        while j < list.length && list[j].code == 401
          lines << list[j].parameters[0].to_s
          j += 1
        end
        entries << text_entry(location.merge("command" => i), "message", lines.join("\n"))
        i = j
      when 102
        choices = command.parameters[0]
        if choices.is_a?(Array)
          entries << text_entry(location.merge("command" => i), "choices", choices)
        end
        i += 1
      else
        i += 1
      end
    end
    return entries
  end

  def text_entry(location, type, text)
    return { "location" => location, "type" => type, "original" => text, "text" => text }
  end

  def validate_payload(payload, source, map_id = nil)
    raise "JSON inválido: se esperaba un objeto." if !payload.is_a?(Hash)
    raise "Versión JSON no compatible." if payload["version"] != FORMAT_VERSION
    raise "El tipo de archivo no coincide." if payload["source"] != source
    if source == "map" && payload["map_id"] != map_id
      raise "El ID del mapa no coincide con el nombre del archivo."
    end
    list_key = source == "maps" ? "maps" : "entries"
    raise "El archivo no contiene una lista de textos." if !payload[list_key].is_a?(Array)
  end

  def validate_combined_map_payloads(payloads)
    seen = {}
    payloads.each do |payload|
      raise "Datos de mapa inválidos en AllMaps.json." if !payload.is_a?(Hash)
      map_id = payload["map_id"]
      raise "ID de mapa inválido en AllMaps.json." if !map_id.is_a?(Integer) || map_id < 1
      raise "Hay un mapa duplicado en AllMaps.json." if seen[map_id]
      seen[map_id] = true
      raise "El archivo no contiene una lista de textos." if !payload["entries"].is_a?(Array)
    end
  end

  def validate_map_entries(entries, map_id, map)
    seen = {}
    entries.each do |entry|
      location = entry["location"]
      raise "Ubicación de texto inválida." if !location.is_a?(Hash) || location["map_id"] != map_id
      event = map.events[location["event_id"]]
      raise "No se encontró el evento indicado." if !event
      page = event.pages[location["page"]]
      raise "No se encontró la página indicada." if !page
      validate_entry(page.list, entry, seen)
    end
  end

  def validate_common_event_entries(entries, events)
    seen = {}
    entries.each do |entry|
      location = entry["location"]
      raise "Ubicación de evento común inválida." if !location.is_a?(Hash)
      event = events.compact.find { |candidate| candidate.id == location["event_id"] }
      raise "No se encontró el evento común indicado." if !event
      validate_entry(event.list, entry, seen)
    end
  end

  def validate_entry(list, entry, seen)
    location = entry["location"]
    command_index = location["command"]
    key = [location["map_id"], location["event_id"], location["page"], command_index]
    key = [location["event_id"], command_index] if !location.key?("map_id")
    raise "Hay una ubicación duplicada en el archivo." if seen[key]
    seen[key] = true
    command = list[command_index]
    raise "El comando indicado ya no existe." if !command
    raise "El tipo de comando ya no coincide." if
      (entry["type"] == "message" && command.code != 101) ||
      (entry["type"] == "choices" && command.code != 102) ||
      !["message", "choices"].include?(entry["type"])
    current = entry["type"] == "message" ? message_text(list, command_index) : command.parameters[0]
    raise "El texto original ha cambiado; vuelve a exportar antes de importar." if !same_text?(current, entry["original"])
    if entry["type"] == "message"
      raise "El texto editado debe ser una cadena." if !entry["text"].is_a?(String)
    else
      raise "La lista de opciones editada no es válida." if
        !entry["text"].is_a?(Array) || entry["text"].length != current.length ||
        entry["text"].any? { |choice| !choice.is_a?(String) }
    end
  end

  def message_text(list, command_index)
    lines = [list[command_index].parameters[0].to_s]
    i = command_index + 1
    while i < list.length && list[i].code == 401
      lines << list[i].parameters[0].to_s
      i += 1
    end
    return lines.join("\n")
  end

  def same_text?(left, right)
    if left.is_a?(Array) && right.is_a?(Array)
      return false if left.length != right.length
      return left.each_with_index.all? { |value, i| same_text?(value, right[i]) }
    end
    return left.b == right.b if left.is_a?(String) && right.is_a?(String)
    return left == right
  end

  def apply_map_entries(entries, map)
    grouped = entries.group_by do |entry|
      location = entry["location"]
      [location["event_id"], location["page"]]
    end
    grouped.each do |(event_id, page_index), page_entries|
      apply_entries_to_list(map.events[event_id].pages[page_index].list, page_entries)
    end
  end

  def apply_common_event_entries(entries, events)
    entries.group_by { |entry| entry["location"]["event_id"] }.each do |event_id, event_entries|
      event = events.compact.find { |candidate| candidate.id == event_id }
      apply_entries_to_list(event.list, event_entries)
    end
  end

  def apply_entries_to_list(list, entries)
    entries.sort_by { |entry| -entry["location"]["command"] }.each do |entry|
      index = entry["location"]["command"]
      if entry["type"] == "message"
        lines = entry["text"].split("\n", -1)
        lines = [""] if lines.empty?
        list[index].parameters[0] = lines.shift
        while index + 1 < list.length && list[index + 1].code == 401
          list.delete_at(index + 1)
        end
        lines.each_with_index do |line, offset|
          list.insert(index + offset + 1, RPG::EventCommand.new(401, list[index].indent, [line]))
        end
      else
        choices = list[index].parameters[0]
        entry["text"].each_with_index { |text, choice_index| choices[choice_index] = text }
        choice_branches(list, index).each do |branch|
          branch_index = branch.parameters[0]
          branch.parameters[1] = choices[branch_index] if choices[branch_index]
        end
      end
    end
  end

  def choice_branches(list, command_index)
    branches = []
    i = command_index + 1
    parent_indent = list[command_index].indent
    while i < list.length
      break if list[i].code == 404 && list[i].indent <= parent_indent
      branches << list[i] if list[i].code == 402 && list[i].indent == parent_indent
      i += 1
    end
    return branches
  end

  def read_json(filename)
    HTTPLite::JSON.parse(File.read(filename, encoding: "UTF-8"))
  rescue HTTPLite::JSON::ParserError => e
    raise "JSON inválido en #{filename}: #{e.message}"
  end

  def write_json(filename, payload)
    File.open(filename, "wb") do |file|
      file.write(HTTPLite::JSON.pretty_generate(payload))
      file.write("\n")
    end
  end
end

MenuHandlers.add(:debug_menu, :export_event_texts, {
  "name"        => _INTL("Exportar textos de eventos"),
  "parent"      => :files_menu,
  "description" => _INTL("Exporta diálogos y opciones a archivos JSON editables."),
  "order"       => 9997,
  "always_show" => true,
  "effect"      => proc {
    existing_files = EventTextExporter.generated_files.select { |filename| File.file?(filename) }
    if !existing_files.empty? && !pbConfirmMessageSerious(_INTL("La carpeta Text_Events ya contiene archivos JSON. ¿Sobrescribirlos con los textos actuales?"))
      next false
    end
    format = pbMessage(_INTL("¿Cómo quieres organizar los JSON de mapas?"), [
      _INTL("Un archivo por mapa"),
      _INTL("Un archivo con todos los mapas")
    ], -1)
    next false if format < 0
    count = EventTextExporter.export_all(format == 0 ? :per_map : :combined)
    pbMessage(_INTL("Se exportaron {1} textos a la carpeta Text_Events.", count))
  }
})

MenuHandlers.add(:debug_menu, :import_event_texts, {
  "name"        => _INTL("Importar textos de eventos"),
  "parent"      => :files_menu,
  "description" => _INTL("Aplica las ediciones de los archivos JSON de Text_Events."),
  "order"       => 9998,
  "always_show" => true,
  "effect"      => proc {
    next false if !pbConfirmMessageSerious(_INTL("¿Importar los textos de la carpeta Text_Events? Se crearán copias de seguridad de los datos modificados."))
    begin
      count = EventTextExporter.import_all
      pbMessage(_INTL("Se actualizaron {1} archivos. Reinicia el juego para ver los cambios.", count))
    rescue => e
      pbMessage(_INTL("No se importaron los textos: {1}", e.message))
    end
  }
})
