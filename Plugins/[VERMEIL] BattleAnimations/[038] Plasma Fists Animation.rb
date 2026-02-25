#===============================================================================
# [VERMEIL] BattleAnimations - Plasma Fists (Zeraora Signature)
# Concept: Lightning background overlay and massive blue electric explosion.
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

    @end_frame = 55
    t_imp = 12

    plasma_bg = "Graphics/Animations/PRAS- Plasma Fist BG.png"
    plasma_fx = "Graphics/Animations/PRAS- Plasma Fist.png"

    # 1. FONDO ELÉCTRICO OSCURO
    if pbResolveBitmap(plasma_bg)
      bg = addNewSprite(Graphics.width/2, Graphics.height/2, plasma_bg, PictureOrigin::CENTER)
      bg.setZ(0, target_z - 5); bg.setOpacity(0, 0); bg.setZoom(0, 150)
      bg.moveOpacity(0, 6, 255) 
      bg.moveOpacity(t_imp + 10, 8, 0)
    end

    # 2. CARGA DE ENERGÍA (Vibración y rayos alrededor del usuario)
    up.setSE(0, "Anim/Thunder2", 100, 150)
    up.moveTone(0, 6, Tone.new(0, 100, 255, 100))
    8.times { |i| up.moveDelta(i, 1, (i.even? ? 4 : -4), 0) }

    if pbResolveBitmap(plasma_fx)
      4.times do |i|
        bolt = addNewSprite(orig_ux, orig_uy - (uh/2), plasma_fx, PictureOrigin::CENTER)
        bolt.setZ(0, user_z + 5)
        apply_pras_frame(bolt, plasma_fx, rand(5), 1, 0) # Rayos de la Fila 1
        bolt.setAngle(0, rand(360)); bolt.setBlendType(0, 1)
        bolt.setVisible(0, false); bolt.setVisible(i * 2, true)
        bolt.setZoom(0, 80 + rand(40)); bolt.moveOpacity((i * 2) + 4, 3, 0)
      end
    end

    # 3. DASH
    up.setSE(8, "Anim/Wind1", 100, 180)
    up.moveXY(8, 4, orig_ux + (20 * f_dir), orig_uy)

    # 4. PUÑO DE PLASMA (Fila 0, Columna 3)
    if pbResolveBitmap(plasma_fx)
      fist = addNewSprite(orig_ux + (20 * f_dir), i_y, plasma_fx, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
      apply_pras_frame(fist, plasma_fx, 3, 0, 0) 
      fist.setAngle(0, f_dir == 1 ? 0 : 180)
      fist.setVisible(0, false); fist.setVisible(8, true); fist.setZoom(0, 200)
      fist.moveXY(8, 4, i_x, i_y); fist.moveOpacity(t_imp + 4, 4, 0)
    end

    # 5. IMPACTO EXPLOSIVO (Fila 2 - Ondas expansivas y destello azul)
    tp.setSE(t_imp, "Anim/Thunder3", 100, 90)
    tp.setSE(t_imp + 2, "Anim/Super Damage", 100, 120)
    
    tp.moveColor(t_imp, 2, Color.new(100, 200, 255, 255)); tp.moveColor(t_imp + 6, 6, Color.new(0,0,0,0))
    tp.moveXY(t_imp, 2, orig_tx + (60 * f_dir), orig_ty) 
    8.times { |i| tp.moveDelta(t_imp + 2 + i, 1, (i.even? ? 15 : -15) * f_dir, 0) }
    tp.moveXY(t_imp + 10, 4, orig_tx, orig_ty)

    if pbResolveBitmap(plasma_fx)
      # Núcleo de la explosión
      boom = addNewSprite(i_x, i_y, plasma_fx, PictureOrigin::CENTER); boom.setZ(0, target_z + 16)
      apply_pras_frame(boom, plasma_fx, 0, 2, 0) # Inicio Fila 2
      boom.setBlendType(0, 1)
      boom.setVisible(0, false); boom.setVisible(t_imp, true); boom.setZoom(0, 150)
      
      # Animamos la fila 2 de explosiones
      5.times { |f| apply_pras_frame(boom, plasma_fx, f, 2, t_imp + (f * 2)) }
      boom.moveZoom(t_imp, 8, 350); boom.moveOpacity(t_imp + 8, 4, 0)

      # Relámpagos residuales
      6.times do |i|
        r_bolt = addNewSprite(i_x, i_y, plasma_fx, PictureOrigin::CENTER); r_bolt.setZ(0, target_z + 17)
        apply_pras_frame(r_bolt, plasma_fx, rand(5), 1, 0) 
        r_bolt.setBlendType(0, 1); r_bolt.setAngle(0, rand(360))
        r_bolt.setVisible(0, false); r_bolt.setVisible(t_imp, true)
        r_bolt.setZoom(0, 50); r_bolt.moveZoom(t_imp, 6, 150 + rand(100))
        r_bolt.moveXY(t_imp, 6, i_x + (rand(160)-80), i_y + (rand(160)-80))
        r_bolt.moveOpacity(t_imp + 4, 4, 0)
      end
    end

    # Reset
    up.moveTone(t_imp + 8, 6, Tone.new(0,0,0,0))
    up.moveXY(t_imp + 8, 6, orig_ux, orig_uy)

    up.setXY(@end_frame - 1, orig_ux, orig_uy)
    tp.setXY(@end_frame - 1, orig_tx, orig_ty)
    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end