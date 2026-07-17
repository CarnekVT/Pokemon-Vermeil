# ! ===================================================
# ! RECORDAR REFACTORIZAR HELPER
# ! ===================================================
# Proxy para convertir datos abstractos en objetos manipulables por el Editor
class VirtualPointProxy
  attr_accessor :name, :parent, :var_name, :type, :owner_class, :hash_key, :array_index

  def initialize(parent, var_name, type = :ivar, hash_key = nil, array_index = nil)
    @parent      = parent   
    @var_name    = var_name 
    @type        = type
    @hash_key    = hash_key
    @array_index = array_index     
    @owner_class = parent.class.name 

     # Determinamos el eje
    name_up = var_name.to_s.upcase
    # ! Debo unificar los regex y refactorizar el helper
    if @type == :hash_const
      @axis = (array_index == 1) ? :y : :x
    elsif name_up.end_with?("_Y", "HEIGHT", "TOP", "OY", "_Y2", "_Y1", "_Y_OFFSET") # Prioridad al final
      @axis = :y
    elsif name_up.end_with?("_X", "WIDTH", "LEFT", "OX", "_X2", "_X1", "_X_OFFSET")
      @axis = :x
    else
      
      @axis = (name_up.match?(/Y|HEIGHT/)) ? :y : :x
    end
    
   
  end

      
  
  



  def x
    return 0 if @axis == :y 

    if @type == :hash_const
      return @parent.class.const_get(@var_name)[@hash_key][@array_index]
    end

    return @type == :ivar ? @parent.instance_variable_get(@var_name) : @parent.class.const_get(@var_name)
  end

  def y
    return 0 if @axis == :x 
    if @type == :hash_const
      return @parent.class.const_get(@var_name)[@hash_key][@array_index]
    end
    return @type == :ivar ? @parent.instance_variable_get(@var_name) : @parent.class.const_get(@var_name)
  end

  def x=(v)
    return if @axis == :y 
    set_val(v)
  end
  def y=(v)
    return if @axis == :x 
    set_val(v)
  end
  
  def set_val(v)
    return if v.nil?
    if @type == :ivar
      @parent.instance_variable_set(@var_name, v)
    

    elsif @type == :hash_const
      # Si es un Hash de Coordenadas en una Constante
      hash = @parent.class.const_get(@var_name)
      hash[@hash_key][@array_index] = v
    else
      
      UI_Editor::Consts.apply(@parent.class, @var_name, v)
    end
    
    return unless $DEBUG && UI_Editor::ControlEditor.active?
    # ! Debo crear una mjor manera de controlar los metodos de recarga
    # ? Hacerlo mas modular?
    # 
    if @parent.is_a?(PokemonPokedex_Scene) && @parent.instance_variable_get(:@sprites)["searchbg"]&.visible
      
      params = @parent.instance_variable_get(:@searchParams)
      cursor = @parent.instance_variable_get(:@sprites)["searchcursor"]
      
      if @parent.respond_to?(:pbRefreshDexSearch)
        
        if cursor.instance_variable_get(:@mode) == -1
          @parent.pbRefreshDexSearch(params, cursor.index)
        else

          @parent.pbRefreshDexSearch(params, cursor.index)
        end
        return 
      end
    end

    
    if @parent.respond_to?(:drawPage) && @parent.instance_variable_defined?(:@page)
      @parent.send(:drawPage, @parent.instance_variable_get(:@page))
      return 
    end
    
  


    metodos_maestros = [:pbUpdateOverlay, :update_overlay, :refresh, :pbRefresh]
    metodos_maestros.each do |m|
      if @parent.respond_to?(m)
        @parent.send(m)
        return 
      end
    end

    # 3. REFRESCADO ESPECÍFICO 
    especificos = [:draw_info, :draw_items, :draw_text, :draw_name, :draw_level, :pbDrawTrainerCardFront,
    :drawPageOne, :drawPageTwo, :drawPageThree, :drawPageFour, :drawPageFive]
    especificos.each do |m|
      if @parent.respond_to?(m)
        method_obj = @parent.method(m)
        
        if method_obj.arity == 0 # Si la aridad del metodo es 0, lo mandamos tal cual
          @parent.send(m)
        else
          
          idx = @parent.instance_variable_get(:@index) rescue nil
          @parent.send(m, idx) if idx
        end
      end
    end
  end


  def z; 999; end; def z=(v); end
  def ox; 0; end; def ox=(v); end; def oy; 0; end; def oy=(v); end
  def zoom; 1.0; end; def zoom=(v); end
  def opacity; 255; end; def opacity=(v); end
  def angle; 0; end; def angle=(v); end
  def mirror; false; end; def mirror=(v); end
  def visible; true; end; def visible=(v); end
  def disposed?; false; end
  def tone; Tone.new(0,0,0); end; def tone=(v); end
#################################################
  def get_patch_path
    if @type == :hash_const
      # Devuelve: PAGE_INFO_COORDS[:species_name][0]
      return "#{@var_name}[:#{@hash_key}][#{@array_index}]"
    elsif @type == :ivar
      return @var_name.to_s
    else
      return "#{@owner_class}::#{@var_name}"
    end
  end
#################################################
end
module UI_Editor_Helper





  def self.call(scene, manual_config = {})
    unless Object.const_defined?(:UI_Editor)
      raise "Error: No se encontró UI_Editor."
    end
    @final_data = {}
    @seen_ids = {}
    @seen_classes = {}
    scan_constants(scene)
    manual_config.each_pair { |var, label| scan_object(scene.instance_variable_get(var), label, nil, scene) rescue next }
    scene.instance_variables.each do |var_sym|
      # skip blacklisted and class variables
      next if Settings_UI_Editor::BLACK_LIST.include?(var_sym)
      next if var_sym.to_s.start_with?('@@')
      obj = scene.instance_variable_get(var_sym)
      
      label = var_sym.to_s.delete("@").gsub("_", " ").capitalize
      scan_object(scene.instance_variable_get(var_sym), label, nil, scene, var_sym)
    end
    finalize_and_run(scene)
  end

  private

  def self.scan_constants(target_obj)
    
    return if !target_obj || [Array, String, Numeric, Viewport, Color, Tone, Rect].include?(target_obj.class)
    
    
    klass = target_obj.is_a?(Class) ? target_obj : target_obj.class
    
    
    return if @seen_classes[klass.name]
    @seen_classes[klass.name] = true

    
    klass.constants(true).each do |const_sym|
      begin
        name = const_sym.to_s
        
        val = klass.const_get(const_sym)

        # --- CASO A: Hash de Coordenadas (Pokédex / PAGE_INFO_COORDS) ---
        if val.is_a?(Hash) && name.upcase.include?("COORDS")
          #MiolUtils.echo_color("   Desmontando Hash #{name}...", "cian")
          
          val.each do |key, coords|
            next unless coords.is_a?(Array) 

            # Proxy para X
            label_x = "COORD: #{key} (X)"
            
            proxy_x = VirtualPointProxy.new(target_obj, const_sym, :hash_const, key, 0)
            @final_data[label_x] = { :main => proxy_x, :internals => {}, :scene_class => klass.name }

            # Proxy para Y
            label_y = "COORD: #{key} (Y)"
            proxy_y = VirtualPointProxy.new(target_obj, const_sym, :hash_const, key, 1)
            @final_data[label_y] = { :main => proxy_y, :internals => {}, :scene_class => klass.name }
          end

        
        elsif val.is_a?(Numeric)
          if name.upcase.match?(/_X\d*(_|$)|_Y\d*(_|$)|_OFFSET|_POS|_WIDTH|_HEIGHT|_CENTER/)
            proxy = VirtualPointProxy.new(target_obj, const_sym, :const)
            @final_data["CONST: #{name}"] = { :main => proxy, :internals => {}, :scene_class => klass.name }
          end
        end
      rescue => e
        next 
      end
    end
  end

  def self.scan_object(obj, label, parent_key = nil, actual_parent_obj = nil, var_sym = nil)
    return if obj.nil? || (!obj.is_a?(Numeric) && @seen_ids[obj.object_id]) || (obj.respond_to?(:disposed?) && obj.disposed?)
    scan_constants(obj) if !obj.is_a?(Numeric)
    @seen_ids[obj.object_id] = true unless obj.is_a?(Numeric)

    if obj.is_a?(Numeric)

      # determine name for matching (prefer var_sym if provided)
      name_for_check = if var_sym
                         var_sym.to_s
                       else
                         label.downcase.gsub(' ', '_')
                       end
      # strip any leading @ characters so we don't accumulate them
      name_for_check = name_for_check.gsub(/^@+/, '')
      if name_for_check.match?(/_x$|_y$|_offset$|_pos$/)
        proxy = VirtualPointProxy.new(actual_parent_obj, "@#{name_for_check}".to_sym, :ivar)
        @final_data["VAR: #{label}"] = { :main => proxy, :internals => {}, :scene_class => actual_parent_obj.class.name }
      end
      

    elsif obj.is_a?(Hash) 
       obj.each { |k, v| scan_object(v, "#{label}: #{k}", parent_key, actual_parent_obj) }
       ################################
    elsif obj.is_a?(Array) 
      ##################################
      obj.each_with_index { |v, i| scan_object(v, "#{label}[#{i}]", parent_key, actual_parent_obj) }
      ##########################################
    elsif is_visual?(obj)  #"si camina como pato"
      if parent_key
        var_id = actual_parent_obj&.instance_variables&.find { |v| actual_parent_obj.instance_variable_get(v).object_id == obj.object_id }
        @final_data[parent_key][:internals][var_id || label] = obj
      else
        @final_data[label] = { :main => obj, :internals => {}, :scene_class => actual_parent_obj&.class&.name || "Unknown" }
        scan_internals(obj, label)
      end
    else scan_internals(obj, label) end
  end
  #Implementacion del patcher (V1)
#######################################################################################
def self.find_object_path(target_obj, scene)

  if target_obj.is_a?(VirtualPointProxy)
    return target_obj.var_name.to_s
  end


  scene.instance_variables.each do |var_sym|
    begin
      val = scene.instance_variable_get(var_sym)
      return var_sym.to_s if val.object_id == target_obj.object_id
      
      
      if val.is_a?(Hash)
        val.each do |k, v|
          if v.object_id == target_obj.object_id
            key_fmt = k.is_a?(Symbol) ? ":#{k}" : "'#{k}'"
            return "#{var_sym}[#{key_fmt}]"
          end
          
          
          if v.respond_to?(:instance_variables)
            v.instance_variables.each do |internal_var|
              internal_obj = v.instance_variable_get(internal_var)
              if internal_obj.object_id == target_obj.object_id
                key_fmt = k.is_a?(Symbol) ? ":#{k}" : "'#{k}'"
                return "#{var_sym}[#{key_fmt}].instance_variable_get(#{internal_var.inspect})"
              end
            end
          end
        end
      end
    rescue; next; end
  end

  nil
end
#######################################################################################
  def self.scan_internals(parent_obj, parent_label)
    return if parent_obj.nil?
    parent_obj.instance_variables.each do |var_sym|
      # skip blacklist and class vars
      next if Settings_UI_Editor::BLACK_LIST.include?(var_sym)
      next if var_sym.to_s.start_with?('@@')
      child = parent_obj.instance_variable_get(var_sym) rescue nil
      scan_object(child, var_sym.to_s.delete("@").gsub("_", " ").capitalize, (@final_data.key?(parent_label) ? parent_label : nil), parent_obj, var_sym)
    end
  end

  def self.is_visual?(obj)
    return false if obj.is_a?(Viewport)
    return true if Settings_UI_Editor::VALID_CLASSES.any? { |klass| obj.is_a?(klass) }
    return obj.respond_to?(:x) && obj.respond_to?(:y) && (obj.respond_to?(:bitmap) || obj.respond_to?(:contents) || obj.respond_to?(:z))
  end

  
  def self.finalize_and_run(scene) # Añadir argumento scene
    echoln "Scene recibida: #{scene.class}"
    echoln "Variables de scene: #{scene.instance_variables.inspect}"
    #lista_coords = scene.class.constants(true).grep(/COORDS/)
    #MiolUtils.echo_color("--- Coordenadas encontradas: #{lista_coords} ---", "cian")
   # MiolUtils.echo_color("--- Constantes de scene #{scene.class.constants(true).inspect} ---", "verde")
    @final_data.delete_if { |k, v| v[:main].nil? }
    categorized = { :const => {}, :var => {}, :sprite => {} }

    @final_data.each do |k, v|
      
      main_obj = v[:main]
      
      
      if k.start_with?("CONST:") || k.start_with?("COORD:") || 
          (main_obj.is_a?(VirtualPointProxy) && [:const, :hash_const].include?(main_obj.type))
        categorized[:const][k] = v

      
      elsif k.start_with?("VAR:") || (main_obj.is_a?(VirtualPointProxy) && main_obj.type == :ivar)
        categorized[:var][k] = v

      
      else
        categorized[:sprite][k] = v
      end
    end
    UI_Editor::Main.new(categorized, scene)
  end

end