module UI_Editor
  

  # Controlador Visual
  # Visual Handler 
  VisualFocus = Struct.new(:all_data, :stats, :vis)  do
    include MiolUtils
    def reset
      each_object() do |obj|
        next unless obj.respond_to?(:tone) && self.stats[obj.object_id]
        ot = self.stats[obj.object_id][:tone]
        obj.tone.set(ot.red, ot.green, ot.blue, ot.gray)
      end
    end

    def update(current_sprite)
      
      settings = UI_Editor.settings
      theme_key = settings.active_theme
      
      
      t = if theme_key == :CUSTOM
            settings.custom_tone
          else
            Settings_UI_Editor::SELECTION_THEMES_UI[theme_key]
          end
      t ||= [0, 0, 0, 0]

      
      bg_opacity = settings.bg_dim_opacity
      bg = [-80, -80, -80, bg_opacity] 

      
      each_object() do |obj|
        if obj == current_sprite
          obj.visible = true
          obj.tone.set(*t) if obj.respond_to?(:tone)
        else
          
          obj.visible = self.vis[obj.object_id]
          obj.tone.set(*bg) if obj.respond_to?(:tone)
        end
      end
    end

    def record_all_initial_values
      each_object() do |obj|
        self.stats[obj.object_id] = {
          :x => get_val(obj, :x), :y => get_val(obj, :y), :z => get_val(obj, :z),
          :zoom => get_val(obj, :zoom, 1.0),:opacity => get_val(obj, :opacity, 255), 
          :angle => get_val(obj, :angle, 0),
          :tone => obj.respond_to?(:tone) ? obj.tone.clone : Tone.new(0,0,0,0)
        }
        
    
        if obj.is_a?(VirtualPointProxy) && (obj.type == :const || obj.type == :hash_const)
          
          klass = Object.const_get(obj.owner_class) rescue nil
          if klass
            self.stats[obj.object_id][:original_source] = klass.const_source_location(obj.var_name)
          end
        end

        self.vis[obj.object_id] = obj.visible
  
      end
    end

    
    
    def each_object
      self.all_data.each_value do |cat|
        cat.each_value do |entry|
          objs = [entry[:main]] + entry[:internals].values
          objs.compact.each do |obj|
            next if obj.disposed?
            yield(obj)
          end
        end
      end
    end


  end

  class Undo
    include MiolUtils
    attr_reader :stack

    # Máximo de cambios que serán guardados en history para evitar consumo excesivo de memoria.

    # Max history size retained to prevent excessive memory usage.
    
    MAX_STEPS = 50 
    def initialize
        @history = []
    end
    

    def record(obj, props)
      return if !obj || obj.disposed? 

      props = [props] unless props.is_a?(Array)

      snapshot = {
        obj: obj,
        data: {}
      }

      props.each do |p|
        if obj.respond_to?(p) || [:x, :y, :ox, :oy, :zoom, :angle, :z].include?(p)
          snapshot[:data][p] = get_val(obj, p)
        end
      end

      @history.push(snapshot)
      @history.shift if @history.size > MAX_STEPS
    end

    def undo
      return false if @history.empty?
      
      last_snapshot = @history.pop
      obj = last_snapshot[:obj]
      
      if obj && !obj.disposed?
        
        last_snapshot[:data].each do |prop, val|
          set_val(obj, prop, val)
        end
        return true
      end
      return false
    end

    def clear_history_undo
      @history.clear
    end
  end
  
  AABB = Struct.new(:x1, :y1, :x2, :y2, :cx, :cy, :width, :height) 
    
  module SnapOfEdge

    # Distancia máxima para que el snap se active
    # Max snap distance threshold.
    THRESHOLD = 8 
    def self.apply_snap(current_obj, all_data)
      my_box = MiolUtils.aabb(current_obj)
      return [nil, nil] if !my_box

      snap_x, snap_y = nil, nil
      min_dist_x = THRESHOLD + 1
      min_dist_y = THRESHOLD + 1
      
      max_magnet_size_w = Graphics.width * 0.7
      max_magnet_size_h = Graphics.height * 0.7
      proximity_limit = 120 

      all_data.each_value do |category|
        category.each_value do |entry|
          other = entry[:main]
          next if !other || other == current_obj || other.disposed? || !other.visible
          other_box = MiolUtils.aabb(other)
          next if !other_box || (other_box.width > max_magnet_size_w && other_box.height > max_magnet_size_h)

          # --- LÓGICA DE SNAP X (Alineación Vertical) ---
          dist_y = (my_box.cy - other_box.cy).abs
          if dist_y < proximity_limit

            [[my_box.x1, other_box.x1], [my_box.x2, other_box.x2], [my_box.cx, other_box.cx],
            [my_box.x1, other_box.x2], [my_box.x2, other_box.x1]].each do |mine, theirs|
              diff = (mine - theirs).abs
              if diff < min_dist_x
                min_dist_x = diff
                snap_x = MiolUtils.get_val(current_obj, :x) - (mine - theirs)
              end
            end
          end

          
          dist_x = (my_box.cx - other_box.cx).abs
          if dist_x < proximity_limit
            [[my_box.y1, other_box.y1], [my_box.y2, other_box.y2], [my_box.cy, other_box.cy],
              [my_box.y1, other_box.y2], [my_box.y2, other_box.y1]].each do |mine, theirs|
              diff = (mine - theirs).abs
              if diff < min_dist_y
                min_dist_y = diff
                snap_y = MiolUtils.get_val(current_obj, :y) - (mine - theirs)
              end
            end
          end
        end
      end


      if snap_x && snap_y && min_dist_x < THRESHOLD && min_dist_y < THRESHOLD
        if min_dist_x <= min_dist_y
          snap_y = nil 
        else
          snap_x = nil 
        end
      end

      return [snap_x, snap_y]
    end
  end
  
  # modulo de recolector de basura para imágenes del historial
  # module for garbage collection of history images
  module DeleteUnusedScreenshots

    PATH_MD = "Graphics/Plugins/UI_Editor/UI_Changes_History.md"
    PATH_SHOTS = "Graphics/Plugins/UI_Editor/Screenshots"
    module_function


    def search_in_markdown
      file = PATH_MD
      img_usadas = []

      if File.exist?(PATH_MD)
        contenido = File.read(file)

        contenido.scan(/Screenshots\/([^\s\)]+)/) do |img|
          img_usadas << img[0]
        end
      end
      return img_usadas
    end

    def search_in_screenshots
      if Dir.exist?(PATH_SHOTS) 
        return Dir.glob("#{PATH_SHOTS}/*.png").map { |f| File.basename(f) }
      end
      return [] #  devolvemos un array vacío si la carpeta no existe
                #  return an empty array if the folder doesn't exist
    end

    def delete_unused
      file_in_used = search_in_markdown
      files_shots = search_in_screenshots
      contador_delete = 0
      if file_in_used.empty?
        shots_in_folder = files_shots.map { |img| File.join(PATH_SHOTS, img) }
        
        shots_in_folder.each do |file|
          File.delete(file) if File.exist?(file)
        end
        return 
      end
      files_shots.each do |img|
        archivo_eliminar = file_in_used.include?(img)
        unless archivo_eliminar
          
          File.delete(File.join(PATH_SHOTS, img))
          contador_delete += 1
        end
      end
      if contador_delete > 0
        echoln ">>> UI Editor: Se eliminaron #{contador_delete} archivos de captura de pantalla no utilizados."
      end
    end
  end



  # Módulo para manejo de Contexto de la scene al editar, para evitar "omnisciencia total" 

  module SceneContext

    PAGE_MAP = {
      "PokemonSummary_Scene"     => :@page,
      "PokemonPokedexInfo_Scene" => :@page,
      
    }

    DEX_PAGES = {
      1 => "INFO",
      2 => "AREA",
      3 => "FORMS"
    }

    def self.get_page(scene)
      var = PAGE_MAP[scene.class.name]
      return nil if !var
      return scene.instance_variable_get(var)
    end

    def self.match_page?(key, current_page, scene)
      return true if current_page.nil?
      scene_class = scene.class.name
      case scene_class
      when "PokemonSummary_Scene"
        if key.to_s =~ /P(\d+)_/
          return $1.to_i == current_page
        end
      end
      true 
    end




  end










end



#--------------------------------------------------------------------------
#
#--------------------------------------------------------------------------


UIEditorCommandKEYS = Struct.new(:keys) do

  def symbol_to_string
    new_string = {}

    each_hash_keys() do |key, value|

      if value.is_a?(Symbol)

        new_string[key] = value.to_s
      end
      
    end

      return new_string

  end


  def string_to_symbol
    new_symbol = {}

    each_hash_keys() do |key, value|

      if value.is_a?(String)

        new_symbol[key] = value.to_sym

      end
    end

    return new_symbol
  end

  def each_hash_keys
    

    self.keys.each do |key, value|
      yield(key, value)
    end


  end
end