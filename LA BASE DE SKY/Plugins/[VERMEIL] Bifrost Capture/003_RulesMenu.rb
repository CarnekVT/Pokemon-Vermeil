# frozen_string_literal: true
# Reglas ingame opcionales. Cambios locales a la partida, sin editar el INI.
module BifrostCapture
  PLAYER_OPTIONS = {
    "capture_enabled"=>"Captura directa",
    "battle_enabled"=>"Iniciar combates desde OW",
    "restricted_species"=>"Solo especies catálogo Bifröst",
    "line_of_sight"=>"Obstáculos bloquean lanzamientos",
    "consume_on_miss"=>"Consumir Balls falladas"
  }.freeze
  ACCESS_LABELS = {
    "event"=>"Solo por evento",
    "always"=>"Siempre disponible",
    "nearby"=>"Con OW elegible cerca"
  }.freeze
  ENCOUNTER_LABELS = {
    "classic"=>"Hierba clásica",
    "hybrid"=>"Encuentros mixtos",
    "overworld"=>"OW completo"
  }.freeze
  KEY_LABELS = {
    "aux2"=>"R (Aux2)",
    "aux1"=>"L (Aux1)",
    "none"=>"Sin atajo"
  }.freeze

  def self.rules_menu
    return false unless $PokemonGlobal
    loop do
      settings = options
      keys = PLAYER_OPTIONS.keys
      choices = keys.map do |key|
        _INTL("{1}: {2}", PLAYER_OPTIONS[key], settings[key]=="1" ? "Sí" : "No")
      end
      choices << _INTL("Acceso: {1}", ACCESS_LABELS[settings["access_mode"]] || "Solo por evento")
      choices << _INTL("Atajo: {1}", KEY_LABELS[settings["hotkey"]] || "Sin atajo")
      choices << _INTL("Encuentros: {1}", ENCOUNTER_LABELS[settings["encounter_mode"]] || "Hierba clásica")
      choices << _INTL("Restaurar reglas del proyecto")
      choices << _INTL("Salir")
      idx = pbMessage(_INTL("Reglas de lanzamiento"),choices,choices.length-1)
      return true if idx < 0 || idx == choices.length-1
      if idx < keys.length
        key = keys[idx]
        set_rule(key,settings[key]=="1" ? "0" : "1")
      elsif idx == keys.length
        modes = ACCESS_LABELS.keys
        labels = ACCESS_LABELS.values
        current = modes.index(settings["access_mode"]) || 0
        selected = pbMessage(_INTL("¿Cuándo se puede apuntar?"), labels + [_INTL("Cancelar")], labels.length, nil, current)
        set_rule("access_mode", modes[selected]) if selected >= 0 && selected < modes.length
      elsif idx == keys.length+1
        modes = KEY_LABELS.keys
        labels = KEY_LABELS.values
        current = modes.index(settings["hotkey"]) || 0
        selected = pbMessage(_INTL("¿Qué tecla abre el apuntado?"), labels + [_INTL("Cancelar")], labels.length, nil, current)
        set_rule("hotkey", modes[selected]) if selected >= 0 && selected < modes.length
      elsif idx == keys.length+2
        modes = ENCOUNTER_LABELS.keys
        labels = ENCOUNTER_LABELS.values
        current = modes.index(settings["encounter_mode"]) || 0
        selected = pbMessage(_INTL("¿Cómo aparecen los Pokémon?"), labels + [_INTL("Cancelar")], labels.length, nil, current)
        set_rule("encounter_mode",modes[selected]) if selected >= 0 && selected < modes.length
      else
        $PokemonGlobal.bifrost_overrides = {}
        pbMessage(_INTL("Restauradas las reglas del proyecto."))
      end
    end
  end

  def self.reset_event(map_id,event_id)
    return false unless $PokemonGlobal && $PokemonGlobal.bifrost_removed_events
    $PokemonGlobal.bifrost_removed_events.delete([map_id,event_id])
    true
  end
end

def pbBifrostRulesMenu
  BifrostCapture.rules_menu
end
