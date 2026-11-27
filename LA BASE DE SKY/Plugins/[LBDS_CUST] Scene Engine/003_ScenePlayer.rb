# encoding: utf-8
class SceneEngine::Player
  def initialize(dialogue_data: nil, start_black: true, strict_assets: false)
    @scene_start_black = start_black
    @scene_strict_assets = strict_assets
    @dialog_data = dialogue_data || {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99_999
    @image_sprites = {}
    @scene_image_files = {}
    @scene_hidden_images = {}
    @scene_persistent_sheets = {}
    @scene_transformed_images = {}
    @scene_fx = {}
    @scene_fx_bitmaps = {}
    @sprites = {}
    @float_anim = nil
    @float_ghosts = []
    @aura_particles = []
    @scrolling_sprites = []
    @floating_sprites = []
  end

  attr_reader :scene_next_key, :scene_event_id

  def run(&block)
    setup_sprites
    catch(:scene_director_end) { instance_eval(&block) if block }
    finish_scene_transition if @scene_end_requested
  ensure
    cleanup
  end

  private

  def setup_sprites
    @sprites[:black] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites[:black].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    @sprites[:black].z = SceneEngine::Settings::LAYER_OVERLAY
    @sprites[:black].opacity = @scene_start_black ? 255 : 0

    @sprites[:white] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites[:white].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(255, 255, 255))
    @sprites[:white].z = SceneEngine::Settings::LAYER_OVERLAY + 1
    @sprites[:white].opacity = 0

    path = "#{SceneEngine::Settings::SCENES_DIR}/#{SceneEngine::Settings::TEXT_BOX_FILE}"
    if File.exist?(path + ".png")
      @sprites[:text_box] = Sprite.new(@viewport)
      @sprites[:text_box].bitmap = AnimatedBitmap.new(path).deanimate
      @sprites[:text_box].y = SceneEngine::Settings::TEXT_BOX_Y
      @sprites[:text_box].z = SceneEngine::Settings::LAYER_TEXTBOX
      @sprites[:text_box].opacity = 0
    end

    tw = Graphics.width - SceneEngine::Settings::TEXT_PAD_X * 2
    th = SceneEngine::Settings::TEXT_BOX_H - SceneEngine::Settings::TEXT_PAD_Y_TOP - SceneEngine::Settings::TEXT_PAD_Y_BOT
    
    # Lienzo del diálogo
    @sprites[:text] = BitmapSprite.new(tw, th, @viewport)
    @sprites[:text].x = SceneEngine::Settings::TEXT_PAD_X
    @sprites[:text].y = SceneEngine::Settings::TEXT_BOX_Y + SceneEngine::Settings::TEXT_PAD_Y_TOP
    @sprites[:text].z = SceneEngine::Settings::LAYER_TEXT
    @sprites[:text].opacity = 0
    pbSetSystemFont(@sprites[:text].bitmap)

    # NUEVO: Lienzo independiente para el Nombre del Speaker (evita parpadeos y cortes)
    @sprites[:speaker_text] = BitmapSprite.new(tw, 40, @viewport)
    @sprites[:speaker_text].x = SceneEngine::Settings::TEXT_PAD_X
    @sprites[:speaker_text].y = SceneEngine::Settings::TEXT_BOX_Y + 8
    @sprites[:speaker_text].z = SceneEngine::Settings::LAYER_TEXT
    @sprites[:speaker_text].opacity = 0
    pbSetSystemFont(@sprites[:speaker_text].bitmap)

    @sprites[:indicator] = Sprite.new(@viewport)
    ind_bmp = Bitmap.new(14, 10)
    c = SceneEngine::Settings::TEXT_COLOR
    sc = SceneEngine::Settings::TEXT_SHADOW
    ind_bmp.fill_rect(1, 1, 14, 2, sc)
    ind_bmp.fill_rect(3, 3, 10, 2, sc)
    ind_bmp.fill_rect(5, 5, 6, 2, sc)
    ind_bmp.fill_rect(7, 7, 2, 2, sc)
    ind_bmp.fill_rect(0, 0, 14, 2, c)
    ind_bmp.fill_rect(2, 2, 10, 2, c)
    ind_bmp.fill_rect(4, 4, 6, 2, c)
    ind_bmp.fill_rect(6, 6, 2, 2, c)
    
    @sprites[:indicator].bitmap = ind_bmp
    @sprites[:indicator].z = SceneEngine::Settings::LAYER_TEXT + 1
    @sprites[:indicator].x = Graphics.width - SceneEngine::Settings::TEXT_PAD_X - 14
    @sprites[:indicator].y = SceneEngine::Settings::TEXT_BOX_Y + SceneEngine::Settings::TEXT_BOX_H - 24
    @sprites[:indicator].opacity = 0
  end

  def cleanup
    dispose_scene_fx
    stop_float
    stop_aura
    stop_scrolling
    stop_floating
    @image_sprites.each_value { |s| s&.dispose rescue nil }
    @sprites.each_value { |s| s&.dispose rescue nil }
    @viewport.dispose
  rescue; end

  # El juego puede renderizar a 120 FPS. El guion, textos y efectos
  # trabajan a 60 pasos lógicos por segundo, sin depender del refresco.
  def update
    if @scene_parallel_fiber && Fiber.current == @scene_parallel_fiber
      Fiber.yield
      return
    end
    [:text_box, :name_box].each { |key| @sprites[key].update if @sprites[key].is_a?(SpriteWindow_Base) }
    unless @scene_finishing
      update_float
      update_aura_particles
      update_scrolling
      update_floating
    end
    update_scene_sheets
    update_scene_fx unless @scene_finishing
    # Graphics.frame_rate no siempre representa los FPS reales de mkxp-z.
    # mkxp.json fija 120; los guiones se escriben a 60 pasos/segundo.
    @scene_frame_remainder ||= 0.0
    @scene_logic_frame ||= 0
    @scene_logic_frame += 1
    fps = SceneEngine::Settings::CINEMATIC_RENDER_FPS.to_f
    logic = SceneEngine::Settings::CINEMATIC_LOGIC_FPS.to_f
    ratio = (fps > 0 && logic > 0) ? fps / logic : 1.0
    @scene_frame_remainder += ratio
    ticks = @scene_frame_remainder.floor
    @scene_frame_remainder -= ticks
    ticks = [[ticks, 1].max, 4].min
    ticks.times { Graphics.update }
    Input.update
  end

  def update_float
    return unless @float_anim
    anim = @float_anim
    anim[:counter] += 1
    frame_interval = (60.0 / anim[:fps]).round
    if anim[:counter] >= frame_interval
      anim[:counter] = 0
      anim[:frame] = (anim[:frame] + 1) % anim[:frames]
      anim[:sprite].src_rect.x = anim[:frame] * anim[:fw]
      if anim[:glow]
        anim[:glow].src_rect.x = anim[:sprite].src_rect.x
      end
      anim[:ghost_counter] = (anim[:ghost_counter] || 0) + 1
      if anim[:y] >= 0 && anim[:y] < anim[:end_y] && anim[:ghost_counter] >= anim[:ghost_interval] && @float_ghosts.length < 15
        anim[:ghost_counter] = 0
        ghost = Sprite.new(@viewport)
        ghost.bitmap = anim[:sprite].bitmap
        ghost.src_rect = anim[:sprite].src_rect.clone
        ghost.x = anim[:sprite].x
        ghost.y = anim[:sprite].y
        ghost.z = anim[:sprite].z - 1 - @float_ghosts.length
        ghost.opacity = 160
        if anim[:glow]
          ghost.blend_type = 1
          ghost.tone = Tone.new(255, 255, 255, 0)
        end
        @float_ghosts << ghost
      end
    end
    if anim[:y] < anim[:end_y]
      anim[:y] += anim[:speed]
      anim[:y] = anim[:end_y] if anim[:y] > anim[:end_y]
      anim[:sprite].y = anim[:y].round
      if anim[:glow]
        g = anim[:glow]
        g.x = anim[:sprite].x
        g.y = anim[:sprite].y
      end
    else
      anim[:bob] = (anim[:bob] || 0) + 1
      anim[:sprite].y = anim[:end_y] + Math.sin(anim[:bob] * 0.04) * 3
      if anim[:glow]
        g = anim[:glow]
        g.x = anim[:sprite].x
        g.y = anim[:sprite].y
        if anim[:land_timer].nil?
          anim[:land_timer] = 30
        end
        if anim[:land_timer] > 0
          anim[:land_timer] -= 1
          g.opacity = (255 * anim[:land_timer] / 30).round
        else
          g.blend_type = 0
          g.tone = Tone.new(0, 0, 0, 0)
          g.opacity = 0
        end
      end
    end
    @float_ghosts.each_with_index do |g, i|
      g.opacity -= 4
      g.y += 0.3
      g.zoom_x -= 0.002
      g.zoom_y -= 0.002
    end
    @float_ghosts.delete_if do |g|
      if g.disposed? || g.opacity <= 0 || g.zoom_x <= 0
        g.dispose rescue nil
        true
      else
        false
      end
    end
  end

  def bgm(name); name.nil? || name.empty? ? pbBGMStop : pbBGMPlay(name); end
  def bgs(name); name.nil? || name.empty? ? pbBGSStop : pbBGSPlay(name); end
  def se(name); pbSEPlay(name) if name; end
  def stop_bgm(fade_secs = 0); fade_secs > 0 ? pbBGMFade(fade_secs) : pbBGMStop; end
  def stop_bgs; pbBGSStop; end

  def scene_fade_bgm(seconds = 1.5)
    seconds = [[seconds.to_f,0].max,600].min
    stop_bgm(seconds)
    wait((seconds*60).round) if seconds > 0
  end

  def fade_from_black(dur = SceneEngine::Settings::FADE_DEFAULT)
    dur = 1 if dur < 1
    @sprites[:black].opacity = 255
    dur.times { |i| @sprites[:black].opacity = 255 - (255 * (i + 1) / dur); update }
    @sprites[:black].opacity = 0
  end

  def fade_to_black(dur = SceneEngine::Settings::FADE_DEFAULT)
    dur = 1 if dur < 1
    @sprites[:black].opacity = 0
    dur.times { |i| @sprites[:black].opacity = 255 * (i + 1) / dur; update }
    @sprites[:black].opacity = 255
  end

  def to_white(dur = SceneEngine::Settings::FADE_DEFAULT)
    dur = 1 if dur < 1
    @sprites[:white].opacity = 0
    dur.times { |i| @sprites[:white].opacity = 255 * (i + 1) / dur; update }
    @sprites[:white].opacity = 255
  end

  def from_white(dur = SceneEngine::Settings::FADE_DEFAULT, se: nil)
    dur = 1 if dur < 1
    @sprites[:white].opacity = 255
    se_vol = 0
    dur.times do |i|
      progress = (i + 1).to_f / dur
      @sprites[:white].opacity = (255 * (1 - progress)).round
      if se
        new_vol = (80 * progress).round
        Audio.se_play("Audio/SE/" + se, new_vol, 100) if new_vol != se_vol
        se_vol = new_vol
      end
      update
    end
    @sprites[:white].opacity = 0
  end

  # --- TRANSICIÓN FLUIDA PARA LA TEXTBOX ---
  def scene_textbox_alpha(alpha)
    [:text_box, :text, :speaker_text, :name_box].each do |key|
      sprite = @sprites[key]
      next if !sprite || sprite.disposed?
      sprite.opacity = alpha
    end
    @sprites[:indicator].opacity = 0 if alpha <= 0
  end

  def show_textbox(fade_frames = 10)
    from = @sprites[:text_box].opacity
    return if from >= 255
    frames = [fade_frames.to_i, 0].max
    frames.times { |i| scene_textbox_alpha((from + (255-from)*(i+1).to_f/frames).round); update }
    scene_textbox_alpha(255)
  end

  def hide_textbox(fade_frames = 10)
    from = @sprites[:text_box].opacity
    return if from <= 0
    @sprites[:indicator].opacity = 0
    frames = [fade_frames.to_i, 0].max
    frames.times { |i| scene_textbox_alpha((from*(1-(i+1).to_f/frames)).round); update }
    scene_textbox_alpha(0)
  end

  def show(filename, x = 0, y = 0, fade: SceneEngine::Settings::FADE_DEFAULT, origin: :top_left, zoom: 1, z: nil, instance_id: nil)
    key = instance_id ? instance_id.to_s : filename.to_s
    @scene_image_files[key] = filename.to_s
    @scene_hidden_images.delete(key)
    @scene_transformed_images.delete(key)
    @scene_persistent_sheets.delete(key)
    @image_sprites.delete(key)&.dispose

    s = Sprite.new(@viewport)
    begin
      s.bitmap = AnimatedBitmap.new(filename).deanimate
    rescue => e
      s.dispose
      raise "Scene Director: no se pudo cargar el gráfico '#{filename}': #{e.message}" if @scene_strict_assets
      return
    end

    case origin
    when :center
      x -= s.bitmap.width * zoom / 2
      y -= s.bitmap.height * zoom / 2
    when :bottom
      x -= s.bitmap.width * zoom / 2
      y -= s.bitmap.height * zoom
    end

    s.x = x
    s.y = y
    s.zoom_x = zoom
    s.zoom_y = zoom
    s.z = z || SceneEngine::Settings::LAYER_IMG + @image_sprites.size
    s.opacity = 0
    s.visible = true
    @image_sprites[key] = s

    if fade < 1
      s.opacity = 255
      return
    end
    fade.times { |i| s.opacity = 255 * (i + 1) / fade; update }
    s.opacity = 255
  end

  def image_clip(filename, x = 320, y = 240, origin: "center", zoom: 1, angle: 0,
                 opacity: 255, z: nil, duration: 120, enter: "fade", in_frames: 24,
                 exit: "none", out_frames: 24, keep: true, motion: "none", distance: 64,
                 easing: "smooth", end_x: nil, end_y: nil, end_zoom: nil,
                 end_angle: nil, end_opacity: nil, keys: [], resource_type: "static", columns: 1, rows: 1,
                 sheet_fps: 8, sheet_mode: "loop", sheet_start: 1, sheet_end: 0, sheet_frame: 1, sheet_persistent: false, instance_id: nil)
    duration = [[duration.to_i, 1].max, 360000].min
    persistent = resource_type == "sheet" && sheet_persistent && ["loop", "ping"].include?(sheet_mode)
    keep = true if persistent
    in_frames = enter == "none" ? 0 : [[in_frames.to_i, 0].max, duration].min
    out_frames = keep || exit == "none" ? 0 : [[out_frames.to_i, 0].max, duration - in_frames].min
    show(filename, x, y, fade: 0, origin: :top_left, zoom: zoom, z: z, instance_id: instance_id)
    key = instance_id ? instance_id.to_s : filename.to_s
    sprite = @image_sprites[key]
    return wait(duration) if !sprite || sprite.disposed?
    cols = resource_type == "sheet" ? [[columns.to_i,1].max,sprite.bitmap.width].min : 1
    row_count = resource_type == "sheet" ? [[rows.to_i,1].max,sprite.bitmap.height].min : 1
    fw, fh = sprite.bitmap.width / cols, sprite.bitmap.height / row_count
    total = cols * row_count
    first_frame = [[sheet_start.to_i-1,0].max,total-1].min
    last_frame = [[(sheet_end.to_i > 0 ? sheet_end.to_i : total)-1,first_frame].max,total-1].min
    count = last_frame-first_frame+1
    fps = [[sheet_fps.to_f,1].max,60].min
    sprite.ox = ["center", "bottom"].include?(origin) ? fw / 2 : 0
    sprite.oy = origin == "center" ? fh / 2 : origin == "bottom" ? fh : 0
    ease = lambda do |p|
      case easing
      when "linear" then p
      when "in" then p * p
      when "out" then 1 - (1 - p) * (1 - p)
      else p * p * (3 - 2 * p)
      end
    end
    distance = [distance.to_f, 0].max
    zoom = [[zoom.to_f, 0.01].max, 30].min
    opacity = [[opacity.to_f, 0].max, 255].min
    key_tracks = {}
    Array(keys).each do |row|
      next unless row.is_a?(Array) && row.length >= 3 && ["x", "y", "zoom", "angle", "opacity", "sheetFrame"].include?(row[0])
      (key_tracks[row[0]] ||= []) << row
    end
    key_tracks.each_value { |rows| rows.sort_by! { |row| row[1].to_f } }
    key_ease = lambda do |t, mode|
      t = [[t, 0.0].max, 1.0].min
      case mode
      when "hold" then t >= 1.0 ? 1.0 : 0.0
      when "linear" then t
      when "ease_in" then t*t
      when "ease_out" then 1-(1-t)*(1-t)
      else t < 0.5 ? 2*t*t : 1-(-2*t+2)**2/2
      end
    end
    key_value = lambda do |prop, f, base|
      rows = key_tracks[prop]
      next base unless rows && !rows.empty?
      first, last = rows.first, rows.last
      if f < first[1].to_f
        next base + (first[2].to_f-base)*key_ease.call(f.to_f/first[1].to_f,"ease_both")
      end
      next last[2].to_f if f >= last[1].to_f
      pair = rows.each_cons(2).find { |a,b| f >= a[1].to_f && f <= b[1].to_f }
      next base unless pair
      a,b = pair
      t = key_ease.call((f-a[1].to_f)/[b[1].to_f-a[1].to_f,0.0001].max,a[3])
      a[2].to_f+(b[2].to_f-a[2].to_f)*t
    end
    sample = lambda do |f|
      p = ease.call(f.to_f / duration)
      mix = ->(a,b) { a + (b-a)*p }
      ax, ay, az, ar, ao = x.to_f, y.to_f, zoom, angle.to_f, opacity
      case motion
      when "float" then ay += Math.sin(f*0.08)*distance*0.25
      when "shake" then ax += Math.sin(f*1.8)*distance*0.12
      when "pulse" then az *= 1+Math.sin(f*0.11)*0.12
      when "zoom_out" then az *= mix.call(1,0.5)
      when "zoom_in" then az *= mix.call(1,1.5)
      when "custom"
        ax = mix.call(ax,(end_x || x).to_f)
        ay = mix.call(ay,(end_y || y).to_f)
        az = mix.call(az,[[(end_zoom || zoom).to_f,0.01].max,30].min)
        ar = mix.call(ar,(end_angle || angle).to_f)
        ao = mix.call(ao,[[(end_opacity || opacity).to_f,0].max,255].min)
      end
      ax = key_value.call("x", f, x.to_f) if key_tracks["x"]
      ay = key_value.call("y", f, y.to_f) if key_tracks["y"]
      az = key_value.call("zoom", f, zoom) if key_tracks["zoom"]
      ar = key_value.call("angle", f, angle.to_f) if key_tracks["angle"]
      ao = key_value.call("opacity", f, opacity) if key_tracks["opacity"]
      effect = lambda do |k,t|
        next if k == "none"
        case k
        when "left" then ax -= distance*t
        when "right" then ax += distance*t
        when "up" then ay -= distance*t
        when "down" then ay += distance*t
        when "zoom" then az *= 1-0.8*t
        when "pop" then az *= [0.08,1-0.92*t+Math.sin(Math::PI*t)*0.38].max
        when "rotate"
          ar -= 90*t
          az *= 1-0.4*t
        end
        ao *= 1-t
      end
      effect.call(enter,1-ease.call(f.to_f/in_frames)) if in_frames > 0 && f < in_frames
      effect.call(exit,ease.call((f-duration+out_frames).to_f/out_frames)) if out_frames > 0 && f > duration-out_frames
      if resource_type == "sheet"
        tick = (f * fps / 60.0).floor
        idx = case sheet_mode
        when "once" then first_frame + [tick,count-1].min
        when "ping"
          period = [1,count*2-2].max
          t = tick % period
          first_frame + (t < count ? t : period-t)
        when "manual"
          key = (key_tracks["sheetFrame"] || []).select { |row| row[1].to_f <= f }.last
          [[(key ? key[2].to_i : sheet_frame.to_i)-1,first_frame].max,last_frame].min
        else first_frame + tick % count
        end
        sprite.src_rect.set((idx % cols)*fw,(idx / cols)*fh,fw,fh)
      end
      sprite.x, sprite.y = ax.round, ay.round
      sprite.zoom_x = sprite.zoom_y = az
      sprite.angle = -ar
      sprite.opacity = ao.round unless @scene_hidden_images[key]
    end
    sample.call(0)
    started_at = @scene_logic_frame || 0
    duration.times { |i| sample.call(i+1) unless @scene_transformed_images[key]; update }
    return sprite if @scene_transformed_images[key]
    if persistent && !@scene_hidden_images[key] && !sprite.disposed?
      @scene_persistent_sheets[key] = { sprite: sprite, start: started_at, cols: cols, fw: fw, fh: fh, first: first_frame, count: count, fps: fps, mode: sheet_mode }
    end
    sprite.visible = false unless keep
    sprite
  end

  def hide(filename = nil, fade: 0, instance_id: nil)
    keys = if instance_id && !instance_id.to_s.empty?
      [instance_id.to_s]
    elsif filename
      @image_sprites.keys.select { |k| k == filename.to_s || @scene_image_files[k] == filename.to_s }
    else
      @image_sprites.keys
    end
    targets = keys.filter_map do |k|
      s = @image_sprites[k]
      next if !s || s.disposed?
      @scene_hidden_images[k] = true
      [s, s.opacity]
    end
    fade = [fade.to_i,0].max
    fade.times do |i|
      targets.each { |s, alpha| s.opacity = (alpha * (1.0 - (i + 1).to_f / fade)).round unless s.disposed? }
      update
    end
    targets.each { |s, _| s.visible = false unless s.disposed? }
    keys.each { |key| @scene_persistent_sheets.delete(key) }
  end

  def hide_all(fade: 0)
    hide(nil, fade: fade)
  end

  def wait(frames)
    frames.times { update }
  end

  # Each eligible lane advances at the same 60 Hz logical clock.
  def parallel_scene(rows)
    pending = rows.each_with_index.sort_by { |row, i| [row[0].to_i, i] }.map(&:first)
    active = []
    completed = {}
    frame = 0
    until pending.empty? && active.empty?
      busy = active.map { |task| task[0] }
      ready = []
      pending.delete_if do |row|
        offset, lane, block, task_id, after_id, delay = row
        if offset.to_i <= frame && !busy.include?(lane) && (!after_id || (completed.key?(after_id) && frame >= completed[after_id] + [delay.to_i,0].max))
          busy << lane
          ready << [lane, Fiber.new { block.call }, task_id]
          true
        else
          false
        end
      end
      active.concat(ready)
      if active.empty? && !pending.empty? && pending.none? { |row| !row[4] || completed[row[4]] }
        raise "Scene Director: dependencia de acción inválida o circular."
      end
      active.each do |task|
        fiber = task[1]
        next unless fiber.alive?
        @scene_parallel_fiber = fiber
        begin
          fiber.resume
        ensure
          @scene_parallel_fiber = nil
        end
      end
      throw :scene_director_end if @scene_end_requested
      active.reject! do |task|
        done = !task[1].alive?
        completed[task[2]] = frame if done && task[2]
        done
      end
      break if active.empty? && pending.empty?
      update
      frame += 1
    end
  ensure
    @scene_parallel_fiber = nil
  end

  def update_scene_sheets
    @scene_persistent_sheets.delete_if do |key, data|
      sprite = data[:sprite]
      if sprite.disposed? || !sprite.visible
        true
      else
        elapsed = [(@scene_logic_frame || 0) - data[:start], 0].max
        tick = (elapsed * data[:fps] / 60.0).floor
        count = data[:count]
        if data[:mode] == "ping"
          phase = tick % [1, 2 * count - 2].max
          index = data[:first] + (phase < count ? phase : 2 * count - 2 - phase)
        else
          index = data[:first] + tick % count
        end
        sprite.src_rect.set((index % data[:cols]) * data[:fw], (index / data[:cols]) * data[:fh], data[:fw], data[:fh])
        false
      end
    end
  end

  def end_scene(style: "cut", fade_frames: 0, hold_frames: 0, breath_frames: 0)
    @scene_end_options = { style: style.to_s, fade: [[fade_frames.to_i,0].max,36000].min,
                           hold: [[hold_frames.to_i,0].max,36000].min, breath: [[breath_frames.to_i,0].max,36000].min }
    @scene_end_requested = true
    throw :scene_director_end unless @scene_parallel_fiber
  end

  # Called on the main fiber after the parallel scheduler has stopped.
  # The map remains frozen throughout the exit, including the breathing pause.
  def finish_scene_transition
    opts = @scene_end_options || { style: "cut", fade: 0, hold: 0, breath: 0 }
    opts[:hold].times { update }
    @scene_finishing = true
    sprites = @sprites.values + @image_sprites.values + @float_ghosts
    sprites += @aura_particles.map { |p| p[:sprite] }
    sprites += @scene_fx.values.flat_map { |fx| fx[:sprites] }
    sprites += @floating_sprites.map { |p| p[:sprite] }
    sprites += @scrolling_sprites.flat_map { |p| p[:sprites] || [] }
    sprites += [@float_anim[:sprite], @float_anim[:glow]] if @float_anim
    targets = sprites.compact.uniq.select { |s| s.respond_to?(:opacity) && !s.disposed? }
    initial = targets.map { |s| [s, s.opacity, s.respond_to?(:contents_opacity) ? s.contents_opacity : nil] }
    if opts[:style] == "fade" && opts[:fade] > 0
      opts[:fade].times do |i|
        alpha = 1.0 - (i + 1).to_f / opts[:fade]
        initial.each do |s, opacity, contents|
          next if s.disposed?
          s.opacity = (opacity * alpha).round
          s.contents_opacity = (contents * alpha).round unless contents.nil?
        end
        update
      end
    end
    targets.each { |s| s.opacity = 0 unless s.disposed? }
    targets.each { |s| s.visible = false if !s.disposed? && s.respond_to?(:visible=) }
    @scene_persistent_sheets.clear
    opts[:breath].times { update }
  end

  def next_scene(key)
    @scene_next_key = key.to_s
    end_scene
  end

  def scene_common_event(id)
    id = id.to_i
    @scene_event_id = id if id > 0 && $data_common_events[id]
  end

  def scene_wait_confirm
    loop do
      update
      break if Input.trigger?(Input::USE) || Input.trigger?(Input::C) || Input.trigger?(Input::ACTION)
    end
  end

  def set_scene_textbox(skin = "")
    skin = skin.to_s
    return if @scene_textbox_skin == skin
    old = @sprites[:text_box]
    alpha = old && !old.disposed? ? old.opacity : 0
    if skin.empty?
      path = "#{SceneEngine::Settings::SCENES_DIR}/#{SceneEngine::Settings::TEXT_BOX_FILE}"
      next_box = Sprite.new(@viewport)
      begin
        next_box.bitmap = AnimatedBitmap.new(path).deanimate
      rescue
        next_box.bitmap = Bitmap.new(Graphics.width, SceneEngine::Settings::TEXT_BOX_H)
        next_box.bitmap.fill_rect(0, 0, Graphics.width, SceneEngine::Settings::TEXT_BOX_H, Color.new(20,20,30))
      end
      next_box.y = SceneEngine::Settings::TEXT_BOX_Y
    else
      return unless pbResolveBitmap(skin)
      next_box = SpriteWindow_Base.new(0, SceneEngine::Settings::TEXT_BOX_Y, Graphics.width, SceneEngine::Settings::TEXT_BOX_H)
      next_box.viewport = @viewport
      next_box.setSkin(skin)
      next_box.back_opacity = 255
    end
    next_box.z = SceneEngine::Settings::LAYER_TEXTBOX
    next_box.opacity = alpha
    old.dispose if old && !old.disposed?
    @sprites[:text_box] = next_box
    @scene_textbox_skin = skin
    scene_layout_textbox
  end

  def text_inline(text, speaker: nil, speed: :normal, format_args: nil, skin: nil, name_skin: nil, speaker_color: nil, speaker_shadow: nil)
    @scene_speaker_color = speaker_color
    @scene_speaker_shadow = speaker_shadow
    @scene_name_skin = name_skin
    set_scene_textbox(skin) unless skin.nil?
    scene_layout_textbox
    text = apply_format(text, format_args) if format_args
    show_page_text(text, speaker, speed)
  end

  # --- ASIGNACIÓN DE SPEAKER INDEPENDIENTE ---
  def scene_backdrop(hex, opacity, z)
    unless @sprites[:sds_backdrop] && !@sprites[:sds_backdrop].disposed?
      @sprites[:sds_backdrop] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    end
    sprite = @sprites[:sds_backdrop]
    sprite.bitmap.fill_rect(0,0,Graphics.width,Graphics.height,scene_hex_color(hex,Color.new(0,0,0)))
    sprite.opacity = [[opacity.to_i,0].max,255].min
    sprite.z = z.to_i
  end

  def scene_fx(id, target, graphics, pattern: "rise", color: "#DD445B", blend: "normal", count: 12, cycle: 30,
               range_x: 55, range_y: 100, scale: 1, sway: 1, opacity: 1, outline: 0, outline_color: "#DD445B",
               x: 320, y: 240, z: 450, life: 0)
    scene_fx_stop(id, fade: 0)
    paths = Array(graphics).reject { |path| path.to_s.empty? }
    bitmaps = paths.filter_map do |path|
      begin
        @scene_fx_bitmaps[path] ||= AnimatedBitmap.new(path).deanimate
      rescue
        nil
      end
    end
    return if bitmaps.empty?
    available = [128 - @scene_fx.values.sum { |fx| fx[:sprites].length }, 0].max
    count = [[count.to_i,1].max,48,available].min
    return if count <= 0
    tint = scene_hex_color(color,Color.new(255,255,255))
    sprites = Array.new(count) do
      sprite = Sprite.new(@viewport)
      sprite.bitmap = bitmaps.first
      sprite.blend_type = blend == "additive" ? 1 : 0
      sprite.color = Color.new(tint.red,tint.green,tint.blue,128)
      sprite.z = z.to_i
      sprite.opacity = 0
      sprite
    end
    @scene_fx[id] = {sprites: sprites, bitmaps: bitmaps, target: target, start: @scene_logic_frame || 0,
      pattern: pattern, count: count, cycle: [cycle.to_f,1].max, rx: range_x.to_f, ry: range_y.to_f,
      scale: [scale.to_f,0.01].max, sway: sway.to_f, opacity: [[opacity.to_f,0].max,1].min,
      x: x.to_f,y: y.to_f,life: life.to_i,alpha: 1.0}
    update_scene_fx
    if life.to_i > 0
      life.to_i.times do
        break unless @scene_fx.key?(id)
        update
      end
    end
  end

  def update_scene_fx
    now = @scene_logic_frame || 0
    @scene_fx.keys.each do |id|
      fx = @scene_fx[id]
      elapsed = [now-fx[:start],0].max
      if fx[:life] > 0 && elapsed >= fx[:life]
        fx[:sprites].each { |sprite| sprite.dispose unless sprite.disposed? }
        @scene_fx.delete(id)
        next
      end
      target = @image_sprites[fx[:target]]
      visible = fx[:target].to_s.empty? || (target && !target.disposed? && target.visible)
      cx,cy = fx[:x],fx[:y]
      if target && !target.disposed?
        cx = target.x + (target.src_rect.width/2.0-target.ox)*target.zoom_x
        cy = target.y + (target.src_rect.height/2.0-target.oy)*target.zoom_y
      end
      fx[:sprites].each_with_index do |sprite,i|
        sprite.visible = !!visible
        next unless visible
        phase = ((elapsed+i*fx[:cycle]/fx[:count])%fx[:cycle])/fx[:cycle]
        angle = i*2.399963229728653+phase*Math::PI*2
        rx,ry = fx[:rx],fx[:ry]
        dx,dy = case fx[:pattern]
        when "orbit" then [Math.cos(angle)*rx,Math.sin(angle)*ry*0.45]
        when "vortex" then [Math.cos(angle)*rx*(1-phase),ry*0.5-phase*ry]
        when "rain" then [Math.sin(i*2.399963)*rx,-ry+phase*ry*2]
        when "burst" then [Math.cos(i*2.399963)*rx*phase,Math.sin(i*2.399963)*ry*phase]
        when "halo" then [Math.cos(angle)*rx,-ry*0.5+Math.sin(angle)*ry*0.2]
        when "ground" then [Math.cos(angle)*rx,ry*0.4+Math.sin(angle)*ry*0.18]
        else [Math.sin(i*2.399963)*rx+Math.sin(angle)*rx*0.18*fx[:sway],ry*0.5-phase*ry]
        end
        bitmap = fx[:bitmaps][((elapsed+i*3)/6).floor%fx[:bitmaps].length]
        if sprite.bitmap != bitmap
          sprite.bitmap = bitmap
          sprite.src_rect.set(0,0,bitmap.width,bitmap.height)
        end
        sprite.ox,sprite.oy = bitmap.width/2,bitmap.height/2
        sprite.x,sprite.y = (cx+dx).round,(cy+dy).round
        sprite.zoom_x = sprite.zoom_y = fx[:scale]
        sprite.opacity = (255*Math.sin(phase*Math::PI)*fx[:opacity]*fx[:alpha]).round
      end
    end
  end

  def scene_fx_stop(id = "", fade: 0)
    keys = id.to_s.empty? ? @scene_fx.keys : [id]
    frames = [[fade.to_i,0].max,36000].min
    frames.times do |i|
      keys.each { |key| @scene_fx[key][:alpha] = 1-(i+1).to_f/frames if @scene_fx[key] }
      update
    end
    keys.each do |key|
      fx = @scene_fx.delete(key)
      fx[:sprites].each { |sprite| sprite.dispose unless sprite.disposed? } if fx
    end
  end

  def dispose_scene_fx
    scene_fx_stop("", fade: 0)
    @scene_fx_bitmaps.each_value { |bitmap| bitmap.dispose unless bitmap.disposed? }
    @scene_fx_bitmaps.clear
  end

  def scene_transform(id, filename, duration: 36, transition: "flash", columns: 1, rows: 1, fps: 8)
    sprite = @image_sprites[id]
    return if !sprite || sprite.disposed? || filename.to_s.empty?
    bitmap = AnimatedBitmap.new(filename).deanimate
    cols, row_count = [[columns.to_i,1].max,bitmap.width].min, [[rows.to_i,1].max,bitmap.height].min
    fw,fh = bitmap.width/cols,bitmap.height/row_count
    old_bitmap = sprite.bitmap
    old_alpha,old_zoom = sprite.opacity,sprite.zoom_x
    anchor_x = sprite.src_rect.width > 0 ? sprite.ox.to_f/sprite.src_rect.width : 0
    anchor_y = sprite.src_rect.height > 0 ? sprite.oy.to_f/sprite.src_rect.height : 0
    @scene_persistent_sheets.delete(id)
    @scene_transformed_images[id] = true
    # Transform owns this instance after the preceding clip has ended.
    frames = transition == "cut" ? 0 : [[duration.to_i,1].max,36000].min
    ghost = nil
    if transition == "crossfade"
      ghost = Sprite.new(@viewport)
      ghost.bitmap = old_bitmap
      ghost.src_rect.set(sprite.src_rect.x,sprite.src_rect.y,sprite.src_rect.width,sprite.src_rect.height)
      ghost.x,ghost.y,ghost.z,ghost.ox,ghost.oy = sprite.x,sprite.y,sprite.z,sprite.ox,sprite.oy
      ghost.zoom_x,ghost.zoom_y,ghost.angle,ghost.opacity = sprite.zoom_x,sprite.zoom_y,sprite.angle,old_alpha
    end
    swap = lambda do
      sprite.bitmap = bitmap
      sprite.src_rect.set(0,0,fw,fh)
      sprite.ox,sprite.oy = (fw*anchor_x).round,(fh*anchor_y).round
      @scene_image_files[id] = filename
    end
    if ghost
      swap.call
      sprite.opacity = 0
      frames.times { |i| p=(i+1).to_f/frames;ghost.opacity=(old_alpha*(1-p)).round;sprite.opacity=(old_alpha*p).round;update }
    else
      swapped = false
      frames.times do |i|
        p=(i+1).to_f/frames
        if p>=0.5 && !swapped
          swap.call
          swapped=true
        end
        strength = Math.sin(p*Math::PI)
        if transition == "flash"
          sprite.color = Color.new(255,255,255,(strength*255).round)
        elsif transition == "shrink"
          sprite.zoom_x = sprite.zoom_y = old_zoom*(1-0.85*strength)
        end
        update
      end
      swap.call unless swapped
    end
    sprite.opacity = old_alpha
    sprite.zoom_x = sprite.zoom_y = old_zoom
    sprite.color = Color.new(0,0,0,0)
    if cols*row_count > 1
      @scene_persistent_sheets[id] = {sprite: sprite,start: @scene_logic_frame || 0,cols: cols,fw: fw,fh: fh,first: 0,count: cols*row_count,fps: [[fps.to_f,1].max,60].min,mode: "loop"}
    end
  ensure
    ghost.dispose if ghost && !ghost.disposed?
  end

  def scene_skin_edges(window)
    return [16,16,16,16] unless window.skinformat == 1
    rect = window.skinrect
    bitmap = window.windowskin
    [rect.x, rect.y, bitmap.width-rect.x-rect.width, bitmap.height-rect.y-rect.height].map { |v| [v,0].max }
  end

  def scene_layout_textbox
    box = @sprites[:text_box]
    return unless box
    settings = SceneEngine::Settings
    if box.is_a?(SpriteWindow_Base)
      l,t,r,b = scene_skin_edges(box)
      x = l + 8
      separate = @scene_name_skin && !@scene_name_skin.empty?
      top = t + 6 + (separate ? 0 : 36)
      width = [1, Graphics.width-l-r-16].max
      height = [1, settings::TEXT_BOX_H-top-b-6].max
      y = settings::TEXT_BOX_Y+top
      @sprites[:indicator].x = Graphics.width-r-22
      @sprites[:indicator].y = settings::TEXT_BOX_Y+settings::TEXT_BOX_H-b-12
    else
      x = settings::TEXT_PAD_X
      y = settings::TEXT_BOX_Y+settings::TEXT_PAD_Y_TOP
      width = Graphics.width-x*2
      height = settings::TEXT_BOX_H-settings::TEXT_PAD_Y_TOP-settings::TEXT_PAD_Y_BOT
      @sprites[:indicator].x = Graphics.width-x-14
      @sprites[:indicator].y = settings::TEXT_BOX_Y+settings::TEXT_BOX_H-24
    end
    text = @sprites[:text]
    if text.bitmap.width != width || text.bitmap.height != height
      text.bitmap.dispose
      text.bitmap = Bitmap.new(width,height)
      pbSetSystemFont(text.bitmap)
    end
    text.x, text.y = x, y
  end

  def scene_hex_color(value, fallback)
    return fallback unless value.is_a?(String) && value.match?(/\A#[0-9a-f]{6}\z/i)
    Color.new(value[1,2].to_i(16),value[3,2].to_i(16),value[5,2].to_i(16))
  end

  def set_speaker(speaker)
    old = @sprites.delete(:name_box)
    old.dispose if old && !old.disposed?
    sp = @sprites[:speaker_text]
    bmp = sp.bitmap
    bmp.clear
    return if speaker.nil? || speaker.empty?
    settings = SceneEngine::Settings
    scolor, sshadow = speaker_colors(speaker)
    scolor = scene_hex_color(@scene_speaker_color,scolor)
    sshadow = scene_hex_color(@scene_speaker_shadow,sshadow)
    sp.x, sp.y = settings::TEXT_PAD_X, settings::TEXT_BOX_Y+8
    box = @sprites[:text_box]
    if @scene_name_skin && !@scene_name_skin.empty? && pbResolveBitmap(@scene_name_skin)
      name_box = SpriteWindow_Base.new(0,0,160,64)
      name_box.viewport = @viewport
      name_box.setSkin(@scene_name_skin)
      l,t,r,b = scene_skin_edges(name_box)
      name_box.width = [[bmp.text_size(speaker).width+l+r+20, l+r+40].max,Graphics.width-16].min
      name_box.height = t+b+38
      name_box.x = 8
      name_box.y = [0,settings::TEXT_BOX_Y-name_box.height].max
      name_box.z = settings::LAYER_TEXTBOX+1
      name_box.back_opacity = 255
      name_box.opacity = box.opacity
      @sprites[:name_box] = name_box
      sp.x = name_box.x+l+8
      sp.y = name_box.y+t+1
    elsif box.is_a?(SpriteWindow_Base)
      l,t,_,_ = scene_skin_edges(box)
      sp.x, sp.y = l+8, settings::TEXT_BOX_Y+t+2
    end
    pbDrawShadowText(bmp, 0, 4, bmp.width, 32, speaker, scolor, sshadow, 0)
  end

  def scene_resolve_text(text)
    trainer = defined?($player) && $player ? $player : (defined?($Trainer) ? $Trainer : nil)
    name = trainer && trainer.respond_to?(:name) ? trainer.name.to_s : ""
    text.to_s.gsub(/\\PN/i) { name }
  end

  def show_page_text(text, speaker, speed)
    text = scene_resolve_text(text)
    speaker = scene_resolve_text(speaker) unless speaker.nil?
    cpf = speed_to_chars(speed).to_f
    bmp = @sprites[:text].bitmap
    max_lines = [[bmp.height / SceneEngine::Settings::TEXT_LINE_H,1].max,SceneEngine::Settings::TEXT_MAX_LINES].min

    set_speaker(speaker)
    bmp.clear 
    show_textbox(10) # Fade in suave

    all_lines = word_wrap_all(text, bmp.width)
    pages = paginate_scene_lines(all_lines, max_lines)
    total_pages = pages.length
    page = 0

    loop do
      page_lines = pages[page]
      page_text = page_lines.join("\n")
      page_len = page_text.length
      revealed = 0.0

      ellipsis_pos = []
      ellipsis_ends = []
      i = 0
      while i < page_len
        if page_text[i, 3] == "..."
          ellipsis_pos.concat([i, i + 1, i + 2])
          ellipsis_ends << i + 3
          i += 3
        else
          i += 1
        end
      end
      suspense_remaining = 0

      loop do
        update
        input = Input.trigger?(Input::USE) || Input.trigger?(Input::C) || Input.trigger?(Input::ACTION)

        if revealed < page_len
          if suspense_remaining > 0
            suspense_remaining -= 1
          else
            before = revealed
            effective_cpf = cpf
            effective_cpf *= 0.1 if ellipsis_pos.include?(revealed.floor)
            revealed = [revealed + effective_cpf, page_len.to_f].min
            if ellipsis_ends.any? { |ending| before < ending && revealed >= ending }
              suspense_remaining = SceneEngine::Settings::ELLIPSIS_HOLD_FRAMES
            end
            redraw_text(page_lines, revealed.floor)
          end
        end

        if revealed >= page_len
          @sprites[:indicator].opacity = (@sprites[:text_box].opacity > 0 && @scene_logic_frame % 40 < 20) ? @sprites[:text_box].opacity : 0
        else
          @sprites[:indicator].opacity = 0
        end

        if input
          if revealed < page_len
            revealed = page_len.to_f
            redraw_text(page_lines, page_len)
          else
            @sprites[:indicator].opacity = 0
            break
          end
        end
      end

      page += 1
      break if page >= total_pages
    end
  end

  def show_centered_text(text, speed: :normal, color: Color.new(0, 0, 0))
    text = scene_resolve_text(text)
    hide_centered_text
    bmp = Bitmap.new(Graphics.width, Graphics.height)
    pbSetSystemFont(bmp)
    sprite = Sprite.new(@viewport)
    sprite.bitmap = bmp
    sprite.z = SceneEngine::Settings::LAYER_OVERLAY + 10
    @sprites[:centered_text] = sprite

    cpf = speed_to_chars(speed).to_f
    revealed = 0.0
    page_len = text.length
    ellipsis_pos = []
    ellipsis_ends = []
    i = 0
    while i < page_len
      if text[i, 3] == "..."
        ellipsis_pos.concat([i, i + 1, i + 2])
        ellipsis_ends << i + 3
        i += 3
      else
        i += 1
      end
    end
    suspense_remaining = 0

    loop do
      update
      input = Input.trigger?(Input::USE) || Input.trigger?(Input::C) || Input.trigger?(Input::ACTION)
      if input
        revealed = page_len.to_f
        suspense_remaining = 0
      end

      if suspense_remaining > 0
        suspense_remaining -= 1
      elsif revealed < page_len
        before = revealed
        effective_cpf = ellipsis_pos.include?(revealed.floor) ? cpf * 0.4 : cpf
        revealed = [revealed + effective_cpf, page_len.to_f].min
        if ellipsis_ends.any? { |ending| before < ending && revealed >= ending }
          suspense_remaining = SceneEngine::Settings::ELLIPSIS_HOLD_FRAMES
        end
      else
        bmp.clear
        pbDrawTextPositions(bmp, [[text, Graphics.width / 2, Graphics.height / 2 - 16, 2, color, Color.new(255, 255, 255, 0)]])
        break
      end

      bmp.clear
      current_text = text[0...revealed.floor]
      pbDrawTextPositions(bmp, [[current_text, Graphics.width / 2, Graphics.height / 2 - 16, 2, color, Color.new(255, 255, 255, 0)]])
    end
  end

  def hide_centered_text
    @sprites[:centered_text]&.dispose
    @sprites[:centered_text] = nil
  end

  def transfer_player(map_id, x, y, direction = 2)
    pbTransferPlayer(map_id, x, y, direction)
  end

  def name_input(default: "Solen", min: 1, max: 12)
    old_z = @viewport.z
    @viewport.z = 1000 
    name = pbEnterPlayerName(_INTL("Ingresa tu nombre"), min, max, default, false)
    @viewport.z = old_z
    
    if $player
      $player.name = name
    elsif $Trainer
      $Trainer.name = name
    end
    
    name
  end

  def speed_to_chars(speed)
    case speed
    when :crawl then SceneEngine::Settings::SPEED_CRAWL
    when :very_slow then SceneEngine::Settings::SPEED_VERY_SLOW
    when :slow then SceneEngine::Settings::SPEED_SLOW
    when :fast then SceneEngine::Settings::SPEED_FAST
    when :instant then SceneEngine::Settings::SPEED_INSTANT
    else SceneEngine::Settings::SPEED_NORMAL
    end
  end

  def speaker_colors(name)
    map = SceneEngine::Settings::SPEAKER_COLOR_MAP
    return map[name] if map&.key?(name)
    [SceneEngine::Settings::SPEAKER_COLOR, SceneEngine::Settings::SPEAKER_SHADOW]
  end

  # Ya NO dibuja el speaker, se encarga exclusivamente del diálogo
  def redraw_text(lines, revealed_chars)
    bmp = @sprites[:text].bitmap
    bmp.clear
    tw = bmp.width
    lh = SceneEngine::Settings::TEXT_LINE_H
    c = SceneEngine::Settings::TEXT_COLOR
    sc = SceneEngine::Settings::TEXT_SHADOW

    drawn = 0

    lines.each_with_index do |line, i|
      break if drawn >= revealed_chars
      
      to_draw = revealed_chars - drawn
      if to_draw >= line.length
        pbDrawShadowText(bmp, 0, i * lh, tw, lh, line, c, sc, 0)
        drawn += line.length + 1 
      else
        pbDrawShadowText(bmp, 0, i * lh, tw, lh, line[0...to_draw], c, sc, 0)
        drawn += to_draw
      end
    end
  end

  def word_wrap_all(text, max_width)
    bmp = @sprites[:text].bitmap
    lines = []
    safe_width = max_width - 12 
    # Respeta los saltos manuales cuando una escena los necesita.
    # La intro elimina los saltos forzados redundantes.
    text.to_s.split("\n").each do |para|
      words = para.split(' ')
      current = ""
      words.each do |word|
        test = current.empty? ? word : current + ' ' + word
        if bmp.text_size(test).width > safe_width && !current.empty?
          lines << current
          current = word
        else
          current = test
        end
      end
      lines << current unless current.empty?
    end
    # Evitar la típica última línea con una palabra como "todo.".
    if lines.length > 1 && lines[-1].split(" ").length < 3
      tail = lines[-1].split(" ")
      prev = lines[-2].split(" ")
      while tail.length < 4 && prev.length > 2
        candidate = ([prev[-1]] + tail).join(" ")
        break if bmp.text_size(candidate).width > safe_width
        tail.unshift(prev.pop)
      end
      lines[-2] = prev.join(" ")
      lines[-1] = tail.join(" ")
    end
    lines
  end

  # Equilibra las páginas, evitando que un solo renglón quede aislado.
  def paginate_scene_lines(lines, max_lines)
    max_lines = [max_lines.to_i, 1].max
    pages = lines.each_slice(max_lines).to_a
    pages = [[""]] if pages.empty?
    if pages.length > 1 && pages[-1].length == 1 && pages[-2].length > 2
      pages[-1].unshift(pages[-2].pop)
    end
    pages
  end

  def apply_format(text, args)
    args.each_with_index { |arg, i| text = text.gsub("{#{i + 1}}", arg.to_s) }
    text
  end

  def float_sprite(filename, fw, fh, frames, x, y, end_y:, speed: 1, fps: 6, ghost_interval: 1, bg: false, glow: false, fade: SceneEngine::Settings::FADE_DEFAULT)
    stop_float
    if bg
      @sprites[:float_bg] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @sprites[:float_bg].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
      @sprites[:float_bg].z = SceneEngine::Settings::LAYER_IMG + 150
      @sprites[:float_bg].opacity = 0
    end
    bmp = AnimatedBitmap.new(filename).deanimate
    sprite = Sprite.new(@viewport)
    sprite.bitmap = bmp
    sprite.src_rect.set(0, 0, fw, fh)
    sprite.x = x
    sprite.y = y
    sprite.z = SceneEngine::Settings::LAYER_IMG + 200
    sprite.opacity = 0
    glow_sprite = nil
    if glow
      glow_sprite = Sprite.new(@viewport)
      glow_sprite.bitmap = bmp
      glow_sprite.src_rect.set(0, 0, fw, fh)
      glow_sprite.x = x
      glow_sprite.y = y
      glow_sprite.z = SceneEngine::Settings::LAYER_IMG + 201
      glow_sprite.blend_type = 1
      glow_sprite.tone = Tone.new(255, 255, 255, 0)
      glow_sprite.opacity = 0
    end
    fade.times do |i|
      sprite.opacity = 255 * (i + 1) / fade
      @sprites[:float_bg].opacity = sprite.opacity if @sprites[:float_bg]
      update
    end
    sprite.opacity = 255
    glow_sprite.opacity = 255 if glow_sprite
    @float_anim = {
      bitmap: bmp, sprite: sprite, glow: glow_sprite, fw: fw, fh: fh,
      frames: frames, frame: 0, counter: 0,
      fps: fps, x: x, y: y, end_y: end_y, speed: speed, bob: 0,
      start_y: y, glow_type: glow, ghost_interval: ghost_interval
    }
  end

  def stop_float(fade: 0)
    if fade > 0 && @float_anim
      sp = @float_anim[:sprite]
      gl = @float_anim[:glow]
      fade.times do |i|
        sp.opacity = 255 - (255 * (i + 1) / fade)
        gl.opacity = sp.opacity if gl
        @float_ghosts.each { |g| g.opacity -= 2 }
        update
      end
    end
    @float_ghosts.each { |g| g.dispose rescue nil }
    @float_ghosts.clear
    if @float_anim
      @float_anim[:sprite]&.dispose rescue nil
      @float_anim[:glow]&.dispose rescue nil
      @float_anim[:bitmap]&.dispose rescue nil
      @float_anim = nil
    end
    @sprites[:float_bg]&.dispose rescue nil
    @sprites[:float_bg] = nil
  end

  def start_aura(filename, fw, fh, count: 8, range_x: 30, range_y: 60, duration: 120)
    stop_aura
    bmp = AnimatedBitmap.new(filename).deanimate
    count.times do
      p = {
        sprite: Sprite.new(@viewport),
        x_off: (rand - 0.5) * range_x * 2,
        speed: 0.6 + rand * 0.8,
        phase: rand * duration,
        duration: duration,
        range_y: range_y,
        fw: fw, fh: fh
      }
      p[:sprite].bitmap = bmp
      p[:sprite].src_rect.width = fw
      p[:sprite].src_rect.height = fh
      p[:sprite].z = SceneEngine::Settings::LAYER_IMG + 250
      @aura_particles << p
    end
  end

  def update_aura_particles
    return if @aura_particles.empty?
    cx = @float_anim ? @float_anim[:sprite].x + @float_anim[:fw] / 2 : 0
    cy = @float_anim ? @float_anim[:sprite].y + @float_anim[:fh] / 2 : 0
    @aura_particles.each do |p|
      p[:phase] = (p[:phase] + p[:speed]) % p[:duration]
      progress = p[:phase] / p[:duration]
      p[:sprite].opacity = (Math.sin(progress * Math::PI) * 255).round
      start_y = cy + p[:fh] / 2 + p[:range_y]
      py = start_y - progress * (p[:range_y] * 2 + p[:fh])
      px = cx + p[:x_off] - p[:fw] / 2
      p[:sprite].x = px.round
      p[:sprite].y = py.round
    end
  end

  def stop_aura
    @aura_particles.each { |p| p[:sprite]&.dispose rescue nil }
    @aura_particles.clear
  end

  def change_float_bitmap(filename)
    return unless @float_anim
    bmp = AnimatedBitmap.new(filename).deanimate
    @float_anim[:bitmap]&.dispose
    @float_anim[:bitmap] = bmp
    @float_anim[:sprite].bitmap = bmp
    frame_x = @float_anim[:frame] * @float_anim[:fw]
    @float_anim[:sprite].src_rect.set(frame_x, 0, @float_anim[:fw], @float_anim[:fh])
    if @float_anim[:glow]
      @float_anim[:glow].bitmap = bmp
      @float_anim[:glow].src_rect.set(frame_x, 0, @float_anim[:fw], @float_anim[:fh])
    end
  end

  def start_scrolling(filename, x, y, speed:, z: nil, mirror: false, horizontal: false)
    bmp = AnimatedBitmap.new(filename).deanimate
    zh = z || SceneEngine::Settings::LAYER_IMG + 50
    if horizontal
      # Encuadra la textura en un canvas del alto de pantalla para que el tile
      # vertical del Plane caiga fuera de la vista (no se duplica arriba)
      canvas = Bitmap.new(bmp.width, Graphics.height)
      canvas.blt(0, y, bmp, Rect.new(0, 0, bmp.width, bmp.height))
      bmp.dispose
      bmp = canvas
      plane = Plane.new(@viewport)
      plane.bitmap = bmp
      plane.oy = 0
      plane.z = zh
      @scrolling_sprites << { type: :plane, sprites: [plane], bitmap: bmp, speed: speed, size: bmp.width, horizontal: true }
      return
    end
    sprites = []
    s1 = Sprite.new(@viewport)
    s1.bitmap = bmp
    s1.src_rect.set(0, 0, bmp.width, bmp.height)
    s1.x = x
    s1.y = y
    s1.z = zh
    s1.mirror = mirror
    sprites << s1
    s2 = Sprite.new(@viewport)
    s2.bitmap = bmp
    s2.src_rect.set(0, 0, bmp.width, bmp.height)
    s2.x = x
    s2.y = y - bmp.height
    s2.z = zh
    s2.mirror = mirror
    sprites << s2
    @scrolling_sprites << { sprites: sprites, bitmap: bmp, speed: speed, size: bmp.height }
  end

  def stop_scrolling
    @scrolling_sprites.each do |s|
      s[:sprites].each { |sp| sp.dispose rescue nil }
      s[:bitmap]&.dispose rescue nil
    end
    @scrolling_sprites.clear
  end

  def update_scrolling
    @scrolling_sprites.each do |s|
      s[:sprites].each do |sp|
        if s[:type] == :plane
          sp.ox -= s[:speed]
        else
          sp.y -= s[:speed]
          sp.y += s[:size] * 2 if sp.y + s[:size] <= 0
        end
      end
    end
  end

  def show_floating(filename, x, y, amplitude: 8, speed: 0.05, z: nil, zoom: 1, opacity: 255, fade: 0)
    bmp = AnimatedBitmap.new(filename).deanimate
    s = Sprite.new(@viewport)
    s.bitmap = bmp
    s.x = x
    s.y = y
    s.z = z || SceneEngine::Settings::LAYER_IMG + 60
    s.zoom_x = zoom
    s.zoom_y = zoom
    s.opacity = 0
    f = { sprite: s, base_x: x, base_y: y, amp: amplitude, speed: speed, counter: 0 }
    @floating_sprites << f
    if fade > 0
      fade.times { |i| s.opacity = (opacity * (i + 1) / fade).round; update }
    end
    s.opacity = opacity
    f
  end

  def update_floating
    @floating_sprites.each do |f|
      f[:counter] += 1
      f[:sprite].y = f[:base_y] + Math.sin(f[:counter] * f[:speed]) * f[:amp]
    end
  end

  def hide_floating
    @floating_sprites.each { |f| f[:sprite]&.dispose rescue nil }
    @floating_sprites.clear
  end
  alias stop_floating hide_floating

  def fade_out_images(dur, filenames = nil)
    targets = filenames ? filenames.map(&:to_s) : @image_sprites.keys
    dur = 1 if dur < 1
    dur.times do |i|
      progress = (i + 1) / dur.to_f
      targets.each { |k| @image_sprites[k].opacity = (255 * (1 - progress)).round if @image_sprites[k] }
      update
    end
  end

  def fade_out_floating(dur)
    return if @floating_sprites.empty?
    dur = 1 if dur < 1
    dur.times do |i|
      progress = (i + 1) / dur.to_f
      @floating_sprites.each { |f| f[:sprite].opacity = (255 * (1 - progress)).round }
      update
    end
  end

  def fade_out_scrolling(dur)
    return if @scrolling_sprites.empty?
    dur = 1 if dur < 1
    dur.times do |i|
      progress = (i + 1) / dur.to_f
      @scrolling_sprites.each { |s| s[:sprites].each { |sp| sp.opacity = (255 * (1 - progress)).round } }
      update
    end
  end

  def fade_in_scrolling(dur)
    return if @scrolling_sprites.empty?
    dur = 1 if dur < 1
    dur.times do |i|
      progress = (i + 1) / dur.to_f
      @scrolling_sprites.each { |s| s[:sprites].each { |sp| sp.opacity = (255 * progress).round } }
      update
    end
  end

  def fade_out_sprites(sprites, dur)
    return if sprites.empty?
    dur = 1 if dur < 1
    dur.times do |i|
      progress = (i + 1) / dur.to_f
      sprites.each { |sp| sp.opacity = (255 * (1 - progress)).round if sp && !sp.disposed? }
      update
    end
  end
end