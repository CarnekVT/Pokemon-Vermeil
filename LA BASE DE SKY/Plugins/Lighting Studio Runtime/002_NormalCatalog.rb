# encoding: UTF-8
# Lighting Studio — cached asset-name resolver for character normal-map shading.
# One global naming rule works for player, follower and changing Pokémon forms.
# An active sprite's graphic name selects the matching normal resource.
module LightingStudio
  NORMAL_ROOT = 'Graphics/LightingStudio/Normals'
  NORMAL_FOLDERS = {
    'characters' => 'Characters',
    'tilesets' => 'Tilesets',
    'autotiles' => 'Autotiles'
  }.freeze
  @normal_resource_cache = {}
  @normal_settings_cache = nil

  module_function

  def normal_graphic_name(graphic)
    str = graphic.to_s.strip.tr('\\', '/')
    str = str.sub(/\A(?:Graphics\/)?(?:Characters|Tilesets|Autotiles)\//i, '')
    str = str.sub(/\.(?:png|bmp|gif|jpg|jpeg)\z/i, '')
    return nil if str.empty? || str.size > 180 || str.start_with?('/')
    parts = str.split('/')
    return nil if parts.empty? || parts.any? { |part| part.empty? || part == '.' || part == '..' }
    return nil if str =~ /[\x00-\x1f:*?"<>|]/
    str
  end

  def normal_settings
    return @normal_settings_cache if @normal_settings_cache
    data = {}
    begin
      if File.file?(DATA_PATH) && defined?(JSON) && JSON.respond_to?(:parse)
        project = JSON.parse(File.binread(DATA_PATH))
        data = project['normalSettings'] if project.is_a?(Hash) && project['normalSettings'].is_a?(Hash)
      end
    rescue StandardError => e
      warn "[Lighting Studio] Normal settings could not be read: #{e.message}"
    end
    @normal_settings_cache = data
  end

  def normal_reset_cache
    @normal_settings_cache = nil
    @normal_resource_cache = {}
  end

  # The global settings are loaded once, and file existence is cached:
  # no file reads or sprite-specific variables are required per frame.
  # `map_settings` supports older maps with their own manual assignments.
  def normal_map_path(category, graphic, map_settings = nil)
    folder = NORMAL_FOLDERS[category.to_s.downcase]
    name = normal_graphic_name(graphic)
    return nil unless folder && name
    cfg = normal_settings
    if cfg['enabled'] != true && map_settings.is_a?(Hash)
      cfg = map_settings
    end
    return nil unless cfg.is_a?(Hash) && cfg['enabled'] == true
    manual = cfg[category.to_s.downcase]
    manual = [] unless manual.is_a?(Array)
    assignment = manual.find do |entry|
      entry.is_a?(Hash) && normal_graphic_name(entry['source']) == name
    end
    return nil if assignment && assignment['enabled'] == false
    suffix = cfg['suffix'].to_s
    suffix = '_n' unless /\A_[a-z0-9]{1,12}\z/i.match?(suffix)
    automatic = cfg['auto']
    auto_enabled = !automatic.is_a?(Hash) || automatic[category.to_s.downcase] != false
    normal_name = assignment ? normal_graphic_name(assignment['normal']) : nil
    return nil unless normal_name || auto_enabled
    normal_name ||= name + suffix
    path = NORMAL_ROOT + '/' + folder + '/' + normal_name + '.png'
    if @normal_resource_cache.key?(path)
      return @normal_resource_cache[path] ? path : nil
    end
    exists = File.file?(path)
    @normal_resource_cache[path] = exists
    exists ? path : nil
  end

  # Runtime helper for any Sprite_Character or follower implementation.
  # Always read the graphic currently displayed, never the Pokemon species ID.
  def normal_for_character(character, map_settings = nil)
    return nil unless character
    graphic = character.respond_to?(:character_name) ? character.character_name : nil
    normal_map_path('characters', graphic, map_settings)
  end

  def normal_for_character_sprite(sprite, map_settings = nil)
    return nil unless sprite
    graphic = sprite.respond_to?(:character_name) ? sprite.character_name : nil
    if !graphic || graphic.to_s.empty?
      character = sprite.instance_variable_get(:@character) if sprite.instance_variable_defined?(:@character)
      graphic = character.character_name if character && character.respond_to?(:character_name)
    end
    normal_map_path('characters', graphic, map_settings)
  end
end
