#===============================================================================
# 001_Core.rb - Lógica de Datos y Caché (Backend)
#===============================================================================
module VermeilChangeDex
  @canon_cache = {}
  @canon_move_data = nil
  @custom_move_ids = nil
  @custom_ability_ids = nil
  @detect_cache = nil

  # --- Compatibilidad con Base de Sky ---
  @snapshot = nil
  def self.clear_cache; @detect_cache = nil; end
  def self.load_canon_from_snapshot(snap); @snapshot = snap; end
  # --------------------------------------

  def self.detect_cache
    return @detect_cache
  end

  def self.detect_cache=(value)
    @detect_cache = value
  end

  def self.load_canon_data
    return if !@canon_cache.empty?
    files = Dir.glob("CanonData/*.txt")
    return if files.empty?
    current_id = nil; current_form = 0
    files.each do |file_path|
      File.open(file_path, "r:utf-8") do |f|
        f.each_line do |line|
          line = line.strip.split("#")[0]; next if line.nil? || line.empty?
          if line[/^\[(.+)\]$/]
            content = $1; parts = content.split(",")
            current_id = parts[0].strip.to_sym
            current_form = parts[1] ? parts[1].strip.to_i : 0
            @canon_cache[current_id] ||= {}
            @canon_cache[current_id][current_form] = { 
              :stats => [], :abilities => [], :hidden_abilities => [],
              :types => [], :level_moves => [], :tutor_moves => [], :egg_moves => [],
              :evolutions => []
            }
            next
          end
          next if current_id.nil?; data = @canon_cache[current_id][current_form]; next if !data
          if line[/^BaseStats\s*=\s*(.*)$/i]
            data[:stats] = $1.strip.split(",").map { |s| s.strip.to_i }
          elsif line[/^Abilities\s*=\s*(.*)$/i]
            data[:abilities] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^HiddenAbilit(?:y|ies)\s*=\s*(.*)$/i]
            data[:hidden_abilities] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^Types\s*=\s*(.*)$/i]
            data[:types] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^Moves\s*=\s*(.*)$/i]
            m_data = $1.strip.split(","); list = []
            m_data.each_with_index { |val, i| list.push(val.strip.to_sym) if i.odd? }
            data[:level_moves] = list
          elsif line[/^TutorMoves\s*=\s*(.*)$/i]
            data[:tutor_moves] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^EggMoves\s*=\s*(.*)$/i]
            data[:egg_moves] = $1.strip.split(",").map { |s| s.strip.to_sym }
          elsif line[/^Evolutions\s*=\s*(.*)$/i]
            evo_parts = $1.strip.split(",").map { |s| s.strip }
            evos = []
            evo_parts.each_slice(3) do |species_str, method_str, param_str|
              next if species_str.nil? || species_str.empty?
              method = (method_str.nil? || method_str.empty?) ? :None : method_str.to_sym
              evos.push([species_str.to_sym, method, param_str])
            end
            data[:evolutions] = evos
          end
        end
      end
    end
  end

  def self.get_canon_info(species, form)
    load_canon_data if @canon_cache.empty?
    return nil if !@canon_cache[species]
    return nil if form > 0 && !@canon_cache[species][form]
    base = @canon_cache[species][0]; this = @canon_cache[species][form]; res = {}
    res[:stats] = (!this[:stats].empty?) ? this[:stats] : base[:stats]
    res[:types] = (!this[:types].empty?) ? this[:types] : base[:types]
    res[:abilities] = (!this[:abilities].empty?) ? this[:abilities] : base[:abilities]
    res[:hidden_abilities] = (!this[:hidden_abilities].empty?) ? this[:hidden_abilities] : base[:hidden_abilities]
    res[:level_moves] = (!this[:level_moves].empty?) ? this[:level_moves] : base[:level_moves]
    res[:tutor_moves] = (!this[:tutor_moves].empty?) ? this[:tutor_moves] : (base ? base[:tutor_moves] : [])
    res[:egg_moves]   = (!this[:egg_moves].empty?) ? this[:egg_moves] : (base ? base[:egg_moves] : [])
    res[:evolutions]  = (!this[:evolutions].empty?) ? this[:evolutions] : (base ? base[:evolutions] : [])
    return res
  end

  def self.canon_known_moves
    load_canon_data if @canon_cache.empty?
    pool = []
    @canon_cache.each_value do |forms|
      next if !forms
      forms.each_value do |data|
        next if !data
        pool.concat(data[:level_moves] || [])
        pool.concat(data[:tutor_moves] || [])
        pool.concat(data[:egg_moves] || [])
      end
    end
    return pool.compact.uniq
  end

  def self.canon_known_abilities
    load_canon_data if @canon_cache.empty?
    pool = []
    @canon_cache.each_value do |forms|
      next if !forms
      forms.each_value do |data|
        next if !data
        pool.concat(data[:abilities] || [])
        pool.concat(data[:hidden_abilities] || [])
      end
    end
    return pool.compact.reject { |a| a == :NONE }.uniq
  end

  def self.load_canon_move_data
    return if !@canon_move_data.nil?
    @canon_move_data = {}
    canon_move_paths = []
    canon_move_paths.concat(Dir.glob("CanonData/moves*.txt"))
    canon_move_paths.concat(["CanonData/moves.txt", "CanonData/moves_Gen_9_Pack.txt", "CanonData/moves_LetsGo.txt"])
    canon_move_paths = canon_move_paths.compact.uniq
    canon_move_paths.each do |path|
      resolved = resolve_existing_path(path)
      next if !resolved
      current_id = nil
      File.open(resolved, "r:utf-8") do |f|
        f.each_line do |line|
          clean = line.to_s.strip.split("#")[0]
          next if clean.nil? || clean.empty?
          if clean[/^\[([^\]]+)\]$/]
            current_id = $1.strip.to_sym
            @canon_move_data[current_id] ||= {
              :type => nil,
              :dmg_class => nil,
              :power => nil,
              :accuracy => nil,
              :total_pp => nil,
              :priority => nil,
              :function => nil,
              :effect_chance => nil,
              :flags => []
            }
            next
          end
          next if current_id.nil?
          if clean[/^Type\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:type] = $1.strip.to_sym
          elsif clean[/^Category\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:dmg_class] = $1.to_s.strip.downcase.to_sym
          elsif clean[/^Power\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:power] = $1.to_s.strip.to_i
          elsif clean[/^Accuracy\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:accuracy] = $1.to_s.strip.to_i
          elsif clean[/^TotalPP\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:total_pp] = $1.to_s.strip.to_i
          elsif clean[/^Priority\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:priority] = $1.to_s.strip.to_i
          elsif clean[/^FunctionCode\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:function] = $1.to_s.strip
          elsif clean[/^EffectChance\s*=\s*(.*)$/i]
            @canon_move_data[current_id][:effect_chance] = $1.to_s.strip.to_i
          elsif clean[/^Flags\s*=\s*(.*)$/i]
            flags = $1.to_s.split(",").map { |s| s.to_s.strip }.reject { |s| s.empty? }
            @canon_move_data[current_id][:flags] = flags
          end
        end
      end
    end
  end

  def self.canon_move_type(move_id)
    load_canon_move_data
    data = @canon_move_data[move_id]
    return nil if !data
    return data[:type]
  end

  def self.canon_move_entry(move_id)
    load_canon_move_data
    return @canon_move_data[move_id]
  end

  def self.canon_move_flags(move_id)
    load_canon_move_data
    data = @canon_move_data[move_id]
    return [] if !data
    return data[:flags] || []
  end

  def self.resolve_existing_path(path)
    candidates = [
      path,
      File.join(".", path),
      File.join("..", path),
      File.join("..", "..", path)
    ].uniq
    candidates.each do |p|
      return p if File.file?(p)
    end
    return nil
  end

  def self.read_ids_from_pbs(path)
    ids = []
    resolved = resolve_existing_path(path)
    return ids if !resolved
    File.open(resolved, "r:utf-8") do |f|
      f.each_line do |line|
        next if !line
        clean = line.strip
        next if clean.empty?
        next if clean.start_with?("#")
        if clean[/^\[([^\]]+)\]$/]
          ids << $1.strip.to_sym
        end
      end
    end
    return ids.uniq
  rescue StandardError
    return []
  end

  def self.custom_move_ids
    if @custom_move_ids.nil?
      @custom_move_ids = read_ids_from_pbs("PBS/moves_Vermeil.txt")
    end
    return @custom_move_ids
  end

  def self.custom_ability_ids
    if @custom_ability_ids.nil?
      @custom_ability_ids = read_ids_from_pbs("PBS/abilities_Vermeil.txt")
    end
    return @custom_ability_ids
  end

  def self.reworked_abilities
    return REWORKED_ABILITIES
  end

  def self.reworked_ability_before_text(ability_id)
    return REWORKED_ABILITY_BEFORE_TEXT[ability_id]
  end

  def self.torque_move?(move_id)
    return TORQUE_MOVE_IDS.include?(move_id)
  end

  def self.reworked_move_before_text(move_id)
    return "Starmobile-exclusive move." if torque_move?(move_id)
    return "Let's Go-exclusive move." if LETSGO_EXCLUSIVE_MOVE_IDS.include?(move_id)
    return nil
  end
end