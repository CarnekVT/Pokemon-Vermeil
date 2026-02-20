#===============================================================================
# [VERMEIL] BattleAnimations
# Custom hardcoded move animation: Bedrock Kick
#===============================================================================

module VermeilBattleAnimations
  module_function

  BEDROCK_KICK_IMPACT_ASSET = "Graphics/BattleParticlesAnimations/Kick"
  BEDROCK_KICK_ROCK_ASSETS = [
    "Graphics/BattleParticlesAnimations/Rock1",
    "Graphics/BattleParticlesAnimations/Rock2",
    "Graphics/BattleParticlesAnimations/Rock3",
    "Graphics/BattleParticlesAnimations/Rock4",
    "Graphics/BattleParticlesAnimations/Rock5"
  ]
  BEDROCK_KICK_SE_WINDUP = "Anim/PRSFX- Low Kick"
  BEDROCK_KICK_SE_JUMP   = "Anim/PRSFX- Jump Kick1"
  BEDROCK_KICK_SE_HIT    = "Anim/PRSFX- Hi Jump Kick2"
  BEDROCK_KICK_SE_ROCK   = "Anim/PRSFX- Rock Smash"
  BEDROCK_KICK_SE_DEBRIS = "Anim/PRSFX- Rock Throw1"

  def resolve_move_id(move)
    return move.id if move.respond_to?(:id)
    data = GameData::Move.try_get(move)
    return data.id if data
    return move
  end

  def first_existing_asset(paths)
    paths.each { |path| return path if pbResolveBitmap(path) }
    return nil
  end

  def existing_assets(paths)
    ret = []
    paths.each { |path| ret.push(path) if pbResolveBitmap(path) }
    return ret
  end
end

class Battle::Scene::Animation::BedrockKick < Battle::Scene::Animation
  ROCK_TARGET_PIXEL_SIZE = 24
  PLAYER_TARGET_SCALE_MULT = 1.22

  def initialize(sprites, viewport, user, target)
    @user   = user
    @target = target
    super(sprites, viewport)
  end

  def createProcesses
    return if !@user || !@target
    user_sprite   = @sprites["pokemon_#{@user.index}"]
    target_sprite = @sprites["pokemon_#{@target.index}"]
    return if !user_sprite || !target_sprite

    user_pic   = addSprite(user_sprite, PictureOrigin::BOTTOM)
    target_pic = addSprite(target_sprite, PictureOrigin::BOTTOM)

    # +1 means moving right, -1 means moving left.
    # "forward" always points from user toward target, so this adapts automatically
    # whether the move is used by the player side or enemy side.
    forward_dir = (@user.index & 1) == 0 ? 1 : -1
    retreat_dir = -forward_dir
    target_scale_mult = (@target.index & 1) == 0 ? PLAYER_TARGET_SCALE_MULT : 1.0
    kick_impact_x = target_sprite.x - (4 * forward_dir)
    kick_impact_y = target_sprite.y - (target_sprite.bitmap ? (target_sprite.bitmap.height / 2) : 64) - 6

    impact = nil
    impact_asset = VermeilBattleAnimations::BEDROCK_KICK_IMPACT_ASSET
    if impact_asset && pbResolveBitmap(impact_asset)
      impact = addNewSprite(kick_impact_x, kick_impact_y, impact_asset, PictureOrigin::CENTER)
      impact.setVisible(0, false)
      impact.setZoom(0, (72 * target_scale_mult).round)
      impact.setZ(0, target_sprite.z + 1)
    end

    rock_assets = VermeilBattleAnimations.existing_assets(
      VermeilBattleAnimations::BEDROCK_KICK_ROCK_ASSETS
    )
    rocks = []
    if rock_assets.length > 0
      # Spawn rocks from the same center point as the Kick graphic.
      impact_x = kick_impact_x
      impact_y = kick_impact_y
      start_offsets = [[-10, -4], [-6, -7], [-2, -3], [2, -2], [6, -5], [10, -3], [-4, 1], [4, 2]]
      8.times do |i|
        rock_asset = rock_assets[i % rock_assets.length]
        ox = start_offsets[i][0]
        oy = start_offsets[i][1]
        rock = addNewSprite(impact_x + ox, impact_y + oy, rock_asset, PictureOrigin::CENTER)
        rock_sprite = @pictureSprites.last
        rock.setVisible(0, false)
        rock.setOpacity(0, 0)
        rock_target_size = (ROCK_TARGET_PIXEL_SIZE * target_scale_mult).round
        base_zoom = rock_zoom_for_uniform_size(rock_sprite, rock_target_size)
        rock.setZoom(0, base_zoom)
        rock.setZ(0, target_sprite.z + 2 + i)
        rocks.push([rock, base_zoom])
      end
    end

    # 1) Carga y retroceso
    user_pic.moveDelta(0, 5, 14 * retreat_dir, 6)
    user_pic.setSE(1, VermeilBattleAnimations::BEDROCK_KICK_SE_WINDUP)

    # 2) Salto hacia delante (sube y luego cae con fuerza)
    user_pic.setSE(5, VermeilBattleAnimations::BEDROCK_KICK_SE_JUMP)
    user_pic.moveDelta(5, 5, 18 * forward_dir, -40)
    user_pic.moveDelta(10, 6, 24 * forward_dir, 34)

    # 3) Impacto de la patada al aterrizar
    if impact
      impact.setVisible(15, true)
      impact.setOpacity(15, 0)
      impact.moveOpacity(15, 2, 255)
      impact.moveZoom(15, 4, (92 * target_scale_mult).round)
      impact.moveOpacity(19, 4, 0)
      impact.setVisible(24, false)
    end

    target_pic.setSE(15, VermeilBattleAnimations::BEDROCK_KICK_SE_HIT)
    target_pic.setSE(16, VermeilBattleAnimations::BEDROCK_KICK_SE_ROCK)
    target_pic.setSE(18, VermeilBattleAnimations::BEDROCK_KICK_SE_DEBRIS, 90, 110)
    target_is_player_side = (@target.index & 1) == 0
    recoil_y = target_is_player_side ? 20 : -24
    if target_is_player_side
      # Push.
      target_pic.moveDelta(15, 4, 24 * forward_dir, recoil_y)
    else
      # Push.
      target_pic.moveDelta(15, 4, 24 * forward_dir, recoil_y)
    end
    # Brief side-to-side shake while still in impacted position.
    target_pic.moveDelta(19, 1, 4 * forward_dir, 0)
    target_pic.moveDelta(20, 1, -8 * forward_dir, 0)
    target_pic.moveDelta(21, 1, 8 * forward_dir, 0)
    target_pic.moveDelta(22, 1, -4 * forward_dir, 0)
    # Smooth return to default.
    target_pic.moveDelta(23, 4, -24 * forward_dir, -recoil_y)
    # Small wait, then damage animation after returning.
    2.times do |i|
      t = 29 + (i * 2)
      target_pic.setVisible(t, false)
      target_pic.setVisible(t + 1, true)
    end

    # 4) Rocas que salen desde el centro del oponente hacia afuera con fade
    if rocks.length > 0
      # 8 cardinal/intercardinal directions:
      # N, NE, E, SE, S, SW, W, NW
      spread_x = [0, 24, 34, 24, 0, -24, -34, -24]
      spread_y = [-34, -24, 0, 24, 34, 24, 0, -24]
      spin     = [220, -220, 240, -240, 200, -200, 230, -230]
      rocks.each_with_index do |entry, i|
        rock = entry[0]
        base_zoom = entry[1]
        delay = 15
        dx = spread_x[i]
        dy = spread_y[i]
        far_dx = (dx * 1.45).to_i
        far_dy = (dy * 1.45).to_i
        rock.setVisible(delay, true)
        # Burst all at once, then keep drifting away while fading.
        rock.moveOpacity(delay, 1, 235)
        rock.moveDelta(delay, 3, dx, dy)
        rock.moveDelta(delay + 3, 6, far_dx, far_dy)
        rock.moveAngle(delay, 9, spin[i])
        rock.moveZoom(delay, 9, base_zoom + (8 * target_scale_mult).round)
        rock.moveOpacity(delay + 1, 8, 0)
        rock.setVisible(delay + 10, false)
      end
    end

    # 5) Recuperación del atacante a su posición base
    user_pic.moveDelta(16, 6, -20 * forward_dir, 2)
    user_pic.moveDelta(22, 4, -8 * forward_dir, -2)
  end

  def rock_zoom_for_uniform_size(sprite, target_size)
    return 24 if !sprite || !sprite.bitmap || sprite.bitmap.disposed?
    dim = [sprite.bitmap.width, sprite.bitmap.height].max
    return 24 if dim <= 0
    zoom = (target_size * 100.0 / dim).round
    zoom = 12 if zoom < 12
    zoom = 70 if zoom > 70
    return zoom
  end

end

class Battle::Scene
  def pbSmoothReturnSpriteTo(sprite, target_x, target_y, frames = 4)
    return if !sprite || target_x.nil? || target_y.nil?
    start_x = sprite.x.to_f
    start_y = sprite.y.to_f
    return if start_x.round == target_x && start_y.round == target_y
    frames = 1 if frames < 1
    frames.times do |i|
      t = (i + 1).to_f / frames
      sprite.x = (start_x + ((target_x - start_x) * t)).round
      sprite.y = (start_y + ((target_y - start_y) * t)).round
      sprite.pbSetOrigin if sprite.respond_to?(:pbSetOrigin)
      pbUpdate
    end
  end

  def pbPlayBedrockKickAnimation(user, targets)
    target = targets.is_a?(Array) ? targets[0] : targets
    return if !user || !target
    user_sprite = @sprites["pokemon_#{user.index}"]
    target_sprite = @sprites["pokemon_#{target.index}"]
    old_user_x = user_sprite&.x
    old_user_y = user_sprite&.y
    old_target_x = target_sprite&.x
    old_target_y = target_sprite&.y
    pbSaveShadows do
      if defined?(Settings::HIDE_DATABOXES_DURING_MOVES) &&
         Settings::HIDE_DATABOXES_DURING_MOVES &&
         respond_to?(:pbToggleDataboxes)
        pbToggleDataboxes
      end
      custom_anim = Animation::BedrockKick.new(@sprites, @viewport, user, target)
      loop do
        custom_anim.update
        pbUpdate
        break if custom_anim.animDone?
      end
      custom_anim.dispose
      if defined?(Settings::HIDE_DATABOXES_DURING_MOVES) &&
         Settings::HIDE_DATABOXES_DURING_MOVES &&
         respond_to?(:pbToggleDataboxes)
        pbToggleDataboxes(true)
      end
    end
    # Prevent cumulative sprite drift between repeated uses of this move,
    # but do it smoothly to avoid a visible snap.
    if user_sprite && !old_user_x.nil? && !old_user_y.nil?
      pbSmoothReturnSpriteTo(user_sprite, old_user_x, old_user_y, 4)
    end
    if target_sprite && !old_target_x.nil? && !old_target_y.nil?
      pbSmoothReturnSpriteTo(target_sprite, old_target_x, old_target_y, 4)
    end
  end
end

class Battle
  alias_method :vermeil_bedrockkick_pbAnimation, :pbAnimation unless method_defined?(:vermeil_bedrockkick_pbAnimation)

  def pbAnimation(move, user, targets, hitNum = 0)
    move_id = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && move_id == :BEDROCKKICK && @scene.respond_to?(:pbPlayBedrockKickAnimation)
      @scene.pbPlayBedrockKickAnimation(user, targets)
      return
    end
    vermeil_bedrockkick_pbAnimation(move, user, targets, hitNum)
  end
end
