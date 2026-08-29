#===============================================================================
# Battle Scene Studio 0.6.37 - Phase 1 launcher
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

    # F12-safe live-test marker. Only tests explicitly launched from the BSS
    # editor write this file, and it also stores the current OS process id. F12
    # reloads scripts inside the same process, while closing/reopening the game
    # creates a new pid. This lets Studio tests resume after F12 without ever
    # forcing a BSS battle on a normal player or on a later game launch.
    def active_battle_request
      return nil if !File.exist?(ACTIVE_BATTLE_FILE)
      raw=json_parse(File.open(ACTIVE_BATTLE_FILE,"rb"){|f|f.read})
      return nil if !raw.is_a?(Hash)
      stamp=raw["bssStartedAt"].to_i
      if stamp>0 && Time.now.to_i-stamp>3600
        File.delete(ACTIVE_BATTLE_FILE) rescue nil
        return nil
      end
      raw
    rescue
      nil
    end

    def write_active_battle(key,live_test,token=nil)
      payload={"key"=>key.to_s,"liveTest"=>(live_test==true),"pid"=>(Process.pid rescue 0),"token"=>(token||"bss_#{Time.now.to_i}_#{rand(1000000)}").to_s,"bssStartedAt"=>Time.now.to_i}
      Dir.mkdir("Data/BattleSceneStudio") if !Dir.exist?("Data/BattleSceneStudio") rescue nil
      File.open(ACTIVE_BATTLE_FILE,"wb"){|f|f.write(json_generate(payload))}
      payload
    rescue => e
      log("Active BSS session write failed: #{e.class}: #{e.message}")
      nil
    end

    def mark_active_battle_reset(key=nil)
      raw=active_battle_request || {}
      raw["key"]=(key||raw["key"]).to_s
      raw["liveTest"]=true
      raw["pid"]=(Process.pid rescue raw["pid"].to_i)
      raw["resumeAfterReset"]=true
      raw["resetDetectedAt"]=(Time.now.to_f*1000).to_i
      raw["bssStartedAt"]=Time.now.to_i if raw["bssStartedAt"].to_i<=0
      raw["token"]="bss_#{Time.now.to_i}_#{rand(1000000)}" if raw["token"].to_s.empty?
      Dir.mkdir("Data/BattleSceneStudio") if !Dir.exist?("Data/BattleSceneStudio") rescue nil
      File.open(ACTIVE_BATTLE_FILE,"wb") { |f| f.write(json_generate(raw)) }
      raw
    rescue => e
      log("F12 Reset marker warning: #{e.class}: #{e.message}")
      nil
    end

    def clear_active_battle
      File.delete(ACTIVE_BATTLE_FILE) if File.exist?(ACTIVE_BATTLE_FILE)
      true
    rescue
      false
    end

    def schedule_active_battle_resume
      raw=active_battle_request
      return false if !raw.is_a?(Hash)
      same_pid=(raw["pid"].to_i>0 && raw["pid"].to_i==(Process.pid rescue -1))
      live=(raw["liveTest"]==true)
      key=raw["key"].to_s
      token=raw["token"].to_s
      reset_at=raw["resetDetectedAt"].to_i
      reset_age=reset_at>0 ? ((Time.now.to_f*1000).to_i-reset_at) : 999999
      explicit_reset=(raw["resumeAfterReset"]==true && reset_age>=0 && reset_age<=120000)
      recent_same_pid=(same_pid && raw["bssStartedAt"].to_i>0 && Time.now.to_i-raw["bssStartedAt"].to_i<=120)
      return false if !live || key.empty? || (!explicit_reset && !recent_same_pid)
      # F12 is a script Reset inside the same game process. Keep the marker and
      # let the freshly reloaded runtime resume its own live test once the map
      # stack has had a short settling window. The editor is not used as the
      # second half of the protocol anymore, so refreshing/reopening BSS cannot
      # "undo" the test or strand it at resume_needed.
      @pending_f12_resume={
        "key"=>key, "token"=>token, "armedAt"=>Time.now.to_f, "readyFrames"=>0
      }
      write_status("f12_resuming",{
        "key"=>key, "resumeToken"=>token,
        "message"=>"F12 detectado · BSS reanudará el mismo test automáticamente"
      })
      true
    rescue => e
      log("F12 resume arm failed: #{e.class}: #{e.message}")
      @pending_f12_resume=nil
      false
    end

    def poll_f12_resume
      req=@pending_f12_resume
      return false if !req.is_a?(Hash) || req["key"].to_s.empty?
      return false if @running
      return false if defined?($game_temp) && $game_temp && ($game_temp.in_battle rescue false)
      return false if Time.now.to_f-req["armedAt"].to_f<0.20
      # Require a stable overworld after Reset. F12 can rebuild scripts before
      # Scene_Map/$game_map are ready, so count several healthy map frames instead
      # of launching the battle during reconstruction.
      return false if defined?($game_temp) && !$game_temp
      return false if defined?($game_map) && !$game_map
      if defined?(Scene_Map) && defined?($scene) && $scene && !$scene.is_a?(Scene_Map)
        return false
      end
      req["readyFrames"]=req["readyFrames"].to_i+1
      return false if req["readyFrames"].to_i<12
      key=req["key"].to_s
      @pending_f12_resume=nil
      @f12_resume_armed=false
      clear_active_battle
      write_status("f12_resuming",{"key"=>key,"message"=>"Reiniciando Test game tras F12…"})
      run_blueprint(key,true)
      true
    rescue => e
      log("F12 auto-resume failed: #{e.class}: #{e.message}")
      @pending_f12_resume=nil
      @f12_resume_armed=false
      clear_active_battle
      write_status("error",{"message"=>"F12 resume: #{e.class}: #{e.message}"})
      false
    end

    def resume_active_battle
      schedule_active_battle_resume
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

      # Only an explicit editor Test game session gets an F12 resume marker.
      # Event-command battles (pbBSSBattle) and ordinary gameplay never do.
      write_status("running",{"key"=>bp["key"],"name"=>bp["name"],"formation"=>mode,"sos"=>sos_enabled,"boss"=>(hget(bp,"boss","enabled")==true)})
      bgm_name=hget(bp,"environment","bgm").to_s.strip
      bgm=if !bgm_name.empty? then bgm_name elsif foe_trainer then pbGetTrainerBattleBGM([foe_trainer]) else pbGetWildBattleBGM(foe_party) end
      anim_type=foe_trainer ? (battle.singleBattle? ? 1 : 3) : (foe_party.length==1 ? 0 : 2)
      subject=foe_trainer ? [foe_trainer] : foe_party
      outcome=0
      battle_error=nil
      # Keep a marker only while an editor-launched test is actually inside the
      # battle. F12 raises Reset (outside StandardError), so that marker survives
      # the interrupted call and the freshly reloaded BSS runtime can ask Studio
      # to requeue the exact same test through the normal control bridge.
      write_active_battle(bp["key"],true) if live_test
      pbBattleAnimation(bgm,anim_type,subject) do
        begin
          pbSceneStandby { outcome=battle.pbStartBattle }
          BattleCreationHelperMethods.after_battle(outcome,true,battle)
        rescue SystemStackError => e
          battle_error=e
          log("Battle runtime SystemStackError: #{e.message}")
        rescue => e
          battle_error=e
          log("Battle runtime failed: #{e.class}: #{e.message}")
        end
      end
      clear_active_battle if live_test
      if battle_error
        write_status("error",{"key"=>key.to_s,"message"=>"#{battle_error.class}: #{battle_error.message}","backtrace"=>(battle_error.backtrace||[])[0,16]})
        return false
      end
      write_status("finished",{"key"=>bp["key"],"decision"=>outcome})
      outcome
    rescue SystemStackError => e
      clear_active_battle if live_test
      log("SystemStackError: #{e.message}"); write_status("error",{"key"=>key.to_s,"message"=>"SystemStackError: #{e.message}","backtrace"=>(e.backtrace||[])[0,16]}); false
    rescue => e
      clear_active_battle if live_test
      log("Battle launch failed: #{e.class}: #{e.message}"); write_status("error",{"key"=>key.to_s,"message"=>"#{e.class}: #{e.message}","backtrace"=>(e.backtrace||[])[0,16]}); false
    rescue Exception => e
      # Reset/F12 does not inherit StandardError. Mark it explicitly before the
      # exception returns to Essentials' Main loop, then re-raise so the normal
      # F12 reload still happens. A normal close/crash never gets this flag.
      if live_test && e.class.to_s=="Reset"
        mark_active_battle_reset((defined?(bp) && bp.is_a?(Hash)) ? bp["key"] : key)
        write_status("f12_resuming",{"key"=>key.to_s,"message"=>"F12 detectado · esperando que el mapa termine de recargar…"}) rescue nil
      end
      raise
    ensure
      @running=false
      if live_test && defined?($player)&&$player&&defined?(original_party)&&original_party&&$player.respond_to?(:party=); $player.party=original_party; end
      if defined?($game_temp)&&$game_temp
        begin; $game_temp.clear_battle_rules; rescue; end
        if defined?(old_rules)&&old_rules.is_a?(Hash); begin; old_rules.each { |k,v| $game_temp.battle_rules[k]=v }; rescue; end; end
        $game_temp.in_battle=old_in_battle if defined?(old_in_battle)&&$game_temp.respond_to?(:in_battle=)
      end
    end

    def runtime_ready!
      clear_cache rescue nil
      @running=false
      @last_control_token=nil
      # Reset itself is not an error. If an editor-launched battle marker survived
      # F12, arm exactly one runtime-owned resume. on_game_load can fire more than
      # once during a reload, so keep the pending request rather than duplicating it.
      return true if @f12_resume_armed==true && @pending_f12_resume.is_a?(Hash)
      raw=active_battle_request rescue nil
      if raw.is_a?(Hash) && schedule_active_battle_resume
        @f12_resume_armed=true
        return true
      end
      clear_active_battle if raw.is_a?(Hash)
      @pending_f12_resume=nil
      @f12_resume_armed=false
      write_status("ready",{"message"=>"BSS 0.6.37 ready · runtime reloaded"})
      true
    rescue => e
      log("Runtime ready bridge warning: #{e.class}: #{e.message}")
      false
    end

    def read_control
      return nil if !File.exist?(CONTROL_FILE)
      json_parse(File.open(CONTROL_FILE,"rb") { |f| f.read })
    rescue; nil; end

    def poll_control
      req=read_control; return false if !req.is_a?(Hash)
      action=req["action"].to_s; return false if action!="test" && action!="start_test"
      return false if defined?($game_temp)&&$game_temp&&($game_temp.in_battle rescue false)
      stamp=req["requestedAt"].to_i
      if stamp>0 && ((Time.now.to_f*1000).to_i-stamp)>300000
        File.delete(CONTROL_FILE) rescue nil
        return false
      end
      token=(req["id"]||req["requestedAt"]||req["key"]).to_s; return false if token.empty? || token==@last_control_token
      @last_control_token=token; File.delete(CONTROL_FILE) rescue nil
      # A fresh editor test replaces any pending F12 resume and arms the bridge
      # again for the next Reset.
      @pending_f12_resume=nil
      @f12_resume_armed=false
      clear_active_battle
      run_blueprint(req["key"].to_s,true); true
    rescue => e
      log("Control bridge failed: #{e.class}: #{e.message}"); write_status("error",{"message"=>"#{e.class}: #{e.message}"}); false
    end
  end
end

# F12 behavior: Reset reloads scripts, then BSS restores the same editor live
# test from its runtime marker after the overworld has settled. Ordinary gameplay
# and pbBSSBattle never write that marker and are never auto-launched.
begin
  BSS064.runtime_ready!
rescue
end

def pbBSSBattle(key)
  BSS064.run_blueprint(key,false)
end

if defined?(EventHandlers)
  EventHandlers.add(:on_game_load,:bss_064_ready,proc do
    begin
      BSS064.runtime_ready!
    rescue
    end
  end)
  EventHandlers.add(:on_frame_update,:bss_064_control,proc do
    begin
      resumed=BSS064.poll_f12_resume
      BSS064.poll_control if !resumed
    rescue
    end
  end)
end
