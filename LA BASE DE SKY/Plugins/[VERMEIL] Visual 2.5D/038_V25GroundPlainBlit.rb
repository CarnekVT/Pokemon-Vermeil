#===============================================================================
# [VERMEIL] Visual 2.5D - 038_V25GroundPlainBlit.rb
# Phase 2.4.11 - plain ground blit hot path
#
# Entries without Maker Studio color effects are copied directly. This preserves
# exact pixels while avoiding baked_source() and its temporary [bitmap, rect]
# Array on the common path. Effect-bearing entries keep the original pipeline.
#===============================================================================
class Mode7Renderer
  private

  if private_method_defined?(:blt_entry_into) &&
     !private_method_defined?(:_VERMEIL_V25_2411_orig_blt_entry_into)
    alias_method :_VERMEIL_V25_2411_orig_blt_entry_into, :blt_entry_into
  end

  def blt_entry_into(dst, dx_px, y, entry, opacity = 255)
    state = entry[:v25_plain_blt]
    if state.nil?
      plain = !entry[:hue] && !entry[:saturation] && !entry[:lighting] &&
              !entry[:tone] && !entry[:color]
      state = plain ? 1 : 0
      entry[:v25_plain_blt] = state
    end

    if state == 1
      bitmap = entry[:bitmap]
      rect = entry[:src_rect]
      return dst.blt(dx_px, y, bitmap, rect, opacity) if bitmap && rect
    end

    return _VERMEIL_V25_2411_orig_blt_entry_into(dst, dx_px, y, entry, opacity)
  end
end
