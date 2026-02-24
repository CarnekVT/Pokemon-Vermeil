#===============================================================================
# [VERMEIL] BattleAnimations - Sticky Web Cast (Pure Visual)
#===============================================================================

module VermeilBattleAnimations
  module_function
  STICKY_WEB_ASSETS = ["Graphics/UI/Battle/hazards/sticky_web", "Graphics/Animations/PRAS- Sticky Web"]
  STICKY_WEB_SE_THROW = "Anim/PRSFX- String Shot1"
  STICKY_WEB_SE_LAND  = "Anim/PRSFX- Spider Web2"
end

class Battle::Scene::Animation::VermeilStickyWebCast < Battle::Scene::Animation
  def initialize(sprites, viewport, user, anchor_x, anchor_y, side_index)
    @user, @anchor_x, @anchor_y, @side_index = user, anchor_x, anchor_y, side_index
    super(sprites, viewport)
  end

  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    web_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::STICKY_WEB_ASSETS)
    return if !web_asset

    @vermeil_effect_pics = []
    user_pic = addSprite(user_sprite, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    t_scale = (@side_index == 0) ? 1.1 : 1.0

    user_pic.setSE(2, VermeilBattleAnimations::STICKY_WEB_SE_THROW, 84, 100)
    user_pic.moveDelta(0, 4, 8 * f_dir, -7)
    user_pic.moveDelta(4, 4, -8 * f_dir, 7)

    hits = [[-34, -2, 10], [30, 2, 12], [-12, 8, 14], [12, 10, 16]]
    hits.each_with_index do |(ox, oy, t), i|
      web = addNewSprite(user_sprite.x, user_sprite.y - 50, web_asset, PictureOrigin::CENTER)
      @vermeil_effect_pics << web
      web.setZ(0, 100 + i); web.setOpacity(0, 0); web.setVisible(0, false)
      web.setZoom(0, 26 + (i * 3))

      web.setVisible(t + 12, true); web.moveOpacity(t + 12, 2, 185)
      web.moveXY(t + 12, 8, (@anchor_x + (ox * t_scale)).round, @anchor_y + oy)
      web.setSE(t + 12, VermeilBattleAnimations::STICKY_WEB_SE_LAND, 84, 98) if i == 1
      web.moveOpacity(t + 24, 9, 0)
    end
  end
end