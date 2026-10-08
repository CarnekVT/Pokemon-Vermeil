# frozen_string_literal: true

require "json"
require "fileutils"
require "digest"

module TrainerVariants
  CONFIG_PATH = File.join(File.dirname(__dir__), "config.json")
  DEFAULT_SETTINGS = {
    "out" => "wiki/site",
    "baseline" => "wiki/baseline.json",
    "sprites" => true,
    "recompile" => true,
    "accent_light" => "#1a3d5c",
    "accent_dark" => "#5ba0d6"
  }.freeze
  FEATURE_DEFAULTS = %w[
    pokemon moves abilities items trainers locations types changes notes
    pokemon_evolution pokemon_level_moves pokemon_tutor_moves pokemon_egg_moves
    pokemon_locations pokemon_trainers pokemon_wild_items move_learners ability_pokemon
    item_locations item_held_by location_encounters location_items trainer_teams trainer_items trainer_quotes
  ].to_h { |key| [key, true] }.freeze

  module_function

  def default_config
    { "settings" => DEFAULT_SETTINGS.dup, "features" => FEATURE_DEFAULTS.dup,
      "version_modes" => {}, "mode_fallbacks" => {}, "player_starter_types" => [],
      "modes" => [], "default_mode" => "", "families" => {} }
  end

  def load(path = CONFIG_PATH)
    return default_config unless File.file?(path)

    raw = JSON.parse(File.read(path))
    return default_config unless raw.is_a?(Hash)

    config = default_config
    config["settings"].merge!(raw["settings"]) if raw["settings"].is_a?(Hash)
    if raw["features"].is_a?(Hash)
      FEATURE_DEFAULTS.each_key { |key| config["features"][key] = raw["features"].fetch(key, true) == true }
    end
    config["version_modes"] = raw["version_modes"].is_a?(Hash) ? raw["version_modes"] : {}
    config["mode_fallbacks"] = raw["mode_fallbacks"].is_a?(Hash) ? raw["mode_fallbacks"] : {}
    config["modes"] = Array(raw["modes"]).filter_map { |name| clean_text(name) }.uniq
    config["default_mode"] = clean_text(raw["default_mode"]) || ""
    config["families"] = raw["families"].is_a?(Hash) ? raw["families"] : {}
    config["player_starter_types"] = raw["player_starter_types"].is_a?(Array) ? raw["player_starter_types"] : []
    config["legacy_player_starters"] = raw["player_starters"] if raw["player_starters"].is_a?(Array)
    config
  rescue JSON::ParserError => e
    raise ArgumentError, "wiki/config.json no es JSON válido: #{e.message}"
  end

  def save(config, path = CONFIG_PATH)
    FileUtils.mkdir_p(File.dirname(path))
    temp = "#{path}.tmp"
    File.write(temp, JSON.pretty_generate(config) + "\n")
    File.rename(temp, path)
  ensure
    File.delete(temp) if temp && File.file?(temp)
  end

  def player_starter_type_ids(config, species)
    configured = Array(config["player_starter_types"])
    return configured unless configured.empty?

    legacy_ids = Array(config["legacy_player_starters"])
    legacy_ids.concat(config["families"].values.flat_map do |family|
      family.is_a?(Hash) && family["versions"].is_a?(Hash) ? family["versions"].values.filter_map do |assignment|
        clean_text(assignment["starter"]) if assignment.is_a?(Hash)
      end : []
    end)
    legacy_ids.filter_map { |id| species[id]&.dig(:types)&.first&.to_s }.uniq
  end

  def build_groups(trainers, config, species)
    configured_starter_types = player_starter_type_ids(config, species)
    grouped = trainers.values.group_by { |entry| entry[:family_key] }
    duplicate_names = grouped.values.group_by { |entries| entries.first[:name].to_s }
    duplicate_ordinals = duplicate_names.transform_values do |entries|
      entries.each_with_index.to_h { |group, index| [group.first[:family_key], index + 1] }
    end

    grouped.values.map do |entries|
      entries.sort_by! { |entry| entry[:version].to_i }
      first = entries.first
      family_key = first[:family_key]
      family_config = config.dig("families", family_key) || {}
      name = first[:name].to_s
      siblings = duplicate_names[name]
      default_label = if siblings.size > 1
                        "#{name} — combate #{duplicate_ordinals[name][family_key]}"
                      else
                        "#{first[:type_name]} #{name}".strip
                      end
      label = clean_text(family_config["label"]) || default_label
      variants = entries.map.with_index do |entry, index|
        version_key = entry[:version].to_s
        family_versions = family_config["versions"].is_a?(Hash) ? family_config["versions"] : {}
        has_family_override = family_versions.key?(version_key)
        assignment = has_family_override ? family_versions[version_key] : {}
        raw_modes = if has_family_override
                      assignment.is_a?(Hash) ? (assignment["modes"] || assignment["mode"]) : []
                    else
                      config.dig("version_modes", version_key)
                    end
        available_modes = Array(config["modes"])
        assigned_modes = Array(raw_modes).filter_map do |value|
          mode = clean_text(value)
          mode if available_modes.include?(mode)
        end.uniq
        legacy_starter_id = clean_text(assignment["starter"])
        starter_type_id = clean_text(assignment["starter_type"])
        starter_type_id ||= species[legacy_starter_id]&.dig(:types)&.first&.to_s
        starter_type_id = nil unless configured_starter_types.include?(starter_type_id)
        starter_type = GameData::Type.try_get(starter_type_id)
        entry.merge(
          mode: assigned_modes.first,
          modes: assigned_modes,
          fallback_modes: [],
          starter_type_id: (starter_type_id if starter_type),
          starter_type_name: (starter_type&.name || starter_type_id),
          variant_label: (clean_text(assignment["label"]) if assignment.is_a?(Hash)),
          alternative_label: ("Equipo alternativo #{letter(index)}" if entries.size > 1 && assigned_modes.empty?),
          common_team: entries.size == 1 && assigned_modes.empty?
        )
      end
      explicit_modes = variants.map { |variant| variant[:modes].dup }
      mode_fallbacks = config["mode_fallbacks"].is_a?(Hash) ? config["mode_fallbacks"] : {}
      resolve_mode = lambda do |mode, visited|
        direct = explicit_modes.each_index.select { |index| explicit_modes[index].include?(mode) }
        next direct unless direct.empty?

        source = mode_fallbacks[mode]
        next [] unless source && !visited.include?(mode)

        resolve_mode.call(source, visited + [mode])
      end
      mode_fallbacks.each do |target_mode, source_mode|
        next if explicit_modes.any? { |assigned| assigned.include?(target_mode) }

        resolve_mode.call(source_mode, [target_mode]).each do |index|
          variant = variants[index]
          variant[:modes] = (variant[:modes] + [target_mode]).uniq
          variant[:fallback_modes] = (Array(variant[:fallback_modes]) + [target_mode]).uniq
        end
      end
      modes = variants.flat_map { |variant| variant[:modes] }.uniq
      starters = variants.filter_map do |variant|
        [variant[:starter_type_id], variant[:starter_type_name]] if variant[:modes].any? && variant[:starter_type_id]
      end.uniq
      {
        key: family_key, page_id: first[:family_page_id], family_key: family_key, label: label, name: name,
        type_name: first[:type_name], trainer_type: first[:trainer_type],
        variants: variants, modes: modes, starters: starters,
        unconfigured_variants: variants.count { |variant| variant[:modes].empty? },
        party_count: variants.sum { |variant| variant[:party].size }
      }
    end.sort_by { |group| [group[:name].downcase, group[:type_name].downcase, group[:key]] }
  end

  def page_id(label, family_key)
    slug = label.to_s.downcase.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "")
               .gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    "#{slug.empty? ? 'combate' : slug}-#{Digest::SHA256.hexdigest(family_key)[0, 8]}"
  end

  def family_key(trainer_type, name)
    [trainer_type.to_s, name.to_s.gsub(/\s+/, "_")].join("-").gsub(/[^A-Za-z0-9_\-]/, "")
  end

  def clean_text(value)
    text = value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�").strip
    text.empty? ? nil : text
  end

  def letter(index)
    value = index + 1
    output = +""
    while value.positive?
      value -= 1
      output.prepend((65 + value % 26).chr)
      value /= 26
    end
    output
  end
end
