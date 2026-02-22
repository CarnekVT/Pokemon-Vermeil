#===============================================================================
# [VERMEIL] BattleAnimations
# [010] Water Shuriken Animation
#===============================================================================

module VermeilBattleAnimations
  module_function

  WATER_SHURIKEN_ASSETS = [
    "Graphics/BattleParticlesAnimations/WaterShuriken",
    "Graphics/BattleParticlesAnimations/watershuriken"
  ]
  WATER_SHURIKEN_DROPS_ASSETS = [
    "Graphics/BattleParticlesAnimations/Water-Drops",
    "Graphics/BattleParticlesAnimations/Bubbles-Drops"
  ]

  WATER_SHURIKEN_SE_THROW  = "Anim/PRSFX- Water Shurkein"
  WATER_SHURIKEN_SE_IMPACT = "Anim/PRSFX- Water Pulse2"
end

class Battle::Scene::Animation::VermeilWaterShuriken < Battle::Scene::Animation
  DROP_FRAME_W = 32
  DROP_FRAME_H = 32

  def initialize(sprites, viewport, user, target, hit_num = 0)
    @user = user
    @target = target
    @hit_num = hit_num || 0
    super(sprites, viewport)
  end

  def createProcesses
    return if !@user || !@target
    user_sprite = @sprites["pokemon_#{@user.index}"]
    target_sprite = @sprites["pokemon_#{@target.index}"]
    return if !user_sprite || !target_sprite

    shuriken_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::WATER_SHURIKEN_ASSETS)
    drops_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::WATER_SHURIKEN_DROPS_ASSETS)
    return if !shuriken_asset

    combo_step = [@hit_num.to_i, 0].max
    speed_bonus = [combo_step, 4].min
    travel_frames = [14 - speed_bonus, 8].max
    interval = [2 - (speed_bonus / 2), 1].max

    forward_dir = (@user.index & 1) == 0 ? 1 : -1
    start_x = user_sprite.x + (forward_dir * 24)
    start_y = user_sprite.y - 44
    impact_x = target_sprite.x - (forward_dir * 6)
    impact_y = target_sprite.y - 46

    target_pic = addSprite(target_sprite, PictureOrigin::BOTTOM)

    shuriken = addNewSprite(start_x, start_y, shuriken_asset, PictureOrigin::CENTER)
    shuriken.setZ(0, target_sprite.z + 8)
    shuriken.setVisible(0, true)
    shuriken.setOpacity(0, 0)
    shuriken.setZoom(0, 74)
    shuriken.setTone(0, Tone.new(-100, -50, 150, 50))
    shuriken.moveOpacity(0, 2, 255)
    shuriken.moveXY(1, travel_frames, impact_x, impact_y)
    shuriken.moveZoom(1, travel_frames, 98)
    shuriken.moveAngle(0, travel_frames + 2, (900 + (combo_step * 180)) * forward_dir)
    shuriken.setSE(1, VermeilBattleAnimations::WATER_SHURIKEN_SE_THROW, 92, 108)

    blur = addNewSprite(start_x - (forward_dir * 8), start_y + 4, shuriken_asset, PictureOrigin::CENTER)
    blur.setZ(0, target_sprite.z + 7)
    blur.setVisible(0, true)
    blur.setOpacity(0, 0)
    blur.setZoom(0, 70)
    blur.setTone(0, Tone.new(-130, -70, 170, 70))
    blur.setAngle(0, 35 * forward_dir)
    blur.moveOpacity(0, 2, 130)
    blur.moveXY(2, travel_frames, impact_x - (forward_dir * 6), impact_y + 4)
    blur.moveZoom(2, travel_frames, 90)
    blur.moveAngle(1, travel_frames + 2, (760 + (combo_step * 140)) * forward_dir)
    blur.moveOpacity(travel_frames - 1, 3, 0)

    if drops_asset
      9.times do |i|
        t = 2 + (i * interval)
        lerp = [[t.to_f / [travel_frames, 1].max, 0.95].min, 0.05].max
        x = (start_x + ((impact_x - start_x) * lerp)).round
        y = (start_y + ((impact_y - start_y) * lerp)).round + ((i % 2) * 4)
        d = addNewSprite(x, y, drops_asset, PictureOrigin::CENTER)
        apply_drop_frame(d, i)
        animate_drop_frames(d, t, 5, i)
        d.setZ(0, target_sprite.z + 6)
        d.setVisible(0, false)
        d.setOpacity(0, 0)
        d.setZoom(0, 42 + (i % 3) * 4)
        d.setTone(0, Tone.new(-80, -40, 140, 40))
        d.setVisible(t, true)
        d.moveOpacity(t, 1, 200)
        d.moveDelta(t, 6, -(forward_dir * (6 + (i % 2) * 3)), 7 + (i % 3))
        d.moveOpacity(t + 2, 5, 0)
        d.setVisible(t + 8, false)
      end
    end

    impact_t = travel_frames + 1
    impact = addNewSprite(impact_x, impact_y, shuriken_asset, PictureOrigin::CENTER)
    impact.setZ(0, target_sprite.z + 10)
    impact.setVisible(0, false)
    impact.setOpacity(0, 0)
    impact.setZoom(0, 56)
    impact.setTone(0, Tone.new(-170, -90, 220, 90))
    impact.setVisible(impact_t, true)
    impact.moveOpacity(impact_t, 1, 255)
    impact.moveZoom(impact_t, 3, 126)
    impact.moveOpacity(impact_t + 1, 4, 0)
    impact.setSE(impact_t, VermeilBattleAnimations::WATER_SHURIKEN_SE_IMPACT, 90, 115)
    impact.setVisible(impact_t + 6, false)

    if drops_asset
      splash_dirs = [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]]
      splash_dirs.each_with_index do |dir, i|
        s = addNewSprite(impact_x, impact_y, drops_asset, PictureOrigin::CENTER)
        apply_drop_frame(s, i + 2)
        animate_drop_frames(s, impact_t, 4, i + combo_step)
        s.setZ(0, target_sprite.z + 9)
        s.setVisible(0, false)
        s.setOpacity(0, 0)
        s.setZoom(0, 52)
        s.setTone(0, Tone.new(-95, -45, 155, 45))
        s.setVisible(impact_t, true)
        s.moveOpacity(impact_t, 1, 255)
        s.moveDelta(impact_t, 5, dir[0] * (18 + (i % 2) * 4), dir[1] * (14 + (i % 3) * 3))
        s.moveOpacity(impact_t + 1, 5, 0)
        s.setVisible(impact_t + 7, false)
      end
    end

    shake = 6 + speed_bonus
    target_pic.moveDelta(impact_t, 1, shake * forward_dir, 0)
    target_pic.moveDelta(impact_t + 1, 1, -((shake * 2) * forward_dir), 0)
    target_pic.moveDelta(impact_t + 2, 1, shake * forward_dir, 0)

    shuriken.moveOpacity(impact_t, 2, 0)
    blur.moveOpacity(impact_t, 2, 0)
  end

  def drop_frame_count(asset_path)
    return 1 if !asset_path
    resolved = pbResolveBitmap(asset_path)
    return 1 if !resolved
    bmp = nil
    begin
      bmp = Bitmap.new(resolved)
      return 1 if !bmp || bmp.disposed?
      cols = [bmp.width / DROP_FRAME_W, 1].max
      rows = [bmp.height / DROP_FRAME_H, 1].max
      return [cols * rows, 1].max
    ensure
      bmp.dispose if bmp && !bmp.disposed?
    end
  rescue
    return 1
  end

  def apply_drop_frame(picture, frame_index)
    return if !picture
    asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::WATER_SHURIKEN_DROPS_ASSETS)
    return if !asset
    count = drop_frame_count(asset)
    idx = frame_index % count
    cols = 1
    resolved = pbResolveBitmap(asset)
    if resolved
      bmp = nil
      begin
        bmp = Bitmap.new(resolved)
        cols = [bmp.width / DROP_FRAME_W, 1].max
      ensure
        bmp.dispose if bmp && !bmp.disposed?
      end
    end
    col = idx % cols
    row = idx / cols
    picture.setSrc(0, col * DROP_FRAME_W, row * DROP_FRAME_H)
    picture.setSrcSize(0, DROP_FRAME_W, DROP_FRAME_H)
    picture.setOrigin(0, PictureOrigin::CENTER)
  rescue
  end

  def animate_drop_frames(picture, start_t, duration, start_index = 0)
    return if !picture
    asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::WATER_SHURIKEN_DROPS_ASSETS)
    return if !asset
    count = drop_frame_count(asset)
    return if count <= 1
    cols = 1
    resolved = pbResolveBitmap(asset)
    if resolved
      bmp = nil
      begin
        bmp = Bitmap.new(resolved)
        cols = [bmp.width / DROP_FRAME_W, 1].max
      ensure
        bmp.dispose if bmp && !bmp.disposed?
      end
    end
    duration.times do |j|
      idx = (start_index + j) % count
      col = idx % cols
      row = idx / cols
      picture.setSrc(start_t + j, col * DROP_FRAME_W, row * DROP_FRAME_H)
      picture.setSrcSize(start_t + j, DROP_FRAME_W, DROP_FRAME_H)
    end
  rescue
  end
end

#===============================================================================
# Battle::Scene — Water Shuriken
#
# Message overlay strategy aligned with Toxic Spikes:
#   - No pbShowWindow monkey patches.
#   - Keep the message skin transparent while the combo is active.
#   - Show normal overlay only for critical text and final combo text
#     (effectiveness / hit count), then restore transparent mode if needed.
#===============================================================================
class Battle::Scene
  WS_DEFAULT_MESSAGE_ASSET = "Graphics/UI/Battle/overlay_message"
  WS_TRANSPARENT_MESSAGE_ASSET = "Graphics/UI/Battle/transparent_message"

  # ---------------------------------------------------------------------------
  # Message helpers
  # ---------------------------------------------------------------------------
  unless method_defined?(:vermeil_ws_is_final_hits_message?)
    def vermeil_ws_is_final_hits_message?(text)
      t = text.to_s.downcase
      return true if t.include?(" hit ") && t.include?(" time")
      return true if t.include?(" times!")
      return false
    end
  end

  unless method_defined?(:vermeil_ws_is_used_line?)
    def vermeil_ws_is_used_line?(text)
      t = text.to_s.downcase
      return t.include?("used") && t.include?("water shuriken")
    end
  end

  unless method_defined?(:vermeil_ws_is_effectiveness_line?)
    def vermeil_ws_is_effectiveness_line?(text)
      t = text.to_s.downcase
      return true if t.include?("super effective")
      return true if t.include?("not very effective")
      return true if t.include?("had no effect")
      return false
    end
  end

  unless method_defined?(:vermeil_ws_set_message_skin)
    def vermeil_ws_set_message_skin(use_transparent)
      return if !@sprites
      msg_box = @sprites["messageBox"]
      return if !msg_box || !msg_box.respond_to?(:setBitmap)
      asset = use_transparent ? WS_TRANSPARENT_MESSAGE_ASSET : WS_DEFAULT_MESSAGE_ASSET
      return if !pbResolveBitmap(asset)
      msg_box.setBitmap(asset)
    rescue
    end
  end

  unless method_defined?(:vermeil_ws_finalize_sequence_for_text!)
    def vermeil_ws_finalize_sequence_for_text!
      @vermeil_ws_sequence_active = false
      @vermeil_ws_sequence_done   = true
      @vermeil_ws_anim_active     = false
      @vermeil_ws_hit_num         = nil
      @vermeil_ws_msg_filter_until = nil
      @vermeil_ws_keep_databox_idx = nil
      vermeil_ws_set_message_skin(false)
      pbRefresh if respond_to?(:pbRefresh)
    end
  end

  unless method_defined?(:vermeil_ws_clear_message_window!)
    def vermeil_ws_clear_message_window!
      return if !@sprites
      msg_box = @sprites["messageBox"]
      msg_win = @sprites["messageWindow"]
      if msg_win
        msg_win.text = "" if msg_win.respond_to?(:text=)
        msg_win.visible = false if msg_win.respond_to?(:visible=)
      end
      if msg_box
        msg_box.visible = false if msg_box.respond_to?(:visible=)
      end
    end
  end

  unless method_defined?(:vermeil_ws_show_message_window!)
    def vermeil_ws_show_message_window!
      return if !@sprites
      msg_box = @sprites["messageBox"]
      msg_win = @sprites["messageWindow"]
      if msg_box
        msg_box.visible = true if msg_box.respond_to?(:visible=)
        msg_box.opacity = 255 if msg_box.respond_to?(:opacity=)
      end
      if msg_win
        msg_win.visible = true if msg_win.respond_to?(:visible=)
        msg_win.contents_opacity = 255 if msg_win.respond_to?(:contents_opacity=)
      end
    end
  end

  # Suppress between-hit effectiveness spam (not on the final hit)
  unless method_defined?(:vermeil_ws_suppress_between_hits?)
    def vermeil_ws_suppress_between_hits?(msg)
      return false if !@vermeil_ws_sequence_active
      return false if !@vermeil_ws_msg_filter_until
      return false if @vermeil_ws_hit_num.to_i <= 0
      return false if System.uptime > @vermeil_ws_msg_filter_until
      text = msg.to_s.downcase
      return false if text.include?("critical")
      return true  if text.include?("super effective")
      return true  if text.include?("not very effective")
      return true  if text.include?("had no effect")
      return false
    end
  end

  # ---------------------------------------------------------------------------
  # pbDisplayMessage — filter mid-sequence messages.
  # Does NOT touch any sprites. Just decides what text to show.
  # ---------------------------------------------------------------------------
  unless method_defined?(:vermeil_ws_pbDisplayMessage)
    alias_method :vermeil_ws_pbDisplayMessage, :pbDisplayMessage

    def pbDisplayMessage(msg, brief = false)
      if @vermeil_ws_sequence_active && vermeil_ws_is_used_line?(msg)
        vermeil_ws_clear_message_window!
        return
      end
      if vermeil_ws_suppress_between_hits?(msg)
        vermeil_ws_clear_message_window!
        return
      end

      if @vermeil_ws_sequence_active
        text = msg.to_s.downcase
        if vermeil_ws_is_used_line?(text)
          vermeil_ws_clear_message_window!
          return
        elsif text.include?("critical")
          # Temporary normal overlay for critical messages during the combo.
          @vermeil_ws_force_message = true
          begin
            vermeil_ws_set_message_skin(false)
            vermeil_ws_show_message_window!
            pbRefresh if respond_to?(:pbRefresh)
            vermeil_ws_pbDisplayMessage(msg, brief)
          ensure
            @vermeil_ws_force_message = false
          end
          vermeil_ws_set_message_skin(true) if @vermeil_ws_sequence_active
          return
        elsif !@vermeil_ws_anim_active && (vermeil_ws_is_effectiveness_line?(text) || vermeil_ws_is_final_hits_message?(text))
          # Finalize on effectiveness (or fallback final hit line), then show text.
          vermeil_ws_finalize_sequence_for_text!
          @vermeil_ws_force_message = true
          begin
            vermeil_ws_set_message_skin(false)
            vermeil_ws_show_message_window!
            pbRefresh if respond_to?(:pbRefresh)
            vermeil_ws_pbDisplayMessage(msg, brief)
          ensure
            @vermeil_ws_force_message = false
          end
          return
        else
          # Hide all intermediate text while sequence is active.
          vermeil_ws_clear_message_window!
          return
        end
      end

      vermeil_ws_pbDisplayMessage(msg, brief)
    end
  end

  if !method_defined?(:vermeil_ws_pbDisplayBrief) &&
     (method_defined?(:pbDisplayBrief) || private_method_defined?(:pbDisplayBrief))
    alias_method :vermeil_ws_pbDisplayBrief, :pbDisplayBrief

    def pbDisplayBrief(msg)
      if @vermeil_ws_sequence_active && vermeil_ws_is_used_line?(msg)
        vermeil_ws_clear_message_window!
        return
      end
      if @vermeil_ws_sequence_active
        text = msg.to_s.downcase
        if !@vermeil_ws_anim_active && (vermeil_ws_is_effectiveness_line?(text) || vermeil_ws_is_final_hits_message?(text))
          vermeil_ws_finalize_sequence_for_text!
          @vermeil_ws_force_message = true
          begin
            vermeil_ws_set_message_skin(false)
            vermeil_ws_show_message_window!
            pbRefresh if respond_to?(:pbRefresh)
            ret = (vermeil_ws_pbDisplayBrief(msg) if respond_to?(:vermeil_ws_pbDisplayBrief))
          ensure
            @vermeil_ws_force_message = false
          end
          return ret
        elsif text.include?("critical")
          @vermeil_ws_force_message = true
          begin
            vermeil_ws_set_message_skin(false)
            vermeil_ws_show_message_window!
            pbRefresh if respond_to?(:pbRefresh)
            ret = (vermeil_ws_pbDisplayBrief(msg) if respond_to?(:vermeil_ws_pbDisplayBrief))
          ensure
            @vermeil_ws_force_message = false
          end
          vermeil_ws_set_message_skin(true) if @vermeil_ws_sequence_active
          return ret
        end
        vermeil_ws_clear_message_window!
        return
      end
      return vermeil_ws_pbDisplayBrief(msg)
    end
  end

  if !method_defined?(:vermeil_ws_pbDisplayPaused) &&
     (method_defined?(:pbDisplayPaused) || private_method_defined?(:pbDisplayPaused))
    alias_method :vermeil_ws_pbDisplayPaused, :pbDisplayPaused

    def pbDisplayPaused(msg)
      if @vermeil_ws_sequence_active && vermeil_ws_is_used_line?(msg)
        vermeil_ws_clear_message_window!
        return
      end
      if @vermeil_ws_sequence_active
        text = msg.to_s.downcase
        if !@vermeil_ws_anim_active && (vermeil_ws_is_effectiveness_line?(text) || vermeil_ws_is_final_hits_message?(text))
          vermeil_ws_finalize_sequence_for_text!
          @vermeil_ws_force_message = true
          begin
            vermeil_ws_set_message_skin(false)
            vermeil_ws_show_message_window!
            pbRefresh if respond_to?(:pbRefresh)
            ret = (vermeil_ws_pbDisplayPaused(msg) if respond_to?(:vermeil_ws_pbDisplayPaused))
          ensure
            @vermeil_ws_force_message = false
          end
          return ret
        elsif text.include?("critical")
          @vermeil_ws_force_message = true
          begin
            vermeil_ws_set_message_skin(false)
            vermeil_ws_show_message_window!
            pbRefresh if respond_to?(:pbRefresh)
            ret = (vermeil_ws_pbDisplayPaused(msg) if respond_to?(:vermeil_ws_pbDisplayPaused))
          ensure
            @vermeil_ws_force_message = false
          end
          vermeil_ws_set_message_skin(true) if @vermeil_ws_sequence_active
          return ret
        end
        vermeil_ws_clear_message_window!
        return
      end
      return vermeil_ws_pbDisplayPaused(msg)
    end
  end

  if false && !method_defined?(:vermeil_ws_pbUpdate_cleanup)
    alias_method :vermeil_ws_pbUpdate_cleanup, :pbUpdate
    def pbUpdate(*args)
      vermeil_ws_pbUpdate_cleanup(*args)
      # Failsafe: avoid stuck sequence/text if final line wasn't emitted.
      if @vermeil_ws_sequence_active && !@vermeil_ws_anim_active
        deadline = (@vermeil_ws_msg_filter_until || 0) + 0.45
        if System.uptime > deadline
          vermeil_ws_finalize_sequence_for_text!
          vermeil_ws_clear_message_window!
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # pbPlayVermeilWaterShuriken — plays ONE shuriken hit.
  # ---------------------------------------------------------------------------
  def pbPlayVermeilWaterShuriken(user, targets, hit_num = 0)
    target = nil
    if targets.is_a?(Array)
      targets.each do |t|
        next if !t || t.fainted? || t.hp <= 0
        target = t
        break
      end
    else
      target = targets
    end
    return false if !user || !target

    @vermeil_ws_anim_active = true
    vermeil_ws_set_message_skin(true)
    vermeil_ws_clear_message_window!

    begin
      anim = Animation::VermeilWaterShuriken.new(@sprites, @viewport, user, target, hit_num)
      loop do
        anim.update
        pbUpdate
        break if anim.animDone?
      end
      anim.dispose
    ensure
      @vermeil_ws_anim_active = false
      # Keep transparent skin only while sequence is active.
      vermeil_ws_set_message_skin(false) if !@vermeil_ws_sequence_active
    end
    return true
  end

  # Compatibility stubs
  def vermeil_ws_capture_ui_state(keep_databox_idx = nil); end
  def vermeil_ws_restore_ui_state; end
  def vermeil_hold_custom_ui_hidden(frames = 90); end

  unless method_defined?(:vermeil_text_ui_key?)
    def vermeil_text_ui_key?(key_str)
      k = key_str.to_s.downcase
      return true if k.include?("commandwindow")
      return true if k.include?("fightwindow")
      return false
    end
  end

  unless method_defined?(:vermeil_play_custom_move_with_hidden_ui)
    def vermeil_custom_move_ui_targets
      targets = []
      return targets if !@sprites
      @sprites.each do |key, sprite|
        next if !sprite || !sprite.respond_to?(:visible=)
        next unless vermeil_text_ui_key?(key.to_s)
        targets << [key, sprite]
      end
      return targets
    end

    def vermeil_play_custom_move_with_hidden_ui
      targets = vermeil_custom_move_ui_targets
      vis_state = {}
      op_state  = {}
      targets.each do |key, sprite|
        vis_state[key] = sprite.respond_to?(:visible) ? sprite.visible : true
        op_state[key]  = sprite.respond_to?(:opacity) ? sprite.opacity : nil
      end
      targets.each do |key, sprite|
        sprite.visible = false if sprite.respond_to?(:visible=)
        sprite.opacity = 0     if sprite.respond_to?(:opacity=)
      end
      begin
        yield
      ensure
        targets.each do |key, sprite|
          sprite.visible = vis_state[key].nil? ? true : vis_state[key] if sprite.respond_to?(:visible=)
          sprite.opacity = op_state[key].nil?  ? 255  : op_state[key]  if sprite.respond_to?(:opacity=)
        end
        pbRefresh if respond_to?(:pbRefresh)
      end
    end
  end
end

#===============================================================================
# Battle — pbAnimation hook
#===============================================================================
class Battle
  alias_method :vermeil_water_shuriken_pbAnimation, :pbAnimation unless method_defined?(:vermeil_water_shuriken_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)

    if @showAnims && move_id == :WATERSHURIKEN && @scene.respond_to?(:pbPlayVermeilWaterShuriken)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_ws_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_ws_sequence_done,   false)
      end
      @scene.instance_variable_set(:@vermeil_ws_hit_num,          hitNum.to_i)
      @scene.instance_variable_set(:@vermeil_ws_msg_filter_until,  System.uptime + 0.80)
      return if @scene.pbPlayVermeilWaterShuriken(user, targets, hitNum)
    end

    # Cleanup if sequence got stuck (no "Hit N times" message)
    if @scene
      @scene.instance_variable_set(:@vermeil_ws_sequence_active, false)
      @scene.instance_variable_set(:@vermeil_ws_sequence_done,   false)
      @scene.instance_variable_set(:@vermeil_ws_anim_active,     false)
      @scene.vermeil_ws_set_message_skin(false) if @scene.respond_to?(:vermeil_ws_set_message_skin)
      @scene.vermeil_ws_clear_message_window! if @scene.respond_to?(:vermeil_ws_clear_message_window!)
    end

    vermeil_water_shuriken_pbAnimation(move, user, targets, hitNum)
  end
end
