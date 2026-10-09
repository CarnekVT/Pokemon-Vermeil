class TestEventTextExporter < TestCase
  def test_export_and_import_commands_are_inside_file_options
    assert_equal :files_menu, MenuHandlers.get(:debug_menu, :export_event_texts)["parent"]
    assert_equal :files_menu, MenuHandlers.get(:debug_menu, :import_event_texts)["parent"]
  end

  def test_exports_messages_and_choices_with_event_locations
    list = sample_list
    event = Struct.new(:id, :pages).new(4, [Struct.new(:list).new(list)])
    map = Struct.new(:events).new({ 4 => event })

    entries = EventTextExporter.map_entries(map, 12)

    assert_equal 2, entries.length
    assert_equal "Hola\n¿Todo bien?", entries[0]["original"]
    assert_equal({ "map_id" => 12, "event_id" => 4, "page" => 0, "command" => 0 }, entries[0]["location"])
    assert_equal ["Sí", "No"], entries[1]["text"]
  end

  def test_imports_multiline_edits_and_updates_choice_branch_labels
    list = sample_list
    event = Struct.new(:id, :pages).new(4, [Struct.new(:list).new(list)])
    map = Struct.new(:events).new({ 4 => event })
    entries = EventTextExporter.map_entries(map, 12)
    entries[0]["text"] = "Hola de nuevo\n¿Todo bien?\n¡Genial!"
    entries[1]["text"] = ["Claro", "Ahora no"]

    EventTextExporter.validate_map_entries(entries, 12, map)
    EventTextExporter.apply_map_entries(entries, map)

    assert_equal "Hola de nuevo\n¿Todo bien?\n¡Genial!", EventTextExporter.message_text(list, 0)
    assert_equal ["Claro", "Ahora no"], list[3].parameters[0]
    assert_equal "Claro", list[4].parameters[1]
    assert_equal "Ahora no", list[5].parameters[1]
  end

  def test_stale_text_is_rejected_before_any_edits_are_applied
    list = sample_list
    event = Struct.new(:id, :pages).new(4, [Struct.new(:list).new(list)])
    map = Struct.new(:events).new({ 4 => event })
    entries = EventTextExporter.map_entries(map, 12)
    entries[0]["text"] = "Texto corregido"
    entries[1]["original"] = ["Antiguo", "No"]

    was_debug, $DEBUG = $DEBUG, false
    assert_raises(RuntimeError) { EventTextExporter.validate_map_entries(entries, 12, map) }
  ensure
    $DEBUG = was_debug
  end

  def test_json_utf8_text_matches_binary_rxdata_strings
    list = [RPG::EventCommand.new(101, 0, ["Pokémon".b]), RPG::EventCommand.new(0, 0, [])]
    event = Struct.new(:id, :pages).new(4, [Struct.new(:list).new(list)])
    map = Struct.new(:events).new({ 4 => event })
    entries = JSON.parse(JSON.generate(EventTextExporter.map_entries(map, 12)))

    EventTextExporter.validate_map_entries(entries, 12, map)
  end

  def test_exports_and_applies_common_event_text
    list = [RPG::EventCommand.new(101, 0, ["Mensaje común"]), RPG::EventCommand.new(0, 0, [])]
    event = Struct.new(:id, :list).new(7, list)
    entries = EventTextExporter.common_event_entries([event])
    entries[0]["text"] = "Mensaje común corregido"

    EventTextExporter.validate_common_event_entries(entries, [event])
    EventTextExporter.apply_common_event_entries(entries, [event])

    assert_equal "Mensaje común corregido", list[0].parameters[0]
  end

  def test_accepts_a_combined_file_with_multiple_maps
    payload = EventTextExporter.combined_payload([
      { "map_id" => 1, "entries" => [] },
      { "map_id" => 12, "entries" => [] }
    ])

    EventTextExporter.validate_payload(payload, "maps")
    assert_equal [1, 12], payload["maps"].map { |map| map["map_id"] }
    EventTextExporter.validate_combined_map_payloads(payload["maps"])
  end

  def test_rejects_duplicate_map_ids_in_a_combined_file
    payloads = [
      { "map_id" => 12, "entries" => [] },
      { "map_id" => 12, "entries" => [] }
    ]

    assert_raises(RuntimeError) { EventTextExporter.validate_combined_map_payloads(payloads) }
  end

  private

  def sample_list
    [
      RPG::EventCommand.new(101, 0, ["Hola"]),
      RPG::EventCommand.new(401, 0, ["¿Todo bien?"]),
      RPG::EventCommand.new(102, 0, [["Sí", "No"], 0]),
      RPG::EventCommand.new(402, 0, [0, "Sí"]),
      RPG::EventCommand.new(402, 0, [1, "No"]),
      RPG::EventCommand.new(404, 0, []),
      RPG::EventCommand.new(0, 0, [])
    ]
  end
end
