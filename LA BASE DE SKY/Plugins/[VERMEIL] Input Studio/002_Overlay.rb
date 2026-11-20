# frozen_string_literal: true
# Game-side F1 overlay. Drawn with RGSS sprites; no external webview required.
module InputStudio
  class Overlay
    TEXT = Color.new(226, 235, 250)
    MUTED = Color.new(153, 171, 196)
    ACCENT = Color.new(94, 178, 251)
    CATEGORIES = ["Todos", "General", "Movimiento", "Exploración", "Menús", "Combate", "Bifröst"].freeze

    def initialize
      @device = "keyboard"
      @category = "Todos"
      @row = 0
      @offset = 0
      @slot = 0
      @capture = nil
      @pending = nil
      @reset_pending = false
      @previous = []
      @message = "Selecciona una casilla y pulsa Enter para asignar"
      @open = true
      @sprite = Sprite.new
      @sprite.z = 999_999
      resize
    end
    def resize
      @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
      @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      @width = Graphics.width
      @height = Graphics.height
    end
    def draw_text(x, y, w, text, size = 17, color = TEXT, align = 0)
      b = @sprite.bitmap
      b.font.size = size
      b.font.color = color
      b.draw_text(x.to_i, y.to_i, [w.to_i, 1].max, 25, text.to_s, align)
    end
    def rect(x, y, w, h, color)
      @sprite.bitmap.fill_rect(x.to_i, y.to_i, [w.to_i,1].max, [h.to_i,1].max, color)
    end
    def categories
      ["Todos"] + InputStudio.definitions.values.map { |r| r["category"] }.uniq
    end
    def rows
      rows = InputStudio.definitions.values
      return rows if @category == "Todos"
      rows.select { |r| r["category"] == @category }
    end
    def available
      # The scrolled rows must end ABOVE the counter and the bottom help box.
      top = 125
      bottom = @height - 89 - 26
      [[(bottom - top) / 33, 1].max, 20].min
    end
    def current
      rows[@row]
    end
    def clamp
      @row = [[@row, rows.size - 1].min, 0].max
      @offset = [[@offset, @row].min, 0].max
      @offset = @row if @row < @offset
      @offset = @row - available + 1 if @row >= @offset + available
    end
    def paint
      resize if Graphics.width != @width || Graphics.height != @height
      b = @sprite.bitmap
      b.clear
      w, h = @width, @height
      left = 13
      table_w = w - 26
      @table_top = 125
      @row_height = 33
      @footer_top = h - 89
      @list_bottom = @footer_top - 26
      rect(0, 0, w, h, Color.new(8, 13, 25, 245))
      rect(12, 10, w - 24, 53, Color.new(21, 34, 54))
      rect(12, 10, 5, 53, ACCENT)
      draw_text(24, 14, 252, "INPUT STUDIO", 21)

      # Visible, mouse-accessible factory reset. Confirmation is mandatory.
      @reset_button = [w - 311, 15, 136, 29]
      bx, by, bw, bh = @reset_button
      rect(bx, by, bw, bh, @reset_pending ? Color.new(124, 67, 65) : Color.new(71, 52, 65))
      draw_text(bx + 3, by + 2, bw - 6, @reset_pending ? "CONFIRMAR RESET" : "RESTAURAR TODO", 12, TEXT, 1)
      draw_text(w - 165, 19, 147, @device == "keyboard" ? "TECLADO [TAB]" : "MANDO [TAB]", 12, ACCENT, 2)
      draw_text(17, 52, w - 34, "F1: cerrar | Arriba/Abajo: accion | Enter/clic: editar", 12, MUTED)

      cats = categories
      tab_x, tab_y = 13, 75
      cat_w = [(table_w.to_f / [cats.size, 1].max).to_i, 50].max
      @category_hitboxes = []
      cats.each_with_index do |cat, index|
        x = tab_x + index * cat_w
        break if x + 35 > w - 10
        width = [cat_w - 3, w - x - 12].min
        rect(x, tab_y, width, 26, @category == cat ? Color.new(43, 85, 124) : Color.new(25, 39, 58))
        draw_text(x + 3, tab_y, width - 6, cat, 12, @category == cat ? TEXT : MUTED, 1)
        @category_hitboxes << [x, tab_y, width, 26, cat]
      end

      label_w = [(table_w * 0.45).to_i, 145].max
      key_w = (table_w - label_w - 12) / 2
      rect(left, 103, table_w, @footer_top - 106, Color.new(19, 29, 45))
      draw_text(left + 9, 101, label_w - 12, "ACCION", 12, ACCENT)
      draw_text(left + label_w, 101, key_w - 3, "PRINCIPAL [1]", 12, ACCENT, 1)
      draw_text(left + label_w + key_w, 101, key_w - 3, "SECUNDARIA [2]", 12, ACCENT, 1)
      rows[@offset, available].to_a.each_with_index do |action, i|
        j = i + @offset
        y = @table_top + i * @row_height
        selected = j == @row
        rect(left + 4, y, table_w - 8, @row_height - 3, selected ? Color.new(40, 69, 100) : Color.new(25, 37, 54))
        draw_text(left + 10, y + 2, label_w - 16, action["label"], 14, selected ? TEXT : MUTED)
        bindings = InputStudio.bindings(action["id"], @device)
        2.times do |slot|
          cx = left + label_w + key_w * slot
          focused = selected && @slot == slot
          rect(cx + 2, y + 2, key_w - 5, @row_height - 7, focused ? Color.new(65, 108, 146) : Color.new(35, 53, 75))
          key = bindings[slot] || "+ ASIGNAR"
          draw_text(cx + 4, y + 2, key_w - 9, key, 13, focused ? TEXT : (bindings[slot] ? ACCENT : MUTED), 1)
        end
      end

      # Counter sits outside the row viewport, even at 640x480.
      count_text = "Accion #{@row + 1}/#{rows.size}   (#{@offset + 1}-#{[@offset + available, rows.size].min} visibles)"
      draw_text(left + 8, @list_bottom + 1, table_w - 15, count_text, 11, MUTED, 2)

      rect(left, @footer_top, table_w, h - @footer_top - 13, Color.new(24, 36, 53))
      fy = @footer_top + 2
      if @reset_pending
        draw_text(23, fy, w - 45, "RESTABLECER TODOS LOS CONTROLES", 14, ACCENT)
        draw_text(23, fy + 23, w - 45, "Se restauraran teclado Y mando a sus valores iniciales.", 12, TEXT)
        draw_text(23, fy + 46, w - 45, "Enter/A o clic en confirmar | Esc/B: cancelar", 12, MUTED)
      elsif @capture
        name = @capture[:slot] == 0 ? "PRINCIPAL" : "SECUNDARIA #{@capture[:slot]}"
        draw_text(23, fy, w - 45, "ESPERANDO: #{name}", 14, ACCENT)
        draw_text(23, fy + 23, w - 45, "Pulsa una tecla o boton. Esc / F1: cancelar", 12, TEXT)
        draw_text(23, fy + 46, w - 45, @message, 12, MUTED)
      elsif @pending
        draw_text(23, fy, w - 45, "CONFLICTO: Enter/A confirma, Esc/B cancela", 13, ACCENT)
        draw_text(23, fy + 23, w - 45, @message, 12, TEXT)
      else
        draw_text(23, fy, w - 45, "Enter: asignar | Izq/Der: casilla | Supr: quitar", 13, TEXT)
        draw_text(23, fy + 23, w - 45, "1-4: asignacion | R: restaurar | Shift+R: todo", 12, MUTED)
        extra = ""
        if current
          keys = InputStudio.bindings(current["id"], @device)
          extra = " [3] #{keys[2] || '-'}  [4] #{keys[3] || '-'}" if keys.length > 2 || @slot > 1
        end
        draw_text(23, fy + 46, w - 45, @message + extra, 11, ACCENT)
      end
    end
    def raw
      if @device == "keyboard"
        Input.respond_to?(:raw_key_states) ? Input.raw_key_states : []
      else
        defined?(Input::Controller) && Input::Controller.respond_to?(:raw_button_states) ? Input::Controller.raw_button_states : []
      end
    rescue StandardError
      []
    end
    def capture_start(slot)
      return unless current
      @capture = { :id=>current["id"], :slot=>slot }
      @pending = nil
      @previous = raw.dup
      @message = "Esperando entrada física; pulsa una tecla o botón nuevo."
    end
    def capture_tick
      states = raw
      indexed = @device == "keyboard" ? InputStudio::SCAN : InputStudio::PAD.each_with_index.to_h
      # Read physical SDL state transitions, independent of the RGSS aliases.
      discovered = indexed.find do |_name, number|
        states[number] && !@previous[number]
      end
      # Some mkxp builds do not expose raw_*_states. In that case, use the
      # physical extended trigger API instead of leaving capture nonfunctional.
      if !discovered && states.empty?
        discovered = indexed.find do |name, _number|
          @device == "keyboard" ? trigger_key(name) : pad_trigger(name)
        end
      end
      @previous = states.dup
      return unless discovered
      key = discovered[0]
      if key == "ESCAPE" || key == "F1" || (key == "BACK" && @device == "gamepad")
        @capture = nil
        @message = "Captura cancelada"
        return
      end
      id = @capture[:id]
      slot = @capture[:slot]
      @capture = nil
      conflicts = InputStudio.conflicts(id, @device, key)
      unless conflicts.empty?
        @pending = { :id=>id, :device=>@device, :key=>key, :slot=>slot }
        @message = "#{key} está en: #{conflicts.join(', ')}"
        return
      end
      if InputStudio.assign(id, @device, key, slot)
        @message = "#{key} asignada y guardada"
      else
        @message = InputStudio.status.to_s
      end
    end
    def pending_tick
      if trigger_key("ESCAPE") || trigger_key("F1") || pad_trigger("B") || pad_trigger("BACK")
        @pending = nil
        @message = "Reasignación cancelada"
        return
      end
      return unless trigger_key("RETURN") || pad_trigger("A")
      item = @pending
      @pending = nil
      if InputStudio.assign(item[:id], item[:device], item[:key], item[:slot], true)
        @message = "#{item[:key]} reasignada; conflicto resuelto y perfil guardado"
      else
        @message = InputStudio.status.to_s
      end
    end
    def trigger_key(key)
      InputStudio.key_query(key, :triggerex?)
    end
    def pad_trigger(key)
      InputStudio.pad_query(key, :triggerex?)
    end
    def navigate(delta)
      @row = (@row + delta).clamp(0, [rows.size - 1, 0].max)
      clamp
    end
    def choose_category(delta)
      index = categories.index(@category) || 0
      @category = categories[(index + delta) % categories.length]
      @row = 0
      @offset = 0
      clamp
    end
    def mouse_tick
      return unless Input.respond_to?(:mouse_x) && Input.respond_to?(:mouse_y)
      return unless Input.input_studio_native_trigger?(Input::MOUSELEFT)
      mx, my = Input.mouse_x, Input.mouse_y
      return unless mx && my
      bx, by, bw, bh = @reset_button
      if mx >= bx && mx < bx + bw && my >= by && my < by + bh
        @reset_pending ? confirm_reset : begin_reset
        return
      end
      return if @reset_pending
      (@category_hitboxes || []).each do |x, y, width, height, cat|
        next unless mx >= x && mx < x + width && my >= y && my < y + height
        @category = cat
        @row = 0
        @offset = 0
        clamp
        return
      end
      return unless my >= @table_top && my < @table_top + available * @row_height
      left = 13
      table_w = @width - 26
      return unless mx >= left && mx < left + table_w
      index = (my - @table_top) / @row_height + @offset
      return unless index >= 0 && index < rows.size
      @row = index
      label_w = [(table_w * 0.45).to_i, 145].max
      key_w = (table_w - label_w - 12) / 2
      if mx >= left + label_w
        @slot = (mx >= left + label_w + key_w) ? 1 : 0
        capture_start(@slot)
      end
      clamp
    end
    def begin_reset
      @reset_pending = true
      @message = "Restaurar todas las asignaciones de ambos dispositivos?"
    end
    def confirm_reset
      @reset_pending = false
      if InputStudio.reset
        @slot = 0
        @message = "Todas las asignaciones restauradas y guardadas"
      else
        @message = InputStudio.status.to_s
      end
    end
    def reset_tick
      if trigger_key("ESCAPE") || trigger_key("F1") || pad_trigger("B") || pad_trigger("BACK")
        @reset_pending = false
        @message = "Restauracion cancelada"
      elsif trigger_key("RETURN") || pad_trigger("A")
        confirm_reset
      else
        mouse_tick
      end
    end
    def normal_tick
      return pending_tick if @pending
      return reset_tick if @reset_pending
      if trigger_key("F1") || trigger_key("ESCAPE") || pad_trigger("BACK")
        @open = false
        return
      end
      if trigger_key("TAB")
        @device = @device == "keyboard" ? "gamepad" : "keyboard"
        @message = @device == "keyboard" ? "Teclado seleccionado" : "Mando seleccionado"
      elsif trigger_key("UP") || pad_trigger("DPAD_UP")
        navigate(-1)
      elsif trigger_key("DOWN") || pad_trigger("DPAD_DOWN")
        navigate(1)
      elsif trigger_key("LEFT") || pad_trigger("DPAD_LEFT")
        @slot = [@slot - 1, 0].max
      elsif trigger_key("RIGHT") || pad_trigger("DPAD_RIGHT")
        @slot = [@slot + 1, 3].min
      elsif trigger_key("1")
        @slot = 0
        capture_start(@slot)
      elsif trigger_key("2")
        @slot = 1
        capture_start(@slot)
      elsif trigger_key("3")
        @slot = 2
        capture_start(@slot)
      elsif trigger_key("4")
        @slot = 3
        capture_start(@slot)
      elsif trigger_key("RETURN") || pad_trigger("A")
        capture_start(@slot)
      elsif trigger_key("DELETE") || trigger_key("BACKSPACE")
        if current && InputStudio.clear_slot(current["id"], @device, @slot)
          @message = "Casilla quitada; las demas teclas se conservan"
        else
          @message = InputStudio.status.to_s
        end
      elsif (trigger_key("R") && (InputStudio.key_query("LSHIFT", :pressex?) ||
                                 InputStudio.key_query("RSHIFT", :pressex?))) ||
            pad_trigger("Y")
        begin_reset
      elsif trigger_key("R")
        if current && InputStudio.reset(current["id"])
          @message = "Accion restaurada"
        end
      end
      mouse_tick unless @capture
    end
    def run
      InputStudio.modal = true
      paint
      while @open
        Graphics.update
        Input.update
        @capture ? capture_tick : normal_tick
        paint
      end
    rescue StandardError => e
      warn("[Input Studio] overlay error: #{e.class} #{e.message}")
    ensure
      if @sprite
        @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
        @sprite.dispose unless @sprite.disposed?
      end
      Input.update if Input.respond_to?(:update)
      InputStudio.modal = false
    end
  end
end

# Defer opening until Graphics.update: avoids reentering Input.update from
# Essentials' menus and map event processing.
module Graphics
  class << self
    alias input_studio_native_graphics_update update unless method_defined?(:input_studio_native_graphics_update)
    def update
      input_studio_native_graphics_update
      InputStudio::Overlay.new.run if InputStudio.take_overlay? && !InputStudio.modal?
    end
  end
end
