#===============================================================================
# Custom Battles
#===============================================================================
# This module stores custom battle scripts for special encounters.
#===============================================================================

module CustomBattles
  #-----------------------------------------------------------------------------
  # Wild Boss Battles
  #-----------------------------------------------------------------------------
  WildBosses = {
    # Ho-Oh Custom Battle
    :HOOH_BOSS => {
      # After player sends out
      "AfterSendOut_player" => {
        "text" => "The heat caused by both Fire-type Pokémon is warping the Poké Balls!",
        "editWindow" => [nil, "speech hgss 1"],
        "speech" => "Welp, I really didn't mean to catch it, but the burning Poké Balls are getting kinda annoying in my pockets.",
        "disableBalls" => true,
        "setBattler" => :Opposing,
        "battlerHPCap" => 0,
        "battlerEffects" => [:Endure, true],
        "setBattler" => :Self,
        "battlerHPCap" => 1,
        "battlerEffects" => [:Endure, true],
        "setBattler" => :Opposing,
        "battlerStats" => [:SPECIAL_ATTACK, 6],
        "battlerEffects" => [:Endure, true],
        "battlerHPCap" => 1
      },
      # Force Sacred Fire on turn 1
      "TurnStart_1_foe" => {
        "setBattler" => :Opposing,
        "battlerEffects" => [:Endure, true],
        "setBattler" => :Self,
        "useMove" => :SACREDFIRE
      },
      # Force Ancient Power on turn 2
      "TurnStart_2_foe" => {
        "setBattler" => :Opposing,
        "battlerEffects" => [:Endure, true],
        "setBattler" => :Self,
        "useMove" => :ANCIENTPOWER
      },
      # First endure dialogue
      "Variable_1" => {
        "speech" => "Geez, that was close. Good thing I used that Full Restore to fix ya up.",
        "editWindow" => [nil, "speech hgss 1"]
      },
      # Second endure dialogue
      "Variable_2" => {
        "speech" => "Welp, that's great. At this rate I'm gonna run outta Full Restores.",
        "editWindow" => [nil, "speech hgss 1"]
      },
      # Third endure dialogue (just in case)
      "Variable_3" => {
        "speech" => "Give me a break. I'm fresh out of Full Restores. Typh, it's all up to you now, pal.",
        "editWindow" => [nil, "speech hgss 1"]
      },
      # Prevent fainting when HP drops to red for 2 turns
      "BattlerHPCritical_player_repeat" => {
        "ignoreAfter" => "RoundEnd_2_player",
        "setBattler" => :Self,
        "battlerHPCap" => 1,
        "battlerEffects" => [:Endure, true],
        "addVariable" => 1,
        "battlerHP" => [100, "{1} was fully healed!"],
        "battlerStatus" => [:NONE]
      },
      "BattlerHPCritical_foe_repeat" => {
        "setBattler" => :Self,
        "battlerEffects" => [:Endure, true],
        "text" => "Ho-Oh uses its energy reserves to recover HP",
        "battlerHP" => [-100],
        "battlerHP" => [100]
      },
      # Message after round 2
      "RoundEnd_2_player" => {
        "editWindow" => [nil, "speech hgss 1"],
        "speech" => "Guess that proves how strong Mega Typhlosion is... And Ho-Oh is pretty overwhelming, too. Welp, time to wrap this up...",
        "endBattle" => 1
      }
    }
  }
end

# Battle rule methods - lowercase to avoid constant interpretation
def start_hooh_battle
  setBattleRule("databoxStyle", [:Long, "The legendary {1}"])
  setBattleRule("editWildPokemon", {
    "moves" => [:SACREDFIRE, :AIRSLASH, :ANCIENTPOWER, :EXTRASENSORY],
    "ivs" => { :HP => 31, :ATTACK => 31, :DEFENSE => 31, :SPECIAL_ATTACK => 31, :SPECIAL_DEFENSE => 31, :SPEED => 31 },
    "evs" => { :HP => 6, :SPECIAL_ATTACK => 252, :SPEED => 252 },
    "nature" => :MODEST,
    "ability" => :REGENERATOR
  })
  setBattleRule("battleIntroText", "Ho-Oh accepts your challenge!")
  setBattleRule("midbattleScript", CustomBattles::WildBosses[:HOOH_BOSS])
  WildBattle.start(:HOOH, 60)
end

def start_test_cinematic
  setBattleRule("editWildPokemon", {
    "moves" => [:SOLARBEAM, :SOLARBLADE, :FRENZYPLANT],
  })
  WildBattle.start(:CORVIKNIGHT, 100)
end
