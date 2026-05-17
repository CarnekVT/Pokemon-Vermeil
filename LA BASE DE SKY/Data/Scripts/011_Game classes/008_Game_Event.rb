#===============================================================================
#
#===============================================================================
class Game_Event < Game_Character
  attr_reader   :map_id
  attr_reader   :trigger
  attr_reader   :list
  attr_reader   :starting
  attr_reader   :tempSwitches   # Temporary self-switches
  attr_accessor :need_refresh
  attr_accessor :side_stairs

  def initialize(map_id, event, map = nil)
    super(map)
    @map_id       = map_id
    @event        = event
    @id           = @event.id
    @original_x   = @event.x
    @original_y   = @event.y
    if @event.name[/size\((\d+),(\d+)\)/i]
      @width = $~[1].to_i
      @height = $~[2].to_i
    end
    @erased       = false
    @starting     = false
    @need_refresh = false
    @route_erased = false
    @through      = true
    @to_update    = true
    @tempSwitches = {}
    moveto(@event.x, @event.y) if map
    refresh
  end

  def id;   return @event.id;   end
  def name; return @event.name; end

  def set_starting
    @starting = true
  end

  def clear_starting
    @starting = false
  end

  def start
    if is_stair_event?
      data = self.get_stair_data
      
      if data[0] == :slope
        $game_player.slope(data[1], data[2], data[3], data[4], data[5])       
      elsif data[0] == :spiral
        if $game_player.y == self.y
          $game_player.set_spiral_data(data[1], data[2], :ascending)
        elsif $game_player.y == self.y - data[2]
          $game_player.set_spiral_data(data[1], data[2], :descending)
        end
      end
    else
      @starting = true if @list.size > 1
    end
  end

  def erase
    @erased = true
    refresh
  end

  def erase_route
    @route_erased = true
    refresh
  end

  def tsOn?(c)
    return @tempSwitches && @tempSwitches[c] == true
  end

  def tsOff?(c)
    return !@tempSwitches || !@tempSwitches[c]
  end

  def setTempSwitchOn(c)
    @tempSwitches[c] = true
    refresh
  end

  def setTempSwitchOff(c)
    @tempSwitches[c] = false
    refresh
  end

  def isOff?(c)
    return !$game_self_switches[[@map_id, @event.id, c]]
  end

  def switchIsOn?(id)
    switch_name = $data_system.switches[id]
    if switch_name && switch_name[/^s\:/]
      return eval($~.post_match)
    end
    return $game_switches[id]
  end

  def variableIsLessThan?(id, value)
    variable_name = $data_system.variables[id]
    if variable_name && variable_name[/^s\:/]
      return eval($~.post_match) < value
    end
    return $game_variables[id] < value
  end

  def variable
    return nil if !$PokemonGlobal.eventvars
    return $PokemonGlobal.eventvars[[@map_id, @event.id]]
  end

  def setVariable(variable)
    $PokemonGlobal.eventvars[[@map_id, @event.id]] = variable
  end

  def varAsInt
    return 0 if !$PokemonGlobal.eventvars
    return $PokemonGlobal.eventvars[[@map_id, @event.id]].to_i
  end

  def expired?(secs = 86_400)
    ontime = self.variable
    time = pbGetTimeNow
    return ontime && (time.to_i > ontime + secs)
  end

  def expiredDays?(days = 1)
    ontime = self.variable.to_i
    return false if !ontime
    now = pbGetTimeNow
    elapsed = (now.to_i - ontime) / 86_400
    elapsed += 1 if (now.to_i - ontime) % 86_400 > ((now.hour * 3600) + (now.min * 60) + now.sec)
    return elapsed >= days
  end

  def cooledDown?(seconds)
    return true if expired?(seconds) && tsOff?("A")
    self.need_refresh = true
    return false
  end

  def cooledDownDays?(days)
    return true if expiredDays?(days) && tsOff?("A")
    self.need_refresh = true
    return false
  end

  def onEvent?
    return @map_id == $game_player.map_id && at_coordinate?($game_player.x, $game_player.y)
  end

  def is_stair_event?
    return STAIR_EVENT_NAMES.include?(self.name)
  end

  def check_stair_zones(char_x, char_y)
    return nil if @side_stairs.nil? || @side_stairs[@map_id].nil?    
    @side_stairs[@map_id].each do |event|
      data = event.get_stair_data
      next unless data
      xincline, yincline, ypos_base, yheight, offset = data
      if char_x == event.x && char_y <= event.y && char_y > event.y - yheight
        ypos_current = event.y - char_y
        return[event, xincline, yincline, ypos_current, yheight, offset, :start]
      end
      end_x = event.x + xincline
      end_y = event.y + yincline      
      if char_x == end_x && char_y <= end_y && char_y > end_y - yheight
        ypos_current = end_y - char_y
        return[event, -xincline, -yincline, ypos_current, yheight, offset, :end]
      end
    end
    
    return nil
  end

  def mss_check_events
    return
  end

  def get_stair_data
    return [:none, 0, 0, 0, 0, 0] unless is_stair_event? && @list
    xincline = 0
    yincline = 0
    ypos     = 0
    yheight  = 1
    offset   = 16
    is_spiral = false
    c = 0
    h = 0

    @list.each do |cmd|
      next unless cmd.code == 108 || cmd.code == 408
      comment = cmd.parameters[0]
      next unless comment

      # --- SPIRAL ---
      if comment =~ /Spiral:\s*([+-]?)\s*c:\s*(\d+)\s*\/\s*([+-]?)\s*h:\s*(\d+)/i
        c_sign, c_val = $1, $2.to_i
        h_sign, h_val = $3, $4.to_i
        c = (c_sign == '-') ? -c_val : c_val
        h = (h_sign == '-') ? -h_val : h_val
        is_spiral = true

      # --- SLOPE AREA ---
      elsif comment =~ /SlopeArea:\s*([+-]?)\s*w:\s*(\d+)\s*\/\s*([+-]?)\s*h:\s*(\d+)(?::(\d+))?/i
        w_sign, w_val = $1, $2.to_i
        h_sign, h_val = $3, $4.to_i
        h_ext = $5
        xincline = (w_sign == '-') ? -w_val : w_val
        yincline = (h_sign == '-') ? h_val : -h_val
        yheight  = h_ext ? h_ext.to_i : 1
        
      # --- SLOPE ---
      elsif comment =~ /Slope:\s*(-?\d+)\s*x\s*(-?\d+)/i
        xincline, yincline = $1.to_i, $2.to_i
        
      # --- PARÁMETROS EXTRA ---
      elsif comment =~ /Width:\s*(\d+)\s*\/\s*(\d+)/i
        ypos, yheight = $1.to_i, $2.to_i
      elsif comment =~ /Offset:\s*(\d+)\s*px/i
        offset = $1.to_i
      end
    end
    if is_spiral
      return [:spiral, c, h, 0, 0, 0]
    else
      return [:slope, xincline, yincline, ypos, yheight, offset]
    end
  end

  def over_trigger?
    return false if @map_id != $game_player.map_id
    return false if @character_name != "" && !@through
    return false if @event.name[/objetooculto/i] || @event.name[/hiddenitem/i]
    each_occupied_tile do |i, j|
      return true if self.map.passable?(i, j, 0, $game_player)
    end
    return false
  end

  def check_event_trigger_touch(dir)
    return if on_stair? || on_spiral?
    return if @map_id != $game_player.map_id
    return if @trigger != 2   # Event touch
    return if $game_system.map_interpreter.running?
    case dir
    when 2
      return if $game_player.y != @y + 1
    when 4
      return if $game_player.x != @x - 1
    when 6
      return if $game_player.x != @x + @width
    when 8
      return if $game_player.y != @y - @height
    end
    return if !in_line_with_coordinate?($game_player.x, $game_player.y)
    return if jumping? || over_trigger?
    start
  end

  def check_event_trigger_after_turning
    return if @map_id != $game_player.map_id
    return if @trigger != 2   # Not Event Touch
    return if $game_system.map_interpreter.running? || @starting
    return if !self.name[/(?:sight|trainer)\((\d+)\)/i]
    distance = $~[1].to_i
    return if !pbEventCanReachPlayer?(self, $game_player, distance)
    return if jumping? || over_trigger?
    start
  end

  def check_event_trigger_after_moving
    return if @map_id != $game_player.map_id
    return if @trigger != 2   # Not Event Touch
    return if $game_system.map_interpreter.running? || @starting
    if self.name[/(?:sight|trainer)\((\d+)\)/i]
      distance = $~[1].to_i
      return if !pbEventCanReachPlayer?(self, $game_player, distance)
    elsif self.name[/counter\((\d+)\)/i]
      distance = $~[1].to_i
      return if !pbEventFacesPlayer?(self, $game_player, distance)
    else
      return
    end
    return if jumping? || over_trigger?
    start
  end

  def check_event_trigger_auto
    return if on_stair? || on_spiral? || ($game_player && ($game_player.on_stair? || $game_player.on_spiral?))
    case @trigger
    when 2   # Event touch
      if at_coordinate?($game_player.x, $game_player.y) && !jumping? && over_trigger?
        start
      end
    when 3   # Autorun
      start
    end
  end

  def refresh
    new_page = nil
    unless @erased
      @event.pages.reverse.each do |page|
        c = page.condition
        next if c.switch1_valid && !switchIsOn?(c.switch1_id)
        next if c.switch2_valid && !switchIsOn?(c.switch2_id)
        next if c.variable_valid && variableIsLessThan?(c.variable_id, c.variable_value)
        if c.self_switch_valid
          key = [@map_id, @event.id, c.self_switch_ch]
          next if $game_self_switches[key] != true
        end
        new_page = page
        break
      end
    end
    return if new_page == @page
    @page = new_page
    clear_starting
    if @page.nil?
      @tile_id            = 0
      @character_name     = ""
      @character_hue      = 0
      @move_type          = 0
      @through            = true
      @trigger            = nil
      @list               = nil
      @interpreter        = nil
      @move_route         = nil
      @move_route_index   = 0
      @move_route_forcing = false
      return
    end
    @tile_id              = @page.graphic.tile_id
    @character_name       = @page.graphic.character_name
    @character_hue        = @page.graphic.character_hue
    if @original_direction != @page.graphic.direction
      @direction          = @page.graphic.direction
      @original_direction = @direction
      @prelock_direction  = 0
    end
    if @original_pattern != @page.graphic.pattern
      @pattern            = @page.graphic.pattern
      @original_pattern   = @pattern
    end
    @opacity              = @page.graphic.opacity
    @blend_type           = @page.graphic.blend_type
    @move_type            = @page.move_type
    self.move_speed       = @page.move_speed
    self.move_frequency   = @page.move_frequency
    @move_route           = (@route_erased) ? RPG::MoveRoute.new : @page.move_route
    @move_route_index     = 0
    @move_route_forcing   = false
    @walk_anime           = @page.walk_anime
    @step_anime           = @page.step_anime
    @direction_fix        = @page.direction_fix
    @through              = @page.through
    @always_on_top        = @page.always_on_top
    calculate_bush_depth
    @trigger              = @page.trigger
    @list                 = @page.list
    @interpreter          = nil
    @interpreter          = Interpreter.new if @trigger == 4   # Parallel Process
    check_event_trigger_auto
  end

  def should_update?(recalc = false)
    return @to_update if !recalc
    return true if @updated_last_frame
    return true if @trigger && (@trigger == 3 || @trigger == 4)
    return true if @move_route_forcing || @moveto_happened
    return true if @event.name[/update/i]
    range = 2   # Number of tiles
    return false if self.screen_x - (@sprite_size[0] / 2) > Graphics.width + (range * Game_Map::TILE_WIDTH)
    return false if self.screen_x + (@sprite_size[0] / 2) < -range * Game_Map::TILE_WIDTH
    return false if self.screen_y_ground - @sprite_size[1] > Graphics.height + (range * Game_Map::TILE_HEIGHT)
    return false if self.screen_y_ground < -range * Game_Map::TILE_HEIGHT
    return true
  end

  def update
    @to_update = should_update?(true)
    @updated_last_frame = false
    return if !@to_update
    @updated_last_frame = true
    @moveto_happened = false
    last_moving = moving?
    super
    check_event_trigger_after_moving if !moving? && last_moving
    if @need_refresh
      @need_refresh = false
      refresh
    end
    check_event_trigger_auto
    if @interpreter
      @interpreter.setup(@list, @event.id, @map_id) if !@interpreter.running?
      @interpreter.update
    end
  end

  def update_move
    was_jumping = jumping?
    super
    if was_jumping && !jumping? && !@transparent && (@tile_id > 0 || @character_name != "")
      spriteset = $scene.spriteset(map_id)
      spriteset&.addUserAnimation(Settings::DUST_ANIMATION_ID, self.x, self.y, true, 1)
    end
  end
end
