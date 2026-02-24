#===============================================================================
# [VERMEIL] Cinematic Engine & Overlay Controller
# THE PERFECT CUT - UNIVERSAL HIDE, FADE DATABOXES, NO GHOST TEXT, NO DELAYS
#===============================================================================

module VermeilCinematicEngine
  def self.get_anim_class(move_id)
    # Convertimos a símbolo por seguridad
    mid = move_id.respond_to?(:to_sym) ? move_id.to_sym : move_id
    
    # 1. DICCIONARIO MAESTRO (100% a prueba de fallos)
    map = {
      :SURGINGSTRIKES => "VermeilMultiHitPunches",
      :DOUBLEHIT      => "VermeilMultiHitPunches",
      :FLURRYPUNCH    => "VermeilMultiHitPunches",
      :COMETPUNCH     => "VermeilMultiHitPunches",
      
      :MACHPUNCH      => "VermeilPriorityPunches",
      :BULLETPUNCH    => "VermeilPriorityPunches",
      :JETPUNCH       => "VermeilPriorityPunches",

      :HAMMERARM      => "VermeilHeavyPunches",
      :ICEHAMMER      => "VermeilHeavyPunches",
      :CRABHAMMER     => "VermeilHeavyPunches",
      :DYNAMICPUNCH   => "VermeilHeavyPunches",
      :MEGAPUNCH      => "VermeilHeavyPunches",

      # ---> PUÑOS ESPECTRALES / OSCUROS <---
      :SHADOWPUNCH    => "VermeilEtherealPunches",
      :RAGEFIST       => "VermeilEtherealPunches",
      :WICKEDBLOW     => "VermeilEtherealPunches",
      :SUCKERPUNCH    => "VermeilEtherealPunches",

      :SNIPESHOT      => "VermeilCinematicSnipeShot",
      :EMBER          => "VermeilCinematicEmber",
      :VINEWHIP       => "VermeilCinematicVineWhip",
      :WATERGUN       => "VermeilCinematicWaterGun",
      :STALKCUTTER    => "VermeilCinematicStalkCutter",
      :BULBBASH       => "VermeilCinematicBulbBash",
      :SUPERSONIC     => "VermeilCinematicSupersonic",
      :VOLTTACKLE     => "VermeilCinematicVoltTackle",

      :TOXICSPIKES    => "VermeilToxicSpikesCast",
      :SPIKES         => "VermeilSpikesCast",
      :STEALTHROCK    => "VermeilStealthRockCast",
      :STICKYWEB      => "VermeilStickyWebCast"
    }
    
    # 2. AUTO-DETECCIÓN INTELIGENTE
    # Si creas una clase llamada "Vermeil_NOMBREDELMOVE" la detectará automáticamente
    direct_name = "Vermeil_#{mid}"
    if Battle::Scene::Animation.const_defined?(direct_name)
      return Battle::Scene::Animation.const_get(direct_name)
    end
    
    cname = map[mid]
    return nil if !cname
    
    if Battle::Scene::Animation.const_defined?(cname)
      return Battle::Scene::Animation.const_get(cname)
    end
    return nil 
  end

  def self.get_behavior(anim_class)
    return :cinematic if !anim_class
    name = anim_class.name.split("::").last
    map = {
      "VermeilMultiHitPunches" => :multihit,
      "VermeilToxicSpikesCast" => :hazard,
      "VermeilSpikesCast"      => :hazard,
      "VermeilStealthRockCast" => :hazard,
      "VermeilStickyWebCast"   => :hazard
    }
    return map[name] || :cinematic
  end
end

class Battle::Scene
  def vermeil_start_sequence
    @vermeil_sequence_active = true
    vermeil_engine_set_message_skin(true)
    vermeil_engine_clear_message_window!
  end

  def vermeil_end_sequence
    @vermeil_sequence_active = false
    vermeil_engine_set_message_skin(false)
  end

  def vermeil_engine_set_message_skin(use_transparent)
    if respond_to?(:vermeil_redux_set_message_box_skin)
      vermeil_redux_set_message_box_skin(use_transparent)
    else
      return if !@sprites || !@sprites["messageBox"]
      asset = use_transparent ? "Graphics/UI/Battle/transparent_message" : "Graphics/UI/Battle/overlay_message"
      @sprites["messageBox"].setBitmap(asset) if pbResolveBitmap(asset) rescue nil
    end
  end

  # =========================================================================
  # BARRIDO MAESTRO: Limpia textos para evitar parpadeos post-animación
  # =========================================================================
  def vermeil_engine_clear_message_window!
    return if !@sprites
    msg_win = @sprites["messageWindow"]
    if msg_win && msg_win.respond_to?(:text=)
      msg_win.text = "" 
    end
    msg_box = @sprites["messageBox"]
    if msg_box && msg_box.respond_to?(:opacity=)
      msg_box.opacity = 0
      msg_box.visible = false if msg_box.respond_to?(:visible=)
    end
  end

  # =========================================================================
  # DESVANECIMIENTO FLUIDO DE DATABOXES (Para TODOS los movimientos)
  # =========================================================================
  def vermeil_slide_databoxes_out
    return if !@sprites
    vermeil_engine_clear_message_window!
    
    if respond_to?(:pbHideInfoUI)
      pbHideInfoUI
    elsif respond_to?(:pbToggleDataboxes)
      pbToggleDataboxes
    end
    
    # Efecto Fade Out forzado a las databoxes para asegurar que se oculten
    8.times do
      @sprites.each do |k, v|
        if k.to_s.start_with?("dataBox_") && v.respond_to?(:opacity)
          v.opacity -= 32
        end
      end
      pbUpdate
    end
    
    @sprites.each do |k, v|
      if k.to_s.start_with?("dataBox_") && v.respond_to?(:visible=)
        v.visible = false
      end
    end
  end

  def vermeil_slide_databoxes_in
    return if !@sprites
    if respond_to?(:pbShowInfoUI)
      pbShowInfoUI
    elsif respond_to?(:pbToggleDataboxes)
      pbToggleDataboxes(true)
    end
    
    @sprites.each do |k, v|
      if k.to_s.start_with?("dataBox_") && v.respond_to?(:visible=)
        v.visible = true
      end
    end
    
    # Efecto Fade In forzado
    8.times do
      @sprites.each do |k, v|
        if k.to_s.start_with?("dataBox_") && v.respond_to?(:opacity)
          v.opacity += 32
        end
      end
      pbUpdate
    end
  end

  def vermeil_force_instant_box
    if @sprites && @sprites["messageBox"] && @sprites["messageWindow"]
      @sprites["messageBox"].x = 0
      @sprites["messageWindow"].x = 16
    end
  end

  def vermeil_hazard_anchor_for_side(side_index)
    if defined?(HazardSettings)
      return [HazardSettings::PLAYER_SIDE_HAZARD_X, HazardSettings::PLAYER_SIDE_HAZARD_Y] if side_index == 0
      return [HazardSettings::FOE_SIDE_HAZARD_X, HazardSettings::FOE_SIDE_HAZARD_Y]
    end
    return [(Graphics.width * 0.30).round, (Graphics.height * 0.72).round] if side_index == 0
    return [(Graphics.width * 0.70).round, (Graphics.height * 0.44).round]
  end

  def pbPlayVermeilCinematic(anim_class, user, targets, mid, hit_num, behavior)
    is_mh  = (behavior == :multihit)
    is_cin = (behavior == :cinematic)
    is_haz = (behavior == :hazard)

    if is_cin
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || !target
    end

    target = nil; anim_user = user; side_index = 0; ax = 0; ay = 0

    if is_haz
      return false if !user
      if !anim_user || anim_user.fainted? || anim_user.hp <= 0
        if targets.respond_to?(:each)
          targets.each do |t|
            next if !t || t.fainted? || t.hp <= 0
            anim_user = t.pbDirectOpposing if t.respond_to?(:pbDirectOpposing)
            break if anim_user && !anim_user.fainted? && anim_user.hp > 0
          end
        elsif targets && targets.respond_to?(:pbDirectOpposing)
          anim_user = targets.pbDirectOpposing
        end
        anim_user = user if !anim_user
      end
      side_index = anim_user.respond_to?(:idxOwnSide) ? (anim_user.idxOwnSide ^ 1) : ((anim_user.index & 1) ^ 1)
      ax, ay = vermeil_hazard_anchor_for_side(side_index)
    else
      target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
      return false if !user || !target
    end

    @vermeil_anim_is_playing = true
    
    begin
      pbHazardsSuspend(:vermeil_hazard_cast) if is_haz && respond_to?(:pbHazardsSuspend)

      if is_haz
        anim = anim_class.new(@sprites, @viewport, anim_user, ax, ay, side_index)
      elsif is_mh
        anim = anim_class.new(@sprites, @viewport, user, target, mid, hit_num)
      elsif anim_class.instance_method(:initialize).arity.abs == 4
        anim = anim_class.new(@sprites, @viewport, user, target)
      else
        anim = anim_class.new(@sprites, @viewport, user, target, mid)
      end

      loop do 
        anim.update; pbUpdate; break if anim.animDone? 
      end
      anim.dispose

    ensure
      pbHazardsResume(:vermeil_hazard_cast, false) if is_haz && respond_to?(:pbHazardsResume)
      us = @sprites["pokemon_#{user.index}"] rescue nil
      ts = @sprites["pokemon_#{target.index}"] rescue nil if target
      us.visible = true if us; ts.visible = true if ts && target
      
      @vermeil_anim_is_playing = false
      @vermeil_skip_slide_in = true 

      vermeil_end_sequence if @vermeil_sequence_active
    end
    return true
  end
end

#===============================================================================
# BATTLE OVERRIDE - ANIQUILADOR DE DELAYS Y ENRUTADOR DE ANIMACIONES
#===============================================================================
module VermeilCinematicEngineBattleOverride
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    anim_class = VermeilCinematicEngine.get_anim_class(mid)
    behavior = anim_class ? VermeilCinematicEngine.get_behavior(anim_class) : :none
    
    # 1. Limpiar textos fantasma y Ocultar Databoxes para TODOS los movimientos
    @scene.vermeil_engine_clear_message_window!
    if behavior != :multihit || hitNum.to_i <= 0
      @scene.vermeil_slide_databoxes_out
    end
    
    # 2. Reproducir animación Custom (Ofensivos / Hazards)
    if @showAnims && anim_class && @scene.respond_to?(:pbPlayVermeilCinematic)
      if behavior == :multihit
        @scene.vermeil_start_sequence if hitNum.to_i <= 0
      end
      
      played = @scene.pbPlayVermeilCinematic(anim_class, user, targets, mid, hitNum, behavior)
      if played
        # Flag para aniquilar el molesto pbWait de Essentials que causa 2 seg de delay
        @vermeil_just_finished_anim = true
        
        # Mostrar databoxes si no es un multihit en medio de su secuencia
        if behavior != :multihit
          @scene.vermeil_slide_databoxes_in
        end
        return
      end
    end

    # 3. Reproducir animación Vainilla
    if @showAnims && @scene
      @scene.instance_variable_set(:@vermeil_anim_is_playing, true)
      super(move, user, targets, hitNum)
      @scene.instance_variable_set(:@vermeil_anim_is_playing, false)
      @scene.instance_variable_set(:@vermeil_skip_slide_in, true) if @scene.respond_to?(:vermeil_skip_slide_in)
      
      @vermeil_just_finished_anim = true
      @scene.vermeil_slide_databoxes_in
      return
    end
    
    super(move, user, targets, hitNum)
    @vermeil_just_finished_anim = true
    @scene.vermeil_slide_databoxes_in
  end

  #=============================================================================
  # ANIMACIONES COMUNES (Habilidades como Intimidate o Toxic Debris)
  #=============================================================================
  def pbCommonAnimation(animName, user = nil, targets = nil)
    @scene.vermeil_engine_clear_message_window!
    super(animName, user, targets)
    
    # Flag para aniquilar el delay de 1 segundo post-habilidad
    @vermeil_just_finished_anim = true
  end

  #=============================================================================
  # EL ANIQUILADOR DE DELAYS
  # Intercepta el tiempo muerto de Essentials justo después de las animaciones
  #=============================================================================
  def pbWait(frames, *args)
    if @vermeil_just_finished_anim
      @vermeil_just_finished_anim = false
      return # Salta la pausa y empalma directo al texto
    end
    super
  end
end

#===============================================================================
# MATRIZ INTELIGENTE DE VISIBILIDAD
#===============================================================================
module VermeilCinematicEngineSceneOverride
  def pbDisplayBrief(msg)
    return if @vermeil_sequence_active
    super(msg)
  end

  def pbDisplayMessage(msg, brief = false)
    if @vermeil_sequence_active && msg.to_s.downcase.include?("used")
      vermeil_engine_clear_message_window!
      return
    end

    # Saltar retraso de slide-in nativo
    if @vermeil_sequence_active || @vermeil_skip_slide_in || @vermeil_is_eor
      vermeil_force_instant_box
      @vermeil_skip_slide_in = false
    end

    super(msg, brief)
  end

  def pbUpdate(*args)
    super(*args) 

    msg_win = @sprites["messageWindow"] rescue nil
    msg_box = @sprites["messageBox"] rescue nil

    if msg_win && msg_box
      msg_win.opacity = 0 if msg_win.respond_to?(:opacity=)
      msg_win.back_opacity = 0 if msg_win.respond_to?(:back_opacity=)
      
      text_empty = (!msg_win.respond_to?(:text) || msg_win.text.nil? || msg_win.text == "")
      
      should_hide = text_empty

      if should_hide
        msg_box.visible = false if msg_box.respond_to?(:visible=)
        msg_box.opacity = 0 if msg_box.respond_to?(:opacity=)
      else
        msg_box.visible = true if msg_box.respond_to?(:visible=)
        msg_box.opacity = 255 if msg_box.respond_to?(:opacity=)
      end
    end
  end
end

Battle.prepend(VermeilCinematicEngineBattleOverride)
Battle::Scene.prepend(VermeilCinematicEngineSceneOverride)