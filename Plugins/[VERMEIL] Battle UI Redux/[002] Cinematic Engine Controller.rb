#===============================================================================
# [VERMEIL] Cinematic Engine & Overlay Controller (v8.1 STABLE + TYPO FIX)
# THE PERFECT CUT - UNIVERSAL HIDE, FADE DATABOXES, NO GHOST TEXT, NO DELAYS
#===============================================================================

module VermeilCinematicEngine
  def self.get_base_priority(battler_index, is_foe)
    pos_idx = battler_index % 3
    base_priority = if is_foe
      pos_idx == 0 ? 1 : (pos_idx == 1 ? 2 : 3)
    else
      pos_idx == 2 ? 1 : (pos_idx == 1 ? 2 : 3)
    end
    return is_foe ? (base_priority + 10) : base_priority
  end

  def self.get_animation_priority(user)
    return 5 if !user || !user.respond_to?(:index)
    idx = user.index
    is_foe = idx >= 3
    return get_base_priority(idx, is_foe)
  end

  def self.uses_z_write?(anim_class)
    return false if !anim_class || !anim_class.is_a?(Class)
    return anim_class.const_defined?(:Z_WRITE) && anim_class::Z_WRITE
  end

  def self.get_anim_class(move_id)
    mid = move_id.respond_to?(:to_sym) ? move_id.to_sym : move_id
    
    Battle::Scene::Animation.constants.each do |c|
      next unless c.to_s.start_with?("Vermeil")
      klass = Battle::Scene::Animation.const_get(c)
      if klass.is_a?(Class) && klass.const_defined?(:HANDLED_MOVES)
        return klass if klass::HANDLED_MOVES.include?(mid)
      end
    end
    
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
    return anim_class::BEHAVIOR if anim_class.const_defined?(:BEHAVIOR)
    
    name = anim_class.name.split("::").last
    map = {
      "VermeilMultiHitPunches" => :multihit,
      "VermeilToxicSpikesCast" => :hazard,
      "VermeilSpikesCast"      => :hazard,
      "VermeilStealthRockCast" => :hazard,
      "VermeilStickyWebCast"   => :hazard,
      "VermeilSelfTargetGrass" => :self_targeting,
      "VermeilGrassStatus"     => :self_targeting
    }
    if anim_class.const_defined?(:Z_WRITE) && anim_class::Z_WRITE
      return :zwrite
    end
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

  def vermeil_slide_databoxes_out
    return if !@sprites
    vermeil_engine_clear_message_window!
    
    if respond_to?(:pbHideInfoUI)
      pbHideInfoUI
    elsif respond_to?(:pbToggleDataboxes)
      pbToggleDataboxes
    end
    
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
    is_haz = (behavior == :hazard)
    is_self = (behavior == :self_targeting)

    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    target = user if target.nil? || is_self

    return false if !user || !target

    anim_user = user; side_index = 0; ax = 0; ay = 0

    if is_haz
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

  def vermeil_get_battler_priority(battler)
    return 2 if !battler || !battler.respond_to?(:index)
    idx = battler.index
    is_foe = idx >= 3
    pos = is_foe ? (idx - 3) : idx  
    base_priority = if is_foe
      pos == 0 ? 1 : (pos == 1 ? 2 : 3)
    else
      pos == 2 ? 1 : (pos == 1 ? 2 : 3)
    end
    return is_foe ? (base_priority + 10) : base_priority
  end

  def vermeil_get_animation_priority(user)
    VermeilCinematicEngine.get_animation_priority(user)
  end
end

module VermeilCinematicEngineBattleOverride
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    anim_class = VermeilCinematicEngine.get_anim_class(mid)
    behavior = anim_class ? VermeilCinematicEngine.get_behavior(anim_class) : :none
    
    @scene.vermeil_engine_clear_message_window!
    
    if behavior == :multihit
      @scene.vermeil_slide_databoxes_out if hitNum.to_i <= 0
    else
      @scene.vermeil_slide_databoxes_out
    end
    
    if @showAnims && anim_class && @scene.respond_to?(:pbPlayVermeilCinematic)
      
      if behavior == :multihit
        @scene.vermeil_start_sequence if hitNum.to_i <= 0
      elsif behavior == :hazard || behavior == :self_targeting
        @scene.vermeil_start_sequence
      end
      
      # CORRECCIÓN DE TYPO AQUÍ: Usamos hitNum en vez de hit_num
      played = @scene.pbPlayVermeilCinematic(anim_class, user, targets, mid, hitNum, behavior)
      if played
        @vermeil_just_finished_anim = true
        @vermeil_in_sequence = true if behavior == :multihit || behavior == :hazard || behavior == :self_targeting
        
        @scene.vermeil_slide_databoxes_in
        return
      end
    end

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

  def pbCommonAnimation(animName, user = nil, targets = nil)
    # Para animaciones personalizadas, el flag debe estar setiado ANTES de que se muestre el mensaje
    custom_anims = ["StatUp", "StatDown", "HealthUp", "HealthDown", "SnapTrap", "SpikyShield", "LeechSeed"]
    is_custom = custom_anims.include?(animName)
    
    if is_custom
      # Para animaciones personalizadas, llamar directamente al método del Scene
      # Esto asegura que se use la animación personalizada de [036]
      @scene.pbCommonAnimation(animName, user, targets)
      # El flag ya se establece en el método del Scene
      @vermeil_just_finished_anim = true
      
      if @scene.respond_to?(:vermeil_slide_databoxes_in)
        @scene.vermeil_slide_databoxes_in
      end
      if @scene.respond_to?(:vermeil_force_instant_box)
        @scene.vermeil_force_instant_box
      end
      return
    end
    
    @scene.vermeil_engine_clear_message_window! if !is_custom
    super(animName, user, targets)
    
    # El flag se establece DESPUÉS de que la animación termina
    # Esto permite que el delay se evite cuando se muestra el siguiente mensaje
    @vermeil_just_finished_anim = true
    
    if @scene.respond_to?(:vermeil_slide_databoxes_in)
      @scene.vermeil_slide_databoxes_in
    end
    if @scene.respond_to?(:vermeil_force_instant_box)
      @scene.vermeil_force_instant_box
    end
  end

  def pbWait(frames, *args)
    # Saltar espera si hay una animación terminada o si el flag no está inicializado (inicio de batalla)
    begin
      should_skip = false
      if !instance_variable_defined?(:@vermeil_just_finished_anim)
        should_skip = true
      elsif @vermeil_just_finished_anim.nil?
        should_skip = true
      elsif @vermeil_just_finished_anim
        should_skip = true
      end
      
      if should_skip
        # No restablecer el flag aquí, hacerlo en pbWaitMessage
        return
      end
    rescue
      return
    end
    super
  end
end

module VermeilCinematicEngineSceneOverride
  def pbWaitMessage
    battle_obj = nil
    if defined?(@battle) && @battle && @battle.is_a?(Battle)
      battle_obj = @battle
    end
    
    in_sequence = false
    if battle_obj && battle_obj.instance_variable_defined?(:@vermeil_in_sequence)
      in_sequence = battle_obj.instance_variable_get(:@vermeil_in_sequence)
    end
    
    # Comprobar si hay una animación terminada
    just_finished = false
    if battle_obj
      begin
        if !battle_obj.instance_variable_defined?(:@vermeil_just_finished_anim)
          # Flag no existe - tratar como si hubiera animación reciente
          just_finished = true
        else
          just_finished = battle_obj.instance_variable_get(:@vermeil_just_finished_anim) rescue false
        end
      rescue
        just_finished = false
      end
    end
    
    if just_finished || in_sequence
      # Restaurar el flag
      if just_finished && battle_obj
        battle_obj.instance_variable_set(:@vermeil_just_finished_anim, false)
      end
      # Forzar visibilidad del message window
      if @sprites && @sprites["messageWindow"]
        @sprites["messageWindow"].visible = true
      end
      # No llamar a super - evitar el delay de 1 segundo
      return
    end
    
    # Solo llamar a super si no hay animación reciente
    super
  end

  def pbDisplayBrief(msg)
    return if @vermeil_sequence_active
    super(msg)
  end

  def pbDisplayMessage(msg, brief = false)
    if @vermeil_sequence_active && msg.to_s.downcase.include?("used")
      vermeil_engine_clear_message_window!
      return
    end

    if @vermeil_sequence_active || @vermeil_skip_slide_in || @vermeil_is_eor
      vermeil_force_instant_box
      @vermeil_skip_slide_in = false
    end
    
    # Si hubo una animación reciente, saltar el delay del mensaje
    begin
      if @vermeil_just_finished_anim
        @vermeil_just_finished_anim = false
        # Forzar que el mensaje se muestre inmediatamente sin esperar
        cw = @sprites["messageWindow"]
        if cw
          cw.visible = true
        end
      end
    rescue
      # Ignorar errores
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