if Settings::MOSTRAR_BARRAS_ENTRENADORES # << Make true to use this script, false to disable.
#===============================================================================
#
#  Trainer Sensor Script
#  Author     : Drimer
#  Editor     : Skyflyer, Zik
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
RANGE_BARS_TRAINER = 4

#===============================================================================
# **  
#===============================================================================
module TrainerSensor
  @top = Sprite.new
  @top.z = 99999
  @bottom = Sprite.new
  @bottom.z = 99999
  @left = Sprite.new
  @left.z = 99999
  @right = Sprite.new
  @right.z = 99999
  @frame = Sprite.new
  @frame.z = 99999
  @triggered = false
  @created = false
  @current_closeness  = 0.2
  @target_closeness   = 0.2
  @rendered_closeness = -1.0
  @slide_progress     = 0.0
  @slide_target       = 0.0
  @current_dir        = 2
  @rel_x              = 0
  @rel_y              = 0
  entrenadorMasCercano = nil
  @last_update_time = Time.now
  
  
  def self.create(distance, direction = 2, rel_x = 0, rel_y = 0)
    if !@created
      if Settings::BAR_SHAPE == :SQUARE
        @frame.bitmap = Bitmap.new(Graphics.width, Graphics.height) if !@frame.bitmap || @frame.bitmap.disposed?
        @frame.ox = 0
        @frame.oy = 0
        @frame.x  = 0
        @frame.y  = 0
      else
        max_h = (Settings::BAR_SHAPE == :SLANTED) ? Settings::SLANTED_BAR_HEIGHT : Settings::HORIZONTAL_BAR_HEIGHT
        @top.bitmap    = Bitmap.new(Graphics.width, max_h) if !@top.bitmap || @top.bitmap.disposed?
        @bottom.bitmap = Bitmap.new(Graphics.width, max_h) if !@bottom.bitmap || @bottom.bitmap.disposed?
        @top.oy = 0      
        @top.y -= max_h
        @top.x  = 0 if $PokemonSystem

        @bottom.oy = max_h - Graphics.height
        @bottom.y += max_h
        @bottom.x  = 0 if $PokemonSystem
      end
      
      rango_max = RANGE_BARS_TRAINER > 0 ? RANGE_BARS_TRAINER : 4
      @current_closeness  = 0.0
      @target_closeness   = ((rango_max + 1.0 - distance) / (rango_max + 1.0)).clamp(Settings::BAR_SOFT_RANGE, 1.0)
      @slide_progress     = 0.0
      @slide_target       = 1.0
      @current_dir        = direction
      @rel_x              = rel_x
      @rel_y              = rel_y
      
      draw_bars_graphic(@current_closeness, @current_dir, @rel_x, @rel_y)
      @rendered_closeness = @current_closeness
      @created = true
    end
  end
  
  def self.draw_bars_graphic(closeness, direction = 2, rel_x = 0, rel_y = 0)
    if Settings::BAR_SHAPE == :SQUARE
      return if !@frame.bitmap || @frame.bitmap.disposed?
      @frame.bitmap.clear
    else
      return if !@top.bitmap || !@bottom.bitmap || @top.bitmap.disposed? || @bottom.bitmap.disposed?
      @top.bitmap.clear
      @bottom.bitmap.clear
      @left.bitmap.clear if @left && @left.bitmap && !@left.bitmap.disposed?
      @right.bitmap.clear if @right && @right.bitmap && !@right.bitmap.disposed?
    end
    
    base_rgb = Settings::CUSTOM_RGB_ENABLED ? Settings::CUSTOM_RGB : [10, 12, 16]
    max_a    = Settings::CUSTOM_RGB_ENABLED ? Settings::CUSTOM_ALPHA : 240
    
    # Cálculo suave de opacidad que empieza desde exactamente 0 cuando closeness es 0.0
    soft = Settings::BAR_SOFT_RANGE
    amin = Settings::BAR_ALPHA_MIN_RATIO
    base_alpha = if closeness <= 0.001
                   0
                 elsif closeness < soft
                   # Desvanecimiento al entrar (0.0 -> soft) o al salir
                   (max_a * amin * (closeness / soft)).round.clamp(0, 255)
                 else
                   # Intensificación continua dentro del rango activo
                   ratio_norm = (closeness - soft) / (1.0 - soft)
                   (max_a * (amin + (1.0 - amin) * ratio_norm)).round.clamp(0, 255)
                 end
    
    if base_alpha <= 0
      return
    end
    
    if Settings::BAR_GRAPHIC && !Settings::BAR_GRAPHIC.empty? && pbResolveBitmap("Graphics/Pictures/" + Settings::BAR_GRAPHIC)
      bmp = Bitmap.new("Graphics/Pictures/" + Settings::BAR_GRAPHIC)
      if Settings::BAR_SHAPE == :SQUARE && @frame.bitmap
        @frame.bitmap.blt(0, 0, bmp, bmp.rect, base_alpha)
      elsif @top.bitmap && @bottom.bitmap
        @top.bitmap.blt(0, 0, bmp, bmp.rect, base_alpha)
        @bottom.bitmap.blt(0, 0, bmp, bmp.rect, base_alpha)
      end
      bmp.dispose
      return
    end

    dir_flip_x = false
    dir_flip_y = false
    if Settings::DYNAMIC_DIRECTION
      dir_flip_x = (direction == 4 || rel_x < 0)
      dir_flip_y = (direction == 8 || rel_y < 0)
    end

    case Settings::BAR_SHAPE
    when :SQUARE
      max_t = Settings::SQUARE_FRAME_THICKNESS > 0 ? Settings::SQUARE_FRAME_THICKNESS : 40
      # El grosor empieza en 0 para que brote suavemente desde el borde exterior
      soft = Settings::BAR_SOFT_RANGE
      emin = Settings::SQUARE_MIN_EXPAND_RATIO
      thickness = if closeness <= 0.001
                    0
                  elsif closeness < soft
                    (max_t * emin * (closeness / soft)).round.clamp(0, max_t)
                  else
                    ratio_norm = (closeness - soft) / (1.0 - soft)
                    (max_t * (emin + (1.0 - emin) * ratio_norm)).round.clamp(1, max_t)
                  end
      
      thickness.times do |d|
        ratio = d.to_f / thickness
        fade  = 1.0 - (ratio ** Settings::BAR_FADE_CURVE)
        alpha = (base_alpha * fade).round.clamp(0, 255)
        line_color = Color.new(base_rgb[0], base_rgb[1], base_rgb[2], alpha)
        
        # Anillo superior
        w_top = Graphics.width - (d * 2)
        @frame.bitmap.fill_rect(d, d, w_top, 1, line_color) if w_top > 0
        
        # Anillo inferior
        if Graphics.height - 1 - d > d && w_top > 0
          @frame.bitmap.fill_rect(d, Graphics.height - 1 - d, w_top, 1, line_color)
        end
        
        # Anillo izquierdo
        h_side = Graphics.height - ((d + 1) * 2)
        if h_side > 0
          @frame.bitmap.fill_rect(d, d + 1, 1, h_side, line_color)
        end
        
        # Anillo derecho
        if Graphics.width - 1 - d > d && h_side > 0
          @frame.bitmap.fill_rect(Graphics.width - 1 - d, d + 1, 1, h_side, line_color)
        end
      end

    when :SLANTED
      max_h = Settings::SLANTED_BAR_HEIGHT
      soft  = Settings::BAR_SOFT_RANGE
      emin  = Settings::BAR_MIN_EXPAND_RATIO
      effective_height = if closeness <= 0.001
                           0
                         elsif closeness < soft
                           (max_h * emin * (closeness / soft)).round.clamp(0, max_h)
                         else
                           ratio_norm = (closeness - soft) / (1.0 - soft)
                           (max_h * (emin + (1.0 - emin) * ratio_norm)).round.clamp(1, max_h)
                         end
      effective_height.times do |i|
        ratio = i.to_f / effective_height
        fade  = 1.0 - (ratio ** Settings::BAR_FADE_CURVE)
        alpha = (base_alpha * fade).round.clamp(0, 255)
        line_color = Color.new(base_rgb[0], base_rgb[1], base_rgb[2], alpha)
        
        max_x = (Graphics.width * (1.0 - ratio)).round
        if max_x > 0
          start_x = dir_flip_x ? (Graphics.width - max_x) : 0
          @top.bitmap.fill_rect(start_x, i, max_x, 1, line_color)
        end
        
        bottom_y = max_h - 1 - i
        start_x  = dir_flip_x ? 0 : (Graphics.width * ratio).round
        width    = Graphics.width - start_x
        @bottom.bitmap.fill_rect(start_x, bottom_y, width, 1, line_color) if width > 0 && bottom_y >= 0
      end

    else # :HORIZONTAL
      max_h = Settings::HORIZONTAL_BAR_HEIGHT
      soft  = Settings::BAR_SOFT_RANGE
      emin  = Settings::BAR_MIN_EXPAND_RATIO
      effective_height = if closeness <= 0.001
                           0
                         elsif closeness < soft
                           (max_h * emin * (closeness / soft)).round.clamp(0, max_h)
                         else
                           ratio_norm = (closeness - soft) / (1.0 - soft)
                           (max_h * (emin + (1.0 - emin) * ratio_norm)).round.clamp(1, max_h)
                         end
      effective_height.times do |i|
        ratio = i.to_f / effective_height
        fade  = 1.0 - (ratio ** Settings::BAR_FADE_CURVE)
        alpha = (base_alpha * fade).round.clamp(0, 255)
        line_color = Color.new(base_rgb[0], base_rgb[1], base_rgb[2], alpha)
        
        @top.bitmap.fill_rect(0, i, Graphics.width, 1, line_color)
        
        bottom_y = max_h - 1 - i
        @bottom.bitmap.fill_rect(0, bottom_y, Graphics.width, 1, line_color) if bottom_y >= 0
      end
    end
  end
  
  
  def self.triggered?
    @triggered
  end
  
  def self.show(distancia, direction = 2, rel_x = 0, rel_y = 0)
    rango_max = RANGE_BARS_TRAINER > 0 ? RANGE_BARS_TRAINER : 4
    @target_closeness = ((rango_max + 1.0 - distancia) / (rango_max + 1.0)).clamp(Settings::BAR_SOFT_RANGE, 1.0)
    @current_dir      = direction
    @rel_x            = rel_x
    @rel_y            = rel_y
    self.create(distancia, direction, rel_x, rel_y)
    @triggered = true
  end
  
  def self.hide
    @triggered = false
  end
  
  
  
  # Transiciones usando delta time real.
  def self.update
    return if !@created
    
    # --- Delta time ---
    now = Time.now
    dt  = (now - @last_update_time).to_f.clamp(0.0001, 0.1)  # segundos reales, cap a 100ms
    @last_update_time = now
    fade_smoothing  = 1.0 - ((1.0 - Settings::BAR_FADE_RATE)  ** (dt * 60.0))
    slide_smoothing = 1.0 - ((1.0 - Settings::BAR_SLIDE_RATE) ** (dt * 60.0))
    
    if Settings::BAR_SHAPE == :SQUARE
      if !@triggered
        @target_closeness = 0.0
      end
    else
      max_h = (Settings::BAR_SHAPE == :SLANTED) ? Settings::SLANTED_BAR_HEIGHT : Settings::HORIZONTAL_BAR_HEIGHT
      # Al ocultar, también reducimos closeness -> 0 para que la opacidad se
      # desvanezca suavemente.
      @target_closeness = 0.0 if !@triggered
      @slide_target = @triggered ? 1.0 : 1.0  # al ocultar se queda en 1 (sin slide-out)
      if @slide_progress != @slide_target
        if (@slide_progress - @slide_target).abs > 0.01
          @slide_progress += (@slide_target - @slide_progress) * slide_smoothing
        else
          @slide_progress = @slide_target
        end
      end
      hidden_offset = 1.0 - @slide_progress
      @top.y    = -max_h * hidden_offset
      @bottom.y =  max_h * hidden_offset
    end

    # Interpolación continua al caminar o al desvanecer el marco :SQUARE
    if @current_closeness != @target_closeness
      # Mismo rate en entrada y salida para que el fade sea simétrico
      if (@current_closeness - @target_closeness).abs > 0.004
        @current_closeness += (@target_closeness - @current_closeness) * fade_smoothing
      else
        @current_closeness = @target_closeness
      end
      
      if (@current_closeness - @rendered_closeness).abs >= 0.005 || @current_closeness == @target_closeness
        draw_bars_graphic(@current_closeness, @current_dir, @rel_x, @rel_y)
        @rendered_closeness = @current_closeness
      end
    end

    # Cleanup unificado
    if !@triggered && @created
      if Settings::BAR_SHAPE == :SQUARE
        if @current_closeness <= 0.005
          @created = false
          @frame.bitmap.clear if @frame && @frame.bitmap && !@frame.bitmap.disposed?
        end
      else
        if @current_closeness <= 0.005
          @created = false
          @top.bitmap.clear    if @top && @top.bitmap && !@top.bitmap.disposed?
          @bottom.bitmap.clear if @bottom && @bottom.bitmap && !@bottom.bitmap.disposed?
        end
      end
    end
  end
  
end


def update_trainer_bars
  entrenadorMasCercano = RANGE_BARS_TRAINER + 1
  dirMasCercano        = 2
  rel_x                = 0
  rel_y                = 0
  
  for event in $game_map.events.values
    if event.name[/^Trainer\((\d+)\)$/] && event.isOff?(Settings::SELF_SWITCH)

      # Obtenemos la distancia a la que mira el entrenador.
      rango_entrenador = event.name[8...9].to_i
      
      dx, dy = case event.direction
               when 8 then [0, -1]
               when 2 then [0, 1]
               when 6 then [1, 0]
               when 4 then [-1, 0]
               else next
               end
      for i in 0..rango_entrenador+1
        distance = ($game_player.x - (event.x + dx * i)).abs + ($game_player.y - (event.y + dy * i)).abs
        if entrenadorMasCercano > distance
          entrenadorMasCercano = distance
          dirMasCercano        = event.direction
          rel_x                = $game_player.x - event.x
          rel_y                = $game_player.y - event.y
        end
      end
    end
  end

  # Actualizamos las barras en base a lo lejos que están los entrenadores.
  if entrenadorMasCercano == RANGE_BARS_TRAINER + 1
    TrainerSensor.hide() if TrainerSensor.triggered?
  else 
    TrainerSensor.show(entrenadorMasCercano, dirMasCercano, rel_x, rel_y)
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
  alias update_barras update
  def update
    update_barras
    update_trainer_bars
  end
  
  alias transfer_player_barras transfer_player if method_defined?(:transfer_player)
  def transfer_player(*args)
    TrainerSensor.hide if TrainerSensor.respond_to?(:hide)
    transfer_player_barras(*args) if respond_to?(:transfer_player_barras)
  end
end




# Change it to Events.onStepTaken if you want this to scan the events on each step
# the player gives. Before: Events.onMapUpdate  
EventHandlers.add(:on_step_taken, :barras_entrenadores, proc{|sender,e|
  update_trainer_bars
})


end # if principal
