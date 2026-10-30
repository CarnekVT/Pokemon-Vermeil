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
    # Original, short SE cues generated once when a ZA-named file is absent.
    # No samples or melodies from Legends: Z-A are embedded here.
    SOUND_DESIGN = {
      "aim"=>[0.105,540,690,0.18], "switch"=>[0.072,760,990,0.15],
      "mode"=>[0.150,455,860,0.21], "party"=>[0.095,610,800,0.17],
      "lock"=>[0.092,930,1050,0.17],
      "throw"=>[0.200,320,860,0.24],
      "hit"=>[0.140,500,140,0.30],
      "shake"=>[0.100,460,540,0.22],
      "caught"=>[0.340,580,920,0.24],
      "breakout"=>[0.270,600,230,0.28],
      "flee"=>[0.225,720,260,0.18],
      "alert"=>[0.200,280,520,0.26]
    }.freeze
    SAMPLE_RATE = 22050

    def self.create_original_cue(event,basename)
      return false unless basename =~ /\Aza_[a-z0-9_]+\z/i
      spec = SOUND_DESIGN[event]
      return false unless spec
      path = "Audio/SE/Bifrost/#{basename}.wav"
      return true if File.file?(path)
      duration,pitch_start,pitch_end,volume = spec
      count = (SAMPLE_RATE*duration).to_i
      phase = 0.0
      noise_state = 1337 # Never affect global rand / capture RNG.
      samples = Array.new(count) do |i|
        time = i.to_f/[count,1].max
        frequency = pitch_start+(pitch_end-pitch_start)*(time*time)
        phase += 2.0*Math::PI*frequency/SAMPLE_RATE
        attack = [i.to_f/(SAMPLE_RATE*0.008),1.0].min
        release = [(1.0-time)/0.20,1.0].min
        env = [attack,release,0.0].max
        env = attack*[release,1.0].min
        noise_state = (noise_state*1103515245+12345)&0x7fffffff
        noise = (noise_state.to_f/0x7fffffff)*2-1
        harmonic = Math.sin(phase)*0.72+Math.sin(phase*1.997)*0.23
        crunch = ["throw","hit","breakout","alert"].include?(event) ? noise*0.12 : noise*0.025
        sample = (32767*volume*env*(harmonic+crunch)).round
        sample.clamp(-32768,32767)
      end
      data = samples.pack("s<*")
      riff_size = 36+data.bytesize
      wav = "RIFF".b+[riff_size].pack("V")+"WAVEfmt ".b+
            [16,1,1,SAMPLE_RATE,SAMPLE_RATE*2,2,16].pack("VvvVVvv")+
            "data".b+[data.bytesize].pack("V")+data
      Dir.mkdir("Audio") unless Dir.exist?("Audio")
      Dir.mkdir("Audio/SE") unless Dir.exist?("Audio/SE")
      Dir.mkdir("Audio/SE/Bifrost") unless Dir.exist?("Audio/SE/Bifrost")
      File.binwrite(path,wav)
      true
    rescue StandardError
      false
    end

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
        if basename && !has_file?(basename) && profile == "za_like"
          create_original_cue(name,basename)
        end
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
