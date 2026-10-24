# frozen_string_literal: true
# Vermeil - Shared camera authority (Battle Scene Studio + Battle Animation Studio)
# BSS owns the persistent EBDX/world shot. BAS adds temporary render-only
# camera transforms without changing the EBDX vector or permanent sprite homes.
# No EBS camera code is imported. Optional BAS remains fully independent.

module VermeilSharedBattleCamera
  VERSION = "1.0.0"

  def self.scene_for(player)
    return nil unless player && player.respond_to?(:runtime_battle)
    battle = player.runtime_battle
    return nil unless battle && battle.respond_to?(:scene)
    battle.scene
  rescue StandardError
    nil
  end
end

module BSSSharedCameraScene
  def bss_shared_camera_available?
    !!(@vector && respond_to?(:bss083_camera_active?) && bss083_camera_active?)
  rescue StandardError
    false
  end

  # BAS acquires a lease on the existing BSS camera, not a replacement camera.
  # Snapshot is diagnostic only: restoring an old snapshot would jump backwards
  # if a battle context changed while an attack was playing.
  def bss_shared_camera_begin(player)
    return false unless bss_shared_camera_available? && player
    @bss_shared_camera_owners ||= {}
    token = player.object_id
    return true if @bss_shared_camera_owners.key?(token)
    if @bss_shared_camera_owners.empty?
      @bss_shared_camera_base = (@vector.get.map { |v| v.to_f } rescue nil)
    end
    @bss_shared_camera_owners[token] = true
    @bss_shared_camera_depth = @bss_shared_camera_owners.length
    @bss083_camera_freeze = @bss083_camera_freeze.to_i + 1
    true
  rescue StandardError => e
    BSS064.log("Shared camera begin: #{e.class}: #{e.message}") if defined?(BSS064)
    false
  end

  def bss_shared_camera_end(player)
    owners = @bss_shared_camera_owners
    return false unless owners && player && owners.delete(player.object_id)
    @bss_shared_camera_depth = owners.length
    @bss083_camera_freeze = [@bss083_camera_freeze.to_i - 1, 0].max
    @bss_shared_camera_base = nil if owners.empty?
    true
  end

  def bss_shared_camera_leased?
    @bss_shared_camera_depth.to_i > 0
  end

  # Replaces the older wrapper which forcibly snapped EBDX to MAIN for every
  # native/BAS action. Preserve the exact current vector and suspend only
  # automatic retargeting and native battler realignment during the animation.
  # Nested multi-hit/scene animation calls share one ownership scope.
  def bss083_with_move_projection(user = nil, targets = nil, camera_cut = true)
    return super unless bss_shared_camera_available?
    outer = @bss_shared_move_depth.to_i == 0
    entered = true
    @bss_shared_move_depth = @bss_shared_move_depth.to_i + 1
    if outer
      @bss_shared_move_prior = {
        :bss098_native_move_active => @bss098_native_move_active,
        :bss096_move_projection_active => @bss096_move_projection_active,
        :bss087_native_move_active => @bss087_native_move_active,
        :bss084_native_move_active => @bss084_native_move_active
      }
      @bss098_native_move_active = true
      @bss096_move_projection_active = true
      @bss087_native_move_active = true
      @bss084_native_move_active = true
      @bss083_camera_freeze = @bss083_camera_freeze.to_i + 1
    end
    yield
  ensure
    if entered && @bss_shared_move_depth.to_i > 0
      @bss_shared_move_depth -= 1
      if @bss_shared_move_depth == 0
        (@bss_shared_move_prior || {}).each { |name, old| instance_variable_set("@#{name}", old) }
        @bss_shared_move_prior = nil
        @bss083_camera_freeze = [@bss083_camera_freeze.to_i - 1, 0].max
        @bss083_animation_projection = false
        @bss083_animation_raw = nil
        # Once BAS restores its render-only transforms, refresh the BSS room
        # using the SAME vector. Never snap to MAIN or an out-of-date shot.
        unless bss_shared_camera_leased?
          begin
            room = @bss070_ebdx_room
            room.position if room && !(room.disposed? rescue true) && room.respond_to?(:position)
            bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
          rescue StandardError => e
            BSS064.log("Shared camera final alignment: #{e.class}: #{e.message}") if defined?(BSS064)
          end
        end
      end
    end
  end

  # While BAS is in charge of attack framing, old command/fight hooks and
  # EBDX suspend/resume code must not reassign the shared world vector.
  def bss070_ebdx_camera_enter(*args)
    return nil if bss_shared_camera_leased?
    super
  end

  def bss070_ebdx_camera_leave(*args)
    return nil if bss_shared_camera_leased?
    super
  end

  def bss096_camera_to_main(*args)
    return false if bss_shared_camera_leased?
    super
  end

  def bss070_ebdx_suspend_world(*args, &block)
    return yield if bss_shared_camera_leased? && block
    super
  end

  # Room animation/tint may continue, but no competing camera interpolation or
  # battler projection may run during BAS's temporary frame transform.
  def bss070_ebdx_tick(advance_camera = true, align = true)
    return super(false, false) if bss_shared_camera_leased?
    super
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSSharedCameraScene)
  Battle::Scene.prepend(BSSSharedCameraScene)
end