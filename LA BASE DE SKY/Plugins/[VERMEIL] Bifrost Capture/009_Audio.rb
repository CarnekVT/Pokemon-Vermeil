# frozen_string_literal: true
# Sound timing inspired by Legends. No extracted copyrighted assets included.
# Only user-provided audio in Audio/SE/Bifrost is loaded as optional custom SE.
module BifrostCapture
  module Audio
    EVENTS = %w[aim switch mode party lock throw hit shake caught
                breakout flee alert critical shiny backstrike calmed].freeze
    VANILLA = {
      "aim"=>"GUI sel cursor", "switch"=>"GUI sel cursor",
      "mode"=>"GUI sel decision", "party"=>"GUI sel cursor",
      "lock"=>"GUI sel decision", "throw"=>"Battle throw",
      "hit"=>"Battle ball drop", "shake"=>"Battle ball shake",
      "caught"=>"Battle catch click", "breakout"=>"Battle ball shake",
      "flee"=>"Battle flee", "alert"=>"Exclaim",
      "critical"=>"Battle critical catch throw", "shiny"=>"GUI sel decision",
       "backstrike"=>"Battle critical catch throw", "calmed"=>"GUI sel decision"
    }.freeze
    PRESETS = {
      "pla_like" => {
        "aim"=>"pla_aim", "switch"=>"pla_switch", "mode"=>"pla_mode",
        "party"=>"pla_party", "lock"=>"pla_lock", "throw"=>"pla_throw",
        "hit"=>"pla_hit", "shake"=>"pla_shake", "caught"=>"pla_caught",
        "breakout"=>"pla_breakout", "flee"=>"pla_flee", "alert"=>"pla_alert",
        "critical"=>"pla_critical", "shiny"=>"pla_shiny",
         "backstrike"=>"pla_backstrike", "calmed"=>"pla_calmed"
      },
      "za_like" => {
        "aim"=>"za_aim", "switch"=>"za_switch", "mode"=>"za_mode",
        "party"=>"za_party", "lock"=>"za_lock", "throw"=>"za_throw",
        "hit"=>"za_hit", "shake"=>"za_shake", "caught"=>"za_caught",
        "breakout"=>"za_breakout", "flee"=>"za_flee", "alert"=>"za_alert",
        "critical"=>"za_critical", "shiny"=>"za_shiny",
         "backstrike"=>"za_backstrike", "calmed"=>"za_calmed"
      }
    }.freeze
    EXTENSIONS = %w[.ogg .wav .mp3].freeze
    # Real, redistributable CC0 recordings from Kenney's Interface Sounds.
    # These are NOT samples from Pokémon Legends: Z-A.
    REAL_FALLBACK = EVENTS.to_h { |event|
      [event, case event
        when "shiny", "backstrike" then "real_critical"
        when "calmed" then "real_party"
        else "real_#{event}"
        end]
    }.freeze

    # Earlier versions wrote synthetic ZA-named PCM WAVs on first launch.
    # Ignore only their recognizable WAV format/duration so they cannot
    # mask real licensed audio after updating this plugin.
    LEGACY_SYNTH_DURATION = {
      "aim"=>0.105, "switch"=>0.072, "mode"=>0.150, "party"=>0.095,
      "lock"=>0.092, "throw"=>0.200, "hit"=>0.140, "shake"=>0.100,
      "caught"=>0.340, "breakout"=>0.270, "flee"=>0.225,
      "alert"=>0.200
    }.freeze

    def self.legacy_synthesized?(event,file)
      return false unless file == "Bifrost/za_#{event}.wav"
      duration = LEGACY_SYNTH_DURATION[event]
      return false unless duration
      path = "Audio/SE/#{file}"
      return false unless File.file?(path)
      return false unless File.size(path) == 44+(22050*duration).to_i*2
      header = File.binread(path,44)
      return false unless header && header.bytesize == 44
      header[0,4] == "RIFF" && header[8,8] == "WAVEfmt " &&
        header[20,2].unpack("v")[0] == 1 &&
        header[22,2].unpack("v")[0] == 1 &&
        header[24,4].unpack("V")[0] == 22050 &&
        header[34,2].unpack("v")[0] == 16
    rescue StandardError
      false
    end

    # Return a real filename INCLUDING its extension. mkxp's Audio.se_play
    # cannot reliably resolve freshly generated WAVs from extensionless names,
    # even when FileTest.audio_exist? reports that a WAV exists.
    # Prefer supplied OGGs over generated WAVs of the same basename.
    def self.existing_file(basename)
      return nil unless basename.to_s =~ /\A[a-z0-9_]+\z/i
      EXTENSIONS.each do |ext|
        path = "Audio/SE/Bifrost/#{basename}#{ext}"
        return "Bifrost/#{basename}#{ext}" if File.file?(path)
      end
      nil
    rescue StandardError
      nil
    end

    def self.has_file?(basename)
      !!existing_file(basename)
    end

    def self.vanilla_file(event)
      name = VANILLA[event]
      return nil unless name && FileTest.audio_exist?("Audio/SE/#{name}")
      name
    rescue StandardError
      nil
    end

    # A failed asset must not cause dozens of ENOENT exceptions per session.
    # Restarting the game clears this cache after fixing the audio files.
    def self.safe_play(file,volume=100,pitch=100)
      return false if @failed_files && @failed_files[file]
      begin
        pbSEPlay(file,volume,pitch)
      rescue ArgumentError
        # Compatibility with older wrappers exposing only pbSEPlay(filename).
        pbSEPlay(file)
      end
      true
    rescue StandardError
      @failed_files ||= {}
      @failed_files[file] = true
      false
    end

    def self.play(event,cfg=nil)
      cfg ||= BifrostCapture.options
      profile = cfg["audio_profile"].to_s
      return false if cfg["feedback_sfx"] == "0" || profile == "muted"
      return false if event.to_s == "shiny" && cfg["shiny_sound_enabled"] == "0"
      name = event.to_s
      return false unless EVENTS.include?(name)
      assigned = cfg["sfx_#{name}"].to_s
      return false unless assigned =~ /\A[a-z0-9_]+\z/i
      return false unless defined?(pbSEPlay)

      file = nil
      if assigned != "none"
        file = existing_file(assigned)
      elsif PRESETS.key?(profile)
        basename = PRESETS[profile][name]
        file = existing_file(basename)
        if profile == "za_like"
          file = nil if legacy_synthesized?(name,file)
          file ||= existing_file(REAL_FALLBACK[name])
        end
      end

      volume = name == "shiny" ? cfg["shiny_sound_volume"].to_i.clamp(0,100) : 100
      pitch = name == "shiny" ? cfg["shiny_sound_pitch"].to_i.clamp(80,140) : 100
      return true if file && safe_play(file,volume,pitch)
      return false if profile == "original"
      fallback = vanilla_file(name)
      return false unless fallback && fallback != file
      safe_play(fallback,volume,pitch)
    rescue StandardError
      false # Optional sound must never interrupt overworld capture.
    end

  end
end
