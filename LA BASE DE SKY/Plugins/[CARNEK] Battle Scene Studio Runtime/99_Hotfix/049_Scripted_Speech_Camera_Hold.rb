# frozen_string_literal: true
# BSS and DBK may display cinematic dialogue during command/move phases.
# Their message loops repeatedly call Scene#pbUpdate, so the camera director
# must not orbit or re-anchor visible trainer sprites until the speech ends.
module BSSScriptedDialogueCameraHold
  def execute_trigger(*args, &block)
    scene=(@battle.scene rescue nil)
    if scene
      scene.instance_variable_set(:@vermeil_cinema_script_depth,
        scene.instance_variable_get(:@vermeil_cinema_script_depth).to_i + 1)
    end
    super
  ensure
    if scene
      depth=scene.instance_variable_get(:@vermeil_cinema_script_depth).to_i
      scene.instance_variable_set(:@vermeil_cinema_script_depth,[depth-1,0].max)
    end
  end
end

module BSSDBKSpeechCameraHold
  def pbProcessText(*args, &block)
    @vermeil_cinema_script_depth=@vermeil_cinema_script_depth.to_i+1
    super
  ensure
    @vermeil_cinema_script_depth=[@vermeil_cinema_script_depth.to_i-1,0].max
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
