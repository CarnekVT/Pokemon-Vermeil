# #===============================================================================
# #
# #===============================================================================
# UI_FOLDER = "Options/"

# class PokemonSystem
#   attr_accessor :textspeed
#   attr_accessor :battlescene
#   attr_accessor :battlestyle
#   attr_accessor :sendtoboxes
#   attr_accessor :givenicknames
#   attr_accessor :frame
#   attr_accessor :textskin
#   attr_accessor :screensize
#   attr_accessor :language
#   attr_accessor :runstyle
#   attr_accessor :bgmvolume
#   attr_accessor :sevolume
#   attr_accessor :textinput

#   def initialize
#     @textspeed     = 1     # Text speed (0=slow, 1=medium, 2=fast, 3=instant)
#     @battlescene   = 0     # Battle effects (animations) (0=on, 1=off)
#     @battlestyle   = 0     # Battle style (0=switch, 1=set)
#     @sendtoboxes   = 0     # Send to Boxes (0=manual, 1=automatic)
#     @givenicknames = 0     # Give nicknames (0=give, 1=don't give)
#     @frame         = 0     # Default window frame (see also Settings::MENU_WINDOWSKINS)
#     @textskin      = 0     # Speech frame
#     @screensize    = (Settings::SCREEN_SCALE * 2).floor - 1   # 0=half size, 1=full size, 2=full-and-a-half size, 3=double size
#     @language      = 0     # Language (see also Settings::LANGUAGES in script PokemonSystem)
#     @runstyle      = 0     # Default movement speed (0=walk, 1=run)
#     @bgmvolume     = 80    # Volume of background music and ME
#     @sevolume      = 100   # Volume of sound effects
#     @textinput     = 0     # Text input mode (0=cursor, 1=keyboard)
#   end
# end

# #===============================================================================
# #
# #===============================================================================
# module PropertyMixin
#   attr_reader :name

#   def get
#     return @get_proc&.call
#   end

#   def set(*args)
#     @set_proc&.call(*args)
#   end
# end

# #===============================================================================
# #
# #===============================================================================
# class EnumOption
#   include PropertyMixin
#   attr_reader :values

#   def initialize(name, values, get_proc, set_proc)
#     @name     = name
#     @values   = values.map { |val| _INTL(val) }
#     @get_proc = get_proc
#     @set_proc = set_proc
#   end

#   def next(current)
#     index = current + 1
#     index = @values.length - 1 if index > @values.length - 1
#     return index
#   end

#   def prev(current)
#     index = current - 1
#     index = 0 if index < 0
#     return index
#   end
# end

# #===============================================================================
# #
# #===============================================================================
# class NumberOption
#   include PropertyMixin
#   attr_reader :lowest_value
#   attr_reader :highest_value

#   def initialize(name, range, get_proc, set_proc)
#     @name = name
#     case range
#     when Range
#       @lowest_value  = range.begin
#       @highest_value = range.end
#     when Array
#       @lowest_value  = range[0]
#       @highest_value = range[1]
#     end
#     @get_proc = get_proc
#     @set_proc = set_proc
#   end

#   def next(current)
#     index = current + @lowest_value
#     index += 1
#     index = @lowest_value if index > @highest_value
#     return index - @lowest_value
#   end

#   def prev(current)
#     index = current + @lowest_value
#     index -= 1
#     index = @highest_value if index < @lowest_value
#     return index - @lowest_value
#   end
# end

# #===============================================================================
# #
# #===============================================================================
# class SliderOption
#   include PropertyMixin
#   attr_reader :lowest_value
#   attr_reader :highest_value

#   def initialize(name, range, get_proc, set_proc)
#     @name          = name
#     @lowest_value  = range[0]
#     @highest_value = range[1]
#     @interval      = range[2]
#     @get_proc      = get_proc
#     @set_proc      = set_proc
#   end

#   def next(current)
#     index = current + @lowest_value
#     index += @interval
#     index = @highest_value if index > @highest_value
#     return index - @lowest_value
#   end

#   def prev(current)
#     index = current + @lowest_value
#     index -= @interval
#     index = @lowest_value if index < @lowest_value
#     return index - @lowest_value
#   end
# end

# #===============================================================================
# #
# #===============================================================================
# module PageHandlers
#   @@handlers = {}

#   def self.add(menu, page, hash)
#     @@handlers[menu] = {} if !@@handlers.has_key?(menu)
#     @@handlers[menu][page] = hash
#   end

#   def self.each_available(menu)
#     return if !@@handlers.has_key?(menu)
#     keys = @@handlers[menu].keys.sort { |a, b| (@@handlers[menu][a][:order] || 99) <=> (@@handlers[menu][b][:order] || 99) }
#     keys.each { |page| yield page, @@handlers[menu][page] }
#   end
# end

# #===============================================================================
# # Main options list
# #===============================================================================
# class Window_PokemonOption < Window_DrawableCommand
#   attr_reader :value_changed
#   attr_reader :options

#   SEL_NAME_BASE_COLOR    = Color.new(192, 120, 0)
#   SEL_NAME_SHADOW_COLOR  = Color.new(248, 176, 80)
#   SEL_VALUE_BASE_COLOR   = Color.new(248, 48, 24)
#   SEL_VALUE_SHADOW_COLOR = Color.new(248, 136, 128)

#   def initialize(options, x, y, width, height)
#     @options = options
#     @values = []
#     @options.length.times { |i| @values[i] = 0 }
#     @value_changed = false
#     super(x, y, width, height)
#   end

#   def options=(value)
#     @options = value
#     @values = []
#     @options.length.times { |i| @values[i] = 0 }
#   end

#   def [](i)
#     return @values[i]
#   end

#   def []=(i, value)
#     @values[i] = value
#     refresh
#   end

#   def setValueNoRefresh(i, value)
#     @values[i] = value
#   end

#   def itemCount
#     return @options.length
#   end

#   def drawItem(index, _count, rect)
#     rect = drawCursor(index, rect)
#     sel_index = self.index
#     # Draw option's name
#     optionname = @options[index].name
#     optionwidth = rect.width * 9 / 20
#     pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height, optionname,
#                      (index == sel_index) ? SEL_NAME_BASE_COLOR : self.baseColor,
#                      (index == sel_index) ? SEL_NAME_SHADOW_COLOR : self.shadowColor)
#     # Draw option's values
#     case @options[index]
#     when EnumOption
#       if @options[index].values.length > 1
#         totalwidth = 0
#         @options[index].values.each do |value|
#           totalwidth += self.contents.text_size(value).width
#         end
#         spacing = (rect.width - rect.x - optionwidth - totalwidth) / (@options[index].values.length - 1)
#         spacing = 0 if spacing < 0
#         xpos = optionwidth + rect.x
#         ivalue = 0
#         @options[index].values.each do |value|
#           pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
#                            (ivalue == self[index]) ? SEL_VALUE_BASE_COLOR : self.baseColor,
#                            (ivalue == self[index]) ? SEL_VALUE_SHADOW_COLOR : self.shadowColor)
#           xpos += self.contents.text_size(value).width
#           xpos += spacing
#           ivalue += 1
#         end
#       else
#         pbDrawShadowText(self.contents, rect.x + optionwidth, rect.y, optionwidth, rect.height,
#                          optionname, self.baseColor, self.shadowColor)
#       end
#     when NumberOption
#       value = _INTL("Type {1}/{2}", @options[index].lowest_value + self[index],
#                     @options[index].highest_value - @options[index].lowest_value + 1)
#       xpos = optionwidth + (rect.x * 2)
#       pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
#                        SEL_VALUE_BASE_COLOR, SEL_VALUE_SHADOW_COLOR, 1)
#     when SliderOption
#       value = sprintf(" %d", @options[index].highest_value)
#       sliderlength = rect.width - rect.x - optionwidth - self.contents.text_size(value).width
#       xpos = optionwidth + rect.x
#       self.contents.fill_rect(xpos, rect.y - 2 + (rect.height / 2), sliderlength, 4, self.baseColor)
#       self.contents.fill_rect(
#         xpos + ((sliderlength - 8) * (@options[index].lowest_value + self[index]) / @options[index].highest_value),
#         rect.y - 8 + (rect.height / 2),
#         8, 16, SEL_VALUE_BASE_COLOR
#       )
#       value = (@options[index].lowest_value + self[index]).to_s
#       xpos += (rect.width - rect.x - optionwidth) - self.contents.text_size(value).width
#       pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
#                        SEL_VALUE_BASE_COLOR, SEL_VALUE_SHADOW_COLOR)
#     else
#       value = @options[index].values[self[index]]
#       xpos = optionwidth + rect.x
#       pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height, value,
#                        SEL_VALUE_BASE_COLOR, SEL_VALUE_SHADOW_COLOR)
#     end
#   end

#   def update
#     oldindex = self.index
#     @value_changed = false
#     super
#     dorefresh = (self.index != oldindex)
#     if self.active && self.index < @options.length
#       if Input.repeat?(Input::LEFT)
#         self[self.index] = @options[self.index].prev(self[self.index])
#         dorefresh = true
#         @value_changed = true
#       elsif Input.repeat?(Input::RIGHT)
#         self[self.index] = @options[self.index].next(self[self.index])
#         dorefresh = true
#         @value_changed = true
#       end
#     end
#     refresh if dorefresh
#   end
# end

# #===============================================================================
# # Options main screen
# #===============================================================================
# class PokemonOption_Scene
#   attr_reader :sprites
#   attr_reader :in_load_screen

#   def pbStartScene(in_load_screen = false)
#     @in_load_screen = in_load_screen
#     # Create sprites
#     @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
#     @viewport.z = 99999
#     @sprites = {}
#     addBackgroundOrColoredPlane(@sprites, "bg", UI_FOLDER + "bg_options", Color.new(32, 32, 32), @viewport)
    
#     # Page Icons
#     @sprites["page_icons"] = IconSprite.new(0, 0, @viewport)
#     @sprites["page_icons"].setBitmap("Graphics/UI/" + UI_FOLDER + "page_icons")
#     @sprites["page_icons"].x = (Graphics.width - @sprites["page_icons"].bitmap.width) / 2
#     @sprites["page_icons"].y = 10
    
#     # Page Cursor
#     @sprites["page_cursor"] = IconSprite.new(0, 0, @viewport)
#     @sprites["page_cursor"].setBitmap("Graphics/UI/" + UI_FOLDER + "cursor_page")
#     @sprites["page_cursor"].x = @sprites["page_icons"].x
#     @sprites["page_cursor"].y = @sprites["page_icons"].y

#     @sprites["textbox"] = pbCreateMessageWindow
#     pbSetSystemFont(@sprites["textbox"].contents)
    
#     @sprites["option"] = Window_PokemonOption.new(
#       [], 0, 64, Graphics.width, Graphics.height - 64 - @sprites["textbox"].height
#     )
#     @sprites["option"].viewport = @viewport
#     @sprites["option"].visible  = true
    
#     # Get pages
#     @pages = []
#     PageHandlers.each_available(:options_menu) do |page, hash|
#       @pages.push({ :id => page, :name => hash[:name], :description => hash[:description] })
#     end
#     @page_index = 0
#     @focus = :options
    
#     pbRefreshPage
#     pbFadeInAndShow(@sprites) { pbUpdate }
#   end

#   def pbRefreshPage
#     @options = []
#     @hashes = []
#     current_page_id = @pages[@page_index][:id]
    
#     MenuHandlers.each_available(:options_menu) do |option, hash, name|
#       opt_page = hash["page"] || :gameplay
#       next if opt_page != current_page_id
#       @options.push(
#         hash["type"].new(name, hash["parameters"], hash["get_proc"], hash["set_proc"])
#       )
#       @hashes.push(hash)
#     end
    
#     @sprites["option"].options = @options
#     # Get the values of each option
#     @options.length.times { |i| @sprites["option"].setValueNoRefresh(i, @options[i].get || 0) }
#     @sprites["option"].refresh
    
#     # Update page cursor
#     if @pages.length > 0
#       cursor_width = @sprites["page_icons"].bitmap.width / @pages.length
#       @sprites["page_cursor"].x = @sprites["page_icons"].x + (@page_index * cursor_width)
#     end
    
#     if @focus == :options
#       @sprites["option"].index = 0
#       pbChangeSelection
#     else
#       @sprites["option"].index = -1
#       @sprites["textbox"].text = _INTL("Select a category.")
#     end
#   end

#   def pbChangeSelection
#     if @sprites["option"].index < 0
#       @sprites["textbox"].text = _INTL("Select a category.")
#       return
#     end
#     hash = @hashes[@sprites["option"].index]
#     # Call selected option's "on_select" proc (if defined)
#     @sprites["textbox"].letterbyletter = false
#     hash["on_select"]&.call(self) if hash
#     # Set descriptive text
#     description = ""
#     if hash
#       if hash["description"].is_a?(Proc)
#         description = hash["description"].call
#       elsif !hash["description"].nil?
#         description = _INTL(hash["description"])
#       end
#     else
#       description = _INTL("Choose an option.")
#     end
#     @sprites["textbox"].text = description
#   end

#   def pbOptions
#     pbActivateWindow(@sprites, "option") do
#       index = -1
#       loop do
#         Graphics.update
#         Input.update
        
#         if @focus == :options
#           if Input.trigger?(Input::UP) && @sprites["option"].index == 0
#             @focus = :tabs
#             @sprites["option"].active = false
#             @sprites["option"].index = -1
#             @sprites["textbox"].text = _INTL("Select a category.")
#             pbPlayCursorSE
#           end
#         elsif @focus == :tabs
#           if Input.trigger?(Input::DOWN)
#             @focus = :options
#             @sprites["option"].active = true
#             @sprites["option"].index = 0
#             pbChangeSelection
#             pbPlayCursorSE
#           elsif Input.trigger?(Input::LEFT)
#             pbPlayCursorSE
#             @page_index = (@page_index - 1) % @pages.length
#             pbRefreshPage
#           elsif Input.trigger?(Input::RIGHT)
#             pbPlayCursorSE
#             @page_index = (@page_index + 1) % @pages.length
#             pbRefreshPage
#           end
#         end

#         if Input.trigger?(Input::L)
#           pbPlayCursorSE
#           @page_index = (@page_index - 1) % @pages.length
#           pbRefreshPage
#         elsif Input.trigger?(Input::R)
#           pbPlayCursorSE
#           @page_index = (@page_index + 1) % @pages.length
#           pbRefreshPage
#         end

#         pbUpdate
#         if @focus == :options && @sprites["option"].index != index
#           pbChangeSelection
#           index = @sprites["option"].index
#         end
#         if @focus == :options && index >= 0
#           @options[index].set(@sprites["option"][index], self) if @sprites["option"].value_changed
#         end
        
#         if Input.trigger?(Input::BACK)
#           break
#         end
#       end
#     end
#   end

#   def pbEndScene
#     pbPlayCloseMenuSE
#     pbFadeOutAndHide(@sprites) { pbUpdate }
#     # Set the values of each option, to make sure they're all set
#     pbDisposeMessageWindow(@sprites["textbox"])
#     pbDisposeSpriteHash(@sprites)
#     pbUpdateSceneMap
#     @viewport.dispose
#   end

#   def pbUpdate
#     pbUpdateSpriteHash(@sprites)
#   end
# end

# #===============================================================================
# #
# #===============================================================================
# class PokemonOptionScreen
#   def initialize(scene)
#     @scene = scene
#   end

#   def pbStartScreen(in_load_screen = false)
#     @scene.pbStartScene(in_load_screen)
#     @scene.pbOptions
#     @scene.pbEndScene
#   end
# end

# #===============================================================================
# # Page Definitions
# #===============================================================================
# PageHandlers.add(:options_menu, :gameplay, {
#   :name        => _INTL("Gameplay"),
#   :order       => 10,
#   :description => _INTL("Change gameplay settings.")
# })

# PageHandlers.add(:options_menu, :audio, {
#   :name        => _INTL("Audio"),
#   :order       => 20,
#   :description => _INTL("Change audio settings.")
# })

# PageHandlers.add(:options_menu, :graphics, {
#   :name        => _INTL("Graphics"),
#   :order       => 30,
#   :description => _INTL("Change graphics settings.")
# })

# #===============================================================================
# # Options Menu commands
# #===============================================================================
# MenuHandlers.add(:options_menu, :bgm_volume, {
#   "name"        => _INTL("Music Volume"),
#   "page"        => :audio,
#   "order"       => 10,
#   "type"        => SliderOption,
#   "parameters"  => [0, 100, 5],   # [minimum_value, maximum_value, interval]
#   "description" => _INTL("Adjust the volume of the background music."),
#   "get_proc"    => proc { next $PokemonSystem.bgmvolume },
#   "set_proc"    => proc { |value, scene|
#     next if $PokemonSystem.bgmvolume == value
#     $PokemonSystem.bgmvolume = value
#     next if scene.in_load_screen || $game_system.playing_bgm.nil?
#     playingBGM = $game_system.getPlayingBGM
#     $game_system.bgm_pause
#     $game_system.bgm_resume(playingBGM)
#   }
# })

# MenuHandlers.add(:options_menu, :se_volume, {
#   "name"        => _INTL("SE Volume"),
#   "page"        => :audio,
#   "order"       => 20,
#   "type"        => SliderOption,
#   "parameters"  => [0, 100, 5],   # [minimum_value, maximum_value, interval]
#   "description" => _INTL("Adjust the volume of sound effects."),
#   "get_proc"    => proc { next $PokemonSystem.sevolume },
#   "set_proc"    => proc { |value, _scene|
#     next if $PokemonSystem.sevolume == value
#     $PokemonSystem.sevolume = value
#     if $game_system.playing_bgs
#       $game_system.playing_bgs.volume = value
#       playingBGS = $game_system.getPlayingBGS
#       $game_system.bgs_pause
#       $game_system.bgs_resume(playingBGS)
#     end
#     pbPlayCursorSE
#   }
# })

# MenuHandlers.add(:options_menu, :text_speed, {
#   "name"        => _INTL("Text Speed"),
#   "page"        => :gameplay,
#   "order"       => 30,
#   "type"        => EnumOption,
#   "parameters"  => [_INTL("Slow"), _INTL("Mid"), _INTL("Fast"), _INTL("Inst")],
#   "description" => _INTL("Choose the speed at which text appears."),
#   "on_select"   => proc { |scene| scene.sprites["textbox"].letterbyletter = true },
#   "get_proc"    => proc { next $PokemonSystem.textspeed },
#   "set_proc"    => proc { |value, scene|
#     next if value == $PokemonSystem.textspeed
#     $PokemonSystem.textspeed = value
#     MessageConfig.pbSetTextSpeed(MessageConfig.pbSettingToTextSpeed(value))
#     # Display the message with the selected text speed to gauge it better.
#     scene.sprites["textbox"].textspeed      = MessageConfig.pbGetTextSpeed
#     scene.sprites["textbox"].letterbyletter = true
#     scene.sprites["textbox"].text           = scene.sprites["textbox"].text
#   }
# })

# MenuHandlers.add(:options_menu, :battle_animations, {
#   "name"        => _INTL("Battle Effects"),
#   "page"        => :graphics,
#   "order"       => 40,
#   "type"        => EnumOption,
#   "parameters"  => [_INTL("On"), _INTL("Off")],
#   "description" => _INTL("Choose whether you wish to see move animations in battle."),
#   "get_proc"    => proc { next $PokemonSystem.battlescene },
#   "set_proc"    => proc { |value, _scene| $PokemonSystem.battlescene = value }
# })

# MenuHandlers.add(:options_menu, :battle_style, {
#   "name"        => _INTL("Battle Style"),
#   "page"        => :gameplay,
#   "order"       => 50,
#   "type"        => EnumOption,
#   "parameters"  => [_INTL("Switch"), _INTL("Set")],
#   "description" => _INTL("Choose whether you can switch Pokémon when an opponent's Pokémon faints."),
#   "get_proc"    => proc { next $PokemonSystem.battlestyle },
#   "set_proc"    => proc { |value, _scene| $PokemonSystem.battlestyle = value }
# })

# MenuHandlers.add(:options_menu, :movement_style, {
#   "name"        => _INTL("Default Movement"),
#   "page"        => :gameplay,
#   "order"       => 60,
#   "type"        => EnumOption,
#   "parameters"  => [_INTL("Walking"), _INTL("Running")],
#   "description" => _INTL("Choose your movement speed. Hold Back while moving to move at the other speed."),
#   "condition"   => proc { next $player&.has_running_shoes },
#   "get_proc"    => proc { next $PokemonSystem.runstyle },
#   "set_proc"    => proc { |value, _sceme| $PokemonSystem.runstyle = value }
# })

# MenuHandlers.add(:options_menu, :send_to_boxes, {
#   "name"        => _INTL("Send to Boxes"),
#   "page"        => :gameplay,
#   "order"       => 70,
#   "type"        => EnumOption,
#   "parameters"  => [_INTL("Manual"), _INTL("Automatic")],
#   "description" => _INTL("Choose whether caught Pokémon are sent to your Boxes when your party is full."),
#   "condition"   => proc { next Settings::NEW_CAPTURE_CAN_REPLACE_PARTY_MEMBER },
#   "get_proc"    => proc { next $PokemonSystem.sendtoboxes },
#   "set_proc"    => proc { |value, _scene| $PokemonSystem.sendtoboxes = value }
# })

# MenuHandlers.add(:options_menu, :give_nicknames, {
#   "name"        => _INTL("Give Nicknames"),
#   "page"        => :gameplay,
#   "order"       => 80,
#   "type"        => EnumOption,
#   "parameters"  => [_INTL("Give"), _INTL("Don't give")],
#   "description" => _INTL("Choose whether you can give a nickname to a Pokémon when you obtain it."),
#   "get_proc"    => proc { next $PokemonSystem.givenicknames },
#   "set_proc"    => proc { |value, _scene| $PokemonSystem.givenicknames = value }
# })

# MenuHandlers.add(:options_menu, :speech_frame, {
#   "name"        => _INTL("Speech Frame"),
#   "page"        => :graphics,
#   "order"       => 90,
#   "type"        => NumberOption,
#   "parameters"  => 1..Settings::SPEECH_WINDOWSKINS.length,
#   "description" => _INTL("Choose the appearance of dialogue boxes."),
#   "get_proc"    => proc { next $PokemonSystem.textskin },
#   "set_proc"    => proc { |value, scene|
#     $PokemonSystem.textskin = value
#     MessageConfig.pbSetSpeechFrame("Graphics/Windowskins/" + Settings::SPEECH_WINDOWSKINS[value])
#     # Change the windowskin of the options text box to selected one
#     scene.sprites["textbox"].setSkin(MessageConfig.pbGetSpeechFrame)
#   }
# })

# MenuHandlers.add(:options_menu, :menu_frame, {
#   "name"        => _INTL("Menu Frame"),
#   "page"        => :graphics,
#   "order"       => 100,
#   "type"        => NumberOption,
#   "parameters"  => 1..Settings::MENU_WINDOWSKINS.length,
#   "description" => _INTL("Choose the appearance of menu boxes."),
#   "get_proc"    => proc { next $PokemonSystem.frame },
#   "set_proc"    => proc { |value, scene|
#     $PokemonSystem.frame = value
#     MessageConfig.pbSetSystemFrame("Graphics/Windowskins/" + Settings::MENU_WINDOWSKINS[value])
#     # Change the windowskin of the options text box to selected one
#     scene.sprites["option"].setSkin(MessageConfig.pbGetSystemFrame)
#   }
# })

# MenuHandlers.add(:options_menu, :text_input_style, {
#   "name"        => _INTL("Text Entry"),
#   "page"        => :gameplay,
#   "order"       => 110,
#   "type"        => EnumOption,
#   "parameters"  => [_INTL("Cursor"), _INTL("Keyboard")],
#   "description" => _INTL("Choose how you want to enter text."),
#   "get_proc"    => proc { next $PokemonSystem.textinput },
#   "set_proc"    => proc { |value, _scene| $PokemonSystem.textinput = value }
# })

# MenuHandlers.add(:options_menu, :screen_size, {
#   "name"        => _INTL("Screen Size"),
#   "page"        => :graphics,
#   "order"       => 120,
#   "type"        => EnumOption,
#   "parameters"  => [_INTL("S"), _INTL("M"), _INTL("L"), _INTL("XL"), _INTL("Full")],
#   "description" => _INTL("Choose the size of the game window."),
#   "get_proc"    => proc { next [$PokemonSystem.screensize, 4].min },
#   "set_proc"    => proc { |value, _scene|
#     next if $PokemonSystem.screensize == value
#     $PokemonSystem.screensize = value
#     pbSetResizeFactor($PokemonSystem.screensize)
#   }
# })
