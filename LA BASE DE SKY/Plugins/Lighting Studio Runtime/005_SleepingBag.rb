# encoding: UTF-8
# Lighting Studio: reusable Sleeping Bag test item for the internal day/night clock.
# GameData::Item :SLEEPINGBAG is defined in PBS/items.txt, compile the PBS once.
module LightingStudioDayNight
  module_function

  def use_sleeping_bag
    cfg=settings
    if cfg['enabled'] != true || cfg['source'] != 'internal'
      pbMessage(_INTL("El saco de dormir solo puede adelantar el reloj cuando el ciclo de día y noche usa un reloj interno."))
      return false
    end
    hour_now=current_hour
    current_minutes=(hour_now*60).round
    h=(current_minutes / 60) % 24
    m=current_minutes % 60
    commands=[
      _INTL("Descansar 1 hora"),
      _INTL("Descansar 6 horas"),
      _INTL("Descansar 12 horas"),
      _INTL("Despertar a las 06:00"),
      _INTL("Despertar a las 12:00"),
      _INTL("Despertar a las 18:00"),
      _INTL("Despertar a las 00:00"),
      _INTL("Cancelar")
    ]
    selected=pbMessage(_INTL("Son las {1}:{2}. ¿Hasta cuándo quieres descansar?",
      format('%02d',h),format('%02d',m)),commands,-1,nil,0)
    return false if selected.nil? || selected<0 || selected>=7
    minutes=case selected
            when 0 then current_minutes+60
            when 1 then current_minutes+360
            when 2 then current_minutes+720
            when 3 then 360
            when 4 then 720
            when 5 then 1080
            when 6 then 0
            end
    minutes %= 1440
    set_internal_time(minutes / 60, minutes % 60)
    pbMessage(_INTL("¡Has descansado! Ahora son las {1}:{2}.",
      format('%02d',minutes/60),format('%02d',minutes%60)))
    true
  end
end

if defined?(ItemHandlers) && defined?(ItemHandlers::UseFromBag) &&
   defined?(ItemHandlers::UseInField)
  ItemHandlers::UseFromBag.add(:SLEEPINGBAG, proc { |item|
    next LightingStudioDayNight.use_sleeping_bag ? 1 : 0
  })
  ItemHandlers::UseInField.add(:SLEEPINGBAG, proc { |item|
    next LightingStudioDayNight.use_sleeping_bag
  })
end
