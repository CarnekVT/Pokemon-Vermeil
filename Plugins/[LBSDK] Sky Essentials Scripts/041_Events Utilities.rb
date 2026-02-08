#====================================================================================
# Events Utilities - Versión Completa para Essentials v21.1
# Créditos: Zik
#====================================================================================
# Extiende la funcionalidad de los eventos mediante comentarios o nombre del 
# evento a modo de comandos.
#
# Comandos en NOMBRE de evento:
#   sizeblock(x,y)                -> Área de colisión sólida (ej: sizeblock(2,1))
#
# Comandos en COMENTARIOS:
#   s:Hitbox/Rx,Ry                -> Radio de interacción/colisión.
#   s:Offset/X,Y                  -> Desplazar el gráfico (píxeles).
#   s:Offset_shadow/X,Y           -> Desplazar la sombra (píxeles).
#   s:Float                       -> Animación de levitación.
#   s:doppelganger                -> Copia el gráfico del jugador.
#   s:pokemon_event/Nombre        -> Gráfico de Pokémon + Cry al interactuar.
#   s:pokemon_event_shiny/Nombre  -> Versión Shiny del anterior.
#   s:Custom/RUTA                 -> Carga gráfico desde Graphics/ (ej: Pictures/molino)
#   s:FrameSize/W,H               -> Tamaño de UN frame (arregla el error del video).
#   s:NoPause                     -> El evento siempre se actualiza (ignora anti-lag/pausa).
#   s:Custom_full/RUTA            -> Carga un gráfico en específico para el ow usando
#                                   una ruta dentro de Graphics. La imagen será 
#                                   cargada de forma completa.
#                                   Ejemplo: s:Custom_full/Pictures/introBoy
#   s:Spritesheet_FRAMES_VEL/RUTA -> Carga un gráfico en específico para el ow usando
#                                   una ruta dentro de Graphics. Esta imagen será 
#                                   tomada como un spritesheet horizontal.
#                                   Ejemplo: s:Spritesheet_8_4/Pictures/molino
#====================================================================================

class Game_Event < Game_Character
  attr_reader :hitbox_rx, :hitbox_ry
  attr_reader :block_width, :block_height
  attr_accessor :visual_offset_x, :visual_offset_y
  attr_accessor :is_floating
  attr_accessor :cry_species
  attr_reader :float_offset
  attr_accessor :shadow_offset_x, :shadow_offset_y
  attr_reader :frame_width, :frame_height
  attr_accessor :always_update
  attr_accessor :is_full_image
  attr_accessor :custom_frames, :current_spritesheet_frame, :custom_speed

  #-----------------------------------------------------------------------------
  # PROTECCIÓN DE ALIAS
  #-----------------------------------------------------------------------------
  unless method_defined?(:zik_ext_initialize)
    alias_method :zik_ext_initialize, :initialize
  end

  unless method_defined?(:zik_ext_refresh)
    alias_method :zik_ext_refresh, :refresh
  end

  unless method_defined?(:zik_ext_screen_y)
    alias_method :zik_ext_screen_y, :screen_y
  end

  unless method_defined?(:zik_ext_should_update?)
    alias_method :zik_ext_should_update?, :should_update?
  end

  unless method_defined?(:zik_ext_start)
    alias_method :zik_ext_start, :start
  end

  #-----------------------------------------------------------------------------
  # Implementación
  #-----------------------------------------------------------------------------
  def initialize(map_id, event, map = nil)
    @hitbox_rx = 0
    @hitbox_ry = 0
    @block_width = 1
    @block_height = 1
    @visual_offset_x = 0
    @visual_offset_y = 0
    @is_floating = false
    @float_offset = 0
    @shadow_offset_x = 0
    @shadow_offset_y = 0
    @cry_species = nil
    @frame_width = 0
    @frame_height = 0
    @always_update = false
    @is_full_image = false
    @custom_frames = 0
    @custom_speed = 0
    @current_spritesheet_frame = 0
    @spritesheet_timer = 0
    zik_ext_initialize(map_id, event, map)
  end

  def refresh
    zik_ext_refresh
    
    # --- SIZEBLOCK (Área) ---
    @block_width = 1
    @block_height = 1
    is_blocker = false
    if @event.name[/sizeblock\((\d+),(\d+)\)/i]
      @block_width = $1.to_i
      @block_height = $2.to_i
      is_blocker = true
    elsif @event.name[/sizeblock/i]
      is_blocker = true
    end
    if is_blocker
      @through = false
      @priority_type = 1
      @trigger = 0
      if @character_name == "" && @tile_id == 0
        @character_name = $game_player.character_name 
        @opacity = 0
      end
    end

    # Resetear valores de comentarios
    @hitbox_rx = 0
    @hitbox_ry = 0
    @visual_offset_x = 0
    @visual_offset_y = 0
    @is_floating = false
    @float_offset = 0
    @shadow_offset_x = 0
    @shadow_offset_y = 0
    @cry_species = nil
    @frame_width = 0
    @frame_height = 0
    @always_update = false
    @is_full_image = false
    @custom_frames = 0
    @custom_speed = 0

    return unless @page && @list

    # Analizar comentarios
    @list.each do |command|
      next unless [108, 408].include?(command.code)
      cmd_text = command.parameters[0]
      next if cmd_text.nil?

      # --- HITBOX (Radio) ---
      if cmd_text.match(/^s:Hitbox\/(\d+),(\d+)/i)
        @hitbox_rx = $1.to_i
        @hitbox_ry = $2.to_i
      
      # --- OFFSET ---
      elsif cmd_text.match(/^s:Offset\/([-\d]+),([-\d]+)/i)
        @visual_offset_x = $1.to_i
        @visual_offset_y = $2.to_i

      # --- OFFSET SHADOW ---
      elsif cmd_text.match(/^s:Offset_shadow\/([-\d]+),([-\d]+)/i)
        @shadow_offset_x = $1.to_i
        @shadow_offset_y = $2.to_i

      # --- FLOAT ---
      elsif cmd_text.match(/^s:Float/i)
        @is_floating = true

      # --- POKÉMON EVENT ---
      elsif cmd_text.match(/^s:pokemon_event_shiny\/(.+)/i)
        filename = $1.strip
        @character_name = "Followers shiny/#{filename}"
        @cry_species = filename

      elsif cmd_text.match(/^s:pokemon_event\/(.+)/i)
        filename = $1.strip
        @character_name = "Followers/#{filename}"
        @cry_species = filename

      #---- DOPPELGANGER ---
      elsif cmd_text.match(/^s:doppelganger/i)
        @character_name = $game_player.character_name
      
      # --- CUSTOM ---
      elsif cmd_text.match(/^s:Custom\/(.+)/i)
        filename = $1.strip
        puts "DEBUG: Game_Event - Raw filename from command: #{filename}"
        if filename.downcase.start_with?("graphics/")
          @character_name = "../#{filename[9..-1]}"
        else
          @character_name = filename
        end
        puts "DEBUG: Game_Event - Set character name to: #{@character_name}"
      
      # --- FRAME SIZE ---
      elsif cmd_text.match(/^s:FrameSize\/(\d+),(\d+)/i)
        @frame_width = $1.to_i
        @frame_height = $2.to_i

      # --- NO PAUSE / ALWAYS UPDATE ---
      elsif cmd_text.match(/^s:NoPause/i) || cmd_text.match(/^s:AlwaysUpdate/i)
        @always_update = true

      # --- CUSTOM FULL ---  
      elsif cmd_text.match(/^s:Custom_full\/(.+)/i)
        filename = $1.strip
        @character_name = "../#{filename}"
        @is_full_image = true
        @direction_fix = true
        @step_anime = false 
        
      # --- SPRITESHEET ---
      elsif cmd_text.match(/^s:Spritesheet_(\d+)(?:_(\d+))?\/(.+)/i)
        @custom_frames = $1.to_i
        @custom_speed = $2 ? $2.to_i : 0 
        filename = $3.strip       
        @character_name = "../#{filename}"
        @step_anime = true
        @direction_fix = true
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Lógica de Interacción
  #-----------------------------------------------------------------------------
  def start
    if @cry_species && ![@trigger == 3, @trigger == 4].include?(true)
      # Corregido para v21.1: Uso de GameData::Species
      specie_data = GameData::Species.try_get(@cry_species)
      GameData::Species.play_cry(specie_data.id) if specie_data rescue nil
    end
    zik_ext_start
  end

  #-----------------------------------------------------------------------------
  # Lógica Visual y Física
  #-----------------------------------------------------------------------------
  def should_update?(recalc = false)
    return true if @is_floating || @always_update
    return zik_ext_should_update?(recalc)
  end

  def screen_x
    return super + @visual_offset_x
  end

  def screen_y
    y = zik_ext_screen_y + @visual_offset_y
    if @is_floating
      timer = Graphics.frame_count + (@id * 7)
      @float_offset = (Math.sin(timer / 15.0) * 5).round
      y -= @float_offset 
    else
      @float_offset = 0
    end
    return y
  end

  def at_coordinate?(x, y)
    if @hitbox_rx > 0 || @hitbox_ry > 0
      return x.between?(@x - @hitbox_rx, @x + @hitbox_rx) &&
             y.between?(@y - @hitbox_ry, @y + @hitbox_ry)
    end
    effective_width = (@block_width > 1) ? @block_width : (@width || 1)
    effective_height = (@block_height > 1) ? @block_height : (@height || 1)
    return x.between?(@x, @x + effective_width - 1) &&
           y.between?(@y - effective_height + 1, @y)
  end
end

#===============================================================================
# Parche para Sprite_Character
#===============================================================================
class Sprite_Character
  alias_method :zik_full_update, :update unless method_defined?(:zik_full_update)

  def update
    zik_full_update

    bmp = (@charbitmapAnimated && @charbitmap) ? @charbitmap.bitmap : @charbitmap
    return unless bmp

    # IMAGEN COMPLETA
    if @character.respond_to?(:is_full_image) && @character.is_full_image
      self.src_rect.set(0, 0, bmp.width, bmp.height)
      self.ox = bmp.width / 2
      self.oy = bmp.height

    # SPRITESHEET
    elsif @character.respond_to?(:custom_frames) && @character.custom_frames > 0
      cw = bmp.width / @character.custom_frames
      ch = bmp.height

      if @character.custom_speed > 0
        target_frames = @character.custom_speed
      else
        target_frames = (7 - @character.move_speed) * 3
        target_frames = 4 if target_frames <= 0
      end

      duration_per_frame = target_frames / 60.0
      current_frame = (System.uptime / duration_per_frame).to_i % @character.custom_frames 
      sx = current_frame * cw
      self.src_rect.set(sx, 0, cw, ch)
      self.ox = cw / 2
      self.oy = ch
    end
  end
end
