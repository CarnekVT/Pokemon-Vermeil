module Battle::Scene::Animation::FaintedOverlayHelper
  def pbMakeFaintOverlay(batSprite)
    return if !batSprite.pkmn
    @_fainted_batsprite = batSprite
    @_fainted_swapped = false
    @_fainted_swap_frame = 0
    [false, true].each do |back|
      @_fainted_bitmap = FaintedBitmap.new(batSprite.pkmn, back)
      next if @_fainted_bitmap.length == 0
      return
    end
  end

  def pbUpdateFaintOverlay(frame = 0)
    return if !@_fainted_bitmap
    if !@_fainted_swapped && frame >= @_fainted_swap_frame
      @_fainted_bitmap.instance_variable_set(:@last_update, System.uptime)
      @_fainted_batsprite.bitmap = @_fainted_bitmap.bitmap
      @_fainted_swapped = true
    end
    return if !@_fainted_swapped
    @_fainted_bitmap.update
    @_fainted_batsprite.bitmap = @_fainted_bitmap.bitmap
  end

  def pbDisposeFaintOverlay
    @_fainted_bitmap&.dispose
    @_fainted_bitmap = nil
    @_fainted_batsprite = nil
  end
end
