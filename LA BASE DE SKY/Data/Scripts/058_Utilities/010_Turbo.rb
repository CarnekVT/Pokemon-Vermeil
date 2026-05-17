#===============================================================================
# TURBO V21.1
#===============================================================================

#===============================================================================
# 1. Configuración.
#===============================================================================
module TurboConfig
  # Velocidades: [Normal, x1.5, x2.0]
  SPEED_STAGES = [1.0, 1.5, 2.0]

  # Teclas para activar (al pulsar avanzan al siguiente nivel).
  TOGGLE_KEYS = [Input::ALT, Input::AUX1]

  # Duración del icono en pantalla (frames)
  ICON_DURATION = 150

  # Duración real (en segundos) de los fades. NO se acelera con el turbo.
  REAL_FADE_DURATION = 0.4

  # Helper: multiplicador actual del turbo, con clamping defensivo por si
  # $GameSpeed se sale de rango (cambios en caliente, saves antiguos, etc.).
  def self.multiplier
    idx = $GameSpeed || 0
    idx = 0 if idx < 0 || idx >= SPEED_STAGES.size
    return SPEED_STAGES[idx]
  end
end

# API pública para usar desde otros scripts/eventos.
module Turbo
  module_function

  # ¿Está el turbo actualmente acelerando el juego?
  def active?
    TurboConfig.multiplier > 1.0
  end

  # Multiplicador de velocidad actual (1.0, 1.5, 2.0…).
  def multiplier
    TurboConfig.multiplier
  end

  # Índice actual de velocidad.
  def speed
    $GameSpeed || 0
  end

  # Fuerza la velocidad a un índice concreto, ajustando $SpeedDifference
  # para que System.uptime sea continuo.
  def set_speed(idx)
    idx = 0 if idx < 0 || idx >= TurboConfig::SPEED_STAGES.size
    real_now = System.unscaled_uptime
    virtual_now = System.uptime
    $GameSpeed = idx
    $SpeedDifference = virtual_now - (real_now * TurboConfig.multiplier)
    $RefreshEventsForTurbo = true
    $buttonframes = 0
  end

  # Reinicia el turbo a velocidad normal (útil al cargar partidas o al
  # detectar estados inconsistentes).
  def reset!
    set_speed(0)
  end
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
    return (unscaled_uptime * TurboConfig.multiplier) + $SpeedDifference
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
      # Avanzar al siguiente nivel de velocidad.
      new_idx = ($GameSpeed || 0) + 1
      new_idx = 0 if new_idx >= TurboConfig::SPEED_STAGES.size
      Turbo.set_speed(new_idx)
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
    # Al cargar, partir siempre de velocidad normal para evitar arrastrar
    # estados raros entre partidas (saves antiguos, índices fuera de rango).
    Turbo.reset!
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
    Turbo.set_speed(TurboConfig::SPEED_STAGES.size - 1)
  end
})

EventHandlers.add(:on_end_battle, :stop_speedup, proc {
  if $PokemonSystem&.only_speedup_battles == 1
    Turbo.reset!
    $CanToggle = false
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
    # Si se activó el turbo, sólo refrescamos el contador de la ventana de
    # mensajes (que usa su propio timing). NO tocamos los waits de los
    # eventos: System.uptime ya es continuo entre cambios de velocidad
    # gracias a $SpeedDifference, así que los waits siguen funcionando
    # correctamente y, al usar tiempo escalado, se aceleran con el turbo.
    #
    # (Resetear los waits de TODOS los eventos al cambiar de velocidad
    # provocaba que eventos paralelos con Set Move Route en curso se
    # reiniciaran y desplazaran al evento poco a poco.)
    if $RefreshEventsForTurbo
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
    # Si el turbo SOLO se aplica en batalla, fuera de batalla la niebla
    # mantiene su velocidad real; si no, escala con el turbo.
    speedup_mult = ($PokemonSystem&.only_speedup_battles == 1) ? 1 : TurboConfig.multiplier

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

#-------------------------------------------------------------------------------
# Game_Screen: tone / flash / shake usan System.uptime (escalado por turbo) en
# lugar de $stats.play_time (tiempo real).
#
# Con la implementación original, los `Change Screen Color Tone`, `Flash` y
# `Shake` mantenían su duración en tiempo real, pero los `Wait` del intérprete
# se aceleran con el turbo. Eso descoordinaba ambas cosas: el Wait que
# venía después de un Change Tone terminaba antes de que el tono hubiera
# acabado de aplicarse, y se veía el mapa "a medio oscurecer" un instante
# antes de la transición.
#
# Aquí hacemos que estos efectos también usen el reloj escalado, así su
# duración va sincronizada con los Wait del evento.
#-------------------------------------------------------------------------------
class Game_Screen
  def start_tone_change(tone, duration)
    if duration == 0
      @tone = tone.clone
      return
    end
    @tone_initial     = @tone.clone
    @tone_target      = tone.clone
    @tone_duration    = duration / 20.0
    @tone_timer_start = System.uptime
  end

  def start_flash(color, duration)
    @flash_color         = color.clone
    @flash_initial_alpha = @flash_color.alpha
    @flash_duration      = duration / 20.0
    @flash_timer_start   = System.uptime
  end

  def start_shake(power, speed, duration)
    @shake_power       = power
    @shake_speed       = speed
    @shake_duration    = duration / 20.0
    @shake_timer_start = System.uptime
  end

  alias_method :turbo_original_update_screen, :update unless method_defined?(:turbo_original_update_screen)
  def update
    # Sustituimos $stats.play_time por System.uptime usando una variable
    # local "now" antes de delegar al método original, pero como el método
    # original usa $stats.play_time directamente, reescribimos la parte de
    # tone/flash/shake aquí.
    now = System.uptime
    if @tone_timer_start
      @tone.red = lerp(@tone_initial.red, @tone_target.red, @tone_duration, @tone_timer_start, now)
      @tone.green = lerp(@tone_initial.green, @tone_target.green, @tone_duration, @tone_timer_start, now)
      @tone.blue = lerp(@tone_initial.blue, @tone_target.blue, @tone_duration, @tone_timer_start, now)
      @tone.gray = lerp(@tone_initial.gray, @tone_target.gray, @tone_duration, @tone_timer_start, now)
      if now - @tone_timer_start >= @tone_duration
        @tone_initial = nil
        @tone_timer_start = nil
      end
    end
    if @flash_timer_start
      @flash_color.alpha = lerp(@flash_initial_alpha, 0, @flash_duration, @flash_timer_start, now)
      if now - @flash_timer_start >= @flash_duration
        @flash_initial_alpha = nil
        @flash_timer_start = nil
      end
    end
    if @shake_timer_start
      delta_t = now - @shake_timer_start
      movement_per_second = @shake_power * @shake_speed * 4
      limit = @shake_power * 2.5
      phase = (delta_t * movement_per_second / limit).to_i % 4
      case phase
      when 0, 2
        @shake = (movement_per_second * delta_t) % limit
        @shake *= -1 if phase == 2
      else
        @shake = limit - ((movement_per_second * delta_t) % limit)
        @shake *= -1 if phase == 3
      end
      if delta_t >= @shake_duration
        @shake_phase = phase if !@shake_phase || phase == 1 || phase == 3
        if phase != @shake_phase || @shake < 2
          @shake_timer_start = nil
          @shake = 0
        end
      end
    end
    # Pictures y weather los seguimos delegando al original (no usan
    # $stats.play_time para sus duraciones críticas).
    if $game_temp.in_battle
      (51..100).each { |i| @pictures[i].update }
    else
      (1..50).each { |i|  @pictures[i].update }
    end
  end
end

#===============================================================================
# 6. Fixes de Estabilidad
#===============================================================================
# Guarda contra recargas en caliente: si ya está aliasado, no volver a hacerlo
# (provocaría recursión infinita).
unless defined?(turbo_original_pbBattleOnStepTaken)
  alias turbo_original_pbBattleOnStepTaken pbBattleOnStepTaken
  def pbBattleOnStepTaken(repel_active)
    return if $game_temp.in_battle
    turbo_original_pbBattleOnStepTaken(repel_active)
  end
end

class Game_Event < Game_Character
  def pbResetInterpreterWaitCount
    # Defensa: si el evento está ejecutando un move route forzado, NO tocamos
    # su intérprete. Resetear el wait en mitad de un Set Move Route hace que
    # el evento paralelo que lo lanzó vuelva a relanzarlo desde la posición
    # actual del evento (bug del puño desplazándose al pulsar turbo).
    return if @move_route_forcing
    @interpreter.pbRefreshWaitCount if @interpreter
  end
end

class Interpreter
  def pbRefreshWaitCount
    @wait_count = 0
    @wait_start = System.uptime
  end
end

# Nota: no se sobrescriben command_106 (Wait), Interpreter#update ni
# Game_Character#update_command. La implementación original de Essentials usa
# `System.uptime`, que aquí está escalado por el turbo, así que los Waits ya
# se aceleran automáticamente con la velocidad. Forzarlos a tiempo real (como
# hacían los parches anteriores) hacía que los Waits NO se acelerasen.
#
# Para los fades y otros elementos que necesitan tiempo real (no acelerable),
# se usa explícitamente `System.unscaled_uptime` en sus implementaciones más
# abajo (sección 9. Fix de Fades).

class Window_AdvancedTextPokemon < SpriteWindow_Base
  def pbResetWaitCounter
    @wait_timer_start = nil
    @waitcount = 0
    @display_last_updated = nil
  end  
end  

# Variable global para rastrear la ventana de mensaje activa.
# Se aliasan pbCreateMessageWindow / pbDisposeMessageWindow (en lugar de
# reescribir pbMessage entero) para no pisar a otros plugins, y se usa una
# pila para soportar mensajes anidados sin que $CurrentMsgWindow quede a nil
# antes de tiempo.
$CurrentMsgWindow = nil
$_TurboMsgWindowStack ||= []

class Object
  unless private_method_defined?(:turbo_original_pbCreateMessageWindow)
    alias_method :turbo_original_pbCreateMessageWindow, :pbCreateMessageWindow
    private :turbo_original_pbCreateMessageWindow
  end

  def pbCreateMessageWindow(*args)
    window = turbo_original_pbCreateMessageWindow(*args)
    $_TurboMsgWindowStack.push($CurrentMsgWindow)
    $CurrentMsgWindow = window
    window
  end
  private :pbCreateMessageWindow

  unless private_method_defined?(:turbo_original_pbDisposeMessageWindow)
    alias_method :turbo_original_pbDisposeMessageWindow, :pbDisposeMessageWindow
    private :turbo_original_pbDisposeMessageWindow
  end

  def pbDisposeMessageWindow(*args)
    turbo_original_pbDisposeMessageWindow(*args)
    $CurrentMsgWindow = $_TurboMsgWindowStack.pop
  end
  private :pbDisposeMessageWindow
end

#===============================================================================
# 7. Icono del Turbo.
#===============================================================================
module Graphics
  class << self
    unless method_defined?(:_old_update_turbo)
      alias _old_update_turbo update
    end

    def update
      _old_update_turbo
      $buttonframes = TurboConfig::ICON_DURATION if !$buttonframes

      # Mostrar icono si el contador está activo.
      if $buttonframes < TurboConfig::ICON_DURATION
        if !@boton_turbo || @boton_turbo.disposed?
          @boton_turbo = Sprite.new
          @boton_turbo.z = 999999
          @boton_turbo.x = 8
          @boton_turbo.y = 8
          @last_turbo_speed = nil   # Forzar carga del bitmap.
        end
        set_turbo_bitmap

        $buttonframes += 1
        if $buttonframes >= TurboConfig::ICON_DURATION
          # Limpieza completa al ocultar el icono (evita fuga de memoria).
          @boton_turbo.bitmap.dispose if @boton_turbo.bitmap && !@boton_turbo.bitmap.disposed?
          @boton_turbo.dispose
          @boton_turbo = nil
          @last_turbo_speed = nil
        end
      end
    end

    # Helper para cargar la imagen correcta. Dispone del bitmap previo si lo
    # hubiera para evitar fugas de memoria al cambiar de velocidad.
    def set_turbo_bitmap
      return if @last_turbo_speed == $GameSpeed
      bmp_name = "Graphics/Pictures/Turbo#{$GameSpeed}"
      old_bmp = @boton_turbo.bitmap
      if defined?(pbResolveBitmap) && pbResolveBitmap(bmp_name)
        @boton_turbo.bitmap = Bitmap.new(bmp_name)
      elsif !@boton_turbo.bitmap
        # Fallback solo la primera vez (placeholder transparente).
        @boton_turbo.bitmap = Bitmap.new(32, 32)
      end
      old_bmp.dispose if old_bmp && old_bmp != @boton_turbo.bitmap && !old_bmp.disposed?
      @last_turbo_speed = $GameSpeed
    end
  end
end

#===============================================================================
# 8. Fix de Colisiones (defensa contra estados rotos)
#===============================================================================
# Si por alguna razón al cambiar de mapa el jugador queda con `through = true`
# o `always_on_top = true` y NO viene de una transición legítima (cinemática,
# evento), restaurarlo. Esto es una red de seguridad ante crashes/exceptions
# que puedan dejar al jugador en estado inconsistente. Sólo actúa si el
# jugador NO está dentro de un evento ni de una ruta forzada.
EventHandlers.add(:on_enter_map, :fix_turbo_collision, proc { |_map_id|
  next unless $game_player
  next if pbMapInterpreterRunning?
  next if $game_player.move_route_forcing
  next if $DEBUG && Input.press?(Input::CTRL)

  if $game_player.through
    if $game_player.passable?($game_player.x, $game_player.y, 0)
      $game_player.through = false
    elsif $game_player.respond_to?(:find_nearest_passable_spot)
      passable_x, passable_y = $game_player.find_nearest_passable_spot($game_player.x, $game_player.y)
      if passable_x && passable_y
        $game_player.moveto(passable_x, passable_y)
        $game_player.through = false
      end
    end
  end
  $game_player.always_on_top = false if $game_player.always_on_top
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

# Reemplazar pbFadeOutIn para usar tiempo real (idempotente).
alias turbo_original_pbFadeOutIn pbFadeOutIn unless defined?(turbo_original_pbFadeOutIn)
def pbFadeOutIn(z = 99999, nofadeout = false)
  duration = TurboConfig::REAL_FADE_DURATION   # Segundos REALES
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

# Reemplazar pbFadeOutAndHide para usar tiempo real (idempotente).
alias turbo_original_pbFadeOutAndHide pbFadeOutAndHide unless defined?(turbo_original_pbFadeOutAndHide)
def pbFadeOutAndHide(sprites)
  duration = TurboConfig::REAL_FADE_DURATION   # Segundos REALES
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

# Reemplazar pbFadeInAndShow para usar tiempo real (idempotente).
alias turbo_original_pbFadeInAndShow pbFadeInAndShow unless defined?(turbo_original_pbFadeInAndShow)
def pbFadeInAndShow(sprites, visiblesprites = nil)
  duration = TurboConfig::REAL_FADE_DURATION   # Segundos REALES
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

# Reemplazar pbFadeOutInWithUpdate para usar tiempo real (idempotente).
alias turbo_original_pbFadeOutInWithUpdate pbFadeOutInWithUpdate unless defined?(turbo_original_pbFadeOutInWithUpdate)
def pbFadeOutInWithUpdate(sprites, z = 99999, nofadeout = false)
  duration = TurboConfig::REAL_FADE_DURATION   # Segundos REALES
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