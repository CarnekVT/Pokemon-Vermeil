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
    "aggressive_level_bonus" => ["Agresivo: niveles EXTRA al entrar en batalla",(0..20).map(&:to_s)],
    "hud_position" => ["Posición del HUD",%w[bottom_right bottom_left top_right top_left]],
    "hud_scale" => ["Tamaño del HUD (%)",%w[70 85 100 115 130 140]],
    "hud_opacity" => ["Opacidad HUD (%)",%w[30 50 70 85 100]],
    "hud_controls" => ["Ayudas de controles",%w[auto always off]],
    "throw_cooldown_frames" => ["Cooldown entre Balls (frames)",%w[0 8 12 17 24 36]],
    "escape_reaction_enabled" => ["Contraataque al liberarse",%w[0 1]],
    "pressure_enabled" => ["Presión por fallos",%w[0 1]],
    "pressure_alert_threshold" => ["Umbral de alerta",%w[20 30 35 45 60]],
    "pressure_block_threshold" => ["Bloqueo captura directa",%w[60 70 80 90 100]],
    "timid_reaction_frames" => ["Aviso previo de miedosos",%w[0 20 35 48 60 75]],
    "pressure_escape_frames" => ["Alerta al huir",%w[0 180 360 600]],
    "escape_reaction_chance" => ["Probabilidad de contraataque (%)",%w[0 10 25 40 60 80 100]],
    "escape_reaction_hp_percent" => ["Coste al equipo: % PS (no debilita)",%w[0 5 8 10 15 20]],
    "aggressive_lunge_distance" => ["Radio de embestida agresiva",(1..8).map(&:to_s)],
    "temperament_indicators" => ["Señales de temperamento",%w[0 1]],
    "aggressive_chase_speed" => ["Velocidad agresivos",(1..6).map(&:to_s)],
    "aggressive_notice_frames" => ["Preparación antes de perseguir",(0..60).step(5).map(&:to_s)],
    "aggressive_step_pause" => ["Pausa entre pasos",(0..30).step(2).map(&:to_s)],
    "aggressive_attack_windup" => ["Preparación antes del combate",(0..60).step(5).map(&:to_s)],
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
