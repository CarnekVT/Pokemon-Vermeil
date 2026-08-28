#===============================================================================
# Battle Scene Studio Runtime 0.6.25
# Basic BSS-native Boss/Totem layer.
# - One configured foe can act as the Boss/Totem.
# - A custom encounter line can replace the first native intro line.
# - An opening aura applies configurable stat stages once the battler is active.
# - SOS allies remain owned by 002_NativeSOS.rb; this file does not duplicate SOS.
#===============================================================================
module BSS064
  class << self
    def configure_native_boss(battle, bp)
      cfg = hget(bp, "boss")
      cfg = {} if !cfg.is_a?(Hash)
      battle.bss_boss_config = cfg if battle.respond_to?(:bss_boss_config=)
      battle.bss_boss_applied = false if battle.respond_to?(:bss_boss_applied=)
      battle.bss_boss_intro_pending = false if battle.respond_to?(:bss_boss_intro_pending=)
      battle.bss_boss_intro_shown = false if battle.respond_to?(:bss_boss_intro_shown=)
    rescue => e
      log("Boss configure failed: #{e.class}: #{e.message}")
    end
  end
end

class Battle
  attr_accessor :bss_boss_config
  attr_accessor :bss_boss_applied
  attr_accessor :bss_boss_intro_pending
  attr_accessor :bss_boss_intro_shown

  def bss_boss_enabled?
    @bss_boss_config.is_a?(Hash) && @bss_boss_config["enabled"] == true
  end

  def bss_boss_target_party_index
    cfg = @bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    [cfg["foeIndex"].to_i, 0].max
  end

  def bss_find_boss_battler
    wanted = bss_boss_target_party_index
    rows = @battlers.is_a?(Array) ? @battlers : []
    rows.compact.find do |b|
      next false if !b
      next false if (b.fainted? rescue false)
      idx = (b.index rescue -1).to_i
      next false if idx < 0 || idx.even?
      party_idx = (b.pokemonIndex rescue 0).to_i
      party_idx == wanted
    end
  rescue
    nil
  end

  def bss_boss_name_for_intro
    begin
      party = pbParty(1)
      idx = bss_boss_target_party_index
      pkmn = party[idx] || party[0]
      return pkmn.name.to_s if pkmn
    rescue
    end
    battler = bss_find_boss_battler
    return battler.name.to_s if battler && battler.respond_to?(:name)
    "Pokémon"
  end

  def bss_boss_message(template, battler = nil)
    text = template.to_s
    return "" if text.empty?
    name = if battler
      begin
        battler.pbThis
      rescue
        battler.name.to_s
      end
    else
      bss_boss_name_for_intro
    end
    text.gsub("{1}", name.to_s)
  end

  def bss_boss_encounter_message
    return "" if !bss_boss_enabled?
    cfg = @bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    bss_boss_message(cfg["encounterMessage"], nil)
  end

  def bss_apply_boss_stat_stage(battler, stat, delta)
    amount = [[delta.to_i, -6].max, 6].min
    return if amount == 0 || !battler
    stages = battler.respond_to?(:stages) ? battler.stages : nil
    return if !stages || !stages.respond_to?(:[]) || !stages.respond_to?(:[]=)
    key = stat.to_s.upcase.to_sym
    current = stages[key].to_i
    stages[key] = [[current + amount, -6].max, 6].min
  rescue => e
    BSS064.log("Boss stat #{stat} failed: #{e.class}: #{e.message}")
  end

  def bss_apply_boss_opening
    return if @bss_boss_applied
    return if !bss_boss_enabled?
    battler = bss_find_boss_battler
    return if !battler
    cfg = @bss_boss_config
    if !@bss_boss_intro_shown
      intro = bss_boss_encounter_message
      if !intro.empty? && respond_to?(:pbDisplay)
        pbDisplay(intro)
        @bss_boss_intro_shown = true
      end
    end
    stats = cfg["stats"].is_a?(Hash) ? cfg["stats"] : {}
    ["ATTACK", "DEFENSE", "SPECIAL_ATTACK", "SPECIAL_DEFENSE", "SPEED", "ACCURACY", "EVASION"].each do |stat|
      bss_apply_boss_stat_stage(battler, stat, stats[stat])
    end
    message = bss_boss_message(cfg["auraMessage"], battler)
    pbDisplay(message) if !message.empty? && respond_to?(:pbDisplay)
    @bss_boss_applied = true
  rescue => e
    BSS064.log("Boss opening failed: #{e.class}: #{e.message}")
    @bss_boss_applied = true
  end

  # DBK/LBDS can wrap pbStartBattleSendOut. Keep their method intact and only
  # replace its first paused intro message while it is running.
  if method_defined?(:pbStartBattleSendOut) && !method_defined?(:bss065_start_sendout_without_totem_intro)
    alias bss065_start_sendout_without_totem_intro pbStartBattleSendOut
    def pbStartBattleSendOut(*args)
      @bss_boss_intro_pending = bss_boss_enabled? && !bss_boss_encounter_message.empty?
      bss065_start_sendout_without_totem_intro(*args)
    ensure
      @bss_boss_intro_pending = false
    end
  end

  if method_defined?(:pbDisplayPaused) && !method_defined?(:bss065_display_paused_without_totem_intro)
    alias bss065_display_paused_without_totem_intro pbDisplayPaused
    def pbDisplayPaused(msg, &block)
      if @bss_boss_intro_pending
        custom = bss_boss_encounter_message
        if !custom.empty?
          @bss_boss_intro_pending = false
          @bss_boss_intro_shown = true
          return bss065_display_paused_without_totem_intro(custom, &block)
        end
      end
      bss065_display_paused_without_totem_intro(msg, &block)
    end
  end

  if method_defined?(:pbCommandPhase) && !method_defined?(:bss065_command_phase_without_native_boss)
    alias bss065_command_phase_without_native_boss pbCommandPhase
    def pbCommandPhase(*args)
      bss_apply_boss_opening
      bss065_command_phase_without_native_boss(*args)
    end
  end
end
