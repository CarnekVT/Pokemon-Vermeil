module UI_Editor
  
  class HUDMain
    
    include MiolUtils

    def initialize(viewport)
      @sprite = Sprite.new(viewport)
      @sprite.bitmap = Bitmap.new(Graphics.width, 110)
      pbSetSystemFont(@sprite.bitmap)
      
      
    end

    
    def clear
      @sprite.bitmap.clear if @sprite.bitmap && !@sprite.bitmap.disposed?
    end

    def dispose
      @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
      @sprite.dispose
    end

    def set_y=(val)
      @sprite.y = val
    end
    

    


    def draw(seleccion, color_mode, show_help)

      obj = seleccion.current_sprite
      return if !obj
      entry =  seleccion.current_entry

      has_internals = entry && !entry[:internals].empty?

      @sprite.bitmap.fill_rect(0, 0, Graphics.width, 80, Color.new(0, 0, 0, 200))

      pos_label = obj.respond_to?(:x) ? "X/Y" : "OX/OY" # decimos que si responde a ox/oy para Plane
      name = seleccion.name_for_object
      
      

      coord_text = "#{pos_label}: #{get_val(obj, :x)}, #{get_val(obj, :y)} | Z: #{get_val(obj, :z)} | Vis: #{obj.visible}"
    
      dynamic_x = width_dinamic(coord_text)

      info_tag, tag_color = tag_for_internals(seleccion, has_internals) 
      txt = [
        ["[#{name.upcase}]", 10, 5, 0, color_mode || Color.new(255,255,255)],
        [coord_text, 10, 30, 0, Color.new(50, 255, 50)],

        [info_tag, dynamic_x, 30, 0, tag_color],
        ["Zoom: #{get_val(obj, :zoom_x).round(2)} | Opac: #{get_val(obj, :opacity)} | Ang: #{get_val(obj, :angle)}", 10, 55, 0, Color.new(50, 255, 50)],
        ["[F5] Ayuda: #{ show_help ? 'ON' : 'OFF'}", Graphics.width - 150, 55, 0, Color.new(200, 200, 200)]
      ]
    
      pbDrawTextPositions(@sprite.bitmap, txt)
    end

    private
    
    def width_dinamic(coord_text)
      text_width = @sprite.bitmap.text_size(coord_text).width
      dynamic_x = 10 + text_width + 15
      return dynamic_x
    end

    def tag_for_internals(seleccion, has_internals)
      info_tag = ""
      tag_color = Color.new(50, 255, 50)
      if has_internals && !seleccion.sub_mode?
        info_tag = "| [INTERNALS]"
        tag_color = Color.new(255, 255, 0) # Amarillo para resaltar
      elsif seleccion.sub_mode?
        info_tag = "| [MODO INTERNO]"
        tag_color = Color.new(0, 255, 255) # Cyan cuando estás dentro
      end
      return [info_tag,tag_color]
    end

  end
  





















  class HelpPanel

    EDGE_SEPARATION = 10
    X_POS_LINE = 10
    Y_POS_LINE = 6
    LINE_HEIGHT = 20
    COLS = 2

    KEY_MAP = UIEditorCommandKEYS.new(Settings_UI_Editor::KEYS)
    KEY_STR = KEY_MAP.symbol_to_string

    def initialize(viewport)
      @sprite = Sprite.new(viewport)
      # Ancho dinámico: ocupa ~60% de la pantalla, mín 400px
      @width  = [[Graphics.width * 6 / 10, 400].max, Graphics.width - EDGE_SEPARATION * 2].min
      # Alto dinámico: lo calculamos tras definir las entradas
      @sprite.bitmap = Bitmap.new(@width, 10) # temporal, se recrea en draw
    end

    def clear
      @sprite.bitmap.clear if @sprite.bitmap && !@sprite.bitmap.disposed?
    end

    def dispose
      @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
      @sprite.dispose
    end

    def draw
      # ── Entradas del panel ────────────────────────────────────────────────
      header = ["CONTROLES DE EDICIÓN", Color.new(255, 200, 0)]
      divider = ["-" * 36,              Color.new(255, 200, 0)]

      entries = [
        ["#{KEY_STR[:NEXT_OBJ]}/#{KEY_STR[:PREV_OBJ]}: Sig/Ant",   Color.new(255, 255, 255)],
        ["L: Lista objetos",                                          Color.new(255, 255, 255)],
        ["#{KEY_STR[:TOGGLE_SUB]}: Sub-modo (Internos)",             Color.new(255, 255, 255)],
        ["Flechas: Mover obj.",                                       Color.new(180, 255, 180)],
        ["+Shift: Mover x GRID",                                     Color.new(180, 255, 180)],
        ["#{KEY_STR[:ZOOM_UP]}/#{KEY_STR[:ZOOM_DOWN]}: Zoom",        Color.new(180, 255, 180)],
        ["#{KEY_STR[:OPACITY_DOWN]}/#{KEY_STR[:OPACITY_UP]}: Opac.", Color.new(180, 255, 180)],
        ["#{KEY_STR[:ROTATE_L]}/#{KEY_STR[:ROTATE_R]}: Rotar",      Color.new(180, 255, 180)],
        ["#{KEY_STR[:MIRROR]}: Espejo",                              Color.new(180, 255, 180)],
        ["#{KEY_STR[:Z_LAYER_TAB]}+ (+/-): Z-layer", Color.new(255, 255, 255)],
        ["#{KEY_STR[:HIDE_TOGGLE]}: Ocultar obj.",                   Color.new(255, 255, 255)],
        ["#{KEY_STR[:TOGGLE_GUIDES]}: Guías",                        Color.new(255, 255, 255)],
        ["#{KEY_STR[:TOGGLE_HUD]}: HUD",                             Color.new(200, 200, 255)],
        ["#{KEY_STR[:TOGGLE_HELP]}: Ayuda",                          Color.new(200, 200, 255)],
        ["#{KEY_STR[:ACTION_MENU]}: Menú Acciones",                  Color.new(255, 150, 150)],
        ["#{KEY_STR[:RESET]}: Reset",               Color.new(255, 150, 150)]
      ]

      # ── Geometría ─────────────────────────────────────────────────────────
      col_w   = (@width - X_POS_LINE * 2) / COLS
      rows    = (entries.size.to_f / COLS).ceil
      # 2 líneas de cabecera + separador + filas de datos + margen
      height  = Y_POS_LINE * 2 + LINE_HEIGHT * (2 + rows) + 4

      # Reemplaza bitmap con el tamaño correcto
      @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
      @sprite.bitmap = Bitmap.new(@width, height)

      # Posición: centrado horizontalmente, esquina inferior izquierda
      @sprite.x = (Graphics.width - @width) / 2
      @sprite.y = Graphics.height - height - EDGE_SEPARATION

      bitmap = @sprite.bitmap
      bitmap.fill_rect(0, 0, @width, height, Color.new(0, 0, 0, 180))

      pbSetSmallFont(bitmap)

      shadow = Color.new(0, 0, 0, 120)

      # ── Cabecera (centrada, ocupa todo el ancho) ──────────────────────────
      y = Y_POS_LINE
      pbDrawTextPositions(bitmap, [[header[0],  @width / 2, y, 1, header[1],  shadow]])
      y += LINE_HEIGHT
      pbDrawTextPositions(bitmap, [[divider[0], @width / 2, y, 1, divider[1], shadow]])
      y += LINE_HEIGHT + 2   # pequeño espacio extra

      # ── Entradas en dos columnas ──────────────────────────────────────────
      entries.each_with_index do |entry, i|
        col  = i % COLS
        row  = i / COLS
        x    = X_POS_LINE + col * col_w
        ey   = y + row * LINE_HEIGHT
        pbDrawTextPositions(bitmap, [[entry[0], x, ey, 0, entry[1], shadow]])
      end
    end

  end






















  class PrecisionGuides
    include MiolUtils
    
    COLOR_SCREEN = Color.new(200, 0, 0, 120) # ROJO
    COLOR_OBJ = Color.new(0, 255, 255, 180) # AZUL
    COLOR_POINT_ZERO = Color.new(255, 255, 0)     # AMARILLO

    def initialize(viewport)
      @sprite =  Sprite.new(viewport)
      @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      
    end

    
    def clear
      @sprite.bitmap.clear if @sprite.bitmap && !@sprite.bitmap.disposed?
    end

    def dispose
      @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
      @sprite.dispose
    end

    def draw(seleccion)
      return if !@sprite || @sprite.disposed?

      s = seleccion.current_sprite

      bmp_canvas = @sprite.bitmap
      bmp_canvas.clear

      @size_rejilla = UI_Editor.settings.grid_size


      draw_grid(bmp_canvas) 
      
      center_screen_x = Graphics.width / 2
      center_screen_y = Graphics.height / 2
      
      unless @grid
        bmp_canvas.fill_rect(center_screen_x, 0, 1, Graphics.height, COLOR_SCREEN)
        bmp_canvas.fill_rect(0, center_screen_y, Graphics.width, 1, COLOR_SCREEN)
      end
      
      if s && !s.disposed? && s.respond_to?(:x) && s.respond_to?(:y)
        sprite_color = COLOR_OBJ # Cían
        
        # Coordenadas base
        base_x = get_val(s, :x)
        base_y = get_val(s, :y)
        
        
        if s.is_a?(Sprite) && s.bitmap
          
          real_center_x = base_x + ((s.bitmap.width / 2.0) - s.ox) * s.zoom_x
          real_center_y = base_y + ((s.bitmap.height / 2.0) - s.oy) * s.zoom_y
        elsif s.respond_to?(:width) && s.respond_to?(:height)
          
          real_center_x = base_x + (s.width / 2.0)
          real_center_y = base_y + (s.height / 2.0)
        else
          
          real_center_x = base_x
          real_center_y = base_y
        end

      
        bmp_canvas.fill_rect(real_center_x, 0, 1, Graphics.height, sprite_color)
        bmp_canvas.fill_rect(0, real_center_y, Graphics.width, 1, sprite_color)
        
        
        bmp_canvas.fill_rect(real_center_x - 10, real_center_y - 1, 21, 3, sprite_color)
        bmp_canvas.fill_rect(real_center_x - 1, real_center_y - 10, 3, 21, sprite_color)
        
      
        bmp_canvas.fill_rect(base_x - 2, base_y - 2, 5, 5, COLOR_POINT_ZERO) # Amarillo
      end

    end
    
    def draw_grid(bmp)

      return if @size_rejilla <= 0 
      
      grid_color =  COLOR_SCREEN
      
      
      (0..Graphics.width).step(@size_rejilla) do |x|
        bmp.fill_rect(x, 0, 1, Graphics.height, grid_color)
      end
      
      
      (0..Graphics.height).step(@size_rejilla) do |x|
        bmp.fill_rect(0, x, Graphics.width, 1, grid_color)
      end
    end

  end
  
end
