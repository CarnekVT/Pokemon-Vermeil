# frozen_string_literal: true

# Traduce un método de evolución (símbolo + parámetro crudo de PBS) a una frase
# legible en español. Cubre los métodos vanilla de Essentials 21.1 y los propios
# de La Base de Sky.
#
# ponytail: tabla de plantillas con hueco para lo raro. Un método no listado cae
# al formato genérico "<Método> (<parámetro>)"; añadir su frase aquí cuando
# aparezca.
module EvolutionText
  module_function

  # @param method [Symbol] p.ej. :Level, :Item, :Trade
  # @param param [Integer, Symbol, String, nil] parámetro tal como lo guarda GameData
  # @return [String]
  def describe(method, param)
    tmpl = TEMPLATES[method]
    return tmpl.call(param) if tmpl

    base = HUMAN.fetch(method, method.to_s)
    p = pretty_param(method, param)
    p.empty? ? base : "#{base} (#{p})"
  end

  # Nombre de item/movimiento/tipo/especie legible; si no, el valor crudo.
  def pretty_param(method, param)
    return "" if param.nil? || param == 0 || param == ""

    kind = (defined?(GameData::Evolution) && GameData::Evolution.try_get(method)&.parameter)
    case kind
    when :Item    then GameData::Item.try_get(param)&.name    || param.to_s
    when :Move    then GameData::Move.try_get(param)&.name     || param.to_s
    when :Type    then GameData::Type.try_get(param)&.name     || param.to_s
    when :Species then GameData::Species.try_get(param)&.name  || param.to_s
    else param.to_s
    end
  end

  def item(param)  = GameData::Item.try_get(param)&.name    || param.to_s
  def move(param)  = GameData::Move.try_get(param)&.name     || param.to_s
  def type(param)  = GameData::Type.try_get(param)&.name     || param.to_s

  # Frases completas para métodos con matices que el formato genérico no capta.
  TEMPLATES = {
    None:              ->(_)  { "No evoluciona" },
    Level:             ->(n)  { "Nivel #{n}" },
    LevelMale:         ->(n)  { "Nivel #{n}, siendo macho" },
    LevelFemale:       ->(n)  { "Nivel #{n}, siendo hembra" },
    LevelDay:          ->(n)  { "Nivel #{n}, de día" },
    LevelNight:        ->(n)  { "Nivel #{n}, de noche" },
    LevelMorning:      ->(n)  { "Nivel #{n}, por la mañana" },
    LevelAfternoon:    ->(n)  { "Nivel #{n}, por la tarde" },
    LevelEvening:      ->(n)  { "Nivel #{n}, al anochecer" },
    LevelNoWeather:    ->(n)  { "Nivel #{n}, sin clima especial" },
    LevelSun:          ->(n)  { "Nivel #{n}, con sol" },
    LevelRain:         ->(n)  { "Nivel #{n}, con lluvia" },
    LevelSnow:         ->(n)  { "Nivel #{n}, nevando" },
    LevelSandstorm:    ->(n)  { "Nivel #{n}, con tormenta de arena" },
    LevelCycling:      ->(n)  { "Nivel #{n}, montando en bici" },
    LevelSurfing:      ->(n)  { "Nivel #{n}, surfeando" },
    LevelDiving:       ->(n)  { "Nivel #{n}, buceando" },
    LevelDarkness:     ->(n)  { "Nivel #{n}, en un lugar oscuro" },
    LevelDarkInParty:  ->(n)  { "Nivel #{n}, con un Pokémon Siniestro en el equipo" },
    LevelRandForm:     ->(n)  { "Nivel #{n} (forma al azar)" },
    LevelCoins:        ->(n)  { "Nivel con #{n} monedas" },
    LevelBattle:       ->(n)  { "Nivel #{n}, subiendo en combate" },
    AttackGreater:     ->(n)  { "Nivel #{n}, con Ataque > Defensa" },
    AtkDefEqual:       ->(n)  { "Nivel #{n}, con Ataque = Defensa" },
    DefenseGreater:    ->(n)  { "Nivel #{n}, con Defensa > Ataque" },
    Silcoon:           ->(n)  { "Nivel #{n} (según personalidad)" },
    Cascoon:           ->(n)  { "Nivel #{n} (según personalidad)" },
    Ninjask:           ->(n)  { "Nivel #{n}" },
    Shedinja:          ->(_)  { "Aparece al evolucionar si hay hueco y una Poké Ball" },
    Happiness:         ->(_)  { "Amistad alta" },
    HappinessMale:     ->(_)  { "Amistad alta, siendo macho" },
    HappinessFemale:   ->(_)  { "Amistad alta, siendo hembra" },
    HappinessDay:      ->(_)  { "Amistad alta, de día" },
    HappinessNight:    ->(_)  { "Amistad alta, de noche" },
    HappinessMove:     ->(m)  { "Amistad alta conociendo #{move(m)}" },
    HappinessMoveType: ->(t)  { "Amistad alta conociendo un movimiento de tipo #{type(t)}" },
    HappinessHoldItem: ->(i)  { "Amistad alta llevando #{item(i)}" },
    MaxHappiness:      ->(_)  { "Amistad al máximo" },
    Beauty:            ->(n)  { "Belleza #{n} o más" },
    HoldItem:          ->(i)  { "Subir de nivel llevando #{item(i)}" },
    HoldItemMale:      ->(i)  { "Subir de nivel llevando #{item(i)}, siendo macho" },
    HoldItemFemale:    ->(i)  { "Subir de nivel llevando #{item(i)}, siendo hembra" },
    DayHoldItem:       ->(i)  { "Subir de nivel de día llevando #{item(i)}" },
    NightHoldItem:     ->(i)  { "Subir de nivel de noche llevando #{item(i)}" },
    HoldItemHappiness: ->(i)  { "Amistad alta llevando #{item(i)}" },
    HasMove:           ->(m)  { "Subir de nivel conociendo #{move(m)}" },
    HasMoveRandForm:   ->(m)  { "Subir de nivel conociendo #{move(m)} (forma al azar)" },
    HasMoveType:       ->(t)  { "Subir de nivel conociendo un movimiento de tipo #{type(t)}" },
    HasInParty:        ->(s)  { "Subir de nivel con #{GameData::Species.try_get(s)&.name || s} en el equipo" },
    Location:          ->(n)  { "Subir de nivel en un lugar concreto (mapa #{n})" },
    LocationFlag:      ->(f)  { "Subir de nivel en una zona marcada como \"#{f}\"" },
    Region:            ->(n)  { "Subir de nivel en la región #{n}" },
    Item:              ->(i)  { "Usar #{item(i)}" },
    ItemMale:          ->(i)  { "Usar #{item(i)}, siendo macho" },
    ItemFemale:        ->(i)  { "Usar #{item(i)}, siendo hembra" },
    ItemDay:           ->(i)  { "Usar #{item(i)} de día" },
    ItemNight:         ->(i)  { "Usar #{item(i)} de noche" },
    ItemHappiness:     ->(i)  { "Usar #{item(i)} con amistad alta" },
    Trade:             ->(_)  { "Intercambio" },
    TradeMale:         ->(_)  { "Intercambio, siendo macho" },
    TradeFemale:       ->(_)  { "Intercambio, siendo hembra" },
    TradeDay:          ->(_)  { "Intercambio de día" },
    TradeNight:        ->(_)  { "Intercambio de noche" },
    TradeItem:         ->(i)  { "Intercambio llevando #{item(i)}" },
    TradeSpecies:      ->(s)  { "Intercambio por #{GameData::Species.try_get(s)&.name || s}" },
    Event:             ->(_)  { "Evento especial" },
    EventReady:        ->(_)  { "Evento especial" },
    # Métodos propios de La Base de Sky
    CableLinkItem:              ->(i) { "Usar Cordón Unión llevando #{item(i)}" },
    CollectItems:               ->(i) { "Tener 999 unidades de #{item(i)} en la mochila" },
    LevelWithPartner:           ->(n) { "Nivel #{n} con un Pokémon aliado (partner)" },
    LevelUseMoveCount:          ->(m) { "Usar #{move(m)} 20 veces" },
    LevelDefeatItsKindWithItem: ->(i) { "Derrotar 3 de su especie llevando #{item(i)}" },
    LevelRecoilDamage:          ->(n) { "Acumular #{n} de daño por retroceso" },
    LevelRecoilDamageForm0:     ->(n) { "Acumular #{n} de daño por retroceso" },
    LevelWalk:                  ->(n) { "Caminar #{n} pasos" }
  }.freeze

  HUMAN = {
    AfterBattleCounter:            "Tras varios combates",
    AfterBattleCounterMakeReady:   "Tras varios combates",
    AfterBattleCritCounter:        "Tras asestar varios golpes críticos",
    Counter:                       "Tras subir de nivel varias veces",
    EventAfterDamageTaken:         "Evento tras recibir daño"
  }.freeze
end
