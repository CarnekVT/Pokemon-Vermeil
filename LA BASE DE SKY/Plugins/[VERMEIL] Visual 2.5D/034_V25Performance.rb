#===============================================================================
# [VERMEIL] Visual 2.5D - 034_V25Performance.rb
# Phase 2 lightweight diagnostics for the Sky-safe Geometry backend.
#===============================================================================
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
