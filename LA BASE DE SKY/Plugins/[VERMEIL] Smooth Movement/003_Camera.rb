# Ajuste no destructivo sobre Fancy Camera de La Base de Sky.
# 35 mantiene el comportamiento existente. 0 sigue mas rapido; 100 mas lento.
if defined?(FancyCamera)
  class Game_Temp
    alias vermeil_movement_base_camera_speed camera_speed unless method_defined?(:vermeil_movement_base_camera_speed)
    def camera_speed
      speed = vermeil_movement_base_camera_speed
      return speed unless defined?(VermeilMovement)
      smoothing = VermeilMovement.camera_smoothing
      # Rango conservador para evitar estelas y latencia excesiva.
      multiplier = (35.0 / [smoothing, 5].max)
      multiplier = [[multiplier, 0.25].max, 3.0].min
      speed * multiplier
    end
  end
end
