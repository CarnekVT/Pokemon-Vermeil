
MenuHandlers.add(:argos_dashboard, :edit_sprite, {
  "name"      => "Sprites",
  "iconName"  => "Sprites",
  "condition" => proc { |data| next data[:sprite].any? },
  "effect"    => proc { |editor| editor.start_editing_mode(:sprite) }
})

MenuHandlers.add(:argos_dashboard, :edit_const, {
  "name"      => "Constantes",
  "iconName"  => "Constantes",
  "condition" => proc { |data| next data[:const].any? },
  "effect"    => proc { |editor| editor.start_editing_mode(:const) }
})

MenuHandlers.add(:argos_dashboard, :edit_var, {
  "name"      => "Variables",
  "iconName"  => "Variables",
  "condition" => proc { |data| next data[:var].any? },
  "effect"    => proc { |editor| editor.start_editing_mode(:var) }
})

MenuHandlers.add(:argos_dashboard, :exit, {
  "name"      => "Salir",
  "iconName"  => "btn_exit",
  "condition" => proc { true },
  "effect"    => proc { |editor| editor.terminate_editor } 
})

MenuHandlers.add(:argos_dashboard, :config, {
  "name"      => "Configuración",
  "iconName"  => "configuracion", 
  "condition" => proc { true },
  "effect"    => proc { |editor| editor.menus.open_config_menu }
})

#



#===============================================================================
#Dashboard Central 
#===============================================================================
class Ui_Editor_Dashboard
  attr_reader :index
  UI_EDITOR_PATCHES_FOLDER = "Graphics/Plugins/UI_Editor/"

  COLOR_MAIN   = Color.new(76, 128, 232)
  COLOR_SHADOW = Color.new(24, 45, 115)
  LOGO_TEXT  = "UI EDITOR v1.0"

  def initialize(categorized_data)
    @data = categorized_data
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 1000000 
    
    @sprites = {}
    @available_procs = [] 

    @stats_to_scan = {
      :sprite => @data[:sprite].keys.size,
      :const  => @data[:const].keys.size,
      :var    => @data[:var].keys.size
    }




    @sprites["bg_panel"] = IconSprite.new(0, 0, @viewport)
    @sprites["bg_panel"].setBitmap( UI_EDITOR_PATCHES_FOLDER + "main_dashboard")
    @sprites["bg_panel"].opacity = 25

    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)

    @sprites["logo"] = BitmapSprite.new(Graphics.width, 100, @viewport)
    @sprites["logo"].x = 0
    @sprites["logo"].y = 1
    logo_bmp = @sprites["logo"].bitmap

    

    pbSetSmallFont(logo_bmp)
    logo_bmp.font.size = 50 
    logo_bmp.font.bold = true
    

    setup_dynamic_menu
    @sprites.each { |k, s| s.opacity = 0 if k.start_with?("boton") }

    @sprites["flecha"] = IconSprite.new(0, 0, @viewport)
    @sprites["flecha"].setBitmap(UI_EDITOR_PATCHES_FOLDER + "flechita")
    @sprites["flecha"].opacity = 0
    @sprites["flecha"].z = 100 

    @intro_state = :writing
    @intro_timer = System.uptime
    @logo_text = LOGO_TEXT
    @index = 0
    @move_start_time = System.uptime
    refresh_cursor_position(true) 
    @show_ui = true
  end


  def setup_dynamic_menu
    idx = 0
    @btn_info = [] 
    MenuHandlers.each_available(:argos_dashboard, @data) do |option, hash, name|

      
      @available_procs.push(hash["effect"]) 

      @btn_info.push(option) 

      @sprites["boton#{idx}"] = Sprite.new(@viewport)
      @sprites["boton#{idx}"].bitmap = Bitmap.new(UI_EDITOR_PATCHES_FOLDER + hash['iconName'])
      

      @sprites["boton#{idx}"].x = 80 + (idx % 2) * 200
      @sprites["boton#{idx}"].y = 120 + (idx / 2) * 90
      idx += 1
    end
  end
  
  #--- Numeritos ---
  def draw_button_numbers
    @sprites["overlay"].bitmap.clear
    return if [:writing, :moving_up].include?(@intro_state)

    base_color = Color.new(255, 255, 255)
    shadow_color = Color.new(0, 0, 0, 150)
    pbSetSmallFont(@sprites["overlay"].bitmap)

    @available_procs.size.times do |i|
      btn_sprite = @sprites["boton#{i}"]
      category = @btn_info[i]
      
      
        target_num = case category
                    when :edit_sprite then @data[:sprite].keys.size
                    when :edit_const  then @data[:const].keys.size
                    when :edit_var    then @data[:var].keys.size
                    else nil
                    end


      next if target_num.nil?


      actual_num = MiolUtils.rolling_number(0, target_num, 1.0, @fade_timer + (i * 0.2))


      if btn_sprite.opacity > 50
        x_num = btn_sprite.width + btn_sprite.x - 2
        y_num = btn_sprite.y + 5
        txt = [[actual_num.to_s, x_num, y_num, 1, base_color, shadow_color]]
        pbDrawTextPositions(@sprites["overlay"].bitmap, txt)
      end
    end
  end
  
  def update_selection(editor_instance)
    loop do
      Graphics.update
      Input.update
      self.update_animations
      next unless @intro_state == :ready
      old_index = @index
      max_options = @available_procs.size

      # Navegación por teclado
      if Input.trigger?(Input::UP)    
        @index = (@index - 2) % max_options
      elsif Input.trigger?(Input::DOWN)  
        @index = (@index + 2) % max_options
      elsif Input.trigger?(Input::LEFT)  
        @index = (@index - 1) % max_options
      elsif Input.trigger?(Input::RIGHT) 
        @index = (@index + 1) % max_options
      end

      if @index != old_index
        pbPlayCursorSE
        refresh_cursor_position
      end

      
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        @available_procs[@index].call(editor_instance)
        break 
      end

      if Input.trigger?(Input::BACK)
        return :exit
      end
    end
  end

  
  def refresh_cursor_position(instant = false)
    target_btn = @sprites["boton#{@index}"]
    @start_x = @sprites["flecha"].x
    @start_y = @sprites["flecha"].y
    
    
    @target_x = target_btn.x 
    @target_y = target_btn.y 
    if instant
      @sprites["flecha"].x = @target_x
      @sprites["flecha"].y = @target_y
    end
    @move_start_time = System.uptime
  end

  
  def update_animations
    return if !@show_ui


    case @intro_state
    when :writing
      
      current_text = MiolUtils.typewriter(@logo_text, 25, @intro_timer)
      @sprites["logo"].bitmap.clear
      txt_logo = [
        [current_text, Graphics.width/2 + 2, 42, 2, Color.black, nil], # Sombra
        [current_text, Graphics.width/2, 40, 2, COLOR_MAIN, COLOR_SHADOW] # Azul con borde Gris
      ]
      pbDrawTextPositions(@sprites["logo"].bitmap, txt_logo)
      
      
      if current_text.length >= @logo_text.length && System.uptime > @intro_timer + (@logo_text.length / 25.0) + 0.5
        @intro_state = :moving_up
        @move_timer = System.uptime
        @logo_start_y = @sprites["logo"].y
      end

    when :moving_up
      
      duration = 0.8
      t = (System.uptime - @move_timer) / duration
      factor = MiolUtils.elastic_out(t)
      
      @sprites["logo"].y = @logo_start_y + (10 - @logo_start_y) * factor
      
      if t >= 1.0
        @intro_state = :fading_in
        @fade_timer = System.uptime
      end

    when :fading_in
  
      bg_alpha = MiolUtils.fade(0, 255, 0.8, @fade_timer)
      @sprites["bg_panel"].opacity = bg_alpha
      @sprites["flecha"].opacity = bg_alpha
      
      # Numeritos
      draw_button_numbers()
    
      botones_listos = true
      
      @available_procs.size.times do |i|
        
        retraso = i * 0.2 
        duracion_del_fade = 0.6
        
        
        opacidad_boton = MiolUtils.fade(0, 255, duracion_del_fade, @fade_timer + retraso)
        @sprites["boton#{i}"].opacity = opacidad_boton
        
        
        botones_listos = false if opacidad_boton < 255
      end
      
      
      if botones_listos && bg_alpha >= 255
        @intro_state = :ready
        refresh_cursor_position(true)
      end

    when :ready
      
      @base_x = MiolUtils.lerp_argos(@start_x, @target_x, 0.2, @move_start_time)
      @base_y = MiolUtils.lerp_argos(@start_y, @target_y, 0.2, @move_start_time)

      @sprites["flecha"].x = MiolUtils.oscillate(@base_x, 6, 5)
      @sprites["flecha"].y = @base_y
    end

   

    pbUpdateSpriteHash(@sprites)
  end

  def visible=(val)
    @show_ui = val
    @viewport.visible = val
  end

  def dispose
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

