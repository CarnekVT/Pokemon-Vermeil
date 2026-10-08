# encoding: utf-8

GameData::Evolution.register({
  :id            => :HasMoveRandomNaussitchd,
  :parameter     => :Move,
  :description   => proc { |pkmn, parameter| _INTL("while it knows the move {1}", GameData::Move.get(parameter).name) },
  :any_level_up  => true,
  :level_up_proc => proc { |pkmn, parameter|
    next false if !pkmn.moves.any? { |m| m && m.id == parameter }
    if pkmn.moves.any? { |m| m && m.id == :BULBBASH } &&
       pkmn.moves.any? { |m| m && m.id == :STALKCUTTER }
      roll = pkmn.instance_variable_get(:@naussitchd_evo_roll)
      if roll.nil?
        roll = rand(2)
        pkmn.instance_variable_set(:@naussitchd_evo_roll, roll)
      end
      if roll == 0
        pkmn.instance_variable_set(:@naussitchd_target_form, 0)
        pkmn.form = 0
        next true
      end
      next false
    end
    pkmn.instance_variable_set(:@naussitchd_target_form, 0)
    pkmn.form = 0
    next true
  },
  :after_evolution_proc => proc { |pkmn, new_species, _parameter, _evo_species|
    next false if new_species != :FARFETCHD
    target = pkmn.instance_variable_get(:@naussitchd_target_form)
    if target == 0
      pkmn.form = 0
      pkmn.remove_instance_variable(:@naussitchd_target_form) if pkmn.instance_variable_defined?(:@naussitchd_target_form)
      pkmn.remove_instance_variable(:@naussitchd_evo_roll) if pkmn.instance_variable_defined?(:@naussitchd_evo_roll)
      next true
    end
    pkmn.remove_instance_variable(:@naussitchd_evo_roll) if pkmn.instance_variable_defined?(:@naussitchd_evo_roll)
    next false
  }
})

GameData::Evolution.register({
  :id            => :HasMoveTurnForm1,
  :parameter     => :Move,
  :description   => proc { |pkmn, parameter| _INTL("while it knows the move {1}", GameData::Move.get(parameter).name) },
  :any_level_up  => true,
  :level_up_proc => proc { |pkmn, parameter|
    next pkmn.moves.any? { |m| m && m.id == parameter }
  }
})
