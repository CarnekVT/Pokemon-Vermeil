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
    bitmap=nil
    flash_bitmap=nil
    saved_vector=(@vector.get.clone rescue nil)
    begin
      # Retain the *same* trainers/wild Pokemon under and inside the snapshot.
      # Hiding them for the capture caused a visible pop at the reveal edge.
      # Do not reveal unreleased party Pokemon; respect native scene state.

      # An initial shot from MAIN means the visual reference and Essentials'
      # trainer sendout use one baseline. No competing per-frame zoom writers.
      main=(BSS070EBDXCore.get_vector(:MAIN,@battle) rescue nil)
      @vector.snap(main) if main && @vector && @vector.respond_to?(:snap)
      # EBDX foliage/terrain uses room z up to ~27. Native DBK TrainerSprite
      # begins at z=10 and can therefore look absent during the reveal,
      # only popping in when later battle animations raise its depth.
      # Keep the ORIGINAL sprite and original XY, but put it above scenery.
      if @battle.trainerBattle? && @battle.opponent
        @battle.opponent.each_index do |i|
          trainer=@sprites["trainer_#{i+1}"]
          next unless trainer && !(trainer.disposed? rescue true) && trainer.respond_to?(:z=)
          trainer.z=[trainer.z.to_i,49+i].max
        end
      end
      room=@bss070_ebdx_room
      room.update if room && !(room.disposed? rescue true)
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
        bitmap=Graphics.snap_to_bitmap
      ensure
        captured.each do |sp,was_visible|
          sp.visible=was_visible if sp && !(sp.disposed? rescue true)
        end
      end
      return false unless bitmap && !(bitmap.disposed? rescue false)
      # Underlying TrainerSprite and DBK animated Pokemon keep playing while
      # this environment-only snapshot zooms and fades.

      viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
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
      grass.opacity=255

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
      drift=(VermeilBSSNDSHandoff::TAGS[tag] || VermeilBSSNDSHandoff::TAGS[:grass])[2]
      dx,dy=drift
      began=Time.now.to_f
      trainer_frame_at=began
      frame=0
      loop do
        elapsed=[Time.now.to_f-began,0.0].max
        p=[[(elapsed-hold)/duration,0.0].max,1.0].min
        smooth=p*p*(3.0-2.0*p)
        zoom=2.0-smooth
        sx=cx+(cx-fx)*zoom
        sy=cy+(cy-fy)*zoom
        halfw=bitmap.width.to_f*zoom/2.0
        halfh=bitmap.height.to_f*zoom/2.0
        cover.x=[[sx,Graphics.width-halfw].max,halfw].min
        cover.y=[[sy,Graphics.height-halfh].max,halfh].min
        cover.zoom_x=zoom
        cover.zoom_y=zoom

        # The untouched original full-size transition strip drifts gently
        # while its alpha reveals the real, already rendered EBDX room.
        grass.x=(dx.to_f*(elapsed*60.0)*0.25).round
        grass.y=(dy.to_f*(elapsed*60.0)*0.12).round
        grass.opacity=(255.0*(1.0-[[p*1.35,1.0].min,0.0].max)).round
        # Strong but brief impact flash as the GrassIntro tears away.
        flash_p=[[(elapsed-hold)/0.22,0.0].max,1.0].min
        flash.opacity=elapsed<hold ? 0 : (158.0*(1.0-(2.0*flash_p-1.0).abs)).round
        # Reveal live actors/terrain during the final third, not a frozen
        # copy of the battlers. Native animation frames remain authoritative.
        reveal=[[(p-0.57)/0.43,0.0].max,1.0].min
        cover.opacity=(255.0*(1.0-reveal*reveal*(3.0-2.0*reveal))).round
        if @battle.trainerBattle? && p>=0.22 && Time.now.to_f-trainer_frame_at>=0.045
          (@battle.opponent || []).each_index do |i|
            trainer=@sprites["trainer_#{i+1}"]
            trainer.play if trainer && trainer.respond_to?(:play) &&
                            trainer.respond_to?(:finished?) && !trainer.finished?
          end
          trainer_frame_at=Time.now.to_f
        end
        # DBK advances animated Pokemon from pbFrameUpdate; Graphics.update
        # alone makes them appear frozen for the whole encounter transition.
        Graphics.update
        pbFrameUpdate if respond_to?(:pbFrameUpdate)
        frame+=1
        break if elapsed>=hold+duration && frame>=2
        break if frame>=1000 # Never hang if a platform clock misbehaves.
      end
      # Ensure the final frame is at exactly 100% even on early frame cap.
      cover.zoom_x=1.0
      cover.zoom_y=1.0
      grass.opacity=0
      flash.opacity=0
      cover.opacity=0
      Graphics.update
      true
    rescue StandardError => e
      BSS064.log("NDS reference reveal: #{e.class}: #{e.message}") if defined?(BSS064)
      false
    ensure
      # Never force an old trainer position or leave the scene behind a
      # full-screen temporary sprite, even on error.
      if @vector && @vector.respond_to?(:snap)
        # Native trainer sendout must inherit the same MAIN shot the reveal
        # settled on, not a stale overview shot saved before the transition.
        @vector.snap(main || saved_vector) if main || saved_vector
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
