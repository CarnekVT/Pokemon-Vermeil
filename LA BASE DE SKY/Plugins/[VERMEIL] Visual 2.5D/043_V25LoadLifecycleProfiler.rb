#===============================================================================
# [VERMEIL] Visual 2.5D - 043_V25LoadLifecycleProfiler.rb
# Distinguishes renderer-build work that previously hid inside scan/other.
#===============================================================================
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
