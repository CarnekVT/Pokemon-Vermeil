#===============================================================================
# Mode 7 (2.5D) - Swap del renderer en Scene_Map
#===============================================================================
class Scene_Map
  alias_method :_ZBOX_M7_orig_createSpritesets, :createSpritesets

  def createSpritesets
    wanted = (Mode7.active_now?) ? Mode7Renderer : TilemapRenderer
    if !@map_renderer || @map_renderer.disposed? || !@map_renderer.is_a?(wanted)
      @map_renderer.dispose if @map_renderer && !@map_renderer.disposed?
      @map_renderer = wanted.new(Spriteset_Map.viewport)
    end
    _ZBOX_M7_orig_createSpritesets
  end
end
