module Battle::Scene::Animation::HitOverlayHelper
  def pbMakeHitOverlay(batSprite)
    return if !batSprite.pkmn
    @_hit_batsprite = batSprite
    @_hit_original_bitmap = batSprite.bitmap
    [false, true].each do |back|
      @_hit_bitmap = HitBitmap.new(batSprite.pkmn, back)
      next if @_hit_bitmap.length == 0
      batSprite.bitmap = @_hit_bitmap.bitmap
      Battle::Scene.carnek_scene&._carnek_hit_register(self)
      return
    end
    @_hit_bitmap = nil
  end

  def pbUpdateHitOverlay
    return if !@_hit_bitmap
    @_hit_bitmap.update
    if @_hit_bitmap.done?
      _carnek_hit_cleanup
    else
      @_hit_batsprite.bitmap = @_hit_bitmap.bitmap
    end
  end

  def pbWaitForHitOverlay
    return if !@_hit_bitmap
    scene = Battle::Scene.carnek_scene
    return if !scene
    loop do
      pbUpdateHitOverlay
      break if !@_hit_bitmap
      scene.pbUpdate
    end
  end

  def _carnek_hit_cleanup
    @_hit_bitmap.dispose
    @_hit_bitmap = nil
    Battle::Scene.carnek_scene&._carnek_hit_unregister(self)
    @_hit_batsprite.bitmap = @_hit_original_bitmap if @_hit_batsprite && @_hit_original_bitmap
    @_hit_original_bitmap = nil
  end

  def pbDisposeHitOverlay
    Battle::Scene.carnek_scene&._carnek_hit_unregister(self)
    if @_hit_bitmap
      @_hit_bitmap.dispose
      @_hit_bitmap = nil
    end
    @_hit_batsprite.bitmap = @_hit_original_bitmap if @_hit_batsprite && @_hit_original_bitmap
    @_hit_original_bitmap = nil
    @_hit_batsprite = nil
  end

  def _carnek_hit_current_bitmap
    @_hit_bitmap&.bitmap
  end

  def _carnek_hit_sprite
    @_hit_batsprite
  end
end
