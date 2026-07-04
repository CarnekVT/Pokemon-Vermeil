#===============================================================================
# VIBRANT COMPANIONS - VEHICLES & TRANSFERS
#===============================================================================

#-------------------------------------------------------------------------------
# Desbloqueo de Acciones
#-------------------------------------------------------------------------------
class Game_Player
  alias vibrant_can_ride_vehicle_with_follower? can_ride_vehicle_with_follower? unless method_defined?(:vibrant_can_ride_vehicle_with_follower?)
  def can_ride_vehicle_with_follower?
    followers = $PokemonGlobal.followers
    if followers.length > 0 && followers.all? { |f| f.name && f.name.start_with?("VibrantFollower_") }
      return true
    end
    return vibrant_can_ride_vehicle_with_follower?
  end

  alias vibrant_can_map_transfer_with_follower? can_map_transfer_with_follower? unless method_defined?(:vibrant_can_map_transfer_with_follower?)
  def can_map_transfer_with_follower?
    followers = $PokemonGlobal.followers
    if followers.length > 0 && followers.all? { |f| f.name && f.name.start_with?("VibrantFollower_") }
      return true
    end
    return vibrant_can_map_transfer_with_follower?
  end
end

#-------------------------------------------------------------------------------
# Monitor de Vehículos y Transiciones de Surf
#-------------------------------------------------------------------------------
module VibrantCompanions
  module VehicleMonitor
    @@last_vehicle_state = false
    @@waiting_for_land_step = false

    def self.waiting_for_land_step?
      return @@waiting_for_land_step
    end

    def self.set_waiting_for_land_step(value)
      @@waiting_for_land_step = value
    end

    def self.update
      return unless $PokemonGlobal
      
      current_state = ($PokemonGlobal.bicycle || $PokemonGlobal.surfing || $PokemonGlobal.diving)
      
      if current_state != @@last_vehicle_state
        @@last_vehicle_state = current_state
        
        if Manager.save_data.system_enabled
          # 1. Si nos SUBIMOS a la Bici o al Surf
          if current_state && Manager.toggled?
            Manager.play_mass_animation(Settings::ANIM_RECALL)
            Manager.refresh # Borrar los eventos físicos
          end
          
          # 2. Si nos BAJAMOS de la Bici
          if !current_state && Manager.toggled?
            if !$PokemonGlobal.surfing && !$PokemonGlobal.diving && !@@waiting_for_land_step
              Manager.refresh
              Manager.play_mass_animation(Settings::ANIM_APPEAR)
            end
          end
        end
      end
    end

    def self.check_land_step
      return unless @@waiting_for_land_step
      return unless Manager.save_data.system_enabled && Manager.toggled?
      
      terrain = $game_player.pbTerrainTag
      if !terrain.can_surf
        @@waiting_for_land_step = false
        Manager.refresh
        Manager.play_mass_animation(Settings::ANIM_APPEAR)
      end
    end
  end
end

EventHandlers.add(:on_frame_update, :vibrant_vehicle_monitor, proc {
  VibrantCompanions::VehicleMonitor.update
})

EventHandlers.add(:on_player_step_taken, :vibrant_surf_transition, proc {
  VibrantCompanions::VehicleMonitor.check_land_step
})

#-------------------------------------------------------------------------------
# Corrección de Teletransportes (Fly / Warp)
#-------------------------------------------------------------------------------
EventHandlers.add(:on_enter_map, :vibrant_fix_map_transfer, proc { |_old_map_id|
  # Si entramos a un mapa, cancelamos la espera de Surf por seguridad
  VibrantCompanions::VehicleMonitor.class_variable_set(:@@waiting_for_land_step, false)
  
  # NUEVO: Si acabamos de cargar partida, NO los escondemos en el jugador.
  # Respetamos las posiciones guardadas.
  next if VibrantCompanions::Manager.class_variable_get(:@@just_loaded)
  
  $game_temp.followers.each_follower do |event, follower_data|
    if follower_data.name && follower_data.name.start_with?("VibrantFollower_")
      follower_data.invisible_after_transfer = true
      if event
        event.transparent = true
        event.moveto($game_player.x, $game_player.y)
        event.direction = $game_player.direction
      end
    end
  end
})