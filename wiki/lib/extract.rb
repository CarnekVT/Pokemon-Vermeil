# frozen_string_literal: true

require "json"
require_relative "evolution"
require_relative "locations"

# Recorre GameData::* y devuelve estructuras de datos planas (Hash/Array de
# tipos JSON) listas para renderizar. Nada de lógica de presentación aquí.
module Extract
  CATEGORY_NAMES = ["Físico", "Especial", "Estado"].freeze

  module_function

  # @return [Hash] { species:, moves:, abilities:, items:, types:, trainers:,
  #                  locations:, dex_order:, meta: }
  def all
    species   = extract_species
    moves     = extract_moves
    abilities = extract_abilities
    items     = extract_items
    trainers  = extract_trainers
    locations = Locations.all

    link_reverse_indices(species, moves, abilities, items, trainers, locations)

    {
      species: species,
      moves: moves,
      abilities: abilities,
      items: items,
      types: extract_types,
      trainers: trainers,
      locations: locations,
      dex_order: dex_order,
      meta: meta
    }
  end

  # ---------------------------------------------------------------------------

  def meta
    version = (defined?(Settings) && Settings.const_defined?(:GAME_VERSION)) ? Settings::GAME_VERSION.to_s : nil
    { game_title: game_title, version: version, generated: Time.now.strftime("%Y-%m-%d") }
  end

  # El nombre del juego sale de "windowTitle" en mkxp.json (que es JSON con
  # comentarios //). Si falla, cae al título de RPG Maker.
  def game_title
    raw = File.read(File.join(Dir.pwd, "mkxp.json"))
    json = raw.gsub(%r{^[ \t]*//.*$}, "").gsub(%r{/\*.*?\*/}m, "")
    title = JSON.parse(json)["windowTitle"].to_s.strip
    return title unless title.empty?

    raise "sin windowTitle"
  rescue StandardError
    (defined?(System) && System.respond_to?(:game_title) ? System.game_title.to_s : "Wiki").sub(/\s*\(tests\)\z/, "")
  end

  def dex_order
    ids = []
    GameData::Species.each_species { |s| ids << s.species.to_s }
    ids
  end

  # GameData::X.each solo hace yield (no devuelve Enumerator), así que se acumula a mano.
  def each_data(klass)
    out = {}
    klass.each { |x| out[x.id.to_s] = yield(x) }
    out
  end

  def extract_types
    each_data(GameData::Type) do |t|
      {
        id: t.id.to_s, name: t.name,
        pseudo: !!t.pseudo_type, special: !!t.special_type,
        icon_position: t.icon_position,
        weaknesses: t.weaknesses.map(&:to_s),
        resistances: t.resistances.map(&:to_s),
        immunities: t.immunities.map(&:to_s)
      }
    end
  end

  def extract_species
    out = {}
    GameData::Species.each do |s|
      out[s.id.to_s] = {
        id: s.id.to_s, species: s.species.to_s, form: s.form,
        name: s.name, form_name: (s.form_name if s.form > 0 && s.real_form_name),
        types: s.types.map(&:to_s),
        base_stats: stat_hash(s.base_stats), bst: s.base_stat_total,
        evs: stat_hash(s.evs).reject { |_, v| v.zero? },
        abilities: s.abilities.map(&:to_s), hidden_abilities: s.hidden_abilities.map(&:to_s),
        moves: s.moves.map { |lvl, mv| [lvl, mv.to_s] },
        tutor_moves: s.tutor_moves.map(&:to_s),
        egg_moves: s.egg_moves.map(&:to_s),
        egg_groups: s.egg_groups.map(&:to_s),
        hatch_steps: s.hatch_steps,
        gender_ratio: gender_ratio_name(s.gender_ratio),
        growth_rate: growth_rate_name(s.growth_rate),
        catch_rate: s.catch_rate, base_exp: s.base_exp, happiness: s.happiness,
        height: (s.height.to_f / 10).round(1), weight: (s.weight.to_f / 10).round(1),
        color: s.color.to_s, shape: s.shape.to_s, habitat: s.habitat.to_s,
        generation: s.generation, category: s.category, pokedex: s.pokedex_entry,
        wild_items: wild_items(s),
        evolves_to: s.get_evolutions(true).map { |sp, m, p|
          { to: sp.to_s, text: EvolutionText.describe(m, p) }
        },
        prevo: (s.get_previous_species.to_s if s.get_previous_species != s.species),
        mega_stone: s.mega_stone&.to_s, mega_move: s.mega_move&.to_s,
        hidden_from_dex: s.hide_from_dex?,
        # rellenados por link_reverse_indices
        locations: [], trainers: []
      }
    end
    out
  end

  def extract_moves
    each_data(GameData::Move) do |m|
      {
        id: m.id.to_s, name: m.name, type: m.type.to_s,
        category: m.category, category_name: CATEGORY_NAMES[m.category],
        power: m.power, accuracy: m.accuracy, total_pp: m.total_pp,
        priority: m.priority, target: m.target.to_s,
        function_code: m.function_code, flags: m.flags.dup,
        effect_chance: m.effect_chance, description: m.description,
        learned_by: { level: [], tutor: [], egg: [] }, machine: nil
      }
    end
  end

  def extract_abilities
    each_data(GameData::Ability) do |a|
      {
        id: a.id.to_s, name: a.name, description: a.description, flags: a.flags.dup,
        pokemon: { normal: [], hidden: [] }
      }
    end
  end

  def extract_items
    pocket_names = PokemonBag.pocket_names
    each_data(GameData::Item) do |i|
      {
        id: i.id.to_s, name: i.name, name_plural: i.real_name_plural,
        pocket: i.pocket, pocket_name: pocket_names[i.pocket - 1],
        price: i.price, sell_price: i.sell_price, bp_price: i.bp_price,
        field_use: field_use_name(i.field_use), battle_use: battle_use_name(i.battle_use),
        flags: i.flags.dup, consumable: i.consumable,
        machine: (i.is_machine? ? { move: i.move.to_s, kind: machine_kind(i) } : nil),
        description: i.description,
        held_by: [], found_at: []   # rellenados por link_reverse_indices
      }
    end
  end

  def extract_trainers
    out = {}
    GameData::Trainer.each do |t|
      tt = GameData::TrainerType.try_get(t.trainer_type)
      key = trainer_key(t)
      out[key] = {
        key: key, trainer_type: t.trainer_type.to_s,
        type_name: (tt&.name || t.trainer_type.to_s),
        name: t.name, version: t.version,
        lose_text: t.lose_text,
        items: t.items.map { |it| GameData::Item.try_get(it)&.name || it.to_s },
        party: t.pokemon.map { |p| trainer_pokemon(p) }
      }
    end
    out
  end

  # ---------------------------------------------------------------------------

  def link_reverse_indices(species, moves, abilities, items, trainers, locations)
    species.each_value do |s|
      s[:moves].each     { |lvl, mv| moves.dig(mv, :learned_by, :level)&.push([s[:id], lvl]) }
      s[:tutor_moves].each { |mv| moves.dig(mv, :learned_by, :tutor)&.push(s[:id]) }
      s[:egg_moves].each   { |mv| moves.dig(mv, :learned_by, :egg)&.push(s[:id]) }
      s[:abilities].each   { |ab| abilities.dig(ab, :pokemon, :normal)&.push(s[:id]) }
      s[:hidden_abilities].each { |ab| abilities.dig(ab, :pokemon, :hidden)&.push(s[:id]) }
      s[:wild_items].each  { |w| items.dig(w[:item], :held_by)&.push(id: s[:id], rarity: w[:rarity]) }
    end

    items.each_value do |i|
      next unless i[:machine]

      m = moves[i[:machine][:move]]
      m[:machine] = { item: i[:id], kind: i[:machine][:kind] } if m
    end

    locations.each do |loc|
      loc[:encounters].each do |enc|
        enc[:slots].each do |sl|
          species.dig(sl[:species], :locations)&.push(
            map: loc[:map], map_name: loc[:name], method: enc[:method_name],
            min: sl[:min], max: sl[:max], chance: sl[:chance]
          )
        end
      end
      loc[:items].each do |it|
        items.dig(it[:item], :found_at)&.push(
          map: loc[:map], map_name: loc[:name], hidden: it[:hidden], kind: it[:kind]
        )
      end
    end

    trainers.each_value do |t|
      t[:party].each { |p| species.dig(p[:species], :trainers)&.push(key: t[:key], name: t[:name], type_name: t[:type_name], level: p[:level]) }
    end
  end

  # ---------------------------------------------------------------------------

  # Estadísticas de PBS en su orden (PS, Ataque, Defensa, Velocidad, At. Esp., Def. Esp.).
  def main_stats
    @main_stats ||= [].tap { |a| GameData::Stat.each_main { |s| a << s if s.pbs_order >= 0 } }
                      .sort_by(&:pbs_order)
  end

  def stat_hash(h)
    main_stats.each_with_object({}) { |s, out| out[s.id.to_s] = h[s.id] || 0 }
  end

  def wild_items(s)
    [[s.wild_item_common, "común"], [s.wild_item_uncommon, "poco común"], [s.wild_item_rare, "raro"]]
      .flat_map { |list, rarity| Array(list).compact.map { |it| { item: it.to_s, rarity: rarity } } }
  end

  def trainer_key(t)
    [t.trainer_type, t.real_name.gsub(/\s+/, "_"), t.version].join("-").gsub(/[^A-Za-z0-9_\-]/, "")
  end

  def trainer_pokemon(p)
    {
      species: p[:species].to_s, level: p[:level], form: p[:form],
      name: p[:name],
      moves: Array(p[:moves]).map { |mv| GameData::Move.try_get(mv)&.name || mv.to_s },
      ability: (GameData::Ability.try_get(p[:ability])&.name if p[:ability]),
      ability_index: p[:ability_index],
      item: (GameData::Item.try_get(p[:item])&.name if p[:item]),
      gender: gender_name(p[:gender]),
      nature: (GameData::Nature.try_get(p[:nature])&.name if p[:nature]),
      iv: stat_line(p[:iv]), ev: stat_line(p[:ev]),
      shiny: !!p[:shininess] || !!p[:super_shininess],
      shadow: !!p[:shadowness],
      ball: (GameData::Item.try_get(p[:poke_ball])&.name if p[:poke_ball])
    }
  end

  def stat_line(h)
    return nil unless h.is_a?(Hash)

    main_stats.map { |s| h[s.id] }
  end

  def gender_name(g)
    { 0 => "Macho", 1 => "Hembra" }[g]
  end

  GROWTH_RATES = {
    "Medium" => "Medio", "Erratic" => "Errático", "Fluctuating" => "Fluctuante",
    "Parabolic" => "Medio lento", "Fast" => "Rápido", "Slow" => "Lento"
  }.freeze

  def growth_rate_name(sym)
    GROWTH_RATES[sym.to_s] || sym.to_s
  end

  GENDER_RATIOS = {
    "AlwaysMale" => "Siempre macho", "AlwaysFemale" => "Siempre hembra", "Genderless" => "Sin género",
    "FemaleOneEighth" => "87,5% macho", "Female25Percent" => "75% macho",
    "Female50Percent" => "50% / 50%", "Female75Percent" => "25% macho",
    "FemaleSevenEighths" => "12,5% macho"
  }.freeze

  def gender_ratio_name(sym)
    GENDER_RATIOS[sym.to_s] || sym.to_s
  end

  def field_use_name(v)
    { 1 => "En un Pokémon", 2 => "Directo", 3 => "MT", 4 => "MO", 5 => "MR" }[v]
  end

  def battle_use_name(v)
    { 1 => "En un Pokémon", 2 => "En un movimiento", 3 => "En el Pokémon activo", 4 => "Contra un rival", 5 => "Directo" }[v]
  end

  def machine_kind(i)
    return "MT" if i.is_TM?
    return "MO" if i.is_HM?

    "MR"
  end
end

module Snapshot
  module_function

  # Reduce los datos extraídos a lo comparable con la baseline (todo lo que no
  # depende del mundo/mapas). Mismo idioma en fork y baseline, así que se
  # comparan también textos.
  FIELDS = {
    species: %i[name form_name types base_stats bst evs abilities hidden_abilities moves
                tutor_moves egg_moves egg_groups hatch_steps gender_ratio growth_rate
                catch_rate base_exp happiness height weight generation category pokedex
                wild_items evolves_to prevo mega_stone mega_move hidden_from_dex],
    moves: %i[name type category power accuracy total_pp priority target function_code
              flags effect_chance description],
    abilities: %i[name description flags],
    items: %i[name name_plural pocket price sell_price bp_price field_use battle_use
              flags consumable machine description]
    # Los entrenadores no se comparan: son propios de cada juego, no "cambios"
    # respecto a nada.
  }.freeze

  def reduce(data)
    FIELDS.each_with_object({}) do |(cat, fields), out|
      out[cat.to_s] = data[cat].transform_values { |e| e.slice(*fields) }
    end
  end
end
