# encoding: utf-8
module CustomWeather
  # --- CONFIGURACIÓN DE INTERRUPTOR ---
  # Si este switch está ON, TODOS los climas (incluso :None) se verán Sepia.
  SEPIA_FILTER_SWITCH = 61 

  # Intensidad del filtro cuando no hay clima (0-255). 
  # 160 es un filtro visible pero no totalmente opaco.
  SEPIA_BASE_INTENSITY = 160 
end
