#===============================================================================
# Hit overlay on BattlerDamage — solo si el battler NO está dormido
# Si está dormido, el sleep overlay maneja el bitmap.
# Patch: 1 flash en vez de 4 (el original hace 4 toggles de visibilidad)
#===============================================================================
class Battle::Scene::Animation::BattlerDamage
  include Battle::Scene::Animation::HitOverlayHelper

  alias _carnek_hit_orig_createProcesses createProcesses
  def createProcesses
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    _carnek_hit_check_and_make_hit_overlay(batSprite)
    # Original logic pero con 1 flash en vez de 4
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    battler = addSprite(batSprite, PictureOrigin::BOTTOM)
    shadow  = addSprite(shaSprite, PictureOrigin::CENTER)
    delay = 0
    case @effectiveness
    when 0 then battler.setSE(delay, "Battle damage normal")
    when 1 then battler.setSE(delay, "Battle damage weak")
    when 2 then battler.setSE(delay, "Battle damage super")
    end
    1.times do
      battler.setVisible(delay, false)
      shadow.setVisible(delay, false)
      battler.setVisible(delay + 2, true) if batSprite.visible
      shadow.setVisible(delay + 2, true) if shaSprite.visible
      delay += 4
    end
    battler.setVisible(delay, batSprite.visible)
    shadow.setVisible(delay, shaSprite.visible)
  end

  def _carnek_hit_check_and_make_hit_overlay(batSprite)
    return if !batSprite || !batSprite.pkmn
    if batSprite.instance_variable_get(:@battler)&.status == :SLEEP
      pbMakeSleepHitOverlay(batSprite)
    else
      pbMakeHitOverlay(batSprite)
    end
  rescue
    pbMakeHitOverlay(batSprite)
  end

  def pbMakeSleepHitOverlay(batSprite)
    return if !batSprite.pkmn
    @_hit_batsprite = batSprite
    @_hit_original_bitmap = batSprite.bitmap
    [false, true].each do |back|
      @_hit_bitmap = SleepHitBitmap.new(batSprite.pkmn, back)
      next if @_hit_bitmap.length == 0
      batSprite.bitmap = @_hit_bitmap.bitmap
      Battle::Scene.carnek_scene&._carnek_hit_register(self)
      return
    end
    @_hit_bitmap = nil
  end
end

#===============================================================================
class Battle::Scene
  alias _carnek_hit_orig_pbDamageAnimation pbDamageAnimation
  def pbDamageAnimation(battler, effectiveness = 0)
    if battler.status == :SLEEP && respond_to?(:_carnek_sleep_damage_animation)
      _carnek_sleep_damage_animation(battler, effectiveness)
    else
      @briefMessage = false
      anim = Animation::BattlerDamage.new(@sprites, @viewport, battler.index, effectiveness)
      loop do
        anim.update
        anim.pbUpdateHitOverlay
        pbUpdate
        anim.pbUpdateHitOverlay
        break if anim.animDone?
      end
      anim.pbDisposeHitOverlay
      anim.dispose
    end
  end

  alias _carnek_hit_orig_pbHitAndHPLossAnimation pbHitAndHPLossAnimation
  def pbHitAndHPLossAnimation(targets)
    all_asleep = targets.all? { |t| t[0].status == :SLEEP }
    if all_asleep && targets.length > 0 && respond_to?(:_carnek_sleep_hit_and_hp_animation)
      _carnek_sleep_hit_and_hp_animation(targets)
      return
    end
    @briefMessage = false
    anims = []
    targets.each do |t|
      anim = Animation::BattlerDamage.new(@sprites, @viewport, t[0].index, t[2])
      anims.push(anim)
      @sprites["dataBox_#{t[0].index}"].animate_hp(t[1], t[0].hp)
    end
    loop do
      anims.each { |a| a.update }
      anims.each { |a| a.pbUpdateHitOverlay rescue nil }
      pbUpdate
      anims.each { |a| a.pbUpdateHitOverlay rescue nil }
      hp_done = targets.all? { |t| !@sprites["dataBox_#{t[0].index}"].animating_hp? }
      anim_done = anims.all?(&:animDone?)
      break if hp_done && anim_done
    end
    anims.each { |a| a.pbDisposeHitOverlay rescue nil }
    anims.each { |a| a.dispose }
  end
end
