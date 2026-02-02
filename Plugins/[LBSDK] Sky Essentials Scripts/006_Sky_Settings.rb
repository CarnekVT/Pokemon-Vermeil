#==============================================================================#
#                              Sky Essentials                                  #
#                                Settings Module                                #
#                         Based on LA BASE DE SKY v21.1                         #
#==============================================================================#

module Settings
  # Restore consumable items after battle (gems, berries, focus sash, etc.)
  RESTORE_HELD_ITEMS_AFTER_BATTLE = false

  # List of consumable items that will NOT be restored after battle
  # Format: [:ITEMID], e.g., [:SITRUSBERRY]
  RESTORE_HELD_ITEMS_BLACKLIST = []

  ################################################################################
  # DELUXE BATTLE SCRIPT CONFIGURATION
  ################################################################################
  DELUXE_GRAPHICS_PATH = "Graphics/Plugins/Deluxe Battle Kit/"
  SHORTEN_MOVES = true
  SHOW_MEGA_ANIM = true
  SHOW_PRIMAL_ANIM = true
  USE_NEW_EXP_SHARE = true
  EXPSHARE_ENABLED = true

  ################################################################################
  # ENHANCED BATTLE UI CONFIGURATION
  ################################################################################
  BATTLE_UI_GRAPHICS_PATH = "Graphics/Plugins/Enhanced Battle UI/"
  
  UI_PROMPT_DISPLAY = 2
  USE_MOVE_TYPE_BACKGROUNDS = true
  SHOW_TYPE_EFFECTIVENESS_FOR_NEW_SPECIES = false
  GREY_OUT_FAINTED = true
  
  ################################################################################
  # ADVANCED POKÉDEX
  ################################################################################
  POKEDEX_DATA_PAGE_GRAPHICS_PATH = "Graphics/Plugins/Pokedex Data Page/"
  ALT_EGG_GROUP_NAMES = false
  ADVANCED_DEX_PAGE = 4
  SHOW_SILHOUETTES_IN_DEX = false
  SHOW_STAT_CHANGES_WITH_POKEAPI = false

  ################################################################################
  # TURBO
  ################################################################################
  SPEED_OPTIONS = true

  ################################################################################
  # ENHANCED POKEMON UI
  ################################################################################
  POKEMON_UI_GRAPHICS_PATH = "Graphics/Plugins/Enhanced Pokemon UI/"
  
  SHOW_PARTY_BALL = true
  SUMMARY_HAPPINESS_METER = true
  SUMMARY_SHINY_LEAF = false
  STORAGE_SHINY_LEAF = false
  SUMMARY_LEGACY_DATA = true
  SUMMARY_IV_RATINGS = true
  STORAGE_IV_RATINGS = false
  IV_DISPLAY_STYLE   = 1
  
  DISPLAY_ENHANCED_STATS = false
  SHOW_ADVANCED_STATS = true
  SHOW_ITEM_DESCRIPTIONS_ON_RECEIVE = true
  SHOW_MTS_MOS_IN_MOVE_RELEARNER = true
  CLOSE_MOVE_RELEARNER_AFTER_TEACHING_MOVE = false

  USE_DEFAULT_PLAYER_NAMES = false
  MALE_PLAYER_NAME = "Red"
  FEMALE_PLAYER_NAME = "Leaf"

  # This is your game version. Format should be MAJOR.MINOR.PATCH.
  GAME_VERSION = "1.0.0"

  # Specifies which generation's mechanics are applied in your game.
  # Used in battles, scripts, and other sections used both in and out of battle.
  # Choose the one that best suits your game. Note that this isn't perfect
  # and there may be some mechanics that don't match exactly, but it will generally be very close.
  MECHANICS_GENERATION = 9
  
  # Show title screen even in debug mode
  SHOW_TITLE_SCREEN_ON_DEBUG = true
  
  # Show black bars on upper/lower frames that darken when near trainers
  SHOW_TRAINER_BARS = true

  # Encrypt Mystery Gift data in MysteryGiftMaster.txt
  ENCRYPT_MYSTERY_GIFTS_IN_MASTER = true

  #=============================================================================

  MAX_MONEY            = 999_999
  MAX_COINS            = 99_999
  MAX_BATTLE_POINTS    = 9_999
  MAX_SOOT             = 9_999
  MAX_PLAYER_NAME_SIZE = 13
  MAX_PARTY_SIZE       = 6
  MAXIMUM_LEVEL        = 100
  EGG_LEVEL            = 1
  SHINY_POKEMON_CHANCE = (MECHANICS_GENERATION >= 6) ? 16 : 8
  SUPER_SHINY          = (MECHANICS_GENERATION >= 8)

  LEGENDARIES_HAVE_SOME_PERFECT_IVS   = (MECHANICS_GENERATION >= 6)
  POKERUS_CHANCE       = 3
  DISABLE_IVS_AND_EVS  = false

  #=============================================================================

  TIME_SHADING                               = true
  ANIMATE_REFLECTIONS                        = true
  POISON_IN_FIELD                            = (MECHANICS_GENERATION <= 4)
  POISON_FAINT_IN_FIELD                      = (MECHANICS_GENERATION <= 3)
  NEW_BERRY_PLANTS                           = (MECHANICS_GENERATION >= 4)
  FISHING_AUTO_HOOK                          = false
  FISHING_BEGIN_COMMON_EVENT                 = -1
  FISHING_END_COMMON_EVENT                   = -1
  DAY_CARE_POKEMON_GAIN_EXP_FROM_WALKING     = (MECHANICS_GENERATION <= 6)
  DAY_CARE_POKEMON_CAN_SHARE_EGG_MOVES       = (MECHANICS_GENERATION >= 8)
  BREEDING_CAN_INHERIT_MACHINE_MOVES         = (MECHANICS_GENERATION <= 5)
  BREEDING_CAN_INHERIT_EGG_MOVES_FROM_MOTHER = (MECHANICS_GENERATION >= 6)
  SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN  = (MECHANICS_GENERATION >= 7)
  MORE_BONUS_PREMIER_BALLS                   = (MECHANICS_GENERATION >= 8)

  ITEM_SELL_PRICE_DIVISOR                    = MECHANICS_GENERATION >= 9 ? 4 : 2

  SAFARI_STEPS                               = 600
  BUG_CONTEST_TIME                           = 20 * 60

  #=============================================================================
  
  TAUGHT_MACHINES_KEEP_OLD_PP          = (MECHANICS_GENERATION == 5)
  MOVE_RELEARNER_CAN_TEACH_MORE_MOVES  = (MECHANICS_GENERATION >= 6)
  REBALANCED_HEALING_ITEM_AMOUNTS      = (MECHANICS_GENERATION >= 7)
  RAGE_CANDY_BAR_CURES_STATUS_PROBLEMS = (MECHANICS_GENERATION >= 7)
  NO_VITAMIN_EV_CAP                    = (MECHANICS_GENERATION >= 8)
  RARE_CANDY_USABLE_AT_MAX_LEVEL       = (MECHANICS_GENERATION >= 8)
  USE_MULTIPLE_STAT_ITEMS_AT_ONCE      = (MECHANICS_GENERATION >= 8)

  #=============================================================================

  REPEL_COUNTS_FAINTED_POKEMON             = (MECHANICS_GENERATION >= 6)
  MORE_ABILITIES_AFFECT_WILD_ENCOUNTERS    = (MECHANICS_GENERATION >= 8)
  FLUTES_CHANGE_WILD_ENCOUNTER_LEVELS      = (MECHANICS_GENERATION >= 6)
  HIGHER_SHINY_CHANCES_WITH_NUMBER_BATTLED = (MECHANICS_GENERATION >= 8)
  OVERWORLD_WEATHER_SETS_BATTLE_TERRAIN    = (MECHANICS_GENERATION >= 8)
  PHONE_REMATCHES_POSSIBLE_FROM_BEGINNING  = false
  COLOR_PHONE_CALL_MESSAGES_BY_CONTACT_GENDER = true

  #=============================================================================

  RIVAL_NAMES = [
    [:RIVAL1,   12],
    [:RIVAL2,   12],
    [:CHAMPION, 12]
  ]

  #=============================================================================

  FIELD_MOVES_COUNT_BADGES = true
  BADGE_FOR_CUT       = 1
  BADGE_FOR_FLASH     = 2
  BADGE_FOR_ROCKSMASH = 3
  BADGE_FOR_SURF      = 4
  BADGE_FOR_FLY       = 5
  BADGE_FOR_STRENGTH  = 6
  BADGE_FOR_DIVE      = 7
  BADGE_FOR_WATERFALL = 8

  USE_HM_WITHOUT_LEARNING_THEM = false
  CAN_FORGET_HMS = true 
  INCUBATOR_CHOOSE_EGG_FROM_PC = true

  #=============================================================================

  def self.bag_pocket_names
    return [
      _INTL("Items"),
      _INTL("Medicine"),
      _INTL("Poké Balls"),
      _INTL("TMs & HMs"),
      _INTL("Berries"),
      _INTL("Mail"),
      _INTL("Battle Items"),
      _INTL("Key Items")
    ]
  end
  
  BAG_MAX_POCKET_SIZE  = [-1, -1, -1, -1, -1, -1, -1, -1]
  BAG_POCKET_AUTO_SORT = [false, false, false, true, true, false, false, false]
  BAG_MAX_PER_SLOT     = 999

  #=============================================================================

  NUM_STORAGE_BOXES   = 40
  HEAL_STORED_POKEMON = (MECHANICS_GENERATION <= 7)

  #=============================================================================

  USE_CURRENT_REGION_DEX = false
  
  def self.pokedex_names
    return [
      [_INTL("Kanto Pokédex"),   0],
      [_INTL("Johto Pokédex"),   1],
      _INTL("National Pokédex")
    ]
  end
  
  DEX_SHOWS_ALL_FORMS = true
  DEXES_WITH_OFFSETS  = []

  #-----------------------------------------------------------------------------
  # Pokémon summary.
  #-----------------------------------------------------------------------------

  ALLOW_RENAMING_POKEMON_IN_SUMMARY_SCREEN = (MECHANICS_GENERATION >= 9)
  ALLOW_CHANGING_MOVES_IN_SUMMARY_SCREEN   = (MECHANICS_GENERATION >= 9)
  ALLOW_SKIPPING_MOVE_LEARNING = (MECHANICS_GENERATION >= 9)

  #=============================================================================

  REGION_MAP_EXTRAS = [
    [0, 51, 16, 15, "hidden_Berth", false],
    [0, 52, 20, 14, "hidden_Faraday", false]
  ]

  CAN_FLY_FROM_TOWN_MAP = true
  SHOW_HMS_IN_PARTY_MENU = true
  SHOW_HMS_IN_SPECIAL_MENU = true
  ENABLE_MOUSE_INPUT_IN_BATTLE = false

  #=============================================================================
  
  NO_SIGNPOSTS = []

  #=============================================================================

  ROAMING_AREAS = {
    5  => [   21, 28, 31, 39, 41, 44, 47, 66, 69],
    21 => [5,     28, 31, 39, 41, 44, 47, 66, 69],
    28 => [5, 21,     31, 39, 41, 44, 47, 66, 69],
    31 => [5, 21, 28,     39, 41, 44, 47, 66, 69],
    39 => [5, 21, 28, 31,     41, 44, 47, 66, 69],
    41 => [5, 21, 28, 31, 39,     44, 47, 66, 69],
    44 => [5, 21, 28, 31, 39, 41,     47, 66, 69],
    47 => [5, 21, 28, 31, 39, 41, 44,     66, 69],
    66 => [5, 21, 28, 31, 39, 41, 44, 47,     69],
    69 => [5, 21, 28, 31, 39, 41, 44, 47, 66    ]
  }
  
  ROAMING_SPECIES = [
    [:LATIAS, 30, 53, 0, "Battle roaming"],
    [:LATIOS, 30, 53, 0, "Battle roaming"],
    [:KYOGRE, 40, 54, 2, nil, {
      2  => [   21, 31    ],
      21 => [2,     31, 69],
      31 => [2, 21,     69],
      69 => [   21, 31    ]
    }],
    [:ENTEI, 40, 55, 1]
  ]

  #=============================================================================

  STARTING_OVER_SWITCH      = 1
  SEEN_POKERUS_SWITCH       = 2
  SHINY_WILD_POKEMON_SWITCH = 31
  FATEFUL_ENCOUNTER_SWITCH  = 32
  DISABLE_BOX_LINK_SWITCH   = 35

  #=============================================================================
  
  GRASS_ANIMATION_ID           = 1
  DUST_ANIMATION_ID            = 2
  EXCLAMATION_ANIMATION_ID     = 3
  RUSTLE_NORMAL_ANIMATION_ID   = 1
  RUSTLE_VIGOROUS_ANIMATION_ID = 5
  RUSTLE_SHINY_ANIMATION_ID    = 6
  PLANT_SPARKLE_ANIMATION_ID   = 7
  WATER_RIPPLE_ANIMATION_ID    = 8

  #=============================================================================

  SCREEN_WIDTH  = 512
  SCREEN_HEIGHT = 384
  SCREEN_SCALE  = 1.0

  #=============================================================================

  LANGUAGES = [
  ]

  #=============================================================================

  SPEECH_WINDOWSKINS = [
    "speech hgss 1",
    "speech hgss 2",
    "speech hgss 3",
    "speech hgss 4",
    "speech hgss 5",
    "speech hgss 6",
    "speech hgss 7",
    "speech hgss 8",
    "speech hgss 9",
    "speech hgss 10",
    "speech hgss 11",
    "speech hgss 12",
    "speech hgss 13",
    "speech hgss 14",
    "speech hgss 15",
    "speech hgss 16",
    "speech hgss 17",
    "speech hgss 18",
    "speech hgss 19",
    "speech hgss 20",
    "speech pl 18"
  ]

  MENU_WINDOWSKINS = [
    "choice 1",
    "choice 2",
    "choice 3",
    "choice 4",
    "choice 5",
    "choice 6",
    "choice 7",
    "choice 8",
    "choice 9",
    "choice 10",
    "choice 11",
    "choice 12",
    "choice 13",
    "choice 14",
    "choice 15",
    "choice 16",
    "choice 17",
    "choice 18",
    "choice 19",
    "choice 20",
    "choice 21",
    "choice 22",
    "choice 23",
    "choice 24",
    "choice 25",
    "choice 26",
    "choice 27",
    "choice 28"
  ]

  #-----------------------------------------------------------------------------
  # Files
  #-----------------------------------------------------------------------------
  DEFAULT_WILD_BATTLE_BGM     = "Battle wild"
  DEFAULT_WILD_VICTORY_BGM    = "Battle victory"
  DEFAULT_WILD_CAPTURE_ME     = "Battle capture success"
  DEFAULT_TRAINER_BATTLE_BGM  = "Battle trainer"
  DEFAULT_TRAINER_VICTORY_BGM = "Battle victory"
  
  #=============================================================================
  # Weather Settings (Hail/Snow)
  #=============================================================================
  HAIL_WEATHER_TYPE = 1
  
  #=============================================================================
  # Status Settings (Frostbite)
  #=============================================================================
  FREEZE_EFFECTS_CAUSE_FROSTBITE = false
  
  ENABLE_SKIP_TEXT = false
  DISABLE_BUMP_SOUND = false

  #=============================================================================
  
  STORAGE_EXTEND_ON_FULL = false
  MAX_STORAGE_BOXES_EXTEND = 70

  USE_NEW_OPTIONS_UI = true
  STORE_SCREENSHOTS_IN_SAVE_FOLDER = true

  #=============================================================================
  # Game credits
  #=============================================================================
  def self.game_credits
    return [
      " PUT YOUR CREDITS HERE ",
      "",
      "SKY ESSENTIALS",
      _INTL("Created by:"),
      "Skyflyer<s>DPertierra",
      "",
      _INTL("Contributions:"),
      "ZikSanchez",
      "DarmanInigo<s>Nieves1236",
      "deNombreTuri<s>Pokepachito",
      "Ebaru",
      "",
      _INTL("Testing:"),
      "DanzanteSinMega<s>axel_kreiss",
      "glitchybek<s>abogadouuu",
      "jonidelta<s> ",
      "",
      "",
      _INTL("Attack animations:"),
      _INTL("Version 20.04.2022"),
      "Project lead by StCooler.",
      "Contributors:",
      "StCooler<s>DarryBD99",
      "WolfPP<s>ardicoozer",
      "riddlemeree",
      "Thanks to the Reborn team for",
      "letting people use their resources.",
      "You are awesome.",
      "Thanks to BellBlitzKing for",
      "his Pokemon Sound Effects Pack:",
      "Gen 1 to Gen 7 - All Attacks SFX.",
      "Kirik<s>Marin",
      "Maruno<s>AiurJordan",
      "Appletun<s>ThatWelshOne_",
      "",
      _INTL("4th gen style battle sprites:"),
      "TheLuiz<s>leparagon",
      "French-Cyndaquil<s>Z-nogyroP",
      "Prodigal96<s>TheLuiz",
      "Vanilla Sunshine<s>fishbowlsoul90",
      "zlolxd<s>elazulmax",
      "mangamanga<s>MrDollSteak",
      "Spherical-Ice<s>Dreadwing93",
      "Smogon Gen 8 Sprite Project",
      "Smogon Sun/Moon Sprite Project",
      "Gen VI: Pokémon Sprite Resource",
      "",
      "Updated Poké Ball sprites:",
      "SrGio<s>Pokepachito",
      "",
      "",_INTL("Gen 9 Pokemon icons:"),
      "CarnekVT<s>Divaruta 666",
      "Okyo<s>JLauz735 ",
      "JLauz735<s>ShenseyGrenin",
      "",
      "",_INTL("Regional Pokédexes:"),
      "HeddyGames",
      "",
      "",_INTL("Incubator:"),
      "Kyu",
      "",
      "",
      "",_INTL("Pokémon Footprints"),
      "भाग्य ज्योति<s>WolfPP ",
      "Caruban<s>komeiji514 ",
      "",
      "",
      "Pokémon Essentials v21.1",
      _INTL("Created by:"),
      "Maruno",
      "",
      _INTL("Also involved:"),
      "A. Lee Uss<s>Anne O'Nymus",
      "Ecksam Pell<s>Jane Doe",
      "Joe Dan<s>Nick Nayme",
      "Sue Donnim<s>"
    ]
  end


end

#===============================================================================
# Enhanced Bag Screen Settings
#===============================================================================
module BagScreenWiInParty
  PANORAMA = true
  BGSTYLE = 0
  SHINYICON = true
  PKRSICON  = true
  # Search and Sort button text positions
  SEARCH_TEXT_X = 232
  SEARCH_TEXT_Y = 4
  SORT_TEXT_X = 317
  SORT_TEXT_Y = 4
  # Search and Sort button icon positions
  SEARCH_ICON_X = 226
  SEARCH_ICON_Y = -1
  SORT_ICON_X = 311
  SORT_ICON_Y = -1
  # Search and Sort button text and icon scales
  SEARCH_TEXT_SCALE = 1.0
  SEARCH_ICON_SCALE = 0.85
  SORT_TEXT_SCALE = 1.0
  SORT_ICON_SCALE = 0.85
end

#===============================================================================
# FANCY CAMERA
#===============================================================================
# Set to true to use the fancy camera with new features
# This is the switch number
CAMERA_FANCY = 59

#===============================================================================
# SPECIAL POKÉMON STORAGE OPTIONS
#===============================================================================
STORAGE_ARROW_PATH = "Graphics/UI/Storage/"
CAN_SWAP_BOXES   = true
CAN_MULTI_SELECT = true
CAN_MASS_RELEASE = true
CAN_BOX_POUR     = true

################################################################################
# ANIMATED SPRITES CONFIGURATION
################################################################################
FRONTSPRITE_SCALE = 1
BACKSPRITE_SCALE  = 1

################################################################################
# Show remaining egg steps in summary screen
################################################################################
SHOW_EGG_STEPS = false

################################################################################
# MAPS WITHOUT REFLECTIONS
################################################################################
NO_REFLECTION_MAPS = []

################################################################################
# REGIONAL FORMS POKÉMON LIST
################################################################################
REGIONAL_SPECIES = [:RATTATA,:RATICATE,:RAICHU,:SANDSHREW,:SANDSLASH,:VULPIX,:NINETALES,:DIGLETT,:DUGTRIO,
                    :MEOWTH,:PERSIAN,:GEODUDE,:GRAVELER,:GOLEM,:PONYTA,:RAPIDASH,:SLOWPOKE,:SLOWBRO,:FARFETCHD,:GRIMER,:MUK,
                    :EXEGGUTOR,:MAROWAK,:WEEZING,:MRMIME,:ARTICUNO,:ZAPDOS,:MOLTRES,:SLOWKING,:CORSOLA,
                    :ZIGZAGOON,:LINOONE,:DARUMAKA,:DARMANITAN,:YAMASK,:STUNFISK,:LYCANROC, :GROWLITHE,:ARCANINE,
                    :VOLTORB,:ELECTRODE,:TAUROS,:TYPHLOSION,:WOOPER,:QWILFISH,:SNEASEL,:SAMUROTT,
                    :LILLIGANT,:ZORUA,:ZOROARK,:BRAVIARY,:SLIGGOO,:GOODRA,:BERGMITE,:AVALUGG,:DECIDUEYE,
                    :PIKACHU, :URSALUNA, :FLABEBE, :FLOETTE, :FLORGES, :SHELLOS, :GASTRODON, :BURMY, :WORMADAM,
                    :ORICORIO, :BASCULIN, :SQUAWKABILLY, :VIVILLON]

#######################################################################################
# FORMS BLACKLIST
########################################################################################
FORMS_BLACKLIST = {:DARMANITAN => [1, 3]}
CURRENT_SPECIES_BLACKLIST = [:FLOETTE_5]
SHOW_SPRITES_IN_FORM_CHANGER = true
