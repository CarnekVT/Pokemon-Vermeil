#===============================================================================
# Golden species runtime. JSON is authoritative; old PBS fields are read-only
# fallback for migration compatibility.
#===============================================================================
module GoldenSystem
  module LegacySpeciesSchema
    def schema(compiling_forms=false)
      ret=super
      ret["GoldenForm"]        ||= [:golden_form,"u"]
      ret["GoldenType"]        ||= [:golden_type,"e",:Type]
      ret["GoldenTypeReplace"] ||= [:golden_type_replace,"e",:Type]
      ret
    end
  end
  module LegacySpeciesInitialize
    def initialize(hash)
      super
      @golden_form=hash[:golden_form]
      @golden_type=hash[:golden_type]
      @golden_type_replace=hash[:golden_type_replace]
    end
  end
end
module GameData
  class Species
    attr_reader :golden_form, :golden_type, :golden_type_replace
  end
end
GameData::Species.singleton_class.prepend(GoldenSystem::LegacySpeciesSchema)
GameData::Species.prepend(GoldenSystem::LegacySpeciesInitialize)

class Pokemon
  attr_accessor :pre_golden_form
  attr_accessor :golden_power_overlay

  def golden_state
    if !defined?(@golden_state) || @golden_state.nil?
      @golden_state=(defined?(@goldenState) && @goldenState) ? :POWER : :NONE
    end
    @golden_state
  end
  def golden_state=(value)
    value=value.to_sym if value.respond_to?(:to_sym)
    @golden_state=[:NONE,:POWER,:FORM].include?(value) ? value : :NONE
    @goldenState=(@golden_state != :NONE)
  end
  def goldenState; golden_state != :NONE; end
  def goldenState=(value); self.golden_state=value ? :POWER : :NONE; end
  def golden_source_form
    return @pre_golden_form if golden_state==:FORM && !@pre_golden_form.nil?
    form
  end
  def legacy_golden_value(method_name)
    data=nil
    begin; data=GameData::Species.get_species_form(@species,golden_source_form); rescue StandardError; end
    value=data.send(method_name) if data && data.respond_to?(method_name)
    return value if !value.nil?
    if golden_source_form.to_i != 0
      base=GameData::Species.get(@species) rescue nil
      return base.send(method_name) if base && base.respond_to?(method_name)
    end
    nil
  end
  def getGoldenForm
    value=GoldenSystem::Data.form_number(@species,golden_source_form)
    value ||= legacy_golden_value(:golden_form)
    value.nil? ? nil : value.to_i
  end
  def golden_form_definition
    GoldenSystem::Data.form_definition(@species,golden_source_form)
  end
  def golden_type
    GoldenSystem::Data.golden_type(@species,golden_source_form) || legacy_golden_value(:golden_type)
  end
  def golden_type_replace
    GoldenSystem::Data.golden_type_replace(@species,golden_source_form) || legacy_golden_value(:golden_type_replace)
  end
  def hasGoldenForm?; !getGoldenForm.nil? && getGoldenForm.to_i>0; end
  def activateGoldenPower
    if golden_state==:FORM
      @golden_power_overlay=true
    else
      self.golden_state=:POWER
    end
  end
  def deactivateGoldenPower
    if golden_state==:FORM
      @golden_power_overlay=false
    elsif golden_state==:POWER
      self.golden_state=:NONE
    end
  end
  def makeGolden
    target=getGoldenForm; return false if !target || target.to_i<=0
    had_power=(golden_state==:POWER || !!@golden_power_overlay)
    @pre_golden_form=self.form if golden_state != :FORM
    self.golden_state=:FORM
    @golden_power_overlay=true if had_power
    self.form=target.to_i
    calc_stats if respond_to?(:calc_stats)
    true
  end
  def makeUnGolden
    if golden_state==:FORM && !@pre_golden_form.nil?
      source=@pre_golden_form
      self.golden_state=:NONE
      self.form=source
      calc_stats if respond_to?(:calc_stats)
    else
      self.golden_state=:NONE
    end
    @pre_golden_form=nil
    @golden_power_overlay=false
  end
  def isOnGoldenPower?; golden_state==:POWER || (golden_state==:FORM && !!@golden_power_overlay); end
  def isOnGoldenForm?; golden_state==:FORM && !getGoldenForm.nil? && self.form==getGoldenForm; end
end

module GoldenSystem
  module PokemonDynamicGoldenSpeciesData
    def species_data
      if respond_to?(:golden_state) && golden_state==:FORM && respond_to?(:pre_golden_form) && !pre_golden_form.nil?
        definition=GoldenSystem::Data.form_definition(@species,pre_golden_form)
        if definition && form.to_i==definition["number"].to_i
          return GoldenSystem::Data.build_form_proxy(@species,pre_golden_form,form,definition)
        end
      end
      super
    end
  end
end
Pokemon.prepend(GoldenSystem::PokemonDynamicGoldenSpeciesData)

class Battle::Battler
  def hasGoldenForm?; @pokemon && @pokemon.hasGoldenForm?; end
  def isOnGoldenPower?; @pokemon && @pokemon.isOnGoldenPower?; end
  def isOnGoldenForm?; @pokemon && @pokemon.isOnGoldenForm?; end
end

EventHandlers.add(:on_end_battle,:golden_system_restore_forms,proc do |decision,canLose|
  next if !$player
  $player.party.each{|pkmn| pkmn.makeUnGolden if pkmn}
end)
