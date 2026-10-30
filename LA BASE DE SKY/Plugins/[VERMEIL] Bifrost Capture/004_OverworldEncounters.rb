# frozen_string_literal: true
# Native encounter adapter. Wild encounter roll -> OW Game_Event -> same OW capture.
# No separate independent spawn loop and no hidden uncatchable Pokémon.
module BifrostCapture
  @wild_events = {}
  @spawn_sequence = 0

  def self.generated?(event)
    !!(event && event.instance_variable_get(:@bifrost_generated))
  end

  def self.wild_events
    @wild_events ||= {}
    @wild_events.delete_if do |_key,event|
      !event || !$game_map || event.map_id != $game_map.map_id ||
        !$game_map.events[event.id].equal?(event) ||
        event.instance_variable_get(:@erased)
    end
    @wild_events.values
  end

  def self.erase_wild(event)
    return false unless generated?(event)
    stop_spawn_intro(event)
    @wild_events.delete(event.object_id)
    map = event.map
    if defined?($scene) && $scene.is_a?(Scene_Map)
      spriteset = $scene.spriteset(event.map_id)
      spriteset.bifrost_remove_character(event) if spriteset
    end
    map.unregister_event(event) if map && event.respond_to?(:active) && event.active
    map.events.delete(event.id) if map && map.events[event.id].equal?(event)
    event.erase
    true
  end

  def self.reset_wild_events
    (@wild_events || {}).values.dup.each { |event| erase_wild(event) }
    @wild_events = {}
    reset_spawn_intros
    @extra_cooldown = 0
  end

  def self.valid_spawn_tile?(x,y,cfg,cave=false)
    return false if !$game_map.valid?(x,y)
    return false if x == $game_player.x && y == $game_player.y
    return false if $game_map.events.values.any? { |event|
      !event.through && event.x == x && event.y == y
    }
    return false unless [2,4,6,8].any? { |d| $game_map.passable?(x,y,d) }
    tag = $game_map.terrain_tag(x,y)
    return false if tag.ice || tag.waterfall || tag.waterfall_crest
    return true if cave || cfg["spawn_grass_only"] == "0"
    tag.land_wild_encounters
  end

  def self.spawn_tile(cfg,cave=false)
    low = cfg["spawn_min_distance"].to_i.clamp(1,12)
    high = cfg["spawn_max_distance"].to_i.clamp(low,16)
    candidates = []
    (-high..high).each do |dx|
      (-high..high).each do |dy|
        dist = dx.abs+dy.abs
        next unless dist.between?(low,high)
        x,y = $game_player.x+dx,$game_player.y+dy
        candidates << [x,y] if valid_spawn_tile?(x,y,cfg,cave)
      end
    end
    return candidates.sample if !candidates.empty?
    # Many narrow grass routes have no free tile at the preferred distance.
    # A nearby walkable tile is preferable to spawning nothing or launching a
    # battle in an explicit OW-only profile.
    return nil unless cfg["encounter_mode"] == "overworld"
    (1..[high+3,12].min).each do |dist|
      nearby = []
      (-dist..dist).each do |dx|
        dy_abs = dist - dx.abs
        [-dy_abs,dy_abs].uniq.each do |dy|
          x,y = $game_player.x+dx,$game_player.y+dy
          next unless valid_spawn_tile?(x,y,cfg,true)
          nearby << [x,y]
        end
      end
      return nearby.sample if !nearby.empty?
    end
    nil
  end

  def self.character_for(species,form=0)
    names = []
    names << "Followers/#{species}_#{form}" if form.to_i > 0
    names << "Followers/#{species}"
    names << "Followers/#{species}_0"
    names.find { |name| pbResolveBitmap("Graphics/Characters/#{name}") }
  end

  def self.spawn_wild(enc_type, extra: false)
    cfg = options
    return :not_available if !extra && !overworld_encounters?(cfg)
    return :not_available if cfg["enabled"] != "1"
    return :full if wild_events.length >= cfg["spawn_limit"].to_i.clamp(1,16)
    wild = $PokemonEncounters.choose_wild_pokemon(enc_type)
    return :not_available unless wild && wild[0] && wild[1]
    species,level = wild[0].to_sym,wild[1].to_i
    return :not_available unless GameData::Species.exists?(species)
    local = options($game_map.map_id,species)
    return :filtered unless spawn_species?(species,local)
    return :filtered if rand(100) >= local["ow_spawn_probability"].to_i.clamp(0,100)
    kind = GameData::EncounterType.get(enc_type).type
    tile = spawn_tile(cfg,kind == :cave)
    return :no_tile if !tile
    min_level,max_level = local["ow_min_level"].to_i,local["ow_max_level"].to_i
    if min_level > 0
      level = max_level >= min_level ? rand(min_level..max_level) : min_level
    end
    level = level.clamp(1,100)
    form = [local["ow_form"].to_i,0].max
    sprite_name = character_for(species,form)
    return :missing_sprite unless sprite_name
    @spawn_sequence = (@spawn_sequence || 0) + 1
    id = ($game_map.events.keys.max || 0) + 1
    event_data = RPG::Event.new(tile[0],tile[1])
    event_data.id = id
    event_data.name = "[OWCAP:#{species}:#{level}:#{form}]"
    page = RPG::Event::Page.new
    page.graphic.character_name = sprite_name
    page.graphic.direction = 2
    page.move_type = 1
    page.move_speed = 3
    page.move_frequency = 3
    page.through = false
    page.trigger = 0
    page.list = [
      RPG::EventCommand.new(355,0,["BifrostCapture.interact_battle($game_map.events[#{id}])"]),
      RPG::EventCommand.new(0,0,[])
    ]
    event_data.pages = [page]
    event = Game_Event.new($game_map.map_id,event_data,$game_map)
    event.instance_variable_set(:@bifrost_generated,true)
    event.instance_variable_set(:@bifrost_extra_spawn,extra)
    event.instance_variable_set(:@bifrost_remaining_steps,
                               cfg["spawn_lifetime"].to_i)
    $game_map.events[id] = event
    # Game_Map updates only registered/active events. Inserting into @events
    # alone leaves a static or invisible Pokémon until the map refreshes.
    $game_map.register_event(event)
    register_ow(event,species,level,form)
    # Temperament is sampled exactly once per individual, not on every tick.
    temperament_for(event,local)
    if $scene.is_a?(Scene_Map)
      spriteset = $scene.spriteset($game_map.map_id)
      spriteset.bifrost_add_character(event) if spriteset
    end
    @wild_events[event.object_id] = event
    spawn_intro(event,local)
    :spawned
  end

  def self.try_extra_spawn
    cfg = options
    return :disabled if cfg["enabled"] != "1"
    chance = cfg["ow_extra_spawn_chance"].to_i.clamp(0,100)
    return :disabled if chance <= 0
    @extra_cooldown = (@extra_cooldown || 0) - 1
    return :cooldown if @extra_cooldown > 0
    return :disabled if !$PokemonEncounters || !$player || !$game_map ||
                        !$game_player || !$game_temp
    return :disabled if $game_temp.in_battle ||
                        $game_temp.in_menu ||
                        $game_temp.message_window_showing
    return :disabled if $game_system && $game_system.encounter_disabled
    return :disabled if $PokemonGlobal && $PokemonGlobal.respond_to?(:surfing) &&
                        $PokemonGlobal.surfing
    return :disabled if defined?($DEBUG) && $DEBUG &&
                        Input.const_defined?(:CTRL) && Input.press?(Input::CTRL)
    return :disabled unless $PokemonEncounters.respond_to?(:encounter_type) &&
                             $PokemonEncounters.respond_to?(:encounter_possible_here?)
    return :disabled unless $PokemonEncounters.encounter_possible_here?
    kind = $PokemonEncounters.encounter_type
    return :disabled unless kind && GameData::EncounterType.exists?(kind)
    type = GameData::EncounterType.get(kind).type
    return :disabled unless [:land,:cave].include?(type)
    return :roll_failed if rand(100) >= chance
    # Use the ordinary PBS table to choose species; only the OW roll is extra.
    # The original wild battle chance remains untouched.
    outcome = spawn_wild(kind, :extra=>true)
    if outcome == :spawned
      @extra_cooldown = cfg["ow_extra_spawn_cooldown"].to_i.clamp(0,250) + 1
    end
    outcome
  end

  def self.step_wild_events
    wild_events.dup.each do |event|
      next if event.instance_variable_get(:@bifrost_flee_state)
      steps = event.instance_variable_get(:@bifrost_remaining_steps).to_i
      next if steps <= 0
      steps -= 1
      event.instance_variable_set(:@bifrost_remaining_steps,steps)
      erase_wild(event) if steps == 0
    end
    try_extra_spawn
  end

  def self.remove_event(event)
    return false unless event
    return erase_wild(event) if generated?(event)
    return false unless defined?($PokemonGlobal) && $PokemonGlobal
    $PokemonGlobal.bifrost_removed_events ||= {}
    $PokemonGlobal.bifrost_removed_events[[$game_map.map_id,event.id]] = true
    event.erase
    true
  end

  def self.removed?(event)
    return false unless $PokemonGlobal && event
    ($PokemonGlobal.bifrost_removed_events || {})[[$game_map.map_id,event.id]] == true
  end
  # Soft materialization in its natural habitat: fade the OW sprite in
  # while a restrained dust/grass ring expands at ground level. Uses the
  # shared map viewport so Visual 2.5D/tile priorities remain intact.
  @spawn_intros = {}
  def self.spawn_intro(event,cfg)
    return unless event && event.respond_to?(:opacity=) && event.respond_to?(:opacity)
    @spawn_intros ||= {}
    stop_spawn_intro(event)
    duration = cfg["spawn_intro_frames"].to_i.clamp(6,60)
    state = { :event=>event, :frame=>0, :duration=>duration,
              :opacity=>event.opacity, :ring=>nil }
    event.opacity = 0
    if defined?($scene) && $scene.is_a?(Scene_Map) &&
       defined?(Spriteset_Map) && Spriteset_Map.respond_to?(:viewport)
      vp = Spriteset_Map.viewport
      if vp && !vp.disposed?
        ring = Sprite.new(vp)
        ring.bitmap = Bitmap.new(48,20)
        ring.ox = 24;ring.oy = 10
        tint = Color.new(176,201,163,168)
        48.times do |i|
          theta = i*2.0*Math::PI/48
          xx = (24+20*Math.cos(theta)).to_i
          yy = (10+6*Math.sin(theta)).to_i
          ring.bitmap.fill_rect(xx,yy,2,2,tint)
        end
        ring.opacity = 0
        state[:ring] = ring
      end
    end
    @spawn_intros[event.object_id] = state
  rescue StandardError
    event.opacity = 255 if event && event.respond_to?(:opacity=)
  end

  def self.emerging?(event)
    !!(@spawn_intros && event && @spawn_intros[event.object_id])
  end

  def self.stop_spawn_intro(event,restore=false)
    return unless @spawn_intros
    state = @spawn_intros.delete(event.object_id)
    return unless state
    event.opacity = state[:opacity] if restore && event.respond_to?(:opacity=)
    ring = state[:ring]
    if ring && !ring.disposed?
      bitmap = ring.bitmap
      ring.dispose
      bitmap.dispose if bitmap && !bitmap.disposed?
    end
  end

  def self.reset_spawn_intros
    (@spawn_intros || {}).values.dup.each do |state|
      stop_spawn_intro(state[:event],true)
    end
    @spawn_intros = {}
  end

  def self.update_spawn_intros
    return unless @spawn_intros && !@spawn_intros.empty?
    unless $game_map && defined?($scene) && $scene.is_a?(Scene_Map) &&
           (!defined?($game_temp) || !$game_temp || !$game_temp.in_battle)
      reset_spawn_intros
      return
    end
    @spawn_intros.values.dup.each do |state|
      event = state[:event]
      unless $game_map.events[event.id].equal?(event) &&
             !event.instance_variable_get(:@erased)
        stop_spawn_intro(event)
        next
      end
      state[:frame] += 1
      t = [state[:frame].to_f/state[:duration],1.0].min
      ease = t*t*(3-2*t)
      event.opacity = (state[:opacity]*ease).round
      ring = state[:ring]
      if ring && !ring.disposed?
        rect = target_rect(event)
        ring.x = rect[0]+rect[2]/2
        ring.y = rect[1]+rect[3]
        ring.z = event.respond_to?(:screen_z) ? event.screen_z-1 : 0
        ring.zoom_x = ring.zoom_y = 0.65+0.75*t
        ring.opacity = (200*Math.sin(Math::PI*t)).round
      end
      stop_spawn_intro(event,true) if state[:frame] >= state[:duration]
    end
  end
end

class Spriteset_Map
  def bifrost_add_character(event)
    @character_sprites ||= []
    return if @character_sprites.any? { |sp| sp.character.equal?(event) }
    @character_sprites << Sprite_Character.new(self.class.viewport,event)
  end

  def bifrost_remove_character(event)
    @character_sprites ||= []
    @character_sprites.delete_if do |sp|
      next false unless sp.character.equal?(event)
      sp.dispose unless sp.disposed?
      true
    end
  end
end

class PokemonEncounters
  unless method_defined?(:bifrost_v1_encounter_triggered?)
    alias bifrost_v1_encounter_triggered? encounter_triggered?
  end

  def encounter_triggered?(enc_type,repel_active=false,triggered_by_step=true)
    triggered = bifrost_v1_encounter_triggered?(enc_type,repel_active,triggered_by_step)
    return triggered unless triggered && triggered_by_step && enc_type
    return triggered unless BifrostCapture.overworld_encounters?
    kind = GameData::EncounterType.get(enc_type).type
    return triggered unless [:land,:cave].include?(kind)
    cfg = BifrostCapture.options
    # Hybrid converts only some naturally rolled encounters.
    if cfg["encounter_mode"] == "hybrid" &&
       rand(100) >= cfg["spawn_chance"].to_i.clamp(0,100)
      return triggered
    end
    outcome = BifrostCapture.spawn_wild(enc_type)
    if cfg["encounter_mode"] == "overworld"
      # Never force the battle renderer from the OW-only mode. In particular,
      # the previous fallback exposed unrelated Battle::Scene alias recursion.
      # Keep a meaningful diagnosis for missing assets or map capacity.
      BifrostCapture.notice(_INTL("Bifröst OW: {1}".dup,outcome.to_s)) if
        outcome != :spawned && outcome != :full && outcome != :filtered
      return false
    end
    # Hybrid may leave the normal battle intact if an OW cannot be created.
    return triggered if [:missing_sprite,:no_tile,:not_available].include?(outcome)
    false
  end
end

EventHandlers.add(:on_player_step_taken,:bifrost_ow_expiry,
  proc { BifrostCapture.step_wild_events }
)
EventHandlers.add(:on_enter_map,:bifrost_ow_reset,
  proc { |_old| BifrostCapture.reset_wild_events }
)

EventHandlers.add(:on_frame_update,:bifrost_spawn_emergence,
  proc { BifrostCapture.update_spawn_intros }
)
