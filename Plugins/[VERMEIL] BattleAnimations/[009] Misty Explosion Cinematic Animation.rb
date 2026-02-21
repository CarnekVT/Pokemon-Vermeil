#===============================================================================
# [VERMEIL] BattleAnimations
# [009] Misty Explosion Cinematic Animation
#===============================================================================

class Battle::Scene::Animation::VermeilCinematicMistyExplosion < Battle::Scene::Animation::VermeilCinematicExplosion
  MISTY_PARTICLE_ASSETS = [
    "Graphics/BattleParticlesAnimations/Energy1",
    "Graphics/BattleParticlesAnimations/Energy2",
    "Graphics/BattleParticlesAnimations/Energy3"
  ]
  MISTY_BG_PATHS = [
    "Graphics/Pictures/terrain_mist_bg",
    "Graphics/Animations/PRAS- Misty Terrain BG"
  ]
  MISTY_FOG_PATHS = [
    "Graphics/Pictures/terrain_mist"
  ]
  MISTY_SPARKLE_PATHS = [
    "Graphics/Pictures/terrain_mist",
    "Graphics/BattleParticlesAnimations/Energy1"
  ]

  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    return if !user_sprite

    center_x = Graphics.width / 2
    center_y = (Graphics.height / 2) + 56
    fx_x = center_x - 8
    fx_y = center_y - 72

    bg_path = VermeilBattleAnimations.first_existing_asset(MISTY_BG_PATHS)
    misty_bg = nil
    if bg_path
      misty_bg = addNewSprite(Graphics.width / 2, Graphics.height / 2, bg_path, PictureOrigin::CENTER)
      misty_bg.setZ(0, 500)
      misty_bg.setOpacity(0, 255)
      misty_bg.setVisible(0, true)
      misty_bg.setTone(0, Tone.new(100, -50, 50, 0))
    end

    blast_bg = nil
    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_BLAST)
      blast_bg = addNewSprite(Graphics.width / 2, Graphics.height / 2, VermeilBattleAnimations::EXPLOSION_BG_BLAST,
                              PictureOrigin::CENTER)
      blast_bg.setZ(0, 505)
      blast_bg.setOpacity(0, 0)
      blast_bg.setVisible(0, false)
      blast_bg.setTone(0, Tone.new(100, -50, 50, 0))
      blast_bg.setVisible(44, true)
      blast_bg.moveOpacity(44, 2, 235)
      blast_bg.setOpacity(62, 235)
      misty_bg.setVisible(44, false) if misty_bg
    end

    attacker = build_front_attacker_sprite(user_sprite, center_x, center_y)
    attacker.setZ(0, 690)
    attacker.setVisible(0, true)
    attacker.setZoom(0, 100)
    attacker.moveColor(18, 3, Color.new(255, 230, 255, 150))
    attacker.moveColor(21, 3, Color.new(255, 255, 255, 0))
    attacker.moveColor(26, 3, Color.new(255, 210, 255, 190))
    attacker.moveColor(29, 3, Color.new(255, 255, 255, 0))
    attacker.moveColor(34, 3, Color.new(255, 240, 255, 230))
    attacker.moveColor(37, 3, Color.new(255, 255, 255, 0))
    attacker.setSE(18, "Anim/PRSFX- Misty Terrain")
    attacker.setSE(31, "Anim/PRSFX- Aromatic Mist")
    attacker.setSE(44, "Anim/PRSFX- Dazzling Gleam")
    attacker.setSE(47, "Anim/PRSFX- Fairy Wind", 90, 110)
    attacker.moveZoom(40, 5, 112)
    attacker.moveZoom(45, 6, 100)

    charge_asset = VermeilBattleAnimations.first_existing_asset(
      VermeilBattleAnimations::EXPLOSION_CHARGE_PARTICLE_ASSETS
    )
    if charge_asset
      charge_dirs = [
        [-1.0, 0.0], [1.0, 0.0], [0.0, -1.0], [0.0, 1.0],
        [-0.7, -0.7], [0.7, -0.7], [-0.7, 0.7], [0.7, 0.7],
        [-0.35, -1.0], [0.35, -1.0], [-1.0, 0.35], [1.0, 0.35]
      ]
      charge_dirs.each_with_index do |dir, i|
        t = 14 + (i % 5) * 2
        radius = 90 + (i / 6) * 10
        p = addNewSprite(fx_x + (dir[0] * radius).round, fx_y + (dir[1] * radius).round, charge_asset, PictureOrigin::CENTER)
        apply_sheet_frame(p, charge_asset, :charge)
        p.setZ(0, 738)
        p.setVisible(0, false)
        p.setOpacity(0, 0)
        p.setZoom(0, 24)
        p.setTone(0, Tone.new(100, -50, 50, 0))
        p.setVisible(t, true)
        p.moveOpacity(t, 2, 245)
        p.moveXY(t, 12, fx_x, fx_y)
        p.moveZoom(t, 12, 62)
        p.moveOpacity(t + 7, 7, 0)
        p.setVisible(t + 13, false)
      end
    end

    # Soft, large pressure wave instead of violent shake.
    shockwave_asset = VermeilBattleAnimations.first_existing_asset(
      VermeilBattleAnimations::EXPLOSION_SHOCKWAVE_ASSETS
    )
    if shockwave_asset
      6.times do |i|
        t = 44 + i
        ring = addNewSprite(fx_x, fx_y, shockwave_asset, PictureOrigin::CENTER)
        apply_sheet_frame(ring, shockwave_asset, :burst)
        ring.setZ(0, 744)
        ring.setVisible(0, false)
        ring.setOpacity(0, 0)
        ring.setZoom(0, 14 + (i * 3))
        ring.setTone(0, Tone.new(100, -50, 50, 0))
        ring.setVisible(t, true)
        ring.moveOpacity(t, 2, 220)
        ring.moveZoom(t, 12, 420 + (i * 90))
        ring.moveOpacity(t + 3, 10, 0)
        ring.setVisible(t + 13, false)
      end
    end

    fog_asset = VermeilBattleAnimations.first_existing_asset(MISTY_PARTICLE_ASSETS + MISTY_FOG_PATHS)
    if fog_asset
      fog_offsets = [[-36, -16], [-20, 8], [0, -20], [22, 10], [38, -4], [0, 22]]
      fog_offsets.each_with_index do |ofs, i|
        t = 45 + (i % 3)
        fog = addNewSprite(fx_x + ofs[0], fx_y + ofs[1], fog_asset, PictureOrigin::CENTER)
        apply_sheet_frame(fog, fog_asset, :charge)
        fog.setZ(0, 746)
        fog.setVisible(0, false)
        fog.setOpacity(0, 0)
        fog.setZoom(0, 30 + (i % 2) * 6)
        fog.setTone(0, Tone.new(70, -20, 35, 0))
        fog.setVisible(t, true)
        fog.moveOpacity(t, 1, 255)
        fog.moveZoom(t, 12, 108 + (i % 3) * 14)
        fog.moveDelta(t, 11, ofs[0] / 2, 8)
        fog.moveOpacity(t + 4, 9, 0)
        fog.setVisible(t + 13, false)
      end
    end

    # Lingering sparkles a few frames after detonation.
    sparkle_asset = VermeilBattleAnimations.first_existing_asset(MISTY_PARTICLE_ASSETS + MISTY_SPARKLE_PATHS)
    if sparkle_asset
      sparkle_offsets = [[0, -34], [20, -18], [30, 4], [16, 24], [-16, 24], [-30, 4], [-20, -18]]
      sparkle_offsets.each_with_index do |ofs, i|
        t = 48 + (i % 4)
        s = addNewSprite(fx_x + ofs[0], fx_y + ofs[1], sparkle_asset, PictureOrigin::CENTER)
        apply_sheet_frame(s, sparkle_asset, :burst)
        s.setZ(0, 748)
        s.setVisible(0, false)
        s.setOpacity(0, 0)
        s.setZoom(0, 14 + (i % 2) * 3)
        s.setTone(0, Tone.new(110, -40, 60, 0))
        s.setVisible(t, true)
        s.moveOpacity(t, 1, 210)
        s.moveZoom(t, 8, 30 + (i % 3) * 4)
        s.moveOpacity(t + 3, 8, 0)
        s.setVisible(t + 12, false)
      end
    end

    if pbResolveBitmap(VermeilBattleAnimations::EXPLOSION_BG_WHITE)
      white = addNewSprite(0, 0, VermeilBattleAnimations::EXPLOSION_BG_WHITE)
      white.setZ(0, 760)
      white.setOpacity(0, 0)
      white.moveOpacity(43, 2, 220)
      white.moveOpacity(45, 2, 0)
    end
  end
end

class Battle::Scene
  def pbPlayCinematicMistyExplosionAnimation(user, targets)
    if respond_to?(:vermeil_play_cinematic_explosion_variant)
      vermeil_play_cinematic_explosion_variant(
        user,
        Animation::VermeilCinematicMistyExplosion,
        in_frames: 4,
        hold_frames: 14,
        out_frames: 14
      )
    else
      pbPlayCinematicExplosionAnimation(user, targets)
    end
  end
end

class Battle
  alias_method :vermeil_misty_explosion_cinematic_pbAnimation, :pbAnimation unless method_defined?(:vermeil_misty_explosion_cinematic_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && move_id == :MISTYEXPLOSION && @scene.respond_to?(:pbPlayCinematicMistyExplosionAnimation)
      @scene.pbPlayCinematicMistyExplosionAnimation(user, targets)
      return
    end
    vermeil_misty_explosion_cinematic_pbAnimation(move, user, targets, hitNum)
  end
end
