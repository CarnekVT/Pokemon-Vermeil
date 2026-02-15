#===============================================================================
# ** Game_System
#------------------------------------------------------------------------------
#  This class handles data surrounding the system. Backround music, etc.
#  is managed here as well. Refer to "$game_system" for the instance of
#  this class.
#===============================================================================
class Game_System
  def initialize
    @map_interpreter        = Interpreter.new(0, true)
    @battle_interpreter     = Interpreter.new(0, false)
    @timer_start            = nil
    @timer_duration         = 0
    @save_disabled          = false
    @menu_disabled          = false
    @encounter_disabled     = false
    @message_position       = 2
    @message_frame          = 0
    @save_count             = 0
    @magic_number           = 0
    @adventure_magic_number = rand(2**32)
    @autoscroll_x_speed     = 0
    @autoscroll_y_speed     = 0
    @bgm_position           = 0
    @bgs_position           = 0
  end

  def adventure_magic_number
    @adventure_magic_number ||= rand(2**32)
    return @adventure_magic_number
  end
end
