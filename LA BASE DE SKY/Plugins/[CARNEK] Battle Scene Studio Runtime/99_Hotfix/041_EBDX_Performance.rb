# encoding: utf-8
#-------------------------------------------------------------------------------
# BSS performance batch (SOS settle + animated-sprite clone throttling).
#
# A single SOS join unwinds through ~11 bss_pbSOSJoin wrappers. Five of them
# (005/013/014/025/034) each run the full room settle in their ensure block:
# invalidate/recalibrate anchors + room.update + world alignment. That bursts
# the whole per-frame room pipeline (vacuum waves, bubbles, weather, position,
# light clones) up to 5 times in the SAME frame - the "SOS is slow to appear"
# stutter. This batch runs that settle exactly once per SOS call: the first
# ensure to run does the work, the rest become cheap no-ops.
#
# It also stops single-frame sprites (e.g. the spinLights "sLight" created with
# 1 frame) from dispose+clone of their whole bitmap on every animation step.
#-------------------------------------------------------------------------------
module BSSPerfBatch
  # Arm/decrement to build the SETTLE REQUEST instead of executing it. The
  # first version ran the settle in the DEEPEST ensure (they unwind first),
  # but at that point the SOS ally is not registered yet and the camera
  # restores from 013 have not run, so the ally stayed drawn against the old
  # camera until the next tick - "invoked in a position that is not its
  # original one until the graphic updates". The counterpart: 025/034 also
  # settle; with dedup those became no-ops and nothing re-aligned after the
  # restores. Fix: the OUTERMOST ensure (this module, last to run in the
  # unwind) performs the single settle once the whole chain - registration,
  # animation, camera restores - has finished.
  def bss_pbSOSJoin(*args, &block)
    if respond_to?(:bss070_ebdx_active?) && bss070_ebdx_active?
      @bss_perf_sos_depth = @bss_perf_sos_depth.to_i + 1
    end
    super(*args, &block)
  ensure
    if @bss_perf_sos_depth.to_i > 0
      @bss_perf_sos_depth -= 1
      if @bss_perf_sos_depth <= 0
        @bss_perf_sos_depth = 0
        begin
          if @bss_perf_sos_needs_settle
            @bss_perf_sos_needs_settle = false
            bss070_ebdx_invalidate_anchors if respond_to?(:bss070_ebdx_invalidate_anchors)
            bss070_ebdx_recalibrate_if_needed if respond_to?(:bss070_ebdx_recalibrate_if_needed)
            @bss070_ebdx_room.update if @bss070_ebdx_room && !(@bss070_ebdx_room.disposed? rescue true)
            bss070_ebdx_apply_world_alignment if respond_to?(:bss070_ebdx_apply_world_alignment)
          end
        rescue
        end
      end
    end
  end

  # Inner ensure callers (005/013/014/025/034) only REQUEST the settle; the
  # outer ensure executes it exactly once per SOS join, after the whole chain.
  def bss_perf_sos_room_settle!
    @bss_perf_sos_needs_settle = true if @bss_perf_sos_depth.to_i > 0
    nil
  end
end

if defined?(Battle::Scene) && !Battle::Scene.ancestors.include?(BSSPerfBatch)
  Battle::Scene.prepend(BSSPerfBatch)
end

if defined?(BSS070EBDXAnimatedSprite)
  class BSS070EBDXAnimatedSprite
    unless method_defined?(:_bss_perf_orig_anim)
      alias _bss_perf_orig_anim update
      def update
        return _bss_perf_orig_anim if !@frames || @frames.length > 1
        # single-frame sprite: bitmap can never change, skip the dispose+clone
      end
    end
  end
end