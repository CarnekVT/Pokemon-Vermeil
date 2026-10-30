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
      @capture = nil
      @previous = []
      @message = "Flechas: navegar | Enter: cambiar | 2: segunda tecla"
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
    def rows
      rows = InputStudio.definitions.values
      return rows if @category == "Todos"
      rows.select { |r| r["category"] == @category }
    end
    def available
      [((@height - 172) / 33).to_i, 4].max
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
      w = @width
      h = @height
      rect(0, 0, w, h, Color.new(8, 13, 25, 245))
      rect(18, 14, w - 36, 51, Color.new(21, 34, 54))
      rect(18, 14, 5, 51, ACCENT)
      draw_text(34, 22, w - 230, "INPUT STUDIO", 23)
      draw_text(w - 205, 27, 174, @device == "keyboard" ? "TECLADO  |  TAB" : "MANDO  |  TAB", 13, ACCENT, 2)
      draw_text(24, 70, w - 45, "Editor de controles  -  F1 para cerrar", 14, MUTED)
      left = [150, (w * 0.27).to_i].min
      rect(18, 99, left - 9, h - 166, Color.new(19, 29, 45))
      CATEGORIES.each_with_index do |cat, index|
        y = 105 + index * 32
        next if y > h - 100
        if @category == cat
          rect(23, y, left - 19, 29, Color.new(38, 78, 114))
        end
        draw_text(31, y + 2, left - 28, cat, 14, @category == cat ? TEXT : MUTED)
      end
      x = left + 20
      listw = w - x - 19
      rect(x, 99, listw, h - 166, Color.new(19, 29, 45))
      draw_text(x + 9, 100, listw - 15, "ACCIONES", 13, ACCENT)
      rows[@offset, available].to_a.each_with_index do |action, i|
        j = i + @offset
        y = 128 + i * 33
        selected = j == @row
        rect(x + 5, y, listw - 10, 30, selected ? Color.new(43, 73, 105) : Color.new(25, 37, 54))
        label = action["label"].to_s
        binding = InputStudio.bindings(action["id"], @device)
        labelw = [listw * 0.54, 110].max
        draw_text(x + 12, y + 3, labelw - 12, label, 14, selected ? TEXT : MUTED)
        keys = binding.empty? ? "(sin asignar)" : binding.join(" / ")
        draw_text(x + labelw, y + 3, listw - labelw - 13, keys, 13, selected ? ACCENT : TEXT, 2)
      end
      if rows.length > available
        draw_text(x + 12, h - 96, listw - 25, "#{@row+1} / #{rows.length} acciones", 12, MUTED, 2)
      end
      rect(18, h - 63, w - 36, 49, Color.new(24, 36, 53))
      if @capture
        label = @capture[:slot] == 0 ? "PRINCIPAL" : "SECUNDARIA"
        draw_text(28, h - 57, w - 56, "Pulsa una tecla / botón para #{label} · Esc cancela", 14, ACCENT)
        draw_text(28, h - 33, w - 56, @message, 12, MUTED)
      else
        draw_text(28, h - 57, w - 56, @message, 13, TEXT)
        draw_text(28, h - 33, w - 56, "Tab: dispositivo   |   Supr: quitar   |   R: restaurar   |   F1: cerrar", 11, MUTED)
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
      @previous = raw
      @message = "Esperando entrada..."
    end
    def capture_tick
      states = raw
      indexed = @device == "keyboard" ? InputStudio::SCAN : InputStudio::PAD.each_with_index.to_h
      # SDL controller raw positions are indexed in the same order as PAD.
      discovered = indexed.find do |name, number|
        states[number] && !@previous[number]
      end
      @previous = states
      return unless discovered
      key = discovered[0]
      if key == "ESCAPE" || key == "F1"
        @capture = nil
        @message = "Captura cancelada"
        return
      end
      if InputStudio.assign(@capture[:id], @device, key, @capture[:slot])
        @message = "#{key} asignada y guardada"
        @capture = nil
      else
        conflicts = InputStudio.conflicts(@capture[:id], @device, key)
        @message = conflicts.empty? ? InputStudio.status.to_s : "Conflicto: " + conflicts.first.to_s
        @capture = nil
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
      index = CATEGORIES.index(@category) || 0
      @category = CATEGORIES[(index + delta) % CATEGORIES.length]
      @row = 0
      @offset = 0
      clamp
    end
    def mouse_tick
      return unless Input.respond_to?(:mouse_x) && Input.respond_to?(:mouse_y)
      return unless Input.input_studio_native_trigger?(Input::MOUSELEFT)
      mx, my = Input.mouse_x, Input.mouse_y
      return unless mx && my
      left = [150, (@width * 0.27).to_i].min
      if mx >= 23 && mx < left && my >= 105
        index = (my - 105) / 32
        if index >= 0 && index < CATEGORIES.size
          @category = CATEGORIES[index]
          @row = 0
          @offset = 0
          clamp
        end
      elsif mx > left && my >= 128
        index = (my - 128) / 33 + @offset
        if index >= 0 && index < rows.size
          @row = index
          capture_start(0)
        end
      end
    end
    def normal_tick
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
        choose_category(-1)
      elsif trigger_key("RIGHT") || pad_trigger("DPAD_RIGHT")
        choose_category(1)
      elsif trigger_key("RETURN") || pad_trigger("A")
        capture_start(0)
      elsif trigger_key("2")
        capture_start(1)
      elsif trigger_key("DELETE") || trigger_key("BACKSPACE")
        if current && InputStudio.clear(current["id"], @device)
          @message = "Asignaciones retiradas"
        end
      elsif trigger_key("R")
        if current && InputStudio.reset(current["id"])
          @message = "Acción restaurada"
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
