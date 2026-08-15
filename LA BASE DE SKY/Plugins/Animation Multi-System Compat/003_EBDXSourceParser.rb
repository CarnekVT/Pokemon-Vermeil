#===============================================================================
# Enumerates Elite Battle DX (EBDX) animation definitions found in the project's
# own Ruby source. It reads files, extracts the block source and records metadata
# so the editor can list EBDX animations and the static parser (003_EBDXParser)
# can translate them into the normalized model.
#===============================================================================
module AnimationMultisystem
  class EBDXSourceParser
    # Scan the project and return an array of definition entries.
    def self.scan
      @definitions = []
      Settings::EBDX_SOURCE_FOLDERS.each do |folder|
        dir = File.join(Dir.pwd, folder)
        next if !Dir.exist?(dir)
        Dir.glob(File.join(dir, "**", "*.rb")).each do |file|
          scan_file(file)
        end
      end
      @definitions
    end

    # Alias used by the loader.
    def self.scan_project
      scan
    end

    # Return definitions matching a move id (used for lazy per-move loads).
    def self.scan_for_move(move_id)
      scan if !@definitions
      up = move_id.to_s.upcase
      @definitions.select { |d| d[:id].to_s.upcase == up && d[:type] == :move }
    end

    # Extract definitions from a raw source string (editor paste / file).
    def self.extract_definitions(source)
      out = []
      lines = source.to_s.lines.to_a
      lines.each_with_index do |line, i|
        if line =~ /EliteBattle\.define(Move|Common)Animation\s*\(\s*[:]?([A-Za-z0-9_]+)(?:\s*,\s*:?([A-Za-z0-9_]+))?/
          kind = $1 == "Move" ? :move : :common
          id = $2.upcase.to_sym
          species = $3 ? $3.upcase.to_sym : nil
          block = extract_block(lines, i)
          out << {
            :id => id, :type => kind, :species => species,
            :source_file => nil, :source_line => i + 1,
            :block_source => block
          }
        end
      end
      out
    end

    def self.definitions
      @definitions || scan
    end

    def self.find(id, type = :move)
      definitions.find { |d| d[:id].to_s.upcase == id.to_s.upcase && d[:type] == type }
    end

    def self.find_move(id)
      find(id, :move) || find(id, :opp_move)
    end

    def self.find_common(id)
      find(id, :common) || find(id, :opp_common)
    end

    #---------------------------------------------------------------------------
    def self.scan_file(file)
      lines = File.readlines(file)
      lines.each_with_index do |line, i|
        # EliteBattle.defineMoveAnimation(:TACKLE)  / with species override
        # EliteBattle.defineMoveAnimation(:LIQUIDATION, :FROZETTE)  (species 2nd arg)
        if line =~ /EliteBattle\.define(Move|Common)Animation\s*\(\s*[:]?([A-Za-z0-9_]+)(?:\s*,\s*:?([A-Za-z0-9_]+))?/
          kind = $1 == "Move" ? :move : :common
          id = $2.upcase.to_sym
          species = $3 ? $3.upcase.to_sym : nil
          block = extract_block(lines, i)
          @definitions << {
            :id => id, :type => kind, :species => species,
            :source_file => file, :source_line => i + 1,
            :block_source => block
          }
        end
      end
    rescue
      nil
    end

    def self.extract_block(lines, def_line_index)
      # Find the opening do / { on the def line or the next few lines.
      i = def_line_index
      opener = nil
      while i < lines.length && i < def_line_index + 3
        if lines[i] =~ /\bdo\b|\{/
          opener = $~[0]
          break
        end
        i += 1
      end
      return "" if !opener
      start = i
      depth = 1
      (start + 1...lines.length).each do |j|
        depth += opens_in_line(lines[j])
        depth -= lines[j].scan(/\bend\b/).length
        if depth <= 0
          return lines[(start + 1)..j].join
        end
      end
      ""
    rescue
      ""
    end

    def self.opens_in_line(line)
      count = 0
      count += line.scan(/\bdo\b/).length
      count += line.scan(/\bbegin\b/).length
      count += line.scan(/\bdef\b/).length
      count += line.scan(/\bclass\b/).length
      count += line.scan(/\bmodule\b/).length
      count += line.scan(/\bif\b/).length
      count += line.scan(/\bunless\b/).length
      count += line.scan(/\bcase\b/).length
      # Ignore 'end' (handled separately) and '}' which we approximate as a close.
      count
    end
  end
end
