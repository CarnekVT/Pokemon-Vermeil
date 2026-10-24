# encoding: UTF-8
#===============================================================================
# Nueva Pokedex — ZBOX
# Arquitectura MVC: Scene (controller/state) + Screen (wrapper) + View (procedural UI)
# UI generada proceduralmente (0 imágenes para la UI). Adaptada a 640x480.
#===============================================================================

module Settings
  NUEVA_POKEDEX_ENABLED = true unless defined?(NUEVA_POKEDEX_ENABLED)
end

module NuevaPokedex
  SCREEN_WIDTH  = (defined?(Graphics) && Graphics.respond_to?(:width)) ? Graphics.width : 640
  SCREEN_HEIGHT = (defined?(Graphics) && Graphics.respond_to?(:height)) ? Graphics.height : 480

  # State machine
  STATE_LIST  = 0
  STATE_INFO  = 1
  STATE_AREA  = 2
  STATE_FORMS = 3

  # Colors (updated to match ChangeDex palette)
  COLOR_BG          = Color.new(20, 25, 35, 255)   # colorBackground "#141923"
  COLOR_PANEL       = Color.new(28, 36, 50, 220)   # colorPanelFill "#1c2432"
  COLOR_PANEL_DARK  = Color.new(62, 78, 104, 240) # colorPanelEdge "#3e4e68"
  COLOR_TEXT        = Color.new(245, 245, 245, 255) # colorText "#f5f5f5"
  COLOR_TEXT_DIM    = Color.new(180, 180, 180, 255) # colorMuted "#b4b4b4"
  COLOR_ACCENT      = Color.new(220, 60, 60, 255)   # colorHighlight "#dc3c3c"
  COLOR_SEEN        = Color.new(255, 157, 92, 255)  # colorResult "#ff9d5c"
  COLOR_OWNED       = Color.new(100, 255, 120, 255) # colorNew "#64ff78"
  COLOR_UNSEEN      = Color.new(255, 215, 0, 255)   # colorDifference "#ffd700"
  COLOR_SELECT      = Color.new(255, 255, 255, 30)   # unchanged opacity

  # Layout — Lista (lado izquierdo + lista a la derecha)
  LIST_WINDOW_X  = 286
  LIST_WINDOW_Y  = 24
  LIST_WINDOW_W  = 326
  LIST_WINDOW_H  = 420
  SLOT_HEIGHT    = 36
  SLOT_SPACING   = 4
  VISIBLE_SLOTS  = 10
  SCROLLBAR_X    = 615
  SCROLLBAR_Y    = 32
  SCROLLBAR_W    = 6
  SCROLLBAR_H    = 420

  # Layout — Sprite Viewer (lado izquierdo)
  SPRITE_BG_X    = 24
  SPRITE_BG_Y    = 56
  SPRITE_BG_W    = 256
  SPRITE_BG_H    = 256
  SPRITE_X       = 152
  SPRITE_Y       = 184
  SPRITE_W       = 256
  SPRITE_H       = 256

  # Layout — Header
  HEADER_X       = 24
  HEADER_Y       = 12
  HEADER_W       = 256
  HEADER_H       = 44

  # Layout — Counters
  COUNT_X        = 24
  COUNT_Y        = 320
  COUNT_W        = 256

  # Hoja de tipos canónica: Graphics/UI/types.png (tiles 64x28, fila = icon_position)
  TYPE_ICON_W     = 64
  TYPE_ICON_H     = 28

  # Pantalla de datos (STATE_INFO) a parte, estilo Pokédex canónica
  ENTRY_SPRITE_X = 24      # hueco del sprite (24..280, 56..312): lo deja transparente para ver el sprite
  ENTRY_SPRITE_Y = 56
  ENTRY_SPRITE_W = 256
  ENTRY_SPRITE_H = 256
  ENTRY_DESC_Y   = 330     # ficha de descripción (ancho completo)
  ENTRY_DESC_W   = 592
  ENTRY_DESC_H   = 118

  module_function

  # Localización por idioma del juego sin duplicar gráficos ni registros.
  POKEDEX_EN = {
    "Pokédex Nacional" => "National Pokédex",
    "Región {1}" => "Region {1}",
    "No se pudo guardar la config de la Pokédex." => "Could not save the Pokédex configuration.",
    "{1} (Forma {2})" => "{1} (Form {2})",
    "{1} [mostrar]" => "{1} [show]",
    "GUARDAR" => "SAVE",
    "Config guardada." => "Configuration saved.",
    "Ocultar forma" => "Hide form",
    "Mostrar forma" => "Show form",
    "Quitar slot propio" => "Remove separate slot",
    "Dar slot propio" => "Add separate slot",
    "Buscar..." => "Search…",
    "Flechas: explorar  ·  C: ficha  ·  D: ordenar  ·  Z: buscar  ·  X: salir" => "Arrows: Browse · C: Info · D: Sort · Z: Search · X: Exit",
    "VISTOS: {1}/{2}" => "SEEN: {1}/{2}",
    "OBTENIDOS: {1}/{2}" => "CAUGHT: {1}/{2}",
    "POKÉDEX · {1}" => "POKÉDEX · {1}",
    "Super Shiny" => "Super Shiny",
    "Normal" => "Normal",
    "Color: {1}" => "Color: {1}",
    "Nº {1}" => "No. {1}",
    "OBTENIDO" => "CAUGHT",
    "VISTO" => "SEEN",
    "NO VISTO" => "NOT SEEN",
    "Categoría: {1}" => "Species: {1}",
    "Altura: {1} m" => "Height: {1} m",
    "Peso: {1} kg" => "Weight: {1} kg",
    "POKÉDEX" => "POKÉDEX",
    "D: cambiar color" => "D: Change color",
    "Zona · {1}" => "Area · {1}",
    "Área desconocida" => "Area unknown",
    "Localizaciones: {1}" => "Locations: {1}",
    "Ubicación: desconocida" => "Location: unknown",
    "Formas de {1}" => "Forms of {1}",
    "Forma base" => "Base form",
    "Forma {1}" => "Form {1}",
    "Color: {1} · Z: cambiar" => "Color: {1} · Z: Change",
    "{1} ({2})" => "{1} ({2})",
    "Forma" => "Form",
    "Buscar Pokémon visto:" => "Search seen Pokémon:",
    "No hay coincidencias entre tus Pokémon vistos." => "No matches among your seen Pokémon.",
    "Orden numérico" => "Numerical",
    "Nombre A-Z" => "Name A–Z",
    "Más pesado" => "Heaviest",
    "Más liviano" => "Lightest",
    "Más alto" => "Tallest",
    "Más bajo" => "Shortest",
    "Pokédex N" => "Pokédex",
    "← Área     → Formas" => "← Area     → Forms"
  }.freeze

  def t(source, *args)
    language = if defined?(CarnekTranslateStudio) && CarnekTranslateStudio.respond_to?(:language_code)
                 CarnekTranslateStudio.language_code
               else
                 "es"
               end
    text = language.to_s == "en" ? (POKEDEX_EN[source.to_s] || source) : source
    _INTL(text, *args)
  end

  def config
    @config_stamp = nil if !defined?(@config_stamp)
    @config = nil if !defined?(@config)
    stamp = (File.file?("Data/SpeciesDex/config.json") ?
             [File.mtime("Data/SpeciesDex/config.json").to_f, File.size("Data/SpeciesDex/config.json")] : nil)
    return @config if @config && @config_stamp == stamp
    path = "Data/SpeciesDex/config.json"
    if !File.file?(path)
      @config = {}
      @config_stamp = nil
      return @config
    end
    raw = File.open(path, "rb") { |f| f.read }
    begin
      if defined?(::JSON) && ::JSON.respond_to?(:parse)
        @config = ::JSON.parse(raw)
      elsif defined?(CarnekStandaloneJSON)
        @config = CarnekStandaloneJSON.parse(CarnekStandaloneJSON.utf8(raw))
      elsif defined?(ResearchNotebook::MiniJSON)
        @config = ResearchNotebook::MiniJSON.parse(raw)
      else
        require "json"
        @config = ::JSON.parse(raw)
      end
      raise "La raíz del JSON no es un objeto" unless @config.is_a?(Hash)
    rescue StandardError => e
      echoln("[Nueva Pokédex] Error de configuración: #{e.message}") if defined?(echoln)
      @config = {}
    end
    @config_stamp = stamp
    return @config
  end

  def enabled_dexes
    lists = config["dexes"]
    return [] unless lists.is_a?(Array)
    Array(config["enabledDexes"]).filter_map do |value|
      raw = value.to_s
      next unless raw =~ /\A\d+\z/
      number = raw.to_i
      next if number >= lists.length || !lists[number].is_a?(Array)
      number
    end.uniq
  end

  def dex_name_for(region)
    names = config["dexNames"] || {}
    if names.is_a?(Array) && names[region].is_a?(String) && !names[region].empty?
      return names[region]
    elsif names.is_a?(Hash)
      val = names[region.to_s] || names[region]
      return val if val.is_a?(String) && !val.empty?
    end
    return NuevaPokedex.t("Pokédex Nacional") if region < 0
    return NuevaPokedex.t("Región {1}", region + 1)
  end

  def normalize_entry(entry)
    raw = entry.to_s.strip
    return nil if raw.empty?
    if raw.include?(",")
      parts = raw.split(",", 2)
      form = parts[1].strip.to_i
      base = parts[0].strip
      id = RepositoryProxy.normalize_id(raw)
      if id && form > 0
        return "#{id}_#{form}".to_sym
      elsif id
        return id
      else
        return base.upcase.to_sym
      end
    end
    return RepositoryProxy.normalize_id(raw) || raw.upcase.to_sym
  end

  def regional_species(region)
    if region.to_i == -1
      return [] unless config["nationalAvailable"]
      species = []
      GameData::Species.each_species { |data| species << data.species }
      return species.uniq
    end
    lists = config["dexes"]
    return [] unless lists.is_a?(Array)
    return [] unless region.is_a?(Integer) && region >= 0 && region < lists.length
    list = lists[region]
    return [] unless list.is_a?(Array)
    result = []
    Array(list).each do |entry|
      ent = normalize_entry(entry)
      next if !ent
      base, form = entry_base_and_form(ent)
      # Un slot con forma propia SIEMPRE se muestra: la lista de la dex ES la
      # fuente de verdad de sus entradas. La lista "forms" del config solo
      # decide qué se ve en la página de FORMAS, no si un slot aparece.
      next if !GameData::Species.try_get(base)
      result.push(ent)
    end
    return result.uniq
  end

  # Slots alternos de la JSON pueden requerir descubrimiento propio.
  # Nunca revelar una forma solamente porque se avistó la especie base.
  def slot_seen?(slot)
    return false unless defined?($player) && $player && $player.pokedex
    base, form = entry_base_and_form(slot)
    return $player.pokedex.seen?(base) if form.to_i <= 0
    return false unless $player.pokedex.seen?(base)
    (0..1).any? { |gender| $player.pokedex.seen_form?(base, gender, form) }
  rescue StandardError
    false
  end

  def dex_form_data(base, form)
    if defined?(GoldenSystem::Data) && form.to_i > 0
      definition = GoldenSystem::Data.form_definition(base, 0)
      if definition && definition["number"].to_i == form.to_i
        return GoldenSystem::Data.build_form_proxy(base, 0, form, definition)
      end
    end
    GameData::Species.get_species_form(base, form.to_i)
  rescue StandardError
    GameData::Species.try_get(base)
  end

  def form_seen?(base, form)
    return false unless $player && $player.pokedex
    return $player.pokedex.seen?(base) if form.to_i <= 0
    (0..1).any? { |gender| $player.pokedex.seen_form?(base, gender, form.to_i) }
  rescue StandardError
    false
  end

  def slot_owned?(slot)
    return false unless defined?($player) && $player && $player.pokedex
    base, form = entry_base_and_form(slot)
    return $player.pokedex.owned?(base) if form.to_i <= 0
    # Essentials no almacena capturas por forma. Exigir propiedad de la especie
    # y registro de la forma vista, sin inventar propiedad específica.
    $player.pokedex.owned?(base) && slot_seen?(slot)
  rescue StandardError
    false
  end

  def accessible_regions
    enabled = enabled_dexes
    regions = enabled.dup
    regions << -1 if config["nationalAvailable"]
    return regions
  end

  def enabled?
    return Settings::NUEVA_POKEDEX_ENABLED
  end

  # --- Config de formas (visibles / propias en la Pokédex) ---

  # Devuelve [especie_base, forma] de un símbolo de slot (:RATTATA_1 => [:RATTATA, 1]).
  def entry_base_and_form(species)
    name = species.to_s
    i = name.rindex("_")
    if i && i > 0 && name[(i + 1)..].match?(/\A\d+\z/)
      return [name[0...i].to_sym, name[(i + 1)..].to_i]
    end
    return [species, 0]
  end

  def form_key(base_species, form)
    return "#{base_species.to_s.upcase},#{form}"
  end

  # Formas ocultas: las anotadas en config["forms"] (formato "ESPECIE,FORMA").
  def hidden_forms
    list = config["forms"]
    return [] if !list.is_a?(Array)
    return list.map { |e| e.to_s.strip.upcase }.reject { |e| e.empty? }
  end

  def form_shown?(base_species, form)
    return true if form.nil? || form <= 0
    return !hidden_forms.include?(form_key(base_species, form))
  end

  def set_form_shown(base_species, form, shown)
    return if form.nil? || form <= 0
    key = form_key(base_species, form)
    cfg = config
    cfg["forms"] = [] if !cfg["forms"].is_a?(Array)
    if shown
      cfg["forms"].reject! { |e| e.to_s.strip.upcase == key }
    elsif !cfg["forms"].any? { |e| e.to_s.strip.upcase == key }
      cfg["forms"].push(key)
    end
    save_config
  end

  # Añade o retira "ESPECIE,FORMA" de la lista de la región (slot propio).
  def set_species_in_region(region, entry, present)
    lists = config["dexes"]
    return if !lists.is_a?(Array)
    list = lists[region]
    return if !list.is_a?(Array)
    raw = entry.to_s.sub(/_(\d+)\z/, ',\1')
    if present
      entry_normalized = normalize_entry(raw)
      already = list.any? { |e| normalize_entry(e) == entry_normalized }
      list.push(raw) if !already
    else
      entry_normalized = normalize_entry(raw)
      list.reject! { |e| normalize_entry(e) == entry_normalized }
    end
    save_config
  end

  def save_config
    cfg = config
    path = "Data/SpeciesDex/config.json"
    temp = path + ".tmp"
    begin
      require "json" if !defined?(::JSON)
      serialized = ::JSON.pretty_generate(cfg) + "\n"
      File.open(temp, "wb") { |f| f.write(serialized); f.flush; f.fsync rescue nil }
      File.rename(temp, path)
      @config_stamp = nil
      true
    rescue StandardError => e
      echoln("[Nueva Pokédex] No se guardó JSON: #{e.message}") if defined?(echoln)
      pbMessage(NuevaPokedex.t("No se pudo guardar la config de la Pokédex.")) if defined?(pbMessage)
      false
    ensure
      File.delete(temp) if File.file?(temp)
    end
  end

  # Región del Town Map asociada a una Pokédex (dexRegions del config.json).
  def dex_region_for(dex_index)
    regs = config["dexRegions"]
    return nil if !regs.is_a?(Array)
    val = regs[dex_index]
    return nil if val.nil? || val.to_s.strip.empty?
    return val.to_i
  end

  # Hoja de iconos de tipo canónica (Graphics/UI/types.png, tiles 64x28),
  # cargada perezosa. Misma hoja que usan las páginas MUI de Pokédex.
  def type_icons
    return @type_icons if @type_icons
    @type_icons = AnimatedBitmap.new(_INTL("Graphics/UI/types"))
    return @type_icons
  end

  # Compatibilidad: esta UI no necesita el atlas duplicado de Pokedex.
  def pokedex_type_icons
    type_icons
  end

  # --- Editor debug de Pokédex (formas visibles / slots) ---

  def debug_edit_pokedex
    regions = accessible_regions
    return if regions.empty?
    region = regions.first
    species_list = regional_species(region)
    return if species_list.empty?
    cmds = species_list.map do |entry|
      base, form = entry_base_and_form(entry)
      label = base.to_s
      label = NuevaPokedex.t("{1} (Forma {2})", base.to_s, form) if form > 0
      NuevaPokedex.t("{1} [mostrar]", label)
    end
    cmds << NuevaPokedex.t("GUARDAR")
    loop do
      cmd = pbShowCommands(nil, cmds, 0)
      break if cmd < 0
      if cmd == cmds.length - 1
        save_config
        pbMessage(NuevaPokedex.t("Config guardada."))
        break
      end
      entry = species_list[cmd]
      base, form = entry_base_and_form(entry)
      visible = form_shown?(base, form)
      options = [visible ? NuevaPokedex.t("Ocultar forma") : NuevaPokedex.t("Mostrar forma")]
      if form > 0
        options << (form_has_own_slot?(region, entry) ? NuevaPokedex.t("Quitar slot propio") : NuevaPokedex.t("Dar slot propio"))
      end
      choice = pbShowCommands(nil, options, -1)
      next if choice < 0
      if choice == 0
        set_form_shown(base, form, !visible)
      elsif choice == 1 && form > 0
        has_slot = form_has_own_slot?(region, entry)
        set_species_in_region(region, entry, !has_slot)
      end
      species_list = regional_species(region)
      cmds = species_list.map do |e|
        b, f = entry_base_and_form(e)
        l = b.to_s
        l = NuevaPokedex.t("{1} (Forma {2})", b.to_s, f) if f > 0
        NuevaPokedex.t("{1} [mostrar]", l)
      end
      cmds << NuevaPokedex.t("GUARDAR")
    end
  end

  def form_has_own_slot?(region, entry)
    lists = config["dexes"]
    return false if !lists.is_a?(Array)
    list = lists[region]
    return false if !list.is_a?(Array)
    return list.any? { |e| normalize_entry(e) == entry }
  end

  module RepositoryProxy
    module_function

    def normalize_id(value)
      if defined?(ResearchNotebook::Repository) && ResearchNotebook::Repository.respond_to?(:normalize_species_id)
        return ResearchNotebook::Repository.normalize_species_id(value)
      end
      raw = value.to_s.strip
      raw = raw.split(",", 2)[0].strip if raw.include?(",")
      return raw.upcase.to_sym
    end
  end
end

#===============================================================================
# Modelo: datos del Pokémon (lazy loading)
#===============================================================================
class NuevaPokedexData
  attr_reader :region

  def initialize(region)
    @region = region
    @assigned_list = NuevaPokedex.regional_species(region)
    @assigned_set = {}
    @assigned_list.each { |s| @assigned_set[s] = true }
    # Roster del juego: SOLO la dex habilitada (p.ej. la de Payu).
    # La decisión de incluir todo el PBS es de los mods de Maker Studio
    # (Dex Catalog Studio), nunca algo de gameplay.
    @species_list = @assigned_list.dup
    @dex_slot_numbers = {}
    @assigned_list.each_with_index { |slot, i| @dex_slot_numbers[slot] = i + 1 }
    @cache = {}
  end

  def assigned?(species)
    return @assigned_set[species] == true
  end

  def slot_number_for(base_species, form)
    sym = form.to_i > 0 ? "#{base_species}_#{form}".to_sym : base_species.to_sym
    @dex_slot_numbers[sym]
  end

  def species_count
    return @species_list.length
  end

  def species_at(index)
    return @species_list[index]
  end

  # Modos de ordenación del roster (tecla SPECIAL en la lista)
  SORTS = {
    :NUM          => 0,
    :NAME         => 1,
    :WEIGHT_DESC  => 2,
    :WEIGHT_ASC   => 3,
    :HEIGHT_DESC  => 4,
    :HEIGHT_ASC   => 5
  }

  def data_for(index)
    return nil if index < 0 || index >= @species_list.length
    return @cache[index] if @cache[index]
    species = @species_list[index]
    base_species, form = NuevaPokedex.entry_base_and_form(species)
    sd = (GameData::Species.get_species_form(base_species, form) rescue nil)
    sd ||= GameData::Species.try_get(base_species)
    if !sd
      # ponytail: slash sin dato en GameData se iguala al de su especie base; nunca se descarta del listado
      return nil
    end
    entry = {
      species:      species,
      base_species: base_species,
      form:         form,
      form_name:    (sd.form_name if form > 0 && sd.respond_to?(:form_name)),
      number:       @dex_slot_numbers[species] || index + 1,
      name:         sd.name,
      category:     sd.category,
      height:       sd.height,
      weight:       sd.weight,
      types:        sd.types,
      description:  sd.pokedex_entry
    }
    @cache[index] = entry
    return entry
  end

  def sort=(sort_mode)
    return if !SORTS.keys.include?(sort_mode)
    @cache.clear
    if sort_mode == :NUM
      @species_list = @assigned_list.dup
      return
    end
    @species_list = @assigned_list.sort_by do |sp|
      base_species, form = NuevaPokedex.entry_base_and_form(sp)
      sd = (GameData::Species.get_species_form(base_species, form) rescue nil)
      sd ||= GameData::Species.try_get(base_species)
      case sort_mode
      when :NAME
        [sd ? sd.name.downcase : sp.to_s.downcase, form]
      when :WEIGHT_DESC
        [-(sd ? sd.weight : 0), form]
      when :WEIGHT_ASC
        [sd ? sd.weight : 0, form]
      when :HEIGHT_DESC
        [-(sd ? sd.height : 0), form]
      else
        [sd ? sd.height : 0, form]
      end
    end
  end

  def clear_cache_except(current_index)
    keep = [current_index - 1, current_index, current_index + 1]
    @cache.each_key do |k|
      @cache.delete(k) if !keep.include?(k)
    end
  end
end

#===============================================================================
# Type Colors
#===============================================================================
module NuevaPokedexTypeColors
  TYPE_COLORS = {
    :NORMAL   => Color.new(168, 168, 120, 220),
    :FIRE     => Color.new(238, 108, 84, 220),
    :FIGHTING => Color.new(185, 52, 52, 220),
    :WATER    => Color.new(96, 140, 220, 220),
    :FLYING   => Color.new(185, 176, 232, 220),
    :GRASS    => Color.new(112, 200, 104, 220),
    :POISON   => Color.new(184, 96, 160, 220),
    :ELECTRIC => Color.new(248, 208, 72, 220),
    :GROUND   => Color.new(208, 176, 112, 220),
    :PSYCHIC  => Color.new(248, 128, 192, 220),
    :ROCK     => Color.new(192, 184, 120, 220),
    :ICE      => Color.new(176, 224, 232, 220),
    :BUG      => Color.new(176, 184, 64, 220),
    :DRAGON   => Color.new(152, 68, 224, 220),
    :GHOST    => Color.new(128, 92, 176, 220),
    :DARK     => Color.new(144, 108, 72, 220),
    :STEEL    => Color.new(192, 192, 208, 220),
    :FAIRY    => Color.new(248, 168, 216, 220)
  }

  module_function

  def color_for(type_id)
    type_data = GameData::Type.try_get(type_id)
    key = type_data&.id || type_id
    return TYPE_COLORS[key] || TYPE_COLORS[:NORMAL]
  end
end

#===============================================================================
# Word Wrap
#===============================================================================
module NuevaPokedexWordWrap
  module_function

  def wrap_text(bitmap, text, width, line_height = 20)
    words = text.to_s.split(/\s+/)
    lines = []
    current = ""
    words.each do |word|
      test = current.empty? ? word : "#{current} #{word}"
      if bitmap.text_size(test).width > width
        lines.push(current) if !current.empty?
        current = word
      else
        current = test
      end
    end
    lines.push(current) if !current.empty?
    return lines, (lines.length * line_height)
  end
end

#===============================================================================
# Vista: UI Procedural
# Usa un único bitmap maestro (bg_bmp) para UI estática y un overlay separado
# para contenido dinámico. El sprite del Pokémon es el único sprite adicional.
#===============================================================================
class NuevaPokedexView
  attr_reader :sprites, :bitmaps, :skin

  def initialize(viewport)
    @viewport = viewport
    @sprites = {}
    @bitmaps = {}
    @skin = VermeilPokedexSkin.new(NewPokedexConfig::CONFIG[:use_custom_ui])
    create_sprites
  end

  def create_sprites
    # Master bitmap (static UI)
    @sprites["master"] = Sprite.new(@viewport)
    @bitmaps["master"] = Bitmap.new(NuevaPokedex::SCREEN_WIDTH, NuevaPokedex::SCREEN_HEIGHT)
    @sprites["master"].bitmap = @bitmaps["master"]

    # Overlay bitmap (dynamic UI)
    @sprites["overlay"] = Sprite.new(@viewport)
    @bitmaps["overlay"] = Bitmap.new(NuevaPokedex::SCREEN_WIDTH, NuevaPokedex::SCREEN_HEIGHT)
    @sprites["overlay"].bitmap = @bitmaps["overlay"]
    @sprites["overlay"].z = 1

    # List window
    @sprites["list"] = Sprite.new(@viewport)
    @bitmaps["list"] = Bitmap.new(NuevaPokedex::LIST_WINDOW_W, NuevaPokedex::LIST_WINDOW_H)
    @sprites["list"].bitmap = @bitmaps["list"]
    @sprites["list"].x = NuevaPokedex::LIST_WINDOW_X
    @sprites["list"].y = NuevaPokedex::LIST_WINDOW_Y
    @sprites["list"].z = 1

    # Scrollbar
    @sprites["scrollbar"] = Sprite.new(@viewport)
    @bitmaps["scrollbar"] = Bitmap.new(NuevaPokedex::SCROLLBAR_W, NuevaPokedex::SCROLLBAR_H)
    @sprites["scrollbar"].bitmap = @bitmaps["scrollbar"]
    @sprites["scrollbar"].x = NuevaPokedex::SCROLLBAR_X
    @sprites["scrollbar"].y = NuevaPokedex::SCROLLBAR_Y
    @sprites["scrollbar"].z = 2

    # Pokémon icon sprite
    @sprites["icon"] = PokemonSprite.new(@viewport)
    @sprites["icon"].x = NuevaPokedex::SPRITE_X
    @sprites["icon"].y = NuevaPokedex::SPRITE_Y
    @sprites["icon"].z = 3

    # Sprite background (for type coloring)
    @sprites["sprite_bg"] = Sprite.new(@viewport)
    @bitmaps["sprite_bg"] = Bitmap.new(NuevaPokedex::SPRITE_BG_W, NuevaPokedex::SPRITE_BG_H)
    @sprites["sprite_bg"].bitmap = @bitmaps["sprite_bg"]
    @sprites["sprite_bg"].x = NuevaPokedex::SPRITE_BG_X
    @sprites["sprite_bg"].y = NuevaPokedex::SPRITE_BG_Y
    @sprites["sprite_bg"].z = 2


  end

  def draw_background(bmp)
    bg_path = NewPokedexConfig::CONFIG[:background_image]
    return if bg_path.nil? || bg_path.empty?
    full_path = File.join('Graphics', 'UI', bg_path)
    if File.file?(full_path)
      begin
        bg_bitmap = Bitmap.new(full_path)
        bmp.blt(0, 0, bg_bitmap, bg_bitmap.rect)
        bg_bitmap.dispose
      rescue StandardError
        # Silently ignore if loading fails
      end
    end
  end

  # Optional quick‑search bar (shown when config flag is true)
  def draw_search_bar(bmp)
    bar_x = NuevaPokedex::HEADER_X
    bar_y = NuevaPokedex::HEADER_Y + NuevaPokedex::HEADER_H + 4
    bar_w = NuevaPokedex::HEADER_W
    bar_h = 24
    bmp.fill_rect(bar_x, bar_y, bar_w, bar_h, Color.new(30, 30, 40, 200))
    pbDrawShadowText(bmp, bar_x + 8, bar_y + 4, bar_w - 16, bar_h,
      NuevaPokedex.t("Buscar..."), Color.new(200, 200, 210), Color.new(0, 0, 0))
  end


  def clear_bitmap(key)
    @bitmaps[key].clear if @bitmaps[key] && !@bitmaps[key].disposed?
  end

  def pbUpdate
    @sprites.each_value do |spr|
      next if !spr || pbDisposed?(spr)
      spr.update if spr.respond_to?(:update)
    end
  end

  def dispose
    pbDisposeSpriteHash(@sprites)
    @bitmaps.each_value { |b| b.dispose if b && !b.disposed? }
    @skin.dispose if @skin
  end

  def set_sprite_color(type1)
    type_color = NuevaPokedexTypeColors.color_for(type1)
    bg = @bitmaps["sprite_bg"]
    bg.clear
    bg.fill_rect(0, 0, NuevaPokedex::SPRITE_BG_W, NuevaPokedex::SPRITE_BG_H, type_color)
    inner = Color.new(type_color.red, type_color.green, type_color.blue, 40)
    bg.fill_rect(8, 8, NuevaPokedex::SPRITE_BG_W - 16, NuevaPokedex::SPRITE_BG_H - 16, inner)
    border = Color.new(type_color.red, type_color.green, type_color.blue, 200)
    bg.fill_rect(0, 0, NuevaPokedex::SPRITE_BG_W, 4, border)
    bg.fill_rect(0, NuevaPokedex::SPRITE_BG_H - 4, NuevaPokedex::SPRITE_BG_W, 4, border)
    bg.fill_rect(0, 0, 4, NuevaPokedex::SPRITE_BG_H, border)
    bg.fill_rect(NuevaPokedex::SPRITE_BG_W - 4, 0, 4, NuevaPokedex::SPRITE_BG_H, border)
    @skin.draw(bg, :portrait_panel, 0, 0) if @skin
  end
end

#===============================================================================
# Scene: Pokédex MVC
#===============================================================================
class PokemonPokedexNueva_Scene
  attr_accessor :index

  def initialize(region = 0)
    @region = region
    @state = NuevaPokedex::STATE_LIST
    @view = nil
    @model = NuevaPokedexData.new(region)
    @current_index = 0
    @current_form = 0
    persisted = ($PokemonGlobal.instance_variable_get(:@vermeil_pokedex_forms) rescue nil)
    @selected_forms = persisted.is_a?(Hash) && persisted[@region].is_a?(Hash) ?
                      persisted[@region].dup : {}
    @scroll_offset = 0.0
    @target_scroll = 0.0
    @shiny_modes = {}   # solo por slot de la Pokédex
    @last_encounter_version = ($PokemonGlobal && $PokemonGlobal.encounter_version) || 0
    @anim_timer = 0
    @bounce_scale_y = 1.0
    @panel_alpha = 255
    @panel_x = 0.0
    @page = 0
  end

  def pbUpdate
    @view&.pbUpdate
    update_animation
  end

  def update_animation
    @scroll_offset += (@target_scroll - @scroll_offset) * 0.2
    @scroll_offset = @target_scroll if (@scroll_offset - @target_scroll).abs < 0.5
    if @bounce_scale_y < 1.0
      @bounce_scale_y += (1.0 - @bounce_scale_y) * 0.15
    end
    if @panel_alpha < 255
      @panel_alpha += (255 - @panel_alpha) * 0.18
      if (@panel_alpha - 255).abs < 2
        @panel_alpha = 255
      end
    end
    if @panel_x > 0
      @panel_x += (0 - @panel_x) * 0.15
      @panel_x = 0.0 if @panel_x < 0.5
    end
    if @view
      # El maestro nunca se desvanece: overlay entra con fade+slide.
      # El sprite y su caja comparten el mismo desplazamiento/opacidad que la
      # página para que el hueco y el Pokémon se muevan como una sola pieza.
      moving = (@panel_x > 0 || @panel_alpha < 255)
      offset = moving ? @panel_x.round : 0
      alpha  = moving ? @panel_alpha : 255
      @view.sprites["master"].opacity = 255
      overlay = @view.sprites["overlay"]
      overlay.opacity = @panel_alpha
      overlay.x = @panel_x.round
      icon = @view.sprites["icon"]
      sprite_bg = @view.sprites["sprite_bg"]
      icon.x = NuevaPokedex::SPRITE_X + offset
      icon.opacity = alpha
      sprite_bg.x = NuevaPokedex::SPRITE_BG_X + offset
      sprite_bg.opacity = alpha
    end
    @anim_timer -= 1 if @anim_timer > 0
  end


  def start_bounce
    @bounce_scale_y = 0.7
  end

  def start_crossfade
    @panel_alpha = 0
    @panel_x = 48.0
  end

  def pbStartScene
    @viewport = Viewport.new(0, 0, NuevaPokedex::SCREEN_WIDTH, NuevaPokedex::SCREEN_HEIGHT)
    @viewport.z = 99999
    @view = NuevaPokedexView.new(@viewport)
    draw_static_ui
    pbFadeInAndShow(@view.sprites)
    pbRefresh
  end

  def pbEndScene
    pbFadeOutAndHide(@view.sprites)
    @view.dispose
    @viewport.dispose
  end

  # === Dibujo UI ===

  def draw_static_ui
    bmp = @view.bitmaps["master"]
    bmp.clear
    @view.draw_background(bmp)
    # Fondo degradado vertical
    top_c = NuevaPokedex::COLOR_BG
    bottom_c = Color.new(16, 16, 24, 255)
    24.times do |seg|
      t = seg / 24.0
      r = (top_c.red + (bottom_c.red - top_c.red) * t).to_i
      g = (top_c.green + (bottom_c.green - top_c.green) * t).to_i
      bl = (top_c.blue + (bottom_c.blue - top_c.blue) * t).to_i
      y0 = (NuevaPokedex::SCREEN_HEIGHT * seg / 24)
      y1 = (NuevaPokedex::SCREEN_HEIGHT * (seg + 1) / 24)
      bmp.fill_rect(0, y0, NuevaPokedex::SCREEN_WIDTH, y1 - y0, Color.new(r, g, bl, 255))
    end
    # La ilustración opcional sustituye el fondo, sin cubrir textos ni sprites.
    @view.skin.draw(bmp, :background, 0, 0)
    # Acentos
    bmp.fill_rect(0, 0, 4, NuevaPokedex::SCREEN_HEIGHT, NuevaPokedex::COLOR_ACCENT)
    bmp.fill_rect(0, NuevaPokedex::SCREEN_HEIGHT - 4, NuevaPokedex::SCREEN_WIDTH, 4, NuevaPokedex::COLOR_PANEL_DARK)

# Header panel (top-left) - use placeholder if enabled
unless @view.skin.draw(bmp, :header, NuevaPokedex::HEADER_X, NuevaPokedex::HEADER_Y)
  bmp.fill_rect(NuevaPokedex::HEADER_X, NuevaPokedex::HEADER_Y, NuevaPokedex::HEADER_W, NuevaPokedex::HEADER_H, NuevaPokedex::COLOR_PANEL)
  bmp.fill_rect(NuevaPokedex::HEADER_X, NuevaPokedex::HEADER_Y + 40, NuevaPokedex::HEADER_W, 4, NuevaPokedex::COLOR_ACCENT)
end
    pbDrawShadowText(bmp, NuevaPokedex::HEADER_X + 8, NuevaPokedex::HEADER_Y + 4, 240, 18,
                     NuevaPokedex.dex_name_for(@region),
                     NuevaPokedex::COLOR_ACCENT, Color.new(0, 0, 0))
    # Show quick‑search bar only when multiple dexes are enabled and config permits
    if NewPokedexConfig::CONFIG[:show_search_bar] && NuevaPokedex.enabled_dexes.size > 1
      draw_search_bar(bmp)
    end

    # Counters panel (bottom-left)
    unless @view.skin.draw(bmp, :counter_panel, NuevaPokedex::COUNT_X, NuevaPokedex::COUNT_Y)
      bmp.fill_rect(NuevaPokedex::COUNT_X, NuevaPokedex::COUNT_Y, NuevaPokedex::COUNT_W, 48, NuevaPokedex::COLOR_PANEL)
      bmp.fill_rect(NuevaPokedex::COUNT_X, NuevaPokedex::COUNT_Y, 3, 48, NuevaPokedex::COLOR_ACCENT)
    end

    # List background
    unless @view.skin.draw(bmp, :list_panel, NuevaPokedex::LIST_WINDOW_X, NuevaPokedex::LIST_WINDOW_Y)
      bmp.fill_rect(NuevaPokedex::LIST_WINDOW_X, NuevaPokedex::LIST_WINDOW_Y, NuevaPokedex::LIST_WINDOW_W, NuevaPokedex::LIST_WINDOW_H, NuevaPokedex::COLOR_PANEL)
      bmp.fill_rect(NuevaPokedex::LIST_WINDOW_X, NuevaPokedex::LIST_WINDOW_Y, NuevaPokedex::LIST_WINDOW_W, 2, NuevaPokedex::COLOR_PANEL_DARK)
    end

    # Scrollbar track
    bmp.fill_rect(NuevaPokedex::SCROLLBAR_X, NuevaPokedex::SCROLLBAR_Y, NuevaPokedex::SCROLLBAR_W, NuevaPokedex::SCROLLBAR_H, Color.new(50, 50, 60, 160))
    draw_counters
    # Leyenda dinámica fuera del panel de la lista: no se hornea en el PNG.
    pbDrawShadowText(bmp, 24, 453, 592, 18,
      NuevaPokedex.t("Flechas: explorar  ·  C: ficha  ·  D: ordenar  ·  Z: buscar  ·  X: salir"),
      NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
  end

  def draw_counters
    cnt_bmp = @view.bitmaps["master"]
    # Borrar las cifras anteriores antes de un nuevo refresco.
    cnt_bmp.clear_rect(NuevaPokedex::COUNT_X, NuevaPokedex::COUNT_Y, NuevaPokedex::COUNT_W, 48)
    unless @view.skin.draw(cnt_bmp, :counter_panel, NuevaPokedex::COUNT_X, NuevaPokedex::COUNT_Y)
      cnt_bmp.fill_rect(NuevaPokedex::COUNT_X, NuevaPokedex::COUNT_Y, NuevaPokedex::COUNT_W, 48, NuevaPokedex::COLOR_PANEL)
      cnt_bmp.fill_rect(NuevaPokedex::COUNT_X, NuevaPokedex::COUNT_Y, 3, 48, NuevaPokedex::COLOR_ACCENT)
    end
    total = @model.species_count
    seen = 0
    owned = 0
    total.times do |i|
      sp = @model.species_at(i)
      seen += 1 if NuevaPokedex.slot_seen?(sp)
      owned += 1 if NuevaPokedex.slot_owned?(sp)
    end
    pbDrawShadowText(cnt_bmp, NuevaPokedex::COUNT_X + 8, NuevaPokedex::COUNT_Y + 4, 240, 18,
                     NuevaPokedex.t("VISTOS: {1}/{2}", seen, total),
                     NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
    pbDrawShadowText(cnt_bmp, NuevaPokedex::COUNT_X + 8, NuevaPokedex::COUNT_Y + 24, 240, 18,
                     NuevaPokedex.t("OBTENIDOS: {1}/{2}", owned, total),
                     NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
  end

  def draw_list
    list_bmp = @view.bitmaps["list"]
    list_bmp.clear
    total = @model.species_count
    return if total == 0
    visible_slots = NuevaPokedex::VISIBLE_SLOTS
    top = @scroll_offset.to_i
    bottom = [top + visible_slots, total].min
    slot_h = NuevaPokedex::SLOT_HEIGHT
    spacing = NuevaPokedex::SLOT_SPACING
    y_offset = 20
    # Cabecera: total de la dex
    list_bmp.fill_rect(0, 0, NuevaPokedex::LIST_WINDOW_W, 16, NuevaPokedex::COLOR_PANEL)
    pbDrawShadowText(list_bmp, 6, 0, 320, 16, NuevaPokedex.t("POKÉDEX · {1}", total),
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    (top...bottom).each_with_index do |i, row|
      entry = @model.data_for(i)
      next if !entry
      y = y_offset + row * (slot_h + spacing)
      selected = (i == @current_index)
      key = selected ? :list_row_selected : :list_row
      unless @view.skin.draw(list_bmp, key, 0, y)
        color = selected ? NuevaPokedex::COLOR_SELECT : Color.new(14, 22, 34, row.even? ? 95 : 50)
        list_bmp.fill_rect(0, y, NuevaPokedex::LIST_WINDOW_W, slot_h, color)
        list_bmp.fill_rect(0, y, 3, slot_h, NuevaPokedex::COLOR_ACCENT) if selected
      end
      draw_slot(list_bmp, entry, i, y, slot_h)
    end
  end

  def draw_slot(bmp, entry, index, y, height)
    if NuevaPokedex.slot_owned?(entry[:species])
      color = NuevaPokedex::COLOR_OWNED
    elsif NuevaPokedex.slot_seen?(entry[:species])
      color = NuevaPokedex::COLOR_SEEN
    else
      color = NuevaPokedex::COLOR_UNSEEN
    end
    bmp.fill_rect(8, y + 4, 16, 16, color)
    num_text = sprintf("#%03d", entry[:number])
    pbDrawShadowText(bmp, 29, y + 4, 49, height, num_text,
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    known = NuevaPokedex.slot_seen?(entry[:species])
    name_color = known ? NuevaPokedex::COLOR_TEXT : NuevaPokedex::COLOR_TEXT_DIM
    display_name = known ? entry[:name] : "----------"
    if known && entry[:form] > 0 && NewPokedexConfig::CONFIG[:show_form_names]
      # Show form name if available; fallback to form number
      form_name = GameData::Species.get_species_form(entry[:base_species], entry[:form])&.form_name rescue nil
      if form_name && !form_name.empty?
        display_name = "#{entry[:name]} (#{form_name})"
      else
        display_name = NuevaPokedex.t("{1} (Forma {2})", entry[:name], entry[:form])
      end
    end
    # Nombre a ancho completo (sin tipos en la lista, como la Pokédex canónica)
    name_w = NuevaPokedex::LIST_WINDOW_W - 91
    if bmp.text_size(display_name).width > name_w
      short = display_name
      while short.length > 1 && bmp.text_size(short + "…").width > name_w
        short = short[0...-1]
      end
      display_name = short + "…"
    end
    pbDrawShadowText(bmp, 82, y + 4, name_w, height, display_name,
                     name_color, Color.new(0, 0, 0))
  end

  def draw_scrollbar
    sb = @view.bitmaps["scrollbar"]
    sb.clear
    total = @model.species_count
    return if total == 0
    visible = NuevaPokedex::VISIBLE_SLOTS
    track_h = NuevaPokedex::SCROLLBAR_H
    if total <= visible
      thumb_h = track_h
      thumb_y = 0
    else
      thumb_h = (track_h * visible / total.to_f).clamp(20, track_h)
      max_scroll = total - visible
      thumb_y = (@scroll_offset / max_scroll) * (track_h - thumb_h)
      thumb_y = thumb_y.clamp(0, track_h - thumb_h)
    end
    unless @view.skin.draw(sb, :scrollbar_track, 0, 0)
      sb.fill_rect(0, 0, NuevaPokedex::SCROLLBAR_W, track_h, Color.new(50, 50, 60, 160))
    end
    sb.fill_rect(0, thumb_y.round, NuevaPokedex::SCROLLBAR_W, thumb_h.round, Color.new(120, 126, 140, 200))
  end

  def collect_form_list
    entry = @model.data_for(@current_index)
    return [] unless entry
    # Si la entrada tiene un slot independiente en esta Pokédex, sus formas
    # NO son un selector: se gestionan exclusivamente mediante su propio slot.
    return [entry[:form]] if entry[:form].to_i > 0 &&
                             @model.slot_number_for(entry[:base_species], entry[:form])
    base = entry[:base_species]
    forms = [entry[:form].to_i]
    if GameData::Species.respond_to?(:each_form_for_species)
      GameData::Species.each_form_for_species(base) do |form_sp|
        next if form_sp.form.to_i <= 0
        next if form_sp.has_flag?("HideFromPokedex")
        next if @model.slot_number_for(base, form_sp.form)
        next unless NuevaPokedex.form_shown?(base, form_sp.form)
        forms << form_sp.form.to_i
      end
    end
    if defined?(GoldenSystem::Data)
      form_id = GoldenSystem::Data.form_number(base, entry[:form])
      if form_id && form_id > 0 && !@model.slot_number_for(base, form_id) &&
         GoldenSystem::Data.visible_form?(base, form_id) &&
         NuevaPokedex.form_shown?(base, form_id)
        forms << form_id
      end
    end
    # Mostrar solo las variantes descubiertas, no placeholders incomprensibles.
    forms.uniq.select { |f| f == entry[:form].to_i || NuevaPokedex.form_seen?(base, f) }
  end

  # Elección de forma visual por slot, sin alterar el número regional, los
  # avistamientos o las entradas de la base de datos del jugador.
  def selected_display_form(entry = nil)
    entry ||= @model.data_for(@current_index)
    return 0 unless entry
    return entry[:form].to_i if entry[:form].to_i > 0 &&
                                 @model.slot_number_for(entry[:base_species], entry[:form])
    form = (@selected_forms || {})[entry[:species]]
    form ||= entry[:form].to_i
    valid = form.to_i == entry[:form].to_i ||
            (form.to_i > 0 &&
             !@model.slot_number_for(entry[:base_species], form) &&
             NuevaPokedex.form_seen?(entry[:base_species], form))
    valid ? form.to_i : entry[:form].to_i
  end

  def store_display_form(entry, form)
    return unless entry
    return if entry[:form].to_i > 0 && @model.slot_number_for(entry[:base_species], entry[:form])
    return unless form.to_i == entry[:form].to_i ||
                  (!@model.slot_number_for(entry[:base_species], form) &&
                   NuevaPokedex.form_seen?(entry[:base_species], form))
    @selected_forms ||= {}
    @selected_forms[entry[:species]] = form.to_i
    # Preferencia de presentación guardada en la partida; no modifica la
    # Pokédex oficial ni los datos de avistamiento/propiedad del Pokémon.
    if defined?($PokemonGlobal) && $PokemonGlobal
      saved = $PokemonGlobal.instance_variable_get(:@vermeil_pokedex_forms)
      saved = {} unless saved.is_a?(Hash)
      saved[@region] = @selected_forms.dup
      $PokemonGlobal.instance_variable_set(:@vermeil_pokedex_forms, saved)
    end
  end

  def effective_entry(entry)
    return nil unless entry
    form = selected_display_form(entry)
    return entry if form == entry[:form].to_i
    sp = NuevaPokedex.dex_form_data(entry[:base_species], form)
    return entry unless sp
    ret = entry.dup
    ret[:form] = form
    ret[:form_name] = sp.form_name if sp.respond_to?(:form_name)
    ret[:types] = sp.types
    ret[:height] = sp.height
    ret[:weight] = sp.weight
    ret[:category] = sp.category
    ret[:description] = sp.pokedex_entry
    ret
  end

  def shiny_mode_for(entry = nil)
    entry ||= @model.data_for(@current_index)
    return 0 unless entry
    (@shiny_modes || {})[entry[:species]] || 0
  end

  def cycle_selected_shiny
    entry = @model.data_for(@current_index)
    return unless entry && NuevaPokedex.slot_seen?(entry[:species])
    maximum = if NewPokedexConfig::CONFIG[:use_supershiny_toggle]
                3
              elsif NewPokedexConfig::CONFIG[:use_shiny_toggle]
                2
              else
                1
              end
    @shiny_modes[entry[:species]] = (shiny_mode_for(entry) + 1) % maximum
    pbPlayCursorSE if defined?(pbPlayCursorSE)
    update_sprite_icon
    draw_forms if @state == NuevaPokedex::STATE_FORMS
    draw_info if @state == NuevaPokedex::STATE_INFO
    pbRefresh if @state == NuevaPokedex::STATE_LIST
  end

  def draw_shiny_status(bmp, x, y)
    entry = @model.data_for(@current_index)
    return unless entry && NuevaPokedex.slot_seen?(entry[:species])
    label = case shiny_mode_for(entry)
            when 1 then NuevaPokedex.t("Shiny")
            when 2 then NuevaPokedex.t("Super Shiny")
            else NuevaPokedex.t("Normal")
            end
    pbDrawShadowText(bmp, x, y, 140, 19, NuevaPokedex.t("Color: {1}", label),
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
  end

  def update_sprite_icon
    entry = @model.data_for(@current_index)
    return if !entry
    form_visible = (@state != NuevaPokedex::STATE_FORMS || @current_form.to_i <= 0 ||
                     NuevaPokedex.form_seen?(entry[:base_species], @current_form))
    if NuevaPokedex.slot_seen?(entry[:species]) && form_visible
      show_species = entry[:base_species]
      show_form = @state == NuevaPokedex::STATE_FORMS ? @current_form : selected_display_form(entry)
      shiny_mode = shiny_mode_for(entry)
      @view.sprites["icon"].setSpeciesBitmap(show_species, 0, show_form,
                                             shiny_mode > 0, false, false, false, shiny_mode > 1)
      @view.sprites["icon"].visible = true
      @view.sprites["icon"].opacity = 255
      @view.sprites["icon"].zoom_y = @bounce_scale_y
      type1 = current_form_types(entry, show_form)
      @view.set_sprite_color(type1[0] || :NORMAL)
    else
      @view.sprites["icon"].visible = false
      @view.set_sprite_color(:NORMAL)
    end
  end

  def current_form_types(entry, form = nil)
    form = (@state == NuevaPokedex::STATE_FORMS ? @current_form : selected_display_form(entry)) if form.nil?
    return entry[:types] if form.nil? || form.to_i == entry[:form].to_i
    sp = NuevaPokedex.dex_form_data(entry[:base_species], form)
    sp ? sp.types : entry[:types]
  end

  def pbRefresh
    @model.clear_cache_except(@current_index)
    @target_scroll = (@current_index - NuevaPokedex::VISIBLE_SLOTS / 2).clamp(0, [@model.species_count - NuevaPokedex::VISIBLE_SLOTS, 0].max)
    @view.clear_bitmap("overlay")
    draw_list
    draw_scrollbar
    draw_counters
    update_sprite_icon
    draw_shiny_status(@view.bitmaps["sprite_bg"], 14, 226)
  end

  # === INFO STATE ===

  def draw_info
    bmp = @view.bitmaps["overlay"]
    bmp.clear
    entry = effective_entry(@model.data_for(@current_index))
    return if !entry
    # Página completa a parte: fondo opaco salvo el hueco del sprite del Pokémon
    bg = Color.new(20, 20, 30, 255)
    sx = NuevaPokedex::ENTRY_SPRITE_X
    sy = NuevaPokedex::ENTRY_SPRITE_Y
    sw = NuevaPokedex::ENTRY_SPRITE_W
    sh = NuevaPokedex::ENTRY_SPRITE_H
    bmp.fill_rect(0, 0, NuevaPokedex::SCREEN_WIDTH, sy, bg)
    bmp.fill_rect(0, sy + sh, NuevaPokedex::SCREEN_WIDTH, NuevaPokedex::SCREEN_HEIGHT - sy - sh, bg)
    bmp.fill_rect(0, sy, sx, sh, bg)
    bmp.fill_rect(sx + sw, sy, NuevaPokedex::SCREEN_WIDTH - sx - sw, sh, bg)
    @view.skin.draw(bmp, :entry_page, 0, 0)
    border_c = Color.new(20, 20, 30, 255)
    # Marco del hueco del sprite (deja el interior transparente)
    bmp.fill_rect(NuevaPokedex::ENTRY_SPRITE_X - 4, NuevaPokedex::ENTRY_SPRITE_Y - 4,
                  NuevaPokedex::ENTRY_SPRITE_W + 8, 3, NuevaPokedex::COLOR_ACCENT)
    bmp.fill_rect(NuevaPokedex::ENTRY_SPRITE_X - 4, NuevaPokedex::ENTRY_SPRITE_Y + NuevaPokedex::ENTRY_SPRITE_H + 1,
                  NuevaPokedex::ENTRY_SPRITE_W + 8, 3, NuevaPokedex::COLOR_ACCENT)
    bmp.fill_rect(NuevaPokedex::ENTRY_SPRITE_X - 4, NuevaPokedex::ENTRY_SPRITE_Y - 4, 3, NuevaPokedex::ENTRY_SPRITE_H + 8, border_c)
    bmp.fill_rect(NuevaPokedex::ENTRY_SPRITE_X + NuevaPokedex::ENTRY_SPRITE_W + 1, NuevaPokedex::ENTRY_SPRITE_Y - 4, 3,
                  NuevaPokedex::ENTRY_SPRITE_H + 8, border_c)
    # Barra superior: Nº + nombre (+ forma al lado)
    bmp.fill_rect(0, 0, NuevaPokedex::SCREEN_WIDTH, 56, NuevaPokedex::COLOR_PANEL)
    bmp.fill_rect(0, 54, NuevaPokedex::SCREEN_WIDTH, 2, NuevaPokedex::COLOR_ACCENT)
    pbDrawShadowText(bmp, 20, 3, 160, 16, NuevaPokedex.t("Nº {1}", sprintf("%03d", entry[:number])),
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    name_w = bmp.text_size(entry[:name]).width
    pbDrawShadowText(bmp, 20, 20, name_w + 8, 32, entry[:name],
                     NuevaPokedex::COLOR_ACCENT, Color.new(0, 0, 0))
    if entry[:form].to_i > 0 && entry[:form_name]
      form_x = 20 + name_w + 12
      if form_x + bmp.text_size(entry[:form_name]).width < 500
        # Forma alineada en altura con el nombre (mismo centro vertical)
        pbDrawShadowText(bmp, form_x, 25, 400, 22, entry[:form_name],
                         NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
      else
        pbDrawShadowText(bmp, 20, 42, 440, 16, entry[:form_name],
                         NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
      end
    end
    # Bola de captura (arriba a la derecha)
    owned = NuevaPokedex.slot_owned?(entry[:species])
    seen = !owned && NuevaPokedex.slot_seen?(entry[:species])
    draw_ball(bmp, 604, 30, 10, owned, seen)
    # Columna derecha de datos
    status_color = owned ? Color.new(150, 220, 150, 255) : (seen ? NuevaPokedex::COLOR_ACCENT : NuevaPokedex::COLOR_TEXT_DIM)
    status_text = owned ? NuevaPokedex.t("OBTENIDO") : (seen ? NuevaPokedex.t("VISTO") : NuevaPokedex.t("NO VISTO"))
    pbDrawShadowText(bmp, 304, 70, 300, 20, status_text, status_color, Color.new(0, 0, 0))
    pbDrawShadowText(bmp, 304, 100, 300, 20, NuevaPokedex.t("Categoría: {1}", entry[:category]),
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    draw_entry_types(bmp, entry[:types], 304, 132)
    pbDrawShadowText(bmp, 304, 178, 200, 20, NuevaPokedex.t("Altura: {1} m", entry[:height] / 10.0),
                     NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
    pbDrawShadowText(bmp, 304, 202, 200, 20, NuevaPokedex.t("Peso: {1} kg", entry[:weight] / 10.0),
                     NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
    # Ficha de descripción (ancho completo)

    pbDrawShadowText(bmp, 24, NuevaPokedex::ENTRY_DESC_Y - 22, 120, 18, NuevaPokedex.t("POKÉDEX"),
                     NuevaPokedex::COLOR_ACCENT, Color.new(0, 0, 0))
    draw_entry_description(bmp, entry[:description])
    draw_shiny_status(bmp, 461, 33)
    pbDrawShadowText(bmp, 462, 280, 150, 19, NuevaPokedex.t("D: cambiar color"),
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
  end

  def draw_ball(bmp, cx, cy, r, owned, seen)
    if !owned && !seen
      ring_c = Color.new(96, 102, 116, 255)
      inner_r = r - 3
      (r * 2).times do |dy|
        y = cy - r + dy
        off = (dy - r).abs.to_f
        next if off >= r
        out_half = Math.sqrt((r.to_f ** 2) - off * off).round
        in_half = off < inner_r ? Math.sqrt((inner_r.to_f ** 2) - off * off).round : 0
        bmp.fill_rect(cx - out_half, y, [out_half - in_half, 0].max, 1, ring_c)
        bmp.fill_rect(cx + in_half, y, [out_half - in_half, 0].max, 1, ring_c)
      end
      return
    end
    top_c = owned ? Color.new(236, 96, 84, 255) : Color.new(150, 152, 164, 255)
    bot_c = owned ? Color.new(230, 230, 240, 255) : Color.new(112, 114, 128, 255)
    (r * 2).times do |dy|
      y = cy - r + dy
      off = (dy - r).abs.to_f
      next if off >= r
      half = Math.sqrt((r.to_f ** 2) - off * off).round
      bmp.fill_rect(cx - half, y, half * 2, 1, dy < r ? top_c : bot_c)
    end
    bmp.fill_rect(cx - r, cy - 1, r * 2, 2, Color.new(46, 46, 58, 255))
    br = (r * 0.3).ceil
    btn_c = owned ? Color.new(216, 216, 226, 255) : Color.new(70, 72, 84, 255)
    (br * 2).times do |dy|
      y = cy - br + dy
      off = (dy - br).abs.to_f
      next if off >= br
      half = Math.sqrt((br.to_f ** 2) - off * off).round
      bmp.fill_rect(cx - half, y, half * 2, 1, btn_c)
    end
  end

  def draw_type_icons(bmp, types, x, y, w, h, gap = 6)
    return if types.nil? || types.empty?
    types[0, 2].each_with_index do |tid, i|
      begin
        type_number = GameData::Type.get(tid).icon_position
        src = Rect.new(0, type_number * NuevaPokedex::TYPE_ICON_H, NuevaPokedex::TYPE_ICON_W, NuevaPokedex::TYPE_ICON_H)
        sheet = NuevaPokedex.type_icons.bitmap
        raise "Missing type badge" if sheet.width < 64 || sheet.height < (type_number + 1) * 28
        bmp.stretch_blt(Rect.new(x + i * (w + gap), y, w, h), sheet, src)
      rescue StandardError
        draw_type_rect(bmp, tid, x + i * (w + gap), y, w, h)
      end
    end
  end

  # Mismo Graphics/UI/types.png que la Libreta, también en las fichas.
  def draw_entry_types(bmp, types, x, y)
    draw_type_icons(bmp, types, x, y, 80, 35, 8)
  end

  def draw_panel(bmp, x, y, w, h)
    bmp.fill_rect(x, y, w, h, NuevaPokedex::COLOR_PANEL_DARK)
    bmp.fill_rect(x, y, w, 3, NuevaPokedex::COLOR_ACCENT)
    bmp.fill_rect(x, y + h - 3, w, 3, Color.new(30, 30, 42, 220))
  end

  def draw_type_rect(bmp, type_id, x, y, w, h)
    color = NuevaPokedexTypeColors.color_for(type_id)
    bmp.fill_rect(x, y, w, h, color)
    bmp.fill_rect(x, y, w, 4, Color.new(color.red, color.green, color.blue, 200))
    type_data = GameData::Type.try_get(type_id)
    type_name = type_data ? type_data.name : "?"
    pbDrawShadowText(bmp, x + 8, y + 4, w - 16, 16, type_name,
                     Color.new(248, 248, 248), Color.new(0, 0, 0), 1)
  end

  def draw_entry_description(bmp, text)
    text_w = NuevaPokedex::ENTRY_DESC_W - 16
    tmp = Bitmap.new(text_w, 20)
    lines, _ = NuevaPokedexWordWrap.wrap_text(tmp, text, text_w, 20)
    tmp.dispose
    lines_per_page = 4
    total_pages = [(lines.length.to_f / lines_per_page).ceil, 1].max
    page_lines = lines.slice(@page * lines_per_page, lines_per_page) || []
    page_lines.each_with_index do |line, i|
      pbDrawShadowText(bmp, 28, NuevaPokedex::ENTRY_DESC_Y + 12 + i * 20,
                       text_w, 20, line,
                       NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
    end
    if total_pages > 1
      pg = NuevaPokedex.t("{1}/{2}", @page + 1, total_pages)
      pbDrawShadowText(bmp, 24 + 8, NuevaPokedex::ENTRY_DESC_Y + NuevaPokedex::ENTRY_DESC_H - 16,
                       200, 16, pg, NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    end
  end

  # === AREA STATE ===

  def draw_area
    bmp = @view.bitmaps["overlay"]
    bmp.clear
    # Fondo opaco completo: nada del master (header "Pokédex Payu", lista) se transparenta
    bmp.fill_rect(0, 0, NuevaPokedex::SCREEN_WIDTH, NuevaPokedex::SCREEN_HEIGHT,
                  Color.new(20, 20, 30, 255))
    # El mapa debe permanecer libre de marcos/bocetos de la skin que tapen
    # ubicaciones o contengan textos en inglés. El área ya tiene su cabecera.
    entry = @model.data_for(@current_index)
    return if !entry
    pbDrawShadowText(bmp, 20, 12, 400, 22, NuevaPokedex.t("Zona · {1}", entry[:name]),
                     NuevaPokedex::COLOR_ACCENT, Color.new(0, 0, 0))
    map_region = NuevaPokedex.dex_region_for(@region)
    mapdata = map_region ? GameData::TownMap.try_get(map_region) : nil
    map_bmp = nil
    map_asset = nil
    if mapdata && mapdata.filename
      begin
        map_asset = AnimatedBitmap.new(_INTL("Graphics/UI/Town Map/{1}", mapdata.filename))
        map_bmp = map_asset.bitmap
      rescue StandardError => e
        echoln("[Nueva Pokédex] Town Map: #{e.message}") if defined?(echoln)
        map_bmp = nil
      end
    end
    # Mostrar siempre un estado de localización, incluso si el Pokémon no
    # está en encuentros salvajes o el proyecto no tiene mapa regional.
    names = locations_for_species(entry[:base_species])
    if mapdata && map_bmp
      points = encounter_points_on_map(mapdata, entry[:base_species])
      draw_area_map(bmp, mapdata, map_bmp, points, entry)
      if !points.any? { |v| v } && names.empty?
        draw_area_unknown(bmp)
      end
    else
      draw_area_text(bmp, [], names)
    end
  ensure
    map_asset.dispose if map_asset && map_asset.respond_to?(:dispose)
  end

  # Dibuja el Town Map de la región (lógica canónica de 048_UI/005 drawPageArea):
  # mapa centrado + cuadros 16x16 en los puntos con aparición de la especie.
  def draw_area_map(bmp, mapdata, map_bmp, points, entry)
    orig_w = map_bmp.width
    orig_h = map_bmp.height
    return if orig_w <= 0 || orig_h <= 0
    max_w = NuevaPokedex::SCREEN_WIDTH
    max_h = NuevaPokedex::SCREEN_HEIGHT - 104
    scale = [(max_w > 0 ? max_w.to_f / orig_w : 1.0), (max_h > 0 ? max_h.to_f / orig_h : 1.0)].min
    scale = [scale, 1.0].min
    mw = (orig_w * scale).to_i
    mh = (orig_h * scale).to_i
    mx = (NuevaPokedex::SCREEN_WIDTH - mw) / 2
    my = (NuevaPokedex::SCREEN_HEIGHT + 22 - mh) / 2
    bmp.stretch_blt(Rect.new(mx, my, mw, mh), map_bmp, map_bmp.rect)
    town_map_width = 1 + PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT
    sq = PokemonRegionMap_Scene::SQUARE_WIDTH
    sz = (sq * scale).round
    point_c  = Color.new(0, 248, 248, 190)
    point_hl = Color.new(192, 248, 248, 230)
    (points || []).length.times do |j|
      next if !points[j]
      px = (mx + (j % town_map_width) * sq * scale).round
      py = (my + (j / town_map_width) * sq * scale).round
      bmp.fill_rect(px, py, sz, sz, point_c)
      bmp.fill_rect(px, py - 2, sz, 2, point_hl) if j - town_map_width < 0 || !points[j - town_map_width]
      bmp.fill_rect(px, py + sz, sz, 2, point_hl) if j + town_map_width >= points.length || !points[j + town_map_width]
      bmp.fill_rect(px - 2, py, 2, sz, point_hl) if j % town_map_width == 0 || !points[j - 1]
      bmp.fill_rect(px + sz, py, 2, sz, point_hl) if (j + 1) % town_map_width == 0 || !points[j + 1]
    end
    names = locations_for_species(entry[:base_species])
    draw_area_footer(bmp, mapdata.name, names, points.any? { |point| point })
  end

  def draw_area_text(bmp, _points, names)
    if names.empty?
      draw_area_unknown(bmp)
    else
      y = 60
      names.each do |loc|
        break if y > 400
        pbDrawShadowText(bmp, 24, y, 580, 20, loc,
                         NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
        y += 22
      end
    end
    draw_area_footer(bmp, nil, names, false)
  end

  def draw_area_unknown(bmp)
    # Mensaje sin ventana negra encima del mapa.
    pbDrawShadowText(bmp, 210, 217, 280, 24, NuevaPokedex.t("Área desconocida"),
                     NuevaPokedex::COLOR_TEXT, Color.new(20, 25, 34))
  end

  def draw_area_footer(bmp, map_name, names, has_points)
    footer_y = NuevaPokedex::SCREEN_HEIGHT - 40
    bmp.fill_rect(0, footer_y, NuevaPokedex::SCREEN_WIDTH, 40, NuevaPokedex::COLOR_PANEL_DARK)
    bmp.fill_rect(0, footer_y, NuevaPokedex::SCREEN_WIDTH, 2, NuevaPokedex::COLOR_ACCENT)
    if has_points
      text = names.empty? ? map_name.to_s : names.join(" · ")
      text = NuevaPokedex.t("Localizaciones: {1}", text)
    elsif names.empty?
      text = NuevaPokedex.t("Ubicación: desconocida")
    else
      text = NuevaPokedex.t("Localizaciones: {1}", names.join(" · "))
    end
    pbDrawShadowText(bmp, 16, footer_y + 10, NuevaPokedex::SCREEN_WIDTH - 32, 20, text,
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
  end

  def encounter_locations_for(species)
    return locations_for_species(species)
  end

  def locations_for_species(species)
    locations = []
    version = ($PokemonGlobal && $PokemonGlobal.encounter_version) || 0
    GameData::Encounter.each_with_species(species, version) do |data|
      meta = GameData::MapMetadata.try_get(data.map)
      next if meta && meta.has_flag?("HideEncountersInPokedex")
      loc = meta && meta.name
      loc ||= pbGetMapNameFromId(data.map) if defined?(pbGetMapNameFromId)
      next if !loc || loc.to_s.empty?
      locations << loc.to_s
    end
    locations.uniq
  rescue StandardError => e
    echoln("[Nueva Pokédex] Área #{species}: #{e.message}") if defined?(echoln)
    []
  end

  # Puntos del Town Map donde la especie aparece (misma lógica que
  # pbGetEncounterPoints de la Pokédex canónica).
  def encounter_points_on_map(mapdata, species)
    visible_points = []
    (mapdata.point || []).each do |loc|
      next if loc[7] && !$game_switches[loc[7]]
      visible_points.push([loc[0], loc[1]])
    end
    town_map_width = 1 + PokemonRegionMap_Scene::RIGHT - PokemonRegionMap_Scene::LEFT
    ret = []
    version = ($PokemonGlobal && $PokemonGlobal.encounter_version) || 0
    GameData::Encounter.each_of_version(version) do |enc_data|
      next if !encounter_has_species?(enc_data.types, species)
      map_metadata = GameData::MapMetadata.try_get(enc_data.map)
      next if !map_metadata || map_metadata.has_flag?("HideEncountersInPokedex")
      mappos = map_metadata.town_map_position
      next if !mappos || mappos[0] != mapdata.id
      map_size = map_metadata.town_map_size
      map_width = 1
      map_shape = "1"
      if map_size && map_size[0] && map_size[0] > 0
        map_width = map_size[0]
        map_shape = map_size[1]
        map_height = (map_shape.length.to_f / map_width).ceil
      else
        map_height = 1
      end
      map_width.times do |i|
        map_height.times do |j|
          next if map_shape[i + (j * map_width), 1].to_i == 0
          next if !visible_points.include?([mappos[1] + i, mappos[2] + j])
          ret[mappos[1] + i + ((mappos[2] + j) * town_map_width)] = true
        end
      end
    end
    return ret
  rescue StandardError => e
    echoln("[Nueva Pokédex] Posiciones del mapa: #{e.message}") if defined?(echoln)
    []
  end

  def encounter_has_species?(enc_types, species)
    return false if !enc_types
    enc_types.each_value do |slots|
      next if !slots
      slots.each { |slot| return true if GameData::Species.get(slot[1]).species == species }
    end
    return false
  end

  # === FORMS STATE ===

  def draw_forms
    bmp = @view.bitmaps["overlay"]
    bmp.clear
    entry = @model.data_for(@current_index)
    return if !entry
    form_ids = collect_form_list
    return if form_ids.length <= 1
    base = entry[:base_species]
    # Fondo opaco completo dejando solo transparente el hueco del sprite
    sx = NuevaPokedex::ENTRY_SPRITE_X
    sy = NuevaPokedex::ENTRY_SPRITE_Y
    sw = NuevaPokedex::ENTRY_SPRITE_W
    sh = NuevaPokedex::ENTRY_SPRITE_H
    bg = Color.new(20, 20, 30, 255)
    bmp.fill_rect(0, 0, NuevaPokedex::SCREEN_WIDTH, sy, bg)
    bmp.fill_rect(0, sy + sh, NuevaPokedex::SCREEN_WIDTH, NuevaPokedex::SCREEN_HEIGHT - sy - sh, bg)
    bmp.fill_rect(0, sy, sx, sh, bg)
    bmp.fill_rect(sx + sw, sy, NuevaPokedex::SCREEN_WIDTH - sx - sw, sh, bg)
    @view.skin.draw(bmp, :forms_page, 0, 0)
    bmp.fill_rect(sx - 4, sy - 4, sw + 8, 3, NuevaPokedex::COLOR_ACCENT)
    bmp.fill_rect(sx - 4, sy + sh + 1, sw + 8, 3, NuevaPokedex::COLOR_ACCENT)
    bmp.fill_rect(sx - 4, sy - 4, 3, sh + 8, NuevaPokedex::COLOR_ACCENT)
    bmp.fill_rect(sx + sw + 1, sy - 4, 3, sh + 8, NuevaPokedex::COLOR_ACCENT)
    # Panel derecha: lista de formas con su número de slot (si lo tienen)
    draw_panel(bmp, 318, 24, 310, 400)
    x = 330
    y = 46
    pbDrawShadowText(bmp, x, y - 24, 290, 18, NuevaPokedex.t("Formas de {1}", entry[:name]),
                     NuevaPokedex::COLOR_ACCENT, Color.new(0, 0, 0))
    selected_pos = form_ids.index(@current_form) || 0
    page_start = (selected_pos / 7) * 7
    form_ids[page_start, 7].each_with_index do |form_id, i|
      form_sp = NuevaPokedex.dex_form_data(base, form_id)
      next unless form_sp
      form_known = NuevaPokedex.form_seen?(base, form_id)
      selected = (@current_form == form_id)
      row_y = y + i * (36 + 8)
      col = selected ? Color.new(255, 255, 255, 40) : NuevaPokedex::COLOR_PANEL
      bmp.fill_rect(x, row_y, 290, 36, col)
      bmp.fill_rect(x, row_y, 4, 36, NuevaPokedex::COLOR_ACCENT) if selected
      form_name = form_id == 0 ? NuevaPokedex.t("Forma base") : form_sp.form_name.to_s
      form_name = NuevaPokedex.t("Forma {1}", form_id) if form_name.nil? || form_name.empty?
      name_c = selected ? NuevaPokedex::COLOR_TEXT : Color.new(190, 190, 190)
      pbDrawShadowText(bmp, x + 12, row_y + 8, 170, 20, form_name, name_c, Color.new(0, 0, 0))
      slot_no = @model.slot_number_for(base, form_id)
      if slot_no
        pbDrawShadowText(bmp, x + 12, row_y + 26, 90, 11, NuevaPokedex.t("Nº {1}", sprintf("%02d", slot_no)),
                         NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
      end
      draw_form_types(bmp, form_sp.types, x + 190, row_y + 6) if form_known
    end
    shiny_label = case shiny_mode_for(entry)
                  when 0 then NuevaPokedex.t("Normal")
                  when 1 then NuevaPokedex.t("Shiny")
                  else        NuevaPokedex.t("Super Shiny")
                  end
    pbDrawShadowText(bmp, x, y + 7 * 44 + 6, 290, 20,
                     NuevaPokedex.t("Color: {1} · Z: cambiar", shiny_label),
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    if form_ids.length > 7
      pbDrawShadowText(bmp, x + 220, y - 24, 70, 18,
                       "#{page_start + 1}-#{[page_start + 7, form_ids.length].min}/#{form_ids.length}",
                       NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    end
    # Panel izquierda-abajo: datos de la forma seleccionada
    draw_forms_detail(bmp, entry, form_ids)
  end

  def draw_forms_detail(bmp, entry, form_ids)
    form_id = @current_form
    return if !form_ids.include?(form_id)
    form_sp = NuevaPokedex.dex_form_data(entry[:base_species], form_id)
    return if !form_sp
    return unless NuevaPokedex.form_seen?(entry[:base_species], form_id)
    px = 24
    py = 318
    pw = 262
    ph = 138
    draw_panel(bmp, px, py, pw, ph)
    slot_no = @model.slot_number_for(entry[:base_species], form_id)
    name_txt = form_sp.name.to_s
    if form_id.to_i > 0
      fname = form_sp.form_name.to_s
      fname = NuevaPokedex.t("Forma {1}", form_id) if fname.empty?
      name_txt = NuevaPokedex.t("{1} ({2})", name_txt, fname)
    end
    pbDrawShadowText(bmp, px + 10, py + 6, pw - 92, 18, name_txt,
                     NuevaPokedex::COLOR_ACCENT, Color.new(0, 0, 0))
    if slot_no
      pbDrawShadowText(bmp, px + pw - 78, py + 6, 68, 18, NuevaPokedex.t("Nº {1}", sprintf("%03d", slot_no)),
                       NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    else
      pbDrawShadowText(bmp, px + pw - 78, py + 6, 68, 18, NuevaPokedex.t("Forma"),
                       NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    end
    draw_type_icons(bmp, form_sp.types, px + 10, py + 28, 52, 22, 6)
    pbDrawShadowText(bmp, px + 10, py + 56, pw - 20, 16, NuevaPokedex.t("Categoría: {1}", form_sp.category),
                     NuevaPokedex::COLOR_TEXT_DIM, Color.new(0, 0, 0))
    pbDrawShadowText(bmp, px + 10, py + 76, pw - 20, 16,
                     NuevaPokedex.t("Altura: {1} m", form_sp.height / 10.0) + "   " +
                     NuevaPokedex.t("Peso: {1} kg", form_sp.weight / 10.0),
                     NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
    text_w = pw - 20
    tmp = Bitmap.new(text_w, 18)
    lines, = NuevaPokedexWordWrap.wrap_text(tmp, form_sp.pokedex_entry.to_s, text_w, 18)
    tmp.dispose
    lines[0, 2].each_with_index do |line, i|
      pbDrawShadowText(bmp, px + 10, py + 96 + i * 17, text_w, 16, line,
                       NuevaPokedex::COLOR_TEXT, Color.new(0, 0, 0))
    end
  end

  def draw_form_types(bmp, types, x, y)
    draw_type_icons(bmp, types, x, y, 44, 19, 6)
  end

  # === Main Loop ===

  def pbPokedex
    loop do
      Graphics.update
      Input.update
      pbUpdate
      case @state
      when NuevaPokedex::STATE_LIST
        if (@scroll_offset - @target_scroll).abs > 0.5
          draw_list
          draw_scrollbar
        end
        result = handle_list_input
        break if result == :exit
      when NuevaPokedex::STATE_INFO
        handle_info_input
      when NuevaPokedex::STATE_AREA
        handle_area_input
      when NuevaPokedex::STATE_FORMS
        handle_forms_input
      end
      @view.sprites["overlay"].visible = (@state != NuevaPokedex::STATE_LIST) if @view
      # Fuera del estado LIST no debe transparentarse nada del master (colisión
      # visual del header "Pokédex Payu" durante el crossfade). El overlay es
      # opaco y cubre toda la pantalla: el master solo se ve de vuelta en la lista.
      if @view
        in_list = (@state == NuevaPokedex::STATE_LIST)
        @view.sprites["master"].visible = in_list
        @view.sprites["list"].visible = in_list
        @view.sprites["scrollbar"].visible = in_list
        @view.sprites["sprite_bg"].visible = (@state != NuevaPokedex::STATE_AREA)
        @view.sprites["icon"].visible = false if @state == NuevaPokedex::STATE_AREA
      end
    end
  end

  def handle_list_input
    max_index = @model.species_count - 1
    if max_index < 0
      return :exit if Input.trigger?(Input::BACK)
      return :continue
    end
    old_index = @current_index
    if Input.repeat?(Input::DOWN)
      @current_index = (@current_index + 1).clamp(0, max_index)
    elsif Input.repeat?(Input::UP)
      @current_index = (@current_index - 1).clamp(0, max_index)
    elsif Input.repeat?(Input::RIGHT)
      @current_index = (@current_index + 5).clamp(0, max_index)
    elsif Input.repeat?(Input::LEFT)
      @current_index = (@current_index - 5).clamp(0, max_index)
    end
    if @current_index != old_index
      pbPlayCursorSE if defined?(pbPlayCursorSE)
      @target_scroll = (@current_index - NuevaPokedex::VISIBLE_SLOTS / 2).clamp(0, [@model.species_count - NuevaPokedex::VISIBLE_SLOTS, 0].max)
      @model.clear_cache_except(@current_index)
      pbRefresh
      start_bounce
      start_crossfade
    end
    if Input.trigger?(Input::BACK)
      pbSEPlay("GUI pokedex cancel")
      return :exit
    elsif Input.trigger?(Input::USE)
      if NuevaPokedex.slot_seen?(@model.species_at(@current_index))
        pbSEPlay("GUI pokedex open")
        @state = NuevaPokedex::STATE_INFO
        @page = 0
        @view.clear_bitmap("overlay")
        draw_info
        start_crossfade
        play_cry
      end
    elsif Input.trigger?(Input::SPECIAL)
      pbDexSearchMode
    elsif Input.trigger?(Input::ACTION)
      search_species
    end
    return :continue
  end

  def handle_info_input
    if Input.trigger?(Input::BACK)
      pbSEPlay("GUI pokedex cancel")
      @state = NuevaPokedex::STATE_LIST
      @view.clear_bitmap("overlay")
      pbRefresh
      start_crossfade
    elsif Input.repeat?(Input::UP)
      change_entry(-1)
    elsif Input.repeat?(Input::DOWN)
      change_entry(1)
    elsif Input.trigger?(Input::LEFT)
      enter_area_state
    elsif Input.trigger?(Input::RIGHT)
      if collect_form_list.length > 1
        enter_forms_state
      else
        enter_area_state
      end
    elsif Input.trigger?(Input::USE)
      entry = @model.data_for(@current_index)
      return if !entry
      if @page + 1 < description_pages(entry)
        @page += 1
        draw_info
        start_crossfade
      elsif collect_form_list.length > 1
        enter_forms_state
      else
        pbSEPlay("GUI pokedex cancel")
        @state = NuevaPokedex::STATE_LIST
        @view.clear_bitmap("overlay")
        pbRefresh
      end
    elsif Input.trigger?(Input::ACTION)
      play_cry
    elsif Input.trigger?(Input::SPECIAL)
      cycle_selected_shiny
    end
  end

  def enter_area_state
    pbSEPlay("GUI pokedex open")
    @state = NuevaPokedex::STATE_AREA
    @view.clear_bitmap("overlay")
    @view.sprites["icon"].visible = false if @view && @view.sprites["icon"]
    @view.sprites["sprite_bg"].visible = false if @view && @view.sprites["sprite_bg"]
    draw_area
    start_crossfade
  end

  def enter_forms_state
    entry = @model.data_for(@current_index)
    return enter_area_state if !entry || collect_form_list.length <= 1
    @current_form = selected_display_form(entry)
    pbSEPlay("GUI pokedex open")
    @state = NuevaPokedex::STATE_FORMS
    @view.clear_bitmap("overlay")
    draw_forms
    update_sprite_icon
    start_crossfade
  end

  def back_to_info_state
    if @state == NuevaPokedex::STATE_FORMS
      store_display_form(@model.data_for(@current_index), @current_form)
    end
    pbSEPlay("GUI pokedex cancel")
    @state = NuevaPokedex::STATE_INFO
    @view.sprites["sprite_bg"].visible = true if @view && @view.sprites["sprite_bg"]
    @view.clear_bitmap("overlay")
    draw_info
    update_sprite_icon if @state == NuevaPokedex::STATE_INFO
    start_crossfade
  end

  def change_entry(dir)
    max_index = @model.species_count - 1
    next_index = @current_index
    loop do
      next_index += dir
      return if next_index < 0 || next_index > max_index
      break if NuevaPokedex.slot_seen?(@model.species_at(next_index))
    end
    @current_index = next_index
    @page = 0
    pbRefresh
    draw_info
    start_bounce
    start_crossfade
    play_cry
  end

  def description_pages(entry)
    text_w = NuevaPokedex::ENTRY_DESC_W - 16
    tmp = Bitmap.new(text_w, 20)
    lines, _ = NuevaPokedexWordWrap.wrap_text(tmp, entry[:description], text_w, 20)
    tmp.dispose
    lines_per_page = 4
    return [(lines.length.to_f / lines_per_page).ceil, 1].max
  end

  def handle_area_input
    if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
      back_to_info_state
    elsif Input.trigger?(Input::LEFT)
      back_to_info_state
    elsif Input.trigger?(Input::RIGHT)
      if collect_form_list.length > 1
        enter_forms_state
      else
        back_to_info_state
      end
    end
  end

  def handle_forms_input
    if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
      back_to_info_state
    elsif Input.trigger?(Input::LEFT)
      store_display_form(@model.data_for(@current_index), @current_form)
      enter_area_state
    elsif Input.trigger?(Input::RIGHT)
      back_to_info_state
    elsif Input.repeat?(Input::UP)
      forms = collect_form_list
      return if forms.empty?
      @current_form = forms[((forms.index(@current_form) || 0) - 1) % forms.length]
      store_display_form(@model.data_for(@current_index), @current_form)
      pbPlayCursorSE if defined?(pbPlayCursorSE)
      draw_forms
      update_sprite_icon
    elsif Input.repeat?(Input::DOWN)
      forms = collect_form_list
      return if forms.empty?
      @current_form = forms[((forms.index(@current_form) || -1) + 1) % forms.length]
      store_display_form(@model.data_for(@current_index), @current_form)
      pbPlayCursorSE if defined?(pbPlayCursorSE)
      draw_forms
      update_sprite_icon
    elsif Input.trigger?(Input::ACTION)
      cycle_selected_shiny
      start_bounce
    elsif Input.trigger?(Input::SPECIAL)
      play_cry
    end
  end

  def play_cry
    entry = @model.data_for(@current_index)
    return if !entry
    begin
      form = @state == NuevaPokedex::STATE_FORMS ? @current_form : selected_display_form(entry)
      Pokemon.play_cry(entry[:base_species], form)
    rescue StandardError
    end
    # Sin efecto visual rectangular al reproducir el grito.
  end

  def search_species
    # Respetar el descubrimiento. No se puede localizar por nombre una entrada
    # todavía oculta, aunque figure en el JSON.
    query = pbEnterText(NuevaPokedex.t("Buscar Pokémon visto:"), 1, 22, "").to_s.strip.downcase
    return if query.empty?
    matches = (0...@model.species_count).select do |index|
      slot = @model.species_at(index)
      next false unless NuevaPokedex.slot_seen?(slot)
      info = @model.data_for(index)
      info && info[:name].to_s.downcase.include?(query)
    end
    if matches.empty?
      pbMessage(NuevaPokedex.t("No hay coincidencias entre tus Pokémon vistos."))
      return
    end
    target = matches.first
    @current_index = target
    @page = 0
    @scroll_offset = (@current_index - NuevaPokedex::VISIBLE_SLOTS / 2).clamp(0, [@model.species_count - NuevaPokedex::VISIBLE_SLOTS, 0].max)
    @target_scroll = @scroll_offset
    pbRefresh
  end

  def pbDexSearchMode
    # SORT real: reordena la lista del modelo (el "search" de la libreta no era útil)
    commands = [NuevaPokedex.t("Orden numérico"), NuevaPokedex.t("Nombre A-Z"),
                NuevaPokedex.t("Más pesado"), NuevaPokedex.t("Más liviano"),
                NuevaPokedex.t("Más alto"), NuevaPokedex.t("Más bajo")]
    sorts = [:NUM, :NAME, :WEIGHT_DESC, :WEIGHT_ASC, :HEIGHT_DESC, :HEIGHT_ASC]
    cmd = pbShowCommands(nil, commands, 0)
    return if cmd < 0
    @model.sort = sorts[cmd]
    @current_index = 0
    @current_form = selected_display_form(@model.data_for(@current_index))
    @page = 0
    @scroll_offset = 0.0
    @target_scroll = 0.0
    pbRefresh
    start_crossfade
  end
end

class PokemonPokedexNuevaScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbPokedex
    @scene.pbEndScene
  end
end

#===============================================================================
# Integration with pause menu (dev-only toggle via Settings constant)
#===============================================================================
if defined?(MenuHandlers)
  MenuHandlers.remove(:pause_menu, :nueva_pokedex) rescue false
  MenuHandlers.add(:pause_menu, :nueva_pokedex, {
    "name"      => NuevaPokedex.t("Pokédex N"),
    "order"     => 10,
    "condition" => proc {
      next false if !NuevaPokedex.enabled?
      next $player.has_pokedex
    },
    "effect"    => proc { |menu|
      pbPlayDecisionSE if defined?(pbPlayDecisionSE)
      pbFadeOutIn do
        dex_regions = NuevaPokedex.accessible_regions
        region = dex_regions.first || 0
        scene = PokemonPokedexNueva_Scene.new(region)
        screen = PokemonPokedexNuevaScreen.new(scene)
        screen.pbStartScreen
        menu.pbRefresh if menu.respond_to?(:pbRefresh)
      end
      next false
    }
  })
end
