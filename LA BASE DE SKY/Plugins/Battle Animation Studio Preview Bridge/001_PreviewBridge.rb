#===============================================================================
# Battle Animation Studio - Preview / Import Bridge v1.2
# Captures:
# - effective screen size and Battle::Scene battler positions
# - legacy Animations.rxdata data
# - the commands actually executed by Battle::Scene::Animation/PictureEx
#   (loops, rand, helpers and callbacks are therefore observed at runtime)
#===============================================================================
module BattleAnimationStudioPreviewBridge
  OUTPUT_DIR        = File.join("PBS", "AnimationStudio")
  OUTPUT_FILE       = File.join(OUTPUT_DIR, "battle_context.json")
  LEGACY_FILE       = File.join(OUTPUT_DIR, "legacy_animations.json")
  CODE_CAPTURE_FILE = File.join(OUTPUT_DIR, "code_capture.json")
  VERSION           = 12
   DEFAULT_WIDTH     = 512
   DEFAULT_HEIGHT    = 384
   DEFAULT_BATTLER_WIDTH  = 96
   DEFAULT_BATTLER_HEIGHT = 96
   @sessions         = {}

  module_function

  def json_escape(value)
    value.to_s.gsub(/\\/) { "\\\\" }.gsub(/\"/) { "\\\"" }
             .gsub(/\r/) { "\\r" }.gsub(/\n/) { "\\n" }.gsub(/\t/) { "\\t" }
  end

  def to_json_value(value)
    case value
    when Hash
      "{" + value.map { |key, val| "\"#{json_escape(key)}\":" + to_json_value(val) }.join(",") + "}"
    when Array
      "[" + value.map { |val| to_json_value(val) }.join(",") + "]"
    when String, Symbol
      "\"#{json_escape(value)}\""
    when Numeric
      value.respond_to?(:finite?) && !value.finite? ? "0" : value.to_s
    when TrueClass then "true"
    when FalseClass then "false"
    when NilClass then "null"
    else "\"#{json_escape(value)}\""
    end
  end

  def ensure_output_dir
    current = ""
    OUTPUT_DIR.split(/[\\\/]+/).each do |part|
      current = current.empty? ? part : File.join(current, part)
      Dir.mkdir(current) unless Dir.exist?(current)
    end
  rescue
    nil
  end

  def write_json(path, data)
    ensure_output_dir
    File.open(path, "wb") { |file| file.write(to_json_value(data)) }
  rescue => e
    echoln("[Battle Animation Studio] #{e.class}: #{e.message}") if defined?(echoln)
  end

  def safe_number(value, fallback = 0)
    ret = value.to_f
    return fallback if ret.respond_to?(:nan?) && (ret.nan? || ret.infinite?)
    ret
  rescue
    fallback
  end

  def settings_dimension(name, fallback)
    return fallback if !defined?(Settings)
    return safe_number(Settings.const_get(name), fallback).to_i if Settings.const_defined?(name)
    fallback
  rescue
    fallback
  end

  # Some projects keep Graphics at the old default until their screen plugin
  # applies Settings. Prefer the non-default value, otherwise the live Graphics.
  def dimensions
    gw = (Graphics.width rescue DEFAULT_WIDTH).to_i
    gh = (Graphics.height rescue DEFAULT_HEIGHT).to_i
    sw = settings_dimension(:SCREEN_WIDTH, gw)
    sh = settings_dimension(:SCREEN_HEIGHT, gh)
    # Settings is the effective source used by this project for its custom
    # 640x480 battle scene. Prefer it when it represents a larger explicit
    # canvas than Graphics currently reports (plugins may resize later).
    if sw >= 160 && sh >= 120 && ((gw == DEFAULT_WIDTH && gh == DEFAULT_HEIGHT) || (sw * sh > gw * gh))
      width, height = sw, sh
    else
      width, height = gw, gh
    end
    [width, height, gw, gh, sw, sh]
  end

  def normalize_value(value, depth = 0)
    return nil if depth > 3
    case value
    when NilClass, TrueClass, FalseClass, Numeric, String
      value
    when Symbol
      value.to_s
    when Array
      value.map { |v| normalize_value(v, depth + 1) }
    when Hash
      ret = {}
      value.each { |k, v| ret[k.to_s] = normalize_value(v, depth + 1) }
      ret
    else
      if defined?(Tone) && value.is_a?(Tone)
        { "__type" => "Tone", "red" => value.red, "green" => value.green, "blue" => value.blue, "gray" => value.gray }
      elsif defined?(Color) && value.is_a?(Color)
        { "__type" => "Color", "red" => value.red, "green" => value.green, "blue" => value.blue, "alpha" => value.alpha }
      elsif defined?(Rect) && value.is_a?(Rect)
        { "__type" => "Rect", "x" => value.x, "y" => value.y, "width" => value.width, "height" => value.height }
      elsif value.is_a?(Proc)
        { "__type" => "Proc" }
      else
        { "__type" => value.class.to_s, "value" => value.to_s }
      end
    end
  rescue
    value.to_s
  end

  def sprite_data(sprite)
    return nil if !sprite
    bitmap = (sprite.bitmap rescue nil)
    bw = (bitmap && !bitmap.disposed?) ? bitmap.width : DEFAULT_BATTLER_WIDTH
    bh = (bitmap && !bitmap.disposed?) ? bitmap.height : DEFAULT_BATTLER_HEIGHT
    x = safe_number((sprite.x rescue 0)); y = safe_number((sprite.y rescue 0))
    {
      "x" => x, "y" => y,
      # This is the same focal convention used by New Animation Editor.
      "focus_x" => x, "focus_y" => y - (bh / 2.0),
      "zoom_x" => safe_number((sprite.zoom_x rescue 1.0), 1.0),
      "zoom_y" => safe_number((sprite.zoom_y rescue 1.0), 1.0),
      "z" => safe_number((sprite.z rescue 0)),
      "ox" => safe_number((sprite.ox rescue bw / 2.0)),
      "oy" => safe_number((sprite.oy rescue bh)),
      "bitmap_width" => bw, "bitmap_height" => bh,
      "visible" => ((sprite.visible rescue true) ? true : false),
      "mirror" => ((sprite.mirror rescue false) ? true : false),
      "angle" => safe_number((sprite.angle rescue 0)),
      "opacity" => safe_number((sprite.opacity rescue 255), 255),
      "tone" => normalize_value((sprite.tone rescue nil)),
      "color" => normalize_value((sprite.color rescue nil))
    }
  rescue
    nil
  end

  def side_size(battle, index)
    return 1 if !battle
    value = (battle.pbSideSize(index) rescue nil)
    value = (battle.pbSideSize(index % 2) rescue nil) if !value
    (value || 1).to_i
  rescue
    1
  end

  def battler_position(index, size = 1)
    begin
      pos = Battle::Scene.pbBattlerPosition(index, size)
      return [safe_number(pos[0]), safe_number(pos[1])] if pos
    rescue
    end
    begin
      pos = Battle::Scene.pbBattlerPosition(index)
      return [safe_number(pos[0]), safe_number(pos[1])] if pos
    rescue
    end
    [0, 0]
  end

  def method_source(klass, method_name)
    meth = klass.method(method_name) rescue nil
    loc = meth && meth.source_location
    return nil if !loc
    { "file" => loc[0].to_s, "line" => loc[1].to_i, "owner" => meth.owner.to_s }
  rescue
    nil
  end

  def battler_data(sprites, battle, index)
    sprite = sprites["pokemon_#{index}"] rescue nil
    data = sprite_data(sprite)
    if !data
      pos = battler_position(index, side_size(battle, index))
      data = { "x" => pos[0], "y" => pos[1], "focus_x" => pos[0], "focus_y" => pos[1] - (DEFAULT_BATTLER_HEIGHT / 2),
               "zoom_x" => 1, "zoom_y" => 1, "z" => 100, "ox" => DEFAULT_BATTLER_WIDTH / 2, "oy" => DEFAULT_BATTLER_HEIGHT,
               "bitmap_width" => DEFAULT_BATTLER_WIDTH, "bitmap_height" => DEFAULT_BATTLER_HEIGHT, "visible" => true,
               "mirror" => false, "angle" => 0, "opacity" => 255, "tone" => nil, "color" => nil }
    end
    battler = (battle && battle.respond_to?(:battlers)) ? (battle.battlers[index] rescue nil) : nil
    pkmn = nil
    pkmn = battler.visiblePokemon if battler && battler.respond_to?(:visiblePokemon)
    pkmn = battler.pokemon if !pkmn && battler && battler.respond_to?(:pokemon)
    data["species"] = (pkmn && pkmn.respond_to?(:species)) ? pkmn.species.to_s.upcase : ""
    data["form"] = (pkmn && pkmn.respond_to?(:form)) ? pkmn.form.to_i : 0
    data["index"] = index
    data["side_size"] = side_size(battle, index)
    data
  rescue
    nil
  end

  def scene_indices(scene, args = [])
    sprites = (scene.instance_variable_get(:@sprites) rescue {}) || {}
    battle = (scene.instance_variable_get(:@battle) rescue nil)
    user = args[1] rescue nil; targets = args[2] rescue nil
    user_index = (user && user.respond_to?(:index)) ? user.index.to_i : 0
    target_index = nil
    [targets].flatten.compact.each do |target|
      next if !target.respond_to?(:index)
      idx = target.index.to_i
      if idx != user_index
        target_index = idx
        break
      end
    end
    target_index ||= (user_index.even? ? 1 : 0)
    [sprites, battle, user_index, target_index]
  rescue
    [{}, nil, 0, 1]
  end

  def build_context(scene = nil, args = [], kind = "static")
    width, height, gw, gh, sw, sh = dimensions
    sprites, battle, user_index, target_index = scene ? scene_indices(scene, args) : [{}, nil, 0, 1]
    indices = []
    sprites.each_key do |key|
      match = key.to_s.match(/^pokemon_(\d+)$/)
      indices << match[1].to_i if match
    end
    indices |= [user_index, target_index]
    battlers = indices.sort.map { |idx| battler_data(sprites, battle, idx) }.compact
    user_pos = battler_position(user_index, side_size(battle, user_index))
    target_pos = battler_position(target_index, side_size(battle, target_index))
    {
      "version" => VERSION,
      "capture_kind" => kind,
      "captured_at" => Time.now.strftime("%Y-%m-%dT%H:%M:%S.%L"),
      "scene_class" => scene ? scene.class.to_s : "Battle::Scene",
      "move" => (args[0].to_s rescue ""),
      "width" => width, "height" => height,
      "graphics_width" => gw, "graphics_height" => gh,
      "settings_width" => sw, "settings_height" => sh,
      "user_index" => user_index, "target_index" => target_index,
      "user_side_size" => side_size(battle, user_index), "target_side_size" => side_size(battle, target_index),
      "user_battler_position" => user_pos, "target_battler_position" => target_pos,
      "script_positions" => { "user" => user_pos, "target" => target_pos },
      "battler_position_method" => method_source(Battle::Scene, :pbBattlerPosition),
      "battlers" => battlers,
      "bases" => {
        "user" => sprite_data((sprites[user_index.even? ? "base_0" : "base_1"] rescue nil)),
        "target" => sprite_data((sprites[target_index.even? ? "base_0" : "base_1"] rescue nil))
      }
    }
  end

  def capture_static(kind = "plugin_load")
    write_json(OUTPUT_FILE, build_context(nil, [], kind))
  end

  def context_signature(data)
    battlers = (data["battlers"] || []).map do |b|
      [b["index"], b["x"].to_f.round(2), b["y"].to_f.round(2), b["zoom_x"].to_f.round(3), b["zoom_y"].to_f.round(3), b["z"].to_f.round(2), b["angle"].to_f.round(2), b["opacity"].to_f.round(1), b["visible"]]
    end
    [data["width"], data["height"], data["user_index"], data["target_index"], data["user_battler_position"], data["target_battler_position"], battlers].inspect
  rescue
    Time.now.to_f.to_s
  end

  def capture_scene(scene, args = [], kind = "battle_scene", only_if_changed = false)
    return capture_static(kind) if !scene
    data = build_context(scene, args, kind)
    if only_if_changed
      signature = context_signature(data)
      return if @last_scene_signature == signature
      @last_scene_signature = signature
    else
      @last_scene_signature = context_signature(data)
    end
    write_json(OUTPUT_FILE, data)
  end

  #--------------------------------------------------------------------------
  # Legacy animation export
  #--------------------------------------------------------------------------
  def anim_frame_indices
    names = %w[X Y ZOOMX ZOOMY BLENDTYPE ANGLE OPACITY PATTERN PRIORITY VISIBLE MIRROR FOCUS]
    ret = {}
    return ret if !defined?(AnimFrame)
    names.each { |name| ret[name.downcase] = AnimFrame.const_get(name) rescue nil }
    ret.delete_if { |_k, v| v.nil? }
    ret
  end

  def export_legacy_animations
    return if !defined?(pbLoadBattleAnimations)
    list = pbLoadBattleAnimations rescue nil
    return if !list || !list.respond_to?(:each_with_index)
    output = []
    list.each_with_index do |anim, id|
      next if !anim
      name = (anim.name rescue "").to_s
      next if name.empty?
      length = (anim.length rescue 0).to_i
      next if length <= 0
      frames = []
      length.times do |frame_index|
        frame = (anim[frame_index] rescue nil)
        frames << ((frame && frame.respond_to?(:map)) ? frame.map { |cel| cel && cel.respond_to?(:map) ? cel.map { |v| v } : nil } : [])
      end
      output << { "id" => id, "name" => name, "animation_name" => (anim.graphic rescue "").to_s,
                  "position" => (anim.position rescue 1).to_i, "frame_max" => length, "frames" => frames }
    end
    write_json(LEGACY_FILE, { "version" => VERSION, "animframe" => anim_frame_indices, "animations" => output })
  rescue => e
    echoln("[Battle Animation Studio Legacy Export] #{e.class}: #{e.message}") if defined?(echoln)
  end

  #--------------------------------------------------------------------------
  # Code animation runtime recorder
  #--------------------------------------------------------------------------
  def animation_source(animation)
    meth = animation.method(:createProcesses) rescue nil
    loc = meth && meth.source_location
    loc ? { "file" => loc[0].to_s, "line" => loc[1].to_i } : { "file" => "", "line" => 0 }
  rescue
    { "file" => "", "line" => 0 }
  end

  def animation_user_index(animation)
    user = animation.instance_variable_get(:@user) rescue nil
    user && user.respond_to?(:index) ? user.index.to_i : 0
  rescue
    0
  end

  def animation_target_index(animation, user_index)
    target = animation.instance_variable_get(:@target) rescue nil
    target ||= ([animation.instance_variable_get(:@targets)].flatten.compact.first rescue nil)
    target && target.respond_to?(:index) ? target.index.to_i : (user_index.even? ? 1 : 0)
  rescue
    user_index.even? ? 1 : 0
  end

  def active_code_context
    @active_code_context || {}
  end

  def with_code_context(data)
    previous = @active_code_context
    @active_code_context = data || {}
    yield
  ensure
    @active_code_context = previous
  end

  def session_for(animation, create = true)
    key = animation.object_id
    current = @sessions[key]
    return current if current || !create
    source = animation_source(animation)
    ui = animation_user_index(animation); ti = animation_target_index(animation, ui)
    current = {
      "version" => VERSION, "class_name" => animation.class.to_s,
      "source_file" => source["file"], "source_line" => source["line"],
      "move" => ((animation.instance_variable_get(:@move_id).to_s rescue "").to_s.empty? ? active_code_context["move"].to_s : (animation.instance_variable_get(:@move_id).to_s rescue "")),
      "behavior" => (active_code_context["behavior"] || ((animation.class.const_get(:BEHAVIOR) rescue nil)) || :cinematic).to_s,
      "hit_num" => (active_code_context["hit_num"] || (animation.instance_variable_get(:@hit_num) rescue 0) || 0).to_i,
      "side_context" => (active_code_context["side_context"] || (ui.odd? ? "foe" : "player")).to_s,
      "scene_envelope" => active_code_context["scene_envelope"],
      "user_index" => ui, "target_index" => ti,
      "pictures" => [], "battler_frames" => [], "frame_count" => 0,
      "fps" => ((Graphics.frame_rate rescue 40).to_i),
      "picture_fps" => 20,
      "captured_at" => Time.now.strftime("%Y-%m-%dT%H:%M:%S.%L")
    }
    @sessions[key] = current
    current
  end

  def picture_initial(picture)
    picture_state(picture)
  rescue
    {}
  end

  # Capture the *resolved state* of PictureEx after its processes have actually
  # run. This is deliberately separate from the operation log: callbacks,
  # overlapping processes, rand, helper methods and moveDelta can all make the
  # final state differ from a naive replay of the method calls.
  def picture_state(picture)
    rect = (picture.src_rect rescue nil)
    tone = (picture.tone rescue nil)
    color = (picture.color rescue nil)
    {
      "x" => safe_number((picture.x rescue 0)), "y" => safe_number((picture.y rescue 0)),
      "z" => safe_number((picture.z rescue 0)),
      "zoom_x" => safe_number((picture.zoom_x rescue 100), 100),
      "zoom_y" => safe_number((picture.zoom_y rescue 100), 100),
      "angle" => safe_number((picture.angle rescue 0)),
      "opacity" => safe_number((picture.opacity rescue 255), 255),
      "visible" => ((picture.visible rescue true) ? true : false),
      "blend_type" => safe_number((picture.blend_type rescue 0)),
      "name" => (picture.name rescue "").to_s,
      "origin" => origin_name((picture.origin rescue nil)),
      "src" => rect ? { "x" => safe_number(rect.x), "y" => safe_number(rect.y), "width" => safe_number(rect.width), "height" => safe_number(rect.height) } : nil,
      "tone" => tone ? normalize_value(tone) : nil,
      "color" => color ? normalize_value(color) : nil
    }
  rescue
    {}
  end

  def same_bitmap?(a, b)
    return false if !a || !b
    ba = (a.bitmap rescue nil); bb = (b.bitmap rescue nil)
    ba && bb && ba.equal?(bb)
  rescue
    false
  end

  def sprite_role(animation, sprite)
    sprites = animation.instance_variable_get(:@sprites) rescue {}
    ui = animation_user_index(animation); ti = animation_target_index(animation, ui)
    us = sprites["pokemon_#{ui}"] rescue nil; ts = sprites["pokemon_#{ti}"] rescue nil
    return "user" if sprite && us && sprite.equal?(us)
    return "target" if sprite && ts && sprite.equal?(ts)
    return "user_clone" if sprite && same_bitmap?(sprite, us)
    return "target_clone" if sprite && same_bitmap?(sprite, ts)
    # Cinematic helpers (Explosion and similar) often build a temporary
    # Battle::Scene::BattlerSprite with the FRONT bitmap, then pass it through
    # addSprite. It is not bitmap-identical to the normal back sprite, so use
    # proximity to identify which battler it represents instead of treating it
    # as an anonymous effect (which previously produced a blank/duplicate body).
    if sprite && sprite.class.to_s.include?("BattlerSprite")
      sx = safe_number((sprite.x rescue 0)); sy = safe_number((sprite.y rescue 0))
      ux = safe_number((us.x rescue sx)); uy = safe_number((us.y rescue sy))
      tx = safe_number((ts.x rescue sx)); ty = safe_number((ts.y rescue sy))
      du = ((sx - ux) ** 2) + ((sy - uy) ** 2)
      dt = ((sx - tx) ** 2) + ((sy - ty) ** 2)
      return du <= dt ? "user_front_clone" : "target_front_clone"
    end
    "sprite"
  end

  def origin_name(origin)
    return "bottom" if defined?(PictureOrigin) && PictureOrigin.const_defined?(:BOTTOM) && origin == PictureOrigin::BOTTOM
    return "center" if defined?(PictureOrigin) && PictureOrigin.const_defined?(:CENTER) && origin == PictureOrigin::CENTER
    return "top_left" if defined?(PictureOrigin) && PictureOrigin.const_defined?(:TOP_LEFT) && origin == PictureOrigin::TOP_LEFT
    origin.to_s
  rescue
    origin.to_s
  end

  def register_picture(animation, picture, role, asset = nil, origin = nil, sprite = nil, initial_override = nil)
    return picture if !picture
    session = session_for(animation)
    existing = (picture.instance_variable_get(:@bas_capture_picture_id) rescue nil)
    return picture if existing
    id = session["pictures"].length + 1
    entry = { "id" => id, "name" => "#{role} #{id}", "role" => role.to_s,
              "asset" => asset.to_s, "origin" => origin_name(origin),
              "initial" => picture_initial(picture).merge(initial_override || {}), "ops" => [], "frames" => [] }
    entry["sprite"] = sprite.class.to_s if sprite
    session["pictures"] << entry
    picture.instance_variable_set(:@bas_capture_owner, animation)
    picture.instance_variable_set(:@bas_capture_picture_id, id)
    picture
  rescue
    picture
  end

  def record_picture_operation(picture, name, args)
    animation = picture.instance_variable_get(:@bas_capture_owner) rescue nil
    id = picture.instance_variable_get(:@bas_capture_picture_id) rescue nil
    return if !animation || !id
    session = session_for(animation, false)
    return if !session
    entry = session["pictures"].find { |p| p["id"] == id }
    return if !entry
    entry["ops"] << { "name" => name.to_s, "args" => normalize_value(args) }
  rescue
    nil
  end

  def snapshot_animation_pictures(animation)
    session = session_for(animation, false)
    return if !session
    pictures = (animation.instance_variable_get(:@pictureEx) rescue []) || []
    pictures.each do |picture|
      next if !picture
      id = (picture.instance_variable_get(:@bas_capture_picture_id) rescue nil)
      next if !id
      entry = session["pictures"].find { |p| p["id"] == id }
      next if !entry
      state = picture_state(picture)
      state["frame"] = session["frame_count"].to_i
      # Keep every resolved frame. Exact code capture is intentionally verbose:
      # repeated values are what preserve hard cuts/set operations instead of
      # accidentally interpolating them in the Studio.
      entry["frames"] << state
    end
  rescue
    nil
  end

  def snapshot_animation_battlers(animation)
    session = session_for(animation, false)
    return if !session
    sprites = animation.instance_variable_get(:@sprites) rescue {}
    ui = session["user_index"].to_i; ti = session["target_index"].to_i
    session["battler_frames"] << {
      "frame" => session["frame_count"].to_i,
      "user" => sprite_data((sprites["pokemon_#{ui}"] rescue nil)),
      "target" => sprite_data((sprites["pokemon_#{ti}"] rescue nil))
    }
  rescue
    nil
  end

  def advance_animation(animation)
    session = session_for(animation, false)
    return if !session
    # Battle::Scene::Animation#update has already updated PictureEx and copied
    # its state to the RGSS sprite when this hook runs. Capture that resolved
    # frame before advancing the counter.
    snapshot_animation_pictures(animation)
    snapshot_animation_battlers(animation)
    session["frame_count"] = session["frame_count"].to_i + 1
  end

  def flush_animation(animation)
    session = session_for(animation, false)
    return if !session
    snapshot_animation_pictures(animation)
    snapshot_animation_battlers(animation)
    session["capture_mode"] = "resolved_frames"
    write_json(CODE_CAPTURE_FILE, { "version" => VERSION, "capture" => session })
    @sessions.delete(animation.object_id)
  rescue
    @sessions.delete(animation.object_id) rescue nil
  end
end

# Update the context automatically whenever the project changes its screen size.
if defined?(Graphics) && Graphics.respond_to?(:resize_screen)
  module BattleAnimationStudioGraphicsHook
    def resize_screen(*args, &block)
      ret = super
      BattleAnimationStudioPreviewBridge.capture_static("resize_screen")
      ret
    end
  end
  Graphics.singleton_class.prepend(BattleAnimationStudioGraphicsHook) unless Graphics.singleton_class.ancestors.include?(BattleAnimationStudioGraphicsHook)
end

if defined?(Battle::Scene)
  # IMPORTANT: do not override/prepend pbInitSprites. A number of Essentials UI
  # plugins alias pbInitSprites after their own load order. Prepending here can
  # make a later alias point back into this module and create an infinite
  # Carnek -> BAS -> Carnek recursion. Instead, initialise context capture lazily
  # from pbUpdate once the live pokemon sprites exist.
  module BattleAnimationStudioSceneHook
    def pbUpdate(*args, &block)
      ret = super
      sprites = (instance_variable_get(:@sprites) rescue nil)
      has_battlers = sprites && (sprites["pokemon_0"] rescue nil) && (sprites["pokemon_1"] rescue nil)
      if has_battlers && !@bas_context_initialized
        @bas_context_initialized = true
        @bas_context_settle_frames = 16
        BattleAnimationStudioPreviewBridge.capture_scene(self, [], "battle_ready", true)
      end
      if has_battlers && @bas_context_settle_frames && @bas_context_settle_frames > 0
        @bas_context_settle_frames -= 1
        BattleAnimationStudioPreviewBridge.capture_scene(self, [], "battle_settle_#{@bas_context_settle_frames}", true)
      elsif has_battlers
        # Battle New/EBUI/DBK and project patches can reposition or rescale
        # battlers after initialisation. Poll the resolved live scene instead of
        # guessing the final layout from Metrics alone.
        @bas_context_live_poll = ((@bas_context_live_poll || 0) + 1) % 10
        BattleAnimationStudioPreviewBridge.capture_scene(self, [], "battle_live", true) if @bas_context_live_poll == 0
      end
      ret
    end

    def pbAnimation(*args, &block)
      BattleAnimationStudioPreviewBridge.capture_scene(self, args, "pbAnimation_before", true)
      ret = super
      BattleAnimationStudioPreviewBridge.capture_scene(self, args, "pbAnimation_after", true)
      ret
    end
  end
  Battle::Scene.prepend(BattleAnimationStudioSceneHook) unless Battle::Scene.ancestors.include?(BattleAnimationStudioSceneHook)
end

if defined?(Battle::Scene::Animation)
  module BattleAnimationStudioAnimationHook
    def addSprite(*args, &block)
      picture = super
      sprite = args[0]
      origin = args.length >= 2 ? args[1] : ((defined?(PictureOrigin) && PictureOrigin.const_defined?(:TOP_LEFT)) ? PictureOrigin::TOP_LEFT : nil)
      role = BattleAnimationStudioPreviewBridge.sprite_role(self, sprite)
      BattleAnimationStudioPreviewBridge.register_picture(self, picture, role, nil, origin, sprite)
      picture
    end

    def addNewSprite(*args, &block)
      picture = super
      asset = args[2]
      origin = args.length >= 4 ? args[3] : ((defined?(PictureOrigin) && PictureOrigin.const_defined?(:TOP_LEFT)) ? PictureOrigin::TOP_LEFT : nil)
      initial = { "x" => BattleAnimationStudioPreviewBridge.safe_number(args[0]), "y" => BattleAnimationStudioPreviewBridge.safe_number(args[1]) }
      BattleAnimationStudioPreviewBridge.register_picture(self, picture, "new_sprite", asset, origin, nil, initial)
      picture
    end

    def update(*args, &block)
      ret = super
      BattleAnimationStudioPreviewBridge.advance_animation(self)
      ret
    end

    def dispose(*args, &block)
      BattleAnimationStudioPreviewBridge.flush_animation(self)
      super
    end
  end
  Battle::Scene::Animation.prepend(BattleAnimationStudioAnimationHook) unless Battle::Scene::Animation.ancestors.include?(BattleAnimationStudioAnimationHook)
end

if defined?(PictureEx)
  module BattleAnimationStudioPictureExHook
  end
  %w[setVisible setZ moveOpacity moveXY setSE setZoom moveColor moveDelta setTone moveZoom setOpacity setBlendType moveTone setAngle setXY setSrc setSrcSize moveAngle setCallback moveZoomXY setZoomXY setBitmap setColor setOrigin setPokemonBitmap].each do |method_name|
    next if !PictureEx.method_defined?(method_name)
    BattleAnimationStudioPictureExHook.module_eval <<~RUBYCODE
      def #{method_name}(*args, &block)
        BattleAnimationStudioPreviewBridge.record_picture_operation(self, :#{method_name}, args)
        super
      end
    RUBYCODE
  end
  PictureEx.prepend(BattleAnimationStudioPictureExHook) unless PictureEx.ancestors.include?(BattleAnimationStudioPictureExHook)
end

# Install hooks that must run after every other plugin has loaded. This is
# especially important for VERMEIL's Cinematic Engine, which may be loaded after
# this bridge and bypass Battle::Scene#pbAnimation for its custom animations.
def BattleAnimationStudioPreviewBridge.install_late_hooks
  if defined?(Battle::Scene) && Battle::Scene.method_defined?(:pbPlayCinematicExplosionAnimation)
    unless defined?(BattleAnimationStudioExplosionSceneHook)
      Object.const_set(:BattleAnimationStudioExplosionSceneHook, Module.new do
        define_method(:pbPlayCinematicExplosionAnimation) do |user, targets|
          ui = (user.index rescue 0).to_i
          data = {
            "move" => "EXPLOSION", "behavior" => "cinematic", "hit_num" => 0,
            "side_context" => ui.odd? ? "foe" : "player",
            # Timings from VERMEIL's scene wrapper: black prelude, custom
            # animation begins after 28 scene frames and a white restore outro.
            "scene_envelope" => { "type" => "explosion", "pre_frames" => 28, "black_fade_in" => 14, "black_hold" => 14, "covered_custom_frames" => 20, "white_in" => 6, "white_hold" => 12, "white_out" => 16 }
          }
          BattleAnimationStudioPreviewBridge.with_code_context(data) { super(user, targets) }
        end
      end)
    end
    mod = Object.const_get(:BattleAnimationStudioExplosionSceneHook)
    Battle::Scene.prepend(mod) unless Battle::Scene.ancestors.include?(mod)
  end

  if defined?(Battle::Scene) && Battle::Scene.method_defined?(:pbPlayVermeilCinematic)
    unless defined?(BattleAnimationStudioVermeilSceneHook)
      Object.const_set(:BattleAnimationStudioVermeilSceneHook, Module.new do
        define_method(:pbPlayVermeilCinematic) do |anim_class, user, targets, mid, hit_num, behavior|
          ui = (user.index rescue 0).to_i
          data = {
            "move" => (mid.respond_to?(:id) ? mid.id : mid).to_s,
            "behavior" => behavior.to_s,
            "hit_num" => hit_num.to_i,
            "side_context" => ui.odd? ? "foe" : "player"
          }
          BattleAnimationStudioPreviewBridge.with_code_context(data) { super(anim_class, user, targets, mid, hit_num, behavior) }
        end
      end)
    end
    mod = Object.const_get(:BattleAnimationStudioVermeilSceneHook)
    Battle::Scene.prepend(mod) unless Battle::Scene.ancestors.include?(mod)
  end
end

if defined?(EventHandlers)
  EventHandlers.add(:on_game_load, :battle_animation_studio_context_refresh, proc {
    BattleAnimationStudioPreviewBridge.install_late_hooks
    BattleAnimationStudioPreviewBridge.capture_static("game_load")
    BattleAnimationStudioPreviewBridge.export_legacy_animations
  })
end

BattleAnimationStudioPreviewBridge.capture_static("plugin_load")
BattleAnimationStudioPreviewBridge.install_late_hooks
BattleAnimationStudioPreviewBridge.export_legacy_animations
