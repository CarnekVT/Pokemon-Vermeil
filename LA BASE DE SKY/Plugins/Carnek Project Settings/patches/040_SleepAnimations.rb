#===============================================================================
# Sleep overlay — bitmap replacement antes de cada render
# Hit: registro de animación activa, re-aplicado via Graphics.update wrapper
# Faint: lock vía pbUpdateFaintOverlay (post-cry)
#===============================================================================
class Battle::Scene
  def self.carnek_scene; @carnek_scene; end
  def self.carnek_scene=(val); @carnek_scene = val; end

  alias _carnek_sleep_orig_pbStartBattle pbStartBattle
  def pbStartBattle(battle)
    Battle::Scene.carnek_scene = self
    @_carnek_sleep_data = {}
    @_carnek_sleep_anim_lock ||= {}
    @_carnek_active_hits = []
    _carnek_sleep_orig_pbStartBattle(battle)
    @battle.battlers.each_with_index do |b, i|
      next if !b || !b.pokemon
      next if @_carnek_sleep_data[i]
      _carnek_sleep_precache(i)
    end
  end

  def _carnek_sleep_precache(idx)
    batSprite = @sprites["pokemon_#{idx}"]
    return if !batSprite || !batSprite.pkmn
    @_carnek_sleep_data ||= {}
    sd = {}
    sd[:bitmap] = SleepBitmap.new(batSprite.pkmn, false)
    if sd[:bitmap].length == 0
      sd[:bitmap].dispose
      sd[:bitmap] = SleepBitmap.new(batSprite.pkmn, true)
      if sd[:bitmap].length == 0
        sd[:bitmap].dispose
        sd[:bitmap] = nil
      end
    end
    @_carnek_sleep_data[idx] = sd
  end

  alias _carnek_sleep_orig_pbEndBattle pbEndBattle
  def pbEndBattle(result)
    _carnek_sleep_orig_pbEndBattle(result)
    Battle::Scene.carnek_scene = nil
  end

  alias _carnek_sleep_orig_pbSendOutBattlers pbSendOutBattlers
  def pbSendOutBattlers(sendOuts, startBattle = false)
    _carnek_sleep_orig_pbSendOutBattlers(sendOuts, startBattle)
    sendOuts.each { |b| _carnek_sleep_precache(b[0]) }
  end

  alias _carnek_sleep_orig_pbFrameUpdate pbFrameUpdate
  def pbFrameUpdate(cw = nil)
    _carnek_sleep_orig_pbFrameUpdate(cw)
    _carnek_sleep_ensure_bitmaps
    @_carnek_sleep_data&.each_value { |sd| sd[:bitmap]&.update }
  end

  def _carnek_sleep_create_data(idx)
    b = @battle.battlers[idx]
    batSprite = @sprites["pokemon_#{idx}"]
    return if !b || b.status != :SLEEP || !batSprite || !batSprite.pkmn
    return if @_carnek_sleep_data&.[](idx)
    @_carnek_sleep_data ||= {}
    sd = {}
    sd[:bitmap] = SleepBitmap.new(batSprite.pkmn, false)
    if sd[:bitmap].length == 0
      sd[:bitmap].dispose
      sd[:bitmap] = SleepBitmap.new(batSprite.pkmn, true)
      if sd[:bitmap].length == 0
        sd[:bitmap].dispose
        sd[:bitmap] = nil
      end
    end
    @_carnek_sleep_data[idx] = sd
  end

  def _carnek_sleep_cleanup_data(idx)
    @_carnek_sleep_data&.delete(idx)
  end

  def _carnek_sleep_ensure_bitmaps
    return if !@_carnek_sleep_data || !@battle
    @_carnek_sleep_anim_lock ||= {}
    @battle.battlers.each_with_index do |b, i|
      next if !b
      if b.status == :SLEEP
        _carnek_sleep_create_data(i)
        next if @_carnek_sleep_anim_lock[i]
        sd = @_carnek_sleep_data[i]
        next if !sd || !sd[:bitmap]
        sp = @sprites["pokemon_#{i}"]
        next if !sp
        sp.bitmap = sd[:bitmap].bitmap
      elsif @_carnek_sleep_data&.[](i)
        _carnek_sleep_cleanup_data(i)
      end
    end
  end

  def _carnek_sleep_lock(idx)
    @_carnek_sleep_anim_lock ||= {}
    @_carnek_sleep_anim_lock[idx] = true
  end

  def _carnek_sleep_unlock(idx)
    @_carnek_sleep_anim_lock&.delete(idx)
  end

  # ── Hit registration: wrapper re-applies hit bitmap after everything ──
  def _carnek_hit_register(anim)
    @_carnek_active_hits ||= []
    @_carnek_active_hits << anim unless @_carnek_active_hits.include?(anim)
  end

  def _carnek_hit_unregister(anim)
    @_carnek_active_hits&.delete(anim)
  end

  def _carnek_hit_apply_pending
    @_carnek_active_hits&.each do |anim|
      bmp = anim._carnek_hit_current_bitmap rescue nil
      sp = anim._carnek_hit_sprite rescue nil
      sp.bitmap = bmp if sp && bmp
    end
  end

  # ── Sleep hit: sin lock, wrapper re-apliega hit bitmap ──
  def _carnek_sleep_damage_animation(battler, effectiveness)
    idx = battler.index
    sd = @_carnek_sleep_data&.[](idx)
    if !sd || !sd[:bitmap]
      _carnek_hit_orig_pbDamageAnimation(battler, effectiveness)
      return
    end
    @briefMessage = false
    anim = Battle::Scene::Animation::BattlerDamage.new(@sprites, @viewport, idx, effectiveness)
    loop do
      anim.update
      anim.pbUpdateHitOverlay
      pbUpdate
      anim.pbUpdateHitOverlay
      break if anim.animDone?
    end
    anim.pbWaitForHitOverlay
    sd = @_carnek_sleep_data[idx]
    @sprites["pokemon_#{idx}"].bitmap = sd[:bitmap].bitmap if sd && sd[:bitmap]
    anim.pbDisposeHitOverlay rescue nil
    anim.dispose
  end

  def _carnek_sleep_hit_and_hp_animation(targets)
    unless targets.all? { |t| sd = @_carnek_sleep_data&.[](t[0].index); sd && sd[:bitmap] }
      _carnek_hit_orig_pbHitAndHPLossAnimation(targets)
      return
    end
    @briefMessage = false
    anims = []
    targets.each do |t|
      idx = t[0].index
      a = Battle::Scene::Animation::BattlerDamage.new(@sprites, @viewport, idx, t[2])
      anims.push(a)
      @sprites["dataBox_#{idx}"].animate_hp(t[1], t[0].hp)
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
    anims.each { |a| a.pbWaitForHitOverlay rescue nil }
    targets.each do |t|
      idx = t[0].index
      sd = @_carnek_sleep_data[idx]
      @sprites["pokemon_#{idx}"].bitmap = sd[:bitmap].bitmap if sd && sd[:bitmap]
    end
    anims.each { |a| a.pbDisposeHitOverlay rescue nil }
    anims.each { |a| a.dispose }
  end

  alias _carnek_sleep_orig_pbFaintBattler pbFaintBattler
  def pbFaintBattler(battler)
    _carnek_sleep_orig_pbFaintBattler(battler)
  ensure
    _carnek_sleep_unlock(battler.index)
  end
end

module Battle::Scene::Animation::FaintedOverlayHelper
  alias _carnek_sleep_orig_pbUpdateFaintOverlay pbUpdateFaintOverlay
  def pbUpdateFaintOverlay(frame)
    scene = Battle::Scene.carnek_scene
    scene&._carnek_sleep_lock(@idxBattler) rescue nil
    _carnek_sleep_orig_pbUpdateFaintOverlay(frame)
  end
end

# Graphics.update wrapper — sleep + hit re-apply antes del render
module Graphics
  class << self
    # MakerStudio/F12 puede evaluar este archivo más de una vez. Sin esta
    # guarda el alias termina apuntando al propio wrapper y cada Graphics.update
    # recurre hasta SystemStackError al comenzar una animación de combate.
    alias _carnek_sleep_orig_update update unless method_defined?(:_carnek_sleep_orig_update)
    def update
      # A bitmap callback can indirectly request Graphics.update again. Never
      # let that enter the alias chain recursively; the outer render is enough.
      return if @carnek_sleep_update_active
      @carnek_sleep_update_active=true
      scene = Battle::Scene.carnek_scene
      begin
        if scene
          begin
            scene._carnek_sleep_ensure_bitmaps
            scene._carnek_hit_apply_pending
          rescue
            Battle::Scene.carnek_scene = nil
          end
        end
        _carnek_sleep_orig_update
      ensure
        @carnek_sleep_update_active=false
      end
    end
  end
end
