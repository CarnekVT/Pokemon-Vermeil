#===============================================================================
# [VERMEIL] BattleAnimations - Priority Punches
# Includes: Mach Punch, Bullet Punch, Jet Punch
# Fix: Removed weird Mach Punch line. Bullet Punch is bluish-gray. 
# Jet Punch is now a fast, heavy, high-pressure water strike.
#===============================================================================

class Battle::Scene::Animation::VermeilPriorityPunches < Battle::Scene::Animation
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

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, user_z)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, target_z)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x = ts.x; i_y = ts.y - th; orig_ux = us.x; orig_uy = us.y; orig_tx = ts.x; orig_ty = ts.y

    @end_frame = 35

    case @move_id
    when :MACHPUNCH
      # 💥 SPEED OF SOUND BLINK-STRIKE (Instant, single heavy hit)
      t_imp = 4
      punches = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
      spark   = "Graphics/Animations/PRAS- Strike.png"

      # Blink instantáneo (Desaparece limpio, sin líneas raras)
      up.setSE(0, "Anim/Wind1", 100, 180)
      up.moveOpacity(0, 2, 0)
      
      # Puño naranja brillante
      if pbResolveBitmap(punches)
        fist = addNewSprite(i_x - (60 * f_dir), i_y, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(200, 50, 0, 0)); fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(t_imp, true); fist.setZoom(0, 150)
        fist.moveXY(t_imp, 2, i_x, i_y); fist.moveOpacity(t_imp + 2, 3, 0)
      end

      # Chispa de pelea
      if pbResolveBitmap(spark)
        sp = addNewSprite(i_x, i_y, spark, PictureOrigin::CENTER); sp.setZ(0, target_z + 16)
        apply_pras_frame(sp, spark, 0, 0, 0)
        sp.setBlendType(0, 1); sp.setTone(0, Tone.new(255, 100, 0, 0))
        sp.setVisible(0, false); sp.setVisible(t_imp, true)
        sp.setZoom(0, 80); sp.moveZoom(t_imp, 3, 200); sp.moveOpacity(t_imp + 2, 3, 0)
      end

      tp.setSE(t_imp, "Anim/Hit1", 100, 100)
      tp.moveColor(t_imp, 2, Color.new(255, 255, 255, 200)); tp.moveColor(t_imp + 2, 4, Color.new(0, 0, 0, 0))
      tp.moveXY(t_imp, 2, orig_tx + (30 * f_dir), orig_ty); tp.moveXY(t_imp + 2, 4, orig_tx, orig_ty)
      
      up.setSE(t_imp + 12, "Anim/Wind1", 80, 150)
      up.moveOpacity(t_imp + 12, 3, 255)

    when :BULLETPUNCH
      # ⚙️ METALLIC ORA ORA BARRAGE (Gris Azulado Intenso)
      t_imp = 2
      punches = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
      spark   = "Graphics/Animations/PRAS- Strike.png"

      up.setSE(0, "Anim/Wind1", 100, 180)
      up.moveOpacity(0, 2, 0)

      # Ráfaga de puños metálicos
      if pbResolveBitmap(punches)
        7.times do |i|
          t_s = t_imp + (i * 2)
          r_x = (rand(60) - 30); r_y = (rand(60) - 30)
          
          fist = addNewSprite(i_x - (50 * f_dir), i_y + r_y, punches, PictureOrigin::CENTER)
          fist.setZ(0, target_z + 15 + i)
          apply_pras_frame(fist, punches, 0, 0, 0) 
          # Tinte gris azulado pesado para eliminar lo amarillo
          fist.setTone(0, Tone.new(-80, -50, 100, 150))
          fist.setAngle(0, f_dir == 1 ? 0 : 180); fist.setZoom(0, 100 + rand(40))
          fist.setVisible(0, false); fist.setVisible(t_s, true)
          fist.moveXY(t_s, 2, i_x + r_x, i_y + r_y)
          fist.moveOpacity(t_s + 2, 2, 0)
          
          if pbResolveBitmap(spark)
            sp = addNewSprite(i_x + r_x, i_y + r_y, spark, PictureOrigin::CENTER)
            sp.setZ(0, target_z + 20 + i)
            apply_pras_frame(sp, spark, rand(3), 0, 0)
            sp.setBlendType(0, 1); sp.setTone(0, Tone.new(-100, -50, 150, 100)) # Chispas metálicas
            sp.setVisible(0, false); sp.setVisible(t_s, true)
            sp.setZoom(0, 60 + rand(40)); sp.moveOpacity(t_s + 2, 3, 0)
          end
          
          tp.setSE(t_s, "Anim/Hit2", 90, 90 + rand(30)) 
          tp.moveDelta(t_s, 1, 8 * f_dir, 0); tp.moveDelta(t_s + 1, 1, -8 * f_dir, 0)
        end
      end
      
      tp.moveColor(t_imp, 2, Color.new(200, 200, 255, 200))
      tp.moveColor(t_imp + 14, 4, Color.new(0, 0, 0, 0))
      
      up.setSE(t_imp + 16, "Anim/Wind1", 80, 150)
      up.moveOpacity(t_imp + 16, 3, 255)

    when :JETPUNCH
      # 🌊 FLUID HEAVY WATER PUNCH (Instant fast strike)
      t_imp = 4
      punches      = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
      splash_asset = "Graphics/BattleParticlesAnimations/WaterSplashShot"
      drops_asset  = "Graphics/BattleParticlesAnimations/Bubbles-Drops"

      up.setSE(0, "Anim/Wind1", 100, 180)
      up.moveOpacity(0, 2, 0)

      # Centramos el impacto en el objetivo (Como en Surging Strikes)
      imp_x = orig_tx
      imp_y = orig_ty - th

      # Puño Torpedo Acuático (Directo a la cara)
      if pbResolveBitmap(punches)
        fist = addNewSprite(imp_x - (80 * f_dir), imp_y, punches, PictureOrigin::CENTER)
        fist.setZ(0, target_z + 15)
        apply_pras_frame(fist, punches, 0, 0, 0)
        fist.setTone(0, Tone.new(0, 100, 255, 100)); fist.setAngle(0, f_dir == 1 ? 0 : 180)
        fist.setVisible(0, false); fist.setVisible(t_imp, true); fist.setZoom(0, 160)
        fist.moveXY(t_imp, 2, imp_x, imp_y); fist.moveOpacity(t_imp + 2, 3, 0)
      end

      # Impacto animado de alta presión 
      tp.setSE(t_imp, "Anim/Water3", 100, 110)
      if pbResolveBitmap(splash_asset)
        splash = addNewSprite(imp_x, imp_y, splash_asset, PictureOrigin::CENTER); splash.setZ(0, target_z + 20)
        
        # Inicializamos en frame 0 para evitar descuadres de sprite
        apply_pras_frame(splash, splash_asset, 0, 0, 0, 64, 64)
        
        5.times do |f_idx|
          apply_pras_frame(splash, splash_asset, f_idx, 0, t_imp + (f_idx * 2), 64, 64)
        end
        splash.setBlendType(0, 1); splash.setVisible(0, false); splash.setVisible(t_imp, true)
        splash.setZoom(0, 120); splash.moveZoom(t_imp, 5, 250); splash.moveOpacity(t_imp + 6, 4, 0)
      end

      # Explosión violenta de gotas
      if pbResolveBitmap(drops_asset)
        15.times do |i|
          sp = addNewSprite(imp_x, imp_y, drops_asset, PictureOrigin::CENTER); sp.setZ(0, target_z + 25)
          apply_pras_frame(sp, drops_asset, rand(3), rand(2), 0, 32, 32); sp.setBlendType(0, 1)
          sp.setVisible(0, false); sp.setVisible(t_imp, true)
          sp.setZoom(0, 60 + rand(50))
          ang = rand(360) * Math::PI / 180; dist = 80 + rand(100)
          sp.moveXY(t_imp, 8 + rand(4), imp_x + Math.cos(ang)*dist, imp_y + Math.sin(ang)*dist + 40)
          sp.moveOpacity(t_imp + 6, 6, 0)
        end
      end

      tp.moveColor(t_imp, 2, Color.new(100, 200, 255, 200)); tp.moveColor(t_imp + 4, 4, Color.new(0, 0, 0, 0))
      tp.moveXY(t_imp, 2, orig_tx + (40 * f_dir), orig_ty); tp.moveXY(t_imp + 2, 4, orig_tx, orig_ty)
      
      up.setSE(t_imp + 12, "Anim/Wind1", 80, 150)
      up.moveOpacity(t_imp + 12, 3, 255)
    end

    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end

class Battle
  alias_method :vermeil_priority_punches_anim, :pbAnimation unless method_defined?(:vermeil_priority_punches_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    if @showAnims && [:MACHPUNCH, :BULLETPUNCH, :JETPUNCH].include?(mid) && @scene.respond_to?(:pbPlayVermeilPriorityPunches)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilPriorityPunches(user, targets, mid)
    end
    vermeil_priority_punches_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene
  def pbPlayVermeilPriorityPunches(user, targets, mid)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true
    vermeil_ss_set_message_skin(true) rescue nil
    vermeil_ss_clear_message_window! rescue nil
    
    
    begin
      anim = Animation::VermeilPriorityPunches.new(@sprites, @viewport, user, target, mid)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts
      
      @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil
      pbRefresh if respond_to?(:pbRefresh)
    end
    return true
  end
end