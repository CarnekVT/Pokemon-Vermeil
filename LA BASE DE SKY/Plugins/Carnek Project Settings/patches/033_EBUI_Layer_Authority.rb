#===============================================================================
# Carnek Project Settings - Enhanced Battle UI layer authority
# Pokémon Essentials v21.1 / DBK Enhanced Battle UI / BSS compatibility
#
# Runtime captures from Vermeil showed databoxes at z=10149 while Enhanced UI
# prompt sprites were at z=10119. BSS can also recreate targetWindow and
# info_icon sprites after the initial scene setup. Keep this fix here, rather
# than in Enhanced Battle UI/BSS, so plugin updates cannot remove it.
#
# Keep databoxes below the Enhanced UI band, and promote UI sprites recreated
# dynamically by BSS.  Uses prepend + super only; no alias chain.
#===============================================================================

module CarnekProjectSettings
  module EBUILayerAuthority
    DATABOX_Z_CEILING = 10_900
    ENHANCED_UI_Z_MIN = 11_000

    def carnek_enforce_ebui_layer_authority
      return if !defined?(@sprites) || !@sprites.is_a?(Hash)

      @sprites.each do |key, sprite|
        next if !sprite || (sprite.respond_to?(:disposed?) && sprite.disposed?)
        next if !sprite.respond_to?(:z) || !sprite.respond_to?(:z=)
        name = key.to_s
        low  = name.downcase

        # Databoxes must remain part of the battle HUD, but never cover the
        # Enhanced Battle UI overlays/prompts/selection UI.
        if low.start_with?("databox_")
          sprite.z = DATABOX_Z_CEILING if sprite.z > DATABOX_Z_CEILING
          next
        end

        # Enhanced Battle UI / DBK selection sprites. BSS may create these
        # after pbInitSprites, bypassing the initial z normalization.
        enhanced_key = (
          low == "targetwindow" ||
          low.start_with?("info_icon") ||
          low.include?("battleinfo") ||
          low.include?("battlerinfo") ||
          low.include?("moveinfo") ||
          low.include?("enhancedui") ||
          low.include?("enhanced_ui")
        )
        sprite.z = ENHANCED_UI_Z_MIN if enhanced_key && sprite.z < ENHANCED_UI_Z_MIN
      end
    end

    def pbInitSprites(*args)
      ret = super
      carnek_enforce_ebui_layer_authority
      return ret
    end

    def pbRefresh(*args)
      ret = super
      carnek_enforce_ebui_layer_authority
      return ret
    end

    # Needed because SOS/BSS can recreate databoxes, targetWindow and info
    # icons after the scene has already initialized.
    def pbPrepNewBattler(*args)
      ret = super
      carnek_enforce_ebui_layer_authority
      return ret
    end

    # Custom databox/UI plugins can restore their own z during updates.
    # Reassert only the small set of HUD/UI sprites above; no viewport changes.
    def pbUpdate(*args)
      ret = super
      carnek_enforce_ebui_layer_authority
      return ret
    end
  end
end

if defined?(Battle::Scene) &&
   !Battle::Scene.ancestors.include?(CarnekProjectSettings::EBUILayerAuthority)
  Battle::Scene.prepend(CarnekProjectSettings::EBUILayerAuthority)
end
