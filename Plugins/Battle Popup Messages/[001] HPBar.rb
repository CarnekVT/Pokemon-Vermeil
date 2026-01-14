#===============================================================================
# Acelera la animación de la barra de vida al recibir daño.
# Este script sobreescribe la lógica de animación de la UI de batalla para
# forzar una velocidad personalizada.
#===============================================================================
class Battle::Scene::PokemonDataBox < Sprite
  # Override refresh_hp to animate if dynamic combat is on, else instant
  alias original_refresh_hp refresh_hp
  def refresh_hp
    return if !@battler
    # If HP animation is already running, don't interrupt it
    return if animating_hp?

    if $PokemonSystem.dynamic_combat == 1
      # Set up animation from current displayed HP to actual HP
      current_displayed_hp = @anim_hp_current || @battler.hp
      @anim_hp_start = current_displayed_hp
      @anim_hp_end = @battler.hp
      @anim_hp_timer_start = System.uptime
      @anim_hp_current = current_displayed_hp
    else
      # Instant update
      original_refresh_hp
    end
  end

  # Override the HP animation to use faster speed if dynamic combat is on
  alias original_update_hp_animation update_hp_animation
  def update_hp_animation
    return if !animating_hp?
    # Use faster duration if dynamic combat is on (0.1 seconds instead of original 1.0)
    duration = ($PokemonSystem.dynamic_combat == 1) ? 0.1 : 1.0
    @anim_hp_current = lerp(@anim_hp_start, @anim_hp_end, duration,
                            @anim_hp_timer_start, System.uptime)
    original_refresh_hp
    if @anim_hp_current == @anim_hp_end
      if @anim_hp_start > @anim_hp_end
        triggers = ["BattlerHPReduced", @battler.species, *@battler.pokemon.types]
        if !@battler.fainted? && @battler.hasLowHP?
          triggers.push("BattlerHPCritical", @battler.species, *@battler.pokemon.types)
        end
        @battler.battle.pbDeluxeTriggers(@battler, nil, *triggers)
      elsif @anim_hp_start < @anim_hp_end
        triggers = ["BattlerHPRecovered", @battler.species, *@battler.pokemon.types]
        if @battler.hp == @battler.totalhp
          triggers.push("BattlerHPFull", @battler.species, *@battler.pokemon.types)
        end
        @battler.battle.pbDeluxeTriggers(@battler, nil, *triggers)
      end
      @anim_hp_start = nil
      @anim_hp_end = nil
      @anim_hp_timer_start = nil
      @anim_hp_current = nil
    end
  end

  def animating_hp?
    return !@anim_hp_start.nil?
  end

end

class Battle::Scene
  # Override HP change method to use faster animation
  alias original_pbHPChanged pbHPChanged
  def pbHPChanged(battler, oldHP, anim = false)
    # If animation is disabled, just refresh and return
    if !anim
      databox = @sprites["dataBox_#{battler.index}"]
      databox.refresh if databox
      return
    end

    # Set up HP animation on the databox
    databox = @sprites["dataBox_#{battler.index}"]
    databox.instance_variable_set(:@anim_hp_start, oldHP)
    databox.instance_variable_set(:@anim_hp_end, battler.hp)
    databox.instance_variable_set(:@anim_hp_timer_start, System.uptime)

    # Animation loop using the faster databox animation
    loop do
      databox.update_hp_animation
      pbUpdate(nil)
      break if !databox.animating_hp?
    end
  end
end
