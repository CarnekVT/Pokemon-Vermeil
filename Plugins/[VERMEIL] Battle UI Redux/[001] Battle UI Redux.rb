#===============================================================================
# [VERMEIL] Battle UI Redux
# Re-skins the command menu into a compact right-side layout.
#===============================================================================

module VermeilBattleUIRedux
  module_function

  #=============================================================================
  # COORDINATES MASTER CONTROL - All position values in one place
  #=============================================================================
  
  # --- Databox Coordinates ---
  PLAYER_DATABOX_X = 0
  PLAYER_DATABOX_BOTTOM_MARGIN = 2
  ENEMY_DATABOX_X = 0  # Typically auto-calculated based on screen width
  ENEMY_DATABOX_TOP_MARGIN = 0
  
  # --- Fight Menu (Move List) Coordinates ---
  FIGHT_LIST_X = 287
  FIGHT_LIST_Y = 120  # Moved up more
  FIGHT_LIST_W = 192  # Normal width
  FIGHT_ROW_H = 46    # Normal height
  FIGHT_ROW_GAP = 8
  FIGHT_TYPE_ICON_X_OFFSET = 8
  FIGHT_PP_X_OFFSET = 74
  
  # --- Command Menu (Fight/Bag/Run/Pokemon) Coordinates ---
  COMMAND_LIST_X = 0  # Auto-calculated from Graphics.width
  COMMAND_LIST_Y = 0  # Auto-calculated from Graphics.height
  COMMAND_MAIN_BTN_W = 130  # Normal width
  COMMAND_MAIN_BTN_H = 46   # Normal height
  
  # Moviendo todo el menú más a la izquierda
  COMMAND_MAIN_BTN_X_OFFSET = -190  
  COMMAND_MAIN_BTN_Y_OFFSET = 10  # Normal position
  
  COMMAND_SMALL_BTN_W = 64
  COMMAND_SMALL_BTN_H = 30
  
  # SEPARACIÓN VERTICAL PERFECTA (Más espacio debajo del botón principal)
  COMMAND_SMALL_BTN_Y_OFFSET_1 = 62  # Empujado hacia abajo para separar del grande (antes 54)
  COMMAND_SMALL_BTN_Y_OFFSET_2 = 98  # Empujado hacia abajo para mantener el rombo (antes 92)
  
  # SEPARACIÓN HORIZONTAL DEL ROMBO
  COMMAND_SMALL_BTN_X_OFFSET_1 = -16  # Expande a la izquierda
  COMMAND_SMALL_BTN_X_OFFSET_2 = 82   # Expande a la derecha
  COMMAND_SMALL_BTN_X_OFFSET_3 = 33   # Centro inferior
  
  # --- Command Arrows ---
  COMMAND_ARROW_SIZE = 16
  
  # --- Action Hint (Mega/Shift) Coordinates ---
  ACTION_HINT_X_OFFSET = -82
  ACTION_HINT_Y_OFFSET = -8
  ACTION_HINT_W = 72
  ACTION_HINT_H = 32
  
  # --- Message Box Coordinates ---
  MESSAGE_BOX_X = 0
  MESSAGE_BOX_Y = 0  # Auto-calculated from Graphics.height - height
  MESSAGE_TEXT_PADDING_X = 16
  MESSAGE_TEXT_PADDING_Y = 2
  MESSAGE_TEXT_X = 0  # Auto-calculated from MESSAGE_BOX_X + MESSAGE_TEXT_PADDING_X
  MESSAGE_TEXT_Y = 0  # Auto-calculated from MESSAGE_BOX_Y + MESSAGE_TEXT_PADDING_Y
  MESSAGE_TEXT_W = 0  # Auto-calculated from screen width - 32
  MESSAGE_TEXT_H = 96
  
  # --- Overlay Z-Order ---
  REDUX_OVERLAY_Z = 250
  
  # --- Animation Distances ---
  FIGHT_SLIDE_DISTANCE = 220
  COMMAND_SLIDE_DISTANCE = 220
  
  # --- Visual Assets ---
  DEFAULT_MESSAGE_ASSET = "Graphics/UI/Battle/overlay_message"
  TRANSPARENT_MESSAGE_ASSET = "Graphics/UI/Battle/transparent_message"
  
  # --- Legacy/Backward Compatibility Aliases ---
  # (These maintain compatibility with older code that uses old constant names)
  TRANSPARENT_MESSAGE_X = 0
  TRANSPARENT_MESSAGE_Y = Graphics.height - 96
  TRANSPARENT_TEXT_X = 16
  TRANSPARENT_TEXT_Y = Graphics.height - 94
  TRANSPARENT_TEXT_W = Graphics.width - 32
  TRANSPARENT_TEXT_H = 96
  
  # --- Configuration Flags ---
  # Visual-only mode: keep command/fight overlays + databox visuals only.
  # Disables message/animation/display rewrites from this plugin.
  VISUAL_ONLY_MODE = true
  FORCE_VANILLA_UI_OVERRIDE = true
  STEP0_BYPASS_CUSTOM_SHOWWINDOW = true
  
  # Databox animation: true = slide from left (custom), false = default pop animation
  USE_SLIDE_DATABOX_ANIMATION = true

  #=============================================================================
  # SECONDARY LAYOUT & COMMAND MODES
  #=============================================================================

  SECONDARY_LAYOUT = {
    0 => [1, 3, 2],
    1 => [2, 0, 3],
    2 => [3, 1, 0],
    3 => [0, 2, 1]
  }

  COMMAND_MODES = [
    [0, 2, 1, 3],   # 0 regular
    [0, 2, 1, 9],   # 1 cancel
    [0, 2, 1, 4],   # 2 call
    [5, 7, 6, 3],   # 3 safari
    [0, 8, 1, 3],   # 4 bug contest
    [0, 2, 1, 10],  # 5 cheer
    [0, 11, 1, 3],  # 6 launch+run
    [0, 11, 1, 9],  # 7 launch+cancel
    [0, 11, 1, 4]   # 8 launch+call
  ]

  #=============================================================================
  # HELPER METHODS FOR DYNAMIC COORDINATES
  #=============================================================================

  def fight_list_x
    return Graphics.width - 225
  end

  def fight_list_y
    return Graphics.height - 212  # Moved up more
  end

  def command_list_base_x
    return Graphics.width - 186
  end

  def command_list_base_y
    return Graphics.height - 166
  end

  def message_box_y
    return Graphics.height - 96
  end

  def transparent_text_x
    return 16
  end

  def transparent_text_y
    return Graphics.height - 94
  end

  def transparent_text_w
    return Graphics.width - 32
  end

  def action_key_label
    default_map = {
      Input::USE     => "C",
      Input::BACK    => "X",
      Input::ACTION  => "Z",
      Input::SPECIAL => "D"
    }
    helper_methods = [
      :getKeyName, :get_key_name,
      :getInputName, :get_input_name,
      :keyName, :key_name,
      :buttonName, :button_name,
      :getButtonName, :get_button_name,
      :buttonToKeyName, :button_to_key_name
    ]
    helper_methods.each do |meth|
      next if !Input.respond_to?(meth)
      begin
        value = Input.send(meth, Input::ACTION)
        clean = value.to_s.strip
        return clean.upcase if !clean.empty?
      rescue
      end
    end
    begin
      data_dir = System.data_directory
      kb_path = data_dir ? File.join(data_dir, "keybindings.mkxp1") : nil
      if kb_path && File.file?(kb_path)
        ints = File.binread(kb_path).unpack("l<*")
        records = ints.each_slice(4).to_a
        matches = records.select { |rec| rec && rec.length == 4 && rec[2] == Input::ACTION }
        if !matches.empty?
          matches.sort_by! { |rec| rec[3] || 0 }
          keycode = matches[-1][0]
          label = keycode_to_label(keycode)
          return label.upcase if label && !label.empty?
        end
      end
    rescue StandardError
    end
    return default_map[Input::ACTION]
  end

  def keycode_to_label(code)
    return "" if code.nil?
    return (65 + (code - 4)).chr if code >= 4 && code <= 29
    return (code - 29).to_s if code >= 30 && code <= 38
    return "0" if code == 39
    key_names = {
      40 => "ENTER", 41 => "ESC", 42 => "BACKSPACE", 43 => "TAB", 44 => "SPACE",
      58 => "F1", 59 => "F2", 60 => "F3", 61 => "F4", 62 => "F5", 63 => "F6",
      64 => "F7", 65 => "F8", 66 => "F9", 67 => "F10", 68 => "F11", 69 => "F12",
      79 => "RIGHT", 80 => "LEFT", 81 => "DOWN", 82 => "UP",
      224 => "CTRL", 225 => "SHIFT", 226 => "ALT"
    }
    return key_names[code] || ""
  end

  class CommandOverlay
    def initialize(viewport, scene = nil)
      @scene = scene
      @sprite = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
      @sprite.z = VermeilBattleUIRedux::REDUX_OVERLAY_Z
      if @scene && @scene.instance_variable_defined?(:@sprites)
        sprites = @scene.instance_variable_get(:@sprites)
        sprites["vermeil_overlay_command"] = @sprite if sprites.is_a?(Hash)
      end
      pbSetNarrowFont(@sprite.bitmap)
      @button_bitmap = nil
      @button_bitmap = AnimatedBitmap.new(_INTL("Graphics/UI/Battle/cursor_command")) rescue nil
      @arrow_bitmap = nil
      @arrow_bitmap = AnimatedBitmap.new(_INTL("Graphics/UI/left_arrow")) rescue nil
      @right_arrow_bitmap = nil
      @right_arrow_bitmap = AnimatedBitmap.new(_INTL("Graphics/UI/right_arrow")) rescue nil
      @last_state = nil
      @offset_x = 0
    end

    def dispose
      @button_bitmap&.dispose
      @arrow_bitmap&.dispose
      @right_arrow_bitmap&.dispose
      @sprite.dispose if @sprite && !@sprite.disposed?
    end

    def visible=(value)
      @sprite.visible = value if @sprite && !@sprite.disposed?
    end

    def opacity=(value)
      @sprite.opacity = value if @sprite && !@sprite.disposed?
    end

    def offset_x=(value)
      @offset_x = value.to_i
    end

    def draw(texts, index, mode = 0)
      state = [texts[1], texts[2], texts[3], texts[4], index, mode, @offset_x]
      return if state == @last_state
      @last_state = state
      bmp = @sprite.bitmap
      bmp.clear

      lbl_pkmn = texts[3].to_s.include?("Pok") ? "PKMN" : texts[3]
      labels = [texts[1], texts[2], lbl_pkmn, texts[4]]
      base_x = (Graphics.width + VermeilBattleUIRedux::COMMAND_MAIN_BTN_X_OFFSET) + @offset_x
      base_y = Graphics.height - 166  # Adjusted to fit with databox
      main_w = 130  # Normal width
      main_h = 46   # Normal height
      small_w = 64
      small_h = 30

      # Dibujar PRIMERO los botones secundarios para que queden por debajo del principal (Efecto Capas 3D)
      secondary = VermeilBattleUIRedux::SECONDARY_LAYOUT[index]
      draw_button(bmp, base_x + VermeilBattleUIRedux::COMMAND_SMALL_BTN_X_OFFSET_1,  base_y + VermeilBattleUIRedux::COMMAND_SMALL_BTN_Y_OFFSET_1, small_w, small_h, secondary[0], "", false, mode)
      draw_button(bmp, base_x + VermeilBattleUIRedux::COMMAND_SMALL_BTN_X_OFFSET_2, base_y + VermeilBattleUIRedux::COMMAND_SMALL_BTN_Y_OFFSET_1, small_w, small_h, secondary[1], "", false, mode)
      draw_button(bmp, base_x + VermeilBattleUIRedux::COMMAND_SMALL_BTN_X_OFFSET_3, base_y + VermeilBattleUIRedux::COMMAND_SMALL_BTN_Y_OFFSET_2, small_w, small_h, secondary[2], "", false, mode)

      # Dibujar Flechas
      draw_command_arrows(bmp, base_x, base_y + VermeilBattleUIRedux::COMMAND_MAIN_BTN_Y_OFFSET, main_w, main_h)

      # Dibujar el botón PRINCIPAL al final para que superponga a los pequeños
      draw_button(bmp, base_x, base_y + VermeilBattleUIRedux::COMMAND_MAIN_BTN_Y_OFFSET, main_w, main_h, index, labels[index], true, mode)
    end

    private

    def viewport_left
      return (@sprite.viewport && @sprite.viewport.rect) ? @sprite.viewport.rect.x : 0
    end

    def viewport_width
      return (@sprite.viewport && @sprite.viewport.rect) ? @sprite.viewport.rect.width : Graphics.width
    end

    def draw_arrows(bmp, x, y, width)
      color = Color.new(24, 24, 24)
      bmp.fill_rect(x, y + 7, width, 5, color)
      bmp.fill_rect(x, y + 5, 14, 9, color)
      bmp.fill_rect(x + width - 14, y + 5, 14, 9, color)
    end

    def draw_command_arrows(bmp, x, y, w, h)
      # Each arrow spritesheet frame is 40x28
      arrow_w = 40
      arrow_h = 28
      center_y = y + (h / 2) - (arrow_h / 2)
      
      # Draw left arrow (first frame only: 40x28) - attached to left side
      if @arrow_bitmap && @arrow_bitmap.bitmap && !@arrow_bitmap.bitmap.disposed?
        src = Rect.new(0, 0, arrow_w, arrow_h)
        dest = Rect.new(x - arrow_w - 2, center_y, arrow_w, arrow_h)  # Closer offset
        bmp.blt(dest.x, dest.y, @arrow_bitmap.bitmap, src)
      else
        # Fallback: draw left triangle - attached
        arrow_color = Color.new(24, 24, 24)
        bx = x - 16
        by = center_y + 8
        bmp.fill_rect(bx, by + 4, 12, 8, arrow_color)
        bmp.fill_rect(bx + 10, by + 6, 6, 4, arrow_color)
      end
      
      # Draw right arrow (first frame only: 40x28) - attached to right side
      if @right_arrow_bitmap && @right_arrow_bitmap.bitmap && !@right_arrow_bitmap.bitmap.disposed?
        src = Rect.new(0, 0, arrow_w, arrow_h)
        dest = Rect.new(x + w + 2, center_y, arrow_w, arrow_h)  # Closer offset
        bmp.blt(dest.x, dest.y, @right_arrow_bitmap.bitmap, src)
      else
        # Fallback: draw right triangle - attached
        arrow_color = Color.new(24, 24, 24)
        bx = x + w + 4
        by = center_y + 8
        bmp.fill_rect(bx, by + 4, 12, 8, arrow_color)
        bmp.fill_rect(bx, by + 6, 6, 4, arrow_color)
      end
    end

    def draw_button(bmp, x, y, w, h, idx, text, large, mode)
      row = (VermeilBattleUIRedux::COMMAND_MODES[mode] || VermeilBattleUIRedux::COMMAND_MODES[0])[idx]
      if @button_bitmap && @button_bitmap.bitmap
        src = @button_bitmap.bitmap
        sw = src.width / 2
        sh = 46
        sx = large ? sw : 0
        sy = row * sh
        bmp.stretch_blt(Rect.new(x, y, w, h), src, Rect.new(sx, sy, sw, sh))
      else
        edge = Color.new(12, 12, 12)
        fill = Color.new(180, 180, 180)
        bmp.fill_rect(x, y, w, h, edge)
        bmp.fill_rect(x + 2, y + 2, w - 4, h - 4, fill)
      end
      # x + 16 da margen izquierdo, w - 46 evita pisar el icono, 0 lo alinea a la izquierda
      bmp.draw_text(x + 16, y + 12, w - 46, h - 20, text.to_s, 0) if large
    end
  end

  class FightOverlay
    def initialize(viewport, scene = nil)
      @scene = scene
      @sprite = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
      @sprite.z = VermeilBattleUIRedux::REDUX_OVERLAY_Z
      if @scene && @scene.instance_variable_defined?(:@sprites)
        sprites = @scene.instance_variable_get(:@sprites)
        sprites["vermeil_overlay_fight"] = @sprite if sprites.is_a?(Hash)
      end
      pbSetNarrowFont(@sprite.bitmap)
      @button_bitmap = nil
      @button_bitmap = AnimatedBitmap.new(_INTL("Graphics/UI/Battle/cursor_fight")) rescue nil
      @type_bitmap = nil
      @type_bitmap = AnimatedBitmap.new(_INTL("Graphics/UI/types")) rescue nil
      @mega_bitmap = nil
      @mega_bitmap = AnimatedBitmap.new(_INTL("Graphics/UI/Battle/cursor_mega")) rescue nil
      @last_state = nil
      @offset_x = 0
    end

    def dispose
      @button_bitmap&.dispose
      @type_bitmap&.dispose
      @mega_bitmap&.dispose
      @sprite.dispose if @sprite && !@sprite.disposed?
    end

    def visible=(value)
      @sprite.visible = value if @sprite && !@sprite.disposed?
    end

    def opacity=(value)
      @sprite.opacity = value if @sprite && !@sprite.disposed?
    end

    def offset_x=(value)
      @offset_x = value.to_i
    end

    def draw(battler, index, action_symbol = nil, action_active = false)
      moves = battler ? battler.moves : []
      move_names = moves.map { |m| m ? m.name : "-" }
      sel = moves[index]
      type_name = "-"
      pp_text = "PP: --/--"
      if sel
        type_id = sel.respond_to?(:display_type) ? sel.display_type(battler) : sel.type
        type_name = GameData::Type.get(type_id).name rescue type_id.to_s
        pp_text = "PP: #{sel.pp}/#{sel.total_pp}"
      end
      pulse = action_active ? ((System.uptime * 8).to_i % 2) : 0
      action_text = VermeilBattleUIRedux.action_key_label
      state = [index, move_names, type_name, pp_text, action_symbol, action_active, pulse, action_text, @offset_x]
      return if state == @last_state
      @last_state = state
      bmp = @sprite.bitmap
      bmp.clear

      draw_move_list(bmp, battler, move_names, index, @offset_x)
      draw_type_pp(bmp, battler, sel, type_name, pp_text, @offset_x)
      draw_action_hint(bmp, action_symbol, action_active, pulse, action_text, @offset_x) if action_symbol
    end

    private

    def draw_move_list(bmp, battler, names, selected, offset_x = 0)
      x = VermeilBattleUIRedux.fight_list_x + offset_x
      y = VermeilBattleUIRedux.fight_list_y
      w = VermeilBattleUIRedux::FIGHT_LIST_W
      h = VermeilBattleUIRedux::FIGHT_ROW_H
      text_pos = []
      4.times do |i|
        row_y = y + (i * (h + VermeilBattleUIRedux::FIGHT_ROW_GAP))
        move = (battler && battler.moves) ? battler.moves[i] : nil
        type_num = 0
        if move && move.id
          begin
            type_num = GameData::Type.get(move.display_type(battler)).icon_position
          rescue
            type_num = 0
          end
        end
        if @button_bitmap && @button_bitmap.bitmap
          source = @button_bitmap.bitmap
          sw = source.width / 2
          sh = 46
          sx = (i == selected) ? sw : 0
          sy = type_num * sh
          src = Rect.new(sx, sy, sw, sh)
          bmp.stretch_blt(Rect.new(x, row_y, w, h), source, src)
          text_pos.push([names[i].to_s, x + (w / 2), row_y + 8, :center, Color.new(248, 248, 248), Color.new(0, 0, 0), :outline])
        else
          base = (i == selected) ? Color.new(250, 236, 224) : Color.new(240, 240, 240)
          edge = Color.new(128, 98, 98)
          bmp.fill_rect(x, row_y, w, h, edge)
          bmp.fill_rect(x + 2, row_y + 2, w - 4, h - 4, base)
          text_pos.push([names[i].to_s, x + (w / 2), row_y + 8, :center, Color.new(248, 248, 248), Color.new(0, 0, 0), :outline])
        end
      end
      pbDrawTextPositions(bmp, text_pos)
    end

    def draw_type_pp(bmp, battler, move, type_name, pp_text, offset_x = 0)
      base_x = VermeilBattleUIRedux.fight_list_x + 8 + offset_x
      
      # [MODIFICADO]: Ahora el Y se resta para que el Type y PP queden ENCIMA de los ataques
      base_y = VermeilBattleUIRedux.fight_list_y - 38 
      
      # Type icon (existing asset)
      if @type_bitmap && @type_bitmap.bitmap && move && move.id
        begin
          type_num = GameData::Type.get(move.display_type(battler)).icon_position
          src = Rect.new(0, type_num * 28, 64, 28)
          bmp.blt(base_x, base_y + 2, @type_bitmap.bitmap, src)
        rescue
          bmp.draw_text(base_x, base_y + 2, 64, 24, type_name.to_s.upcase, 1)
        end
      else
        bmp.draw_text(base_x, base_y + 2, 64, 24, type_name.to_s.upcase, 1)
      end
      # PP text block
      px = base_x + 74
      py = base_y + 1
      bmp.fill_rect(px, py, 114, 30, Color.new(182, 182, 182))
      bmp.fill_rect(px + 2, py + 2, 110, 26, Color.new(228, 228, 228))
      pp_base = Color.new(80, 80, 80)
      pp_shadow = Color.new(220, 220, 220)
      if move && move.total_pp && move.total_pp > 0
        frac = [(4.0 * move.pp / move.total_pp).ceil, 3].min
        colors = Battle::Scene::FightMenu::PP_COLORS rescue nil
        if colors
          pp_base = colors[frac * 2]
          pp_shadow = colors[(frac * 2) + 1]
        end
      end
      pbDrawTextPositions(bmp, [[pp_text, px + 8, py + 5, :left, pp_base, pp_shadow]])
    end

def draw_action_hint(bmp, action_symbol, active, pulse, action_text, offset_x = 0)
      # 1. Movido más a la derecha (Cambiamos el -104 por -76)
      x = VermeilBattleUIRedux.fight_list_x - 76 + offset_x
      y = VermeilBattleUIRedux.fight_list_y + (1 * (VermeilBattleUIRedux::FIGHT_ROW_H + VermeilBattleUIRedux::FIGHT_ROW_GAP)) + VermeilBattleUIRedux::ACTION_HINT_Y_OFFSET
      
      mega_w = 28
      mega_h = 28

      if @mega_bitmap && @mega_bitmap.bitmap && !@mega_bitmap.bitmap.disposed? && action_symbol == :mega
        
        # 2. Dibujamos SIEMPRE la piedra apagada como base (Frame 0)
        src_base = Rect.new(0, 0, mega_w, mega_h)
        bmp.blt(x, y, @mega_bitmap.bitmap, src_base)
        
        # 3. BRILLO PERFECTO: Superponemos la piedra brillante (Frame 1) 
        # Como usamos 'blt' (Block Transfer), detecta el espacio nulo automáticamente.
        if active
          stone_opacity = (pulse == 0) ? 255 : 120 # Palpita entre 100% y 50% de opacidad
          src_active = Rect.new(mega_w, 0, mega_w, mega_h)
          bmp.blt(x, y, @mega_bitmap.bitmap, src_active, stone_opacity)
        end
      end
      
      # 4. Letra de Input (Ej. 'Z') centrada debajo de la piedra
      pbDrawTextPositions(bmp, [[action_text, x + 14, y + 36, :center, Color.new(248, 248, 248), Color.new(0, 0, 0), :outline]])
    end

    def viewport_left
      return (@sprite.viewport && @sprite.viewport.rect) ? @sprite.viewport.rect.x : 0
    end

    def viewport_width
      return (@sprite.viewport && @sprite.viewport.rect) ? @sprite.viewport.rect.width : Graphics.width
    end
  end
end

module VermeilBattleUIRedux
  module MessageBoxLayoutOverride
    MESSAGE_TEXT_PADDING_X = 16
    MESSAGE_TEXT_PADDING_Y = 2
    MESSAGE_TRANSITION_FRAMES = 0
    MESSAGE_TRANSITION_DROP_Y = 0

    def vermeil_redux_message_box_rect
      resolved = pbResolveBitmap(VermeilBattleUIRedux::DEFAULT_MESSAGE_ASSET)
      w = Graphics.width
      h = 96
      if resolved
        bmp = nil
        begin
          bmp = Bitmap.new(resolved)
          w = bmp.width if bmp && !bmp.disposed?
          h = bmp.height if bmp && !bmp.disposed?
        ensure
          bmp.dispose if bmp && !bmp.disposed?
        end
      end
      x = 0
      y = Graphics.height - h
      return [x, y, w, h]
    end

    def vermeil_redux_apply_message_layout
      return if !@sprites
      msg_box = @sprites["messageBox"]
      msg_win = @sprites["messageWindow"]
      return if !msg_box || !msg_win
      x, y, w, h = vermeil_redux_message_box_rect
      msg_box.x = x if msg_box.respond_to?(:x=)
      msg_box.y = y if msg_box.respond_to?(:y=)
      if msg_win.respond_to?(:x=) && msg_win.respond_to?(:y=)
        msg_win.x = x + MESSAGE_TEXT_PADDING_X
        msg_win.y = y + MESSAGE_TEXT_PADDING_Y
      end
      if msg_win.respond_to?(:width=) && msg_win.respond_to?(:height=)
        msg_win.width = [w - (MESSAGE_TEXT_PADDING_X * 2), 32].max
        msg_win.height = h
      end
      # No window background; overlay graphic is the only box.
      msg_win.opacity = 0 if msg_win.respond_to?(:opacity=)
      msg_win.back_opacity = 0 if msg_win.respond_to?(:back_opacity=)
      msg_win.contents_opacity = 255 if msg_win.respond_to?(:contents_opacity=)
      if msg_win.respond_to?(:baseColor=)
        msg_win.baseColor = defined?(Battle::Scene::BASE_DARK) ? Battle::Scene::BASE_DARK : Color.new(56, 56, 56)
      end
      if msg_win.respond_to?(:shadowColor=)
        msg_win.shadowColor = defined?(Battle::Scene::SHADOW_DARK) ? Battle::Scene::SHADOW_DARK : Color.new(184, 184, 184)
      end
      @vermeil_redux_msg_base_x = x
      @vermeil_redux_msg_base_y = y
    end

    def vermeil_redux_start_message_transition(show)
      # STEP 3 (disabled): transition helper is currently unused and can
      # interfere with message visibility state tracking.
      # Re-enable only if you want animated message box transitions again.
      return
    end

    def vermeil_redux_set_message_box_skin(use_transparent = false)
      return if !@sprites
      msg_box = @sprites["messageBox"]
      return if !msg_box || !msg_box.respond_to?(:setBitmap)
      asset = use_transparent ? VermeilBattleUIRedux::TRANSPARENT_MESSAGE_ASSET : VermeilBattleUIRedux::DEFAULT_MESSAGE_ASSET
      return if !pbResolveBitmap(asset)
      msg_box.setBitmap(asset)
      vermeil_redux_apply_message_layout
    end

    def vermeil_redux_force_message_state(show)
      return if !@sprites
      msg_box = @sprites["messageBox"]
      msg_win = @sprites["messageWindow"]
      return if !msg_box || !msg_win
      vermeil_redux_apply_message_layout
      if show
        msg_box.visible = true if msg_box.respond_to?(:visible=)
        msg_win.visible = true if msg_win.respond_to?(:visible=)
        msg_box.opacity = 255 if msg_box.respond_to?(:opacity=)
        msg_win.contents_opacity = 255 if msg_win.respond_to?(:contents_opacity=)
      else
        msg_box.visible = false if msg_box.respond_to?(:visible=)
        msg_win.visible = false if msg_win.respond_to?(:visible=)
      end
    end

    def pbShowWindow(windowType)
      if defined?(VermeilBattleUIRedux::VISUAL_ONLY_MODE) &&
         VermeilBattleUIRedux::VISUAL_ONLY_MODE
        # Visual-only safety path: avoid super-chain recursion with other
        # plugins that alias/prepend pbShowWindow.
        if @sprites
          msg_box_const = (defined?(Battle::Scene::MESSAGE_BOX) ? Battle::Scene::MESSAGE_BOX : 1)
          cmd_box_const = (defined?(Battle::Scene::COMMAND_BOX) ? Battle::Scene::COMMAND_BOX : 2)
          fight_box_const = (defined?(Battle::Scene::FIGHT_BOX) ? Battle::Scene::FIGHT_BOX : 3)
          target_box_const = (defined?(Battle::Scene::TARGET_BOX) ? Battle::Scene::TARGET_BOX : 4)
          @sprites["messageBox"].visible = (windowType == msg_box_const) if @sprites["messageBox"] && @sprites["messageBox"].respond_to?(:visible=)
          @sprites["messageWindow"].visible = (windowType == msg_box_const) if @sprites["messageWindow"] && @sprites["messageWindow"].respond_to?(:visible=)
          @sprites["commandWindow"].visible = (windowType == cmd_box_const) if @sprites["commandWindow"] && @sprites["commandWindow"].respond_to?(:visible=)
          @sprites["fightWindow"].visible = (windowType == fight_box_const) if @sprites["fightWindow"] && @sprites["fightWindow"].respond_to?(:visible=)
          @sprites["targetWindow"].visible = (windowType == target_box_const) if @sprites["targetWindow"] && @sprites["targetWindow"].respond_to?(:visible=)
        end
        return
      end
      if @vermeil_redux_showwindow_guard
        # Fallback on re-entry: apply vanilla visibility state to avoid partial UI.
        if @sprites
          msg_box_const = (defined?(Battle::Scene::MESSAGE_BOX) ? Battle::Scene::MESSAGE_BOX : 1)
          cmd_box_const = (defined?(Battle::Scene::COMMAND_BOX) ? Battle::Scene::COMMAND_BOX : 2)
          fight_box_const = (defined?(Battle::Scene::FIGHT_BOX) ? Battle::Scene::FIGHT_BOX : 3)
          target_box_const = (defined?(Battle::Scene::TARGET_BOX) ? Battle::Scene::TARGET_BOX : 4)
          @sprites["messageBox"].visible = (windowType == msg_box_const) if @sprites["messageBox"] && @sprites["messageBox"].respond_to?(:visible=)
          @sprites["messageWindow"].visible = (windowType == msg_box_const) if @sprites["messageWindow"] && @sprites["messageWindow"].respond_to?(:visible=)
          @sprites["commandWindow"].visible = (windowType == cmd_box_const) if @sprites["commandWindow"] && @sprites["commandWindow"].respond_to?(:visible=)
          @sprites["fightWindow"].visible = (windowType == fight_box_const) if @sprites["fightWindow"] && @sprites["fightWindow"].respond_to?(:visible=)
          @sprites["targetWindow"].visible = (windowType == target_box_const) if @sprites["targetWindow"] && @sprites["targetWindow"].respond_to?(:visible=)
          want_show = (windowType == msg_box_const)
          @vermeil_redux_msg_target_visible = want_show
          @vermeil_redux_msg_transition = nil
          vermeil_redux_force_message_state(want_show)
        end
        return
      end
      @vermeil_redux_showwindow_guard = true
      msg_box_const = (defined?(Battle::Scene::MESSAGE_BOX) ? Battle::Scene::MESSAGE_BOX : 1)
      cmd_box_const = (defined?(Battle::Scene::COMMAND_BOX) ? Battle::Scene::COMMAND_BOX : 2)
      fight_box_const = (defined?(Battle::Scene::FIGHT_BOX) ? Battle::Scene::FIGHT_BOX : 3)
      target_box_const = (defined?(Battle::Scene::TARGET_BOX) ? Battle::Scene::TARGET_BOX : 4)
      if !(defined?(VermeilBattleUIRedux::FORCE_VANILLA_UI_OVERRIDE) && VermeilBattleUIRedux::FORCE_VANILLA_UI_OVERRIDE)
        super
      elsif @sprites
        # Hard override mode: Redux controls visibility and ignores vanilla window toggles.
        @sprites["messageBox"].visible   = (windowType == msg_box_const)   if @sprites["messageBox"] && @sprites["messageBox"].respond_to?(:visible=)
        @sprites["messageWindow"].visible = (windowType == msg_box_const)  if @sprites["messageWindow"] && @sprites["messageWindow"].respond_to?(:visible=)
        @sprites["commandWindow"].visible = (windowType == cmd_box_const)  if @sprites["commandWindow"] && @sprites["commandWindow"].respond_to?(:visible=)
        @sprites["fightWindow"].visible   = (windowType == fight_box_const) if @sprites["fightWindow"] && @sprites["fightWindow"].respond_to?(:visible=)
        @sprites["targetWindow"].visible  = (windowType == target_box_const) if @sprites["targetWindow"] && @sprites["targetWindow"].respond_to?(:visible=)
      end
      if @sprites
        if windowType == msg_box_const
          if @vermeil_redux_command_overlay && @vermeil_redux_command_overlay.respond_to?(:visible=)
            @vermeil_redux_command_overlay.visible = false
          end
          if @vermeil_redux_fight_overlay && @vermeil_redux_fight_overlay.respond_to?(:visible=)
            @vermeil_redux_fight_overlay.visible = false
          end
          @sprites.each_value do |s|
            next if !s || !s.respond_to?(:visible=)
            if s.is_a?(VermeilBattleUIRedux::CommandOverlay) || s.is_a?(VermeilBattleUIRedux::FightOverlay)
              s.visible = false
            end
          end
        end
      end
      vermeil_redux_apply_message_layout
      # Keep message UI instant (no transition), to avoid state bugs in flee/turn swaps.
      msg_box_const = (defined?(Battle::Scene::MESSAGE_BOX) ? Battle::Scene::MESSAGE_BOX : 1)
      want_show = (windowType == msg_box_const)
      if @vermeil_redux_msg_target_visible.nil?
        current_vis = (@sprites && @sprites["messageBox"] && @sprites["messageBox"].respond_to?(:visible)) ? @sprites["messageBox"].visible : false
        @vermeil_redux_msg_target_visible = current_vis
      end
      @vermeil_redux_msg_target_visible = want_show
      @vermeil_redux_msg_transition = nil
      vermeil_redux_force_message_state(want_show)
    ensure
      @vermeil_redux_showwindow_guard = false
    end

    def pbUpdate(*args)
      super
      return if !@sprites
      # STEP 1 (disabled): per-frame visibility enforcement can fight with
      # Essentials/other plugins and cause flicker/overlap race conditions.
      # Re-enable later if needed.
      return
    end
  end

  module DataboxPositionOverride
    def set_style_properties(sideSize)
      super
      return if !@battler || !@battler.index.even?
      box_height = (@databoxBitmap && @databoxBitmap.respond_to?(:height)) ? @databoxBitmap.height : 96
      @spriteX = VermeilBattleUIRedux::PLAYER_DATABOX_X
      @spriteY = Graphics.height - box_height - VermeilBattleUIRedux::PLAYER_DATABOX_BOTTOM_MARGIN
    end

    def update_positions
      if @battler && @battler.index.even?
        box_height = (self.bitmap && self.bitmap.respond_to?(:height)) ? self.bitmap.height : 96
        @spriteX = VermeilBattleUIRedux::PLAYER_DATABOX_X
        @spriteY = Graphics.height - box_height - VermeilBattleUIRedux::PLAYER_DATABOX_BOTTOM_MARGIN
      end
      super
    end
  end
end

Battle::Scene::PokemonDataBox.prepend(VermeilBattleUIRedux::DataboxPositionOverride) if
  defined?(Battle::Scene::PokemonDataBox) &&
  !Battle::Scene::PokemonDataBox.ancestors.include?(VermeilBattleUIRedux::DataboxPositionOverride)

module VermeilBattleUIRedux
  module DataBoxSwitchRefreshOverride
    def battler=(b)
      super
      # On switch-in, kill stale HP/EXP tween state from previous occupant.
      @anim_hp_start = nil
      @anim_hp_end = nil
      @anim_hp_timer_start = nil
      @anim_hp_current = nil
      @anim_exp_start = nil
      @anim_exp_end = nil
      @anim_exp_range = nil
      @anim_exp_duration_mult = nil
      @anim_exp_current = nil
      @anim_exp_timer_start = nil
      refresh if @battler && respond_to?(:refresh)
    end
  end
end

Battle::Scene::PokemonDataBox.prepend(VermeilBattleUIRedux::DataBoxSwitchRefreshOverride) if
  defined?(Battle::Scene::PokemonDataBox) &&
  !Battle::Scene::PokemonDataBox.ancestors.include?(VermeilBattleUIRedux::DataBoxSwitchRefreshOverride)

module VermeilBattleUIRedux
  module FightMenuOverride
    def vermeil_redux_valid_move_indices(battler)
      indices = []
      Pokemon::MAX_MOVES.times do |i|
        move = battler.moves[i] rescue nil
        indices << i if move && move.id
      end
      indices = [0] if indices.empty?
      return indices
    end

    def vermeil_redux_next_move_index(current_index, indices, step)
      pos = indices.index(current_index) || 0
      return indices[(pos + step) % indices.length]
    end

# [MODIFICADO]: Desplazar la caja de Move Info al tope de la pantalla
    def pbUpdateMoveInfoWindow(*args)
      super(*args) if defined?(super)
      offset_y = -72 # Ajustado para dejar respirar el primer movimiento
      
      if @sprites && @sprites["enhancedUI"]
        @sprites["enhancedUI"].y = offset_y
      end
    end
    def pbHideInfoUI(*args)
      if @sprites && @sprites["enhancedUI"]
        @sprites["enhancedUI"].y = 0 
      end
      super(*args) if defined?(super)
    end

    def pbFightMenu(idxBattler, specialAction = nil)
      battler = @battle.battlers[idxBattler]
      cw = @sprites["fightWindow"]
      pbHideInfoUI if respond_to?(:pbHideInfoUI)
      cw.battler = battler if cw.respond_to?(:battler=)
      move_index = 0
      if battler && battler.moves[@lastMove[idxBattler]]&.id
        move_index = @lastMove[idxBattler]
      end
      mode = (!specialAction.nil?) ? 1 : 0
      cw.setIndexAndMode(move_index, mode)
      pbSetSpecialActionModes(idxBattler, specialAction, cw) if respond_to?(:pbSetSpecialActionModes)
      cw.refresh if cw.respond_to?(:refresh)
      @sprites["messageBox"].visible = false if @sprites["messageBox"]
      @sprites["messageWindow"].visible = false if @sprites["messageWindow"]

      overlay = VermeilBattleUIRedux::FightOverlay.new(@viewport, self)
      @vermeil_redux_fight_overlay = overlay
      cw.visible = false if cw.respond_to?(:visible=)
      enter_frames = 6
      overlay.opacity = 0
      overlay.offset_x = VermeilBattleUIRedux::FIGHT_SLIDE_DISTANCE
      (1..enter_frames).each do |i|
        t = i.to_f / enter_frames
        overlay.opacity = (255 * t).to_i
        overlay.offset_x = ((1.0 - t) * VermeilBattleUIRedux::FIGHT_SLIDE_DISTANCE).round
        action_active = (specialAction && cw.respond_to?(:mode) && cw.mode == 2)
        overlay.draw(battler, cw.index, specialAction, action_active)
        pbUpdate(cw)
        cw.visible = false if cw.respond_to?(:visible=)
      end
      overlay.offset_x = 0
      fight_exit_anim = proc do
        1.upto(6) do |i|
          t = i.to_f / 6.0
          overlay.offset_x = (VermeilBattleUIRedux::FIGHT_SLIDE_DISTANCE * t).round
          action_active = (specialAction && cw.respond_to?(:mode) && cw.mode == 2)
          overlay.draw(battler, cw.index, specialAction, action_active)
          pbUpdate(cw)
          cw.visible = false if cw.respond_to?(:visible=)
        end
      end
      need_full_refresh = true
      need_refresh = false
      loop do
        if need_full_refresh
          pbShowWindow(Battle::Scene::FIGHT_BOX)
          cw.visible = false if cw.respond_to?(:visible=)
          @sprites["messageBox"].visible = false if @sprites["messageBox"]
          @sprites["messageWindow"].visible = false if @sprites["messageWindow"]
          pbSelectBattler(idxBattler)
          need_full_refresh = false
        end
        if need_refresh
          if specialAction && @battle.respond_to?(:pbBattleMechanicIsRegistered?)
            new_mode = (@battle.pbBattleMechanicIsRegistered?(idxBattler, specialAction)) ? 2 : 1
            cw.mode = new_mode if cw.respond_to?(:mode=) && new_mode != cw.mode
            pbFightMenu_Update(battler, specialAction, cw) if respond_to?(:pbFightMenu_Update)
          end
          need_refresh = false
        end

        old_index = cw.index
        pbUpdate(cw)
        cw.visible = false if cw.respond_to?(:visible=)
        enhanced_active = @sprites && @sprites["enhancedUI"] && @sprites["enhancedUI"].visible
        if enhanced_active && instance_variable_defined?(:@enhancedUIToggle) && @enhancedUIToggle == :move &&
           respond_to?(:pbUpdateMoveInfoWindow)
          pbUpdateMoveInfoWindow(battler, specialAction, cw)
        end
        action_active = (specialAction && cw.respond_to?(:mode) && cw.mode == 2)
        overlay.draw(battler, cw.index, specialAction, action_active)
        valid_indices = vermeil_redux_valid_move_indices(battler)
        if Input.trigger?(Input::UP) || Input.trigger?(Input::LEFT)
          cw.index = vermeil_redux_next_move_index(cw.index, valid_indices, -1)
        elsif Input.trigger?(Input::DOWN) || Input.trigger?(Input::RIGHT)
          cw.index = vermeil_redux_next_move_index(cw.index, valid_indices, 1)
        end
        if cw.index != old_index
          pbPlayCursorSE
          pbFightMenu_Update(battler, specialAction, cw) if respond_to?(:pbFightMenu_Update)
        end

        if Input.trigger?(Input::USE)
          overlay.visible = false if overlay.respond_to?(:visible=)
          pbPlayDecisionSE
          cmd = respond_to?(:pbFightMenu_Confirm) ? pbFightMenu_Confirm(battler, specialAction, cw) : cw.index
          accepted = yield cmd
          break if accepted
          overlay.visible = true if overlay.respond_to?(:visible=)
          need_full_refresh = true
          need_refresh = true
        elsif Input.trigger?(Input::BACK)
          if instance_variable_defined?(:@enhancedUIToggle) && @enhancedUIToggle == :move &&
             respond_to?(:pbHideInfoUI)
            pbPlayCancelSE
            pbHideInfoUI
            # [MODIFICADO]: Reactivar el Prompt original al ocultar Move Info
            @enhancedUIToggle = nil 
            pbRefreshUIPrompt(idxBattler, Battle::Scene::FIGHT_BOX) if respond_to?(:pbRefreshUIPrompt)
            need_refresh = true
            next
          end
          cmd = respond_to?(:pbFightMenu_Cancel) ? pbFightMenu_Cancel(battler, specialAction, cw) : -1
          accepted = yield cmd
          fight_exit_anim.call if accepted
          break if accepted
          need_refresh = true
        elsif Input.trigger?(Input::ACTION)
          if specialAction
            need_full_refresh = pbFightMenu_Action(battler, specialAction, cw) if respond_to?(:pbFightMenu_Action)
            accepted = yield specialAction
            break if accepted
            need_refresh = true
          end
        elsif Input.trigger?(Input::SPECIAL)
          if cw.respond_to?(:shiftMode) && cw.shiftMode.to_i > 0
            cmd = respond_to?(:pbFightMenu_Shift) ? pbFightMenu_Shift(battler, cw) : :shift
            accepted = yield cmd
            break if accepted
            need_refresh = true
          end
        end
        pbFightMenu_Extra(battler, specialAction, cw) if respond_to?(:pbFightMenu_Extra)
      end
      pbFightMenu_End(battler, specialAction, cw) if respond_to?(:pbFightMenu_End)
      @lastMove[idxBattler] = cw.index
    ensure
      if @sprites
        @sprites.delete("vermeil_overlay_fight")
      end
      @vermeil_redux_fight_overlay = nil
      overlay.dispose if overlay
      cw.visible = false if cw && cw.respond_to?(:visible=)
      pbHideInfoUI if respond_to?(:pbHideInfoUI)
    end
  end

  module CommandMenuOverride
  def pbCommandMenuEx(idxBattler, texts, mode = 0)
    pbRefreshUIPrompt(idxBattler, Battle::Scene::COMMAND_BOX) if respond_to?(:pbRefreshUIPrompt)
    pbShowWindow(Battle::Scene::COMMAND_BOX)
    cw = @sprites["commandWindow"]
    cw.setTexts(texts)
    cw.setIndexAndMode(@lastCmd[idxBattler], mode)
    pbSelectBattler(idxBattler)
    @sprites["messageBox"].visible = false if @sprites["messageBox"]
    @sprites["messageWindow"].visible = false if @sprites["messageWindow"]

    overlay = VermeilBattleUIRedux::CommandOverlay.new(@viewport, self)
    @vermeil_redux_command_overlay = overlay
    cw.visible = false if cw.respond_to?(:visible=)
    overlay.offset_x = VermeilBattleUIRedux::COMMAND_SLIDE_DISTANCE
    overlay.draw(texts, cw.index, cw.mode)
    fade_frames = 6
    overlay.opacity = 0
    (1..fade_frames).each do |i|
      t = i.to_f / fade_frames
      overlay.opacity = (255 * t).to_i
      overlay.offset_x = ((1.0 - t) * VermeilBattleUIRedux::COMMAND_SLIDE_DISTANCE).round
      overlay.draw(texts, cw.index, cw.mode)
      pbUpdate(cw)
      cw.visible = false if cw.respond_to?(:visible=)
    end
    overlay.offset_x = 0

    ret = -1
    command_exit_anim = proc do
      1.upto(6) do |i|
        t = i.to_f / 6.0
        overlay.offset_x = (VermeilBattleUIRedux::COMMAND_SLIDE_DISTANCE * t).round
        overlay.draw(texts, cw.index, cw.mode)
        pbUpdate(cw)
        cw.visible = false if cw.respond_to?(:visible=)
      end
      overlay.offset_x = 0
    end
    prompt_timer = System.uptime
    loop do
      old_index = cw.index
      pbUpdate(cw)
      if defined?(Settings::UI_PROMPT_DISPLAY) && Settings::UI_PROMPT_DISPLAY == 2 &&
         respond_to?(:pbShowingPrompt?) && pbShowingPrompt?
        pbToggleUIPrompt if respond_to?(:pbToggleUIPrompt) && System.uptime - prompt_timer > 2
      end

      if Input.trigger?(Input::LEFT)
        cw.index = (cw.index - 1) & 3
      elsif Input.trigger?(Input::RIGHT)
        cw.index = (cw.index + 1) & 3
      end

      if cw.index != old_index
        pbPlayCursorSE
        6.times do |i|
          t = (i + 1).to_f / 6.0
          phase_index = (t < 0.5) ? old_index : cw.index
          pulse = (Math.sin(t * Math::PI) * 16).round
          overlay.offset_x = pulse
          overlay.draw(texts, phase_index, cw.mode)
          pbUpdate(cw)
          cw.visible = false if cw.respond_to?(:visible=)
        end
        overlay.offset_x = 0
        overlay.draw(texts, cw.index, cw.mode)
      end

      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = cw.index
        @lastCmd[idxBattler] = ret
        command_exit_anim.call
        overlay.visible = false if overlay.respond_to?(:visible=)
        break
      elsif Input.trigger?(Input::BACK) && mode > 0
        pbPlayCancelSE
        command_exit_anim.call
        break
      elsif Input.trigger?(Input::F9) && $DEBUG
        pbPlayDecisionSE
        pbHideInfoUI if respond_to?(:pbHideInfoUI)
        ret = -2
        command_exit_anim.call
        break
      elsif Input.trigger?(Input::JUMPUP) && !pbInSafari? && respond_to?(:pbToggleBattleInfo)
        pbToggleBattleInfo
        prompt_timer = System.uptime
      elsif Input.trigger?(Input::JUMPDOWN) && !pbInSafari? && respond_to?(:pbToggleBallInfo)
        if pbToggleBallInfo(idxBattler)
          ret = 1
          command_exit_anim.call
          break
        end
        prompt_timer = System.uptime
      end
    end
    return ret
  ensure
    if @sprites
      @sprites.delete("vermeil_overlay_command")
    end
    @vermeil_redux_command_overlay = nil
    overlay.dispose if overlay
    cw.visible = false if cw && cw.respond_to?(:visible=)
  end
  end
end

module VermeilBattleUIRedux
  module AnimationVisibilityOverride
    def vermeil_redux_force_hide_enhanced_ui
      return if @vermeil_redux_hiding_ui
      @vermeil_redux_hiding_ui = true
      @enhancedUIToggle = nil if instance_variable_defined?(:@enhancedUIToggle)
      if @sprites
        @sprites["messageBox"].visible = false if @sprites["messageBox"]
        @sprites["messageWindow"].visible = false if @sprites["messageWindow"]
        @sprites["commandWindow"].visible = false if @sprites["commandWindow"]
        @sprites["fightWindow"].visible = false if @sprites["fightWindow"]
        @sprites["targetWindow"].visible = false if @sprites["targetWindow"]
        @sprites["enhancedUI"].visible = false if @sprites["enhancedUI"]
        @battle&.allBattlers&.each do |b|
          key = "info_icon#{b.index}"
          @sprites[key].visible = false if @sprites[key]
        end
      end
      @enhancedUIOverlay.clear if instance_variable_defined?(:@enhancedUIOverlay) && @enhancedUIOverlay
    ensure
      @vermeil_redux_hiding_ui = false
    end

    def pbBeginAttackPhase(*args)
      # STEP 2a (disabled): hide call during attack phase.
      # vermeil_redux_force_hide_enhanced_ui
      super(*args)
    end

    def pbAnimation(*args)
      # STEP 2b (disabled): animation-time UI/skin manipulation can re-enter
      # message flow and cause duplicate/overlap behavior.
      # vermeil_redux_force_hide_enhanced_ui
      # vermeil_redux_set_message_box_skin(true) if respond_to?(:vermeil_redux_set_message_box_skin)
      super(*args)
    ensure
      # vermeil_redux_set_message_box_skin(false) if respond_to?(:vermeil_redux_set_message_box_skin)
    end

  end
end

module VermeilBattleUIRedux
  module DataBoxSlideDirectionAppear
    def createProcesses
      return if !@sprites["dataBox_#{@idxBox}"]
      box = addSprite(@sprites["dataBox_#{@idxBox}"])
      box.setVisible(0, true)
      box.setOpacity(0, 0) if box.respond_to?(:setOpacity)
      # Both databoxes enter from the LEFT side with fade in
      box.setDelta(0, -Graphics.width / 2, 0)
      box.moveDelta(0, 8, Graphics.width / 2, 0)
      box.moveOpacity(0, 8, 255) if box.respond_to?(:moveOpacity)
    end
  end

  module DataBoxSlideDirectionDisappear
    def createProcesses
      return if !@sprites["dataBox_#{@idxBox}"] || !@sprites["dataBox_#{@idxBox}"].visible
      box = addSprite(@sprites["dataBox_#{@idxBox}"])
      # Both databoxes exit to the LEFT
      box.setOpacity(0, 255) if box.respond_to?(:setOpacity)
      box.moveDelta(0, 8, -Graphics.width / 2, 0)
      box.moveOpacity(0, 8, 0) if box.respond_to?(:moveOpacity)
      box.setVisible(8, false)
    end
  end
end

Battle::Scene.prepend(VermeilBattleUIRedux::FightMenuOverride) if
  !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::FightMenuOverride)

Battle::Scene.prepend(VermeilBattleUIRedux::CommandMenuOverride) if
  !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::CommandMenuOverride)

Battle::Scene.prepend(VermeilBattleUIRedux::AnimationVisibilityOverride) if
  !VermeilBattleUIRedux::VISUAL_ONLY_MODE &&
  !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::AnimationVisibilityOverride)

Battle::Scene.prepend(VermeilBattleUIRedux::MessageBoxLayoutOverride) if
  !VermeilBattleUIRedux::VISUAL_ONLY_MODE &&
  !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::MessageBoxLayoutOverride)

if !VermeilBattleUIRedux::VISUAL_ONLY_MODE
  class Battle::Scene
    alias_method :vermeil_redux_pbInitSprites, :pbInitSprites

    def pbInitSprites
      return vermeil_redux_pbInitSprites if @vermeil_redux_msglayout_init_guard
      @vermeil_redux_msglayout_init_guard = true
      vermeil_redux_pbInitSprites
      return if !@sprites
      msg_box = @sprites["messageBox"]
      msg_win = @sprites["messageWindow"]
      return if !msg_box || !msg_win
      vermeil_redux_set_message_box_skin(false)
      msg_box.x = VermeilBattleUIRedux::TRANSPARENT_MESSAGE_X if msg_box.respond_to?(:x=)
      msg_box.y = VermeilBattleUIRedux::TRANSPARENT_MESSAGE_Y if msg_box.respond_to?(:y=)
      msg_win.x = VermeilBattleUIRedux::TRANSPARENT_TEXT_X if msg_win.respond_to?(:x=)
      msg_win.y = VermeilBattleUIRedux::TRANSPARENT_TEXT_Y if msg_win.respond_to?(:y=)
      if msg_win.respond_to?(:width=) && msg_win.respond_to?(:height=)
        msg_win.width = VermeilBattleUIRedux::TRANSPARENT_TEXT_W
        msg_win.height = VermeilBattleUIRedux::TRANSPARENT_TEXT_H
      end
      # Keep message window body transparent so overlay_message is the only panel.
      msg_win.opacity = 0 if msg_win.respond_to?(:opacity=)
      msg_win.contents_opacity = 255 if msg_win.respond_to?(:contents_opacity=)
      msg_win.back_opacity = 0 if msg_win.respond_to?(:back_opacity=)
      if msg_win.respond_to?(:baseColor=)
        msg_win.baseColor = defined?(Battle::Scene::BASE_DARK) ? Battle::Scene::BASE_DARK : Color.new(56, 56, 56)
      end
      if msg_win.respond_to?(:shadowColor=)
        msg_win.shadowColor = defined?(Battle::Scene::SHADOW_DARK) ? Battle::Scene::SHADOW_DARK : Color.new(184, 184, 184)
      end
      msg_win.z = 999 if msg_win.respond_to?(:z=)
      msg_box.z = 998 if msg_box.respond_to?(:z=)
    ensure
      @vermeil_redux_msglayout_init_guard = false
    end
  end
end

if defined?(Battle::Scene::Animation::DataBoxAppear) &&
   !Battle::Scene::Animation::DataBoxAppear.ancestors.include?(VermeilBattleUIRedux::DataBoxSlideDirectionAppear) &&
   VermeilBattleUIRedux::USE_SLIDE_DATABOX_ANIMATION
  Battle::Scene::Animation::DataBoxAppear.prepend(VermeilBattleUIRedux::DataBoxSlideDirectionAppear)
end

if defined?(Battle::Scene::Animation::DataBoxDisappear) &&
   !Battle::Scene::Animation::DataBoxDisappear.ancestors.include?(VermeilBattleUIRedux::DataBoxSlideDirectionDisappear) &&
   VermeilBattleUIRedux::USE_SLIDE_DATABOX_ANIMATION
  Battle::Scene::Animation::DataBoxDisappear.prepend(VermeilBattleUIRedux::DataBoxSlideDirectionDisappear)
end

#-----------------------------------------------------------------------------
# Visual-only message skin fix
# Keeps the vanilla message window body transparent so overlay_message remains
# the only visible panel, without overriding pbShowWindow.
#-----------------------------------------------------------------------------
if VermeilBattleUIRedux::VISUAL_ONLY_MODE
  module VermeilBattleUIRedux
    module VisualOnlyMessageSkinFix
      def vermeil_redux_apply_visual_message_skin
        return if !@sprites
        msg_box = @sprites["messageBox"]
        msg_win = @sprites["messageWindow"]
        return if !msg_box || !msg_win
        msg_win.opacity = 0 if msg_win.respond_to?(:opacity=)
        msg_win.back_opacity = 0 if msg_win.respond_to?(:back_opacity=)
        msg_win.contents_opacity = 255 if msg_win.respond_to?(:contents_opacity=)
        msg_win.z = 999 if msg_win.respond_to?(:z=)
        msg_box.z = 998 if msg_box.respond_to?(:z=)
      end

      def pbUpdate(*args)
        super(*args)
        vermeil_redux_apply_visual_message_skin
      end

      def pbSendOutBattlers(sendOuts, startBattle = false)
        super
        return if !@sprites || !sendOuts
        # Ensure databoxes are visible after switch (but let animation handle position)
        sendOuts.each do |entry|
          next if !entry || !entry[0]
          idx = entry[0]
          box = @sprites["dataBox_#{idx}"]
          next if !box
          # Set battler data
          if box.respond_to?(:battler=) && @battle && @battle.battlers[idx]
            box.battler = @battle.battlers[idx]
          end
          # Ensure visibility
          box.visible = true if box.respond_to?(:visible=)
          box.opacity = 255 if box.respond_to?(:opacity=)
          # Refresh the box
          pbRefreshOne(idx) if respond_to?(:pbRefreshOne)
          box.refresh if box.respond_to?(:refresh)
        end
      end
    end
  end

  Battle::Scene.prepend(VermeilBattleUIRedux::VisualOnlyMessageSkinFix) if
    !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::VisualOnlyMessageSkinFix)
end

# Visual-only mode databox positioning
if VermeilBattleUIRedux::VISUAL_ONLY_MODE
  module VermeilBattleUIRedux
    module VisualOnlyDataboxPosition
      def pbInitSprites
        super
        return if !@sprites
        # Reposition databoxes after initialization
        2.times do |idx|
          box = @sprites["dataBox_#{idx}"]
          next if !box
          if idx.even?
            # Player: bottom left
            box.y = Graphics.height - 96 if box.respond_to?(:y=)
          else
            # Opponent: top - ensure higher Z to appear in front of battlers
            box.y = VermeilBattleUIRedux::ENEMY_DATABOX_TOP_MARGIN if box.respond_to?(:y=)
            box.z = 100 if box.respond_to?(:z=)  # Higher Z for opponent databox
          end
        end
      end
    end
  end

  Battle::Scene.prepend(VermeilBattleUIRedux::VisualOnlyDataboxPosition) if
    !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::VisualOnlyDataboxPosition)
end

module VermeilBattleUIRedux
  module MessageDedupeOverride
    DEDUPE_WINDOW_SECONDS = 2.5

    # Lógica de dedupe compartida — devuelve true si debe suprimirse
    def vermeil_should_suppress_used_msg?(msg)
      text = msg.to_s.strip
      normalized = text.downcase.gsub(/\s+/, " ")
      return false if normalized.empty?
      return false unless normalized =~ /\A.+ used .+!\z/
      now = System.uptime
      if @vermeil_redux_last_used_normalized == normalized &&
         @vermeil_redux_last_used_line_time &&
         (now - @vermeil_redux_last_used_line_time) < DEDUPE_WINDOW_SECONDS
        return true
      end
      @vermeil_redux_last_used_normalized = normalized
      @vermeil_redux_last_used_line_time = now
      return false
    end

    def vermeil_hide_battle_overlays
      if @sprites
        ["vermeil_overlay_command", "vermeil_overlay_fight"].each do |key|
          spr = @sprites[key]
          spr.visible = false if spr && spr.respond_to?(:visible=)
        end
        @sprites["commandWindow"].visible = false if @sprites["commandWindow"] && @sprites["commandWindow"].respond_to?(:visible=)
        @sprites["fightWindow"].visible = false if @sprites["fightWindow"] && @sprites["fightWindow"].respond_to?(:visible=)
      end
      @vermeil_redux_command_overlay.visible = false if defined?(@vermeil_redux_command_overlay) && @vermeil_redux_command_overlay && @vermeil_redux_command_overlay.respond_to?(:visible=)
      @vermeil_redux_fight_overlay.visible = false if defined?(@vermeil_redux_fight_overlay) && @vermeil_redux_fight_overlay && @vermeil_redux_fight_overlay.respond_to?(:visible=)
    end
  end
end