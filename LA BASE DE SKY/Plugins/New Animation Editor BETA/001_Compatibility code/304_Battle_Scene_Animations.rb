#===============================================================================
#
#===============================================================================
class Battle::Scene::Animation::Intro < Battle::Scene::Animation
  def createProcesses
    appearTime = 20   # This is in 1/20 seconds
    # Background
    if @sprites["battle_bg2"]
      makeSlideSprite("battle_bg", 0.5, appearTime)
      makeSlideSprite("battle_bg2", 0.5, appearTime)
    end
    # Bases
    makeSlideSprite("base_0", 1, appearTime, PictureOrigin::BOTTOM)
    makeSlideSprite("base_1", -1, appearTime, PictureOrigin::CENTER)
    # Player sprite, partner trainer sprite
    @battle.player.each_with_index do |_p, i|
      makeSlideSprite("player_#{i + 1}", 1, appearTime, PictureOrigin::BOTTOM)
    end
    # Opposing trainer sprite(s) or wild Pokémon sprite(s)
    if @battle.trainerBattle?
      @battle.opponent.each_with_index do |_p, i|
        makeSlideSprite("trainer_#{i + 1}", -1, appearTime, PictureOrigin::BOTTOM)
      end
    else   # Wild battle
      @battle.pbParty(1).each_with_index do |_pkmn, i|
        idxBattler = (2 * i) + 1
        makeSlideSprite("pokemon_#{idxBattler}", -1, appearTime, nil)
      end
    end
    # Shadows
    @battle.battlers.length.times do |i|
      makeSlideSprite("shadow_#{i}", (i.even?) ? 1 : -1, appearTime, PictureOrigin::CENTER)
    end
    # Fading blackness over whole screen
    blackScreen = addNewSprite(0, 0, "Graphics/Battle animations/Screens/black")
    blackScreen.setZ(0, 99999)
    blackScreen.moveOpacity(0, 8, 0)
    # Fading blackness over command bar
    blackBar = addNewSprite(@sprites["cmdBar_bg"].x, @sprites["cmdBar_bg"].y,
                            "Graphics/Battle animations/Screens/black_bar")
    blackBar.setZ(0, 99998)
    blackBar.moveOpacity(appearTime * 3 / 4, appearTime / 4, 0)
  end
end

#===============================================================================
#
#===============================================================================
class Battle::Scene::Animation::Intro2 < Battle::Scene::Animation
  def createProcesses
    @sideSize.times do |i|
      idxBattler = (2 * i) + 1
      next if !@sprites["pokemon_#{idxBattler}"]
      battler = addSprite(@sprites["pokemon_#{idxBattler}"], nil)
      battler.moveTone(0, 4, Tone.new(0, 0, 0, 0))
      battler.setCallback(10 * i, [@sprites["pokemon_#{idxBattler}"], :pbPlayIntroAnimation])
    end
  end
end

#===============================================================================
#
#===============================================================================
class Battle::Scene::Animation::PokeballPlayerSendOut < Battle::Scene::Animation
  def createProcesses
    batSprite = @sprites["pokemon_#{@battler.index}"]
    shaSprite = @sprites["shadow_#{@battler.index}"]
    traSprite = @sprites["player_#{@idxTrainer}"]
    # Calculate the Poké Ball graphic to use
    poke_ball = (batSprite.pkmn) ? batSprite.pkmn.poke_ball : nil
    # Calculate the color to turn the battler sprite
    col = getBattlerColorFromPokeBall(poke_ball)
    col.alpha = 255
    # Calculate start and end coordinates for battler sprite movement
    ballPos = Battle::Scene.pbBattlerPosition(@battler.index, batSprite.sideSize)
    battlerStartX = ballPos[0]   # Is also where the Ball needs to end
    battlerStartY = ballPos[1]   # Is also where the Ball needs to end + 18
    battlerEndX = batSprite.x
    battlerEndY = batSprite.y
    # Calculate start and end coordinates for Poké Ball sprite movement
    ballStartX = -6
    ballStartY = 202
    ballMidX = 0   # Unused in trajectory calculation
    ballMidY = battlerStartY - 144
    # Set up Poké Ball sprite
    ball = addBallSprite(ballStartX, ballStartY, poke_ball)
    ball.setZ(0, 1025)
    ball.setVisible(0, false)
    # Poké Ball tracking the player's hand animation (if trainer is visible)
    if @showingTrainer && traSprite && traSprite.x > 0
      ball.setZ(0, traSprite.z - 1)
      ballStartX, ballStartY = ballTracksHand(ball, traSprite)
    end
    delay = ball.totalDuration   # 0 or 7
    # Poké Ball trajectory animation
    createBallTrajectory(ball, delay, 12,
                         ballStartX, ballStartY, ballMidX, ballMidY, battlerStartX, battlerStartY - 18)
    ball.setZ(9, batSprite.z - 1)
    delay = ball.totalDuration + 4
    delay += 10 * @idxOrder   # Stagger appearances if multiple Pokémon are sent out at once
    ballOpenUp(ball, delay - 2, poke_ball)
    ballBurst(delay, ball, battlerStartX, battlerStartY - 18, poke_ball)
    ball.moveOpacity(delay + 2, 2, 0)
    # Set up battler sprite
    battler = addSprite(batSprite, nil)
    battler.setXY(0, battlerStartX, battlerStartY)
    battler.setZoom(0, 0)
    battler.setColor(0, col)
    # Battler animation
    battlerAppear(battler, delay, battlerEndX, battlerEndY, batSprite, col)
    if @shadowVisible
      # Set up shadow sprite
      shadow = addSprite(shaSprite, PictureOrigin::CENTER)
      shadow.setOpacity(0, 0)
      # Shadow animation
      shadow.setVisible(delay, @shadowVisible)
      shadow.moveOpacity(delay + 5, 10, 255)
    end
  end
end

#===============================================================================
#
#===============================================================================
class Battle::Scene::Animation::PokeballTrainerSendOut < Battle::Scene::Animation
  def createProcesses
    batSprite = @sprites["pokemon_#{@battler.index}"]
    shaSprite = @sprites["shadow_#{@battler.index}"]
    # Calculate the Poké Ball graphic to use
    poke_ball = (batSprite.pkmn) ? batSprite.pkmn.poke_ball : nil
    # Calculate the color to turn the battler sprite
    col = getBattlerColorFromPokeBall(poke_ball)
    col.alpha = 255
    # Calculate start and end coordinates for battler sprite movement
    ballPos = Battle::Scene.pbBattlerPosition(@battler.index, batSprite.sideSize)
    battlerStartX = ballPos[0]
    battlerStartY = ballPos[1]
    battlerEndX = batSprite.x
    battlerEndY = batSprite.y
    # Set up Poké Ball sprite
    ball = addBallSprite(0, 0, poke_ball)
    ball.setZ(0, batSprite.z - 1)
    # Poké Ball animation
    createBallTrajectory(ball, battlerStartX, battlerStartY)
    delay = ball.totalDuration + 6
    delay += 10 if @showingTrainer   # Give time for trainer to slide off screen
    delay += 10 * @idxOrder   # Stagger appearances if multiple Pokémon are sent out at once
    ballOpenUp(ball, delay - 2, poke_ball)
    ballBurst(delay, ball, battlerStartX, battlerStartY - 18, poke_ball)
    ball.moveOpacity(delay + 2, 2, 0)
    # Set up battler sprite
    battler = addSprite(batSprite, nil)
    battler.setXY(0, battlerStartX, battlerStartY)
    battler.setZoom(0, 0)
    battler.setColor(0, col)
    # Battler animation
    battlerAppear(battler, delay, battlerEndX, battlerEndY, batSprite, col)
    if @shadowVisible
      # Set up shadow sprite
      shadow = addSprite(shaSprite, PictureOrigin::CENTER)
      shadow.setOpacity(0, 0)
      # Shadow animation
      shadow.setVisible(delay, @shadowVisible)
      shadow.moveOpacity(delay + 5, 10, 255)
    end
  end
end

#===============================================================================
#
#===============================================================================
class Battle::Scene::Animation::BattlerRecall < Battle::Scene::Animation
  def createProcesses
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    # Calculate the Poké Ball graphic to use
    poke_ball = (batSprite.pkmn) ? batSprite.pkmn.poke_ball : nil
    # Calculate the color to turn the battler sprite
    col = getBattlerColorFromPokeBall(poke_ball)
    col.alpha = 0
    # Calculate end coordinates for battler sprite movement
    ballPos = Battle::Scene.pbBattlerPosition(@idxBattler, batSprite.sideSize)
    battlerEndX = ballPos[0]
    battlerEndY = ballPos[1]
    # Set up battler sprite
    battler = addSprite(batSprite, nil)
    battler.setVisible(0, true)
    battler.setColor(0, col)
    # Set up Poké Ball sprite
    ball = addBallSprite(battlerEndX, battlerEndY, poke_ball)
    ball.setZ(0, batSprite.z + 1)
    # Poké Ball animation
    ballOpenUp(ball, 0, poke_ball)
    delay = ball.totalDuration
    ballBurstRecall(delay, ball, battlerEndX, battlerEndY, poke_ball)
    ball.moveOpacity(10, 2, 0)
    # Battler animation
    battlerAbsorb(battler, delay, battlerEndX, battlerEndY, col)
    if shaSprite.visible
      # Set up shadow sprite
      shadow = addSprite(shaSprite, PictureOrigin::CENTER)
      # Shadow animation
      shadow.moveOpacity(0, 10, 0)
      shadow.setVisible(delay, false)
    end
  end
end

#===============================================================================
#
#===============================================================================
class Battle::Scene::Animation::BattlerDamage < Battle::Scene::Animation
  def createProcesses
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    # Set up battler/shadow sprite
    battler = addSprite(batSprite, nil)
    shadow  = addSprite(shaSprite, PictureOrigin::CENTER)
    # Animation
    delay = 0
    case @effectiveness
    when 0 then battler.setSE(delay, "Battle damage normal")
    when 1 then battler.setSE(delay, "Battle damage weak")
    when 2 then battler.setSE(delay, "Battle damage super")
    end
    4.times do   # 4 flashes, each lasting 0.2 (4/20) seconds
      battler.setVisible(delay, false)
      shadow.setVisible(delay, false)
      battler.setVisible(delay + 2, true) if batSprite.visible
      shadow.setVisible(delay + 2, true) if shaSprite.visible
      delay += 4
    end
    # Restore original battler/shadow sprites visibilities
    battler.setVisible(delay, batSprite.visible)
    shadow.setVisible(delay, shaSprite.visible)
  end
end

#===============================================================================
#
#===============================================================================
class Battle::Scene::Animation::BattlerFaint < Battle::Scene::Animation
  def createProcesses
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    # Set up battler/shadow sprite
    battler = addSprite(batSprite, nil)
    shadow  = addSprite(shaSprite, PictureOrigin::CENTER)
    # Get approx duration depending on sprite's position/size. Min 20 frames.
    battlerTop = batSprite.y - batSprite.oy
    cropY = Battle::Scene.pbBattlerPosition(@idxBattler, @battle.pbSideSize(@idxBattler))[1]
    cropY += 8
    duration = (cropY - battlerTop) / 8
    duration = 10 if duration < 10   # Min 0.5 seconds
    # Animation
    # Play cry
    delay = 10
    cry = GameData::Species.cry_filename_from_pokemon(batSprite.pkmn, "_faint")
    if cry   # Play a specific faint cry
      battler.setSE(0, cry)
      delay = (GameData::Species.cry_length(batSprite.pkmn, nil, nil, "_faint") * 20).ceil
    else
      cry = GameData::Species.cry_filename_from_pokemon(batSprite.pkmn)
      if cry   # Play the regular cry at a lower pitch (75)
        battler.setSE(0, cry, nil, 75)
        delay = (GameData::Species.cry_length(batSprite.pkmn, nil, 75) * 20).ceil
      end
    end
    delay += 2
    # Sprite drops down
    shadow.setVisible(delay, false)
    battler.setSE(delay, "Pkmn faint")
    battler.moveOpacity(delay, duration, 0)
    battler.moveDelta(delay, duration, 0, cropY - battlerTop)
    battler.setCropBottom(delay, cropY)
    battler.setVisible(delay + duration, false)
    battler.setOpacity(delay + duration, 255)
  end
end

#===============================================================================
#
#===============================================================================
class Battle::Scene::Animation::PokeballThrowCapture < Battle::Scene::Animation
  def createProcesses
    # Calculate start and end coordinates for battler sprite movement
    batSprite = @sprites["pokemon_#{@battler.index}"]
    shaSprite = @sprites["shadow_#{@battler.index}"]
    traSprite = @sprites["player_1"]
    ballPos = Battle::Scene.pbBattlerPosition(@battler.index, batSprite.sideSize)
    battlerStartX = batSprite.x
    battlerStartY = batSprite.y
    ballStartX = -6
    ballStartY = 246
    ballMidX   = 0   # Unused in arc calculation
    ballMidY   = 78
    ballEndX   = ballPos[0]
    ballEndY   = 112
    ballGroundY = ballPos[1] - 4
    # Set up Poké Ball sprite
    ball = addBallSprite(ballStartX, ballStartY, @poke_ball)
    ball.setZ(0, batSprite.z + 1)
    @ballSpriteIndex = (@success) ? @tempSprites.length - 1 : -1
    # Set up trainer sprite (only visible in Safari Zone battles)
    if @showingTrainer && traSprite && traSprite.bitmap.width >= traSprite.bitmap.height * 2
      trainer = addSprite(traSprite, PictureOrigin::BOTTOM)
      # Trainer animation
      ballStartX, ballStartY = trainerThrowingFrames(ball, trainer, traSprite)
    end
    delay = ball.totalDuration   # 0 or 7
    # Poké Ball arc animation
    if @critCapture
      ball.setSE(delay, "Battle critical catch throw")
    else
      ball.setSE(delay, "Battle throw")
    end
    createBallTrajectory(ball, delay, 16,
                         ballStartX, ballStartY, ballMidX, ballMidY, ballEndX, ballEndY)
    ball.setZ(9, batSprite.z + 1)
    ball.setSE(delay + 16, "Battle ball hit")
    # Poké Ball opens up
    delay = ball.totalDuration + 6
    ballOpenUp(ball, delay, @poke_ball, true, false)
    # Set up battler sprite
    battler = addSprite(batSprite, nil)
    # Poké Ball absorbs battler
    delay = ball.totalDuration
    ballBurstCapture(delay, ball, ballEndX, ballEndY, @poke_ball)
    # NOTE: The Pokémon does not change color while being absorbed into a Poké
    #       Ball during a capture attempt. This may be an oversight in HGSS.
    #       It's hard to spot due to the ball burst animation being played on
    #       top of it.
    battler.setSE(delay, "Battle jump to ball")
    battler.moveXY(delay, 5, ballEndX, ballEndY)
    battler.moveZoom(delay, 5, 0)
    battler.setVisible(delay + 5, false)
    if @shadowVisible
      # Set up shadow sprite
      shadow = addSprite(shaSprite, PictureOrigin::CENTER)
      # Shadow animation
      shadow.moveOpacity(delay, 5, 0)
      shadow.moveZoom(delay, 5, 0)
      shadow.setVisible(delay + 5, false)
    end
    # Poké Ball closes
    delay = ball.totalDuration
    ballSetClosed(ball, delay, @poke_ball)
    ball.moveTone(delay, 3, Tone.new(96, 64, -160, 160))
    ball.moveTone(delay + 5, 3, Tone.new(0, 0, 0, 0))
    # Poké Ball critical capture animation
    delay = ball.totalDuration + 3
    if @critCapture
      ball.setSE(delay, "Battle ball shake")
      ball.moveXY(delay, 1, ballEndX + 4, ballEndY)
      ball.moveXY(delay + 1, 2, ballEndX - 4, ballEndY)
      ball.moveXY(delay + 3, 2, ballEndX + 4, ballEndY)
      ball.setSE(delay + 4, "Battle ball shake")
      ball.moveXY(delay + 5, 2, ballEndX - 4, ballEndY)
      ball.moveXY(delay + 7, 1, ballEndX, ballEndY)
      delay = ball.totalDuration + 3
    end
    # Poké Ball drops to the ground
    4.times do |i|
      t = [4, 4, 3, 2][i]   # Time taken to rise or fall for each bounce
      d = [1, 2, 4, 8][i]   # Fraction of the starting height each bounce rises to
      delay -= t if i == 0
      if i > 0
        ball.setZoomXY(delay, 100 + (5 * (5 - i)), 100 - (5 * (5 - i)))   # Squish
        ball.moveZoom(delay, 2, 100)                      # Unsquish
        ball.moveXY(delay, t, ballEndX, ballGroundY - ((ballGroundY - ballEndY) / d))
      end
      ball.moveXY(delay + t, t, ballEndX, ballGroundY)
      ball.setSE(delay + (2 * t), "Battle ball drop", 100 - (i * 7))
      delay = ball.totalDuration
    end
    battler.setXY(ball.totalDuration, ballEndX, ballGroundY)
    # Poké Ball shakes
    delay = ball.totalDuration + 12
    [@numShakes, 3].min.times do |i|
      ball.setSE(delay, "Battle ball shake")
      ball.moveXY(delay, 2, ballEndX - (2 * (4 - i)), ballGroundY)
      ball.moveAngle(delay, 2, 5 * (4 - i))   # positive means counterclockwise
      ball.moveXY(delay + 2, 4, ballEndX + (2 * (4 - i)), ballGroundY)
      ball.moveAngle(delay + 2, 4, -5 * (4 - i))   # negative means clockwise
      ball.moveXY(delay + 6, 2, ballEndX, ballGroundY)
      ball.moveAngle(delay + 6, 2, 0)
      delay = ball.totalDuration + 8
    end
    if @success
      # Pokémon was caught
      ballCaptureSuccess(ball, delay, ballEndX, ballGroundY)
    else
      # Poké Ball opens
      ball.setZ(delay, batSprite.z - 1)
      ballOpenUp(ball, delay, @poke_ball, false)
      ballBurst(delay, ball, ballEndX, ballGroundY, @poke_ball)
      ball.moveOpacity(delay + 2, 2, 0)
      # Battler emerges
      col = getBattlerColorFromPokeBall(@poke_ball)
      col.alpha = 255
      battler.setColor(delay, col)
      battlerAppear(battler, delay, battlerStartX, battlerStartY, batSprite, col)
      if @shadowVisible
        shadow.setVisible(delay + 5, true)
        shadow.setZoom(delay + 5, 100)
        shadow.moveOpacity(delay + 5, 10, 255)
      end
    end
  end
end
