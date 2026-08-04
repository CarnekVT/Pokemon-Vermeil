#===============================================================================
# Mode 7 (2.5D) - Proyección de personajes
#===============================================================================
class Game_Character
  alias_method :_ZBOX_M7_orig_screen_x, :screen_x
  alias_method :_ZBOX_M7_orig_screen_y_ground, :screen_y_ground
  alias_method :_ZBOX_M7_orig_screen_z, :screen_z

  def screen_x
    return _ZBOX_M7_orig_screen_x if !mode7_active_for_self?
    wx = @real_x.to_f / Game_Map::X_SUBPIXELS + (@width * Game_Map::TILE_WIDTH / 2)
    wy = @real_y.to_f / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT
    pr = Mode7.project(wx, wy)
    return -1000 if !pr
    return pr[0].round + self.x_offset
  end

  def screen_y_ground
    return _ZBOX_M7_orig_screen_y_ground if !mode7_active_for_self?
    wx = @real_x.to_f / Game_Map::X_SUBPIXELS
    wy = @real_y.to_f / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT
    pr = Mode7.project(wx, wy)
    return 100_000 if !pr
    return pr[1].round
  end

  def screen_z(height = 0)
    ret = _ZBOX_M7_orig_screen_z(height)
    return ret + 1 if mode7_active_for_self?
    return ret
  end

  private

  def mode7_active_for_self?
    return false if !$scene.is_a?(Scene_Map)
    return Mode7.active_now?
  end
end
