#===============================================================================
#
#===============================================================================
class Battle::AI
  attr_reader :battle
  attr_reader :trainer
  attr_reader :battlers
  attr_reader :user, :target, :move

  def initialize(battle)
    @battle = battle
  end

  def create_ai_objects
    # Initialize AI trainers
    @trainers = [[], []]
    @battle.player.each_with_index do |trainer, i|
      @trainers[0][i] = AITrainer.new(self, 0, i, trainer)
    end
    if @battle.wildBattle?
      @trainers[1][0] = AITrainer.new(self, 1, 0, nil)
    else
      @battle.opponent.each_with_index do |trainer, i|
        @trainers[1][i] = AITrainer.new(self, 1, i, trainer)
      end
    end
    # Initialize AI battlers
    @battlers = []
    @battle.battlers.each_with_index do |battler, i|
      @battlers[i] = AIBattler.new(self, i) if battler
    end
    # Initialize AI move object
    @move = AIMove.new(self)
  end

  # Set some class variables for the Pokémon whose action is being chosen
  def set_up(idxBattler)
    # Find the AI trainer choosing the action
    opposes = @battle.opposes?(idxBattler)
    trainer_index = @battle.pbGetOwnerIndexFromBattlerIndex(idxBattler)
    @trainer = @trainers[(opposes) ? 1 : 0][trainer_index]
    # Find the AI battler for which the action is being chosen
    @user = @battlers[idxBattler]
    @battlers.each { |b| b.refresh_battler if b }
  end

  # Choose an action.
  def pbDefaultChooseEnemyCommand(idxBattler)
    PBDebug.with_ai_logging do
      set_up(idxBattler)
      PBDebug.log_ai_decision("Turno #{@battle.turnCount + 1} | #{@user.name} (#{idxBattler}) | skill #{@trainer.skill} | HP #{@user.hp}/#{@user.totalhp} | estado #{@user.status}")
      ret = false
      PBDebug.logonerr { ret = pbChooseToSwitchOut }
      if ret
        PBDebug.log_ai_decision("Cambio registrado; tiene prioridad sobre objetos y movimientos.")
        PBDebug.log("")
        return
      end
      ret = false
      PBDebug.logonerr { ret = pbChooseToUseItem }
      if ret
        PBDebug.log_ai_decision("Objeto registrado; tiene prioridad sobre movimientos.")
        PBDebug.log("")
        return
      end
      PBDebug.log_ai_decision("Sin cambio ni objeto registrado; se evalua atacar.")
      if @battle.pbAutoFightMenu(idxBattler)
        PBDebug.log_ai_decision("Accion resuelta por el modo de combate automatico.")
        PBDebug.log("")
        return
      end
      @battle.pbRegisterMegaEvolution(idxBattler) if pbEnemyShouldMegaEvolve?
      choices = pbGetMoveScores
      pbChooseMove(choices)
      PBDebug.log("")
    end
  end

  # Choose a replacement Pokémon (called directly from @battle, not part of
  # action choosing). Must return the party index of a replacement Pokémon if
  # possible.
  def pbDefaultChooseNewEnemy(idxBattler)
    PBDebug.with_ai_logging do
      set_up(idxBattler)
      PBDebug.log_ai_decision("Relevo para #{@user.name} (#{idxBattler}) | skill #{@trainer.skill}")
      idxParty = choose_best_replacement_pokemon(idxBattler, true)
      if idxParty >= 0
        pkmn = @battle.pbParty(idxBattler)[idxParty]
        PBDebug.log_ai_decision("Relevo elegido: #{pkmn.name} (party #{idxParty}).") if pkmn
      else
        PBDebug.log_ai_decision("No hay relevo valido.")
      end
      idxParty
    end
  end
end

#===============================================================================
#
#===============================================================================
module Battle::AI::Handlers
  MoveFailureCheck              = HandlerHash.new
  MoveFailureAgainstTargetCheck = HandlerHash.new
  MoveEffectScore               = HandlerHash.new
  MoveEffectAgainstTargetScore  = HandlerHash.new
  MoveBasePower                 = HandlerHash.new
  GeneralMoveScore              = HandlerHash.new
  GeneralMoveAgainstTargetScore = HandlerHash.new
  ShouldSwitch                  = HandlerHash.new
  ShouldNotSwitch               = HandlerHash.new
  AbilityRanking                = AbilityHandlerHash.new
  ItemRanking                   = ItemHandlerHash.new

  module_function

  def move_will_fail?(function_code, *args)
    ret = MoveFailureCheck.trigger(function_code, *args)
    PBDebug.log_ai_decision("Fallo previsto por function code #{function_code}.") if ret
    return ret || false
  end

  def move_will_fail_against_target?(function_code, *args)
    ret = MoveFailureAgainstTargetCheck.trigger(function_code, *args)
    PBDebug.log_ai_decision("Fallo previsto contra el objetivo por function code #{function_code}.") if ret
    return ret || false
  end

  def apply_move_effect_score(function_code, score, *args)
    ret = MoveEffectScore.trigger(function_code, score, *args)
    return (ret.nil?) ? score : ret
  end

  def apply_move_effect_against_target_score(function_code, score, *args)
    ret = MoveEffectAgainstTargetScore.trigger(function_code, score, *args)
    return (ret.nil?) ? score : ret
  end

  def get_base_power(function_code, power, *args)
    ret = MoveBasePower.trigger(function_code, power, *args)
    return (ret.nil?) ? power : ret
  end

  def apply_general_move_score_modifiers(score, *args)
    GeneralMoveScore.each do |id, score_proc|
      new_score = score_proc.call(score, *args)
      if new_score && PBDebug.ai_logging?
        PBDebug.log_score_change(new_score - score, "[TRACE] regla #{id}: #{score} -> #{new_score}")
      end
      score = new_score if new_score
    end
    return score
  end

  def apply_general_move_against_target_score_modifiers(score, *args)
    GeneralMoveAgainstTargetScore.each do |id, score_proc|
      new_score = score_proc.call(score, *args)
      if new_score && PBDebug.ai_logging?
        PBDebug.log_score_change(new_score - score, "[TRACE] regla #{id}: #{score} -> #{new_score}")
      end
      score = new_score if new_score
    end
    return score
  end

  def should_switch?(*args)
    ret = false
    ShouldSwitch.each do |id, switch_proc|
      ret ||= switch_proc.call(*args)
      PBDebug.log_ai_decision("Cambio recomendado por regla #{id}.") if ret
      break if ret
    end
    PBDebug.log_ai_decision("Ninguna regla recomienda cambiar.") if !ret
    return ret
  end

  def should_not_switch?(*args)
    ret = false
    ShouldNotSwitch.each do |id, switch_proc|
      ret ||= switch_proc.call(*args)
      PBDebug.log_ai_decision("Cambio vetado por regla #{id}.") if ret
      break if ret
    end
    return ret
  end

  def modify_ability_ranking(ability, score, *args)
    ret = AbilityRanking.trigger(ability, score, *args)
    return (ret.nil?) ? score : ret
  end

  def modify_item_ranking(item, score, *args)
    ret = ItemRanking.trigger(item, score, *args)
    return (ret.nil?) ? score : ret
  end
end
