module UI_Editor
  class ChangeManager
    include MiolUtils
    def initialize(orig, all_data, parent_scene, editor)
      @orig = orig
      @parent_scene = parent_scene
      @all_data = all_data
      @editor = editor
      @hud = editor.hud
      @before_bmp = MiolUtils.capture_to_ram
      @visuals = editor.handler_visual
    end

    def dispose
      @before_bmp.dispose if @before_bmp && !@before_bmp.disposed?
    end

    def log_all_changes
      report_header = "█" * 60 + "\n"
      report_header += "   REPORTE TÉCNICO DE DISEÑO - #{Time.now.strftime('%d/%m/%Y %H:%M:%S')}\n"
      report_header += "   Diseñador: #{name_editor}\n"
      report_header += "█" * 60 + "\n"
      
      reports = { :const => [], :var => [], :sprite => []}

      
        parent_deltas = {} 

      each_value_all_data() do |obj, internal_var, main_key, entry| 
        orig_stats = @orig[obj.object_id]
        
        # Calculamos todos los cambios brutos del objeto actual
        all_changes = deltas_props_obj(obj, orig_stats)
        next if all_changes.empty?

        if internal_var.nil?
          # --- CASO PADRE ---
          # Guardamos sus deltas en un Hash para comparar con sus futuros hijos
          parent_deltas = all_changes.to_h 
          changes = all_changes
        else
          # --- CASO HIJO ---
          # Filtramos: Solo dejamos los cambios que NO sean iguales a los del padre
          changes = all_changes.select do |prop, delta|
            # Si el padre no tiene esa propiedad o el delta es distinto, lo mantenemos
            !parent_deltas.key?(prop) || (delta - parent_deltas[prop]).abs > 0.001
          end
        end

        # Si después de filtrar el hijo no tiene cambios únicos, saltamos al siguiente
        
        
        next if changes.empty?
        is_proxy = obj.is_a?(VirtualPointProxy)
        type = is_proxy ? obj.type : :sprite
        
        cat_key = case type
          when :const, :hash_const then :const
          when :ivar               then :var   # <--- Mapeamos :ivar a :var
          else                          :sprite
          end
        
        if cat_key == :const
          loc = orig_stats[:original_source]
          
          if loc
            # Limpiamos la ruta para que sea legible
            full_path = loc[0].gsub(/\\/, "/")
            if full_path =~ /(Plugins|Scripts|Data\/Scripts)\/(.+)$/i
              location = "#{$1}/#{$2}:#{loc[1]}"
            else
              location = "#{File.basename(full_path)}:#{loc[1]}"
            end
          else
            
            location = get_precise_origin(entry[:scene_class], obj.var_name, :const)
          end
          
          path =  obj.get_patch_path
        elsif cat_key == :sprite
            real_key = main_key.to_s.sub(/^(Sprites|VAR):\s*/, "")
          target_method = detectar_target_method_por_clase(entry[:scene_class])
          location = get_precise_origin(entry[:scene_class], target_method, :method)
          path = internal_var ? "@sprites['#{real_key}'].instance_variable_get(:#{internal_var})" : "@sprites['#{real_key}']"
          
        else
            real_key = main_key.to_s.sub(/^(Sprites|VAR):\s*/, "")
          target_method = detectar_target_method_por_clase(entry[:scene_class])
          location = get_precise_origin(entry[:scene_class], target_method, :method)
          path = obj.get_patch_path
        
        end

        

        
        block = "\n[ #{entry[:scene_class]} ] -> Ubicación: #{location}\n"
        changes.each do |p, d|
          current_val = get_val(obj, p)
          sym = d > 0 ? "+=" : "-="
          if cat_key == :const
            block += "   #{path} = #{current_val}\n"
          elsif cat_key == :var
            
            block += "  #{path} #{sym} #{d.abs}\n"
          else
            
            
            block += "   #{path}.#{p} #{sym} #{d.abs}\n"
          end
        end
        reports[cat_key] << block

      end

      
      report_body = ""
      { :const => "CONFIGURACIÓN (CONSTANTES)", :var => "VARIABLES DE INSTANCIA", :sprite => "OBJETOS GRÁFICOS" }.each do |key, title|
        unless reports[key].empty?
          report_body += "\n#{"="*20} #{title} #{"="*20}\n"
          report_body += reports[key].join("\n")
        end
      end

      if report_body.strip.empty?
        pbMessage("No se detectaron cambios para reportar.")
        return
      end

      echoln report_header + report_body + "\n" + "█" * 60
      format_change_history = UI_Editor.settings.report_format == :md ? "Markdown" : "TXT"
      if pbConfirmMessage("¿Deseas guardar estos cambios en el historial? (Formato: #{format_change_history})")
        @hud.visible = false
        mini_preview = nil
        if UI_Editor.settings.report_format == :md

          @hud.visible = false
          @visuals.reset
          Graphics.update
          after_bmp = Graphics.snap_to_bitmap
          
          
          mini_preview = {
            :before => MiolUtils.create_mini_preview(@before_bmp, 240),
            :after  => MiolUtils.create_mini_preview(after_bmp, 240)
          }
          after_bmp.dispose 
        end

        scene = UIEditorTextEntry.new
        screen = MiolTextEntry.new(scene)
        #text_entry = UI_Editor::UIEditorTextEntry.new("Describe brevemente el cambio realizado:", 5, 50, "", mini_preview)
        commit_name = screen.pbStartScreen("Nombre del cambio:", 5, 50, "ajuste_ui", mini_preview)
        save_report_to_file(report_body, commit_name) if commit_name && commit_name != ""
      else
        @hud.visible = true
        @visuals.update(@editor.seleccion.current_sprite)
      end
    end

    def display_delta_data(s)
      return if !s
      orig = @orig[s.object_id]
      dx = (get_val(s, :x) - orig[:x]).round(2)
      dy = (get_val(s, :y) - orig[:y]).round(2)
      pbMessage("Deltas actuales:\nX: #{dx >= 0 ? '+' : ''}#{dx}\nY: #{dy >= 0 ? '+' : ''}#{dy}")
    end


    def detectar_target_method_por_clase(class_name)

      # Specific cases for methods where sprites are instantiated to improve the accuracy of where changes are applied.

      # Case para especificar excepciones de métodos donde se crean los sprites y mejorar la precisión de la ubicación del cambio
      case class_name
      when "Battle::Scene" 
        return "pbInitSprites"
      when "PokemonStorageScene" 
        return "pbStartBox"
      end
      
      begin
        klass = Object.const_get(class_name)
      rescue
        return "initialize" 
      end

      
      if class_name.include?("Battle::Scene::") && !class_name.include?("Scene_")
        return "initialize"
      end

      
      if klass.instance_methods(false).include?(:pbStartScene)
        return "pbStartScene"
      end

      
      return "initialize"
    end


    def compile_patch_json
      patcher= Patcher::Core.new
      result = patcher.request_compilation(@all_data, @orig, @parent_scene)
      return result
    end




    private

    def save_report_to_file(body, commit_name)
    
      formato = UI_Editor.settings.report_format
      file_path = "Graphics/Plugins/UI_Editor/UI_Changes_History.#{formato}"
      
      @hud.visible = false
      @visuals.reset

      before_fn = nil
      after_fn  = nil
      
      
      begin
        File.open(file_path, "a+b") do |f|
          if formato == :md
            countdown()
            2.times { Graphics.update } 
            after_img = Graphics.snap_to_bitmap
            before_fn = MiolUtils.save_bitmap_to_png(@before_bmp, "before")
            after_fn  = MiolUtils.save_bitmap_to_png(after_img, "after")
            after_img.dispose
            @visuals.update((@editor.seleccion.current_sprite))
            f.write(generate_markdown_content(commit_name, body, before_fn, after_fn))
          else
            
            f.write("\n" + "="*60 + "\n")
            f.write(" CAMBIO: #{commit_name.upcase}\n")
            f.write(body)
          end
        end
        pbMessage("Historial actualizado en #{file_path.gsub("Graphics/Plugins/", "")}")
        @visuals.update((@editor.seleccion.current_sprite))
        @hud.visible = true 
      rescue => e
        pbMessage("Error al guardar archivo: #{e.message}")
      end
    end

    def generate_markdown_content(name, body, before_img, after_img)
      md =  "\n# 🛠 CAMBIO: #{name.upcase}\n"
      md += "**Fecha:** #{Time.now.strftime('%d/%m/%Y %H:%M:%S')} | **Diseñador:** #{name_editor}\n\n"
      md += "### Comparativa Visual\n"
      md += "| Estado Original (Antes) | Estado Modificado (Después) |\n"
      md += "| :---: | :---: |\n"

      md += "| ![Antes](Screenshots/#{before_img}) | ![Después](Screenshots/#{after_img}) |\n\n"
      md += "### Código a Aplicar\n"
      md += "```ruby\n#{body}\n```\n"
      md += "---\n"
      return md
    end

    def each_value_all_data
      @all_data.each_value do |category|
        category.each do |main_key, entry|

          parent = entry[:main]
          yield(parent, nil, main_key, entry) if parent && !parent.disposed?


          entry[:internals].each do |internal_var, obj|
            next if !obj || obj.disposed?
            yield(obj, internal_var, main_key, entry)
          end
        end
      end
    end
    #  RECORDAR CREAR HASH DE PROPS
    def deltas_props_obj(obj, orig)
      changes = []
      [:x, :y, :z, :zoom, :opacity, :angle].each do |p|
        insert = get_val(obj, p)
        delta = ( insert - orig[p]).round(2)

        next if p.to_s.include?("zoom") && delta == -1.0 # ignorar zoom fantasma
        next if p.to_s.include?("opacity") && delta == -255 # ignorar cambio de opacidad total que a veces ocurre al modificar el zoom
        changes << [p, delta] if delta.abs > 0.001
      end
      return changes
    end


    def get_precise_origin(class_name, target_name, type = :method)
      begin
        klass = Object.const_get(class_name)
        
        if type == :const || type == :hash_const
          loc = klass.const_source_location(target_name.to_sym)
        else
          loc = klass.instance_method(target_name.to_sym).source_location
        end

        return "Origen no detectado" if !loc
        
        
        full_path = loc[0].gsub(/\\/, "/") 
        
        
        if full_path =~ /(Plugins|Scripts|Data\/Scripts)\/(.+)$/i
          clean_path = "#{$1}/#{$2}"
          return "#{clean_path}:#{loc[1]}"
        end

        return "#{File.basename(full_path)}:#{loc[1]}"
      rescue
        return "Desconocido"
      end
    end
    
    def countdown
        pbSEPlay("Screenshot") if FileTest.audio_exist?("Audio/SE/Screenshot")

        10.times do
          Graphics.update
          Input.update 
        end
    end
    def name_editor
      class_name = @parent_scene.class
      class_is_ui_load = class_name.to_s

      exception = class_is_ui_load.include?("PokemonLoad_Scene") ? true : false
      if exception 
        echo_color("Has editado la ui: UI_Load, por lo que se usara el nombre predeterminado de tu ordenador") 
        return pbGetUserName
      end
      return $player.name rescue pbGetUserName
    end
  end
  
end