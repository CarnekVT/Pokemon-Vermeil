# frozen_string_literal: true
# Preserve built-in controls even while Bifröst's live aiming UI is open.
# USE and BACK are contextual; SPECIAL and F9 ALWAYS keep their original jobs.
module BifrostCapture
  module MapInputGuard
    def update_input(*args)
      if defined?(BifrostCapture::LiveAim) && BifrostCapture::LiveAim.active?
        # D opens the registered-items Ready Menu, and F9 is debug. Exit aim
        # before delegating; never steal these actions for Bifröst.
        debug_key = defined?($DEBUG) && $DEBUG &&
                    Input.const_defined?(:F9) && Input.press?(Input::F9)
        if Input.trigger?(Input::SPECIAL) || debug_key
          BifrostCapture::LiveAim.close
        elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
          # C throws, X cancels: don't also interact with an event/open pause.
          return
        end
      end
      super
    end
  end
end
Scene_Map.prepend(BifrostCapture::MapInputGuard) unless
  Scene_Map.ancestors.include?(BifrostCapture::MapInputGuard)
