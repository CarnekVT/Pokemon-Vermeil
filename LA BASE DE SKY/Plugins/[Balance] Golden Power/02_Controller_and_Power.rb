#===============================================================================
# Shared Golden activation controller + Golden Power
# Desbordamiento v2.6: limits, item bypass and per-Pokémon assignments.
#===============================================================================
class Battle
  def pbGoldenUsageKey(idxBattler)
    battler=@battlers[idxBattler]
    return nil if !battler
    return [battler.idxOwnSide,pbGetOwnerIndexFromBattlerIndex(idxBattler)]
  end

  def pbGoldenPartySlot(idxBattler)
    battler=@battlers[idxBattler]
    return nil if !battler || !battler.pokemon
    if battler.respond_to?(:pokemonIndex)
      value=battler.pokemonIndex rescue nil
      return value.to_i+1 if !value.nil?
    end
    begin
      party=pbParty(idxBattler)
      index=party.index(battler.pokemon) if party
      return index+1 if index
    rescue StandardError
    end
    return nil
  end

  def pbGoldenUsageEntry(idxBattler)
    key=pbGoldenUsageKey(idxBattler)
    return nil if !key
    @golden_usage||={}
    if !@golden_usage[key]
      owner=pbGetOwnerFromBattlerIndex(idxBattler) rescue nil
      profile=GoldenSystem::TrainerProfiles.for_owner(owner)
      @golden_usage[key]={
        :used      => 0,
        :limit     => (profile && profile[:limit]) || GoldenSystem.settings[:default_activation_limit],
        :unlimited => (profile && profile[:unlimited]) || false,
        :history   => [],
        :profile   => profile
      }
    end
    return @golden_usage[key]
  end

  def pbGoldenProfile(idxBattler)
    entry=pbGoldenUsageEntry(idxBattler)
    return entry ? entry[:profile] : nil
  end

  def pbGoldenAssignmentFor(idxBattler, mechanic=nil)
    battler=@battlers[idxBattler]
    return nil if !battler || !battler.pokemon
    profile=pbGoldenProfile(idxBattler)
    return nil if !profile
    return GoldenSystem::TrainerProfiles.assignment_for(profile,battler.pokemon,pbGoldenPartySlot(idxBattler),mechanic)
  end

  def pbGoldenAssignmentsRestricted?(idxBattler)
    profile=pbGoldenProfile(idxBattler)
    return false if !profile
    return false if !(profile[:assignments].is_a?(Array)) || profile[:assignments].empty?
    return !!profile[:restrict_assignments]
  end

  def pbGoldenLimit(idxBattler)
    entry=pbGoldenUsageEntry(idxBattler)
    return 0 if !entry
    return -1 if entry[:unlimited]
    return entry[:limit]
  end

  def pbGoldenUsesLeft(idxBattler)
    entry=pbGoldenUsageEntry(idxBattler)
    return 0 if !entry
    return 999 if entry[:unlimited]
    return [entry[:limit]-entry[:used],0].max
  end

  def pbGoldenCanConsumeCount?(idxBattler, count=1)
    entry=pbGoldenUsageEntry(idxBattler)
    return false if !entry
    return true if entry[:unlimited]
    return entry[:used]+[count.to_i,0].max <= entry[:limit]
  end

  def pbSetGoldenLimit(idxBattler, limit)
    entry=pbGoldenUsageEntry(idxBattler)
    return false if !entry
    entry[:limit]=[limit.to_i,0].max
    entry[:unlimited]=false
    return true
  end

  def pbSetGoldenUnlimited(idxBattler, value=true)
    entry=pbGoldenUsageEntry(idxBattler)
    return false if !entry
    entry[:unlimited]=!!value
    return true
  end

  # Lower-level API for scripted boss battles where no active battler is known yet.
  def pbSetGoldenLimitFor(side, owner, limit, unlimited=false)
    @golden_usage||={}
    key=[side.to_i,owner.to_i]
    @golden_usage[key]||={:used=>0,:limit=>1,:unlimited=>false,:history=>[],:profile=>nil}
    @golden_usage[key][:limit]=[limit.to_i,0].max
    @golden_usage[key][:unlimited]=!!unlimited
    return true
  end

  def pbGoldenHeldItem?(idxBattler, item)
    battler=@battlers[idxBattler]
    return false if !battler
    held=nil
    held=battler.item_id if battler.respond_to?(:item_id)
    held=battler.item if held.nil? && battler.respond_to?(:item)
    return held==item
  rescue StandardError
    return false
  end

  def pbGoldenRuleIgnores?(idxBattler, assignment, kind)
    profile=pbGoldenProfile(idxBattler)
    return false if !profile
    rule=assignment ? assignment[kind==:ITEM ? :item_rule : :ring_rule] : :INHERIT
    return true if rule==:IGNORE
    return false if rule==:REQUIRE
    return kind==:ITEM ? !!profile[:default_ignore_item] : !!profile[:default_ignore_ring]
  end

  def pbHasGoldenRing?(idxBattler, assignment=nil)
    return true if !GoldenSystem.settings[:require_golden_ring]
    return true if pbGoldenRuleIgnores?(idxBattler,assignment,:RING)
    if pbOwnedByPlayer?(idxBattler)
      return $bag && $bag.has?(GoldenSystem::GOLDEN_RING_ITEM)
    end
    trainer_items=pbGetOwnerItems(idxBattler)
    return trainer_items && trainer_items.include?(GoldenSystem::GOLDEN_RING_ITEM)
  end

  def pbHasGoldenActivator?(idxBattler, mechanic, assignment=nil)
    return true if pbGoldenRuleIgnores?(idxBattler,assignment,:ITEM)
    item=(mechanic==:FORM) ? GoldenSystem::GOLDEN_STONE_ITEM : GoldenSystem::GOLDEN_FRAGMENT_ITEM
    return pbGoldenHeldItem?(idxBattler,item)
  end

  def pbCanUseGoldenMechanic?(idxBattler, mechanic, assignment=nil)
    battler=@battlers[idxBattler]
    return false if !battler || battler.fainted?
    mechanic=mechanic.to_sym
    assignment ||= pbGoldenAssignmentFor(idxBattler,mechanic)
    if pbGoldenAssignmentsRestricted?(idxBattler) && !assignment
      return false
    end
    return false if assignment && !GoldenSystem::TrainerProfiles.assignment_allows_mode?(assignment,mechanic)
    return false if !pbHasGoldenRing?(idxBattler,assignment)
    return false if !pbHasGoldenActivator?(idxBattler,mechanic,assignment)
    return false if mechanic==:FORM && !battler.hasGoldenForm?
    return false if mechanic==:POWER && battler.isOnGoldenPower?
    return false if mechanic==:FORM && battler.isOnGoldenForm?
    return pbGoldenCanConsumeCount?(idxBattler,1)
  end

  def pbConsumeGoldenUse(idxBattler, mechanic)
    entry=pbGoldenUsageEntry(idxBattler)
    return false if !entry
    return false if !entry[:unlimited] && entry[:used]>=entry[:limit]
    entry[:used]+=1 if !entry[:unlimited]
    entry[:history] << mechanic
    return true
  end

  # Compatibility with Golden Power v1.x.
  def pbCanGoldenForm?(idxBattler, item=GoldenSystem::GOLDEN_STONE_ITEM)
    mechanic=(item==GoldenSystem::GOLDEN_FRAGMENT_ITEM) ? :POWER : :FORM
    return pbCanUseGoldenMechanic?(idxBattler,mechanic)
  end

  def pbRegisterGoldenForm(idxBattler)
    return pbConsumeGoldenUse(idxBattler,:FORM)
  end

  def pbStartGoldenPower(idxBattler, assignment=nil)
    battler=@battlers[idxBattler]
    return false if !battler
    return true if battler.isOnGoldenPower?
    assignment ||= pbGoldenAssignmentFor(idxBattler,:POWER)
    return false if !pbCanUseGoldenMechanic?(idxBattler,:POWER,assignment)
    battler.pokemon.activateGoldenPower
    pbConsumeGoldenUse(idxBattler,:POWER)
    pbDisplay(_INTL("¡{1} rebosa de Poder Dorado!",battler.pbThis))
    battler.pbApplyGoldenVane(true)
    return true
  end

  # Called when a trainer Overflow profile explicitly assigns the battler.
  # POWER/FORM cost one activation each. STACKED costs two if both layers are new.
  def pbTryGoldenOverflowAssignment(idxBattler)
    battler=@battlers[idxBattler]
    return false if !battler || battler.fainted? || !battler.pokemon
    assignment=pbGoldenAssignmentFor(idxBattler,nil)
    return false if !assignment || !assignment[:auto_activate]
    mode=assignment[:mode]
    case mode
    when :POWER
      return true if battler.isOnGoldenPower?
      return pbStartGoldenPower(idxBattler,assignment)
    when :FORM
      return true if battler.isOnGoldenForm?
      return pbStartGoldenForm(idxBattler,assignment)
    when :EITHER
      return true if battler.isOnGoldenForm? || battler.isOnGoldenPower?
      if battler.hasGoldenForm? && pbCanUseGoldenMechanic?(idxBattler,:FORM,assignment)
        return pbStartGoldenForm(idxBattler,assignment)
      end
      return pbStartGoldenPower(idxBattler,assignment)
    when :STACKED
      missing_form=!battler.isOnGoldenForm?
      missing_power=!battler.isOnGoldenPower?
      cost=(missing_form ? 1 : 0)+(missing_power ? 1 : 0)
      return true if cost<=0
      return false if !pbGoldenCanConsumeCount?(idxBattler,cost)
      # A simultaneous activation cannot satisfy both held activators at once.
      # It is therefore only valid when this assignment/profile bypasses them.
      return false if !pbGoldenRuleIgnores?(idxBattler,assignment,:ITEM)
      if missing_form
        return false if !pbStartGoldenForm(idxBattler,assignment)
      end
      if missing_power
        return false if !pbStartGoldenPower(idxBattler,assignment)
      end
      return true
    end
    return false
  end
end

#===============================================================================
# Golden Power's +3 / -2 "weathervane".
#===============================================================================
class Battle::Battler
  attr_reader :golden_peak_stat
  attr_reader :golden_lag_stat

  def golden_stage_deltas
    @golden_stage_deltas||={}
    return @golden_stage_deltas
  end

  def pbClearGoldenVane
    # This state may not exist yet on a freshly-created battler.  Always create
    # it before pbApplyGoldenVane writes into it.
    @golden_stage_deltas ||= {}
    if @golden_stage_deltas.empty?
      @golden_peak_stat=nil
      @golden_lag_stat=nil
      return
    end
    @golden_stage_deltas.each do |stat,delta|
      next if !@stages.key?(stat)
      @stages[stat]-=delta
      @stages[stat]=[[@stages[stat],-STAT_STAGE_MAXIMUM].max,STAT_STAGE_MAXIMUM].min
    end
    @golden_stage_deltas.clear
    @golden_peak_stat=nil
    @golden_lag_stat=nil
  end

  def pbApplyGoldenVane(show_message=true)
    return false if !isOnGoldenPower? || fainted?
    pbClearGoldenVane
    stats=GoldenSystem::BATTLE_STATS.clone
    # Use the active species proxy so Golden Form base stats are respected.
    base_stats=(@pokemon.species_data.base_stats rescue GameData::Species.get(@pokemon.species).base_stats)
    lag=stats.min_by { |stat| base_stats[stat] || 0 }
    peak_candidates=stats.reject { |stat| stat==lag || @stages[stat]>=STAT_STAGE_MAXIMUM }
    peak_candidates=stats.reject { |stat| stat==lag } if peak_candidates.empty?
    peak=peak_candidates[@battle.pbRandom(peak_candidates.length)]
    boost=GoldenSystem.settings[:power_boost_stages]
    penalty=GoldenSystem.settings[:power_penalty_stages]
    applied_up=[boost,STAT_STAGE_MAXIMUM-@stages[peak]].min
    applied_down=[penalty,STAT_STAGE_MAXIMUM+@stages[lag]].min
    @stages[peak]+=applied_up
    @stages[lag]-=applied_down
    @golden_stage_deltas[peak]=applied_up
    @golden_stage_deltas[lag]=-applied_down
    @golden_peak_stat=peak
    @golden_lag_stat=lag
    if show_message
      peak_name=GameData::Stat.get(peak).name
      lag_name=GameData::Stat.get(lag).name
      @battle.pbCommonAnimation("StatUp",self)
      @battle.pbDisplay(_INTL("¡El Poder Dorado de {1} lleva su {2} al cénit, pero sacrifica su {3}!",pbThis,peak_name,lag_name))
    end
    return true
  end

  # Power ends on switch/KO, but Overflow may pay another activation later.
  def pbEndGoldenPower
    return false if !isOnGoldenPower?
    pbClearGoldenVane
    @pokemon.deactivateGoldenPower if @pokemon && @pokemon.respond_to?(:deactivateGoldenPower)
    return true
  end
end

module GoldenSystem
  module BattleGoldenPowerSwitchLifecycle
    def pbRecallAndReplace(idxBattler,*args,&block)
      battler=@battlers[idxBattler] rescue nil
      battler.pbEndGoldenPower if battler && battler.isOnGoldenPower?
      return super
    end
  end

  module BattlerGoldenPowerFaintLifecycle
    def pbFaint(*args,&block)
      pbEndGoldenPower if isOnGoldenPower?
      return super
    end
  end

  module BattlerResetStages
    def pbResetStatStages
      ret=super
      @golden_stage_deltas={}
      @golden_peak_stat=nil
      @golden_lag_stat=nil
      return ret
    end
  end

  module BattlerTypes
    def pbTypes(withExtraType=false)
      # Avoid SystemStackError when another battle hook asks for pbTypes while
      # Golden Form/species data is being resolved.
      return (@__golden_pb_types_base || []) if @__golden_pb_types_busy
      @__golden_pb_types_busy=true
      ret=super
      if !@pokemon
        @__golden_pb_types_base=ret
        return ret
      end

      # Golden Form uses a dynamic GameData::Species proxy.  Other battle
      # systems may keep the battler's old typing cached, so force the first
      # two battle types to match the active Golden Form while preserving any
      # temporary extra type appended by Essentials/other plugins.
      if isOnGoldenForm?
        begin
          form_types=@pokemon.species_data.types
          # Enhanced battle hooks can return only their replacement type.  For
          # Golden Form, rebuild the core from the original species/form so a
          # Heracross Bicho/Lucha becomes Bicho/Dragón, not only Dragón.
          if @pokemon.respond_to?(:pre_golden_form) && !@pokemon.pre_golden_form.nil?
            source_data=GameData::Species.get_species_form(@pokemon.species,@pokemon.pre_golden_form) rescue nil
            source_types=source_data.types if source_data && source_data.respond_to?(:types)
            form_types=source_types if source_types && source_types.length>=2
            golden=@pokemon.golden_type
            if golden && GameData::Type.exists?(golden) && form_types && !form_types.include?(golden)
              core=form_types[0,2].clone
              replace=@pokemon.golden_type_replace
              idx=replace ? core.index(replace) : nil
              idx=1 if idx.nil? && core.length>1
              if idx && core.length>1
                core[idx]=golden
              else
                core << golden
              end
              form_types=core
            end
          end
          if form_types && !form_types.empty?
            extra=(ret.length>2) ? ret[2..-1].clone : []
            ret=(form_types[0,2]+extra).compact.uniq
          end
        rescue StandardError
        end
      end

      # Golden Power overlays its Golden Type after the form typing has been
      # resolved, which also keeps STACKED Power + Form behaviour coherent.
      if !isOnGoldenPower?
        @__golden_pb_types_base=ret
        return ret
      end
      golden_type=@pokemon.golden_type
      if !golden_type || !GameData::Type.exists?(golden_type)
        @__golden_pb_types_base=ret
        return ret
      end
      core=ret[0,2].clone
      extra=(ret.length>2) ? ret[2..-1].clone : []
      if core.include?(golden_type)
        @__golden_pb_types_base=ret
        return ret
      end
      if core.length<=1
        core << golden_type
      else
        replace=@pokemon.golden_type_replace
        idx=replace ? core.index(replace) : nil
        idx=1 if idx.nil?
        core[idx]=golden_type
      end
      ret=(core+extra).compact.uniq
      @__golden_pb_types_base=ret
      return ret
    ensure
      @__golden_pb_types_busy=false
    end
  end

  # Essentials v21 switch-in hook. Runs after normal held-item/ability effects,
  # then applies explicit boss Overflow assignments that can bypass activators.
  module BattlerOverflowSwitchInLifecycle
    def pbEffectsOnSwitchIn(*args,&block)
      ret=super
      begin
        @battle.pbTryGoldenOverflowAssignment(@index) if @battle
      rescue StandardError => e
        echoln("[GoldenSystem] Overflow switch-in: #{e.class}: #{e.message}") if defined?(echoln)
      end
      return ret
    end
  end


  module BattlerOverflowAbilitySwitchInFallback
    def pbAbilitiesOnSwitchIn(*args,&block)
      ret=super
      begin
        @battle.pbTryGoldenOverflowAssignment(@index) if @battle
      rescue StandardError => e
        echoln("[GoldenSystem] Overflow ability switch-in: #{e.class}: #{e.message}") if defined?(echoln)
      end
      return ret
    end
  end

  # Itemless Overflow still needs the normal end-of-round mechanics. Held-item
  # users continue through ItemEffects, so this hook only services missing items.
  module BattleGoldenItemlessEndOfRound
    def pbEndOfRoundPhase(*args,&block)
      ret=super
      @battlers.each do |battler|
        next if !battler || battler.fainted?
        if battler.isOnGoldenPower? && !pbGoldenHeldItem?(battler.index,GoldenSystem::GOLDEN_FRAGMENT_ITEM)
          battler.pbApplyGoldenVane(true)
        end
        if battler.isOnGoldenForm? && !pbGoldenHeldItem?(battler.index,GoldenSystem::GOLDEN_STONE_ITEM)
          pbApplyGoldenFormDrain(battler) if respond_to?(:pbApplyGoldenFormDrain)
        end
      end
      return ret
    end
  end
end

Battle.prepend(GoldenSystem::BattleGoldenPowerSwitchLifecycle)
Battle::Battler.prepend(GoldenSystem::BattlerGoldenPowerFaintLifecycle)
Battle::Battler.prepend(GoldenSystem::BattlerResetStages)
Battle::Battler.prepend(GoldenSystem::BattlerTypes)
if Battle::Battler.method_defined?(:pbEffectsOnSwitchIn)
  Battle::Battler.prepend(GoldenSystem::BattlerOverflowSwitchInLifecycle)
elsif Battle::Battler.method_defined?(:pbAbilitiesOnSwitchIn)
  Battle::Battler.prepend(GoldenSystem::BattlerOverflowAbilitySwitchInFallback)
end
if Battle.method_defined?(:pbEndOfRoundPhase)
  Battle.prepend(GoldenSystem::BattleGoldenItemlessEndOfRound)
end

#===============================================================================
# Held-item activation. Assignment restrictions are checked inside pbStart...
#===============================================================================
Battle::ItemEffects::OnSwitchIn.add(
  GoldenSystem::GOLDEN_FRAGMENT_ITEM,
  proc do |item,battler,battle|
    battle.pbStartGoldenPower(battler.index)
  end
)

Battle::ItemEffects::EndOfRoundEffect.add(
  GoldenSystem::GOLDEN_FRAGMENT_ITEM,
  proc do |item,battler,battle|
    next if battler.fainted? || !battler.isOnGoldenPower?
    battler.pbApplyGoldenVane(true)
  end
)
