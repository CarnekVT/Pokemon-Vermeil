# frozen_string_literal: true
# Bifrost Capture - core independiente de la escena y Maker Studio (Essentials 21.1)
module BifrostCapture
  PATH = "Plugins/[VERMEIL] Bifrost Capture/config.ini"
  DEFAULTS = {
    "profile"=>"bifrost", "enabled"=>"1", "capture_enabled"=>"1",
    "battle_enabled"=>"1", "restricted_species"=>"1", "range"=>"7",
    "width"=>"7", "optimal_range"=>"4", "alert_distance"=>"3",
    "hit_near"=>"96", "hit_far"=>"60", "capture_floor"=>"10",
    "back_multiplier"=>"175", "critical_front"=>"3",
    "critical_back"=>"35", "critical_multiplier"=>"250",
    "line_of_sight"=>"1", "reaction"=>"flee", "consume_on_miss"=>"1",
    "impact_frames"=>"3",
    "access_mode"=>"event", "hotkey"=>"aux2",
    "encounter_mode"=>"classic", "spawn_chance"=>"24",
    "spawn_min_distance"=>"3", "spawn_max_distance"=>"6",
    "spawn_limit"=>"4", "spawn_lifetime"=>"40", "spawn_filter"=>"all",
    "spawn_grass_only"=>"1", "spawn_allow_fishing"=>"0",
    "ow_form"=>"0", "ow_min_level"=>"0", "ow_max_level"=>"0",
    "ow_spawn_probability"=>"100"
  }.freeze
  ROAMERS = %w[RAIKOU SUICUNE ENTEI LATIAS LATIOS ARTICUNO ZAPDOS MOLTRES
               MESPRIT UXIE AZELF COBALION VIRIZION TERRAKION GENESECT
               LANDORUS THUNDURUS TORNADUS ETERNATUS TAPUKOKO TAPULELE
               TAPUBULU TAPUFINI].freeze
  DIR = { 2=>[0,1], 4=>[-1,0], 6=>[1,0], 8=>[0,-1] }.freeze
  PROFILES = {
    "bifrost"=>{}, "classic"=>{"capture_enabled"=>"0", "battle_enabled"=>"1"},
    "adventure"=>{"restricted_species"=>"0", "reaction"=>"attack"},
    "safari"=>{"restricted_species"=>"0", "battle_enabled"=>"0",
               "reaction"=>"flee"},
    "full_ow"=>{"restricted_species"=>"0", "access_mode"=>"always",
               "encounter_mode"=>"overworld", "spawn_filter"=>"all"},
    "custom"=>{}
  }.freeze

  ROSTER_PATH = "Plugins/[VERMEIL] Bifrost Capture/roster.ini"

  def self.reload!
    @sections = nil
    @mtime = nil
    @roster = nil
    @roster_mtime = nil
  end

  def self.roster
    stamp = begin File.mtime(ROSTER_PATH) rescue nil end
    return @roster if @roster && @roster_mtime == stamp
    sections = {"bifrost" => {}, "spawn" => {}, "blocked" => {}}
    section = "bifrost"
    begin
      File.foreach(ROSTER_PATH) do |raw|
        line = raw.sub(/[;#].*$/, "").strip
        next if line.empty?
        if line =~ /\A\[(bifrost|spawn|blocked)\]\z/i
          section = $1.downcase
        elsif line =~ /\A([A-Za-z0-9_]+)\s*=\s*([01])\z/
          sections[section][$1.upcase] = ($2 == "1")
        end
      end
    rescue Errno::ENOENT, Errno::EACCES
      ROAMERS.each { |species| sections["bifrost"][species] = true }
    end
    @roster_mtime = stamp
    @roster = sections
  end

  def self.spawn_species?(species, config)
    name = species.to_s.upcase
    return false if roster["blocked"][name]
    return true if config["spawn_filter"] != "allowlist"
    roster["spawn"][name] == true
  end


  def self.sections
    stamp = begin File.mtime(PATH) rescue nil end
    return @sections if @sections && @mtime == stamp
    data = {"global"=>DEFAULTS.dup}
    section = "global"
    begin
      File.foreach(PATH) do |line|
        line = line.sub(/[;#].*$/, "").strip
        next if line.empty?
        if line =~ /\A\[(global|map:\d+|species:[a-z0-9_]+|event:\d+:\d+)\]\z/i
          section = $1.downcase
          data[section] ||= {}
        elsif line =~ /\A([a-z_]+)\s*=\s*([a-z0-9_]+)\z/i
          key, val = $1.downcase, $2.downcase
          data[section][key] = val if DEFAULTS.key?(key)
        end
      end
    rescue Errno::ENOENT, Errno::EACCES
    end
    @mtime = stamp
    @sections = data
  end

  def self.options(map_id = nil, species = nil, event_id = nil)
    map_id ||= $game_map.map_id if defined?($game_map) && $game_map
    data = sections
    base = data["global"].dup
    profile = base["profile"]
    result = DEFAULTS.merge(PROFILES[profile] || {}).merge(base)
    # Los perfiles rapidos se aplican a las claves no personalizadas del INI.
    (PROFILES[profile] || {}).each do |key, val|
      result[key] = val if base[key] == DEFAULTS[key]
    end
    keys = []
    keys << "species:#{species.to_s.downcase}" if species
    keys << "map:#{map_id}" if map_id
    keys << "event:#{map_id}:#{event_id}" if map_id && event_id
    keys.each { |key| result.merge!(data[key]) if data[key] }
    if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.bifrost_overrides
      result.merge!($PokemonGlobal.bifrost_overrides)
    end
    result
  end

  # "event": apertura mediante pbBifrostAim desde un evento u objeto.
  # "always": tecla disponible en cualquier mapa jugable, con o sin objetivo.
  # "nearby": tecla disponible solo al haber un objetivo OW en la zona frontal.
  def self.overworld_encounters?(cfg = options)
    cfg["enabled"] == "1" && ["overworld", "hybrid"].include?(cfg["encounter_mode"])
  end

  def self.hotkey_code(name)
    case name
    when "aux1" then Input::AUX1 if defined?(Input::AUX1)
    when "aux2" then Input::AUX2 if defined?(Input::AUX2)
    else nil
    end
  end

  def self.can_open_from_map?(cfg)
    return false if !defined?($scene) || !$scene.is_a?(Scene_Map)
    return false if !$game_temp || !$game_player || !$game_map || !$player
    return false if cfg["enabled"] != "1"
    return false if cfg["capture_enabled"] != "1" && cfg["battle_enabled"] != "1"
    return false if $game_temp.in_menu || $game_temp.in_battle ||
                    $game_temp.message_window_showing ||
                    $game_temp.player_transferring ||
                    $game_temp.transition_processing
    return false if $game_player.moving? || $game_player.move_route_forcing
    return false if $PokemonGlobal && $PokemonGlobal.forced_movement?
    return false if pbMapInterpreterRunning?
    true
  end

  def self.target_in_aim_area?(cfg)
    range = [cfg["range"].to_i, 1].max
    width = [cfg["width"].to_i, 1].max
    half = width / 2
    $game_map.events.values.any? do |event|
      next false unless valid_target?(event)
      forward, lateral = relative($game_player.x, $game_player.y,
                                  $game_player.direction, event.x, event.y)
      forward.between?(1, range) && lateral.abs <= half
    end
  end

  def self.update_access
    return if @aim_opening
    cfg = options
    mode = cfg["access_mode"]
    return if mode != "always" && mode != "nearby"
    return unless can_open_from_map?(cfg)
    key = hotkey_code(cfg["hotkey"])
    return if !key || !Input.trigger?(key)
    return if mode == "nearby" && !target_in_aim_area?(cfg)
    begin
      @aim_opening = true
      aim
    ensure
      @aim_opening = false
    end
  end

  def self.allow_species?(species, cfg)
    cfg["restricted_species"] != "1" || roster["bifrost"][species.to_s.upcase] == true
  end

  def self.offset(px, py, facing, forward, side)
    x, y = DIR[facing] || DIR[8]
    [px + x * forward - y * side, py + y * forward + x * side]
  end

  def self.relative(px, py, facing, ex, ey)
    x, y = DIR[facing] || DIR[8]
    dx, dy = ex - px, ey - py
    [dx * x + dy * y, -dx * y + dy * x]
  end

  def self.behind?(px, py, target)
    x, y = DIR[target.direction] || [0,0]
    (px - target.x) * x + (py - target.y) * y < 0
  end

  def self.hit_chance(distance, cfg)
    range = [cfg["range"].to_i,1].max
    optimum = cfg["optimal_range"].to_i.clamp(1,range)
    return 0.0 if distance > range || distance < 1
    near = cfg["hit_near"].to_f / 100.0
    far = cfg["hit_far"].to_f / 100.0
    return near if distance <= optimum
    near + (far-near) * (distance-optimum).to_f / [range-optimum,1].max
  end

  def self.catch_chance(species, ball, distance, behind, critical, cfg)
    data = GameData::Species.get(species)
    rate = data.catch_rate
    ball_bonus = {
      :MASTERBALL=>1000.0, :ULTRABALL=>2.0, :GREATBALL=>1.5,
      :NETBALL=>1.5, :DUSKBALL=>1.5, :QUICKBALL=>1.5,
      :BEASTBALL=>0.1
    }[ball] || 1.0
    optimal = [cfg["optimal_range"].to_i,1].max
    range = [cfg["range"].to_i,optimal].max
    distance_bonus = distance <= optimal ? 1.0 + (optimal-distance)*0.15 :
      1.0 - (distance-optimal)*0.5/[range-optimal,1].max
    base = [rate / 765.0, cfg["capture_floor"].to_f/100.0].max
    bonus = behind ? cfg["back_multiplier"].to_f/100.0 : 1.0
    bonus *= cfg["critical_multiplier"].to_f/100.0 if critical
    (base * ball_bonus * distance_bonus * bonus).clamp(0.0,1.0)
  end

  def self.event_spec(event)
    # Evento: [OWCAP:RAIKOU:50] o [OWDECOR] o [OWCAP:ARTICUNO:70:1]
    return nil unless event && event.respond_to?(:name)
    return nil if event.name =~ /\[OWDECOR\]/i
    match = /\[OWCAP:([A-Z0-9_]+):(\d+)(?::(\d+))?\]/i.match(event.name)
    return nil unless match
    species = match[1].upcase.to_sym
    return nil unless GameData::Species.exists?(species)
    [species, match[2].to_i, (match[3] || "0").to_i]
  end

  def self.removed?(event)
    return false unless defined?($PokemonGlobal) && $PokemonGlobal
    removed = $PokemonGlobal.bifrost_removed_events || {}
    removed[[$game_map.map_id,event.id]] == true
  end

  def self.remove_event(event)
    return discard_generated(event) if generated?(event)
    $PokemonGlobal.bifrost_removed_events ||= {}
    $PokemonGlobal.bifrost_removed_events[[$game_map.map_id,event.id]] = true
    event.erase
  end

  def self.valid_target?(event)
    spec = event_spec(event)
    return false if !spec || removed?(event) || event.instance_variable_get(:@erased)
    cfg = options($game_map.map_id,spec[0],event.id)
    cfg["enabled"] == "1" && allow_species?(spec[0],cfg)
  end

  def self.nearby_target?
    return nil unless $game_map && $game_player
    $game_map.events.values.find { |e| valid_target?(e) }
  end

  def self.line_clear?(px,py,tx,ty)
    # Bresenham y bloqueo por eventos solidos entre origen y objetivo.
    dx=(tx-px).abs; dy=(ty-py).abs
    sx=px<tx ? 1 : -1; sy=py<ty ? 1 : -1
    err=dx-dy; x=px; y=py
    until x==tx && y==ty
      e2=2*err
      if e2 > -dy then err-=dy; x+=sx end
      if e2 < dx then err+=dx; y+=sy end
      break if x==tx && y==ty
      return false unless $game_map.valid?(x,y)
      return false if $game_map.events.values.any? { |e| e.x==x && e.y==y && !e.through && !removed?(e) }
    end
    true
  end

  def self.set_rule(key, value)
    return false unless DEFAULTS.key?(key)
    $PokemonGlobal.bifrost_overrides ||= {}
    $PokemonGlobal.bifrost_overrides[key] = value.to_s
    true
  end
end

class PokemonGlobalMetadata
  attr_accessor :bifrost_overrides
  attr_accessor :bifrost_removed_events
end
