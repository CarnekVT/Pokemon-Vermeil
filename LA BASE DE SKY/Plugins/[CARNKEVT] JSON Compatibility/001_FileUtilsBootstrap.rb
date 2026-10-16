# encoding: UTF-8
# Retrocompatible startup shim for Ruby environments without fileutils.
# This plugin runs with First = true, before Battle Scene Studio and MakerStudio.
unless defined?(FileUtils) && FileUtils.respond_to?(:mkdir_p)
  begin
    require "fileutils"
  rescue LoadError
    # Embedded Ruby stdlib is missing fileutils.
  rescue RuntimeError => error
    # Some packaged Ruby stdlib files target a different interpreter version.
    raise unless /ruby lib version|incompatible library version|ruby version/i.match?(error.message.to_s)
  end
end

unless defined?(FileUtils) && FileUtils.respond_to?(:mkdir_p)
  module FileUtils
    module_function

    # Minimal, standard-library-free replacement for FileUtils.mkdir_p.
    # Supports nested paths and arrays, with compatible mode/noop keywords.
    def mkdir_p(paths, mode: nil, noop: false, verbose: false)
      entries = paths.is_a?(Array) ? paths : [paths]
      entries.each do |entry|
        path = entry.to_s
        raise ArgumentError, "Empty directory path" if path.empty?
        absolute = File.expand_path(path)
        missing = []
        current = absolute
        until File.directory?(current)
          raise Errno::EEXIST, current if File.exist?(current)
          parent = File.dirname(current)
          raise Errno::ENOENT, current if parent == current
          missing << current
          current = parent
        end
        next if noop
        missing.reverse_each do |folder|
          begin
            Dir.mkdir(folder, mode || 0777)
          rescue Errno::EEXIST
            raise unless File.directory?(folder)
          end
        end
      end
      entries
    end

    def mkpath(*args, **kwargs)
      mkdir_p(*args, **kwargs)
    end
  end
end

unless defined?(FileUtils) && FileUtils.respond_to?(:mkdir_p)
  raise LoadError, "FileUtils.mkdir_p is unavailable to project plugins"
end

# Ensure later require "fileutils" calls do not retry a missing stdlib gem.
unless $LOADED_FEATURES.any? { |entry|
  entry.to_s.tr("\\", "/").split("/").last == "fileutils.rb"
}
  $LOADED_FEATURES << "fileutils.rb"
end
