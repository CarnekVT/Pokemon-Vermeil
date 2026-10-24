# frozen_string_literal: true
# BAS renders its authored camera over BSS's already-projected world frame.
# This is deliberately a non-destructive, render-only composition: all BAS
# sprite positions/zooms are restored after each Graphics.update by BAS itself.

module BASSharedCameraPlayer
  def initialize(*args)
    super
    @bas_bss_camera_scene = nil
    if defined?(VermeilSharedBattleCamera)
      scene = VermeilSharedBattleCamera.scene_for(self)
      if scene && scene.respond_to?(:bss_shared_camera_begin) && scene.bss_shared_camera_begin(self)
        @bas_bss_camera_scene = scene
      end
    end
  end

  # Custom BSS backdrops can expose these sprites as top-level entries rather
  # than children of battlebg. Their transforms should follow BAS's temporary
  # camera, but HUD and screen-fixed effects must remain untransformed.
  def camera_world_sprite_key?(key)
    return true if @bas_bss_camera_scene && ["bg", "base", "sky", "terrain_bg", "terrain_base"].include?(key.to_s)
    super
  end

  # Authoring can end at a non-neutral camera key. Restore the shot by easing
  # BAS's relative camera back to identity before returning to BSS. No BSS
  # vector change, no second full-scene projection, no synchronous frame wait.
  def update
    if @bas_bss_camera_tail
      @bas_bss_camera_tail_frame += 1
      @done = @bas_bss_camera_tail_frame >= @bas_bss_camera_tail_frames
      return
    end
    super
    return unless @done && @bas_bss_camera_scene
    shot = camera_state.dup
    return if camera_neutral?(shot)
    @bas_bss_camera_tail = shot
    @bas_bss_camera_tail_frame = 0
    fps = (Graphics.frame_rate.to_f rescue 40.0)
    @bas_bss_camera_tail_frames = [[(fps * 0.20).round, 4].max, 15].min
    @done = false
  end

  def camera_state
    return super unless @bas_bss_camera_tail
    shot = @bas_bss_camera_tail
    state = neutral_camera_state
    t = [[@bas_bss_camera_tail_frame.to_f / @bas_bss_camera_tail_frames.to_f, 0.0].max, 1.0].min
    smooth = t * t * (3.0 - 2.0 * t)
    remain = 1.0 - smooth
    state[:x] = shot[:x].to_f * remain
    state[:y] = shot[:y].to_f * remain
    state[:zoom] = 1.0 + (shot[:zoom].to_f - 1.0) * remain
    state[:rotation] = shot[:rotation].to_f * remain
    rad = state[:rotation] * Math::PI / 180.0
    state[:cos] = Math.cos(rad)
    state[:sin] = Math.sin(rad)
    state
  end

  def dispose
    super
  ensure
    if @bas_bss_camera_scene && @bas_bss_camera_scene.respond_to?(:bss_shared_camera_end)
      @bas_bss_camera_scene.bss_shared_camera_end(self)
    end
    @bas_bss_camera_scene = nil
    @bas_bss_camera_tail = nil
  end
end

if defined?(BattleAnimationStudioRuntime::Player) &&
   !BattleAnimationStudioRuntime::Player.ancestors.include?(BASSharedCameraPlayer)
  BattleAnimationStudioRuntime::Player.prepend(BASSharedCameraPlayer)
end