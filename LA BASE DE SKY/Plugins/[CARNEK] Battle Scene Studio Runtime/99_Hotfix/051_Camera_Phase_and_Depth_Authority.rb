# frozen_string_literal: true
# BSS v2.4 camera ownership / scene depth bridge, informed by EBS priority
# scopes (without importing EBSVector or running a second camera).
#
# Priority: trainer/intro -> cinematic dialogue -> BAS/attack (whole phase) ->
# command/fight composition -> idle hold. Every writer hands back the SAME
# EBDX vector; no forced MAIN reset after a move.

module BSSCameraPhaseAuthority
  def pbAttackPhase(*args, &block)
    scene = (respond_to?(:scene) ? self.scene : nil) rescue nil
    scene_active = scene && scene.respond_to?(:bss070_ebdx_active?) &&
                   (scene.bss070_ebdx_active? rescue false)
    return super unless scene_active
    outer = scene.instance_variable_get(:@bss_camera_attack_phase_depth).to_i == 0
    scene.instance_variable_set(:@bss_camera_attack_phase_depth,
      scene.instance_variable_get(:@bss_camera_attack_phase_depth).to_i + 1)
    # Do not temporarily alter all backdrop sprite Z values. Earlier builds
    # shifted the entire EBDX room by -10_000 when an attack phase started,
    # then shifted it back: the day/night sky and terrain flashed or vanished.
    # Ownership is represented by the phase counter only.
    super
  ensure
    if scene_active && scene
      current = scene.instance_variable_get(:@bss_camera_attack_phase_depth).to_i
      scene.instance_variable_set(:@bss_camera_attack_phase_depth,[current-1,0].max)
      # No backdrop-depth restoration: nothing was displaced.
      # Leave the camera where BAS ended: only a future menu may request
      # another shot; never snap to a stale intro/attack camera.
    end
  end
end

module BSSCameraTrainerDepth
  def bss_camera_relayer_trainers
    return unless @sprites.is_a?(Hash) && @battle
    return if @vermeil_cinema_trainer_intro_depth.to_i > 0 ||
              @bss_nds_intro_active
    opponents = (@battle.opponent rescue nil)
    return unless opponents && opponents.respond_to?(:length)
    opponents.length.times do |i|
      # DBK/Essentials index trainer sprites FROM ONE. Earlier BSS world
      # projection used trainer_0 for the first trainer, which was incorrect.
      trainer = @sprites["trainer_#{i + 1}"]
      battler = @sprites["pokemon_#{2*i+1}"]
      next unless trainer && battler
      next if (trainer.disposed? rescue false) || (battler.disposed? rescue false)
      next unless battler.visible && (battler.opacity rescue 255).to_i > 0
      next unless trainer.respond_to?(:z=) && battler.respond_to?(:z)
      trainer.z = battler.z.to_i - 2
    end
  rescue StandardError => e
    BSS064.log("Trainer Z-order: #{e.class}: #{e.message}") if defined?(BSS064)
  end

  def pbUpdate(*args, &block)
    result = super
    if respond_to?(:bss070_ebdx_active?) && (bss070_ebdx_active? rescue false)
      # Native DBK darken/revert clips sometimes make Essentials' battle_bg
      # visible for one frame. The EBDX room is the single background:
      # re-hide native fallback planes at the end of each update.
      # The EBDX room compositor already handles native backdrop visibility.
      # Do not forcibly set native background opacity to zero a second time
      # after every animation tick (this broke fade/reveal composition).
      bss_camera_relayer_trainers
    end
    result
  end

  def bss070_ebdx_apply_world_alignment(*args, &block)
    result = super
    bss_camera_relayer_trainers
    result
  end
end

if defined?(Battle) && !Battle.ancestors.include?(BSSCameraPhaseAuthority)
  Battle.prepend(BSSCameraPhaseAuthority)
end
if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSCameraTrainerDepth)
  Battle::Scene.prepend(BSSCameraTrainerDepth)
end
