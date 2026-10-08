module PBSChanges
  CHANGES_DIR = "Plugins/Carnek Project Settings/PBS Changes"
  MODIFIED_SPECIES = []
  AUDIT = {}
  @snapshot = nil
  class << self; attr_reader :snapshot; end

  def self.discover_namespaces
    return [] if !File.directory?(CHANGES_DIR)
    Dir.children(CHANGES_DIR).select { |d| File.directory?(File.join(CHANGES_DIR, d)) }.sort
  end

  def self.namespace_paths
    discover_namespaces.map { |ns| "#{CHANGES_DIR}/#{ns}" }
  end

  def self.apply
    MODIFIED_SPECIES.clear
    AUDIT.clear
    snapshot = { species: {}, moves: {}, abilities: {} }
    GameData::Species.each_species { |s| snapshot[:species][s.id] = Marshal.dump(s.instance_variables.map { |iv| [iv, s.instance_variable_get(iv)] }.to_h) }
    GameData::Move.each         { |m| snapshot[:moves][m.id]     = Marshal.dump(m.instance_variables.map { |iv| [iv, m.instance_variable_get(iv)] }.to_h) }
    GameData::Ability.each      { |a| snapshot[:abilities][a.id] = Marshal.dump(a.instance_variables.map { |iv| [iv, a.instance_variable_get(iv)] }.to_h) }
    apply_ability_changes
    apply_move_changes
    apply_species_changes
    build_audit(snapshot)
    @snapshot = snapshot
  end

  def self.suffix_files(glob)
    Dir.glob(glob).select { |f| File.file?(f) }
  end

  #---------------------------------------------------------------------------
  # Species handler
  #---------------------------------------------------------------------------
  FIELD_MAP = {
    "Name"             => { iv: :@real_name,             type: :string },
    "Types"            => { iv: :@types,                 type: :symlist },
    "BaseStats"        => { iv: :@base_stats,            type: :stats },
    "GenderRatio"      => { iv: :@gender_ratio,          type: :symbol },
    "GrowthRate"       => { iv: :@growth_rate,           type: :symbol },
    "BaseExp"          => { iv: :@base_exp,              type: :posint },
    "EVs"              => { iv: :@evs,                   type: :evs },
    "CatchRate"        => { iv: :@catch_rate,            type: :uint },
    "Happiness"        => { iv: :@happiness,             type: :uint },
    "Abilities"        => { iv: :@abilities,             type: :symlist },
    "HiddenAbilities"  => { iv: :@hidden_abilities,      type: :symlist },
    "Moves"            => { iv: :@moves,                 type: :movelist },
    "TutorMoves"       => { iv: :@tutor_moves,           type: :symlist },
    "EggMoves"         => { iv: :@egg_moves,             type: :symlist },
    "EggGroups"        => { iv: :@egg_groups,            type: :symlist },
    "HatchSteps"       => { iv: :@hatch_steps,           type: :posint },
    "Incense"          => { iv: :@incense,               type: :symbol },
    "Height"           => { iv: :@height,                type: :height },
    "Weight"           => { iv: :@weight,                type: :weight },
    "Color"            => { iv: :@color,                 type: :symbol },
    "Shape"            => { iv: :@shape,                 type: :symbol },
    "Habitat"          => { iv: :@habitat,               type: :symbol },
    "Category"         => { iv: :@real_category,         type: :string },
    "Pokedex"          => { iv: :@real_pokedex_entry,    type: :string },
    "Generation"       => { iv: :@generation,            type: :int },
    "Flags"            => { iv: :@flags,                 type: :strlist },
    "WildItemCommon"   => { iv: :@wild_item_common,      type: :symlist },
    "WildItemUncommon" => { iv: :@wild_item_uncommon,    type: :symlist },
    "WildItemRare"     => { iv: :@wild_item_rare,        type: :symlist },
    "Evolution"        => { iv: :@evolutions,            type: :evolution },
    "Evolutions"       => { iv: :@evolutions,            type: :evolutions },
    "HideFromDex"      => { iv: :@hide_from_dex,         type: :bool }
  }

  def self.parse_val(raw, type)
    case type
    when :string  then raw
    when :symbol  then raw.to_sym
    when :symlist then raw.split(",").map(&:strip).reject(&:empty?).map(&:to_sym)
    when :strlist then raw.split(",").map(&:strip).reject(&:empty?)
    when :int     then raw.to_i
    when :posint  then [raw.to_i, 1].max
    when :uint    then [raw.to_i, 0].max
    when :bool    then %w[true 1 yes].include?(raw.downcase)
    when :height  then (raw.to_f * 10).round
    when :weight  then (raw.to_f * 10).round
    when :stats
      vals = raw.split(",").map(&:strip).map(&:to_i)
      order = [:HP, :ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE]
      h = {}
      order.each_with_index { |s, i| h[s] = vals[i] if i < vals.length }
      GameData::Stat.each_main { |s| h[s.id] = 1 if !h[s.id] || h[s.id] <= 0 }
      h
    when :evs
      parts = raw.split(",").map(&:strip)
      h = {}
      parts.each_slice(2) { |stat, val| h[stat.to_sym] = val.to_i }
      GameData::Stat.each_main { |s| h[s.id] = 0 if !h[s.id] }
      h
    when :movelist
      parts = raw.split(",").map(&:strip)
      parts.each_slice(2).map { |lvl, move| [lvl.to_i, move.to_sym] }
    when :evolution
      parts = raw.split(",").map(&:strip)
      return nil if parts.length < 2
      target = parts[0].to_sym
      meth   = parts[1].to_sym
      param  = parts[2]
      param  = param.to_i if param && param[/^\d+$/]
      [target, meth, param, false]
    when :evolutions
      parts = raw.split(",").map(&:strip)
      parts.each_slice(3).map { |t, m, p|
        p = p.to_i if p && p[/^\d+$/]
        [t.to_sym, m.to_sym, p, false]
      }
    end
  end

  def self.apply_species_changes
    files = []
    roots = [CHANGES_DIR] + namespace_paths
    roots.each do |root|
      f = "#{root}/pokemon.txt"
      files << f if FileTest.exist?(f)
    end
    suffix_files("PBS/pokemon_*.txt").each do |f|
      next if f == "PBS/pokemon.txt"
      files << f
    end
    return if files.empty?

    files.each do |file|
      echoln("PBS Changes [pokemon]: leyendo #{file}")
      species = nil
      changes = {}
      Compiler.pbCompilerEachPreppedLine(file) do |line, line_no|
        if line[/^\s*\[(\w+)\]\s*$/]
          apply_species(species, changes) if species
          species = $~[1].to_sym
          changes = {}
          next
        end
        next if species.nil?
        next if !line[/^\s*(\w+)\s*=\s*(.*\S)\s*$/]
        changes[$~[1]] = $~[2]
      end
      apply_species(species, changes) if species
    end
  end

  def self.apply_ability_changes
    files = []
    roots = [CHANGES_DIR] + namespace_paths
    roots.each do |root|
      f = "#{root}/abilities.txt"
      files << f if FileTest.exist?(f)
    end
    suffix_files("PBS/abilities_*.txt").each do |f|
      next if f == "PBS/abilities.txt"
      files << f
    end
    return if files.empty?

    files.each do |file|
      ab_id = nil
      ab_data = {}
      Compiler.pbCompilerEachPreppedLine(file) do |line, line_no|
        if line[/^\s*\[(\w+)\]\s*$/]
          apply_ability(ab_id, ab_data) if ab_id
          ab_id = $~[1].to_sym
          ab_data = { id: ab_id }
          next
        end
        next if ab_id.nil?
        next if !line[/^\s*(\w+)\s*=\s*(.*\S)\s*$/]
        key = $~[1]; val = $~[2]
        case key
        when "Name"        then ab_data[:real_name] = val
        when "Description" then ab_data[:real_description] = val
        when "Flags"       then ab_data[:flags] = val.split(",").map(&:strip).reject(&:empty?)
        when "PBSFileSuffix" then ab_data[:pbs_file_suffix] = val
        end
      end
      apply_ability(ab_id, ab_data) if ab_id
    end
  end

  def self.apply_ability(ab_id, data)
    return if data.empty? || data.keys == [:id]
    existing = GameData::Ability.try_get(ab_id)
    if existing
      data.each do |k, v|
        existing.instance_variable_set(:"@#{k}", v) if k != :id
      end
      echoln("PBS Changes [abilities]: actualizado #{ab_id}")
    else
      data[:pbs_file_suffix] ||= ""
      GameData::Ability.register(data)
      echoln("PBS Changes [abilities]: registrado nuevo #{ab_id}")
    end
  end

  def self.apply_species(sym, changes)
    if sym.nil?
      echoln("PBS Changes [pokemon]: sym es nil, salteando")
      return
    end
    if changes.empty?
      echoln("PBS Changes [pokemon]: #{sym} no tiene changes, salteando")
      return
    end
    MODIFIED_SPECIES << sym unless MODIFIED_SPECIES.include?(sym)
    sp = GameData::Species.try_get(sym)
    if sp.nil?
      echoln("PBS Changes [pokemon]: NO ENCONTRÉ #{sym} en GameData")
      return
    end
    echoln("PBS Changes [pokemon]: aplicando cambios a #{sym} (#{changes.keys.length} campos)")

    applied = []
    changes.each do |field, raw|
      cfg = FIELD_MAP[field]
      next if cfg.nil?

      begin
        if cfg[:type] == :evolution
          evo = parse_val(raw, :evolution)
          next if evo.nil?
          base = sp.evolutions.dup
          base.reject! { |e| e[0] == evo[0] }
          base.push(evo)
          sp.instance_variable_set(:@evolutions, base)
        elsif cfg[:type] == :evolutions
          sp.instance_variable_set(:@evolutions, parse_val(raw, :evolutions))
        else
          sp.instance_variable_set(cfg[:iv], parse_val(raw, cfg[:type]))
        end
        applied << field
      rescue => e
        echoln("PBS Changes [pokemon]: error en #{sym} campo #{field}: #{e.message}")
      end
    end

    echoln("PBS Changes [pokemon]: #{sym} -> #{applied.join(', ')}") if !applied.empty?
  end

  def self.build_audit(snapshot)
    GameData::Species.each_species { |s|
      old = snapshot[:species][s.id]
      new = snapshot_hash(s)
      AUDIT[s.id] = { species: true } if old != new
    }
    GameData::Move.each { |m|
      old = snapshot[:moves][m.id]
      new = snapshot_hash(m)
      AUDIT[m.id] = { move: true } if old != new
    }
    GameData::Ability.each { |a|
      old = snapshot[:abilities][a.id]
      new = snapshot_hash(a)
      AUDIT[a.id] = { ability: true } if old != new
    }
    echoln("PBS Changes / PBS Vanilla Delta: #{AUDIT.length} entradas modificadas")
  end

  def self.snapshot_hash(obj)
    Marshal.dump(obj.instance_variables.map { |iv| [iv, obj.instance_variable_get(iv)] }.to_h)
  end

  #---------------------------------------------------------------------------
  # Move handler
  #---------------------------------------------------------------------------
  MOVE_FIELDS = {
    "Name"         => :real_name,
    "Type"         => :type,
    "Category"     => :category,
    "Power"        => :power,
    "Accuracy"     => :accuracy,
    "TotalPP"      => :total_pp,
    "Target"       => :target,
    "Priority"     => :priority,
    "FunctionCode" => :function_code,
    "Flags"        => :flags,
    "EffectChance" => :effect_chance,
    "Description"  => :real_description
  }

  def self.apply_move_changes
    files = []
    roots = [CHANGES_DIR] + namespace_paths
    roots.each do |root|
      f = "#{root}/moves.txt"
      files << f if FileTest.exist?(f)
    end
    suffix_files("PBS/moves_*.txt").each do |f|
      next if f == "PBS/moves.txt"
      files << f
    end
    return if files.empty?

    files.each do |file|
      move_id = nil
      data = {}
      Compiler.pbCompilerEachPreppedLine(file) do |line, line_no|
        if line[/^\s*\[(\w+)\]\s*$/]
          apply_move(move_id, data) if move_id
          move_id = $~[1].to_sym
          data = { id: move_id }
          next
        end
        next if move_id.nil?
        next if !line[/^\s*(\w+)\s*=\s*(.*\S)\s*$/]
        key = $~[1]
        val = $~[2]
        case key
        when "Name"         then data[:real_name] = val
        when "Type"         then data[:type] = val.to_sym
        when "Category"     then data[:category] = %w[Physical Special Status].index(val) || 2
        when "Power"        then data[:power] = val.to_i
        when "Accuracy"     then data[:accuracy] = val.to_i
        when "TotalPP"      then data[:total_pp] = val.to_i
        when "Target"       then data[:target] = val.to_sym
        when "Priority"     then data[:priority] = val.to_i
        when "FunctionCode" then data[:function_code] = val
        when "Flags"        then data[:flags] = val.split(",").map(&:strip).reject(&:empty?)
        when "EffectChance" then data[:effect_chance] = val.to_i
        when "Description"  then data[:real_description] = val
        end
      end
      apply_move(move_id, data) if move_id
    end
  end

  def self.apply_move(move_id, data)
    existing = GameData::Move.try_get(move_id)
    if existing
      data.each do |key, val|
        existing.instance_variable_set(:"@#{key}", val) if key != :id
      end
      echoln("PBS Changes [moves]: actualizado #{move_id}")
    else
      data[:pbs_file_suffix] ||= ""
      GameData::Move.register(data)
      echoln("PBS Changes [moves]: registrado nuevo #{move_id}")
    end
  end
end

EventHandlers.add(:on_game_initialize, :apply_pbs_changes, proc {
  PBSChanges.apply
  if defined?(ChangeDex::Core)
    ChangeDex::Core.load_canon_from_snapshot(PBSChanges.snapshot)
    echoln("PBS Changes / ChangeDex canon desde snapshot (#{PBSChanges.snapshot[:species].length} species, #{PBSChanges.snapshot[:moves].length} moves)")
  end
})
