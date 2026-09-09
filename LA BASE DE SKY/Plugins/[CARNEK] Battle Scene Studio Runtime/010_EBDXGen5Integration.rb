#===============================================================================
# Battle Scene Studio v0.8.2
# Final EBDX Gen 5 integration / compatibility authority.
# Loaded last so alias-heavy project plugins cannot restore unsafe vanilla slots.
#===============================================================================

module BSS078
  VERSION = "0.8.2"
  TRANSITION_ROOT = "Graphics/BattleSceneStudio/EBDX/Transitions/WildIntro"

  module_function

  def true_boss?(battle)
    return false if !battle
    return false if !battle.respond_to?(:bss_boss_enabled?)
    battle.bss_boss_enabled? == true
  rescue
    false
  end

  def ebdx_room?(sprites)
    return false if !sprites.is_a?(Hash)
    room = sprites["battlebg"]
    defined?(BSS070EBDXRoom) && room.is_a?(BSS070EBDXRoom) && !(room.disposed? rescue false)
  rescue
    false
  end

  def transient_rule_key?(key)
    key.to_s.downcase =~ /(bss|boss|totem|raid|sos|noescape|canrun|setboss|bossbattle|totembattle|sosbattle|setsospokemon|addsospokemon)/ ? true : false
  end
end

#-------------------------------------------------------------------------------
# Dynamic battler slot authority.
# SOS can insert index 3/5 before a plugin has refreshed @sideSizes. Never let
# Essentials index BATTLER_OFFSET_2/3 with a global index that doesn't exist.
#-------------------------------------------------------------------------------
module BSS078SafeBattlerPosition
  def pbBattlerPosition(index, sideSize = 1)
    idx = index.to_i
    side = idx & 1
    local = idx / 2
    size = sideSize.to_i
    size = 1 if size < 1
    size = 3 if size > 3
    # The live battler index is stronger evidence than a one-frame-old sideSize.
    effective = [size, [local + 1, 3].min].max
    visual_local = [[local, 0].max, effective - 1].min
    visual_idx = side + visual_local * 2

    # During EBDX animation construction, return the projected room anchor itself.
    begin
      ctx = defined?(BSS070EBDXCore) ? BSS070EBDXCore.position_scene : nil
      if ctx && ctx.respond_to?(:bss070_ebdx_active?) && ctx.bss070_ebdx_active?
        room = ctx.instance_variable_get(:@bss070_ebdx_room) rescue nil
        anchor = room.battler(visual_idx) rescue nil
        return [anchor.x.to_f, anchor.y.to_f] if anchor
      end
    rescue
    end

    if side == 0
      x = const_defined?(:PLAYER_BASE_X) ? const_get(:PLAYER_BASE_X).to_f : 128.0
      y = respond_to?(:PLAYER_BASE_Y) ? PLAYER_BASE_Y().to_f : (const_get(:PLAYER_BASE_Y).to_f rescue 400.0)
    else
      x = respond_to?(:FOE_BASE_X) ? FOE_BASE_X().to_f : (const_get(:FOE_BASE_X).to_f rescue Graphics.width - 128.0)
      y = respond_to?(:FOE_BASE_Y) ? FOE_BASE_Y().to_f : (const_get(:FOE_BASE_Y).to_f rescue Graphics.height * 0.75 - 112.0)
    end
    if effective == 2
      ox = const_defined?(:BATTLER_OFFSET_2_X) ? const_get(:BATTLER_OFFSET_2_X)[visual_idx] : nil
      oy = const_defined?(:BATTLER_OFFSET_2_Y) ? const_get(:BATTLER_OFFSET_2_Y)[visual_idx] : nil
      x += ox.to_f if !ox.nil?
      y += oy.to_f if !oy.nil?
    elsif effective >= 3
      ox = const_defined?(:BATTLER_OFFSET_3_X) ? const_get(:BATTLER_OFFSET_3_X)[visual_idx] : nil
      oy = const_defined?(:BATTLER_OFFSET_3_Y) ? const_get(:BATTLER_OFFSET_3_Y)[visual_idx] : nil
      x += ox.to_f if !ox.nil?
      y += oy.to_f if !oy.nil?
    end
    [x, y]
  rescue => e
    if defined?(BSS064)
      BSS064.log("BSS078 safe battler position warning: #{e.class}: #{e.message}")
    end
    (idx & 1) == 0 ? [128, Graphics.height - 80] : [Graphics.width - 128, (Graphics.height * 3 / 4) - 112]
  end
end
begin
  Battle::Scene.singleton_class.prepend(BSS078SafeBattlerPosition) if defined?(Battle::Scene) && !Battle::Scene.singleton_class.ancestors.include?(BSS078SafeBattlerPosition)
rescue => e
  BSS064.log("BSS078 battler slot install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# Real room overscan. The original 384x308 art remains unchanged in the authored
# centre. Off-canvas strips repeat only the edge band, while top/bottom use the
# sky/ground edge colours. This prevents black wedges on wide/tall screens and
# aggressive Aura/Gen5 camera shots without stretching the actual composition.
#-------------------------------------------------------------------------------
module BSS078RoomOverscan
  def bss078_repeat_band(dst, src, dst_x, dst_y, width, height, src_rect)
    return if width <= 0 || height <= 0 || src_rect.width <= 0 || src_rect.height <= 0
    x = dst_x
    while x < dst_x + width
      w = [src_rect.width, dst_x + width - x].min
      dst.blt(x, dst_y, src, Rect.new(src_rect.x, src_rect.y, w, [src_rect.height, height].min))
      x += w
    end
  end

  def bss078_extend_room_bitmap!
    bg = @sprites && @sprites["bg"]
    return if !bg || !bg.bitmap || (bg.bitmap.disposed? rescue false)
    return if bg.instance_variable_get(:@bss078_overscanned)
    src = bg.bitmap
    # At 640x480 this creates >1400 px of horizontal world coverage. Camera zoom
    # can expose a large area without ever reaching a black viewport edge.
    cfg = defined?(BSS070EBDXCore) ? BSS070EBDXCore.camera_config : {}
    extra = (cfg["overscan"] || 24).to_f
    px = [(@viewport.width * (1.15 + extra / 100.0)).to_i, 640].max
    pt = [(@viewport.height * 0.65).to_i, 256].max
    pb = [(@viewport.height * 0.95).to_i, 384].max
    dst = Bitmap.new(src.width + px * 2, src.height + pt + pb)
    top = src.get_pixel([src.width / 2, src.width - 1].min, 0)
    bottom = src.get_pixel([src.width / 2, src.width - 1].min, src.height - 1)
    dst.fill_rect(0, 0, dst.width, pt, top)
    dst.fill_rect(0, pt + src.height, dst.width, pb, bottom)
    dst.blt(px, pt, src, src.rect)
    band = [[src.width / 4, 96].max, src.width].min
    # Repeat meaningful edge strips instead of scaling the whole battleback.
    x = 0
    while x < px
      w = [band, px - x].min
      dst.blt(x, pt, src, Rect.new(0, 0, w, src.height))
      x += w
    end
    x = px + src.width
    while x < dst.width
      w = [band, dst.width - x].min
      dst.blt(x, pt, src, Rect.new(src.width - w, 0, w, src.height))
      x += w
    end
    # Extend the sky and floor colour through the side columns as well.
    dst.fill_rect(0, 0, dst.width, pt, top)
    dst.fill_rect(0, pt + src.height, dst.width, pb, bottom)

    old_ox = bg.ox.to_f
    old_oy = bg.oy.to_f
    bg.bitmap = dst
    bg.ox = old_ox + px
    bg.oy = old_oy + pt
    bg.instance_variable_set(:@bss078_overscanned, true)
    @bss078_pad_x = px
    @bss078_pad_y = pt

    # Every authored element shares the same 384x308 coordinate space.
    @sprites.each do |key, sp|
      next if !sp || key == "bg" || key == "void"
      begin
        sp.ex = sp.ex.to_f + px if sp.respond_to?(:ex) && sp.respond_to?(:ex=) && !sp.ex.nil?
        sp.ey = sp.ey.to_f + pt if sp.respond_to?(:ey) && sp.respond_to?(:ey=) && !sp.ey.nil?
      rescue
      end
    end
    begin
      src.dispose if src && !(src.disposed? rescue true)
    rescue
    end
  end

  def refresh(*args)
    ret = super
    bss078_extend_room_bitmap! if args[0].is_a?(Hash)
    ret
  end

  def stageLightPos(j)
    pos = super
    return pos if !pos || !pos.respond_to?(:[]) || pos.length < 2
    [pos[0].to_f + @bss078_pad_x.to_f, pos[1].to_f + @bss078_pad_y.to_f]
  rescue
    super
  end
end
begin
  BSS070EBDXRoom.prepend(BSS078RoomOverscan) if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(BSS078RoomOverscan)
rescue => e
  BSS064.log("BSS078 overscan install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# Battle state isolation. A BSS blueprint may disable running, add Boss/SOS rules,
# etc. Those flags belong to that Battle instance only.
#-------------------------------------------------------------------------------
module BSS078BattleIsolation
  def initialize(*args, &block)
    # During a Maker Studio/F12 reload an alias can point back to this method,
    # producing EBDXGen5 -> Midbattle -> NativeSOS -> EBDXGen5 recursion.
    return if @bss078_initialize_active
    @bss078_initialize_active=true
    begin
      super
      @bss_boss_config = nil
      @bss_boss_hud_config = nil
      @bss_blueprint = nil
      @bss_boss_active = false
    ensure
      @bss078_initialize_active=false
    end
  end
end
begin
  Battle.prepend(BSS078BattleIsolation) if defined?(Battle) && !Battle.ancestors.include?(BSS078BattleIsolation)
rescue => e
  BSS064.log("BSS078 battle isolation install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# Non-Boss SOS must never be processed as a BossHUD layout. Normal PokémonDataBox
# remains fully owned by Essentials/DBK/Enhanced UI.
#-------------------------------------------------------------------------------
module BSS078NonBossDataboxAuthority
  def bss652_hide_native_boss_databox(*args, &block)
    battle = (@battle rescue nil)
    return false if !BSS078.true_boss?(battle)
    super
  end

  def bss652_layout_sos_databoxes(*args, &block)
    battle = @battle rescue nil
    if battle && !BSS078.true_boss?(battle)
      begin
        (@sprites || {}).each do |key, box|
          next if !key.to_s.start_with?("dataBox_") || !box
          box.bss654_clear_layout_override if box.respond_to?(:bss654_clear_layout_override)
        end
      rescue
      end
      return true
    end
    super
  end
end
begin
  Battle::Scene.prepend(BSS078NonBossDataboxAuthority) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS078NonBossDataboxAuthority)
rescue => e
  BSS064.log("BSS078 databox authority install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# Cinematic UI ownership + Gen5-like wild entry based on the supplied NDS assets.
# No snapshot of a vanilla battleback is used; the live EBDX room stays underneath.
#-------------------------------------------------------------------------------
module BSS078SceneCinematics
  def bss078_cinematic_ui_hide
    state = {}
    return state if !@sprites.is_a?(Hash)
    @sprites.each do |key, sp|
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible)
      k = key.to_s
      next if k =~ /boss/i
      next unless k =~ /(dataBox_|info_icon|enhanced|partyBar_|partyBall_|cmdBar|command|fight|target|ability|itemWindow)/i
      begin
        state[key] = sp.visible
        sp.visible = false if sp.respond_to?(:visible=)
      rescue
      end
    end
    state
  end

  def bss078_cinematic_ui_restore(state)
    return if !state.is_a?(Hash) || !@sprites.is_a?(Hash)
    state.each do |key, vis|
      sp = @sprites[key] rescue nil
      next if !sp || (sp.disposed? rescue false) || !sp.respond_to?(:visible=)
      begin; sp.visible = vis; rescue; end
    end
  end

  def bss078_wild_intro_kind
    begin
      return "Water" if defined?($PokemonGlobal) && $PokemonGlobal && (($PokemonGlobal.surfing rescue false) || ($PokemonGlobal.diving rescue false) || ($PokemonGlobal.fishing rescue false))
    rescue
    end
    env = BSS070EBDXCore.environment_for(self) rescue {}
    bg = env.is_a?(Hash) ? (env["backdrop"] || env[:backdrop]).to_s.downcase : ""
    return "Water" if bg.include?("water") || bg.include?("underwater")
    return "Cave" if bg.include?("cave")
    "Grass"
  end

  def bss078_wild_intro_asset
    kind = bss078_wild_intro_kind
    return "#{BSS078::TRANSITION_ROOT}/CaveIntro" if kind == "Cave"
    suffix = ""
    begin
      suffix = "_night" if defined?(PBDayNight) && PBDayNight.respond_to?(:isNight?) && PBDayNight.isNight?
      suffix = "_eve" if suffix.empty? && defined?(PBDayNight) && ((PBDayNight.respond_to?(:isEvening?) && PBDayNight.isEvening?) || (PBDayNight.respond_to?(:isMorning?) && PBDayNight.isMorning?))
    rescue
      suffix = ""
    end
    "#{BSS078::TRANSITION_ROOT}/#{kind}Intro#{suffix}"
  end

  def bss078_play_wild_nds_reveal
    return if !respond_to?(:bss070_ebdx_active?) || !bss070_ebdx_active?
    bss070_ebdx_ensure_core if respond_to?(:bss070_ebdx_ensure_core)
    ui = bss078_cinematic_ui_hide
    foes = []
    shadows = []
    begin
      @battle.sideSizes[1].times do |i|
        idx = i * 2 + 1
        sp = @sprites["pokemon_#{idx}"] rescue nil
        sh = @sprites["shadow_#{idx}"] rescue nil
        foes << [sp, (sp.opacity rescue 255)] if sp
        shadows << [sh, (sh.opacity rescue 255)] if sh
        sp.opacity = 0 if sp && sp.respond_to?(:opacity=)
        sh.opacity = 0 if sh && sh.respond_to?(:opacity=)
      end
      bss070_ebdx_camera_enter(:fight) if respond_to?(:bss070_ebdx_camera_enter)
      overlay = Sprite.new(@viewport)
      overlay.bitmap = pbBitmap(bss078_wild_intro_asset)
      overlay.z = 99990
      scale = @viewport.width.to_f / [overlay.bitmap.width, 1].max
      overlay.zoom_x = scale
      overlay.zoom_y = scale
      overlay.x = 0
      h = overlay.bitmap.height * scale
      overlay.y = @viewport.height
      overlay.opacity = 255
      # Biome strip rises while the actual EBDX world/camera remains live.
      12.times do |i|
        t = (i + 1) / 12.0
        ease = 1.0 - (1.0 - t) * (1.0 - t)
        overlay.y = @viewport.height - h * ease
        pbUpdate
      end
      6.times { pbUpdate }
      12.times do |i|
        a = ((i + 1) * 255 / 12.0).round
        foes.each { |sp, old| sp.opacity = [a, old.to_i].min if sp && sp.respond_to?(:opacity=) }
        shadows.each { |sp, old| sp.opacity = [a, old.to_i].min if sp && sp.respond_to?(:opacity=) }
        overlay.opacity = 255 - a
        pbUpdate
      end
      overlay.dispose if overlay && !(overlay.disposed? rescue true)
      foes.each { |sp, old| sp.opacity = old if sp && sp.respond_to?(:opacity=) }
      shadows.each { |sp, old| sp.opacity = old if sp && sp.respond_to?(:opacity=) }
      bss070_ebdx_camera_leave if respond_to?(:bss070_ebdx_camera_leave)
    ensure
      bss078_cinematic_ui_restore(ui)
    end
  rescue => e
    BSS064.log("BSS078 wild intro warning: #{e.class}: #{e.message}") if defined?(BSS064)
    bss078_cinematic_ui_restore(ui) rescue nil
  end

  def pbBattleIntroAnimation
    return super if !@battle || @battle.trainerBattle? || !respond_to?(:bss070_ebdx_active?) || !bss070_ebdx_active?
    bss070_ebdx_ensure_core if respond_to?(:bss070_ebdx_ensure_core)
    # Essentials still handles the black-screen opening and trainer-layer setup,
    # but EBDX disables its wild Pokémon/background slide via the patch below.
    introAnim = Battle::Scene::Animation::Intro.new(@sprites, @viewport, @battle)
    loop do
      introAnim.update
      pbUpdate
      break if introAnim.animDone?
    end
    introAnim.dispose
    bss078_play_wild_nds_reveal
    @battle.sideSizes[1].times do |i|
      idxBattler = (2 * i) + 1
      next if !@battle.battlers[idxBattler]
      @animations.push(Battle::Scene::Animation::DataBoxAppear.new(@sprites, @viewport, idxBattler))
    end
    while inPartyAnimation?; pbUpdate; end
    if !@battle.rules[:no_battle_animations]
      @battle.sideSizes[1].times do |i|
        idxBattler = (2 * i) + 1
        b = @battle.battlers[idxBattler]
        next if !b || !b.shiny?
        if Settings::SUPER_SHINY && b.super_shiny?
          pbCommonAnimation("SuperShiny", b)
        else
          pbCommonAnimation("Shiny", b)
        end
      end
    end
  end

  # EBDX SOS = camera event around the live scene, not a vanilla positional cut.
  def bss_pbSOSJoin(idx_battler, *args, &block)
    return super unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    state = bss078_cinematic_ui_hide
    begin
      bss070_ebdx_camera_enter(:fight) if respond_to?(:bss070_ebdx_camera_enter)
      6.times { pbUpdate }
      result = super
      6.times { pbUpdate }
      bss070_ebdx_camera_leave if respond_to?(:bss070_ebdx_camera_leave)
      result
    ensure
      bss078_cinematic_ui_restore(state)
      begin
        bss073_repair_sos_databoxes(idx_battler, true) if respond_to?(:bss073_repair_sos_databoxes)
      rescue
      end
    end
  end
end
begin
  Battle::Scene.prepend(BSS078SceneCinematics) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS078SceneCinematics)
rescue => e
  BSS064.log("BSS078 cinematic install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

# Remove the Essentials off-screen slide for wild battlers/shadows in EBDX mode.
module BSS078EBDXIntroMotion
  def makeSlideSprite(spriteName, deltaMult, appearTime, origin = nil)
    if BSS078.ebdx_room?(@sprites) && (spriteName.to_s.start_with?("pokemon_") || spriteName.to_s.start_with?("shadow_") || spriteName.to_s.start_with?("battle_bg") || spriteName.to_s.start_with?("base_"))
      return
    end
    super
  end
end
begin
  k = Battle::Scene::Animation::Intro
  k.prepend(BSS078EBDXIntroMotion) if defined?(k) && !k.ancestors.include?(BSS078EBDXIntroMotion)
rescue => e
  BSS064.log("BSS078 intro motion install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

#-------------------------------------------------------------------------------
# Gen5-like Poké Ball travel. Player throws have a longer/higher arc; opponent
# balls actually travel in from the opposing side instead of materialising at the
# destination as Essentials' default TrainerSendOut does.
#-------------------------------------------------------------------------------
module BSS078Gen5PlayerBallArc
  def createBallTrajectory(ball, delay, duration, startX, startY, midX, midY, endX, endY)
    owner=self.class.to_s
    # This arc is for sendout only. Applying it to Poké Ball capture classes made
    # the catching throw take a visibly wrong, over-high path.
    capture_like=(owner =~ /(throw|capture|catch)/i)
    if BSS078.ebdx_room?(@sprites) && !capture_like
      duration = [duration.to_i + 6, 18].max
      midX = (startX.to_f + endX.to_f) * 0.5
      midY = [[[midY.to_f, endY.to_f - 92.0].min, 24.0].max, Graphics.height - 24.0].min
    end
    super(ball, delay, duration, startX, startY, midX, midY, endX, endY)
  end
end
begin
  mix = Battle::Scene::Animation::BallAnimationMixin
  mix.prepend(BSS078Gen5PlayerBallArc) if defined?(mix) && !mix.ancestors.include?(BSS078Gen5PlayerBallArc)
rescue => e
  BSS064.log("BSS078 ball arc install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end

module BSS078Gen5OpponentBallArc
  def createBallTrajectory(ball, destX, destY)
    return super unless BSS078.ebdx_room?(@sprites)
    duration = 18
    startX = [[destX.to_f + 128.0, Graphics.width - 18.0].min, 18.0].max
    startY = [[[destY.to_f - 44.0, 28.0].max, Graphics.height - 28.0].min, 28.0].max
    midY = [[[destY.to_f - 96.0, 24.0].max, Graphics.height - 24.0].min, 24.0].max
    # The endpoint belongs to Essentials/the active BSS battler-position
    # authority. The Gen 5 styling may change only the *path*, never the final
    # reveal point; an old -4 offset made the ball visibly miss the battler.
    endX = destX.to_f
    endY = destY.to_f
    ball.setVisible(0, true)
    a = (2 * startY) - (4 * midY) + (2 * endY)
    b = (4 * midY) - (3 * startY) - endY
    c = startY
    (1..duration).each do |i|
      t = i.to_f / duration
      x = startX + ((endX - startX) * t)
      y = (a * (t ** 2)) + (b * t) + c
      ball.moveXY(i - 1, 1, x, y)
    end
    createBallTumbling(ball, 0, duration)
  end
end
begin
  k = Battle::Scene::Animation::PokeballTrainerSendOut
  k.prepend(BSS078Gen5OpponentBallArc) if defined?(k) && !k.ancestors.include?(BSS078Gen5OpponentBallArc)
rescue => e
  BSS064.log("BSS078 opponent ball install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end


#===============================================================================
# BSS v0.7.9 - Intro authority / EBDX Intro Studio runtime
# Wild EBDX battles never fall through to the Vanilla wild slide. The same intro
# engine can optionally replace Vanilla wild intros when enabled in EBDX Studio.
#===============================================================================
module BSS079IntroAuthority
  def bss079_intro_config
    raw = (defined?(BSS070EBDXCore) ? BSS070EBDXCore.global_config["ebdxIntro"] : nil) rescue nil
    raw = {} if !raw.is_a?(Hash)
    d = {
      "style" => "nds_biome",
      "useInVanilla" => false,
      "holdFrames" => 8,
      "moveFrames" => 12,
      "zoomStart" => 200,
      "dim" => 72,
      "flash" => 160,
      "driftX" => -7,
      "driftY" => 3
    }
    raw.each { |k,v| d[k.to_s] = v }
    d
  rescue
    {"style"=>"nds_biome","useInVanilla"=>false,"holdFrames"=>8,"moveFrames"=>12,"zoomStart"=>200,"dim"=>72,"flash"=>160,"driftX"=>-7,"driftY"=>3}
  end

  def bss079_intro_overlay(color, opacity, z=99980)
    sp = Sprite.new(@viewport)
    sp.bitmap = Bitmap.new(1,1)
    sp.bitmap.fill_rect(0,0,1,1,color)
    sp.zoom_x = [@viewport.width,1].max
    sp.zoom_y = [@viewport.height,1].max
    sp.opacity = opacity.to_i
    sp.z = z
    sp
  end

  def bss079_intro_foe_sprites
    rows=[]
    size=(@battle.sideSizes[1] rescue 1).to_i
    size=1 if size<1
    size.times do |i|
      idx=(i*2)+1
      pkm=@sprites["pokemon_#{idx}"] rescue nil
      sha=@sprites["shadow_#{idx}"] rescue nil
      rows << [idx,pkm,sha,(pkm.opacity rescue 255),(sha.opacity rescue 255),(pkm.zoom_x rescue 1.0),(pkm.zoom_y rescue 1.0),(pkm.x rescue nil),(pkm.y rescue nil)]
    end
    rows
  end

  def bss079_intro_asset_sprite
    path = bss078_wild_intro_asset rescue nil
    return nil if !path || !(pbResolveBitmap(path) rescue false)
    sp=Sprite.new(@viewport)
    sp.bitmap=pbBitmap(path)
    sp.z=99970
    scale=[@viewport.width.to_f/[sp.bitmap.width,1].max, @viewport.height.to_f/[sp.bitmap.height,1].max].max
    sp.zoom_x=scale; sp.zoom_y=scale
    sp
  rescue
    nil
  end

  def bss079_play_custom_wild_intro(ebdx_active)
    cfg=bss079_intro_config
    style=cfg["style"].to_s
    style="nds_biome" if style.empty?
    hold=[[cfg["holdFrames"].to_i,0].max,120].min
    move=[[cfg["moveFrames"].to_i,2].max,180].min
    dim=[[cfg["dim"].to_i,0].max,255].min
    flash=[[cfg["flash"].to_i,0].max,255].min
    drift_x=cfg["driftX"].to_f
    drift_y=cfg["driftY"].to_f
    zoom_start=[[cfg["zoomStart"].to_f,100.0].max,240.0].min / 100.0
    ui=bss078_cinematic_ui_hide rescue {}
    foes=bss079_intro_foe_sprites
    asset=nil; dark=nil; white=nil
    begin
      foes.each do |idx,pkm,sha,po,so,zx,zy,px,py|
        pkm.opacity=0 if pkm && pkm.respond_to?(:opacity=)
        sha.opacity=0 if sha && sha.respond_to?(:opacity=)
      end
      bss070_ebdx_camera_enter(:fight) if ebdx_active && respond_to?(:bss070_ebdx_camera_enter)
      dark=bss079_intro_overlay(Color.new(0,0,0),dim,99960) if dim>0
      asset=bss079_intro_asset_sprite if ["nds_biome","side_sweep","custom"].include?(style)
      if asset
        w=asset.bitmap.width*asset.zoom_x; h=asset.bitmap.height*asset.zoom_y
        case style
        when "side_sweep"
          asset.x=-w; asset.y=0
        else
          asset.x=0; asset.y=@viewport.height
        end
      end
      hold.times do |i|
        if dark && hold>0; dark.opacity=(dim*(1.0-(i+1).to_f/[hold,1].max)*0.35).round; end
        pbUpdate
      end
      move.times do |i|
        t=(i+1).to_f/move
        ease=1.0-(1.0-t)*(1.0-t)
        case style
        when "side_sweep"
          asset.x=(-asset.bitmap.width*asset.zoom_x)+(asset.bitmap.width*asset.zoom_x)*ease if asset
          asset.y=drift_y*t if asset
        when "focus_zoom"
          # Camera owns the movement; only dim/reveal here.
        when "flash_focus"
          if i==[move/3,1].max
            white=bss079_intro_overlay(Color.new(255,255,255),flash,99990)
          end
          white.opacity=(flash*(1.0-t)).round if white
        when "dark_reveal"
          dark.opacity=(dim*(1.0-t)).round if dark
        else
          if asset
            h=asset.bitmap.height*asset.zoom_y
            asset.y=@viewport.height-h*ease + drift_y*i
            asset.x=drift_x*i
            asset.opacity=(255*(1.0-[0.0,(t-0.55)/0.45].max)).round
          end
        end
        a=(255*ease).round
        foes.each do |idx,pkm,sha,po,so,zx,zy,px,py|
          pkm.opacity=[a,po.to_i].min if pkm && pkm.respond_to?(:opacity=)
          sha.opacity=[a,so.to_i].min if sha && sha.respond_to?(:opacity=)
        end
        dark.opacity=[dark.opacity.to_i,(dim*(1.0-t)).round].min if dark && style!="dark_reveal"
        pbUpdate
      end
      foes.each do |idx,pkm,sha,po,so,zx,zy,px,py|
        pkm.opacity=po if pkm && pkm.respond_to?(:opacity=)
        sha.opacity=so if sha && sha.respond_to?(:opacity=)
      end
      begin
        first=foes.find { |row| @battle.battlers[row[0]] rescue false }
        b=@battle.battlers[first[0]] if first
        b.pokemon.play_cry if b && b.respond_to?(:pokemon) && b.pokemon
      rescue
      end
      bss070_ebdx_camera_leave if ebdx_active && respond_to?(:bss070_ebdx_camera_leave)
    ensure
      [asset,dark,white].each do |sp|
        begin
          bmp=sp.bitmap if sp
          sp.dispose if sp && !(sp.disposed? rescue true)
          bmp.dispose if bmp && bmp.width==1 && bmp.height==1 && !(bmp.disposed? rescue true)
        rescue
        end
      end
      bss078_cinematic_ui_restore(ui) rescue nil
    end
  end

  def bss079_finish_wild_intro
    size=(@battle.sideSizes[1] rescue 1).to_i
    size=1 if size<1
    size.times do |i|
      idx=(2*i)+1
      next if !@battle.battlers[idx]
      @animations.push(Battle::Scene::Animation::DataBoxAppear.new(@sprites,@viewport,idx))
    end
    while inPartyAnimation?; pbUpdate; end
    if !@battle.rules[:no_battle_animations]
      size.times do |i|
        idx=(2*i)+1; b=@battle.battlers[idx]; next if !b || !b.shiny?
        if Settings::SUPER_SHINY && b.super_shiny?; pbCommonAnimation("SuperShiny",b)
        else; pbCommonAnimation("Shiny",b); end
      end
    end
  end

  def pbBattleIntroAnimation
    wild = @battle && @battle.respond_to?(:wildBattle?) && @battle.wildBattle?
    return super if !wild
    ebdx = respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    cfg=bss079_intro_config
    return super if !ebdx && cfg["useInVanilla"] != true
    bss070_ebdx_ensure_core if ebdx && respond_to?(:bss070_ebdx_ensure_core)
    bss079_play_custom_wild_intro(ebdx)
    bss079_finish_wild_intro
  rescue => e
    BSS064.log("BSS079 intro warning: #{e.class}: #{e.message}") if defined?(BSS064)
    super
  end
end
begin
  Battle::Scene.prepend(BSS079IntroAuthority) if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSS079IntroAuthority)
rescue => e
  BSS064.log("BSS079 intro install warning: #{e.class}: #{e.message}") if defined?(BSS064)
end
