# frozen_string_literal: true
# FULL OVERWORLD MODE - utiliza las tablas actuales de encuentros sin
# reemplazar datos de PBS, mapas, visual 2.5D ni sistemas de batalla.
module BifrostCapture
  @spawned = {}

  def self.generated?(event)
    event && event.instance_variable_get(:@bifrost_generated) == true
  end

  def self.discard_generated(event)
    return false unless generated?(event)
    @spawned ||= {}
    @spawned.delete([event.map_id, event.id])
    event.erase
    if defined?($scene) && $scene.is_a?(Scene_Map)
      spriteset = $scene.spriteset(event.map_id)
      spriteset.bifrost_remove_character(event) if spriteset
    end
    # No registrar eventos temporales como capturados de forma persistente.
    # El mapa se restablece al volver a entrar.
    source_map = event.respond_to?(:map) ? event.map : nil
    if source_map && source_map.events[event.id].equal?(event)
      source_map.events.delete(event.id)
    end
    true
  end

  def self.spawned_events
    @spawned ||= {}
    @spawned.delete_if do |key, event|
      !event || event.instance_variable_get(:@erased) ||
        !($game_map && key[0] == $game_map.map_id &&
          $game_map.events[key[1]].equal?(event))
    end
    @spawned.values
  end

  def self.reset_spawns
    (@spawned || {}).values.dup.each do |event|
      discard_generated(event) if generated?(event)
    end
    @spawned = {}
  end

  def self.eligible_grass_tile?(x,y,cfg)
    return false unless $game_map.valid?(x,y)
    return false if x == $game_player.x && y == $game_player.y
    return false if $game_map.events.values.any? { |e| e.x == x && e.y == y && !e.through }
    # Evitar apariciones dentro de paredes y obstaculos no transitables.
    return false unless [2,4,6,8].any? { |d| $game_map.passable?(x,y,d) }
    tag = $game_map.terrain_tag(x,y)
    return false if tag.ice || tag.waterfall || tag.waterfall_crest
    return true if cfg["spawn_grass_only"] == "0"
    tag.land_wild_encounters
  end

  def self.choose_spawn_tile(cfg)
    low = cfg["spawn_min_distance"].to_i.clamp(1,12)
    high = cfg["spawn_max_distance"].to_i.clamp(low,16)
    candidates = []
    (-high..high).each do |dx|
      (-high..high).each do |dy|
        distance = dx.abs + dy.abs
        next unless distance.between?(low,high)
        x = $game_player.x + dx
        y = $game_player.y + dy
        candidates << [x,y] if eligible_grass_tile?(x,y,cfg)
      end
    end
    candidates.sample
  end

  def self.existing_sprite(species, form = 0)
    candidates = []
    candidates << "Followers/#{species}_#{form}" if form > 0
    candidates << "Followers/#{species}"
    candidates << "Followers/#{species}_0"
    candidates.each do |name|
      return name if pbResolveBitmap("Graphics/Characters/#{name}")
    end
    nil
  end

  def self.construct_ow_event(species, level, tile, sprite_name, form = 0)
    id = ($game_map.events.keys.max || 0) + 1
    # Ids never reuse a previous id while the map is loaded.
    data = RPG::Event.new(tile[0],tile[1])
    data.id = id
    data.name = "[OWCAP:#{species}:#{level}:#{form}]"
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
    data.pages = [page]
    event = Game_Event.new($game_map.map_id, data, $game_map)
    event.instance_variable_set(:@bifrost_generated,true)
    event.instance_variable_set(:@bifrost_steps,0)
    $game_map.events[id] = event
    # Los Spriteset_Map se construyen antes que el evento generado.
    if $scene.is_a?(Scene_Map) && $scene.spriteset($game_map.map_id)
      $scene.spriteset($game_map.map_id).bifrost_add_character(event)
    end
    @spawned ||= {}
    @spawned[[$game_map.map_id,id]] = event
    event
  end

  def self.expire_spawns(cfg)
    duration = cfg["spawn_lifetime"].to_i
    return if duration <= 0
    spawned_events.dup.each do |event|
      steps = event.instance_variable_get(:@bifrost_steps).to_i + 1
      event.instance_variable_set(:@bifrost_steps,steps)
      discard_generated(event) if steps >= duration
    end
  end

  def self.spawn_on_step
    return if !$PokemonEncounters || !$game_map || !$game_player
    cfg = options
    return unless overworld_encounters?(cfg)
    return if !$scene.is_a?(Scene_Map) || !$player
    return if $game_temp.in_menu || $game_temp.in_battle ||
              $game_temp.message_window_showing || pbMapInterpreterRunning? ||
              $game_player.move_route_forcing
    expire_spawns(cfg)
    return if spawned_events.length >= cfg["spawn_limit"].to_i.clamp(1,20)
    return if rand(100) >= cfg["spawn_chance"].to_i.clamp(0,100)
    return if defined?(repel_active?) && repel_active?
    return unless $PokemonEncounters.encounter_possible_here?
    encounter_type = $PokemonEncounters.encounter_type
    return unless encounter_type
    kind = GameData::EncounterType.get(encounter_type).type
    return unless [:land, :cave].include?(kind)
    wild = $PokemonEncounters.choose_wild_pokemon(encounter_type)
    return unless wild && wild[0] && wild[1]
    species, level = wild[0].to_sym, wild[1].to_i
    return unless GameData::Species.exists?(species)
    local = options($game_map.map_id,species)
    return unless spawn_species?(species,local)
    probability = local["ow_spawn_probability"].to_i.clamp(0,100)
    return if rand(100) >= probability
    level_min = local["ow_min_level"].to_i
    level_max = local["ow_max_level"].to_i
    if level_min > 0 && level_max >= level_min
      level = rand(level_min..level_max)
    elsif level_min > 0
      level = level_min
    end
    level = level.clamp(1,GameData::GrowthRate.max_level)
    form = [local["ow_form"].to_i,0].max
    # Cuevas: no exigir un tag de hierba inexistente.
    spawn_tile_rules = kind == :cave ? cfg.merge("spawn_grass_only"=>"0") : cfg
    tile = choose_spawn_tile(spawn_tile_rules)
    return unless tile
    sprite_name = existing_sprite(species,form)
    return unless sprite_name # Sin gráfico jamás generar un OW invisible.
    construct_ow_event(species,level,tile,sprite_name,form)
  end
end

class Spriteset_Map
  def bifrost_add_character(event)
    @character_sprites ||= []
    @character_sprites.push(Sprite_Character.new(self.class.viewport,event))
  end

  def bifrost_remove_character(event)
    @character_sprites ||= []
    @character_sprites.delete_if do |sprite|
      next false if !sprite || sprite.character != event
      sprite.dispose if !sprite.disposed?
      true
    end
  end
end

class PokemonEncounters
  unless method_defined?(:bifrost_original_encounter_triggered?)
    alias bifrost_original_encounter_triggered? encounter_triggered?
  end

  def encounter_triggered?(enc_type, repel_active = false, triggered_by_step = true)
    if BifrostCapture.overworld_encounters? && enc_type &&
       GameData::EncounterType.exists?(enc_type)
      kind = GameData::EncounterType.get(enc_type).type
      # Solo los encuentros espontaneos de terreno. Pesca, Surf, uso de objetos
      # y los combates por script mantienen el sistema original.
      return false if triggered_by_step &&
                      BifrostCapture.options["encounter_mode"] == "overworld" &&
                      [:land, :cave].include?(kind)
    end
    bifrost_original_encounter_triggered?(enc_type,repel_active,triggered_by_step)
  end
end

EventHandlers.add(:on_player_step_taken,:bifrost_spawn_on_step,
  proc { BifrostCapture.spawn_on_step }
)
EventHandlers.add(:on_enter_map,:bifrost_reset_ow_spawns,
  proc { |_old_map_id| BifrostCapture.reset_spawns }
)
