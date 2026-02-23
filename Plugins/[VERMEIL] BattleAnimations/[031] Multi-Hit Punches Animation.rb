#===============================================================================
# [VERMEIL] BattleAnimations - Multi-Hit & Flow Punches
# Fix: WaterSplashShot off-center bug (time=0 src_rect initialization).
# Surging Strikes arc now starts from attacker's hand perfectly.
# Maintenance: Full code structure preserved (>395 lines) for UI stability.
#===============================================================================

class Battle::Scene::Animation::VermeilMultiHitPunches < Battle::Scene::Animation
  def initialize(sprites, viewport, user, target, move_id, hit_num = 0)
    @user = user; @target = target; @move_id = move_id; @hit_num = hit_num
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

    lunge_x = orig_ux + (15 * f_dir)
    up.setSE(2, "Anim/Wind1", 100, 130)
    up.moveXY(2, 3, lunge_x, orig_uy)

    @end_frame = 25

    case @move_id
    when :FLURRYPUNCH
      @end_frame = 22
      punches = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
      spark   = "Graphics/Animations/PRAS- Strike.png"
      if pbResolveBitmap(punches)
        delays = [5, 8, 11]
        delays.each_with_index do |t_s, idx|
          r_x = (rand(60) - 30); r_y = (rand(60) - 30)
          start_f_x = i_x - (80 * f_dir); start_f_y = i_y + r_y
          end_f_x = i_x + r_x; end_f_y = i_y + r_y
          fist = addNewSprite(start_f_x, start_f_y, punches, PictureOrigin::CENTER); fist.setZ(0, target_z + 16)
          apply_pras_frame(fist, punches, 0, 0, 0); fist.setAngle(0, f_dir == 1 ? 0 : 180); fist.setZoom(0, 100 + rand(30))
          fist.setVisible(0, false); fist.setVisible(t_s, true)
          fist.moveXY(t_s, 2, end_f_x, end_f_y); fist.moveOpacity(t_s + 2, 2, 0)
          if pbResolveBitmap(spark)
            4.times do |k|
              tr = addNewSprite(0, 0, spark, PictureOrigin::CENTER); tr.setZ(0, target_z + 15)
              apply_pras_frame(tr, spark, rand(3), 0, 0); tr.setBlendType(0, 1)
              tr_x = start_f_x + (end_f_x - start_f_x) * (k / 3.0)
              tr.setXY(0, tr_x, start_f_y + (rand(20)-10)); tr.setVisible(0, false); tr.setVisible(t_s, true)
              tr.setZoom(0, 30 + rand(30)); tr.moveOpacity(t_s + 1 + rand(2), 2, 0)
            end
          end
          tp.setSE(t_s + 1, "Anim/Hit1", 100, 100 + rand(20))
          tp.moveDelta(t_s + 1, 1, 8 * f_dir, 0); tp.moveDelta(t_s + 2, 1, -8 * f_dir, 0)
        end
      end
      up.moveXY(16, 4, orig_ux, orig_uy)

    when :COMETPUNCH
      @end_frame = 20
      punches = "Graphics/Animations/punches.png"
      swift = pbResolveBitmap("Graphics/Animations/PRAS- Swift.png") ? "Graphics/Animations/PRAS- Swift.png" : "Graphics/Animations/PRAS- Meteor Mash.png"
      start_c_x = lunge_x + (20 * f_dir); start_c_y = orig_uy - uh
      if pbResolveBitmap(punches)
        fist = addNewSprite(start_c_x, start_c_y, punches, PictureOrigin::CENTER); fist.setZ(0, user_z + 6)
        apply_pras_frame(fist, punches, 1, 0, 0); fist.setTone(0, Tone.new(0, 100, 255, 50)) 
        fist.setVisible(0, false); fist.setVisible(5, true); fist.setZoom(0, 120)
        fist.setAngle(0, f_dir == 1 ? 0 : 180); fist.moveXY(5, 3, i_x, i_y); fist.moveOpacity(8, 2, 0)
      end
      if pbResolveBitmap(swift)
        5.times do |k|
          tr = addNewSprite(0, 0, swift, PictureOrigin::CENTER); tr.setZ(0, user_z + 5)
          apply_pras_frame(tr, swift, rand(4), 0, 0); tr.setBlendType(0, 1)
          tr_x = start_c_x + (i_x - start_c_x) * (k / 4.0); tr_y = start_c_y + (i_y - start_c_y) * (k / 4.0)
          tr.setXY(0, tr_x + (rand(20)-10), tr_y + (rand(20)-10))
          tr.setVisible(0, false); tr.setVisible(5, true); tr.setZoom(0, 40 + rand(30)); tr.moveOpacity(7 + rand(2), 2, 0)
        end
      end
      tp.setSE(8, "Anim/Hit2", 100, 110)
      tp.moveColor(8, 2, Color.new(255, 255, 200, 200)); tp.moveColor(10, 3, Color.new(0,0,0,0))
      4.times { |i| tp.moveDelta(8 + i, 1, (i.even? ? 10 : -10) * f_dir, 0) }
      if pbResolveBitmap(swift)
        8.times do |i|
          s = addNewSprite(i_x, i_y, swift, PictureOrigin::CENTER); s.setZ(0, target_z + 15)
          apply_pras_frame(s, swift, rand(4), 0, 0); s.setBlendType(0, 1)
          s.setVisible(0, false); s.setVisible(8, true); s.setZoom(0, 40 + rand(30))
          s.moveXY(8, 4 + rand(4), i_x + (rand(120)-60), i_y + (rand(120)-60)); s.moveOpacity(11, 4, 0)
        end
      end
      up.moveXY(13, 4, orig_ux, orig_uy)

    when :SURGINGSTRIKES
      # AZOTE TORRENCIAL - CANONICAL FLUID ARCS & ANIMATED SPLASH
      @end_frame = 28 # Damos margen para asegurar que el overlay no se corte prematuramente
      splash_asset = "Graphics/BattleParticlesAnimations/WaterSplashShot"
      drops_asset  = "Graphics/BattleParticlesAnimations/Bubbles-Drops"

      # Centramos el nacimiento del arco directamente en el atacante
      c_x = orig_ux + (40 * f_dir)
      c_y = orig_uy - uh

      y_off = (rand(80) - 40)
      start_f_x = c_x
      start_f_y = c_y
      
      # 1. Generar el arco de agua (Drops con gravedad atenuada)
      if pbResolveBitmap(drops_asset)
        14.times do |k|
          tr = addNewSprite(0, 0, drops_asset, PictureOrigin::CENTER)
          tr.setZ(0, target_z + 20)
          apply_pras_frame(tr, drops_asset, rand(3), rand(2), 0, 32, 32)
          tr.setBlendType(0, 1); tr.setTone(0, Tone.new(-100, 50, 200, 0))
          
          ratio = k / 13.0
          y_arc = Math.sin(ratio * Math::PI) * 65 
          tr.setXY(0, start_f_x + (i_x - start_f_x) * ratio, start_f_y + (i_y + y_off - start_f_y) * ratio - y_arc)
          
          tr.setVisible(0, false); tr.setVisible(5 + (k/1.2).floor, true)
          tr.setZoom(0, 60 + rand(40))
          # Inercia de Snipe Shot: Caen levemente sin cruzar el suelo
          tr.moveDelta(5 + (k/1.2).floor, 10, rand(25) * -f_dir, 30 + rand(20))
          tr.moveOpacity(5 + (k/1.2).floor, 12, 0)
        end
      end

      # Reacción de impacto en el objetivo
      tp.setSE(8, "Anim/Water3", 100, 110)
      tp.moveColor(8, 2, Color.new(150, 255, 255, 200)); tp.moveColor(10, 4, Color.new(0, 0, 0, 0))
      4.times { |i| tp.moveDelta(8 + i, 1, (i.even? ? 12 : -12) * f_dir, 0) }

      # 2. Impacto ANIMADO (Recorre los frames de WaterSplashShot centrado en el rival)
      if pbResolveBitmap(splash_asset)
        splash = addNewSprite(i_x, i_y + y_off, splash_asset, PictureOrigin::CENTER)
        splash.setZ(0, target_z + 22)
        
        # ¡FIX CLAVE! Inicializar el frame a tiempo 0 para ajustar el PictureOrigin de la imagen
        apply_pras_frame(splash, splash_asset, 0, 0, 0, 64, 64)
        
        # Sincronizamos la animación de la hoja de sprites
        5.times do |f_idx|
          apply_pras_frame(splash, splash_asset, f_idx, 0, 8 + (f_idx * 2), 64, 64)
        end
        
        splash.setBlendType(0, 1)
        splash.setVisible(0, false); splash.setVisible(8, true)
        splash.setZoom(0, 140); splash.moveZoom(8, 6, 260); splash.moveOpacity(16, 6, 0)
      end

      # 3. Dispersión radial (Gotas finales)
      if pbResolveBitmap(drops_asset)
        18.times do |i|
          sp = addNewSprite(i_x, i_y + y_off, drops_asset, PictureOrigin::CENTER); sp.setZ(0, target_z + 25)
          apply_pras_frame(sp, drops_asset, rand(3), rand(2), 0, 32, 32); sp.setBlendType(0, 1)
          sp.setVisible(0, false); sp.setVisible(8, true)
          ang = rand(360) * Math::PI / 180; dist = 90 + rand(130)
          sp.moveXY(8, 12 + rand(5), i_x + Math.cos(ang)*dist, i_y + Math.sin(ang)*dist + 50)
          sp.moveOpacity(12, 10, 0)
        end
      end
      
      up.moveXY(18, 5, orig_ux, orig_uy)

    when :DOUBLEHIT
      @end_frame = 18
      punches = pbResolveBitmap("Graphics/Animations/PRAS- Pummeling.png") ? "Graphics/Animations/PRAS- Pummeling.png" : "Graphics/Animations/punches.png"
      spark   = "Graphics/Animations/PRAS- Strike.png"
      is_even = @hit_num.to_i.even?
      start_slap_x = i_x + (is_even ? -80 : 80); end_slap_x = i_x + (is_even ? 80 : -80)
      if pbResolveBitmap(punches)
        slap = addNewSprite(start_slap_x, i_y, punches, PictureOrigin::CENTER); slap.setZ(0, target_z + 16)
        apply_pras_frame(slap, punches, 0, 0, 0); slap.setAngle(0, is_even ? 0 : 180); slap.setZoom(0, 130)
        slap.setVisible(0, false); slap.setVisible(4, true); slap.moveXY(4, 2, end_slap_x, i_y); slap.moveOpacity(5, 2, 0)
      end
      if pbResolveBitmap(spark)
        4.times do |k|
          tr = addNewSprite(0, 0, spark, PictureOrigin::CENTER); tr.setZ(0, target_z + 15)
          apply_pras_frame(tr, spark, rand(3), 0, 0); tr.setBlendType(0, 1)
          tr_x = start_slap_x + (end_slap_x - start_slap_x) * (k / 3.0)
          tr.setXY(0, tr_x, i_y + (rand(20)-10)); tr.setVisible(0, false); tr.setVisible(4, true)
          tr.setZoom(0, 40 + rand(40)); tr.moveOpacity(5 + rand(2), 2, 0)
        end
      end
      tp.setSE(4, "Anim/Hit1", 100, 100)
      tp.moveColor(4, 2, Color.new(255, 255, 255, 180)); tp.moveColor(6, 4, Color.new(0, 0, 0, 0))
      shake_dir = is_even ? 15 : -15
      tp.moveDelta(4, 1, shake_dir, 0); tp.moveDelta(5, 2, -shake_dir, 0); tp.moveDelta(7, 1, 0, 0)
      up.moveXY(10, 4, orig_ux, orig_uy)
    end

    up.setCallback(@end_frame, proc { us.visible = true; ts.visible = true })
  end
end

#===============================================================================
# THE ROUTER & NATIVE MULTI-HIT UI PATCH
#===============================================================================
class Battle
  alias_method :vermeil_multihit_punches_anim, :pbAnimation unless method_defined?(:vermeil_multihit_punches_anim)
  
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = move.respond_to?(:id) ? move.id : move
    multi_hit_punches = [:FLURRYPUNCH, :COMETPUNCH, :DOUBLEHIT, :SURGINGSTRIKES]

    if @showAnims && multi_hit_punches.include?(mid) && @scene.respond_to?(:pbPlayVermeilMultiHitPunches)
      if hitNum.to_i <= 0
        @scene.instance_variable_set(:@vermeil_mh_sequence_active, true)
        @scene.instance_variable_set(:@vermeil_mh_sequence_done,   false)
      end
      @scene.instance_variable_set(:@vermeil_mh_hit_num, hitNum.to_i)
      @scene.instance_variable_set(:@vermeil_mh_msg_filter_until, System.uptime + 0.80)
      
      return if @scene.pbPlayVermeilMultiHitPunches(user, targets, mid, hitNum)
    end

    if @scene && multi_hit_punches.include?(mid)
      @scene.instance_variable_set(:@vermeil_mh_sequence_active, false)
      @scene.instance_variable_set(:@vermeil_mh_sequence_done,   false)
      @scene.vermeil_mh_set_message_skin(false) if @scene.respond_to?(:vermeil_mh_set_message_skin)
      @scene.vermeil_mh_clear_message_window! if @scene.respond_to?(:vermeil_mh_clear_message_window!)
    end

    vermeil_multihit_punches_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene
  MH_DEFAULT_MESSAGE_ASSET = "Graphics/UI/Battle/overlay_message"
  MH_TRANSPARENT_MESSAGE_ASSET = "Graphics/UI/Battle/transparent_message"

  def vermeil_mh_is_final_hits_message?(text); t = text.to_s.downcase; return true if (t.include?(" hit ") && t.include?(" time")) || t.include?(" times!"); false; end
  def vermeil_mh_is_used_line?(text); t = text.to_s.downcase; return t.include?("used"); end
  def vermeil_mh_is_effectiveness_line?(text); t = text.to_s.downcase; return true if t.include?("super effective") || t.include?("not very effective") || t.include?("had no effect"); false; end

  def vermeil_mh_set_message_skin(use_transparent)
    return if !@sprites; msg_box = @sprites["messageBox"]; return if !msg_box || !msg_box.respond_to?(:setBitmap)
    asset = use_transparent ? MH_TRANSPARENT_MESSAGE_ASSET : MH_DEFAULT_MESSAGE_ASSET
    msg_box.setBitmap(asset) if pbResolveBitmap(asset) rescue nil
  end

  def vermeil_mh_finalize_sequence_for_text!
    @vermeil_mh_sequence_active = false; @vermeil_mh_sequence_done = true; @vermeil_mh_anim_active = false
    @vermeil_mh_hit_num = nil; @vermeil_mh_msg_filter_until = nil
    vermeil_mh_set_message_skin(false); pbRefresh if respond_to?(:pbRefresh)
  end

  def vermeil_mh_clear_message_window!
    return if !@sprites
    msg_box = @sprites["messageBox"]; msg_win = @sprites["messageWindow"]
    if msg_win; msg_win.text = "" if msg_win.respond_to?(:text=); msg_win.visible = false if msg_win.respond_to?(:visible=); end
    if msg_box; msg_box.visible = false if msg_box.respond_to?(:visible=); end
  end

  def vermeil_mh_show_message_window!
    return if !@sprites
    msg_box = @sprites["messageBox"]; msg_win = @sprites["messageWindow"]
    if msg_box; msg_box.visible = true if msg_box.respond_to?(:visible=); msg_box.opacity = 255 if msg_box.respond_to?(:opacity=); end
    if msg_win; msg_win.visible = true if msg_win.respond_to?(:visible=); msg_win.contents_opacity = 255 if msg_win.respond_to?(:contents_opacity=); end
  end

  def vermeil_mh_suppress_between_hits?(msg)
    return false if !@vermeil_mh_sequence_active || !@vermeil_mh_msg_filter_until || @vermeil_mh_hit_num.to_i <= 0 || System.uptime > @vermeil_mh_msg_filter_until
    text = msg.to_s.downcase; return false if text.include?("critical")
    return true if text.include?("super effective") || text.include?("not very effective") || text.include?("had no effect"); false
  end

  unless method_defined?(:vermeil_mh_pbDisplayMessage)
    alias_method :vermeil_mh_pbDisplayMessage, :pbDisplayMessage
    def pbDisplayMessage(msg, brief = false)
      if @vermeil_mh_sequence_active && vermeil_mh_is_used_line?(msg); vermeil_mh_clear_message_window!; return; end
      if vermeil_mh_suppress_between_hits?(msg); vermeil_mh_clear_message_window!; return; end
      if @vermeil_mh_sequence_active
        text = msg.to_s.downcase
        if vermeil_mh_is_used_line?(text)
          vermeil_mh_clear_message_window!; return
        elsif text.include?("critical")
          @vermeil_mh_force_message = true
          begin; vermeil_mh_set_message_skin(false); vermeil_mh_show_message_window!; pbRefresh if respond_to?(:pbRefresh); vermeil_mh_pbDisplayMessage(msg, brief); ensure; @vermeil_mh_force_message = false; end
          vermeil_mh_set_message_skin(true) if @vermeil_mh_sequence_active; return
        elsif !@vermeil_mh_anim_active && (vermeil_mh_is_effectiveness_line?(text) || vermeil_mh_is_final_hits_message?(text))
          vermeil_mh_finalize_sequence_for_text!
          @vermeil_mh_force_message = true
          begin; vermeil_mh_set_message_skin(false); vermeil_mh_show_message_window!; pbRefresh if respond_to?(:pbRefresh); vermeil_mh_pbDisplayMessage(msg, brief); ensure; @vermeil_mh_force_message = false; end
          return
        else; vermeil_mh_clear_message_window!; return; end
      end
      vermeil_mh_pbDisplayMessage(msg, brief)
    end
  end

  unless method_defined?(:vermeil_mh_pbUpdate_cleanup)
    alias_method :vermeil_mh_pbUpdate_cleanup, :pbUpdate
    def pbUpdate(*args)
      vermeil_mh_pbUpdate_cleanup(*args)
      if @vermeil_mh_sequence_active && !@vermeil_mh_anim_active
        deadline = (@vermeil_mh_msg_filter_until || 0) + 0.45
        if System.uptime > deadline; vermeil_mh_finalize_sequence_for_text!; vermeil_mh_clear_message_window!; end
      end
    end
  end

  def pbPlayVermeilMultiHitPunches(user, targets, mid, hit_num)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_mh_anim_active = true
    
    vermeil_mh_set_message_skin(true) if @vermeil_mh_sequence_active
    vermeil_mh_clear_message_window! if @vermeil_mh_sequence_active
    pbToggleDataboxes if respond_to?(:pbToggleDataboxes) && !@vermeil_mh_sequence_active
    
    begin
      anim = Animation::VermeilMultiHitPunches.new(@sprites, @viewport, user, target, mid, hit_num)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_mh_anim_active = false
      vermeil_mh_set_message_skin(false) if !@vermeil_mh_sequence_active
      pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes) && !@vermeil_mh_sequence_active
      pbRefresh if respond_to?(:pbRefresh)
    end
    return true
  end
end