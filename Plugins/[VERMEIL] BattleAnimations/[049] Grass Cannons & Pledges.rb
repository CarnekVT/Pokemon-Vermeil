#===============================================================================
# [VERMEIL] BattleAnimations - Grass Cannons & Pledges v5.0 (FINAL)
# Includes: Energy Ball, Chloroblast, Grass Pledge
# Fix: Natural SolarCharge-style suction for Energy Ball.
#      SolarBeam-style devastating orb torrent for Chloroblast.
#      Significantly sped up Grass Pledge duration.
#===============================================================================

class Battle::Scene::Animation::VermeilGrassCannons < Battle::Scene::Animation
  HANDLED_MOVES = [:ENERGYBALL, :CHLOROBLAST, :GRASSPLEDGE]
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
    orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y
    i_x = ts.x; i_y = ts.y - th

    # CENTRO VISUAL ELEVADO (A la altura de la cara/boca)
    c_uy = orig_uy - uh - 35
    c_ty = orig_ty - th + 15

    orbs_asset    = "Graphics/Animations/PRAS- Orbs.png"
    strike_asset  = "Graphics/Animations/PRAS- Strike.png"
    tornado_asset = "Graphics/Animations/PRAS- Leaf Tornado.png"

    case @move_id
    when :ENERGYBALL
      # ENERGY BALL - Carga natural estilo Solar Charge
      t_charge = 2; t_fire = 18; t_hit = 24; @end_frame = 45
      up.setSE(t_charge, "Anim/PRSFX- Focus Energy", 100, 120)
      
      c_ux = orig_ux + (30 * f_dir)
      
      if pbResolveBitmap(orbs_asset)
        core = addNewSprite(c_ux, c_uy, orbs_asset, PictureOrigin::CENTER)
        core.setZ(0, user_z + 15)
        apply_pras_frame(core, orbs_asset, 2, 0, 0)
        core.setTone(0, Tone.new(-100, 150, -100, 0)); core.setBlendType(0, 1)
        core.setVisible(0, false); core.setVisible(t_charge, true)
        core.setZoom(0, 10); core.moveZoom(t_charge, 12, 120)
        
        # Succión suave y natural (idéntico a Solar Charge)
        30.times do |i|
          t_s = t_charge + rand(12)
          start_x = c_ux + (rand(260) - 130)
          start_y = c_uy + (rand(260) - 130)
          
          p = addNewSprite(start_x, start_y, orbs_asset, PictureOrigin::CENTER)
          p.setZ(0, user_z + 10); apply_pras_frame(p, orbs_asset, rand(2) * 2, 0, 0)
          p.setTone(0, Tone.new(-100, 150, -100, 0)); p.setBlendType(0, 1)
          p.setVisible(0, false); p.setVisible(t_s, true)
          p.setZoom(0, 40 + rand(40))
          
          p.moveXY(t_s, 6, c_ux, c_uy)
          p.moveZoom(t_s, 6, 10)
          p.moveOpacity(t_s + 4, 2, 0)
        end
        
        up.setSE(t_fire, "Anim/Wind1", 100, 150)
        core.moveXY(t_fire, 6, orig_tx, i_y)
        core.moveOpacity(t_hit, 2, 0)
      end
      
      tp.setSE(t_hit, "Anim/PRSFX- Poison", 100, 120)
      tp.moveColor(t_hit, 3, Color.new(100, 255, 100, 200))
      tp.moveColor(t_hit + 4, 4, Color.new(0,0,0,0))
      8.times { |i| tp.moveXY(t_hit + i, 1, orig_tx + (i.even? ? 8 : -8), orig_ty) }
      tp.moveXY(t_hit + 8, 1, orig_tx, orig_ty)
      
      if pbResolveBitmap(orbs_asset)
        15.times do |i|
          sp = addNewSprite(orig_tx, i_y, orbs_asset, PictureOrigin::CENTER)
          sp.setZ(0, target_z + 20); apply_pras_frame(sp, orbs_asset, 2, 0, 0)
          sp.setTone(0, Tone.new(-100, 150, -100, 0)); sp.setBlendType(0, 1)
          sp.setVisible(0, false); sp.setVisible(t_hit, true); sp.setZoom(0, 60 + rand(50))
          sp.moveXY(t_hit, 6, orig_tx + (rand(160)-80), i_y + (rand(160)-80))
          sp.moveOpacity(t_hit + 3, 3, 0)
        end
      end

    when :CHLOROBLAST
      # CHLOROBLAST - Láser Masivo Destructor estilo Solar Beam
      t_charge = 2; t_fire = 16; t_hit = 18; @end_frame = 55
      
      bg_dim = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
      bg_dim.setZ(0, target_z - 10)
      bg_dim.setOpacity(0, 0)
      bg_dim.moveOpacity(t_charge, 8, 200)
      bg_dim.moveOpacity(t_hit + 15, 6, 0)
      
      up.setSE(t_charge, "Anim/Absorb2", 100, 150)
      up.setSE(t_charge + 4, "Anim/Thunder1", 100, 180)
      up.moveColor(t_charge, 8, Color.new(150, 255, 50, 180))
      
      # Centro del cañón (pecho)
      c_ux = orig_ux + (20 * f_dir)
      # Un poco más abajo que energy ball, simulando el cuerpo entero forzando el disparo
      c_uy2 = orig_uy - (uh * 0.7) 
      
      # Disparo - Setting de daño por retroceso (Recoil)
      up.setSE(t_fire, "Anim/Explosion", 90, 120)
      
      # El usuario se pone en rojo por el dolor del ataque
      up.moveColor(t_fire, 2, Color.new(255, 50, 50, 200))
      up.moveColor(t_fire + 2, 10, Color.new(0,0,0,0))
      
      # Sacudida brutal hacia atrás
      up.moveXY(t_fire, 2, orig_ux - (40 * f_dir), orig_uy)
      12.times { |i| up.moveXY(t_fire + 2 + i, 1, orig_ux - (40 * f_dir) + (i.even? ? 10 : -10), orig_uy) }
      up.moveXY(t_fire + 14, 6, orig_ux, orig_uy)
      
      # EL LÁSER DEVASTADOR (Torrente de orbes de energía estilo Solar Beam, pero inestable)
      if pbResolveBitmap(orbs_asset)
        angle = Math.atan2(i_y - c_uy2, orig_tx - orig_ux) * 180 / Math::PI
        
        25.times do |i|
          t_l = t_fire + (i / 2)
          orb_beam = addNewSprite(c_ux, c_uy2, orbs_asset, PictureOrigin::CENTER)
          orb_beam.setZ(0, target_z + 24 + i)
          raw_orb = @pictureSprites.last; raw_orb.ox = 96; raw_orb.oy = 96 if raw_orb
          
          apply_pras_frame(orb_beam, orbs_asset, 0, 0, 0)
          orb_beam.setTone(0, Tone.new(-50, 200, -100, 0)); orb_beam.setBlendType(0, 1)
          orb_beam.setVisible(0, false); orb_beam.setVisible(t_l, true)
          
          # Orbes masivos (Zoom gigantesco)
          orb_beam.setZoom(0, 250 + rand(100)) 
          orb_beam.setAngle(0, angle)
          
          orb_beam.moveXY(t_l, 3, orig_tx, i_y)
          orb_beam.moveOpacity(t_l + 2, 2, 0)
        end
      end
      
      # Impacto
      tp.setSE(t_hit, "Anim/PRSFX- Focus Punch2", 100, 100)
      tp.moveColor(t_hit, 3, Color.new(200, 255, 150, 255))
      tp.moveColor(t_hit + 5, 5, Color.new(0,0,0,0))
      14.times { |i| tp.moveXY(t_hit + i, 1, orig_tx + (i.even? ? 25 : -25), orig_ty) }
      tp.moveXY(t_hit + 14, 1, orig_tx, orig_ty)
      
      if pbResolveBitmap(strike_asset)
        15.times do |i|
          t_s = t_hit + rand(6)
          sp = addNewSprite(orig_tx, i_y, strike_asset, PictureOrigin::CENTER)
          sp.setZ(0, target_z + 30); apply_pras_frame(sp, strike_asset, 3, 0, 0)
          sp.setTone(0, Tone.new(-50, 200, -100, 0)); sp.setBlendType(0, 1)
          sp.setVisible(0, false); sp.setVisible(t_s, true); sp.setZoom(0, 150 + rand(150))
          sp.setAngle(0, rand(360))
          sp.moveXY(t_s, 6, orig_tx + (rand(300)-150), i_y + (rand(300)-150))
          sp.moveOpacity(t_s + 3, 3, 0)
        end
      end

    when :GRASSPLEDGE
      # GRASS PLEDGE - Ultra Rápido
      t_start = 2; @end_frame = 40
      
      up.setSE(t_start, "Anim/PRSFX- Grass Pledge2", 100, 100)
      up.moveColor(t_start, 4, Color.new(100, 255, 100, 150))
      up.moveColor(t_start + 4, 6, Color.new(0,0,0,0))
      
      if pbResolveBitmap(tornado_asset)
        # 3 Columnas [Offset X, Delay] (Tiempos mucho más cortos)
        columns = [
          [-(60 * f_dir), 0],   
          [0, 3],               
          [(60 * f_dir), 6]    
        ]
        
        columns.each do |col|
          t_col = t_start + col[1]
          col_x = orig_tx + col[0]
          
          up.setSE(t_col, "Anim/Wind1", 100, 140)
          
          # Base del Tornado (Mitad de tiempo de vida)
          tornado = addNewSprite(col_x, orig_ty - 10, tornado_asset, PictureOrigin::BOTTOM)
          tornado.setZ(0, target_z + 15)
          apply_pras_frame(tornado, tornado_asset, 0, 5, 0)
          tornado.setVisible(0, false); tornado.setVisible(t_col, true)
          tornado.setZoom(0, 160)
          
          15.times do |f|
            apply_pras_frame(tornado, tornado_asset, f % 4, 5, t_col + f)
          end
          tornado.moveOpacity(t_col + 15, 4, 0)

          # Hojas subiendo
          10.times do |i|
            leaf = addNewSprite(col_x, orig_ty - 10, tornado_asset, PictureOrigin::CENTER)
            leaf.setZ(0, target_z + 20 + i)
            apply_pras_frame(leaf, tornado_asset, rand(3), 0, 0)
            leaf.setVisible(0, false)
            
            delay = t_col + i
            leaf.setVisible(delay, true); leaf.setZoom(0, 100 + rand(50))
            
            start_x = col_x + (rand(2)==0 ? 100 : -100)
            leaf.setXY(delay, start_x, orig_ty - 10)
            # Sube más rápido (8 fotogramas)
            leaf.moveXY(delay, 8, col_x - (start_x - col_x), orig_ty - 200)
            leaf.moveAngle(delay, 8, rand(1080) * f_dir) 
            leaf.moveOpacity(delay + 6, 2, 0)
          end
        end
      end
      
      t_hit = t_start + 12
      tp.setSE(t_hit, "Anim/PRSFX- Focus Punch2", 100, 100)
      tp.moveColor(t_hit, 4, Color.new(100, 255, 100, 200))
      tp.moveColor(t_hit + 4, 6, Color.new(0,0,0,0))
      12.times { |i| tp.moveXY(t_hit + i, 1, orig_tx + (i.even? ? 15 : -15), orig_ty) }
      tp.moveXY(t_hit + 12, 1, orig_tx, orig_ty)

    end

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setCallback(@end_frame, proc { 
      us.opacity = @us_orig_opac; ts.opacity = @ts_orig_opac
      us.visible = true; ts.visible = true 
    })
  end
end