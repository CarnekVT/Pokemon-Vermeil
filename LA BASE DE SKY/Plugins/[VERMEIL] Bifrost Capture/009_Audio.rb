# frozen_string_literal: true
# Sound timing inspired by Legends. No extracted copyrighted assets included.
# Only user-provided audio in Audio/SE/Bifrost is loaded as optional custom SE.
module BifrostCapture
  module Audio
    EVENTS = %w[aim switch mode party lock throw hit shake caught
                breakout flee alert].freeze
    VANILLA = {
      "switch"=>"GUI sel cursor", "mode"=>"GUI sel decision",
      "party"=>"GUI sel cursor", "lock"=>"GUI sel decision",
      "throw"=>"Battle throw", "hit"=>"Battle ball drop",
      "shake"=>"Battle ball shake", "caught"=>"Battle capture success",
      "breakout"=>"Battle ball shake"
    }.freeze
    PRESETS = {
      "pla_like" => {
        "aim"=>"pla_aim", "switch"=>"pla_switch", "mode"=>"pla_mode",
        "party"=>"pla_party", "lock"=>"pla_lock", "throw"=>"pla_throw",
        "hit"=>"pla_hit", "shake"=>"pla_shake", "caught"=>"pla_caught",
        "breakout"=>"pla_breakout", "flee"=>"pla_flee", "alert"=>"pla_alert"
      },
      "za_like" => {
        "aim"=>"za_aim", "switch"=>"za_switch", "mode"=>"za_mode",
        "party"=>"za_party", "lock"=>"za_lock", "throw"=>"za_throw",
        "hit"=>"za_hit", "shake"=>"za_shake", "caught"=>"za_caught",
        "breakout"=>"za_breakout", "flee"=>"za_flee", "alert"=>"za_alert"
      }
    }.freeze
    EXTENSIONS = %w[.ogg .wav .mp3].freeze

    def self.has_file?(basename)
      EXTENSIONS.any? { |ext|
        File.file?("Audio/SE/Bifrost/#{basename}#{ext}")
      }
    rescue StandardError
      false
    end

    def self.play(event,cfg=nil)
      cfg ||= BifrostCapture.options
      profile = cfg["audio_profile"].to_s
      return false if cfg["feedback_sfx"] == "0" || profile == "muted"
      name = event.to_s
      return false unless EVENTS.include?(name)
      assigned = cfg["sfx_#{name}"].to_s
      return false unless assigned =~ /\A[a-z0-9_]+\z/i
      if assigned != "none"
        file = "Bifrost/#{assigned}"
      elsif PRESETS.key?(profile)
        basename = PRESETS[profile][name]
        # Custom PLA/ZA-inspired filenames are optional. If they do not exist,
        # the game still plays its original sound instead of falling silent.
        file = basename && has_file?(basename) ? "Bifrost/#{basename}" :
               VANILLA[name]
      else
        file = profile == "original" ? nil : VANILLA[name]
      end
      return false unless file && defined?(pbSEPlay)
      pbSEPlay(file)
      true
    rescue StandardError
      false # Missing optional audio should not interrupt capture.
    end
  end
end
