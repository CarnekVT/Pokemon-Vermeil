module UI_Editor

  class HandlerMovement

    include MiolUtils

    def initialize(seleccion, original_stats, undo)
      @seleccion = seleccion
      @original_stats = original_stats
      @undo = undo
    end

    def update
      sprite = @seleccion.current_sprite
      return false if !sprite || sprite.disposed?
      @step = Input.press?(Settings_UI_Editor::KEYS[:FAST_STEP]) ? 10 : 1

      changed = false
      
      # 1. Posición (Flechas)
      changed ||= update_position(sprite)
      
      # 2. Zoom (W/S)
      changed ||= update_zoom(sprite)

      # 3. Capas Z (Tab + AvPag/RePag)
      changed ||= update_z_layer(sprite)

      # 4. Opacidad (A/D)
      changed ||= update_opacity(sprite)

      # 5. Ángulo (Q/T)
      changed ||= update_rotation(sprite)

      # 6. Mirror (M)
      changed ||= update_mirror(sprite)

      # 7. Visibilidad (H)
      changed ||= update_visibility(sprite)
      return changed
    end

    def reset_all
      obj = @seleccion.current_sprite
      return if !obj || obj.disposed?
      
      orig = @original_stats[obj.object_id]

      return if !orig

      set_val(obj, :x, orig[:x]); set_val(obj, :y, orig[:y])
      obj.z = orig[:z] if obj.respond_to?(:z)
      obj.zoom = orig[:zoom] if obj.respond_to?(:zoom)
      obj.opacity = orig[:opacity] if obj.respond_to?(:opacity)
      obj.angle = orig[:angle] if obj.respond_to?(:angle)
      
      pbPlayCancelSE
      return true
    end
    
    def open_menu_resets

      obj = @seleccion.current_sprite
      return if !obj || obj.disposed?
      orig = @original_stats[obj.object_id]

      options = ["Reset Completo"]
      actions = [:all] 
      options.push("Posición (X/Y)"); actions.push(:pos)
      options.push("Escala (Zoom)") if obj.respond_to?(:zoom); actions.push(:zoom) if obj.respond_to?(:zoom)
      options.push("Opacidad") if obj.respond_to?(:opacity); actions.push(:opac) if obj.respond_to?(:opacity)
      options.push("Ángulo") if obj.respond_to?(:angle); actions.push(:ang) if obj.respond_to?(:angle)
      options.push("Volver")

      cmd = pbShowCommandsCustom(options, 0, (Graphics.width-280)/2, (Graphics.height-220)/2) 
      return false if cmd < 0 || cmd == options.length - 1

      case actions[cmd]
      when :all   then reset_all()
      when :pos   then set_val(obj, :x, orig[:x]); set_val(obj, :y, orig[:y])
      when :zoom  then obj.zoom = orig[:zoom] if obj.respond_to?(:zoom)
      when :opac  then obj.opacity = orig[:opacity] if obj.respond_to?(:opacity)
      when :ang   then obj.angle = orig[:angle] if obj.respond_to?(:angle)
      end
      
      pbPlayDecisionSE
      return true
    end

    private


    def update_position(sprite)
      s = sprite 
      changed = false
      keys = [Input::RIGHT, Input::LEFT, Input::UP, Input::DOWN]
      capture_point_undo(s, keys, [:x,:y])
      if Input.press?(Input::SHIFT) # Grid Snapping 8px
        grid = 8
        if Input.repeat?(keys[0])  then set_val(s, :x, ((get_val(s, :x) + grid).to_f / grid).round * grid); changed = true end
        if Input.repeat?(keys[1])  then set_val(s, :x, ((get_val(s, :x) - grid).to_f / grid).round * grid); changed = true end
        if Input.repeat?(keys[3])  then set_val(s, :y, ((get_val(s, :y) + grid).to_f / grid).round * grid); changed = true end
        if Input.repeat?(keys[2])  then set_val(s, :y, ((get_val(s, :y) - grid).to_f / grid).round * grid); changed = true end
      else # Movimiento píxel a píxel
        mult = s.respond_to?(:ox) && !s.respond_to?(:x) ? -1 : 1
        if Input.repeat?(keys[0])      then set_val(s, :x, get_val(s, :x) + @step * mult);  changed = true end
        if Input.repeat?(keys[1])      then set_val(s, :x, get_val(s, :x) - @step * mult);  changed = true end
        if Input.repeat?(keys[3])      then set_val(s, :y, get_val(s, :y) + @step * mult);  changed = true end
        if Input.repeat?(keys[2])      then set_val(s, :y, get_val(s, :y) - @step * mult);  changed = true end
      end

      if changed && Input.pressex?(Settings_UI_Editor::KEYS[:SNAP_EDGE]) 
        
        snap_x, snap_y = SnapOfEdge.apply_snap(s, @seleccion.all_data)
        if snap_x
          set_val(s, :x, snap_x)
        end
        if snap_y
          set_val(s, :y, snap_y)
        end
      end
      return changed
    end
    
    def update_zoom(sprite)
      s = sprite
      return false unless s.respond_to?(:zoom)

      keys = [Settings_UI_Editor::KEYS[:ZOOM_UP], Settings_UI_Editor::KEYS[:ZOOM_DOWN]]
      capture_point_undo(s, keys, :zoom)

      z_step = Input.press?(Settings_UI_Editor::KEYS[:FAST_STEP]) ? 0.1 : 0.01
      if Input.pressex?(keys[0])
        s.zoom = (s.zoom + z_step).round(2); return true
      elsif Input.pressex?(keys[1])
        s.zoom = [(s.zoom - z_step).round(2), 0.1].max; return true
      end
      false
    end

    def update_z_layer(sprite)
      s = sprite
      return false unless s.respond_to?(:z)
      
      

      if Input.pressex?(Settings_UI_Editor::KEYS[:Z_LAYER_TAB])
        keys = [Settings_UI_Editor::KEYS[:PLUS_Z],Settings_UI_Editor::KEYS[:MIN_Z]]
        capture_point_undo(s, keys, :z)
        step_z = Input.press?(Settings_UI_Editor::KEYS[:FAST_STEP]) ? 10 : 1
        if Input.triggerex?(Settings_UI_Editor::KEYS[:PLUS_Z])
          set_val(s, :z, get_val(s, :z) + step_z)
          
          pbPlayCursorSE
          return true
        elsif Input.triggerex?(Settings_UI_Editor::KEYS[:MIN_Z])
          set_val(s, :z, get_val(s, :z) - step_z)
          pbPlayCursorSE
          return true
        end
      end
      false
    end

    def update_opacity(s)
      return false unless s.respond_to?(:opacity)
      keys = [Settings_UI_Editor::KEYS[:OPACITY_UP], Settings_UI_Editor::KEYS[:OPACITY_DOWN]]
      capture_point_undo(s, keys, :opacity)
      if Input.pressex?(Settings_UI_Editor::KEYS[:OPACITY_UP])
        set_val(s, :opacity, (get_val(s, :opacity) + @step).clamp(0, 255)); return true
      elsif Input.pressex?(Settings_UI_Editor::KEYS[:OPACITY_DOWN])
        set_val(s, :opacity, (get_val(s, :opacity) - @step).clamp(0, 255)); return true
      end
      false
    end

    def update_rotation(s)
      return false unless s.respond_to?(:angle)
      keys = [Settings_UI_Editor::KEYS[:ROTATE_L], Settings_UI_Editor::KEYS[:ROTATE_R]]
      capture_point_undo(s, keys, :angle)
      if Input.pressex?(Settings_UI_Editor::KEYS[:ROTATE_L])
        set_val(s, :angle, (get_val(s, :angle) - @step) % 360); return true
      elsif Input.pressex?(Settings_UI_Editor::KEYS[:ROTATE_R])
        set_val(s, :angle, (get_val(s, :angle) + @step) % 360); return true
      end
      false
    end


    def update_mirror(s)
      return false unless s.respond_to?(:mirror)
      changed = false
      keys = [Settings_UI_Editor::KEYS[:MIRROR]]
      capture_point_undo(s, keys, :mirror)
      if s.respond_to?(:mirror) && Input.triggerex?(keys[0])
        capture_point_undo(s, keys[0], :mirror)
        s.mirror = !s.mirror
        pbPlayDecisionSE
        changed = true
      end
      return changed
    end

    def update_visibility(s)
      return false unless s.respond_to?(:visible)
      changed = false 
      keys = [Settings_UI_Editor::KEYS[:HIDE_TOGGLE]]
      capture_point_undo(s, keys, :visible)

      if Input.triggerex?(keys[0])
        capture_point_undo(s, keys[0], :visible)
        s.visible = !s.visible
        pbPlayDecisionSE
        changed = true
      end
      return changed
    end


    def capture_point_undo(s, keys, props)

      keys = [keys] unless keys.is_a?(Array)

      pressed = keys.any? do |k|
        if k.is_a?(Symbol) || (k.is_a?(Integer) && k > 20)
          Input.triggerex?(k)
        else
          Input.trigger?(k)
        end
      end

      @undo.record(s, props) if pressed
    end

  end

end