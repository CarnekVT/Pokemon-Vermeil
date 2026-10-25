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
    viewport=nil; screenshot=nil; scene_copy=nil; strip=nil; dark=nil; flash=nil
    hidden=[]
    begin
      # The transition's snapshot must not leak a trainer/Pokemon before their
      # native DBK/Essentials reveal. Capture scenery only, restore immediately.
      @sprites.each do |key,sprite|
        next unless key.to_s =~ /\A(?:trainer_|player_|pokemon_|shadow_|dataBox_|party)/i
        next unless sprite && sprite.respond_to?(:visible) && sprite.respond_to?(:visible=)
        hidden << [sprite,sprite.visible]
        sprite.visible=false
      rescue StandardError
      end
      Graphics.update
      screenshot=Graphics.snap_to_bitmap
      hidden.each { |sp,vis| begin;sp.visible=vis if sp && !(sp.disposed? rescue false);rescue StandardError;end }
      hidden.clear

      viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      viewport.z=999_900
      scene_copy=Sprite.new(viewport)
      scene_copy.bitmap=screenshot
      scene_copy.ox=screenshot.width/2
      scene_copy.oy=screenshot.height/2
      scene_copy.z=0
      strip=Sprite.new(viewport)
      strip.bitmap=pbBitmap(path)
      strip.z=1
      scale=Graphics.height.to_f/[strip.bitmap.height,1].max
      strip.zoom_x=scale
      strip.zoom_y=scale
      dark=VermeilBSSNDSHandoff.full_screen_sprite(viewport,[0,0,0]);dark.z=2
      flash=VermeilBSSNDSHandoff.full_screen_sprite(viewport,[255,255,255]);flash.z=3
      duration=VermeilBSSNDSHandoff::HOLD+VermeilBSSNDSHandoff::MOVE
      c_x=Graphics.width/2.0; c_y=Graphics.height/2.0
      focus=(@sprites["trainer_1"] || @sprites["base_1"] || @sprites["pokemon_1"]) rescue nil
      fx=focus ? focus.x.to_f : c_x
      fy=focus ? focus.y.to_f : c_y
      drift=(VermeilBSSNDSHandoff::TAGS[tag] || VermeilBSSNDSHandoff::TAGS[:grass])[2]
      VermeilBSSNDSHandoff.play_sound(tag)
      duration.times do |frame|
        hold=VermeilBSSNDSHandoff::HOLD
        move=VermeilBSSNDSHandoff::MOVE
        p=(frame-hold+1).to_f/move
        p=[[p,0.0].max,1.0].min
        zoom=VermeilBSSNDSHandoff.interpolate(VermeilBSSNDSHandoff::START_ZOOM,1.0,p)
        scene_copy.zoom_x=zoom;scene_copy.zoom_y=zoom
        sx=c_x+(c_x-fx)*(zoom-1.0)
        sy=c_y+(c_y-fy)*(zoom-1.0)
        # Clamp the zoomed screenshot so no empty margins are exposed at
        # battle-scene edges, even with far-off custom trainer coordinates.
        x_spare=[(screenshot.width*zoom-Graphics.width)/2.0,0.0].max
        y_spare=[(screenshot.height*zoom-Graphics.height)/2.0,0.0].max
        scene_copy.x=[[sx,c_x-x_spare].max,c_x+x_spare].min
        scene_copy.y=[[sy,c_y-y_spare].max,c_y+y_spare].min
        strip.x=(drift[0]*[frame,hold].min) + (drift[0]*move*VermeilBSSNDSHandoff::REVEAL_SPEED*p).round
        strip.y=(drift[1]*move*VermeilBSSNDSHandoff::REVEAL_SPEED*p).round
        strip.opacity=(255*(1.0-[p/0.70,1.0].min)).round
        dark.opacity=(220*(1.0-[frame/8.0,1.0].min)).round
        flash.opacity=(frame>=duration-2 ? ((frame-duration+3)*48) : 0)
        Graphics.update
        Input.update if defined?(Input)
      end
      true
    rescue StandardError => e
      BSS064.log("NDS prelude warning: #{e.class}: #{e.message}") if defined?(BSS064)
      false
    ensure
      hidden.each { |sp,vis| begin;sp.visible=vis if sp && !(sp.disposed? rescue false);rescue StandardError;end }
      [scene_copy,strip,dark,flash].compact.each do |sp|
        begin
          bmp=sp.bitmap
          sp.bitmap=nil
          sp.dispose unless sp.disposed?
          bmp.dispose if bmp && (sp==dark || sp==flash) && !(bmp.disposed? rescue true)
        rescue StandardError
        end
      end
      screenshot.dispose if screenshot && !(screenshot.disposed? rescue true)
      viewport.dispose if viewport && !(viewport.disposed? rescue true)
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
