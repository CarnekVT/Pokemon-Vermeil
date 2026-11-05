# frozen_string_literal: true
# Pokemon Vermeil - BSS scripted dialogue events.
# DBK's pbDeluxeTriggers exits early when no DBK midbattle script is assigned.
# BSS Blueprints have their own dialogue engine, so dispatch independently
# without assigning a duplicate DBK script or changing ordinary encounters.
module BSSBlueprintDialogueDispatch
  BSS_EVENTS = /\A(?:RoundStartCommand|RoundStartAttack|BattleStart|BeforeMove|BeforeDamagingMove|BeforePhysicalMove|BeforeSpecialMove|BeforeStatusMove|AfterMove|TargetHP75|TargetHPHalf|TargetHPLow|ShieldBreak|SOSCall|SOSSuccess|SOSFail|BeforeLastSwitchIn|AfterLastSendOut|BattlerFainted|TurnEnd|BattleEnd(?:Win|Loss|Capture|Draw|Run|Fled|Forfeit)?)\z/i

  def pbDeluxeTriggers(idxBattler, idxTarget, *triggers)
    result = super
    engine = (respond_to?(:bss_dialogue_engine) ? bss_dialogue_engine : nil)
    return result unless engine && engine.enabled?
    return result if @bss_dialogue_dispatch_running
    user = idxBattler.respond_to?(:index) ? idxBattler.index : idxBattler
    target = idxTarget.respond_to?(:index) ? idxTarget.index : idxTarget
    @bss_dialogue_dispatch_running = true
    begin
      triggers.each do |ev|
        next unless ev.is_a?(String) && ev.match?(BSS_EVENTS)
        engine.process_event(ev, user, target)
        # DBK currently emits TargetHP75 for every HP level below 75% due
        # to its elsif ordering. Relay the two stricter thresholds so scripted
        # BSS phases are actually testable without rewriting DBK internals.
        if ev.match?(/\ATargetHP75\z/i)
          b = (@battlers[user] rescue nil)
          if b && b.totalhp.to_i > 0
            engine.process_event("TargetHPHalf", user, target) if b.hp.to_f <= b.totalhp.to_f * 0.5
            engine.process_event("TargetHPLow", user, target) if b.hp.to_f <= b.totalhp.to_f * 0.25
          end
        end
      end
    rescue StandardError => e
      BSS064.log("BSS dialogue event bridge: #{e.class}: #{e.message}") if defined?(BSS064)
    ensure
      @bss_dialogue_dispatch_running = false
    end
    result
  end
end

if defined?(Battle) && !Battle.ancestors.include?(BSSBlueprintDialogueDispatch)
  Battle.prepend(BSSBlueprintDialogueDispatch)
end

# Essentials always prints trainer.lose_text after "X ha perdido", even if a
# BSS Blueprint authors the same moment as a cinematic BattleEndWin dialogue.
# Suppress only the duplicate *native* lose_text in that one BSS context;
# never alter an ordinary trainer battle's win/lose messages or other display.
module BSSScriptedTrainerDefeatCaption
  def bss_scripted_cinematic_defeat?
    return false unless respond_to?(:trainerBattle?) && trainerBattle?
    bp=(respond_to?(:bss_blueprint) ? bss_blueprint : nil)
    return false unless bp.is_a?(Hash)
    cfg=bp["dialogues"]
    return false unless cfg.is_a?(Hash) && cfg["enabled"]!=false
    triggers=cfg["triggers"]
    triggers.is_a?(Array) && triggers.any? do |t|
      next false unless t.is_a?(Hash)
      event=(t["event"] || t["rawEvent"]).to_s
      (t["style"]=="cinematic" || ["cinematic","speech"].include?(t["textboxType"])) &&
        event.casecmp("BattleEndWin").zero?
    end
  rescue StandardError
    false
  end

  def pbHandleEndOfBattleOutcome(oldDecision)
    suppress=(oldDecision==Battle::Outcome::WIN && bss_scripted_cinematic_defeat?)
    previous=@bss_suppress_native_trainer_lose_text
    @bss_suppress_native_trainer_lose_text=true if suppress
    super
  ensure
    @bss_suppress_native_trainer_lose_text=previous
  end

  def pbDisplayPaused(message,*args,&block)
    if @bss_suppress_native_trainer_lose_text && @opponent
      text=message.to_s
      opponent_names=@opponent.respond_to?(:each) ? @opponent : []
      native=opponent_names.any? do |trainer|
        lose=(trainer.lose_text rescue "").to_s
        lose="..." if lose.empty?
        lose=lose.gsub(/\\[Pp][Nn]/,(pbPlayer.name rescue "")).gsub(/\\[Nn]/,"\n")
        text==lose
      end
      return nil if native
    end
    super
  end
end

if defined?(Battle) && !Battle.ancestors.include?(BSSScriptedTrainerDefeatCaption)
  Battle.prepend(BSSScriptedTrainerDefeatCaption)
end
