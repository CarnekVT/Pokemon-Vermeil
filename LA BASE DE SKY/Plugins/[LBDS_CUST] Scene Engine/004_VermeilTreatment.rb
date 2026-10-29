# encoding: utf-8
# Pokémon Vermeil: tratamiento gramatical y selector visual de Solen.
# El tratamiento es independiente del personaje gráfico y del trainer_type.
module VermeilTreatment
  OPTIONS = [:femenino, :neutro, :masculino].freeze
  LABELS  = {
    femenino: "FEMENINO",
    neutro: "NEUTRO",
    masculino: "MASCULINO"
  }.freeze
  ASSET_DIR = "Graphics/Scenes/Intro/GenderSelect"
  UI_DIR = "Graphics/Scenes/Intro/UI"
  # Ajuste artístico por pose: el brazo extendido no define el eje del torso.
  PORTRAIT_X_OFFSET = { femenino: 0, neutro: -21, masculino: 30 }.freeze

  def self.normalize(value)
    key = value.to_s.downcase.to_sym
    OPTIONS.include?(key) ? key : :neutro
  end

  def self.current
    player = $player || (defined?($Trainer) && $Trainer)
    return :neutro if !player || !player.respond_to?(:vermeil_treatment)
    normalize(player.vermeil_treatment)
  end

  def self.set(value)
    value = normalize(value)
    player = $player || (defined?($Trainer) && $Trainer)
    player.vermeil_treatment = value if player && player.respond_to?(:vermeil_treatment=)
    value
  end

  def self.text(masculino:, femenino:, neutro:)
    { masculino: masculino, femenino: femenino, neutro: neutro }[current]
  end
end

# La variable de instancia forma parte del Player guardado por Essentials.
class Player
  attr_accessor :vermeil_treatment
end

class SceneEngine::Player
  # Selector interactivo 640 x 480 (escalable con Graphics.width/height).
  # PNG independientes, mitad de cuerpo:
  # Graphics/Scenes/Intro/GenderSelect/solen_femenino.png
  # Graphics/Scenes/Intro/GenderSelect/solen_neutro.png
  # Graphics/Scenes/Intro/GenderSelect/solen_masculino.png
  def treatment_input(default: :neutro)
    index = VermeilTreatment::OPTIONS.index(VermeilTreatment.normalize(default)) || 1
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 100_010
    backdrop = BitmapSprite.new(Graphics.width, Graphics.height, vp)
    backdrop.z = 0
    effects = BitmapSprite.new(Graphics.width, Graphics.height, vp)
    effects.z = 1
    previous = Sprite.new(vp)
    previous.z = 2
    previous.visible = false
    portrait = Sprite.new(vp)
    portrait.z = 3
    arrows = []
    pictures = {}
    ui_art = vermeil_ui_bitmap("treatment")
    tick = 0

    blackout_bmp = Bitmap.new(Graphics.width, Graphics.height)
    blackout_bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    blackout = Sprite.new(vp)
    blackout.bitmap = blackout_bmp
    blackout.z = 10
    blackout.opacity = 255

    begin
      VermeilTreatment::OPTIONS.each do |option|
        path = "#{VermeilTreatment::ASSET_DIR}/solen_#{option}"
        next unless pbResolveBitmap(path)
        pictures[option] = AnimatedBitmap.new(path).deanimate
      rescue => e
        echoln("[VermeilTreatment] Error cargando #{path}: #{e.message}") rescue nil
      end

      # Los dos triángulos son gráficos del juego, no formas improvisadas.
      ["left_arrow", "right_arrow"].each_with_index do |name, i|
        path = "Graphics/UI/#{name}"
        next unless pbResolveBitmap(path)
        bitmap = AnimatedBitmap.new(path).deanimate
        arrow = Sprite.new(vp)
        arrow.bitmap = bitmap
        arrow.z = 4
        # Recursos UI: las flechas son tiras verticales. Solo primer frame.
        frame_w = bitmap.width
        # Los assets nativos miden 40x224: 7 cuadros verticales de 40x32.
        frame_h = if bitmap.width == 40 && bitmap.height == 224
                    32
                  elsif bitmap.height > bitmap.width * 4 && bitmap.height % 7 == 0
                    bitmap.height / 7
                  else
                    [bitmap.width, bitmap.height].min
                  end
        arrow.src_rect.set(0, 0, frame_w, frame_h)
        zoom = [[29.0 / [frame_w, frame_h].max, 2.0].min, 1.0].max
        arrow.zoom_x = arrow.zoom_y = zoom
        arrow.x = (Graphics.width - 640) / 2 + (i == 0 ? 84 : 556) - frame_w * zoom / 2
        arrow.y = (Graphics.height - 480) / 2 + 264 - frame_h * zoom / 2
        arrows << [arrow, bitmap, arrow.x]
      end

      current = VermeilTreatment::OPTIONS[index]
      draw_treatment_ui(backdrop.bitmap, current, !pictures.empty?, ui_art)
      refresh_treatment_portrait(portrait, pictures, current)
      portrait.opacity = 0

      # Entrada suave desde negro, con anticipación y aterrizaje ease-out.
      backdrop.opacity = 0
      22.times do |i|
        t = (i + 1) / 22.0
        eased = 1.0 - (1.0 - t) ** 3
        backdrop.opacity = (255 * eased).round
        backdrop.y = (14 * (1.0 - eased)).round
        portrait.opacity = (255 * eased).round
        portrait.y = treatment_portrait_y(portrait) + (12 * (1.0 - eased)).round
        blackout.opacity = (255 * (1.0 - eased)).round
        draw_treatment_effects(effects.bitmap, current, tick)
        tick += 1
        update
      end
      backdrop.y = 0
      blackout.opacity = 0

      # La elección no tiene un temporizador: el jugador marca el ritmo.
      loop do
        update
        tick += 1
        current = VermeilTreatment::OPTIONS[index]
        draw_treatment_effects(effects.bitmap, current, tick)
        portrait.y = treatment_portrait_y(portrait) + (Math.sin(tick / 20.0) * 2).round
        arrows.each_with_index do |(arrow, _bitmap, base_x), i|
          arrow.x = base_x + ((i == 0 ? -1 : 1) * Math.sin(tick / 16.0) * 3).round
          arrow.opacity = 205 + (Math.sin(tick / 12.0) * 45).round
        end

        direction = 0
        direction = -1 if Input.trigger?(Input::LEFT)
        direction = 1 if Input.trigger?(Input::RIGHT)
        if direction != 0
          previous.bitmap = portrait.bitmap
          previous.src_rect.set(portrait.src_rect.x, portrait.src_rect.y,
                                portrait.src_rect.width, portrait.src_rect.height)
          previous.zoom_x = portrait.zoom_x
          previous.zoom_y = portrait.zoom_y
          previous.x = portrait.x
          previous.y = portrait.y
          previous.opacity = 255
          previous.visible = !previous.bitmap.nil?

          index = (index + direction) % VermeilTreatment::OPTIONS.length
          current = VermeilTreatment::OPTIONS[index]
          draw_treatment_ui(backdrop.bitmap, current, !pictures.empty?, ui_art)
          refresh_treatment_portrait(portrait, pictures, current)
          target_x = portrait.x
          pbSEPlay("GUI sel cursor") rescue nil
          8.times do |frame|
            t = (frame + 1) / 8.0
            eased = 1.0 - (1.0 - t) ** 3
            previous.opacity = (255 * (1.0 - eased)).round
            previous.x = previous.x - (direction * 2) if frame < 8
            portrait.opacity = (255 * eased).round
            portrait.x = target_x + (direction * 18 * (1.0 - eased)).round
            portrait.y = treatment_portrait_y(portrait) - (4 * (1.0 - eased)).round
            draw_treatment_effects(effects.bitmap, current, tick + frame)
            update
          end
          previous.visible = false
          portrait.x = target_x
          portrait.opacity = 255
        elsif Input.trigger?(Input::USE) || Input.trigger?(Input::C)
          next unless vermeil_confirm_selection(vp, "¿Usar #{VermeilTreatment::LABELS[current].downcase}?")
          chosen = VermeilTreatment.set(current)
          pbSEPlay("GUI sel decision") rescue nil
          # Breve confirmación visual, luego salida gradual a negro.
          8.times do |i|
            draw_treatment_effects(effects.bitmap, current, tick + i, true)
            update
          end
          18.times do |i|
            t = (i + 1) / 18.0
            eased = t * t * (3.0 - 2.0 * t)
            blackout.opacity = (255 * eased).round
            portrait.opacity = (255 * (1.0 - eased * 0.4)).round
            update
          end
          return chosen
        end
      end
    ensure
      blackout.dispose if blackout && !blackout.disposed?
      blackout_bmp.dispose if blackout_bmp && !blackout_bmp.disposed?
      arrows.each do |arrow, bitmap, _x|
        arrow.dispose if arrow && !arrow.disposed?
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
      previous.dispose if previous && !previous.disposed?
      portrait.dispose if portrait && !portrait.disposed?
      pictures.each_value { |bmp| bmp.dispose if bmp && !bmp.disposed? }
      effects.dispose if effects && !effects.disposed?
      backdrop.dispose if backdrop && !backdrop.disposed?
      ui_art.dispose if ui_art && !ui_art.disposed?
      vp.dispose if vp && !vp.disposed?
    end
  end

  def treatment_portrait_y(sprite)
    return 150 unless sprite.bitmap
    ((Graphics.height - 480) / 2 + 150 +
     (244 - sprite.src_rect.height * sprite.zoom_y) / 2).round
  end

  # Compatible con el editor: un solo comando con tres variantes narrativas.
  # En neutro utilizar castellano sin marcas de género (nunca "elle" ni "-e").
  def treatment_text(masculino:, femenino:, neutro:, speaker: nil, speed: :normal)
    text = VermeilTreatment.text(
      masculino: masculino, femenino: femenino, neutro: neutro
    )
    text_inline(text, speaker: speaker, speed: speed)
  end

  # Los PNG no comparten necesariamente el mismo margen transparente.
  # Centrar por los píxeles visibles, no por el tamaño del lienzo.
  def treatment_visible_rect(bitmap)
    @treatment_visible_bounds ||= {}
    return @treatment_visible_bounds[bitmap.object_id] if @treatment_visible_bounds.key?(bitmap.object_id)
    left = bitmap.width
    top = bitmap.height
    right = -1
    bottom = -1
    (0...bitmap.height).step(3) do |y|
      (0...bitmap.width).step(3) do |x|
        next if bitmap.get_pixel(x, y).alpha < 32
        left = x if x < left
        top = y if y < top
        right = x if x > right
        bottom = y if y > bottom
      end
    end
    rect = if right < left
             Rect.new(0, 0, bitmap.width, bitmap.height)
           else
             x = [left - 4, 0].max
             y = [top - 4, 0].max
             Rect.new(x, y, [[right + 7, bitmap.width].min - x, 1].max,
                      [[bottom + 7, bitmap.height].min - y, 1].max)
           end
    @treatment_visible_bounds[bitmap.object_id] = rect
  end

  def refresh_treatment_portrait(sprite, portraits, option)
    bitmap = portraits[option]
    sprite.bitmap = bitmap
    sprite.visible = !bitmap.nil?
    return unless bitmap
    rect = treatment_visible_rect(bitmap)
    sprite.src_rect.set(rect.x, rect.y, rect.width, rect.height)
    scale = [274.0 / rect.width, 244.0 / rect.height, 1.0].min
    sprite.zoom_x = sprite.zoom_y = scale
    sprite.x = ((Graphics.width - rect.width * scale) / 2).round +
               VermeilTreatment::PORTRAIT_X_OFFSET.fetch(option, 0)
    sprite.y = treatment_portrait_y(sprite)
  end

  # Efectos en capa separada; nunca pinta sobre el PNG del personaje.
  # Partículas orbitales, brillo de selección y guías luminosas de navegación.
  def draw_treatment_effects(bitmap, option, tick, confirm = false)
    bitmap.clear
    ox = ((Graphics.width - 640) / 2.0).round
    oy = ((Graphics.height - 480) / 2.0).round
    accent = case option
             when :femenino then [221, 78, 159]
             when :masculino then [137, 109, 176]
             else [93, 170, 168]
             end
    a = accent
    16.times do |i|
      angle = (i * Math::PI / 8.0) + (tick * 0.012)
      x = ox + 320 + (Math.cos(angle) * 173).round
      y = oy + 267 + (Math.sin(angle) * 126).round
      size = (i % 4 == 0) ? 5 : 3
      alpha = 70 + (Math.sin(tick * 0.045 + i) * 45).round
      bitmap.fill_rect(x, y, size, size, Color.new(a[0], a[1], a[2], alpha))
    end
    pulse = 120 + (Math.sin(tick * 0.11) * 75).round
    [ox + 72, ox + 547].each do |x|
      bitmap.fill_rect(x, oy + 231, 3, 55,
                       Color.new(a[0], a[1], a[2], pulse))
    end
    # Indicador de tres opciones, sincronizado con el orden real.
    VermeilTreatment::OPTIONS.each_with_index do |candidate, i|
      x = ox + 293 + i * 22
      selected = candidate == option
      bitmap.fill_rect(x, oy + 399, selected ? 12 : 7, 5,
                       Color.new(a[0], a[1], a[2], selected ? 255 : 90))
    end
    if confirm
      bitmap.fill_rect(ox + 50, oy + 145, 540, 250,
                       Color.new(a[0], a[1], a[2], 55))
    end
  end

  # Gama crema/cobre inspirada en los menús del juego; sin PNG extra.
  def draw_treatment_ui(bitmap, option, has_art, ui_art = nil)
    ox = ((Graphics.width - 640) / 2.0).round
    oy = ((Graphics.height - 480) / 2.0).round
    ink = Color.new(65, 44, 38)
    cream = Color.new(252, 246, 218)
    paper = Color.new(244, 231, 193)
    copper = Color.new(176, 100, 59)
    dark = Color.new(111, 64, 48)
    magenta = Color.new(154, 75, 108)
    bitmap.clear
    if ui_art
      bitmap.blt(ox, oy, ui_art, Rect.new(0, 0, ui_art.width, ui_art.height))
      pbSetSystemFont(bitmap)
      bitmap.font.color = ink
      bitmap.font.size = 28
      bitmap.draw_text(ox + 170, oy + 39, 300, 34, VermeilTreatment::LABELS[option], 1)
      bitmap.font.size = 18
      bitmap.font.color = cream
      bitmap.draw_text(ox + 80, oy + 108, 480, 28, "Izq. / Der. elegir      Enter confirmar", 1)
      return
    end
    bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(53, 40, 42))
    bitmap.fill_rect(ox + 18, oy + 14, 604, 452, dark)
    bitmap.fill_rect(ox + 23, oy + 19, 594, 442, cream)
    bitmap.fill_rect(ox + 34, oy + 30, 572, 75, copper)
    bitmap.fill_rect(ox + 40, oy + 35, 560, 64, paper)
    bitmap.fill_rect(ox + 49, oy + 42, 5, 50, magenta)
    bitmap.fill_rect(ox + 586, oy + 42, 5, 50, magenta)
    bitmap.fill_rect(ox + 34, oy + 111, 572, 290, Color.new(223, 197, 148))
    bitmap.fill_rect(ox + 39, oy + 116, 562, 280, cream)
    bitmap.fill_rect(ox + 138, oy + 122, 364, 270, Color.new(232, 217, 189))
    bitmap.fill_rect(ox + 143, oy + 127, 354, 260, Color.new(251, 247, 230))
    # Franja inferior independiente: no tapa las instrucciones.
    bitmap.fill_rect(ox + 34, oy + 410, 572, 43, dark)
    bitmap.fill_rect(ox + 40, oy + 415, 560, 33, copper)
    pbSetSystemFont(bitmap)
    bitmap.font.color = ink
    bitmap.font.size = 32
    bitmap.draw_text(ox + 95, oy + 44, 450, 43, VermeilTreatment::LABELS[option], 1)
    bitmap.font.color = cream
    bitmap.font.size = 18
    bitmap.draw_text(ox + 54, oy + 421, 532, 23,
                     "Izq. / Der.  Elegir       Enter  Confirmar", 1)
    if !has_art
      bitmap.font.color = ink
      bitmap.font.size = 18
      bitmap.draw_text(ox + 149, oy + 298, 340, 34, "Faltan los PNG de Solen", 1)
    end
  end

  # Pantalla exclusiva de Vermeil; el control de teclado es el propio de
  # Essentials, pero su ventana es invisible y toda la UI se dibuja aquí.
  def custom_name_input(default: "Solen", min: 1, max: 12)
    return name_input(default: default, min: min, max: max) unless defined?(Window_TextEntry_Keyboard)
    max = [[max.to_i, 1].max, 20].min
    min = [[min.to_i, 1].max, max].min
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 100_020
    ui = BitmapSprite.new(Graphics.width, Graphics.height, vp)
    preview = nil
    preview_bmp = nil
    entry = nil
    ui_art = vermeil_ui_bitmap("name")
    blackout_bmp = Bitmap.new(Graphics.width, Graphics.height)
    blackout_bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    blackout = Sprite.new(vp)
    blackout.bitmap = blackout_bmp
    blackout.z = 100
    blackout.opacity = 255
    ox = ((Graphics.width - 640) / 2.0).round
    oy = ((Graphics.height - 480) / 2.0).round
    name = default.to_s[0, max]

    begin
      chosen = VermeilTreatment.current
      image_path = "#{VermeilTreatment::ASSET_DIR}/solen_#{chosen}"
      if pbResolveBitmap(image_path)
        preview_bmp = AnimatedBitmap.new(image_path).deanimate
        preview = Sprite.new(vp)
        preview.bitmap = preview_bmp
        preview.z = 2
        rect = treatment_visible_rect(preview_bmp)
        preview.src_rect.set(rect.x, rect.y, rect.width, rect.height)
        scale = [168.0 / rect.width, 236.0 / rect.height, 1.0].min
        preview.zoom_x = preview.zoom_y = scale
        preview.x = ox + 139 - (rect.width * scale / 2).round
        preview.y = oy + 140 + (236 - rect.height * scale) / 2
      end

      # Misma captura de texto que la UI original. Sin teclado casero.
      entry = Window_TextEntry_Keyboard.new(
        name, ox + 258, oy + 217, 304, 80, "", true
      )
      entry.viewport = vp
      entry.maxlength = max
      entry.opacity = 0
      entry.back_opacity = 0
      entry.contents_opacity = 0
      entry.visible = true
      Input.text_input = true

      draw_vermeil_name_ui(ui.bitmap, name, max, false, ui_art)
      16.times do |i|
        t = (i + 1) / 16.0
        blackout.opacity = (255 * (1.0 - t) ** 2).round
        update
      end

      tick = 0
      previous = nil
      blink = nil
      loop do
        update
        entry.update
        helper = entry.instance_variable_get(:@helper)
        if helper && helper.respond_to?(:cursor=)
          helper.cursor = entry.text.to_s.length
        end
        tick += 1
        name = entry.text.to_s[0, max]
        show_cursor = false
        if name != previous || show_cursor != blink
          draw_vermeil_name_ui(ui.bitmap, name, max, show_cursor, ui_art)
          previous = name.dup
          blink = show_cursor
        end
        if Input.triggerex?(:RETURN) || Input.trigger?(Input::USE)
          if name.strip.length >= min
            if vermeil_confirm_selection(vp, "¿Usar el nombre #{name.strip}?")
              pbSEPlay("GUI sel decision") rescue nil
              break
            end
            # No reiniciar el texto ni el cursor al regresar.
            Input.text_input = true
            next
          end
          pbPlayBuzzerSE rescue nil
        end
      end
      15.times do |i|
        t = (i + 1) / 15.0
        blackout.opacity = (255 * t * t).round
        update
      end
      name = name.strip
      if $player
        $player.name = name
      elsif $Trainer
        $Trainer.name = name
      end
      name
    ensure
      Input.text_input = false
      entry.dispose if entry && !entry.disposed?
      preview.dispose if preview && !preview.disposed?
      preview_bmp.dispose if preview_bmp && !preview_bmp.disposed?
      blackout.dispose if blackout && !blackout.disposed?
      blackout_bmp.dispose if blackout_bmp && !blackout_bmp.disposed?
      ui.dispose if ui && !ui.disposed?
      ui_art.dispose if ui_art && !ui_art.disposed?
      vp.dispose if vp && !vp.disposed?
    end
  end

  def draw_vermeil_name_ui(bitmap, name, max, show_cursor, ui_art = nil)
    ox = ((Graphics.width - 640) / 2.0).round
    oy = ((Graphics.height - 480) / 2.0).round
    bg = Color.new(55, 39, 41)
    border = Color.new(103, 56, 45)
    wood = Color.new(174, 99, 58)
    light = Color.new(205, 137, 75)
    cream = Color.new(252, 246, 219)
    parchment = Color.new(244, 228, 189)
    ink = Color.new(64, 42, 41)
    magenta = Color.new(153, 76, 102)
    bitmap.clear
    if ui_art
      bitmap.blt(ox, oy, ui_art, Rect.new(0, 0, ui_art.width, ui_art.height))
      pbSetSystemFont(bitmap)
      bitmap.font.color = ink
      bitmap.font.size = 31
      bitmap.draw_text(ox + 222, oy + 42, 360, 44, "TU NOMBRE", 1)
      bitmap.font.size = 28
      bitmap.draw_text(ox + 290, oy + 223, 283, 47, name.to_s, 1)
      bitmap.font.size = 18
      bitmap.draw_text(ox + 286, oy + 311, 277, 24, "#{name.length} / #{max}", 1)
      return
    end
    bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, bg)
    bitmap.fill_rect(ox + 16, oy + 16, 608, 448, border)
    bitmap.fill_rect(ox + 22, oy + 22, 596, 436, cream)
    bitmap.fill_rect(ox + 34, oy + 32, 572, 77, wood)
    bitmap.fill_rect(ox + 41, oy + 38, 558, 62, parchment)
    bitmap.fill_rect(ox + 50, oy + 42, 6, 52, magenta)
    bitmap.fill_rect(ox + 584, oy + 42, 6, 52, magenta)
    bitmap.fill_rect(ox + 34, oy + 119, 211, 280, border)
    bitmap.fill_rect(ox + 40, oy + 125, 199, 268, parchment)
    bitmap.fill_rect(ox + 253, oy + 119, 353, 280, border)
    bitmap.fill_rect(ox + 259, oy + 125, 341, 268, cream)
    bitmap.fill_rect(ox + 272, oy + 225, 315, 85, wood)
    bitmap.fill_rect(ox + 279, oy + 231, 301, 73, parchment)
    bitmap.fill_rect(ox + 34, oy + 409, 572, 43, border)
    bitmap.fill_rect(ox + 40, oy + 415, 560, 31, wood)
    pbSetSystemFont(bitmap)
    bitmap.font.color = ink
    bitmap.font.size = 31
    bitmap.draw_text(ox + 110, oy + 44, 420, 43, "ELIGE TU NOMBRE", 1)
    bitmap.font.size = 20
    bitmap.draw_text(ox + 277, oy + 148, 308, 32, "Nombre del protagonista", 1)
    bitmap.font.size = 29
    bitmap.draw_text(ox + 292, oy + 243, 276, 39,
                     name.to_s, 1)
    bitmap.font.size = 18
    bitmap.draw_text(ox + 275, oy + 325, 305, 27,
                     "#{name.length} / #{max} caracteres", 1)
    bitmap.font.size = 17
    bitmap.font.color = cream
    bitmap.draw_text(ox + 57, oy + 420, 526, 23,
                     "Escribir  ·  Retroceso: borrar  ·  Enter: confirmar", 1)
  end

  # Fondo PNG intercambiable. El código sigue funcionando si no hay archivo.
  def vermeil_ui_bitmap(name)
    path = "#{VermeilTreatment::UI_DIR}/#{name}"
    return nil unless pbResolveBitmap(path)
    AnimatedBitmap.new(path).deanimate
  rescue => e
    echoln("[Vermeil UI] #{e.message}") rescue nil
    nil
  end

  # Confirmación reversible para ambas pantallas; el texto es una capa
  # propia y nunca está incrustado en los fondos PNG.
  def vermeil_confirm_selection(viewport, question)
    box = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
    box.z = 8
    selected = 0
    ox = ((Graphics.width - 640) / 2).round
    oy = ((Graphics.height - 480) / 2).round
    was_text_input = Input.text_input
    Input.text_input = false
    update
    loop do
      bmp = box.bitmap
      bmp.clear
      bmp.fill_rect(ox + 62, oy + 321, 516, 121, Color.new(51, 35, 50, 242))
      bmp.fill_rect(ox + 67, oy + 326, 506, 111, Color.new(245, 224, 185))
      bmp.fill_rect(ox + 72, oy + 331, 496, 101, Color.new(255, 245, 215))
      pbSetSystemFont(bmp)
      bmp.font.size = 24
      bmp.font.color = Color.new(70, 41, 51)
      bmp.draw_text(ox + 78, oy + 340, 484, 35, question, 1)
      bmp.font.size = 22
      ["Confirmar", "Cambiar"].each_with_index do |label, i|
        x = ox + 138 + i * 225
        if selected == i
          bmp.fill_rect(x, oy + 381, 170, 37, Color.new(155, 76, 104))
          bmp.font.color = Color.new(255, 246, 225)
        else
          bmp.font.color = Color.new(70, 41, 51)
        end
        bmp.draw_text(x, oy + 385, 170, 30, label, 1)
      end
      update
      if Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        selected = 1 - selected
        pbSEPlay("GUI sel cursor") rescue nil
      elsif Input.trigger?(Input::BACK)
        return false
      elsif Input.trigger?(Input::USE) || Input.trigger?(Input::C) ||
            Input.triggerex?(:RETURN)
        return selected == 0
      end
    end
  ensure
    Input.text_input = was_text_input unless was_text_input.nil?
    box.dispose if box && !box.disposed?
  end

end
