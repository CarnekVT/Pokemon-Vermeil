#===============================================================================
# Battle Popup Messages - Shows effectiveness, critical hits etc. as
# graphics on the Pokémon instead of in the normal text box
#===============================================================================

# Add setting to PokemonSystem
class PokemonSystem
  attr_accessor :dynamic_combat

  alias dynamic_initialize initialize
  def initialize
    dynamic_initialize
    @dynamic_combat = 1  # Default to on
  end

  def dynamic_combat
    return @dynamic_combat || 1
  end

  def dynamic_combat=(value)
    @dynamic_combat = value || 1
  end
end

# Add to options menu
MenuHandlers.add(:options_menu, :dynamic_combat, {
  "name"        => _INTL("Combate Dinámico"),
  "order"       => 36,
  "type"        => EnumOption,
  "parameters"  => [_INTL("No"), _INTL("Sí")],
  "description" => _INTL("Activa/desactiva los pop-ups y animaciones dinámicas en combate."),
  "get_proc"    => proc { next $PokemonSystem.dynamic_combat },
  "set_proc"    => proc { |value, _scene| $PokemonSystem.dynamic_combat = value }
})

module BattlePopupMessages
  # Settings
  POPUP_DURATION = 30        # Duración del popup en frames (30 = 0.75 segundos a 40fps).
  FADE_DURATION = 15         # Duración del desvanecimiento.
  # Individual toggles now depend on dynamic_combat setting
  def self.show_popups?
    return $PokemonSystem.dynamic_combat == 1
  end
  
  # Paths to the graphics
  GRAPHICS_PATH = "Graphics/UI/Battle/Pop Up/animations/zv-battle-messages/popup-messages/"
  
  GRAPHIC_SUPER_EFFECTIVE = GRAPHICS_PATH + "super-effective"
  GRAPHIC_NOT_EFFECTIVE = GRAPHICS_PATH + "not-very-effective"
  GRAPHIC_CRITICAL = GRAPHICS_PATH + "critical-hit"
  GRAPHIC_NO_EFFECT = GRAPHICS_PATH + "no-effect"
  GRAPHIC_DODGED = GRAPHICS_PATH + "miss"
  GRAPHIC_STAT_CHANGE = GRAPHICS_PATH + "stat-change"
  
  # Stat abbreviations (like in Summary Screen)
  STAT_NAMES = {
    :ATTACK => "Ataque",
    :DEFENSE => "Defensa",
    :SPECIAL_ATTACK => "Ataque Esp.",
    :SPECIAL_DEFENSE => "Defensa Esp.",
    :SPEED => "Velocidad",
    :ACCURACY => "Presición",
    :EVASION => "Evasión"
  }
end

#===============================================================================
# Popup Sprite Class - Shows graphics instead of text
#===============================================================================
class BattlePopupSprite < Sprite
  attr_accessor :timer
  
  def initialize(x, y, graphic_path, viewport, text_overlay = nil, start_delay = 0)
    super(viewport)
    @timer = BattlePopupMessages::POPUP_DURATION
    @fade_start = @timer - BattlePopupMessages::FADE_DURATION
    @start_delay = start_delay
    
    # --- INICIO DE LA MODIFICACIÓN: Tamaño de popup consistente ---
    # Crear un bitmap base de tamaño fijo para todos los popups.
    if graphic_path
      bitmap = Bitmap.new(160, 42) # Ancho y alto fijos para popups con gráfico.
    else
      bitmap = Bitmap.new(300, 60) # Ancho y alto para popups de solo texto (daño).
    end
    begin
      if graphic_path
        # Cargar la imagen del cartel y dibujarla centrada en el bitmap base.
        graphic_bitmap = AnimatedBitmap.new(graphic_path)
        x_pos = (bitmap.width - graphic_bitmap.width) / 2
        y_pos = (bitmap.height - graphic_bitmap.height) / 2
        bitmap.blt(x_pos, y_pos, graphic_bitmap.bitmap, graphic_bitmap.bitmap.rect)
        graphic_bitmap.dispose
      end

      # Wenn Text-Overlay vorhanden (für Stat-Changes), zeichne ihn drauf
      if text_overlay
        text = text_overlay.to_s
        if text_overlay.include?("|")
          dmg, maxhp = text_overlay.split("|").map(&:to_i)
          text = dmg.to_s
          if dmg <= 25
            main_color = Color.new(100, 100, 100, 255)  # Leve
          elsif dmg <= 60
            main_color = Color.new(255, 255, 255, 255)  # Normal
          elsif dmg <= 120
            main_color = Color.new(255, 255, 0, 255)    # Fuerte
          else
            main_color = Color.new(255, 0, 0, 255)      # Grave
          end
        else
          main_color = Color.new(255, 255, 255, 255)
        end

        if graphic_path
          pbSetSystemFont(bitmap)
          bitmap.font.size = 12   # Tamaño de fuente reducido a 12
          bitmap.font.bold = true # Texto en negrita para mejor legibilidad
          text_x = 0
          text_y = (bitmap.height / 2)  # Ajuste vertical para centrar mejor
          text_width = bitmap.width - 4     # Un poco de margen
          text_height = 40
        else
          pbSetSystemFont(bitmap)
          bitmap.font.size = 32 # Tamaño de fuente para solo texto
          bitmap.font.bold = true
          text_x = 0
          text_y = 0
          text_width = bitmap.width
          text_height = bitmap.height
        end

        # Shadow/Outline (schwarz) - für bessere Lesbarkeit
        [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]].each do |offset|
          bitmap.font.color = Color.new(0, 0, 0, 255)
          bitmap.draw_text(text_x + offset[0], text_y + offset[1], text_width, text_height, text, 1)
        end

        # Haupttext
        bitmap.font.color = main_color
        bitmap.draw_text(text_x, text_y, text_width, text_height, text, 1)
      end
      
    rescue => e
      # Fallback: Create simple text bitmap if graphic not found
      puts "Battle Popup: Graphic not found: #{graphic_path}"
      puts "Error: #{e.message}"
      pbSetSystemFont(bitmap)
      bitmap.font.color = Color.new(255, 255, 255)
      bitmap.font.size = 20
      bitmap.draw_text(0, 0, 200, 50, text_overlay || "Graphic missing!", 1)
    end
    self.bitmap = bitmap
    # --- FIN DE LA MODIFICACIÓN ---

    if graphic_path
      self.zoom_x = 1.5 # Tamaño ajustado a 1.5x
      self.zoom_y = 1.5 # Tamaño ajustado a 1.5x
      @timer = BattlePopupMessages::POPUP_DURATION
      @fade_start = @timer - BattlePopupMessages::FADE_DURATION
    else
      self.zoom_x = 1
      self.zoom_y = 1
      @timer = 60
      @fade_start = 50
    end
    self.x = x
    # --- INICIO DE LA CORRECCIÓN: Centrado Horizontal ---
    self.ox = self.bitmap.width / 2
    # --- FIN DE LA CORRECCIÓN ---
    self.y = y
    self.z = 999
    self.opacity = 255

    # Speichere Startposition für Bewegung
    @start_y = y
  end
  
  def update
    return if disposed?
    super
    if @start_delay > 0
      @start_delay -= 1
      return
    end
    @timer -= 1
    
    # Fade out
    if @timer <= @fade_start
      self.opacity = (@timer.to_f / @fade_start) * 255
      self.y -= 1.5  # Se mueve hacia arriba más rápido durante el desvanecimiento
    else
      self.y -= 1    # Se mueve hacia arriba más rápido
    end
    
    if @timer <= 0
      dispose
    end
  end
  
  def dispose
    self.bitmap&.dispose
    super
  end
end

#===============================================================================
# Battle Scene Extension
#===============================================================================
class Battle::Scene
  alias popup_pbInitSprites pbInitSprites
  def pbInitSprites
    popup_pbInitSprites
    @popupSprites = []
  end
  
  # Load transparent Message Box graphic only when popups are enabled
  alias popup_pbCreateBackdropSprites pbCreateBackdropSprites
  def pbCreateBackdropSprites
    popup_pbCreateBackdropSprites

    if BattlePopupMessages.show_popups?
      # Replace the Message Box with transparent graphic
      if @sprites["messageBox"]
        @sprites["messageBox"].dispose
        @sprites["messageBox"] = nil
      end

      # Load transparent Message Box
      transparentMsgBox = pbAddSprite("messageBox", 0, Graphics.height - 96,
                                       "Graphics/UI/Battle/transparent_message", @viewport)
      transparentMsgBox.z = 195
    end
  end
  
  alias popup_pbEndBattle pbEndBattle
  def pbEndBattle(result)
    @popupSprites.each { |sprite| sprite.dispose if sprite && !sprite.disposed? }
    @popupSprites.clear
    popup_pbEndBattle(result)
  end
  
  alias popup_pbUpdate pbUpdate
  def pbUpdate(cw = nil)
    popup_pbUpdate(cw)
    @popupSprites.each { |sprite| sprite.update if sprite && !sprite.disposed? }
    @popupSprites.delete_if { |sprite| sprite.nil? || sprite.disposed? }
  end
  
  # Shows a popup on the Pokémon (with graphic)
  def pbShowBattlePopup(battlerIndex, graphic_path, text_overlay = nil, start_delay = 0)
    return if !@sprites["pokemon_#{battlerIndex}"]

    # Position of the Pokémon sprite (centered)
    pokemonSprite = @sprites["pokemon_#{battlerIndex}"]

    # Calculate the correct position based on the sprite
    if pokemonSprite && pokemonSprite.bitmap && !pokemonSprite.bitmap.disposed?
      # X is the center of the sprite
      x = pokemonSprite.x
      # Y is above the sprite (use the actual bitmap height)
      spriteHeight = pokemonSprite.bitmap.height
      y = pokemonSprite.y - (spriteHeight * 0.8)
    else
      # Fallback if no sprite present
      x = pokemonSprite.x
      y = pokemonSprite.y - 40
    end

    # Create popup
    popup = BattlePopupSprite.new(x, y, graphic_path, @viewport, text_overlay, start_delay)
    @popupSprites.push(popup)
  end

end
#===============================================================================
# Move Usage Overrides
#===============================================================================
class Battle::Move
  alias popup_pbHitEffectivenessMessages pbHitEffectivenessMessages
  def pbHitEffectivenessMessages(user, target, numTargets = 1)
    return if target.damageState.disguise || target.damageState.iceFace

    # Damage Popup
    if target.damageState.hpLost > 0
      text = "#{target.damageState.hpLost}|#{target.totalhp}"
      @battle.scene.pbShowBattlePopup(target.index, nil, text, 0) if BattlePopupMessages.show_popups?
    end
  
    # Critical Hit Popup
    if target.damageState.critical
      @battle.scene.pbShowBattlePopup(target.index, BattlePopupMessages::GRAPHIC_CRITICAL, nil, 20) if BattlePopupMessages.show_popups?
    end
  
    # Effectiveness Popup
    if target.damageState.hpLost > 0
      if Effectiveness.super_effective?(target.damageState.typeMod)
        @battle.scene.pbShowBattlePopup(target.index, BattlePopupMessages::GRAPHIC_SUPER_EFFECTIVE, nil, 5) if BattlePopupMessages.show_popups?
      elsif Effectiveness.not_very_effective?(target.damageState.typeMod)
        @battle.scene.pbShowBattlePopup(target.index, BattlePopupMessages::GRAPHIC_NOT_EFFECTIVE, nil, 5) if BattlePopupMessages.show_popups?
      end
    end
    # No text box shown
  end

end
#===============================================================================
# Immunity/No Effect Messages
#===============================================================================
class Battle::Battler
  # Este método ya no es necesario, la lógica se centraliza en Battle.pbDisplay
  # para capturar todos los mensajes de "No afecta".
  def pbMoveImmunityHealingAbility(user, move, moveType, immuneType, show_message)
    return super
  end
end

#===============================================================================
# Silence miss/evade text message and add dodge animation
#===============================================================================
class Battle::Move
  # Usamos "prepend" para asegurarnos de que esta versión se ejecute primero
  # y no llame a las versiones que muestran texto.
  def pbMissMessage(user, target)
    if BattlePopupMessages.show_popups?
      # Si el ataque falló (por precisión, etc.)
      @battle.scene.pbShowBattlePopup(target.index, BattlePopupMessages::GRAPHIC_DODGED)
      # Añadimos la animación de esquive al Pokémon objetivo en cualquier caso de fallo/esquive.
      @battle.scene.pbDodgeAnimation(target)
      return true  # Popup shown, suppress text message
    else
      return false  # No popup, show text message
    end
  end
end

#===============================================================================
# Intercepta el mensaje "No afecta a..."
#===============================================================================
class Battle
  alias popup_pbDisplay pbDisplay
  def pbDisplay(msg, brief = false)
    # Comprueba si es un mensaje de "No afecta"
    is_no_effect_msg = msg.is_a?(String) && (msg.include?("doesn't affect") || msg.include?("No afecta a"))

    if is_no_effect_msg && BattlePopupMessages.show_popups?
      # Busca al objetivo de forma más precisa para evitar confusiones con nombres iguales.
      # Se busca al Pokémon cuya descripción contextual (`pbThis`) tenga la coincidencia más larga
      # dentro del mensaje, para evitar ambigüedades con Pokémon de la misma especie.
      best_match = nil
      @battlers.each do |b|
        next if !b || b.fainted?
        best_match = b if msg.include?(b.pbThis(true)) && (!best_match || b.pbThis(true).length > best_match.pbThis(true).length)
      end
      if best_match
        @scene.pbShowBattlePopup(best_match.index, BattlePopupMessages::GRAPHIC_NO_EFFECT)
      end
      return # Suprime el mensaje de texto original SOLO si los popups están activos.
    end
    if method(:popup_pbDisplay).arity == 1
      popup_pbDisplay(msg)
    else
      popup_pbDisplay(msg, brief)
    end
  end

end

#===============================================================================
# Show stat changes
#===============================================================================
module Battle::Battler::BattlePopupsStatMessages
  def pbRaiseStatStage(*args)
    stat = args[0]
    increment = args[1]
    user = args[2]
    showAnim = args[3] || true
    ignoreContrary = args[4] || false
    if BattlePopupMessages.show_popups?
      # Replicate the base logic without displaying text messages
      if hasActiveAbility?(:CONTRARY) && !ignoreContrary && !@battle.moldBreaker
        return pbLowerStatStage(*args)
      end
      increment = pbRaiseStatStageBasic(stat, increment, ignoreContrary)
      return false if increment <= 0
      @battle.pbCommonAnimation("StatUp", self) if showAnim
      if abilityActive?
        Battle::AbilityEffects.triggerOnStatGain(self.ability, self, stat, user)
      end
      return true
    end
    super
  end

  def pbLowerStatStage(*args)
    stat = args[0]
    increment = args[1]
    user = args[2]
    showAnim = args[3] || true
    ignoreContrary = args[4] || false
    mirrorArmorSplash = args[5] || 0
    ignoreMirrorArmor = args[6] || false
    if BattlePopupMessages.show_popups?
      # Replicate the base logic without displaying text messages
      if !@battle.moldBreaker
        if hasActiveAbility?(:CONTRARY) && !ignoreContrary
          return pbRaiseStatStage(stat, increment, user, showAnim, true)
        end
        if hasActiveAbility?(:MIRRORARMOR) && !ignoreMirrorArmor && user && user.index != @index && !statStageAtMin?(stat)
          if mirrorArmorSplash < 2
            @battle.pbShowAbilitySplash(self)
            if !Battle::Scene::USE_ABILITY_SPLASH
              @battle.pbDisplay(_INTL("¡Se ha activado {2} de {1}!", pbThis(true), abilityName))
            end
          end
          ret = false
          if user.pbCanLowerStatStage?(stat, self, nil, true, ignoreContrary, true)
            ret = user.pbLowerStatStage(stat, increment, self, showAnim, ignoreContrary, mirrorArmorSplash + 1, true)
          end
          @battle.pbHideAbilitySplash(self) if mirrorArmorSplash.even?
          return ret
        end
      end
      increment = pbLowerStatStageBasic(stat, increment, ignoreContrary)
      return false if increment <= 0
      @battle.pbCommonAnimation("StatDown", self) if showAnim
      if abilityActive?
        Battle::AbilityEffects.triggerOnStatLoss(self.ability, self, stat, user)
      end
      return true
    end
    super
  end
end

class Battle::Battler
  # Hook für Stat-Erhöhung
  alias popup_pbRaiseStatStageBasic pbRaiseStatStageBasic
  def pbRaiseStatStageBasic(stat, increment, ignoreContrary = false)
    # Save the current stage BEFORE the change
    old_stage = @stages[stat]

    result = popup_pbRaiseStatStageBasic(stat, increment, ignoreContrary)

    # Calculate the actual change
    actual_change = @stages[stat] - old_stage

    if actual_change > 0 && BattlePopupMessages.show_popups?
      # Create text overlay: "Atk +1" or "Sp.Atk +2" etc.
      stat_name = BattlePopupMessages::STAT_NAMES[stat] || GameData::Stat.get(stat).name
      text = "#{stat_name} +#{actual_change}"

      # Show stat-change.png with text overlay
      @battle.scene.pbShowBattlePopup(self.index, BattlePopupMessages::GRAPHIC_STAT_CHANGE, text)
    end

    return result
  end

  # Hook für Stat-Senkung
  alias popup_pbLowerStatStageBasic pbLowerStatStageBasic
  def pbLowerStatStageBasic(stat, increment, ignoreContrary = false)
    # Save the current stage BEFORE the change
    old_stage = @stages[stat]

    result = popup_pbLowerStatStageBasic(stat, increment, ignoreContrary)

    # Calculate the actual change (absolute value)
    actual_change = old_stage - @stages[stat]

    if actual_change > 0 && BattlePopupMessages.show_popups?
      # Create text overlay: "Atk -1" or "Speed -2" etc.
      stat_name = BattlePopupMessages::STAT_NAMES[stat] || GameData::Stat.get(stat).name
      text = "#{stat_name} -#{actual_change}"

      # Show stat-change.png with text overlay
      @battle.scene.pbShowBattlePopup(self.index, BattlePopupMessages::GRAPHIC_STAT_CHANGE, text)
    end

    return result
  end

end

#===============================================================================
# Optional configuration via Debug Menu
#===============================================================================
MenuHandlers.add(:debug_menu, :toggle_battle_popups, {
  "name"        => _INTL("Battle Popup Messages"),
  "parent"      => :deluxe_plugins_menu,
  "description" => _INTL("Turn Battle Popup Messages on/off."),
  "effect"      => proc {
    if !defined?(BattlePopupMessages.show_popups?)
      pbMessage(_INTL("The Battle Popup Messages plugin is not loaded."))
      next
    end

    cmds = []
    cmds.push(_INTL("Dynamic Combat: {1}", BattlePopupMessages.show_popups? ? "ON" : "OFF"))
    cmds.push(_INTL("Back"))

    cmd = pbMessage(_INTL("Toggle dynamic combat popups?"), cmds, -1, nil, 0)
    if cmd == 0
      $PokemonSystem.dynamic_combat = ($PokemonSystem.dynamic_combat == 1) ? 0 : 1
    end
  }
})

#===============================================================================
# Silence stat change text message
#===============================================================================
module Battle::Scene::BattlePopupsSilence
  # We modify the method that shows the text message.
  def pbDisplayStatChange(battler, stat, change)
    # If the option to show stat popups is activated, we do nothing.
    # This prevents the original text message from being displayed.
    return if BattlePopupMessages.show_popups?
    # If the option is disabled, we call the original method to show the text.
    super
  end
end

class Battle::Scene
  prepend Battle::Scene::BattlePopupsSilence
end


class Battle::Battler
  prepend Battle::Battler::BattlePopupsStatMessages
end

#===============================================================================
# Silence miss/evade text message
#===============================================================================
class Battle::Scene
  def pbDodgeAnimation(battler)
    # Obtiene el sprite del Pokémon
    pkmnSprite = @sprites["pokemon_#{battler.index}"]
    return if !pkmnSprite

    # Guardamos la posición original del sprite
    original_x = pkmnSprite.x
    original_y = pkmnSprite.y

    # Determinamos la dirección del movimiento basado en el lado del campo
    # Los Pokémon del jugador (índices pares) se mueven a la derecha.
    # Los Pokémon del oponente (índices impares) se mueven a la izquierda.
    movement_x = (battler.index.even?) ? 40 : -40

    # Animación de esquive
    # El sprite se mueve rápidamente hacia un lado y vuelve.
    # Puedes ajustar la duración (el número de frames) para cambiar la velocidad.
    duration = 12 # Duración en frames (más alto = más lento)
    (duration * 2).times do |i|
      # Mover hacia el lado en la primera mitad, volver en la segunda.
      pkmnSprite.x += (i < duration) ? (movement_x.to_f / duration) : -(movement_x.to_f / duration)
      pbUpdate(nil)
    end

    # Asegurarse de que el sprite vuelva a su posición original
    pkmnSprite.x = original_x
    pkmnSprite.y = original_y
  end
end
#===============================================================================
# Silence stat change text message (Part 2)
#===============================================================================
module Battle::Scene::BattlePopupsSilence
  # We modify the method that shows the text message in the scene.
  def pbDisplayStatChange(battler, stat, change)
    # If the option to show stat popups is activated, we do nothing.
    return if BattlePopupMessages.show_popups?
    # If the option is disabled, we call the original method to show the text.
    super
  end
end

class Battle::Scene
  prepend Battle::Scene::BattlePopupsSilence
end
