################################################################################
# Simple Exit Arrows - by Tustin2121
# Edited by Skyflyer
#
# To use, set the graphic of your exit warp event to an arrow with
# the desired hue and name it "ExitArrow" (without the quotes).
#
# The below code will do the work of hiding and showing the arrow when needed.
################################################################################

class Game_Player < Game_Character
 # Run when the player turns.
 # The default version of this method is empty, so replacing it outright
 # like this is fine. You may want to double check, just in case, however.
 def check_event_trigger_after_turning
   pxCheckExitArrows
 end
end

class Game_Character
 # Add accessors for some otherwise hidden options
 attr_accessor :step_anime
 attr_accessor :direction_fix
end

module ExitArrows
 # La cache se invalida por identidad de $game_map, no por map_id, y es a
 # proposito: Game_MapFactory descarta mapas de @maps (delete_if en
 # 011_Game classes/006_Game_MapFactory.rb:365, 370 y 374), asi que un mapa
 # revisitado puede volver como un Game_Map nuevo con el mismo map_id y eventos
 # distintos. Comparar map_id no lo detectaria y @events se quedaria apuntando a
 # los eventos del objeto ya descartado.
 def self.events
   map_events = $game_map.events
   if @map != $game_map || @events_count != map_events.length
     @map = $game_map
     @events_count = map_events.length
     @events = map_events.values.select { |event| event.name == "FlechaSalida" }
   end
   return @events
 end
end

# Checks if the player is standing next to the exit arrow, facing it.
def pxCheckExitArrows(init=false)
 px = $game_player.x
 py = $game_player.y
 for event in ExitArrows.events
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
EventHandlers.add(:on_map_or_spriteset_change, :flechas_salidas, proc{|sender,e|
 pxCheckExitArrows(true)
})

# Run on every step taken
EventHandlers.add(:on_leave_tile, :flechas_salidas, proc{|sender,e|
 pxCheckExitArrows
})
