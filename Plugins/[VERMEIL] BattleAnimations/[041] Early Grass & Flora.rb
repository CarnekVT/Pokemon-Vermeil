#===============================================================================
# [VERMEIL] BattleAnimations - Early Grass & Flora v25.0
# Includes: Grass Knot (Reworked side-wrap to avoid float issues), 
#           Leaf Tornado (Base lowered), Branch Poke, 
#           Trailblaze (Fixed trail path for opponent), 
#           Leafage, Snap Trap (Fixed bottom jaw to Row 5 Col 4), 
#           Syrup Bomb (Safe species check, perfect parabola), 
#           Grassy Glide, Needle Arm.
#===============================================================================

class Battle::Scene::Animation::VermeilEarlyGrassFlora < Battle::Scene::Animation
  
  HANDLED_MOVES = [:GRASSKNOT, :LEAFTORNADO, :BRANCHPOKE, :TRAILBLAZE, :LEAFAGE, 
                   :SNAPTRAP, :SYRUPBOMB, :GRASSYGLIDE, :NEEDLEARM]
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

    knot_asset    = "Graphics/Animations/PRAS- Grass Knot.png"
    leaf_asset    = "Graphics/Animations/PRAS- Grass.png"
    frenzy_asset  = "Graphics/Animations/PRAS- Frenzy Plant.png"
    magic_asset   = "Graphics/Animations/PRAS- Magical Leaf.png"
    needle_asset  = "Graphics/Animations/PRAS- Needle Arm.png"
    tornado_asset = "Graphics/Animations/PRAS- Leaf Tornado.png"
    fangs_asset   = "Graphics/Animations/PRAS- Elemental Fangs.png"
    syrup_asset   = "Graphics/Animations/Gen 9 - Syrup Bomb.png"

    case @move_id
    when :GRASSKNOT
      # GRASS KNOT (Animación estilo Vine Whip: Súper rápida y fluida)
      hit_times  = [2, 8, 14] # Tiempos mucho más juntos
      t_finisher = 20
      @end_frame = 50
      
      up.setSE(0, "Anim/Absorb2", 100, 150)
      
      if pbResolveBitmap(leaf_asset)
        play_lash = proc do |t_hit, heavy|
          lash = addNewSprite(i_x, i_y, leaf_asset, PictureOrigin::CENTER)
          lash.setZ(0, target_z + 20)
          apply_pras_frame(lash, leaf_asset, 0, 1, 0) # Fila 1 = Animación de Vine Whip
          lash.setVisible(0, false)
          lash.setVisible(t_hit, true)
          lash.setZoomXY(0, f_dir == 1 ? 130 : -130, 130)
          lash.setSE(t_hit, "Anim/PRSFX- Vine Whip", 100, 110)

          if heavy
            # Golpe pesado: 2 ticks por frame
            5.times do |j|
              apply_pras_frame(lash, leaf_asset, j, 1, t_hit + (j * 2))
            end
            lash.moveZoomXY(t_hit + 1, 3, f_dir == 1 ? 190 : -190, 175)
            lash.moveOpacity(t_hit + 8, 4, 0)
          else
            # Golpes normales: 1 tick por frame (doble velocidad)
            5.times do |j|
              apply_pras_frame(lash, leaf_asset, j, 1, t_hit + j)
            end
            lash.setVisible(t_hit + 6, false)
          end
        end

        # Disparamos la ráfaga
        hit_times.each { |t| play_lash.call(t, false) }
        play_lash.call(t_finisher, true)
      end

      # Impactos visuales acelerados para los golpes normales
      hit_times.each do |t_hit|
        t_imp = t_hit + 2 # Impacta casi al instante
        up.moveDelta(t_hit, 2, 8 * f_dir, 0)
        up.moveDelta(t_hit + 2, 2, -8 * f_dir, 0)
        
        tp.setSE(t_imp, "Anim/PRSFX- Slash2", 90, 110)
        tp.moveTone(t_imp, 2, Tone.new(0, 80, 0, 0))
        tp.moveTone(t_imp + 2, 2, Tone.new(0, 0, 0, 0))
        
        tp.moveDelta(t_imp, 1, 10 * f_dir, 0)
        tp.moveDelta(t_imp + 1, 2, -20 * f_dir, 0)
        tp.moveDelta(t_imp + 3, 1, 10 * f_dir, 0)
      end

      # Impacto masivo para el golpe final
      t_big = t_finisher + 4
      up.moveDelta(t_finisher, 2, 12 * f_dir, 0)
      up.moveDelta(t_finisher + 2, 3, -12 * f_dir, 0)
      
      tp.setSE(t_big, "Anim/PRSFX- Pound", 100, 100)
      tp.setSE(t_big, "Anim/PRSFX- Leafage 2", 100, 130)
      
      tp.moveColor(t_big, 2, Color.new(100, 255, 100, 180))
      tp.moveColor(t_big + 4, 4, Color.new(0, 0, 0, 0))
      tp.moveTone(t_big, 2, Tone.new(0, 100, 0, 0))
      tp.moveTone(t_big + 2, 4, Tone.new(0, 0, 0, 0))
      
      # Sacudida destructiva y rápida
      tp.moveDelta(t_big, 1, 20 * f_dir, 0)
      tp.moveDelta(t_big + 1, 2, -40 * f_dir, 0)
      tp.moveDelta(t_big + 3, 1, 20 * f_dir, 0)
      tp.moveDelta(t_big + 4, 1, -16 * f_dir, 0)
      tp.moveDelta(t_big + 5, 1, 16 * f_dir, 0)
      tp.moveXY(t_big + 8, 4, orig_tx, orig_ty)
      
      tp.moveZoom(t_big, 2, 88)
      tp.moveZoom(t_big + 2, 4, 100)

      # Partículas de daño 
      if pbResolveBitmap(magic_asset) && pbResolveBitmap(leaf_asset)
        impact = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER)
        impact.setZ(0, target_z + 30)
        apply_pras_frame(impact, magic_asset, 3, 3, 0)
        impact.setTone(0, Tone.new(50, 200, 50, 0))
        impact.setVisible(0, false); impact.setVisible(t_big, true)
        impact.setZoom(0, 55); impact.moveZoom(t_big, 3, 185)
        impact.moveOpacity(t_big + 2, 4, 0)

        10.times do
          leaf = addNewSprite(i_x, i_y, leaf_asset, PictureOrigin::CENTER)
          leaf.setZ(0, target_z + 35)
          apply_pras_frame(leaf, leaf_asset, rand(5), 1, 0) 
          leaf.setVisible(0, false); leaf.setVisible(t_big, true)
          leaf.setZoom(0, 50)
          leaf.moveDelta(t_big, 6, (rand(150)-75), (rand(130)-65))
          leaf.moveAngle(t_big, 6, rand(360))
          leaf.moveOpacity(t_big + 3, 3, 0)
        end
      end

    when :LEAFTORNADO
      # LEAF TORNADO (Mas abajo para no quedar volando)
      t_start = 4; t_impact = 20; @end_frame = 45
      up.setSE(0, "Anim/Wind1", 100, 140)
      
      if pbResolveBitmap(tornado_asset)
        # orig_ty - 10 para estar al nivel de los pies
        tornado = addNewSprite(orig_tx, orig_ty - 10, tornado_asset, PictureOrigin::BOTTOM)
        tornado.setZ(0, target_z + 15)
        apply_pras_frame(tornado, tornado_asset, 0, 5, 0)
        tornado.setVisible(0, false); tornado.setVisible(t_start, true)
        tornado.setZoom(0, 160)
        
        30.times do |f|
          apply_pras_frame(tornado, tornado_asset, f % 4, 5, t_start + f)
        end
        tornado.moveOpacity(t_start + 25, 5, 0)

        10.times do |i|
          leaf = addNewSprite(orig_tx, orig_ty - 10, tornado_asset, PictureOrigin::CENTER)
          leaf.setZ(0, target_z + 20 + i)
          apply_pras_frame(leaf, tornado_asset, rand(3), 0, 0)
          leaf.setVisible(0, false)
          
          delay = t_start + i
          leaf.setVisible(delay, true); leaf.setZoom(0, 100 + rand(50))
          
          start_x = orig_tx + (rand(2)==0 ? 100 : -100)
          leaf.setXY(delay, start_x, orig_ty - 10)
          leaf.moveXY(delay, 12, orig_tx - (start_x - orig_tx), orig_ty - 200)
          leaf.moveAngle(delay, 12, rand(1440) * f_dir) 
          leaf.moveOpacity(delay + 8, 4, 0)
        end
      end
      
      6.times do |i|
        t_hit = t_start + 4 + (i*3)
        tp.setSE(t_hit, "Anim/PRSFX- Cut", 90, 160 + rand(20))
        tp.moveColor(t_hit, 1, Color.new(150, 255, 150, 150))
        tp.moveColor(t_hit + 1, 1, Color.new(0,0,0,0))
        tp.moveDelta(t_hit, 1, (i.even? ? 8 : -8), 0)
      end

    when :BRANCHPOKE
      # BRANCH POKE
      t_aim = 4; t_poke = 10; @end_frame = 30
      up.moveXY(0, t_aim, orig_ux + (20 * f_dir), orig_uy)
      up.setSE(t_aim, "Anim/Wind1", 100, 180)
      
      if pbResolveBitmap(frenzy_asset)
        branch = addNewSprite(orig_ux + (30 * f_dir), orig_uy - (uh/2), frenzy_asset, PictureOrigin::CENTER)
        branch.setZ(0, user_z + 10)
        apply_pras_frame(branch, frenzy_asset, 0, 1, 0)
        
        dx = i_x - (orig_ux + (30 * f_dir))
        dy = i_y - (orig_uy - (uh/2))
        angle = Math.atan2(dy, dx) * 180.0 / 3.14159
        angle += 180 if f_dir == -1 
        
        branch.setAngle(0, angle)
        branch.setVisible(0, false); branch.setVisible(t_aim, true)
        branch.setZoom(0, 160)
        
        branch.moveXY(t_poke, 2, i_x, i_y); branch.moveOpacity(t_poke + 3, 2, 0)
      end
      
      tp.setSE(t_poke, "Anim/PRSFX- Pound", 100, 130); tp.setSE(t_poke, "Anim/PRSFX- Tackle", 100, 150)
      tp.moveDelta(t_poke, 2, 10 * f_dir, 0); tp.moveDelta(t_poke + 2, 2, -10 * f_dir, 0)
      tp.moveColor(t_poke, 2, Color.new(255, 200, 100, 150)); tp.moveColor(t_poke + 2, 2, Color.new(0,0,0,0))
      
      if pbResolveBitmap(magic_asset) && pbResolveBitmap(leaf_asset)
        impact = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER); impact.setZ(0, target_z+30)
        apply_pras_frame(impact, magic_asset, 3, 3, 0); impact.setTone(0, Tone.new(50, 150, 50, 0))
        impact.setVisible(0, false); impact.setVisible(t_poke, true); impact.setZoom(0, 60)
        impact.moveZoom(t_poke, 4, 130); impact.moveOpacity(t_poke+2, 4, 0)
        
        6.times do |i|
          leaf = addNewSprite(i_x, i_y, leaf_asset, PictureOrigin::CENTER); leaf.setZ(0, target_z+35)
          apply_pras_frame(leaf, leaf_asset, 0, 2, 0)
          leaf.setVisible(0, false); leaf.setVisible(t_poke, true); leaf.setZoom(0, 40)
          leaf.moveDelta(t_poke, 6, (rand(100)-50), (rand(100)-50))
          leaf.moveAngle(t_poke, 6, rand(360))
          leaf.moveOpacity(t_poke+2, 4, 0)
        end
      end
      up.moveXY(t_poke + 4, 4, orig_ux, orig_uy)

    when :TRAILBLAZE
      # TRAILBLAZE (Zoom y Z consistentes toda la animación)
      t_dash = 4; t_hit = 8; t_ret = 25; @end_frame = 40
      up.setSE(0, "Anim/Wind1", 100, 160)
      
      # Z fijo desde el frame 0 para evitar saltos de capa
      z_dash = (f_dir == 1) ? target_z + 20 : target_z - 5
      up.setZ(0, z_dash)
      
      # Lógica Sucker Punch Zoom (jugador retrocede visualmente, oponente avanza)
      zoom_target = (f_dir == 1) ? 66 : 150
      up.moveZoom(t_dash, 4, zoom_target)
      
      dest_x = orig_tx + (40 * f_dir)
      dest_y = orig_ty + 20
      up.moveXY(t_dash, 4, dest_x, dest_y)
      
      if pbResolveBitmap(leaf_asset) && pbResolveBitmap(magic_asset)
        6.times do |i|
          t_drop = t_dash + (i/2.0).round
          leaf = addNewSprite(orig_ux, orig_ty, leaf_asset, PictureOrigin::CENTER)
          leaf.setZ(0, target_z - 5)
          apply_pras_frame(leaf, leaf_asset, rand(2), 2, 0)
          leaf.setVisible(0, false); leaf.setVisible(t_drop, true); leaf.setZoom(0, 70)
          
          dist_x = dest_x - orig_ux
          dist_y = dest_y - orig_ty
          trail_x = orig_ux + (dist_x * (i/5.0))
          trail_y = orig_ty + (dist_y * (i/5.0))
          
          leaf.setXY(t_drop, trail_x, trail_y)
          leaf.moveDelta(t_drop+1, 4, 0, -30)
          leaf.moveOpacity(t_drop + 5, 4, 0)
        end
        
        tp.setSE(t_hit, "Anim/PRSFX- Pound", 100, 110); tp.setSE(t_hit, "Anim/PRSFX- Cut", 100, 130)
        impact = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER); impact.setZ(0, target_z+30)
        apply_pras_frame(impact, magic_asset, 3, 3, 0); impact.setTone(0, Tone.new(50, 200, 50, 0))
        impact.setVisible(0, false); impact.setVisible(t_hit, true); impact.setZoom(0, 80)
        impact.moveZoom(t_hit, 4, 180); impact.moveOpacity(t_hit+2, 4, 0)
      end
      
      tp.moveDelta(t_hit, 2, 20 * f_dir, 0); tp.moveDelta(t_hit + 2, 2, -20 * f_dir, 0)
      tp.moveColor(t_hit, 2, Color.new(150, 255, 100, 150)); tp.moveColor(t_hit + 2, 2, Color.new(0,0,0,0))
      
      up.moveColor(t_hit, 4, Color.new(100, 255, 100, 150)); up.moveColor(t_hit + 4, 4, Color.new(0,0,0,0))
      
      up.moveXY(t_ret, 6, orig_ux, orig_uy)
      up.moveZoom(t_ret, 6, 100)
      up.setZ(@end_frame - 1, user_z)

    when :LEAFAGE
      # LEAFAGE
      t_spawn = 2; t_impact = 14; @end_frame = 30
      up.setSE(0, "Anim/Wind1", 100, 180)
      
      if pbResolveBitmap(magic_asset) && pbResolveBitmap(leaf_asset)
        3.times do |i|
          t_fire = t_spawn + (i * 2)
          
          ball = addNewSprite(orig_ux + (20*f_dir), orig_uy - (uh/2), magic_asset, PictureOrigin::CENTER)
          ball.setZ(0, user_z + 10 + i); apply_pras_frame(ball, magic_asset, 0, 0, 0)
          ball.setTone(0, Tone.new(-50, 150, -50, 0))
          ball.setVisible(0, false); ball.setVisible(t_fire, true); ball.setZoom(0, 60)
          
          target_off_x = i_x + (i==1 ? 20 : (i==2 ? -20 : 0))
          target_off_y = i_y + (i==0 ? -10 : 10)
          
          ball.moveXY(t_fire, 6, target_off_x, target_off_y)
          ball.moveOpacity(t_fire + 5, 2, 0)
          
          2.times do |k|
            leaf = addNewSprite(orig_ux + (20*f_dir), orig_uy - (uh/2), leaf_asset, PictureOrigin::CENTER)
            leaf.setZ(0, user_z + 5); apply_pras_frame(leaf, leaf_asset, rand(2), 2, 0)
            leaf.setVisible(0, false); leaf.setVisible(t_fire, true); leaf.setZoom(0, 60)
            leaf.moveXY(t_fire, 6, target_off_x + (rand(40)-20), target_off_y + (rand(40)-20))
            leaf.moveAngle(t_fire, 6, rand(360)*f_dir)
            leaf.moveOpacity(t_fire + 5, 2, 0)
          end
          
          t_hit = t_fire + 5
          tp.setSE(t_hit, "Anim/PRSFX- Cut", 90, 160)
          tp.moveDelta(t_hit, 1, (i.even? ? 4 : -4), 0)
          
          tp.moveColor(t_hit, 2, Color.new(100, 255, 100, 180))
          tp.moveColor(t_hit + 2, 2, Color.new(0,0,0,0))
          
          impact = addNewSprite(target_off_x, target_off_y, magic_asset, PictureOrigin::CENTER)
          impact.setZ(0, target_z + 20); apply_pras_frame(impact, magic_asset, 3, 3, 0)
          impact.setTone(0, Tone.new(-50, 150, -50, 0))
          impact.setVisible(0, false); impact.setVisible(t_hit, true); impact.setZoom(0, 40)
          impact.moveZoom(t_hit, 3, 80); impact.moveOpacity(t_hit+1, 2, 0)
        end
      end

    when :SNAPTRAP
      # SNAP TRAP (Mandíbula inferior ajustada a la izquierda)
      t_spawn = 2; t_snap = 10; @end_frame = 40
      up.setSE(0, "Anim/PRSFX- Focus Energy", 100, 150)
      
      if pbResolveBitmap(fangs_asset) && pbResolveBitmap(magic_asset)
        2.times do |i|
          dust = addNewSprite(orig_tx + (rand(20)-10), orig_ty, magic_asset, PictureOrigin::BOTTOM)
          dust.setZ(0, target_z - 5); apply_pras_frame(dust, magic_asset, 0, 1, 0)
          dust.setTone(0, Tone.new(50, -50, -100, 0))
          dust.setVisible(0, false); dust.setVisible(t_spawn+i, true); dust.setZoom(0, 60)
          dust.moveDelta(t_spawn+i, 4, 0, -20); dust.moveOpacity(t_spawn+i+2, 2, 0)
        end
        
        jaw_top = addNewSprite(orig_tx, i_y - 72, fangs_asset, PictureOrigin::CENTER)
        jaw_top.setZ(0, target_z + 20)
        apply_pras_frame(jaw_top, fangs_asset, 0, 0, 0) # Frame superior
        jaw_top.setVisible(0, false); jaw_top.setVisible(t_spawn, true); jaw_top.setZoom(0, 125)

        # Ajuste a la izquierda para la mandíbula inferior
        bot_x = orig_tx
        jaw_bot = addNewSprite(bot_x, i_y + 74, fangs_asset, PictureOrigin::CENTER)
        jaw_bot.setZ(0, target_z + 21)
        apply_pras_frame(jaw_bot, fangs_asset, 0, 0, 0) # Base superior espejada
        jaw_bot.setVisible(0, false); jaw_bot.setVisible(t_spawn, true); jaw_bot.setZoomXY(0, 125, -125)
        
        up.setSE(t_snap, "Anim/PRSFX- Bite", 100, 120)
        jaw_top.moveXY(t_snap, 2, orig_tx, i_y - 18)
        jaw_bot.moveXY(t_snap, 2, bot_x, i_y + 18)
        
        3.times do |i|
          t_chew = t_snap + 2 + (i * 4)
          up.setSE(t_chew, "Anim/PRSFX- Cut", 100, 140) if i > 0
          
          jaw_top.moveXY(t_chew, 2, orig_tx, i_y - 40)
          jaw_bot.moveXY(t_chew, 2, bot_x, i_y + 40)
          
          jaw_top.moveXY(t_chew + 2, 2, orig_tx, i_y - 12)
          jaw_bot.moveXY(t_chew + 2, 2, bot_x, i_y + 12)
          
          tp.moveColor(t_chew + 2, 2, Color.new(255, 50, 50, 200))
          tp.moveColor(t_chew + 4, 2, Color.new(0,0,0,0))
          tp.moveDelta(t_chew + 2, 2, (i.even? ? 10 : -10), 0)
        end
        
        jaw_top.moveOpacity(t_snap + 16, 4, 0)
        jaw_bot.moveOpacity(t_snap + 16, 4, 0)
      end

    when :SYRUPBOMB
      # SYRUP BOMB (Chequeo seguro, parabola perfecta)
      t_start = 2; @end_frame = 45
      
      # SAFE SHINY APPLE CHECK
      is_shiny_apple = false
      begin
        if @user.pokemon && [:DIPPLIN, :HYDRAPPLE].include?(@user.pokemon.species) && @user.pokemon.shiny?
          is_shiny_apple = true
        end
      rescue
      end
      
      syrup_tone = is_shiny_apple ? Tone.new(200, 180, 50, 80) : Tone.new(200, 50, 50, 0)
      
      up.setSE(0, "Anim/Wind1", 100, 150)
      up.moveDelta(0, 4, 0, 10); up.moveDelta(4, 4, 0, -10) 
      
      if pbResolveBitmap(magic_asset)
        3.times do |i|
          t_lob = t_start + (i * 4)
          t_hit = t_lob + 12
          
          bomb = addNewSprite(orig_ux, orig_uy - uh, magic_asset, PictureOrigin::CENTER)
          bomb.setZ(0, target_z + 20)
          apply_pras_frame(bomb, magic_asset, 0, 0, 0)
          bomb.setTone(0, syrup_tone)
          bomb.setVisible(0, false); bomb.setVisible(t_lob, true); bomb.setZoom(0, 60 + rand(20))
          
          hit_x = i_x + (rand(20) - 10)
          hit_y = i_y + (rand(20) - 10)
          mid_x = (orig_ux + hit_x) / 2
          mid_y = ((orig_uy - uh) + hit_y) / 2 - 120
          
          half_time = (t_hit - t_lob) / 2
          bomb.moveXY(t_lob, half_time, mid_x, mid_y)
          bomb.moveXY(t_lob + half_time, half_time, hit_x, hit_y)
          bomb.moveOpacity(t_hit, 1, 0)

          tp.setSE(t_hit, "Anim/Water1", 100, 100 + rand(30))
          tp.moveTone(t_hit, 4, Tone.new(syrup_tone.red, syrup_tone.green, syrup_tone.blue, 100))
          tp.moveTone(t_hit + 6, 4, Tone.new(0,0,0,0))
          tp.moveDelta(t_hit, 2, 0, 5); tp.moveDelta(t_hit+2, 2, 0, -5)
          
          4.times do |k|
            splat = addNewSprite(hit_x, hit_y, magic_asset, PictureOrigin::CENTER)
            splat.setZ(0, target_z + 25 + k); apply_pras_frame(splat, magic_asset, 0, 0, 0)
            splat.setTone(0, syrup_tone)
            splat.setVisible(0, false); splat.setVisible(t_hit, true); splat.setZoom(0, 20 + rand(20))
            
            dir_x = (rand(120) - 60)
            splat.moveDelta(t_hit, 8, dir_x, 40 + rand(40))
            splat.moveOpacity(t_hit + 5, 3, 0)
          end
        end
      end

    when :GRASSYGLIDE
      # GRASSY GLIDE (Zoom y Z consistentes toda la animación)
      t_dash = 2; t_hit = 8; t_ret = 20; @end_frame = 30
      up.setSE(0, "Anim/PRSFX- Focus Energy", 100, 180)
      up.moveTone(0, t_dash, Tone.new(-100, 150, -100, 100))
      
      up.setSE(t_dash, "Anim/Wind1", 100, 180)
      
      # Z fijo desde el frame 0
      z_dash = (f_dir == 1) ? target_z + 20 : target_z - 5
      up.setZ(0, z_dash)
      
      # Lógica Sucker Punch Zoom
      zoom_target = (f_dir == 1) ? 66 : 150
      up.moveZoom(t_dash, 4, zoom_target)
      
      up.moveXY(t_dash, 4, orig_tx - (40 * f_dir), orig_ty + 10)
      
      if pbResolveBitmap(magic_asset) && pbResolveBitmap(leaf_asset)
        impact = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER); impact.setZ(0, target_z+30)
        apply_pras_frame(impact, magic_asset, 3, 3, 0); impact.setTone(0, Tone.new(-50, 200, -50, 0))
        impact.setVisible(0, false); impact.setVisible(t_hit, true); impact.setZoom(0, 80)
        impact.moveZoom(t_hit, 4, 200); impact.moveOpacity(t_hit+2, 4, 0)
        
        6.times do |i|
          leaf = addNewSprite(i_x, i_y, leaf_asset, PictureOrigin::CENTER)
          leaf.setZ(0, target_z + 35); apply_pras_frame(leaf, leaf_asset, rand(2), 2, 0)
          leaf.setVisible(0, false); leaf.setVisible(t_hit, true); leaf.setZoom(0, 50)
          leaf.moveDelta(t_hit, 6, (rand(120)-60), (rand(120)-60))
          leaf.moveAngle(t_hit, 6, rand(360))
          leaf.moveOpacity(t_hit+3, 3, 0)
        end
      end
      
      tp.setSE(t_hit, "Anim/PRSFX- Tackle", 100, 110)
      tp.moveDelta(t_hit, 1, 15 * f_dir, 0); tp.moveDelta(t_hit + 1, 2, -15 * f_dir, 0)
      tp.moveColor(t_hit, 2, Color.new(100, 255, 100, 150)); tp.moveColor(t_hit + 2, 2, Color.new(0,0,0,0))
      
      up.moveXY(t_ret, 4, orig_ux, orig_uy)
      up.moveZoom(t_ret, 4, 100)
      up.moveTone(t_ret, 4, Tone.new(0,0,0,0))
      up.setZ(@end_frame - 1, user_z)
      
    when :NEEDLEARM
      # NEEDLE ARM
      t_aim = 4; t_punch = 12; @end_frame = 35
      up.setSE(0, "Anim/Wind1", 100, 120)
      up.moveXY(0, t_aim, orig_ux - (10 * f_dir), orig_uy)
      if pbResolveBitmap(needle_asset)
        fist = addNewSprite(orig_ux + (20 * f_dir), orig_uy - (uh/2), needle_asset, PictureOrigin::CENTER)
        fist.setZ(0, user_z + 20); apply_pras_frame(fist, needle_asset, 2, 0, 0)
        fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(t_aim, true)
        fist.setZoom(0, 0); fist.moveZoom(t_aim, 4, 200)
        fist.moveAngle(t_aim, 4, f_dir == 1 ? -45 : 225)
        
        up.setSE(t_punch, "Anim/Wind1", 100, 160)
        fist.moveAngle(t_punch, 2, f_dir == 1 ? 45 : 135)
        fist.moveXY(t_punch, 2, i_x, i_y); fist.moveOpacity(t_punch + 4, 4, 0)
        
        30.times do |i|
          spike = addNewSprite(i_x, i_y, needle_asset, PictureOrigin::CENTER)
          spike.setZ(0, target_z + 25); apply_pras_frame(spike, needle_asset, 0, 0, 0)
          spike.setVisible(0, false); spike.setVisible(t_punch, true)
          spike.setZoom(0, 100 + rand(40))
          
          ang = rand(360)
          spike.setAngle(0, ang)
          dist = 100 + rand(120)
          dest_sx = i_x + Math.cos(ang * 3.14159 / 180) * dist
          dest_sy = i_y + Math.sin(ang * 3.14159 / 180) * dist
          
          spike.moveXY(t_punch, 6, dest_sx, dest_sy)
          spike.moveOpacity(t_punch+4, 2, 0)
        end
      end
      tp.setSE(t_punch + 1, "Anim/PRSFX- Pound", 100, 120)
      tp.setSE(t_punch + 1, "Anim/PRSFX- Focus Punch2", 100, 130)
      tp.moveColor(t_punch + 1, 2, Color.new(200, 255, 100, 200))
      tp.moveColor(t_punch + 5, 4, Color.new(0,0,0,0))
      8.times { |i| tp.moveDelta(t_punch + 1 + i, 1, (i.even? ? 12 : -12) * f_dir, 0) }
      up.moveXY(t_punch + 6, 4, orig_ux, orig_uy)

    when :SPIKYSHIELD
      # SPIKY SHIELD (8 púas cardinales contra objetivo)
      t_start = 2; @end_frame = 40
      up.setSE(t_start, "Anim/PRSFX- Spiky Shield2", 100, 120)
      
      protect_asset = "Graphics/Animations/PRAS- Protect.png"
      spike_asset = "Graphics/Animations/PRAS- Spike Cannon.png"
      
      # Position slightly raised
      shield_y = orig_uy - (uh/2) - 20
      
      if pbResolveBitmap(protect_asset)
        shield = addNewSprite(orig_ux, shield_y, protect_asset, PictureOrigin::CENTER)
        shield.setZ(0, user_z + 20)
        apply_pras_frame(shield, protect_asset, 0, 0, 0) 
        shield.setTone(0, Tone.new(-100, 150, -100, 0)) 
        shield.setVisible(0, false); shield.setVisible(t_start, true)
        shield.setZoom(0, 50); shield.moveZoom(t_start, 4, 180)
        
        5.times do |i|
           apply_pras_frame(shield, protect_asset, i, 0, t_start + (i*2))
        end
        shield.moveOpacity(t_start + 25, 8, 0)
      end
      
      if pbResolveBitmap(spike_asset)
        8.times do |i|
          spike = addNewSprite(orig_ux, shield_y, spike_asset, PictureOrigin::CENTER)
          spike.setZ(0, user_z + 25)
          apply_pras_frame(spike, spike_asset, 0, 0, 0)
          spike.setVisible(0, false); spike.setVisible(t_start + 2, true)
          
          ang = (i * 45)
          spike.setAngle(0, ang)
          spike.setZoom(0, 150)
          
          rad = 120
          dest_x = orig_ux + Math.cos(ang * 3.14159 / 180) * rad
          dest_y = shield_y + Math.sin(ang * 3.14159 / 180) * rad
          
          spike.moveXY(t_start + 2, 6, dest_x, dest_y)
          spike.moveOpacity(t_start + 10, 4, 0)
        end
      end
      
      up.moveTone(t_start, 4, Tone.new(-50, 100, -50, 50))
      up.moveTone(t_start + 10, 6, Tone.new(0,0,0,0))

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

