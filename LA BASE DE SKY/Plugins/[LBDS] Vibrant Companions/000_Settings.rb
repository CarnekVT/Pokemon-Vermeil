#===============================================================================
# VIBRANT COMPANIONS - SETTINGS
# Configuración Global del Sistema de Followers
#===============================================================================

module VibrantCompanions
  module Settings
    #---------------------------------------------------------------------------
    # FEATURE TOGGLES
    # Si están en false, la función se desactiva por completo
    #---------------------------------------------------------------------------
    # Permite que te siga todo el equipo en fila india. (Desactivado por defecto)
    ALLOW_CATERPILLAR_MODE = false
    
    # Permite que los Pokémon te sigan dentro de edificios y cuevas.
    ALLOW_INDOORS          = true
    
    # Permite que el Pokémon camine a tu alrededor al estar quieto. (Inestable)
    ALLOW_WANDERING        = false
    
    # Permite que los Pokémon muevan las patas incluso estando quietos.
    ALLOW_ALWAYS_ANIMATE   = true
    
    # Permite que el Pokémon encuentre objetos al caminar.
    ALLOW_ITEM_GATHERING   = false

    # Permite interactuar con el Pokémon que te sigue.
    ALLOW_INTERACT         = true

    # Permite activar/desactivar la opcion de hablar con los Pokemon desde los ajustes del juego.
    ALLOW_DISABLE_TALK_TO_FOLLOWER = true

    #---------------------------------------------------------------------------
    # CONFIGURACIÓN ESTÁTICA
    #---------------------------------------------------------------------------
    # Tecla para sacar o guardar a los Pokémon.
    TOGGLE_KEY = Input::JUMPUP

    # Esta tecla permite al jugador recorrer rápidamente su equipo de Pokémon. 
    # Establece ENABLE_PARTY_CYCLING como true si quieres activar esta funcion
    # Input::JUMPDOWN es la tecla S - rota el grupo hacia adelante (el primer Pokémon va al final)
    # Input::AUX2 es la tecla W - rota el grupo hacia atrás (el último Pokémon va al principio)
    ENABLE_PARTY_CYCLING     = false
    CYCLE_PARTY_FORWARD_KEY  = Input::JUMPDOWN
    CYCLE_PARTY_BACKWARD_KEY = Input::AUX2
    
    # ID de la animación al salir de la Poké Ball.
    ANIM_APPEAR = 30
    
    # ID de la animación al regresar a la Poké Ball.
    ANIM_RECALL = 29

    # Segundos de inactividad antes de que el Pokémon empiece a deambular.
    IDLE_START_TIME = 3.0 
    
    # Segundos de pausa entre cada paso al deambular.
    WANDER_STEP_DELAY = 1.5
    
    # Distancia máxima (en casillas) que el Pokémon puede alejarse al deambular.
    WANDER_RADIUS = 3
    
    # Velocidad de la animación de las patas cuando el Pokémon está quieto.
    IDLE_ANIMATION_SPEED = 0.6

    # Pasos que el jugador debe dar para que el Pokémon intente buscar un objeto.
    ITEM_STEP_THRESHOLD = 200
    
    # Probabilidad (en %) de encontrar un objeto tras dar los pasos necesarios.
    ITEM_CHANCE = 15
    
    # Lista de objetos que puede encontrar y su peso de probabilidad (Hash).
    GATHER_ITEMS = {
      :ORANBERRY    => 40,
      :PECHABERRY   => 30,
      :CHERIBERRY   => 30,
      :RAWSTBERRY   => 30,
      :POTION       => 40,
      :ANTIDOTE     => 30,
      :PARALYZEHEAL => 30,
      :TINYMUSHROOM => 15,
      :PEARL        => 10,
      :STARDUST     => 5,
      :RARECANDY    => 1
    }

    # Permite que el Pokémon haga animaciones al interactuar.
    ENABLE_PHYSICAL_EMOTES = true
    
    # Si es true, el Pokémon líder se deslizará hacia la batalla en lugar de 
    # salir de una Poké Ball.
    SLIDE_INTO_BATTLE = true

    #---------------------------------------------------------------------------
    # CONFIGURACIÓN DE ESPACIADO INTELIGENTE
    #---------------------------------------------------------------------------
    # Activa el sistema de colisión visual para evitar que los sprites se superpongan.
    ENABLE_SMART_SPACING       = true  
    
    # Aplica la separación visual también entre los miembros del modo tren.
    ENABLE_TRAIN_SMART_SPACING = true  
    
    # Píxeles exactos de separación entre cada sprite.
    SMART_SPACING_GAP          = 2     

    #---------------------------------------------------------------------------
    # EASTER EGGS
    #---------------------------------------------------------------------------
    # Aún experimental.
    ENABLE_EASTER_EGGS = false

    #---------------------------------------------------------------------------
    # CONFIGURACIÓN DINÁMICA
    #---------------------------------------------------------------------------
    def self.enable_caterpillar?
      return false unless ALLOW_CATERPILLAR_MODE
      return true if !$PokemonSystem
      return $PokemonSystem.vibrant_caterpillar == 0
    end

    def self.max_followers
      return 1 unless ALLOW_CATERPILLAR_MODE
      return 6 if !$PokemonSystem
      return ($PokemonSystem.vibrant_max_followers || 5) + 1
    end

    def self.allow_indoors?
      return false unless ALLOW_INDOORS
      return true if !$PokemonSystem
      return $PokemonSystem.vibrant_indoors == 0
    end

    def self.enable_wandering?
      return false unless ALLOW_WANDERING
      return true if !$PokemonSystem
      return $PokemonSystem.vibrant_wandering == 0
    end

    def self.always_animate?
      return false unless ALLOW_ALWAYS_ANIMATE
      return true if !$PokemonSystem
      return $PokemonSystem.vibrant_always_animate == 0
    end

    def self.enable_item_gathering?
      return ALLOW_ITEM_GATHERING
    end

    def self.allow_interact?
      return ALLOW_INTERACT unless $PokemonSystem
      return $PokemonSystem.vibrant_interact == 0
    end
  end
end