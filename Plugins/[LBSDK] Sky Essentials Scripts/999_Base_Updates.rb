#===============================================================================
# LBSDK Base Updates - Non-invasive backports from La Base de Sky
# These additions keep Data/Scripts untouched and remain opt-in where possible.
#===============================================================================

#-------------------------------------------------------------------------------
# Exp Share System (from Sky Base)
#-------------------------------------------------------------------------------
def expshare_enabled?
  return false unless $PokemonGlobal
  $PokemonGlobal.expshare_enabled ||= Settings::EXPSHARE_ENABLED || $player&.has_exp_all || $bag.has?(:EXPSHARE2)
  $PokemonGlobal.expshare_enabled ? true : false
end

class PokemonGlobalMetadata
  unless instance_methods.include?(:expshare_enabled)
    attr_accessor :expshare_enabled
  end
  alias initialize_sky_expshare_999_old initialize unless method_defined?(:initialize_sky_expshare_999_old)
  def initialize
    initialize_sky_expshare_999_old
    @expshare_enabled = Settings::EXPSHARE_ENABLED
  end
end

if Settings::USE_NEW_EXP_SHARE
  class PokemonSystem
    unless method_defined?(:expshareon)
      attr_reader :expshareon
    end
    
    unless method_defined?(:expshareon=)
      def expshareon=(value)
        @expshareon = value
      end
    end
    
    unless method_defined?(:expshareon)
      def expshareon
        @expshareon ||= 0
      end
    end
  end

  MenuHandlers.add(:options_menu, :expshareon, {
    "name"        => _INTL("Exp. Share on Capture"),
    "order"       => 40,
    "type"        => Settings::USE_NEW_OPTIONS_UI ? :array : EnumOption,
    "condition"   => proc { next expshare_enabled? },
    "parameters"  => proc { [_INTL("Yes"), _INTL("No")] },
    "description" => _INTL("Toggle Exp. Share for newly caught Pokémon."),
    "get_proc"    => proc { next $PokemonSystem.expshareon },
    "set_proc"    => proc { |value, _scene| $PokemonSystem.expshareon = value }
  })

  MenuHandlers.add(:party_menu, :expshare, {
    "name"      => _INTL("Exp. Share"),
    "order"     => 70,
    "condition" => proc { next expshare_enabled? },
    "effect"    => proc { |screen, party, party_idx|
      pokemon = party[party_idx]
      
      txt_individual = pokemon.expshare ? _INTL("Disable for {1}", pokemon.name) : _INTL("Enable for {1}", pokemon.name)
      txt_individual_msg = pokemon.expshare ? _INTL("disabled") : _INTL("enabled")
      txt_all_on     = _INTL("Enable for all")
      txt_all_off    = _INTL("Disable for all")
      txt_cancel     = _INTL("Cancel")
      commands = []
      cmd_individual = -1
      cmd_all_on     = -1
      cmd_all_off    = -1
      cmd_cancel     = -1

      if !pokemon.egg?
        commands.push(txt_individual)
        cmd_individual = commands.length - 1
      end

      commands.push(txt_all_on)
      cmd_all_on = commands.length - 1
      commands.push(txt_all_off)
      cmd_all_off = commands.length - 1
      commands.push(txt_cancel)
      cmd_cancel = commands.length - 1
      cmd = screen.pbShowCommands(_INTL("What to do?"), commands, 0)
      
      if cmd >= 0
        if cmd == cmd_individual
          pokemon.expshare = !pokemon.expshare
          screen.scene.pbRefresh
          screen.pbDisplay( _INTL("Exp. Share has been {1} for {2}.", txt_individual_msg, pokemon.name))          
        elsif cmd == cmd_all_on
          party.each do |pkmn| 
            pkmn.expshare = true if !pkmn.egg? 
          end
          screen.scene.pbRefresh
          screen.pbDisplay(_INTL("Exp. Share has been enabled for your team."))        
        elsif cmd == cmd_all_off
          party.each { |pkmn| pkmn.expshare = false }
          screen.scene.pbRefresh
          screen.pbDisplay(_INTL("Exp. Share has been disabled for your team."))
        elsif cmd == cmd_cancel
          # Do nothing
        end
      end
      
      next true
    }   
  })

  def toggle_expshare
    $PokemonGlobal.expshare_enabled ||= Settings::EXPSHARE_ENABLED || $player&.has_exp_all || $bag.has?(:EXPSHARE2)
    $PokemonGlobal.expshare_enabled = !$PokemonGlobal.expshare_enabled
    $player.party.each { |pokemon| pokemon.expshare = $PokemonGlobal.expshare_enabled }
  end
  
  class Pokemon
    unless method_defined?(:expshare)
      attr_accessor :expshare
    end
    alias initialize_sky_expshare_999_pokemon_old initialize unless method_defined?(:initialize_sky_expshare_999_pokemon_old)
    def initialize(species, level, player = $player, withMoves = true, recheck_form = true)
      initialize_sky_expshare_999_pokemon_old(species, level, player, withMoves, recheck_form)
      $PokemonSystem.expshareon ||= 0
      @expshare = expshare_enabled? && $PokemonSystem.expshareon == 0
    end 
  end
  
  #-------------------------------------------------------------------------------
  # PokemonPartyPanel - Add exp icon display
  #-------------------------------------------------------------------------------
  class PokemonPartyPanel
    alias initialize_sky_expshare_999_panel_old initialize unless method_defined?(:initialize_sky_expshare_999_panel_old)
    def initialize(pokemon, index, viewport = nil)
      initialize_sky_expshare_999_panel_old(pokemon, index, viewport)
      if @pokemon.respond_to?(:expshare) && @pokemon.expshare && !@pokemon.egg?
        @expicon = ChangelingSprite.new(0, 0, viewport)
        @expicon.add_bitmap(:expicon, "Graphics/Pictures/expicon")
        @expicon.z = self.z + 3
      end
    end

    alias lbdsk_expshare_refresh_old refresh unless method_defined?(:lbdsk_expshare_refresh_old)
    def refresh
      lbdsk_expshare_refresh_old
      draw_exp_icon
    end

    def draw_exp_icon
      return if !@pokemon.respond_to?(:expshare) || !@pokemon.expshare || @pokemon.egg?
      pbDrawImagePositions(@overlaysprite.bitmap, 
        [["Graphics/Pictures/expicon", 226, 70, 0, 0]])
    end

    def refresh_exp_icon
      return if !@expicon || @expicon.disposed?
      @expicon.x = self.x + 226
      @expicon.y = self.y + 68
      @expicon.color = self.color
    end

    alias lbdsk_expshare_dispose dispose unless method_defined?(:lbdsk_expshare_dispose)
    def dispose
      @expicon.dispose if @expicon
      lbdsk_expshare_dispose
    end

    alias lbdsk_expshare_panel_refresh refresh unless method_defined?(:lbdsk_expshare_panel_refresh)
    def refresh
      return if disposed?
      return if @refreshing
      @refreshing = true
      refresh_panel_graphic
      refresh_hp_bar_graphic
      refresh_ball_graphic
      refresh_pokemon_icon
      refresh_held_item_icon
      refresh_exp_icon if respond_to?(:refresh_exp_icon)
      if @overlaysprite && !@overlaysprite.disposed?
        @overlaysprite.x     = self.x
        @overlaysprite.y     = self.y
        @overlaysprite.color = self.color
      end
      refresh_overlay_information
      @refreshBitmap = false
      @refreshing = false
    end

    alias lbdsk_expshare_update update unless method_defined?(:lbdsk_expshare_update)
    def update
      lbdsk_expshare_update
      @expicon.update if @expicon
    end
  end
  
  #-------------------------------------------------------------------------------
  # Battle - New Exp Share system
  #-------------------------------------------------------------------------------
  class Battle
    alias lbdsk_expshare_pbgain pbGainExp unless method_defined?(:lbdsk_expshare_pbgain)
    def pbGainExp
      # Play wild victory music if it's the end of the battle
      @scene.pbWildBattleSuccess if wildBattle? && pbAllFainted?(1) && !pbAllFainted?(0)
      return if !@internalBattle || @rules[:no_exp_gain]
      
      expAll = $player.has_exp_all || $bag.has?(:EXPALL)
      p1 = pbParty(0)
      
      @battlers.each do |b|
        next unless b&.opposes?
        next if b.participants.length == 0
        next unless b.fainted? || b.captured
        
        # Count participants
        numPartic = 0
        b.participants.each do |partic|
          next unless p1[partic]&.able? && pbIsOwner?(0, partic)
          numPartic += 1
        end
        
        # Find Pokémon with Exp Share
        expShare = []
        if !expAll
          eachInTeam(0, 0) do |pkmn, i|
            next if !pkmn.able?
            next if !pkmn.hasItem?(:EXPSHARE) && 
                   GameData::Item.try_get(@initialItems[0][i]) != :EXPSHARE && 
                   !(pkmn.respond_to?(:expshare) && pkmn.expshare)
            expShare.push(i)
          end
        end
        
        # Gain EVs and Exp
        if numPartic > 0 || expShare.length > 0 || expAll
          unGroupMessage = !Settings::GROUP_EXP_SHARE_MESSAGE && expShare.length > 0 && expShare.length > b.participants.length ? true : false
          
          eachInTeam(0, 0) do |pkmn, i|
            next if !pkmn.able?
            next unless b.participants.include?(i) || expShare.include?(i)
            showMessage = b.participants.include?(i) || unGroupMessage ? true : false
            pbGainEVsOne(i, b)
            pbGainExpOne(i, b, numPartic, expShare, expAll, showMessage)
          end
          
          if !unGroupMessage && (expShare.length > numPartic && pbParty(0).length > 1)
            pbDisplayPaused(_INTL("Your other Pokémon also gained experience!"))
          end
          
          # Gain EVs and Exp for all other Pokémon because of Exp All
          if expAll
            showMessage = true
            eachInTeam(0, 0) do |pkmn, i|
              next if !pkmn.able?
              next if b.participants.include?(i) || expShare.include?(i)
              pbDisplayPaused(_INTL("Your other Pokémon also gained experience!")) if showMessage && (expShare.length > numPartic && pbParty(0).length > 1)
              showMessage = false
              pbGainEVsOne(i, b)
              pbGainExpOne(i, b, numPartic, expShare, expAll, false)
            end
          end
          b.participants = []
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# UI Width/Height Constants (for compatibility with new UI scripts)
# These provide fallback values when new UI scripts try to access them
#-------------------------------------------------------------------------------
module UI
  module Dimensions
  # Party Screen Dimensions
  PARTY_WINDOW_WIDTH  = 398
  PARTY_WINDOW_HEIGHT = 256
  
  # Bag Screen Dimensions  
  BAG_WINDOW_WIDTH   = 346
  BAG_WINDOW_HEIGHT  = 320
  
  # Summary Screen Dimensions
  SUMMARY_WINDOW_WIDTH  = 480
  SUMMARY_WINDOW_HEIGHT = 320
  
  # Pokédex Dimensions
  POKEDEX_WINDOW_WIDTH  = 482
  POKEDEX_WINDOW_HEIGHT = 352
  
  # Storage Dimensions
  STORAGE_WINDOW_WIDTH  = 480
  STORAGE_WINDOW_HEIGHT = 320
  end
end

#-------------------------------------------------------------------------------
# UI Auto-Centering Helper
# Provides methods to automatically center UIs based on their dimensions
#-------------------------------------------------------------------------------
module UI
  module AutoCenter
  module_function

  # Calculate centered X position for a UI element
  def center_x(ui_width, screen_width = Graphics.width)
    return 0 if ui_width >= screen_width
    return (screen_width - ui_width) / 2
  end

  # Calculate centered Y position for a UI element
  def center_y(ui_height, screen_height = Graphics.height)
    return 0 if ui_height >= screen_height
    return (screen_height - ui_height) / 2
  end

  # Calculate centered position as [x, y]
  def center_position(ui_width, ui_height, screen_width = Graphics.width, screen_height = Graphics.height)
    return [center_x(ui_width, screen_width), center_y(ui_height, screen_height)]
  end

  # Get dimensions from UI Dimensions module, with fallback to default values
  def get_dimensions(screen_name)
    dims = UI::Dimensions rescue nil
    return nil unless dims
    
    case screen_name.to_s.downcase
    when "party"
      return [dims::PARTY_WINDOW_WIDTH, dims::PARTY_WINDOW_HEIGHT]
    when "bag"
      return [dims::BAG_WINDOW_WIDTH, dims::BAG_WINDOW_HEIGHT]
    when "summary"
      return [dims::SUMMARY_WINDOW_WIDTH, dims::SUMMARY_WINDOW_HEIGHT]
    when "pokedex"
      return [dims::POKEDEX_WINDOW_WIDTH, dims::POKEDEX_WINDOW_HEIGHT]
    when "storage"
      return [dims::STORAGE_WINDOW_WIDTH, dims::STORAGE_WINDOW_HEIGHT]
    else
      return nil
    end
  end
  end
end

# Add auto-centering to base UI classes if they want to use it
class UI::BaseVisuals
  unless method_defined?(:lbdsk_centered_x)
    def centered_x(width)
      UI::AutoCenter.center_x(width, Graphics.width)
    end
  end
  
  unless method_defined?(:lbdsk_centered_y)
    def centered_y(height)
      UI::AutoCenter.center_y(height, Graphics.height)
    end
  end
  
  unless method_defined?(:lbdsk_centered_position)
    def centered_position(width, height)
      UI::AutoCenter.center_position(width, height, Graphics.width, Graphics.height)
    end
  end
end

#-------------------------------------------------------------------------------
# Minimal Grinding (ignore IVs/EVs when enabled)
#-------------------------------------------------------------------------------
unless defined?(MinimalGrinding)
  module MinimalGrinding
    module_function

    def on?
      return $PokemonGlobal&.minimal_grinding ? true : false
    end

    def on
      return if !$PokemonGlobal
      $PokemonGlobal.minimal_grinding = true
    end

    def off
      return if !$PokemonGlobal
      $PokemonGlobal.minimal_grinding = false
    end

    def toggle
      return if !$PokemonGlobal
      $PokemonGlobal.minimal_grinding = !$PokemonGlobal.minimal_grinding
    end
  end
end

class PokemonGlobalMetadata
  unless instance_methods.include?(:minimal_grinding)
    attr_accessor :minimal_grinding
  end
end

module LBSDK_BaseUpdates
  module PokemonStatPatch
    def calcHP(base, level, iv, ev)
      if Settings::DISABLE_IVS_AND_EVS || (defined?(MinimalGrinding) && MinimalGrinding.on?)
        iv = ev = 0
      end
      super(base, level, iv, ev)
    end

    def calcStat(base, level, iv, ev, nat)
      if Settings::DISABLE_IVS_AND_EVS || (defined?(MinimalGrinding) && MinimalGrinding.on?)
        iv = ev = 0
      end
      super(base, level, iv, ev, nat)
    end
  end
end

Pokemon.prepend(LBSDK_BaseUpdates::PokemonStatPatch) if defined?(Pokemon)

#-------------------------------------------------------------------------------
# Show Choices with images (opt-in via event comments)
#-------------------------------------------------------------------------------
unless defined?(pbGetChoiceImages)
  # Parse choice images from event comments.
  # Place comments before Show Choices command in the event:
  #   s:ChoiceImage: show_background
  #   s:ChoiceImage: 1, species, PIKACHU, 0
  #   s:ChoiceImage: 2, item, POTION
  #   s:ChoiceImage: 1, Graphics/Pokemon/Front/PIKACHU
  def pbGetChoiceImages(commands)
    return nil unless pbMapInterpreterRunning?
    interpreter = pbMapInterpreter
    event = interpreter.get_self
    return nil unless event

    current_index = interpreter.instance_variable_get(:@index)
    return nil unless current_index

    choice_images = {}
    show_background = false

    (current_index - 1).downto(0) do |i|
      item = event.list[i]
      next unless item
      break if [102, 402, 404].include?(item.code)
      next unless [108, 408].include?(item.code)
      next unless item.parameters[0].start_with?("s:ChoiceImage:")

      parts = item.parameters[0].sub("s:ChoiceImage:", "").split(",").map(&:strip)
      if parts[0].downcase == "show_background"
        show_background = true
        next
      end
      next if parts.length < 2

      index = parts[0].to_i - 1
      next if index < 0

      bitmap = nil
      if parts[1] == "species" && parts.length >= 3
        species = parts[2].to_sym
        form = parts[3] ? parts[3].to_i : 0
        bitmap = GameData::Species.sprite_bitmap(species, form) if GameData::Species.exists?(species)
      elsif parts[1] == "item" && parts.length >= 3
        item_id = parts[2].to_sym
        bitmap = GameData::Item.icon_bitmap(item_id) if GameData::Item.exists?(item_id)
      else
        file_path = parts[1..-1].join(",").strip
        resolved_path = pbResolveBitmap(file_path)
        bitmap = AnimatedBitmap.new(resolved_path) if resolved_path
      end

      choice_images[index] = bitmap if bitmap
    end

    return nil if choice_images.empty?
    return { images: choice_images, show_background: show_background }
  end
end

unless defined?(pbParseChoiceImages)
  def pbParseChoiceImages(commands)
    result = pbGetChoiceImages(commands)
    return commands unless result

    choice_images = result[:images]
    show_background = result[:show_background]

    parsed_commands = []
    commands.each_with_index do |cmd, i|
      if choice_images[i]
        parsed_commands.push([cmd, choice_images[i], show_background])
      else
        parsed_commands.push(cmd)
      end
    end
    return parsed_commands
  end
end

module Kernel
  unless method_defined?(:lbdsk_pbShowCommands_with_choice_images)
    alias lbdsk_pbShowCommands_with_choice_images pbShowCommands
    def pbShowCommands(msgwindow, commands = nil, cmdIfCancel = 0, defaultCmd = 0)
      commands = pbParseChoiceImages(commands) if commands && defined?(pbParseChoiceImages)
      lbdsk_pbShowCommands_with_choice_images(msgwindow, commands, cmdIfCancel, defaultCmd)
    end
  end
end

#-------------------------------------------------------------------------------
# Hover image support for command windows (used by choice images)
#-------------------------------------------------------------------------------
unless defined?(HoverImageMixin)
  module HoverImageMixin
    def initHoverImage
      @hover_image = Sprite.new(self.viewport)
      @hover_image.z = self.z + 100
      @hover_image.visible = false
      @hover_background = Sprite.new(self.viewport)
      @hover_background.z = self.z + 99
      @hover_background.visible = false
      @hover_animated_bitmap = nil
      @current_image_path = nil
      @command_images ||= []
      @command_show_background ||= []
    end

    def parseCommandsWithImages(commands)
      @commands = []
      @command_images = []
      @command_show_background = []
      commands.each do |cmd|
        if cmd.is_a?(Array)
          @commands.push(cmd[0])
          @command_images.push(cmd.length > 1 ? cmd[1] : nil)
          @command_show_background.push(cmd.length > 2 ? cmd[2] : nil)
        else
          @commands.push(cmd)
          @command_images.push(nil)
          @command_show_background.push(nil)
        end
      end
    end

    def disposeHoverImage
      if @hover_image
        @hover_image.bitmap.dispose if @hover_image.bitmap && !@hover_animated_bitmap
        @hover_image.dispose
        @hover_image = nil
      end
      if @hover_background
        @hover_background.bitmap.dispose if @hover_background.bitmap
        @hover_background.dispose
        @hover_background = nil
      end
      @hover_animated_bitmap.dispose if @hover_animated_bitmap&.respond_to?(:dispose)
      @hover_animated_bitmap = nil
    end

    def updateHoverImage
      return unless self.active && self.visible && @command_images && @command_images.length > 0

      initHoverImage unless @hover_image
      image_source = @command_images[self.index]
      show_background = @command_show_background && @command_show_background[self.index]

      if image_source && self.index >= 0 && self.index < @command_images.length
        if @current_image_path != image_source || @current_show_background != show_background
          setHoverImage(image_source, show_background)
        end
        updateHoverImagePosition if @hover_image.visible
      else
        @hover_image.visible = false
        @hover_background.visible = false if @hover_background
        @current_image_path = nil
        @current_show_background = nil
      end
    end

    private

    def setHoverImage(source, show_background = false)
      return unless isValidImageSource?(source)

      clearHoverBitmap
      if source.is_a?(AnimatedBitmap) || (defined?(DeluxeBitmapWrapper) && source.is_a?(DeluxeBitmapWrapper))
        @hover_animated_bitmap = source
      end
      @hover_image.bitmap = copyBitmap(extractBitmap(source))
      @current_image_path = source
      @current_show_background = show_background
      @hover_image.visible = true

      if show_background && @hover_background
        createHoverBackground(@hover_image.bitmap.width, @hover_image.bitmap.height)
        @hover_background.visible = true
      elsif @hover_background
        @hover_background.visible = false
      end

      updateHoverImagePosition
    rescue => e
      puts "Error loading hover image: #{e.message}"
      @hover_image.visible = false
      @hover_background.visible = false if @hover_background
      @current_image_path = nil
      @current_show_background = nil
    end

    def isValidImageSource?(source)
      source.is_a?(Bitmap) || source.is_a?(AnimatedBitmap) ||
      (defined?(DeluxeBitmapWrapper) && source.is_a?(DeluxeBitmapWrapper)) ||
      (source.is_a?(String) && File.exist?(source))
    end

    def extractBitmap(source)
      case source
      when AnimatedBitmap then source.bitmap
      when Bitmap then source
      when String then Bitmap.new(source)
      else
        if defined?(DeluxeBitmapWrapper) && source.is_a?(DeluxeBitmapWrapper)
          source.bitmap
        end
      end
    end

    def copyBitmap(bitmap)
      return nil unless bitmap && !bitmap.disposed?
      copy = Bitmap.new(bitmap.width, bitmap.height)
      copy.blt(0, 0, bitmap, Rect.new(0, 0, bitmap.width, bitmap.height))
      copy
    end

    def clearHoverBitmap
      if @hover_image.bitmap && !@hover_animated_bitmap
        @hover_image.bitmap.dispose
      end
      @hover_image.bitmap = nil
    end

    def createHoverBackground(img_width, img_height)
      @hover_background.bitmap.dispose if @hover_background.bitmap

      windowskin_path = MessageConfig.pbGetSystemFrame
      if windowskin_path && windowskin_path != "" && pbResolveBitmap(windowskin_path)
        temp_skin = Bitmap.new(windowskin_path)
        if temp_skin.width == 128 && temp_skin.height == 128
          border_size = 16
          slice = Rect.new(16, 16, 96, 96)
        elsif temp_skin.width == 192 && temp_skin.height == 128
          border_size = 16
          slice = Rect.new(16, 16, 160, 96)
        else
          border_size = 16
          slice = Rect.new(16, 16, temp_skin.width - 32, temp_skin.height - 32)
        end
        temp_skin.dispose

        @hover_padding = border_size
        bg_width = img_width + (border_size * 2)
        bg_height = img_height + (border_size * 2)
        rect = Rect.new(0, 0, bg_width, bg_height)
        @hover_background.bitmap = Bitmap.smartWindow(slice, rect, windowskin_path)
      else
        @hover_padding = 8
        bg_width = img_width + (@hover_padding * 2)
        bg_height = img_height + (@hover_padding * 2)

        @hover_background.bitmap = Bitmap.new(bg_width, bg_height)
        base_color = Color.new(0, 0, 0, 160)
        border_color = Color.new(255, 255, 255, 200)
        @hover_background.bitmap.fill_rect(0, 0, bg_width, bg_height, base_color)
        border_width = 2
        @hover_background.bitmap.fill_rect(0, 0, bg_width, border_width, border_color)
        @hover_background.bitmap.fill_rect(0, bg_height - border_width, bg_width, border_width, border_color)
        @hover_background.bitmap.fill_rect(0, 0, border_width, bg_height, border_color)
        @hover_background.bitmap.fill_rect(bg_width - border_width, 0, border_width, bg_height, border_color)
      end
    end

    def updateHoverImagePosition
      @hover_image.viewport = self.viewport

      if @hover_background && @hover_background.visible
        padding = @hover_padding || 16
        @hover_background.z = self.z + 99
        @hover_background.viewport = self.viewport
        @hover_background.x = self.x - @hover_background.bitmap.width - 8
        @hover_background.y = self.y + (self.height / 2) - (@hover_background.bitmap.height / 2)
        @hover_image.z = self.z + 100
        @hover_image.x = @hover_background.x + padding
        @hover_image.y = @hover_background.y + padding
      else
        @hover_image.z = self.z + 100
        @hover_image.x = self.x - @hover_image.bitmap.width - 8
        @hover_image.y = self.y + (self.height / 2) - (@hover_image.bitmap.height / 2)
      end
    end
  end
end

class Window_AdvancedCommandPokemon < Window_DrawableCommand
  include HoverImageMixin unless included_modules.include?(HoverImageMixin)
  attr_reader :command_images unless method_defined?(:command_images)

  unless method_defined?(:lbdsk_images_initialize)
    alias lbdsk_images_initialize initialize
    def initialize(commands, width = nil)
      if commands.is_a?(Array) && commands.any? { |c| c.is_a?(Array) }
        @starting = true
        dims = []
        super(0, 0, 32, 32)
        parseCommandsWithImages(commands)
        getAutoDims(@commands, dims, width)
        self.width = dims[0]
        self.height = dims[1]
        initHoverImage
        self.active = true
        @baseColor, @shadowColor = getDefaultTextColors(self.windowskin)
        refresh
        @starting = false
      else
        lbdsk_images_initialize(commands, width)
      end
    end
  end

  unless method_defined?(:lbdsk_images_commands_set)
    alias lbdsk_images_commands_set commands=
    def commands=(value)
      if value.is_a?(Array) && value.any? { |c| c.is_a?(Array) }
        parseCommandsWithImages(value)
        @item_max = @commands.length
        self.update_cursor_rect
        self.refresh
      else
        lbdsk_images_commands_set(value)
      end
    end
  end

  def command_images=(value)
    @command_images = value
    self.refresh
  end

  unless method_defined?(:lbdsk_images_update)
    alias lbdsk_images_update update
    def update
      lbdsk_images_update
      updateHoverImage if respond_to?(:updateHoverImage)
    end
  end

  unless method_defined?(:lbdsk_images_dispose)
    alias lbdsk_images_dispose dispose
    def dispose
      disposeHoverImage if respond_to?(:disposeHoverImage)
      lbdsk_images_dispose
    end
  end
end

#-------------------------------------------------------------------------------
# Extended message text colors (more \c[n] options)
#-------------------------------------------------------------------------------
unless defined?(get_text_colors_for_windowskin)
  def get_text_colors_for_windowskin(windowskin, color, isDarkSkin, no_ctag = true)
    if windowskin && !windowskin.disposed? && windowskin.width == 128 && windowskin.height == 128
      color = 0 if color >= 32
      x = 64 + ((color % 8) * 8)
      y = 96 + ((color / 8) * 8)
      pixel = windowskin.get_pixel(x, y)
      return no_ctag ? [pixel, pixel.get_contrast_color] : shadowc3tag(pixel, pixel.get_contrast_color)
    end
    # Base color, shadow color (these are reversed on dark windowskins)
    # Values in arrays are RGB numbers
    textcolors = [
      [  0, 112, 248], [120, 184, 232],   # 1  Blue
      [232,  32,  16], [248, 168, 184],   # 2  Red
      [ 96, 176,  72], [174, 208, 144],   # 3  Green
      [ 72, 216, 216], [168, 224, 224],   # 4  Cyan
      [208,  56, 184], [232, 160, 224],   # 5  Magenta
      [232, 208,  32], [248, 232, 136],   # 6  Yellow
      [160, 160, 168], [208, 208, 216],   # 7  Gray
      [240, 240, 248], [120, 120, 128],   # 8  White
      [114,  64, 232], [184, 168, 224],   # 9  Purple
      [248, 152,  24], [248, 200, 152],   # 10 Orange
      MessageConfig::DARK_TEXT_MAIN_COLOR,
      MessageConfig::DARK_TEXT_SHADOW_COLOR,   # 11 Dark default
      MessageConfig::LIGHT_TEXT_MAIN_COLOR,
      MessageConfig::LIGHT_TEXT_SHADOW_COLOR,  # 12 Light default
      [120, 120, 128], [240, 240, 248],   # 13 White with black background
      [138,  90,  43], [216, 184, 154],   # 14 Brown
      [240,  96, 144], [248, 184, 200],   # 15 Pink
      [152, 224,  32], [216, 240, 168],   # 16 Lime
      [ 32,  56, 112], [144, 168, 216],   # 17 Navy
      [140,  32,  32], [216, 160, 160],   # 18 Maroon
      [ 32, 128, 112], [152, 200, 184],   # 19 Teal
      [ 88, 168, 240], [184, 216, 248],   # 20 Sky Blue
      [128, 128,  32], [200, 200, 160],   # 21 Olive
      [224, 200, 160], [248, 232, 208],   # 22 Beige
      [184, 144, 224], [224, 208, 248],   # 23 Lavender
      [216, 176,  32], [240, 224, 168],   # 24 Gold
      [240, 160,  32], [248, 216, 168],   # 25 Amber
      [248, 160, 144], [248, 216, 200],   # 26 Peach
      [200,  32,  48], [240, 160, 168],   # 27 Crimson
      [248, 120,  88], [248, 200, 184],   # 28 Coral
      [ 64,  64, 168], [184, 184, 232],   # 29 Indigo
      [ 96, 120, 160], [192, 208, 232],   # 30 Slate Blue
      [ 96, 216, 168], [200, 240, 224],   # 31 Mint
      [ 32,  96,  32], [152, 192, 152],   # 32 Forest Green
      [112,  32,  64], [200, 160, 184],   # 33 Plum
      [168, 144, 120], [224, 208, 200],   # 34 Warm Gray
      [128, 144, 168], [208, 216, 232]    # 35 Cool Gray
    ]
    if color == 0 || color > textcolors.length / 2   # No special colour, use default
      if isDarkSkin   # Dark background, light text
        return no_ctag ? [MessageConfig::LIGHT_TEXT_MAIN_COLOR, MessageConfig::LIGHT_TEXT_SHADOW_COLOR] :
          shadowc3tag(MessageConfig::LIGHT_TEXT_MAIN_COLOR, MessageConfig::LIGHT_TEXT_SHADOW_COLOR)
      end
      # Light background, dark text
      return no_ctag ? [MessageConfig::DARK_TEXT_MAIN_COLOR, MessageConfig::DARK_TEXT_SHADOW_COLOR] :
        shadowc3tag(MessageConfig::DARK_TEXT_MAIN_COLOR, MessageConfig::DARK_TEXT_SHADOW_COLOR)
    end
    # Special colour as listed above
    if isDarkSkin && color != 12   # Dark background, light text
      if textcolors[2 * (color - 1)].is_a?(Color)
        if no_ctag
          return textcolors[(2 * (color - 1)) + 1], textcolors[2 * (color - 1)]
        else
          return shadowc3tag(textcolors[(2 * (color - 1)) + 1], textcolors[2 * (color - 1)])
        end
      end
      if no_ctag
        return Color.new(*textcolors[(2 * (color - 1)) + 1]), Color.new(*textcolors[2 * (color - 1)])
      end
      return shadowc3tag(Color.new(*textcolors[(2 * (color - 1)) + 1]), Color.new(*textcolors[2 * (color - 1)]))
    end
    # Light background, dark text
    if textcolors[2 * (color - 1)].is_a?(Color)
      if no_ctag
        return textcolors[2 * (color - 1)], textcolors[(2 * (color - 1)) + 1]
      end
      return shadowc3tag(textcolors[2 * (color - 1)], textcolors[(2 * (color - 1)) + 1])
    end
    if no_ctag
      return Color.new(*textcolors[2 * (color - 1)]), Color.new(*textcolors[(2 * (color - 1)) + 1])
    end
    return shadowc3tag(Color.new(*textcolors[2 * (color - 1)]), Color.new(*textcolors[(2 * (color - 1)) + 1]))
  end
end

def getSkinColor(windowskin, color, isDarkSkin)
  return get_text_colors_for_windowskin(windowskin, color, isDarkSkin, false) if defined?(get_text_colors_for_windowskin)
  return ""
end

#-------------------------------------------------------------------------------
# Critical hit message color (orange)
#-------------------------------------------------------------------------------
class Battle::Scene
  MESSAGE_BASE_CRITICAL_COLOR = Color.new(248, 96, 8) unless const_defined?(:MESSAGE_BASE_CRITICAL_COLOR)
  MESSAGE_SHADOW_CRITICAL_COLOR = Color.new(248, 176, 128) unless const_defined?(:MESSAGE_SHADOW_CRITICAL_COLOR)
end

class Battle::Move
  unless method_defined?(:lbdsk_pbHitEffectivenessMessages)
    alias lbdsk_pbHitEffectivenessMessages pbHitEffectivenessMessages
    def pbHitEffectivenessMessages(user, target, numTargets = 1)
      return if target.damageState.disguise || target.damageState.iceFace
      if target.damageState.substitute
        @battle.pbDisplay(_INTL("The substitute took damage for {1}!", target.pbThis(true)))
      end
      if target.damageState.critical
        if $game_temp.party_critical_hits_dealt &&
           $game_temp.party_critical_hits_dealt[user.pokemonIndex] &&
           user.pbOwnedByPlayer?
          $game_temp.party_critical_hits_dealt[user.pokemonIndex] += 1
        end
        crit_color = nil
        if defined?(Battle::Scene::MESSAGE_BASE_CRITICAL_COLOR) &&
           defined?(Battle::Scene::MESSAGE_SHADOW_CRITICAL_COLOR)
          crit_color = Battle::Scene::MESSAGE_BASE_CRITICAL_COLOR.to_rgb24 + "," +
                       Battle::Scene::MESSAGE_SHADOW_CRITICAL_COLOR.to_rgb24
        end
        if target.damageState.affection_critical
          if numTargets > 1
            if crit_color
              @battle.pbDisplay(_INTL("{1} <c3={2}>landed a critical hit on {3}, wishing to be praised!</c3>",
                                      user.pbThis, crit_color, target.pbThis(true)))
            else
              @battle.pbDisplay(_INTL("{1} landed a critical hit on {2}, wishing to be praised!",
                                      user.pbThis, target.pbThis(true)))
            end
          elsif crit_color
            @battle.pbDisplay(_INTL("{1} <c3={2}>landed a critical hit, wishing to be praised!</c3>",
                                    user.pbThis, crit_color))
          else
            @battle.pbDisplay(_INTL("{1} landed a critical hit, wishing to be praised!", user.pbThis))
          end
        elsif numTargets > 1
          if crit_color
            @battle.pbDisplay(_INTL("<c3={1}>A critical hit on {2}!</c3>", crit_color, target.pbThis(true)))
          else
            @battle.pbDisplay(_INTL("A critical hit on {1}!", target.pbThis(true)))
          end
        elsif crit_color
          @battle.pbDisplay(_INTL("<c3={1}>A critical hit!</c3>", crit_color))
        else
          @battle.pbDisplay(_INTL("A critical hit!"))
        end
      end
      # Effectiveness message, for moves with 1 hit
      if !multiHitMove? && user.effects[PBEffects::ParentalBond] == 0
        pbEffectivenessMessage(user, target, numTargets)
      end
      if target.damageState.substitute && target.effects[PBEffects::Substitute] == 0
        target.effects[PBEffects::Substitute] = 0
        @battle.pbDisplay(_INTL("{1}'s substitute faded!", target.pbThis))
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Player speed constants (default speed centralized)
#-------------------------------------------------------------------------------
class Game_Player < Game_Character
  PLAYER_SPEEDS = {
    :walking             => 3,
    :walking_stopped     => 3,
    :running             => 4,
    :ice_sliding         => 4,
    :cycling             => 5,
    :cycling_fast        => 5,
    :cycling_jumping     => 3,
    :cycling_stopped     => 5,
    :waterfall           => 2,
    :descending_waterfall => 2,
    :ascending_waterfall => 2,
    :surfing             => 4,
    :surfing_fast        => 4,
    :surfing_jumping     => 3,
    :surfing_stopped     => 4,
    :diving              => 3,
    :diving_fast         => 3,
    :diving_jumping      => 3,
    :diving_stopped      => 3
  } unless const_defined?(:PLAYER_SPEEDS)
end

class Game_Player
  unless method_defined?(:lbdsk_speed_can_run)
    alias lbdsk_speed_can_run can_run?
    def can_run?
      speed_table = self.class.const_defined?(:PLAYER_SPEEDS) ? self.class::PLAYER_SPEEDS : {}
      walking_speed = speed_table[:walking] || 3
      return @move_speed > walking_speed if @move_route_forcing
      return false if @bumping
      return false if $game_temp.in_menu || $game_temp.in_battle ||
                      $game_temp.message_window_showing || pbMapInterpreterRunning?
      return false if !$player.has_running_shoes && !$PokemonGlobal.diving &&
                      !$PokemonGlobal.surfing && !$PokemonGlobal.bicycle
      return false if jumping?
      return false if pbTerrainTag.must_walk
      return ($PokemonSystem.runstyle == 1) ^ Input.press?(Input::BACK)
    end
  end

  unless method_defined?(:lbdsk_speed_set_movement_type)
    alias lbdsk_speed_set_movement_type set_movement_type
    def set_movement_type(type)
      meta = GameData::PlayerMetadata.get($player&.character_ID || 1)
      new_charset = nil
      speed_table = self.class.const_defined?(:PLAYER_SPEEDS) ? self.class::PLAYER_SPEEDS : {}
      speed = speed_table[type] || speed_table[:walking] || 3
      case type
      when :fishing
        new_charset = pbGetPlayerCharset(meta.fish_charset)
      when :surf_fishing
        new_charset = pbGetPlayerCharset(meta.surf_fish_charset)
      when :diving, :diving_fast, :diving_jumping, :diving_stopped
        self.move_speed = speed if !@move_route_forcing
        new_charset = pbGetPlayerCharset(meta.dive_charset)
      when :surfing, :surfing_fast, :surfing_jumping, :surfing_stopped
        self.move_speed = speed if !@move_route_forcing
        new_charset = pbGetPlayerCharset(meta.surf_charset)
      when :descending_waterfall, :ascending_waterfall
        self.move_speed = speed if !@move_route_forcing
        new_charset = pbGetPlayerCharset(meta.surf_charset)
      when :cycling, :cycling_fast, :cycling_jumping, :cycling_stopped
        self.move_speed = speed if !@move_route_forcing
        new_charset = pbGetPlayerCharset(meta.cycle_charset)
      when :running
        self.move_speed = speed if !@move_route_forcing
        new_charset = pbGetPlayerCharset(meta.run_charset)
      when :ice_sliding
        self.move_speed = speed if !@move_route_forcing
        new_charset = pbGetPlayerCharset(meta.walk_charset)
      else   # :walking, :jumping, :walking_stopped
        self.move_speed = speed if !@move_route_forcing
        new_charset = pbGetPlayerCharset(meta.walk_charset)
      end
      self.move_speed = (speed_table[:walking] || 3) if @bumping
      @character_name = new_charset if new_charset
    end
  end
end
