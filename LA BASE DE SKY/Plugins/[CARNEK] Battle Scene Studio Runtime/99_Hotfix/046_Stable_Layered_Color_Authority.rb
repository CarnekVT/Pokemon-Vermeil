# frozen_string_literal: true
# BSS atmosphere stabilizer: a single layered-lighting authority for scenery.
# Built-in EBDX tint conflicts with the separated sky/haze/terrain compositor.
module VermeilBSSColorAuthority
  def daylightTint(*args, &block)
    return super unless defined?(BSSLayeredLighting) && BSSLayeredLighting.outdoor?(@data)
    return super unless @bss_layered_generated && @bss_layered_generated.length == 3
    # The separated compositor updates tone on a throttled clock. Do not clear
    # sprite.color here; it destroys the authored dusk haze / trees.
    bss_layered_apply_tone!(true) if respond_to?(:bss_layered_apply_tone!)
    nil
  end
end
if defined?(BSS070EBDXRoom) && !BSS070EBDXRoom.ancestors.include?(VermeilBSSColorAuthority)
  BSS070EBDXRoom.prepend(VermeilBSSColorAuthority)
end
