#===============================================================================
#
#===============================================================================
class Battle::AI
  # Decide whether the opponent should Mega Evolve.
  def pbEnemyShouldMegaEvolve?
    if @battle.pbCanMegaEvolve?(@user.index)   # Simple "always should if possible"
      # AI Improvements (Fix #8b): solo hay una mega por combate. Si en forma BASE el
      # usuario ya es más rápido que el rival Y ya lo noquea, megaevolucionar ahora no
      # aporta nada este turno -> reservar la mega para otro Pokémon del equipo. Solo
      # high_skill? y singles (en dobles "más rápido"/"lo mato" son ambiguos).
      if @trainer.high_skill? && ai_improvements_should_save_mega?
        PBDebug.log_ai("#{@user.name} NO megaevoluciona: ya mata al rival sin la mega y es más rápido (Fix #8b)")
        return false
      end
      PBDebug.log_ai("#{@user.name} will Mega Evolve")
      return true
    end
    return false
  end

  # AI Improvements (Fix #8b): ¿conviene reservar la mega? True si es singles, el usuario
  # en forma BASE ya es más rápido que el único rival activo y ya lo noquea (rough_damage
  # lee stats/habilidad en vivo = forma base, justo lo que queremos). moldBreaker se fija
  # al del usuario porque aquí (antes del scoring) aún no está montado; se restaura con ensure.
  def ai_improvements_should_save_mega?
    foes = []
    each_foe_battler(@user.idxOwnSide) { |b, _i| foes << b }
    return false if foes.length != 1
    rival = foes[0]
    return false unless @user.faster_than?(rival)
    orig_mold = @battle.moldBreaker
    begin
      @battle.moldBreaker = @user.has_mold_breaker?
      return AIImprovements.user_can_faint_rival?(self, @user, rival)
    ensure
      @battle.moldBreaker = orig_mold
    end
  end
end

