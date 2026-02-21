#===============================================================================
# [VERMEIL] BattleAnimations
# [008] Voltburst Cinematic Animation
#===============================================================================

class Battle::Scene::Animation::VermeilCinematicVoltburst < Battle::Scene::Animation::VermeilCinematicExplosion
  VOLTBURST_BG_PICTURE = "Graphics/Pictures/terrain_electric_bg"
  VOLTBURST_ENERGY_ASSETS = [
    "Graphics/BattleParticlesAnimations/Energy1",
    "Graphics/BattleParticlesAnimations/Energy2",
    "Graphics/BattleParticlesAnimations/Energy3"
  ]
  VOLTBURST_VOLT_ASSET = "Graphics/BattleParticlesAnimations/Volt"

  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    return if !user_sprite

    center_x = Graphics.width / 2
    center_y = (Graphics.height / 2) + 56
    fx_x = (Graphics.width / 2) - 8
    fx_y = (Graphics.height / 2) - 16

    attacker = build_front_attacker_sprite(user_sprite, center_x, center_y)
    attacker.setZ(0, 690)
    attacker.setVisible(0, true)
    attacker.setZoom(0, 100)
    attacker.moveColor(18, 2, Color.new(170, 220, 255, 180))
    attacker.moveColor(20, 2, Color.new(255, 255, 255, 0))
    attacker.moveColor(24, 2, Color.new(200, 240, 255, 210))
    attacker.moveColor(26, 2, Color.new(255, 255, 255, 0))
    attacker.moveZoom(38, 3, 92)
    attacker.moveZoom(41, 2, 128)
    attacker.moveZoom(43, 2, 96)
    attacker.moveDelta(40, 1, -12, 0)
    attacker.moveDelta(41, 1, 18, 0)
    attacker.moveDelta(42, 1, -20, 0)
    attacker.moveDelta(43, 1, 16, 0)
    attacker.moveDelta(44, 1, -10, 0)
    attacker.setSE(20, "Anim/PRSFX- Charge")
    attacker.setSE(31, "Anim/PRSFX- Thunderbolt1")
    attacker.setSE(44, "Anim/PRSFX- Discharge")
    attacker.setSE(46, "Anim/PRSFX- Zap Cannon2")
    attacker.setSE(48, "Anim/PRSFX- Thunder")

    base_bg = nil
    if pbResolveBitmap(VOLTBURST_BG_PICTURE)
      base_bg = addNewSprite(Graphics.width / 2, Graphics.height / 2, VOLTBURST_BG_PICTURE, PictureOrigin::CENTER)
      base_bg.setZ(0, 504)
      base_bg.setOpacity(0, 255)
      base_bg.setVisible(0, true)
    end

    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_BLAST)
      blast_bg = addNewSprite(Graphics.width / 2, Graphics.height / 2, VermeilBattleAnimations::EXPLOSION_BG_BLAST,
                              PictureOrigin::CENTER)
      blast_bg.setZ(0, 505)
      blast_bg.setOpacity(0, 0)
      blast_bg.setVisible(0, false)
      blast_bg.setVisible(44, true)
      blast_bg.setOpacity(44, 220)
      blast_bg.setOpacity(46, 255)
      blast_bg.setOpacity(70, 255)
      blast_bg.moveDelta(44, 1, 14, 0)
      blast_bg.moveDelta(45, 1, -20, 0)
      blast_bg.moveDelta(46, 1, 16, 0)
      blast_bg.moveDelta(47, 1, -12, 0)
      blast_bg.moveDelta(48, 1, 8, 0)
      blast_bg.moveDelta(49, 1, -6, 0)
      blast_bg.moveOpacity(72, 5, 0)
      blast_bg.setVisible(78, false)
      base_bg.setVisible(44, false) if base_bg
    end

    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_WHITE)
      flash = addNewSprite(0, 0, VermeilBattleAnimations::EXPLOSION_BG_WHITE)
      flash.setZ(0, 760)
      flash.setOpacity(0, 0)
      flash.moveOpacity(43, 1, 220)
      flash.moveOpacity(44, 1, 0)
      flash.moveOpacity(46, 1, 255)
      flash.moveOpacity(47, 2, 0)
    end

    # New custom particle pack: Energy1/2/3 charging around the user.
    VOLTBURST_ENERGY_ASSETS.each_with_index do |asset, a|
      next if !pbResolveBitmap(asset)
      dirs = [
        [0.0, -1.0], [0.85, -0.55], [0.85, 0.55],
        [0.0, 1.0], [-0.85, 0.55], [-0.85, -0.55]
      ]
      dirs.each_with_index do |dir, i|
        t = 14 + a + (i % 3) * 3
        radius = 52 + (a * 8)
        p = addNewSprite(fx_x + (dir[0] * radius).round, fx_y + (dir[1] * radius).round, asset, PictureOrigin::CENTER)
        apply_sheet_frame(p, asset, :charge)
        p.setZ(0, 742 + a)
        p.setVisible(0, false)
        p.setOpacity(0, 0)
        p.setZoom(0, 14 + (a * 2))
        p.setTone(0, Tone.new(-220, -120, 220, 0))
        p.setVisible(t, true)
        p.moveOpacity(t, 2, 210)
        p.moveXY(t, 11, fx_x, fx_y)
        p.moveZoom(t, 11, 34 + (a * 4))
        p.moveOpacity(t + 7, 5, 0)
        p.setVisible(t + 13, false)
      end
    end

    # Volt.png (96x92 per frame): local electric bursts around body.
    if pbResolveBitmap(VOLTBURST_VOLT_ASSET)
      volt_origin_x = fx_x + 144
      volt_offsets = [[0, -28], [24, -6], [18, 22], [-18, 22], [-24, -6]]
      volt_offsets.each_with_index do |ofs, i|
        t = 42 + (i % 3)
        v = addNewSprite(volt_origin_x + ofs[0], fx_y + ofs[1], VOLTBURST_VOLT_ASSET, PictureOrigin::CENTER)
        apply_volt_frame(v, i)
        animate_volt_frames(v, t, 6, i * 2)
        v.setZ(0, 748)
        v.setVisible(0, false)
        v.setOpacity(0, 0)
        v.setZoom(0, 34 + (i % 2) * 6)
        v.setTone(0, Tone.new(-255, -120, 200, 0))
        v.setVisible(t, true)
        v.moveOpacity(t, 1, 255)
        v.moveOpacity(t + 2, 1, 120)
        v.moveOpacity(t + 3, 1, 255)
        v.moveOpacity(t + 4, 2, 0)
        v.moveDelta(t, 5, (ofs[0] / 3), (ofs[1] / 3))
        v.setVisible(t + 7, false)
      end
    end

    shockwave_asset = VermeilBattleAnimations.first_existing_asset(
      VermeilBattleAnimations::EXPLOSION_SHOCKWAVE_ASSETS
    )
    if shockwave_asset
      8.times do |i|
        t = 44 + i
        ring = addNewSprite(fx_x, fx_y, shockwave_asset, PictureOrigin::CENTER)
        apply_sheet_frame(ring, shockwave_asset, :burst)
        ring.setZ(0, 745)
        ring.setVisible(0, false)
        ring.setOpacity(0, 0)
        ring.setZoom(0, 8 + (i * 3))
        ring.setTone(0, Tone.new(0, 0, -255, 0))
        ring.setVisible(t, true)
        ring.moveOpacity(t, 1, 255)
        ring.moveZoom(t, 5, 470 + (i * 155))
        ring.moveTone(t + 2, 3, Tone.new(-220, -120, 30, 0))
        ring.moveOpacity(t + 2, 5, 0)
        ring.setVisible(t + 8, false)
      end
    end

    attacker.moveColor(44, 2, Color.new(255, 255, 255, 255))
    attacker.moveColor(46, 4, Color.new(255, 255, 255, 0))
    attacker.moveDelta(45, 1, 10, 0)
    attacker.moveDelta(46, 1, -16, 0)
    attacker.moveDelta(47, 1, 12, 0)
  end

  def volt_sheet_layout
    info = VermeilBattleAnimations.sheet_frame_info(VOLTBURST_VOLT_ASSET)
    return nil if !info
    if info[:width] % 96 == 0 && info[:height] % 92 == 0
      cols = info[:width] / 96
      rows = info[:height] / 92
      return [info[:width], info[:height], cols, rows, 96, 92]
    end
    return [info[:width], info[:height], info[:cols], info[:rows], info[:frame_w], info[:frame_h]]
  end

  def volt_frame_rect(frame_index)
    layout = volt_sheet_layout
    return [0, 0, 0, 0] if !layout
    width, height, cols, rows, fw, fh = layout
    return [0, 0, 0, 0] if cols <= 0 || rows <= 0 || fw <= 0 || fh <= 0
    count = cols * rows
    idx = frame_index % count
    col = idx % cols
    row = idx / cols
    return [col * fw, row * fh, fw, fh]
  end

  def apply_volt_frame(picture, frame_index = 0)
    return if !picture
    sx, sy, sw, sh = volt_frame_rect(frame_index)
    if sw <= 0 || sh <= 0
      apply_sheet_frame(picture, VOLTBURST_VOLT_ASSET, :burst)
      return
    end
    picture.setSrc(0, sx, sy)
    picture.setSrcSize(0, sw, sh)
    picture.setOrigin(0, PictureOrigin::CENTER)
  end

  def animate_volt_frames(picture, start_t, duration, start_index = 0)
    return if !picture
    duration.times do |j|
      sx, sy, sw, sh = volt_frame_rect(start_index + j)
      next if sw <= 0 || sh <= 0
      picture.setSrc(start_t + j, sx, sy)
      picture.setSrcSize(start_t + j, sw, sh)
    end
  end
end

class Battle::Scene
  def pbPlayCinematicVoltburstAnimation(user, targets)
    if respond_to?(:vermeil_play_cinematic_explosion_variant)
      vermeil_play_cinematic_explosion_variant(
        user,
        Animation::VermeilCinematicVoltburst,
        in_frames: 5,
        hold_frames: 9,
        out_frames: 14
      )
    else
      pbPlayCinematicExplosionAnimation(user, targets)
    end
  end
end

class Battle
  alias_method :vermeil_voltburst_cinematic_pbAnimation, :pbAnimation unless method_defined?(:vermeil_voltburst_cinematic_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && move_id == :VOLTBURST && @scene.respond_to?(:pbPlayCinematicVoltburstAnimation)
      @scene.pbPlayCinematicVoltburstAnimation(user, targets)
      return
    end
    vermeil_voltburst_cinematic_pbAnimation(move, user, targets, hitNum)
  end
end
