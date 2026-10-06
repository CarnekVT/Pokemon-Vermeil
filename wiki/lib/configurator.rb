# frozen_string_literal: true

require "socket"
require "securerandom"
require "json"
require "rbconfig"
require_relative "trainer_variants"

module WikiConfigurator
  ROOT = File.expand_path("..", __dir__)
  ASSET_DIR = File.join(ROOT, "assets")
  MAX_BODY = 2 * 1024 * 1024

  module_function

  def open(config:, groups:, species:)
    server = TCPServer.new("127.0.0.1", 0)
    token = SecureRandom.hex(24)
    url = "http://127.0.0.1:#{server.addr[1]}/?token=#{token}"
    puts "Abriendo el configurador local…"
    puts "Si no se abre el navegador, visita: #{url}"
    open_browser(url)

    loop do
      client = server.accept
      finish = handle(client, token, config, groups, species)
      break if finish
    end
    TrainerVariants.load
  ensure
    server&.close
  end

  def handle(client, token, config, groups, species)
    request_line = client.gets("\r\n")
    return false unless request_line

    method, target, = request_line.split(" ", 3)
    headers = {}
    while (line = client.gets("\r\n")) && line != "\r\n"
      key, value = line.split(":", 2)
      headers[key.downcase] = value.to_s.strip if key
    end
    length = headers.fetch("content-length", "0").to_i
    raise ArgumentError, "La petición es demasiado grande." if length > MAX_BODY

    body = length.positive? ? client.read(length).to_s : ""
    path, query = target.to_s.split("?", 2)
    params = query.to_s.split("&").to_h { |part| part.split("=", 2) }

    case [method, path]
    when ["GET", "/"]
      raise ArgumentError, "Enlace de configurador no válido." unless secure_equal(params["token"], token)

      send_response(client, 200, "text/html; charset=utf-8", File.read(File.join(ROOT, "configurator.html")))
    when ["GET", "/api/data"]
      authorize!(headers, token, client)
      payload = {
        config: config.merge("player_starter_types" => TrainerVariants.player_starter_type_ids(config, species)),
        families: groups.select { |group| group[:variants].size > 1 }.map do |group|
          {
            key: group[:key], label: group[:label], name: group[:name],
            type_name: group[:type_name], trainer_type: group[:trainer_type],
            versions: group[:variants].map do |variant|
              party = variant[:party].map do |pokemon|
                form_id = pokemon[:form].to_i.positive? ? "#{pokemon[:species]}_#{pokemon[:form]}" : pokemon[:species]
                entry = species[form_id] || species[pokemon[:species]]
                species_name = entry ? entry[:name].to_s : pokemon[:species].to_s
                form_name = entry && entry[:form_name].to_s
                display_name = [species_name, form_name].reject(&:empty?).join(" · ")
                nickname = pokemon[:name].to_s
                display_name = "#{display_name} (#{nickname})" unless nickname.empty? || nickname == species_name
                {
                  name: display_name, level: pokemon[:level], shiny: pokemon[:shiny],
                  types: Array(entry && entry[:types]).map { |id| GameData::Type.try_get(id)&.name || id.to_s }
                }
              end
              { version: variant[:version], label: variant[:variant_label], starter_type: variant[:starter_type_id], party: party }
            end
          }
        end,
        pbs_versions: groups.flat_map { |group| group[:variants].map { |variant| [variant[:version].to_s, group[:key]] } }
                            .group_by(&:first).sort_by { |version, _| version.to_i }
                            .map { |version, entries| { version: version, combats: entries.map(&:last).uniq.size } },
        starter_types: species.values.flat_map { |entry| Array(entry[:types]) }.uniq
                            .filter_map do |id|
          type = GameData::Type.try_get(id)
          { id: id.to_s, name: type&.name || id.to_s } if type
        end.sort_by { |entry| entry[:name].downcase }
      }
      send_response(client, 200, "application/json; charset=utf-8", JSON.generate(payload))
    when ["POST", "/api/save"]
      authorize!(headers, token, client)
      updated = validate_config(JSON.parse(body), groups, species)
      Boot.unguarded { TrainerVariants.save(updated) }
      config.replace(updated)
      send_response(client, 200, "application/json; charset=utf-8", JSON.generate(ok: true))
    when ["POST", "/api/finish"]
      authorize!(headers, token, client)
      send_response(client, 200, "application/json; charset=utf-8", JSON.generate(ok: true))
      return true
    when ["GET", "/configurator.css"], ["GET", "/configurator.js"]
      filename = File.basename(path)
      content_type = filename.end_with?(".css") ? "text/css; charset=utf-8" : "text/javascript; charset=utf-8"
      send_response(client, 200, content_type, File.read(File.join(ROOT, filename)))
    when ["GET", "/assets/style.css"]
      send_response(client, 200, "text/css; charset=utf-8", File.read(File.join(ASSET_DIR, "style.css")))
    when ["GET", "/theme.js"]
      send_response(client, 200, "text/javascript; charset=utf-8", File.read(File.join(ASSET_DIR, "theme.js")))
    else
      send_response(client, 404, "text/plain; charset=utf-8", "No encontrado")
    end
    false
  rescue StandardError => e
    send_response(client, 400, "application/json; charset=utf-8", JSON.generate(error: e.message))
    false
  ensure
    client.close unless client.closed?
  end

  def validate_config(raw, groups, species)
    raise ArgumentError, "La configuración debe ser un objeto JSON." unless raw.is_a?(Hash)

    settings = TrainerVariants::DEFAULT_SETTINGS.merge(raw["settings"].is_a?(Hash) ? raw["settings"] : {})
    %w[out baseline].each do |key|
      settings[key] = TrainerVariants.clean_text(settings[key]) || TrainerVariants::DEFAULT_SETTINGS[key]
    end
    %w[sprites recompile].each { |key| settings[key] = !!settings[key] }
    %w[accent_light accent_dark].each do |key|
      value = settings[key].to_s
      raise ArgumentError, "El color #{key} debe tener formato #RRGGBB." unless value.match?(/\A#[0-9a-fA-F]{6}\z/)

      settings[key] = value.downcase
    end

    modes = Array(raw["modes"]).filter_map do |value|
      mode = TrainerVariants.clean_text(value)
      raise ArgumentError, "El nombre de un modo no puede superar 60 caracteres." if mode && mode.length > 60

      mode
    end.uniq
    available_starter_types = species.values.flat_map { |entry| Array(entry[:types]) }.map(&:to_s).uniq
    player_starter_types = Array(raw["player_starter_types"]).filter_map do |value|
      id = TrainerVariants.clean_text(value)
      id if id && available_starter_types.include?(id)
    end.uniq
    if player_starter_types.empty?
      player_starter_types = Array(raw["player_starters"]).filter_map do |id|
        species[id]&.dig(:types)&.first&.to_s
      end.uniq
    end
    available_versions = groups.flat_map { |group| group[:variants].map { |variant| variant[:version].to_s } }.uniq
    version_modes = {}
    (raw["version_modes"].is_a?(Hash) ? raw["version_modes"] : {}).each do |version, values|
      next unless available_versions.include?(version.to_s)

      version_modes[version.to_s] = Array(values).filter_map do |value|
        mode = TrainerVariants.clean_text(value)
        mode if modes.include?(mode)
      end.uniq
    end
    mode_fallbacks = {}
    (raw["mode_fallbacks"].is_a?(Hash) ? raw["mode_fallbacks"] : {}).each do |target, source|
      target_mode = TrainerVariants.clean_text(target)
      source_mode = TrainerVariants.clean_text(source)
      next unless target_mode && source_mode && target_mode != source_mode && modes.include?(target_mode) && modes.include?(source_mode)

      mode_fallbacks[target_mode] = source_mode
    end
    mode_fallbacks.each_key do |start_mode|
      visited = {}
      current_mode = start_mode
      while (next_mode = mode_fallbacks[current_mode])
        raise ArgumentError, "Las reglas de sustitución de modos no pueden formar un ciclo." if visited[current_mode]

        visited[current_mode] = true
        current_mode = next_mode
      end
    end
    default_mode = modes.include?(raw["default_mode"]) ? raw["default_mode"] : modes.first.to_s
    allowed_groups = groups.to_h { |group| [group[:key], group] }
    families = {}
    (raw["families"].is_a?(Hash) ? raw["families"] : {}).each do |key, family|
      group = allowed_groups[key]
      next unless group && family.is_a?(Hash)

      label = TrainerVariants.clean_text(family["label"]) || group[:label]
      raise ArgumentError, "El nombre de un combate no puede superar 100 caracteres." if label.length > 100

      available_versions = group[:variants].to_h { |variant| [variant[:version].to_s, true] }
      versions = {}
      (family["versions"].is_a?(Hash) ? family["versions"] : {}).each do |version, assignment|
        next unless available_versions[version.to_s] && assignment.is_a?(Hash)

        assigned_modes = Array(assignment["modes"] || assignment["mode"]).filter_map do |value|
          mode = TrainerVariants.clean_text(value)
          mode if modes.include?(mode)
        end.uniq
        starter_type_id = TrainerVariants.clean_text(assignment["starter_type"])
        legacy_starter_id = TrainerVariants.clean_text(assignment["starter"])
        starter_type_id ||= species[legacy_starter_id]&.dig(:types)&.first&.to_s
        starter_type_id = nil unless player_starter_types.include?(starter_type_id)
        variant_label = TrainerVariants.clean_text(assignment["label"])
        raise ArgumentError, "El nombre visible de un equipo no puede superar 80 caracteres." if variant_label && variant_label.length > 80

        versions[version.to_s] = { "modes" => assigned_modes, "starter_type" => starter_type_id, "label" => variant_label }.compact
      end
      families[key] = { "label" => label, "versions" => versions }
    end
    raw_features = raw["features"].is_a?(Hash) ? raw["features"] : {}
    features = TrainerVariants::FEATURE_DEFAULTS.to_h do |key, default|
      [key, raw_features.key?(key) ? raw_features[key] == true : default]
    end
    {
      "settings" => settings, "features" => features, "version_modes" => version_modes,
      "mode_fallbacks" => mode_fallbacks, "player_starter_types" => player_starter_types, "modes" => modes,
      "default_mode" => default_mode, "families" => families
    }
  end

  def authorize!(headers, token, client)
    raise ArgumentError, "Sesión local no válida." unless secure_equal(headers["x-wiki-token"], token)
    host = headers["host"].to_s
    origin = headers["origin"]
    raise ArgumentError, "La petición debe venir del configurador local." unless host.start_with?("127.0.0.1:")
    raise ArgumentError, "La petición debe venir del configurador local." if origin && origin != "http://#{host}"
  end

  def secure_equal(left, right)
    return false unless left && right && left.bytesize == right.bytesize

    left.bytes.zip(right.bytes).reduce(0) { |diff, (a, b)| diff | (a ^ b) }.zero?
  end

  def send_response(client, status, content_type, body)
    phrase = { 200 => "OK", 400 => "Bad Request", 404 => "Not Found" }.fetch(status, "Error")
    response = body.to_s
    client.write("HTTP/1.1 #{status} #{phrase}\r\n")
    client.write("Content-Type: #{content_type}\r\n")
    client.write("Content-Length: #{response.bytesize}\r\n")
    client.write("Cache-Control: no-store\r\n")
    client.write("X-Content-Type-Options: nosniff\r\n")
    client.write("Connection: close\r\n\r\n")
    client.write(response)
  end

  def open_browser(url)
    case RbConfig::CONFIG["host_os"]
    when /darwin/i
      system("open", url, out: File::NULL, err: File::NULL)
    when /mswin|mingw|cygwin/i
      system("cmd", "/c", "start", "", url, out: File::NULL, err: File::NULL)
    else
      system("xdg-open", url, out: File::NULL, err: File::NULL)
    end
  rescue StandardError
    nil
  end
end
