#===============================================================================
# [VERMEIL] Fast Status Animations
# 003_Status_Effects_Skip.rb
#
# Overrides Battler#pbInflictStatus, pbRaiseStatStage, and
# pbLowerStatStage to skip their pbCommonAnimation calls.
#===============================================================================

class Battle::Battler
  alias_method :_vermeil_fast_status_orig_pbInflictStatus, :pbInflictStatus
  def pbInflictStatus(newStatus, newStatusCount = 0, msg = nil, user = nil)
    self.status      = newStatus
    self.statusCount = newStatusCount
    @battle.pbDisplay(msg) if msg
  end

  alias_method :_vermeil_fast_status_orig_pbRaiseStatStage, :pbRaiseStatStage
  def pbRaiseStatStage(stat, increment, user, showAnim = true, ignoreContrary = false)
    increment = pbRaiseStatStageBasic(stat, increment, ignoreContrary)
    return false if increment <= 0
    stat_name = GameData::Stat.get(stat).name
    if increment == 1
      @battle.pbDisplay(_INTL("¡{1} subió su {2}!", pbThis, stat_name))
    else
      @battle.pbDisplay(_INTL("¡{1} subió mucho su {2}!", pbThis, stat_name))
    end
    true
  end

  alias_method :_vermeil_fast_status_orig_pbLowerStatStage, :pbLowerStatStage
  def pbLowerStatStage(stat, increment, user, showAnim = true, ignoreContrary = false)
    increment = pbLowerStatStageBasic(stat, increment, ignoreContrary)
    return false if increment <= 0
    stat_name = GameData::Stat.get(stat).name
    if increment == 1
      @battle.pbDisplay(_INTL("¡{1} bajó su {2}!", pbThis, stat_name))
    else
      @battle.pbDisplay(_INTL("¡{1} bajó mucho su {2}!", pbThis, stat_name))
    end
    true
  end
end
