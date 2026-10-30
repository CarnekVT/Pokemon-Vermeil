# frozen_string_literal: true
# Vermeil Input Studio 1.0 - independent physical keyboard/controller action router.
# Does not modify Essentials' Input.rb or native mkxp keybinding database.
require "json"
require "fileutils"

module InputStudio
  VERSION = "1.0.1"
  ROOT = "Plugins/[VERMEIL] Input Studio"
  CONFIG = ROOT + "/actions.json"
  CONTEXTS = %w[global map menu battle bifrost]
  SCAN = {}
  ("A".."Z").each_with_index { |key, i| SCAN[key] = 4 + i }
  %w[1 2 3 4 5 6 7 8 9 0].each_with_index { |key, i| SCAN[key] = 30 + i }
  {
    "RETURN"=>40,"ESCAPE"=>41,"BACKSPACE"=>42,"TAB"=>43,"SPACE"=>44,
    "MINUS"=>45,"EQUALS"=>46,"LEFTBRACKET"=>47,"RIGHTBRACKET"=>48,
    "BACKSLASH"=>49,"SEMICOLON"=>51,"APOSTROPHE"=>52,"GRAVE"=>53,
    "COMMA"=>54,"PERIOD"=>55,"SLASH"=>56,"CAPSLOCK"=>57,
    "RIGHT"=>79,"LEFT"=>80,"DOWN"=>81,"UP"=>82,"INSERT"=>73,
    "HOME"=>74,"PAGEUP"=>75,"DELETE"=>76,"END"=>77,"PAGEDOWN"=>78,
    "LCTRL"=>224,"LSHIFT"=>225,"LALT"=>226,"LGUI"=>227,
    "RCTRL"=>228,"RSHIFT"=>229,"RALT"=>230,"RGUI"=>231
  }.each { |key, code| SCAN[key] = code }
  (1..12).each { |n| SCAN["F#{n}"] = 57 + n }
  PAD = %w[A B X Y BACK GUIDE START LEFTSTICK RIGHTSTICK LEFTSHOULDER RIGHTSHOULDER DPAD_UP DPAD_DOWN DPAD_LEFT DPAD_RIGHT].freeze
  LOCKED = %w[F1 F8 F9 F12].freeze

  # Action IDs, contexts and defaults are a developer-facing contract.
  # Player profile overrides are stored separately, never in this file.
  BASE = [
    ["move_up","Arriba","Movimiento","map",%w[UP],%w[DPAD_UP]],
    ["move_down","Abajo","Movimiento","map",%w[DOWN],%w[DPAD_DOWN]],
    ["move_left","Izquierda","Movimiento","map",%w[LEFT],%w[DPAD_LEFT]],
    ["move_right","Derecha","Movimiento","map",%w[RIGHT],%w[DPAD_RIGHT]],
    ["confirm","Aceptar / interactuar","General","global",%w[C RETURN],%w[A]],
    ["back","Volver / menú","General","global",%w[X ESCAPE],%w[B]],
    ["action","Acción adicional","Exploración","map",%w[Z],%w[X]],
    ["jump_up","Salto arriba","Exploración","map",%w[A],%w[LEFTSHOULDER]],
    ["jump_down","Salto abajo","Exploración","map",%w[S],%w[RIGHTSHOULDER]],
    ["special","Acceso rápido","Exploración","map",%w[D],%w[Y]],
    ["aux1","Auxiliar 1","Exploración","map",%w[Q],%w[LEFTSTICK]],
    ["aux2","Auxiliar 2","Exploración","map",%w[W],%w[RIGHTSTICK]],
    ["menu","Abrir menú","Exploración","map",%w[],%w[START]],
    ["bifrost_aim","Apuntar","Bifröst","bifrost",%w[F],%w[LEFTSHOULDER]],
    ["bifrost_ball_next","Siguiente Ball","Bifröst","bifrost",%w[E],%w[RIGHTSHOULDER]],
    ["bifrost_ball_prev","Anterior Ball","Bifröst","bifrost",%w[Q],%w[LEFTSHOULDER]],
    ["bifrost_team_next","Siguiente Pokémon","Bifröst","bifrost",%w[TAB],%w[DPAD_RIGHT]],
    ["bifrost_team_prev","Anterior Pokémon","Bifröst","bifrost",%w[BACKSPACE],%w[DPAD_LEFT]],
    ["bifrost_mode","Cambiar Ball / equipo","Bifröst","bifrost",%w[R],%w[Y]],
    ["bifrost_throw","Lanzar","Bifröst","bifrost",%w[SPACE],%w[X]]
  ].freeze

  class << self
    attr_reader :actions, :status
    def definitions
      @actions ||= begin
        definitions = {}
        BASE.each do |id, label, category, context, kb, pad|
          definitions[id] = { "id"=>id, "label"=>label, "category"=>category,
                              "context"=>context, "keyboard"=>kb.dup, "gamepad"=>pad.dup }
        end
        if File.file?(CONFIG)
          parsed = JSON.parse(File.read(CONFIG, encoding: "UTF-8"))
          Array(parsed["actions"]).each do |entry|
            next unless entry.is_a?(Hash)
            id = entry["id"].to_s
            next unless id.match?(/\A[a-z][a-z0-9_]{1,49}\z/)
            next unless CONTEXTS.include?(entry["context"])
            prev = definitions[id]
            label = entry["label"].to_s[0, 60]
            category = entry["category"].to_s[0, 30]
            next if label.empty? || category.empty?
            definitions[id] = {
              "id"=>id, "label"=>label, "category"=>category, "context"=>entry["context"],
              "keyboard"=>valid_keys(entry["keyboard"], "keyboard"),
              "gamepad"=>valid_keys(entry["gamepad"], "gamepad")
            }
          end
        end
        definitions
      rescue StandardError => e
        warn("[Input Studio] actions.json: #{e.message}")
        definitions
      end
    end

    def valid_keys(values, device)
      allowed = device == "gamepad" ? PAD : SCAN.keys
      Array(values).select { |x| x.is_a?(String) && allowed.include?(x) && (device=="gamepad" || !LOCKED.include?(x)) }.uniq.take(4)
    end

    def directory
      candidate = defined?(System) && System.respond_to?(:data_directory) ? System.data_directory : "."
      File.join((candidate && !candidate.empty?) ? candidate : ".", "InputStudio")
    end
    def profile_file
      File.join(directory, "controls.json")
    end
    def load!
      definitions
      @profile = {}
      if File.file?(profile_file)
        parsed = JSON.parse(File.read(profile_file, encoding: "UTF-8"))
        if parsed.is_a?(Hash) && parsed["bindings"].is_a?(Hash)
          parsed["bindings"].each do |id, entry|
            next unless @actions.key?(id) && entry.is_a?(Hash)
            @profile[id] = {}
            %w[keyboard gamepad].each do |device|
              @profile[id][device] = valid_keys(entry[device], device) if entry.key?(device)
            end
          end
        end
      end
      @status = "Controles cargados"
    rescue StandardError => e
      @status = "No se pudieron leer los controles: #{e.message}"
      @profile ||= {}
    end
    def profile
      load! unless @profile
      @profile
    end
    def bindings(id, device)
      item = definitions[id.to_s]
      return [] unless item
      own = profile[id.to_s]
      return own[device] if own && own.key?(device)
      item[device] || []
    end
    def conflicts(id, device, key)
      item = definitions[id.to_s]
      return [] unless item
      definitions.values.select do |other|
        next false if other["id"] == id.to_s
        next false unless other["context"] == item["context"] ||
                          other["context"] == "global" || item["context"] == "global"
        bindings(other["id"], device).include?(key)
      end.map { |other| other["label"] }
    end
    def conflicting_ids(id, device, key)
      item = definitions[id.to_s]
      return [] unless item
      definitions.values.select do |other|
        next false if other["id"] == id.to_s
        next false unless other["context"] == item["context"] ||
                          other["context"] == "global" || item["context"] == "global"
        bindings(other["id"], device).include?(key)
      end.map { |other| other["id"] }
    end

    # If force is true, remove the same physical key from other actions in the
    # shared context. The overlay requests explicit confirmation first.
    def assign(id, device, key, slot = 0, force = false)
      id = id.to_s
      return false unless definitions[id] && %w[keyboard gamepad].include?(device)
      return false unless valid_keys([key], device).include?(key)
      collisions = conflicting_ids(id, device, key)
      if !collisions.empty? && !force
        @status = "Conflicto: #{collisions.map { |other| definitions[other]['label'] }.join(', ')}"
        return false
      end
      old = Marshal.load(Marshal.dump(profile))
      collisions.each do |other|
        profile[other] ||= {}
        profile[other][device] = bindings(other, device).reject { |value| value == key }
      end
      slot = slot.to_i.clamp(0, 3)
      current = bindings(id, device).dup
      current.delete(key)
      current[slot] = key
      profile[id] ||= {}
      profile[id][device] = current.compact.uniq.take(4)
      return true if persist!
      @profile = old
      false
    rescue StandardError => e
      @profile = old if defined?(old) && old
      @status = "No se pudo reasignar: #{e.message}"
      false
    end

    def clear(id, device)
      return false unless definitions[id.to_s] && %w[keyboard gamepad].include?(device)
      old = Marshal.load(Marshal.dump(profile))
      profile[id.to_s] ||= {}
      profile[id.to_s][device] = []
      return true if persist!
      @profile = old
      false
    end
    def reset(id = nil)
      old = Marshal.load(Marshal.dump(profile))
      if id
        profile.delete(id.to_s)
      else
        @profile = {}
      end
      return true if persist!
      @profile = old
      false
    end
    def persist!
      FileUtils.mkdir_p(directory)
      target = profile_file
      temp = target + ".tmp"
      File.open(temp, "wb") do |f|
        f.write(JSON.pretty_generate({ "version"=>1, "bindings"=>profile }))
        f.flush
        f.fsync
      end
      # The player profile can already exist on Windows. Preserve a backup if
      # the platform does not allow rename() to replace the destination.
      begin
        File.rename(temp, target)
      rescue Errno::EEXIST, Errno::EACCES
        backup = target + ".bak"
        File.delete(backup) if File.file?(backup)
        File.rename(target, backup) if File.file?(target)
        begin
          File.rename(temp, target)
          File.delete(backup) if File.file?(backup)
        rescue StandardError
          File.rename(backup, target) if File.file?(backup) && !File.file?(target)
          raise
        end
      end
      @status = "Guardado en #{target}"
      true
    rescue StandardError => e
      @status = "No se pudo guardar: #{e.message}"
      false
    end

    def context
      return @context_override if @context_override
      klass = (defined?($scene) && $scene) ? $scene.class.name.to_s : ""
      return "battle" if klass.match?(/battle/i)
      if klass == "Scene_Map"
        if defined?($game_temp) && $game_temp &&
           ($game_temp.in_menu || $game_temp.message_window_showing)
          return "menu"
        end
        return "map"
      end
      "menu"
    end
    def with_context(value)
      old = @context_override
      @context_override = CONTEXTS.include?(value.to_s) ? value.to_s : nil
      yield
    ensure
      @context_override = old
    end
    def active?(id)
      action = definitions[id.to_s]
      return false unless action
      return true if action["context"] == "global"
      return action["context"] == context
    end
    def key_query(key, method)
      return false unless Input.respond_to?(method)
      Input.send(method, key.to_sym)
    rescue StandardError
      false
    end
    def pad_query(key, method)
      return false unless defined?(Input::Controller) && Input::Controller.respond_to?(method)
      Input::Controller.send(method, key.to_sym)
    rescue StandardError
      false
    end
    def query(id, mode)
      return false if @modal
      return false unless active?(id)
      method = { :press=>:pressex?, :trigger=>:triggerex?, :repeat=>:repeatex?, :release=>:releaseex? }[mode]
      return false unless method
      bindings(id, "keyboard").any? { |key| key_query(key, method) } ||
        bindings(id, "gamepad").any? { |key| pad_query(key, method) }
    end
    def press?(id); query(id, :press); end
    def trigger?(id); query(id, :trigger); end
    def repeat?(id); query(id, :repeat); end
    def release?(id); query(id, :release); end
    def label(id, device = "keyboard")
      bindings(id, device).join(" / ")
    end
    def input_name(id, device = "keyboard")
      label(id, device)
    end
    def modal?; !!@modal; end
    def modal=(value); @modal = !!value; end
    def enqueue_overlay; @queued = true unless @modal; end
    def take_overlay?
      return false unless @queued
      @queued = false
      true
    end
    def analog_direction
      return [0, 0] unless defined?(Input::Controller)
      return [0, 0] unless Input::Controller.respond_to?(:axes_left)
      x, y = Input::Controller.axes_left
      return [0, 0] if !x || !y
      [x > 0.45 ? 1 : x < -0.45 ? -1 : 0, y > 0.45 ? 1 : y < -0.45 ? -1 : 0]
    rescue StandardError
      [0, 0]
    end
    def direction
      return 0 if @modal
      x = (press?("move_right") ? 1 : 0) - (press?("move_left") ? 1 : 0)
      y = (press?("move_down") ? 1 : 0) - (press?("move_up") ? 1 : 0)
      ax, ay = analog_direction
      x = ax if x == 0
      y = ay if y == 0
      5 - 3 * y + x # RPG Maker keypad: 1..9, 5 means idle
    end
    def dir4(_moved_last_frame = nil)
      n = direction
      return 0 if n == 5
      return 4 if [1,4,7].include?(n)
      return 6 if [3,6,9].include?(n)
      return 8 if n == 8
      2
    end
    def dir8(*_args)
      n = direction
      n == 5 ? 0 : n
    end
  end
end

InputStudio.load!

# Legacy API adapter: override only game-facing logical buttons and movement.
# Preserve raw physical Input.pressex?/triggerex? etc and all other buttons.
module Input
  LEGACY_STUDIO_ACTIONS = {
    UP => "move_up", DOWN => "move_down", LEFT => "move_left", RIGHT => "move_right",
    USE => "confirm", BACK => "back", ACTION => "action",
    JUMPUP => "jump_up", JUMPDOWN => "jump_down",
    SPECIAL => "special", AUX1 => "aux1", AUX2 => "aux2"
  }.freeze

  class << self
    alias input_studio_native_press? press? unless method_defined?(:input_studio_native_press?)
    alias input_studio_native_trigger? trigger? unless method_defined?(:input_studio_native_trigger?)
    alias input_studio_native_repeat? repeat? unless method_defined?(:input_studio_native_repeat?)
    alias input_studio_native_release? release? unless method_defined?(:input_studio_native_release?)
    alias input_studio_native_dir4 dir4 unless method_defined?(:input_studio_native_dir4)
    alias input_studio_native_dir8 dir8 unless method_defined?(:input_studio_native_dir8)
    alias input_studio_native_update update unless method_defined?(:input_studio_native_update)
    def press?(button)
      id = LEGACY_STUDIO_ACTIONS[button]
      id && InputStudio.active?(id) ? InputStudio.press?(id) : input_studio_native_press?(button)
    end
    def trigger?(button)
      id = LEGACY_STUDIO_ACTIONS[button]
      id && InputStudio.active?(id) ? InputStudio.trigger?(id) : input_studio_native_trigger?(button)
    end
    def repeat?(button)
      id = LEGACY_STUDIO_ACTIONS[button]
      id && InputStudio.active?(id) ? InputStudio.repeat?(id) : input_studio_native_repeat?(button)
    end
    def release?(button)
      id = LEGACY_STUDIO_ACTIONS[button]
      id && InputStudio.active?(id) ? InputStudio.release?(id) : input_studio_native_release?(button)
    end
    # Essentials' Game_Player and Smooth Movement pass @moved_last_frame to
    # dir4, while the native mkxp API often receives zero arguments.
    # Accept either form; route the optional value to the map controller.
    def dir4(*args)
      if InputStudio.context == "map"
        InputStudio.dir4(*args)
      else
        input_studio_native_dir4(*args)
      end
    end
    def dir8(*args)
      if InputStudio.context == "map"
        InputStudio.dir8(*args)
      else
        input_studio_native_dir8(*args)
      end
    end
    def update
      input_studio_native_update
      InputStudio.enqueue_overlay if !InputStudio.modal? && InputStudio.key_query("F1", :triggerex?)
    end
  end
end
