#===============================================================================
# Battle Scene Studio 0.6.25 - Phase 1 launcher
# Normal battles + BSS-native SOS only.
#===============================================================================
module BSS064
  class << self
    def build_pokemon(raw)
      return nil if !raw.is_a?(Hash) || !defined?(Pokemon)
      species=raw["species"].to_s.upcase
      return nil if species.empty? || !(GameData::Species.exists?(species.to_sym) rescue false)
      level=[[raw["level"].to_i,1].max,100].min
      pkmn=Pokemon.new(species.to_sym,level)
      form=raw["form"].to_i; pkmn.form=form if form>0 && pkmn.respond_to?(:form=)
      pkmn.form_simple=pkmn.form if pkmn.respond_to?(:form_simple=)
      apply_custom_pokemon_fields(pkmn,raw,true)
      pkmn.calc_stats if pkmn.respond_to?(:calc_stats); pkmn.heal if pkmn.respond_to?(:heal)
      hp=raw.key?("hpPercent") ? raw["hpPercent"].to_f : 100.0
      pkmn.hp=[[(pkmn.totalhp*hp/100.0).round,1].max,pkmn.totalhp].min if pkmn.respond_to?(:hp=)
      pkmn
    rescue => e
      log("Pokemon build failed: #{e.class}: #{e.message}"); nil
    end

    def resolve_trainer_type(raw)
      return nil if !defined?(GameData::TrainerType)
      id=raw.to_s.strip; return nil if id.empty?
      sym=id.upcase.to_sym; return sym if GameData::TrainerType.exists?(sym) rescue false
      found=nil; GameData::TrainerType.each { |row| found=row.id if !found && row.id.to_s.casecmp(id).zero? }; found
    rescue; nil; end

    def default_trainer_type
      found=nil; GameData::TrainerType.each { |row| found ||= row.id } if defined?(GameData::TrainerType); found
    rescue; nil; end

    def build_trainer(bp,party)
      return nil if !defined?(NPCTrainer)
      cfg=hget(bp,"setup","trainer"); cfg={} if !cfg.is_a?(Hash)
      type=resolve_trainer_type(cfg["type"]) || default_trainer_type; return nil if !type
      tr=NPCTrainer.new((cfg["name"]||"Trainer").to_s,type); tr.party=party
      defeat=(cfg["defeatMessage"]||"").to_s
      if !defeat.strip.empty?
        begin; tr.lose_text=defeat if tr.respond_to?(:lose_text=); rescue; end
        begin; tr.instance_variable_set(:@lose_text,defeat); rescue; end
      end
      tr
    rescue => e
      log("Trainer build failed: #{e.class}: #{e.message}"); nil
    end

    def formation(bp,player_party,foe_party,sos_enabled=false)
      raw=hget(bp,"setup","formation").to_s
      m=raw.match(/^([123])v([123])$/i); pslots=m ? m[1].to_i : 1; fslots=m ? m[2].to_i : 1
      pslots=[[pslots,[player_party.length,1].max].min,1].max
      fslots=sos_enabled ? 1 : [[fslots,[foe_party.length,1].max].min,1].max
      "#{pslots}v#{fslots}"
    end

    def configure_native_sos(battle,bp)
      cfg=hget(bp,"sos"); cfg={} if !cfg.is_a?(Hash)
      global=global_sos; global={} if !global.is_a?(Hash)
      global_for_bss=(global["enabled"]==true && global["mode"].to_s=="battle_only" && BSS064.global_sos_requirements_met?)
      global_active=BSS064.global_sos_active?
      kind=hget(bp,"setup","kind").to_s
      scripted=(cfg["enabled"] == true)
      enabled=scripted || (kind!="trainer" && (global_for_bss || global_active))
      battle.bss_sos_enabled=enabled if battle.respond_to?(:bss_sos_enabled=)
      if battle.respond_to?(:bss_sos_config=)
        merged=global.dup
        if scripted
          merged.merge!(cfg)
          merged["scriptedBattle"] = true
          merged["allowAdditionalCalls"] = (cfg["allowAdditionalCalls"] == true)
          merged["allowRecursiveCalls"] = (cfg["allowRecursiveCalls"] == true)
          merged["maxSimultaneousSOS"] = [[cfg["maxSimultaneousSOS"].to_i,1].max,2].min
        else
          # A BSS battle reached only through SOS Global must obey the GLOBAL chain
          # and simultaneous-allies settings, rather than blueprint defaults.
          merged["scriptedBattle"] = false
        end
        battle.bss_sos_config=merged
      end
      battle.bss_sos_chain=0 if battle.respond_to?(:bss_sos_chain=)
      battle.bss_initial_sos_done=false if battle.respond_to?(:bss_initial_sos_done=)
      battle.instance_variable_set(:@bss_sos_fixed_cursor,0)
      battle.sosBattle=false if battle.respond_to?(:sosBattle=)
      enabled
    end

    def run_blueprint(key,live_test=false)
      clear_cache
      bp=find(key)
      if !bp; write_status("error",{"message"=>"Battle not found: #{key}"}); return false; end
      return false if @running
      if !defined?(BattleCreationHelperMethods) || !defined?(Battle)
        write_status("error",{"message"=>"Pokémon Essentials battle runtime is unavailable."}); return false
      end
      @running=true
      kind=hget(bp,"setup","kind").to_s; kind="wild" if kind.empty?
      foe_rows=hget(bp,"teams","foes"); foe_rows=[] if !foe_rows.is_a?(Array)
      foe_party=foe_rows.map { |row| build_pokemon(row) }.compact
      if foe_party.empty?; write_status("error",{"message"=>"The battle has no valid foe Pokémon."}); return false; end
      sos_cfg=hget(bp,"sos"); sos_cfg={} if !sos_cfg.is_a?(Hash)
      gs=global_sos; gs={} if !gs.is_a?(Hash)
      global_for_bss=(gs["enabled"]==true && gs["mode"].to_s=="battle_only" && BSS064.global_sos_requirements_met?)
      global_active=BSS064.global_sos_active?
      scripted_sos=(sos_cfg["enabled"]==true)
      sos_enabled=scripted_sos || (kind=="wild" && (global_for_bss || global_active))
      # Wild scripted SOS starts from the configured caller only. Trainer SOS keeps
      # the trainer's reserve party intact; setBattleMode still starts with one
      # active foe and dynamic SOS allies are appended during battle.
      foe_party=foe_party.first(1) if sos_enabled && kind=="wild"

      original_party=(defined?($player) && $player ? $player.party : nil)
      if live_test
        rows=hget(bp,"teams","testPlayer"); rows=[] if !rows.is_a?(Array)
        player_party=rows.map { |row| build_pokemon(row) }.compact
      else
        player_party=original_party
      end
      if !player_party || player_party.empty?; write_status("error",{"message"=>"No player Pokémon available."}); return false; end

      mode=formation(bp,player_party,foe_party,sos_enabled)
      old_in_battle=(defined?($game_temp)&&$game_temp ? ($game_temp.in_battle rescue false) : false)
      old_rules=(defined?($game_temp)&&$game_temp&&$game_temp.respond_to?(:battle_rules) ? ($game_temp.battle_rules.dup rescue nil) : nil)
      begin; $game_temp.clear_battle_rules if $game_temp.respond_to?(:clear_battle_rules); rescue; end if defined?($game_temp)&&$game_temp
      $game_temp.in_battle=true if defined?($game_temp)&&$game_temp&&$game_temp.respond_to?(:in_battle=)
      $player.party=player_party if live_test && defined?($player)&&$player&&$player.respond_to?(:party=)

      EventHandlers.trigger(:on_start_battle) if defined?(EventHandlers)
      scene=BattleCreationHelperMethods.create_battle_scene
      foe_trainer=kind=="trainer" ? build_trainer(bp,foe_party) : nil
      raise RuntimeError,"Trainer battle has no valid trainer type." if kind=="trainer" && !foe_trainer
      battle=Battle.new(scene,player_party,foe_party,[$player],foe_trainer ? [foe_trainer] : nil)
      battle.setBattleMode(mode) if battle.respond_to?(:setBattleMode)
      battle.party1starts=[0] if battle.respond_to?(:party1starts=); battle.party2starts=[0] if battle.respond_to?(:party2starts=)
      battle.ally_items=[] if battle.respond_to?(:ally_items=); battle.items=foe_trainer ? [foe_trainer.items] : [] if battle.respond_to?(:items=)
      BattleCreationHelperMethods.prepare_battle(battle)
      configure_native_sos(battle,bp)
      configure_native_boss(battle,bp) if respond_to?(:configure_native_boss)
      battle.canLose=(hget(bp,"setup","canLose")!=false) if battle.respond_to?(:canLose=)
      begin; $game_temp.clear_battle_rules; rescue; end if defined?($game_temp)&&$game_temp

      write_status("running",{"key"=>bp["key"],"name"=>bp["name"],"formation"=>mode,"sos"=>sos_enabled,"boss"=>(hget(bp,"boss","enabled")==true)})
      bgm_name=hget(bp,"environment","bgm").to_s.strip
      bgm=if !bgm_name.empty? then bgm_name elsif foe_trainer then pbGetTrainerBattleBGM([foe_trainer]) else pbGetWildBattleBGM(foe_party) end
      anim_type=foe_trainer ? (battle.singleBattle? ? 1 : 3) : (foe_party.length==1 ? 0 : 2)
      subject=foe_trainer ? [foe_trainer] : foe_party
      outcome=0
      pbBattleAnimation(bgm,anim_type,subject) do
        pbSceneStandby { outcome=battle.pbStartBattle }
        BattleCreationHelperMethods.after_battle(outcome,true,battle)
      end
      write_status("finished",{"key"=>bp["key"],"decision"=>outcome})
      outcome
    rescue SystemStackError => e
      log("SystemStackError: #{e.message}"); write_status("error",{"key"=>key.to_s,"message"=>"SystemStackError: #{e.message}","backtrace"=>(e.backtrace||[])[0,16]}); false
    rescue => e
      log("Battle launch failed: #{e.class}: #{e.message}"); write_status("error",{"key"=>key.to_s,"message"=>"#{e.class}: #{e.message}","backtrace"=>(e.backtrace||[])[0,16]}); false
    ensure
      @running=false
      if live_test && defined?($player)&&$player&&defined?(original_party)&&original_party&&$player.respond_to?(:party=); $player.party=original_party; end
      if defined?($game_temp)&&$game_temp
        begin; $game_temp.clear_battle_rules; rescue; end
        if defined?(old_rules)&&old_rules.is_a?(Hash); begin; old_rules.each { |k,v| $game_temp.battle_rules[k]=v }; rescue; end; end
        $game_temp.in_battle=old_in_battle if defined?(old_in_battle)&&$game_temp.respond_to?(:in_battle=)
      end
    end

    def read_control
      return nil if !File.exist?(CONTROL_FILE)
      json_parse(File.open(CONTROL_FILE,"rb") { |f| f.read })
    rescue; nil; end

    def poll_control
      req=read_control; return false if !req.is_a?(Hash)
      action=req["action"].to_s; return false if action!="test" && action!="start_test"
      return false if defined?($game_temp)&&$game_temp&&($game_temp.in_battle rescue false)
      token=(req["id"]||req["requestedAt"]||req["key"]).to_s; return false if token.empty? || token==@last_control_token
      @last_control_token=token; File.delete(CONTROL_FILE) rescue nil
      run_blueprint(req["key"].to_s,true); true
    rescue => e
      log("Control bridge failed: #{e.class}: #{e.message}"); write_status("error",{"message"=>"#{e.class}: #{e.message}"}); false
    end
  end
end

def pbBSSBattle(key)
  BSS064.run_blueprint(key,false)
end

if defined?(EventHandlers)
  EventHandlers.add(:on_game_load,:bss_064_ready,proc { BSS064.clear_cache; BSS064.write_status("ready",{"message"=>"BSS 0.6.25 Phase 1 SOS + Boss/Totem ready"}) rescue nil })
  EventHandlers.add(:on_frame_update,:bss_064_control,proc { BSS064.poll_control rescue nil })
end
