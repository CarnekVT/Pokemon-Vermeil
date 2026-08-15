#===============================================================================
# Core helpers, normalized model, graphics resolver and format detector.
#===============================================================================
module AnimationMultisystem
  #-----------------------------------------------------------------------------
  # Value helpers (Color / Tone <-> the string forms the editor model uses).
  #-----------------------------------------------------------------------------
  module ValueHelper
    module_function

    def color_to_string(c)
      r, g, b, a = (c.is_a?(Color)) ? [c.red, c.green, c.blue, c.alpha] : c.to_a
      "%02X%02X%02X%02X" % [r & 0xFF, g & 0xFF, b & 0xFF, a & 0xFF]
    end

    def tone_to_string(t)
      r, g, b, a = (t.is_a?(Tone)) ? [t.red, t.green, t.blue, t.gray] : t.to_a
      s = lambda { |v| v = v.to_i; (v < 0 ? "-" : "+") + sprintf("%02X", v & 0xFF) }
      s.call(r) + s.call(g) + s.call(b) + s.call(a)
    end

    def parse_tone_args(str)
      # Matches Tone.new(r, g, b[, a]) or just numbers separated by commas.
      nums = str.scan(/-?\d+/).map(&:to_i)
      nums << 0 if nums.length == 3
      nums
    end

    def parse_color_args(str)
      nums = str.scan(/-?\d+/).map(&:to_i)
      nums << 255 if nums.length == 3
      nums
    end

    def round(v, n = 0)
      return v if v.nil?
      (v.to_f * (10**n)).round / (10.0**n)
    end
  end

  #-----------------------------------------------------------------------------
  # Normalized animation model. Wraps a GameData::Animation-style hash (so the
  # existing AnimationPlayer can consume it directly) and keeps enough source
  # metadata to later export without destroying original behaviour.
  #-----------------------------------------------------------------------------
  class Animation
    attr_reader :type, :move, :version, :name, :fps, :particles
    attr_reader :source_system, :source_file, :source_line, :source_metadata
    attr_reader :unsupported, :audio_events, :warnings, :notes

    def initialize(opts = {})
      @type            = opts[:type] || :move
      @move            = (opts[:move] || "STRUGGLE").to_s
      @version         = opts[:version] || 0
      @name            = opts[:name] || "Imported animation"
      @fps             = opts[:fps] || 20
      @particles       = opts[:particles] || []
      @source_system   = opts[:source_system] || :unknown
      @source_file     = opts[:source_file]
      @source_line     = opts[:source_line]
      @source_metadata = opts[:source_metadata] || {}
      @unsupported     = opts[:unsupported] || []
      @audio_events    = opts[:audio_events] || []
      @warnings        = opts[:warnings] || []
      @notes           = opts[:notes] || []
    end

    def move_animation?;   [:move, :opp_move].include?(@type); end
    def common_animation?; [:common, :opp_common].include?(@type); end
    def opposing_animation?; [:opp_move, :opp_common].include?(@type); end

    # Plain hash consumable by AnimationPlayer (it reads :fps / :particles).
    def to_hash
      { :type => @type, :move => @move, :version => @version, :name => @name,
        :fps => @fps, :particles => @particles }
    end

    # Full hash in the exact shape GameData::Animation expects, ready to be
    # passed into AnimationEditor (which registers and writes PBS on save).
    def to_editor_hash(anim_type = nil)
      h = to_hash
      h[:type] = (anim_type == 1) ? :common : (@type || :move)
      h[:no_user]          = false
      h[:no_target]        = false
      h[:ignore]           = false
      h[:hides_data_boxes] = false
      h[:credit]           = "Imported via Multi-System Compat"
      h[:flags]            = []
      h[:pbs_path]         = "Imported_#{@name}_#{rand(100_000)}"
      h
    end

    def add_unsupported(context, detail = nil)
      @unsupported << { :context => context.to_s, :detail => detail.to_s }
    end

    def add_audio(frame, name, volume = 100, pitch = 100)
      @audio_events << { :frame => frame.to_i, :name => name.to_s,
                         :volume => volume.to_i, :pitch => pitch.to_i }
    end
  end

  #-----------------------------------------------------------------------------
  # Builds particle hashes in the exact shape AnimationPlayer expects.
  #-----------------------------------------------------------------------------
  module ParticleBuilder
    module_function

    DEFAULT_KEYS = [:x, :y, :z, :zoom_x, :zoom_y, :angle, :opacity,
                    :visible, :frame, :color, :tone, :se, :user_cry, :target_cry]

    def new_particle(name, graphic, focus = :foreground)
      part = { :name => name.to_s, :graphic => graphic.to_s, :focus => focus }
      DEFAULT_KEYS.each { |k| part[k] = [] }
      part
    end

    # SET command: [keyframe, duration=0, value]
    def set(part, prop, kf, value)
      part[prop] ||= []
      part[prop] << [kf.to_i, 0, value]
    end

    # MOVE command: [keyframe, duration, value, interpolation]
    def move(part, prop, kf, duration, value, interp = :linear)
      part[prop] ||= []
      part[prop] << [kf.to_i, duration.to_i, value, interp]
    end

    def set_xy(part, kf, x, y)
      set(part, :x, kf, x.to_i)
      set(part, :y, kf, y.to_i)
    end

    def move_xy(part, kf, duration, x, y, interp = :linear)
      move(part, :x, kf, duration, x.to_i, interp)
      move(part, :y, kf, duration, y.to_i, interp)
    end
  end

  #-----------------------------------------------------------------------------
  # Resolves a referenced graphic to a real file in the loaded project's
  # Graphics folders. Records where it was found and whether it lives in the
  # location the editor player expects ("Graphics/Battle animations/").
  #-----------------------------------------------------------------------------
    module GraphicsResolver
      module_function

      def nil_or_empty?(s)
        s.nil? || s.to_s.strip.empty?
      end

      def all_graphics_files
      return @cache if @cache
      @cache = []
      base = Dir.pwd
      Settings::GRAPHICS_FOLDERS.each do |folder|
        dir = File.join(base, folder)
        next if !Dir.exist?(dir)
        Settings::GRAPHIC_EXTENSIONS.each do |ext|
          Dir.glob(File.join(dir, "**", "*.#{ext}")).each do |path|
            rel = path.sub(base + File::SEPARATOR, "")
            @cache << rel.gsub("\\", "/")
          end
        end
      end
      @cache
    end

    # Returns a hash: { found: bool, path: relative_path, editor_graphic: string,
    #                   in_battle_animations: bool }
    def resolve(name)
      return { :found => false } if nil_or_empty?(name.to_s)
      bare = name.to_s.gsub(/^Graphics\//, "").sub(/\.(png|gif|jpg|jpeg|xyz)$/i, "")
      candidates = all_graphics_files.select do |f|
        f.downcase.end_with?("#{bare.downcase}.png") ||
        f.downcase.end_with?("#{bare.downcase}.gif") ||
        f.downcase.end_with?("#{bare.downcase}.jpg") ||
        f.downcase.end_with?("#{bare.downcase}.xyz")
      end
      if candidates.empty?
        return { :found => false, :searched => bare }
      end
      # Prefer the editor's default location if present.
      preferred = candidates.find { |f| f.start_with?("Graphics/Battle animations/") } || candidates.first
      editor_graphic = preferred.sub(%r{^Graphics/Battle animations/}, "").sub(/\.(png|gif|jpg|jpeg|xyz)$/i, "")
      { :found => true, :path => preferred, :editor_graphic => editor_graphic,
        :in_battle_animations => preferred.start_with?("Graphics/Battle animations/") }
    end
  end

  #-----------------------------------------------------------------------------
  # Classifies an animation source into one of the supported systems.
  #-----------------------------------------------------------------------------
  module FormatDetector
    module_function

    def detect(source)
      if source.is_a?(GameData::Animation)
        return :essentials
      elsif source.is_a?(Hash) && source[:particles]
        return :essentials
      elsif source.is_a?(Class) && source < Battle::Scene::Animation
        return :ruby_animation
      elsif source.is_a?(Battle::Scene::Animation)
        return :ruby_animation
      elsif source.is_a?(String)
        return :ebdx_source if source.include?("EliteBattle.defineMoveAnimation") ||
                               source.include?("EliteBattle.defineCommonAnimation")
        return :ruby_source  if source.include?("def createProcesses")
        return :pbs_source   if source.include?("[Move:") || source.include?("[Common:")
      elsif source.is_a?(Array) && source[0].is_a?(String) && source[0].include?("createProcesses")
        return :ruby_source
      end
      :unknown
    end
  end
end
