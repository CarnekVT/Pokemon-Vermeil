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
    now_minutes=(current_hour*60).round % 1440
    now_label=format('%02d:%02d',now_minutes/60,now_minutes%60)
    # Six fixed wake-up presets, rather than relative sleep durations.
    # Edit this small table to adjust the six slots displayed to players.
    slots=[
      [6,0,_INTL("Amanecer")],
      [9,0,_INTL("Mañana")],
      [12,0,_INTL("Mediodía")],
      [15,0,_INTL("Tarde")],
      [18,0,_INTL("Atardecer")],
      [21,0,_INTL("Noche")]
    ]
    commands=slots.map do |h,m,label|
      _INTL("{1} — {2}:{3}",label,format('%02d',h),format('%02d',m))
    end
    commands << _INTL("Cancelar")
    selected=pbMessage(_INTL("Ahora son las {1}. ¿A qué hora quieres despertar?",now_label),
                       commands,-1,nil,0)
    return false if selected.nil? || selected<0 || selected>=slots.length
    hour,minute=slots[selected][0],slots[selected][1]
    minutes=hour*60+minute
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
