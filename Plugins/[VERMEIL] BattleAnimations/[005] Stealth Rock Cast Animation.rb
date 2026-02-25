#===============================================================================
# [VERMEIL] BattleAnimations - Stealth Rock Cast Rework (HAZARD)
#===============================================================================

module VermeilStealthRockAssets
  ROCK_ASSET = "Graphics/UI/Battle/hazards/stealth_rock"
end

class Battle::Scene::Animation::VermeilStealthRockCast < Battle::Scene::Animation
  include VermeilStealthRockAssets
  
  HANDLED_MOVES = [:STEALTHROCK]
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
    t_scale = (@side_index == 0) ? 1.08 : 1.0

    rock_asset = resolve_bitmap(ROCK_ASSET, "Graphics/UI/Battle/hazards/stealth-rock")
    
    user_pic.setSE(2, "Anim/PRSFX- Rock Throw1", 85, 102)
    user_pic.moveDelta(0, 5, 8 * f_dir, -7)
    user_pic.moveDelta(5, 5, -8 * f_dir, 7)

    @end_frame = 38

    offsets = [[-44, -6], [-26, 8], [-6, -10], [16, 6], [34, -4], [52, 10]]
    offsets.each_with_index do |(ox, oy), i|
      rock = addNewSprite(us.x, us.y - 54, rock_asset, PictureOrigin::CENTER)
      rock.setZ(0, 96 + i)
      rock.setOpacity(0, 0)
      rock.setVisible(0, false)
      rock.setZoom(0, 70 + ((i % 3) * 5))

      start_t = 4 + i
      rock.setVisible(start_t, true)
      rock.moveOpacity(start_t, 2, 255)
      rock.moveXY(start_t, 9, (@anchor_x + (ox * 0.55)).round, @anchor_y - 94)
      rock.moveXY(start_t + 9, 10, (@anchor_x + (ox * t_scale)).round, @anchor_y + oy)
      rock.moveAngle(start_t, 19, (f_dir * 580) + (i * 35))
      rock.moveDelta(start_t + 19, 2, 0, -5)
      rock.moveDelta(start_t + 21, 3, 0, 5)
      rock.setSE(start_t + 20, "Anim/PRSFX- Rock Smash", 92, 100) if i == 2
      rock.moveOpacity(start_t + 25, 6, 0)
    end
  end
end