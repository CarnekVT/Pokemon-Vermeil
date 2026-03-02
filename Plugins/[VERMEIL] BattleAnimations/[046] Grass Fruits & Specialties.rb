#===============================================================================
# [VERMEIL] BattleAnimations - Grass Signatures v5.0 (FINAL)
# Includes: Apple Acid, Grav Apple, Matcha Gotcha, Seed Flare
# Fix: Replaced Water asset in Matcha Gotcha for Acid asset stream, 
#      Yellow/Orange varied Acid drops, Fixed moveDelta target drift globally.
#===============================================================================

class Battle::Scene::Animation::VermeilGrassSignatures < Battle::Scene::Animation
  
  HANDLED_MOVES = [:APPLEACID, :GRAVAPPLE, :MATCHAGOTCHA, :SEEDFLARE]
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

    target_z = (ts.z rescue 300) + 20
    user_z   = target_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    
    @us_orig_opac = us.opacity; @ts_orig_opac = ts.opacity
    us.opacity = 0; ts.opacity = 0

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y
    
    @end_frame = 60

    # Lógica Matemática de Parábola (Curva de Bezier)
    apply_parabola = ->(sprite, t_start, dur, sx, sy, ex, ey, height) {
      seg = dur / 4
      seg = 1 if seg < 1
      ctrl_x = sx + (ex - sx) / 2.0
      ctrl_y = [sy, ey].min - height
      pts = []
      [0.25, 0.5, 0.75, 1.0].each do |t|
        u = 1.0 - t
        x = (u*u*sx + 2*u*t*ctrl_x + t*t*ex).round
        y = (u*u*sy + 2*u*t*ctrl_y + t*t*ey).round
        pts << [x, y]
      end
      sprite.setXY(t_start, sx, sy)
      sprite.moveXY(t_start, seg, pts[0][0], pts[0][1])
      sprite.moveXY(t_start + seg, seg, pts[1][0], pts[1][1])
      sprite.moveXY(t_start + seg*2, seg, pts[2][0], pts[2][1])
      sprite.moveXY(t_start + seg*3, dur - seg*3, pts[3][0], pts[3][1])
    }

    # Lógica Matemática de Humo Estrictamente Vertical
    energy_asset = "Graphics/BattleParticlesAnimations/Energy1"
    spawn_math_smoke = ->(base_x, base_y, z_idx, t_hit, count) {
      if pbResolveBitmap(energy_asset)
        count.times do |s_i|
          t_s = t_hit + rand(8)
          smoke = addNewSprite(base_x + (rand(40)-20), base_y + (rand(40)-20), energy_asset, PictureOrigin::CENTER)
          smoke.setZ(0, z_idx + s_i)
          smoke.setTone(0, Tone.new(80, 80, 80, 255)) 
          smoke.setVisible(0, false); smoke.setVisible(t_s, true)
          start_zoom = 20 + rand(20)
          smoke.setZoom(0, start_zoom)
          
          smoke.moveZoom(t_s, 10, start_zoom + 60 + rand(40)) 
          # Vuelo totalmente recto
          smoke.moveDelta(t_s, 10 + rand(5), 0, -(50 + rand(40))) 
          smoke.moveOpacity(t_s + 5, 5 + rand(5), 0)
        end
      end
    }

    case @move_id
    when :APPLEACID
      # APPLE ACID - Chorro Parabólico + Quemadura (Naranja/Amarillo)
      t_start = 2; @end_frame = 65
      acid_asset = "Graphics/Animations/GEN8- Apple Acid.png"
      
      up.setSE(t_start, "Anim/Water1", 100, 150)
      # FIX DERIVA: Usamos moveXY desde el origen
      up.moveXY(t_start, 4, orig_ux, orig_uy + 10)
      up.moveXY(t_start + 4, 4, orig_ux, orig_uy)
      
      if pbResolveBitmap(acid_asset)
        # CHORRO CONTINUO
        25.times do |i|
          t_lob = t_start + i 
          dur = 12
          t_hit = t_lob + dur
          
          start_x = orig_ux + (30 * f_dir)
          start_y = orig_uy - (uh/2)
          
          drop = addNewSprite(start_x, start_y, acid_asset, PictureOrigin::CENTER)
          drop.setZ(0, target_z + 20)
          apply_pras_frame(drop, acid_asset, 0, 0, 0)
          # Tono Naranja/Amarillo (añadiendo verde y cortando azul)
          drop.setTone(0, Tone.new(80, 160, -120, 0)) 
          drop.setVisible(0, false); drop.setVisible(t_lob, true)
          
          # Tamaños variados drásticamente (desde 30% hasta 110%)
          drop.setZoom(0, 30 + rand(80)) 
          
          hit_x = i_x + (rand(40) - 20)
          hit_y = i_y + (rand(40) - 20)
          
          apply_parabola.call(drop, t_lob, dur, start_x, start_y, hit_x, hit_y, 60 + rand(30))
          drop.moveOpacity(t_hit, 1, 0)

          if i % 4 == 0
            tp.setSE(t_hit, "Anim/PRSFX- Sludge Bomb2", 80, 120 + rand(20))
            tp.moveColor(t_hit, 3, Color.new(255, 120, 0, 220)) # Fogonazo Naranja
            tp.moveColor(t_hit + 4, 4, Color.new(0, 0, 0, 0))
            
            # FIX DERIVA: Sacudida con retorno matemático exacto
            tp.moveXY(t_hit, 2, orig_tx + (i.even? ? 8 : -8), orig_ty)
            tp.moveXY(t_hit + 2, 2, orig_tx, orig_ty)
            
            spawn_math_smoke.call(hit_x, hit_y, target_z + 25, t_hit, 3)
          end
        end
      end

    when :GRAVAPPLE
      # GRAV APPLE
      t_dark = 2; t_drop = 12; t_hit = 20; @end_frame = 60
      apple_asset = "Graphics/Animations/GEN8- Grav Apple.png"
      bomb_asset = "Graphics/Animations/PRAS- Seed Bomb.png" 
      
      up.setSE(t_dark, "Anim/PRSFX- Psychic", 100, 70) 
      bg_dark = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg_dark.setZ(0, target_z - 10)
      bg_dark.setOpacity(0, 0); bg_dark.moveOpacity(t_dark, 8, 160)
      bg_dark.moveOpacity(t_hit + 15, 10, 0)
      
      # FIX DERIVA:
      up.moveXY(t_dark + 4, 3, orig_ux, orig_uy - 20)
      up.moveXY(t_drop, 2, orig_ux, orig_uy + 10)
      up.moveXY(t_drop + 2, 2, orig_ux, orig_uy)
      
      if pbResolveBitmap(apple_asset)
        apple = addNewSprite(orig_tx, orig_ty - 400, apple_asset, PictureOrigin::CENTER)
        apple.setZ(0, target_z + 15)
        apply_pras_frame(apple, apple_asset, 0, 0, 0) 
        apple.setVisible(0, false); apple.setVisible(t_drop, true)
        apple.setZoom(0, 180) 
        
        apple.moveXY(t_drop, t_hit - t_drop, orig_tx, orig_ty - (th/2))
        apple.setVisible(t_hit, false)
        
        star = addNewSprite(orig_tx, orig_ty - (th/2), apple_asset, PictureOrigin::CENTER)
        star.setZ(0, target_z + 20)
        apply_pras_frame(star, apple_asset, 2, 0, 0) 
        star.setVisible(0, false); star.setVisible(t_hit, true)
        star.setZoom(0, 100); star.moveZoom(t_hit, 4, 250) 
        star.moveOpacity(t_hit + 3, 4, 0)
      end
      
      tp.setSE(t_hit, "Anim/Earth1", 100, 80)
      tp.setSE(t_hit, "Anim/PRSFX- Focus Punch2", 100, 100)
      
      tp.moveZoomXY(t_hit, 2, 140, 20) 
      tp.moveZoomXY(t_hit + 2, 6, 100, 100) 
      tp.moveColor(t_hit, 2, Color.new(255, 255, 255, 200))
      tp.moveColor(t_hit + 4, 4, Color.new(0,0,0,0))
      
      # FIX DERIVA: Sacudida vertical exacta
      10.times { |i| tp.moveXY(t_hit + i, 1, orig_tx, orig_ty + (i.even? ? 15 : -15)) }
      tp.moveXY(t_hit + 10, 1, orig_tx, orig_ty)
      
      if pbResolveBitmap(bomb_asset)
        crater = addNewSprite(orig_tx, orig_ty, bomb_asset, PictureOrigin::CENTER)
        crater.setZ(0, target_z + 25)
        crater.setTone(0, Tone.new(80, 40, -50, 0)) 
        apply_pras_frame(crater, bomb_asset, 1, 0, 0)
        crater.setVisible(0, false); crater.setVisible(t_hit, true)
        crater.setZoom(0, 220)
        
        4.times { |f| apply_pras_frame(crater, bomb_asset, f + 1, 0, t_hit + (f * 2)) }
        crater.moveOpacity(t_hit + 6, 4, 0)
      end

    when :MATCHAGOTCHA
      # MATCHA GOTCHA - Full Apple Acid Style (Parábola continua sin Water_asset)
      t_boil = 2; t_spit = 16; t_hit = 30; t_drain = 36; @end_frame = 80
      acid_asset = "Graphics/Animations/GEN8- Apple Acid.png"
      orbs_asset = "Graphics/Animations/PRAS- Orbs.png"
      status_asset = "Graphics/Animations/PRAS- Status.png"
      
      matcha_tone = Tone.new(-60, 160, -120, 0) # Verde Oscuro Matcha
      
      # 1. El usuario hierve y se agita
      up.setSE(t_boil, "Anim/Water1", 100, 130)
      
      # FIX DERIVA: 
      14.times { |i| up.moveXY(t_boil + i, 1, orig_ux + (i.even? ? 6 : -6), orig_uy) }
      up.moveXY(t_boil + 14, 1, orig_ux, orig_uy)
      
      spawn_math_smoke.call(orig_ux, orig_uy - (uh/2), user_z + 10, t_boil, 8)
      
      # 2. Escupe chorro continuo de Matcha (Como Apple Acid)
      up.setSE(t_spit, "Anim/Water3", 100, 110)
      if pbResolveBitmap(acid_asset)
        25.times do |i|
          t_lob = t_spit + i 
          dur = 14
          t_h = t_lob + dur
          
          start_x = orig_ux + (30 * f_dir)
          start_y = orig_uy - (uh/2)
          
          drop = addNewSprite(start_x, start_y, acid_asset, PictureOrigin::CENTER)
          drop.setZ(0, target_z + 15)
          apply_pras_frame(drop, acid_asset, 0, 0, 0)
          drop.setTone(0, matcha_tone) 
          drop.setVisible(0, false); drop.setVisible(t_lob, true)
          drop.setZoom(0, 30 + rand(60)) 
          
          hit_x = i_x + (rand(50) - 25)
          hit_y = i_y + (rand(50) - 25)
          
          apply_parabola.call(drop, t_lob, dur, start_x, start_y, hit_x, hit_y, 70 + rand(40))
          drop.moveOpacity(t_h, 1, 0)

          # 3. Impacto y Quemadura con Humo Matemático
          if i % 4 == 0
            tp.setSE(t_h, "Anim/PRSFX- Sludge Bomb2", 80, 110 + rand(20))
            tp.moveColor(t_h, 3, Color.new(255, 50, 50, 220)) 
            tp.moveColor(t_h + 4, 4, Color.new(0, 0, 0, 0))
            
            # FIX DERIVA:
            tp.moveXY(t_h, 2, orig_tx + (i.even? ? 8 : -8), orig_ty)
            tp.moveXY(t_h + 2, 2, orig_tx, orig_ty)
            
            spawn_math_smoke.call(hit_x, hit_y, target_z + 20, t_h, 3)
          end
        end
      end

      # 4. Drenaje Vampírico
      if pbResolveBitmap(orbs_asset)
        30.times do |i|
          t_s = t_drain + (i / 2)
          orb = addNewSprite(orig_tx, orig_ty - (th/2), orbs_asset, PictureOrigin::CENTER)
          orb.setZ(0, target_z + 25)
          apply_pras_frame(orb, orbs_asset, rand(2) * 2, 0, 0) 
          orb.setTone(0, Tone.new(-50, 200, -50, 0)) 
          orb.setVisible(0, false); orb.setVisible(t_s, true)
          orb.setZoom(t_s, 60 + rand(40))
          
          pop_x = orig_tx + (rand(160) - 80)
          pop_y = orig_ty - (th/2) + (rand(160) - 80)
          orb.moveXY(t_s, 6, pop_x, pop_y)
          orb.moveXY(t_s + 6, 10, orig_ux, orig_uy - (uh/2))
          orb.moveZoom(t_s + 6, 10, 20)
          orb.moveOpacity(t_s + 14, 2, 0)
        end
      end
      
      # 5. Curación
      t_heal = t_drain + 12
      up.setSE(t_heal, "Anim/PRSFX- Healing Pulse", 100, 100)
      up.moveColor(t_heal, 4, Color.new(100, 255, 100, 200))
      up.moveColor(t_heal + 8, 4, Color.new(0,0,0,0))
      
      if pbResolveBitmap(status_asset)
        8.times do |i|
          t_s = t_heal + (i * 2)
          start_x = orig_ux + (rand(70) - 35)
          
          s = addNewSprite(start_x, orig_uy - rand(uh), status_asset, PictureOrigin::CENTER)
          s.setZ(0, user_z + 30)
          apply_pras_frame(s, status_asset, 4, 4, 0) 
          s.setTone(0, Tone.new(0, 255, 100, 0))
          s.setVisible(0, false); s.setVisible(t_s, true)
          s.setZoom(0, 60 + rand(50))
          
          s.moveDelta(t_s, 8, 0, -(60 + rand(30)))
          s.moveOpacity(t_s + 4, 4, 0)
        end
      end

    when :SEEDFLARE
      # SEED FLARE - Aniquilación Lumínica sin electricidad.
      t_inhale = 2; t_flash = 24; t_boom = 26; @end_frame = 80
      orbs_asset = "Graphics/Animations/PRAS- Orbs.png"
      hyper_asset = "Graphics/Animations/PRAS- Hyper Beam.png"
      bomb_asset = "Graphics/Animations/PRAS- Seed Bomb.png" 
      strike_asset = "Graphics/Animations/PRAS- Strike.png" 
      
      up.setSE(t_inhale, "Anim/PRSFX- Seed Flare1", 100, 180) 
      bg_dim = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg_dim.setZ(0, target_z - 10)
      bg_dim.setOpacity(0, 0); bg_dim.moveOpacity(t_inhale, 20, 200) 
      
      if pbResolveBitmap(orbs_asset)
        40.times do |i|
          t_s = t_inhale + rand(18)
          orb = addNewSprite(orig_ux + (rand(600) - 300), orig_uy - (uh/2) + (rand(400) - 200), orbs_asset, PictureOrigin::CENTER)
          orb.setZ(0, user_z + 10)
          apply_pras_frame(orb, orbs_asset, 2, 0, 0)
          orb.setTone(0, Tone.new(-100, 255, -100, 0)) 
          orb.setVisible(0, false); orb.setVisible(t_s, true)
          orb.setZoom(0, 100)
          
          orb.moveXY(t_s, 6, orig_ux, orig_uy - (uh/2))
          orb.moveZoom(t_s, 6, 10)
          orb.moveOpacity(t_s + 4, 2, 0)
        end
        
        core = addNewSprite(orig_ux, orig_uy - (uh/2), orbs_asset, PictureOrigin::CENTER)
        core.setZ(0, user_z + 15)
        apply_pras_frame(core, orbs_asset, 2, 0, 0)
        core.setTone(0, Tone.new(100, 255, 100, 0))
        core.setVisible(0, false); core.setVisible(t_inhale, true)
        core.setZoom(0, 10); core.moveZoom(t_inhale, 20, 250)
        core.setVisible(t_flash, false)
      end
      
      # FLASH CEGADOR
      up.setSE(t_flash, "Anim/Thunder1", 100, 120)
      flash = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      flash.setZ(0, 999)
      flash.setTone(0, Tone.new(255, 255, 255, 0)) 
      flash.setOpacity(0, 0)
      flash.moveOpacity(t_flash, 1, 255)
      flash.moveOpacity(t_flash + 1, 4, 0) 
      
      bg_dim.moveOpacity(t_flash, 2, 0) 
      
      # PROYECTIL Y DETONACIÓN
      tp.setSE(t_boom, "Anim/PRSFX- Hyper Beam", 100, 100)
      tp.setSE(t_boom, "Anim/Explosion", 100, 100) 
      tp.setSE(t_boom + 3, "Anim/PRSFX- Focus Punch2", 100, 90)
      
      # FIX DERIVA:
      up.moveXY(t_boom, 4, orig_ux - (20 * f_dir), orig_uy) 
      up.moveXY(t_boom + 10, 10, orig_ux, orig_uy)
      
      if pbResolveBitmap(hyper_asset)
        beam = addNewSprite(orig_ux, orig_uy - (uh/2), hyper_asset, PictureOrigin::CENTER)
        beam.setZ(0, target_z + 25)
        apply_pras_frame(beam, hyper_asset, 0, 0, 0)
        beam.setTone(0, Tone.new(-150, 255, -150, 0)) 
        beam.setBlendType(0, 1) 
        beam.setVisible(0, false); beam.setVisible(t_boom, true)
        beam.setZoom(0, 100)
        
        beam.moveXY(t_boom, 3, orig_tx, orig_ty - (th/2))
        beam.moveZoom(t_boom, 3, 300)
        
        5.times { |f| apply_pras_frame(beam, hyper_asset, f, 0, t_boom + 3 + (f * 2)) }
        beam.moveZoom(t_boom + 3, 10, 600)
        beam.moveOpacity(t_boom + 10, 4, 0)
      end
      
      if pbResolveBitmap(bomb_asset)
        nuke = addNewSprite(orig_tx, orig_ty - (th/2), bomb_asset, PictureOrigin::CENTER)
        nuke.setZ(0, target_z + 30)
        apply_pras_frame(nuke, bomb_asset, 1, 0, 0) 
        nuke.setTone(0, Tone.new(-150, 255, -150, 0)) 
        nuke.setBlendType(0, 1)
        nuke.setVisible(0, false); nuke.setVisible(t_boom + 3, true)
        nuke.setZoom(0, 300)
        
        5.times { |f| apply_pras_frame(nuke, bomb_asset, f + 1, 0, t_boom + 3 + (f * 2)) }
        nuke.moveOpacity(t_boom + 10, 5, 0)
        
        3.times do |k|
          ring = addNewSprite(orig_tx, orig_ty - (th/2), bomb_asset, PictureOrigin::CENTER)
          ring.setZ(0, target_z + 35)
          apply_pras_frame(ring, bomb_asset, 5, 0, 0) 
          ring.setTone(0, Tone.new(-150, 255, -150, 0))
          ring.setBlendType(0, 1)
          ring.setVisible(0, false); ring.setVisible(t_boom + 3 + k, true)
          ring.setZoom(0, 100)
          ring.moveZoom(t_boom + 3 + k, 5, 400 + (k*100))
          ring.moveOpacity(t_boom + 6 + k, 3, 0)
        end
      end

      if pbResolveBitmap(strike_asset)
        12.times do |i|
          t_s = t_boom + 3 + rand(6)
          spark = addNewSprite(orig_tx, orig_ty - (th/2), strike_asset, PictureOrigin::CENTER)
          spark.setZ(0, target_z + 30)
          apply_pras_frame(spark, strike_asset, 3, 0, 0) 
          spark.setTone(0, Tone.new(-100, 255, -100, 0))
          spark.setBlendType(0, 1)
          spark.setVisible(0, false); spark.setVisible(t_s, true)
          spark.setZoom(0, 150 + rand(150))
          spark.setAngle(0, rand(360))
          spark.moveXY(t_s, 6, orig_tx + (rand(200)-100), orig_ty - (th/2) + (rand(200)-100))
          spark.moveOpacity(t_s + 4, 3, 0)
        end
      end
      
      tp.moveColor(t_boom + 3, 4, Color.new(150, 255, 150, 255))
      tp.moveColor(t_boom + 7, 10, Color.new(0,0,0,0))
      
      # FIX DERIVA:
      16.times { |i| tp.moveXY(t_boom + 3 + i, 1, orig_tx + (i.even? ? 25 : -25), orig_ty + (i.even? ? 10 : -10)) } 
      tp.moveXY(t_boom + 3 + 16, 1, orig_tx, orig_ty)

    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac; ts.opacity = @ts_orig_opac
      us.visible = true; ts.visible = true 
    })
  end
end