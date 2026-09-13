#===============================================================================
# Eclipse Fog (Executioner's Shadow) display in Enhanced Battle UI
#===============================================================================
# EBU's pbGetDisplayEffects shows DBK/PBEffects but not Battle Additions'
# Executioner's Shadow state. This patch prepends a hook that adds the Eclipse
# fog effect to the battler info panel when active.
#===============================================================================
module ZBOXEclipseFogDisplay
  def pbGetDisplayEffects(battler)
    effects = super
    return effects unless @battle && battler

    if @battle.respond_to?(:pbExecutionerShadowActive?) && @battle.pbExecutionerShadowActive?
      if @battle.respond_to?(:pbExecutionerShadowInvokerSide?) && @battle.pbExecutionerShadowInvokerSide?(battler)
        ticks = @battle.instance_variable_get(:@exec_shadow_turns) || 0
        name = _INTL("Eclipse")
        tick = ticks.to_s
        desc = _INTL("El Pokémon es protegido por el velo del eclipse. Los tipos Siniestro y Fantasma se fortalecen, mientras que la luz es suprimida.")
        effects.push([name, tick, desc])
      elsif @battle.respond_to?(:pbExecutionerShadowOpposes?) && @battle.pbExecutionerShadowOpposes?(battler)
        ticks = @battle.instance_variable_get(:@exec_shadow_turns) || 0
        name = _INTL("Eclipse")
        tick = ticks.to_s
        desc = _INTL("El Pokémon es debilitado por el velo del eclipse. Los tipos Siniestro y Fantasma se fortalecen a costa de los demás.")
        effects.push([name, tick, desc])
      end
    end

    effects
  end
end

if defined?(Battle::Scene) &&
   Battle::Scene.instance_methods.include?(:pbGetDisplayEffects) &&
   !Battle::Scene.ancestors.include?(ZBOXEclipseFogDisplay)
  Battle::Scene.prepend(ZBOXEclipseFogDisplay)
end
