
#===============================================================================
# Arcane visual indicators in Summary.
#===============================================================================
if defined?(PokemonSummary_Scene)
  module ArcaneAbilities
    module SummaryArcaneInfo
      ARCANE_BASE   = Color.new(120, 72, 160)
      ARCANE_SHADOW = Color.new(216, 184, 240)
      ARCANE_DIM    = Color.new(92, 56, 124)
      ARCANE_DIM_S  = Color.new(172, 144, 206)

      def drawPageOne
        ret = super
        return ret if !@pokemon || !@pokemon.hasArcaneAbility?
        overlay = @sprites["overlay"].bitmap
        state = if @pokemon.arcane_active?
                  _INTL("ACTIVA")
                elsif @pokemon.arcane_unlocked?
                  _INTL("DESBLOQUEADA")
                else
                  _INTL("SELLADA")
                end
        arcane_name = begin
          GameData::Ability.get(@pokemon.arcane_ability_id).name
        rescue
          @pokemon.arcane_ability_id.to_s
        end
        pbDrawTextPositions(overlay, [
          [_INTL("✦ HABILIDAD ARCANA"), 224, 300, :left, ARCANE_BASE, ARCANE_SHADOW],
          [_INTL("{1} · {2}", state, arcane_name), 224, 332, :left, ARCANE_DIM, ARCANE_DIM_S]
        ])
        return ret
      end

      def drawPageThree
        ret = super
        return ret if !@pokemon || !@pokemon.arcane_unlocked?
        arcane = @pokemon.arcane_ability_id
        return ret if !arcane
        overlay = @sprites["overlay"].bitmap
        state = @pokemon.arcane_active? ? _INTL("ACTIVA") : _INTL("DESBLOQUEADA")
        arcane_name = begin
          GameData::Ability.get(arcane).name
        rescue
          arcane.to_s
        end
        pbDrawTextPositions(overlay, [
          [_INTL("ARCANA · {1}", state), 224, 374, :left, ARCANE_BASE, ARCANE_SHADOW],
          [_INTL("Capacidad ancestral equipada: {1}", arcane_name), 224, 406, :left, ARCANE_DIM, ARCANE_DIM_S]
        ])
        return ret
      end
    end
  end
  PokemonSummary_Scene.prepend(ArcaneAbilities::SummaryArcaneInfo)
end
