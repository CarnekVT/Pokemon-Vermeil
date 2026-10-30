# frozen_string_literal: true
# Bifröst audio router. Game references inspire the timing, but no extracted
# commercial audio is included; only user-supplied project files are played.
module BifrostCapture
  module Audio
    EVENTS = %w[aim switch lock throw hit shake caught breakout flee alert].freeze
    VANILLA = {
      "throw"=>"Battle throw", "hit"=>"Battle ball drop",
      "shake"=>"Battle ball shake", "caught"=>"Battle capture success",
      "breakout"=>"Battle ball shake"
    }.freeze

    def self.play(event,cfg=nil)
      cfg ||= BifrostCapture.options
      return false if cfg["feedback_sfx"] == "0" ||
                      cfg["audio_profile"] == "muted"
      name = event.to_s
      return false unless EVENTS.include?(name)
      mapped = cfg["sfx_#{name}"].to_s
      return false unless mapped =~ /\A[a-z0-9_]+\z/i
      if mapped == "none"
        return false if cfg["audio_profile"] == "original"
        file = VANILLA[name]
      else
        # Keep the folder fixed; no path traversal or arbitrary source URLs.
        file = "Bifrost/#{mapped}"
      end
      return false unless file && defined?(pbSEPlay)
      pbSEPlay(file)
      true
    rescue StandardError
      # Missing optional sound files should never cancel an OW encounter.
      false
    end
  end
end
