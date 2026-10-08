# [VERMEIL] Battle Additions - custom move registrations
# Ability registrations are kept inside Abilities/000_VermeilAbilityData.rb.

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
}) unless GameData::Move.exists?(:BEDROCKKICK)
