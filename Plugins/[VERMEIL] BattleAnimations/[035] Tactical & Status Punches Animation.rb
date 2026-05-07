#===============================================================================
# [VERMEIL] BattleAnimations - Tactical & Status Punches v13 (FINAL)
# Includes: Drain Punch, Power-Up Punch, Dizzy Punch, Poison Jab
# Fix: Added individual user jolts, swing SFX and hit SFX for barrage strikes.
#===============================================================================

class Battle::Scene::Animation::VermeilTacticalPunches < Battle::Scene::Animation
  
  HANDLED_MOVES = [:DRAINPUNCH, :POWERUPPUNCH, :DIZZYPUNCH, :POISONJAB]
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

    @end_frame = 50

    punches = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
    energy  = "Graphics/BattleParticlesAnimations/Energy1" 
    status  = "Graphics/Animations/PRAS- Status.png"
    stats   = "Graphics/Animations/PRAS- Stats.png"
    pjab    = "Graphics/Animations/PRAS- Poison Jab.png"

    case @move_id
    when :DRAINPUNCH
      t_imp = 6
      @end_frame = 40
      
      up.setSE(0, "Anim/Wind2", 100, 120)
      up.moveXY(0, t_imp, orig_ux + (20 * f_dir), orig_uy)

      if pbResolveBitmap(punches)
        fist = addNewSprite(i_x - (30 * f_dir), i_y, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(50, 50, 50, 0)); fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(t_imp - 2, true); fist.setZoom(0, 150)
        fist.moveXY(t_imp - 2, 2, i_x, i_y); fist.moveOpacity(t_imp + 2, 4, 0)
      end

      tp.setSE(t_imp, "Anim/PRSFX- Focus Punch2", 100, 100)
      tp.moveColor(t_imp, 2, Color.new(100, 255, 100, 200)); tp.moveColor(t_imp + 4, 4, Color.new(0,0,0,0))
      tp.moveXY(t_imp, 2, orig_tx + (15 * f_dir), orig_ty); tp.moveXY(t_imp + 2, 4, orig_tx, orig_ty)
      up.moveXY(t_imp + 4, 6, orig_ux, orig_uy)

      if pbResolveBitmap(energy)
        12.times do |i|
          t_s = t_imp + 4 + i
          p = addNewSprite(i_x, i_y, energy, PictureOrigin::CENTER); p.setZ(0, target_z + 20)
          p.setTone(0, Tone.new(-100, 200, -255, 0))
          p.setVisible(0, false); p.setVisible(t_s, true)
          p.setZoom(t_s, 30 + rand(60)) 
          
          pop_x = i_x + (rand(60) - 30) 
          pop_y = i_y + (rand(60) - 30)
          p.moveXY(t_s, 5, pop_x, pop_y) 
          
          p.moveXY(t_s + 5, 8, orig_ux, orig_uy - (uh/2)) 
          p.moveZoom(t_s + 5, 8, 10)
          p.moveOpacity(t_s + 11, 2, 0)
        end
      end
      
      t_heal = t_imp + 16
      up.setSE(t_heal, "Anim/PRSFX- Healing Pulse", 100, 85)
      up.moveColor(t_heal, 4, Color.new(50, 255, 50, 150)) 
      up.moveColor(t_heal + 6, 6, Color.new(0, 0, 0, 0))

      if pbResolveBitmap(status)
        8.times do |i|
          t_s = t_heal + (i * 2) 
          start_x = orig_ux + (rand(70) - 35) 
          start_y = orig_uy - rand(uh)        
          
          s = addNewSprite(start_x, start_y, status, PictureOrigin::CENTER)
          s.setZ(0, user_z + 25)
          apply_pras_frame(s, status, 4, 4, 0) 
          s.setTone(0, Tone.new(0, 255, 100, 0))
          s.setVisible(0, false); s.setVisible(t_s, true)
          s.setZoom(0, 60 + rand(50)) 
          
          s.moveXY(t_s, 8, start_x, start_y - 60 - rand(30)) 
          s.moveOpacity(t_s + 4, 4, 0)
        end
      end

    when :POWERUPPUNCH
      t_imp = 6
      @end_frame = 30
      
      up.setSE(0, "Anim/Wind1", 100, 100)
      up.moveXY(0, t_imp, orig_ux + (20 * f_dir), orig_uy)

      if pbResolveBitmap(punches)
        fist = addNewSprite(i_x - (30 * f_dir), i_y, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(255, 100, 0, 0)); fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(t_imp - 2, true); fist.setZoom(0, 180)
        fist.moveXY(t_imp - 2, 2, i_x, i_y); fist.moveOpacity(t_imp + 2, 4, 0)
      end

      tp.setSE(t_imp, "Anim/PRSFX- Tackle", 100, 110)
      tp.moveColor(t_imp, 2, Color.new(255, 150, 50, 200)); tp.moveColor(t_imp + 4, 4, Color.new(0,0,0,0))
      tp.moveXY(t_imp, 2, orig_tx + (20 * f_dir), orig_ty); tp.moveXY(t_imp + 2, 4, orig_tx, orig_ty)
      up.moveXY(t_imp + 4, 4, orig_ux, orig_uy)

      if pbResolveBitmap(energy)
        t_aura = t_imp + 6
        up.setSE(t_aura, "Anim/Battle1", 100, 100)
        up.moveTone(t_aura, 4, Tone.new(120, 30, 0, 30)); up.moveTone(t_aura + 12, 6, Tone.new(0,0,0,0))
        
        18.times do |i|
          t_start = t_aura + rand(8) 
          start_x = orig_ux + (rand(16) - 8)
          start_y = orig_uy - 20 + (rand(10) - 5) 
          z_layer = (i.even?) ? user_z + 15 : user_z - 5

          sp = addNewSprite(start_x, start_y, energy, PictureOrigin::CENTER)
          sp.setZ(0, z_layer) 
          sp.setBlendType(0, 0) 
          sp.setTone(0, Tone.new(255, 80, -150, 0)) 
          sp.setVisible(0, false); sp.setVisible(t_start, true)
          sp.setZoom(0, 40 + rand(50)) 
          
          end_x = orig_ux + (rand(160) - 80)
          end_y = start_y - 120 - rand(40)
          
          dur = 6 + rand(4) 
          sp.moveXY(t_start, dur, end_x, end_y) 
          sp.moveOpacity(t_start + (dur - 3), 3, 0) 
        end
        
        if pbResolveBitmap(stats)
          arrow = addNewSprite(orig_ux, orig_uy - (uh/2), stats, PictureOrigin::CENTER)
          arrow.setZ(0, user_z + 30)
          apply_pras_frame(arrow, stats, 5, 2, 0) 
          arrow.setTone(0, Tone.new(255, 120, 0, 0))
          arrow.setVisible(0, false); arrow.setVisible(t_aura, true)
          arrow.setZoom(0, 50); arrow.moveZoom(t_aura, 4, 130)
          
          arrow.moveXY(t_aura, 10, orig_ux, orig_uy - uh - 30)
          arrow.moveOpacity(t_aura + 7, 3, 0)
        end
      end

    when :DIZZYPUNCH
      t1 = 4
      t2 = t1 + 5
      @end_frame = 25
      
      # Primer golpe con sacudida individual
      up.setSE(t1 - 1, "Anim/Wind1", 100, 150)
      up.moveDelta(t1 - 1, 2, 8 * f_dir, 0); up.moveDelta(t1 + 1, 2, -8 * f_dir, 0)
      
      if pbResolveBitmap(punches)
        fist1 = addNewSprite(i_x - (30 * f_dir), i_y - 15, punches, PictureOrigin::CENTER); fist1.setZ(0, target_z + 15)
        apply_pras_frame(fist1, punches, 0, 0, 0)
        fist1.setTone(0, Tone.new(255, 100, 200, 0)); fist1.setAngle(0, f_dir == 1 ? -15 : 165)
        fist1.setVisible(0, false); fist1.setVisible(t1 - 1, true); fist1.setZoom(0, 140)
        fist1.moveXY(t1 - 1, 2, i_x, i_y - 15); fist1.moveOpacity(t1 + 1, 2, 0)
      end
      tp.setSE(t1, "Anim/PRSFX- Tackle", 90, 120)
      tp.moveColor(t1, 2, Color.new(255, 150, 255, 150)); tp.moveColor(t1 + 2, 2, Color.new(0,0,0,0))
      tp.moveDelta(t1, 2, 10 * f_dir, 0)

      # Segundo golpe con sacudida individual
      up.setSE(t2 - 1, "Anim/Wind2", 100, 150)
      up.moveDelta(t2 - 1, 2, 8 * f_dir, 0); up.moveDelta(t2 + 1, 2, -8 * f_dir, 0)
      
      if pbResolveBitmap(punches)
        fist2 = addNewSprite(i_x - (30 * f_dir), i_y + 15, punches, PictureOrigin::CENTER); fist2.setZ(0, target_z + 15)
        apply_pras_frame(fist2, punches, 0, 0, 0)
        fist2.setTone(0, Tone.new(255, 100, 200, 0)); fist2.setAngle(0, f_dir == 1 ? 15 : 195)
        fist2.setVisible(0, false); fist2.setVisible(t2 - 1, true); fist2.setZoom(0, 160)
        fist2.moveXY(t2 - 1, 2, i_x, i_y + 15); fist2.moveOpacity(t2 + 1, 2, 0)
      end
      tp.setSE(t2, "Anim/PRSFX- Tackle", 100, 130)
      tp.setSE(t2, "Anim/PRSFX- Confused", 100, 100)
      tp.moveColor(t2, 2, Color.new(255, 150, 255, 255)); tp.moveColor(t2 + 4, 4, Color.new(0,0,0,0))
      tp.moveXY(t2, 2, orig_tx + (20 * f_dir), orig_ty); tp.moveXY(t2 + 2, 4, orig_tx, orig_ty)
      
      up.moveXY(t2 + 4, 4, orig_ux, orig_uy)

      if pbResolveBitmap(status)
        face_y = i_y - (th / 2)
        3.times do |i|
          t_s = t2 + 4 + (i * 3)
          duck = addNewSprite(i_x, face_y, status, PictureOrigin::CENTER)
          duck.setZ(0, target_z + 20)
          apply_pras_frame(duck, status, 1, 1, 0) 
          apply_pras_frame(duck, status, 2, 1, t_s + 2)
          apply_pras_frame(duck, status, 3, 1, t_s + 4)
          duck.setVisible(0, false); duck.setVisible(t_s, true); duck.setZoom(0, 80)
          duck.moveXY(t_s, 6, i_x + (i.even? ? 30 : -30), face_y - 15 - rand(10))
          duck.moveOpacity(t_s + 4, 4, 0)
        end
      end

    when :POISONJAB
      t_start = 4
      hits = 7
      @end_frame = t_start + (hits * 3) + 10
      
      up.moveTone(0, 4, Tone.new(150, 0, 255, 100)) 
      up.moveXY(0, t_start, orig_ux + (20 * f_dir), orig_uy)

      if pbResolveBitmap(punches) && pbResolveBitmap(pjab)
        hits.times do |i|
          t_h = t_start + (i * 3) 
          
          # Sacudida y sonido de viento INDIVIDUAL para cada golpe envenenado
          up.setSE(t_h - 1, "Anim/Wind1", 90, 110 + rand(20))
          up.moveDelta(t_h - 1, 1, 8 * f_dir, 0); up.moveDelta(t_h, 2, -8 * f_dir, 0)

          r_y = (rand(40) - 20)
          r_x = (rand(20) - 10)
          
          fist = addNewSprite(i_x - (40 * f_dir) + r_x, i_y + r_y, punches, PictureOrigin::CENTER)
          fist.setZ(0, target_z + 15 + i)
          apply_pras_frame(fist, punches, 0, 0, 0)
          fist.setTone(0, Tone.new(180, -50, 255, 100)) 
          fist.setAngle(0, f_dir == 1 ? 0 : 180)
          fist.setVisible(0, false); fist.setVisible(t_h - 1, true); fist.setZoom(0, 130 + rand(30))
          fist.moveXY(t_h - 1, 2, i_x + r_x, i_y + r_y)
          fist.moveOpacity(t_h + 1, 2, 0)

          # Sonido de impacto y temblor INDIVIDUAL
          tp.setSE(t_h, "Anim/PRSFX- Tackle#{(i%3)+1}", 90, 120 + rand(20))
          tp.moveDelta(t_h, 1, (i.even? ? 6 : -6), 0)

          sp = addNewSprite(i_x + r_x, i_y + r_y, pjab, PictureOrigin::CENTER); sp.setZ(0, target_z + 25)
          apply_pras_frame(sp, pjab, rand(2..4), 0, 0) 
          sp.setTone(0, Tone.new(120, -20, 220, 50)) 
          sp.setVisible(0, false); sp.setVisible(t_h + 1, true)
          sp.setZoom(0, 60 + rand(40)); sp.moveOpacity(t_h + 3, 3, 0)
        end
      end

      t_final = t_start + (hits * 3)
      tp.setSE(t_final, "Anim/PRSFX- Poison", 100, 100)
      tp.moveColor(t_start, t_final - t_start, Color.new(150, 0, 255, 180)) 
      tp.moveColor(t_final + 4, 6, Color.new(0,0,0,0))
      tp.moveXY(t_final, 4, orig_tx, orig_ty)
      
      up.moveTone(t_final + 2, 4, Tone.new(0,0,0,0))
      up.moveXY(t_final + 2, 6, orig_ux, orig_uy)
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end