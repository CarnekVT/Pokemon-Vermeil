#===============================================================================
# [VERMEIL] BattleAnimations - Zippy Zap
# Style: Light-speed teleport dash + Evasion buff visual.
#===============================================================================

module VermeilBattleAnimations
  module_function
  ZIPPY_BG     = ["Graphics/Animations/PRAS- Electric Terrain BG.png", "Graphics/Animations/PRAS- Electric Terrain BG"]
  ZIPPY_SPARKS = ["Graphics/Animations/PRAS- Electro Ball.png", "Graphics/Animations/PRAS- Electro Ball"]
  ZIPPY_BOLTS  = ["Graphics/Animations/PRAS- Electric.png", "Graphics/Animations/PRAS- Electric"]
  
  ZIPPY_SE_DASH = "Anim/PRSFX- Spark1"
  ZIPPY_SE_HIT  = "Anim/Thunder3"

  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id); d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicZippyZap < Battle::Scene::Animation
  T_START  = 2
  T_VANISH = 6
  T_STRIKE = 12
  T_BUFF   = 28
  T_END    = 50

  def initialize(sprites, viewport, user, target); @user = user; @target = target; super(sprites, viewport); end

  def apply_pras_frame(sprite, col, row, time = 0)
    fw = 192; fh = 192
    sprite.setSrc(time, col * fw, row * fh); sprite.setSrcSize(time, fw, fh)
    if time == 0 && (raw = @pictureSprites.last) && raw.src_rect
      raw.src_rect.set(col * fw, row * fh, fw, fh)
    end
  end

  def create_battler_clone(original_sprite)
    clone = Sprite.new(@viewport); clone.bitmap = original_sprite.bitmap
    if original_sprite.respond_to?(:src_rect) && original_sprite.src_rect
      clone.src_rect.set(original_sprite.src_rect.x, original_sprite.src_rect.y, original_sprite.src_rect.width, original_sprite.src_rect.height)
    end
    clone.ox, clone.oy = original_sprite.ox, original_sprite.oy; clone.x, clone.y = original_sprite.x, original_sprite.y
    clone.zoom_x, clone.zoom_y = original_sprite.zoom_x, original_sprite.zoom_y; clone.mirror = original_sprite.mirror
    @tempSprites << clone; return clone
  end

  def createProcesses
    return if !@user || !@target
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    bg_asset    = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::ZIPPY_BG)
    spark_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::ZIPPY_SPARKS)
    bolt_asset  = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::ZIPPY_BOLTS)
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    c_x, c_y = us.x + (40 * f_dir), us.y - uh; i_x, i_y = ts.x - (10 * f_dir), ts.y - th

    orig_ux = up.x; orig_uy = up.y

    # 1. FONDO DE VELOCIDAD (Speedlines doradas)
    if bg_asset
      bg = addNewSprite(Graphics.width/2, Graphics.height/2, bg_asset, PictureOrigin::CENTER)
      bg.setZ(0, 550); bg.setVisible(0, false); bg.setOpacity(0, 0)
      bg.setZoomXY(0, Graphics.width * 1.5, Graphics.height * 1.5) # Llenar pantalla
      bg.setBlendType(0, 1) # Luz aditiva para que brille
      bg.setVisible(T_START, true); bg.moveOpacity(T_START, 4, 200)
      bg.moveOpacity(T_BUFF, 6, 0); bg.setVisible(T_BUFF + 6, false)
    end

    # 2. VANISH (Flash step)
    up.setSE(T_VANISH, VermeilBattleAnimations::ZIPPY_SE_DASH, 100, 150)
    up.moveColor(T_VANISH, 2, Color.new(255, 255, 0, 255))
    up.moveDelta(T_VANISH, 2, 60 * f_dir, -40)
    up.moveOpacity(T_VANISH, 2, 0)

    if spark_asset
      v_spark = addNewSprite(c_x, c_y, spark_asset, PictureOrigin::CENTER); v_spark.setZ(0, 750)
      apply_pras_frame(v_spark, 0, 1, 0) # Fila 1 son las chispas en Electro Ball
      v_spark.setBlendType(0, 1); v_spark.setVisible(0, false)
      v_spark.setVisible(T_VANISH, true); v_spark.setZoom(T_VANISH, 150)
      v_spark.moveZoom(T_VANISH, 4, 300); v_spark.moveOpacity(T_VANISH + 2, 4, 0)
    end

    # 3. ZIG-ZAG STRIKES (Impactos ultra rápidos en el objetivo)
    tp.moveColor(T_STRIKE, 2, Color.new(255, 255, 255, 255))
    tp.moveColor(T_STRIKE + 6, 6, Color.new(255, 255, 255, 0))
    tp.moveTone(T_STRIKE + 4, 6, Tone.new(-60, -60, -60, 60)) # Oscurece por el daño
    tp.setSE(T_STRIKE, VermeilBattleAnimations::ZIPPY_SE_HIT, 100, 120)

    # 3 golpes eléctricos simulando el zig-zag
    if bolt_asset
      delays = [0, 3, 6]
      angles = [45, -45, 0]
      3.times do |i|
        t_s = T_STRIKE + delays[i]
        
        # Rayo (Asumiendo que hay rayos en la Fila 3 o similar, usamos una chispa grande si no)
        bolt = addNewSprite(i_x, i_y, bolt_asset, PictureOrigin::CENTER); bolt.setZ(0, 750 + i)
        apply_pras_frame(bolt, rand(3), 2, 0) # Fila 2 de PRAS- Electric suele tener rayos horizontales
        bolt.setBlendType(0, 1); bolt.setVisible(0, false)
        bolt.setAngle(0, angles[i] * f_dir); bolt.setZoomXY(0, 200, 50)
        
        bolt.setVisible(t_s, true)
        bolt.moveZoomXY(t_s, 3, 50, 150)
        bolt.moveOpacity(t_s + 2, 3, 0)

        # Temblor
        tp.moveDelta(t_s, 1, 12 * (i.even? ? 1 : -1) * f_dir, 0)
        tp.moveDelta(t_s + 1, 2, -24 * (i.even? ? 1 : -1) * f_dir, 0)
        tp.moveDelta(t_s + 3, 1, 12 * (i.even? ? 1 : -1) * f_dir, 0)
      end
    end

    # Chispas de impacto masivas
    if spark_asset
      15.times do |i|
        t_s = T_STRIKE + rand(6)
        sp = addNewSprite(i_x, i_y, spark_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_pras_frame(sp, rand(5), 1, 0) # Fila 1 (chispas)
        sp.setBlendType(0, 1); sp.setVisible(0, false)
        sp.setTone(0, Tone.new(255, 255, (i.even? ? 0 : 255), 0))
        sp.setVisible(t_s, true); sp.setZoom(t_s, 40 + rand(30))
        
        pop_x = i_x + (rand(120) - 60); pop_y = i_y + (rand(120) - 60)
        sp.moveXY(t_s, 6 + rand(4), pop_x, pop_y)
        sp.moveOpacity(t_s + 4, 4, 0)
      end
    end

    # 4. REAPARECE CON BUFF DE EVASIÓN
    up.setXY(T_BUFF, orig_ux, orig_uy)
    up.setSE(T_BUFF, VermeilBattleAnimations::ZIPPY_SE_DASH, 100, 90)
    up.moveOpacity(T_BUFF, 2, 255)
    
    # Brillo Cian de Evasión (Velocidad)
    up.moveColor(T_BUFF, 3, Color.new(0, 255, 255, 200))
    up.moveTone(T_BUFF, 3, Tone.new(0, 150, 150, 50))
    up.moveColor(T_BUFF + 4, 10, Color.new(0, 0, 0, 0))
    up.moveTone(T_BUFF + 10, 10, Tone.new(0, 0, 0, 0))

    if spark_asset
      aura = addNewSprite(c_x, c_y, spark_asset, PictureOrigin::CENTER); aura.setZ(0, 590) # Detrás del user
      apply_pras_frame(aura, 0, 0, 0) # Fila 0 (Bola)
      aura.setBlendType(0, 1); aura.setTone(0, Tone.new(-100, 100, 100, 0)) # Cian
      aura.setVisible(0, false); aura.setVisible(T_BUFF, true)
      aura.setZoom(T_BUFF, 100); aura.moveZoom(T_BUFF, 10, 250)
      aura.moveOpacity(T_BUFF + 4, 8, 0)
    end

    tp.moveTone(T_END - 10, 10, Tone.new(0,0,0,0))
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_zippyzap_anim, :pbAnimation unless method_defined?(:vermeil_zippyzap_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :ZIPPYZAP && @scene.respond_to?(:pbPlayVermeilZippyZap)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilZippyZap(user, targets)
    end
    vermeil_zippyzap_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilZippyZap)
  def pbPlayVermeilZippyZap(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; vermeil_ss_clear_message_window! rescue nil
    begin
      anim = Animation::VermeilCinematicZippyZap.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end