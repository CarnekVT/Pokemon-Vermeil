#===============================================================================
# [VERMEIL] Visual 2.5D - 033_V25NativeAccelerator.rb
# V25 Phase 2 - SKY SAFE PERFORMANCE BRIDGE
#
# IMPORTANT:
#   This version DOES NOT require a modified Game.exe.
#   It keeps the current La Base de Sky runtime untouched and loads the tiny
#   V25Native.dll only for CPU projection math.
#
# Design:
#   * Never inherits Luka's old runtime behavior.
#   * Batch-quad native path is enabled when the DLL is present.
#   * Single-point DLL calls are OFF by default because Win32API+pack overhead
#     may be slower than the already optimized Ruby point projection.
#   * Full Ruby fallback remains available at all times.
#===============================================================================

module Mode7
  module Config
    V25_NATIVE_ACCELERATOR = true unless const_defined?(:V25_NATIVE_ACCELERATOR)
    V25_NATIVE_LOG         = true unless const_defined?(:V25_NATIVE_LOG)
    # Keep false for Phase 1.1. Quad batches benefit more from crossing FFI once.
    V25_NATIVE_SINGLE_POINT = false unless const_defined?(:V25_NATIVE_SINGLE_POINT)
    V25_NATIVE_DLL = "V25Native.dll" unless const_defined?(:V25_NATIVE_DLL)
    V25_NATIVE_SCREEN_MARGIN = 40.0 unless const_defined?(:V25_NATIVE_SCREEN_MARGIN)
  end

  module V25Native
    class << self
      def init_api
        return @api_ok unless @api_ok.nil?
        @api_ok = false
        return false if !defined?(Win32API)

        candidates = [Mode7::Config::V25_NATIVE_DLL, "./#{Mode7::Config::V25_NATIVE_DLL}"]
        candidates.each do |dll|
          begin
            version = Win32API.new(dll, "v25_version", "", "i")
            ver = version.call.to_i
            next if ver < 102

            @dll_name = dll
            @fn_version = version
            @fn_set     = Win32API.new(dll, "v25_set_camera", "p", "i")
            @fn_clear   = Win32API.new(dll, "v25_clear_camera", "", "i")
            @fn_point   = Win32API.new(dll, "v25_project_point", "pp", "i")
            @fn_quad    = Win32API.new(dll, "v25_project_quad", "pp", "i")
            @fn_points  = Win32API.new(dll, "v25_project_points", "pip", "i")
            if ver >= 103
              begin
                @fn_screen = Win32API.new(dll, "v25_set_screen", "p", "i")
                @fn_sprite_quads = Win32API.new(dll, "v25_project_sprite_quads", "pip", "i")
              rescue Exception
                @fn_sprite_quads = nil
              end
            end
            @version = ver
            @point_out = "\0" * 16
            @quad_out  = "\0" * 64
            @sprite_batch_out = ""
            @api_ok = true
            break
          rescue Exception => e
            @last_error = e.message
          end
        end
        @api_ok
      rescue Exception => e
        @last_error = e.message
        @api_ok = false
      end

      def api_available?
        init_api
      end

      def enabled?
        return false if !Mode7::Config::V25_NATIVE_ACCELERATOR
        return false if @forced_off
        api_available?
      end

      def active?
        !!@active
      end

      def clear
        @fn_clear.call if @fn_clear && @api_ok
        @sync_key = nil
        @active = false
      rescue Exception => e
        @last_error = e.message
        @sync_key = nil
        @active = false
      end

      def sync(_viewport = nil)
        return false if !enabled?
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
        screen_values = [
          Mode7.screen_w.to_f,
          Mode7.screen_h.to_f,
          Mode7::Config::V25_NATIVE_SCREEN_MARGIN.to_f
        ]

        key = values + screen_values + [Mode7.projection_revision.to_i]
        if @sync_key != key
          packed = values.pack("d*")
          ok = @fn_set.call(packed).to_i
          if ok == 0
            @last_error = "v25_set_camera returned 0"
            @active = false
            return false
          end
          if @fn_screen
            sok = @fn_screen.call(screen_values.pack("d*")).to_i
            if sok == 0
              @last_error = "v25_set_screen returned 0"
              @active = false
              return false
            end
          end
          @sync_key = key
        end
        @active = true
        true
      rescue Exception => e
        @last_error = e.message
        @active = false
        false
      end

      # Optional single-point path. Off by default because one FFI transition
      # per vertex is not the optimization target of this safe bridge.
      def project_point(wx, wy, elevation = 0.0)
        return nil if !active?
        input = [wx.to_f, wy.to_f, elevation.to_f].pack("d*")
        out = @point_out
        ok = @fn_point.call(input, out).to_i
        return nil if ok == 0
        out.unpack("d2")
      rescue Exception => e
        @last_error = e.message
        nil
      end

      # The intended Phase 1.1 fast path: 4 vertices through one FFI call.
      def project_quad(world)
        return nil if !active? || !world || world.length != 12
        input = world.pack("d*")
        out = @quad_out
        ok = @fn_quad.call(input, out).to_i
        return nil if ok == 0
        out.unpack("d8")
      rescue Exception => e
        @last_error = e.message
        nil
      end


      # Phase 2: Sky fallback batch. One FFI transition projects/culls every
      # candidate face and returns only the Sprite transform needed by stock Sky.
      # packed_world is a String containing count*12 doubles. Return layout is
      # count*6 doubles: x,y,width,height,angle,depth. width=0 means culled.
      def sprite_batch_available?
        api_available? && @version.to_i >= 103 && !!@fn_sprite_quads
      end

      def project_sprite_quads_packed(packed_world, count)
        return nil if !active? || !sprite_batch_available?
        count = count.to_i
        return [] if count <= 0
        return nil if !packed_world.is_a?(String)
        need = count * 6 * 8
        if !@sprite_batch_out || @sprite_batch_out.bytesize < need
          @sprite_batch_out = "\0" * need
        end
        ok = @fn_sprite_quads.call(packed_world, count, @sprite_batch_out).to_i
        return nil if ok != count
        @sprite_batch_out.unpack("d#{count * 6}")
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
        return "DLL MISSING" if !api_available?
        return "OFF (debug)" if @forced_off
        return "ON DLL v#{@version}#{sprite_batch_available? ? " [batch]" : ""}" if active?
        enabled? ? "READY DLL v#{@version}" : "OFF"
      end

      def last_error; @last_error; end
      def version; @version; end

      def log_once
        return if @logged || !Mode7::Config::V25_NATIVE_LOG
        @logged = true
        text = if api_available?
                 "[VERMEIL 2.5D] V25Native.dll v#{@version}: available (Sky-safe)"
               else
                 "[VERMEIL 2.5D] V25Native.dll: unavailable; Ruby fallback"
               end
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
    # Preserve optimized Ruby functions from 027_GlobalPerformance.rb.
    if method_defined?(:project) && !method_defined?(:_V25_dll_orig_project)
      alias_method :_V25_dll_orig_project, :project
    end
    if method_defined?(:perspective_project) && !method_defined?(:_V25_dll_orig_perspective_project)
      alias_method :_V25_dll_orig_perspective_project, :perspective_project
    end

    def project(wx, wy, elevation = 0.0)
      if Config::V25_NATIVE_SINGLE_POINT && V25Native.active? && perspective_mode?
        return V25Native.project_point(wx, wy, elevation)
      end
      _V25_dll_orig_project(wx, wy, elevation)
    end

    def perspective_project(wx, wy, elevation = 0.0)
      if Config::V25_NATIVE_SINGLE_POINT && V25Native.active?
        return V25Native.project_point(wx, wy, elevation)
      end
      _V25_dll_orig_perspective_project(wx, wy, elevation)
    end

    # world = [x0,y0,z0, x1,y1,z1, x2,y2,z2, x3,y3,z3]
    def project_quad(world)
      if V25Native.active?
        result = V25Native.project_quad(world)
        return result if result
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
      text = "V25 Native DLL: #{V25Native.status}"
      err = V25Native.last_error
      text += "\nLast error: #{err}" if err && !err.empty? && !V25Native.api_available?
      text
    end
  end
end

class Mode7Renderer
  if instance_methods(false).include?(:update) &&
     !instance_methods(false).include?(:_V25_dll_orig_update)
    alias_method :_V25_dll_orig_update, :update
  end

  def update
    Mode7::V25Native.sync(@viewport)
    _V25_dll_orig_update
  end

  if instance_methods(false).include?(:dispose) &&
     !instance_methods(false).include?(:_V25_dll_orig_dispose)
    alias_method :_V25_dll_orig_dispose, :dispose
  end

  def dispose
    Mode7::V25Native.clear
    _V25_dll_orig_dispose
  end
end

module Mode7
  class << self
    if method_defined?(:mkxpz_ext_status_text) && !method_defined?(:_V25_dll_orig_status_text)
      alias_method :_V25_dll_orig_status_text, :mkxpz_ext_status_text
      def mkxpz_ext_status_text
        _V25_dll_orig_status_text + "\n" + v25_native_status_text
      end
    end
  end
end

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :vermeil_v25_native_toggle, {
    "name"        => _INTL("V25 Native DLL: ON/OFF"),
    "parent"      => :main,
    "description" => _INTL("Alterna el acelerador DLL sin cambiar el Game.exe de Sky."),
    "effect"      => proc {
      off = Mode7::V25Native.toggle
      Mode7::V25Native.sync unless off
      pbMessage(_INTL("V25 Native DLL: {1}", Mode7::V25Native.status))
    }
  })
end

EventHandlers.add(:on_frame_update, :vermeil_v25_native_log,
  proc { Mode7::V25Native.log_once }
)
