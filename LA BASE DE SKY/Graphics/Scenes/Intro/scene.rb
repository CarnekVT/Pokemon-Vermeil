# encoding: utf-8
# Intro: "El Eco del Guía"
# Ajustar nombres de BGM/BGS/SE según los archivos de audio disponibles.

SceneEngine.play("Intro") do
  # ─── PRÓLOGO: Pantalla en negro ───
  # Sin BGM. Viento helado de fondo.
  # NOTA: necessitas un archivo de viento. Usa bgm (loop) o se (one-shot).
  # Opción A (loop): bgm "Intro/wind"   -> Audio/BGM/Intro_wind.ogg
  # Opción B (one-shot): se "Wind"      -> Audio/SE/Wind.ogg
  wait 30

  # ─── APARECE EL ENTE DORADO ───
  # int1.png: destello dorado pulsante en el centro
  show "int1", Graphics.width / 2, Graphics.height / 2, fade: 40, origin: :center

  dialog :l1
  wait 20

  dialog :l2
  wait 20

  # ─── APARECE LA GUARDIANA (lado izquierdo, luz verde) ───
  show "int2", 0, 0, fade: 30

  dialog :l3

  # ─── APARECE EL LEGENDARIO (centro) ───
  show "int5", 0, 0, fade: 30

  dialog :l4
  dialog :l5

  # ─── GUARDIANA RESPONDE ───
  show "int2", 0, 0, fade: 30

  dialog :l6
  dialog :l7
  dialog :l8

  # ─── NOMBRAMIENTO: BGM cambia a melodía melancólica ───
  show "int5", 0, 0, fade: 30
  # NOTA: necesitas Audio/BGM/Intro_melody.ogg
  # bgm "Intro_melody"

  dialog :l9

  # ─── SOLEN APARECE DURMIENDO ───
  show "int6", 0, 0, fade: 30

  dialog :l10
  dialog :l11
  dialog :l12
  dialog :l13

  # ─── INTERFAZ DE NOMBRE ───
  player_name = name_input(default: "Solen", min: 1, max: 12)

  # ─── CIERRE ───
  show "int5", 0, 0, fade: 20
  dialog :l14, format_args: [player_name]
  dialog :l15, format_args: [player_name]

  # ─── LA LUZ ENTRA EN SOLEN ───
  show "int8", 0, 0, fade: 30
  wait 40

  # ─── FLASH BLANCO Y CIERRE ───
  stop_bgm
  wait 10
  flash :white, 15
  wait 20
  to_white 20
  wait 10

  # Voz en off sobre blanco
  text_inline "Despierta.", speaker: "???", speed: :slow
  wait 30
end
