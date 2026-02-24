#===============================================================================
# [VERMEIL] BattleAnimations - Mega Drain (Official Game Feel)
#===============================================================================

class Battle::Scene::Animation::VermeilCinematicMegaDrain < Battle::Scene::Animation
  T_IMPACT = 2; T_DRAIN = 8; T_END = 45
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
    ene_asset = "Graphics/Animations/PRAS- Magical Leaf"
    fla_asset = "Graphics/Animations/PRAS- Grass"
    f_dir = (@user.index & 1) == 0 ? 1 : -1

    up = addSprite(create_battler_clone(us), PictureOrigin::BOTTOM); up.setZ(0, 600)
    tp = addSprite(create_battler_clone(ts), PictureOrigin::BOTTOM); tp.setZ(0, 600)
    us.visible = false; ts.visible = false

    uh = us.bitmap ? (us.bitmap.height / 2.0) : 40; th = ts.bitmap ? (ts.bitmap.height / 2.0) : 40
    c_x, c_y = us.x + (40 * f_dir), us.y - uh; i_x, i_y = ts.x - (10 * f_dir), ts.y - th

    # 1. IMPACTO Y DRENADO (Target se vuelve grisáceo)
    tp.setSE(T_IMPACT, "Anim/PRSFX- Heal Order1", 100, 95)
    tp.moveColor(T_IMPACT, 3, Color.new(255, 255, 255, 220))
    tp.moveColor(T_IMPACT + 3, 5, Color.new(255, 255, 255, 0))
    tp.moveTone(T_IMPACT + 8, 5, Tone.new(-80, -80, -80, 100)) 

    # 2. ENJAMBRE ADITIVO (Luz Pura)
    25.times do |i|
      t_s = T_DRAIN + i
      p = addNewSprite(i_x, i_y, ene_asset, PictureOrigin::CENTER); p.setZ(0, 752)
      apply_pras_frame(p, 0, 0, 0)
      p.setBlendType(0, 1) # LUZ ADITIVA
      p.setTone(0, Tone.new(0, 120, -50, 0)) 
      p.setVisible(0, false); p.setVisible(t_s, true); p.setZoom(t_s, 40 + rand(20))
      
      # Pop Out amplio
      pop_x = i_x + (rand(120) - 60); pop_y = i_y + (rand(120) - 60)
      p.moveXY(t_s, 6, pop_x, pop_y)
      # Vuelo fluido
      p.moveXY(t_s + 6, 10, c_x, c_y)
      p.moveZoom(t_s + 6, 10, 15)
      p.moveOpacity(t_s + 12, 4, 0)
    end

    # 3. HOJAS QUE ACOMPAÑAN EL FLUJO
    8.times do |i|
      t_s = T_DRAIN + 4 + (i * 2)
      lf = addNewSprite(i_x + rand(60)-30, i_y + rand(60)-30, fla_asset, PictureOrigin::CENTER); lf.setZ(0, 755)
      apply_pras_frame(lf, rand(5), 2, 0) # Control: Fila 2 = Hojas limpias
      lf.setZoom(0, 45)
      lf.setVisible(0, false); lf.setVisible(t_s, true)
      lf.moveXY(t_s, 12, c_x, c_y); lf.moveOpacity(t_s + 8, 4, 0)
      lf.moveAngle(t_s, 12, 360)
    end

    # 4. CURACIÓN BRILLANTE
    up.moveColor(T_DRAIN + 15, 6, Color.new(50, 255, 50, 140))
    up.moveColor(T_DRAIN + 25, 12, Color.new(0, 0, 0, 0))
    tp.moveTone(T_END - 12, 12, Tone.new(0,0,0,0))
    up.setCallback(T_END, proc { us.visible = true; ts.visible = true })
  end
end

class Battle; alias_method :vermeil_megadrain_anim, :pbAnimation unless method_defined?(:vermeil_megadrain_anim)
  def pbAnimation(move, user, targets, hitNum = 0)
    mid = GameData::Move.try_get(move).id rescue nil
    if @showAnims && mid == :MEGADRAIN && @scene.respond_to?(:pbPlayVermeilMegaDrain)
      @scene.instance_variable_set(:@vermeil_ss_sequence_active, true)
      return if @scene.pbPlayVermeilMegaDrain(user, targets)
    end
    vermeil_megadrain_anim(move, user, targets, hitNum)
  end
end

class Battle::Scene; unless method_defined?(:pbPlayVermeilMegaDrain)
  def pbPlayVermeilMegaDrain(user, targets)
    target = targets.is_a?(Array) ? targets.find { |t| t && !t.fainted? && t.hp > 0 } : targets
    return false if !user || !target
    @vermeil_ss_anim_active = true; vermeil_ss_set_message_skin(true) rescue nil; vermeil_ss_clear_message_window! rescue nil
    begin
      anim = Animation::VermeilCinematicMegaDrain.new(@sprites, @viewport, user, target)
      loop do anim.update; pbUpdate; break if anim.animDone? end; anim.dispose
    ensure
      us, ts = @sprites["pokemon_#{user.index}"], @sprites["pokemon_#{target.index}"]
      us.visible = true if us; ts.visible = true if ts; @vermeil_ss_anim_active = false
      vermeil_ss_set_message_skin(false) rescue nil; pbRefresh if respond_to?(:pbRefresh)
    end; return true
  end
end; end