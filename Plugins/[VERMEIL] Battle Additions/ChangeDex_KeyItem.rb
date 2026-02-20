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
  SHOW_DETAIL_VARIANT_ACTION = false
  FORCE_VISIBLE_HIDDEN_VARIANT_SPECIES = [
    :PIKACHU, :PICHU, :KOFFING, :PETILIL, :OSHAWOTT, :ROWLETT, :CYNDAQUIL,
    :DEWOTT, :QUILAVA, :DARTRIX, :GOOMY, :RUFFLET, :BERGMITE
  ]
  REWORKED_ABILITIES = [:NORMALIZE, :ICEBODY, :BULLETPROOF, :SOLARPOWER, :ILLUMINATE, :CORROSION]
  TORQUE_MOVE_IDS = [:BLAZINGTORQUE, :NOXIOUSTORQUE, :COMBATTORQUE, :MAGICALTORQUE, :WICKEDTORQUE]
  LETSGO_EXCLUSIVE_MOVE_IDS = [:ZIPPYZAP, :SPLISHYSPLASH, :FLOATYFALL, :BOUNCYBUBBLE, :BUZZYBUZZ,
                               :SIZZLYSLIDE, :GLITZYGLOW, :BADDYBAD, :SAPPYSEED, :FREEZYFROST,
                               :SPARKLYSWIRL]
  EXCLUSIVE_GLOBALIZED_FILTER_EXCLUDED_IDS = [
    :AROMATHERAPY, :ASSIST, :BARRAGE, :BARRIER, :BESTOW, :BIDE, :BUBBLE, :CAMOUFLAGE,
    :CAPTIVATE, :CHIPAWAY, :CLAMP, :COMETPUNCH, :CONSTRICT, :DIZZYPUNCH, :DOUBLESLAP,
    :DRAGONRAGE, :DUALCHOP, :EGGBOMB, :EMBARGO, :FEINTATTACK, :FLAMEBURST, :FLASH,
    :FLOWERSHIELD, :FORESIGHT, :FRUSTRATION, :GRASSWHISTLE, :HAIL, :HEALBLOCK,
    :HIDDENPOWER, :IONDELUGE, :JUMPKICK, :KARATECHOP, :LOVELYKISS, :LUCKYCHANT,
    :MAGICCOAT, :MAGNETBOMB, :MAGNITUDE, :MEDITATE, :MEFIRST, :MINDREADER, :MIRACLEEYE,
    :MIRRORMOVE, :MIRRORSHOT, :MUDSPORT, :NATURALGIFT, :NIGHTMARE, :ODORSLEUTH,
    :OMINOUSWIND, :PLAYNICE, :PSYCHOSHIFT, :PSYWAVE, :PUNISHMENT, :PURSUIT, :RAGE,
    :RAZORWIND, :REFRESH, :RETURN, :ROCKCLIMB, :ROLLINGKICK, :ROTOTILLER, :SECRETPOWER,
    :SHARPEN, :SIGNALBEAM, :SILVERWIND, :SKYDROP, :SKYUPPERCUT, :SMELLINGSALTS,
    :SNATCH, :SONICBOOM, :SPIDERWEB, :SPIKECANNON, :SPOTLIGHT, :STEAMROLLER,
    :SUBMISSION, :SYNCHRONOISE, :TELEKINESIS, :TRUMPCARD, :VITALTHROW, :WAKEUPSLAP,
    :WATERSPORT, :WRINGOUT,
    :BONECLUB, :TWINEEDLE, :NEEDLEARM, :MATBLOCK, :VOLTTACKLE
  ]
  REWORKED_ABILITY_BEFORE_TEXT = {
    :NORMALIZE   => "All the Pokemon's moves become the Normal type.",
    :ICEBODY     => "The Pokemon gradually regains HP in a hailstorm.",
    :BULLETPROOF => "Protects the Pokemon from some ball and bomb moves.",
    :SOLARPOWER  => "In sunshine, Sp. Atk is boosted but HP decreases.",
    :ILLUMINATE  => "Prevents other Pokemon from lowering accuracy.",
    :CORROSION   => "It can poison Steel- and Poison-type targets."
  }

  @canon_cache = {}
  @canon_move_data = nil
  @custom_move_ids = nil
  @custom_ability_ids = nil
  @detect_cache = nil
  DETECT_CACHE_VERSION = 14

  def self.detect_cache
    return @detect_cache
  end

  def self.detect_cache=(value)
    @detect_cache = value
  end

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

  def self.canon_known_moves
    load_canon_data if @canon_cache.empty?
    pool = []
    @canon_cache.each_value do |forms|
      next if !forms
      forms.each_value do |data|
        next if !data
        pool.concat(data[:level_moves] || [])
        pool.concat(data[:tutor_moves] || [])
        pool.concat(data[:egg_moves] || [])
      end
    end
    return pool.compact.uniq
  end

  def self.canon_known_abilities
    load_canon_data if @canon_cache.empty?
    pool = []
    @canon_cache.each_value do |forms|
      next if !forms
      forms.each_value do |data|
        next if !data
        pool.concat(data[:abilities] || [])
        pool.concat(data[:hidden_abilities] || [])
      end
    end
    return pool.compact.reject { |a| a == :NONE }.uniq
  end

  def self.load_canon_move_data
    return if !@canon_move_data.nil?
    @canon_move_data = {}
    canon_move_paths = []
    canon_move_paths.concat(Dir.glob("CanonData/moves*.txt"))
    canon_move_paths.concat(["CanonData/moves.txt", "CanonData/moves_Gen_9_Pack.txt", "CanonData/moves_LetsGo.txt"])
    canon_move_paths = canon_move_paths.compact.uniq
    canon_move_paths.each do |path|
      resolved = resolve_existing_path(path)
      next if !resolved
      current_id = nil
      File.open(resolved, "r:utf-8") do |f|
        f.each_line do |line|
          clean = line.to_s.strip.split("#")[0]
          next if clean.nil? || clean.empty?
          if clean[/^\[([^\]]+)\]$/]
            current_id = $1.strip.to_sym
            @canon_move_data[current_id] ||= {
              :type => nil,
              :dmg_class => nil,
              :power => nil,
              :accuracy => nil,
              :total_pp => nil,
              :priority => nil,
              :function => nil,
              :effect_chance => nil,
              :flags => []
            }
            next
          end
          next if current_id.nil?
          if clean[/^Type\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:type] = $1.strip.to_sym
          elsif clean[/^Category\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:dmg_class] = $1.to_s.strip.downcase.to_sym
          elsif clean[/^Power\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:power] = $1.to_s.strip.to_i
          elsif clean[/^Accuracy\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:accuracy] = $1.to_s.strip.to_i
          elsif clean[/^TotalPP\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:total_pp] = $1.to_s.strip.to_i
          elsif clean[/^Priority\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:priority] = $1.to_s.strip.to_i
          elsif clean[/^FunctionCode\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:function] = $1.to_s.strip
          elsif clean[/^EffectChance\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:effect_chance] = $1.to_s.strip.to_i
          elsif clean[/^Flags\s*=\s*(.*)$/i]
            flags = $1.to_s.split(",").map { |s| s.to_s.strip }.reject { |s| s.empty? }
            @canon_move_data[current_id][:flags] = flags
          end
        end
      end
    end
  end

  def self.canon_move_type(move_id)
    load_canon_move_data
    data = @canon_move_data[move_id]
    return nil if !data
    return data[:type]
  end

  def self.canon_move_entry(move_id)
    load_canon_move_data
    return @canon_move_data[move_id]
  end

  def self.canon_move_flags(move_id)
    load_canon_move_data
    data = @canon_move_data[move_id]
    return [] if !data
    return data[:flags] || []
  end

  def self.resolve_existing_path(path)
    candidates = [
      path,
      File.join(".", path),
      File.join("..", path),
      File.join("..", "..", path)
    ].uniq
    candidates.each do |p|
      return p if File.file?(p)
    end
    return nil
  end

  def self.read_ids_from_pbs(path)
    ids = []
    resolved = resolve_existing_path(path)
    return ids if !resolved
    File.open(resolved, "r:utf-8") do |f|
      f.each_line do |line|
        next if !line
        clean = line.strip
        next if clean.empty?
        next if clean.start_with?("#")
        if clean[/^\[([^\]]+)\]$/]
          ids << $1.strip.to_sym
        end
      end
    end
    return ids.uniq
  rescue StandardError
    return []
  end

  def self.custom_move_ids
    if @custom_move_ids.nil?
      @custom_move_ids = read_ids_from_pbs("PBS/moves_Vermeil.txt")
    end
    return @custom_move_ids
  end

  def self.custom_ability_ids
    if @custom_ability_ids.nil?
      @custom_ability_ids = read_ids_from_pbs("PBS/abilities_Vermeil.txt")
    end
    return @custom_ability_ids
  end

  def self.reworked_abilities
    return REWORKED_ABILITIES
  end

  def self.reworked_ability_before_text(ability_id)
    return REWORKED_ABILITY_BEFORE_TEXT[ability_id]
  end

  def self.torque_move?(move_id)
    return TORQUE_MOVE_IDS.include?(move_id)
  end

  def self.reworked_move_before_text(move_id)
    return "Starmobile-exclusive move." if torque_move?(move_id)
    return "Let's Go-exclusive move." if LETSGO_EXCLUSIVE_MOVE_IDS.include?(move_id)
    return nil
  end

  class Scene
    def initialize
      @mode = :grid; @index = 0; @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999; @sprites = {}; @entries = []
      @typebitmap = AnimatedBitmap.new(_INTL("Graphics/UI/types"))
      @action_key_name = resolve_input_name(Input::ACTION, "Z")
      @filter_key_name = resolve_input_name(Input::SPECIAL, "Special")
      @use_key_name = resolve_input_name(Input::USE, "C")
      @jump_up_input = defined?(Input::JUMPUP) ? Input::JUMPUP : nil
      @jump_down_input = defined?(Input::JUMPDOWN) ? Input::JUMPDOWN : nil
      @category = :pokemon_changes
      @sort_mode = :dex
      @type_filter = :all
      @generation_filter = nil
      @entry_sort_mode = :az
      @entry_type_filter = :all
      @entry_damage_filter = :all
      @entry_exclusive_filter = :all
      @category_panel_open = false
      @category_panel_index = 0
      @startup_category_selection = true
      @category_exit_on_back = true
      @category_fullscreen = true
      @carrier_popup_open = false
      @carrier_popup_page = 0
      @carrier_popup_entry = nil
      @carrier_mark_base_y = {}
      @variant_mark_base_y = {}
      @detail_variant_mark_base_y = nil
      @ability_moves_popup_open = false
      @ability_moves_popup_page = 0
      @ability_moves_popup_lines = []
      @ability_moves_popup_title = "Boosted Moves"
      @ability_rework_popup_open = false
      @ability_rework_popup_page = 0
      @ability_rework_popup_lines = []
      @ability_rework_popup_title = "Before / After"
      @move_rework_popup_open = false
      @move_rework_popup_page = 0
      @move_rework_popup_lines = []
      @detail_form_options = [0]
      @detail_form_option_index = 0
      @detail_action_menu_open = false
      @detail_action_menu_index = 0
      @detail_action_menu_options = []
      @detail_variant_menu_open = false
      @detail_variant_menu_index = 0
      @detail_variant_menu_options = []
      @moves_popup_open = false
      @moves_popup_page = 0
      @detail_move_popup_lines = []
      @detail_moves_truncated = false
      @data_ready = false
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
      cached = VermeilChangeDex.detect_cache
      if cached && cached[:version] == VermeilChangeDex::DETECT_CACHE_VERSION
        @species_move_delta = cached[:species_move_delta].transform_values do |v|
          { :added => (v[:added] || []).clone, :added_tutor => (v[:added_tutor] || []).clone }
        end
        @species_ability_delta = cached[:species_ability_delta].transform_values { |v| { :added => (v[:added] || []).clone } }
        @noncanon_species_entries = cached[:noncanon_species_entries].clone
        @species_learnset_cache = cached[:species_learnset_cache].transform_values { |arr| (arr || []).clone }
        @entry_gained_evos = cached[:entry_gained_evos].transform_values { |arr| (arr || []).clone }
        @dex_order = cached[:dex_order].clone
        @entries = (cached[:entries] || []).map { |k| [k[0], k[1]] }
        @pokemon_entries = @entries.clone
        @all_entries = @pokemon_entries.clone
        @move_entries_all = clone_entry_list(cached[:move_entries_all] || [])
        @ability_entries_all = clone_entry_list(cached[:ability_entries_all] || [])
        @new_move_entries_all = clone_entry_list(cached[:new_move_entries_all] || [])
        @new_ability_entries_all = clone_entry_list(cached[:new_ability_entries_all] || [])
        @non_pokemon_indexes_ready = (!@move_entries_all.empty? || !@ability_entries_all.empty? ||
                                      !@new_move_entries_all.empty? || !@new_ability_entries_all.empty?)
        apply_current_filters
        return
      end
      @species_move_delta = {}
      @species_ability_delta = {}
      @noncanon_species_entries = {}
      @species_learnset_cache = {}
      @entry_gained_evos = {}
      @dex_order = {}
      dex_idx = 0
      GameData::Species.each_species do |base_species|
        dex_idx += 1
        @dex_order[base_species.species] = dex_idx
      end
      GameData::Species.each do |s|
        next if excluded_from_pokemon_changes?(s.species, s.form)
        # Collapse specific form families in Pokemon Changes:
        # - Always base form only for listed species.
        # - For Minior, show shell (form 0) and only first core form if core stats changed.
        next if base_only_form_family?(s.species) && s.form > 0
        if minior_core_form?(s.species, s.form)
          next if s.form > 1
          next if !minior_core_stats_changed?
        end
        v_abil = (s.abilities + s.hidden_abilities).compact.reject{|a| a == :NONE}.uniq.sort
        key = [s.species, s.form]
        # Keep Pokemon Changes stable: compare level-up and tutor learnsets separately.
        v_moves = s.moves.map { |m| m[1] }.uniq
        v_tutor_moves = (s.respond_to?(:tutor_moves) ? (s.tutor_moves || []).compact.uniq : [])
        # Carriers view uses full learnset (level + tutor + egg).
        @species_learnset_cache[key] = species_all_learnable_moves(s)
        canon = VermeilChangeDex.get_canon_info(s.species, s.form)
        # Forced hidden-variant entries compare against base form canon.
        if canon.nil? && force_visible_hidden_variant?(s.species, s.form)
          canon = VermeilChangeDex.get_canon_info(s.species, 0)
        end
        # Treat Unown alternate forms as base-form canon unless that form has its own
        # explicit canon block, to avoid counting every letter as a separate change.
        if canon.nil? && s.species == :UNOWN && s.form > 0
          canon = VermeilChangeDex.get_canon_info(s.species, 0)
        end
        if canon.nil?
          # Species/forms not in CanonData are treated as fully new for move/ability carriers.
          @noncanon_species_entries[key] = true
          @species_move_delta[key] = { :added => v_moves, :added_tutor => v_tutor_moves }
          @species_ability_delta[key] = { :added => v_abil }
          next
        end
        v_stats = species_stats_array(s)
        c_abil = (canon[:abilities] + canon[:hidden_abilities]).compact.reject{|a| a == :NONE}.uniq.sort
        v_types = (s.types || []).to_a.sort; c_types = (canon[:types] || []).to_a.sort
        c_pool = (canon[:level_moves] + canon[:tutor_moves] + canon[:egg_moves]).uniq
        c_tutor = (canon[:tutor_moves] || []).compact.uniq
        # If canonical movepool is missing/empty for this species, avoid false positives.
        new_moves = c_pool.empty? ? [] : (v_moves - c_pool)
        # Tutor move changes are isolated: tutor list vs tutor list.
        new_tutor_moves = (v_tutor_moves - c_tutor)
        @species_move_delta[key] = { :added => new_moves, :added_tutor => new_tutor_moves }
        @species_ability_delta[key] = { :added => (c_abil.empty? ? [] : (v_abil - c_abil)) }
        gained_evos = gained_evolution_species(s, canon)
        canon_has_stats = !canon[:stats].nil? && !canon[:stats].empty?
        canon_has_abilities = !c_abil.empty?
        canon_has_types = !c_types.empty?
        canon_has_moves = !c_pool.empty?
        if pumpkaboo_alt_form?(s.species, s.form) || arceus_alt_form?(s.species, s.form) || type_memory_alt_form?(s.species, s.form)
          next if !canon_has_stats || v_stats == canon[:stats]
        end
        has_change =
          (canon_has_stats && v_stats != canon[:stats]) ||
          (canon_has_abilities && v_abil != c_abil) ||
          (canon_has_types && v_types != c_types) ||
          (canon_has_moves && !new_moves.empty?) ||
          !new_tutor_moves.empty? ||
          !gained_evos.empty? ||
          force_visible_hidden_variant?(s.species, s.form)
        if has_change
          @entries.push(key)
          @entry_gained_evos[key] = gained_evos
        end
      end
      @entries.sort_by! { |k| [@dex_order[k[0]] || 999_999, k[1]] }
      @pokemon_entries = @entries.clone
      @all_entries = @pokemon_entries.clone
      @non_pokemon_indexes_ready = false
      VermeilChangeDex.detect_cache = {
        :version => VermeilChangeDex::DETECT_CACHE_VERSION,
        :species_move_delta => @species_move_delta.transform_values do |v|
          { :added => (v[:added] || []).clone, :added_tutor => (v[:added_tutor] || []).clone }
        end,
        :species_ability_delta => @species_ability_delta.transform_values { |v| { :added => (v[:added] || []).clone } },
        :noncanon_species_entries => @noncanon_species_entries.clone,
        :species_learnset_cache => @species_learnset_cache.transform_values { |arr| (arr || []).clone },
        :entry_gained_evos => @entry_gained_evos.transform_values { |arr| (arr || []).clone },
        :dex_order => @dex_order.clone,
        :entries => @entries.map { |k| [k[0], k[1]] },
        :move_entries_all => [],
        :ability_entries_all => [],
        :new_move_entries_all => [],
        :new_ability_entries_all => [],
        :non_pokemon_indexes_ready => false
      }
      apply_current_filters
    end

    def clone_entry_list(list)
      return [] if !list
      return list.map do |e|
        {
          :id => e[:id],
          :name => e[:name],
          :type => e[:type],
          :dmg_class => e[:dmg_class],
          :canon_user_count => e[:canon_user_count],
          :added_users => (e[:added_users] || []).map { |k| [k[0], k[1]] },
          :added_users_comparable => (e[:added_users_comparable] || []).map { |k| [k[0], k[1]] },
          :removed_users => (e[:removed_users] || []).map { |k| [k[0], k[1]] },
          :all_users => (e[:all_users] || []).map { |k| [k[0], k[1]] }
        }
      end
    end

    def species_stats_array(species_data)
      bs = species_data.base_stats || {}
      return [
        bs[:HP].to_i,
        bs[:ATTACK].to_i,
        bs[:DEFENSE].to_i,
        bs[:SPEED].to_i,
        bs[:SPECIAL_ATTACK].to_i,
        bs[:SPECIAL_DEFENSE].to_i
      ]
    end

    def species_all_learnable_moves(species_data)
      moves = []
      moves.concat(species_data.moves.map { |m| m[1] }.uniq) if species_data.respond_to?(:moves)
      moves.concat((species_data.tutor_moves || [])) if species_data.respond_to?(:tutor_moves)
      if species_data.respond_to?(:get_egg_moves)
        begin
          moves.concat((species_data.get_egg_moves || []))
        rescue StandardError
          # Ignore species/forms that cannot resolve inherited egg move chains.
        end
      elsif species_data.respond_to?(:egg_moves)
        moves.concat((species_data.egg_moves || []))
      end
      return moves.compact.uniq
    end

    def build_non_pokemon_indexes
      @canon_known_moves = VermeilChangeDex.canon_known_moves
      @canon_known_abilities = VermeilChangeDex.canon_known_abilities
      @custom_move_ids = VermeilChangeDex.custom_move_ids
      @custom_ability_ids = VermeilChangeDex.custom_ability_ids
      @reworked_ability_ids = VermeilChangeDex.reworked_abilities
      @move_entries_all = []
      @ability_entries_all = []
      @new_move_entries_all = []
      @new_ability_entries_all = []
      move_index = {}
      ability_index = {}
      all_move_users = {}
      all_ability_users = {}
      canon_move_users = {}
      GameData::Species.each do |s|
        key = [s.species, s.form]
        learnset = (@species_learnset_cache && @species_learnset_cache[key]) || species_all_learnable_moves(s)
        if !excluded_from_move_categories?(s.species, s.form)
          learnset.each do |move_id|
            all_move_users[move_id] ||= []
            all_move_users[move_id] << key unless all_move_users[move_id].include?(key)
          end
        end
        canon = VermeilChangeDex.get_canon_info(s.species, s.form)
        if canon.nil? && s.species == :UNOWN && s.form > 0
          canon = VermeilChangeDex.get_canon_info(s.species, 0)
        end
        if canon && !excluded_from_move_categories?(s.species, s.form)
          canon_pool = ((canon[:level_moves] || []) + (canon[:tutor_moves] || []) + (canon[:egg_moves] || [])).uniq
          canon_pool.each do |move_id|
            canon_move_users[move_id] ||= []
            canon_move_users[move_id] << key unless canon_move_users[move_id].include?(key)
          end
        end
        if !excluded_from_ability_categories?(s.species, s.form)
          (s.abilities + s.hidden_abilities).compact.reject { |a| a == :NONE }.uniq.each do |ability_id|
            all_ability_users[ability_id] ||= []
            all_ability_users[ability_id] << key unless all_ability_users[ability_id].include?(key)
          end
        end
      end
      (@species_move_delta || {}).each do |key, data|
        next if excluded_from_move_categories?(key[0], key[1])
        added_ids = ((data[:added] || []) + (data[:added_tutor] || [])).uniq
        added_ids.each do |move_id|
          move_index[move_id] ||= { :id => move_id, :added_users => [], :removed_users => [] }
          move_index[move_id][:added_users] << key unless move_index[move_id][:added_users].include?(key)
        end
      end
      (@species_ability_delta || {}).each do |key, data|
        next if excluded_from_ability_categories?(key[0], key[1])
        (data[:added] || []).each do |ability_id|
          ability_index[ability_id] ||= { :id => ability_id, :added_users => [], :removed_users => [] }
          ability_index[ability_id][:added_users] << key unless ability_index[ability_id][:added_users].include?(key)
        end
      end
      # Include globally reworked abilities even if no carriers changed.
      (@reworked_ability_ids || []).each do |ability_id|
        ability_index[ability_id] ||= { :id => ability_id, :added_users => [], :removed_users => [] }
      end
      move_index.each_value do |entry|
        m_data = GameData::Move.try_get(entry[:id])
        next if !m_data
        entry[:name] = m_data.name
        entry[:type] = m_data.type
        entry[:dmg_class] = move_damage_class(m_data)
        entry[:canon_user_count] = (canon_move_users[entry[:id]] || []).length
        entry[:added_users_comparable] = (entry[:added_users] || []).reject { |k| @noncanon_species_entries && @noncanon_species_entries[k] }
        entry[:all_users] = (all_move_users[entry[:id]] || []).sort_by { |k| [@dex_order[k[0]] || 999_999, k[1]] }
        @move_entries_all << entry
      end
      ability_index.each_value do |entry|
        a_data = GameData::Ability.try_get(entry[:id])
        next if !a_data
        entry[:name] = a_data.name
        entry[:added_users_comparable] = (entry[:added_users] || []).reject { |k| @noncanon_species_entries && @noncanon_species_entries[k] }
        entry[:all_users] = (all_ability_users[entry[:id]] || []).sort_by { |k| [@dex_order[k[0]] || 999_999, k[1]] }
        @ability_entries_all << entry
      end
      @new_move_entries_all = @move_entries_all.select do |e|
        !e[:added_users].empty? && (@custom_move_ids || []).include?(e[:id])
      end
      @new_ability_entries_all = @ability_entries_all.select do |e|
        !e[:added_users].empty? && (@custom_ability_ids || []).include?(e[:id])
      end
      cached = VermeilChangeDex.detect_cache
      if cached && cached[:version] == VermeilChangeDex::DETECT_CACHE_VERSION
        cached[:move_entries_all] = clone_entry_list(@move_entries_all || [])
        cached[:ability_entries_all] = clone_entry_list(@ability_entries_all || [])
        cached[:new_move_entries_all] = clone_entry_list(@new_move_entries_all || [])
        cached[:new_ability_entries_all] = clone_entry_list(@new_ability_entries_all || [])
        cached[:non_pokemon_indexes_ready] = true
        VermeilChangeDex.detect_cache = cached
      end
    end

    def current_category_title
      case @category
      when :pokemon_changes then "Pokemon Changes"
      when :move_changes    then "Move Changes"
      when :ability_changes then "Ability Changes"
      when :new_moves       then "New Moves"
      when :new_abilities   then "New Abilities"
      else "Change Dex"
      end
    end

    def pokemon_category?
      return @category == :pokemon_changes
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

    def base_only_form_family?(species)
      return [:CRAMORANT, :DUDUNSPARCE, :MAUSHOLD, :SINISTEA, :POLTEAGEIST, :POLTCHAGEIST, :SINISTCHA].include?(species)
    end

    def minior_core_form?(species, form)
      return species == :MINIOR && form > 0
    end

    def minior_core_stats_changed?
      return @minior_core_stats_changed if !@minior_core_stats_changed.nil?
      @minior_core_stats_changed = false
      GameData::Species.each do |s|
        next if s.species != :MINIOR || s.form <= 0
        canon = VermeilChangeDex.get_canon_info(:MINIOR, s.form)
        next if !canon || !canon[:stats] || canon[:stats].empty?
        if species_stats_array(s) != canon[:stats]
          @minior_core_stats_changed = true
          break
        end
      end
      return @minior_core_stats_changed
    end

    def mega_stone_for(species, form)
      return nil if !mega_form?(species, form)
      s_data = GameData::Species.get_species_form(species, form)
      return nil if !s_data || !s_data.respond_to?(:mega_stone)
      return s_data.mega_stone
    end

    def seen_species_form?(species, form)
      return false if !$player || !$player.respond_to?(:pokedex) || !$player.pokedex
      return false if !form || form <= 0
      return false if !$player.pokedex.respond_to?(:seen_form?)
      begin
        return true if $player.pokedex.seen_form?(species, 0, form)
        return true if $player.pokedex.seen_form?(species, 1, form)
      rescue StandardError
        return false
      end
      return false
    end

    def locked_new_mega?(species, form)
      return false if !mega_form?(species, form)
      return false if !noncanon_species?(species, form)
      stone = mega_stone_for(species, form)
      return false if !stone
      begin
        return false if defined?($bag) && $bag && $bag.has?(stone)
      rescue StandardError
      end
      return !seen_species_form?(species, form)
    end

    def pumpkaboo_alt_form?(species, form)
      return false if form <= 0
      return species == :PUMPKABOO || species == :GOURGEIST
    end

    def arceus_alt_form?(species, form)
      return false if form <= 0
      return species == :ARCEUS
    end

    def type_memory_alt_form?(species, form)
      return false if form <= 0
      return species == :SILVALLY || species == :GENESECT
    end

    def greninja_ash_form?(species, form)
      return false if species != :GRENINJA || form <= 0
      s_data = GameData::Species.get_species_form(species, form)
      return false if !s_data
      return s_data.form_name.to_s.downcase.include?("ash")
    end

    def unown_alt_form?(species, form)
      return false if form <= 0
      return species == :UNOWN
    end

    def starmobile_form?(species, form)
      return false if form <= 0
      s_data = GameData::Species.get_species_form(species, form)
      return false if !s_data
      return s_data.form_name.to_s.downcase.include?("starmobile")
    end

    def excluded_from_pokemon_changes?(species, form)
      return true if starmobile_form?(species, form)
      return false
    end

    def force_visible_hidden_variant?(species, form)
      return false if form <= 0
      return false if !FORCE_VISIBLE_HIDDEN_VARIANT_SPECIES.include?(species)
      s_data = GameData::Species.get_species_form(species, form) rescue nil
      return false if !s_data
      return s_data.form_name.to_s.strip.empty?
    end

    def form_has_any_changed_data?(species, form)
      key = [species, form]
      move_delta = (@species_move_delta || {})[key]
      if move_delta
        return true if !(move_delta[:added] || []).empty?
        return true if !(move_delta[:added_tutor] || []).empty?
      end
      abil_delta = (@species_ability_delta || {})[key]
      return true if abil_delta && !(abil_delta[:added] || []).empty?
      return true if @entry_gained_evos && !(@entry_gained_evos[key] || []).empty?
      return false
    end

    def excluded_from_move_categories?(species, form)
      return true if mega_form?(species, form)
      return true if greninja_ash_form?(species, form)
      return true if pumpkaboo_alt_form?(species, form)
      return true if arceus_alt_form?(species, form)
      return true if type_memory_alt_form?(species, form)
      return true if unown_alt_form?(species, form) && !form_has_any_changed_data?(species, form)
      return true if base_only_form_family?(species) && form > 0
      return true if minior_core_form?(species, form)
      return false
    end

    def excluded_from_ability_categories?(species, form)
      return true if pumpkaboo_alt_form?(species, form)
      return true if arceus_alt_form?(species, form)
      return true if type_memory_alt_form?(species, form)
      return true if unown_alt_form?(species, form) && !form_has_any_changed_data?(species, form)
      return true if base_only_form_family?(species) && form > 0
      return true if minior_core_form?(species, form)
      return false
    end

    def noncanon_species?(species, form = 0)
      return false if !@noncanon_species_entries || @noncanon_species_entries.empty?
      return true if @noncanon_species_entries[[species, form]]
      return true if form == 0 && @noncanon_species_entries[[species, 0]]
      return false
    end

    def should_mask_species_name?(species, form = 0)
      return false if !$player || $player.seen?(species)
      return noncanon_species?(species, form)
    end

    def regional_form?(species, form)
      return false if form <= 0
      s_data = GameData::Species.get_species_form(species, form)
      return false if !s_data
      form_name = s_data.form_name.to_s.downcase
      regional_tags = ["alolan", "galarian", "hisuian", "paldean", "kantonian", "kantoan", "kanto"]
      return regional_tags.any? { |tag| form_name.include?(tag) }
    end

    def apply_current_filters
      if pokemon_category?
        apply_filters
      else
        if !@non_pokemon_indexes_ready
          build_non_pokemon_indexes
          @non_pokemon_indexes_ready = true
        end
        apply_entry_filters
      end
    end

    def apply_filters
      list = (@all_entries || []).clone
      list.reject! { |sp, f| locked_new_mega?(sp, f) }
      list.reject! { |sp, f| excluded_from_pokemon_changes?(sp, f) }
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

    def move_damage_class(move_data)
      return :status if move_data.respond_to?(:status?) && move_data.status?
      return :physical if move_data.respond_to?(:physical?) && move_data.physical?
      return :special if move_data.respond_to?(:special?) && move_data.special?
      return :status
    end

    def move_entry_name(entry)
      return entry[:name] if entry[:name]
      m = GameData::Move.try_get(entry[:id])
      return entry[:id].to_s if !m
      return m.name
    end

    def ability_entry_name(entry)
      return entry[:name] if entry[:name]
      a = GameData::Ability.try_get(entry[:id])
      return entry[:id].to_s if !a
      return a.name
    end

    def apply_entry_filters
      list = case @category
      when :move_changes
        (@move_entries_all || []).select do |e|
          comparable = e[:added_users_comparable] || []
          next false if comparable.empty?
          next false if (@custom_move_ids || []).include?(e[:id])
          # Ignore noisy case: canonical move gained only by one brand-new species/form.
          next true
        end.clone
      when :ability_changes
        (@ability_entries_all || []).select do |e|
          has_comparable = !(e[:added_users_comparable] || []).empty?
          is_reworked = (@reworked_ability_ids || []).include?(e[:id])
          next false if !has_comparable && !is_reworked
          next false if (@custom_ability_ids || []).include?(e[:id])
          next false if @canon_known_abilities && !@canon_known_abilities.include?(e[:id]) && !is_reworked
          next true
        end.clone
      when :new_moves       then (@new_move_entries_all || []).clone
      when :new_abilities   then (@new_ability_entries_all || []).clone
      else []
      end
      if @category == :move_changes || @category == :new_moves
        if @entry_type_filter != :all
          list.select! do |e|
            e[:type] == @entry_type_filter
          end
        end
        if @entry_damage_filter != :all
          list.select! do |e|
            e[:dmg_class] == @entry_damage_filter
          end
        end
        if @entry_exclusive_filter == :globalized
          list.select! do |e|
            next false if EXCLUSIVE_GLOBALIZED_FILTER_EXCLUDED_IDS.include?(e[:id])
            has_explicit_before = !VermeilChangeDex.reworked_move_before_text(e[:id]).nil?
            canon_count = (e[:canon_user_count] || 0)
            was_exclusive_carrier = canon_count <= 1
            has_comparable_gain = !(e[:added_users_comparable] || []).empty?
            has_explicit_before || (was_exclusive_carrier && has_comparable_gain)
          end
        end
      end
      case @entry_sort_mode
      when :za
        list.sort_by! { |e| [(@category == :ability_changes || @category == :new_abilities) ? ability_entry_name(e).downcase : move_entry_name(e).downcase] }
        list.reverse!
      when :users_plus
        list.sort_by! { |e| [-(e[:added_users].length), ((@category == :ability_changes || @category == :new_abilities) ? ability_entry_name(e).downcase : move_entry_name(e).downcase)] }
      when :users_minus
        list.sort_by! { |e| [-(e[:removed_users] ? e[:removed_users].length : 0), ((@category == :ability_changes || @category == :new_abilities) ? ability_entry_name(e).downcase : move_entry_name(e).downcase)] }
      else
        list.sort_by! { |e| [((@category == :ability_changes || @category == :new_abilities) ? ability_entry_name(e).downcase : move_entry_name(e).downcase)] }
      end
      @entries = list
      if @entries.empty?
        @index = 0
      else
        @index = [[@index, 0].max, @entries.length - 1].min
      end
    end

    def category_options
      return [
        [:pokemon_changes, "Pokemon Changes"],
        [:move_changes, "Move Changes"],
        [:ability_changes, "Ability Changes"],
        [:new_moves, "New Moves"],
        [:new_abilities, "New Abilities"]
      ]
    end

    def open_category_menu(_force_open = false, exit_on_back = true, fullscreen = false)
      opts = category_options
      idx = opts.index { |o| o[0] == @category }
      @category_panel_index = idx || 0
      @category_panel_open = true
      @category_exit_on_back = exit_on_back
      @category_fullscreen = fullscreen || @startup_category_selection
      if @category_fullscreen
        draw_category_start_screen
      else
        draw_category_panel
      end
      return true
    end

    def close_category_menu(apply_choice = false)
      old_category = @category
      if apply_choice
        chosen = category_options[@category_panel_index]
        if chosen
          @category = chosen[0]
          if @category != old_category || @startup_category_selection
            @index = 0
            if !pokemon_category? && !@non_pokemon_indexes_ready
              draw_category_loading_screen
              Graphics.update
              Input.update
              pbUpdate
              build_non_pokemon_indexes
              @non_pokemon_indexes_ready = true
            end
            @all_entries = (@pokemon_entries || []).clone if pokemon_category?
            apply_current_filters
          end
        end
      end
      @category_panel_open = false
      @startup_category_selection = false
      @category_fullscreen = false
      if @sprites["category_panel"]
        @sprites["category_panel"].dispose
        @sprites.delete("category_panel")
      end
      draw_grid_interface
      return true
    end

    def draw_category_loading_screen
      panel = @sprites["category_panel"]
      return if !panel || panel.disposed?
      bmp = panel.bitmap
      bmp.clear
      bmp.fill_rect(0, 44, SCREEN_W, SCREEN_H - 44, Color.new(0, 0, 0, 216))
      w = 260
      h = 72
      x = (SCREEN_W - w) / 2
      y = 156
      bmp.fill_rect(x, y, w, h, Color.new(18, 24, 36, 242))
      bmp.fill_rect(x, y, w, 1, COLOR_PANEL_EDGE)
      bmp.fill_rect(x, y + h - 1, w, 1, COLOR_PANEL_EDGE)
      bmp.fill_rect(x, y, 1, h, COLOR_PANEL_EDGE)
      bmp.fill_rect(x + w - 1, y, 1, h, COLOR_PANEL_EDGE)
      pbDrawTextPositions(bmp, [[_INTL("Loading {1}...", current_category_title), SCREEN_W / 2, y + 24, :center, COLOR_TEXT_MAIN, Color.new(0,0,0,120)]])
    end

    def draw_category_start_screen
      @sprites["overlay"].bitmap.clear
      draw_header("CHANGE DEX", "Select Category")
      grid_bmp = @sprites["grid_bg"].bitmap
      grid_bmp.clear
      @sprites.keys.each do |k|
        if k.to_s.include?("icon_") || k.to_s.include?("evo_mark_") || k == "cursor" ||
           k.to_s.include?("variant_mark_") ||
           k == "scroll_up" || k == "scroll_down"
          @sprites[k].dispose
          @sprites.delete(k)
        end
      end
      draw_category_panel
    end

    def draw_category_panel
      return if !@category_panel_open
      if !@sprites["category_panel"] || @sprites["category_panel"].disposed?
        @sprites["category_panel"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @sprites["category_panel"].z = 260
        pbSetSystemFont(@sprites["category_panel"].bitmap)
      end
      bmp = @sprites["category_panel"].bitmap
      bmp.clear
      dim_opacity = @category_fullscreen ? 0 : 216
      bmp.fill_rect(0, 44, SCREEN_W, SCREEN_H - 44, Color.new(0, 0, 0, dim_opacity))
      x = 96
      y = 70
      w = 320
      row_h = 30
      opts = category_options
      show_title = false
      h = (opts.length * row_h) + (show_title ? 46 : 28)
      bmp.fill_rect(x, y, w, h, Color.new(18, 24, 36, 242))
      bmp.fill_rect(x, y, w, 1, COLOR_PANEL_EDGE)
      bmp.fill_rect(x, y + h - 1, w, 1, COLOR_PANEL_EDGE)
      bmp.fill_rect(x, y, 1, h, COLOR_PANEL_EDGE)
      bmp.fill_rect(x + w - 1, y, 1, h, COLOR_PANEL_EDGE)
      list_start_y = y + (show_title ? 28 : 12)
      opts.each_with_index do |opt, i|
        ry = list_start_y + (i * row_h)
        if i == @category_panel_index
          bmp.fill_rect(x + 6, ry - 1, w - 12, row_h - 2, Color.new(220, 60, 60, 70))
          bmp.fill_rect(x + 6, ry - 1, 3, row_h - 2, COLOR_HIGHLIGHT)
        end
        pbDrawTextPositions(bmp, [[opt[1], x + 16, ry + 3, :left, COLOR_TEXT_MAIN, Color.new(0,0,0,120)]])
      end
      hint = @category_fullscreen ? _INTL("{1}: Select  {2}: Exit", @action_key_name, "X") : _INTL("{1}: Select  {2}: Close", @action_key_name, "X")
      pbDrawTextPositions(bmp, [[hint, x + w - 10, y + h - 22, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
    end

    def open_filter_menu
      if !pokemon_category?
        open_non_pokemon_filter_menu
        return
      end
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
      apply_current_filters
      draw_grid_interface
    end

    def open_non_pokemon_filter_menu
      if @category == :move_changes || @category == :new_moves
        type_names = GameData::Type.keys.sort_by { |t| GameData::Type.get(t).name }
        exclusive_label = (@entry_exclusive_filter == :globalized) ? "Filter: Exclusive->Globalized [ON]" : "Filter: Exclusive->Globalized [OFF]"
        commands = ["Sort: A-Z", "Sort: Z-A", "Sort: +Users", "Sort: -Users", "Filter: Type", "Filter: Physical", "Filter: Special", "Filter: Status", exclusive_label, "Clear Filters", "Cancel"]
        chosen = pbShowCommands(nil, commands, -1)
        return if chosen < 0 || chosen == 10
        case chosen
        when 0 then @entry_sort_mode = :az
        when 1 then @entry_sort_mode = :za
        when 2 then @entry_sort_mode = :users_plus
        when 3 then @entry_sort_mode = :users_minus
        when 4
          type_cmd = ["All Types"] + type_names.map { |t| GameData::Type.get(t).name } + ["Cancel"]
          t_choice = pbShowCommands(nil, type_cmd, -1)
          return if t_choice < 0 || t_choice == type_cmd.length - 1
          @entry_type_filter = (t_choice == 0) ? :all : type_names[t_choice - 1]
        when 5 then @entry_damage_filter = :physical
        when 6 then @entry_damage_filter = :special
        when 7 then @entry_damage_filter = :status
        when 8
          @entry_exclusive_filter = (@entry_exclusive_filter == :globalized) ? :all : :globalized
        when 9
          @entry_sort_mode = :az
          @entry_type_filter = :all
          @entry_damage_filter = :all
          @entry_exclusive_filter = :all
        end
      else
        commands = ["Sort: A-Z", "Sort: Z-A", "Sort: +Users", "Sort: -Users", "Clear Filters", "Cancel"]
        chosen = pbShowCommands(nil, commands, -1)
        return if chosen < 0 || chosen == 5
        case chosen
        when 0 then @entry_sort_mode = :az
        when 1 then @entry_sort_mode = :za
        when 2 then @entry_sort_mode = :users_plus
        when 3 then @entry_sort_mode = :users_minus
        when 4 then @entry_sort_mode = :az
        end
      end
      apply_current_filters
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
      if label.nil? && m[/^HasMove/i]
        if has_param
          move_id = p.to_sym rescue nil
          move_name = move_id ? (GameData::Move.try_get(move_id)&.name || p) : p
          label = "Move: #{move_name}"
        else
          label = "Move"
        end
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
      return data if canon.nil? || !canon.is_a?(Hash)
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
      canon ||= VermeilChangeDex.get_canon_info(species, 0)
      species_data = GameData::Species.get_species_form(species, form)
      evo_data = evolution_method_change_data(species_data, canon)
      return if evo_data[:new].empty? && evo_data[:changed].empty?
      lines = []
      if !evo_data[:new].empty?
        lines << _INTL("New Evolution Methods:")
        evo_data[:new].each do |evo|
          method_txt = changedex_evo_method_short_label(evo[:method], evo[:param])
          if should_mask_species_name?(evo[:species], 0)
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

    def ability_move_name(move_id)
      move = GameData::Move.try_get(move_id)
      return move_id.to_s if !move
      return move.name
    end

    def moves_with_flag(flag_name)
      ids = []
      GameData::Move.each do |m|
        next if !m || !m.id
        flags = (m.flags || [])
        next if flags.empty?
        ids << m.id if flags.any? { |f| f.to_s =~ /^#{Regexp.escape(flag_name)}$/i }
      end
      return ids.uniq
    end

    def moves_with_type(type_sym)
      ids = []
      GameData::Move.each do |m|
        next if !m || !m.id
        ids << m.id if m.type == type_sym
      end
      return ids.uniq
    end

    def ability_boost_sections(ability_id)
      sections = []
      case ability_id
      when :IRONFIST
        sections << { :label => "Punching moves", :moves => moves_with_flag("Punching") }
      when :STRONGJAW
        sections << { :label => "Biting moves", :moves => moves_with_flag("Biting") }
      when :MEGALAUNCHER
        sections << { :label => "Pulse moves", :moves => moves_with_flag("Pulse") }
      when :SHARPNESS
        sections << { :label => "Slicing moves", :moves => moves_with_flag("Slicing") }
      when :BLUDGEONMASTER
        hammer_ids = if defined?(Battle::AbilityEffects) && Battle::AbilityEffects.const_defined?(:HAMMER_MASTER_MOVES)
                       Battle::AbilityEffects::HAMMER_MASTER_MOVES
                     else
                       [:ICEHAMMER, :CRABHAMMER, :HAMMERARM, :WOODHAMMER, :GIGATONHAMMER, :DRAGONHAMMER]
                     end
        sections << { :label => "Hammer moves", :moves => hammer_ids }
      when :STRIKER
        kick_ids = if defined?(VermeilStriker) && VermeilStriker.const_defined?(:KICK_MOVES)
                     VermeilStriker::KICK_MOVES
                   else
                     [:DOUBLEKICK, :JUMPKICK, :HIJUMPKICK, :MEGAKICK, :LOWKICK, :ROLLINGKICK, :TRIPLEKICK, :BLAZEKICK, :TROPKICK, :THUNDEROUSKICK, :AXEKICK]
                   end
        sections << { :label => "Kicking moves", :moves => kick_ids }
      when :ILLUMINATE
        light_ids = if defined?(VermeilAbilityReworks) && VermeilAbilityReworks.const_defined?(:LIGHT_MOVES)
                      VermeilAbilityReworks::LIGHT_MOVES
                    else
                      []
                    end
        sections << { :label => "Light moves", :moves => light_ids } if !light_ids.empty?
      end
      return sections
    end

    def wrap_colored_tokens(bmp, tokens, max_w)
      lines = []
      line = []
      line_w = 0
      tokens.each do |tok|
        if tok == :newline
          lines << line if !line.empty?
          line = []
          line_w = 0
          next
        end
        text = tok[0].to_s
        next if text.empty?
        color = tok[1] || COLOR_TEXT_MAIN
        token_w = bmp.text_size(text).width
        if line_w + token_w > max_w && !line.empty?
          lines << line
          line = []
          line_w = 0
        end
        line << [text, color]
        line_w += token_w
      end
      lines << line if !line.empty?
      return lines
    end

    def draw_colored_token_line(bmp, token_line, x, y)
      xx = x
      (token_line || []).each do |tok|
        text = tok[0].to_s
        color = tok[1] || COLOR_TEXT_MAIN
        pbDrawTextPositions(bmp, [[text, xx, y, :left, color, Color.new(0, 0, 0, 120)]])
        xx += bmp.text_size(text).width
      end
    end

    def ability_newly_boosted_move?(ability_id, move_id)
      move_data = GameData::Move.try_get(move_id)
      return false if !move_data
      now_type = move_data.type
      now_flags = (move_data.flags || []).map { |f| f.to_s }
      canon_type = VermeilChangeDex.canon_move_type(move_id)
      canon_flags = (VermeilChangeDex.canon_move_flags(move_id) || []).map { |f| f.to_s }
      has_now_flag = proc { |name| now_flags.any? { |f| f =~ /^#{Regexp.escape(name)}$/i } }
      had_canon_flag = proc { |name| canon_flags.any? { |f| f =~ /^#{Regexp.escape(name)}$/i } }
      case ability_id
      when :IRONFIST
        return has_now_flag.call("Punching") && !had_canon_flag.call("Punching")
      when :STRONGJAW
        return has_now_flag.call("Biting") && !had_canon_flag.call("Biting")
      when :MEGALAUNCHER
        return has_now_flag.call("Pulse") && !had_canon_flag.call("Pulse")
      when :SHARPNESS
        return has_now_flag.call("Slicing") && !had_canon_flag.call("Slicing")
      end
      return false
    end

    def ability_boost_popup_lines(ability_id, bmp)
      sections = ability_boost_sections(ability_id)
      return [] if sections.empty?
      canonical_ability = !(VermeilChangeDex.custom_ability_ids || []).include?(ability_id)
      custom_move_lookup = {}
      (VermeilChangeDex.custom_move_ids || []).each { |mid| custom_move_lookup[mid] = true }
      tokens = []
      sections.each_with_index do |sec, idx|
        tokens << :newline if idx > 0
        if sec[:general]
          tokens << ["#{sec[:label]}: ", COLOR_CANON]
          tokens << [sec[:general].to_s, COLOR_TEXT_MAIN]
          next
        end
        move_ids = (sec[:moves] || []).compact.uniq
        next if move_ids.empty?
        tokens << ["#{sec[:label]}: ", COLOR_CANON]
        move_ids.each_with_index do |move_id, i|
          move_name = ability_move_name(move_id)
          highlight = canonical_ability && (custom_move_lookup[move_id] || ability_newly_boosted_move?(ability_id, move_id))
          col = highlight ? COLOR_DIFF : COLOR_TEXT_MAIN
          tokens << [move_name, col]
          tokens << [", ", COLOR_TEXT_MAIN] if i < move_ids.length - 1
        end
      end
      return wrap_colored_tokens(bmp, tokens, 404)
    end

    def ability_moves_popup_page_size
      return 6
    end

    def show_ability_moves_popup(entry)
      return if !entry || !entry[:id]
      bmp = @sprites["overlay"]&.bitmap
      return if !bmp
      lines = ability_boost_popup_lines(entry[:id], bmp)
      if lines.empty?
        pbPlayBuzzerSE
        return
      end
      @ability_moves_popup_lines = lines
      @ability_moves_popup_page = 0
      @ability_moves_popup_title = _INTL("Boosted Moves")
      redraw_ability_moves_popup
      @ability_moves_popup_open = true
    end

    def redraw_ability_moves_popup
      hide_ability_moves_popup(false)
      return if @ability_moves_popup_lines.nil? || @ability_moves_popup_lines.empty?
      @sprites["ability_moves_popup"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["ability_moves_popup"].z = 260
      bmp = @sprites["ability_moves_popup"].bitmap
      pbSetSystemFont(bmp)
      panel_x = 38
      panel_y = 86
      panel_w = SCREEN_W - 76
      panel_h = 210
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(20, 28, 40, 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      pbDrawTextPositions(bmp, [[@ability_moves_popup_title, panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      per_page = ability_moves_popup_page_size
      total_pages = [(@ability_moves_popup_lines.length.to_f / per_page).ceil, 1].max
      @ability_moves_popup_page = [[@ability_moves_popup_page, 0].max, total_pages - 1].min
      start_idx = @ability_moves_popup_page * per_page
      page_lines = @ability_moves_popup_lines[start_idx, per_page] || []
      y = panel_y + 36
      page_lines.each do |line|
        draw_colored_token_line(bmp, line, panel_x + 12, y)
        y += 22
      end
      controls = _INTL("L/R: Page  {1}/{2}: Close", @filter_key_name, "X")
      page_txt = _INTL("Page {1}/{2}", @ability_moves_popup_page + 1, total_pages)
      pbDrawTextPositions(bmp, [[controls, panel_x + 12, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      pbDrawTextPositions(bmp, [[page_txt, panel_x + panel_w - 12, panel_y + panel_h - 24, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      @ability_moves_popup_open = true
    end

    def hide_ability_moves_popup(clear_lines = true)
      @ability_moves_popup_open = false
      @ability_moves_popup_page = 0 if clear_lines
      @ability_moves_popup_lines = [] if clear_lines
      if @sprites["ability_moves_popup"]
        @sprites["ability_moves_popup"].dispose
        @sprites.delete("ability_moves_popup")
      end
    end

    def ability_rework_popup_page_size
      return 7
    end

    def pokemon_ability_before_after_lines(species, form, bmp)
      canon = VermeilChangeDex.get_canon_info(species, form)
      canon ||= VermeilChangeDex.get_canon_info(species, 0)
      return [] if !canon
      vermeil = GameData::Species.get_species_form(species, form) rescue nil
      return [] if !vermeil
      c_slots = build_ability_slots(canon[:abilities], canon[:hidden_abilities], true)
      v_slots = build_ability_slots(vermeil.abilities, vermeil.hidden_abilities, false)
      labels = (c_slots.keys + v_slots.keys).uniq.sort_by { |k| ability_slot_sort_key(k) }
      max_w = 372
      before_entries = []
      after_entries = []
      labels.each do |slot|
        before = c_slots[slot].to_s.strip
        after = v_slots[slot].to_s.strip
        before_entries << "#{before}(#{slot.gsub(/[()]/, '')})" if !before.empty?
        after_entries << "#{after}(#{slot.gsub(/[()]/, '')})" if !after.empty?
      end
      return [] if before_entries == after_entries
      lines = []
      lines << [["Before:", COLOR_CANON]]
      wrap_plain_lines(bmp, before_entries.empty? ? "-" : before_entries.join(", "), max_w).each do |seg|
        lines << [[seg, COLOR_TEXT_MAIN]]
      end
      lines << [["After:", COLOR_VERMEIL]]
      wrap_plain_lines(bmp, after_entries.empty? ? "-" : after_entries.join(", "), max_w).each do |seg|
        lines << [[seg, COLOR_DIFF]]
      end
      return lines
    end

    def pokemon_ability_before_after_available?
      return false if !pokemon_category?
      return false if !@detail_species
      bmp = @sprites["overlay"]&.bitmap
      return false if !bmp
      lines = pokemon_ability_before_after_lines(@detail_species, @detail_form, bmp)
      return !lines.empty?
    end

    def show_pokemon_ability_rework_popup
      return if !pokemon_category? || !@detail_species
      bmp = @sprites["overlay"]&.bitmap
      return if !bmp
      lines = pokemon_ability_before_after_lines(@detail_species, @detail_form, bmp)
      if lines.empty?
        pbPlayBuzzerSE
        return
      end
      @ability_rework_popup_lines = lines
      @ability_rework_popup_title = _INTL("Abilities: Before / After")
      @ability_rework_popup_page = 0
      redraw_ability_rework_popup
      @ability_rework_popup_open = true
    end

    def ability_before_after_lines(entry, bmp)
      return [] if !entry || !entry[:id]
      ability_id = entry[:id]
      ability_data = GameData::Ability.try_get(ability_id)
      return [] if !ability_data
      before_txt = VermeilChangeDex.reworked_ability_before_text(ability_id).to_s.strip
      after_txt = ability_data.description.to_s.strip
      return [] if before_txt.empty? || after_txt.empty?
      return [] if before_txt == after_txt
      max_w = 372
      lines = []
      lines << [["Before:", COLOR_CANON]]
      wrap_plain_lines(bmp, before_txt, max_w).each do |seg|
        lines << [[seg, COLOR_TEXT_MAIN]]
      end
      lines << [["After:", COLOR_VERMEIL]]
      wrap_plain_lines(bmp, after_txt, max_w).each do |seg|
        lines << [[seg, COLOR_TEXT_MAIN]]
      end
      return lines
    end

    def show_ability_rework_popup(entry)
      return if !entry || !entry[:id]
      bmp = @sprites["overlay"]&.bitmap
      return if !bmp
      lines = ability_before_after_lines(entry, bmp)
      if lines.empty?
        pbPlayBuzzerSE
        return
      end
      @ability_rework_popup_lines = lines
      @ability_rework_popup_title = _INTL("Before / After")
      @ability_rework_popup_page = 0
      redraw_ability_rework_popup
      @ability_rework_popup_open = true
    end

    def redraw_ability_rework_popup
      hide_ability_rework_popup(false)
      return if @ability_rework_popup_lines.nil? || @ability_rework_popup_lines.empty?
      @sprites["ability_rework_popup"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["ability_rework_popup"].z = 260
      bmp = @sprites["ability_rework_popup"].bitmap
      pbSetSystemFont(bmp)
      panel_x = 38
      panel_y = 78
      panel_w = SCREEN_W - 76
      panel_h = 226
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(20, 28, 40, 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      title = (@ability_rework_popup_title && !@ability_rework_popup_title.empty?) ? @ability_rework_popup_title : _INTL("Before / After")
      pbDrawTextPositions(bmp, [[title, panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      per_page = ability_rework_popup_page_size
      total_pages = [(@ability_rework_popup_lines.length.to_f / per_page).ceil, 1].max
      @ability_rework_popup_page = [[@ability_rework_popup_page, 0].max, total_pages - 1].min
      start_idx = @ability_rework_popup_page * per_page
      page_lines = @ability_rework_popup_lines[start_idx, per_page] || []
      y = panel_y + 36
      page_lines.each do |line|
        draw_colored_token_line(bmp, line, panel_x + 12, y)
        y += 22
      end
      controls = _INTL("L/R: Page  {1}/{2}: Close", @action_key_name, "X")
      page_txt = _INTL("Page {1}/{2}", @ability_rework_popup_page + 1, total_pages)
      pbDrawTextPositions(bmp, [[controls, panel_x + 12, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      pbDrawTextPositions(bmp, [[page_txt, panel_x + panel_w - 12, panel_y + panel_h - 24, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      @ability_rework_popup_open = true
    end

    def hide_ability_rework_popup(clear_lines = true)
      @ability_rework_popup_open = false
      @ability_rework_popup_page = 0 if clear_lines
      @ability_rework_popup_lines = [] if clear_lines
      @ability_rework_popup_title = "Before / After" if clear_lines
      if @sprites["ability_rework_popup"]
        @sprites["ability_rework_popup"].dispose
        @sprites.delete("ability_rework_popup")
      end
    end

    def move_rework_popup_page_size
      return 7
    end

    def move_display_accuracy(value)
      return "-" if value.to_i <= 0
      return value.to_i.to_s
    end

    def move_display_power(value)
      return "-" if value.to_i <= 0
      return value.to_i.to_s
    end

    def move_display_dmg_class(sym)
      return "Status" if !sym
      return sym.to_s.capitalize
    end

    def normalized_flag_list(flags)
      return [] if !flags
      return flags.map { |f| f.to_s.strip }.reject { |f| f.empty? }.uniq
    end

    def move_extra_category_tags(move_id)
      tags = []
      if defined?(VermeilStriker) && VermeilStriker.const_defined?(:KICK_MOVES)
        tags << "Kicking" if VermeilStriker::KICK_MOVES.include?(move_id)
      end
      if defined?(VermeilAbilityReworks) && VermeilAbilityReworks.const_defined?(:LIGHT_MOVES)
        tags << "Light" if VermeilAbilityReworks::LIGHT_MOVES.include?(move_id)
      end
      if defined?(Battle::AbilityEffects) && Battle::AbilityEffects.const_defined?(:HAMMER_MASTER_MOVES)
        tags << "Hammer" if Battle::AbilityEffects::HAMMER_MASTER_MOVES.include?(move_id)
      end
      return tags.uniq
    end

    def normalized_move_tag_list(move_id, flags)
      tags = normalized_flag_list(flags)
      tags.concat(move_extra_category_tags(move_id))
      return tags.uniq
    end

    def titleize_flag(flag_name)
      txt = flag_name.to_s.dup
      txt.gsub!(/([a-z])([A-Z])/, '\1 \2')
      txt = txt.tr("_", " ")
      return txt.split.map { |w| w[0] ? w[0].upcase + w[1..-1].to_s.downcase : w }.join(" ")
    end

    def friendly_function_effect(code)
      code_s = code.to_s
      map = {
        "AlwaysCriticalHit"          => "Critical hit",
        "RaiseUserEvasion1"          => "Evasion up",
        "ParalyzeTarget"             => "May paralyze",
        "FlinchTarget"               => "May flinch",
        "BurnTarget"                 => "May burn",
        "StartLightScreen"           => "Sets up Light Screen",
        "StartReflect"               => "Sets up Reflect",
        "StartLeechSeedTarget"       => "Seeds target (HP drain)",
        "ResetAllBattlersStatChanges"=> "Resets all stat changes",
        "CureUserPartyStatus"        => "Cures party status",
        "HealUserByHalfOfDamageDone" => "Heals user (50% damage dealt)",
        "PowerHigherWithUserHappiness" => "Power scales with friendship"
      }
      return map[code_s] if map[code_s]
      human = code_s.gsub(/([a-z])([A-Z])/, '\1 \2').tr("_", " ").strip
      return human.empty? ? "Special effect changed" : human.downcase.capitalize
    end

    def flag_synergy_descriptions(flag_names)
      map = {
        "Punching" => "Iron Fist",
        "Biting"   => "Strong Jaw",
        "Pulse"    => "Mega Launcher",
        "Slicing"  => "Sharpness",
        "Kicking"  => "Striker",
        "Light"    => "Illuminate",
        "Hammer"   => "Bludgeon Master"
      }
      out = []
      (flag_names || []).each do |flag|
        ability = map[flag]
        next if !ability
        out << ability
      end
      return out.uniq
    end

    def move_change_lines(entry)
      return [] if !entry || !entry[:id]
      move_id = entry[:id]
      move_data = GameData::Move.try_get(move_id)
      canon = VermeilChangeDex.canon_move_entry(move_id)
      return [] if !move_data
      diffs = []
      canon_type = canon ? canon[:type] : nil
      now_type = move_data.type
      if canon_type && canon_type != now_type
        before = (GameData::Type.get(canon_type).name rescue canon_type.to_s)
        after = (GameData::Type.get(now_type).name rescue now_type.to_s)
        diffs << _INTL("Type: {1} -> {2}", before, after)
      end
      canon_class = canon ? canon[:dmg_class] : nil
      now_class = move_damage_class(move_data)
      if canon_class && canon_class != now_class
        diffs << _INTL("Class: {1} -> {2}", move_display_dmg_class(canon_class), move_display_dmg_class(now_class))
      end
      canon_power = canon ? canon[:power] : nil
      now_power = move_data.respond_to?(:power) ? move_data.power.to_i : 0
      if !canon_power.nil? && canon_power.to_i != now_power.to_i
        diffs << _INTL("Power: {1} -> {2}", move_display_power(canon_power), move_display_power(now_power))
      end
      canon_acc = canon ? canon[:accuracy] : nil
      now_acc = move_data.accuracy.to_i
      if !canon_acc.nil? && canon_acc.to_i != now_acc.to_i
        diffs << _INTL("Acc: {1} -> {2}", move_display_accuracy(canon_acc), move_display_accuracy(now_acc))
      end
      canon_pp = canon ? canon[:total_pp] : nil
      now_pp = move_data.total_pp.to_i
      if !canon_pp.nil? && canon_pp.to_i != now_pp.to_i
        diffs << _INTL("PP: {1} -> {2}", canon_pp.to_i, now_pp.to_i)
      end
      canon_priority = canon ? canon[:priority] : nil
      now_priority = move_data.priority.to_i
      if !canon_priority.nil? && canon_priority.to_i != now_priority.to_i
        diffs << _INTL("Priority: {1} -> {2}", canon_priority.to_i, now_priority.to_i)
      end
      canon_func = canon ? canon[:function].to_s : ""
      now_func = move_data.function_code.to_s
      if !canon_func.empty? && canon_func != now_func
        diffs << _INTL("Effect: {1} -> {2}", friendly_function_effect(canon_func), friendly_function_effect(now_func))
      end
      canon_eff = canon ? canon[:effect_chance] : nil
      now_eff = move_data.effect_chance.to_i
      if !canon_eff.nil? && canon_eff.to_i != now_eff.to_i
        diffs << _INTL("Effect chance: {1}% -> {2}%", canon_eff.to_i, now_eff.to_i)
      end
      # Canon only has raw move flags, while Vermeil may additionally classify
      # moves via curated tag lists (Kicking/Light/Hammer). Compare against
      # canonical raw flags so those new categories appear as gained tags.
      canon_flags = normalized_flag_list(canon ? canon[:flags] : [])
      now_flags = normalized_move_tag_list(move_id, move_data.flags || [])
      canon_lookup = {}
      canon_flags.each { |f| canon_lookup[f.downcase] = f }
      now_lookup = {}
      now_flags.each { |f| now_lookup[f.downcase] = f }
      gained_flags = now_flags.select { |f| !canon_lookup[f.downcase] }
      removed_flags = canon_flags.select { |f| !now_lookup[f.downcase] }
      if !gained_flags.empty?
        diffs << _INTL("Now counts as: {1}", gained_flags.map { |f| titleize_flag(f) }.join(", "))
        synergies = flag_synergy_descriptions(gained_flags)
        if !synergies.empty?
          diffs << _INTL("Boosted by: {1}", synergies.join(", "))
        end
      end
      if !removed_flags.empty?
        diffs << _INTL("No longer counts as: {1}", removed_flags.map { |f| titleize_flag(f) }.join(", "))
      end
      return diffs
    end

    def push_wrapped_colored_text(tokens, text, color)
      words = text.to_s.split(/\s+/)
      return if words.empty?
      words.each_with_index do |word, i|
        tokens << [word, color]
        tokens << [" ", color] if i < words.length - 1
      end
    end

    def wrap_plain_lines(bmp, text, max_w)
      words = text.to_s.split(/\s+/)
      return [] if words.empty?
      lines = []
      line = ""
      words.each do |w|
        candidate = line.empty? ? w : "#{line} #{w}"
        if bmp.text_size(candidate).width > max_w && !line.empty?
          lines << line
          line = w
        else
          line = candidate
        end
      end
      lines << line if !line.empty?
      return lines
    end

    def move_rework_popup_lines(entry, bmp)
      move_id = entry[:id]
      before_txt = VermeilChangeDex.reworked_move_before_text(move_id)
      diff_lines = move_change_lines(entry)
      return [] if diff_lines.empty?
      max_w = 372
      lines = []
      if before_txt && !before_txt.empty?
        before_prefix = "Before: "
        wrapped_before = wrap_plain_lines(bmp, before_txt, max_w - bmp.text_size(before_prefix).width)
        if wrapped_before.empty?
          lines << [[before_prefix, COLOR_CANON]]
        else
          lines << [[before_prefix, COLOR_CANON], [wrapped_before[0], COLOR_TEXT_MAIN]]
          cont_indent = " " * before_prefix.length
          wrapped_before[1..-1].to_a.each do |seg|
            lines << [[cont_indent, COLOR_CANON], [seg, COLOR_TEXT_MAIN]]
          end
        end
      end
      lines << [["After:", COLOR_VERMEIL]]
      diff_lines.each do |line|
        bullet = "- "
        indent = "  "
        wrapped = wrap_plain_lines(bmp, line, max_w - bmp.text_size(bullet).width)
        next if wrapped.empty?
        lines << [[bullet, COLOR_TEXT_GRAY], [wrapped[0], COLOR_DIFF]]
        wrapped[1..-1].to_a.each do |seg|
          lines << [[indent, COLOR_TEXT_GRAY], [seg, COLOR_DIFF]]
        end
      end
      return lines
    end

    def show_move_rework_popup(entry)
      return if !entry || !entry[:id]
      bmp = @sprites["overlay"]&.bitmap
      return if !bmp
      lines = move_rework_popup_lines(entry, bmp)
      if lines.empty?
        pbPlayBuzzerSE
        return
      end
      @move_rework_popup_lines = lines
      @move_rework_popup_page = 0
      redraw_move_rework_popup
      @move_rework_popup_open = true
    end

    def redraw_move_rework_popup
      hide_move_rework_popup(false)
      return if @move_rework_popup_lines.nil? || @move_rework_popup_lines.empty?
      @sprites["move_rework_popup"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["move_rework_popup"].z = 260
      bmp = @sprites["move_rework_popup"].bitmap
      pbSetSystemFont(bmp)
      panel_x = 38
      panel_y = 78
      panel_w = SCREEN_W - 76
      panel_h = 226
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(20, 28, 40, 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      pbDrawTextPositions(bmp, [[_INTL("Before / After"), panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      per_page = move_rework_popup_page_size
      total_pages = [(@move_rework_popup_lines.length.to_f / per_page).ceil, 1].max
      @move_rework_popup_page = [[@move_rework_popup_page, 0].max, total_pages - 1].min
      start_idx = @move_rework_popup_page * per_page
      page_lines = @move_rework_popup_lines[start_idx, per_page] || []
      y = panel_y + 36
      page_lines.each do |line|
        draw_colored_token_line(bmp, line, panel_x + 12, y)
        y += 22
      end
      controls = _INTL("L/R: Page  {1}/{2}: Close", @filter_key_name, "X")
      page_txt = _INTL("Page {1}/{2}", @move_rework_popup_page + 1, total_pages)
      pbDrawTextPositions(bmp, [[controls, panel_x + 12, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      pbDrawTextPositions(bmp, [[page_txt, panel_x + panel_w - 12, panel_y + panel_h - 24, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      @move_rework_popup_open = true
    end

    def hide_move_rework_popup(clear_lines = true)
      @move_rework_popup_open = false
      @move_rework_popup_page = 0 if clear_lines
      @move_rework_popup_lines = [] if clear_lines
      if @sprites["move_rework_popup"]
        @sprites["move_rework_popup"].dispose
        @sprites.delete("move_rework_popup")
      end
    end

    def move_popup_lines_per_page
      return 6
    end

    def show_new_moves_popup
      return if !@detail_moves_truncated
      @moves_popup_page = 0
      redraw_new_moves_popup
      @moves_popup_open = true
    end

    def redraw_new_moves_popup
      hide_new_moves_popup(false)
      return if @detail_move_popup_lines.nil? || @detail_move_popup_lines.empty?
      @sprites["new_moves_popup"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["new_moves_popup"].z = 260
      bmp = @sprites["new_moves_popup"].bitmap
      pbSetSystemFont(bmp)
      panel_x = 38
      panel_y = 86
      panel_w = SCREEN_W - 76
      panel_h = 210
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(20, 28, 40, 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      pbDrawTextPositions(bmp, [[_INTL("New Moves"), panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      per_page = move_popup_lines_per_page
      total_pages = [(@detail_move_popup_lines.length.to_f / per_page).ceil, 1].max
      @moves_popup_page = [[@moves_popup_page, 0].max, total_pages - 1].min
      start_idx = @moves_popup_page * per_page
      page_lines = @detail_move_popup_lines[start_idx, per_page] || []
      y = panel_y + 36
      page_lines.each do |line|
        pbDrawTextPositions(bmp, [[line, panel_x + 12, y, :left, COLOR_MOVES_NEW, Color.new(0,0,0,120)]])
        y += 22
      end
      controls = _INTL("L/R: Page  {1}/{2}: Close", @action_key_name, "X")
      page_txt = _INTL("Page {1}/{2}", @moves_popup_page + 1, total_pages)
      pbDrawTextPositions(bmp, [[controls, panel_x + 12, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      pbDrawTextPositions(bmp, [[page_txt, panel_x + panel_w - 12, panel_y + panel_h - 24, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      @moves_popup_open = true
    end

    def hide_new_moves_popup(clear_lines = true)
      @moves_popup_open = false
      @moves_popup_page = 0 if clear_lines
      @detail_move_popup_lines = [] if clear_lines
      if @sprites["new_moves_popup"]
        @sprites["new_moves_popup"].dispose
        @sprites.delete("new_moves_popup")
      end
    end

    def move_popup_usable_width
      # Popup inner width with safety margin to avoid overflow against border.
      return SCREEN_W - 110
    end

    def find_entry_index(search_text)
      query = search_text.to_s.strip
      return nil if query.empty?
      if !pokemon_category?
        down = query.downcase
        @entries.each_with_index do |entry, i|
          name = if @category == :ability_changes || @category == :new_abilities
                   ability_entry_name(entry)
                 else
                   move_entry_name(entry)
                 end
          return i if name.to_s.downcase.include?(down)
        end
        return nil
      end
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
      prompt = if pokemon_category?
                 _INTL("Search Pokémon (name or Dex number).")
               elsif @category == :ability_changes || @category == :new_abilities
                 _INTL("Search Ability.")
               else
                 _INTL("Search Move.")
               end
      query = pbMessageFreeText(prompt, "", false, 32, 240)
      return if !query || query.strip.empty?
      found_index = find_entry_index(query)
      if found_index
        old_page = @index / GRID_PAGE_SIZE
        @index = found_index
        pbPlayCursorSE
        if pokemon_category?
          (@index / GRID_PAGE_SIZE != old_page) ? draw_grid_interface : refresh_cursor
        else
          draw_grid_interface
        end
      else
        pbPlayBuzzerSE
        pbMessage(_INTL("No match found in Change Dex."))
      end
    end

    def pbStartScene
      pbFadeOutIn do
        if !@data_ready
          VermeilChangeDex.load_canon_data
          detect_changes
          @data_ready = true
        end
        @sprites["bg"] = IconSprite.new(0, 0, @viewport)
        @sprites["bg"].bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
        @sprites["bg"].bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, COLOR_BG); @sprites["bg"].z = 10
        @sprites["grid_bg"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @sprites["grid_bg"].z = 50
        @sprites["overlay"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @sprites["overlay"].z = 200; pbSetSystemFont(@sprites["overlay"].bitmap)
        if @entries.empty?
          draw_header("CHANGE DEX", "No changes detected")
        else
          open_category_menu(true, true, true)
        end
        pbUpdate
      end
    end

    def draw_grid_interface
      if !pokemon_category?
        draw_list_interface
        return
      end
      @sprites["overlay"].bitmap.clear; draw_header("CHANGE DEX", current_category_title)
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
      @variant_mark_base_y = {}
      @sprites.keys.each do |k|
        if k.to_s.include?("icon_") || k.to_s.include?("evo_mark_") || k.to_s.include?("variant_mark_") || k == "cursor" ||
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
        frame = hidden_variant_icon_frame(sp, f)
        if !frame.nil?
          mark = IconSprite.new(0, 0, @viewport)
          mark.setBitmap("Graphics/UI/RegionalVariantIcon")
          mark.src_rect.set(frame * 32, 0, 32, 32)
          mark.x = s.x - 32
          mark.y = s.y - 32
          mark.z = 131
          key = "variant_mark_#{real_idx}"
          @sprites[key] = mark
          @variant_mark_base_y[key] = mark.y
        end
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
        frame = hidden_variant_icon_frame(sp, f)
        if !frame.nil?
          mark = IconSprite.new(0, 0, @viewport)
          mark.setBitmap("Graphics/UI/RegionalVariantIcon")
          mark.src_rect.set(frame * 32, 0, 32, 32)
          mark.x = s.x - 32
          mark.y = s.y - 32
          mark.z = 121
          mark.opacity = 150
          key = "variant_mark_#{real_idx}"
          @sprites[key] = mark
          @variant_mark_base_y[key] = mark.y
        end
      end
      draw_grid_scroll_hints
      refresh_cursor
      draw_category_panel
    end

    def draw_list_interface
      @sprites["overlay"].bitmap.clear
      draw_header("CHANGE DEX", current_category_title)
      grid_bmp = @sprites["grid_bg"].bitmap
      grid_bmp.clear
      @sprites.keys.each do |k|
        if k.to_s.include?("icon_") || k.to_s.include?("evo_mark_") || k.to_s.include?("variant_mark_") || k == "cursor" ||
           k == "scroll_up" || k == "scroll_down"
          @sprites[k].dispose
          @sprites.delete(k)
        end
      end
      bmp = @sprites["overlay"].bitmap
      list_x = 18
      list_y = 56
      list_w = SCREEN_W - 36
      row_h = 28
      visible = 10
      list_h = row_h * visible
      draw_panel(bmp, list_x - 8, list_y - 4, list_w + 16, list_h + 8)
      start_idx = [[@index - (visible / 2), 0].max, [@entries.length - visible, 0].max].min
      selected_y = list_y + ((@index - start_idx) * row_h)
      if !@entries.empty?
        bmp.fill_rect(list_x - 4, selected_y, list_w + 8, row_h, Color.new(220, 60, 60, 56))
      end
      visible.times do |r|
        idx = start_idx + r
        break if idx >= @entries.length
        y = list_y + (r * row_h) + 4
        entry = @entries[idx]
        name = if @category == :ability_changes || @category == :new_abilities
                 ability_entry_name(entry)
               else
                 move_entry_name(entry)
               end
        added = if @category == :move_changes || @category == :ability_changes
                  (entry[:added_users_comparable] || []).length
                else
                  entry[:added_users].length
                end
        right = "+#{added}"
        color = (idx == @index) ? COLOR_TEXT_MAIN : Color.new(210, 210, 210)
        pbDrawTextPositions(bmp, [[name, list_x, y, :left, color, Color.new(0,0,0,120)],
                                  [right, list_x + list_w, y, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      end
      bmp.fill_rect(0, 340, SCREEN_W, 44, Color.new(0, 0, 0, 236))
      bmp.fill_rect(0, 338, SCREEN_W, 2, COLOR_HIGHLIGHT)
      label = @entries.empty? ? "No entries" : ((@category == :ability_changes || @category == :new_abilities) ? ability_entry_name(@entries[@index]) : move_entry_name(@entries[@index]))
      right_hint = _INTL("{1}: Filter", @filter_key_name)
      text_positions = [[label, SCREEN_W / 2, 350, :center, COLOR_TEXT_MAIN, Color.new(0,0,0,160)],
                        [_INTL("{1}: Search", @action_key_name), 8, 350, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,160)]]
      text_positions << [right_hint, SCREEN_W - 8, 350, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,160)] if right_hint && !right_hint.empty?
      pbDrawTextPositions(bmp, text_positions)
      draw_category_panel
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

    def update_variant_mark_animation
      return if !@variant_mark_base_y || @variant_mark_base_y.empty?
      bob = Math.sin(System.uptime * 6.0) * 2.0
      @variant_mark_base_y.each do |k, base_y|
        spr = @sprites[k]
        next if !spr || spr.disposed?
        spr.y = (base_y + bob).round
      end
    end

    def move_cursor(dx, dy)
      return if @entries.empty?
      if !pokemon_category?
        old_idx = @index
        step = (dy != 0) ? dy : dx
        if step < 0 && @index <= 0
          @index = @entries.length - 1
        elsif step > 0 && @index >= @entries.length - 1
          @index = 0
        else
          @index = [[@index + step, 0].max, @entries.length - 1].min
        end
        return if @index == old_idx
        pbPlayCursorSE
        draw_grid_interface
        return
      end
      old_idx = @index
      page = (@index / GRID_PAGE_SIZE)
      in_page = @index - (page * GRID_PAGE_SIZE)
      if dy != 0 && dx == 0
        col = in_page % GRID_COLS
        row = in_page / GRID_COLS
        page_start = page * GRID_PAGE_SIZE
        page_count = [GRID_PAGE_SIZE, @entries.length - page_start].min
        last_visible_row = [[(page_count - 1) / GRID_COLS, 0].max, GRID_ACTIVE_ROWS - 1].min
        if dy > 0 && row >= last_visible_row
          # From last active row, moving down pages forward.
          target_page = page + 1
          target_idx = (target_page * GRID_PAGE_SIZE) + col
          if target_idx >= @entries.length
            # Wrap to first page when moving down from the last page.
            target_idx = [col, @entries.length - 1].min
          end
        elsif dy < 0 && row <= 0
          # From first active row, moving up pages backward.
          target_page = page - 1
          if target_page < 0
            target_page = (@entries.length - 1) / GRID_PAGE_SIZE
          end
          page_start = target_page * GRID_PAGE_SIZE
          target_idx = nil
          (GRID_ACTIVE_ROWS - 1).downto(0) do |r|
            cand = page_start + (r * GRID_COLS) + col
            if cand >= 0 && cand < @entries.length
              target_idx = cand
              break
            end
          end
          target_idx = [@entries.length - 1, page_start].max if target_idx.nil?
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

    def hidden_form_has_changes?(species, form)
      return false if form <= 0
      base = GameData::Species.get_species_form(species, 0)
      alt = GameData::Species.get_species_form(species, form)
      return false if !base || !alt
      return true if species_stats_array(base) != species_stats_array(alt)
      return true if (base.types || []).to_a != (alt.types || []).to_a
      base_abil = (base.abilities + base.hidden_abilities).compact.reject { |a| a == :NONE }.uniq.sort
      alt_abil = (alt.abilities + alt.hidden_abilities).compact.reject { |a| a == :NONE }.uniq.sort
      return true if base_abil != alt_abil
      base_moves = (base.moves || []).map { |m| m[1] }.compact.uniq
      alt_moves = (alt.moves || []).map { |m| m[1] }.compact.uniq
      return true if base_moves != alt_moves
      base_evos = base.get_evolutions(true) rescue []
      alt_evos = alt.get_evolutions(true) rescue []
      return true if base_evos != alt_evos
      return false
    end

    def hidden_variant_forms_for(species)
      forms = []
      GameData::Species.each do |s|
        next if s.species != species || s.form <= 0
        next if mega_form?(species, s.form)
        f_name = s.form_name.to_s.strip
        # Hidden-variant selector is only for implicit forms (no FormName),
        # such as Cubone-style regional evolution routing.
        next if !f_name.empty?
        next if !hidden_form_has_changes?(species, s.form)
        forms << s.form
      end
      return forms.uniq.sort
    end

    def inferred_variant_name(species, form)
      return "Normal" if form <= 0
      visited = {}
      queue = [[species, form]]
      while !queue.empty?
        sp, f = queue.shift
        next if visited[[sp, f]]
        visited[[sp, f]] = true
        s_data = GameData::Species.get_species_form(sp, f) rescue nil
        next if !s_data
        f_name = s_data.form_name.to_s.strip
        return f_name if !f_name.empty?
        evos = s_data.get_evolutions(true) rescue []
        evos.each do |evo|
          evo_species = evo[0]
          queue << [evo_species, f]
        end
      end
      return "Form #{form}"
    end

    def hidden_variant_icon_frame(species, form)
      return nil if form <= 0
      s_data = GameData::Species.get_species_form(species, form)
      return nil if !s_data.form_name.to_s.strip.empty?   # Only hidden variants.
      variant = inferred_variant_name(species, form).to_s.downcase
      return 0 if variant.include?("alolan") || variant.include?("alola")
      return 1 if variant.include?("galarian") || variant.include?("galar")
      return 2 if variant.include?("hisuian") || variant.include?("hisui")
      return nil
    end

    def detail_variant_label(species, form)
      base_name = begin
        GameData::Species.get(species).name.to_s
      rescue StandardError
        species.to_s
      end
      return base_name if form <= 0
      variant = inferred_variant_name(species, form).to_s
      return variant if variant.downcase.include?(base_name.downcase)
      return "#{variant} #{base_name}"
    end

    def prepare_detail_form_options(species, current_form)
      if mega_form?(species, current_form)
        @detail_form_options = [current_form]
        @detail_form_option_index = 0
        return
      end
      if current_form > 0
        s_data = GameData::Species.get_species_form(species, current_form)
        if s_data && !s_data.form_name.to_s.strip.empty?
          # Visible named forms (e.g. Alolan Ninetales) shouldn't use the
          # hidden-variant toggle flow.
          @detail_form_options = [current_form]
          @detail_form_option_index = 0
          return
        end
      end
      forms = [0]
      forms.concat(hidden_variant_forms_for(species))
      forms = forms.uniq.sort
      @detail_form_options = forms
      @detail_form_option_index = forms.include?(current_form) ? forms.index(current_form) : 0
    end

    def cycle_detail_variant
      return false if !pokemon_category?
      return false if !@detail_form_options || @detail_form_options.length <= 1
      @detail_form_option_index += 1
      @detail_form_option_index = 0 if @detail_form_option_index >= @detail_form_options.length
      @detail_form = @detail_form_options[@detail_form_option_index]
      draw_detail_view(@detail_species, @detail_form)
      return true
    end

    def detail_action_options
      opts = []
      if pokemon_category?
        opts << [:evo_methods, "Evo Methods"] if @detail_has_evo_method_changes
        opts << [:pokemon_ability_before_after, "Ability B/A"] if pokemon_ability_before_after_available?
        if SHOW_DETAIL_VARIANT_ACTION
          opts << [:variant, "Variant"] if @detail_form_options && @detail_form_options.length > 1
        end
      end
      return opts
    end

    def perform_detail_action(option_sym)
      case option_sym
      when :evo_methods
        show_evolution_method_window(@detail_species, @detail_form)
        return true
      when :variant
        # If there are multiple alternate variants, let user choose directly.
        alt_count = (@detail_form_options ? @detail_form_options.length - 1 : 0)
        if alt_count > 1
          return open_detail_variant_menu
        end
        return cycle_detail_variant
      when :pokemon_ability_before_after
        return false if !pokemon_category?
        show_pokemon_ability_rework_popup
        return true
      end
      return false
    end

    def open_detail_action_menu
      opts = detail_action_options
      return false if opts.empty?
      if opts.length == 1
        return perform_detail_action(opts[0][0])
      end
      close_detail_action_menu
      @detail_action_menu_options = opts
      @detail_action_menu_index = 0
      @detail_action_menu_open = true
      draw_detail_action_menu
      return true
    end

    def close_detail_action_menu
      @detail_action_menu_open = false
      @detail_action_menu_options = []
      @detail_action_menu_index = 0
      @sprites["detail_action_menu"]&.dispose
      @sprites.delete("detail_action_menu")
    end

    def open_detail_variant_menu
      return false if !pokemon_category?
      return false if !@detail_form_options || @detail_form_options.length <= 1
      close_detail_variant_menu
      @detail_variant_menu_options = @detail_form_options.map do |f|
        [f, detail_variant_label(@detail_species, f)]
      end
      @detail_variant_menu_index = [@detail_form_options.index(@detail_form) || 0, 0].max
      @detail_variant_menu_open = true
      draw_detail_variant_menu
      return true
    end

    def close_detail_variant_menu
      @detail_variant_menu_open = false
      @detail_variant_menu_options = []
      @detail_variant_menu_index = 0
      @sprites["detail_variant_menu"]&.dispose
      @sprites.delete("detail_variant_menu")
    end

    def draw_detail_variant_menu
      @sprites["detail_variant_menu"]&.dispose
      @sprites.delete("detail_variant_menu")
      @sprites["detail_variant_menu"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["detail_variant_menu"].z = 261
      bmp = @sprites["detail_variant_menu"].bitmap
      pbSetSystemFont(bmp)
      panel_w = 240
      panel_h = 32 + (@detail_variant_menu_options.length * 28) + 28
      panel_x = SCREEN_W - panel_w - 12
      panel_y = 50
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(20, 28, 40, 236))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      pbDrawTextPositions(bmp, [["Choose Variant", panel_x + 10, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      @detail_variant_menu_options.each_with_index do |opt, i|
        y = panel_y + 34 + (i * 28)
        if i == @detail_variant_menu_index
          bmp.fill_rect(panel_x + 8, y - 2, panel_w - 16, 24, Color.new(98, 44, 56, 210))
        end
        pbDrawTextPositions(bmp, [[opt[1], panel_x + 14, y, :left, COLOR_TEXT_MAIN, Color.new(0,0,0,120)]])
      end
      pbDrawTextPositions(bmp, [[_INTL("{1}: Select  {2}: Back", @action_key_name, "X"), panel_x + 10, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
    end

    def draw_detail_action_menu
      @sprites["detail_action_menu"]&.dispose
      @sprites.delete("detail_action_menu")
      @sprites["detail_action_menu"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["detail_action_menu"].z = 260
      bmp = @sprites["detail_action_menu"].bitmap
      pbSetSystemFont(bmp)
      panel_w = 210
      panel_h = 32 + (@detail_action_menu_options.length * 28) + 28
      panel_x = SCREEN_W - panel_w - 12
      panel_y = 50
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(20, 28, 40, 236))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      pbDrawTextPositions(bmp, [["Select Action", panel_x + 10, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      @detail_action_menu_options.each_with_index do |opt, i|
        y = panel_y + 34 + (i * 28)
        if i == @detail_action_menu_index
          bmp.fill_rect(panel_x + 8, y - 2, panel_w - 16, 24, Color.new(98, 44, 56, 210))
        end
        pbDrawTextPositions(bmp, [[opt[1], panel_x + 14, y, :left, COLOR_TEXT_MAIN, Color.new(0,0,0,120)]])
      end
      pbDrawTextPositions(bmp, [[_INTL("{1}: Select  {2}: Back", @action_key_name, "X"), panel_x + 10, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
    end

    def refresh_cursor
      return if @mode != :grid
      if !pokemon_category?
        draw_list_interface
        return
      end
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
      draw_category_panel
    end

    def switch_to_detail
      return if @entries.empty?
      @mode = :detail
      ["scroll_up", "scroll_down"].each do |k|
        next if !@sprites[k] || @sprites[k].disposed?
        @sprites[k].visible = false
      end
      if !pokemon_category?
        @sprites["grid_bg"].visible = false if @sprites["grid_bg"] && !@sprites["grid_bg"].disposed?
        draw_entry_detail(@entries[@index])
        return
      end
      @sprites["grid_bg"].visible = false if @sprites["grid_bg"] && !@sprites["grid_bg"].disposed?
      @sprites.each do |k, v|
        if (k.to_s.include?("icon_") || k.to_s.include?("evo_mark_") || k.to_s.include?("variant_mark_") || k == "cursor") && !v.disposed?
          v.visible = false
        end
      end
      sp = @entries[@index][0]
      form = @entries[@index][1]
      prepare_detail_form_options(sp, form)
      draw_detail_view(sp, @detail_form_options[@detail_form_option_index] || form)
    end

    def switch_to_grid
      @mode = :grid
      @sprites["grid_bg"].visible = true if @sprites["grid_bg"] && !@sprites["grid_bg"].disposed?
      hide_ability_moves_popup
      hide_ability_rework_popup
      hide_move_rework_popup
      hide_new_moves_popup
      hide_carrier_popup
      close_detail_action_menu
      close_detail_variant_menu
      clear_entry_detail_carrier_icons
      ["big_icon", "detail_variant_mark", "evo_label_overlay", "evo_method_popup", "new_moves_popup", "ability_moves_popup", "ability_rework_popup", "move_rework_popup", "detail_action_menu", "detail_variant_menu"].each do |k|
        next if !@sprites[k]
        @sprites[k].dispose
        @sprites.delete(k)
      end
      @evo_popup_open = false
      @moves_popup_open = false
      @sprites.keys.each do |k|
        next if !k.to_s.start_with?("evo_detail_")
        @sprites[k].dispose
        @sprites.delete(k)
      end
      @sprites.each do |k, v|
        if !v.nil? && !v.disposed? && (k.to_s.include?("icon_") || k.to_s.include?("evo_mark_") || k.to_s.include?("variant_mark_") || k == "cursor")
          v.visible = true
        end
      end
      draw_grid_interface
    end

    def user_label_from_key(key)
      sp = key[0]
      f = key[1]
      if should_mask_species_name?(sp, f)
        return "???"
      end
      s_data = GameData::Species.get_species_form(sp, f) rescue nil
      if f > 0 && s_data && s_data.form_name.to_s.strip.empty?
        return detail_variant_label(sp, f)
      end
      return changedex_display_name(sp, f)
    end

    def compact_user_list_text(users, max = 10)
      return "None" if users.nil? || users.empty?
      names = users.map { |k| user_label_from_key(k) }
      return names.join(", ") if names.length <= max
      shown = names[0, max]
      return "#{shown.join(', ')} +#{names.length - max} more"
    end

    def draw_entry_detail(entry)
      bmp = @sprites["overlay"].bitmap
      clear_pokemon_detail_sprites
      clear_entry_detail_carrier_icons
      bmp.clear
      name = if @category == :ability_changes || @category == :new_abilities
               ability_entry_name(entry)
             else
               move_entry_name(entry)
             end
      draw_header(current_category_title.upcase, name)
      draw_panel(bmp, 10, 52, 492, 166)
      draw_panel(bmp, 10, 228, 492, 146)
      y = 56
      if @category == :move_changes || @category == :new_moves
        move_data = GameData::Move.try_get(entry[:id])
        return if !move_data
        canon = VermeilChangeDex.canon_move_entry(entry[:id])
        dmg = move_damage_class(move_data).to_s.capitalize
        type_name = GameData::Type.get(move_data.type).name rescue move_data.type.to_s
        move_power = move_data.respond_to?(:power) ? move_data.power.to_i : move_data.base_damage.to_i
        power_txt = (move_power <= 0) ? "-" : move_power.to_s
        acc_txt = (move_data.accuracy.to_i <= 0) ? "-" : move_data.accuracy.to_i.to_s
        pp_txt = move_data.total_pp.to_i.to_s
        type_changed = @category == :move_changes && canon && canon[:type] && canon[:type] != move_data.type
        class_changed = @category == :move_changes && canon && canon[:dmg_class] && canon[:dmg_class] != move_damage_class(move_data)
        power_changed = @category == :move_changes && canon && !canon[:power].nil? && canon[:power].to_i != move_power.to_i
        acc_changed = @category == :move_changes && canon && !canon[:accuracy].nil? && canon[:accuracy].to_i != move_data.accuracy.to_i
        pp_changed = @category == :move_changes && canon && !canon[:total_pp].nil? && canon[:total_pp].to_i != move_data.total_pp.to_i
        pbDrawTextPositions(bmp, [["Type: #{type_name}", 20, y, :left, (type_changed ? COLOR_DIFF : COLOR_CANON)],
                                  ["Class: #{dmg}", 190, y, :left, (class_changed ? COLOR_DIFF : COLOR_VERMEIL)],
                                  ["Power: #{power_txt}", 340, y, :left, (power_changed ? COLOR_DIFF : COLOR_TEXT_MAIN)]])
        pbDrawTextPositions(bmp, [["Acc: #{acc_txt}", 20, y + 28, :left, (acc_changed ? COLOR_DIFF : COLOR_TEXT_GRAY)],
                                  ["PP: #{pp_txt}", 190, y + 28, :left, (pp_changed ? COLOR_DIFF : COLOR_TEXT_GRAY)]])
        desc = move_data.description.to_s
        draw_wrapped_text(bmp, desc, 20, y + 58, 468, COLOR_TEXT_GRAY, 22, 3)
      else
        a_data = GameData::Ability.try_get(entry[:id])
        return if !a_data
        draw_wrapped_text(bmp, a_data.description.to_s, 20, y, 468, COLOR_TEXT_GRAY, 22, 5)
      end
      draw_carrier_icon_window(bmp, entry)
      if @category == :move_changes && !move_change_lines(entry).empty?
        pbDrawTextPositions(bmp, [[_INTL("{1}: Before/After", @filter_key_name), SCREEN_W - 20, 352, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      end
      if (@category == :ability_changes || @category == :new_abilities)
        if !ability_before_after_lines(entry, @sprites["overlay"].bitmap).empty?
          pbDrawTextPositions(bmp, [[_INTL("{1}: Before/After", @filter_key_name), SCREEN_W - 20, 352, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
        elsif !ability_boost_sections(entry[:id]).empty?
          pbDrawTextPositions(bmp, [[_INTL("{1}: Boosted Moves", @filter_key_name), SCREEN_W - 20, 352, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
        end
      end
      if !pokemon_category?
        action_opts = detail_action_options
        if !action_opts.empty?
          header_hint = action_opts.length > 1 ? _INTL("{1}: Options", @action_key_name) : _INTL("{1}: {2}", @action_key_name, action_opts[0][1])
          pbDrawTextPositions(bmp, [[header_hint, SCREEN_W / 2, 12, :center, Color.new(255,255,255), Color.new(0,0,0,120)]])
        end
      end
    end

    def clear_pokemon_detail_sprites
      @sprites.keys.each do |k|
        ks = k.to_s
        next if ks != "big_icon" &&
                ks != "detail_variant_mark" &&
                ks != "evo_label_overlay" &&
                ks != "evo_method_popup" &&
                ks != "new_moves_popup" &&
                !ks.start_with?("evo_detail_")
        @sprites[k].dispose
        @sprites.delete(k)
      end
    end

    def clear_entry_detail_carrier_icons
      @sprites.keys.each do |k|
        next if !k.to_s.start_with?("carrier_detail_") &&
                !k.to_s.start_with?("carrier_popup_") &&
                !k.to_s.start_with?("carrier_mark_") &&
                !k.to_s.start_with?("carrier_variant_mark_")
        @sprites[k].dispose
        @sprites.delete(k)
      end
    end

    def draw_carrier_icon_window(bmp, entry)
      users = entry[:all_users] || []
      added = if @category == :move_changes || @category == :ability_changes
                entry[:added_users_comparable] || []
              else
                entry[:added_users] || []
              end
      pbDrawTextPositions(bmp, [["New Carriers:", 20, 244, :left, COLOR_HIGHLIGHT]])
      if added.empty?
        pbDrawTextPositions(bmp, [["None", 20, 268, :left, COLOR_TEXT_GRAY]])
      else
        draw_wrapped_text(bmp, compact_user_list_text(added, 8), 20, 268, 468, COLOR_MOVES_NEW, 22, 2)
      end
      pbDrawTextPositions(bmp, [["All Carriers: #{users.length}", 492, 244, :right, COLOR_TEXT_GRAY]])
    end

    def carrier_popup_page_size
      return 18
    end

    def show_carrier_popup(entry)
      return if !entry
      users = entry[:all_users] || []
      return if users.empty?
      hide_carrier_popup
      @carrier_popup_entry = entry
      @carrier_popup_page = 0
      redraw_carrier_popup
      @carrier_popup_open = true
    end

    def redraw_carrier_popup
      return if !@carrier_popup_entry
      clear_entry_detail_carrier_icons
      @sprites["carrier_popup"]&.dispose
      @sprites.delete("carrier_popup")
      @sprites["carrier_popup"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["carrier_popup"].z = 260
      bmp = @sprites["carrier_popup"].bitmap
      pbSetSystemFont(bmp)
      panel_x = 28
      panel_y = 72
      panel_w = SCREEN_W - 56
      panel_h = 276
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(20, 28, 40, 236))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, Color.new(88, 106, 138, 210))
      pbDrawTextPositions(bmp, [["Carriers", panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      users = carrier_popup_users_sorted(@carrier_popup_entry)
      new_users = (@carrier_popup_entry[:added_users] || [])
      new_lookup = {}
      new_users.each { |k| new_lookup[[k[0], k[1]]] = true }
      per_page = carrier_popup_page_size
      total_pages = [(users.length.to_f / per_page).ceil, 1].max
      @carrier_popup_page = [[@carrier_popup_page, 0].max, total_pages - 1].min
      start_idx = @carrier_popup_page * per_page
      page_users = users[start_idx, per_page] || []
      cols = 6
      step_x = 70
      step_y = 56
      start_x = panel_x + 36
      start_y = panel_y + 76
      page_users.each_with_index do |key, i|
        sp = key[0]
        f = key[1]
        spr = PokemonSpeciesIconSprite.new(nil, @viewport)
        spr.setOffset(PictureOrigin::CENTER)
        spr.x = start_x + ((i % cols) * step_x)
        spr.y = start_y + ((i / cols) * step_y)
        spr.z = 270
        spr.pbSetParams(sp, 0, f, false)
        if should_mask_species_name?(sp, f)
          spr.tone = Tone.new(-255, -255, -255)
          spr.color = Color.new(0, 0, 0, 180)
        end
        @sprites["carrier_popup_#{i}"] = spr
        if new_lookup[[sp, f]]
          mark = IconSprite.new(0, 0, @viewport)
          mark.setBitmap("Graphics/UI/NewCarrierIcon")
          mark.x = spr.x + 8
          mark.y = spr.y - 22
          mark.z = 275
          mark_key = "carrier_mark_#{i}"
          @sprites[mark_key] = mark
          @carrier_mark_base_y[mark_key] = mark.y
        end
        vframe = hidden_variant_icon_frame(sp, f)
        if !vframe.nil?
          vmark = IconSprite.new(0, 0, @viewport)
          vmark.setBitmap("Graphics/UI/RegionalVariantIcon")
          vmark.src_rect.set(vframe * 32, 0, 32, 32)
          vmark.x = spr.x - 32
          vmark.y = spr.y - 36
          vmark.z = 274
          vkey = "carrier_variant_mark_#{i}"
          @sprites[vkey] = vmark
          @carrier_mark_base_y[vkey] = vmark.y
        end
      end
      page_txt = _INTL("Page {1}/{2}", @carrier_popup_page + 1, total_pages)
      pbDrawTextPositions(bmp, [[page_txt, panel_x + panel_w - 12, panel_y + panel_h - 28, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      controls = _INTL("L/R: Page  {1}/{2}: Close", @action_key_name, "X")
      pbDrawTextPositions(bmp, [[controls, panel_x + 12, panel_y + panel_h - 28, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
    end

    def carrier_popup_users_sorted(entry)
      all_users = (entry[:all_users] || []).map { |k| [k[0], k[1]] }
      added = (entry[:added_users] || []).map { |k| [k[0], k[1]] }
      added_lookup = {}
      added.each { |k| added_lookup[[k[0], k[1]]] = true }
      new_first = []
      old_rest = []
      all_users.each do |k|
        if added_lookup[[k[0], k[1]]]
          new_first << k
        else
          old_rest << k
        end
      end
      sort_proc = proc { |k| [@dex_order[k[0]] || 999_999, k[1]] }
      new_first.sort_by!(&sort_proc)
      old_rest.sort_by!(&sort_proc)
      return new_first + old_rest
    end

    def hide_carrier_popup
      @carrier_popup_open = false
      @carrier_popup_entry = nil
      @carrier_mark_base_y = {}
      @sprites["carrier_popup"]&.dispose
      @sprites.delete("carrier_popup")
      clear_entry_detail_carrier_icons
    end

    def update_carrier_mark_animation
      return if !@carrier_mark_base_y || @carrier_mark_base_y.empty?
      bob = Math.sin(System.uptime * 6.0) * 2.0
      @carrier_mark_base_y.each do |k, base_y|
        spr = @sprites[k]
        next if !spr || spr.disposed?
        spr.y = (base_y + bob).round
      end
    end

    def update_detail_variant_mark_animation
      return if !@detail_variant_mark_base_y
      spr = @sprites["detail_variant_mark"]
      return if !spr || spr.disposed?
      bob = Math.sin(System.uptime * 6.0) * 2.0
      spr.y = (@detail_variant_mark_base_y + bob).round
    end

    def draw_detail_view(species, form)
      hide_new_moves_popup
      bmp = @sprites["overlay"].bitmap; bmp.clear; canon = VermeilChangeDex.get_canon_info(species, form)
      canon ||= VermeilChangeDex.get_canon_info(species, 0)
      @detail_species = species
      @detail_form = form
      vermeil = GameData::Species.get_species_form(species, form)
      base_species_name = begin
        GameData::Species.get(species).name.to_s
      rescue StandardError
        changedex_display_name(species, form)
      end
      form_name = vermeil.form_name.to_s.strip
      if form > 0 && !form_name.empty?
        # Visible named forms (e.g. Alolan Meowth): show form name directly.
        draw_header("COMPARISON", changedex_display_name(species, form))
      else
        # Hidden forms (e.g. Cubone/Koffing-style): keep base name and show
        # inferred variant tag in muted color beside it.
        draw_header("COMPARISON", base_species_name)
        if form > 0
          variant_tag = inferred_variant_name(species, form).to_s.strip
          if !variant_tag.empty? && !variant_tag.downcase.start_with?(base_species_name.downcase)
            base_w = @sprites["overlay"].bitmap.text_size(base_species_name).width
            tag_x = SCREEN_W - 22 - base_w - 8
            pbDrawTextPositions(@sprites["overlay"].bitmap, [[variant_tag, tag_x, 12, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
          end
        end
      end
      @detail_has_evo_method_changes = has_evolution_method_changes?(vermeil, canon)
      # Block panels for clearer visual hierarchy.
      draw_panel(bmp, 10, 52, 150, 170)   # Left: sprite + typing
      draw_panel(bmp, 170, 52, 332, 174)  # Right: stat comparison
      if @sprites["big_icon"] && !@sprites["big_icon"].disposed?
        @sprites["big_icon"].dispose
      end
      if @sprites["detail_variant_mark"] && !@sprites["detail_variant_mark"].disposed?
        @sprites["detail_variant_mark"].dispose
        @sprites.delete("detail_variant_mark")
      end
      @detail_variant_mark_base_y = nil
      @sprites["big_icon"] = PokemonSpeciesIconSprite.new(nil, @viewport)
      @sprites["big_icon"].setOffset(PictureOrigin::CENTER); @sprites["big_icon"].x, @sprites["big_icon"].y = LEFT_PANEL_CENTER_X, 92
      @sprites["big_icon"].z = 210; @sprites["big_icon"].pbSetParams(species, 0, form, false)
      vframe = hidden_variant_icon_frame(species, form)
      if !vframe.nil?
        mark = IconSprite.new(0, 0, @viewport)
        mark.setBitmap("Graphics/UI/RegionalVariantIcon")
        mark.src_rect.set(vframe * 32, 0, 32, 32)
        mark.x = LEFT_PANEL_CENTER_X - 40
        mark.y = 52
        mark.z = 212
        @sprites["detail_variant_mark"] = mark
        @detail_variant_mark_base_y = mark.y
      end
      
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
      v_stats = species_stats_array(vermeil)
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
      
      # MOVES SECTION (isolated comparisons)
      v_moves = vermeil.moves.map { |m| m[1] }.uniq
      v_tutor_moves = (vermeil.respond_to?(:tutor_moves) ? (vermeil.tutor_moves || []).compact.uniq : [])
      c_pool = (canon[:level_moves] + canon[:tutor_moves] + canon[:egg_moves]).uniq
      c_tutor = (canon[:tutor_moves] || []).compact.uniq
      level_added_names = (v_moves - c_pool).map { |m| GameData::Move.get(m).name }
      tutor_added_names = (v_tutor_moves - c_tutor).map { |m| GameData::Move.get(m).name }
      moves_header_y = [296, abilities_end_y + 6].max
      draw_panel(bmp, 10, moves_header_y - 6, 492, 126)
      draw_move_change_section(bmp, level_added_names, tutor_added_names, moves_header_y)
      action_opts = detail_action_options
      if !action_opts.empty?
        header_hint = action_opts.length > 1 ? _INTL("{1}: Options", @action_key_name) : _INTL("{1}: {2}", @action_key_name, action_opts[0][1])
        pbDrawTextPositions(bmp, [[header_hint, (SCREEN_W / 2) - 28, 12, :center, Color.new(255,255,255), Color.new(0,0,0,120)]])
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

    def draw_move_change_section(bmp, level_list, tutor_list, header_y = 296)
      y = header_y
      combined = []
      combined.concat(level_list || [])
      (tutor_list || []).each { |name| combined << name if !combined.include?(name) }
      @detail_move_popup_lines = []
      @detail_moves_truncated = false
      if !combined.empty?
        @detail_move_popup_lines = wrapped_move_list_lines(bmp, combined, move_popup_usable_width)
        @detail_moves_truncated = @detail_move_popup_lines.length > 2
      end
      pbDrawTextPositions(bmp, [["New Moves:", 20, y, :left, COLOR_HIGHLIGHT]])
      if @detail_moves_truncated
        hint_txt = _INTL("{1} - More Info", @filter_key_name)
        pbDrawTextPositions(bmp, [[hint_txt, 148, y, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      end
      y += 22
      if combined.empty?
        draw_wrapped_text(bmp, "No moves added to this Pokémon.", 20, y, 470, COLOR_TEXT_GRAY, 22, 2)
      else
        full_text = combined.join(", ")
        draw_wrapped_text(bmp, full_text, 20, y, 470, COLOR_MOVES_NEW, 22, 2)
      end
    end

    def wrapped_move_list_lines(bmp, move_names, max_w)
      names = (move_names || []).map { |m| m.to_s.strip }.reject { |m| m.empty? }
      return [] if names.empty?
      lines = []
      line = ""
      names.each_with_index do |name, i|
        token = (i == names.length - 1) ? name : "#{name}, "
        if line.empty?
          line = token
          next
        end
        candidate = line + token
        if bmp.text_size(candidate).width > max_w
          lines << line.sub(/,\s*$/, "")
          line = token
        else
          line = candidate
        end
      end
      lines << line.sub(/,\s*$/, "") if !line.empty?
      return lines
    end

    def wrapped_text_lines(bmp, text, max_w)
      words = text.to_s.split(/\s+/)
      return [] if words.empty?
      lines = []
      line = ""
      words.each do |w|
        candidate = line.empty? ? w : "#{line} #{w}"
        if bmp.text_size(candidate).width > max_w && !line.empty?
          lines << line
          line = w
        else
          line = candidate
        end
      end
      lines << line if !line.empty?
      return lines
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
          if @move_rework_popup_open
            if Input.repeat?(Input::LEFT)
              @move_rework_popup_page -= 1
              redraw_move_rework_popup
            elsif Input.repeat?(Input::RIGHT)
              @move_rework_popup_page += 1
              redraw_move_rework_popup
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Input.trigger?(Input::SPECIAL)
              hide_move_rework_popup(false)
            end
            next
          end
          if @category_panel_open
            if Input.repeat?(Input::UP)
              @category_panel_index = [@category_panel_index - 1, 0].max
              pbPlayCursorSE
              draw_category_panel
              next
            end
            if Input.repeat?(Input::DOWN)
              @category_panel_index = [@category_panel_index + 1, category_options.length - 1].min
              pbPlayCursorSE
              draw_category_panel
              next
            end
            if Input.trigger?(Input::USE) || Input.trigger?(Input::ACTION)
              close_category_menu(true)
              next
            end
            if Input.trigger?(Input::BACK) || Input.trigger?(Input::SPECIAL)
              if Input.trigger?(Input::BACK)
                break
              else
                close_category_menu(false)
              end
              next
            end
            next
          end
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
          if pokemon_category?
            if @jump_up_input && Input.repeat?(@jump_up_input)
              old_page = (@index / GRID_PAGE_SIZE)
              @index = [@index - GRID_PAGE_SIZE, 0].max
              if @index != old_page * GRID_PAGE_SIZE
                pbPlayCursorSE
                draw_grid_interface
              end
              next
            end
            if @jump_down_input && Input.repeat?(@jump_down_input)
              old_idx = @index
              @index = [@index + GRID_PAGE_SIZE, @entries.length - 1].min
              if @index != old_idx
                pbPlayCursorSE
                draw_grid_interface
              end
              next
            end
          else
            if @jump_up_input && Input.repeat?(@jump_up_input)
              move_cursor(0, -8)
              next
            end
            if @jump_down_input && Input.repeat?(@jump_down_input)
              move_cursor(0, 8)
              next
            end
          end
          move_cursor(-1, 0) if Input.repeat?(Input::LEFT); move_cursor(1, 0) if Input.repeat?(Input::RIGHT)
          move_cursor(0, -1) if Input.repeat?(Input::UP); move_cursor(0, 1) if Input.repeat?(Input::DOWN)
          if Input.trigger?(Input::BACK)
            open_category_menu(false, true, true)
            next
          end
        else
          if @detail_variant_menu_open
            if Input.repeat?(Input::UP)
              @detail_variant_menu_index = [@detail_variant_menu_index - 1, 0].max
              pbPlayCursorSE
              draw_detail_variant_menu
              next
            end
            if Input.repeat?(Input::DOWN)
              @detail_variant_menu_index = [@detail_variant_menu_index + 1, @detail_variant_menu_options.length - 1].min
              pbPlayCursorSE
              draw_detail_variant_menu
              next
            end
            if Input.trigger?(Input::ACTION) || Input.trigger?(Input::USE)
              sel = @detail_variant_menu_options[@detail_variant_menu_index]
              close_detail_variant_menu
              if sel
                chosen_form = sel[0]
                if @detail_form_options.include?(chosen_form)
                  @detail_form_option_index = @detail_form_options.index(chosen_form) || 0
                  @detail_form = chosen_form
                  draw_detail_view(@detail_species, @detail_form)
                  pbPlayCursorSE
                else
                  pbPlayBuzzerSE
                end
              else
                pbPlayBuzzerSE
              end
              next
            end
            if Input.trigger?(Input::BACK) || Input.trigger?(Input::SPECIAL)
              close_detail_variant_menu
              pbPlayCancelSE
              next
            end
          end
          if @detail_action_menu_open
            if Input.repeat?(Input::UP)
              @detail_action_menu_index = [@detail_action_menu_index - 1, 0].max
              pbPlayCursorSE
              draw_detail_action_menu
              next
            end
            if Input.repeat?(Input::DOWN)
              @detail_action_menu_index = [@detail_action_menu_index + 1, @detail_action_menu_options.length - 1].min
              pbPlayCursorSE
              draw_detail_action_menu
              next
            end
            if Input.trigger?(Input::ACTION) || Input.trigger?(Input::USE)
              sel = @detail_action_menu_options[@detail_action_menu_index]
              close_detail_action_menu
              if sel && perform_detail_action(sel[0])
                pbPlayCursorSE
              else
                pbPlayBuzzerSE
              end
              next
            end
            if Input.trigger?(Input::BACK) || Input.trigger?(Input::SPECIAL)
              close_detail_action_menu
              pbPlayCancelSE
              next
            end
          end
          if @ability_moves_popup_open
            if Input.repeat?(Input::LEFT)
              @ability_moves_popup_page -= 1
              redraw_ability_moves_popup
            elsif Input.repeat?(Input::RIGHT)
              @ability_moves_popup_page += 1
              redraw_ability_moves_popup
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Input.trigger?(Input::SPECIAL)
              hide_ability_moves_popup(false)
            end
            next
          end
          if @ability_rework_popup_open
            if Input.repeat?(Input::LEFT)
              @ability_rework_popup_page -= 1
              redraw_ability_rework_popup
            elsif Input.repeat?(Input::RIGHT)
              @ability_rework_popup_page += 1
              redraw_ability_rework_popup
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Input.trigger?(Input::SPECIAL)
              hide_ability_rework_popup(false)
            end
            next
          end
          if @move_rework_popup_open
            if Input.repeat?(Input::LEFT)
              @move_rework_popup_page -= 1
              redraw_move_rework_popup
            elsif Input.repeat?(Input::RIGHT)
              @move_rework_popup_page += 1
              redraw_move_rework_popup
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Input.trigger?(Input::SPECIAL)
              hide_move_rework_popup(false)
            end
            next
          end
          if @moves_popup_open
            if Input.repeat?(Input::LEFT)
              @moves_popup_page -= 1
              redraw_new_moves_popup
            elsif Input.repeat?(Input::RIGHT)
              @moves_popup_page += 1
              redraw_new_moves_popup
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Input.trigger?(Input::SPECIAL)
              # Keep cached wrapped lines so the popup can be reopened
              # without changing entry.
              hide_new_moves_popup(false)
            end
            next
          end
          if @carrier_popup_open
            if Input.repeat?(Input::LEFT)
              @carrier_popup_page -= 1
              redraw_carrier_popup
            elsif Input.repeat?(Input::RIGHT)
              @carrier_popup_page += 1
              redraw_carrier_popup
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
              hide_carrier_popup
            end
            next
          end
          if @evo_popup_open
            if Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
              hide_evolution_method_popup
            end
            next
          end
          if Input.trigger?(Input::SPECIAL)
            if @category == :move_changes
              show_move_rework_popup(@entries[@index])
            elsif pokemon_category? && @detail_moves_truncated
              show_new_moves_popup
            elsif @category == :ability_changes || @category == :new_abilities
              entry = @entries[@index]
              if !ability_before_after_lines(entry, @sprites["overlay"].bitmap).empty?
                show_ability_rework_popup(entry)
              elsif !ability_boost_sections(entry[:id]).empty?
                show_ability_moves_popup(entry)
              else
                pbPlayBuzzerSE
              end
            else
              pbPlayBuzzerSE
            end
            next
          end
          if Input.trigger?(Input::ACTION)
            if pokemon_category?
              if open_detail_action_menu
                pbPlayCursorSE
              else
                pbPlayBuzzerSE
              end
            else
              entry = @entries[@index]
              users = entry ? (entry[:all_users] || []) : []
              if users.empty?
                pbPlayBuzzerSE
              else
                show_carrier_popup(entry)
              end
            end
            next
          end
          if @jump_up_input && Input.repeat?(@jump_up_input)
            detail_step = pokemon_category? ? GRID_PAGE_SIZE : 8
            move_detail_cursor(-detail_step)
            next
          end
          if @jump_down_input && Input.repeat?(@jump_down_input)
            detail_step = pokemon_category? ? GRID_PAGE_SIZE : 8
            move_detail_cursor(detail_step)
            next
          end
          if Input.repeat?(Input::LEFT) || Input.repeat?(Input::UP)
            move_detail_cursor(-1)
            next
          end
          if Input.repeat?(Input::RIGHT) || Input.repeat?(Input::DOWN)
            move_detail_cursor(1)
            next
          end
          switch_to_grid if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        end
      end
    end

    def move_detail_cursor(delta)
      return if @entries.empty?
      old_idx = @index
      @index = [[@index + delta, 0].max, @entries.length - 1].min
      return if @index == old_idx
      pbPlayCursorSE
      if pokemon_category?
        close_detail_action_menu if @detail_action_menu_open
        close_detail_variant_menu if @detail_variant_menu_open
        clear_evolution_method_popup if @evo_popup_open
        hide_new_moves_popup if @moves_popup_open
        sp = @entries[@index][0]
        form = @entries[@index][1]
        prepare_detail_form_options(sp, form)
        draw_detail_view(sp, @detail_form_options[@detail_form_option_index] || form)
      else
        hide_carrier_popup if @carrier_popup_open
        hide_ability_moves_popup if @ability_moves_popup_open
        hide_ability_rework_popup if @ability_rework_popup_open
        hide_move_rework_popup if @move_rework_popup_open
        draw_entry_detail(@entries[@index])
      end
    end

    def pbUpdate
      pbUpdateSpriteHash(@sprites)
      update_evo_mark_animation if @mode == :grid
      update_variant_mark_animation if @mode == :grid
      update_scroll_arrow_animation if @mode == :grid
      update_carrier_mark_animation
      update_detail_variant_mark_animation if @mode == :detail
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
