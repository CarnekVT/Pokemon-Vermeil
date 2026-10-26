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
    # Use one prelude for either encounter type. The native intro STILL runs
    # afterwards and remains the source of truth for trainer send-outs.
    true
  rescue StandardError
    false
  end

  def bss_nds_prelude
    tag=VermeilBSSNDSHandoff.tag(@battle)
    path=VermeilBSSNDSHandoff.asset(@battle,tag)
    return false unless path
    @bss_nds_intro_active=true
    viewport=nil
    strip=nil
    # Keep the real EBDX battle world underneath: there must not be a second
    # capture/zoom/background nor a full black frame between transitions.
    # The NDS strip is RGBA with transparent sky and an opaque patterned floor.
    begin
      viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      viewport.z=999_900
      strip=Sprite.new(viewport)
      strip.bitmap=pbBitmap(path)
      return false unless strip.bitmap
      strip.z=1
      strip.zoom_y=Graphics.height.to_f/[strip.bitmap.height,1].max
      strip.zoom_x=strip.zoom_y
      # Start at the leftmost section; strips are authored at 2044x480
      # and can move across the screen without wrapping or black seams.
      max_travel=[strip.bitmap.width*strip.zoom_x-Graphics.width,0.0].max
      travel=[Graphics.width.to_f*0.36,max_travel].min
      strip.x=0
      strip.y=0
      strip.opacity=255
      VermeilBSSNDSHandoff.play_sound(tag)
      hold=VermeilBSSNDSHandoff::HOLD
      move=[VermeilBSSNDSHandoff::MOVE*2,18].max
      duration=hold+move
      duration.times do |frame|
        p=[[((frame-hold).to_f/[move,1].max),0.0].max,1.0].min
        eased=p*p*(3.0-2.0*p)
        strip.x=-(travel*eased).round
        # Tiny vertical parallax, never enough to expose the bottom edge.
        strip.y=0
        fade=[[((p-0.44)/0.56),0.0].max,1.0].min
        strip.opacity=(255*(1.0-fade)).round
        Graphics.update
        Input.update if defined?(Input)
      end
      true
    rescue StandardError => e
      BSS064.log("NDS overlay prelude: #{e.class}: #{e.message}") if defined?(BSS064)
      false
    ensure
      if strip
        # pbBitmap is a game-owned cached bitmap, not ours to dispose.
        begin;strip.bitmap=nil;strip.dispose unless strip.disposed?;rescue StandardError;end
      end
      begin;viewport.dispose if viewport && !(viewport.disposed? rescue true);rescue StandardError;end
      @bss_nds_intro_active=false
    end
  end

  def pbBattleIntroAnimation(*args, &block)
    engaged=false
    return super unless bss_nds_intro_active?
    engaged=true
    @bss_nds_intro_played=true
    @vermeil_cinema_trainer_intro_depth=@vermeil_cinema_trainer_intro_depth.to_i+1
    bss_nds_prelude
    # Handoff: after the NDS texture zoom, continue with the original Trainer
    # intro animation (or the native Wild reveal) instead of replacing it.
    super
  ensure
    if engaged && @vermeil_cinema_trainer_intro_depth.to_i>0
      @vermeil_cinema_trainer_intro_depth-=1
    end
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(VermeilBSSNDSIntroScene)
  Battle::Scene.prepend(VermeilBSSNDSIntroScene)
end
