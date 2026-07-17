

# 
#===============================================================================
module MiolUtils
  module_function


  #==============================================================================
  # Metodos de apoyo a UI_Editor.
  #==============================================================================


  def pbShowCommandsCustom(commands, defaultcmd = 0, xpos = 0, ypos = 0, ramo_de_flores = false)
    ret = -1

    original_list = commands.clone
    index_map = (0...commands.length).to_a 
    
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 99999
    
    # Creamos la ventana con la lista inicial
    cmdwindow = Window_CommandPokemon.new(commands)
    cmdwindow.viewport = vp
    cmdwindow.index = defaultcmd
    cmdwindow.x, cmdwindow.y = xpos, ypos
    cmdwindow.z = 1000005
    
    is_filtered = false

    loop do
      Graphics.update
      Input.update
      cmdwindow.update
      

      if Input.triggerex?(:F) && ramo_de_flores
        term = pbOpenGenericListSearch 
        if term && !term.empty?
          new_commands = []
          new_index_map = []
          

          original_list.each_with_index do |cmd_text, i|
            if pbSmartMatch?(cmd_text, term)
              new_commands.push(cmd_text)
              new_index_map.push(i)
            end
          end
          
          if new_commands.empty?
            pbMessage(_INTL("No se encontraron resultados para: {1}", term))
          else

            commands = new_commands
            index_map = new_index_map
            cmdwindow.commands = commands
            cmdwindow.index = 0
            cmdwindow.refresh
            is_filtered = true
          end
        end
      end


      if Input.trigger?(Input::USE)
        pbPlayDecisionSE

        ret = index_map[cmdwindow.index]
        break
      

      elsif Input.trigger?(Input::BACK)
        if is_filtered

          commands = original_list.clone
          index_map = (0...original_list.length).to_a
          cmdwindow.commands = commands
          cmdwindow.index = 0
          cmdwindow.refresh
          is_filtered = false
          pbPlayCancelSE
        else

          pbPlayCancelSE
          break
        end
      end
    end
    
    cmdwindow.dispose
    vp.dispose
    return ret
  end




  def experimental_functions_message
    pbMessage("No tienes acceso a las funciones experimentales")
  end




  ##################
  # Logica matematica

  def get_val(obj, prop, default=0)
    return default if !obj || obj.disposed?
    return obj.send(prop) if obj.respond_to?(prop)
    if prop == :x && obj.respond_to?(:ox) then return obj.ox end
    if prop == :y && obj.respond_to?(:oy) then return obj.oy end
    return default
  end
  

  def set_val(obj, prop, val)
    return if !obj || obj.disposed?
    if prop == :x then obj.respond_to?(:x=) ? obj.x = val : obj.ox = val
    elsif prop == :y then obj.respond_to?(:y=) ? obj.y = val : obj.oy = val
    else obj.send("#{prop}=", val) if obj.respond_to?("#{prop}=") end
  end



  def sanitize_filename(filename)
    return filename.gsub(/[\x00\/\\:\*\?\"<>\|]/, '_').gsub(/^\.+/, '')
  end

#--------------------------------------------------------------------------
# CAPTURA DE PANTALLA
#--------------------------------------------------------------------------


  def capture_to_ram
    return Graphics.snap_to_bitmap
  end

  def save_bitmap_to_png(bmp, prefix)
    path = "Graphics/Plugins/UI_Editor/Screenshots"
    Dir.mkdir(path) unless Dir.exist?(path)
    
    filename = "#{prefix}_#{Time.now.to_i}.png"
    path = "#{path}/#{filename}"
    bmp.save_to_png(path)
    return filename
  end

  
  def create_mini_preview(bmp, max_size = 200)
    return nil if !bmp || bmp.disposed?
    ratio = [max_size.to_f / bmp.width, max_size.to_f / bmp.height].min
    new_width = (bmp.width * ratio).to_i
    new_height = (bmp.height * ratio).to_i

    mini= Bitmap.new(new_width, new_height)
    mini.stretch_blt(mini.rect, bmp, bmp.rect)
    return mini
  end
#--------------------------------------------------------------------------

  def echo_color(texto, color = "blanco")
    colores = {
      "rojo"     => "31",
      "verde"    => "32",
      "amarillo" => "33",
      "azul"     => "34",
      "magenta"  => "35",
      "cian"     => "36",
      "blanco"   => "37"
    }
    codigo = colores[color.downcase] || "37"
    echoln "\e[#{codigo}m#{texto}\e[0m"
  end



# Método para calcular el AABB de un objeto para el alineado 
  def aabb(obj)
    return nil if obj.disposed? || !obj || obj.is_a?(VirtualPointProxy)
    x = get_val(obj, :x)
    y = get_val(obj, :y)

    if obj.is_a?(Sprite) && obj.bitmap
      w = obj.bitmap.width * obj.zoom_x
      h = obj.bitmap.height * obj.zoom_y
      x -= obj.ox * obj.zoom_x
      y -= obj.oy * obj.zoom_y
    elsif obj.respond_to?(:width)
      w, h = obj.width, obj.height
    else
      return nil
    end

    return UI_Editor::AABB.new(x, y, x + w, y + h, x + w/2.0, y + h/2.0, w, h)
  end










































































  # ! modificar el editor para soportar animaciones




  #-----------------------------------------------------------------------------
  # I. MOTOR CINEMÁTICO (Interpolación y Transiciones)
  #-----------------------------------------------------------------------------
  
  # me acorde qu ya existia uno en la base xd. recomiendo usar ese
  def lerp_argos(start_val, end_val, duration, start_time)
    return end_val if duration <= 0
    elapsed = System.uptime - start_time
    return end_val if elapsed >= duration
    t = elapsed / duration.to_f
    return start_val + (end_val - start_val) * t
  end



 # --- FADE  ---
  def fade(start_opac, end_opac, duration, start_time)
    elapsed = System.uptime - start_time
    

    return start_opac if elapsed <= 0
    
    
    return end_opac if elapsed >= duration
    
    
    t = elapsed / duration.to_f
    t = t * t * (3 - 2 * t) 
    
    return (start_opac + (end_opac - start_opac) * t).to_i
  end


  # Oscilación 
  def oscillate(base_val, amplitude, speed)
    return base_val + Math.sin(System.uptime * speed) * amplitude
  end



  # Efecto Muelle 
  def elastic_out(t)
    return 1 if t >= 1
    return 0 if t <= 0
    p = 0.3
    return (2**(-10 * t) * Math.sin((t - p/4) * (2 * Math::PI) / p) + 1)
  end


  def draw_procedural_line(bitmap, x1, y1, x2, y2, thickness, color)
    dist = [(x2 - x1).abs, (y2 - y1).abs].max
    return if dist == 0
    
    x_step = (x2 - x1).to_f / dist
    y_step = (y2 - y1).to_f / dist
    
    cur_x, cur_y = x1.to_f, y1.to_f
    
    (dist.to_i + 1).times do
      
      if thickness <= 1
        bitmap.set_pixel(cur_x, cur_y, color)
      else
        offset = thickness / 2.0
        bitmap.fill_rect(cur_x - offset, cur_y - offset, thickness, thickness, color)
      end
      cur_x += x_step
      cur_y += y_step
    end
  end


  # Máquina de escribir (creo que tambien habia una manera mas simple en la base)
  def typewriter(full_text, speed, start_time)
    chars = ((System.uptime - start_time) * speed).to_i
    return full_text[0...chars] || ""
  end

  # Rolling Number (lo mismo que lo anterior)
  def rolling_number(start_num, end_num, duration, start_time)
    return end_num if (System.uptime - start_time) >= duration
    return lerp_argos(start_num, end_num, duration, start_time).to_i
  end

end

module UI_Editor
  module Consts
    extend self
    FORBIDDEN_CONSTANTS = [:Object, :Module, :Class, :Kernel, :Settings, :Graphics, :Input].freeze
    def safe_name?(name)
      
      name.to_s =~ /^[A-Z][A-Z0-9_]*$/ && 
      name.to_s.match?(/_X|_Y|_OFFSET|_POS|_WIDTH|_HEIGHT|COORDS|CENTER|TOP|LEFT/)
    end

    def apply(klass, const_name, new_value)
      
      return unless safe_name?(const_name)
      return if forbidden_target?(const_name)
      safe_value = sanitize_value(new_value)
      execute_atomic_change(klass, const_name.to_sym, safe_value)
    end

    private

  
    def forbidden_target?(name)
      FORBIDDEN_CONSTANTS.include?(name.to_sym)
    end

    def sanitize_value(val)
      if val.is_a?(Numeric)
        if val.is_a?(Integer) || (val % 1 == 0)
          return val.to_i
        else
          return val.to_f
        end 
      elsif val.is_a?(Array)
        return val.map { |v| v.is_a?(Numeric) ? v.to_f : 0.0 }
      elsif val.is_a?(Hash)

        new_hash = {}
        val.each { |k, v| new_hash[k] = sanitize_value(v) }
        return new_hash
      end
      return 0.0 
    end

    def execute_atomic_change(klass, name, val)

      begin
        
        klass.send(:remove_const, name) if klass.const_defined?(name, false)
        klass.const_set(name, val)
      rescue Exception => e
        UI_Editor.echo_color("Shield Blocked: #{e.message}", "rojo")

      end
    end
  end
end

module Mouse
  def self.get_hitbox(obj)
    return [0,0,0,0] if !obj || obj.disposed?
    
    
    ax = MiolUtils.get_val(obj, :x)
    ay = MiolUtils.get_val(obj, :y)
    
    
    if obj.respond_to?(:viewport) && obj.viewport
      ax += obj.viewport.rect.x - obj.viewport.ox
      ay += obj.viewport.rect.y - obj.viewport.oy
    end

    
    if obj.is_a?(Sprite) && obj.bitmap
      aw = obj.bitmap.width * obj.zoom_x
      ah = obj.bitmap.height * obj.zoom_y
      ax -= obj.ox * obj.zoom_x
      ay -= obj.oy * obj.zoom_y
    elsif obj.respond_to?(:width)
      aw = obj.width
      ah = obj.height
    else
      aw = ah = 20 
    end
    
    return [ax, ay, aw, ah]
  end

  def self.over_accurate?(obj)
    x, y, w, h = self.get_hitbox(obj)
    return Input.mouse_x.between?(x, x + w) && Input.mouse_y.between?(y, y + h)
  end
end