#===============================================================================
# [VERMEIL] BattleAnimations - Grass Status & Powders v1.0
# Includes: Worry Seed, Strength Sap, Aromatherapy, Ingrain, Spiky Shield, 
#           Forest's Curse, Jungle Healing, Leech Seed, Spore, Cotton Spore, 
#           Stun Spore, Spicy Extract, Grass Whistle, Synthesis, Sleep Powder, 
#           Poison Powder, Growth.
#===============================================================================

class Battle::Scene::Animation::VermeilGrassStatus < Battle::Scene::Animation
  
  HANDLED_MOVES = [:WORRYSEED, :STRENGTHSAP, :AROMATHERAPY, :FORESTSCURSE, 
                   :JUNGLEHEALING, :LEECHSEED, :SPORE, :COTTONSPORE, 
                   :STUNSPORE, :SPICYEXTRACT, :GRASSWHISTLE, :SLEEPPOWDER, 
                   :POISONPOWDER]
  BEHAVIOR = :self_targeting

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

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM)
    up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM)
    tp.setZ(0, target_z)
    
    @us_orig_opac = us.opacity
    @ts_orig_opac = ts.opacity
    us.opacity = 0
    ts.opacity = 0

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40
    th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th
    orig_ux = us.x; orig_uy = us.y
    orig_tx = ts.x; orig_ty = ts.y

    @end_frame = 50

    magic_asset  = "Graphics/Animations/PRAS- Magical Leaf.png"
    leaf_asset   = "Graphics/Animations/PRAS- Grass.png"
    frenzy_asset = "Graphics/Animations/PRAS- Frenzy Plant.png"
    stats_asset  = "Graphics/Animations/PRAS- Stats.png"

    case @move_id
    when :SPORE, :COTTONSPORE, :STUNSPORE, :SLEEPPOWDER, :POISONPOWDER
      # POWDERS (Parábola curva perfecta, desvanecimiento y caída en cono)
      t_lob = 2; t_hit = 12; @end_frame = 20
      up.setSE(0, "Anim/Wind1", 100, 150)
      
      p_tone = Tone.new(0,0,0,0)
      case @move_id
      when :SPORE;        p_tone = Tone.new(50, 50, 50, 0)
      when :COTTONSPORE;  p_tone = Tone.new(150, 150, 150, 0)
      when :STUNSPORE;    p_tone = Tone.new(200, 150, -50, 0)
      when :SLEEPPOWDER;  p_tone = Tone.new(-50, 100, 200, 0)
      when :POISONPOWDER; p_tone = Tone.new(150, -50, 200, 0)
      end

      if pbResolveBitmap(magic_asset)
        bomb = addNewSprite(orig_ux, orig_uy - uh, magic_asset, PictureOrigin::CENTER)
        bomb.setZ(0, target_z + 20)
        apply_pras_frame(bomb, magic_asset, 0, 0, 0)
        bomb.setTone(0, p_tone)
        bomb.setVisible(0, false); bomb.setVisible(t_lob, true); bomb.setZoom(0, 80)
        
        start_x = orig_ux; start_y = orig_uy - uh
        hit_x = i_x; hit_y = i_y - 40 
        dur = t_hit - t_lob
        
        # Trayectoria parabólica calculada frame a frame
        dur.times do |j|
          prog = j.to_f / dur
          cx = start_x + (hit_x - start_x) * prog
          cy = start_y + (hit_y - start_y) * prog - Math.sin(prog * 3.14159) * 100
          bomb.setXY(t_lob + j, cx, cy)
        end
        bomb.moveOpacity(t_hit, 1, 0)

        tp.setSE(t_hit, "Anim/PRSFX- Poison Powder", 100, 120)
        tp.setSE(t_hit, "Anim/PRSFX- Paralyze", 100, 150) if @move_id == :STUNSPORE

        flash_tone = Tone.new(p_tone.red, p_tone.green, p_tone.blue, 150)
        tp.moveTone(t_hit, 4, flash_tone)
        tp.moveTone(t_hit + 6, 6, Tone.new(0,0,0,0))
        
        # Caída en cono hacia abajo
        20.times do |i|
          t_start = t_hit + rand(4)
          pow = addNewSprite(hit_x + (rand(40)-20), hit_y + (rand(20)-10), magic_asset, PictureOrigin::CENTER)
          pow.setZ(0, target_z + 10 + i)
          apply_pras_frame(pow, magic_asset, 0, 0, 0)
          pow.setTone(0, p_tone)
          pow.setVisible(0, false); pow.setVisible(t_start, true)
          pow.setZoom(0, 20 + rand(30))
          
          dir_x = (rand(120) - 60)
          pow.moveDelta(t_start, 10, dir_x, 60 + rand(30))
          pow.moveOpacity(t_start + 6, 4, 0)
        end
      end

    when :WORRYSEED
      # WORRY SEED (Disparo recto y sacudida)
      t_shoot = 4; t_hit = 10; @end_frame = 20
      up.setSE(0, "Anim/Wind1", 100, 120)
      
      if pbResolveBitmap(magic_asset)
        seed = addNewSprite(orig_ux + (20*f_dir), orig_uy - (uh/2), magic_asset, PictureOrigin::CENTER)
        seed.setZ(0, target_z + 20); apply_pras_frame(seed, magic_asset, 0, 0, 0)
        seed.setTone(0, Tone.new(100, 50, -50, 0)) # Marron semilla
        seed.setVisible(0, false); seed.setVisible(t_shoot, true); seed.setZoom(0, 50)
        
        seed.moveXY(t_shoot, t_hit - t_shoot, i_x, i_y)
        seed.moveOpacity(t_hit, 2, 0)
      end
      
      tp.setSE(t_hit, "Anim/PRSFX- Pound", 100, 150)
      tp.moveColor(t_hit, 2, Color.new(200, 200, 100, 150))
      tp.moveColor(t_hit + 2, 2, Color.new(0,0,0,0))
      
      # Sacudida de preocupacion
      6.times { |i| tp.moveDelta(t_hit + i, 1, (i.even? ? 6 : -6), 0) }

when :STRENGTHSAP
      # STRENGTH SAP (Energy1 partículas + iluminación verde + healing)
      t_drain = 4; t_heal = 25; @end_frame = 45
      if pbResolveBitmap(frenzy_asset)
        # Roots land on ground at target position (base of battler)
        root1 = addNewSprite(orig_tx - 20, orig_ty, frenzy_asset, PictureOrigin::BOTTOM)
        root2 = addNewSprite(orig_tx + 20, orig_ty, frenzy_asset, PictureOrigin::BOTTOM)
        root1.setZ(0, target_z + 15); root2.setZ(0, target_z + 16)
        
        apply_pras_frame(root1, frenzy_asset, 0, 3, 0)
        apply_pras_frame(root2, frenzy_asset, 0, 3, 0); root2.setZoomXY(0, -100, 100)
        
        root1.setTone(0, Tone.new(-30, 50, -30, 0))
        root2.setTone(0, Tone.new(-30, 50, -30, 0))
        root1.setVisible(0, false); root1.setVisible(t_drain, true)
        root2.setVisible(0, false); root2.setVisible(t_drain, true)
        
        4.times do |i|
          apply_pras_frame(root1, frenzy_asset, i, 3, t_drain + (i*2))
          apply_pras_frame(root2, frenzy_asset, i, 3, t_drain + (i*2))
        end
        
        # Roots stay throughout the animation
        root1.moveOpacity(t_drain + 35, 6, 0)
        root2.moveOpacity(t_drain + 35, 6, 0)
      end
      
      # Target feels weak (sinks, shakes, loses color)
      tp.moveTone(t_drain, 10, Tone.new(-100, -100, -100, 150))
      tp.moveTone(t_drain + 14, 6, Tone.new(0,0,0,0))
      tp.moveDelta(t_drain, 8, 0, 15)
      tp.moveDelta(t_drain + 14, 6, 0, -15)
      10.times { |i| tp.moveDelta(t_drain + i, 1, (i.even? ? 4 : -4), 0) }
      
      # Energy1 partículas de drenado (como Giga Drain)
      ene_asset = "Graphics/BattleParticlesAnimations/Energy1"
      tones = [
        Tone.new(-180, 150, -180, 0),
        Tone.new(-100, 200, -255, 0),
        Tone.new(-50, 255, -200, 0),
        Tone.new(50, 200, -50, 0)
      ]
      
      if pbResolveBitmap(ene_asset)
        40.times do |i|
          t_s = t_drain + 4 + i
          p = addNewSprite(i_x, i_y - (th/2), ene_asset, PictureOrigin::CENTER)
          p.setZ(0, target_z + 30)
          p.setTone(0, tones[i % 4])
          p.setVisible(0, false); p.setVisible(t_s, true); p.setZoom(t_s, 30 + rand(25))
          
          # Pop Out del objetivo
          pop_x = i_x + (rand(120) - 60); pop_y = i_y + (rand(120) - 60)
          p.moveXY(t_s, 5, pop_x, pop_y)
          
          # Succión al usuario
          p.moveXY(t_s + 5, 10, orig_ux, orig_uy - (uh/2))
          p.moveZoom(t_s + 5, 10, 10)
          p.moveOpacity(t_s + 12, 3, 0)
        end
      end
      
      # Target return (vuelve a posición original)
      tp.moveXY(t_drain + 25, 10, orig_tx, orig_ty)
      
      # Iluminación verde del usuario (el que drena)
      up.moveColor(t_drain + 10, 8, Color.new(50, 255, 50, 180))
      up.moveColor(t_drain + 25, 10, Color.new(0, 0, 0, 0))
      
      # Healing effect como Mega Drain (estrellas curativas)
      status = "Graphics/Animations/PRAS- Status.png"
      if pbResolveBitmap(status)
        8.times do |i|
          t_s = t_drain + 15 + (i * 2)
          start_x = orig_ux + (rand(70) - 35)
          start_y = orig_uy - rand(uh)
          
          s = addNewSprite(start_x, start_y, status, PictureOrigin::CENTER)
          s.setZ(0, user_z + 30)
          apply_pras_frame(s, status, 4, 4, 0)
          s.setTone(0, Tone.new(0, 255, 100, 0))
          s.setVisible(0, false); s.setVisible(t_s, true)
          s.setZoom(0, 60 + rand(50))
          
          s.moveXY(t_s, 8, start_x, start_y - 60 - rand(30))
          s.moveOpacity(t_s + 4, 4, 0)
        end
      end
      
      up.setSE(t_heal, "Anim/Recovery", 100, 120)
      up.moveZoom(t_heal, 2, 110)
      up.moveZoom(t_heal+2, 4, 100)

    when :AROMATHERAPY
      # AROMATHERAPY (Brisa de hojas pequeñas con Z global)
      t_start = 2; @end_frame = 42
      up.setSE(0, "Anim/Recovery", 100, 150)
      
      bg_asset = "Graphics/Animations/PRAS- Aromatherapy FG.png"
      if pbResolveBitmap(bg_asset)
        bg = addNewSprite(Graphics.width/2, Graphics.height/2, bg_asset, PictureOrigin::CENTER)
        bg.setZ(0, target_z + 30) 
        bg.setOpacity(0, 0)
        bg.moveOpacity(t_start, 6, 200)
        bg.moveOpacity(t_start + 25, 10, 0)
      end

      up.moveColor(t_start, 8, Color.new(255, 150, 255, 150))
      up.moveColor(t_start + 12, 8, Color.new(0,0,0,0))
      
      if pbResolveBitmap(leaf_asset)
        30.times do |i|
          delay = t_start + rand(20)
          start_x = (f_dir == 1) ? -50 : Graphics.width + 50
          dest_x = (f_dir == 1) ? Graphics.width + 50 : -50
          
          leaf = addNewSprite(start_x, rand(Graphics.height), leaf_asset, PictureOrigin::CENTER)
          leaf.setZ(0, 999) # Z superior a los battlers
          apply_pras_frame(leaf, leaf_asset, rand(3), 0, 0) 
          leaf.setVisible(0, false); leaf.setVisible(delay, true)
          leaf.setZoom(0, 30 + rand(20)) # Tamaño de pétalos pequeños
          
          leaf.moveXY(delay, 20, dest_x, rand(Graphics.height))
          leaf.moveAngle(delay, 20, rand(720) * f_dir)
          leaf.moveOpacity(delay + 16, 4, 0)
        end
      end

when :FORESTSCURSE
      # FOREST'S CURSE (Raíces en la base del battler)
      t_start = 4; @end_frame = 30
      if pbResolveBitmap(frenzy_asset)
        # Position at base of target (bottom of sprite, using orig_ty which is the feet position)
        # Efectos en el suelo (base del Pokémon)
        ground_y = orig_ty + (th * 0.3)
        curse_l = addNewSprite(orig_tx - 25, ground_y, frenzy_asset, PictureOrigin::BOTTOM)
        curse_r = addNewSprite(orig_tx + 25, ground_y, frenzy_asset, PictureOrigin::BOTTOM)
        curse_l.setZ(0, target_z + 15); curse_r.setZ(0, target_z + 16)
        
        apply_pras_frame(curse_l, frenzy_asset, 0, 3, 0)
        apply_pras_frame(curse_r, frenzy_asset, 0, 3, 0)
        
        curse_l.setTone(0, Tone.new(-100, -50, -50, 0))
        curse_r.setTone(0, Tone.new(-100, -50, -50, 0))
        
        curse_l.setVisible(0, false); curse_l.setVisible(t_start, true); curse_l.setZoom(0, 130)
        curse_r.setVisible(0, false); curse_r.setVisible(t_start, true); curse_r.setZoomXY(0, -130, 130)
        
        5.times do |i|
          apply_pras_frame(curse_l, frenzy_asset, i, 3, t_start + (i*2))
          apply_pras_frame(curse_r, frenzy_asset, i, 3, t_start + (i*2))
        end
        
        6.times { |i| tp.moveDelta(t_start + i, 1, (i.even? ? 4 : -4), 0) }
        
        curse_l.moveOpacity(t_start + 18, 6, 0)
        curse_r.moveOpacity(t_start + 18, 6, 0)
      end
      
      tp.setSE(t_start + 6, "Anim/PRSFX- Curse", 100, 120)
      tp.moveColor(t_start + 6, 6, Color.new(100, 0, 150, 180))
      tp.moveColor(t_start + 16, 6, Color.new(0,0,0,0))

    when :JUNGLEHEALING
      # JUNGLE HEALING (Pulsos expansivos curativos tipo Healing Wish)
      t_start = 4; @end_frame = 20
      up.setSE(0, "Anim/Recovery", 100, 100)
      up.moveColor(t_start, 6, Color.new(100, 255, 100, 180))
      up.moveColor(t_start + 12, 6, Color.new(0,0,0,0))
      
      wish_asset = "Graphics/Animations/PRAS- Healing Wish.png"
      if pbResolveBitmap(wish_asset)
        3.times do |i|
          t_pulse = t_start + (i * 6)
          pulse = addNewSprite(orig_ux, orig_uy - (uh/2), wish_asset, PictureOrigin::CENTER)
          pulse.setZ(0, user_z + 20)
          apply_pras_frame(pulse, wish_asset, 0, 3, 0) # Anillos de pulso de Healing Wish
          pulse.setTone(0, Tone.new(-100, 100, -100, 0)) 
          pulse.setVisible(0, false); pulse.setVisible(t_pulse, true)
          pulse.setZoom(0, 50); pulse.moveZoom(t_pulse, 10, 300 + (i*50))
          pulse.moveOpacity(t_pulse + 6, 4, 0)
        end
      end
      
      if pbResolveBitmap(leaf_asset)
        12.times do |i|
          leaf = addNewSprite(orig_ux, orig_uy - (uh/2), leaf_asset, PictureOrigin::CENTER)
          leaf.setZ(0, user_z + 10 + i)
          apply_pras_frame(leaf, leaf_asset, rand(3), 2, 0)
          leaf.setVisible(0, false); leaf.setVisible(t_start, true)
          leaf.setZoom(0, 100 + rand(50))
          
          ang = rand(360) * 3.14159 / 180
          dist = 100 + rand(100)
          dest_x = orig_ux + Math.cos(ang) * dist
          dest_y = orig_uy - (uh/2) + Math.sin(ang) * dist
          
          leaf.moveXY(t_start, 12, dest_x, dest_y)
          leaf.moveAngle(t_start, 12, rand(720))
          leaf.moveOpacity(t_start + 8, 4, 0)
        end
      end


when :LEECHSEED
      # LEECH SEED
      t_shoot = 4; t_hit = 12; @end_frame = 35
      up.setSE(0, "Anim/Wind1", 100, 120)
      
      if pbResolveBitmap(magic_asset)
        seed = addNewSprite(orig_ux + (20*f_dir), orig_uy - (uh/2), magic_asset, PictureOrigin::CENTER)
        seed.setZ(0, target_z + 20)
        apply_pras_frame(seed, magic_asset, 0, 0, 0)
        seed.setTone(0, Tone.new(50, 200, 50, 0))
        seed.setVisible(0, false); seed.setVisible(t_shoot, true)
        seed.setZoom(0, 50)
        seed.moveXY(t_shoot, t_hit - t_shoot, i_x, orig_ty + (th * 0.3))
        seed.moveOpacity(t_hit, 2, 0)
      end
      
      if pbResolveBitmap(frenzy_asset)
        root_y = orig_ty + (th * 0.3)
        root1 = addNewSprite(orig_tx - 20, root_y, frenzy_asset, PictureOrigin::BOTTOM)
        root2 = addNewSprite(orig_tx + 20, root_y, frenzy_asset, PictureOrigin::BOTTOM)
        root1.setZ(0, target_z + 15); root2.setZ(0, target_z + 16)
        apply_pras_frame(root1, frenzy_asset, 0, 3, 0)
        apply_pras_frame(root2, frenzy_asset, 0, 3, 0)
        root2.setZoomXY(0, -100, 100)
        root1.setTone(0, Tone.new(-30, 50, -30, 0))
        root2.setTone(0, Tone.new(-30, 50, -30, 0))
        root1.setVisible(0, false); root1.setVisible(t_hit, true)
        root2.setVisible(0, false); root2.setVisible(t_hit, true)
        4.times do |i|
          apply_pras_frame(root1, frenzy_asset, i, 3, t_hit + (i*2))
          apply_pras_frame(root2, frenzy_asset, i, 3, t_hit + (i*2))
        end
        root1.moveOpacity(t_hit + 20, 6, 0)
        root2.moveOpacity(t_hit + 20, 6, 0)
      end
      
      tp.setSE(t_hit, "Anim/PRSFX- Leech Seed", 100, 120)
      tp.moveColor(t_hit, 4, Color.new(50, 200, 50, 150))
      tp.moveColor(t_hit + 8, 6, Color.new(0, 0, 0, 0))

when :SPICYEXTRACT
      # SPICY EXTRACT (Salpicadura roja picante SIN BUG Z-Icon)
      t_splash = 4; t_hit = 14; @end_frame = 20
      if pbResolveBitmap(magic_asset)
        10.times do |i|
          drop = addNewSprite(orig_ux + (20*f_dir), orig_uy - (uh/2), magic_asset, PictureOrigin::CENTER)
          drop.setZ(0, target_z + 20); apply_pras_frame(drop, magic_asset, 0, 0, 0)
          drop.setTone(0, Tone.new(200, 50, -50, 0)) 
          drop.setVisible(0, false); drop.setVisible(t_splash, true); drop.setZoom(0, 30 + rand(20))
          
          dest_x = i_x + (rand(80) - 40)
          dest_y = i_y + (rand(80) - 40)
          drop.moveXY(t_splash, 10, dest_x, dest_y)
          drop.moveOpacity(t_splash + 8, 2, 0)
        end
      end
      
      tp.setSE(t_hit, "Anim/Water1", 100, 120)
      tp.moveColor(t_hit, 4, Color.new(255, 50, 50, 180))
      tp.moveColor(t_hit + 6, 4, Color.new(0,0,0,0))
      
      3.times { |i| tp.moveDelta(t_hit + i, 1, (i.even? ? 6 : -6), 0) }

    when :GRASSWHISTLE
      # GRASS WHISTLE (Notas musicales + hojas)
      t_start = 2; @end_frame = 30
      up.setSE(0, "Anim/PRSFX- Sing", 100, 100)
      
      # Notas musicales que viajan directamente al objetivo (desde arriba del usuario)
      sound_asset = "Graphics/Animations/PRAS- Sound.png"
      if pbResolveBitmap(sound_asset)
        10.times do |i|
          t_note = t_start + (i * 2)
          # Spawn point raised higher on user
          note = addNewSprite(orig_ux + (10*f_dir), orig_uy - (uh * 0.7), sound_asset, PictureOrigin::CENTER)
          note.setZ(0, target_z + 25)
          
          row = [1, 2, 4].sample
          apply_pras_frame(note, sound_asset, rand(5), row, 0) 
          note.setVisible(0, false); note.setVisible(t_note, true); note.setZoom(0, 60)
          
          note.moveXY(t_note, 12, orig_tx, orig_ty - (th/2))
          note.moveOpacity(t_note + 10, 4, 0)
        end
      end
      
      # Hojas flotando alrededor del objetivo
      if pbResolveBitmap(leaf_asset)
        8.times do |i|
          t_leaf = t_start + rand(8)
          leaf = addNewSprite(orig_tx + (rand(80)-40), orig_ty - (th/2) + (rand(60)-30), leaf_asset, PictureOrigin::CENTER)
          leaf.setZ(0, target_z + 35)
          apply_pras_frame(leaf, leaf_asset, rand(3), 0, 0)
          leaf.setTone(0, Tone.new(50, 200, 50, 0))
          leaf.setVisible(0, false); leaf.setVisible(t_leaf, true)
          leaf.setZoom(0, 30 + rand(20))
          
          ang = rand(360) * 3.14159 / 180
          dist = 30 + rand(30)
          dest_x = orig_tx + Math.cos(ang) * dist
          dest_y = orig_ty - (th/2) + Math.sin(ang) * dist
          
          leaf.moveXY(t_leaf, 16, dest_x, dest_y)
          leaf.moveAngle(t_leaf, 16, rand(360) * 2)
          leaf.moveOpacity(t_leaf + 12, 4, 0)
        end
      end
      
      # Efecto de impacto en el objetivo
      tp.setSE(t_start + 14, "Anim/PRSFX- Yawn", 100, 100)
      tp.moveDelta(t_start + 14, 6, 0, 10) 
      tp.moveDelta(t_start + 22, 6, 0, -10)
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    
    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac
      ts.opacity = @ts_orig_opac
      us.visible = true; ts.visible = true 
    })
  end
end

#===============================================================================
# Add playback method and Battle alias for grass status animations
#===============================================================================

class Battle::Scene
  # Play Grass Status animation
  def pbPlayVermeilGrassStatusAnimation(user, target, move_id)
    return if !user || !target
    user_sprite = @sprites["pokemon_#{user.index}"]
    target_sprite = @sprites["pokemon_#{target.index}"]
    return if !user_sprite || !target_sprite
    
    # Enable status particles for this animation
    StatusParticles.set_cinematic_mode_all(true) if defined?(StatusParticles)
    
    pbSaveShadows do
      anim = Animation::VermeilGrassStatus.new(@sprites, @viewport, user, target, move_id)
      loop do
        anim.update
        pbUpdate
        break if anim.animDone?
      end
      anim.dispose
    end
    
    # Disable status particles cinematic mode
    StatusParticles.set_cinematic_mode_all(false) if defined?(StatusParticles)
  end
end

# Note: Grass status moves are now handled by the Cinematic Engine Controller