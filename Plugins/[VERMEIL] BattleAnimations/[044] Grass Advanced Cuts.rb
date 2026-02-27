#===============================================================================
# [VERMEIL] BattleAnimations - Grass Advanced Cuts & Storms v1.3
# Includes: Leaf Blade, Petal Blizzard, Petal Dance, Leaf Storm
#===============================================================================

class Battle::Scene::Animation::VermeilGrassCuts < Battle::Scene::Animation
  
  HANDLED_MOVES = [:LEAFBLADE, :PETALBLIZZARD, :PETALDANCE, :LEAFSTORM]
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

  def make_green_anime_slash
    cw = Graphics.width; ch = Graphics.height
    diag = (Math.sqrt(cw * cw + ch * ch) * 2.5).to_i
    bmp  = Bitmap.new(diag, ch * 2)
    
    bmp.fill_rect(0, ch - 80, diag, 160, Color.new(0, 80, 0, 255))
    bmp.fill_rect(0, ch - 60, diag, 120, Color.new(0, 180, 0, 255))
    bmp.fill_rect(0, ch - 30, diag,  60, Color.new(40, 255, 40, 255))
    bmp.fill_rect(0, ch - 10, diag,  20, Color.new(200, 255, 200, 255))
    
    s = Sprite.new(@viewport)
    s.bitmap = bmp; s.ox = diag / 2; s.oy = ch
    @tempSprites << s; return s
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

    @end_frame = 40

    case @move_id
    when :LEAFBLADE
      t_start = 2; t_dash = 6; t_strike = 14; @end_frame = 45
      
      bg_dark = addNewSprite(0, 0, "Graphics/Battle animations/black_screen") rescue nil
      if bg_dark
        bg_dark.setZ(0, target_z - 15) 
        bg_dark.setOpacity(0, 0)
        bg_dark.moveOpacity(t_start, 4, 200)
        bg_dark.moveOpacity(@end_frame - 10, 8, 0)
      end

      up.setSE(t_dash, "Anim/Wind1", 100, 130)
      up.moveZoom(t_start, 4, 130)
      up.moveColor(t_dash, 2, Color.new(255, 255, 255, 255))
      up.moveDelta(t_dash, 3, 150 * f_dir, -100) 
      up.moveOpacity(t_dash, 3, 0)

      slash_angle = 35 * f_dir
      diag_s = make_green_anime_slash
      diag = addSprite(diag_s, PictureOrigin::CENTER); diag.setZ(0, user_z + 10)
      diag.setXY(0, orig_tx, orig_ty - th)
      diag.setVisible(0, false); diag.setOpacity(0, 0)
      diag.setAngle(0, slash_angle) 
      
      diag.setVisible(t_strike, true)
      diag.setOpacity(t_strike, 255)
      diag.moveZoomXY(t_strike, 4, 100, 15) 
      diag.moveOpacity(t_strike + 6, 4, 0)

      leaf_asset = "Graphics/Animations/PRAS- Grass.png"
      if pbResolveBitmap(leaf_asset)
        12.times do |i|
          spark = addNewSprite(orig_tx, orig_ty - (th/2), leaf_asset, PictureOrigin::CENTER)
          spark.setZ(0, target_z + 20)
          apply_pras_frame(spark, leaf_asset, rand(3), 0, 0)
          spark.setTone(0, Tone.new(100, 255, 100, 0)) 
          spark.setVisible(0, false); spark.setVisible(t_strike, true)
          spark.setZoom(0, 20 + rand(30))
          
          pop_x = orig_tx + (rand(160) - 80)
          pop_y = orig_ty - (th/2) + (rand(160) - 80)
          spark.moveXY(t_strike, 4 + rand(4), pop_x, pop_y)
          spark.moveAngle(t_strike, 8, rand(720))
          spark.moveOpacity(t_strike + 3, 4, 0)
        end
      end

      tp.setSE(t_strike, "Anim/PRSFX- Slash", 100, 90)
      tp.setSE(t_strike + 1, "Anim/PRSFX- Focus Punch2", 100, 110)
      tp.moveColor(t_strike, 2, Color.new(255, 255, 255, 255))
      tp.moveColor(t_strike + 4, 6, Color.new(0, 0, 0, 0))
      
      6.times { |i| tp.moveDelta(t_strike + i, 1, (i.even? ? 16 : -16) * f_dir, 0) }

      up.setXY(t_strike + 8, orig_ux - (40 * f_dir), orig_uy - 30)
      up.moveZoom(t_strike + 8, 1, 100) 
      up.moveOpacity(t_strike + 8, 3, 255)
      up.moveDelta(t_strike + 8, 4, 40 * f_dir, 30)
      up.moveColor(t_strike + 8, 2, Color.new(150, 255, 150, 200))
      up.moveColor(t_strike + 10, 4, Color.new(0, 0, 0, 0))

    when :PETALBLIZZARD
      t_start = 2; t_burst = 10; @end_frame = 55
      up.setSE(0, "Anim/Wind1", 100, 100)
      up.setSE(t_burst, "Anim/Blizzard", 100, 140)
      
      leaf_asset = "Graphics/Animations/PRAS- Grass.png"
      
      if pbResolveBitmap(leaf_asset)
        80.times do |i| 
          t_spawn = t_start + rand(15)
          start_x = orig_ux - (300 * f_dir) - rand(200)
          start_y = rand(Graphics.height + 100) - 50 
          
          petal = addNewSprite(start_x, start_y, leaf_asset, PictureOrigin::CENTER)
          petal.setZ(0, target_z + 10 + rand(20))
          apply_pras_frame(petal, leaf_asset, rand(3), 0, 0)
          petal.setTone(0, Tone.new(255, 100, 200, 0))
          petal.setVisible(0, false); petal.setVisible(t_spawn, true)
          petal.setZoom(0, 40 + rand(30))
          
          dest_x = orig_tx + (400 * f_dir) + rand(200)
          dur = 15 + rand(10)
          petal.moveXY(t_spawn, dur, dest_x, start_y + (rand(100)-50))
          petal.moveAngle(t_spawn, dur, rand(1080))
          petal.moveOpacity(t_spawn + (dur - 4), 4, 0)
        end
        
        # Partículas de impacto
        20.times do |i|
          spark = addNewSprite(orig_tx, orig_ty - (th/2), leaf_asset, PictureOrigin::CENTER)
          spark.setZ(0, target_z + 20)
          apply_pras_frame(spark, leaf_asset, rand(3), 0, 0)
          spark.setTone(0, Tone.new(255, 100, 200, 0))
          spark.setVisible(0, false); spark.setVisible(t_burst, true)
          spark.setZoom(0, 20 + rand(30))
          
          pop_x = orig_tx + (rand(160) - 80)
          pop_y = orig_ty - (th/2) + (rand(160) - 80)
          spark.moveXY(t_burst, 6, pop_x, pop_y)
          spark.moveOpacity(t_burst + 3, 3, 0)
        end
      end
      
      tp.moveColor(t_burst, 10, Color.new(255, 150, 200, 150))
      tp.moveColor(t_burst + 10, 8, Color.new(0, 0, 0, 0))
      tp.moveDelta(t_burst, 8, 15 * f_dir, 0) 
      tp.moveDelta(t_burst + 8, 8, -15 * f_dir, 0)
      10.times { |i| tp.moveDelta(t_burst + i, 1, (i.even? ? 4 : -4), 0) }

    when :PETALDANCE
      t_charge = 2; t_storm = 10; t_hit = 20; @end_frame = 55
      up.setSE(t_charge, "Anim/Recovery", 100, 110)
      
      # Solo oscurecemos el fondo, los Pokémon conservan su color real
      bg_dark = addNewSprite(0, 0, "Graphics/Battle animations/black_screen") rescue nil
      if bg_dark
        bg_dark.setZ(0, target_z - 15) 
        bg_dark.setOpacity(0, 0)
        bg_dark.moveOpacity(t_charge, 8, 160)
        bg_dark.moveOpacity(@end_frame - 10, 8, 0)
      end
      
      leaf_asset = "Graphics/Animations/PRAS- Grass.png"
      if pbResolveBitmap(leaf_asset)
        35.times do |i|
          t_spawn = t_storm + rand(12)
          start_angle = (i * 25.0) * 3.14159 / 180
          radius = 60 + rand(20)
          
          base_x = orig_tx + Math.cos(start_angle) * radius
          base_y = orig_ty - (th / 3)
          
          leaf = addNewSprite(base_x, base_y, leaf_asset, PictureOrigin::CENTER)
          z_offset = (Math.sin(start_angle) > 0) ? 20 : -10 
          leaf.setZ(0, target_z + z_offset)
          
          apply_pras_frame(leaf, leaf_asset, rand(3), 0, 0)
          leaf.setTone(0, Tone.new(255, 100, 180, 0)) 
          leaf.setVisible(0, false); leaf.setVisible(t_spawn, true)
          leaf.setZoom(0, 40 + rand(30))
          
          10.times do |j|
            current_angle = start_angle + (j * 1.5)
            current_radius = radius - (j * 2)
            lx = orig_tx + Math.cos(current_angle) * current_radius
            ly = base_y - (j * 20) 
            
            new_z = (Math.sin(current_angle) > 0) ? target_z + 20 : target_z - 10
            leaf.setZ(t_spawn + j, new_z)
            leaf.moveXY(t_spawn + j, 1, lx, ly)
            leaf.moveAngle(t_spawn + j, 1, (j * 45))
          end
          leaf.moveOpacity(t_spawn + 8, 3, 0)
        end

        # Partículas de impacto
        15.times do |i|
          spark = addNewSprite(orig_tx, orig_ty - (th/2), leaf_asset, PictureOrigin::CENTER)
          spark.setZ(0, target_z + 20)
          apply_pras_frame(spark, leaf_asset, rand(3), 0, 0)
          spark.setTone(0, Tone.new(255, 100, 180, 0))
          spark.setVisible(0, false); spark.setVisible(t_hit, true)
          spark.setZoom(0, 20 + rand(30))
          
          pop_x = orig_tx + (rand(160) - 80)
          pop_y = orig_ty - (th/2) + (rand(160) - 80)
          spark.moveXY(t_hit, 5 + rand(3), pop_x, pop_y)
          spark.moveAngle(t_hit, 8, rand(720))
          spark.moveOpacity(t_hit + 4, 4, 0)
        end
      end
      
      tp.setSE(t_hit, "Anim/Wind1", 100, 150)
      tp.moveColor(t_hit, 2, Color.new(255, 150, 200, 200))
      tp.moveColor(t_hit + 4, 4, Color.new(0, 0, 0, 0))
      
      tp.moveDelta(t_hit, 3, -10, 0); tp.moveDelta(t_hit + 3, 3, 20, 0)
      tp.moveDelta(t_hit + 6, 3, -10, 0)

    when :LEAFSTORM
      t_start = 2; t_strike = 12; @end_frame = 50
      up.setSE(t_start, "Anim/Wind1", 100, 90)
      
      # Oscurecemos el fondo, no los Pokémon
      bg_dark = addNewSprite(0, 0, "Graphics/Battle animations/black_screen") rescue nil
      if bg_dark
        bg_dark.setZ(0, target_z - 15) 
        bg_dark.setOpacity(0, 0)
        bg_dark.moveOpacity(t_start, 6, 180)
        bg_dark.moveOpacity(@end_frame - 10, 8, 0)
      end

      leaf_asset = "Graphics/Animations/PRAS- Grass.png"
      if pbResolveBitmap(leaf_asset)
        # Muchísimas más hojas (de 20 a 45)
        45.times do |i|
          t_spawn = t_start + rand(10)
          start_x = orig_ux + (rand(100) - 50)
          start_y = orig_uy - (uh * 0.8) + (rand(60) - 30)
          
          leaf = addNewSprite(start_x, start_y, leaf_asset, PictureOrigin::CENTER)
          leaf.setZ(0, user_z + 10 + i)
          apply_pras_frame(leaf, leaf_asset, rand(3), 0, 0)
          leaf.setTone(0, Tone.new(50, 255, 50, 0)) 
          leaf.setVisible(0, false); leaf.setVisible(t_spawn, true)
          leaf.setZoom(0, 40 + rand(30))
          
          dest_x = orig_tx + (rand(60) - 30)
          dest_y = orig_ty - (th / 2) + (rand(60) - 30)
          
          leaf.moveXY(t_spawn, 5, dest_x, dest_y)
          leaf.moveOpacity(t_spawn + 4, 2, 0) 
        end

        # Partículas de impacto
        25.times do |i|
          spark = addNewSprite(orig_tx, orig_ty - (th/2), leaf_asset, PictureOrigin::CENTER)
          spark.setZ(0, target_z + 20)
          apply_pras_frame(spark, leaf_asset, rand(3), 0, 0)
          spark.setTone(0, Tone.new(50, 255, 50, 0)) 
          spark.setVisible(0, false); spark.setVisible(t_strike, true)
          spark.setZoom(0, 25 + rand(35))
          
          pop_x = orig_tx + (rand(200) - 100)
          pop_y = orig_ty - (th/2) + (rand(200) - 100)
          spark.moveXY(t_strike, 5 + rand(3), pop_x, pop_y)
          spark.moveAngle(t_strike, 8, rand(720))
          spark.moveOpacity(t_strike + 4, 4, 0)
        end
      end
      
      # El objetivo se tiñe de verde intenso
      tp.moveColor(t_strike, 6, Color.new(50, 255, 50, 200))
      tp.moveColor(t_strike + 6, 6, Color.new(0, 0, 0, 0))

      10.times do |i|
        t_hit = t_strike + (i * 2)
        tp.setSE(t_hit, "Anim/PRSFX- Cut", 100, 110 + rand(30))
        tp.moveDelta(t_hit, 1, (i.even? ? 8 : -8), (i.even? ? 4 : -4)) 
      end
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac; ts.opacity = @ts_orig_opac
      us.visible = true; ts.visible = true 
    })
  end
end