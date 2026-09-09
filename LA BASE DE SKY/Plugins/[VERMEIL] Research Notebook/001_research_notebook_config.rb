# encoding: UTF-8
#===============================================================================
# Libreta de Investigación - Configuración
# Pokémon Essentials v21.1
#===============================================================================
module ResearchNotebook
  module Settings
    SCREEN_WIDTH  = 640
    SCREEN_HEIGHT = 480

    # Orden del catálogo.
    # :GAME     -> usa la Pokédex regional/del juego indicada abajo.
    # :NATIONAL -> usa el número Nacional.
    DEX_ORDER = :GAME
    GAME_DEX_INDEX = 0

    # Fuentes de verdad. La Libreta NO duplica la configuración de las mecánicas.
    GOLDEN_SPECIES_JSON = "Data/GoldenSystem/species.json"
    ARCANE_SPECIES_JSON = "Data/ArcaneAbilities/species.json"

    # Objetos relacionados con las mecánicas.
    ARCANE_TEA_ITEM      = :ARCANETEA
    GOLDEN_FRAGMENT_ITEM = :GOLDENFRAGMENT
    GOLDEN_STONE_ITEM    = :GOLDENSTONE
    GOLDEN_RING_ITEM     = :GOLDENSRING

    # Acceso. Durante desarrollo es útil tenerla también en Debug.
    SHOW_IN_PAUSE_MENU = true
    SHOW_IN_DEBUG_MENU = true
    NOTEBOOK_AVAILABLE_FROM_START = false
    MENU_ORDER = 45

    # Entradas no capturadas de los sistemas especiales.
    # false = solo lo que el protagonista conoce.
    # true  = deja huecos/siluetas para todo lo configurado.
    SHOW_UNOWNED_ENTRIES = true

    REVEAL_ARCANE_POTENTIAL_ON_CAPTURE = true
    REVEAL_GOLDEN_TYPE_BEFORE_USE      = true
    REVEAL_GOLDEN_SPRITE_ON_SEEN       = true
    GOLDEN_DETAILS_REQUIRE_USE         = true

    # Gamefeel. Todo se dibuja por código; no requiere assets adicionales.
    ENABLE_OPEN_ANIMATION       = true
    ENABLE_PAGE_TURN_ANIMATION  = true
    ENABLE_CURSOR_PULSE         = false
    ENABLE_SECTION_MOTIF        = true
    ENABLE_FOCUS_BREATH         = false
    ENABLE_GRID_ICON_PULSE      = false

    # Duraciones en frames. Breves, pero lo bastante visibles para que abrir/cerrar
    # y pasar página se sientan como acciones de una libreta.
    # Ritmo visual: centralizado para poder ajustar la sensación sin tocar la UI.
    # 60 frames = 1 segundo en Essentials.
    OPEN_ANIMATION_FRAMES   = 18
    PAGE_TURN_FRAMES        = 16
    CONTENT_FADE_FRAMES     = 6
    PAGE_TURN_MIN_FRAMES    = 8

    # Gráficos custom para la forma áurea. La ruta es relativa a Graphics/.
    GOLDEN_FORM_SPRITE_ROOT = "Graphics/Pokemon/GoldenForms"

    # Información global mostrada en la página de Forma Dorada.
    # Se genera dinámicamente desde GoldenSystem.settings[:form_hp_drain] (ej: 0.25 = "1/4")
    GOLDEN_FORM_DRAIN_TEXT = nil

    # Catálogo estilo MegaDex: vista focal a la izquierda y cuadrícula a la derecha.
    GRID_COLUMNS = 5
    GRID_ROWS    = 5
    DEFAULT_SORT = :DEX       # :DEX / :NAME / :STATUS

    # Usa el spritesheet de tipos del propio proyecto. No se incluyen gráficos
    # duplicados en este plugin. `Graphics/UI/types` es la ruta principal de v21.1.
    TYPE_SHEET_CANDIDATES = [
      "Graphics/UI/types",
      "Graphics/UI/Pokedex/types",
      "Graphics/UI/Pokedex/icon_types"
    ]

# ChangeDex: ocultar formas listadas en config.json (megas, etc.).
    USE_CHANGEDEX_HIDDEN_FORMS = true
    CHANGEDEX_CONFIG_JSON = "Data/ChangeDex/config.json"
    CHANGEDEX_CHANGES_JSON  = "Data/ChangeDex/pokemon_changes.json"
    # Formas de ChangeDex que sí deben permanecer visibles en la Libreta.
    # Acepta "ESPECIE,FORMA" para una forma concreta o "ESPECIE" para todas
    # las formas de esa especie. Se consulta después de hiddenForms.
    CHANGEDEX_VISIBLE_FORMS = []

    # Formas especiales a incluir en la sección Áureo (Megas, Gigamax, etc.).
    # Se obtienen de GameData::Species y se filtran por ChangeDex.
    INCLUDE_SPECIAL_FORMS_IN_GOLDEN = true
    # Tipos de forma considerados "especiales" para la sección Áureo.
    GOLDEN_SPECIAL_FORM_TYPES = [:MEGA, :GIGANTAMAX, :PRIMAL, :ULTRA_BURST, :ETERNAMAX]

    # Incluir formas alternas en la sección Habilidades Arcanas.
    INCLUDE_ALTERNATE_FORMS_IN_ARCANE = true

    # Incluir Forma 1 (Pikachu, Cubone, Exeggutor Alola, etc.) en Áureo.
    # Requiere que la forma exista en ChangeDex (config.json + pokemon_changes.json)
    # para ser editable en Golden Studio / Arcane Ability Studio.
    INCLUDE_FORM_ONE_IN_GOLDEN = true

    # Incluir Forma 1 en Habilidades Arcanas.
    INCLUDE_FORM_ONE_IN_ARCANE = true

MENU_NAME = "Libreta"
  end
end
