#===============================================================================
# Sky Essentials - Options Menu with Tabs
# Adapted from La Base de Sky for Pokémon Essentials v21
# This plugin adds a tabbed options menu similar to La Base de Sky
#===============================================================================

#===============================================================================
# PageHandlers module - Manages page/tab definitions for UI screens
#===============================================================================
module PageHandlers
  @@handlers = {}

  def self.add(menu, page, hash)
    @@handlers[menu] = {} if !@@handlers.has_key?(menu)
    @@handlers[menu][page] = hash
  end

  def self.remove(menu, page)
    @@handlers[menu]&.delete(page)
  end

  def self.clear(menu)
    @@handlers[menu]&.clear
  end

  def self.get(menu, page)
    return @@handlers[menu]&.[](page)
  end

  def self.each(menu)
    return if !@@handlers.has_key?(menu)
    @@handlers[menu].each { |page, hash| yield page, hash }
  end

  def self.each_available(menu, *args)
    return if !@@handlers.has_key?(menu)
    pages = @@handlers[menu]
    keys = pages.keys
    sorted_keys = keys.sort_by { |page| pages[page][:order] || 99 }
    sorted_keys.each do |page|
      hash = pages[page]
      next if hash[:condition] && !hash[:condition].call(*args)
      if hash[:name].is_a?(Proc)
        name = hash[:name].call(*args)
      else
        name = _INTL(hash[:name])
      end
      yield page, hash, name
    end
  end

  def self.call(menu, page)
    return @@handlers[menu]&.[](page)
  end
end

#===============================================================================
# Extended PokemonSystem class with additional options
#===============================================================================
class PokemonSystem
  attr_accessor :main_volume
  attr_accessor :pokemon_cry_volume
  attr_accessor :damagenumbers
  attr_accessor :vsync
  attr_accessor :autotile_animations

  alias sky_options_initialize initialize
  def initialize
    sky_options_initialize
    @main_volume = 100
    @pokemon_cry_volume = 100
    @damagenumbers = 0     # Damage numbers (0=Real, 1=Raw, 2=Off)
    @vsync = 1
    @autotile_animations = 0
  end

  def main_volume
    return @main_volume || 100
  end

  def main_volume=(value)
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

  def pokemon_cry_volume
    return @pokemon_cry_volume || 100
  end
end

#===============================================================================
# Override Pokemon cry methods to use pokemon_cry_volume setting
#===============================================================================
module GameData
  class Species
    class << self
      alias sky_play_cry_from_species play_cry_from_species
      def play_cry_from_species(species, form = 0, volume = 90, pitch = 100)
        # Apply pokemon_cry_volume setting
        cry_vol = $PokemonSystem&.pokemon_cry_volume || 100
        adjusted_volume = (volume * cry_vol / 100.0).round
        sky_play_cry_from_species(species, form, adjusted_volume, pitch)
      end

      alias sky_play_cry_from_pokemon play_cry_from_pokemon
      def play_cry_from_pokemon(pkmn, volume = 90, pitch = 100)
        return if !pkmn || pkmn.egg?
        # Apply pokemon_cry_volume setting
        cry_vol = $PokemonSystem&.pokemon_cry_volume || 100
        adjusted_volume = (volume * cry_vol / 100.0).round
        sky_play_cry_from_pokemon(pkmn, adjusted_volume, pitch)
      end
    end
  end
end

class Pokemon
  alias sky_play_cry play_cry
  def play_cry(volume = 90, pitch = nil)
    # Apply pokemon_cry_volume setting
    cry_vol = $PokemonSystem&.pokemon_cry_volume || 100
    adjusted_volume = (volume * cry_vol / 100.0).round
    sky_play_cry(adjusted_volume, pitch)
  end
end

#===============================================================================
# Main options list window with tab support
#===============================================================================
class Window_PokemonOptionTabbed < Window_DrawableCommand
  attr_reader :value_changed
  attr_reader :options

  SEL_NAME_BASE_COLOR    = Color.new(192, 120, 0)
  SEL_NAME_SHADOW_COLOR  = Color.new(248, 176, 80)
  SEL_VALUE_BASE_COLOR   = Color.new(248, 48, 24)
  SEL_VALUE_SHADOW_COLOR = Color.new(248, 136, 128)

  def initialize(options, x, y, width, height)
    @options = options
    @values = []
    @options.length.times { |i| @values[i] = 0 }
    @value_changed = false
    super(x, y, width, height)
  end

  def options=(value)
    @options = value
    @values = []
    @options.length.times { |i| @values[i] = 0 }
    self.index = 0 if self.index >= @options.length
    refresh
  end

  def [](i)
    return @values[i]
  end

  def []=(i, value)
    @values[i] = value
    refresh
  end

  def setValueNoRefresh(i, value)
    @values[i] = value
  end

  def itemCount
    return @options.length
  end

  def drawItem(index, _count, rect)
    rect = drawCursor(index, rect)
    sel_index = self.index
    # Draw option's name
    optionname = @options[index].name
    optionwidth = rect.width * 9 / 20
    pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, optionname,
                     (index == sel_index) ? SEL_NAME_BASE_COLOR : self.baseColor,
                     (index == sel_index) ? SEL_NAME_SHADOW_COLOR : self.shadowColor)
    # Draw option's values
    case @options[index]
    when EnumOption
      if @options[index].values.length > 1
        totalwidth = 0
        @options[index].values.each do |value|
          totalwidth += self.contents.text_size(value).width
        end
        spacing = (rect.width - rect.x - optionwidth - totalwidth) / (@options[index].values.length - 1)
        spacing = 0 if spacing < 0
        xpos = optionwidth + rect.x
        ivalue = 0
        @options[index].values.each do |value|
          pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
                           (ivalue == self[index]) ? SEL_VALUE_BASE_COLOR : self.baseColor,
                           (ivalue == self[index]) ? SEL_VALUE_SHADOW_COLOR : self.shadowColor)
          xpos += self.contents.text_size(value).width
          xpos += spacing
          ivalue += 1
        end
      else
        pbDrawShadowText(self.contents, rect.x + optionwidth, rect.y, optionwidth, rect.height,
                         optionname, self.baseColor, self.shadowColor)
      end
    when NumberOption
      value = _INTL("Type {1}/{2}", @options[index].lowest_value + self[index],
                    @options[index].highest_value - @options[index].lowest_value + 1)
      xpos = optionwidth + (rect.x * 2)
      pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
                       SEL_VALUE_BASE_COLOR, SEL_VALUE_SHADOW_COLOR, 1)
    when SliderOption
      value = sprintf(" %d", @options[index].highest_value)
      sliderlength = rect.width - rect.x - optionwidth - self.contents.text_size(value).width
      xpos = optionwidth + rect.x
      self.contents.fill_rect(xpos, rect.y - 2 + (rect.height / 2), sliderlength, 4, self.baseColor)
      self.contents.fill_rect(
        xpos + ((sliderlength - 8) * (@options[index].lowest_value + self[index]) / @options[index].highest_value),
        rect.y - 8 + (rect.height / 2),
        8, 16, SEL_VALUE_BASE_COLOR
      )
      value = (@options[index].lowest_value + self[index]).to_s
      xpos += (rect.width - rect.x - optionwidth) - self.contents.text_size(value).width
      pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
                       SEL_VALUE_BASE_COLOR, SEL_VALUE_SHADOW_COLOR)
    else
      value = @options[index].values[self[index]]
      xpos = optionwidth + rect.x
      pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
                       SEL_VALUE_BASE_COLOR, SEL_VALUE_SHADOW_COLOR)
    end
  end

  def update
    oldindex = self.index
    @value_changed = false
    super
    dorefresh = (self.index != oldindex)
    if self.active && self.index >= 0 && self.index < @options.length
      if Input.repeat?(Input::LEFT)
        self[self.index] = @options[self.index].prev(self[self.index])
        dorefresh = true
        @value_changed = true
      elsif Input.repeat?(Input::RIGHT)
        self[self.index] = @options[self.index].next(self[self.index])
        dorefresh = true
        @value_changed = true
      end
    end
    refresh if dorefresh
  end
end

#===============================================================================
# Options main screen with tabs
#===============================================================================
class PokemonOption_Scene
  attr_reader :sprites
  attr_reader :in_load_screen

  UI_FOLDER = "Graphics/UI/Options/"
  PAGE_ICONS_Y = 8
  PAGE_CURSOR_OFFSET = -2

  def pbStartScene(in_load_screen = false)
    @in_load_screen = in_load_screen
    # Create sprites
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    
    # Background from UI/Options folder
    addBackgroundOrColoredPlane(@sprites, "bg", "Options/bg", Color.new(192, 200, 208), @viewport)
    
    # Load page icons bitmap to get dimensions
    @page_icons_bitmap = AnimatedBitmap.new(UI_FOLDER + "page_icons")
    @page_icon_width = @page_icons_bitmap.width / 2  # Selected and unselected states
    @page_icon_height = @page_icons_bitmap.height
    
    # Page icons sprite
    @sprites["page_icons"] = BitmapSprite.new(Graphics.width, @page_icon_height + 16, @viewport)
    @sprites["page_icons"].y = PAGE_ICONS_Y
    
    # Page cursor sprite
    @sprites["page_cursor"] = IconSprite.new(0, 0, @viewport)
    @sprites["page_cursor"].setBitmap(UI_FOLDER + "page_cursor")
    @sprites["page_cursor"].visible = false
    @sprites["page_cursor"].z = 1
    
    # Text box for descriptions
    @sprites["textbox"] = pbCreateMessageWindow
    pbSetSystemFont(@sprites["textbox"].contents)
    
    # Options list
    options_y = @sprites["page_icons"].y + @page_icon_height + 16
    options_height = Graphics.height - options_y - @sprites["textbox"].height
    @sprites["option"] = Window_PokemonOptionTabbed.new(
      [], 0, options_y, Graphics.width, options_height
    )
    @sprites["option"].viewport = @viewport
    @sprites["option"].visible  = true
    
    # Get pages
    @pages = []
    PageHandlers.each_available(:options_menu) do |page, hash, name|
      @pages.push({ :id => page, :name => name, :description => hash[:description] })
    end
    @page_index = 0
    @focus = :options  # :tabs or :options
    
    pbRefreshPage
    pbDeactivateWindows(@sprites)
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbDrawTabs
    bitmap = @sprites["page_icons"].bitmap
    bitmap.clear
    return if @pages.empty?
    
    # Calculate total width and starting position
    tab_spacing = 8
    total_width = (@page_icon_width * @pages.length) + (tab_spacing * (@pages.length - 1))
    start_x = (Graphics.width - total_width) / 2
    
    @pages.each_with_index do |page, i|
      x = start_x + (i * (@page_icon_width + tab_spacing))
      y = 0
      
      # Draw page icon (selected or unselected)
      src_x = (i == @page_index) ? @page_icon_width : 0
      bitmap.blt(x, y, @page_icons_bitmap.bitmap, Rect.new(src_x, 0, @page_icon_width, @page_icon_height))
      
      # Draw page name centered on icon
      pbSetSystemFont(bitmap)
      text_color = (i == @page_index) ? Color.new(248, 248, 248) : Color.new(88, 88, 80)
      shadow_color = (i == @page_index) ? Color.new(168, 184, 184) : Color.new(168, 184, 184)
      pbDrawShadowText(bitmap, x, y + 8, @page_icon_width, @page_icon_height - 16, page[:name],
                       text_color, shadow_color, 1)
    end
    
    # Update cursor position
    if @focus == :tabs
      cursor_x = start_x + (@page_index * (@page_icon_width + tab_spacing)) + PAGE_CURSOR_OFFSET
      cursor_y = @sprites["page_icons"].y + PAGE_CURSOR_OFFSET
      @sprites["page_cursor"].x = cursor_x
      @sprites["page_cursor"].y = cursor_y
      @sprites["page_cursor"].visible = true
    else
      @sprites["page_cursor"].visible = false
    end
  end

  def pbRefreshPage
    @options = []
    @hashes = []
    current_page_id = @pages[@page_index][:id]
    
    MenuHandlers.each_available(:options_menu) do |option, hash, name|
      opt_page = hash["page"] || :gameplay
      next if opt_page != current_page_id
      @options.push(
        hash["type"].new(name, hash["parameters"], hash["get_proc"], hash["set_proc"])
      )
      @hashes.push(hash)
    end
    
    @sprites["option"].options = @options
    # Get the values of each option
    @options.length.times { |i| @sprites["option"].setValueNoRefresh(i, @options[i].get || 0) }
    @sprites["option"].refresh
    
    pbDrawTabs
    
    if @focus == :options && @options.length > 0
      @sprites["option"].index = 0
      @sprites["option"].active = true
      pbChangeSelection
    elsif @focus == :tabs || @options.length == 0
      @sprites["option"].index = -1 if @options.length == 0
      @sprites["option"].active = false
      page_desc = @pages[@page_index][:description]
      if page_desc.is_a?(Proc)
        @sprites["textbox"].text = page_desc.call
      elsif page_desc
        @sprites["textbox"].text = _INTL(page_desc)
      else
        @sprites["textbox"].text = _INTL("Select a category with LEFT/RIGHT.")
      end
    end
  end

  def pbChangeSelection
    if @sprites["option"].index < 0 || @sprites["option"].index >= @hashes.length
      page_desc = @pages[@page_index][:description]
      if page_desc.is_a?(Proc)
        @sprites["textbox"].text = page_desc.call
      elsif page_desc
        @sprites["textbox"].text = _INTL(page_desc)
      else
        @sprites["textbox"].text = _INTL("Select an option.")
      end
      return
    end
    hash = @hashes[@sprites["option"].index]
    # Call selected option's "on_select" proc (if defined)
    @sprites["textbox"].letterbyletter = false
    hash["on_select"]&.call(self) if hash
    # Set descriptive text
    description = ""
    if hash
      if hash["description"].is_a?(Proc)
        description = hash["description"].call
      elsif !hash["description"].nil?
        description = _INTL(hash["description"])
      end
    else
      description = _INTL("Choose an option.")
    end
    @sprites["textbox"].text = description
  end

  def pbOptions
    pbActivateWindow(@sprites, "option") do
      index = -1
      loop do
        Graphics.update
        Input.update
        pbUpdate
        
        # Handle tab navigation with L/R buttons (Q/W keys)
        if Input.trigger?(Input::JUMPUP)   # L button / Q key
          pbPlayCursorSE
          @page_index = (@page_index - 1) % @pages.length
          pbRefreshPage
          next
        elsif Input.trigger?(Input::JUMPDOWN)   # R button / W key
          pbPlayCursorSE
          @page_index = (@page_index + 1) % @pages.length
          pbRefreshPage
          next
        end
        
        if @focus == :options
          # In options mode
          if Input.trigger?(Input::UP) && @sprites["option"].index == 0
            # Move to tabs when at top of options
            @focus = :tabs
            @sprites["option"].active = false
            pbDrawTabs
            page_desc = @pages[@page_index][:description]
            if page_desc.is_a?(Proc)
              @sprites["textbox"].text = page_desc.call
            elsif page_desc
              @sprites["textbox"].text = _INTL(page_desc)
            else
              @sprites["textbox"].text = _INTL("Select a category with LEFT/RIGHT.")
            end
            pbPlayCursorSE
            next
          end
          
          if @sprites["option"].index != index
            pbChangeSelection
            index = @sprites["option"].index
          end
          
          if index >= 0 && index < @options.length
            @options[index].set(@sprites["option"][index], self) if @sprites["option"].value_changed
          end
          
        elsif @focus == :tabs
          # In tabs mode
          if Input.trigger?(Input::DOWN)
            if @options.length > 0
              @focus = :options
              @sprites["option"].active = true
              @sprites["option"].index = 0
              pbDrawTabs
              pbChangeSelection
              pbPlayCursorSE
            end
            next
          elsif Input.trigger?(Input::LEFT)
            pbPlayCursorSE
            @page_index = (@page_index - 1) % @pages.length
            pbRefreshPage
            next
          elsif Input.trigger?(Input::RIGHT)
            pbPlayCursorSE
            @page_index = (@page_index + 1) % @pages.length
            pbRefreshPage
            next
          elsif Input.trigger?(Input::USE)
            if @options.length > 0
              @focus = :options
              @sprites["option"].active = true
              @sprites["option"].index = 0
              pbDrawTabs
              pbChangeSelection
              pbPlayDecisionSE
            end
            next
          end
        end
        
        if Input.trigger?(Input::BACK)
          if @focus == :options
            # Go back to tabs first
            @focus = :tabs
            @sprites["option"].active = false
            pbDrawTabs
            page_desc = @pages[@page_index][:description]
            if page_desc.is_a?(Proc)
              @sprites["textbox"].text = page_desc.call
            elsif page_desc
              @sprites["textbox"].text = _INTL(page_desc)
            else
              @sprites["textbox"].text = _INTL("Select a category with LEFT/RIGHT.")
            end
            pbPlayCancelSE
          else
            # Exit from tabs
            break
          end
        end
      end
    end
  end

  def pbEndScene
    pbPlayCloseMenuSE
    pbFadeOutAndHide(@sprites) { pbUpdate }
    # Set the values of each option, to make sure they're all set
    @options.length.times do |i|
      @options[i].set(@sprites["option"][i], self)
    end
    # Dispose bitmaps
    @page_icons_bitmap.dispose if @page_icons_bitmap
    pbDisposeMessageWindow(@sprites["textbox"])
    pbDisposeSpriteHash(@sprites)
    pbUpdateSceneMap
    @viewport.dispose
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
end

#===============================================================================
# Page Definitions
#===============================================================================
PageHandlers.add(:options_menu, :gameplay, {
  :name        => _INTL("Gameplay"),
  :order       => 10,
  :description => _INTL("Change gameplay settings.")
})

PageHandlers.add(:options_menu, :audio, {
  :name        => _INTL("Audio"),
  :order       => 20,
  :description => _INTL("Change audio settings.")
})

PageHandlers.add(:options_menu, :graphics, {
  :name        => _INTL("Graphics"),
  :order       => 30,
  :description => _INTL("Change graphics settings.")
})

#===============================================================================
# Remove old options and add new ones with page assignments
#===============================================================================

# Remove existing options to redefine them with pages
MenuHandlers.remove(:options_menu, :bgm_volume)
MenuHandlers.remove(:options_menu, :se_volume)
MenuHandlers.remove(:options_menu, :text_speed)
MenuHandlers.remove(:options_menu, :battle_animations)
MenuHandlers.remove(:options_menu, :battle_style)
MenuHandlers.remove(:options_menu, :movement_style)
MenuHandlers.remove(:options_menu, :send_to_boxes)
MenuHandlers.remove(:options_menu, :give_nicknames)
MenuHandlers.remove(:options_menu, :speech_frame)
MenuHandlers.remove(:options_menu, :menu_frame)
MenuHandlers.remove(:options_menu, :text_input_style)
MenuHandlers.remove(:options_menu, :screen_size)

#===============================================================================
# Gameplay Options
#===============================================================================
MenuHandlers.add(:options_menu, :text_speed, {
  "name"        => _INTL("Text Speed"),
  "page"        => :gameplay,
  "order"       => 10,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Slow"), _INTL("Mid"), _INTL("Fast"), _INTL("Inst")],
  "description" => _INTL("Choose the speed at which text appears."),
  "on_select"   => proc { |scene| scene.sprites["textbox"].letterbyletter = true },
  "get_proc"    => proc { next $PokemonSystem.textspeed },
  "set_proc"    => proc { |value, scene|
    next if value == $PokemonSystem.textspeed
    $PokemonSystem.textspeed = value
    MessageConfig.pbSetTextSpeed(MessageConfig.pbSettingToTextSpeed(value))
    scene.sprites["textbox"].textspeed      = MessageConfig.pbGetTextSpeed
    scene.sprites["textbox"].letterbyletter = true
    scene.sprites["textbox"].text           = scene.sprites["textbox"].text
  }
})

MenuHandlers.add(:options_menu, :battle_style, {
  "name"        => _INTL("Battle Style"),
  "page"        => :gameplay,
  "order"       => 20,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Switch"), _INTL("Set")],
  "description" => _INTL("Choose whether you can switch Pokémon when an opponent's Pokémon faints."),
  "get_proc"    => proc { next $PokemonSystem.battlestyle },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.battlestyle = value }
})

MenuHandlers.add(:options_menu, :damage_numbers, {
  "name"        => _INTL("Damage Numbers"),
  "page"        => :gameplay,
  "order"       => 25,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Real"), _INTL("Raw"), _INTL("Off")],
  "description" => _INTL("Choose whether to show damage numbers in battle. Real shows HP lost, Raw shows damage calculated."),
  "get_proc"    => proc { next $PokemonSystem.damagenumbers },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.damagenumbers = value }
})

MenuHandlers.add(:options_menu, :movement_style, {
  "name"        => _INTL("Default Movement"),
  "page"        => :gameplay,
  "order"       => 30,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Walking"), _INTL("Running")],
  "description" => _INTL("Choose your movement speed. Hold Back while moving to move at the other speed."),
  "condition"   => proc { next $player&.has_running_shoes },
  "get_proc"    => proc { next $PokemonSystem.runstyle },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.runstyle = value }
})

MenuHandlers.add(:options_menu, :send_to_boxes, {
  "name"        => _INTL("Send to Boxes"),
  "page"        => :gameplay,
  "order"       => 40,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Manual"), _INTL("Automatic")],
  "description" => _INTL("Choose whether caught Pokémon are sent to your Boxes when your party is full."),
  "condition"   => proc { next Settings::NEW_CAPTURE_CAN_REPLACE_PARTY_MEMBER },
  "get_proc"    => proc { next $PokemonSystem.sendtoboxes },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.sendtoboxes = value }
})

MenuHandlers.add(:options_menu, :give_nicknames, {
  "name"        => _INTL("Give Nicknames"),
  "page"        => :gameplay,
  "order"       => 50,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Give"), _INTL("Don't give")],
  "description" => _INTL("Choose whether you can give a nickname to a Pokémon when you obtain it."),
  "get_proc"    => proc { next $PokemonSystem.givenicknames },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.givenicknames = value }
})

MenuHandlers.add(:options_menu, :text_input_style, {
  "name"        => _INTL("Text Entry"),
  "page"        => :gameplay,
  "order"       => 60,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Cursor"), _INTL("Keyboard")],
  "description" => _INTL("Choose how you want to enter text."),
  "get_proc"    => proc { next $PokemonSystem.textinput },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.textinput = value }
})

#===============================================================================
# Audio Options
#===============================================================================
MenuHandlers.add(:options_menu, :main_volume, {
  "name"        => _INTL("Master Volume"),
  "page"        => :audio,
  "order"       => 5,
  "type"        => SliderOption,
  "parameters"  => [0, 100, 5],
  "description" => _INTL("Adjust the overall volume of all audio."),
  "get_proc"    => proc { next $PokemonSystem.main_volume },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.main_volume = value }
})

MenuHandlers.add(:options_menu, :bgm_volume, {
  "name"        => _INTL("Music Volume"),
  "page"        => :audio,
  "order"       => 10,
  "type"        => SliderOption,
  "parameters"  => [0, 100, 5],
  "description" => _INTL("Adjust the volume of the background music."),
  "get_proc"    => proc { next $PokemonSystem.bgmvolume },
  "set_proc"    => proc { |value, scene|
    next if $PokemonSystem.bgmvolume == value
    $PokemonSystem.bgmvolume = value
    next if scene.in_load_screen || $game_system.playing_bgm.nil?
    playingBGM = $game_system.getPlayingBGM
    $game_system.bgm_pause
    $game_system.bgm_resume(playingBGM)
  }
})

MenuHandlers.add(:options_menu, :se_volume, {
  "name"        => _INTL("SE Volume"),
  "page"        => :audio,
  "order"       => 20,
  "type"        => SliderOption,
  "parameters"  => [0, 100, 5],
  "description" => _INTL("Adjust the volume of sound effects."),
  "get_proc"    => proc { next $PokemonSystem.sevolume },
  "set_proc"    => proc { |value, _scene|
    next if $PokemonSystem.sevolume == value
    $PokemonSystem.sevolume = value
    if $game_system.playing_bgs
      $game_system.playing_bgs.volume = value
      playingBGS = $game_system.getPlayingBGS
      $game_system.bgs_pause
      $game_system.bgs_resume(playingBGS)
    end
    pbPlayCursorSE
  }
})

MenuHandlers.add(:options_menu, :pokemon_cry_volume, {
  "name"        => _INTL("Cry Volume"),
  "page"        => :audio,
  "order"       => 30,
  "type"        => SliderOption,
  "parameters"  => [0, 100, 5],
  "description" => _INTL("Adjust the volume of Pokémon cries."),
  "get_proc"    => proc { next $PokemonSystem.pokemon_cry_volume },
  "set_proc"    => proc { |value, _scene|
    next if $PokemonSystem.pokemon_cry_volume == value
    $PokemonSystem.pokemon_cry_volume = value
  }
})

#===============================================================================
# Graphics Options
#===============================================================================
MenuHandlers.add(:options_menu, :battle_animations, {
  "name"        => _INTL("Battle Effects"),
  "page"        => :graphics,
  "order"       => 10,
  "type"        => EnumOption,
  "parameters"  => [_INTL("On"), _INTL("Off")],
  "description" => _INTL("Choose whether you wish to see move animations in battle."),
  "get_proc"    => proc { next $PokemonSystem.battlescene },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.battlescene = value }
})

MenuHandlers.add(:options_menu, :speech_frame, {
  "name"        => _INTL("Speech Frame"),
  "page"        => :graphics,
  "order"       => 20,
  "type"        => NumberOption,
  "parameters"  => 1..Settings::SPEECH_WINDOWSKINS.length,
  "description" => _INTL("Choose the appearance of dialogue boxes."),
  "get_proc"    => proc { next $PokemonSystem.textskin },
  "set_proc"    => proc { |value, scene|
    $PokemonSystem.textskin = value
    MessageConfig.pbSetSpeechFrame("Graphics/Windowskins/" + Settings::SPEECH_WINDOWSKINS[value])
    scene.sprites["textbox"].setSkin(MessageConfig.pbGetSpeechFrame)
  }
})

MenuHandlers.add(:options_menu, :menu_frame, {
  "name"        => _INTL("Menu Frame"),
  "page"        => :graphics,
  "order"       => 30,
  "type"        => NumberOption,
  "parameters"  => 1..Settings::MENU_WINDOWSKINS.length,
  "description" => _INTL("Choose the appearance of menu boxes."),
  "get_proc"    => proc { next $PokemonSystem.frame },
  "set_proc"    => proc { |value, scene|
    $PokemonSystem.frame = value
    MessageConfig.pbSetSystemFrame("Graphics/Windowskins/" + Settings::MENU_WINDOWSKINS[value])
    scene.sprites["option"].setSkin(MessageConfig.pbGetSystemFrame)
  }
})

MenuHandlers.add(:options_menu, :screen_size, {
  "name"        => _INTL("Screen Size"),
  "page"        => :graphics,
  "order"       => 40,
  "type"        => EnumOption,
  "parameters"  => [_INTL("S"), _INTL("M"), _INTL("L"), _INTL("XL"), _INTL("Full")],
  "description" => _INTL("Choose the size of the game window."),
  "get_proc"    => proc { next [$PokemonSystem.screensize, 4].min },
  "set_proc"    => proc { |value, _scene|
    next if $PokemonSystem.screensize == value
    $PokemonSystem.screensize = value
    pbSetResizeFactor($PokemonSystem.screensize)
  }
})
