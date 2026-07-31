#===============================================================================
# AI Improvements — Handlers aditivos de scoring de la IA
# Creado por vlxj97 y modificado por DPertierra
#===============================================================================
# Handlers de scoring que cierran huecos del core, sobre todo para entrenadores
# con ScoreMoves pero SIN PredictMoveFailure (los MoveFailureCheck del core solo
# corren con ese flag). Todo es aditivo (Handlers::*.add): no toca métodos del
# core. Los parches de comportamiento (switch, item, mega, bugs Spikes/Encore)
# viven editados in-place en 003_AI_Switch, 004_AI_UseItem, 005_AI_MegaEvolve,
# 033_AI MoveEffects/002 y 010. Este archivo carga tras el resto de 032_AI (099),
# así que las clases Battle::AI/AIMove/AIBattler ya existen.
#
# NOTA sobre conocimiento: igual que todo el core AI, estos handlers leen la
# habilidad real y el moveset completo del rival (no existe fog-of-war en el
# motor). Es consistente con cómo puntúa el core en todas partes.
#===============================================================================

module AIImprovements
  #-----------------------------------------------------------------------------
  # Function codes de movimientos puros que infligen estado primario permanente.
  # Excluye ConfuseTarget/AttractTarget (volátiles en effects[], no en status).
  STATUS_INFLICTING_CODES = [
    "SleepTarget", "SleepTargetIfUserDarkrai",
    "SleepTargetChangeUserMeloettaForm", "SleepTargetNextTurn",
    "PoisonTarget", "BadPoisonTarget",
    "PoisonTargetLowerTargetSpeed1",
    "PoisonTargetRemoveUserBindingAndEntryHazards",
    "ParalyzeTarget", "ParalyzeTargetIfNotTypeImmune",
    "ParalyzeTargetAlwaysHitsInRain",
    "ParalyzeTargetAlwaysHitsInRainHitsTargetInSky",
    "BurnTarget", "BurnTargetAlwaysHitsInRain",
    "FreezeTarget", "FreezeTargetSuperEffectiveAgainstWater",
    "FreezeTargetAlwaysHitsInHail"
  ].freeze

  # Subset de estado puro veneno/quemadura (Handlers C y D).
  POISON_BURN_PURE_CODES = [
    "PoisonTarget", "PoisonTargetLowerTargetSpeed1",
    "PoisonTargetRemoveUserBindingAndEntryHazards",
    "BadPoisonTarget",
    "BurnTarget", "BurnTargetAlwaysHitsInRain"
  ].freeze

  # Handler C — umbrales de HP para penalizar status con target agonizante.
  STATUS_HP_LOW      = 25
  STATUS_HP_CRITICAL = 15
  LOW_HP_PENALTY     = 15
  RESIDUAL_PENALTY   = 8

  #-----------------------------------------------------------------------------
  # Handler E — diminishing returns consciente del incremento.
  # Tabla +2/+3: el core no penaliza estos (su -10 plano es solo para +1).
  BOOST_PENALTY_PLUS2_BY_STAGE = [0, 0, 10, 10, 22, 22].freeze
  # Tabla +1: el core ya resta -10 plano en stages >=2; solo extra en 4-5.
  BOOST_PENALTY_PLUS1_BY_STAGE = [0, 0, 0, 0, 12, 12].freeze

  # Handler F — bonus contextual (requiere HPAware).
  BOOST_BONUS_HIGH_HP   = 8
  BOOST_BONUS_SPEED     = 6
  BOOST_BONUS_RIVAL_LOW = 6
  BOOST_BONUS_MAX       = 15

  # Function codes que suben stat stages del PROPIO user. El guard por este set
  # DEBE ir antes de tocar move.move.statUp (statUp solo existe en estas clases).
  BOOST_USER_STAT_CODES = %w[
    RaiseUserAttack1 RaiseUserAttack2 RaiseUserAttack3
    RaiseUserDefense1 RaiseUserDefense1CurlUpUser RaiseUserDefense2 RaiseUserDefense3
    RaiseUserSpAtk1 RaiseUserSpAtk2 RaiseUserSpAtk3
    RaiseUserSpDef1 RaiseUserSpDef1PowerUpElectricMove RaiseUserSpDef2 RaiseUserSpDef3
    RaiseUserSpeed1 RaiseUserSpeed2 RaiseUserSpeed2LowerUserWeight RaiseUserSpeed3
    RaiseUserAccuracy1 RaiseUserAccuracy2 RaiseUserAccuracy3
    RaiseUserEvasion1 RaiseUserEvasion2 RaiseUserEvasion2MinimizeUser RaiseUserEvasion3
    RaiseUserAtkDef1 RaiseUserAtkDefSpd1 RaiseUserAtkDefAcc1
    RaiseUserAtkSpAtk1 RaiseUserAtkSpAtk1Or2InSun
    RaiseUserAtkSpd1 RaiseUserAtkSpd1RemoveEntryHazardsAndSubstitutes
    RaiseUserAtk1Spd2 RaiseUserAtkAcc1
    RaiseUserDefSpDef1 RaiseUserSpAtkSpDef1
    RaiseUserSpAtkSpDef1CureStatus RaiseUserSpAtkSpDefSpd1
    RaiseUserMainStats1 RaiseUserMainStats1LoseThirdOfTotalHP RaiseUserMainStats1TrapUserInBattle
    RaiseUserAtkSpAtkSpeed2LoseHalfOfTotalHP
    MaxUserAttackLoseHalfOfTotalHP
    RaiseUserStatDependingOnCommander1
    LowerUserDefSpDef1RaiseUserAtkSpAtkSpd2
    RaisePlusMinusUserAndAlliesAtkSpAtk1 RaisePlusMinusUserAndAlliesDefSpDef1
  ].freeze

  #-----------------------------------------------------------------------------
  # Handler G — choice-lock en movimiento inefectivo -> inducir switch.
  CHOICE_LOCK_MIN_DAMAGE_PCT = 10

  #-----------------------------------------------------------------------------
  # Handler H — clima con abusadores en reserva. Nombres confirmados en el PBS.
  WEATHER_MOVE_TO_WEATHER = {
    "StartSunWeather"       => :Sun,
    "StartRainWeather"      => :Rain,
    "StartSandstormWeather" => :Sandstorm,
    "StartHailWeather"      => :Hail,
    "StartSnowstormWeather" => :Snowstorm
  }.freeze

  WEATHER_ABUSER_ABILITIES = {
    :Sun       => [:CHLOROPHYLL, :FLOWERGIFT, :FORECAST, :HARVEST, :LEAFGUARD,
                   :SOLARPOWER, :PROTOSYNTHESIS, :ORICHALCUMPULSE],
    :Rain      => [:DRYSKIN, :FORECAST, :HYDRATION, :RAINDISH, :SWIFTSWIM],
    :Sandstorm => [:SANDFORCE, :SANDRUSH, :SANDVEIL],
    :Hail      => [:FORECAST, :ICEBODY, :SLUSHRUSH, :SNOWCLOAK, :ICEFACE],
    :Snowstorm => [:FORECAST, :ICEBODY, :SLUSHRUSH, :SNOWCLOAK, :ICEFACE]
  }.freeze

  WEATHER_BONUS_PER_ABUSER   = 4
  WEATHER_BONUS_MAX_RESERVES = 10

  #-----------------------------------------------------------------------------
  # Handlers I/J — anticipar pivotes del rival.
  # USER se retira él mismo (excluye SwitchOutTarget*, que fuerzan salir al rival).
  PIVOT_FUNCTION_CODES = %w[
    SwitchOutUserDamagingMove
    SwitchOutUserStatusMove
    SwitchOutUserPassOnEffects
    LowerTargetAtkSpAtk1SwitchOutUser
    StartSnowstormWeatherSwitchOutUser
    UserMakeSubstituteSwitchOut
  ].freeze

  HAZARD_FUNCTION_CODES = %w[
    AddSpikesToFoeSide
    AddToxicSpikesToFoeSide
    AddStealthRocksToFoeSide
    AddStickyWebToFoeSide
  ].freeze

  PIVOT_STATUS_PENALTY = 7
  PIVOT_HAZARD_BONUS   = 6

  #-----------------------------------------------------------------------------
  # Candidato 2 — Destiny Bond proactivo (Handler O).
  DB_PROACTIVE_CRITICAL        = 60
  DB_PROACTIVE_FAST_BONUS      = 20
  DB_PROACTIVE_SLOW_PENALTY    = 10
  DB_PROACTIVE_LOW             = 30
  DB_PROACTIVE_HEALTHY_PENALTY = 40
  DB_PROACTIVE_RIVAL_BOOSTED   = 15

  # Ajuste (puede ser negativo) para Destiny Bond proactivo. faster_than? respeta
  # Trick Room. Si vamos primeros, activamos DB y luego morimos -> conecta; si
  # vamos últimos y estamos a punto de morir, nos noquean antes de usarlo.
  def self.proactive_destiny_bond_bonus(user, rival)
    hp_pct = user.hp.to_f / user.totalhp
    moves_first = user.faster_than?(rival)
    bonus = 0
    if hp_pct <= 0.25
      bonus += DB_PROACTIVE_CRITICAL
      bonus += moves_first ? DB_PROACTIVE_FAST_BONUS : -DB_PROACTIVE_SLOW_PENALTY
    elsif hp_pct <= 0.40
      bonus += DB_PROACTIVE_LOW
    else
      bonus -= DB_PROACTIVE_HEALTHY_PENALTY
    end
    bonus += DB_PROACTIVE_RIVAL_BOOSTED if rival.stages.values.sum >= 3
    bonus
  end

  # ¿Tiene el usuario un movimiento de daño usable que mataría al rival? rough_damage
  # está acoplado a @ai.target; en un GeneralMoveScore no está montado. Lo fijamos al
  # rival y restauramos con ensure (junto a moldBreaker). AIMoves independientes para
  # no mutar @ai.@move.
  def self.user_can_faint_rival?(ai, user, rival)
    orig_target = ai.target
    orig_mold   = ai.battle.moldBreaker
    begin
      ai.instance_variable_set(:@target, rival)
      user.battler.moves.any? do |m|
        next false if m.nil? || m.pp == 0 || !m.damagingMove?
        aim = Battle::AI::AIMove.new(ai)
        aim.set_up(m)
        aim.rough_damage >= rival.hp
      end
    ensure
      ai.instance_variable_set(:@target, orig_target)
      ai.battle.moldBreaker = orig_mold
    end
  end

  #-----------------------------------------------------------------------------
  # Candidato 3 — Sucker Punch Risk (Handler P).
  SUCKER_RATIO_HIGH_PENALTY = 40
  SUCKER_RATIO_MID_PENALTY  = 20
  SUCKER_PROTECT_PENALTY    = 15

  # Auto-Protect del rival (excluye ProtectUserSide* y Endure).
  PROTECT_FUNCTION_CODES = [
    "ProtectUser",
    "ProtectUserBanefulBunker",
    "ProtectUserFromDamagingMovesBurningBulwark",
    "ProtectUserFromDamagingMovesKingsShield",
    "ProtectUserFromDamagingMovesObstruct",
    "ProtectUserFromDamagingMovesSilkTrap",
    "ProtectUserFromTargetingMovesSpikyShield"
  ].freeze

  # Ajuste basado solo en el moveset conocido del rival (sin datos de HP: el core
  # ya pondera el HP en sentido opuesto en su handler FailsIfTargetActed).
  def self.sucker_punch_delta(target)
    moves = target.battler.moves
    total = moves.length
    return 0 if total == 0
    status_ratio = moves.count(&:statusMove?).to_f / total
    delta = 0
    if status_ratio >= 0.5
      delta -= SUCKER_RATIO_HIGH_PENALTY
    elsif status_ratio >= 0.25
      delta -= SUCKER_RATIO_MID_PENALTY
    end
    delta -= SUCKER_PROTECT_PENALTY if moves.any? { |m| PROTECT_FUNCTION_CODES.include?(m.function_code) }
    delta
  end

  #-----------------------------------------------------------------------------
  # Candidato 4 — Contact Punishment (Handler Q). Recoil como % del HP actual del
  # usuario (su propio HP, siempre conocido -> no requiere HPAware).
  CONTACT_RECOIL_LETHAL = 80
  CONTACT_RECOIL_HIGH   = 40
  CONTACT_RECOIL_MID    = 20
  CONTACT_RECOIL_LOW    = 10

  CONTACT_FLAMEBODY_PHYSICAL = 25
  CONTACT_FLAMEBODY_OTHER    = 10
  CONTACT_STATIC_FAST        = 20
  CONTACT_STATIC_SLOW        = 8
  CONTACT_POISONPOINT        = 10
  CONTACT_GOOEY              = 10
  CONTACT_CUTECHARM          = 20
  CONTACT_EFFECTSPORE        = 15

  # Penalización total por contacto contra las habilidades del target. Respeta
  # Mold Breaker (ignora las habilidades del rival).
  def self.contact_punishment_penalty(user, target, move)
    return 0 if user.has_mold_breaker?
    penalty = 0
    penalty += contact_recoil_penalty(user) if target.has_active_ability?([:ROUGHSKIN, :IRONBARBS])
    penalty += contact_status_ability_penalty(user, target, move) if user.status == :NONE
    penalty += CONTACT_GOOEY if target.has_active_ability?([:GOOEY, :TANGLINGHAIR])
    # Cute Charm: pbCanAttract? resuelve género, ya-enamorado y Aroma Veil/Oblivious.
    # No va bajo el guard user.status (la infatuación no es un status mayor).
    if target.has_active_ability?(:CUTECHARM) && user.battler.pbCanAttract?(target.battler, false)
      penalty += CONTACT_CUTECHARM
    end
    penalty += contact_effect_spore_penalty(user, target) if target.has_active_ability?(:EFFECTSPORE)
    penalty
  end

  # Effect Spore escalado por nº de estados aún aplicables (valor esperado del 30%/1-de-3).
  def self.contact_effect_spore_penalty(user, target)
    return 0 unless user.battler.affectedByPowder?
    applicable = [user.battler.pbCanSleep?(target.battler, false),
                  user.battler.pbCanPoison?(target.battler, false),
                  user.battler.pbCanParalyze?(target.battler, false)].count(true)
    return 0 if applicable == 0
    CONTACT_EFFECTSPORE * applicable / 3
  end

  # Habilidades que infligen estado por contacto (solo si user.status == :NONE, validado por el llamador).
  def self.contact_status_ability_penalty(user, target, move)
    penalty = 0
    penalty += move.physicalMove? ? CONTACT_FLAMEBODY_PHYSICAL : CONTACT_FLAMEBODY_OTHER if target.has_active_ability?(:FLAMEBODY)
    penalty += user.faster_than?(target) ? CONTACT_STATIC_FAST : CONTACT_STATIC_SLOW if target.has_active_ability?(:STATIC)
    penalty += CONTACT_POISONPOINT if target.has_active_ability?(:POISONPOINT)
    penalty
  end

  # Recoil de Rough Skin/Iron Barbs (1/8 HP máx) como % del HP actual.
  def self.contact_recoil_penalty(user)
    recoil = user.totalhp / 8
    pct = recoil * 100.0 / [user.hp, 1].max
    return CONTACT_RECOIL_LETHAL if pct >= 100
    return CONTACT_RECOIL_HIGH   if pct >= 50
    return CONTACT_RECOIL_MID    if pct >= 25
    CONTACT_RECOIL_LOW
  end

  #-----------------------------------------------------------------------------
  # Candidato 5 — Guts/Marvel Scale/Quick Feet (Handler R).
  GUTS_PENALTY        = 60
  MARVELSCALE_PENALTY = 40
  QUICKFEET_PENALTY   = 30

  #-----------------------------------------------------------------------------
  # Candidato 6 — Poison Heal (Handler T). Subconjunto que inflige VENENO.
  POISON_INFLICTING_CODES = [
    "PoisonTarget", "BadPoisonTarget",
    "PoisonTargetLowerTargetSpeed1",
    "PoisonTargetRemoveUserBindingAndEntryHazards"
  ].freeze
  POISON_HEAL_PENALTY = 60

  #-----------------------------------------------------------------------------
  # Reverse Abilities Defiant/Competitive (Handler N).
  DEFIANT_PENALTY     = 45
  COMPETITIVE_PENALTY = 45

  #-----------------------------------------------------------------------------
  # Unburden (Handler S).
  UNBURDEN_TRIGGER_CODES = %w[RemoveTargetItem DestroyTargetBerryOrGem UserTargetSwapItems].freeze
  UNBURDEN_PENALTY       = 55

  #-----------------------------------------------------------------------------
  # Handler V — habilidades snowball (boost de stat al noquear).
  SNOWBALL_ABILITIES = %i[
    MOXIE BEASTBOOST CHILLINGNEIGH GRIMNEIGH ASONECHILLINGNEIGH ASONEGRIMNEIGH
  ].freeze
  SNOWBALL_BONUS_KO              = 15
  SNOWBALL_SETUP_PENALTY         = 12
  SNOWBALL_HP_DANGER_THRESHOLD   = 0.35
  SNOWBALL_MIN_DAMAGE            = 0.20
  SNOWBALL_BONUS_ALREADY_BOOSTED = 12

  #-----------------------------------------------------------------------------
  # Mec.2 (choose_best_replacement_pokemon, editado in-place en 003_AI_Switch).
  SWITCH_MIN_IMPROVEMENT = 15
end

#===============================================================================
# Handler A: no infligir estado primario a un objetivo que ya tiene uno.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:dont_status_already_statused_target,
  proc { |score, move, user, target, ai, battle|
    next score unless move.statusMove?
    # GiveUserStatusToTarget (Psycho Shift): penalizar solo si el target ya tiene
    # estado Y el user tiene uno que transferir (si no, ya falla por su MoveFailureCheck).
    if move.function_code == "GiveUserStatusToTarget"
      if target.status != :NONE && user.status != :NONE
        next Battle::AI::MOVE_USELESS_SCORE
      end
      next score
    end
    if AIImprovements::STATUS_INFLICTING_CODES.include?(move.function_code) &&
       target.status != :NONE
      next Battle::AI::MOVE_USELESS_SCORE
    end
    next score
  }
)

#===============================================================================
# Handler B: no usar hazards de entrada ya colocados al máximo.
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:dont_add_maxed_hazards,
  proc { |score, move, user, ai, battle|
    opp = user.pbOpposingSide
    case move.function_code
    when "AddSpikesToFoeSide"
      next Battle::AI::MOVE_USELESS_SCORE if opp.effects[PBEffects::Spikes] >= 3
    when "AddToxicSpikesToFoeSide"
      next Battle::AI::MOVE_USELESS_SCORE if opp.effects[PBEffects::ToxicSpikes] >= 2
    when "AddStealthRocksToFoeSide"
      next Battle::AI::MOVE_USELESS_SCORE if opp.effects[PBEffects::StealthRock]
    when "AddStickyWebToFoeSide"
      next Battle::AI::MOVE_USELESS_SCORE if opp.effects[PBEffects::StickyWeb]
    end
    next score
  }
)

#===============================================================================
# Handler C: status inútil con HP bajo del target (requiere HPAware).
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:status_useless_on_low_hp_target,
  proc { |score, move, user, target, ai, battle|
    next score unless ai.trainer.has_skill_flag?("HPAware")
    next score unless move.statusMove?
    next score unless AIImprovements::POISON_BURN_PURE_CODES.include?(move.function_code)
    # Si el user no tiene ningún movimiento de daño, el status puede ser su única opción.
    has_damaging = false
    user.battler.eachMoveWithIndex { |m, _i| has_damaging = true if m.damagingMove? }
    next score unless has_damaging
    hp_pct = target.hp.to_f / target.totalhp * 100
    next Battle::AI::MOVE_USELESS_SCORE if hp_pct < AIImprovements::STATUS_HP_CRITICAL
    score -= AIImprovements::LOW_HP_PENALTY if hp_pct < AIImprovements::STATUS_HP_LOW
    next score
  }
)

#===============================================================================
# Handler D: status redundante con daño residual ya activo (LeechSeed + burn/poison).
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:redundant_status_with_residual,
  proc { |score, move, user, target, ai, battle|
    next score unless move.statusMove?
    next score unless AIImprovements::POISON_BURN_PURE_CODES.include?(move.function_code)
    has_leech           = target.effects[PBEffects::LeechSeed] >= 0
    has_residual_status = [:POISON, :BURN].include?(target.status)
    next score if has_leech && !has_residual_status
    score -= AIImprovements::RESIDUAL_PENALTY if has_leech && has_residual_status
    next score
  }
)

#===============================================================================
# Handler E: diminishing returns en boosts del user.
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:boost_diminishing_returns,
  proc { |score, move, user, ai, battle|
    next score unless AIImprovements::BOOST_USER_STAT_CODES.include?(move.function_code)
    stat_ups = move.move.statUp
    next score if stat_ups.nil? || stat_ups.empty?
    max_penalty = 0
    stat_ups.each_slice(2) do |stat, inc|
      stage = (user.stages[stat] || 0).clamp(0, 5)   # stage 6 lo gestiona el core
      table = (inc >= 2) ? AIImprovements::BOOST_PENALTY_PLUS2_BY_STAGE
                         : AIImprovements::BOOST_PENALTY_PLUS1_BY_STAGE
      max_penalty = [max_penalty, table[stage]].max
    end
    score -= max_penalty
    next score
  }
)

#===============================================================================
# Handler F: bonus contextual para hacer setup cuando es favorable (requiere HPAware).
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:favorable_setup_bonus,
  proc { |score, move, user, ai, battle|
    next score unless ai.trainer.has_skill_flag?("HPAware")
    next score unless AIImprovements::BOOST_USER_STAT_CODES.include?(move.function_code)
    stat_ups = move.move.statUp
    next score if stat_ups.nil? || stat_ups.empty?
    next score unless stat_ups.each_slice(2).all? { |stat, _inc| (user.stages[stat] || 0) <= 1 }
    rival = nil
    ai.each_foe_battler(user.idxOwnSide) { |b, _i| rival ||= b }
    next score if rival.nil?
    bonus = 0
    bonus += AIImprovements::BOOST_BONUS_HIGH_HP   if user.hp.to_f / user.totalhp > 0.70
    bonus += AIImprovements::BOOST_BONUS_SPEED     if user.faster_than?(rival)
    bonus += AIImprovements::BOOST_BONUS_RIVAL_LOW if rival.hp.to_f / rival.totalhp < 0.50
    score += [bonus, AIImprovements::BOOST_BONUS_MAX].min
    next score
  }
)

#===============================================================================
# Handler G: choice-lock en movimiento inefectivo -> inducir switch.
#===============================================================================
# Hunde el score del movimiento bloqueado-inefectivo a MOVE_USELESS_SCORE para que
# el fallback de switch forzado del core (pbChooseMove: max_score <= USELESS ->
# pbChooseToSwitchOut(true)) actúe. GeneralMoveScore corre el último, tras los
# modificadores, así que el suelo no se revierte al alza.
Battle::AI::Handlers::GeneralMoveScore.add(:choice_lock_ineffective_move,
  proc { |score, move, user, ai, battle|
    locked_move_id = user.effects[PBEffects::ChoiceBand]
    next score if !locked_move_id
    next score if move.id != locked_move_id
    next score unless move.damagingMove?
    target = ai.target
    next score if !target || !target.opposes?(user)
    threshold = target.totalhp * AIImprovements::CHOICE_LOCK_MIN_DAMAGE_PCT / 100.0
    next score if move.rough_damage >= threshold
    next [score, Battle::AI::MOVE_USELESS_SCORE].min
  }
)

#===============================================================================
# Handler H: incentivar poner clima si hay abusadores en reserva.
#===============================================================================
# Complementa al core (que solo mira los activos). Añade el factor "reservas".
Battle::AI::Handlers::GeneralMoveScore.add(:weather_with_abuser_in_reserves,
  proc { |score, move, user, ai, battle|
    weather = AIImprovements::WEATHER_MOVE_TO_WEATHER[move.function_code]
    next score if !weather
    next score unless ai.trainer.medium_skill?
    next score if battle.pbCheckGlobalAbility(:AIRLOCK) ||
                  battle.pbCheckGlobalAbility(:CLOUDNINE)
    # Clima redundante o primario que no se puede sobrescribir: no sumar bonus.
    next score if [:HarshSun, :HeavyRain, :StrongWinds,
                   move.move.weatherType].include?(battle.field.weather)
    abusers = AIImprovements::WEATHER_ABUSER_ABILITIES[weather]
    next score if !abusers || abusers.empty?
    on_field = battle.allSameSideBattlers(user.idxOwnSide, true).map { |b| b.pokemonIndex }
    abuser_reserves = 0
    battle.pbParty(user.idxOwnSide).each_with_index do |pkmn, i|
      next if !pkmn || !pkmn.able? || on_field.include?(i)
      next if [:Sun, :Rain].include?(weather) && pkmn.hasItem?(:UTILITYUMBRELLA)
      abuser_reserves += 1 if abusers.include?(pkmn.ability_id)
    end
    next score if abuser_reserves == 0
    bonus = [abuser_reserves * AIImprovements::WEATHER_BONUS_PER_ABUSER,
             AIImprovements::WEATHER_BONUS_MAX_RESERVES].min
    score += bonus
    next score
  }
)

#===============================================================================
# Handler I: penalizar status si el activo rival puede pivotar.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:status_vs_pivoting_rival,
  proc { |score, move, user, target, ai, battle|
    next score unless ai.trainer.medium_skill?
    next score unless move.statusMove?
    next score unless AIImprovements::STATUS_INFLICTING_CODES.include?(move.function_code)
    next score if target.status != :NONE               # Handler A ya lo hunde
    next score if score <= Battle::AI::MOVE_USELESS_SCORE   # no apilar bajo el suelo
    has_damaging = false
    user.battler.eachMoveWithIndex { |m, _i| has_damaging = true if m.damagingMove? }
    next score unless has_damaging
    if target.battler.moves.any? { |m| AIImprovements::PIVOT_FUNCTION_CODES.include?(m.function_code) }
      score -= AIImprovements::PIVOT_STATUS_PENALTY
    end
    next score
  }
)

#===============================================================================
# Handler J: bonificar hazards si el activo rival puede pivotar.
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:hazards_vs_pivoting_rival,
  proc { |score, move, user, ai, battle|
    next score unless ai.trainer.medium_skill?
    next score unless AIImprovements::HAZARD_FUNCTION_CODES.include?(move.function_code)
    foe_has_pivot = battle.allOtherSideBattlers(user.index).any? do |b|
      b.moves.any? { |m| AIImprovements::PIVOT_FUNCTION_CODES.include?(m.function_code) }
    end
    score += AIImprovements::PIVOT_HAZARD_BONUS if foe_has_pivot
    next score
  }
)

#===============================================================================
# Handler M: Drenadoras (Leech Seed) redundante.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:redundant_leech_seed,
  proc { |score, move, user, target, ai, battle|
    next score unless move.function_code == "StartLeechSeedTarget"
    next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::LeechSeed] >= 0
    next score
  }
)

#===============================================================================
# Handler N: no bajar stats a rivales con Defiant / Competitive.
#===============================================================================
# Guard statusMove? imprescindible: hay muchos moves de DAÑO con code LowerTarget*
# (Fuerza Lunar, Triturar, Onda Certera...); sin él se hundirían esos ataques.
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:reverse_ability_defiant_competitive,
  proc { |score, move, user, target, ai, battle|
    next score unless move.statusMove?
    next score unless move.function_code.start_with?("LowerTarget")
    next score - AIImprovements::DEFIANT_PENALTY     if target.has_active_ability?(:DEFIANT)
    next score - AIImprovements::COMPETITIVE_PENALTY if target.has_active_ability?(:COMPETITIVE)
    next score
  }
)

#===============================================================================
# Handler O: priorizar Destiny Bond cuando vamos a morir (juego proactivo).
#===============================================================================
# Guard: si ya tenemos un golpe que mata al rival, preferimos GANAR atacando (1-por-0)
# antes que el trade (1-por-1). El ajuste por velocidad va en proactive_destiny_bond_bonus.
Battle::AI::Handlers::GeneralMoveScore.add(:proactive_destiny_bond,
  proc { |score, move, user, ai, battle|
    next score unless ai.trainer.medium_skill?
    next score unless ai.trainer.has_skill_flag?("HPAware")
    next score unless move.id == :DESTINYBOND
    rival = nil
    ai.each_foe_battler(user.idxOwnSide) { |b, _i| rival ||= b }
    next score if rival.nil?
    next score if AIImprovements.user_can_faint_rival?(ai, user, rival)
    next score + AIImprovements.proactive_destiny_bond_bonus(user, rival)
  }
)

#===============================================================================
# Handler P: deprioritizar Sucker Punch si es probable que falle.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:sucker_punch_risk,
  proc { |score, move, user, target, ai, battle|
    next score unless ai.trainer.medium_skill?
    next score unless move.id == :SUCKERPUNCH
    next score + AIImprovements.sucker_punch_delta(target)
  }
)

#===============================================================================
# Handler Q: penalizar movimientos de contacto contra habilidades de represalia.
#===============================================================================
# contactMove?/punchingMove? viven en move.move (el Battle::Move subyacente).
# Respeta Long Reach, Protective Pads y Punching Glove.
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:contact_punishment,
  proc { |score, move, user, target, ai, battle|
    next score unless move.damagingMove?
    next score unless move.move.contactMove?
    next score if user.has_active_ability?(:LONGREACH)
    next score if user.has_active_item?(:PROTECTIVEPADS)
    next score if move.move.punchingMove? && user.has_active_item?(:PUNCHINGGLOVE)
    next score - AIImprovements.contact_punishment_penalty(user, target, move)
  }
)

#===============================================================================
# Handler R: no estatusar a rivales con Guts / Marvel Scale / Quick Feet.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:guts_marvel_scale_quickfeet_penalty,
  proc { |score, move, user, target, ai, battle|
    next score unless move.statusMove?
    next score unless AIImprovements::STATUS_INFLICTING_CODES.include?(move.function_code)
    next score - AIImprovements::GUTS_PENALTY        if target.has_active_ability?(:GUTS)
    next score - AIImprovements::MARVELSCALE_PENALTY if target.has_active_ability?(:MARVELSCALE)
    next score - AIImprovements::QUICKFEET_PENALTY   if target.has_active_ability?(:QUICKFEET)
    next score
  }
)

#===============================================================================
# Handler S: no activar el Unburden del rival quitándole el item.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:dont_trigger_rival_unburden,
  proc { |score, move, user, target, ai, battle|
    next score unless AIImprovements::UNBURDEN_TRIGGER_CODES.include?(move.function_code)
    next score unless target.has_active_ability?(:UNBURDEN)
    next score if !target.item || !target.item_active?
    next score - AIImprovements::UNBURDEN_PENALTY
  }
)

#===============================================================================
# Handler T: no envenenar a un rival con Poison Heal.
#===============================================================================
# Guard statusMove? imprescindible: "PoisonTarget" lo comparten Polvo Veneno (estado)
# y Bomba Lodo (daño, veneno secundario). Sin él se hundirían moves de daño.
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:poison_heal_penalty,
  proc { |score, move, user, target, ai, battle|
    next score unless move.statusMove?
    next score unless AIImprovements::POISON_INFLICTING_CODES.include?(move.function_code)
    next score unless target.has_active_ability?(:POISONHEAL)
    next score - AIImprovements::POISON_HEAL_PENALTY
  }
)

#===============================================================================
# Handler U: Fake Out (Sorpresa) solo sirve el primer turno.
#===============================================================================
# turnCount PRE-incremento: 0 en el primer turno en pista, >=1 después.
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:fake_out_only_first_turn,
  proc { |score, move, user, target, ai, battle|
    next score unless move.function_code == "FlinchTargetFailsIfNotUserFirstTurn"
    next Battle::AI::MOVE_USELESS_SCORE if user.turnCount > 0
    next score
  }
)

#===============================================================================
# Handler V: "Snowball" (Moxie / Beast Boost / habilidades Neigh) (requiere HPAware).
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:snowball_ability_priority,
  proc { |score, move, user, target, ai, battle|
    next score unless ai.trainer.has_skill_flag?("HPAware")
    next score unless move.damagingMove?
    next score unless target.has_active_ability?(AIImprovements::SNOWBALL_ABILITIES)
    dmg = move.rough_damage
    # (1) KO previsto: rematar evita el snowball. Refuerza el +15 del core.
    score += AIImprovements::SNOWBALL_BONUS_KO if dmg >= target.hp
    # (2) No mata pero lo deja en zona de peligro con golpe no trivial -> arriesgado.
    if dmg < target.hp &&
       target.hp.to_f / target.totalhp < AIImprovements::SNOWBALL_HP_DANGER_THRESHOLD &&
       dmg.to_f / target.totalhp > AIImprovements::SNOWBALL_MIN_DAMAGE
      score -= AIImprovements::SNOWBALL_SETUP_PENALTY
    end
    # (3) El rival ya tiene +1 o más en Atk/SpAtk: urge matarlo.
    if (target.stages[:ATTACK] || 0) >= 1 || (target.stages[:SPECIAL_ATTACK] || 0) >= 1
      score += AIImprovements::SNOWBALL_BONUS_ALREADY_BOOSTED
    end
    next score
  }
)

#===============================================================================
# Handler W: no re-aplicar un efecto de equipo/campo que ya está activo.
#===============================================================================
# Cada rama replica el guard de su MoveFailureCheck del core. Trick Room excluido
# (es un toggle, no una redundancia).
Battle::AI::Handlers::GeneralMoveScore.add(:side_or_field_effect_already_active,
  proc { |score, move, user, ai, battle|
    side = user.pbOwnSide
    case move.function_code
    when "StartUserSideDoubleSpeed"                    # Viento Afín/Tailwind
      next Battle::AI::MOVE_USELESS_SCORE if side.effects[PBEffects::Tailwind] > 0
    when "StartWeakenPhysicalDamageAgainstUserSide"   # Reflejo/Reflect
      next Battle::AI::MOVE_USELESS_SCORE if side.effects[PBEffects::Reflect] > 0
    when "StartWeakenSpecialDamageAgainstUserSide"    # Pantalla de Luz/Light Screen
      next Battle::AI::MOVE_USELESS_SCORE if side.effects[PBEffects::LightScreen] > 0
    when "StartWeakenDamageAgainstUserSideIfHail"     # Velo Aurora/Aurora Veil
      next Battle::AI::MOVE_USELESS_SCORE if side.effects[PBEffects::AuroraVeil] > 0
      next Battle::AI::MOVE_USELESS_SCORE if ![:Hail, :Snowstorm].include?(user.battler.effectiveWeather)
    when "StartUserSideImmunityToInflictedStatus"     # Velo Sagrado/Safeguard
      next Battle::AI::MOVE_USELESS_SCORE if side.effects[PBEffects::Safeguard] > 0
    when "StartUserSideImmunityToStatStageLowering"   # Neblina/Mist
      next Battle::AI::MOVE_USELESS_SCORE if side.effects[PBEffects::Mist] > 0
    when "UserMakeSubstitute"                          # Sustituto (volátil del user, no de lado)
      next Battle::AI::MOVE_USELESS_SCORE if user.effects[PBEffects::Substitute] > 0
    end
    next score
  }
)

#===============================================================================
# Handler X: no re-aplicar un efecto volátil de OBJETIVO ya activo.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:target_volatile_effect_already_active,
  proc { |score, move, user, target, ai, battle|
    case move.function_code
    when "DisableTargetLastMoveUsed"                   # Anulación/Disable
      next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::Disable] > 0
    when "DisableTargetUsingDifferentMove"             # Otra Vez/Encore
      next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::Encore] > 0
    when "DisableTargetStatusMoves"                    # Mofa/Taunt
      next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::Taunt] > 0
    when "DisableTargetUsingSameMoveConsecutively"     # Tormento/Torment
      next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::Torment]
    when "DisableTargetHealingMoves"                   # Anticura/Heal Block
      next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::HealBlock] > 0
    when "StartTargetCannotUseItem"                    # Embargo
      next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::Embargo] > 0
    when "CurseTargetOrLowerUserSpd1RaiseUserAtkDef1"  # Maldición/Curse — solo rama Fantasma
      next score if !user.has_type?(:GHOST) &&
                    !(move.rough_type == :GHOST && user.has_active_ability?([:LIBERO, :PROTEAN]))
      next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::Curse]
    end
    next score
  }
)

#===============================================================================
# Handler Y: no atacar a rivales que ABSORBEN/son INMUNES al tipo por habilidad.
#===============================================================================
# Reutiliza pokemon_can_absorb_move? del core (Water Absorb, Volt Absorb, Flash Fire,
# Sap Sipper, Earth Eater, Bulletproof, Soundproof, Good as Gold, Wonder Guard...).
# Levitate NO entra aquí (va por efectividad de tipo, que rough_damage sí evalúa).
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:target_absorbs_move_by_ability,
  proc { |score, move, user, target, ai, battle|
    next score unless move.damagingMove?
    next score if target.being_mold_broken?
    next score unless ai.pokemon_can_absorb_move?(target, move, move.rough_type)
    next Battle::AI::MOVE_USELESS_SCORE
  }
)
