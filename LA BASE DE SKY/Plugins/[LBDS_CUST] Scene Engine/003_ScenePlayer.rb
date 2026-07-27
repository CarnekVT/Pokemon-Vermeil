# encoding: utf-8
class SceneEngine::Player
  def initialize(scene_name)
    @scene_name = scene_name
    @dialog_data = SceneEngine.load_dialog(scene_name)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99_999
    @image_sprites = {}
    @sprites = {}
  end

  def run(&block)
    setup_sprites
    instance_eval(&block) if block
  ensure
    cleanup
  end

  private

  def setup_sprites
    @sprites[:black] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites[:black].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    @sprites[:black].z = Settings::LAYER_OVERLAY
    @sprites[:black].opacity = 255

    @sprites[:white] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites[:white].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(255, 255, 255))
    @sprites[:white].z = Settings::LAYER_OVERLAY + 1
    @sprites[:white].opacity = 0

    @sprites[:text_box] = Sprite.new(@viewport)
    path = "#{Settings::SCENES_DIR}/#{Settings::TEXT_BOX_FILE}"
    @sprites[:text_box].bitmap = Bitmap.new(path) if File.exist?(path + ".png")
    @sprites[:text_box].y = Settings::TEXT_BOX_Y
    @sprites[:text_box].z = Settings::LAYER_TEXTBOX
    @sprites[:text_box].opacity = 0

    tw = Graphics.width - Settings::TEXT_PAD_X * 2
    th = Settings::TEXT_BOX_H - Settings::TEXT_PAD_Y_TOP - Settings::TEXT_PAD_Y_BOT
    @sprites[:text] = BitmapSprite.new(tw, th, @viewport)
    @sprites[:text].x = Settings::TEXT_PAD_X
    @sprites[:text].y = Settings::TEXT_BOX_Y + Settings::TEXT_PAD_Y_TOP
    @sprites[:text].z = Settings::LAYER_TEXT
    @sprites[:text].opacity = 0
    pbSetSystemFont(@sprites[:text].bitmap)
  end

  def cleanup
    @image_sprites.each_value { |s| s&.dispose unless s.disposed? }
    @sprites.each_value { |s| s&.dispose unless s.disposed? }
    @viewport.dispose
  rescue; end

  def update
    Graphics.update
    Input.update
  end

  # ── Audio ───────────────────────────────────────────────

  def bgm(name)
    name.nil? || name.empty? ? pbBGMStop : pbBGMPlay(name)
  end

  def bgs(name)
    name.nil? || name.empty? ? pbBGSStop : pbBGSPlay(name)
  end

  def se(name)
    pbSEPlay(name) if name
  end

  def stop_bgm
    pbBGMStop
  end

  def stop_bgs
    pbBGSStop
  end

  # ── Screen control ──────────────────────────────────────

  def fade_from_black(dur = Settings::FADE_DEFAULT)
    dur = 1 if dur < 1
    black = @sprites[:black]
    black.opacity = 255
    dur.times do |i|
      black.opacity = 255 - (255 * (i + 1) / dur)
      update
    end
    black.opacity = 0
  end

  def fade_to_black(dur = Settings::FADE_DEFAULT)
    dur = 1 if dur < 1
    black = @sprites[:black]
    black.opacity = 0
    dur.times do |i|
      black.opacity = 255 * (i + 1) / dur
      update
    end
    black.opacity = 255
  end

  def fade_in(dur = Settings::FADE_DEFAULT)
    fade_from_black(dur)
  end

  def fade_out(dur = Settings::FADE_DEFAULT)
    fade_to_black(dur)
  end

  def to_white(dur = Settings::FADE_DEFAULT)
    dur = 1 if dur < 1
    white = @sprites[:white]
    white.opacity = 0
    dur.times do |i|
      white.opacity = 255 * (i + 1) / dur
      update
    end
    white.opacity = 255
  end

  def from_white(dur = Settings::FADE_DEFAULT)
    dur = 1 if dur < 1
    white = @sprites[:white]
    white.opacity = 255
    dur.times do |i|
      white.opacity = 255 - (255 * (i + 1) / dur)
      update
    end
    white.opacity = 0
  end

  def flash(color, dur = 15)
    spr = color.to_s == "white" ? @sprites[:white] : @sprites[:black]
    orig = spr.opacity
    spr.opacity = 255
    dur.times do |i|
      spr.opacity = 255 - (255 * (i + 1) / dur)
      update
    end
    spr.opacity = orig
  end

  # ── Image control ───────────────────────────────────────

  def show(filename, x = 0, y = 0, fade: Settings::FADE_DEFAULT, origin: :top_left)
    key = filename.to_s
    @image_sprites[key]&.dispose

    s = Sprite.new(@viewport)
    begin
      s.bitmap = Bitmap.new("#{Settings::SCENES_DIR}/#{@scene_name}/#{filename}")
    rescue
      s.dispose
      return
    end

    case origin
    when :center
      x -= s.bitmap.width / 2
      y -= s.bitmap.height / 2
    when :bottom
      x -= s.bitmap.width / 2
      y -= s.bitmap.height
    end

    s.x = x
    s.y = y
    s.z = Settings::LAYER_IMG + @image_sprites.size
    s.opacity = 0
    s.visible = true
    @image_sprites[key] = s

    return if fade < 1
    fade.times do |i|
      s.opacity = 255 * (i + 1) / fade
      update
    end
    s.opacity = 255
  end

  def hide(filename = nil, fade: 0)
    targets = filename ? [filename.to_s] : @image_sprites.keys
    targets.each do |k|
      s = @image_sprites[k]
      next unless s
      if fade > 0
        fade.times do |i|
          s.opacity = 255 - (255 * (i + 1) / fade)
          update
        end
      end
      s.visible = false
    end
  end

  def hide_all(fade: 0)
    hide(nil, fade: fade)
  end

  def wait(frames)
    frames.times { update }
  end

  # ── Dialogue ─────────────────────────────────────────────

  def dialog(label, speed: nil, format_args: nil)
    entry = @dialog_data[label.to_sym]
    return unless entry

    text = entry[:text]
    text = apply_format(text, format_args) if format_args
    speaker = entry[:speaker]
    cpf = speed_to_chars(speed || entry[:speed] || :normal)

    @sprites[:text_box].opacity = 255
    @sprites[:text].opacity = 255

    visible = 0
    total = text.length

    loop do
      update

      input_advance = Input.trigger?(Input::USE) || Input.trigger?(Input::C) || Input.trigger?(Input::ACTION)

      if visible < total
        visible += cpf
        visible = total if visible > total
        redraw_text(text[0...visible], speaker)
      end

      if input_advance
        if visible < total
          visible = total
          redraw_text(text, speaker)
        else
          break
        end
      end
    end

    @sprites[:text_box].opacity = 0
    @sprites[:text].opacity = 0
  end

  def text_inline(text, speaker: nil, speed: :normal, format_args: nil)
    text = apply_format(text, format_args) if format_args
    cpf = speed_to_chars(speed)

    @sprites[:text_box].opacity = 255
    @sprites[:text].opacity = 255

    visible = 0
    total = text.length

    loop do
      update

      input_advance = Input.trigger?(Input::USE) || Input.trigger?(Input::C) || Input.trigger?(Input::ACTION)

      if visible < total
        visible += cpf
        visible = total if visible > total
        redraw_text(text[0...visible], speaker)
      end

      if input_advance
        if visible < total
          visible = total
          redraw_text(text, speaker)
        else
          break
        end
      end
    end

    @sprites[:text_box].opacity = 0
    @sprites[:text].opacity = 0
  end

  # ── Name input ───────────────────────────────────────────

  def name_input(default: "Solen", min: 1, max: 12)
    @viewport.visible = false
    name = pbEnterPlayerName(_INTL("Ingresa tu nombre"), min, max, default, false)
    @viewport.visible = true
    name
  end

  # ── Helpers ──────────────────────────────────────────────

  def speed_to_chars(speed)
    case speed
    when :slow then Settings::SPEED_SLOW
    when :fast then Settings::SPEED_FAST
    when :instant then Settings::SPEED_INSTANT
    else Settings::SPEED_NORMAL
    end
  end

  def redraw_text(text, speaker)
    bmp = @sprites[:text].bitmap
    bmp.clear
    tw = bmp.width
    c = Settings::TEXT_COLOR
    sc = Settings::TEXT_SHADOW
    lh = Settings::TEXT_LINE_H
    max_lines = Settings::TEXT_MAX_LINES

    if speaker
      scolor = Settings::SPEAKER_COLOR
      sshadow = Settings::SPEAKER_SHADOW
      pbDrawShadowText(bmp, 0, 0, tw, lh, speaker, scolor, sshadow, 0)
    end

    lines = word_wrap(text, tw, max_lines)
    y0 = speaker ? lh + 4 : 0
    lines.each_with_index do |line, i|
      pbDrawShadowText(bmp, 0, y0 + i * lh, tw, lh, line, c, sc, 0)
    end
  end

  def word_wrap(text, max_width, max_lines)
    bmp = @sprites[:text].bitmap
    lines = []
    paragraphs = text.split("\n")
    paragraphs.each do |para|
      current = ""
      para.each_char do |ch|
        test = current + ch
        if bmp.text_size(test).width > max_width && !current.empty?
          lines << current
          current = ch
        else
          current = test
        end
        return lines if lines.size >= max_lines
      end
      lines << current unless current.empty?
      return lines if lines.size >= max_lines
    end
    lines
  end

  def apply_format(text, args)
    args.each_with_index { |arg, i| text = text.gsub("{#{i + 1}}", arg.to_s) }
    text
  end
end
