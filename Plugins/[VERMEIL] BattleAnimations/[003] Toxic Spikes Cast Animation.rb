#===============================================================================
# [VERMEIL] BattleAnimations - Toxic Spikes Cast (Pure Visual)
#===============================================================================

module VermeilBattleAnimations
  module_function
  TOXIC_SPIKES_ASSETS = ["Graphics/UI/Battle/hazards/toxic_spikes", "Graphics/UI/Battle/hazards/toxic-spikes"]
  TOXIC_PARTICLE_ASSETS = ["Graphics/Pictures/StatusParticles/toxic", "Graphics/Pictures/StatusParticles/poison"]
  TOXIC_SPIKES_SE_THROW = "Anim/PRSFX- Toxic Spikes1"
  TOXIC_SPIKES_SE_LAND  = "Anim/PRSFX- Toxic Spikes2"

  def first_existing_asset(paths)
    paths.each { |path| return path if pbResolveBitmap(path) rescue nil }
    return nil
  end
end

class Battle::Scene::Animation::VermeilToxicSpikesCast < Battle::Scene::Animation
  def initialize(sprites, viewport, user, anchor_x, anchor_y, side_index)
    @user = user
    @anchor_x = anchor_x
    @anchor_y = anchor_y
    @side_index = side_index
    super(sprites, viewport)
  end

  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    return if !user_sprite
    
    spike_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::TOXIC_SPIKES_ASSETS)
    particle_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::TOXIC_PARTICLE_ASSETS)
    
    # Abortamos si no encuentras la imagen para evitar crasheos visuales
    return if !spike_asset

    @vermeil_effect_pics = []
    user_pic = addSprite(user_sprite, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    t_scale = (@side_index == 0) ? 1.15 : 1.0

    user_pic.setSE(2, VermeilBattleAnimations::TOXIC_SPIKES_SE_THROW, 82, 105) rescue nil
    user_pic.moveDelta(0, 5, 10 * f_dir, -8)
    user_pic.moveDelta(5, 5, -10 * f_dir, 8)

    offsets = [[-58, 8], [-36, 2], [-14, 10], [10, 1], [34, 9], [56, 4]]
    offsets.each_with_index do |(ox, oy), i|
      spike = addNewSprite(user_sprite.x, user_sprite.y - 56, spike_asset, PictureOrigin::CENTER)
      @vermeil_effect_pics << spike
      spike.setZ(0, 96 + i)
      spike.setOpacity(0, 0)
      spike.setVisible(0, false)
      spike.setZoom(0, 78 + (@side_index == 0 ? 20 : 0))

      start_t = 4 + (i * 2)
      spike.setVisible(start_t, true)
      spike.moveOpacity(start_t, 2, 255)
      spike.moveXY(start_t, 9, (@anchor_x + (ox * 0.4)).round, @anchor_y - 86)
      spike.moveXY(start_t + 9, 10, (@anchor_x + (ox * t_scale)).round, @anchor_y + oy)
      spike.moveAngle(start_t, 19, (f_dir * 540) + (i * 30))

      spike.moveDelta(start_t + 19, 2, 0, -8)
      spike.moveDelta(start_t + 21, 3, 0, 8)
      spike.setSE(start_t + 20, VermeilBattleAnimations::TOXIC_SPIKES_SE_LAND, 90, 98) if i == 2
      spike.moveOpacity(start_t + 28, 10, 0)
    end

    if particle_asset
      4.times do |i|
        p = addNewSprite(@anchor_x + ((i - 2) * 14), @anchor_y - 10, particle_asset, PictureOrigin::CENTER)
        p.setZ(0, 104 + i)
        p.setVisible(0, false)
        p.setOpacity(0, 0)
        p.setZoom(0, 56 + (i % 2) * 6)
        t = 30 + i
        p.setVisible(t, true)
        p.moveOpacity(t, 2, 150)
        p.moveDelta(t, 7, (i.even? ? -7 : 7), -18)
        p.moveOpacity(t + 3, 6, 0)
      end
    end
  end
end