#########################################################
###                 Encounter list UI                 ###
### Base version + DexNav page                        ###
#########################################################

WINDOWSKIN = "base.png"
SHOW_DEXNAV_SEARCH_PANEL = false
ICONS_PER_ROW = 7
ICON_SPACING = 64
ICON_LEFT_OFFSET = 28
ICON_TOP_OFFSET = 156
ARROW_Y_DIVISOR = 16

USER_DEFINED_NAMES = {
  :Land => "Grass",
  :LandDay => "Grass (Day)",
  :LandNight => "Grass (Night)",
  :LandMorning => "Grass (Morning)",
  :LandAfternoon => "Grass (Afternoon)",
  :LandEvening => "Grass (Evening)",
  :Cave => "Cave",
  :CaveDay => "Cave (Day)",
  :CaveNight => "Cave (Night)",
  :CaveMorning => "Cave (Morning)",
  :CaveAfternoon => "Cave (Afternoon)",
  :CaveEvening => "Cave (Evening)",
  :Water => "Surfing",
  :WaterDay => "Surfing (Day)",
  :WaterNight => "Surfing (Night)",
  :WaterMorning => "Surfing (Morning)",
  :WaterAfternoon => "Surfing (Afternoon)",
  :WaterEvening => "Surfing (Evening)",
  :OldRod => "Fishing (Old Rod)",
  :GoodRod => "Fishing (Good Rod)",
  :SuperRod => "Fishing",
  :RockSmash => "Rock Smash",
  :HeadbuttLow => "Headbutt (Rare)",
  :HeadbuttHigh => "Headbutt",
  :BugContest => "Bug Contest",
  :PokeRadar => "PokéRadar",
  :HoneyTree => "Honey Tree"
}

SHOW_SHADOWS_FOR_UNSEEN_POKEMON = true
LOC_WINDOW_WIDTH = 512
LOC_WINDOW_HEIGHT = 344

EventHandlers.add(:on_wild_encounter_chance, :dexnav_prevent_encounter,
  proc { |encounter_type, chance, encounter_data|
    dexnav = pbEncounterDexNavLiteData
    # Only trigger if we have an active pending search
    if !dexnav.pending_search_active?
      next true  # Allow normal wild encounters
    end
    # Allow encounter at any location except the trigger spot
    # to prevent overlap
    coords = dexnav.pending_coords
    if coords && $game_player.x == coords[0] && $game_player.y == coords[1]
      next false  # Block wild encounter at trigger point
    end
    next true  # Allow wild encounters everywhere else
  }
)

def seen_form_any_gender?(species, _form)
  return $player.pokedex.seen?(species)
end

class EncounterDexNavLiteData
  attr_accessor :species_list
  attr_accessor :active_species
  attr_accessor :active_chain
  attr_accessor :is_grass
  attr_accessor :pin_streak
  attr_accessor :species_current_chain
  attr_accessor :species_best_chain
  attr_accessor :species_current_streak
  attr_accessor :species_best_streak
  attr_accessor :last_hunt_species
  attr_accessor :pending_species
  attr_accessor :pending_coords
  attr_accessor :pending_steps
  attr_accessor :pending_is_grass
  attr_accessor :pending_bonus

  def initialize
    @species_list = Hash.new(0)
    @active_species = nil
    @active_chain = 0
    @is_grass = true
    @pin_streak = 0
    @species_current_chain = Hash.new(0)
    @species_best_chain = Hash.new(0)
    @species_current_streak = Hash.new(0)
    @species_best_streak = Hash.new(0)
    @last_hunt_species = nil
    @pending_species = nil
    @pending_coords = nil
    @pending_steps = 0
    @pending_is_grass = true
    @pending_bonus = nil
  end

  def set_active_species(species, _max_steps = 15, is_grass = true)
    @active_species = species
    @is_grass = is_grass
    sync_legacy_active_counters
  end

  def set_inactive
    @active_species = nil
    @active_chain = 0
    @pin_streak = 0
    @last_hunt_species = nil
    clear_pending_search
  end

  def get_search_level(species = @active_species)
    ensure_species_stats!
    return 0 if species.nil?
    @species_list[species]
  end

  def get_chain_level(species = @active_species)
    return get_search_level(species)
  end

  def increase_search_level(species = @active_species)
    ensure_species_stats!
    return if species.nil?
    @species_list[species] += 1
  end

  def get_current_chain(species = @active_species)
    ensure_species_stats!
    return 0 if species.nil?
    @species_current_chain[species]
  end

  def get_best_chain(species = @active_species)
    ensure_species_stats!
    return 0 if species.nil?
    @species_best_chain[species]
  end

  def get_current_streak(species = @active_species)
    ensure_species_stats!
    return 0 if species.nil?
    @species_current_streak[species]
  end

  def get_best_streak(species = @active_species)
    ensure_species_stats!
    return 0 if species.nil?
    @species_best_streak[species]
  end

  def increase_species_progress(species = @active_species)
    ensure_species_stats!
    return if species.nil?
    increase_search_level(species)
    @species_current_chain[species] += 1
    @species_current_streak[species] += 1
    @species_best_chain[species] = [@species_best_chain[species], @species_current_chain[species]].max
    @species_best_streak[species] = [@species_best_streak[species], @species_current_streak[species]].max
    sync_legacy_active_counters
  end

  def reset_species_progress(species = @active_species)
    ensure_species_stats!
    return if species.nil?
    @species_current_chain[species] = 0
    @species_current_streak[species] = 0
    sync_legacy_active_counters
  end

  def active_chain
    ensure_species_stats!
    return get_current_chain(@active_species)
  end

  def active_chain=(value)
    ensure_species_stats!
    return if @active_species.nil?
    v = [value.to_i, 0].max
    @species_current_chain[@active_species] = v
    @species_best_chain[@active_species] = [@species_best_chain[@active_species], v].max
    @active_chain = v
  end

  def pin_streak
    ensure_species_stats!
    return get_current_streak(@active_species)
  end

  def pin_streak=(value)
    ensure_species_stats!
    return if @active_species.nil?
    v = [value.to_i, 0].max
    @species_current_streak[@active_species] = v
    @species_best_streak[@active_species] = [@species_best_streak[@active_species], v].max
    @pin_streak = v
  end

  def clear_pending_search
    @pending_species = nil
    @pending_coords = nil
    @pending_steps = 0
    @pending_bonus = nil
  end

  def pending_search_active?
    return !@pending_species.nil? && @pending_coords.is_a?(Array) && @pending_steps.to_i > 0
  end

  private

  def sync_legacy_active_counters
    ensure_species_stats!
    if @active_species.nil?
      @active_chain = 0
      @pin_streak = 0
    else
      @active_chain = @species_current_chain[@active_species]
      @pin_streak = @species_current_streak[@active_species]
    end
  end

  def ensure_species_stats!
    @species_list = Hash.new(0) if !@species_list.is_a?(Hash)
    @species_current_chain = Hash.new(0) if !@species_current_chain.is_a?(Hash)
    @species_best_chain = Hash.new(0) if !@species_best_chain.is_a?(Hash)
    @species_current_streak = Hash.new(0) if !@species_current_streak.is_a?(Hash)
    @species_best_streak = Hash.new(0) if !@species_best_streak.is_a?(Hash)
  end
end

class EncounterList_Scene
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    mapid = $game_map.map_id
    @encounter_data = GameData::Encounter.get(mapid, $PokemonGlobal.encounter_version)
    if @encounter_data
      @encounter_tables = Marshal.load(Marshal.dump(@encounter_data.types))
      @max_enc, @eLength = getMaxEncounters(@encounter_tables)
    else
      @max_enc, @eLength = [1, 1]
    end
    @index = 0
    @subpage = 0
    @selected_idx = 0
    @current_species = []
    @current_enc_key = nil
    @default_color = Color.new(0, 0, 0, 0)
    @status_text = ""
    @close_after_trigger = false
  end

  def getMaxEncounters(data)
    keys = data.keys
    arr = []
    keys.each do |key|
      list = data[key].map { |item| item[1] }.uniq
      arr << list.length
    end
    return arr.max, keys.length
  end

  def pbStartScene
    unless File.file?("Graphics/UI/EncounterUI/" + WINDOWSKIN)
      raise _INTL("Missing UI graphic: Graphics/UI/EncounterUI/{1}", WINDOWSKIN)
    end
    @sprites["base"] = IconSprite.new(0, 0, @viewport)
    @sprites["base"].setBitmap("Graphics/UI/EncounterUI/#{WINDOWSKIN}")
    @sprites["base"].ox = @sprites["base"].bitmap.width / 2
    @sprites["base"].oy = @sprites["base"].bitmap.height / 2
    @sprites["base"].x = Graphics.width / 2
    @sprites["base"].y = Graphics.height / 2
    @sprites["base"].opacity = 200

    @sprites["loc_sprite"] = Sprite.new(@viewport)
    @sprites["loc_sprite"].bitmap = Bitmap.new(LOC_WINDOW_WIDTH, LOC_WINDOW_HEIGHT)
    @sprites["loc_sprite"].x = Graphics.width / 2
    @sprites["loc_sprite"].y = Graphics.height / 2
    @sprites["loc_sprite"].ox = LOC_WINDOW_WIDTH / 2
    @sprites["loc_sprite"].oy = LOC_WINDOW_HEIGHT / 2

    dexnav_ui_path = nil
    ["Graphics/UI/EncounterUI/DexnavSearchUI_with_icons",
     "Graphics/UI/EncounterUI/DexnavSearchUI",
     "Graphics/UI/EncounterUI/DexnavSearch UI_with_icons",
     "Graphics/UI/EncounterUI/DexnavSearch UI"].each do |p|
      if pbResolveBitmap(p)
        dexnav_ui_path = p
        break
      end
    end
    if dexnav_ui_path
      @sprites["dexnav_ui"] = IconSprite.new(0, 0, @viewport)
      @sprites["dexnav_ui"].setBitmap(dexnav_ui_path)
      @sprites["dexnav_ui"].x = Graphics.width - @sprites["dexnav_ui"].bitmap.width + 12
      @sprites["dexnav_ui"].y = Graphics.height - @sprites["dexnav_ui"].bitmap.height + 2
      @sprites["dexnav_ui"].z = 50
      @sprites["dexnav_ui"].visible = false
    end
    
    @sprites["dexnav_text"] = Sprite.new(@viewport)
    @sprites["dexnav_text"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @sprites["dexnav_text"].visible = false

    @h = (Graphics.height - @sprites["base"].bitmap.height) / 2
    @w = (Graphics.width - @sprites["base"].bitmap.width) / 2
    @max_enc&.times do |i|
      @sprites["icon_#{i}"] = PokemonSpeciesIconSprite.new(nil, @viewport)
      if i == 0
        @default_color = Color.new(@sprites["icon_#{i}"].color.red,
                                   @sprites["icon_#{i}"].color.green,
                                   @sprites["icon_#{i}"].color.blue,
                                   @sprites["icon_#{i}"].color.alpha)
      end
      @sprites["icon_#{i}"].x = @w + ICON_LEFT_OFFSET + ICON_SPACING * (i % ICONS_PER_ROW)
      @sprites["icon_#{i}"].y = @h + ICON_TOP_OFFSET + (i / ICONS_PER_ROW) * ICON_SPACING
      @sprites["icon_#{i}"].visible = false
    end

    @sprites["cursor"] = IconSprite.new(0, 0, @viewport)
    pointer_path = "Graphics/UI/EncounterUI/pointer"
    if pbResolveBitmap(pointer_path)
      @sprites["cursor"].setBitmap(pointer_path)
    else
      @sprites["cursor"].bitmap = Bitmap.new(64, 64)
      b = @sprites["cursor"].bitmap
      c = Color.new(94, 224, 255)
      b.fill_rect(0, 0, 64, 2, c)
      b.fill_rect(0, 62, 64, 2, c)
      b.fill_rect(0, 0, 2, 64, c)
      b.fill_rect(62, 0, 2, 64, c)
    end
    @sprites["cursor"].z = 200
    @sprites["cursor"].visible = false

    @sprites["rightarrow"] = AnimatedSprite.new("Graphics/UI/EncounterUI/right_arrow", 8, 40, 28, 2, @viewport)
    @sprites["rightarrow"].x = Graphics.width - @sprites["rightarrow"].bitmap.width
    @sprites["rightarrow"].y = Graphics.height / 2 - @sprites["rightarrow"].bitmap.height / ARROW_Y_DIVISOR
    @sprites["rightarrow"].visible = false
    @sprites["rightarrow"].play

    @sprites["leftarrow"] = AnimatedSprite.new("Graphics/UI/EncounterUI/left_arrow", 8, 40, 28, 2, @viewport)
    @sprites["leftarrow"].x = 0
    @sprites["leftarrow"].y = Graphics.height / 2 - @sprites["rightarrow"].bitmap.height / ARROW_Y_DIVISOR
    @sprites["leftarrow"].visible = false
    @sprites["leftarrow"].play

    @encounter_data ? drawEncounterPage : drawAbsent
    playListZoomIn
  end

  def pbEncounter
    loop do
      Graphics.update
      Input.update
      pbUpdate
      break if @close_after_trigger
      if @subpage == 0
        if Input.trigger?(Input::RIGHT) && @eLength > 1 && @index < @eLength - 1
          pbPlayCursorSE
          @index += 1
          drawEncounterPage
        elsif Input.trigger?(Input::LEFT) && @eLength > 1 && @index > 0
          pbPlayCursorSE
          @index -= 1
          drawEncounterPage
        elsif Input.trigger?(Input::USE) && !@current_species.empty?
          pbPlayDecisionSE
          if SHOW_DEXNAV_SEARCH_PANEL && @sprites["dexnav_ui"]
            @sprites["base"].visible = false
            @sprites["loc_sprite"].visible = false
          end
          @subpage = 1
          @selected_idx = 0
          drawDexNavPage
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          break
        end
      else
        if Input.trigger?(Input::RIGHT) && !@current_species.empty?
          pbPlayCursorSE
          @selected_idx = (@selected_idx + 1) % @current_species.length
          drawDexNavPage
        elsif Input.trigger?(Input::LEFT) && !@current_species.empty?
          pbPlayCursorSE
          @selected_idx = (@selected_idx - 1) % @current_species.length
          drawDexNavPage
        elsif Input.trigger?(Input::ACTION) || Input.trigger?(Input::SPECIAL)
          quickSearchSelected
        elsif Input.trigger?(Input::USE)
          quickSearchSelected
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          @sprites["dexnav_ui"].visible = false if @sprites["dexnav_ui"]
          @sprites["dexnav_text"].visible = false
          @subpage = 0
          
          @sprites["base"].visible = true
          @sprites["loc_sprite"].visible = true
          
          drawEncounterPage
        end
      end
    end
  end

  def drawEncounterPage
    hideSprites
    @sprites["cursor"].visible = false
    @sprites["dexnav_ui"].visible = false if @sprites["dexnav_ui"]
    @sprites["dexnav_text"].visible = false
    @sprites["rightarrow"].visible = @index < @eLength - 1
    @sprites["leftarrow"].visible = @index > 0
    if @sprites["rightarrow"]
      @sprites["rightarrow"].x = Graphics.width - @sprites["rightarrow"].bitmap.width
      @sprites["rightarrow"].y = Graphics.height / 2 - @sprites["rightarrow"].bitmap.height / ARROW_Y_DIVISOR
    end
    if @sprites["leftarrow"]
      @sprites["leftarrow"].x = 0
      @sprites["leftarrow"].y = Graphics.height / 2 - @sprites["leftarrow"].bitmap.height / ARROW_Y_DIVISOR
    end
    @current_species, @current_enc_key = getEncData
    i = 0
    @current_species.each do |s|
      species_data = GameData::Species.get(s)
      @sprites["icon_#{i}"].tone = Tone.new(0, 0, 0, 0)
      @sprites["icon_#{i}"].color = @default_color
      row = i / ICONS_PER_ROW
      col = i % ICONS_PER_ROW
      @sprites["icon_#{i}"].x = @w + ICON_LEFT_OFFSET + (col * ICON_SPACING)
      @sprites["icon_#{i}"].y = @h + ICON_TOP_OFFSET + row * ICON_SPACING
      @sprites["icon_#{i}"].pbSetParams(s, 0, species_data.form, false)
      if SHOW_SHADOWS_FOR_UNSEEN_POKEMON && !$player.pokedex.seen?(s)
        @sprites["icon_#{i}"].color = Color.new(0, 0, 0)
      elsif SHOW_SHADOWS_FOR_UNSEEN_POKEMON && !$player.pokedex.owned?(s)
        @sprites["icon_#{i}"].tone = Tone.new(0, 0, 0, 255)
      end
      @sprites["icon_#{i}"].visible = true
      i += 1
    end
    name = USER_DEFINED_NAMES ? USER_DEFINED_NAMES[@current_enc_key] : GameData::EncounterType.get(@current_enc_key).real_name
    loctext = _INTL("<ac>{1}: <c2=43F022E8>{2}</c2></ac>", $game_map.name, name)
    # Adjust text to fit within base.png
    loctext += _INTL("<al><c2=7FFF5EF7>Encounters: {1}  Page {2}/{3}</c2></al>", @current_species.length, @index + 1, @eLength)
    loctext += _INTL("<c2=63184210>-----------------------------------------</c2>")
    loctext += _INTL("<al><c2=43F022E8>[C] DexNav   [X] Exit</c2></al>")
    
    @sprites["loc_sprite"].bitmap.clear
    pbSetSystemFont(@sprites["loc_sprite"].bitmap)
    drawFormattedTextEx(@sprites["loc_sprite"].bitmap, 24, 4, LOC_WINDOW_WIDTH - 32, loctext, Color.new(248, 248, 248), Color.new(40, 40, 40))
  end

  def drawDexNavPage
    hideSprites
    use_panel = (SHOW_DEXNAV_SEARCH_PANEL && !!@sprites["dexnav_ui"])
    @sprites["dexnav_ui"].visible = use_panel if @sprites["dexnav_ui"]
    @sprites["dexnav_text"].visible = use_panel
    @sprites["rightarrow"].visible = (@current_species.length > 1)
    @sprites["leftarrow"].visible = (@current_species.length > 1)
    return if @current_species.empty?
    s = @current_species[@selected_idx]
    species_data = GameData::Species.get(s)
    icon = @sprites["icon_0"]
    if icon
      icon.tone = Tone.new(0, 0, 0, 0)
      icon.color = @default_color
      icon.pbSetParams(s, 0, species_data.form, false)
      if SHOW_SHADOWS_FOR_UNSEEN_POKEMON && !$player.pokedex.seen?(s)
        icon.color = Color.new(0, 0, 0)
      elsif SHOW_SHADOWS_FOR_UNSEEN_POKEMON && !$player.pokedex.owned?(s)
        icon.tone = Tone.new(0, 0, 0, 255)
      end
      if use_panel
        icon.x = @w + 360
        icon.y = @h + 115
      else
        icon.x = @w + 360
        icon.y = @h + 115
      end
      icon.visible = true
      @sprites["cursor"].x = icon.x
      @sprites["cursor"].y = icon.y
      @sprites["cursor"].visible = true
      if @sprites["leftarrow"]
        @sprites["leftarrow"].x = icon.x - 38
        @sprites["leftarrow"].y = icon.y + 16
      end
      if @sprites["rightarrow"]
        @sprites["rightarrow"].x = icon.x + 66
        @sprites["rightarrow"].y = icon.y + 16
      end
    end

    seen = $player.pokedex.seen?(s)
    owned = $player.pokedex.owned?(s)
    dexnav = encounterDexNavData
    search_level = dexnav.get_search_level(s)
    current_chain = dexnav.get_current_chain(s)
    best_chain = dexnav.get_best_chain(s)
    current_streak = dexnav.get_current_streak(s)
    best_streak = dexnav.get_best_streak(s)
    special_move = getPinnedSpecialMoveName(s)
    hidden_ability = if owned
      hidden = species_data.hidden_abilities
      (!hidden.nil? && !hidden.empty?) ? GameData::Ability.get(hidden[0]).name : _INTL("None")
    else
      seen ? "???" : "---"
    end
    items = getSpeciesItemText(species_data, seen, owned)
    species_name = seen ? species_data.real_name : "???"
    name = USER_DEFINED_NAMES ? USER_DEFINED_NAMES[@current_enc_key] : GameData::EncounterType.get(@current_enc_key).real_name

    loctext = _INTL("<ac>{1}: <c2=43F022E8>{2}</c2></ac>", $game_map.name, name)
    loctext += _INTL("<al><c2=7FFF5EF7>Species {1}/{2}</c2></al>", @selected_idx + 1, @current_species.length)
    loctext += _INTL("<c2=63184210>-----------------------------------------</c2>")
    loctext += _INTL("<al><c2=43F022E8>{1}</c2></al>", species_name)
    # Show special move in yellow if available, white if none
    special_move_color = (special_move != _INTL("None")) ? "FFFF00" : "FFFFFF"
    loctext += _INTL("<al><c2=7FFF5EF7>Search Level:</c2> {1}</al>", search_level)
    loctext += _INTL("<al><c2=7FFF5EF7>Current Chain:</c2> {1}   <c2=7FFF5EF7>Best Chain:</c2> {2}</al>", current_chain, best_chain)
    loctext += _INTL("<al><c2=7FFF5EF7>Current Streak:</c2> {1}   <c2=7FFF5EF7>Best Streak:</c2> {2}</al>", current_streak, best_streak)
    # Show hidden ability in yellow if it's a hidden ability, white if normal/None
    ability_color = (hidden_ability != _INTL("None") && hidden_ability != "???" && hidden_ability != "---") ? "FFFF00" : "FFFFFF"
    action_key = pbInputKeyName(Input::ACTION, "ACTION")
    loctext += _INTL("<al><c2=43F022E8>[{1}] Trigger   [X] Back</c2></al>", action_key)
    
    if use_panel
      @sprites["dexnav_text"].bitmap.clear
      pbSetSystemFont(@sprites["dexnav_text"].bitmap)
      # Draw text relative to the DexNav UI panel
      x_pos = @sprites["dexnav_ui"].x + 20
      y_pos = @sprites["dexnav_ui"].y + 20
      drawFormattedTextEx(@sprites["dexnav_text"].bitmap, x_pos, y_pos, LOC_WINDOW_WIDTH, loctext, Color.new(248, 248, 248), Color.new(40, 40, 40))
    else
      @sprites["loc_sprite"].bitmap.clear
      pbSetSystemFont(@sprites["loc_sprite"].bitmap)
      drawFormattedTextEx(@sprites["loc_sprite"].bitmap, 24, 4, LOC_WINDOW_WIDTH - 32, loctext, Color.new(248, 248, 248), Color.new(40, 40, 40))
    end
  end

  def drawAbsent
    hideSprites
    @sprites["cursor"].visible = false
    @sprites["rightarrow"].visible = false
    @sprites["leftarrow"].visible = false
    loctext = _INTL("<ac>{1}</ac>", $game_map.name)
    loctext += _INTL("<al><c2=7FFF5EF7>No wild Pokemon in this area</c2></al>")
    loctext += _INTL("<c2=63184210>-----------------------------------------</c2>")
    @sprites["loc_sprite"].bitmap.clear
    pbSetSystemFont(@sprites["loc_sprite"].bitmap)
    drawFormattedTextEx(@sprites["loc_sprite"].bitmap, 0, 0, LOC_WINDOW_WIDTH, loctext, Color.new(248, 248, 248), Color.new(40, 40, 40))
  end

  def getEncData
    curr_key = @encounter_tables.keys[@index]
    enc_array = []
    encounters = @encounter_tables[curr_key]
    if encounters
      enc_array = encounters.map { |e| [e[1], e[0]] }
      enc_array.sort_by! do |e|
        dexlist = pbGetDexList(e[0])
        dexnum = dexlist[0][dexlist[1]][:number]
        [-e[1], dexnum]
      end
      enc_array.map! { |e| e[0] }
      enc_array.uniq!
    end
    return enc_array, curr_key
  end

  def encounterMethodFromType(enc_key)
    key_name = enc_key.to_s
    return _INTL("Walk") if key_name.start_with?("Land", "Cave", "Headbutt", "RockSmash", "BugContest")
    return _INTL("Surf") if key_name.start_with?("Water")
    return _INTL("Fish") if key_name.end_with?("Rod")
    return key_name
  end

  # Returns the display label for a configured input key.
  def pbInputKeyName(input_value, fallback_label)
    default_map = {
      Input::USE     => "C",
      Input::BACK    => "X",
      Input::ACTION  => "Z",
      Input::SPECIAL => "D"
    }
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
        name = Input.send(meth, input_value)
        return name.to_s.strip if name && !name.to_s.strip.empty?
      rescue StandardError
        next
      end
    end
    begin
      data_dir = System.data_directory
      kb_path = data_dir ? File.join(data_dir, "keybindings.mkxp1") : nil
      if kb_path && File.file?(kb_path)
        bytes = File.binread(kb_path)
        ints = bytes.unpack("l<*")
        records = ints.each_slice(4).to_a
        matches = records.select { |rec| rec && rec.length == 4 && rec[2] == input_value }
        if !matches.empty?
          matches.sort_by! { |rec| rec[3] || 0 }
          matches.reverse!
          keycode = matches[0][0]
          label = pbKeycodeToLabel(keycode)
          return label if label && !label.empty?
        end
      end
    rescue StandardError
    end
    return default_map[input_value] || fallback_label
  end

  # Converts mkxp/SDL scancodes to display labels.
  def pbKeycodeToLabel(code)
    return "" if code.nil?
    return (65 + (code - 4)).chr if code >= 4 && code <= 29
    return (code - 29).to_s if code >= 30 && code <= 38
    return "0" if code == 39
    return "F#{code - 57}" if code >= 58 && code <= 69
    return "RIGHT" if code == 79
    return "LEFT"  if code == 80
    return "DOWN"  if code == 81
    return "UP"    if code == 82
    return "ENTER"     if code == 40
    return "ESC"       if code == 41
    return "BACKSPACE" if code == 42
    return "TAB"       if code == 43
    return "SPACE"     if code == 44
    return "LSHIFT"    if code == 225
    return "RSHIFT"    if code == 229
    return "LCTRL"     if code == 224
    return "RCTRL"     if code == 228
    return "LALT"      if code == 226
    return "RALT"      if code == 230
    return "LGUI"      if code == 227
    return "RGUI"      if code == 231
    return ""
  end

  def getSpeciesItemText(species_data, seen, owned)
    return "---" unless seen
    return "???" unless owned
    names = []
    c = species_data.wild_item_common
    u = species_data.wild_item_uncommon
    r = species_data.wild_item_rare
    names << "#{GameData::Item.get(c[0]).name} (50%)" if !c.nil? && !c.empty?
    names << "#{GameData::Item.get(u[0]).name} (5%)" if !u.nil? && !u.empty?
    names << "#{GameData::Item.get(r[0]).name} (1%)" if !r.nil? && !r.empty?
    names.uniq!
    return names.empty? ? _INTL("None") : names.join(", ")
  end

  def getPinnedSpecialMoveName(species)
    begin
      dexnav = encounterDexNavData
      # Use the pending_bonus move if available (already calculated)
      if dexnav.respond_to?(:pending_bonus) && dexnav.pending_bonus && dexnav.pending_bonus[:special_move]
        mv = dexnav.pending_bonus[:special_move]
        return GameData::Move.get(mv).name
      end
      # Otherwise, no special move is available
      return _INTL("None")
    rescue StandardError
      return _INTL("None")
    end
  end

  def quickRegisterSelected(show_message = false)
    return if @current_species.empty?
    species = @current_species[@selected_idx]
    dexnav = encounterDexNavData
    dexnav.set_active_species(species, 15, encounterIsGrassStyle?(@current_enc_key))
    $game_switches[dexnavRegisteredSwitchID] = true
    pbMessage(_INTL("{1} has been pinned.", GameData::Species.get(species).real_name)) if show_message
    drawDexNavPage
  end

  def quickSearchSelected
    return if @current_species.empty?
    trigger_species = @current_species[@selected_idx]
    return if trigger_species.nil?
    dexnav = encounterDexNavData
    dexnav.set_active_species(trigger_species, 15, encounterIsGrassStyle?(@current_enc_key))
    dexnav.last_hunt_species = trigger_species if dexnav.respond_to?(:last_hunt_species=)
    $game_switches[dexnavRegisteredSwitchID] = true
    if Kernel.respond_to?(:pbDexNavSearchEvent)
      pbPlayDecisionSE
      pbDexNavSearchEvent
      GameData::Species.play_cry(trigger_species)
      @close_after_trigger = true
    else
      if startFallbackDexNavSearch(trigger_species, encounterIsGrassStyle?(@current_enc_key))
        pbPlayDecisionSE
        GameData::Species.play_cry(trigger_species)
        @close_after_trigger = true
      else
        pbPlayBuzzerSE
        pbMessage(_INTL("No valid encounter spot found."))
      end
    end
    drawDexNavPage unless @close_after_trigger
  end

  def clearRegisteredSpecies
    $game_switches[dexnavRegisteredSwitchID] = false
    dexnav = encounterDexNavData
    dexnav.set_inactive if dexnav.respond_to?(:set_inactive)
  end

  def openActionMenu
    # Deprecated - trigger is now direct
  end

  def currentPinnedSpecies
    return nil if !$game_switches[dexnavRegisteredSwitchID]
    dexnav = encounterDexNavData
    return nil if !dexnav.respond_to?(:active_species)
    return dexnav.active_species
  end

  # Fallback search for projects without the full DexNav module:
  # marks a target in map tiles and starts battle when reached.
  def startFallbackDexNavSearch(species, is_grass = true)
    return false if species.nil?
    dexnav = encounterDexNavData
    coords = fallbackSearchCoords(is_grass)
    return false if coords.nil?
    bonus = buildFallbackBonus(species)
    dexnav.pending_species = species
    dexnav.pending_coords = coords
    dexnav.pending_steps = 16
    dexnav.pending_is_grass = is_grass
    dexnav.pending_bonus = bonus
    dexnav.last_hunt_species = species if dexnav.respond_to?(:last_hunt_species=)
    pbEncounterDexNavLiteShowSearchAnim(coords[0], coords[1], is_grass, true)
     $game_temp.instance_variable_set(:@encounter_dexnav_overlay_data, {
      species: species,
      is_grass: is_grass,
      search_level: dexnav.get_search_level(species),
      streak: dexnav.get_current_streak(species).to_i,
      steps: dexnav.pending_steps,
      special_move: bonus[:special_move],
      ivs: bonus[:ivs],
      item: bonus[:item],
      ability: bonus[:ability]
    })
    return true
  rescue StandardError
    return false
  end

  def buildFallbackBonus(species)
    dexnav = encounterDexNavData
    streak = dexnav.get_current_streak(species).to_i
    search = dexnav.get_search_level(species).to_i
    sp = GameData::Species.get(species)
    bonus = { special_move: nil, ivs: 0, item: nil, ability: nil }
    special_pool = ((sp.tutor_moves || []) + (sp.get_egg_moves || [])).compact.uniq
    if !special_pool.empty?
      chance = [15 + streak * 2 + (search / 5), 85].min
      # Store the special move decision once and keep it consistent
      if rand(100) < chance
        bonus[:special_move] = special_pool.sample
      end
    end
    # Hidden ability chance
    hidden_abilities = sp.hidden_abilities || []
    if !hidden_abilities.empty?
      hidden_chance = [5 + streak * 3, 40].min
      if rand(100) < hidden_chance
        bonus[:ability] = hidden_abilities.sample
      end
    end
    bonus[:ivs] = (streak >= 20) ? 3 : (streak >= 10 ? 2 : (streak >= 5 ? 1 : 0))
    c = sp.wild_item_common
    u = sp.wild_item_uncommon
    r = sp.wild_item_rare
    
    # Special items pool (Elemental + Berries)
    special_items = [:CHARCOAL, :MYSTICWATER, :MIRACLESEED, :NEVERMELTICE, :MAGNET, :SHARPBEAK, :POISONBARB, :SPELLTAG, :DRAGONFANG, :SILKSCARF]
    berries = [:ORANBERRY, :SITRUSBERRY, :LUMBERRY, :LEPPABERRY, :RAWSTBERRY, :CHERIBERRY, :CHESTOBERRY, :PECHABERRY, :ASPEARBERRY]
    
    # Item probability system - higher chance with streak
    if !r.nil? && !r.empty?
      rare_chance = [8 + (streak * 0.8), 35].min
      bonus[:item] = r[0] if rand(100) < rare_chance
    end
    unless bonus[:item]
      if !u.nil? && !u.empty?
        uncommon_chance = [20 + (streak * 0.5), 55].min
        bonus[:item] = u[0] if rand(100) < uncommon_chance
      end
    end
    unless bonus[:item]
      if !c.nil? && !c.empty?
        common_chance = [50 + (streak * 0.3), 90].min
        bonus[:item] = c[0] if rand(100) < common_chance
      end
    end
    
    # Chance for special item override (15% base + 1% per streak level)
    special_chance = [15 + (streak * 1.0), 40].min
    if rand(100) < special_chance
      bonus[:item] = (special_items + berries).sample
    end
    
    return bonus
  end

  def fallbackSearchCoords(is_grass = true)
    target = if is_grass
               [:Grass, :TallGrass, :UnderwaterGrass]
             else
               [:Water, :DeepWater, :StillWater]
             end
    x = -1
    y = -1
    (0..3).each do
      i = 3
      r = rand((i + 1) * 8)
      if r <= (i + 1) * 2
        x = $game_player.x - i - 1 + r
        y = $game_player.y - i - 1
      elsif r <= ((i + 1) * 6) - 2
        x = [$game_player.x + i + 1, $game_player.x - i - 1][r % 2]
        y = $game_player.y - i + ((r - 1 - ((i + 1) * 2)) / 2).floor
      else
        x = $game_player.x - i + r - ((i + 1) * 6)
        y = $game_player.y + i + 1
      end
      next if x < 0 || x >= $game_map.width || y < 0 || y >= $game_map.height
      terrain = $game_map.terrain_tag(x, y)
      return [x, y] if target.include?(terrain.id)
    end
    return nil
  end

  def encounterIsGrassStyle?(enc_key)
    key_name = enc_key.to_s
    return false if key_name.start_with?("Water")
    return false if key_name.end_with?("Rod")
    return true
  end

  def encounterDexNavData
    return safeAccessDexNav if Kernel.respond_to?(:safeAccessDexNav)
    storage_id = dexnavStorageVariableID
    dexnav = $game_variables[storage_id]
    if !dexnav.is_a?(EncounterDexNavLiteData)
      dexnav = EncounterDexNavLiteData.new
      $game_variables[storage_id] = dexnav
    end
    return dexnav
  end

  def dexnavStorageVariableID
    return Settings::DEXNAX_GLOBAL_STORAGE_VARIABLE_ID if defined?(Settings::DEXNAX_GLOBAL_STORAGE_VARIABLE_ID)
    return 44
  end

  def dexnavRegisteredSwitchID
    return Settings::DEXNAX_HAS_REGISTERED_SWITCH_ID if defined?(Settings::DEXNAX_HAS_REGISTERED_SWITCH_ID)
    return 63
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def playListZoomIn
    keys = @sprites.keys
    cx = Graphics.width / 2.0
    cy = Graphics.height / 2.0
    original = {}
    keys.each do |k|
      s = @sprites[k]
      next if !s || s.disposed?
      next unless s.respond_to?(:x) && s.respond_to?(:y)
      ow = s.respond_to?(:width) ? s.width : nil
      oh = s.respond_to?(:height) ? s.height : nil
      original[k] = { x: s.x, y: s.y, w: ow, h: oh }
    end
    10.times do |i|
      z = 0.2 + (0.8 * (i + 1) / 10.0)
      keys.each do |k|
        s = @sprites[k]
        next if !s || s.disposed?
        if s.respond_to?(:zoom_x=) && s.respond_to?(:zoom_y=)
          s.zoom_x = z
          s.zoom_y = z
        end
        next unless original[k]
        ox = original[k][:x]
        oy = original[k][:y]
        s.x = (cx + (ox - cx) * z).to_i
        s.y = (cy + (oy - cy) * z).to_i
        if s.respond_to?(:width=) && original[k][:w]
          s.width = [1, (original[k][:w] * z).to_i].max
        end
        if s.respond_to?(:height=) && original[k][:h]
          s.height = [1, (original[k][:h] * z).to_i].max
        end
      end
      Graphics.update
      Input.update
      pbUpdate
    end
    keys.each do |k|
      s = @sprites[k]
      next if !s || s.disposed?
      if s.respond_to?(:zoom_x=) && s.respond_to?(:zoom_y=)
        s.zoom_x = 1.0
        s.zoom_y = 1.0
      end
      next unless original[k]
      s.x = original[k][:x]
      s.y = original[k][:y]
      s.width = original[k][:w] if s.respond_to?(:width=) && original[k][:w]
      s.height = original[k][:h] if s.respond_to?(:height=) && original[k][:h]
    end
  end

  def playListZoomOut
    keys = @sprites.keys
    cx = Graphics.width / 2.0
    cy = Graphics.height / 2.0
    original = {}
    keys.each do |k|
      s = @sprites[k]
      next if !s || s.disposed?
      next unless s.respond_to?(:x) && s.respond_to?(:y)
      ow = s.respond_to?(:width) ? s.width : nil
      oh = s.respond_to?(:height) ? s.height : nil
      original[k] = { x: s.x, y: s.y, w: ow, h: oh }
    end
    10.times do |i|
      z = 1.0 - (0.8 * (i + 1) / 10.0)
      keys.each do |k|
        s = @sprites[k]
        next if !s || s.disposed?
        if s.respond_to?(:zoom_x=) && s.respond_to?(:zoom_y=)
          s.zoom_x = z
          s.zoom_y = z
        end
        next unless original[k]
        ox = original[k][:x]
        oy = original[k][:y]
        s.x = (cx + (ox - cx) * z).to_i
        s.y = (cy + (oy - cy) * z).to_i
        if s.respond_to?(:width=) && original[k][:w]
          s.width = [1, (original[k][:w] * z).to_i].max
        end
        if s.respond_to?(:height=) && original[k][:h]
          s.height = [1, (original[k][:h] * z).to_i].max
        end
      end
      Graphics.update
      Input.update
      pbUpdate
    end
  end

  def hideSprites
    @max_enc.times do |i|
      @sprites["icon_#{i}"].visible = false
    end
  end

  def pbEndScene
    playListZoomOut if !@close_after_trigger
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    data = $game_temp.instance_variable_get(:@encounter_dexnav_overlay_data)
    if data
      $game_temp.instance_variable_set(:@encounter_dexnav_overlay_data, nil)
      EncounterDexNavSearchOverlay.show(data)
    end
  end
end

class EncounterList_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbEncounter
    @scene.pbEndScene
  end
end

ItemHandlers::UseFromBag.add(:RADAR, proc { |item|
  scene = EncounterList_Scene.new
  screen = EncounterList_Screen.new(scene)
  screen.pbStartScreen
  next 1
})

ItemHandlers::UseInField.add(:RADAR, proc { |item|
  scene = EncounterList_Scene.new
  screen = EncounterList_Screen.new(scene)
  screen.pbStartScreen
  next 1
})

def pbStartRadar
  scene = EncounterList_Scene.new
  screen = EncounterList_Screen.new(scene)
  screen.pbStartScreen
end

def pbEncounterDexNavLiteData
  storage_id = defined?(Settings::DEXNAX_GLOBAL_STORAGE_VARIABLE_ID) ? Settings::DEXNAX_GLOBAL_STORAGE_VARIABLE_ID : 44
  dexnav = $game_variables[storage_id]
  if !dexnav.is_a?(EncounterDexNavLiteData)
    dexnav = EncounterDexNavLiteData.new
    $game_variables[storage_id] = dexnav
  end
  return dexnav
end

def pbEncounterDexNavLiteShowSearchAnim(x, y, is_grass = true, first = false)
  return if !$scene || !$scene.respond_to?(:spriteset) || !$scene.spriteset
  water_anim_id = if defined?(Settings::WATER_RIPPLE_ANIMATION_ID)
                    Settings::WATER_RIPPLE_ANIMATION_ID
                  elsif defined?(Settings::BUBBLE_ANIM_ID)
                    Settings::BUBBLE_ANIM_ID
                  else
                    8
                  end
  anim = if is_grass
           (defined?(Settings::RUSTLE_NORMAL_ANIMATION_ID) ? Settings::RUSTLE_NORMAL_ANIMATION_ID : 1)
         else
           water_anim_id
         end
  tinting = is_grass
  anim_sprite = $scene.spriteset.addUserAnimation(anim, x, y, tinting, 1)
  # Water search FX: force a subtle blue tint to avoid a plain white look.
  anim_sprite.tone = Tone.new(-48, -24, 48, 0) if !is_grass && anim_sprite
  if first
    anim_sprite = $scene.spriteset.addUserAnimation(anim, x, y, tinting, 1)
    anim_sprite.tone = Tone.new(-48, -24, 48, 0) if !is_grass && anim_sprite
  end
end

module EncounterDexNavSearchOverlay
  PANEL_MARGIN_X = 0
  PANEL_MARGIN_Y = 0
  # Reference coords taken from DexNav 1.2.0 OverlayUI:
  # icon(440,185), text(280,248,250,126), item(480,354), ivs(294,358)
  REF_ICON_X = 475
  REF_ICON_Y = 225
  REF_ITEM_X = 480
  REF_ITEM_Y = 354
  REF_IVS_X  = 260
  REF_IVS_Y  = 358
  REF_TEXT_X = 240
  REF_TEXT_Y = 248
  REF_TEXT_W = 250
  REF_TEXT_H = 126

  @viewport = nil
  @panel = nil
  @text = nil
  @icon = nil
  @item = nil
  @ivs = nil
  @data = nil
  @cached_panel_path = nil

  def self.show(data)
    hide
    return if !data || data[:species].nil?
    @data = data.clone
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    
    if !@cached_panel_path
      ["Graphics/UI/EncounterUI/DexnavSearchUI_with_icons",
       "Graphics/UI/EncounterUI/DexnavSearchUI",
       "Graphics/UI/EncounterUI/DexnavSearch UI_with_icons",
       "Graphics/UI/EncounterUI/DexnavSearch UI"].each do |p|
        if pbResolveBitmap(p)
          @cached_panel_path = p
          break
        end
      end
    end
    
    if @cached_panel_path
      @panel = IconSprite.new(0, 0, @viewport)
      @panel.setBitmap(@cached_panel_path)
      @panel.x = Graphics.width
      @panel.y = Graphics.height - @panel.bitmap.height - PANEL_MARGIN_Y
    end
    @text = Window_AdvancedTextPokemon.newWithSize("", 0, 0, REF_TEXT_W, REF_TEXT_H, @viewport)
    @text.opacity = 0
    @text.baseColor = Color.new(248, 248, 248)
    @text.shadowColor = Color.new(40, 40, 40)
    species = data[:species]
    sp = GameData::Species.get(species)
    pkmn = Pokemon.new(species, 1)
    @icon = PokemonIconSprite.new(pkmn, @viewport)
    @icon.setOffset(PictureOrigin::CENTER) if @icon.respond_to?(:setOffset)
  # Set icon position to fit in the circle
  @icon.x = (@panel ? @panel.x : 0) + REF_ICON_X
  @icon.y = (@panel ? @panel.y : 0) + REF_ICON_Y
    if data[:item]
      @item = ItemIconSprite.new((@panel ? @panel.x : 0) + REF_ITEM_X, (@panel ? @panel.y : 0) + REF_ITEM_Y, data[:item], @viewport)
    end
    ivs_count = data[:ivs].to_i
    if ivs_count > 0
      file = (ivs_count >= 3) ? "ThreeIVs" : (ivs_count == 2 ? "TwoIVs" : "OneIVs")
      path = "Graphics/UI/EncounterUI/#{file}"
      if pbResolveBitmap(path)
        @ivs = IconSprite.new(0, 0, @viewport)
        @ivs.setBitmap(path)
        @ivs.x = (@panel ? @panel.x : 0) + REF_IVS_X
        @ivs.y = (@panel ? @panel.y : 0) + REF_IVS_Y
      end
    end
    move_name = "None"
    if data[:special_move]
      move_name = GameData::Move.get(data[:special_move]).name rescue "None"
    end
    # Show the Pokémon's ability, not "None" if no hidden ability is selected
    ability_text = if data[:ability]
                    GameData::Ability.get(data[:ability]).name rescue sp.abilities[0] ? GameData::Ability.get(sp.abilities[0]).name : "None"
                   else
                     # If no ability is specified, use the first normal ability
                     sp.abilities[0] ? GameData::Ability.get(sp.abilities[0]).name : "None"
                   end
  @text.text = _INTL("{1}\n★ {2}\n{3}\nLv {4}  Streak {5}  Steps {6}",
                        sp.real_name, move_name, ability_text, data[:search_level], data[:streak], data[:steps])
    animate_in
  rescue StandardError
    hide
  end

  def self.update_steps(steps)
    return if !@data || !@text || @text.disposed?
    @data[:steps] = steps
    move_name = "None"
    if @data[:special_move]
      move_name = GameData::Move.get(@data[:special_move]).name rescue "None"
    end
    sp = GameData::Species.get(@data[:species])
    # Show the Pokémon's ability, not "None" if no hidden ability is selected
    ability_text = if @data[:ability]
                    GameData::Ability.get(@data[:ability]).name rescue sp.abilities[0] ? GameData::Ability.get(sp.abilities[0]).name : "None"
                   else
                     # If no ability is specified, use the first normal ability
                     sp.abilities[0] ? GameData::Ability.get(sp.abilities[0]).name : "None"
                   end
  @text.text = _INTL("{1}\n★ {2}\n{3}\nLv {4}  Streak {5}  Steps {6}",
                        sp.real_name, move_name, ability_text, @data[:search_level], @data[:streak], @data[:steps])
  rescue StandardError
  end

  def self.animate_in
    return unless @panel
    target_x = Graphics.width - @panel.bitmap.width - PANEL_MARGIN_X
    start_x = Graphics.width
    24.times do |i|
      t = (i + 1) / 24.0
      ease = t * t * (3.0 - 2.0 * t)
      x = start_x - ((start_x - target_x) * ease)
      place_x(x.to_i)
      Graphics.update
      Input.update
      @icon&.update
    end
    place_x(target_x)
  end

  def self.animate_out
    return unless @panel
    start_x = @panel.x
    target_x = Graphics.width
    24.times do |i|
      t = (i + 1) / 24.0
      ease = t * t * (3.0 - 2.0 * t)
      x = start_x + ((target_x - start_x) * ease)
      place_x(x.to_i)
      Graphics.update
      Input.update
      @icon&.update
    end
  end

  def self.place_x(panel_x)
    return unless @panel
    @panel.x = panel_x
    @icon.x = panel_x + REF_ICON_X if @icon && !@icon.disposed?
    @icon.y = (@panel ? @panel.y : 0) + REF_ICON_Y if @icon && !@icon.disposed?
    @item.x = panel_x + REF_ITEM_X if @item && !@item.disposed?
    @ivs.x = panel_x + REF_IVS_X if @ivs && !@ivs.disposed?
    @text.x = panel_x + REF_TEXT_X if @text && !@text.disposed?
    @text.y = (@panel ? @panel.y : 0) + REF_TEXT_Y if @text && !@text.disposed?
  end

  def self.hide
    animate_out
    @icon&.dispose
    @icon = nil
    @item&.dispose
    @item = nil
    @ivs&.dispose
    @ivs = nil
    @panel&.dispose
    @panel = nil
    @text&.dispose
    @text = nil
    @data = nil
    @viewport&.dispose
    @viewport = nil
  end
end

def pbEncounterDexNavLiteStartBattle(species, bonus = nil)
  return false if species.nil?
  dexnav = pbEncounterDexNavLiteData
  level = 1
  encounterData = GameData::Encounter.get($game_map.map_id, $PokemonGlobal.encounter_version)
  if encounterData
    encounterTables = Marshal.load(Marshal.dump(encounterData.types))
    encounterTables.each_value do |enc|
      next if enc.nil? || enc.empty?
      entry = enc.find { |e| e[1] == species }
      next if entry.nil?
      if entry[2] && entry[3]
        level = rand(entry[2]..entry[3])
      end
      break
    end
  end
  if dexnav.active_species == species
    level += [dexnav.get_current_streak(species).to_i / 3, 5].min
  end
  pkmn = Pokemon.new(species, level)
  bonus ||= (dexnav.pending_bonus || {})
  # Apply special move if available - use learn_move as in original DexNav
  puts "Debug: Bonus data: #{bonus.inspect}"
  if bonus && bonus[:special_move]
    begin
      move = GameData::Move.get(bonus[:special_move])
      puts "Debug: Special move name: #{move.name}"
      puts "Debug: Current moves before adding: #{pkmn.moves}"
      
      # Use learn_move method as in original DexNav
      result = pkmn.learn_move(move.id)
      puts "Debug: learn_move result: #{result}"
      puts "Debug: Current moves after adding: #{pkmn.moves}"
    rescue StandardError => e
      puts "Failed to add special move: #{e.message}"
      puts "Error backtrace: #{e.backtrace.join("\n")}"
    end
  end
  # Apply hidden ability if available
  if bonus && bonus[:ability]
    begin
      pkmn.ability_id = bonus[:ability]
      puts "Debug: Applied hidden ability: #{GameData::Ability.get(bonus[:ability]).name}"
    rescue StandardError => e
      puts "Failed to apply hidden ability: #{e.message}"
    end
  end
  # Apply item if available
  if bonus && bonus[:item]
    item = GameData::Item.get(bonus[:item])
    pkmn.item = item.id if item
  end
  # Apply IV bonuses
  ivs = bonus && bonus[:ivs] ? bonus[:ivs].to_i : 0
  if ivs > 0
    iv_slots = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
    iv_slots.sample([ivs, 6].min).each { |st| pkmn.iv[st] = 31 }
  end
  dexnav.last_hunt_species = species if dexnav.respond_to?(:last_hunt_species=)
  dexnav.pending_bonus = nil if dexnav.respond_to?(:pending_bonus=)
  WildBattle.start(pkmn)
  return true
end

EventHandlers.add(:on_player_step_taken, :encounter_dexnav_pending_search,
  proc {
    dexnav = pbEncounterDexNavLiteData
    next unless dexnav.pending_search_active?
    coords = dexnav.pending_coords
    species = dexnav.pending_species
    dexnav.pending_steps -= 1
    if dexnav.pending_steps <= 0
      dexnav.clear_pending_search
      EncounterDexNavSearchOverlay.hide
      pbMessage(_INTL("The target has been lost."))
      next
    end
    EncounterDexNavSearchOverlay.update_steps(dexnav.pending_steps)
    pbEncounterDexNavLiteShowSearchAnim(coords[0], coords[1], dexnav.pending_is_grass, false)
    if $game_player.x == coords[0] && $game_player.y == coords[1]
      bonus = dexnav.pending_bonus
      puts "Debug: Encounter bonus: #{bonus.inspect}"
      pbEncounterDexNavLiteShowSearchAnim(coords[0], coords[1], dexnav.pending_is_grass, true)
      # Clear pending search and hide overlay AFTER the battle starts/ends
      pbEncounterDexNavLiteStartBattle(species, bonus)
      dexnav.clear_pending_search
      EncounterDexNavSearchOverlay.hide
    end
  }
)

EventHandlers.add(:on_enter_map, :encounter_dexnav_clear_overlay,
  proc { |_map_id|
    EncounterDexNavSearchOverlay.hide
  }
)

EventHandlers.add(:on_end_battle, :encounter_dexnav_pin_progress,
  proc { |decision, _canLose|
    EncounterDexNavSearchOverlay.hide
    storage_id = defined?(Settings::DEXNAX_GLOBAL_STORAGE_VARIABLE_ID) ? Settings::DEXNAX_GLOBAL_STORAGE_VARIABLE_ID : 44
    dexnav = $game_variables[storage_id]
    next if !dexnav || !dexnav.respond_to?(:last_hunt_species)
    species = dexnav.last_hunt_species
    next if species.nil?
    success = [1, 4].include?(decision)
    if success
      dexnav.increase_species_progress(species) if dexnav.respond_to?(:increase_species_progress)
    else
      dexnav.reset_species_progress(species) if dexnav.respond_to?(:reset_species_progress)
    end
    dexnav.last_hunt_species = nil if dexnav.respond_to?(:last_hunt_species=)
  }
)
