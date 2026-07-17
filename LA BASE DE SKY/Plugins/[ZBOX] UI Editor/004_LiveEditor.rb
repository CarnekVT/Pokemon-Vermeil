# encoding: utf-8
module ZBOX_UIEditor
  module LiveEditor
    @active = false
    @screen_key = nil
    @elem_idx = 0
    @viewport = nil
    @sprites = nil
    @skip_frame = false
    @scene_obj = nil

    SCENE_MAP = {
      PokemonStorageScene => :pc_storage,
    }.freeze

    class << self
      attr_reader :active, :elem_idx, :screen_key
      attr_accessor :skip_frame, :scene_obj
    end

    def self.toggle
      if @active
        deactivate
      else
        activate
      end
      @skip_frame = true
    end

    def self.activate
      @scene_obj = $scene
      @screen_key = nil
      SCENE_MAP.each { |klass, key| @screen_key = key if $scene.is_a?(klass) }
      return if @screen_key.nil?
      @elem_idx = 0
      @active = true
      create_overlay
      draw_overlay
    end

    def self.deactivate
      @active = false
      @screen_key = nil
      @scene_obj = nil
      dispose_overlay
    end

    def self.check_scene_alive
      return true if !@active
      if $scene != @scene_obj || !$scene.is_a?(PokemonStorageScene)
        deactivate
        return false
      end
      true
    end

    def self.create_overlay
      dispose_overlay
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999
      @sprites = {}
      @sprites["bg"] = BitmapSprite.new(Graphics.width, 56, @viewport)
      @sprites["bg"].bitmap.fill_rect(0, 0, Graphics.width, 56, Color.new(0, 0, 0, 176))
      @sprites["hint"] = BitmapSprite.new(Graphics.width, 20, @viewport)
      @sprites["hint"].y = Graphics.height - 20
      @sprites["hint"].bitmap.fill_rect(0, 0, Graphics.width, 20, Color.new(0, 0, 0, 176))
      pbSetSystemFont(@sprites["bg"].bitmap)
      pbSetSystemFont(@sprites["hint"].bitmap)
    end

    def self.dispose_overlay
      pbDisposeSpriteHash(@sprites) if @sprites
      @sprites = nil
      @viewport&.dispose
      @viewport = nil
    end

    def self.elements
      return [] unless @screen_key
      data = ::ZBOX_UIEditor::Settings::SCREENS[@screen_key]
      data ? data[:elements] : []
    end

    def self.current_elem
      elements[@elem_idx]
    end

    def self.draw_overlay
      return unless @sprites
      bmp = @sprites["bg"].bitmap
      bmp.clear
      elem = current_elem
      if elem
        val = ::ZBOX_UIEditor.get_effective(elem[:klass], elem[:const]) || 0
        total = elements.length
        idx = @elem_idx + 1
        sd = ::ZBOX_UIEditor::Settings::SCREENS[@screen_key]
        name = sd ? sd[:label] : "?"
        pbDrawShadowText(bmp, 4, 2, 0, 0,
                         _INTL("[UI Editor] {1}  ({2}/{3})", name, idx, total),
                         Color.new(255, 220, 80), Color.new(40, 40, 40), 0)
        pbDrawShadowText(bmp, 4, 22, 0, 0,
                         _INTL("{1}::{2} = {3}", elem[:klass].split("::").last, elem[:const], val),
                         Color.new(255, 255, 255), Color.new(40, 40, 40), 0)
        pbDrawShadowText(bmp, 4, 40, 0, 0,
                         _INTL("{1}", elem[:label]),
                         Color.new(180, 180, 220), Color.new(40, 40, 40), 0)
      end
      hint = @sprites["hint"].bitmap
      hint.clear
      pbDrawShadowText(hint, Graphics.width / 2, 0, 0, 0,
                       _INTL("Q: toggle  |  Ctrl+←/→: valor  |  Ctrl+↑/↓: elem  |  Ctrl+Q: guardar"),
                       Color.new(180, 180, 200), Color.new(40, 40, 40), 1)
    end

    def self.process_input
      return unless @active
      return unless check_scene_alive
      return if @skip_frame

      ctrl = Input.press?(Input::CTRL)

      # Apagar: Q solo
      if !ctrl && Input.trigger?(Input::AUX1)
        deactivate
        return
      end

      # Guardar: Ctrl+Q
      if ctrl && Input.trigger?(Input::AUX1)
        ::ZBOX_UIEditor.save_file
        pbPlayDecisionSE
        draw_overlay
        return
      end

      step = Input.press?(Input::SHIFT) ? 10 : 1
      elem = current_elem
      return unless elem

      changed = false

      # Siguiente/anterior elemento: Ctrl+abajo/arriba
      if ctrl && Input.repeat?(Input::DOWN)
        @elem_idx = (@elem_idx + 1) % elements.length
        changed = true
      elsif ctrl && Input.repeat?(Input::UP)
        @elem_idx = (@elem_idx - 1) % elements.length
        changed = true
      end

      # Disminuir/aumentar valor: Ctrl+izquierda/derecha
      if ctrl && Input.repeat?(Input::LEFT)
        adjust_value(elem, -step)
        changed = true
      elsif ctrl && Input.repeat?(Input::RIGHT)
        adjust_value(elem, step)
        changed = true
      end

      draw_overlay if changed
    end

    def self.adjust_value(elem, delta)
      klass = Object.const_get(elem[:klass]) rescue nil
      return unless klass
      val = ::ZBOX_UIEditor.get_effective(elem[:klass], elem[:const]) || 0
      new_val = val + delta
      ::ZBOX_UIEditor.set_override(elem[:klass], elem[:const], new_val)
      refresh_scene
    end

    def self.refresh_scene
      return unless @scene_obj
      case @screen_key
      when :pc_storage
        s = @scene_obj
        sp = s.instance_variable_get(:@sprites) rescue nil
        return unless sp
        box = sp["box"]
        if box && !box.disposed?
          bx = ::ZBOX_UIEditor.get_effective("PokemonBoxSprite", :BOX_X)
          by = ::ZBOX_UIEditor.get_effective("PokemonBoxSprite", :BOX_Y)
          box.x = bx if bx; box.y = by if by
          box.refresh
        end
        sp["boxparty"]&.refresh rescue nil
        if s.respond_to?(:pbUpdateOverlay)
          sel = s.instance_variable_get(:@selection) rescue nil
          s.pbUpdateOverlay(sel) rescue nil
        end
      end
    end
  end
end

# ─── Parche a Input.update ────────────────────────────────────

module Input
  class << Input
    alias _ZBOX_UI_orig_update update
  end

  def self.update
    _ZBOX_UI_orig_update
    # AUX1 = Q (no usada en ningún menú) → toggle on/off
    if trigger?(Input::AUX1) && !ZBOX_UIEditor::LiveEditor.active
      begin
        ZBOX_UIEditor::LiveEditor.toggle
      rescue => e
        p "UI Editor error: #{e.message}"
      end
    end
    if ZBOX_UIEditor::LiveEditor.active && !ZBOX_UIEditor::LiveEditor.skip_frame
      begin
        ZBOX_UIEditor::LiveEditor.process_input
      rescue => e
        p "UI Editor error: #{e.message}"
        ZBOX_UIEditor::LiveEditor.deactivate
      end
    end
    ZBOX_UIEditor::LiveEditor.skip_frame = false
  end
end


