#===============================================================================
#
#===============================================================================
class Battle::AI
  HP_HEAL_ITEMS = {
    :POTION       => 20,
    :SUPERPOTION  => (Settings::REBALANCED_HEALING_ITEM_AMOUNTS) ? 60 : 50,
    :HYPERPOTION  => (Settings::REBALANCED_HEALING_ITEM_AMOUNTS) ? 120 : 200,
    :MAXPOTION    => 999,
    :BERRYJUICE   => 20,
    :SWEETHEART   => 20,
    :FRESHWATER   => (Settings::REBALANCED_HEALING_ITEM_AMOUNTS) ? 30 : 50,
    :SODAPOP      => (Settings::REBALANCED_HEALING_ITEM_AMOUNTS) ? 50 : 60,
    :LEMONADE     => (Settings::REBALANCED_HEALING_ITEM_AMOUNTS) ? 70 : 80,
    :MOOMOOMILK   => 100,
    :ORANBERRY    => 10,
    :SITRUSBERRY  => 1,   # Actual amount is determined below (pkmn.totalhp / 4)
    :ENERGYPOWDER => (Settings::REBALANCED_HEALING_ITEM_AMOUNTS) ? 60 : 50,
    :ENERGYROOT   => (Settings::REBALANCED_HEALING_ITEM_AMOUNTS) ? 120 : 200
  }
  HP_HEAL_ITEMS[:RAGECANDYBAR] = 20 if !Settings::RAGE_CANDY_BAR_CURES_STATUS_PROBLEMS
  FULL_RESTORE_ITEMS = [
    :FULLRESTORE
  ]
  ONE_STATUS_CURE_ITEMS = [   # Preferred over items that heal all status problems
    :AWAKENING, :CHESTOBERRY, :BLUEFLUTE,
    :ANTIDOTE, :PECHABERRY,
    :BURNHEAL, :RAWSTBERRY,
    :PARALYZEHEAL, :PARLYZHEAL, :CHERIBERRY,
    :ICEHEAL, :ASPEARBERRY
  ]
  ALL_STATUS_CURE_ITEMS = [
    :FULLHEAL, :LAVACOOKIE, :OLDGATEAU, :CASTELIACONE, :LUMIOSEGALETTE,
    :SHALOURSABLE, :BIGMALASADA, :PEWTERCRUNCHIES, :LUMBERRY, :HEALPOWDER
  ]
  ALL_STATUS_CURE_ITEMS.push(:RAGECANDYBAR) if Settings::RAGE_CANDY_BAR_CURES_STATUS_PROBLEMS
  ONE_STAT_RAISE_ITEMS = {
    :XATTACK    => [:ATTACK, (Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES) ? 2 : 1],
    :XATTACK2   => [:ATTACK, 2],
    :XATTACK3   => [:ATTACK, 3],
    :XATTACK6   => [:ATTACK, 6],
    :XDEFENSE   => [:DEFENSE, (Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES) ? 2 : 1],
    :XDEFENSE2  => [:DEFENSE, 2],
    :XDEFENSE3  => [:DEFENSE, 3],
    :XDEFENSE6  => [:DEFENSE, 6],
    :XDEFEND    => [:DEFENSE, (Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES) ? 2 : 1],
    :XDEFEND2   => [:DEFENSE, 2],
    :XDEFEND3   => [:DEFENSE, 3],
    :XDEFEND6   => [:DEFENSE, 6],
    :XSPATK     => [:SPECIAL_ATTACK, (Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES) ? 2 : 1],
    :XSPATK2    => [:SPECIAL_ATTACK, 2],
    :XSPATK3    => [:SPECIAL_ATTACK, 3],
    :XSPATK6    => [:SPECIAL_ATTACK, 6],
    :XSPECIAL   => [:SPECIAL_ATTACK, (Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES) ? 2 : 1],
    :XSPECIAL2  => [:SPECIAL_ATTACK, 2],
    :XSPECIAL3  => [:SPECIAL_ATTACK, 3],
    :XSPECIAL6  => [:SPECIAL_ATTACK, 6],
    :XSPDEF     => [:SPECIAL_DEFENSE, (Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES) ? 2 : 1],
    :XSPDEF2    => [:SPECIAL_DEFENSE, 2],
    :XSPDEF3    => [:SPECIAL_DEFENSE, 3],
    :XSPDEF6    => [:SPECIAL_DEFENSE, 6],
    :XSPEED     => [:SPEED, (Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES) ? 2 : 1],
    :XSPEED2    => [:SPEED, 2],
    :XSPEED3    => [:SPEED, 3],
    :XSPEED6    => [:SPEED, 6],
    :XACCURACY  => [:ACCURACY, (Settings::X_STAT_ITEMS_RAISE_BY_TWO_STAGES) ? 2 : 1],
    :XACCURACY2 => [:ACCURACY, 2],
    :XACCURACY3 => [:ACCURACY, 3],
    :XACCURACY6 => [:ACCURACY, 6]
  }
  ALL_STATS_RAISE_ITEMS = [
    :MAXMUSHROOMS
  ]
  REVIVE_ITEMS = {
    :REVIVE      => 5,
    :MAXREVIVE   => 7,
    :REVIVALHERB => 7,
    :MAXHONEY    => 7
  }

  #-----------------------------------------------------------------------------

  # Decide whether the opponent should use an item on the Pokémon.
  def pbChooseToUseItem
    item = nil
    idxTarget = nil   # Party index (battle_use type 1/2/3) or battler index
    idxMove = nil
    item, idxTarget, idxMove = choose_item_to_use
    return false if !item
    # Register use of item
    @battle.pbRegisterItem(@user.index, item, idxTarget, idxMove)
    PBDebug.log_ai("#{@user.name} will use item #{GameData::Item.get(item).name}")
    return true
  end

  # Return values are:
  #   item ID
  #   target index (party index for items with a battle use of 1/2/3, battler
  #     index otherwise)
  #   move index (for items usable on moves only)
  def choose_item_to_use
    if !@battle.internalBattle
      PBDebug.log_ai_decision("Objetos descartados: combate sin uso de objetos de entrenador.")
      return nil
    end
    items = @battle.pbGetOwnerItems(@user.index)
    if !items || items.length == 0
      PBDebug.log_ai_decision("Objetos descartados: el entrenador no tiene objetos disponibles.")
      return nil
    end
    # Find all items usable on the Pokémon choosing this action
    pkmn = @user.battler.pokemon
    usable_items = {}
    items.each do |item|
      usage = get_usability_of_item_on_pkmn(item, @user.party_index, @user.side)
      usage.each_pair do |key, vals|
        usable_items[key] ||= []
        usable_items[key] += vals
      end
    end
    # Prioritise using a HP restoration item
    if usable_items[:hp_heal] && (pkmn.hp <= pkmn.totalhp / 4 ||
       (pkmn.hp <= pkmn.totalhp / 2 && pbAIRandom(100) < 30))
      # AI Improvements (Fix #13): si el rival noquea al activo igual aun curando al
      # máximo, curar malgasta el turno -> no usar item (la IA atacará). Cubre las dos
      # velocidades: si el rival mata desde HP máximo, curar sobra seamos rápidos o no.
      if @trainer.high_skill? && ai_improvements_heal_wasted_by_ko?
        PBDebug.log_ai("#{@user.name} NO se cura: el rival lo noquea igual (Fix #13)")
        return nil
      end
      PBDebug.log_ai_decision("Se prioriza curar HP: #{pkmn.hp}/#{pkmn.totalhp}; se compara prioridad y cantidad curada.")
      usable_items[:hp_heal].sort! { |a, b| (a[2] == b[2]) ? a[3] <=> b[3] : a[2] <=> b[2] }
      candidate = usable_items[:hp_heal].find do |item|
        item[3] >= (pkmn.totalhp - pkmn.hp) * 0.75
      end
      candidate ||= usable_items[:hp_heal].last
      return nil if ai_improvements_hp_heal_loses_race?(candidate)
      return candidate[0], candidate[1]
    end
    # Next prioritise using a status-curing item
    if usable_items[:status_cure] &&
       ([:SLEEP, :FROZEN].include?(pkmn.status) || pbAIRandom(100) < 40)
      PBDebug.log_ai_decision("Se prioriza curar el estado #{pkmn.status}.")
      usable_items[:status_cure].sort! { |a, b| a[2] <=> b[2] }
      return usable_items[:status_cure].first[0], usable_items[:status_cure].first[1]
    end
    # Next try using an item that raises all stats (Max Mushrooms)
    if usable_items[:all_stats_raise] && pbAIRandom(100) < 30
      PBDebug.log_ai_decision("Se intenta usar un objeto para subir todas las estadisticas; paso aleatorio superado.")
      return usable_items[:stat_raise].first[0], usable_items[:stat_raise].first[1]
    end
    # Next try using an X item
    if usable_items[:stat_raise] && pbAIRandom(100) < 30
      PBDebug.log_ai_decision("Se prioriza un objeto X; paso aleatorio superado.")
      usable_items[:stat_raise].sort! { |a, b| (a[2] == b[2]) ? a[3] <=> b[3] : a[2] <=> b[2] }
      return usable_items[:stat_raise].last[0], usable_items[:stat_raise].last[1]
    end
    # Find items usable on other Pokémon in the user's team
    # NOTE: Currently only checks Revives.
    usable_items = {}
    @battle.eachInTeamFromBattlerIndex(@user.index) do |team_pkmn, i|
      next if !team_pkmn.fainted?   # Remove this line to check unfainted Pokémon too
      items.each do |item|
        usage = get_usability_of_item_on_pkmn(item, i, @user.side)
        usage.each_pair do |key, vals|
          usable_items[key] ||= []
          usable_items[key] += vals
        end
      end
    end
    # Try using a Revive (prefer Max Revive-type items over Revive)
    if usable_items[:revive] &&
       (@battle.pbAbleNonActiveCount(@user.index) == 0 || pbAIRandom(100) < 40)
      PBDebug.log_ai_decision("Se prioriza revivir una reserva; se compara tipo de revivir y posicion en el equipo.")
      usable_items[:revive].sort! { |a, b| (a[2] == b[2]) ? a[1] <=> b[1] : a[2] <=> b[2] }
      return usable_items[:revive].last[0], usable_items[:revive].last[1]
    end
    PBDebug.log_ai_decision("Ningun objeto supera los criterios de uso y los filtros aleatorios.")
    return nil
  end

  # Conserva objetos HP si comprar turnos no permite aprovecharlos en individuales.
  # No modifica el veto fullHP previo ni la selección/prioridad de objetos.
  def ai_improvements_hp_heal_loses_race?(candidate)
    return false if !@trainer.high_skill? || !@trainer.has_skill_flag?("HPAware")
    return false if @battle.pbSideSize(0) != 1 || @battle.pbSideSize(1) != 1
    if @user.status != :NONE || @user.effects[PBEffects::Confusion] > 0
      PBDebug.log_ai_decision("Cura HP conservada: el activo tiene estado o confusion; no se aplica carrera ofensiva.")
      return false
    end
    rival = nil
    each_foe_battler(@user.idxOwnSide) { |b, _i| rival ||= b }
    return false if rival.nil?
    # ponytail: no proyecta el daño después de romper Sustituto; conserva la cura
    # hasta disponer de un horizonte de acciones.
    if rival.effects[PBEffects::Substitute] > 0
      PBDebug.log_ai_decision("Cura HP conservada: Sustituto rival requiere una secuencia de ataques.")
      return false
    end
    incoming = ai_improvements_best_damage(rival, @user)
    # La política ofensiva usa el HP actual, no simula habilidades activadas
    # por HP tras curar; ampliar el contexto si estas carreras lo requieren.
    attack_pressure = ai_improvements_attack_pressure(@user, rival)
    return false if attack_pressure.nil?
    outgoing, recoil = attack_pressure
    heal_amount = candidate[3]
    if FULL_RESTORE_ITEMS.include?(candidate[0]) || candidate[0] == :MAXPOTION
      heal_amount = @user.totalhp - @user.hp
    elsif candidate[0] == :SITRUSBERRY
      heal_amount = @user.totalhp / 4
    end
    healed_hp = [@user.hp + heal_amount, @user.totalhp].min
    own_residual = @user.rough_end_of_round_damage
    foe_residual = rival.rough_end_of_round_damage
    hp_after = [[healed_hp - incoming - own_residual, 0].max, @user.totalhp].min
    pressure = incoming + own_residual + recoil
    PBDebug.log_ai_decision("Cura HP #{candidate[0]}: HP #{@user.hp}/#{@user.totalhp}, cura efectiva #{healed_hp - @user.hp}, " \
                           "daño entrante #{incoming.round(1)}, saliente #{outgoing.round(1)}, " \
                           "retroceso al atacar #{recoil.round(1)}, residual propio #{own_residual}, rival #{foe_residual}, HP tras turno #{hp_after.round(1)}.")
    defensive_recovery = @user.battler.moves.each_with_index.any? do |move, i|
      move && move.healingMove? && @battle.pbCanChooseMove?(@user.index, i, false)
    end
    if rival.status != :NONE || rival.effects[PBEffects::Confusion] > 0 || foe_residual > 0 ||
       own_residual < 0 || defensive_recovery || ai_improvements_has_progress_status?(@user)
      PBDebug.log_ai_decision("Cura HP conservada: existe estado, residual, recuperacion defensiva o movimiento de progreso.")
      return false
    end
    if pressure <= 0
      PBDebug.log_ai_decision("Cura HP conservada: no hay desgaste neto estimado.")
      return false
    end
    # ponytail: carrera de daño constante, sin PP ni secuencias de movimientos;
    # concede incluso el ataque del turno letal (optimista). Usar un horizonte de
    # acciones con prioridad/velocidad y cambios de estado si se necesita más precisión.
    turns_before = (@user.hp / pressure.to_f).ceil
    useful_turns = (hp_after / pressure.to_f).ceil
    bought_turns = useful_turns - turns_before
    turns_to_ko = (outgoing > 0) ? (rival.hp / outgoing.to_f).ceil : Float::INFINITY
    clearly_lost = turns_to_ko > useful_turns + 2 && turns_to_ko > useful_turns * 2
    PBDebug.log_ai_decision("Cura HP carrera: turnos antes #{turns_before}, utiles tras cura #{useful_turns}, " \
                           "comprados #{bought_turns}, necesarios para KO #{turns_to_ko}, claramente perdida #{clearly_lost}.")
    if !clearly_lost
      PBDebug.log_ai_decision("Cura HP conservada: margen insuficiente para declarar perdida la carrera.")
      return false
    end
    useful_reserve = nil
    @battle.eachInTeamFromBattlerIndex(@user.index) do |pkmn, i|
      next if !pkmn || !@battle.pbCanSwitch?(@user.index, i)
      next if calculate_entry_hazard_damage(pkmn, @user.side) >= pkmn.hp
      next if !pkmn.moves.any? { |move| move.pp > 0 || move.total_pp == 0 }
      next if rate_replacement_pokemon(@user.index, pkmn, 100) < 100
      useful_reserve = i
      break
    end
    if useful_reserve.nil?
      PBDebug.log_ai_decision("Cura HP conservada: no hay reserva viva legal con movimientos y valoracion util.")
      return false
    end
    PBDebug.log_ai_decision("Cura HP descartada: carrera ofensiva claramente perdida incluso tras curar; " \
                           "se conserva #{candidate[0]} para reserva util (party #{useful_reserve}).")
    return true
  end

  # AI Improvements (Fix #13): ¿el rival noquea al activo este turno aunque curemos
  # al máximo? Si es así, curar malgasta el turno (morimos igual) -> suprimir la cura.
  def ai_improvements_heal_wasted_by_ko?
    rival = nil
    each_foe_battler(@user.idxOwnSide) { |b, _i| rival ||= b }
    return false if rival.nil?
    ai_improvements_rival_kos_from_full_hp?(rival)
  end

  # ¿El rival noquea a @user aunque curemos al máximo? (speed-agnostic). rough_damage usa
  # @ai.user (atacante) y @ai.target (defensor): intercambiamos @user:=rival, @target:=
  # nuestro mon y fijamos moldBreaker al del rival (es el atacante); todo se restaura con
  # ensure. Pesimista: asume curación total (totalhp) -> falsos positivos raros.
  def ai_improvements_rival_kos_from_full_hp?(rival)
    target_hp = @user.battler.totalhp
    orig_user   = @user
    orig_target = @target
    orig_mold   = @battle.moldBreaker
    begin
      instance_variable_set(:@user, rival)
      instance_variable_set(:@target, orig_user)
      @battle.moldBreaker = rival.has_mold_breaker?
      rival.battler.moves.any? do |m|
        next false if m.nil? || m.pp == 0 || !m.damagingMove?
        aim = Battle::AI::AIMove.new(self)
        aim.set_up(m)
        aim.rough_damage >= target_hp
      end
    ensure
      instance_variable_set(:@user, orig_user)
      instance_variable_set(:@target, orig_target)
      @battle.moldBreaker = orig_mold
    end
  end

  def get_usability_of_item_on_pkmn(item, party_index, side)
    pkmn = @battle.pbParty(side)[party_index]
    battler = @battle.pbFindBattler(party_index, side)
    ret = {}
    return ret if !@battle.pbCanUseItemOnPokemon?(item, pkmn, battler, @battle.scene, false)
    return ret if !ItemHandlers.triggerCanUseInBattle(item, pkmn, battler, nil,
                                                      false, self, @battle.scene, false)
    want_to_cure_status = (pkmn.status != :NONE)
    if battler
      if want_to_cure_status
        want_to_cure_status = @battlers[battler.index].wants_status_problem?(pkmn.status)
        want_to_cure_status = false if pkmn.status == :SLEEP && pkmn.statusCount <= 2
      end
      want_to_cure_status ||= (battler.effects[PBEffects::Confusion] > 1)
    end
    if HP_HEAL_ITEMS.include?(item)
      if pkmn.hp < pkmn.totalhp
        heal_amount = HP_HEAL_ITEMS[item]
        heal_amount = pkmn.totalhp / 4 if item == :SITURUSBERRY
        ret[:hp_heal] ||= []
        ret[:hp_heal].push([item, party_index, 5, heal_amount])
      end
    elsif FULL_RESTORE_ITEMS.include?(item)
      prefer_full_restore = (pkmn.hp <= pkmn.totalhp * 2 / 3 && want_to_cure_status)
      if pkmn.hp < pkmn.totalhp
        ret[:hp_heal] ||= []
        ret[:hp_heal].push([item, party_index, (prefer_full_restore) ? 3 : 7, 999])
      end
      if want_to_cure_status
        ret[:status_cure] ||= []
        ret[:status_cure].push([item, party_index, (prefer_full_restore) ? 3 : 9])
      end
    elsif ONE_STATUS_CURE_ITEMS.include?(item)
      if want_to_cure_status
        ret[:status_cure] ||= []
        ret[:status_cure].push([item, party_index, 5])
      end
    elsif ALL_STATUS_CURE_ITEMS.include?(item)
      if want_to_cure_status
        ret[:status_cure] ||= []
        ret[:status_cure].push([item, party_index, 7])
      end
    elsif ONE_STAT_RAISE_ITEMS.include?(item)
      stat_data = ONE_STAT_RAISE_ITEMS[item]
      if battler && stat_raise_worthwhile?(@battlers[battler.index], stat_data[0])
        ret[:stat_raise] ||= []
        ret[:stat_raise].push([item, party_index, battler.stages[stat_data[0]], stat_data[1]])
      end
    elsif ALL_STATS_RAISE_ITEMS.include?(item)
      if battler
        ret[:all_stats_raise] ||= []
        ret[:all_stats_raise].push([item, party_index])
      end
    elsif REVIVE_ITEMS.include?(item)
      ret[:revive] ||= []
      ret[:revive].push([item, party_index, REVIVE_ITEMS[item]])
    end
    return ret
  end
end
