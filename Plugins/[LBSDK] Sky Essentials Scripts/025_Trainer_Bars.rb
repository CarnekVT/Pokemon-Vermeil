if Settings::SHOW_TRAINER_BARS # << Make true to use this script, false to disable.
#===============================================================================
#
#  Trainer Sensor Script
#  Author     : Drimer
#  Editor     : Skyflyer
#
#===============================================================================

#===============================================================================
#                             **  Settings here! **
#
# RANGE sets the... range of detection! If it is set to 0 it will take the
# value x from 'Trainer(x)' (Event's name!)
#
# BAR_OPACITY is used to set the transparency to the focus bars.
#
# SELF_SWITCH is used to identify those trainers you already fought against of.
#
# BAR_HEIGHT sets the the focus bars' height value.
#
# BAR_GRAPHIC allows you to load your own graphic from 'Graphics/Pictures/'
# if it is set to "" or nil, the system will create them for you. If not, then
# the BAR_HEIGHT will be ignored as well as the BAR_OPACITY constant.
#===============================================================================
TRAINER_BARS_RANGE = 4

module TrainerSensor  
  BAR_OPACITY = 255/8
  SELF_SWITCH = "A"
  BAR_HEIGHT  = Graphics.height/6
  BAR_GRAPHIC = ""
  # If you use EBS, a good option is set this value to "EBS/newBattleMessageBox"
end
  

#===============================================================================
# **  
#===============================================================================
module TrainerSensor
  @top = Sprite.new
  @top.z = 1
  @bottom = Sprite.new
  @bottom.z = 1
  @triggered = false
  @created = false
  closestTrainer = nil
  #@lastClosest = nil
  
  
  def self.create(distance)
    
    if !@created
      # Create top bar
      @top.bitmap = Bitmap.new(Graphics.width, BAR_HEIGHT)
      @top.bitmap.fill_rect(0,0,@top.bitmap.width,@top.bitmap.height,
        Color.new(-255,-255,-255, BAR_OPACITY*(6-distance)))
      @top.oy = 0 # Position where it should end.      
      @top.y -= BAR_HEIGHT
      @top.x=0 if $PokemonSystem

      # Create bottom bar
      @bottom.bitmap = Bitmap.new(Graphics.width, BAR_HEIGHT)
      @bottom.bitmap.fill_rect(0,0,@bottom.bitmap.width,@bottom.bitmap.height,
        Color.new(-255,-255,-255, BAR_OPACITY*(6-distance)))
      @bottom.oy = BAR_HEIGHT-Graphics.height  # Position where it should end.
      @bottom.y += BAR_HEIGHT
      @bottom.x=0 if $PokemonSystem

      @created = true
      
    else # Modify opacity
      # Fill top bar
      @top.bitmap.fill_rect(0,0,@top.bitmap.width,@top.bitmap.height,
        Color.new(-255,-255,-255, BAR_OPACITY*(6-distance)))
      
      # Fill bottom bar
      @bottom.bitmap.fill_rect(0,0,@bottom.bitmap.width,@bottom.bitmap.height,
        Color.new(-255,-255,-255, BAR_OPACITY*(6-distance)))
    end
  end
  
  
  
  def self.triggered?
    @triggered
  end
  
  def self.show(distance)
    self.create(distance) #if !@created
    @triggered = true
  end
  
  def self.hide
    @triggered = false
  end
  
  
  
  # Make them appear or disappear progressively
  def self.update
    return if !@created
    if @triggered # Appear sliding
      if @top.y <= (- 6)
        @top.y += 6
        @bottom.y -= 6
      end
    else  # Disappear sliding
      if @top.y >= (-BAR_HEIGHT)
        @top.y -= 6
        @bottom.y += 6
      end    
      if @top.y <= (-BAR_HEIGHT)
        @created = false
      end
    end
  end
  
end


def update_trainer_bars
  closestTrainer = TRAINER_BARS_RANGE+1
  
  for event in $game_map.events.values
    if event.name[/^Trainer\((\d+)\)$/] && event.isOff?(TrainerSensor::SELF_SWITCH)

      # Get the distance the trainer is looking at.
      trainer_range = event.name[8...9].to_i
      
      # Depending on where the trainer is looking, calculate the squares they are looking at.
      if event.direction == 8 # Up
        for i in 0..trainer_range+1
          distance = (($game_player.x-event.x).abs) + (($game_player.y-(event.y-i)).abs)
          if (closestTrainer>distance)
            closestTrainer = distance
          end
        end
      elsif event.direction == 2 # Down
        for i in 0..trainer_range+1
          distance = (($game_player.x-event.x).abs) + (($game_player.y-(event.y+i)).abs)
          if (closestTrainer>distance)
            closestTrainer = distance
          end
        end
      elsif event.direction == 6 # Right
        for i in 0..trainer_range+1
          distance = (($game_player.x-(event.x+i)).abs) + (($game_player.y-event.y).abs)
          if (closestTrainer>distance)
            closestTrainer = distance
          end
        end
      elsif event.direction == 4 # Left
        for i in 0..trainer_range+1
          distance = (($game_player.x-(event.x-i)).abs) + (($game_player.y-event.y).abs)
          if (closestTrainer>distance)
            closestTrainer = distance
          end
        end
      end
    end
  end

  # Update the bars based on how far the trainers are.
    if closestTrainer == TRAINER_BARS_RANGE+1
      TrainerSensor.hide() if TrainerSensor.triggered?
    else 
      TrainerSensor.show(closestTrainer)
    end
end


module Graphics
  class << self
    alias trainer_detection_update update
    def update
      trainer_detection_update
      TrainerSensor.update if $scene && $scene.is_a?(Scene_Map)
    end
  end
end


class Scene_Map
  alias update_bars update
  def update
    update_bars
    update_trainer_bars
  end
end



# Change it to Events.onStepTaken if you want this to scan the events on each step
# the player takes. Before: Events.onMapUpdate  
EventHandlers.add(:on_step_taken, :trainer_bars, proc{|sender,e|
  update_trainer_bars
})


end # if principal
