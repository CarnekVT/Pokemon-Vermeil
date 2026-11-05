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

  def bss_scripted_remember_visible(completed_sendout=false)
    return unless bss_scripted_visible_scene?
    @bss_scripted_revealed ||= {}
    @battle.battlers.each do |b|
      next unless b && !(b.fainted? rescue true)
      idx=b.index
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
    bss_scripted_remember_visible(true)
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
