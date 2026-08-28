# Cross-references inside the compiled PBS data.
#
# The compiler accepts an ID that looks well-formed but names something that does
# not exist; the game only notices when it tries to use it — a crash on entering
# a route, or an evolution that silently never happens. These walk the data and
# report every dangling reference at once.

class TestPBSIntegrity < EngineTest
  def test_species_moves_exist
    report = []
    GameData::Species.each do |species|
      species.moves.each do |level, move|
        report << "#{species.id}: nivel #{level} enseña #{move}" if !GameData::Move.exists?(move)
      end
      species.tutor_moves.each do |move|
        report << "#{species.id}: tutor #{move}" if !GameData::Move.exists?(move)
      end
      species.egg_moves.each do |move|
        report << "#{species.id}: movimiento huevo #{move}" if !GameData::Move.exists?(move)
      end
    end
    assert_empty report, dangling("movimientos inexistentes", report)
  end

  def test_species_abilities_exist
    report = []
    GameData::Species.each do |species|
      (species.abilities + species.hidden_abilities).each do |ability|
        report << "#{species.id}: #{ability}" if !GameData::Ability.exists?(ability)
      end
    end
    assert_empty report, dangling("habilidades inexistentes", report)
  end

  def test_species_held_items_exist
    report = []
    GameData::Species.each do |species|
      [species.wild_item_common, species.wild_item_uncommon, species.wild_item_rare].flatten.compact.each do |item|
        report << "#{species.id}: #{item}" if !GameData::Item.exists?(item)
      end
    end
    assert_empty report, dangling("objetos salvajes inexistentes", report)
  end

  def test_species_evolutions_point_somewhere_real
    report = []
    GameData::Species.each do |species|
      species.get_evolutions.each do |evolved, method, parameter|
        report << "#{species.id} evoluciona a #{evolved}" if !GameData::Species.exists?(evolved)
        evolution = GameData::Evolution.try_get(method)
        if evolution.nil?
          report << "#{species.id}: método de evolución #{method} desconocido"
          next
        end
        report.concat(bad_evolution_parameter(species, method, evolution.parameter, parameter))
      end
    end
    assert_empty report, dangling("evoluciones rotas", report)
  end

  def test_species_egg_groups_and_growth_rates_are_known
    report = []
    GameData::Species.each do |species|
      species.egg_groups.each do |group|
        report << "#{species.id}: grupo huevo #{group}" if !GameData::EggGroup.exists?(group)
      end
      report << "#{species.id}: tipo #{species.types}" if species.types.any? { |type| !GameData::Type.exists?(type) }
      report << "#{species.id}: crecimiento #{species.growth_rate}" if !GameData::GrowthRate.exists?(species.growth_rate)
      report << "#{species.id}: género #{species.gender_ratio}" if !GameData::GenderRatio.exists?(species.gender_ratio)
    end
    assert_empty report, dangling("enums desconocidos", report)
  end

  def test_trainer_teams_are_valid
    report = []
    GameData::Trainer.each do |trainer|
      label = "#{trainer.trainer_type} #{trainer.real_name}"
      trainer.items.each do |item|
        report << "#{label}: objeto #{item}" if !GameData::Item.exists?(item)
      end
      trainer.pokemon.each do |entry|
        if !GameData::Species.exists?(entry[:species])
          report << "#{label}: especie #{entry[:species]}"
          next
        end
        level = entry[:level]
        if level.nil? || level < 1 || level > Settings::MAXIMUM_LEVEL
          report << "#{label}: #{entry[:species]} a nivel #{level.inspect}"
        end
        entry[:moves]&.each do |move|
          report << "#{label}: #{entry[:species]} conoce #{move}" if !GameData::Move.exists?(move)
        end
        if entry[:item] && !GameData::Item.exists?(entry[:item])
          report << "#{label}: #{entry[:species]} lleva #{entry[:item]}"
        end
        if entry[:ability] && !GameData::Ability.exists?(entry[:ability])
          report << "#{label}: #{entry[:species]} con #{entry[:ability]}"
        end
      end
    end
    assert_empty report, dangling("equipos de entrenador rotos", report)
  end

  def test_encounter_tables_are_valid
    report = []
    GameData::Encounter.each do |encounter|
      encounter.types.each do |type, slots|
        next if slots.nil?
        slots.each do |slot|
          _probability, species, min_level, max_level = slot
          if !GameData::Species.exists?(species)
            report << "mapa #{encounter.map} (#{type}): especie #{species}"
            next
          end
          max_level ||= min_level
          if min_level < 1 || max_level > Settings::MAXIMUM_LEVEL || min_level > max_level
            report << "mapa #{encounter.map} (#{type}): #{species} niveles #{min_level}-#{max_level}"
          end
        end
      end
    end
    assert_empty report, dangling("encuentros rotos", report)
  end

  def test_machine_items_teach_real_moves
    report = []
    GameData::Item.each do |item|
      next if !item.is_machine?
      report << "#{item.id} enseña #{item.move}" if !GameData::Move.exists?(item.move)
    end
    assert_empty report, dangling("MTs/MOs sin movimiento", report)
  end

  private

  # An evolution method declares what kind of parameter it takes; this checks the
  # value actually stored matches, which is where PBS typos usually land.
  def bad_evolution_parameter(species, method, expected, value)
    case expected
    when :Item    then GameData::Item.exists?(value) ? [] : ["#{species.id}: #{method} con objeto #{value}"]
    when :Move    then GameData::Move.exists?(value) ? [] : ["#{species.id}: #{method} con movimiento #{value}"]
    when :Species then GameData::Species.exists?(value) ? [] : ["#{species.id}: #{method} con especie #{value}"]
    when :Type    then GameData::Type.exists?(value) ? [] : ["#{species.id}: #{method} con tipo #{value}"]
    when Integer  then value.is_a?(Integer) ? [] : ["#{species.id}: #{method} espera un número, llegó #{value.inspect}"]
    else []
    end
  end

  def dangling(title, report)
    "#{report.length} #{title}:\n  " + report.first(40).join("\n  ") +
      (report.length > 40 ? "\n  ... y #{report.length - 40} más" : "")
  end
end
