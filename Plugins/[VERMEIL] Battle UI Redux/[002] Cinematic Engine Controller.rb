#===============================================================================
# [VERMEIL] Cinematic Engine & Overlay Controller
# MOTOR UNIVERSAL: Cubre todos los movimientos (Custom y por Defecto de Essentials).
#===============================================================================

module VermeilCinematicEngine
  # 1. DICCIONARIO PARA ANIMACIONES CUSTOM EN RUBY (Hechas a mano)
  ANIMATIONS = {
    :SURGINGSTRIKES => Battle::Scene::Animation::VermeilMultiHitPunches,
    :DOUBLEHIT      => Battle::Scene::Animation::VermeilMultiHitPunches,
    :FLURRYPUNCH    => Battle::Scene::Animation::VermeilMultiHitPunches,
    :COMETPUNCH     => Battle::Scene::Animation::VermeilMultiHitPunches,
    
    :MACHPUNCH      => Battle::Scene::Animation::VermeilPriorityPunches,
    :BULLETPUNCH    => Battle::Scene::Animation::VermeilPriorityPunches,
    :JETPUNCH       => Battle::Scene::Animation::VermeilPriorityPunches,

    :HAMMERARM      => Battle::Scene::Animation::VermeilHeavyPunches,
    :ICEHAMMER      => Battle::Scene::Animation::VermeilHeavyPunches,
    :CRABHAMMER     => Battle::Scene::Animation::VermeilHeavyPunches,
    :DYNAMICPUNCH   => Battle::Scene::Animation::VermeilHeavyPunches,
    :MEGAPUNCH      => Battle::Scene::Animation::VermeilHeavyPunches,

    :SNIPESHOT      => Battle::Scene::Animation::VermeilCinematicSnipeShot,
    :EMBER          => Battle::Scene::Animation::VermeilCinematicEmber,
    :VINEWHIP       => Battle::Scene::Animation::VermeilCinematicVineWhip,
    :WATERGUN       => Battle::Scene::Animation::VermeilCinematicWaterGun,
    :STALKCUTTER    => Battle::Scene::Animation::VermeilCinematicStalkCutter,
    :BULBBASH       => Battle::Scene::Animation::VermeilCinematicBulbBash,
    :SUPERSONIC     => Battle::Scene::Animation::VermeilCinematicSupersonic,
    :VOLTTACKLE     => Battle::Scene::Animation::VermeilCinematicVoltTackle,

    :TOXICSPIKES    => Battle::Scene::Animation::VermeilToxicSpikesCast,
    :SPIKES         => Battle::Scene::Animation::VermeilSpikesCast,
    :STEALTHROCK    => Battle::Scene::Animation::VermeilStealthRockCast
  }

  # 2. DICCIONARIO DE COMPORTAMIENTOS PARA LAS CUSTOM
  BEHAVIORS = {
    Battle::Scene::Animation::VermeilMultiHitPunches    => :multihit,
    Battle::Scene::Animation::VermeilToxicSpikesCast    => :hazard,
    Battle::Scene::Animation::VermeilSpikesCast         => :hazard,
    Battle::Scene::Animation::VermeilStealthRockCast    => :hazard
  }

  def self.get_anim_class(move_id)
    return ANIMATIONS[move_id]
  end

  def self.get_behavior(anim_class)
    return BEHAVIORS[anim_class] || :cinematic
  end
end

#===============================================================================
# MÉTODOS DE LA ESCENA (CONTROL DE UI)
#===============================================================================
class Battle::Scene
  def vermeil_start_sequence
    @vermeil_sequence_active = true
    vermeil_engine_set_message_skin(true)
    vermeil_engine_clear_message_window!
  end

  def vermeil_update_sequence_timer
    @vermeil_msg_filter_until = System.uptime + 0.80
  end

  def vermeil_end_sequence
    @vermeil_sequence_active = false
    vermeil_engine_set_message_skin(false)
    pbRefresh if respond_to?(:pbRefresh)
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
    msg_box = @sprites["messageBox"]
    if msg_win; msg_win.text = "" if msg_win.respond_to?(:text=); msg_win.visible = false if msg_win.respond_to?(:visible=); end
    if msg_box; msg_box.visible = false if msg_box.respond_to?(:visible=); end
  end

  def vermeil_engine_show_message_window!
    return if !@sprites
    msg_win = @sprites["messageWindow"]
    msg_box = @sprites["messageBox"]
    if msg_box; msg_box.visible = true if msg_box.respond_to?(:visible=); msg_box.opacity = 255 if msg_box.respond_to?(:opacity=); end
    if msg_win; msg_win.visible = true if msg_win.respond_to?(:visible=); msg_win.contents_opacity = 255 if msg_win.respond_to?(:contents_opacity=); end
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
    
    if is_mh && @vermeil_sequence_active
      vermeil_engine_set_message_skin(true)
      vermeil_engine_clear_message_window!
    elsif is_cin || is_haz
      vermeil_engine_clear_message_window! 
    end
    
    pbToggleDataboxes if !is_mh || !@vermeil_sequence_active
    
    begin
      pbHazardsSuspend(:vermeil_hazard_cast) if is_haz && respond_to?(:pbHazardsSuspend)

      if is_haz
        anim = anim_class.new(@sprites, @viewport, anim_user, ax, ay, side_index)
      elsif anim_class == Battle::Scene::Animation::VermeilMultiHitPunches
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
      if !is_mh || !@vermeil_sequence_active
        vermeil_engine_set_message_skin(false)
        pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes)
        pbRefresh if respond_to?(:pbRefresh)
      end
    end
    return true
  end
end

#===============================================================================
# ENRUTADOR GLOBAL UNIVERSAL (PREPEND)
#===============================================================================
module VermeilCinematicEngineBattleOverride
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    anim_class = VermeilCinematicEngine.get_anim_class(mid)

    # 1. SI ES UNA ANIMACIÓN CUSTOMIZADA EN RUBY (Las que hemos estado haciendo)
    if @showAnims && anim_class && @scene.respond_to?(:pbPlayVermeilCinematic)
      behavior = VermeilCinematicEngine.get_behavior(anim_class)
      
      if behavior == :multihit
        @scene.vermeil_start_sequence if hitNum.to_i <= 0
        @scene.vermeil_update_sequence_timer
      end
      
      played = @scene.pbPlayVermeilCinematic(anim_class, user, targets, mid, hitNum, behavior)
      return if played
    end

    # 2. SISTEMA UNIVERSAL PARA TODOS LOS MOVIMIENTOS EXISTENTES E INVENTADOS (Vanilla y Editor)
    if @showAnims && @scene
      behavior = :cinematic
      move_data = GameData::Move.try_get(mid)
      
      if move_data
        func = move_data.function_code
        # Códigos de Multigolpe nativos de Essentials
        if ["02D", "02E", "02F", "030", "031", "032", "0B0"].include?(func) || hitNum > 0
          behavior = :multihit
        # Códigos de Trampas nativas de Essentials
        elsif ["04A", "04B", "04C", "101", "169"].include?(func)
          behavior = :hazard
        end
      end

      is_mh  = (behavior == :multihit)
      is_haz = (behavior == :hazard)

      if is_mh
        @scene.vermeil_start_sequence if hitNum.to_i <= 0
        @scene.vermeil_update_sequence_timer
      end

      @scene.instance_variable_set(:@vermeil_anim_is_playing, true)

      if is_mh && @scene.instance_variable_get(:@vermeil_sequence_active)
        @scene.vermeil_engine_set_message_skin(true)
        @scene.vermeil_engine_clear_message_window!
      else
        @scene.vermeil_engine_clear_message_window!
      end
      
      # Ocultar UI e inmersión
      @scene.pbToggleDataboxes if !is_mh || !@scene.instance_variable_get(:@vermeil_sequence_active)
      @scene.pbHazardsSuspend(:vermeil_hazard_cast) if is_haz && @scene.respond_to?(:pbHazardsSuspend)

      # --- REPRODUCIR LA ANIMACIÓN POR DEFECTO ---
      super(move, user, targets, hitNum)

      # Restaurar el estado del campo
      @scene.instance_variable_set(:@vermeil_anim_is_playing, false)
      @scene.pbHazardsResume(:vermeil_hazard_cast, false) if is_haz && @scene.respond_to?(:pbHazardsResume)
      
      if !is_mh || !@scene.instance_variable_get(:@vermeil_sequence_active)
        @scene.vermeil_engine_set_message_skin(false)
        @scene.pbToggleDataboxes(true) if @scene.respond_to?(:pbToggleDataboxes)
        @scene.pbRefresh if @scene.respond_to?(:pbRefresh)
      end

      return
    end
    
    super(move, user, targets, hitNum)
  end
end

module VermeilCinematicEngineSceneOverride
  def pbDisplayMessage(msg, brief = false)
    if @vermeil_sequence_active
      text = msg.to_s.downcase
      if text.include?("used")
        vermeil_engine_clear_message_window!
        return
      end
      if text.include?("critical")
        vermeil_engine_set_message_skin(true)
        vermeil_engine_show_message_window!
        pbRefresh
        super(msg, brief) 
        vermeil_engine_clear_message_window!
        return
      end
      if text.include?("super effective") || text.include?("not very effective") || text.include?("had no effect") || (text.include?(" hit ") && (text.include?(" time") || text.include?(" times!")))
        vermeil_end_sequence
        vermeil_engine_show_message_window!
        pbRefresh
        super(msg, brief)
        return
      end
      if @vermeil_msg_filter_until && System.uptime < @vermeil_msg_filter_until
        vermeil_engine_clear_message_window!
        return
      end
    end
    
    if @vermeil_anim_is_playing && !@vermeil_sequence_active
      return 
    end

    super(msg, brief)
  end

  def pbUpdate(*args)
    super(*args) 
    if @vermeil_sequence_active && !@vermeil_anim_is_playing
      deadline = (@vermeil_msg_filter_until || 0) + 0.45
      if System.uptime > deadline
        vermeil_end_sequence
        vermeil_engine_clear_message_window!
      end
    end
  end
end

Battle.prepend(VermeilCinematicEngineBattleOverride)
Battle::Scene.prepend(VermeilCinematicEngineSceneOverride)