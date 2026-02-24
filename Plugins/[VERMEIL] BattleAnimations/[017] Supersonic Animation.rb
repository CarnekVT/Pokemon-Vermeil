#===============================================================================
# [VERMEIL] BattleAnimations - Supersonic (Pure Visual)
#===============================================================================

module VermeilBattleAnimations
  module_function
  SUPERSONIC_WAVES = ["Graphics/Animations/PRAS- Metal Sound.png", "Graphics/Animations/PRAS- Metal Sound"]
  SUPERSONIC_NOTES = ["Graphics/Animations/PRAS- Sound.png", "Graphics/Animations/PRAS- Sound"]
  SUPERSONIC_SE    = "Anim/PRSFX- Supersonic" 
end

class Battle::Scene::Animation::VermeilCinematicSupersonic < Battle::Scene::Animation
  T_EMISSION = 2
  T_TRAVEL   = 6
  T_IMPACT   = T_EMISSION + T_TRAVEL
  T_END      = T_IMPACT + 20

  def initialize(sprites, viewport, user, target)
    @user = user; @target = target; super(sprites, viewport)
  end

  def apply_pras_frame(sprite, absolute_frame, time = 0)
    fw = 192; fh = 192; cols = 5
    col = absolute_frame % cols; row = absolute_frame / cols
    sprite.setSrc(time, col * fw, row * fh)
    sprite.setSrcSize(time, fw, fh)
    sprite.setOrigin(time, PictureOrigin::CENTER)
  end

  def createProcesses
    return if !@user || !@target
    user_sprite = @sprites["pokemon_#{@user.index}"]
    target_sprite = @sprites["pokemon_#{@target.index}"]
    return if !user_sprite || !target_sprite

    waves_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SUPERSONIC_WAVES)
    notes_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SUPERSONIC_NOTES)
    return if !waves_asset

    user_pic = addSprite(user_sprite, PictureOrigin::BOTTOM)
    target_pic = addSprite(target_sprite, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    start_x = user_sprite.x + (16 * f_dir)
    start_y = user_sprite.y - 32
    end_x = target_sprite.x - (8 * f_dir)
    end_y = target_sprite.y - 40

    user_pic.setSE(0, VermeilBattleAnimations::SUPERSONIC_SE)
    user_pic.moveDelta(0, 4, -4 * f_dir, 0)
    user_pic.moveDelta(4, 4, 4 * f_dir, 0)

    3.times do |i|
      t = T_EMISSION + (i * 2)
      wave = addNewSprite(start_x, start_y, waves_asset, PictureOrigin::CENTER)
      wave.setZ(0, target_sprite.z + 10 + i)
      wave.setVisible(0, false)
      wave.setOpacity(0, 0)
      wave.setZoom(0, 40)
      wave.setTone(0, Tone.new(0, -50, 100, 0)) 
      
      wave.setVisible(t, true)
      wave.moveOpacity(t, 2, 200)
      wave.moveXY(t, T_TRAVEL, end_x, end_y)
      wave.moveZoom(t, T_TRAVEL, 150)
      
      5.times { |f| apply_pras_frame(wave, f, t + f) }
      wave.moveOpacity(t + 4, 3, 0)
      wave.setVisible(t + 7, false)
    end

    if notes_asset
      note_offsets = [[-16, -24], [24, -10], [-8, 20], [16, 16]]
      note_offsets.each_with_index do |ofs, i|
        t = T_IMPACT + i
        note = addNewSprite(end_x, end_y, notes_asset, PictureOrigin::CENTER)
        note.setZ(0, target_sprite.z + 20 + i)
        note.setVisible(0, false)
        note.setOpacity(0, 0)
        note.setZoom(0, 30)
        note.setTone(0, Tone.new(50, -50, 150, 0))

        note.setVisible(t, true)
        note.moveOpacity(t, 2, 255)
        note.moveDelta(t, 6, ofs[0] * f_dir, ofs[1])
        note.moveZoom(t, 6, 80)
        note.moveAngle(t, 8, (f_dir * 45) + (i * 15))
        
        5.times { |f| apply_pras_frame(note, f, t + f) }
        note.moveOpacity(t + 4, 4, 0)
        note.setVisible(t + 8, false)
      end
    end

    target_pic.moveDelta(T_IMPACT, 2, 8 * f_dir, 0)
    target_pic.moveDelta(T_IMPACT + 2, 2, -16 * f_dir, 0)
    target_pic.moveDelta(T_IMPACT + 4, 2, 16 * f_dir, 0)
    target_pic.moveDelta(T_IMPACT + 6, 2, -8 * f_dir, 0)
  end
end