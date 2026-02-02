#===============================================================================
# Storage Grabber
# By Swdfm
# Used For Storage Utilities
#===============================================================================
class StorageGrabber
  def initialize
    clear
  end
  
  #===============================================================================
  # Adds hovered over pokemon to held pokemon
  #===============================================================================
  def add_to(position, position_1)
    @mons.push([position, position_1])
  end

  #===============================================================================
  # Is the grabber holding a Pokemon?
  #===============================================================================
  def holding_anything?
    return !@mons.empty?
  end
  
  #===============================================================================
  # Sets the pivot (top left Pokemon)
  #===============================================================================
  def setPivot(selection)
    @pivot      = selection
    @mock_pivot = selection
  end
  
  #===============================================================================
  # Begins hovering phase
  #===============================================================================
  def do_with(selection)
    p_col = @pivot % PokemonBox::BOX_WIDTH
    p_row = (@pivot / PokemonBox::BOX_WIDTH).floor
    s_col = selection % PokemonBox::BOX_WIDTH
    s_row = (selection / PokemonBox::BOX_WIDTH).floor
    @mons = []
    f_row = [p_row, s_row].min # F stands for flow
    f_col = [p_col, s_col].min
    @mock_pivot = f_col + f_row * PokemonBox::BOX_WIDTH
    for i in 0...PokemonBox::BOX_WIDTH
      next if (i < p_col && i < s_col) || (i > p_col && i > s_col)
      for j in 0...PokemonBox::BOX_HEIGHT
        next if (j < p_row && j < s_row) || (j > p_row && j > s_row)
        add_to(i - f_col,  j - f_row)
      end
    end
  end
  
  #===============================================================================
  # Is the grabber carrying?
  #===============================================================================
  def carrying
    return @carrying
  end
  
  def carrying=(value)
    @carrying = value
  end
  
  #===============================================================================
  # Adds Pokémon and their positions (relative to top left) to @carried_mons
  #===============================================================================
  def pack_up(storage, box_num)
    ret   = []
    p_col = @mock_pivot % PokemonBox::BOX_WIDTH
    p_row = (@mock_pivot / PokemonBox::BOX_WIDTH).floor
    for i in @mons
      x, y = i
      sel  = (p_row + y) * PokemonBox::BOX_WIDTH + (p_col + x)
      pkmn = storage[box_num, sel]
      ret.push([pkmn, x, y])
    end
    @carried_mons = ret
    @source_box = box_num  # Track the source box
  end
  
  #===============================================================================
  # Gets storage index of carried mons for deletion
  #===============================================================================
  def get_carried_mons
    ret   = []
    p_col = @mock_pivot % PokemonBox::BOX_WIDTH
    p_row = (@mock_pivot / PokemonBox::BOX_WIDTH).floor
    for i in @carried_mons
      x = i[1] + p_col
      y = i[2] + p_row
      ret.push(y * PokemonBox::BOX_WIDTH + x)
    end
    return ret
  end
  
  #===============================================================================
  # Places mons in those positions
  # STOPS IF THERE IS NOT A SPACE FOR EVERY MON
  #===============================================================================
  def place_with_positions(storage, box_num, selection)
    s_col = selection % PokemonBox::BOX_WIDTH
    s_row = (selection / PokemonBox::BOX_WIDTH).floor
    can_place = true
    for i in @carried_mons
      col = s_col + i[1]
      if col >= PokemonBox::BOX_WIDTH
        can_place = false 
        next
      end
      row = s_row + i[2]
      if row >= PokemonBox::BOX_HEIGHT
        can_place = false
        next
      end
      pseudo_sel = row * PokemonBox::BOX_WIDTH + col
      can_place = false if storage[box_num, pseudo_sel] # Occupied
    end
    return can_place
  end
  
  #===============================================================================
  # Gets index number of mons proposed to be put in boxes in above def.
  #===============================================================================
  def get_new_carried_mons(selection)
    
    ret   = []
    s_col = selection % PokemonBox::BOX_WIDTH
    s_row = (selection / PokemonBox::BOX_WIDTH).floor
    for i in @carried_mons
      col = s_col + i[1]
      row = s_row + i[2]
      pseudo_sel = row * PokemonBox::BOX_WIDTH + col
      ret.push([pseudo_sel, i[0]])
    end
    return ret
  end
  
  #===============================================================================
  # Removes any poured Pokemon
  #===============================================================================
  def pour(count)
    return if count == 0
    to_del = get_new_carried_mons(0)
	  to_del = to_del.sort{ |a, b| a[0] <=> b[0] }
	  ret = @carried_mons.clone
    count.times do
      ret.pop
    end
  	@carried_mons = ret
  end
  
  #===============================================================================
  # Clears everything
  #===============================================================================
  def clear
    @mons         = []
    @pivot        = nil
    @mock_pivot   = nil
    @carrying     = false
    @carried_mons = []
    @source_box   = nil
  end
  
  #===============================================================================
  # Utilities
  #===============================================================================
  def mons
    return @mons
  end
  
  def mock_pivot
    return @mock_pivot
  end
  
  def contains_an_egg?
    for i in @carried_mons
      return true if i[0]&.egg?
    end
    return false
  end
  
  def carried_mons
    return @carried_mons
  end
  
  def source_box
    return @source_box
  end
end

#===============================================================================
# PokemonStorage override
#===============================================================================
class PokemonStorage
  def swap(one, two)
    t = @boxes[one]
    @boxes[one] = @boxes[two]
    @boxes[two] = t
  end
end

#===============================================================================
# Storage System Utilities
# By Swdfm
# Works For Both Essentials Version 20 and 21
#===============================================================================
# Configuration options in PluginSettings

#===============================================================================
# Using Version 21 or not?
#===============================================================================
def pbVersion21?
  return Essentials::VERSION.include?("21")
end

#===============================================================================
# Nitty Gritty below here!
# Don't touch unless you knwo what you're doing!
#===============================================================================
# PokemonBoxIcon Overrides
#===============================================================================
class PokemonBoxIcon < IconSprite
  #===============================================================================
  # Turns the sprite(s) into a certain colour
  #===============================================================================
  def make_clear
    @type = :Clear
  end
  def make_green
    @type = :Green
  end
  def make_grey
    @type = :Grey
  end
  
  #===============================================================================
  # update Override
  #===============================================================================
  def update
    super
    @type = :Clear if !@type
	  return update_21 if pbVersion21?
    @release.update
    do_colours
    dispose if @startRelease && !releasing?
  end
  
  def update_21
    do_colours
    # Apply tone after any bitmap changes
    if @should_be_grey
      self.tone = Tone.new(0, 0, 0, 255)
    else
      self.tone = Tone.new(0, 0, 0, 0)
    end
    if releasing?
      self.zoom_x = lerp(1.0, 0.0, 1.5, @release_timer_start, System.uptime)
      self.zoom_y = self.zoom_x
      self.opacity = lerp(255, 0, 1.5, @release_timer_start, System.uptime)
      if self.opacity == 0
        @release_timer_start = nil
        dispose
      end
    end
    
  end
  
  def do_colours
    case @type
    when :Clear
      self.color = Color.new(0, 0, 0, 0)
    when :Green
      self.color = Color.new(0, 128, 0, 192)
    when :Grey
      self.color = Color.new(128, 128, 128, 255)
    end
  end
end

#===============================================================================
# PokemonBoxArrow Override
#===============================================================================
class PokemonBoxArrow < Sprite
  attr_accessor :multi
  
  #===============================================================================
  # initialize Add On
  #===============================================================================
  alias swdfm_init initialize
  def initialize(viewport = nil)
    swdfm_init(viewport)
	  @path  = STORAGE_ARROW_PATH
	if @path == ""
      @path  = "Graphics/Pictures/Storage/"
      @path  = "Graphics/UI/Storage/" if pbVersion21?
	end
    @multi = false
    @handsprite.addBitmap("point1g", @path + "cursor_point_1_g")
    @handsprite.addBitmap("point2g", @path + "cursor_point_2_g")
    @handsprite.addBitmap("grabg", @path + "cursor_grab_g")
    @handsprite.addBitmap("fistg", @path + "cursor_fist_g")
  end
  
  #===============================================================================
  # update Override (v20)
  #===============================================================================
  def update
    @updating = true
    super
	return update_21 if pbVersion21?
    heldpkmn = heldPokemon
    heldpkmn&.update
    @handsprite.update
    @holding = false if !heldpkmn
    t = @tension
    b = @multi ? "g" : (@quickswap ? "q" : "")
    if @grabbingState > 0
      if @grabbingState <= 4 * Graphics.frame_rate / 20
        @handsprite.change_bitmap("grab" + b)
        self.y = @spriteY + (4.0 * @grabbingState * 20 / Graphics.frame_rate)
        @grabbingState += 1
      elsif @grabbingState <= 8 * Graphics.frame_rate / 20
        @holding = true
        @handsprite.change_bitmap("fist" + b)
        self.y = @spriteY + (4 * ((8 * Graphics.frame_rate / 20) - @grabbingState) * 20 / Graphics.frame_rate)
        @grabbingState += 1
      else
        @grabbingState = 0
      end
    elsif @placingState > 0
      if @placingState <= 4 * Graphics.frame_rate / 20
        @handsprite.change_bitmap("fist" + b)
        self.y = @spriteY + (4.0 * @placingState * 20 / Graphics.frame_rate)
		    @placingState += 1
      elsif @placingState <= 8 * Graphics.frame_rate / 20
        @holding = false
        @heldpkmn = nil
        @handsprite.change_bitmap("grab" + b)
        self.y = @spriteY + (4 * ((8 * Graphics.frame_rate / 20) - @placingState) * 20 / Graphics.frame_rate)
		    @placingState += 1
      else
        @placingState = 0
      end
    elsif holding?
      @handsprite.change_bitmap("fist" + b)
    elsif t == :Selecting
      @handsprite.change_bitmap("grab" + b)
    elsif t == :Moving
      @handsprite.change_bitmap("fist" + b)
    else   # Idling
      self.x = @spriteX
      self.y = @spriteY
      if @frame < Graphics.frame_rate / 2
        @handsprite.change_bitmap("point1" + b)
      else
        @handsprite.change_bitmap("point2" + b)
      end
    end
    @frame += 1
    @frame = 0 if @frame >= Graphics.frame_rate
    @updating = false
  end
  
  #===============================================================================
  # update Override (v21)
  #===============================================================================
  def update_21
    heldpkmn = heldPokemon
    heldpkmn&.update
    @handsprite.update
    @holding = false if !heldpkmn
    t = @tension
    b = @multi ? "g" : (@quickswap ? "q" : "")
    if @grabbing_timer_start
      if System.uptime - @grabbing_timer_start <= GRAB_TIME / 2
        @handsprite.change_bitmap("grab" + b)
        self.y = @spriteY + lerp(0, 16, GRAB_TIME / 2, @grabbing_timer_start, System.uptime)
      else
        @holding = true
        @handsprite.change_bitmap("fist" + b)
        delta_y = lerp(16, 0, GRAB_TIME / 2, @grabbing_timer_start + (GRAB_TIME / 2), System.uptime)
        self.y = @spriteY + delta_y
        @grabbing_timer_start = nil if delta_y == 0
      end
    elsif @placing_timer_start
      if System.uptime - @placing_timer_start <= GRAB_TIME / 2
        @handsprite.change_bitmap("fist" + b)
        self.y = @spriteY + lerp(0, 16, GRAB_TIME / 2, @placing_timer_start, System.uptime)
      else
        @holding = false
        @heldpkmn = nil
        @handsprite.change_bitmap("grab" + b)
        delta_y = lerp(16, 0, GRAB_TIME / 2, @placing_timer_start + (GRAB_TIME / 2), System.uptime)
        self.y = @spriteY + delta_y
        @placing_timer_start = nil if delta_y == 0
      end
    elsif holding?
      @handsprite.change_bitmap("fist" + b)
    elsif t == :Selecting
      @handsprite.change_bitmap("grab" + b)
    elsif t == :Moving
      @handsprite.change_bitmap("fist" + b)
    else   # Idling
      self.x = @spriteX
      self.y = @spriteY
      if (System.uptime / 0.5).to_i.even?   # Changes every 0.5 seconds
        @handsprite.change_bitmap("point1" + b)
      else
        @handsprite.change_bitmap("point2" + b)
      end
    end
    @updating = false
  end
  
  #===============================================================================
  # Additional methods: Tension
  # Used For Multiple Grabbing
  #===============================================================================
  def set_tension
    @tension = :Selecting # 1
  end
  
  def start_tension
    @tension = :Moving # 2
  end
  
  def release_tension
    @tension = :None # 0
  end
end

#===============================================================================
# PokemonStorageScene Override
#===============================================================================
class PokemonStorageScene
  attr_reader :multi
  
  #===============================================================================
  # pbStartBox Addition
  #===============================================================================
  alias swdfm_start_box pbStartBox
  def pbStartBox(*args)
    @grabber = StorageGrabber.new
    swdfm_start_box(*args)
  end
  
  #===============================================================================
  # pbSetArrow Addition
  #===============================================================================
  alias swdfm_set_arrow pbSetArrow
  def pbSetArrow(arrow, selection)
    swdfm_set_arrow(arrow, selection)
    return unless selection >= 0
    t = @multi && @grabber.holding_anything? && !@grabber.carrying
    return unless t
    @grabber.do_with(selection)
    do_green
  end
  
  #===============================================================================
  # pbChangeSelection Addition
  #===============================================================================
  alias swdfm_change_sel pbChangeSelection
  def pbChangeSelection(key, selection)
    skip = @multi && @grabber.holding_anything? && !@grabber.carrying
    case key
    when Input::UP
      case selection
      when -1   # Box name
        selection = -2
      when -2   # Party
        selection = PokemonBox::BOX_SIZE - 1 - (PokemonBox::BOX_WIDTH * 2 / 3)   # 25
      when -3   # Close Box
        selection = PokemonBox::BOX_SIZE - (PokemonBox::BOX_WIDTH / 3)   # 28
      else
        selection -= PokemonBox::BOX_WIDTH
        if skip && selection < 0
              selection += PokemonBox::BOX_SIZE
        elsif selection < 0
              selection = -1
        end
      end
    when Input::DOWN
      case selection
      when -1   # Box name
        selection = PokemonBox::BOX_WIDTH / 3   # 2
      when -2   # Party
        selection = -1
      when -3   # Close Box
        selection = -1
      else
        selection += PokemonBox::BOX_WIDTH
        if skip && selection >= PokemonBox::BOX_SIZE
          selection -= PokemonBox::BOX_SIZE
        elsif selection >= PokemonBox::BOX_SIZE
          if selection < PokemonBox::BOX_SIZE + (PokemonBox::BOX_WIDTH / 2)
            selection = -2   # Party
          else
            selection = -3   # Close Box
          end
        end
      end
    when Input::LEFT, Input::RIGHT
      selection = swdfm_change_sel(key, selection)
    end
    return selection
  end
  
  #===============================================================================
  # pbSelectBoxInternal Override
  #===============================================================================
  def pbSelectBoxInternal(_party)
    selection = @selection
    pbSetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection)
    pbSetMosaic(selection)
    loop do
      Graphics.update
      Input.update
      key = -1
      key = Input::DOWN if Input.repeat?(Input::DOWN)
      key = Input::RIGHT if Input.repeat?(Input::RIGHT)
      key = Input::LEFT if Input.repeat?(Input::LEFT)
      key = Input::UP if Input.repeat?(Input::UP)
      if key >= 0
        pbPlayCursorSE
        selection = pbChangeSelection(key, selection)
        pbSetArrow(@sprites["arrow"], selection)
        case selection
        when -4
          nextbox = (@storage.currentBox + @storage.maxBoxes - 1) % @storage.maxBoxes
          pbSwitchBoxToLeft(nextbox)
          @storage.currentBox = nextbox
        when -5
          nextbox = (@storage.currentBox + 1) % @storage.maxBoxes
          pbSwitchBoxToRight(nextbox)
          @storage.currentBox = nextbox
        end
        selection = -1 if [-4, -5].include?(selection)
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      end
      self.update
      t = @grabber.holding_anything? && !@grabber.carrying
      if Input.trigger?(Input::JUMPUP) && !t
        pbPlayCursorSE
        nextbox = (@storage.currentBox + @storage.maxBoxes - 1) % @storage.maxBoxes
        pbSwitchBoxToLeft(nextbox)
        @storage.currentBox = nextbox
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      elsif Input.trigger?(Input::JUMPDOWN) && !t
        pbPlayCursorSE
        nextbox = (@storage.currentBox + 1) % @storage.maxBoxes
        pbSwitchBoxToRight(nextbox)
        @storage.currentBox = nextbox
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      elsif Input.trigger?(Input::SPECIAL) && !t   # Jump to box name
        if selection != -1
          pbPlayCursorSE
          selection = -1
          pbSetArrow(@sprites["arrow"], selection)
          pbUpdateOverlay(selection)
          pbSetMosaic(selection)
        end
      elsif Input.trigger?(Input::AUX2)
        pbSearch
      elsif Input.trigger?(Input::ACTION) && @command == 0   # Organize only
        if !t && !@grabber.carrying
          pbPlayDecisionSE
          pbSetQuickSwap(!@quickswap)
        elsif @grabber.carrying && CAN_MASS_RELEASE && @multi
          pbMassRelease
        end
      elsif Input.trigger?(Input::BACK)
        @selection = selection
        return nil
      elsif Input.trigger?(Input::USE)
        @selection = selection
        if selection >= 0
          return [@storage.currentBox, selection]
        elsif selection == -1   # Box name
          return [-4, -1]
        elsif selection == -2   # Party Pokémon
          return [-2, -1] if !@multi
        elsif selection == -3   # Close Box
          return [-3, -1]
        end
      end
    end
  end
  
  #===============================================================================
  # pbSelectPartyInternal Override
  #===============================================================================
  def pbSelectPartyInternal(party, depositing)
    selection = @selection
    pbPartySetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection, party)
    pbSetMosaic(selection)
    lastsel = 1
    loop do
      Graphics.update
      Input.update
      key = -1
      key = Input::DOWN if Input.repeat?(Input::DOWN)
      key = Input::RIGHT if Input.repeat?(Input::RIGHT)
      key = Input::LEFT if Input.repeat?(Input::LEFT)
      key = Input::UP if Input.repeat?(Input::UP)
      if key >= 0
        pbPlayCursorSE
        newselection = pbPartyChangeSelection(key, selection)
        case newselection
        when -1
          return -1 if !depositing
        when -2
          selection = lastsel
        else
          selection = newselection
        end
        pbPartySetArrow(@sprites["arrow"], selection)
        lastsel = selection if selection > 0
        pbUpdateOverlay(selection, party)
        pbSetMosaic(selection)
      end
      self.update
      if Input.trigger?(Input::ACTION) && @command == 0   # Organize only
        pbPlayDecisionSE
        pbSetQuickSwap(!@quickswap, true)
      elsif Input.trigger?(Input::BACK)
        @selection = selection
        return -1
      elsif Input.trigger?(Input::USE)
        if selection >= 0 && selection < Settings::MAX_PARTY_SIZE
          @selection = selection
          return selection
        elsif selection == Settings::MAX_PARTY_SIZE   # Close Box
          @selection = selection
          return (depositing) ? -3 : -1
        end
      end
    end
  end
  
  #===============================================================================
  # New Method To Swap Boxes
  #===============================================================================
  def pbSwapBoxes(newbox)
    return if @storage.currentBox == newbox
	  @storage.swap(newbox, @storage.currentBox)
	  @sprites["box"].update
	  refresh_box_sprites
  end
  
  #===============================================================================
  # pbSetQuickSwap Override
  #===============================================================================
  def pbSetQuickSwap(value, ignore_multi = false)
    ignore_multi = true if !CAN_MULTI_SELECT
    # Set to Quickswap
    if !@quickswap && !@multi
      @quickswap = true
      @multi     = false
    elsif @quickswap && !@multi && !ignore_multi
      @quickswap = false
      @multi     = true
    # Set to white
    else
      @quickswap = false
      @multi     = false
    end
    @sprites["arrow"].quickswap = @quickswap
    @sprites["arrow"].multi = @multi
  end
  
  #===============================================================================
  # pbChooseBox
  #===============================================================================
  def pbChooseBox(msg, swapping = false)
    commands = []
    @storage.maxBoxes.times do |i|
      box = @storage[i]
      if box
        if swapping  && i == @storage.currentBox
          commands.push("Do not swap")
          next
        end
		    commands.push(_INTL("{1} ({2}/{3})", box.name, box.nitems, box.length))
      end
    end
    return pbShowCommands(msg, commands, @storage.currentBox)
  end
  
  #===============================================================================
  # Additional methods
  #===============================================================================  
  # Tension: Used For Multiple Grabbing
  #===============================================================================
  def grabber
    return @grabber
  end
  
  def set_tension
    @sprites["arrow"].set_tension
  end
  
  def start_tension
    @sprites["arrow"].start_tension
  end
  
  def release_tension
    @sprites["arrow"].release_tension
  end
  
  #===============================================================================
  # Sets all necessary sprites to green
  #===============================================================================
  def do_green
    piv   = @grabber.mock_pivot
    piv_x = piv % PokemonBox::BOX_WIDTH
    piv_y = (piv / PokemonBox::BOX_WIDTH).floor
    sels = []
    for i in @grabber.mons
      x = i[0] + piv_x
      y = i[1] + piv_y
      sel = x + PokemonBox::BOX_WIDTH * y
      sels.push(sel)
    end
    for i in 0...PokemonBox::BOX_SIZE
      boxpokesprite = @sprites["box"].getPokemon(i)
      if sels.include?(i)
        boxpokesprite&.make_green
      else
        pokemon = boxpokesprite&.getPokemon
        if pokemon && !pokemon.fainted?
          boxpokesprite&.make_clear
        end
      end
    end
  end
  
  #===============================================================================
  # Method to refresh all box sprites
  #===============================================================================
  def refresh_box_sprites
    @sprites["box"].refreshSprites = true
    @sprites["box"].refreshBox = true
    pbHardRefresh
  end
  
  #===============================================================================
  # Changes from wherever the anchor is to the top left of the selection
  #===============================================================================
  def quick_change(selection)
    pbSetArrow(@sprites["arrow"], selection)
    pbUpdateOverlay(selection)
    pbSetMosaic(selection)
    @selection = selection
  end
  
  #===============================================================================
  # Shortcut to mass release
  #===============================================================================
  def pbMassRelease
    @screen.pbMassRelease
  end
  
  #===============================================================================
  # Greys all necessary sprites
  #===============================================================================
  def do_greys(ableProc = nil)
    return if !ableProc
    for i in 0...(PokemonBox::BOX_SIZE + PokemonBox::BOX_WIDTH)
      if i < PokemonBox::BOX_SIZE
        boxpokesprite = @sprites["box"].getPokemon(i)
      else
        boxpokesprite = @sprites["boxparty"].getPokemon(i-30)
      end
      next if !boxpokesprite
      next if !boxpokesprite.getPokemon
      if ableProc.call(boxpokesprite.getPokemon)
        boxpokesprite.make_clear
      else
        boxpokesprite.make_grey
      end
    end
  end
end

#===============================================================================
# PokemonStorageScreen Override
#===============================================================================
class PokemonStorageScreen
  def pbStartScreen(command)
    $game_temp.in_storage = true
    @heldpkmn = nil
    case command
    when 0   # Organise
      @scene.pbStartBox(self, command)
      loop do
        selected = @scene.pbSelectBox(@storage.party)
        if selected.nil?
          if pbHeldPokemon
            pbDisplay(_INTL("You are holding a Pokémon!"))
            next
          elsif @scene.grabber.carrying
            pbDisplay(_INTL("You are holding a Pokémon!"))
            next
          end
          next if pbConfirm(_INTL("Do you want to do more operations?"))
          break
        elsif selected[0] == -3   # Close box
          if pbHeldPokemon
            pbDisplay(_INTL("You are holding a Pokémon!"))
            next
          elsif @scene.grabber.carrying
            pbDisplay(_INTL("You are holding a Pokémon!"))
            next
          end
          if pbConfirm(_INTL("Do you want to exit the box?"))
            pbSEPlay("PC close")
            break
          end
          next
        elsif selected[0] == -4   # Box name
          if @scene.grabber.carrying && CAN_BOX_POUR
              if pbPour(selected)
                @scene.grabber.carrying = false
                @scene.grabber.clear
                @scene.release_tension
              end
          else
            pbBoxCommands
          end
        else
          pokemon = @storage[selected[0], selected[1]]
          heldpoke = pbHeldPokemon
          next if !pokemon && !heldpoke && !@scene.grabber.carrying
          if @scene.quickswap
            if @heldpkmn
              (pokemon) ? pbSwap(selected) : pbPlace(selected)
            else
              pbHold(selected)
            end
          elsif @scene.multi
            if !@scene.grabber.carrying
              if @scene.grabber.holding_anything?
                @scene.grabber.carrying = true
                # Gathers held mons data in @carried_mons in the grabber
                @scene.grabber.pack_up(@storage, selected[0])
                # Deletes mon off storage
                pbHold_Multi(selected)
                @scene.start_tension
                # Moves the hand to mock pivot position
                @scene.quick_change(@scene.grabber.mock_pivot)
                selected[1] = @scene.grabber.mock_pivot
              else
                # Start tension here
                @scene.grabber.setPivot(selected[1])
                @scene.grabber.do_with(selected[1])
                @scene.do_green
                @scene.set_tension
              end
            else
              # Drop Off If Possible
              if @scene.grabber.place_with_positions(@storage, selected[0], selected[1])
                pbPlace_Multi(selected)
                # @scene.grabber.get_new_carried_mons
                @scene.grabber.carrying = false
                @scene.grabber.clear
                @scene.release_tension
              else
                next
              end
            end
          else
            organise_commands(selected, pokemon)
          end
        end
      end
      @scene.pbCloseBox
    when 1   # Withdraw
      @scene.pbStartBox(self, command)
      loop do
        selected = @scene.pbSelectBox(@storage.party)
        if selected.nil?
          next if pbConfirm(_INTL("Do you want to do more operations?"))
          break
        else
          case selected[0]
          when -2   # Party Pokémon
            pbDisplay(_INTL("Which will you take?"))
            next
          when -3   # Close box
            if pbConfirm(_INTL("Do you want to exit the box?"))
              pbSEPlay("PC close")
              break
            end
            next
          when -4   # Box name
            pbBoxCommands
            next
          end
          pokemon = @storage[selected[0], selected[1]]
          next if !pokemon
          commands_symbols = [:WITHDRAW, :SUMMARY, :MARK, :POKEDEX, :RELEASE, :CANCEL]
          commands_text = [_INTL("Withdraw"), _INTL("Data"), _INTL("Marks")]
          commands_text.push(_INTL("Pokédex")) if $player.has_pokedex && !pokemon.egg? && $player.pokedex.species_in_unlocked_dex?(pokemon.species)
          commands_text.push(_INTL("Release"), _INTL("Cancel"))

          command_index = pbShowCommands(_INTL("{1} is selected.", pokemon.name), commands_text)
          next if command_index < 0
          command = commands_symbols[command_index]
          case command
          when :WITHDRAW then pbWithdraw(selected, nil)
          when :SUMMARY then pbSummary(selected, nil)
          when :MARK then pbMark(selected, nil)
          when :POKEDEX then openPokedexOnPokemon(pokemon.species, pokemon.gender, pokemon.form)
          when :RELEASE then pbRelease(selected, nil)
          end
        end
      end
      @scene.pbCloseBox
    when 2   # Deposit
      @scene.pbStartBox(self, command)
      loop do
        selected = @scene.pbSelectParty(@storage.party)
        if selected == -3   # Close box
          if pbConfirm(_INTL("Do you want to exit the box?"))
            pbSEPlay("PC close")
            break
          end
          next
        elsif selected < 0
          next if pbConfirm(_INTL("Do you want to do more operations?"))
          break
        else
          pokemon = @storage[-1, selected]
          next if !pokemon
          commands_symbols = [:DEPOSIT, :SUMMARY, :MARK, :POKEDEX, :RELEASE, :CANCEL]
          commands_texts = [_INTL("Deposit"),
                      _INTL("Data"),
                      _INTL("Marks")]
          commands_texts.push(_INTL("Pokédex")) if $player.has_pokedex && !pokemon.egg? && $player.pokedex.species_in_unlocked_dex?(pokemon.species)
          commands_texts.push(_INTL("Release"),
                        _INTL("Cancel"))
          command_index = pbShowCommands(_INTL("{1} is selected.", pokemon.name), commands_texts)
          next if command_index < 0
          command = commands_symbols[command_index]
          case command
          when :DEPOSIT then pbStore([-1, selected], nil)
          when :SUMMARY then pbSummary([-1, selected], nil)
          when :MARK then pbMark([-1, selected], nil)
          when :POKEDEX then openPokedexOnPokemon(pokemon.species, pokemon.gender, pokemon.form)
          when :RELEASE then pbRelease([-1, selected], nil)
          end
        end
      end
      @scene.pbCloseBox
    when 3
      @scene.pbStartBox(self, command)
      @scene.pbCloseBox
    end
    $game_temp.in_storage = false
  end
  
  #===============================================================================
  # pbBoxCommands Override
  #===============================================================================
  def pbBoxCommands
    c_consts = [:JUMP]
	  c_consts.push(:SWAP) if CAN_SWAP_BOXES
	  c_consts.push(:WALL, :NAME, :RELEASE, :SORT, :CANCEL)
    commands = [
      _INTL("Jump")
	  ] 
    commands.push(_INTL("Swap")) if CAN_SWAP_BOXES
    commands.push(
      _INTL("Background"),
      _INTL("Name"),
      _INTL("Release Box"),
      # _INTL("Sort Box"),
      _INTL("Cancel")
    )
    command = pbShowCommands(_INTL("What do you want to do?"), commands)
    case c_consts[command]
    when :JUMP
      destbox = @scene.pbChooseBox(_INTL("Jump to which Box?"))
      @scene.pbJumpToBox(destbox) if destbox >= 0
    when :SWAP
      destbox = @scene.pbChooseBox(_INTL("Swap with which Box?"), true)
      @scene.pbSwapBoxes(destbox) if destbox >= 0
    when :WALL
      papers = @storage.availableWallpapers
      index = 0
      papers[1].length.times do |i|
        if papers[1][i] == @storage[@storage.currentBox].background
          index = i
          break
        end
      end
      wpaper = pbShowCommands(_INTL("Choose the background."), papers[0], index)
      @scene.pbChangeBackground(papers[1][wpaper]) if wpaper >= 0
    when :NAME
      @scene.pbBoxName(_INTL("Box name?"), BOX_NAME_MIN_CHARS, BOX_NAME_MAX_CHARS)
    when :RELEASE
      pbReleaseBox(@storage.currentBox)
    # when :SORT
    #   pbSortBox(@storage.currentBox)
    end
  end
  
  def pbReleaseBox(box)
    released_count = 0
    stored_items = 0
    if pbConfirmMessageSerious(_INTL("Do you want to release all Pokémon from the Box?"))
      for i in 0...@storage.maxPokemon(box)
        pokemon = @storage[box, i]
        next if !pokemon || pokemon.egg? || pokemon.mail || pokemon.cannot_release
        if pokemon.hasItem? # Recovers the held item if it has one.
          stored_items += 1
          $bag.add(pokemon.item_id)
        end
        @storage.pbDelete(box, i)
        @scene.pbHardRefresh
        released_count += 1
        pbWait(0.20)
      end
      if released_count > 0
        pbDisplay(_INTL("You have released {1} Pokémon from this box!", released_count))
      else
        pbDisplay(_INTL("There are no valid Pokémon to release in this box."))
      end
      if stored_items > 0
        pbDisplay(_INTL("{1} item{2} has been stored in your bag", stored_items, stored_items > 1 ? "s" : ""))
      end
    end
    @scene.pbRefresh
  end

  #===============================================================================
  # organise_commands method - missing in core Essentials
  #===============================================================================
  def organise_commands(selected, pokemon)
    commands = []
    cmdMove     = -1
    cmdSummary  = -1
    cmdWithdraw = -1
    cmdItem     = -1
    cmdMark     = -1
    cmdRelease  = -1
    cmdDebug    = -1
    heldpoke = pbHeldPokemon
    if heldpoke
      helptext = _INTL("{1} is selected.", heldpoke.name)
      commands[cmdMove = commands.length] = (pokemon) ? _INTL("Shift") : _INTL("Place")
    elsif pokemon
      helptext = _INTL("{1} is selected.", pokemon.name)
      commands[cmdMove = commands.length] = _INTL("Move")
    end
    commands[cmdSummary = commands.length]  = _INTL("Summary")
    commands[cmdWithdraw = commands.length] = (selected[0] == -1) ? _INTL("Store") : _INTL("Withdraw")
    commands[cmdItem = commands.length]     = _INTL("Item")
    commands[cmdMark = commands.length]     = _INTL("Mark")
    commands[cmdRelease = commands.length]  = _INTL("Release")
    commands[cmdDebug = commands.length]    = _INTL("Debug") if $DEBUG
    commands[commands.length]               = _INTL("Cancel")
    command = pbShowCommands(helptext, commands)
    if cmdMove >= 0 && command == cmdMove   # Move/Shift/Place
      if @heldpkmn
        (pokemon) ? pbSwap(selected) : pbPlace(selected)
      else
        pbHold(selected)
      end
    elsif cmdSummary >= 0 && command == cmdSummary   # Summary
      pbSummary(selected, @heldpkmn)
    elsif cmdWithdraw >= 0 && command == cmdWithdraw   # Store/Withdraw
      (selected[0] == -1) ? pbStore(selected, @heldpkmn) : pbWithdraw(selected, @heldpkmn)
    elsif cmdItem >= 0 && command == cmdItem   # Item
      pbItem(selected, @heldpkmn)
    elsif cmdMark >= 0 && command == cmdMark   # Mark
      pbMark(selected, @heldpkmn)
    elsif cmdRelease >= 0 && command == cmdRelease   # Release
      pbRelease(selected, @heldpkmn)
    elsif cmdDebug >= 0 && command == cmdDebug   # Debug
      pbPokemonDebug((@heldpkmn) ? @heldpkmn : pokemon, selected, heldpoke)
    end
  end

  #===============================================================================
  # pbItem method - missing in Sky Essentials
  #===============================================================================
  def pbItem(selected, heldpoke)
    box = selected[0]
    index = selected[1]
    pokemon = (heldpoke) ? heldpoke : @storage[box, index]
    if pokemon.egg?
      pbDisplay(_INTL("Eggs can't hold items."))
      return
    elsif pokemon.mail
      pbDisplay(_INTL("Please remove the mail."))
      return
    end
    if pokemon.item
      itemname = pokemon.item.portion_name
      if pbConfirm(_INTL("Take the {1}?", itemname))
        if $bag.add(pokemon.item)
          pbDisplay(_INTL("Took the {1}.", itemname))
          pokemon.item = nil
          @scene.pbHardRefresh
        else
          pbDisplay(_INTL("Can't store the {1}.", itemname))
        end
      end
    else
      item = @scene.pbChooseItem($bag)
      if item
        itemname = GameData::Item.get(item).name
        pokemon.item = item
        $bag.remove(item)
        pbDisplay(_INTL("{1} is now being held.", itemname))
        @scene.pbHardRefresh
      end
    end
  end

  #===============================================================================
  # pbPokemonDebug method - missing in Sky Essentials (debug purposes)
  #===============================================================================
  def pbPokemonDebug(pkmn, pkmnid, heldpoke = nil, settingUpBattle = false)
    # This is a debug method that should be implemented in the core Essentials scripts
    # For now, we'll just display a message that this feature is not available
    pbDisplay(_INTL("Debug feature not available."))
  end

  #===============================================================================
  # ***Additional methods***
  #===============================================================================
  def pbHold_Multi(selected)
    box, index = selected
    if box == -1 && pbAble?(@storage[box, index]) && pbAbleCount <= 1
      pbPlayBuzzerSE
      pbDisplay(_INTL("It's your last Pokémon!"))
      return
    end
    for i in @scene.grabber.get_carried_mons
      @storage.pbDelete(box, i)
    end
    index = @scene.grabber.get_carried_mons[0]
    @heldpkmn = @storage[box, index]
    @scene.refresh_box_sprites
    @scene.pbRefresh
  end
  
  def pbPlace_Multi(selected)
    box, index = selected
    for i in @scene.grabber.get_new_carried_mons(index)
      this_index = i[0]
      if @storage[box, this_index]
        raise _INTL("Position {1}, {2} is not empty...", box, this_index)
      end
      if box != -1 && this_index >= @storage.maxPokemon(box)
        pbDisplay("Cannot place there.")
        return
      end
      this_pkmn = i[1]
      if box >= 0 && this_pkmn
        this_pkmn.formTime = nil if this_pkmn.respond_to?("formTime")
        this_pkmn.form     = 0 if this_pkmn.isSpecies?(:SHAYMIN)
        this_pkmn.heal if Settings::HEAL_STORED_POKEMON
      end
      @storage[box,this_index] = this_pkmn
      if box==-1
        @storage.party.compact!
      end
    end
    @scene.refresh_box_sprites
    @scene.pbRefresh
    @heldpkmn = nil
  end
  
  #===============================================================================
  # Puts all held Pokemon into available slots in a box
  #===============================================================================
  def pbPour(selected)
    # box = @storage.currentBox
    mons_to_place = @scene.grabber.carried_mons.clone
    needed_space = mons_to_place && mons_to_place.size > 0 ? mons_to_place.size : 1
    box = @scene.pbChooseBoxWithSpace("Place in which box?", needed_space)
    return false if box < 0
    count = 0
    placed = false
    if !mons_to_place.empty?
      for i in 0...PokemonBox::BOX_SIZE
        next if @storage[box, i]
        m_t_p = mons_to_place.pop
        next unless m_t_p && !m_t_p.empty?
        @storage[box, i] = m_t_p[0]
        count += 1
        break if mons_to_place.empty?
      end
    elsif @heldpkmn
      for i in 0...PokemonBox::BOX_SIZE
        next if @storage[box, i]
        @storage[box, i] = @heldpkmn
        count += 1
        placed = true
        break
      end
    end
    emptied = mons_to_place.empty? || placed
    @scene.refresh_box_sprites
    @scene.pbRefresh
    @heldpkmn = nil if emptied
    if emptied && @scene.sprites["arrow"]&.holding?
      @scene.sprites["arrow"]&.deleteSprite
      @scene.sprites["arrow"]&.update 
      @scene.grabber.carrying = false
    end
    @scene.grabber.pour(count)
	  return emptied
  end
  
  #===============================================================================
  # Releases all held Pokemon
  #===============================================================================
  def pbMassRelease
    if @scene.grabber.contains_an_egg?
      pbDisplay(_INTL("You cannot release an Egg!"))
      return false
    end
    # NOTE: No need to stop if last mon because this cannot be done in party!
    pbDisplay(_INTL("WARNING! You have chosen to release all selected Pokémon."))
    command = pbShowCommands(_INTL("Do you want to release these Pokémon?"), [_INTL("No"), _INTL("Yes")])
    return unless command == 1
    command = pbShowCommands(_INTL("Are you sure?"), [_INTL("No"), _INTL("Yes")])
    return unless command == 1
    @scene.grabber.clear
    @scene.pbRefresh
    pbDisplay(_INTL("The Pokémon have been released."))
    pbDisplay(_INTL("Be free, Pokémon!"))
    @scene.pbRefresh
    @scene.grabber.carrying = false
    @scene.release_tension
  end
end
