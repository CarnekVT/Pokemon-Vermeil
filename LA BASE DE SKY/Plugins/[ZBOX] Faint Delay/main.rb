if defined?(Battle::Scene)
  class Battle::Scene
    alias_method :_ZBOX_FD_orig_pbFaintBattler, :pbFaintBattler

    def pbFaintBattler(battler)
      _ZBOX_FD_orig_pbFaintBattler(battler)
      idxBattler = battler.index
      batSprite = @sprites["pokemon_#{idxBattler}"]
      shaSprite = @sprites["shadow_#{idxBattler}"]
      return if !batSprite
      pos = Battle::Scene.pbBattlerPosition(idxBattler, @battle.pbSideSize(idxBattler))
      batSprite.x = pos[0]
      batSprite.y = pos[1]
      batSprite.visible = true
      batSprite.opacity = 255
      if shaSprite
        shaSprite.visible = true
        shaSprite.opacity = 255
        shaSprite.zoom_x = 1.0
        shaSprite.zoom_y = 1.0
      end
      timer_start = System.uptime
      loop do
        pbUpdate
        break if System.uptime - timer_start >= 0.25
      end
    end
  end
end
