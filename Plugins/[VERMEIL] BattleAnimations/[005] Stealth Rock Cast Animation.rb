#===============================================================================
# [VERMEIL] BattleAnimations - Stealth Rock Cast (Pure Visual)
#===============================================================================

module VermeilBattleAnimations
  module_function
  STEALTH_ROCK_ASSETS = ["Graphics/UI/Battle/hazards/stealth_rock", "Graphics/UI/Battle/hazards/stealth-rock"]
  STEALTH_ROCK_SE_THROW = "Anim/PRSFX- Rock Throw1"
  STEALTH_ROCK_SE_LAND  = "Anim/PRSFX- Rock Smash"
end

class Battle::Scene::Animation::VermeilStealthRockCast < Battle::Scene::Animation
  def initialize(sprites, viewport, user, anchor_x, anchor_y, side_index)
    @user, @anchor_x, @anchor_y, @side_index = user, anchor_x, anchor_y, side_index
    super(sprites, viewport)
  end

  def createProcesses
    return if !@user
    user_sprite = @sprites["pokemon_#{@user.index}"]
    rock_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::STEALTH_ROCK_ASSETS)
    return if !rock_asset

    @vermeil_effect_pics = []
    user_pic = addSprite(user_sprite, PictureOrigin::BOTTOM)
    f_dir = (@user.index & 1) == 0 ? 1 : -1
    t_scale = (@side_index == 0) ? 1.08 : 1.0

    user_pic.setSE(2, VermeilBattleAnimations::STEALTH_ROCK_SE_THROW, 85, 102)
    user_pic.moveDelta(0, 5, 8 * f_dir, -7)
    user_pic.moveDelta(5, 5, -8 * f_dir, 7)

    offsets = [[-44, -6], [-26, 8], [-6, -10], [16, 6], [34, -4], [52, 10]]
    offsets.each_with_index do |(ox, oy), i|
      rock = addNewSprite(user_sprite.x, user_sprite.y - 54, rock_asset, PictureOrigin::CENTER)
      @vermeil_effect_pics << rock
      rock.setZ(0, 96 + i); rock.setOpacity(0, 0); rock.setVisible(0, false)
      rock.setZoom(0, 70 + ((i % 3) * 5))

      start_t = 4 + i
      rock.setVisible(start_t, true); rock.moveOpacity(start_t, 2, 255)
      rock.moveXY(start_t, 9, (@anchor_x + (ox * 0.55)).round, @anchor_y - 94)
      rock.moveXY(start_t + 9, 10, (@anchor_x + (ox * t_scale)).round, @anchor_y + oy)
      rock.moveAngle(start_t, 19, (f_dir * 580) + (i * 35))
      rock.moveDelta(start_t + 19, 2, 0, -5)
      rock.moveDelta(start_t + 21, 3, 0, 5)
      rock.setSE(start_t + 20, VermeilBattleAnimations::STEALTH_ROCK_SE_LAND, 92, 100) if i == 2
      rock.moveOpacity(start_t + 30, 10, 0)
    end
  end
end