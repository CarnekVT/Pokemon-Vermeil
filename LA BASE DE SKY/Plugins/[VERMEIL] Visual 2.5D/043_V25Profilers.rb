#===============================================================================
# [VERMEIL] Visual 2.5D - 043_V25Profilers.rb
# Diagnostico de rendimiento: profiler de build (lento >250ms), fases de
# geometria, sampler por frame y ciclo de carga. Solo consola, sin efecto en
# gameplay. (Fusiona los antiguos 031/034/035/043.)
#===============================================================================

# --- Build lento: una linea compacta si el build supera 250 ms ---
class Mode7Renderer
  PROFILE_METHODS = [
    :build_v25_entry_cache,
    :cache_terrain_tag_heights,
    :cache_visual_priorities,
    :resolve_projection_from_indoor_tags,
    :compose_ground_fast,
    :build_nds_surface_geometry,
    :cache_wall_visual_components,
    :build_wall_columns,
    :build_priority_surfaces,
    :build_nds_volume_faces,
    :build_nds_geometry_objects,
    :build_nds_runtime_buckets
  ].freeze unless const_defined?(:PROFILE_METHODS)

  PROFILE_METHODS.each do |name|
    next if !private_method_defined?(name)
    alias_name = "_VERMEIL_V513_profile_#{name}".to_sym
    next if private_method_defined?(alias_name)
    alias_method alias_name, name
    define_method(name) do |*args, &block|
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue nil
      result = send(alias_name, *args, &block)
      if t0
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0 rescue 0.0
        @nds_v513_profile ||= Hash.new(0.0)
        @nds_v513_profile[name] += elapsed
      end
      result
    end
    private name
  end

  if private_method_defined?(:build) && !private_method_defined?(:_VERMEIL_V513_profile_build)
    alias_method :_VERMEIL_V513_profile_build, :build
    def build
      @nds_v513_profile = Hash.new(0.0)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue nil
      result = _VERMEIL_V513_profile_build
      if t0
        total = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0 rescue 0.0
        if total >= 250.0 && defined?(Console)
          pieces = (@nds_v513_profile || {}).sort_by { |_k, v| -v }.first(6).map do |k, v|
            "#{k}=#{v.round(1)}"
          end
          known = (@nds_v513_profile || {}).values.inject(0.0, :+)
          other = [total - known, 0.0].max
          pieces << "scan/other=#{other.round(1)}"
          Console.echoln("[VERMEIL PERF] Map#{format('%03d', @map_id.to_i)} build=#{total.round(1)} ms | #{pieces.join(' | ')}")
        end
      end
      result
    end
    private :build
  end
end

# --- Fases de geometria (muestreo cada N frames) ---
module Mode7
  module V25Perf
    class << self
      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rescue Exception
        Time.now.to_f
      end

      def sample_now?
        return false if !Mode7::Config.const_defined?(:V25_PERF_DIAGNOSTICS)
        return false if !Mode7::Config::V25_PERF_DIAGNOSTICS
        interval = if Mode7::Config.const_defined?(:V25_PERF_SAMPLE_INTERVAL)
                     Mode7::Config::V25_PERF_SAMPLE_INTERVAL.to_i
                   else
                     300
                   end
        interval = 300 if interval <= 0
        frame = Graphics.respond_to?(:frame_count) ? Graphics.frame_count.to_i : 0
        frame > 0 && (frame % interval) == 0
      rescue Exception
        false
      end

      def report_geometry(stats)
        @last_geometry = stats
        return if !defined?(Console)
        fps = if Mode7.respond_to?(:nds_average_fps)
                Mode7.nds_average_fps.to_f
              elsif Graphics.respond_to?(:average_frame_rate)
                Graphics.average_frame_rate.to_f
              else
                0.0
              end
        batch = stats[:native_batch] ? "ON" : "OFF"
        text = format(
          "[V25 PERF] Geometry cand=%d visible=%d active=%d culled=%d created=%d | batch=%s native=%.2fms apply=%.2fms total=%.2fms | FPS=%.1f",
          stats[:candidates].to_i,
          stats[:visible].to_i,
          stats[:active].to_i,
          stats[:culled].to_i,
          stats[:created].to_i,
          batch,
          stats[:batch_ms].to_f,
          stats[:apply_ms].to_f,
          stats[:total_ms].to_f,
          fps
        )
        if Console.respond_to?(:echo_li)
          Console.echo_li(text)
        elsif Console.respond_to?(:echo)
          Console.echo(text)
        end
      rescue Exception
      end

      def last_geometry
        @last_geometry
      end

      def status_text
        s = @last_geometry
        return "V25 PERF: esperando muestra" if !s
        format(
          "V25 PERF: cand %d / visible %d / active %d\nBatch: %s | native %.2f ms | apply %.2f ms | total %.2f ms",
          s[:candidates].to_i, s[:visible].to_i, s[:active].to_i,
          s[:native_batch] ? "ON" : "OFF",
          s[:batch_ms].to_f, s[:apply_ms].to_f, s[:total_ms].to_f
        )
      rescue Exception
        "V25 PERF: unavailable"
      end
    end
  end
end

module Mode7
  class << self
    if method_defined?(:mkxpz_ext_status_text) && !method_defined?(:_V25_perf_orig_status_text)
      alias_method :_V25_perf_orig_status_text, :mkxpz_ext_status_text
      def mkxpz_ext_status_text
        _V25_perf_orig_status_text + "\n" + Mode7::V25Perf.status_text
      end
    end
  end
end

# --- Sampler por frame (ciclo completo del renderer) ---
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

# --- Ciclo de carga: setup del mapa separado del build del renderer ---
class Mode7Renderer
  {
    :compose_ground_fast => :compose_ground_fast,
    :ensure_extended_data => :makerstudio_data,
    :prepare_v25_maker_studio_indexes => :makerstudio_indexes,
    :bake_ms_shadows => :makerstudio_shadows
  }.each do |method_name, stage_name|
    next if !private_method_defined?(method_name)
    alias_name = "_VERMEIL_V25LOAD_profile_#{method_name}".to_sym
    next if private_method_defined?(alias_name)
    alias_method alias_name, method_name
    define_method(method_name) do |*args, &block|
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue nil
      result = send(alias_name, *args, &block)
      if t0
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0 rescue 0.0
        @nds_v513_profile ||= Hash.new(0.0)
        # compose_ground_fast was wrapped by the old profiler before Phase 2.5.2
        # replaced it. For the new final method there is no prior timing entry.
        @nds_v513_profile[stage_name] += elapsed
      end
      result
    end
    private method_name
  end
end

# Measure engine/map setup separately from renderer build. This catches startup
# delays from base map loading or other plugins instead of mislabeling them as
# Visual 2.5D build time.
class Game_Map
  if method_defined?(:setup) && !method_defined?(:_VERMEIL_V25LOAD_profile_setup)
    alias_method :_VERMEIL_V25LOAD_profile_setup, :setup
    def setup(map_id)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue nil
      result = _VERMEIL_V25LOAD_profile_setup(map_id)
      if t0 && defined?(Console)
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0 rescue 0.0
        Console.echoln("[VERMEIL LOAD] Map#{format('%03d', map_id.to_i)} Game_Map#setup=#{elapsed.round(1)} ms") if elapsed >= 20.0
      end
      result
    end
  end
end
