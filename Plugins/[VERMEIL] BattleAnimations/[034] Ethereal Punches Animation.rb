#===============================================================================
# [VERMEIL] BattleAnimations - Ethereal & Dark Punches
# Includes: Shadow Punch, Rage Fist, Wicked Blow, Sucker Punch
# Focus: Ghostly energy, sudden shadow strikes, and furious dark impacts.
#===============================================================================

class Battle::Scene::Animation::VermeilEtherealPunches < Battle::Scene::Animation
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

    punches  = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
    spark    = "Graphics/Animations/PRAS- Strike.png"
    
    # Assets PRAS requeridos
    psycho   = "Graphics/Animations/PRAS- Psycho Boost.png"
    sp_thief = "Graphics/Animations/PRAS- Spectral Thief.png"
    sinister = "Graphics/Animations/PRAS- Sinister Arrow Raid.png"
    tantrum  = "Graphics/Animations/PRAS- Stomping Tantrum.png"
    void_bg  = "Graphics/Animations/PRAS- Dark Void BG.png"

    case @move_id
    when :SHADOWPUNCH
      # 👻 SHADOW PUNCH (Hundimiento en las sombras y golpe horizontal frontal)
      t_imp = 12
      
      up.setSE(0, "Anim/PRSFX- Shadow Sneak2", 100, 100)
      up.moveTone(0, 4, Tone.new(100, -50, 150, 120))
      
      # Fade/Sink limpio
      up.moveXY(0, 6, orig_ux, orig_uy + 30)
      up.moveOpacity(0, 6, 0)
      
      # Reaparece para el golpe
      up.setXY(t_imp - 2, orig_ux + (80 * f_dir), orig_uy)
      up.moveOpacity(t_imp - 2, 2, 255)
      
      # Puño sale directamente hacia el rival (Ya no cae del cielo)
      if pbResolveBitmap(punches)
        fist = addNewSprite(i_x - (80 * f_dir), i_y + 10, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(100, -100, 200, 150)); fist.setAngle(0, f_dir == 1 ? 0 : 180) # Ángulo recto
        fist.setVisible(0, false); fist.setVisible(t_imp - 4, true)
        fist.setZoom(0, 50) 
        fist.moveZoom(t_imp - 4, 4, 150)
        fist.moveXY(t_imp - 4, 4, i_x, i_y)
        fist.moveOpacity(t_imp + 2, 4, 0)
      end

      tp.setSE(t_imp, "Anim/PRSFX- Shadow Punch1", 100, 110)
      tp.moveColor(t_imp, 2, Color.new(150, 0, 255, 200)); tp.moveColor(t_imp + 6, 6, Color.new(0, 0, 0, 0))
      
      # Explosión Espectral
      if pbResolveBitmap(psycho)
        boom = addNewSprite(i_x, i_y, psycho, PictureOrigin::CENTER); boom.setZ(0, target_z + 16)
        apply_pras_frame(boom, psycho, 1, 1, 0)
        3.times { |k| apply_pras_frame(boom, psycho, k+1, 1, t_imp + (k*2)) }
        boom.setBlendType(0, 1); boom.setTone(0, Tone.new(50, -50, 150, 0))
        boom.setVisible(0, false); boom.setVisible(t_imp, true)
        boom.setZoom(0, 100); boom.moveZoom(t_imp, 6, 250)
        boom.moveOpacity(t_imp + 4, 4, 0)
      end

      tp.moveXY(t_imp, 2, orig_tx + (40 * f_dir), orig_ty)
      8.times { |i| tp.moveDelta(t_imp + 2 + i, 1, (i.even? ? 12 : -12) * f_dir, 0) }
      tp.moveXY(t_imp + 10, 4, orig_tx, orig_ty)
      
      up.moveOpacity(t_imp + 4, 3, 0)
      up.setXY(t_imp + 7, orig_ux, orig_uy)
      up.moveTone(t_imp + 7, 1, Tone.new(0, 0, 0, 0))
      up.moveOpacity(t_imp + 8, 4, 255)

    when :RAGEFIST
      # RAGE FIST (Vena de Enojo + Carga de Partículas + Púas)
      t_imp = 20
      
      # 1. Signo de Enojo pop-up
      if pbResolveBitmap(tantrum)
        anger = addNewSprite(orig_ux + (25 * f_dir), orig_uy - uh - 15, tantrum, PictureOrigin::CENTER)
        anger.setZ(0, user_z + 10); anger.setZoom(0, 0)
        apply_pras_frame(anger, tantrum, 1, 0, 0) 
        anger.moveZoom(0, 4, 150); anger.moveZoom(4, 3, 100)
        anger.moveOpacity(10, 4, 0)
      end

      # 2. Fase de Ira y Absorción (Mismas partículas que Wicked Blow, pero moradas)
      up.setSE(0, "Anim/PRSFX- Screech", 100, 80)
      up.moveTone(0, 10, Tone.new(100, -100, 200, 150))
      16.times { |i| up.moveDelta(i, 1, (i.even? ? 8 : -8), 0) }
      
      if pbResolveBitmap(sp_thief)
        12.times do |i|
          st_x = orig_ux + (rand(200) - 100) * f_dir
          st_y = orig_uy - 100 + (rand(150) - 75)
          au = addNewSprite(st_x, st_y, sp_thief, PictureOrigin::CENTER)
          au.setZ(0, user_z + 5)
          apply_pras_frame(au, sp_thief, rand(1..4), 0, 0)
          au.setTone(0, Tone.new(150, -50, 255, 100)) # Tinte púrpura para Rage Fist
          au.setVisible(0, false); au.setVisible(i/2, true)
          au.setZoom(0, 100); au.moveZoom(i/2, 6, 20)
          au.moveXY(i/2, 6, orig_ux, orig_uy - (uh/2))
          au.moveOpacity(i/2 + 4, 2, 0)
        end
      end
      
      # 3. Dash Furioso
      up.setSE(16, "Anim/Wind2", 100, 100)
      up.moveXY(16, 4, orig_ux + (25 * f_dir), orig_uy)

      if pbResolveBitmap(punches)
        fist = addNewSprite(orig_ux + (25 * f_dir), i_y, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(120, -50, 255, 100)); fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(16, true); fist.setZoom(0, 200)
        fist.moveXY(16, 4, i_x, i_y); fist.moveOpacity(t_imp + 4, 4, 0)
      end

      tp.setSE(t_imp, "Anim/PRSFX- Focus Punch2", 100, 80)
      tp.moveColor(t_imp, 2, Color.new(180, 50, 255, 255)); tp.moveColor(t_imp + 6, 6, Color.new(0, 0, 0, 0))
      
      # Explosión de Púas en el impacto
      if pbResolveBitmap(sinister)
        10.times do |i|
          sm = addNewSprite(i_x, i_y, sinister, PictureOrigin::CENTER); sm.setZ(0, target_z + 16)
          apply_pras_frame(sm, sinister, rand(2..3), 0, 0) 
          sm.setTone(0, Tone.new(150, -50, 255, 100)) # Púas púrpuras
          sm.setVisible(0, false); sm.setVisible(t_imp, true)
          # REDUCIDO: Ahora inician más pequeñas y no se inflan tanto
          sm.setZoom(0, 40 + rand(30)); sm.moveZoom(t_imp, 6, 120 + rand(50))
          sm.moveXY(t_imp, 6 + rand(2), i_x + (rand(160)-80), i_y + (rand(160)-80))
          sm.moveOpacity(t_imp + 4, 4, 0)
        end
      end
      
      tp.moveXY(t_imp, 2, orig_tx + (60 * f_dir), orig_ty) 
      8.times { |i| tp.moveDelta(t_imp + 2 + i, 1, (i.even? ? 14 : -14) * f_dir, 0) }
      tp.moveXY(t_imp + 10, 4, orig_tx, orig_ty)

      up.moveTone(t_imp + 10, 6, Tone.new(0,0,0,0))
      up.moveXY(t_imp + 10, 6, orig_ux, orig_uy)

    when :WICKEDBLOW
      # WICKED BLOW (Fondo Dark Void + Absorbe Humo + Cero Destello Negro)
      t_imp = 18
      
      if pbResolveBitmap(void_bg)
        bg = addNewSprite(Graphics.width/2, Graphics.height/2, void_bg, PictureOrigin::CENTER)
        bg.setZ(0, target_z - 5); bg.setOpacity(0, 0)
        bg.moveOpacity(0, 8, 255) 
      end
      
      up.setSE(0, "Anim/Wind1", 100, 80)
      up.moveXY(0, 6, orig_ux - (15 * f_dir), orig_uy)
      up.moveTone(0, 6, Tone.new(-150, -150, -150, 100))
      
      if pbResolveBitmap(sp_thief)
        12.times do |i|
          st_x = orig_ux + (rand(240) - 120) * f_dir
          st_y = orig_uy - 120 + (rand(150) - 75)
          au = addNewSprite(st_x, st_y, sp_thief, PictureOrigin::CENTER)
          au.setZ(0, user_z + 5)
          apply_pras_frame(au, sp_thief, rand(1..4), 0, 0)
          au.setVisible(0, false); au.setVisible(i/2, true)
          au.setZoom(0, 100); au.moveZoom(i/2, 6, 20)
          au.moveXY(i/2, 6, orig_ux, orig_uy - (uh/2))
          au.moveOpacity(i/2 + 4, 2, 0)
        end
      end
      
      up.setSE(14, "Anim/Wind2", 100, 120)
      up.moveXY(14, 4, orig_ux + (20 * f_dir), orig_uy)

      if pbResolveBitmap(punches)
        fist = addNewSprite(orig_ux + (20 * f_dir), i_y, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(-255, -255, -255, 255)); fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(14, true); fist.setZoom(0, 220)
        fist.moveXY(14, 4, i_x, i_y); fist.moveOpacity(t_imp + 4, 4, 0)
      end

      # Impacto (Sin flash de pantalla negro)
      tp.setSE(t_imp, "Anim/PRSFX- Focus Punch2", 100, 100)
      tp.setSE(t_imp + 2, "Anim/PRSFX- Pound", 100, 80)
      
      # Explosión de Púas Oscuras en el impacto
      if pbResolveBitmap(sinister)
        10.times do |i|
          sm = addNewSprite(i_x, i_y, sinister, PictureOrigin::CENTER); sm.setZ(0, target_z + 16)
          apply_pras_frame(sm, sinister, rand(2..3), 0, 0) 
          sm.setVisible(0, false); sm.setVisible(t_imp, true)
          # REDUCIDO: Zoom controlado para que parezcan cortes y no manchas
          sm.setZoom(0, 40 + rand(30)); sm.moveZoom(t_imp, 6, 120 + rand(50))
          sm.moveXY(t_imp, 6 + rand(2), i_x + (rand(160)-80), i_y + (rand(160)-80))
          sm.moveOpacity(t_imp + 4, 4, 0)
        end
      end

      tp.moveColor(t_imp, 2, Color.new(0, 0, 0, 255)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      
      tp.moveXY(t_imp, 2, orig_tx + (70 * f_dir), orig_ty) 
      8.times { |i| tp.moveDelta(t_imp + 2 + i, 1, (i.even? ? 15 : -15) * f_dir, 0) }
      tp.moveXY(t_imp + 10, 4, orig_tx, orig_ty)
      
      bg.moveOpacity(t_imp + 10, 6, 0) if bg
      up.moveTone(t_imp + 10, 6, Tone.new(0,0,0,0))
      up.moveXY(t_imp + 10, 6, orig_ux, orig_uy)

    when :SUCKERPUNCH
      # SUCKER PUNCH (Cámara 3D controlada para no tapar al Player)
      t_imp = 5
      @end_frame = 30
      
      tp.setSE(0, "Anim/Wind1", 80, 120)
      tp.moveXY(0, 3, orig_tx - (20 * f_dir), orig_ty) 
      
      up.setSE(0, "Anim/PRSFX- Shadow Sneak2", 100, 150)
      up.moveOpacity(0, 2, 0) 
      
      # Zoom y control de Z-Index
      zoom_target = (f_dir == 1) ? 66 : 150 

      # Si el oponente ataca, lo forzamos detrás del jugador
      if f_dir == -1 
        up.setZ(t_imp - 1, target_z - 5)
      end

      up.setXY(t_imp - 1, orig_tx - (60 * f_dir), orig_ty)
      up.setZoom(t_imp - 1, 100)
      up.moveZoom(t_imp - 1, 3, zoom_target)
      
      up.moveOpacity(t_imp - 1, 1, 255)
      up.setTone(t_imp - 1, Tone.new(-100, -100, -100, 100))

      if pbResolveBitmap(spark)
        sp = addNewSprite(orig_tx - (20 * f_dir), orig_ty - th, spark, PictureOrigin::CENTER); sp.setZ(0, target_z + 16)
        apply_pras_frame(sp, spark, 2, 0, 0); sp.setBlendType(0, 1)
        sp.setTone(0, Tone.new(100, -50, 150, 0)); sp.setAngle(0, f_dir == 1 ? 45 : 135)
        sp.setVisible(0, false); sp.setVisible(t_imp, true)
        sp.setZoomXY(0, 20, 200); sp.moveZoomXY(t_imp, 4, 200, 20); sp.moveOpacity(t_imp + 2, 4, 0)
      end

      tp.setSE(t_imp, "Anim/PRSFX- Pound", 100, 120)
      tp.moveColor(t_imp, 2, Color.new(50, 0, 100, 200)); tp.moveColor(t_imp + 4, 4, Color.new(0, 0, 0, 0))
      
      tp.moveXY(t_imp, 2, orig_tx + (30 * f_dir), orig_ty); tp.moveXY(t_imp + 2, 4, orig_tx, orig_ty)
      
      # Reset
      up.moveOpacity(t_imp + 6, 2, 0)
      up.setXY(t_imp + 8, orig_ux, orig_uy)
      up.setZoom(t_imp + 8, 100)
      up.setTone(t_imp + 8, Tone.new(0, 0, 0, 0))
      up.setSE(t_imp + 10, "Anim/Wind1", 80, 150)
      up.moveOpacity(t_imp + 10, 4, 255)
    end

    # FAILSAFE ABSOLUTO
    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setZoom(@end_frame - 1, 100)
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)

    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end