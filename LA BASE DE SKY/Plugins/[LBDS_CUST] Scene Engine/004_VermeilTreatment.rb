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
        zoom = [[36.0 / [bitmap.width, bitmap.height].max, 2.0].min, 0.5].max
        arrow.zoom_x = arrow.zoom_y = zoom
        arrow.x = (Graphics.width - 640) / 2 + (i == 0 ? 84 : 556) - bitmap.width * zoom / 2
        arrow.y = (Graphics.height - 480) / 2 + 264 - bitmap.height * zoom / 2
        arrows << [arrow, bitmap, arrow.x]
      end

      current = VermeilTreatment::OPTIONS[index]
      draw_treatment_ui(backdrop.bitmap, current, !pictures.empty?)
      refresh_treatment_portrait(portrait, pictures, current)
      portrait.opacity = 0

      # Entrada suave desde negro, con anticipación y aterrizaje ease-out.
      backdrop.opacity = 0
      36.times do |i|
        t = (i + 1) / 36.0
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
          previous.zoom_x = portrait.zoom_x
          previous.zoom_y = portrait.zoom_y
          previous.x = portrait.x
          previous.y = portrait.y
          previous.opacity = 255
          previous.visible = !previous.bitmap.nil?

          index = (index + direction) % VermeilTreatment::OPTIONS.length
          current = VermeilTreatment::OPTIONS[index]
          draw_treatment_ui(backdrop.bitmap, current, !pictures.empty?)
          refresh_treatment_portrait(portrait, pictures, current)
          target_x = portrait.x
          pbSEPlay("GUI sel cursor") rescue nil
          12.times do |frame|
            t = (frame + 1) / 12.0
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
          chosen = VermeilTreatment.set(current)
          pbSEPlay("GUI sel decision") rescue nil
          # Breve confirmación visual, luego salida gradual a negro.
          16.times do |i|
            draw_treatment_effects(effects.bitmap, current, tick + i, true)
            update
          end
          32.times do |i|
            t = (i + 1) / 32.0
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
      vp.dispose if vp && !vp.disposed?
    end
  end

  def treatment_portrait_y(sprite)
    return 102 unless sprite.bitmap
    ((Graphics.height - 480) / 2 + 102 +
     (320 - sprite.bitmap.height * sprite.zoom_y) / 2).round
  end

  # Compatible con el editor: un solo comando con tres variantes narrativas.
  # En neutro utilizar castellano sin marcas de género (nunca "elle" ni "-e").
  def treatment_text(masculino:, femenino:, neutro:, speaker: nil, speed: :normal)
    text = VermeilTreatment.text(
      masculino: masculino, femenino: femenino, neutro: neutro
    )
    text_inline(text, speaker: speaker, speed: speed)
  end

  def refresh_treatment_portrait(sprite, portraits, option)
    bitmap = portraits[option]
    sprite.bitmap = bitmap
    sprite.visible = !bitmap.nil?
    return if !bitmap
    scale = [304.0 / bitmap.width, 320.0 / bitmap.height, 1.0].min
    sprite.zoom_x = scale
    sprite.zoom_y = scale
    sprite.x = ((Graphics.width - bitmap.width * scale) / 2).round
    sprite.y = (102 + (320 - bitmap.height * scale) / 2).round
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
      bitmap.fill_rect(x, oy + 416, selected ? 12 : 7, 5,
                       Color.new(a[0], a[1], a[2], selected ? 255 : 90))
    end
    if confirm
      bitmap.fill_rect(ox + 50, oy + 104, 540, 302,
                       Color.new(a[0], a[1], a[2], 55))
    end
  end

  def draw_treatment_ui(bitmap, option, has_art)
    w = Graphics.width
    h = Graphics.height
    ox = ((w - 640) / 2.0).round
    oy = ((h - 480) / 2.0).round
    c = proc { |r, g, b| Color.new(r, g, b) }
    outer = c.call(38, 45, 63)
    purple = c.call(133, 63, 103)
    magenta = c.call(195, 100, 149)
    cream = c.call(249, 245, 229)
    pale = c.call(230, 224, 226)
    bitmap.clear
    bitmap.fill_rect(0, 0, w, h, c.call(219, 222, 225))
    bitmap.fill_rect(ox + 24, oy + 18, 592, 444, outer)
    bitmap.fill_rect(ox + 29, oy + 23, 582, 434, cream)
    bitmap.fill_rect(ox + 41, oy + 109, 558, 321, pale)
    bitmap.fill_rect(ox + 45, oy + 113, 550, 313, c.call(245, 242, 237))
    bitmap.fill_rect(ox + 41, oy + 30, 558, 68, purple)
    bitmap.fill_rect(ox + 46, oy + 35, 548, 58, cream)
    bitmap.fill_rect(ox + 53, oy + 39, 7, 50, magenta)
    bitmap.fill_rect(ox + 580, oy + 39, 7, 50, magenta)
    bitmap.fill_rect(ox + 132, oy + 125, 376, 289, c.call(233, 229, 230))
    bitmap.fill_rect(ox + 138, oy + 131, 364, 277, c.call(247, 244, 240))
    bitmap.fill_rect(ox + 35, oy + 438, 570, 17, outer)
    pbSetSystemFont(bitmap)
    bitmap.font.size = 33
    bitmap.font.color = outer
    bitmap.draw_text(ox + 90, oy + 42, 460, 42, VermeilTreatment::LABELS[option], 1)
    bitmap.font.size = 20
    bitmap.draw_text(ox + 53, oy + 433, 534, 23, "← →  Cambiar      C / Enter  Confirmar", 1)

    if !has_art
      bitmap.font.size = 18
      bitmap.draw_text(ox + 153, oy + 316, 335, 50, "Añade los PNG del personaje", 1)
    end
  end
end
