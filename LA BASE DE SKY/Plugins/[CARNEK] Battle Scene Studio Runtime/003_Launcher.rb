#===============================================================================
# Battle Scene Studio 0.6.56 - Phase 1 launcher
# Normal battles + BSS-native SOS only.
#===============================================================================

# Per-battle scene extensions. They are prepended to the scene singleton only
# for BSS battles, so ordinary Essentials/DBK battles are untouched.
module BSS064SceneEnvironmentCompat
  def pbCreateBackdropSprites(*args,&block)
    result=super
    cfg=(@battle.respond_to?(:bss_environment_config) ? @battle.bss_environment_config : nil) rescue nil
    cfg={} if !cfg.is_a?(Hash)
    custom=cfg["backgroundGraphic"].to_s.strip.tr("\\","/")
    if !custom.empty? && custom =~ /\AGraphics\/.+\.(?:png|gif|jpg|jpeg|webp|bmp)\z/i
      begin
        bg=@sprites["battle_bg"]
        bg.setBitmap(custom) if bg && bg.respond_to?(:setBitmap)
        bg2=@sprites["battle_bg2"]
        bg2.setBitmap(custom) if bg2 && bg2.respond_to?(:setBitmap)
      rescue => e
        BSS064.log("Custom battle background warning: #{e.class}: #{e.message}")
      end
    end
    # Global visual settings are edited outside the running battle process. Read
    # the current battles.json once at scene creation instead of leaving a stale
    # cached value active across later ordinary encounters.
    begin;BSS064.clear_cache if defined?(BSS064) && BSS064.respond_to?(:clear_cache);rescue;end
    show_bases=true
    mode=cfg["basesMode"].to_s
    if mode=="off"
      show_bases=false
    elsif mode=="on"
      show_bases=true
    else
      begin
        global=BSS064.data["global"]
        show_bases=(global.is_a?(Hash) ? global["battleBasesEnabled"]!=false : true)
      rescue
        show_bases=true
      end
    end
    if !show_bases
      ["base_0","base_1"].each do |key|
        sp=@sprites[key] rescue nil
        next if !sp
        sp.visible=false if sp.respond_to?(:visible=)
        sp.opacity=0 if sp.respond_to?(:opacity=)
      end
    end
    result
  end

  def bss_victory_subject_name
    battle=@battle
    return "Pokémon" if !battle
    if battle.respond_to?(:bss_boss_enabled?) && battle.bss_boss_enabled?
      return battle.bss_boss_name_for_intro.to_s if battle.respond_to?(:bss_boss_name_for_intro)
    end
    begin
      party=battle.pbParty(1)
      pkmn=party && party[0]
      return pkmn.name.to_s if pkmn
    rescue
    end
    "Pokémon"
  end

  def bss_custom_victory_bgm_name
    battle=@battle
    env=(battle && battle.respond_to?(:bss_environment_config)) ? battle.bss_environment_config : nil
    env={} if !env.is_a?(Hash)
    name=env["victoryBgm"].to_s.strip.tr("\\","/")
    name=name.sub(%r{\A(?:Audio/)?BGM/}i,"")
    name=name.sub(/\.(?:ogg|mp3|wav|mid|midi|flac|opus|m4a)\z/i,"")
    name
  rescue
    ""
  end

  def bss_play_custom_victory_bgm
    name=bss_custom_victory_bgm_name
    return false if name.empty?
    pbBGMPlay(name)
    true
  rescue => e
    BSS064.log("Custom victory BGM warning: #{e.class}: #{e.message}")
    false
  end

  def bss_play_player_victory_celebration
    battle=@battle
    return if !battle
    battler=nil
    sp=nil
    pkmn=nil
    begin
      rows=battle.battlers
      if rows.respond_to?(:compact)
        rows.compact.each do |candidate|
          idx=(candidate.index rescue -1).to_i
          next if idx < 0 || !idx.even?
          next if (candidate.fainted? rescue true)
          next if (candidate.respond_to?(:hp) && candidate.hp.to_i <= 0 rescue true)
          sprite=@sprites["pokemon_#{idx}"] rescue nil
          next if !sprite || (sprite.disposed? rescue true)
          next if sprite.respond_to?(:visible) && !sprite.visible
          next if sprite.respond_to?(:opacity) && sprite.opacity.to_i <= 0
          mon=(candidate.visiblePokemon rescue nil) if candidate.respond_to?(:visiblePokemon)
          mon ||= (candidate.pokemon rescue nil) if candidate.respond_to?(:pokemon)
          next if !mon
          battler=candidate
          sp=sprite
          pkmn=mon
          break
        end
      end
    rescue
      battler=nil
      sp=nil
      pkmn=nil
    end
    # If Explosion/Self-Destruct (or another effect) leaves the player's side
    # with no living Pokémon actually visible on the field, there is nobody
    # to celebrate: do not play a reserve Pokémon's cry.
    return if !battler || !sp || !pkmn
    idx=(battler.index rescue 0).to_i
    begin
      if defined?(GameData::Species) && GameData::Species.respond_to?(:play_cry_from_pokemon)
        GameData::Species.play_cry_from_pokemon(pkmn)
      elsif pkmn.respond_to?(:play_cry)
        pkmn.play_cry
      end
    rescue
    end
    base_y=(sp.y rescue 0).to_f
    started=BSS064.respond_to?(:monotonic_seconds) ? BSS064.monotonic_seconds : Time.now.to_f
    duration=0.56
    loop do
      now=BSS064.respond_to?(:monotonic_seconds) ? BSS064.monotonic_seconds : Time.now.to_f
      elapsed=now-started
      break if elapsed>=duration
      phase=elapsed/duration
      # Two small celebratory hops, always clocked in real/unscaled time.
      hop=(Math.sin(phase*Math::PI*4.0)).abs
      sp.y=base_y-(hop*10.0)
      pbUpdate
    end
  rescue => e
    BSS064.log("Victory celebration warning: #{e.class}: #{e.message}")
  ensure
    begin;sp.y=base_y if sp && !(sp.disposed? rescue true) && !base_y.nil?;rescue;end
  end

  def bss_custom_victory_sequence
    return if @bss_custom_victory_done
    battle=@battle
    # This scene module is installed globally so ordinary battles can honor the
    # BSS global battleback/battlebox settings. Victory authoring remains strictly
    # Blueprint-owned; never inject an extra BSS celebration into a normal battle.
    return if !battle || !battle.respond_to?(:bss_blueprint) || !battle.bss_blueprint
    setup=(battle.respond_to?(:bss_setup_config) ? battle.bss_setup_config : nil) rescue nil
    setup={} if !setup.is_a?(Hash)
    msg=setup["victoryMessage"].to_s
    celebrate=setup["victoryCelebration"]!=false
    # A Boss/Dominant that is declined and then fainted is still defeated.
    # Therefore it uses the exact same authored victory celebration as any
    # other successful battle unless victoryCelebration itself is disabled.
    return if msg.empty? && !celebrate
    @bss_custom_victory_done=true
    bss_play_player_victory_celebration if celebrate
    if !msg.empty? && battle && battle.respond_to?(:pbDisplayPaused)
      battle.pbDisplayPaused(msg.gsub("{1}",bss_victory_subject_name))
    end
  rescue => e
    BSS064.log("Custom victory sequence warning: #{e.class}: #{e.message}")
  end

  def pbWildBattleSuccess(*args,&block)
    result=super
    bss_play_custom_victory_bgm
    bss_custom_victory_sequence
    result
  end

  def pbTrainerBattleSuccess(*args,&block)
    result=super
    bss_play_custom_victory_bgm
    bss_custom_victory_sequence
    result
  end
end

module BSS064BattleVictoryBGMCompat
  # The editor normally stores a path relative to Audio/BGM without extension,
  # but older BSS builds/manual entries may contain Audio/BGM/... or the file
  # extension. Essentials' pbBGMPlay expects the relative logical BGM name.
  def bss_result_bgm_name(value)
    name=value.to_s.strip.tr("\\","/")
    name=name.sub(%r{\A(?:Audio/)?BGM/}i,"")
    name=name.sub(/\.(?:ogg|mp3|wav|mid|midi|flac|opus|m4a)\z/i,"")
    name
  rescue
    value.to_s.strip
  end

  def pbEndOfBattle(*args,&block)
    begin
      env=respond_to?(:bss_environment_config) ? bss_environment_config : nil
      env={} if !env.is_a?(Hash)
      if @decision==Battle::Outcome::WIN
        name=bss_result_bgm_name(env["victoryBgm"])
        if !name.empty? && defined?($PokemonGlobal) && $PokemonGlobal
          $PokemonGlobal.nextBattleVictoryBGM=pbStringToAudioFile(name)
        end
      elsif @decision==Battle::Outcome::LOSE || @decision==Battle::Outcome::DRAW
        # Essentials has no native "next defeat BGM" equivalent. Start the BSS
        # track before the base loss flow so it plays under the loss message and
        # is then faded normally by Scene#pbEndBattle.
        name=bss_result_bgm_name(env["defeatBgm"])
        pbBGMPlay(name) if !name.empty?
      end
    rescue => e
      BSS064.log("Battle result BGM warning: #{e.class}: #{e.message}")
    end
    super
  end
end
#===============================================================================
# BSS v0.6.74 - real BattleBox slide driver.
#
# PictureEx#setDelta works for Fade/normal sprites, but many project/DBK databox
# classes recalculate their real x/y from @spriteX/@spriteY every #update. That
# silently overwrites a PictureEx slide. The driver below applies the horizontal
# camera-space offset AFTER the databox' own update, so Vanilla, DBK and custom
# skins cannot erase it. Timing uses the unscaled clock, therefore Sky Turbo
# cannot compress the slide into an invisible one-frame jump.
#===============================================================================
module BSS074DataBoxSlideDriver
  def bss074_slide_unapply
    dx=(@bss074_slide_applied_x || 0).to_f
    if dx!=0.0 && respond_to?(:x) && respond_to?(:x=)
      self.x=self.x.to_f-dx
    end
    @bss074_slide_applied_x=0.0
  rescue
    @bss074_slide_applied_x=0.0
  end

  def bss074_begin_slide(phase,dir,duration=0.22)
    bss074_slide_unapply
    @bss074_slide_state={
      :phase=>phase.to_sym,
      :dir=>(dir.to_i<0 ? -1 : 1),
      :started=>(BSS064.respond_to?(:monotonic_seconds) ? BSS064.monotonic_seconds : Time.now.to_f),
      :duration=>[duration.to_f,0.08].max,
      :hide_when_done=>false
    }
    true
  rescue
    false
  end

  def bss074_slide_active?
    @bss074_slide_state.is_a?(Hash)
  end

  def bss074_clear_slide
    bss074_slide_unapply
    @bss074_slide_state=nil
    true
  rescue
    @bss074_slide_state=nil
    false
  end

  def visible=(value)
    state=@bss074_slide_state
    if value==false && state.is_a?(Hash) && state[:phase]==:out
      now=(BSS064.respond_to?(:monotonic_seconds) ? BSS064.monotonic_seconds : Time.now.to_f)
      if now-state[:started].to_f < state[:duration].to_f
        state[:hide_when_done]=true
        return (visible rescue true)
      end
    end
    ret=super(value)
    bss074_clear_slide if value==false && @bss074_slide_state
    ret
  end

  def bss074_apply_slide
    state=@bss074_slide_state
    return if !state.is_a?(Hash)
    now=(BSS064.respond_to?(:monotonic_seconds) ? BSS064.monotonic_seconds : Time.now.to_f)
    duration=[state[:duration].to_f,0.001].max
    p=(now-state[:started].to_f)/duration
    p=0.0 if p<0.0
    p=1.0 if p>1.0
    # ease-out cubic = readable initial motion without a stiff linear glide.
    ease=1.0-((1.0-p)**3)
    fraction=(state[:phase]==:in ? (1.0-ease) : ease)
    dist=(Graphics.width.to_f*0.52)
    dx=(state[:dir].to_i*dist*fraction)
    self.x=self.x.to_f+dx if respond_to?(:x) && respond_to?(:x=)
    @bss074_slide_applied_x=dx
    return if p<1.0
    if state[:phase]==:in
      # At the final frame the offset is already 0, so hand authority back to
      # the databox class without changing its resolved native/style position.
      @bss074_slide_state=nil
      @bss074_slide_applied_x=0.0
    elsif state[:hide_when_done]
      @bss074_slide_state=nil
      bss074_slide_unapply
      begin
        @bss074_allow_hide=true
        self.visible=false
      ensure
        @bss074_allow_hide=false
      end
    end
  rescue => e
    BSS064.log("BattleBox real slide warning: #{e.class}: #{e.message}") if defined?(BSS064)
    bss074_clear_slide rescue nil
  end

  def update(*args,&block)
    bss074_slide_unapply if @bss074_slide_state
    ret=super
    bss074_apply_slide if @bss074_slide_state
    ret
  end
end

#===============================================================================
# BSS v0.6.73 - global BattleBox animation authority and unscaled battle handoff.
# These hooks are installed only after the full plugin stack has loaded. This is
# important in projects where DBK/Databox Styles aliases DataBoxAppear later than
# BSS itself: the final hook must sit above the completed project chain.
#===============================================================================
module BSS073GlobalDataBoxAppear
  def createProcesses
    box=@sprites["dataBox_#{@idxBox}"] rescue nil
    return if !box
    # BSS BossHUD replaces only the Boss' native databox. Helpers and ordinary
    # battlers must continue through the globally selected BattleBox animation.
    begin
      battler=(box.battler rescue nil)
      battle=(battler.instance_variable_get(:@battle) rescue nil) if battler
      if battler && battle && battle.respond_to?(:bss_blueprint) && battle.bss_blueprint &&
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
      BSS064.log("Global DataBoxAppear BossHUD guard warning: #{e.class}: #{e.message}") if defined?(BSS064)
    end

    mode=(BSS064.databox_animation_mode rescue "slide")
    obj=addSprite(box)
    case mode
    when "pop"
      obj.setOpacity(0,255) if obj.respond_to?(:setOpacity)
      obj.setVisible(0,true)
    when "fade"
      obj.setOpacity(0,0)
      obj.setVisible(0,true)
      obj.moveOpacity(0,8,255)
    else
      # 0.6.74: slide the REAL databox after its own update instead of
      # PictureEx#setDelta (custom/DBK boxes frequently overwrite that x value).
      idx=((box.battler.index rescue @idxBox).to_i rescue @idxBox.to_i)
      dir=idx.even? ? 1 : -1
      BSS064.ensure_databox_slide_driver(box) if BSS064.respond_to?(:ensure_databox_slide_driver)
      box.bss074_begin_slide(:in,dir) if box.respond_to?(:bss074_begin_slide)
      obj.setOpacity(0,255) if obj.respond_to?(:setOpacity)
      obj.setVisible(0,true)
      # Keep the animation process alive while the real-time driver moves it.
      obj.moveDelta(0,10,0,0) if obj.respond_to?(:moveDelta)
    end
  rescue => e
    BSS064.log("Global DataBoxAppear 0.6.73 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    super
  end
end

module BSS073GlobalDataBoxDisappear
  def createProcesses
    box=@sprites["dataBox_#{@idxBox}"] rescue nil
    return if !box || (box.respond_to?(:visible) && !box.visible)
    mode=(BSS064.databox_animation_mode rescue "slide")
    obj=addSprite(box)
    case mode
    when "pop"
      obj.setVisible(0,false)
      obj.setOpacity(0,255) if obj.respond_to?(:setOpacity)
    when "fade"
      obj.moveOpacity(0,8,0)
      obj.setVisible(8,false)
      # Reset opacity after it is hidden so a later rebind/reuse starts clean.
      obj.setOpacity(8,255) if obj.respond_to?(:setOpacity)
    else
      idx=((box.battler.index rescue @idxBox).to_i rescue @idxBox.to_i)
      dir=idx.even? ? 1 : -1
      BSS064.ensure_databox_slide_driver(box) if BSS064.respond_to?(:ensure_databox_slide_driver)
      box.bss074_begin_slide(:out,dir) if box.respond_to?(:bss074_begin_slide)
      obj.moveDelta(0,10,0,0) if obj.respond_to?(:moveDelta)
      obj.setVisible(10,false)
    end
  rescue => e
    BSS064.log("Global DataBoxDisappear 0.6.73 warning: #{e.class}: #{e.message}") if defined?(BSS064)
    super
  end
end

module BSS073BattleAnimationHandoff
  def pbBattleAnimation(*args,&block)
    return super(*args,&block) if !block
    handoff=nil
    wrapped=proc do |*yield_args|
      result=block.call(*yield_args)
      # Create an opaque top-level overlay BEFORE the base transition resumes.
      # Even if Sky Turbo compresses the base return fade to one frame, the map
      # remains covered until BSS performs its own real-clock reveal afterward.
      handoff=BSS064.bss073_begin_battle_handoff rescue nil
      result
    end
    result=super(*args,&wrapped)
    if handoff
      BSS064.bss073_finish_battle_handoff(handoff)
      handoff=nil
    end
    result
  ensure
    BSS064.bss073_cleanup_battle_handoff(handoff) if handoff && defined?(BSS064)
  end
end

#===============================================================================
# BSS v0.6.74 - EBDX-inspired camera/backdrop layer.
# Uses the actual EBDX battlebg assets supplied with the project, while retaining
# Essentials/DBK battlers, UI and battle lifecycle. It is opt-in globally or per
# Blueprint and does not require Elite Battle DX to be installed at runtime.
#===============================================================================
module BSS074EBDXSceneLayer
  def bss074_ebdx_enabled?
    return @bss074_ebdx_enabled if !@bss074_ebdx_enabled.nil?
    @bss074_ebdx_enabled=(defined?(BSS064) && BSS064.respond_to?(:scene_camera_style) && BSS064.scene_camera_style(@battle)=="ebdx")
  rescue
    @bss074_ebdx_enabled=false
  end

  def bss074_apply_ebdx_backdrop
    return false if !bss074_ebdx_enabled? || !@sprites
    name=BSS064.ebdx_backdrop_name(@battle)
    path="Graphics/BattleSceneStudio/EBDX/battlebg/#{name}.png"
    bg=@sprites["battle_bg"] || @sprites["battle_bg2"]
    return false if !bg || !bg.respond_to?(:setBitmap)
    begin
      bg.setBitmap(path)
      bmp=(bg.bitmap rescue nil)
      if bmp && bmp.width.to_i>0 && bmp.height.to_i>0
        scale=[Graphics.width.to_f/bmp.width.to_f,Graphics.height.to_f/bmp.height.to_f].max
        bg.ox=0 if bg.respond_to?(:ox=)
        bg.oy=0 if bg.respond_to?(:oy=)
        bg.zoom_x=scale if bg.respond_to?(:zoom_x=)
        bg.zoom_y=scale if bg.respond_to?(:zoom_y=)
        bg.x=((Graphics.width-bmp.width*scale)/2.0) if bg.respond_to?(:x=)
        bg.y=((Graphics.height-bmp.height*scale)/2.0) if bg.respond_to?(:y=)
      end
      # EBDX battlebg already contains its floor perspective. Hide the second
      # native scrolling background layer so it cannot overwrite the authored room.
      bg2=@sprites["battle_bg2"]
      if bg2 && !bg2.equal?(bg)
        bg2.visible=false if bg2.respond_to?(:visible=)
        bg2.opacity=0 if bg2.respond_to?(:opacity=)
      end
      @bss074_ebdx_bg_applied=true
      true
    rescue => e
      BSS064.log("EBDX backdrop warning: #{e.class}: #{e.message}") if defined?(BSS064)
      false
    end
  end

  def bss074_world_sprite?(key,sp)
    return false if !sp || (sp.disposed? rescue false)
    s=key.to_s
    return true if s=="battle_bg" || s=="battle_bg2" || s.start_with?("base_")
    return true if s.start_with?("pokemon_") || s.start_with?("shadow_")
    return true if s.start_with?("trainer_") || s.start_with?("player_")
    false
  rescue
    false
  end

  def bss074_unapply_ebdx_camera
    rows=@bss074_ebdx_last_transform
    return if !rows.is_a?(Hash)
    rows.each_value do |state|
      sp=state[:sprite] rescue nil
      next if !sp || (sp.disposed? rescue false)
      begin;sp.x=sp.x.to_f-state[:dx].to_f if sp.respond_to?(:x=);rescue;end
      begin;sp.y=sp.y.to_f-state[:dy].to_f if sp.respond_to?(:y=);rescue;end
      z=state[:zoom].to_f;z=1.0 if z<=0.0001
      begin;sp.zoom_x=sp.zoom_x.to_f/z if sp.respond_to?(:zoom_x=);rescue;end
      begin;sp.zoom_y=sp.zoom_y.to_f/z if sp.respond_to?(:zoom_y=);rescue;end
    end
    @bss074_ebdx_last_transform={}
  rescue
    @bss074_ebdx_last_transform={}
  end

  def bss074_apply_ebdx_camera
    return if !bss074_ebdx_enabled? || !@sprites.is_a?(Hash)
    now=BSS064.respond_to?(:monotonic_seconds) ? BSS064.monotonic_seconds : Time.now.to_f
    @bss074_ebdx_camera_started ||= now
    t=now-@bss074_ebdx_camera_started
    # EBDX's idle vector camera continually reframes the room. This lightweight
    # native bridge keeps that visual language without replacing the battle scene.
    zoom=1.022 + Math.sin(t*0.72)*0.012
    pan_x=Math.sin(t*0.43)*7.0
    pan_y=Math.cos(t*0.37)*3.5
    cx=Graphics.width.to_f/2.0
    cy=Graphics.height.to_f/2.0
    @bss074_ebdx_last_transform={}
    @sprites.each do |key,sp|
      next if !bss074_world_sprite?(key,sp)
      begin
        bx=sp.x.to_f;by=sp.y.to_f
        dx=(bx-cx)*(zoom-1.0)+pan_x
        dy=(by-cy)*(zoom-1.0)+pan_y
        sp.x=bx+dx if sp.respond_to?(:x=)
        sp.y=by+dy if sp.respond_to?(:y=)
        sp.zoom_x=sp.zoom_x.to_f*zoom if sp.respond_to?(:zoom_x=)
        sp.zoom_y=sp.zoom_y.to_f*zoom if sp.respond_to?(:zoom_y=)
        @bss074_ebdx_last_transform[sp.object_id]={:sprite=>sp,:dx=>dx,:dy=>dy,:zoom=>zoom}
      rescue
      end
    end
  rescue => e
    BSS064.log("EBDX camera warning: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def pbCreateBackdropSprites(*args,&block)
    ret=super
    bss074_apply_ebdx_backdrop
    ret
  end

  def pbUpdate(*args,&block)
    bss074_unapply_ebdx_camera if @bss074_ebdx_last_transform
    ret=super
    bss074_apply_ebdx_camera
    ret
  end
end

module BSS064
  class << self
    def fresh_global_visual_config
      fallback={"blueprints"=>[],"global"=>{}}
      main=read_json_file(DATA_FILE,fallback)
      recovery=File.exist?(RECOVERY_DATA_FILE) ? read_json_file(RECOVERY_DATA_FILE,fallback) : nil
      main_at=(main.is_a?(Hash) ? main["_bssSavedAt"].to_i : 0)
      recovery_at=(recovery.is_a?(Hash) ? recovery["_bssSavedAt"].to_i : 0)
      chosen=(recovery && recovery_at>main_at) ? recovery : main
      row=chosen.is_a?(Hash) ? chosen["global"] : nil
      row.is_a?(Hash) ? row : {}
    rescue
      global=data["global"] rescue nil
      global.is_a?(Hash) ? global : {}
    end

    def databox_animation_mode
      # Appear/disappear are infrequent; read the latest saved global value here
      # so an old runtime cache can never make the UI appear to be ignored.
      global=fresh_global_visual_config
      raw=global["battleBoxAnimation"].to_s
      return raw if ["pop","slide","fade"].include?(raw)
      "slide"
    rescue
      "slide"
    end

    def ensure_databox_slide_driver(box)
      return false if !box
      klass=box.class
      klass.prepend(BSS074DataBoxSlideDriver) if klass.respond_to?(:prepend) && !klass.ancestors.include?(BSS074DataBoxSlideDriver)
      true
    rescue => e
      log("BattleBox slide driver install warning: #{e.class}: #{e.message}")
      false
    end

    def scene_camera_style(battle=nil)
      cfg=(battle && battle.respond_to?(:bss_environment_config)) ? battle.bss_environment_config : nil
      cfg={} if !cfg.is_a?(Hash)
      per=cfg["cameraStyle"].to_s
      return per if ["project","ebdx"].include?(per)
      global=fresh_global_visual_config
      raw=global["cameraStyle"].to_s
      ["project","ebdx"].include?(raw) ? raw : "project"
    rescue
      "project"
    end

    def ebdx_backdrop_name(battle=nil)
      cfg=(battle && battle.respond_to?(:bss_environment_config)) ? battle.bss_environment_config : nil
      cfg={} if !cfg.is_a?(Hash)
      requested=cfg["ebdxBackdrop"].to_s.strip
      global=fresh_global_visual_config
      requested=global["ebdxBackdrop"].to_s.strip if requested.empty? || requested=="inherit"
      valid=%w[Auto Field Forest City Cave CaveDark Mountain Sand Snow Water Underwater IndoorA IndoorB Sky Darkness Champion Net DanceFloor Sapphire]
      return requested if valid.include?(requested) && requested!="Auto"
      # EBDX itself resolves environment + terrain + indoor/outdoor. Keep this
      # BSS-native first pass deterministic and source-compatible with those cues.
      env=""
      begin;env=pbGetEnvironment.to_s if defined?(pbGetEnvironment);rescue;end
      terrain=""
      begin;terrain=$game_player.terrain_tag.id.to_s if defined?($game_player) && $game_player;rescue;end
      text=(env+" "+terrain).downcase
      return "Underwater" if text.include?("underwater")
      return "Water" if text.include?("water") || text.include?("puddle")
      return "CaveDark" if text.include?("cavedark") || text.include?("dark cave")
      return "Cave" if text.include?("cave")
      return "Sand" if text.include?("sand")
      return "Snow" if text.include?("snow") || text.include?("ice")
      return "Forest" if text.include?("forest") || text.include?("woods")
      return "Mountain" if text.include?("rock") || text.include?("mountain")
      begin
        meta=GameData::MapMetadata.try_get($game_map.map_id) if defined?(GameData::MapMetadata) && defined?($game_map) && $game_map
        outdoor=(meta && meta.respond_to?(:outdoor_map)) ? meta.outdoor_map : nil
        return outdoor ? "Field" : "IndoorA" unless outdoor.nil?
      rescue
      end
      "Field"
    rescue
      "Field"
    end

    def bss073_real_seconds
      if defined?(Process) && Process.respond_to?(:clock_gettime) && defined?(Process::CLOCK_MONOTONIC)
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      else
        Time.now.to_f
      end
    rescue
      Time.now.to_f
    end

    def bss073_begin_battle_handoff
      state={:viewport=>nil,:turbo_speed=>nil,:toggle=>nil,:finished=>false}
      begin
        if defined?(Turbo) && Turbo.respond_to?(:set_speed) && Turbo.respond_to?(:speed)
          state[:turbo_speed]=Turbo.speed.to_i
          state[:toggle]=(defined?($CanToggle) ? $CanToggle : nil)
          $CanToggle=false if defined?($CanToggle)
          Turbo.set_speed(0) if Turbo.speed.to_i!=0
        end
      rescue => e
        log("Global battle handoff Turbo lock warning: #{e.class}: #{e.message}")
      end
      begin
        vp=Viewport.new(0,0,Graphics.width,Graphics.height)
        vp.z=99999999 if vp.respond_to?(:z=)
        vp.color=Color.new(0,0,0,255)
        state[:viewport]=vp
      rescue => e
        log("Global battle handoff overlay warning: #{e.class}: #{e.message}")
      end
      state
    end

    def bss073_finish_battle_handoff(state,duration=0.40)
      return false if !state.is_a?(Hash)
      vp=state[:viewport]
      if vp && !(vp.disposed? rescue false)
        started=bss073_real_seconds
        loop do
          elapsed=bss073_real_seconds-started
          t=elapsed/duration.to_f
          t=1.0 if t>1.0
          alpha=((1.0-t)*255.0).round
          vp.color=Color.new(0,0,0,alpha)
          Graphics.update
          break if t>=1.0
        end
      end
      state[:finished]=true
      bss073_cleanup_battle_handoff(state)
      true
    rescue => e
      log("Global battle handoff fade warning: #{e.class}: #{e.message}")
      bss073_cleanup_battle_handoff(state)
      false
    end

    def bss073_cleanup_battle_handoff(state)
      return if !state.is_a?(Hash)
      begin
        vp=state[:viewport]
        vp.dispose if vp && !(vp.disposed? rescue true)
      rescue
      ensure
        state[:viewport]=nil
      end
      begin
        if !state[:turbo_speed].nil? && defined?(Turbo) && Turbo.respond_to?(:set_speed)
          Turbo.set_speed(state[:turbo_speed].to_i)
        end
        if defined?($CanToggle) && !state[:toggle].nil?
          $CanToggle=state[:toggle]
        end
      rescue => e
        log("Global battle handoff Turbo restore warning: #{e.class}: #{e.message}")
      end
      nil
    end

    def install_general_databox_animation_hooks!
      ok=false
      if defined?(Battle::Scene::Animation::DataBoxAppear)
        klass=Battle::Scene::Animation::DataBoxAppear
        klass.prepend(BSS073GlobalDataBoxAppear) if !klass.ancestors.include?(BSS073GlobalDataBoxAppear)
        ok=true
      end
      if defined?(Battle::Scene::Animation::DataBoxDisappear)
        klass=Battle::Scene::Animation::DataBoxDisappear
        klass.prepend(BSS073GlobalDataBoxDisappear) if !klass.ancestors.include?(BSS073GlobalDataBoxDisappear)
        ok=true
      end
      ok
    rescue => e
      log("Global BattleBox animation hook install warning: #{e.class}: #{e.message}")
      false
    end

    def install_battle_handoff_hook!
      owner=nil
      begin
        owner=Object.instance_method(:pbBattleAnimation).owner if Object.method_defined?(:pbBattleAnimation) || Object.private_method_defined?(:pbBattleAnimation)
      rescue
      end
      if !owner
        begin
          owner=Kernel.instance_method(:pbBattleAnimation).owner if Kernel.method_defined?(:pbBattleAnimation) || Kernel.private_method_defined?(:pbBattleAnimation)
        rescue
        end
      end
      return false if !owner || !owner.respond_to?(:prepend)
      owner.prepend(BSS073BattleAnimationHandoff) if !owner.ancestors.include?(BSS073BattleAnimationHandoff)
      true
    rescue => e
      log("Battle handoff hook install warning: #{e.class}: #{e.message}")
      false
    end

    def install_general_runtime_hooks!
      # Scene environment/global bases must affect ordinary battles as well as
      # Blueprints. Victory methods inside the module self-guard to BSS battles.
      if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS064SceneEnvironmentCompat)
        Battle::Scene.prepend(BSS064SceneEnvironmentCompat)
      end
      if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS074EBDXSceneLayer)
        Battle::Scene.prepend(BSS074EBDXSceneLayer)
      end
      install_general_databox_animation_hooks!
      install_battle_handoff_hook!
      true
    rescue => e
      log("General runtime hooks 0.6.73 warning: #{e.class}: #{e.message}")
      false
    end
  end
end

class Battle
  attr_accessor :bss_blueprint unless method_defined?(:bss_blueprint)
  attr_accessor :bss_environment_config unless method_defined?(:bss_environment_config)
  attr_accessor :bss_setup_config unless method_defined?(:bss_setup_config)
end

module BSS064
  class << self
    def normalize_bgm_name(value)
      name=value.to_s.strip.tr("\\","/")
      name=name.sub(%r{\A(?:Audio/)?BGM/}i,"")
      name=name.sub(/\.(?:ogg|mp3|wav|mid|midi|flac|opus|m4a)\z/i,"")
      name
    rescue
      value.to_s.strip
    end

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

    def configure_bss_scene_environment(battle,bp)
      return false if !battle
      env=hget(bp,"environment");env={} if !env.is_a?(Hash)
      setup=hget(bp,"setup");setup={} if !setup.is_a?(Hash)
      battle.bss_blueprint=bp if battle.respond_to?(:bss_blueprint=)
      battle.bss_environment_config=env if battle.respond_to?(:bss_environment_config=)
      battle.bss_setup_config=setup if battle.respond_to?(:bss_setup_config=)
      custom_back=env["battleback"].to_s.strip
      battle.backdrop=custom_back if !custom_back.empty? && battle.respond_to?(:backdrop=)
      scene=battle.instance_variable_get(:@scene) rescue nil
      if scene && (!defined?(Battle::Scene) || !Battle::Scene.ancestors.include?(BSS064SceneEnvironmentCompat))
        # Fallback for unusual launch orders where the late global hook was not
        # installed yet. In the normal path Battle::Scene already owns it.
        singleton=class << scene; self; end
        singleton.prepend(BSS064SceneEnvironmentCompat) if !singleton.ancestors.include?(BSS064SceneEnvironmentCompat)
      end
      battle_singleton=class << battle; self; end
      battle_singleton.prepend(BSS064BattleVictoryBGMCompat) if !battle_singleton.ancestors.include?(BSS064BattleVictoryBGMCompat)
      true
    rescue => e
      log("Scene/environment configure failed: #{e.class}: #{e.message}")
      false
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
      # F12 rebuilds scripts before every gameplay singleton is ready. Do not
      # consume the marker until the overworld/player/party are all stable.
      return false if !defined?($game_temp) || !$game_temp
      return false if !defined?($game_map) || !$game_map
      return false if !defined?($game_player) || !$game_player
      return false if !defined?($player) || !$player
      party=($player.party rescue nil)
      return false if !party || party.empty?
      if defined?(Scene_Map) && defined?($scene) && $scene && !$scene.is_a?(Scene_Map)
        req["readyFrames"]=0
        return false
      end
      req["readyFrames"]=req["readyFrames"].to_i+1
      return false if req["readyFrames"].to_i<20
      key=req["key"].to_s
      write_status("f12_resuming",{"key"=>key,"message"=>"Reiniciando Test game tras F12…"})
      # Keep runtime_active_battle.json alive while starting the replacement
      # battle. If the map is still transient and launch fails, retry instead of
      # deleting the only information needed to recover the BSS test.
      result=run_blueprint(key,true)
      if result==false
        req["readyFrames"]=0
        req["armedAt"]=Time.now.to_f
        @pending_f12_resume=req
        @f12_resume_armed=true
        return false
      end
      @pending_f12_resume=nil
      @f12_resume_armed=false
      true
    rescue => e
      log("F12 auto-resume failed: #{e.class}: #{e.message}")
      # Preserve marker and retry from a clean settled frame instead of
      # silently turning BSS off after Reset.
      if req.is_a?(Hash)
        req["readyFrames"]=0
        req["armedAt"]=Time.now.to_f
        @pending_f12_resume=req
        @f12_resume_armed=true
      end
      write_status("f12_resuming",{"key"=>(req&&req["key"]).to_s,"message"=>"F12: esperando runtime estable · #{e.class}"}) rescue nil
      false
    end

    def resume_active_battle
      schedule_active_battle_resume
    end

    def run_blueprint(key,live_test=false)
      clear_cache
      install_general_runtime_hooks! if respond_to?(:install_general_runtime_hooks!)
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
      # DBK's :hp_level must exist on the Pokemon before Battle.new builds the
      # Battler. Immunities are stored on that same Pokemon for this battle.
      apply_native_boss_party_attributes(foe_party,bp) if respond_to?(:apply_native_boss_party_attributes)

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
      @active_live_test_scene=scene if live_test
      foe_trainer=kind=="trainer" ? build_trainer(bp,foe_party) : nil
      raise RuntimeError,"Trainer battle has no valid trainer type." if kind=="trainer" && !foe_trainer
      battle=Battle.new(scene,player_party,foe_party,[$player],foe_trainer ? [foe_trainer] : nil)
      battle.setBattleMode(mode) if battle.respond_to?(:setBattleMode)
      battle.party1starts=[0] if battle.respond_to?(:party1starts=); battle.party2starts=[0] if battle.respond_to?(:party2starts=)
      battle.ally_items=[] if battle.respond_to?(:ally_items=); battle.items=foe_trainer ? [foe_trainer.items] : [] if battle.respond_to?(:items=)
      BattleCreationHelperMethods.prepare_battle(battle)
      # Blueprint-owned no-EXP option uses Essentials' own battle rule. Setting
      # it on Battle#rules after prepare_battle is intentional: the launcher
      # clears $game_temp rules for isolation, while pbGainExp checks this hash.
      begin
        battle.rules[:no_exp_gain]=true if hget(bp,"setup","noExp")==true && battle.respond_to?(:rules) && battle.rules.is_a?(Hash)
      rescue => e
        log("No EXP rule warning: #{e.class}: #{e.message}")
      end
      configure_bss_scene_environment(battle,bp)
      configure_native_sos(battle,bp)
      configure_native_boss(battle,bp) if respond_to?(:configure_native_boss)
      battle.canLose=(hget(bp,"setup","canLose")!=false) if battle.respond_to?(:canLose=)
      begin; $game_temp.clear_battle_rules; rescue; end if defined?($game_temp)&&$game_temp

      # Only an explicit editor Test game session gets an F12 resume marker.
      # Event-command battles (pbBSSBattle) and ordinary gameplay never do.
      write_status("running",{"key"=>bp["key"],"name"=>bp["name"],"formation"=>mode,"sos"=>sos_enabled,"boss"=>(hget(bp,"boss","enabled")==true)})
      bgm_name=normalize_bgm_name(hget(bp,"environment","bgm"))
      victory_bgm_name=normalize_bgm_name(hget(bp,"environment","victoryBgm"))
      if !victory_bgm_name.empty? && defined?($PokemonGlobal) && $PokemonGlobal
        begin
          $PokemonGlobal.nextBattleVictoryBGM=pbStringToAudioFile(victory_bgm_name)
        rescue => e
          log("Victory BGM pre-arm warning: #{e.class}: #{e.message}")
        end
      end
      bgm=if !bgm_name.empty? then bgm_name elsif foe_trainer then pbGetTrainerBattleBGM([foe_trainer]) else pbGetWildBattleBGM(foe_party) end
      anim_type=foe_trainer ? (battle.singleBattle? ? 1 : 3) : (foe_party.length==1 ? 0 : 2)
      subject=foe_trainer ? [foe_trainer] : foe_party
      outcome=0
      battle_error=nil
      handoff_turbo_restore=nil
      # Keep a marker only while an editor-launched test is actually inside the
      # battle. F12 raises Reset (outside StandardError), so that marker survives
      # the interrupted call and the freshly reloaded BSS runtime can ask Studio
      # to requeue the exact same test through the normal control bridge.
      write_active_battle(bp["key"],true) if live_test
      pbBattleAnimation(bgm,anim_type,subject) do
        begin
          pbSceneStandby { outcome=battle.pbStartBattle }
          BattleCreationHelperMethods.after_battle(outcome,true,battle)
          # pbBattleAnimation's return fade is timed with System.uptime. This
          # project scales that clock with Turbo, which can reduce the 0.4s map
          # reveal to only a handful of visible frames. Hold Turbo at 1x only
          # for the battle->overworld handoff, then restore the player's speed.
          if defined?(Turbo) && Turbo.respond_to?(:set_speed) && Turbo.respond_to?(:speed)
            begin
              current_speed=Turbo.speed.to_i
              # Lock input for EVERY return fade, not only when Turbo was already
              # active. pbBattleAnimation calls Input.update during the 0.4 s map
              # reveal; with speed 0 the old code left $CanToggle enabled, so a
              # lingering turbo key could change System.uptime mid-fade and make
              # the overworld appear in a single visible jump.
              handoff_turbo_restore={:speed=>current_speed,:toggle=>(defined?($CanToggle) ? $CanToggle : nil)}
              $CanToggle=false if defined?($CanToggle)
              Turbo.set_speed(0) if current_speed!=0
              scene.bss650_hide_native_turbo_icon if scene && scene.respond_to?(:bss650_hide_native_turbo_icon)
            rescue => e
              log("Battle handoff Turbo warning: #{e.class}: #{e.message}")
            end
          end
        rescue SystemStackError => e
          battle_error=e
          log("Battle runtime SystemStackError: #{e.message}")
          begin; scene.pbEndBattle(Battle::Outcome::UNDECIDED) if scene && scene.respond_to?(:pbEndBattle); rescue; end
        rescue => e
          battle_error=e
          log("Battle runtime failed: #{e.class}: #{e.message}")
          # Never leave a half-alive Battle::Scene covering the overworld. This
          # is exception recovery only; normal faint/capture paths still reach
          # Essentials' own pbEndOfBattle -> Scene#pbEndBattle lifecycle.
          begin; scene.pbEndBattle(Battle::Outcome::UNDECIDED) if scene && scene.respond_to?(:pbEndBattle); rescue; end
        end
      end
      clear_active_battle if live_test
      begin
        if handoff_turbo_restore && defined?(Turbo) && Turbo.respond_to?(:set_speed)
          Turbo.set_speed(handoff_turbo_restore[:speed].to_i) if !Turbo.respond_to?(:speed) || Turbo.speed.to_i!=handoff_turbo_restore[:speed].to_i
          $CanToggle=handoff_turbo_restore[:toggle] if defined?($CanToggle) && !handoff_turbo_restore[:toggle].nil?
          scene.bss650_hide_native_turbo_icon if scene && scene.respond_to?(:bss650_hide_native_turbo_icon)
          handoff_turbo_restore=nil
        end
      rescue => e
        log("Battle handoff Turbo restore warning: #{e.class}: #{e.message}")
      end
      begin;Input.update if defined?(Input);rescue;end
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
      begin
        if defined?(handoff_turbo_restore) && handoff_turbo_restore && defined?(Turbo) && Turbo.respond_to?(:set_speed)
          Turbo.set_speed(handoff_turbo_restore[:speed].to_i) if !Turbo.respond_to?(:speed) || Turbo.speed.to_i!=handoff_turbo_restore[:speed].to_i
          $CanToggle=handoff_turbo_restore[:toggle] if defined?($CanToggle) && !handoff_turbo_restore[:toggle].nil?
          scene.bss650_hide_native_turbo_icon if defined?(scene) && scene && scene.respond_to?(:bss650_hide_native_turbo_icon)
        end
      rescue
      end
      # BSS releases only the visual objects it owns here. Battle::Scene itself has
      # no guaranteed dispose method in Essentials/LBDS; invoking one fabricated by
      # a prepend caused the v0.6.51 end-battle NoMethodError.
      if defined?(scene) && scene
        # Never dispose Essentials' scene sprites/viewport here on a normal exit.
        # pbBattleAnimation owns the black viewport and its 0.4s return fade;
        # destroying the whole battle scene in this ensure made the overworld pop
        # in underneath it instead of being revealed gradually.
        begin; scene.bss650_release_boss_visuals if scene.respond_to?(:bss650_release_boss_visuals); rescue; end
      end
      @running=false
      @active_live_test_scene=nil if live_test
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
      return true if @f12_resume_armed==true && @pending_f12_resume.is_a?(Hash)
      raw=active_battle_request rescue nil
      if raw.is_a?(Hash)
        if schedule_active_battle_resume
          @f12_resume_armed=true
          return true
        end
        # Keep an explicit recent Reset marker through early initialization.
        reset_at=raw["resetDetectedAt"].to_i
        reset_age=reset_at>0 ? ((Time.now.to_f*1000).to_i-reset_at) : 999999
        if raw["resumeAfterReset"]==true && reset_age>=0 && reset_age<=120000
          @pending_f12_resume={"key"=>raw["key"].to_s,"token"=>raw["token"].to_s,"armedAt"=>Time.now.to_f,"readyFrames"=>0}
          @f12_resume_armed=true
          return true
        end
        clear_active_battle
      end
      @pending_f12_resume=nil
      @f12_resume_armed=false
      write_status("ready",{"message"=>"BSS 0.6.74 ready · runtime reloaded"})
      true
    rescue => e
      log("Runtime ready bridge warning: #{e.class}: #{e.message}")
      false
    end

    # Editor live tests are a sandbox. A runtime error must be reported back to
    # Studio, but it must not escape into Essentials' global exception handler and
    # leave the battle viewport covering the map. Scripted pbBSSBattle gameplay is
    # intentionally not routed through this recovery helper.
    def recover_live_test_error(error,key=nil)
      begin
        log("BSS live-test recovered #{error.class}: #{error.message}")
      rescue
      end
      begin
        clear_active_battle
      rescue
      end
      begin
        scene=@active_live_test_scene
        if scene
          begin;scene.bss650_release_boss_visuals if scene.respond_to?(:bss650_release_boss_visuals);rescue;end
          begin;scene.pbEndBattle(Battle::Outcome::UNDECIDED) if defined?(Battle::Outcome) && scene.respond_to?(:pbEndBattle);rescue Exception;end
        end
      rescue Exception
      ensure
        @active_live_test_scene=nil
      end
      begin
        $game_temp.in_battle=false if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:in_battle=)
      rescue
      end
      begin
        write_status("error",{
          "key"=>key.to_s,
          "message"=>"#{error.class}: #{error.message}",
          "backtrace"=>(error.backtrace||[])[0,16],
          "recoveredToOverworld"=>true
        })
      rescue
      end
      @running=false
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
    rescue SystemStackError => e
      recover_live_test_error(e,(req && req["key"]))
    rescue => e
      log("Control bridge failed: #{e.class}: #{e.message}"); write_status("error",{"message"=>"#{e.class}: #{e.message}","recoveredToOverworld"=>true});
      begin;$game_temp.in_battle=false if defined?($game_temp)&&$game_temp&&$game_temp.respond_to?(:in_battle=);rescue;end
      @running=false
      false
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
  EventHandlers.add(:on_game_initialize,:bss_064_initialize,proc do
    begin
      BSS064.install_general_runtime_hooks! if BSS064.respond_to?(:install_general_runtime_hooks!)
      BSS064.runtime_ready!
    rescue
    end
  end)
  EventHandlers.add(:on_game_load,:bss_064_ready,proc do
    begin
      BSS064.install_general_runtime_hooks! if BSS064.respond_to?(:install_general_runtime_hooks!)
      BSS064.runtime_ready!
    rescue
    end
  end)
  EventHandlers.add(:on_frame_update,:bss_064_control,proc do
    begin
      resumed=BSS064.poll_f12_resume
      BSS064.poll_control if !resumed
    rescue SystemStackError => e
      BSS064.recover_live_test_error(e,nil) if BSS064.respond_to?(:recover_live_test_error)
    rescue
    end
  end)
end
