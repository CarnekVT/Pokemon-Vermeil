# frozen_string_literal: true
# Bifrost Capture 1.0 - rules, registration, geometry, no UI or engine overrides.
module BifrostCapture
  CONFIG_PATH = "Plugins/[VERMEIL] Bifrost Capture/config.ini"
  ROSTER_PATH = "Plugins/[VERMEIL] Bifrost Capture/roster.ini"
  DIR = { 2 => [0,1], 4 => [-1,0], 6 => [1,0], 8 => [0,-1] }.freeze
  LEGENDARIES = %w[
    RAIKOU ENTEI SUICUNE LATIAS LATIOS ARTICUNO ZAPDOS MOLTRES
    UXIE MESPRIT AZELF COBALION TERRAKION VIRIZION GENESECT
    LANDORUS TORNADUS THUNDURUS ETERNATUS TAPUKOKO TAPULELE
    TAPUBULU TAPUFINI
  ].freeze
  DEFAULTS = {
    "profile"=>"bifrost", "enabled"=>"1",
    "access_mode"=>"always", "hotkey"=>"aux2", "control_mode"=>"hold",
    "capture_enabled"=>"1", "battle_enabled"=>"1", "restricted_species"=>"1",
    "encounter_mode"=>"classic", "spawn_chance"=>"50",
    "spawn_min_distance"=>"3", "spawn_max_distance"=>"6", "spawn_limit"=>"5",
    "spawn_lifetime"=>"45", "spawn_filter"=>"all", "spawn_grass_only"=>"1",
    "spawn_allow_fishing"=>"0", "ow_form"=>"0", "ow_min_level"=>"0",
    "ow_max_level"=>"0", "ow_spawn_probability"=>"100",
    "range"=>"7", "width"=>"7", "optimal_range"=>"4", "alert_distance"=>"3",
    "hit_near"=>"100", "hit_far"=>"60", "capture_floor"=>"10",
    "back_multiplier"=>"175", "critical_front"=>"3", "critical_back"=>"35",
    "critical_multiplier"=>"250", "line_of_sight"=>"1",
    "reaction"=>"flee", "consume_on_miss"=>"1", "allow_empty_throw"=>"0",
    "impact_frames"=>"3", "capture_shakes"=>"3", "capture_shake_frames"=>"10",
    "aim_keyboard"=>"1", "aim_speed"=>"5", "aim_mouse"=>"1",
    "aim_target_radius"=>"30", "throw_frames"=>"18", "throw_arc"=>"36",
    "aim_chain"=>"0", "flee_steps"=>"5", "flee_speed"=>"4",
    "flee_disappear_distance"=>"9", "flee_stuck_frames"=>"90",
    "alert_on_miss"=>"1", "attempt_limit"=>"0",
    "instant_modifier"=>"100",
    "feedback_enabled"=>"1", "feedback_frames"=>"150",
    "feedback_sfx"=>"1", "capture_fx"=>"1"
  }.freeze
  PROFILES = {
    "bifrost"=>{},
    "classic"=>{"capture_enabled"=>"0","encounter_mode"=>"classic"},
    "adventure"=>{"restricted_species"=>"0","reaction"=>"attack"},
    "safari"=>{"restricted_species"=>"0","battle_enabled"=>"0"},
    "full_ow"=>{"restricted_species"=>"0","access_mode"=>"always",
                  "encounter_mode"=>"overworld"},
    "custom"=>{}
  }.freeze

  def self.read_ini(path, allowed_sections)
    sections = {}
    section = allowed_sections.first
    sections[section] = {}
    begin
      File.foreach(path) do |line|
        line = line.sub(/[;#].*$/, "").strip
        next if line.empty?
        if line =~ /\A\[([^\]]+)\]\z/
          candidate = $1.downcase
          section = candidate if allowed_sections.include?(candidate) ||
            candidate =~ /\A(map:\d+|species:[a-z0-9_]+|event:\d+:\d+)\z/
          sections[section] ||= {}
        elsif line =~ /\A([a-z0-9_]+)\s*=\s*([a-z0-9_]+)\z/i
          sections[section][$1.downcase] = $2.downcase
        end
      end
    rescue Errno::ENOENT, Errno::EACCES
    end
    sections
  end

  def self.reload!
    @config = nil
    @roster = nil
    @config_time = nil
    @roster_time = nil
  end

  def self.config
    stamp = (File.mtime(CONFIG_PATH) rescue nil)
    return @config if @config && @config_time == stamp
    @config = read_ini(CONFIG_PATH, ["global"])
    @config_time = stamp
    @config
  end

  def self.roster
    stamp = (File.mtime(ROSTER_PATH) rescue nil)
    return @roster if @roster && @roster_time == stamp
    data = read_ini(ROSTER_PATH, ["bifrost","spawn","blocked"])
    data["bifrost"] ||= {}
    data["spawn"] ||= {}
    data["blocked"] ||= {}
    if stamp.nil?
      LEGENDARIES.each { |sp| data["bifrost"][sp.downcase] = "1" }
    end
    @roster_time = stamp
    @roster = data
  end

  def self.options(map_id = nil, species = nil, event_id = nil)
    map_id ||= $game_map.map_id if defined?($game_map) && $game_map
    data = config
    global = data["global"] || {}
    profile = global.fetch("profile","bifrost")
    result = DEFAULTS.merge(PROFILES[profile] || {})
    global.each do |key, value|
      next unless DEFAULTS.key?(key)
      # Existing INI files contain all default keys; profile should still
      # control an unchanged value, while a customized value has priority.
      preset = (PROFILES[profile] || {})[key]
      next if preset && value == DEFAULTS[key]
      result[key] = value
    end
    result.merge!(data["map:#{map_id}"] || {}) if map_id
    result.merge!(data["species:#{species.to_s.downcase}"] || {}) if species
    result.merge!(data["event:#{map_id}:#{event_id}"] || {}) if map_id && event_id
    if defined?($PokemonGlobal) && $PokemonGlobal &&
       $PokemonGlobal.respond_to?(:bifrost_overrides)
      result.merge!($PokemonGlobal.bifrost_overrides || {})
    end
    result
  end

  def self.overworld_encounters?(cfg = options)
    cfg["enabled"] == "1" && ["overworld","hybrid"].include?(cfg["encounter_mode"])
  end

  def self.allow_species?(species,cfg)
    return true if cfg["restricted_species"] != "1"
    roster["bifrost"][species.to_s.downcase] == "1"
  end

  def self.spawn_species?(species,cfg)
    key = species.to_s.downcase
    return false if roster["blocked"][key] == "1"
    cfg["spawn_filter"] != "allowlist" || roster["spawn"][key] == "1"
  end

  def self.event_spec(event)
    return nil unless event && event.respond_to?(:name)
    return nil if event.name.to_s =~ /\[OWDECOR\]/i
    meta = event.instance_variable_get(:@bifrost_capture_spec)
    if meta.is_a?(Array) && meta.length >= 2
      sp, lv, form = meta
      return [sp.to_sym,lv.to_i,form.to_i] if GameData::Species.exists?(sp.to_sym)
    end
    match = /\[OWCAP:([A-Z0-9_]+):(\d+)(?::(\d+))?\]/i.match(event.name.to_s)
    return nil unless match
    species = match[1].upcase.to_sym
    return nil unless GameData::Species.exists?(species)
    [species,match[2].to_i,(match[3] || 0).to_i]
  end

  def self.register_ow(event,species,level,form=0)
    return false unless event && event.respond_to?(:name) &&
                        event.name !~ /\[OWDECOR\]/i &&
                        GameData::Species.exists?(species.to_sym)
    event.instance_variable_set(:@bifrost_capture_spec,
      [species.to_sym, [level.to_i,1].max,form.to_i])
    true
  end

  def self.valid_target?(event)
    spec = event_spec(event)
    return false unless spec && !event.instance_variable_get(:@erased)
    return false if event.respond_to?(:transparent) && event.transparent
    return false if event.respond_to?(:character_name) &&
                    event.character_name.to_s.empty?
    cfg = options($game_map.map_id,spec[0],event.id)
    return false if cfg["enabled"] != "1"
    # All naturally-generated OWs are capturable in full OW mode, even when
    # the project also restricts manual legendary encounters to its roster.
    return true if event.instance_variable_get(:@bifrost_generated) &&
                   cfg["encounter_mode"] == "overworld" &&
                   spawn_species?(spec[0],cfg)
    allow_species?(spec[0],cfg)
  end

  def self.offset(px,py,dir,forward,side)
    x,y = DIR[dir] || DIR[8]
    [px+x*forward-y*side,py+y*forward+x*side]
  end

  def self.relative(px,py,dir,tx,ty)
    x,y = DIR[dir] || DIR[8]
    dx,dy = tx-px,ty-py
    [dx*x+dy*y,-dx*y+dy*x]
  end

  def self.geometry(px,py,tx,ty,cfg)
    dx,dy = tx-px,ty-py
    direction = (dx.abs > dy.abs) ? (dx < 0 ? 4 : 6) : (dy < 0 ? 8 : 2)
    front,side = relative(px,py,direction,tx,ty)
    {
      :direction=>direction, :front=>front, :side=>side,
      :in_range=>front.between?(1,[cfg["range"].to_i,1].max) &&
         side.abs <= [cfg["width"].to_i,1].max/2
    }
  end

  def self.behind?(px,py,event)
    x,y = DIR[event.direction] || DIR[2]
    (px-event.x)*x+(py-event.y)*y < 0
  end

  def self.hit_chance(distance,cfg)
    far = [cfg["range"].to_i,1].max
    optimum = cfg["optimal_range"].to_i.clamp(1,far)
    return 0.0 unless distance.between?(1,far)
    near_chance = cfg["hit_near"].to_f/100.0
    far_chance = cfg["hit_far"].to_f/100.0
    return near_chance.clamp(0.0,1.0) if distance <= optimum
    (near_chance+(far_chance-near_chance)*(distance-optimum).to_f/
      [far-optimum,1].max).clamp(0.0,1.0)
  end

  def self.line_clear?(px,py,tx,ty)
    # Check map passability and solid events BETWEEN thrower and target.
    dx=(tx-px).abs;dy=(ty-py).abs
    sx=px<tx ? 1 : -1;sy=py<ty ? 1 : -1
    x=px;y=py;err=dx-dy
    until x==tx && y==ty
      ox,oy=x,y;e2=2*err
      if e2 > -dy then err-=dy;x+=sx end
      if e2 < dx then err+=dx;y+=sy end
      return false unless $game_map.valid?(x,y)
      break if x==tx && y==ty
      h=x>ox ? 6 : 4
      v=y>oy ? 2 : 8
      dirs=(x!=ox && y!=oy) ? [h,v] : [x!=ox ? h : v]
      return false unless dirs.all? { |direction| $game_map.passable?(ox,oy,direction) }
      return false if $game_map.events.values.any? { |e|
        e.x==x && e.y==y && !e.through && !e.instance_variable_get(:@erased)
      }
    end
    true
  end

  def self.hotkey
    case options["hotkey"]
    when "aux1" then Input::AUX1
    when "aux2" then Input::AUX2
    end
  end

  def self.notice(message)
    @notice = message
    @notice_timer = 80
  end

  def self.take_notice
    if @notice_timer.to_i > 0
      @notice_timer -= 1
      @notice
    else
      nil
    end
  end
end

class PokemonGlobalMetadata
  attr_accessor :bifrost_overrides, :bifrost_removed_events
end
