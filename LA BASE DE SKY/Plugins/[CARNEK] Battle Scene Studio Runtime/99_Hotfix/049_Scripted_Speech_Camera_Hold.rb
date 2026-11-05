# frozen_string_literal: true
# BSS and DBK may display cinematic dialogue during command/move phases.
# Their message loops repeatedly call Scene#pbUpdate, so the camera director
# must not orbit or re-anchor visible trainer sprites until the speech ends.
module BSSScriptedDialogueCameraHold
  def execute_trigger(*args, &block)
    scene=(@battle.scene rescue nil)
    if scene
      depth=scene.instance_variable_get(:@vermeil_cinema_script_depth).to_i
      # Acquire just once for the entire nested scripted dialogue/choice chain.
      if depth==0 && scene.instance_variable_get(:@vector)
        vector=scene.instance_variable_get(:@vector)
        scene.instance_variable_set(:@vermeil_cinema_script_camera_hold,vector.get.clone)
      end
      scene.instance_variable_set(:@vermeil_cinema_script_depth,depth+1)
    end
    super
  ensure
    if scene
      depth=scene.instance_variable_get(:@vermeil_cinema_script_depth).to_i
      depth=[depth-1,0].max
      scene.instance_variable_set(:@vermeil_cinema_script_depth,depth)
      scene.instance_variable_set(:@vermeil_cinema_script_camera_hold,nil) if depth==0
    end
  end
end

module BSSDBKSpeechCameraHold
  # Animated Trainer Intros and authored sprite metrics retain their native
  # coordinates. Do not restore a hard-coded pbTrainerPosition at intro exit.
  def pbProcessText(*args, &block)
    depth=@vermeil_cinema_script_depth.to_i
    if depth==0 && @vector
      @vermeil_cinema_script_camera_hold=@vector.get.clone
    end
    @vermeil_cinema_script_depth=depth+1
    super
  ensure
    @vermeil_cinema_script_depth=[@vermeil_cinema_script_depth.to_i-1,0].max
    @vermeil_cinema_script_camera_hold=nil if @vermeil_cinema_script_depth==0
  end

  def pbAnimateTrainerIntros(*args, &block)
    @vermeil_cinema_trainer_intro_depth=@vermeil_cinema_trainer_intro_depth.to_i+1
    super
  ensure
    @vermeil_cinema_trainer_intro_depth=[@vermeil_cinema_trainer_intro_depth.to_i-1,0].max
  end
end

if defined?(BSSDialogueEngine) && !BSSDialogueEngine.ancestors.include?(BSSScriptedDialogueCameraHold)
  BSSDialogueEngine.prepend(BSSScriptedDialogueCameraHold)
end
if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSDBKSpeechCameraHold)
  Battle::Scene.prepend(BSSDBKSpeechCameraHold)
end

# Scripted BSS speech may toggle Pokemon visibility via DBK speaker/blackbar
# transitions. Restore ONLY actual active Pokemon previously revealed natively.
# No actor moves or camera writes: BAS, sendouts and faint animations retain
# their own sprite authority.
module BSSScriptedActiveBattlerVisibility
  def bss_scripted_visible_scene?
    @battle && @sprites.is_a?(Hash) &&
      respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
  rescue StandardError
    false
  end

  def bss_scripted_remember_visible(completed_sendout=false, sent_indices=nil)
    return unless bss_scripted_visible_scene?
    @bss_scripted_revealed ||= {}
    @battle.battlers.each do |b|
      next unless b && !(b.fainted? rescue true)
      idx=b.index
      next if sent_indices && !sent_indices.include?(idx)
      mon=(b.pokemon rescue nil)
      sp=@sprites["pokemon_#{idx}"]
      next unless mon && sp && !(sp.disposed? rescue true)
      unless completed_sendout
        next unless (sp.visible rescue false) && (sp.opacity rescue 0).to_i>0
      end
      @bss_scripted_revealed[idx]=mon.object_id
    end
  end

  def bss_scripted_restore_visible
    return unless bss_scripted_visible_scene?
    return if @bss_nds_intro_active ||
              @vermeil_cinema_trainer_intro_depth.to_i>0 ||
              @bss096_native_formation_depth.to_i>0 ||
              @bss096_battler_anim_depth.to_i>0 ||
              @bss070_ebdx_bas_frame ||
              @bas_runtime_playback_depth.to_i>0 ||
              @bss087_native_move_active || @bss084_native_move_active
    (@bss_scripted_revealed || {}).each do |idx,identity|
      b=(@battle.battlers[idx] rescue nil)
      next unless b && !(b.fainted? rescue true)
      mon=(b.pokemon rescue nil)
      next unless mon && mon.object_id==identity
      sp=@sprites["pokemon_#{idx}"]
      next unless sp && !(sp.disposed? rescue true)
      sp.visible=true if sp.respond_to?(:visible=) && !(sp.visible rescue true)
      sp.opacity=255 if sp.respond_to?(:opacity=) && (sp.opacity rescue 255).to_i==0
    end
  rescue StandardError => e
    BSS064.log("BSS scripted battler visibility: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def pbSendOutBattlers(*args,&block)
    result=super
    # Only slots included in this completed native sendout may be marked
    # revealed; other active battlers may still be intentionally hidden.
    rows=args[0].is_a?(Array) ? args[0] : []
    indices=rows.filter_map do |row|
      value=row.is_a?(Array) ? row[0] : row
      value.respond_to?(:index) ? value.index : (value.is_a?(Integer) ? value : nil)
    end
    bss_scripted_remember_visible(false) if indices.empty?
    bss_scripted_remember_visible(true,indices) unless indices.empty?
    result
  end

  def pbStartSpeech(*args,&block)
    bss_scripted_remember_visible if @bss_dialogue_cinema_active
    result=super
    bss_scripted_restore_visible if @bss_dialogue_cinema_active
    result
  end

  def pbForceEndSpeech(*args,&block)
    was_scripted=@bss_dialogue_cinema_active
    result=super
    if was_scripted
      bss_scripted_restore_visible
      @bss_scripted_restore_tail=12
    end
    result
  end

  def pbUpdate(*args,&block)
    result=super
    if @bss_dialogue_cinema_active || @bss_scripted_restore_tail.to_i>0
      bss_scripted_restore_visible
      @bss_scripted_restore_tail=[@bss_scripted_restore_tail.to_i-1,0].max unless @bss_dialogue_cinema_active
    elsif !@bss_nds_intro_active && @vermeil_cinema_trainer_intro_depth.to_i==0
      bss_scripted_remember_visible
    end
    result
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSScriptedActiveBattlerVisibility)
  Battle::Scene.prepend(BSSScriptedActiveBattlerVisibility)
end

# DBK's SlideSpriteAppear intentionally places a duplicate trainer on top of
# pokemon_1. In BSS scripted dialogue the real actor has already completed its
# Pokeball sendout: preserve the author's battler placement and show the name
# plate + black bars without a second full trainer sprite covering the foe.
module BSSScriptedSpeakerComposition
  def bss_scripted_foe_deployed?
    return false unless @bss_dialogue_cinema_active && @battle && @sprites.is_a?(Hash)
    shown=@bss106_presented_pokemon || {}
    @battle.battlers.each_with_index.any? do |b,idx|
      next false unless idx.odd? && b && !(b.fainted? rescue true)
      mon=(b.pokemon rescue nil)
      sp=@sprites["pokemon_#{idx}"]
      next false unless mon && sp && !(sp.disposed? rescue true)
      # AfterLastSendOut can fire DURING the native sendout, before the
      # BSS106 completion registry is committed. Accept either its token or
      # a currently displayed Pokemon, never a merely allocated empty slot.
      completed=shown.is_a?(Hash) && shown[idx]==mon.object_id
      active=(sp.visible rescue false) &&
             (sp.opacity rescue 0).to_i>0 &&
             (sp.respond_to?(:pkmn) ? !!sp.pkmn : true)
      completed || active
    end
  rescue StandardError
    false
  end

  def pbShowSpeaker(*args,&block)
    if bss_scripted_foe_deployed?
      # pbStartSpeech has already established the cinematic textbox/bars.
      # Don't invoke DBK's SlideSpriteAppear on an occupied battlefield.
      @showSpeaker=false
      sprite=@sprites["midbattle_speaker"]
      sprite.visible=false if sprite && !(sprite.disposed? rescue true) &&
                             sprite.respond_to?(:visible=)
      return nil
    end
    super
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSScriptedSpeakerComposition)
  Battle::Scene.prepend(BSSScriptedSpeakerComposition)
end
