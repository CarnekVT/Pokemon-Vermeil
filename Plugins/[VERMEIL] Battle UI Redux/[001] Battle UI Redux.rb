#===============================================================================
# [VERMEIL] Battle UI Redux
# Re-skins the command menu into a compact right-side layout.
#===============================================================================

module VermeilBattleUIRedux
  module_function

  PLAYER_DATABOX_X = 0
  PLAYER_DATABOX_BOTTOM_MARGIN = 2
  FIGHT_LIST_X = 287
  FIGHT_LIST_Y = 146
  FIGHT_LIST_W = 204
  FIGHT_ROW_H = 38
  FIGHT_ROW_GAP = 8
  REDUX_OVERLAY_Z = 250
  ACTION_HINT_Y_OFFSET = -8
  FIGHT_SLIDE_DISTANCE = 220
  COMMAND_SLIDE_DISTANCE = 220

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

  def fight_list_x
    return Graphics.width - 225
  end

  def fight_list_y
    return Graphics.height - 238
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
    def initialize(viewport)
      @sprite = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
      @sprite.z = VermeilBattleUIRedux::REDUX_OVERLAY_Z
      pbSetNarrowFont(@sprite.bitmap)
      @button_bitmap = nil
      @button_bitmap = AnimatedBitmap.new(_INTL("Graphics/UI/Battle/cursor_command")) rescue nil
      @last_state = nil
      @offset_x = 0
    end

    def dispose
      @button_bitmap&.dispose
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

      labels = [texts[1], texts[2], texts[3], texts[4]]
      base_x = (Graphics.width - 186) + @offset_x
      base_y = Graphics.height - 166
      main_w = 164
      main_h = 58
      small_w = 64
      small_h = 30

      draw_arrows(bmp, base_x + 34, base_y + 6, 96)
      draw_button(bmp, base_x, base_y + 20, main_w, main_h, index, labels[index], true, mode)

      secondary = VermeilBattleUIRedux::SECONDARY_LAYOUT[index]
      draw_button(bmp, base_x + 6,  base_y + 90, small_w, small_h, secondary[0], "", false, mode)
      draw_button(bmp, base_x + 94, base_y + 90, small_w, small_h, secondary[1], "", false, mode)
      draw_button(bmp, base_x + 50, base_y + 126, small_w, small_h, secondary[2], "", false, mode)
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
      bmp.draw_text(x + 6, y + 4, w - 10, h - 8, text.to_s, 1) if large
    end
  end

  class FightOverlay
    def initialize(viewport)
      @sprite = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
      @sprite.z = VermeilBattleUIRedux::REDUX_OVERLAY_Z
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
      base_y = VermeilBattleUIRedux.fight_list_y + (4 * (VermeilBattleUIRedux::FIGHT_ROW_H + VermeilBattleUIRedux::FIGHT_ROW_GAP)) + 14
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
      x = VermeilBattleUIRedux.fight_list_x - 82 + offset_x
      y = VermeilBattleUIRedux.fight_list_y + (2 * (VermeilBattleUIRedux::FIGHT_ROW_H + VermeilBattleUIRedux::FIGHT_ROW_GAP)) + VermeilBattleUIRedux::ACTION_HINT_Y_OFFSET
      if @mega_bitmap && @mega_bitmap.bitmap && action_symbol == :mega
        src = @mega_bitmap.bitmap
        bmp.stretch_blt(Rect.new(x, y, 72, 32), src, Rect.new(0, 0, src.width, src.height))
      else
        bmp.fill_rect(x, y, 72, 32, Color.new(170, 110, 80))
      end
      if active
        glow = (pulse == 0) ? 96 : 48
        bmp.fill_rect(x - 2, y - 2, 76, 36, Color.new(120, 220, 255, glow))
      end
      pbDrawTextPositions(bmp, [[action_text, x + 36, y + 34, :center, Color.new(248, 248, 248), Color.new(0, 0, 0), :outline]])
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

      overlay = VermeilBattleUIRedux::FightOverlay.new(@viewport)
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
          pbPlayDecisionSE
          cmd = respond_to?(:pbFightMenu_Confirm) ? pbFightMenu_Confirm(battler, specialAction, cw) : cw.index
          accepted = yield cmd
          break if accepted
          need_full_refresh = true
          need_refresh = true
        elsif Input.trigger?(Input::BACK)
          if instance_variable_defined?(:@enhancedUIToggle) && @enhancedUIToggle == :move &&
             respond_to?(:pbHideInfoUI)
            pbPlayCancelSE
            pbHideInfoUI
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

    overlay = VermeilBattleUIRedux::CommandOverlay.new(@viewport)
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
      elsif Input.trigger?(Input::UP)
        cw.index = (cw.index - 1) & 3
      elsif Input.trigger?(Input::DOWN)
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
      vermeil_redux_force_hide_enhanced_ui
      super(*args)
    end

    def pbAnimation(*args)
      vermeil_redux_force_hide_enhanced_ui
      super(*args)
    end

  end
end

Battle::Scene.prepend(VermeilBattleUIRedux::FightMenuOverride) if
  !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::FightMenuOverride)

Battle::Scene.prepend(VermeilBattleUIRedux::CommandMenuOverride) if
  !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::CommandMenuOverride)

Battle::Scene.prepend(VermeilBattleUIRedux::AnimationVisibilityOverride) if
  !Battle::Scene.ancestors.include?(VermeilBattleUIRedux::AnimationVisibilityOverride)
