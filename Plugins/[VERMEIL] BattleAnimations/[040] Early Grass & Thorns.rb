#===============================================================================
# [VERMEIL] BattleAnimations - Early Grass & Thorns v15.1
# Includes: Reactive Thorn (Roots start at frame 1 to avoid crack, 1.5x scale vs player), 
#           Razor Leaf (Fixed missing Anim/ prefix for Cut SE), 
#           Magical Leaf (Moderated impact bolitas)
#===============================================================================

class Battle::Scene::Animation::VermeilEarlyGrass < Battle::Scene::Animation
  
  HANDLED_MOVES = [:REACTIVETHORN, :RAZORLEAF, :BULLETSEED, :MAGICALLEAF]
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
    # f_dir: 1 si el usuario es el jugador (aprox), -1 si es el oponente.
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    target_z = (ts.z rescue 300) + 10
    user_z   = target_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM)
    up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM)
    tp.setZ(0, target_z)
    us.visible = false
    ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40
    th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x
    i_y = ts.y - th
    orig_ux = us.x
    orig_uy = us.y
    orig_tx = ts.x
    orig_ty = ts.y

    @end_frame = 60

    # ASSETS EXACTOS
    needle_asset = "Graphics/Animations/PRAS- Needle Arm.png"
    leaf_asset   = "Graphics/Animations/PRAS- Grass.png"
    magic_asset  = "Graphics/Animations/PRAS- Magical Leaf.png"
    frenzy_asset = "Graphics/Animations/PRAS- Frenzy Plant.png"

    case @move_id
    when :REACTIVETHORN
      # 🎯 ESPINA REACTIVA
      user_atk = @user.respond_to?(:attack) ? @user.attack : 0
      user_spatk = @user.respond_to?(:spatk) ? @user.spatk : 0
      is_physical = user_atk >= user_spatk
      @end_frame = 75

      # 0. INICIO COMÚN: Análisis
      up.setSE(0, "Anim/PRSFX- Focus Energy", 100, 150)
      if pbResolveBitmap(needle_asset)
        analysis = addNewSprite(orig_ux + (20 * f_dir), orig_uy - (uh/2), needle_asset, PictureOrigin::CENTER)
        analysis.setZ(0, user_z + 20)
        apply_pras_frame(analysis, needle_asset, 0, 0, 0)
        analysis.setAngle(0, f_dir == 1 ? 0 : 180)
        analysis.setVisible(0, false)
        analysis.setVisible(0, true)
        analysis.setZoom(0, 0)
        analysis.moveZoom(0, 4, 100)
        analysis.moveOpacity(6, 4, 0)
      end

      # RAÍCES: Crecen del SUELO LITERAL
      t_roots = 4
      if pbResolveBitmap(frenzy_asset)
        up.setSE(t_roots, "Anim/PRSFX- Spiky Shield2", 100, 120)
        
        # Factor de escala: 1.5x si el usuario es oponente (f_dir -1), 1.0x si no.
        root_mul = (f_dir == -1) ? 1.5 : 1.0
        
        # Raíz principal (SIN GRIETA: Inicia en frame 1)
        vine1 = addNewSprite(orig_tx, orig_ty - 20, frenzy_asset, PictureOrigin::CENTER)
        vine1.setZ(0, target_z + 15)
        apply_pras_frame(vine1, frenzy_asset, 1, 0, 0) # Frame 1 inicial
        vine1.setVisible(0, false)
        vine1.setVisible(t_roots, true)
        vine1.setZoom(0, 140 * root_mul) # Aplicar escala
        
        # Animación frames 1 a 4
        4.times do |f|
           apply_pras_frame(vine1, frenzy_asset, f + 1, 0, t_roots + (f*2))
        end
        vine1.moveOpacity(55, 5, 0)
        
        # Raíces secundarias envolventes (SIN GRIETA: Inicia en frame 1)
        root_zoom_sec = 110 * root_mul
        2.times do |j|
           vine2 = addNewSprite(orig_tx + ((j == 0 ? -35 : 35)), orig_ty - 10, frenzy_asset, PictureOrigin::CENTER)
           vine2.setZ(0, target_z + 16 + j)
           apply_pras_frame(vine2, frenzy_asset, 1, 2, 0) # Frame 1 inicial
           vine2.setVisible(0, false)
           vine2.setVisible(t_roots + 2, true)
           
           # Aplicar escala y espejo matemático
           vine2.setZoomXY(0, j == 0 ? root_zoom_sec : -root_zoom_sec, root_zoom_sec)
           vine2.setAngle(0, j == 0 ? 10 : -10)
           
           # Animación frames 1 a 4
           4.times do |f|
             apply_pras_frame(vine2, frenzy_asset, f + 1, 2, t_roots + 2 + (f*2))
           end
           vine2.moveOpacity(55, 5, 0)
        end
      end

      if is_physical
        # === RUTA FÍSICA ===
        t_form = 10
        if pbResolveBitmap(needle_asset) && pbResolveBitmap(magic_asset)
          thorns = []
          4.times do |i|
            offset_x = (i - 1.5) * 35 
            spawn_x = i_x + offset_x
            spawn_y = i_y - 80 
            thorn = addNewSprite(spawn_x, spawn_y, needle_asset, PictureOrigin::CENTER)
            thorn.setZ(0, target_z + 25)
            apply_pras_frame(thorn, needle_asset, 0, 0, 0)
            
            angle = -90 
            if i == 0; angle = -60; elsif i == 3; angle = -120; end
            thorn.setAngle(0, angle)
            
            thorn.setVisible(0, false)
            thorn.setVisible(t_form, true)
            thorn.setZoom(0, 0)
            thorn.moveZoom(t_form, 4, 100)
            thorns << thorn
          end

          4.times do |i|
            t_atk = t_form + 6 + (i * 6)
            thorns[i].moveDelta(t_atk, 3, 0, -25)
            
            t_impact = t_atk + 3
            up.setSE(t_impact, "Anim/PRSFX- Cut", 90, 140)
            
            impact_x = i_x + ((i - 1.5) * 5)
            thorns[i].moveXY(t_impact, 2, impact_x, i_y)
            thorns[i].moveOpacity(t_impact, 2, 0)
            
            # Sacudida bidireccional (Baja y Sube para no desfasar al sprite)
            tp.moveDelta(t_impact, 1, 0, 8)
            tp.moveDelta(t_impact + 1, 1, 0, -8)
            
            # Partículas de daño pequeñas
            3.times do |k|
              spark = addNewSprite(impact_x, i_y, magic_asset, PictureOrigin::CENTER)
              spark.setZ(0, target_z + 30 + k)
              apply_pras_frame(spark, magic_asset, 3, 3, 0) # Estrella impacto
              spark.setTone(0, Tone.new(-20, 120, -20, 0)) # Verde militar
              spark.setVisible(0, false); spark.setVisible(t_impact, true)
              spark.setZoom(0, 30 + rand(20))
              spark.moveXY(t_impact, 4, impact_x + (rand(60)-30), i_y + (rand(60)-30))
              spark.moveOpacity(t_impact + 2, 3, 0)
            end
          end

          # ESPINA FINAL GIGANTE FÍSICA
          t_fin = t_form + 32
          fin_thorn = addNewSprite(i_x, i_y - 100, needle_asset, PictureOrigin::CENTER) 
          fin_thorn.setZ(0, target_z + 30)
          apply_pras_frame(fin_thorn, needle_asset, 0, 0, 0)
          fin_thorn.setAngle(0, -90)
          fin_thorn.setVisible(0, false)
          fin_thorn.setVisible(t_fin, true)
          fin_thorn.setZoom(0, 0)
          fin_thorn.moveZoom(t_fin, 4, 200) 
          fin_thorn.moveDelta(t_fin + 4, 8, 0, -60)
          
          t_smash = t_fin + 12
          up.setSE(t_smash, "Anim/PRSFX- Focus Punch2", 100, 100)
          fin_thorn.moveXY(t_smash, 2, i_x, i_y + 20)
          fin_thorn.moveOpacity(t_smash + 2, 4, 0)
          
          tp.moveColor(t_smash, 2, Color.new(255, 100, 100, 200))
          tp.moveColor(t_smash + 4, 4, Color.new(0,0,0,0))
          10.times { |i| tp.moveDelta(t_smash + i, 1, 0, (i.even? ? 15 : -15)) }
          
          # Explosión de partículas gigantes
          8.times do |k|
            spark = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER)
            spark.setZ(0, target_z + 40 + k)
            apply_pras_frame(spark, magic_asset, 3, 3, 0) 
            spark.setTone(0, Tone.new(-20, 150, -20, 0)) 
            spark.setVisible(0, false); spark.setVisible(t_smash, true)
            spark.setZoom(0, 50 + rand(40))
            spark.moveXY(t_smash, 5, i_x + (rand(120)-60), i_y + (rand(120)-60))
            spark.moveOpacity(t_smash + 3, 3, 0)
          end
          
          # Retorno Forzado
          tp.moveXY(t_smash + 12, 2, orig_tx, orig_ty)
        end

      else
        # === RUTA ESPECIAL ===
        t_volley = 10
        if pbResolveBitmap(needle_asset) && pbResolveBitmap(magic_asset)
          5.times do |i|
            t_fire = t_volley + (i * 3)
            t_hit = t_fire + 2
            
            thorn = addNewSprite(orig_ux, orig_uy - (uh/2), needle_asset, PictureOrigin::CENTER)
            thorn.setZ(0, user_z + 10)
            apply_pras_frame(thorn, needle_asset, 0, 0, 0)
            thorn.setAngle(0, f_dir == 1 ? 0 : 180)
            thorn.setVisible(0, false)
            thorn.setVisible(t_fire, true)
            thorn.setZoom(0, 80)
            
            up.setSE(t_fire, "Anim/Wind2", 80, 150)
            
            hit_x = i_x + (rand(30)-15)
            hit_y = i_y + (rand(40)-20)
            thorn.moveXY(t_fire, 3, hit_x, hit_y)
            thorn.moveOpacity(t_fire + 3, 2, 0)
            
            tp.setSE(t_hit, "Anim/PRSFX- Cut", 80, 150)
            # Sacudida bidireccional
            tp.moveDelta(t_hit, 1, (i.even? ? 6 : -6), 0)
            tp.moveDelta(t_hit + 1, 1, (i.even? ? -6 : 6), 0)
            
            # Partículas de daño menores
            2.times do |k|
              spark = addNewSprite(hit_x, hit_y, magic_asset, PictureOrigin::CENTER)
              spark.setZ(0, target_z + 30 + k)
              apply_pras_frame(spark, magic_asset, 3, 3, 0)
              spark.setTone(0, Tone.new(50, 50, 150, 0)) # Púrpura especial
              spark.setVisible(0, false); spark.setVisible(t_hit, true)
              spark.setZoom(0, 20 + rand(20))
              spark.moveXY(t_hit, 4, hit_x + (rand(60)-30), hit_y + (rand(60)-30))
              spark.moveOpacity(t_hit + 2, 3, 0)
            end
          end

          # ESPINA FINAL ESPECIAL
          t_fin = t_volley + 18
          fin_thorn = addNewSprite(orig_ux + (30*f_dir), orig_uy - (uh/2), needle_asset, PictureOrigin::CENTER)
          fin_thorn.setZ(0, user_z + 20)
          apply_pras_frame(fin_thorn, needle_asset, 0, 0, 0)
          fin_thorn.setAngle(0, f_dir == 1 ? 0 : 180)
          fin_thorn.setVisible(0, false)
          fin_thorn.setVisible(t_fin, true)
          fin_thorn.setZoom(0, 0)
          fin_thorn.moveZoom(t_fin, 4, 200)
          fin_thorn.moveDelta(t_fin + 4, 8, -70 * f_dir, 0)
          
          t_launch = t_fin + 12
          t_lhit = t_launch + 2
          
          up.setSE(t_launch, "Anim/PRSFX- Focus Punch2", 100, 120)
          fin_thorn.moveXY(t_launch, 3, i_x, i_y)
          fin_thorn.moveOpacity(t_launch + 3, 4, 0)
          
          tp.setSE(t_lhit, "Anim/PRSFX- Cut", 100, 110)
          tp.moveColor(t_lhit, 2, Color.new(150, 100, 255, 200))
          tp.moveColor(t_lhit + 4, 4, Color.new(0,0,0,0))
          10.times { |i| tp.moveDelta(t_lhit + i, 1, (i.even? ? 12 : -12) * f_dir, 0) }
          
          # Explosión gigante especial
          8.times do |k|
            spark = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER)
            spark.setZ(0, target_z + 40 + k)
            apply_pras_frame(spark, magic_asset, 3, 3, 0) 
            spark.setTone(0, Tone.new(50, 50, 150, 0)) 
            spark.setVisible(0, false); spark.setVisible(t_lhit, true)
            spark.setZoom(0, 50 + rand(40))
            spark.moveXY(t_lhit, 5, i_x + (rand(120)-60), i_y + (rand(120)-60))
            spark.moveOpacity(t_lhit + 3, 3, 0)
          end
          
          # Retorno Forzado
          tp.moveXY(t_lhit + 10, 2, orig_tx, orig_ty)
        end
      end

    when :RAZORLEAF
      # 🍃 HOJA AFILADA
      t_spawn = 4
      t_launch = 14
      @end_frame = 45
      up.setSE(0, "Anim/Wind1", 100, 150)
      
      if pbResolveBitmap(leaf_asset) && pbResolveBitmap(magic_asset)
        6.times do |i|
          leaf = addNewSprite(orig_ux, orig_uy - (uh/2), leaf_asset, PictureOrigin::CENTER)
          leaf.setZ(0, user_z + i)
          apply_pras_frame(leaf, leaf_asset, 0, 2, 0) 
          leaf.setVisible(0, false)
          leaf.setVisible(t_spawn + i, true)
          leaf.setZoom(0, 100)
          ang = (i * 60) * Math::PI / 180
          radius = 50
          leaf.moveXY(t_spawn + i, 6, orig_ux + Math.cos(ang) * radius, orig_uy - (uh/2) + Math.sin(ang) * radius)
          leaf.moveAngle(t_spawn + i, 8, rand(360) * f_dir)

          t_fire = t_launch + i
          dest_x = i_x + (rand(40) - 20)
          dest_y = i_y + (rand(40) - 20)
          leaf.moveXY(t_fire, 4, dest_x, dest_y)
          leaf.setAngle(t_fire, f_dir == 1 ? 45 : 225) 
          leaf.moveOpacity(t_fire + 3, 2, 0)

          t_hit = t_fire + 3
          # AQUÍ ESTÁ EL ARREGLO DEL SONIDO (Agregado "Anim/")
          tp.setSE(t_hit, "Anim/PRSFX- Cut", 100, 130 + rand(20))
          tp.moveDelta(t_hit, 1, (i.even? ? 6 : -6), 0)
          
          # BOLITAS DE IMPACTO (TAMAÑO MODERADO: Verde Hoja)
          3.times do |k|
            bolita = addNewSprite(dest_x, dest_y, magic_asset, PictureOrigin::CENTER)
            bolita.setZ(0, target_z + 55 + k) 
            apply_pras_frame(bolita, magic_asset, 0, 0, 0) 
            bolita.setTone(0, Tone.new(-50, 150, -50, 0))
            bolita.setVisible(0, false)
            bolita.setVisible(t_hit, true)
            bolita.setZoom(0, 20 + rand(15))
            dir_x = (rand(80) - 40)
            dir_y = (rand(80) - 40)
            bolita.moveXY(t_hit, 5, dest_x + dir_x, dest_y + dir_y)
            bolita.moveOpacity(t_hit + 3, 3, 0) 
          end
        end
      end
      tp.moveXY(t_launch + 16, 2, orig_tx, orig_ty)

    when :BULLETSEED
      # 🌱 SEMILLADORA 
      @end_frame = 35
      t_start = 2
      seed_count = 6 
      
      if pbResolveBitmap(magic_asset)
        seed_count.times do |i|
          t_fire = t_start + (i * 2)
          t_hit = t_fire + 3
          
          up.setSE(t_fire, "Anim/Wind1", 80, 180)
          up.moveDelta(t_fire, 1, -4 * f_dir, 0) 
          
          seed = addNewSprite(orig_ux+(20*f_dir), orig_uy-(uh/2), magic_asset, PictureOrigin::CENTER)
          seed.setZ(0, user_z+10)
          apply_pras_frame(seed, magic_asset, 0, 1, 0) 
          seed.setTone(0, Tone.new(50, -50, -100, 0))
          seed.setAngle(0, rand(360))
          seed.setVisible(0, false)
          seed.setVisible(t_fire, true)
          seed.setZoom(0, 80)
          seed.moveXY(t_fire, 3, i_x, i_y)
          seed.moveOpacity(t_fire+3, 1, 0)
          
          tp.setSE(t_hit, "Anim/PRSFX- Pound", 100, 140+rand(20)) 
          tp.moveColor(t_hit, 1, Color.new(200, 255, 100, 150))
          tp.moveColor(t_hit+1, 1, Color.new(0,0,0,0))
          tp.moveDelta(t_hit, 1, (i.even? ? 8 : -8)*f_dir, 0) 
          
          # Destello principal de la semilla
          spark = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER)
          spark.setZ(0, target_z+15)
          apply_pras_frame(spark, magic_asset, 3, 3, 0)
          spark.setTone(0, Tone.new(100, 50, -50, 0)) 
          spark.setVisible(0, false)
          spark.setVisible(t_hit, true)
          spark.setZoom(0, 40)
          spark.moveZoom(t_hit, 3, 120)
          spark.moveOpacity(t_hit+2, 3, 0)
          
          # Escombro
          debris = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER)
          debris.setZ(0, target_z-5)
          apply_pras_frame(debris, magic_asset, 0, 1, 0)
          debris.setTone(0, Tone.new(50, -50, -100, 0))
          debris.setVisible(0, false)
          debris.setVisible(t_hit, true)
          debris.setZoom(0, 60)
          debris.moveDelta(t_hit, 2, (rand(30)-15), -30)
          debris.moveDelta(t_hit+2, 6, (rand(10)-5), 100)
          debris.moveAngle(t_hit, 8, rand(360))
          debris.moveOpacity(t_hit+6, 2, 0)
        end
      end
      
      t_reset = t_start + (seed_count * 2) + 2
      up.moveXY(t_reset, 6, orig_ux, orig_uy)
      tp.moveXY(t_reset, 4, orig_tx, orig_ty)

    when :MAGICALLEAF
      # 🌟 HOJA MÁGICA
      t_spawn = 4
      t_shoot = 14
      @end_frame = 45
      up.setSE(0, "Anim/Recovery", 100, 150)
      
      if pbResolveBitmap(magic_asset)
        colors = [
          Tone.new(200,-100,-100,0), 
          Tone.new(-100,200,-100,0), 
          Tone.new(-100,-100,255,0), 
          Tone.new(180,-80,180,0), 
          Tone.new(180,180,-80,0)
        ]
        
        5.times do |i|
          leaf = addNewSprite(orig_ux, orig_uy-(uh/2), magic_asset, PictureOrigin::CENTER)
          leaf.setZ(0, user_z+i)
          apply_pras_frame(leaf, magic_asset, rand(3), 1, 0)
          color = colors[i%colors.length]
          leaf.setTone(0, color) 
          leaf.setVisible(0, false)
          leaf.setVisible(t_spawn+i, true)
          leaf.setZoom(0, 100)
          
          ang = (i*72)*Math::PI/180
          radius = 50
          leaf.moveXY(t_spawn+i, 6, orig_ux+Math.cos(ang)*radius, orig_uy-(uh/2)+Math.sin(ang)*radius)
          leaf.moveAngle(t_spawn+i, 8, rand(360))
          
          t_fly = t_shoot+(i*2)
          leaf.moveXY(t_fly, 4, i_x, i_y)
          leaf.moveOpacity(t_fly+3, 2, 0)

          t_hit = t_fly+4
          tp.setSE(t_hit, "Anim/PRSFX- Cut", 100, 130+rand(20))
          tp.setSE(t_hit, "Anim/PRSFX- Air Cutter2", 90, 150) # Aseguré que aquí también diga Anim/
          tp.moveColor(t_hit, 2, Color.new(color.red+50, color.green+50, color.blue+50, 200))
          tp.moveColor(t_hit+2, 2, Color.new(0,0,0,0))
          tp.moveDelta(t_hit, 1, (i.even? ? 8 : -8), 0)
          
          # Destello principal de la magia
          impact = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER)
          impact.setZ(0, target_z+50)
          apply_pras_frame(impact, magic_asset, 3, 3, 0)
          impact.setTone(0, Tone.new(255, 255, 255, 0))
          impact.setVisible(0, false)
          impact.setVisible(t_hit, true)
          impact.setZoom(0, 50)
          impact.moveZoom(t_hit, 4, 200)
          impact.moveOpacity(t_hit+2, 4, 0)

          # BOLITAS DE IMPACTO (TAMAÑO MODERADO)
          5.times do |k|
            bolita = addNewSprite(i_x, i_y, magic_asset, PictureOrigin::CENTER)
            bolita.setZ(0, target_z + 55 + k) 
            apply_pras_frame(bolita, magic_asset, 0, 0, 0)
            bolita.setTone(0, color)
            bolita.setVisible(0, false)
            bolita.setVisible(t_hit, true)
            bolita.setZoom(0, 30 + rand(15))
            
            dir_x = (rand(100) - 50)
            dir_y = (rand(100) - 50)
            bolita.moveXY(t_hit, 5, i_x + dir_x, i_y + dir_y)
            bolita.moveOpacity(t_hit + 3, 3, 0) 
          end
        end
      end
      tp.moveXY(t_shoot+16, 4, orig_tx, orig_ty)
    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end