class TestBattleRefactoredFlow < BattleTestCase
  DefeatedPokemon = Struct.new(:base_exp)
  DefeatedBattler = Struct.new(:participants, :level, :pokemon)

  def test_base_exp_distribution_returns_participation_and_share_flags
    battle = Battle.allocate
    defeated = DefeatedBattler.new([0], 10, DefeatedPokemon.new(60))

    participant_exp, participated, has_exp_share = battle.pbCalculateBaseExpGain(
      0, defeated, 10, 2, [], false
    )
    expected_participant_exp = Settings::SPLIT_EXP_BETWEEN_GAINERS ? 300 : 600
    assert_equal [expected_participant_exp, true, false],
                 [participant_exp, participated, has_exp_share]

    share_exp, participated, has_exp_share = battle.pbCalculateBaseExpGain(
      1, defeated, 10, 1, [1], false
    )
    assert_equal [300, false, true], [share_exp, participated, has_exp_share]
  end

  def test_exp_formula_preserves_scaled_and_unscaled_paths
    battle = Battle.allocate
    battle.define_singleton_method(:trainerBattle?) { false }
    pokemon = Struct.new(:level).new(5)
    expected = 100

    if Settings::SCALED_EXP_FORMULA
      expected /= 5
      level_adjust = ((2 * 10) + 10.0) / (pokemon.level + 10 + 10.0)
      level_adjust **= 5
      level_adjust = Math.sqrt(level_adjust)
      expected = (expected * level_adjust).floor + 1
    else
      expected /= 7
    end

    assert_equal expected, battle.pbApplyExpFormula(100, pokemon, 10, true, false)
  end

  def test_exp_bonus_uses_the_held_item_handler
    $bag.remove(:EXPCHARM) if $bag.has?(:EXPCHARM)
    pokemon = mon(:PIKACHU, item: :LUCKYEGG)
    battle = Battle.allocate
    battle.instance_variable_set(:@internalBattle, false)
    battle.define_singleton_method(:pbPlayer) { $player }
    battle.define_singleton_method(:initialItem) { |_side, _index| nil }

    exp, outsider = battle.pbApplyExpBonuses(100, pokemon, 0)

    assert_equal 150, exp
    refute outsider
  end

  def test_restores_a_knocked_off_initial_item
    pokemon = mon(:PIKACHU)
    pokemon.item = nil
    parties = [[pokemon], []]
    battle = Battle.allocate
    battle.instance_variable_set(:@initialItems, [[[:LEFTOVERS, 0, 0, true]], []])
    battle.define_singleton_method(:trainerBattle?) { false }
    battle.define_singleton_method(:pbParty) { |side| parties[side] }

    battle.pbRestoreInitialBattleItems

    assert_equal :LEFTOVERS, pokemon.item_id
  end

  def test_passes_pokerus_to_an_adjacent_party_member
    infected = mon(:PIKACHU)
    susceptible = mon(:SQUIRTLE)
    infected.givePokerus(4)
    $player.party = [infected, susceptible]
    battle = Battle.allocate
    battle.instance_variable_set(:@internalBattle, true)
    battle.define_singleton_method(:rand) { |*_args| 0 }

    battle.pbPassPokerus

    assert_equal 1, susceptible.pokerusStage
    assert_equal infected.pokerusStrain, susceptible.pokerusStrain
  end

  def test_exp_share_group_message_precedes_reserve_level_up
    participant = mon(:PIKACHU, level: 5, moves: [:THUNDERBOLT])
    reserve = mon(:SQUIRTLE, level: 5, item: :EXPSHARE)
    foe = mon(:MAGIKARP, level: 50, moves: [:SPLASH])
    $game_map = Struct.new(:map_id, :metadata).new(-1, nil)

    battle = run_battle(player: [participant, reserve], foe: [foe],
                        moves: { 0 => [:THUNDERBOLT] }, rounds: nil, seed: 42,
                        internal: true)

    messages = battle.scene.messages
    participant_exp_index = messages.index { |message| message.include?("Pikachu obtuvo") }
    group_message_index = messages.index { |message| message.include?("Tus otros Pokémon") }
    level_up_index = messages.index { |message| message.include?("Squirtle subió al nivel") }

    refute_nil participant_exp_index, "no apareció el mensaje de experiencia del participante"
    refute_nil group_message_index, "no apareció el mensaje de experiencia compartida"
    refute_nil level_up_index, "el Pokémon reserva no subió de nivel"
    assert_operator participant_exp_index, :<, group_message_index
    assert_operator group_message_index, :<, level_up_index
  end

  def test_internal_battle_awards_exp_and_finishes
    pikachu = mon(:PIKACHU, level: 5, moves: [:THUNDERBOLT])
    magikarp = mon(:MAGIKARP, level: 50, moves: [:SPLASH])
    starting_exp = pikachu.exp
    starting_level = pikachu.level
    $game_map = Struct.new(:map_id, :metadata).new(-1, nil)

    battle = run_battle(player: [pikachu], foe: [magikarp],
                        moves: { 0 => [:THUNDERBOLT] }, rounds: nil, seed: 42,
                        internal: true)

    assert_equal Battle::Outcome::WIN, battle.decision
    assert_operator pikachu.exp, :>, starting_exp
    assert_operator pikachu.level, :>, starting_level
    assert_operator $stats.total_exp_gained, :>, 0
    assert_message_matching(/puntos de experiencia/i, battle)
  end
end
