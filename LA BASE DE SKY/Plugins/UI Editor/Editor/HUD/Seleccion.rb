module UI_Editor
  
  class Seleccion
    attr_accessor :sub_mode, :sub_index, :main_key, :all_data, :main_index, :mode

    def initialize(all_data)
      @all_data = all_data
      @mode = :sprite
      @main_index = 0
      @sub_index = 0
      @sub_mode = false
      refresh_keys()
    end

    def set_mode(new_mode)
      @mode = new_mode
      refresh_keys()
    end

    def refresh_keys
      @current_category = @all_data[@mode] || {}
      scene = UI_Editor::ControlEditor.scene

      current_page = SceneContext.get_page(scene)

      @main_keys = @current_category.keys.select do |k|
        entry = @current_category[k]
        obj = entry[:main]

        next false unless SceneContext.match_page?(k, current_page, scene)

        if current_page && obj.respond_to?(:visible)
          # Excepción: Siempre mostrar el fondo y el Pokémon principal
          is_global = k.to_s.match?(/background|pokemon/i)
          next true if is_global
          next false unless obj.visible
        end

        true
      end
      @main_index = 0 if @main_index >= @main_keys.length
    end
    


    def current_entry
      return nil if @main_keys.empty?
      @current_category[@main_keys[@main_index]]
    end
    
    def current_sprite
      entry = current_entry()
      return nil if !entry
      if @sub_mode && !entry[:internals].empty?
        return entry[:internals].values[@sub_index]
      else
        return entry[:main]
      end
    end

    def name_for_object
      return "Vacío" if @main_keys.empty?
      name = @main_keys[@main_index].to_s
      if @sub_mode && current_entry && !current_entry[:internals].empty?
        sub_key = current_entry[:internals].keys[@sub_index]
        name += " > #{sub_key}"
      end

      return name
      
    end

    def nexts(step = 1)
      if @sub_mode
        keys = current_entry[:internals].keys
        @sub_index = (@sub_index + step) % keys.length
      else
        return if @main_keys.empty?
        @main_index = (@main_index + step) % @main_keys.length
        @sub_index = 0
      end
    end

    def prev(step = 1); nexts(-step); end

    def toggle_sub
      if !@sub_mode && current_entry && !current_entry[:internals].empty?
        @sub_mode = true
        @sub_index = 0
        return true
      elsif @sub_mode
        @sub_mode = false
        return true 
      end
      false 
    end
    
    
    def jump_to(index)
      if index >= 0 && index < @main_keys.length
        @main_index = index
        @sub_index = 0
        @sub_mode = false
      end
    end

    def main_keys_labels;  @main_keys.map { |k| k.to_s.gsub(/CONST: |VAR: /, "").capitalize }; end
    

    def sub_mode?; return @sub_mode; end
    

    



  end
  
end
