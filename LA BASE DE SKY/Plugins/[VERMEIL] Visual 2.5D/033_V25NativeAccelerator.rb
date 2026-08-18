#===============================================================================
# [VERMEIL] Visual 2.5D - 033_V25NativeAccelerator.rb
# Phase 1 native accelerator for the mkxp-z V25 fork.
#
# Goals:
#   * Keep the current Visual 2.5D projection visually identical.
#   * Move pinhole projection math into C++ when the runtime exposes it.
#   * Keep a full Ruby fallback for normal mkxp-z / older mkxp-z-ext builds.
#   * Provide an A/B debug toggle before moving full geometry to V25World.
#===============================================================================

module Mode7
  module Config
    V25_NATIVE_ACCELERATOR = true unless const_defined?(:V25_NATIVE_ACCELERATOR)
    V25_NATIVE_LOG         = true unless const_defined?(:V25_NATIVE_LOG)
  end

  module V25Native
    class << self
      attr_reader :viewport

      def api_available?
        return false if !defined?(Viewport)
        Viewport.method_defined?(:v25_perspective_set) &&
          Viewport.method_defined?(:v25_perspective_clear) &&
          Viewport.method_defined?(:v25_project_point) &&
          Viewport.method_defined?(:v25_project_quad)
      rescue Exception
        false
      end

      def enabled?
        return false if !Mode7::Config::V25_NATIVE_ACCELERATOR
        return false if @forced_off
        api_available?
      end

      # Hot-path query: never cross back into C++ here. sync() updates this
      # once per renderer frame, while project() can be called thousands of times.
      def active?
        !!@active
      end

      def register_viewport(vp)
        return if !vp || vp.disposed?
        @viewport = vp
      rescue Exception
      end

      def clear
        vp = @viewport
        vp.v25_perspective_clear if vp && !vp.disposed? && vp.respond_to?(:v25_perspective_clear)
        @sync_key = nil
        @active = false
      rescue Exception
        @sync_key = nil
        @active = false
      end

      def sync(vp = nil)
        register_viewport(vp) if vp
        vp = @viewport
        return false if !enabled? || !vp || vp.disposed?
        if !Mode7.perspective_mode?
          clear
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

        # Most frames move the camera, but on idle frames this avoids a Ruby ->
        # native call entirely. projection_revision catches optics changes.
        key = values + [Mode7.projection_revision.to_i]
        if @sync_key != key
          vp.v25_perspective_set(*values)
          @sync_key = key
        end
        @active = true
        true
      rescue Exception => e
        @last_error = e.message
        clear
        false
      end

      def project_point(wx, wy, elevation = 0.0)
        return nil if !active?
        @viewport.v25_project_point(wx.to_f, wy.to_f, elevation.to_f)
      rescue Exception => e
        @last_error = e.message
        nil
      end

      def project_quad(world)
        return nil if !active? || !world || world.length != 12
        @viewport.v25_project_quad(world)
      rescue Exception => e
        @last_error = e.message
        nil
      end

      def forced_off?; !!@forced_off; end

      def toggle
        @forced_off = !@forced_off
        clear if @forced_off
        @forced_off
      end

      def status
        return "UNAVAILABLE" if !api_available?
        return "OFF (debug)" if @forced_off
        return "ON" if active?
        return enabled? ? "READY" : "OFF"
      end

      def last_error; @last_error; end

      def log_once
        return if @logged || !Mode7::Config::V25_NATIVE_LOG
        @logged = true
        text = "[VERMEIL 2.5D] V25 Native Accelerator: #{api_available? ? 'available' : 'not available; Ruby fallback'}"
        if defined?(Console) && Console.respond_to?(:echo_li)
          Console.echo_li(text)
        elsif defined?(Console) && Console.respond_to?(:echo)
          Console.echo(text)
        end
      rescue Exception
      end
    end
  end

  class << self
    # Preserve the fully optimized Ruby path from 027_GlobalPerformance.rb.
    if method_defined?(:project) && !method_defined?(:_V25_native_orig_project)
      alias_method :_V25_native_orig_project, :project
    end
    if method_defined?(:perspective_project) && !method_defined?(:_V25_native_orig_perspective_project)
      alias_method :_V25_native_orig_perspective_project, :perspective_project
    end

    def project(wx, wy, elevation = 0.0)
      if V25Native.active? && perspective_mode?
        # nil is meaningful here: the native camera rejected a point behind the
        # near plane, exactly like the Ruby perspective path.
        return V25Native.project_point(wx, wy, elevation)
      end
      _V25_native_orig_project(wx, wy, elevation)
    end

    def perspective_project(wx, wy, elevation = 0.0)
      if V25Native.active?
        return V25Native.project_point(wx, wy, elevation)
      end
      _V25_native_orig_perspective_project(wx, wy, elevation)
    end

    # Batch four world vertices through a single Ruby -> C++ transition.
    # world = [x0,y0,z0, x1,y1,z1, x2,y2,z2, x3,y3,z3]
    def project_quad(world)
      if V25Native.active?
        return V25Native.project_quad(world)
      end
      return nil if !world || world.length != 12
      out = []
      4.times do |i|
        p = project(world[i * 3], world[i * 3 + 1], world[i * 3 + 2])
        return nil if !p
        out << p[0] << p[1]
      end
      out
    end

    def v25_native_status_text
      text = "V25 Native: #{V25Native.status}"
      err = V25Native.last_error
      text += "\nLast error: #{err}" if err && !err.empty?
      text
    end
  end
end

# Sync the native camera once at the beginning of the map renderer update. All
# subsequent Mode7.project calls in the frame see the same camera state.
class Mode7Renderer
  if instance_methods(false).include?(:update) &&
     !instance_methods(false).include?(:_V25_native_orig_update)
    alias_method :_V25_native_orig_update, :update
  end

  def update
    Mode7::V25Native.sync(@viewport)
    _V25_native_orig_update
  end

  if instance_methods(false).include?(:dispose) &&
     !instance_methods(false).include?(:_V25_native_orig_dispose)
    alias_method :_V25_native_orig_dispose, :dispose
  end

  def dispose
    if Mode7::V25Native.viewport.equal?(@viewport)
      Mode7::V25Native.clear
    end
    _V25_native_orig_dispose
  end
end

# Extend the existing diagnostics without replacing them.
module Mode7
  class << self
    if method_defined?(:mkxpz_ext_status_text) && !method_defined?(:_V25_native_orig_status_text)
      alias_method :_V25_native_orig_status_text, :mkxpz_ext_status_text
      def mkxpz_ext_status_text
        _V25_native_orig_status_text + "\n" + v25_native_status_text
      end
    end
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :vermeil_v25_native_toggle, {
    "name"        => _INTL("V25 Native Accelerator: ON/OFF"),
    "parent"      => :main,
    "description" => _INTL("Alterna la proyeccion C++ y Ruby para comparar rendimiento."),
    "effect"      => proc {
      off = Mode7::V25Native.toggle
      Mode7::V25Native.sync($scene.instance_variable_get(:@map_renderer).viewport) rescue nil unless off
      pbMessage(_INTL("V25 Native Accelerator: {1}", Mode7::V25Native.status))
    }
  })
end

EventHandlers.add(:on_frame_update, :vermeil_v25_native_log,
  proc { Mode7::V25Native.log_once }
)
