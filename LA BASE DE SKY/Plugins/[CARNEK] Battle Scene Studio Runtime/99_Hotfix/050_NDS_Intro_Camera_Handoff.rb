# frozen_string_literal: true
# Vermeil NDS encounter -> native Essentials/DBK trainer/wild presentation.
# Adapted from the user's WildIntroNDS.rb (the supplied Grass/Water/Cave
# 2044x480 strips are already in Graphics/Transitions).
#
# Deliberately DO NOT import the source's pbCreateBackdropSprites or its
# pbBattleIntroAnimation replacement. Those overwrite BSS/EBDX scenery and
# fight DBK's trainer intro. The prelude instead operates on a temporary
# screen snapshot in a separate viewport, with the shared camera frozen.
module VermeilBSSNDSHandoff
  HOLD = 8
  MOVE = 12
  REVEAL_SPEED = 4
  START_ZOOM = 2.0
  # Seconds, not frames: 20 iterations at 110+ FPS were a blink.
  # Keep the scene anchored during hold and ease to 100% over the reveal.
  HOLD_SECONDS = 0.12
  REVEAL_SECONDS = 0.82
  TAGS = {
    :grass => ["Graphics/Transitions/GrassIntro", ["Anim/Wind8",40,110], [-7,3]],
    :water => ["Graphics/Transitions/WaterIntro", ["Anim/Water1",40,115], [-4,4]],
    :cave  => ["Graphics/Transitions/CaveIntro", ["Anim/Whirlwind",70,105], [-3,2]]
  }

  module_function

  def slot(battle)
    env=(battle.respond_to?(:bss_environment_config) ? battle.bss_environment_config : {}) rescue {}
    sky=(env.is_a?(Hash) ? (env["skyMode"] || env[:skyMode]).to_s.downcase : "")
    return 2 if sky=="night"
    return 1 if ["dawn","sunset","evening","eve"].include?(sky)
    return 0 if ["day","noon"].include?(sky)
    # The EBDX sunset horizon is deliberately warmer than the strict clock
    # classification. Use that SAME twilight factor for the entry strip:
    # otherwise a blue night grass texture flashes before an orange sky.
    if defined?(BSSLayeredLighting)
      begin
        return 1 if BSSLayeredLighting.twilight_strength.to_f >= 0.20
        current=BSSLayeredLighting.slot
        return 2 if current==:night
        return 1 if current==:dawn
      rescue StandardError
      end
    end
    t=(battle.time rescue 0)
    (t==1 || t==2) ? t : 0
  end

  def tag(battle)
    env=(battle.environment.to_s.downcase rescue "")
    return :cave if env.include?("cave")
    return :water if env.include?("water") || env.include?("puddle")
    return :grass if env.include?("grass") || env.include?("forest")
    return :water if defined?($PokemonGlobal) && $PokemonGlobal && ($PokemonGlobal.surfing rescue false)
    enc=($game_temp.encounter_type rescue nil)
    if enc && defined?(GameData::EncounterType) && (GameData::EncounterType.exists?(enc) rescue false)
      type=(GameData::EncounterType.get(enc).type rescue nil)
      return :water if [:water,:fishing].include?(type)
      return :cave if type==:cave
      return :grass if [:land,:contest].include?(type)
    end
    return :grass if !battle
    # Trainer encounters do not always have an encounter_type; use the map's
    # environmental metadata when possible, with grass as the safe fallback.
    md=($game_map.metadata rescue nil)
    return :cave if md && (md.respond_to?(:outdoor_map) && md.outdoor_map==false)
    :grass
  end

  def asset(battle,chosen_tag)
    base=(TAGS[chosen_tag] || TAGS[:grass])[0]
    variant=(slot(battle)==1 ? "_eve" : (slot(battle)==2 ? "_night" : ""))
    candidate=base+variant
    return candidate if defined?(pbResolveBitmap) && pbResolveBitmap(candidate)
    return base if defined?(pbResolveBitmap) && pbResolveBitmap(base)
    nil
  rescue StandardError
    nil
  end

  def play_sound(chosen_tag)
    snd=(TAGS[chosen_tag] || TAGS[:grass])[1]
    pbSEPlay(snd[0],snd[1],snd[2]) if defined?(pbSEPlay)
  rescue StandardError
    nil
  end

  def interpolate(a,b,p)
    t=[[p.to_f,0.0].max,1.0].min
    t=t*t*(3.0-2.0*t)
    a+(b-a)*t
  end

  def full_screen_sprite(viewport,rgb)
    sp=Sprite.new(viewport)
    bmp=Bitmap.new(1,1)
    bmp.fill_rect(0,0,1,1,Color.new(*rgb))
    sp.bitmap=bmp
    sp.zoom_x=Graphics.width.to_f
    sp.zoom_y=Graphics.height.to_f
    sp
  end
end

module VermeilBSSNDSIntroScene
  def bss_nds_intro_active?
    return false unless @battle && @sprites
    return false unless (@battle.wildBattle? || @battle.trainerBattle?)
    # Only BSS/EBDX Blueprints own this transition. Ordinary Essentials
    # encounters should never acquire an extra independent battle intro.
    return false unless respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
    return false if @bss_nds_intro_played || @bss_nds_intro_active
    # The overlay is transparent above the biome; it must only render on a
    # fully initialized BSS/EBDX stage, never over vanilla battle_bg.
    bss070_ebdx_ensure_core if respond_to?(:bss070_ebdx_ensure_core)
    room=@bss070_ebdx_room
    return false unless room && !(room.disposed? rescue true)
    # Use one prelude for either encounter type. The native intro STILL runs
    # afterwards and remains the source of truth for trainer send-outs.
    true
  rescue StandardError
    false
  end

  # Follow the user's original WildIntroNDS sequence, but render a frozen
  # *snapshot of the EBDX room* instead of replacing its native battleback.
  # Map transition squares are owned by pbBattleAnimation and play beforehand.
  def bss_nds_prelude
    tag=VermeilBSSNDSHandoff.tag(@battle)
    path=VermeilBSSNDSHandoff.asset(@battle,tag)
    return false unless path
    @bss_nds_intro_active=true
    viewport=nil
    cover=nil
    grass=nil
    flash=nil
    darkness=nil
    bitmap=nil
    flash_bitmap=nil
    trainer_states=[]
    saved_vector=(@vector.get.clone rescue nil)
    begin
      # All encounters start behind a real black curtain. The Intro NDS
      # biome strip is drawn ABOVE this curtain (z=4), so the black never
      # hides the authored intro graphic; it only covers the live battlefield.
      viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      viewport.z=999_900
      darkness=VermeilBSSNDSHandoff.full_screen_sprite(viewport,[0,0,0,255])
      darkness.z=2
      darkness.opacity=255
      # Retain the *same* trainers/wild Pokemon under and inside the snapshot.
      # Hiding them for the capture caused a visible pop at the reveal edge.
      # Do not reveal unreleased party Pokemon; respect native scene state.

      # An initial shot from MAIN means the visual reference and Essentials'
      # trainer sendout use one baseline. No competing per-frame zoom writers.
      main=(BSS070EBDXCore.get_vector(:MAIN,@battle) rescue nil)
      @vector.snap(main) if main && @vector && @vector.respond_to?(:snap)
      # Authoritative trainer height is computed ONCE by 042 and cached.
      # EBDX/DBK cutscenes use these exact coordinates without repeatedly
      # calling pbSetPosition (which caused a one-frame height pop).
      @bss_nds_trainer_anchor={}
      if @battle.trainerBattle? && @battle.opponent
        @battle.opponent.each_index do |i|
          trainer=@sprites["trainer_#{i+1}"]
          next unless trainer && !(trainer.disposed? rescue true)
          trainer.pbSetPosition if trainer.respond_to?(:pbSetPosition)
          trainer.to_first_frame if trainer.respond_to?(:to_first_frame)
          @bss_nds_trainer_anchor[i+1]=[(trainer.x rescue nil),(trainer.y rescue nil),
                                       (trainer.z rescue nil)]
          was_visible=(trainer.visible rescue false)
          original_opacity=(trainer.opacity rescue 255)
          trainer_states << [trainer,was_visible,original_opacity]
          # The first frame can appear late, but never instantly. It fades
          # into the already aligned scene as the temporary camera settles.
          trainer.opacity=0 if was_visible && trainer.respond_to?(:opacity=)
          trainer.z=[trainer.z.to_i,49+i].max if trainer.respond_to?(:z=)
        end
      end
      room=@bss070_ebdx_room
      room.update if room && !(room.disposed? rescue true)
      # Pre-align each real battler to the SAME projected EBDX anchor it will
      # occupy after the intro. Otherwise its native pbInitSprites Y is visible
      # throughout the reveal and abruptly jumps higher at the first command.
      # One alignment BEFORE animations is safe; no runtime movement is
      # applied again while native/DBK intro owns the scene.
      if defined?(BSS103WorldSpaceBattlers) && @battle && @sprites.is_a?(Hash)
        BSS103WorldSpaceBattlers.instance_method(:bss070_ebdx_apply_world_alignment).bind(self).call
      end
      bss070_ebdx_hide_native_backdrops if respond_to?(:bss070_ebdx_hide_native_backdrops)
      # Snapshot ONLY the EBDX environment, not the animated actors. Restore
      # their original visibility IMMEDIATELY after one capture frame. Capturing
      # trainers/Pokemon in this bitmap froze them while the live sprites moved,
      # and their positions appeared to jump when the overlay disappeared.
      captured=[]
      begin
        @sprites.each do |key,sp|
          next unless key.to_s.match?(/\A(?:trainer_|player_|pokemon_|shadow_|dataBox_|party)/i)
          next unless sp && !(sp.disposed? rescue true) && sp.respond_to?(:visible) && sp.respond_to?(:visible=)
          captured << [sp,sp.visible]
          sp.visible=false
        end
        Graphics.update
        # Capture the authored stage, not our temporary black curtain.
        # The curtain remains opaque on-screen throughout the operation.
        begin
          darkness.visible=false if darkness
          bitmap=Graphics.snap_to_bitmap
        ensure
          darkness.visible=true if darkness
        end
      ensure
        captured.each do |sp,was_visible|
          sp.visible=was_visible if sp && !(sp.disposed? rescue true)
        end
      end
      return false unless bitmap && !(bitmap.disposed? rescue false)
      # Underlying TrainerSprite and DBK animated Pokemon keep playing while
      # this environment-only snapshot zooms and fades.

      viewport ||= Viewport.new(0,0,Graphics.width,Graphics.height)
      viewport.z=999_900
      cover=Sprite.new(viewport)
      cover.bitmap=bitmap
      cover.ox=bitmap.width/2
      cover.oy=bitmap.height/2
      cover.z=0
      cover.opacity=255
      cx=Graphics.width/2.0
      cy=Graphics.height/2.0
      focus=if @battle.trainerBattle?
              @sprites["trainer_1"]
            else
              @sprites["pokemon_1"]
            end
      fx=(focus.x rescue nil)
      fy=(focus.y rescue nil)
      if !fx || !fy
        pos=if @battle.trainerBattle?
              Battle::Scene.pbTrainerPosition(1)
            else
              Battle::Scene.pbBattlerPosition(1)
            end
        fx=pos[0];fy=pos[1]
      end
      fx=fx.to_f;fy=fy.to_f

      grass=Sprite.new(viewport)
      grass.bitmap=pbBitmap(path)
      return false unless grass.bitmap
      # Source WildIntroNDS paints the FULL 2044x480 RGBA strip, at 100%.
      # The old BSS bridge cut it at 52%, stretched it and left a hard seam.
      grass.z=4
      grass.ox=0
      grass.oy=0
      grass.x=0
      grass.y=0
      grass.zoom_x=1.0
      grass.zoom_y=1.0
      # Fade/slide the biome graphic in from black; do not pop the full
      # alpha strip into existence at full opacity on its first render.
      grass.opacity=0

      flash=Sprite.new(viewport)
      flash_bitmap=Bitmap.new(1,1)
      flash_bitmap.fill_rect(0,0,1,1,Color.new(255,255,255,255))
      flash.bitmap=flash_bitmap
      flash.z=5
      flash.zoom_x=Graphics.width.to_f
      flash.zoom_y=Graphics.height.to_f
      flash.opacity=0

      VermeilBSSNDSHandoff.play_sound(tag)
      hold=VermeilBSSNDSHandoff::HOLD_SECONDS
      duration=VermeilBSSNDSHandoff::REVEAL_SECONDS
      # A compact three-beat reveal: graphic enters over black, scenery
      # sweeps from the opponent/right and zooms OUT, then the live actors
      # appear on the final stable camera. This is not a second battle intro.
      hold=0.16
      duration=1.46
      drift=(VermeilBSSNDSHandoff::TAGS[tag] || VermeilBSSNDSHandoff::TAGS[:grass])[2]
      dx,dy=drift
      began=Time.now.to_f
      frame=0
      loop do
        elapsed=[Time.now.to_f-began,0.0].max
        p=[[(elapsed-hold)/duration,0.0].max,1.0].min
        # Right-side close-up -> deliberate pullback to a full-scene frame.
        # The last camera coordinates are EXACTLY (cx,cy,zoom 1.0); the
        # screenshot cannot snap when switching to the live EBDX backdrop.
        pull=[[(p-0.08)/0.86,0.0].max,1.0].min
        ease=pull*pull*(3.0-2.0*pull)
        zoom=1.82-0.82*ease
        sweep=[[(p-0.08)/0.78,0.0].max,1.0].min
        sweep=sweep*sweep*(3.0-2.0*sweep)
        lead_x=[[fx+Graphics.width*0.12,Graphics.width*0.88].min,
                Graphics.width*0.42].max
        close_x=cx+(cx-lead_x)*zoom
        close_y=cy+(cy-fy)*zoom
        sx=close_x*(1.0-sweep)+cx*sweep
        sy=close_y*(1.0-sweep)+cy*sweep
        halfw=bitmap.width.to_f*zoom/2.0
        halfh=bitmap.height.to_f*zoom/2.0
        cover.x=[[sx,Graphics.width-halfw].max,halfw].min
        cover.y=[[sy,Graphics.height-halfh].max,halfh].min
        cover.zoom_x=zoom
        cover.zoom_y=zoom

        # ORAS-like choreography: the biome rushes in over black, holds
        # briefly, then peels away as the world becomes visible. Start fully
        # transparent, including the first Graphics.update after allocation.
        entrance=[[elapsed/0.27,0.0].max,1.0].min
        entrance=entrance*entrance*(3.0-2.0*entrance)
        departure=[[(elapsed-(hold+duration*0.30))/(duration*0.67),0.0].max,1.0].min
        departure=departure*departure*(3.0-2.0*departure)
        grass.x=(-42.0*(1.0-entrance)+dx.to_f*elapsed*9.0).round
        grass.y=(dy.to_f*elapsed*3.0).round
        grass.opacity=(255.0*entrance*(1.0-departure)).round
        # Strong but brief impact flash as the GrassIntro tears away.
        flash_p=[[(elapsed-hold)/0.20,0.0].max,1.0].min
        flash.opacity=0 if flash  # No white flash to wash out the intro art.
        # Reveal the *moving scenery* early, then dissolve its screenshot
        # only when the camera is nearly on the final (1x, MAIN) frame.
        # Prevents two differently aligned terrain copies from ghosting.
        reveal=[[(p-0.77)/0.23,0.0].max,1.0].min
        smooth_reveal=reveal*reveal*(3.0-2.0*reveal)
        cover.opacity=(255.0*(1.0-smooth_reveal)).round
        if darkness
          dark_p=[[(p-0.20)/0.57,0.0].max,1.0].min
          dark_ease=dark_p*dark_p*(3.0-2.0*dark_p)
          darkness.opacity=(255.0*(1.0-dark_ease)).round
        end
        # The native trainer sprite is already at its 042-authorized floor,
        # with its bitmap still on frame zero. Fade visibility in without
        # moving it, then let pbAnimateTrainerIntros play from the beginning.
        appear=[[(p-0.82)/0.18,0.0].max,1.0].min
        appear=appear*appear*(3.0-2.0*appear)
        trainer_states.each do |trainer,was_visible,old_opacity|
          next unless was_visible && trainer && !(trainer.disposed? rescue true)
          trainer.opacity=(old_opacity.to_f*appear).round if trainer.respond_to?(:opacity=)
        end
        # Do not advance TrainerBitmapWrapper here. Only the native
        # pbAnimateTrainerIntros owns trainer frame playback, after reveal.
        # DBK advances animated Pokemon from pbFrameUpdate; Graphics.update
        # alone makes them appear frozen for the whole encounter transition.
        Graphics.update
        pbFrameUpdate if respond_to?(:pbFrameUpdate)
        frame+=1
        break if elapsed>=hold+duration && frame>=2
        break if frame>=1000 # Never hang if a platform clock misbehaves.
      end
      # Native trainer animation must begin on its *first* frame after the
      # scenery has been revealed, even when the graphics driver advanced an
      # animated bitmap during an unrelated render pass.
      if @battle.trainerBattle? && @battle.opponent
        @battle.opponent.each_index do |i|
          trainer=@sprites["trainer_#{i+1}"]
          trainer.to_first_frame if trainer && trainer.respond_to?(:to_first_frame)
        end
      end
      # Ensure the final frame is at exactly 100% even on early frame cap.
      cover.zoom_x=1.0
      cover.zoom_y=1.0
      grass.opacity=0
      flash.opacity=0
      cover.opacity=0
      darkness.opacity=0 if darkness
      Graphics.update
      true
    rescue StandardError => e
      BSS064.log("NDS reference reveal: #{e.class}: #{e.message}") if defined?(BSS064)
      false
    ensure
      # Never force an old trainer position or leave the scene behind a
      # full-screen temporary sprite, even on error.
      if @vector && @vector.respond_to?(:snap)
        # Native sendout inherits the exact MAIN camera used for the final
        # screenshot, independent of intro focus pan/zoom.
        @vector.snap(main || saved_vector) if main || saved_vector
      end
      trainer_states.each do |trainer,was_visible,old_opacity|
        next unless trainer && !(trainer.disposed? rescue true)
        trainer.opacity=old_opacity if trainer.respond_to?(:opacity=)
        trainer.visible=was_visible if trainer.respond_to?(:visible=)
      end
      if darkness
        begin
          bmp=darkness.bitmap
          darkness.bitmap=nil
          darkness.dispose unless darkness.disposed?
          bmp.dispose if bmp && !(bmp.disposed? rescue true)
        rescue StandardError
        end
      end
      if flash
        begin;flash.bitmap=nil;flash.dispose unless flash.disposed?;rescue StandardError;end
      end
      begin;flash_bitmap.dispose if flash_bitmap && !flash_bitmap.disposed?;rescue StandardError;end
      if grass
        begin;grass.bitmap=nil;grass.dispose unless grass.disposed?;rescue StandardError;end
      end
      if cover
        begin;cover.bitmap=nil;cover.dispose unless cover.disposed?;rescue StandardError;end
      end
      begin;bitmap.dispose if bitmap && !bitmap.disposed?;rescue StandardError;end
      begin;viewport.dispose if viewport && !viewport.disposed?;rescue StandardError;end
      @bss_nds_intro_active=false
    end
  end

  def pbBattleIntroAnimation(*args, &block)
    engaged=false
    return super unless bss_nds_intro_active?
    engaged=true
    @bss_nds_intro_played=true
    @vermeil_cinema_trainer_intro_depth=@vermeil_cinema_trainer_intro_depth.to_i+1
    # If the reference textures or screenshot renderer are missing, the
    # original native intro is the safe fallback.
    return super unless bss_nds_prelude

    # WildIntroNDS intentionally does not invoke a second Animation::Intro
    # after revealing the battlefield. The former BSS bridge did, producing
    # another black flash/slide and spoiling the camera handoff.
    if @battle.trainerBattle?
      # TrainerBitmapWrapper animation (not Pokemon Intro2) is the one that
      # should run in a scripted trainer battle. Resume any unplayed frames
      # from the reveal before native PokeballTrainerSendOut takes over.
      pbAnimateTrainerIntros if respond_to?(:pbAnimateTrainerIntros)
      pbShowPartyLineup(0,true)
      pbShowPartyLineup(1,true)
      return
    end
    @battle.sideSizes[1].times do |i|
      idx=(2*i)+1
      next unless @battle.battlers[idx]
      @animations.push(Battle::Scene::Animation::DataBoxAppear.new(@sprites,@viewport,idx))
    end
    @animations.push(Battle::Scene::Animation::Intro2.new(@sprites,@viewport,@battle.sideSizes[1]))
    while inPartyAnimation?
      pbUpdate
    end
    unless @battle.rules[:no_battle_animations]
      @battle.sideSizes[1].times do |i|
        idx=(2*i)+1
        battler=@battle.battlers[idx]
        next unless battler && battler.shiny?
        kind=(Settings::SUPER_SHINY && battler.super_shiny?) ? "SuperShiny" : "Shiny"
        pbCommonAnimation(kind,battler)
      end
    end
  ensure
    if engaged && @vermeil_cinema_trainer_intro_depth.to_i>0
      @vermeil_cinema_trainer_intro_depth-=1
    end
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(VermeilBSSNDSIntroScene)
  Battle::Scene.prepend(VermeilBSSNDSIntroScene)
end
