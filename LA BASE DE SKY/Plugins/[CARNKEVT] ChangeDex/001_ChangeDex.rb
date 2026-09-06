#===============================================================================
# ChangeDex Data Layer
# PBS = baseline / JSON = only project changes
#===============================================================================
module CarnekChangeData
  JSON_PATH = "Data/ChangeDex/pokemon_changes.json"
  SCHEMA_VERSION = 5
  @applied = false
  @applying = false
  @applied_signature = nil
  @document_cache = nil
  @document_signature = nil
  @document_last_check = 0.0
  @document_check_interval = 0.50
  @last_json_error = nil

  class JsonReader
    def initialize(text)
      @s = text.to_s
      @i = 0
    end
    def parse
      skip_ws
      value = parse_value
      skip_ws
      return value
    end
    def parse_value
      skip_ws
      ch = @s[@i, 1]
      return parse_object if ch == "{"
      return parse_array if ch == "["
      return parse_string if ch == '"'
      return parse_number if ch == "-" || (ch && ch >= "0" && ch <= "9")
      return read_literal("true", true) if @s[@i, 4] == "true"
      return read_literal("false", false) if @s[@i, 5] == "false"
      return read_literal("null", nil) if @s[@i, 4] == "null"
      raise "Invalid JSON near byte #{@i}"
    end
    def parse_object
      obj = {}; @i += 1; skip_ws
      if @s[@i, 1] == "}"; @i += 1; return obj; end
      loop do
        skip_ws; key = parse_string; skip_ws
        raise "Expected ':' in JSON" if @s[@i, 1] != ":"
        @i += 1; obj[key] = parse_value; skip_ws
        ch = @s[@i, 1]; @i += 1
        break if ch == "}"
        raise "Expected ',' in JSON" if ch != ","
      end
      obj
    end
    def parse_array
      arr = []; @i += 1; skip_ws
      if @s[@i, 1] == "]"; @i += 1; return arr; end
      loop do
        arr << parse_value; skip_ws
        ch = @s[@i, 1]; @i += 1
        break if ch == "]"
        raise "Expected ',' in JSON" if ch != ","
      end
      arr
    end
    def parse_string
      raise "Expected string in JSON" if @s[@i, 1] != '"'
      @i += 1; out = ""
      while @i < @s.length
        ch = @s[@i, 1]; @i += 1
        return out if ch == '"'
        if ch == "\\"
          esc = @s[@i, 1]; @i += 1
          case esc
          when '"', "\\", "/" then out << esc
          when "b" then out << "\b"
          when "f" then out << "\f"
          when "n" then out << "\n"
          when "r" then out << "\r"
          when "t" then out << "\t"
          when "u"
            hex = @s[@i, 4]; @i += 4
            code = hex.to_i(16)
            begin
              out << [code].pack("U")
            rescue StandardError
              out << "?"
            end
          else
            raise "Invalid JSON escape"
          end
        else
          out << ch
        end
      end
      raise "Unterminated JSON string"
    end
    def parse_number
      start = @i
      @i += 1 if @s[@i, 1] == "-"
      @i += 1 while @s[@i, 1] && @s[@i, 1] =~ /[0-9]/
      if @s[@i, 1] == "."
        @i += 1
        @i += 1 while @s[@i, 1] && @s[@i, 1] =~ /[0-9]/
      end
      if @s[@i, 1] =~ /[eE]/
        @i += 1; @i += 1 if @s[@i, 1] =~ /[+-]/
        @i += 1 while @s[@i, 1] && @s[@i, 1] =~ /[0-9]/
      end
      raw = @s[start...@i]
      return raw.to_f if raw.include?(".") || raw =~ /[eE]/
      raw.to_i
    end
    def read_literal(word, value)
      raise "Invalid JSON literal" if @s[@i, word.length] != word
      @i += word.length; value
    end
    def skip_ws
      @i += 1 while @s[@i, 1] && @s[@i, 1] =~ /\s/
    end
  end

  def self.empty_document
    return { "schema" => SCHEMA_VERSION, "species" => {}, "moves" => {}, "abilities" => {}, "localization" => { "es" => { "species" => {}, "moves" => {}, "abilities" => {}, "items" => {}, "types" => {}, "strings" => {} }, "en" => { "species" => {}, "moves" => {}, "abilities" => {}, "items" => {}, "types" => {}, "strings" => {} } } }
  end

  # Files opened with "rb" are ASCII-8BIT in Ruby.  The old reader then used
  # UTF-8 regexps directly on those bytes, which raised Encoding::CompatibilityError
  # before a single override could be applied.  Normalize once, before parsing.
  def self.utf8_text(raw)
    s = raw.to_s.dup
    if s.bytesize >= 3 && s.getbyte(0) == 0xEF && s.getbyte(1) == 0xBB && s.getbyte(2) == 0xBF
      s = s.byteslice(3, s.bytesize - 3) || ""
    end
    begin
      s.force_encoding(Encoding::UTF_8)
      s = s.encode(Encoding::UTF_8, :invalid => :replace, :undef => :replace, :replace => "") unless s.valid_encoding?
    rescue StandardError
      begin
        s.force_encoding("UTF-8")
      rescue StandardError
      end
    end
    return s
  end

  def self.json_signature
    return nil if !File.file?(JSON_PATH)
    return [File.size(JSON_PATH).to_i, File.mtime(JSON_PATH).to_f]
  rescue StandardError
    return nil
  end

  def self.monotonic_time
    return System.uptime.to_f if defined?(System) && System.respond_to?(:uptime)
    return Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f if defined?(Process) && Process.respond_to?(:clock_gettime)
    return Time.now.to_f
  rescue StandardError
    return Time.now.to_f rescue 0.0
  end

  def self.invalidate_document_cache!
    @document_cache = nil
    @document_signature = nil
    @document_last_check = 0.0
    @last_json_error = nil
  end

  def self.parse_json_text(text)
    begin
      if !defined?(JSON)
        begin
          require "json"
        rescue LoadError
        end
      end
      return JSON.parse(text) if defined?(JSON) && JSON.respond_to?(:parse)
    rescue StandardError
      # Essentials distributions without Ruby JSON keep using the bundled reader.
    end
    return JsonReader.new(text).parse
  end

  def self.document
    # Game-wide localization can ask for names/descriptions hundreds of times
    # per frame. Never stat the JSON file for every getter call. Recheck at a
    # short interval so Studio edits are still picked up live without turning
    # File.size/File.mtime into a hot-path cost.
    now = monotonic_time
    if @document_cache && (now - (@document_last_check || 0.0)) < (@document_check_interval || 0.50)
      return @document_cache
    end
    @document_last_check = now
    sig = json_signature
    return empty_document if !sig
    return @document_cache if @document_cache && @document_signature == sig
    raw = File.open(JSON_PATH, "rb") { |f| f.read }
    doc = parse_json_text(utf8_text(raw))
    doc = empty_document if !doc.is_a?(Hash)
    doc["species"] = {} if !doc["species"].is_a?(Hash)
    doc["moves"] = {} if !doc["moves"].is_a?(Hash)
    doc["abilities"] = {} if !doc["abilities"].is_a?(Hash)
    doc["localization"] = {} if !doc["localization"].is_a?(Hash)
    ["es", "en"].each do |lang|
      doc["localization"][lang] = {} if !doc["localization"][lang].is_a?(Hash)
      ["species", "moves", "abilities", "items", "types", "strings"].each { |bucket| doc["localization"][lang][bucket] = {} if !doc["localization"][lang][bucket].is_a?(Hash) }
    end
    @document_cache = doc
    @document_signature = sig
    @last_json_error = nil
    return doc
  rescue StandardError => e
    msg = e.message.to_s
    if @last_json_error != msg && defined?(echoln)
      echoln("[ChangeDex] JSON error: #{msg}")
      @last_json_error = msg
    end
    return empty_document
  end

  def self.csv(value)
    return [] if value.nil?
    return value if value.is_a?(Array)
    value.to_s.split(",").map { |x| x.strip }.reject { |x| x.empty? }
  end

  def self.int_or_symbol(value)
    s = value.to_s.strip
    return nil if s.empty?
    return s.to_i if s =~ /^-?\d+$/
    return s.to_f if s =~ /^-?\d+\.\d+$/
    return s.to_sym
  end

  def self.find_species_record(species, form)
    return nil if !defined?(GameData::Species) || !GameData::Species.const_defined?(:DATA)
    data = GameData::Species.const_get(:DATA)
    return nil if !data
    sig = [data.object_id, data.length.to_i]
    if !@species_record_index || @species_record_index_signature != sig
      index = {}
      data.each_value do |entry|
        next if !entry
        begin
          index[[entry.species.to_sym, entry.form.to_i]] = entry
        rescue StandardError
        end
      end
      @species_record_index = index
      @species_record_index_signature = sig
    end
    return @species_record_index[[species.to_sym, form.to_i]]
  rescue StandardError
    return nil
  end

  def self.assign(entry, field, raw)
    case field.to_s
    when "Types"
      entry.instance_variable_set(:@types, csv(raw).map { |x| x.to_sym })
    when "BaseStats"
      vals = csv(raw).map { |x| x.to_i }
      keys = [:HP, :ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE]
      h = {}; keys.each_with_index { |k, i| h[k] = vals[i].to_i }
      entry.instance_variable_set(:@base_stats, h)
    when "Abilities"
      entry.instance_variable_set(:@abilities, csv(raw).map { |x| x.to_sym })
    when "HiddenAbilities"
      entry.instance_variable_set(:@hidden_abilities, csv(raw).map { |x| x.to_sym })
    when "Moves"
      parts = csv(raw); list = []
      parts.each_slice(2) { |lvl, move| list << [lvl.to_i, move.to_s.to_sym] if move && !move.to_s.empty? }
      entry.instance_variable_set(:@moves, list)
    when "TutorMoves"
      entry.instance_variable_set(:@tutor_moves, csv(raw).map { |x| x.to_sym })
    when "EggMoves"
      entry.instance_variable_set(:@egg_moves, csv(raw).map { |x| x.to_sym })
    when "Evolutions"
      parts = csv(raw); list = []
      parts.each_slice(3) do |sp, method, param|
        next if !sp || sp.to_s.empty?
        list << [sp.to_s.to_sym, (method && !method.to_s.empty?) ? method.to_s.to_sym : :None, int_or_symbol(param)]
      end
      entry.instance_variable_set(:@evolutions, list)
    when "EVs"
      parts = csv(raw); h = {}
      parts.each_slice(2) { |stat, amount| h[stat.to_s.to_sym] = amount.to_i if stat && amount }
      entry.instance_variable_set(:@evs, h)
    when "EggGroups"
      entry.instance_variable_set(:@egg_groups, csv(raw).map { |x| x.to_sym })
    when "Flags"
      entry.instance_variable_set(:@flags, csv(raw))
    when "BaseExp", "CatchRate", "Happiness", "HatchSteps", "Generation"
      iv = { "BaseExp"=>:@base_exp, "CatchRate"=>:@catch_rate, "Happiness"=>:@happiness,
             "HatchSteps"=>:@hatch_steps, "Generation"=>:@generation }[field.to_s]
      entry.instance_variable_set(iv, raw.to_i)
    when "Height", "Weight"
      iv = field.to_s == "Height" ? :@height : :@weight
      entry.instance_variable_set(iv, raw.to_f)
    when "GenderRatio", "GrowthRate", "Color", "Shape", "Habitat"
      iv = { "GenderRatio"=>:@gender_ratio, "GrowthRate"=>:@growth_rate, "Color"=>:@color,
             "Shape"=>:@shape, "Habitat"=>:@habitat }[field.to_s]
      entry.instance_variable_set(iv, raw.to_s.to_sym)
    end
  end

  def self.find_move_record(id)
    return nil if !defined?(GameData::Move)
    return GameData::Move.try_get(id.to_sym) rescue nil
  end

  def self.find_ability_record(id)
    return nil if !defined?(GameData::Ability)
    return GameData::Ability.try_get(id.to_sym) rescue nil
  end

  def self.assign_move(entry, field, raw)
    return if !entry
    case field.to_s
    when "Type"          then entry.instance_variable_set(:@type, raw.to_s.to_sym)
    when "Category"
      current = entry.instance_variable_get(:@category) rescue nil
      if current.is_a?(Integer)
        map = { "physical" => 0, "special" => 1, "status" => 2 }
        entry.instance_variable_set(:@category, map[raw.to_s.downcase] || current)
      else
        entry.instance_variable_set(:@category, raw.to_s.downcase.to_sym)
      end
    when "Power"         then entry.instance_variable_set(:@power, raw.to_i)
    when "Accuracy"      then entry.instance_variable_set(:@accuracy, raw.to_i)
    when "TotalPP"       then entry.instance_variable_set(:@total_pp, raw.to_i)
    when "Target"        then entry.instance_variable_set(:@target, raw.to_s.to_sym)
    when "Priority"      then entry.instance_variable_set(:@priority, raw.to_i)
    when "FunctionCode"  then entry.instance_variable_set(:@function_code, raw.to_s)
    when "EffectChance"  then entry.instance_variable_set(:@effect_chance, raw.to_i)
    when "Flags"         then entry.instance_variable_set(:@flags, csv(raw))
    when "Name"
      entry.instance_variable_set(:@real_name, raw.to_s)
      entry.instance_variable_set(:@name, raw.to_s) if entry.instance_variable_defined?(:@name)
    when "Description"
      entry.instance_variable_set(:@real_description, raw.to_s)
      entry.instance_variable_set(:@description, raw.to_s) if entry.instance_variable_defined?(:@description)
    end
  end

  def self.assign_ability(entry, field, raw)
    return if !entry
    case field.to_s
    when "Name"
      entry.instance_variable_set(:@real_name, raw.to_s)
      entry.instance_variable_set(:@name, raw.to_s) if entry.instance_variable_defined?(:@name)
    when "Description"
      entry.instance_variable_set(:@real_description, raw.to_s)
      entry.instance_variable_set(:@description, raw.to_s) if entry.instance_variable_defined?(:@description)
    when "Flags"       then entry.instance_variable_set(:@flags, csv(raw))
    end
  end

  def self.move_category_value(raw, fallback = 2)
    return raw.to_i if raw.is_a?(Integer) || raw.to_s =~ /^\d+$/
    map = { "physical" => 0, "special" => 1, "status" => 2 }
    return map.fetch(raw.to_s.downcase, fallback)
  end

  def self.default_entity_name(id)
    txt = id.to_s.gsub(/_+/, " ").strip
    return id.to_s if txt.empty?
    return txt.split(/\s+/).map { |w| w[0,1].to_s.upcase + w[1..-1].to_s.downcase }.join(" ")
  end

  def self.register_move_record(id, fields)
    entry = find_move_record(id)
    return entry if entry
    return nil if !defined?(GameData::Move) || !GameData::Move.respond_to?(:register)
    h = {
      :id => id.to_s.to_sym,
      :name => fields["Name"].to_s.strip.empty? ? default_entity_name(id) : fields["Name"].to_s,
      :type => (fields["Type"].to_s.strip.empty? ? :NORMAL : fields["Type"].to_s.to_sym),
      :category => move_category_value(fields["Category"], 2),
      :power => (fields.key?("Power") ? fields["Power"].to_i : 0),
      :accuracy => (fields.key?("Accuracy") ? fields["Accuracy"].to_i : 100),
      :total_pp => (fields.key?("TotalPP") ? fields["TotalPP"].to_i : 5),
      :target => (fields["Target"].to_s.strip.empty? ? :NearOther : fields["Target"].to_s.to_sym),
      :priority => (fields.key?("Priority") ? fields["Priority"].to_i : 0),
      :function_code => (fields["FunctionCode"].to_s.strip.empty? ? "None" : fields["FunctionCode"].to_s),
      :effect_chance => (fields.key?("EffectChance") ? fields["EffectChance"].to_i : 0),
      :flags => csv(fields["Flags"]),
      :description => fields["Description"].to_s
    }
    GameData::Move.register(h)
    return find_move_record(id)
  rescue StandardError => e
    echoln("[ChangeDex] Could not register Move #{id}: #{e.message}") if defined?(echoln) && (!defined?(ChangeDexConfig) || ChangeDexConfig.debug_logging?)
    return nil
  end

  def self.register_ability_record(id, fields)
    entry = find_ability_record(id)
    return entry if entry
    return nil if !defined?(GameData::Ability) || !GameData::Ability.respond_to?(:register)
    h = {
      :id => id.to_s.to_sym,
      :name => fields["Name"].to_s.strip.empty? ? default_entity_name(id) : fields["Name"].to_s,
      :description => fields["Description"].to_s,
      :flags => csv(fields["Flags"])
    }
    GameData::Ability.register(h)
    return find_ability_record(id)
  rescue StandardError => e
    echoln("[ChangeDex] Could not register Ability #{id}: #{e.message}") if defined?(echoln) && (!defined?(ChangeDexConfig) || ChangeDexConfig.debug_logging?)
    return nil
  end

  def self.data_signature(klass)
    return nil if !klass || !klass.const_defined?(:DATA)
    data = klass.const_get(:DATA) rescue nil
    return nil if !data
    # Kept intentionally O(1): this is checked by hot GameData getters. Full
    # reloads are caught by the post-load hooks below.
    return [data.object_id, data.length.to_i]
  rescue StandardError
    return nil
  end

  # Essentials/compilers can replace or repopulate GameData after plugins load.
  # Remember the actual registries that received the overrides instead of a single
  # boolean, so a later reload automatically receives the JSON again.
  def self.registry_signature
    return [
      (defined?(GameData::Species) ? data_signature(GameData::Species) : nil),
      (defined?(GameData::Move) ? data_signature(GameData::Move) : nil),
      (defined?(GameData::Ability) ? data_signature(GameData::Ability) : nil)
    ]
  end

  def self.apply!
    return false if @applying
    return false if !defined?(GameData::Species) || !GameData::Species.const_defined?(:DATA)
    data = GameData::Species.const_get(:DATA) rescue nil
    return false if !data || data.empty?
    current_signature = registry_signature
    return true if @applied && @applied_signature == current_signature
    @applying = true
    doc = document

    # Register JSON-only entities first so Species learnsets/abilities can point to
    # a real GameData record during the same boot. Existing records are mutated.
    move_count = 0
    (doc["moves"] || {}).each do |id, fields|
      next if !fields.is_a?(Hash)
      existed = !!find_move_record(id)
      entry = find_move_record(id) || register_move_record(id, fields)
      next if !entry
      fields.each do |field, value|
        next if field.to_s.start_with?("_")
        # Existing PBS entities keep their project's language. Name/Description
        # are localization, not balance overrides. JSON-only new entities still
        # need those fields to be registered correctly.
        next if existed && ["Name", "Description"].include?(field.to_s)
        assign_move(entry, field, value)
      end
      move_count += 1
    end
    ability_count = 0
    (doc["abilities"] || {}).each do |id, fields|
      next if !fields.is_a?(Hash)
      existed = !!find_ability_record(id)
      entry = find_ability_record(id) || register_ability_record(id, fields)
      next if !entry
      fields.each do |field, value|
        next if field.to_s.start_with?("_")
        next if existed && ["Name", "Description"].include?(field.to_s)
        assign_ability(entry, field, value)
      end
      ability_count += 1
    end

    count = 0
    (doc["species"] || {}).each do |header, fields|
      next if !fields.is_a?(Hash)
      parts = header.to_s.split(",").map { |x| x.strip }
      species = parts[0].to_s.to_sym
      form = (parts[1] || "0").to_i
      entry = find_species_record(species, form)
      next if !entry
      fields.each { |field, value| assign(entry, field, value) }
      count += 1
    end

    @applied = true
    @applying = false
    @applied_signature = registry_signature
    begin
      VermeilChangeDex.clear_caches! if defined?(VermeilChangeDex) && VermeilChangeDex.respond_to?(:clear_caches!)
    rescue StandardError
    end
    if defined?(echoln) && defined?(ChangeDexConfig) && ChangeDexConfig.debug_logging? && (count + move_count + ability_count) > 0
      echoln("[ChangeDex] JSON overrides applied: #{count} species/forms, #{move_count} moves, #{ability_count} abilities.")
    end
    return true
  rescue StandardError => e
    @applying = false
    @applied = false
    @applied_signature = nil
    echoln("[ChangeDex] Failed to apply JSON overrides: #{e.message}") if defined?(echoln)
    return false
  end

  def self.bulk_loading?
    return @bulk_loading == true
  end

  def self.begin_bulk_load!
    @bulk_loading = true
    mark_stale!
  end

  def self.end_bulk_load!
    @bulk_loading = false
  end

  def self.ensure_applied
    # v0.11.0: hot GameData getters used to recalculate three registry
    # signatures on every call. Load hooks already tell us when data changed,
    # so the normal path is now a single boolean check.
    return if @applying || @applied || bulk_loading?
    apply!
  end

  def self.mark_stale!
    @applied = false
    @applied_signature = nil
    @species_record_index = nil
    @species_record_index_signature = nil
    begin
      VermeilChangeDex::GameLanguage.invalidate! if defined?(VermeilChangeDex::GameLanguage)
    rescue StandardError
    end
  end

  def self.install_hooks!
    targets = []
    targets << GameData::Species if defined?(GameData::Species)
    targets << GameData::Move if defined?(GameData::Move)
    targets << GameData::Ability if defined?(GameData::Ability)
    targets.each do |klass|
      singleton = class << klass; self; end
      [:get, :try_get, :get_species_form, :each, :each_species].each do |meth|
        next if !klass.respond_to?(meth)
        original = "carnek_changedex_original_#{meth}".to_sym
        next if singleton.method_defined?(original)
        singleton.class_eval do
          alias_method original, meth
          define_method(meth) do |*args, &block|
            CarnekChangeData.ensure_applied
            send(original, *args, &block)
          end
        end
      end
      if klass.respond_to?(:load)
        original_load = :carnek_changedex_original_load
        if !singleton.method_defined?(original_load)
          singleton.class_eval do
            alias_method original_load, :load
            define_method(:load) do |*args, &block|
              ret = send(original_load, *args, &block)
              CarnekChangeData.mark_stale!
              # GameData.load_all can call Species/Move/Ability.load in the same
              # compilation. Do not reapply the whole JSON three times.
              CarnekChangeData.apply! if !CarnekChangeData.bulk_loading?
              ret
            end
          end
        end
      end
    end
    if defined?(GameData) && GameData.respond_to?(:load_all)
      singleton = class << GameData; self; end
      original = :carnek_changedex_original_load_all
      if !singleton.method_defined?(original)
        singleton.class_eval do
          alias_method original, :load_all
          define_method(:load_all) do |*args, &block|
            CarnekChangeData.begin_bulk_load!
            ret = nil
            begin
              ret = send(original, *args, &block)
            ensure
              CarnekChangeData.end_bulk_load!
            end
            CarnekChangeData.mark_stale!
            CarnekChangeData.apply!
            # Do not build the ChangeDex browser index here. Essentials uses
            # load_all while compiling PBS; prewarming here made compilation
            # pay for ChangeDex work as well. The lightweight preload runs once
            # when the first map scene starts instead.
            ret
          end
        end
      end
    end
  end

end

#===============================================================================
# ChangeDex project configuration
# This file belongs to the game project and is never replaced by Studio updates.
#===============================================================================
module ChangeDexConfig
  PATH = "Data/ChangeDex/config.json"
  DEFAULTS = {
    "screenMode" => "auto", "width" => 640, "height" => 480, "iconSize" => 84, "gameName" => "", "uiMode" => "code", "languageMode" => "auto",
    "gameLocalizationEnabled" => true, "gameLanguageMode" => "auto", "languagePickerInDebug" => true,
    "hiddenForms" => [], "hiddenMoves" => [], "hiddenAbilities" => [],
    "sectionDescriptions" => {
      "es" => {"pokemon_changes"=>"Stats · tipos · habilidades · movimientos · evoluciones","move_changes"=>"Datos del movimiento · efectos · usuarios añadidos/retirados","ability_changes"=>"Datos de la habilidad · reworks · usuarios añadidos/retirados","new_moves"=>"Movimientos que no existen en el balance original","new_abilities"=>"Habilidades que no existen en el balance original"},
      "en" => {"pokemon_changes"=>"Stats · types · abilities · learnsets · evolutions","move_changes"=>"Move data · effects · added/removed users","ability_changes"=>"Ability data · reworks · added/removed users","new_moves"=>"Moves that do not exist in the original balance","new_abilities"=>"Abilities that do not exist in the original balance"}
    },
    "colorBackground" => "#141923", "colorGridFill" => "#1e2634", "colorGridEdge" => "#38465c",
    "colorPanelFill" => "#1c2432", "colorPanelEdge" => "#3e4e68", "colorHighlight" => "#dc3c3c",
    "colorText" => "#f5f5f5", "colorMuted" => "#b4b4b4", "colorOriginal" => "#50b4ff",
    "colorResult" => "#ff6464", "colorDifference" => "#ffd700", "colorNew" => "#64ff78",
    "suppressPbsChangesLogs" => true, "debugLogging" => false, "specialKeyLabel" => ""
  }
  @data = nil
  @data_signature = nil
  @last_check = 0.0
  @check_interval = 0.75

  def self.file_signature
    return nil if !File.file?(PATH)
    return [File.size(PATH).to_i, File.mtime(PATH).to_f]
  rescue StandardError
    return nil
  end

  def self.reload!
    @data = nil
    @data_signature = nil
    @last_check = 0.0
    return data
  end
  def self.data
    now = CarnekChangeData.monotonic_time rescue 0.0
    if @data && (now - (@last_check || 0.0)) < (@check_interval || 0.75)
      return @data
    end
    @last_check = now
    sig = file_signature
    return @data if @data && @data_signature == sig
    @data = DEFAULTS.clone
    if File.file?(PATH)
      begin
        raw = CarnekChangeData.utf8_text(File.open(PATH, "rb") { |f| f.read })
        parsed = CarnekChangeData.parse_json_text(raw)
        @data.merge!(parsed) if parsed.is_a?(Hash)
      rescue StandardError
      end
    end
    @data_signature = sig
    return @data
  end
  def self.screen_width
    return data["width"].to_i if data["screenMode"].to_s == "custom" && data["width"].to_i > 0
    return Graphics.width.to_i if defined?(Graphics) && Graphics.respond_to?(:width)
    640
  end
  def self.screen_height
    return data["height"].to_i if data["screenMode"].to_s == "custom" && data["height"].to_i > 0
    return Graphics.height.to_i if defined?(Graphics) && Graphics.respond_to?(:height)
    480
  end
  def self.icon_size
    v = data["iconSize"].to_i
    return [[v, 32].max, 128].min if v > 0
    84
  end
  def self.ui_mode
    return data["uiMode"].to_s.downcase == "custom" ? "custom" : "code"
  end
  def self.custom_ui?
    return ui_mode == "custom"
  end
  def self.language_mode
    v = data["languageMode"].to_s.downcase
    return v if ["es", "en"].include?(v)
    return "auto"
  end
  def self.game_localization_enabled?
    v = data["gameLocalizationEnabled"]
    return v != false && v.to_s.downcase != "false"
  end
  def self.game_language_mode
    v = data["gameLanguageMode"].to_s.downcase
    return v if ["es", "en"].include?(v)
    return "auto"
  end
  def self.language_picker_in_debug?
    v = data["languagePickerInDebug"]
    return v != false && v.to_s.downcase != "false"
  end
  def self.color(key, fallback, alpha = 255)
    raw = data[key].to_s.strip
    raw = raw[1..-1] if raw.start_with?("#")
    if raw =~ /\A[0-9a-fA-F]{6}\z/
      return Color.new(raw[0,2].to_i(16), raw[2,2].to_i(16), raw[4,2].to_i(16), alpha)
    end
    return Color.new(fallback[0], fallback[1], fallback[2], alpha)
  rescue StandardError
    return Color.new(fallback[0], fallback[1], fallback[2], alpha)
  end
  def self.suppress_pbs_changes_logs?
    value = data["suppressPbsChangesLogs"]
    return value != false && value.to_s.downcase != "false"
  end
  def self.debug_logging?
    value = data["debugLogging"]
    return value == true || value.to_s.downcase == "true"
  end
  def self.special_key_label
    return data["specialKeyLabel"].to_s.strip
  end
  def self.hidden_form?(species, form)
    key = "#{species.to_s.upcase},#{form.to_i}"
    list = data["hiddenForms"]
    return false if !list.is_a?(Array)
    return list.any? { |v| v.to_s.strip.upcase == key }
  rescue StandardError
    return false
  end
  def self.hidden_move?(move_id)
    key = move_id.to_s.strip.upcase
    list = data["hiddenMoves"]
    return false if !list.is_a?(Array)
    return list.any? { |v| v.to_s.strip.upcase == key }
  rescue StandardError
    return false
  end
  def self.hidden_ability?(ability_id)
    key = ability_id.to_s.strip.upcase
    list = data["hiddenAbilities"]
    return false if !list.is_a?(Array)
    return list.any? { |v| v.to_s.strip.upcase == key }
  rescue StandardError
    return false
  end
  def self.section_description(category, lang = nil)
    lang = (lang || VermeilChangeDex.language_code).to_s
    key = category.to_s
    rows = data["sectionDescriptions"]
    if rows.is_a?(Hash) && rows[lang].is_a?(Hash)
      txt = rows[lang][key].to_s.strip
      return txt if !txt.empty?
    end
    defaults = DEFAULTS["sectionDescriptions"] rescue nil
    return defaults.dig(lang, key).to_s if defaults.is_a?(Hash)
    return ""
  rescue StandardError
    return ""
  end
  def self.game_name
    custom = data["gameName"].to_s.strip
    return custom if !custom.empty?
    begin
      value = Settings::GAME_NAME.to_s.strip if defined?(Settings) && Settings.const_defined?(:GAME_NAME)
      return value if value && !value.empty?
    rescue StandardError
    end
    begin
      value = $data_system.game_title.to_s.strip if defined?($data_system) && $data_system
      return value if value && !value.empty?
    rescue StandardError
    end
    return "Modified"
  end
end

# Silence only the legacy PBS Changes progress chatter. Errors and every other
# console message still pass through untouched. Can be disabled in config.json.
module CarnekChangeDexConsoleFilter
  def self.suppress?(message)
    s = message.to_s
    return true if s.start_with?("PBS Changes [")
    return true if s.start_with?("PBS Changes / PBS Vanilla Delta:")
    return false
  end
end

module CarnekChangeDexEchoGuard
  def echoln(*args)
    msg = args.map { |v| v.to_s }.join(" ")
    if defined?(ChangeDexConfig) && ChangeDexConfig.suppress_pbs_changes_logs? && CarnekChangeDexConsoleFilter.suppress?(msg)
      return nil
    end
    return super
  end
end
begin
  Object.prepend(CarnekChangeDexEchoGuard) if !Object.ancestors.include?(CarnekChangeDexEchoGuard)
  Kernel.prepend(CarnekChangeDexEchoGuard) if defined?(Kernel) && !Kernel.ancestors.include?(CarnekChangeDexEchoGuard)
rescue StandardError
end

# Some Essentials builds call Console.echo/echo_li directly instead of the global
# echoln helper. Guard only those informational writes and only for the exact
# legacy PBS Changes prefixes.
module CarnekChangeDexConsoleDirectGuard
  def echo(*args)
    msg = args.map { |v| v.to_s }.join(" ")
    if defined?(ChangeDexConfig) && ChangeDexConfig.suppress_pbs_changes_logs? && CarnekChangeDexConsoleFilter.suppress?(msg)
      return nil
    end
    return super
  end
  def echo_li(*args)
    msg = args.map { |v| v.to_s }.join(" ")
    if defined?(ChangeDexConfig) && ChangeDexConfig.suppress_pbs_changes_logs? && CarnekChangeDexConsoleFilter.suppress?(msg)
      return nil
    end
    return super
  end
end
begin
  if defined?(Console)
    class << Console; self; end.prepend(CarnekChangeDexConsoleDirectGuard) unless (class << Console; self; end).ancestors.include?(CarnekChangeDexConsoleDirectGuard)
  end
rescue StandardError
end

#===============================================================================
# ChangeDex
#===============================================================================
module VermeilChangeDex
  SCREEN_W = ChangeDexConfig.screen_width
  SCREEN_H = ChangeDexConfig.screen_height
  LEFT_PANEL_CENTER_X = [(SCREEN_W * 0.155).round, 72].max
  ICON_TARGET_SIZE = ChangeDexConfig.icon_size
  # Icons are 42×42 in the source and are normally shown at 2× (84×84).
  # Give every icon an actual slot around it instead of making the icon and
  # cell exactly the same size, which made the grid look cramped/misaligned.
  GRID_CELL = ICON_TARGET_SIZE + 10
  GRID_COLS = [[((SCREEN_W - 56) / GRID_CELL), 4].max, 8].min
  GRID_Y = 54
  FOOTER_Y = SCREEN_H - 44
  FOOTER_LINE_Y = FOOTER_Y - 2
  # Use every complete horizontal slot that fits above the footer. The final
  # physical row is ALWAYS reserved for the dim next-page preview. This gives
  # 640x480 one extra horizontal row instead of consuming the preview space as
  # another selectable row.
  GRID_AVAILABLE_H = [FOOTER_LINE_Y - GRID_Y - 4, GRID_CELL * 3].max
  GRID_ROWS = [[(GRID_AVAILABLE_H / GRID_CELL), 3].max, 6].min
  GRID_ACTIVE_ROWS = [GRID_ROWS - 1, 2].max
  GRID_PAGE_SIZE = GRID_COLS * GRID_ACTIVE_ROWS
  GRID_X = (SCREEN_W - (GRID_COLS * GRID_CELL)) / 2
  
  COLOR_BG           = ChangeDexConfig.color("colorBackground", [20, 25, 35])
  COLOR_GRID_FILL    = ChangeDexConfig.color("colorGridFill", [30, 38, 52], 140)
  COLOR_GRID_EDGE    = ChangeDexConfig.color("colorGridEdge", [56, 70, 92], 120)
  COLOR_PANEL_FILL   = ChangeDexConfig.color("colorPanelFill", [28, 36, 50], 170)
  COLOR_PANEL_EDGE   = ChangeDexConfig.color("colorPanelEdge", [62, 78, 104], 150)
  COLOR_HIGHLIGHT    = ChangeDexConfig.color("colorHighlight", [220, 60, 60])
  COLOR_TEXT_MAIN    = ChangeDexConfig.color("colorText", [245, 245, 245])
  COLOR_TEXT_GRAY    = ChangeDexConfig.color("colorMuted", [180, 180, 180])
  COLOR_CANON        = ChangeDexConfig.color("colorOriginal", [80, 180, 255])
  COLOR_VERMEIL      = ChangeDexConfig.color("colorResult", [255, 100, 100])
  COLOR_DIFF         = ChangeDexConfig.color("colorDifference", [255, 215, 0])
  COLOR_MOVES_NEW    = ChangeDexConfig.color("colorNew", [100, 255, 120])
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
  @canon_ability_data = nil
  @custom_move_ids = nil
  @custom_ability_ids = nil
  @detect_cache = nil
  DETECT_CACHE_VERSION = 31
  CANON_CACHE_VERSION = 3
  BASELINE_CACHE_PATH = "Data/ChangeDex/baseline_pbs_base.cache"
  RUNTIME_DETECT_CACHE_PATH = "Data/ChangeDex/runtime_detect.cache"

  def self.detect_cache
    return @detect_cache
  end

  def self.detect_cache=(value)
    @detect_cache = value
  end

  def self.read_marshaled(path)
    return nil if !File.file?(path)
    return Marshal.load(File.binread(path))
  rescue StandardError => e
    echoln("[ChangeDex] Cache read failed (#{path}): #{e.message}") if defined?(echoln)
    return nil
  end

  def self.write_marshaled(path, value)
    dir = File.dirname(path)
    begin
      Dir.mkdir(dir) if !File.directory?(dir)
    rescue StandardError
    end
    File.open(path, "wb") { |f| f.write(Marshal.dump(value)) }
    return true
  rescue StandardError => e
    echoln("[ChangeDex] Cache write failed (#{path}): #{e.message}") if defined?(echoln)
    return false
  end

  def self.file_signature(path)
    return nil if !File.file?(path)
    return [path, File.size(path).to_i, File.mtime(path).to_f]
  rescue StandardError
    return [path, 0, 0]
  end

  # Data/*.dat can be rewritten by Essentials compilation even when their
  # contents did not change. Using mtime made the ChangeDex index cache expire
  # every boot. Sample the binary contents instead; this is tiny compared with
  # rebuilding every species/move/ability comparison.
  def self.sampled_file_signature(path)
    return nil if !File.file?(path)
    size = File.size(path).to_i
    hash = 2166136261
    File.open(path, "rb") do |f|
      offsets = [0, [size / 2 - 2048, 0].max, [size - 4096, 0].max].uniq
      offsets.each do |off|
        f.seek(off, IO::SEEK_SET)
        (f.read(4096) || "").each_byte do |b|
          hash ^= b
          hash = (hash * 16777619) & 0xffffffff
        end
      end
    end
    return [path, size, hash]
  rescue StandardError
    return [path, 0, 0]
  end

  def self.gameplay_document_signature
    doc = CarnekChangeData.document rescue {}
    payload = [doc["schema"], doc["species"] || {}, doc["moves"] || {}, doc["abilities"] || {}]
    bytes = Marshal.dump(payload)
    hash = 2166136261
    bytes.each_byte do |b|
      hash ^= b
      hash = (hash * 16777619) & 0xffffffff
    end
    return [bytes.bytesize, hash]
  rescue StandardError
    return [0, 0]
  end

  def self.runtime_source_signature
    sigs = []
    # Language Studio lives in the same JSON, but translation-only edits must
    # not invalidate/rebuild the expensive ChangeDex comparison index. Hash only
    # the gameplay buckets that can change category membership/carrier deltas.
    sigs << ["changedex_gameplay", gameplay_document_signature]
    sigs << [BASELINE_CACHE_PATH, File.size(BASELINE_CACHE_PATH).to_i] if File.file?(BASELINE_CACHE_PATH)
    dat_paths = ["Data/species.dat", "Data/moves.dat", "Data/abilities.dat"].select { |p| File.file?(p) }
    dat_paths.each { |p| sigs << sampled_file_signature(p) }
    if dat_paths.empty?
      Dir.glob("PBS/pokemon*.txt").sort.each { |p| sigs << file_signature(p) }
    end
    return [DETECT_CACHE_VERSION, sigs.compact]
  end

  def self.load_persistent_detect_cache!
    return @detect_cache if @detect_cache
    doc = read_marshaled(RUNTIME_DETECT_CACHE_PATH)
    return nil if !doc.is_a?(Hash)
    return nil if doc[:version].to_i != DETECT_CACHE_VERSION
    return nil if doc[:signature] != runtime_source_signature
    payload = doc[:payload]
    return nil if !payload.is_a?(Hash)
    @detect_cache = payload
    return @detect_cache
  rescue StandardError
    return nil
  end

  def self.save_persistent_detect_cache!
    return false if !@detect_cache.is_a?(Hash)
    doc = {
      :version => DETECT_CACHE_VERSION,
      :signature => runtime_source_signature,
      :payload => @detect_cache
    }
    return write_marshaled(RUNTIME_DETECT_CACHE_PATH, doc)
  end

  def self.load_bundled_baseline_cache!
    doc = read_marshaled(BASELINE_CACHE_PATH)
    return false if !doc.is_a?(Hash)
    return false if doc[:version].to_i != CANON_CACHE_VERSION
    species = doc[:species]
    return false if !species.is_a?(Hash) || species.empty?
    @canon_cache = species
    @canon_move_data = doc[:moves] if doc[:moves].is_a?(Hash)
    @canon_ability_data = doc[:abilities] if doc[:abilities].is_a?(Hash)
    return true
  rescue StandardError
    return false
  end

  def self.clear_caches!
    @canon_cache = {}
    @canon_move_data = nil
    @canon_ability_data = nil
    @custom_move_ids = nil
    @custom_ability_ids = nil
    @detect_cache = nil
  end

  def self.baseline_species_paths
    # Legacy bridge: the original all-in-one ChangeDex used CanonData.
    # If that folder is still present, keep using it so an existing project
    # does not lose its historical comparisons during migration.
    legacy = Dir.glob("CanonData/pokemon*.txt").sort
    legacy = Dir.glob("CanonData/*.txt").sort if legacy.empty? && File.directory?("CanonData")
    return legacy if !legacy.empty?
    files = Dir.glob("PBS/pokemon*.txt").sort
    files.reject! { |p| File.basename(p) =~ /^pokemon_(?:metrics|regional_dexes)/i }
    files
  end

  def self.load_canon_data
    return if !@canon_cache.empty?
    # Fast path: the package includes a compact Marshal snapshot generated from
    # the supplied clean PBS Base. This avoids reparsing every pokemon*.txt on
    # each game start. The PBS parser below remains as a safe fallback.
    return if load_bundled_baseline_cache!
    baseline_species_paths.each do |file_path|
      current_id = nil; current_form = 0; data = nil
      File.open(file_path, "r:utf-8") do |f|
        f.each_line do |raw_line|
          line = raw_line.to_s.strip
          next if line.empty? || line.start_with?("#")
          if line[/^\[([^\]]+)\](?:!exclude)?$/]
            content = $1; parts = content.split(",")
            current_id = parts[0].strip.to_sym
            current_form = parts[1] ? parts[1].strip.to_i : 0
            @canon_cache[current_id] ||= {}
            @canon_cache[current_id][current_form] ||= {
              :stats => [], :abilities => [], :hidden_abilities => [], :types => [],
              :level_moves => [], :tutor_moves => [], :egg_moves => [], :evolutions => []
            }
            data = @canon_cache[current_id][current_form]
            next
          end
          next if current_id.nil? || !data
          clean = line.split("#", 2)[0].to_s.strip
          next if clean.empty?
          if clean[/^BaseStats\s*=\s*(.*)$/i]
            data[:stats] = $1.strip.split(",").map { |s| s.strip.to_i }
          elsif clean[/^Abilities\s*=\s*(.*)$/i]
            data[:abilities] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif clean[/^HiddenAbilit(?:y|ies)\s*=\s*(.*)$/i]
            data[:hidden_abilities] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif clean[/^Types\s*=\s*(.*)$/i]
            data[:types] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif clean[/^Moves\s*=\s*(.*)$/i]
            parts = $1.strip.split(","); list = []
            parts.each_slice(2) { |lvl, mid| list << mid.to_s.strip.to_sym if mid && !mid.to_s.strip.empty? }
            data[:level_moves] = list
          elsif clean[/^TutorMoves\s*=\s*(.*)$/i]
            data[:tutor_moves] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif clean[/^EggMoves\s*=\s*(.*)$/i]
            data[:egg_moves] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif clean[/^Evolution\s*=\s*(.*)$/i]
            p = $1.strip.split(",").map { |s| s.strip }
            data[:evolutions] << [p[0].to_sym, (p[1] || "None").to_sym, p[2]] if p[0] && !p[0].empty?
          elsif clean[/^Evolutions\s*=\s*(.*)$/i]
            p = $1.strip.split(",").map { |s| s.strip }; evos = []
            p.each_slice(3) { |sp, method, param| evos << [sp.to_sym, (method || "None").to_sym, param] if sp && !sp.empty? }
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


  def self.canon_species_form_defined?(species, form = 0)
    load_canon_data if @canon_cache.empty?
    forms = @canon_cache[species.to_sym] rescue nil
    return false if !forms.is_a?(Hash)
    return !!forms[form.to_i]
  rescue StandardError
    return false
  end

  def self.canon_known_moves
    load_canon_data if @canon_cache.empty?
    load_canon_move_data
    return @canon_move_data.keys if @canon_move_data && !@canon_move_data.empty?
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
    load_canon_ability_data
    return @canon_ability_data.keys if @canon_ability_data && !@canon_ability_data.empty?
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
    paths = Dir.glob("CanonData/moves*.txt").sort
    paths = Dir.glob("PBS/moves*.txt").sort.reject { |p| File.basename(p) =~ /_Vermeil/i } if paths.empty?
    paths.each do |path|
      current_id = nil
      File.open(path, "r:utf-8") do |f|
        f.each_line do |line|
          clean = line.to_s.strip.split("#", 2)[0].to_s.strip
          next if clean.empty?
          if clean[/^\[([^\]]+)\](?:!exclude)?$/]
            current_id = $1.strip.to_sym
            @canon_move_data[current_id] ||= {
              :type => nil, :dmg_class => nil, :power => nil, :accuracy => nil,
              :total_pp => nil, :priority => nil, :function => nil, :effect_chance => nil, :flags => []
            }
            next
          end
          next if current_id.nil?
          data = @canon_move_data[current_id]
          if clean[/^Type\s*=\s*(.*)$/i]; data[:type] = $1.strip.to_sym
          elsif clean[/^Category\s*=\s*(.*)$/i]; data[:dmg_class] = $1.to_s.strip.downcase.to_sym
          elsif clean[/^Power\s*=\s*(.*)$/i]; data[:power] = $1.to_i
          elsif clean[/^Accuracy\s*=\s*(.*)$/i]; data[:accuracy] = $1.to_i
          elsif clean[/^TotalPP\s*=\s*(.*)$/i]; data[:total_pp] = $1.to_i
          elsif clean[/^Priority\s*=\s*(.*)$/i]; data[:priority] = $1.to_i
          elsif clean[/^FunctionCode\s*=\s*(.*)$/i]; data[:function] = $1.to_s.strip
          elsif clean[/^EffectChance\s*=\s*(.*)$/i]; data[:effect_chance] = $1.to_i
          elsif clean[/^Flags\s*=\s*(.*)$/i]; data[:flags] = $1.split(",").map { |s| s.strip }.reject { |s| s.empty? }
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

  def self.load_canon_ability_data
    return if !@canon_ability_data.nil?
    @canon_ability_data = {}
    paths = Dir.glob("CanonData/abilities*.txt").sort
    paths = Dir.glob("PBS/abilities*.txt").sort.reject { |p| File.basename(p) =~ /_Vermeil/i } if paths.empty?
    paths.each do |path|
      current_id = nil
      File.open(path, "r:utf-8") do |f|
        f.each_line do |line|
          clean = line.to_s.strip.split("#", 2)[0].to_s.strip
          next if clean.empty?
          if clean[/^\[([^\]]+)\](?:!exclude)?$/]
            current_id = $1.strip.to_sym
            @canon_ability_data[current_id] ||= { :flags => [] }
            next
          end
          next if current_id.nil?
          data = @canon_ability_data[current_id]
          if clean[/^Name\s*=\s*(.*)$/i]; data[:name] = $1.to_s.strip
          elsif clean[/^Description\s*=\s*(.*)$/i]; data[:description] = $1.to_s.strip
          elsif clean[/^Flags\s*=\s*(.*)$/i]; data[:flags] = $1.split(",").map { |s| s.strip }.reject { |s| s.empty? }
          end
        end
      end
    end
  end

  def self.canon_ability_entry(ability_id)
    load_canon_ability_data
    return @canon_ability_data[ability_id]
  end

  def self.move_snapshot(move_data)
    return nil if !move_data
    dmg = if move_data.respond_to?(:status?) && move_data.status?
            :status
          elsif move_data.respond_to?(:physical?) && move_data.physical?
            :physical
          elsif move_data.respond_to?(:special?) && move_data.special?
            :special
          else
            :status
          end
    power = if move_data.respond_to?(:power)
              move_data.power
            elsif move_data.respond_to?(:base_damage)
              move_data.base_damage
            else
              0
            end
    return {
      :type => (move_data.type rescue nil), :dmg_class => dmg, :power => power.to_i,
      :accuracy => (move_data.accuracy.to_i rescue 0), :total_pp => (move_data.total_pp.to_i rescue 0),
      :priority => (move_data.priority.to_i rescue 0), :function => (move_data.function_code.to_s rescue ""),
      :effect_chance => (move_data.effect_chance.to_i rescue 0),
      :flags => ((move_data.flags || []).map { |x| x.to_s }.sort rescue [])
    }
  end

  def self.move_data_changed?(move_id, move_data = nil)
    canon = canon_move_entry(move_id)
    return false if !canon
    current = move_snapshot(move_data || (GameData::Move.try_get(move_id) rescue nil))
    return false if !current
    [:type, :dmg_class, :power, :accuracy, :total_pp, :priority, :function, :effect_chance].each do |k|
      a = canon[k]; b = current[k]
      next if a.nil?
      return true if k == :function ? a.to_s != b.to_s : a != b
    end
    return true if (canon[:flags] || []).map { |x| x.to_s }.sort != (current[:flags] || []).map { |x| x.to_s }.sort
    change = entity_change("moves", move_id)
    if change.is_a?(Hash)
      functional = ["Type","Category","Power","Accuracy","TotalPP","Target","Priority","FunctionCode","EffectChance","Flags"]
      return true if change.keys.any? { |k| functional.include?(k.to_s) }
      return true if !change["_notes"].to_s.strip.empty?
    end
    return false
  rescue StandardError
    return false
  end

  def self.ability_data_changed?(ability_id)
    return true if reworked_abilities.include?(ability_id)
    change = entity_change("abilities", ability_id)
    return false if !change.is_a?(Hash)
    return true if !change["_notes"].to_s.strip.empty?
    # Flags are data, while Name/Description alone may only be a translation change.
    return true if change.keys.any? { |k| ["Flags"].include?(k.to_s) }
    return false
  rescue StandardError
    return false
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

  def self.change_document
    return CarnekChangeData.document rescue { "moves" => {}, "abilities" => {} }
  end

  def self.entity_change(bucket, id)
    doc = change_document
    map = doc[bucket.to_s] || {}
    return map[id.to_s] || map[id.to_s.upcase] || map[id.to_s.downcase]
  rescue StandardError
    return nil
  end

  def self.game_name
    return ChangeDexConfig.game_name
  end

  def self.custom_move_ids
    if @custom_move_ids.nil?
      canon = {}; canon_known_moves.each { |id| canon[id] = true }
      @custom_move_ids = []
      GameData::Move.each { |m| @custom_move_ids << m.id if !canon[m.id] } if defined?(GameData::Move)
      @custom_move_ids.uniq!
    end
    return @custom_move_ids
  end

  def self.custom_ability_ids
    if @custom_ability_ids.nil?
      canon = {}; canon_known_abilities.each { |id| canon[id] = true }
      @custom_ability_ids = []
      GameData::Ability.each { |a| @custom_ability_ids << a.id if !canon[a.id] } if defined?(GameData::Ability)
      @custom_ability_ids.uniq!
    end
    return @custom_ability_ids
  end

  def self.reworked_abilities
    ids = REWORKED_ABILITIES.clone
    begin
      ((change_document["abilities"] || {}).keys).each do |id|
        data = entity_change("abilities", id)
        next if !data.is_a?(Hash)
        # Name/Description and translated before/after text alone are not proof of
        # a mechanic rework. Studio marks script-side effects with _notes.
        ids << id.to_sym if !data["_notes"].to_s.strip.empty? || data.key?("Flags")
      end
    rescue StandardError
    end
    return ids.uniq
  end

  def self.localized_behavior_text(bucket, id, field, fallback = "")
    over = localization_override(language_code, bucket, id)
    txt = over[field.to_s].to_s.strip if over.is_a?(Hash)
    return txt if txt && !txt.empty?
    # Do not expose Spanish-only freeform notes while ChangeDex is explicitly
    # English. Names/descriptions have canon EN; script-side notes do not.
    return "" if language_code == "en" && field.to_s == "Notes"
    return fallback.to_s
  rescue StandardError
    return fallback.to_s
  end

  def self.reworked_ability_before_text(ability_id)
    data = entity_change("abilities", ability_id)
    raw = data["_beforeText"].to_s.strip if data.is_a?(Hash)
    raw = REWORKED_ABILITY_BEFORE_TEXT[ability_id].to_s if !raw || raw.empty?
    return localized_behavior_text("abilities", ability_id, "BeforeText", raw || "")
  end

  def self.reworked_ability_after_text(ability_id)
    data = entity_change("abilities", ability_id)
    raw = data["_afterText"].to_s.strip if data.is_a?(Hash)
    if !raw || raw.empty?
      a = GameData::Ability.try_get(ability_id) rescue nil
      raw = localized_entity_text("abilities", ability_id, "Description", a ? a.description.to_s : "")
    end
    return localized_behavior_text("abilities", ability_id, "AfterText", raw || "")
  end

  def self.reworked_ability_notes(ability_id)
    data = entity_change("abilities", ability_id)
    raw = data["_notes"].to_s.strip if data.is_a?(Hash)
    return localized_behavior_text("abilities", ability_id, "Notes", raw || "")
  end

  def self.torque_move?(move_id)
    return TORQUE_MOVE_IDS.include?(move_id)
  end

  def self.reworked_move_before_text(move_id)
    data = entity_change("moves", move_id)
    raw = data["_beforeText"].to_s.strip if data.is_a?(Hash)
    raw = "Starmobile-exclusive move." if (!raw || raw.empty?) && torque_move?(move_id)
    raw = "Let's Go-exclusive move." if (!raw || raw.empty?) && LETSGO_EXCLUSIVE_MOVE_IDS.include?(move_id)
    txt = localized_behavior_text("moves", move_id, "BeforeText", raw || "")
    return nil if txt.to_s.empty?
    return txt
  end

  def self.reworked_move_after_text(move_id)
    data = entity_change("moves", move_id)
    raw = data.is_a?(Hash) ? data["_afterText"].to_s.strip : ""
    return localized_behavior_text("moves", move_id, "AfterText", raw)
  end

  def self.reworked_move_notes(move_id)
    data = entity_change("moves", move_id)
    raw = data.is_a?(Hash) ? data["_notes"].to_s.strip : ""
    return localized_behavior_text("moves", move_id, "Notes", raw)
  end

  CANON_LOCALIZATION_EN_PATH = "Data/TranslateStudio/canon_localization_en.json"
  @canon_localization_en = nil
  def self.canon_localization_en
    return @canon_localization_en if @canon_localization_en
    @canon_localization_en = { "species" => {}, "moves" => {}, "abilities" => {} }
    if File.file?(CANON_LOCALIZATION_EN_PATH)
      begin
        raw = CarnekChangeData.utf8_text(File.open(CANON_LOCALIZATION_EN_PATH, "rb") { |f| f.read })
        parsed = CarnekChangeData.parse_json_text(raw)
        @canon_localization_en = parsed if parsed.is_a?(Hash)
      rescue StandardError
      end
    end
    return @canon_localization_en
  end


  CANON_ITEM_LOCALIZATION_PATH = "Data/TranslateStudio/canon_items_localization.json"
  @canon_item_localization = nil
  def self.canon_item_localization
    return @canon_item_localization if @canon_item_localization
    @canon_item_localization = { "es" => {}, "en" => {} }
    if File.file?(CANON_ITEM_LOCALIZATION_PATH)
      begin
        raw = CarnekChangeData.utf8_text(File.open(CANON_ITEM_LOCALIZATION_PATH, "rb") { |f| f.read })
        parsed = CarnekChangeData.parse_json_text(raw)
        @canon_item_localization = parsed if parsed.is_a?(Hash)
      rescue StandardError
      end
    end
    return @canon_item_localization
  end

  def self.localized_item_text(item_id, field = "Name", fallback = nil)
    id = item_id.to_s.upcase
    lang = language_code
    begin
      over = localization_override(lang, "items", id)
      txt = over[field.to_s].to_s.strip if over.is_a?(Hash)
      return txt if txt && !txt.empty?
    rescue StandardError
    end
    begin
      row = canon_item_localization.dig(lang, id)
      txt = row[field.to_s].to_s.strip if row.is_a?(Hash)
      return txt if txt && !txt.empty?
    rescue StandardError
    end
    begin
      data = GameData::Item.try_get(item_id.to_sym)
      if data
        txt = case field.to_s
              when "NamePlural"
                data.respond_to?(:name_plural) ? data.name_plural.to_s.strip : ""
              when "Description"
                data.respond_to?(:description) ? data.description.to_s.strip : ""
              else
                data.name.to_s.strip
              end
        return txt if txt && !txt.empty?
      end
    rescue StandardError
    end
    return fallback.to_s.strip unless fallback.nil? || fallback.to_s.strip.empty?
    return id
  end

  def self.localized_item_name(item_id, fallback = nil)
    return localized_item_text(item_id, "Name", fallback)
  end

  def self.language_code
    begin
      return CarnekTranslateStudio.language_code if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:language_code)
    rescue StandardError
    end
    tokens = []
    begin
      lang = $PokemonSystem.language if defined?($PokemonSystem) && $PokemonSystem && $PokemonSystem.respond_to?(:language)
      if lang.is_a?(Integer) && defined?(Settings::LANGUAGES)
        entry = Settings::LANGUAGES[lang] rescue nil
        entry.is_a?(Array) ? entry.each { |v| tokens << v.to_s } : tokens << entry.to_s if entry
      elsif !lang.nil?
        tokens << lang.to_s
      end
    rescue StandardError
    end
    raw = tokens.join(" ").downcase
    return "es" if raw.include?("españ") || raw.include?("espan") || raw.include?("spanish") || raw.include?("messages_es") || raw.include?("message_es") || raw =~ /(^|[^a-z])es([_\-. ]|$)/
    return "en"
  end

  UI_ES = {
    "CHANGE DEX"=>"CHANGE DEX","Preparing…"=>"Preparando…","Loading comparison index"=>"Preparando índice de comparación",
    "No changes detected"=>"No se detectaron cambios","No changes detected in abilities."=>"No se detectaron cambios en habilidades.","Select Category"=>"Seleccionar categoría","Change Dex"=>"ChangeDex",
    "Pokemon Changes"=>"Cambios de Pokémon","Move Changes"=>"Cambios de Movimientos","Ability Changes"=>"Cambios de Habilidades",
    "New Moves"=>"Movimientos Nuevos","New Abilities"=>"Habilidades Nuevas","Move"=>"Movimiento","Ability"=>"Habilidad",
    "Data"=>"Datos","Users"=>"Usuarios","Users / behavior"=>"Usuarios / comportamiento","New"=>"Nuevo","Change"=>"Cambio",
    "Before / After"=>"Antes / Después","Abilities: Before / After"=>"Habilidades: Antes / Después","Boosted Moves"=>"Movimientos potenciados",
    "Level Movepool"=>"Movimientos por nivel","Evolution Methods"=>"Métodos de evolución","Canon Evolutions:"=>"Evoluciones originales:",
    "Changed Evolution Methods:"=>"Métodos de evolución modificados:","New Evolution Methods:"=>"Nuevos métodos de evolución:",
    "No evolution methods found for this Pokémon."=>"No se encontraron métodos de evolución para este Pokémon.",
    "Item"=>"Objeto","Trade"=>"Intercambio","Friendship"=>"Amistad",
    "{1}: added method {2}"=>"{1}: método añadido {2}",
    "New moves are highlighted in yellow"=>"Los movimientos nuevos aparecen resaltados en amarillo","No entries"=>"Sin entradas",
    "Search Pokémon (name or Dex number)."=>"Buscar Pokémon (nombre o número de Dex).","Search Ability."=>"Buscar habilidad.","Search Move."=>"Buscar movimiento.",
    "No match found in Change Dex."=>"No se encontró ninguna coincidencia en ChangeDex.","Type · Class · Power"=>"Tipo · Clase · Potencia",
    "Moves that do not exist in the original balance"=>"Movimientos que no existen en el balance original",
    "Abilities that do not exist in the original balance"=>"Habilidades que no existen en el balance original",
    "Move data · effects · added/removed carriers"=>"Datos del movimiento · efectos · usuarios añadidos/retirados",
    "Ability data · reworks · added/removed users"=>"Datos de la habilidad · reworks · usuarios añadidos/retirados",
    "Stats · types · abilities · learnsets · evolutions"=>"Stats · tipos · habilidades · movimientos · evoluciones",
    "Open the ChangeDex comparison screen."=>"Abrir la pantalla de comparación de ChangeDex.",
    "Effect"=>"Efecto","Class"=>"Clase","Power"=>"Potencia","Priority"=>"Prioridad","Type"=>"Tipo","Acc"=>"Prec.","Before:"=>"Antes:","After:"=>"Después:","Notes:"=>"Notas:",
    "No longer counts as: {1}"=>"Ya no cuenta como: {1}","Now counts as: {1}"=>"Ahora cuenta como: {1}","Boosted by: {1}"=>"Potenciado por: {1}",
    "{1}: Select"=>"{1}: Seleccionar","{1}: Exit"=>"{1}: Salir","{1}: Search"=>"{1}: Buscar","{1}: Filter"=>"{1}: Filtrar",
    "{1}: Options"=>"{1}: Opciones","{1}: Select  {2}: Back"=>"{1}: Seleccionar  {2}: Volver","{1}: Select  {2}: Close"=>"{1}: Seleccionar  {2}: Cerrar",
    "{1}: Before/After"=>"{1}: Antes/Después","{1}: Boosted Moves"=>"{1}: Movimientos potenciados","{1}/{2}: Close"=>"{1}/{2}: Cerrar",
    "L/R: Page  {1}/{2}: Close"=>"L/R: Página  {1}/{2}: Cerrar","Page {1}/{2}"=>"Página {1}/{2}","{1} - More Info"=>"{1} - Más información",
    "Choose Variant"=>"Elegir variante","Select Action"=>"Seleccionar acción","No matches for current filter."=>"No hay coincidencias con el filtro actual.",
    "New Carriers:"=>"Nuevos usuarios:","All Carriers"=>"Todos los usuarios","Carriers"=>"Usuarios","None"=>"Ninguno","COMPARISON"=>"COMPARACIÓN",
    "New Typing"=>"Nuevo tipo","Original"=>"Original","Abilities:"=>"Habilidades:","New Moves:"=>"Movimientos nuevos:",
    "No moves added to this Pokémon."=>"No se añadieron movimientos a este Pokémon.","Punching moves"=>"Movimientos de puño","Biting moves"=>"Movimientos de mordida",
    "Pulse moves"=>"Movimientos de pulso","Slicing moves"=>"Movimientos de corte","Hammer moves"=>"Movimientos de martillo","Kicking moves"=>"Movimientos de patada","Light moves"=>"Movimientos de luz"
  }
  def self.ui(text, *args)
    raw = text.to_s
    raw = UI_ES[raw] || raw if language_code == "es"
    return raw if args.empty?
    return raw.gsub(/\{(\d+)\}/) { |m| idx = $1.to_i - 1; idx >= 0 && idx < args.length ? args[idx].to_s : m }
  rescue StandardError
    return text.to_s
  end

  def self.localization_override(lang, bucket, id)
    begin
      if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:override_row)
        row = CarnekTranslateStudio.override_row(lang, bucket, id)
        return row if row.is_a?(Hash)
      end
    rescue StandardError
    end
    return {}
  end

  def self.localized_entity_text(bucket, id, field, fallback = "")
    lang = language_code
    key = id.to_s.upcase
    begin
      if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:entity_text)
        return CarnekTranslateStudio.entity_text(bucket, key, field, fallback)
      end
    rescue StandardError
    end
    if lang == "en"
      base = canon_localization_en.dig(bucket.to_s, key) rescue nil
      txt = base[field.to_s].to_s.strip if base.is_a?(Hash)
      return txt if txt && !txt.empty?
    end
    return fallback.to_s
  end

  TYPE_NAMES_EN = {
    :NORMAL=>"Normal", :FIRE=>"Fire", :WATER=>"Water", :ELECTRIC=>"Electric",
    :GRASS=>"Grass", :ICE=>"Ice", :FIGHTING=>"Fighting", :POISON=>"Poison",
    :GROUND=>"Ground", :FLYING=>"Flying", :PSYCHIC=>"Psychic", :BUG=>"Bug",
    :ROCK=>"Rock", :GHOST=>"Ghost", :DRAGON=>"Dragon", :DARK=>"Dark",
    :STEEL=>"Steel", :FAIRY=>"Fairy", :STELLAR=>"Stellar", :SHADOW=>"Shadow",
    :UNKNOWN=>"Unknown"
  }

  def self.type_name(type_id)
    id = type_id.to_sym rescue type_id
    if language_code == "en"
      return TYPE_NAMES_EN[id] || id.to_s.split("_").map { |w| w.capitalize }.join(" ")
    end
    return GameData::Type.get(id).name.to_s if defined?(GameData::Type)
    return id.to_s
  rescue StandardError
    return type_id.to_s
  end

  def self.move_class_name(move_data)
    klass =
      if move_data.respond_to?(:status?) && move_data.status?
        :status
      elsif move_data.respond_to?(:physical?) && move_data.physical?
        :physical
      else
        :special
      end
    return ({:physical=>"Physical", :special=>"Special", :status=>"Status"}[klass]) if language_code == "en"
    return ({:physical=>"Físico", :special=>"Especial", :status=>"Estado"}[klass])
  rescue StandardError
    return language_code == "en" ? "Status" : "Estado"
  end

  def self.localized_move_name(move_id, fallback = nil)
    id = move_id.to_s.upcase
    m = GameData::Move.try_get(move_id) rescue nil
    base_fallback = fallback.nil? ? (m ? m.name.to_s : id) : fallback.to_s
    txt = localized_entity_text("moves", id, "Name", base_fallback)
    if language_code == "en"
      canon = canon_localization_en.dig("moves", id) rescue nil
      over = localization_override("en", "moves", id)
      # Custom/new entities have no official English source. Never silently
      # fall back to a Spanish project name while ChangeDex is in English.
      return over["Name"].to_s.strip if over.is_a?(Hash) && !over["Name"].to_s.strip.empty?
      return canon["Name"].to_s.strip if canon.is_a?(Hash) && !canon["Name"].to_s.strip.empty?
      row = entity_change("moves", id)
      return base_fallback if row.is_a?(Hash) && row["_new"] == true
    end
    return txt
  rescue StandardError
    return fallback.to_s unless fallback.nil?
    return move_id.to_s
  end

  def self.localized_ability_name(ability_id, fallback = nil)
    id = ability_id.to_s.upcase
    a = GameData::Ability.try_get(ability_id) rescue nil
    base_fallback = fallback.nil? ? (a ? a.name.to_s : id) : fallback.to_s
    txt = localized_entity_text("abilities", id, "Name", base_fallback)
    if language_code == "en"
      canon = canon_localization_en.dig("abilities", id) rescue nil
      over = localization_override("en", "abilities", id)
      return over["Name"].to_s.strip if over.is_a?(Hash) && !over["Name"].to_s.strip.empty?
      return canon["Name"].to_s.strip if canon.is_a?(Hash) && !canon["Name"].to_s.strip.empty?
      row = entity_change("abilities", id)
      return base_fallback if row.is_a?(Hash) && row["_new"] == true
    end
    return txt
  rescue StandardError
    return fallback.to_s unless fallback.nil?
    return ability_id.to_s
  end

  def self.localized_species_name(species, fallback = nil)
    id = species.to_s.upcase
    s_data = GameData::Species.get_species_form(species, 0) rescue nil
    base_fallback = fallback.nil? ? (s_data ? s_data.name.to_s : id) : fallback.to_s
    return localized_entity_text("species", id, "Name", base_fallback)
  rescue StandardError
    return fallback.to_s unless fallback.nil?
    return species.to_s
  end

  CUSTOM_UI_DIR = "Graphics/UI/ChangeDex"
  @custom_ui_bitmaps = {}
  def self.custom_ui?
    return ChangeDexConfig.custom_ui?
  end
  def self.custom_ui_bitmap(name)
    return nil if !custom_ui?
    key = name.to_s
    bmp = @custom_ui_bitmaps[key]
    return bmp if bmp && !bmp.disposed?
    path = File.join(CUSTOM_UI_DIR, key)
    resolved = nil
    begin
      resolved = pbResolveBitmap(path) if defined?(pbResolveBitmap)
    rescue StandardError
    end
    resolved = path if !resolved && File.file?(path)
    resolved = path + ".png" if !resolved && File.file?(path + ".png")
    return nil if !resolved
    bmp = Bitmap.new(resolved)
    @custom_ui_bitmaps[key] = bmp
    return bmp
  rescue StandardError
    return nil
  end


  #=============================================================================
  # Translation compatibility bridge
  # Language ownership lives in the independent [CARNKEVT] Translate Studio.
  # This tiny adapter only keeps older ChangeDex calls safe.
  #=============================================================================
  module GameLanguage
    def self.install!
      return CarnekTranslateStudio.install! if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:install!)
      true
    rescue StandardError
      true
    end
    def self.invalidate!
      CarnekTranslateStudio.invalidate! if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:invalidate!)
      true
    rescue StandardError
      true
    end
    def self.active_language
      return CarnekTranslateStudio.language_code if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:language_code)
      VermeilChangeDex.language_code
    rescue StandardError
      "en"
    end
    def self.choose_language!
      return CarnekTranslateStudio.choose_language! if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:choose_language!)
      false
    rescue StandardError
      false
    end
    def self.apply_native_language_index!(value)
      return CarnekTranslateStudio.apply_native_language_index!(value) if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:apply_native_language_index!)
      false
    rescue StandardError
      false
    end
    def self.extract_intl!(core=false)
      return CarnekTranslateStudio.extract_intl!(core) if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:extract_intl!)
      false
    rescue StandardError
      false
    end
    def self.compile_intl!
      return CarnekTranslateStudio.compile_intl! if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:compile_intl!)
      false
    rescue StandardError
      false
    end
  end

  class Scene
    def initialize
      @mode = :grid; @index = 0; @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999; @sprites = {}; @entries = []
      @typebitmap = AnimatedBitmap.new(VermeilChangeDex.ui("Graphics/UI/types"))
      @action_key_name = resolve_input_name(Input::ACTION, "Z")
      @filter_key_name = resolve_input_name(Input::SPECIAL, "D")
      @use_key_name = resolve_input_name(Input::USE, "C")
      @back_key_name = resolve_input_name(Input::BACK, "X")
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
      @ability_moves_popup_title = VermeilChangeDex.ui("Boosted Moves")
      @ability_rework_popup_open = false
      @ability_rework_popup_page = 0
      @ability_rework_popup_lines = []
      @ability_rework_popup_title = VermeilChangeDex.ui("Before / After")
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
      @level_movepool_popup_open = false
      @level_movepool_popup_page = 0
      @level_movepool_popup_lines = []
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
      # Some Essentials/mkxp-z builds expose the key-name helper as a global
      # private method instead of Input.*.
      [:pbGetKeyName, :pbGetInputName, :getKeyName, :getInputName].each do |meth|
        next if !respond_to?(meth, true)
        begin
          name = send(meth, input_constant).to_s.strip
          return name if !name.empty? && !generic_names.include?(name.downcase)
        rescue StandardError
        end
      end
      if defined?(Input::SPECIAL) && input_constant.to_i == Input::SPECIAL.to_i
        configured = ChangeDexConfig.special_key_label
        return configured if configured && !configured.empty?
      end
      keybind_name = keybinding_name_for(input_constant)
      return keybind_name if keybind_name && !keybind_name.empty?
      return fallback
    end

    def keybinding_name_for(input_constant)
      begin
        paths = []
        data_dir = (System.data_directory rescue nil)
        paths << File.join(data_dir, "keybindings.mkxp1") if data_dir
        paths << "keybindings.mkxp1"
        paths.uniq.each do |kb_path|
          next if !File.file?(kb_path)
          ints = File.binread(kb_path).unpack("L<*")
          next if ints.length < 4
          records = []
          count = ints[2].to_i rescue 0
          records.concat((ints[3, count * 4] || []).each_slice(4).to_a) if count > 0
          # Fallback for mkxp-z revisions with a different header: scan aligned
          # 4-int BindingDesc candidates and use only plausible keyboard rows.
          ints.each_slice(4) { |r| records << r if r.length == 4 }
          matches = records.select do |rec|
            next false if !rec || rec.length != 4
            source = rec[0].to_i
            scan = rec[1].to_i
            target = rec[3].to_i
            [0, 1, 2].include?(source) && scan >= 4 && scan <= 290 && target == input_constant.to_i
          end
          label = keycode_to_label(matches[-1][1].to_i) if !matches.empty?
          return label if label && !label.empty?
        end
      rescue StandardError
      end
      return nil
    end

    def special_trigger?
      return false if !defined?(Input::SPECIAL)
      return Input.trigger?(Input::SPECIAL)
    rescue StandardError
      return false
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


    # Build the visible Pokémon-change index directly from the JSON delta.
    # This is also used to sanity-check a persisted cache. A stale/too-early
    # preload used to leave the category counter populated while the grid was
    # completely empty.
    def document_pokemon_entry_keys
      VermeilChangeDex.load_canon_data
      doc = VermeilChangeDex.change_document
      rows = doc["species"].is_a?(Hash) ? doc["species"] : {}
      keys = []
      rows.each do |header, fields|
        next if !fields.is_a?(Hash)
        parts = header.to_s.split(",", 2)
        species = parts[0].to_s.strip.upcase.to_sym
        form = parts[1] ? parts[1].to_i : 0
        next if species.to_s.empty?
        functional_fields = fields.keys.reject { |f| f.to_s.start_with?("_") }
        next if functional_fields.empty?
        next if excluded_from_pokemon_changes?(species, form)
        next if base_only_form_family?(species) && form > 0
        next if minior_core_form?(species, form) && form > 1
        canon = VermeilChangeDex.get_canon_info(species, form)
        canon ||= VermeilChangeDex.get_canon_info(species, 0) if form > 0 && force_visible_hidden_variant?(species, form)
        next if canon.nil?
        keys << [species, form]
      end
      keys.uniq.sort_by { |k| [@dex_order && @dex_order[k[0]] || 999_999, k[1]] }
    rescue StandardError
      return []
    end

    def cached_pokemon_entries_valid?(cached)
      return false if !cached.is_a?(Hash)
      expected = document_pokemon_entry_keys
      got = (cached[:entries] || []).map { |k| [k[0].to_s.upcase.to_sym, k[1].to_i] }.uniq
      return got.empty? if expected.empty?
      return false if got.empty?
      missing = expected - got
      tolerance = [[(expected.length * 0.02).ceil, 2].max, 12].min
      return false if missing.length > tolerance
      true
    rescue StandardError
      return false
    end

    def detect_changes
      CarnekChangeData.ensure_applied
      VermeilChangeDex.load_persistent_detect_cache!
      cached = VermeilChangeDex.detect_cache
      if cached && cached[:version] == VermeilChangeDex::DETECT_CACHE_VERSION && cached[:entries].is_a?(Array)
        @species_move_delta = cached[:species_move_delta].transform_values do |v|
          { :added => (v[:added] || []).clone, :removed => (v[:removed] || []).clone,
            :added_tutor => (v[:added_tutor] || []).clone, :removed_tutor => (v[:removed_tutor] || []).clone,
            :added_egg => (v[:added_egg] || []).clone, :removed_egg => (v[:removed_egg] || []).clone }
        end
        @species_ability_delta = cached[:species_ability_delta].transform_values { |v| { :added => (v[:added] || []).clone, :removed => (v[:removed] || []).clone } }
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
        @non_pokemon_indexes_ready = !!cached[:non_pokemon_indexes_ready]
        apply_current_filters
        return
      end

      # v0.9: ChangeDex is a JSON-delta browser, so build its index from the
      # actual override document instead of comparing every GameData::Species
      # record against canon on first open. The old full scan made large projects
      # pay for ~1500 forms even when only a small category was requested.
      VermeilChangeDex.load_canon_data
      doc = VermeilChangeDex.change_document
      species_rows = (doc["species"].is_a?(Hash) ? doc["species"] : {})

      @species_move_delta = {}
      @species_ability_delta = {}
      @noncanon_species_entries = {}
      @species_learnset_cache = {}
      @entry_gained_evos = {}
      @dex_order = {}
      @entries = []

      dex_idx = 0
      GameData::Species.each_species do |base_species|
        dex_idx += 1
        @dex_order[base_species.species] = dex_idx
      end

      # Project-only species/forms from pokemon_vermeil, pokemon_balance and
      # any other custom pokemon_*.txt remain valid context for New Moves/Abilities.
      GameData::Species.each do |s_data|
        key = [s_data.species, s_data.form]
        @noncanon_species_entries[key] = true if !VermeilChangeDex.canon_species_form_defined?(s_data.species, s_data.form)
      end

      csv_syms = proc do |raw|
        CarnekChangeData.csv(raw).map { |v| v.to_s.strip }.reject { |v| v.empty? }.map { |v| v.to_sym }
      end
      level_syms = proc do |raw|
        arr = CarnekChangeData.csv(raw)
        ret = []
        arr.each_slice(2) { |_lvl, mid| ret << mid.to_s.strip.to_sym if mid && !mid.to_s.strip.empty? }
        ret.compact.uniq
      end
      evo_rows = proc do |raw|
        arr = CarnekChangeData.csv(raw)
        ret = []
        arr.each_slice(3) do |sp, method, param|
          next if !sp || sp.to_s.strip.empty?
          ret << [sp.to_s.strip.to_sym, (method.to_s.strip.empty? ? :None : method.to_s.strip.to_sym), param]
        end
        ret
      end

      species_rows.each do |header, fields|
        next if !fields.is_a?(Hash)
        parts = header.to_s.split(",", 2)
        species = parts[0].to_s.strip.upcase.to_sym
        form = parts[1] ? parts[1].to_i : 0
        next if species.to_s.empty?
        next if excluded_from_pokemon_changes?(species, form)
        next if base_only_form_family?(species) && form > 0
        next if minior_core_form?(species, form) && form > 1

        key = [species, form]
        canon = VermeilChangeDex.get_canon_info(species, form)
        canon ||= VermeilChangeDex.get_canon_info(species, 0) if form > 0 && force_visible_hidden_variant?(species, form)
        functional_fields = fields.keys.reject { |f| f.to_s.start_with?("_") }
        # The browser index must reflect the JSON document even if GameData is
        # still settling during startup. Detail/carrier data can be completed
        # once the species registry is available.
        @entries << key if !canon.nil? && !functional_fields.empty?

        s_data = GameData::Species.get_species_form(species, form) rescue nil
        next if !s_data

        if canon.nil?
          @noncanon_species_entries[key] = true
          # Non-canon species are not listed as official Pokémon Changes, but
          # their JSON learnset/ability additions can still count as carriers.
          v_level = fields.key?("Moves") ? level_syms.call(fields["Moves"]) : ((s_data.moves || []).map { |m| m[1] }.compact.uniq rescue [])
          v_tutor = fields.key?("TutorMoves") ? csv_syms.call(fields["TutorMoves"]) : ((s_data.tutor_moves || []).compact.uniq rescue [])
          v_egg = fields.key?("EggMoves") ? csv_syms.call(fields["EggMoves"]) : ((s_data.egg_moves || []).compact.uniq rescue [])
          v_abil = []
          v_abil.concat(fields.key?("Abilities") ? csv_syms.call(fields["Abilities"]) : ((s_data.abilities || []).compact rescue []))
          v_abil.concat(fields.key?("HiddenAbilities") ? csv_syms.call(fields["HiddenAbilities"]) : ((s_data.hidden_abilities || []).compact rescue []))
          @species_move_delta[key] = { :added => v_level, :removed => [], :added_tutor => v_tutor, :removed_tutor => [], :added_egg => v_egg, :removed_egg => [] }
          @species_ability_delta[key] = { :added => v_abil.compact.reject { |a| a == :NONE }.uniq, :removed => [] }
          @species_learnset_cache[key] = (v_level + v_tutor + v_egg).compact.uniq
          next
        end

        c_level = (canon[:level_moves] || []).compact.uniq
        c_tutor = (canon[:tutor_moves] || []).compact.uniq
        c_egg = (canon[:egg_moves] || []).compact.uniq
        c_normal_abilities = (canon[:abilities] || []).compact.reject { |a| a == :NONE }
        c_hidden_abilities = (canon[:hidden_abilities] || []).compact.reject { |a| a == :NONE }
        c_abil = (c_normal_abilities + c_hidden_abilities).uniq

        v_level = fields.key?("Moves") ? level_syms.call(fields["Moves"]) : c_level
        v_tutor = fields.key?("TutorMoves") ? csv_syms.call(fields["TutorMoves"]) : c_tutor
        v_egg = fields.key?("EggMoves") ? csv_syms.call(fields["EggMoves"]) : c_egg
        v_normal_abilities = fields.key?("Abilities") ? csv_syms.call(fields["Abilities"]) : c_normal_abilities
        v_hidden_abilities = fields.key?("HiddenAbilities") ? csv_syms.call(fields["HiddenAbilities"]) : c_hidden_abilities
        v_abil = (v_normal_abilities + v_hidden_abilities).compact.reject { |a| a == :NONE }.uniq

        @species_move_delta[key] = {
          :added => (v_level - c_level), :removed => (c_level - v_level),
          :added_tutor => (v_tutor - c_tutor), :removed_tutor => (c_tutor - v_tutor),
          :added_egg => (v_egg - c_egg), :removed_egg => (c_egg - v_egg)
        }
        @species_ability_delta[key] = { :added => (v_abil - c_abil), :removed => (c_abil - v_abil) }
        @species_learnset_cache[key] = (v_level + v_tutor + v_egg).compact.uniq

        if fields.key?("Evolutions")
          new_evos = evo_rows.call(fields["Evolutions"])
          old_targets = (canon[:evolutions] || []).map { |e| evolution_target_identity(e[0]) }.compact.uniq
          @entry_gained_evos[key] = new_evos.select { |e| !old_targets.include?(evolution_target_identity(e[0])) }.map { |e| e[0] }.compact.uniq
        else
          @entry_gained_evos[key] = []
        end

      end

      @entries.uniq!
      @entries.sort_by! { |k| [@dex_order[k[0]] || 999_999, k[1]] }
      @pokemon_entries = @entries.clone
      @all_entries = @pokemon_entries.clone
      @non_pokemon_indexes_ready = false

      VermeilChangeDex.detect_cache = {
        :version => VermeilChangeDex::DETECT_CACHE_VERSION,
        :species_move_delta => @species_move_delta.transform_values do |v|
          { :added => (v[:added] || []).clone, :removed => (v[:removed] || []).clone,
            :added_tutor => (v[:added_tutor] || []).clone, :removed_tutor => (v[:removed_tutor] || []).clone,
            :added_egg => (v[:added_egg] || []).clone, :removed_egg => (v[:removed_egg] || []).clone }
        end,
        :species_ability_delta => @species_ability_delta.transform_values { |v| { :added => (v[:added] || []).clone, :removed => (v[:removed] || []).clone } },
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
      VermeilChangeDex.save_persistent_detect_cache!
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
          :data_changed => !!e[:data_changed],
          :is_new => !!e[:is_new],
          :added_users => (e[:added_users] || []).map { |k| [k[0], k[1]] },
          :added_users_comparable => (e[:added_users_comparable] || []).map { |k| [k[0], k[1]] },
          :removed_users => (e[:removed_users] || []).map { |k| [k[0], k[1]] },
          :all_users => (e.key?(:all_users) && !e[:all_users].nil? ? e[:all_users].map { |k| [k[0], k[1]] } : nil)
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
      if species_data.respond_to?(:egg_moves)
        moves.concat((species_data.egg_moves || []))
      elsif species_data.respond_to?(:get_egg_moves)
        begin
          moves.concat((species_data.get_egg_moves || []))
        rescue StandardError
          # Ignore species/forms that cannot resolve inherited egg move chains.
        end
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

      # The species pass already calculated every added/removed carrier. Invert
      # those deltas instead of scanning every species a second time. Full
      # carrier lists are resolved only when the user opens one entry.
      move_added = {}; move_removed = {}; ability_added = {}; ability_removed = {}
      (@species_move_delta || {}).each do |key, d|
        next if excluded_from_move_categories?(key[0], key[1])
        ((d[:added] || []) + (d[:added_tutor] || []) + (d[:added_egg] || [])).compact.uniq.each do |mid|
          (move_added[mid] ||= []) << key unless (move_added[mid] || []).include?(key)
        end
        ((d[:removed] || []) + (d[:removed_tutor] || []) + (d[:removed_egg] || [])).compact.uniq.each do |mid|
          (move_removed[mid] ||= []) << key unless (move_removed[mid] || []).include?(key)
        end
      end
      (@species_ability_delta || {}).each do |key, d|
        next if excluded_from_ability_categories?(key[0], key[1])
        (d[:added] || []).compact.uniq.each { |aid| (ability_added[aid] ||= []) << key unless (ability_added[aid] || []).include?(key) }
        (d[:removed] || []).compact.uniq.each { |aid| (ability_removed[aid] ||= []) << key unless (ability_removed[aid] || []).include?(key) }
      end

      # New entities also show carriers from project-only species even when those
      # species were defined purely in PBS and never touched by ChangeDex JSON.
      custom_moves_lookup = {}; (@custom_move_ids || []).each { |id| custom_moves_lookup[id] = true }
      custom_abilities_lookup = {}; (@custom_ability_ids || []).each { |id| custom_abilities_lookup[id] = true }
      if !custom_moves_lookup.empty? || !custom_abilities_lookup.empty?
        GameData::Species.each do |s_data|
          key = [s_data.species, s_data.form]
          next if !(@noncanon_species_entries && @noncanon_species_entries[key])
          if !custom_abilities_lookup.empty? && !excluded_from_ability_categories?(key[0], key[1])
            abs = ((s_data.abilities || []) + (s_data.hidden_abilities || [])).compact.reject { |a| a == :NONE }.uniq rescue []
            abs.each do |aid|
              next if !custom_abilities_lookup[aid]
              (ability_added[aid] ||= []) << key unless (ability_added[aid] || []).include?(key)
            end
          end
          if !custom_moves_lookup.empty? && !excluded_from_move_categories?(key[0], key[1])
            species_all_learnable_moves(s_data).each do |mid|
              next if !custom_moves_lookup[mid]
              (move_added[mid] ||= []) << key unless (move_added[mid] || []).include?(key)
            end
          end
        end
      end

      # Only entities that can actually appear in ChangeDex need indexing:
      # explicit entity overrides/reworks plus moves/abilities whose carrier set
      # changed. Scanning every canonical Move/Ability was unnecessary work.
      move_ids = (move_added.keys + move_removed.keys + (@custom_move_ids || [])).uniq
      ability_ids = (ability_added.keys + ability_removed.keys + (@custom_ability_ids || []) + (@reworked_ability_ids || [])).uniq
      begin
        move_ids.concat((VermeilChangeDex.change_document["moves"] || {}).keys.map { |id| id.to_sym })
        ability_ids.concat((VermeilChangeDex.change_document["abilities"] || {}).keys.map { |id| id.to_sym })
      rescue StandardError
      end
      move_ids.uniq!
      ability_ids.uniq!
      sorter = proc { |k| [@dex_order[k[0]] || 999_999, k[1]] }
      move_ids.uniq.each do |move_id|
        next if ChangeDexConfig.hidden_move?(move_id)
        m_data = GameData::Move.try_get(move_id)
        next if !m_data
        added_users = (move_added[move_id] || []).uniq.sort_by(&sorter)
        removed_users = (move_removed[move_id] || []).uniq.sort_by(&sorter)
        is_new = (@custom_move_ids || []).include?(move_id)
        data_changed = VermeilChangeDex.move_data_changed?(move_id, m_data)
        next if !is_new && !data_changed && added_users.empty? && removed_users.empty?
        entry = {
          :id => move_id, :name => m_data.name, :type => m_data.type, :dmg_class => move_damage_class(m_data),
          :is_new => is_new, :data_changed => data_changed, :canon_user_count => nil,
          :added_users => added_users, :removed_users => removed_users, :all_users => nil
        }
        entry[:added_users_comparable] = added_users.reject { |k| @noncanon_species_entries && @noncanon_species_entries[k] }
        @move_entries_all << entry
      end
      ability_ids.uniq.each do |ability_id|
        next if ChangeDexConfig.hidden_ability?(ability_id)
        a_data = GameData::Ability.try_get(ability_id)
        next if !a_data
        added_users = (ability_added[ability_id] || []).uniq.sort_by(&sorter)
        removed_users = (ability_removed[ability_id] || []).uniq.sort_by(&sorter)
        is_new = (@custom_ability_ids || []).include?(ability_id)
        data_changed = VermeilChangeDex.ability_data_changed?(ability_id)
        next if !is_new && !data_changed && added_users.empty? && removed_users.empty?
        entry = {
          :id => ability_id, :name => a_data.name, :is_new => is_new, :data_changed => data_changed,
          :canon_user_count => nil, :added_users => added_users, :removed_users => removed_users, :all_users => nil
        }
        entry[:added_users_comparable] = added_users.reject { |k| @noncanon_species_entries && @noncanon_species_entries[k] }
        @ability_entries_all << entry
      end
      @new_move_entries_all = @move_entries_all.select { |e| e[:is_new] }
      @new_ability_entries_all = @ability_entries_all.select { |e| e[:is_new] }
      cached = VermeilChangeDex.detect_cache
      if cached && cached[:version] == VermeilChangeDex::DETECT_CACHE_VERSION
        cached[:move_entries_all] = clone_entry_list(@move_entries_all || [])
        cached[:ability_entries_all] = clone_entry_list(@ability_entries_all || [])
        cached[:new_move_entries_all] = clone_entry_list(@new_move_entries_all || [])
        cached[:new_ability_entries_all] = clone_entry_list(@new_ability_entries_all || [])
        cached[:non_pokemon_indexes_ready] = true
        VermeilChangeDex.detect_cache = cached
        VermeilChangeDex.save_persistent_detect_cache!
      end
    end

    def entry_all_users(entry)
      return [] if !entry
      return entry[:all_users] if entry.key?(:all_users) && !entry[:all_users].nil?
      users = []
      is_ability = (@category == :ability_changes || @category == :new_abilities)
      GameData::Species.each do |s|
        key = [s.species, s.form]
        if is_ability
          next if excluded_from_ability_categories?(s.species, s.form)
          list = (s.abilities + s.hidden_abilities).compact.reject { |a| a == :NONE }.uniq
          users << key if list.include?(entry[:id])
        else
          next if excluded_from_move_categories?(s.species, s.form)
          list = (@species_learnset_cache && @species_learnset_cache[key]) || species_all_learnable_moves(s)
          users << key if list.include?(entry[:id])
        end
      end
      users.sort_by! { |k| [@dex_order[k[0]] || 999_999, k[1]] }
      entry[:all_users] = users
      begin
        cached = VermeilChangeDex.detect_cache
        if cached && cached[:version] == VermeilChangeDex::DETECT_CACHE_VERSION
          list_key = is_ability ? :ability_entries_all : :move_entries_all
          new_key = is_ability ? :new_ability_entries_all : :new_move_entries_all
          [list_key, new_key].each do |lk|
            target = (cached[lk] || []).find { |e| e[:id] == entry[:id] }
            target[:all_users] = users.clone if target
          end
          VermeilChangeDex.detect_cache = cached
          VermeilChangeDex.save_persistent_detect_cache!
        end
      rescue StandardError
      end
      return users
    rescue StandardError
      entry[:all_users] = [] if entry
      return []
    end

    def precompute_all_carriers!
      move_entries = (@move_entries_all || [])
      ability_entries = (@ability_entries_all || [])
      move_lookup = {}; ability_lookup = {}
      move_entries.each { |e| move_lookup[e[:id]] = e }
      ability_entries.each { |e| ability_lookup[e[:id]] = e }
      move_entries.each { |e| e[:all_users] = [] }
      ability_entries.each { |e| e[:all_users] = [] }
      return if move_lookup.empty? && ability_lookup.empty?
      GameData::Species.each do |sp_data|
        key = [sp_data.species, sp_data.form]
        if !move_lookup.empty? && !excluded_from_move_categories?(sp_data.species, sp_data.form)
          list = (@species_learnset_cache && @species_learnset_cache[key]) || species_all_learnable_moves(sp_data)
          list.compact.uniq.each do |mid|
            ent = move_lookup[mid]
            ent[:all_users] << key if ent
          end
        end
        if !ability_lookup.empty? && !excluded_from_ability_categories?(sp_data.species, sp_data.form)
          list = (sp_data.abilities + sp_data.hidden_abilities).compact.reject { |a| a == :NONE }.uniq
          list.each do |aid|
            ent = ability_lookup[aid]
            ent[:all_users] << key if ent
          end
        end
      end
      sorter = proc { |k| [@dex_order[k[0]] || 999_999, k[1]] }
      move_entries.each { |e| e[:all_users].sort_by!(&sorter) }
      ability_entries.each { |e| e[:all_users].sort_by!(&sorter) }
      cached = VermeilChangeDex.detect_cache
      if cached && cached[:version] == VermeilChangeDex::DETECT_CACHE_VERSION
        cached[:move_entries_all] = clone_entry_list(move_entries)
        cached[:ability_entries_all] = clone_entry_list(ability_entries)
        cached[:new_move_entries_all] = clone_entry_list(@new_move_entries_all || [])
        cached[:new_ability_entries_all] = clone_entry_list(@new_ability_entries_all || [])
        cached[:non_pokemon_indexes_ready] = true
        VermeilChangeDex.detect_cache = cached
        VermeilChangeDex.save_persistent_detect_cache!
      end
    rescue StandardError => e
      echoln("[ChangeDex] Carrier pre-cache skipped: #{e.message}") if defined?(echoln) && ChangeDexConfig.debug_logging?
    end

    def canon_user_count_for(entry)
      return 0 if !entry
      return entry[:canon_user_count].to_i if !entry[:canon_user_count].nil?
      count = 0
      is_ability = (@category == :ability_changes || @category == :new_abilities)
      GameData::Species.each do |s|
        next if is_ability ? excluded_from_ability_categories?(s.species, s.form) : excluded_from_move_categories?(s.species, s.form)
        canon = VermeilChangeDex.get_canon_info(s.species, s.form)
        canon = VermeilChangeDex.get_canon_info(s.species, 0) if canon.nil? && s.species == :UNOWN && s.form > 0
        next if !canon
        list = if is_ability
                 ((canon[:abilities] || []) + (canon[:hidden_abilities] || [])).compact.reject { |a| a == :NONE }.uniq
               else
                 ((canon[:level_moves] || []) + (canon[:tutor_moves] || []) + (canon[:egg_moves] || [])).compact.uniq
               end
        count += 1 if list.include?(entry[:id])
      end
      entry[:canon_user_count] = count
      return count
    rescue StandardError
      entry[:canon_user_count] = 0 if entry
      return 0
    end

    def current_category_title
      case @category
      when :pokemon_changes then VermeilChangeDex.ui("Pokemon Changes")
      when :move_changes    then VermeilChangeDex.ui("Move Changes")
      when :ability_changes then VermeilChangeDex.ui("Ability Changes")
      when :new_moves       then VermeilChangeDex.ui("New Moves")
      when :new_abilities   then VermeilChangeDex.ui("New Abilities")
      else VermeilChangeDex.ui("Change Dex")
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
      # Team Star Starmobile forms from Gen 9 Pack are REVAVROOM forms 1..5
      # and are usually defined without FormName.
      return true if species == :REVAVROOM && form >= 1 && form <= 5
      s_data = GameData::Species.get_species_form(species, form)
      return false if !s_data
      return s_data.form_name.to_s.downcase.include?("starmobile")
    end

    def excluded_from_pokemon_changes?(species, form)
      return true if starmobile_form?(species, form)
      return true if form.to_i > 0 && ChangeDexConfig.hidden_form?(species, form)
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
        [:added, :removed, :added_tutor, :removed_tutor, :added_egg, :removed_egg].each do |kind|
          return true if !(move_delta[kind] || []).empty?
        end
      end
      abil_delta = (@species_ability_delta || {})[key]
      if abil_delta
        return true if !(abil_delta[:added] || []).empty?
        return true if !(abil_delta[:removed] || []).empty?
      end
      return true if @entry_gained_evos && !(@entry_gained_evos[key] || []).empty?
      return false
    end

    def excluded_from_move_categories?(species, form)
      return true if form.to_i > 0 && ChangeDexConfig.hidden_form?(species, form)
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
      return true if form.to_i > 0 && ChangeDexConfig.hidden_form?(species, form)
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
      return false if !$player
      return false if !noncanon_species?(species, form)
      if form.to_i > 0 && $player.respond_to?(:pokedex) && $player.pokedex && $player.pokedex.respond_to?(:seen_form?)
        return !seen_species_form?(species, form)
      end
      return !$player.seen?(species)
    rescue StandardError
      return true
    end

    def regional_form?(species, form)
      return false if form <= 0
      s_data = GameData::Species.get_species_form(species, form)
      return false if !s_data
      form_name = s_data.form_name.to_s.strip
      form_name = inferred_variant_name(species, form).to_s if form_name.empty?
      form_name = form_name.downcase
      regional_tags = ["alolan", "alola", "galarian", "galar", "hisuian", "hisui", "paldean", "paldea", "kantonian", "kantoan", "kanto"]
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
      m = GameData::Move.try_get(entry[:id])
      fallback = entry[:name] || (m ? m.name : entry[:id].to_s)
      return VermeilChangeDex.localized_move_name(entry[:id], fallback)
    end

    def ability_entry_name(entry)
      a = GameData::Ability.try_get(entry[:id])
      fallback = entry[:name] || (a ? a.name : entry[:id].to_s)
      return VermeilChangeDex.localized_ability_name(entry[:id], fallback)
    end

    def apply_entry_filters
      list = case @category
      when :move_changes
        (@move_entries_all || []).select do |e|
          next false if e[:is_new]
          next true if e[:data_changed]
          next true if !(e[:added_users_comparable] || []).empty?
          next true if !(e[:removed_users] || []).empty?
          next false
        end.clone
      when :ability_changes
        (@ability_entries_all || []).select do |e|
          next false if e[:is_new]
          next true if e[:data_changed]
          next true if !(e[:added_users_comparable] || []).empty?
          next true if !(e[:removed_users] || []).empty?
          next false
        end.clone
      when :new_moves       then (@new_move_entries_all || []).clone
      when :new_abilities   then (@new_ability_entries_all || []).clone
      else []
      end
      # Hidden lists are configuration, not part of the heavy data cache. Apply
      # them every time so cleaning up accidental imports is immediate even if
      # runtime_detect.cache was built before the blacklist changed.
      if @category == :move_changes || @category == :new_moves
        list.reject! { |e| ChangeDexConfig.hidden_move?(e[:id]) }
      elsif @category == :ability_changes || @category == :new_abilities
        list.reject! { |e| ChangeDexConfig.hidden_ability?(e[:id]) }
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
            canon_count = canon_user_count_for(e)
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
        [:pokemon_changes, VermeilChangeDex.ui("Pokemon Changes")],
        [:move_changes, VermeilChangeDex.ui("Move Changes")],
        [:ability_changes, VermeilChangeDex.ui("Ability Changes")],
        [:new_moves, VermeilChangeDex.ui("New Moves")],
        [:new_abilities, VermeilChangeDex.ui("New Abilities")]
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
            ensure_change_data_ready if !@data_ready
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

    def draw_category_start_screen
      @sprites["overlay"].bitmap.clear
      @sprites["grid_bg"].bitmap.clear if @sprites["grid_bg"]
      @sprites.keys.each do |k|
        if k.to_s.include?("icon_") || k.to_s.include?("icon_preview_") || k.to_s.include?("evo_mark_") || k.to_s.include?("variant_mark_") || k.to_s.include?("variant_preview_") || k == "cursor" ||
           k == "scroll_up" || k == "scroll_down"
          @sprites[k].dispose
          @sprites.delete(k)
        end
      end
      draw_header(VermeilChangeDex.ui("CHANGE DEX"), VermeilChangeDex.ui("Select Category"))
      draw_category_panel
    end

    def category_summary(category)
      custom = ChangeDexConfig.section_description(category, VermeilChangeDex.language_code)
      return custom if custom && !custom.empty?
      return ""
    end

    def quick_category_count(category)
      doc = CarnekChangeData.document rescue {}
      case category
      when :pokemon_changes
        rows = doc["species"] rescue nil
        return rows.is_a?(Hash) ? rows.keys.count { |h| begin; sp, f = h.to_s.split(",", 2); !ChangeDexConfig.hidden_form?(sp.to_s.upcase.to_sym, f.to_i); rescue StandardError; true; end } : 0
      when :move_changes
        rows = doc["moves"] rescue nil
        return 0 if !rows.is_a?(Hash)
        return rows.count { |id, v| !ChangeDexConfig.hidden_move?(id) && v.is_a?(Hash) && v["_new"] != true && !v.keys.reject { |k| k.to_s == "Name" || k.to_s == "Description" }.empty? }
      when :ability_changes
        rows = doc["abilities"] rescue nil
        return 0 if !rows.is_a?(Hash)
        return rows.count { |id, v| !ChangeDexConfig.hidden_ability?(id) && v.is_a?(Hash) && v["_new"] != true && !v.keys.reject { |k| k.to_s == "Name" || k.to_s == "Description" }.empty? }
      when :new_moves
        rows = doc["moves"] rescue nil
        return rows.is_a?(Hash) ? rows.count { |id, v| !ChangeDexConfig.hidden_move?(id) && v.is_a?(Hash) && v["_new"] == true } : 0
      when :new_abilities
        rows = doc["abilities"] rescue nil
        return rows.is_a?(Hash) ? rows.count { |id, v| !ChangeDexConfig.hidden_ability?(id) && v.is_a?(Hash) && v["_new"] == true } : 0
      end
      return 0
    rescue StandardError
      return 0
    end

    def hydrate_prebuilt_cache_only
      return true if @data_ready
      VermeilChangeDex.load_persistent_detect_cache!
      cached = VermeilChangeDex.detect_cache
      return false if !cached.is_a?(Hash) || cached[:version].to_i != VermeilChangeDex::DETECT_CACHE_VERSION
      return false if !cached[:entries].is_a?(Array)
      # detect_changes takes the O(1) cached branch because @detect_cache is now
      # in memory; it does not compare the PBS again.
      detect_changes
      @data_ready = true
      return true
    rescue StandardError
      return false
    end

    def ensure_change_data_ready
      return true if @data_ready
      begin
        # v0.9 indexes from the JSON delta and the bundled Marshal baseline.
        # It is fast enough to build without replacing the current screen with
        # a separate "Loading comparison index" interstitial.
        VermeilChangeDex.load_canon_data
        detect_changes
        @data_ready = true
        return true
      rescue StandardError => e
        @data_ready = false
        raise e
      end
    end

    def category_count(category)
      return quick_category_count(category) if !@data_ready
      case category
      when :pokemon_changes then return (@pokemon_entries || []).length
      when :move_changes
        return (@move_entries_all || []).count { |e| !ChangeDexConfig.hidden_move?(e[:id]) && !e[:is_new] && (e[:data_changed] || !(e[:added_users_comparable] || []).empty? || !(e[:removed_users] || []).empty?) }
      when :ability_changes
        return (@ability_entries_all || []).count { |e| !ChangeDexConfig.hidden_ability?(e[:id]) && !e[:is_new] && (e[:data_changed] || !(e[:added_users_comparable] || []).empty? || !(e[:removed_users] || []).empty?) }
      when :new_moves then return (@new_move_entries_all || []).count { |e| !ChangeDexConfig.hidden_move?(e[:id]) }
      when :new_abilities then return (@new_ability_entries_all || []).count { |e| !ChangeDexConfig.hidden_ability?(e[:id]) }
      end
      return 0
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
      opts = category_options
      if @category_fullscreen
        # v0.9: use the full 640×480 stage as five readable category cards.
        # The previous split list + floating detail panel left a large dead area
        # and made the menu feel like two unrelated UIs.
        bmp.fill_rect(0, 44, SCREEN_W, SCREEN_H - 44, Color.new(0, 0, 0, 76))
        outer_x = 14
        outer_y = 54
        outer_w = SCREEN_W - 28
        footer_space = 32
        available_h = SCREEN_H - outer_y - footer_space - 8
        gap = 6
        row_h = [(available_h - (gap * (opts.length - 1))) / [opts.length, 1].max, 58].max
        row_h = [row_h, 72].min
        opts.each_with_index do |opt, i|
          ry = outer_y + (i * (row_h + gap))
          selected = (i == @category_panel_index)
          draw_panel(bmp, outer_x, ry, outer_w, row_h)
          if selected
            accent = ChangeDexConfig.color("colorHighlight", [220, 60, 60], 76)
            bmp.fill_rect(outer_x + 2, ry + 2, outer_w - 4, row_h - 4, accent)
            bmp.fill_rect(outer_x + 2, ry + 2, 5, row_h - 4, COLOR_HIGHLIGHT)
          end
          count = category_count(opt[0])
          title_color = selected ? COLOR_TEXT_MAIN : COLOR_TEXT_GRAY
          count_color = selected ? COLOR_HIGHLIGHT : COLOR_TEXT_GRAY
          pbDrawTextPositions(bmp, [
            [opt[1].to_s, outer_x + 18, ry + 8, :left, title_color, Color.new(0,0,0,120)],
            [count.to_s, outer_x + outer_w - 18, ry + 8, :right, count_color, Color.new(0,0,0,120)]
          ])
          summary = category_summary(opt[0]).to_s
          draw_wrapped_text(bmp, summary, outer_x + 18, ry + 31, outer_w - 120, COLOR_TEXT_GRAY, 18, 2) if !summary.empty?
        end
        hint_y = SCREEN_H - 27
        pbDrawTextPositions(bmp, [
          [VermeilChangeDex.ui("{1}: Select", @action_key_name), 14, hint_y, :left, COLOR_TEXT_MAIN, Color.new(0,0,0,140)],
          [VermeilChangeDex.ui("{1}: Exit", @back_key_name), SCREEN_W - 14, hint_y, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,140)]
        ])
        return
      end
      bmp.fill_rect(0, 44, SCREEN_W, SCREEN_H - 44, Color.new(0, 0, 0, 216))
      w = [SCREEN_W - 48, 440].min
      x = (SCREEN_W - w) / 2
      y = 72
      row_h = 42
      h = [(opts.length * row_h) + 34, SCREEN_H - y - 18].min
      draw_panel(bmp, x, y, w, h)
      opts.each_with_index do |opt, i|
        ry = y + 8 + (i * row_h)
        break if ry + row_h > y + h - 24
        if i == @category_panel_index
          bmp.fill_rect(x + 8, ry, w - 16, row_h - 4, ChangeDexConfig.color("colorHighlight", [220, 60, 60], 66))
          bmp.fill_rect(x + 8, ry, 4, row_h - 4, COLOR_HIGHLIGHT)
        end
        count = category_count(opt[0])
        pbDrawTextPositions(bmp, [[opt[1].to_s, x + 20, ry + 5, :left, COLOR_TEXT_MAIN, Color.new(0,0,0,120)],
                                  [count.to_s, x + w - 22, ry + 5, :right, (i == @category_panel_index ? COLOR_HIGHLIGHT : COLOR_TEXT_GRAY), Color.new(0,0,0,120)]])
      end
      hint = VermeilChangeDex.ui("{1}: Select  {2}: Close", @action_key_name, @back_key_name)
      pbDrawTextPositions(bmp, [[hint, x + w - 12, y + h - 23, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
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
        type_names = GameData::Type.keys.sort_by { |t| VermeilChangeDex.type_name(t) }
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
          type_cmd = ["All Types"] + type_names.map { |t| VermeilChangeDex.type_name(t) } + ["Cancel"]
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

    def evolution_target_identity(target)
      raw = target
      begin
        id = target.to_sym
        data = GameData::Species.try_get(id)
        return data.species.to_sym if data && data.respond_to?(:species)
        return id
      rescue StandardError
      end
      return raw.to_s.upcase.to_sym
    end

    def evolution_data_changed?(species_data, canon)
      return false if !species_data || !canon
      current = species_data.get_evolutions(true).map do |e|
        [evolution_target_identity(e[0]).to_s, (e[1] || :None).to_s, e[2].to_s]
      end.sort
      original = (canon[:evolutions] || []).map do |e|
        [evolution_target_identity(e[0]).to_s, (e[1] || :None).to_s, e[2].to_s]
      end.sort
      return current != original
    rescue StandardError
      return false
    end

    def gained_evolution_species(species_data, canon)
      return gained_evolution_data(species_data, canon).map { |e| e[:species] }
    end

    def gained_evolution_data(species_data, canon)
      return [] if !species_data
      current_evos = species_data.get_evolutions(true).map do |e|
        [e[0], (e[1] || :None).to_sym, e[2]]
      end
      canon_targets = (canon[:evolutions] || []).reject { |e| (e[1] || :None).to_s.downcase == "none" }.map { |e| evolution_target_identity(e[0]) }.uniq
      gained = []
      current_evos.each do |species, method, param|
        next if canon_targets.include?(evolution_target_identity(species))
        gained << { :species => species, :method => method, :param => param }
      end
      return gained.uniq { |e| evolution_target_identity(e[:species]) }
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
          item_name = item_id ? VermeilChangeDex.localized_item_name(item_id, p) : p
          label = "#{VermeilChangeDex.ui("Item")}: #{item_name}"
        else
          label = VermeilChangeDex.ui("Item")
        end
      when "trade"
        label = VermeilChangeDex.ui("Trade")
      when "tradeitem"
        if has_param
          item_id = p.to_sym rescue nil
          item_name = item_id ? VermeilChangeDex.localized_item_name(item_id, p) : p
          label = "#{VermeilChangeDex.ui("Trade")} + #{item_name}"
        else
          label = "#{VermeilChangeDex.ui("Trade")} + #{VermeilChangeDex.ui("Item")}"
        end
      when "happiness", "friendship"
        label = VermeilChangeDex.ui("Friendship")
      end
      if label.nil? && m[/^HasMove/i]
        if has_param
          move_id = p.to_sym rescue nil
          move_name = move_id ? (VermeilChangeDex.localized_move_name(move_id) || p) : p
          label = "#{VermeilChangeDex.ui("Move")}: #{move_name}"
        else
          label = VermeilChangeDex.ui("Move")
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
        data << { :species => species, :target_key => evolution_target_identity(species), :method => method, :param => param }
      end
      return data
    end

    def evolution_method_change_data(species_data, canon)
      return { :new => [], :changed => [], :canon => [] } if !species_data
      canon_list = canon_evolution_data(canon)
      canon_map = {}
      canon_list.each do |e|
        key = e[:target_key] || evolution_target_identity(e[:species])
        canon_map[key] ||= []
        canon_map[key] << e
      end
      current_list = species_data.get_evolutions(true).map do |e|
        { :species => e[0], :target_key => evolution_target_identity(e[0]), :method => (e[1] || :None).to_sym, :param => e[2] }
      end
      current_list = current_list.reject { |e| e[:method].to_s.downcase == "none" }
      new_list = []
      changed_list = []
      consumed = {}
      current_list.each do |cur|
        canon_for_target = canon_map[cur[:target_key]] || []
        if canon_for_target.empty?
          new_list << cur
          next
        end
        exact_idx = canon_for_target.each_index.find do |i|
          !consumed[[cur[:target_key], i]] && canon_for_target[i][:method] == cur[:method] && canon_for_target[i][:param].to_s == cur[:param].to_s
        end
        if exact_idx
          consumed[[cur[:target_key], exact_idx]] = true
          next
        end
        same_method_idx = canon_for_target.each_index.find do |i|
          !consumed[[cur[:target_key], i]] && canon_for_target[i][:method] == cur[:method]
        end
        any_idx = canon_for_target.each_index.find { |i| !consumed[[cur[:target_key], i]] }
        idx = same_method_idx || any_idx
        if idx
          consumed[[cur[:target_key], idx]] = true
          changed_list << { :species => cur[:species], :from => canon_for_target[idx], :to => cur }
        else
          changed_list << { :species => cur[:species], :from => nil, :to => cur, :added_method => true }
        end
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
        lines << VermeilChangeDex.ui("New Evolution Methods:")
        evo_data[:new].each do |evo|
          method_txt = changedex_evo_method_short_label(evo[:method], evo[:param])
          if should_mask_species_name?(evo[:species], 0)
            lines << VermeilChangeDex.ui("??? evolves via {1}", method_txt)
          else
            evo_name = VermeilChangeDex.localized_species_name(evo[:species])
            lines << VermeilChangeDex.ui("{1} evolves via {2}", evo_name, method_txt)
          end
        end
      end
      if !evo_data[:changed].empty?
        lines << "" if !lines.empty?
        lines << VermeilChangeDex.ui("Changed Evolution Methods:")
        evo_data[:changed].each do |chg|
          evo_name = VermeilChangeDex.localized_species_name(chg[:species])
          new_m = changedex_evo_method_short_label(chg[:to][:method], chg[:to][:param])
          if chg[:from]
            old_m = changedex_evo_method_short_label(chg[:from][:method], chg[:from][:param])
            lines << VermeilChangeDex.ui("{1}: {2} -> {3}", evo_name, old_m, new_m)
          else
            lines << VermeilChangeDex.ui("{1}: added method {2}", evo_name, new_m)
          end
        end
      end
      if evo_data[:changed].empty? && !evo_data[:canon].empty?
        lines << "" if !lines.empty?
        lines << VermeilChangeDex.ui("Canon Evolutions:")
        evo_data[:canon].each do |evo|
          evo_name = VermeilChangeDex.localized_species_name(evo[:species])
          method_txt = changedex_evo_method_short_label(evo[:method], evo[:param])
          lines << VermeilChangeDex.ui("{1} evolves via {2}", evo_name, method_txt)
        end
      end
      lines = [VermeilChangeDex.ui("No evolution methods found for this Pokémon.")] if lines.empty?
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
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, ChangeDexConfig.color("colorPanelFill", [20, 28, 40], 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      title = VermeilChangeDex.ui("Evolution Methods")
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
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("{1}/{2}: Close", @action_key_name, "X"), panel_x + panel_w - 12, panel_y + panel_h - 24, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
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
      return VermeilChangeDex.localized_move_name(move_id, move.name)
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
        sections << { :label => VermeilChangeDex.ui("Punching moves"), :moves => moves_with_flag("Punching") }
      when :STRONGJAW
        sections << { :label => VermeilChangeDex.ui("Biting moves"), :moves => moves_with_flag("Biting") }
      when :MEGALAUNCHER
        sections << { :label => VermeilChangeDex.ui("Pulse moves"), :moves => moves_with_flag("Pulse") }
      when :SHARPNESS
        sections << { :label => VermeilChangeDex.ui("Slicing moves"), :moves => moves_with_flag("Slicing") }
      when :BLUDGEONMASTER
        hammer_ids = if defined?(Battle::AbilityEffects) && Battle::AbilityEffects.const_defined?(:HAMMER_MASTER_MOVES)
                       Battle::AbilityEffects::HAMMER_MASTER_MOVES
                     else
                       [:ICEHAMMER, :CRABHAMMER, :HAMMERARM, :WOODHAMMER, :GIGATONHAMMER, :DRAGONHAMMER]
                     end
        sections << { :label => VermeilChangeDex.ui("Hammer moves"), :moves => hammer_ids }
      when :STRIKER
        kick_ids = if defined?(VermeilStriker) && VermeilStriker.const_defined?(:KICK_MOVES)
                     VermeilStriker::KICK_MOVES
                   else
                     [:DOUBLEKICK, :JUMPKICK, :HIJUMPKICK, :MEGAKICK, :LOWKICK, :ROLLINGKICK, :TRIPLEKICK, :BLAZEKICK, :TROPKICK, :THUNDEROUSKICK, :AXEKICK]
                   end
        sections << { :label => VermeilChangeDex.ui("Kicking moves"), :moves => kick_ids }
      when :ILLUMINATE
        light_ids = if defined?(VermeilAbilityReworks) && VermeilAbilityReworks.const_defined?(:LIGHT_MOVES)
                      VermeilAbilityReworks::LIGHT_MOVES
                    else
                      []
                    end
        sections << { :label => VermeilChangeDex.ui("Light moves"), :moves => light_ids } if !light_ids.empty?
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
      @ability_moves_popup_title = VermeilChangeDex.ui("Boosted Moves")
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
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, ChangeDexConfig.color("colorPanelFill", [20, 28, 40], 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
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
      controls = VermeilChangeDex.ui("L/R: Page  {1}/{2}: Close", @filter_key_name, "X")
      page_txt = VermeilChangeDex.ui("Page {1}/{2}", @ability_moves_popup_page + 1, total_pages)
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
      before_entries = compact_ability_entries(c_slots, labels)
      after_entries = compact_ability_entries(v_slots, labels)
      return [] if before_entries == after_entries
      lines = []
      lines << [["Before:", COLOR_CANON]]
      wrap_plain_lines(bmp, before_entries.empty? ? "-" : before_entries.join(", "), max_w).each do |seg|
        lines << [[seg, COLOR_TEXT_MAIN]]
      end
      lines << [[VermeilChangeDex.ui("After:"), COLOR_VERMEIL]]
      wrap_plain_lines(bmp, after_entries.empty? ? "-" : after_entries.join(", "), max_w).each do |seg|
        lines << [[seg, COLOR_DIFF]]
      end
      return lines
    end

    def compact_ability_entries(slot_hash, ordered_labels = nil)
      labels = ordered_labels || slot_hash.keys.sort_by { |k| ability_slot_sort_key(k) }
      grouped = {}
      order = []
      labels.each do |slot|
        name = slot_hash[slot].to_s.strip
        next if name.empty?
        key = name.downcase
        if !grouped[key]
          grouped[key] = { name: name, slots: [] }
          order << key
        end
        grouped[key][:slots] << slot.gsub(/[()]/, "")
      end
      out = []
      order.each do |k|
        item = grouped[k]
        slots = item[:slots].uniq
        if slots.length > 1
          out << "#{item[:name]}[#{slots.join('/')}]"
        else
          out << item[:name]
        end
      end
      return out
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
      @ability_rework_popup_title = VermeilChangeDex.ui("Abilities: Before / After")
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
      after_txt = VermeilChangeDex.reworked_ability_after_text(ability_id).to_s.strip
      notes_txt = VermeilChangeDex.reworked_ability_notes(ability_id).to_s.strip
      return [] if (before_txt.empty? || after_txt.empty? || before_txt == after_txt) && notes_txt.empty?
      max_w = 372
      lines = []
      if !before_txt.empty? && !after_txt.empty? && before_txt != after_txt
        lines << [[VermeilChangeDex.ui("Before:"), COLOR_CANON]]
        wrap_plain_lines(bmp, before_txt, max_w).each do |seg|
          lines << [[seg, COLOR_TEXT_MAIN]]
        end
        lines << [[VermeilChangeDex.ui("After:"), COLOR_VERMEIL]]
        wrap_plain_lines(bmp, after_txt, max_w).each do |seg|
          lines << [[seg, COLOR_TEXT_MAIN]]
        end
      end
      if !notes_txt.empty?
        lines << [[VermeilChangeDex.ui("Notes:"), COLOR_DIFF]]
        wrap_plain_lines(bmp, notes_txt, max_w).each do |seg|
          lines << [[seg, COLOR_TEXT_MAIN]]
        end
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
      @ability_rework_popup_title = VermeilChangeDex.ui("Before / After")
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
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, ChangeDexConfig.color("colorPanelFill", [20, 28, 40], 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      title = (@ability_rework_popup_title && !@ability_rework_popup_title.empty?) ? @ability_rework_popup_title : VermeilChangeDex.ui("Before / After")
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
      controls = VermeilChangeDex.ui("L/R: Page  {1}/{2}: Close", @action_key_name, @back_key_name)
      page_txt = VermeilChangeDex.ui("Page {1}/{2}", @ability_rework_popup_page + 1, total_pages)
      pbDrawTextPositions(bmp, [[controls, panel_x + 12, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      pbDrawTextPositions(bmp, [[page_txt, panel_x + panel_w - 12, panel_y + panel_h - 24, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      @ability_rework_popup_open = true
    end

    def hide_ability_rework_popup(clear_lines = true)
      @ability_rework_popup_open = false
      @ability_rework_popup_page = 0 if clear_lines
      @ability_rework_popup_lines = [] if clear_lines
      @ability_rework_popup_title = VermeilChangeDex.ui("Before / After") if clear_lines
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
      key = (sym || :status).to_s.downcase.to_sym
      return ({:physical=>"Physical", :special=>"Special", :status=>"Status"}[key] || key.to_s.capitalize) if VermeilChangeDex.language_code == "en"
      return ({:physical=>"Físico", :special=>"Especial", :status=>"Estado"}[key] || key.to_s.capitalize)
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
        before = VermeilChangeDex.type_name(canon_type)
        after = VermeilChangeDex.type_name(now_type)
        diffs << VermeilChangeDex.ui("Type: {1} -> {2}", before, after)
      end
      canon_class = canon ? canon[:dmg_class] : nil
      now_class = move_damage_class(move_data)
      if canon_class && canon_class != now_class
        diffs << VermeilChangeDex.ui("Class: {1} -> {2}", move_display_dmg_class(canon_class), move_display_dmg_class(now_class))
      end
      canon_power = canon ? canon[:power] : nil
      now_power = move_data.respond_to?(:power) ? move_data.power.to_i : 0
      if !canon_power.nil? && canon_power.to_i != now_power.to_i
        diffs << VermeilChangeDex.ui("Power: {1} -> {2}", move_display_power(canon_power), move_display_power(now_power))
      end
      canon_acc = canon ? canon[:accuracy] : nil
      now_acc = move_data.accuracy.to_i
      if !canon_acc.nil? && canon_acc.to_i != now_acc.to_i
        diffs << VermeilChangeDex.ui("Acc: {1} -> {2}", move_display_accuracy(canon_acc), move_display_accuracy(now_acc))
      end
      canon_pp = canon ? canon[:total_pp] : nil
      now_pp = move_data.total_pp.to_i
      if !canon_pp.nil? && canon_pp.to_i != now_pp.to_i
        diffs << VermeilChangeDex.ui("PP: {1} -> {2}", canon_pp.to_i, now_pp.to_i)
      end
      canon_priority = canon ? canon[:priority] : nil
      now_priority = move_data.priority.to_i
      if !canon_priority.nil? && canon_priority.to_i != now_priority.to_i
        diffs << VermeilChangeDex.ui("Priority: {1} -> {2}", canon_priority.to_i, now_priority.to_i)
      end
      canon_func = canon ? canon[:function].to_s : ""
      now_func = move_data.function_code.to_s
      if !canon_func.empty? && canon_func != now_func
        diffs << VermeilChangeDex.ui("Effect: {1} -> {2}", friendly_function_effect(canon_func), friendly_function_effect(now_func))
      end
      canon_eff = canon ? canon[:effect_chance] : nil
      now_eff = move_data.effect_chance.to_i
      if !canon_eff.nil? && canon_eff.to_i != now_eff.to_i
        diffs << VermeilChangeDex.ui("Effect chance: {1}% -> {2}%", canon_eff.to_i, now_eff.to_i)
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
        diffs << VermeilChangeDex.ui("Now counts as: {1}", gained_flags.map { |f| titleize_flag(f) }.join(", "))
        synergies = flag_synergy_descriptions(gained_flags)
        if !synergies.empty?
          diffs << VermeilChangeDex.ui("Boosted by: {1}", synergies.join(", "))
        end
      end
      if !removed_flags.empty?
        diffs << VermeilChangeDex.ui("No longer counts as: {1}", removed_flags.map { |f| titleize_flag(f) }.join(", "))
      end
      notes = VermeilChangeDex.reworked_move_notes(move_id)
      diffs << notes if notes && !notes.empty?
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
      after_txt = VermeilChangeDex.reworked_move_after_text(move_id)
      diff_lines = move_change_lines(entry)
      return [] if diff_lines.empty? && (before_txt.nil? || before_txt.empty?) && (after_txt.nil? || after_txt.empty?)
      max_w = 372
      lines = []
      if before_txt && !before_txt.empty?
        before_prefix = VermeilChangeDex.ui("Before:") + " "
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
      lines << [[VermeilChangeDex.ui("After:"), COLOR_VERMEIL]]
      if after_txt && !after_txt.empty?
        wrap_plain_lines(bmp, after_txt, max_w).each { |seg| lines << [[seg, COLOR_TEXT_MAIN]] }
      end
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
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, ChangeDexConfig.color("colorPanelFill", [20, 28, 40], 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("Before / After"), panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
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
      controls = VermeilChangeDex.ui("L/R: Page  {1}/{2}: Close", @filter_key_name, "X")
      page_txt = VermeilChangeDex.ui("Page {1}/{2}", @move_rework_popup_page + 1, total_pages)
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
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, ChangeDexConfig.color("colorPanelFill", [20, 28, 40], 235))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("New Moves"), panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
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
      controls = VermeilChangeDex.ui("L/R: Page  {1}/{2}: Close", @action_key_name, @back_key_name)
      page_txt = VermeilChangeDex.ui("Page {1}/{2}", @moves_popup_page + 1, total_pages)
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

    def level_movepool_popup_page_size
      return 8
    end

    def pokemon_level_movepool_lines(species, form)
      canon = VermeilChangeDex.get_canon_info(species, form)
      canon ||= VermeilChangeDex.get_canon_info(species, 0)
      canon_lookup = {}
      (canon ? (canon[:level_moves] || []) : []).each { |mid| canon_lookup[mid] = true }
      s_data = GameData::Species.get_species_form(species, form) rescue nil
      return [] if !s_data
      pairs = []
      seen = {}
      (s_data.moves || []).each do |entry|
        next if !entry || entry.length < 2
        lvl = entry[0].to_i
        mid = entry[1]
        next if !mid || mid == :NONE
        key = [lvl, mid]
        next if seen[key]
        seen[key] = true
        pairs << key
      end
      pairs.sort_by! { |lvl, mid| [lvl, (VermeilChangeDex.localized_move_name(mid) rescue mid.to_s)] }
      lines = []
      pairs.each do |lvl, mid|
        name = (VermeilChangeDex.localized_move_name(mid) rescue mid.to_s)
        lvl_txt = if lvl > 0
                    VermeilChangeDex.ui("Lv {1}: ", lvl)
                  elsif lvl == 0
                    VermeilChangeDex.ui("Evolve: ")
                  elsif lvl < 0
                    VermeilChangeDex.ui("Tutor: ")
                  else
                    VermeilChangeDex.ui("Lv ?: ")
                  end
        lines << [[lvl_txt, COLOR_TEXT_GRAY], [name, (canon_lookup[mid] ? COLOR_TEXT_MAIN : COLOR_DIFF)]]
      end
      return lines
    end

    def wrapped_level_movepool_lines(bmp, token_lines, max_w)
      return [] if !token_lines || token_lines.empty?
      out = []
      token_lines.each do |line|
        prefix = (line[0] && line[0][0]) ? line[0][0].to_s : ""
        prefix_col = (line[0] && line[0][1]) ? line[0][1] : COLOR_TEXT_GRAY
        name = (line[1] && line[1][0]) ? line[1][0].to_s : ""
        name_col = (line[1] && line[1][1]) ? line[1][1] : COLOR_TEXT_MAIN
        avail = [max_w - bmp.text_size(prefix).width, 40].max
        name_wrapped = wrap_plain_lines(bmp, name, avail)
        if name_wrapped.empty?
          out << [[prefix, prefix_col]]
          next
        end
        out << [[prefix, prefix_col], [name_wrapped[0], name_col]]
        cont_indent = " " * [prefix.length, 2].max
        name_wrapped[1..-1].to_a.each do |seg|
          out << [[cont_indent, prefix_col], [seg, name_col]]
        end
      end
      return out
    end

    def show_level_movepool_popup
      return if !pokemon_category? || !@detail_species
      lines = pokemon_level_movepool_lines(@detail_species, @detail_form)
      if lines.empty?
        pbPlayBuzzerSE
        return
      end
      @level_movepool_popup_lines = lines
      @level_movepool_popup_page = 0
      redraw_level_movepool_popup
      @level_movepool_popup_open = true
    end

    def redraw_level_movepool_popup
      hide_level_movepool_popup(false)
      return if @level_movepool_popup_lines.nil? || @level_movepool_popup_lines.empty?
      @sprites["level_movepool_popup"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["level_movepool_popup"].z = 320
      bmp = @sprites["level_movepool_popup"].bitmap
      pbSetSystemFont(bmp)
      panel_x = 30
      panel_y = 60
      panel_w = SCREEN_W - 60
      panel_h = 274
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, Color.new(16, 22, 34, 246))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("Level Movepool"), panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("New moves are highlighted in yellow"), panel_x + 12, panel_y + 28, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      wrapped = wrapped_level_movepool_lines(bmp, @level_movepool_popup_lines, panel_w - 28)
      # Keep a safe bottom margin so the last move line never overlaps controls.
      per_page = level_movepool_popup_page_size
      total_pages = [(wrapped.length.to_f / per_page).ceil, 1].max
      @level_movepool_popup_page = [[@level_movepool_popup_page, 0].max, total_pages - 1].min
      start_idx = @level_movepool_popup_page * per_page
      page_lines = wrapped[start_idx, per_page] || []
      y = panel_y + 56
      page_lines.each do |line|
        draw_colored_token_line(bmp, line, panel_x + 12, y)
        y += 20
      end
      controls = VermeilChangeDex.ui("L/R: Page  {1}/{2}: Close", @action_key_name, @back_key_name)
      page_txt = VermeilChangeDex.ui("Page {1}/{2}", @level_movepool_popup_page + 1, total_pages)
      pbDrawTextPositions(bmp, [[controls, panel_x + 12, panel_y + panel_h - 20, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      pbDrawTextPositions(bmp, [[page_txt, panel_x + panel_w - 12, panel_y + panel_h - 20, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      @level_movepool_popup_open = true
    end

    def hide_level_movepool_popup(clear_lines = true)
      @level_movepool_popup_open = false
      @level_movepool_popup_page = 0 if clear_lines
      @level_movepool_popup_lines = [] if clear_lines
      if @sprites["level_movepool_popup"]
        @sprites["level_movepool_popup"].dispose
        @sprites.delete("level_movepool_popup")
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
        candidates = [s_data.name, s_data.species.to_s, changedex_display_name(sp, f), VermeilChangeDex.localized_species_name(sp)]
        candidates.push(s_data.form_name) if s_data.form_name && !s_data.form_name.empty?
        return i if candidates.any? { |txt| txt.to_s.downcase.include?(down) }
      end
      return nil
    end

    def open_search
      prompt = if pokemon_category?
                 VermeilChangeDex.ui("Search Pokémon (name or Dex number).")
               elsif @category == :ability_changes || @category == :new_abilities
                 VermeilChangeDex.ui("Search Ability.")
               else
                 VermeilChangeDex.ui("Search Move.")
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
        pbMessage(VermeilChangeDex.ui("No match found in Change Dex."))
      end
    end

    def pbStartScene
      pbFadeOutIn do
        # Paint the scene first. The old flow performed every comparison before
        # a background existed, which looked like a long black freeze.
        @sprites["bg"] = IconSprite.new(0, 0, @viewport)
        @sprites["bg"].bitmap = Bitmap.new(SCREEN_W, SCREEN_H)
        bg_bmp = @sprites["bg"].bitmap
        custom_bg = VermeilChangeDex.custom_ui_bitmap("background")
        if custom_bg
          bg_bmp.stretch_blt(Rect.new(0, 0, SCREEN_W, SCREEN_H), custom_bg, Rect.new(0, 0, custom_bg.width, custom_bg.height))
        else
          bg_bmp.fill_rect(0, 0, SCREEN_W, SCREEN_H, COLOR_BG)
        end
        @sprites["bg"].z = 10
        @sprites["grid_bg"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @sprites["grid_bg"].z = 50
        @sprites["overlay"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
        @sprites["overlay"].z = 200; pbSetSystemFont(@sprites["overlay"].bitmap)
        # v0.11: entering ChangeDex must never be the moment that builds the
        # comparison database. Paint the selector immediately, then hydrate only
        # an already prepared in-memory/persistent cache. If there is no cache,
        # the selected category builds on demand after the player can already see
        # and control the UI.
        CarnekChangeData.ensure_applied
        @sprites["overlay"].bitmap.clear
        @sprites["grid_bg"].bitmap.clear
        draw_header(VermeilChangeDex.ui("CHANGE DEX"), VermeilChangeDex.ui("Select Category"))
        open_category_menu(true, true, true)
        pbUpdate
        Graphics.update
        begin
          hydrate_prebuilt_cache_only
          draw_category_panel if @category_panel_open
          pbUpdate
          Graphics.update
        rescue StandardError => e
          echoln("[ChangeDex] Fast cache hydrate skipped: #{e.message}") if defined?(echoln) && ChangeDexConfig.debug_logging?
        end
      end
    end

    def fit_species_icon(sprite, target = ICON_TARGET_SIZE)
      return if !sprite || sprite.disposed?
      w = sprite.src_rect.width.to_f
      h = sprite.src_rect.height.to_f
      return if w <= 0 || h <= 0
      sprite.zoom_x = target.to_f / w
      sprite.zoom_y = target.to_f / h
      sprite.ox = w / 2
      sprite.oy = h / 2
    rescue StandardError
    end

    def draw_grid_interface
      if !pokemon_category?
        draw_list_interface
        return
      end
      @sprites["overlay"].bitmap.clear; draw_header(VermeilChangeDex.ui("CHANGE DEX"), current_category_title)
      grid_bmp = @sprites["grid_bg"].bitmap
      grid_bmp.clear
      if !VermeilChangeDex.custom_ui?
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
      end
      # Stronger footer opacity for readable names over dense icon rows.
      draw_custom_strip(@sprites["overlay"].bitmap, "footer", 0, FOOTER_Y, SCREEN_W, 44) || @sprites["overlay"].bitmap.fill_rect(0, FOOTER_Y, SCREEN_W, 44, Color.new(0, 0, 0, 236))
      @sprites["overlay"].bitmap.fill_rect(0, FOOTER_LINE_Y, SCREEN_W, 2, COLOR_HIGHLIGHT)
      @sprites["overlay"].bitmap.fill_rect((SCREEN_W / 2) - 140, FOOTER_Y + 2, 280, 38, Color.new(12, 16, 24, 210))
      @evo_mark_base_y = {}
      @variant_mark_base_y = {}
      @sprites.keys.each do |k|
        if k.to_s.include?("icon_") || k.to_s.include?("icon_preview_") || k.to_s.include?("evo_mark_") || k.to_s.include?("variant_mark_") || k.to_s.include?("variant_preview_") || k == "cursor" ||
           k == "scroll_up" || k == "scroll_down"
          @sprites[k].dispose
          @sprites.delete(k)
        end
      end
      if !@entries.empty?
        @sprites["cursor"] = BitmapSprite.new(GRID_CELL, GRID_CELL, @viewport); @sprites["cursor"].z = 150
        bmp = @sprites["cursor"].bitmap
        custom_cursor = VermeilChangeDex.custom_ui_bitmap("grid_cell_selected")
        if custom_cursor
          src_b = [[custom_cursor.width, custom_cursor.height].min / 7, 4].max
          src_b = [src_b, 12].min
          dst_b = [[GRID_CELL / 12, 4].max, 8].min
          # Draw only the four border strips. The center remains fully
          # transparent so selection never covers the Pokémon icon.
          bmp.stretch_blt(Rect.new(0, 0, GRID_CELL, dst_b), custom_cursor, Rect.new(0, 0, custom_cursor.width, src_b))
          bmp.stretch_blt(Rect.new(0, GRID_CELL - dst_b, GRID_CELL, dst_b), custom_cursor, Rect.new(0, custom_cursor.height - src_b, custom_cursor.width, src_b))
          bmp.stretch_blt(Rect.new(0, dst_b, dst_b, GRID_CELL - (dst_b * 2)), custom_cursor, Rect.new(0, src_b, src_b, custom_cursor.height - (src_b * 2)))
          bmp.stretch_blt(Rect.new(GRID_CELL - dst_b, dst_b, dst_b, GRID_CELL - (dst_b * 2)), custom_cursor, Rect.new(custom_cursor.width - src_b, src_b, src_b, custom_cursor.height - (src_b * 2)))
        else
          bmp.fill_rect(0, 0, GRID_CELL, GRID_CELL, Color.new(COLOR_HIGHLIGHT.red, COLOR_HIGHLIGHT.green, COLOR_HIGHLIGHT.blue, 60))
          [0, GRID_CELL - 4].each { |y| bmp.fill_rect(0, y, GRID_CELL, 4, COLOR_HIGHLIGHT) }
          [0, GRID_CELL - 4].each { |x| bmp.fill_rect(x, 0, 4, GRID_CELL, COLOR_HIGHLIGHT) }
        end
      end
      start_idx = (@index / GRID_PAGE_SIZE).floor * GRID_PAGE_SIZE
      (start_idx...start_idx + GRID_PAGE_SIZE).each_with_index do |real_idx, i|
        next if real_idx >= @entries.length
        if VermeilChangeDex.custom_ui?
          custom_cell = VermeilChangeDex.custom_ui_bitmap("grid_cell")
          if custom_cell
            gx = GRID_X + ((i % GRID_COLS) * GRID_CELL) + 5
            gy = GRID_Y + ((i / GRID_COLS) * GRID_CELL) + 5
            grid_bmp.stretch_blt(Rect.new(gx, gy, GRID_CELL - 10, GRID_CELL - 10), custom_cell, Rect.new(0, 0, custom_cell.width, custom_cell.height))
          end
        end
        sp, f = @entries[real_idx]; s = PokemonSpeciesIconSprite.new(nil, @viewport)
        s.setOffset(PictureOrigin::CENTER); s.z = 100
        s.x = GRID_X + ((i % GRID_COLS) * GRID_CELL) + (GRID_CELL / 2)
        s.y = GRID_Y + ((i / GRID_COLS) * GRID_CELL) + (GRID_CELL / 2) - 2
        s.pbSetParams(sp, 0, f, false); fit_species_icon(s); @sprites["icon_#{real_idx}"] = s
        # True center origin in each 84×84 icon cell.
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
      # Dedicated preview row for the next page. It is not part of the active
      # page, so the cursor never lands here and the preview cannot overlap the
      # selectable rows. A subtle horizontal separator makes it visually clear
      # that this last row is only a preview.
      preview_sep_y = GRID_Y + (GRID_ACTIVE_ROWS * GRID_CELL) - 2
      grid_bmp.fill_rect(GRID_X + 4, preview_sep_y, (GRID_COLS * GRID_CELL) - 8, 1, Color.new(COLOR_GRID_EDGE.red, COLOR_GRID_EDGE.green, COLOR_GRID_EDGE.blue, 150))
      preview_start = start_idx + GRID_PAGE_SIZE
      (preview_start...preview_start + GRID_COLS).each_with_index do |real_idx, i|
        next if real_idx >= @entries.length
        if VermeilChangeDex.custom_ui?
          custom_cell = VermeilChangeDex.custom_ui_bitmap("grid_cell")
          if custom_cell
            gx = GRID_X + (i * GRID_CELL) + 5
            gy = GRID_Y + ((GRID_ROWS - 1) * GRID_CELL) + 5
            grid_bmp.stretch_blt(Rect.new(gx, gy, GRID_CELL - 10, GRID_CELL - 10), custom_cell, Rect.new(0, 0, custom_cell.width, custom_cell.height))
          end
        end
        sp, f = @entries[real_idx]
        s = PokemonSpeciesIconSprite.new(nil, @viewport)
        s.setOffset(PictureOrigin::CENTER); s.z = 90
        s.x = GRID_X + (i * GRID_CELL) + (GRID_CELL / 2)
        s.y = GRID_Y + ((GRID_ROWS - 1) * GRID_CELL) + (GRID_CELL / 2) - 2
        s.pbSetParams(sp, 0, f, false); fit_species_icon(s); s.opacity = 120
        @sprites["icon_preview_#{real_idx}"] = s
        frame = hidden_variant_icon_frame(sp, f)
        if !frame.nil?
          mark = IconSprite.new(0, 0, @viewport)
          mark.setBitmap("Graphics/UI/RegionalVariantIcon")
          mark.src_rect.set(frame * 32, 0, 32, 32)
          mark.x = s.x - 32; mark.y = s.y - 32; mark.z = 121; mark.opacity = 135
          key = "variant_preview_#{real_idx}"
          @sprites[key] = mark
        end
      end
      draw_grid_scroll_hints
      refresh_cursor
      draw_category_panel
    end

    def draw_list_interface
      @sprites["overlay"].bitmap.clear
      draw_header(VermeilChangeDex.ui("CHANGE DEX"), current_category_title)
      grid_bmp = @sprites["grid_bg"].bitmap
      grid_bmp.clear
      @sprites.keys.each do |k|
        if k.to_s.include?("icon_") || k.to_s.include?("icon_preview_") || k.to_s.include?("evo_mark_") || k.to_s.include?("variant_mark_") || k.to_s.include?("variant_preview_") || k == "cursor" ||
           k == "scroll_up" || k == "scroll_down"
          @sprites[k].dispose
          @sprites.delete(k)
        end
      end
      bmp = @sprites["overlay"].bitmap
      list_x = 14
      header_y = 54
      list_y = 84
      list_w = SCREEN_W - 28
      row_h = 32
      visible = [[((FOOTER_Y - list_y - 8) / row_h), 7].max, 10].min
      list_h = row_h * visible
      draw_panel(bmp, list_x - 4, header_y - 3, list_w + 8, (list_y - header_y) + list_h + 8)
      bmp.fill_rect(list_x, header_y, list_w, 26, Color.new(COLOR_PANEL_EDGE.red, COLOR_PANEL_EDGE.green, COLOR_PANEL_EDGE.blue, 72))
      ability_cat = (@category == :ability_changes || @category == :new_abilities)
      col2 = list_x + (list_w * 0.48).to_i
      pbDrawTextPositions(bmp, [[ability_cat ? VermeilChangeDex.ui("Ability") : VermeilChangeDex.ui("Move"), list_x + 6, header_y + 4, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)],
                                [ability_cat ? VermeilChangeDex.ui("Change") : VermeilChangeDex.ui("Type · Class · Power"), col2, header_y + 4, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)],
                                [VermeilChangeDex.ui("Users"), list_x + list_w - 6, header_y + 4, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      start_idx = [[@index - (visible / 2), 0].max, [@entries.length - visible, 0].max].min
      selected_y = list_y + ((@index - start_idx) * row_h)
      bmp.fill_rect(list_x, selected_y, list_w, row_h, ChangeDexConfig.color("colorHighlight", [220, 60, 60], 54)) if !@entries.empty?
      visible.times do |r|
        idx = start_idx + r
        break if idx >= @entries.length
        y = list_y + (r * row_h) + 4
        entry = @entries[idx]
        name = ability_cat ? ability_entry_name(entry) : move_entry_name(entry)
        added = (@category == :move_changes || @category == :ability_changes) ? (entry[:added_users_comparable] || []).length : (entry[:added_users] || []).length
        removed = (entry[:removed_users] || []).length
        status = []
        status << VermeilChangeDex.ui("Data") if entry[:data_changed]
        status << VermeilChangeDex.ui("New") if entry[:is_new]
        if ability_cat
          meta = status.empty? ? VermeilChangeDex.ui("Users / behavior") : status.join(" · ")
        else
          move_obj = GameData::Move.try_get(entry[:id]) rescue nil
          type_txt = entry[:type] ? VermeilChangeDex.type_name(entry[:type]) : "—"
          cls_txt = move_obj ? VermeilChangeDex.move_class_name(move_obj) : (entry[:dmg_class] ? entry[:dmg_class].to_s.capitalize : "—")
          pwr = move_obj && move_obj.respond_to?(:power) ? move_obj.power.to_i : 0
          meta = "#{type_txt} · #{cls_txt}"
          meta += " · #{pwr}" if pwr > 0
          meta += " · #{status.join(' · ')}" if !status.empty?
        end
        right = "+#{added}"
        right += "  -#{removed}" if removed > 0
        color = (idx == @index) ? COLOR_TEXT_MAIN : Color.new(218, 218, 222)
        pbDrawTextPositions(bmp, [[name, list_x + 6, y, :left, color, Color.new(0,0,0,120)],
                                  [meta, col2, y, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)],
                                  [right, list_x + list_w - 6, y, :right, (added > 0 ? COLOR_MOVES_NEW : COLOR_TEXT_GRAY), Color.new(0,0,0,120)]])
        bmp.fill_rect(list_x + 4, y + row_h - 6, list_w - 8, 1, Color.new(110, 120, 140, 28)) if r < visible - 1
      end
      draw_custom_strip(bmp, "footer", 0, FOOTER_Y, SCREEN_W, 44) || bmp.fill_rect(0, FOOTER_Y, SCREEN_W, 44, Color.new(0, 0, 0, 236))
      bmp.fill_rect(0, FOOTER_LINE_Y, SCREEN_W, 2, COLOR_HIGHLIGHT)
      label = @entries.empty? ? VermeilChangeDex.ui("No entries") : (ability_cat ? ability_entry_name(@entries[@index]) : move_entry_name(@entries[@index]))
      right_hint = VermeilChangeDex.ui("{1}: Filter", @filter_key_name)
      pbDrawTextPositions(bmp, [[label, SCREEN_W / 2, FOOTER_Y + 10, :center, COLOR_TEXT_MAIN, Color.new(0,0,0,160)],
                                [VermeilChangeDex.ui("{1}: Search", @action_key_name), 8, FOOTER_Y + 10, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,160)],
                                [right_hint, SCREEN_W - 8, FOOTER_Y + 10, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,160)]])
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

    def changedex_language_tokens
      tokens = []
      begin
        lang = $PokemonSystem.language if defined?($PokemonSystem) && $PokemonSystem && $PokemonSystem.respond_to?(:language)
        if lang.is_a?(Integer) && defined?(Settings::LANGUAGES)
          entry = Settings::LANGUAGES[lang] rescue nil
          if entry.is_a?(Array)
            entry.each { |v| tokens << v.to_s }
          elsif entry
            tokens << entry.to_s
          end
        elsif !lang.nil?
          tokens << lang.to_s
        end
      rescue StandardError
      end
      return tokens
    end

    def changedex_spanish?
      return VermeilChangeDex.language_code == "es"
    end

    def regional_descriptor(raw_name)
      raw = raw_name.to_s.downcase
      return { :es => "Alola",  :en => "Alolan" }  if raw.include?("alola")
      return { :es => "Galar",  :en => "Galarian" } if raw.include?("galar")
      return { :es => "Hisui",  :en => "Hisuian" }  if raw.include?("hisui")
      return { :es => "Paldea", :en => "Paldean" }  if raw.include?("paldea")
      return { :es => "Kanto",  :en => "Kantonian" } if raw.include?("kanto")
      return nil
    end

    def localized_form_display_name(species, form, explicit_form_name = nil)
      s_data = GameData::Species.get_species_form(species, form) rescue nil
      base_default = begin
        GameData::Species.get(species).name.to_s
      rescue StandardError
        s_data ? s_data.name.to_s : species.to_s
      end
      base_name = VermeilChangeDex.localized_species_name(species, base_default)
      return base_name if form.to_i <= 0
      form_name = explicit_form_name.nil? ? (s_data ? s_data.form_name.to_s.strip : "") : explicit_form_name.to_s.strip
      localized_form = VermeilChangeDex.localized_entity_text("species", "#{species},#{form}", "FormName", form_name)
      form_name = localized_form if localized_form && !localized_form.to_s.strip.empty?
      inferred = form_name
      inferred = inferred_variant_name(species, form).to_s.strip if inferred.empty?
      region = regional_descriptor(inferred)
      if region
        return changedex_spanish? ? "#{base_name} Forma #{region[:es]}" : "#{region[:en]} Form #{base_name}"
      end
      return base_name if inferred.empty? || inferred == "Form #{form}"
      return inferred if inferred.downcase.include?(base_name.downcase)
      return "#{inferred} #{base_name}"
    end

    def changedex_display_name(species, form)
      s_data = GameData::Species.get_species_form(species, form)
      return "" if !s_data
      return localized_form_display_name(species, form, s_data.form_name.to_s.strip)
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
      return localized_form_display_name(species, form)
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
        opts << [:level_movepool, "Lv Movepool"]
        if SHOW_DETAIL_VARIANT_ACTION
          opts << [:variant, "Variant"] if @detail_form_options && @detail_form_options.length > 1
        end
      else
        entry = (@entries && @entries[@index]) ? @entries[@index] : nil
        users = entry ? entry_all_users(entry) : []
        opts << [:carriers, "Carriers"] if !users.empty?
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
      when :level_movepool
        return false if !pokemon_category?
        show_level_movepool_popup
        return true
      when :carriers
        return false if pokemon_category?
        entry = (@entries && @entries[@index]) ? @entries[@index] : nil
        return false if !entry
        show_carrier_popup(entry)
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
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, ChangeDexConfig.color("colorPanelFill", [20, 28, 40], 236))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("Choose Variant"), panel_x + 10, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      @detail_variant_menu_options.each_with_index do |opt, i|
        y = panel_y + 34 + (i * 28)
        if i == @detail_variant_menu_index
          bmp.fill_rect(panel_x + 8, y - 2, panel_w - 16, 24, Color.new(98, 44, 56, 210))
        end
        pbDrawTextPositions(bmp, [[opt[1], panel_x + 14, y, :left, COLOR_TEXT_MAIN, Color.new(0,0,0,120)]])
      end
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("{1}: Select  {2}: Back", @action_key_name, "X"), panel_x + 10, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
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
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, ChangeDexConfig.color("colorPanelFill", [20, 28, 40], 236))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("Select Action"), panel_x + 10, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      @detail_action_menu_options.each_with_index do |opt, i|
        y = panel_y + 34 + (i * 28)
        if i == @detail_action_menu_index
          bmp.fill_rect(panel_x + 8, y - 2, panel_w - 16, 24, Color.new(98, 44, 56, 210))
        end
        pbDrawTextPositions(bmp, [[opt[1], panel_x + 14, y, :left, COLOR_TEXT_MAIN, Color.new(0,0,0,120)]])
      end
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("{1}: Select  {2}: Back", @action_key_name, "X"), panel_x + 10, panel_y + panel_h - 24, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
    end

    def refresh_cursor
      return if @mode != :grid
      if !pokemon_category?
        draw_list_interface
        return
      end
      bmp = @sprites["overlay"].bitmap
      bmp.clear_rect(0, FOOTER_LINE_Y, SCREEN_W, 46)
      # Redraw full footer each refresh so Search/Filter always stay readable.
      draw_custom_strip(bmp, "footer", 0, FOOTER_Y, SCREEN_W, 44) || bmp.fill_rect(0, FOOTER_Y, SCREEN_W, 44, Color.new(0, 0, 0, 236))
      bmp.fill_rect(0, FOOTER_LINE_Y, SCREEN_W, 2, COLOR_HIGHLIGHT)
      if @entries.empty?
        pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("No matches for current filter."), SCREEN_W / 2, FOOTER_Y + 10, :center, COLOR_TEXT_GRAY, Color.new(0,0,0,160)],
                                  [VermeilChangeDex.ui("{1}: Search", @action_key_name), 8, FOOTER_Y + 10, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,160)],
                                  [VermeilChangeDex.ui("{1}: Filter", @filter_key_name), SCREEN_W - 8, FOOTER_Y + 10, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,160)]])
        return
      end
      return if !@sprites["cursor"]
      p_idx = @index % GRID_PAGE_SIZE
      @sprites["cursor"].x = GRID_X + ((p_idx % GRID_COLS) * GRID_CELL)
      @sprites["cursor"].y = GRID_Y + ((p_idx / GRID_COLS) * GRID_CELL)
      sp, f = @entries[@index]; name = changedex_display_name(sp, f)
      pbDrawTextPositions(bmp, [[name, SCREEN_W/2, FOOTER_Y + 10, :center, COLOR_TEXT_MAIN, Color.new(0,0,0,160)],
                                [VermeilChangeDex.ui("{1}: Search", @action_key_name), 8, FOOTER_Y + 10, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,160)],
                                [VermeilChangeDex.ui("{1}: Filter", @filter_key_name), SCREEN_W - 8, FOOTER_Y + 10, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,160)]])
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
      hide_level_movepool_popup
      hide_carrier_popup
      close_detail_action_menu
      close_detail_variant_menu
      clear_entry_detail_carrier_icons
      ["big_icon", "detail_variant_mark", "evo_label_overlay", "evo_method_popup", "new_moves_popup", "ability_moves_popup", "ability_rework_popup", "move_rework_popup", "level_movepool_popup", "detail_action_menu", "detail_variant_menu"].each do |k|
        next if !@sprites[k]
        @sprites[k].dispose
        @sprites.delete(k)
      end
      @evo_popup_open = false
      @moves_popup_open = false
      @level_movepool_popup_open = false
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
      return VermeilChangeDex.ui("None") if users.nil? || users.empty?
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
      # Keep content dense at 640×480. Empty carrier sets no longer reserve
      # half the screen as a blank panel.
      carrier_users = entry_all_users(entry)
      carrier_panel_y = carrier_users.empty? ? (SCREEN_H - 78) : 238
      detail_h = carrier_users.empty? ? (carrier_panel_y - 62) : 176
      draw_panel(bmp, 10, 52, SCREEN_W - 20, detail_h)
      draw_panel(bmp, 10, carrier_panel_y, SCREEN_W - 20, SCREEN_H - carrier_panel_y - 10)
      y = 56
      if @category == :move_changes || @category == :new_moves
        move_data = GameData::Move.try_get(entry[:id])
        return if !move_data
        canon = VermeilChangeDex.canon_move_entry(entry[:id])
        dmg = VermeilChangeDex.move_class_name(move_data)
        type_name = VermeilChangeDex.type_name(move_data.type)
        move_power = move_data.respond_to?(:power) ? move_data.power.to_i : move_data.base_damage.to_i
        power_txt = (move_power <= 0) ? "-" : move_power.to_s
        acc_txt = (move_data.accuracy.to_i <= 0) ? "-" : move_data.accuracy.to_i.to_s
        pp_txt = move_data.total_pp.to_i.to_s
        type_changed = @category == :move_changes && canon && canon[:type] && canon[:type] != move_data.type
        class_changed = @category == :move_changes && canon && canon[:dmg_class] && canon[:dmg_class] != move_damage_class(move_data)
        power_changed = @category == :move_changes && canon && !canon[:power].nil? && canon[:power].to_i != move_power.to_i
        acc_changed = @category == :move_changes && canon && !canon[:accuracy].nil? && canon[:accuracy].to_i != move_data.accuracy.to_i
        pp_changed = @category == :move_changes && canon && !canon[:total_pp].nil? && canon[:total_pp].to_i != move_data.total_pp.to_i
        pbDrawTextPositions(bmp, [["#{VermeilChangeDex.ui("Type")}: #{type_name}", 20, y, :left, (type_changed ? COLOR_DIFF : COLOR_CANON)],
                                  ["#{VermeilChangeDex.ui("Class")}: #{dmg}", 210, y, :left, (class_changed ? COLOR_DIFF : COLOR_VERMEIL)],
                                  ["#{VermeilChangeDex.ui("Power")}: #{power_txt}", 400, y, :left, (power_changed ? COLOR_DIFF : COLOR_TEXT_MAIN)]])
        pbDrawTextPositions(bmp, [["#{VermeilChangeDex.ui("Acc")}: #{acc_txt}", 20, y + 28, :left, (acc_changed ? COLOR_DIFF : COLOR_TEXT_GRAY)],
                                  ["PP: #{pp_txt}", 210, y + 28, :left, (pp_changed ? COLOR_DIFF : COLOR_TEXT_GRAY)]])
        desc = VermeilChangeDex.localized_entity_text("moves", entry[:id], "Description", move_data.description.to_s)
        draw_wrapped_text(bmp, desc, 20, y + 62, SCREEN_W - 44, COLOR_TEXT_GRAY, 22, 4)
      else
        a_data = GameData::Ability.try_get(entry[:id])
        return if !a_data
        desc = VermeilChangeDex.localized_entity_text("abilities", entry[:id], "Description", a_data.description.to_s)
        draw_wrapped_text(bmp, desc, 20, y + 6, SCREEN_W - 44, COLOR_TEXT_GRAY, 22, 6)
      end
      draw_carrier_icon_window(bmp, entry)
      if @category == :move_changes && !move_change_lines(entry).empty?
        pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("{1}: Before/After", @filter_key_name), SCREEN_W - 20, SCREEN_H - 30, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      end
      if (@category == :ability_changes || @category == :new_abilities)
        if !ability_before_after_lines(entry, @sprites["overlay"].bitmap).empty?
          pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("{1}: Before/After", @filter_key_name), SCREEN_W - 20, SCREEN_H - 30, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
        elsif !ability_boost_sections(entry[:id]).empty?
          pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("{1}: Boosted Moves", @filter_key_name), SCREEN_W - 20, SCREEN_H - 30, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
        end
      end
      if !pokemon_category?
        action_opts = detail_action_options
        if !action_opts.empty?
          header_hint = action_opts.length > 1 ? VermeilChangeDex.ui("{1}: Options", @action_key_name) : VermeilChangeDex.ui("{1}: {2}", @action_key_name, action_opts[0][1])
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
      users = entry_all_users(entry)
      added = if @category == :move_changes || @category == :ability_changes
                entry[:added_users_comparable] || []
              else
                entry[:added_users] || []
              end
      # A compact two-line summary; the full icon grid lives behind Carriers.
      base_y = users.empty? ? (SCREEN_H - 66) : 252
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("New Carriers:"), 20, base_y, :left, COLOR_HIGHLIGHT],
                                ["#{VermeilChangeDex.ui("All Carriers")}: #{users.length}", SCREEN_W - 20, base_y, :right, COLOR_TEXT_GRAY]])
      if added.empty?
        pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("None"), 20, base_y + 24, :left, COLOR_TEXT_GRAY]])
      else
        text = compact_user_list_text(added, 8)
        draw_wrapped_text(bmp, text, 20, base_y + 24, SCREEN_W - 44, COLOR_MOVES_NEW, 20, 2)
      end
    end

    def carrier_popup_page_size
      panel_h = SCREEN_H - 108
      cols = [[((SCREEN_W - 70) / 68), 4].max, 8].min
      # Match redraw_carrier_popup exactly. The old formula allowed one extra
      # row, which is why the last carriers spilled outside the panel.
      rows = [[(((panel_h - 148) / 58).floor + 1), 2].max, 5].min
      return cols * rows
    end

    def show_carrier_popup(entry)
      return if !entry
      users = entry_all_users(entry)
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
      panel_x = 16
      panel_y = 58
      panel_w = SCREEN_W - 32
      panel_h = SCREEN_H - 108
      bmp.fill_rect(panel_x, panel_y, panel_w, panel_h, ChangeDexConfig.color("colorPanelFill", [20, 28, 40], 236))
      bmp.fill_rect(panel_x, panel_y, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y + panel_h - 1, panel_w, 1, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      bmp.fill_rect(panel_x + panel_w - 1, panel_y, 1, panel_h, ChangeDexConfig.color("colorPanelEdge", [88, 106, 138], 210))
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("Carriers"), panel_x + 12, panel_y + 8, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      users = carrier_popup_users_sorted(@carrier_popup_entry)
      new_users = (@carrier_popup_entry[:added_users] || [])
      new_lookup = {}
      new_users.each { |k| new_lookup[[k[0], k[1]]] = true }
      per_page = carrier_popup_page_size
      total_pages = [(users.length.to_f / per_page).ceil, 1].max
      @carrier_popup_page = [[@carrier_popup_page, 0].max, total_pages - 1].min
      start_idx = @carrier_popup_page * per_page
      page_users = users[start_idx, per_page] || []
      cols = [[((SCREEN_W - 70) / 68), 4].max, 8].min
      rows = [[(((panel_h - 148) / 58).floor + 1), 2].max, 5].min
      step_x = (cols > 1) ? ((panel_w - 82).to_f / (cols - 1)).round : 0
      step_y = (rows > 1) ? ((panel_h - 130).to_f / (rows - 1)).round : 58
      start_x = panel_x + 41
      start_y = panel_y + 74
      page_users.each_with_index do |key, i|
        sp = key[0]
        f = key[1]
        spr = PokemonSpeciesIconSprite.new(nil, @viewport)
        spr.setOffset(PictureOrigin::CENTER)
        spr.x = start_x + ((i % cols) * step_x)
        spr.y = start_y + ((i / cols) * step_y) - 2
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
      page_txt = VermeilChangeDex.ui("Page {1}/{2}", @carrier_popup_page + 1, total_pages)
      pbDrawTextPositions(bmp, [[page_txt, panel_x + panel_w - 12, panel_y + panel_h - 28, :right, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      controls = VermeilChangeDex.ui("L/R: Page  {1}/{2}: Close", @action_key_name, @back_key_name)
      pbDrawTextPositions(bmp, [[controls, panel_x + 12, panel_y + panel_h - 28, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
    end

    def carrier_popup_users_sorted(entry)
      all_users = entry_all_users(entry).map { |k| [k[0], k[1]] }
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
      # Regional forms use language-aware display order:
      # ES: "Cubone Forma Alola" / EN: "Alolan Form Cubone".
      # Hidden regional routing forms are inferred through their evolution line.
      draw_header(VermeilChangeDex.ui("COMPARISON"), localized_form_display_name(species, form, form_name))
      @detail_has_evo_method_changes = has_evolution_method_changes?(vermeil, canon)
      # Block panels for clearer visual hierarchy.
      draw_panel(bmp, 10, 52, 176, 180)   # Left: 84x84 icon + typing
      draw_panel(bmp, 196, 52, SCREEN_W - 206, 180)  # Right: stat comparison
      if @sprites["big_icon"] && !@sprites["big_icon"].disposed?
        @sprites["big_icon"].dispose
      end
      if @sprites["detail_variant_mark"] && !@sprites["detail_variant_mark"].disposed?
        @sprites["detail_variant_mark"].dispose
        @sprites.delete("detail_variant_mark")
      end
      @detail_variant_mark_base_y = nil
      @sprites["big_icon"] = PokemonSpeciesIconSprite.new(nil, @viewport)
      @sprites["big_icon"].setOffset(PictureOrigin::CENTER); @sprites["big_icon"].x, @sprites["big_icon"].y = LEFT_PANEL_CENTER_X, 104
      @sprites["big_icon"].z = 210; @sprites["big_icon"].pbSetParams(species, 0, form, false); fit_species_icon(@sprites["big_icon"])
      vframe = hidden_variant_icon_frame(species, form)
      if !vframe.nil?
        mark = IconSprite.new(0, 0, @viewport)
        mark.setBitmap("Graphics/UI/RegionalVariantIcon")
        mark.src_rect.set(vframe * 32, 0, 32, 32)
        mark.x = LEFT_PANEL_CENTER_X - 44
        mark.y = 56
        mark.z = 212
        @sprites["detail_variant_mark"] = mark
        @detail_variant_mark_base_y = mark.y
      end
      
      # TYPE ICONS
      c_types = (canon[:types] || []).to_a; v_types = (vermeil.types || []).to_a; type_y = 142; type_center_x = LEFT_PANEL_CENTER_X
      if c_types.sort != v_types.sort && !c_types.empty?
        draw_type_icons(bmp, c_types, type_center_x, type_y, 150)
        pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("New Typing"), type_center_x, type_y + 34, :center, COLOR_TEXT_MAIN, Color.new(0,0,0,100)]])
        draw_type_icons(bmp, v_types, type_center_x, type_y + 58)
      else
        draw_type_icons(bmp, v_types, type_center_x, type_y + 24)
      end

      # STATS LAYOUT (Lowered and Spaced)
      v_stats = species_stats_array(vermeil)
      c_stats = canon[:stats]
      has_new_evos = !gained_evolution_species(vermeil, canon).empty?
      x_base = has_new_evos ? 214 : 238
      y_base = 96
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("Original"), x_base + 92, y_base - 30, :center, COLOR_CANON], [VermeilChangeDex.game_name, x_base + 202, y_base - 30, :center, COLOR_VERMEIL]])
      draw_new_evolution_icons(species, form, canon, x_base, y_base)
      ["HP","ATK","DEF","SPE","SPA","SPD"].each_with_index do |lbl, i|
        yy = y_base + (i*22); c_v = c_stats[i] || 0; v_v = v_stats[i]
        pbDrawTextPositions(bmp, [[lbl, x_base, yy, :left, COLOR_TEXT_GRAY], [c_v.to_s, x_base + 92, yy, :center, COLOR_CANON], [v_v.to_s, x_base + 202, yy, :center, (v_v != c_v ? COLOR_DIFF : COLOR_TEXT_MAIN)]])
        if v_v != c_v
          diff = v_v - c_v; txt = (diff > 0 ? "+#{diff}" : "#{diff}")
          pbDrawTextPositions(bmp, [[txt, x_base + 252, yy, :left, (diff > 0 ? Color.new(100,255,100) : Color.new(255,100,100))]])
        end
      end
      
      # ABILITIES SECTION
      abilities_panel_y = 240
      draw_panel(bmp, 10, abilities_panel_y, SCREEN_W - 20, 92)
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("Abilities:"), 20, abilities_panel_y + 9, :left, COLOR_HIGHLIGHT]])
      abilities_text_y = abilities_panel_y + 32
      abilities_end_y = abilities_text_y
      c_slots = build_ability_slots(canon[:abilities], canon[:hidden_abilities], true)
      v_slots = build_ability_slots(vermeil.abilities, vermeil.hidden_abilities, false)
      display_entries = build_display_ability_entries(c_slots, v_slots)
      if display_entries.empty?
        lines = draw_wrapped_text(bmp, VermeilChangeDex.ui("No changes detected in abilities."), 20, abilities_text_y, SCREEN_W - 44, COLOR_TEXT_GRAY, 22, 2)
        abilities_end_y = abilities_text_y + (lines * 22)
      else
        lines = draw_colored_ability_entries(bmp, display_entries, 20, abilities_text_y, SCREEN_W - 44, 22, 2)
        abilities_end_y = abilities_text_y + (lines * 22)
      end
      
      # MOVES SECTION (isolated comparisons)
      v_moves = vermeil.moves.map { |m| m[1] }.uniq
      v_tutor_moves = (vermeil.respond_to?(:tutor_moves) ? (vermeil.tutor_moves || []).compact.uniq : [])
      c_pool = (canon[:level_moves] + canon[:tutor_moves] + canon[:egg_moves]).uniq
      c_tutor = (canon[:tutor_moves] || []).compact.uniq
      level_added_names = (v_moves - c_pool).map { |m| VermeilChangeDex.localized_move_name(m) }
      tutor_added_names = (v_tutor_moves - c_tutor).map { |m| VermeilChangeDex.localized_move_name(m) }
      moves_header_y = [344, abilities_end_y + 8].max
      draw_panel(bmp, 10, moves_header_y - 6, SCREEN_W - 20, SCREEN_H - (moves_header_y - 6) - 10)
      draw_move_change_section(bmp, level_added_names, tutor_added_names, moves_header_y)
      action_opts = detail_action_options
      if !action_opts.empty?
        header_hint = action_opts.length > 1 ? VermeilChangeDex.ui("{1}: Options", @action_key_name) : VermeilChangeDex.ui("{1}: {2}", @action_key_name, action_opts[0][1])
        pbDrawTextPositions(bmp, [[header_hint, (SCREEN_W / 2) - 28, 12, :center, Color.new(255,255,255), Color.new(0,0,0,120)]])
      end
    end

    def draw_new_moves(bmp, list, header_y = 296)
      y, max_w = header_y + 22, SCREEN_W - 44
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("New Moves:"), 20, header_y, :left, COLOR_HIGHLIGHT]])
      if list.empty?; pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("No moves added to this Pokémon."), 20, y, :left, COLOR_TEXT_GRAY]]); return; end
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
      pbDrawTextPositions(bmp, [[VermeilChangeDex.ui("New Moves:"), 20, y, :left, COLOR_HIGHLIGHT]])
      if @detail_moves_truncated
        hint_txt = VermeilChangeDex.ui("{1} - More Info", @filter_key_name)
        pbDrawTextPositions(bmp, [[hint_txt, 148, y, :left, COLOR_TEXT_GRAY, Color.new(0,0,0,120)]])
      end
      y += 22
      if combined.empty?
        draw_wrapped_text(bmp, VermeilChangeDex.ui("No moves added to this Pokémon."), 20, y, SCREEN_W - 44, COLOR_TEXT_GRAY, 22, 3)
      else
        full_text = combined.join(", ")
        draw_wrapped_text(bmp, full_text, 20, y, SCREEN_W - 44, COLOR_MOVES_NEW, 22, 3)
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

    def draw_custom_strip(bmp, name, x, y, w, h)
      custom = VermeilChangeDex.custom_ui_bitmap(name)
      return false if !custom
      bmp.stretch_blt(Rect.new(x, y, w, h), custom, Rect.new(0, 0, custom.width, custom.height))
      return true
    rescue StandardError
      return false
    end

    def draw_panel(bmp, x, y, w, h)
      custom = VermeilChangeDex.custom_ui_bitmap("panel")
      if custom
        draw_custom_panel_9slice(bmp, custom, x, y, w, h)
        return
      end
      bmp.fill_rect(x, y, w, h, COLOR_PANEL_FILL)
      bmp.fill_rect(x, y, w, 1, COLOR_PANEL_EDGE)
      bmp.fill_rect(x, y + h - 1, w, 1, COLOR_PANEL_EDGE)
      bmp.fill_rect(x, y, 1, h, COLOR_PANEL_EDGE)
      bmp.fill_rect(x + w - 1, y, 1, h, COLOR_PANEL_EDGE)
    end

    # Custom panels used to stretch the whole PNG, deforming rounded corners and
    # borders differently on every screen. Keep corners pixel-perfect and only
    # stretch the center/edges (simple 9-slice).
    def draw_custom_panel_9slice(dst, src, x, y, w, h)
      return if !dst || !src || w <= 0 || h <= 0
      cut = [[16, src.width / 3, src.height / 3, w / 2, h / 2].min, 2].max
      sw = src.width; sh = src.height
      mid_sw = [sw - cut * 2, 1].max; mid_sh = [sh - cut * 2, 1].max
      mid_dw = [w - cut * 2, 1].max; mid_dh = [h - cut * 2, 1].max
      # center
      dst.stretch_blt(Rect.new(x + cut, y + cut, mid_dw, mid_dh), src, Rect.new(cut, cut, mid_sw, mid_sh))
      # top/bottom
      dst.stretch_blt(Rect.new(x + cut, y, mid_dw, cut), src, Rect.new(cut, 0, mid_sw, cut))
      dst.stretch_blt(Rect.new(x + cut, y + h - cut, mid_dw, cut), src, Rect.new(cut, sh - cut, mid_sw, cut))
      # left/right
      dst.stretch_blt(Rect.new(x, y + cut, cut, mid_dh), src, Rect.new(0, cut, cut, mid_sh))
      dst.stretch_blt(Rect.new(x + w - cut, y + cut, cut, mid_dh), src, Rect.new(sw - cut, cut, cut, mid_sh))
      # corners
      dst.blt(x, y, src, Rect.new(0, 0, cut, cut))
      dst.blt(x + w - cut, y, src, Rect.new(sw - cut, 0, cut, cut))
      dst.blt(x, y + h - cut, src, Rect.new(0, sh - cut, cut, cut))
      dst.blt(x + w - cut, y + h - cut, src, Rect.new(sw - cut, sh - cut, cut, cut))
    rescue StandardError
      dst.stretch_blt(Rect.new(x, y, w, h), src, Rect.new(0, 0, src.width, src.height))
    end

    def ability_name_from_id(ability_id, use_try = true)
      return nil if ability_id.nil? || ability_id == :NONE
      fallback = if use_try
                   GameData::Ability.try_get(ability_id)&.name || ability_id.to_s
                 else
                   GameData::Ability.get(ability_id).name
                 end
      return VermeilChangeDex.localized_ability_name(ability_id, fallback)
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
      label_x = SCREEN_W - 148
      label_y = y_base - 30
      @sprites["evo_label_overlay"] = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
      @sprites["evo_label_overlay"].z = 220
      pbSetSystemFont(@sprites["evo_label_overlay"].bitmap)
      pbDrawTextPositions(@sprites["evo_label_overlay"].bitmap, [[label, label_x, label_y, :left, COLOR_HIGHLIGHT, Color.new(0,0,0,120)]])
      icon_x = SCREEN_W - 74
      icon_y = y_base + 30
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
      bmp = @sprites["overlay"].bitmap
      if !draw_custom_strip(bmp, "header", 0, 0, SCREEN_W, 44)
        bmp.fill_rect(0, 0, SCREEN_W, 44, ChangeDexConfig.color("colorHighlight", [180, 40, 50]))
        bmp.fill_rect(0, 42, SCREEN_W, 2, Color.new(255, 255, 255, 100))
      end
      pbDrawTextPositions(bmp, [[t1, 20, 12, :left, COLOR_TEXT_MAIN], [t2, SCREEN_W-20, 12, :right, COLOR_TEXT_MAIN]])
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
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || special_trigger?
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
            if Input.trigger?(Input::BACK) || special_trigger?
              if Input.trigger?(Input::BACK)
                break
              else
                close_category_menu(false)
              end
              next
            end
            next
          end
          if special_trigger?
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
            if Input.trigger?(Input::BACK) || special_trigger?
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
            if Input.trigger?(Input::BACK) || special_trigger?
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
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || special_trigger?
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
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || special_trigger?
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
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || special_trigger?
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
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || special_trigger?
              # Keep cached wrapped lines so the popup can be reopened
              # without changing entry.
              hide_new_moves_popup(false)
            end
            next
          end
          if @level_movepool_popup_open
            if Input.repeat?(Input::LEFT)
              @level_movepool_popup_page -= 1
              redraw_level_movepool_popup
            elsif Input.repeat?(Input::RIGHT)
              @level_movepool_popup_page += 1
              redraw_level_movepool_popup
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || special_trigger?
              hide_level_movepool_popup(false)
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
            elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || special_trigger?
              hide_carrier_popup
            end
            next
          end
          if @evo_popup_open
            if Input.trigger?(Input::ACTION) || Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || special_trigger?
              hide_evolution_method_popup
            end
            next
          end
          if special_trigger?
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
              users = entry ? entry_all_users(entry) : []
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
        hide_level_movepool_popup if @level_movepool_popup_open
        sp = @entries[@index][0]
        form = @entries[@index][1]
        prepare_detail_form_options(sp, form)
        draw_detail_view(sp, @detail_form_options[@detail_form_option_index] || form)
      else
        hide_carrier_popup if @carrier_popup_open
        hide_ability_moves_popup if @ability_moves_popup_open
        hide_ability_rework_popup if @ability_rework_popup_open
        hide_move_rework_popup if @move_rework_popup_open
        hide_level_movepool_popup if @level_movepool_popup_open
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

  def self.prewarm_indexes!
    return true if @prewarm_running
    @prewarm_running = true
    begin
      ChangeDexConfig.reload! if defined?(ChangeDexConfig) && ChangeDexConfig.respond_to?(:reload!)
      # Never persist an index while Essentials is still rebuilding the
      # registries. ChangeDex needs the Species registry even for Move/Ability
      # carrier indexing, so require it for every preload, not only when the JSON
      # happens to contain species overrides.
      registry_count = 0
      begin
        GameData::Species.each { |_s| registry_count += 1 }
      rescue StandardError
        registry_count = 0
      end
      return false if registry_count <= 0
      load_persistent_detect_cache!
      cached = detect_cache
      if cached && cached[:version] == DETECT_CACHE_VERSION && cached[:non_pokemon_indexes_ready]
        # Category lists/counts are ready. Full carrier lists are intentionally
        # lazy now so boot/compilation never scans every species just to fill a
        # popup the player may never open.
        return true
      end
      worker = Scene.allocate
      worker.instance_variable_set(:@category, :pokemon_changes)
      worker.instance_variable_set(:@sort_mode, :dex)
      worker.instance_variable_set(:@type_filter, :all)
      worker.instance_variable_set(:@generation_filter, nil)
      worker.instance_variable_set(:@entry_sort_mode, :az)
      worker.instance_variable_set(:@entry_type_filter, :all)
      worker.instance_variable_set(:@entry_damage_filter, :all)
      worker.instance_variable_set(:@entry_exclusive_filter, :all)
      worker.instance_variable_set(:@index, 0)
      worker.send(:detect_changes)
      unless worker.instance_variable_get(:@non_pokemon_indexes_ready)
        worker.send(:build_non_pokemon_indexes)
        worker.instance_variable_set(:@non_pokemon_indexes_ready, true)
      end
      # build_non_pokemon_indexes already prepares Move/Ability/New category
      # counts and their added/removed users. All Carriers is resolved on demand.
      true
    rescue StandardError => e
      echoln("[ChangeDex] Preload skipped: #{e.message}") if defined?(echoln) && ChangeDexConfig.debug_logging?
      false
    ensure
      @prewarm_running = false
    end
  end

  def self.open
    ChangeDexConfig.reload! if defined?(ChangeDexConfig) && ChangeDexConfig.respond_to?(:reload!)
    scene = Scene.new
    scene.pbStartScene
    scene.pbMain
    scene.pbEndScene
  end
end

ItemHandlers::UseInField.add(:CHANGEDEX, proc { |item| VermeilChangeDex.open; next true })


CarnekChangeData.install_hooks!

# v0.11.1: ChangeDex only prewarms its comparison index here. Translation is
# owned by the independent [CARNKEVT] Translate Studio plugin.
if defined?(Game)
  module ChangeDexBootPrewarm
    def initialize(*args, &block)
      ret = super(*args, &block)
      begin
        VermeilChangeDex.prewarm_indexes!
      rescue StandardError => e
        echoln("[ChangeDex] Boot preload skipped: #{e.message}") if defined?(echoln) && ChangeDexConfig.debug_logging?
      end
      ret
    end
  end
  begin
    game_singleton = class << Game; self; end
    game_singleton.prepend(ChangeDexBootPrewarm) unless game_singleton.ancestors.include?(ChangeDexBootPrewarm)
  rescue StandardError
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :changedex_studio, {
    "name"        => VermeilChangeDex.ui("ChangeDex"),
    "parent"      => :main,
    "description" => VermeilChangeDex.ui("Open the ChangeDex comparison screen."),
    "effect"      => proc { |sprites, viewport| VermeilChangeDex.open }
  })
end
