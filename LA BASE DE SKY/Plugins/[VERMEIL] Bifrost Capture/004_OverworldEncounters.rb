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
    candidates.sample
  end

  def self.character_for(species,form=0)
    names = []
    names << "Followers/#{species}_#{form}" if form.to_i > 0
    names << "Followers/#{species}"
    names << "Followers/#{species}_0"
    names.find { |name| pbResolveBitmap("Graphics/Characters/#{name}") }
  end

  def self.spawn_wild(enc_type)
    cfg = options
    return :not_available if !overworld_encounters?(cfg)
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
      RPG::EventCommand.new(355,0,["pbBifrostAim"]),
      RPG::EventCommand.new(0,0,[])
    ]
    event_data.pages = [page]
    event = Game_Event.new($game_map.map_id,event_data,$game_map)
    event.instance_variable_set(:@bifrost_generated,true)
    event.instance_variable_set(:@bifrost_remaining_steps,
                               cfg["spawn_lifetime"].to_i)
    $game_map.events[id] = event
    register_ow(event,species,level,form)
    if $scene.is_a?(Scene_Map)
      spriteset = $scene.spriteset($game_map.map_id)
      spriteset.bifrost_add_character(event) if spriteset
    end
    @wild_events[event.object_id] = event
    :spawned
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
    # Full mode never silently replaces an eligible encounter with nothing.
    # Missing graphics/room fall back to a vanilla battle.
    return triggered if [:missing_sprite,:no_tile,:not_available].include?(outcome)
    return false # spawned / full / intentionally filtered
  end
end

EventHandlers.add(:on_player_step_taken,:bifrost_ow_expiry,
  proc { BifrostCapture.step_wild_events }
)
EventHandlers.add(:on_enter_map,:bifrost_ow_reset,
  proc { |_old| BifrostCapture.reset_wild_events }
)
