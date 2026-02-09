#===============================================================================
# Item: Sleeping Bag (Saco de Dormir)
# Requiere: [FL] Unreal Time System
#===============================================================================

ItemHandlers::UseInField.add(:SLEEPINGBAG, proc { |item|
  # Verificar si Unreal Time está activo
  if !defined?(UnrealTime) || !UnrealTime::ENABLED
    pbMessage(_INTL("You can't use this right now."))
    next false
  end

  commands = [
    _INTL("Morning (06:00)"),
    _INTL("Day (12:00)"),
    _INTL("Afternoon (16:00)"),
    _INTL("Evening (19:00)"),
    _INTL("Night (22:00)"),
    _INTL("Cancel")
  ]
  
  choice = pbMessage(_INTL("Until when do you want to rest?"), commands, -1)
  
  if choice >= 0 && choice < 5
    pbFadeOutIn do
      # Sonido de curación/descanso
      pbMEPlay("Pkmn healing")
      pbWait(1)
      
      case choice
      when 0 then UnrealTime.advance_to(6)  # Mañana
      when 1 then UnrealTime.advance_to(12) # Día
      when 2 then UnrealTime.advance_to(16) # Tarde
      when 3 then UnrealTime.advance_to(19) # Ocaso
      when 4 then UnrealTime.advance_to(22) # Noche
      end
      PBDayNight.instance_variable_set(:@dayNightToneLastUpdate, nil)
      PBDayNight.instance_variable_set(:@cachedTone, nil)
      $scene.update if $scene.is_a?(Scene_Map)
    end
    pbMessage(_INTL("You rested until the selected time."))
    next true
  end
  next false
})