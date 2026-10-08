#===============================================================================
# Carnek Project Settings - Enhanced Battle UI z-fix
#
# Flat alias on pbInitSprites would capture a prepended module (BSS/BAT/DBK)
# and bounce via its `super` → SystemStackError. Prepend with `super` chains
# safely in any load order.
#===============================================================================

module CarnekProjectSettings
  module EBUIZFix
    def pbInitSprites
      super
      @sprites["enhancedUI"].z += 9999 if @sprites["enhancedUI"]
      @sprites["leftarrow"].z += 9999 if @sprites["leftarrow"]
      @sprites["rightarrow"].z += 9999 if @sprites["rightarrow"]
      @sprites["enhancedUIPrompts"].z += 9999 if @sprites["enhancedUIPrompts"]
      @sprites.keys.each do |key|
        next unless key =~ /\A(info_icon|ball_icon)\d+\z/
        @sprites[key].z += 9999
        8.times do |i|
          okey = "#{key}_outline#{i}"
          @sprites[okey].z += 9999 if @sprites[okey]
        end
      end
    end
  end
end

if defined?(Battle::Scene) &&
   !Battle::Scene.ancestors.include?(CarnekProjectSettings::EBUIZFix)
  Battle::Scene.prepend(CarnekProjectSettings::EBUIZFix)
end