# Vermeil Smooth Movement - configuracion INI sin JSON, FileUtils ni gemas.
module VermeilMovement
  CONFIG_PATH = "Plugins/[VERMEIL] Smooth Movement/config.ini"
  DEFAULTS = {
    "directions"        => "4",
    "mode"              => "grid",
    "subtile_divisions" => "4",
    "instant_turn"      => "1",
    "input_buffer_ms"   => "0",
    "wall_slide"        => "0",
    "smooth_movement"   => "1",
    "camera_smoothing"  => "35"
  }
  ALLOWED = {
    "directions"        => ["4", "8"],
    "mode"              => ["grid", "free"],
    "subtile_divisions" => ["4", "8"],
    "instant_turn"      => ["0", "1"],
    "input_buffer_ms"   => ["0", "60", "100", "150"],
    "wall_slide"        => ["0", "1"],
    "smooth_movement"   => ["0", "1"]
  }

  def self.reload!
    @sections = nil
    @last_mtime = nil
    @last_poll = nil
  end

  def self.sections
    poll_changes!
    return @sections if @sections
    parsed = { "global" => DEFAULTS.dup }
    section = "global"
    begin
      File.foreach(CONFIG_PATH) do |line|
        line = line.sub(/[;#].*$/, "").strip
        next if line.empty?
        if line =~ /^\[(global|map:\d+)\]$/i
          section = $1.downcase
          parsed[section] ||= {}
        elsif line =~ /^([a-z_]+)\s*=\s*(.*?)\s*$/i
          key = $1.downcase
          value = $2
          next unless DEFAULTS.key?(key)
          next if ALLOWED[key] && !ALLOWED[key].include?(value)
          next if key == "camera_smoothing" && !(0..100).include?(value.to_i)
          parsed[section][key] = value
        end
      end
    rescue Errno::ENOENT, Errno::EACCES
      # La configuracion de fabrica mantiene jugable el proyecto.
    end
    @sections = parsed
    @last_mtime = config_mtime
    return @sections   # Nunca devolver File.mtime (objeto Time).
  end

  # Detecta cambios guardados por Maker Studio sin reiniciar la partida.
  # El chequeo se limita a dos veces por segundo para no hacer I/O por frame.
  def self.config_mtime
    File.mtime(CONFIG_PATH)
  rescue Errno::ENOENT, Errno::EACCES
    nil
  end

  def self.poll_changes!
    return unless @sections
    # Leer el INI con reloj real para no depender de la velocidad del Turbo.
    now = System.respond_to?(:unscaled_uptime) ? System.unscaled_uptime : System.uptime
    return if @last_poll && now >= @last_poll && now - @last_poll < 0.5
    @last_poll = now
    @sections = nil if config_mtime != @last_mtime
  end

  def self.option(name, map_id = nil)
    id = map_id || ($game_map.map_id if defined?($game_map) && $game_map)
    config = sections
    map = id ? config["map:#{id}"] : nil
    return map[name] if map && map.key?(name)
    config["global"][name] || DEFAULTS[name]
  end

  def self.enabled?(name)
    option(name) == "1"
  end

  def self.directions
    option("directions").to_i
  end

  def self.free?
    option("mode") == "free"
  end

  def self.subtiles
    option("subtile_divisions").to_i
  end

  def self.input_buffer_ms
    option("input_buffer_ms").to_i
  end

  def self.camera_smoothing
    option("camera_smoothing").to_i
  end
end
