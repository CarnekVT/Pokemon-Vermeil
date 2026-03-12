#===============================================================================
# [VERMEIL] BattleAnimations - Grass Physical Exclusives v10.0 (FINAL PERFECT)
# Includes: Power Whip, Ivy Cudgel, Flower Trick
# Fixes: Ivy Cudgel perfectly mimics Gigaton Hammer approach + Energy1 impacts.
#        Power Whip hits fast with explicit Strike impact bursts.
#        Flower Trick keeps dark background + smooth Y=0 spotlight.
#===============================================================================

class Battle::Scene::Animation::VermeilGrassExclusives < Battle::Scene::Animation
  HANDLED_MOVES = [:POWERWHIP, :IVYCUDGEL, :FLOWERTRICK]
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
    bmp.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0, 255))
    s = Sprite.new(@viewport); s.bitmap = bmp
    @tempSprites << s; s
  end

  def make_horizontal_green_bg
    cw = Graphics.width; ch = Graphics.height
    bmp = Bitmap.new(cw * 2.5, ch)
    bmp.fill_rect(0, 0, cw * 2.5, ch, Color.new(10, 50, 10, 255))
    bmp.fill_rect(0, ch/2 - 80, cw*2.5, 160, Color.new(20, 120, 20, 255))
    bmp.fill_rect(0, ch/2 - 40, cw*2.5, 80, Color.new(50, 200, 50, 255))
    bmp.fill_rect(0, ch/2 - 10, cw*2.5, 20, Color.new(150, 255, 150, 255))
    s = Sprite.new(@viewport); s.bitmap = bmp
    s.ox = cw; s.oy = ch/2
    @tempSprites << s; s
  end

  def make_spotlight(floor_y)
    bmp = Bitmap.new(200, floor_y + 100)
    (0..100).each do |i|
      alpha = 180 - (i * 1.8)
      alpha = 0 if alpha < 0
      
      bmp.fill_rect(i, 0, 200 - (i*2), floor_y, Color.new(255, 255, 200, alpha))
      
      60.times do |j|
        fade_alpha = alpha * (60 - j) / 60.0
        bmp.fill_rect(i, floor_y + j, 200 - (i*2), 1, Color.new(255, 255, 200, fade_alpha))
      end
    end
    s = Sprite.new(@viewport); s.bitmap = bmp
    s.ox = 100; s.oy = 0 
    @tempSprites << s; s
  end

  def createProcesses
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    return if !us || !ts
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    # Z-Index Aislado
    bg_z = 90000
    target_z = bg_z + 10
    user_z   = bg_z + 40
    orig_tz = (ts.z rescue 300) + 10
    orig_uz = orig_tz + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    
    @us_orig_opac = us.opacity; @ts_orig_opac = ts.opacity
    us.opacity = 0; ts.opacity = 0

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y
    i_x = ts.x; i_y = ts.y - th

    # Posiciones relativas
    dash_x = (orig_ux + orig_tx) / 2
    dash_y = (orig_uy + orig_ty) / 2

    # Assets
    leaf_asset   = "Graphics/Animations/PRAS- Grass.png"
    magic_asset  = "Graphics/Animations/PRAS- Magical Leaf.png"
    strike_asset = "Graphics/Animations/PRAS- Strike.png"
    slash_asset  = "Graphics/Animations/PRAS- Slash.png"
    ene_asset    = "Graphics/BattleParticlesAnimations/Energy1" # Partícula de impacto requerida
    pummel_asset = "Graphics/Animations/PRAS- All Out Pummeling.png"

    @end_frame = 55

    case @move_id
    when :POWERWHIP
      # POWER WHIP - Fondo horizontal rápido con impactos FÍSICOS
      t_dash = 2; t_bg = 6; t_strike = 10; @end_frame = 35
      
      bg_dark = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg_dark.setZ(0, bg_z - 10) 
      bg_dark.setOpacity(0, 0); bg_dark.moveOpacity(t_dash, 4, 220)
      bg_dark.moveOpacity(@end_frame - 8, 6, 0)
      
      # Línea verde Horizontal detrás
      bg_anim = addSprite(make_horizontal_green_bg, PictureOrigin::CENTER)
      bg_anim.setZ(0, target_z - 5) 
      bg_anim.setXY(0, Graphics.width/2, orig_ty - (th/2))
      bg_anim.setVisible(0, false); bg_anim.setOpacity(0, 0)
      
      bg_anim.setVisible(t_bg, true)
      bg_anim.setOpacity(t_bg, 255)
      bg_anim.moveZoomXY(t_bg, 4, 100, 15) 
      bg_anim.moveOpacity(t_strike + 12, 4, 0)

      up.setSE(t_dash, "Anim/Wind1", 100, 130)
      up.moveColor(t_dash, 2, Color.new(255, 255, 255, 255))
      up.moveDelta(t_dash, 3, 150 * f_dir, -50) 
      up.moveOpacity(t_dash, 3, 0)

      # 5 IMPACTOS RAPIDÍSIMOS
      5.times do |i|
        t_hit = t_strike + (i * 2) 
        
        tp.setSE(t_hit, "Anim/PRSFX- Cut", 100, 80 + (i*10))
        tp.setSE(t_hit, "Anim/PRSFX- Focus Punch2", 100, 100) if i == 4 
        
        tp.moveColor(t_hit, 1, Color.new(200, 255, 100, 255))
        tp.moveColor(t_hit + 1, 1, Color.new(0, 0, 0, 0))
        
        tp.moveXY(t_hit, 1, orig_tx + (i.even? ? 25 : -25) * f_dir, orig_ty)
        tp.moveXY(t_hit + 1, 1, orig_tx, orig_ty)
        
        # Tajo
        if pbResolveBitmap(slash_asset)
          slash = addNewSprite(orig_tx + (rand(80)-40), orig_ty - (th/2) + (rand(80)-40), slash_asset, PictureOrigin::CENTER)
          slash.setZ(0, target_z + 20 + i)
          apply_pras_frame(slash, slash_asset, 5, 0, 0)
          slash.setBlendType(0, 1); slash.setTone(0, Tone.new(50, 255, 50, 0))
          slash.setVisible(0, false); slash.setVisible(t_hit, true)
          slash.setZoomXY(0, 300 + rand(100), 100 + rand(50))
          slash.setAngle(0, rand(180)) 
          slash.moveOpacity(t_hit + 2, 2, 0)
        end

        # IMPACTO EXPLÍCITO (PRAS- Strike)
        if pbResolveBitmap(strike_asset)
          strike = addNewSprite(orig_tx + (rand(60)-30), orig_ty - (th/2) + (rand(60)-30), strike_asset, PictureOrigin::CENTER)
          strike.setZ(0, target_z + 21 + i)
          apply_pras_frame(strike, strike_asset, 3, 0, 0)
          strike.setBlendType(0, 1); strike.setTone(0, Tone.new(100, 255, 100, 0))
          strike.setVisible(0, false); strike.setVisible(t_hit, true)
          strike.setZoom(0, 150 + rand(80)) 
          strike.setAngle(0, rand(360))
          strike.moveOpacity(t_hit + 3, 3, 0)
        end
        
        # Hojas
        if pbResolveBitmap(leaf_asset)
          10.times do |l|
            leaf = addNewSprite(orig_tx, orig_ty - (th/2), leaf_asset, PictureOrigin::CENTER)
            leaf.setZ(0, target_z + 25 + l)
            apply_pras_frame(leaf, leaf_asset, rand(3), 0, 0)
            leaf.setVisible(0, false); leaf.setVisible(t_hit, true)
            leaf.setZoom(0, 50 + rand(40))
            
            end_x = orig_tx + (rand(300) + 100) * (l.even? ? 1 : -1)
            end_y = orig_ty - (th/2) + (rand(100) - 50)
            leaf.moveXY(t_hit, 6, end_x, end_y)
            leaf.moveAngle(t_hit, 6, rand(720))
            leaf.moveOpacity(t_hit + 4, 2, 0)
          end
        end
      end
      
      t_return = t_strike + 12
      up.setXY(t_return, orig_ux - (40 * f_dir), orig_uy - 30)
      up.setSE(t_return, "Anim/Wind1", 80, 150)
      up.moveOpacity(t_return, 3, 255)
      up.moveDelta(t_return, 4, 40 * f_dir, 30)
      up.moveColor(t_return, 2, Color.new(100, 255, 100, 200))
      up.moveColor(t_return + 2, 4, Color.new(0,0,0,0))

    when :IVYCUDGEL
      # IVY CUDGEL - Lógica de [039] GIGATON HAMMER con impactos Energy1 puros
      t_lift = 4; t_hang = t_lift + 16; t_imp = t_hang + 3; @end_frame = t_imp + 40
      
      bg = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg.setZ(0, bg_z); bg.setOpacity(0, 0); bg.moveOpacity(0, 6, 200)

      up.setSE(0, "Anim/Earth1", 100, 80)
      up.setZ(0, target_z - 5) if f_dir == -1
      
      # Acercamiento exacto del Gigaton Hammer original
      dist_x = (f_dir == 1) ? 50 : 100 
      dash_x2 = orig_tx - (dist_x * f_dir)
      jump_y = dash_y - 10 
      zoom_target = (f_dir == 1) ? 75 : 130 

      up.moveXY(0, t_lift, dash_x2, jump_y)
      up.moveZoom(0, t_lift, zoom_target)

      # SINCRONIZACIÓN DE OGERPON
      sp = @user.pokemon ? @user.pokemon.species : @user.displaySpecies
      form = @user.pokemon ? @user.pokemon.form : @user.form
      
      mask_type = :GRASS
      if sp.to_s.include?("OGERPON") || sp.to_s == "PON"
        mask_type = :WATER if [1, 5, 9].include?(form)
        mask_type = :FIRE  if [2, 6, 10].include?(form)
        mask_type = :ROCK  if [3, 7, 11].include?(form)
      end

      hammer_tone = Tone.new(50, 255, 50, 100)
      impact_se   = "Anim/PRSFX- Wood Hammer"
      shard_color = Color.new(50, 255, 50, 200)
      
      case mask_type
      when :FIRE
        hammer_tone = Tone.new(255, 100, -50, 100)
        impact_se   = "Anim/PRSFX- Flare Blitz"
        shard_color = Color.new(255, 100, 50, 200)
      when :WATER
        hammer_tone = Tone.new(-50, 100, 255, 100)
        impact_se   = "Anim/Water1"
        shard_color = Color.new(50, 150, 255, 200)
      when :ROCK
        hammer_tone = Tone.new(150, 100, 50, 100)
        impact_se   = "Anim/Earth1"
        shard_color = Color.new(200, 150, 100, 200)
      end

      # ARMA GIGANTE DEL CIELO
      if pbResolveBitmap(pummel_asset)
        g_hammer = addNewSprite(i_x, i_y - 200, pummel_asset, PictureOrigin::CENTER)
        g_hammer.setZ(0, target_z + 15)
        apply_pras_frame(g_hammer, pummel_asset, 1, 0, 0) 
        g_hammer.setTone(0, hammer_tone) 
        g_hammer.setAngle(0, 180) 
        g_hammer.setVisible(0, false); g_hammer.setVisible(t_lift, true)
        g_hammer.setZoom(0, 400)

        up.setSE(t_lift, "Anim/Wind1", 80, 150)
        16.times { |i| g_hammer.moveDelta(t_lift + i, 1, (i.even? ? 6 : -6), 0) }
        
        up.setSE(t_hang, "Anim/Wind2", 100, 150)
        g_hammer.moveXY(t_hang, t_imp - t_hang, i_x, i_y)
        g_hammer.moveOpacity(t_imp + 4, 4, 0)
      end

      # IMPACTO MASIVO EN EL OBJETIVO
      tp.setSE(t_imp, impact_se, 100, 100)
      tp.setSE(t_imp + 2, "Anim/PRSFX- Focus Punch2", 100, 110)
      
      flash = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      flash.setZ(0, 99999); flash.setTone(0, Tone.new(hammer_tone.red, hammer_tone.green, hammer_tone.blue, 0))
      flash.setOpacity(0, 0); flash.moveOpacity(t_imp, 1, 255); flash.moveOpacity(t_imp + 3, 10, 0)

      tp.moveColor(t_imp, 3, shard_color); tp.moveColor(t_imp + 10, 8, Color.new(0,0,0,0))
      
      tp.moveZoomXY(t_imp, 2, 160, 40); tp.moveXY(t_imp, 2, orig_tx, orig_ty + 50)
      tp.moveZoomXY(t_imp + 12, 8, 100, 100); tp.moveXY(t_imp + 12, 8, orig_tx, orig_ty)
      18.times { |i| tp.moveDelta(t_imp + i, 1, (i.even? ? 20 : -20), (i.even? ? 10 : -10)) }

      # PARTÍCULAS ENERGY1 EXCLUSIVAS Y EXPLOSIVAS
      if pbResolveBitmap(ene_asset)
        60.times do |i|
          t_s = t_imp
          p = addNewSprite(i_x, i_y, ene_asset, PictureOrigin::CENTER)
          p.setZ(0, target_z + 20 + i)
          p.setTone(0, hammer_tone)
          p.setBlendType(0, 1) # Aditivo para que brille
          p.setVisible(0, false); p.setVisible(t_s, true)
          p.setZoom(0, 40 + rand(60))
          
          pop_x = orig_tx + (rand(300) - 150)
          pop_y = orig_ty - (th/2) + (rand(300) - 150)
          
          dur = 6 + rand(8)
          p.moveXY(t_s, dur, pop_x, pop_y)
          p.moveOpacity(t_s + (dur/2).floor, dur/2, 0)
        end
      end

      # Chispazo de impacto central complementario
      if pbResolveBitmap(strike_asset)
        3.times do |i|
          spp = addNewSprite(i_x, i_y, strike_asset, PictureOrigin::CENTER)
          spp.setZ(0, target_z + 21)
          apply_pras_frame(spp, strike_asset, 3, 0, 0)
          spp.setBlendType(0, 1); spp.setTone(0, hammer_tone)
          spp.setVisible(0, false); spp.setVisible(t_imp, true)
          spp.setZoom(0, 150 + (i*50))
          spp.setAngle(0, rand(360))
          spp.moveOpacity(t_imp + 4, 4, 0)
        end
      end

      bg.moveOpacity(t_imp + 15, 10, 0)
      up.moveXY(t_imp + 15, 8, orig_ux, orig_uy)
      up.moveZoom(t_imp + 15, 8, 100)
      up.setZ(t_imp + 15, orig_uz)

    when :FLOWERTRICK
      # FLOWER TRICK - Fondo Negro Mantenido, Reflector Y=0 con degradado.
      t_spot = 2; t_throw = 10; t_land = 20; t_boom = 28; @end_frame = 70
      
      bg_dark = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg_dark.setZ(0, bg_z - 10)
      bg_dark.setOpacity(0, 0)
      bg_dark.moveOpacity(t_spot, 6, 220)
      bg_dark.moveOpacity(t_boom + 10, 10, 0)
      
      tp.moveTone(t_spot, 6, Tone.new(-255, -255, -255, 255))
      tp.moveTone(t_boom, 2, Tone.new(0,0,0,0)) 
      
      spotlight = addSprite(make_spotlight(orig_uy), PictureOrigin::TOP)
      spotlight.setZ(0, target_z - 5)
      spotlight.setXY(0, orig_ux, 0) 
      spotlight.setOpacity(0, 0)
      spotlight.moveOpacity(t_spot + 4, 6, 255)
      spotlight.moveOpacity(t_boom, 2, 0) 
      
      up.setSE(t_spot, "Anim/PRSFX- Psychic", 100, 100)
      
      if pbResolveBitmap(magic_asset)
        bomb = addNewSprite(orig_ux, orig_uy - (uh/2), magic_asset, PictureOrigin::CENTER)
        bomb.setZ(0, target_z + 20)
        apply_pras_frame(bomb, magic_asset, 0, 0, 0)
        bomb.setTone(0, Tone.new(100, 200, 100, 0))
        bomb.setVisible(0, false); bomb.setVisible(t_throw, true)
        bomb.setZoom(0, 60)
        
        up.setSE(t_throw, "Anim/Wind1", 100, 160)
        
        dur = t_land - t_throw
        start_y = orig_uy - (uh/2)
        dur.times do |j|
          prog = j.to_f / dur
          cx = orig_ux + (orig_tx - orig_ux) * prog
          cy = start_y + (orig_ty - start_y) * prog - Math.sin(prog * 3.14159) * 150
          bomb.setXY(t_throw + j, cx, cy)
        end
        
        tp.setSE(t_land, "Anim/PRSFX- Pound", 80, 150)
        bomb.moveZoom(t_land, 2, 90)
        bomb.moveZoom(t_land + 2, 2, 60)
        bomb.moveZoom(t_land + 4, 2, 90)
        bomb.moveZoom(t_land + 6, 2, 60)
        bomb.moveOpacity(t_boom, 1, 0)
      end
      
      tp.setSE(t_boom, "Anim/PRSFX- Explosion", 100, 140)
      tp.setSE(t_boom, "Anim/PRSFX- Focus Punch2", 100, 110)
      
      flash = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      flash.setZ(0, 99999)
      flash.setTone(0, Tone.new(255, 255, 255, 0))
      flash.setOpacity(0, 0)
      flash.moveOpacity(t_boom, 2, 255)
      flash.moveOpacity(t_boom + 4, 6, 0)
      
      tp.moveColor(t_boom, 3, Color.new(255, 150, 200, 255))
      tp.moveColor(t_boom + 4, 6, Color.new(0,0,0,0))
      12.times { |i| tp.moveXY(t_boom + i, 1, orig_tx + (i.even? ? 20 : -20), orig_ty + (i.even? ? 10 : -10)) }
      tp.moveXY(t_boom + 12, 1, orig_tx, orig_ty)
      
      if pbResolveBitmap(leaf_asset)
        40.times do |i|
          petal = addNewSprite(orig_tx, orig_ty - (th/2), leaf_asset, PictureOrigin::CENTER)
          petal.setZ(0, target_z + 25 + i)
          apply_pras_frame(petal, leaf_asset, rand(3), 0, 0)
          
          color = [Tone.new(200, 50, 150, 0), Tone.new(50, 200, 50, 0), Tone.new(200, 200, 200, 0)].sample
          petal.setTone(0, color)
          petal.setVisible(0, false); petal.setVisible(t_boom, true)
          petal.setZoom(0, 50 + rand(50))
          
          ang = rand(360) * 3.14159 / 180
          dist = 100 + rand(200) 
          dest_x = orig_tx + Math.cos(ang) * dist
          dest_y = orig_ty - (th/2) + Math.sin(ang) * dist
          
          petal.moveXY(t_boom, 8 + rand(8), dest_x, dest_y)
          petal.moveAngle(t_boom, 16, rand(1080))
          petal.moveOpacity(t_boom + 6, 6, 0)
        end
      end
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setZoom(@end_frame - 1, 100)
    up.setZ(@end_frame - 1, orig_uz)
    
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    tp.setZoom(@end_frame - 1, 100)
    tp.setZ(@end_frame - 1, orig_tz)

    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac; ts.opacity = @ts_orig_opac
      us.visible = true; ts.visible = true 
    })
  end
end