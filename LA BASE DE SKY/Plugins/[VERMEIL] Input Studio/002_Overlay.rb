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
      [((@height - 194) / 37).to_i, 3].max
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
      rect(0, 0, w, h, Color.new(8, 13, 25, 245))
      rect(12, 10, w - 24, 54, Color.new(21, 34, 54))
      rect(12, 10, 5, 54, ACCENT)
      draw_text(27, 16, w - 200, "INPUT STUDIO", 22)
      draw_text(w - 172, 22, 148, @device == "keyboard" ? "TECLADO [TAB]" : "MANDO [TAB]", 13, ACCENT, 2)
      draw_text(17, 65, w - 34, "Selecciona una accion y su casilla. Enter: editar | 1-4: ir a casilla", 13, MUTED)

      # A full-width action table leaves both bindings individually readable.
      cats = categories
      tab_x = 13
      tab_y = 91
      usable = w - 26
      cat_w = [usable / [cats.size, 1].max, 57].max
      @category_hitboxes = []
      cats.each_with_index do |cat, index|
        x = tab_x + index * cat_w
        break if x + 35 > w - 10
        width = [cat_w - 3, w - x - 12].min
        rect(x, tab_y, width, 29, @category == cat ? Color.new(43, 85, 124) : Color.new(25, 39, 58))
        draw_text(x + 3, tab_y + 2, width - 6, cat, 12, @category == cat ? TEXT : MUTED, 1)
        @category_hitboxes << [x, tab_y, width, 29, cat]
      end

      left = 13
      table_w = w - 26
      label_w = [(table_w * 0.46).to_i, 150].max
      key_w = (table_w - label_w - 12) / 2
      key_w = [key_w, 45].max
      @table_top = 150
      rect(left, 125, table_w, h - 224, Color.new(19, 29, 45))
      draw_text(left + 10, 125, label_w - 12, "ACCION", 12, ACCENT)
      draw_text(left + label_w, 125, key_w - 3, "PRINCIPAL [1]", 12, ACCENT, 1)
      draw_text(left + label_w + key_w, 125, key_w - 3, "SECUNDARIA [2]", 12, ACCENT, 1)
      rows[@offset, available].to_a.each_with_index do |action, i|
        j = i + @offset
        y = @table_top + i * 37
        selected = j == @row
        rect(left + 4, y, table_w - 8, 34, selected ? Color.new(40, 69, 100) : Color.new(25, 37, 54))
        draw_text(left + 10, y + 4, label_w - 16, action["label"], 14, selected ? TEXT : MUTED)
        bindings = InputStudio.bindings(action["id"], @device)
        2.times do |slot|
          cx = left + label_w + key_w * slot
          focused = selected && @slot == slot
          rect(cx + 2, y + 3, key_w - 5, 28, focused ? Color.new(65, 108, 146) : Color.new(35, 53, 75))
          key = bindings[slot] || "+ ASIGNAR"
          draw_text(cx + 4, y + 4, key_w - 9, key, 13, focused ? TEXT : (bindings[slot] ? ACCENT : MUTED), 1)
        end
      end
      if rows.size > available
        draw_text(left + 8, h - 110, table_w - 14, "Accion #{@row + 1} / #{rows.size}    Arriba/Abajo: navegar", 12, MUTED, 2)
      end

      rect(13, h - 97, w - 26, 84, Color.new(24, 36, 53))
      if @capture
        name = @capture[:slot] == 0 ? "PRINCIPAL" : "SECUNDARIA #{@capture[:slot]}"
        draw_text(23, h - 94, w - 45, "ESPERANDO: #{name}", 15, ACCENT)
        draw_text(23, h - 72, w - 45, "Pulsa una tecla o boton. Esc / F1: cancelar", 13, TEXT)
        draw_text(23, h - 47, w - 45, @message, 12, MUTED)
      elsif @pending
        draw_text(23, h - 94, w - 45, "CONFLICTO: Enter/A confirma, Esc/B cancela", 13, ACCENT)
        draw_text(23, h - 71, w - 45, @message, 12, TEXT)
      else
        draw_text(23, h - 94, w - 45, "Enter: asignar  |  Izq/Der: casilla  |  Supr: quitar casilla", 13, TEXT)
        draw_text(23, h - 72, w - 45, "1-4: elegir casilla  |  R: restaurar  |  Tab: dispositivo", 12, MUTED)
        draw_text(23, h - 49, w - 45, @message, 12, ACCENT)
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
      (@category_hitboxes || []).each do |x, y, width, height, cat|
        next unless mx >= x && mx < x + width && my >= y && my < y + height
        @category = cat
        @row = 0
        @offset = 0
        clamp
        return
      end
      return unless my >= @table_top && my < @table_top + available * 37
      left = 13
      table_w = @width - 26
      return unless mx >= left && mx < left + table_w
      index = (my - @table_top) / 37 + @offset
      return unless index >= 0 && index < rows.size
      @row = index
      label_w = [(table_w * 0.46).to_i, 150].max
      key_w = (table_w - label_w - 12) / 2
      if mx >= left + label_w
        @slot = (mx >= left + label_w + key_w) ? 1 : 0
        capture_start(@slot)
      end
      clamp
    end
    def normal_tick
      return pending_tick if @pending
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
