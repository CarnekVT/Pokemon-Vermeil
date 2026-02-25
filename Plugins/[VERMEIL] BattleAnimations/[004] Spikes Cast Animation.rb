#===============================================================================
# [VERMEIL] BattleAnimations - Spikes Cast Rework (HAZARD)
#===============================================================================

module VermeilSpikesAssets
  SPIKES_ASSET = "Graphics/UI/Battle/hazards/spikes"
end

class Battle::Scene::Animation::VermeilSpikesCast < Battle::Scene::Animation
  include VermeilSpikesAssets
  
  HANDLED_MOVES = [:SPIKES]
  BEHAVIOR = :hazard

  def initialize(sprites, viewport, user, anchor_x, anchor_y, side_index)
    @user = user
    @anchor_x = anchor_x
    @anchor_y = anchor_y
    @side_index = side_index
    super(sprites, viewport)
  end

  def resolve_bitmap(path, fallback)
    return pbResolveBitmap(path) ? path : fallback
  end

  def createProcesses
    us = @sprites["pokemon_#{@user.index}"]
    return if !us
    
    user_pic = addSprite(us, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    t_scale = (@side_index == 0) ? 1.12 : 1.0

    spike_asset = resolve_bitmap(SPIKES_ASSET, "Graphics/UI/Battle/hazards/spike")
    
    user_pic.setSE(2, "Anim/PRSFX- Low Kick", 80, 100)
    user_pic.moveDelta(0, 5, 10 * f_dir, -8)
    user_pic.moveDelta(5, 5, -10 * f_dir, 8)

    @end_frame = 35

    offsets = [[-52, 8], [-30, 4], [-8, 10], [16, 5], [38, 9]]
    offsets.each_with_index do |(ox, oy), i|
      spike = addNewSprite(us.x, us.y - 56, spike_asset, PictureOrigin::CENTER)
      spike.setZ(0, 96 + i)
      spike.setOpacity(0, 0)
      spike.setVisible(0, false)
      spike.setZoom(0, 74 + (@side_index == 0 ? 16 : 0))

      start_t = 4 + (i * 2)
      spike.setVisible(start_t, true)
      spike.moveOpacity(start_t, 2, 255)
      spike.moveXY(start_t, 8, (@anchor_x + (ox * 0.45)).round, @anchor_y - 76)
      spike.moveXY(start_t + 8, 9, (@anchor_x + (ox * t_scale)).round, @anchor_y + oy)
      spike.moveAngle(start_t, 17, (f_dir * 500) + (i * 28))
      spike.moveDelta(start_t + 17, 2, 0, -6)
      spike.moveDelta(start_t + 19, 3, 0, 6)
      spike.setSE(start_t + 18, "Anim/PRSFX- Spikes2", 88, 98) if i == 2
      spike.moveOpacity(start_t + 22, 6, 0)
    end
  end
end