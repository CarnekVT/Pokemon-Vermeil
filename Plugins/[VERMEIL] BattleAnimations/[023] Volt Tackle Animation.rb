#===============================================================================
# [VERMEIL] BattleAnimations - Volt Tackle (Pikachu UNITE Style)
# Fix: True Motion Blur & High-Speed Light Streaks (Omnislash Style).
#===============================================================================

module VermeilBattleAnimations
  module_function
  VOLT_TACKLE_SPARKS = ["Graphics/Animations/PRAS- Electric.png", "Graphics/Animations/PRAS- Electric"]
  VOLT_TACKLE_AURA   = ["Graphics/Animations/PRAS- Electro Ball.png", "Graphics/Animations/PRAS- Electro Ball"]
  
  VT_SE_CHARGE = "Anim/Thunder1"
  VT_SE_DASH   = "Anim/Wind1"
  VT_SE_HIT    = "Anim/Thunder3"
  VT_SE_BLAST  = "Anim/PRSFX- Thunder"

  def first_existing_asset(paths); paths.each { |p| return p if pbResolveBitmap(p) }; nil; end
  def resolve_move_id(move)
    return move.id if move.respond_to?(:id); d = GameData::Move.try_get(move); return d.id if d; move
  end
end

class Battle::Scene::Animation::VermeilCinematicVoltTackle < Battle::Scene::Animation
  T_CHARGE = 2
  T_DASH   = 16
  T_MULTI  = 20
  T_FINAL  = 44
  T_RECOIL = 50
  T_END    = 80

  def initialize(sprites, viewport, user, target); @user = user; @target = target; super(sprites, viewport); end

  def get_frame_info(path)
    @_sheet_cache ||= {}; return @_sheet_cache[path] if @_sheet_cache[path]
    resolved = pbResolveBitmap(path); return nil if !resolved
    bmp = Bitmap.new(resolved); fw = 192; fh = 192 
    cols = [1, (bmp.width / fw.to_f).round].max; rows = [1, (bmp.height / fh.to_f).round].max
    info = { fw: fw, fh: fh, cols: cols, rows: rows, count: cols * rows }; bmp.dispose
    @_sheet_cache[path] = info; return info
  end

  def apply_frame(sprite, path, col, row, time = 0)
    info = get_frame_info(path); return if !info
    sprite.setSrc(time, col * info[:fw], row * info[:fh]); sprite.setSrcSize(time, info[:fw], info[:fh])
    if time == 0 && (raw = @pictureSprites.last) && raw.src_rect
      raw.src_rect.set(col * info[:fw], row * info[:fh], info[:fw], info[:fh])
    end
  end

  def create_battler_clone(original_sprite)
    clone = Sprite.new(@viewport); clone.bitmap = original_sprite.bitmap
    if original_sprite.respond_to?(:src_rect) && original_sprite.src_rect
      clone.src_rect.set(original_sprite.src_rect.x, original_sprite.src_rect.y, original_sprite.src_rect.width, original_sprite.src_rect.height)
    end
    # CORREGIDO: Faltaba el signo de igual en clone.ox = original_sprite.ox
    clone.ox = original_sprite.ox; clone.oy = original_sprite.oy; clone.x = original_sprite.x; clone.y = original_sprite.y
    clone.zoom_x = original_sprite.zoom_x; clone.zoom_y = original_sprite.zoom_y; clone.mirror = original_sprite.mirror
    @tempSprites << clone; return clone
  end

  def createProcesses
    return if !@user || !@target
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    spark_asset = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::VOLT_TACKLE_SPARKS)
    aura_asset  = VermeilBattleAnimations.first_existing_asset(VermeilBattleAnimations::VOLT_TACKLE_AURA)
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    c_x, c_y = us.x + (40 * f_dir), us.y - uh; i_x, i_y = ts.x - (10 * f_dir), ts.y - th

    orig_ux = up.x; orig_uy = up.y
    orig_tx = tp.x; orig_ty = tp.y

    # 1. CARGA DE ENERGÍA
    up.setSE(T_CHARGE, VermeilBattleAnimations::VT_SE_CHARGE, 100, 100)
    up.moveColor(T_CHARGE, 12, Color.new(255, 255, 0, 180))
    14.times { |i| up.moveDelta(T_CHARGE + i, 1, (i.even? ? 6 : -6), 0) }

    if aura_asset
      aura = addNewSprite(c_x, c_y, aura_asset, PictureOrigin::CENTER); aura.setZ(0, 610)
      apply_frame(aura, aura_asset, 0, 0)
      aura.setBlendType(0, 1); aura.setTone(0, Tone.new(50, 50, 0, 0))
      aura.setVisible(0, false); aura.setVisible(T_CHARGE, true)
      aura.setZoom(T_CHARGE, 50); aura.moveZoom(T_CHARGE, 14, 220)
    end

    # 2. DASH INICIAL (El usuario choca y "desaparece" para iniciar el combo)
    up.setSE(T_DASH, VermeilBattleAnimations::VT_SE_DASH, 100, 110)
    up.moveXY(T_DASH, 4, i_x - (30 * f_dir), i_y + uh)
    aura.moveXY(T_DASH, 4, i_x - (30 * f_dir), i_y) if aura_asset
    
    # Se hace invisible para que los clones de estela tomen el control
    up.moveOpacity(T_DASH + 2, 2, 0)
    aura.moveOpacity(T_DASH + 2, 2, 0) if aura_asset

    # 3. COMBO DE ESTELAS TIPO OMNISLASH (Motion Blur Dash)
    7.times do |i|
      t_s = T_MULTI + (i * 3) # Un corte hiperrápido cada 3 frames
      
      # Vector de movimiento aleatorio cruzando el centro
      streak_angle = rand(360)
      dist = 220
      rad = streak_angle * Math::PI / 180
      start_x = i_x + Math.cos(rad) * dist
      start_y = i_y + Math.sin(rad) * dist
      end_x   = i_x - Math.cos(rad) * dist
      end_y   = i_y - Math.sin(rad) * dist

      # Clon fantasma del usuario cruzando la pantalla
      dash_u = Sprite.new(@viewport); dash_u.bitmap = us.bitmap
      dash_u.src_rect.set(us.src_rect.x, us.src_rect.y, us.src_rect.width, us.src_rect.height) if us.src_rect
      dash_u.ox = us.ox; dash_u.oy = us.oy; dash_u.mirror = us.mirror
      @tempSprites << dash_u
      
      du_pic = addSprite(dash_u, PictureOrigin::BOTTOM); du_pic.setZ(0, 615)
      du_pic.setVisible(0, false); du_pic.setTone(0, Tone.new(150, 150, 0, 50)) # Electrificado
      
      du_pic.setVisible(t_s, true)
      du_pic.setXY(t_s, start_x, start_y + uh)
      du_pic.moveXY(t_s, 3, end_x, end_y + uh)
      du_pic.moveOpacity(t_s + 1, 2, 0) # Se desvanece por la inercia

      # Aura estirada (El haz de luz que envuelve al Pokémon)
      if aura_asset
        da = addNewSprite(start_x, start_y, aura_asset, PictureOrigin::CENTER); da.setZ(0, 620)
        apply_frame(da, aura_asset, 0, 0)
        da.setBlendType(0, 1); da.setTone(0, Tone.new(255, 255, 0, 0))
        da.setAngle(0, streak_angle + 180) # Apunta en la dirección de la trayectoria
        da.setZoomXY(0, 450, 60) # Super estirado simulando velocidad
        
        da.setVisible(0, false); da.setVisible(t_s, true)
        da.setXY(t_s, start_x, start_y)
        da.moveXY(t_s, 3, end_x, end_y)
        da.moveOpacity(t_s + 1, 2, 0)
      end

      # Reacción del Rival (Suspendido en el aire, tiembla)
      tp.setXY(t_s, orig_tx + (rand(20) - 10), orig_ty + (rand(20) - 10) - 25)
      tp.setSE(t_s, VermeilBattleAnimations::VT_SE_HIT, 90, 120 + rand(30))
      tp.setColor(t_s, Color.new(255, 255, 200, 220))
      tp.moveColor(t_s + 1, 2, Color.new(0, 0, 0, 0))

      # Chispas en cada golpe
      if spark_asset
        sp = addNewSprite(i_x + rand(40)-20, i_y + rand(40)-20, spark_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_frame(sp, spark_asset, rand(5), 1, 0) # Fila 1 (Chispas)
        sp.setBlendType(0, 1); sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setZoom(t_s, 60 + rand(40)); sp.setTone(0, Tone.new(255, 255, 0, 0))
        sp.moveOpacity(t_s + 1, 3, 0)
      end
    end

    # 4. IMPACTO FINAL Y KNOCK-UP
    # El usuario reaparece en el centro de golpe
    up.setXY(T_FINAL, i_x - (20 * f_dir), i_y + uh)
    up.setOpacity(T_FINAL, 255)
    up.setColor(T_FINAL, Color.new(255, 255, 0, 200))
    
    if aura_asset
      aura.setXY(T_FINAL, i_x - (20 * f_dir), i_y)
      aura.setOpacity(T_FINAL, 255)
      aura.moveZoom(T_FINAL, 4, 400)
      aura.moveOpacity(T_FINAL + 2, 4, 0)
    end

    tp.setSE(T_FINAL, VermeilBattleAnimations::VT_SE_BLAST, 100, 90)
    tp.moveColor(T_FINAL, 2, Color.new(255, 255, 255, 255))
    tp.moveColor(T_FINAL + 4, 8, Color.new(255, 255, 255, 0))
    tp.moveTone(T_FINAL + 6, 6, Tone.new(-100, -100, -100, 120)) 

    # Knock-up explosivo (Sale despedido hacia atrás)
    tp.moveXY(T_FINAL, 3, orig_tx + (40 * f_dir), orig_ty - 60)
    tp.moveXY(T_FINAL + 3, 5, orig_tx + (60 * f_dir), orig_ty)
    tp.moveXY(T_FINAL + 8, 3, orig_tx + (70 * f_dir), orig_ty - 20)
    tp.moveXY(T_FINAL + 11, 3, orig_tx + (70 * f_dir), orig_ty)

    flash = addNewSprite(0, 0, "Graphics/Battle animations/white_screen") rescue nil
    if flash
      flash.setZ(0, 800); flash.setOpacity(0, 0)
      flash.moveOpacity(T_FINAL, 1, 200); flash.moveOpacity(T_FINAL + 2, 5, 0)
    end

    if spark_asset
      30.times do |i|
        t_s = T_FINAL
        sp = addNewSprite(i_x, i_y, spark_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_frame(sp, spark_asset, rand(5), 1, 0)
        sp.setBlendType(0, 1); sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setTone(0, Tone.new(255, 255, (i % 3 == 0 ? 255 : 0), 0)) 
        sp.setZoom(t_s, 60 + rand(60))
        
        pop_x = i_x + (rand(260) - 130); pop_y = i_y + (rand(260) - 130)
        sp.moveXY(t_s, 6 + rand(6), pop_x, pop_y)
        sp.moveOpacity(t_s + 4, 6, 0)
      end
    end

    # 5. RECOIL BOUNCE (El usuario sale despedido por el daño)
    up.moveColor(T_RECOIL, 2, Color.new(255, 50, 50, 200)) 
    up.moveXY(T_RECOIL, 5, orig_ux - (60 * f_dir), orig_uy - 60) # Vuela hacia atrás (Arco)
    up.moveXY(T_RECOIL + 5, 5, orig_ux - (90 * f_dir), orig_uy) # Aterriza
    up.moveColor(T_RECOIL + 5, 8, Color.new(0, 0, 0, 0))

    # 6. REGRESO SUAVE A POSICIONES ORIGINALES
    up.moveXY(T_END - 10, 8, orig_ux, orig_uy)
    tp.moveXY(T_END - 10, 8, orig_tx, orig_ty)
    tp.moveTone(T_END - 10, 8, Tone.new(0,0,0,0))

    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_volttackle_anim, :pbAnimation unless method_defined?(:vermeil_volttackle_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = VermeilBattleAnimations.resolve_move_id(move)
    if @showAnims && mid == :VOLTTACKLE && @scene.respond_to?(:pbPlayVermeilVoltTackle)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilVoltTackle(user, targets)
    end
    vermeil_volttackle_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilVoltTackle)
  def pbPlayVermeilVoltTackle(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; vermeil_ss_clear_message_window! rescue nil
    begin
      anim = Animation::VermeilCinematicVoltTackle.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end