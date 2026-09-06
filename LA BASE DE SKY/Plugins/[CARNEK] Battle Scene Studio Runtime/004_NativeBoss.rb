#===============================================================================
# Battle Scene Studio Runtime 0.6.56
# BSS-native Boss/Totem layer.
#
# Totem aura goals:
# - EBDX-style charge sequence when opening stat stages are configured.
# - Persistent charged particles for the whole battle.
# - Persistent particles follow the *live* BattlerSprite geometry (x/y/z,
#   zoom, rotation, mirror, opacity and visibility) instead of a cached anchor.
# - The aura is updated from the same frame pumps used by normal battle UI and
#   BAS playback, so target selection/message windows do not freeze it.
# - When Battle Animation Studio Runtime is present, the charge sequence uses a
#   BAS camera-only timeline to focus/zoom the Totem. Without BAS, the exact
#   same charge sequence plays without camera zoom.
# - BSS aura sprites are registered in Scene#@sprites. A tiny BAS compatibility
#   layer marks their keys as world sprites so BAS camera transforms also affect
#   them while move/common animations are running.
#
# The default particle/ray/ripple behavior is adapted from the supplied Elite
# Battle DX AURAFLARE/charged behavior, but this runtime remains BSS-owned and
# does not require EBDX to be installed.
#===============================================================================
module BSS064
  BOSS_AURA_FRAME_GRAPHICS = [
    "Graphics/BattleSceneStudio/Auras/TotemCharged001.png",
    "Graphics/BattleSceneStudio/Auras/TotemCharged002.png",
    "Graphics/BattleSceneStudio/Auras/TotemCharged003.png",
    "Graphics/BattleSceneStudio/Auras/TotemCharged004.png"
  ]
  BOSS_INTRO_PARTICLES    = [
    "Graphics/BattleSceneStudio/Auras/TotemIntroParticle001.png",
    "Graphics/BattleSceneStudio/Auras/TotemIntroParticle002.png",
    "Graphics/BattleSceneStudio/Auras/TotemIntroParticle003.png",
    "Graphics/BattleSceneStudio/Auras/TotemIntroParticle004.png"
  ]
  BOSS_AURA_RAY_GRAPHIC   = "Graphics/BattleSceneStudio/Auras/TotemAuraRay.png"
  BOSS_AURA_RIPPLE_GRAPHIC= "Graphics/BattleSceneStudio/Auras/TotemAuraRipple.png"
  BOSS_AURA_IMPACT_GRAPHIC= "Graphics/BattleSceneStudio/Auras/TotemImpact.png"
  BOSS_AURA_DEFAULT_RGB   = [221, 68, 91]

  class << self
    # Apply BSS-native wild-boss attributes before Battle.new creates
    # Battle::Battler objects. Older boss.dbk JSON is read only as migration
    # input; BSS does not require DBK to own or execute these attributes.
    def apply_native_boss_party_attributes(foe_party, bp)
      cfg=hget(bp,"boss");cfg={} if !cfg.is_a?(Hash)
      return false if cfg["enabled"]!=true
      raw=cfg["attributes"];raw=cfg["dbk"] if !raw.is_a?(Hash) # migration only
      raw={} if !raw.is_a?(Hash)
      party=foe_party.is_a?(Array) ? foe_party : []
      return false if party.empty?
      idx=clamp_int(cfg["foeIndex"],0,[party.length-1,0].max,0)
      pkmn=party[idx];return false if !pkmn

      # v0.6.56: an immunity checkbox is authoritative by itself. Older builds
      # incorrectly gated every selected immunity behind attributes.enabled, so
      # valid JSON such as immunities:["RECOIL"] silently did nothing whenever
      # the HP-multiplier master switch was off. Keep the master switch only for
      # HP multiplication and always stamp the selected immunities on the Boss.
      allowed=%w[SLEEP POISON BURN PARALYSIS FROZEN FROSTBITE DROWSY CONFUSION ATTRACT ALLSTATUS FLINCH CRITICALHIT STATDROPS PPLOSS TYPECHANGE ITEMREMOVAL ABILITYREMOVAL INDIRECT RECOIL DISABLE OHKO SELFKO ESCAPE TRANSFORM]
      vals=(raw["immunities"].is_a?(Array) ? raw["immunities"] : []).map { |x| x.to_s.upcase }.select { |x| allowed.include?(x) }.uniq
      pkmn.instance_variable_set(:@bss_native_boss_immunities,vals)

      mult=(raw.key?("hpMultiplier") ? raw["hpMultiplier"] : raw["hpLevel"]).to_i;mult=1 if mult<1
      if raw["enabled"]==true
        pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
        base_total=(pkmn.totalhp rescue 1).to_i;base_total=1 if base_total<1
        boosted=[base_total*mult,1].max
        pkmn.instance_variable_set(:@totalhp,boosted)
        begin
          rows=hget(bp,"teams","foes");row=(rows.is_a?(Array) ? rows[idx] : nil)
          pct=row.is_a?(Hash) && row.key?("hpPercent") ? clamp_float(row["hpPercent"],0,100,100) : 100.0
          hp=(boosted.to_f*pct/100.0).round;hp=1 if pct>0 && hp<1
          pkmn.instance_variable_set(:@hp,[[hp,0].max,boosted].min)
        rescue
          pkmn.instance_variable_set(:@hp,boosted)
        end
      else
        mult=1
      end
      pkmn.instance_variable_set(:@bss_native_boss_hp_multiplier,mult)
      raw["enabled"]==true || !vals.empty?
    rescue => e
      log("Boss native attributes warning: #{e.class}: #{e.message}")
      false
    end

    def configure_native_boss(battle, bp)
      cfg = hget(bp, "boss")
      cfg = {} if !cfg.is_a?(Hash)
      battle.bss_boss_config = cfg if battle.respond_to?(:bss_boss_config=)
      battle.bss_boss_applied = false if battle.respond_to?(:bss_boss_applied=)
      battle.bss_boss_intro_pending = false if battle.respond_to?(:bss_boss_intro_pending=)
      battle.bss_boss_intro_shown = false if battle.respond_to?(:bss_boss_intro_shown=)
      battle.bss_boss_aura_active = false if battle.respond_to?(:bss_boss_aura_active=)
      battle.bss_boss_shield_segments = 0 if battle.respond_to?(:bss_boss_shield_segments=)
      battle.bss_boss_shield_max = 0 if battle.respond_to?(:bss_boss_shield_max=)
      battle.bss_boss_shield_started = false if battle.respond_to?(:bss_boss_shield_started=)
      battle.bss_boss_shield_broken = false if battle.respond_to?(:bss_boss_shield_broken=)
      battle.instance_variable_set(:@bss653_boss_shield_intro_played,false)
      battle.instance_variable_set(:@bss653_boss_capture_visuals_locked,false)
      battle.instance_variable_set(:@bss665_boss_hud_ready,false)
      battle.instance_variable_set(:@bss665_retired_helper_indices,{})
      # Optional DBK databox style selected by the Blueprint. Apply it before
      # Battle::Scene constructs PokemonDataBox objects. "inherit" leaves any
      # project/battle-rule choice untouched. Long keeps DBK's own fallback to
      # Basic when a side later grows beyond one battler.
      begin
        hud=cfg["hud"].is_a?(Hash) ? cfg["hud"] : {}
        style=hud["databoxStyle"].to_s.downcase
        if style!="inherit" && battle.respond_to?(:databoxStyle=) && defined?(GameData::DataboxStyle)
          wanted=(style=="long" ? :Long : (style=="basic" ? :Basic : nil))
          battle.databoxStyle=wanted if wanted && (GameData::DataboxStyle.exists?(wanted) rescue false)
        end
      rescue => e
        log("Boss databox style 0.6.56 warning: #{e.class}: #{e.message}")
      end
      # Install after all plugins have loaded, but for every BSS battle (not only
      # Boss battles). The 0.6.72 gate owns only Vanilla DataBoxAppear and lets
      # DBK/custom styles fall through untouched. This is what restores the
      # visible Vanilla entrance slide in ordinary BSS battles too.
      begin
        install_boss_databox_appear_gate!
      rescue => e
        log("Databox appear gate 0.6.72 warning: #{e.class}: #{e.message}")
      end
      if cfg["enabled"] == true
        # Secondary sync for live/F12/event-created battles: even if the party
        # pre-pass was skipped, the selected immunity list must reach the actual
        # Boss Pokemon before any move can apply recoil or another blocked effect.
        begin
          raw=cfg["attributes"].is_a?(Hash) ? cfg["attributes"] : {}
          vals=raw["immunities"].is_a?(Array) ? raw["immunities"].map{|x|x.to_s.upcase}.uniq : []
          boss=(battle.bss_find_boss_battler_any rescue nil) if battle.respond_to?(:bss_find_boss_battler_any)
          boss ||= (battle.bss_find_boss_battler rescue nil) if battle.respond_to?(:bss_find_boss_battler)
          boss.pokemon.instance_variable_set(:@bss_native_boss_immunities,vals) if boss && boss.respond_to?(:pokemon) && boss.pokemon
        rescue => e
          log("Boss immunity live-sync warning: #{e.class}: #{e.message}")
        end
        install_bas_aura_compat
        install_scene_aura_compat(battle)
        ensure_boss_recoil_hooks! if respond_to?(:ensure_boss_recoil_hooks!)
        configure_boss_capture(battle,cfg)
      end
    rescue => e
      log("Boss configure failed: #{e.class}: #{e.message}")
    end

    # Raid-style capture is delegated to DBK's proven capture flow when that API
    # exists, but BSS gates it to the configured Boss only. SOS helpers must never
    # trigger the raid capture prompt just because they fainted first.
    def install_boss_capture_compat(battle)
      return false if !defined?(Battle::Battler)
      klass=Battle::Battler
      return false if !klass.method_defined?(:canRaidCapture?)
      klass.prepend(BSS064BossRaidCaptureGate652) if !klass.ancestors.include?(BSS064BossRaidCaptureGate652)
      true
    rescue => e
      log("Boss raid-style capture hook warning: #{e.class}: #{e.message}")
      false
    end

    def configure_boss_capture(battle,cfg)
      raw=cfg.is_a?(Hash) && cfg["capture"].is_a?(Hash) ? cfg["capture"] : {}
      enabled=(cfg.is_a?(Hash) && cfg["enabled"]==true && raw["enabled"]==true)
      battle.instance_variable_set(:@bss_boss_capture_config,raw)
      return false if !enabled
      return false if (battle.trainerBattle? rescue false)
      return false if !install_boss_capture_compat(battle)
      return false if !battle.respond_to?(:raidStyleCapture=)
      chance=clamp_int(raw["chance"],0,100,100)
      bgm=normalize_bgm_name(raw["bgm"])
      flee=raw["fleeMessage"].to_s
      battle.raidStyleCapture={:capture_chance=>chance,:capture_bgm=>(bgm.empty? ? nil : bgm),:flee_msg=>(flee.empty? ? nil : flee)}
      battle.disablePokeBalls=true if battle.respond_to?(:disablePokeBalls=)
      true
    rescue => e
      log("Boss raid-style capture configure warning: #{e.class}: #{e.message}")
      false
    end

    def bas_available?
      return false if !defined?(BattleAnimationStudioRuntime)
      return false if !defined?(BattleAnimationStudioRuntime::Player)
      true
    rescue
      false
    end

    def install_bas_aura_compat
      return false if !bas_available?
      klass = BattleAnimationStudioRuntime::Player
      # Only extend BAS when the method actually exists. This keeps BSS from
      # injecting an incomplete override into unrelated BAS builds/battles.
      has_world_key = klass.method_defined?(:camera_world_sprite_key?) || klass.private_method_defined?(:camera_world_sprite_key?)
      return false if !has_world_key
      if !klass.ancestors.include?(BSS064BASWorldSpriteCompat)
        klass.prepend(BSS064BASWorldSpriteCompat)
      end
      true
    rescue => e
      log("Boss BAS aura compat warning: #{e.class}: #{e.message}")
      false
    end

    def install_scene_aura_compat(battle)
      scene = battle.instance_variable_get(:@scene) rescue nil
      return false if !scene
      singleton = class << scene; self; end
      if (scene.respond_to?(:pbFrameUpdate) || scene.respond_to?(:pbUpdate)) && !singleton.ancestors.include?(BSS064BossAuraFrameCompat)
        singleton.prepend(BSS064BossAuraFrameCompat)
      end
      if scene.respond_to?(:bas_runtime_pump_frame) && !singleton.ancestors.include?(BSS064BossAuraBASPumpCompat)
        singleton.prepend(BSS064BossAuraBASPumpCompat)
      end
      if !singleton.ancestors.include?(BSS064BossAnimationScaleCompat)
        singleton.prepend(BSS064BossAnimationScaleCompat)
      end
      if !singleton.ancestors.include?(BSS064BossHUDSceneCompat)
        singleton.prepend(BSS064BossHUDSceneCompat)
      end
      if scene.respond_to?(:pbPlayBattleAnimationStudio) && !singleton.ancestors.include?(BSS064BossBASAnimationScaleCompat)
        singleton.prepend(BSS064BossBASAnimationScaleCompat)
      end
      if (scene.respond_to?(:_carnek_sleep_ensure_bitmaps) || scene.respond_to?(:_carnek_hit_apply_pending)) && !singleton.ancestors.include?(BSS064DynamicBattlerBitmapCompat)
        singleton.prepend(BSS064DynamicBattlerBitmapCompat)
      end
      install_faint_bitmap_compat
      true
    rescue => e
      log("Boss scene compat warning: #{e.class}: #{e.message}")
      false
    end

    def install_faint_bitmap_compat
      names=[:BattlerFaintShrink,:BattlerFaintRecall]
      return false if !defined?(Battle::Scene::Animation)
      names.each do |name|
        begin
          klass=Battle::Scene::Animation.const_get(name)
          next if !klass || !klass.method_defined?(:pbUpdateFaintOverlay) || klass.ancestors.include?(BSS064FaintBitmapAuraCompat)
          klass.prepend(BSS064FaintBitmapAuraCompat)
        rescue
        end
      end
      true
    rescue
      false
    end

    # Numeric config can be absent in older blueprints. Avoid Integer(nil)/
    # Float(nil) entirely: mkxp-z/PBDebug reports even rescued exceptions, which
    # previously produced an endless TypeError log from the aura frame loop.
    def clamp_int(v, min, max, fallback)
      lo=min.to_i; hi=max.to_i
      base=fallback.is_a?(Numeric) ? fallback.to_i : lo
      n=base
      if v.is_a?(Numeric)
        n=v.to_i
      elsif !v.nil?
        text=v.to_s.strip
        n=text.to_f.to_i if text =~ /\A[+-]?(?:\d+(?:\.\d*)?|\.\d+)\z/
      end
      [[n,lo].max,hi].min
    end

    def clamp_float(v, min, max, fallback)
      lo=min.to_f; hi=max.to_f
      base=fallback.is_a?(Numeric) ? fallback.to_f : lo
      n=base
      if v.is_a?(Numeric)
        n=v.to_f
      elsif !v.nil?
        text=v.to_s.strip
        n=text.to_f if text =~ /\A[+-]?(?:\d+(?:\.\d*)?|\.\d+)\z/
      end
      n=base if n.respond_to?(:finite?) && !n.finite?
      [[n,lo].max,hi].min
    end

    def aura_color_rgb(value)
      s = value.to_s.strip
      if s =~ /\A#?([0-9a-fA-F]{6})\z/
        hex = $1
        return [hex[0,2].to_i(16), hex[2,2].to_i(16), hex[4,2].to_i(16)]
      end
      BOSS_AURA_DEFAULT_RGB.clone
    rescue
      BOSS_AURA_DEFAULT_RGB.clone
    end

    def aura_graphic_paths(raw)
      fallback=BOSS_AURA_FRAME_GRAPHICS.clone
      raw={} if !raw.is_a?(Hash)
      mode=raw["graphicMode"].to_s.downcase
      mode="sequence" if !["single","sequence","sheet"].include?(mode)
      clean=lambda do |v|
        path=v.to_s.strip.tr("\\","/")
        next nil if path.empty? || path.include?("..")
        next nil if path !~ /\AGraphics\/.+\.(?:png|gif|jpg|jpeg|webp)\z/i
        path
      end
      if mode=="single" || mode=="sheet"
        one=clean.call(raw["particleGraphic"]) || fallback[0]
        return [one]
      end
      rows=raw["particleGraphics"].is_a?(Array) ? raw["particleGraphics"] : []
      rows=rows[0,24].map { |v| clean.call(v) }.compact
      rows.empty? ? fallback : rows
    rescue
      BOSS_AURA_FRAME_GRAPHICS.clone
    end

    # Crop a spritesheet into independent Bitmap frames. This uses the same
    # left-to-right, then top-to-bottom order as Aura Studio's canvas preview.
    # The source bitmap is disposed after the cells are copied, so persistent
    # particles never hold the whole sheet as their visible frame.
    def aura_sheet_bitmaps(path, raw)
      raw={} if !raw.is_a?(Hash)
      source=new_bitmap(path)
      return [] if !source || (source.disposed? rescue true)
      cols=clamp_int(raw["sheetColumns"],1,32,4)
      rows=clamp_int(raw["sheetRows"],1,32,1)
      total=[cols*rows,1].max
      start=clamp_int(raw["sheetStartFrame"],0,total-1,0)
      count=clamp_int(raw["sheetFrameCount"],1,total-start,[4,total-start].min)
      fw=source.width.to_i/cols
      fh=source.height.to_i/rows
      return [source] if fw<=0 || fh<=0
      result=[]
      count.times do |n|
        idx=start+n
        break if idx>=total
        bmp=Bitmap.new(fw,fh)
        bmp.blt(0,0,source,Rect.new((idx%cols)*fw,(idx/cols)*fh,fw,fh))
        result << bmp
      end
      source.dispose if source && !(source.disposed? rescue true)
      result
    rescue => e
      begin; source.dispose if source && !(source.disposed? rescue true); rescue; end
      log("Boss aura sheet crop failed #{path}: #{e.class}: #{e.message}")
      []
    end

    def aura_layer_config(raw, index=0)
      raw={} if !raw.is_a?(Hash)
      mode=raw["graphicMode"].to_s.downcase
      mode="single" if !["single","sequence","sheet"].include?(mode)
      spawn=raw["spawnMode"].to_s.downcase
      spawn="async" if !["async","simultaneous"].include?(spawn)
      depth=raw["depthMode"].to_s.downcase
      depth="alternate" if !["alternate","front","back"].include?(depth)
      blend=raw["blendMode"].to_s.downcase
      blend="additive" if !["normal","additive"].include?(blend)
      seq=aura_graphic_paths(raw.merge("graphicMode"=>"sequence"))
      one=raw["particleGraphic"].to_s.strip
      one=(seq[0] || BOSS_AURA_FRAME_GRAPHICS[0]) if one.empty?
      {
        "id"                    => (raw["id"].to_s.empty? ? "layer_#{index.to_i+1}" : raw["id"].to_s),
        "name"                  => (raw["name"].to_s.empty? ? "Capa paralela #{index.to_i+1}" : raw["name"].to_s),
        "enabled"               => raw["enabled"] != false,
        "graphicMode"           => mode,
        "particleGraphic"       => one,
        "particleGraphics"      => seq,
        "sheetColumns"          => clamp_int(raw["sheetColumns"],1,32,4),
        "sheetRows"             => clamp_int(raw["sheetRows"],1,32,1),
        "sheetFrameCount"       => clamp_int(raw["sheetFrameCount"],1,256,4),
        "sheetStartFrame"       => clamp_int(raw["sheetStartFrame"],0,255,0),
        "graphicFrameFrames"    => clamp_float(raw["graphicFrameFrames"],1.0,60.0,6.0),
        "graphicTransitionFrames"=> clamp_float(raw["graphicTransitionFrames"],0.0,30.0,2.0),
        "opacity"               => clamp_float(raw["opacity"],0.0,100.0,100.0),
        "opacityStart"          => clamp_float(raw["opacityStart"],0.0,100.0,0.0),
        "opacityMid"            => clamp_float(raw["opacityMid"],0.0,100.0,100.0),
        "opacityEnd"            => clamp_float(raw["opacityEnd"],0.0,100.0,0.0),
        "particleCount"         => clamp_int(raw["particleCount"],1,48,12),
        "scale"                 => clamp_float(raw["scale"],10.0,300.0,100.0),
        "riseSpeed"             => clamp_float(raw["riseSpeed"],10.0,400.0,135.0),
        "cycleFrames"           => clamp_float(raw["cycleFrames"],6.0,180.0,30.0),
        "riseHeight"            => clamp_float(raw["riseHeight"],10.0,400.0,100.0),
        "spreadX"               => clamp_float(raw["spreadX"],10.0,300.0,100.0),
        "spreadY"               => clamp_float(raw["spreadY"],10.0,300.0,80.0),
        "laneWidth"             => clamp_float(raw["laneWidth"],10.0,300.0,100.0),
        "swayAmount"            => clamp_float(raw["swayAmount"],0.0,400.0,100.0),
        "stretchStart"          => clamp_float(raw["stretchStart"],10.0,300.0,62.0),
        "stretchEnd"            => clamp_float(raw["stretchEnd"],10.0,400.0,132.0),
        "spawnMode"             => spawn,
        "asyncAmount"           => clamp_float(raw["asyncAmount"],0.0,500.0,100.0),
        "phaseOffset"           => clamp_float(raw["phaseOffset"],0.0,100.0,((index.to_i+1)*23)%100),
        "offsetX"               => clamp_float(raw["offsetX"],-200.0,200.0,0.0),
        "offsetY"               => clamp_float(raw["offsetY"],-200.0,200.0,0.0),
        "depthMode"             => depth,
        "blendMode"             => blend
      }
    rescue
      {
        "id"=>"layer_#{index.to_i+1}","name"=>"Capa paralela #{index.to_i+1}","enabled"=>true,
        "graphicMode"=>"single","particleGraphic"=>BOSS_AURA_FRAME_GRAPHICS[0],
        "particleGraphics"=>BOSS_AURA_FRAME_GRAPHICS.clone,"sheetColumns"=>4,"sheetRows"=>1,"sheetFrameCount"=>4,"sheetStartFrame"=>0,
        "graphicFrameFrames"=>6.0,"graphicTransitionFrames"=>2.0,"opacity"=>100.0,"opacityStart"=>0.0,"opacityMid"=>100.0,"opacityEnd"=>0.0,"particleCount"=>12,"scale"=>100.0,
        "riseSpeed"=>135.0,"cycleFrames"=>30.0,"riseHeight"=>100.0,"spreadX"=>100.0,"spreadY"=>80.0,
        "laneWidth"=>100.0,"swayAmount"=>100.0,"stretchStart"=>62.0,"stretchEnd"=>132.0,
        "spawnMode"=>"async","asyncAmount"=>100.0,"phaseOffset"=>((index.to_i+1)*23)%100,
        "offsetX"=>0.0,"offsetY"=>0.0,"depthMode"=>"alternate","blendMode"=>"additive"
      }
    end

    def boss_aura_config(boss_cfg)
      raw = boss_cfg.is_a?(Hash) && boss_cfg["aura"].is_a?(Hash) ? boss_cfg["aura"] : {}
      spawn_mode=raw["spawnMode"].to_s.downcase
      spawn_mode="async" if !["async","simultaneous"].include?(spawn_mode)
      graphic_mode=raw["graphicMode"].to_s.downcase
      graphic_mode="sequence" if !["single","sequence","sheet"].include?(graphic_mode)
      depth=raw["depthMode"].to_s.downcase; depth="alternate" if !["alternate","front","back"].include?(depth)
      blend=raw["blendMode"].to_s.downcase; blend="normal" if !["normal","additive"].include?(blend)
      {
        "profileId"      => (raw["profileId"].to_s.empty? ? "ebdx_default" : raw["profileId"].to_s),
        "enabled"        => raw["enabled"] != false,
        "introEnabled"   => raw["introEnabled"] != false,
        "introSpotlight" => raw["introSpotlight"] != false,
        "color"          => (raw["color"].to_s.empty? ? "#DD445B" : raw["color"].to_s),
        "particleCount"  => clamp_int(raw["particleCount"], 1, 48, 12),
        "riseSpeed"      => clamp_float(raw["riseSpeed"], 10.0, 400.0, 135.0),
        "cycleFrames"    => clamp_float(raw["cycleFrames"], 6.0, 180.0, 30.0),
        "riseHeight"     => clamp_float(raw["riseHeight"], 10.0, 400.0, 100.0),
        "spreadX"        => clamp_float(raw["spreadX"], 10.0, 300.0, 100.0),
        "spreadY"        => clamp_float(raw["spreadY"], 10.0, 300.0, 80.0),
        "laneWidth"      => clamp_float(raw["laneWidth"], 10.0, 300.0, 100.0),
        "swayAmount"     => clamp_float(raw["swayAmount"], 0.0, 400.0, 100.0),
        "offsetX"        => clamp_float(raw["offsetX"], -200.0, 200.0, 0.0),
        "offsetY"        => clamp_float(raw["offsetY"], -200.0, 200.0, 0.0),
        "particleScale"  => clamp_float(raw["particleScale"], 10.0, 300.0, 100.0),
        "stretchStart"   => clamp_float(raw["stretchStart"], 10.0, 300.0, 62.0),
        "stretchEnd"     => clamp_float(raw["stretchEnd"], 10.0, 400.0, 132.0),
        "opacity"        => clamp_float(raw["opacity"], 0.0, 100.0, 100.0),
        "opacityStart"   => clamp_float(raw["opacityStart"], 0.0, 100.0, 0.0),
        "opacityMid"     => clamp_float(raw["opacityMid"], 0.0, 100.0, 100.0),
        "opacityEnd"     => clamp_float(raw["opacityEnd"], 0.0, 100.0, 0.0),
        "spawnMode"      => spawn_mode,
        "asyncAmount"    => clamp_float(raw["asyncAmount"], 0.0, 500.0, 100.0),
        "graphicMode"    => graphic_mode,
        "particleGraphic"=> (raw["particleGraphic"].to_s.empty? ? BOSS_AURA_FRAME_GRAPHICS[0] : raw["particleGraphic"].to_s),
        "particleGraphics"=> aura_graphic_paths(raw.merge("graphicMode"=>"sequence")),
        "sheetColumns"   => clamp_int(raw["sheetColumns"],1,32,4),
        "sheetRows"      => clamp_int(raw["sheetRows"],1,32,1),
        "sheetFrameCount"=> clamp_int(raw["sheetFrameCount"],1,256,4),
        "sheetStartFrame"=> clamp_int(raw["sheetStartFrame"],0,255,0),
        "graphicFrameFrames"=> clamp_float(raw["graphicFrameFrames"], 1.0, 60.0, 6.0),
        "graphicTransitionFrames"=> clamp_float(raw["graphicTransitionFrames"], 0.0, 30.0, 2.0),
        "parallelLayers"  => (raw["parallelLayers"].is_a?(Array) ? raw["parallelLayers"][0,8].each_with_index.map { |layer,i| aura_layer_config(layer,i) } : []),
        "depthMode"      => depth,
        "blendMode"      => blend,
        "introDuration"  => clamp_int(raw["introDuration"], 48, 180, 104),
        "impactHold"     => clamp_int(raw["impactHold"], 0, 120, 56),
        "introReturnFrames"=> clamp_int(raw["introReturnFrames"], 8, 60, 24),
        "fadeOutFrames"  => clamp_int(raw["fadeOutFrames"], 1, 90, 18),
        "outlineEnabled" => raw["outlineEnabled"] != false,
        "outlineColor"   => (raw["outlineColor"].to_s.empty? ? (raw["color"].to_s.empty? ? "#DD445B" : raw["color"].to_s) : raw["outlineColor"].to_s),
        "outlineOpacity" => clamp_float(raw["outlineOpacity"], 0.0, 100.0, 46.0),
        "outlineSize"    => clamp_int(raw["outlineSize"], 1, 8, 2),
        "outlineEffect"  => (["standard","roaring_knight","pulse"].include?(raw["outlineEffect"].to_s) ? raw["outlineEffect"].to_s : "standard"),
        "outlineCopies"  => clamp_int(raw["outlineCopies"], 1, 12, 6),
        "outlineCopySpacing"=> clamp_float(raw["outlineCopySpacing"], 25.0, 300.0, 100.0),
        "roaringStrength"=> clamp_float(raw["roaringStrength"], 0.0, 250.0, 100.0),
        "roaringSpeed"   => clamp_float(raw["roaringSpeed"], 10.0, 300.0, 100.0),
        "pulseStrength"  => clamp_float(raw["pulseStrength"], 0.0, 250.0, 100.0),
        "pulseSpeed"     => clamp_float(raw["pulseSpeed"], 10.0, 300.0, 100.0),
        "basZoomEnabled" => raw["basZoomEnabled"] != false,
        "basZoom"        => clamp_float(raw["basZoom"], 100.0, 220.0, 150.0),
        "basZoomBounds"  => (["screen","extended"].include?(raw["basZoomBounds"].to_s) ? raw["basZoomBounds"].to_s : "screen"),
        "ebdxCenterMon"     => raw["ebdxCenterMon"] == true,
        "ebdxCenterOffsetX" => clamp_float(raw["ebdxCenterOffsetX"], -320.0, 320.0, 0.0),
        "ebdxCenterOffsetY" => clamp_float(raw["ebdxCenterOffsetY"], -240.0, 240.0, 0.0)
      }
    rescue => e
      log("Boss aura config warning: #{e.class}: #{e.message}")
      boss_aura_config({"aura"=>{}}) unless boss_cfg.is_a?(Hash) && boss_cfg["aura"].is_a?(Hash) && boss_cfg["aura"].empty?
    end

    def resolve_bitmap_path(path)
      resolved = nil
      begin
        resolved = pbResolveBitmap(path) if defined?(pbResolveBitmap)
      rescue
      end
      resolved && !resolved.to_s.empty? ? resolved : path
    end

    def new_bitmap(path)
      Bitmap.new(resolve_bitmap_path(path))
    rescue => e
      log("Boss aura bitmap failed #{path}: #{e.class}: #{e.message}")
      nil
    end

    # Safe SE bridge used by the aura intro. 0.6.45 called this helper but did
    # not define it, which spammed NoMethodError every frame of the charge.
    def play_aura_se(name, volume=100, pitch=100)
      file=name.to_s.strip
      return false if file.empty?
      vol=clamp_int(volume,0,200,100)
      pit=clamp_int(pitch,20,200,100)
      begin
        pbSEPlay(file,vol,pit) if defined?(pbSEPlay)
        return true
      rescue
      end
      begin
        path=file.gsub(/\\/,"/")
        path="Audio/SE/#{path}" if path !~ /\AAudio\/SE\//i
        path += ".ogg" if File.extname(path).to_s.empty?
        Audio.se_play(path,vol,pit) if defined?(Audio) && Audio.respond_to?(:se_play)
        return true
      rescue => e
        log("Boss aura SE warning #{file}: #{e.class}: #{e.message}")
      end
      false
    end

    # Real-time clock for aura pacing. Graphics.frame_rate is not reliable in
    # every mkxp-z/LBDS setup (some projects render at 120 FPS while reporting
    # a lower logical rate), which made the passive aura race ahead.
    def monotonic_seconds
      # The user's base exposes System.unscaled_uptime specifically so Turbo
      # can speed gameplay without shortening authored animation timing.
      if defined?(System) && System.respond_to?(:unscaled_uptime)
        value=(System.unscaled_uptime.to_f rescue nil)
        return value if value && value>=0
      end
      if Process.respond_to?(:clock_gettime) && defined?(Process::CLOCK_MONOTONIC)
        value=(Process.clock_gettime(Process::CLOCK_MONOTONIC).to_f rescue nil)
        return value if value && value>=0
      end
      if defined?(System) && System.respond_to?(:uptime)
        value=(System.uptime.to_f rescue nil)
        return value if value && value>=0
      end
      fc=(Graphics.frame_count rescue 0).to_f
      fr=(Graphics.frame_rate rescue 40).to_f
      fr=40.0 if fr<=0
      fc/fr
    rescue
      Time.now.to_f
    end
  end

  # Geometry helpers shared by the intro and persistent emitter.
  module BossAuraGeometry
    def target_state(target_sprite)
      return nil if !target_sprite || (target_sprite.respond_to?(:disposed?) && target_sprite.disposed?)
      bmp = target_sprite.respond_to?(:bitmap) ? target_sprite.bitmap : nil
      return nil if !bmp || (bmp.respond_to?(:disposed?) && bmp.disposed?)
      src=(target_sprite.src_rect rescue nil)
      visible_w=(src && src.width.to_i>0) ? src.width.to_f : bmp.width.to_f
      visible_h=(src && src.height.to_i>0) ? src.height.to_f : bmp.height.to_f
      {
        :x => (target_sprite.x rescue 0).to_f,
        :y => (target_sprite.y rescue 0).to_f,
        :z => (target_sprite.z rescue 50).to_i,
        :ox => (target_sprite.ox rescue 0).to_f,
        :oy => (target_sprite.oy rescue 0).to_f,
        :zoom_x => (target_sprite.zoom_x rescue 1.0).to_f,
        :zoom_y => (target_sprite.zoom_y rescue 1.0).to_f,
        :angle => (target_sprite.angle rescue 0).to_f,
        :mirror => !!(target_sprite.mirror rescue false),
        :opacity => (target_sprite.opacity rescue 255).to_i,
        :visible => (target_sprite.visible rescue true),
        # Use the actually visible frame, not the full animated battler sheet.
        # This is important for Animated Pokémon/BAS where bitmap.width can be
        # several frames wide even though only src_rect is on screen.
        :width => visible_w,
        :height => visible_h
      }
    rescue
      nil
    end

    def local_to_world(state, nx, ny, rise_px = 0.0)
      px = nx.to_f * state[:width]
      px = state[:width] - px if state[:mirror]
      py = ny.to_f * state[:height] - rise_px.to_f
      dx = (px - state[:ox]) * state[:zoom_x]
      dy = (py - state[:oy]) * state[:zoom_y]
      rad = state[:angle].to_f * Math::PI / 180.0
      cos = Math.cos(rad)
      sin = Math.sin(rad)
      [state[:x] + dx * cos - dy * sin, state[:y] + dx * sin + dy * cos]
    rescue
      [state[:x], state[:y]]
    end

    def target_center(state)
      local_to_world(state, 0.5, 0.48, 0.0)
    end

    def aura_tone(rgb)
      d = BSS064::BOSS_AURA_DEFAULT_RGB
      Tone.new(
        [[rgb[0].to_i - d[0], -255].max, 255].min,
        [[rgb[1].to_i - d[1], -255].max, 255].min,
        [[rgb[2].to_i - d[2], -255].max, 255].min,
        0
      )
    rescue
      Tone.new(0,0,0,0)
    end
  end

  # Persistent EBDX-style charged particles.
  # The original reference is a 4-frame strip, but BSS ships and loads four
  # separate frame PNGs. No persistent Sprite ever receives the full strip.
  class BossAuraEmitter
    include BossAuraGeometry

    def initialize(viewport, scene_sprites, cfg, key_prefix = "bss_totem_persistent")
      @viewport=viewport
      @scene_sprites=scene_sprites.is_a?(Hash) ? scene_sprites : nil
      @cfg=cfg || {}
      @key_prefix=key_prefix.to_s
      @particles=[]
      @frame=0.0
      @last_clock=nil
      @disposed=false
      @rgb=BSS064.aura_color_rgb(@cfg["color"])
      @tone=aura_tone(@rgb)
      @layers=[]
      build_layers
      count=[BSS064.clamp_int(@cfg["particleCount"],1,48,12),*@layers.map { |layer| layer[:particle_count].to_i }].max
      count=BSS064.clamp_int(count,1,48,12)
      count.times { |i| create_particle(i,count) }
    end

    def disposed?; @disposed; end

    def logical_step
      now=BSS064.monotonic_seconds
      if @last_clock.nil?
        @last_clock=now
        return 0.0
      end
      dt=now-@last_clock
      @last_clock=now
      return 0.0 if dt<=0
      dt=0.05 if dt>0.05
      dt*40.0
    rescue
      0.0
    end

    def layer_from_raw(raw, primary=false, index=0)
      raw={} if !raw.is_a?(Hash)
      src=primary ? @cfg : raw
      mode=src["graphicMode"].to_s.downcase
      mode=(primary ? "sequence" : "single") if !["single","sequence","sheet"].include?(mode)
      paths=BSS064.aura_graphic_paths(src.merge("graphicMode"=>mode))
      paths=BSS064::BOSS_AURA_FRAME_GRAPHICS.clone if paths.empty?
      bitmaps=if mode=="sheet"
        BSS064.aura_sheet_bitmaps(paths[0],src)
      else
        paths.map { |path| BSS064.new_bitmap(path) }.compact
      end
      return nil if bitmaps.empty?
      spawn=src["spawnMode"].to_s
      spawn="async" if !["async","simultaneous"].include?(spawn)
      depth=src["depthMode"].to_s
      depth="alternate" if !["alternate","front","back"].include?(depth)
      {
        :primary=>primary,
        :bitmaps=>bitmaps,
        :hold=>BSS064.clamp_float(src["graphicFrameFrames"],1,60,6),
        :transition=>BSS064.clamp_float(src["graphicTransitionFrames"],0,30,2),
        :opacity=>BSS064.clamp_float(src["opacity"],0,100,100)/100.0,
        :opacity_start=>BSS064.clamp_float(src["opacityStart"],0,100,0)/100.0,
        :opacity_mid=>BSS064.clamp_float(src["opacityMid"],0,100,100)/100.0,
        :opacity_end=>BSS064.clamp_float(src["opacityEnd"],0,100,0)/100.0,
        :particle_count=>BSS064.clamp_int(src["particleCount"],1,48,12),
        :pattern=>(%w[rise orbit vortex rain burst halo ground].include?(src["pattern"].to_s.downcase) ? src["pattern"].to_s.downcase : "rise"),
        :scale=>(primary ? BSS064.clamp_float(src["particleScale"],25,250,100)/100.0 : BSS064.clamp_float(src["scale"],10,300,100)/100.0),
        :rise_speed=>BSS064.clamp_float(src["riseSpeed"],25,300,135)/100.0,
        :cycle_frames=>BSS064.clamp_float(src["cycleFrames"],10,120,30),
        :rise_height=>BSS064.clamp_float(src["riseHeight"],20,300,100)/100.0,
        :spread_x=>BSS064.clamp_float(src["spreadX"],25,200,100)/100.0,
        :spread_y=>BSS064.clamp_float(src["spreadY"],25,180,80)/100.0,
        :lane_width=>BSS064.clamp_float(src["laneWidth"],25,200,100)/100.0,
        :sway_amount=>BSS064.clamp_float(src["swayAmount"],0,300,100)/100.0,
        :stretch_start=>BSS064.clamp_float(src["stretchStart"],10,250,62)/100.0,
        :stretch_end=>BSS064.clamp_float(src["stretchEnd"],10,300,132)/100.0,
        :spawn_mode=>spawn,
        :async_amount=>BSS064.clamp_float(src["asyncAmount"],0,300,100)/100.0,
        :phase_offset=>(primary ? 0.0 : BSS064.clamp_float(src["phaseOffset"],0,100,((index+1)*23)%100)/100.0),
        :offset_x=>BSS064.clamp_float(src["offsetX"],-100,100,0)/100.0,
        :offset_y=>BSS064.clamp_float(src["offsetY"],-100,100,0)/100.0,
        :depth=>depth,
        :blend=>(src["blendMode"].to_s.downcase=="additive" ? 1 : 0),
        :id=>(primary ? "main" : (src["id"].to_s.empty? ? "parallel_#{index+1}" : src["id"].to_s))
      }
    rescue => e
      BSS064.log("Boss aura layer warning: #{e.class}: #{e.message}")
      nil
    end

    def build_layers
      main=layer_from_raw(@cfg,true,0)
      @layers << main if main
      rows=@cfg["parallelLayers"].is_a?(Array) ? @cfg["parallelLayers"] : []
      rows[0,8].each_with_index do |raw,i|
        next if !raw.is_a?(Hash) || raw["enabled"]==false
        layer=layer_from_raw(raw,false,i)
        @layers << layer if layer
      end
    end

    def create_layer_sprite(layer, i, suffix)
      sp=Sprite.new(@viewport)
      bmp=layer[:bitmaps][0]
      if bmp
        sp.bitmap=bmp
        sp.ox=bmp.width/2
        sp.oy=bmp.height
      end
      sp.visible=false;sp.opacity=0
      sp.tone=@tone if sp.respond_to?(:tone=)
      sp.blend_type=layer[:blend] if sp.respond_to?(:blend_type=)
      key="#{@key_prefix}_#{layer[:id]}_#{i}_#{suffix}"
      @scene_sprites[key]=sp if @scene_sprites
      [sp,key]
    end

    def create_particle(i,count)
      denom=[count.to_i-1,1].max.to_f
      lane=i.to_f/denom
      layer_rows=@layers.map do |layer|
        a=create_layer_sprite(layer,i,"a");b=create_layer_sprite(layer,i,"b")
        # Every layer gets its own phase. Parallel async layers therefore do not
        # spawn on the same frame merely because the main particle did.
        particle_phase=(layer[:spawn_mode]=="simultaneous" ? 0.0 : i.to_f*7.0*layer[:async_amount])
        {:layer=>layer,:a=>a[0],:a_key=>a[1],:b=>b[0],:b_key=>b[1],:phase=>particle_phase}
      end
      @particles << {:layers=>layer_rows,:lane=>lane,:row=>(i%3),:front=>(i%2==0)}
    rescue => e
      BSS064.log("Boss aura particle create warning: #{e.class}: #{e.message}")
    end

    def dispose
      return if @disposed
      @particles.each do |row|
        row[:layers].each do |lr|
          [[:a,:a_key],[:b,:b_key]].each do |spk,keyk|
            sp=lr[spk];key=lr[keyk]
            begin;@scene_sprites.delete(key) if @scene_sprites && @scene_sprites[key].equal?(sp);rescue;end
            begin;sp.dispose if sp && !sp.disposed?;rescue;end
          end
        end
      end
      @particles.clear
      @layers.each do |layer|
        layer[:bitmaps].each { |bmp| begin;bmp.dispose if bmp && !bmp.disposed?;rescue;end }
        layer[:bitmaps].clear
      end
      @layers.clear;@disposed=true
    end

    def smoothstep01(x)
      x=[[x.to_f,0.0].max,1.0].min
      x*x*(3.0-2.0*x)
    end

    def layer_opacity_curve(layer,t)
      start=layer[:opacity_start].to_f;mid=layer[:opacity_mid].to_f;finish=layer[:opacity_end].to_f
      if t.to_f<=0.5
        q=smoothstep01(t.to_f*2.0);start+(mid-start)*q
      else
        q=smoothstep01((t.to_f-0.5)*2.0);mid+(finish-mid)*q
      end
    rescue
      1.0
    end

    # One-shot graphic sequence: 1 -> 2 -> 3 -> 4 -> final graphic while the
    # particle fades. It never loops 4 -> 1 inside one particle life.
    def sequence_state(layer,age)
      list=layer[:bitmaps]
      return [0,nil,1.0,0.0] if !list || list.length<=1
      hold=[layer[:hold].to_f,1.0].max;trans=[layer[:transition].to_f,0.0].max;cursor=[age.to_f,0.0].max
      (0...(list.length-1)).each do |i|
        return [i,nil,1.0,0.0] if cursor<hold
        cursor-=hold
        if trans>0.0
          if cursor<trans
            q=smoothstep01(cursor/trans);return [i,i+1,1.0-q,q]
          end
          cursor-=trans
        end
      end
      [list.length-1,nil,1.0,0.0]
    rescue
      [0,nil,1.0,0.0]
    end

    def assign_bitmap(sp,layer,index)
      return if !sp
      bmp=layer[:bitmaps][index.to_i] rescue nil
      return if !bmp
      if !sp.bitmap.equal?(bmp)
        sp.bitmap=bmp;sp.ox=bmp.width/2;sp.oy=bmp.height
      end
    rescue;end

    def hide_layer(lr)
      [lr[:a],lr[:b]].each do |sp|
        next if !sp || (sp.disposed? rescue true)
        sp.opacity=0;sp.visible=false
      end
    rescue;end

    def update_layer(lr,state,row,i,global_alpha,live_opacity)
      layer=lr[:layer]
      count=[layer[:particle_count].to_i,1].max
      if i>=count
        hide_layer(lr);return
      end
      speed=layer[:rise_speed].to_f
      life=[layer[:cycle_frames].to_f/[speed,0.25].max,14.0].max
      raw_frame=@frame+lr[:phase].to_f+(life*layer[:phase_offset].to_f)
      raw_t=(raw_frame % life)/life
      start_t=0.075;end_t=0.925
      if raw_t<=start_t || raw_t>=end_t
        hide_layer(lr);return
      end
      t=(raw_t-start_t)/(end_t-start_t);t=[[t,0.0].max,1.0].min
      lane=count>1 ? i.to_f/(count-1).to_f : 0.5
      pattern=layer[:pattern].to_s
      angle=(t*Math::PI*2.0)+(i*0.73)+(layer[:phase_offset].to_f*Math::PI*2.0)
      nx=0.5;ny=0.68;rise=0.0
      case pattern
      when "orbit"
        nx=0.5+Math.cos(angle*1.35)*0.30*layer[:spread_x].to_f
        ny=0.55+Math.sin(angle*1.35)*0.20*layer[:spread_y].to_f
      when "vortex"
        radius=(0.36-0.24*t)*layer[:spread_x].to_f
        nx=0.5+Math.cos(angle*2.4)*radius
        ny=0.66-0.24*t+Math.sin(angle*2.4)*0.09*layer[:spread_y].to_f
      when "rain"
        base_lane=0.5+0.72*(lane-0.5)*layer[:lane_width].to_f
        nx=0.5+(base_lane-0.5)*layer[:spread_x].to_f+Math.sin(angle)*0.010*layer[:sway_amount].to_f
        ny=0.16+0.72*t
      when "burst"
        theta=(i.to_f/[count,1].max.to_f)*Math::PI*2.0+layer[:phase_offset].to_f*Math::PI*2.0
        radius=0.06+0.36*t
        nx=0.5+Math.cos(theta)*radius*layer[:spread_x].to_f
        ny=0.57+Math.sin(theta)*radius*0.72*layer[:spread_y].to_f
      when "halo"
        theta=angle*1.15
        nx=0.5+Math.cos(theta)*0.29*layer[:spread_x].to_f
        ny=0.32+Math.sin(theta)*0.085*layer[:spread_y].to_f
      when "ground"
        nx=0.5+Math.cos(angle)*0.34*layer[:spread_x].to_f
        ny=0.79+Math.sin(angle)*0.065*layer[:spread_y].to_f
      else
        base_lane=0.5+0.68*(lane-0.5)*layer[:lane_width].to_f
        nx=0.5+(base_lane-0.5)*layer[:spread_x].to_f
        nx+=Math.sin(angle)*0.012*layer[:spread_x].to_f*layer[:sway_amount].to_f
        base_y=[0.68,0.54,0.78][row[:row].to_i%3]
        ny=0.5+(base_y-0.5)*layer[:spread_y].to_f
        rise=state[:height]*0.12*t*speed*layer[:rise_height].to_f
      end
      nx=[[nx+layer[:offset_x].to_f,0.04].max,0.96].min
      ny=[[ny+layer[:offset_y].to_f,0.08].max,0.94].min
      stretch=layer[:stretch_start].to_f+(layer[:stretch_end].to_f-layer[:stretch_start].to_f)*t
      base_alpha=(live_opacity.to_f/255.0)*layer[:opacity].to_f*layer_opacity_curve(layer,t)*global_alpha.to_f
      sequence_age=(raw_t-start_t)*life
      ia,ib,wa,wb=sequence_state(layer,sequence_age)
      assign_bitmap(lr[:a],layer,ia);assign_bitmap(lr[:b],layer,ib) if ib
      x,y=local_to_world(state,nx,ny,rise)
      depth=layer[:depth]
      z=depth=="front" ? state[:z]+1 : (depth=="back" ? state[:z]-1 : (row[:front] ? state[:z]+1 : state[:z]-1))
      [[:a,wa],[:b,wb]].each do |which,weight|
        sp=lr[which];next if !sp || (sp.disposed? rescue true)
        if weight.to_f<=0.001 || (which==:b && ib.nil?)
          sp.opacity=0;sp.visible=false;next
        end
        sp.x=x;sp.y=y;sp.z=z;sp.blend_type=layer[:blend] if sp.respond_to?(:blend_type=)
        sp.angle=state[:angle] if sp.respond_to?(:angle=);sp.mirror=((nx>=0.5) ^ state[:mirror]) if sp.respond_to?(:mirror=)
        sp.zoom_x=[state[:zoom_x].abs*layer[:scale].to_f,0.05].max
        sp.zoom_y=[state[:zoom_y].abs*layer[:scale].to_f*stretch,0.05].max
        alpha=base_alpha*weight.to_f;sp.opacity=[[(alpha*255.0).round,0].max,255].min;sp.visible=sp.opacity>1
      end
    rescue => e
      BSS064.log("Boss aura layer update warning: #{e.class}: #{e.message}");hide_layer(lr)
    end

    def update(target_sprite,battler,master_alpha=1.0,allow_fainted=false)
      return if @disposed
      state=target_state(target_sprite);fainted=(battler.fainted? rescue false)
      if !state || !battler || (fainted && !allow_fainted) || ((!state[:visible] || state[:opacity]<=0) && !allow_fainted) || @layers.empty?
        hide_all;return
      end
      step=logical_step;@frame+=step if step>0
      global_alpha=[[master_alpha.to_f,0.0].max,1.0].min
      live_opacity=state[:opacity].to_f
      @particles.each_with_index do |row,i|
        row[:layers].each { |lr| update_layer(lr,state,row,i,global_alpha,live_opacity) }
      end
    rescue => e
      BSS064.log("Boss aura update warning: #{e.class}: #{e.message}");hide_all
    end

    def hide_all
      @particles.each { |row| row[:layers].each { |lr| hide_layer(lr) } }
    rescue;end
  end

  # BSS-native long Boss HP bar with optional segmented barrier. The visual
  # language follows the supplied Raid Battles reference (long HP + shield
  # segments), while state and rendering remain completely owned by BSS.
  class BossHUD
    WIDTH=512
    HEIGHT=104
    FRAME_PATH="Graphics/BattleSceneStudio/BossHUD/databox_foe"
    HP_PATH="Graphics/BattleSceneStudio/BossHUD/overlay_hp_foe"
    SHIELD_BG_PATH="Graphics/BattleSceneStudio/BossHUD/shield_bg"
    SHIELD_PATH="Graphics/BattleSceneStudio/BossHUD/raid_shield"
    HP_X=50
    HP_Y=30
    SHIELD_X=150
    SHIELD_Y=46
    SHIELD_W=192
    SHIELD_H=6
    SHIELD_OFFSET_X=10
    SHIELD_OFFSET_Y=2
    SHIELD_SEGMENT_W=24
    # World/BAS foreground objects top out around z=2000. Keep the Boss HUD
    # above ordinary battle-world animation layers, but below explicit screen
    # overlays/transitions (BAS uses ~9999 for those).
    BASE_Z=3000

    def initialize(viewport,scene_sprites,battle,battler,cfg,key="bss_boss_hud")
      @viewport=viewport
      @scene_sprites=scene_sprites.is_a?(Hash) ? scene_sprites : nil
      @battle=battle;@battler=battler;@cfg=cfg.is_a?(Hash) ? cfg : {};@key=key;@disposed=false
      @owned_bitmaps=[];@sprites=[];@native_box=nil;@native_visible=nil;@last_label=nil
      @display_hp=nil;@last_target_hp=nil;@hp_anim_from=nil;@hp_anim_to=nil;@hp_anim_started=nil;@hp_hit_started=nil
      @last_shield_segments=nil;@last_shield_max=nil;@shield_spawn_started=nil;@shield_spawn_segments=[]
      @shield_ghosts=[];@shield_break_started=nil;@shield_break_done=false;@shield_break_se=false
      @faint_started=nil;@faint_complete=false
      # BossHUD behaves as one HUD object to BAS/DBK while internally rendering
      # several sprites. Opacity/visibility written by animation systems are
      # propagated to the entire group at the end of each update.
      @external_opacity=255
      @external_visible=true
      @toggle_from=1.0;@toggle_to=1.0;@toggle_started=nil;@toggle_duration=0.075
      build_graphical_hud
      @scene_sprites[@key]=self if @scene_sprites
      capture_native_databox
      update(@battler,true)
    rescue => e
      BSS064.log("Boss HUD create warning: #{e.class}: #{e.message}")
    end

    def disposed?;@disposed;end
    def fainting?;!!@faint_started;end
    def faint_complete?;@faint_complete==true;end

    # Sprite-like facade: BAS and the Aura intro can classify this object as UI
    # and fade/hide it without knowing about its internal frame/HP/shield sprites.
    def visible;@external_visible!=false && @external_opacity.to_i>0;end
    def visible=(value);@external_visible=(value!=false);end
    def opacity;@external_opacity.to_i;end
    def opacity=(value);@external_opacity=[[value.to_i,0].max,255].min;end
    def contents_opacity;opacity;end
    def contents_opacity=(value);self.opacity=value;end

    def request_visibility(show,duration=0.075)
      current=toggle_visibility_factor
      @toggle_from=current
      @toggle_to=show ? 1.0 : 0.0
      @toggle_started=now
      @toggle_duration=[duration.to_f,0.001].max
    rescue
    end

    def toggle_visibility_factor
      return @toggle_to.to_f if !@toggle_started
      p=[[((now-@toggle_started)/[@toggle_duration.to_f,0.001].max),0.0].max,1.0].min
      ease=p*p*(3.0-2.0*p)
      value=@toggle_from.to_f+(@toggle_to.to_f-@toggle_from.to_f)*ease
      if p>=1.0
        @toggle_started=nil
        @toggle_from=@toggle_to
      end
      [[value,0.0].max,1.0].min
    rescue
      1.0
    end

    def master_visibility_factor
      ext=(@external_visible==false ? 0.0 : [[@external_opacity.to_f/255.0,0.0].max,1.0].min)
      ext*toggle_visibility_factor
    rescue
      1.0
    end

    def reset_core_geometry
      return if !@graphical
      if @frame;@frame.x=@base_x;@frame.y=@base_y;@frame.opacity=255;@frame.zoom_x=1.0;@frame.zoom_y=1.0;end
      if @text;@text.x=@base_x;@text.y=@base_y;@text.opacity=255;@text.zoom_x=1.0;@text.zoom_y=1.0;end
      if @hp;@hp.x=@base_x+HP_X;@hp.y=@base_y+HP_Y;@hp.opacity=255;@hp.zoom_x=1.0;@hp.zoom_y=1.0;end
      begin;@hp.color=Color.new(0,0,0,0) if @hp;rescue;end
    rescue
    end

    def apply_master_visibility
      f=master_visibility_factor
      @sprites.each do |sp|
        next if !sp || (sp.disposed? rescue true)
        # Auxiliary shield/faint animations calculate their own opacity first.
        sp.opacity=(sp.opacity.to_f*f).round if sp.respond_to?(:opacity=)
        sp.visible=false if f<=0.005 && sp.respond_to?(:visible=)
      end
    rescue
    end

    def now
      BSS064.monotonic_seconds
    rescue
      (Graphics.frame_count rescue 0).to_f/40.0
    end

    def owned_bitmap(path)
      bmp=BSS064.new_bitmap(path)
      @owned_bitmaps << bmp if bmp
      bmp
    end

    def make_sprite(bitmap,zoff=0)
      return nil if !bitmap
      sp=Sprite.new(@viewport);sp.bitmap=bitmap;sp.z=BASE_Z+zoff
      @sprites << sp
      sp
    end

    def build_graphical_hud
      @frame_bitmap=owned_bitmap(FRAME_PATH)
      @hp_bitmap=owned_bitmap(HP_PATH)
      @shield_bg_bitmap=owned_bitmap(SHIELD_BG_PATH)
      @shield_bitmap=owned_bitmap(SHIELD_PATH)
      @graphical=!!(@frame_bitmap && @hp_bitmap)
      if @graphical
        @frame=make_sprite(@frame_bitmap,0)
        @hp=make_sprite(@hp_bitmap,2)
        @hp.src_rect.height=[@hp_bitmap.height/3,1].max if @hp && @hp.respond_to?(:src_rect)
        @text_bitmap=Bitmap.new(WIDTH,HEIGHT);@owned_bitmaps << @text_bitmap
        @text=make_sprite(@text_bitmap,4)
        begin;pbSetSmallFont(@text_bitmap) if defined?(pbSetSmallFont);rescue;begin;pbSetSystemFont(@text_bitmap) if defined?(pbSetSystemFont);rescue;end;end
        @shield_bg=make_sprite(@shield_bg_bitmap,1) if @shield_bg_bitmap
        if @shield_bitmap
          @shield_max=make_sprite(@shield_bitmap,2)
          @shield_live=make_sprite(@shield_bitmap,3)
        end
      else
        @fallback_bitmap=Bitmap.new(WIDTH,72);@owned_bitmaps << @fallback_bitmap
        @fallback=make_sprite(@fallback_bitmap,0)
        begin;pbSetSystemFont(@fallback_bitmap) if defined?(pbSetSystemFont);rescue;end
      end
      reposition
    end

    # Keep the supplied DBK Long offsets exactly. The old one-line modifier-if
    # around @fallback was parsed by Ruby in a way that still evaluated x= on nil,
    # aborting this method before HP/shield coordinates were assigned.
    def reposition
      x=[((Graphics.width rescue 640)-WIDTH)/2,0].max
      y=(@cfg["position"].to_s=="databox" ? 34 : 6)
      if @frame;@frame.x=x;@frame.y=y;end
      if @text;@text.x=x;@text.y=y;end
      if @fallback;@fallback.x=x;@fallback.y=y;end
      if @hp;@hp.x=x+HP_X;@hp.y=y+HP_Y;end
      if @shield_bg;@shield_bg.x=x+SHIELD_X;@shield_bg.y=y+SHIELD_Y;end
      @base_x=x;@base_y=y
      true
    rescue => e
      BSS064.log("Boss HUD reposition warning: #{e.class}: #{e.message}")
      false
    end

    # SOS/DBK rebuilds databox objects when side size changes. Always recapture
    # the CURRENT databox, not only the object that existed when the Boss HUD was
    # created, otherwise the recreated boss databox becomes visible again.
    def capture_native_databox
      idx=(@battler.index rescue -1).to_i
      return if idx<0 || !@scene_sprites
      current=@scene_sprites["dataBox_#{idx}"]
      return if !current || (current.disposed? rescue true)
      replaced=!@native_box.equal?(current) rescue true
      if replaced
        @native_box=current
        @native_visible=(current.visible rescue true)
      end
      current.visible=false if current.respond_to?(:visible=)
      current
    rescue => e
      BSS064.log("Boss native databox capture warning: #{e.class}: #{e.message}")
      nil
    end

    def hide_native_databox
      current=capture_native_databox
      box=current || @native_box
      return if !box || (box.disposed? rescue true)
      box.visible=false if box.respond_to?(:visible=)
    rescue
    end

    def restore_native_databox
      # Restore only the live object currently registered by the scene.
      idx=(@battler.index rescue -1).to_i
      box=(@scene_sprites && idx>=0) ? @scene_sprites["dataBox_#{idx}"] : @native_box
      return if !box || (box.disposed? rescue true)
      box.visible=@native_visible != false if box.respond_to?(:visible=)
    rescue
    end

    def draw_label(name,level,title)
      return if !@text_bitmap
      label=""
      label << "#{title}: " if @cfg["showTitle"] != false && !title.to_s.empty?
      label << name.to_s
      label << "  Lv. #{level}" if @cfg["showLevel"] != false && level
      return if label==@last_label
      @last_label=label;@text_bitmap.clear
      begin
        @text_bitmap.font.size=20;@text_bitmap.font.bold=true
        @text_bitmap.font.color=Color.new(48,48,48,255)
        @text_bitmap.draw_text(1,1,WIDTH,28,label,1)
        @text_bitmap.font.color=Color.new(248,248,248,255)
        @text_bitmap.draw_text(0,0,WIDTH,28,label,1)
      rescue
        @text_bitmap.draw_text(0,0,WIDTH,28,label,1) rescue nil
      end
    end

    def update_hp(hp,total,force=false)
      return if !@hp || !@hp_bitmap
      hp=hp.to_f;total=[total.to_f,1.0].max;t=now
      if force || @display_hp.nil?
        @display_hp=hp;@last_target_hp=hp;@hp_anim_started=nil
      elsif @last_target_hp.nil? || hp!=@last_target_hp
        @hp_anim_from=@display_hp.to_f;@hp_anim_to=hp;@hp_anim_started=t
        @hp_hit_started=t if hp<@last_target_hp.to_f
        @last_target_hp=hp
      end
      if @hp_anim_started
        p=[[((t-@hp_anim_started)/0.36),0.0].max,1.0].min
        ease=1.0-(1.0-p)**3
        @display_hp=@hp_anim_from.to_f+(@hp_anim_to.to_f-@hp_anim_from.to_f)*ease
        if p>=1.0;@display_hp=@hp_anim_to.to_f;@hp_anim_started=nil;end
      else
        @display_hp=hp if @display_hp.nil?
      end
      ratio=[[@display_hp/total,0.0].max,1.0].min
      row=ratio>0.5 ? 0 : (ratio>0.2 ? 1 : 2)
      row_h=[@hp_bitmap.height/3,1].max
      width=[(@hp_bitmap.width*ratio).round,0].max
      @hp.src_rect.set(0,row*row_h,width,row_h)
      @hp.visible=width>0
      # Damage feedback must never move the HP fill independently from its
      # frame. Shield break already has its own animation; keep HP geometry fixed
      # and use only a short brightness flash here.
      @hp.x=@base_x+HP_X
      if @hp_hit_started
        p=(t-@hp_hit_started)/0.22
        if p<1.0
          begin;@hp.color=Color.new(255,255,255,((1.0-p)*115).round);rescue;end
        else
          @hp_hit_started=nil
          begin;@hp.color=Color.new(0,0,0,0);rescue;end
        end
      end
    rescue => e
      BSS064.log("Boss HUD HP warning: #{e.class}: #{e.message}")
    end

    def shield_center(maxseg)
      width=[[maxseg.to_i,1].max,8].min*SHIELD_SEGMENT_W
      [@base_x+SHIELD_X+SHIELD_OFFSET_X+(SHIELD_W/2-width/2),width]
    end

    def dispose_aux(list)
      list.each do |row|
        sp=row.is_a?(Hash) ? row[:sprite] : row
        begin;sp.dispose if sp && !sp.disposed?;rescue;end
        @sprites.delete(sp) rescue nil
      end
      list.clear
    rescue
    end

    def start_shield_spawn(seg,maxseg)
      dispose_aux(@shield_spawn_segments)
      return if !@shield_bitmap || seg.to_i<=0
      center,width=shield_center(maxseg)
      @shield_spawn_started=now
      seg.to_i.times do |i|
        sp=make_sprite(@shield_bitmap,5)
        next if !sp
        sp.src_rect.set(i*SHIELD_SEGMENT_W,SHIELD_H,SHIELD_SEGMENT_W,SHIELD_H)
        sp.ox=SHIELD_SEGMENT_W/2;sp.oy=SHIELD_H/2
        sp.x=center+i*SHIELD_SEGMENT_W+SHIELD_SEGMENT_W/2
        sp.y=@base_y+SHIELD_Y+SHIELD_OFFSET_Y+SHIELD_H/2
        sp.opacity=0;sp.zoom_x=3.0;sp.zoom_y=3.0
        begin;sp.color=Color.new(255,255,255,255);rescue;end
        @shield_spawn_segments << {:sprite=>sp,:index=>i}
      end
      begin;pbSEPlay("Vs sword");rescue;end
    rescue => e
      BSS064.log("Boss shield spawn warning: #{e.class}: #{e.message}")
    end

    def update_shield_spawn
      return false if !@shield_spawn_started
      t=now
      done=true
      @shield_spawn_segments.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        local=(t-@shield_spawn_started-row[:index].to_i*0.045)/0.22
        if local<=0
          sp.opacity=0;done=false;next
        end
        p=[[local,0.0].max,1.0].min;done=false if p<1.0
        ease=1.0-(1.0-p)**3
        sp.opacity=(255*ease).round
        z=3.0-2.0*ease;sp.zoom_x=z;sp.zoom_y=z
        begin;sp.color=Color.new(255,255,255,((1.0-ease)*220).round);rescue;end
      end
      if done
        dispose_aux(@shield_spawn_segments);@shield_spawn_started=nil
        return false
      end
      true
    rescue
      false
    end

    def spawn_shield_ghosts(before,after,maxseg)
      return if !@shield_bitmap || before.to_i<=after.to_i
      center,width=shield_center(maxseg)
      (after.to_i...before.to_i).each do |i|
        sp=make_sprite(@shield_bitmap,6);next if !sp
        sp.src_rect.set(i*SHIELD_SEGMENT_W,SHIELD_H,SHIELD_SEGMENT_W,SHIELD_H)
        sp.ox=SHIELD_SEGMENT_W/2;sp.oy=SHIELD_H/2
        sp.x=center+i*SHIELD_SEGMENT_W+SHIELD_SEGMENT_W/2
        sp.y=@base_y+SHIELD_Y+SHIELD_OFFSET_Y+SHIELD_H/2
        @shield_ghosts << {:sprite=>sp,:start=>now+(before.to_i-1-i)*0.045,:x=>sp.x.to_f,:y=>sp.y.to_f}
      end
    rescue => e
      BSS064.log("Boss shield ghost warning: #{e.class}: #{e.message}")
    end

    def update_shield_ghosts
      t=now
      @shield_ghosts.delete_if do |row|
        sp=row[:sprite]
        dead=!sp || (sp.disposed? rescue true)
        next true if dead
        p=(t-row[:start].to_f)/0.34
        if p<0
          false
        elsif p>=1.0
          begin;sp.dispose;rescue;end;@sprites.delete(sp) rescue nil;true
        else
          # Raid-reference feel: lift, then drop/darken/fade.
          lift=p<0.28 ? (-7.0*(p/0.28)) : (-7.0+17.0*((p-0.28)/0.72))
          sp.x=row[:x];sp.y=row[:y]+lift
          sp.opacity=(255*(1.0-p)).round
          z=1.0-0.25*p;sp.zoom_x=z;sp.zoom_y=z
          begin;sp.color=Color.new(0,0,0,(170*p).round);rescue;end
          false
        end
      end
    rescue
    end

    def start_shield_break
      return if @shield_break_started || @shield_break_done
      @shield_break_started=now;@shield_break_done=false
      se=(@cfg.is_a?(Hash) ? @cfg["shieldBreakSE"].to_s.strip : "")
      begin;pbSEPlay(se) if !se.empty?;rescue;end
    rescue
    end

    def apply_shield_break_visual
      return false if !@shield_break_started
      p=(now-@shield_break_started)/0.52
      p=[[p,0.0].max,1.0].min
      group=[@shield_bg,@shield_max,@shield_live].compact
      if p<0.52
        shake=(Math.sin(p*Math::PI*28.0)*2.5).round
        group.each { |sp| sp.x=(sp.equal?(@shield_bg) ? @base_x+SHIELD_X : shield_center(@last_shield_max||8)[0])+shake }
      else
        q=(p-0.52)/0.48
        group.each do |sp|
          sp.opacity=(255*(1.0-q)).round
          sp.zoom_x=1.0+3.0*q;sp.zoom_y=1.0
          begin;sp.color=Color.new(255,255,255,(210*q).round);rescue;end
        end
      end
      if p>=1.0
        group.each { |sp| sp.visible=false }
        @shield_break_started=nil;@shield_break_done=true
        return false
      end
      true
    rescue
      false
    end

    def update_shield(seg,maxseg)
      maxseg=[[maxseg.to_i,0].max,8].min;seg=[[seg.to_i,0].max,maxseg].min
      enabled=@cfg["shieldEnabled"]==true && maxseg>0
      group=[@shield_bg,@shield_max,@shield_live].compact
      if !enabled
        group.each { |sp| sp.visible=false }
        dispose_aux(@shield_spawn_segments);dispose_aux(@shield_ghosts)
        @last_shield_segments=seg;@last_shield_max=maxseg;return
      end
      center,width=shield_center(maxseg)
      if @shield_bg;@shield_bg.x=@base_x+SHIELD_X;@shield_bg.y=@base_y+SHIELD_Y;end
      if @shield_max
        @shield_max.x=center;@shield_max.y=@base_y+SHIELD_Y+SHIELD_OFFSET_Y
        @shield_max.src_rect.set(0,0,width,SHIELD_H)
      end
      if @shield_live
        @shield_live.x=center;@shield_live.y=@base_y+SHIELD_Y+SHIELD_OFFSET_Y
        @shield_live.src_rect.set(0,SHIELD_H,seg*SHIELD_SEGMENT_W,SHIELD_H)
      end
      group.each do |sp|
        sp.visible=true;sp.opacity=255;sp.zoom_x=1.0;sp.zoom_y=1.0
        begin;sp.color=Color.new(0,0,0,0);rescue;end
      end
      @shield_live.visible=seg>0 if @shield_live

      if seg>0;@shield_break_done=false;end
      if @last_shield_max.to_i<=0 && maxseg>0 && seg>0
        start_shield_spawn(seg,maxseg)
      elsif @last_shield_segments && seg<@last_shield_segments.to_i
        spawn_shield_ghosts(@last_shield_segments.to_i,seg,maxseg)
        start_shield_break if seg<=0
      end
      spawning=update_shield_spawn
      @shield_live.visible=false if spawning && @shield_live
      update_shield_ghosts
      breaking=apply_shield_break_visual
      if seg<=0 && @shield_break_done && !breaking
        group.each { |sp| sp.visible=false }
      end
      @last_shield_segments=seg;@last_shield_max=maxseg
    rescue => e
      BSS064.log("Boss HUD shield warning: #{e.class}: #{e.message}")
    end

    def draw_fallback(hp,total,name,level,title,seg,maxseg)
      bmp=@fallback_bitmap;return if !bmp
      bmp.clear
      label="#{(@cfg["showTitle"]!=false && !title.empty?) ? title+": " : ""}#{name}#{(@cfg["showLevel"]!=false && level) ? "  Lv. #{level}" : ""}"
      begin;bmp.font.size=18;bmp.font.bold=true;rescue;end
      bmp.draw_text(10,2,WIDTH-20,24,label,1)
      x=34;y=31;w=WIDTH-68;h=8;bmp.fill_rect(x,y,w,h,Color.new(24,20,30,240))
      fill=[(w*hp.to_f/[total.to_f,1.0].max).round,w].min;bmp.fill_rect(x,y,fill,h,Color.new(220,70,100,255)) if fill>0
      if maxseg.to_i>0
        count=[[maxseg.to_i,1].max,8].min;gap=3;sw=((w-gap*(count-1))/count.to_f).floor
        count.times { |i| bmp.fill_rect(x+i*(sw+gap),50,sw,6,i<seg.to_i ? Color.new(244,82,142,255) : Color.new(55,45,62,255)) }
      end
    rescue
    end

    def begin_faint
      @faint_started ||= now
    rescue
    end

    def apply_faint_animation
      return if !@faint_started
      p=(now-@faint_started)/0.62
      p=[[p,0.0].max,1.0].min
      # Brief hit shake, then slide/fade the full Boss HUD instead of popping it.
      shake=p<0.20 ? (Math.sin(p*Math::PI*30.0)*(1.0-p/0.20)*4.0).round : 0
      fade_p=p<0.22 ? 0.0 : [[(p-0.22)/0.78,0.0].max,1.0].min
      dy=(-12.0*fade_p).round;alpha=(255*(1.0-fade_p)).round
      positions={
        @frame=>[@base_x,@base_y],@text=>[@base_x,@base_y],
        @hp=>[@base_x+HP_X,@base_y+HP_Y],
        @shield_bg=>[@base_x+SHIELD_X,@base_y+SHIELD_Y]
      }
      if @shield_max || @shield_live
        center=shield_center(@last_shield_max.to_i>0 ? @last_shield_max : 1)[0]
        positions[@shield_max]=[center,@base_y+SHIELD_Y+SHIELD_OFFSET_Y] if @shield_max
        positions[@shield_live]=[center,@base_y+SHIELD_Y+SHIELD_OFFSET_Y] if @shield_live
      end
      positions.each do |sp,pos|
        next if !sp
        sp.opacity=[sp.opacity.to_i,alpha].min
        # Absolute coordinates prevent per-frame accumulation/drift.
        sp.x=pos[0].to_i+shake
        sp.y=pos[1].to_i+dy
        begin;sp.color=Color.new(255,255,255,(110*(1.0-fade_p)).round) if p<0.22;rescue;end
      end
      if @fallback;@fallback.opacity=alpha;@fallback.x=@base_x+shake;@fallback.y=@base_y+dy;end
      @faint_complete=true if p>=1.0
    rescue
    end

    def update(battler=nil,force=false)
      return if @disposed
      @battler=battler if battler
      b=@battler;return if !b
      hide_native_databox
      hp=(b.hp rescue 0).to_i;total=[(b.totalhp rescue 1).to_i,1].max
      seg=(@battle.respond_to?(:bss_boss_shield_segments) ? @battle.bss_boss_shield_segments.to_i : 0)
      maxseg=(@battle.respond_to?(:bss_boss_shield_max) ? @battle.bss_boss_shield_max.to_i : 0)
      real_name=(b.name rescue "Boss").to_s;custom=@cfg["displayName"].to_s.strip;name=(custom.empty? ? real_name : custom.gsub("{1}",real_name));level=(b.level rescue nil)
      title=@battle.respond_to?(:bss_boss_config) ? (@battle.bss_boss_config["title"] rescue "Boss").to_s : "Boss"
      begin_faint if hp<=0 || (b.fainted? rescue false)
      if @graphical
        reposition;reset_core_geometry;draw_label(name,level,title);update_hp(hp,total,force);update_shield(seg,maxseg)
        @frame.visible=true if @frame;@text.visible=true if @text
      else
        draw_fallback(hp,total,name,level,title,seg,maxseg)
        if @fallback;@fallback.x=@base_x;@fallback.y=@base_y;@fallback.opacity=255;@fallback.visible=true;end
      end
      apply_faint_animation if @faint_started
      apply_master_visibility
    rescue => e
      BSS064.log("Boss HUD update warning: #{e.class}: #{e.message}")
    end

    def dispose(restore_native=true)
      return if @disposed
      restore_native_databox if restore_native
      begin;@scene_sprites.delete(@key) if @scene_sprites;rescue;end
      @sprites.each { |sp| begin;sp.dispose if sp && !sp.disposed?;rescue;end }
      @owned_bitmaps.each { |bmp| begin;bmp.dispose if bmp && !bmp.disposed?;rescue;end }
      @sprites.clear;@owned_bitmaps.clear;@disposed=true
    rescue
      @disposed=true
    end
  end

  # Persistent bright contour.  Eight tinted copies of the live battler are
  # rendered just behind it.  They share the battler bitmap (never dispose it)
  # and mirror src_rect/origin/zoom/angle every frame, so forms, spritesheet
  # frames and BAS-authored transformations remain aligned.
  class BossAuraOutline
    def initialize(viewport,scene_sprites,cfg,key_prefix="bss_totem_outline")
      @viewport=viewport;@scene_sprites=scene_sprites.is_a?(Hash) ? scene_sprites : nil
      @cfg=cfg||{};@contours=[];@ghosts=[];@disposed=false;@rgb=BSS064.aura_color_rgb(@cfg["outlineColor"])
      r=BSS064.clamp_int(@cfg["outlineSize"],1,8,2)
      [[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]].each_with_index do |unit,i|
        sp=make_sprite("#{key_prefix}_edge_#{i}");@contours << [sp,"#{key_prefix}_edge_#{i}",unit,r]
      end
      count=BSS064.clamp_int(@cfg["outlineCopies"],1,12,6)
      count.times do |i|
        key="#{key_prefix}_ghost_#{i}";sp=make_sprite(key);@ghosts << [sp,key,i]
      end
    rescue => e
      BSS064.log("Boss outline create warning: #{e.class}: #{e.message}")
    end

    def make_sprite(key)
      sp=Sprite.new(@viewport);sp.visible=false;sp.opacity=0
      sp.blend_type=0 if sp.respond_to?(:blend_type=)
      sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
      @scene_sprites[key]=sp if @scene_sprites
      sp
    end

    def disposed?;@disposed;end

    def sync_from_target(sp,target,bmp,src)
      return if !sp || (sp.disposed? rescue true)
      sp.bitmap=bmp if !sp.bitmap.equal?(bmp)
      if src && sp.respond_to?(:src_rect) && sp.src_rect
        sp.src_rect.set(src.x,src.y,src.width,src.height)
      end
      sp.ox=(target.ox rescue 0);sp.oy=(target.oy rescue 0)
      sp.angle=(target.angle rescue 0) if sp.respond_to?(:angle=)
      sp.mirror=(target.mirror rescue false) if sp.respond_to?(:mirror=)
      # Keep the current RGSS color. Screen fades temporarily write to it via
      # pbSetSpritesToColor and restore it afterwards; resetting it here made
      # Roaring/Pulse outlines draw above black transitions.
      sp.blend_type=0 if sp.respond_to?(:blend_type=)
    rescue;end

    def gaussian(x,center,width)
      Math.exp(-(((x-center)/width)**2))
    rescue
      0.0
    end

    def update(target,battler,master_alpha=1.0,allow_fainted=false)
      return if @disposed
      bmp=target && target.respond_to?(:bitmap) ? target.bitmap : nil
      fainted=(battler.fainted? rescue false)
      visible=target && bmp && !(bmp.disposed? rescue true) && !(target.disposed? rescue true) && (!fainted || allow_fainted) && (allow_fainted || ((target.visible rescue true) && (target.opacity rescue 255).to_i>0))
      if !visible;hide_all;return;end
      src=(target.src_rect rescue nil);fade=[[master_alpha.to_f,0.0].max,1.0].min
      cfg_op=BSS064.clamp_float(@cfg["outlineOpacity"],0,100,46)/100.0;target_op=(target.opacity rescue 255).to_f
      effect=@cfg["outlineEffect"].to_s;effect="standard" if !["standard","roaring_knight","pulse"].include?(effect)
      base_op=[[(target_op*cfg_op*fade).round,0].max,255].min
      zbase_x=(target.zoom_x rescue 1.0).to_f;zbase_y=(target.zoom_y rescue 1.0).to_f;clock=BSS064.monotonic_seconds
      radius=BSS064.clamp_int(@cfg["outlineSize"],1,8,2).to_f
      roaring_strength=BSS064.clamp_float(@cfg["roaringStrength"],0,250,100)/100.0
      roaring_speed=BSS064.clamp_float(@cfg["roaringSpeed"],10,300,100)/100.0
      pulse_strength=BSS064.clamp_float(@cfg["pulseStrength"],0,250,100)/100.0
      pulse_speed=BSS064.clamp_float(@cfg["pulseSpeed"],10,300,100)/100.0
      spacing=BSS064.clamp_float(@cfg["outlineCopySpacing"],25,300,100)/100.0

      # The close 8-way contour always follows the live battler exactly. This is
      # separate from the Roaring/Pulse copies so the silhouette never becomes
      # the noisy multi-outline artifact of the old implementation.
      @contours.each_with_index do |row,i|
        sp,key,unit,r=row;next if !sp || (sp.disposed? rescue true);sync_from_target(sp,target,bmp,src)
        local_radius=radius
        if effect=="pulse"
          phase=(clock*1.90*pulse_speed)%1.0;beat=[gaussian(phase,0.10,0.10)+0.76*gaussian(phase,0.33,0.115),1.0].min
          pulse_body=0.10+0.90*beat
          local_radius=radius*(1.0+0.28*pulse_body*pulse_strength)
        end
        sp.zoom_x=zbase_x;sp.zoom_y=zbase_y;sp.x=(target.x rescue 0)+unit[0]*local_radius;sp.y=(target.y rescue 0)+unit[1]*local_radius
        sp.z=(target.z rescue 50)-1;sp.opacity=base_op;sp.visible=sp.opacity>1
      end

      @ghosts.each do |row|
        sp,key,i=row;next if !sp || (sp.disposed? rescue true);sync_from_target(sp,target,bmp,src)
        n=i+1;fall=[1.0-(i.to_f/[@ghosts.length,1].max.to_f),0.08].max
        if effect=="roaring_knight"
          # Reference-style displaced afterimages: a directional white/tinted
          # trail with staggered jitter, not a circular glow.
          phase=clock*9.0*roaring_speed+i*1.83
          dist=n*radius*2.55*spacing*roaring_strength
          dx=dist*(0.72+0.20*Math.sin(phase*0.53))
          dy=-dist*0.16+Math.sin(phase)*radius*1.85*roaring_strength
          zoom=1.0+n*0.010*roaring_strength
          sp.x=(target.x rescue 0)+dx;sp.y=(target.y rescue 0)+dy;sp.zoom_x=zbase_x*zoom;sp.zoom_y=zbase_y*zoom
          sp.z=(target.z rescue 50)-2-n;sp.opacity=[[base_op*fall*(0.22+0.28*(Math.sin(phase*0.71)*0.5+0.5))*[roaring_strength,0.15].max,205].min,0].max.to_i;sp.visible=sp.opacity>1
        elsif effect=="pulse"
          phase=(clock*1.90*pulse_speed-i*0.075*spacing)%1.0;phase+=1.0 if phase<0
          beat=[gaussian(phase,0.10,0.10)+0.76*gaussian(phase,0.33,0.115),1.0].min
          pulse_body=0.10+0.90*beat
          grow=1.0+n*0.024*spacing*pulse_strength*(0.48+pulse_body*1.38)
          sp.x=(target.x rescue 0);sp.y=(target.y rescue 0);sp.zoom_x=zbase_x*grow;sp.zoom_y=zbase_y*grow
          sp.z=(target.z rescue 50)-2-n;sp.opacity=[[base_op*fall*pulse_body*[pulse_strength,0.15].max,190].min,0].max.to_i;sp.visible=sp.opacity>1
        else
          sp.visible=false;sp.opacity=0
        end
      end
    rescue => e
      BSS064.log("Boss outline update warning: #{e.class}: #{e.message}");hide_all
    end

    def hide_all
      (@contours+@ghosts).each{|row|sp=row[0];sp.visible=false if sp && !(sp.disposed? rescue true);sp.opacity=0 if sp && !(sp.disposed? rescue true)}
    rescue;end

    def dispose
      return if @disposed
      (@contours+@ghosts).each do |row|
        sp=row[0];key=row[1]
        begin;@scene_sprites.delete(key) if @scene_sprites && @scene_sprites[key].equal?(sp);rescue;end
        begin;sp.bitmap=nil if sp && !(sp.disposed? rescue true);sp.dispose if sp && !sp.disposed?;rescue;end
      end
      @contours.clear;@ghosts.clear;@disposed=true
    rescue;@disposed=true;end
  end

  # Opening charge animation. This intentionally mirrors EBDX's broad rhythm:
  # converging sparks -> radial rays/ripples -> flash/impact -> persistent aura.
  class BossAuraIntro
    include BossAuraGeometry

    PRELUDE_FRAMES=16.0
    CANONICAL_CHARGE=104.0
    IMPACT_FRAMES=40.0

    def initialize(scene, target_sprite, battler, cfg, &activate_proc)
      @scene = scene
      @target = target_sprite
      @battler = battler
      @activate_proc = activate_proc
      @viewport = scene.instance_variable_get(:@viewport) rescue nil
      @scene_sprites = scene.instance_variable_get(:@sprites) rescue nil
      @scene_sprites = nil if !@scene_sprites.is_a?(Hash)
      @cfg = cfg || {}
      @rgb = BSS064.aura_color_rgb(@cfg["color"])
      @sprites = []
      @bitmaps = []
      @original_target_color = nil
      @hud_sprites = []
      @focus_sprites = []
      @charge_duration = BSS064.clamp_int(@cfg["introDuration"],48,180,104).to_f
      # The reference sequence is authored at a hard 40 FPS. The outer scene
      # loop now clocks these logical frames from monotonic real time, so this
      # object itself always advances in genuine EBDX frames.
      @fps_scale=1.0
      @hold_duration=BSS064.clamp_int(@cfg["impactHold"],0,120,56).to_f
      @total_logical=PRELUDE_FRAMES+@charge_duration+IMPACT_FRAMES+@hold_duration
      @total_duration=[@total_logical.round,1].max
      @activated=false;@sfx_start=false;@sfx_twine=false;@sfx_refresh=false;@sfx_impact=false;@cry_played=false
      create_assets
      capture_hud
      capture_stage_focus
    end

    attr_reader :total_duration

    def register(sp, key)
      @sprites << [sp,key]
      @scene_sprites[key] = sp if @scene_sprites
      sp
    end

    def bitmap(path)
      bmp = BSS064.new_bitmap(path)
      @bitmaps << bmp if bmp
      bmp
    end

    def create_assets
      @particle_bitmaps = BSS064::BOSS_INTRO_PARTICLES.map { |p| bitmap(p) }.compact
      @ray_bitmap = bitmap(BSS064::BOSS_AURA_RAY_GRAPHIC)
      @ripple_bitmap = bitmap(BSS064::BOSS_AURA_RIPPLE_GRAPHIC)
      @impact_bitmap = bitmap(BSS064::BOSS_AURA_IMPACT_GRAPHIC)
      @particles=[]; @rays=[]; @ripples=[]
      16.times do |i|
        sp=Sprite.new(@viewport); sp.bitmap=@particle_bitmaps[i % [@particle_bitmaps.length,1].max] if @particle_bitmaps.length>0
        if sp.bitmap;sp.ox=sp.bitmap.width/2;sp.oy=sp.bitmap.height/2;end
        sp.opacity=0;sp.visible=false
        register(sp,"bss_totem_intro_particle_#{i}")
        @particles << {:sprite=>sp,:spawned=>false,:nx=>0.5,:ny=>0.5}
      end
      angles=(0...8).map{|i|(360.0/8.0)*i+15.0}.sort_by{rand}
      8.times do |i|
        sp=Sprite.new(@viewport);sp.bitmap=@ray_bitmap if @ray_bitmap
        if sp.bitmap;sp.ox=0;sp.oy=sp.bitmap.height/2;end
        sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
        sp.opacity=0;sp.zoom_x=0;sp.zoom_y=0;sp.angle=angles[i]||((360.0/8.0)*i+15);sp.visible=false
        register(sp,"bss_totem_intro_ray_#{i}");@rays << sp
      end
      3.times do |i|
        sp=Sprite.new(@viewport);sp.bitmap=@ripple_bitmap if @ripple_bitmap
        if sp.bitmap;sp.ox=sp.bitmap.width/2;sp.oy=sp.bitmap.height/2;end
        sp.color=Color.new(@rgb[0],@rgb[1],@rgb[2],255) if sp.respond_to?(:color=)
        sp.opacity=0;sp.visible=false
        register(sp,"bss_totem_intro_ripple_#{i}");@ripples << {:sprite=>sp,:toggle=>1.0,:started=>false}
      end
      @impact=Sprite.new(@viewport);@impact.bitmap=@impact_bitmap if @impact_bitmap
      if @impact.bitmap
        @impact.ox=@impact.bitmap.width/2;@impact.oy=@impact.bitmap.height/2
        # TotemImpact is authored at 512x384. Fill the live game resolution
        # (640x480, 640x440, custom, etc.) instead of leaving a tiny center card.
        gw=(Graphics.width rescue 512).to_f;gh=(Graphics.height rescue 384).to_f
        @impact.zoom_x=gw/[@impact.bitmap.width.to_f,1.0].max
        @impact.zoom_y=gh/[@impact.bitmap.height.to_f,1.0].max
      end
      @impact.x=(Graphics.width rescue 512)/2;@impact.y=(Graphics.height rescue 384)/2;@impact.z=9999;@impact.opacity=0;@impact.visible=false
      register(@impact,"bss_totem_intro_impact")

      # Safe screen-space drama: these are sprites, never Viewport#color, so an
      # interrupted transition cannot strand the whole game on a black screen.
      @veil_bitmap=Bitmap.new(1,1);@veil_bitmap.fill_rect(0,0,1,1,Color.new(0,0,0,255));@bitmaps << @veil_bitmap
      @veil=Sprite.new(@viewport);@veil.bitmap=@veil_bitmap;@veil.x=0;@veil.y=0;@veil.z=1
      @veil.zoom_x=(Graphics.width rescue 512);@veil.zoom_y=(Graphics.height rescue 384);@veil.opacity=0;@veil.visible=true
      register(@veil,"bss_totem_intro_veil")
      @flash_bitmap=Bitmap.new(1,1);@flash_bitmap.fill_rect(0,0,1,1,Color.new(255,255,255,255));@bitmaps << @flash_bitmap
      @flash=Sprite.new(@viewport);@flash.bitmap=@flash_bitmap;@flash.x=0;@flash.y=0;@flash.z=10000
      @flash.zoom_x=(Graphics.width rescue 512);@flash.zoom_y=(Graphics.height rescue 384);@flash.opacity=0;@flash.visible=true
      register(@flash,"bss_totem_intro_flash")
      begin
        col=@target.color
        @original_target_color=Color.new(col.red,col.green,col.blue,col.alpha) if col
      rescue;@original_target_color=nil;end
    rescue => e
      BSS064.log("Boss intro create warning: #{e.class}: #{e.message}")
    end

    def capture_hud
      return if !@scene_sprites
      seen={}
      candidates=[]
      @scene_sprites.each { |key,sp| candidates << [key,sp] }
      # Some Essentials/LBDS message windows live as direct scene instance
      # variables instead of @sprites entries. Capture them too so text fades
      # with the rest of the HUD instead of remaining fully opaque.
      begin
        @scene.instance_variables.each do |ivar|
          sp=@scene.instance_variable_get(ivar)
          cls=(sp.class.to_s rescue "")
          candidates << [ivar,sp] if cls =~ /(Window|PokemonDataBox|CommandMenu|FightMenu)/i
        end
      rescue
      end
      candidates.each do |key,sp|
        next if !sp || (sp.disposed? rescue false)
        k=key.to_s
        cls=(sp.class.to_s rescue "")
        # Keep battlers, bases, shadows and aura effects in world space. Everything
        # that behaves like a databox/window/menu/message is captured as HUD.
        is_hud=(k =~ /(databox|bss_boss_hud|message|command|fight|target|party|help|text|window|info|ability|choice|menu|prompt)/i) || (cls =~ /(Window|PokemonDataBox|CommandMenu|FightMenu|BossHUD)/i)
        next if !is_hud
        oid=(sp.object_id rescue k)
        next if seen[oid];seen[oid]=true
        @hud_sprites << {
          :sprite=>sp,
          :visible=>(sp.visible rescue true),
          :opacity=>(sp.respond_to?(:opacity) ? (sp.opacity rescue 255) : nil),
          :contents_opacity=>(sp.respond_to?(:contents_opacity) ? (sp.contents_opacity rescue 255) : nil)
        }
      end
    rescue => e
      BSS064.log("Boss HUD capture warning: #{e.class}: #{e.message}")
    end

    def capture_stage_focus
      return if @cfg["introSpotlight"] == false || !@scene_sprites
      target_index=(@battler.index rescue -1).to_i
      seen={}
      @scene_sprites.each do |key,sp|
        next if !sp || (sp.disposed? rescue false)
        k=key.to_s
        m=k.match(/\A(?:pokemon|shadow)_(\d+)\z/i)
        next if !m
        next if m[1].to_i==target_index
        oid=(sp.object_id rescue k);next if seen[oid];seen[oid]=true
        @focus_sprites << {
          :sprite=>sp,
          :visible=>(sp.visible rescue true),
          :opacity=>(sp.respond_to?(:opacity) ? (sp.opacity rescue 255) : nil)
        }
      end
    rescue => e
      BSS064.log("Boss focus capture warning: #{e.class}: #{e.message}")
    end

    def update_focus_alpha(factor)
      return if @cfg["introSpotlight"] == false
      f=[[factor.to_f,0.0].max,1.0].min
      @focus_sprites.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=(row[:opacity].to_f*f).round if sp.respond_to?(:opacity=) && !row[:opacity].nil?
        sp.visible=(row[:visible] && f>0.005) if sp.respond_to?(:visible=)
      end
    rescue
    end

    def restore_stage_focus
      @focus_sprites.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=row[:opacity] if sp.respond_to?(:opacity=) && !row[:opacity].nil?
        sp.visible=row[:visible] if sp.respond_to?(:visible=)
      end
      @focus_sprites.clear
    rescue
    end

    def hud_smoothstep(x)
      x=[[x.to_f,0.0].max,1.0].min
      x*x*(3.0-2.0*x)
    end

    def update_hud_alpha(factor)
      f=[[factor.to_f,0.0].max,1.0].min
      @hud_sprites.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        if sp.respond_to?(:opacity=) && !row[:opacity].nil?
          sp.opacity=(row[:opacity].to_f*f).round
        end
        if sp.respond_to?(:contents_opacity=) && !row[:contents_opacity].nil?
          sp.contents_opacity=(row[:contents_opacity].to_f*f).round
        end
        sp.visible=(row[:visible] && f>0.005) if sp.respond_to?(:visible=)
      end
    rescue
    end

    def update_hud_for_frame(logical)
      fade_out=18.0
      fade_in=BSS064.clamp_int(@cfg["introReturnFrames"],8,60,24).to_f
      restore_at=[@total_logical-fade_in,fade_out].max
      factor=if logical<fade_out
               1.0-hud_smoothstep(logical/fade_out)
             elsif logical>=restore_at
               hud_smoothstep((logical-restore_at)/fade_in)
             else
               0.0
             end
      update_hud_alpha(factor)
      update_focus_alpha(factor)
    end

    def restore_databoxes
      @hud_sprites.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=row[:opacity] if sp.respond_to?(:opacity=) && !row[:opacity].nil?
        sp.contents_opacity=row[:contents_opacity] if sp.respond_to?(:contents_opacity=) && !row[:contents_opacity].nil?
        sp.visible=row[:visible] if sp.respond_to?(:visible=)
      end
      @hud_sprites.clear
    rescue
    end

    def fade_intro_transients(factor)
      f=[[factor.to_f,0.0].max,1.0].min
      @particles.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=[sp.opacity.to_i,(255*f).round].min
        sp.visible=sp.opacity>1
      end
      @rays.each do |sp|
        next if !sp || (sp.disposed? rescue true)
        sp.opacity=[sp.opacity.to_i,(255*f).round].min
        sp.visible=sp.opacity>1
      end
      @ripples.each do |row|
        sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
        sp.opacity=[sp.opacity.to_i,(255*f).round].min
        sp.visible=sp.opacity>1
      end
    rescue
    end

    def play_cry_once
      return if @cry_played;@cry_played=true
      pkmn=begin @battler.pokemon rescue nil end
      begin
        if pkmn && defined?(GameData::Species) && GameData::Species.respond_to?(:play_cry)
          GameData::Species.play_cry(pkmn.species,pkmn.form)
          return
        end
      rescue;end
      begin
        if @scene.respond_to?(:pbPlayCry)
          @scene.pbPlayCry(pkmn || @battler)
          return
        end
      rescue;end
    end

    def activate_persistent_once
      return if @activated;@activated=true
      begin;@activate_proc.call if @activate_proc;rescue => e;BSS064.log("Boss aura activate callback warning: #{e.class}: #{e.message}");end
      play_cry_once
    end

    def update(frame)
      state=target_state(@target);return if !state
      logical=frame.to_f
      update_hud_for_frame(logical)
      # EBDX deliberately waits before the flare.  This also gives BAS time to
      # settle into the Totem focus instead of snapping camera + particles at once.
      return if logical < PRELUDE_FRAMES
      charge=((logical-PRELUDE_FRAMES)*CANONICAL_CHARGE/[@charge_duration,0.0001].max)
      cx,cy=target_center(state)
      if @veil
        @veil.z=[state[:z]-20,1].max
      end
      if charge < CANONICAL_CHARGE
        if !@sfx_start;BSS064.play_aura_se("Anim/Harden",120);@sfx_start=true;end
        if !@sfx_twine && charge>=40;BSS064.play_aura_se("Anim/Twine",80);@sfx_twine=true;end
        if !@sfx_refresh && charge>=56;BSS064.play_aura_se("Anim/Refresh",100);@sfx_refresh=true;end
        if @target.respond_to?(:color=)
          alpha=[[charge*8.0,0].max,255].min.round
          @target.color=Color.new(@rgb[0],@rgb[1],@rgb[2],alpha)
        end
        # Pull the background back as the aura builds. This reproduces the
        # punch of EBDX's battlebg.defocus without depending on EBDX itself.
        @veil.opacity=[[charge*1.15,0].max,118].min.round if @veil
        @particles.each_with_index do |row,j|
          sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
          if charge>=j*8.0 && charge<76.0
            if sp.opacity<=0 && charge<72.0
              ang=rand*2*Math::PI;rad=0.35+rand*0.55
              row[:nx]=0.5+Math.cos(ang)*rad;row[:ny]=0.48+Math.sin(ang)*rad
              px,py=local_to_world(state,row[:nx],row[:ny],0);sp.x=px;sp.y=py
              sp.opacity=255;sp.visible=true
            end
            lerp=1.0-(0.9 ** (1.0/[ @fps_scale,0.0001].max))
            sp.x += (cx-sp.x)*lerp;sp.y += (cy-sp.y)*lerp
            sp.z=state[:z]+10;sp.zoom_x=[state[:zoom_x].abs,0.1].max;sp.zoom_y=[state[:zoom_y].abs,0.1].max
            sp.opacity=[sp.opacity-(16.0/[ @fps_scale,0.0001].max),0].max.round;sp.visible=sp.opacity>0
          else
            sp.opacity=[sp.opacity-(24.0/[ @fps_scale,0.0001].max),0].max.round;sp.visible=sp.opacity>0
          end
        end
        @rays.each_with_index do |sp,j|
          next if !sp || (sp.disposed? rescue true)
          if charge<96.0 && sp.opacity<=0 && j <= ((charge%128.0)/16.0).floor
            sp.opacity=255;sp.zoom_x=0;sp.zoom_y=0;sp.visible=true
          end
          sp.x=cx;sp.y=cy;sp.z=state[:z]+2
          sp.opacity=[sp.opacity-(4.0/[ @fps_scale,0.0001].max),0].max.round
          sp.zoom_x += 0.05/[ @fps_scale,0.0001].max;sp.zoom_y += 0.05/[ @fps_scale,0.0001].max
          sp.visible=sp.opacity>0
        end
        if charge>=24.0
          @ripples.each_with_index do |row,j|
            sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
            next if j > ((charge-32.0)/12.0).floor || sp.zoom_x<=0 && row[:started]
            if !row[:started]
              row[:started]=true;row[:toggle]=1.0;sp.opacity=0
              sp.zoom_x=2.0*[state[:zoom_x].abs,0.3].max;sp.zoom_y=2.0*[state[:zoom_y].abs,0.3].max;sp.visible=true
            end
            sp.x=cx;sp.y=cy;sp.z=state[:z]+1;sp.angle=state[:angle]
            step=1.0/[ @fps_scale,0.0001].max
            sp.opacity=[[sp.opacity+(16*row[:toggle]*step).round,0].max,255].min
            sp.zoom_x=[sp.zoom_x-0.05*step,0].max;sp.zoom_y=[sp.zoom_y-0.05*step,0].max
            row[:toggle]=-0.2 if sp.zoom_x < 1.6*[state[:zoom_x].abs,0.3].max
          end
        end
        return
      end

      # EBDX enables chargedUpdate before the impact, not after a dialogue box.
      activate_persistent_once
      impact=(logical-PRELUDE_FRAMES-@charge_duration)
      transient_fade=1.0-hud_smoothstep(impact/18.0)
      fade_intro_transients(transient_fade)
      if impact>=0 && impact<IMPACT_FRAMES && @impact
        if !@sfx_impact
          BSS064.play_aura_se("Anim/Refresh",120,90)
          @sfx_impact=true
        end
        @impact.visible=true
        # Full-screen flash replaces Viewport#color. It is equally strong but
        # cannot leak into the next screen if the sequence is interrupted.
        if @flash
          @flash.opacity=255 if impact<1.5
          @flash.opacity=[255-(impact*16.0),0].max.round if impact>=1.5
        end
        @veil.opacity=[118-(impact*4.0),0].max.round if @veil
        if @target.respond_to?(:color=)
          pulse=[220-(impact*14.0),0].max.round
          @target.color=Color.new(@rgb[0],@rgb[1],@rgb[2],pulse)
        end
        if impact<24
          @impact.opacity=[@impact.opacity+(64.0/[ @fps_scale,0.0001].max).round,255].min
          tick=impact.floor
          @impact.angle+=180 if tick%4==0 && @last_impact_turn!=tick
          @impact.mirror=!@impact.mirror if tick%4==2 && @impact.respond_to?(:mirror=) && @last_impact_mirror!=tick
          @last_impact_turn=tick if tick%4==0;@last_impact_mirror=tick if tick%4==2
        else
          @impact.opacity=[@impact.opacity-(64.0/[ @fps_scale,0.0001].max).round,0].max
        end
        return
      end
      # Hold on the fully charged Totem after the impact has cleared. The UI
      # stays hidden and BAS keeps the focus for most of this window, giving
      # the player time to actually read the powered-up silhouette/aura before
      # the camera returns and the aura message appears.
      fade_intro_transients(0.0)
      if @impact
        @impact.opacity=0;@impact.visible=false
      end
      @flash.opacity=0 if @flash
      @veil.opacity=0 if @veil
      if @target.respond_to?(:color=)
        @target.color=Color.new(@rgb[0],@rgb[1],@rgb[2],0)
      end
    rescue => e
      BSS064.log("Boss intro update warning: #{e.class}: #{e.message}")
    end

    def dispose
      restore_databoxes
      restore_stage_focus
      begin
        @target.color=@original_target_color if @original_target_color && @target && !(@target.disposed? rescue false) && @target.respond_to?(:color=)
      rescue;end
      @sprites.each do |sp,key|
        begin;@scene_sprites.delete(key) if @scene_sprites && @scene_sprites[key].equal?(sp);rescue;end
        begin;sp.dispose if sp && !sp.disposed?;rescue;end
      end
      @sprites.clear
      @bitmaps.each{|bmp|begin;bmp.dispose if bmp && !bmp.disposed?;rescue;end};@bitmaps.clear
    rescue;end
  end
end

# BAS only transforms known battle-world sprite keys. BSS aura/intro sprites are
# in the same world and must receive the exact camera transform as their Totem.
module BSS064BASWorldSpriteCompat
  def ui_sprite_key?(key)
    return true if key.to_s=="bss_boss_hud"
    super
  end

  def camera_world_sprite_key?(key)
    k=key.to_s
    return false if k=="bss_boss_hud"
    # Full-screen impact/flash/veil are HUD/screen-space effects. Letting BAS
    # transform them as world sprites is exactly what made TotemImpact look
    # small while the camera was zoomed.
    return false if k.start_with?("bss_totem_intro_impact") || k.start_with?("bss_totem_intro_flash") || k.start_with?("bss_totem_intro_veil")
    return true if k.start_with?("bss_totem_")
    super
  end
end

class Battle
  attr_accessor :bss_boss_config
  attr_accessor :bss_boss_applied
  attr_accessor :bss_boss_intro_pending
  attr_accessor :bss_boss_intro_shown
  attr_accessor :bss_boss_aura_active
  attr_accessor :bss_boss_shield_segments
  attr_accessor :bss_boss_shield_max
  attr_accessor :bss_boss_shield_started
  attr_accessor :bss_boss_shield_broken

  def bss_boss_hud_config
    raw=@bss_boss_config.is_a?(Hash) && @bss_boss_config["hud"].is_a?(Hash) ? @bss_boss_config["hud"] : {}
    boss_active=(@bss_boss_config.is_a?(Hash) && @bss_boss_config["enabled"]==true)
    {
      "enabled"=>boss_active && raw["enabled"]!=false,"position"=>(["top","databox"].include?(raw["position"].to_s) ? raw["position"].to_s : "top"),
      "showTitle"=>raw["showTitle"]!=false,"showLevel"=>raw["showLevel"]!=false,"displayName"=>raw["displayName"].to_s,
      "shieldEnabled"=>raw["shieldEnabled"]==true,"shieldSegments"=>BSS064.clamp_int(raw["shieldSegments"],1,24,5),
      "shieldStartMode"=>(raw["shieldStartMode"].to_s=="hp_threshold" ? "hp_threshold" : "battle_start"),
      "shieldTriggerPercent"=>BSS064.clamp_float(raw["shieldTriggerPercent"],1,100,50),
      "shieldDamagePercent"=>BSS064.clamp_float(raw["shieldDamagePercent"],1,100,5),
      "shieldBreakDamagePercent"=>BSS064.clamp_float(raw["shieldBreakDamagePercent"],0,100,12.5),
      "shieldBreakSE"=>raw["shieldBreakSE"].to_s,
      "shieldMessage"=>(raw["shieldMessage"].to_s.empty? ? "¡Una barrera misteriosa protege a {1}!" : raw["shieldMessage"].to_s),
      "shieldBreakMessage"=>(raw["shieldBreakMessage"].to_s.empty? ? "¡La barrera de {1} se ha roto!" : raw["shieldBreakMessage"].to_s)
    }
  rescue;{};end

  def bss_boss_residual_config
    raw=@bss_boss_config.is_a?(Hash) && @bss_boss_config["mechanics"].is_a?(Hash) && @bss_boss_config["mechanics"]["residual"].is_a?(Hash) ? @bss_boss_config["mechanics"]["residual"] : {}
    {
      "enabled"=>raw["enabled"]==true,
      "trappingPercent"=>BSS064.clamp_float(raw["trappingPercent"],0,100,50),
      "moveEffectPercent"=>BSS064.clamp_float(raw["moveEffectPercent"],0,100,50),
      "statusPercent"=>BSS064.clamp_float(raw["statusPercent"],0,100,50),
      "weatherPercent"=>BSS064.clamp_float(raw["weatherPercent"],0,100,50)
    }
  rescue
    {"enabled"=>false}
  end

  def bss_with_boss_residual_context(kind)
    @bss_boss_residual_context_stack ||= []
    @bss_boss_residual_context_stack << kind
    yield
  ensure
    @bss_boss_residual_context_stack.pop if @bss_boss_residual_context_stack && !@bss_boss_residual_context_stack.empty?
  end

  def bss_boss_residual_context
    @bss_boss_residual_context_stack && @bss_boss_residual_context_stack[-1]
  rescue
    nil
  end

  def bss_with_boss_direct_damage_context(target)
    @bss_boss_direct_damage_stack ||= []
    @bss_boss_direct_damage_stack << target
    yield
  ensure
    @bss_boss_direct_damage_stack.pop if @bss_boss_direct_damage_stack && !@bss_boss_direct_damage_stack.empty?
  end

  def bss_boss_direct_damage_target
    @bss_boss_direct_damage_stack && @bss_boss_direct_damage_stack[-1]
  rescue
    nil
  end

  def bss_boss_attribute_config
    raw=@bss_boss_config.is_a?(Hash) ? @bss_boss_config["attributes"] : nil
    raw=@bss_boss_config["dbk"] if !raw.is_a?(Hash) && @bss_boss_config.is_a?(Hash) # old JSON migration
    raw={} if !raw.is_a?(Hash)
    {"enabled"=>raw["enabled"]==true,"hpMultiplier"=>[raw.key?("hpMultiplier") ? raw["hpMultiplier"].to_i : raw["hpLevel"].to_i,1].max,"immunities"=>(raw["immunities"].is_a?(Array) ? raw["immunities"].map{|x|x.to_s.upcase}.uniq : [])}
  rescue
    {"enabled"=>false,"hpMultiplier"=>1,"immunities"=>[]}
  end

  def bss_native_boss_immunity?(battler,*ids)
    cfg=bss_boss_attribute_config
    boss=bss_find_boss_battler_any rescue nil;boss ||= bss_find_boss_battler rescue nil
    return false if !boss || !battler || !boss.equal?(battler)
    # Immunities are independent from the HP-multiplier master switch.
    vals=cfg["immunities"];ids.flatten.any?{|id| vals.include?(id.to_s.upcase)}
  rescue
    false
  end

  def bss_boss_residual_multiplier_for(battler)
    cfg=bss_boss_residual_config
    return 1.0 if cfg["enabled"]!=true
    boss=bss_find_boss_battler_any rescue nil
    boss ||= bss_find_boss_battler rescue nil
    return 1.0 if !boss || !battler || !boss.equal?(battler)
    key=case bss_boss_residual_context
        when :trapping then "trappingPercent"
        when :move_effect then "moveEffectPercent"
        when :status then "statusPercent"
        when :weather then "weatherPercent"
        else nil
        end
    return 1.0 if !key
    BSS064.clamp_float(cfg[key],0,100,100)/100.0
  rescue
    1.0
  end

  def bss_boss_shield_active?(battler=nil)
    return false if !bss_boss_enabled? || @bss_boss_shield_segments.to_i<=0
    target=bss_find_boss_battler rescue nil
    return false if battler && target && !battler.equal?(target)
    !!target
  rescue;false;end

  def bss_try_start_boss_shield(battler=nil,force=false)
    return false if !bss_boss_enabled? || @bss_boss_shield_started || @bss_boss_shield_broken
    cfg=bss_boss_hud_config;return false if !cfg["shieldEnabled"]
    boss=bss_find_boss_battler rescue nil
    return false if !boss || (boss.fainted? rescue false)
    # Never let HP loss on the player's battler (Explosion/Self-Destruct) or an
    # SOS ally initialize/mutate the boss shield.
    return false if battler && !battler.equal?(boss)
    mode=cfg["shieldStartMode"].to_s
    if !force && mode=="hp_threshold"
      total=[(boss.totalhp rescue 1).to_f,1.0].max;ratio=(boss.hp rescue total).to_f*100.0/total
      return false if ratio>cfg["shieldTriggerPercent"].to_f
    end
    @bss_boss_shield_started=true;@bss_boss_shield_max=cfg["shieldSegments"].to_i;@bss_boss_shield_segments=@bss_boss_shield_max
    msg=bss_boss_message(cfg["shieldMessage"],boss);pbDisplay(msg) if !msg.empty? && respond_to?(:pbDisplay)
    @scene.bss_update_boss_hud(false) if @scene && @scene.respond_to?(:bss_update_boss_hud)
    true
  rescue => e;BSS064.log("Boss shield start warning: #{e.class}: #{e.message}");false;end

  def bss_damage_boss_shield(battler,count=1)
    return false if !bss_boss_shield_active?(battler)
    before=@bss_boss_shield_segments.to_i;@bss_boss_shield_segments=[before-[count.to_i,1].max,0].max
    if @bss_boss_shield_segments<=0
      @bss_boss_shield_broken=true;cfg=bss_boss_hud_config
      msg=bss_boss_message(cfg["shieldBreakMessage"],battler);pbDisplay(msg) if !msg.empty? && respond_to?(:pbDisplay)
      pct=cfg["shieldBreakDamagePercent"].to_f
      if pct>0 && battler && !(battler.fainted? rescue true)
        old=(battler.hp rescue 1).to_i;extra=[((battler.totalhp rescue old).to_f*pct/100.0).round,1].max;newhp=[old-extra,1].max
        battler.instance_variable_set(:@hp,newhp)
        begin;@scene.pbHPChanged(battler,old) if @scene && @scene.respond_to?(:pbHPChanged);rescue;end
      end
    end
    @scene.bss_update_boss_hud(false) if @scene && @scene.respond_to?(:bss_update_boss_hud)
    before!=@bss_boss_shield_segments.to_i
  rescue => e;BSS064.log("Boss shield damage warning: #{e.class}: #{e.message}");false;end

  def bss_boss_enabled?
    @bss_boss_config.is_a?(Hash) && @bss_boss_config["enabled"] == true
  end

  def bss_boss_target_party_index
    cfg=@bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    [cfg["foeIndex"].to_i,0].max
  end

  def bss_boss_has_stat_aura?
    return false if !bss_boss_enabled?
    cfg=@bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    aura=BSS064.boss_aura_config(cfg)
    return false if !aura["enabled"]
    stats=cfg["stats"].is_a?(Hash) ? cfg["stats"] : {}
    ["ATTACK","DEFENSE","SPECIAL_ATTACK","SPECIAL_DEFENSE","SPEED","ACCURACY","EVASION"].any? { |stat| stats[stat].to_i != 0 }
  rescue
    false
  end

  def bss_find_boss_battler
    return nil if !bss_boss_enabled?
    wanted=bss_boss_target_party_index
    rows=@battlers.is_a?(Array) ? @battlers : []
    rows.compact.find do |b|
      next false if !b || (b.fainted? rescue false)
      idx=(b.index rescue -1).to_i
      next false if idx<0 || idx.even?
      (b.pokemonIndex rescue 0).to_i==wanted
    end
  rescue
    nil
  end

  # Same lookup but keeps the fainted boss addressable while its faint animation
  # is running. The HUD uses this to hide/dispose itself instead of becoming an
  # orphaned overlay after bss_find_boss_battler starts returning nil.
  def bss_find_boss_battler_any
    return nil if !bss_boss_enabled?
    wanted=bss_boss_target_party_index
    rows=@battlers.is_a?(Array) ? @battlers : []
    rows.compact.find do |b|
      idx=(b.index rescue -1).to_i
      next false if idx<0 || idx.even?
      (b.pokemonIndex rescue 0).to_i==wanted
    end
  rescue
    nil
  end

  def bss_boss_name_for_intro
    begin
      party=pbParty(1);idx=bss_boss_target_party_index;pkmn=party[idx]||party[0]
      return pkmn.name.to_s if pkmn
    rescue
    end
    battler=bss_find_boss_battler
    return battler.name.to_s if battler && battler.respond_to?(:name)
    "Pokémon"
  end

  def bss_boss_message(template,battler=nil)
    text=template.to_s
    return "" if text.empty?
    # {1} is intentionally the raw Pokémon nickname/species display name only.
    # Articles/roles such as "salvaje", "rival" or "dominante" belong to the
    # editable template, never to pbThis (which can inject battle grammar).
    name=if battler
      begin battler.name.to_s rescue bss_boss_name_for_intro end
    else
      bss_boss_name_for_intro
    end
    text.gsub("{1}",name.to_s)
  end

  def bss_default_aura_message
    role=(trainerBattle? rescue false) ? "rival" : "salvaje"
    "¡El {1} #{role} está rodeado por un aura!"
  rescue
    "¡El {1} salvaje está rodeado por un aura!"
  end

  def bss_boss_encounter_message
    return "" if !bss_boss_enabled?
    cfg=@bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    bss_boss_message(cfg["encounterMessage"],nil)
  end

  def bss_apply_boss_stat_stage(battler,stat,delta)
    amount=[[delta.to_i,-6].max,6].min
    return if amount==0 || !battler
    stages=battler.respond_to?(:stages) ? battler.stages : nil
    return if !stages || !stages.respond_to?(:[]) || !stages.respond_to?(:[]=)
    key=stat.to_s.upcase.to_sym
    stages[key]=[[stages[key].to_i+amount,-6].max,6].min
  rescue => e
    BSS064.log("Boss stat #{stat} failed: #{e.class}: #{e.message}")
  end

  def bss_apply_boss_opening
    return if @bss_boss_applied || !bss_boss_enabled?
    battler=bss_find_boss_battler
    return if !battler
    begin; @scene.bss_capture_boss_native_scale(battler,true) if @scene && @scene.respond_to?(:bss_capture_boss_native_scale); rescue; end
    cfg=@bss_boss_config
    hud_cfg=bss_boss_hud_config rescue {}
    shield_at_start=hud_cfg.is_a?(Hash) && hud_cfg["shieldEnabled"] && hud_cfg["shieldStartMode"].to_s=="battle_start"
    intro_order=(cfg["introOrder"].to_s=="aura_first" ? "aura_first" : "shield_first")
    begin
      bss_try_start_boss_shield(battler,true) if shield_at_start && intro_order=="shield_first"
    rescue => e
      BSS064.log("Boss opening shield warning: #{e.class}: #{e.message}")
    end
    begin; @scene.bss_update_boss_hud(true) if @scene && @scene.respond_to?(:bss_update_boss_hud); rescue; end
    if !@bss_boss_intro_shown
      intro=bss_boss_encounter_message
      if !intro.empty? && respond_to?(:pbDisplay)
        pbDisplay(intro);@bss_boss_intro_shown=true
      end
    end
    stats=cfg["stats"].is_a?(Hash) ? cfg["stats"] : {}
    ["ATTACK","DEFENSE","SPECIAL_ATTACK","SPECIAL_DEFENSE","SPEED","ACCURACY","EVASION"].each { |stat| bss_apply_boss_stat_stage(battler,stat,stats[stat]) }
    has_boost=["ATTACK","DEFENSE","SPECIAL_ATTACK","SPECIAL_DEFENSE","SPEED","ACCURACY","EVASION"].any? { |stat| stats[stat].to_i!=0 }
    aura_cfg=BSS064.boss_aura_config(cfg)
    if has_boost && aura_cfg["enabled"]
      if aura_cfg["introEnabled"] && @scene && @scene.respond_to?(:bss_play_boss_aura_sequence)
        @scene.bss_play_boss_aura_sequence(battler,cfg)
      else
        @bss_boss_aura_active=true
        @scene.bss_update_boss_aura if @scene && @scene.respond_to?(:bss_update_boss_aura)
      end
    end
    # The charged aura/outline is already visible when this line is shown.
    aura_template=cfg["auraMessage"].to_s
    aura_template=bss_default_aura_message if aura_template.strip.empty?
    message=bss_boss_message(aura_template,battler)
    pbDisplay(message) if has_boost && !message.empty? && respond_to?(:pbDisplay)
    if shield_at_start && intro_order=="aura_first"
      begin;bss_try_start_boss_shield(battler,true);rescue => e;BSS064.log("Boss post-aura shield warning: #{e.class}: #{e.message}");end
    end
    @bss_boss_applied=true
    @scene.bss_update_boss_aura if @scene && @scene.respond_to?(:bss_update_boss_aura)
  rescue => e
    BSS064.log("Boss opening failed: #{e.class}: #{e.message}")
    @bss_boss_applied=true
  end

end

#===============================================================================
# BSS v0.6.64 - reload-safe battle opening hooks.
#===============================================================================
# Older builds wrapped these entry points with aliases stored directly on Battle.
# In mkxp-z/F12 development sessions those aliases can outlive a script reload and
# keep pointing at a stale DBK/LBDS method chain. The visible symptom is exactly a
# battleback/trainer appearing for a moment and pbStartBattle aborting before the
# battlers finish their send-out. Use one prepend layer instead: re-evaluating the
# plugin updates the same module while `super` always resolves to the CURRENT
# Essentials/DBK implementation loaded in this reset.
module BSS064BossOpeningReloadSafe663
  def bss669_apply_boss_databox_title
    battle=self
    cfg=respond_to?(:bss_boss_config) ? bss_boss_config : nil
    return false if !cfg.is_a?(Hash)
    hud=cfg["hud"].is_a?(Hash) ? cfg["hud"] : {}
    selected=hud["databoxStyle"].to_s.downcase
    return false if !%w[basic long].include?(selected)
    boss=(bss_find_boss_battler_any rescue nil) if respond_to?(:bss_find_boss_battler_any)
    boss ||= (bss_find_boss_battler rescue nil) if respond_to?(:bss_find_boss_battler)
    return false if !boss
    scene=@scene rescue nil
    sprites=scene ? (scene.instance_variable_get(:@sprites) rescue nil) : nil
    return false if !sprites.is_a?(Hash)
    text=hud["databoxTitle"].to_s
    # Clear any stale helper title first, then assign the title to the actual Boss
    # slot. This is post-construction, so it cannot participate in DBK's alias
    # chain.
    sprites.each do |key,box|
      next if !key.to_s.start_with?("dataBox_") || !box
      begin
        idx=key.to_s.sub("dataBox_","").to_i
        battler=(respond_to?(:battlers) && battlers.is_a?(Array)) ? battlers[idx] : nil
        wanted=(battler && battler.equal?(boss) && !text.strip.empty?) ? text : nil
        old=box.instance_variable_get(:@title) rescue nil
        if old!=wanted
          box.instance_variable_set(:@title,wanted)
          box.refresh if box.respond_to?(:refresh)
        end
      rescue
      end
    end
    true
  rescue => e
    BSS064.log("Boss DBK databox title post-apply 0.6.69 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  def pbStartBattleSendOut(*args,&block)
    begin
      @bss_boss_intro_pending=respond_to?(:bss_boss_enabled?) && bss_boss_enabled? &&
                              respond_to?(:bss_boss_encounter_message) && !bss_boss_encounter_message.to_s.empty?
    rescue
      @bss_boss_intro_pending=false
    end
    super
  ensure
    @bss_boss_intro_pending=false
  end

  def pbDisplayPaused(msg,&block)
    if @bss_boss_intro_pending
      begin
        custom=respond_to?(:bss_boss_encounter_message) ? bss_boss_encounter_message.to_s : ""
        if !custom.empty?
          @bss_boss_intro_pending=false
          @bss_boss_intro_shown=true
          return super(custom,&block)
        end
      rescue => e
        BSS064.log("Boss intro message 0.6.64 warning: #{e.class}: #{e.message}") if defined?(BSS064)
      end
    end
    super
  end

  def pbCommandPhase(*args,&block)
    begin
      bss_apply_boss_opening if respond_to?(:bss_apply_boss_opening)
    rescue => e
      BSS064.log("Boss opening command hook 0.6.64 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    super
  end
end
begin
  if defined?(Battle) && !Battle.ancestors.include?(BSS064BossOpeningReloadSafe663)
    Battle.prepend(BSS064BossOpeningReloadSafe663)
  end
rescue => e
  BSS064.log("Boss reload-safe opening install 0.6.64 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

class Battle::Scene
  def bss_scene_sprites
    @sprites.is_a?(Hash) ? @sprites : {}
  rescue
    {}
  end

  def bss_boss_target_sprite(battler)
    return nil if !battler
    idx=(battler.index rescue -1).to_i
    return nil if idx<0
    bss_scene_sprites["pokemon_#{idx}"]
  rescue
    nil
  end

  def bss_dispose_boss_aura
    emitter=@bss_boss_aura_emitter;outline=@bss_boss_aura_outline
    emitter.dispose if emitter && emitter.respond_to?(:dispose)
    outline.dispose if outline && outline.respond_to?(:dispose)
    @bss_boss_aura_emitter=nil;@bss_boss_aura_outline=nil;@bss_boss_aura_index=nil
    @bss_boss_aura_battler=nil;@bss_boss_aura_fade_started=nil
  rescue
    @bss_boss_aura_emitter=nil;@bss_boss_aura_outline=nil;@bss_boss_aura_index=nil
    @bss_boss_aura_battler=nil;@bss_boss_aura_fade_started=nil
  end

  def bss_dispose_boss_hud(restore_native=true)
    hud=@bss_boss_hud
    hud.dispose(restore_native) if hud && hud.respond_to?(:dispose)
    @bss_boss_hud=nil;@bss_boss_hud_index=nil
  rescue
    @bss_boss_hud=nil;@bss_boss_hud_index=nil
  end

  def bss_update_boss_hud(force=false)
    battle=@battle
    if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled?
      bss_dispose_boss_hud(true) if @bss_boss_hud;return
    end
    cfg=battle.respond_to?(:bss_boss_hud_config) ? battle.bss_boss_hud_config : {}
    if cfg["enabled"]==false
      bss_dispose_boss_hud(true) if @bss_boss_hud;return
    end
    battler=(battle.respond_to?(:bss_find_boss_battler_any) ? battle.bss_find_boss_battler_any : (battle.bss_find_boss_battler rescue nil))
    if !battler
      # If the battler disappeared after fainting, let an already-created HUD
      # finish its exit rather than snapping it off in one frame.
      if @bss_boss_hud && @bss_boss_hud.respond_to?(:fainting?) && @bss_boss_hud.fainting?
        @bss_boss_hud.update(nil,false)
        bss_dispose_boss_hud(false) if @bss_boss_hud.faint_complete?
      else
        bss_dispose_boss_hud(false) if @bss_boss_hud
      end
      return
    end
    idx=(battler.index rescue -1).to_i
    if !@bss_boss_hud || (@bss_boss_hud.disposed? rescue true) || @bss_boss_hud_index!=idx
      bss_dispose_boss_hud(true)
      @bss_boss_hud=BSS064::BossHUD.new(@viewport,bss_scene_sprites,battle,battler,cfg)
      @bss_boss_hud_index=idx;force=true
    end
    @bss_boss_hud.update(battler,force) if @bss_boss_hud
    if ((battler.fainted? rescue false) || (battler.hp rescue 0).to_i<=0) && @bss_boss_hud
      @bss_boss_hud.hide_native_databox if @bss_boss_hud.respond_to?(:hide_native_databox)
      bss_dispose_boss_hud(false) if @bss_boss_hud.respond_to?(:faint_complete?) && @bss_boss_hud.faint_complete?
    end
  rescue => e
    BSS064.log("Boss HUD scene warning: #{e.class}: #{e.message}")
  end

  def bss_boss_frame_dimensions(sprite)
    return [0.0,0.0] if !sprite || (sprite.disposed? rescue true)
    bmp=(sprite.bitmap rescue nil);src=(sprite.src_rect rescue nil)
    w=(src && src.width.to_i>0) ? src.width.to_f : (bmp && !(bmp.disposed? rescue true) ? bmp.width.to_f : 0.0)
    h=(src && src.height.to_i>0) ? src.height.to_f : (bmp && !(bmp.disposed? rescue true) ? bmp.height.to_f : 0.0)
    [w,h]
  rescue
    [0.0,0.0]
  end

  def bss_capture_boss_native_scale(battler=nil,force=false)
    battle=@battle
    battler ||= (battle.bss_find_boss_battler rescue nil) if battle
    return nil if !battler
    sprite=bss_boss_target_sprite(battler);return nil if !sprite || (sprite.disposed? rescue true)
    @bss_boss_native_scale ||= {};@bss_boss_native_renderer ||= {}
    idx=(battler.index rescue 1).to_i
    current=[(sprite.zoom_x rescue 1.0).to_f,(sprite.zoom_y rescue 1.0).to_f]
    bmp=(sprite.bitmap rescue nil);src=(sprite.src_rect rescue nil);fw,fh=bss_boss_frame_dimensions(sprite)
    renderer={
      :width=>(bmp && !(bmp.disposed? rescue true) ? bmp.width.to_i : 0),
      :height=>(bmp && !(bmp.disposed? rescue true) ? bmp.height.to_i : 0),
      :src_w=>(src ? src.width.to_i : 0),:src_h=>(src ? src.height.to_i : 0),
      :frame_w=>fw,:frame_h=>fh,
      # Store what the player actually sees, not only zoom. LBDS/Animated DBK
      # can bake a multiplier into the bitmap/src_rect during SOS/BAS.
      :display_w=>fw*current[0].abs,:display_h=>fh*current[1].abs,
      :x=>(sprite.x rescue 0).to_f,:y=>(sprite.y rescue 0).to_f,:z=>(sprite.z rescue 50).to_i,
      :back=>((battler.index.to_i.even?) rescue false)
    }
    return @bss_boss_native_scale[idx] if !force && @bss_boss_native_scale[idx]
    if current[0]!=0 && current[1]!=0 && fw>0 && fh>0
      @bss_boss_native_scale[idx]=current;@bss_boss_native_renderer[idx]=renderer
    end
    @bss_boss_native_scale[idx]
  rescue => e
    BSS064.log("Boss native scale capture warning: #{e.class}: #{e.message}");nil
  end

  def bss_boss_renderer_profile_mismatch?(sprite,idx)
    info=@bss_boss_native_renderer && @bss_boss_native_renderer[idx]
    return false if !info || !sprite || (sprite.disposed? rescue true)
    bmp=(sprite.bitmap rescue nil);return false if !bmp || (bmp.disposed? rescue true)
    src=(sprite.src_rect rescue nil);w=bmp.width.to_i;h=bmp.height.to_i;sw=src ? src.width.to_i : 0;sh=src ? src.height.to_i : 0
    return true if info[:width].to_i>0 && (w-info[:width].to_i).abs>1
    return true if info[:height].to_i>0 && (h-info[:height].to_i).abs>1
    return true if info[:src_w].to_i>0 && sw>0 && (sw-info[:src_w].to_i).abs>1
    return true if info[:src_h].to_i>0 && sh>0 && (sh-info[:src_h].to_i).abs>1
    false
  rescue
    false
  end

  def bss_apply_boss_display_size(sprite,idx)
    info=@bss_boss_native_renderer && @bss_boss_native_renderer[idx]
    base=@bss_boss_native_scale && @bss_boss_native_scale[idx]
    return false if !sprite || !info || !base
    fw,fh=bss_boss_frame_dimensions(sprite);return false if fw<=0 || fh<=0
    want_w=info[:display_w].to_f;want_h=info[:display_h].to_f
    return false if want_w<=0 || want_h<=0
    sx=base[0].to_f<0 ? -1.0 : 1.0;sy=base[1].to_f<0 ? -1.0 : 1.0
    sprite.zoom_x=sx*(want_w/fw) if sprite.respond_to?(:zoom_x=)
    sprite.zoom_y=sy*(want_h/fh) if sprite.respond_to?(:zoom_y=)
    true
  rescue => e
    BSS064.log("Boss display-size restore warning: #{e.class}: #{e.message}");false
  end

  # Reassert the physical on-screen size of the Totem. This is intentionally
  # callable by SOS because that flow can rebuild every battler renderer without
  # going through Scene#pbAnimation.
  def bss_reassert_boss_visual_scale(battler=nil,rebuild=true)
    battle=@battle;battler ||= (battle.bss_find_boss_battler rescue nil) if battle
    return false if !battler || (battler.fainted? rescue false)
    idx=(battler.index rescue -1).to_i;return false if idx<0
    bss_capture_boss_native_scale(battler,false)
    sprite=bss_boss_target_sprite(battler);return false if !sprite || (sprite.disposed? rescue true)
    if rebuild && bss_boss_renderer_profile_mismatch?(sprite,idx)
      bss_restore_boss_natural_renderer(battler,nil,true)
      sprite=bss_boss_target_sprite(battler) rescue sprite
    end
    bss_apply_boss_display_size(sprite,idx)
  rescue => e
    BSS064.log("Boss visual-scale reassert warning: #{e.class}: #{e.message}");false
  end

  # BAS/Animated DBK can replace the whole battler bitmap while showing a
  # temporary Front/Back view. Rebuild the natural renderer and restore the
  # original DISPLAYED dimensions instead of blindly reusing zoom_x/zoom_y.
  def bss_restore_boss_natural_renderer(battler,snapshot=nil,force=false)
    return false if !battler || (battler.fainted? rescue false)
    sprite=bss_boss_target_sprite(battler);return false if !sprite || (sprite.disposed? rescue true)
    idx=(battler.index rescue -1).to_i;return false if idx<0
    return false if !force && !bss_boss_renderer_profile_mismatch?(sprite,idx)
    pkmn=(battler.visiblePokemon rescue nil) if battler.respond_to?(:visiblePokemon)
    pkmn ||= (battler.pokemon rescue nil) if battler.respond_to?(:pokemon)
    return false if !pkmn
    back=(battler.index.to_i.even? rescue false)
    x=snapshot && snapshot[:x] ? snapshot[:x] : (sprite.x rescue nil);y=snapshot && snapshot[:y] ? snapshot[:y] : (sprite.y rescue nil);z=snapshot && snapshot[:z] ? snapshot[:z] : (sprite.z rescue nil)
    begin;sprite.setPokemonBitmap(pkmn,battler,back);rescue ArgumentError, TypeError;sprite.setPokemonBitmap(pkmn,back);end
    sprite.x=x if !x.nil? && sprite.respond_to?(:x=);sprite.y=y if !y.nil? && sprite.respond_to?(:y=);sprite.z=z if !z.nil? && sprite.respond_to?(:z=)
    bss_apply_boss_display_size(sprite,idx)
    true
  rescue => e
    BSS064.log("Boss natural renderer restore warning: #{e.class}: #{e.message}");false
  end

  def bss_boss_dynamic_bitmap_active?(battler)
    return false if !battler
    idx=(battler.index rescue -1).to_i
    return true if (battler.status rescue :NONE)==:SLEEP
    hits=instance_variable_get(:@_carnek_active_hits) rescue nil
    if hits.is_a?(Array)
      target=bss_boss_target_sprite(battler) rescue nil
      return true if hits.any? { |anim| (anim._carnek_hit_sprite rescue nil).equal?(target) }
    end
    return true if (battler.fainted? rescue false)
    false
  rescue
    false
  end

  def bss_sync_dynamic_boss_visual
    bss_update_boss_aura if respond_to?(:bss_update_boss_aura)
  rescue
  end

  def bss_guard_boss_sprite_scale
    return if @bss_boss_animation_depth.to_i>0
    battle=@battle;return if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled?
    battler=battle.bss_find_boss_battler rescue nil;return if !battler
    # Sleep/Hit/Fainted overlays deliberately replace the battler bitmap. Never
    # classify those authored state graphics as a leaked BAS renderer and rebuild
    # the normal Front/Back bitmap over them.
    return if bss_boss_dynamic_bitmap_active?(battler)
    bss_reassert_boss_visual_scale(battler,true)
  rescue => e
    BSS064.log("Boss scale guard warning: #{e.class}: #{e.message}")
  end

  def bss_boss_transition_alpha
    factor=1.0
    begin
      c=@viewport && @viewport.respond_to?(:color) ? @viewport.color : nil
      factor*=(1.0-[[c.alpha.to_f/255.0,0.0].max,1.0].min) if c && c.respond_to?(:alpha)
    rescue
    end
    [[factor,0.0].max,1.0].min
  rescue
    1.0
  end

  def bss_update_boss_aura
    bss_guard_boss_sprite_scale
    battle=@battle
    if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled? ||
       !battle.respond_to?(:bss_boss_has_stat_aura?) || !battle.bss_boss_has_stat_aura? ||
       !battle.respond_to?(:bss_boss_aura_active) || battle.bss_boss_aura_active!=true
      bss_dispose_boss_aura if @bss_boss_aura_emitter || @bss_boss_aura_outline
      return
    end

    live=battle.bss_find_boss_battler rescue nil
    battler=live || @bss_boss_aura_battler
    if !battler
      bss_dispose_boss_aura if @bss_boss_aura_emitter || @bss_boss_aura_outline
      return
    end
    idx=(battler.index rescue -1).to_i
    sprite=bss_boss_target_sprite(battler)
    if idx<0 || !sprite || (sprite.disposed? rescue true)
      bss_dispose_boss_aura if @bss_boss_aura_emitter || @bss_boss_aura_outline
      return
    end

    if !@bss_boss_aura_emitter || (@bss_boss_aura_emitter.disposed? rescue true) || @bss_boss_aura_index!=idx
      bss_dispose_boss_aura
      cfg=BSS064.boss_aura_config(battle.bss_boss_config)
      @bss_boss_aura_emitter=BSS064::BossAuraEmitter.new(@viewport,bss_scene_sprites,cfg,"bss_totem_persistent")
      @bss_boss_aura_outline=BSS064::BossAuraOutline.new(@viewport,bss_scene_sprites,cfg,"bss_totem_outline") if cfg["outlineEnabled"]
      @bss_boss_aura_index=idx
      @bss_boss_aura_battler=battler
      @bss_boss_aura_fade_started=nil
    end

    fainted=(battler.fainted? rescue false)
    if fainted
      cfg=BSS064.boss_aura_config(battle.bss_boss_config)
      @bss_boss_aura_fade_started ||= BSS064.monotonic_seconds
      duration=[BSS064.clamp_int(cfg["fadeOutFrames"],1,90,18).to_f/40.0,0.025].max
      elapsed=BSS064.monotonic_seconds-@bss_boss_aura_fade_started
      factor=1.0-(elapsed/duration)
      if factor<=0.0
        bss_dispose_boss_aura
        return
      end
      factor=[[factor,0.0].max,1.0].min
      factor*=bss_boss_transition_alpha
      @bss_boss_aura_emitter.update(sprite,battler,factor,true) if @bss_boss_aura_emitter
      @bss_boss_aura_outline.update(sprite,battler,factor,true) if @bss_boss_aura_outline
      return
    end

    @bss_boss_aura_battler=battler
    @bss_boss_aura_fade_started=nil
    visual_alpha=bss_boss_transition_alpha
    @bss_boss_aura_emitter.update(sprite,battler,visual_alpha,false) if @bss_boss_aura_emitter
    @bss_boss_aura_outline.update(sprite,battler,visual_alpha,false) if @bss_boss_aura_outline
  rescue => e
    BSS064.log("Boss aura scene warning: #{e.class}: #{e.message}")
  end

  # Update once per logical scene frame. pbFrameUpdate covers normal menus and
  # target selection; BAS has its own pump hook below for the exact pre-camera
  # point during Studio animations.
  def bss_tick_boss_aura_once(force=false)
    token=(Graphics.frame_count rescue nil)
    return if !force && !token.nil? && @bss_boss_aura_last_tick==token
    @bss_boss_aura_last_tick=token if !token.nil?
    bss_update_boss_aura
    bss_update_boss_hud(false) if respond_to?(:bss_update_boss_hud)
  rescue
  end

  def bss_plain_frame_pump
    if respond_to?(:pbUpdate)
      pbUpdate
      return
    end
    Graphics.update
    respond_to?(:pbInputUpdate) ? pbInputUpdate : Input.update
    pbFrameUpdate(nil) if respond_to?(:pbFrameUpdate)
  rescue
    Graphics.update rescue nil
    Input.update rescue nil
  end

  def bss_boss_static_camera_offset(sprite)
    cx=(Graphics.width rescue 512).to_f/2.0
    cy=(Graphics.height rescue 384).to_f/2.0
    return [0.0,0.0] if !sprite || (sprite.disposed? rescue true)
    sx=(sprite.x rescue cx).to_f
    sy=(sprite.y rescue cy).to_f
    src=(sprite.src_rect rescue nil)
    bmp=(sprite.bitmap rescue nil)
    h=if src && src.height.to_i>0 then src.height.to_f elsif bmp && !(bmp.disposed? rescue true) then bmp.height.to_f else 80.0 end
    zy=(sprite.zoom_y rescue 1.0).to_f.abs
    # Sample once. Animated battler frame/bitmap changes can no longer pull the
    # camera around during the Totem charge like BAS's live focus directive did.
    [sx-cx,(sy-(h*zy/2.0))-cy]
  rescue
    [0.0,0.0]
  end

  def bss_bas_camera_data(total,zoom,bounds_mode="screen",offset_x=0.0,offset_y=0.0)
    fps=40.0
    focus_in=28
    out_frames=28
    clear_start=[total.to_i-out_frames,focus_in+1].max
    clear_start=[clear_start,total.to_i-2].min
    mode=(bounds_mode.to_s=="extended" ? "extended" : "screen")
    {
      "id"=>"bss_totem_aura_camera", "name"=>"BSS Totem Aura Camera",
      "fps"=>fps, "duration"=>total.to_i,
      "source"=>{"type"=>"custom","catalogType"=>"common","targetMode"=>"foe"},
      "battlers"=>{}, "tracks"=>[], "events"=>[], "logic"=>[],
      "scene"=>{"cameraBoundsMode"=>mode},
      "camera"=>{
        "id"=>"camera_main","type"=>"camera","name"=>"Camera","enabled"=>true,
        "visual"=>{"cameraX"=>0,"cameraY"=>0,"cameraZoom"=>100,"cameraRotation"=>0,"opacity"=>100},
        "visibleKeys"=>[{"frame"=>0,"value"=>true}],
        "valueKeys"=>{
          "cameraX"=>[
            {"frame"=>0,"value"=>0,"easing"=>"ease_both"},
            {"frame"=>focus_in,"value"=>offset_x.to_f,"easing"=>"ease_both"},
            {"frame"=>clear_start,"value"=>offset_x.to_f,"easing"=>"linear"},
            {"frame"=>total.to_i-1,"value"=>0,"easing"=>"ease_both"}
          ],
          "cameraY"=>[
            {"frame"=>0,"value"=>0,"easing"=>"ease_both"},
            {"frame"=>focus_in,"value"=>offset_y.to_f,"easing"=>"ease_both"},
            {"frame"=>clear_start,"value"=>offset_y.to_f,"easing"=>"linear"},
            {"frame"=>total.to_i-1,"value"=>0,"easing"=>"ease_both"}
          ],
          "cameraRotation"=>[],
          "cameraZoom"=>[
            {"frame"=>0,"value"=>100,"easing"=>"ease_both"},
            {"frame"=>focus_in,"value"=>zoom.to_f,"easing"=>"ease_both"},
            {"frame"=>clear_start,"value"=>zoom.to_f,"easing"=>"linear"},
            {"frame"=>total.to_i-1,"value"=>100,"easing"=>"ease_both"}
          ]
        },
        "logic"=>[]
      }
    }
  end

  # BSS cinematics may temporarily change the native Turbo speed to keep their
  # timing deterministic. Turbo#set_speed intentionally displays its HUD icon,
  # which is useful during normal play but breaks the Boss/Totem presentation.
  # Hide only that indicator; the player's configured speed is restored below.
  def bss650_hide_native_turbo_icon
    begin
      if defined?(TurboConfig) && TurboConfig.const_defined?(:ICON_DURATION)
        $buttonframes=TurboConfig::ICON_DURATION.to_i
      elsif defined?($buttonframes)
        $buttonframes=999999
      end
    rescue
    end
    begin
      if defined?(Graphics)
        icon=Graphics.instance_variable_get(:@boton_turbo)
        if icon
          bmp=(icon.bitmap rescue nil)
          bmp.dispose if bmp && !(bmp.disposed? rescue true)
          icon.dispose if !(icon.disposed? rescue true)
        end
        Graphics.instance_variable_set(:@boton_turbo,nil)
        Graphics.instance_variable_set(:@last_turbo_speed,nil)
      end
    rescue
    end
    true
  end

  def bss_play_boss_aura_sequence(battler,boss_cfg)
    intro=nil;player=nil;turbo_restore=nil;scale_snapshot=nil;scale_depth=false
    sprite=bss_boss_target_sprite(battler);return if !sprite
    cfg=BSS064.boss_aura_config(boss_cfg)
    begin
      scale_snapshot=bss_boss_animation_scale_snapshot if respond_to?(:bss_boss_animation_scale_snapshot)
      @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1;scale_depth=true
    rescue
    end

    # Aura intro is authored in real 40-Hz time. Lock the user's native Turbo
    # to x1 for the whole sequence so Input.update cannot change it mid-charge.
    if defined?(Turbo) && Turbo.respond_to?(:set_speed)
      begin
        old_speed=Turbo.respond_to?(:speed) ? Turbo.speed.to_i : (defined?($GameSpeed) ? $GameSpeed.to_i : 0)
        old_toggle=defined?($CanToggle) ? $CanToggle : nil
        turbo_restore={:speed=>old_speed,:toggle=>old_toggle}
        $CanToggle=false if defined?($CanToggle)
        bss650_hide_native_turbo_icon
        Turbo.set_speed(0)
        bss650_hide_native_turbo_icon
      rescue => e
        BSS064.log("Aura Turbo lock warning: #{e.class}: #{e.message}")
      end
    end

    intro=BSS064::BossAuraIntro.new(self,sprite,battler,cfg) do
      if @battle && @battle.respond_to?(:bss_boss_aura_active=);@battle.bss_boss_aura_active=true;end
      bss_update_boss_aura
    end
    total=intro.total_duration.to_i;BSS064.install_bas_aura_compat
    center_ebdx=cfg["ebdxCenterMon"] && respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    use_bas=(cfg["basZoomEnabled"] || center_ebdx) && BSS064.bas_available? && respond_to?(:bas_runtime_pump_frame)
    if use_bas
      offset=bss_boss_static_camera_offset(sprite)
      if center_ebdx
        # BAS subtracts cameraX/Y. Offset 0/0 therefore puts the battler exactly
        # in screen center; positive user offsets move the centered composition.
        offset[0]-=cfg["ebdxCenterOffsetX"].to_f;offset[1]-=cfg["ebdxCenterOffsetY"].to_f
      end
      bounds=center_ebdx ? "extended" : cfg["basZoomBounds"]
      data=bss_bas_camera_data(total,cfg["basZoom"],bounds,offset[0],offset[1])
      player=BattleAnimationStudioRuntime::Player.new(bss_scene_sprites,@viewport,battler,battler,data,[battler])
      BattleAnimationStudioRuntime.active_player=player if BattleAnimationStudioRuntime.respond_to?(:active_player=)
    end
    started=BSS064.monotonic_seconds;last_logic=-1;safety=0
    loop do
      elapsed=BSS064.monotonic_seconds-started;logical=(elapsed*40.0).floor;logical=0 if logical<0;logical=total-1 if logical>=total
      if logical>last_logic
        first=[last_logic+1,0].max;(first..logical).each { |f| intro.update(f) };last_logic=logical
      end
      use_bas ? (player.update;bas_runtime_pump_frame(player)) : bss_plain_frame_pump
      break if elapsed*40.0>=total;safety+=1;break if safety>20000
    end
  rescue => e
    BSS064.log("Boss aura sequence warning: #{e.class}: #{e.message}")
  ensure
    begin
      if player && defined?(BattleAnimationStudioRuntime) && BattleAnimationStudioRuntime.respond_to?(:active_player=) && BattleAnimationStudioRuntime.active_player.equal?(player);BattleAnimationStudioRuntime.active_player=nil;end
    rescue;end
    begin;player.restore_camera! if player;rescue;end;begin;player.dispose if player;rescue;end
    if scale_depth
      @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
      begin;bss_restore_boss_animation_scale(scale_snapshot) if scale_snapshot && respond_to?(:bss_restore_boss_animation_scale);rescue;end
      begin;bss_reassert_boss_visual_scale(battler,true) if respond_to?(:bss_reassert_boss_visual_scale);rescue;end
    end
    if @battle && @battle.respond_to?(:bss_boss_aura_active=) && @battle.respond_to?(:bss_boss_has_stat_aura?) && @battle.bss_boss_has_stat_aura?
      @battle.bss_boss_aura_active=true;begin;bss_update_boss_aura;rescue;end
    end
    begin;intro.dispose if intro;rescue;end
    if turbo_restore && defined?(Turbo) && Turbo.respond_to?(:set_speed)
      begin
        Turbo.set_speed(turbo_restore[:speed].to_i)
        bss650_hide_native_turbo_icon
        $CanToggle=turbo_restore[:toggle] if defined?($CanToggle) && !turbo_restore[:toggle].nil?
      rescue => e
        BSS064.log("Aura Turbo restore warning: #{e.class}: #{e.message}")
      end
    end
  end
end

# A move/common animation may temporarily scale a battler, but several BAS/DBK
# combinations restore that temporary value as if it were the battler's native
# renderer scale. Snapshot the Totem immediately before each animation and put
# that exact scale back afterward. The animation is still free to scale it while
# it is playing; only the leaked post-animation state is corrected.
module BSS064BossAnimationScaleCompat
  def bss_boss_animation_scale_snapshot
    battle=@battle
    return nil if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled?
    battler=(battle.bss_find_boss_battler rescue nil) || @bss_boss_aura_battler
    return nil if !battler
    sprite=bss_boss_target_sprite(battler) rescue nil
    return nil if !sprite || (sprite.disposed? rescue true)
    idx=(battler.index rescue -1).to_i
    base=bss_capture_boss_native_scale(battler,false) rescue nil
    zx=base ? base[0].to_f : (sprite.zoom_x rescue 1.0).to_f
    zy=base ? base[1].to_f : (sprite.zoom_y rescue 1.0).to_f
    {
      :sprite=>sprite,:battler=>battler,:idx=>idx,:zoom_x=>zx,:zoom_y=>zy,
      :x=>(sprite.x rescue 0).to_f,:y=>(sprite.y rescue 0).to_f,:z=>(sprite.z rescue 50).to_i,
      :display_w=>((bss_boss_frame_dimensions(sprite)[0] rescue 0).to_f*(sprite.zoom_x rescue 1.0).to_f.abs),
      :display_h=>((bss_boss_frame_dimensions(sprite)[1] rescue 0).to_f*(sprite.zoom_y rescue 1.0).to_f.abs)
    }
  rescue
    nil
  end

  def bss_restore_boss_animation_scale(snapshot)
    return if !snapshot.is_a?(Hash)
    battler=snapshot[:battler]
    sprite=snapshot[:sprite]
    return if !sprite || (sprite.disposed? rescue true)
    idx=snapshot[:idx].to_i
    # Repair a leaked Front/Back renderer profile first. This is the missing
    # step for LBDS Animated DBK, where the view's x2/x3 scale lives inside the
    # rebuilt bitmap rather than only in sprite.zoom_x/y.
    bss_restore_boss_natural_renderer(battler,snapshot,false) if battler && respond_to?(:bss_restore_boss_natural_renderer)
    sprite=bss_boss_target_sprite(battler) rescue sprite
    return if !sprite || (sprite.disposed? rescue true)
    # Renderer dimensions may have changed. First restore the exact physical
    # footprint seen immediately before this animation/SOS call. This is more
    # robust than restoring raw zoom on LBDS Animated DBK because Front/Back
    # changes can rebuild a bitmap at a different baked-in scale.
    applied=false
    begin
      fw,fh=bss_boss_frame_dimensions(sprite)
      want_w=snapshot[:display_w].to_f;want_h=snapshot[:display_h].to_f
      if fw.to_f>0 && fh.to_f>0 && want_w>0 && want_h>0
        sx=snapshot[:zoom_x].to_f<0 ? -1.0 : 1.0
        sy=snapshot[:zoom_y].to_f<0 ? -1.0 : 1.0
        sprite.zoom_x=sx*(want_w/fw.to_f) if sprite.respond_to?(:zoom_x=)
        sprite.zoom_y=sy*(want_h/fh.to_f) if sprite.respond_to?(:zoom_y=)
        applied=true
      end
    rescue
      applied=false
    end
    bss_apply_boss_display_size(sprite,idx) if !applied && respond_to?(:bss_apply_boss_display_size)
    sprite.x=snapshot[:x] if sprite.respond_to?(:x=)
    sprite.y=snapshot[:y] if sprite.respond_to?(:y=)
    sprite.z=snapshot[:z] if sprite.respond_to?(:z=)
    @bss_boss_native_scale ||= {}
    @bss_boss_native_scale[idx]=[snapshot[:zoom_x].to_f,snapshot[:zoom_y].to_f] if idx>=0 && !@bss_boss_native_scale[idx]
  rescue => e
    BSS064.log("Boss animation scale restore warning: #{e.class}: #{e.message}")
  end

  def pbAnimation(*args,&block)
    @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1
    snapshot=bss_boss_animation_scale_snapshot
    super
  ensure
    @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
    bss_restore_boss_animation_scale(snapshot) if @bss_boss_animation_depth==0
  end

  def pbCommonAnimation(*args,&block)
    @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1
    snapshot=bss_boss_animation_scale_snapshot
    super
  ensure
    @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
    bss_restore_boss_animation_scale(snapshot) if @bss_boss_animation_depth==0
  end
end

# BAS-exported move/custom animations are invoked through pbPlayBattleAnimationStudio
# directly and can bypass Scene#pbAnimation entirely. Protect the Totem scale on
# that real playback entry point as well; this module is only prepended when BAS
# actually defines the method on the active scene.
module BSS064BossBASAnimationScaleCompat
  def pbPlayBattleAnimationStudio(*args,&block)
    @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1
    snapshot=bss_boss_animation_scale_snapshot
    super
  ensure
    @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
    bss_restore_boss_animation_scale(snapshot) if @bss_boss_animation_depth==0
  end

  def pbPlayBattleAnimationStudioCustom(*args,&block)
    @bss_boss_animation_depth=@bss_boss_animation_depth.to_i+1
    snapshot=bss_boss_animation_scale_snapshot
    super
  ensure
    @bss_boss_animation_depth=[@bss_boss_animation_depth.to_i-1,0].max
    bss_restore_boss_animation_scale(snapshot) if @bss_boss_animation_depth==0
  end
end

# BSS-native barrier hooks. Damage scaling mirrors the supplied Raid Battles
# approach by modifying the final damaging-move multiplier, while segment loss
# is attached to the boss's actual HP-loss event. Other battles are untouched.
module BSS064BossShieldMoveCompat
  def pbInflictHPDamage(target)
    battle=@battle rescue nil
    return battle.bss_with_boss_direct_damage_context(target) { super } if battle && battle.respond_to?(:bss_with_boss_direct_damage_context)
    super
  end

  def pbCalcDamageMults_Screens(user,target,numTargets,type,baseDmg,multipliers)
    super
    battle=(target.instance_variable_get(:@battle) rescue nil)
    if battle && battle.respond_to?(:bss_boss_shield_active?) && battle.bss_boss_shield_active?(target)
      cfg=battle.bss_boss_hud_config rescue {}
      multipliers[:final_damage_multiplier] *= BSS064.clamp_float(cfg["shieldDamagePercent"],1,100,5)/100.0
    end
  end
end

module BSS064BossShieldBattlerCompat
  def pbReduceHP(amt,*args)
    battle=@battle rescue nil
    boss=(battle.bss_find_boss_battler_any rescue nil) if battle && battle.respond_to?(:bss_find_boss_battler_any)
    boss ||= (battle.bss_find_boss_battler rescue nil) if battle && battle.respond_to?(:bss_find_boss_battler)
    is_boss=!!(boss && boss.equal?(self))
    shield_before=is_boss && battle && battle.respond_to?(:bss_boss_shield_active?) && battle.bss_boss_shield_active?(self)
    passive_context=(battle.respond_to?(:bss_boss_residual_context) ? battle.bss_boss_residual_context : nil) if battle
    # A live shield absorbs all residual/end-of-turn damage. It neither loses a
    # segment nor lets the tick leak into the Boss's base HP.
    return 0 if is_boss && shield_before && passive_context
    if is_boss && battle && passive_context && battle.respond_to?(:bss_native_boss_immunity?) && battle.bss_native_boss_immunity?(self,:INDIRECT)
      return 0
    end
    if is_boss && battle && battle.respond_to?(:bss_boss_residual_multiplier_for) && amt.is_a?(Numeric)
      mult=battle.bss_boss_residual_multiplier_for(self)
      if mult<0.999999
        original=amt.to_f;scaled=(original*mult).round;scaled=1 if mult>0.0 && original>0.0 && scaled<1;scaled=0 if mult<=0.0;amt=scaled
      end
    end
    oldhp=(@hp rescue 0).to_i
    result=super(amt,*args)
    direct_target=(battle.respond_to?(:bss_boss_direct_damage_target) ? battle.bss_boss_direct_damage_target : nil) if battle
    # Only HP damage actually inflicted by Battle::Move#pbInflictHPDamage can
    # consume a barrier segment. Recoil, Life Orb, self-damage and EOR ticks do not.
    if is_boss && battle && battle.respond_to?(:bss_damage_boss_shield) && shield_before && direct_target && direct_target.equal?(self) && (@hp rescue oldhp).to_i<oldhp
      battle.bss_damage_boss_shield(self,1)
    elsif is_boss && battle && battle.respond_to?(:bss_try_start_boss_shield) && (@hp rescue oldhp).to_i<oldhp
      battle.bss_try_start_boss_shield(self,false)
    end
    result
  end
end

begin
  Battle::Move.prepend(BSS064BossShieldMoveCompat) if defined?(Battle::Move) && !Battle::Move.ancestors.include?(BSS064BossShieldMoveCompat)
rescue => e;BSS064.log("Boss shield move hook warning: #{e.class}: #{e.message}");end
begin
  Battle::Battler.prepend(BSS064BossShieldBattlerCompat) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossShieldBattlerCompat)
rescue => e;BSS064.log("Boss shield battler hook warning: #{e.class}: #{e.message}");end


# Make the custom Boss bar participate in the same HUD visibility contract used
# by DBK. Move/common animations that call pbToggleDataboxes now hide/show the
# BossHUD with the same short transition instead of letting effects draw through it.
module BSS064BossHUDSceneCompat
  def pbToggleDataboxes(toggle=false)
    begin
      hud=@bss_boss_hud
      hud.request_visibility(toggle,0.075) if hud && hud.respond_to?(:request_visibility)
    rescue
    end
    result=super
    begin
      hud=@bss_boss_hud
      hud.hide_native_databox if hud && hud.respond_to?(:hide_native_databox)
      bss652_hide_native_boss_databox if respond_to?(:bss652_hide_native_boss_databox)
    rescue
    end
    result
  end

  def pbHideDatabox(*args,&block)
    begin
      idx=(args[0] rescue -1).to_i
      battle=@battle
      boss=(battle.bss_find_boss_battler_any rescue nil) if battle && battle.respond_to?(:bss_find_boss_battler_any)
      boss ||= (battle.bss_find_boss_battler rescue nil) if battle && battle.respond_to?(:bss_find_boss_battler)
      if boss && idx==(boss.index rescue -2).to_i
        hud=@bss_boss_hud
        hud.request_visibility(false,0.075) if hud && hud.respond_to?(:request_visibility)
      end
    rescue
    end
    super
  end
end

# Tag the exact end-of-round source while Essentials evaluates it. pbReduceHP
# then scales only the Boss and only that category, leaving direct attacks and
# every non-BSS battle untouched.
module BSS064BossResidualEORCompat
  def pbEORTrappingDamage(*args,&block)
    bss_with_boss_residual_context(:trapping) { super }
  end
  def pbEORHealingEffects(*args,&block)
    bss_with_boss_residual_context(:move_effect) { super }
  end
  def pbEORSeaOfFireDamage(*args,&block)
    bss_with_boss_residual_context(:move_effect) { super }
  end
  def pbEOREffectDamage(*args,&block)
    bss_with_boss_residual_context(:move_effect) { super }
  end
  def pbEORStatusProblemDamage(*args,&block)
    bss_with_boss_residual_context(:status) { super }
  end
  def pbEORWeatherDamage(*args,&block)
    bss_with_boss_residual_context(:weather) { super }
  end
end

begin
  Battle.prepend(BSS064BossResidualEORCompat) if defined?(Battle) && !Battle.ancestors.include?(BSS064BossResidualEORCompat)
rescue => e;BSS064.log("Boss residual EOR hook warning: #{e.class}: #{e.message}");end

# The user's Hit/Sleep system swaps battler bitmaps immediately before
# Graphics.update. Sync the aura after those swaps so the outline/particles use
# the exact same frame on the same rendered frame, rather than one frame late.
module BSS064DynamicBattlerBitmapCompat
  def _carnek_sleep_ensure_bitmaps(*args,&block)
    result=super
    bss_sync_dynamic_boss_visual if respond_to?(:bss_sync_dynamic_boss_visual)
    result
  end

  def _carnek_hit_apply_pending(*args,&block)
    result=super
    bss_sync_dynamic_boss_visual if respond_to?(:bss_sync_dynamic_boss_visual)
    result
  end
end

# FaintedBitmap is applied after Scene#pbUpdate in the supplied faint animation,
# so it needs its own immediate aura resync as well.
module BSS064FaintBitmapAuraCompat
  def pbUpdateFaintOverlay(*args,&block)
    result=super
    begin
      scene=Battle::Scene.respond_to?(:carnek_scene) ? Battle::Scene.carnek_scene : nil
      scene.bss_sync_dynamic_boss_visual if scene && scene.respond_to?(:bss_sync_dynamic_boss_visual)
    rescue
    end
    result
  end
end

# Normal battle/UI pump. This is what keeps the aura moving during menus,
# target selection, switch prompts and message windows.
module BSS064BossAuraFrameCompat
  def pbUpdate(*args,&block)
    result=super
    if !@bss_boss_aura_in_bas_pump && respond_to?(:bss_tick_boss_aura_once)
      bss_tick_boss_aura_once(false)
    end
    result
  end

  def pbFrameUpdate(*args,&block)
    result=super
    # BAS calls pbFrameUpdate from inside its own pump after Graphics.update.
    # The aura has already been sampled immediately before BAS camera/render in
    # BSS064BossAuraBASPumpCompat, so do not advance it a second time here.
    if !@bss_boss_aura_in_bas_pump && respond_to?(:bss_tick_boss_aura_once)
      bss_tick_boss_aura_once(false)
    end
    result
  end

end

# BAS bypasses Battle::Scene#pbUpdate and drives its own frame pump. Update the
# persistent aura after BAS has modified battler properties but *before* BAS
# applies the temporary camera transform and calls Graphics.update.
module BSS064BossAuraBASPumpCompat
  def bas_runtime_pump_frame(player)
    @bss_boss_aura_in_bas_pump=true
    # Player#update has already written the animation's live Battler properties.
    # Sample them now; super will apply the temporary BAS camera transform next.
    bss_tick_boss_aura_once(false) if respond_to?(:bss_tick_boss_aura_once)
    super
  ensure
    @bss_boss_aura_in_bas_pump=false
  end
end

# Scene/BAS frame hooks are installed only on the active Boss/Totem scene
# instance by configure_native_boss. Normal battles are left completely untouched.


#===============================================================================
# BSS 0.6.49 - native boss attributes, transition-safe HUD and scalable shields
#===============================================================================
class BSS064::BossHUD
  unless method_defined?(:bss649_initialize_without_color)
    alias bss649_initialize_without_color initialize
  end
  def initialize(*args)
    @external_color=Color.new(0,0,0,0) rescue nil
    @shield_cells=[]
    bss649_initialize_without_color(*args)
  end

  def color
    c=@external_color
    return c.clone if c && c.respond_to?(:clone)
    Color.new(0,0,0,0)
  rescue
    nil
  end

  def color=(value)
    @external_color=(value && value.respond_to?(:clone)) ? value.clone : value
    bss649_apply_external_color
  rescue
  end

  def bss649_apply_external_color
    return if !@external_color
    @sprites.each do |sp|
      next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:color=)
      sp.color=@external_color.clone rescue sp.color=@external_color
    end
  rescue
  end

  unless method_defined?(:bss649_update_without_external_color)
    alias bss649_update_without_external_color update
  end
  def update(*args)
    ret=bss649_update_without_external_color(*args)
    if @external_color && (@external_color.alpha rescue 0).to_i>0
      bss649_apply_external_color
    end
    ret
  end

  def visible=(value)
    @external_visible=(value!=false)
    if value==false
      @sprites.each { |sp| sp.visible=false if sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible=) }
    end
  rescue
  end

  def shield_center(maxseg)
    [@base_x+SHIELD_X+SHIELD_OFFSET_X,SHIELD_W]
  end

  def bss649_shield_cell_geometry(index,maxseg)
    n=[[maxseg.to_i,1].max,24].min
    left=@base_x+SHIELD_X+SHIELD_OFFSET_X
    display=SHIELD_W.to_f/n.to_f
    zoom=display/SHIELD_SEGMENT_W.to_f
    [left+index.to_i*display+display/2.0,@base_y+SHIELD_Y+SHIELD_OFFSET_Y+SHIELD_H/2.0,zoom]
  end

  def bss649_ensure_shield_cells(maxseg)
    maxseg=[[maxseg.to_i,0].max,24].min
    @shield_cells ||= []
    if @shield_cells.length!=maxseg
      dispose_aux(@shield_cells) if !@shield_cells.empty?
      maxseg.times do |i|
        sp=make_sprite(@shield_bitmap,3);next if !sp
        sp.ox=SHIELD_SEGMENT_W/2;sp.oy=SHIELD_H/2
        @shield_cells << {:sprite=>sp,:index=>i}
      end
    end
    @shield_max.visible=false if @shield_max
    @shield_live.visible=false if @shield_live
  rescue
  end

  def start_shield_spawn(seg,maxseg)
    dispose_aux(@shield_spawn_segments);return if !@shield_bitmap || seg.to_i<=0
    @shield_spawn_started=now
    seg.to_i.times do |i|
      sp=make_sprite(@shield_bitmap,5);next if !sp
      x,y,bz=bss649_shield_cell_geometry(i,maxseg)
      sp.src_rect.set((i%8)*SHIELD_SEGMENT_W,SHIELD_H,SHIELD_SEGMENT_W,SHIELD_H)
      sp.ox=SHIELD_SEGMENT_W/2;sp.oy=SHIELD_H/2;sp.x=x;sp.y=y;sp.opacity=0;sp.zoom_x=bz*3.0;sp.zoom_y=3.0
      @shield_spawn_segments << {:sprite=>sp,:index=>i,:base_zoom=>bz}
    end
    begin;pbSEPlay("Vs sword");rescue;end
  rescue => e;BSS064.log("Boss shield spawn warning: #{e.class}: #{e.message}");end

  def update_shield_spawn
    return false if !@shield_spawn_started
    t=now;done=true
    @shield_spawn_segments.each do |row|
      sp=row[:sprite];next if !sp || (sp.disposed? rescue true)
      local=(t-@shield_spawn_started-row[:index].to_i*0.045)/0.22
      if local<=0;sp.opacity=0;done=false;next;end
      p=[[local,0.0].max,1.0].min;done=false if p<1.0;ease=1.0-(1.0-p)**3
      sp.opacity=(255*ease).round;sp.zoom_x=row[:base_zoom].to_f*(3.0-2.0*ease);sp.zoom_y=3.0-2.0*ease
      begin;sp.color=Color.new(255,255,255,((1.0-ease)*220).round);rescue;end
    end
    if done;dispose_aux(@shield_spawn_segments);@shield_spawn_started=nil;return false;end
    true
  rescue;false;end

  def spawn_shield_ghosts(before,after,maxseg)
    return if !@shield_bitmap || before.to_i<=after.to_i
    (after.to_i...before.to_i).each do |i|
      sp=make_sprite(@shield_bitmap,6);next if !sp
      x,y,bz=bss649_shield_cell_geometry(i,maxseg)
      sp.src_rect.set((i%8)*SHIELD_SEGMENT_W,SHIELD_H,SHIELD_SEGMENT_W,SHIELD_H)
      sp.ox=SHIELD_SEGMENT_W/2;sp.oy=SHIELD_H/2;sp.x=x;sp.y=y;sp.zoom_x=bz;sp.zoom_y=1.0
      @shield_ghosts << {:sprite=>sp,:start=>now+(before.to_i-1-i)*0.045,:x=>x.to_f,:y=>y.to_f,:base_zoom=>bz}
    end
  rescue => e;BSS064.log("Boss shield ghost warning: #{e.class}: #{e.message}");end

  def update_shield_ghosts
    t=now
    @shield_ghosts.delete_if do |row|
      sp=row[:sprite];next true if !sp || (sp.disposed? rescue true)
      p=(t-row[:start].to_f)/0.34
      if p<0;false
      elsif p>=1.0;begin;sp.dispose;rescue;end;@sprites.delete(sp) rescue nil;true
      else
        lift=p<0.28 ? (-7.0*(p/0.28)) : (-7.0+17.0*((p-0.28)/0.72))
        sp.x=row[:x];sp.y=row[:y]+lift;sp.opacity=(255*(1.0-p)).round;sp.zoom_x=row[:base_zoom].to_f*(1.0-0.25*p);sp.zoom_y=1.0-0.25*p
        begin;sp.color=Color.new(0,0,0,(170*p).round);rescue;end;false
      end
    end
  rescue;end

  def apply_shield_break_visual
    return false if !@shield_break_started
    p=[[((now-@shield_break_started)/0.52),0.0].max,1.0].min
    rows=(@shield_cells||[]);group=[@shield_bg]+rows.map{|r|r[:sprite]};group.compact!
    if p<0.52
      shake=(Math.sin(p*Math::PI*28.0)*2.5).round
      @shield_bg.x=@base_x+SHIELD_X+shake if @shield_bg
      rows.each do |r|
        sp=r[:sprite];next if !sp;gx,gy,gz=bss649_shield_cell_geometry(r[:index],@last_shield_max||rows.length);sp.x=gx+shake;sp.y=gy;sp.zoom_x=gz;sp.zoom_y=1.0
      end
    else
      q=(p-0.52)/0.48
      group.each do |sp|
        sp.opacity=(255*(1.0-q)).round;sp.zoom_y=1.0+1.8*q
        begin;sp.color=Color.new(255,255,255,(210*q).round);rescue;end
      end
    end
    if p>=1.0;group.each{|sp|sp.visible=false if sp};@shield_break_started=nil;@shield_break_done=true;return false;end
    true
  rescue;false;end

  def update_shield(seg,maxseg)
    maxseg=[[maxseg.to_i,0].max,24].min;seg=[[seg.to_i,0].max,maxseg].min
    enabled=@cfg["shieldEnabled"]==true && maxseg>0
    bss649_ensure_shield_cells(enabled ? maxseg : 0)
    group=[@shield_bg]+(@shield_cells||[]).map{|r|r[:sprite]};group.compact!
    if !enabled
      group.each{|sp|sp.visible=false};dispose_aux(@shield_spawn_segments);dispose_aux(@shield_ghosts);@last_shield_segments=seg;@last_shield_max=maxseg;return
    end
    if @shield_bg;@shield_bg.x=@base_x+SHIELD_X;@shield_bg.y=@base_y+SHIELD_Y;@shield_bg.visible=true;@shield_bg.opacity=255;@shield_bg.zoom_x=1.0;@shield_bg.zoom_y=1.0;begin;@shield_bg.color=Color.new(0,0,0,0);rescue;end;end
    (@shield_cells||[]).each do |r|
      sp=r[:sprite];next if !sp;x,y,z=bss649_shield_cell_geometry(r[:index],maxseg);sp.x=x;sp.y=y;sp.zoom_x=z;sp.zoom_y=1.0;sp.src_rect.set((r[:index]%8)*SHIELD_SEGMENT_W,(r[:index]<seg ? SHIELD_H : 0),SHIELD_SEGMENT_W,SHIELD_H);sp.opacity=255;sp.visible=true;begin;sp.color=Color.new(0,0,0,0);rescue;end
    end
    @shield_break_done=false if seg>0
    if @last_shield_max.to_i<=0 && maxseg>0 && seg>0;start_shield_spawn(seg,maxseg)
    elsif @last_shield_segments && seg<@last_shield_segments.to_i;spawn_shield_ghosts(@last_shield_segments.to_i,seg,maxseg);start_shield_break if seg<=0;end
    spawning=update_shield_spawn
    (@shield_cells||[]).each{|r|r[:sprite].visible=false if spawning && r[:sprite]}
    update_shield_ghosts;breaking=apply_shield_break_visual
    group.each{|sp|sp.visible=false if seg<=0 && @shield_break_done && !breaking && sp}
    @last_shield_segments=seg;@last_shield_max=maxseg
  rescue => e;BSS064.log("Boss HUD shield warning: #{e.class}: #{e.message}");end

  def draw_fallback(hp,total,name,level,title,seg,maxseg)
    bmp=@fallback_bitmap;return if !bmp;bmp.clear
    label="#{(@cfg["showTitle"]!=false && !title.empty?) ? title+": " : ""}#{name}#{(@cfg["showLevel"]!=false && level) ? "  Lv. #{level}" : ""}"
    begin;bmp.font.size=18;bmp.font.bold=true;rescue;end;bmp.draw_text(10,2,WIDTH-20,24,label,1)
    x=34;y=31;w=WIDTH-68;h=8;bmp.fill_rect(x,y,w,h,Color.new(24,20,30,240));fill=[(w*hp.to_f/[total.to_f,1.0].max).round,w].min;bmp.fill_rect(x,y,fill,h,Color.new(220,70,100,255)) if fill>0
    if maxseg.to_i>0;count=[[maxseg.to_i,1].max,24].min;gap=1;sw=[((w-gap*(count-1))/count.to_f).floor,1].max;count.times{|i|bmp.fill_rect(x+i*(sw+gap),50,sw,6,i<seg.to_i ? Color.new(244,82,142,255) : Color.new(55,45,62,255))};end
  rescue;end

  def apply_faint_animation
    return if !@faint_started
    p=[[((now-@faint_started)/0.62),0.0].max,1.0].min;shake=p<0.20 ? (Math.sin(p*Math::PI*30.0)*(1.0-p/0.20)*4.0).round : 0;fade_p=p<0.22 ? 0.0 : [[(p-0.22)/0.78,0.0].max,1.0].min;dy=(-12.0*fade_p).round;alpha=(255*(1.0-fade_p)).round
    positions={@frame=>[@base_x,@base_y],@text=>[@base_x,@base_y],@hp=>[@base_x+HP_X,@base_y+HP_Y],@shield_bg=>[@base_x+SHIELD_X,@base_y+SHIELD_Y]}
    (@shield_cells||[]).each{|r|sp=r[:sprite];x,y,z=bss649_shield_cell_geometry(r[:index],@last_shield_max.to_i>0 ? @last_shield_max : [@shield_cells.length,1].max);positions[sp]=[x-sp.ox.to_f*(1.0-z)*0.0,y] if sp}
    positions.each do |sp,pos|;next if !sp;sp.opacity=[sp.opacity.to_i,alpha].min;sp.x=pos[0].to_i+shake;sp.y=pos[1].to_i+dy;end
    if @fallback;@fallback.opacity=alpha;@fallback.x=@base_x+shake;@fallback.y=@base_y+dy;end;@faint_complete=true if p>=1.0
  rescue;end
end

module BSS064BossRaidCaptureGate652
  def canRaidCapture?
    battle=@battle rescue nil
    return false if battle && battle.instance_variable_get(:@bss668_force_native_boss_faint)==true
    if battle && battle.respond_to?(:bss_boss_capture_enabled?) && battle.bss_boss_capture_enabled?
      return false if !battle.bss_boss_capture_target?(self)
    end
    super
  end
end

class Battle
  def bss_boss_capture_config
    raw=@bss_boss_capture_config
    raw=@bss_boss_config["capture"] if !raw.is_a?(Hash) && @bss_boss_config.is_a?(Hash)
    raw.is_a?(Hash) ? raw : {}
  rescue
    {}
  end

  def bss_boss_capture_enabled?
    return false if !bss_boss_enabled?
    return false if (trainerBattle? rescue false)
    bss_boss_capture_config["enabled"]==true
  rescue
    false
  end

  def bss_boss_capture_target?(battler)
    return false if !bss_boss_capture_enabled? || !battler
    boss=(bss_find_boss_battler_any rescue nil)
    boss ||= (bss_find_boss_battler rescue nil)
    boss && boss.equal?(battler)
  rescue
    false
  end
end

class Battle::Scene
  def bss_update_boss_hud(force=false)
    battle=@battle
    if !battle || !battle.respond_to?(:bss_boss_enabled?) || !battle.bss_boss_enabled?;bss_dispose_boss_hud(true) if @bss_boss_hud;@bss_boss_hud_retired_index=nil;return;end
    cfg=battle.respond_to?(:bss_boss_hud_config) ? battle.bss_boss_hud_config : {}
    if cfg["enabled"]==false;bss_dispose_boss_hud(true) if @bss_boss_hud;return;end
    battler=(battle.respond_to?(:bss_find_boss_battler_any) ? battle.bss_find_boss_battler_any : (battle.bss_find_boss_battler rescue nil))
    if !battler;bss_dispose_boss_hud(false) if @bss_boss_hud;return;end
    idx=(battler.index rescue -1).to_i;dead=((battler.fainted? rescue false) || (battler.hp rescue 0).to_i<=0)
    if dead && @bss_boss_hud_retired_index==idx && !@bss_boss_hud;return;end
    @bss_boss_hud_retired_index=nil if !dead
    if !@bss_boss_hud || (@bss_boss_hud.disposed? rescue true) || @bss_boss_hud_index!=idx
      bss_dispose_boss_hud(true);@bss_boss_hud=BSS064::BossHUD.new(@viewport,bss_scene_sprites,battle,battler,cfg);@bss_boss_hud_index=idx;force=true
    end
    @bss_boss_hud.update(battler,force) if @bss_boss_hud
    if dead && @bss_boss_hud && @bss_boss_hud.respond_to?(:faint_complete?) && @bss_boss_hud.faint_complete?
      @bss_boss_hud_retired_index=idx;bss_dispose_boss_hud(false)
    end
  rescue => e;BSS064.log("Boss HUD scene warning: #{e.class}: #{e.message}");end
end

# Legacy 0.6.49 pbEndBattle wrapper intentionally left uninstalled.
# Some projects alias Scene#pbEndBattle after BSS loads; combining that alias with
# a prepended super-chain can recurse forever. Cleanup is owned explicitly by BSS Launcher#ensure instead.
module BSS064BossEndBattleCleanup649
end

module BSS064NativeBossImmunityBattler649
  def bss649_native_immunity?(*ids)
    wanted=ids.flatten.map{|id|id.to_s.upcase}
    begin
      vals=(@pokemon.instance_variable_get(:@bss_native_boss_immunities) rescue nil)
      return true if vals.is_a?(Array) && wanted.any?{|id|vals.map{|x|x.to_s.upcase}.include?(id)}
    rescue
    end
    @battle && @battle.respond_to?(:bss_native_boss_immunity?) && @battle.bss_native_boss_immunity?(self,*ids)
  rescue
    false
  end
  def pbReducePP(move);return true if bss649_native_immunity?(:PPLOSS);super;end
  def pbCanInflictStatus?(newStatus,user,showMessages,move=nil,ignoreStatus=false)
    if !ignoreStatus && user && (user.index rescue -2)!=(self.index rescue -1) && bss649_native_immunity?(:ALLSTATUS,newStatus)
      @battle.pbDisplay(_INTL("¡{1} es inmune a ese estado!",pbThis)) if showMessages;return false
    end;super
  end
  def pbCanSynchronizeStatus?(newStatus,user);return false if bss649_native_immunity?(:ALLSTATUS,newStatus);super;end
  def pbCanSleepYawn?;return false if bss649_native_immunity?(:ALLSTATUS,:SLEEP);super;end
  def pbCanConfuse?(*args);if bss649_native_immunity?(:ALLSTATUS,:CONFUSION,:CONFUSED);@battle.pbDisplay(_INTL("¡{1} es inmune a la confusión!",pbThis)) if args[1];return false;end;super;end
  def pbCanAttract?(user,showMessages=true);if bss649_native_immunity?(:ALLSTATUS,:ATTRACT);@battle.pbDisplay(_INTL("¡{1} es inmune al enamoramiento!",pbThis)) if showMessages;return false;end;super;end
  def pbFlinch(user=nil);return false if bss649_native_immunity?(:FLINCH);super;end
  def pbCanLowerStatStage?(*args);if bss649_native_immunity?(:STATDROPS) && (!args[1] || (args[1].index rescue -2)!=(self.index rescue -1));@battle.pbDisplay(_INTL("¡{1} es inmune a las bajadas de estadísticas!",pbThis)) if args[3];return false;end;super;end
  def canChangeType?;return false if bss649_native_immunity?(:TYPECHANGE);super;end
  def takesIndirectDamage?(showMsg=false);if bss649_native_immunity?(:INDIRECT);@battle.pbDisplay(_INTL("¡{1} es inmune al daño indirecto!",pbThis)) if showMsg;return false;end;super;end
  def unlosableItem?(item);return true if item && bss649_native_immunity?(:ITEMREMOVAL);super;end
  def unstoppableAbility?(abil=nil);return true if bss649_native_immunity?(:ABILITYREMOVAL);super;end
end
begin
  Battle::Battler.prepend(BSS064NativeBossImmunityBattler649) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064NativeBossImmunityBattler649)
rescue => e;BSS064.log("Native Boss immunity battler warning: #{e.class}: #{e.message}");end

module BSS064NativeBossImmunityMove649
  def pbIsCritical?(user,target);return false if target && target.respond_to?(:bss649_native_immunity?) && target.bss649_native_immunity?(:CRITICALHIT);super;end
  def pbMoveFailedAromaVeil?(user,target,showMessage=true);if target && target.respond_to?(:bss649_native_immunity?) && target.bss649_native_immunity?(:DISABLE);@battle.pbDisplay(_INTL("¡{1} es inmune a ese efecto!",target.pbThis)) if showMessage;return true;end;super;end
end
begin
  Battle::Move.prepend(BSS064NativeBossImmunityMove649) if defined?(Battle::Move) && !Battle::Move.ancestors.include?(BSS064NativeBossImmunityMove649)
rescue => e;BSS064.log("Native Boss immunity move warning: #{e.class}: #{e.message}");end

module BSS064NativeBossOHKO649
  def pbFailsAgainstTarget?(user,target,show_message=true)
    if target && target.respond_to?(:bss649_native_immunity?) && target.bss649_native_immunity?(:OHKO);@battle.pbDisplay(_INTL("¡{1} es inmune a los movimientos de KO directo!",target.pbThis)) if show_message;return true;end
    super
  end
end
begin
  Battle::Move::OHKO.prepend(BSS064NativeBossOHKO649) if defined?(Battle::Move::OHKO) && !Battle::Move::OHKO.ancestors.include?(BSS064NativeBossOHKO649)
rescue => e;BSS064.log("Native Boss OHKO warning: #{e.class}: #{e.message}");end

module BSS064NativeBossEscape649
  def pbCanRun?(idxBattler)
    boss=bss_find_boss_battler_any rescue nil;boss ||= bss_find_boss_battler rescue nil
    return false if boss && respond_to?(:bss_native_boss_immunity?) && bss_native_boss_immunity?(boss,:ESCAPE)
    super
  end
end
begin
  Battle.prepend(BSS064NativeBossEscape649) if defined?(Battle) && !Battle.ancestors.include?(BSS064NativeBossEscape649)
rescue => e;BSS064.log("Native Boss escape warning: #{e.class}: #{e.message}");end


#===============================================================================
# BSS 0.6.49 - complete native immunity bridges
#===============================================================================
# The editor owns these attributes. DBK may be installed, but these checks do
# not rely on Pokemon#immunities, hp_level or any DBK-specific property.
module BSS064NativeBossImmunityBridge649
  def hasBossImmunity?(*ids)
    return true if respond_to?(:bss649_native_immunity?) && bss649_native_immunity?(*ids)
    return super if defined?(super)
    false
  rescue
    false
  end
end
begin
  Battle::Battler.prepend(BSS064NativeBossImmunityBridge649) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064NativeBossImmunityBridge649)
rescue => e
  BSS064.log("Native Boss immunity bridge warning: #{e.class}: #{e.message}")
end

# Transform must fail if either the user or target is protected. This is
# implemented here even without DBK; if DBK is present its own checks simply
# agree with the BSS-native result.
module BSS064NativeBossTransform649
  def pbMoveFailed?(user,targets)
    if user && user.respond_to?(:bss649_native_immunity?) && user.bss649_native_immunity?(:TRANSFORM)
      @battle.pbDisplay(_INTL("¡Pero falló!")) rescue nil
      return true
    end
    super
  end
  def pbFailsAgainstTarget?(user,target,show_message=true)
    if target && target.respond_to?(:bss649_native_immunity?) && target.bss649_native_immunity?(:TRANSFORM)
      @battle.pbDisplay(_INTL("¡{1} es inmune a ser copiado!",target.pbThis)) if show_message rescue nil
      return true
    end
    super
  end
end
begin
  k=Battle::Move::TransformUserIntoTarget if defined?(Battle::Move::TransformUserIntoTarget)
  k.prepend(BSS064NativeBossTransform649) if k && !k.ancestors.include?(BSS064NativeBossTransform649)
rescue => e
  BSS064.log("Native Boss transform immunity warning: #{e.class}: #{e.message}")
end

# Self-KO immunities mirror the behavior expected from boss battles but remain
# BSS-owned. Moves which only lose half HP are blocked only if that payment
# would KO the boss; moves whose defining effect is fainting are blocked outright.
module BSS064NativeBossHalfHP649
  def pbMoveFailed?(user,targets)
    if user && user.respond_to?(:bss649_native_immunity?) && user.bss649_native_immunity?(:SELFKO)
      total=[(user.totalhp rescue 1).to_i,1].max
      if (user.hp rescue total).to_i <= (total/2.0).ceil
        @battle.pbDisplay(_INTL("¡Pero falló!")) rescue nil
        return true
      end
    end
    super
  end
end
module BSS064NativeBossAlwaysSelfKO649
  def pbMoveFailed?(user,targets)
    if user && user.respond_to?(:bss649_native_immunity?) && user.bss649_native_immunity?(:SELFKO)
      @battle.pbDisplay(_INTL("¡Pero falló!")) rescue nil
      return true
    end
    super
  end
end
module BSS064NativeBossCurse649
  def pbMoveFailed?(user,targets)
    if user && user.respond_to?(:bss649_native_immunity?) && user.bss649_native_immunity?(:SELFKO) && (user.pbHasType?(:GHOST) rescue false)
      total=[(user.totalhp rescue 1).to_i,1].max
      if (user.hp rescue total).to_i <= (total/2.0).ceil
        @battle.pbDisplay(_INTL("¡Pero falló!")) rescue nil
        return true
      end
    end
    super
  end
end
begin
  %i[UserLosesHalfOfTotalHP UserLosesHalfOfTotalHPExplosive].each do |name|
    k=Battle::Move.const_get(name) rescue nil
    k.prepend(BSS064NativeBossHalfHP649) if k && !k.ancestors.include?(BSS064NativeBossHalfHP649)
  end
  %i[UserFaintsExplosive UserFaintsFixedDamageUserHP UserFaintsLowerTargetAtkSpAtk2 UserFaintsHealAndCureReplacement UserFaintsHealAndCureReplacementRestorePP].each do |name|
    k=Battle::Move.const_get(name) rescue nil
    k.prepend(BSS064NativeBossAlwaysSelfKO649) if k && !k.ancestors.include?(BSS064NativeBossAlwaysSelfKO649)
  end
  k=Battle::Move::CurseTargetOrLowerUserSpd1RaiseUserAtkDef1 if defined?(Battle::Move::CurseTargetOrLowerUserSpd1RaiseUserAtkDef1)
  k.prepend(BSS064NativeBossCurse649) if k && !k.ancestors.include?(BSS064NativeBossCurse649)
rescue => e
  BSS064.log("Native Boss self-KO immunity warning: #{e.class}: #{e.message}")
end


#===============================================================================
# BSS 0.6.53 - native Boss residual shield flow, recoil immunity and hard cleanup
#===============================================================================
class Battle
  def bss_boss_residual_config
    raw=@bss_boss_config.is_a?(Hash) && @bss_boss_config["mechanics"].is_a?(Hash) && @bss_boss_config["mechanics"]["residual"].is_a?(Hash) ? @bss_boss_config["mechanics"]["residual"] : {}
    {
      "enabled"=>raw["enabled"]==true,
      "trappingPercent"=>BSS064.clamp_float(raw["trappingPercent"],0,100,50),
      "trappingApplyEffect"=>raw["trappingApplyEffect"]!=false,
      "moveEffectPercent"=>BSS064.clamp_float(raw["moveEffectPercent"],0,100,50),
      "moveEffectApplyEffect"=>raw["moveEffectApplyEffect"]!=false,
      "statusPercent"=>BSS064.clamp_float(raw["statusPercent"],0,100,50),
      "statusApplyEffect"=>raw["statusApplyEffect"]!=false,
      "weatherPercent"=>BSS064.clamp_float(raw["weatherPercent"],0,100,50)
    }
  rescue
    {"enabled"=>false,"trappingApplyEffect"=>true,"moveEffectApplyEffect"=>true,"statusApplyEffect"=>true}
  end

  def bss_boss_residual_effect_allowed?(battler,kind)
    boss=bss_find_boss_battler_any rescue nil
    boss ||= bss_find_boss_battler rescue nil
    return true if !boss || !battler || !boss.equal?(battler)
    cfg=bss_boss_residual_config
    return true if cfg["enabled"]!=true
    key=case kind.to_sym
        when :trapping then "trappingApplyEffect"
        when :move_effect then "moveEffectApplyEffect"
        when :status then "statusApplyEffect"
        else nil
        end
    key ? cfg[key]!=false : true
  rescue
    true
  end

  # Shield changes are published to the scene immediately, before any message
  # window or EOR callback can postpone a regular scene update.
  def bss_damage_boss_shield(battler,count=1,apply_break_damage=true)
    return false if !bss_boss_shield_active?(battler)
    before=@bss_boss_shield_segments.to_i
    @bss_boss_shield_segments=[before-[count.to_i,1].max,0].max
    broke=@bss_boss_shield_segments<=0
    @bss_boss_shield_broken=true if broke
    begin;@scene.bss_update_boss_hud(false) if @scene && @scene.respond_to?(:bss_update_boss_hud);rescue;end
    if broke
      cfg=bss_boss_hud_config
      msg=bss_boss_message(cfg["shieldBreakMessage"],battler)
      pbDisplay(msg) if !msg.empty? && respond_to?(:pbDisplay)
      pct=cfg["shieldBreakDamagePercent"].to_f
      if apply_break_damage && pct>0 && battler && !(battler.fainted? rescue true)
        old=(battler.hp rescue 1).to_i
        extra=[((battler.totalhp rescue old).to_f*pct/100.0).round,1].max
        newhp=[old-extra,1].max
        battler.instance_variable_set(:@hp,newhp)
        begin;@scene.pbHPChanged(battler,old) if @scene && @scene.respond_to?(:pbHPChanged);rescue;end
      end
      begin;@scene.bss_update_boss_hud(false) if @scene && @scene.respond_to?(:bss_update_boss_hud);rescue;end
    end
    before!=@bss_boss_shield_segments.to_i
  rescue => e
    BSS064.log("Boss shield damage 0.6.53 warning: #{e.class}: #{e.message}")
    false
  end
end

# Residual/common damage is absorbed by a live shield and consumes a segment
# immediately. It never leaks into the Boss's base HP while a segment remains.
module BSS064BossResidualShield650
  def pbReduceHP(amt,*args)
    battle=@battle rescue nil
    boss=(battle.bss_find_boss_battler_any rescue nil) if battle && battle.respond_to?(:bss_find_boss_battler_any)
    boss ||= (battle.bss_find_boss_battler rescue nil) if battle && battle.respond_to?(:bss_find_boss_battler)
    if boss && boss.equal?(self) && battle
      context=(battle.bss_boss_residual_context rescue nil)
      shield=(battle.bss_boss_shield_active?(self) rescue false)
      if context && shield
        return 0 if battle.respond_to?(:bss_native_boss_immunity?) && battle.bss_native_boss_immunity?(self,:INDIRECT)
        mult=(battle.bss_boss_residual_multiplier_for(self) rescue 1.0).to_f
        return 0 if mult<=0.0
        battle.bss_damage_boss_shield(self,1,false) if battle.respond_to?(:bss_damage_boss_shield)
        return 0
      end
    end
    super
  end
end
begin
  Battle::Battler.prepend(BSS064BossResidualShield650) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossResidualShield650)
rescue => e
  BSS064.log("Boss residual shield 0.6.53 warning: #{e.class}: #{e.message}")
end

# Optional suppression of the persistent effect itself.
module BSS064BossNoTrapEffect650
  def pbEffectAgainstTarget(user,target)
    if target && @battle && @battle.respond_to?(:bss_boss_residual_effect_allowed?) && !@battle.bss_boss_residual_effect_allowed?(target,:trapping)
      return
    end
    super
  end
end
begin
  k=Battle::Move::BindTarget if defined?(Battle::Move::BindTarget)
  k.prepend(BSS064BossNoTrapEffect650) if k && !k.ancestors.include?(BSS064BossNoTrapEffect650)
rescue => e
  BSS064.log("Boss trapping suppression warning: #{e.class}: #{e.message}")
end

module BSS064BossNoPersistentMoveEffect650
  def pbEffectAgainstTarget(user,target)
    if target && @battle && @battle.respond_to?(:bss_boss_residual_effect_allowed?) && !@battle.bss_boss_residual_effect_allowed?(target,:move_effect)
      return
    end
    super
  end
end
begin
  %i[StartLeechSeedTarget StartDamageTargetEachTurnIfTargetAsleep StartSaltCureTarget DamageTargetAddLeechSeedToFoeSide CurseTargetOrLowerUserSpd1RaiseUserAtkDef1].each do |name|
    k=Battle::Move.const_get(name) rescue nil
    k.prepend(BSS064BossNoPersistentMoveEffect650) if k && !k.ancestors.include?(BSS064BossNoPersistentMoveEffect650)
  end
rescue => e
  BSS064.log("Boss persistent-effect suppression warning: #{e.class}: #{e.message}")
end

module BSS064BossNoStatusEffect650
  def pbCanInflictStatus?(newStatus,user,showMessages,move=nil,ignoreStatus=false)
    if !ignoreStatus && user && @battle && @battle.respond_to?(:bss_boss_residual_effect_allowed?) &&
       !@battle.bss_boss_residual_effect_allowed?(self,:status) && (user.index rescue -2)!=(self.index rescue -1)
      @battle.pbDisplay(_INTL("¡{1} ignora el estado!",pbThis)) if showMessages rescue nil
      return false
    end
    super
  end
end
begin
  Battle::Battler.prepend(BSS064BossNoStatusEffect650) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossNoStatusEffect650)
rescue => e
  BSS064.log("Boss status suppression warning: #{e.class}: #{e.message}")
end

# Recoil immunity is distinct from generic indirect damage. It only cancels the
# damage paid by a recoil-class move used by the Boss itself.
module BSS064NativeBossRecoil650
  def pbEffectAfterAllHits(user,target)
    immune=false
    if user
      begin;immune=user.bss649_native_immunity?(:RECOIL) if user.respond_to?(:bss649_native_immunity?);rescue;end
      begin
        vals=user.pokemon.instance_variable_get(:@bss_native_boss_immunities) if !immune && user.respond_to?(:pokemon) && user.pokemon
        immune=vals.is_a?(Array) && vals.any?{|x|x.to_s.upcase=="RECOIL"}
      rescue
      end
    end
    return if immune
    super
  end
end
module BSS064
  class << self
    def ensure_boss_recoil_hooks!
      begin
        base=Battle::Move::RecoilMove if defined?(Battle::Move::RecoilMove)
        if base
          # Hook the base class and every concrete recoil subclass currently
          # registered. Some DBK/plugin move classes override the base method,
          # so patching only RecoilMove is not sufficient in every project.
          targets=[base]
          begin
            Battle::Move.constants.each do |name|
              klass=Battle::Move.const_get(name) rescue nil
              next if !klass.is_a?(Class) || klass==base
              targets << klass if (klass <= base rescue false)
            end
          rescue
          end
          targets.uniq.each do |klass|
            klass.prepend(BSS064NativeBossRecoil650) if klass.ancestors.first != BSS064NativeBossRecoil650
          end
        end
      rescue => e
        log("Native Boss recoil immunity warning: #{e.class}: #{e.message}")
      end
      begin
        %i[UserLosesHalfOfTotalHP Struggle].each do |name|
          k=Battle::Move.const_get(name) rescue nil
          k.prepend(BSS064NativeBossUserDamageAfterHit650) if defined?(BSS064NativeBossUserDamageAfterHit650) && k && k.ancestors.first != BSS064NativeBossUserDamageAfterHit650
        end
        k=Battle::Move::UserLosesHalfOfTotalHPExplosive if defined?(Battle::Move::UserLosesHalfOfTotalHPExplosive)
        k.prepend(BSS064NativeBossUserDamageSelfKO650) if defined?(BSS064NativeBossUserDamageSelfKO650) && k && k.ancestors.first != BSS064NativeBossUserDamageSelfKO650
        %i[CrashDamageIfFails ConfuseTargetCrashDamageIfFails].each do |name|
          k=Battle::Move.const_get(name) rescue nil
          k.prepend(BSS064NativeBossCrashDamage650) if defined?(BSS064NativeBossCrashDamage650) && k && k.ancestors.first != BSS064NativeBossCrashDamage650
        end
      rescue => e
        log("Native Boss recoil/self-damage late hook warning: #{e.class}: #{e.message}")
      end
      true
    end
  end
end

begin;BSS064.ensure_boss_recoil_hooks!;rescue;end

# Do not let a generic Sprite hash keep references to BSS visual objects after
# the battle has ended. This is deliberately idempotent because Scene#pbEndBattle
# and Scene#dispose can both be called by different bases.
module BSS064BossSceneCleanup650
  def bss650_release_boss_visuals
    begin;bss_dispose_boss_hud(false) if respond_to?(:bss_dispose_boss_hud);rescue;end
    begin;bss_dispose_boss_aura if respond_to?(:bss_dispose_boss_aura);rescue;end
    if instance_variable_defined?(:@sprites) && @sprites.is_a?(Hash)
      @sprites.keys.grep(/^bss_/i).each do |key|
        obj=@sprites[key]
        begin;obj.dispose if obj && !pbDisposed?(obj);rescue;begin;obj.dispose if obj && obj.respond_to?(:dispose);rescue;end;end
        @sprites.delete(key) rescue nil
      end
    end
    @bss_boss_hud=nil;@bss_boss_hud_index=nil;@bss_boss_hud_retired_index=nil
    true
  rescue
    false
  end

  # Explicit launcher-owned teardown. This replaces the invalid Scene#dispose
  # call while still guaranteeing that a completed BSS test cannot leave the
  # previous battle frame layered over Scene_Map.
  def bss652_release_scene_graphics
    bss650_release_boss_visuals
    begin
      sprites=instance_variable_get(:@sprites)
      if sprites.is_a?(Hash)
        if defined?(pbDisposeSprites)
          pbDisposeSprites(sprites)
        else
          sprites.each_value do |obj|
            begin;obj.dispose if obj && obj.respond_to?(:dispose) && !(obj.disposed? rescue false);rescue;end
          end
        end
        sprites.clear rescue nil
      end
    rescue => e
      BSS064.log("Battle scene sprite teardown warning: #{e.class}: #{e.message}")
    end
    begin
      vp=instance_variable_get(:@viewport)
      vp.dispose if vp && vp.respond_to?(:dispose) && !(vp.disposed? rescue false)
    rescue
    end
    true
  rescue
    false
  end

  # Battle::Scene in Essentials/LBDS is not guaranteed to implement dispose.
  # Cleanup is called explicitly by the BSS launcher and never invents a
  # superclass dispose method.
end
begin
  Battle::Scene.prepend(BSS064BossSceneCleanup650) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064BossSceneCleanup650)
rescue => e
  BSS064.log("Boss hard scene cleanup warning: #{e.class}: #{e.message}")
end

# Recoil immunity also covers damaging attacks whose function code explicitly
# hurts the user (Steel Beam/Mind Blown) and crash damage. It does not erase HP
# costs from setup moves such as Substitute/Belly Drum; those are mechanics, not
# attack recoil.
module BSS064NativeBossUserDamageAfterHit650
  def pbEffectAfterAllHits(user,target)
    return if user && user.respond_to?(:bss649_native_immunity?) && user.bss649_native_immunity?(:RECOIL)
    super
  end
end
module BSS064NativeBossUserDamageSelfKO650
  def pbSelfKO(user)
    return if user && user.respond_to?(:bss649_native_immunity?) && user.bss649_native_immunity?(:RECOIL)
    super
  end
end
module BSS064NativeBossCrashDamage650
  def pbCrashDamage(user)
    return if user && user.respond_to?(:bss649_native_immunity?) && user.bss649_native_immunity?(:RECOIL)
    super
  end
end
begin
  %i[UserLosesHalfOfTotalHP Struggle].each do |name|
    k=Battle::Move.const_get(name) rescue nil
    k.prepend(BSS064NativeBossUserDamageAfterHit650) if k && !k.ancestors.include?(BSS064NativeBossUserDamageAfterHit650)
  end
  k=Battle::Move::UserLosesHalfOfTotalHPExplosive if defined?(Battle::Move::UserLosesHalfOfTotalHPExplosive)
  k.prepend(BSS064NativeBossUserDamageSelfKO650) if k && !k.ancestors.include?(BSS064NativeBossUserDamageSelfKO650)
  %i[CrashDamageIfFails ConfuseTargetCrashDamageIfFails].each do |name|
    k=Battle::Move.const_get(name) rescue nil
    k.prepend(BSS064NativeBossCrashDamage650) if k && !k.ancestors.include?(BSS064NativeBossCrashDamage650)
  end
rescue => e
  BSS064.log("Native Boss recoil/self-damage extension warning: #{e.class}: #{e.message}")
end


# v0.6.53 - final Boss databox ownership guard. Other UI plugins are free to
# toggle normal databoxes; the Boss' native box remains owned/hidden by BossHUD.
module BSS064BossDataboxOwnership652
  def bss_update_boss_hud(*args,&block)
    result=super
    begin
      hud=@bss_boss_hud
      hud.hide_native_databox if hud && hud.respond_to?(:hide_native_databox)
      bss652_hide_native_boss_databox if respond_to?(:bss652_hide_native_boss_databox)
    rescue
    end
    result
  end
end
begin
  Battle::Scene.prepend(BSS064BossDataboxOwnership652) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064BossDataboxOwnership652)
rescue => e
  BSS064.log("Boss databox ownership hook warning: #{e.class}: #{e.message}")
end


#===============================================================================
# BSS v0.6.53 - persistent Boss shield intro + capture lifecycle.
#===============================================================================
module BSS064BossShieldSpawnOnce653
  def start_shield_spawn(seg,maxseg)
    if @battle && @battle.instance_variable_get(:@bss653_boss_shield_intro_played)==true
      begin;dispose_aux(@shield_spawn_segments) if respond_to?(:dispose_aux);rescue;end
      @shield_spawn_started=nil
      return
    end
    @battle.instance_variable_set(:@bss653_boss_shield_intro_played,true) if @battle
    super
  end
end
begin
  if defined?(BSS064::BossHUD) && !BSS064::BossHUD.ancestors.include?(BSS064BossShieldSpawnOnce653)
    BSS064::BossHUD.prepend(BSS064BossShieldSpawnOnce653)
  end
rescue => e
  BSS064.log("Boss shield once install warning: #{e.class}: #{e.message}")
end

class Battle
  def bss653_prepare_boss_capture_visuals
    @bss653_boss_capture_visuals_locked=true
    self.bss_boss_aura_active=false if respond_to?(:bss_boss_aura_active=)
    if @scene
      begin;@scene.bss_dispose_boss_aura if @scene.respond_to?(:bss_dispose_boss_aura);rescue;end
      begin;@scene.bss_dispose_boss_hud(false) if @scene.respond_to?(:bss_dispose_boss_hud);rescue;end
    end
    true
  rescue => e
    BSS064.log("Boss capture visual cleanup warning: #{e.class}: #{e.message}")
    false
  end

  def bss653_any_poke_ball?
    return false if !defined?($bag) || !$bag || !defined?(GameData::Item)
    found=false
    GameData::Item.each do |item|
      next if !item || !(item.is_poke_ball? rescue false)
      if ($bag.quantity(item.id) rescue 0).to_i>0
        found=true;break
      end
    end
    found
  rescue
    false
  end

  def bss653_supply_emergency_ball
    return true if bss653_any_poke_ball?
    return false if !defined?($bag) || !$bag || !defined?(GameData::Item)
    ball=nil
    ball=:POKEBALL if (GameData::Item.exists?(:POKEBALL) rescue false)
    if !ball
      GameData::Item.each do |item|
        if item && (item.is_poke_ball? rescue false);ball=item.id;break;end
      end
    end
    return false if !ball
    ok=($bag.add(ball,1) rescue false)
    if ok
      name=(GameData::Item.get(ball).name rescue "Poké Ball")
      pbDisplayPaused(_INTL("No te quedaban Poké Balls. ¡Has recibido una {1} para intentar la captura!",name))
    end
    ok==true
  rescue => e
    BSS064.log("Emergency capture ball warning: #{e.class}: #{e.message}")
    false
  end
end

# While the capture scene owns the defeated Boss, normal Scene#update pumps must
# not recreate the aura/HUD that were intentionally removed for the Ball throw.
module BSS064BossCaptureSceneLock653
  def bss_update_boss_hud(*args,&block)
    if @battle && @battle.instance_variable_get(:@bss653_boss_capture_visuals_locked)==true
      begin;bss_dispose_boss_hud(false) if @bss_boss_hud && respond_to?(:bss_dispose_boss_hud);rescue;end
      return
    end
    super
  end

  def bss_update_boss_aura(*args,&block)
    if @battle && @battle.instance_variable_get(:@bss653_boss_capture_visuals_locked)==true
      begin;bss_dispose_boss_aura if respond_to?(:bss_dispose_boss_aura);rescue;end
      return
    end
    super
  end
end
begin
  Battle::Scene.prepend(BSS064BossCaptureSceneLock653) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064BossCaptureSceneLock653)
rescue => e
  BSS064.log("Boss capture scene lock install warning: #{e.class}: #{e.message}")
end

# BSS uses DBK's proven raid UI/animations, but owns the Boss-specific policy:
# emergency Ball, permanent aura teardown and the exact Boss-only target gate.
module BSS064BossRaidCaptureFlow653
  def pbRaidStyleCapture(target,chance=nil,fleeMsg=nil,bgm=nil)
    battle=@battle rescue nil
    return super if !battle || !battle.respond_to?(:bss_boss_capture_target?) || !battle.bss_boss_capture_target?(target)
    fainted_count=0
    battle.battlers.each do |b|
      next if !b || !b.opposes?(target) || b.hp>0
      fainted_count+=1
    end
    return if fainted_count>=battle.pbSideSize(0)
    if battle.pbAbleCount(target.index)<=1
      battle.raidCaptureMode=true if battle.respond_to?(:raidCaptureMode=)
      battle.field.initialize
      2.times{|i|battle.sides[i].initialize}
      battle.eachSameSideBattler do |b|
        b.pbInitEffects(false)
        pos=battle.positions[b.index] rescue nil
        pos.initialize if pos
      end
    end
    battle.bss653_prepare_boss_capture_visuals
    battle.pbPauseAndPlayBGM(bgm)
    battle.scene.pbHideDatabox(target.index)
    battle.scene.pbToggleDataboxes if battle.raidBattle?
    boss_label=battle.respond_to?(:bss655_boss_capture_label) ? battle.bss655_boss_capture_label(target) : (target.name rescue target.pbThis)
    battle.pbDisplayPaused(_INTL("¡{1} está débil!\n¡Es el momento de capturarlo!",boss_label))
    battle.scene.pbRevertBattlerStart
    battle.scene.pbPauseScene(0.5)
    loop do
      cmd=battle.pbShowCommands(_INTL("¿Quieres capturar a {1}?",boss_label),["Capturar","No capturar"],1)
      pbPlayDecisionSE
      if cmd!=0
        battle.scene.pbRevertBattlerEnd
        if battle.respond_to?(:bss654_decline_boss_capture)
          battle.bss654_decline_boss_capture(target,fleeMsg)
        else
          target.wild_flee(fleeMsg)
        end
        break
      end
      battle.sendToBoxes=1
      if $PokemonStorage.full?
        battle.scene.pbRevertBattlerEnd
        battle.pbDisplay(_INTL("¡No hay espacio en el PC!"))
        resolved=fleeMsg.to_s
        resolved=battle.bss655_boss_capture_message(resolved,target) if !resolved.empty? && battle.respond_to?(:bss655_boss_capture_message)
        target.wild_flee(resolved.empty? ? nil : resolved)
        break
      end
      # ZA-style safety: choosing Capture with an empty bag must never be
      # interpreted as rejecting the Boss and making it flee.
      if !battle.bss653_any_poke_ball? && !battle.bss653_supply_emergency_ball
        battle.pbDisplay(_INTL("No hay ninguna Poké Ball disponible."))
        next
      end
      ball=nil
      if PluginManager.installed?("[DBK] Enhanced Battle UI")
        ball=battle.scene.pbToggleBallInfo(pbDirectOpposing(true),true)
      else
        pbFadeOutIn do
          scene=PokemonBag_Scene.new
          screen=PokemonBagScreen.new(scene,$bag)
          ball=screen.pbChooseItemScreen(Proc.new{|item|GameData::Item.get(item).is_poke_ball?})
        end
      end
      # Cancel in the Ball list means "go back", not "Boss flees". Only the
      # explicit No capturar option ends the opportunity.
      if !ball
        battle.pbDisplay(_INTL("Elige una Poké Ball o selecciona \"No capturar\" para dejarlo ir."))
        next
      end
      $bag.remove(ball,1)
      if !chance.nil?
        battle.captureSuccess=(ball==:MASTERBALL || ($DEBUG && Input.press?(Input::CTRL)) || rand(100)<chance)
      end
      battle.scene.pbRevertBattlerEnd
      battle.instance_variable_set(:@bss653_boss_capture_in_progress,true)
      begin
        battle.pbThrowPokeBall(target.index,ball)
      ensure
        battle.instance_variable_set(:@bss653_boss_capture_in_progress,false)
      end
      if battle.poke_ball_failed
        resolved=fleeMsg.to_s
        resolved=battle.bss655_boss_capture_message(resolved,target) if !resolved.empty? && battle.respond_to?(:bss655_boss_capture_message)
        target.wild_flee(resolved.empty? ? nil : resolved)
      end
      break
    end
  rescue => e
    BSS064.log("Boss raid capture 0.6.53 warning: #{e.class}: #{e.message}")
    raise
  end
end
begin
  Battle::Battler.prepend(BSS064BossRaidCaptureFlow653) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossRaidCaptureFlow653)
rescue => e
  BSS064.log("Boss raid capture flow install warning: #{e.class}: #{e.message}")
end

# Store the Boss immediately after the successful Ball animation, before capture
# EXP/end-of-battle celebration. DBK's generic raid storage deliberately erases
# nicknames, so this path calls its preserved pre-raid store alias instead.
module BSS064BossCaptureStore653
  def pbStorePokemon(pkmn)
    if @bss653_store_boss_now && pkmn && pkmn.equal?(@bss653_store_boss_pokemon)
      begin;pkmn.makeUnmega if pkmn.respond_to?(:makeUnmega);rescue;end
      begin;pkmn.makeUnprimal if pkmn.respond_to?(:makeUnprimal);rescue;end
      begin;pkmn.makeUnUltra if pkmn.respond_to?(:ultra?) && pkmn.ultra? && pkmn.respond_to?(:makeUnUltra);rescue;end
      begin;pkmn.dynamax=false if pkmn.respond_to?(:dynamax?) && pkmn.dynamax? && pkmn.respond_to?(:dynamax=);rescue;end
      begin;pkmn.terastallized=false if pkmn.respond_to?(:tera?) && pkmn.tera? && pkmn.respond_to?(:terastallized=);rescue;end
      begin;pkmn.remove_instance_variable(:@bss_native_boss_immunities) if pkmn.instance_variable_defined?(:@bss_native_boss_immunities);rescue;end
      begin;pkmn.remove_instance_variable(:@bss_native_boss_hp_multiplier) if pkmn.instance_variable_defined?(:@bss_native_boss_hp_multiplier);rescue;end
      begin
        pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
        pkmn.hp=[[pkmn.hp.to_i,1].max,pkmn.totalhp].min if pkmn.respond_to?(:hp=) && pkmn.respond_to?(:totalhp)
      rescue;end
      # Raid Boss captures are deliberately sent to PC (the DBK/Raid behavior),
      # but BSS asks for the nickname first and never wipes it afterwards.
      if !pkmn.shadowPokemon? && $PokemonSystem.givenicknames==0 &&
         pbDisplayConfirm(_INTL("¿Quieres ponerle un mote a {1}?",pkmn.name))
        nickname=@scene.pbNameEntry(_INTL("¿Mote de {1}?",pkmn.speciesName),pkmn)
        pkmn.name=nickname
      end
      if Settings::HEAL_STORED_POKEMON
        old_ready=(pkmn.ready_to_evolve rescue nil)
        pkmn.heal
        pkmn.ready_to_evolve=old_ready if !old_ready.nil? && pkmn.respond_to?(:ready_to_evolve=)
      else
        pkmn.hp=1
      end
      stored_box=$PokemonStorage.pbStoreCaught(pkmn)
      box_name=@peer.pbBoxName(stored_box)
      pbDisplayPaused(_INTL("¡{1} se ha enviado a la Caja \"{2}\"!",pkmn.name,box_name))
      return stored_box
    end
    super
  end

  def pbThrowPokeBallSuccess(battler,pkmn,ball)
    active=@bss653_boss_capture_in_progress==true && respond_to?(:bss_boss_capture_target?) && bss_boss_capture_target?(battler)
    return super if !active
    pbDisplayBrief(_INTL("¡Ya está! ¡{1} atrapado!",pkmn.name))
    @scene.pbThrowSuccess
    # Capture metadata first; the Pokémon is fully valid by the time the nickname
    # prompt/storage UI opens.
    begin;pkmn.owner=Pokemon::Owner.new_from_trainer(pbPlayer) if GameData::Item.get(ball).is_snag_ball?;rescue;end
    begin;Battle::PokeBallEffects.onCatch(ball,self,pkmn);rescue;end
    pkmn.poke_ball=ball
    pkmn.makeUnmega if pkmn.mega?
    pkmn.makeUnprimal
    pkmn.update_shadow_moves if pkmn.shadowPokemon?
    pkmn.record_first_moves
    pkmn.forced_form=nil if MultipleForms.hasFunction?(pkmn.species,"getForm")
    @peer.pbOnLeavingBattle(self,pkmn,true,true)
    # Remove the capture Ball and every BSS Boss visual before opening PC/mote UI.
    @scene.pbHideCaptureBall(battler.index)
    bss653_prepare_boss_capture_visuals if respond_to?(:bss653_prepare_boss_capture_visuals)
    pbRemoveFromParty(battler.index,battler.pokemonIndex)
    @caughtPokemon.push(pkmn)
    @bss653_store_boss_now=true
    @bss653_store_boss_pokemon=pkmn
    begin
      pbRecordAndStoreCaughtPokemon
    ensure
      @bss653_store_boss_now=false
      @bss653_store_boss_pokemon=nil
    end
    # Capture EXP now runs after nickname + party/PC placement rather than before.
    if Settings::GAIN_EXP_FOR_CAPTURE
      battler.captured=true
      pbGainExp
      battler.captured=false
    end
    battler.pbReset
    @decision=(trainerBattle? ? Battle::Outcome::WIN : Battle::Outcome::CATCH) if pbAllFainted?(battler.index)
  end
end
begin
  Battle.prepend(BSS064BossCaptureStore653) if defined?(Battle) && !Battle.ancestors.include?(BSS064BossCaptureStore653)
rescue => e
  BSS064.log("Boss capture store install warning: #{e.class}: #{e.message}")
end

# Recoil safety is installed again at the end of BSS so projects that redefine
# RecoilMove in late DBK patches cannot bypass the Boss immunity.
begin
  BSS064.ensure_boss_recoil_hooks! if BSS064.respond_to?(:ensure_boss_recoil_hooks!)
rescue => e
  BSS064.log("Boss recoil final install warning: #{e.class}: #{e.message}")
end


#===============================================================================
# BSS v0.6.56 - Boss capture handoff policy and capture-animation compatibility.
#===============================================================================
class Battle
  # The New Animation Editor compatibility shipped in some projects references
  # spark_small even when that bitmap isn't present. Reuse the installed spark
  # asset instead of allowing every capture particle to raise ENOENT.
  def bss654_patch_capture_particle_fallbacks
    return true if !defined?(Battle::Scene::Animation::BallAnimationMixin)
    begin
      return true if defined?(pbResolveBitmap) && pbResolveBitmap("Graphics/Battle animations/spark_small")
    rescue
    end
    begin
      return false if defined?(pbResolveBitmap) && !pbResolveBitmap("Graphics/Battle animations/spark")
    rescue
    end
    mixin=Battle::Scene::Animation::BallAnimationMixin
    return false if !mixin.const_defined?(:BALL_BURST_CAPTURE_VARIANCES)
    table=mixin.const_get(:BALL_BURST_CAPTURE_VARIANCES)
    return false if !table.respond_to?(:each_value)
    table.each_value do |row|
      next if !row.is_a?(Array)
      row.map!{|value|value.is_a?(String) && value=="spark_small" ? "spark" : value}
    end
    true
  rescue => e
    BSS064.log("Capture particle fallback warning: #{e.class}: #{e.message}")
    false
  end

  # Display text for the capture finish must keep the Boss identity. pbThis(true)
  # deliberately injects wild-battle grammar ("salvaje"), which is wrong for a
  # Totem/Boss that already owns a Blueprint title/display label.
  def bss655_boss_capture_label(target)
    return "" if !target
    cfg=@bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    hud=cfg["hud"].is_a?(Hash) ? cfg["hud"] : {}
    name=(target.name rescue "").to_s
    display=hud["displayName"].to_s.strip
    if !display.empty?
      label=display.gsub("{1}",name).strip
      return label if !label.empty?
    end
    title=cfg["title"].to_s.strip
    return name if title.empty?
    "#{name} #{title}".strip
  rescue
    (target.name rescue "Pokémon").to_s
  end

  def bss655_boss_capture_message(template,target)
    label=bss655_boss_capture_label(target)
    template.to_s.gsub("{1}",label)
  rescue
    template.to_s
  end

  # Capture is a one-on-one finish. Any BSS SOS helpers still alive are fainted
  # through the real faint lifecycle before DBK resets the field for the capture.
  # Identity flags are preferred; in a scripted wild SOS battle the launcher
  # starts with exactly one foe, so any extra same-side live battler is also a
  # safe fallback SOS classification for old/reloaded runtime state.
  def bss654_retire_sos_for_boss_capture(target)
    return true if !target
    helpers=(@battlers rescue []).compact.select do |b|
      next false if b.equal?(target) || (b.fainted? rescue false) || (b.hp rescue 0).to_i<=0
      # A Raid-style Boss capture is a terminal one-Boss scene. Any other live
      # battler on the Boss' side (SOS or pre-placed helper) must finish its real
      # faint lifecycle before the capture prompt can begin. Do not depend on a
      # transient SOS index map here; slot relocation/custom scene code may have
      # changed indices by this point.
      !(b.opposes?(target) rescue true)
    end
    return true if helpers.empty?
    @bss654_retiring_capture_sos=true
    helpers.each do |b|
      begin
        b.hp=0 if b.respond_to?(:hp=)
        if b.respond_to?(:dx_pbFaint,true)
          b.send(:dx_pbFaint,true)
        else
          b.pbFaint(true)
        end
        # Some custom scene stacks rebuild dynamic sprites immediately after the
        # faint callback. Reassert the final hidden state only AFTER the normal
        # faint animation has completed, never instead of the animation.
        if @scene && (sprites=@scene.instance_variable_get(:@sprites) rescue nil).is_a?(Hash)
          idx=(b.index rescue -1).to_i
          ["pokemon_#{idx}","shadow_#{idx}","dataBox_#{idx}"].each do |key|
            sp=sprites[key];sp.visible=false if sp && sp.respond_to?(:visible=)
          end
        end
        pbClearChoice(b.index) if respond_to?(:pbClearChoice)
      rescue => e
        BSS064.log("Capture SOS retire #{(b.index rescue '?')} warning: #{e.class}: #{e.message}")
        begin;b.hp=0 if b.respond_to?(:hp=);rescue;end
      end
    end
    begin;@scene.bss652_layout_sos_databoxes if @scene && @scene.respond_to?(:bss652_layout_sos_databoxes);rescue;end
    begin;pbCalculatePriority(true) if respond_to?(:pbCalculatePriority);rescue;end
    true
  ensure
    @bss654_retiring_capture_sos=false
  end

  def bss654_decline_boss_capture(target,flee_msg=nil)
    cfg=bss_boss_capture_config rescue {}
    mode=cfg.is_a?(Hash) && cfg["declineMode"].to_s=="faint" ? "faint" : "flee"
    if mode=="faint"
      self.raidCaptureMode=false if respond_to?(:raidCaptureMode=)
      target.hp=0 if target && target.respond_to?(:hp=)
      if target && target.respond_to?(:dx_pbFaint,true)
        target.send(:dx_pbFaint,true)
      elsif target
        target.pbFaint(true)
      end
      return :faint
    end
    resolved=flee_msg.to_s
    resolved=bss655_boss_capture_message(resolved,target) if !resolved.empty?
    target.wild_flee(resolved.empty? ? nil : resolved) if target
    :flee
  rescue => e
    BSS064.log("Boss capture decline warning: #{e.class}: #{e.message}")
    begin
      resolved=flee_msg.to_s
      resolved=bss655_boss_capture_message(resolved,target) if !resolved.empty?
      target.wild_flee(resolved.empty? ? nil : resolved) if target
    rescue;end
    :flee
  end

  # Same emergency Ball rule as v0.6.53, now with a Blueprint-owned message.
  def bss653_supply_emergency_ball
    return true if bss653_any_poke_ball?
    return false if !defined?($bag) || !$bag || !defined?(GameData::Item)
    ball=nil
    ball=:POKEBALL if (GameData::Item.exists?(:POKEBALL) rescue false)
    if !ball
      GameData::Item.each do |item|
        if item && (item.is_poke_ball? rescue false);ball=item.id;break;end
      end
    end
    return false if !ball
    ok=($bag.add(ball,1) rescue false)
    if ok
      name=(GameData::Item.get(ball).name rescue "Poké Ball")
      cfg=bss_boss_capture_config rescue {}
      text=cfg.is_a?(Hash) ? cfg["emergencyBallMessage"].to_s : ""
      text="No te quedaban Poké Balls. ¡Has recibido una {1} para intentar la captura!" if text.strip.empty?
      pbDisplayPaused(text.gsub("{1}",name.to_s))
    end
    ok==true
  rescue => e
    BSS064.log("Emergency capture ball 0.6.56 warning: #{e.class}: #{e.message}")
    false
  end
end

# BSS v0.6.72 - capture music authority.
# DBK can legitimately pass nil when no raid capture BGM is set in its own rule.
# BSS has an independent Boss capture field, so recover it here instead of
# allowing the battle theme to continue through the capture decision screen.
module BSS064
  class << self
    def boss_capture_bgm_name(battle,passed=nil)
      candidates=[passed]
      begin
        raid=battle.respond_to?(:raidStyleCapture) ? battle.raidStyleCapture : nil
        candidates << raid[:capture_bgm] if raid.is_a?(Hash)
      rescue
      end
      begin
        cfg=battle.respond_to?(:bss_boss_capture_config) ? battle.bss_boss_capture_config : battle.instance_variable_get(:@bss_boss_capture_config)
        candidates << cfg["bgm"] if cfg.is_a?(Hash)
      rescue
      end
      begin
        env=battle.respond_to?(:bss_environment_config) ? battle.bss_environment_config : nil
        candidates << env["victoryBgm"] if env.is_a?(Hash)
      rescue
      end
      # Essentials defaults are the final fallback, preferring the current map.
      begin
        if defined?(GameData::MapMetadata) && defined?($game_map) && $game_map
          meta=GameData::MapMetadata.try_get($game_map.map_id)
          candidates << meta.wild_victory_BGM if meta && meta.respond_to?(:wild_victory_BGM)
        end
      rescue
      end
      begin
        if defined?(GameData::Metadata)
          meta=GameData::Metadata.get
          candidates << meta.wild_victory_BGM if meta && meta.respond_to?(:wild_victory_BGM)
        end
      rescue
      end
      candidates.each do |raw|
        name=respond_to?(:normalize_bgm_name) ? normalize_bgm_name(raw) : raw.to_s.strip
        return name if !name.empty?
      end
      ""
    rescue => e
      log("Boss capture BGM 0.6.72 warning: #{e.class}: #{e.message}") if respond_to?(:log)
      ""
    end
  end
end

module BSS064BossRaidCaptureFlow654
  def pbRaidStyleCapture(target,chance=nil,fleeMsg=nil,bgm=nil)
    battle=@battle rescue nil
    return super if !battle || !battle.respond_to?(:bss_boss_capture_target?) || !battle.bss_boss_capture_target?(target)
    fainted_count=0
    battle.battlers.each do |b|
      next if !b || !b.opposes?(target) || b.hp>0
      fainted_count+=1
    end
    return if fainted_count>=battle.pbSideSize(0)

    # The dominant Pokémon is the only foe that participates in the Raid-style
    # finish. Existing SOS allies use their real faint path first.
    battle.bss654_retire_sos_for_boss_capture(target) if battle.respond_to?(:bss654_retire_sos_for_boss_capture)
    if battle.pbAbleCount(target.index)<=1
      battle.raidCaptureMode=true if battle.respond_to?(:raidCaptureMode=)
      battle.field.initialize
      2.times{|i|battle.sides[i].initialize}
      battle.eachSameSideBattler do |b|
        b.pbInitEffects(false)
        pos=battle.positions[b.index] rescue nil
        pos.initialize if pos
      end
    end
    battle.bss654_patch_capture_particle_fallbacks if battle.respond_to?(:bss654_patch_capture_particle_fallbacks)
    battle.bss653_prepare_boss_capture_visuals
    # Resolve the capture-phase BGM again at the point where it is actually
    # needed. Some DBK/load-order paths call this method with bgm=nil even though
    # BSS already stored a capture BGM in the Boss blueprint. Never silently keep
    # the battle theme in that case: capture config -> BSS victory BGM -> map/
    # global wild-victory BGM are valid fallbacks.
    capture_bgm=BSS064.boss_capture_bgm_name(battle,bgm)
    battle.pbPauseAndPlayBGM(capture_bgm) if !capture_bgm.empty?
    battle.scene.pbHideDatabox(target.index)
    battle.scene.pbToggleDataboxes if battle.raidBattle?
    boss_label=battle.respond_to?(:bss655_boss_capture_label) ? battle.bss655_boss_capture_label(target) : (target.name rescue target.pbThis)
    battle.pbDisplayPaused(_INTL("¡{1} está débil!\n¡Es el momento de capturarlo!",boss_label))
    battle.scene.pbRevertBattlerStart
    battle.scene.pbPauseScene(0.5)
    loop do
      cmd=battle.pbShowCommands(_INTL("¿Quieres capturar a {1}?",boss_label),["Capturar","No capturar"],1)
      pbPlayDecisionSE
      if cmd!=0
        battle.scene.pbRevertBattlerEnd
        battle.bss654_decline_boss_capture(target,fleeMsg)
        break
      end
      battle.sendToBoxes=1
      if $PokemonStorage.full?
        battle.scene.pbRevertBattlerEnd
        battle.pbDisplay(_INTL("¡No hay espacio en el PC!"))
        resolved=fleeMsg.to_s
        resolved=battle.bss655_boss_capture_message(resolved,target) if !resolved.empty? && battle.respond_to?(:bss655_boss_capture_message)
        target.wild_flee(resolved.empty? ? nil : resolved)
        break
      end
      if !battle.bss653_any_poke_ball? && !battle.bss653_supply_emergency_ball
        battle.pbDisplay(_INTL("No hay ninguna Poké Ball disponible."))
        next
      end
      ball=nil
      if PluginManager.installed?("[DBK] Enhanced Battle UI")
        ball=battle.scene.pbToggleBallInfo(pbDirectOpposing(true),true)
      else
        pbFadeOutIn do
          scene=PokemonBag_Scene.new
          screen=PokemonBagScreen.new(scene,$bag)
          ball=screen.pbChooseItemScreen(Proc.new{|item|GameData::Item.get(item).is_poke_ball?})
        end
      end
      if !ball
        battle.pbDisplay(_INTL("Elige una Poké Ball o selecciona \"No capturar\" para terminar la oportunidad."))
        next
      end
      $bag.remove(ball,1)
      if !chance.nil?
        battle.captureSuccess=(ball==:MASTERBALL || ($DEBUG && Input.press?(Input::CTRL)) || rand(100)<chance)
      end
      battle.scene.pbRevertBattlerEnd
      battle.instance_variable_set(:@bss653_boss_capture_in_progress,true)
      begin
        battle.pbThrowPokeBall(target.index,ball)
      ensure
        battle.instance_variable_set(:@bss653_boss_capture_in_progress,false)
      end
      if battle.poke_ball_failed
        resolved=fleeMsg.to_s
        resolved=battle.bss655_boss_capture_message(resolved,target) if !resolved.empty? && battle.respond_to?(:bss655_boss_capture_message)
        target.wild_flee(resolved.empty? ? nil : resolved)
      end
      break
    end
  rescue => e
    BSS064.log("Boss raid capture 0.6.56 warning: #{e.class}: #{e.message}")
    raise
  end
end
begin
  Battle::Battler.prepend(BSS064BossRaidCaptureFlow654) if defined?(Battle::Battler) && Battle::Battler.ancestors.first != BSS064BossRaidCaptureFlow654
rescue => e
  BSS064.log("Boss raid capture 0.6.56 install warning: #{e.class}: #{e.message}")
end

# Re-run the final recoil installer with the concrete-subclass-safe 0.6.56 logic.
begin;BSS064.ensure_boss_recoil_hooks! if BSS064.respond_to?(:ensure_boss_recoil_hooks!);rescue => e;BSS064.log("Boss recoil 0.6.56 final install warning: #{e.class}: #{e.message}");end

#===============================================================================
# BSS v0.6.56 - Boss/SOS finish policy, recoil final gate, DBK databox titles
# and animated-sprite capture handoff.
#===============================================================================
class Battle
  # What live same-side helpers do after the Boss reaches 0 HP.
  #   faint    -> use their real faint lifecycle before the finish/capture.
  #   flee     -> use DBK/scene flee animation and remove them from the side.
  #   continue -> Boss stays defeated and battle continues against the helpers;
  #               a configured Boss capture is deferred until they are gone.
  def bss656_sos_on_boss_defeat
    cfg=@bss_boss_config.is_a?(Hash) ? @bss_boss_config : {}
    mode=cfg["sosOnBossDefeat"].to_s
    %w[faint flee continue].include?(mode) ? mode : "faint"
  rescue
    "faint"
  end

  def bss656_live_boss_helpers(target=nil)
    target ||= (bss_find_boss_battler_any rescue nil)
    return [] if !target
    (@battlers rescue []).compact.select do |b|
      next false if b.equal?(target)
      next false if (b.opposes?(target) rescue true)
      # IMPORTANT: Battler#fainted? only means HP <= 0. During a spread move a
      # helper can already be at 0 HP while its real pbFaint lifecycle (sprite
      # faint animation, databox exit, defeated bookkeeping, abilities, etc.) has
      # not run yet. Treat it as unresolved until pbInitEffects(false), called by
      # the normal faint/flee lifecycle, has marked @fainted = true.
      properly_finished=(b.instance_variable_get(:@fainted)==true rescue false)
      next false if properly_finished
      true
    end
  rescue
    []
  end

  def bss656_flee_boss_helper(battler)
    return false if !battler
    old_decision=(@decision rescue 0)
    # Mark the slot before the flee animation starts. Any DBK/global databox toggle
    # that runs during the flee/message pump will therefore be corrected immediately
    # instead of resurrecting the box for one frame after it slid away.
    begin
      bss665_mark_retired_helper_index(battler.index) if respond_to?(:bss665_mark_retired_helper_index)
    rescue
    end
    if battler.respond_to?(:wild_flee)
      battler.wild_flee(nil)
      # DBK wild_flee writes Battler @hp directly. Sync through the public
      # writer as well so the underlying party Pokémon is no longer counted
      # as able if this helper happened to be the last battler on the side.
      battler.hp=0 if battler.respond_to?(:hp=)
    else
      begin;@scene.pbBattlerFlee(battler,nil) if @scene && @scene.respond_to?(:pbBattlerFlee);rescue;end
      battler.hp=0 if battler.respond_to?(:hp=)
      battler.pbInitEffects(false) if battler.respond_to?(:pbInitEffects)
      pbClearChoice(battler.index) if respond_to?(:pbClearChoice)
      begin;pbRemoveFromParty(battler.index,battler.pokemonIndex) if respond_to?(:pbRemoveFromParty);rescue;end
    end
    # A helper fleeing must not turn a Boss battle into Outcome::FLEE simply
    # because it was the last remaining helper after the Boss had already fallen.
    @decision=old_decision if old_decision.to_i==0 && (@decision rescue 0).to_i!=0
    begin
      @scene.bss665_hide_retired_helper_databoxes if @scene && @scene.respond_to?(:bss665_hide_retired_helper_databoxes)
    rescue
    end
    true
  rescue => e
    BSS064.log("Boss helper flee 0.6.56 warning: #{e.class}: #{e.message}")
    false
  end

  def bss656_resolve_boss_helpers(target,mode=nil)
    mode=(mode || bss656_sos_on_boss_defeat).to_s
    helpers=bss656_live_boss_helpers(target)
    return true if helpers.empty? || mode=="continue"
    @bss656_resolving_boss_helpers=true
    helpers.each do |b|
      if mode=="flee"
        bss656_flee_boss_helper(b)
      else
        begin
          b.hp=0 if b.respond_to?(:hp=)
          # Use the public faint lifecycle so the project's current databox and
          # battler animations run normally. Do not hard-hide sprites afterward.
          b.pbFaint(true)
        rescue => e
          BSS064.log("Boss helper faint 0.6.56 warning: #{e.class}: #{e.message}")
          begin;b.hp=0 if b.respond_to?(:hp=);rescue;end
        end
      end
    end
    begin;@scene.bss652_layout_sos_databoxes if @scene && @scene.respond_to?(:bss652_layout_sos_databoxes);rescue;end
    begin;pbCalculatePriority(true) if respond_to?(:pbCalculatePriority);rescue;end
    true
  ensure
    @bss656_resolving_boss_helpers=false
  end

  def bss656_defer_boss_capture(target)
    @bss656_deferred_boss_capture=target
    true
  end

  def bss656_deferred_boss_capture?
    boss=@bss656_deferred_boss_capture
    !!(boss && bss_boss_capture_enabled? && bss_boss_capture_target?(boss))
  rescue
    false
  end

  def bss656_try_deferred_boss_capture
    return false if @bss656_deferred_capture_running
    boss=@bss656_deferred_boss_capture
    return false if !boss || !bss_boss_capture_enabled?
    return false if !bss656_live_boss_helpers(boss).empty?
    return false if (pbAllFainted?(0) rescue false)
    return false if (@decision rescue 0).to_i>0
    @bss656_deferred_capture_running=true
    @bss656_deferred_boss_capture=nil

    # DBK correctly fainted the Boss while helpers were still active. Restore it
    # only as the capture target after the last helper is gone; it is never made
    # targetable again during the continued combat.
    boss.hp=1 if boss.respond_to?(:hp=)
    boss.instance_variable_set(:@fainted,false)
    begin
      if @scene && @scene.respond_to?(:pbChangePokemon)
        pkmn=(boss.visiblePokemon rescue nil) || (boss.pokemon rescue nil)
        @scene.pbChangePokemon(boss,pkmn,0) if pkmn
      end
      @scene.bss656_restore_battler_animation_frames(@bss656_capture_animation_snapshot) if @scene && @scene.respond_to?(:bss656_restore_battler_animation_frames)
    rescue => e
      BSS064.log("Deferred Boss capture visual restore warning: #{e.class}: #{e.message}")
    end

    raid=respond_to?(:raidStyleCapture) ? raidStyleCapture : nil
    if raid.is_a?(Hash)
      boss.pbRaidStyleCapture(boss,raid[:capture_chance],raid[:flee_msg],raid[:capture_bgm])
    else
      boss.pbRaidStyleCapture(boss)
    end
    true
  rescue => e
    BSS064.log("Deferred Boss capture 0.6.56 warning: #{e.class}: #{e.message}")
    false
  ensure
    @bss656_deferred_capture_running=false
  end

  # Replaces the v0.6.56 one-size-fits-all helper retirement. Capture callers
  # can keep the same API while the Blueprint decides the actual finish policy.
  def bss654_retire_sos_for_boss_capture(target)
    mode=bss656_sos_on_boss_defeat
    return false if mode=="continue" && !bss656_live_boss_helpers(target).empty?
    bss656_resolve_boss_helpers(target,mode)
  end
end

# If a configured capture is set to continue through surviving SOS, suppress the
# immediate Raid capture hook. DBK then executes the Boss's normal faint path and
# BSS re-opens the capture only after the helper side is empty.
module BSS064BossDeferredCaptureGate656
  def canRaidCapture?
    battle=@battle rescue nil
    if battle && battle.respond_to?(:bss_boss_capture_target?) && battle.bss_boss_capture_target?(self) &&
       battle.respond_to?(:bss656_sos_on_boss_defeat) && battle.bss656_sos_on_boss_defeat=="continue"
      helpers=battle.bss656_live_boss_helpers(self) rescue []
      if helpers && !helpers.empty?
        battle.bss656_defer_boss_capture(self) if battle.respond_to?(:bss656_defer_boss_capture)
        return false
      end
    end
    super
  end
end
begin
  Battle::Battler.prepend(BSS064BossDeferredCaptureGate656) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossDeferredCaptureGate656)
rescue => e
  BSS064.log("Deferred capture gate install 0.6.56 warning: #{e.class}: #{e.message}")
end

# Judge is the safe common checkpoint for both a helper fainting and a helper
# fleeing. Resolve a deferred Boss capture before Essentials declares victory.
module BSS064BossDeferredJudge656
  def pbJudge(*args,&block)
    if respond_to?(:bss656_deferred_boss_capture?) && bss656_deferred_boss_capture?
      return if bss656_try_deferred_boss_capture
    end
    super
  end
end
begin
  Battle.prepend(BSS064BossDeferredJudge656) if defined?(Battle) && !Battle.ancestors.include?(BSS064BossDeferredJudge656)
rescue => e
  BSS064.log("Deferred capture judge install 0.6.56 warning: #{e.class}: #{e.message}")
end

# Non-capturable Bosses still obey the same SOS finish rule. Capturable Bosses
# are handled inside Raid capture (or deferred capture) to avoid double-fainting.
module BSS064BossPostFaintSOS656
  def pbFaint(showMessage=true)
    battle=@battle rescue nil
    is_boss=false
    capture=false
    if battle && battle.respond_to?(:bss_find_boss_battler_any)
      boss=(battle.bss_find_boss_battler_any rescue nil)
      is_boss=!!(boss && boss.equal?(self))
      capture=(battle.bss_boss_capture_enabled? rescue false) if is_boss
      if is_boss && battle.scene && battle.scene.respond_to?(:bss656_snapshot_battler_animation_frames)
        snap=battle.scene.bss656_snapshot_battler_animation_frames
        battle.instance_variable_set(:@bss656_capture_animation_snapshot,snap)
        battle.instance_variable_set(:@bss656_boss_faint_animation_snapshot,snap)
      end
    end
    ret=super
    if is_boss && !capture && battle && battle.respond_to?(:bss656_resolve_boss_helpers)
      battle.bss656_resolve_boss_helpers(self,battle.bss656_sos_on_boss_defeat)
    end
    if is_boss && battle && battle.scene && battle.scene.respond_to?(:bss656_restore_battler_animation_frames)
      begin
        snap=battle.instance_variable_get(:@bss656_boss_faint_animation_snapshot)
        battle.scene.bss656_restore_battler_animation_frames(snap,true) if snap
      rescue
      end
    end
    ret
  end
end
begin
  Battle::Battler.prepend(BSS064BossPostFaintSOS656) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossPostFaintSOS656)
rescue => e
  BSS064.log("Boss post-faint SOS install 0.6.56 warning: #{e.class}: #{e.message}")
end

# Final low-level recoil gate. This deliberately sits at pbReduceHP, after all
# DBK/LBDS/plugin move classes have been defined. RecoilMove and its concrete
# subclasses call pbReduceHP(amount, false); matching the battler's active move
# prevents a late plugin override from bypassing the higher-level recoil hook.
module BSS064BossRecoilHPGate656
  # v0.6.62: do not infer recoil from the Boss' selected move here.
  # Battle::Move#pbInflictHPDamage also calls pbReduceHP(..., false), so the old
  # heuristic treated ANY incoming player hit as recoil whenever the Boss had a
  # recoil move selected (e.g. Take Down), making the Boss appear immortal after
  # its shield broke. Recoil is already blocked at the exact source by the
  # RecoilMove/UserLosesHP/Crash hooks above, so this low-level gate must be a
  # transparent compatibility layer.
  def pbReduceHP(amt,*args)
    super
  end
end
begin
  Battle::Battler.prepend(BSS064BossRecoilHPGate656) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossRecoilHPGate656)
rescue => e
  BSS064.log("Boss recoil HP gate install 0.6.56 warning: #{e.class}: #{e.message}")
end

class Battle::Scene
  # Preserve frame phase across DBK's Raid capture preparation, which calls
  # pbChangePokemon and therefore rebuilds Animated Pokémon wrappers at frame 0.
  def bss656_snapshot_battler_animation_frames
    out={}
    return out if !@sprites.is_a?(Hash)
    @sprites.each do |key,sp|
      m=/\Apokemon_(\d+)\z/.match(key.to_s);next if !m || !sp
      wrapper=sp.instance_variable_get(:@_iconBitmap) rescue nil
      wrapper ||= sp.instance_variable_get(:@_iconbitmap) rescue nil
      next if !wrapper || !wrapper.respond_to?(:frame_idx)
      out[m[1].to_i]={
        :frame=>(wrapper.frame_idx rescue 0).to_i,
        :wrapper_id=>(wrapper.object_id rescue nil)
      }
    end
    out
  rescue
    {}
  end

  def bss656_restore_battler_animation_frames(snapshot,only_if_rebuilt=true)
    return false if !snapshot.is_a?(Hash) || !@sprites.is_a?(Hash)
    snapshot.each do |idx,state|
      sp=@sprites["pokemon_#{idx}"];next if !sp || (sp.disposed? rescue false)
      wrapper=sp.instance_variable_get(:@_iconBitmap) rescue nil
      wrapper ||= sp.instance_variable_get(:@_iconbitmap) rescue nil
      next if !wrapper || !wrapper.respond_to?(:to_frame)
      frame=state.is_a?(Hash) ? state[:frame].to_i : state.to_i
      old_wrapper_id=state.is_a?(Hash) ? state[:wrapper_id] : nil
      # Do not rewind a sprite that simply kept animating while the Boss faint
      # animation played. Restore only wrappers that were actually rebuilt
      # (setPokemonBitmap/pbChangePokemon), which is the source of the visible
      # frame-0 restart in Animated Pokémon/DBK.
      next if only_if_rebuilt && old_wrapper_id && (wrapper.object_id rescue nil)==old_wrapper_id
      begin
        wrapper.to_frame(frame)
        sp.bitmap=wrapper.bitmap if wrapper.respond_to?(:bitmap) && sp.respond_to?(:bitmap=)
        shadow=@sprites["shadow_#{idx}"]
        if shadow
          sw=(shadow.respond_to?(:iconBitmap) ? shadow.iconBitmap : (shadow.instance_variable_get(:@_iconBitmap) rescue nil))
          if sw && sw.respond_to?(:to_frame)
            sw.to_frame(frame)
            shadow.bitmap=sw.bitmap if sw.respond_to?(:bitmap) && shadow.respond_to?(:bitmap=)
          end
        end
      rescue
      end
    end
    true
  rescue
    false
  end
end

# Restore the captured animation phase immediately after DBK has rebuilt the
# Boss sprite and before the Raid-style prompt/ball sequence becomes visible.
module BSS064BossCaptureFrameRestore656
  def pbRaidStyleCapture(target,chance=nil,fleeMsg=nil,bgm=nil)
    battle=@battle rescue nil
    if battle && battle.respond_to?(:bss_boss_capture_target?) && battle.bss_boss_capture_target?(target)
      begin
        snap=battle.instance_variable_get(:@bss656_capture_animation_snapshot)
        battle.scene.bss656_restore_battler_animation_frames(snap) if snap && battle.scene && battle.scene.respond_to?(:bss656_restore_battler_animation_frames)
      rescue
      end
    end
    super
  end
end
begin
  Battle::Battler.prepend(BSS064BossCaptureFrameRestore656) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossCaptureFrameRestore656)
rescue => e
  BSS064.log("Boss capture frame restore install 0.6.56 warning: #{e.class}: #{e.message}")
end

# BSS v0.6.69 - DBK databox initialization authority
# -----------------------------------------------------------------------------
# DO NOT wrap/prepend PokemonDataBox#initializeDataBoxGraphic here. DBK aliases
# that method during plugin loading (dx_initializeDataBoxGraphic). If BSS is in
# the lookup chain when DBK creates the alias, DBK's fallback can point back to
# BSS and recurse forever: DBK -> BSS -> DBK -> ...
#
# Boss databox titles are applied after the databox already exists instead. This
# preserves DBK/Vanilla ownership of construction and remains safe for projects
# that load BSS before Deluxe Battle Kit.
module BSS064BossDataboxTitle656
  # 0.6.69 intentionally has NO initializeDataBoxGraphic override.
end

#===============================================================================
# BSS 0.6.57 - final shield segment direct-hit fallback
#===============================================================================
# A shield segment belongs to the successful damaging hit, not to whether some
# later HP-floor/plugin wrapper actually allowed @hp to decrease.  In particular,
# when the Boss is already sitting at the protected 1 HP floor, the old hook saw
# no HP delta and never consumed the final segment, leaving the Boss immortal.
#
# This wrapper runs outside the older 0.6.5x pbReduceHP hooks.  If a direct move
# hit entered through Battle::Move#pbInflictHPDamage while a barrier was active,
# it snapshots the segment count.  The older hook is allowed to handle normal
# hits first; only when that count did NOT change do we consume the segment here.
# Recoil, Life Orb, residual damage and other self/EOR damage have no direct
# damage target context and therefore cannot consume a segment through this path.
module BSS064BossShieldLastSegment657
  def pbReduceHP(amt,*args)
    battle=@battle rescue nil
    boss=nil
    begin
      boss=battle.bss_find_boss_battler_any if battle && battle.respond_to?(:bss_find_boss_battler_any)
      boss ||= battle.bss_find_boss_battler if battle && battle.respond_to?(:bss_find_boss_battler)
    rescue
      boss=nil
    end
    is_boss=!!(boss && boss.equal?(self))
    direct_target=nil
    shield_before=false
    segments_before=0
    begin
      direct_target=battle.bss_boss_direct_damage_target if battle && battle.respond_to?(:bss_boss_direct_damage_target)
      shield_before=is_boss && battle && battle.respond_to?(:bss_boss_shield_active?) && battle.bss_boss_shield_active?(self)
      segments_before=(battle.bss_boss_shield_segments rescue 0).to_i if shield_before
    rescue
      shield_before=false
    end
    direct_shield_hit=shield_before && direct_target && direct_target.equal?(self) && amt.is_a?(Numeric) && amt.to_f>0.0
    result=super
    if direct_shield_hit && battle && battle.respond_to?(:bss_damage_boss_shield)
      begin
        segments_after=(battle.bss_boss_shield_segments rescue segments_before).to_i
        # Normal hits were already counted by BSS064BossShieldBattlerCompat.
        # This is only the no-HP-delta fallback needed for the protected floor.
        if segments_before>0 && segments_after==segments_before && (battle.bss_boss_shield_active?(self) rescue false)
          battle.bss_damage_boss_shield(self,1)
        end
      rescue => e
        BSS064.log("Boss final shield segment 0.6.57 warning: #{e.class}: #{e.message}")
      end
    end
    result
  end
end
begin
  if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossShieldLastSegment657)
    Battle::Battler.prepend(BSS064BossShieldLastSegment657)
  end
rescue => e
  BSS064.log("Boss final shield segment hook 0.6.57 warning: #{e.class}: #{e.message}")
end


#===============================================================================
# BSS 0.6.58 - terminal Boss visual lock, shield-break stat stages, smoother
# helper flee handoff and deterministic battle -> overworld return fade.
#===============================================================================
class Battle
  BSS658_SHIELD_STATS = [:ATTACK,:DEFENSE,:SPECIAL_ATTACK,:SPECIAL_DEFENSE,:SPEED,:ACCURACY,:EVASION] unless const_defined?(:BSS658_SHIELD_STATS)

  def bss658_boss_terminal_visuals?
    @bss658_boss_terminal_visuals == true
  end

  def bss658_retire_boss_terminal_visuals(battler=nil)
    @bss658_boss_terminal_visuals=true
    self.bss_boss_aura_active=false if respond_to?(:bss_boss_aura_active=)
    begin
      @scene.bss_dispose_boss_aura if @scene && @scene.respond_to?(:bss_dispose_boss_aura)
    rescue
    end
    # Do NOT dispose the HUD here. Let the existing BossHUD run its own faint
    # slide/fade, but the scene gate below forbids creating a new HUD afterward.
    begin
      hud=@scene.instance_variable_get(:@bss_boss_hud) if @scene
      hud.begin_faint if hud && hud.respond_to?(:begin_faint)
    rescue
    end
    true
  rescue => e
    BSS064.log("Boss terminal visual lock 0.6.58 warning: #{e.class}: #{e.message}")
    false
  end

  def bss658_shield_break_stats_config
    raw=bss_boss_hud_config rescue {}
    raw=raw.is_a?(Hash) ? raw["shieldBreakStats"] : nil
    if !raw.is_a?(Hash)
      src=@bss_boss_config.is_a?(Hash) && @bss_boss_config["hud"].is_a?(Hash) ? @bss_boss_config["hud"]["shieldBreakStats"] : nil
      raw=src.is_a?(Hash) ? src : {}
    end
    norm=lambda do |value,min,max,default|
      n=value.nil? ? default : value.to_i
      [[n,min].max,max].min
    end
    modes=%w[none all specific]
    drop_mode=modes.include?(raw["dropMode"].to_s) ? raw["dropMode"].to_s : "none"
    raise_mode=modes.include?(raw["raiseMode"].to_s) ? raw["raiseMode"].to_s : "none"
    drop=raw["drop"].is_a?(Hash) ? raw["drop"] : {}
    rise=raw["raise"].is_a?(Hash) ? raw["raise"] : {}
    {
      "enabled"=>raw["enabled"]==true,
      "dropMode"=>drop_mode,"dropAll"=>norm.call(raw["dropAll"],1,6,1),
      "raiseMode"=>raise_mode,"raiseAll"=>norm.call(raw["raiseAll"],1,6,1),
      "drop"=>Hash[BSS658_SHIELD_STATS.map{|st|[st.to_s,norm.call(drop[st.to_s],0,6,0)]}],
      "raise"=>Hash[BSS658_SHIELD_STATS.map{|st|[st.to_s,norm.call(rise[st.to_s],0,6,0)]}]
    }
  rescue
    {"enabled"=>false,"dropMode"=>"none","raiseMode"=>"none","drop"=>{},"raise"=>{}}
  end

  def bss658_apply_exact_stat_delta(battler,stat,delta)
    return 0 if !battler || delta.to_i==0 || !battler.respond_to?(:stages)
    stages=battler.stages
    return 0 if !stages.is_a?(Hash)
    old=(stages[stat] || 0).to_i
    newv=[[old+delta.to_i,-6].max,6].min
    stages[stat]=newv
    newv-old
  rescue
    0
  end

  def bss658_apply_shield_break_stats(battler)
    return false if @bss658_shield_break_stats_applied
    cfg=bss658_shield_break_stats_config
    return false if cfg["enabled"]!=true || !battler || (battler.fainted? rescue true)
    @bss658_shield_break_stats_applied=true
    drops={};raises={}
    BSS658_SHIELD_STATS.each do |stat|
      if cfg["dropMode"]=="all"
        drops[stat]=cfg["dropAll"].to_i
      elsif cfg["dropMode"]=="specific"
        drops[stat]=(cfg["drop"][stat.to_s] || 0).to_i
      else
        drops[stat]=0
      end
      if cfg["raiseMode"]=="all"
        raises[stat]=cfg["raiseAll"].to_i
      elsif cfg["raiseMode"]=="specific"
        raises[stat]=(cfg["raise"][stat.to_s] || 0).to_i
      else
        raises[stat]=0
      end
    end
    changed_down=false;changed_up=false
    drops.each{|st,n|changed_down=true if n>0 && bss658_apply_exact_stat_delta(battler,st,-n)<0}
    if changed_down
      begin;pbCommonAnimation("StatDown",battler);rescue;end
      begin;pbDisplay(_INTL("¡Al romperse el escudo, bajaron las características de {1}!",battler.pbThis(true)));rescue;end
    end
    raises.each{|st,n|changed_up=true if n>0 && bss658_apply_exact_stat_delta(battler,st,n)>0}
    if changed_up
      begin;pbCommonAnimation("StatUp",battler);rescue;end
      begin;pbDisplay(_INTL("¡Al romperse el escudo, aumentaron las características de {1}!",battler.pbThis(true)));rescue;end
    end
    changed_down || changed_up
  rescue => e
    BSS064.log("Boss shield break stats 0.6.58 warning: #{e.class}: #{e.message}")
    false
  end

  unless method_defined?(:bss658_orig_damage_boss_shield)
    alias bss658_orig_damage_boss_shield bss_damage_boss_shield
  end
  def bss_damage_boss_shield(battler,count=1,*args)
    before=(respond_to?(:bss_boss_shield_segments) ? bss_boss_shield_segments.to_i : 0) rescue 0
    ret=bss658_orig_damage_boss_shield(battler,count,*args)
    after=(respond_to?(:bss_boss_shield_segments) ? bss_boss_shield_segments.to_i : 0) rescue before
    bss658_apply_shield_break_stats(battler) if before>0 && after<=0
    ret
  end
end

# Expose the normalized nested config through the existing HUD config API.
module BSS064BossShieldStatsConfig658
  def bss_boss_hud_config
    cfg=super
    cfg=cfg.is_a?(Hash) ? cfg : {}
    raw=@bss_boss_config.is_a?(Hash) && @bss_boss_config["hud"].is_a?(Hash) ? @bss_boss_config["hud"]["shieldBreakStats"] : nil
    cfg["shieldBreakStats"]=raw.is_a?(Hash) ? raw : {}
    cfg
  end
end
begin
  Battle.prepend(BSS064BossShieldStatsConfig658) if defined?(Battle) && !Battle.ancestors.include?(BSS064BossShieldStatsConfig658)
rescue => e
  BSS064.log("Boss shield stats config install 0.6.58 warning: #{e.class}: #{e.message}")
end

# Once the Boss reaches its terminal defeat/capture state, Aura and BossHUD are
# never allowed to be constructed again. The existing HUD may finish its own
# faint fade, which prevents both the one-frame reappearance and a new pop.
module BSS064BossTerminalSceneGate658
  def bss_update_boss_hud(*args,&block)
    if @battle && @battle.respond_to?(:bss658_boss_terminal_visuals?) && @battle.bss658_boss_terminal_visuals?
      hud=@bss_boss_hud rescue nil
      if hud && !(hud.disposed? rescue false)
        begin
          boss=(@battle.bss_find_boss_battler_any rescue nil)
          hud.begin_faint if hud.respond_to?(:begin_faint)
          hud.update(boss,false) if boss && hud.respond_to?(:update)
        rescue
        end
      end
      return hud
    end
    super
  end

  def bss_update_boss_aura(*args,&block)
    if @battle && @battle.respond_to?(:bss658_boss_terminal_visuals?) && @battle.bss658_boss_terminal_visuals?
      begin;@battle.bss_boss_aura_active=false if @battle.respond_to?(:bss_boss_aura_active=);rescue;end
      begin;bss_dispose_boss_aura if respond_to?(:bss_dispose_boss_aura);rescue;end
      return nil
    end
    super
  end
end
begin
  Battle::Scene.prepend(BSS064BossTerminalSceneGate658) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064BossTerminalSceneGate658)
rescue => e
  BSS064.log("Boss terminal scene gate install 0.6.58 warning: #{e.class}: #{e.message}")
end

module BSS064BossTerminalFaint658
  def pbFaint(showMessage=true)
    battle=@battle rescue nil
    if battle && battle.respond_to?(:bss_find_boss_battler_any)
      boss=(battle.bss_find_boss_battler_any rescue nil)
      if boss && boss.equal?(self) && (hp rescue 0).to_i<=0
        battle.bss658_retire_boss_terminal_visuals(self) if battle.respond_to?(:bss658_retire_boss_terminal_visuals)
      end
    end
    super
  end
end
begin
  Battle::Battler.prepend(BSS064BossTerminalFaint658) if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossTerminalFaint658)
rescue => e
  BSS064.log("Boss terminal faint install 0.6.58 warning: #{e.class}: #{e.message}")
end

# DBK's helper flee begins at full linear velocity. For automatic Boss cleanup
# this looked like a teleport into motion, especially while databoxes reflowed.
# Keep DBK's state semantics, but replace only the scene animation while BSS is
# retiring an SOS: start with a real ease-in and let the databox disappear from
# its CURRENT on-screen position.
module BSS064SmoothBossHelperFleeScene658
  def pbBattlerFlee(battler,msg=nil)
    marked=@battle && @battle.instance_variable_get(:@bss658_smooth_helper_flee_target)
    return super unless marked && battler && marked.equal?(battler)
    @briefMessage=false if instance_variable_defined?(:@briefMessage)
    idx=battler.index
    bat=@sprites["pokemon_#{idx}"] rescue nil
    shadow=@sprites["shadow_#{idx}"] rescue nil
    box=@sprites["dataBox_#{idx}"] rescue nil
    begin;pbAnimateSubstitute(battler,:break);rescue;end
    if box
      begin
        # DataBoxDisappear animates from the box's current screen position by
        # itself. Do not rewrite @spriteX/@spriteY here: those are the native/style
        # home coordinates, and mutating them is what let a retired SOS box snap
        # back on-screen after its flee slide.
        box.bss654_clear_layout_override if box.respond_to?(:bss654_clear_layout_override)
      rescue
      end
    end
    data_anim=Battle::Scene::Animation::DataBoxDisappear.new(@sprites,@viewport,idx) rescue nil
    if bat
      sx=(bat.x rescue 0).to_f;sy=(bat.y rescue 0).to_f;sop=(bat.opacity rescue 255).to_i
      shop=(shadow.opacity rescue 255).to_i if shadow
      dir=(battler.opposes?(0) rescue true) ? 1.0 : -1.0
      distance=[Graphics.width.to_f*0.82,240.0].max
      begin;pbSEPlay("Battle flee");rescue;end
      frames=30
      (0..frames).each do |f|
        p=f.to_f/frames.to_f
        ease=p*p
        fade=[[((p-0.16)/0.84),0.0].max,1.0].min
        bat.x=(sx+(dir*distance*ease)).round if bat.respond_to?(:x=)
        bat.y=sy.round if bat.respond_to?(:y=)
        bat.opacity=(sop*(1.0-fade)).round if bat.respond_to?(:opacity=)
        if shadow
          shadow.opacity=(shop.to_i*(1.0-[[p/0.52,0.0].max,1.0].min)).round if shadow.respond_to?(:opacity=)
          shadow.visible=false if p>=0.52 && shadow.respond_to?(:visible=)
        end
        begin;data_anim.update if data_anim;rescue;end
        pbUpdate
      end
      bat.visible=false if bat.respond_to?(:visible=)
      shadow.visible=false if shadow && shadow.respond_to?(:visible=)
    else
      10.times do
        begin;data_anim.update if data_anim;rescue;end
        pbUpdate
      end
    end
    begin;data_anim.dispose if data_anim;rescue;end
    begin
      # DataBoxDisappear already ended at visible=false. Reassert only that final
      # visibility bit before any message/menu pump can toggle all databoxes again.
      box.visible=false if box && box.respond_to?(:visible=)
    rescue
    end
    if msg.is_a?(String)
      @battle.pbDisplayPaused(_INTL("#{msg}",battler.pbThis))
    else
      @battle.pbDisplayPaused(_INTL("¡{1} ha huido!",battler.pbThis))
    end
  rescue => e
    BSS064.log("Boss helper smooth flee 0.6.58 warning: #{e.class}: #{e.message}")
    super
  end
end
begin
  Battle::Scene.prepend(BSS064SmoothBossHelperFleeScene658) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064SmoothBossHelperFleeScene658)
rescue => e
  BSS064.log("Boss helper smooth flee scene install 0.6.58 warning: #{e.class}: #{e.message}")
end

module BSS064SmoothBossHelperFleeState658
  def bss656_flee_boss_helper(battler)
    @bss658_smooth_helper_flee_target=battler
    super
  ensure
    @bss658_smooth_helper_flee_target=nil
  end
end
begin
  Battle.prepend(BSS064SmoothBossHelperFleeState658) if defined?(Battle) && !Battle.ancestors.include?(BSS064SmoothBossHelperFleeState658)
rescue => e
  BSS064.log("Boss helper smooth flee state install 0.6.58 warning: #{e.class}: #{e.message}")
end


#===============================================================================
# BSS v0.6.59 - seamless Boss -> SOS terminal handoff.
#
# [ZBOX] Faint Delay adds a fixed 0.25 s wait after Scene#pbFaintBattler. That
# pause is useful in ordinary faints, but becomes a visible dead beat when BSS
# immediately retires surviving SOS after the Boss. Bypass only that outer
# delay for this one terminal transition; the project's real faint animation,
# cry, databox exit and callbacks still run through the alias captured by ZBOX.
#===============================================================================
module BSS064BossTerminalNoFaintGap659
  def pbFaintBattler(battler,*args,&block)
    battle=@battle rescue nil
    skip_gap=false
    if battle && battler && battle.respond_to?(:bss_find_boss_battler_any)
      boss=(battle.bss_find_boss_battler_any rescue nil)
      if boss && boss.equal?(battler) && battle.respond_to?(:bss656_sos_on_boss_defeat) &&
         battle.respond_to?(:bss656_live_boss_helpers)
        mode=(battle.bss656_sos_on_boss_defeat rescue "faint").to_s
        helpers=(battle.bss656_live_boss_helpers(battler) rescue [])
        skip_gap=(mode!="continue" && helpers && !helpers.empty?)
      end
    end
    if skip_gap && respond_to?(:_ZBOX_FD_orig_pbFaintBattler,true)
      return send(:_ZBOX_FD_orig_pbFaintBattler,battler,*args,&block)
    end
    super
  rescue => e
    BSS064.log("Boss terminal faint handoff 0.6.60 warning: #{e.class}: #{e.message}")
    raise
  end
end
# v0.6.68: DO NOT prepend Scene#pbFaintBattler.
# Carnek Project Settings aliases this lifecycle method after BSS loads. A prepended
# wrapper here becomes the target of that alias and its `super` resolves back into
# the alias, producing an infinite recursion even in ordinary non-BSS wild battles.
# Boss/SOS terminal behavior is handled at Battle/Battler level instead.
begin
  # Intentionally left uninstalled.
rescue => e
  BSS064.log("Boss terminal faint handoff install 0.6.68 warning: #{e.class}: #{e.message}")
end

#===============================================================================
# BSS v0.6.60 - player faint / battle decision guard.
#
# Some late battle plugins decide a BSS battle from the currently active field
# instead of the full player party. If one active Pokémon faints while a reserve
# is still able, that can turn into an immediate LOSE/DRAW before Essentials gets
# to its normal replacement prompt. BSS only cancels that false terminal result;
# a real party wipe is untouched.
#===============================================================================
module BSS064PlayerReserveJudgeGuard660
  def pbJudge(*args,&block)
    ret=super
    begin
      is_bss=respond_to?(:bss_blueprint) && !bss_blueprint.nil?
      if is_bss && [Battle::Outcome::LOSE,Battle::Outcome::DRAW].include?(@decision)
        party=pbParty(0) rescue nil
        has_reserve=party.is_a?(Array) && party.any? { |pkmn| pkmn && (pkmn.able? rescue false) }
        if has_reserve
          BSS064.log("Player reserve judge guard 0.6.60: cancelled false terminal decision #{@decision}")
          @decision=0
        end
      end
    rescue => e
      BSS064.log("Player reserve judge guard 0.6.60 warning: #{e.class}: #{e.message}")
    end
    ret
  end
end
begin
  if defined?(Battle) && !Battle.ancestors.include?(BSS064PlayerReserveJudgeGuard660)
    Battle.prepend(BSS064PlayerReserveJudgeGuard660)
  end
rescue => e
  BSS064.log("Player reserve judge guard install 0.6.60 warning: #{e.class}: #{e.message}")
end


#===============================================================================
# BSS v0.6.61 - shield hits must always pass their configured HP damage through.
#===============================================================================
# DBK's Wild Boss Attributes wraps Battle::Battler#pbReduceHP and may divide the
# incoming amount by Pokemon#hp_boost.  After BSS has already reduced a move to
# the configured shield pass-through percentage, that second scaling can round a
# legitimate 1 HP (or other small) hit down to 0. v0.6.57 deliberately allowed
# the shield segment to break even when HP did not move, which exposed the bug as
# "the shield breaks but the Boss takes no damage".
#
# For BSS-owned Boss shields, a direct damaging move is already fully calculated
# by Battle::Move (including shieldDamagePercent). Preserve that final amount
# through DBK's boosted-HP wrapper. As a last compatibility fallback, if another
# plugin still swallows the HP loss while the segment was consumed, apply the
# already-calculated amount once and publish the normal HP-change state.
module BSS064BossShieldDamagePassThrough661
  def pbReduceHP(amt,*args)
    battle=@battle rescue nil
    boss=nil
    begin
      boss=battle.bss_find_boss_battler_any if battle && battle.respond_to?(:bss_find_boss_battler_any)
      boss ||= battle.bss_find_boss_battler if battle && battle.respond_to?(:bss_find_boss_battler)
    rescue
      boss=nil
    end
    direct_target=nil
    shield_before=false
    segments_before=0
    begin
      direct_target=battle.bss_boss_direct_damage_target if battle && battle.respond_to?(:bss_boss_direct_damage_target)
      shield_before=!!(boss && boss.equal?(self) && battle && battle.respond_to?(:bss_boss_shield_active?) && battle.bss_boss_shield_active?(self))
      segments_before=(battle.bss_boss_shield_segments rescue 0).to_i if shield_before
    rescue
      shield_before=false
    end
    direct_shield_hit=shield_before && direct_target && direct_target.equal?(self) && amt.is_a?(Numeric) && amt.to_f>0.0
    oldhp=(@hp rescue 0).to_i

    # DBK uses this flag internally to avoid a second HP-boost division. BSS has
    # already calculated the shield-reduced move damage, so dividing it again is
    # incorrect here. Do this only for the exact BSS Boss + direct shield hit.
    had_stop=instance_variable_defined?(:@stopBoostedHPScaling)
    old_stop=(instance_variable_get(:@stopBoostedHPScaling) rescue nil)
    instance_variable_set(:@stopBoostedHPScaling,true) if direct_shield_hit

    result=super
    hp_after=(@hp rescue oldhp).to_i

    if direct_shield_hit && hp_after>=oldhp && oldhp>0
      begin
        segments_after=(battle.bss_boss_shield_segments rescue segments_before).to_i
        segment_consumed=(segments_before>0 && segments_after<segments_before)
        # Only compensate a hit which BSS actually accepted as a shield hit. This
        # avoids turning unrelated blocked/self/residual damage into forced HP loss.
        if segment_consumed
          forced=[amt.to_f.round,1].max
          forced=oldhp if forced>oldhp
          newhp=[oldhp-forced,0].max
          if newhp<oldhp
            self.hp=newhp
            begin
              if defined?(PBDebug)
                PBDebug.log("[BSS 0.6.61] Shield pass-through restored #{forced} HP damage (#{oldhp} -> #{newhp})")
              end
            rescue
            end
            anim=(args.length>=1 ? args[0] : true)
            register_damage=(args.length>=2 ? args[1] : true)
            any_anim=(args.length>=3 ? args[2] : true)
            begin
              battle.scene.pbHPChanged(self,oldhp,anim) if any_anim && battle && battle.respond_to?(:scene) && battle.scene
            rescue
            end
            if register_damage
              begin
                @droppedBelowHalfHP=true if @hp < @totalhp/2 && oldhp >= @totalhp/2
                @droppedBelowThirdHP=true if @hp < @totalhp/3 && oldhp >= @totalhp/3
                @tookDamageThisRound=true
                @tookMoveDamageThisRound=true
              rescue
              end
            end
            result=forced
          end
        end
      rescue => e
        BSS064.log("Boss shield HP pass-through 0.6.61 warning: #{e.class}: #{e.message}")
      end
    end
    result
  ensure
    if defined?(direct_shield_hit) && direct_shield_hit
      begin
        # DBK treats stopBoostedHPScaling as a one-shot flag and clears it at
        # the end of pbReduceHP. Do not resurrect a stale true value here; that
        # value belongs only to the hit that just finished.
        instance_variable_set(:@stopBoostedHPScaling,false) if instance_variable_defined?(:@stopBoostedHPScaling)
      rescue
      end
    end
  end
end
begin
  if defined?(Battle::Battler) && !Battle::Battler.ancestors.include?(BSS064BossShieldDamagePassThrough661)
    Battle::Battler.prepend(BSS064BossShieldDamagePassThrough661)
  end
rescue => e
  BSS064.log("Boss shield HP pass-through install 0.6.61 warning: #{e.class}: #{e.message}")
end


#===============================================================================
# BSS v0.6.62 - post-shield direct damage / recoil-context correction.
#===============================================================================
# The fix is intentionally source-level rather than another outer pbReduceHP
# wrapper: the old 0.6.56 low-level recoil heuristic could return before every
# newer wrapper in the chain. Recoil is now decided only by the move method that
# actually pays recoil, while normal incoming damage always reaches Essentials.


#===============================================================================
# BSS v0.6.64 - final hot-reload cleanup / recoil gate neutrality.
#===============================================================================
module BSS064BossRecoilHPGate656
  def pbReduceHP(amt,*args)
    super
  end
end

module BSS064BossBattleStartState663
  def pbStartBattle(*args,&block)
    begin
      # Never carry BSS per-hit compatibility flags into a new battle. They are
      # meaningful only while one damage call is on the stack.
      (@battlers rescue []).compact.each do |b|
        begin;b.stopBoostedHPScaling=false if b.respond_to?(:stopBoostedHPScaling=);rescue;end
        begin;b.instance_variable_set(:@stopBoostedHPScaling,false) if b.instance_variable_defined?(:@stopBoostedHPScaling);rescue;end
      end
      @bss_boss_direct_damage_target=nil
      @bss_boss_direct_damage_depth=0
      @bss_boss_residual_context=nil
    rescue
    end
    super
  end
end
begin
  if defined?(Battle) && !Battle.ancestors.include?(BSS064BossBattleStartState663)
    Battle.prepend(BSS064BossBattleStartState663)
  end
rescue => e
  BSS064.log("Boss battle-start state install 0.6.64 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end


#===============================================================================
# BSS v0.6.64 - native faint lifecycle + native databox authority.
#===============================================================================
# v0.6.59 tried to remove a 0.25 s third-party faint pause by jumping directly
# into an aliased Scene#pbFaintBattler implementation. That bypass is unsafe in a
# heavily patched battle scene: it can skip the CURRENT faint chain after plugin
# reloads and an exception inside it used to be swallowed by the launcher,
# leaving the last battle frame over the overworld. Faints are lifecycle-critical,
# so BSS no longer shortcuts them at all.
module BSS064BossTerminalNoFaintGap659
  def pbFaintBattler(battler,*args,&block)
    super
  end
end

# Essentials already judges defeat from the entire party, not just the active
# battler. The old recovery guard could overwrite a terminal decision produced by
# another battle system after `super`. Leave decision ownership to the real battle
# engine; deferred Boss capture remains handled by its dedicated earlier layer.
module BSS064PlayerReserveJudgeGuard660
  def pbJudge(*args,&block)
    super
  end
end

# When the custom Boss Bar is OFF, a normal PokemonDataBox belongs entirely to
# Essentials/DBK/Enhanced UI. BSS may still rebuild its graphic when SOS expands
# sideSize (that is required for singles -> doubles), but it must not reorder,
# pin or repeatedly rewrite x/y/z afterward. That preserves DataBoxAppear,
# DataBoxDisappear and custom databox styles exactly as the active UI defines them.
module BSS064NativeBossDataboxAuthority664
  def bss652_layout_sos_databoxes(*args,&block)
    battle=@battle rescue nil
    sprites=@sprites rescue nil
    if battle && sprites && respond_to?(:bss653_boss_hud_enabled?) && !bss653_boss_hud_enabled?
      sprites.each do |key,box|
        next if !key.to_s.start_with?("dataBox_") || !box
        begin;box.bss654_clear_layout_override if box.respond_to?(:bss654_clear_layout_override);rescue;end
      end
      return true
    end
    super
  end
end
begin
  if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064NativeBossDataboxAuthority664)
    Battle::Scene.prepend(BSS064NativeBossDataboxAuthority664)
  end
rescue => e
  BSS064.log("Native Boss databox authority install 0.6.64 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end


#===============================================================================
# BSS v0.6.65 - native intro timing, terminal SOS databox ownership and
# source-faithful Boss faint/EXP handoff.
#===============================================================================
# The active project uses Essentials' DataBoxAppear/DataBoxDisappear animations,
# DBK's databox styles/toggles and optional EBDX/Enhanced UI layers.  BSS must
# therefore own only the extra Boss/SOS state; it must not pre-empt the native
# entrance/exit lifecycle.

# Keep the Boss encounter text in the same position as Essentials' first wild
# message, but do not allow the custom Boss HUD to be created while that message
# is still being presented. This fixes the Boss Bar appearing before
# "... te ataca" and, more importantly, stops it from hiding/repositioning the
# native opponent databox before DataBoxAppear has finished its own slide.
module BSS064BossOpeningReloadSafe663
  def pbStartBattleSendOut(*args,&block)
    begin
      @bss665_boss_hud_ready=false if respond_to?(:bss_boss_enabled?) && bss_boss_enabled?
      @bss_boss_intro_pending=respond_to?(:bss_boss_enabled?) && bss_boss_enabled? &&
                              respond_to?(:bss_boss_encounter_message) && !bss_boss_encounter_message.to_s.empty?
    rescue
      @bss_boss_intro_pending=false
    end
    ret=super
    # A Boss with no custom encounter message still becomes HUD-ready only once
    # the complete native send-out path has returned.
    begin
      @bss665_boss_hud_ready=true if respond_to?(:bss_boss_enabled?) && bss_boss_enabled?
    rescue
    end
    ret
  ensure
    @bss_boss_intro_pending=false
  end

  def pbDisplayPaused(msg,&block)
    if @bss_boss_intro_pending
      begin
        custom=respond_to?(:bss_boss_encounter_message) ? bss_boss_encounter_message.to_s : ""
        if !custom.empty?
          @bss_boss_intro_pending=false
          # Keep the HUD locked for the ENTIRE message pump. Scene#pbUpdate runs
          # while the text window is open, which was the exact early-pop window.
          ret=super(custom,&block)
          @bss_boss_intro_shown=true
          @bss665_boss_hud_ready=true
          return ret
        end
      rescue => e
        BSS064.log("Boss intro timing 0.6.65 warning: #{e.class}: #{e.message}") if defined?(BSS064)
      end
    end
    super
  end

  def pbCommandPhase(*args,&block)
    begin
      @bss665_boss_hud_ready=true if respond_to?(:bss_boss_enabled?) && bss_boss_enabled?
      bss669_apply_boss_databox_title if respond_to?(:bss669_apply_boss_databox_title)
      bss_apply_boss_opening if respond_to?(:bss_apply_boss_opening)
    rescue => e
      BSS064.log("Boss opening command hook 0.6.65 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    super
  end
end

module BSS064BossHUDNativeIntroGate665
  def bss_update_boss_hud(*args,&block)
    battle=@battle rescue nil
    if battle && battle.respond_to?(:bss_boss_enabled?) && battle.bss_boss_enabled? &&
       battle.instance_variable_get(:@bss665_boss_hud_ready)!=true
      # Do not create, hide, restore or otherwise touch PokemonDataBox while the
      # native intro is active. There should normally be no HUD yet; returning an
      # existing one is only a hot-reload safety fallback.
      return (@bss_boss_hud rescue nil)
    end
    super
  end
end
begin
  if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064BossHUDNativeIntroGate665)
    Battle::Scene.prepend(BSS064BossHUDNativeIntroGate665)
  end
rescue => e
  BSS064.log("Boss HUD intro gate install 0.6.65 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

class Battle
  # Databoxes that belonged to helpers which have completed a terminal
  # faint/flee. They stay in Scene#@sprites because Essentials/DBK may reuse that
  # slot later, so dispose is wrong. Remembering the index lets BSS prevent a
  # later global pbToggleDataboxes from resurrecting the already-retired box.
  def bss665_retired_helper_indices
    @bss665_retired_helper_indices ||= {}
  end

  def bss665_mark_retired_helper_index(idx)
    return false if idx.nil? || idx.to_i<0
    bss665_retired_helper_indices[idx.to_i]=true
    true
  end

  def bss665_unmark_retired_helper_index(idx)
    bss665_retired_helper_indices.delete(idx.to_i) if @bss665_retired_helper_indices
    true
  end

  def bss665_helper_retired_index?(idx)
    !!(bss665_retired_helper_indices[idx.to_i])
  rescue
    false
  end
end

module BSS064BossTerminalHelperState665
  def pbStartBattle(*args,&block)
    @bss665_retired_helper_indices={}
    @bss665_skip_duplicate_terminal_exp=false
    @bss665_boss_hud_ready=false
    super
  end

  def bss656_resolve_boss_helpers(target,mode=nil)
    actual=(mode || (respond_to?(:bss656_sos_on_boss_defeat) ? bss656_sos_on_boss_defeat : "faint")).to_s
    indexes=[]
    if actual!="continue" && respond_to?(:bss656_live_boss_helpers)
      begin;indexes=bss656_live_boss_helpers(target).map{|b|(b.index rescue -1).to_i}.select{|i|i>=0};rescue;indexes=[];end
    end
    ret=super
    if actual!="continue"
      indexes.each{|idx|bss665_mark_retired_helper_index(idx)}
      begin
        @scene.bss665_hide_retired_helper_databoxes if @scene && @scene.respond_to?(:bss665_hide_retired_helper_databoxes)
      rescue
      end
    end
    ret
  end

  # v0.6.65 explicitly awards the terminal Boss EXP immediately after the real
  # native faint lifecycle. Battle::Battler#pbUseMove will normally call
  # pbGainExp once more when it unwinds; skip that one duplicate call so victory
  # BGM/messages don't play twice. Participants were already consumed by the
  # first call.
  def pbGainExp(*args,&block)
    # v0.6.68: never consume the native EXP checkpoint. Earlier builds granted
    # EXP from inside the capture prompt and then skipped the engine's real call;
    # that could leave participants/state incomplete and produce no visible EXP.
    super
  end
end
begin
  if defined?(Battle) && !Battle.ancestors.include?(BSS064BossTerminalHelperState665)
    Battle.prepend(BSS064BossTerminalHelperState665)
  end
rescue => e
  BSS064.log("Boss terminal helper state install 0.6.65 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

class Battle::Scene
  def bss665_hide_retired_helper_databoxes
    battle=@battle rescue nil
    return false if !battle || !battle.respond_to?(:bss665_retired_helper_indices)
    sprites=@sprites rescue nil
    return false if !sprites.is_a?(Hash)
    battle.bss665_retired_helper_indices.keys.each do |idx|
      box=sprites["dataBox_#{idx}"]
      next if !box || (box.disposed? rescue false)
      begin;box.bss654_clear_layout_override if box.respond_to?(:bss654_clear_layout_override);rescue;end
      begin;box.visible=false if box.respond_to?(:visible=);rescue;end
    end
    true
  rescue => e
    BSS064.log("Retired helper databox hide 0.6.65 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end
end

module BSS064BossTerminalHelperScene665
  def pbToggleDataboxes(*args,&block)
    ret=super
    bss665_hide_retired_helper_databoxes if respond_to?(:bss665_hide_retired_helper_databoxes)
    ret
  end

  def pbHideDatabox(*args,&block)
    ret=super
    bss665_hide_retired_helper_databoxes if respond_to?(:bss665_hide_retired_helper_databoxes)
    ret
  end

  def bss_pbPrepNewBattler(idx,*args,&block)
    begin
      @battle.bss665_unmark_retired_helper_index(idx) if @battle && @battle.respond_to?(:bss665_unmark_retired_helper_index)
    rescue
    end
    ret=super
    bss665_hide_retired_helper_databoxes if respond_to?(:bss665_hide_retired_helper_databoxes)
    ret
  end
end
begin
  if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064BossTerminalHelperScene665)
    Battle::Scene.prepend(BSS064BossTerminalHelperScene665)
  end
rescue => e
  BSS064.log("Retired helper scene install 0.6.65 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

class Battle
  # "No capturar -> Debilitar" must look and behave like an actual wild faint:
  # message, current project faint animation + DataBoxDisappear, defeated state,
  # then the standard EXP/victory pass. Calling DBK's preserved dx_pbFaint is
  # intentional here: it bypasses only the Raid-capture re-entry wrapper, not the
  # Essentials faint lifecycle that dx_pbFaint points to.
  def bss654_decline_boss_capture(target,flee_msg=nil)
    cfg=bss_boss_capture_config rescue {}
    mode=cfg.is_a?(Hash) && cfg["declineMode"].to_s=="faint" ? "faint" : "flee"
    if mode=="faint"
      self.raidCaptureMode=false if respond_to?(:raidCaptureMode=)
      # Declining capture does not undo the victory: the Boss is being defeated
      # normally, so the regular BSS victory celebration remains enabled. Reset
      # the old 0.6.71 compatibility flag in case scripts were hot-reloaded.
      @bss671_skip_boss_decline_victory_celebration=false
      # Helper flee/faint callbacks must not leave a terminal decision behind
      # before the actual Boss faint is processed.
      @decision=0 if (@decision rescue 0).to_i!=0
      if target
        target.hp=0 if target.respond_to?(:hp=)
        # Run the CURRENT Battler#pbFaint chain (Essentials + project faint visuals
        # + DBK), but suppress only the raid-capture re-entry for this nested faint.
        # EXP is deliberately NOT awarded here: the surrounding move/EOR/capture
        # lifecycle calls Battle#pbGainExp at its normal native checkpoint.
        @bss668_force_native_boss_faint=true
        begin
          target.pbFaint(true)
        ensure
          @bss668_force_native_boss_faint=false
        end
      end
      begin
        @scene.bss665_hide_retired_helper_databoxes if @scene && @scene.respond_to?(:bss665_hide_retired_helper_databoxes)
      rescue
      end
      return :faint
    end
    resolved=flee_msg.to_s
    resolved=bss655_boss_capture_message(resolved,target) if !resolved.empty? && respond_to?(:bss655_boss_capture_message)
    target.wild_flee(resolved.empty? ? nil : resolved) if target
    # Choosing "No capturar -> Dejar escapar" is still the authored victory over
    # the Boss. wild_flee ends the target lifecycle without necessarily reaching
    # Scene#pbWildBattleSuccess, so trigger the BSS victory sequence explicitly.
    begin
      @scene.bss_custom_victory_sequence if @scene && @scene.respond_to?(:bss_custom_victory_sequence)
    rescue => e
      BSS064.log("Boss flee victory celebration warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    :flee
  rescue => e
    BSS064.log("Boss capture decline 0.6.73 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    begin
      resolved=flee_msg.to_s
      resolved=bss655_boss_capture_message(resolved,target) if !resolved.empty? && respond_to?(:bss655_boss_capture_message)
      target.wild_flee(resolved.empty? ? nil : resolved) if target
      @scene.bss_custom_victory_sequence if @scene && @scene.respond_to?(:bss_custom_victory_sequence)
    rescue
    end
    :flee
  end
end

#===============================================================================
# BSS v0.6.67 - native databox authority, BossHUD native-style entrance and
# field-aware battle-end safety.
#===============================================================================
# 0.6.66 tried to reimplement DataBoxAppear itself. That was the wrong layer:
# Essentials/DBK already own the complete animation (including custom vertical
# styles), and manually writing PokemonDataBox coordinates bypassed that process.
# Normal databoxes now go straight through the project's real DataBoxAppear.
# Only the native databox of a Boss that actually uses BSS BossHUD is suppressed.
module BSS067NativeDataboxAuthority
  def createProcesses
    box=nil
    battler=nil
    battle=nil
    begin
      box=@sprites["dataBox_#{@idxBox}"]
      battler=(box.battler rescue nil) if box
      battle=(battler.instance_variable_get(:@battle) rescue nil) if battler
      if box && battler && battle && battle.respond_to?(:bss_blueprint) && battle.bss_blueprint &&
         battle.respond_to?(:bss_boss_capture_target?)
        boss=(battle.bss_find_boss_battler_any rescue nil) if battle.respond_to?(:bss_find_boss_battler_any)
        boss ||= (battle.bss_find_boss_battler rescue nil) if battle.respond_to?(:bss_find_boss_battler)
        cfg=(battle.bss_boss_hud_config rescue {}) if battle.respond_to?(:bss_boss_hud_config)
        if boss && boss.equal?(battler) && cfg.is_a?(Hash) && cfg["enabled"]!=false
          box.visible=false if box.respond_to?(:visible=)
          return
        end
      end
    rescue => e
      BSS064.log("Databox authority 0.6.72 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end

    # Vanilla PokemonDataBox is deliberately handled here instead of relying on
    # whichever DataBoxAppear alias DBK/project scripts happened to capture. In
    # affected projects that alias chain makes the box visible only after it has
    # already reached @spriteX/@spriteY, so the native slide technically runs but
    # is never seen. This is the stock lateral entrance: player from the right,
    # foe from the left. DBK/custom styles remain fully owned by their own code.
    begin
      style=(box.instance_variable_get(:@style) rescue nil) if box
      if box && battler && style.nil?
        dir=(battler.index rescue @idxBox).to_i.even? ? 1 : -1
        obj=addSprite(box)
        obj.setDelta(0,dir*Graphics.width/2,0)
        obj.setVisible(0,true)
        obj.moveDelta(0,8,-dir*Graphics.width/2,0)
        return
      end
    rescue => e
      BSS064.log("Vanilla databox slide 0.6.72 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end
    super
  end
end

module BSS064
  class << self
    def install_boss_databox_appear_gate!
      # v0.6.73: DataBox appearance is no longer Boss-only. The final global hook
      # owns Pop/Slide/Fade for ordinary, Boss and SOS battleboxes alike, while
      # preserving the special BossHUD suppression inside that same authority.
      return install_general_databox_animation_hooks! if respond_to?(:install_general_databox_animation_hooks!)
      false
    rescue => e
      log("Global databox animation gate install 0.6.73 warning: #{e.class}: #{e.message}")
      false
    end
  end
end

# v0.6.68: do not prepend DataBoxAppear during plugin compilation. DBK aliases
# DataBoxAppear#createProcesses in its own plugin; installing BSS before that alias
# can poison the native opponent slide chain. The gate is installed lazily from
# configure_native_boss(), after every plugin has finished loading.
begin
  # Intentionally deferred.
rescue => e
  BSS064.log("Databox authority deferred install 0.6.68 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# The custom BossHUD is not a PokemonDataBox, so it needs its own entrance.
# Animate only the BSS-owned HUD sprites and keep @base_y as the FINAL position.
# The previous build accumulated offsets into @base_y, which could snap/pop.
module BSS067BossHUDEntrance
  def initialize(*args,&block)
    @bss067_entry_frame=(Graphics.frame_count rescue 0)
    @bss067_entry_frames=12
    @bss067_last_entry_dy=0
    super
  end

  def update(*args,&block)
    # Undo the previous visual-only offset before the normal HUD update. This
    # keeps every internal HP/shield/faint coordinate calculation source-faithful.
    old=@bss067_last_entry_dy.to_i
    if old!=0 && instance_variable_defined?(:@sprites) && @sprites.respond_to?(:each)
      @sprites.each do |sp|
        next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:y=)
        sp.y=(sp.y rescue 0).to_i-old
      end
    end
    @bss067_last_entry_dy=0
    ret=super
    start=@bss067_entry_frame
    return ret if start.nil?
    frames=[@bss067_entry_frames.to_i,1].max
    elapsed=(Graphics.frame_count rescue start).to_i-start.to_i
    p=[[elapsed.to_f/frames.to_f,0.0].max,1.0].min
    ease=1.0-(1.0-p)**3
    dy=(-((self.class.const_defined?(:HEIGHT) ? self.class::HEIGHT : 104)+20)*(1.0-ease)).round
    if dy!=0 && instance_variable_defined?(:@sprites) && @sprites.respond_to?(:each)
      @sprites.each do |sp|
        next if !sp || (sp.disposed? rescue true) || !sp.respond_to?(:y=)
        sp.y=(sp.y rescue 0).to_i+dy
      end
      @bss067_last_entry_dy=dy
    end
    if p>=1.0
      @bss067_entry_frame=nil
      @bss067_last_entry_dy=0
    end
    ret
  rescue => e
    BSS064.log("BossHUD entrance 0.6.67 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    super
  end
end
begin
  if defined?(BSS064::BossHUD) && !BSS064::BossHUD.ancestors.include?(BSS067BossHUDEntrance)
    BSS064::BossHUD.prepend(BSS067BossHUDEntrance)
  end
rescue => e
  BSS064.log("BossHUD entrance install 0.6.67 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# Dynamic SOS battles can have a live battler whose party bookkeeping is being
# expanded/reused in the same frame. Essentials' pbJudge is correct and remains
# authoritative; this only makes pbAllFainted? refuse a terminal result while a
# real, living battler still exists on that side. This fixes "one faint ends the
# whole battle" without replacing the native switch/faint/victory lifecycle.
module BSS067FieldAwareAllFainted
  def pbAllFainted?(idxBattler=0)
    result=super
    return result unless result
    return result unless respond_to?(:bss_blueprint) && bss_blueprint
    # Raid-style Boss capture intentionally removes/rebuilds party state while
    # the capture target may still exist visually at 1 HP. Do not interfere.
    begin
      return result if instance_variable_get(:@bss653_boss_capture_in_progress)==true
      return result if respond_to?(:raidCaptureMode) && raidCaptureMode
    rescue
    end
    side=(opposes?(idxBattler) rescue ((idxBattler.to_i & 1)==1)) ? 1 : 0
    alive=false
    begin
      alive=(@battlers||[]).compact.any? do |b|
        next false if ((b.index rescue -1).to_i & 1)!=side
        next false if (b.hp rescue 0).to_i<=0
        next false if (b.instance_variable_get(:@fainted)==true rescue false)
        true
      end
    rescue
      alive=false
    end
    if alive
      BSS064.log("Field-aware all-fainted 0.6.67: kept side #{side} active despite party count 0") if defined?(BSS064)
      return false
    end
    result
  end
end
begin
  if defined?(Battle) && !Battle.ancestors.include?(BSS067FieldAwareAllFainted)
    Battle.prepend(BSS067FieldAwareAllFainted)
  end
rescue => e
  BSS064.log("Field-aware all-fainted install 0.6.67 warning: #{e.class}: #{e.message}") if defined?(BSS064)
end


#===============================================================================
# BSS v0.6.68 - native faint/databox chain repair.
#===============================================================================
# Important load-order rule:
# - Never prepend Battle::Scene#pbFaintBattler from BSS. Carnek Project Settings
#   aliases this method later and must capture the project's own scene lifecycle.
# - Boss-only DataBoxAppear suppression is installed lazily by configure_native_boss
#   after DBK/Enhanced UI have finished defining/aliasing their animation methods.
# This intentionally restores ordinary grass battles to the exact project-native
# faint and opponent databox behavior.
