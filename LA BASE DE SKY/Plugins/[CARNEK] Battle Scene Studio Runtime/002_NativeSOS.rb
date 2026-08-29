#===============================================================================
# Battle Scene Studio 0.6.37 - Native SOS (Phase 1)
# BSS-owned SOS. Runtime assignments come only from sos_global.json.
# Dynamic battler creation follows the v21/DBK SOS lifecycle supplied by the
# user. Growth slots are created by the project's real pbCreateBattler constructor
# before AI/special-actions/bookkeeping are exposed; existing fainted active slots
# are reinitialized in-place. No allocate/placeholder shell path is used.
#===============================================================================

class Battle::AI
  def bss_create_new_ai_battler(idx_battler)
    idx_battler=idx_battler.to_i
    return nil if !@battlers.is_a?(Array)
    return @battlers[idx_battler] if @battlers[idx_battler]
    @battlers[idx_battler]=AIBattler.new(self,idx_battler)
    @battlers[idx_battler]
  end

  def bss_ai_battler_ready?(idx_battler)
    @battlers.is_a?(Array) && !!@battlers[idx_battler.to_i]
  end
end


#===============================================================================
# Dynamic battlers are intentionally NOT monkey-patched here.
# BSS 0.6.37 follows the same creation/replacement lifecycle as the supplied
# SOS source: pbCreateBattler for new slots and pbInitialize only for an already
# constructed fainted slot. This avoids entering the project's Battler initializer
# with a hand-built/partially seeded object.
#===============================================================================

#===============================================================================
# Bundled BAS SOS Call animation
# Uses the CarnekVT-authored SOS Call animpack supplied with v0.6.37 whenever
# Battle Animation Studio Runtime is present. The animation is injected into the
# BAS in-memory custom catalog only; the user's compiled_animations.json is never
# edited. Without BAS, the native Growl fallback remains untouched.
#===============================================================================
module BSS064
  BAS_SOS_CALL_FILE = "Data/BattleSceneStudio/BAS/SOSCALL_Foe_V0.animpack.json" unless const_defined?(:BAS_SOS_CALL_FILE)

  class << self
    def bas_sos_call_animation
      return @bas_sos_call_animation if @bas_sos_call_animation.is_a?(Hash)
      return nil if !File.exist?(BAS_SOS_CALL_FILE)
      raw=File.open(BAS_SOS_CALL_FILE,"rb") { |f| f.read }
      pack=json_parse(raw)
      anim=pack.is_a?(Hash) ? pack["animation"] : nil
      return nil if !anim.is_a?(Hash)
      src=anim["source"].is_a?(Hash) ? anim["source"] : (anim["source"]={})
      src["runtimeEnabled"]=true; src["runtimeSelected"]=true
      @bas_sos_call_animation=anim
    rescue => e
      log("SOS BAS animpack load warning: #{e.class}: #{e.message}")
      nil
    end

    def ensure_bas_sos_call_animation
      return false if !defined?(BattleAnimationStudioRuntime)
      anim=bas_sos_call_animation; return false if !anim
      begin; BattleAnimationStudioRuntime.load_data if BattleAnimationStudioRuntime.respond_to?(:load_data); rescue; end
      cache=BattleAnimationStudioRuntime.instance_variable_get(:@cache) rescue nil
      if !cache.is_a?(Hash)
        cache={"animations"=>[]}
        BattleAnimationStudioRuntime.instance_variable_set(:@cache,cache) rescue nil
      end
      list=cache["animations"]; list=[] if !list.is_a?(Array); cache["animations"]=list
      list.delete_if { |a| a.is_a?(Hash) && (a["source"].is_a?(Hash) ? a["source"]["move"].to_s : "") == "SOSCALL" && a["bssBundledSource"].to_s.start_with?("BSS:") }
      injected=begin Marshal.load(Marshal.dump(anim)) rescue anim.dup end
      injected["bssBundledSource"]="BSS:SOS Call(1).zip"
      list << injected
      if BattleAnimationStudioRuntime.respond_to?(:rebuild_lookup_index)
        BattleAnimationStudioRuntime.rebuild_lookup_index
      end
      true
    rescue => e
      log("SOS BAS catalog inject warning: #{e.class}: #{e.message}")
      false
    end

    def install_bas_sos_color_compat
      return false if !defined?(BattleAnimationStudioRuntime::Player)
      klass=BattleAnimationStudioRuntime::Player
      return true if klass.ancestors.include?(BSS064BASParticleColorCompat)
      return false if !klass.method_defined?(:apply_object) && !klass.private_method_defined?(:apply_object)
      klass.prepend(BSS064BASParticleColorCompat)
      true
    rescue => e
      log("SOS BAS color compat warning: #{e.class}: #{e.message}")
      false
    end

    # Main path for BAS 5.1+: inject the supplied animpack into BAS' custom
    # catalog, then ask BAS itself to resolve and play it. This is deliberately
    # the same public playback path used by custom/Quick animations. BSS no
    # longer guesses the animation duration or reimplements Player semantics.
    def play_bas_sos_call_official(scene, caller)
      return false if !scene || !caller
      return false if !defined?(BattleAnimationStudioRuntime)
      return false if !scene.respond_to?(:pbPlayBattleAnimationStudioCustom)
      install_bas_sos_color_compat
      return false if !ensure_bas_sos_call_animation
      target=begin caller.pbDirectOpposing(true) rescue nil end
      targets=target ? [target] : []
      result=scene.pbPlayBattleAnimationStudioCustom("SOSCALL",caller,targets,0)
      result != false
    rescue => e
      log("SOS BAS official playback warning: #{e.class}: #{e.message}")
      false
    end

    # Compatibility only. Older BAS builds may expose Player but not the public
    # custom-animation helper. Even here BSS waits for BAS' own animDone? state
    # rather than truncating the supplied animation at its metadata duration.
    def play_bas_sos_call_direct(scene, caller)
      return false if !scene || !caller
      return false if !defined?(BattleAnimationStudioRuntime) || !defined?(BattleAnimationStudioRuntime::Player)
      install_bas_sos_color_compat
      return false if !scene.respond_to?(:bas_runtime_pump_frame)
      source=bas_sos_call_animation;return false if !source
      data=begin Marshal.load(Marshal.dump(source)) rescue source.dup end
      src=data["source"].is_a?(Hash) ? data["source"] : (data["source"]={})
      src["runtimeEnabled"]=true;src["runtimeSelected"]=true
      target=begin caller.pbDirectOpposing(true) rescue nil end
      sprites=scene.instance_variable_get(:@sprites) rescue nil
      viewport=scene.instance_variable_get(:@viewport) rescue nil
      return false if !sprites.is_a?(Hash)
      player=BattleAnimationStudioRuntime::Player.new(sprites,viewport,caller,target,data,target ? [target] : [])
      BattleAnimationStudioRuntime.active_player=player if BattleAnimationStudioRuntime.respond_to?(:active_player=)
      safety=0
      fallback_duration=(BSS064.clamp_int(data["duration"],1,100000,60) rescue 60)
      fallback_frames=[fallback_duration,60].max
      loop do
        player.update
        scene.bas_runtime_pump_frame(player)
        safety+=1
        break if player.respond_to?(:animDone?) && player.animDone?
        break if !player.respond_to?(:animDone?) && safety>=fallback_frames
        break if safety>20000
      end
      true
    rescue => e
      log("SOS BAS direct playback warning: #{e.class}: #{e.message}")
      false
    ensure
      begin
        if player && defined?(BattleAnimationStudioRuntime) && BattleAnimationStudioRuntime.respond_to?(:active_player=) && BattleAnimationStudioRuntime.active_player.equal?(player)
          BattleAnimationStudioRuntime.active_player=nil
        end
      rescue;end
      begin;player.restore_camera! if player;rescue;end
      begin;player.dispose if player;rescue;end
    end

    def play_bas_sos_call(scene, caller)
      return false if !scene || !caller
      return false if !defined?(BattleAnimationStudioRuntime)
      # BAS is the authority. BSS only supplies the animpack and participants.
      return true if play_bas_sos_call_official(scene,caller)
      play_bas_sos_call_direct(scene,caller)
    rescue => e
      log("SOS BAS playback warning: #{e.class}: #{e.message}")
      false
    end

  end
end

# BAS 1.0.32 applies Tone to ordinary effect clips but ignores the authored
# Essentials SetColor/MoveColor fxOps. The bundled SOS Call uses those ops for
# its orange rings and yellow zaps. Add only that missing RGSS Color layer while
# leaving BAS in charge of every other property/timing/graphic.
module BSS064BASParticleColorCompat
  # Convert the same color payloads accepted by BAS Studio preview. The
  # Essentials importer normally stores raw SetColor/MoveColor colors as
  # RRGGBBAA strings, but hash payloads are accepted too.
  def bss067_fx_color(raw)
    if raw.is_a?(String) || raw.is_a?(Symbol)
      text=raw.to_s.strip.sub(/^#/,"")
      return nil if text !~ /\A[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?\z/
      text += "FF" if text.length==6
      return {
        "red"=>text[0,2].to_i(16), "green"=>text[2,2].to_i(16),
        "blue"=>text[4,2].to_i(16), "alpha"=>text[6,2].to_i(16)
      }
    end
    if raw.is_a?(Hash)
      return {
        "red"=>(raw["red"].nil? ? raw["r"] : raw["red"]).to_f,
        "green"=>(raw["green"].nil? ? raw["g"] : raw["green"]).to_f,
        "blue"=>(raw["blue"].nil? ? raw["b"] : raw["blue"]).to_f,
        "alpha"=>(raw["alpha"].nil? ? raw["a"] : raw["alpha"]).to_f
      }
    end
    nil
  rescue
    nil
  end

  def bss067_mix_color(a,b,t)
    a ||= {"red"=>0.0,"green"=>0.0,"blue"=>0.0,"alpha"=>0.0}
    b ||= {"red"=>0.0,"green"=>0.0,"blue"=>0.0,"alpha"=>0.0}
    x=[[t.to_f,0.0].max,1.0].min
    out={}
    ["red","green","blue","alpha"].each { |k| out[k]=a[k].to_f+((b[k].to_f-a[k].to_f)*x) }
    out
  end

  def bss067_ease_color(t,mode)
    x=[[t.to_f,0.0].max,1.0].min
    case mode.to_s.downcase
    when "linear", "" then x
    when "ease_in", "easein", "in" then x*x
    when "ease_out", "easeout", "out" then 1.0-((1.0-x)*(1.0-x))
    else
      x<0.5 ? 2.0*x*x : 1.0-(((-2.0*x+2.0)**2)/2.0)
    end
  rescue
    x
  end

  # BAS 1.0.32 runtime fx_at only consumes legacyFx. BAS Studio preview also
  # consumes imported SetColor/MoveColor (frame may live in op.frame OR args[0])
  # and then overlays color valueKeys. Reproduce that exact missing layer so an
  # animpack looks the same in-game as it does in BAS.
  def bss067_fx_color_at(obj,frame)
    return nil if !obj.is_a?(Hash)
    source=begin
      respond_to?(:replica_visual_source,true) ? replica_visual_source(obj) : obj
    rescue
      obj
    end
    source=obj if !source.is_a?(Hash)
    value={"red"=>0.0,"green"=>0.0,"blue"=>0.0,"alpha"=>0.0}
    seen=false
    ops=source["fxOps"].is_a?(Array) ? source["fxOps"].select { |op| op.is_a?(Hash) } : []
    ops=ops.sort_by do |op|
      args=op["args"].is_a?(Array) ? op["args"] : []
      (op.key?("frame") ? op["frame"] : args[0]).to_f
    end
    fnow=frame.to_f
    ops.each do |op|
      args=op["args"].is_a?(Array) ? op["args"] : []
      f=(op.key?("frame") ? op["frame"] : args[0]).to_f
      break if f>fnow
      name=op["name"].to_s
      if name=="legacyFx"
        parsed=bss067_fx_color(op["color"])
        if parsed; value=parsed; seen=true; end
        next
      end
      next if name !~ /Color/i
      moving=(name =~ /^move/i) ? true : false
      raw=if op.key?("value")
        op["value"]
      elsif moving
        args.length>2 ? args[2] : args[-1]
      else
        args.length>1 ? args[1] : args[-1]
      end
      target=bss067_fx_color(raw)
      next if !target
      seen=true
      duration=moving ? [0.0,(op.key?("duration") ? op["duration"] : args[1]).to_f].max : 0.0
      if moving && duration>0.0 && fnow<f+duration
        mode=(op["easing"] || args[3] || "linear").to_s
        t=bss067_ease_color((fnow-f)/duration,mode)
        return bss067_mix_color(value,target,t)
      end
      value=target
    end

    # Match BAS preview's final colorRed/Green/Blue/Alpha overlay too. This is
    # harmless for the bundled SOS Call (it uses raw fxOps) and makes the shim
    # correct for user-authored BAS variants as well.
    keys=source["valueKeys"].is_a?(Hash) ? source["valueKeys"] : {}
    keyed=["colorRed","colorGreen","colorBlue","colorAlpha"].any? { |k| keys[k].is_a?(Array) && !keys[k].empty? }
    if keyed && respond_to?(:sample_value,true)
      value={
        "red"=>sample_value(source,"colorRed",fnow,value["red"]),
        "green"=>sample_value(source,"colorGreen",fnow,value["green"]),
        "blue"=>sample_value(source,"colorBlue",fnow,value["blue"]),
        "alpha"=>sample_value(source,"colorAlpha",fnow,value["alpha"])
      }
      seen=true
    end
    seen ? value : nil
  rescue => e
    BattleAnimationStudioRuntime.log("BSS SOS color evaluate #{e.class}: #{e.message}") if defined?(BattleAnimationStudioRuntime) && BattleAnimationStudioRuntime.respond_to?(:log)
    nil
  end

  def apply_object(sprite,obj,frame,battler=false,side=nil)
    result=super
    if sprite && sprite.respond_to?(:color=)
      rgba=bss067_fx_color_at(obj,frame)
      if rgba
        sprite.color=Color.new(rgba["red"].to_f,rgba["green"].to_f,rgba["blue"].to_f,rgba["alpha"].to_f)
      end
    end
    result
  rescue => e
    BattleAnimationStudioRuntime.log("BSS SOS color compat #{e.class}: #{e.message}") if defined?(BattleAnimationStudioRuntime) && BattleAnimationStudioRuntime.respond_to?(:log)
    result
  end
end

class Battle
  attr_accessor :bss_sos_enabled
  attr_accessor :bss_sos_config
  attr_accessor :bss_sos_chain
  attr_accessor :bss_adrenaline_orb
  attr_accessor :bss_original_caller
  attr_accessor :bss_last_turn_called
  attr_accessor :bss_last_call_answered
  attr_accessor :bss_initial_sos_done

  unless method_defined?(:bss064_initialize_without_native_sos) || private_method_defined?(:bss064_initialize_without_native_sos)
    alias bss064_initialize_without_native_sos initialize
  end
  # F12-safe: redefine the wrapper every plugin reload even though the alias
  # name already exists from the previous script pass.
  def initialize(scene, p1, p2, player, opponent)
    bss064_initialize_without_native_sos(scene, p1, p2, player, opponent)
    @bss_sos_enabled        = (wildBattle? rescue false) && BSS064.global_sos_active?
    @bss_sos_config         = @bss_sos_enabled ? BSS064.global_sos.dup : {}
    @bss_sos_chain          = 0
    @bss_adrenaline_orb     = false
    @bss_original_caller    = nil
    @bss_last_turn_called   = -99
    @bss_last_call_answered = nil
    @bss_initial_sos_done   = false
    @bss_sos_summoned_indices = {}
    @bss_sos_fixed_cursor      = 0
    self.sosBattle = false if respond_to?(:sosBattle=)
  end

  def bss_sos_limit_one?
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    return !(cfg["allowChainCalls"] == true) if cfg.key?("allowChainCalls")
    return cfg["limitCallsToOne"] != false if cfg.key?("limitCallsToOne")
    global=BSS064.global_sos
    return !(global["allowChainCalls"] == true) if global.is_a?(Hash) && global.key?("allowChainCalls")
    global.is_a?(Hash) ? global["limitCallsToOne"] != false : true
  end

  def bss_scripted_sos_battle?
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    cfg["scriptedBattle"] == true
  end

  # Global SOS is wild-only. Trainer SOS is allowed only when the current BSS
  # blueprint explicitly enables its scripted SOS block.
  def bss_sos_runtime_battle_allowed?
    return true if (wildBattle? rescue false)
    (trainerBattle? rescue false) && bss_scripted_sos_battle?
  end

  # Global SOS has two separate concepts:
  # - allowChainCalls: more calls may happen after the first successful call.
  # - allowSOSContinuation: a battler that arrived by SOS may become the caller
  #   and keep the original chain alive (important when the first caller faints).
  # Scripted battles keep their explicit per-blueprint controls.
  def bss_sos_continuation_allowed?
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    return cfg["allowRecursiveCalls"] == true if bss_scripted_sos_battle?
    return cfg["allowSOSContinuation"] == true if cfg.key?("allowSOSContinuation")
    # Backward compatibility with 0.6.18 JSON: the old chain checkbox meant both.
    return cfg["allowChainCalls"] == true if cfg.key?("allowChainCalls")
    global=BSS064.global_sos
    return global["allowSOSContinuation"] == true if global.is_a?(Hash) && global.key?("allowSOSContinuation")
    global.is_a?(Hash) && global["allowChainCalls"] == true
  end

  def bss_additional_sos_calls_allowed?
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    return cfg["allowAdditionalCalls"] == true if bss_scripted_sos_battle?
    return true if bss_sos_continuation_allowed?
    return cfg["allowChainCalls"] == true if cfg.key?("allowChainCalls")
    !bss_sos_limit_one?
  end

  def bss_recursive_sos_calls_allowed?
    bss_sos_continuation_allowed?
  end

  # Number of SOS allies that may be alive beside the current caller.
  # 1 = standard Alola-style caller + one ally. 2 = extended caller + two allies.
  def bss_sos_max_simultaneous_allies
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    n=cfg["maxSimultaneousSOS"].to_i
    if n<=0
      global=BSS064.global_sos
      n=global["maxSimultaneousSOS"].to_i if global.is_a?(Hash)
    end
    n=1 if n<=0
    [[n,1].max,2].min
  end

  def bss_sos_max_live_same_side
    1 + bss_sos_max_simultaneous_allies
  end

  # Number of allies produced by one SCRIPTED SOS event. This is distinct from
  # maxSimultaneousSOS, which is only the live-side cap.
  def bss_sos_summons_per_call
    return 1 if !bss_scripted_sos_battle?
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    n=cfg["summonsPerCall"].to_i
    n=1 if n<=0
    [[n,1].max,bss_sos_max_simultaneous_allies].min
  end

  def bss_sos_shiny_multiplier
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    n=cfg["shinyMultiplier"].to_i
    n=BSS064.global_sos["shinyMultiplier"].to_i if n<=0
    [n,1].max
  end

  # ---------------------------------------------------------------------------
  # Conditions used by global SOS profiles and weighted pool entries.
  # ---------------------------------------------------------------------------
  def bss_player_highest_level
    return 0 if !defined?($player) || !$player || !$player.respond_to?(:party)
    vals=$player.party.compact.map { |p| p.level.to_i }
    vals.empty? ? 0 : vals.max
  rescue
    0
  end

  def bss_requirement_met?(req, caller=nil)
    return true if !req.is_a?(Hash)
    type=req["type"].to_s
    value=req["value"].to_i
    id=req["id"].to_i
    case type
    when "", "always" then true
    when "badge_min" then (defined?($player) && $player && $player.respond_to?(:badge_count) ? $player.badge_count.to_i : 0) >= value
    when "badge_max" then (defined?($player) && $player && $player.respond_to?(:badge_count) ? $player.badge_count.to_i : 0) <= value
    when "switch_on" then id>0 && defined?($game_switches) && $game_switches && !!$game_switches[id]
    when "switch_off" then id>0 && defined?($game_switches) && $game_switches && !$game_switches[id]
    when "variable_min" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i >= value
    when "variable_max" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i <= value
    when "variable_equals" then id>0 && defined?($game_variables) && $game_variables && $game_variables[id].to_i == value
    when "caller_level_min" then caller && caller.level.to_i >= value
    when "caller_level_max" then caller && caller.level.to_i <= value
    when "player_level_min" then bss_player_highest_level >= value
    when "player_level_max" then bss_player_highest_level <= value
    when "map_id" then defined?($game_map) && $game_map && $game_map.map_id.to_i == value
    when "chain_min" then @bss_sos_chain.to_i >= value
    when "chain_max" then @bss_sos_chain.to_i <= value
    when "day" then defined?(PBDayNight) && PBDayNight.respond_to?(:isDay?) && PBDayNight.isDay?
    when "night" then defined?(PBDayNight) && PBDayNight.respond_to?(:isNight?) && PBDayNight.isNight?
    else true
    end
  rescue
    false
  end

  def bss_requirements_met?(requirements, caller=nil)
    rows=requirements.is_a?(Array) ? requirements : []
    rows.all? { |r| bss_requirement_met?(r,caller) }
  end

  def bss_sos_profile(caller)
    return nil if !caller
    profile=nil
    # A surviving SOS ally that is explicitly allowed to continue the chain uses
    # the ORIGINAL caller's profile/pool first. Without this, mixed-species pools
    # (e.g. caller A -> ally B) stop as soon as A faints if B has no own profile.
    if bss_sos_summoned_battler?(caller.index) && bss_sos_continuation_allowed? && @bss_original_caller
      begin
        profile=BSS064.sos_profile(@bss_original_caller.species, @bss_original_caller.form)
      rescue
        profile=nil
      end
    end
    profile ||= BSS064.sos_profile(caller.species, caller.form)
    return nil if !profile
    return nil if !bss_requirements_met?(profile["requirements"], caller)
    profile
  rescue
    nil
  end

  # ---------------------------------------------------------------------------
  # Dynamic battler lifecycle — source-faithful to the SOS code supplied by user.
  # ---------------------------------------------------------------------------
  # Do not construct, clone, allocate or pre-seed Battle::Battler here. A truly
  # new active slot must go through Battle#pbCreateBattler, while a fainted active
  # slot is reinitialized in-place. The side size is changed at the same point as
  # the source SOS implementation, before pbCreateBattler.
  # ---------------------------------------------------------------------------
  def bss_find_new_battler_slot(caller)
    return [-1, false] if !caller
    return [-1, false] if bss_live_same_side_count(caller.index) >= bss_sos_max_live_same_side
    # Use the source SOS slot finder when present, including any project-specific
    # side-size/index changes made by that implementation.
    if respond_to?(:pbFindNewBattlerIndex) && !((trainerBattle? rescue false) && bss_scripted_sos_battle?)
      side = caller.idxOwnSide.to_i
      before = @sideSizes.is_a?(Array) ? @sideSizes[side].to_i : pbSideSize(caller.index).to_i
      idx_new = pbFindNewBattlerIndex(caller)
      after = @sideSizes.is_a?(Array) ? @sideSizes[side].to_i : before
      return [idx_new, idx_new.to_i >= 0 && after > before]
    end
    idx_new = -1
    change_size = false
    size = pbSideSize(caller.index).to_i
    6.times do |i|
      b = @battlers[i]
      next if b && !b.fainted?
      next if caller.opposes?(i)
      idx_new = i
      change_size = b.nil?
      break
    end
    if idx_new < 0 && size < 3
      idx_new = caller.index + (2 * ([1, size - 1].max))
      change_size = true
    end
    @sideSizes[caller.idxOwnSide] = size + 1 if change_size && idx_new >= 0
    [idx_new, change_size]
  end

  # Extend battle/scene arrays which are indexed by active battler position.
  def bss_prepare_battle_slot(idx_battler)
    idx_battler = idx_battler.to_i
    if @choices.is_a?(Array)
      @choices << [:None, 0, nil, -1] while @choices.length <= idx_battler
    end
    scene = @scene
    if scene
      [:@lastCmd, :@lastMove].each do |ivar|
        rows = scene.instance_variable_get(ivar)
        rows << 0 while rows.is_a?(Array) && rows.length <= idx_battler
      end
      [:@lastTarget, :@lastMoveUser].each do |ivar|
        rows = scene.instance_variable_get(ivar)
        rows << -1 while rows.is_a?(Array) && rows.length <= idx_battler
      end
    end
    true
  end

  # LBDS 1.2.x adds party-indexed battle state that stock v21.1 SOS Battles does
  # not know about. In particular Battler#pbInitEffects clears
  # abilitiesUsedPerSwitchIn[side][pokemonIndex]. A freshly appended SOS Pokemon
  # therefore MUST get these entries before pbCreateBattler constructs the new
  # Battle::Battler. Otherwise 003_Battler_Initialize.rb raises nil.clear.
  def bss_prepare_party_tracking_slot(side, idx_party)
    side = side.to_i
    idx_party = idx_party.to_i

    if @abilitiesUsedPerSwitchIn.is_a?(Array)
      @abilitiesUsedPerSwitchIn[side] ||= []
      rows = @abilitiesUsedPerSwitchIn[side]
      rows << [] while rows.length <= idx_party
      rows[idx_party] = [] if !rows[idx_party].is_a?(Array)
    end

    if @abilitiesUsedOnce.is_a?(Array)
      @abilitiesUsedOnce[side] ||= []
      rows = @abilitiesUsedOnce[side]
      rows << [] while rows.length <= idx_party
      rows[idx_party] = [] if !rows[idx_party].is_a?(Array)
    end

    if @hitsTakenCounts.is_a?(Array)
      @hitsTakenCounts[side] ||= []
      rows = @hitsTakenCounts[side]
      rows << 0 while rows.length <= idx_party
      rows[idx_party] = 0 if rows[idx_party].nil?
    end

    true
  end

  # The supplied SOS plugin was written against stock v21.1, where
  # @initialItems stores only the item id. LBDS 1.2.x stores a four-value record.
  # Preserve whichever layout the running project actually uses.
  def bss_normalize_initial_item_slot(side, idx_party, pkmn)
    return if !@initialItems.is_a?(Array) || !@initialItems[side].is_a?(Array)
    rows = @initialItems[side]
    sample = rows.find { |row| !row.nil? }
    if sample.is_a?(Array)
      rows[idx_party] = [pkmn.item_id, side, idx_party, false]
    end
  rescue => e
    BSS064.log("SOS initialItems compatibility skipped: #{e.class}: #{e.message}")
  end

  # Generic scene/choice bookkeeping helper for fallback paths.
  def bss_finalize_battle_slot(idx_battler)
    bss_prepare_battle_slot(idx_battler)
  end

  # SOS Battles v21.1 assumes all of these are [player_side, foe_side] arrays.
  # LBDS and some battle-base combinations can omit one legacy tracker entirely,
  # or leave its foe-side row nil. Never call []/push on that nil row.
  def bss_side_array!(ivar, side)
    side = side.to_i
    outer = instance_variable_get(ivar)
    if outer.is_a?(Hash)
      outer[side] = [] if !outer[side].is_a?(Array)
      return outer[side]
    end
    if !outer.is_a?(Array)
      outer = []
      instance_variable_set(ivar, outer)
    end
    outer << [] while outer.length <= side
    outer[side] = [] if !outer[side].is_a?(Array)
    outer[side]
  end

  def bss_prepare_source_bookkeeping_arrays(side = 1)
    [:@initialItems, :@recycleItems, :@belch, :@battleBond,
     :@corrosiveGas, :@usedInBattle].each { |ivar| bss_side_array!(ivar, side) }
    bss_side_array!(:@abils_triggered, side) if instance_variable_defined?(:@abils_triggered)
    bss_side_array!(:@rage_hit_count, side) if instance_variable_defined?(:@rage_hit_count)
    if instance_variable_defined?(:@wonderLauncher) && (trainerBattle? rescue false)
      bss_side_array!(:@launcherPoints, side)
      bss_side_array!(:@launcherCounter, side)
    end
    true
  end

  def bss_initial_item_value(side, idx_party, pkmn)
    outer = @initialItems
    sample = nil
    if outer.is_a?(Array)
      outer.each do |rows|
        next if !rows.is_a?(Array)
        sample = rows.find { |row| !row.nil? }
        break if !sample.nil?
      end
    end
    return [pkmn.item_id, side.to_i, idx_party.to_i, false] if sample.is_a?(Array)
    pkmn.item_id
  end

  def bss_append_source_bookkeeping(pkmn)
    # Same semantic bookkeeping as the supplied SOS source, but each tracker is
    # normalized first so standalone BSS also works on LBDS builds that removed
    # or never initialized one of the legacy arrays (e.g. @battleBond[1]).
    side = 1
    bss_prepare_source_bookkeeping_arrays(side)
    idx_party = @party2.is_a?(Array) ? [@party2.length - 1, 0].max : bss_side_array!(:@usedInBattle, side).length
    bss_side_array!(:@initialItems, side).push(bss_initial_item_value(side, idx_party, pkmn))
    bss_side_array!(:@recycleItems, side).push(nil)
    bss_side_array!(:@belch, side).push(false)
    bss_side_array!(:@battleBond, side).push(false)
    bss_side_array!(:@corrosiveGas, side).push(false)
    bss_side_array!(:@usedInBattle, side).push(true)
    bss_side_array!(:@abils_triggered, side).push(false) if instance_variable_defined?(:@abils_triggered)
    bss_side_array!(:@rage_hit_count, side).push(0) if instance_variable_defined?(:@rage_hit_count)
    if instance_variable_defined?(:@wonderLauncher) && (trainerBattle? rescue false)
      bss_side_array!(:@launcherPoints, side).push(0)
      bss_side_array!(:@launcherCounter, side).push((launcherBattle? rescue false))
    end
  end

  def bss_replace_source_bookkeeping(idx_party, pkmn)
    side = 1
    idx_party = idx_party.to_i
    bss_prepare_source_bookkeeping_arrays(side)
    bss_side_array!(:@initialItems, side)[idx_party] = bss_initial_item_value(side, idx_party, pkmn)
    bss_side_array!(:@recycleItems, side)[idx_party] = nil
    bss_side_array!(:@belch, side)[idx_party] = false
    bss_side_array!(:@battleBond, side)[idx_party] = false
    bss_side_array!(:@corrosiveGas, side)[idx_party] = false
    bss_side_array!(:@usedInBattle, side)[idx_party] = true
    bss_side_array!(:@abils_triggered, side)[idx_party] = false if instance_variable_defined?(:@abils_triggered)
    bss_side_array!(:@rage_hit_count, side)[idx_party] = 0 if instance_variable_defined?(:@rage_hit_count)
    if instance_variable_defined?(:@wonderLauncher) && (trainerBattle? rescue false)
      bss_side_array!(:@launcherPoints, side)[idx_party] = 0
      bss_side_array!(:@launcherCounter, side)[idx_party] = (launcherBattle? rescue false)
    end
  end

  def bss_initialize_new_sos_battler(idx_battler, pkmn, full_update)
    # Prefer the lifecycle supplied by the installed SOS plugin, but seed the
    # additional LBDS 1.2.x party-indexed state BEFORE it constructs/reinitializes
    # the battler. The stock SOS source doesn't maintain those newer arrays.
    if respond_to?(:pbInitializeNewBattler) && !((trainerBattle? rescue false) && bss_scripted_sos_battle?)
      idx_party = nil
      if full_update
        idx_party = @party2.length
      else
        idx_party = 0
        @battlers.each do |b|
          next if !b || !b.fainted? || b.opposes?(idx_battler)
          idx_party = b.pokemonIndex
          break
        end
      end
      bss_prepare_party_tracking_slot(1, idx_party)
      bss_prepare_battle_slot(idx_battler)
      bss_prepare_source_bookkeeping_arrays(1)
      BSS064.log("SOS lifecycle: source pbInitializeNewBattler idx=#{idx_battler} party=#{idx_party} full=#{full_update}")
      pbInitializeNewBattler([idx_battler, pkmn], [], full_update)
      battler = @battlers[idx_battler]
      raise RuntimeError, "SOS source lifecycle did not create battler #{idx_battler}" if !battler
      bss_prepare_party_tracking_slot(1, battler.pokemonIndex)
      bss_normalize_initial_item_slot(1, battler.pokemonIndex, pkmn)
      return battler
    end

    # Autonomous fallback when no source SOS runtime exists.
    idx_party = nil
    if full_update
      @party2.push(pkmn)
      idx_party = @party2.length - 1
      @party2order = Array.new(@party2.length) { |i| i }
      bss_prepare_party_tracking_slot(1, idx_party)
      bss_prepare_battle_slot(idx_battler)
      bss_prepare_source_bookkeeping_arrays(1)
      pbCreateBattler(idx_battler, pkmn, idx_party)
      if @battleAI
        if @battleAI.respond_to?(:create_new_ai_battler)
          @battleAI.create_new_ai_battler(idx_battler)
        elsif @battleAI.respond_to?(:bss_create_new_ai_battler)
          @battleAI.bss_create_new_ai_battler(idx_battler)
        end
      end
      pbInitializeSpecialActions(nil)
      bss_append_source_bookkeeping(pkmn)
    else
      idx_party = 0
      @battlers.each do |b|
        next if !b || !b.fainted? || b.opposes?(idx_battler)
        idx_party = b.pokemonIndex
        break
      end
      @party2[idx_party] = pkmn
      @party2order = Array.new(@party2.length) { |i| i }
      bss_prepare_party_tracking_slot(1, idx_party)
      bss_prepare_battle_slot(idx_battler)
      bss_prepare_source_bookkeeping_arrays(1)
      battler = @battlers[idx_battler]
      raise RuntimeError, "SOS replacement slot #{idx_battler} has no constructed battler" if !battler
      battler.pbInitialize(pkmn, idx_party)
      if @battleAI
        if @battleAI.respond_to?(:create_new_ai_battler)
          @battleAI.create_new_ai_battler(idx_battler)
        elsif @battleAI.respond_to?(:bss_create_new_ai_battler)
          @battleAI.bss_create_new_ai_battler(idx_battler)
        end
      end
      pbInitializeSpecialActions(nil)
      bss_replace_source_bookkeeping(idx_party, pkmn)
    end
    battler = @battlers[idx_battler]
    raise RuntimeError, "SOS battler #{idx_battler} was not created" if !battler
    bss_prepare_party_tracking_slot(1, battler.pokemonIndex) if battler.respond_to?(:pokemonIndex)
    bss_normalize_initial_item_slot(1, battler.pokemonIndex, pkmn) if battler.respond_to?(:pokemonIndex)
    battler.lastRoundMoved = @turnCount if battler.respond_to?(:lastRoundMoved=)
    battler.totemBattler = false if battler.respond_to?(:totemBattler=)
    if @choices.is_a?(Array)
      @choices << [:None, 0, nil, -1] while @choices.length <= idx_battler
    end
    scene = @scene
    if scene
      [:@lastCmd, :@lastMove].each do |ivar|
        rows = scene.instance_variable_get(ivar)
        rows << 0 while rows.is_a?(Array) && rows.length <= idx_battler
      end
      [:@lastTarget, :@lastMoveUser].each do |ivar|
        rows = scene.instance_variable_get(ivar)
        rows << -1 while rows.is_a?(Array) && rows.length <= idx_battler
      end
    end
    battler
  end

  def bss_create_fresh_sos_battler(idx_battler, caller, pkmn, change_size)
    side = caller.idxOwnSide.to_i
    # bss_find_new_battler_slot already changed @sideSizes if this is a new slot.
    previous_size = @sideSizes[side].to_i - (change_size ? 1 : 0)
    old_party = @party2.dup
    old_order = @party2order.dup if @party2order.is_a?(Array)
    old_battler = @battlers[idx_battler]
    full_update = old_battler.nil?
    begin
      return bss_initialize_new_sos_battler(idx_battler, pkmn, full_update)
    rescue => e
      # Roll back only battle-level data BSS changed. Never retry pbInitialize and
      # never mutate Battle::Battler internals to hide the real initializer error.
      @sideSizes[side] = previous_size if change_size
      @party2.replace(old_party) if @party2.is_a?(Array)
      @party2order = old_order if old_order
      @battlers[idx_battler] = old_battler if @battlers.is_a?(Array)
      BSS064.log("SOS battler source lifecycle failed: #{e.class}: #{e.message}")
      BSS064.log((e.backtrace || [])[0, 12].join(" | "))
      nil
    end
  end

  def bss_active_battler_indices
    out = []
    [[0, [0,2,4]], [1, [1,3,5]]].each do |side, slots|
      count = @sideSizes.is_a?(Array) ? @sideSizes[side].to_i : 0
      count = [[count, 0].max, 3].min
      slots.first(count).each do |idx|
        battler = @battlers.is_a?(Array) ? @battlers[idx] : nil
        out << idx if battler
      end
    end
    out
  end

  def bss_live_same_side_count(idx_battler)
    side = idx_battler.to_i & 1
    bss_active_battler_indices.count do |idx|
      next false if (idx & 1) != side
      battler = @battlers[idx]
      battler && !(battler.fainted? rescue true)
    end
  end

  def bss_sos_pool_entries(caller)
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    rows=cfg["pool"].is_a?(Array) ? cfg["pool"] : []
    if rows.empty?
      profile=bss_sos_profile(caller)
      rows=profile && profile["pool"].is_a?(Array) ? profile["pool"] : []
    end
    out=[]
    rows.each do |raw|
      entry=raw.is_a?(Hash) ? raw.dup : {"species"=>raw.to_s,"form"=>0,"weight"=>100}
      species=entry["species"].to_s.upcase
      next if species.empty? || !(GameData::Species.exists?(species.to_sym) rescue false)
      next if !bss_requirements_met?(entry["requirements"], caller)
      entry["species"]=species
      entry["form"]=entry["form"].to_i
      entry["weight"]=[entry["weight"].to_i,0].max
      out << entry
    end
    out << {"species"=>caller.species.to_s,"form"=>caller.form.to_i,"weight"=>100} if out.empty?
    out
  end

  def bss_pick_sos_entry(caller)
    rows=bss_sos_pool_entries(caller)
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    if bss_scripted_sos_battle? && cfg["allySelectionMode"].to_s == "fixed"
      idx=@bss_sos_fixed_cursor.to_i
      return nil if idx<0 || idx>=rows.length
      return rows[idx]
    end
    weighted=rows.select { |x| x["weight"].to_i>0 }
    return rows[0] if weighted.empty?
    total=weighted.inject(0) { |n,x| n+x["weight"].to_i }
    roll=pbRandom(total)
    weighted.each do |x|
      w=x["weight"].to_i
      return x if roll<w
      roll-=w
    end
    weighted[-1]
  end

  def bss_max_level
    return GameData::GrowthRate.max_level.to_i if defined?(GameData::GrowthRate) && GameData::GrowthRate.respond_to?(:max_level)
    100
  rescue
    100
  end

  def bss_level_value(value, fallback)
    return fallback.to_i if value.nil? || value.to_s.empty?
    [[value.to_i, 1].max, bss_max_level].min
  end

  # Returns rows [weight, species, min_level, max_level] from the CURRENT map.
  # Prefer the current encounter type and the requested SOS species. If that
  # species isn't native to the map, fall back to the zone's overall level table.
  def bss_zone_encounter_rows(species)
    return [] if !defined?(GameData::Encounter) || !defined?($game_map) || !$game_map
    version = (defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:encounter_version)) ? $PokemonGlobal.encounter_version : 0
    data = GameData::Encounter.get($game_map.map_id, version) rescue nil
    return [] if !data || !data.respond_to?(:types) || !data.types.is_a?(Hash)
    types = data.types
    enc_type = nil
    begin
      enc_type = $PokemonEncounters.encounter_type if defined?($PokemonEncounters) && $PokemonEncounters && $PokemonEncounters.respond_to?(:encounter_type)
    rescue
      enc_type = nil
    end
    current_rows = enc_type && types[enc_type].is_a?(Array) ? types[enc_type] : []
    all_rows = types.values.select { |rows| rows.is_a?(Array) }.flatten(1)
    sid = species.to_s.upcase
    match = proc { |row| row.is_a?(Array) && row.length >= 4 && row[1].to_s.upcase == sid }
    rows = current_rows.select { |row| match.call(row) }
    rows = all_rows.select { |row| match.call(row) } if rows.empty?
    rows = current_rows.select { |row| row.is_a?(Array) && row.length >= 4 } if rows.empty?
    rows = all_rows.select { |row| row.is_a?(Array) && row.length >= 4 } if rows.empty?
    rows
  rescue => e
    BSS064.log("SOS zone level lookup warning: #{e.class}: #{e.message}")
    []
  end

  def bss_pick_zone_level(species, fallback_level)
    rows = bss_zone_encounter_rows(species)
    return [[fallback_level.to_i,1].max,bss_max_level].min if rows.empty?
    total = rows.inject(0) { |sum,row| sum + [row[0].to_i,1].max }
    roll = pbRandom([total,1].max)
    picked = rows[-1]
    rows.each do |row|
      roll -= [row[0].to_i,1].max
      if roll < 0
        picked = row
        break
      end
    end
    lo = [[picked[2].to_i,1].max,bss_max_level].min
    hi = [[picked[3].to_i,lo].max,bss_max_level].min
    lo + pbRandom([hi-lo+1,1].max)
  rescue
    [[fallback_level.to_i,1].max,bss_max_level].min
  end

  def bss_sos_level_for(entry, caller)
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    mode=cfg["levelMode"].to_s.downcase
    mode="range" if mode=="custom"   # migrate legacy JSON in-place
    mode="zone" if !["zone","range","fixed"].include?(mode)
    base=(caller && caller.respond_to?(:level)) ? caller.level.to_i : 1
    if mode=="fixed"
      return bss_level_value(cfg["levelFixed"],base)
    elsif mode=="range"
      lo=bss_level_value(cfg["levelMin"],base)
      hi=bss_level_value(cfg["levelMax"],base)
      lo,hi=hi,lo if hi<lo
      return lo + pbRandom([hi-lo+1,1].max)
    end
    bss_pick_zone_level(entry["species"],base)
  end

  def bss_apply_scripted_sos_moves(pkmn, entry)
    return pkmn if !bss_scripted_sos_battle? || !entry.is_a?(Hash)
    return pkmn if entry["moveMode"].to_s != "custom"
    raw=entry["moves"].is_a?(Array) ? entry["moves"] : []
    ids=raw.map { |x| x.to_s.strip.upcase }.reject { |x| x.empty? }.first(4)
    ids.select! { |id| GameData::Move.exists?(id.to_sym) rescue false }
    return pkmn if ids.empty?
    begin
      pkmn.moves.clear if pkmn.respond_to?(:moves) && pkmn.moves.respond_to?(:clear)
      ids.each { |id| pkmn.learn_move(id.to_sym) if pkmn.respond_to?(:learn_move) }
    rescue => e
      BSS064.log("SOS custom movepool warning: #{e.class}: #{e.message}")
    end
    pkmn
  end

  def bss_generate_sos_pokemon(entry, caller)
    level=bss_sos_level_for(entry,caller)
    species=entry["species"].to_s.upcase.to_sym
    trainer_sos=(trainerBattle? rescue false) && bss_scripted_sos_battle?
    pkmn=trainer_sos ? Pokemon.new(species,level) : pbGenerateWildPokemon(species,level)
    form=entry["form"].to_i
    pkmn.form=form if form>0 && pkmn.respond_to?(:form=)
    pkmn.form_simple=pkmn.form if pkmn.respond_to?(:form_simple=)
    if trainer_sos && caller && caller.respond_to?(:pokemon) && caller.pokemon
      begin
        pkmn.owner = caller.pokemon.owner if pkmn.respond_to?(:owner=) && caller.pokemon.respond_to?(:owner)
      rescue
      end
    end
    BSS064.apply_custom_pokemon_fields(pkmn,entry,true) if BSS064.respond_to?(:apply_custom_pokemon_fields)
    pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
    pkmn.heal if pkmn.respond_to?(:heal)
    @peer.pbOnStartingBattle(self,pkmn,!trainer_sos) if @peer && @peer.respond_to?(:pbOnStartingBattle)
    pkmn
  end

  def bss_set_sos_chain(caller)
    if @bss_original_caller.nil?
      @bss_original_caller=caller.pokemon
      @bss_sos_chain=1
    elsif @bss_sos_chain<255
      @bss_sos_chain+=1
    end
  end

  def bss_sos_summoned_battler?(idx_battler)
    @bss_sos_summoned_indices.is_a?(Hash) && @bss_sos_summoned_indices[idx_battler.to_i] == true
  end

  def bss_sos_message(key, fallback, *args)
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    text=nil
    if bss_scripted_sos_battle? && cfg["messages"].is_a?(Hash)
      raw=cfg["messages"][key.to_s]
      text=raw.to_s if !raw.nil? && !raw.to_s.strip.empty?
    end
    text=fallback if !text || text.empty?
    begin
      return _INTL(text,*args)
    rescue
      out=text.to_s.dup
      args.each_with_index { |arg,i| out.gsub!("{#{i+1}}",arg.to_s) }
      out
    end
  end

  def bss_sos_answer_rate(caller)
    cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
    direct=cfg["answerRate"]
    return [[direct.to_i,0].max,100].min if !direct.nil? && direct.to_s!=""
    profile=bss_sos_profile(caller)
    return 100 if !profile || profile["answerRate"].nil?
    [[profile["answerRate"].to_i,0].max,100].min
  end

  def bss_call_for_help(caller, guaranteed=false, acts_this_round=false, show_intro=true)
    return false if !caller || !@bss_sos_enabled
    begin
      @scene.pbAnimateSubstitute(caller,:hide) if show_intro && @scene.respond_to?(:pbAnimateSubstitute)
    rescue
    end
    if show_intro
      pbDisplay(bss_sos_message("call","¡{1} pidió ayuda!",caller.pbThis))
      begin
        played_bas=BSS064.play_bas_sos_call(@scene,caller)
        @scene.pbAnimation(:GROWL, caller, caller.pbDirectOpposing(true)) if !played_bas
      rescue
        begin; @scene.pbAnimation(:GROWL, caller, caller.pbDirectOpposing(true)); rescue; end
      end
      pbDisplayPaused(bss_sos_message("wait","... ... ..."))
    end
    answered=guaranteed || pbRandom(100)<bss_sos_answer_rate(caller)
    if answered
      entry=bss_pick_sos_entry(caller)
      if entry
        idx,grow_side=bss_find_new_battler_slot(caller)
        if idx>=0
          pokemon=bss_generate_sos_pokemon(entry,caller)
          battler=bss_create_fresh_sos_battler(idx,caller,pokemon,grow_side)
          if battler
            @peer.pbOnEnteringBattle(self,battler,pokemon,!((trainerBattle? rescue false) && bss_scripted_sos_battle?)) if @peer && @peer.respond_to?(:pbOnEnteringBattle)
            @bss_last_call_answered=true
            @bss_sos_summoned_indices ||= {}
            @bss_sos_summoned_indices[idx] = true
            cfg=@bss_sos_config.is_a?(Hash) ? @bss_sos_config : {}
            @bss_sos_fixed_cursor=@bss_sos_fixed_cursor.to_i+1 if bss_scripted_sos_battle? && cfg["allySelectionMode"].to_s=="fixed"
            bss_set_sos_chain(caller)
            if @scene.respond_to?(:bss_pbSOSJoin)
              @scene.bss_pbSOSJoin(idx)
            else
              @scene.pbRefresh if @scene.respond_to?(:pbRefresh)
            end
            pbDisplay(bss_sos_message("success","¡Apareció {1}!",battler.name,caller.pbThis))
            begin
              @scene.pbAnimateSubstitute(caller,:show) if show_intro && @scene.respond_to?(:pbAnimateSubstitute)
            rescue
            end
            pbCalculatePriority(true)
            pbOnBattlerEnteringBattle(idx)
            # Normal SOS calls happen after the round, so the source plugin marks a
            # new battler as having already moved. BSS can also force an SOS BEFORE
            # the first command phase; in that one case it must be eligible for an
            # AI command and an action in the same first turn.
            if acts_this_round
              battler.lastRoundMoved = @turnCount.to_i - 1 if battler.respond_to?(:lastRoundMoved=)
              @choices[idx] = [:None, 0, nil, -1] if @choices.is_a?(Array) && idx < @choices.length
            end
            @scene.bss_sync_sos_side_size_state(idx) if @scene.respond_to?(:bss_sync_sos_side_size_state)
            pbSetSeen(battler)
            @scene.bss_sync_enhanced_ui_icons if @scene.respond_to?(:bss_sync_enhanced_ui_icons)
            @bss_last_turn_called=@turnCount
            return true
          end
        end
      end
    end
    @bss_last_call_answered=false
    pbDisplay(bss_sos_message("fail","¡La ayuda no apareció!",caller.pbThis))
    begin
      @scene.pbAnimateSubstitute(caller,:show) if show_intro && @scene.respond_to?(:pbAnimateSubstitute)
    rescue
    end
    @bss_last_turn_called=@turnCount
    false
  rescue => e
    BSS064.log("Native SOS call failed: #{e.class}: #{e.message}")
    BSS064.log((e.backtrace||[])[0,12].join(" | "))
    begin
      @scene.pbAnimateSubstitute(caller,:show) if show_intro && caller && @scene.respond_to?(:pbAnimateSubstitute)
    rescue
    end
    false
  end

  # One scripted SOS event can deliberately bring 1 or 2 allies. The answer roll
  # belongs to the event: once the first ally answers, the additional configured
  # allies are guaranteed, and only the first arrival repeats the call/wait intro.
  def bss_call_for_help_batch(caller, guaranteed=false, acts_this_round=false)
    count=bss_sos_summons_per_call
    first=bss_call_for_help(caller,guaranteed,acts_this_round,true)
    return false if !first
    success=true
    i=1
    while i<count
      break if bss_live_same_side_count(caller.index)>=bss_sos_max_live_same_side
      ok=bss_call_for_help(caller,true,acts_this_round,false)
      break if !ok
      success=true
      i+=1
    end
    @bss_last_call_answered=true if success
    success
  end

  unless method_defined?(:bss064_command_phase_without_native_sos) || private_method_defined?(:bss064_command_phase_without_native_sos)
    alias bss064_command_phase_without_native_sos pbCommandPhase
  end
  def pbCommandPhase(*args)
    if @bss_sos_enabled && !@bss_initial_sos_done && @bss_sos_config.is_a?(Hash) && @bss_sos_config["initialCall"]==true
      wanted=[@bss_sos_config["callRound"].to_i,1].max
      if @turnCount.to_i+1>=wanted
        @bss_initial_sos_done=true
        caller=@battlers[1] || @battlers[3] || @battlers[5]
        bss_call_for_help_batch(caller,true,true) if caller && caller.bss_can_sos_call_simple?
      end
    end
    if @bss_sos_enabled && @scene.respond_to?(:bss_sync_sos_side_size_state)
      anchor=[1,3,5].map { |i| @battlers[i] rescue nil }.find { |b| b && !(b.fainted? rescue true) }
      @scene.bss_sync_sos_side_size_state(anchor.index) if anchor && pbSideSize(anchor.index).to_i>1
    end
    bss064_command_phase_without_native_sos(*args)
  end

  unless method_defined?(:bss064_end_round_without_native_sos) || private_method_defined?(:bss064_end_round_without_native_sos)
    alias bss064_end_round_without_native_sos pbEndOfRoundPhase
  end
  def pbEndOfRoundPhase(*args)
    self.sosBattle=false if respond_to?(:sosBattle=)
    ret=bss064_end_round_without_native_sos(*args)
    self.sosBattle=false if respond_to?(:sosBattle=)
    if @bss_sos_enabled && @bss_sos_config.is_a?(Hash) && @bss_sos_config["automaticCalls"]!=false && (!bss_scripted_sos_battle? || @bss_last_call_answered!=true || bss_additional_sos_calls_allowed?) && bss_sos_runtime_battle_allowed?
      trainer_sos=(trainerBattle? rescue false) && bss_scripted_sos_battle?
      pbPriority(true).each do |b|
        next if !b || (b.fainted? rescue true)
        next if trainer_sos ? !(b.opposes? rescue false) : !(b.wild? rescue false)
        if b.bss_can_sos_call?
          bss_call_for_help_batch(b,false,false)
          b.bss_took_super_effective_damage=false
          break
        end
      end
    end
    ret
  end
end

class Battle::Battler
  attr_accessor :totemBattler unless method_defined?(:totemBattler)
  attr_accessor :bss_took_super_effective_damage

  def bss_sos_call_rate
    return 0 if !@battle.bss_sos_enabled
    cfg=@battle.bss_sos_config.is_a?(Hash) ? @battle.bss_sos_config : {}
    direct=cfg["callRate"]
    return [[direct.to_i,0].max,100].min if !direct.nil? && direct.to_s!=""
    profile=@battle.bss_sos_profile(self)
    return 0 if !profile
    [[profile["callRate"].to_i,0].max,100].min
  end

  def bss_can_sos_call?
    return false if !@battle.bss_sos_enabled
    trainer_sos=(@battle.trainerBattle? rescue false) && @battle.bss_scripted_sos_battle?
    return false if (@battle.trainerBattle? rescue false) && !trainer_sos
    return false if !trainer_sos && !(wild? rescue false)
    return false if !opposes? || fainted? || usingMultiTurnAttack?
    return false if @battle.bss_live_same_side_count(@index)>=@battle.bss_sos_max_live_same_side
    return false if respond_to?(:pbHasAnyStatus?) && pbHasAnyStatus?
    return false if bss_sos_call_rate<=0
    return false if @battle.bss_last_call_answered && !@battle.bss_additional_sos_calls_allowed?
    return false if @battle.bss_sos_summoned_battler?(@index) && !@battle.bss_recursive_sos_calls_allowed?
    rate=bss_sos_call_rate
    rate*=5 if hp<=totalhp/4
    rate*=3 if hp>totalhp/4 && hp<=totalhp/2
    rate*=2 if @battle.bss_adrenaline_orb
    @battle.pbRandom(100)<[rate,100].min
  end

  def bss_can_sos_call_simple?
    return false if !@battle.bss_sos_enabled
    trainer_sos=(@battle.trainerBattle? rescue false) && @battle.bss_scripted_sos_battle?
    return false if (@battle.trainerBattle? rescue false) && !trainer_sos
    return false if !trainer_sos && !(wild? rescue false)
    return false if !opposes? || fainted? || usingMultiTurnAttack?
    return false if @battle.bss_last_call_answered && !@battle.bss_additional_sos_calls_allowed?
    return false if @battle.bss_sos_summoned_battler?(@index) && !@battle.bss_recursive_sos_calls_allowed?
    @battle.bss_live_same_side_count(@index)<@battle.bss_sos_max_live_same_side
  end
end

#===============================================================================
# Scene-side dynamic battler support.
# Enhanced Battle UI assumes every live battler has info_icon#{index}. BSS creates
# that icon at the same point as the supplied SOS scene code and also performs a
# defensive sync immediately before Enhanced UI hides its UI.
#===============================================================================
class Battle::Scene
  def bss_raise_target_menu_z
    win = @sprites.is_a?(Hash) ? @sprites["targetWindow"] : nil
    return false if !win
    z = 10000
    win.z = z if win.respond_to?(:z=)
    win.instance_variables.each do |ivar|
      obj = win.instance_variable_get(ivar) rescue nil
      rows = obj.is_a?(Hash) ? obj.values : (obj.is_a?(Array) ? obj : [obj])
      rows.compact.each do |child|
        child.z = [child.z.to_i, z].max if child.respond_to?(:z=) && child.respond_to?(:z)
      end
    end
    true
  rescue => e
    BSS064.log("Target menu z warning: #{e.class}: #{e.message}")
    false
  end

  def bss_ensure_enhanced_ui_icon(idx_battler)
    battler = @battle.battlers[idx_battler] rescue nil
    return false if !battler || !@sprites.is_a?(Hash)
    key = "info_icon#{idx_battler}"
    return true if @sprites[key]
    return false if !defined?(PokemonIconSprite)
    # Only create these compatibility icons when Enhanced Battle UI is present.
    return false if !respond_to?(:pbHideInfoUI) && !@sprites["enhancedUI"]
    icon = PokemonIconSprite.new(battler.pokemon, @viewport)
    icon.setOffset(PictureOrigin::CENTER) if defined?(PictureOrigin) && icon.respond_to?(:setOffset)
    icon.visible = false
    icon.z = 300 if icon.respond_to?(:z=)
    @sprites[key] = icon
    begin
      pbAddSpriteOutline([key, @viewport, battler.pokemon, PictureOrigin::CENTER]) if respond_to?(:pbAddSpriteOutline) && defined?(PictureOrigin)
    rescue
    end
    true
  rescue => e
    BSS064.log("Enhanced UI icon warning idx=#{idx_battler}: #{e.class}: #{e.message}")
    false
  end

  def bss_sync_enhanced_ui_icons
    return if !@battle
    @battle.allBattlers.each { |b| bss_ensure_enhanced_ui_icon(b.index) if b }
  rescue => e
    BSS064.log("Enhanced UI sync warning: #{e.class}: #{e.message}")
  end

  # Keep the internal formation size stored by BattlerSprite/ShadowSprite in sync
  # with Battle#sideSizes without touching x/y/z.  The stock sprite classes cache
  # @sideSize and setPokemonBitmap -> pbSetPosition uses that cached value.  If it
  # stays at 1 after an SOS expands the side, any move animation that reloads a
  # battler bitmap resets the caller to its old singles position.
  #
  # IMPORTANT: this method deliberately does not reposition sprites.  Formation
  # changes are animated by BSSSOSJoin, exactly like the source SOS plugin, so the
  # caller glides into doubles/triples instead of being corrected by a visible TP.
  def bss_sync_sos_side_size_state(idx_battler)
    return false if !@battle || !@sprites
    side_size = @battle.pbSideSize(idx_battler).to_i
    side_size = [[side_size, 1].max, 3].min
    @battle.allSameSideBattlers(idx_battler).each do |b|
      next if !b
      bat = @sprites["pokemon_#{b.index}"]
      sha = @sprites["shadow_#{b.index}"]
      bat.sideSize = side_size if bat && bat.respond_to?(:sideSize=)
      sha.sideSize = side_size if sha && sha.respond_to?(:sideSize=)
    end
    true
  rescue => e
    BSS064.log("SOS side-size sync warning: #{e.class}: #{e.message}")
    false
  end

  # Compatibility with 0.6.17 callers.  This used to hard-set x/y/z and caused
  # the visible post-call teleport.  It is now intentionally state-only.
  def bss_snap_sos_side_positions(idx_battler)
    bss_sync_sos_side_size_state(idx_battler)
  end

  def bss_pbPrepNewBattler(idx_battler)
    pbRefresh
    battler = @battle.battlers[idx_battler]
    add_new_battler = !@sprites["dataBox_#{idx_battler}"]
    if add_new_battler
      begin
        @sprites["targetWindow"].dispose if @sprites["targetWindow"] && !@sprites["targetWindow"].disposed?
      rescue
      end
      if defined?(TargetMenu)
        @sprites["targetWindow"] = TargetMenu.new(@viewport, 10000, @battle.sideSizes)
        @sprites["targetWindow"].visible = false
        bss_raise_target_menu_z
      end
      pbCreatePokemonSprite(idx_battler)
      bss_ensure_enhanced_ui_icon(idx_battler)
    else
      begin
        @sprites["pokemon_#{idx_battler}"].dispose if @sprites["pokemon_#{idx_battler}"]
      rescue
      end
      begin
        @sprites["shadow_#{idx_battler}"].dispose if @sprites["shadow_#{idx_battler}"]
      rescue
      end
      pbCreatePokemonSprite(idx_battler)
    end
    @sprites["pokemon_#{idx_battler}"].visible = false if @sprites["pokemon_#{idx_battler}"]
    @sprites["shadow_#{idx_battler}"].visible = false if @sprites["shadow_#{idx_battler}"]
    side_size = @battle.pbSideSize(idx_battler)
    bss_sync_sos_side_size_state(idx_battler)
    @battle.allSameSideBattlers(idx_battler).each do |b|
      bat_sprite = @sprites["pokemon_#{b.index}"]
      sha_sprite = @sprites["shadow_#{b.index}"]
      bat_sprite.sideSize = side_size if bat_sprite && bat_sprite.respond_to?(:sideSize=)
      sha_sprite.sideSize = side_size if sha_sprite && sha_sprite.respond_to?(:sideSize=)
      if add_new_battler
        begin
          @sprites["dataBox_#{b.index}"].dispose if @sprites["dataBox_#{b.index}"]
        rescue
        end
        @sprites["dataBox_#{b.index}"] = PokemonDataBox.new(b, side_size, @viewport)
      else
        box = @sprites["dataBox_#{b.index}"]
        if box
          box.battler = b if box.respond_to?(:battler=)
          box.visible = bat_sprite.visible if bat_sprite
          box.refresh if box.respond_to?(:refresh)
        end
      end
      @sprites["dataBox_#{b.index}"].update if @sprites["dataBox_#{b.index}"]
      bss_ensure_enhanced_ui_icon(b.index)
    end
    bss_sync_enhanced_ui_icons
    bss_raise_target_menu_z
    add_new_battler
  end

  def bss_pbSOSJoin(idx_battler)
    add_new_battler = bss_pbPrepNewBattler(idx_battler)
    battler = @battle.battlers[idx_battler]
    pbChangePokemon(idx_battler, battler.displayPokemon)
    sos_anim = Battle::Scene::Animation::BSSSOSJoin.new(@sprites, @viewport, @battle, battler.index, add_new_battler)
    @animations.push(sos_anim)
    while inPartyAnimation?
      pbUpdate
    end
    bss_sync_sos_side_size_state(idx_battler)
    show_anims = if @battle.respond_to?(:showAnims)
                   (@battle.showAnims rescue true)
                 elsif @battle.instance_variable_defined?(:@showAnims)
                   (@battle.instance_variable_get(:@showAnims) rescue true)
                 else
                   true
                 end
    if show_anims && battler.shiny?
      begin
        pbCommonAnimation("Shiny", battler)
      rescue
      end
    end
    bss_raise_target_menu_z
    bss_sync_enhanced_ui_icons
  end
end

class Battle::Scene::BattlerSprite < RPG::Sprite
  # Essentials v21.1 already defines attr_reader :sideSize.  Checking only for
  # `sideSize` therefore skipped creation of the writer in older BSS builds.
  # Keep @sideSize mutable so every later setPokemonBitmap/pbSetPosition uses the
  # live SOS formation instead of the original singles formation.
  def sideSize=(value)
    @sideSize = [[value.to_i, 1].max, 3].min
  end unless method_defined?(:sideSize=)
end
class Battle::Scene::BattlerShadowSprite < RPG::Sprite
  def sideSize=(value)
    @sideSize = [[value.to_i, 1].max, 3].min
  end unless method_defined?(:sideSize=)

  def sideSize
    @sideSize
  end unless method_defined?(:sideSize)
end

module Battle::Scene::Animation::BSSSOSPositionMixin
  # Ask the ACTUAL battler/shadow sprite class where it would settle for the
  # current side size, then restore the visible coordinates before Graphics.update.
  # This is intentionally a same-frame probe: DBK/LBDS/custom BattlerSprite
  # overrides remain the authority for X/Y/Z and there is no visible teleport.
  def bss_probe_native_sprite_position(sprite, side_size)
    return nil if !sprite || !sprite.respond_to?(:pbSetPosition)
    old_x = sprite.x rescue nil
    old_y = sprite.y rescue nil
    old_z = sprite.z rescue nil
    sprite.sideSize = side_size if sprite.respond_to?(:sideSize=)
    sprite.pbSetPosition
    target = [sprite.x, sprite.y, sprite.z]
    sprite.x = old_x if !old_x.nil? && sprite.respond_to?(:x=)
    sprite.y = old_y if !old_y.nil? && sprite.respond_to?(:y=)
    sprite.z = old_z if !old_z.nil? && sprite.respond_to?(:z=)
    target
  rescue => e
    BSS064.log("SOS native position probe warning: #{e.class}: #{e.message}")
    begin
      sprite.x = old_x if !old_x.nil? && sprite.respond_to?(:x=)
      sprite.y = old_y if !old_y.nil? && sprite.respond_to?(:y=)
      sprite.z = old_z if !old_z.nil? && sprite.respond_to?(:z=)
    rescue
    end
    nil
  end

  def bss_sos_battler_position(b, side_size, battler_sprite=nil)
    native = bss_probe_native_sprite_position(battler_sprite, side_size)
    return native if native
    # Vanilla-compatible fallback used only if the project's sprite has no
    # pbSetPosition API. Keep it source-faithful to Essentials/SOS Battles.
    p = Battle::Scene.pbBattlerPosition(b.index, side_size)
    new_x, new_y = p[0], p[1]
    metrics = nil
    begin
      if defined?(PluginManager) && PluginManager.respond_to?(:installed?) && PluginManager.installed?("[DBK] Animated Pokémon System")
        if b.respond_to?(:battlerSprite) && b.battlerSprite && b.battlerSprite.respond_to?(:substitute) && b.battlerSprite.substitute
          new_y += Settings::SUBSTITUTE_DOLL_METRICS[1] if defined?(Settings::SUBSTITUTE_DOLL_METRICS)
        else
          metrics = GameData::SpeciesMetrics.get_species_form(b.species, b.form, b.gender == 1) rescue nil
        end
      else
        metrics = GameData::SpeciesMetrics.get_species_form(b.species, b.form) rescue nil
      end
    rescue
      metrics = GameData::SpeciesMetrics.get_species_form(b.species, b.form) rescue nil
    end
    if metrics
      if metrics.respond_to?(:front_sprite)
        fs = metrics.front_sprite rescue nil
        if fs
          new_x += fs[0].to_i * 2
          new_y += fs[1].to_i * 2
        end
      end
      alt = metrics.respond_to?(:front_sprite_altitude) ? (metrics.front_sprite_altitude rescue 0) : 0
      new_y -= alt.to_i * 2
    end
    new_z = 50 - (5 * (b.index + 1) / 2)
    [new_x, new_y, new_z]
  end

  def bss_sos_shadow_position(b, side_size, shadow_sprite=nil)
    native = bss_probe_native_sprite_position(shadow_sprite, side_size)
    return native if native
    p = Battle::Scene.pbBattlerPosition(b.index, side_size)
    new_x, new_y, new_z = p[0], p[1], 3
    begin
      if defined?(PluginManager) && PluginManager.respond_to?(:installed?) && PluginManager.installed?("[DBK] Animated Pokémon System")
        substituted = b.respond_to?(:battlerSprite) && b.battlerSprite && b.battlerSprite.respond_to?(:substitute) && b.battlerSprite.substitute
        if !substituted
          metrics = GameData::SpeciesMetrics.get_species_form(b.species, b.form, b.gender == 1) rescue nil
          if metrics
            fs = metrics.front_sprite rescue nil
            ss = metrics.shadow_sprite rescue nil
            new_x += (fs ? fs[0].to_i * 2 : 0) + (ss ? ss[0].to_i * 2 : 0)
            new_y += (fs ? fs[1].to_i * 2 : 0) + (ss ? ss[2].to_i * 2 : 0)
            new_y -= (shadow_sprite.height / 4).round if shadow_sprite && shadow_sprite.respond_to?(:height)
          end
        end
      else
        metrics = GameData::SpeciesMetrics.get_species_form(b.species, b.form) rescue nil
        new_x += metrics.shadow_x.to_i * 2 if metrics && metrics.respond_to?(:shadow_x)
      end
    rescue
    end
    [new_x, new_y, new_z]
  end
end

class Battle::Scene::Animation::BSSSOSJoin < Battle::Scene::Animation
  include Battle::Scene::Animation::BSSSOSPositionMixin
  def initialize(sprites, viewport, battle, idx_sos, add_new)
    @battle = battle
    @idx_sos = idx_sos
    @add_new = add_new
    super(sprites, viewport)
  end

  def createProcesses
    delay = 0
    @battle.battlers.each do |b|
      next if !b || b.opposes?(@idx_sos)
      bat = @sprites["pokemon_#{b.index}"]
      sha = @sprites["shadow_#{b.index}"]
      boxsp = @sprites["dataBox_#{b.index}"]
      next if !bat
      if b.index == @idx_sos
        side_size = bat.respond_to?(:sideSize) && bat.sideSize ? bat.sideSize : @battle.pbSideSize(b.index)
        _nx, _ny, native_z = bss_sos_battler_position(b, side_size, bat)
        obj = addSprite(bat, PictureOrigin::BOTTOM)
        obj.setZ(delay, native_z) if obj.respond_to?(:setZ)
        obj.setTone(delay, Tone.new(-196, -196, -196, -196))
        obj.setOpacity(delay, 0)
        obj.setVisible(delay, true)
        obj.moveOpacity(delay, 4, 255)
        obj.moveTone(delay + 4, 10, Tone.new(0, 0, 0, 0), [bat, :pbPlayIntroAnimation])
        if sha
          sha.visible = false
          _sx, _sy, native_shadow_z = bss_sos_shadow_position(b, side_size, sha)
          sh = addSprite(sha, PictureOrigin::CENTER)
          sh.setZ(delay, native_shadow_z) if sh.respond_to?(:setZ)
          sh.setOpacity(delay, 0)
          sh.setVisible(delay, true)
          sh.moveOpacity(delay, 4, 255)
        end
        if boxsp
          dir = b.index.even? ? 1 : -1
          bx = addSprite(boxsp)
          bx.setDelta(delay, dir * Graphics.width / 2, 0)
          bx.setVisible(delay, true)
          bx.moveDelta(delay, 8, -dir * Graphics.width / 2, 0)
        end
      else
        side_size = bat.respond_to?(:sideSize) && bat.sideSize ? bat.sideSize : @battle.pbSideSize(b.index)
        new_x, new_y, new_z = bss_sos_battler_position(b, side_size, bat)
        obj = addSprite(bat, PictureOrigin::BOTTOM)
        obj.setZ(delay, new_z) if obj.respond_to?(:setZ)
        obj.moveXY(delay, 4, new_x, new_y)
        if sha
          shadow_size = sha.respond_to?(:sideSize) && sha.sideSize ? sha.sideSize : side_size
          sx, sy, sz = bss_sos_shadow_position(b, shadow_size, sha)
          sh = addSprite(sha, PictureOrigin::CENTER)
          sh.setZ(delay, sz) if sh.respond_to?(:setZ)
          sh.moveXY(delay, 4, sx, sy)
        end
        if boxsp
          bx = addSprite(boxsp)
          bx.setVisible(delay, true) if !b.fainted?
        end
      end
      delay += 1
    end
  end
end

# Run before Enhanced Battle UI's pbHideInfoUI loop. It expects a non-nil icon
# for every battler returned by allBattlers, including the newly inserted SOS.
#===============================================================================
# Animation compatibility: keep formation metadata current before any scene move
# or common animation.  BAS continues to own its anchors, priorityReference, Z,
# target replication and restoration.  BSS only fixes the stale sideSize state
# that made BAS capture/restore a singles position after an SOS had joined.
#===============================================================================
module BSS064AnimationFormationCompat
  def pbAnimation(move_id, user, targets, *args)
    begin
      anchor = user || (targets.is_a?(Array) ? targets.compact[0] : targets)
      if anchor && @battle && @battle.respond_to?(:bss_sos_enabled) && @battle.bss_sos_enabled
        bss_sync_sos_side_size_state(anchor.index) if respond_to?(:bss_sync_sos_side_size_state)
      end
    rescue
    end
    super
  end

  def pbCommonAnimation(anim_name, user = nil, target = nil, *args)
    begin
      anchor = user || target
      if anchor && @battle && @battle.respond_to?(:bss_sos_enabled) && @battle.bss_sos_enabled
        bss_sync_sos_side_size_state(anchor.index) if respond_to?(:bss_sync_sos_side_size_state)
      end
    rescue
    end
    super
  end
end

module BSS064EnhancedUICompat
  def pbHideInfoUI(*args)
    bss_sync_enhanced_ui_icons if respond_to?(:bss_sync_enhanced_ui_icons)
    super
  end
end

module BSS064
  class << self
    def install_enhanced_ui_compat
      return false if !defined?(Battle::Scene)
      if !Battle::Scene.ancestors.include?(BSS064AnimationFormationCompat)
        Battle::Scene.prepend(BSS064AnimationFormationCompat)
      end
      if Battle::Scene.method_defined?(:pbHideInfoUI) && !Battle::Scene.ancestors.include?(BSS064EnhancedUICompat)
        Battle::Scene.prepend(BSS064EnhancedUICompat)
      end
      true
    rescue => e
      log("Enhanced UI compat install warning: #{e.class}: #{e.message}")
      false
    end
  end
end
BSS064.install_enhanced_ui_compat
if defined?(EventHandlers)
  EventHandlers.add(:on_game_load, :bss_064_enhanced_ui_compat, proc { BSS064.install_enhanced_ui_compat })
end

class Battle::Move
  unless method_defined?(:bss064_effectiveness_without_sos_flag) || private_method_defined?(:bss064_effectiveness_without_sos_flag)
    alias bss064_effectiveness_without_sos_flag pbEffectivenessMessage
  end
  def pbEffectivenessMessage(user, target, numTargets = 1)
    bss064_effectiveness_without_sos_flag(user, target, numTargets)
    return if !target || !(target.wild? rescue false)
    ds = target.damageState rescue nil
    return if !ds
    return if (ds.disguise rescue false) || (ds.iceFace rescue false)
    target.bss_took_super_effective_damage = true if Effectiveness.super_effective?(ds.typeMod) rescue nil
  end
end

if defined?(ItemHandlers) && defined?(GameData::Item) && (GameData::Item.exists?(:ADRENALINEORB) rescue false)
  ItemHandlers::CanUseInBattle.add(:ADRENALINEORB, proc { |_item, _pokemon, _battler, _move, _firstAction, _battle, _scene, _showMessages| next true })
  ItemHandlers::UseInBattle.add(:ADRENALINEORB, proc { |item, battler, battle|
    if battle.bss_adrenaline_orb
      battle.pbDisplay(_INTL("¡Pero no tuvo efecto!"))
      battle.pbReturnUnusedItemToBag(item, battler.index) rescue nil
    else
      battle.pbDisplay(_INTL("¡El {1} pone nervioso al Pokémon salvaje!", GameData::Item.get(item).portion_name))
      battle.bss_adrenaline_orb = true
    end
  })
end
