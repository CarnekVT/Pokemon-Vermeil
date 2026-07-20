#===============================================================================
# BattlerFaintShrink — wild opponents: encoger + fundir
# BattlerFaintRecall — trainer battles: absorb + ball recall
# Parche a Battle::Scene#pbFaintBattler
#===============================================================================
class Battle::Scene::Animation::BattlerFaintShrink < Battle::Scene::Animation
  include Battle::Scene::Animation::FaintedOverlayHelper

  def initialize(sprites, viewport, idxBattler, battle)
    @idxBattler = idxBattler
    @battle     = battle
    super(sprites, viewport)
  end

  def createProcesses
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    return if !batSprite
    pbMakeFaintOverlay(batSprite)
    battler = addSprite(batSprite, PictureOrigin::BOTTOM)
    shadow  = addSprite(shaSprite, PictureOrigin::CENTER)
    @_fainted_swap_frame = 0
    battler.setSE(0, "Pkmn faint")
    battler.moveOpacity(0, 10, 0)
    battler.moveZoom(0, 10, 0)
    battler.setVisible(10, false)
    battler.setOpacity(10, 255)
    shadow.setVisible(0, false)
  end
end

#===============================================================================
class Battle::Scene::Animation::BattlerFaintRecall < Battle::Scene::Animation
  include Battle::Scene::Animation::BallAnimationMixin
  include Battle::Scene::Animation::FaintedOverlayHelper

  def initialize(sprites, viewport, battler)
    @battler = battler
    @idxBattler = battler.index
    super(sprites, viewport)
  end

  def createProcesses
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    return if !batSprite
    pbMakeFaintOverlay(batSprite)
    poke_ball = (batSprite.pkmn) ? batSprite.pkmn.poke_ball : nil
    col = getBattlerColorFromPokeBall(poke_ball)
    col.alpha = 0
    ballPos = Battle::Scene.pbBattlerPosition(@idxBattler, batSprite.sideSize)
    battlerEndX = ballPos[0]
    battlerEndY = ballPos[1]
    battler = addSprite(batSprite, PictureOrigin::BOTTOM)
    battler.setVisible(0, true)
    battler.setColor(0, col)
    ball = addBallSprite(battlerEndX, battlerEndY, poke_ball)
    ball.setZ(0, batSprite.z + 1)
    ball.setVisible(0, true)
    ballOpenUp(ball, 0, poke_ball)
    @_fainted_swap_frame = 0
    ballBurstRecall(0, ball, battlerEndX, battlerEndY, poke_ball)
    col.alpha = 255
    battler.moveColor(0, 10, col)
    battler.moveOpacity(0, 10, 0)
    d2 = battler.totalDuration
    battler.moveXY(d2, 5, battlerEndX, battlerEndY)
    battler.moveZoom(d2, 5, 0)
    battler.setVisible(d2 + 5, false)
    ballSetClosed(ball, d2 + 5, poke_ball)
    ball.moveOpacity(d2 + 5, 3, 0)
    ball.setVisible(d2 + 8, false)
    if shaSprite.visible
      shadow = addSprite(shaSprite, PictureOrigin::CENTER)
      shadow.moveOpacity(0, 14, 0)
      shadow.setVisible(14, false)
    end
  end
end

#===============================================================================
class Battle::Scene
  alias _carnek_faintrecall_pbFaintBattler pbFaintBattler
  def pbFaintBattler(battler)
    @briefMessage = false
    idx = battler.index
    batSprite = @sprites["pokemon_#{idx}"]
    # Play cry and wait in real-time before any visual animation
    cry = GameData::Species.cry_filename_from_pokemon(batSprite.pkmn, "_faint")
    if cry
      pbSEPlay(cry)
      cry_len = GameData::Species.cry_length(batSprite.pkmn, nil, nil, "_faint")
    else
      cry = GameData::Species.cry_filename_from_pokemon(batSprite.pkmn)
      if cry
        pbSEPlay(cry, nil, 75)
        cry_len = GameData::Species.cry_length(batSprite.pkmn, nil, 75)
      end
    end
    if cry
      timer_start = System.uptime
      loop do
        pbUpdate
        break if System.uptime - timer_start >= cry_len
      end
    end
    if @battle.wildBattle? && battler.opposes?
      old_height = @sprites["pokemon_#{idx}"].src_rect.height
      faintAnim   = Animation::BattlerFaintShrink.new(@sprites, @viewport, idx, @battle)
      dataBoxAnim = Animation::DataBoxDisappear.new(@sprites, @viewport, idx)
      frame = 0
      loop do
        faintAnim.update
        dataBoxAnim.update
        pbUpdate
        faintAnim.pbUpdateFaintOverlay(frame)
        break if faintAnim.animDone? && dataBoxAnim.animDone?
        frame += 1
      end
      faintAnim.dispose
      faintAnim.pbDisposeFaintOverlay
      dataBoxAnim.dispose
      @sprites["pokemon_#{idx}"].src_rect.height = old_height
    else
      old_height = @sprites["pokemon_#{idx}"].src_rect.height
      faintAnim   = Animation::BattlerFaintRecall.new(@sprites, @viewport, battler)
      dataBoxAnim = Animation::DataBoxDisappear.new(@sprites, @viewport, idx)
      frame = 0
      loop do
        faintAnim.update
        dataBoxAnim.update
        pbUpdate
        faintAnim.pbUpdateFaintOverlay(frame)
        break if faintAnim.animDone? && dataBoxAnim.animDone?
        frame += 1
      end
      faintAnim.dispose
      faintAnim.pbDisposeFaintOverlay
      dataBoxAnim.dispose
      @sprites["pokemon_#{idx}"].src_rect.height = old_height
    end
  end
end