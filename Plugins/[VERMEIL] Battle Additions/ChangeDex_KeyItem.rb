#===============================================================================
# Vermeil Change Dex
#===============================================================================
module VermeilChangeDex
  SCREEN_W = 512
  SCREEN_H = 384
  LEFT_PANEL_CENTER_X = 82
  GRID_COLS = 6
  GRID_ROWS = 4
  GRID_ACTIVE_ROWS = 3
  GRID_PAGE_SIZE = GRID_COLS * GRID_ACTIVE_ROWS
  GRID_CELL = 80
  GRID_X = (SCREEN_W - (GRID_COLS * GRID_CELL)) / 2
  GRID_Y = 60
  
  COLOR_BG           = Color.new(20, 25, 35)
  COLOR_GRID_FILL    = Color.new(30, 38, 52, 140)
  COLOR_GRID_EDGE    = Color.new(56, 70, 92, 120)
  COLOR_PANEL_FILL   = Color.new(28, 36, 50, 170)
  COLOR_PANEL_EDGE   = Color.new(62, 78, 104, 150)
  COLOR_HIGHLIGHT    = Color.new(220, 60, 60)
  COLOR_TEXT_MAIN    = Color.new(245, 245, 245)
  COLOR_TEXT_GRAY    = Color.new(180, 180, 180)
  COLOR_CANON        = Color.new(80, 180, 255)
  COLOR_VERMEIL      = Color.new(255, 100, 100)
  COLOR_DIFF         = Color.new(255, 215, 0)
  COLOR_MOVES_NEW    = Color.new(100, 255, 120)

  @canon_cache = {}

  def self.load_canon_data
    return if !@canon_cache.empty?
    files = Dir.glob("CanonData/*.txt")
    return if files.empty?
    current_id = nil; current_form = 0
    files.each do |file_path|
      File.open(file_path, "r:utf-8") do |f|
        f.each_line do |line|
          line = line.strip.split("#")[0]; next if line.nil? || line.empty?
          if line[/^\[(.+)\]$/]
            content = $1; parts = content.split(",")
            current_id = parts[0].strip.to_sym
            current_form = parts[1] ? parts[1].strip.to_i : 0
            @canon_cache[current_id] ||= {}
            @canon_cache[current_id][current_form] = { 
              :stats => [], :abilities => [], :hidden_abilities => [],
              :types => [], :level_moves => [], :tutor_moves => [], :egg_moves => [],
              :evolutions => []
            }
            next
          end
          next if current_id.nil?; data = @canon_cache[current_id][current_form]; next if !data
          if line[/^BaseStats\s*=\s*(.*)$/i]
            data[:stats] = $1.strip.split(",").map { |s| s.strip.to_i }
          elsif line[/^Abilities\s*=\s*(.*)$/i]
            data[:abilities] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^HiddenAbilit(?:y|ies)\s*=\s*(.*)$/i]
            data[:hidden_abilities] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^Types\s*=\s*(.*)$/i]
            data[:types] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^Moves\s*=\s*(.*)$/i]
            m_data = $1.strip.split(","); list = []
            m_data.each_with_index { |val, i| list.push(val.strip.to_sym) if i.odd? }
            data[:level_moves] = list
          elsif line[/^TutorMoves\s*=\s*(.*)$/i]
            data[:tutor_moves] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^EggMoves\s*=\s*(.*)$/i]
            data[:egg_moves] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^Evolutions\s*=\s*(.*)$/i]
            evo_parts = $1.strip.split(",").map { |s| s.strip }
            evos = []
            evo_parts.each_slice(3) do |species_str, method_str, param_str|
              next if species_str.nil? || species_str.empty?
              method = (method_str.nil? || method_str.empty?) ? :None : method_str.to_sym
              evos.push([species_str.to_sym, method, param_str])
            end
            data[:evolutions] = evos
          end
        end
      end
    end
  end

  def self.get_canon_info(species, form)
    load_canon_data if @canon_cache.empty?
    return nil if !@canon_cache[species]
    return nil if form > 0 && !@canon_cache[species][form]
    base = @canon_cache[species][0]; this = @canon_cache[species][form]; res = {}
    res[:stats] = (!this[:stats].empty?) ? this[:stats] : base[:stats]
    res[:types] = (!this[:types].empty?) ? this[:types] : base[:types]
    res[:abilities] = (!this[:abilities].empty?) ? this[:abilities] : base[:abilities]
    res[:hidden_abilities] = (!this[:hidden_abilities].empty?) ? this[:hidden_abilities] : base[:hidden_abilities]
    res[:level_moves] = (!this[:level_moves].empty?) ? this[:level_moves] : base[:level_moves]
    res[:tutor_moves] = (!this[:tutor_moves].empty?) ? this[:tutor_moves] : (base ? base[:tutor_moves] : [])
    res[:egg_moves]   = (!this[:egg_moves].empty?) ? this[:egg_moves] : (base ? base[:egg_moves] : [])
    res[:evolutions]  = (!this[:evolutions].empty?) ? this[:evolutions] : (base ? base[:evolutions] : [])
    return res
  end

  class Scene
    def initialize
      @mode = :grid; @index = 0; @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999; @sprites = {}; @entries = []
      @typebitmap = AnimatedBitmap.new(_INTL("Graphics/UI/types"))
      @action_key_name = resolve_input_name(Input::ACTION, "Z")
      @filter_key_name = resolve_input_name(Input::SPECIAL, "Special")
      @sort_mode = :dex
      @type_filter = :all
      @generation_filter = nil
      VermeilChangeDex.load_canon_data; detect_changes
    end

    def resolve_input_name(input_constant, fallback)
      generic_names = []
      begin
        generic_names = [input_constant.to_s.downcase]
      rescue StandardError
        generic_names = []
      end
      generic_names.concat(["use", "back", "action", "special"])
      helper_methods = [
        :getKeyName, :get_key_name,
        :getInputName, :get_input_name,
        :keyName, :key_name,
        :buttonName, :button_name,
        :getButtonName, :get_button_name
      ]
      helper_methods.each do |meth|
        next unless Input.respond_to?(meth)
        begin
          name = Input.send(meth, input_constant).to_s.strip
          if !name.empty? && !generic_names.include?(name.downcase)
            return name
          end
        rescue StandardError
          next
        end
      end
      keybind_name = keybinding_name_for(input_constant)
      return keybind_name if keybind_name && !keybind_name.empty?
      return fallback
    end

    def keybinding_name_for(input_constant)
      begin
        data_dir = System.data_directory
        return nil if !data_dir
        kb_path = File.join(data_dir, "keybindings.mkxp1")
        return nil if !File.file?(kb_path)
        ints = File.binread(kb_path).unpack("l<*")
        records = ints.each_slice(4).to_a
        matches = records.select { |rec| rec && rec.length == 4 && rec[2] == input_constant }
        return nil if matches.empty?
        # Prefer the most recently defined mapping by priority/order field.
        matches.sort_by! { |rec| rec[3] || 0 }
        keycode = matches[-1][0]
        return keycode_to_label(keycode)
      rescue StandardError
        return nil
      end
    end

    def keycode_to_label(code)
      return nil if code.nil?
      # SDL scancode letters A-Z.
      return (65 + (code - 4)).chr if code >= 4 && code <= 29
      # Numbers 1-9,0.
      return (code - 29).to_s if code >= 30 && code <= 38
      return "0" if code == 39
      # Function keys.
      return "F#{code - 57}" if code >= 58 && code <= 69
      # Arrows.
      return "RIGHT" if code == 79
      return "LEFT"  if code == 80
      return "DOWN"  if code == 81
      return "UP"    if code == 82
      # Common controls.
      return "ENTER" if code == 40
      return "ESC" if code == 41
      return "SPACE" if code == 44
      return nil
    end

    def detect_changes
      @entry_gained_evos = {}
      @dex_order = {}
      dex_idx = 0
      GameData::Species.each_species do |base_species|
        dex_idx += 1
        @dex_order[base_species.species] = dex_idx
      end
      GameData::Species.each do |s|
        next if s.form > 0 && (s.form_name.nil? || s.form_name.empty?)
        canon = VermeilChangeDex.get_canon_info(s.species, s.form); next if canon.nil?
        v_raw = s.base_stats.values; v_stats = [v_raw[0], v_raw[1], v_raw[2], v_raw[5], v_raw[3], v_raw[4]]
        v_abil = (s.abilities + s.hidden_abilities).compact.reject{|a| a == :NONE}.uniq.sort
        c_abil = (canon[:abilities] + canon[:hidden_abilities]).compact.reject{|a| a == :NONE}.uniq.sort
        v_types = (s.types || []).to_a.sort; c_types = (canon[:types] || []).to_a.sort
        v_moves = s.moves.map { |m| m[1] }.uniq; c_pool = (canon[:level_moves] + canon[:tutor_moves] + canon[:egg_moves]).uniq
        new_moves = v_moves - c_pool
        gained_evos = gained_evolution_species(s, canon)
        has_change = (v_stats != canon[:stats] || v_abil != c_abil || (!c_types.empty? && v_types != c_types) || !new_moves.empty? || !gained_evos.empty?)
        if has_change
          key = [s.species, s.form]
          @entries.push(key)
          @entry_gained_evos[key] = gained_evos
        end
      end
      @entries.sort_by! { |k| [@dex_order[k[0]] || 999_999, k[1]] }
      @all_entries = @entries.clone
      apply_filters
    end

    def species_generation_for(species)
      dex = @dex_order[species] || 0
      return 1 if dex >= 1   && dex <= 151
      return 2 if dex >= 152 && dex <= 251
      return 3 if dex >= 252 && dex <= 386
      return 4 if dex >= 387 && dex <= 493
      return 5 if dex >= 494 && dex <= 649
      return 6 if dex >= 650 && dex <= 721
      return 7 if dex >= 722 && dex <= 809
      return 8 if dex >= 810 && dex <= 905
      return 9 if dex > 905
      return nil
    end

    def mega_form?(species, form)
      return false if form <= 0
      s_data = GameData::Species.get_species_form(species, form)
      return false if !s_data
      return s_data.form_name.to_s.downcase.include?("mega")
    end

    def regional_form?(species, form)
      return false if form <= 0
      s_data = GameData::Species.get_species_form(species, form)
      return false if !s_data
      form_name = s_data.form_name.to_s.downcase
      regional_tags = ["alolan", "galarian", "hisuian", "paldean", "kantonian", "kantoan", "kanto"]
      return regional_tags.any? { |tag| form_name.include?(tag) }
    end

    def apply_filters
      list = (@all_entries || []).clone
      case @type_filter
      when :mega
        list.select! { |sp, f| mega_form?(sp, f) }
      when :regional
        list.select! { |sp, f| regional_form?(sp, f) }
      end
      if @generation_filter
        list.select! { |sp, _f| species_generation_for(sp) == @generation_filter }
      end
      case @sort_mode
      when :az
        list.sort_by! { |sp, f| [changedex_display_name(sp, f).downcase, f] }
      when :za
        list.sort_by! { |sp, f| [changedex_display_name(sp, f).downcase, f] }
        list.reverse!
      else
        list.sort_by! { |k| [@dex_order[k[0]] || 999_999, k[1]] }
      end
      @entries = list
      if @entries.empty?
        @index = 0
      else
        @index = [[@index, 0].max, @entries.length - 1].min
      end
    end

    def open_filter_menu
      commands = [
        "Sort: Dex Order",
        "Sort: A-Z",
        "Sort: Z-A",
        "Filter: Megas Only",
        "Filter: Regional Forms Only",
        "Filter: Generation",
        "Clear Filters",
        "Cancel"
      ]
      chosen = pbShowCommands(nil, commands, -1)
      return if chosen < 0 || chosen == 7
      case chosen
      when 0
        @sort_mode = :dex
      when 1
        @sort_mode = :az
      when 2
        @sort_mode = :za
      when 3
        @type_filter = (@type_filter == :mega) ? :all : :mega
      when 4
        @type_filter = (@type_filter == :regional) ? :all : :regional
      when 5
        gen_cmd = ["All Generations", "Gen 1", "Gen 2", "Gen 3", "Gen 4", "Gen 5", "Gen 6", "Gen 7", "Gen 8", "Gen 9", "Cancel"]
        default_idx = @generation_filter ? @generation_filter : 0
        gen_choice = pbShowCommands(nil, gen_cmd, -1, default_idx)
        return if gen_choice < 0 || gen_choice == 10
        @generation_filter = (gen_choice == 0) ? nil : gen_choice
      when 6
        @sort_mode = :dex
        @type_filter = :all
        @generation_filter = nil
      end
      apply_filters
      draw_grid_interface
    end

    def gained_evolution_species(species_data, canon)
      return gained_evolution_data(species_data, canon).map { |e| e[:species] }
    end

    def gained_evolution_data(species_data, canon)
      return [] if !species_data
      current_evos = species_data.get_evolutions(true).map do |e|
        [e[0], (e[1] || :None).to_sym, e[2]]
      end
      canon_evos = (canon[:evolutions] || []).map { |e| [e[0], (e[1] || :None).to_sym] }
      canon_evos = canon_evos.reject { |e| e[1].to_s.downcase == "none" }.map { |e| e[0] }.uniq
      gained = []
      current_evos.each do |species, method, param|
        next if canon_evos.include?(species)
        gained << { :species => species, :method => method, :param => param }
      end
      return gained.uniq { |e| e[:species] }
    end

    def changedex_evo_method_label(method, param)
      m = method.to_s
      p = param.to_s.strip
      has_param = !p.empty? && p.upcase != "NONE"
      label = nil
      case m.downcase
      when "item"
        if has_param
          item_id = p.to_sym rescue nil
          item_name = item_id ? (GameData::Item.try_get(item_id)&.name || p) : p
          label = "Item: #{item_name}"
        else
          label = "Item"
        end
      when "trade"
        label = "Trade"
      when "tradeitem"
        if has_param
          item_id = p.to_sym rescue nil
          item_name = item_id ? (GameData::Item.try_get(item_id)&.name || p) : p
          label = "Trade + #{item_name}"
        else
          label = "Trade + Item"
        end
      when "happiness", "friendship"
        label = "Friendship"
      end
      if label.nil?
        if m[/^Level/i]
          suffix = m.sub(/^Level/, "")
          suffix = suffix.gsub(/([a-z])([A-Z])/, '\1 \2').strip
          label = has_param ? "Lv.#{p}" : "Lv."
          label += " #{suffix}" if !suffix.empty?
        else
          pretty = m.gsub(/([a-z])([A-Z])/, '\1 \2').strip
          label = pretty
          label += " (#{p})" if has_param
        end
      end
      return "Evo: #{label}"
    end

    def changedex_evo_method_short_label(method, param)
      return changedex_evo_method_label(method, param).sub(/^Evo:\s*/, "")
    end

    def canon_evolution_data(canon)
      data = []
      (canon[:evolutions] || []).each do |e|
        species = e[0]
        method = (e[1] || :None).to_sym
        param = e[2]
        next if method.to_s.downcase == "none"
        data << { :species => species, :method => method, :param => param }
      end
      return data
    end

    def evolution_method_change_data(species_data, canon)
      return { :new => [], :changed => [], :canon => [] } if !species_data
      canon_list = canon_evolution_data(canon)
      canon_map = {}
      canon_list.each do |e|
        canon_map[e[:species]] ||= []
        canon_map[e[:species]] << e
      end
      current_list = species_data.get_evolutions(true).map do |e|
        { :species => e[0], :method => (e[1] || :None).to_sym, :param => e[2] }
      end
      current_list = current_list.reject { |e| e[:method].to_s.downcase == "none" }
      new_list = []
      changed_list = []
      current_list.each do |cur|
        canon_for_species = canon_map[cur[:species]] || []
        if canon_for_species.empty?
          new_list << cur
          next
        end
        same = canon_for_species.any? { |ce| ce[:method] == cur[:method] && ce[:param].to_s == cur[:param].to_s }
        next if same
        changed_list << { :species => cur[:species], :from => canon_for_species[0], :to => cur }
      end
      return { :new => new_list, :changed => changed_list, :canon => canon_list }
    end

    def has_evolution_method_changes?(species_data, canon)
      data = evolution_method_change_data(species_data, canon)
      return !data[:new].empty? || !data[:changed].empty?
    end

    def show_evolution_method_window(species, form)
      return if species.nil?
      canon = VermeilChangeDex.get_canon_info(species, form)
      species_data = GameData::Species.get_species_form(species, form)
      evo_data = evolution_method_change_data(species_data, canon)
      return if evo_data[:new].empty? && evo_data[:changed].empty?
      lines = []
      if !evo_data[:new].empty?
        lines << _INTL("New Evolution Methods:")
        evo_data[:new].each do |evo|
          method_txt = changedex_evo_method_short_label(evo[:method], evo[:param])
          if !$player || !$player.seen?(evo[:species])
            lines << _INTL("??? evolves via {1}", method_txt)
          else
            evo_name = GameData::Species.get(evo[:species]).name
            lines << _INTL("{1} evolves via {2}", evo_name, method_txt)
          end
        end
      end
      if !evo_data[:changed].empty?
        lines << "" if !lines.empty?
        lines << _INTL("Changed Evolution Methods:")
        evo_data[:changed].each do |chg|
          evo_name = GameData::Species.get(chg[:species]).name
          old_m = changedex_evo_method_short_label(chg[:from][:method], chg[:from][:param])
          new_m = changedex_evo_method_short_label(chg[:to][:method], chg[:to][:param])
          lines << _INTL("{1}: {2} -> {3}", evo_name, old_m, new_m)
        end
      end
      if evo_data[:changed].empty? && !evo_data[:canon].empty?
        lines << "" if !lines.empty?
        lines << _INTL("Canon Evolutions:")
        evo_data[:canon].each do |evo|
          evo_name = GameData::Species.get(evo[:species]).name
          method_txt = changedex_evo_method_short_label(evo[:method], evo[:param])
          lines << _INTL("{1} evolves via {2}", evo_name, method_txt)
        end
      end
      lines = [_INTL("No evolution methods found for this Pokémon.")] if lines.empty?
      show_evolution_method_popup(lines)
    end

    def show_evolution_method_popup(lines)
      hide_evolution_method_popup
      @sprites["evo_method_popup"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["evo_method_popup"].z = 260
      bmp = @sprites["evo_method_popup"].bitmap
      pbSetSystemFont(bmp)
      panel_x = 38
      panel_y = 86
      panel_w = SCREEN_W - 76
      panel_h = 188
      # Higher-opacity popup panel for readability over dense UI content.
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(20, 28, 40, 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      title = _INTL("Evolution Methods")
      pbDrawTextPositions(bmp, [[title, panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      y = panel_y + 36
      max_w = panel_w - 24
      lines.each do |line|
        if line.to_s.empty?
          y += 14
          next
        end
        color = line.to_s.end_with?(":") ? COLOR_HIGHLIGHT : COLOR_TEXT_MAIN
        used = draw_wrapped_text(bmp, line, panel_x + 12, y, max_w, color, 24, 2)
        y += (used * 24) + 4
        break if y > panel_y + panel_h - 30
      end
      pbDrawTextPositions(bmp, [[_INTL("{1}/{2}: Close", @action_key_name, "X"), panel_x + panel_w - 12, panel_y + panel_h - 24, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      @evo_popup_open = true
    end

    def hide_evolution_method_popup
      @evo_popup_open = false
      if @sprites["evo_method_popup"]
        @sprites["evo_method_popup"].dispose
        @sprites.delete("evo_method_popup")
      end
    end

    def find_entry_index(search_text)
      query = search_text.to_s.strip
      return nil if query.empty?
      if query[/^\d+$/]
        wanted_dex = query.to_i
        return @entries.index { |sp, _f| (@dex_order[sp] || 0) == wanted_dex }
      end
      down = query.downcase
      @entries.each_with_index do |entry, i|
        sp = entry[0]; f = entry[1]
        s_data = GameData::Species.get_species_form(sp, f)
        next if !s_data
        candidates = [s_data.name, s_data.species.to_s]
        candidates.push(s_data.form_name) if s_data.form_name && !s_data.form_name.empty?
        return i if candidates.any? { |txt| txt.to_s.downcase.include?(down) }
      end
      return nil
    end

    def open_search
      query = pbMessageFreeText(_INTL("Search Pokémon (name or Dex number)."), "", false, 32, 240)
      return if !query || query.strip.empty?
      found_index = find_entry_index(query)
      if found_index
        old_page = @index / GRID_PAGE_SIZE
        @index = found_index
        pbPlayCursorSE
        (@index / GRID_PAGE_SIZE != old_page) ? draw_grid_interface : refresh_cursor
      else
        pbPlayBuzzerSE
        pbMessage(_INTL("No matching Pokémon found in Change Dex."))
      end
    end

    def pbStartScene
      pbFadeOutIn do
        @sprites["bg"] = IconSprite.new(0, 0, @viewport)
        @sprites["bg"].bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
        @sprites["bg"].bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, COLOR_BG); @sprites["bg"].z = 10
        @sprites["grid_bg"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @sprites["grid_bg"].z = 50
        @sprites["overlay"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @sprites["overlay"].z = 200; pbSetSystemFont(@sprites["overlay"].bitmap)
        @entries.empty? ? draw_header("CHANGE DEX", "No changes detected") : draw_grid_interface
        pbUpdate
      end
    end

    def draw_grid_interface
      @sprites["overlay"].bitmap.clear; draw_header("CHANGE DEX", "")
      grid_bmp = @sprites["grid_bg"].bitmap
      grid_bmp.clear
      GRID_ROWS.times do |row|
        GRID_COLS.times do |col|
          gx = GRID_X + (col * GRID_CELL) + 3
          gy = GRID_Y + (row * GRID_CELL) + 3
          gw = GRID_CELL - 6
          gh = GRID_CELL - 6
          grid_bmp.fill_rect(gx, gy, gw, gh, COLOR_GRID_FILL)
          grid_bmp.fill_rect(gx, gy, gw, 1, COLOR_GRID_EDGE)
          grid_bmp.fill_rect(gx, gy + gh - 1, gw, 1, COLOR_GRID_EDGE)
          grid_bmp.fill_rect(gx, gy, 1, gh, COLOR_GRID_EDGE)
          grid_bmp.fill_rect(gx + gw - 1, gy, 1, gh, COLOR_GRID_EDGE)
        end
      end
      # Stronger footer opacity for readable names over dense icon rows.
      @sprites["overlay"].bitmap.fill_rect(0, 340, SCREEN_W, 44, Color.new(0, 0, 0, 236))
      @sprites["overlay"].bitmap.fill_rect(0, 338, SCREEN_W, 2, COLOR_HIGHLIGHT)
      @sprites["overlay"].bitmap.fill_rect((SCREEN_W / 2) - 112, 342, 224, 38, Color.new(12, 16, 24, 210))
      @evo_mark_base_y = {}
      @sprites.keys.each do |k|
        if k.to_s.include?("icon_") || k.to_s.include?("evo_mark_") || k == "cursor" ||
           k == "scroll_up" || k == "scroll_down"
          @sprites[k].dispose
          @sprites.delete(k)
        end
      end
      if !@entries.empty?
        @sprites["cursor"] = BitmapSprite.new(80, 80, @viewport); @sprites["cursor"].z = 150
        bmp = @sprites["cursor"].bitmap; bmp.fill_rect(0, 0, 80, 80, Color.new(220, 60, 60, 60))
        [0, 76].each { |y| bmp.fill_rect(0, y, 80, 4, COLOR_HIGHLIGHT) }
        [0, 76].each { |x| bmp.fill_rect(x, 0, 4, 80, COLOR_HIGHLIGHT) }
      end
      start_idx = (@index / GRID_PAGE_SIZE).floor * GRID_PAGE_SIZE
      (start_idx...start_idx + GRID_PAGE_SIZE).each_with_index do |real_idx, i|
        next if real_idx >= @entries.length
        sp, f = @entries[real_idx]; s = PokemonSpeciesIconSprite.new(nil, @viewport)
        s.setOffset(PictureOrigin::CENTER); s.z = 100
        s.x = GRID_X + ((i % GRID_COLS) * GRID_CELL) + (GRID_CELL / 2)
        s.y = GRID_Y + ((i / GRID_COLS) * GRID_CELL) + (GRID_CELL / 2)
        s.pbSetParams(sp, 0, f, false); @sprites["icon_#{real_idx}"] = s
        # Force true center origin in grid cells (default CENTER uses 5/8 y-origin).
        s.ox = s.src_rect.width / 2
        s.oy = s.src_rect.height / 2
        if @entry_gained_evos[[sp, f]] && !@entry_gained_evos[[sp, f]].empty?
          mark = IconSprite.new(0, 0, @viewport)
          mark.setBitmap("Graphics/UI/EvoIcon")
          mark.x = s.x + 6
          mark.y = s.y - 32
          mark.z = 130
          key = "evo_mark_#{real_idx}"
          @sprites[key] = mark
          @evo_mark_base_y[key] = mark.y
        end
      end
      # Preview next page in 4th row with lower opacity.
      preview_start = start_idx + GRID_PAGE_SIZE
      (preview_start...preview_start + GRID_COLS).each_with_index do |real_idx, i|
        next if real_idx >= @entries.length
        sp, f = @entries[real_idx]; s = PokemonSpeciesIconSprite.new(nil, @viewport)
        s.setOffset(PictureOrigin::CENTER); s.z = 90
        s.x = GRID_X + (i * GRID_CELL) + (GRID_CELL / 2)
        s.y = GRID_Y + ((GRID_ROWS - 1) * GRID_CELL) + (GRID_CELL / 2)
        s.pbSetParams(sp, 0, f, false); @sprites["icon_#{real_idx}"] = s
        s.ox = s.src_rect.width / 2
        s.oy = s.src_rect.height / 2
        s.opacity = 130
      end
      draw_grid_scroll_hints
      refresh_cursor
    end

    def draw_grid_scroll_hints
      @scroll_arrow_base = {}
      @sprites["scroll_up"] = IconSprite.new(0, 0, @viewport)
      @sprites["scroll_up"].setBitmap("Graphics/UI/up_arrow")
      @sprites["scroll_up"].src_rect.set(0, 0, 28, 40)
      @sprites["scroll_up"].z = 215
      @sprites["scroll_up"].x = SCREEN_W - @sprites["scroll_up"].src_rect.width - 4
      @sprites["scroll_up"].y = GRID_Y - 10
      @sprites["scroll_up"].opacity = grid_can_scroll_up? ? 255 : 110
      @scroll_arrow_base["scroll_up"] = @sprites["scroll_up"].y

      @sprites["scroll_down"] = IconSprite.new(0, 0, @viewport)
      @sprites["scroll_down"].setBitmap("Graphics/UI/down_arrow")
      @sprites["scroll_down"].src_rect.set(0, 0, 28, 40)
      @sprites["scroll_down"].z = 215
      @sprites["scroll_down"].x = SCREEN_W - @sprites["scroll_down"].src_rect.width - 4
      @sprites["scroll_down"].y = GRID_Y + (GRID_CELL * GRID_ROWS) - 82
      @sprites["scroll_down"].opacity = grid_can_scroll_down? ? 255 : 110
      @scroll_arrow_base["scroll_down"] = @sprites["scroll_down"].y
    end

    def update_scroll_arrow_animation
      return if !@scroll_arrow_base || @scroll_arrow_base.empty?
      t = System.uptime
      bob = (Math.sin(t * 6.0) * 2.0).round
      pulse = (Math.sin(t * 8.0) * 18.0).round

      up = @sprites["scroll_up"]
      if up && !up.disposed?
        can = grid_can_scroll_up?
        up.y = @scroll_arrow_base["scroll_up"].to_i + (can ? -bob : 0)
        up.opacity = can ? [[235 + pulse, 180].max, 255].min : 110
      end

      down = @sprites["scroll_down"]
      if down && !down.disposed?
        can = grid_can_scroll_down?
        down.y = @scroll_arrow_base["scroll_down"].to_i + (can ? bob : 0)
        down.opacity = can ? [[235 + pulse, 180].max, 255].min : 110
      end
    end

    def grid_can_scroll_up?
      return false if @entries.empty?
      return (@index / GRID_PAGE_SIZE) > 0
    end

    def grid_can_scroll_down?
      return false if @entries.empty?
      return (((@index / GRID_PAGE_SIZE) + 1) * GRID_PAGE_SIZE) < @entries.length
    end

    def update_evo_mark_animation
      return if !@evo_mark_base_y || @evo_mark_base_y.empty?
      bob = Math.sin(System.uptime * 6.0) * 2.0
      @evo_mark_base_y.each do |k, base_y|
        spr = @sprites[k]
        next if !spr || spr.disposed?
        spr.y = (base_y + bob).round
      end
    end

    def move_cursor(dx, dy)
      return if @entries.empty?
      old_idx = @index
      page = (@index / GRID_PAGE_SIZE)
      in_page = @index - (page * GRID_PAGE_SIZE)
      if dy != 0 && dx == 0
        col = in_page % GRID_COLS
        row = in_page / GRID_COLS
        if dy > 0 && row >= (GRID_ACTIVE_ROWS - 1)
          # From last active row, moving down pages forward.
          target_page = page + 1
          target_idx = (target_page * GRID_PAGE_SIZE) + col
          if target_idx >= @entries.length
            # Fallback to nearest valid slot in next page.
            page_start = target_page * GRID_PAGE_SIZE
            return if page_start >= @entries.length
            target_idx = [page_start + GRID_COLS - 1, @entries.length - 1].min
          end
        elsif dy < 0 && row <= 0
          # From first active row, moving up pages backward.
          target_page = page - 1
          return if target_page < 0
          target_idx = (target_page * GRID_PAGE_SIZE) + ((GRID_ACTIVE_ROWS - 1) * GRID_COLS) + col
          if target_idx >= @entries.length
            target_idx = @entries.length - 1
          end
        else
          target_row = row + dy
          return if target_row < 0
          row_start = (page * GRID_PAGE_SIZE) + (target_row * GRID_COLS)
          target_idx = row_start + col
          if target_idx >= @entries.length
            if row_start >= @entries.length
              target_idx = @entries.length - 1 if dy > 0
            else
              row_end = [row_start + GRID_COLS - 1, @entries.length - 1].min
              target_idx = row_end
            end
          end
        end
        return if target_idx.nil? || target_idx < 0 || target_idx >= @entries.length
        @index = target_idx
      else
        # Horizontal movement confined to active rows in current page.
        new_idx = @index + dx + (dy * GRID_COLS)
        return if new_idx < 0 || new_idx >= @entries.length
        new_page = (new_idx / GRID_PAGE_SIZE)
        new_in_page = new_idx - (new_page * GRID_PAGE_SIZE)
        if new_page != page || (new_in_page / GRID_COLS) < GRID_ACTIVE_ROWS
          @index = new_idx
        else
          return
        end
      end
      return if @index == old_idx
      old_p = old_idx / GRID_PAGE_SIZE
      pbPlayCursorSE
      (@index / GRID_PAGE_SIZE != old_p) ? draw_grid_interface : refresh_cursor
    end

    def changedex_display_name(species, form)
      s_data = GameData::Species.get_species_form(species, form)
      return "" if !s_data
      base_name = s_data.name.to_s
      form_name = s_data.form_name.to_s.strip
      return base_name if form <= 0 || form_name.empty?
      return form_name if form_name.downcase.include?(base_name.downcase)
      return "#{form_name} #{base_name}"
    end

    def refresh_cursor
      return if @mode != :grid
      bmp = @sprites["overlay"].bitmap
      bmp.clear_rect(0, 338, SCREEN_W, 46)
      # Redraw full footer each refresh so Search/Filter always stay readable.
      bmp.fill_rect(0, 340, SCREEN_W, 44, Color.new(0, 0, 0, 236))
      bmp.fill_rect(0, 338, SCREEN_W, 2, COLOR_HIGHLIGHT)
      if @entries.empty?
        pbDrawTextPositions(bmp, [["No matches for current filter.", SCREEN_W / 2, 350, :center, COLOR_TEXT_GRAY, Color.new(0,0,0,160)],
                                  [_INTL("{1}: Search", @action_key_name), 8, 350, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,160)],
                                  [_INTL("{1}: Filter", @filter_key_name), SCREEN_W - 8, 350, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,160)]])
        return
      end
      return if !@sprites["cursor"]
      p_idx = @index % GRID_PAGE_SIZE
      @sprites["cursor"].x = GRID_X + ((p_idx % GRID_COLS) * GRID_CELL)
      @sprites["cursor"].y = GRID_Y + ((p_idx / GRID_COLS) * GRID_CELL)
      sp, f = @entries[@index]; name = changedex_display_name(sp, f)
      pbDrawTextPositions(bmp, [[name, SCREEN_W/2, 350, :center, COLOR_TEXT_MAIN, Color.new(0,0,0,160)],
                                [_INTL("{1}: Search", @action_key_name), 8, 350, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,160)],
                                [_INTL("{1}: Filter", @filter_key_name), SCREEN_W - 8, 350, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,160)]])
    end

    def switch_to_detail
      return if @entries.empty?
      @mode = :detail
      @sprites["grid_bg"].visible = false if @sprites["grid_bg"] && !@sprites["grid_bg"].disposed?
      @sprites.each do |k, v|
        if (k.to_s.include?("icon_") || k.to_s.include?("evo_mark_") || k == "cursor") && !v.disposed?
          v.visible = false
        end
      end
      draw_detail_view(@entries[@index][0], @entries[@index][1])
    end

    def switch_to_grid
      @mode = :grid
      @sprites["grid_bg"].visible = true if @sprites["grid_bg"] && !@sprites["grid_bg"].disposed?
      ["big_icon", "evo_label_overlay", "evo_method_popup"].each do |k|
        next if !@sprites[k]
        @sprites[k].dispose
        @sprites.delete(k)
      end
      @evo_popup_open = false
      @sprites.keys.each do |k|
        next if !k.to_s.start_with?("evo_detail_")
        @sprites[k].dispose
        @sprites.delete(k)
      end
      @sprites.each do |k, v|
        if !v.nil? && !v.disposed? && (k.to_s.include?("icon_") || k.to_s.include?("evo_mark_") || k == "cursor")
          v.visible = true
        end
      end
      draw_grid_interface
    end

    def draw_detail_view(species, form)
      bmp = @sprites["overlay"].bitmap; bmp.clear; canon = VermeilChangeDex.get_canon_info(species, form)
      @detail_species = species
      @detail_form = form
      vermeil = GameData::Species.get_species_form(species, form); draw_header("COMPARISON", changedex_display_name(species, form))
      @detail_has_evo_method_changes = has_evolution_method_changes?(vermeil, canon)
      # Block panels for clearer visual hierarchy.
      draw_panel(bmp, 10, 52, 150, 170)   # Left: sprite + typing
      draw_panel(bmp, 170, 52, 332, 174)  # Right: stat comparison
      @sprites["big_icon"] = PokemonSpeciesIconSprite.new(nil, @viewport)
      @sprites["big_icon"].setOffset(PictureOrigin::CENTER); @sprites["big_icon"].x, @sprites["big_icon"].y = LEFT_PANEL_CENTER_X, 92
      @sprites["big_icon"].z = 210; @sprites["big_icon"].pbSetParams(species, 0, form, false)
      
      # TYPE ICONS
      c_types = (canon[:types] || []).to_a; v_types = (vermeil.types || []).to_a; type_y = 126; type_center_x = LEFT_PANEL_CENTER_X
      if c_types.sort != v_types.sort && !c_types.empty?
        draw_type_icons(bmp, c_types, type_center_x, type_y, 150)
        pbDrawTextPositions(bmp, [["New Typing", type_center_x, type_y + 34, :center, COLOR_TEXT_MAIN, Color.new(0,0,0,100)]])
        draw_type_icons(bmp, v_types, type_center_x, type_y + 58)
      else
        draw_type_icons(bmp, v_types, type_center_x, type_y + 24)
      end

      # STATS LAYOUT (Lowered and Spaced)
      v_raw = vermeil.base_stats.values; v_stats = [v_raw[0], v_raw[1], v_raw[2], v_raw[5], v_raw[3], v_raw[4]]
      c_stats = canon[:stats]
      has_new_evos = !gained_evolution_species(vermeil, canon).empty?
      x_base = has_new_evos ? 186 : 220
      y_base = 95
      pbDrawTextPositions(bmp, [["Original", x_base + 58, y_base - 30, :center, COLOR_CANON], ["Vermeil", x_base + 152, y_base - 30, :center, COLOR_VERMEIL]])
      draw_new_evolution_icons(species, form, canon, x_base, y_base)
      ["HP","ATK","DEF","SPE","SPA","SPD"].each_with_index do |lbl, i|
        yy = y_base + (i*22); c_v = c_stats[i] || 0; v_v = v_stats[i]
        pbDrawTextPositions(bmp, [[lbl, x_base, yy, :left, COLOR_TEXT_GRAY], [c_v.to_s, x_base + 65, yy, :center, COLOR_CANON], [v_v.to_s, x_base + 145, yy, :center, (v_v != c_v ? COLOR_DIFF : COLOR_TEXT_MAIN)]])
        if v_v != c_v
          diff = v_v - c_v; txt = (diff > 0 ? "+#{diff}" : "#{diff}")
          pbDrawTextPositions(bmp, [[txt, x_base + 172, yy, :left, (diff > 0 ? Color.new(100,255,100) : Color.new(255,100,100))]])
        end
      end
      
      # ABILITIES SECTION
      abilities_panel_y = 228
      draw_panel(bmp, 10, abilities_panel_y, 492, 74)
      pbDrawTextPositions(bmp, [["Abilities:", 20, abilities_panel_y + 9, :left, COLOR_HIGHLIGHT]])
      abilities_text_y = abilities_panel_y + 32
      abilities_end_y = abilities_text_y
      c_slots = build_ability_slots(canon[:abilities], canon[:hidden_abilities], true)
      v_slots = build_ability_slots(vermeil.abilities, vermeil.hidden_abilities, false)
      display_entries = build_display_ability_entries(c_slots, v_slots)
      if display_entries.empty?
        lines = draw_wrapped_text(bmp, "No changes detected in abilities.", 20, abilities_text_y, 470, COLOR_TEXT_GRAY, 22, 2)
        abilities_end_y = abilities_text_y + (lines * 22)
      else
        lines = draw_colored_ability_entries(bmp, display_entries, 20, abilities_text_y, 470, 22, 2)
        abilities_end_y = abilities_text_y + (lines * 22)
      end
      
      # MOVES SECTION
      v_moves = vermeil.moves.map { |m| m[1] }.uniq; c_pool = (canon[:level_moves] + canon[:tutor_moves] + canon[:egg_moves]).uniq
      moves_header_y = [296, abilities_end_y + 6].max
      draw_panel(bmp, 10, moves_header_y - 6, 492, 102)
      draw_new_moves(bmp, (v_moves - c_pool).map { |m| GameData::Move.get(m).name }, moves_header_y)
      if @detail_has_evo_method_changes
        pbDrawTextPositions(bmp, [[_INTL("{1}: Evo Methods", @action_key_name), SCREEN_W / 2, 12, :center, Color.new(255,255,255), Color.new(0,0,0,120)]])
      end
    end

    def draw_new_moves(bmp, list, header_y = 296)
      y, max_w = header_y + 22, 470
      pbDrawTextPositions(bmp, [["New Moves:", 20, header_y, :left, COLOR_HIGHLIGHT]])
      if list.empty?; pbDrawTextPositions(bmp, [["No moves added to this Pokémon.", 20, y, :left, COLOR_TEXT_GRAY]]); return; end
      curr = ""; list.each do |m|
        test = curr + m + ", "; if bmp.text_size(test).width > max_w
          pbDrawTextPositions(bmp, [[curr, 20, y, :left, COLOR_MOVES_NEW]]); curr = m + ", "; y += 22
        else; curr = test; end
      end
      pbDrawTextPositions(bmp, [[curr.chomp(", "), 20, y, :left, COLOR_MOVES_NEW]])
    end

    def draw_wrapped_text(bmp, text, x, y, max_w, color, line_h = 22, max_lines = nil)
      words = text.to_s.split(/\s+/)
      return 0 if words.empty?
      line = ""
      lines = 0
      words.each do |w|
        candidate = (line.empty?) ? w : "#{line} #{w}"
        if bmp.text_size(candidate).width > max_w && !line.empty?
          if max_lines && lines >= max_lines - 1
            ell = line
            ell = ell[0...-1] while ell.length > 0 && bmp.text_size("#{ell}...").width > max_w
            pbDrawTextPositions(bmp, [["#{ell}...", x, y + (lines * line_h), :left, color]])
            return lines + 1
          end
          pbDrawTextPositions(bmp, [[line, x, y + (lines * line_h), :left, color]])
          lines += 1
          line = w
        else
          line = candidate
        end
      end
      if !line.empty?
        if max_lines && lines >= max_lines
          return lines
        end
        if max_lines && lines == max_lines - 1 && bmp.text_size(line).width > max_w
          ell = line
          ell = ell[0...-1] while ell.length > 0 && bmp.text_size("#{ell}...").width > max_w
          line = "#{ell}..."
        end
        pbDrawTextPositions(bmp, [[line, x, y + (lines * line_h), :left, color]])
        lines += 1
      end
      return lines
    end

    def draw_panel(bmp, x, y, w, h)
      bmp.fill_rect(x, y, w, h, COLOR_PANEL_FILL)
      bmp.fill_rect(x, y, w, 1, COLOR_PANEL_EDGE)
      bmp.fill_rect(x, y + h - 1, w, 1, COLOR_PANEL_EDGE)
      bmp.fill_rect(x, y, 1, h, COLOR_PANEL_EDGE)
      bmp.fill_rect(x + w - 1, y, 1, h, COLOR_PANEL_EDGE)
    end

    def ability_name_from_id(ability_id, use_try = true)
      return nil if ability_id.nil? || ability_id == :NONE
      if use_try
        return GameData::Ability.try_get(ability_id)&.name || ability_id.to_s
      end
      return GameData::Ability.get(ability_id).name
    rescue StandardError
      return ability_id.to_s
    end

    def build_ability_slots(abilities, hidden_abilities, use_try = true)
      ret = {}
      (abilities || []).each_with_index do |ab, i|
        next if ab.nil? || ab == :NONE
        ret["(#{i + 1})"] = ability_name_from_id(ab, use_try)
      end
      (hidden_abilities || []).each_with_index do |ab, i|
        next if ab.nil? || ab == :NONE
        key = (i == 0) ? "(HA)" : "(HA#{i + 1})"
        ret[key] = ability_name_from_id(ab, use_try)
      end
      return ret
    end

    def ability_slot_sort_key(label)
      return [0, $1.to_i] if label[/^\((\d+)\)$/]
      return [1, 1] if label == "(HA)"
      return [1, $1.to_i] if label[/^\(HA(\d+)\)$/]
      return [2, label.to_s]
    end

    def build_display_ability_entries(c_slots, v_slots)
      labels = (c_slots.keys + v_slots.keys).uniq.sort_by { |k| ability_slot_sort_key(k) }
      by_key = {}
      order = []
      labels.each do |slot|
        c_name = c_slots[slot]
        v_name = v_slots[slot]
        next if !v_name || v_name.empty?
        changed = (c_name != v_name)
        name = v_name.to_s.strip
        key = name.downcase
        if !by_key.key?(key)
          by_key[key] = { :text => name, :changed => changed }
          order << key
        else
          by_key[key][:changed] ||= changed
        end
      end
      entries = []
      order.each do |key|
        entries << {
          :text  => by_key[key][:text],
          :color => (by_key[key][:changed] ? COLOR_DIFF : COLOR_TEXT_MAIN)
        }
      end
      return entries
    end

    def draw_colored_ability_entries(bmp, entries, x, y, max_w, line_h = 22, max_lines = 2)
      return 0 if !entries || entries.empty?
      line = 0
      cursor_x = x
      entries.each_with_index do |entry, i|
        token = entry[:text]
        token += ", " if i < entries.length - 1
        w = bmp.text_size(token).width
        if cursor_x > x && cursor_x + w > x + max_w
          line += 1
          break if line >= max_lines
          cursor_x = x
        end
        break if line >= max_lines
        pbDrawTextPositions(bmp, [[token, cursor_x, y + (line * line_h), :left, entry[:color]]])
        cursor_x += w
      end
      drawn_count = 0
      # Recount how many entries were drawn to decide whether to add "+N more"
      line = 0
      cursor_x = x
      entries.each_with_index do |entry, i|
        token = entry[:text]
        token += ", " if i < entries.length - 1
        w = bmp.text_size(token).width
        if cursor_x > x && cursor_x + w > x + max_w
          line += 1
          break if line >= max_lines
          cursor_x = x
        end
        break if line >= max_lines
        drawn_count += 1
        cursor_x += w
      end
      hidden = entries.length - drawn_count
      if hidden > 0
        suffix = " +#{hidden} more"
        s_w = bmp.text_size(suffix).width
        if cursor_x + s_w > x + max_w
          line += 1
          if line < max_lines
            cursor_x = x
          else
            line -= 1
            cursor_x = [x, (x + max_w - s_w)].max
          end
        end
        pbDrawTextPositions(bmp, [[suffix, cursor_x, y + (line * line_h), :left, COLOR_TEXT_GRAY]])
      end
      used_lines = [1, [max_lines, line + 1].min].max
      return used_lines
    end

    def draw_new_evolution_icons(species, form, canon, x_base, y_base)
      @sprites.keys.each do |k|
        next if !k.to_s.start_with?("evo_detail_")
        @sprites[k].dispose
        @sprites.delete(k)
      end
      if @sprites["evo_label_overlay"]
        @sprites["evo_label_overlay"].dispose
        @sprites.delete("evo_label_overlay")
      end
      species_data = GameData::Species.get_species_form(species, form)
      gained = gained_evolution_data(species_data, canon)
      return if gained.empty?
      label = (gained.length > 1) ? "New Evos" : "New Evo"
      label_x = x_base + 214
      label_y = y_base - 30
      @sprites["evo_label_overlay"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["evo_label_overlay"].z = 220
      pbSetSystemFont(@sprites["evo_label_overlay"].bitmap)
      pbDrawTextPositions(@sprites["evo_label_overlay"].bitmap, [[label, label_x, label_y, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      icon_x = label_x + 38
      icon_y = y_base + 26
      gained.each_with_index do |evo_data, i|
        evo_species = evo_data[:species]
        spr = PokemonSpeciesIconSprite.new(nil, @viewport)
        spr.setOffset(PictureOrigin::CENTER)
        spr.x = icon_x
        spr.y = icon_y + (i * 40)
        # Keep evo icons above UI panel but below the dedicated New Evo label.
        spr.z = 210
        spr.pbSetParams(evo_species, 0, 0, false)
        if !$player || !$player.seen?(evo_species)
          spr.tone = Tone.new(-255, -255, -255)
          spr.color = Color.new(0, 0, 0, 180)
        end
        @sprites["evo_detail_#{i}"] = spr
      end
    end

    def draw_type_icons(bmp, types, center_x, y, opacity = 255)
      return if types.nil? || types.empty?
      icon_w = 64; icon_h = 28; gap = 6
      total_w = (icon_w * types.length) + (gap * (types.length - 1))
      x = center_x - (total_w / 2)
      types.each do |type|
        type_number = GameData::Type.get(type).icon_position
        type_rect = Rect.new(0, type_number * icon_h, icon_w, icon_h)
        bmp.blt(x, y, @typebitmap.bitmap, type_rect, opacity)
        x += icon_w + gap
      end
    end

    def draw_header(t1, t2)
      @sprites["overlay"].bitmap.fill_rect(0, 0, SCREEN_W, 44, Color.new(180, 40, 50))
      @sprites["overlay"].bitmap.fill_rect(0, 42, SCREEN_W, 2, Color.new(255, 255, 255, 100))
      pbDrawTextPositions(@sprites["overlay"].bitmap, [[t1, 20, 12, :left, Color.new(255,255,255)], [t2, SCREEN_W-20, 12, :right, Color.new(255,255,255)]])
    end

    def pbMain
      loop do
        Graphics.update; Input.update; pbUpdate
        if @mode == :grid
          if Input.trigger?(Input::SPECIAL)
            open_filter_menu
            next
          end
          if Input.trigger?(Input::ACTION)
            open_search
            next
          end
          if Input.trigger?(Input::USE)
            switch_to_detail
            next
          end
          move_cursor(-1, 0) if Input.repeat?(Input::LEFT); move_cursor(1, 0) if Input.repeat?(Input::RIGHT)
          move_cursor(0, -1) if Input.repeat?(Input::UP); move_cursor(0, 1) if Input.repeat?(Input::DOWN)
          break if Input.trigger?(Input::BACK)
        else
          if @evo_popup_open
            if Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
              hide_evolution_method_popup
            end
            next
          end
          if Input.trigger?(Input::ACTION)
            if @detail_has_evo_method_changes
              show_evolution_method_window(@detail_species, @detail_form)
            else
              pbPlayBuzzerSE
            end
            next
          end
          switch_to_grid if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        end
      end
    end

    def pbUpdate
      pbUpdateSpriteHash(@sprites)
      update_evo_mark_animation if @mode == :grid
      update_scroll_arrow_animation if @mode == :grid
    end
    def pbEndScene
      pbFadeOutIn do
        pbDisposeSpriteHash(@sprites)
        @viewport.dispose
        @typebitmap.dispose if @typebitmap
      end
    end
  end

  def self.open; scene = Scene.new; scene.pbStartScene; scene.pbMain; scene.pbEndScene; end
end

ItemHandlers::UseInField.add(:CHANGEDEX, proc { |item| VermeilChangeDex.open; next true })
