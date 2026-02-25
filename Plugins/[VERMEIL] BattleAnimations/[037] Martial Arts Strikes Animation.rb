#===============================================================================
# [VERMEIL] BattleAnimations - Martial Arts Strikes
# Includes: Close Combat, Brick Break, Cross Chop, Arm Thrust
# Concept: Heavy martial arts choreography using PRAS- All Out Pummeling.
#===============================================================================

class Battle::Scene::Animation::VermeilFightingStrikes < Battle::Scene::Animation
  
  HANDLED_MOVES = [:CLOSECOMBAT, :BRICKBREAK, :CROSSCHOP, :ARMTHRUST]
  BEHAVIOR = :cinematic

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

    @end_frame = 40

    pummel = "Graphics/Animations/PRAS- All Out Pummeling.png"
    force_palm = "Graphics/Animations/PRAS- Force Palm.png"
    spark = "Graphics/Animations/PRAS- Strike.png"

    case @move_id
    when :CLOSECOMBAT
      # 🥋 A BOCAJARRO (Ráfaga Absoluta de 12-15 golpes al azar + Remate)
      t_start = 4
      hits = 12
      @end_frame = t_start + (hits * 2) + 15
      
      up.setSE(0, "Anim/Wind2", 100, 100)
      up.moveXY(0, t_start, orig_ux + (30 * f_dir), orig_uy)

      if pbResolveBitmap(pummel)
        hits.times do |i|
          t_h = t_start + (i * 2) 
          
          up.setSE(t_h - 1, "Anim/Wind1", 90, 120 + rand(40))
          up.moveDelta(t_h - 1, 1, 6 * f_dir, 0); up.moveDelta(t_h, 1, -6 * f_dir, 0)

          r_x = (rand(60) - 30); r_y = (rand(60) - 30)
          
          # Elegimos al azar un tipo de golpe (Puño, Palma, Pie)
          col = rand(3); row = rand(4)
          
          hit_sp = addNewSprite(i_x - (50 * f_dir) + r_x, i_y + r_y, pummel, PictureOrigin::CENTER)
          hit_sp.setZ(0, target_z + 15 + i)
          apply_pras_frame(hit_sp, pummel, col, row, 0)
          hit_sp.setAngle(0, f_dir == 1 ? (rand(40)-20) : 180 + (rand(40)-20))
          hit_sp.setVisible(0, false); hit_sp.setVisible(t_h, true); hit_sp.setZoom(0, 100 + rand(40))
          hit_sp.moveXY(t_h, 2, i_x + r_x, i_y + r_y)
          hit_sp.moveOpacity(t_h + 2, 2, 0)

          tp.setSE(t_h, "Anim/Hit1", 100, 90 + rand(30))
          tp.moveColor(t_h, 1, Color.new(255, 255, 255, 150)); tp.moveColor(t_h + 1, 1, Color.new(0,0,0,0))
          tp.moveDelta(t_h, 1, (i.even? ? 8 : -8), 0)
        end
        
        # REMATE FINAL (Golpe masivo)
        t_fin = t_start + (hits * 2) + 2
        up.setSE(t_fin - 2, "Anim/Earth1", 100, 100)
        up.moveXY(t_fin - 2, 2, orig_ux + (40 * f_dir), orig_uy)
        
        fin = addNewSprite(i_x - (60 * f_dir), i_y, pummel, PictureOrigin::CENTER); fin.setZ(0, target_z + 30)
        apply_pras_frame(fin, pummel, 1, 0, 0) # Puño central
        fin.setAngle(0, f_dir == 1 ? 0 : 180); fin.setVisible(0, false); fin.setVisible(t_fin, true)
        fin.setZoom(0, 250); fin.moveXY(t_fin, 2, i_x, i_y); fin.moveOpacity(t_fin + 4, 4, 0)
        
        tp.setSE(t_fin, "Anim/PRSFX- Focus Punch2", 100, 100)
        tp.moveColor(t_fin, 3, Color.new(255, 150, 50, 255)); tp.moveColor(t_fin + 6, 6, Color.new(0,0,0,0))
        tp.moveXY(t_fin, 2, orig_tx + (60 * f_dir), orig_ty) 
        8.times { |i| tp.moveDelta(t_fin + i, 1, (i.even? ? 15 : -15) * f_dir, 0) }
        tp.moveXY(t_fin + 8, 4, orig_tx, orig_ty)
      end
      up.moveXY(@end_frame - 6, 4, orig_ux, orig_uy)

    when :BRICKBREAK
      # 🧱 DEMOLICIÓN (Mano de karate cayendo desde arriba con fuerza)
      t_imp = 8
      
      up.setSE(0, "Anim/Wind1", 100, 80)
      up.moveXY(0, 4, orig_ux + (10 * f_dir), orig_uy - 40) 
      up.moveXY(4, 4, orig_ux + (15 * f_dir), orig_uy)      
      
      if pbResolveBitmap(pummel)
        chop = addNewSprite(i_x, i_y - 150, pummel, PictureOrigin::CENTER); chop.setZ(0, target_z + 15)
        apply_pras_frame(chop, pummel, 0, 4, 0) # Fila 4, Col 0 es la mano de Karate
        chop.setTone(0, Tone.new(255, 100, 0, 0)) # Rojo ardiente
        chop.setAngle(0, f_dir == 1 ? -90 : 90)
        chop.setVisible(0, false); chop.setVisible(t_imp - 2, true); chop.setZoom(0, 200)
        chop.moveXY(t_imp - 2, 2, i_x, i_y + 20) 
        chop.moveOpacity(t_imp + 4, 4, 0)
      end

      # Impacto rompe-pantallas
      tp.setSE(t_imp, "Anim/Super Damage", 100, 100)
      tp.moveColor(t_imp, 2, Color.new(255, 200, 50, 200)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      
      tp.moveZoomXY(t_imp, 2, 120, 80); tp.moveXY(t_imp, 2, orig_tx, orig_ty + 20)
      tp.moveZoomXY(t_imp + 6, 6, 100, 100); tp.moveXY(t_imp + 6, 6, orig_tx, orig_ty)
      10.times { |i| tp.moveDelta(t_imp + i, 1, 0, (i.even? ? 12 : -12)) }
      
      up.moveXY(t_imp + 12, 6, orig_ux, orig_uy)

    when :CROSSCHOP
      # ❌ TAJO CRUZADO
      t_imp = 6
      
      up.setSE(0, "Anim/Wind2", 100, 110)
      up.moveXY(0, t_imp, orig_ux + (20 * f_dir), orig_uy)

      if pbResolveBitmap(pummel)
        # Tajo 1 (Ángulo de 45 grados)
        c1 = addNewSprite(i_x - (80 * f_dir), i_y - 80, pummel, PictureOrigin::CENTER); c1.setZ(0, target_z + 15)
        apply_pras_frame(c1, pummel, 0, 4, 0)
        c1.setTone(0, Tone.new(255, 50, 0, 0)); c1.setAngle(0, f_dir == 1 ? -45 : 135)
        c1.setVisible(0, false); c1.setVisible(t_imp - 2, true); c1.setZoom(0, 180)
        c1.moveXY(t_imp - 2, 3, i_x + (40 * f_dir), i_y + 40); c1.moveOpacity(t_imp + 2, 3, 0)

        # Tajo 2 (Ángulo de 135 grados cruzando)
        c2 = addNewSprite(i_x - (80 * f_dir), i_y + 80, pummel, PictureOrigin::CENTER); c2.setZ(0, target_z + 16)
        apply_pras_frame(c2, pummel, 0, 4, 0)
        c2.setTone(0, Tone.new(255, 50, 0, 0)); c2.setAngle(0, f_dir == 1 ? -135 : 45)
        c2.setVisible(0, false); c2.setVisible(t_imp - 2, true); c2.setZoom(0, 180)
        c2.moveXY(t_imp - 2, 3, i_x + (40 * f_dir), i_y - 40); c2.moveOpacity(t_imp + 2, 3, 0)
      end

      tp.setSE(t_imp, "Anim/Hit2", 100, 90)
      tp.moveColor(t_imp, 2, Color.new(255, 100, 50, 200)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      tp.moveXY(t_imp, 2, orig_tx + (30 * f_dir), orig_ty); tp.moveXY(t_imp + 2, 6, orig_tx, orig_ty)
      
      # Chispa en X si existe la sheet de Spark
      if pbResolveBitmap(spark)
        sp = addNewSprite(i_x, i_y, spark, PictureOrigin::CENTER); sp.setZ(0, target_z + 17)
        apply_pras_frame(sp, spark, 3, 0, 0) # Estrella de impacto roja
        sp.setVisible(0, false); sp.setVisible(t_imp, true); sp.setZoom(0, 50)
        sp.moveZoom(t_imp, 4, 250); sp.moveOpacity(t_imp + 2, 4, 0)
      end

      up.moveXY(t_imp + 10, 6, orig_ux, orig_uy)

    when :ARMTHRUST
      # ✋ EMPUJÓN (Loopable rápido por el Multi-Hit engine)
      @end_frame = 20
      t_imp = 4

      up.setSE(0, "Anim/Wind1", 100, 130)
      up.moveDelta(0, 2, 10 * f_dir, 0); up.moveDelta(2, 2, -10 * f_dir, 0)

      if pbResolveBitmap(force_palm)
        palm = addNewSprite(orig_ux + (30 * f_dir), i_y, force_palm, PictureOrigin::CENTER)
        palm.setZ(0, target_z + 15)
        apply_pras_frame(palm, force_palm, 0, 0, 0) # Palma verde
        palm.setAngle(0, f_dir == 1 ? 0 : 180)
        palm.setVisible(0, false); palm.setVisible(2, true); palm.setZoom(0, 120)
        palm.moveXY(2, 2, i_x, i_y); palm.moveOpacity(t_imp, 2, 0)

        shock = addNewSprite(i_x, i_y, force_palm, PictureOrigin::CENTER)
        shock.setZ(0, target_z + 16)
        apply_pras_frame(shock, force_palm, 1, 0, 0) # Onda 1
        shock.setAngle(0, f_dir == 1 ? 0 : 180)
        shock.setVisible(0, false); shock.setVisible(t_imp, true); shock.setZoom(0, 100)
        
        # Animamos las ondas del Force Palm (Columnas 1, 2 y 3)
        3.times { |f| apply_pras_frame(shock, force_palm, f + 1, 0, t_imp + (f * 2)) }
        shock.moveOpacity(t_imp + 4, 3, 0)
      end

      tp.setSE(t_imp, "Anim/Hit1", 100, 110)
      tp.moveColor(t_imp, 2, Color.new(255, 255, 150, 200)); tp.moveColor(t_imp + 2, 3, Color.new(0,0,0,0))
      tp.moveDelta(t_imp, 1, 12 * f_dir, 0); tp.moveDelta(t_imp + 1, 2, -12 * f_dir, 0)
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end