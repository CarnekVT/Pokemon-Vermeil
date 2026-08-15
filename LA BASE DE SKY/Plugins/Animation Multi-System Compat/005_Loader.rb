#===============================================================================
# Registry + loaders for all animation systems.
#
# Provides the normalized Animation objects for a given move / common animation
# and entry points for the editor's import flow (Ruby-from-file, EBDX-from-file,
# EBDX-from-source, Essentials/PBS). No runtime capture/recording is used: every
# conversion is static source parsing so it runs safely inside the editor.
#===============================================================================
module AnimationMultisystem
  module Loader
    @registry = { :moves => {}, :commons => {} }
    @scanned = false

    def self.registry; @registry; end

    #---------------------------------------------------------------------------
    # Lookups return an array (several systems may define the same move).
    def self.for_move(move_id)
      ensure_loaded
      key = move_id.to_s.downcase.to_sym
      return @registry[:moves][key] if @registry[:moves].key?(key)
      # Fall back to an EBDX/PBS definition scan for this specific move.
      defs = EBDXSourceParser.scan_for_move(move_id.to_s)
      defs.each do |defn|
        anim = EBDXParser.parse(defn)
        register(anim, :move)
      end
      @registry[:moves][key] || []
    end

    def self.for_common(common_id)
      ensure_loaded
      key = common_id.to_s.downcase.to_sym
      @registry[:commons][key] || []
    end

    def self.register(anim, type)
      return if !anim
      bucket = (type == :common) ? @registry[:commons] : @registry[:moves]
      key = anim.move.to_s.downcase.to_sym
      bucket[key] ||= []
      bucket[key] << anim if !bucket[key].include?(anim)
    end

    #---------------------------------------------------------------------------
    # Loaders
    def self.load_ebdx
      ensure_loaded
    end

    def self.load_ebdx_definition(defn)
      anim = EBDXParser.parse(defn)
      register(anim, anim.type == :common ? :common : :move)
      anim
    end

    # Parse a Ruby file into one or more Animations.
    def self.load_ruby_file(path)
      anims = RubyAnimParser.parse_file(path)
      anims.each { |a| register(a, :move) }
      anims
    end

    # Parse a pasted EBDX block source.
    def self.load_ebdx_source(source, opts = {})
      anim = EBDXParser.parse_source(source, opts)
      register(anim, anim.type == :common ? :common : :move)
      anim
    end

    # Load a standard Essentials / PBS animation (registered by the engine).
    def self.load_essentials(id)
      return nil if !GameData::Animation.exists?(id.to_sym)
      anim = GameData::Animation.get(id.to_sym)
      register(anim, :move)
      anim
    end

    #---------------------------------------------------------------------------
    # Editor import entry point.
    # opts:
    #   :system => :ruby | :ebdx | :essentials
    #   :file   => path (ruby / ebdx-from-file)
    #   :source => block source string (ebdx pasted)
    #   :move   => id for ebdx / essentials
    #   :name   => display name
    def self.import(opts = {})
      case (opts[:system] || :ruby).to_sym
      when :ruby
        return load_ruby_file(opts[:file]) if opts[:file]
        []
      when :ebdx
        if opts[:source]
          return load_ebdx_source(opts[:source],
                                  :move => opts[:move], :name => opts[:name])
        elsif opts[:file]
          src = File.read(opts[:file])
          defs = EBDXSourceParser.extract_definitions(src)
          return defs.map { |d| load_ebdx_definition(d) }
        end
      when :essentials
        return load_essentials(opts[:move])
      end
      nil
    end

    #---------------------------------------------------------------------------
    # One-time scan of the project for EBDX definitions.
    def self.ensure_loaded
      return if @scanned
      @scanned = true
      begin
        defs = EBDXSourceParser.scan_project
        defs.each { |d| load_ebdx_definition(d) }
      rescue
        nil
      end
    end

    def self.reset
      @registry = { :moves => {}, :commons => {} }
      @scanned = false
    end
  end
end
