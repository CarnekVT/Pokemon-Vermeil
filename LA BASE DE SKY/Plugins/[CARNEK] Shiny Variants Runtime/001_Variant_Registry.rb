#===============================================================================
# [CARNEK] Shiny Variants Runtime - Registro de Variantes
#===============================================================================
module ShinyVariantRegistry
  @variants = {}
  @loaded = false

  module_function

  def parse_json(raw)
    begin
      require "json" unless defined?(JSON)
      return JSON.parse(raw) if defined?(JSON) && JSON.respond_to?(:parse)
    rescue => e
    end
    # Fallback parser usando regex si no está disponible la gema JSON
    res = { "variants" => [] }
    raw.scan(/\{[^{}]*"id"[^{}]*\}/) do |obj_str|
      item = {}
      obj_str.scan(/"(\w+)"\s*:\s*("(?:[^"\\]|\\.)*"|\d+|true|false|null)/) do |k, v|
        if v.start_with?('"')
          item[k] = v[1..-2]
        elsif v == "true"
          item[k] = true
        elsif v == "false"
          item[k] = false
        elsif v == "null"
          item[k] = nil
        else
          item[k] = v.to_i
        end
      end
      res["variants"] << item if item["id"]
    end
    return res if !res["variants"].empty?
    return nil
  end

  def load
    @variants = {
      "shiny" => {
        "id"     => "shiny",
        "name"   => "Variocolor (Shiny)",
        "folder" => "shiny",
        "color"  => "#facc15",
        "rate"   => 65536
      },
      "supershiny" => {
        "id"     => "supershiny",
        "name"   => "Super Variocolor",
        "folder" => "supershiny",
        "color"  => "#c084fc",
        "rate"   => 655360
      }
    }

    path = ShinyVariantsSettings::CONFIG_FILE
    alt_path = "./" + ShinyVariantsSettings::CONFIG_FILE
    target_path = File.exist?(path) ? path : (File.exist?(alt_path) ? alt_path : nil)

    if target_path
      begin
        raw = File.read(target_path)
        data = parse_json(raw)
        if data && data["variants"].is_a?(Array)
          data["variants"].each do |entry|
            id = entry["id"].to_s.downcase.strip
            next if id.empty?
            @variants[id] = entry
          end
          echoln "[ShinyVariants] Cargadas #{@variants.size} variantes desde #{target_path}" if ShinyVariantsSettings::DEBUG_LOG
        end
      rescue => e
        echoln "[ShinyVariants] Error leyendo #{target_path}: #{e.message}"
      end
    end
    @loaded = true
  end

  def reload!
    @loaded = false
    load
  end

  def ensure_loaded
    load unless @loaded
  end

  def all
    ensure_loaded
    return @variants.values
  end

  def all_ids
    ensure_loaded
    return @variants.keys.map(&:to_sym)
  end

  def get(id)
    ensure_loaded
    key = id.to_s.downcase.strip
    return @variants[key]
  end

  def exists?(id)
    ensure_loaded
    key = id.to_s.downcase.strip
    return @variants.key?(key)
  end

  def folder_for(id)
    info = get(id)
    return info["folder"] if info && info["folder"]
    return id.to_s.downcase
  end

  def badge_path(id)
    key = id.to_s.downcase.strip
    custom_badge = "#{ShinyVariantsSettings::BADGES_DIR}#{key}"
    return custom_badge if pbResolveBitmap(custom_badge)
    return "Graphics/UI/supershiny" if key == "supershiny" && pbResolveBitmap("Graphics/UI/supershiny")
    return "Graphics/UI/shiny" if pbResolveBitmap("Graphics/UI/shiny")
    return nil
  end
end

ShinyVariantRegistry.load
