GameData::Ability.register({
  :id => :STRIKER,
  :real_name => "Striker",
  :real_description => _INTL("Potencia los movimientos de patada del Pokémon en un 50%."),
  :flags => [],
  :pbs_file_suffix => ""
})

GameData::Ability.register({
  :id => :BURNINGRAMPAGE,
  :real_name => "Burning Rampage",
  :real_description => _INTL("Al usar un movimiento de tipo Fuego, atrapa al objetivo en un torbellino ígneo."),
  :flags => [],
  :pbs_file_suffix => ""
})

GameData::Ability.register({
  :id => :OVERCHARGE,
  :real_name => "Overcharge",
  :real_description => _INTL("Potencia los movimientos de tipo Eléctrico del Pokémon en un 33%."),
  :flags => [],
  :pbs_file_suffix => ""
})

GameData::Ability.register({
  :id => :CRYSTALORBIT,
  :real_name => "Crystal Orbit",
  :real_description => _INTL("Cuando le queda la mitad de PS, el Pokémon se rodea de un campo de fuerza que sube su Defensa Especial."),
  :flags => [],
  :pbs_file_suffix => ""
})

GameData::Move.register({
  :id => :BEDROCKKICK,
  :real_name => "Bedrock Kick",
  :type => :FIGHTING,
  :category => 0,
  :power => 75,
  :accuracy => 90,
  :total_pp => 10,
  :target => :NearOther,
  :priority => 0,
  :function_code => "None",
  :flags => ["Contact", "CanProtect", "CanMirrorMove", "Kicking"],
  :effect_chance => 0,
  :real_description => _INTL("A powerful kick that shatters the ground. May lower the target's Defense."),
  :pbs_file_suffix => ""
})
