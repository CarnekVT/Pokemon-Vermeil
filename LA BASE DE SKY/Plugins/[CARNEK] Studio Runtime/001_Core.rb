#===============================================================================
# [CARNEK] Studio Runtime 0.2.0
# Shared data/runtime for Maker Studio authoring tools.
#===============================================================================
module CarnekStudio
  require 'json'
  DATA_DIR = "Data/CarnekStudio"
  module_function
  def ensure_data_dir
    Dir.mkdir(DATA_DIR) unless Dir.exist?(DATA_DIR)
    DATA_DIR
  rescue
    DATA_DIR
  end
  def path(name); File.join(DATA_DIR, name); end
  def load_json(name, fallback = nil)
    p = path(name)
    return fallback unless File.exist?(p)
    JSON.parse(File.binread(p))
  rescue => e
    PBDebug.log("[CarnekStudio] #{name}: #{e.message}") if defined?(PBDebug)
    fallback
  end
  def ruby_value(v)
    case v
    when Array then v.map { |x| ruby_value(x) }
    when Hash  then v.each_with_object({}) { |(k,x),h| h[k] = ruby_value(x) }
    when String
      return v[1..-1].to_sym if v.match?(/^:[A-Za-z_]\w*$/)
      v
    else v
    end
  end
  def safe_const_set(path, value)
    parts = path.to_s.split("::").reject(&:empty?)
    return false if parts.empty?
    owner = Object
    parts[0...-1].each { |p| owner = owner.const_get(p) }
    key = parts[-1].to_sym
    owner.send(:remove_const, key) if owner.const_defined?(key, false)
    owner.const_set(key, ruby_value(value))
    true
  rescue => e
    PBDebug.log("[CarnekStudio] config #{path}: #{e.message}") if defined?(PBDebug)
    false
  end
  def apply_plugin_config
    data = load_json("plugin_config.json", {"groups"=>[]})
    (data["groups"] || []).each do |g|
      (g["settings"] || []).each { |s| safe_const_set(s["constant"], s["value"]) }
    end
  end
  def export_save_snapshot
    Dir.mkdir(DATA_DIR) unless Dir.exist?(DATA_DIR)
    snapshot = {
      "time" => Time.now.to_s,
      "map" => ($game_map ? {"id"=>$game_map.map_id, "x"=>$game_player.x, "y"=>$game_player.y} : nil),
      "player" => (defined?($player) && $player ? {"name"=>$player.name, "money"=>$player.money, "party"=>$player.party.map { |p| {"species"=>p.species.to_s,"level"=>p.level,"hp"=>p.hp,"status"=>p.status.to_s} }} : nil),
      "switches" => (defined?($game_switches) && $game_switches ? $game_switches.instance_variable_get(:@data) : nil),
      "variables" => (defined?($game_variables) && $game_variables ? $game_variables.instance_variable_get(:@data) : nil)
    }
    File.binwrite(path("save_snapshot.json"), JSON.pretty_generate(snapshot))
    snapshot
  end
end
