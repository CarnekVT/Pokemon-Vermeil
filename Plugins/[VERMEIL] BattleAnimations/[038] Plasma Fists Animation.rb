#===============================================================================
# [VERMEIL] BattleAnimations - Plasma Fists (Zeraora Signature)
# Concept: SwSh Accurate. Ground punch eruption, Freeze-frame dash, Nuclear impact.
# Update: Fixed Z-Index Bug (Opponent becoming invisible behind the background).
#===============================================================================

class Battle::Scene::Animation::VermeilPlasmaFists < Battle::Scene::Animation
  
  HANDLED_MOVES = [:PLASMAFISTS]
  BEHAVIOR = :cinematic

  def initialize(sprites, viewport, user, target, move_id = :PLASMAFISTS)
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

    target_z = (ts.z rescue 300) + 10
    user_z   = target_z + 40

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y

    @end_frame = 70
    t_eruption = 6
    t_dash = 16
    t_imp = 20

    plasma_bg = "Graphics/Animations/PRAS- Plasma Fist BG.png"
    plasma_fx = "Graphics/Animations/PRAS- Plasma Fist.png"

    dist_x = (f_dir == 1) ? 50 : 100 
    dist_y = (f_dir == 1) ? 10 : -15 
    dash_x = orig_tx - (dist_x * f_dir)
    dash_y = orig_ty + dist_y
    zoom_target = (f_dir == 1) ? 75 : 130 

    # 1. FONDO ELÉCTRICO OSCURO (Enviado al Z -20 para que no tape al oponente)
    if pbResolveBitmap(plasma_bg)
      bg = addNewSprite(Graphics.width/2, Graphics.height/2, plasma_bg, PictureOrigin::CENTER)
      bg.setZ(0, target_z - 20); bg.setOpacity(0, 0); bg.setZoom(0, 150)
      bg.moveOpacity(0, 6, 255) 
      bg.moveOpacity(t_imp + 25, 15, 0)
    end

    # 2. WINDUP
    up.setSE(0, "Anim/Wind1", 100, 120)
    up.moveXY(0, 4, orig_ux, orig_uy - 40) 
    up.moveXY(4, 2, orig_ux, orig_uy + 10) 
    
    # 3. ERUPCIÓN DE PLASMA DESDE EL SUELO
    up.setSE(t_eruption, "Anim/Thunder2", 100, 100)
    up.setSE(t_eruption, "Anim/Earth1", 100, 150)
    up.moveTone(t_eruption, 4, Tone.new(0, 150, 255, 150))
    8.times { |i| up.moveDelta(t_eruption + i, 1, (i.even? ? 6 : -6), 0) }

    if pbResolveBitmap(plasma_fx)
      pillar = addNewSprite(orig_ux, orig_uy, plasma_fx, PictureOrigin::BOTTOM)
      pillar.setZ(0, user_z - 5)
      apply_pras_frame(pillar, plasma_fx, 0, 0, 0) 
      pillar.setBlendType(0, 1)
      pillar.setVisible(0, false); pillar.setVisible(t_eruption, true)
      pillar.setZoomXY(0, 100, 0)
      pillar.moveZoomXY(t_eruption, 4, 150, 200)
      pillar.moveOpacity(t_eruption + 8, 4, 0)

      6.times do |i|
        bolt = addNewSprite(orig_ux, orig_uy - (uh/2), plasma_fx, PictureOrigin::CENTER)
        bolt.setZ(0, user_z + 5)
        apply_pras_frame(bolt, plasma_fx, rand(5), 1, 0) 
        bolt.setAngle(0, rand(360)); bolt.setBlendType(0, 1)
        bolt.setVisible(0, false); bolt.setVisible(t_eruption + i, true)
        bolt.setZoom(0, 100 + rand(50)); bolt.moveOpacity(t_eruption + i + 4, 3, 0)
      end
    end

    # 4. DASH HIPERVELOZ (Z-Index del oponente seteado a -2 para estar delante del fondo)
    up.setSE(t_dash, "Anim/Wind1", 100, 200)
    
    up.setZ(t_dash, target_z - 2) if f_dir == -1 
    
    up.moveXY(t_dash, 2, dash_x, dash_y)
    up.moveZoom(t_dash, 2, zoom_target)

    # 5. PUÑO Y FREEZE-FRAME
    if pbResolveBitmap(plasma_fx)
      fist = addNewSprite(dash_x + (20 * f_dir), i_y, plasma_fx, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
      apply_pras_frame(fist, plasma_fx, 3, 0, 0) 
      fist.setAngle(0, f_dir == 1 ? 0 : 180)
      fist.setVisible(0, false); fist.setVisible(t_dash + 2, true); fist.setZoom(0, 250)
      fist.moveXY(t_dash + 2, 2, i_x, i_y); fist.moveOpacity(t_imp + 4, 4, 0)
    end
    
    t_nuke = t_imp + 2 

    # 6. EXPLOSIÓN NUCLEAR ELÉCTRICA
    tp.setSE(t_nuke, "Anim/Thunder3", 100, 80)
    tp.setSE(t_nuke + 2, "Anim/Super Damage", 100, 100)
    tp.setSE(t_nuke + 6, "Anim/Thunder1", 100, 90)
    
    flash = addSprite(make_black_sprite, PictureOrigin::TOP_LEFT)
    flash.setZ(0, 999); flash.setTone(0, Tone.new(255, 255, 255, 0))
    flash.setOpacity(0, 0); flash.moveOpacity(t_nuke, 1, 255); flash.moveOpacity(t_nuke + 4, 10, 0)

    tp.moveColor(t_nuke, 2, Color.new(0, 255, 255, 255)); tp.moveColor(t_nuke + 8, 8, Color.new(0,0,0,0))
    tp.moveXY(t_nuke, 2, orig_tx + (70 * f_dir), orig_ty) 
    16.times { |i| tp.moveDelta(t_nuke + i, 1, (i.even? ? 20 : -20) * f_dir, 0) } 
    tp.moveXY(t_nuke + 16, 6, orig_tx, orig_ty)

    if pbResolveBitmap(plasma_fx)
      boom = addNewSprite(i_x, i_y, plasma_fx, PictureOrigin::CENTER); boom.setZ(0, target_z + 16)
      apply_pras_frame(boom, plasma_fx, 0, 2, 0) 
      boom.setBlendType(0, 1)
      boom.setVisible(0, false); boom.setVisible(t_nuke, true); boom.setZoom(0, 200)
      
      5.times { |f| apply_pras_frame(boom, plasma_fx, f, 2, t_nuke + (f * 2)) }
      boom.moveZoom(t_nuke, 10, 500); boom.moveOpacity(t_nuke + 10, 6, 0) 

      10.times do |i|
        r_bolt = addNewSprite(i_x, i_y, plasma_fx, PictureOrigin::CENTER); r_bolt.setZ(0, target_z + 17)
        apply_pras_frame(r_bolt, plasma_fx, rand(5), 1, 0) 
        r_bolt.setBlendType(0, 1); r_bolt.setAngle(0, rand(360))
        r_bolt.setVisible(0, false); r_bolt.setVisible(t_nuke + rand(4), true)
        r_bolt.setZoom(0, 80); r_bolt.moveZoom(t_nuke, 8, 200 + rand(150))
        r_bolt.moveXY(t_nuke, 8, i_x + (rand(240)-120), i_y + (rand(240)-120))
        r_bolt.moveOpacity(t_nuke + 6, 4, 0)
      end
    end

    # Reset
    up.moveTone(t_nuke + 10, 8, Tone.new(0,0,0,0))
    up.moveXY(t_nuke + 10, 8, orig_ux, orig_uy)
    up.moveZoom(t_nuke + 10, 8, 100)
    up.setZ(t_nuke + 10, user_z)

    # Failsafes
    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    up.setZoom(@end_frame - 1, 100)
    up.setZ(@end_frame - 1, user_z)
    
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    tp.setZoom(@end_frame - 1, 100)
    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end