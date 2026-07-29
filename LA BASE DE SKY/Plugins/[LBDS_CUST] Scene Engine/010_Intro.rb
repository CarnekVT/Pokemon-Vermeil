# encoding: utf-8
def pbIntroVermeil
  SceneEngine.play do
    bgm "Snow-Buried Tales - Intro.ogg"
    # ══════════ FASE 1: EL DESPERTAR DEL ALMA ══════════
    wait 20

    show "Graphics/Scenes/Intro/int1", Graphics.width / 2, Graphics.height / 2,
         fade: 40, origin: :center
    fade_from_black 30

    text_inline "El equilibrio es una línea muy fina.\nUna línea que los humanos rompieron con el peso de su propia codicia.",
                speaker: "???", speed: :slow
    hide_textbox(10)

    # ══════════ FASE 2: LA SOMBRA DEL PASADO ══════════
    
    show "Graphics/Scenes/Intro/int2", 0, 0, fade: 25
    wait 40
    
    show "Graphics/Scenes/Intro/int3", 0, 0, fade: 25
    wait 20
    
    text_inline "Antes de apartarme de este mundo, asqueado por su egoísmo, enfrenté una oscuridad que no vino de los cielos ni de la tierra... sino de mi propia sangre.",
                speaker: "???", speed: :slow
    hide_textbox(10)

    # ══════════ FASE 3: LA GUARDIANA INTERVIENE ══════════

    show "Graphics/Scenes/Intro/int4", 0, 0, fade: 30

    text_inline "El Guía de los Caídos.\nSu deber era noble: llevar a las almas al descanso eterno. Pero la misma avaricia que a veces ciega a los nuestros, lo alcanzó a él en el abismo.",
                speaker: "Mujer Misteriosa"
    hide_textbox(10)

    # ══════════ FASE 4: EL RELATO DEL ENFRENTAMIENTO ══════════

    show "Graphics/Scenes/Intro/int5", 0, 0, fade: 30

    text_inline "Comenzó a devorar las almas que juró proteger. Acumuló poder en las sombras, deseando derrocarme.",
                speaker: "Gran Espíritu"
    text_inline "Junto a mis otros hijos, las Fuerzas de la Naturaleza, logramos doblegarlo. Lo despojamos de su poder, reduciéndolo a un simple susurro en la oscuridad.",
                speaker: "Gran Espíritu"
    hide_textbox(10)

    # ══════════ FASE 5: LA DEFENSA DE LA TRADICIÓN ══════════

    show "Graphics/Scenes/Intro/int9", 0, 0, fade: 25

    text_inline "Y tras esa batalla, viendo que la codicia persistía, nos diste la espalda, Gran Espíritu.",
                speaker: "Mujer Misteriosa"
    text_inline "Pero te equivocaste al juzgarnos a todos. Aún hay quienes sacrificaríamos nuestra humanidad entera solo para ver a nuestras familias y a nuestra gente vivir en paz.",
                speaker: "Mujer Misteriosa"
    text_inline "Aun así... los ecos en la tierra no mienten. El Guía está recuperando su fuerza. Si resurge, sumirá a nuestra región... y pronto al mundo entero... en un caos sin retorno.",
                speaker: "Mujer Misteriosa"
    hide_textbox(10)

    # ══════════ FASE 6: LA REVELACIÓN DEL RECEPTÁCULO ══════════
    
    show "Graphics/Scenes/Intro/int1", Graphics.width / 2, Graphics.height / 2, fade: 25, origin: :center
    
    text_inline "Por eso te hemos invocado a ti, Ente Dorado.\nUn alma forastera de este mundo e inmune a su hambre devoradora. Pero no puedes caminar sobre la tierra sin un receptáculo.",
                speaker: "Gran Espíritu"
    hide_textbox(10)

    float_sprite "Graphics/Scenes/Intro/FloatSolen96x96perFrame",
                 96, 96, 6,
                 Graphics.width / 2 - 48, -96,
                 end_y: 160, speed: 0.7, fps: 6, fade: 25, bg: true, glow: true, ghost_interval: 2
    wait 400

    text_inline "Observa a este muchacho. Un corazón mortal, pero forjado con una determinación inusual frente a la oscuridad que se avecina.",
                speaker: "Mujer Misteriosa"
    text_inline "Él entiende lo que está en juego. En su sueño profundo, su mente aguarda en perfecta calma, lista para recibirte.",
                speaker: "Mujer Misteriosa"
    hide_textbox(10)
    text_inline "Al abrir las puertas de su alma sin resistencia, el vínculo será perfecto. Él te cederá su cuerpo material, y tú serás la fuerza que lo impulse frente a la catástrofe.",
                speaker: "Gran Espíritu"
    hide_textbox(10)

    # ══════════ FASE 7: EL PACTO Y NOMBRAMIENTO ══════════

    text_inline "Su nombre es Solen.\nDime, ente que observas desde más allá del velo... ¿Deseas mantener el nombre que su familia le dio, o le otorgarás uno nuevo para sellar este pacto?",
                speaker: "Mujer Misteriosa"

    hide_textbox(10)
    fade_to_black 15
    @float_anim[:sprite].visible = false if @float_anim
    @float_anim[:glow].visible = false if @float_anim && @float_anim[:glow]
    @sprites[:float_bg]&.dispose
    @sprites[:float_bg] = nil
    player_name = name_input(default: "Solen", min: 1, max: 12)
    @float_anim[:sprite].visible = true if @float_anim
    @float_anim[:glow].visible = true if @float_anim && @float_anim[:glow]
    wait 60

    # ══════════ FASE 8: EL PACTO FORJADO ══════════

    hide_all
    @sprites[:black].opacity = 255
    @sprites[:float_bg] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites[:float_bg].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    @sprites[:float_bg].z = SceneEngine::Settings::LAYER_IMG + 100
    start_aura "Graphics/Scenes/Intro/AuraParticle", 12, 12, count: 12, range_x: 35, range_y: 70, duration: 90
    fade_from_black 25

    text_inline "El pacto está forjado en la quietud de la noche. Mi hijo renegado aguarda en las sombras, reuniendo almas para su venganza. Demuéstrame, {1}, que mi desprecio por la humanidad fue un error.",
                speaker: "Gran Espíritu", format_args: [player_name]
    text_inline "Que la vida vuelva a florecer bajo tus pasos. Desciende, {1}. Entra en su sueño.",
                speaker: "Mujer Misteriosa", format_args: [player_name]

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