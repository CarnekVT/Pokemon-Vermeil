# Battle mechanics, played out headlessly.
#
# The opponent is usually given Splash so the only thing changing its HP is the
# move under test. Damage rolls between 85% and 100%, so assertions cover ranges
# rather than exact numbers; a fixed seed keeps runs comparable anyway.

class TestBattleBasics < BattleTestCase
  def test_super_effective_move_deals_damage
    pikachu = mon(:PIKACHU, moves: [:THUNDERBOLT])
    squirtle = mon(:SQUIRTLE, moves: [:SPLASH])

    battle = run_battle(player: [pikachu], foe: [squirtle],
                        moves: { 0 => [:THUNDERBOLT] }, rounds: 1, seed: 42)

    assert_operator damage_taken(squirtle), :>, 0, "Rayo no hizo daño a Squirtle"
    assert_message_matching(/supereficaz/i, battle)
  end

  def test_immune_type_takes_no_damage
    pikachu = mon(:PIKACHU, moves: [:THUNDERBOLT])
    sandshrew = mon(:SANDSHREW, moves: [:SPLASH])   # Ground, immune to Electric

    run_battle(player: [pikachu], foe: [sandshrew],
               moves: { 0 => [:THUNDERBOLT] }, rounds: 1, seed: 42)

    assert_equal 0, damage_taken(sandshrew), "un tipo Tierra recibió daño eléctrico"
  end

  def test_super_effective_hits_harder_than_neutral
    seed = 7
    squirtle = mon(:SQUIRTLE, moves: [:SPLASH])
    run_battle(player: [mon(:PIKACHU, moves: [:THUNDERBOLT])], foe: [squirtle],
               moves: { 0 => [:THUNDERBOLT] }, rounds: 1, seed: seed)
    super_effective = damage_taken(squirtle)

    rattata = mon(:RATTATA, moves: [:SPLASH])       # Normal, neutral to Electric
    run_battle(player: [mon(:PIKACHU, moves: [:THUNDERBOLT])], foe: [rattata],
               moves: { 0 => [:THUNDERBOLT] }, rounds: 1, seed: seed)
    neutral_ratio = damage_taken(rattata).to_f / rattata.totalhp

    assert_operator super_effective.to_f / squirtle.totalhp, :>, neutral_ratio,
                    "el golpe supereficaz no hizo proporcionalmente más daño que el neutro"
  end

  def test_burn_damages_at_end_of_round
    attacker = mon(:PIKACHU, moves: [:SPLASH])
    burned = mon(:SQUIRTLE, moves: [:SPLASH], status: :BURN)
    assert_equal :BURN, burned.status, "el Pokémon no empezó quemado"

    run_battle(player: [attacker], foe: [burned],
               moves: { 0 => [:SPLASH] }, rounds: 1, seed: 42)

    assert_operator damage_taken(burned), :>, 0, "la quemadura no hizo daño de fin de turno"
  end

  def test_intimidate_lowers_opposing_attack
    gyarados = mon(:GYARADOS, moves: [:SPLASH], ability: :INTIMIDATE)
    squirtle = mon(:SQUIRTLE, moves: [:SPLASH])

    battle = run_battle(player: [gyarados], foe: [squirtle],
                        moves: { 0 => [:SPLASH] }, rounds: 1, seed: 42)

    assert_equal(-1, battler(battle, 1).stages[:ATTACK],
                 "Intimidación no bajó el Ataque del rival")
  end

  def test_priority_move_goes_first_despite_lower_speed
    snorlax = mon(:SNORLAX, moves: [:QUICKATTACK])   # slow
    jolteon = mon(:JOLTEON, moves: [:TACKLE])        # fast

    battle = run_battle(player: [snorlax], foe: [jolteon],
                        moves: { 0 => [:QUICKATTACK] }, rounds: 1, seed: 42)

    used = battle.scene.messages.select { |msg| msg.include?("ha usado") }
    refute_empty used, "nadie atacó en el turno"
    assert used.first.include?("Snorlax"),
           "Ataque Rápido no fue primero. Orden: #{used.inspect}"
  end

  def test_battle_runs_to_completion_and_reports_an_outcome
    pikachu = mon(:PIKACHU, level: 50, moves: [:THUNDERBOLT])
    magikarp = mon(:MAGIKARP, level: 5, moves: [:SPLASH])

    battle = run_battle(player: [pikachu], foe: [magikarp],
                        moves: { 0 => [:THUNDERBOLT] }, rounds: nil, seed: 42)

    assert_equal Battle::Outcome::WIN, battle.decision
    assert_equal 0, magikarp.hp
  end
end
