#===============================================================================
# Golden Power / Golden Form - configuration from Data/GoldenSystem/*.json
#===============================================================================
module GoldenSystem
  VERSION = "2.6.7"
  DEFAULT_ACTIVATION_LIMIT   = 1
  # Fragment/Stone activation requires the trainer to own the Golden Ring.
  # A trainer profile can still explicitly bypass this requirement.
  REQUIRE_GOLDEN_RING        = true
  GOLDEN_RING_ITEM           = :GOLDENSRING
  GOLDEN_FRAGMENT_ITEM       = :GOLDENFRAGMENT
  GOLDEN_STONE_ITEM          = :GOLDENSTONE
  POWER_BOOST_STAGES         = 3
  POWER_PENALTY_STAGES       = 2
  SAME_TYPE_POWER_MULTIPLIER = 1.20
  FORM_HP_DRAIN_NUMERATOR    = 1
  FORM_HP_DRAIN_DENOMINATOR  = 4
  BATTLE_STATS = [:ATTACK,:DEFENSE,:SPECIAL_ATTACK,:SPECIAL_DEFENSE,:SPEED]

  @settings_cache=nil
  def self.settings
    return @settings_cache if @settings_cache
    doc=CarnekStandaloneJSON.load(SETTINGS_JSON,{})
    s=doc["settings"].is_a?(Hash) ? doc["settings"] : doc
    ret={
      :default_activation_limit=>DEFAULT_ACTIVATION_LIMIT,
      :require_golden_ring=>REQUIRE_GOLDEN_RING,
      :power_boost_stages=>POWER_BOOST_STAGES,
      :power_penalty_stages=>POWER_PENALTY_STAGES,
      :same_type_multiplier=>SAME_TYPE_POWER_MULTIPLIER,
      :form_hp_drain=>FORM_HP_DRAIN_NUMERATOR.to_f/FORM_HP_DRAIN_DENOMINATOR
    }
    ret[:default_activation_limit]=[s["defaultActivationLimit"].to_i,0].max if s.key?("defaultActivationLimit")
    # Ringless activation is opt-in; legacy JSON with requireGoldenRing:false
    # must not silently make Fragment/Stone usable without the Ring.
    ret[:require_golden_ring]=false if s["allowRingless"] == true
    ret[:power_boost_stages]=[[s["powerBoost"].to_i,1].max,6].min if s.key?("powerBoost")
    ret[:power_penalty_stages]=[[s["powerPenalty"].to_i.abs,1].max,6].min if s.key?("powerPenalty")
    ret[:same_type_multiplier]=[s["sameTypeMultiplier"].to_f,1.0].max if s.key?("sameTypeMultiplier")
    if s.key?("formHPDrain")
      v=s["formHPDrain"].to_f
      ret[:form_hp_drain]=[[v,0.0].max,1.0].min
    end
    @settings_cache=ret
  end

  def self.reload!
    @settings_cache=nil
    Data.reload! if defined?(Data)
    TrainerProfiles.reload!
    GoldenMoves.reload!
  end

  module TrainerProfiles
    @cache=nil
    def self.reload!; @cache=nil; end

    def self.normalize_mode(value)
      mode=value.to_s.upcase.to_sym
      return mode if [:POWER,:FORM,:EITHER,:STACKED].include?(mode)
      return :EITHER
    end

    def self.normalize_rule(value, fallback=:INHERIT)
      rule=value.to_s.upcase.to_sym
      return rule if [:INHERIT,:REQUIRE,:IGNORE].include?(rule)
      return fallback
    end

    def self.normalize_assignment(raw)
      return nil if !raw.is_a?(Hash)
      species=raw["species"].to_s.upcase
      return nil if species.empty?
      form=nil
      if raw.key?("form") && !raw["form"].nil? && raw["form"].to_s != "*"
        form=raw["form"].to_i
      end
      slot=raw["partySlot"].to_i
      slot=nil if slot <= 0
      item_rule=normalize_rule(raw["itemRule"], raw["ignoreItem"] ? :IGNORE : :INHERIT)
      ring_rule=normalize_rule(raw["ringRule"], raw["ignoreRing"] ? :IGNORE : :INHERIT)
      return {
        :species       => species,
        :form          => form,
        :party_slot    => slot,
        :mode          => normalize_mode(raw["mode"]),
        :item_rule     => item_rule,
        :ring_rule     => ring_rule,
        :auto_activate => raw.key?("autoActivate") ? !!raw["autoActivate"] : true
      }
    end

    def self.all
      return @cache if @cache
      @cache={}
      doc=CarnekStandaloneJSON.load(GoldenSystem::TRAINERS_JSON,{"trainers"=>{}})
      rows=doc["trainers"].is_a?(Hash) ? doc["trainers"] : {}
      rows.each do |raw_key,value|
        next unless value.is_a?(Hash)
        parts=raw_key.to_s.split("|")
        next if parts.empty?
        key=[parts[0].to_s.upcase,(parts[1]||"*").to_s,(parts[2]||"0").to_i]
        assignments=[]
        if value["assignments"].is_a?(Array)
          value["assignments"].each do |raw|
            assignment=normalize_assignment(raw)
            assignments << assignment if assignment
          end
        end
        @cache[key]={
          :limit                => [value["activationLimit"].to_i,0].max,
          :unlimited            => !!value["unlimited"],
          :default_ignore_item  => !!value["defaultIgnoreItem"],
          :default_ignore_ring  => !!value["defaultIgnoreRing"],
          :restrict_assignments => value.key?("restrictAssignments") ? !!value["restrictAssignments"] : false,
          :assignments          => assignments
        }
      end
      return @cache
    end

    def self.for_owner(owner)
      return nil if !owner
      trainer_type=owner.respond_to?(:trainer_type) ? owner.trainer_type : (owner.respond_to?(:trainer_type_id) ? owner.trainer_type_id : nil)
      return nil if !trainer_type
      name=owner.respond_to?(:name) ? owner.name.to_s : ""
      version=owner.respond_to?(:version) ? owner.version.to_i : 0
      [[trainer_type.to_s.upcase,name,version],[trainer_type.to_s.upcase,name,0],[trainer_type.to_s.upcase,"*",version],[trainer_type.to_s.upcase,"*",0]].each do |key|
        value=all[key]
        return value if value
      end
      return nil
    end

    def self.assignment_allows_mode?(assignment, mechanic)
      return false if !assignment
      mode=assignment[:mode]
      return true if mode==:EITHER || mode==:STACKED
      return mode==mechanic
    end

    def self.assignment_for(profile, pokemon, party_slot=nil, mechanic=nil)
      return nil if !profile || !pokemon
      species=pokemon.species.to_s.upcase
      source_form=(pokemon.respond_to?(:golden_source_form) ? pokemon.golden_source_form : pokemon.form).to_i
      matches=(profile[:assignments] || []).select do |assignment|
        next false if assignment[:species] != species
        next false if !assignment[:form].nil? && assignment[:form].to_i != source_form
        next false if assignment[:party_slot] && (!party_slot || assignment[:party_slot].to_i != party_slot.to_i)
        next false if mechanic && !assignment_allows_mode?(assignment,mechanic)
        true
      end
      matches.sort_by! do |assignment|
        [assignment[:party_slot] ? 0 : 1, assignment[:form].nil? ? 1 : 0]
      end
      return matches[0]
    end
  end
end
