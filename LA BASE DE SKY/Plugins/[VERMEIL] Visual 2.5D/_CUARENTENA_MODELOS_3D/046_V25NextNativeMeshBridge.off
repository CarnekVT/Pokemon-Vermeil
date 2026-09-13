#===============================================================================
# [VERMEIL] Visual 2.5D - 046_V25NextNativeMeshBridge.rb
# V25 mkxp-z Next Phase 1 bridge.
#
# Synchronizes the existing Visual 2.5D pinhole camera into the native Viewport
# camera. On stock Sky this file is inert; the existing Sprite/V25Native.dll
# backend remains untouched.
#===============================================================================

module Mode7
  module MKXPZExt
    class << self
      def v25_engine_capabilities
        return {} if !defined?(V25Engine) || !V25Engine.respond_to?(:capabilities)
        caps = V25Engine.capabilities
        caps.is_a?(Hash) ? caps : {}
      rescue Exception
        {}
      end

      def native_mesh?
        defined?(V25NativeMesh) && v25_engine_capabilities[:native_mesh_instances] == true
      rescue Exception
        false
      end

      def viewport_v25_camera?
        defined?(Viewport) && Viewport.method_defined?(:v25_perspective_set)
      rescue Exception
        false
      end

      def sync_v25_viewport_camera(viewport)
        return false if !viewport || !viewport_v25_camera?
        if !Mode7.perspective_mode?
          viewport.v25_perspective_clear if viewport.respond_to?(:v25_perspective_clear)
          return false
        end

        math = Mode7.nds_camera_math
        near_clip = Mode7::Config::PERSPECTIVE_NEAR_CLIP.to_f
        near_clip = 8.0 if near_clip <= 0.0
        values = [
          Mode7.center_x.to_f,
          Mode7.pivot_y.to_f,
          Mode7.cam_x.to_f,
          Mode7.projection_cam_y.to_f,
          Mode7.projection_cam_elevation.to_f,
          math[:distance].to_f,
          math[:sin].to_f,
          math[:cos_raw].to_f,
          math[:focal].to_f,
          near_clip
        ]
        key = values + [Mode7.projection_revision.to_i]
        if @v25_viewport_camera_key != key || @v25_viewport_camera_object_id != viewport.object_id
          viewport.v25_perspective_set(*values)
          @v25_viewport_camera_key = key
          @v25_viewport_camera_object_id = viewport.object_id
        end
        true
      rescue Exception => e
        if defined?(Console) && !@v25_viewport_camera_error_logged
          @v25_viewport_camera_error_logged = true
          Console.echo_error("V25 Next camera bridge: #{e.message}")
        end
        false
      end
    end
  end
end

class Mode7Renderer
  if method_defined?(:update) && !method_defined?(:_VERMEIL_V25NEXT_orig_update)
    alias_method :_VERMEIL_V25NEXT_orig_update, :update
  end

  def update
    Mode7::MKXPZExt.sync_v25_viewport_camera(@viewport)
    _VERMEIL_V25NEXT_orig_update
    sync_v25_native_mesh_tone if respond_to?(:sync_v25_native_mesh_tone, true)
  end
end

# Extend the existing capability report without changing old-runtime behavior.
module Mode7
  module MKXPZExt
    class << self
      if method_defined?(:capabilities) && !method_defined?(:_VERMEIL_V25NEXT_orig_capabilities)
        alias_method :_VERMEIL_V25NEXT_orig_capabilities, :capabilities
      end

      def capabilities
        base = respond_to?(:_VERMEIL_V25NEXT_orig_capabilities) ? _VERMEIL_V25NEXT_orig_capabilities : {}
        base.merge(
          v25_engine: defined?(V25Engine) ? true : false,
          native_mesh: native_mesh?,
          v25_viewport_camera: viewport_v25_camera?
        )
      rescue Exception
        base || {}
      end
    end
  end
end
