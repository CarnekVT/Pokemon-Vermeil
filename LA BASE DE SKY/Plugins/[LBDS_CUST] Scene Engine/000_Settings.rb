# encoding: utf-8
module SceneEngine
  module Settings
    SCENES_DIR = "Graphics/Scenes"

    TEXT_BOX_FILE = "txt"
    
    TEXT_BOX_Y = 286
    TEXT_BOX_H = 178
    
    TEXT_PAD_X = 48         # Ligeramente más ancho para que quepa más texto por línea
    TEXT_PAD_Y_TOP = 42     # Margen superior ajustado
    TEXT_PAD_Y_BOT = 0      # Cero margen inferior para aprovechar toda la caja
    TEXT_LINE_H = 32        # ¡VITAL! 32px es la altura real de la fuente, evita cortes
    TEXT_MAX_LINES = 4      

    SPEAKER_COLOR = Color.new(248, 208, 48)
    SPEAKER_SHADOW = Color.new(120, 96, 16)
    SPEAKER_COLOR_MAP = {
      "???"           => [Color.new(180, 180, 180), Color.new(72, 72, 72)],
      "Gran Espíritu"    => [Color.new(255, 215, 0), Color.new(180, 140, 0)],
      "Mujer Misteriosa" => [Color.new(0, 200, 200), Color.new(0, 110, 130)]
    }
    TEXT_COLOR = Color.new(248, 248, 248)
    TEXT_SHADOW = Color.new(72, 72, 72)

    SPEED_INSTANT = 999
    SPEED_FAST = 4.4
    SPEED_NORMAL = 1.5
    SPEED_SLOW = 0.7
    SPEED_VERY_SLOW = 0.15

    FADE_DEFAULT = 20
    LAYER_BG = 100
    LAYER_IMG = 200
    LAYER_TEXTBOX = 500
    LAYER_TEXT = 510
    LAYER_OVERLAY = 9000
  end
end