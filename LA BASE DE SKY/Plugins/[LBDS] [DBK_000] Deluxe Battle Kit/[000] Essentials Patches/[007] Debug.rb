#===============================================================================
# Menu code for the application of battle rules via the debug menu.
#===============================================================================
class BattleRulesDebug
  def pbDebugMenu
    @commands = pbGetBattleRuleList
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99999
    sprites = {}
    sprites["textbox"] = pbCreateMessageWindow
    sprites["textbox"].letterbyletter = false
    sprites["cmdwindow"] = Window_CommandPokemonEx.new(@commands.list)
    cmdwindow = sprites["cmdwindow"]
    cmdwindow.x        = 0
    cmdwindow.y        = 0
    cmdwindow.width    = Graphics.width
    cmdwindow.height   = Graphics.height - sprites["textbox"].height
    cmdwindow.viewport = viewport
    cmdwindow.visible  = true
    sprites["textbox"].text = @commands.getDesc(cmdwindow.index)
    refresh = true
    @selecting = false
    loop do
      if refresh
        @commands = pbGetBattleRuleList
        cmdwindow.commands = @commands.list
        cmdwindow.index = 0
        refresh = false
      end
      cmdwindow.update
      sprites["textbox"].text = @commands.getDesc(cmdwindow.index)
      Graphics.update
      Input.update
      if Input.trigger?(Input::BACK)
        if @selecting
          pbPlayCancelSE
          @selecting = false
          refresh = true
        else
          break
        end
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        cmd = @commands.getCommand(cmdwindow.index)
        if @selecting || [:add_new_rule, :clear_all_rules].include?(cmd)
          refresh = pbSetBattleRule(cmd)
        else
          options = [_INTL("Editar"), _INTL("Quitar"), _INTL("Cancelar")]
          case pbMessage(_INTL("¿Qué hacer con esta regla?"), options, 3)
          when 0
            pbPlayDecisionSE
            refresh = pbSetBattleRule(cmd)
          when 1
            pbPlayDecisionSE
            refresh = pbRemoveBattleRule(cmdwindow.index)
          when 2
            pbPlayCancelSE
          end
        end
      end
    end
    pbDisposeMessageWindow(sprites["textbox"])
    pbDisposeSpriteHash(sprites)
    viewport.dispose
  end

  def pbGetBattleRuleList
    commands = CommandMenuList.new
    commands.currentList = :set_battle_rules
    battleRules = $game_temp.battle_rules
    MenuHandlers.each_available(:battle_rules_menu) do |option, hash, name|
      rule = hash["rule"]
      value = battleRules[rule].clone
      nameRule = hash["nameRule"]
      if rule && value.nil?
        value = battleRules[rule.to_sym].clone
      end
      next if @selecting && (rule.nil? || !value.nil?)
      next if !@selecting && !rule.nil? && value.nil?
      if @selecting
        name = (nameRule) ? nameRule : rule
      else
        case rule
        when "tempParty" then value = sprintf("%d PkMn", value.length / 2)
        when "tempBag"   then value = sprintf("%d Objetos", value.length / 2)
        else
          case value
          when Array  then value = value.join(",")
          when Symbol then value = value.to_s
          when String then value = "Ninguno" if nil_or_empty?(value)
          end
          if value.is_a?(String)
            value = value[0..12] + "..." if value.length > 16
          end
        end
        name = _INTL(name, value)
      end
      commands.add_rule(option, hash, name)
    end
    return commands
  end
  
  def pbSetBattleRule(cmd)
    if MenuHandlers.call(:battle_rules_menu, cmd, "effect", self)
      @selecting = (cmd == :add_new_rule) ? true : false
      commands = pbGetBattleRuleList
      if cmd == :add_new_rule
        @selecting = true
        commands = pbGetBattleRuleList
        if commands.list.empty?
          pbMessage(_INTL("No hay reglas de combate restantes para agregar."))
          @selecting = false
          return false
        end
      end
      return true
    end
    return false
  end
  
  def pbRemoveBattleRule(index)
    rule = @commands.getRule(index)
    return false if $game_temp.battle_rules[rule].nil? && $game_temp.battle_rules[rule.to_sym].nil?
    $game_temp.battle_rules.delete(rule)
    $game_temp.battle_rules.delete(rule.to_sym)
    return true
  end
end

class CommandMenuList
  def add_rule(option, hash, name)
    @commands.push([option, hash["parent"], name || hash["name"], hash["description"], hash["rule"]])
  end
  
  def getRule(index)
    count = 0
    @commands.each do |cmd|
      next if cmd[1] != @currentList
      return cmd[4] if count == index && cmd[4]
      break if count == index
      count += 1
    end
    return "<No hay regla disponible>"
  end
end

#===============================================================================
# Generic utility for setting battle rules during gameplay.
#===============================================================================
def pbApplyBattleRule(rule, value_type, set_value, msg = "")
  if (rule.is_a?(String) && nil_or_empty?(rule)) || (rule.is_a?(Symbol) && rule.nil?)
    pbMessage(_INTL("La regla de combate seleccionada es inválida."))
    return false
  end
  pbPlayDecisionSE
  value = nil
  battleRule = $game_temp.battle_rules[rule]
  case value_type
  when :Toggle
    if battleRule.nil?
      pbMessage(msg) if !nil_or_empty?(msg)
      value = set_value
    else
      $game_temp.battle_rules.delete(rule)
      pbMessage(_INTL("Regla de combate invertida."))
      return true
    end
  when :Boolean
    case pbMessage(msg, [_INTL("Sí"), _INTL("No")], -1)
    when 0 then value = true
    when 1 then value = false
    end
  when :String, :Symbol
    value = pbMessageFreeText(msg, "", false, 250, Graphics.width)
    case value_type
    when :String
      if set_value && value == set_value
        value = ""
      elsif nil_or_empty?(value)
        value = nil
      end
    when :Symbol
      value = (nil_or_empty?(value)) ? nil : value.to_sym
    end
  when :Integer
    minVal = set_value || 0
    initVal = battleRule || minVal
    params = ChooseNumberParams.new
    params.setRange(minVal, 999)
    params.setInitialValue(initVal)
    params.setCancelValue(initVal)
    value = pbMessageChooseNumber(msg, params)
    if value == initVal || value == minVal
      if !battleRule.nil? && value == minVal
        pbPlayDecisionSE
        $game_temp.battle_rules.delete(rule)
		return true
      end
      value = nil
    end
  when :Data
    return false if !set_value || !set_value.is_a?(Symbol)
    pbMessage(msg) if !nil_or_empty?(msg)
    case set_value
    when :Species
      value = pbChooseSpeciesList
    else
      value = pbChooseFromGameDataList(set_value)
    end
  when :Choose
    return false if !set_value || !set_value.is_a?(Array)
    ids = []
    commands = []
    set_value.each do |data| 
      ids.push(data)
      commands.push(_INTL("{1}", data))
    end
    value = pbMessage(msg, commands, -1)
    value = (value == -1) ? nil : ids[value]
  end
  if !value.nil? && battleRule != value
    pbPlayDecisionSE
    $game_temp.battle_rules[rule] = value
    return true
  end
  return false
end


################################################################################
#
# Debug options.
#
################################################################################

#===============================================================================
# Main debug menu option for the Deluxe Battle Kit and supported plugins.
#===============================================================================
MenuHandlers.add(:debug_menu, :deluxe_plugins_menu, {
  "name"        => _INTL("Configuración del DBK..."),
  "parent"      => :main,
  "description" => _INTL("Configuraciones agregadas por el Deluxe Battle Kit y addons."),
  "always_show" => false
})

#===============================================================================
# Main menu.
#===============================================================================
MenuHandlers.add(:debug_menu, :set_battle_rules, {
  "name"        => _INTL("Establecer reglas de combate..."),
  "parent"      => :deluxe_plugins_menu,
  "description" => _INTL("Establecer reglas de combate para aplicar al próximo encuentro."),
  "effect"      => proc {
    pbPlayDecisionSE
    scr = BattleRulesDebug.new
    scr.pbDebugMenu
    next false
  }
})

MenuHandlers.add(:debug_menu, :set_partner, {
  "name"        => _INTL("Establecer entrenador compañero"),
  "parent"      => :deluxe_plugins_menu,
  "description" => _INTL("Establecer un entrenador compañero para que acompañe al jugador en combate."),
  "effect"      => proc {
    endProc = false
    if $PokemonGlobal.partner
      trname = $PokemonGlobal.partner[1]
      commands = [_INTL("Eliminar"), _INTL("Reemplazar"), _INTL("Cancelar")]
      case pbMessage(
        "\\ts[]" + _INTL("¿Qué hacer con el compañero existente del jugador? ({1})", trname), commands, 3)
      when 0
        pbMessage(_INTL("Se eliminó a {1} como compañero.", trname))
        pbDeregisterPartner
        endProc = true
      when 1
        pbMessage(_INTL("Elige un nuevo compañero."))
      when 2
        endProc = true
      end
    end
    if !endProc
      trdata = pbListScreen(_INTL("ENTRENADOR COMPAÑERO"), TrainerBattleLister.new(0, false))
      next false if !trdata
      backSprite = false
      if trdata[2] > 0 && pbResolveBitmap(sprintf("Graphics/Trainers/%s_%s_back", trdata[0], trdata[2]))
        backSprite = true
      end
      if !backSprite && pbResolveBitmap(sprintf("Graphics/Trainers/%s_back", trdata[0]))
        backSprite = true
      end
      if backSprite
        pbRegisterPartner(*trdata)
        pbMessage(_INTL("Se registró a {1} como compañero.", trdata[1]))
      else
        pbMessage(_INTL("El entrenador no tiene una imagen de espalda.\nNo se puede establecer como compañero."))
      end
    end
    next false
  }
})

MenuHandlers.add(:debug_menu, :deluxe_gimmick_toggles, {
  "name"        => _INTL("Activar mecánicas de combate..."),
  "parent"      => :deluxe_plugins_menu,
  "description" => _INTL("Activar o desactivar distintas mecánicas de combate como la Mega Evolución.")
})

MenuHandlers.add(:debug_menu, :deluxe_mega, {
  "name"        => _INTL("Activar/Desactivar Mega Evolución"),
  "parent"      => :deluxe_gimmick_toggles,
  "description" => _INTL("Activa o desactiva la funcionalidad de Mega Evolución."),
  "effect"      => proc {
    $game_switches[Settings::NO_MEGA_EVOLUTION] = !$game_switches[Settings::NO_MEGA_EVOLUTION]
    toggle = ($game_switches[Settings::NO_MEGA_EVOLUTION]) ? "desactivada" : "activada"
    pbMessage(_INTL("Mega Evolution {1}.", toggle))
  }
})


################################################################################
#
# Battle Rule debug options. (Main)
#
################################################################################

MenuHandlers.add(:battle_rules_menu, :add_new_rule, {
  "name"        => _INTL("[AÑADIR NUEVA REGLA]"),
  "order"       => 0,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Selecciona una nueva regla de combate para aplicar."),
  "effect"      => proc { |menu|
    next true
  }
})

MenuHandlers.add(:battle_rules_menu, :clear_all_rules, {
  "name"        => _INTL("[BORRAR TODAS LAS REGLAS]"),
  "order"       => 1,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Borra todas las reglas de combate activas."),
  "effect"      => proc { |menu|
    if $game_temp.battle_rules.empty?
      pbMessage(_INTL("No hay reglas de combate activas para borrar."))
    elsif pbConfirmMessage(_INTL("¿Estás seguro de que quieres borrar todas las reglas de combate activas?"))
      pbPlayDecisionSE
      $game_temp.battle_rules.clear
      next true
    end
    next false
  }
})

################################################################################
#
# Battle Rule debug options. (Essentials)
#
################################################################################

MenuHandlers.add(:battle_rules_menu, :size, {
  "name"        => _INTL("Tamaño de combate: [{1}]"),
  "nameRule"    => "size",
  "rule"        => "side_sizes",
  "order"       => 25,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el número de combatientes en cada lado del campo."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:side_sizes, :Choose, 
      ["single", "1v1", "1v2", "1v3", "2v1", "3v1", "double", "2v2", "2v3", "3v2", "triple", "3v3"],
      _INTL("Set the battle size."))
  }
})

MenuHandlers.add(:battle_rules_menu, :noPartner, {
  "name"        => _INTL("Sin compañero: [{1}]"),
  "nameRule"    => "noPartner",
  "rule"        => "no_partner_trainer",
  "order"       => 50,
  "parent"      => :set_battle_rules,
  "description" => _INTL("El entrenador compañero del jugador no participará en la batalla."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:no_partner_trainer, :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :canLose, {
  "name"        => _INTL("No puede perder: [{1}]"),
  "nameRule"    => "cannotlose",
  "rule"        => "continue_if_lose",
  "order"       => 75,
  "parent"      => :set_battle_rules,
  "description" => _INTL("El juego continuará incluso si el jugador pierde la batalla."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:continue_if_lose, :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :canRun, {
  "name"        => _INTL("No puede huir: [{1}]"),
  "nameRule"    => "cannotrun",
  "rule"        => "cannot_run",
  "order"       => 100,
  "parent"      => :set_battle_rules,
  "description" => _INTL("El jugador no podrá seleccionar el comando Huir."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:cannot_run, :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :roamerFlees, {
  "name"        => _INTL("Los Pokémon salvajes huyen: [{1}]"),
  "nameRule"    => "roamerflees",
  "rule"        => "roamer_flees",
  "order"       => 125,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Los Pokémon salvajes siempre intentarán huir como su primera acción."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:roamer_flees, :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :canSwitch, {
  "name"        => _INTL("No puede cambiar: [{1}]"),
  "nameRule"    => "cannotswitch",
  "rule"        => "cannot_switch",
  "order"       => 150,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Los entrenadores no podrán cambiar manualmente de Pokémon."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:cannot_switch, :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :switchStyle, {
  "name"        => _INTL("No estilo de cambio: [{1}]"),
  "nameRule"    => "noswitchstyle",
  "rule"        => "no_switch_style",
  "order"       => 175,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina si el modo de cambio está habilitado."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:no_switch_style, :Boolean, nil, 
      _INTL("Establece si el modo de cambio debe estar habilitado. (Solo batallas contra entrenadores)"))
  }
})

MenuHandlers.add(:battle_rules_menu, :expGain, {
  "name"        => _INTL("No ganar experiencia: [{1}]"),
  "nameRule"    => "noexp",
  "rule"        => "no_exp_gain",
  "order"       => 200,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Los Pokémon del jugador no ganarán experiencia."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:no_exp_gain, :Toggle, True)
  }
})

MenuHandlers.add(:battle_rules_menu, :moneyGain, {
  "name"        => _INTL("No ganar dinero: [{1}]"),
  "nameRule"    => "nomoney",
  "rule"        => "no_money_gain",
  "order"       => 225,
  "parent"      => :set_battle_rules,
  "description" => _INTL("El jugador no perderá ni recibirá dinero de premio."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:no_money_gain, :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :defaultWeather, {
  "name"        => _INTL("Clima: [{1}]"),
  "nameRule"    => "weather",
  "rule"        => "default_weather",
  "order"       => 250,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el clima predeterminado de la batalla."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:default_weather, :Data, :BattleWeather,
      _INTL("Establece el clima predeterminado de la batalla."))
  }
})

MenuHandlers.add(:battle_rules_menu, :defaultTerrain, {
  "name"        => _INTL("Terreno: [{1}]"),
  "nameRule"    => "terrain",
  "rule"        => "default_terrain",
  "order"       => 275,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el terreno predeterminado de la batalla."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:default_terrain, :Data, :BattleTerrain,
      _INTL("Establece el terreno predeterminado de la batalla."))
  }
})

MenuHandlers.add(:battle_rules_menu, :environment, {
  "name"        => _INTL("Entorno: [{1}]"),
  "rule"        => "environment",
  "order"       => 300,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el entorno de la batalla."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:environment, :Data, :Environment,
      _INTL("Establece el entorno de la batalla."))
  }
})

MenuHandlers.add(:battle_rules_menu, :disablePokeBalls, {
  "name"        => _INTL("Poké Balls deshabilitadas: [{1}]"),
  "nameRule"    => "disablepokeballs",
  "rule"        => "disable_poke_balls",
  "order"       => 325,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Las Poké Balls no podrán ser seleccionadas desde la bolsa."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:disable_poke_balls, :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :forceCatchIntoParty, {
  "name"        => _INTL("Captura va al equipo: [{1}]"),
  "nameRule"    => "forcecatchintoparty",
  "rule"        => "force_catch_into_party",
  "order"       => 350,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Cualquier Pokémon capturado debe ser añadido al equipo."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:force_catch_into_party, :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :battleAnims, {
  "name"        => _INTL("No mostrar animaciones de combate: [{1}]"),
  "nameRule"    => "noanims",
  "rule"        => "no_battle_animations",
  "order"       => 375,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina si las animaciones de combate están habilitadas."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:no_battle_animations, :Boolean, nil, 
      _INTL("Establece si las animaciones de combate deben estar habilitadas."))
  }
})

MenuHandlers.add(:battle_rules_menu, :backdrop, {
  "name"        => _INTL("Fondo: [{1}]"),
  "nameRule"    => "backdrop",
  "rule"        => "backdrop_name",
  "order"       => 400,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el gráfico utilizado para el fondo de la batalla."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:backdrop_name, :String, nil, 
      _INTL("Establece el nombre del gráfico de fondo."))
  }
})

MenuHandlers.add(:battle_rules_menu, :base, {
  "name"        => _INTL("Bases: [{1}]"),
  "nameRule"    => "base",
  "rule"        => "base_name",
  "order"       => 425,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina los gráficos utilizados para las bases de batalla."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:base_name, :String, nil, 
      _INTL("Establece el nombre de los gráficos de las bases de batalla."))
  }
})

MenuHandlers.add(:battle_rules_menu, :outcomeVar, {
  "name"        => _INTL("Variable de resultado: [{1}]"),
  "nameRule"    => "outcomevar",
  "rule"        => "outcome_variable",
  "order"       => 450,
  "parent"      => :set_battle_rules,
  "description" => _INTL("El número de variable utilizado para almacenar el resultado de la batalla."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule(:outcome_variable, :Integer, 1, 
      _INTL("Establece un número de variable."))
  }
})

################################################################################
#
# Battle Rule debug options (DBK).
#
################################################################################

MenuHandlers.add(:battle_rules_menu, :tempPlayer, {
  "name"        => _INTL("Jugador temporal: [{1}]"),
  "rule"        => "tempPlayer",
  "order"       => 301,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina los atributos temporales del jugador."),
  "effect"      => proc { |menu|
    name = pbMessageFreeText(
      _INTL("Ingrese el nombre temporal para mostrar del jugador."), $player.name, false, 250, Graphics.width)
    if !nil_or_empty?(name)
      params = ChooseNumberParams.new
      params.setRange(0, 999)
      params.setInitialValue($player.outfit)
      params.setCancelValue(0)
      outfit = pbMessageChooseNumber(_INTL("Establece el número de atuendo temporal del jugador."), params)
      next false if $player.name == name && $player.outfit == outfit
      next false if $game_temp.battle_rules["tempPlayer"] == [name, outfit]
      $game_temp.battle_rules["tempPlayer"] = [name, outfit]
      next true
    end
    next false
  }
})

MenuHandlers.add(:battle_rules_menu, :tempParty, {
  "name"        => _INTL("Equipo temporal: [{1}]"),
  "rule"        => "tempParty",
  "order"       => 302,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el equipo temporal del jugador."),
  "effect"      => proc { |menu|
    party = []
    Settings::MAX_PARTY_SIZE.times do |i|
      pbMessage(_INTL("Agrega un miembro temporal al equipo (ranura {1}).\n(Salir del menú para terminar temprano)", i + 1))
      species = pbChooseSpeciesList
      break if !species
      name = GameData::Species.get(species).name
      params = ChooseNumberParams.new
      params.setRange(1, Settings::MAXIMUM_LEVEL)
      params.setInitialValue(1)
      params.setCancelValue(1)
      level = pbMessageChooseNumber(_INTL("Establece un nivel para {1}.", name), params)
      party.push(species, level)
    end
    if !party.empty? && $game_temp.battle_rules["tempParty"] != party
      pbMessage(_INTL("Establece un equipo temporal de {1}.", party.length / 2))
      $game_temp.battle_rules["tempParty"] = party
      next true
    end
    next false
  }
})

MenuHandlers.add(:battle_rules_menu, :tempBag, {
  "name"        => _INTL("Mochila temporal: [{1}]"),
  "rule"        => "tempBag",
  "order"       => 303,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina la mochila temporal del jugador."),
  "effect"      => proc { |menu|
    bag = []
    loop do
      pbMessage(_INTL("Agrega un nuevo objeto a la mochila temporal.\n(Salir del menú para terminar)"))
      item = pbChooseFromGameDataList(:Item) do |data|
        next (bag.include?(data.id)) ? nil : data.real_name
      end
      break if !item
      data = GameData::Item.get(item)
      maxRange = (data.is_important?) ? 1 : 999
      params = ChooseNumberParams.new
      params.setRange(1, maxRange)
      params.setInitialValue(1)
      params.setCancelValue(1)
      qty = pbMessageChooseNumber(_INTL("Establece la cantidad de {1} para agregar.", data.name_plural), params)
      bag.push(item, qty)
    end
    if !bag.empty? && $game_temp.battle_rules["tempBag"] != bag
      pbMessage(_INTL("Establece una mochila temporal de {1} objetos.", bag.length / 2))
      $game_temp.battle_rules["tempBag"] = bag
      next true
    end
    next false
  }
})

MenuHandlers.add(:battle_rules_menu, :noBag, {
  "name"        => _INTL("Sin mochila: [{1}]"),
  "rule"        => "noBag",
  "order"       => 304,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Los entrenadores no pueden usar ningún objeto de sus inventarios."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("noBag", :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :noMegaEvolution, {
  "name"        => _INTL("Sin Mega Evolución: [{1}]"),
  "rule"        => "noMegaEvolution",
  "order"       => 305,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina para qué lado está deshabilitada la Mega Evolución."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("noMegaEvolution", :Choose, [:All, :Player, :Opponent], 
      _INTL("Elige un lado para deshabilitar la Mega Evolución."))
  }
})

MenuHandlers.add(:battle_rules_menu, :autoBattle, {
  "name"        => _INTL("Combate automático: [{1}]"),
  "rule"        => "autoBattle",
  "order"       => 310,
  "parent"      => :set_battle_rules,
  "description" => _INTL("La IA controlará los comandos del jugador."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("autoBattle", :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :internalBattle, {
  "name"        => _INTL("Combate PvE: [{1}]"),
  "rule"        => "internalBattle",
  "order"       => 311,
  "parent"      => :set_battle_rules,
  "description" => _INTL("El combate funciona como una Torre Batalla o un combate PvP."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("internalBattle", :Toggle, false)
  }
})

MenuHandlers.add(:battle_rules_menu, :inverseBattle, {
  "name"        => _INTL("Combate inverso: [{1}]"),
  "rule"        => "inverseBattle",
  "order"       => 312,
  "parent"      => :set_battle_rules,
  "description" => _INTL("La efectividad de los tipos será invertida."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("inverseBattle", :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :wildBattleMode, {
  "name"        => _INTL("Mecánica salvaje: [{1}]"),
  "rule"        => "wildBattleMode",
  "order"       => 320,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina una mecánica de combate para que lo usen los Pokémon salvajes."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("wildBattleMode", :Choose, [:mega, :zmove, :ultra, :dynamax, :tera], 
      _INTL("Elige una mecánica de combate para que usen los Pokémon salvajes."))
  }
})

MenuHandlers.add(:battle_rules_menu, :captureSuccess, {
  "name"        => _INTL("Éxito de captura: [{1}]"),
  "rule"        => "captureSuccess",
  "order"       => 351,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina si las Poké Balls siempre tendrán éxito o fallarán."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("captureSuccess", :Boolean, nil, 
      _INTL("Establece si las Poké Balls siempre tendrán éxito o fallarán."))
  }
})

MenuHandlers.add(:battle_rules_menu, :captureTutorial, {
  "name"        => _INTL("Tutorial de captura: [{1}]"),
  "rule"        => "captureTutorial",
  "order"       => 352,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Los Pokémon capturados no se conservarán ni se registrarán en la Pokédex."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("captureTutorial", :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :raidStyleCapture, {
  "name"        => _INTL("Captura estilo raid: [{1}]"),
  "rule"        => "raidStyleCapture",
  "order"       => 353,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Se te pedirá capturar un Pokémon salvaje cuando su HP llegue a cero."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("raidStyleCapture", :Toggle, true)
  }
})

MenuHandlers.add(:battle_rules_menu, :captureME, {
  "name"        => _INTL("Efecto musical de captura: [{1}]"),
  "rule"        => "captureME",
  "order"       => 354,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el efecto musical al capturar un Pokémon."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("captureME", :String, nil, 
      _INTL("Establece el efecto musical que se reproduce al capturar un Pokémon."))
  }
})

MenuHandlers.add(:battle_rules_menu, :battleBGM, {
  "name"        => _INTL("Música de combate: [{1}]"),
  "rule"        => "battleBGM",
  "order"       => 355,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina la música de fondo de la combate."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("battleBGM", :String, "None", 
      _INTL("Establece la música de fondo de la combate. (Pon None para desactivar)"))
  }
})

MenuHandlers.add(:battle_rules_menu, :victoryBGM, {
  "name"        => _INTL("Música de victoria: [{1}]"),
  "rule"        => "victoryBGM",
  "order"       => 356,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina la música de victoria en combate."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("victoryBGM", :String, "None", 
      _INTL("Establece la música de victoria en combate. (Pon None para desactivar)"))
  }
})

MenuHandlers.add(:battle_rules_menu, :lowHealthBGM, {
  "name"        => _INTL("Música de PS bajos: [{1}]"),
  "rule"        => "lowHealthBGM",
  "order"       => 357,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina la música de fondo de PS bajos."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("lowHealthBGM", :String, "None", 
      _INTL("Establece la música de fondo de PS bajos. (Pon None para desactivar)"))
  }
})

MenuHandlers.add(:battle_rules_menu, :battleIntroText, {
  "name"        => _INTL("Texto de introducción: [{1}]"),
  "rule"        => "battleIntroText",
  "order"       => 358,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el texto que se muestra al inicio de un encuentro."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("battleIntroText", :String, nil, 
      _INTL("Establece el texto que se muestra al inicio de un encuentro."))
  }
})

MenuHandlers.add(:battle_rules_menu, :opposingWinText, {
  "name"        => _INTL("Texto de victoria del oponente: [{1}]"),
  "rule"        => "opposingWinText",
  "order"       => 359,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el texto de victoria del entrenador oponente."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("opposingWinText", :String, nil, 
      _INTL("Establece el texto de victoria del entrenador oponente. (Solo combates estilo PvP)"))
  }
})

MenuHandlers.add(:battle_rules_menu, :opposingLoseText, {
  "name"        => _INTL("Texto de derrota del oponente: [{1}]"),
  "rule"        => "opposingLoseText",
  "order"       => 360,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el texto de derrota del entrenador oponente."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("opposingLoseText", :String, nil, 
      _INTL("Establece el texto de derrota del entrenador oponente. (Solo combates estilo PvP)"))
  }
})

MenuHandlers.add(:battle_rules_menu, :slideSpriteStyle, {
  "name"        => _INTL("Entrada del oponente: [{1}]"),
  "rule"        => "slideSpriteStyle",
  "order"       => 426,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina la forma en que los oponentes se deslizan en pantalla al ser encontrados."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("slideSpriteStyle", :Choose,
      ["side", "side_hideBase", "top", "top_hideBase", "bottom", "bottom_hideBase", "still", "still_hideBase"], 
      _INTL("Establece la forma en que los oponentes se deslizan en pantalla."))
  }
})

MenuHandlers.add(:battle_rules_menu, :databoxStyle, {
  "name"        => _INTL("Estilo de databox: [{1}]"),
  "rule"        => "databoxStyle",
  "order"       => 427,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina el estilo de los databoxes mostrados."),
  "effect"      => proc { |menu|
    next pbApplyBattleRule("databoxStyle", :Data, :DataboxStyle,
      _INTL("Establece el estilo de databox a mostrar."))
  }
})

MenuHandlers.add(:battle_rules_menu, :midbattleScript, {
  "name"        => _INTL("Midbattle script: [{1}]"),
  "rule"        => "midbattleScript",
  "order"       => 451,
  "parent"      => :set_battle_rules,
  "description" => _INTL("Determina qué script de mitad de batalla ejecutar."),
  "effect"      => proc { |menu|
    commands = []
    scripts = MidbattleHandlers.script_keys
    MidbattleScripts.constants.each { |script| scripts.push(script.to_sym) }
    if scripts.empty?
      pbMessage(_INTL("No se encontraron scripts de mitad de batalla válidos."))
      next false
    end
    scripts.each { |script| commands.push(_INTL("{1}", script)) }
    cmd = pbMessage(_INTL("Establece un script de mitad de batalla para ejecutar."), commands, -1)
    script = scripts[cmd]
    if cmd >= 0 && $game_temp.battle_rules["midbattleScript"] != script
      $game_temp.battle_rules["midbattleScript"] = script
      pbPlayDecisionSE
      next true
    end
    next false
  }
})