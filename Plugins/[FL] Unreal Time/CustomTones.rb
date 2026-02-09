#===============================================================================
# [FL] Unreal Time - Custom Tones (Tonos Personalizados)
#===============================================================================
# Este script reemplaza los tonos de pantalla por defecto para dar un aspecto
# más estético.
# Tonos basados en "Deo's custom Day & Night tones" (https://eeveeexpo.com/r/50/)
# Funciona automáticamente con el tiempo de Unreal Time.
#===============================================================================

module DayNight
  # Tonos por hora (Red, Green, Blue, Gray)
  TONES = {
    # Noche profunda
    0  => Tone.new(-40, -65, 30, 80),
    1  => Tone.new(-38, -63, 28, 78),
    2  => Tone.new(-36, -60, 26, 75),
    3  => Tone.new(-34, -58, 24, 72),
    4  => Tone.new(-30, -50, 22, 65),
    # Madrugada
    5  => Tone.new(-25, -35, 10, 30),
    6  => Tone.new(-20, -30, 8, 20),
    # Amanecer
    7  => Tone.new(10, -10, -5, 10),
    8  => Tone.new(15, -5, -10, 5),
    # Mañana
    9  => Tone.new(0, 0, 0, 0),
    10 => Tone.new(2, 2, -2, 0),
    11 => Tone.new(3, 3, -3, 0),
    # Mediodía
    12 => Tone.new(5, 5, -5, 0),
    13 => Tone.new(6, 6, -6, 0),
    14 => Tone.new(5, 5, -5, 0),
    # Tarde
    15 => Tone.new(10, 0, -10, 5),
    16 => Tone.new(8, -2, -12, 8),
    # Atardecer
    17 => Tone.new(20, -10, -20, 15),
    18 => Tone.new(25, -15, -25, 20),
    # Crepúsculo
    19 => Tone.new(-10, -20, 10, 30),
    20 => Tone.new(-15, -30, 15, 40),
    # Noche
    21 => Tone.new(-30, -50, 20, 60),
    22 => Tone.new(-35, -60, 25, 70),
    23 => Tone.new(-40, -65, 30, 80)
  }

  def self.getTone
    # Verificar si el sombreado está activo (compatible con v21 y UnrealTime)
    shading = true
    if defined?(UnrealTime) && defined?(UnrealTime::Bridge)
      shading = UnrealTime::Bridge.time_shading
    elsif defined?(Settings::TIME_SHADING)
      shading = Settings::TIME_SHADING
    end
    return Tone.new(0, 0, 0, 0) if !shading

    # Obtener hora actual (UnrealTime afecta a pbGetTimeNow)
    time = pbGetTimeNow
    hour = time.hour
    min = time.min

    # Encontrar los puntos de control (keyframes) para interpolar
    start_hour = TONES.keys.select { |h| h <= hour }.max || 0
    end_hour = TONES.keys.select { |h| h > hour }.min || 24

    tone1 = TONES[start_hour]
    tone2 = TONES[end_hour] || TONES[0]

    # Calcular el progreso (fracción) entre la hora de inicio y fin
    total_minutes = (end_hour - start_hour) * 60
    current_minutes = (hour - start_hour) * 60 + min
    
    return tone1 if total_minutes <= 0

    fraction = current_minutes.to_f / total_minutes

    # Interpolación lineal para suavizar el cambio de color minuto a minuto
    r = tone1.red + (tone2.red - tone1.red) * fraction
    g = tone1.green + (tone2.green - tone1.green) * fraction
    b = tone1.blue + (tone2.blue - tone1.blue) * fraction
    gray = tone1.gray + (tone2.gray - tone1.gray) * fraction

    return Tone.new(r, g, b, gray)
  end
end