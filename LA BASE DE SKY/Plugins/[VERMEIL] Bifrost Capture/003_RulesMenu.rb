# frozen_string_literal: true
# Menu de reglas opcional accesible desde evento / menu propio.
module BifrostCapture
  PLAYER_OPTIONS = {
    "capture_enabled"=>"Captura directa",
    "battle_enabled"=>"Iniciar combates desde OW",
    "line_of_sight"=>"Obstaculos bloquean lanzamientos",
    "consume_on_miss"=>"Consumir Balls falladas"
  }.freeze

  def self.rules_menu
    return false unless $PokemonGlobal
    loop do
      settings = options
      choices = PLAYER_OPTIONS.map do |key,label|
        _INTL("{1}: {2}",label,settings[key]=="1" ? "Sí" : "No")
      end
      choices << _INTL("Restaurar reglas del proyecto")
      choices << _INTL("Salir")
      idx = pbMessage(_INTL("Reglas de lanzamiento"),choices,choices.length-1)
      return true if idx < 0 || idx == choices.length-1
      if idx == choices.length-2
        $PokemonGlobal.bifrost_overrides = {}
        pbMessage(_INTL("Restauradas las reglas del proyecto."))
      else
        key = PLAYER_OPTIONS.keys[idx]
        set_rule(key,settings[key]=="1" ? "0" : "1")
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
