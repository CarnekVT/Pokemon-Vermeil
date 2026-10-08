#===============================================================================
# Z-order fix: Enhanced UI must render above BattleBox/TargetMenu (z=10000)
# and BossHUD (z=3000).
#===============================================================================
# BSS085 sets enhancedUI.z=12000 ("above TargetMenu/BattleBox use 10000").
# But BSS087's pbUpdate runs AFTER BSS085 and calls bss087_enforce_enhanced_ui_z
# which calls bss087_enhanced_base_z. That function scans @sprites for keys
# matching "databox", "battlebox", "command", "fight", "messagebox", "cmdbar"
# — but NOT "target" (TargetMenu, z=10000). So it returns 300, dragging
# enhancedUI from 12000 down to 300 — below BattleBox.
#
# This patch wraps bss087_enhanced_base_z to also scan for "target" sprites
# and BossHUD internal sprites, ensuring Enhanced UI stays above everything.
#===============================================================================
module ZBOXEnhancedUIZFix
  ENHANCED_MIN_Z = 10000

  def bss087_enhanced_base_z
    base = super
    begin
      (@sprites || {}).each do |k, sp|
        next if !sp || !sp.respond_to?(:z)
        n = k.to_s.downcase
        next if n.include?("enhanced") || n.include?("outline") || n.include?("info_icon") || n.include?("ball_icon") || n == "bss087capturefilter"
        z = (sp.z rescue 0).to_i
        if n.include?("target") || n.include?("databox") || n.include?("battlebox") ||
           n.include?("command") || n.include?("fight") || n.include?("messagebox") || n.include?("cmdbar")
          base = [base, z + 20].max
        end
      end
      if instance_variable_defined?(:@bss_boss_hud) && @bss_boss_hud &&
         !(@bss_boss_hud.disposed? rescue false)
        hud_sprites = @bss_boss_hud.instance_variable_get(:@sprites)
        if hud_sprites.is_a?(Array)
          hud_sprites.each do |sp|
            next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:z)
            z = (sp.z rescue 0).to_i
            base = [base, z + 20] if z > base
          end
        end
      end
    rescue
      # scanning failed; return original base from super
    end
    [base, ENHANCED_MIN_Z].max
  end
end

if defined?(Battle::Scene) &&
   Battle::Scene.instance_methods.include?(:bss087_enhanced_base_z) &&
   !Battle::Scene.ancestors.include?(ZBOXEnhancedUIZFix)
  Battle::Scene.prepend(ZBOXEnhancedUIZFix)
end
