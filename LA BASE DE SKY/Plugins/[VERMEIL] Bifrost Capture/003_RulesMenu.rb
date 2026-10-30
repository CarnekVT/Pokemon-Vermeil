# frozen_string_literal: true
# Optional in-game settings. Saved per playthrough, never modifies config.ini.
module BifrostCapture
  RULE_CHOICES = {
    "capture_enabled" => ["Captura en el mapa",["0","1"]],
    "battle_enabled" => ["Enviar Pokémon",["0","1"]],
    "restricted_species" => ["Solo catálogo Bifröst",["0","1"]],
    "access_mode" => ["Disponibilidad",["event","always","nearby"]],
    "control_mode" => ["Control",["toggle","hold"]],
    "encounter_mode" => ["Encuentros",["classic","hybrid","overworld"]],
    "reaction" => ["Reacción",["flee","attack","ignore"]],
    "aim_keyboard" => ["Apuntado con teclado",["0","1"]],
    "aim_mouse" => ["Apuntado con ratón",["0","1"]],
    "hotkey" => ["Abrir apuntado",["aux1","aux2","none"]]
  }.freeze

  def self.rules_menu
    return false unless $PokemonGlobal
    loop do
      cfg = options
      keys = RULE_CHOICES.keys
      labels = keys.map do |key|
        text, _values = RULE_CHOICES[key]
        _INTL("{1}: {2}".dup,text,cfg[key])
      end
      labels << _INTL("Restaurar configuración del proyecto")
      labels << _INTL("Salir")
      choice = pbMessage(_INTL("Bifröst · Configuración"),labels,labels.length-1)
      break if choice < 0 || choice == labels.length-1
      if choice == labels.length-2
        reset_rules
        next
      end
      key = keys[choice]
      title,values = RULE_CHOICES[key]
      options_labels = values.map { |v| v == "1" ? "Sí" : v == "0" ? "No" : v }
      options_labels << _INTL("Cancelar")
      picked = pbMessage(title,options_labels,options_labels.length-1)
      set_rule(key,values[picked]) if picked >= 0 && picked < values.length
    end
    true
  end

  def self.reset_event(map_id,event_id)
    return false unless $PokemonGlobal
    ($PokemonGlobal.bifrost_removed_events || {}).delete([map_id,event_id])
    true
  end
end

def pbBifrostRulesMenu
  BifrostCapture.rules_menu
end
