#===============================================================================
#  Sky Essentials Utilities
#  Collection of useful scripts from LA BASE DE SKY
#===============================================================================

# Add missing constants for compatibility with Essentials v21.1
module GameData
  class Type
    class << self
      unless const_defined?(:ICON_SIZE)
        ICON_SIZE = [64, 28]
      end
    end
  end

  class Move
    class << self
      unless const_defined?(:CATEGORY_ICON_SIZE)
        CATEGORY_ICON_SIZE = [64, 28]
      end
    end
  end
end

# Add natural sort key method for compatibility
def natural_sort_key(str)
  # Simple implementation of natural sort key
  return str.downcase.gsub(/(\d+)/) { |s| format('%010d', s.to_i) }
end

# Add pb_message_free_text_with_on_input for compatibility with LBSDK search functionality
def pb_message_free_text_with_on_input(message, currenttext, passwordbox, maxlength, width = 240, on_input = nil, position = :right, &block)
  # This is a simplified implementation that doesn't support the on_input callback
  # because Essentials v21.1 doesn't have this feature natively
  return pbMessageFreeText(message, currenttext, passwordbox, maxlength, width, &block)
end

# Add from_pocket method for GameData::Item class
module GameData
  class Item
    class << self
      unless method_defined?(:from_pocket)
        def from_pocket(pocket_number)
          # Return all item IDs in the specified pocket, sorted by id
          return DATA.values.select { |item| item.pocket == pocket_number }.sort_by { |item| item.id }.map { |item| item.id }
        end
      end
    end
  end
end

#===============================================================================
# Always on bush by DPertierra
#===============================================================================
class Game_Character
  def calculate_bush_depth
    if @tile_id > 0 || @always_on_top || jumping?
      @bush_depth = 0
      return
    end
    this_map = (self.map.valid?(@x, @y)) ? [self.map, @x, @y] : $map_factory&.getNewMap(@x, @y, self.map.map_id)
    if this_map && ( this_map[0].deepBush?(this_map[1], this_map[2]) || this_map[0].bush?(this_map[1], this_map[2]))
      xbehind = @x + (@direction == 4 ? 1 : @direction == 6 ? -1 : 0)
      ybehind = @y + (@direction == 8 ? 1 : @direction == 2 ? -1 : 0)
      if moving?
        behind_map = (self.map.valid?(xbehind, ybehind)) ? [self.map, xbehind, ybehind] : $map_factory&.getNewMap(xbehind, ybehind, self.map.map_id)
        @bush_depth = 12 if behind_map && ((behind_map[0].bush?(behind_map[1], behind_map[2]) || behind_map[0].deepBush?(behind_map[1], behind_map[2])))
      else
        @bush_depth = 12
      end
    else
      @bush_depth = 0
    end
  end
end

#===============================================================================
# Exit Arrows - by Tustin2121, edited by Skyflyer
#===============================================================================
class Game_Player < Game_Character
  # Run when the player turns.
  def check_event_trigger_after_turning
    pxCheckExitArrows
  end
end

class Game_Character
  # Add accessors for some otherwise hidden options
  attr_accessor :step_anime
  attr_accessor :direction_fix
end

# Checks if the player is standing next to the exit arrow, facing it.
def pxCheckExitArrows(init=false)
  px = $game_player.x
  py = $game_player.y
  for event in $game_map.events.values
    next if !event.name[/^ExitArrow$/]
    event.transparent = ! (
      (px==event.x && py==event.y-1) ||
      (px==event.x && py==event.y+1) ||
      (px==event.x+1 && py==event.y) ||
      (px==event.x-1 && py==event.y) )
    if init
      # This homogenizes the Exit Arrows to all act the same, that is
      # a slow flashing arrow. If you want to change the behavior,
      # change the values below.
      event.move_speed = 1
      event.walk_anime = false
      event.step_anime = true
      event.direction_fix = true
    end
  end
end

# Run on scene change, init them as well
EventHandlers.add(:on_map_or_spriteset_change, :exit_arrows, proc{|sender,e|
  pxCheckExitArrows(true)
})

# Run on every step taken
EventHandlers.add(:on_leave_tile, :exit_arrows, proc{|sender,e|
  pxCheckExitArrows
})

#===============================================================================
# Turbo V21.1
#===============================================================================
module TurboConfig
  SPEED_STAGES = [1.0, 2.0, 2.5]  # x1 (normal), x3
  TOGGLE_KEYS = [Input::ALT, Input::AUX1]
  ICON_DURATION = 150
end

$GameSpeed = 0
$CanToggle = true
$RefreshEventsForTurbo = false
$SpeedDifference = 0

module System
  class << self
    unless method_defined?(:unscaled_uptime)
      alias_method :unscaled_uptime, :uptime
    end
    
    unless method_defined?(:real_uptime)
      def real_uptime
        return unscaled_uptime
      end
    end
  end

  def self.uptime
    return (unscaled_uptime * TurboConfig::SPEED_STAGES[$GameSpeed]) + $SpeedDifference
  end
end

module Input
  class << self
    alias_method :turbo_update, :update unless method_defined?(:turbo_update)
  end

  def self.update
    turbo_update
    
    if TurboConfig::TOGGLE_KEYS.any? { |key| trigger?(key) } && ( !Input.text_input || !trigger?(Input::AUX1) )
      real_now = System.unscaled_uptime
      virtual_now = System.uptime
      
      $GameSpeed += 1
      $GameSpeed = 0 if $GameSpeed >= TurboConfig::SPEED_STAGES.size
      
      new_mult = TurboConfig::SPEED_STAGES[$GameSpeed]
      $SpeedDifference = virtual_now - (real_now * new_mult)
      $RefreshEventsForTurbo = true
      $buttonframes = 0
    end
  end
end

class PokemonSystem
  alias_method :original_initialize, :initialize unless method_defined?(:original_initialize)
  attr_accessor :only_speedup_battles
  attr_accessor :battle_speed

  def initialize
    original_initialize
    @only_speedup_battles = 0
    @battle_speed = 0 
  end
end

module Game
  class << self
    alias_method :original_load, :load unless method_defined?(:original_load)
  end

  def self.load(save_data)
    original_load(save_data)
    # Always allow toggling turbo speed
    $CanToggle = true
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:options_menu, :turbo, {
    "name"        => _INTL("Turbo Mode"),
    "order"       => 45,
    "type"        => EnumOption,
    "condition"   => proc { next $player },
    "parameters"  => [_INTL("Always"), _INTL("Battles Only")],
    "description" => _INTL("Define if turbo mode is always active or only in battles."),
    "get_proc"    => proc { next $PokemonSystem&.only_speedup_battles || 0 },
    "set_proc"    => proc { |value, _scene| 
      next unless $PokemonSystem
      $PokemonSystem.only_speedup_battles = value 
      
      # Always allow toggling turbo speed
      $CanToggle = true
    }
  })
end

EventHandlers.add(:on_start_battle, :start_speedup, proc {
  if $PokemonSystem&.only_speedup_battles == 1
    $GameSpeed = TurboConfig::SPEED_STAGES.size - 1  # x3 for battles only
    $RefreshEventsForTurbo = true
  end
})

EventHandlers.add(:on_end_battle, :stop_speedup, proc {
  if $PokemonSystem&.only_speedup_battles == 1
    $GameSpeed = 0  # Back to normal speed
    $RefreshEventsForTurbo = true
  end
})

class Game_Map
  alias_method :original_update, :update unless method_defined?(:original_update)

  def update
    if $RefreshEventsForTurbo
      if $game_map&.events
        $game_map.events.each_value { |event| event.pbResetInterpreterWaitCount if event }
      end
      if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing && $CurrentMsgWindow
        $CurrentMsgWindow.pbResetWaitCounter 
      end
      $RefreshEventsForTurbo = false
    end

    temp_timer = @fog_scroll_last_update_timer
    @fog_scroll_last_update_timer = System.uptime 
    original_update
    @fog_scroll_last_update_timer = temp_timer
    update_fog
  end

  def update_fog
    uptime_now = System.unscaled_uptime
    @fog_scroll_last_update_timer = uptime_now unless @fog_scroll_last_update_timer
    speedup_mult = ($PokemonSystem&.only_speedup_battles == 1) ? 1 : TurboConfig::SPEED_STAGES[$GameSpeed]
    
    scroll_mult = (uptime_now - @fog_scroll_last_update_timer) * 5 * speedup_mult
    @fog_ox -= @fog_sx * scroll_mult
    @fog_oy -= @fog_sy * scroll_mult
    @fog_scroll_last_update_timer = uptime_now
  end
end

class SpriteAnimation
  def update_animation
    new_index = ((System.uptime - @_animation_timer_start) / @_animation_time_per_frame).to_i
    if new_index >= @_animation_duration
      dispose_animation
      return
    end
    quick_update = (@_animation_index == new_index)
    @_animation_index = new_index
    frame_index = @_animation_index
    current_frame = @_animation.frames[frame_index]
    unless current_frame
      dispose_animation
      return
    end
    cell_data   = current_frame.cell_data
    position    = @_animation.position
    animation_set_sprites(@_animation_sprites, cell_data, position, quick_update)
    return if quick_update
    @_animation.timings.each do |timing|
      next if timing.frame != frame_index
      animation_process_timing(timing, @_animation_hit)
    end
  end
end

alias :original_pbBattleOnStepTaken :pbBattleOnStepTaken
def pbBattleOnStepTaken(repel_active)
  return if $game_temp.in_battle
  original_pbBattleOnStepTaken(repel_active)
end

class Game_Event < Game_Character
  def pbResetInterpreterWaitCount
    @interpreter.pbRefreshWaitCount if @interpreter
  end
end  

class Interpreter
  def pbRefreshWaitCount
    @wait_count = 0
    @wait_start = System.uptime
  end  
end  

class Window_AdvancedTextPokemon < SpriteWindow_Base
  def pbResetWaitCounter
    @wait_timer_start = nil
    @waitcount = 0
    @display_last_updated = nil
  end  
end  

$CurrentMsgWindow = nil;
def pbMessage(message, commands = nil, cmdIfCancel = 0, skin = nil, defaultCmd = 0, &block)
  ret = 0
  msgwindow = pbCreateMessageWindow(nil, skin)
  $CurrentMsgWindow = msgwindow

  if commands
    ret = pbMessageDisplay(msgwindow, message, true,
                           proc { |msgwndw|
                             next Kernel.pbShowCommands(msgwndw, commands, cmdIfCancel, defaultCmd, &block)
                           }, &block)
  else
    pbMessageDisplay(msgwindow, message, &block)
  end
  pbDisposeMessageWindow(msgwindow)
  $CurrentMsgWindow = nil
  Input.update
  return ret
end

module Graphics
  class << self
    alias _old_update_turbo update
    
    def update
      _old_update_turbo
      $buttonframes = TurboConfig::ICON_DURATION if !$buttonframes
      
      if $buttonframes < TurboConfig::ICON_DURATION
        if !@boton_turbo || @boton_turbo.disposed?
          @boton_turbo = Sprite.new
          @boton_turbo.z = 999999
          @boton_turbo.x = 8
          @boton_turbo.y = 8
          set_turbo_bitmap
        elsif @boton_turbo
          set_turbo_bitmap
        end
        
        $buttonframes += 1
        if $buttonframes >= TurboConfig::ICON_DURATION
          @boton_turbo.dispose
        end
      end
    end

    def set_turbo_bitmap
      bmp_name = "Graphics/Pictures/Turbo#{$GameSpeed}"
      return if @last_turbo_speed == $GameSpeed && @boton_turbo.bitmap
      
      if defined?(pbResolveBitmap) && pbResolveBitmap(bmp_name)
        @boton_turbo.bitmap = Bitmap.new(bmp_name)
      else
        @boton_turbo.bitmap = Bitmap.new(32, 32) unless @boton_turbo.bitmap
      end
      
      @last_turbo_speed = $GameSpeed
    end
  end
end

EventHandlers.add(:on_enter_map, :fix_turbo_collision, proc { |_map_id|
  unless $DEBUG && Input.press?(Input::CTRL)
    if $game_player
      if $game_player.through
        player_x = $game_player.x
        player_y = $game_player.y
        
        unless $game_player.passable?(player_x, player_y, 0)
          passable_x, passable_y = $game_player.find_nearest_passable_spot(player_x, player_y)
          if passable_x && passable_y
            $game_player.moveto(passable_x, passable_y)
            $game_player.through = false
          end
        else
          $game_player.through = false
        end
      end
    end
  end
})

#===============================================================================
# Base Searcher - Base class for searchable interfaces
#===============================================================================
class BaseSearcher
  SEARCH_BOX_MAX_LENGTH = 32
  SEARCH_BOX_WIDTH = 240

  def open_search_box(position = :right)
    on_input = ->(text, char = '') { search_by_name(text, char) }
    term = pb_message_free_text_with_on_input(search_prompt, "", false, SEARCH_BOX_MAX_LENGTH, width = SEARCH_BOX_WIDTH, on_input = on_input, position = position)

    return false if ['', nil].include?(term)

    search_by_name(term)
  end

  def search_by_name(text, _char = '')
    current_index = get_current_index
    search_list = get_search_list
    
    index = search(text, current_index, search_list.length)
    return on_search_complete(index) if index

    if current_index.positive?
      index = search(text, 0, current_index)
      return on_search_complete(index) if index
    end
    
    false
  end

  def search(text, start_index, end_index)
    get_search_list[start_index...end_index].each_with_index do |item, offset|
      next unless valid_item?(item)
      
      item_name = get_item_name(item)
      return start_index + offset if matches_name?(item_name, text)
    end
    false
  end

  def matches_name?(item_name, text)
    pbSmartMatch?(item_name, text)
  end

  def valid_item?(item)
    true
  end

  def on_search_complete(index)
    refresh_display(index)
    index
  end

  def get_item_name(item)
    raise NotImplementedError, "#{self.class} must implement #get_item_name"
  end

  def get_search_list
    raise NotImplementedError, "#{self.class} must implement #get_search_list"
  end

  def get_current_index
    raise NotImplementedError, "#{self.class} must implement #get_current_index"
  end

  def refresh_display(index)
    raise NotImplementedError, "#{self.class} must implement #refresh_display"
  end

  def search_prompt
    _INTL("What are you looking for?")
  end
end

#===============================================================================
# Exp Share System
#===============================================================================
def expshare_enabled?
    return false unless $PokemonGlobal
    $PokemonGlobal.expshare_enabled ||= Settings::EXPSHARE_ENABLED || $player&.has_exp_all || $bag.has?(:EXPSHARE2)
    $PokemonGlobal.expshare_enabled ? true : false
end

class PokemonGlobalMetadata
    attr_accessor :expshare_enabled
    alias initialize_expshare initialize
    def initialize
        initialize_expshare
        @expshare_enabled = Settings::EXPSHARE_ENABLED
    end
end

if Settings::USE_NEW_EXP_SHARE
    class PokemonSystem
        attr_accessor :expshareon
    end

    MenuHandlers.add(:options_menu, :expshareon, {
        "name"        => _INTL("Capture Exp Share"),
        "order"       => 40,
        "type"        => EnumOption,
        "condition"   => proc { next expshare_enabled? },
        "parameters"  => [_INTL("Yes"), _INTL("No")],
        "description" => _INTL("Whether captured Pokémon should have Exp Share activated."),
        "get_proc"    => proc { next $PokemonSystem.expshareon },
        "set_proc"    => proc { |value, _scene| $PokemonSystem.expshareon = value }
    })

    MenuHandlers.add(:party_menu, :expshare, {
        "name"      => _INTL("Exp Share"),
        "order"     => 70,
        "condition" => proc { next expshare_enabled? },
        "effect"    => proc { |screen, party, party_idx|
                pokemon = party[party_idx]
                var_msg = pokemon.expshare ? _INTL("deactivate") : _INTL("activate")
                pokemon.expshare = !pokemon.expshare if pbConfirmMessage(_INTL("Do you want to {1} Exp Share on this Pokémon?", var_msg))
        }   
    })

    def toggle_expshare
        $PokemonGlobal.expshare_enabled ||= Settings::EXPSHARE_ENABLED || $player&.has_exp_all || $bag.has?(:EXPSHARE2)
        $PokemonGlobal.expshare_enabled = !$PokemonGlobal.expshare_enabled
        $player.party.each { |pokemon| pokemon.expshare = $PokemonGlobal.expshare_enabled }
    end
    
    class Pokemon
        attr_accessor(:expshare)
        alias initialize_old initialize
        def initialize(species, level, player = $player, withMoves = true, recheck_form = true)
            initialize_old(species, level, player, withMoves)
            $PokemonSystem.expshareon ||= 0
            @expshare = expshare_enabled? && $PokemonSystem.expshareon == 0
        end 
    end
    
    class PokemonPartyPanel < Sprite
        alias initialize_old initialize
        def initialize(pokemon,index,viewport=nil)
            initialize_old(pokemon,index,viewport)
            if @pokemon.expshare && !@pokemon.egg?
                @expicon = ChangelingSprite.new(0, 0, viewport)
                @expicon.add_bitmap(:expicon,"Graphics/Pictures/expicon")
                @expicon.z=self.z+3
            end
        end

        alias refresh_overlay_information_old refresh_overlay_information
        def refresh_overlay_information
            refresh_overlay_information_old
            draw_exp_icon
        end

        def draw_exp_icon
            return if !@pokemon.expshare || @pokemon.egg?
            pbDrawImagePositions(@overlaysprite.bitmap, 
            [["Graphics/Pictures/expicon", 226, 70, 0, 0]])
        end

        def refresh_exp_icon
            return if !@expicon || @expicon.disposed?
            @expicon.x=self.x+226
            @expicon.y=self.y+68
            @expicon.color=self.color
        end

        def dispose
            @panelbgsprite.dispose
            @hpbgsprite.dispose
            @ballsprite.dispose
            @pkmnsprite.dispose
            @helditemsprite.dispose
            @overlaysprite.bitmap.dispose
            @overlaysprite.dispose
            @hpbar.dispose
            @statuses.dispose
            @expicon.dispose if @expicon
            super
        end
        
        def refresh
            return if disposed?
            return if @refreshing
            @refreshing = true
            refresh_panel_graphic
            refresh_hp_bar_graphic
            refresh_ball_graphic
            refresh_pokemon_icon
            refresh_held_item_icon
            refresh_exp_icon
            if @overlaysprite && !@overlaysprite.disposed?
            @overlaysprite.x     = self.x
            @overlaysprite.y     = self.y
            @overlaysprite.color = self.color
            end
            refresh_overlay_information
            @refreshBitmap = false
            @refreshing = false
        end

        alias update_old update
        def update
            update_old
            @expicon.update if @expicon 
        end
        
    end
    
    class Battle 
        def pbGainExp
            @scene.pbWildBattleSuccess if wildBattle? && pbAllFainted?(1) && !pbAllFainted?(0)
            return if !@internalBattle || !@expGain
            
            expAll = $player.has_exp_all || $bag.has?(:EXPALL) 
            p1 = pbParty(0)
            @battlers.each do |b|
            next unless b&.opposes?
            next if b.participants.length == 0
            next unless b.fainted? || b.captured
            
            numPartic = 0
            b.participants.each do |partic|
                next unless p1[partic]&.able? && pbIsOwner?(0, partic)
                numPartic += 1
            end
            
            expShare = []
            if !expAll
                eachInTeam(0, 0) do |pkmn, i|
                    next if !pkmn.able?
                    next if (!pkmn.hasItem?(:EXPSHARE) && GameData::Item.try_get(@initialItems[0][i]) != :EXPSHARE) && !pkmn.expshare
                    expShare.push(i)
                end
            end
            
            if numPartic > 0 || expShare.length > 0 || expAll
                unGroupMessage = (!defined?(Settings::GROUP_EXP_SHARE_MESSAGE) || !Settings::GROUP_EXP_SHARE_MESSAGE) && expShare.length > 0 && expShare.length > b.participants.length ? true : false
                
                eachInTeam(0, 0) do |pkmn, i|
                    next if !pkmn.able?
                    next unless b.participants.include?(i) || expShare.include?(i)
                    showMessage = b.participants.include?(i) || unGroupMessage ? true : false
                    pbGainEVsOne(i, b)
                    pbGainExpOne(i, b, numPartic, expShare, expAll, showMessage)
                end
                if !unGroupMessage && (expShare.length > numPartic && pbParty(0).length > 1)
                    pbDisplayPaused(_INTL("Your other Pokémon also gained experience points!"))
                end
                
                if expAll
                    showMessage = true
                    eachInTeam(0, 0) do |pkmn, i|
                        next if !pkmn.able?
                        next if b.participants.include?(i) || expShare.include?(i) 
                        pbDisplayPaused(_INTL("Your other Pokémon also gained experience points!")) if showMessage && (expShare.length > numPartic && pbParty(0).length > 1)
                        showMessage = false
                        pbGainEVsOne(i, b)
                        pbGainExpOne(i, b, numPartic, expShare, expAll, false)
                    end
                end
            end
            
            b.participants = []
            end
        end
    end
end
