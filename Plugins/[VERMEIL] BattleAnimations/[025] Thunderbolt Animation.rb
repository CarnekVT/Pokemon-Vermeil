#===============================================================================
# [VERMEIL] BattleAnimations - Thunderbolt (Sustained Beam)
# Style: Energy born from user, bridging continuously to the target.
#===============================================================================

class Battle::Scene::Animation::VermeilCinematicThunderbolt < Battle::Scene::Animation
  T_CHARGE = 2
  T_STRIKE = 12
  T_END    = 55

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
    elec_asset = "Graphics/Animations/PRAS- Electric.png"
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    c_x, c_y = us.x + (40 * f_dir), us.y - uh; i_x, i_y = ts.x, ts.y - th

    # 1. CARGA INTENSA EN EL USUARIO
    up.setSE(T_CHARGE, "Anim/Thunder1", 100, 100)
    up.moveColor(T_CHARGE, 8, Color.new(255, 255, 0, 200)); up.moveColor(T_CHARGE + 8, 6, Color.new(0, 0, 0, 0))
    8.times { |i| up.moveDelta(T_CHARGE + i, 1, (i.even? ? 4 : -4), 0) }

    if pbResolveBitmap(elec_asset)
      15.times do |i|
        t_s = T_CHARGE + (i / 2)
        sp = addNewSprite(c_x, c_y, elec_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_frame(sp, elec_asset, rand(5), 1, 0) # Chispas
        sp.setBlendType(0, 1); sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setTone(0, Tone.new(255, 255, 0, 0)); sp.setZoom(0, 40 + rand(30))
        sp.moveXY(t_s, 5, c_x + rand(80)-40, c_y + rand(80)-40)
        sp.moveOpacity(t_s + 3, 4, 0)
      end
    end

    # 2. EL PUENTE DE ENERGÍA (Haz de luz conectando User y Target)
    tp.setSE(T_STRIKE, "Anim/Thunder3", 100, 100)
    tp.moveColor(T_STRIKE, 2, Color.new(255, 255, 255, 255))
    tp.moveColor(T_STRIKE + 6, 10, Color.new(255, 255, 255, 0))
    tp.moveTone(T_STRIKE + 4, 8, Tone.new(-80, -80, -40, 100)) # Calcinado
    12.times { |i| tp.moveDelta(T_STRIKE + i, 1, (i.even? ? 12 : -12) * f_dir, 0) }

    if pbResolveBitmap(elec_asset)
      dx = i_x - c_x; dy = i_y - c_y
      dist = Math.sqrt(dx*dx + dy*dy)
      angle = -Math.atan2(dy, dx) * 180.0 / Math::PI
      mid_x = (c_x + i_x) / 2.0; mid_y = (c_y + i_y) / 2.0

      # 6 rayos gruesos superpuestos para crear un láser continuo
      6.times do |i|
        t_s = T_STRIKE + (i * 2)
        beam = addNewSprite(mid_x, mid_y, elec_asset, PictureOrigin::CENTER); beam.setZ(0, 750 + i)
        apply_frame(beam, elec_asset, rand(4), 2, 0) # Fila 2 = Horizontal
        beam.setBlendType(0, 1); beam.setTone(0, Tone.new(255, 255, 0, 0))
        beam.setVisible(0, false); beam.setVisible(t_s, true)
        
        beam.setAngle(0, angle)
        beam.setZoomXY(0, (dist / 192.0) * 100, 100 + rand(50)) # Distancia exacta, muy grueso
        beam.moveOpacity(t_s + 4, 4, 0)
      end
    end

    # 3. CHISPAS EN EL OBJETIVO
    if pbResolveBitmap(elec_asset)
      25.times do |i|
        t_s = T_STRIKE + rand(12)
        sp = addNewSprite(i_x, i_y, elec_asset, PictureOrigin::CENTER); sp.setZ(0, 760)
        apply_frame(sp, elec_asset, rand(5), 1, 0)
        sp.setBlendType(0, 1); sp.setVisible(0, false); sp.setVisible(t_s, true)
        sp.setTone(0, Tone.new(255, 255, (i % 3 == 0 ? 255 : 0), 0)); sp.setZoom(t_s, 40 + rand(40))
        sp.moveXY(t_s, 6 + rand(4), i_x + (rand(160) - 80), i_y + (rand(160) - 80))
        sp.moveOpacity(t_s + 4, 5, 0)
      end
    end

    tp.moveTone(T_END - 10, 10, Tone.new(0,0,0,0))
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_thunderbolt_anim, :pbAnimation unless method_defined?(:vermeil_thunderbolt_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = GameData::Move.try_get(move).id rescue nil
    if @showAnims && mid == :THUNDERBOLT && @scene.respond_to?(:pbPlayVermeilThunderbolt)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilThunderbolt(user, targets)
    end
    vermeil_thunderbolt_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilThunderbolt)
  def pbPlayVermeilThunderbolt(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; vermeil_ss_clear_message_window! rescue nil
    begin
      anim = Animation::VermeilCinematicThunderbolt.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end