#===============================================================================
# Battle Scene Studio & DBK Midbattle Dialogues Integration
#===============================================================================
# Este archivo proporciona integración directa, helpers y plantillas para
# diálogos durante el combate (Mid-Battle Dialogues) usando el motor de DBK.
#
# CÓMO USAR EN EVENTOS DE RPG MAKER:
# ----------------------------------
# Antes de iniciar un combate con pbTrainerBattle o pbWildBattle, puedes activar
# cualquier diálogo registrado usando una sola línea:
#
#   setBattleRule("midbattleScript", :BOSS_TRAINER_EXAMPLE)
#   o bien:
#   setMidbattleDialogue(:BOSS_TRAINER_EXAMPLE)
#
# EN BATTLE SCENE STUDIO (BSS):
# -----------------------------
# En el Blueprint o configuración de Boss en JSON/Editor:
#   "boss": {
#     "enabled": true,
#     "aiSkill": 100,
#     "midbattleScript": "BOSS_WILD_EXAMPLE"
#   }
#===============================================================================

# Helper global para asignar diálogos cómodamente en eventos
def setMidbattleDialogue(script_id)
  setBattleRule("midbattleScript", script_id.to_sym)
end

module MidbattleScripts
  #-----------------------------------------------------------------------------
  # Helper para registrar diálogos dinámicamente desde cualquier script
  #-----------------------------------------------------------------------------
  def self.register(id, script_hash)
    const_set(id.to_sym, script_hash)
  end

  #-----------------------------------------------------------------------------
  # PLANTILLA 1: JEFE SALVAJE (Wild Boss / Totem)
  # Diálogos y efectos narrativos para un Pokémon salvaje dominante.
  # Usa texto nativo de batalla sin barras negras cinematográficas.
  #-----------------------------------------------------------------------------
  BOSS_WILD_EXAMPLE = {
    # Al inicio del primer turno de ataque
    "RoundStartAttack_foe" => {
      "text" => "¡El Pokémon dominante emite un rugido ensordecedor que hace temblar el terreno!"
    },
    # Cuando la vida del jefe baja al 50%
    "TargetHPHalf_foe" => {
      "text" => [
        "¡El Pokémon dominante jadea furioso ante la presión del combate!",
        "¡Una intensa aura de furia comienza a emanar de su cuerpo!"
      ]
    },
    # Cuando la vida del jefe baja al 25% (vida crítica)
    "TargetHPLow_foe" => {
      "text" => "¡El Pokémon dominante reúne sus últimas fuerzas para un contraataque desesperado!"
    },
    # Cuando el jefe es derrotado
    "BattlerFainted_foe" => {
      "text" => "¡El Pokémon dominante cae exhausto tras una feroz batalla!"
    }
  }

  #-----------------------------------------------------------------------------
  # PLANTILLA 2: JEFE ENTRENADOR (Líder de Gimnasio / Rival / Boss Trainer)
  # Diálogos cinematográficos con orador, barras negras y retrato.
  # Cierra con endSpeech para restaurar databoxes y barras negras.
  #-----------------------------------------------------------------------------
  BOSS_TRAINER_EXAMPLE = {
    # Inicio del combate (Turno 1, fase de comandos)
    "RoundStartCommand_foe" => {
      "speech" => [
        "¡Espero que estés listo para un combate de verdad!",
        "¡Demuéstrame lo que tú y tus Pokémon son capaces de hacer!"
      ],
      "endSpeech" => true
    },
    # Cuando su Pokémon recibe daño y cae al 50% o menos
    "TargetHPHalf_foe" => {
      "speech" => [
        "¡Nada mal! Tu técnica es más sólida de lo que imaginaba.",
        "¡Pero aún estamos muy lejos del final!"
      ],
      "endSpeech" => true
    },
    # Cuando su Pokémon está en vida crítica (25% o menos)
    "TargetHPLow_foe" => {
      "speech" => [
        "¡Increíble potencia! Nos tienes contra las cuerdas...",
        "¡Aún así, un verdadero entrenador nunca se rinde hasta el último aliento!"
      ],
      "endSpeech" => true
    },
    # Cuando saca a su último Pokémon (su As)
    "BeforeLastSwitchIn_foe" => {
      "speech" => [
        "¡Llegó la hora! ¡Sal a escena, compañero!",
        "¡Mostremos nuestro verdadero poder!"
      ],
      "endSpeech" => true
    },
    # Tras enviar a su último Pokémon
    "AfterLastSendOut_foe" => {
      "speech" => "¡Este combate se decide aquí y ahora!",
      "endSpeech" => true
    },
    # Si el jugador pierde
    "BattleEndLoss" => {
      "speech" => "Buen intento, pero aún te queda un largo camino por recorrer.",
      "endSpeech" => true
    },
    # Si el jugador gana
    "BattleEndWin" => {
      "speech" => "Has peleado con maestría y corazón. Una victoria totalmente merecida.",
      "endSpeech" => true
    }
  }

  #-----------------------------------------------------------------------------
  # PLANTILLA 3: JEFE CON EFECTOS Y DIÁLOGOS COMPLEJOS
  # Muestra cómo encadenar diálogos, cambios de estado y efectos tácticos.
  #-----------------------------------------------------------------------------
  BOSS_TACTICAL_EXAMPLE = {
    "RoundStartAttack_foe" => {
      "speech" => "¡Prepárate! ¡Esta batalla apenas comienza!",
      "endSpeech" => true
    },
    "TargetHPHalf_foe" => {
      "speech" => [
        "¡No creas que nos vencerás tan fácilmente!",
        "¡Observa cómo damos la vuelta a este combate!"
      ],
      "endSpeech" => true
    },
    "TargetHPLow_foe" => {
      "speech" => "¡Jamás cederemos la victoria!",
      "endSpeech" => true
    }
  }
end

#===============================================================================
# Battle Scene Studio - Dialogue & Scripting Engine (Guionización)
#===============================================================================
class BSSDialogueEngine
  attr_reader :battle, :triggers, :activated_ids

  def initialize(battle, cfg = {})
    @battle = battle
    @cfg = cfg.is_a?(Hash) ? cfg : {}
    @enabled = @cfg["enabled"] != false
    @triggers = []
    @activated_ids = {}

    # 1. Load triggers from "dialogues"
    raw_triggers = @cfg["triggers"]
    if raw_triggers.is_a?(Array)
      raw_triggers.each do |t|
        norm = normalize_trigger(t)
        @triggers << norm if norm
      end
    end

    # 2. Backwards-compatibility: load triggers from boss["midbattleTriggers"] if present
    boss_cfg = (battle.respond_to?(:bss_boss_config) ? battle.bss_boss_config : {}) || {}
    if boss_cfg["midbattleTriggers"].is_a?(Array) && @triggers.empty?
      boss_cfg["midbattleTriggers"].each do |t|
        norm = normalize_trigger(t, default_target: "boss")
        @triggers << norm if norm
      end
    end
    # Dialogue IDs identify independent one-shot events. Imported libraries can
    # contain duplicate IDs; distinguish them without changing saved JSON.
    used_ids = {}
    @triggers.each_with_index do |trigger, index|
      id = trigger[:id].to_s.strip
      id = "dialogue_#{index + 1}" if id.empty?
      base = id
      suffix = 2
      while used_ids[id]
        id = "#{base}_#{suffix}"
        suffix += 1
      end
      trigger[:id] = id
      used_ids[id] = true
    end

  end

  def enabled?
    @enabled && !@triggers.empty?
  end

  def normalize_trigger(t, default_target: "boss")
    return nil unless t.is_a?(Hash)
    raw_ev = (t["event"] || t[:event]).to_s.strip
    return nil if raw_ev.empty?

    ev = raw_ev.dup
    inferred_target = default_target
    if ev =~ /_(foe|foe1|foe2|foe3)$/i
      ev = ev.sub(/_(foe|foe1|foe2|foe3)$/i, "")
      inferred_target = "boss"
    elsif ev =~ /_(player|player1|player2|player3)$/i
      ev = ev.sub(/_(player|player1|player2|player3)$/i, "")
      inferred_target = "player"
    elsif ev =~ /_ally$/i
      ev = ev.sub(/_ally$/i, "")
      inferred_target = "sos"
    end

    tgt = (t["target"] || t[:target] || inferred_target).to_s.strip.downcase
    tgt = "boss" unless %w[boss sos player global].include?(tgt)

    spk = (t["speaker"] || t[:speaker] || "narrator").to_s.strip.downcase
    spk = "narrator" unless %w[boss sos trainer narrator custom].include?(spk)

    style = (t["style"] || t[:style] || "narrative").to_s.strip.downcase
    style = "narrative" unless %w[cinematic narrative].include?(style)

    tb_type = (t["textboxType"] || t[:textboxType] || (style == "cinematic" ? "cinematic" : "default")).to_s.strip.downcase
    tb_type = "default" unless %w[default cinematic speech clean].include?(tb_type)

    raw_choices = t["choices"] || t[:choices]
    choices = if raw_choices.is_a?(Array)
                raw_choices.map(&:to_s).map(&:strip).reject(&:empty?)
              elsif raw_choices.is_a?(String) && !raw_choices.strip.empty?
                raw_choices.split(/[,\n]/).map(&:strip).reject(&:empty?)
              else
                []
              end

    raw_resp = t["choiceResponses"] || t[:choiceResponses]
    choice_resp = if raw_resp.is_a?(Array)
                    raw_resp.map(&:to_s).map(&:strip)
                  elsif raw_resp.is_a?(String) && !raw_resp.strip.empty?
                    raw_resp.split("\n").map(&:strip)
                  else
                    []
                  end

    raw_effects = t["choiceEffects"] || t[:choiceEffects]
    choice_effects = if raw_effects.is_a?(Array)
                       raw_effects.map do |eff|
                         next nil unless eff.is_a?(Hash)
                         {
                           type: (eff["type"] || eff[:type] || "none").to_s.downcase,
                           stat: (eff["stat"] || eff[:stat] || "ATTACK").to_s.upcase,
                           stages: (eff["stages"] || eff[:stages] || 1).to_i,
                           target: (eff["target"] || eff[:target] || "player").to_s.downcase,
                           percent: (eff["percent"] || eff[:percent] || 25).to_i,
                           status: (eff["status"] || eff[:status] || "").to_s.upcase
                         }
                       end.compact
                     else
                       []
                     end

    txt = (t["text"] || t[:text]).to_s.strip
    lines = txt.split("\n").map(&:strip).reject(&:empty?)
    return nil if lines.empty? && choices.empty?

    {
      id: (t["id"] || t[:id] || "dlg_#{rand(1_000_000)}").to_s,
      event: ev,
      target: tgt,
      speaker: spk,
      speakerName: (t["speakerName"] || t[:speakerName] || "").to_s.strip,
      style: style,
      textboxType: tb_type,
      showNamebox: (t["showNamebox"] != false && t[:showNamebox] != false),
      choices: choices,
      choiceResponses: choice_resp,
      choiceEffects: choice_effects,
      playCry: t["playCry"] == true || t[:playCry] == true,
      screenShake: t["screenShake"] == true || t[:screenShake] == true,
      barTransition: (t["barTransition"] || t[:barTransition] || "reenter").to_s == "hold" ? "hold" : "reenter",
      repeat: t["repeat"] == true || t[:repeat] == true,
      turn: (t["turn"] || t[:turn]).to_i,
      lines: lines
    }
  end

  def target_matches?(target_type, idxBattler)
    return true if target_type == "global"
    return false if idxBattler.nil?

    boss = (@battle.bss_find_boss_battler_any rescue nil)
    # The "boss" editor target also means the opponent in ordinary trainer
    # tests; these Battles do not instantiate a BSS Totem boss object.
    foe = (@battle.opposes?(idxBattler) rescue idxBattler.to_i.odd?)
    is_boss = boss ? boss.index == idxBattler : foe

    case target_type
    when "boss"
      is_boss
    when "sos"
      boss && !is_boss && foe
    when "player"
      (@battle.pbOwnedByPlayer?(idxBattler) rescue idxBattler.to_i.even?)
    else
      true
    end
  end

  def process_event(event_name, idxBattler = nil, idxTarget = nil, *extra_params)
    return false unless enabled?

    clean_ev = event_name.to_s.sub(/_(foe|player|ally)[0-9]*$/i, "")
    base_ev = clean_ev.sub(/^Last/i, "")

    matched = []
    @triggers.each do |t|
      next if !t[:repeat] && @activated_ids[t[:id]]
      t_ev = t[:event].to_s.sub(/_(foe|player|ally)[0-9]*$/i, "")
      t_base = t_ev.sub(/^Last/i, "")

      next unless t[:event].casecmp(clean_ev) == 0 ||
                  t[:event].casecmp(event_name.to_s) == 0 ||
                  t_base.casecmp(base_ev) == 0 ||
                  t_ev.casecmp(clean_ev) == 0

      next unless target_matches?(t[:target], idxBattler)

      if t[:turn] && t[:turn] > 0
        current_turn = (@battle.turnCount rescue 0).to_i + 1
        next if current_turn != t[:turn]
      end

      if base_ev =~ /HP/i && idxBattler
        battler = (@battle.battlers[idxBattler] rescue nil)
        if battler && battler.totalhp.to_i > 0
          pct = (battler.hp.to_f / battler.totalhp.to_f) * 100.0
          if base_ev =~ /HP75/i && pct > 75.0
            next
          elsif base_ev =~ /HPHalf/i && pct > 50.0
            next
          elsif base_ev =~ /HPLow/i && pct > 25.0
            next
          end
        end
      end

      matched << t
    end

    return false if matched.empty?

    @bss_dialogue_event_depth = @bss_dialogue_event_depth.to_i + 1
    matched.each_with_index do |t,i|
      nxt=matched[i+1]
      cinematic_next=nxt && (nxt[:style]=="cinematic" || ["cinematic","speech"].include?(nxt[:textboxType]))
      t[:_keep_cinematic_to_next] = t[:barTransition]=="hold" && cinematic_next
      execute_trigger(t,idxBattler,idxTarget)
    end
    true
  ensure
    @bss_dialogue_event_depth = [@bss_dialogue_event_depth.to_i-1,0].max if @bss_dialogue_event_depth
    # Choice_N events can recursively invoke process_event; only the outer
    # event may finish a BSS-owned black-bar session.
    bss_close_owned_speech if @bss_dialogue_event_depth.to_i==0 && @bss_bars_owned
  end

  def bss_close_owned_speech
    return unless @bss_bars_owned
    scene=(@battle.scene rescue nil)
    @bss_bars_owned=false
    scene.pbForceEndSpeech if scene && scene.respond_to?(:pbForceEndSpeech)
    scene.instance_variable_set(:@bss_dialogue_cinema_active,false) if scene
  rescue StandardError => e
    BSS064.log("BSS cinematic close: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def execute_trigger(t, idxBattler, idxTarget)
    @activated_ids[t[:id]] = true

    battler = idxBattler ? (@battle.battlers[idxBattler] rescue nil) : nil
    target = idxTarget ? (@battle.battlers[idxTarget] rescue nil) : nil

    battler_name = battler ? (battler.name rescue battler.pbThis) : "el Pokémon"
    target_name = target ? (target.name rescue target.pbThis) : "el objetivo"

    # 1. Screen Shake
    if t[:screenShake]
      begin
        pbSEPlay("Battle damage normal") rescue nil
        if @battle.scene && @battle.scene.respond_to?(:pbShake)
          @battle.scene.pbShake(4, 4) rescue nil
        end
      rescue
      end
    end

    # 2. Play Cry (v21.1 API)
    if t[:playCry]
      begin
        pkmn = (battler && battler.respond_to?(:pokemon)) ? battler.pokemon : nil
        pkmn ||= (idxBattler && @battle.battlers[idxBattler] ? @battle.battlers[idxBattler].pokemon : nil)
        pkmn ||= (@battle.bss_find_boss_battler_any.pokemon rescue nil)
        if pkmn && pkmn.respond_to?(:play_cry)
          pkmn.play_cry
        elsif pkmn && defined?(GameData::Species) && GameData::Species.respond_to?(:play_cry_from_pokemon)
          GameData::Species.play_cry_from_pokemon(pkmn)
        elsif pkmn && defined?(Pokemon) && Pokemon.respond_to?(:play_cry)
          Pokemon.play_cry(pkmn.species, pkmn.form)
        end
      rescue => e
        BSS064.log("Cry playback warning: #{e.class}: #{e.message}") if defined?(BSS064)
      end
    end

    # 3. Format lines
    formatted_lines = (t[:lines] || []).map do |l|
      text = l.dup
      text.gsub!("{1}", battler_name)
      text.gsub!("{2}", target_name)
      text
    end

    # 4. Enforce Z-Order of Dialogue & Black Bars above all battlers and position Namebox
    scene_sprites = @battle.scene.instance_variable_get(:@sprites) rescue nil
    if scene_sprites.is_a?(Hash)
      scene_sprites["topBar"].z = 99990 if scene_sprites["topBar"] && scene_sprites["topBar"].respond_to?(:z=)
      scene_sprites["bottomBar"].z = 99990 if scene_sprites["bottomBar"] && scene_sprites["bottomBar"].respond_to?(:z=)
      scene_sprites["nameWindow"].z = 99995 if scene_sprites["nameWindow"] && scene_sprites["nameWindow"].respond_to?(:z=)
      scene_sprites["messageWindow"].z = 99995 if scene_sprites["messageWindow"] && scene_sprites["messageWindow"].respond_to?(:z=)
      scene_sprites["midbattle_speaker"].z = 99980 if scene_sprites["midbattle_speaker"] && scene_sprites["midbattle_speaker"].respond_to?(:z=)
      if scene_sprites["nameWindow"] && scene_sprites["messageWindow"]
        nw = scene_sprites["nameWindow"]
        mw = scene_sprites["messageWindow"]
        nw.y = mw.y - nw.height + 4
        nw.x = [mw.x + 8, 16].max
      end
    end

    # 5. Presentation mode
    # DBK's pbProcessText indexes @battle.battlers[idxBattler], so global
    # events with no battler need a valid display anchor.
    display_idx = idxBattler
    if display_idx.nil? || !(@battle.battlers[display_idx] rescue nil)
      display_idx = (@battle.battlers[1] ? 1 : 0) rescue 0
    end
    is_cinematic = (t[:style] == "cinematic" || t[:textboxType] == "cinematic" ||
                    t[:textboxType] == "speech")
    is_clean = (t[:textboxType] == "clean")
    show_name = t[:showNamebox] != false

    speaker_label = if show_name
                      case t[:speaker]
                      when "boss", "sos"
                        battler_name == "el Pokémon" ? (@battle.battlers[display_idx].name rescue battler_name) : battler_name
                      when "trainer"
                        (@battle.pbGetOwnerName(display_idx) rescue "Entrenador")
                      when "custom"
                        t[:speakerName].empty? ? battler_name : t[:speakerName]
                      else
                        nil
                      end
                    else
                      nil
                    end

    scene = @battle.scene
    name_window = scene_sprites.is_a?(Hash) ? scene_sprites["nameWindow"] : nil
    has_choices = t[:choices].is_a?(Array) && !t[:choices].empty?
    # pbShowCommands displays its prompt. It MUST NOT be shown beforehand by
    # pbProcessText or pbDisplayPaused (otherwise it appears twice).
    introduction = has_choices ? formatted_lines[0...-1] : formatted_lines
    prompt = has_choices ? (formatted_lines.last || "Elige una opción:") : nil
    cinematic_owner = false
    pending_effect = nil
    pending_effect_recipient = nil
    begin
      if is_cinematic && scene && scene.respond_to?(:pbProcessText)
        # A nested Choice_1/Choice_2 branch inherits the parent's cinematic
        # bars. Only the outermost dialogue may close them.
        already_speaking = scene.respond_to?(:pbInCinematicSpeech?) && scene.pbInCinematicSpeech?
        cinematic_owner = !already_speaking
        @bss_bars_owned=true if cinematic_owner
        scene.instance_variable_set(:@bss_dialogue_cinema_active,true)
        scene.pbStartSpeech(display_idx) if scene.respond_to?(:pbStartSpeech) && !already_speaking
        if speaker_label && !speaker_label.empty?
          scene.pbUpdateSpeakerWindows(speaker_label) if scene.respond_to?(:pbUpdateSpeakerWindows)
          name_window.visible = true if name_window
        elsif name_window
          name_window.visible = false
        end
        scene.pbProcessText(display_idx, idxTarget, true, introduction) unless introduction.empty?
      elsif is_clean
        message_window = scene_sprites.is_a?(Hash) ? scene_sprites["messageWindow"] : nil
        orig_opacity = message_window ? message_window.opacity : 255
        begin
          message_window.opacity = 0 if message_window
          introduction.each do |line|
            msg = speaker_label && !speaker_label.empty? ? "#{speaker_label}: #{line}" : line
            @battle.pbDisplayPaused(msg)
          end
        ensure
          message_window.opacity = orig_opacity if message_window
        end
      else
        introduction.each do |line|
          msg = speaker_label && !speaker_label.empty? ? "#{speaker_label}: #{line}" : line
          @battle.pbDisplayPaused(msg)
        end
      end

      if has_choices && scene && scene.respond_to?(:pbShowCommands)
        # Cinematic speech is deliberately NOT ended before opening choices.
        # This keeps black bars, speaker sprite, and namebox visible.
        cmd = scene.pbShowCommands(prompt, t[:choices], -1)
        if cmd.is_a?(Integer) && cmd >= 0 && cmd < t[:choices].length
          if t[:choiceResponses] && t[:choiceResponses][cmd] && !t[:choiceResponses][cmd].empty?
            resp = t[:choiceResponses][cmd].dup
            resp.gsub!("{1}", battler_name)
            resp.gsub!("{2}", target_name)
            if is_cinematic && scene.respond_to?(:pbProcessText)
              scene.pbProcessText(display_idx,idxTarget,true,[resp])
            else
              @battle.pbDisplayPaused(resp)
            end
          end
          # Apply boosts AFTER restoring the standard battle textbox and HUD.
          # Otherwise the stat animation/message is clipped beneath black bars.
          pending_effect=t[:choiceEffects][cmd] if t[:choiceEffects] && t[:choiceEffects][cmd]
          # One canonical dispatch. The old second suffixed dispatch could
          # retrigger branches marked repeat=true in the same selection.
          process_event("Choice_#{cmd + 1}",idxBattler,idxTarget)
        end
      end
    ensure
      # A dialogue may keep its bars seamlessly when the next trigger requests
      # Hold; Re-enter closes here, allowing the native 5-frame exit animation.
      if @bss_dialogue_event_depth.to_i <= 1 && !t[:_keep_cinematic_to_next]
        bss_close_owned_speech
      end
    end
    if pending_effect
      begin
        scene.pbShowWindow(Battle::Scene::MESSAGE_BOX) if scene && scene.respond_to?(:pbShowWindow)
      rescue StandardError
      end
      apply_choice_consequence(pending_effect,idxBattler,idxTarget)
      stat=(pending_effect[:stat] || "ATTACK").to_s
      if pending_effect[:type].to_s == "stat_boost"
        labels={"ATTACK"=>"Ataque","DEFENSE"=>"Defensa","SPECIAL_ATTACK"=>"Ataque Especial",
                "SPECIAL_DEFENSE"=>"Defensa Especial","SPEED"=>"Velocidad"}
        name=labels[stat.upcase] || stat
        battler=((@battle.battlers[0] rescue nil))
        who=battler ? battler.name : "tu Pokémon"
        @battle.pbDisplayPaused("¡La #{name} de #{who} ha aumentado!") if @battle.respond_to?(:pbDisplayPaused)
      end
    end
  end

  def apply_choice_consequence(effect, idxBattler, idxTarget)
    return unless effect.is_a?(Hash)
    type = effect[:type].to_s.downcase
    return if type.empty? || type == "none"

    target_mode = effect[:target].to_s.downcase
    boss = (@battle.bss_find_boss_battler_any rescue nil)
    player = (@battle.battlers[0] rescue nil)

    recipients = []
    case target_mode
    when "player", "jugador"
      recipients << player if player && !player.fainted?
    when "boss", "jefe", "dominante"
      recipients << boss if boss && !boss.fainted?
    when "both", "ambos"
      recipients << player if player && !player.fainted?
      recipients << boss if boss && !boss.fainted?
    else
      recipients << (type =~ /boost|heal/ ? player : boss)
    end
    recipients.compact!

    recipients.each do |b|
      case type
      when "stat_boost"
        stat_name = (effect[:stat] || "ATTACK").to_s.upcase
        stages = (effect[:stages] || 1).to_i
        stages = 1 if stages <= 0
        if stat_name == "ALL"
          [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |st|
            b.pbRaiseStatStage(st, stages, b, true) rescue nil
          end
        else
          st_sym = stat_name.to_sym
          b.pbRaiseStatStage(st_sym, stages, b, true) rescue nil
        end
      when "stat_drop"
        stat_name = (effect[:stat] || "ATTACK").to_s.upcase
        stages = (effect[:stages] || 1).to_i.abs
        stages = 1 if stages <= 0
        if stat_name == "ALL"
          [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |st|
            b.pbLowerStatStage(st, stages, b, true) rescue nil
          end
        else
          st_sym = stat_name.to_sym
          b.pbLowerStatStage(st_sym, stages, b, true) rescue nil
        end
      when "heal"
        pct = (effect[:percent] || 25).to_i
        pct = 25 if pct <= 0
        amt = [(b.totalhp * pct / 100.0).round, 1].max
        b.pbRecoverHP(amt) if b.hp < b.totalhp
      when "damage"
        pct = (effect[:percent] || 25).to_i
        pct = 25 if pct <= 0
        amt = [(b.totalhp * pct / 100.0).round, 1].max
        b.pbReduceHP(amt)
      when "status"
        st = effect[:status].to_s.upcase.to_sym
        if st == :CONFUSION
          b.pbConfuse if b.respond_to?(:pbCanConfuse?) && b.pbCanConfuse?(nil, false)
        elsif [:PARALYSIS, :BURN, :POISON, :SLEEP, :FROZEN].include?(st)
          b.pbInflictStatus(st) if b.respond_to?(:pbCanInflictStatus?) && b.pbCanInflictStatus?(st, nil, false)
        end
      end
    end
  end
end

class Battle
  attr_accessor :bss_dialogue_engine
end

module BSS064
  class << self
    def configure_bss_dialogues(battle, bp)
      return unless battle && bp.is_a?(Hash)
      dlg_cfg = bp["dialogues"]
      if !dlg_cfg.is_a?(Hash)
        boss_cfg = bp["boss"].is_a?(Hash) ? bp["boss"] : {}
        if boss_cfg["midbattleTriggers"].is_a?(Array) && !boss_cfg["midbattleTriggers"].empty?
          dlg_cfg = { "enabled" => true, "triggers" => boss_cfg["midbattleTriggers"] }
        end
      end
      if dlg_cfg.is_a?(Hash)
        battle.bss_dialogue_engine = BSSDialogueEngine.new(battle, dlg_cfg)
      end
    rescue => e
      log("BSS Dialogues config warning: #{e.class}: #{e.message}")
    end
  end
end
