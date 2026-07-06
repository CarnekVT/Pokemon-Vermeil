# encoding: utf-8
#===============================================================================
# [ZBOX] Vibrant Adapted — Settings
# Fusión de Following Pokemon EX + Vibrant Companions
#===============================================================================

module VibrantAdapted
  module Settings
    #--- Toggle ---
    TOGGLE_KEY            = Input::JUMPUP
    CYCLE_PARTY_FORWARD_KEY  = Input::JUMPDOWN
    CYCLE_PARTY_BACKWARD_KEY = Input::AUX2

    #--- Animaciones ---
    ANIM_APPEAR    = 30
    ANIM_RECALL     = 29
    ANIM_EMOTE_HEART    = 9
    ANIM_EMOTE_MUSIC    = 12
    ANIM_EMOTE_HAPPY    = 10
    ANIM_EMOTE_ELLIPSES = 13
    ANIM_EMOTE_ANGRY    = 15
    ANIM_EMOTE_POISON   = 17
    DUST_ANIMATION_ID   = 31

    #--- Spacing (de Following Pokemon EX) ---
    FOLLOWER_DISTANCE_OFFSET = 12

    FOLLOWER_DISTANCE_EXCEPTIONS = {
      :VENUSAUR   => 24, :CHARIZARD  => 24, :BLASTOISE  => 24,
      :ONIX       => 32, :GYARADOS   => 32, :LAPRAS     => 24,
      :SNORLAX    => 24, :ARTICUNO   => 24, :ZAPDOS     => 24,
      :MOLTRES    => 24, :DRAGONITE  => 24, :MEWTWO     => 24,
      :RHYDON     => 24,
      :MEGANIUM   => 24, :FERALIGATR => 24, :STEELIX    => 32,
      :LUGIA      => 32, :HOOH       => 32, :TYRANITAR  => 24,
      :SCEPTILE   => 24, :SWAMPERT   => 24, :WAILORD    => 40,
      :AGGRON     => 24, :METAGROSS  => 24, :REGIROCK   => 24,
      :REGICE     => 24, :REGISTEEL  => 24, :KYOGRE     => 40,
      :GROUDON    => 40, :RAYQUAZA   => 40,
      :TORTERRA   => 32, :GARCHOMP   => 24, :RHYPERIOR  => 32,
      :DIALGA     => 40, :PALKIA     => 40, :HEATRAN    => 24,
      :REGIGIGAS  => 32, :GIRATINA   => 40, :ARCEUS     => 32,
      :SERPERIOR  => 24, :SCOLIPEDE  => 32, :GIGALITH   => 24,
      :RESHIRAM   => 40, :ZEKROM     => 40, :KYUREM     => 40,
      :XERNEAS    => 32, :YVELTAL    => 32, :ZYGARDE    => 40,
      :HOOPA      => 32, :VOLCANION  => 24,
      :SOLGALEO   => 32, :LUNALA     => 32, :NECROZMA   => 32,
      :GUZZLORD   => 40, :STAKATAKA  => 40,
      :ETERNATUS  => 40, :ZAMAZENTA  => 24, :ZACIAN     => 24,
      :CALYREX    => 24, :REGIDRAGO  => 24, :REGIELEKI  => 24
    }

    #--- Comportamiento ---
    ALWAYS_FACE_PLAYER  = false
    ALWAYS_ANIMATE      = true
    IMPASSABLE_FOLLOWER = true
    SLIDE_INTO_BATTLE   = true
    ALWAYS_ON_TOP       = true

    #--- Status Tones ---
    APPLY_STATUS_TONES  = true
    TONE_BURN       = Tone.new(206, 73, 43, 0)
    TONE_POISON     = Tone.new(109, 55, 130, 0)
    TONE_PARALYSIS  = Tone.new(204, 152, 44, 0)
    TONE_FROZEN     = Tone.new(56, 160, 193, 0)
    TONE_SLEEP      = Tone.new(0, 0, 0, 80)
    TONE_NONE       = Tone.new(0, 0, 0, 0)

    #--- Idle animation speed ---
    # Frames por ciclo de patrón cuando el follower está quieto.
    # Valor bajo = más rápido. Ejemplo: 0.5 es fluido, 2.0 es lento.
    IDLE_ANIM_SPEED = 1.10

    #--- Walk/Surf animation speed ---
    # Aplica a la caminata y al surf. 
    # Usa 9999 para animación por pasos (estándar), o un valor bajo para ciclo continuo.
    WALK_ANIM_SPEED = 1.10

    #--- Run animation speed ---
    # Aplica a la carrera.
    # Usa 9999 para animación por pasos (estándar), o un valor bajo para ciclo continuo.
    RUN_ANIM_SPEED  = 1.10

    #--- Easter Eggs ---
    ENABLE_EASTER_EGGS  = true
    ENABLE_PHYSICAL_EMOTES = true

    #--- Wandering ---
    IDLE_START_TIME     = 3.0
    WANDER_RADIUS       = 3
    WANDER_STEP_DELAY   = 0.8

    #--- Item gathering (FPEX) ---
    FRIENDSHIP_TIME_TAKEN = 125
    ITEM_TIME_TAKEN      = 375

    #--- Opciones (persistidas en PokemonSystem) ---
    def self.enable_wandering?
      return $PokemonSystem.vibrant_wandering == 0 rescue true
    end

    def self.always_animate?
      return $PokemonSystem.vibrant_always_animate == 0 rescue false
    end

    def self.allow_interact?
      return $PokemonSystem.vibrant_interact == 0 rescue true
    end

    def self.allow_indoors?
      return $PokemonSystem.vibrant_indoors == 0 rescue false
    end

    def self.water_tile?(x, y)
      return false unless $game_map
      terrain = $game_map.terrain_tag(x, y)
      return terrain && terrain.can_surf
    end
  end
end
