#===============================================================================
# [VERMEIL] Visual 2.5D - 027_GlobalPerformance.rb
# V5.11 - hot-path cache / idle governor
#
# Keeps expensive mode/metadata/camera queries out of projection hot loops and
# prevents 3D-only geometry from updating after the 2.5D camera is fully OFF.
# No gameplay logic is skipped while 2.5D is active or transitioning.
#===============================================================================

module Mode7
  class << self
    if method_defined?(:indoor_map?) && !method_defined?(:_VERMEIL_PERF_orig_indoor_map)
      alias_method :_VERMEIL_PERF_orig_indoor_map, :indoor_map?
    end
    if method_defined?(:map_mode) && !method_defined?(:_VERMEIL_PERF_orig_map_mode)
      alias_method :_VERMEIL_PERF_orig_map_mode, :map_mode
    end
    if method_defined?(:active_now?) && !method_defined?(:_VERMEIL_PERF_orig_active_now)
      alias_method :_VERMEIL_PERF_orig_active_now, :active_now?
    end
    if method_defined?(:projection_cam_elevation) && !method_defined?(:_VERMEIL_PERF_orig_projection_cam_elevation)
      alias_method :_VERMEIL_PERF_orig_projection_cam_elevation, :projection_cam_elevation
    end
    if method_defined?(:nds_camera_math) && !method_defined?(:_VERMEIL_PERF_orig_nds_camera_math)
      alias_method :_VERMEIL_PERF_orig_nds_camera_math, :nds_camera_math
    end
    if method_defined?(:project) && !method_defined?(:_VERMEIL_PERF_orig_project)
      alias_method :_VERMEIL_PERF_orig_project, :project
    end
    if method_defined?(:perspective_project) && !method_defined?(:_VERMEIL_PERF_orig_perspective_project)
      alias_method :_VERMEIL_PERF_orig_perspective_project, :perspective_project
    end

    # Metadata lookup used to happen indirectly for every projected point via
    # map_mode -> indoor_map?. Cache it until the map/tag state changes.
    def indoor_map?(map_id = nil)
      return _VERMEIL_PERF_orig_indoor_map(map_id) if !Config::GLOBAL_RUNTIME_OPTIMIZATIONS
      id = map_id
      id = $game_map.map_id if id.nil? && $game_map
      id = id ? id.to_i : -1
      tag_id = @tag_indoor_map_id ? @tag_indoor_map_id.to_i : -1
      if @perf_indoor_valid && @perf_indoor_id == id && @perf_indoor_tag_id == tag_id
        return @perf_indoor_value
      end
      value = _VERMEIL_PERF_orig_indoor_map(map_id)
      @perf_indoor_valid = true
      @perf_indoor_id = id
      @perf_indoor_tag_id = tag_id
      @perf_indoor_value = value
      value
    rescue Exception
      _VERMEIL_PERF_orig_indoor_map(map_id)
    end

    def map_mode
      return _VERMEIL_PERF_orig_map_mode if !Config::GLOBAL_RUNTIME_OPTIMIZATIONS
      id = $game_map ? $game_map.map_id.to_i : -1
      override = @projection_override
      projection = @map_projection
      tag_id = @tag_indoor_map_id ? @tag_indoor_map_id.to_i : -1
      if @perf_mode_valid && @perf_mode_id == id &&
         @perf_mode_override == override && @perf_mode_projection == projection &&
         @perf_mode_tag_id == tag_id
        return @perf_mode_value
      end
      value = _VERMEIL_PERF_orig_map_mode
      @perf_mode_valid = true
      @perf_mode_id = id
      @perf_mode_override = override
      @perf_mode_projection = projection
      @perf_mode_tag_id = tag_id
      @perf_mode_value = value
      value
    rescue Exception
      _VERMEIL_PERF_orig_map_mode
    end

    # Explicit setters invalidate the persistent mode caches without touching
    # projection caches every frame during camera interpolation.
    def tag_indoor_map_id=(value)
      @tag_indoor_map_id = value
      @perf_indoor_valid = false
      @perf_mode_valid = false
    end

    def map_projection=(_value)
      # NDS-only: even external/older scripts cannot switch the active map back
      # to Affine/Cylindrical. Keep the writer for API compatibility.
      @map_projection = :perspective
      @perf_mode_valid = false
    end

    # Hundreds of character/wall calls can ask for the same switch state in a
    # frame. Read switches once per frame.
    def active_now?
      return _VERMEIL_PERF_orig_active_now if !Config::GLOBAL_RUNTIME_OPTIMIZATIONS
      frame = Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : -1
      if frame >= 0 && @perf_active_frame == frame
        return @perf_active_value
      end
      value = _VERMEIL_PERF_orig_active_now
      @perf_active_frame = frame
      @perf_active_value = value
      value
    rescue Exception
      _VERMEIL_PERF_orig_active_now
    end

    # Surface elevation is static during a render frame. The original method
    # already cached by player position but still allocated/computed its key on
    # every projected vertex.
    def projection_cam_elevation
      return _VERMEIL_PERF_orig_projection_cam_elevation if !Config::GLOBAL_RUNTIME_OPTIMIZATIONS
      frame = Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : -1
      map_id = $game_map ? $game_map.map_id.to_i : -1
      if frame >= 0 && @perf_elevation_frame == frame && @perf_elevation_map == map_id
        return @perf_elevation_value.to_f
      end
      value = _VERMEIL_PERF_orig_projection_cam_elevation.to_f
      @perf_elevation_frame = frame
      @perf_elevation_map = map_id
      @perf_elevation_value = value
      value
    rescue Exception
      0.0
    end

    # nds_camera_math used an Array key + rounding on every perspective_sin /
    # perspective_cos / perspective_focal call. configure() already increments
    # projection_revision whenever optics change, so one calculation/revision is
    # sufficient.
    def nds_camera_math
      return _VERMEIL_PERF_orig_nds_camera_math if !Config::GLOBAL_RUNTIME_OPTIMIZATIONS
      revision = @projection_revision.to_i
      if @perf_camera_math_revision == revision && @perf_camera_math
        return @perf_camera_math
      end
      @perf_camera_math = _VERMEIL_PERF_orig_nds_camera_math
      @perf_camera_math_revision = revision
      @perf_camera_math
    end

    def render_3d_runtime?
      return true if !Config.const_defined?(:IDLE_3D_WHEN_DISABLED) || !Config::IDLE_3D_WHEN_DISABLED
      return true if active_now?
      frames = @transition_frames.to_i
      return true if frames > 0
      alpha = (@current_alpha || 0.0).to_f.abs
      alpha > 0.02
    rescue Exception
      true
    end

    # Perspective is the main runtime path. Resolve the mode once and project
    # from the cached camera math directly instead of chaining multiple helper
    # calls (each of which used to re-check mode/math/elevation).
    def perf_perspective_project(wx, wy, elevation = 0.0)
      math = nds_camera_math
      py = pivot_y.to_f
      cam_elev = projection_cam_elevation.to_f
      dy = wy.to_f - (projection_cam_y.to_f + py)
      rel_elev = elevation.to_f - cam_elev
      depth = math[:distance].to_f - dy * math[:sin].to_f - rel_elev * math[:cos_raw].to_f
      near = Config::PERSPECTIVE_NEAR_CLIP.to_f
      near = 8.0 if near <= 0.0
      return nil if depth <= near
      focal = math[:focal].to_f
      sx = center_x.to_f + focal * (wx.to_f - cam_x.to_f) / depth
      vertical = dy * math[:cos_raw].to_f - rel_elev * math[:sin].to_f
      sy = py + focal * vertical / depth
      [sx, sy]
    rescue Exception
      _VERMEIL_PERF_orig_perspective_project(wx, wy, elevation)
    end

    def perspective_project(wx, wy, elevation = 0.0)
      return _VERMEIL_PERF_orig_perspective_project(wx, wy, elevation) if !Config::GLOBAL_RUNTIME_OPTIMIZATIONS
      perf_perspective_project(wx, wy, elevation)
    end

    def project(wx, wy, elevation = 0.0)
      return _VERMEIL_PERF_orig_project(wx, wy, elevation) if !Config::GLOBAL_RUNTIME_OPTIMIZATIONS
      mode = map_mode
      return perf_perspective_project(wx, wy, elevation) if mode == :perspective
      _VERMEIL_PERF_orig_project(wx, wy, elevation)
    end
  end
end

class Mode7Renderer
  if private_method_defined?(:nds_ground_active?) &&
     !private_method_defined?(:_VERMEIL_PERF_orig_nds_ground_active)
    alias_method :_VERMEIL_PERF_orig_nds_ground_active, :nds_ground_active?
  end
  if private_method_defined?(:update_nds_volume_faces) &&
     !private_method_defined?(:_VERMEIL_PERF_orig_update_volume_faces)
    alias_method :_VERMEIL_PERF_orig_update_volume_faces, :update_nds_volume_faces
  end
  if private_method_defined?(:update_nds_geometry_objects) &&
     !private_method_defined?(:_VERMEIL_PERF_orig_update_geometry_objects)
    alias_method :_VERMEIL_PERF_orig_update_geometry_objects, :update_nds_geometry_objects
  end

  private

  def nds_ground_active?
    return false if Mode7::Config::IDLE_3D_WHEN_DISABLED && !Mode7.render_3d_runtime?
    _VERMEIL_PERF_orig_nds_ground_active
  end

  def perf_hide_sprite_indices(faces, indices)
    (indices || []).each do |i|
      face = faces && faces[i]
      spr = face && face[:sprite]
      spr.visible = false if spr && !spr.disposed?
    end
  rescue Exception
  end

  def update_nds_volume_faces
    if Mode7::Config::IDLE_3D_WHEN_DISABLED && !Mode7.render_3d_runtime?
      if !@perf_volume_idled
        perf_hide_sprite_indices(@nds_volume_faces, @nds_volume_active)
        @nds_volume_active = []
        @nds_volume_projection_key = nil
        @perf_volume_idled = true
      end
      return
    end
    @perf_volume_idled = false
    _VERMEIL_PERF_orig_update_volume_faces
  end

  def update_nds_geometry_objects
    if Mode7::Config::IDLE_3D_WHEN_DISABLED && !Mode7.render_3d_runtime?
      if !@perf_objects_idled
        perf_hide_sprite_indices(@nds_object_faces, @nds_object_active)
        @nds_object_active = []
        @nds_object_projection_key = nil
        @perf_objects_idled = true
      end
      return
    end
    @perf_objects_idled = false
    _VERMEIL_PERF_orig_update_geometry_objects
  end
end
