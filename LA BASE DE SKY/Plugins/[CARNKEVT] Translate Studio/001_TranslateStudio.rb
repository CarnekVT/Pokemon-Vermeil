# encoding: UTF-8
#===============================================================================
# [CARNKEVT] Translate Studio v1.4.0
# Direct contextual localization runtime for Pokémon Essentials v21.1.
#
# - Español / English selector with first-boot gamefeel.
# - No Extract -> Compile cycle: translations.json is read directly.
# - General/Event/Script/Plugin text are separated and indexed in memory.
# - New development maps/events/scripts/plugins are discovered incrementally.
# - BSS battle blueprint text and SDS/Scene Engine dialogue share this catalog.
# - GameData + MessageTypes + Debug listers follow the active language.
# - Localized graphics support *_ESP / *_ENG and legacy suffixes.
#===============================================================================
require "json" if !defined?(JSON)
begin
  require "zlib" if !defined?(Zlib)
rescue LoadError
end

module CarnekTranslateStudio
  VERSION = "1.4.0"
  DATA_PATH = "Data/TranslateStudio/translations.json"
  CONFIG_PATH = "Data/TranslateStudio/config.json"
  PREF_PATH = "Data/TranslateStudio/language.json"
  CANON_EN_PATH = "Data/TranslateStudio/canon_localization_en.json"
  CANON_ITEMS_PATH = "Data/TranslateStudio/canon_items_localization.json"
  CATALOG_PATH = "Data/TranslateStudio/catalog.json"
  DISCOVERY_CACHE_PATH = "Data/TranslateStudio/discovery_cache.json"
  PLUGIN_EN_REFERENCE_PATH = "Data/TranslateStudio/plugin_english_reference.json"
  BASE_EN_REFERENCE_PATH = "Data/TranslateStudio/base_english_reference.json"
  STRICT_CONTEXT_EN_PATH = "Data/TranslateStudio/strict_context_english.json"

  TEXT_BUCKETS = ["general", "events", "scripts", "plugins", "bss", "sds"]
  DATA_BUCKETS = ["species", "moves", "abilities", "items", "types"]
  REFERENCE_BUCKETS = ["pbs"]

  LANGUAGE_INFO = {
    "es" => {
      "name" => "Español",
      "short" => "ESP",
      "nativeFragments" => ["spanish", "espanol", "español", "es"],
      "textFolders" => ["Text_spanish_game", "Text_espanol_game", "Text_español_game", "Text_esp_game", "Text_es_game"],
      "graphicSuffixes" => ["_ESP", "_ES", "_SPANISH", "_esp", "_es", "_spanish"]
    },
    "en" => {
      "name" => "English",
      "short" => "ENG",
      "nativeFragments" => ["english", "eng", "en"],
      "textFolders" => ["Text_english_game", "Text_eng_game", "Text_en_game"],
      "graphicSuffixes" => ["_ENG", "_EN", "_ENGLISH", "_USA", "_eng", "_en", "_english", "_usa"]
    }
  }

  DEFAULT_CONFIG = {
    "schema" => 6,
    "activeLanguage" => "auto",
    "baseLanguage" => "es",
    "applyToGame" => true,
    "showFirstBootLanguageMenu" => true,
    "showLanguageOption" => true,
    "showDebugTools" => true,
    "readDirectTextPacks" => false,
    "preferLocalizedGraphics" => true,
    "graphicRules" => {},
    "autoDiscoverDevelopmentTexts" => true,
    "discoveryOnlyInDebug" => true,
    "languageMenuMode" => "graphics",
    "languageMenuBackground" => "Graphics/UI/TranslateStudio/language_bg.png",
    "languageMenuHeader" => "Graphics/UI/TranslateStudio/language_header.png",
    "languageMenuFooter" => "Graphics/UI/TranslateStudio/language_footer.png",
    "languageMenuCardES" => "Graphics/UI/TranslateStudio/language_es.png",
    "languageMenuCardEN" => "Graphics/UI/TranslateStudio/language_en.png",
    "languageMenuCursor" => "Graphics/UI/TranslateStudio/language_cursor.png",
    "languageMenuCustomCode" => "Data/TranslateStudio/language_menu_custom.rb"
  }

  @doc = nil
  @config = nil
  @canon_en = nil
  @canon_items = nil
  @installed_methods = {}
  @reverse_index = nil
  @reverse_signature = nil
  @session_language = nil
  @text_indexes = {}
  @context_fast_cache = {}
  @direct_pack_cache = {}
  @graphic_cache = {}
  @bootstrapped = false
  @language_revision = 0
  @debug_lister_patches_installed = false
  @context_catalog = nil
  @context_catalog_signature = nil
  @external_document_cache = {}
  @bss_bridge_module = nil
  @sds_bridge_module = nil
  @plugin_english_reference = nil
  @plugin_reference_index = nil
  @base_english_reference = nil
  @base_reference_index = nil
  @reference_autofill_pending = nil
  @reference_autofill_collisions = nil

  #-----------------------------------------------------------------------------
  # Files / JSON
  #-----------------------------------------------------------------------------
  def self.utf8_text(raw)
    s = raw.to_s.dup
    begin
      s.force_encoding(Encoding::UTF_8)
      s = s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
    rescue StandardError
    end
    s.sub!(/\A\uFEFF/, "")
    s
  end

  def self.read_json(path, fallback)
    return fallback if !File.file?(path)
    raw = utf8_text(File.open(path, "rb") { |f| f.read })
    parsed = JSON.parse(raw)
    parsed.is_a?(Hash) ? parsed : fallback
  rescue StandardError
    fallback
  end

  def self.ensure_data_dir!
    Dir.mkdir("Data") if !File.directory?("Data")
    Dir.mkdir("Data/TranslateStudio") if !File.directory?("Data/TranslateStudio")
    true
  rescue StandardError
    false
  end

  def self.write_json(path, data)
    ensure_data_dir!
    File.open(path, "wb") { |f| f.write(JSON.pretty_generate(data)) }
    true
  rescue StandardError
    false
  end

  def self.sig(path)
    return nil if !File.file?(path)
    [File.size(path).to_i, File.mtime(path).to_i]
  rescue StandardError
    nil
  end

  def self.document
    return @doc if @doc
    @doc = read_json(DATA_PATH, { "schema" => 6, "languages" => { "es" => {}, "en" => {} } })
    @doc["languages"] = {} if !@doc["languages"].is_a?(Hash)
    ["es", "en"].each do |lang|
      @doc["languages"][lang] = {} if !@doc["languages"][lang].is_a?(Hash)
      (DATA_BUCKETS + TEXT_BUCKETS + REFERENCE_BUCKETS).each do |bucket|
        @doc["languages"][lang][bucket] = {} if !@doc["languages"][lang][bucket].is_a?(Hash)
      end
      # Legacy flat-string buckets are intentionally ignored. v0.7 uses
      # project-scoped contextual buckets plus canonical structured data.
      @doc["languages"][lang].delete("strings")
    end
    @doc
  end

  def self.config
    return @config if @config
    @config = DEFAULT_CONFIG.clone
    @config.merge!(read_json(CONFIG_PATH, {}))
    @config["graphicRules"] = {} if !@config["graphicRules"].is_a?(Hash)
    @config
  end

  def self.reload!
    @doc = nil
    @config = nil
    @canon_en = nil
    @canon_items = nil
    @direct_pack_cache = {}
    @text_indexes = {}
    @pbs_indexes = {}
    @context_fast_cache = {}
    @template_text_indexes = {}
    @graphic_cache = {}
    @reverse_index = nil
    @reverse_signature = nil
    @context_catalog = nil
    @context_catalog_signature = nil
    @external_document_cache = {}
    @plugin_english_reference = nil
    @plugin_reference_index = nil
    @base_english_reference = nil
    @base_reference_index = nil
    @reference_autofill_pending = nil
    @reference_autofill_collisions = nil
    @language_revision = @language_revision.to_i + 1
    true
  end

  def self.invalidate!
    @reverse_index = nil
    @reverse_signature = nil
    true
  end

  def self.canon_en
    @canon_en ||= read_json(CANON_EN_PATH, { "species" => {}, "moves" => {}, "abilities" => {} })
  end

  def self.canon_items
    @canon_items ||= read_json(CANON_ITEMS_PATH, { "es" => {}, "en" => {} })
  end

  # Only event strings that belong to maps/common events detected in the current
  # project are allowed to use the Events bucket. This prevents old reference/sample
  # map catalogs from translating unrelated custom events that happen to share a
  # short literal such as "..." or "Yes".
  def self.context_catalog
    signature = sig(CATALOG_PATH)
    if @context_catalog.nil? || @context_catalog_signature != signature
      @context_catalog = read_json(CATALOG_PATH, {
        "schema" => 2, "generatedBy" => "Translate Studio #{VERSION}",
        "events" => {}, "scripts" => {}, "plugins" => {}, "general" => {},
        "bss" => {}, "sds" => {}
      })
      if @context_catalog["schema"].to_i < 2 || @context_catalog["generatedBy"].to_s !~ /\ATranslate Studio\b/i
        @context_catalog = empty_catalog
      end
      @context_catalog_signature = signature
    end
    @context_catalog
  rescue StandardError
    { "events" => {}, "scripts" => {}, "plugins" => {}, "general" => {}, "bss" => {}, "sds" => {} }
  end

  def self.current_event_source?(source)
    rows = context_catalog["events"] rescue nil
    rows.is_a?(Hash) && rows.key?(source.to_s)
  rescue StandardError
    false
  end

  #-----------------------------------------------------------------------------
  # Language state / persistence
  #-----------------------------------------------------------------------------
  def self.language_from_tokens(tokens)
    raw = Array(tokens).compact.map { |v| v.to_s }.join(" ").downcase
    return "es" if raw.include?("españ") || raw.include?("espan") || raw.include?("spanish") || raw =~ /(^|[^a-z])esp([^a-z]|$)/ || raw =~ /(^|[^a-z])es([^a-z]|$)/
    return "en" if raw.include?("english") || raw =~ /(^|[^a-z])eng([^a-z]|$)/ || raw =~ /(^|[^a-z])en([^a-z]|$)/
    nil
  end

  def self.native_language_for_index(index)
    return nil if !defined?(Settings::LANGUAGES) || !Settings::LANGUAGES || Settings::LANGUAGES.empty?
    entry = Settings::LANGUAGES[index.to_i] rescue nil
    return nil if !entry
    language_from_tokens(entry.is_a?(Array) ? entry : [entry])
  rescue StandardError
    nil
  end

  def self.native_index_for(code)
    return nil if !defined?(Settings::LANGUAGES) || !Settings::LANGUAGES || Settings::LANGUAGES.empty?
    Settings::LANGUAGES.each_with_index do |entry, i|
      tokens = entry.is_a?(Array) ? entry : [entry]
      return i if language_from_tokens(tokens) == code.to_s.downcase
    end
    nil
  rescue StandardError
    nil
  end

  def self.saved_language
    row = read_json(PREF_PATH, {})
    code = row["language"].to_s.downcase
    ["es", "en"].include?(code) ? code : nil
  rescue StandardError
    nil
  end

  def self.preference_exists?
    File.file?(PREF_PATH) && !saved_language.nil?
  rescue StandardError
    false
  end

  def self.save_language(code)
    code = code.to_s.downcase
    return false if !["es", "en"].include?(code)
    write_json(PREF_PATH, { "language" => code, "savedBy" => "Translate Studio #{VERSION}" })
  end

  def self.system_language_guess
    raw = ""
    begin
      raw = System.user_language.to_s if defined?(System) && System.respond_to?(:user_language)
    rescue StandardError
    end
    detected = language_from_tokens([raw])
    return detected if detected
    base = config["baseLanguage"].to_s.downcase
    ["es", "en"].include?(base) ? base : "es"
  rescue StandardError
    "es"
  end

  def self.forced_language
    forced = config["activeLanguage"].to_s.downcase
    ["es", "en"].include?(forced) ? forced : nil
  end

  def self.language_code
    forced = forced_language
    return forced if forced
    return @session_language if ["es", "en"].include?(@session_language)
    saved = saved_language
    return saved if saved
    begin
      if defined?($PokemonSystem) && $PokemonSystem && $PokemonSystem.respond_to?(:language)
        native = native_language_for_index($PokemonSystem.language)
        return native if native
      end
    rescue StandardError
    end
    base = config["baseLanguage"].to_s.downcase
    ["es", "en"].include?(base) ? base : "es"
  end

  def self.language_index
    language_code == "en" ? 1 : 0
  end

  def self.language_name(code = language_code)
    LANGUAGE_INFO.dig(code.to_s.downcase, "name") || code.to_s
  end

  def self.enabled?
    v = config["applyToGame"]
    v != false && v.to_s.downcase != "false"
  end

  def self.language_revision
    @language_revision.to_i
  end

  def self.apply_native_language_hint!(code)
    idx = native_index_for(code)
    return false if idx.nil? || !defined?($PokemonSystem) || !$PokemonSystem
    # Do not call PokemonSystem#language=. Native Essentials can try to load a
    # compiled language pack; Translate Studio intentionally does not need one.
    $PokemonSystem.instance_variable_set(:@language, idx)
    true
  rescue StandardError
    false
  end

  def self.clear_runtime_caches!
    @graphic_cache = {}
    @text_indexes = {}
    @pbs_indexes = {}
    @context_fast_cache = {}
    @template_text_indexes = {}
    @direct_pack_cache = {}
    @external_document_cache = {}
    invalidate!
    begin
      RPG::Cache.clear if defined?(RPG::Cache) && RPG::Cache.respond_to?(:clear)
    rescue StandardError
    end
    true
  end

  def self.set_language!(code, persist = true)
    code = code.to_s.downcase
    return false if !["es", "en"].include?(code)
    @session_language = code
    save_language(code) if persist && !forced_language
    apply_native_language_hint!(code)
    @language_revision = @language_revision.to_i + 1
    clear_runtime_caches!
    install!
    $carnek_translate_language_changed = true
    true
  rescue StandardError
    false
  end

  def self.apply_native_language_index!(value)
    code = native_language_for_index(value)
    code = value.to_i == 1 ? "en" : "es" if code.nil? && [0, 1].include?(value.to_i)
    return false if code.nil?
    set_language!(code, true)
  rescue StandardError
    false
  end

  def self.extract_intl!(_core = false)
    pbMessage("Translate Studio v#{VERSION}: ya no necesitas extraer textos para aplicar traducciones.") rescue nil
    true
  end

  def self.compile_intl!
    pbMessage("Translate Studio v#{VERSION}: ya no necesitas compilar un paquete de idioma. Guarda el JSON y recarga.") rescue nil
    true
  end

  #-----------------------------------------------------------------------------
  # Contextual text data - indexed once, O(1) lookups during gameplay
  #-----------------------------------------------------------------------------
  def self.normalize_string_key(text)
    s = text.to_s.dup
    s.gsub!("\\r", "\n")
    s.gsub!("\\n", "\n")
    s.gsub!("\r\n", "\n")
    s.gsub!("\r", "\n")
    s.strip
  rescue StandardError
    text.to_s
  end

  def self.text_value(value)
    return value["Text"].to_s if value.is_a?(Hash)
    value.to_s
  end

  def self.direct_text_pack_rows(lang)
    return {} if config["readDirectTextPacks"] == false
    lang = lang.to_s.downcase
    return @direct_pack_cache[lang] if @direct_pack_cache.key?(lang)
    rows = {}
    folders = LANGUAGE_INFO.dig(lang, "textFolders") || []
    folders.each do |folder|
      next if !File.directory?(folder)
      Dir.glob("#{folder}/*.txt").sort.each do |path|
        begin
          raw = utf8_text(File.open(path, "rb") { |f| f.read })
          lines = raw.split(/\r?\n/, -1)
          start = lines.index { |line| line.to_s.strip =~ /^\[[^\]]+\]$/ }
          next if start.nil?
          payload = lines[(start + 1)..-1] || []
          payload.pop while !payload.empty? && payload[-1].to_s.empty?
          i = 0
          while i + 1 < payload.length
            source = payload[i].to_s
            translated = payload[i + 1].to_s
            rows[source] = translated if !source.empty? && !translated.empty? && translated != source && !rows.key?(source)
            i += 2
          end
        rescue StandardError
        end
      end
    end
    @direct_pack_cache[lang] = rows
    rows
  rescue StandardError
    @direct_pack_cache[lang] = {}
  end

  def self.text_rows(lang, bucket)
    lang = lang.to_s.downcase
    bucket = bucket.to_s
    rows = {}
    if bucket == "general"
      direct_text_pack_rows(lang).each { |k, v| rows[k.to_s] = v.to_s }
    end
    json_rows = document.dig("languages", lang, bucket) rescue nil
    if json_rows.is_a?(Hash)
      json_rows.each do |source, value|
        next if bucket == "events" && !current_event_source?(source)
        txt = text_value(value)
        rows[source.to_s] = txt if !txt.empty?
      end
    end
    rows
  rescue StandardError
    {}
  end

  def self.build_text_index!(lang, bucket)
    lang = lang.to_s.downcase
    bucket = bucket.to_s
    @text_indexes[lang] ||= {}
    return @text_indexes[lang][bucket] if @text_indexes[lang][bucket]
    exact = text_rows(lang, bucket)
    normalized = {}
    collisions = {}
    exact.each do |source, translated|
      key = normalize_string_key(source)
      next if key.empty?
      if normalized.key?(key) && normalized[key] != translated
        collisions[key] = true
      else
        normalized[key] = translated
      end
    end
    collisions.each_key { |key| normalized.delete(key) }
    @text_indexes[lang][bucket] = { :exact => exact, :normalized => normalized }
  rescue StandardError
    { :exact => {}, :normalized => {} }
  end

  def self.lookup_text(bucket, source, lang = language_code)
    return nil if !enabled?
    original = source.to_s
    idx = build_text_index!(lang, bucket)
    txt = idx[:exact][original]
    txt = idx[:normalized][normalize_string_key(original)] if txt.nil? || txt.to_s.empty?
    txt = txt.to_s
    txt.empty? ? nil : txt
  rescue StandardError
    nil
  end

  # Clean-English call-site reference. Unlike the normal text table, this can
  # distinguish identical Spanish literals that mean different things in
  # different base scripts (for example Guardar = Save / Store / Take).
  # The table is generated only from the user's clean English base and never
  # from events. It is consulted before the global translation memory.
  def self.strict_context_reference
    @strict_context_reference ||= read_json(STRICT_CONTEXT_EN_PATH, { "schema" => 1, "files" => {} })
  rescue StandardError
    { "schema" => 1, "files" => {} }
  end

  def self.strict_context_basename(path)
    base = path.to_s.tr("\\", "/").split("/").last.to_s.downcase
    base = base.sub(/\A(?:\[[^\]]+\]\s*)+/, "")
    base = base.sub(/\A\[?\d{3}\]?[_ -]*/, "")
    base
  rescue StandardError
    ""
  end

  def self.strict_context_index
    return @strict_context_index if @strict_context_index
    by_base = Hash.new { |h, k| h[k] = [] }
    by_path = {}
    files = strict_context_reference["files"]
    files = {} if !files.is_a?(Hash)
    files.each do |key, row|
      next if !row.is_a?(Hash)
      rel = key.to_s.tr("\\", "/").downcase
      by_path[rel] = row
      b = row["basenameKey"].to_s.downcase
      b = strict_context_basename(row["path"]) if b.empty?
      by_base[b] << row if !b.empty?
    end
    @strict_context_index = { :path => by_path, :base => by_base }
  rescue StandardError
    @strict_context_index = { :path => {}, :base => {} }
  end

  def self.strict_context_candidates_for_location(path)
    idx = strict_context_index
    clean = path.to_s.tr("\\", "/").downcase
    # Prefer a full project-relative suffix when the runtime exposes it.
    hit = nil
    idx[:path].each do |rel, row|
      if clean.end_with?(rel) || clean.end_with?("data/scripts/" + rel)
        hit = row
        break
      end
    end
    return [hit] if hit
    idx[:base][strict_context_basename(clean)] || []
  rescue StandardError
    []
  end

  def self.strict_context_text(source)
    return nil if language_code != "en"
    original = source.to_s
    return nil if original.empty?
    loc = nil
    (caller_locations(2, 14) rescue []).each do |candidate|
      pth = candidate.path.to_s
      next if pth.empty?
      next if pth.include?("TranslateStudio") || pth.include?("Translate Studio")
      loc = candidate
      break
    end
    return nil if !loc
    files = strict_context_candidates_for_location(loc.path)
    return nil if files.empty?
    rows = []
    files.each do |frow|
      Array(frow["entries"]).each do |entry|
        next if !entry.is_a?(Hash) || entry["source"].to_s != original
        target = entry["target"].to_s
        rows << entry if !target.empty? && target != original
      end
    end
    return nil if rows.empty?
    targets = rows.map { |r| r["target"].to_s }.uniq
    return targets[0] if targets.length == 1
    line = loc.lineno.to_i
    if line > 0
      chosen = rows.min_by { |r| (r["line"].to_i - line).abs }
      # A fairly generous tolerance handles small code insertions while still
      # preventing a distant repeated literal from being chosen by accident.
      return chosen["target"].to_s if chosen && (chosen["line"].to_i - line).abs <= 80
    end
    nil
  rescue StandardError
    nil
  end

  # BSS sometimes builds a translated message template first and only then
  # substitutes {1}/{2}. Exact dictionary lookup cannot see that final string,
  # so keep a tiny cached template index for BSS raw display routes.
  def self.lookup_template_text(bucket, source, lang = language_code)
    return nil if !enabled?
    @template_text_indexes ||= {}
    cache_key = [lang.to_s.downcase, bucket.to_s]
    rows = @template_text_indexes[cache_key]
    if !rows
      rows = []
      text_rows(lang, bucket).each do |template, translated|
        next if template.to_s !~ /\{\d+\}/
        pieces = []
        order = []
        cursor = 0
        template.to_s.to_enum(:scan, /\{(\d+)\}/).each do
          m = Regexp.last_match
          pieces << Regexp.escape(template.to_s[cursor...m.begin(0)])
          pieces << '(.*?)'
          order << m[1].to_i
          cursor = m.end(0)
        end
        pieces << Regexp.escape(template.to_s[cursor..-1].to_s)
        begin
          rows << [Regexp.new('\\A' + pieces.join + '\\z', Regexp::MULTILINE), order, translated.to_s]
        rescue StandardError
        end
      end
      @template_text_indexes[cache_key] = rows
    end
    rows.each do |regex, order, translated|
      match = regex.match(source.to_s)
      next if !match
      values = {}
      order.each_with_index { |number, i| values[number] = match[i + 1].to_s if !values.key?(number) }
      return translated.gsub(/\{(\d+)\}/) { values[$1.to_i] || $& }
    end
    nil
  rescue StandardError
    nil
  end

  # Core UI strings that must change immediately even when the base scripts
  # were already loaded in Spanish before Translate Studio selected English.
  # This is intentionally small and engine-facing; project dialogue belongs in
  # the editable catalog, not in this table.
  BUILTIN_EN = {
    "<Descripción no disponible>" => "<No description available>",
    "[NUEVO]" => "[NEW]",
    "¿Qué hacer con {1}?" => "What do you want to do with {1}?",
    "¿Qué hacer?" => "What do you want to do?",
    "Cancelar" => "Cancel",
    "Atrás" => "Back",
    "Sí" => "Yes",
    "No" => "No",
    "Hecho" => "Done",
    "Elegir" => "Choose",
    "Confirmar" => "Confirm"
  }

  # The Spanish base registers its debug handlers at script load time. Those
  # labels are therefore already Spanish strings by the time the player changes
  # language. Rebuild them from the stable handler IDs instead of trusting the
  # boot-time display string.
  DEBUG_NAME_EN = {
    :field_menu => "Field options...",
    :warp => "Warp to map",
    :use_pc => "Use PC",
    :switches => "Switches",
    :variables => "Variables",
    :safari_zone_and_bug_contest => "Safari Zone and Bug-Catching Contest",
    :edit_field_effects => "Edit field effects",
    :refresh_map => "Refresh map",
    :day_care => "Day Care",
    :storage_wallpapers => "Toggle storage wallpapers",
    :skip_credits => "Skip credits",
    :battle_menu => "Battle options...",
    :test_wild_battle => "Test wild battle",
    :test_wild_battle_advanced => "Test wild battle (advanced)",
    :test_trainer_battle => "Test trainer battle",
    :test_trainer_battle_advanced => "Test trainer battle (advanced)",
    :set_battle_rules => "Set next battle's rules",
    :partner_trainer => "Set partner trainer",
    :encounter_version => "Set wild encounter version",
    :roamers => "Roaming Pokémon",
    :reset_trainers => "Reset map trainers",
    :toggle_exp_all => "Toggle Exp. All effect",
    :toggle_logging => "Toggle battle message logging",
    :pokemon_menu => "Pokémon options...",
    :heal_party => "Heal party",
    :add_pokemon => "Add Pokémon",
    :fill_boxes => "Fill storage boxes",
    :clear_boxes => "Clear storage boxes",
    :give_demo_party => "Give demo party",
    :quick_hatch_party_eggs => "Quick-hatch party Eggs",
    :open_storage => "Access Pokémon storage",
    :shadow_pokemon_menu => "Shadow Pokémon options...",
    :toggle_snag_machine => "Toggle Snag Machine",
    :toggle_purify_chamber_access => "Toggle Purify Chamber access",
    :purify_chamber => "Use Purify Chamber",
    :relic_stone => "Use Relic Stone",
    :items_menu => "Item options...",
    :add_item => "Add item",
    :fill_bag => "Fill Bag",
    :empty_bag => "Empty Bag",
    :player_menu => "Player options...",
    :set_money => "Set money",
    :set_badges => "Set Gym Badges",
    :toggle_running_shoes => "Toggle Running Shoes",
    :toggle_pokedex => "Toggle Pokédex and Regional Dexes",
    :toggle_pokegear => "Toggle Pokégear",
    :edit_phone_contacts => "Edit phone and contacts",
    :toggle_box_link => "Toggle party storage access",
    :set_player_character => "Set player character",
    :change_outfit => "Set player outfit",
    :rename_player => "Set player name",
    :random_id => "Randomize player ID",
    :pbs_editors_menu => "PBS file editors...",
    :set_map_connections => "Edit map_connections.txt",
    :set_encounters => "Edit encounters.txt",
    :set_trainers => "Edit trainers.txt",
    :set_trainer_types => "Edit trainer_types.txt",
    :set_map_metadata => "Edit map_metadata.txt",
    :set_metadata => "Edit metadata.txt",
    :set_items => "Edit items.txt",
    :set_species => "Edit pokemon.txt",
    :position_sprites => "Edit pokemon_metrics.txt",
    :auto_position_sprites => "Auto-set pokemon_metrics.txt",
    :set_pokedex_lists => "Edit regional_dexes.txt",
    :editors_menu => "Other editors...",
    :animation_editor => "Battle Animation Editor",
    :animation_organiser => "Battle Animation Organizer",
    :import_animations => "Import battle animations",
    :export_animations => "Export battle animations",
    :set_terrain_tags => "Edit terrain tags",
    :fix_invalid_tiles => "Fix invalid tiles",
    :files_menu => "File options...",
    :compile_data => "Compile data",
    :create_pbs_files => "Create PBS files",
    :rename_files => "Rename outdated files",
    :extract_text => "Extract text for translation",
    :compile_text => "Compile translated text",
    :mystery_gift => "Manage Mystery Gifts",
    :mystery_gift_bundle => "Create Mystery Gift bundle",
    :mystery_gift_pokemon_bundle => "Create Mystery Gift Pokémon bundle",
    :mystery_gift_mixed_bundle => "Create mixed Mystery Gift bundle",
    :reload_system_cache => "Reload system cache",
    :pokeapi_download_all => "Download full PokéAPI cache",
    :translate_studio_language => "Translate Studio: Language",
    :translate_studio_reload => "Translate Studio: Reload translations",
    :translate_studio_rescan => "Translate Studio: Refresh catalog"
  }

  def self.builtin_ui_text(source)
    return source.to_s if language_code != "en"
    BUILTIN_EN[source.to_s] || source.to_s
  rescue StandardError
    source.to_s
  end

  def self.spanish_ui_text?(text)
    s = text.to_s
    return false if s.empty?
    return true if s =~ /[¿¡áéíóúñÁÉÍÓÚÑ]/
    !!(s.downcase =~ /\b(?:opciones|saltar|mapa|editar|elige|elegir|combate|entrenador|todos|todas|cambiar|activar|desactivar|usar|campo|almacenamiento|guardería|guardaria|pokémon|variables|interruptores|prueba|testear|actualizar|añadir|vaciar|llenar|definir|alternar|recargar|traduc|archivo|objetos|jugador|equipo)\b/)
  rescue StandardError
    false
  end

  def self.humanize_debug_option(option)
    raw = option.to_s.sub(/^debug_/, "").sub(/_menu$/, "")
    words = raw.split("_").map do |word|
      case word.downcase
      when "pokemon", "pkmn" then "Pokémon"
      when "pokedex" then "Pokédex"
      when "pokegear" then "Pokégear"
      when "pokeapi" then "PokéAPI"
      when "pbs" then "PBS"
      when "bgm" then "BGM"
      when "se" then "SE"
      when "ui" then "UI"
      when "pc" then "PC"
      when "id" then "ID"
      when "ids" then "IDs"
      when "ivs" then "IVs"
      when "evs" then "EVs"
      when "exp" then "Exp."
      when "sos" then "SOS"
      when "bss" then "BSS"
      when "sds" then "SDS"
      else word.capitalize
      end
    end
    label = words.join(" ")
    label += "..." if option.to_s.end_with?("_menu")
    label
  rescue StandardError
    option.to_s
  end

  def self.debug_option_name(option, original = nil)
    return original.to_s if language_code != "en"
    mapped = DEBUG_NAME_EN[option.to_sym] rescue nil
    return mapped if mapped && !mapped.empty?
    source = original.to_s
    translated = lookup_text("scripts", source, "en") || lookup_text("plugins", source, "en")
    return translated if translated && !translated.empty? && !spanish_ui_text?(translated)
    return source if !source.empty? && !spanish_ui_text?(source)
    humanize_debug_option(option)
  rescue StandardError
    original.to_s
  end

  def self.debug_option_description(option, original = nil, name = nil)
    return original.to_s if language_code != "en"
    source = original.to_s
    translated = lookup_text("scripts", source, "en") || lookup_text("plugins", source, "en")
    return translated if translated && !translated.empty? && !spanish_ui_text?(translated)
    return source if !source.empty? && !spanish_ui_text?(source)
    title = name.to_s.sub(/\.\.\.\z/, "")
    title = humanize_debug_option(option).sub(/\.\.\.\z/, "") if title.empty?
    "Debug option: #{title}."
  rescue StandardError
    original.to_s
  end

  def self.general_text(source)
    return source.to_s if !enabled?
    builtin = builtin_ui_text(source)
    return builtin if builtin != source.to_s
    if language_code == "en"
      return "Attacks" if source.to_s == "Atacks"
      return "Attack" if source.to_s == "Atack"
      return "{1} Lv.{2} {3}" if source.to_s == "{1} Nv.{2} {3}"
      return "at the {1}Move Relearner{2}" if source.to_s == "en el {1}recuerda movimientos{2}"
      return "Would you like to give {1} a nickname?" if source.to_s == "¿Te gustaría ponerle un mote a {1}?"
      return "Ultra Burst Method\n" if source.to_s == "Método Ultraexplosión\n"
      return "{1} learned {2}!" if source.to_s == "¡{1} aprendió {2}!"
      return "{1} sent out {2}!" if source.to_s == "¡{1} sacó a {2}!"
    end
    lookup_text("general", source) || source.to_s
  rescue StandardError
    source.to_s
  end

  # Compatibility name used by v0.2 integrations.
  def self.string_text(source)
    general_text(source)
  end

  # Most strings have either one translation or the same translation in every
  # context. Cache that answer so _INTL does not need caller_locations on every
  # invocation. A stack lookup is only used for genuinely ambiguous literals.
  def self.fast_contextual_text(source)
    lang = language_code
    @context_fast_cache[lang] ||= {}
    key = source.to_s
    return @context_fast_cache[lang][key] if @context_fast_cache[lang].key?(key)
    found = []
    ["events", "bss", "sds", "scripts", "plugins", "general"].each do |bucket|
      txt = lookup_text(bucket, key, lang)
      found << txt if txt && !found.include?(txt)
      break if found.length > 1
    end
    value = found.empty? ? nil : (found.length == 1 ? found[0] : :ambiguous)
    @context_fast_cache[lang][key] = value
    value
  rescue StandardError
    nil
  end

  def self.contextual_text(source, kind = nil)
    return source.to_s if !enabled?
    builtin = builtin_ui_text(source)
    return builtin if builtin != source.to_s
    if language_code == "en"
      strict = strict_context_text(source)
      return strict if strict && !strict.empty?
      return "Attacks" if source.to_s == "Atacks"
      return "Attack" if source.to_s == "Atack"
      return "{1} Lv.{2} {3}" if source.to_s == "{1} Nv.{2} {3}"
      return "at the {1}Move Relearner{2}" if source.to_s == "en el {1}recuerda movimientos{2}"
      return "Would you like to give {1} a nickname?" if source.to_s == "¿Te gustaría ponerle un mote a {1}?"
      return "Ultra Burst Method\n" if source.to_s == "Método Ultraexplosión\n"
      return "{1} learned {2}!" if source.to_s == "¡{1} aprendió {2}!"
      return "{1} sent out {2}!" if source.to_s == "¡{1} sacó a {2}!"
    end
    if kind.nil? || kind.to_s.empty?
      quick = fast_contextual_text(source)
      return quick if quick.is_a?(String)
      return source.to_s if quick.nil?
      # Only conflicting translations need call-site context.
      kind = caller_kind(3)
    end
    order = case kind.to_s
            when "events"  then ["events", "general"]
            when "plugins" then ["plugins", "scripts", "general"]
            when "bss"     then ["bss", "plugins", "scripts", "general"]
            when "sds"     then ["sds", "plugins", "scripts", "general"]
            when "scripts" then ["scripts", "plugins", "general"]
            else ["bss", "sds", "scripts", "plugins", "general", "events"]
            end
    order.each do |bucket|
      txt = lookup_text(bucket, source)
      txt = lookup_template_text(bucket, source) if !txt && bucket == "bss"
      return txt if txt
    end
    source.to_s
  rescue StandardError
    source.to_s
  end

  def self.event_text(source, _map_id = nil)
    contextual_text(source, "events")
  end

  def self.caller_kind(depth = 2)
    locs = caller_locations(depth, 8) rescue []
    locs.each do |loc|
      path = loc.path.to_s
      next if path.empty?
      next if path.include?("TranslateStudio") || path.include?("Translate Studio")
      clean = path.tr("\\", "/").downcase
      return "bss" if clean =~ /battle[ _-]*scene[ _-]*studio/
      return "sds" if clean =~ /scene[ _-]*director|scene[ _-]*engine/
      return "plugins" if clean.include?("/plugins/") || clean.start_with?("plugins/") || clean.include?("plugin:") || clean.include?("pluginscript")
      return "events" if clean.include?("mapevent") || clean.include?("commonevent")
      return "scripts"
    end
    "scripts"
  rescue StandardError
    "scripts"
  end

  #-----------------------------------------------------------------------------
  # BSS / SDS bridge
  #-----------------------------------------------------------------------------
  # These systems store part of their authored dialogue outside _INTL. Keep
  # technical IDs untouched and localize only fields that are meant to be read
  # by a player (messages, captions, dialogue, speakers, etc.).
  EXTERNAL_TEXT_KEYS = [
    "text", "speaker", "title", "subtitle", "caption", "label", "prompt",
    "description", "dialogue", "speech"
  ]

  def self.external_text_key?(key, system = nil)
    k = key.to_s
    low = k.downcase
    sys = system.to_s.upcase
    # BSS has a few *Text fields that are serialized configuration, not player copy.
    # ebdxMapBackdropsText is the known offender; more generally BSS only accepts
    # bare text or clearly player-facing suffixes instead of every arbitrary *Text.
    return false if sys == "BSS" && ["ebdxmapbackdropstext"].include?(low)
    # BSS custom presentation names are authored player-facing text too.
    # In particular boss.hud.displayName is where labels such as
    # "Dragonite el Indomable" live, and it must be independently localizable.
    return true if sys == "BSS" && [
      "displayname", "bossdisplayname", "battlerdisplayname",
      "nametitle", "displaytitle", "databoxtitle"
    ].include?(low)
    return true if EXTERNAL_TEXT_KEYS.include?(low)
    return true if low.end_with?("message") ||
                   low.end_with?("title") || low.end_with?("subtitle") ||
                   low.end_with?("caption") || low.end_with?("prompt") ||
                   low.end_with?("dialogue") || low.end_with?("speech")
    return true if ["choices", "options", "responses"].include?(low)
    return true if sys != "BSS" && low.end_with?("text")
    false
  rescue StandardError
    false
  end

  def self.external_text(system, source)
    return source if source.nil?
    contextual_text(source.to_s, system.to_s.downcase == "bss" ? "bss" : (system.to_s.downcase == "sds" ? "sds" : "plugins"))
  rescue StandardError
    source.to_s
  end

  def self.localize_external_value(value, system, parent_key = nil)
    case value
    when Hash
      out = {}
      value.each do |key, child|
        out[key] = localize_external_value(child, system, key)
      end
      out
    when Array
      value.map { |child| localize_external_value(child, system, parent_key) }
    when String
      external_text_key?(parent_key, system) ? external_text(system, value) : value
    else
      value
    end
  rescue StandardError
    value
  end

  def self.localize_external_document(value, system)
    return value if !enabled? || value.nil?
    @external_document_cache ||= {}
    key = [system.to_s.downcase, language_code, language_revision, value.object_id]
    cached = @external_document_cache[key]
    return cached if cached
    localized = localize_external_value(value, system)
    @external_document_cache[key] = localized
    # Keep the cache tiny even if a development session hot-reloads many JSONs.
    @external_document_cache.shift while @external_document_cache.length > 12
    localized
  rescue StandardError
    value
  end

  def self.install_bss_bridge!
    return false if !defined?(BSS064) || !BSS064.respond_to?(:data)
    singleton = class << BSS064; self; end
    @bss_bridge_module ||= Module.new do
      define_method(:data) do |*args, &block|
        raw = super(*args, &block)
        CarnekTranslateStudio.localize_external_document(raw, "bss")
      end
    end
    singleton.prepend(@bss_bridge_module) if !singleton.ancestors.include?(@bss_bridge_module)
    true
  rescue StandardError
    false
  end

  def self.install_sds_bridge!
    return false if !defined?(SceneEngine::Player)
    klass = SceneEngine::Player
    @sds_bridge_module ||= Module.new do
      define_method(:show_page_text) do |text, speaker = nil, *args, &block|
        t = CarnekTranslateStudio.external_text("sds", text)
        sp = speaker.nil? ? nil : CarnekTranslateStudio.external_text("sds", speaker)
        super(t, sp, *args, &block)
      end
      define_method(:show_centered_text) do |text, *args, **kwargs, &block|
        t = CarnekTranslateStudio.external_text("sds", text)
        super(t, *args, **kwargs, &block)
      end
      define_method(:set_speaker) do |speaker, *args, &block|
        sp = speaker.nil? ? nil : CarnekTranslateStudio.external_text("sds", speaker)
        super(sp, *args, &block)
      end
    end
    klass.prepend(@sds_bridge_module) if !klass.ancestors.include?(@sds_bridge_module)
    true
  rescue StandardError
    false
  end

  def self.install_external_bridges!
    install_bss_bridge!
    install_sds_bridge!
    true
  rescue StandardError
    false
  end

  #-----------------------------------------------------------------------------
  # Structured GameData localization
  #-----------------------------------------------------------------------------
  def self.override_row(lang, bucket, id)
    key = id.to_s.upcase
    row = document.dig("languages", lang.to_s.downcase, bucket.to_s, key) rescue nil
    row.is_a?(Hash) ? row : {}
  rescue StandardError
    {}
  end

  def self.entity_text(bucket, id, field, fallback = "", base_id = nil)
    return fallback.to_s if !enabled?
    lang = language_code
    key = id.to_s.upcase
    row = override_row(lang, bucket, key)
    txt = row[field.to_s].to_s.strip
    if txt.empty? && base_id
      row = override_row(lang, bucket, base_id)
      txt = row[field.to_s].to_s.strip
    end
    if txt.empty? && lang == "en"
      base = canon_en.dig(bucket.to_s, key) rescue nil
      txt = base[field.to_s].to_s.strip if base.is_a?(Hash)
      if txt.empty? && base_id
        base = canon_en.dig(bucket.to_s, base_id.to_s.upcase) rescue nil
        txt = base[field.to_s].to_s.strip if base.is_a?(Hash)
      end
    end
    txt = general_text(fallback) if txt.empty?
    txt.empty? ? fallback.to_s : txt
  rescue StandardError
    fallback.to_s
  end

  def self.item_text(id, field, fallback = "")
    return fallback.to_s if !enabled?
    lang = language_code
    key = id.to_s.upcase
    row = override_row(lang, "items", key)
    txt = row[field.to_s].to_s.strip
    if txt.empty?
      canon = canon_items.dig(lang, key) rescue nil
      txt = canon[field.to_s].to_s.strip if canon.is_a?(Hash)
    end
    txt = general_text(fallback) if txt.empty?
    txt.empty? ? fallback.to_s : txt
  rescue StandardError
    fallback.to_s
  end

  TYPE_NAMES_EN = {
    :NORMAL=>"Normal", :FIRE=>"Fire", :WATER=>"Water", :ELECTRIC=>"Electric", :GRASS=>"Grass",
    :ICE=>"Ice", :FIGHTING=>"Fighting", :POISON=>"Poison", :GROUND=>"Ground", :FLYING=>"Flying",
    :PSYCHIC=>"Psychic", :BUG=>"Bug", :ROCK=>"Rock", :GHOST=>"Ghost", :DRAGON=>"Dragon",
    :DARK=>"Dark", :STEEL=>"Steel", :FAIRY=>"Fairy", :STELLAR=>"Stellar", :SHADOW=>"Shadow",
    :UNKNOWN=>"Unknown"
  }

  def self.type_text(id, fallback = "")
    return fallback.to_s if !enabled?
    key = id.to_s.upcase
    row = override_row(language_code, "types", key)
    txt = row["Name"].to_s.strip
    return txt if !txt.empty?
    return TYPE_NAMES_EN[key.to_sym] || general_text(fallback) if language_code == "en"
    general_text(fallback)
  rescue StandardError
    fallback.to_s
  end

  def self.reverse_registry_signature
    sigs = []
    sigs << (GameData::Species::DATA.object_id rescue 0) if defined?(GameData::Species)
    sigs << (GameData::Move::DATA.object_id rescue 0) if defined?(GameData::Move)
    sigs << (GameData::Ability::DATA.object_id rescue 0) if defined?(GameData::Ability)
    sigs << (GameData::Item::DATA.object_id rescue 0) if defined?(GameData::Item)
    sigs << (GameData::Type::DATA.object_id rescue 0) if defined?(GameData::Type)
    sigs
  rescue StandardError
    []
  end

  def self.build_reverse_index!
    signature = reverse_registry_signature
    return @reverse_index if @reverse_index && @reverse_signature == signature
    idx = Hash.new { |h, k| h[k] = {} }
    add = proc do |type, source, payload, overwrite = false|
      next if type.nil? || source.nil? || source.to_s.empty?
      key = source.to_s
      idx[type][key] = payload if overwrite || !idx[type].key?(key)
    end
    begin
      if defined?(MessageTypes) && defined?(GameData::Species)
        GameData::Species.each do |sp|
          next if !sp
          species = (sp.respond_to?(:species) ? sp.species : sp.id).to_s.upcase
          form = sp.respond_to?(:form) ? sp.form.to_i : 0
          key = form > 0 ? "#{species},#{form}" : species
          add.call(MessageTypes::SPECIES_NAMES, sp.real_name, ["species", key, "Name", species]) if defined?(MessageTypes::SPECIES_NAMES) && sp.respond_to?(:real_name)
          add.call(MessageTypes::SPECIES_FORM_NAMES, sp.real_form_name, ["species", key, "FormName", nil], true) if defined?(MessageTypes::SPECIES_FORM_NAMES) && sp.respond_to?(:real_form_name)
          add.call(MessageTypes::SPECIES_CATEGORIES, sp.real_category, ["species", key, "Category", species]) if defined?(MessageTypes::SPECIES_CATEGORIES) && sp.respond_to?(:real_category)
          add.call(MessageTypes::POKEDEX_ENTRIES, sp.real_pokedex_entry, ["species", key, "Pokedex", species]) if defined?(MessageTypes::POKEDEX_ENTRIES) && sp.respond_to?(:real_pokedex_entry)
        end
      end
      if defined?(MessageTypes) && defined?(GameData::Move)
        GameData::Move.each do |m|
          next if !m
          add.call(MessageTypes::MOVE_NAMES, m.real_name, ["moves", m.id.to_s.upcase, "Name", nil]) if defined?(MessageTypes::MOVE_NAMES) && m.respond_to?(:real_name)
          add.call(MessageTypes::MOVE_DESCRIPTIONS, m.real_description, ["moves", m.id.to_s.upcase, "Description", nil]) if defined?(MessageTypes::MOVE_DESCRIPTIONS) && m.respond_to?(:real_description)
        end
      end
      if defined?(MessageTypes) && defined?(GameData::Ability)
        GameData::Ability.each do |a|
          next if !a
          add.call(MessageTypes::ABILITY_NAMES, a.real_name, ["abilities", a.id.to_s.upcase, "Name", nil]) if defined?(MessageTypes::ABILITY_NAMES) && a.respond_to?(:real_name)
          add.call(MessageTypes::ABILITY_DESCRIPTIONS, a.real_description, ["abilities", a.id.to_s.upcase, "Description", nil]) if defined?(MessageTypes::ABILITY_DESCRIPTIONS) && a.respond_to?(:real_description)
        end
      end
      if defined?(MessageTypes) && defined?(GameData::Item)
        GameData::Item.each do |it|
          next if !it
          id = it.id.to_s.upcase
          add.call(MessageTypes::ITEM_NAMES, it.real_name, ["items", id, "Name", nil]) if defined?(MessageTypes::ITEM_NAMES) && it.respond_to?(:real_name)
          add.call(MessageTypes::ITEM_NAME_PLURALS, it.real_name_plural, ["items", id, "NamePlural", nil]) if defined?(MessageTypes::ITEM_NAME_PLURALS) && it.respond_to?(:real_name_plural)
          add.call(MessageTypes::ITEM_DESCRIPTIONS, it.real_description, ["items", id, "Description", nil]) if defined?(MessageTypes::ITEM_DESCRIPTIONS) && it.respond_to?(:real_description)
        end
      end
      if defined?(MessageTypes) && defined?(GameData::Type)
        GameData::Type.each do |t|
          next if !t
          add.call(MessageTypes::TYPE_NAMES, t.real_name, ["types", t.id.to_s.upcase, "Name", nil]) if defined?(MessageTypes::TYPE_NAMES) && t.respond_to?(:real_name)
        end
      end
    rescue StandardError
    end
    @reverse_index = idx
    @reverse_signature = signature
    idx
  end

  # ZBox PBS reference imported by Translate Studio v1.0.0.  Unlike the old
  # translator, this never imports Map/CommonEvent text.  PBS categories remain
  # scoped by MessageTypes so a trainer/ribbon/phone label cannot contaminate an
  # unrelated event that happens to use the same Spanish literal.
  ZBOX_PBS_MESSAGE_TYPES = {
    "Item Name"         => :ITEM_NAMES,
    "Item Plural"       => :ITEM_NAME_PLURALS,
    "Item Desc"         => :ITEM_DESCRIPTIONS,
    "Species Name"      => :SPECIES_NAMES,
    "Species Form"      => :SPECIES_FORM_NAMES,
    "Species Category"  => :SPECIES_CATEGORIES,
    "Dex Entry"         => :POKEDEX_ENTRIES,
    "Move Name"         => :MOVE_NAMES,
    "Move Desc"         => :MOVE_DESCRIPTIONS,
    "Ability Name"      => :ABILITY_NAMES,
    "Ability Desc"      => :ABILITY_DESCRIPTIONS,
    "Type"              => :TYPE_NAMES,
    "Map Name"          => :MAP_NAMES,
    "Trainer Name"      => :TRAINER_NAMES,
    "TrainerType"       => :TRAINER_TYPE_NAMES,
    "Region"            => :REGION_NAMES,
    "Ribbon"            => :RIBBON_NAMES,
    "Ribbon Desc"       => :RIBBON_DESCRIPTIONS,
    "Phone"             => :PHONE_MESSAGES,
    "Storage Creator"   => :STORAGE_CREATOR_NAME,
    "Trainer Pkmn Nick" => :POKEMON_NICKNAMES,
    "Trainer Lose"      => :TRAINER_SPEECHES_LOSE,
    "Trainer Lose(F)"   => :TRAINER_SPEECHES_LOSE_F
  }

  def self.zbox_sanitize_key(text)
    s = text.to_s.dup
    s.gsub!("\\n", "\n")
    s.gsub!("\\r", "\n")
    s.gsub!(/\r\n|\r|\n/, " ")
    s.gsub!(/ +/, " ")
    s.strip
  rescue StandardError
    text.to_s.strip
  end

  def self.build_pbs_index!(lang, category)
    @pbs_indexes ||= {}
    lang = lang.to_s.downcase
    category = category.to_s
    @pbs_indexes[lang] ||= {}
    return @pbs_indexes[lang][category] if @pbs_indexes[lang].key?(category)
    rows = document.dig("languages", lang, "pbs", category) rescue nil
    exact = {}
    normalized = {}
    if rows.is_a?(Hash)
      rows.each do |source, value|
        txt = text_value(value)
        next if txt.to_s.empty?
        exact[source.to_s] = txt.to_s
        key = zbox_sanitize_key(source)
        normalized[key] = txt.to_s if !key.empty? && !normalized.key?(key)
      end
    end
    @pbs_indexes[lang][category] = { :exact => exact, :normalized => normalized }
  rescue StandardError
    { :exact => {}, :normalized => {} }
  end

  def self.lookup_pbs_text(category, source, lang = language_code)
    idx = build_pbs_index!(lang, category)
    raw = source.to_s
    txt = idx[:exact][raw]
    txt = idx[:normalized][zbox_sanitize_key(raw)] if txt.nil? || txt.to_s.empty?
    txt = txt.to_s
    txt.empty? ? nil : txt
  rescue StandardError
    nil
  end

  def self.zbox_pbs_message_text(type, source, resolved = source)
    return nil if !enabled? || !defined?(MessageTypes)
    ZBOX_PBS_MESSAGE_TYPES.each do |category, const_name|
      next if !MessageTypes.const_defined?(const_name)
      next if MessageTypes.const_get(const_name) != type
      txt = lookup_pbs_text(category, source)
      txt ||= lookup_pbs_text(category, resolved)
      return txt if txt && !txt.empty?
      return nil
    end
    nil
  rescue StandardError
    nil
  end

  def self.message_text(type, source, resolved)
    return resolved.to_s if !enabled?
    info = build_reverse_index!.dig(type, source.to_s) rescue nil
    info ||= build_reverse_index!.dig(type, resolved.to_s) rescue nil
    if info
      bucket, key, field, base_key = info
      return item_text(key, field, resolved) if bucket == "items"
      return type_text(key, resolved) if bucket == "types"
      return entity_text(bucket, key, field, resolved, base_key)
    end
    scoped = zbox_pbs_message_text(type, source, resolved)
    return scoped if scoped && !scoped.empty?
    translated = general_text(source)
    return translated if translated != source.to_s
    general_text(resolved)
  rescue StandardError
    resolved.to_s
  end

  #-----------------------------------------------------------------------------
  # Runtime hooks
  #-----------------------------------------------------------------------------
  def self.install_method_patch(klass, method_name, &resolver)
    return if !klass || !klass.instance_methods.include?(method_name)
    key = [klass.name.to_s, method_name.to_sym]
    return if @installed_methods[key]
    mod = Module.new do
      define_method(method_name) do |*args, &block|
        raw = super(*args, &block)
        begin
          resolver.call(self, raw)
        rescue StandardError
          raw
        end
      end
    end
    klass.prepend(mod)
    @installed_methods[key] = true
  rescue StandardError
  end

  def self.install_message_patch!
    return if !defined?(MessageTypes)
    singleton = class << MessageTypes; self; end
    if MessageTypes.respond_to?(:getFromHash) && !singleton.method_defined?(:carnek_translate_original_getFromHash)
      singleton.class_eval do
        alias_method :carnek_translate_original_getFromHash, :getFromHash
        define_method(:getFromHash) do |type, text|
          resolved = carnek_translate_original_getFromHash(type, text)
          CarnekTranslateStudio.message_text(type, text, resolved)
        end
      end
    end
    if MessageTypes.respond_to?(:get) && !singleton.method_defined?(:carnek_translate_original_get)
      singleton.class_eval do
        alias_method :carnek_translate_original_get, :get
        define_method(:get) do |type, id|
          resolved = carnek_translate_original_get(type, id)
          CarnekTranslateStudio.message_text(type, resolved, resolved)
        end
      end
    end
    if MessageTypes.respond_to?(:getFromMapHash) && !singleton.method_defined?(:carnek_translate_original_getFromMapHash)
      singleton.class_eval do
        alias_method :carnek_translate_original_getFromMapHash, :getFromMapHash
        define_method(:getFromMapHash) do |map_id, text|
          resolved = carnek_translate_original_getFromMapHash(map_id, text)
          translated = CarnekTranslateStudio.event_text(text.to_s, map_id)
          translated != text.to_s ? translated : CarnekTranslateStudio.event_text(resolved, map_id)
        end
      end
    end
  rescue StandardError
  end

  # Localize raw battle command arrays as well as the prompt. BSS and several
  # battle plugins pass choices such as ["Capturar", "No capturar"] directly
  # instead of wrapping each item in _INTL.
  # Some BSS compatibility/fallback routes call pbDisplay with a raw Spanish
  # string after placeholders have already been substituted. Translate those
  # display calls too, without changing battle logic or IDs.
  def self.install_battle_display_patch!
    return if !defined?(Battle)
    marker = :carnek_translate_v110_battle_display
    return if Battle.instance_methods.include?(marker)
    mod = Module.new do
      define_method(:pbDisplay) do |msg, *args, &block|
        super(CarnekTranslateStudio.contextual_text(msg.to_s, "bss"), *args, &block)
      end
      define_method(:pbDisplayPaused) do |msg, *args, &block|
        super(CarnekTranslateStudio.contextual_text(msg.to_s, "bss"), *args, &block)
      end
      define_method(marker) { true }
    end
    Battle.prepend(mod)
  rescue StandardError
  end

  def self.install_battle_command_patch!
    return if !defined?(Battle::Scene)
    marker = :carnek_translate_v110_battle_commands
    return if Battle::Scene.instance_methods.include?(marker)
    mod = Module.new do
      define_method(:pbShowCommands) do |msg, commands, *args, &block|
        translated_msg = CarnekTranslateStudio.contextual_text(msg.to_s)
        translated_commands = Array(commands).map { |cmd| CarnekTranslateStudio.contextual_text(cmd.to_s) }
        super(translated_msg, translated_commands, *args, &block)
      end
      define_method(marker) { true }
    end
    Battle::Scene.prepend(mod)
  rescue StandardError
  end

  def self.install!
    if defined?(GameData::Species)
      install_method_patch(GameData::Species, :name) do |obj, raw|
        sp = (obj.respond_to?(:species) ? obj.species : obj.id).to_s.upcase
        form = obj.respond_to?(:form) ? obj.form.to_i : 0
        key = form > 0 ? "#{sp},#{form}" : sp
        entity_text("species", key, "Name", raw, sp)
      end
      install_method_patch(GameData::Species, :form_name) do |obj, raw|
        sp = (obj.respond_to?(:species) ? obj.species : obj.id).to_s.upcase
        form = obj.respond_to?(:form) ? obj.form.to_i : 0
        key = form > 0 ? "#{sp},#{form}" : sp
        entity_text("species", key, "FormName", raw)
      end
      install_method_patch(GameData::Species, :category) do |obj, raw|
        sp = (obj.respond_to?(:species) ? obj.species : obj.id).to_s.upcase
        form = obj.respond_to?(:form) ? obj.form.to_i : 0
        key = form > 0 ? "#{sp},#{form}" : sp
        entity_text("species", key, "Category", raw, sp)
      end if GameData::Species.instance_methods.include?(:category)
      install_method_patch(GameData::Species, :pokedex_entry) do |obj, raw|
        sp = (obj.respond_to?(:species) ? obj.species : obj.id).to_s.upcase
        form = obj.respond_to?(:form) ? obj.form.to_i : 0
        key = form > 0 ? "#{sp},#{form}" : sp
        entity_text("species", key, "Pokedex", raw, sp)
      end if GameData::Species.instance_methods.include?(:pokedex_entry)
    end
    if defined?(GameData::Move)
      install_method_patch(GameData::Move, :name) { |obj, raw| entity_text("moves", obj.id, "Name", raw) }
      install_method_patch(GameData::Move, :description) { |obj, raw| entity_text("moves", obj.id, "Description", raw) }
    end
    if defined?(GameData::Ability)
      install_method_patch(GameData::Ability, :name) { |obj, raw| entity_text("abilities", obj.id, "Name", raw) }
      install_method_patch(GameData::Ability, :description) { |obj, raw| entity_text("abilities", obj.id, "Description", raw) }
    end
    if defined?(GameData::Item)
      install_method_patch(GameData::Item, :name) { |obj, raw| item_text(obj.id, "Name", raw) }
      install_method_patch(GameData::Item, :name_plural) { |obj, raw| item_text(obj.id, "NamePlural", raw) }
      install_method_patch(GameData::Item, :description) { |obj, raw| item_text(obj.id, "Description", raw) }
    end
    if defined?(GameData::Type)
      install_method_patch(GameData::Type, :name) { |obj, raw| type_text(obj.id, raw) }
    end
    install_message_patch!
    install_debug_lister_patches!
    install_debug_menu_patch!
    install_debug_menu_render_patch!
    install_debug_choose_list_patch!
    install_external_bridges!
    install_battle_display_patch!
    install_battle_command_patch!
    true
  end

  #-----------------------------------------------------------------------------
  # Debug listers: force names/descriptions through GameData after language change
  #-----------------------------------------------------------------------------
  def self.debug_rows(kind)
    rows = []
    push = proc do |obj, name|
      next if !obj
      number = obj.respond_to?(:id_number) ? obj.id_number : nil
      id = obj.respond_to?(:id) ? obj.id : nil
      next if id.nil?
      rows << [id, name.to_s, number]
    end
    case kind
    when :moves
      GameData::Move.each { |obj| push.call(obj, obj.name) } if defined?(GameData::Move)
    when :items
      GameData::Item.each { |obj| push.call(obj, obj.name) } if defined?(GameData::Item)
    when :abilities
      GameData::Ability.each { |obj| push.call(obj, obj.name) } if defined?(GameData::Ability)
    when :types
      GameData::Type.each { |obj| push.call(obj, obj.name) } if defined?(GameData::Type)
    when :trainertypes
      GameData::TrainerType.each { |obj| push.call(obj, (obj.name rescue obj.real_name)) } if defined?(GameData::TrainerType)
    when :species
      if defined?(GameData::Species)
        if GameData::Species.respond_to?(:each_species)
          GameData::Species.each_species { |obj| push.call(obj, obj.name) }
        else
          GameData::Species.each { |obj| push.call(obj, obj.name) if !obj.respond_to?(:form) || obj.form.to_i == 0 }
        end
      end
    end
    rows.sort_by { |row| row[1].to_s.downcase }
  rescue StandardError
    []
  end

  def self.refresh_debug_lister!(lister, kind, force = false)
    return if !lister
    return if lister.instance_variable_get(:@commands_override)
    rev = language_revision
    return if !force && lister.instance_variable_get(:@carnek_translate_revision) == rev
    rows = debug_rows(kind)
    return if rows.empty?
    commands = []
    ids = []
    include_new = lister.instance_variable_get(:@includeNew) rescue false
    if include_new
      commands << (language_code == "en" ? "[NEW]" : contextual_text("[NUEVO]", "scripts"))
      ids << true
    end
    rows.each_with_index do |row, i|
      number = row[2].nil? ? (i + 1) : row[2].to_i
      commands << sprintf("%03d: %s", number, row[1].to_s)
      ids << row[0]
    end
    lister.instance_variable_set(:@commands, commands)
    lister.instance_variable_set(:@ids, ids)
    selection = lister.instance_variable_get(:@selection).to_i rescue 0
    selection = commands.length - 1 if selection >= commands.length && !commands.empty?
    selection = 0 if selection < 0
    lister.instance_variable_set(:@index, selection) rescue nil
    lister.instance_variable_set(:@carnek_translate_revision, rev)
    true
  rescue StandardError
    false
  end

  def self.install_debug_lister_patches!
    # Classes may become available at different moments during boot. Iterate on
    # every install! call; per-class markers prevent duplicate prepends.
    mapping = {
      "MoveLister" => :moves,
      "ItemLister" => :items,
      "AbilityLister" => :abilities,
      "SpeciesLister" => :species,
      "TypeLister" => :types,
      "TrainerTypeLister" => :trainertypes
    }
    patched_any = false
    mapping.each do |name, kind|
      next if !Object.const_defined?(name)
      klass = Object.const_get(name)
      next if !klass || !klass.instance_methods.include?(:commands)
      marker = "carnek_translate_v070_#{name}_commands".to_sym
      next if klass.instance_methods.include?(marker)
      kind_for_patch = kind
      marker_for_patch = marker
      mod = Module.new do
        define_method(:commands) do |*args, &block|
          result = super(*args, &block)
          CarnekTranslateStudio.refresh_debug_lister!(self, kind_for_patch, true)
          translated = instance_variable_get(:@commands) rescue nil
          translated || result
        end
        define_method(marker_for_patch) { true }
      end
      klass.prepend(mod)
      patched_any = true
    end
    @debug_lister_patches_installed = true if patched_any
  rescue StandardError
  end

  # Debug menus are registered before the player chooses a language in this
  # Spanish project. Translate at render time so changing language also changes
  # Debug without restarting or recompiling.
  def self.install_debug_menu_patch!
    return if !defined?(CommandMenuList)
    return if CommandMenuList.ancestors.any? { |a| a.to_s == "CarnekTranslateDebugMenuPatchV070" }
    mod = Module.new do
      define_method(:add) do |option, hash, name = nil, description = nil|
        if CarnekTranslateStudio.language_code == "en"
          raw_name = name.nil? ? hash["name"] : name
          begin
            raw_name = raw_name.call if raw_name.is_a?(Proc)
          rescue StandardError
          end
          raw_desc = description.nil? ? hash["description"] : description
          begin
            raw_desc = raw_desc.call if raw_desc.is_a?(Proc)
          rescue StandardError
          end
          english_name = CarnekTranslateStudio.debug_option_name(option, raw_name)
          english_desc = CarnekTranslateStudio.debug_option_description(option, raw_desc, english_name)
          super(option, hash, english_name, english_desc)
        else
          super(option, hash, name, description)
        end
      end
    end
    Object.const_set(:CarnekTranslateDebugMenuPatchV070, mod) if !Object.const_defined?(:CarnekTranslateDebugMenuPatchV070)
    CommandMenuList.prepend(mod)
    true
  rescue StandardError
    false
  end

  #-----------------------------------------------------------------------------
  # Debug render-time localization. Essentials v21 deliberately uses real_name
  # in several editor/debug selectors; these wrappers make Debug follow the
  # active language without modifying PBS data or recompiling anything.
  #-----------------------------------------------------------------------------
  def self.debug_data_name(data)
    return "" if !data
    return data.name.to_s if data.respond_to?(:name)
    data.respond_to?(:real_name) ? data.real_name.to_s : data.to_s
  rescue StandardError
    ""
  end

  def self.install_debug_choose_list_patch!
    marker_name = :CarnekTranslateDebugChooseListPatchV070
    return if Object.const_defined?(marker_name) && Object.ancestors.include?(Object.const_get(marker_name))
    mod = Module.new do
      # Essentials v21 uses real_name here on purpose. For a bilingual project,
      # Debug must instead resolve the display name at the moment the list opens.
      define_method(:pbChooseFromGameDataList) do |game_data, default = nil, &chooser|
        if !GameData.const_defined?(game_data.to_sym)
          raise _INTL("No se encuentra la clase {1} en el módulo GameData.", game_data.to_s)
        end
        game_data_module = GameData.const_get(game_data.to_sym)
        commands = []
        game_data_module.each do |data|
          next if !data
          name = chooser ? chooser.call(data) : CarnekTranslateStudio.debug_data_name(data)
          next if !name
          begin
            # Species/Type helpers in Essentials pass real_name from their block.
            # Swap that exact value for the live localized GameData#name.
            if data.respond_to?(:real_name) && name.to_s == data.real_name.to_s
              name = CarnekTranslateStudio.debug_data_name(data)
            elsif CarnekTranslateStudio.language_code == "en"
              name = CarnekTranslateStudio.contextual_text(name.to_s, "scripts")
            end
          rescue StandardError
          end
          commands << [commands.length + 1, name.to_s, data.id]
        end
        pbChooseList(commands, default, nil, -1)
      end

      define_method(:pbChooseMoveList) do |default = nil|
        pbChooseFromGameDataList(:Move, default)
      end if defined?(GameData::Move)
      define_method(:pbChooseItemList) do |default = nil|
        pbChooseFromGameDataList(:Item, default)
      end if defined?(GameData::Item)
      define_method(:pbChooseAbilityList) do |default = nil|
        pbChooseFromGameDataList(:Ability, default)
      end if defined?(GameData::Ability)
      define_method(:pbChooseTypeList) do |default = nil|
        pbChooseFromGameDataList(:Type, default) do |data|
          next nil if data.respond_to?(:pseudo_type) && data.pseudo_type
          CarnekTranslateStudio.debug_data_name(data)
        end
      end if defined?(GameData::Type)
      define_method(:pbChooseSpeciesList) do |default = nil|
        pbChooseFromGameDataList(:Species, default) do |data|
          next nil if data.respond_to?(:form) && data.form.to_i > 0
          CarnekTranslateStudio.debug_data_name(data)
        end
      end if defined?(GameData::Species)
      define_method(:pbChooseSpeciesFormList) do |default = nil|
        pbChooseFromGameDataList(:Species, default) do |data|
          name = CarnekTranslateStudio.debug_data_name(data)
          (data.respond_to?(:form) && data.form.to_i > 0) ? sprintf("%s_%d", name, data.form.to_i) : name
        end
      end if defined?(GameData::Species)
    end
    Object.const_set(marker_name, mod) if !Object.const_defined?(marker_name)
    Object.prepend(mod) if !Object.ancestors.include?(mod)
    true
  rescue StandardError
    false
  end

  def self.install_debug_menu_render_patch!
    return if !defined?(CommandMenuList)
    return if CommandMenuList.ancestors.any? { |a| a.to_s == "CarnekTranslateDebugMenuRenderPatchV070" }
    mod = Module.new do
      define_method(:list) do
        rows = super()
        next rows if CarnekTranslateStudio.language_code != "en"
        rows.map { |txt| CarnekTranslateStudio.contextual_text(txt.to_s, "scripts") }
      end
      define_method(:getDesc) do |index|
        txt = super(index)
        CarnekTranslateStudio.language_code == "en" ? CarnekTranslateStudio.contextual_text(txt.to_s, "scripts") : txt
      end
    end
    Object.const_set(:CarnekTranslateDebugMenuRenderPatchV070, mod) if !Object.const_defined?(:CarnekTranslateDebugMenuRenderPatchV070)
    CommandMenuList.prepend(mod)
    true
  rescue StandardError
    false
  end

  #-----------------------------------------------------------------------------
  # Localized graphics: foo_ENG.png / foo_ESP.png (plus legacy aliases)
  #-----------------------------------------------------------------------------
  def self.graphic_suffixes(code = language_code)
    LANGUAGE_INFO.dig(code.to_s.downcase, "graphicSuffixes") || []
  end

  def self.strip_graphic_language_suffix(path_without_ext)
    suffixes = LANGUAGE_INFO.values.map { |row| row["graphicSuffixes"] }.flatten.uniq
    suffixes.sort_by { |s| -s.length }.each do |suffix|
      if path_without_ext.downcase.end_with?(suffix.downcase)
        return path_without_ext[0, path_without_ext.length - suffix.length]
      end
    end
    path_without_ext
  end

  def self.graphic_exists?(path)
    return true if FileTest.exist?(path)
    return false if File.extname(path).to_s != ""
    [".png", ".jpg", ".jpeg", ".bmp", ".webp"].any? { |ext| FileTest.exist?(path + ext) }
  rescue StandardError
    false
  end

  def self.graphic_rule_key(base)
    base.to_s.tr("\\", "/").downcase
  end

  def self.graphic_variant_enabled?(neutral_base, code)
    rules = config["graphicRules"]
    return true if !rules.is_a?(Hash)
    group = rules[graphic_rule_key(neutral_base)]
    return true if !group.is_a?(Hash)
    row = group[code.to_s.downcase]
    return true if !row.is_a?(Hash)
    row["enabled"] != false
  rescue StandardError
    true
  end

  def self.resolve_translated_graphic(filename)
    return filename if filename.nil? || filename.to_s.empty?
    return filename if config["preferLocalizedGraphics"] == false
    name = filename.to_s
    code = language_code
    ext = File.extname(name)
    base = ext.empty? ? name : name[0, name.length - ext.length]
    neutral_base = strip_graphic_language_suffix(base)
    enabled = graphic_variant_enabled?(neutral_base, code)
    cache_key = "#{code}|#{enabled ? 1 : 0}|#{name}"
    return @graphic_cache[cache_key] if @graphic_cache.key?(cache_key)
    candidates = []
    graphic_suffixes(code).each { |suffix| candidates << "#{neutral_base}#{suffix}#{ext}" } if enabled
    candidates << "#{neutral_base}#{ext}"
    candidates << name if enabled || neutral_base == base
    chosen = candidates.find { |path| graphic_exists?(path) } || name
    @graphic_cache[cache_key] = chosen
    chosen
  rescue StandardError
    filename
  end

  #-----------------------------------------------------------------------------
  # Player-facing language selection UI with gamefeel
  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  # Player-facing language selection UI.
  # It is always a real visual scene: cancelling never falls back to pbShowCommands.
  #-----------------------------------------------------------------------------
  class LanguageScene
    def initialize(initial_code = "es", allow_cancel = false)
      @index = initial_code.to_s.downcase == "en" ? 1 : 0
      @allow_cancel = allow_cancel
      @codes = ["es", "en"]
      @viewport = nil
      @bg_sprite = nil
      @sprite = nil
      @frame = 0
      @entry = 0.0
      @selection_anim = 1.0
      @confirm = 0.0
      @custom_bitmaps = {}
    end

    def run
      create
      loop do
        Graphics.update
        Input.update
        @frame += 1
        @entry = [@entry + 0.075, 1.0].min
        @selection_anim = [@selection_anim + 0.18, 1.0].min
        changed = false
        if Input.trigger?(Input::UP) || Input.trigger?(Input::LEFT)
          @index = (@index - 1) % @codes.length
          changed = true
        elsif Input.trigger?(Input::DOWN) || Input.trigger?(Input::RIGHT)
          @index = (@index + 1) % @codes.length
          changed = true
        end
        if changed
          @selection_anim = 0.0
          pbPlayCursorSE rescue nil
        end
        refresh if @frame.even? || changed || @entry < 1.0
        if Input.trigger?(Input::USE)
          pbPlayDecisionSE rescue nil
          code = @codes[@index]
          8.times do
            Graphics.update
            @frame += 1
            @confirm += 0.125
            refresh
          end
          dispose
          return code
        end
        if @allow_cancel && Input.trigger?(Input::BACK)
          pbPlayCancelSE rescue nil
          dispose
          return nil
        end
      end
    rescue StandardError
      dispose
      nil
    end

    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 999_999

      # Dedicated opaque background sprite. This prevents the previous scene from
      # showing through even on mkxp-z builds that blend semi-transparent fills.
      @bg_sprite = Sprite.new(@viewport)
      @bg_sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      draw_background(@bg_sprite.bitmap)

      @sprite = Sprite.new(@viewport)
      @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      pbSetSystemFont(@sprite.bitmap) if defined?(pbSetSystemFont)
      load_custom_graphics if ["graphics", "code"].include?(CarnekTranslateStudio.config["languageMenuMode"].to_s)
      refresh
    end

    def dispose
      @custom_bitmaps.each_value do |bmp|
        bmp.dispose if bmp && bmp.respond_to?(:disposed?) && !bmp.disposed?
      end
      @custom_bitmaps.clear
      if @sprite
        @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
        @sprite.dispose if !@sprite.disposed?
      end
      if @bg_sprite
        @bg_sprite.bitmap.dispose if @bg_sprite.bitmap && !@bg_sprite.bitmap.disposed?
        @bg_sprite.dispose if !@bg_sprite.disposed?
      end
      @viewport.dispose if @viewport && !@viewport.disposed?
      @sprite = nil
      @bg_sprite = nil
      @viewport = nil
    rescue StandardError
    end

    # Language-menu art must be resolved EXACTLY. The normal pbResolveBitmap
    # hook intentionally swaps *_ES/*_EN variants to the active language, which
    # is correct for normal game UI but wrong here because this scene must show
    # both language cards at the same time.
    def resolve_bitmap(path)
      return nil if path.nil? || path.to_s.empty?
      raw = path.to_s.tr("\\", "/")
      candidates = [raw]
      if File.extname(raw).to_s.empty?
        [".png", ".jpg", ".jpeg", ".bmp", ".webp"].each { |ext| candidates << raw + ext }
      end
      exact = candidates.find { |candidate| File.file?(candidate) }
      return Bitmap.new(exact) if exact
      # RTP/engine fallback, still bypassing Translate Studio's localized wrapper.
      resolved = carnek_translate_original_pbResolveBitmap(raw) rescue nil
      return nil if !resolved || !File.file?(resolved)
      Bitmap.new(resolved)
    rescue StandardError
      nil
    end

    def load_custom_graphics
      cfg = CarnekTranslateStudio.config
      {
        :background => cfg["languageMenuBackground"],
        :header     => cfg["languageMenuHeader"],
        :footer     => cfg["languageMenuFooter"],
        :es         => cfg["languageMenuCardES"],
        :en         => cfg["languageMenuCardEN"],
        :cursor     => cfg["languageMenuCursor"]
      }.each do |key, path|
        bmp = resolve_bitmap(path)
        @custom_bitmaps[key] = bmp if bmp
      end
      if @custom_bitmaps[:background] && @bg_sprite && @bg_sprite.bitmap
        src = @custom_bitmaps[:background]
        @bg_sprite.bitmap.clear
        @bg_sprite.bitmap.stretch_blt(
          Rect.new(0, 0, Graphics.width, Graphics.height),
          src,
          Rect.new(0, 0, src.width, src.height)
        )
      end
    rescue StandardError
    end

    def ease_out(t)
      t = [[t.to_f, 0.0].max, 1.0].min
      1.0 - ((1.0 - t) ** 3)
    end

    def rect_border(bmp, x, y, w, h, color, thickness = 2)
      bmp.fill_rect(x, y, w, thickness, color)
      bmp.fill_rect(x, y + h - thickness, w, thickness, color)
      bmp.fill_rect(x, y, thickness, h, color)
      bmp.fill_rect(x + w - thickness, y, thickness, h, color)
    end

    def draw_background(bmp)
      w = Graphics.width
      h = Graphics.height
      # Fully opaque layered background, intentionally without transparent stripes.
      bmp.fill_rect(0, 0, w, h, Color.new(24, 31, 47, 255))
      top_h = [96, (h * 0.24).to_i].min
      bmp.fill_rect(0, 0, w, top_h, Color.new(39, 49, 70, 255))
      bmp.fill_rect(0, top_h, w, h - top_h, Color.new(28, 36, 54, 255))
      bmp.fill_rect(0, top_h - 5, w, 5, Color.new(246, 156, 45, 255))
      bmp.fill_rect(0, top_h, w, 2, Color.new(255, 207, 101, 255))
      # Clean, fully opaque lower area. No animated blocks/squares that can pop.
      bmp.fill_rect(0, h - 3, w, 3, Color.new(49, 61, 84, 255))
      bmp.fill_rect(18, top_h + 18, 4, h - top_h - 42, Color.new(44, 56, 78, 255))
      bmp.fill_rect(w - 22, top_h + 18, 4, h - top_h - 42, Color.new(44, 56, 78, 255))
    end

    def draw_flag_es(bmp, x, y, w, h)
      red = Color.new(191, 42, 51)
      yellow = Color.new(247, 193, 48)
      bmp.fill_rect(x, y, w, h / 4, red)
      bmp.fill_rect(x, y + h / 4, w, h / 2, yellow)
      bmp.fill_rect(x, y + (h * 3 / 4), w, h / 4, red)
      bmp.fill_rect(x + w / 3, y + h / 3, [w / 12, 2].max, h / 3, Color.new(172, 42, 42))
    end

    def draw_flag_en(bmp, x, y, w, h)
      blue = Color.new(47, 67, 116)
      white = Color.new(242, 244, 248)
      red = Color.new(192, 43, 54)
      bmp.fill_rect(x, y, w, h, blue)
      bmp.fill_rect(x, y + h / 2 - [h / 8, 2].max, w, [h / 4, 4].max, white)
      bmp.fill_rect(x + w / 2 - [w / 10, 2].max, y, [w / 5, 4].max, h, white)
      bmp.fill_rect(x, y + h / 2 - [h / 16, 1].max, w, [h / 8, 2].max, red)
      bmp.fill_rect(x + w / 2 - [w / 20, 1].max, y, [w / 10, 2].max, h, red)
    end

    def draw_pointer(bmp, x, cy, color)
      custom = @custom_bitmaps[:cursor]
      if custom
        y = cy - custom.height / 2
        bmp.blt(x, y, custom, Rect.new(0, 0, custom.width, custom.height))
        return
      end
      7.times do |i|
        width = i < 4 ? (i + 1) * 3 : (7 - i) * 3
        bmp.fill_rect(x, cy - 10 + i * 3, width, 3, color)
      end
    end

    def draw_card(bmp, code, index, x, y, w, h)
      selected = index == @index
      pulse = selected ? ((Math.sin(@frame / 5.0) + 1.0) * 0.5) : 0.0
      slide = selected ? ((1.0 - ease_out(@selection_anim)) * 18).to_i : 0
      expand = selected ? (2 + pulse.to_i) : 0
      x -= expand + slide
      y -= expand
      w += expand * 2
      h += expand * 2

      custom = @custom_bitmaps[code.to_sym]
      if custom
        bmp.stretch_blt(Rect.new(x, y, w, h), custom, Rect.new(0, 0, custom.width, custom.height))
        rect_border(bmp, x, y, w, h, selected ? Color.new(255, 189, 61) : Color.new(96, 105, 128), selected ? 3 : 1)
        draw_pointer(bmp, x - 24, y + h / 2, Color.new(255, 213, 83)) if selected
        return
      end

      shadow = Color.new(9, 12, 19, 220)
      panel = selected ? Color.new(248, 248, 244) : Color.new(215, 219, 227)
      border = selected ? Color.new(255, 164, 50) : Color.new(105, 115, 135)
      inner = selected ? Color.new(255, 218, 121) : Color.new(177, 183, 195)
      dark = Color.new(43, 48, 61)
      muted = Color.new(86, 93, 109)
      bmp.fill_rect(x + 5, y + 7, w, h, shadow)
      bmp.fill_rect(x, y, w, h, panel)
      rect_border(bmp, x, y, w, h, border, selected ? 3 : 2)
      rect_border(bmp, x + 4, y + 4, w - 8, h - 8, inner, 1)
      if selected
        bmp.fill_rect(x + 8, y + h - 9, w - 16, 5, Color.new(255, 187, 55))
        draw_pointer(bmp, x - 20, y + h / 2, Color.new(255, 213, 83))
      end
      flag_w = [64, (w * 0.15).to_i].min
      flag_h = [42, h - 22].min
      fx = x + 20
      fy = y + (h - flag_h) / 2
      code == "es" ? draw_flag_es(bmp, fx, fy, flag_w, flag_h) : draw_flag_en(bmp, fx, fy, flag_w, flag_h)
      rect_border(bmp, fx, fy, flag_w, flag_h, Color.new(69, 75, 89), 1)
      tx = fx + flag_w + 18
      bmp.font.color = dark
      bmp.font.size = [28, (h * 0.34).to_i].min
      bmp.font.bold = true
      bmp.draw_text(tx, y + 12, w - (tx - x) - 92, 38, code == "es" ? "Español" : "English")
      bmp.font.bold = false
      bmp.font.color = muted
      bmp.font.size = 18
      bmp.draw_text(tx, y + 52, w - (tx - x) - 30, 28, code == "es" ? "Jugar en español" : "Play in English")
      if selected
        bmp.font.color = Color.new(178, 88, 24)
        bmp.font.bold = true
        bmp.font.size = 16
        bmp.draw_text(x + w - 92, y + (h - 24) / 2, 70, 24, code == "es" ? "ESP" : "ENG", 2)
        bmp.font.bold = false
      end
    end

    def refresh
      return if !@sprite || !@sprite.bitmap
      draw_background(@bg_sprite.bitmap) if @bg_sprite && @bg_sprite.bitmap && !@custom_bitmaps[:background]
      bmp = @sprite.bitmap
      w = Graphics.width
      h = Graphics.height
      bmp.clear
      accent = Color.new(246, 156, 45)
      white = Color.new(246, 247, 250)
      muted = Color.new(186, 195, 210)
      header_h = [96, (h * 0.24).to_i].min

      if @custom_bitmaps[:header]
        head = @custom_bitmaps[:header]
        bmp.stretch_blt(Rect.new(0, 0, w, header_h), head, Rect.new(0, 0, head.width, head.height))
      else
        bmp.font.color = Color.new(255, 205, 92)
        bmp.font.bold = true
        bmp.font.size = 15
        bmp.draw_text(20, 8, w - 40, 24, "IDIOMA  /  LANGUAGE", 1)
        bmp.font.color = white
        bmp.font.size = [30, (w * 0.052).to_i].min
        bmp.draw_text(20, 31, w - 40, 38, "Elige un idioma / Choose a language", 1)
        bmp.font.bold = false
        bmp.font.size = 15
        bmp.font.color = muted
        bmp.draw_text(20, 67, w - 40, 24, "Puedes cambiarlo después en Opciones / Change it later in Options", 1)
      end

      card_w = [[w - 76, 540].min, 310].max
      card_h = [[(h - 176) / 2, 92].max, 112].min
      gap = 14
      total_h = card_h * 2 + gap
      target_y = header_h + [(h - header_h - 48 - total_h) / 2, 0].max
      entry_ease = ease_out(@entry)
      x = (w - card_w) / 2
      y0 = target_y + ((1.0 - entry_ease) * 40).to_i
      y1 = target_y + card_h + gap + ((1.0 - entry_ease) * 72).to_i
      draw_card(bmp, "es", 0, x, y0, card_w, card_h)
      draw_card(bmp, "en", 1, x, y1, card_w, card_h)

      if @custom_bitmaps[:footer]
        foot = @custom_bitmaps[:footer]
        bmp.stretch_blt(Rect.new(0, h - 42, w, 42), foot, Rect.new(0, 0, foot.width, foot.height))
      else
        bmp.font.size = 15
        bmp.font.color = muted
        hint = @allow_cancel ? "↑ ↓  Elegir / Choose     C / Enter  Confirmar     X / Esc  Volver" : "↑ ↓  Elegir / Choose     C / Enter  Confirmar / Confirm"
        bmp.draw_text(18, h - 38, w - 36, 26, hint, 1)
      end
      if @confirm > 0.0
        alpha = [[(@confirm * 210).to_i, 0].max, 210].min
        bmp.fill_rect(0, 0, w, h, Color.new(255, 255, 255, alpha))
      end
    end
  end

  def self.custom_language_ui_choice(initial, allow_cancel)
    return [false, nil] if config["languageMenuMode"].to_s != "code"
    path = config["languageMenuCustomCode"].to_s
    return [false, nil] if path.empty? || !File.file?(path)
    load(path)
    return [false, nil] if !defined?(TranslateStudioLanguageUI) || !TranslateStudioLanguageUI.respond_to?(:choose)
    value = TranslateStudioLanguageUI.choose(initial, allow_cancel)
    return [true, nil] if value.nil? && allow_cancel
    value = value.to_s.downcase
    return [true, value] if LANGUAGE_INFO.key?(value)
    [false, nil]
  rescue StandardError => e
    echoln("[Translate Studio] Custom language UI failed: #{e.class}: #{e.message}") rescue nil
    [false, nil]
  end

  def self.choose_language!(allow_cancel = true)
    initial = language_code
    initial = system_language_guess if !preference_exists? && !forced_language
    handled, selected = custom_language_ui_choice(initial, allow_cancel)
    selected = LanguageScene.new(initial, allow_cancel).run if !handled
    return false if selected.nil?
    set_language!(selected, true)
  rescue StandardError
    false
  end

  #-----------------------------------------------------------------------------
  # Incremental development discovery (never in the per-frame translation path)
  #-----------------------------------------------------------------------------
  def self.discovery_enabled?
    return false if config["autoDiscoverDevelopmentTexts"] == false
    if config["discoveryOnlyInDebug"] != false
      return false if !defined?($DEBUG) || !$DEBUG
    end
    true
  rescue StandardError
    false
  end

  def self.empty_catalog
    out = { "schema" => 2, "generatedBy" => "Translate Studio #{VERSION}" }
    TEXT_BUCKETS.each { |bucket| out[bucket] = {} }
    out
  end

  def self.catalog_add!(catalog, bucket, source, context)
    return if source.nil? || source.to_s.empty?
    bucket = bucket.to_s
    return if !TEXT_BUCKETS.include?(bucket)
    catalog[bucket] ||= {}
    row = (catalog[bucket][source.to_s] ||= { "Contexts" => [] })
    row["Contexts"] = [] if !row["Contexts"].is_a?(Array)
    row["Contexts"] << context.to_s if !context.to_s.empty? && !row["Contexts"].include?(context.to_s)
  end

  #-----------------------------------------------------------------------------
  # English plugin source references
  #-----------------------------------------------------------------------------
  # These files are reference-only. During a development scan we pair literals
  # from the installed plugin with the same literal slot in the supplied English
  # source file. Only exact/canonical file matches with the same literal layout
  # are accepted. Existing manual translations always win. Events are never used.
  def self.plugin_english_reference
    @plugin_english_reference ||= read_json(PLUGIN_EN_REFERENCE_PATH, { "schema" => 1, "files" => {} })
  rescue StandardError
    { "schema" => 1, "files" => {} }
  end

  def self.base_english_reference
    @base_english_reference ||= read_json(BASE_EN_REFERENCE_PATH, { "schema" => 1, "files" => {} })
  rescue StandardError
    { "schema" => 1, "files" => {} }
  end

  def self.reference_canonical_path(path)
    clean = path.to_s.tr("\\\\", "/").sub(/\A\.\//, "")
    clean = clean.sub(/\Aplugins\//i, "")
    parts = clean.split("/")
    return clean.downcase if parts.empty?
    parts.map! do |part|
      p = part.to_s.dup
      p.sub!(/\A(?:\[[^\]]+\]\s*)+/, "")
      p.sub!(/\A\[?\d{3}\]?[_ -]*/, "")
      p.strip
    end
    parts.join("/").downcase
  rescue StandardError
    path.to_s.downcase
  end

  def self.plugin_reference_index
    return @plugin_reference_index if @plugin_reference_index
    exact = {}
    canonical = {}
    collisions = {}
    files = plugin_english_reference["files"]
    files = {} if !files.is_a?(Hash)
    files.each do |key, row|
      next if !row.is_a?(Hash)
      path = row["path"].to_s
      path = key.to_s if path.empty?
      norm = path.tr("\\\\", "/").sub(/\A\.\//, "").downcase
      exact[norm] = row
      can = reference_canonical_path(path)
      if canonical.key?(can) && canonical[can] != row
        collisions[can] = true
      else
        canonical[can] = row
      end
    end
    collisions.each_key { |key| canonical.delete(key) }
    @plugin_reference_index = { :exact => exact, :canonical => canonical }
  rescue StandardError
    @plugin_reference_index = { :exact => {}, :canonical => {} }
  end

  def self.base_reference_index
    return @base_reference_index if @base_reference_index
    exact = {}
    canonical = {}
    collisions = {}
    files = base_english_reference["files"]
    files = {} if !files.is_a?(Hash)
    files.each do |key, row|
      next if !row.is_a?(Hash)
      path = row["path"].to_s
      path = key.to_s if path.empty?
      norm = path.tr("\\", "/").sub(/\A\.\//, "").downcase
      exact[norm] = row
      can = reference_canonical_path(path)
      if canonical.key?(can) && canonical[can] != row
        collisions[can] = true
      else
        canonical[can] = row
      end
    end
    collisions.each_key { |key| canonical.delete(key) }
    @base_reference_index = { :exact => exact, :canonical => canonical }
  rescue StandardError
    @base_reference_index = { :exact => {}, :canonical => {} }
  end

  def self.base_reference_for_path(path)
    idx = base_reference_index
    norm = path.to_s.tr("\\", "/").sub(/\A\.\//, "").downcase
    idx[:exact][norm] || idx[:canonical][reference_canonical_path(path)]
  rescue StandardError
    nil
  end

  def self.plugin_reference_for_path(path)
    idx = plugin_reference_index
    norm = path.to_s.tr("\\\\", "/").sub(/\A\.\//, "").downcase
    idx[:exact][norm] || idx[:canonical][reference_canonical_path(path)]
  rescue StandardError
    nil
  end

  def self.extract_code_entries(code)
    text = utf8_text(code)
    patterns = [
      ["intl", /(?:_INTL|_ISPRINTF|pbEnter(?:Text|PlayerName|PokemonName|NPCName|BoxName))\s*\(\s*(["'])((?:(?!\1|\\).|\\.)*)\1/m],
      ["sds_text", /(?:text_inline|show_centered_text)\s*(?:\(\s*)?(["'])((?:(?!\1|\\).|\\.)*)\1/m],
      ["speaker", /speaker\s*:\s*(["'])((?:(?!\1|\\).|\\.)*)\1/m]
    ]
    rows = []
    patterns.each do |kind, pattern|
      offset = 0
      while (match = pattern.match(text, offset))
        quote = match[1]
        source = match[2].to_s
        if quote == '"'
          source = source.gsub('\\n', "\n").gsub('\\r', "\r").gsub('\\t', "\t").gsub('\\"', '"').gsub('\\\\', '\\')
        else
          source = source.gsub("\\'", "'").gsub('\\\\', '\\')
        end
        rows << [match.begin(0), kind, source]
        offset = match.end(0)
      end
    end
    rows.sort_by! { |row| row[0] }
    rows.map { |row| { "kind" => row[1], "text" => row[2] } }
  rescue StandardError
    []
  end

  def self.queue_reference_autofill(path, code, bucket)
    bucket = bucket.to_s
    return 0 if !["scripts", "plugins", "bss", "sds"].include?(bucket)
    ref = (bucket == "scripts") ? base_reference_for_path(path) : plugin_reference_for_path(path)
    return 0 if !ref.is_a?(Hash)
    english = ref["entries"]
    return 0 if !english.is_a?(Array) || english.empty?
    current = extract_code_entries(code)
    return 0 if current.length != english.length
    return 0 if current.each_index.any? { |i| current[i]["kind"].to_s != english[i]["kind"].to_s }
    @reference_autofill_pending ||= {}
    @reference_autofill_collisions ||= {}
    @reference_autofill_pending[bucket] ||= {}
    @reference_autofill_collisions[bucket] ||= {}
    added = 0
    current.each_index do |i|
      source = current[i]["text"].to_s
      target = english[i]["text"].to_s
      next if source.empty? || target.empty? || source == target
      prev = @reference_autofill_pending[bucket][source]
      if prev && text_value(prev) != target
        @reference_autofill_pending[bucket].delete(source)
        @reference_autofill_collisions[bucket][source] = true
        next
      end
      next if @reference_autofill_collisions[bucket][source]
      @reference_autofill_pending[bucket][source] = {
        "Text" => target,
        "Reference" => ref["path"].to_s,
        "SourcePack" => ref["sourcePack"].to_s
      }
      added += 1
    end
    added
  rescue StandardError
    0
  end

  def self.manual_translation_row?(row)
    return false if !row.is_a?(Hash)
    return true if row["Manual"] == true
    return true if row["SourcePack"].to_s =~ /manual/i
    return true if row["Reference"].to_s =~ /manual/i
    false
  rescue StandardError
    false
  end

  def self.flush_reference_autofill!
    pending = @reference_autofill_pending
    @reference_autofill_pending = nil
    @reference_autofill_collisions = nil
    return 0 if !pending.is_a?(Hash) || pending.empty?
    doc = document
    doc["languages"] ||= {}
    doc["languages"]["en"] ||= {}
    added = 0
    pending.each do |bucket, rows|
      next if !rows.is_a?(Hash)
      doc["languages"]["en"][bucket] ||= {}
      rows.each do |source, value|
        existing = doc["languages"]["en"][bucket][source]
        # File-slot matching is useful as a fallback for genuinely missing text,
        # but it is not authoritative enough to overwrite an existing translation
        # when a customized source file has inserted/reordered literals.
        next if existing.is_a?(Hash) && !text_value(existing).to_s.empty?
        next if manual_translation_row?(existing)
        doc["languages"]["en"][bucket][source] = value.merge("ReferenceFallback" => true)
        added += 1
      end
    end
    if added > 0
      doc["referenceImport"] ||= {}
      doc["referenceImport"]["pluginEnglishAutoFill"] = {
        "version" => VERSION,
        "added" => added,
        "policy" => "English source-slot references fill missing rows only; existing/manual rows are never overwritten; events excluded."
      }
      write_json(DATA_PATH, doc)
      @text_indexes = {}
      @context_fast_cache = {}
      @template_text_indexes = {}
    end
    added
  rescue StandardError
    0
  end

  def self.scan_code_for_catalog(code, context_prefix, bucket)
    out = empty_catalog
    text = utf8_text(code)
    patterns = [
      [/(?:_INTL|_ISPRINTF|pbEnter(?:Text|PlayerName|PokemonName|NPCName|BoxName))\s*\(\s*(["'])((?:(?!\1|\\).|\\.)*)\1/m, nil],
      [/(?:text_inline|show_centered_text)\s*(?:\(\s*)?(["'])((?:(?!\1|\\).|\\.)*)\1/m, "SDS texto"],
      [/speaker\s*:\s*(["'])((?:(?!\1|\\).|\\.)*)\1/m, "SDS hablante"]
    ]
    patterns.each do |pattern, suffix|
      offset = 0
      while (match = pattern.match(text, offset))
        quote = match[1]
        source = match[2].to_s
        if quote == '"'
          source = source.gsub('\\n', "\n").gsub('\\r', "\r").gsub('\\t', "\t").gsub('\\"', '"').gsub('\\\\', '\\')
        else
          source = source.gsub("\\'", "'").gsub('\\\\', '\\')
        end
        line = text[0...match.begin(0)].count("\n") + 1
        ctx = "#{context_prefix}:L#{line}"
        ctx += " · #{suffix}" if suffix
        catalog_add!(out, bucket, source, ctx)
        offset = match.end(0)
      end
    end
    out
  rescue StandardError
    empty_catalog
  end

  def self.scan_external_json_value_for_catalog(out, value, system, context, parent_key = nil)
    target_bucket = system.to_s.upcase == "BSS" ? "bss" : (system.to_s.upcase == "SDS" ? "sds" : "plugins")
    case value
    when Hash
      value.each do |key, child|
        child_context = "#{context} · #{key}"
        if child.is_a?(String) && external_text_key?(key, system)
          catalog_add!(out, target_bucket, child, child_context)
        elsif child.is_a?(Array) && external_text_key?(key, system)
          child.each_with_index do |entry, i|
            if entry.is_a?(String)
              catalog_add!(out, target_bucket, entry, "#{child_context}[#{i + 1}]")
            else
              scan_external_json_value_for_catalog(out, entry, system, "#{child_context}[#{i + 1}]", key)
            end
          end
        else
          scan_external_json_value_for_catalog(out, child, system, child_context, key)
        end
      end
    when Array
      value.each_with_index { |child, i| scan_external_json_value_for_catalog(out, child, system, "#{context}[#{i + 1}]", parent_key) }
    end
    out
  rescue StandardError
    out
  end

  def self.scan_external_json_file(path, system)
    out = empty_catalog
    doc = read_json(path, {})
    label = system.to_s.upcase
    if label == "BSS" && doc["blueprints"].is_a?(Array)
      scan_external_json_value_for_catalog(out, doc["global"], label, "BSS General") if doc["global"].is_a?(Hash)
      doc["blueprints"].each_with_index do |bp, i|
        next if !bp.is_a?(Hash)
        name = bp["name"].to_s.strip
        name = bp["key"].to_s.strip if name.empty?
        name = "Combate #{i + 1}" if name.empty?
        scan_external_json_value_for_catalog(out, bp, label, "BSS · #{name}")
      end
    elsif label == "SDS" && doc["scenes"].is_a?(Array)
      doc["scenes"].each_with_index do |scene, i|
        next if !scene.is_a?(Hash)
        name = scene["name"].to_s.strip
        name = scene["key"].to_s.strip if name.empty?
        name = "Escena #{i + 1}" if name.empty?
        scan_external_json_value_for_catalog(out, scene, label, "SDS · #{name}")
        code = scene["compiledRuby"].to_s
        merge_catalog!(out, scan_code_for_catalog(code, "SDS · #{name} · Ruby", "sds")) if !code.empty?
      end
    else
      scan_external_json_value_for_catalog(out, doc, label, label)
    end
    out
  rescue StandardError
    empty_catalog
  end

  def self.merge_catalog!(dst, src)
    TEXT_BUCKETS.each do |bucket|
      (src[bucket] || {}).each do |source, row|
        Array(row["Contexts"]).each { |ctx| catalog_add!(dst, bucket, source, ctx) }
      end
    end
    dst
  end

  def self.scan_event_list_for_catalog(list, context_prefix)
    out = empty_catalog
    return out if !list
    i = 0
    while i < list.length
      cmd = list[i]
      if cmd && cmd.code == 101
        text = cmd.parameters[0].to_s.dup
        j = i + 1
        while j < list.length && list[j] && list[j].code == 401
          text += " " + list[j].parameters[0].to_s
          j += 1
        end
        catalog_add!(out, "events", text, "#{context_prefix} · Mensaje")
      elsif cmd && cmd.code == 102
        Array(cmd.parameters[0]).each { |choice| catalog_add!(out, "events", choice.to_s, "#{context_prefix} · Opción") }
      elsif cmd && cmd.code == 355
        code = cmd.parameters[0].to_s.dup
        j = i + 1
        while j < list.length && list[j] && list[j].code == 655
          code += "\n" + list[j].parameters[0].to_s
          j += 1
        end
        merge_catalog!(out, scan_code_for_catalog(code, "#{context_prefix} · Script", "events"))
      elsif cmd && cmd.code == 111 && cmd.parameters[0] == 12
        merge_catalog!(out, scan_code_for_catalog(cmd.parameters[1].to_s, "#{context_prefix} · Condición", "events"))
      elsif cmd && cmd.code == 209
        route = cmd.parameters[1] rescue nil
        if route && route.respond_to?(:list)
          route.list.each do |rcmd|
            merge_catalog!(out, scan_code_for_catalog(rcmd.parameters[0].to_s, "#{context_prefix} · Ruta de movimiento", "events")) if rcmd.code == 45
          end
        end
      end
      i += 1
    end
    out
  rescue StandardError
    empty_catalog
  end

  def self.registered_map_infos
    return {} if !File.file?("Data/MapInfos.rxdata")
    raw = load_data("Data/MapInfos.rxdata")
    out = {}
    if raw.respond_to?(:each)
      raw.each do |id, info|
        next if id.nil? || info.nil?
        name = info.respond_to?(:name) ? info.name.to_s : ""
        out[id.to_i] = name
      end
    end
    out
  rescue StandardError
    {}
  end

  def self.scan_map_file(path, map_name = nil)
    out = empty_catalog
    map = load_data(path)
    map_id = File.basename(path)[/\d+/].to_i
    map_label = map_name.to_s.strip
    map_label = "Sin nombre" if map_label.empty?
    events = map.respond_to?(:events) ? map.events : {}
    events.each_value do |event|
      name = event.respond_to?(:name) ? event.name.to_s.strip : ""
      Array(event.pages).each_with_index do |page, i|
        ev_label = name.empty? ? "Evento #{event.id}" : "Evento #{event.id} \"#{name}\""
        context = sprintf("Map%03d · %s · %s · Pág. %d", map_id, map_label, ev_label, i + 1)
        merge_catalog!(out, scan_event_list_for_catalog(page.list, context))
      end
    end
    out
  rescue StandardError
    empty_catalog
  end

  def self.scan_common_events_file(path)
    out = empty_catalog
    Array(load_data(path)).compact.each do |event|
      name = event.respond_to?(:name) ? event.name.to_s.strip : ""
      context = name.empty? ? "Evento común #{event.id}" : "Evento común #{event.id} \"#{name}\""
      merge_catalog!(out, scan_event_list_for_catalog(event.list, context))
    end
    out
  rescue StandardError
    empty_catalog
  end

  def self.scan_scripts_rxdata(path)
    out = empty_catalog
    Array(load_data(path)).each do |entry|
      next if !entry || entry.length < 3
      begin
        code = defined?(Zlib) ? Zlib::Inflate.inflate(entry[2]).force_encoding(Encoding::UTF_8) : ""
        merge_catalog!(out, scan_code_for_catalog(code, "Script: #{entry[1]}", "scripts"))
      rescue StandardError
      end
    end
    out
  rescue StandardError
    empty_catalog
  end

  def self.scan_plugins_rxdata(path)
    out = empty_catalog
    Array(load_data(path)).each do |plugin|
      next if !plugin || plugin.length < 3
      name = plugin[0].to_s
      next if name =~ /ZBox\s*(?:Translator|Traductor)|Translator[- _]?Helper|Translate Studio/i
      Array(plugin[2]).each do |script_entry|
        begin
          code = defined?(Zlib) ? Zlib::Inflate.inflate(script_entry[1]).force_encoding(Encoding::UTF_8) : ""
          file = script_entry[0].to_s
          display_file = File.basename(file)
          virtual_path = "Plugins/#{name}/#{file}"
          queue_reference_autofill(virtual_path, code, "plugins")
          merge_catalog!(out, scan_code_for_catalog(code, "Plugin: #{name} - #{display_file}", "plugins"))
        rescue StandardError
        end
      end
    end
    out
  rescue StandardError
    empty_catalog
  end

  def self.scan_rb_file(path, bucket, prefix)
    code = utf8_text(File.open(path, "rb") { |f| f.read })
    queue_reference_autofill(path, code, bucket)
    scan_code_for_catalog(code, prefix, bucket)
  rescue StandardError
    empty_catalog
  end

  def self.same_signature?(a, b)
    Array(a).map(&:to_i) == Array(b).map(&:to_i)
  rescue StandardError
    false
  end

  def self.discover_development_texts!(force = false)
    return false if !force && !discovery_enabled?
    cache = read_json(DISCOVERY_CACHE_PATH, { "schema" => 2, "version" => VERSION, "files" => {} })
    if cache["schema"].to_i < 2 || cache["version"].to_s != VERSION
      cache = { "schema" => 2, "version" => VERSION, "files" => {} }
    end
    cache["schema"] = 2
    cache["version"] = VERSION
    cache["files"] = {} if !cache["files"].is_a?(Hash)
    active = {}
    sources = []

    # Maps are taken from MapInfos, not from every MapXXX.rxdata left on disk.
    # This prevents deleted/old/sample maps from appearing as real project events.
    map_infos = registered_map_infos
    if !map_infos.empty?
      map_infos.keys.sort.each do |map_id|
        path = sprintf("Data/Map%03d.rxdata", map_id)
        sources << [path, :map, nil, nil, map_infos[map_id]] if File.file?(path)
      end
    else
      Dir.glob("Data/Map*.rxdata").sort.each { |path| sources << [path, :map, nil, nil, nil] }
    end
    sources << ["Data/CommonEvents.rxdata", :common, nil, nil, nil] if File.file?("Data/CommonEvents.rxdata")

    script_files = File.directory?("Data/Scripts") ? Dir.glob("Data/Scripts/**/*.rb").sort : []
    if script_files.empty? && File.file?("Data/Scripts.rxdata")
      sources << ["Data/Scripts.rxdata", :scripts_rxdata, nil, nil]
    else
      script_files.each do |path|
        rel = path.sub(/^Data\/Scripts\/?/, "")
        sources << [path, :rb, "scripts", "Script: #{rel}"]
      end
    end

    plugin_files = File.directory?("Plugins") ? Dir.glob("Plugins/**/*.rb").sort : []
    plugin_files.reject! { |p| p.include?("[CARNKEVT] Translate Studio") || p =~ /ZBox\s*(?:Translator|Traductor)|Translator[- _]?Helper/i }
    if plugin_files.empty? && File.file?("Data/PluginScripts.rxdata")
      sources << ["Data/PluginScripts.rxdata", :plugins_rxdata, nil, nil]
    else
      plugin_files.each do |path|
        rel = path.sub(/^Plugins\/?/, "")
        parts = rel.split(/[\\\/]/)
        target_bucket = "plugins"
        if rel =~ /Battle[ _-]*Scene[ _-]*Studio/i
          prefix = "BSS: #{rel}"
          target_bucket = "bss"
        elsif rel =~ /Scene[ _-]*Director|Scene[ _-]*Engine/i
          prefix = "SDS: #{rel}"
          target_bucket = "sds"
        else
          prefix = parts.length > 1 ? "Plugin: #{parts[0]} - #{parts[1..-1].join('/')}" : "Plugin: #{rel}"
        end
        sources << [path, :rb, target_bucket, prefix]
      end
    end

    # Authored text stored outside Ruby by BSS and SDS.
    sources << ["Data/BattleSceneStudio/battles.json", :external_json, "bss", "BSS", "BSS"] if File.file?("Data/BattleSceneStudio/battles.json")
    sources << ["Data/BattleSceneStudio/battles.recovery.json", :external_json, "bss", "BSS recovery", "BSS"] if File.file?("Data/BattleSceneStudio/battles.recovery.json")
    sources << ["Data/SceneDirector/scenes.json", :external_json, "sds", "SDS", "SDS"] if File.file?("Data/SceneDirector/scenes.json")

    sources.each do |path, kind, bucket, prefix, meta|
      signature = sig(path)
      signature = Array(signature) + Array(sig("Data/MapInfos.rxdata")) if kind == :map
      next if signature.nil?
      active[path] = true
      cached = cache["files"][path]
      if !force && cached.is_a?(Hash) && same_signature?(cached["sig"], signature) && cached["catalog"].is_a?(Hash)
        next
      end
      data = case kind
             when :map then scan_map_file(path, meta)
             when :common then scan_common_events_file(path)
             when :scripts_rxdata then scan_scripts_rxdata(path)
             when :plugins_rxdata then scan_plugins_rxdata(path)
             when :rb then scan_rb_file(path, bucket, prefix)
             when :external_json then scan_external_json_file(path, meta || prefix)
             else empty_catalog
             end
      cache["files"][path] = { "sig" => signature, "catalog" => data }
    end
    cache["files"].delete_if { |path, _row| !active[path] }

    merged = empty_catalog
    cache["files"].each_value do |row|
      merge_catalog!(merged, row["catalog"]) if row.is_a?(Hash) && row["catalog"].is_a?(Hash)
    end
    TEXT_BUCKETS.each do |bucket|
      merged[bucket].each_value { |row| row["Contexts"] = Array(row["Contexts"]).uniq.sort }
    end
    flush_reference_autofill!
    write_json(DISCOVERY_CACHE_PATH, cache)
    old = read_json(CATALOG_PATH, {})
    if JSON.generate(old) != JSON.generate(merged)
      write_json(CATALOG_PATH, merged)
      @context_catalog = nil
      @context_catalog_signature = nil
      @text_indexes = {}
      @context_fast_cache = {}
      @template_text_indexes = {}
    end
    true
  rescue StandardError
    false
  end

  def self.bootstrap_language!
    return true if @bootstrapped
    @bootstrapped = true
    forced = forced_language
    if forced
      @session_language = forced
      apply_native_language_hint!(forced)
    else
      saved = saved_language
      if saved
        @session_language = saved
        apply_native_language_hint!(saved)
      elsif config["showFirstBootLanguageMenu"] != false
        choose_language!(false) || set_language!(system_language_guess, true)
      else
        set_language!(system_language_guess, true)
      end
    end
    discover_development_texts!(false)
    true
  rescue StandardError
    @session_language = config["baseLanguage"].to_s.downcase
    true
  end
end

#===============================================================================
# Install hooks now; GameData may already exist.
#===============================================================================
CarnekTranslateStudio.install!

#===============================================================================
# Ability splash grammar/layout bridge
#===============================================================================
# The Spanish base intentionally draws the ability first and "de {1}" second
# (e.g. "Intimidación" / "de Persian"). Translating only the words produces
# the wrong English layout ("Intimidate" / "Persian's"). English Essentials
# draws the possessive Pokémon name first and the ability second, so swap the
# displayed rows only while ENG is active. Spanish keeps the project's layout.
module CarnekTranslateStudioAbilitySplashEnglishOrder
  def refresh
    if CarnekTranslateStudio.enabled? && CarnekTranslateStudio.language_code == "en" && @battler
      self.bitmap.clear
      text_pos = []
      left_offset = self.class.const_defined?(:TEXT_X_OFFSET) ? self.class.const_get(:TEXT_X_OFFSET) : 10
      right_margin = self.class.const_defined?(:TEXT_X_MARGIN) ? self.class.const_get(:TEXT_X_MARGIN) : 8
      top_y = self.class.const_defined?(:ABILITY_NAME_Y) ? self.class.const_get(:ABILITY_NAME_Y) : 8
      bottom_y = self.class.const_defined?(:POKEMON_NAME_Y) ? self.class.const_get(:POKEMON_NAME_Y) : 38
      text_x = (@side == 0) ? left_offset : self.bitmap.width - right_margin
      align = (@side == 0) ? :left : :right
      base_color = self.class.const_defined?(:TEXT_BASE_COLOR) ? self.class.const_get(:TEXT_BASE_COLOR) : Color.new(0, 0, 0)
      shadow_color = self.class.const_defined?(:TEXT_SHADOW_COLOR) ? self.class.const_get(:TEXT_SHADOW_COLOR) : Color.new(248, 248, 248)
      text_pos.push([_INTL("{1}'s", @battler.name), text_x, top_y, align,
                     base_color, shadow_color, :outline])
      text_pos.push([@battler.abilityName, text_x, bottom_y, align,
                     base_color, shadow_color, :outline])
      pbDrawTextPositions(self.bitmap, text_pos)
      return
    end
    super
  end
end

if defined?(Battle::Scene::AbilitySplashBar) &&
   !Battle::Scene::AbilitySplashBar.ancestors.include?(CarnekTranslateStudioAbilitySplashEnglishOrder)
  Battle::Scene::AbilitySplashBar.prepend(CarnekTranslateStudioAbilitySplashEnglishOrder)
end


#===============================================================================
# Context-aware _INTL family
#===============================================================================
unless defined?(carnek_translate_original_INTL)
  alias carnek_translate_original_INTL _INTL if defined?(_INTL)
end

def _INTL(*args)
  return "" if args.empty?
  source = args[0].to_s
  translated = CarnekTranslateStudio.contextual_text(source)
  if translated == source && defined?(carnek_translate_original_INTL)
    begin
      native = carnek_translate_original_INTL(*args)
      translated = CarnekTranslateStudio.contextual_text(native) if native
    rescue StandardError
    end
  end
  result = translated.to_s.dup
  (1...args.length).each { |i| result.gsub!(/\{#{i}\}/) { args[i].to_s } }
  result
end

unless defined?(carnek_translate_original_MAPINTL)
  alias carnek_translate_original_MAPINTL _MAPINTL if defined?(_MAPINTL)
end

def _MAPINTL(map_id, *args)
  return "" if args.empty?
  source = args[0].to_s
  translated = CarnekTranslateStudio.event_text(source, map_id)
  if translated == source && defined?(carnek_translate_original_MAPINTL)
    begin
      native = carnek_translate_original_MAPINTL(map_id, *args)
      translated = CarnekTranslateStudio.event_text(native, map_id) if native
    rescue StandardError
    end
  end
  result = translated.to_s.dup
  (1...args.length).each { |i| result.gsub!(/\{#{i}\}/) { args[i].to_s } }
  result
end

unless defined?(carnek_translate_original_ISPRINTF)
  alias carnek_translate_original_ISPRINTF _ISPRINTF if defined?(_ISPRINTF)
end

def _ISPRINTF(*args)
  return "" if args.empty?
  source = args[0].to_s
  translated = CarnekTranslateStudio.contextual_text(source)
  if translated == source && defined?(carnek_translate_original_ISPRINTF)
    begin
      native = carnek_translate_original_ISPRINTF(*args)
      translated = CarnekTranslateStudio.contextual_text(native) if native
    rescue StandardError
    end
  end
  result = translated.to_s.dup
  (1...args.length).each do |i|
    result.gsub!(/\{#{i}\:([^\}]+?)\}/) do
      begin
        sprintf("%" + $1, args[i])
      rescue StandardError
        args[i].to_s
      end
    end
    result.gsub!(/\{#{i}\}/) { args[i].to_s }
  end
  result
end

# Text-entry labels/defaults follow the caller context; player-entered result is untouched.
if defined?(pbEnterText)
  unless defined?(carnek_translate_original_pbEnterText)
    alias carnek_translate_original_pbEnterText pbEnterText
  end
  def pbEnterText(helptext, minlength, maxlength, initialText = "", mode = 0, pokemon = nil, nofadeout = false)
    helptext = CarnekTranslateStudio.contextual_text(helptext)
    initialText = CarnekTranslateStudio.contextual_text(initialText)
    carnek_translate_original_pbEnterText(helptext, minlength, maxlength, initialText, mode, pokemon, nofadeout)
  end
end

#===============================================================================
# Essentials compatibility: pbGetBasicMapNameFromId used to call .name on nil
# for stale/nonexistent map IDs. mkxp-z can log the rescued exception anyway,
# so avoid raising it in the first place.
#===============================================================================
def pbGetBasicMapNameFromId(id)
  map = pbLoadMapInfos
  return "" if !map || !map.respond_to?(:[])
  key = id.respond_to?(:to_i) ? id.to_i : id
  info = map[key]
  return "" if !info
  return info.name.to_s if info.respond_to?(:name)
  ""
rescue StandardError
  ""
end

#===============================================================================
# Graphics hooks
#===============================================================================
unless defined?(carnek_translate_original_pbResolveBitmap)
  alias carnek_translate_original_pbResolveBitmap pbResolveBitmap if defined?(pbResolveBitmap)
end

if defined?(carnek_translate_original_pbResolveBitmap)
  def pbResolveBitmap(filename)
    translated = CarnekTranslateStudio.resolve_translated_graphic(filename)
    carnek_translate_original_pbResolveBitmap(translated)
  end
end

if defined?(RPG::Cache)
  module CarnekTranslateCachePatch
    def load_bitmap(folder_name, filename, hue = 0)
      if filename && !filename.to_s.empty?
        full = folder_name.to_s + filename.to_s
        translated = CarnekTranslateStudio.resolve_translated_graphic(full)
        if translated != full
          relative = translated.start_with?(folder_name.to_s) ? translated[folder_name.to_s.length..-1] : translated
          return super(folder_name, relative, hue)
        end
      end
      super
    end
  end
  begin
    cache_singleton = class << RPG::Cache; self; end
    cache_singleton.prepend(CarnekTranslateCachePatch) unless cache_singleton.ancestors.include?(CarnekTranslateCachePatch)
  rescue StandardError
  end
end

#===============================================================================
# Bootstrap after PokemonSystem exists.
#===============================================================================
if defined?(Game)
  module CarnekTranslateAfterSystemSetup
    def set_up_system(*args, &block)
      ret = super(*args, &block)
      begin
        CarnekTranslateStudio.reload!
        CarnekTranslateStudio.install!
        CarnekTranslateStudio.bootstrap_language!
      rescue StandardError
      end
      ret
    end
  end
  begin
    game_singleton = class << Game; self; end
    game_singleton.prepend(CarnekTranslateAfterSystemSetup) unless game_singleton.ancestors.include?(CarnekTranslateAfterSystemSetup)
  rescue StandardError
  end
end

#===============================================================================
# Options + Debug
#===============================================================================
if defined?(MenuHandlers) && defined?(EnumOption) && CarnekTranslateStudio.config["showLanguageOption"] != false && !CarnekTranslateStudio.forced_language
  begin
    MenuHandlers.add(:options_menu, :translate_studio_game_language, {
      "name"        => "Idioma / Language",
      "order"       => 5,
      "type"        => EnumOption,
      "parameters"  => ["Español", "English"],
      "description" => "Cambia el idioma del juego. / Change the game language.",
      "get_proc"    => proc { next CarnekTranslateStudio.language_index },
      "set_proc"    => proc do |value, scene|
        CarnekTranslateStudio.set_language!(value.to_i == 1 ? "en" : "es", true)
        begin
          scene.rebuild_for_translation if scene && scene.respond_to?(:rebuild_for_translation)
          scene.refresh if scene && scene.respond_to?(:refresh)
        rescue StandardError
        end
      end
    })
  rescue StandardError
  end
end

if defined?(MenuHandlers) && CarnekTranslateStudio.config["showDebugTools"] != false
  begin
    MenuHandlers.add(:debug_menu, :translate_studio_language, {
      "name"        => proc { CarnekTranslateStudio.language_code == "en" ? "Translate Studio: Language" : "Translate Studio: Idioma" },
      "parent"      => :main,
      "description" => proc { CarnekTranslateStudio.language_code == "en" ? "Open the visual language selector." : "Abre el selector visual de idioma." },
      "effect"      => proc { |_sprites, _viewport| CarnekTranslateStudio.choose_language!(true) }
    })
    MenuHandlers.add(:debug_menu, :translate_studio_reload, {
      "name"        => proc { CarnekTranslateStudio.language_code == "en" ? "Translate Studio: Reload translations" : "Translate Studio: Recargar traducciones" },
      "parent"      => :main,
      "description" => proc { CarnekTranslateStudio.language_code == "en" ? "Reload JSON and localized graphics without compiling." : "Recarga JSON e imágenes localizadas sin compilar." },
      "effect"      => proc do |_sprites, _viewport|
        CarnekTranslateStudio.reload!
        CarnekTranslateStudio.install!
        msg = CarnekTranslateStudio.language_code == "en" ? "Translate Studio: translations reloaded." : "Translate Studio: traducciones recargadas."
        pbMessage(msg) rescue nil
      end
    })
    MenuHandlers.add(:debug_menu, :translate_studio_rescan, {
      "name"        => proc { CarnekTranslateStudio.language_code == "en" ? "Translate Studio: Refresh catalog" : "Translate Studio: Actualizar catálogo" },
      "parent"      => :main,
      "description" => proc { CarnekTranslateStudio.language_code == "en" ? "Rescan real maps, common events, scripts, plugins, BSS and SDS." : "Reescanea mapas reales, eventos comunes, scripts, plugins y textos externos de BSS/SDS modificados." },
      "effect"      => proc do |_sprites, _viewport|
        ok = CarnekTranslateStudio.discover_development_texts!(true)
        msg = if CarnekTranslateStudio.language_code == "en"
                ok ? "Translate Studio: catalog refreshed." : "Translate Studio: catalog refresh failed."
              else
                ok ? "Translate Studio: catálogo actualizado." : "Translate Studio: no se pudo actualizar el catálogo."
              end
        pbMessage(msg) rescue nil
      end
    })
  rescue StandardError
  end
end
