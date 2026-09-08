#===============================================================================
# [VERMEIL] Battle Additions - ability registrations
# Custom ability definitions that belong to this plugin.
#===============================================================================
[
  [:STRIKER,        "Striker",        "Powers up kicking moves by 50%."],
  [:BURNINGRAMPAGE, "Burning Rampage", "Fire moves trap the target in a fiery vortex."],
  [:OVERCHARGE,     "Overcharge",     "Powers up Electric-type moves by 33%."],
  [:CRYSTALORBIT,   "Crystal Orbit",   "When it drops to half HP, raises its Special Defense."],
].each do |id, name, description|
  next if GameData::Ability.exists?(id)
  GameData::Ability.register({
    :id => id,
    :real_name => name,
    :real_description => _INTL(description),
    :flags => [],
    :pbs_file_suffix => ""
  })
end
