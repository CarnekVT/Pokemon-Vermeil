#===============================================================================
# [VERMEIL] BattleAnimations
# [007] Selfdestruct Cinematic Animation
#===============================================================================

class Battle::Scene::Animation::VermeilCinematicSelfdestruct < Battle::Scene::Animation::VermeilCinematicExplosion
  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    return if !user_sprite

    center_x = Graphics.width / 2
    center_y = (Graphics.height / 2) + 56
    fx_x = (Graphics.width / 2) - 8
    fx_y = (Graphics.height / 2) - 16

    base_bg = nil
    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_BASE)
      base_bg = addNewSprite(Graphics.width / 2, Graphics.height / 2, VermeilBattleAnimations::EXPLOSION_BG_BASE,
                             PictureOrigin::CENTER)
      base_bg.setZ(0, 500)
      base_bg.setOpacity(0, 255)
      base_bg.setVisible(0, true)
    end

    attacker = build_front_attacker_sprite(user_sprite, center_x, center_y)
    attacker.setZ(0, 690)
    attacker.setVisible(0, true)
    attacker.setZoom(0, 100)
    attacker.moveColor(20, 3, Color.new(255, 255, 255, 170))
    attacker.moveColor(23, 3, Color.new(255, 255, 255, 0))
    attacker.moveColor(27, 3, Color.new(255, 255, 255, 220))
    attacker.moveColor(30, 3, Color.new(255, 255, 255, 0))
    attacker.moveColor(34, 3, Color.new(255, 255, 255, 255))
    attacker.moveColor(37, 3, Color.new(255, 255, 255, 0))
    attacker.setSE(20, VermeilBattleAnimations::EXPLOSION_SE_CHARGE_1)
    attacker.setSE(30, VermeilBattleAnimations::EXPLOSION_SE_CHARGE_2)
    attacker.moveZoom(40, 3, 88)
    attacker.moveZoom(43, 2, 126)
    attacker.moveZoom(45, 3, 100)
    attacker.setSE(44, VermeilBattleAnimations::EXPLOSION_SE_RELEASE)
    attacker.setSE(45, VermeilBattleAnimations::EXPLOSION_SE_BLAST)
    attacker.setSE(47, VermeilBattleAnimations::EXPLOSION_SE_BLAST, 90, 90)

    blast_bg = nil
    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_BLAST)
      blast_bg = addNewSprite(Graphics.width / 2, Graphics.height / 2, VermeilBattleAnimations::EXPLOSION_BG_BLAST,
                              PictureOrigin::CENTER)
      blast_bg.setZ(0, 505)
      blast_bg.setOpacity(0, 0)
      blast_bg.setVisible(0, false)
      blast_bg.setVisible(45, true)
      blast_bg.setOpacity(45, 240)
      blast_bg.setOpacity(65, 210)
      base_bg.setVisible(45, false) if base_bg
    end

    charge_asset = VermeilBattleAnimations.first_existing_asset(
      VermeilBattleAnimations::EXPLOSION_CHARGE_PARTICLE_ASSETS
    )
    shockwave_asset = VermeilBattleAnimations.first_existing_asset(
      VermeilBattleAnimations::EXPLOSION_SHOCKWAVE_ASSETS
    )
    # Energy accumulation before detonation.
    if charge_asset
      charge_dirs = [
        [-1.0, 0.0], [1.0, 0.0], [0.0, -1.0], [0.0, 1.0],
        [-0.7, -0.7], [0.7, -0.7], [-0.7, 0.7], [0.7, 0.7]
      ]
      charge_dirs.each_with_index do |dir, i|
        t = 14 + (i % 4) * 3
        radius = 82 + (i / 4) * 12
        p = addNewSprite(fx_x + (dir[0] * radius).round, fx_y + (dir[1] * radius).round, charge_asset, PictureOrigin::CENTER)
        apply_sheet_frame(p, charge_asset, :charge)
        p.setZ(0, 742)
        p.setVisible(0, false)
        p.setOpacity(0, 0)
        p.setZoom(0, 24)
        p.setTone(0, Tone.new(-80, -80, -80, 0))
        p.setVisible(t, true)
        p.moveOpacity(t, 2, 220)
        p.moveXY(t, 10, fx_x, fx_y)
        p.moveZoom(t, 10, 56)
        p.moveOpacity(t + 6, 5, 0)
        p.setVisible(t + 12, false)
      end
    end

    # Dominant annihilation wave (kept as requested).
    if shockwave_asset
      8.times do |i|
        t = 44 + i
        ring = addNewSprite(fx_x, fx_y, shockwave_asset, PictureOrigin::CENTER)
        apply_sheet_frame(ring, shockwave_asset, :burst)
        ring.setZ(0, 744)
        ring.setVisible(0, false)
        ring.setOpacity(0, 0)
        ring.setZoom(0, 8 + (i * 3))
        ring.setTone(0, Tone.new(-70, -70, -70, 0))
        ring.setVisible(t, true)
        ring.moveOpacity(t, 1, 255)
        ring.moveZoom(t, 7, 500 + (i * 110))
        ring.moveTone(t + 2, 4, Tone.new(-165, -165, -165, 0))
        ring.moveOpacity(t + 2, 6, 0)
        ring.setVisible(t + 9, false)
      end
    end

    attacker.moveColor(44, 2, Color.new(255, 255, 255, 255))
    attacker.moveColor(46, 4, Color.new(255, 255, 255, 0))
    attacker.moveDelta(45, 1, 6, 0)
    attacker.moveDelta(46, 1, -8, 0)
    attacker.moveDelta(47, 1, 6, 0)

    # Cegador final (pure overwhelming energy signature).
    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_WHITE)
      white = addNewSprite(0, 0, VermeilBattleAnimations::EXPLOSION_BG_WHITE)
      white.setZ(0, 761)
      white.setOpacity(0, 0)
      white.moveOpacity(43, 1, 255)
      white.setOpacity(44, 255)
      white.setOpacity(45, 255)
      white.moveOpacity(46, 1, 180)
      white.moveOpacity(47, 2, 0)
    end
  end
end

class Battle::Scene
  def vermeil_white_overlay_in(frames = 6)
    overlay = Sprite.new(@viewport)
    overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    overlay.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(255, 255, 255, 255))
    overlay.z = 999
    overlay.opacity = 0
    frames = 1 if frames < 1
    frames.times do |i|
      overlay.opacity = (((i + 1) * 255) / frames.to_f).round
      pbUpdate
    end
    return overlay
  end

  def vermeil_white_overlay_out(overlay, frames = 16)
    return if !overlay
    frames = 1 if frames < 1
    frames.times do |i|
      overlay.opacity = (255 - (((i + 1) * 255) / frames.to_f)).round
      pbUpdate
    end
  end

  def vermeil_play_cinematic_explosion_variant(user, anim_class, in_frames: 6, hold_frames: 12, out_frames: 16)
    return if !user
    ui_state = vermeil_capture_ui_visibility
    message_ui_state = respond_to?(:vermeil_capture_message_visibility) ? vermeil_capture_message_visibility : nil
    white_overlay = nil
    user_sprite = @sprites["pokemon_#{user.index}"]
    old_vis = user_sprite&.visible
    old_x = user_sprite&.x
    old_y = user_sprite&.y
    begin
      pbSaveShadows do
        pre_black = nil
        if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_BLACK)
          pre_black = IconSprite.new(0, 0, @viewport)
          pre_black.setBitmap(VermeilBattleAnimations::EXPLOSION_BG_BLACK)
          pre_black.z = 780
          pre_black.opacity = 0
          14.times do |i|
            pre_black.opacity = ((i + 1) * 255 / 14.0).round
            pbUpdate
          end
          14.times { pbUpdate }
        end
        pbToggleDataboxes if respond_to?(:pbToggleDataboxes)
        vermeil_hide_ui_for_cinematic
        user_sprite.visible = false if user_sprite
        @sprites.each do |key, sprite|
          next if !sprite || !sprite.respond_to?(:visible=)
          k = key.to_s
          next if !k.start_with?("pokemon_") && !k.start_with?("shadow_")
          next if k == "pokemon_#{user.index}" || k == "shadow_#{user.index}"
          sprite.visible = false
        end
        custom_anim = anim_class.new(@sprites, @viewport, user, true)
        6.times do
          custom_anim.update
          pbUpdate
        end
        if pre_black
          14.times do |i|
            pre_black.opacity = (255 - (((i + 1) * 255) / 14.0)).round
            custom_anim.update
            pbUpdate
          end
          pre_black.dispose
        end
        loop do
          custom_anim.update
          pbUpdate
          break if custom_anim.animDone?
        end
        white_overlay = vermeil_white_overlay_in(in_frames)
        custom_anim.dispose
      end
    ensure
      if user_sprite
        user_sprite.visible = old_vis unless old_vis.nil?
        if !old_x.nil? && !old_y.nil?
          user_sprite.x = old_x
          user_sprite.y = old_y
          user_sprite.pbSetOrigin if user_sprite.respond_to?(:pbSetOrigin)
        end
      end
      vermeil_restore_ui_visibility(ui_state)
      pbRefresh if respond_to?(:pbRefresh)
      pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes)
      @sprites.each do |key, sprite|
        next if !sprite || !sprite.respond_to?(:visible=)
        k = key.to_s.downcase
        next if !k.start_with?("databox")
        sprite.visible = true
      end
      if respond_to?(:vermeil_set_message_visibility)
        vermeil_set_message_visibility(false)
      end
      vermeil_sync_shadows_after_cinematic
      if respond_to?(:vermeil_wait_for_hp_animations)
        vermeil_wait_for_hp_animations(210)
      else
        20.times { pbUpdate }
      end
      8.times { pbUpdate }
      vermeil_sync_shadows_after_cinematic
      vermeil_white_overlay_hold(white_overlay, hold_frames)
      vermeil_white_overlay_out(white_overlay, out_frames)
      vermeil_dispose_overlay(white_overlay)
      if respond_to?(:vermeil_set_message_visibility)
        if message_ui_state
          vermeil_set_message_visibility(message_ui_state)
        else
          vermeil_set_message_visibility(true)
        end
      end
    end
  end

  def pbPlayCinematicSelfdestructAnimation(user, targets)
    vermeil_play_cinematic_explosion_variant(
      user,
      Animation::VermeilCinematicSelfdestruct,
      in_frames: 3,
      hold_frames: 22,
      out_frames: 10
    )
  end
end

class Battle
  alias_method :vermeil_selfdestruct_cinematic_pbAnimation, :pbAnimation unless method_defined?(:vermeil_selfdestruct_cinematic_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && move_id == :SELFDESTRUCT && @scene.respond_to?(:pbPlayCinematicSelfdestructAnimation)
      @scene.pbPlayCinematicSelfdestructAnimation(user, targets)
      return
    end
    vermeil_selfdestruct_cinematic_pbAnimation(move, user, targets, hitNum)
  end
end
