module UI_Editor
  class MouseInputHandler
    include MiolUtils
    attr_accessor :enabled

    def initialize(editor)
      @editor  = editor
      @sel     = editor.seleccion
      @mov     = editor.handler_movement
      @vis     = editor.handler_visual
      @enabled = false
      @dragging = false
    end

    def update
      return false unless @enabled && Mouse.active?
      
      changed = false
      
      
      Mouse.show if @enabled
      
      if Mouse.click?(:left) && !@dragging
        changed = check_selection_click
      end

      
      changed ||= handle_dragging

      
      changed ||= handle_wheel_zoom

      return changed
    end

    def toggle
      @enabled = !@enabled
      @enabled ? Mouse.show : Mouse.hide
      if @enabled 
        pbMessage("Soporte de mouse activado")
      else
        pbMessage("Soporte de mouse desactivado")
      end
      pbPlayDecisionSE
    end

    private

    
    def check_selection_click
      
      @sel.all_data.each_value do |category|
        category.each do |key, entry|
         
          entry[:internals].each do |sub_key, sub_obj|
            next if !sub_obj || sub_obj.disposed? || !sub_obj.visible
            
            if Mouse.over_accurate?(sub_obj)
              select_object(key, entry, sub_key)
              return true
            end
          end

          
          main_obj = entry[:main]
          next if !main_obj || main_obj.disposed? || !main_obj.visible
          
          if Mouse.over_accurate?(main_obj)
            select_object(key, entry)
            return true
          end
        end
      end
      false
    end

    def select_object(main_key, entry, sub_key = nil)
    
      idx = @sel.all_data[@sel.mode].keys.index(main_key)
      if idx
        @sel.jump_to(idx)
        if sub_key
        
        # ! Corregir sub-mode
          @sel.sub_mode = true
          @sel.sub_index = entry[:internals].keys.index(sub_key) || 0
        end
        @vis.update(@sel.current_sprite)
        @editor.refresh_hud = true
        pbPlayCursorSE
      end
    end

    def handle_dragging
      s = @sel.current_sprite
      return false if !s || s.disposed? || s.is_a?(VirtualPointProxy)

      if Mouse.press?(:left) && Mouse.over_accurate?(s) && !@dragging
        @editor.undo.record(s, [:x, :y])
        @dragging = true

        @m_offset_x = Input.mouse_x - MiolUtils.get_val(s, :x)
        @m_offset_y = Input.mouse_y - MiolUtils.get_val(s, :y)
      end

      if @dragging
        if Mouse.press?(:left)

          new_x = Input.mouse_x - @m_offset_x
          new_y = Input.mouse_y - @m_offset_y
          
          MiolUtils.set_val(s, :x, new_x)
          MiolUtils.set_val(s, :y, new_y)
          return true
        else
          @dragging = false
        end
      end
      false
    end

    def handle_wheel_zoom
      s = @sel.current_sprite
      return false if !s || s.disposed? || !s.respond_to?(:zoom_x)

      if Mouse.scroll_up?
        @editor.undo.record(s, [:zoom_x, :zoom_y])
        s.zoom_x = s.zoom_y = (s.zoom_x + 0.1).round(2)
        return true
      elsif Mouse.scroll_down?
        @editor.undo.record(s, [:zoom_x, :zoom_y])
        s.zoom_x = s.zoom_y = [(s.zoom_x - 0.1).round(2), 0.1].max
        return true
      end
      false
    end
  end
end