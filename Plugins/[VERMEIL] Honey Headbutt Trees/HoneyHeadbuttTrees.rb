#===============================================================================
# Honey + Headbutt Trees (Guaranteed Encounters)
#===============================================================================
module HoneyHeadbuttTrees
  # Event name must match this regex to be treated as a honey/headbutt tree.
  TREE_NAME_REGEX = /honeytree|headbutttree|sweettree/i
  TREE_TERRAIN_TAG = :HoneyTree
  TREE_TERRAIN_TAG_ID = 18

  # Item used to slather honey.
  HONEY_ITEM = :HONEY
  HONEY_ENCOUNTER_TYPE = :HoneyTree

  # Items that can substitute for having the Headbutt move.
  # Add or replace entries to match your project (e.g. :TM_HEADBUTT).
  HEADBUTT_ITEMS = [:HEADBUTT]
  HEADBUTT_ENCOUNTER_TYPE = :HeadbuttHigh
end

if !GameData::EncounterType.exists?(HoneyHeadbuttTrees::HONEY_ENCOUNTER_TYPE)
  GameData::EncounterType.register({
    :id   => HoneyHeadbuttTrees::HONEY_ENCOUNTER_TYPE,
    :type => :none
  })
end

if !GameData::TerrainTag.exists?(HoneyHeadbuttTrees::TREE_TERRAIN_TAG)
  GameData::TerrainTag.register({
    :id        => HoneyHeadbuttTrees::TREE_TERRAIN_TAG,
    :id_number => HoneyHeadbuttTrees::TREE_TERRAIN_TAG_ID
  })
end

def pbHoneyTreeObtainText
  map_name = ($game_map) ? $game_map.name : ""
  return _INTL("Honey Tree - {1}", map_name)
end

def pbFacingHoneyHeadbuttTree?
  tag = $game_player.pbFacingTerrainTag
  return true if tag && tag.id == HoneyHeadbuttTrees::TREE_TERRAIN_TAG
  event = $game_player.pbFacingEvent(true)
  return true if event && event.name[HoneyHeadbuttTrees::TREE_NAME_REGEX]
  return false
end

def pbHasHeadbuttTool?
  return true if $player.get_pokemon_with_move(:HEADBUTT)
  HoneyHeadbuttTrees::HEADBUTT_ITEMS.each do |item|
    next if !GameData::Item.exists?(item)
    return true if $bag && $bag.has?(item)
  end
  return false
end

def pbHasHoneyForTree?
  item = HoneyHeadbuttTrees::HONEY_ITEM
  return false if !GameData::Item.exists?(item)
  return $bag && $bag.has?(item)
end

def pbUseHeadbuttOnTree(event = nil)
  $stats.headbutt_count += 1 if $stats
  movefinder = $player.get_pokemon_with_move(:HEADBUTT)
  if movefinder
    pbMessage(_INTL("{1} used {2}!", movefinder.name, GameData::Move.get(:HEADBUTT).name))
    pbHiddenMoveAnimation(movefinder)
  else
    pbMessage(_INTL("You used Headbutt!"))
  end
  pbSEPlay("Headbutt")
  $game_screen.start_shake(3, 4, 12)
  pbWait(1.0)
  if $game_temp
    $game_temp.instance_variable_set(:@honey_headbutt_tree_obtain_text, pbHoneyTreeObtainText)
  end
  if pbEncounter(HoneyHeadbuttTrees::HEADBUTT_ENCOUNTER_TYPE)
    $stats.headbutt_battles += 1 if $stats
  else
    pbMessage(_INTL("Nothing appeared..."))
  end
  return true
end

def pbUseHoneyOnTree(event = nil)
  item = HoneyHeadbuttTrees::HONEY_ITEM
  if !GameData::Item.exists?(item) || !$bag || !$bag.has?(item)
    pbMessage(_INTL("You don't have any Honey."))
    return false
  end
  pbMessage(_INTL("You slathered some Honey on the tree."))
  pbHoneyTreeScentAnimation
  $bag.remove(item)
  if $game_temp
    $game_temp.instance_variable_set(:@honey_headbutt_tree_obtain_text, pbHoneyTreeObtainText)
  end
  if !pbEncounter(HoneyHeadbuttTrees::HONEY_ENCOUNTER_TYPE)
    pbMessage(_INTL("Nothing appeared..."))
  end
  return true
end

def pbHoneyTreeScentAnimation
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99999
  viewport.color.red   = 255
  viewport.color.green = 32
  viewport.color.blue  = 32
  viewport.color.alpha -= 10
  pbSEPlay("Sweet Scent")
  start_alpha = viewport.color.alpha
  duration = 2.0
  fade_time = 0.4
  pbWait(duration) do |delta_t|
    if delta_t < duration / 2
      viewport.color.alpha = lerp(start_alpha, start_alpha + 128, fade_time, delta_t)
    else
      viewport.color.alpha = lerp(start_alpha + 128, start_alpha, fade_time, delta_t - duration + fade_time)
    end
  end
  viewport.dispose
  pbSEStop(0.5)
end

def pbHoneyHeadbuttTree(event = nil)
  event ||= $game_player.pbFacingEvent(true)
  if event
    return false if !event.name[HoneyHeadbuttTrees::TREE_NAME_REGEX]
  else
    tag = $game_player.pbFacingTerrainTag
    return false if !tag || tag.id != HoneyHeadbuttTrees::TREE_TERRAIN_TAG
  end
  has_headbutt = pbHasHeadbuttTool?
  has_honey    = pbHasHoneyForTree?
  if !has_headbutt && !has_honey
    pbMessage(_INTL("It's a sweet-smelling tree.\nBut you don't have anything to use on it."))
    return false
  end
  if has_headbutt && has_honey
    cmds = [_INTL("Headbutt the tree"), _INTL("Slather honey"), _INTL("Cancel")]
    choice = pbMessage(_INTL("What would you like to do?"), cmds, 3, nil, 2)
    case choice
    when 0 then return pbUseHeadbuttOnTree(event)
    when 1 then return pbUseHoneyOnTree(event)
    else return false
    end
  elsif has_headbutt
    return pbUseHeadbuttOnTree(event)
  else
    return pbUseHoneyOnTree(event)
  end
end

EventHandlers.add(:on_player_interact, :honey_headbutt_tree,
  proc {
    next if !pbFacingHoneyHeadbuttTree?
    pbHoneyHeadbuttTree
  }
)

HiddenMoveHandlers::CanUseMove.add(:HEADBUTT, proc { |move, pkmn, showmsg|
  facing_event = $game_player.pbFacingEvent
  if !facing_event || !facing_event.name[/headbutttree/i]
    tag = $game_player.pbFacingTerrainTag
    if !tag || tag.id != HoneyHeadbuttTrees::TREE_TERRAIN_TAG
      pbMessage(_INTL("You can't use that here.")) if showmsg
      next false
    end
  end
  next true
})

HiddenMoveHandlers::UseMove.add(:HEADBUTT, proc { |move, pokemon|
  if pbFacingHoneyHeadbuttTree?
    pbUseHeadbuttOnTree($game_player.pbFacingEvent)
  else
    if !pbHiddenMoveAnimation(pokemon)
      pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name))
    end
    $stats.headbutt_count += 1 if $stats
    facing_event = $game_player.pbFacingEvent
    pbHeadbuttEffect(facing_event)
  end
  next true
})

module Battle::CatchAndStoreMixin
  if method_defined?(:pbRecordAndStoreCaughtPokemon) &&
     !method_defined?(:__honey_headbutt__pbRecordAndStoreCaughtPokemon)
    alias __honey_headbutt__pbRecordAndStoreCaughtPokemon pbRecordAndStoreCaughtPokemon
  end

  def pbRecordAndStoreCaughtPokemon
    if $game_temp && $game_temp.instance_variable_defined?(:@honey_headbutt_tree_obtain_text)
      obtain_text = $game_temp.instance_variable_get(:@honey_headbutt_tree_obtain_text)
      @caughtPokemon.each do |pkmn|
        pkmn.obtain_text = obtain_text
      end
    end
    __honey_headbutt__pbRecordAndStoreCaughtPokemon
  ensure
    if $game_temp
      $game_temp.remove_instance_variable(:@honey_headbutt_tree_obtain_text) if
        $game_temp.instance_variable_defined?(:@honey_headbutt_tree_obtain_text)
    end
  end
end
