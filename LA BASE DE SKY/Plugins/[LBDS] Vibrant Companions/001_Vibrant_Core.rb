#===============================================================================
# VIBRANT COMPANIONS - CORE & DATA
#===============================================================================
if defined?(Spriteset_Global)
  class Spriteset_Global
    attr_reader :follower_sprites
  end
end

module VibrantCompanions
  #-----------------------------------------------------------------------------
  # Estructura de Datos de Estado
  #-----------------------------------------------------------------------------
  class PluginState
    attr_accessor :toggled
    attr_accessor :steps
    attr_accessor :holding_item
    attr_accessor :system_enabled
		attr_accessor :saved_positions
    attr_accessor :saved_map_id

    def conga_timer
      @conga_timer = 0.0 if @conga_timer.nil?
      return @conga_timer
    end

    def conga_timer=(val)
      @conga_timer = val
    end
    
    def initialize
      @toggled      = false
      @steps        = 0
      @holding_item = nil
      @system_enabled = false
      @conga_timer    = 0.0
			@saved_positions = []
      @saved_map_id    = 0
    end
  end

  #-----------------------------------------------------------------------------
  # Manager
  #-----------------------------------------------------------------------------
  module Manager
    @@state = PluginState.new
    @@just_loaded = false # Bandera para saber si acabamos de cargar partida

    def self.save_data; return @@state; end
    
    def self.load_data(data)
      @@state = data || PluginState.new
      @@state.saved_positions ||= []
      @@state.saved_map_id ||= 0
      @@just_loaded = true
    end
    
    def self.toggled?; return @@state.toggled; end

		def self.just_loaded?
      return @@just_loaded
    end

    def self.clear_just_loaded
      @@just_loaded = false
    end

    def self.update_saved_positions
      return unless $game_map
      @@state.saved_map_id = $game_map.map_id
      @@state.saved_positions = []
      
      able_pokemon = $player.party.select { |p| p && !p.egg? && !p.fainted? }
      max = Settings.enable_caterpillar? ? Settings.max_followers : 1
      able_pokemon = able_pokemon[0...max]
      
      able_pokemon.each_with_index do |pkmn, i|
        follower = $game_temp.followers.get_follower_by_name("VibrantFollower_#{i}")
        if follower
          @@state.saved_positions << [follower.x, follower.y, follower.direction]
        else
          # Fallback seguro: si no encuentra al follower, anota la posición del jugador
          @@state.saved_positions << [$game_player.x, $game_player.y, $game_player.direction]
        end
      end
    end

    def self.toggle(force_state = nil, with_anim = true)
      old_state = @@state.toggled
      @@state.toggled = force_state.nil? ? !old_state : force_state
      
      if old_state && !@@state.toggled && with_anim
        play_toggle_animation(false)
      end
      
      refresh
      
      if !old_state && @@state.toggled && with_anim
        play_toggle_animation(true)
      end
    end

    def self.refresh
      is_indoor = $game_map && $game_map.metadata && !$game_map.metadata.outdoor_map
      indoor_blocked = is_indoor && !Settings.allow_indoors?
      
      waiting_surf = defined?(VehicleMonitor) && VehicleMonitor.waiting_for_land_step?

      if !@@state.toggled || $player.party.empty? || 
         $PokemonGlobal.bicycle || $PokemonGlobal.surfing || $PokemonGlobal.diving ||
         indoor_blocked || waiting_surf
        remove_all_vibrant_followers
        return
      end

      able_pokemon = $player.party.select { |p| p && !p.egg? && !p.fainted? }
      max = Settings.enable_caterpillar? ? Settings.max_followers : 1
      able_pokemon = able_pokemon[0...max]
      names_to_remove = []
      
      $game_temp.followers.each_follower do |event, follower|
        next unless follower.name
        
        # Limpieza profunda de residuos del plugin viejo
        if follower.name == "VibrantFollower" || follower.name == "FollowingPkmn" || follower.name == "FollowerPkmn"
          names_to_remove << follower.name
          next
        end
        
        if follower.name.start_with?("VibrantFollower_")
          idx = follower.name.split("_")[1].to_i
          names_to_remove << follower.name if idx >= able_pokemon.length
        end
      end
      names_to_remove.each { |name| $game_temp.followers.remove_follower_by_name(name) }

      # Decidir cadena de aparición
      spawn_chain = nil
      if @@just_loaded && @@state.saved_map_id == $game_map.map_id && 
         @@state.saved_positions && @@state.saved_positions.length >= able_pokemon.length
        spawn_chain = @@state.saved_positions
      else
        spawn_chain = calculate_spawn_chain(able_pokemon.length)
      end

      able_pokemon.each_with_index do |pkmn, i|
        follower_name = "VibrantFollower_#{i}"
        follower = $game_temp.followers.get_follower_by_name(follower_name)
        character_name = get_pokemon_graphic(pkmn)
        
        if follower
          follower.character_name = character_name
          follower.character_hue  = pkmn.respond_to?(:superShiny?) && pkmn.superShiny? ? pkmn.superHue : 0
          # Forzar posición si acabamos de cargar
          if @@just_loaded && spawn_chain == @@state.saved_positions
            follower.moveto(spawn_chain[i][0], spawn_chain[i][1])
            follower.direction = spawn_chain[i][2]
          end
        else
          spawn_follower(pkmn, character_name, i, spawn_chain[i])
        end
      end
      
      if $scene.is_a?(Scene_Map) && $scene.spritesetGlobal && $scene.spritesetGlobal.respond_to?(:follower_sprites)
        fs = $scene.spritesetGlobal.follower_sprites
        fs.refresh if fs
      end
    end

    def self.play_dynamic_animation(spriteset, anim_id, x, y, pkmn)
      anim = $data_animations[anim_id]
      if anim && pkmn
        original_name = anim.animation_name
        ball_name = "Ball_#{pkmn.poke_ball}" # Ej: "Ball_MASTERBALL"
        
        begin
          # 1. Cambiamos el nombre temporalmente si el gráfico existe
          if pbResolveBitmap("Graphics/Animations/#{ball_name}.png") || pbResolveBitmap("Graphics/Animations/#{ball_name}")
            anim.animation_name = ball_name
          elsif pbResolveBitmap("Graphics/Animations/Ball_POKEBALL.png") || pbResolveBitmap("Graphics/Animations/Ball_POKEBALL")
            anim.animation_name = "Ball_POKEBALL"
          end
          
          # 2. Reproducimos la animación
          spriteset.addUserAnimation(anim_id, x, y, true, 1)
        ensure
          # 3. Restauramos el nombre original SIEMPRE, incluso si hay un error
          anim.animation_name = original_name
        end
      else
        spriteset.addUserAnimation(anim_id, x, y, true, 1) if anim
      end
    end

		def self.play_mass_animation(anim_id)
      return unless $scene.is_a?(Scene_Map)
      spriteset = $scene.spriteset($game_map.map_id)
      return unless spriteset
      
      able_pokemon = $player.party.select { |p| p && !p.egg? && !p.fainted? }
      $game_temp.followers.each_follower do |event, follower|
        if follower.name && follower.name.start_with?("VibrantFollower_")
          idx = follower.name.split("_")[1].to_i
          pkmn = able_pokemon[idx]
          play_dynamic_animation(spriteset, anim_id, event.x, event.y, pkmn) if pkmn
        end
      end
    end

    private

    def self.remove_all_vibrant_followers
      if defined?(VibrantCompanions::EasterEggs)
        VibrantCompanions::EasterEggs.cancel_conga
      else
        @@state.conga_timer = 0.0 if @@state
      end
      
      names_to_remove = []
      $game_temp.followers.each_follower do |event, follower|
        next unless follower.name
        if follower.name.start_with?("VibrantFollower") || follower.name == "FollowingPkmn" || follower.name == "FollowerPkmn"
          names_to_remove << follower.name
        end
      end
      
      if names_to_remove.length > 0
        names_to_remove.each { |name| $game_temp.followers.remove_follower_by_name(name) }
        if $scene.is_a?(Scene_Map) && $scene.spritesetGlobal && $scene.spritesetGlobal.respond_to?(:follower_sprites)
          fs = $scene.spritesetGlobal.follower_sprites
          fs.refresh if fs
        end
      end
    end

    def self.spawn_follower(pkmn, character_name, index, spawn_data)
      target_x   = spawn_data[0]
      target_y   = spawn_data[1]
      target_dir = spawn_data[2]
      
      rpg_event = RPG::Event.new(target_x, target_y)
      rpg_event.id   = 999 + index
      rpg_event.name = "VibrantFollowerTemplate"
      
      page = RPG::Event::Page.new
      page.graphic.character_name = character_name
      page.graphic.character_hue  = 0
      page.move_speed             = $game_player.move_speed
      page.move_frequency         = 3
      page.walk_anime             = true
      page.step_anime             = Settings.always_animate?
      page.through                = true
      
      rpg_event.pages = [page]
      dummy_event = Game_Event.new($game_map.map_id, rpg_event, $game_map)
      dummy_event.direction = target_dir # Mira hacia el Pokémon anterior
      
      follower_name = "VibrantFollower_#{index}"
      $game_temp.followers.add_follower(dummy_event, follower_name, nil)
      
      actual_follower = $game_temp.followers.get_follower_by_name(follower_name)
      if actual_follower
        actual_follower.moveto(target_x, target_y)
        actual_follower.direction = target_dir
      end
    end

    def self.get_pokemon_graphic(pkmn)
      filename = GameData::Species.check_graphic_file("Graphics/Characters/", pkmn.species, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadow, "Followers")
      if filename.nil? || filename.empty?
        folder = pkmn.shiny? ? "Followers shiny/" : "Followers/"
        fallback = "#{folder}#{pkmn.species}"
        if pbResolveBitmap("Graphics/Characters/#{fallback}.png") || pbResolveBitmap("Graphics/Characters/#{fallback}")
          return fallback
        else
          return pkmn.species.to_s
        end
      end
      filename = filename.gsub("Graphics/Characters/", "").gsub(".png", "").gsub(".gif", "")
      return filename
    end

    # Calcula la posición en fila india, tomando en cuenta a los seguidores que ya existen
    def self.calculate_spawn_chain(count)
      chain = []
      
      # Empezamos asumiendo que el punto de partida es el jugador
      curr_x = $game_player.x
      curr_y = $game_player.y
      curr_dir = $game_player.direction

      count.times do |i|
        # Verificamos si este eslabón de la cadena ya existe físicamente en el mapa
        existing_follower = $game_temp.followers.get_follower_by_name("VibrantFollower_#{i}")
        
        if existing_follower
          curr_x = existing_follower.x
          curr_y = existing_follower.y
          curr_dir = existing_follower.direction
          chain << [curr_x, curr_y, curr_dir]
        else
          back_dir = 10 - curr_dir
          dirs_to_try = [back_dir]
          if back_dir == 8 || back_dir == 2
            dirs_to_try += [4, 6, curr_dir]
          else
            dirs_to_try += [2, 8, curr_dir]
          end

          placed = false
          dirs_to_try.each do |d|
            test_x = curr_x + (d == 6 ? 1 : d == 4 ? -1 : 0)
            test_y = curr_y + (d == 2 ? 1 : d == 8 ? -1 : 0)
            
            terrain = $game_map.terrain_tag(test_x, test_y)
            is_occupied = chain.any? { |pos| pos[0] == test_x && pos[1] == test_y } || 
                          (test_x == $game_player.x && test_y == $game_player.y)
            if $game_map.passable?(test_x, test_y, 0) && (!terrain.can_surf || $PokemonGlobal.surfing) && !is_occupied
              curr_x = test_x
              curr_y = test_y
              curr_dir = 10 - d
              chain << [curr_x, curr_y, curr_dir]
              placed = true
              break
            end
          end
          if !placed
            chain << [curr_x, curr_y, curr_dir]
          end
        end
      end
      
      return chain
    end

    def self.play_toggle_animation(appearing)
      return unless $scene.is_a?(Scene_Map)
      spriteset = $scene.spriteset($game_map.map_id)
      return unless spriteset
      
      anim_id = appearing ? Settings::ANIM_APPEAR : Settings::ANIM_RECALL
      able_pokemon = $player.party.select { |p| p && !p.egg? && !p.fainted? }
      
      # Tanto al salir como al entrar, reproducimos la animación en la posición de cada evento
      $game_temp.followers.each_follower do |event, follower|
        if follower.name && follower.name.start_with?("VibrantFollower_")
          idx = follower.name.split("_")[1].to_i
          pkmn = able_pokemon[idx]
          play_dynamic_animation(spriteset, anim_id, event.x, event.y, pkmn) if pkmn
        end
      end
    end
  end
end

#===============================================================================
# Hooks y SaveData
#===============================================================================

# Registro de Datos de Guardado
SaveData.register(:vibrant_companions) do
  save_value { 
    VibrantCompanions::Manager.update_saved_positions
    VibrantCompanions::Manager.save_data 
  }
  load_value { |data| VibrantCompanions::Manager.load_data(data) }
  new_game_value { VibrantCompanions::PluginState.new }
end

# Refresco al cambiar de mapa o actualizar spriteset
EventHandlers.add(:on_map_or_spriteset_change, :vibrant_follower_refresh, proc {
  VibrantCompanions::Manager.refresh
})

# Input para el Toggle
EventHandlers.add(:on_frame_update, :vibrant_follower_input, proc {
  next if $game_temp.in_menu || $game_temp.message_window_showing
  next if $game_player.moving? || $game_player.lock?
  next if $game_temp.in_battle || $game_temp.encounter_triggered
  next unless VibrantCompanions::Manager.save_data.system_enabled
  if Input.trigger?(VibrantCompanions::Settings::TOGGLE_KEY)
    pbPlayDecisionSE
    VibrantCompanions::Manager.toggle
  end
})

# Input para rotar el equipo y cambiar el Pokémon que te sigue
EventHandlers.add(:on_frame_update, :vibrant_cycle_party, proc {
  next if $game_temp.in_menu || $game_temp.message_window_showing
  next if $game_player.moving? || $game_player.lock?
  next if $game_temp.in_battle || $game_temp.encounter_triggered
  next unless VibrantCompanions::Manager.save_data.system_enabled
  next unless VibrantCompanions::Manager.toggled?
  next unless VibrantCompanions::Settings::ENABLE_PARTY_CYCLING
  next if $player.party.length < 2
  if Input.trigger?(VibrantCompanions::Settings::CYCLE_PARTY_FORWARD_KEY)
    pbPlayDecisionSE
    $player.party.rotate!
    VibrantCompanions::Manager.refresh
  elsif Input.trigger?(VibrantCompanions::Settings::CYCLE_PARTY_BACKWARD_KEY)
    pbPlayDecisionSE
    $player.party.rotate!(-1)
    VibrantCompanions::Manager.refresh
  end
})

# Apagar la bandera de carga en el primer frame jugable
EventHandlers.add(:on_frame_update, :vibrant_clear_load_flag, proc {
  next unless VibrantCompanions::Manager.just_loaded?   
  if $scene.is_a?(Scene_Map)
    VibrantCompanions::Manager.clear_just_loaded
  end
})

#===============================================================================
# Integración con Menús y Pantallas
#===============================================================================

# Antes de salir de la escena de Equipo
class PokemonParty_Scene
  alias vibrant_pbEndScene pbEndScene unless method_defined?(:vibrant_pbEndScene)
  def pbEndScene
    VibrantCompanions::Manager.refresh if VibrantCompanions::Manager.toggled?
    vibrant_pbEndScene
  end
end

# Antes de salir del PC
class PokemonStorageScene
  alias vibrant_pbCloseBox pbCloseBox unless method_defined?(:vibrant_pbCloseBox)
  def pbCloseBox
    VibrantCompanions::Manager.refresh if VibrantCompanions::Manager.toggled?
    vibrant_pbCloseBox
  end
end

# Antes de terminar una Evolución
class PokemonEvolutionScene
  alias vibrant_pbEndScreen pbEndScreen unless method_defined?(:vibrant_pbEndScreen)
  def pbEndScreen(*args)
    VibrantCompanions::Manager.refresh if VibrantCompanions::Manager.toggled?
    vibrant_pbEndScreen(*args)
  end
end

# Al eclosionar un huevo
alias vibrant_pbHatch pbHatch unless defined?(vibrant_pbHatch)
def pbHatch(*args)
  ret = vibrant_pbHatch(*args)
  VibrantCompanions::Manager.refresh if VibrantCompanions::Manager.toggled?
  return ret
end

# Al usar un objeto desde la mochila
alias vibrant_pbChooseItem pbChooseItem unless defined?(vibrant_pbChooseItem)
def pbChooseItem(*args)
  ret = vibrant_pbChooseItem(*args)
  VibrantCompanions::Manager.refresh if VibrantCompanions::Manager.toggled?
  return ret
end