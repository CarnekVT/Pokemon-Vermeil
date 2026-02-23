#===============================================================================
# [VERMEIL] BattleAnimations - Thunder (The Descending Strike)
# Fix: Visible lightning bolt dropping from the sky, THEN the massive explosion.
#===============================================================================

class Battle::Scene::Animation::VermeilCinematicThunder < Battle::Scene::Animation
  T_DARKEN = 2
  T_CHARGE = 6
  T_DROP   = 16   # El rayo empieza a caer
  T_STRIKE = 19   # El rayo impacta, inicia la destrucción
  T_END    = 70

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
    clone.ox = original_sprite.ox; clone.oy = original_sprite.oy; clone.x = original_sprite.x; clone.y = original_sprite.y
    clone.zoom_x = original_sprite.zoom_x; clone.zoom_y = original_sprite.zoom_y; clone.mirror = original_sprite.mirror
    @tempSprites << clone; return clone
  end

  def createProcesses
    return if !@user || !@target
    us, ts = @sprites["pokemon_#{@user.index}"], @sprites["pokemon_#{@target.index}"]
    thunder_bg = "Graphics/Animations/PRAS- Thunder BG.png"
    elec_asset = "Graphics/Animations/PRAS- Electric.png"
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    i_x, i_y = ts.x, ts.y - th

    # 1. EL CIELO SE OSCURECE
    if pbResolveBitmap(thunder_bg)
      bg = addNewSprite(Graphics.width/2, Graphics.height/2, thunder_bg, PictureOrigin::CENTER)
      bg.setZ(0, 550); bg.setVisible(0, false); bg.setOpacity(0, 0)
      bg.setVisible(T_DARKEN, true); bg.moveOpacity(T_DARKEN, 6, 255)
      bg.moveOpacity(T_END - 10, 10, 0)
    else
      bg = addNewSprite(0, 0, "Graphics/Battle animations/black_screen") rescue nil
      if bg
        bg.setZ(0, 550); bg.setOpacity(0, 0); bg.moveOpacity(T_DARKEN, 4, 220)
        bg.moveOpacity(T_END - 10, 10, 0)
      end
    end

    # 2. CARGA DEL USUARIO (Nace de él)
    up.setSE(T_CHARGE, "Anim/Thunder1", 110, 90)
    up.moveColor(T_CHARGE, 10, Color.new(255, 255, 0, 220))
    up.moveTone(T_CHARGE, 10, Tone.new(50, 50, 50, 100))
    10.times { |i| up.moveDelta(T_CHARGE + i, 1, (i.even? ? 6 : -6), 0) }

    if pbResolveBitmap(elec_asset)
      12.times do |i|
        t_s = T_CHARGE + (i/2)
        sp = addNewSprite(us.x, us.y - uh, elec_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_frame(sp, elec_asset, rand(5), 1, 0)
        sp.setBlendType(0, 1); sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setTone(0, Tone.new(255, 255, 0, 0)); sp.setZoom(0, 50)
        sp.moveXY(t_s, 5, us.x + rand(100)-50, us.y - uh - 100 - rand(100)) # Chispas suben al cielo
        sp.moveOpacity(t_s + 3, 3, 0)
      end
    end

    # 3. EL RAYO DESCIENDE (Se ve caer físicamente)
    if pbResolveBitmap(elec_asset)
      drop = addNewSprite(i_x, i_y - 800, elec_asset, PictureOrigin::CENTER); drop.setZ(0, 740)
      apply_frame(drop, elec_asset, rand(3), 2, 0) # Fila 2
      drop.setBlendType(0, 1); drop.setTone(0, Tone.new(255, 255, 255, 0)) # Blanco puro
      drop.setVisible(0, false); drop.setVisible(T_DROP, true)
      drop.setAngle(0, -90) # Vertical
      drop.setZoomXY(0, 150, 80) # Largo pero delgado
      drop.moveXY(T_DROP, 3, i_x, i_y) # Cae a velocidad de la luz en 3 frames
      drop.moveOpacity(T_STRIKE, 1, 0)
    end

    # 4. EL CASTIGO DIVINO (Explosión y Pilar al impactar)
    tp.setSE(T_STRIKE, "Anim/PRSFX- Thunder", 120, 95)
    
    flash = addNewSprite(0, 0, "Graphics/Battle animations/white_screen") rescue nil
    if flash
      flash.setZ(0, 800); flash.setOpacity(0, 0)
      flash.moveOpacity(T_STRIKE, 1, 255); flash.moveOpacity(T_STRIKE + 3, 8, 0)
    end

    tp.moveColor(T_STRIKE, 2, Color.new(255, 255, 255, 255))
    tp.moveColor(T_STRIKE + 6, 10, Color.new(255, 255, 255, 0))
    tp.moveTone(T_STRIKE + 4, 10, Tone.new(-120, -120, -120, 180)) # Quemado
    
    16.times { |i| tp.moveDelta(T_STRIKE + i, 1, (i.even? ? 20 : -20) * f_dir, 0) }

    # PILAR VERTICAL COLOSAL
    if pbResolveBitmap(elec_asset)
      start_y = i_y - 600
      mid_y = (start_y + i_y) / 2.0
      dist = 600; angle = -90 
      
      4.times do |i|
        t_s = T_STRIKE + (i * 2)
        blast = addNewSprite(i_x, mid_y, elec_asset, PictureOrigin::CENTER); blast.setZ(0, 750 + i)
        apply_frame(blast, elec_asset, rand(5), 2, 0) 
        blast.setBlendType(0, 1); blast.setTone(0, Tone.new(255, 255, (i == 3 ? 255 : 0), 0))
        blast.setVisible(0, false); blast.setVisible(t_s, true)
        blast.setAngle(0, angle)
        
        # zoom_x es el LARGO (conecta cielo y tierra), zoom_y es el GROSOR (masivo)
        blast.setZoomXY(0, (dist / 192.0) * 100, 300 + (i * 100)) 
        blast.moveOpacity(t_s + 6, 6, 0)
      end
    end

    # 5. LLUVIA DE CHISPAS RESIDUALES
    if pbResolveBitmap(elec_asset)
      35.times do |i|
        t_s = T_STRIKE + rand(15)
        sp = addNewSprite(i_x, i_y, elec_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_frame(sp, elec_asset, rand(5), 1, 0)
        sp.setBlendType(0, 1); sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setTone(0, Tone.new(255, 255, (i % 3 == 0 ? 255 : 0), 0))
        sp.setZoom(t_s, 60 + rand(40))
        
        pop_x = i_x + (rand(260) - 130); pop_y = i_y + (rand(200) - 100)
        sp.moveXY(t_s, 8 + rand(6), pop_x, pop_y)
        sp.moveOpacity(t_s + 6, 6, 0)
      end
    end

    up.moveColor(T_STRIKE + 10, 15, Color.new(0, 0, 0, 0))
    up.moveTone(T_STRIKE + 10, 15, Tone.new(0,0,0,0))
    tp.moveTone(T_END - 15, 15, Tone.new(0,0,0,0))
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_thunder_anim, :pbAnimation unless method_defined?(:vermeil_thunder_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = GameData::Move.try_get(move).id rescue nil
    if @showAnims && mid == :THUNDER && @scene.respond_to?(:pbPlayVermeilThunder)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilThunder(user, targets)
    end
    vermeil_thunder_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilThunder)
  def pbPlayVermeilThunder(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; pbToggleDataboxes if respond_to?(:pbToggleDataboxes)
    begin
      anim = Animation::VermeilCinematicThunder.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbToggleDataboxes(true) if respond_to?(:pbToggleDataboxes); pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end