#===============================================================================
# [VERMEIL] Visual 2.5D - 035_V25FrameProfiler.rb
# V25 Phase 2.3.1 - low-overhead renderer sampling with Sky ground visibility.
#===============================================================================

module Mode7
  module V25FrameProfiler
    SAMPLE_INTERVAL = 180
    @active = false
    @stages = nil
    @build_ms = 0.0

    class << self
      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rescue Exception
        Time.now.to_f
      end
      def should_sample?
        frame = defined?(Graphics) && Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : 0
        frame > 0 && (frame % SAMPLE_INTERVAL) == 0
      rescue Exception
        false
      end
      def active?; @active == true; end
      def begin_sample
        @active = true
        @stages = Hash.new(0.0)
        @build_ms = 0.0
      end
      def end_sample; @active = false; end
      def add(name, seconds)
        return if !active?
        @stages ||= Hash.new(0.0)
        @stages[name] += seconds.to_f * 1000.0
      end
      def set_build(seconds)
        return if !active?
        @build_ms += seconds.to_f * 1000.0
      end
      def stage(name); (@stages && @stages[name]) ? @stages[name] : 0.0; end

      def report(renderer, total_ms)
        known_names = [:ground, :fog, :walls, :priority, :volume, :tone, :geometry,
                       :tilesets, :autotiles, :recompose, :stream, :native_sync, :background]
        known = known_names.inject(0.0) { |sum, key| sum + stage(key) }
        other = total_ms.to_f - known
        other = 0.0 if other < 0.0
        walls = renderer.instance_variable_get(:@nds_fast_wall_active) || []
        strips = renderer.instance_variable_get(:@nds_fast_strip_active) || []
        pobj = renderer.instance_variable_get(:@nds_fast_object_active) || []
        volume = renderer.instance_variable_get(:@nds_volume_active) || []
        geometry = renderer.instance_variable_get(:@nds_object_active) || []
        bands = renderer.instance_variable_get(:@v25_sky_ground_bands_used).to_i
        mode = Mode7.respond_to?(:map_mode) ? Mode7.map_mode : :unknown
        fps = Mode7.respond_to?(:nds_average_fps) ? Mode7.nds_average_fps.to_f :
              (defined?(Graphics) && Graphics.respond_to?(:frame_rate) ? Graphics.frame_rate.to_f : 0.0)
        build_text = @build_ms.to_f > 0.0 ? format(" build=%.2fms", @build_ms) : ""
        Console.echoln(format(
          "[V25 FRAME] total=%.2fms | ground=%.2f walls=%.2f priority=%.2f geometry=%.2f | tiles=%.2f auto=%.2f recompose=%.2f stream=%.2f sync=%.2f fog=%.2f tone=%.2f bg=%.2f other=%.2f%s | mode=%s active W=%d P=%d V=%d G=%d bands=%d | FPS=%.1f",
          total_ms.to_f, stage(:ground), stage(:walls), stage(:priority), stage(:geometry),
          stage(:tilesets), stage(:autotiles), stage(:recompose), stage(:stream),
          stage(:native_sync), stage(:fog), stage(:tone), stage(:background), other, build_text,
          mode.to_s, walls.length, strips.length + pobj.length, volume.length, geometry.length, bands, fps
        )) if defined?(Console)
      rescue Exception => e
        Console.echo_error("V25 frame profiler: #{e.message}") if defined?(Console)
      end
    end
  end
end

# Generic helper used only while a sampled frame is active.
class Mode7Renderer
  {
    :update_nds_ground           => :ground,
    :draw_ground                 => :ground,
    :update_ms_fog               => :fog,
    :update_walls                => :walls,
    :update_priority_surfaces    => :priority,
    :update_nds_volume_faces     => :volume,
    :update_nds_geometry_objects => :geometry,
    :apply_tone_color            => :tone,
    :recomposite_autotiles       => :recompose,
    :nds_model_stream_step       => :stream,
    :fast_refresh_nds_background => :background,
    :refresh_v25_sky_ground_background => :background
  }.each do |method_name, stage_name|
    next if !private_method_defined?(method_name)
    alias_name = "_VERMEIL_V25P22_profile_#{method_name}".to_sym
    next if private_method_defined?(alias_name)
    alias_method alias_name, method_name
    define_method(method_name) do |*args, &block|
      if Mode7::V25FrameProfiler.active?
        t0 = Mode7::V25FrameProfiler.clock
        begin
          send(alias_name, *args, &block)
        ensure
          Mode7::V25FrameProfiler.add(stage_name, Mode7::V25FrameProfiler.clock - t0)
        end
      else
        send(alias_name, *args, &block)
      end
    end
    private method_name
  end

  if private_method_defined?(:build) && !private_method_defined?(:_VERMEIL_V25P22_profile_build)
    alias_method :_VERMEIL_V25P22_profile_build, :build
    def build
      if Mode7::V25FrameProfiler.active?
        t0 = Mode7::V25FrameProfiler.clock
        begin
          _VERMEIL_V25P22_profile_build
        ensure
          Mode7::V25FrameProfiler.set_build(Mode7::V25FrameProfiler.clock - t0)
        end
      else
        _VERMEIL_V25P22_profile_build
      end
    end
    private :build
  end

  if method_defined?(:update) && !method_defined?(:_VERMEIL_V25P22_profile_update)
    alias_method :_VERMEIL_V25P22_profile_update, :update
    def update
      if Mode7::V25FrameProfiler.should_sample?
        Mode7::V25FrameProfiler.begin_sample
        t0 = Mode7::V25FrameProfiler.clock
        begin
          _VERMEIL_V25P22_profile_update
        ensure
          total = (Mode7::V25FrameProfiler.clock - t0) * 1000.0
          Mode7::V25FrameProfiler.report(self, total)
          Mode7::V25FrameProfiler.end_sample
        end
      else
        _VERMEIL_V25P22_profile_update
      end
    end
  end
end

# These two helpers sit outside Mode7Renderer but are called at the start of
# every renderer frame. Time them independently so they cannot hide in 'other'.
if defined?(TilemapRenderer::TilesetBitmaps) &&
   TilemapRenderer::TilesetBitmaps.method_defined?(:update) &&
   !TilemapRenderer::TilesetBitmaps.method_defined?(:_VERMEIL_V25P22_profile_update)
  class TilemapRenderer::TilesetBitmaps
    alias_method :_VERMEIL_V25P22_profile_update, :update
    def update(*args, &block)
      return _VERMEIL_V25P22_profile_update(*args, &block) if !Mode7::V25FrameProfiler.active?
      t0 = Mode7::V25FrameProfiler.clock
      begin
        _VERMEIL_V25P22_profile_update(*args, &block)
      ensure
        Mode7::V25FrameProfiler.add(:tilesets, Mode7::V25FrameProfiler.clock - t0)
      end
    end
  end
end

if defined?(TilemapRenderer::AutotileBitmaps) &&
   TilemapRenderer::AutotileBitmaps.method_defined?(:update) &&
   !TilemapRenderer::AutotileBitmaps.method_defined?(:_VERMEIL_V25P22_profile_update)
  class TilemapRenderer::AutotileBitmaps
    alias_method :_VERMEIL_V25P22_profile_update, :update
    def update(*args, &block)
      return _VERMEIL_V25P22_profile_update(*args, &block) if !Mode7::V25FrameProfiler.active?
      t0 = Mode7::V25FrameProfiler.clock
      begin
        _VERMEIL_V25P22_profile_update(*args, &block)
      ensure
        Mode7::V25FrameProfiler.add(:autotiles, Mode7::V25FrameProfiler.clock - t0)
      end
    end
  end
end

module Mode7
  module V25Native
    class << self
      if method_defined?(:sync) && !method_defined?(:_VERMEIL_V25P22_profile_sync)
        alias_method :_VERMEIL_V25P22_profile_sync, :sync
        def sync(*args, &block)
          return _VERMEIL_V25P22_profile_sync(*args, &block) if !Mode7::V25FrameProfiler.active?
          t0 = Mode7::V25FrameProfiler.clock
          begin
            _VERMEIL_V25P22_profile_sync(*args, &block)
          ensure
            Mode7::V25FrameProfiler.add(:native_sync, Mode7::V25FrameProfiler.clock - t0)
          end
        end
      end
    end
  end
end
