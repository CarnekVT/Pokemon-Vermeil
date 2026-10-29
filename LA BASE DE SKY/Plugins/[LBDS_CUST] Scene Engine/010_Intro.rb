# encoding: utf-8
def pbIntroVermeil
  SceneEngine.play do
    bgm "Snow-Buried Tales - Intro.ogg"
    # ══════════ FASE 1: EL DESPERTAR DEL ALMA ══════════
    wait 20

    @sprites[:float_bg] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites[:float_bg].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    @sprites[:float_bg].z = SceneEngine::Settings::LAYER_IMG - 10
    golden = show_floating "Graphics/Scenes/Intro/GoldenEntity",
                           Graphics.width / 2 - 75 / 2,
                           (Graphics.height / 2 - 30) - 144 / 2,
                           amplitude: 6, speed: 0.03, zoom: 1, fade: 40,
                           z: SceneEngine::Settings::LAYER_IMG + 70
    fade_from_black 30

    text_inline "El mundo conoció el equilibrio. Pero la ambición humana terminó por quebrarlo.",
                speaker: "???", speed: :slow
    hide_textbox(10)

    # ══════════ FASE 2: LA SOMBRA DEL PASADO ══════════

    start_scrolling "Graphics/Scenes/Intro/clouds", 0, 190, speed: 1.5, horizontal: true
    fade_in_scrolling 30

    75.times do |i|
      progress = (i + 1) / 75.0
      z = 1 - 0.5 * progress
      cy = (Graphics.height / 2 - 30) + 20 * progress
      golden[:sprite].zoom_x = z
      golden[:sprite].zoom_y = z
      golden[:sprite].x = Graphics.width / 2 - golden[:sprite].bitmap.width * z / 2
      golden[:base_y] = cy - golden[:sprite].bitmap.height * z / 2
      update
    end
    wait 15

    elder = show_floating "Graphics/Scenes/Intro/ElderSoul",
                          -288, -410,
                          amplitude: 6, speed: 0.03, zoom: 1, opacity: 0
    40.times do |i|
      progress = (i + 1) / 40.0
      elder[:sprite].opacity = (255 * progress).round
      update
    end

    text_inline "Me aparté de la humanidad, convencido de que no tenía remedio. Pero la peor traición vino de mi propia sangre.",
                speaker: "???", speed: :slow
    hide_textbox(10)
    fade_out_sprites([golden[:sprite], elder[:sprite]], 15)
    hide_floating
    hide_all

    # ══════════ FASE 3: LA GUARDIANA INTERVIENE ══════════

    show "Graphics/Scenes/Intro/FennaSupay", 0, 8, fade: 30
    show_floating "Graphics/Scenes/Intro/SupayorusEnergy", 255, 90, amplitude: 8, speed: 0.04, fade: 20

    text_inline "El Guía de los Caídos llevaba las almas a su descanso. Luego empezó a verlas como una fuente de poder... y lo arruinó todo.",
                speaker: "Mujer Misteriosa", speed: :slow
    hide_textbox(10)

    # ══════════ FASE 4: EL RELATO DEL ENFRENTAMIENTO ══════════

    energy = @floating_sprites.first
    clouds = @scrolling_sprites.flat_map { |s| s[:sprites] }
    fade_out_sprites([@image_sprites["Graphics/Scenes/Intro/FennaSupay"],
                      energy&.[](:sprite),
                      *clouds], 15)
    hide_floating
    hide_all
    show "Graphics/Scenes/Intro/int5", 0, 0, fade: 30

    text_inline "Consumió las almas que había jurado proteger. Con cada una, aumentaba su poder... hasta que decidió desafiarme.",
                speaker: "Gran Espíritu", speed: :slow
    text_inline "Las Fuerzas de la Naturaleza, mis otros hijos, lucharon a mi lado. Le arrebatamos su poder, mas no extinguimos su rencor.",
                speaker: "Gran Espíritu", speed: :slow
    hide_textbox(10)

    # ══════════ FASE 5: LA DEFENSA DE LA TRADICIÓN ══════════

    show "Graphics/Scenes/Intro/int9", 0, 0, fade: 25

    text_inline "Y después de aquello, nos diste la espalda. A todos. No precisamente tu mejor decisión, Gran Espíritu.",
                speaker: "Mujer Misteriosa", speed: :slow
    text_inline "Hay gente capaz de horrores, sí. Pero también quien lo daría todo por ver a los suyos en paz. Eso también cuenta.",
                speaker: "Mujer Misteriosa", speed: :slow
    text_inline "Y hablando de problemas... el Guía está recuperando fuerzas. Si vuelve, nuestra región será la primera en sufrirlo.",
                speaker: "Mujer Misteriosa", speed: :slow
    hide_textbox(10)

    # ══════════ FASE 6: LA REVELACIÓN DEL RECEPTÁCULO ══════════

    @image_sprites["Graphics/Scenes/Intro/int5"]&.visible = false
    fade_out_sprites([@image_sprites["Graphics/Scenes/Intro/int9"]], 20)
    hide_floating
    hide_all
    stop_scrolling
    start_scrolling "Graphics/Scenes/Intro/clouds", 0, 190, speed: 1.5, horizontal: true
    fade_in_scrolling 25
    golden6 = show_floating "Graphics/Scenes/Intro/GoldenEntity",
                            Graphics.width / 2 - 75 * 0.5 / 2,
                            (Graphics.height / 2 - 10) - 144 * 0.5 / 2,
                            amplitude: 6, speed: 0.03, zoom: 0.5, fade: 25,
                            z: SceneEngine::Settings::LAYER_IMG + 70
    elder6 = show_floating "Graphics/Scenes/Intro/ElderSoul",
                           -288, -410,
                           amplitude: 6, speed: 0.03, zoom: 1, opacity: 0
    30.times do |i|
      progress = (i + 1) / 30.0
      elder6[:sprite].opacity = (255 * progress).round
      update
    end

    text_inline "Por eso te hemos llamado, Ente Dorado. No perteneces a este mundo y su hambre no puede alcanzarte, pero necesitas un cuerpo.",
                speaker: "Gran Espíritu", speed: :slow
    hide_textbox(10)

    fade_out_sprites([golden6[:sprite], elder6[:sprite],
                      *@scrolling_sprites.flat_map { |s| s[:sprites] }], 20)
    hide_floating
    hide_all
    stop_scrolling

    float_sprite "Graphics/Scenes/Intro/FloatSolen96x96perFrame",
                 96, 96, 6,
                 Graphics.width / 2 - 48, -96,
                 end_y: 160, speed: 0.7, fps: 6, fade: 25, glow: true, ghost_interval: 2, bg: true
    wait 400

    text_inline "Mira, ahí está Solen. Tiene una determinación difícil de encontrar... y aceptó meterse en este lío.",
                speaker: "Mujer Misteriosa", speed: :slow
    text_inline "Y mira qué bien duerme, como si aquí no pasara nada... En fin. Solen conoce los riesgos y ha aceptado ayudarte.",
                speaker: "Mujer Misteriosa", speed: :slow
    hide_textbox(10)
    text_inline "Solen aceptó este vínculo. Su cuerpo te permitirá actuar entre los vivos; tu fuerza ayudará a enfrentar la oscuridad.",
                speaker: "Gran Espíritu", speed: :slow
    hide_textbox(10)

    # ══════════ FASE 7: EL PACTO Y NOMBRAMIENTO ══════════

    text_inline "Ah, espera. Nos falta un detalle: cuando hablen de ti en este mundo, ¿cómo prefieres que se refieran a ti?",
                speaker: "Mujer Misteriosa", speed: :slow

    hide_textbox(10)
    fade_to_black 15
    @float_anim[:sprite].visible = false if @float_anim
    @float_anim[:glow].visible = false if @float_anim && @float_anim[:glow]
    @sprites[:float_bg]&.dispose
    @sprites[:float_bg] = nil
    treatment_input(default: :neutro)
    fade_from_black 15
    treatment_text(
      masculino: "Entendido, compañero. Así será.",
      femenino: "Entendido, compañera. Así será.",
      neutro: "Entendido. Lo tendremos en cuenta.",
      speaker: "Mujer Misteriosa", speed: :slow
    )
    text_inline "¡Listo! Solen es el nombre que recibió al nacer. ¿Quieres conservarlo o prefieres que te llamemos de otra forma?",
                speaker: "Mujer Misteriosa", speed: :slow
    hide_textbox(10)
    fade_to_black 15
    player_name = name_input(default: "Solen", min: 1, max: 12)
    @float_anim[:sprite].visible = true if @float_anim
    @float_anim[:glow].visible = true if @float_anim && @float_anim[:glow]
    wait 60

    # ══════════ FASE 8: EL PACTO FORJADO ══════════

    hide_all
    stop_scrolling
    @sprites[:black].opacity = 255
    @sprites[:float_bg] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites[:float_bg].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    @sprites[:float_bg].z = SceneEngine::Settings::LAYER_IMG - 10
    start_aura "Graphics/Scenes/Intro/AuraParticle", 12, 12, count: 12, range_x: 35, range_y: 70, duration: 90
    fade_from_black 25

    text_inline "El pacto está sellado, {1}. Mi hijo sigue reuniendo fuerzas. Quizá me demuestres que juzgué a la humanidad demasiado pronto.",
                speaker: "Gran Espíritu", speed: :slow, format_args: [player_name]
    text_inline "Bueno, {1}, ¡ya está! Ahora te toca a ti. Cuídate y recuerda: las mejores aventuras nunca siguen el plan.",
                speaker: "Mujer Misteriosa", speed: :slow, format_args: [player_name]

    # ══════════ FASE 9: LA FUSIÓN Y DESPERTAR ══════════

    hide_textbox(10)
    wait 10

    to_white 15
    stop_float
    stop_aura
    hide_all
    wait 25

    stop_bgm(1.5)
    wait 5
    se "Exit sound effect - IntroWakeUp.wav"
    show_centered_text "Despierta...", speed: :very_slow, color: Color.new(0,0,0)
    
    wait 20
    hide_centered_text

    show "Graphics/Scenes/Intro/BGWakeUp", 0, 0, fade: 0
    start_scrolling "Graphics/Scenes/Intro/BGWakeUpEffectSides", 0, 0, speed: 1
    start_scrolling "Graphics/Scenes/Intro/BGWakeUpEffectSides", Graphics.width - 294, 0, speed: 1, mirror: true
    float_sprite "Graphics/Scenes/Intro/FloatSolen96x96perFrame",
                 96, 96, 6,
                 Graphics.width / 2 - 48, 160,
                 end_y: 160, speed: 0, fps: 6, fade: 0
    start_aura "Graphics/Scenes/Intro/AuraParticle", 12, 12, count: 12, range_x: 35, range_y: 70, duration: 90
    from_white 20, se: "Magical Light Aura Sound Effect - Aura.wav"
    wait 12
    change_float_bitmap "Graphics/Scenes/Intro/FloatSolen96x96perFrameWakeUp"
    wait 10
    change_float_bitmap "Graphics/Scenes/Intro/FloatSolen96x96perFrameSolenWakeUp"
    wait 10
    change_float_bitmap "Graphics/Scenes/Intro/FloatSolen96x96perFramePNTransition"
    wait 10
    change_float_bitmap "Graphics/Scenes/Intro/FloatSolen96x96perFramePN"
    wait 30

    pbChangePlayer(1)

    to_white 20
    stop_scrolling
    wait 100

    Graphics.freeze
    $game_temp.player_new_map_id    = 42
    $game_temp.player_new_x         = 32
    $game_temp.player_new_y         = 16
    $game_temp.player_new_direction = 0
    $game_temp.player_transferring  = true
    $game_temp.transition_processing = true
    $game_temp.transition_name       = ""
  end
end