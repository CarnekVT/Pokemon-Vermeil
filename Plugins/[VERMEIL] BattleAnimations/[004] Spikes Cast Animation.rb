#===============================================================================
# [VERMEIL] BattleAnimations - Spikes Cast (Pure Visual)
#===============================================================================

module VermeilBattleAnimations
  module_function
  SPIKES_ASSETS = ["Graphics/UI/Battle/hazards/spikes", "Graphics/UI/Battle/hazards/spike"]
  SPIKES_SE_THROW = "Anim/PRSFX- Low Kick"
  SPIKES_SE_LAND  = "Anim/PRSFX- Spikes2"
end

class Battle::Scene::Animation::VermeilSpikesCast < Battle::Scene::Animation
  def initialize(sprites, viewport, user, anchor_x, anchor_y, side_index)
    @user, @anchor_x, @anchor_y, @side_index = user, anchor_x, anchor_y, side_index
    super(sprites, viewport)
  end

  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    spike_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::SPIKES_ASSETS)
    return if !spike_asset

    @vermeil_effect_pics = []
    user_pic = addSprite(user_sprite, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    t_scale = (@side_index == 0) ? 1.12 : 1.0

    user_pic.setSE(2, VermeilBattleAnimations::SPIKES_SE_THROW, 80, 100)
    user_pic.moveDelta(0, 5, 10 * f_dir, -8)
    user_pic.moveDelta(5, 5, -10 * f_dir, 8)

    offsets = [[-52, 8], [-30, 4], [-8, 10], [16, 5], [38, 9]]
    offsets.each_with_index do |(ox, oy), i|
      spike = addNewSprite(user_sprite.x, user_sprite.y - 56, spike_asset, PictureOrigin::CENTER)
      @vermeil_effect_pics << spike
      spike.setZ(0, 96 + i); spike.setOpacity(0, 0); spike.setVisible(0, false)
      spike.setZoom(0, 74 + (@side_index == 0 ? 16 : 0))

      start_t = 4 + (i * 2)
      spike.setVisible(start_t, true); spike.moveOpacity(start_t, 2, 255)
      spike.moveXY(start_t, 8, (@anchor_x + (ox * 0.45)).round, @anchor_y - 76)
      spike.moveXY(start_t + 8, 9, (@anchor_x + (ox * t_scale)).round, @anchor_y + oy)
      spike.moveAngle(start_t, 17, (f_dir * 500) + (i * 28))
      spike.moveDelta(start_t + 17, 2, 0, -6)
      spike.moveDelta(start_t + 19, 3, 0, 6)
      spike.setSE(start_t + 18, VermeilBattleAnimations::SPIKES_SE_LAND, 88, 98) if i == 2
      spike.moveOpacity(start_t + 26, 10, 0)
    end
  end
end