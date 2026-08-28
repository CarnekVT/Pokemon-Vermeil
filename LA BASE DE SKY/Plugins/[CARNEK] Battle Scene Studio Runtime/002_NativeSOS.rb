#===============================================================================
# Battle Scene Studio 0.6.14 - Native SOS (Phase 1)
# BSS-owned SOS. Runtime assignments come only from sos_global.json.
# Dynamic battler creation follows the v21/DBK SOS lifecycle supplied by the
# user. Growth slots are created by the project's real pbCreateBattler constructor
# before AI/special-actions/bookkeeping are exposed; existing fainted active slots
# are reinitialized in-place. No allocate/placeholder shell path is used.
#===============================================================================

class Battle::AI
  def bss_create_new_ai_battler(idx_battler)
    idx_battler=idx_battler.to_i
    return nil if !@battlers.is_a?(Array)
    return @battlers[idx_battler] if @battlers[idx_battler]
    @battlers[idx_battler]=AIBattler.new(self,idx_battler)
    @battlers[idx_battler]
  end

  def bss_ai_battler_ready?(idx_battler)
    @battlers.is_a?(Array) && !!@battlers[idx_battler.to_i]
  end
end


#===============================================================================
# Dynamic battlers are intentionally NOT monkey-patched here.
# BSS 0.6.14 follows the same creation/replacement lifecycle as the supplied
# SOS source: pbCreateBattler for new slots and pbInitialize only for an already
# constructed fainted slot. This avoids entering the project's Battler initializer
# with a hand-built/partially seeded object.
#===============================================================================
class Battle
  attr_accessor :bss_sos_enabled
  attr_accessor :bss_sos_config
  attr_accessor :bss_sos_chain
  attr_accessor :bss_adrenaline_orb
  attr_accessor :bss_original_caller
  attr_accessor :bss_last_turn_called
  attr_accessor :bss_last_call_answered
  attr_accessor :bss_initial_sos_done

  unless method_defined?(:bss064_initialize_without_native_sos)
    alias bss064_initialize_without_native_sos initialize
    def initialize(scene, p1, p2, player, opponent)
      bss064_initialize_without_native_sos(scene, p1, p2, player, opponent)
      @bss_sos_enabled        = (wildBattle? rescue false) && BSS064.global_sos_active?
      @bss_sos_config         = @bss_sos_enabled ? BSS064.global_sos.dup : {}
      @bss_sos_chain          = 0
      @bss_adrenaline_orb     = false
      @bss_original_caller    = nil
      @bss_last_turn_called   = -99
      @bss_last_call_answered = nil
      @bss_initial_sos_done   = false
      self.sosBattle = false if respond_to?(:sosBattle=)
    end
  end

  def bss_sos_limit_one?
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    return cfg["limitCallsToOne"] != false if cfg.key?("limitCallsToOne")
    BSS064.global_sos["limitCallsToOne"] != false
  end

  def bss_sos_shiny_multiplier
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    n=cfg["shinyMultiplier"].to_i
    n=BSS064.global_sos["shinyMultiplier"].to_i if n<=0
    [n,1].max
  end

  # ---------------------------------------------------------------------------
  # Conditions used by global SOS profiles and weighted pool entries.
  # ---------------------------------------------------------------------------
  def bss_player_highest_level
    return 0 if !defined?($player) || !$player || !$player.respond_to?(:party)
    vals=$player.party.compact.map { |p| p.level.to_i }
    vals.empty? ? 0 : vals.max
  rescue
    0
  end

  def bss_requirement_met?(req, caller=nil)
    return true if !req.is_a?(Hash)
    type=req["type"].to_s
    value=req["value"].to_i
    id=req["id"].to_i
    case type
    when "", "always" then true
    when "badge_min" then (defined?($player) && $player && $player.respond_to?(:badge_count) ? $player.badge_count.to_i : 0) >= value
    when "badge_max" then (defined?($player) && $player && $player.respond_to?(:badge_count) ? $player.badge_count.to_i : 0) <= value
    when "switch_on" then id>0 && defined?($game_switches) && $game_switches && !!$game_switches[id]
    when "switch_off" then id>0 && defined?($game_switches) && $game_switches && !$game_switches[id]
    when "variable_min" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i >= value
    when "variable_max" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i <= value
    when "variable_equals" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i == value
    when "caller_level_min" then caller && caller.level.to_i >= value
    when "caller_level_max" then caller && caller.level.to_i <= value
    when "player_level_min" then bss_player_highest_level >= value
    when "player_level_max" then bss_player_highest_level <= value
    when "map_id" then defined?($game_map) && $game_map && $game_map.map_id.to_i == value
    when "chain_min" then @bss_sos_chain.to_i >= value
    when "chain_max" then @bss_sos_chain.to_i <= value
    when "day" then defined?(PBDayNight) && PBDayNight.respond_to?(:isDay?) && PBDayNight.isDay?
    when "night" then defined?(PBDayNight) && PBDayNight.respond_to?(:isNight?) && PBDayNight.isNight?
    else true
    end
  rescue
    false
  end

  def bss_requirements_met?(requirements, caller=nil)
    rows=requirements.is_a?(Array) ? requirements : []
    rows.all? { |r| bss_requirement_met?(r,caller) }
  end

  def bss_sos_profile(caller)
    profile=BSS064.sos_profile(caller.species, caller.form)
    return nil if !profile
    return nil if !bss_requirements_met?(profile["requirements"], caller)
    profile
  rescue
    nil
  end

  # ---------------------------------------------------------------------------
  # Dynamic battler lifecycle — source-faithful to the SOS code supplied by user.
  # ---------------------------------------------------------------------------
  # Do not construct, clone, allocate or pre-seed Battle::Battler here. A truly
  # new active slot must go through Battle#pbCreateBattler, while a fainted active
  # slot is reinitialized in-place. The side size is changed at the same point as
  # the source SOS implementation, before pbCreateBattler.
  # ---------------------------------------------------------------------------
  def bss_find_new_battler_slot(caller)
    return [-1, false] if !caller
    # Use the source SOS slot finder when present, including any project-specific
    # side-size/index changes made by that implementation.
    if respond_to?(:pbFindNewBattlerIndex)
      side = caller.idxOwnSide.to_i
      before = @sideSizes.is_a?(Array) ? @sideSizes[side].to_i : pbSideSize(caller.index).to_i
      idx_new = pbFindNewBattlerIndex(caller)
      after = @sideSizes.is_a?(Array) ? @sideSizes[side].to_i : before
      return [idx_new, idx_new.to_i >= 0 && after > before]
    end
    idx_new = -1
    change_size = false
    size = pbSideSize(caller.index).to_i
    6.times do |i|
      b = @battlers[i]
      next if b && !b.fainted?
      next if caller.opposes?(i)
      idx_new = i
      change_size = b.nil?
      break
    end
    if idx_new < 0 && size < 3
      idx_new = caller.index + (2 * ([1, size - 1].max))
      change_size = true
    end
    @sideSizes[caller.idxOwnSide] = size + 1 if change_size && idx_new >= 0
    [idx_new, change_size]
  end

  # Extend battle/scene arrays which are indexed by active battler position.
  def bss_prepare_battle_slot(idx_battler)
    idx_battler = idx_battler.to_i
    if @choices.is_a?(Array)
      @choices << [:None, 0, nil, -1] while @choices.length <= idx_battler
    end
    scene = @scene
    if scene
      [:@lastCmd, :@lastMove].each do |ivar|
        rows = scene.instance_variable_get(ivar)
        rows << 0 while rows.is_a?(Array) && rows.length <= idx_battler
      end
      [:@lastTarget, :@lastMoveUser].each do |ivar|
        rows = scene.instance_variable_get(ivar)
        rows << -1 while rows.is_a?(Array) && rows.length <= idx_battler
      end
    end
    true
  end

  # LBDS 1.2.x adds party-indexed battle state that stock v21.1 SOS Battles does
  # not know about. In particular Battler#pbInitEffects clears
  # abilitiesUsedPerSwitchIn[side][pokemonIndex]. A freshly appended SOS Pokemon
  # therefore MUST get these entries before pbCreateBattler constructs the new
  # Battle::Battler. Otherwise 003_Battler_Initialize.rb raises nil.clear.
  def bss_prepare_party_tracking_slot(side, idx_party)
    side = side.to_i
    idx_party = idx_party.to_i

    if @abilitiesUsedPerSwitchIn.is_a?(Array)
      @abilitiesUsedPerSwitchIn[side] ||= []
      rows = @abilitiesUsedPerSwitchIn[side]
      rows << [] while rows.length <= idx_party
      rows[idx_party] = [] if !rows[idx_party].is_a?(Array)
    end

    if @abilitiesUsedOnce.is_a?(Array)
      @abilitiesUsedOnce[side] ||= []
      rows = @abilitiesUsedOnce[side]
      rows << [] while rows.length <= idx_party
      rows[idx_party] = [] if !rows[idx_party].is_a?(Array)
    end

    if @hitsTakenCounts.is_a?(Array)
      @hitsTakenCounts[side] ||= []
      rows = @hitsTakenCounts[side]
      rows << 0 while rows.length <= idx_party
      rows[idx_party] = 0 if rows[idx_party].nil?
    end

    true
  end

  # The supplied SOS plugin was written against stock v21.1, where
  # @initialItems stores only the item id. LBDS 1.2.x stores a four-value record.
  # Preserve whichever layout the running project actually uses.
  def bss_normalize_initial_item_slot(side, idx_party, pkmn)
    return if !@initialItems.is_a?(Array) || !@initialItems[side].is_a?(Array)
    rows = @initialItems[side]
    sample = rows.find { |row| !row.nil? }
    if sample.is_a?(Array)
      rows[idx_party] = [pkmn.item_id, side, idx_party, false]
    end
  rescue => e
    BSS064.log("SOS initialItems compatibility skipped: #{e.class}: #{e.message}")
  end

  # Generic scene/choice bookkeeping helper for fallback paths.
  def bss_finalize_battle_slot(idx_battler)
    bss_prepare_battle_slot(idx_battler)
  end

  def bss_append_source_bookkeeping(pkmn)
    # This is deliberately the same append order used by the supplied SOS source.
    @initialItems[1].push(pkmn.item_id)
    @recycleItems[1].push(nil)
    @belch[1].push(false)
    @battleBond[1].push(false)
    @corrosiveGas[1].push(false)
    @usedInBattle[1].push(true)
    @abils_triggered[1].push(false) if defined?(@abils_triggered)
    @rage_hit_count[1].push(0) if defined?(@rage_hit_count)
    if defined?(@wonderLauncher) && trainerBattle?
      @launcherPoints[1].push(0)
      @launcherCounter[1].push(launcherBattle?)
    end
  end

  def bss_replace_source_bookkeeping(idx_party, pkmn)
    @initialItems[1][idx_party] = pkmn.item_id
    @recycleItems[1][idx_party] = nil
    @belch[1][idx_party] = false
    @battleBond[1][idx_party] = false
    @corrosiveGas[1][idx_party] = false
    @usedInBattle[1][idx_party] = true
    @abils_triggered[1][idx_party] = false if defined?(@abils_triggered)
    @rage_hit_count[1][idx_party] = 0 if defined?(@rage_hit_count)
    if defined?(@wonderLauncher) && trainerBattle?
      @launcherPoints[1][idx_party] = 0
      @launcherCounter[1][idx_party] = launcherBattle?
    end
  end

  def bss_initialize_new_sos_battler(idx_battler, pkmn, full_update)
    # Prefer the lifecycle supplied by the installed SOS plugin, but seed the
    # additional LBDS 1.2.x party-indexed state BEFORE it constructs/reinitializes
    # the battler. The stock SOS source doesn't maintain those newer arrays.
    if respond_to?(:pbInitializeNewBattler)
      idx_party = nil
      if full_update
        idx_party = @party2.length
      else
        idx_party = 0
        @battlers.each do |b|
          next if !b || !b.fainted? || b.opposes?(idx_battler)
          idx_party = b.pokemonIndex
          break
        end
      end
      bss_prepare_party_tracking_slot(1, idx_party)
      bss_prepare_battle_slot(idx_battler)
      BSS064.log("SOS lifecycle: source pbInitializeNewBattler idx=#{idx_battler} party=#{idx_party} full=#{full_update}")
      pbInitializeNewBattler([idx_battler, pkmn], [], full_update)
      battler = @battlers[idx_battler]
      raise RuntimeError, "SOS source lifecycle did not create battler #{idx_battler}" if !battler
      bss_prepare_party_tracking_slot(1, battler.pokemonIndex)
      bss_normalize_initial_item_slot(1, battler.pokemonIndex, pkmn)
      return battler
    end

    # Autonomous fallback when no source SOS runtime exists.
    idx_party = nil
    if full_update
      @party2.push(pkmn)
      idx_party = @party2.length - 1
      @party2order = Array.new(@party2.length) { |i| i }
      bss_prepare_party_tracking_slot(1, idx_party)
      bss_prepare_battle_slot(idx_battler)
      pbCreateBattler(idx_battler, pkmn, idx_party)
      if @battleAI
        if @battleAI.respond_to?(:create_new_ai_battler)
          @battleAI.create_new_ai_battler(idx_battler)
        elsif @battleAI.respond_to?(:bss_create_new_ai_battler)
          @battleAI.bss_create_new_ai_battler(idx_battler)
        end
      end
      pbInitializeSpecialActions(nil)
      bss_append_source_bookkeeping(pkmn)
    else
      idx_party = 0
      @battlers.each do |b|
        next if !b || !b.fainted? || b.opposes?(idx_battler)
        idx_party = b.pokemonIndex
        break
      end
      @party2[idx_party] = pkmn
      @party2order = Array.new(@party2.length) { |i| i }
      bss_prepare_party_tracking_slot(1, idx_party)
      bss_prepare_battle_slot(idx_battler)
      battler = @battlers[idx_battler]
      raise RuntimeError, "SOS replacement slot #{idx_battler} has no constructed battler" if !battler
      battler.pbInitialize(pkmn, idx_party)
      if @battleAI
        if @battleAI.respond_to?(:create_new_ai_battler)
          @battleAI.create_new_ai_battler(idx_battler)
        elsif @battleAI.respond_to?(:bss_create_new_ai_battler)
          @battleAI.bss_create_new_ai_battler(idx_battler)
        end
      end
      pbInitializeSpecialActions(nil)
      bss_replace_source_bookkeeping(idx_party, pkmn)
    end
    battler = @battlers[idx_battler]
    raise RuntimeError, "SOS battler #{idx_battler} was not created" if !battler
    bss_prepare_party_tracking_slot(1, battler.pokemonIndex) if battler.respond_to?(:pokemonIndex)
    bss_normalize_initial_item_slot(1, battler.pokemonIndex, pkmn) if battler.respond_to?(:pokemonIndex)
    battler.lastRoundMoved = @turnCount if battler.respond_to?(:lastRoundMoved=)
    battler.totemBattler = false if battler.respond_to?(:totemBattler=)
    if @choices.is_a?(Array)
      @choices << [:None, 0, nil, -1] while @choices.length <= idx_battler
    end
    scene = @scene
    if scene
      [:@lastCmd, :@lastMove].each do |ivar|
        rows = scene.instance_variable_get(ivar)
        rows << 0 while rows.is_a?(Array) && rows.length <= idx_battler
      end
      [:@lastTarget, :@lastMoveUser].each do |ivar|
        rows = scene.instance_variable_get(ivar)
        rows << -1 while rows.is_a?(Array) && rows.length <= idx_battler
      end
    end
    battler
  end

  def bss_create_fresh_sos_battler(idx_battler, caller, pkmn, change_size)
    side = caller.idxOwnSide.to_i
    # bss_find_new_battler_slot already changed @sideSizes if this is a new slot.
    previous_size = @sideSizes[side].to_i - (change_size ? 1 : 0)
    old_party = @party2.dup
    old_order = @party2order.dup if @party2order.is_a?(Array)
    old_battler = @battlers[idx_battler]
    full_update = old_battler.nil?
    begin
      return bss_initialize_new_sos_battler(idx_battler, pkmn, full_update)
    rescue => e
      # Roll back only battle-level data BSS changed. Never retry pbInitialize and
      # never mutate Battle::Battler internals to hide the real initializer error.
      @sideSizes[side] = previous_size if change_size
      @party2.replace(old_party) if @party2.is_a?(Array)
      @party2order = old_order if old_order
      @battlers[idx_battler] = old_battler if @battlers.is_a?(Array)
      BSS064.log("SOS battler source lifecycle failed: #{e.class}: #{e.message}")
      BSS064.log((e.backtrace || [])[0, 12].join(" | "))
      nil
    end
  end

  def bss_active_battler_indices
    out = []
    [[0, [0,2,4]], [1, [1,3,5]]].each do |side, slots|
      count = @sideSizes.is_a?(Array) ? @sideSizes[side].to_i : 0
      count = [[count, 0].max, 3].min
      slots.first(count).each do |idx|
        battler = @battlers.is_a?(Array) ? @battlers[idx] : nil
        out << idx if battler
      end
    end
    out
  end

  def bss_live_same_side_count(idx_battler)
    side = idx_battler.to_i & 1
    bss_active_battler_indices.count do |idx|
      next false if (idx & 1) != side
      battler = @battlers[idx]
      battler && !(battler.fainted? rescue true)
    end
  end

  def bss_sos_pool_entries(caller)
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    rows=cfg["pool"].is_a?(Array) ? cfg["pool"] : []
    if rows.empty?
      profile=bss_sos_profile(caller)
      rows=profile && profile["pool"].is_a?(Array) ? profile["pool"] : []
    end
    out=[]
    rows.each do |raw|
      entry=raw.is_a?(Hash) ? raw.dup : {"species"=>raw.to_s,"form"=>0,"weight"=>100}
      species=entry["species"].to_s.upcase
      next if species.empty? || !(GameData::Species.exists?(species.to_sym) rescue false)
      next if !bss_requirements_met?(entry["requirements"], caller)
      entry["species"]=species
      entry["form"]=entry["form"].to_i
      entry["weight"]=[entry["weight"].to_i,0].max
      out << entry
    end
    out << {"species"=>caller.species.to_s,"form"=>caller.form.to_i,"weight"=>100} if out.empty?
    out
  end

  def bss_pick_sos_entry(caller)
    rows=bss_sos_pool_entries(caller)
    weighted=rows.select { |x| x["weight"].to_i>0 }
    return rows[0] if weighted.empty?
    total=weighted.inject(0) { |n,x| n+x["weight"].to_i }
    roll=pbRandom(total)
    weighted.each do |x|
      w=x["weight"].to_i
      return x if roll<w
      roll-=w
    end
    weighted[-1]
  end

  def bss_generate_sos_pokemon(entry, caller)
    original=@bss_original_caller || caller.pokemon
    level=[original.level-(pbRandom(5)+1),1].max
    species=entry["species"].to_s.upcase.to_sym
    pkmn=pbGenerateWildPokemon(species,level)
    form=entry["form"].to_i
    pkmn.form=form if form>0 && pkmn.respond_to?(:form=)
    pkmn.form_simple=pkmn.form if pkmn.respond_to?(:form_simple=)
    @peer.pbOnStartingBattle(self,pkmn,true) if @peer && @peer.respond_to?(:pbOnStartingBattle)
    pkmn
  end

  def bss_set_sos_chain(caller)
    if @bss_original_caller.nil?
      @bss_original_caller=caller.pokemon
      @bss_sos_chain=1
    elsif @bss_sos_chain<255
      @bss_sos_chain+=1
    end
  end

  def bss_sos_answer_rate(caller)
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    direct=cfg["answerRate"]
    return [[direct.to_i,0].max,100].min if !direct.nil? && direct.to_s!=""
    profile=bss_sos_profile(caller)
    return 100 if !profile || profile["answerRate"].nil?
    [[profile["answerRate"].to_i,0].max,100].min
  end

  def bss_call_for_help(caller, guaranteed=false)
    return false if !caller || !@bss_sos_enabled
    begin
      @scene.pbAnimateSubstitute(caller,:hide) if @scene.respond_to?(:pbAnimateSubstitute)
    rescue
    end
    pbDisplay(_INTL("¡{1} pidió ayuda!", caller.pbThis))
    begin
      @scene.pbAnimation(:GROWL, caller, caller.pbDirectOpposing(true))
    rescue
    end
    pbDisplayPaused(_INTL("... ... ..."))
    answered=guaranteed || pbRandom(100)<bss_sos_answer_rate(caller)
    if answered
      idx,grow_side=bss_find_new_battler_slot(caller)
      if idx>=0
        entry=bss_pick_sos_entry(caller)
        pokemon=bss_generate_sos_pokemon(entry,caller)
        battler=bss_create_fresh_sos_battler(idx,caller,pokemon,grow_side)
        if battler
          @peer.pbOnEnteringBattle(self,battler,pokemon,true) if @peer && @peer.respond_to?(:pbOnEnteringBattle)
          @bss_last_call_answered=true
          bss_set_sos_chain(caller)
          if @scene.respond_to?(:bss_pbSOSJoin)
            @scene.bss_pbSOSJoin(idx)
          else
            @scene.pbRefresh if @scene.respond_to?(:pbRefresh)
          end
          pbDisplay(_INTL("¡Apareció {1}!", battler.name))
          begin
            @scene.pbAnimateSubstitute(caller,:show) if @scene.respond_to?(:pbAnimateSubstitute)
          rescue
          end
          pbCalculatePriority(true)
          pbOnBattlerEnteringBattle(idx)
          pbSetSeen(battler)
          @scene.bss_sync_enhanced_ui_icons if @scene.respond_to?(:bss_sync_enhanced_ui_icons)
          @bss_last_turn_called=@turnCount
          return true
        end
      end
    end
    @bss_last_call_answered=false
    pbDisplay(_INTL("¡La ayuda no apareció!"))
    begin
      @scene.pbAnimateSubstitute(caller,:show) if @scene.respond_to?(:pbAnimateSubstitute)
    rescue
    end
    @bss_last_turn_called=@turnCount
    false
  rescue => e
    BSS064.log("Native SOS call failed: #{e.class}: #{e.message}")
    BSS064.log((e.backtrace||[])[0,12].join(" | "))
    begin
      @scene.pbAnimateSubstitute(caller,:show) if caller && @scene.respond_to?(:pbAnimateSubstitute)
    rescue
    end
    false
  end

  unless method_defined?(:bss064_command_phase_without_native_sos)
    alias bss064_command_phase_without_native_sos pbCommandPhase
    def pbCommandPhase(*args)
      if @bss_sos_enabled && !@bss_initial_sos_done && @bss_sos_config.is_a?(Hash) && @bss_sos_config["initialCall"]==true
        wanted=[@bss_sos_config["callRound"].to_i,1].max
        if @turnCount.to_i+1>=wanted
          @bss_initial_sos_done=true
          caller=@battlers[1] || @battlers[3] || @battlers[5]
          bss_call_for_help(caller,true) if caller && caller.bss_can_sos_call_simple?
        end
      end
        bss064_command_phase_without_native_sos(*args)
    end
  end

  unless method_defined?(:bss064_end_round_without_native_sos)
    alias bss064_end_round_without_native_sos pbEndOfRoundPhase
    def pbEndOfRoundPhase(*args)
      self.sosBattle=false if respond_to?(:sosBattle=)
      ret=bss064_end_round_without_native_sos(*args)
      self.sosBattle=false if respond_to?(:sosBattle=)
      if @bss_sos_enabled && @bss_sos_config.is_a?(Hash) && @bss_sos_config["automaticCalls"]!=false && (wildBattle? rescue false)
        pbPriority(true).each do |b|
          next if !b || (b.fainted? rescue true) || !(b.wild? rescue false)
          if b.bss_can_sos_call?
            bss_call_for_help(b,false)
            b.bss_took_super_effective_damage=false
            break
          end
        end
      end
      ret
    end
  end
end

class Battle::Battler
  attr_accessor :totemBattler unless method_defined?(:totemBattler)
  attr_accessor :bss_took_super_effective_damage

  def bss_sos_call_rate
    return 0 if !@battle.bss_sos_enabled
    cfg=@battle.bss_sos_config.is_a?(Hash) ? @battle.bss_sos_config : {}
    direct=cfg["callRate"]
    return [[direct.to_i,0].max,100].min if !direct.nil? && direct.to_s!=""
    profile=@battle.bss_sos_profile(self)
    return 0 if !profile
    [[profile["callRate"].to_i,0].max,100].min
  end

  def bss_can_sos_call?
    return false if !@battle.bss_sos_enabled || @battle.trainerBattle?
    return false if !(wild? rescue false) || !opposes? || fainted? || usingMultiTurnAttack?
    return false if @battle.bss_live_same_side_count(@index)>=2
    return false if respond_to?(:pbHasAnyStatus?) && pbHasAnyStatus?
    return false if bss_sos_call_rate<=0
    return false if @battle.bss_sos_limit_one? && @battle.bss_last_call_answered && !@battle.bss_adrenaline_orb
    rate=bss_sos_call_rate
    rate*=5 if hp<=totalhp/4
    rate*=3 if hp>totalhp/4 && hp<=totalhp/2
    rate*=2 if @battle.bss_adrenaline_orb
    @battle.pbRandom(100)<[rate,100].min
  end

  def bss_can_sos_call_simple?
    return false if !@battle.bss_sos_enabled || @battle.trainerBattle?
    return false if !(wild? rescue false) || !opposes? || fainted? || usingMultiTurnAttack?
    @battle.bss_live_same_side_count(@index)<2
  end
end

#===============================================================================
# Scene-side dynamic battler support.
# Enhanced Battle UI assumes every live battler has info_icon#{index}. BSS creates
# that icon at the same point as the supplied SOS scene code and also performs a
# defensive sync immediately before Enhanced UI hides its UI.
#===============================================================================
class Battle::Scene
  def bss_ensure_enhanced_ui_icon(idx_battler)
    battler = @battle.battlers[idx_battler] rescue nil
    return false if !battler || !@sprites.is_a?(Hash)
    key = "info_icon#{idx_battler}"
    return true if @sprites[key]
    return false if !defined?(PokemonIconSprite)
    # Only create these compatibility icons when Enhanced Battle UI is present.
    return false if !respond_to?(:pbHideInfoUI) && !@sprites["enhancedUI"]
    icon = PokemonIconSprite.new(battler.pokemon, @viewport)
    icon.setOffset(PictureOrigin::CENTER) if defined?(PictureOrigin) && icon.respond_to?(:setOffset)
    icon.visible = false
    icon.z = 300 if icon.respond_to?(:z=)
    @sprites[key] = icon
    begin
      pbAddSpriteOutline([key, @viewport, battler.pokemon, PictureOrigin::CENTER]) if respond_to?(:pbAddSpriteOutline) && defined?(PictureOrigin)
    rescue
    end
    true
  rescue => e
    BSS064.log("Enhanced UI icon warning idx=#{idx_battler}: #{e.class}: #{e.message}")
    false
  end

  def bss_sync_enhanced_ui_icons
    return if !@battle
    @battle.allBattlers.each { |b| bss_ensure_enhanced_ui_icon(b.index) if b }
  rescue => e
    BSS064.log("Enhanced UI sync warning: #{e.class}: #{e.message}")
  end

  def bss_pbPrepNewBattler(idx_battler)
    pbRefresh
    battler = @battle.battlers[idx_battler]
    add_new_battler = !@sprites["dataBox_#{idx_battler}"]
    if add_new_battler
      begin
        @sprites["targetWindow"].dispose if @sprites["targetWindow"] && !@sprites["targetWindow"].disposed?
      rescue
      end
      if defined?(TargetMenu)
        @sprites["targetWindow"] = TargetMenu.new(@viewport, 200, @battle.sideSizes)
        @sprites["targetWindow"].visible = false
      end
      pbCreatePokemonSprite(idx_battler)
      bss_ensure_enhanced_ui_icon(idx_battler)
    else
      begin
        @sprites["pokemon_#{idx_battler}"].dispose if @sprites["pokemon_#{idx_battler}"]
      rescue
      end
      begin
        @sprites["shadow_#{idx_battler}"].dispose if @sprites["shadow_#{idx_battler}"]
      rescue
      end
      pbCreatePokemonSprite(idx_battler)
    end
    @sprites["pokemon_#{idx_battler}"].visible = false if @sprites["pokemon_#{idx_battler}"]
    @sprites["shadow_#{idx_battler}"].visible = false if @sprites["shadow_#{idx_battler}"]
    side_size = @battle.pbSideSize(idx_battler)
    @battle.allSameSideBattlers(idx_battler).each do |b|
      bat_sprite = @sprites["pokemon_#{b.index}"]
      sha_sprite = @sprites["shadow_#{b.index}"]
      bat_sprite.sideSize = side_size if bat_sprite && bat_sprite.respond_to?(:sideSize=)
      sha_sprite.sideSize = side_size if sha_sprite && sha_sprite.respond_to?(:sideSize=)
      if add_new_battler
        begin
          @sprites["dataBox_#{b.index}"].dispose if @sprites["dataBox_#{b.index}"]
        rescue
        end
        @sprites["dataBox_#{b.index}"] = PokemonDataBox.new(b, side_size, @viewport)
      else
        box = @sprites["dataBox_#{b.index}"]
        if box
          box.battler = b if box.respond_to?(:battler=)
          box.visible = bat_sprite.visible if bat_sprite
          box.refresh if box.respond_to?(:refresh)
        end
      end
      @sprites["dataBox_#{b.index}"].update if @sprites["dataBox_#{b.index}"]
      bss_ensure_enhanced_ui_icon(b.index)
    end
    bss_sync_enhanced_ui_icons
    add_new_battler
  end

  def bss_pbSOSJoin(idx_battler)
    add_new_battler = bss_pbPrepNewBattler(idx_battler)
    battler = @battle.battlers[idx_battler]
    pbChangePokemon(idx_battler, battler.displayPokemon)
    sos_anim = Battle::Scene::Animation::BSSSOSJoin.new(@sprites, @viewport, @battle, battler.index, add_new_battler)
    @animations.push(sos_anim)
    while inPartyAnimation?
      pbUpdate
    end
    if @battle.showAnims && battler.shiny?
      begin
        pbCommonAnimation("Shiny", battler)
      rescue
      end
    end
    bss_sync_enhanced_ui_icons
  end
end

class Battle::Scene::BattlerSprite < RPG::Sprite
  attr_accessor :sideSize unless method_defined?(:sideSize)
end
class Battle::Scene::BattlerShadowSprite < RPG::Sprite
  attr_accessor :sideSize unless method_defined?(:sideSize)
end

class Battle::Scene::Animation::BSSSOSJoin < Battle::Scene::Animation
  def initialize(sprites, viewport, battle, idx_sos, add_new)
    @battle = battle
    @idx_sos = idx_sos
    @add_new = add_new
    super(sprites, viewport)
  end

  def createProcesses
    delay = 0
    @battle.battlers.each do |b|
      next if !b || b.opposes?(@idx_sos)
      bat = @sprites["pokemon_#{b.index}"]
      sha = @sprites["shadow_#{b.index}"]
      boxsp = @sprites["dataBox_#{b.index}"]
      next if !bat
      if b.index == @idx_sos
        obj = addSprite(bat, PictureOrigin::BOTTOM)
        obj.setTone(delay, Tone.new(-196, -196, -196, -196))
        obj.setOpacity(delay, 0)
        obj.setVisible(delay, true)
        obj.moveOpacity(delay, 4, 255)
        obj.moveTone(delay + 4, 10, Tone.new(0, 0, 0, 0), [bat, :pbPlayIntroAnimation])
        if sha
          sha.visible = false
          sh = addSprite(sha, PictureOrigin::CENTER)
          sh.setOpacity(delay, 0)
          sh.setVisible(delay, true)
          sh.moveOpacity(delay, 4, 255)
        end
        if boxsp
          dir = b.index.even? ? 1 : -1
          bx = addSprite(boxsp)
          bx.setDelta(delay, dir * Graphics.width / 2, 0)
          bx.setVisible(delay, true)
          bx.moveDelta(delay, 8, -dir * Graphics.width / 2, 0)
        end
      else
        pos = Battle::Scene.pbBattlerPosition(b.index, @battle.pbSideSize(b.index))
        obj = addSprite(bat, PictureOrigin::BOTTOM)
        obj.moveXY(delay, 4, pos[0], pos[1])
        if sha
          sh = addSprite(sha, PictureOrigin::CENTER)
          sh.moveXY(delay, 4, pos[0], pos[1])
        end
        if boxsp
          bx = addSprite(boxsp)
          bx.setVisible(delay, true) if !b.fainted?
        end
      end
      delay += 1
    end
  end
end

# Run before Enhanced Battle UI's pbHideInfoUI loop. It expects a non-nil icon
# for every battler returned by allBattlers, including the newly inserted SOS.
module BSS064EnhancedUICompat
  def pbHideInfoUI(*args)
    bss_sync_enhanced_ui_icons if respond_to?(:bss_sync_enhanced_ui_icons)
    super
  end
end

module BSS064
  class << self
    def install_enhanced_ui_compat
      return false if !defined?(Battle::Scene)
      return false if !Battle::Scene.method_defined?(:pbHideInfoUI)
      return true if Battle::Scene.ancestors.include?(BSS064EnhancedUICompat)
      Battle::Scene.prepend(BSS064EnhancedUICompat)
      true
    rescue => e
      log("Enhanced UI compat install warning: #{e.class}: #{e.message}")
      false
    end
  end
end
BSS064.install_enhanced_ui_compat
if defined?(EventHandlers)
  EventHandlers.add(:on_game_load, :bss_064_enhanced_ui_compat, proc { BSS064.install_enhanced_ui_compat })
end

class Battle::Move
  unless method_defined?(:bss064_effectiveness_without_sos_flag)
    alias bss064_effectiveness_without_sos_flag pbEffectivenessMessage
    def pbEffectivenessMessage(user, target, numTargets = 1)
      bss064_effectiveness_without_sos_flag(user, target, numTargets)
      return if !target || !(target.wild? rescue false)
      ds = target.damageState rescue nil
      return if !ds
      return if (ds.disguise rescue false) || (ds.iceFace rescue false)
      target.bss_took_super_effective_damage = true if Effectiveness.super_effective?(ds.typeMod) rescue nil
    end
  end
end

if defined?(ItemHandlers) && defined?(GameData::Item) && (GameData::Item.exists?(:ADRENALINEORB) rescue false)
  ItemHandlers::CanUseInBattle.add(:ADRENALINEORB, proc { |_item, _pokemon, _battler, _move, _firstAction, _battle, _scene, _showMessages| next true })
  ItemHandlers::UseInBattle.add(:ADRENALINEORB, proc { |item, battler, battle|
    if battle.bss_adrenaline_orb
      battle.pbDisplay(_INTL("¡Pero no tuvo efecto!"))
      battle.pbReturnUnusedItemToBag(item, battler.index) rescue nil
    else
      battle.pbDisplay(_INTL("¡El {1} pone nervioso al Pokémon salvaje!", GameData::Item.get(item).portion_name))
      battle.bss_adrenaline_orb = true
    end
  })
end
