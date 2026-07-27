# encoding: utf-8
module SceneEngine
  module Settings
    SCENES_DIR = "Graphics/Scenes"

    TEXT_BOX_FILE = "txt"
    TEXT_BOX_Y = 321
    TEXT_BOX_H = 159
    TEXT_PAD_X = 42
    TEXT_PAD_Y_TOP = 28
    TEXT_PAD_Y_BOT = 20
    TEXT_LINE_H = 26
    TEXT_MAX_LINES = 3
    SPEAKER_Y = 10

    SPEAKER_COLOR = Color.new(248, 208, 48)
    SPEAKER_SHADOW = Color.new(120, 96, 16)
    TEXT_COLOR = Color.new(248, 248, 248)
    TEXT_SHADOW = Color.new(72, 72, 72)

    SPEED_INSTANT = 999
    SPEED_FAST = 6
    SPEED_NORMAL = 3
    SPEED_SLOW = 1

    FADE_DEFAULT = 20
    LAYER_BG = 100
    LAYER_IMG = 200
    LAYER_TEXTBOX = 500
    LAYER_TEXT = 510
    LAYER_OVERLAY = 9000
  end
end
