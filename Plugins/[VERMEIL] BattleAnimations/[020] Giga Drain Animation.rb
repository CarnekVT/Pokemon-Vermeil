#===============================================================================
# [VERMEIL] BattleAnimations - Giga Drain (Clean & Organic - Let's Go Style)
#===============================================================================

class Battle::Scene::Animation::VermeilCinematicGigaDrain < Battle::Scene::Animation
  T_IMPACT = 2; T_DRAIN = 8; T_END = 65
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
    ene_asset = "Graphics/BattleParticlesAnimations/Energy1"
    fla_asset = "Graphics/Animations/PRAS- Grass.png"
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    c_x, c_y = us.x + (40 * f_dir), us.y - uh; i_x, i_y = ts.x - (10 * f_dir), ts.y - th

    # 1. IMPACTO Y SUCCIÓN VIOLENTA (Sin raíces, pura energía)
    tp.setSE(T_IMPACT, "Anim/PRSFX- Healing Pulse", 100, 75)
    tp.moveColor(T_IMPACT, 3, Color.new(255, 255, 255, 255))
    tp.moveColor(T_IMPACT + 3, 5, Color.new(255, 255, 255, 0))
    tp.moveTone(T_IMPACT + 8, 6, Tone.new(-120, -120, -120, 150)) 
    
    8.times { |i| tp.moveDelta(T_IMPACT + (i*2), 1, 12 * f_dir, 0); tp.moveDelta(T_IMPACT + (i*2) + 1, 1, -12 * f_dir, 0) }

    # 2. ENJAMBRE MASIVO (Colores limpios y redondos)
    tones = [
      Tone.new(-180, 150, -180, 0), # Verde Bosque
      Tone.new(-100, 200, -255, 0), # Verde Lima
      Tone.new(-50, 255, -200, 0),  # Verde Amarillento
      Tone.new(50, 200, -50, 0)     # Amarillo Puro
    ]
    
    45.times do |i|
      t_s = T_DRAIN + i
      p = addNewSprite(i_x, i_y, ene_asset, PictureOrigin::CENTER); p.setZ(0, 750)
      p.setTone(0, tones[i % 4])
      p.setVisible(0, false); p.setVisible(t_s, true); p.setZoom(t_s, 30 + rand(25))
      
      # Pop Out masivo (El aura estalla primero)
      pop_x = i_x + (rand(160) - 80); pop_y = i_y + (rand(160) - 80)
      p.moveXY(t_s, 6, pop_x, pop_y)
      
      # Swoop de succión agresiva al jugador
      p.moveXY(t_s + 6, 12, c_x, c_y)
      p.moveZoom(t_s + 6, 12, 10)
      p.moveOpacity(t_s + 15, 3, 0)
    end
    
    # 3. LLUVIA DE HOJAS LIMPIAS (Fila 2 pura)
    15.times do |i|
      t_s = T_DRAIN + 4 + rand(15)
      lf = addNewSprite(i_x, i_y, fla_asset, PictureOrigin::CENTER); lf.setZ(0, 756)
      apply_pras_frame(lf, rand(5), 2, 0) 
      lf.setZoom(0, 55)
      lf.setVisible(0, false); lf.setVisible(t_s, true)
      
      pop_x = i_x + (rand(120) - 60); pop_y = i_y + (rand(120) - 60)
      lf.moveXY(t_s, 6, pop_x, pop_y)
      lf.moveXY(t_s + 6, 12, c_x, c_y)
      lf.moveOpacity(t_s + 14, 4, 0)
      lf.moveAngle(t_s, 18, 360)
    end
    
    # 4. CURACIÓN EXPLOSIVA
    up.moveColor(T_DRAIN + 15, 6, Color.new(50, 255, 50, 180)) 
    up.moveColor(T_DRAIN + 30, 15, Color.new(0, 0, 0, 0))
    tp.moveTone(T_END - 15, 15, Tone.new(0,0,0,0))
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_gigadrain_anim, :pbAnimation unless method_defined?(:vermeil_gigadrain_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = GameData::Move.try_get(move).id rescue nil
    if @showAnims && mid == :GIGADRAIN && @scene.respond_to?(:pbPlayVermeilGigaDrain)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilGigaDrain(user, targets)
    end
    vermeil_gigadrain_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilGigaDrain)
  def pbPlayVermeilGigaDrain(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; vermeil_ss_clear_message_window! rescue nil
    begin
      anim = Animation::VermeilCinematicGigaDrain.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end