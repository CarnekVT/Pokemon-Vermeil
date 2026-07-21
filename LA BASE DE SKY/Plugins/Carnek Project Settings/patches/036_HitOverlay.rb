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
      Battle::Scene.carnek_scene&._carnek_hit_unregister(self)
      @_hit_bitmap.dispose
      @_hit_bitmap = nil
      @_hit_batsprite.bitmap = @_hit_original_bitmap if @_hit_original_bitmap
      return
    end
    @_hit_batsprite.bitmap = @_hit_bitmap.bitmap
  end

  def pbDisposeHitOverlay
    Battle::Scene.carnek_scene&._carnek_hit_unregister(self)
    @_hit_bitmap&.dispose
    @_hit_bitmap = nil
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
