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
        # The cinematic win message was presented before Essentials' default
        # "Entrenador ha perdido" line. Do not present it a second time from
        # DBK's later Scene#pbEndBattle callback.
        next if @bss_scripted_pre_end_win && ev.casecmp("BattleEndWin").zero?
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
    if suppress && !@bss_scripted_pre_end_win
      # Essentials prints "¡Joven Chano ha perdido!" before its normal
      # lose_text. Play the authored cinematic speech *first*, then let the
      # native result announcement proceed without repeating lose_text.
      engine=(respond_to?(:bss_dialogue_engine) ? bss_dialogue_engine : nil)
      if engine && engine.respond_to?(:enabled?) && engine.enabled?
        begin
          # Scene#pbTrainerBattleSuccess starts the actual victory BGM.
          # Run it BEFORE cinematic speech; the one-shot Scene hook below
          # prevents the later native call from restarting the track.
          @bss_scripted_pre_end_win=true
          if @scene
            @scene.pbTrainerBattleSuccess if @scene.respond_to?(:pbTrainerBattleSuccess)
            # Native Essentials normally shows the defeated trainer AFTER
            # the loss announcement. The cinematic dialogue comes BEFORE it,
            # so run the SAME 042-aware TrainerAppear animation here first.
            @scene.pbShowOpponent(0) if @scene.respond_to?(:pbShowOpponent)
          end
          engine.process_event("BattleEndWin",1,nil)
        rescue StandardError => e
          @bss_scripted_pre_end_win=false
          BSS064.log("Pre-result cinematic dialogue: #{e.class}: #{e.message}") if defined?(BSS064)
        end
      end
    end
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

# Native success is also called after "Trainer has lost". When BSS has
# already started the music before its cinematic line, do not play it twice.
# The native battle end cleanup still runs normally.
module BSSScriptedVictoryAudioOnce
  def pbShowOpponent(idxTrainer,*args,&block)
    battle=(@battle rescue nil)
    if idxTrainer.to_i==0 && battle &&
       battle.instance_variable_get(:@bss_scripted_pre_end_win) &&
       @bss_scripted_result_trainer_shown
      # Already animated the actual trainer on-screen for its earlier speech.
      # Suppress the second, identical native slide after the win notice.
      return nil
    end
    result=super
    if idxTrainer.to_i==0 && battle &&
       battle.instance_variable_get(:@bss_scripted_pre_end_win)
      @bss_scripted_result_trainer_shown=true
    end
    result
  end

  def pbTrainerBattleSuccess(*args,&block)
    battle=(@battle rescue nil)
    scripted=battle && battle.respond_to?(:bss_scripted_cinematic_defeat?) &&
              battle.bss_scripted_cinematic_defeat?
    return nil if scripted && @bss_scripted_victory_audio_started
    result=super
    @bss_scripted_victory_audio_started=true if scripted
    result
  end
end

if defined?(Battle::Scene) &&
   !Battle::Scene.ancestors.include?(BSSScriptedVictoryAudioOnce)
  Battle::Scene.prepend(BSSScriptedVictoryAudioOnce)
end


