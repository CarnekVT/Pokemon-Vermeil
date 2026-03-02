#===============================================================================
# [VERMEIL] BattleAnimations - Grass Physical & Drum v2.4 (FINAL)
# Includes: Seed Bomb, Horn Leech, Trop Kick, Drum Beating
# Fix: Elevated Horn Leech energy horn and impact burst for better centering.
#===============================================================================

class Battle::Scene::Animation::VermeilGrassPhysical < Battle::Scene::Animation
  
  HANDLED_MOVES = [:SEEDBOMB, :HORNLEECH, :TROPKICK, :DRUMBEATING]
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

    target_z = (ts.z rescue 300) + 20
    user_z   = target_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    
    @us_orig_opac = us.opacity; @ts_orig_opac = ts.opacity
    us.opacity = 0; ts.opacity = 0

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y
    
    mid_x = (orig_ux + orig_tx) / 2
    mid_y = (orig_uy + orig_ty) / 2
    dash_x = mid_x
    dash_y = mid_y
    zoom_target = (f_dir == 1) ? 75 : 130 

    @end_frame = 50

    case @move_id
    when :SEEDBOMB
      # SEED BOMB
      t_start = 2; @end_frame = 65
      seed_asset = "Graphics/Animations/PRAS- Seed Bomb.png"
      trop_asset = "Graphics/Animations/PRAS- Trop Kick.png"
      energy_asset = "Graphics/BattleParticlesAnimations/Energy1"
      
      3.times do |i|
        t_fire = t_start + (i * 6)
        t_hit = t_start + 20 + (i * 10)
        t_drop = t_hit - 6
        
        up.setSE(t_fire, "Anim/Wind1", 100, 80 + (i * 10))
        up.moveDelta(t_fire, 2, -5 * f_dir, 5)
        up.moveDelta(t_fire + 2, 2, 5 * f_dir, -5)
        
        drop_x = orig_tx + (rand(40) - 20) 
        drop_y = orig_ty - (th/2) + 20
        
        if pbResolveBitmap(seed_asset)
          seed_up = addNewSprite(orig_ux, orig_uy - (uh/2), seed_asset, PictureOrigin::CENTER)
          seed_up.setZ(0, user_z - 5)
          apply_pras_frame(seed_up, seed_asset, 0, 0, 0)
          seed_up.setZoom(0, 100)
          seed_up.moveXY(t_fire, 5, orig_ux + (30 * f_dir), orig_uy - 600)
          seed_up.moveOpacity(t_fire + 5, 1, 0)
          
          seed_down = addNewSprite(drop_x, orig_ty - 400, seed_asset, PictureOrigin::CENTER)
          seed_down.setZ(0, target_z + 10 + i)
          apply_pras_frame(seed_down, seed_asset, 0, 0, 0)
          seed_down.setZoom(0, 150)
          seed_down.setVisible(0, false); seed_down.setVisible(t_drop, true)
          seed_down.moveXY(t_drop, 6, drop_x, drop_y) 
          seed_down.setVisible(t_hit, false) 
          
          # EXPLOSIÓN 1: NUBE DE HUMO (Fluidez mejorada)
          exp_seed = addNewSprite(drop_x, drop_y, seed_asset, PictureOrigin::CENTER)
          exp_seed.setZ(0, target_z + 14 + i)
          apply_pras_frame(exp_seed, seed_asset, 1, 0, 0) 
          exp_seed.setZoom(0, 250)
          exp_seed.setVisible(0, false); exp_seed.setVisible(t_hit, true)
          
          4.times { |f| apply_pras_frame(exp_seed, seed_asset, f + 1, 0, t_hit + (f * 2)) }
          exp_seed.moveOpacity(t_hit + 6, 4, 0) 
        end
        
        # EXPLOSIÓN 2: FOGONAZO (Fluidez mejorada)
        if pbResolveBitmap(trop_asset)
          exp_trop = addNewSprite(drop_x, drop_y, trop_asset, PictureOrigin::CENTER)
          exp_trop.setZ(0, target_z + 25 + i) 
          apply_pras_frame(exp_trop, trop_asset, 2, 2, 0) 
          exp_trop.setZoom(0, 260)
          exp_trop.setVisible(0, false); exp_trop.setVisible(t_hit, true)
          
          apply_pras_frame(exp_trop, trop_asset, 2, 2, t_hit)
          apply_pras_frame(exp_trop, trop_asset, 3, 2, t_hit + 2)
          apply_pras_frame(exp_trop, trop_asset, 4, 2, t_hit + 4)
          exp_trop.moveOpacity(t_hit + 5, 3, 0) 
        end

        # EXPLOSIÓN 3: BOLITAS DE ENERGÍA 8-WAY
        if pbResolveBitmap(energy_asset)
          color_pool = [Tone.new(255, -100, -255, 0), Tone.new(255, 100, -255, 0), Tone.new(255, 255, -100, 0)]
          8.times do |p|
            angle = p * 45 * Math::PI / 180
            spark = addNewSprite(drop_x, drop_y, energy_asset, PictureOrigin::CENTER)
            spark.setZ(0, target_z + 30)
            spark.setBlendType(0, 1)
            spark.setTone(0, color_pool.sample)
            spark.setVisible(0, false); spark.setVisible(t_hit, true)
            spark.setZoom(0, 20 + rand(160))
            
            dest_x = drop_x + (Math.cos(angle) * 100)
            dest_y = drop_y + (Math.sin(angle) * 100)
            
            spark.moveXY(t_hit, 6, dest_x, dest_y)
            spark.moveOpacity(t_hit + 2, 4, 0) 
          end
        end
        
        tp.setSE(t_hit, "Anim/PRSFX- Explosion", 100, 90 + (i * 10))
        tp.moveColor(t_hit, 1, Color.new(0, 0, 0, 255)) 
        tp.moveColor(t_hit + 3, 3, Color.new(0, 0, 0, 0)) 
        tp.moveDelta(t_hit, 2, (i.even? ? 12 : -12), (i.even? ? 6 : -6))
        tp.moveDelta(t_hit + 2, 2, (i.even? ? -12 : 12), (i.even? ? -6 : 6))
      end

    when :HORNLEECH
      # HORN LEECH - Cuerno Elevado
      t_start = 2; t_dash = 6; t_hit = 10; t_return = 16; t_drain = 20; @end_frame = 65
      horn_asset = "Graphics/Animations/PRAS- Horn Leech.png"
      ene_asset = "Graphics/BattleParticlesAnimations/Energy1"
      status_asset = "Graphics/Animations/PRAS- Status.png"
      
      up.setSE(t_dash, "Anim/Wind1", 100, 130)
      up.setZ(t_dash, target_z - 2) if f_dir == -1 
      up.moveXY(t_dash, 2, dash_x, dash_y)
      up.moveZoom(t_dash, 2, zoom_target)
      
      # Elevamos la posición del cuerno restando 25 píxeles adicionales
      horn_start_y = dash_y - (th/2) - 25
      horn_hit_y = orig_ty - (th/2) - 25
      
      if pbResolveBitmap(horn_asset)
        horn = addNewSprite(dash_x + (20 * f_dir), horn_start_y, horn_asset, PictureOrigin::CENTER)
        horn.setZ(0, target_z + 10)
        apply_pras_frame(horn, horn_asset, 0, 0, 0)
        horn.setAngle(0, f_dir == 1 ? 45 : -45)
        horn.setZoomXY(0, f_dir * 150, 150)
        horn.setVisible(0, false); horn.setVisible(t_hit - 1, true)
        horn.moveXY(t_hit, 2, orig_tx, horn_hit_y)
        horn.moveOpacity(t_hit + 4, 3, 0)
        
        burst = addNewSprite(orig_tx, horn_hit_y, horn_asset, PictureOrigin::CENTER)
        burst.setZ(0, target_z + 15)
        apply_pras_frame(burst, horn_asset, 3, 0, 0)
        burst.setTone(0, Tone.new(50, 255, 50, 0))
        burst.setVisible(0, false); burst.setVisible(t_hit, true)
        burst.setZoom(0, 50); burst.moveZoom(t_hit, 3, 200)
        burst.moveOpacity(t_hit + 2, 4, 0)
      end
      
      tp.setSE(t_hit, "Anim/PRSFX- Tackle", 100, 100)
      tp.moveColor(t_hit, 2, Color.new(100, 255, 100, 150))
      tp.moveColor(t_hit + 4, 4, Color.new(0, 0, 0, 0))
      tp.moveDelta(t_hit, 2, 20 * f_dir, 0); tp.moveDelta(t_hit + 4, 4, -20 * f_dir, 0)
      
      up.moveXY(t_return, 3, orig_ux, orig_uy)
      up.moveZoom(t_return, 3, 100)
      up.setZ(t_return, user_z)
      
      if pbResolveBitmap(ene_asset)
        tones = [Tone.new(-180, 150, -180, 0), Tone.new(-100, 200, -255, 0)]
        35.times do |i|
          t_s = t_drain + (i / 3) 
          p = addNewSprite(orig_tx, orig_ty - (th/2), ene_asset, PictureOrigin::CENTER)
          p.setZ(0, target_z + 20)
          p.setTone(0, tones[i % 2])
          p.setVisible(0, false); p.setVisible(t_s, true)
          p.setZoom(t_s, 30 + rand(30))
          
          pop_x = orig_tx + (rand(140) - 70)
          pop_y = orig_ty - (th/2) + (rand(140) - 70)
          p.moveXY(t_s, 6, pop_x, pop_y)
          p.moveXY(t_s + 6, 12, orig_ux, orig_uy - (uh/2))
          p.moveZoom(t_s + 6, 12, 10)
          p.moveOpacity(t_s + 15, 3, 0)
        end
      end
      
      t_heal = t_drain + 15
      up.setSE(t_heal, "Anim/PRSFX- Healing Pulse", 100, 100)
      up.moveColor(t_heal, 4, Color.new(100, 255, 100, 200))
      up.moveColor(t_heal + 6, 4, Color.new(0,0,0,0))
      
      if pbResolveBitmap(status_asset)
        8.times do |i|
          t_s = t_heal + (i * 2)
          start_x = orig_ux + (rand(70) - 35)
          start_y = orig_uy - rand(uh)
          
          s = addNewSprite(start_x, start_y, status_asset, PictureOrigin::CENTER)
          s.setZ(0, user_z + 25)
          apply_pras_frame(s, status_asset, 4, 4, 0)
          s.setTone(0, Tone.new(0, 255, 100, 0))
          s.setVisible(0, false); s.setVisible(t_s, true)
          s.setZoom(0, 60 + rand(50))
          
          s.moveXY(t_s, 8, start_x, start_y - 60 - rand(30))
          s.moveOpacity(t_s + 4, 4, 0)
        end
      end

    when :TROPKICK
      # TROP KICK
      t_start = 2; t_dash = 6; t_hit = 14; t_return = 28; @end_frame = 45
      trop_asset = "Graphics/Animations/PRAS- Trop Kick.png"
      
      up.setSE(t_dash, "Anim/Wind1", 100, 130)
      up.setZ(t_dash, target_z - 2) if f_dir == -1 
      up.moveXY(t_dash, 2, dash_x, dash_y - 120) 
      up.moveZoom(t_dash, 2, zoom_target)
      
      up.moveXY(t_hit - 2, 2, dash_x, dash_y - 20) 
      
      tp.setSE(t_hit, "Anim/Super Damage", 100, 100) 
      tp.setSE(t_hit, "Anim/Earth1", 100, 100) 
      
      tp.moveZoomXY(t_hit, 2, 130, 40) 
      tp.moveZoomXY(t_hit + 2, 4, 100, 100) 
      
      tp.moveColor(t_hit, 2, Color.new(255, 255, 255, 255))
      tp.moveColor(t_hit + 2, 6, Color.new(0, 0, 0, 0))
      
      6.times { |i| tp.moveDelta(t_hit + i, 1, 0, (i.even? ? 15 : -15)) }
      
      if pbResolveBitmap(trop_asset)
        3.times do |i|
          exp = addNewSprite(orig_tx, orig_ty - (th/2), trop_asset, PictureOrigin::CENTER)
          exp.setZ(0, target_z + 15)
          apply_pras_frame(exp, trop_asset, 2 + i, 2, 0) 
          exp.setZoom(0, 200)
          exp.setVisible(0, false)
          exp.setVisible(t_hit + (i * 2), true)
          exp.setVisible(t_hit + (i * 2) + 2, false)
        end
        
        10.times do |i|
          flower = addNewSprite(orig_tx, orig_ty - (th/2), trop_asset, PictureOrigin::CENTER)
          flower.setZ(0, target_z + 20)
          apply_pras_frame(flower, trop_asset, 0, 0, 0)
          flower.setVisible(0, false); flower.setVisible(t_hit, true)
          flower.setZoom(0, 50 + rand(30))
          
          pop_x = orig_tx + (rand(200) - 100)
          pop_y = orig_ty - th + (rand(160) - 80)
          flower.moveXY(t_hit, 6 + rand(4), pop_x, pop_y)
          flower.moveAngle(t_hit, 10, rand(720))
          flower.moveOpacity(t_hit + 4, 6, 0)
        end
      end
      
      up.moveXY(t_return, 6, orig_ux, orig_uy)
      up.moveZoom(t_return, 6, 100)
      up.setZ(t_return, user_z)

    when :DRUMBEATING
      # DRUMBEATING
      t_start = 2; @end_frame = 70
      drum_asset = "Graphics/Animations/GEN8- Drum beating.png"
      frenzy_asset = "Graphics/Animations/PRAS- Frenzy Plant.png"
      strike_asset = "Graphics/Animations/PRAS- Strike.png"
      
      root_mul = (f_dir == -1) ? 1.5 : 1.0
      
      4.times do |i|
        t_beat = t_start + 6 + (i * 14) 
        is_last = (i == 3)
        
        # GORILLA CHEST BEAT - Ahora elevado y centrado
        if pbResolveBitmap(strike_asset)
          3.times do |b| 
            t_b = t_beat + (b * 2)
            side = (b.even? ? 1 : -1)
            
            # Elevamos la posición Y restando 25 píxeles más
            fist_y = orig_uy - (uh/2) - 25
            
            fist = addNewSprite(orig_ux + (side * 30 * f_dir), fist_y, strike_asset, PictureOrigin::CENTER)
            fist.setZ(0, user_z + 10)
            apply_pras_frame(fist, strike_asset, 1, 0, 0)
            fist.setAngle(0, side == 1 ? -45 : 45)
            fist.setVisible(0, false); fist.setVisible(t_b, true)
            fist.setZoom(0, 150)
            
            fist.moveXY(t_b, 2, orig_ux + (side * 10 * f_dir), fist_y + 10)
            fist.moveOpacity(t_b + 2, 2, 0)
            
            up.setSE(t_b, "Anim/PRSFX- Pound", 100, 90 + rand(20)) 
            up.moveZoomXY(t_b, 1, 105, 95)
            up.moveZoomXY(t_b + 1, 1, 100, 100)
          end
        end
        
        t_launch = t_beat + 6
        
        # ONDA ACÚSTICA
        if pbResolveBitmap(drum_asset)
          wave = addNewSprite(orig_ux, orig_uy - (uh/2), drum_asset, PictureOrigin::CENTER)
          wave.setZ(0, target_z + 15 + i)
          apply_pras_frame(wave, drum_asset, 0, 1, 0) 
          wave.setTone(0, Tone.new(0, 200, 0, 0)) 
          wave.setVisible(0, false); wave.setVisible(t_launch, true)
          wave.setZoom(0, 50)
          
          wave.moveXY(t_launch, 4, orig_tx, orig_ty - (th/2))
          wave.moveZoom(t_launch, 4, is_last ? 300 : 200)
          wave.moveOpacity(t_launch + 3, 3, 0)
        end
        
        t_hit = t_launch + 3
        
        tp.setSE(t_hit, is_last ? "Anim/PRSFX- Focus Punch2" : "Anim/PRSFX- Cut", 100, 110)
        tp.moveColor(t_hit, 2, Color.new(150, 255, 100, 180))
        tp.moveColor(t_hit + 4, 2, Color.new(0, 0, 0, 0))
        tp.moveDelta(t_hit, 2, (i.even? ? 15 : -15), 0)
        tp.moveDelta(t_hit + 2, 2, (i.even? ? -15 : 15), 0)
        
        # LIANAS
        root_y = orig_ty - 35
        
        if pbResolveBitmap(frenzy_asset)
          vine = addNewSprite(orig_tx + (rand(40) - 20), root_y, frenzy_asset, PictureOrigin::CENTER)
          vine.setZ(0, target_z + 50 + i) 
          
          apply_pras_frame(vine, frenzy_asset, 0, 2, 0)
          vine.setVisible(0, false); vine.setVisible(t_hit, true)
          vine.setZoom(0, (is_last ? 210 : 160) * root_mul) 
          
          5.times { |f| apply_pras_frame(vine, frenzy_asset, f, 2, t_hit + (f * 2)) }
          vine.moveOpacity(t_hit + 10, 5, 0)
          
          if is_last
            2.times do |j|
               vine_sec = addNewSprite(orig_tx + (j == 0 ? -60 : 60), root_y + 10, frenzy_asset, PictureOrigin::CENTER)
               vine_sec.setZ(0, target_z + 51 + j)
               
               apply_pras_frame(vine_sec, frenzy_asset, 0, 3, 0) 
               vine_sec.setVisible(0, false); vine_sec.setVisible(t_hit, true)
               
               sec_zoom = 180 * root_mul
               vine_sec.setZoomXY(0, j == 0 ? sec_zoom : -sec_zoom, sec_zoom)
               
               5.times { |f| apply_pras_frame(vine_sec, frenzy_asset, f, 3, t_hit + (f * 2)) }
               vine_sec.moveOpacity(t_hit + 10, 5, 0)
            end
          end
        end
      end

    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setZoom(@end_frame - 1, 100)
    up.setZ(@end_frame - 1, user_z)
    
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    tp.setZoomXY(@end_frame - 1, 100, 100)
    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac; ts.opacity = @ts_orig_opac
      us.visible = true; ts.visible = true 
    })
  end
end