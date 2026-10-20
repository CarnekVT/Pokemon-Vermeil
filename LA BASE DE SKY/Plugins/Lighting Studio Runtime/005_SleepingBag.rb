# encoding: UTF-8
# Lighting Studio: event-style Sleeping Bag test item and six fixed time slots.
# Scriptable via LightingStudioDayNight.skip_to_hour(7).
module LightingStudioDayNight
  SLEEPING_BAG_SLOTS = [
    [7,  0, "7 a.m.",  "La frescura de la mañana te invita a explorar."],
    [11, 0, "11 a.m.", "La luz del día ilumina el camino que tienes por delante."],
    [15, 0, "3 p.m.",  "La tarde transcurre tranquila. Es hora de continuar."],
    [17, 0, "5 p.m.",  "El sol comienza a descender sobre el horizonte."],
    [19, 0, "7 p.m.",  "Las primeras luces de la noche acompañan tu camino."],
    [23, 0, "11 p.m.", "La quietud nocturna te permite descansar un momento."]
  ].freeze
  module_function

  def skip_to_hour(hour, minute=0)
    set_internal_time(hour, minute)
  end

  # Time phrase for event scripts, e.g. display text after changing the hour.
  def time_in_text(value=current_hour)
    case value.to_f % 24
    when 5...11 then _INTL("la mañana")
    when 11...17 then _INTL("el día")
    when 17...20 then _INTL("el atardecer")
    else _INTL("la noche")
    end
  end

  def sleep_fade_frames(count)
    count.times do
      Graphics.update
      Input.update if defined?(Input)
    end
  end

  def sleeping_bag_transition(hour,minute)
    # Mirror the supplied Essentials event: 10 frames to white, short wait,
    # change time, play Pokemon Healing ME, 30 frames, 10 frames back,
    # 20 frames before the line of text. A disposable overlay avoids
    # permanently modifying the game's Screen Tone or other lighting mods.
    if defined?(Graphics) && defined?(Sprite) && defined?(Viewport)
      viewport=nil
      overlay=nil
      bitmap=nil
      begin
        viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
        viewport.z=999999
        bitmap=Bitmap.new(1,1)
        bitmap.set_pixel(0,0,Color.new(255,255,255,255))
        overlay=Sprite.new(viewport)
        overlay.bitmap=bitmap
        overlay.zoom_x=Graphics.width
        overlay.zoom_y=Graphics.height
        overlay.opacity=0
        10.times do |i|
          overlay.opacity=((i+1)*255/10.0).round
          sleep_fade_frames(1)
        end
        sleep_fade_frames(10)
        skip_to_hour(hour,minute)
        pbMEPlay("Pokemon Healing") if defined?(pbMEPlay)
        sleep_fade_frames(30)
        10.times do |i|
          overlay.opacity=((9-i)*255/10.0).round
          sleep_fade_frames(1)
        end
        sleep_fade_frames(20)
      ensure
        overlay.dispose if overlay && !overlay.disposed?
        bitmap.dispose if bitmap && !bitmap.disposed?
        viewport.dispose if viewport && !viewport.disposed?
      end
    else
      skip_to_hour(hour,minute)
    end
  end

  def use_sleeping_bag
    cfg=settings
    if cfg['enabled'] != true || cfg['source'] != 'internal'
      pbMessage(_INTL("El saco de dormir necesita un ciclo de día y noche con reloj interno."))
      return false
    end
    # Show all six fixed hours at once; cancel with the usual Back button.
    names=SLEEPING_BAG_SLOTS.map { |row| _INTL(row[2]) }
    selected=pbMessage(_INTL("¿A qué hora quieres despertar?"),names,-1,nil,0)
    return false if selected.nil? || selected<0 || selected>=SLEEPING_BAG_SLOTS.length
    h,m,label,description=SLEEPING_BAG_SLOTS[selected]
    sleeping_bag_transition(h,m)
    pbMessage(_INTL(description))
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
