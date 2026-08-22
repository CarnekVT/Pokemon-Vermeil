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

    def play(id)
      raise "Scene Engine no está cargado." unless defined?(SceneEngine::Player)
      scene = find(id)
      raise "Scene Director: escena '#{id}' no encontrada en #{DATA_FILE}." unless scene
      code = scene["compiledRuby"].to_s
      raise "Scene Director: la escena '#{id}' no tiene compiledRuby. Ábrela y guarda desde el Studio." if code.empty?
      player = SceneEngine::Player.new(dialogue_data: {})
      player.run do
        instance_eval(code, "SceneDirector/#{scene['key'] || scene['id']}", 1)
      end
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
