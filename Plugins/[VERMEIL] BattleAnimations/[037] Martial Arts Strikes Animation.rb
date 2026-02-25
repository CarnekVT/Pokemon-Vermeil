#===============================================================================
# [VERMEIL] BattleAnimations - Martial Arts Strikes
# Includes: Close Combat, Brick Break, Cross Chop, Arm Thrust
# Update: Cinematic Spotlight added for Close Combat (1v1 isolation).
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

    # Guardamos las Z originales para poder restaurarlas
    orig_tz = (ts.z rescue 300) + 10
    orig_uz = orig_tz + 40

    target_z = orig_tz
    user_z   = orig_uz

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y

    @end_frame = 40

    pummel = "Graphics/Animations/PRAS- All Out Pummeling.png"
    force_palm = "Graphics/Animations/PRAS- Force Palm.png"
    spark = "Graphics/Animations/PRAS- Strike.png"

    dist_x = (f_dir == 1) ? 50 : 100 
    dist_y = (f_dir == 1) ? 10 : -15 
    dash_x = orig_tx - (dist_x * f_dir)
    dash_y = orig_ty + dist_y
    zoom_target = (f_dir == 1) ? 75 : 130 

    case @move_id
    when :CLOSECOMBAT
      t_start = 4
      hits = 15
      
      # =========================================================================
      # AISLAMIENTO CINEMÁTICO: Elevamos a los luchadores por encima de la oscuridad
      # =========================================================================
      bg_z = 90000
      target_z = bg_z + 10
      user_z   = bg_z + 50
      
      up.setZ(0, user_z)
      tp.setZ(0, target_z)

      # El fondo oscuro tapa al resto del campo, pero NO a nuestro Target ni User
      bg = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg.setZ(0, bg_z); bg.setOpacity(0, 0); bg.moveOpacity(0, 4, 180)

      up.setZ(0, target_z - 5) if f_dir == -1 
      up.setSE(0, "Anim/Wind2", 100, 100)
      up.moveXY(0, t_start, dash_x, dash_y)
      up.moveZoom(0, t_start, zoom_target)

      if pbResolveBitmap(pummel)
        hits.times do |i|
          t_h = t_start + (i * 2) 
          
          up.setSE(t_h - 1, "Anim/Wind1", 90, 140 + rand(40))
          up.moveDelta(t_h - 1, 1, 8 * f_dir, 0); up.moveDelta(t_h, 1, -8 * f_dir, 0)

          r_x = (rand(80) - 40); r_y = (rand(80) - 40)
          col = rand(3); row = rand(4)
          
          hit_sp = addNewSprite(i_x - (60 * f_dir) + r_x, i_y + r_y, pummel, PictureOrigin::CENTER)
          hit_sp.setZ(0, target_z + 15 + i)
          apply_pras_frame(hit_sp, pummel, col, row, 0)
          hit_sp.setAngle(0, f_dir == 1 ? (rand(40)-20) : 180 + (rand(40)-20))
          hit_sp.setVisible(0, false); hit_sp.setVisible(t_h, true); hit_sp.setZoom(0, 120 + rand(40))
          hit_sp.moveXY(t_h, 2, i_x + r_x, i_y + r_y)
          hit_sp.moveOpacity(t_h + 2, 2, 0)

          tp.setSE(t_h, "Anim/Hit1", 100, 80 + rand(30))
          tp.moveColor(t_h, 1, Color.new(255, 255, 255, 150)); tp.moveColor(t_h + 1, 1, Color.new(0,0,0,0))
          tp.moveDelta(t_h, 1, (i.even? ? 10 : -10), (i.even? ? 5 : -5))
        end
        
        t_pause = t_start + (hits * 2) + 2
        t_fin = t_pause + 6 
        
        up.setSE(t_pause, "Anim/Earth1", 100, 80)
        up.moveXY(t_pause, 6, dash_x + (10 * f_dir), dash_y - 10) 
        
        up.moveXY(t_fin, 2, dash_x + (40 * f_dir), dash_y) 
        
        fin = addNewSprite(dash_x + (20 * f_dir), i_y, pummel, PictureOrigin::CENTER); fin.setZ(0, target_z + 30)
        apply_pras_frame(fin, pummel, 1, 0, 0) 
        fin.setAngle(0, f_dir == 1 ? 0 : 180); fin.setVisible(0, false); fin.setVisible(t_fin, true)
        fin.setZoom(0, 300); fin.moveXY(t_fin, 2, i_x + (20 * f_dir), i_y); fin.moveOpacity(t_fin + 6, 6, 0)
        
        tp.setSE(t_fin, "Anim/PRSFX- Focus Punch2", 100, 90)
        tp.setSE(t_fin + 2, "Anim/Super Damage", 100, 100)
        
        flash = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
        flash.setZ(0, 99999); flash.setTone(0, Tone.new(255, 255, 255, 0))
        flash.setOpacity(0, 0); flash.moveOpacity(t_fin, 1, 255); flash.moveOpacity(t_fin + 2, 8, 0)

        tp.moveColor(t_fin, 3, Color.new(255, 150, 50, 255)); tp.moveColor(t_fin + 8, 8, Color.new(0,0,0,0))
        tp.moveXY(t_fin, 2, orig_tx + (80 * f_dir), orig_ty) 
        10.times { |i| tp.moveDelta(t_fin + i, 1, (i.even? ? 18 : -18) * f_dir, 0) }
        tp.moveXY(t_fin + 10, 6, orig_tx, orig_ty)
        
        bg.moveOpacity(t_fin + 8, 10, 0)
        @end_frame = t_fin + 25
      end
      
      up.moveXY(@end_frame - 8, 6, orig_ux, orig_uy)
      up.moveZoom(@end_frame - 8, 6, 100)
      
      # Restauramos las Capas Z originales
      up.setZ(@end_frame - 8, orig_uz)
      tp.setZ(@end_frame - 8, orig_tz)

    when :BRICKBREAK
      t_imp = 10
      @end_frame = 45
      
      up.setZ(0, target_z - 5) if f_dir == -1
      up.setSE(0, "Anim/Wind1", 100, 80)
      up.moveXY(0, 6, dash_x - (20 * f_dir), dash_y - 80)
      up.moveZoom(0, 6, zoom_target)
      up.moveXY(6, 4, dash_x + (10 * f_dir), dash_y)      
      
      if pbResolveBitmap(pummel)
        chop = addNewSprite(i_x, i_y - 200, pummel, PictureOrigin::CENTER); chop.setZ(0, target_z + 15)
        apply_pras_frame(chop, pummel, 0, 4, 0) 
        chop.setTone(0, Tone.new(255, 150, 50, 0)) 
        chop.setAngle(0, f_dir == 1 ? 0 : 180)
        chop.setVisible(0, false); chop.setVisible(t_imp - 4, true); chop.setZoom(0, 250)
        chop.moveXY(t_imp - 4, 4, i_x, i_y + 30) 
        chop.moveOpacity(t_imp + 4, 4, 0)
      end

      tp.setSE(t_imp, "Anim/Super Damage", 100, 100)
      tp.moveColor(t_imp, 2, Color.new(255, 200, 50, 200)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      
      tp.moveZoomXY(t_imp, 2, 130, 70); tp.moveXY(t_imp, 2, orig_tx, orig_ty + 30)
      tp.moveZoomXY(t_imp + 6, 6, 100, 100); tp.moveXY(t_imp + 6, 6, orig_tx, orig_ty)
      10.times { |i| tp.moveDelta(t_imp + i, 1, 0, (i.even? ? 15 : -15)) }

      if pbResolveBitmap(spark)
        tp.setSE(t_imp, "Anim/PRSFX- Ice Beam2", 100, 150) 
        12.times do |i|
          shard = addNewSprite(i_x, i_y, spark, PictureOrigin::CENTER); shard.setZ(0, target_z + 20)
          apply_pras_frame(shard, spark, 1, 1, 0) 
          shard.setBlendType(0, 1); shard.setTone(0, Tone.new(100, 200, 255, 0)) 
          shard.setVisible(0, false); shard.setVisible(t_imp, true); shard.setZoom(0, 40 + rand(40))
          
          ang = rand(360) * Math::PI / 180
          dist_s = 100 + rand(150)
          shard.moveXY(t_imp, 6 + rand(4), i_x + Math.cos(ang)*dist_s, i_y + Math.sin(ang)*dist_s)
          shard.moveAngle(t_imp, 10, rand(720) * (i.even? ? 1 : -1)) 
          shard.moveOpacity(t_imp + 4, 6, 0)
        end
      end
      
      up.moveXY(t_imp + 12, 6, orig_ux, orig_uy)
      up.moveZoom(t_imp + 12, 6, 100)
      up.setZ(t_imp + 12, orig_uz)

    when :CROSSCHOP
      t_charge = 12
      t_imp = t_charge + 4
      @end_frame = 55
      
      up.setSE(0, "Anim/Wind1", 100, 80)
      
      if pbResolveBitmap(pummel)
        c1_u = addNewSprite(orig_ux, orig_uy - (uh/2), pummel, PictureOrigin::CENTER); c1_u.setZ(0, user_z + 15)
        apply_pras_frame(c1_u, pummel, 0, 4, 0); c1_u.setTone(0, Tone.new(255, 100, 50, 0)); c1_u.setAngle(0, 45)
        c1_u.setVisible(0, false); c1_u.setVisible(2, true); c1_u.setZoom(0, 150)
        
        c2_u = addNewSprite(orig_ux, orig_uy - (uh/2), pummel, PictureOrigin::CENTER); c2_u.setZ(0, user_z + 16)
        apply_pras_frame(c2_u, pummel, 0, 4, 0); c2_u.setTone(0, Tone.new(255, 100, 50, 0)); c2_u.setAngle(0, 135)
        c2_u.setVisible(0, false); c2_u.setVisible(2, true); c2_u.setZoom(0, 150)
        
        c1_u.moveZoom(2, 6, 200); c2_u.moveZoom(2, 6, 200)
        c1_u.moveOpacity(10, 2, 0); c2_u.moveOpacity(10, 2, 0)
      end

      up.setSE(t_charge, "Anim/Wind2", 100, 160)
      up.setZ(t_charge, target_z - 5) if f_dir == -1
      
      up.moveXY(t_charge, t_imp - t_charge, dash_x, dash_y)
      up.moveZoom(t_charge, t_imp - t_charge, zoom_target)

      if pbResolveBitmap(pummel)
        c1 = addNewSprite(i_x, i_y, pummel, PictureOrigin::CENTER); c1.setZ(0, target_z + 15)
        apply_pras_frame(c1, pummel, 0, 4, 0); c1.setTone(0, Tone.new(255, 100, 50, 0)); c1.setAngle(0, 45)
        c1.setVisible(0, false); c1.setVisible(t_imp, true); c1.setZoom(0, 80)
        
        c2 = addNewSprite(i_x, i_y, pummel, PictureOrigin::CENTER); c2.setZ(0, target_z + 16)
        apply_pras_frame(c2, pummel, 0, 4, 0); c2.setTone(0, Tone.new(255, 100, 50, 0)); c2.setAngle(0, 135)
        c2.setVisible(0, false); c2.setVisible(t_imp, true); c2.setZoom(0, 80)

        c1.moveZoom(t_imp, 3, 240); c1.moveXY(t_imp + 2, 4, i_x + 100, i_y + 100); c1.moveOpacity(t_imp + 4, 4, 0)
        c2.moveZoom(t_imp, 3, 240); c2.moveXY(t_imp + 2, 4, i_x - 100, i_y + 100); c2.moveOpacity(t_imp + 4, 4, 0)
      end

      tp.setSE(t_imp + 2, "Anim/Hit2", 100, 90)
      tp.moveColor(t_imp + 2, 2, Color.new(255, 100, 50, 200)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
      tp.moveXY(t_imp + 2, 2, orig_tx + (40 * f_dir), orig_ty); tp.moveXY(t_imp + 4, 6, orig_tx, orig_ty)
      
      if pbResolveBitmap(spark)
        sp = addNewSprite(i_x, i_y, spark, PictureOrigin::CENTER); sp.setZ(0, target_z + 17)
        apply_pras_frame(sp, spark, 3, 0, 0) 
        sp.setVisible(0, false); sp.setVisible(t_imp + 2, true); sp.setZoom(0, 50)
        sp.setTone(0, Tone.new(255, 100, 0, 0))
        sp.moveZoom(t_imp + 2, 4, 250); sp.moveOpacity(t_imp + 4, 4, 0)
      end

      up.moveXY(t_imp + 12, 6, orig_ux, orig_uy)
      up.moveZoom(t_imp + 12, 6, 100)
      up.setZ(t_imp + 12, orig_uz)

    when :ARMTHRUST
      @end_frame = 20
      t_imp = 4

      up.setSE(0, "Anim/Wind1", 100, 130)
      up.moveDelta(0, 2, 10 * f_dir, 0); up.moveDelta(2, 2, -10 * f_dir, 0)

      if pbResolveBitmap(force_palm)
        palm = addNewSprite(orig_ux + (30 * f_dir), i_y, force_palm, PictureOrigin::CENTER)
        palm.setZ(0, target_z + 15)
        apply_pras_frame(palm, force_palm, 0, 0, 0) 
        palm.setAngle(0, f_dir == 1 ? 0 : 180)
        palm.setVisible(0, false); palm.setVisible(2, true); palm.setZoom(0, 120)
        palm.moveXY(2, 2, i_x, i_y); palm.moveOpacity(t_imp, 2, 0)

        shock = addNewSprite(i_x, i_y, force_palm, PictureOrigin::CENTER)
        shock.setZ(0, target_z + 16)
        apply_pras_frame(shock, force_palm, 1, 0, 0) 
        shock.setAngle(0, f_dir == 1 ? 0 : 180)
        shock.setVisible(0, false); shock.setVisible(t_imp, true); shock.setZoom(0, 100)
        
        3.times { |f| apply_pras_frame(shock, force_palm, f + 1, 0, t_imp + (f * 2)) }
        shock.moveOpacity(t_imp + 4, 3, 0)
      end

      tp.setSE(t_imp, "Anim/Hit1", 100, 110)
      tp.moveColor(t_imp, 2, Color.new(255, 255, 150, 200)); tp.moveColor(t_imp + 2, 3, Color.new(0,0,0,0))
      tp.moveDelta(t_imp, 1, 12 * f_dir, 0); tp.moveDelta(t_imp + 1, 2, -12 * f_dir, 0)
    end

    # FAILSAFES ABSOLUTOS
    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setZoom(@end_frame - 1, 100)
    up.setZ(@end_frame - 1, orig_uz)
    
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    tp.setZoom(@end_frame - 1, 100)
    tp.setZ(@end_frame - 1, orig_tz)
    
    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end