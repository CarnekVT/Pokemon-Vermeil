#===============================================================================
# Carnek Project Settings - Enhanced Battle UI layer authority
# Pokémon Essentials v21.1 / DBK Enhanced Battle UI / BSS compatibility
#
# BSS can recreate or raise UI sprites after the initial scene setup. Keep the
# requested ordering here, rather than changing DBK or BSS: move information
# stays behind command windows and all Enhanced UI information behind databoxes.
#===============================================================================

module CarnekProjectSettings
  module EBUILayerAuthority
    # BSS places the interactive command window at 10_000 and its databoxes
    # around 10_149. Keep Enhanced UI visible in the HUD band, but below both.
    DATABOX_Z_FLOOR       = 10_149
    ENHANCED_UI_Z         = 9_900
    ENHANCED_PROMPT_Z     = 9_950
    ENHANCED_ICON_Z       = 9_970
    ENHANCED_ARROW_Z      = 9_920

    def carnek_enforce_ebui_layer_authority
      return if !defined?(@sprites) || !@sprites.is_a?(Hash)

      @sprites.each do |key, sprite|
        next if !sprite || (sprite.respond_to?(:disposed?) && sprite.disposed?)
        next if !sprite.respond_to?(:z) || !sprite.respond_to?(:z=)
        name = key.to_s
        low  = name.downcase

        # Databoxes are the foreground HUD layer.
        if low.start_with?("databox_")
          sprite.z = DATABOX_Z_FLOOR if sprite.z < DATABOX_Z_FLOOR
          next
        end

        # targetWindow is an interactive selector and intentionally retains its
        # native layer. Everything drawn by Enhanced UI is informational.
        if low == "enhancedui"
          sprite.z = ENHANCED_UI_Z
        elsif low == "enhanceduiprompts"
          sprite.z = ENHANCED_PROMPT_Z
        elsif low == "leftarrow" || low == "rightarrow"
          sprite.z = ENHANCED_ARROW_Z
        elsif low.start_with?("info_icon") || low.start_with?("ball_icon")
          sprite.z = ENHANCED_ICON_Z
        elsif low =~ /\A(.+)_outline\d+\z/
          parent = @sprites[$1] rescue nil
          if parent && parent.respond_to?(:z)
            sprite.z = parent.z.to_i - 1
          end
        end
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

    # BSS reapplies its own UI Z after this method's original implementation.
    # Normalize once more so opening the Fight/Command window cannot raise the
    # move-information overlay above it.
    def pbShowWindow(*args)
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
