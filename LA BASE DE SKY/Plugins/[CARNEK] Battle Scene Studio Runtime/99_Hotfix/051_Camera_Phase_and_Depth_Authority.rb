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
    room = nil
    room_held = false
    if outer
      room = scene.instance_variable_get(:@bss070_ebdx_room)
      if room && !(room.disposed? rescue true) && room.respond_to?(:bss106_push_behind!)
        # Previous code moved the whole background by -10_000 Z on each
        # individual move and returned it after each move: visible blinking.
        # Keep that exact render band for the complete attack phase.
        room_held = (room.bss106_push_behind! == true)
      end
    end
    super
  ensure
    if scene_active && scene
      current = scene.instance_variable_get(:@bss_camera_attack_phase_depth).to_i
      scene.instance_variable_set(:@bss_camera_attack_phase_depth,[current-1,0].max)
      if outer && room_held && room && !(room.disposed? rescue true)
        room.bss106_pop_behind! if room.respond_to?(:bss106_pop_behind!)
      end
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
    bss_camera_relayer_trainers if respond_to?(:bss070_ebdx_active?) &&
                                    (bss070_ebdx_active? rescue false)
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
