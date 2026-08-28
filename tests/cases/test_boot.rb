# Does the game still start? Every script and plugin has to evaluate cleanly and
# the compiled PBS data has to load. This catches the breakages that otherwise
# only show up as a crash on the title screen.

class TestBoot < EngineTest
  def test_all_scripts_and_plugins_load_without_errors
    report = TestGame.load_errors.map do |name, error|
      "#{name}\n    #{error.class}: #{error.message}"
    end
    assert_empty report, "scripts que no cargan:\n  #{report.join("\n  ")}"
  end

  def test_game_data_loads
    assert_operator GameData::Species.count, :>, 0
    assert_operator GameData::Move.count, :>, 0
    assert_operator GameData::Item.count, :>, 0
    assert_operator GameData::Ability.count, :>, 0
  end

  def test_core_constants_are_defined
    assert Settings::SCREEN_WIDTH.is_a?(Integer)
    assert Settings::SCREEN_HEIGHT.is_a?(Integer)
    assert_equal "21.1", Essentials::VERSION
    refute_empty LBDSKY::VERSION
  end

  def test_new_game_state_is_usable
    assert_equal "Tester", $player.name
    assert_empty $player.party
    refute_nil $bag
    refute_nil $PokemonStorage
  end

  def test_pokemon_can_be_created_and_healed
    pkmn = Pokemon.new(:PIKACHU, 5)
    assert_equal :PIKACHU, pkmn.species
    assert_equal 5, pkmn.level
    assert_operator pkmn.totalhp, :>, 0
    assert_equal pkmn.totalhp, pkmn.hp
    refute_empty pkmn.moves
  end
end
