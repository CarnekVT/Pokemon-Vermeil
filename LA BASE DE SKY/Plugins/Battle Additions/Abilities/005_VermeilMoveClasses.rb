#===============================================================================
# [VERMEIL] Move classifiers
# Shared by Striker, Illuminate and related Vermeil systems.
#===============================================================================
module VermeilMoveClasses
  KICK_MOVES = [
    :DOUBLEKICK, :JUMPKICK, :HIGHJUMPKICK, :MEGAKICK, :LOWKICK,
    :ROLLINGKICK, :TRIPLEKICK, :BLAZEKICK, :TROPKICK, :THUNDEROUSKICK,
    :AXEKICK, :LOWSWEEP, :STOMP, :HIGHHORSEPOWER, :STOMPINGTANTRUM,
    :CLOSECOMBAT, :BEDROCKKICK, :TRIPLEARROWS
  ].freeze unless const_defined?(:KICK_MOVES)

  LIGHT_MOVES = [
    :FLASH, :FLASHCANNON, :LUMINACRASH, :MORNINGSUN, :MOONLIGHT, :SYNTHESIS,
    :SWIFT, :REFLECT, :LIGHTSCREEN, :AURORAVEIL, :AURORABEAM, :MIRRORCOAT,
    :SPOTLIGHT, :PHOTONGEYSER, :PRISMATICLASER, :LIGHTOFRUIN, :DAZZLINGGLEAM,
    :LUSTERPURGE, :FLASHSTRIKE, :MAGICSPARK, :MAGICPHOTON, :POWERGEM,
    :SOLARBEAM, :SOLARBLADE, :MINDBLOWN, :SIGNALBEAM, :CONFUSERAY,
    :SUNSTEELSTRIKE, :MOONGEISTBEAM, :FLEURCANNON, :FLAMEBURST
  ].freeze unless const_defined?(:LIGHT_MOVES)

  def self.normalize_id(move_or_id)
    id = move_or_id.respond_to?(:id) ? move_or_id.id : move_or_id
    return id.to_sym if id.is_a?(String)
    return id
  end

  def self.kick_move?(move_or_id)
    return false if move_or_id.nil?
    if move_or_id.respond_to?(:flags)
      flags = move_or_id.flags
      return true if flags && flags.include?("Kicking")
      return true if flags && flags.include?(:Kicking)
    end
    KICK_MOVES.include?(normalize_id(move_or_id))
  end

  def self.light_move?(move_or_id)
    return LIGHT_MOVES.include?(normalize_id(move_or_id))
  end
end
