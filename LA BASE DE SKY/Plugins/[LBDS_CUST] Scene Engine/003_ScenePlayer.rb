# encoding: utf-8
class SceneEngine::Player
  def initialize(dialogue_data: nil)
    @dialog_data = dialogue_data || {}
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
    @sprites[:black].z = SceneEngine::Settings::LAYER_OVERLAY
    @sprites[:black].opacity = 255

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
    @image_sprites.each_value { |s| s&.dispose rescue nil }
    @sprites.each_value { |s| s&.dispose rescue nil }
    @viewport.dispose
  rescue; end

  def update
    Graphics.update
    Input.update
  end

  def bgm(name); name.nil? || name.empty? ? pbBGMStop : pbBGMPlay(name); end
  def bgs(name); name.nil? || name.empty? ? pbBGSStop : pbBGSPlay(name); end
  def se(name); pbSEPlay(name) if name; end
  def stop_bgm(fade_secs = 0); fade_secs > 0 ? pbBGMFade(fade_secs) : pbBGMStop; end
  def stop_bgs; pbBGSStop; end

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
  def show_textbox(fade_frames = 10)
    return if @sprites[:text_box].opacity >= 255
    fade_frames = 1 if fade_frames < 1
    fade_frames.times do |i|
      alpha = 255 * (i + 1) / fade_frames
      @sprites[:text_box].opacity = alpha
      @sprites[:text].opacity = alpha
      @sprites[:speaker_text].opacity = alpha
      update
    end
  end

  def hide_textbox(fade_frames = 10)
    return if @sprites[:text_box].opacity <= 0
    fade_frames = 1 if fade_frames < 1
    @sprites[:indicator].opacity = 0
    fade_frames.times do |i|
      alpha = 255 - (255 * (i + 1) / fade_frames)
      @sprites[:text_box].opacity = alpha
      @sprites[:text].opacity = alpha
      @sprites[:speaker_text].opacity = alpha
      update
    end
  end

  def show(filename, x = 0, y = 0, fade: SceneEngine::Settings::FADE_DEFAULT, origin: :top_left)
    key = filename.to_s
    @image_sprites[key]&.dispose

    s = Sprite.new(@viewport)
    begin
      s.bitmap = AnimatedBitmap.new(filename).deanimate
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
    s.z = SceneEngine::Settings::LAYER_IMG + @image_sprites.size
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

  def hide(filename = nil, fade: 0)
    targets = filename ? [filename.to_s] : @image_sprites.keys
    targets.each do |k|
      s = @image_sprites[k]
      next unless s
      if fade > 0
        fade.times { |i| s.opacity = 255 - (255 * (i + 1) / fade); update }
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

  def text_inline(text, speaker: nil, speed: :normal, format_args: nil)
    text = apply_format(text, format_args) if format_args
    show_page_text(text, speaker, speed)
  end

  # --- ASIGNACIÓN DE SPEAKER INDEPENDIENTE ---
  def set_speaker(speaker)
    bmp = @sprites[:speaker_text].bitmap
    bmp.clear
    return unless speaker
    scolor, sshadow = speaker_colors(speaker)
    # Dibujado con margen Y=4 para que las letras no se rebanen por arriba
    pbDrawShadowText(bmp, 0, 4, bmp.width, 32, speaker, scolor, sshadow, 0)
  end

  def show_page_text(text, speaker, speed)
    cpf = speed_to_chars(speed).to_f
    max_lines = SceneEngine::Settings::TEXT_MAX_LINES
    bmp = @sprites[:text].bitmap

    set_speaker(speaker)
    bmp.clear 
    show_textbox(10) # Fade in suave

    all_lines = word_wrap_all(text, bmp.width)
    total_pages = (all_lines.length.to_f / max_lines).ceil
    total_pages = 1 if total_pages < 1
    page = 0

    loop do
      page_lines = all_lines[page * max_lines, max_lines]
      page_text = page_lines.join("\n")
      page_len = page_text.length
      revealed = 0.0

      ellipsis_pos = []
      i = 0
      while i < page_len
        if page_text[i, 3] == "..."
          ellipsis_pos.concat([i, i + 1, i + 2])
          i += 3
        else
          i += 1
        end
      end

      loop do
        update
        input = Input.trigger?(Input::USE) || Input.trigger?(Input::C) || Input.trigger?(Input::ACTION)

        if revealed < page_len
          effective_cpf = cpf
          if ellipsis_pos.include?(revealed.floor)
            effective_cpf *= 0.1
          end
          revealed += effective_cpf
          revealed = page_len.to_f if revealed > page_len
          redraw_text(page_lines, revealed.floor)
        end

        if revealed >= page_len
          @sprites[:indicator].opacity = (Graphics.frame_count % 40 < 20) ? 255 : 0
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

    loop do
      update
      
      input = Input.trigger?(Input::USE) || Input.trigger?(Input::C) || Input.trigger?(Input::ACTION)
      if input
        revealed = page_len.to_f
      end

      if revealed < page_len
        revealed += cpf
        revealed = page_len.to_f if revealed > page_len
        bmp.clear
        current_text = text[0...revealed.floor]
        pbDrawTextPositions(bmp, [[current_text, Graphics.width / 2, Graphics.height / 2 - 16, 2, color, Color.new(255, 255, 255, 0)]])
      else
        bmp.clear
        pbDrawTextPositions(bmp, [[text, Graphics.width / 2, Graphics.height / 2 - 16, 2, color, Color.new(255, 255, 255, 0)]])
        break
      end
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
    text.split("\n").each do |para|
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
    lines
  end

  def apply_format(text, args)
    args.each_with_index { |arg, i| text = text.gsub("{#{i + 1}}", arg.to_s) }
    text
  end
end