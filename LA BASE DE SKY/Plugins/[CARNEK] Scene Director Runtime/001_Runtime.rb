# encoding: utf-8
# Scene Director Runtime
# Lee las escenas visuales bajo demanda. No escanea ni parsea el JSON al arrancar.

module SceneDirector
  DATA_FILE = "Data/SceneDirector/scenes.json"
  @cache = nil
  @cache_mtime = nil

  class << self
    def available?
      defined?(SceneEngine::Player) && File.exist?(DATA_FILE)
    end

    def clear_cache
      @cache = nil
      @cache_mtime = nil
    end

    def data
      return { "scenes" => [] } unless File.exist?(DATA_FILE)
      mtime = (File.mtime(DATA_FILE).to_i rescue 0)
      return @cache if @cache && @cache_mtime == mtime
      begin
        require "json" unless defined?(JSON)
        raw = File.open(DATA_FILE, "rb") { |f| f.read }
        raw = raw.force_encoding("UTF-8") if raw.respond_to?(:force_encoding)
        @cache = JSON.parse(raw)
        @cache_mtime = mtime
      rescue => e
        echoln("[Scene Director] No se pudo leer #{DATA_FILE}: #{e.class}: #{e.message}") rescue nil
        @cache = { "scenes" => [] }
      end
      @cache
    end

    def scenes
      arr = data["scenes"]
      arr.is_a?(Array) ? arr : []
    end

    def find(id)
      key = id.to_s
      scenes.find { |s| s["id"].to_s == key || s["key"].to_s == key || s["name"].to_s == key }
    end

    def play_once(id, map_id, event_id, self_switch = "A")
      key = [map_id.to_i, event_id.to_i, self_switch.to_s.upcase]
      raise "Scene Director: play_once requiere un evento de mapa válido." if key[0] <= 0 || key[1] <= 0 || !["A","B","C","D"].include?(key[2])
      return false if $game_self_switches[key] || @playing
      result = play(id)
      if result
        $game_self_switches[key] = true
        $game_map.need_refresh = true if $game_map && $game_map.map_id == key[0]
      end
      result
    end

    def play(id)
      return false if @playing
      @playing = true
      begin
        result = play_internal(id)
        release_scene_input
        result
      ensure
        @playing = false
      end
    end

    # The map interpreter returns into Scene_Map#update on the same tick.
    # Drain the dialogue press before the map can interpret it as an interaction.
    def release_scene_input
      buttons = [:USE, :C, :ACTION, :BACK, :B].filter_map do |name|
        Input.const_get(name) if Input.const_defined?(name)
      end.uniq
      $game_temp.interact_calling = false if $game_temp
      Input.update
      while buttons.any? { |button| Input.press?(button) }
        Graphics.update
        Input.update
      end
      # Clear the trigger/release edge as well as a queued map interaction.
      2.times { Graphics.update; Input.update }
      $game_temp.interact_calling = false if $game_temp
    end

    def play_internal(id)
      raise "Scene Engine no está cargado." unless defined?(SceneEngine::Player)
      scene = find(id)
      raise "Scene Director: escena '#{id}' no encontrada en #{DATA_FILE}." unless scene
      code = scene["compiledRuby"].to_s
      raise "Scene Director: la escena '#{id}' no tiene compiledRuby. Ábrela y guarda desde el Studio." if code.empty?
      visited = {}
      reserved_event = nil
      loop do
        key = scene["key"] || scene["id"]
        raise "Scene Director: bucle entre escenas '#{key}'." if visited[key]
        visited[key] = true
        player = SceneEngine::Player.new(dialogue_data: {}, start_black: false, strict_assets: true)
        player.run do
          instance_eval(code, "SceneDirector/#{key}", 1)
        end
        reserved_event = player.scene_event_id || reserved_event
        target = player.scene_next_key
        break if !target || target.empty?
        scene = find(target)
        raise "Scene Director: escena '#{target}' no encontrada." unless scene
        code = scene["compiledRuby"].to_s
        raise "Scene Director: guarda la escena '#{target}' desde el Studio." if code.empty?
      end
      $game_temp.common_event_id = reserved_event if reserved_event && $game_temp
      true
    end

    def keys
      scenes.map { |s| s["key"].to_s }.reject(&:empty?)
    end
  end
end

# Útil durante desarrollo: el JSON puede cambiar sin recompilar plugins.
EventHandlers.add(:on_game_load, :scene_director_clear_cache,
  proc { SceneDirector.clear_cache }
) if defined?(EventHandlers)

if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :scene_director_test, {
    "name"        => _INTL("Scene Director"),
    "parent"      => :main,
    "description" => _INTL("Prueba una escena creada con Scene Director Studio."),
    "effect"      => proc {
      list = SceneDirector.scenes
      if list.empty?
        pbMessage(_INTL("No hay escenas en {1}.", SceneDirector::DATA_FILE))
        next false
      end
      commands = list.map { |s| s["name"].to_s.empty? ? s["key"].to_s : s["name"].to_s }
      choice = pbMessage(_INTL("Elige una escena."), commands, -1)
      if choice && choice >= 0 && choice < list.length
        begin
          SceneDirector.play(list[choice]["key"] || list[choice]["id"])
        rescue => e
          pbMessage(_INTL("No se pudo reproducir la escena: {1}", e.message))
        end
      end
      next false
    }
  })
end
