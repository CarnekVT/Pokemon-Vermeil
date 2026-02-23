#===============================================================================
# [VERMEIL] BattleAnimations - Heavy Smasher Punches
# Includes: Hammer Arm, Ice Hammer, Crabhammer, Dynamic Punch, Mega Punch
# Fixes: Dynamic Punch target now has coherent horizontal knockback instead 
# of random shaking, and uses "Anim/PRSFX- Focus Punch2" SFX.
#===============================================================================

class Battle::Scene::Animation::VermeilHeavyPunches < Battle::Scene::Animation
  def initialize(sprites, viewport, user, target, move_id)
    @user = user; @target = target; @move_id = move_id
    super(sprites, viewport)
  end

  def apply_pras_frame(sprite, path, col, row, time = 0, fw = 192, fh = 192)
    resolved = pbResolveBitmap(path); return if !resolved
    sprite.setSrc(time, col * fw, row * fh); sprite.setSrcSize(time, fw, fh)
    if time == 0 && (raw = @pictureSprites.last) && raw.respond_to?(:src_rect) && raw.src_rect
      raw.src_rect.set(col * fw, row * fh, fw, fh)
    end
  end

  def create_battler_clone(original_sprite)
    clone = Sprite.new(@viewport); clone.bitmap = original_sprite.bitmap
    if original_sprite.respond_to?(:src_rect) && original_sprite.src_rect
      clone.src_rect.set(original_sprite.src_rect.x, original_sprite.src_rect.y, original_sprite.src_rect.width, original_sprite.src_rect.height)
    end
    clone.ox = original_sprite.ox; clone.oy = original_sprite.oy; clone.x = original_sprite.x; clone.y = original_sprite.y
    clone.zoom_x = original_sprite.zoom_x; clone.zoom_y = original_sprite.zoom_y; clone.mirror = original_sprite.mirror
    @tempSprites << clone; return clone
  end

  def make_black_sprite
    bmp = Bitmap.new(Graphics.width, Graphics.height)
    bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    s = Sprite.new(@viewport); s.bitmap = bmp
    @tempSprites << s; s
  end

  def createProcesses
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    target_z = (ts.z rescue 300) + 10
    user_z   = target_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y

    @end_frame = 45

    # ASSETS COMUNES
    punches = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
    spark   = "Graphics/Animations/PRAS- Strike.png"

    case @move_id
    when :HAMMERARM, :ICEHAMMER
      # 🔨 MACHADA Y MARTILLO HIELO (Salto Vertical Físico y Realista)
      t_imp = 8 
      
      # Salto parabólico (Sube y cae con fuerza)
      up.setSE(0, "Anim/Wind1", 100, 80)
      up.moveXY(0, 4, orig_ux, orig_uy - 50) # Sube rápido en 4 frames
      up.moveXY(4, 4, orig_ux, orig_uy)      # Cae aplastando en 4 frames (Llega justo al impacto)
      
      if @move_id == :ICEHAMMER
        up.setTone(0, Tone.new(-50, 100, 255, 100))
        punch_col = 1
        punch_tone = Tone.new(-50, 150, 255, 100)
        snd_impact = "Anim/Ice1"
        hit_color = Color.new(0, 200, 255, 255)
      else
        up.setTone(0, Tone.new(100, 50, 0, 50))
        punch_col = 0
        punch_tone = Tone.new(200, 80, 0, 0)
        snd_impact = "Anim/PRSFX- Focus Punch2"
        hit_color = Color.new(255, 100, 0, 200)
      end
      
      # El puño acompaña la caída
      if pbResolveBitmap(punches)
        fist = addNewSprite(i_x, i_y - 200, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, punch_col, 0, 0)
        fist.setTone(0, punch_tone); fist.setAngle(0, f_dir == 1 ? -90 : 90)
        fist.setVisible(0, false); fist.setVisible(t_imp - 2, true); fist.setZoom(0, 250)
        fist.moveXY(t_imp - 2, 2, i_x, i_y + 30) 
        fist.moveOpacity(t_imp + 4, 4, 0)
      end

      # Impacto
      tp.setSE(t_imp, snd_impact, 100, 80)
      tp.moveColor(t_imp, 2, hit_color); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      
      tp.moveZoomXY(t_imp, 2, 140, 60); tp.moveXY(t_imp, 2, orig_tx, orig_ty + 30)
      tp.moveZoomXY(t_imp + 6, 6, 100, 100); tp.moveXY(t_imp + 6, 6, orig_tx, orig_ty)
      10.times { |i| tp.moveDelta(t_imp + i, 1, 0, (i.even? ? 15 : -15)) }

      # Partículas de polvo/hielo
      if pbResolveBitmap(spark)
        8.times do |i|
          sp = addNewSprite(i_x, i_y + 30, spark, PictureOrigin::CENTER); sp.setZ(0, target_z + 16)
          apply_pras_frame(sp, spark, rand(3), 0, 0); sp.setBlendType(0, 1)
          sp.setTone(0, @move_id == :ICEHAMMER ? Tone.new(-100, 100, 255, 0) : Tone.new(150, 100, 50, 0))
          sp.setVisible(0, false); sp.setVisible(t_imp, true); sp.setZoom(0, 120 + rand(50))
          sp.moveXY(t_imp, 6 + rand(4), i_x + (rand(200)-100), i_y + 40 - rand(120))
          sp.moveOpacity(t_imp + 6, 4, 0)
        end
      end
      
      # Restaurar tono al final
      up.setTone(t_imp + 12, Tone.new(0,0,0,0))

    when :CRABHAMMER
      # 🦀 MARTILLAZO (Retroceso + Paso firme hacia adelante)
      t_imp = 12
      splash_asset = "Graphics/BattleParticlesAnimations/WaterSplashShot"
      drops_asset  = "Graphics/BattleParticlesAnimations/Bubbles-Drops"

      # Vuelo (Se echa para atrás)
      up.setSE(0, "Anim/Wind1", 80, 90)
      up.moveXY(0, 6, orig_ux - (20 * f_dir), orig_uy)
      up.setTone(6, Tone.new(0, 50, 200, 80))
      
      # Lunge controlado (Paso hacia adelante para pegar)
      up.moveXY(8, 4, orig_ux + (10 * f_dir), orig_uy)

      # Placeholder: Aquí cargaremos tu imagen de Tenaza cuando la tengas
      tp.setSE(t_imp, "Anim/Water2", 100, 70) 
      tp.moveZoomXY(t_imp, 2, 130, 70); tp.moveXY(t_imp, 2, orig_tx, orig_ty + 25)
      tp.moveZoomXY(t_imp + 4, 6, 100, 100); tp.moveXY(t_imp + 4, 6, orig_tx, orig_ty)
      8.times { |i| tp.moveDelta(t_imp + i, 1, 0, (i.even? ? 12 : -12)) }

      # Pilar de agua
      if pbResolveBitmap(splash_asset)
        splash = addNewSprite(i_x, i_y + 30, splash_asset, PictureOrigin::CENTER); splash.setZ(0, target_z + 20)
        apply_pras_frame(splash, splash_asset, 0, 0, 0, 64, 64)
        5.times { |f_idx| apply_pras_frame(splash, splash_asset, f_idx, 0, t_imp + (f_idx * 2), 64, 64) }
        splash.setBlendType(0, 1); splash.setVisible(0, false); splash.setVisible(t_imp, true)
        splash.setZoomXY(0, 150, 300) 
        splash.moveZoomXY(t_imp, 8, 250, 400); splash.moveOpacity(t_imp + 8, 4, 0)
      end
      
      # Regreso a su sitio
      up.setTone(t_imp + 15, Tone.new(0,0,0,0))
      up.moveXY(t_imp + 15, 6, orig_ux, orig_uy)

    when :DYNAMICPUNCH
      # 🌀 PUÑO DINÁMICO (Vibe B2W2 - Focus Punch + Impacto Pesado Horizontal)
      t_imp = 16
      
      # Fondo Oscuro (Focus Punch vibe)
      bg = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg.setZ(0, target_z - 5)
      bg.setOpacity(0, 0)
      bg.moveOpacity(0, 6, 180) 
      
      # Carga (El usuario vibra y brilla)
      up.setSE(0, "Anim/Wind2", 100, 120)
      up.moveXY(0, 4, orig_ux - (15 * f_dir), orig_uy)
      up.setTone(0, Tone.new(150, 50, 0, 100))
      # Vibración de poder
      4.times { |i| up.moveDelta(4 + i*2, 2, (i.even? ? 4 : -4) * f_dir, 0) } 
      
      # Dash de impacto
      up.moveXY(12, 4, orig_ux + (15 * f_dir), orig_uy)

      # Puño incandescente gigante
      if pbResolveBitmap(punches)
        fist = addNewSprite(orig_ux + (20 * f_dir), i_y, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(255, 100, 50, 0)); fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(12, true); fist.setZoom(0, 250)
        fist.moveXY(12, 4, i_x, i_y)
        fist.moveOpacity(t_imp + 2, 4, 0)
      end

      # Impacto brutal y sonido (SE cambiado según tu petición)
      tp.setSE(t_imp, "Anim/PRSFX- Focus Punch2", 100, 100)
      tp.setSE(t_imp + 2, "Anim/Paralyze3", 100, 120) # Sonido que denota la confusión
      tp.moveColor(t_imp, 2, Color.new(255, 150, 50, 255)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      
      # Explosión masiva naranja/amarilla
      if pbResolveBitmap(spark)
        # Núcleo de la explosión
        sp = addNewSprite(i_x, i_y, spark, PictureOrigin::CENTER); sp.setZ(0, target_z + 16)
        apply_pras_frame(sp, spark, 0, 0, 0); sp.setBlendType(0, 1)
        sp.setTone(0, Tone.new(255, 150, 50, 0))
        sp.setVisible(0, false); sp.setVisible(t_imp, true)
        sp.setZoom(0, 100); sp.moveZoom(t_imp, 6, 400); sp.moveOpacity(t_imp + 4, 6, 0)
        
        # Chispas caóticas girando
        6.times do |i|
          sp2 = addNewSprite(i_x, i_y, spark, PictureOrigin::CENTER); sp2.setZ(0, target_z + 17)
          apply_pras_frame(sp2, spark, rand(3), 0, 0); sp2.setBlendType(0, 1)
          sp2.setTone(0, Tone.new(255, 200, 100, 0))
          sp2.setVisible(0, false); sp2.setVisible(t_imp, true)
          sp2.setZoom(0, 50); sp2.moveZoom(t_imp, 8, 200 + rand(100))
          sp2.moveAngle(t_imp, 8, rand(360) * (i.even? ? 1 : -1))
          sp2.moveOpacity(t_imp + 4, 4, 0)
        end
      end

      # Regresa la luz
      bg.moveOpacity(t_imp + 8, 8, 0) 
      
      # REACCIÓN COHERENTE: Empuje horizontal fuerte y retroceso vibratorio
      tp.moveXY(t_imp, 2, orig_tx + (60 * f_dir), orig_ty) 
      tp.moveXY(t_imp + 2, 8, orig_tx, orig_ty)
      8.times { |i| tp.moveDelta(t_imp + i, 1, (i.even? ? 15 : -15) * f_dir, 0) }
      
      # Regreso del usuario
      up.setTone(t_imp + 15, Tone.new(0,0,0,0))
      up.moveXY(t_imp + 15, 6, orig_ux, orig_uy)

    when :MEGAPUNCH
      # 🥊 MEGAPUÑO (Straight punch devastador puro)
      t_imp = 12
      
      up.setSE(0, "Anim/Wind2", 100, 100)
      up.moveXY(0, 8, orig_ux - (40 * f_dir), orig_uy)
      up.setTone(8, Tone.new(200, 200, 200, 100))
      
      up.moveXY(8, 4, orig_ux + (30 * f_dir), orig_uy)

      if pbResolveBitmap(punches)
        fist = addNewSprite(orig_ux + (20 * f_dir), i_y, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(255, 255, 255, 0)); fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(8, true); fist.setZoom(0, 250)
        fist.moveXY(8, 4, i_x + (40 * f_dir), i_y)
        fist.moveOpacity(t_imp + 4, 4, 0)
      end

      tp.setSE(t_imp, "Anim/PRSFX- Focus Punch2", 100, 90)
      tp.moveColor(t_imp, 2, Color.new(255, 255, 255, 255)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      
      tp.moveXY(t_imp, 2, orig_tx + (80 * f_dir), orig_ty) 
      tp.moveXY(t_imp + 2, 8, orig_tx, orig_ty)
      10.times { |i| tp.moveDelta(t_imp + i, 1, (i.even? ? 10 : -10) * f_dir, 0) }

      up.setTone(t_imp + 10, Tone.new(0,0,0,0))
      up.moveXY(t_imp + 10, 6, orig_ux, orig_uy)
    end

    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end