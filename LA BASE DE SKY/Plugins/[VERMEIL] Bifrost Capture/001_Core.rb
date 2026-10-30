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
    "access_mode"=>"always", "hotkey"=>"jumpup", "control_mode"=>"hold",
    "ball_key"=>"jumpdown", "target_key"=>"none", "mode_key"=>"none",
    "keyboard_target_key"=>"tab", "keyboard_mode_key"=>"e",
    "contextual_mode_toggle"=>"0", "mode_double_tap_frames"=>"0",
    "mouse_wheel_select"=>"1",
    "mouse_right_mode"=>"1", "remember_selection"=>"1",
    "debug_input_guard"=>"1", "allow_shared_bindings"=>"0",
    # Mode change uses an independent key; holding selection never toggles.
    "hud_controls"=>"auto", "hud_controls_intro_frames"=>"150",
    "hud_position"=>"bottom_right", "hud_scale"=>"100",
    "hud_opacity"=>"94", "hud_offset_x"=>"0", "hud_offset_y"=>"0",
    "temperament_indicators"=>"1",
    "capture_enabled"=>"1", "battle_enabled"=>"1", "restricted_species"=>"1",
    "encounter_mode"=>"classic", "spawn_chance"=>"50",
    "spawn_min_distance"=>"3", "spawn_max_distance"=>"6", "spawn_limit"=>"5",
    "spawn_lifetime"=>"45", "spawn_filter"=>"all", "spawn_grass_only"=>"1",
    "ow_extra_spawn_chance"=>"0", "ow_extra_spawn_cooldown"=>"7",
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
    "aim_chain"=>"1", "max_flights"=>"3",
    "throw_cooldown_frames"=>"17",
    "spawn_intro_frames"=>"26", "aggressive_notice_frames"=>"25",
    "aggressive_step_pause"=>"12", "aggressive_attack_windup"=>"24",
    "aggressive_lunge_distance"=>"3", "aggressive_lunge_speed"=>"5",
    "aggressive_charge_steps"=>"2",
    "flee_steps"=>"5", "flee_speed"=>"4",
    "flee_disappear_distance"=>"9", "flee_stuck_frames"=>"90",
    "alert_on_miss"=>"1", "attempt_limit"=>"0",
    "instant_modifier"=>"100",
    "temperament"=>"mixed", "neutral_weight"=>"50", "timid_weight"=>"30",
    "aggressive_weight"=>"20", "timid_alert_distance"=>"4",
    "aggressive_alert_distance"=>"5", "aggressive_attack_distance"=>"1",
    "aggressive_chase_speed"=>"4", "aggressive_level_bonus"=>"2",
    "escape_reaction_enabled"=>"1", "escape_reaction_chance"=>"25",
    "escape_reaction_hp_percent"=>"8", "escape_reaction_windup"=>"30",
    "escape_reaction_recovery"=>"180", "escape_reaction_range"=>"4",
    "feedback_enabled"=>"1", "feedback_frames"=>"150",
    "feedback_enter_frames"=>"12", "feedback_hold_frames"=>"72",
    "feedback_exit_frames"=>"16", "feedback_queue_limit"=>"5",
    "feedback_sfx"=>"1", "capture_fx"=>"1",
    "audio_profile"=>"za_like", "sfx_aim"=>"none", "sfx_switch"=>"none",
    "sfx_mode"=>"none", "sfx_party"=>"none",
    "sfx_lock"=>"none", "sfx_throw"=>"none", "sfx_hit"=>"none",
    "sfx_shake"=>"none", "sfx_caught"=>"none", "sfx_breakout"=>"none",
    "sfx_flee"=>"none", "sfx_alert"=>"none",
    "sfx_critical"=>"none"
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
        elsif line =~ /\A([a-z0-9_]+)\s*=\s*(-?[a-z0-9_]+)\z/i
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
                   (cfg["encounter_mode"] == "overworld" ||
                    event.instance_variable_get(:@bifrost_extra_spawn)) &&
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

  INPUT_ACTIONS = {
    "aux1"=>:AUX1, "aux2"=>:AUX2, "jumpup"=>:JUMPUP,
    "jumpdown"=>:JUMPDOWN, "action"=>:ACTION, "special"=>:SPECIAL,
    "use"=>:USE, "back"=>:BACK
  }.freeze

  def self.input_action(name)
    method_name = INPUT_ACTIONS[name.to_s]
    return nil unless method_name && Input.const_defined?(method_name)
    Input.const_get(method_name)
  end

  # Map audit for Vermeil: SPECIAL is Ready Menu, AUX1 is Turbo,
  # ACTION is running, USE is interaction, BACK is pause and F9 is debug.
  # These cannot be capture shortcuts unless deliberately opted in.
  SAFE_MAP_ACTIONS = %w[jumpup jumpdown].freeze
  RESERVED_MAP_ACTIONS = %w[aux1 aux2 action special use back].freeze

  def self.capture_action(cfg,field)
    name = cfg[field].to_s.downcase
    return nil if name == "none" || name.empty?
    return nil unless INPUT_ACTIONS.key?(name)
    # A legacy 0.9 save may still contain W/AUX2. Never react to W
    # unless the developer explicitly opted into shared bindings.
    return nil if RESERVED_MAP_ACTIONS.include?(name) &&
                  cfg["allow_shared_bindings"] != "1"
    return nil if field != "hotkey" && name == cfg["hotkey"]
    input_action(name)
  end

  def self.hotkey
    capture_action(options,"hotkey")
  end

  # Resolve the current physical label on demand, not at HUD initialization.
  # F1 mappings can change while the game is running. Do not display a
  # guessed physical key if the runtime doesn't expose its bindings.
  def self.action_key_name(action)
    return nil if action.nil?
    if defined?(KeybindingReader) &&
       KeybindingReader.respond_to?(:key_name)
      value = KeybindingReader.key_name(action)
      return value.to_s.strip unless value.nil? || value.to_s.strip.empty?
    end
    if Input.respond_to?(:key_name)
      value = Input.key_name(action)
      return value.to_s.strip unless value.nil? || value.to_s.strip.empty?
    end
    nil
  rescue StandardError
    nil
  end

  def self.binding_name(cfg,field)
    name = cfg[field].to_s.downcase
    return "--" if name == "none" || name.empty?
    action = capture_action(cfg,field)
    return "--" unless action
    # Logical action name, not a potentially outdated physical letter.
    action_key_name(action) || name.upcase
  end

  def self.hud_action_key(name)
    const = { "throw"=>:USE, "cancel"=>:BACK }[name.to_s]
    return nil unless const && Input.const_defined?(const)
    action_key_name(Input.const_get(const)) || const.to_s
  rescue StandardError
    nil
  end

  # Developer commands frequently use CTRL + actions on map. In debug,
  # never intercept a control chord reserved for developer tools.
  def self.debug_input_blocked?(cfg=options)
    cfg["debug_input_guard"] == "1" && defined?($DEBUG) && $DEBUG &&
      Input.const_defined?(:CTRL) && Input.press?(Input::CTRL)
  end

  def self.temperament_for(event,cfg=nil)
    return :neutral unless event
    preset = event.instance_variable_get(:@bifrost_temperament)
    return preset if [:neutral,:timid,:aggressive].include?(preset)
    spec = event_spec(event)
    cfg ||= options($game_map.map_id,spec && spec[0],event.id)
    kind = cfg["temperament"].to_s
    if ["neutral","timid","aggressive"].include?(kind)
      chosen = kind.to_sym
    else
      neutral = cfg["neutral_weight"].to_i.clamp(0,100)
      timid = cfg["timid_weight"].to_i.clamp(0,100)
      aggressive = cfg["aggressive_weight"].to_i.clamp(0,100)
      total = neutral+timid+aggressive
      roll = total > 0 ? rand(total) : 0
      chosen = total == 0 || roll < neutral ? :neutral :
               roll < neutral+timid ? :timid : :aggressive
    end
    event.instance_variable_set(:@bifrost_temperament,chosen)
    chosen
  end

  def self.temperament_label(kind)
    { :neutral=>"NEUTRO", :timid=>"MIEDOSO",
      :aggressive=>"AGRESIVO" }[kind] || "NEUTRO"
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
  attr_accessor :bifrost_last_ball, :bifrost_last_party_index, :bifrost_last_mode
end
