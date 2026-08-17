#===============================================================================
# [VERMEIL] Visual 2.5D - 031_LoadProfiler.rb
# V5.13 - low-overhead slow-build diagnostics
# Prints one compact line only when a map build exceeds 250 ms.
#===============================================================================

class Mode7Renderer
  PROFILE_METHODS = [
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
