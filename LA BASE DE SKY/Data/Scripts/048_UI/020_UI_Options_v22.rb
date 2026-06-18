#===============================================================================
#
#===============================================================================
class PokemonSystem
  # Simple read/write attributes (no custom accessors)
  attr_accessor :battlestyle
  attr_accessor :runstyle
  attr_accessor :sendtoboxes
  attr_accessor :givenicknames
  attr_accessor :textinput
  attr_accessor :battlescene
  attr_accessor :vsync
  attr_accessor :autotile_animations

  # Attributes with custom setters defined below (reader only via attr)
  attr_reader :textspeed
  attr_reader :textskin
  attr_reader :frame
  attr_reader :screensize
  attr_reader :language

  # Attributes with both custom getter and setter defined below
  attr_reader :skip_texts
  attr_reader :skip_move_learning
  attr_reader :main_volume
  attr_reader :bgmvolume
  attr_reader :sevolume
  attr_reader :pokemon_cry_volume

  # Write-only
  attr_writer :controls

  def initialize
    @battlestyle         = 0     # Battle style (0=switch, 1=set)
    @runstyle            = 0     # Default movement speed (0=walk, 1=run)
    @sendtoboxes         = 0     # Send to Boxes (0=manual, 1=automatic)
    @givenicknames       = 0     # Give nicknames (0=give, 1=don't give)
    @skip_move_learning  = 1     # Skip move learning (0=Sí, 1=No)
    @textinput           = 0     # Text input mode (0=cursor, 1=keyboard)
    @skip_texts          = 1     # Skip text (0=Sí, 1=No)
    @language            = 0     # Language (see also Settings::LANGUAGES)
    @main_volume         = 100
    @bgmvolume           = 80    # Volume of background music and ME
    @sevolume            = 100   # Volume of sound effects (except cries)
    @pokemon_cry_volume  = 100
    @textspeed           = 1     # Text speed (0=slow, 1=medium, 2=fast, 3=instant)
    @battlescene         = 0     # Battle effects (animations) (0=on, 1=off)
    @textskin            = 0     # Speech frame
    @frame               = 0     # Default window frame (see also Settings::MENU_WINDOWSKINS)
    @screensize          = Settings.screensize_index_from_screen_scale
    @vsync               = vsync_initial_value?
    @autotile_animations = 0
  end

  def vsync_initial_value?
    return 1 if !File.exist?("mkxp.json") || $joiplay
    file_content = File.read("mkxp.json")
    clean_json_string = json_remove_comments(file_content)
    # Parse JSON content
    begin
      config = HTTPLite::JSON.parse(clean_json_string)

      # Check the vsync value
      vsync_value = config['vsync']
      return vsync_value == true ? 0 : 1
    rescue MKXPError => e
      echoln "Error parsing JSON: #{e.message}"
      return 1
    end
  end

  def update_vsync(vsync_value)
    file_path = "mkxp.json"
    vsync_value = vsync_value == 1 ? false : true
    vsync_str = vsync_value ? 'true' : 'false'
    sync_to_refresh_str = vsync_str

    # Read the file line-by-line to preserve comments and order
    lines = File.readlines(file_path)
    
    updated_lines = lines.map do |line|
      # Update the "vsync" value
      if line.match?(/"vsync":\s*(true|false)/)
        line.sub(/"vsync":\s*(true|false)/, "\"vsync\": #{vsync_str}")
      # Update the "syncToRefreshrate" value
      elsif line.match?(/"syncToRefreshrate":\s*(true|false)/)
        if vsync_value
          # Set to true with a trailing comma
          line.sub(/"syncToRefreshrate":\s*(true|false),?/, "\"syncToRefreshrate\": #{sync_to_refresh_str}")
        else
          # Set to false without a trailing comma
          line.sub(/"syncToRefreshrate":\s*(true|false)/, "\"syncToRefreshrate\": #{sync_to_refresh_str},")
        end
      # Comment out "fixedFramerate" if vsync is true
      elsif vsync_value && line.match?(/"fixedFramerate":\s*\d+/)
        "//#{line.strip}" # Comment out the line
      # Uncomment "fixedFramerate" if vsync is false
      elsif !vsync_value && line.match?(/\/\/\s*"fixedFramerate":\s*\d+/)
        line.sub(/\/\/\s*/, '') # Uncomment the line
      else
        line # Return the line unchanged
      end
    end
    
    # Write the updated lines back to the file
    File.open(file_path, 'w') do |file|
      file.puts(updated_lines)
    end
    # Handle game restart after vsync value change
    message = $player ? _INTL("Cambiar el valor del vsync requiere reiniciar el juego.\nPodrás guardar antes de reiniciar.\n¿Deseas reiniciar ahora?") : _INTL("Cambiar el valor del vsync requiere reiniciar el juego.\n¿Deseas reiniciar ahora?")
    if Kernel.pbConfirmMessageSerious(message)
      pbSaveScreen if $player
      if System.is_really_windows?
        # Launch Game.exe and immediately exit the current process
        Thread.new do
          system('start "" "Game.exe"')
        end
        sleep(0.1) # Give the thread some time to execute
      else
        pbMessage(_INTL("Al no estar en Windows el juego no puede reiniciarse automáticamente.\nSe cerrará y deberás abrirlo manualmente"))
      end

      Kernel.exit!
    end
  end

  def language=(value)
    return if @language == value && !@force_set_options
    @language = value
    if Settings::LANGUAGES[@language]
      MessageTypes.load_message_files(Settings::LANGUAGES[@language][1])
    end
  end

  def skip_move_learning
    return @skip_move_learning || 1
  end

  def skip_move_learning=(value)
    return if @skip_move_learning == value && !@force_set_options
    @skip_move_learning = value
  end

  def main_volume
    return @main_volume || 100
  end

  def main_volume=(value)
    return if @main_volume == value && !@force_set_options
    @main_volume = value
    return if !$game_system
    if $game_system.playing_bgm
      playing_bgm = $game_system.getPlayingBGM
      $game_system.bgm_pause
      $game_system.bgm_resume(playing_bgm)
    end
    if $game_system.playing_bgs
      playing_bgs = $game_system.getPlayingBGS
      $game_system.bgs_pause
      $game_system.bgs_resume(playing_bgs)
    end
  end

  def bgmvolume
    return @bgmvolume || 80
  end

  def bgmvolume=(value)
    return if @bgmvolume == value && !@force_set_options
    @bgmvolume = value
    return if !$game_system || $game_system.playing_bgm.nil?
    playing_bgm = $game_system.getPlayingBGM
    $game_system.bgm_pause
    $game_system.bgm_resume(playing_bgm)
  end

  def sevolume
    return @sevolume || 100
  end

  def sevolume=(value)
    return if @sevolume == value && !@force_set_options
    @sevolume = value
    return if !$game_system || $game_system.playing_bgs.nil?
    playing_bgs = $game_system.getPlayingBGS
    $game_system.bgs_pause
    $game_system.bgs_resume(playing_bgs)
  end

  def pokemon_cry_volume
    return @pokemon_cry_volume || 100
  end

  def pokemon_cry_volume=(value)
    return if @pokemon_cry_volume == value && !@force_set_options
    @pokemon_cry_volume = value
  end

  def textspeed=(value)
    return if @textspeed == value && !@force_set_options
    @textspeed = value
    MessageConfig.pbSetTextSpeed(MessageConfig.pbSettingToTextSpeed(@textspeed))
  end

  def textskin=(value)
    return if @textskin == value && !@force_set_options
    @textskin = value
    MessageConfig.pbSetSpeechFrame("Graphics/Windowskins/" + Settings::SPEECH_WINDOWSKINS[@textskin])
  end

  def frame=(value)
    return if @frame == value && !@force_set_options
    @frame = value
    MessageConfig.pbSetSystemFrame("Graphics/Windowskins/" + Settings::MENU_WINDOWSKINS[@frame])
  end

  def screensize=(value)
    return if @screensize == value && !@force_set_options
    @screensize = value
    pbSetResizeFactor(@screensize)
  end

  def skip_texts
    return @skip_texts || 1
  end

  def skip_texts=(value)
    return if @skip_texts == value && !@force_set_options
    @skip_texts = value
  end

  # def controls
  #   reset_controls if !@controls
  #   return @controls
  # end

  # def reset_controls
  #   @controls ||= {}
  #   keys = Input::DEFAULT_INPUT_MAPPINGS.keys + Input::DEFAULT_INPUT_MAPPINGS_REMAPPABLE.keys
  #   keys.uniq!
  #   keys.each do |key|
  #     @controls[key] = []
  #     if Input::DEFAULT_INPUT_MAPPINGS_REMAPPABLE[key]
  #       @controls[key][0] = Input::DEFAULT_INPUT_MAPPINGS_REMAPPABLE[key][0]
  #       @controls[key][1] = Input::DEFAULT_INPUT_MAPPINGS_REMAPPABLE[key][1]
  #     end
  #   end
  # end

  #-----------------------------------------------------------------------------

  def reapply_all_options
    @force_set_options = true
    instance_variables.each do |ivar|
      option = ivar.to_s.delete_prefix("@").to_sym
      next if option == :force_set_options
      setter = :"#{option}="
      next unless respond_to?(setter)
      send(setter, send(option))
    end
    @force_set_options = false
  end
end

#===============================================================================
# Main list of options.
#===============================================================================
class UI::OptionsVisualsList < Window_DrawableCommand
  attr_writer   :baseColor, :shadowColor
  attr_accessor :optionColor, :optionShadowColor
  attr_accessor :selectedColor, :selectedShadowColor
  attr_accessor :unsetColor, :unsetShadowColor
  attr_reader   :value_changed
  attr_reader   :options

  # Offset vertical al dibujar el icono de entrada (input) dentro del rect
  OPTION_ICON_BLT_Y_OFFSET = 2
  # Espacio adicional entre icono de entrada y el texto del nombre de la opción
  OPTION_ICON_TEXT_GAP = 6
  # Separación entre los valores cuando hay exactamente 2 elementos en un array
  ARRAY_SPACING = 32
  # Espacio entre el slider y el número mostrado a su derecha
  SLIDER_NUMBER_GAP = 6
  # Alto de la barra del slider (en píxeles)
  SLIDER_BAR_HEIGHT = 4
  # Ancho del indicador (notch) del slider
  SLIDER_NOTCH_WIDTH = 8
  # Alto del indicador (notch) del slider
  SLIDER_NOTCH_HEIGHT = 16
  # Padding en pbDrawShadowText para texto del número del slider
  SLIDER_NUMBER_TEXT_PADDING = 2
  # Espaciado al dibujar corchetes de selección (izquierda)
  SELECTION_BRACKET_LEFT_PADDING = 2
  # Espaciado al dibujar corchetes de selección (derecha)
  SELECTION_BRACKET_RIGHT_PADDING = 0
  # Espaciado horizontal entre items en multiselect
  MULTISELECT_ITEM_SPACING = 8
  # Note: For :array and :multiselect, spacing is calculated to distribute items evenly across available width.
  # When scrolling, visible items are spaced as if they were the only items (original pre-scrolling behavior).
  # Navigation arrows (< >) appear automatically when items don't fit.

  def initialize(x, y, width, height, viewport)
    @input_icons_bitmap = AnimatedBitmap.new(UI::OptionsVisuals::UI_FOLDER + "input_icons")
    @left_arrow_bmp = Bitmap.new("Graphics/UI/left_arrow") rescue nil
    @right_arrow_bmp = Bitmap.new("Graphics/UI/right_arrow") rescue nil
    super(x, y, width, height, viewport)
    @index = -1
  end

  def dispose
    super
    @input_icons_bitmap.dispose
    @left_arrow_bmp&.dispose
    @right_arrow_bmp&.dispose
  end

  #-----------------------------------------------------------------------------

  def drawCursor(index, rect)
    # Hide cursor arrow when selecting tabs (self.index < 0)
    return Rect.new(rect.x + 16, rect.y, rect.width - 16, rect.height) if self.index < 0
    return super(index, rect)
  end

  def itemCount
    return @options&.length || 0
  end

  #-----------------------------------------------------------------------------

  def options=(new_options)
    @options = new_options
    self.top_row = 0
    get_values
    @array_second_value_x = 0
    @options.each do |option|
      next if option[:type] != :array || option[:parameters].length != 2
      text_width = self.contents.text_size(option[:parameters][0]).width
      @array_second_value_x = text_width if @array_second_value_x < text_width
    end
    @array_second_value_x += ARRAY_SPACING
    # Calculate similar spacing for multiselect options with 2 items
    @multiselect_second_value_x = 0
    @options.each do |option|
      next if option[:type] != :multiselect
      items = get_multiselect_items(option)
      next if items.length != 2
      fixed_checkbox = get_checkbox_text(false)  # Fixed width for stable layout
      text_width = self.contents.text_size(fixed_checkbox + items[0]).width
      @multiselect_second_value_x = text_width if @multiselect_second_value_x < text_width
    end
    @multiselect_second_value_x += ARRAY_SPACING
    refresh
  end

  def update_options_dynamically(new_options, current_option_id)
    @options = new_options
    get_values
    
    @array_second_value_x = 0
    @options.each do |option|
      next if option[:type] != :array || option[:parameters].length != 2
      text_width = self.contents.text_size(option[:parameters][0]).width
      @array_second_value_x = text_width if @array_second_value_x < text_width
    end
    @array_second_value_x += ARRAY_SPACING
    
    @multiselect_second_value_x = 0
    @options.each do |option|
      next if option[:type] != :multiselect
      items = get_multiselect_items(option)
      next if items.length != 2
      fixed_checkbox = get_checkbox_text(false)
      text_width = self.contents.text_size(fixed_checkbox + items[0]).width
      @multiselect_second_value_x = text_width if @multiselect_second_value_x < text_width
    end
    @multiselect_second_value_x += ARRAY_SPACING
    
    new_index = @options.index { |o| o[:option] == current_option_id }
    if new_index && !@options[new_index][:disabled_proc]&.call
      self.index = new_index
    else
      first_enabled = @options.index { |o| !o[:disabled_proc]&.call }
      self.index = first_enabled || 0
    end
  end

  def get_values
    @values = @options.map.with_index do |option, i|
      val = option[:get_proc]&.call
      # Convert actual value to offset for number sliders
      if option[:type] == :number_slider || (option[:type] == :number_type && option[:parameters].is_a?(Array))
        lowest = lowest_value(option)
        val = val - lowest if val
      end
      # For array, store selected index and scroll offset
      if [:array, :array_one, :arrow_option].include?(option[:type])
        selected = val.is_a?(Integer) ? val : 0
        val = { selected: selected, scroll: 0 }
      end
      # For multiselect, store current cursor position, selection array, and scroll offset
      if option[:type] == :multiselect
        selections = val.is_a?(Array) ? val : []
        val = { cursor: 0, selections: selections, scroll: 0 }
      end
      next val
    end
  end

  # Helper method to get multiselect items from parameters
  def get_multiselect_items(option)
    params = option[:parameters]
    return params if params.is_a?(Array) && !params[0].is_a?(Hash)
    return params[:items] if params.is_a?(Hash) && params[:items]
    return []
  end

  #-----------------------------------------------------------------------------
  # Common visibility/scrolling calculations
  #-----------------------------------------------------------------------------

  # Core method: count how many items fit in available_width.
  # Yields each index to obtain the display text for measurement.
  def calculate_items_visible(items, start_index, available_width)
    return 0 if items.empty? || start_index >= items.length
    current_width = 0
    visible_count = 0
    (start_index...items.length).each do |i|
      text_width = self.contents.text_size(yield(i)).width
      break unless current_width + text_width <= available_width
      current_width += text_width
      visible_count += 1
    end
    return [visible_count, 1].max
  end

  # Core method: calculate visible count accounting for scroll arrows.
  # Yields each index to obtain the display text for measurement.
  def calculate_actual_items_visible(items, scroll, available_width)
    return 0 if items.empty? || scroll >= items.length
    left_arrow_w  = self.contents.text_size("< ").width
    right_arrow_w = self.contents.text_size(" >").width
    has_previous = scroll > 0
    base_reserved = has_previous ? left_arrow_w : 0
    # First pass: assume right arrow present to calculate initial visible count
    visible_count = calculate_items_visible(items, scroll, available_width - base_reserved - right_arrow_w) { |i| yield(i) }
    visible_end = [scroll + visible_count, items.length].min
    has_next = visible_end < items.length
    reserved = base_reserved + (has_next ? right_arrow_w : 0)
    # Second pass: recalculate with actual reserved width
    visible_count = calculate_items_visible(items, scroll, available_width - reserved) { |i| yield(i) }
    visible_end = [scroll + visible_count, items.length].min
    has_next = visible_end < items.length
    # Shrink if total text width exceeds available space
    total_w = 0
    (scroll...visible_end).each { |i| total_w += self.contents.text_size(yield(i)).width }
    avail_w = available_width - reserved
    while visible_count > 1 && total_w > avail_w
      visible_count -= 1
      visible_end = scroll + visible_count
      has_next = visible_end < items.length
      reserved = base_reserved + (has_next ? right_arrow_w : 0)
      avail_w = available_width - reserved
      total_w = 0
      (scroll...visible_end).each { |i| total_w += self.contents.text_size(yield(i)).width }
    end
    return [visible_count, 1].max
  end

  # --- Convenience wrappers ---

  def calculate_array_visible(option, start_index, available_width)
    items = option[:parameters]
    calculate_items_visible(items, start_index, available_width) { |i| items[i] }
  end

  def calculate_multiselect_visible(option, start_index, available_width, _selections = [])
    items = get_multiselect_items(option)
    fixed_checkbox = get_checkbox_text(false)
    calculate_items_visible(items, start_index, available_width) { |i| fixed_checkbox + items[i] }
  end

  def calculate_actual_array_visible(option, scroll, available_width)
    items = option[:parameters]
    calculate_actual_items_visible(items, scroll, available_width) { |i| items[i] }
  end

  def calculate_actual_multiselect_visible(option, scroll, available_width, _selections = [])
    items = get_multiselect_items(option)
    fixed_checkbox = get_checkbox_text(false)
    calculate_actual_items_visible(items, scroll, available_width) { |i| fixed_checkbox + items[i] }
  end

  # Helper method to ensure scroll is consistent with the active position
  # Works for both :array/:array_one (selected) and :multiselect (cursor)
  def fix_scroll(this_index)
    option = @options[this_index]
    val = @values[this_index]
    return unless val.is_a?(Hash)
    type = option[:type]
    is_array = [:array, :array_one].include?(type)
    is_multiselect = (type == :multiselect)
    return unless is_array || is_multiselect
    # Determine the active position and the visibility calculator
    active_pos = is_array ? val[:selected] : val[:cursor]
    current_scroll = val[:scroll]
    available_width = (self.width - self.borderX) / 2 - 40
    calc_visible = proc do |from_scroll|
      if is_array
        calculate_actual_array_visible(option, from_scroll, available_width)
      else
        calculate_actual_multiselect_visible(option, from_scroll, available_width, val[:selections])
      end
    end
    visible_count = calc_visible.call(current_scroll)
    visible_end = current_scroll + visible_count
    # Already visible — no scroll change needed
    return if active_pos >= current_scroll && active_pos < visible_end
    if active_pos >= visible_end
      # Moving forward: jump to the start of the next page
      @values[this_index][:scroll] = visible_end
    else
      # Moving backward: walk pages from 0 to find the page containing active_pos
      new_scroll = 0
      loop do
        next_page = new_scroll + calc_visible.call(new_scroll)
        break if active_pos < next_page
        new_scroll = next_page
      end
      @values[this_index][:scroll] = new_scroll
    end
  end

  def lowest_value(option)
    case option[:type]
    when :number_type
      case option[:parameters]
      when Range
        return option[:parameters].begin
      when Array
        return option[:parameters][0] if option[:parameters][0]   # Parameter is [lowest, highest, interval]
      end
      raise _INTL("Opción {1} tiene parámetros inválidos.", option[:name])
    when :number_slider
      if option[:parameters].is_a?(Array) && option[:parameters][0]
        return option[:parameters][0]   # Parameter is [lowest, highest, interval]
      end
      raise _INTL("Opción {1} tiene parámetros inválidos.", option[:name])
    end
    raise _INTL("Opción {1} tiene un valor más bajo indefinido.", option[:name])
  end

  def highest_value(option)
    case option[:type]
    when :number_type
      case option[:parameters]
      when Range
        return option[:parameters].end
      when Array
        return option[:parameters][1] if option[:parameters][1]   # Parameter is [lowest, highest, interval]
      end
      raise _INTL("Opción {1} tiene parámetros inválidos.", option[:name])
    when :number_slider
      if option[:parameters].is_a?(Array) && option[:parameters][1]
        return option[:parameters][1]   # Parameter is [lowest, highest, interval]
      end
      raise _INTL("Opción {1} tiene parámetros inválidos.", option[:name])
    end
    raise _INTL("Opción {1} tiene un valor más alto indefinido.", option[:name])
  end

  def previous_value(this_index)
    option = @options[this_index]
    case option[:type]
    when :toggle
      return (@values[this_index] == 0) ? 1 : 0  
    when :array, :array_one, :arrow_option
      current_selected = @values[this_index][:selected]
      current_scroll = @values[this_index][:scroll]
      new_selected = current_selected - 1
      if new_selected < 0
        new_selected = (option[:type] == :arrow_option) ? 0 : option[:parameters].length - 1
      end
      return { selected: new_selected, scroll: current_scroll }
    when :multiselect
      items = get_multiselect_items(option)
      current_cursor = @values[this_index][:cursor]
      current_scroll = @values[this_index][:scroll]
      
      new_cursor = current_cursor - 1
      # Wrap around if at start
      if new_cursor < 0
        new_cursor = items.length - 1
      end
      
      # Scroll will be adjusted by fix_scroll
      return { cursor: new_cursor, selections: @values[this_index][:selections], scroll: current_scroll }
    when :number_type
      case option[:parameters]
      when Range
        ret = @values[this_index] - 1
        ret = highest_value(option) - lowest_value(option) if ret < 0   # Wrap around
        return ret
      when Array
        highest = highest_value(option)
        lowest = lowest_value(option)
        interval = option[:parameters][2]
        if @values[this_index] > 0
          ret = @values[this_index] - interval
          ret = 0 if ret < 0
        else
          ret = highest - lowest   # Wrap around
        end
        return ret
      end
    when :number_slider
      highest = highest_value(option)
      lowest = lowest_value(option)
      interval = option[:parameters][2]
      if @values[this_index] > 0
        ret = @values[this_index] - interval
        ret = lowest if ret < lowest
        return ret
      end
    end
    return @values[this_index]
  end

  def next_value(this_index)
    option = @options[this_index]
    case option[:type]
    when :toggle
      return (@values[this_index] == 0) ? 1 : 0  
    when :array, :array_one, :arrow_option
      current_selected = @values[this_index][:selected]
      current_scroll = @values[this_index][:scroll]
      new_selected = current_selected + 1
      if new_selected >= option[:parameters].length
        new_selected = (option[:type] == :arrow_option) ? option[:parameters].length - 1 : 0
      end
      return { selected: new_selected, scroll: current_scroll }
    when :multiselect
      items = get_multiselect_items(option)
      current_cursor = @values[this_index][:cursor]
      current_scroll = @values[this_index][:scroll]
      
      new_cursor = current_cursor + 1
      # Wrap around if at end
      if new_cursor >= items.length
        new_cursor = 0
      end
      
      # Scroll will be adjusted by fix_scroll
      return { cursor: new_cursor, selections: @values[this_index][:selections], scroll: current_scroll }
    when :number_type
      case option[:parameters]
      when Range
        ret = @values[this_index] + 1
        ret = 0 if ret > highest_value(option) - lowest_value(option)   # Wrap around
        return ret
      when Array
        highest = highest_value(option)
        lowest = lowest_value(option)
        interval = option[:parameters][2]
        if @values[this_index] < highest - lowest
          ret = @values[this_index] + interval
          ret = highest - lowest if ret > highest - lowest
        else
          ret = 0   # Wrap around
        end
        return ret
      end
    when :number_slider
      highest = highest_value(option)
      lowest = lowest_value(option)
      interval = option[:parameters][2]
      if @values[this_index] < highest - lowest
        ret = @values[this_index] + interval
        ret = highest - lowest if ret > highest - lowest
        return ret
      end
    end
    return @values[this_index]
  end

  def value(this_index = nil)
    idx = this_index || self.index
    val = @values[idx]
    # Convert offset back to actual value for number sliders
    option = @options[idx]
    if option[:type] == :number_slider || (option[:type] == :number_type && option[:parameters].is_a?(Array))
      lowest = lowest_value(option)
      val = val + lowest if val
    end
    # For array, return only the selected index
    if [:array, :array_one, :arrow_option].include?(option[:type])
      val = val[:selected] if val.is_a?(Hash)
    end
    # For multiselect, return only the selections array
    if option[:type] == :multiselect
      val = val[:selections] if val.is_a?(Hash)
    end
    return val
  end

  def selected_option
    return @options[self.index]
  end

  #-----------------------------------------------------------------------------

  def drawItem(this_index, _count, rect)
    rect = drawCursor(this_index, rect)
    option_start_x = (rect.x + rect.width) / 2
    draw_option_name(this_index, rect, option_start_x)
    draw_option_values(this_index, rect, option_start_x) if this_index < @options.length
  end

  def draw_option_name(this_index, rect, option_start_x)
    if this_index >= @options.length
      pbDrawShadowText(self.contents, rect.x, rect.y, option_start_x, rect.height,
                       _INTL("Atrás"), self.baseColor, self.shadowColor)
      return
    end
    option = @options[this_index]
    option_name = option[:name]
    option_name_x = rect.x
    
    is_disabled = option[:disabled_proc]&.call
    c_base   = is_disabled ? self.unsetColor : self.baseColor
    c_shadow = is_disabled ? self.unsetShadowColor : self.shadowColor
    c_opt    = is_disabled ? self.unsetColor : self.optionColor
    c_opt_sh = is_disabled ? self.unsetShadowColor : self.optionShadowColor

    option_colors = [c_opt, c_opt_sh]
    case option[:type]
    when :control
      # Draw icon
      input_index = UI::BaseVisuals::INPUT_ICONS_ORDER.index(option[:parameters]) || 0
      src_rect = Rect.new(input_index * @input_icons_bitmap.height, 0,
                          @input_icons_bitmap.height, @input_icons_bitmap.height)
      self.contents.blt(rect.x, rect.y + OPTION_ICON_BLT_Y_OFFSET, @input_icons_bitmap.bitmap, src_rect)
      # Adjust text position
      option_name_x += @input_icons_bitmap.height + OPTION_ICON_TEXT_GAP
    when :use
      option_colors = [c_base, c_shadow]
    end
    pbDrawShadowText(self.contents, option_name_x, rect.y, option_start_x, rect.height,
                     option_name, *option_colors)
  end

  def draw_option_values(this_index, rect, option_start_x)
    option_width = rect.x + rect.width - option_start_x
    option = @options[this_index]

    is_disabled = option[:disabled_proc]&.call
    c_base   = is_disabled ? self.unsetColor : self.baseColor
    c_shadow = is_disabled ? self.unsetShadowColor : self.shadowColor
    c_sel    = is_disabled ? self.unsetColor : self.selectedColor
    c_sel_sh = is_disabled ? self.unsetShadowColor : self.selectedShadowColor

    case option[:type]
    when :array, :array_one
      items = option[:parameters]
      scroll = @values[this_index][:scroll]
      selected = @values[this_index][:selected]
      
      # Calculate available width for items (matches spacing calculation)
      available_width = rect.width - option_start_x
      
      # Check if all items actually fit WITH realistic spacing
      # Calculate total width including minimum spacing between items
      total_text_width = 0
      items.each { |v| total_text_width += self.contents.text_size(v).width }
      min_realistic_spacing = items.length > 1 ? (items.length - 1) * 16 : 0  # 16px minimum between items
      all_items_fit = (total_text_width + min_realistic_spacing <= available_width)
      
      if all_items_fit
        # All items fit - draw them all with distributed spacing
        spacing = 0
        if items.length > 1
          spacing = (rect.width - option_start_x - total_text_width) / (items.length - 1)
          spacing = 0 if spacing < 0
        end
        x_pos = option_start_x
        items.each_with_index do |value, i|
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                           value,
                           (i == selected) ? c_sel : c_base,
                           (i == selected) ? c_sel_sh : c_shadow)
          # Use special spacing for 2-item arrays
          if items.length == 2 && i == 0
            x_pos += @array_second_value_x
          else
            x_pos += self.contents.text_size(value).width + spacing
          end
        end
      else
        # Scrolling logic - show subset with arrows
        x_pos = option_start_x
        left_arrow_width = self.contents.text_size("< ").width
        right_arrow_width = self.contents.text_size(" >").width
        
        # Determine if we need arrows based on scroll position and total items
        has_previous = scroll > 0
        
        # Calculate reserved width for arrows
        reserved_width = 0
        reserved_width += left_arrow_width if has_previous
        
        # Always reserve space for right arrow to calculate if we need it
        test_reserved_width = reserved_width + right_arrow_width
        visible_count = calculate_array_visible(option, scroll, available_width - test_reserved_width)
        visible_end = [scroll + visible_count, items.length].min
        has_next = visible_end < items.length
        
        # Set final reserved width based on which arrows we actually need
        reserved_width += right_arrow_width if has_next
        
        # Recalculate visible count with correct reserved width
        visible_count = calculate_array_visible(option, scroll, available_width - reserved_width)
        visible_end = [scroll + visible_count, items.length].min
        # Recalculate has_next with the final visible_end
        has_next = visible_end < items.length
        
        # Calculate spacing based on VISIBLE items only (original behavior)
        visible_total_width = 0
        (scroll...visible_end).each { |i| visible_total_width += self.contents.text_size(items[i]).width }
        visible_available_width = available_width - reserved_width
        
        # Check if items actually fit with distributed spacing + arrows
        # If not, reduce visible count until they fit
        while visible_count > 1 && visible_total_width > visible_available_width
          visible_count -= 1
          visible_end = scroll + visible_count
          has_next = visible_end < items.length
          # Recalculate reserved width
          reserved_width = 0
          reserved_width += left_arrow_width if has_previous
          reserved_width += right_arrow_width if has_next
          visible_available_width = available_width - reserved_width
          # Recalculate total width
          visible_total_width = 0
          (scroll...visible_end).each { |i| visible_total_width += self.contents.text_size(items[i]).width }
        end
        
        visible_spacing = 0
        if visible_count > 1
          visible_spacing = (visible_available_width - visible_total_width) / (visible_count - 1)
          visible_spacing = 0 if visible_spacing < 0
        end
        
        # Draw left arrow if there are previous items
        if has_previous
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                           "< ", c_base, c_shadow)
          x_pos += left_arrow_width
        end
        
        # Draw visible items with spacing calculated from visible items only
        (scroll...visible_end).each do |i|
          value = items[i]
          is_selected = (i == selected)
          
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                           value,
                           is_selected ? c_sel : c_base,
                           is_selected ? c_sel_sh : c_shadow)
          x_pos += self.contents.text_size(value).width
          x_pos += visible_spacing if i < visible_end - 1
        end
        
        # Draw right arrow if there are more items
        if has_next
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                           " >", c_base, c_shadow)
        end
      end
    when :arrow_option
      items = option[:parameters]
      selected = @values[this_index][:selected]
      value_text = items[selected]
      
      width_area = option_width - rect.x
      center_x = option_start_x + (width_area / 2)
      
      # Dibujar texto centrado (align = 1)
      pbDrawShadowText(self.contents, option_start_x, rect.y, width_area, rect.height,
                       value_text,
                       (this_index == self.index) ? c_sel : c_base,
                       (this_index == self.index) ? c_sel_sh : c_shadow,
                       1)
                       
      # Dibujar flechas animadas si está seleccionado
      if this_index == self.index
        total_frames = 8
        current_frame = (System.uptime * 10).to_i % total_frames
        arrow_padding = 70
        
        if @right_arrow_bmp && selected < items.length - 1
          frame_height = @right_arrow_bmp.height / total_frames
          frame_width  = @right_arrow_bmp.width
          src_rect = Rect.new(0, current_frame * frame_height, frame_width, frame_height)
          y_pos = rect.y + (rect.height - frame_height) / 2
          self.contents.blt(center_x + arrow_padding, y_pos, @right_arrow_bmp, src_rect)
        end
        
        if @left_arrow_bmp && selected > 0
          frame_height = @left_arrow_bmp.height / total_frames
          frame_width  = @left_arrow_bmp.width
          src_rect = Rect.new(0, current_frame * frame_height, frame_width, frame_height)
          y_pos = rect.y + (rect.height - frame_height) / 2
          self.contents.blt(center_x - arrow_padding - frame_width, y_pos, @left_arrow_bmp, src_rect)
        end
      end  
    when :number_type
      lowest = lowest_value(option)
      highest = highest_value(option)
      value = _INTL("Tipo {1}/{2}", lowest + @values[this_index], highest - lowest + 1)
      pbDrawShadowText(self.contents, option_start_x, rect.y, option_width, rect.height,
                       value, c_base, c_shadow)
    when :number_slider
      lowest = lowest_value(option)
      highest = highest_value(option)
      spacing = SLIDER_NUMBER_GAP   # Gap between slider and number
      # Draw slider bar
      slider_length = option_width - rect.x - self.contents.text_size(highest.to_s).width - spacing
      x_pos = option_start_x
      self.contents.fill_rect(x_pos, rect.y + (rect.height / 2) - (SLIDER_BAR_HEIGHT / 2), slider_length, SLIDER_BAR_HEIGHT, self.baseColor)
      # Draw slider notch
      self.contents.fill_rect(
        x_pos + ((slider_length - SLIDER_NOTCH_WIDTH) * @values[this_index] / (highest - lowest)),
        rect.y + (rect.height / 2) - (SLIDER_NOTCH_HEIGHT / 2),
        SLIDER_NOTCH_WIDTH, SLIDER_NOTCH_HEIGHT, c_sel
      )
      # Draw text
      value = (lowest + @values[this_index]).to_s
      pbDrawShadowText(self.contents, x_pos - rect.x + 2, rect.y - 2, option_width, rect.height,
                       value, c_sel, c_sel_sh, SLIDER_NUMBER_TEXT_PADDING)
    when :control
      x_pos = option_start_x
      spacing = option_width / 2
      @values[this_index].each_with_index do |value, i|
        if value
          text = Input.input_name(value, (i == 0) ? :keyboard : :gamepad)
          text_colors = [c_base, c_shadow]
        else
          text = "---"
          text_colors = [self.unsetColor, self.unsetShadowColor]
        end
        pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                         text, *text_colors)
        x_pos += spacing
      end
    when :toggle
      val = @values[this_index] || 0
      is_on = (val == 0) 
      is_disabled = option[:disabled_proc]&.call
      
      if option[:parameters].is_a?(Array) && option[:parameters].length >= 2
        text_val = option[:parameters][val].to_s
        if option[:parameters][0].to_s.match?(/^(no|off|apagado|falso|false)$/i)
          is_on = (val == 1)
        end
      else
        text_val = is_on ? _INTL("ON") : _INTL("OFF")
      end
      
      toggle_w = 42
      toggle_h = 22
      x_pos = option_start_x
      y_pos = rect.y + (rect.height - toggle_h) / 2
      knob_size = 18
      
      # Posiciones extremas del botón
      knob_off_x = x_pos + 2
      knob_on_x  = x_pos + toggle_w - knob_size - 2
      
      if is_disabled
        border_color = Color.new(80, 80, 80)
        bg_off       = Color.new(120, 120, 120)
        bg_on        = Color.new(120, 120, 120)
        knob_base    = Color.new(180, 180, 180)
        knob_shadow  = Color.new(150, 150, 150)
        text_color   = self.unsetColor
        text_shadow  = self.unsetShadowColor
      else
        border_color = Color.new(50, 50, 58)
        bg_off       = Color.new(100, 100, 110)
        bg_on        = Color.new(46, 204, 113)
        knob_base    = Color.new(245, 245, 245)
        knob_shadow  = Color.new(180, 180, 190)
        text_color   = is_on ? self.selectedColor : self.baseColor
        text_shadow  = is_on ? self.selectedShadowColor : self.shadowColor
      end
      
      # --- LÓGICA DE ANIMACIÓN ---
      @toggle_animations ||= {}
      anim = @toggle_animations[this_index]
      
      # state_progress va de 0.0 (Totalmente OFF) a 1.0 (Totalmente ON)
      state_progress = is_on ? 1.0 : 0.0
      
      if anim && (System.uptime - anim[:start] < anim[:duration]) && !is_disabled
        anim_progress = (System.uptime - anim[:start]) / anim[:duration]
        anim_progress = 1.0 - (1.0 - anim_progress)**3 # Ease-out cubic
        
        start_is_on = (anim[:from] == 0)
        end_is_on   = (anim[:to] == 0)
        
        if option[:parameters].is_a?(Array) && option[:parameters].length >= 2
          if option[:parameters][0].to_s.match?(/^(no|off|apagado|falso|false)$/i)
            start_is_on = (anim[:from] == 1)
            end_is_on   = (anim[:to] == 1)
          end
        end
        
        if start_is_on && !end_is_on
          state_progress = 1.0 - anim_progress # Se está apagando
        elsif !start_is_on && end_is_on
          state_progress = anim_progress       # Se está encendiendo
        end
      end
      
      # Calcular posición X del botón basada en el progreso
      knob_x = knob_off_x + (knob_on_x - knob_off_x) * state_progress
      # -----------------------------------------
      
      # Dibujar Borde
      self.contents.fill_rect(x_pos + 1, y_pos, toggle_w - 2, toggle_h, border_color)
      self.contents.fill_rect(x_pos, y_pos + 1, toggle_w, toggle_h - 2, border_color)
      
      # Dibujar Fondo Gris
      self.contents.fill_rect(x_pos + 2, y_pos + 2, toggle_w - 4, toggle_h - 4, bg_off)
      
      # Dibujar Fondo Verde
      green_w = ((toggle_w - 4) * state_progress).round
      if green_w > 0
        self.contents.fill_rect(x_pos + 2, y_pos + 2, green_w, toggle_h - 4, bg_on)
      end
      
      # Dibujar Botón
      knob_y = y_pos + 2
      self.contents.fill_rect(knob_x, knob_y, knob_size, knob_size, knob_shadow)
      self.contents.fill_rect(knob_x, knob_y, knob_size - 1, knob_size - 1, knob_base)
      
      # Dibujar Texto
      text_x = x_pos + toggle_w + 10
      pbDrawShadowText(self.contents, text_x, rect.y, option_width, rect.height,
                       text_val, text_color, text_shadow)
    when :use
      # Draw nothing
    when :submenu
      color = (this_index == self.index) ? c_sel : c_base
      shadow = (this_index == self.index) ? c_sel_sh : c_shadow
      pbDrawShadowText(self.contents, option_start_x, rect.y, option_width, rect.height,
                       ">", color, shadow, 1)
    when :multiselect
      items = get_multiselect_items(option)
      scroll = @values[this_index][:scroll]
      cursor_index = @values[this_index][:cursor]
      selections = @values[this_index][:selections]
      
      # Calculate available width for items (matches spacing calculation)
      available_width = rect.width - option_start_x
      
      # Use a fixed checkbox string for all layout/width decisions so toggling
      # selections never causes all_items_fit to flip and arrows to appear/disappear
      fixed_checkbox = get_checkbox_text(false)
      
      # Check if all items actually fit WITH realistic spacing
      # Calculate total width including minimum spacing between items
      total_text_width = 0
      items.each do |v|
        total_text_width += self.contents.text_size(fixed_checkbox + v).width
      end
      min_realistic_spacing = items.length > 1 ? (items.length - 1) * 16 : 0  # 16px minimum between items
      all_items_fit = (total_text_width + min_realistic_spacing <= available_width)
      
      if all_items_fit
        # All items fit - draw them all with distributed spacing
        # Use fixed checkbox for spacing calculation to keep layout stable
        total_width = total_text_width
        spacing = 0
        if items.length > 1
          spacing = (rect.width - option_start_x - total_width) / (items.length - 1)
          spacing = 0 if spacing < 0
        end
        x_pos = option_start_x
        items.each_with_index do |value, i|
          is_selected = @values[this_index][:selections].include?(i)
          is_cursor = (i == cursor_index)
          checkbox = get_checkbox_text(is_selected)
          text_value = checkbox + value
          
          # Use selected colors for cursor position
          if is_cursor
            color = self.selectedColor
            shadow_color = self.selectedShadowColor
          else
            color = self.baseColor
            shadow_color = self.shadowColor
          end
          
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                           text_value, color, shadow_color)
          # Use special spacing for 2-item multiselect to match array behavior
          if items.length == 2 && i == 0
            x_pos += @multiselect_second_value_x
          else
            # Advance using fixed checkbox width so spacing matches spacing calculation
            x_pos += self.contents.text_size(fixed_checkbox + value).width + spacing
          end
        end
      else
        # Scrolling logic - show subset with arrows
        x_pos = option_start_x
        left_arrow_width = self.contents.text_size("< ").width
        right_arrow_width = self.contents.text_size(" >").width
        
        # Determine if we need arrows based on scroll position and total items
        has_previous = scroll > 0
        
        # Calculate reserved width for arrows
        reserved_width = 0
        reserved_width += left_arrow_width if has_previous
        
        # Always reserve space for right arrow to calculate if we need it
        test_reserved_width = reserved_width + right_arrow_width
        visible_count = calculate_multiselect_visible(option, scroll, available_width - test_reserved_width, selections)
        visible_end = [scroll + visible_count, items.length].min
        has_next = visible_end < items.length
        
        # Set final reserved width based on which arrows we actually need
        reserved_width += right_arrow_width if has_next
        
        # Recalculate visible count with correct reserved width
        visible_count = calculate_multiselect_visible(option, scroll, available_width - reserved_width, selections)
        visible_end = [scroll + visible_count, items.length].min
        # Recalculate has_next with the final visible_end
        has_next = visible_end < items.length
        
        # Calculate spacing using fixed checkbox width to keep layout stable
        visible_total_width = 0
        (scroll...visible_end).each do |i|
          visible_total_width += self.contents.text_size(fixed_checkbox + items[i]).width
        end
        visible_available_width = available_width - reserved_width
        
        # Check if items actually fit with distributed spacing + arrows
        # If not, reduce visible count until they fit
        while visible_count > 1 && visible_total_width > visible_available_width
          visible_count -= 1
          visible_end = scroll + visible_count
          has_next = visible_end < items.length
          # Recalculate reserved width
          reserved_width = 0
          reserved_width += left_arrow_width if has_previous
          reserved_width += right_arrow_width if has_next
          visible_available_width = available_width - reserved_width
          # Recalculate total width
          visible_total_width = 0
          (scroll...visible_end).each do |i|
            visible_total_width += self.contents.text_size(fixed_checkbox + items[i]).width
          end
        end
        
        visible_spacing = 0
        if visible_count > 1
          visible_spacing = (visible_available_width - visible_total_width) / (visible_count - 1)
          visible_spacing = 0 if visible_spacing < 0
        end
        
        # Draw left arrow if there are previous items
        if has_previous
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                           "< ", self.baseColor, self.shadowColor)
          x_pos += left_arrow_width
        end
        
        # Draw visible items with spacing calculated from visible items only
        (scroll...visible_end).each do |i|
          value = items[i]
          is_selected = @values[this_index][:selections].include?(i)
          is_cursor = (i == cursor_index)
          checkbox = get_checkbox_text(is_selected)
          text_value = checkbox + value
          
          # Use selected colors for cursor position
          if is_cursor
            color = self.selectedColor
            shadow_color = self.selectedShadowColor
          else
            color = self.baseColor
            shadow_color = self.shadowColor
          end
          
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                           text_value, color, shadow_color)
          # Advance using fixed checkbox width so spacing matches visible_spacing calculation
          x_pos += self.contents.text_size(fixed_checkbox + value).width
          x_pos += visible_spacing if i < visible_end - 1
        end
        
        # Draw right arrow if there are more items
        if has_next
          pbDrawShadowText(self.contents, x_pos, rect.y, option_width, rect.height,
                           " >", self.baseColor, self.shadowColor)
        end
      end
    else
      val_index = @values[this_index] || 0
      if option[:parameters].is_a?(Array) && val_index.is_a?(Integer) && val_index < option[:parameters].length
        value = option[:parameters][val_index].to_s
      else
        value = ""
      end
      pbDrawShadowText(self.contents, option_start_x, rect.y, option_width, rect.height,
                       value, c_base, c_shadow)
    end
  end

  def get_checkbox_text(value)
    return value ? "[X] " : "[  ] "
  end

  def draw_selection_brackets(text_x, text_y, text, rect, option_width)
    pbDrawShadowText(self.contents, text_x - option_width, text_y, option_width, rect.height,
                     "[", self.selectedColor, self.selectedShadowColor, SELECTION_BRACKET_LEFT_PADDING)
    pbDrawShadowText(self.contents, text_x + self.contents.text_size(text).width, text_y, option_width, rect.height,
                     "]", self.selectedColor, self.selectedShadowColor, SELECTION_BRACKET_RIGHT_PADDING)
  end

  #-----------------------------------------------------------------------------

  def update
    if @index < 0
      # Hide up/down arrows when in tab selection mode
      @uparrow.visible = false if @uparrow
      @downarrow.visible = false if @downarrow
      return
    end
    old_index = self.index
    @value_changed = false

    # --- SALTO DE OPCIONES DESHABILITADAS ---
    if @index >= 0 && @options.length > 0
      if Input.repeat?(Input::UP)
        new_index = @index
        loop do
          new_index -= 1
          new_index = @options.length - 1 if new_index < 0
          break if !@options[new_index][:disabled_proc]&.call || new_index == @index
        end
        if new_index != @index
          pbPlayCursorSE
          self.index = new_index
          @ignore_input = true
        end
      elsif Input.repeat?(Input::DOWN)
        new_index = @index
        loop do
          new_index += 1
          new_index = 0 if new_index >= @options.length
          break if !@options[new_index][:disabled_proc]&.call || new_index == @index
        end
        if new_index != @index
          pbPlayCursorSE
          self.index = new_index
          @ignore_input = true
        end
      end
    end
    # ----------------------------------------

    super
    # Hide up/down arrows when in tab selection mode (also after super call)
    @ignore_input = false    
    if self.index < 0
      @uparrow.visible = false if @uparrow
      @downarrow.visible = false if @downarrow
    end
    
    need_refresh = (self.index != old_index)
    
    # --- CONTROL DE ANIMACIONES DEL TOGGLE ---
    @toggle_animations ||= {}
    animating = false
    @toggle_animations.each_key do |idx|
      if System.uptime - @toggle_animations[idx][:start] < @toggle_animations[idx][:duration]
        animating = true
      else
        @toggle_animations.delete(idx)
        need_refresh = true
      end
    end
    need_refresh = true if animating
    # -----------------------------------------

    if self.index < @options.length &&
       [:array, :array_one, :number_type, :number_slider, :multiselect, :arrow_option, :toggle].include?(@options[self.index][:type])
      
      is_disabled = @options[self.index][:disabled_proc]&.call
      old_value = self.value
      old_raw_value = @values[self.index]
      cursor_moved = false
      
      if Input.repeat?(Input::LEFT)
        if is_disabled
          pbPlayBuzzerSE
        else
          @values[self.index] = previous_value(self.index)
          cursor_moved = true
        end
      elsif Input.repeat?(Input::RIGHT)
        if is_disabled
          pbPlayBuzzerSE
        else
          @values[self.index] = next_value(self.index)
          cursor_moved = true
        end
      end
      
      if (@options[self.index][:type] == :multiselect || @options[self.index][:type] == :toggle) && Input.trigger?(Input::USE)
        if is_disabled
          pbPlayBuzzerSE
        else
          if @options[self.index][:type] == :toggle
            @values[self.index] = (@values[self.index] == 0) ? 1 : 0
          else
            cursor_pos = @values[self.index][:cursor]
            scroll_pos = @values[self.index][:scroll]
            selections = @values[self.index][:selections].clone
            if selections.include?(cursor_pos)
              selections.delete(cursor_pos)
            else
              selections.push(cursor_pos)
            end
            # Preserve the full hash structure with scroll
            @values[self.index] = { cursor: cursor_pos, selections: selections, scroll: scroll_pos }
          end
          pbPlayDecisionSE
          need_refresh = true
          @value_changed = true
        end
      end
      
      if self.value != old_value
        # --- REGISTRAR ANIMACIÓN SI ES UN TOGGLE ---
        if @options[self.index][:type] == :toggle
          @toggle_animations[self.index] = {
            start: System.uptime,
            duration: 0.15,
            from: old_raw_value,
            to: @values[self.index]
          }
        end
        # -------------------------------------------
        
        pbPlayCursorSE if selected_option[:type] != :number_slider
        need_refresh = true
        @value_changed = true
      end
      # Ensure scroll stays consistent (only when cursor moved)
      if cursor_moved
        fix_scroll(self.index) if [:array, :array_one, :multiselect].include?(@options[self.index][:type])
      end
    end
    if self.index >= 0 && self.index < @options.length && @options[self.index][:type] == :arrow_option
      need_refresh = true
    end
    
    refresh if need_refresh
  end
end

#===============================================================================
#
#===============================================================================
class UI::OptionsVisuals < UI::BaseVisuals
  attr_reader :page
  attr_reader :in_load_screen

  GRAPHICS_FOLDER   = "Options/"   # Subfolder in Graphics/UI
  TEXT_COLOR_THEMES = {   # Themes not in DEFAULT_TEXT_COLOR_THEMES
    :page_name        => [Color.new(248, 248, 248), Color.new(168, 184, 184)],
    :option_name      => [Color.new(192, 120, 0), Color.new(248, 176, 80)],
    :unselected_value => [Color.new(80, 80, 88), Color.new(160, 160, 168)],
    :selected_value   => [Color.new(248, 48, 24), Color.new(248, 136, 128)],
    :unset_control    => [Color.new(160, 160, 168), Color.new(224, 224, 232)]
  }
  OPTIONS_VISIBLE  = 6
  PAGE_TAB_SPACING = 4
  MAX_VISIBLE_TABS = 4   # Maximum number of tabs visible per page
  START_Y = 64
  OPTION_SPACING = 32
  PAGE_DOTS_X = 57
  PAGE_DOTS_Y = 4
  PAGE_NAME_Y = 14

  #-----------------------------------------------------------------------------

  def initialize(options, in_load_screen = false, menu = :options_menu)
    @options        = options
    @in_load_screen = in_load_screen
    @menu           = menu
    @page               = all_pages.first
    @tab_scroll         = 0   # Track which tab is the leftmost visible
    @is_submenu         = false
    @submenu_pages      = nil  # Non-nil when the active submenu has its own tab set
    @submenu_tab_scroll = 0
    super()
  end

  def initialize_bitmaps
    super
    @bitmaps[:page_icons] = AnimatedBitmap.new(graphics_folder + "page_icons")
  end

  def initialize_message_box
    super
    @sprites[:speech_box].letterbyletter = false
    @sprites[:speech_box].visible        = true
  end

  def initialize_sprites
    initialize_page_tabs
    initialize_page_cursor
    initialize_options_list
  end

  def initialize_page_tabs
    # Always allocate the maximum number of tab slots so submenu tabs (which may
    # exceed the number of main-menu tabs) have enough room to render.
    add_overlay(:page_icons,
                MAX_VISIBLE_TABS * ((@bitmaps[:page_icons].width / 2) + PAGE_TAB_SPACING),
                @bitmaps[:page_icons].height + 16)  # Extra height for page dots
    # @sprites[:page_icons].x = Graphics.width - @sprites[:page_icons].width
    @sprites[:page_icons].x = PAGE_DOTS_X
    @sprites[:page_icons].y = PAGE_DOTS_Y
  end

  def initialize_page_cursor
    add_icon_sprite(:page_cursor, @sprites[:page_icons].x - 2, @sprites[:page_icons].y - 2,
                    graphics_folder + "page_cursor")
    @sprites[:page_cursor].z = 1100
  end

  def initialize_options_list
    @sprites[:options_list] = UI::OptionsVisualsList.new(0, START_Y, Graphics.width, (OPTIONS_VISIBLE * OPTION_SPACING) + OPTION_SPACING, @viewport)
    @sprites[:options_list].optionColor         = get_text_color_theme(:option_name)[0]
    @sprites[:options_list].optionShadowColor   = get_text_color_theme(:option_name)[1]
    @sprites[:options_list].baseColor           = get_text_color_theme(:unselected_value)[0]
    @sprites[:options_list].shadowColor         = get_text_color_theme(:unselected_value)[1]
    @sprites[:options_list].selectedColor       = get_text_color_theme(:selected_value)[0]
    @sprites[:options_list].selectedShadowColor = get_text_color_theme(:selected_value)[1]
    @sprites[:options_list].unsetColor          = get_text_color_theme(:unset_control)[0]
    @sprites[:options_list].unsetShadowColor    = get_text_color_theme(:unset_control)[1]
    @sprites[:options_list].options             = options_for_page(@page)
  end

  #-----------------------------------------------------------------------------

  def all_pages
    @all_pages_cache ||= begin
      ret = []
      PageHandlers.each_available(@menu) do |page, hash, name|
        ret.push([page, hash[:order] || 0])
      end
      ret.sort_by! { |val| val[1] }
      ret.map! { |val| val[0] }
      ret
    end
  end

  def invalidate_pages_cache
    @all_pages_cache = nil
  end

  def set_page(value)
    return if @page == value
    @page = value
    update_tab_page
    @sprites[:options_list].options = options_for_page(@page)
    refresh
  end

  def update_tab_page
    page_index = all_pages.index(@page)
    return if !page_index
    
    pages_length = all_pages.length
    return if pages_length <= MAX_VISIBLE_TABS
    
    # Calculate which "page" of tabs this belongs to
    # If we're navigating to a tab outside the current page, switch pages
    current_page_start = @tab_scroll
    current_page_end = @tab_scroll + MAX_VISIBLE_TABS
    
    if page_index < current_page_start || page_index >= current_page_end
      # Calculate which page this tab is on
      tab_page_number = page_index / MAX_VISIBLE_TABS
      @tab_scroll = tab_page_number * MAX_VISIBLE_TABS
      
      # Make sure we don't scroll past the last complete page
      max_scroll = ((pages_length - 1) / MAX_VISIBLE_TABS) * MAX_VISIBLE_TABS
      @tab_scroll = [@tab_scroll, max_scroll].min
    end
  end

  def go_to_next_page
    pages = all_pages
    page_number = pages.index(@page)
    new_page = pages[(page_number + 1) % pages.length]
    return if new_page == @page
    pbPlayCursorSE
    set_page(new_page)
  end

  def go_to_previous_page
    pages = all_pages
    page_number = pages.index(@page)
    new_page = pages[(page_number - 1) % pages.length]
    return if new_page == @page
    pbPlayCursorSE
    set_page(new_page)
  end

  def index
    return @sprites[:options_list].index
  end

  def set_index(value)
    old_index = index
    @sprites[:options_list].index = value
    refresh_on_index_changed(old_index)
  end

  def options_for_page(this_page)
    return @options.filter do |option|
      next false if option[:page] != this_page
      next false if option[:visible_proc] && !option[:visible_proc].call
      next true
    end
  end

  def selected_option
    return @sprites[:options_list].selected_option
  end

  #-----------------------------------------------------------------------------

  def refresh
    super
    refresh_page_tabs
    refresh_page_cursor
    refresh_options_list
    refresh_selected_option
  end

  def refresh_on_index_changed(old_index)
    refresh_selected_option
    if (old_index < 0) != (index < 0)
      refresh_page_cursor
      refresh_options_list
    elsif index < 0
      # Also refresh when staying in tab selection to hide cursor arrows
      refresh_options_list
    end
  end

  def refresh_page_tabs
    @sprites[:page_icons].bitmap.clear
    if @is_submenu && @submenu_pages
      draw_page_tabs(@submenu_pages, @submenu_tab_scroll, @page)
      return
    end
    # Determine which main tab should be highlighted when inside a plain submenu
    active_main_page = @page
    if @is_submenu && @submenu_stack && !@submenu_stack.empty?
      active_main_page = @submenu_stack.first[:page]
    end
    draw_page_tabs(all_pages, @tab_scroll, active_main_page)
  end

  # Shared rendering used by both the main tab bar and any submenu tab bar.
  def draw_page_tabs(pages, tab_scroll, active_page)
    visible_start = tab_scroll
    visible_end   = [tab_scroll + MAX_VISIBLE_TABS, pages.length].min
    (visible_start...visible_end).each do |i|
      this_page = pages[i]
      tab_x  = (i - tab_scroll) * ((@bitmaps[:page_icons].width / 2) + PAGE_TAB_SPACING)
      src_x  = (this_page == active_page) ? @bitmaps[:page_icons].width / 2 : 0
      draw_image(@bitmaps[:page_icons], tab_x, 0,
                 src_x, 0,
                 @bitmaps[:page_icons].width / 2, @bitmaps[:page_icons].height, overlay: :page_icons)
      page_handler = PageHandlers.call(@menu, this_page)
      page_name    = page_handler[:name].call
      draw_text(page_name, tab_x + (@bitmaps[:page_icons].width / 4), PAGE_NAME_Y,
                align: :center, theme: :page_name, overlay: :page_icons)
    end
    total_pages = (pages.length.to_f / MAX_VISIBLE_TABS).ceil
    if total_pages > 1
      current_page = (tab_scroll / MAX_VISIBLE_TABS) + 1
      dots_text = (1..total_pages).map { |n| n == current_page ? "●" : "○" }.join(" ")
      dots_x = @sprites[:page_icons].bitmap.width - 50
      draw_text(dots_text, dots_x, @bitmaps[:page_icons].height + 2,
                align: :center, theme: :page_name, overlay: :page_icons)
    end
  end

  def refresh_page_cursor
    # Hide cursor whenever an option (not a tab) is selected
    if index >= 0
      @sprites[:page_cursor].visible = false
      return
    end
    # Submenu with its own tab bar: show cursor on the active submenu tab
    if @is_submenu && @submenu_pages
      page_index = @submenu_pages.index(@page)
      if page_index
        @sprites[:page_cursor].visible = true
        @sprites[:page_cursor].x = @sprites[:page_icons].x - 2
        visible_position = page_index - @submenu_tab_scroll
        @sprites[:page_cursor].x += visible_position * ((@bitmaps[:page_icons].width / 2) + PAGE_TAB_SPACING)
      else
        @sprites[:page_cursor].visible = false
      end
      return
    end
    # Plain submenu (no tabs): hide cursor
    if @is_submenu
      @sprites[:page_cursor].visible = false
      return
    end
    # Normal main-menu tab mode
    @sprites[:page_cursor].visible = true
    @sprites[:page_cursor].x = @sprites[:page_icons].x - 2
    page_index = all_pages.index(@page)
    return if !page_index
    visible_position = page_index - @tab_scroll
    @sprites[:page_cursor].x += visible_position * ((@bitmaps[:page_icons].width / 2) + PAGE_TAB_SPACING)
  end

  def refresh_options_list
    @sprites[:options_list].refresh
  end

  def refresh_selected_option
    # Call selected option's "on_select" proc (if defined)
    @sprites[:speech_box].letterbyletter = false
    # Ensure the speech box's font is correct (prevents intermittent small text)
    speech_contents = @sprites[:speech_box].contents
    if speech_contents && !speech_contents.disposed?
      pbSetSystemFont(speech_contents) if speech_contents.font.size != MessageConfig::FONT_SIZE
    end
    # Set descriptive text
    description = ""
    option = selected_option
    if index < 0 && (!@is_submenu || (@is_submenu && @submenu_pages))   # Selecting a tab (main or submenu)
      page_handler = PageHandlers.call(@menu, @page)
      if page_handler && page_handler[:description].is_a?(Proc)
        # If the description proc expects arguments, pass the page and visuals
        desc_proc = page_handler[:description]
        description = if desc_proc.arity == 0
                        desc_proc.call
                      elsif desc_proc.arity == 1
                        desc_proc.call(@page)
                      else
                        desc_proc.call(@page, self)
                      end
      elsif page_handler && !page_handler[:description].nil?
        description = _INTL(page_handler[:description])
      end
    elsif option
      option[:on_select]&.call(self)   # Can change speech box's letterbyletter
      if option[:description].is_a?(Proc)
        description = option[:description].call
      elsif !option[:description].nil?
        description = _INTL(option[:description])
      end
    else   # Back
      description = _INTL("Atrás.")
    end
    
    # Añadir aviso de restablecer si hay opciones con valores por defecto en esta página
    has_defaults = @sprites[:options_list].options.any? { |opt| !opt[:default_value].nil? }
    if has_defaults && index >= 0
      description += _INTL("\n[Z] Restablecer valores.")
    end
    
    @sprites[:speech_box].text = description
  end

  def description=(value)
    @sprites[:speech_box].text = value
  end

  #-----------------------------------------------------------------------------

  def update_input_tabs
    if Input.repeat?(Input::DOWN)
      pbPlayCursorSE
      set_index(0)
    elsif Input.repeat?(Input::LEFT)
      go_to_previous_page
    elsif Input.repeat?(Input::RIGHT)
      go_to_next_page
    end
    # Check for interaction
    if Input.trigger?(Input::USE)
      pbPlayCursorSE
      set_index(0)
    elsif Input.trigger?(Input::BACK)
      pbPlayCloseMenuSE
      return :quit
    end
    return nil
  end

  # Tab-bar navigation used when inside a submenu that has its own page set.
  # Mirrors update_input_tabs but BACK closes the submenu level instead of quitting.
  def update_input_submenu_tabs
    if Input.repeat?(Input::DOWN)
      pbPlayCursorSE
      set_index(0)
    elsif Input.repeat?(Input::LEFT)
      go_to_previous_submenu_page
    elsif Input.repeat?(Input::RIGHT)
      go_to_next_submenu_page
    end
    if Input.trigger?(Input::USE)
      pbPlayCursorSE
      set_index(0)
    elsif Input.trigger?(Input::BACK)
      pbPlayCancelSE
      close_submenu
    end
    return nil
  end

  def go_to_next_submenu_page
    pages = @submenu_pages
    return unless pages
    page_number = pages.index(@page)
    return unless page_number
    new_page = pages[(page_number + 1) % pages.length]
    return if new_page == @page
    pbPlayCursorSE
    @page = new_page
    update_submenu_tab_scroll
    @sprites[:options_list].options = options_for_page(@page)
    @sprites[:options_list].index = -1
    refresh
  end

  def go_to_previous_submenu_page
    pages = @submenu_pages
    return unless pages
    page_number = pages.index(@page)
    return unless page_number
    new_page = pages[(page_number - 1) % pages.length]
    return if new_page == @page
    pbPlayCursorSE
    @page = new_page
    update_submenu_tab_scroll
    @sprites[:options_list].options = options_for_page(@page)
    @sprites[:options_list].index = -1
    refresh
  end

  def update_submenu_tab_scroll
    return unless @submenu_pages
    page_index = @submenu_pages.index(@page)
    return unless page_index
    pages_length = @submenu_pages.length
    return if pages_length <= MAX_VISIBLE_TABS
    current_page_start = @submenu_tab_scroll
    current_page_end   = @submenu_tab_scroll + MAX_VISIBLE_TABS
    if page_index < current_page_start || page_index >= current_page_end
      tab_page_number     = page_index / MAX_VISIBLE_TABS
      @submenu_tab_scroll = tab_page_number * MAX_VISIBLE_TABS
      max_scroll          = ((pages_length - 1) / MAX_VISIBLE_TABS) * MAX_VISIBLE_TABS
      @submenu_tab_scroll = [@submenu_tab_scroll, max_scroll].min
    end
  end

  def open_submenu(submenu_page, submenu_pages = nil)
    @submenu_stack ||= []
    @is_submenu    ||= false

    @submenu_stack.push({
      page:               @page,
      index:              @sprites[:options_list].index,
      is_submenu:         @is_submenu,
      submenu_pages:      @submenu_pages,
      submenu_tab_scroll: @submenu_tab_scroll
    })
    @is_submenu         = true
    @submenu_pages      = submenu_pages
    @submenu_tab_scroll = 0
    @page = submenu_page
    @sprites[:options_list].options = options_for_page(@page)
    first_enabled = @sprites[:options_list].options.index { |o| !o[:disabled_proc]&.call }
    @sprites[:options_list].index = first_enabled || 0
    refresh
  end

  def close_submenu
    @submenu_stack ||= []
    state = @submenu_stack.pop
    return if !state

    @page               = state[:page]
    @is_submenu         = state[:is_submenu]
    @submenu_pages      = state[:submenu_pages]
    @submenu_tab_scroll = state[:submenu_tab_scroll] || 0
    @sprites[:options_list].options = options_for_page(@page)
    @sprites[:options_list].index = state[:index]
    refresh
  end

  def update_input
    # Update value change
    if @sprites[:options_list].value_changed
      selected_option[:set_proc].call(@sprites[:options_list].value, self)
      current_option_id = selected_option[:option]
      new_options = options_for_page(@page)
      if @sprites[:options_list].options.length != new_options.length || 
         @sprites[:options_list].options.map{|o| o[:option]} != new_options.map{|o| o[:option]}
        @sprites[:options_list].update_options_dynamically(new_options, current_option_id)
        refresh
      end
    end
    # Do page selection
    if @sprites[:options_list].index < 0
      return update_input_submenu_tabs if @is_submenu && @submenu_pages
      return update_input_tabs         if !@is_submenu
    end
    # Check for interaction
    if Input.trigger?(Input::USE)
      if selected_option
        if selected_option[:type] == :submenu
          pbPlayDecisionSE
          open_submenu(selected_option[:parameters], selected_option[:submenu_pages])
        elsif selected_option[:use_proc]
          pbPlayDecisionSE
          return :use_option
        end
      else
        pbPlayCancelSE
        if @is_submenu
          close_submenu
        else
          set_index(-1)
        end
      end
    elsif Input.trigger?(Input::BACK)
      pbPlayCancelSE
      if @is_submenu && @submenu_pages && index >= 0
        # First BACK from options goes to the submenu tab bar (mirrors normal menu)
        set_index(-1)
      elsif @is_submenu
        close_submenu
      else
        set_index(-1)
      end
    elsif Input.trigger?(Input::ACTION)
      # Restablecer valores predeterminados
      pbPlayDecisionSE
      if pbConfirmMessage(_INTL("¿Restablecer las opciones de esta página a sus valores por defecto?"))
        current_option_id = selected_option ? selected_option[:option] : nil
        
        # Aplicar los valores por defecto a todas las opciones de la página actual
        @options.each do |opt|
          if opt[:page] == @page && !opt[:default_value].nil?
            opt[:set_proc].call(opt[:default_value], self)
          end
        end
        
        # Recalcular visibilidad dinámica por si algún valor por defecto ocultó/mostró opciones
        new_options = options_for_page(@page)
        @sprites[:options_list].update_options_dynamically(new_options, current_option_id)
        refresh
      end
    end
    return nil
  end

  # def change_key_or_button
  #   this_input = selected_option[:parameters]
  #   @sprites[:speech_box].text = _INTL("Presiona una tecla o botón para asignarlo,\no presiona Esc para salir.")
  #   pressed_key = nil
  #   pressed_button = nil
  #   # Detect key/button press
  #   loop do
  #     Graphics.update
  #     Input.update
  #     # Cancel
  #     if Input::DEFAULT_INPUT_MAPPINGS[Input::BACK].flatten.any? { |key| Input.pressex?(key) }
  #       pbPlayCancelSE
  #       break
  #     end
  #     # Check for key/button press
  #     Input::REMAP_KEYBOARD_KEYS.keys.each do |key|
  #       pressed_key = key if Input.triggerex?(key)
  #       break if pressed_key
  #     end
  #     break if pressed_key
  #     Input::REMAP_GAMEPAD_BUTTONS.keys.each do |key|
  #       pressed_button = key if Input::Controller.triggerex?(key)
  #       break if pressed_button
  #     end
  #     break if pressed_button
  #     Input::REMAP_GAMEPAD_AXIS.keys.each do |key|
  #       pressed_button = key if Input.axis_triggerex?(key)
  #       break if pressed_button
  #     end
  #     break if pressed_button
  #   end
  #   # Change input binding if key/button was pressed
  #   if pressed_key || pressed_button
  #     pbPlayDecisionSE
  #     control_index = (pressed_key ? 0 : 1)
  #     if $PokemonSystem.controls[this_input][control_index] == (pressed_key || pressed_button)
  #       $PokemonSystem.controls[this_input][control_index] = nil
  #     else
  #       $PokemonSystem.controls[this_input][control_index] = pressed_key || pressed_button
  #       $PokemonSystem.controls.each_pair do |ctrl_input, keys|
  #         keys[0] = nil if ctrl_input != this_input && pressed_key && keys[0] == pressed_key
  #         keys[1] = nil if ctrl_input != this_input && pressed_button && keys[1] == pressed_button
  #       end
  #     end
  #   end
  #   # Clean up
  #   @sprites[:options_list].get_values
  #   refresh
  #   Input.update
  # end
end

#===============================================================================
#
#===============================================================================
class UI::Options < UI::BaseScreen
  ACTIONS = HandlerHash.new

  def initialize(in_load_screen = false, menu = :options_menu)
    @in_load_screen = in_load_screen
    @menu = menu
    @options = get_all_options(menu)
    super()
  end

  def initialize_visuals
    @visuals = UI::OptionsVisuals.new(@options, @in_load_screen, @menu)
  end

  def get_all_options(menu = :options_menu)
    ret = []
    seen_options = {}
    
    # First pass: collect all options and track which format they use
    MenuHandlers.each_available(menu) do |option, hash, name|
      has_explicit_page = !hash["page"].nil?
      
      # If this option was already seen with an explicit page, skip old format versions
      next if seen_options[option] && !has_explicit_page
      
      if hash["description"].is_a?(Proc)
        description = hash["description"].call
      elsif !hash["description"].nil?
        description = _INTL(hash["description"])
      end
      
      # Auto-assign page for options without one (backward compatibility)
      page = hash["page"] || auto_detect_page(hash["type"], hash["name"] || name)
      # Convert old option types to new format
      type = convert_option_type(hash["type"])

      raw_params = hash["parameters"]
      final_params = raw_params.is_a?(Proc) ? raw_params.call : raw_params
      option_data = {
        :option      => option,
        :page        => page,
        :name        => name,
        :description => description,
        :type        => type,
        :parameters  => final_params,
        :default_value => hash["default_value"],
        :visible_proc  => hash["visible_proc"],
        :disabled_proc => hash["disabled_proc"],
        :on_select   => hash["on_select"],
        :get_proc      => hash["get_proc"],
        :set_proc      => hash["set_proc"],
        :use_proc      => hash["use_proc"],
        :submenu_pages => hash["submenu_pages"]
      }
      option_data[:parameters].map! { |val| _INTL(val) } if option_data[:type] == :array
      
      # Remove old version if it exists and this is a new format version
      if has_explicit_page && seen_options[option]
        ret.delete_if { |opt| opt[:option] == option }
      end
      
      ret.push(option_data)
      seen_options[option] = has_explicit_page
    end
    
    return ret
  end

  # Keyword mappings for auto-detecting option pages
  AUTO_DETECT_AUDIO_KEYWORDS    = %w[volumen volume bgm sound música music].freeze
  AUTO_DETECT_GRAPHICS_KEYWORDS = %w[frame marco screen pantalla text texto animation animación vsync autotile].freeze

  # Auto-detect appropriate page based on option type and name
  def auto_detect_page(type, name)
    name_lower = name.to_s.downcase
    return :audio    if AUTO_DETECT_AUDIO_KEYWORDS.any? { |kw| name_lower.include?(kw) }
    return :graphics if AUTO_DETECT_GRAPHICS_KEYWORDS.any? { |kw| name_lower.include?(kw) }
    return :gameplay
  end

  # Hash lookup for converting old option type class names to new format symbols
  OPTION_TYPE_MAP = {
    "SliderOption"  => :number_slider,
    "EnumOption"    => :array,
    "NumberOption"  => :number_type,
    "ButtonOption"  => :use,
    "ArrowOption"   => :arrow_option,
    "SubmenuOption" => :submenu,
    "ToggleOption"  => :toggle
  }.freeze

  # Convert old option type classes to new format symbols
  def convert_option_type(type)
    return type if type.is_a?(Symbol)
    OPTION_TYPE_MAP.fetch(type.to_s, :array)
  end

  ACTIONS.add(:use_option, {
    :effect => proc { |screen|
      option = screen.visuals.selected_option
      option[:use_proc].call(screen)
    }
  })
end

#===============================================================================
# Options Menu commands.
#===============================================================================
if Settings::USE_NEW_OPTIONS_UI
  # Default page handlers for options menu
  PageHandlers.add(:options_menu, :gameplay, {
    :name  => proc { next _INTL("Juego") },
    :order => 10,
    :description => proc { next _INTL("Cambia cómo se comporta el juego.") }
  })

  PageHandlers.add(:options_menu, :audio, {
    :name  => proc { next _INTL("Audio") },
    :order => 20,
    :description => proc { next _INTL("Cambia el volumen del juego.") }
  })

  PageHandlers.add(:options_menu, :graphics, {
    :name  => proc { next _INTL("Gráficos") },
    :order => 30,
    :description => proc { next _INTL("Cambia cómo se ve el juego.") }
  })

  # PageHandlers.add(:options_menu, :controls, {
  #   :name  => proc { next _INTL("Controles") },
  #   :order => 40,
  #   :description => proc { next _INTL("Edita los controles del juego.") }
  # })

  PageHandlers.add(:options_menu, :plugins, {
    :name  => proc { next _INTL("Plugins") },
    :order => 50,
    :condition => proc { next PageHandlers.has_any?(:options_menu, :plugins) },
    :description => proc { next _INTL("Configuraciones de Plugins.") }
  })

  MenuHandlers.add(:options_menu, :text_speed, {
    "page"        => :gameplay,
    "name"        => _INTL("Velocidad de texto"),
    "order"       => 10,
    "type"        => :array,
    "parameters"  => proc { [_INTL("Lento"), _INTL("Medio"), _INTL("Rápido"), _INTL("Instantáneo")] },
    "description" => _INTL("Elige la velocidad a la que aparece el texto."),
    "on_select"   => proc { |screen| screen.sprites[:speech_box].letterbyletter = true },
    "get_proc"    => proc { next $PokemonSystem.textspeed },
    "set_proc"    => proc { |value, screen|
      next if value == $PokemonSystem.textspeed
      $PokemonSystem.textspeed = value
      # Display the message with the selected text speed to gauge it better.
      screen.sprites[:speech_box].textspeed      = MessageConfig.pbGetTextSpeed
      screen.sprites[:speech_box].letterbyletter = true
      screen.sprites[:speech_box].text           = screen.sprites[:speech_box].text
    }
  })


  MenuHandlers.add(:options_menu, :battle_style, {
    "page"        => :gameplay,
    "name"        => _INTL("Estilo de combate"),
    "order"       => 20,
    "type"        => :array,
    "parameters"  => proc { [_INTL("Cambio"), _INTL("Fijo")] }, 
    "description" => _INTL("Elige si quieres que se te ofrezca la opción de cambiar de Pokémon cuando se debilita el del rival."),
    "get_proc"    => proc { next $PokemonSystem.battlestyle },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.battlestyle = value }
  })

  MenuHandlers.add(:options_menu, :movement_style, {
    "page"        => :gameplay,
    "name"        => _INTL("Mov. por defecto"),
    "order"       => 30,
    "type"        => :array,
    "parameters"  => proc { [_INTL("Andar"), _INTL("Correr")] },
    "description" => _INTL("Elige tu velocidad de movimiento. Mantén Presionar hacia atrás mientras te mueves para moverte a la otra velocidad."),
    "condition"   => proc { next $player&.has_running_shoes },
    "get_proc"    => proc { next $PokemonSystem.runstyle },
    "set_proc"    => proc { |value, _sceme| $PokemonSystem.runstyle = value }
  })

  MenuHandlers.add(:options_menu, :send_to_boxes, {
    "page"        => :gameplay,
    "name"        => _INTL("Enviar a las Cajas"),
    "order"       => 40,
    "type"        => :array,
    "parameters"  => proc { [_INTL("Manual"), _INTL("Automático")] },
    "description" => _INTL("Elige si los Pokémon capturados se envían a tus Cajas cuando tu equipo está lleno."),
    "condition"   => proc { next Settings::NEW_CAPTURE_CAN_REPLACE_PARTY_MEMBER },
    "get_proc"    => proc { next $PokemonSystem.sendtoboxes },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.sendtoboxes = value }
  })

  MenuHandlers.add(:options_menu, :give_nicknames, {
    "page"        => :gameplay,
    "name"        => _INTL("Motes al capturar"),
    "order"       => 50,
    "type"        => :array,
    "parameters"  => proc { [_INTL("Dar"), _INTL("No dar")] },
    "description" => _INTL("Elige si poner mote a un Pokémon cuando lo obtienes."),
    "get_proc"    => proc { next $PokemonSystem.givenicknames },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.givenicknames = value }
  })

  MenuHandlers.add(:options_menu, :text_input_style, {
    "page"        => :gameplay,
    "name"        => _INTL("Escritura"),
    "order"       => 60,
    "type"        => :array,
    "parameters"  => proc { [_INTL("Teclado"), _INTL("Cursor")] },
    "description" => _INTL("Elige el método de escritura."),
    "get_proc"    => proc { next $PokemonSystem.textinput },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.textinput = value }
  })

  MenuHandlers.add(:options_menu, :jump_texts, {
    "page"        => :gameplay,
    "name"        => _INTL("Saltar textos"),
    "order"       => 70,
    "type"        => :toggle,
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "description" => _INTL("Elige si quieres saltar rápido los textos pulsando la Z."),
    "condition"   => proc { next Settings::ENABLE_SKIP_TEXT },
    "get_proc"    => proc { next $PokemonSystem.skip_texts },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.skip_texts = value }
  })

  MenuHandlers.add(:options_menu, :language, {
    "page"        => :gameplay,
    "name"        => _INTL("Idioma"),
    "order"       => 80,
    "type"        => (Settings::LANGUAGES.length == 2) ? :array : :array_one,
    "parameters"  => proc { Settings::LANGUAGES.map { |lang| lang[0] } },
    "description" => _INTL("Elige el idioma del juego."),
    "condition"   => proc { next Settings::LANGUAGES.length >= 2 },
    "get_proc"    => proc { next $PokemonSystem.language },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.language = value }
  })

  MenuHandlers.add(:options_menu, :skip_move_learning, {
    "page"        => :gameplay,
    "name"        => _INTL("Saltar aprender Movs."),
    "order"       => 81,
    "type"        => :toggle,
    "parameters"  => [_INTL("Sí"), _INTL("No")],
    "description" => _INTL("Elige si quieres saltarte el aprendizaje de movimientos al subir de nivel.\nPuedes aprenderlos más tarde desde el recordador de movimientos."),
    "condition"   => proc { next Settings::ALLOW_SKIPPING_MOVE_LEARNING },
    "get_proc"    => proc { next $PokemonSystem.skip_move_learning },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.skip_move_learning = value }
  })

  #-------------------------------------------------------------------------------

  # MenuHandlers.add(:options_menu, :main_volume, {
  #   "page"        => :audio,
  #   "name"        => _INTL("Volumen general"),
  #   "order"       => 10,
  #   "type"        => :number_slider,
  #   "parameters"  => [0, 100, 5],   # [minimum_value, maximum_value, interval]
  #   "description" => _INTL("Ajusta el volumen de todos los audio en el juego."),
  #   "get_proc"    => proc { next $PokemonSystem.main_volume },
  #   "set_proc"    => proc { |value, screen| 
  #     $PokemonSystem.main_volume = value 
  #     screen.refresh 
  #   }
  # })

  MenuHandlers.add(:options_menu, :bgm_volume, {
    "page"        => :audio,
    "name"        => _INTL("Música de fondo"),
    "order"       => 20,
    "type"        => :number_slider,
    "parameters"  => [0, 100, 5],   # [minimum_value, maximum_value, interval]
    "description" => _INTL("Ajusta el volumen de la música de fondo."),
    "get_proc"    => proc { next $PokemonSystem.bgmvolume },
    "set_proc"    => proc { |value, screen| 
      $PokemonSystem.bgmvolume = value 
      screen.refresh 
    },
    "disabled_proc" => proc { next $PokemonSystem.main_volume <= 0 }
  })

  MenuHandlers.add(:options_menu, :se_volume, {
    "page"        => :audio,
    "name"        => _INTL("Efectos de sonido"),
    "order"       => 30,
    "type"        => :number_slider,
    "parameters"  => [0, 100, 5],   # [minimum_value, maximum_value, interval]
    "description" => _INTL("Ajusta el volumen de los efectos de sonido."),
    "get_proc"    => proc { next $PokemonSystem.sevolume },
    "set_proc"    => proc { |value, _screen|
      next if $PokemonSystem.sevolume == value
      $PokemonSystem.sevolume = value
      pbPlayCursorSE
    },
    "disabled_proc" => proc { next $PokemonSystem.main_volume <= 0 }
  })

  MenuHandlers.add(:options_menu, :pokemon_cry_volume, {
    "page"        => :audio,
    "name"        => _INTL("Volumen gritos Pkmn."),
    "order"       => 40,
    "type"        => :number_slider,
    "parameters"  => [0, 100, 5],   # [minimum_value, maximum_value, interval]
    "description" => _INTL("Ajusta el volumen de los gritos de los Pokémon."),
    "get_proc"    => proc { next $PokemonSystem.pokemon_cry_volume },
    "set_proc"    => proc { |value, _screen|
      next if $PokemonSystem.pokemon_cry_volume == value
      $PokemonSystem.pokemon_cry_volume = value
      pbPlayCursorSE
    },
    "disabled_proc" => proc { next $PokemonSystem.main_volume <= 0 }
  })

  #-------------------------------------------------------------------------------

  MenuHandlers.add(:options_menu, :battle_animations, {
    "page"        => :graphics,
    "name"        => _INTL("Efectos de combate"),
    "order"       => 20,
    "type"        => :toggle,
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "description" => _INTL("Elige si deseas ver las animaciones de movimiento en batalla."),
    "get_proc"    => proc { next $PokemonSystem.battlescene },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.battlescene = value }
  })

  MenuHandlers.add(:options_menu, :speech_frame, {
    "page"        => :graphics,
    "name"        => _INTL("Marco de diálogo"),
    "order"       => 30,
    "type"        => :number_type,
    "parameters"  => 1..Settings::SPEECH_WINDOWSKINS.length,
    "description" => _INTL("Elige la apariencia de los cuadros de diálogo."),
    "condition"   => proc { next Settings::SPEECH_WINDOWSKINS.length > 1 },
    "get_proc"    => proc { next $PokemonSystem.textskin },
    "set_proc"    => proc { |value, screen|
      $PokemonSystem.textskin = value
      # Change the windowskin of the options text box to selected one
      screen.sprites[:speech_box].setSkin(MessageConfig.pbGetSpeechFrame)
    }
  })

  MenuHandlers.add(:options_menu, :menu_frame, {
    "page"        => :graphics,
    "name"        => _INTL("Marco de menú"),
    "order"       => 40,
    "type"        => :number_type,
    "parameters"  => 1..Settings::MENU_WINDOWSKINS.length,
    "description" => _INTL("Elige la apariencia de los menús del juego."),
    "condition"   => proc { next Settings::MENU_WINDOWSKINS.length > 1 },
    "get_proc"    => proc { next $PokemonSystem.frame },
    "set_proc"    => proc { |value, screen|
      $PokemonSystem.frame = value
      # Change the windowskin of the options text box to selected one
      screen.sprites[:options_list].setSkin(MessageConfig.pbGetSystemFrame)
    }
  })

  MenuHandlers.add(:options_menu, :screen_size, {
    "page"        => :graphics,
    "name"        => _INTL("Tamaño de ventana"),
    "order"       => 50,
    "type"        => :arrow_option,
    "parameters"  => proc { [_INTL("Pequeña"), _INTL("Mediana"), _INTL("Grande"), _INTL("Extra Grande"), _INTL("Completa")] },
    "description" => _INTL("Elije el tamaño de la ventana del juego."),
    "get_proc"    => proc { next [$PokemonSystem.screensize, 4].min },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.screensize = value }
  })

  MenuHandlers.add(:options_menu, :vsync, {
    "page"        => :graphics,
    "name"        => _INTL("VSync"),
    "order"       => 60,
    "type"        => :toggle,
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "condition"   => proc { next !$joiplay },
    "description" => _INTL("Si el juego va muy rápido desactiva el VSync.\nRequiere reiniciar el juego"),
    "get_proc"    => proc { next $PokemonSystem.vsync },
    "set_proc"    => proc { |value, _scene|
      next if $PokemonSystem.vsync == value
      $PokemonSystem.vsync = value
      $PokemonSystem.update_vsync($PokemonSystem.vsync)
    }
  })

  MenuHandlers.add(:options_menu, :autotile_animations, {
    "page"        => :graphics,
    "name"        => _INTL("Anim. de mapas"),
    "order"       => 70,
    "type"        => :toggle,
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "description" => _INTL("Activa o desactiva las animaciones de los mapas."),
    "get_proc"    => proc { next $PokemonSystem.autotile_animations || 0 },
    "set_proc"    => proc { |value, _scene| $PokemonSystem.autotile_animations = value }
  })

  #-------------------------------------------------------------------------------

  # MenuHandlers.add(:options_menu, :control_up, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Arriba"),
  #   "order"       => 10,
  #   "type"        => :control,
  #   "parameters"  => Input::UP,
  #   "description" => _INTL("Movimiento hacia arriba del personaje o en menús. [Also: Arriba]"),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::UP] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::UP] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :control_left, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Izquierda"),
  #   "order"       => 20,
  #   "type"        => :control,
  #   "parameters"  => Input::LEFT,
  #   "description" => _INTL("Movimiento hacia la izquierda del personaje o en menús. [Also: Izquierda]"),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::LEFT] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::LEFT] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :control_down, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Abajo"),
  #   "order"       => 30,
  #   "type"        => :control,
  #   "parameters"  => Input::DOWN,
  #   "description" => _INTL("Movimiento hacia abajo del personaje o en menús. [Also: Abajo]"),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::DOWN] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::DOWN] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :control_right, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Derecha"),
  #   "order"       => 40,
  #   "type"        => :control,
  #   "parameters"  => Input::RIGHT,
  #   "description" => _INTL("Movimiento hacia la derecha del personaje o en menús. [También: Derecha]"),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::RIGHT] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::RIGHT] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :control_use, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Usar/Seleccionar"),
  #   "order"       => 50,
  #   "type"        => :control,
  #   "parameters"  => Input::USE,
  #   "description" => _INTL("Interactuar o Confirmar. [También: Enter, Espacio]"),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::USE] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::USE] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :control_back, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Atrás"),
  #   "order"       => 60,
  #   "type"        => :control,
  #   "parameters"  => Input::BACK,
  #   "description" => _INTL("Sale del menú y cancela interacciones. [También: X/Esc]"),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::BACK] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::BACK] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :control_action, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Acción"),
  #   "order"       => 70,
  #   "type"        => :control,
  #   "parameters"  => Input::ACTION,
  #   "description" => _INTL("Cambia el comportamiento de ciertas interacciones en el juego. (Default: Z)"),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::ACTION] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::ACTION] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :control_jump_up, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Subir Rápido"),
  #   "order"       => 80,
  #   "type"        => :control,
  #   "parameters"  => Input::QUICK_UP,
  #   "description" => _INTL("Permite avanzar más rápidamente hacia arriba en los menús."),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::QUICK_UP] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::QUICK_UP] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :control_jump_down, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Av. Página"),
  #   "order"       => 90,
  #   "type"        => :control,
  #   "parameters"  => Input::QUICK_DOWN,
  #   "description" => _INTL("Permite avanzar más rápidamente hacia abajo en los menús."),
  #   "get_proc"    => proc { next $PokemonSystem.controls[Input::QUICK_DOWN] },
  #   "set_proc"    => proc { |value, _screen| $PokemonSystem.controls[Input::QUICK_DOWN] = value },
  #   "use_proc"    => proc { |screen| screen.visuals.change_key_or_button }
  # })

  # MenuHandlers.add(:options_menu, :reset_controls, {
  #   "page"        => :controls,
  #   "name"        => _INTL("Resetear Controles"),
  #   "order"       => 900,
  #   "type"        => :use,
  #   "description" => _INTL("Restablece los controles a sus valores predeterminados."),
  #   "use_proc"    => proc { |screen|
  #     $PokemonSystem.reset_controls
  #     screen.sprites[:options_list].get_values
  #     screen.refresh
  #     Input.update
  #   }
  # })

  #-------------------------------------------------------------------------------
  # EJEMPLO OPCIÓN MULTISELECT
  # Esta opción personalizada permite seleccionar múltiples valores de una lista.
  # Usa las flechas IZQUIERDA/DERECHA para navegar y ENTER/Z para alternar selecciones.
  # Calcula dinámicamente cuántos ítems caben por página según el ancho disponible.
  # Muestra flechas de navegación (< >) cuando hay más ítems para ver.
  #-------------------------------------------------------------------------------

  # # Primero, agrega un campo para rastrear las selecciones en PokemonSystem
  # # En 010_PokemonSystem.rb o similar:
  # # attr_accessor :my_multiselect_option
  # #
  # # En el método initialize:
  # # @my_multiselect_option = [] # Array de índices seleccionados
  #
  # MenuHandlers.add(:options_menu, :example_multiselect, {
  #   "page"        => :gameplay,
  #   "name"        => _INTL("Multi-opción"),
  #   "order"       => 100,
  #   "type"        => :multiselect,
  #   "parameters"  => [_INTL("A"), _INTL("B"), _INTL("C"), _INTL("Opción D"), _INTL("E"), _INTL("F"), _INTL("G")],
  #   "description" => _INTL("Selecciona múltiples opciones. Usa flechas para navegar y Enter para marcar."),
  #   "get_proc"    => proc { next $PokemonSystem.my_multiselect_option || [] },
  #   "set_proc"    => proc { |value, _screen|
  #     $PokemonSystem.my_multiselect_option = value
  #     # value is an array of indices, e.g., [0, 2, 4] means options A, C, and E are selected
  #   }
  # })
end