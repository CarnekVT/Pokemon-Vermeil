#===============================================================================
# TURBO V21.1
#===============================================================================

#===============================================================================
# 1. Configuración.
#===============================================================================
module TurboConfig
  # Velocidades: [Normal, x1.5, x2.0]
  SPEED_STAGES = [1.0, 1.5, 2.0]
  
  # Teclas para activar
  TOGGLE_KEYS = [Input::ALT, Input::AUX1]
  
  # Duración del icono en pantalla (frames)
  ICON_DURATION = 150
end

# Variables globales
$GameSpeed = 0
$CanToggle = true
$RefreshEventsForTurbo = false
$SpeedDifference = 0

#===============================================================================
# 2. System Uptime.
#===============================================================================
module System
  class << self
    # Guardamos el método original si no existe
    unless method_defined?(:unscaled_uptime)
      alias_method :unscaled_uptime, :uptime
    end
    
    # Compatibilidad con scripts externos
    unless method_defined?(:real_uptime)
      def real_uptime
        return unscaled_uptime
      end
    end
  end

  def self.uptime
    # (Tiempo Real * Velocidad) + Diferencia acumulada
    return (unscaled_uptime * TurboConfig::SPEED_STAGES[$GameSpeed]) + $SpeedDifference
  end
end

#===============================================================================
# 3. Input y lógica de cambio.
#===============================================================================
module Input
  class << self
    alias_method :turbo_update, :update unless method_defined?(:turbo_update)
  end

  def self.update
    turbo_update
    
    # Detectar teclas de Turbo
    if $CanToggle && TurboConfig::TOGGLE_KEYS.any? { |key| trigger?(key) } && ( !Input.text_input || !trigger?(Input::AUX1) )
      # Guardar tiempo actual antes del cambio
      real_now = System.unscaled_uptime
      virtual_now = System.uptime
      
      # Cambiar velocidad
      $GameSpeed += 1
      $GameSpeed = 0 if $GameSpeed >= TurboConfig::SPEED_STAGES.size
      
      # Calcular nueva diferencia para que no haya saltos bruscos de tiempo
      new_mult = TurboConfig::SPEED_STAGES[$GameSpeed]
      $SpeedDifference = virtual_now - (real_now * new_mult)
      $RefreshEventsForTurbo = true
      $buttonframes = 0
    end
  end
end

#===============================================================================
# 4. Opciones.
#===============================================================================
class PokemonSystem
  alias_method :original_initialize, :initialize unless method_defined?(:original_initialize)
  attr_accessor :only_speedup_battles
  attr_accessor :battle_speed

  def initialize
    original_initialize
    @only_speedup_battles = 0 # 0 = Siempre, 1 = Solo Batalla
    @battle_speed = 0 
  end
end

module Game
  class << self
    alias_method :original_load, :load unless method_defined?(:original_load)
  end

  def self.load(save_data)
    original_load(save_data)
    if $PokemonSystem
      $CanToggle = ($PokemonSystem.only_speedup_battles == 0)
    end
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:options_menu, :turbo, {
    "name"        => _INTL("Modo turbo"),
    "order"       => 45,
    "type"        => Settings::USE_NEW_OPTIONS_UI ? :array : EnumOption,
    "condition"   => proc { next $player },
    "parameters"  => [_INTL("Siempre"), _INTL("Combates")],
    "description" => _INTL("Define si el turbo se activa siempre o solo en combates."),
    "get_proc"    => proc { next $PokemonSystem&.only_speedup_battles || 0 },
    "set_proc"    => proc { |value, _scene| 
      next unless $PokemonSystem
      $PokemonSystem.only_speedup_battles = value 
      
      # Actualizar permisos inmediatamente
      if $PokemonSystem.only_speedup_battles == 0
        $CanToggle = true
      else
        $CanToggle = false
        $GameSpeed = 0
      end
    }
  })
end

# Controladores para activar/desactivar en batalla automáticamente
EventHandlers.add(:on_start_battle, :start_speedup, proc {
  if $PokemonSystem&.only_speedup_battles == 1
    $CanToggle = true
    $GameSpeed = TurboConfig::SPEED_STAGES.size - 1
    $RefreshEventsForTurbo = true
  end
})

EventHandlers.add(:on_end_battle, :stop_speedup, proc {
  if $PokemonSystem&.only_speedup_battles == 1
    $GameSpeed = 0
    $CanToggle = false
    $RefreshEventsForTurbo = true
  end
})

# Desactivar en el Editor de Metrics (DBK / Vanilla)
EventHandlers.add(:on_game_initialize, :turbo_metrics_fix, proc {
  if defined?(SpritePositionerScreen)
    SpritePositionerScreen.class_eval do      
      unless method_defined?(:turbo_metrics_pbStart)
        alias_method :turbo_metrics_pbStart, :pbStart        
        def pbStart
          previous_toggle = $CanToggle
          previous_speed  = $GameSpeed          
          $CanToggle = false
          if $GameSpeed != 0
            $GameSpeed = 0
            $RefreshEventsForTurbo = true
          end
          begin
            turbo_metrics_pbStart
          ensure
            $CanToggle = previous_toggle
            if $GameSpeed != previous_speed
              $GameSpeed = previous_speed
              $RefreshEventsForTurbo = true
            end
          end
        end
      end
    end
  end
})

#===============================================================================
# 5. Fixes Visuales.
#===============================================================================
class Game_Map
  alias_method :original_update, :update unless method_defined?(:original_update)

  def update
    # Si se activó el turbo, actualizamos temporizadores de eventos
    if $RefreshEventsForTurbo
      if $game_map&.events
        $game_map.events.each_value { |event| event.pbResetInterpreterWaitCount if event }
      end
      if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing && $CurrentMsgWindow
        $CurrentMsgWindow.pbResetWaitCounter 
      end
      $RefreshEventsForTurbo = false
    end

    temp_timer = @fog_scroll_last_update_timer
    @fog_scroll_last_update_timer = System.uptime 
    original_update
    @fog_scroll_last_update_timer = temp_timer
    update_fog
  end

  def update_fog
    uptime_now = System.unscaled_uptime
    @fog_scroll_last_update_timer = uptime_now unless @fog_scroll_last_update_timer
    speedup_mult = ($PokemonSystem&.only_speedup_battles == 1) ? 1 : TurboConfig::SPEED_STAGES[$GameSpeed]
    
    scroll_mult = (uptime_now - @fog_scroll_last_update_timer) * 5 * speedup_mult
    @fog_ox -= @fog_sx * scroll_mult
    @fog_oy -= @fog_sy * scroll_mult
    @fog_scroll_last_update_timer = uptime_now
  end
end

# Fix para evitar crasheos en animaciones de batalla por el cambio de tiempo
class SpriteAnimation
  def update_animation
    new_index = ((System.uptime - @_animation_timer_start) / @_animation_time_per_frame).to_i
    if new_index >= @_animation_duration
      dispose_animation
      return
    end
    quick_update = (@_animation_index == new_index)
    @_animation_index = new_index
    frame_index = @_animation_index
    current_frame = @_animation.frames[frame_index]
    unless current_frame
      dispose_animation
      return
    end
    cell_data   = current_frame.cell_data
    position    = @_animation.position
    animation_set_sprites(@_animation_sprites, cell_data, position, quick_update)
    return if quick_update
    @_animation.timings.each do |timing|
      next if timing.frame != frame_index
      animation_process_timing(timing, @_animation_hit)
    end
  end
end

#===============================================================================
# 6. Fixes de Estabilidad
#===============================================================================
alias :original_pbBattleOnStepTaken :pbBattleOnStepTaken
def pbBattleOnStepTaken(repel_active)
  return if $game_temp.in_battle
  original_pbBattleOnStepTaken(repel_active)
end

class Game_Event < Game_Character
  def pbResetInterpreterWaitCount
    @interpreter.pbRefreshWaitCount if @interpreter
  end
end  

class Interpreter
  def pbRefreshWaitCount
    @wait_count = 0
    @wait_start = System.uptime
    @wait_start_real = System.unscaled_uptime
  end
  
  # Override del comando Wait para usar tiempo REAL
  # Esto evita que el wait termine antes que los fades de Graphics
  alias turbo_original_command_106 command_106
  def command_106
    @wait_count = @parameters[0] / 20.0
    @wait_start = System.uptime
    @wait_start_real = System.unscaled_uptime  # Guardar tiempo real también
    return true
  end
end

# Parche para que el Interpreter verifique el wait con tiempo REAL
class Interpreter
  alias turbo_original_update update unless method_defined?(:turbo_original_update)
  
  def update
    # Si hay un wait activo, verificar con tiempo REAL
    if @wait_count && @wait_count > 0 && @wait_start_real
      # Usar tiempo real para el wait
      real_elapsed = System.unscaled_uptime - @wait_start_real
      if real_elapsed < @wait_count
        # Actualizar @wait_start para que el check original también funcione
        # cuando el wait termine
        return
      else
        @wait_count = 0
        @wait_start = nil
        @wait_start_real = nil
      end
    end
    turbo_original_update
  end
end

# También parchar Game_Character para que sus waits usen tiempo real
class Game_Character
  alias turbo_original_update_command update_command unless method_defined?(:turbo_original_update_command)
  
  def update_command
    # Si hay un wait activo, verificar con tiempo real en lugar de tiempo escalado
    if @wait_count && @wait_count > 0
      # Inicializar wait_start_real si no existe
      @wait_start_real ||= System.unscaled_uptime
      
      # Verificar con tiempo real
      real_elapsed = System.unscaled_uptime - @wait_start_real
      if real_elapsed < @wait_count
        return  # El wait no ha terminado (en tiempo real)
      end
      
      # El wait terminó - limpiar
      @wait_count = 0
      @wait_start = nil
      @wait_start_real = nil
    end
    
    # Llamar al método original con @wait_count en 0
    # para que no vuelva a verificar el wait (ya lo hicimos)
    turbo_original_update_command
    
    # Si el original estableció un nuevo wait, inicializar el tiempo real
    if @wait_count && @wait_count > 0 && !@wait_start_real
      @wait_start_real = System.unscaled_uptime
    end
  end
end  

class Window_AdvancedTextPokemon < SpriteWindow_Base
  def pbResetWaitCounter
    @wait_timer_start = nil
    @waitcount = 0
    @display_last_updated = nil
  end  
end  

# Variable global para rastrear la ventana de mensaje activa
$CurrentMsgWindow = nil;
def pbMessage(message, commands = nil, cmdIfCancel = 0, skin = nil, defaultCmd = 0, &block)
  ret = 0
  msgwindow = pbCreateMessageWindow(nil, skin)
  $CurrentMsgWindow = msgwindow

  if commands
    ret = pbMessageDisplay(msgwindow, message, true,
                           proc { |msgwndw|
                             next Kernel.pbShowCommands(msgwndw, commands, cmdIfCancel, defaultCmd, &block)
                           }, &block)
  else
    pbMessageDisplay(msgwindow, message, &block)
  end
  pbDisposeMessageWindow(msgwindow)
  $CurrentMsgWindow = nil
  Input.update
  return ret
end

#===============================================================================
# 7. Icono del Turbo.
#===============================================================================
module Graphics
  class << self
    alias _old_update_turbo update
    
    def update
      _old_update_turbo
      $buttonframes = TurboConfig::ICON_DURATION if !$buttonframes
      
      # Mostrar icono si el contador está activo
      if $buttonframes < TurboConfig::ICON_DURATION
        if !@boton_turbo || @boton_turbo.disposed?
          @boton_turbo = Sprite.new
          @boton_turbo.z = 999999
          @boton_turbo.x = 8
          @boton_turbo.y = 8
          set_turbo_bitmap
        elsif @boton_turbo
          set_turbo_bitmap
        end
        
        $buttonframes += 1
        if $buttonframes >= TurboConfig::ICON_DURATION
          @boton_turbo.dispose
        end
      end
    end

    # Helper para cargar la imagen correcta
    def set_turbo_bitmap
      bmp_name = "Graphics/Pictures/Turbo#{$GameSpeed}"
      return if @last_turbo_speed == $GameSpeed && @boton_turbo.bitmap
      
      if defined?(pbResolveBitmap) && pbResolveBitmap(bmp_name)
        @boton_turbo.bitmap = Bitmap.new(bmp_name)
      else
        # Fallback
        @boton_turbo.bitmap = Bitmap.new(32, 32) unless @boton_turbo.bitmap
      end
      
      @last_turbo_speed = $GameSpeed
    end
  end
end

#===============================================================================
# 8. Fix de Colisiones
#===============================================================================

# Asegura que al cambiar de mapa, el jugador vuelva a tener colisiones.
EventHandlers.add(:on_enter_map, :fix_turbo_collision, proc { |_map_id|
  # Solo forzamos la colisión si NO estamos presionando CTRL en modo Debug.
  unless $DEBUG && Input.press?(Input::CTRL)
    if $game_player
      # Verificar si el jugador tiene through activado
      if $game_player.through
        player_x = $game_player.x
        player_y = $game_player.y
        
        # Verificar si la posición actual será transitable después de desactivar through
        unless $game_player.passable?(player_x, player_y, 0)
          # Buscar la posición transitable más cercana
          passable_x, passable_y = $game_player.find_nearest_passable_spot(player_x, player_y)
          if passable_x && passable_y
            $game_player.moveto(passable_x, passable_y)
            $game_player.through = false
          end
        else
          $game_player.through = false
        end
      end
      $game_player.always_on_top = false
    end
  end
})

#===============================================================================
# 9. Fix de Fades
#===============================================================================
# Los fades deben usar tiempo REAL para que su duración visual sea consistente
# independientemente de la velocidad del turbo.

# Función auxiliar para lerp con tiempo real (no escalado)
def turbo_real_lerp(start_val, end_val, duration, timer_start_real)
  now_real = System.unscaled_uptime
  elapsed = now_real - timer_start_real
  return end_val if elapsed >= duration
  return start_val + (end_val - start_val) * (elapsed / duration)
end

# Reemplazar pbFadeOutIn para usar tiempo real
alias turbo_original_pbFadeOutIn pbFadeOutIn
def pbFadeOutIn(z = 99999, nofadeout = false)
  duration = 0.4   # En segundos REALES
  col = Color.new(0, 0, 0, 0)
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = z
  timer_start_real = System.unscaled_uptime
  loop do
    col.set(0, 0, 0, turbo_real_lerp(0, 255, duration, timer_start_real))
    viewport.color = col
    Graphics.update
    Input.update
    break if col.alpha == 255
  end
  pbPushFade
  begin
    val = 0
    val = yield if block_given?
    nofadeout = true if val == 99999
  ensure
    pbPopFade
    if !nofadeout
      timer_start_real = System.unscaled_uptime
      loop do
        col.set(0, 0, 0, turbo_real_lerp(255, 0, duration, timer_start_real))
        viewport.color = col
        Graphics.update
        Input.update
        break if col.alpha == 0
      end
    end
    viewport.dispose
  end
end

# Reemplazar pbFadeOutAndHide para usar tiempo real
alias turbo_original_pbFadeOutAndHide pbFadeOutAndHide
def pbFadeOutAndHide(sprites)
  duration = 0.4   # En segundos REALES
  col = Color.new(0, 0, 0, 0)
  visiblesprites = {}
  pbDeactivateWindows(sprites) do
    timer_start_real = System.unscaled_uptime
    loop do
      col.alpha = turbo_real_lerp(0, 255, duration, timer_start_real)
      pbSetSpritesToColor(sprites, col)
      (block_given?) ? yield : pbUpdateSpriteHash(sprites)
      break if col.alpha == 255
    end
  end
  sprites.each do |i|
    next if !i[1]
    next if pbDisposed?(i[1])
    visiblesprites[i[0]] = true if i[1].visible
    i[1].visible = false
  end
  return visiblesprites
end

# Reemplazar pbFadeInAndShow para usar tiempo real
alias turbo_original_pbFadeInAndShow pbFadeInAndShow
def pbFadeInAndShow(sprites, visiblesprites = nil)
  duration = 0.4   # En segundos REALES
  col = Color.new(0, 0, 0, 0)
  if visiblesprites
    visiblesprites.each do |i|
      if i[1] && sprites[i[0]] && !pbDisposed?(sprites[i[0]])
        sprites[i[0]].visible = true
      end
    end
  end
  pbDeactivateWindows(sprites) do
    timer_start_real = System.unscaled_uptime
    loop do
      col.alpha = turbo_real_lerp(255, 0, duration, timer_start_real)
      pbSetSpritesToColor(sprites, col)
      (block_given?) ? yield : pbUpdateSpriteHash(sprites)
      break if col.alpha == 0
    end
  end
end

# Reemplazar pbFadeOutInWithUpdate para usar tiempo real
alias turbo_original_pbFadeOutInWithUpdate pbFadeOutInWithUpdate
def pbFadeOutInWithUpdate(sprites, z = 99999, nofadeout = false)
  duration = 0.4   # En segundos REALES
  col = Color.new(0, 0, 0, 0)
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = z
  timer_start_real = System.unscaled_uptime
  loop do
    col.set(0, 0, 0, turbo_real_lerp(0, 255, duration, timer_start_real))
    viewport.color = col
    pbUpdateSpriteHash(sprites)
    Graphics.update
    Input.update
    break if col.alpha == 255
  end
  pbPushFade
  begin
    yield if block_given?
  ensure
    pbPopFade
    if !nofadeout
      timer_start_real = System.unscaled_uptime
      loop do
        col.set(0, 0, 0, turbo_real_lerp(255, 0, duration, timer_start_real))
        viewport.color = col
        pbUpdateSpriteHash(sprites)
        Graphics.update
        Input.update
        break if col.alpha == 0
      end
    end
    viewport.dispose
  end
end