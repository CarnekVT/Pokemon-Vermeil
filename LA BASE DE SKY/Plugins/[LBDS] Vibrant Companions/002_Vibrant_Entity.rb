#===============================================================================
# VIBRANT COMPANIONS - ENTITY
#===============================================================================

module VibrantCompanions
  module SmartSpacing
    @@bounds_cache = {}

    def self.get_horizontal_bounds(character_name, direction)
      return nil if character_name.nil? || character_name.empty?
      
      @@bounds_cache[character_name] ||= {}
      return @@bounds_cache[character_name][direction] if @@bounds_cache[character_name][direction]

      bmp = nil
      begin
        path = pbResolveBitmap("Graphics/Characters/#{character_name}")
        return nil unless path
        
        bmp = Bitmap.new(path)
        fw = bmp.width / 4
        fh = bmp.height / 4
        row = (direction == 2 ? 0 : direction == 4 ? 1 : direction == 6 ? 2 : 3)
        sy = row * fh
        
        left = fw; right = 0
        (0...fw).each do |x|
          (0...fh).each do |y|
            if bmp.get_pixel(x, sy + y).alpha > 20
              left = x if x < left
              right = x if x > right
            end
          end
        end
        
        bounds = { left: left, right: right, ox: fw / 2 }
        @@bounds_cache[character_name][direction] = bounds
        return bounds
      rescue
        return nil
      ensure
        bmp.dispose if bmp && !bmp.disposed?
      end
    end
    
    def self.clear_cache
      @@bounds_cache.clear
    end
  end
end

# Inyectamos una variable de lectura segura en todos los personajes
class Game_Character
  def vibrant_visual_shift_x
    @vibrant_visual_shift_x ||= 0
    return @vibrant_visual_shift_x
  end
end

class Game_PokemonFollower < Game_Follower
  attr_accessor :vibrant_state
  attr_accessor :current_leader
  attr_accessor :vibrant_name

  def initialize(event_data)
    super(event_data)
    @vibrant_name   = event_data.name # Capturamos "VibrantFollower_X"
    @vibrant_state  = :following
    @current_leader = $game_player
  end

  #-----------------------------------------------------------------------------
  # LÓGICA DE ACTUALIZACIÓN
  #-----------------------------------------------------------------------------
  alias vibrant_update update unless method_defined?(:vibrant_update)
  def update
    @step_anime = VibrantCompanions::Settings.always_animate?
    vibrant_update
    
    # LÓGICA DE LA CONGA
    state = VibrantCompanions::Manager.save_data
    if state.conga_timer > 0
      
      # Solo el líder del tren reduce el tiempo y restaura la música al terminar
      if @vibrant_name == "VibrantFollower_0" && state.conga_timer > 0
        state.conga_timer -= Graphics.delta
        if state.conga_timer <= 0
          state.conga_timer = 0.0
          $game_system.bgm_unpause # Comando correcto
        end
      end
      
      # Verificamos de nuevo por si el líder acaba de apagar el temporizador
      if state.conga_timer > 0
        idx = @vibrant_name.split("_")[1].to_i
        time = System.uptime * 5.0
        beat = Math.sin(time - (idx * 0.8))
        
        # 1. SALTO
        self.y_offset = (beat > 0.7) ? -12 : 0
        
        # 2. GIROS RÍTMICOS (Izquierda, Derecha, Frente)
        if beat > 0.4
          @direction = 4 # Mirar Izquierda
        elsif beat < -0.4
          @direction = 6 # Mirar Derecha
        else
          @direction = @current_leader ? @current_leader.direction : 2
        end
      else
        self.y_offset = 0
      end
      
    else
      self.y_offset = 0
    end
  end

  def pattern_update_speed
    if !moving? && @step_anime && defined?(VibrantCompanions::Settings::IDLE_ANIMATION_SPEED)
      return VibrantCompanions::Settings::IDLE_ANIMATION_SPEED
    end
    return super
  end

  #-----------------------------------------------------------------------------
  # MOVIMIENTO Y SEPARACIÓN
  #-----------------------------------------------------------------------------
  alias vibrant_follow_leader follow_leader unless method_defined?(:vibrant_follow_leader)
  def follow_leader(leader, instant = false, leaderIsTrueLeader = true)
    @current_leader = leader
    return if @vibrant_state == :wandering || @vibrant_state == :returning
    vibrant_follow_leader(leader, instant, leaderIsTrueLeader)
  end

  alias vibrant_move_speed= move_speed= unless method_defined?(:vibrant_move_speed=)
  def move_speed=(val)
    return if @vibrant_state != :following
    self.vibrant_move_speed = val
  end

  def force_speed(val)
    self.vibrant_move_speed = val
  end

  # --- Deduce el líder real sin esperar a que el motor lo actualice ---
  def get_true_leader
    return $game_player if !@vibrant_name || !@vibrant_name.start_with?("VibrantFollower_")
    idx = @vibrant_name.split("_")[1].to_i
    return $game_player if idx == 0
    prev_follower = $game_temp.followers.get_follower_by_name("VibrantFollower_#{idx - 1}")
    return prev_follower || $game_player
  end

  def vibrant_tile_passable?(tx, ty)
    return false if tx < 0 || tx >= $game_map.width
    return false if ty < 0 || ty >= $game_map.height
    
    terrain = $game_map.terrain_tag(tx, ty)
    # Si no estamos surfeando, el agua es un obstáculo visual
    return false if terrain.can_surf && !$PokemonGlobal.surfing
    
    # Verifica la transitabilidad básica del mapa (ignora eventos, solo revisa paredes)
    return $game_map.passable?(tx, ty, 0)
  end

  alias vibrant_screen_x screen_x unless method_defined?(:vibrant_screen_x)
  def screen_x
    ret = vibrant_screen_x
    @vibrant_visual_shift_x ||= 0
    @vibrant_frames_active ||= 0
    @vibrant_frames_active += 1
    
    leader = get_true_leader
    
    # --- NUEVO: Congelar espaciado durante Emotes/Interacciones ---
    # Si el Pokémon o su líder están ejecutando una animación forzada, ignoramos el cálculo
    if self.move_route_forcing || (leader != $game_player && leader.move_route_forcing)
      return ret + @vibrant_visual_shift_x
    end
    # --------------------------------------------------------------
    
    if !VibrantCompanions::Settings::ENABLE_SMART_SPACING || 
       @vibrant_state != :following || 
       ![4, 6].include?(@direction)
      
      if @vibrant_visual_shift_x != 0
        @vibrant_visual_shift_x = (@vibrant_visual_shift_x * 0.7).to_i
      end
      return ret + @vibrant_visual_shift_x
    end
    
    if !VibrantCompanions::Settings::ENABLE_TRAIN_SMART_SPACING && leader != $game_player
      if @vibrant_visual_shift_x != 0
        @vibrant_visual_shift_x = (@vibrant_visual_shift_x * 0.7).to_i
      end
      return ret + @vibrant_visual_shift_x
    end
    
    # --- SISTEMA DE CANDADO DE COORDENADAS ---
    if @vibrant_last_lx != leader.x || @vibrant_last_ly != leader.y ||
       @vibrant_last_sx != self.x || @vibrant_last_sy != self.y
       
      @vibrant_last_lx = leader.x
      @vibrant_last_ly = leader.y
      @vibrant_last_sx = self.x
      @vibrant_last_sy = self.y
      
      p_bounds = VibrantCompanions::SmartSpacing.get_horizontal_bounds(leader.character_name, leader.direction)
      f_bounds = VibrantCompanions::SmartSpacing.get_horizontal_bounds(@character_name, @direction)
      
      if p_bounds && f_bounds && self.y == leader.y
        gap = VibrantCompanions::Settings::SMART_SPACING_GAP
        dx = self.x - leader.x
        
        if dx == 1
          dist_actual = (p_bounds[:right] - p_bounds[:ox]) + (f_bounds[:ox] - f_bounds[:left])
          @vibrant_base_shift = -(32 - dist_actual - gap)
        elsif dx == -1
          dist_actual = (p_bounds[:ox] - p_bounds[:left]) + (f_bounds[:right] - f_bounds[:ox])
          @vibrant_base_shift = (32 - dist_actual - gap)
        else
          @vibrant_base_shift = 0
        end
      else
        @vibrant_base_shift = 0
      end
    end
    
    leader_shift = leader.respond_to?(:vibrant_visual_shift_x) ? leader.vibrant_visual_shift_x : 0
    target_shift = (@vibrant_base_shift || 0) + leader_shift
    
    # --- SISTEMA ANTI-CLIPPING ---
    if target_shift < 0
      if !vibrant_tile_passable?(self.x - 1, self.y)
        target_shift = [target_shift, -6].max 
      end
    elsif target_shift > 0
      if !vibrant_tile_passable?(self.x + 1, self.y)
        target_shift = [target_shift, 6].min  
      end
    end
    
    # --- APLICACIÓN DEL DESPLAZAMIENTO ---
    if @vibrant_frames_active <= 10
      @vibrant_visual_shift_x = target_shift
    elsif @vibrant_visual_shift_x != target_shift
      diff = target_shift - @vibrant_visual_shift_x
      step = (diff * 0.3).round
      step = (diff > 0 ? 1 : -1) if step == 0 && diff != 0
      @vibrant_visual_shift_x += step
    end
    
    return ret + @vibrant_visual_shift_x
  end

  alias vibrant_screen_y screen_y unless method_defined?(:vibrant_screen_y)
  def screen_y; return vibrant_screen_y; end
end

class Game_FollowerFactory
  alias vibrant_create_follower_object create_follower_object unless method_defined?(:vibrant_create_follower_object)
  def create_follower_object(event_data)
    if event_data.name && event_data.name.start_with?("VibrantFollower_")
      return Game_PokemonFollower.new(event_data)
    end
    return vibrant_create_follower_object(event_data)
  end
end