#===============================================================================
# 000_Settings.rb
#===============================================================================
module VermeilChangeDex
  # Configuración General
  SCREEN_W = 640
  SCREEN_H = 480
  
  # Colores (Se mantienen en la raíz o en Settings)
  COLOR_BG           = Color.new(20, 25, 35)
  COLOR_GRID_FILL    = Color.new(30, 38, 52, 140)
  COLOR_GRID_EDGE    = Color.new(56, 70, 92, 120)
  COLOR_PANEL_FILL   = Color.new(28, 36, 50, 170)
  COLOR_PANEL_EDGE   = Color.new(62, 78, 104, 150)
  COLOR_HIGHLIGHT    = Color.new(220, 60, 60)
  COLOR_TEXT_MAIN    = Color.new(245, 245, 245)
  COLOR_TEXT_GRAY    = Color.new(180, 180, 180)
  COLOR_CANON        = Color.new(80, 180, 255)
  COLOR_VERMEIL      = Color.new(255, 100, 100)
  COLOR_DIFF         = Color.new(255, 215, 0)
  COLOR_MOVES_NEW    = Color.new(100, 255, 120)
  
  DETECT_CACHE_VERSION = 14

  # Módulo de Layout (Aquí es donde el Scene.rb buscaba y fallaba)
  module Layout
    GRID_COLS = 6
    GRID_ROWS = 4
    GRID_ACTIVE_ROWS = 3
    GRID_PAGE_SIZE = GRID_COLS * GRID_ACTIVE_ROWS
    GRID_CELL = 80
    GRID_X = (SCREEN_W - (GRID_COLS * GRID_CELL)) / 2
    GRID_Y = 60
  end
end