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
    default = VermeilTreatment.normalize(default)
    index = VermeilTreatment::OPTIONS.index(default) || 1
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 100_010
    backdrop = BitmapSprite.new(Graphics.width, Graphics.height, vp)
    backdrop.z = 0
    effects = BitmapSprite.new(Graphics.width, Graphics.height, vp)
    effects.z = 1
    portrait = Sprite.new(vp)
    portrait.z = 2
    portraits = {}
    tick = 0

    begin
      VermeilTreatment::OPTIONS.each do |option|
        path = "#{VermeilTreatment::ASSET_DIR}/solen_#{option}"
        next unless pbResolveBitmap(path)
        portraits[option] = AnimatedBitmap.new(path).deanimate
      rescue => e
        echoln("[VermeilTreatment] Error cargando #{path}: #{e.message}") rescue nil
      end

      draw_treatment_ui(backdrop.bitmap, VermeilTreatment::OPTIONS[index], !portraits.empty?)
      refresh_treatment_portrait(portrait, portraits, VermeilTreatment::OPTIONS[index])
      # Entrada suave, destellos ambientales y respuesta animada al cambiar.
      portrait.opacity = 0
      update  # Evita arrastrar la confirmación del diálogo anterior.
      loop do
        update
        tick += 1
        option = VermeilTreatment::OPTIONS[index]
        draw_treatment_effects(effects.bitmap, option, tick)
        portrait.opacity = [portrait.opacity + 24, 255].min
        if portrait.bitmap
          portrait.y = 102 + ((320 - portrait.bitmap.height * portrait.zoom_y) / 2).round +
                       (Math.sin(tick / 18.0) * 3).round
        end

        change = 0
        change = -1 if Input.trigger?(Input::LEFT)
        change = 1 if Input.trigger?(Input::RIGHT)
        if change != 0
          index = (index + change) % VermeilTreatment::OPTIONS.length
          option = VermeilTreatment::OPTIONS[index]
          draw_treatment_ui(backdrop.bitmap, option, !portraits.empty?)
          refresh_treatment_portrait(portrait, portraits, option)
          portrait.opacity = 0
          pbSEPlay("GUI sel cursor") rescue nil
        elsif Input.trigger?(Input::USE) || Input.trigger?(Input::C)
          selection = VermeilTreatment.set(option)
          pbSEPlay("GUI sel decision") rescue nil
          10.times do |i|
            draw_treatment_effects(effects.bitmap, option, tick + i, true)
            portrait.opacity = [255 - i * 16, 0].max
            update
          end
          return selection
        end
      end
    ensure
      portrait.dispose if portrait && !portrait.disposed?
      portraits.each_value { |bmp| bmp.dispose if bmp && !bmp.disposed? }
      effects.dispose if effects && !effects.disposed?
      backdrop.dispose if backdrop && !backdrop.disposed?
      vp.dispose if vp && !vp.disposed?
    end
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
    bitmap.draw_text(ox + 53, oy + 433, 534, 23, "← / → Cambiar     Z / Intro Confirmar", 1)

    # Flechas pixeladas, en bitmap independiente del retrato.
    [false, true].each do |right|
      cx = ox + (right ? 557 : 83)
      cy = oy + 260
      9.times do |i|
        span = (8 - (i - 4).abs) * 4
        x = right ? cx - (8 - i) * 3 : cx + (8 - i) * 3
        bitmap.fill_rect(x, cy - span / 2, 4, span, outer)
        bitmap.fill_rect(x + 1, cy - span / 2 + 2, 2, [span - 4, 1].max, magenta)
      end
    end

    if !has_art
      bitmap.font.size = 18
      bitmap.draw_text(ox + 153, oy + 316, 335, 50, "Añade los PNG del personaje", 1)
    end
  end
end
