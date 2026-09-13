#===============================================================================
# Wild Intro NDS-Style (Camera Zoom & Fix Black Sprite)
#===============================================================================

module VermeilWildIntroNDS
  HOLD_TIME    = 8
  MOVE_TIME    = 12
  REVEAL_SPEED = 4

  # Map IDs que deben forzar el tag :indoor aunque el metadata diga outdoor.
  INDOOR_MAP_IDS  = [
    # 12, 34, 56
  ]

  # Map IDs con intro "especial" (torres, lugares clave, etc.).
  SPECIAL_MAP_IDS = [
    # 101, 202
  ]

  # Overrides por tipo de encounter (GameData::EncounterType ID).
  # Valores posibles: :tag, :se, :visual, :drift
  #   :se     => "Anim/Wind8" o ["Anim/Wind8", vol, pitch]
  #   :visual => "Graphics/Transitions/GrassIntro"
  #   :drift  => [dx, dy]
  INTRO_BY_ENCOUNTER_ID = {
    # :OldRod => { :tag => :fish, :visual => "Graphics/Transitions/FishIntro" }
    :HoneyTree  => { :tag => :grass },
    :HeadbuttLow  => { :tag => :grass },
    :HeadbuttHigh => { :tag => :grass }
  }

  # Overrides por ID de mapa.
  INTRO_BY_MAP_ID = {
    # 42 => { :tag => :special, :visual => "Graphics/Transitions/SpecialIntro" }
  }

  # Backdrop water por zona (usa Map Metadata -> battle_background).
  # Se espera que los archivos sigan este formato:
  #   Base_bg_water_bg
  #   Base_eve_bg_water_bg
  #   Base_night_bg_water_bg
  WATER_BACKDROP_SUFFIX = "_bg_water"

  # Sonidos por tipo de encounter.
  # Formato: "SE/Name" o ["SE/Name", volumen, pitch]
  SE_BY_TAG = {
    :grass      => ["Anim/Wind8", 40, 110],
    :land       => ["Anim/Wind8", 40, 110],
    :water      => ["Anim/Water1", 40, 115],
    :fish       => ["Anim/Water1", 40, 115],
    :cave       => ["Anim/Whirlwind", 70, 105],
    :indoor     => ["Anim/Wind7", 60, 110],
    :special    => ["Anim/Whirlwind", 80, 100],
    :rocksmash  => ["Anim/Wind5", 70, 110],
    :headbutt   => ["Anim/Wind1", 70, 110],
    :radar      => ["Anim/Wind8", 70, 120],
    :contest    => ["Anim/Wind7", 70, 115],
    :other      => ["Anim/Wind8", 70, 115]
  }

  # Visuales por tipo de encounter (usar graficos en Graphics/Transitions).
  # Si el archivo no existe, se hara fallback a :other o se omite.
  VISUAL_BY_TAG = {
    :grass      => "Graphics/Transitions/GrassIntro",
    :land       => "Graphics/Transitions/GrassIntro",
    :water      => "Graphics/Transitions/WaterIntro",
    :fish       => "Graphics/Transitions/WaterIntro",
    :cave       => "Graphics/Transitions/CaveIntro",
    :indoor     => "Graphics/Transitions/IndoorIntro",
    :special    => "Graphics/Transitions/SpecialIntro",
    :rocksmash  => "Graphics/Transitions/RockSmashIntro",
    :headbutt   => "Graphics/Transitions/HeadbuttIntro",
    :radar      => "Graphics/Transitions/RadarIntro",
    :contest    => "Graphics/Transitions/ContestIntro",
    :other      => "Graphics/Transitions/GrassIntro"
  }

  # Drift por tag: [dx, dy]
  DRIFT_BY_TAG = {
    :grass      => [-7, 3],
    :land       => [-6, 2],
    :water      => [-4, 4],
    :fish       => [-5, 3],
    :cave       => [-3, 2],
    :indoor     => [-2, 1],
    :special    => [-2, 1],
    :rocksmash  => [-4, 2],
    :headbutt   => [-4, 2],
    :radar      => [-6, 2],
    :contest    => [-5, 2],
    :other      => [-6, 2]
  }
  def self.enabled?
    return true
  end

  def self.encounter_tag(battle)
    map_id = $game_map&.map_id
    return :special if map_id && SPECIAL_MAP_IDS.include?(map_id)
    return :indoor if map_id && INDOOR_MAP_IDS.include?(map_id)
    return :indoor if $game_map&.metadata && !$game_map.metadata.outdoor_map

    enc_id = $game_temp&.encounter_type
    if enc_id && GameData::EncounterType.exists?(enc_id)
      enc_data = GameData::EncounterType.get(enc_id)
      case enc_data.type
      when :fishing then return :fish
      when :water   then return :water
      when :cave    then return :cave
      when :land    then return :land
      when :contest then return :contest
      end
      case enc_id
      when :RockSmash then return :rocksmash
      when :HeadbuttLow, :HeadbuttHigh then return :headbutt
      when :PokeRadar then return :radar
      end
    end

    if battle
      return :grass if [:Grass, :TallGrass, :ForestGrass].include?(battle.environment)
      return :water if [:MovingWater, :StillWater, :Puddle, :Underwater].include?(battle.environment)
      return :cave if [:Cave].include?(battle.environment)
    end
    return :other
  end

  def self.intro_se_for(tag)
    return SE_BY_TAG[tag] || SE_BY_TAG[:other]
  end

  def self.resolve_visual_name(base, time)
    return nil if nil_or_empty?(base)
    trial = nil
    case time
    when 1 then trial = base + "_eve"
    when 2 then trial = base + "_night"
    end
    return trial if trial && pbResolveBitmap(trial)
    return base if pbResolveBitmap(base)
    return nil
  end

  def self.intro_visual_for(tag, battle)
    time = battle&.time || 0
    base = VISUAL_BY_TAG[tag] || VISUAL_BY_TAG[:other]
    name = resolve_visual_name(base, time)
    if !name && tag != :other
      name = resolve_visual_name(VISUAL_BY_TAG[:other], time)
    end
    return name
  end

  def self.intro_drift_for(tag)
    return DRIFT_BY_TAG[tag] || DRIFT_BY_TAG[:other] || [-6, 2]
  end

  def self.intro_config_for(battle)
    tag = encounter_tag(battle)
    visual_base = nil
    se = nil
    drift = nil

    enc_id = $game_temp&.encounter_type
    if enc_id && INTRO_BY_ENCOUNTER_ID[enc_id]
      cfg = INTRO_BY_ENCOUNTER_ID[enc_id]
      tag = cfg[:tag] if cfg[:tag]
      visual_base = cfg[:visual] if cfg[:visual]
      se = cfg[:se] if cfg[:se]
      drift = cfg[:drift] if cfg[:drift]
    end

    map_id = $game_map&.map_id
    if map_id && INTRO_BY_MAP_ID[map_id]
      cfg = INTRO_BY_MAP_ID[map_id]
      tag = cfg[:tag] if cfg[:tag]
      visual_base = cfg[:visual] if cfg[:visual]
      se = cfg[:se] if cfg[:se]
      drift = cfg[:drift] if cfg[:drift]
    end

    time = battle&.time || 0
    visual_base ||= VISUAL_BY_TAG[tag] || VISUAL_BY_TAG[:other]
    visual = resolve_visual_name(visual_base, time)
    if !visual && tag != :other
      visual = resolve_visual_name(VISUAL_BY_TAG[:other], time)
    end
    se ||= intro_se_for(tag)
    drift ||= intro_drift_for(tag)
    return { :tag => tag, :visual => visual, :se => se, :drift => drift }
  end

  def self.water_encounter?(battle)
    return true if $PokemonGlobal&.surfing
    enc_id = $game_temp&.encounter_type
    if enc_id && GameData::EncounterType.exists?(enc_id)
      enc_type = GameData::EncounterType.get(enc_id).type
      return true if [:water, :fishing].include?(enc_type)
    end
    if battle
      return true if [:MovingWater, :StillWater, :Puddle, :Underwater].include?(battle.environment)
    end
    return false
  end

  def self.time_tag_for(battle)
    return "eve"   if battle&.time == 1
    return "night" if battle&.time == 2
    return nil
  end

  def self.water_backdrop_for(battle)
    base = $game_map&.metadata&.battle_background
    return nil if nil_or_empty?(base)
    # If map metadata already includes "_bg", strip it for water variants.
    base = base.sub(/_bg\z/, "")
    time_tag = time_tag_for(battle)
    if time_tag
      name = "#{base}_#{time_tag}#{WATER_BACKDROP_SUFFIX}"
      return name if valid_backdrop?(name)
    end
    name = "#{base}#{WATER_BACKDROP_SUFFIX}"
    return name if valid_backdrop?(name)
    return nil
  end

  def self.valid_backdrop?(name)
    return false if nil_or_empty?(name)
    return true if pbResolveBitmap("Graphics/Battlebacks/#{name}")
    return true if pbResolveBitmap("Graphics/Battlebacks/#{name}_bg")
    return false
  end

  def self.reveal_wait_frames
    # Aparecer justo después de iniciar el reveal
    return HOLD_TIME + 16
  end
end

# Override backdrop for water encounters to be zone-dependent.
module BattleCreationHelperMethods
  class << self
    alias_method :vermeil_prepare_battle, :prepare_battle unless method_defined?(:vermeil_prepare_battle)
  end

  def self.prepare_battle(battle)
    vermeil_prepare_battle(battle)
    return if !VermeilWildIntroNDS.water_encounter?(battle)
    water_backdrop = VermeilWildIntroNDS.water_backdrop_for(battle)
    if VermeilWildIntroNDS.valid_backdrop?(water_backdrop)
      battle.backdrop = water_backdrop
      return
    end
    base = $game_map&.metadata&.battle_background
    if VermeilWildIntroNDS.valid_backdrop?(base)
      battle.backdrop = base
      return
    end
    # Last resort: ensure we don't point to a missing backdrop (e.g., "water").
    if !VermeilWildIntroNDS.valid_backdrop?(battle.backdrop)
      battle.backdrop = "indoor1" if VermeilWildIntroNDS.valid_backdrop?("indoor1")
    end
  end
end

class Battle::Scene::Animation::TrainerIntroReveal < Battle::Scene::Animation
  def initialize(sprites, viewport, battle)
    @battle = battle
    super(sprites, viewport)
  end

  def createProcesses
    fadeTime = 8
    holdTime = VermeilWildIntroNDS::HOLD_TIME
    moveTime = VermeilWildIntroNDS::MOVE_TIME
    revealSpeed = VermeilWildIntroNDS::REVEAL_SPEED
    zoomMoveTime = [(moveTime / revealSpeed.to_f).round, 1].max
    totalTime = holdTime + moveTime

    centerX = Graphics.width / 2
    centerY = Graphics.height / 2

    zoomStart = 200
    zoomEnd = 100

    focusX = centerX
    focusY = centerY
    if @sprites["trainer_1"]
      focusX = @sprites["trainer_1"].x
      focusY = @sprites["trainer_1"].y
    end

    if @sprites["battle_bg2"]
      @sprites["battle_bg2"].visible = false
    end

    if @sprites["battle_bg"]
      bg = @sprites["battle_bg"]
      bg.visible = false

      tempBG = Sprite.new(@viewport)
      tempBG.bitmap = bg.bitmap
      tempBG.x = centerX
      tempBG.y = centerY
      tempBG.ox = tempBG.bitmap.width / 2
      tempBG.oy = tempBG.bitmap.height / 2
      tempBG.z = 0
      tempBG.mirror = bg.mirror
      tempBG.visible = false
      @tempSprites << tempBG

      bgStartX = centerX + (centerX - focusX) * (zoomStart / 100.0)
      bgStartY = centerY + (centerY - focusY) * (zoomStart / 100.0)
      if tempBG.bitmap
        w_scaled = tempBG.bitmap.width * (zoomStart / 100.0)
        h_scaled = tempBG.bitmap.height * (zoomStart / 100.0)
        minX = Graphics.width - (w_scaled / 2.0)
        maxX = w_scaled / 2.0
        minY = Graphics.height - (h_scaled / 2.0)
        maxY = h_scaled / 2.0
        bgStartX = [[bgStartX, minX].max, maxX].min
        bgStartY = [[bgStartY, minY].max, maxY].min
      end

      bgAnim = addSprite(tempBG, PictureOrigin::CENTER)
      bgAnim.setVisible(0, true)
      bgAnim.setXY(0, bgStartX, bgStartY)
      bgAnim.moveXY(holdTime, zoomMoveTime, centerX, centerY)
      bgAnim.setZoom(0, zoomStart)
      bgAnim.moveZoom(holdTime, zoomMoveTime, zoomEnd)
      bgAnim.setCallback(totalTime, proc { bg.visible = true })
    end

    intro_cfg = VermeilWildIntroNDS.intro_config_for(@battle)
    intro_name = intro_cfg[:visual]
    if intro_name
      intro = addNewSprite(0, 0, intro_name)
      se = intro_cfg[:se]
      if se
        if se.is_a?(Array)
          intro.setSE(0, se[0], se[1], se[2])
        else
          intro.setSE(0, se)
        end
      end
      intro.setZ(0, 9000)
      intro.setOpacity(0, 255)
      drift = intro_cfg[:drift]
      drift_dx = drift[0]
      drift_dy = drift[1]
      end_x_hold = drift_dx * holdTime
      end_x_final = end_x_hold + (drift_dx * moveTime * revealSpeed)
      end_y_final = drift_dy * moveTime * revealSpeed
      intro.setXY(0, 0, 0)
      intro.moveXY(0, holdTime, end_x_hold, 0)
      intro.moveXY(holdTime, moveTime, end_x_final, end_y_final)
      intro.moveOpacity(holdTime, (moveTime / 2.0).ceil, 0)
    end

    ["base_0", "base_1"].each do |baseName|
      next if !@sprites[baseName]
      base = @sprites[baseName]
      base.visible = false

      tempBase = Sprite.new(@viewport)
      tempBase.bitmap = base.bitmap
      tempBase.ox = base.ox
      tempBase.oy = base.oy
      tempBase.z = base.z
      tempBase.x = base.x
      tempBase.y = base.y
      tempBase.visible = false
      @tempSprites << tempBase

      endX = base.x
      endY = base.y
      startX = centerX + (endX - focusX) * (zoomStart / 100.0)
      startY = centerY + (endY - focusY) * (zoomStart / 100.0)

      origin = (baseName == "base_0") ? PictureOrigin::BOTTOM : PictureOrigin::CENTER
      baseAnim = addSprite(tempBase, origin)
      baseAnim.setVisible(0, true)
      baseAnim.setXY(0, startX, startY)
      baseAnim.moveXY(holdTime, moveTime, endX, endY)
      baseAnim.setZoom(0, zoomStart)
      baseAnim.moveZoom(holdTime, zoomMoveTime, zoomEnd)
      baseAnim.setCallback(totalTime, proc { base.visible = true })
    end

    idx = 1
    while @sprites["trainer_#{idx}"]
      trainer_sprite = @sprites["trainer_#{idx}"]
      trainer_sprite.visible = false

      temp = Sprite.new(@viewport)
      temp.bitmap = trainer_sprite.bitmap
      temp.ox = trainer_sprite.ox
      temp.oy = trainer_sprite.oy
      temp.z = trainer_sprite.z
      temp.x = trainer_sprite.x
      temp.y = trainer_sprite.y
      temp.visible = false
      @tempSprites << temp

      endX = trainer_sprite.x - trainer_sprite.ox
      endY = trainer_sprite.y - trainer_sprite.oy

      trainer = addSprite(temp, PictureOrigin::TOP_LEFT)
      trainer.setVisible(0, true)
      trainer.setXY(0, endX, endY)
      trainer.setOpacity(0, 0)
      trainer.moveOpacity(holdTime, 4, 255)
      trainer.setCallback(totalTime, proc { trainer_sprite.visible = true })
      idx += 1
    end

    blackScreen = addNewSprite(0, 0, "Graphics/Battle animations/black_screen")
    blackScreen.setZ(0, 9999)
    blackScreen.setOpacity(0, 255)
    blackScreen.moveOpacity(0, fadeTime, 0)

    whiteScreen = addNewSprite(0, 0, "Graphics/Battle animations/white_screen")
    whiteScreen.setZ(0, 1010)
    whiteScreen.setOpacity(0, 0)
    whiteScreen.moveOpacity(holdTime, 2, 160)
    whiteScreen.moveOpacity(holdTime + 2, 6, 0)
  end
end

class Battle::Scene
  # Allow backdrops that already include "_bg" (e.g., NewBark_bg_water.png).
  def pbBackdropBGPath(name)
    direct = "Graphics/Battlebacks/#{name}"
    return direct if pbResolveBitmap(direct)
    return "Graphics/Battlebacks/#{name}_bg"
  end

  # Override to use pbBackdropBGPath for battle backgrounds.
  def pbCreateBackdropSprites
    case @battle.time
    when 1 then time = "eve"
    when 2 then time = "night"
    end
    # Put everything together into backdrop, bases and message bar filenames
    backdropFilename = @battle.backdrop
    baseFilename = @battle.backdrop
    baseFilename = sprintf("%s_%s", baseFilename, @battle.backdropBase) if @battle.backdropBase
    messageFilename = @battle.backdrop
    if time
      trialName = sprintf("%s_%s", backdropFilename, time)
      if pbResolveBitmap("Graphics/Battlebacks/#{trialName}") ||
         pbResolveBitmap("Graphics/Battlebacks/#{trialName}_bg")
        backdropFilename = trialName
      end
      trialName = sprintf("%s_%s", baseFilename, time)
      if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", trialName))
        baseFilename = trialName
      end
      trialName = sprintf("%s_%s", messageFilename, time)
      if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_message", trialName))
        messageFilename = trialName
      end
    end
    if !pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", baseFilename)) &&
       @battle.backdropBase
      baseFilename = @battle.backdropBase
      if time
        trialName = sprintf("%s_%s", baseFilename, time)
        if pbResolveBitmap(sprintf("Graphics/Battlebacks/%s_base0", trialName))
          baseFilename = trialName
        end
      end
    end
    # Finalise filenames
    battleBG   = pbBackdropBGPath(backdropFilename)
    playerBase = "Graphics/Battlebacks/" + baseFilename + "_base0"
    enemyBase  = "Graphics/Battlebacks/" + baseFilename + "_base1"
    messageBG  = "Graphics/Battlebacks/" + messageFilename + "_message"
    # Apply graphics
    bg = pbAddSprite("battle_bg", 0, 0, battleBG, @viewport)
    bg.z = 0
    disable_bg_slide = Settings.const_defined?(:DISABLE_SLIDING_BACKGROUND) &&
                       Settings::DISABLE_SLIDING_BACKGROUND
    if !disable_bg_slide
      bg = pbAddSprite("battle_bg2", -Graphics.width, 0, battleBG, @viewport)
      bg.z      = 0
      bg.mirror = true
    end
    2.times do |side|
      baseX, baseY = Battle::Scene.pbBattlerPosition(side)
      base = pbAddSprite("base_#{side}", baseX, baseY,
                         (side == 0) ? playerBase : enemyBase, @viewport)
      base.z = 1
      if base.bitmap
        base.ox = base.bitmap.width / 2
        base.oy = (side == 0) ? base.bitmap.height : base.bitmap.height / 2
      end
    end
    cmdBarBG = pbAddSprite("cmdBar_bg", 0, Graphics.height - 96, messageBG, @viewport)
    cmdBarBG.z = 180
  end
end

class Battle::Scene::Animation::WildIntroReveal < Battle::Scene::Animation
  def initialize(sprites, viewport, sideSize, battlers, battle)
    @sideSize = sideSize
    @battlers = battlers
    @battle   = battle
    super(sprites, viewport)
  end

  def createProcesses
    fadeTime = 8       # Tiempo para desvanecer la pantalla negra
    holdTime = VermeilWildIntroNDS::HOLD_TIME
    moveTime = VermeilWildIntroNDS::MOVE_TIME
    revealSpeed = VermeilWildIntroNDS::REVEAL_SPEED
    zoomMoveTime = [(moveTime / revealSpeed.to_f).round, 1].max
    totalTime = holdTime + moveTime
    
    centerX = Graphics.width / 2
    centerY = Graphics.height / 2
    
    zoomStart = 200
    zoomEnd = 100
    
    # Determinar el punto de enfoque (Cámara centrada en la base enemiga)
    focusX = centerX
    focusY = centerY
    if @sprites["base_1"]
      focusX = @sprites["base_1"].x
      focusY = @sprites["base_1"].y
    end

    # 0. Background
    if @sprites["battle_bg2"]
      @sprites["battle_bg2"].visible = false
    end

    if @sprites["battle_bg"]
      bg = @sprites["battle_bg"]
      bg.visible = false
      
      tempBG = Sprite.new(@viewport)
      tempBG.bitmap = bg.bitmap
      tempBG.x = centerX
      tempBG.y = centerY
      tempBG.ox = tempBG.bitmap.width / 2
      tempBG.oy = tempBG.bitmap.height / 2
      tempBG.z = 0
      tempBG.mirror = bg.mirror
      @tempSprites << tempBG
      
      # Calculamos dónde debe empezar el BG para que la cámara parezca estar en focusX
      bgStartX = centerX + (centerX - focusX) * (zoomStart / 100.0)
      bgStartY = centerY + (centerY - focusY) * (zoomStart / 100.0)
      # Clamp start position so scaled background always covers the screen
      if tempBG.bitmap
        w_scaled = tempBG.bitmap.width * (zoomStart / 100.0)
        h_scaled = tempBG.bitmap.height * (zoomStart / 100.0)
        minX = Graphics.width - (w_scaled / 2.0)
        maxX = w_scaled / 2.0
        minY = Graphics.height - (h_scaled / 2.0)
        maxY = h_scaled / 2.0
        bgStartX = [[bgStartX, minX].max, maxX].min
        bgStartY = [[bgStartY, minY].max, maxY].min
      end
      
      bgAnim = addSprite(tempBG, PictureOrigin::CENTER)
      bgAnim.setXY(0, bgStartX, bgStartY)
      bgAnim.moveXY(holdTime, zoomMoveTime, centerX, centerY)
      bgAnim.setZoom(0, zoomStart)
      bgAnim.moveZoom(holdTime, zoomMoveTime, zoomEnd)
      bgAnim.setCallback(totalTime, proc { bg.visible = true })
    end

    # 0.5 Intro visual + SE segun el tipo de encounter
    intro_cfg = VermeilWildIntroNDS.intro_config_for(@battle)
    tag = intro_cfg[:tag]
    intro_name = intro_cfg[:visual]
    if intro_name
      intro = addNewSprite(0, 0, intro_name)
      se = intro_cfg[:se]
      if se
        if se.is_a?(Array)
          intro.setSE(0, se[0], se[1], se[2])
        else
          intro.setSE(0, se)
        end
      end
      intro.setZ(0, 9000)
      intro.setOpacity(0, 255)
      # Parallax-like drift (similar to Bag panorama) + fade while moving down
      drift = intro_cfg[:drift]
      drift_dx = drift[0]
      drift_dy = drift[1]
      end_x_hold = drift_dx * holdTime
      end_x_final = end_x_hold + (drift_dx * moveTime * revealSpeed)
      end_y_final = drift_dy * moveTime * revealSpeed
      intro.setXY(0, 0, 0)
      # Lateral parallax only until reveal
      intro.moveXY(0, holdTime, end_x_hold, 0)
      # During reveal: continue lateral drift + move down while fading
      intro.moveXY(holdTime, moveTime, end_x_final, end_y_final)
      # Fade only after the Pokémon reveal starts (holdTime)
      intro.moveOpacity(holdTime, (moveTime / 2.0).ceil, 0)
    end

    # Bases
    ["base_0", "base_1"].each do |baseName|
      next if !@sprites[baseName]
      base = @sprites[baseName]
      base.visible = false
      
      tempBase = Sprite.new(@viewport)
      tempBase.bitmap = base.bitmap
      tempBase.ox = base.ox
      tempBase.oy = base.oy
      tempBase.z = base.z
      @tempSprites << tempBase
      
      endX = base.x
      endY = base.y
      # Calculamos posición inicial relativa al foco (base enemiga)
      startX = centerX + (endX - focusX) * (zoomStart / 100.0)
      startY = centerY + (endY - focusY) * (zoomStart / 100.0)
      
      origin = (baseName == "base_0") ? PictureOrigin::BOTTOM : PictureOrigin::CENTER
      
      baseAnim = addSprite(tempBase, origin)
      baseAnim.setXY(0, startX, startY)
      baseAnim.moveXY(holdTime, moveTime, endX, endY)
      baseAnim.setZoom(0, zoomStart)
      baseAnim.moveZoom(holdTime, zoomMoveTime, zoomEnd)
      baseAnim.setCallback(totalTime, proc { base.visible = true })
    end
    
    # 1. Pokémon: Ocultar originales y preparar copias con movimiento de cámara
    @sideSize.times do |i|
      idxBattler = (2 * i) + 1
      sprite = @sprites["pokemon_#{idxBattler}"]
      next if !sprite
      sprite.visible = false # Ocultamos el real para que no interfiera
      
      # Creamos el sprite de revelación
      temp = Sprite.new(@viewport)
      temp.bitmap = sprite.bitmap
      temp.mirror = sprite.mirror
      temp.x      = sprite.x
      temp.y      = sprite.y
      temp.ox     = sprite.ox
      temp.oy     = sprite.oy
      temp.z      = 1000 + i
      @tempSprites << temp

      endX = sprite.x
      endY = sprite.y
      startX = centerX + (endX - focusX) * (zoomStart / 100.0)
      startY = centerY + (endY - focusY) * (zoomStart / 100.0)

      battler = addSprite(temp, PictureOrigin::BOTTOM)
      battler.setXY(0, startX, startY)
      battler.moveXY(holdTime, zoomMoveTime, endX, endY)
      battler.setVisible(0, true)
      battler.setOpacity(0, 0)
      
      # ANIMACIÓN DE ZOOM (Cámara alejándose):
      battler.setZoom(0, zoomStart) 
      battler.moveOpacity(holdTime, 4, 255) # Aparece rápido tras el hold
      battler.moveZoom(holdTime, zoomMoveTime, zoomEnd) # Se aleja suavemente después del hold
      
      # Sincronizar el grito
      battler.setCallback(holdTime, proc { @battlers[idxBattler].pokemon.play_cry })

      # AL FINALIZAR: Es vital restaurar el sprite original
      battler.setCallback(totalTime, proc { |_p| 
        sprite.visible = true
        sprite.opacity = 255
        sprite.tone = Tone.new(0, 0, 0, 0) # Restaurar color normal (quitar silueta negra)
        # No destruimos el bitmap porque es el del original
      })
    end

    # 2. Pantalla Negra (Fade In inicial)
    blackScreen = addNewSprite(0, 0, "Graphics/Battle animations/black_screen")
    blackScreen.setZ(0, 9999)
    blackScreen.setOpacity(0, 255)
    blackScreen.moveOpacity(0, fadeTime, 0)

    # 3. Destello blanco (Flash) al aparecer el Pokémon (Opcional, para el "pop")
    whiteScreen = addNewSprite(0, 0, "Graphics/Battle animations/white_screen")
    whiteScreen.setZ(0, 1010)
    whiteScreen.setOpacity(0, 0)
    whiteScreen.moveOpacity(holdTime, 2, 160)
    whiteScreen.moveOpacity(holdTime + 2, 6, 0)
  end
end

class Battle::Scene
  alias_method :vermeil_pbBattleIntroAnimation, :pbBattleIntroAnimation unless method_defined?(:vermeil_pbBattleIntroAnimation)

  def pbBattleIntroAnimation
    return vermeil_pbBattleIntroAnimation if !VermeilWildIntroNDS.enabled?
    return vermeil_pbBattleIntroAnimation if !@battle.wildBattle? && !@battle.trainerBattle?

    if @battle.trainerBattle?
      # Ocultar PokÃ©mon enemigos y barras de vida para evitar spoilers
      @battle.sideSizes[1].times do |i|
        idxBattler = (2 * i) + 1
        @sprites["pokemon_#{idxBattler}"]&.visible = false
        @sprites["shadow_#{idxBattler}"]&.visible = false
        @sprites["dataBox_#{idxBattler}"]&.visible = false
      end
      # Ocultar entrenadores para revelarlos con la intro
      i = 1
      while @sprites["trainer_#{i}"]
        @sprites["trainer_#{i}"].visible = false
        i += 1
      end

      revealAnim = Animation::TrainerIntroReveal.new(@sprites, @viewport, @battle)
      @animations.push(revealAnim)

      wait_frames = VermeilWildIntroNDS.reveal_wait_frames
      wait_frames.times do
        pbUpdate
      end

      pbShowPartyLineup(0, true)
      pbShowPartyLineup(1, true)
      return
    end

    # --- PASO 1: Transición de cuadrados ---
    # Ocultamos enemigos para que no se vean "debajo" de los cuadrados
    @battle.sideSizes[1].times do |i|
      idx = (2 * i) + 1
      @sprites["pokemon_#{idx}"].visible = false if @sprites["pokemon_#{idx}"]
    end

    # introAnim = Animation::Intro.new(@sprites, @viewport, @battle)
    # loop do
    #   introAnim.update
    #   pbUpdate
    #   break if introAnim.animDone?
    # end
    # introAnim.dispose

    # --- PASO 2: Revelación NDS (El Zoom que pedías) ---
    revealAnim = Animation::WildIntroReveal.new(@sprites, @viewport, @battle.sideSizes[1], @battle.battlers, @battle)
    @animations.push(revealAnim)
    
    # Detectar velocidad del turbo para ajustar la espera
    speed = 1.0
    if defined?(TurboConfig) && defined?($GameSpeed)
      speed = TurboConfig::SPEED_STAGES[$GameSpeed] || 1.0
    elsif defined?(Input.time_scale)
      speed = Input.time_scale.to_f
    end

    # Base de 60 frames, ajustado agresivamente por el turbo (al cuadrado)
    # para eliminar la pausa estática en velocidades altas.
    # Mínimo 20 frames para asegurar que la animación de zoom termine (8+12).
    wait_frames = VermeilWildIntroNDS.reveal_wait_frames

    wait_frames.times do
      pbUpdate
    end

    # --- PASO 3: Aparecen las cajas de vida ---
    @battle.sideSizes[1].times do |i|
      idx = (2 * i) + 1
      next if !@battle.battlers[idx]
      @animations.push(Animation::DataBoxAppear.new(@sprites, @viewport, idx))
    end
    
    while inPartyAnimation?
      pbUpdate
    end

    # --- PASO 4: Animación Shiny ---
    if @battle.showAnims
      @battle.sideSizes[1].times do |i|
        idxBattler = (2 * i) + 1
        battler = @battle.battlers[idxBattler]
        next if !battler || !battler.shiny?
        pbCommonAnimation(battler.super_shiny? ? "SuperShiny" : "Shiny", battler)
      end
    end
  end
end





